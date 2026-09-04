-- Off-client test for the crowd-control domain and its RPCX wire section.
--
-- Loads the REAL Assign model, the REAL class modules (so the CC catalog and
-- its wids are the shipping ones, not a fixture) and the REAL sync layer, then
-- drives assignments through the public API, lets the sync layer serialise and
-- broadcast them, and feeds the captured message back in as a different sender.
--
-- Two things here fail silently rather than loudly, which is why they are
-- tested rather than eyeballed:
--
--   * The store is CASTER-major and the panel reads a MARK-major view. A bug
--     in that derivation shows up as an assignment that exists but is invisible
--     on the tab, or one that appears on the wrong row.
--   * CC shares the duty catalog and the duty wid space. If a non-CC wid were
--     accepted in the CC section, a remote client would install a debuff key
--     into a domain where every reader expects a CC spell - no error, just a
--     mark showing "Sunder Armor".
--
-- Run:  lua scripts/test_cc.lua

--------------------------------------------------------------------------
-- 1.12 API stubs
--------------------------------------------------------------------------
local ME = "Mage1"
local sent = {}              -- captured SendAddonMessage payloads
local frames = {}            -- every CreateFrame'd frame, for driving scripts
local roster = { "Mage1", "Warlock1", "Priest1", "Rogue1" }

function UnitName(unit)
    if unit == "player" then return ME end
    local _, _, i = string.find(unit or "", "^raid(%d+)$")
    return i and roster[tonumber(i)]
end
function UnitClass(unit) if unit == "player" then return "Mage", "MAGE" end end
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
    setmetatable(f, { __index = function() return function() return f end end })
    table.insert(frames, f)
    return f
end
DEFAULT_CHAT_FRAME = { AddMessage = function() end }

-- leader-gated writes: we are the leader in this harness
function PallyPower_CheckRaidLeader() return true end
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
    local ok, e = pcall(chunk)
    if not ok then print("error running " .. rel .. ": " .. tostring(e)); os.exit(1) end
end

AegisRP = { classes = {} }
function AegisRP:NewClass(token)
    local M = { token = token }
    self.classes[token] = M
    return M
end
function AegisRP.IsTestMode() return false end
function AegisRP.NewStrip() return { AddButton = function() end, Finish = function() end } end
function AegisRP.BuildClassBuffs() return { Toggle = function() end } end
function AegisRP.FindSpell() return nil end

load("Core/Aegis_Assign.lua")
local CLASSES = { "Priest", "Mage", "Druid", "Warrior", "Shaman",
                  "Hunter", "Warlock", "Rogue" }
for i = 1, table.getn(CLASSES) do load("Classes/Class_" .. CLASSES[i] .. ".lua") end
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

-- This harness loads the CLASS MODULES as well (the CC catalog has to be the
-- shipping one), and they register tickers of their own that want game state
-- nothing here stubs. Those are not under test, so a throw in one must not
-- take the sync flush down with it.
local function pumpFrames(elapsed)
    for _, f in ipairs(frames) do
        if f.scripts["OnUpdate"] then
            this, arg1 = f, elapsed or 1.0
            pcall(f.scripts["OnUpdate"])
            this, arg1 = nil, nil
        end
    end
end

local function deliver(msg, fromWho)
    for _, f in ipairs(frames) do
        if f.scripts["OnEvent"] and f.events["CHAT_MSG_ADDON"] then
            this = f
            event, arg1, arg2, arg3, arg4 = "CHAT_MSG_ADDON", "RPCX", msg, "RAID", fromWho
            f.scripts["OnEvent"]()
            event, arg1, arg2, arg3, arg4 = nil, nil, nil, nil, nil
            this = nil
        end
    end
end

local function lastBlockFor(who)
    for i = table.getn(sent), 1, -1 do
        if string.find(sent[i].msg, "BLK " .. who .. " ", 1, true) then return sent[i].msg end
    end
    return nil
end

-- the owner of a mark, or nil
local function ownerOf(mark)
    local h = A.GetCCForMark(mark)
    return h[1] and h[1].caster
end
local function spellOf(mark)
    local h = A.GetCCForMark(mark)
    return h[1] and h[1].key
end

print("crowd control - model + RPCX round-trip")

--------------------------------------------------------------------------
-- 1. The catalog CC is assigned FROM is the shipping one
--------------------------------------------------------------------------
check("Polymorph is a CC entry", A.duties.POLYMORPH and A.duties.POLYMORPH.tab, "cc")
check("Banish is a CC entry", A.duties.BANISH and A.duties.BANISH.tab, "cc")
check("Sunder is NOT a CC entry", A.duties.SUNDER.tab ~= "cc", true)

--------------------------------------------------------------------------
-- 2. Model: a caster holds marks; the mark-major view is derived from that
--------------------------------------------------------------------------
check("mark 8 starts empty", ownerOf(8), nil)
check("set Polymorph on Skull", A.SetCC(ME, 8, "POLYMORPH"), true)
check("...the caster-major store has it", A.GetCC(ME, 8), "POLYMORPH")
check("...and the mark-major view agrees", ownerOf(8), ME)
check("...with the right spell", spellOf(8), "POLYMORPH")
check("another mark is still empty", ownerOf(7), nil)

check("a second mark for the same caster", A.SetCC(ME, 5, "POLYMORPH"), true)
check("GetCCMarks lists both, ascending", A.GetCCMarks(ME)[1].mark, 5)
check("...and the second", A.GetCCMarks(ME)[2].mark, 8)
check("...as a count", table.getn(A.GetCCMarks(ME)), 2)

-- clearing one mark leaves the other alone
check("clear one mark", A.SetCC(ME, 5, nil), true)
check("...the other survives", A.GetCC(ME, 8), "POLYMORPH")
check("...and the cleared one is gone", ownerOf(5), nil)

--------------------------------------------------------------------------
-- 3. Bounds and bad keys are REFUSED rather than stored.
--
--    A key no catalog entry answers to would serialise to nothing: it would
--    look assigned on this client and be invisible on every other one.
--------------------------------------------------------------------------
check("mark 0 rejected", A.SetCC(ME, 0, "POLYMORPH"), false)
check("mark 9 rejected", A.SetCC(ME, 9, "POLYMORPH"), false)
check("an unknown key is rejected", A.SetCC(ME, 3, "NOT_A_SPELL"), false)
-- a real duty that is not CC is equally wrong here: the CC domain's readers
-- all expect a CC spell, so a debuff key in it is corruption, not data
check("a non-CC duty key is rejected", A.SetCC(ME, 3, "SUNDER"), false)
check("...so mark 3 stayed empty", ownerOf(3), nil)

--------------------------------------------------------------------------
-- 4. AssignMark is single-owner: giving a mark away takes it off whoever had
--    it. Two people sheeping one skull is a mistake, not a plan.
--------------------------------------------------------------------------
check("give Skull to the warlock", A.AssignMark(8, "Warlock1", "BANISH"), true)
check("...the warlock has it", ownerOf(8), "Warlock1")
check("...with their spell", spellOf(8), "BANISH")
check("...and the mage was evicted", A.GetCC(ME, 8), nil)
check("exactly one claimant", table.getn(A.GetCCForMark(8)), 1)

-- nil caster empties the mark
check("clear the mark entirely", A.AssignMark(8, nil), true)
check("...nobody holds it", ownerOf(8), nil)
check("clearing an empty mark reports nothing done", A.AssignMark(8, nil), false)

-- A double claim is REPRESENTABLE on purpose: SetCC is the primitive and a
-- non-leader can always claim for themselves, so two clients can race. The
-- panel shows the clash; the model must not silently drop one.
A.SetCC(ME, 6, "POLYMORPH")
A.SetCC("Priest1", 6, "SHACKLE")
check("a double claim is kept, not hidden", table.getn(A.GetCCForMark(6)), 2)
check("...sorted by caster name", A.GetCCForMark(6)[1].caster, "Mage1")
check("...each with their own spell", A.GetCCForMark(6)[2].key, "SHACKLE")
-- and AssignMark resolves it
A.AssignMark(6, "Priest1", "SHACKLE")
check("AssignMark resolves the clash", table.getn(A.GetCCForMark(6)), 1)

--------------------------------------------------------------------------
-- 5. ClearCC drops one caster's whole plan and nobody else's
--------------------------------------------------------------------------
A.SetCC(ME, 1, "POLYMORPH")
A.SetCC(ME, 2, "POLYMORPH")
check("the mage holds two marks", table.getn(A.GetCCMarks(ME)), 2)
check("clear the mage's plan", A.ClearCC(ME), true)
check("...all of their marks are gone", table.getn(A.GetCCMarks(ME)), 0)
check("...the priest's is untouched", ownerOf(6), "Priest1")
check("clearing an empty plan is idempotent", A.ClearCC(ME), true)

--------------------------------------------------------------------------
-- 6. Wire: the "x" section serialises and survives a round-trip
--------------------------------------------------------------------------
A.ClearCC("Priest1")
A.SetCC(ME, 8, "POLYMORPH")     -- Skull
A.SetCC(ME, 5, "POLYMORPH")     -- Moon
sent = {}
pumpFrames(1.0)                 -- past FLUSH_DELAY

local blk = lastBlockFor(ME)
check("a BLK went out for us", blk ~= nil, true)
if blk then
    -- mark.wid pairs, ASCENDING BY MARK: marks are walked 1..N rather than
    -- with pairs(), because the wire has an order and pairs() does not
    local wid = A.duties.POLYMORPH.wid
    check("carries the x section, marks ascending",
          string.find(blk, "x5%." .. wid .. ",8%." .. wid) ~= nil, true)
    check("still carries the class tag", string.find(blk, "cMAGE", 1, true) ~= nil, true)
end

if blk then
    local asOther = string.gsub(blk, "BLK " .. ME .. " ", "BLK Mage2 ", 1)
    deliver(asOther, "Mage2")
    check("round-trip: Skull came back", A.GetCC("Mage2", 8), "POLYMORPH")
    check("round-trip: Moon came back", A.GetCC("Mage2", 5), "POLYMORPH")
    check("round-trip: an unset mark stays unset", A.GetCC("Mage2", 7), nil)
    check("round-trip: the mark-major view sees them", table.getn(A.GetCCForMark(5)), 2)
end

-- a caster with no CC sends no x section at all (an empty one would be noise
-- in a 250-byte message budget)
A.ClearCC(ME)
sent = {}
pumpFrames(1.0)
local bare = lastBlockFor(ME)
check("no CC plan means no x section",
      bare and string.find(bare, "x%d") == nil, true)

--------------------------------------------------------------------------
-- 7. A wid that is not a CC entry is refused ON THE WAY IN.
--
--    Wid 7 is Sunder Armor. A client sending it inside the CC section is
--    version skew, not a plan: installing it would put a debuff key where
--    every reader expects a CC spell, and nothing downstream would complain.
--------------------------------------------------------------------------
deliver("1 BLK Rogue9 1 cROGUE;x8." .. A.duties.SUNDER.wid, "Rogue9")
check("a non-CC wid is not installed", A.GetCC("Rogue9", 8), nil)
deliver("1 BLK Rogue8 1 cROGUE;x8." .. A.duties.SAP.wid, "Rogue8")
check("...but a real CC wid is", A.GetCC("Rogue8", 8), "SAP")

-- an out-of-range mark on the wire is dropped rather than stored off the end
deliver("1 BLK Rogue7 1 cROGUE;x99." .. A.duties.SAP.wid, "Rogue7")
check("an out-of-range mark is dropped", A.GetCC("Rogue7", 99), nil)

-- unknown sections still skip cleanly with an x section behind them: the whole
-- point of tagged sections is that a new one does not need a PROTO bump
deliver("1 BLK Rogue6 1 cROGUE;zFUTURE,STUFF;x2." .. A.duties.BLIND.wid, "Rogue6")
check("an unknown tag doesn't eat the x section", A.GetCC("Rogue6", 2), "BLIND")

--------------------------------------------------------------------------
-- 8. Pruning: someone who leaves takes their marks with them, because the CC
--    plan lives inside their caster block rather than in a mark-major table
--    that would need its own cleanup.
--------------------------------------------------------------------------
A.SetCC("Rogue8", 4, "SAP")
check("the rogue holds a mark", ownerOf(4), "Rogue8")
roster = { "Mage1", "Warlock1", "Priest1" }      -- Rogue8 was never in it
A.PruneToRoster()
check("a leaver's mark falls vacant", ownerOf(4), nil)
check("...and so did their Skull", ownerOf(8), nil)

--------------------------------------------------------------------------
print("")
if failures == 0 then
    print("PASS - CC model, mark-major view, wire round-trip and pruning")
    os.exit(0)
end
print("FAIL - " .. failures .. " check(s)")
os.exit(1)
