-- Off-client test for the group-buff domain and its RPCX wire section.
--
-- Exercises the REAL Core/Aegis_Assign.lua and Core/Aegis_Sync.lua against
-- stubbed 1.12 APIs, end to end: set assignments through the public model API,
-- let the sync layer serialise and broadcast them, then feed the captured
-- addon message back in as a different sender and assert the model that comes
-- out the far side matches the one that went in.
--
-- Why this and not a unit test of the serialiser: SerializeBlock and
-- DeserializeBlock are file-locals (correctly), so the honest way to test the
-- format is through the paths that actually use it. A silent round-trip bug
-- here would corrupt raid assignments with no error, which is the worst
-- possible failure mode for a sync protocol.
--
-- Run:  lua scripts/test_groupbuff.lua
-- The addon files are Lua 5.0-compatible, so they load unmodified.

--------------------------------------------------------------------------
-- 1.12 API stubs
--------------------------------------------------------------------------
local ME = "Priest1"
local sent = {}              -- captured SendAddonMessage payloads
local frames = {}            -- every CreateFrame'd frame, for driving scripts

function UnitName(unit) if unit == "player" then return ME end return nil end
function UnitClass(unit) if unit == "player" then return "Priest", "PRIEST" end end
function GetNumRaidMembers() return 5 end
function GetNumPartyMembers() return 0 end
function GetRaidRosterInfo(i) return nil end
function GetTime() return 100 end
function SendAddonMessage(prefix, msg, chan, sender)
    table.insert(sent, { prefix = prefix, msg = msg, chan = chan, sender = sender })
end
function CreateFrame(kind, name)
    local f = { scripts = {}, events = {} }
    function f:SetScript(which, fn) self.scripts[which] = fn end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    table.insert(frames, f)
    return f
end
DEFAULT_CHAT_FRAME = { AddMessage = function() end }

-- leader-gated writes: we are the leader in this harness
function PallyPower_CheckRaidLeader(name) return true end
function IsRaidLeader() return true end
function IsRaidOfficer() return true end
function IsPartyLeader() return true end

--------------------------------------------------------------------------
-- load the real addon files
--------------------------------------------------------------------------
local here = string.gsub(debug.getinfo(1).source, "^@(.*)scripts[/\\][^/\\]*$", "%1")
if here == "" then here = "./" end
local function load(rel)
    local chunk, err = loadfile(here .. rel)
    if not chunk then print("could not load " .. rel .. ": " .. tostring(err)); os.exit(1) end
    chunk()
end

AegisRP = { classes = {}, active = nil }
-- a Priest catalog: index order is what the wire encodes
AegisRP.classes.PRIEST = { buffs = {
    { name = "Power Word: Fortitude", group = "Prayer of Fortitude" },  -- 1
    { name = "Divine Spirit",         group = "Prayer of Spirit"    },  -- 2
    { name = "Shadow Protection",     group = "Prayer of Shadow Protection" }, -- 3
} }
function AegisRP.IsTestMode() return false end

load("Core/Aegis_Assign.lua")
load("Core/Aegis_Sync.lua")

local A = AegisRP.Assign

--------------------------------------------------------------------------
-- harness helpers
--------------------------------------------------------------------------
local failures = 0
local function check(label, got, want)
    if got == want then
        print(string.format("  ok    %-54s %s", label, tostring(got)))
    else
        print(string.format("  FAIL  %-54s got %s, want %s", label, tostring(got), tostring(want)))
        failures = failures + 1
    end
end

-- drive every frame's OnUpdate far enough to pass the flush debounce
local function pumpFrames(elapsed)
    for _, f in ipairs(frames) do
        if f.scripts["OnUpdate"] then arg1 = elapsed or 1.0; f.scripts["OnUpdate"](); arg1 = nil end
    end
end

-- deliver a captured message back in as though another client sent it
local function deliver(msg, fromWho)
    for _, f in ipairs(frames) do
        if f.scripts["OnEvent"] and f.events["CHAT_MSG_ADDON"] then
            event, arg1, arg2, arg3, arg4 = "CHAT_MSG_ADDON", "RPCX", msg, "RAID", fromWho
            f.scripts["OnEvent"]()
            event, arg1, arg2, arg3, arg4 = nil, nil, nil, nil, nil
        end
    end
end

local function lastBlockFor(who)
    for i = table.getn(sent), 1, -1 do
        if string.find(sent[i].msg, "BLK " .. who .. " ", 1, true) then return sent[i].msg end
    end
    return nil
end

print("group buffs - model + RPCX round-trip")

--------------------------------------------------------------------------
-- 1. Model: a group holds a SET, so one caster can own several buffs for it
--------------------------------------------------------------------------
check("set Fortitude on group 2", A.SetGroupBuff(ME, 2, "Power Word: Fortitude", true), true)
check("set Divine Spirit on group 2", A.SetGroupBuff(ME, 2, "Divine Spirit", true), true)
check("set Fortitude on group 5", A.SetGroupBuff(ME, 5, "Power Word: Fortitude", true), true)

check("group 2 holds both buffs", table.getn(A.GetGroupBuffs(ME, 2)), 2)
check("group 5 holds one", table.getn(A.GetGroupBuffs(ME, 5)), 1)
check("group 3 holds none", table.getn(A.GetGroupBuffs(ME, 3)), 0)
check("HasGroupBuff true", A.HasGroupBuff(ME, 2, "Divine Spirit"), true)
check("HasGroupBuff false", A.HasGroupBuff(ME, 3, "Divine Spirit"), false)

-- catalog order, not insertion order, so panel and wire agree
local g2 = A.GetGroupBuffs(ME, 2)
check("returned in catalog order", g2[1] .. " / " .. g2[2],
      "Power Word: Fortitude / Divine Spirit")

check("covered groups", table.concat(A.GetCoveredGroups(ME), ","), "2,5")

--------------------------------------------------------------------------
-- 2. Removing the last buff drops the group entirely
--------------------------------------------------------------------------
A.SetGroupBuff(ME, 5, "Power Word: Fortitude", false)
check("group 5 emptied", table.getn(A.GetGroupBuffs(ME, 5)), 0)
check("emptied group leaves coverage", table.concat(A.GetCoveredGroups(ME), ","), "2")

--------------------------------------------------------------------------
-- 3. Bounds: groups outside 1..8 are rejected, not stored
--------------------------------------------------------------------------
check("group 0 rejected", A.SetGroupBuff(ME, 0, "Divine Spirit", true), false)
check("group 9 rejected", A.SetGroupBuff(ME, 9, "Divine Spirit", true), false)
check("nil buff rejected", A.SetGroupBuff(ME, 2, nil, true), false)

--------------------------------------------------------------------------
-- 4. Wire: the "g" section serialises and survives a round-trip
--------------------------------------------------------------------------
A.SetGroupBuff(ME, 5, "Shadow Protection", true)   -- back to two groups
sent = {}
pumpFrames(1.0)                                     -- past FLUSH_DELAY

local blk = lastBlockFor(ME)
check("a BLK went out for us", blk ~= nil, true)
if blk then
    -- group.buffIndex pairs, catalog-ordered: g2.1,2.2,5.3
    check("carries the g section", string.find(blk, "g2%.1,2%.2,5%.3") ~= nil, true)
    check("still carries the class tag", string.find(blk, "cPRIEST", 1, true) ~= nil, true)
end

-- feed it back as a DIFFERENT caster and confirm the model rebuilds
if blk then
    local asOther = string.gsub(blk, "BLK " .. ME .. " ", "BLK Priest2 ", 1)
    deliver(asOther, "Priest2")
    check("round-trip: group 2 buffs", table.getn(A.GetGroupBuffs("Priest2", 2)), 2)
    check("round-trip: group 5 buffs", table.getn(A.GetGroupBuffs("Priest2", 5)), 1)
    check("round-trip: exact buff name",
          A.HasGroupBuff("Priest2", 5, "Shadow Protection"), true)
    check("round-trip: absent group stays absent",
          A.HasGroupBuff("Priest2", 4, "Divine Spirit"), false)
end

--------------------------------------------------------------------------
-- 5. FORWARD COMPATIBILITY, both directions
--------------------------------------------------------------------------
-- a v1 payload (no g section) must still parse everything it does know
deliver("1 BLK Priest3 1 cPRIEST;b0.1", "Priest3")
check("v1 payload still parses (no g)", A.GetClassBuff("Priest3", 0),
      "Power Word: Fortitude")
check("v1 payload leaves no groups", table.getn(A.GetCoveredGroups("Priest3")), 0)

-- an UNKNOWN future tag must be skipped without harming the rest: this is the
-- property that let "g" ship without a PROTO_V bump
deliver("1 BLK Priest4 1 cPRIEST;zFUTURE,STUFF;g3.2", "Priest4")
check("unknown tag skipped, g still read", A.HasGroupBuff("Priest4", 3, "Divine Spirit"), true)
check("unknown tag left class intact", A.GetCaster("Priest4").class, "PRIEST")

--------------------------------------------------------------------------
print("")
if failures == 0 then
    print("PASS - model, wire round-trip and forward compatibility")
    os.exit(0)
end
print("FAIL - " .. failures .. " check(s)")
os.exit(1)
