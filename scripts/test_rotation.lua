-- Off-client test for the rotation layer (kick + taunt) and its RPCX sections.
--
-- Exercises the REAL Core/Aegis_Assign.lua and Core/Aegis_Sync.lua against
-- stubbed 1.12 APIs. Two rotations now share one implementation, so the thing
-- worth asserting is that sharing an implementation did NOT make them share
-- STATE: a taunt order must not leak into the kick order, each must ride its
-- own wire message, and the kick-named wrappers the panel still calls must keep
-- returning what they always did.
--
-- Run:  lua scripts/test_rotation.lua

--------------------------------------------------------------------------
-- 1.12 API stubs
--------------------------------------------------------------------------
local ME = "Tankadin"
local sent = {}
local frames = {}
local roster = { ME, "War1", "War2", "Bear1", "Rogue1" }

function UnitName(unit) if unit == "player" then return ME end return nil end
function UnitClass(unit) if unit == "player" then return "Warrior", "WARRIOR" end end
function GetNumRaidMembers() return table.getn(roster) end
function GetNumPartyMembers() return 0 end
function GetRaidRosterInfo(i) return roster[i] end
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

local amLeader = true
function PallyPower_CheckRaidLeader(name) return amLeader end
function IsRaidLeader() return amLeader end
function IsRaidOfficer() return amLeader end
function IsPartyLeader() return amLeader end

--------------------------------------------------------------------------
local here = string.gsub(debug.getinfo(1).source, "^@(.*)scripts[/\\][^/\\]*$", "%1")
if here == "" then here = "./" end
local function load(rel)
    local chunk, err = loadfile(here .. rel)
    if not chunk then print("could not load " .. rel .. ": " .. tostring(err)); os.exit(1) end
    chunk()
end

AegisRP = { classes = {}, active = nil }
AegisRP.classes.WARRIOR = { buffs = {} }
function AegisRP.IsTestMode() return false end

-- the panel owns this in-game; here it just records what the wire delivered
local noted = {}
function AegisRP.NoteRemoteCooldown(kind, name, cd)
    table.insert(noted, { kind = kind, name = name, cd = cd })
end

load("Core/Aegis_Assign.lua")
load("Core/Aegis_Sync.lua")

local A = AegisRP.Assign

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

local function pumpFrames(elapsed)
    for _, f in ipairs(frames) do
        if f.scripts["OnUpdate"] then arg1 = elapsed or 1.0; f.scripts["OnUpdate"](); arg1 = nil end
    end
end

local function deliver(msg, fromWho)
    for _, f in ipairs(frames) do
        if f.scripts["OnEvent"] and f.events["CHAT_MSG_ADDON"] then
            event, arg1, arg2, arg3, arg4 = "CHAT_MSG_ADDON", "RPCX", msg, "RAID", fromWho
            f.scripts["OnEvent"]()
            event, arg1, arg2, arg3, arg4 = nil, nil, nil, nil, nil
        end
    end
end

local function lastMsg(head)
    for i = table.getn(sent), 1, -1 do
        if string.find(sent[i].msg, head, 1, true) then return sent[i].msg end
    end
    return nil
end

print("rotations - two lists, one engine")

--------------------------------------------------------------------------
-- 1. The two rotations are independent stores
--------------------------------------------------------------------------
check("add to kick", A.ToggleRotationMember("kick", "Rogue1"), true)
check("add to taunt", A.ToggleRotationMember("taunt", "War1"), true)
check("add to taunt again", A.ToggleRotationMember("taunt", "Bear1"), true)

check("kick has one", table.getn(A.GetRotation("kick")), 1)
check("taunt has two", table.getn(A.GetRotation("taunt")), 2)
check("taunt member absent from kick", A.RotationIndexOf("kick", "War1"), nil)
check("kick member absent from taunt", A.RotationIndexOf("taunt", "Rogue1"), nil)

-- order is insertion order, and the wheel moves within one list only
check("taunt order", table.concat(A.GetRotation("taunt"), ","), "War1,Bear1")
check("move Bear1 up", A.MoveRotationMember("taunt", "Bear1", -1), true)
check("taunt reordered", table.concat(A.GetRotation("taunt"), ","), "Bear1,War1")
check("kick untouched by the move", table.concat(A.GetRotation("kick"), ","), "Rogue1")

-- toggling off removes, and only from that list
check("toggle War1 out of taunt", A.ToggleRotationMember("taunt", "War1"), true)
check("taunt down to one", table.getn(A.GetRotation("taunt")), 1)

--------------------------------------------------------------------------
-- 2. The kick-named wrappers still behave (the panel and strip call them)
--------------------------------------------------------------------------
check("GetKickOrder matches", table.concat(A.GetKickOrder(), ","), "Rogue1")
check("KickIndexOf matches", A.KickIndexOf("Rogue1"), 1)
check("ToggleKicker adds", A.ToggleKicker("War2"), true)
check("...to the kick list only", table.getn(A.GetRotation("kick")), 2)
check("...and not the taunt list", table.getn(A.GetRotation("taunt")), 1)
check("MaxKickers is the shared cap", A.MaxKickers(), A.MaxRotation())

--------------------------------------------------------------------------
-- 3. Bounds and permissions
--------------------------------------------------------------------------
check("unknown kind is refused", A.ToggleRotationMember("mindcontrol", "War1"), false)
check("unknown kind reads empty", table.getn(A.GetRotation("mindcontrol")), 0)

A.ClearRotation("kick")
for i = 1, A.MaxRotation() + 3 do A.ToggleRotationMember("kick", "Filler" .. i) end
check("cap holds at MaxRotation", table.getn(A.GetRotation("kick")), A.MaxRotation())

amLeader = false
check("a non-leader can't edit", A.ToggleRotationMember("taunt", "War2"), false)
check("a non-leader can't clear", A.ClearRotation("taunt"), false)
amLeader = true

--------------------------------------------------------------------------
-- 4. Pruning drops leavers from BOTH rotations, not just the kick one
--------------------------------------------------------------------------
A.ClearRotation("kick")
A.ClearRotation("taunt")
A.ToggleRotationMember("kick", "Rogue1")
A.ToggleRotationMember("kick", "Ghost1")     -- never in the roster
A.ToggleRotationMember("taunt", "Bear1")
A.ToggleRotationMember("taunt", "Ghost2")
A.PruneToRoster()
check("kick keeps the present member", table.concat(A.GetRotation("kick"), ","), "Rogue1")
check("taunt keeps the present member", table.concat(A.GetRotation("taunt"), ","), "Bear1")

--------------------------------------------------------------------------
-- 5. Wire: each rotation rides its own message
--------------------------------------------------------------------------
sent = {}
A.ToggleRotationMember("taunt", "War1")
pumpFrames(1.0)
local to = lastMsg(" TO ")
check("a TO went out", to ~= nil, true)
if to then check("TO carries both taunts", string.find(to, "Bear1 War1", 1, true) ~= nil, true) end

sent = {}
A.ToggleRotationMember("kick", "War2")
pumpFrames(1.0)
local ko = lastMsg(" KO ")
check("a KO went out", ko ~= nil, true)
if ko then check("KO carries the kickers", string.find(ko, "Rogue1 War2", 1, true) ~= nil, true) end
check("KO did not carry a taunter", ko and string.find(ko, "Bear1", 1, true) == nil, true)

--------------------------------------------------------------------------
-- 6. Wire: a received TO installs the taunt order and leaves kicks alone
--------------------------------------------------------------------------
deliver("1 TO Bear1 War2", "Someone")
check("received TO applied", table.concat(A.GetRotation("taunt"), ","), "Bear1,War2")
check("received TO left kicks alone", table.concat(A.GetRotation("kick"), ","), "Rogue1,War2")

deliver("1 KO War1", "Someone")
check("received KO applied", table.concat(A.GetRotation("kick"), ","), "War1")
check("received KO left taunts alone", table.concat(A.GetRotation("taunt"), ","), "Bear1,War2")

-- "-" is the empty-rotation token
deliver("1 TO -", "Someone")
check("empty TO clears the taunt order", table.getn(A.GetRotation("taunt")), 0)

--------------------------------------------------------------------------
-- 7. Wire: self-reported cooldowns route to the right rotation
--------------------------------------------------------------------------
noted = {}
deliver("1 KICK 7.5", "Rogue1")
deliver("1 TNT 9.0", "Bear1")
check("two cooldown reports landed", table.getn(noted), 2)
check("KICK routed to kick", noted[1] and noted[1].kind, "kick")
check("KICK named the sender", noted[1] and noted[1].name, "Rogue1")
check("TNT routed to taunt", noted[2] and noted[2].kind, "taunt")
check("TNT carried the seconds", noted[2] and noted[2].cd, 9)

-- nonsense is dropped rather than stored
noted = {}
deliver("1 TNT -3", "Bear1")
deliver("1 TNT 9999", "Bear1")
check("bad cooldowns dropped", table.getn(noted), 0)

--------------------------------------------------------------------------
print("")
if failures == 0 then
    print("PASS - independent rotations, wrappers, pruning and wire")
    os.exit(0)
end
print("FAIL - " .. failures .. " check(s)")
os.exit(1)
