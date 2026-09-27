-- Off-client test for the Warlock soulstone tier ranking
-- (StoneTier in Classes/Class_Warlock.lua, exposed as M.StoneTier).
--
-- Vanilla has five soulstones, as five separate spells AND five separate items:
-- Minor / Lesser / (unprefixed) / Greater / Major. The bug this guards shipped
-- and reached a player: both the create path and the bag lookup took the LAST
-- match in list order, and alphabetically "(Minor)" sorts last of the five, so
-- the button reliably created the weakest stone the character knew.
--
-- Ranking by NAME is the fix, and it is exactly the kind of thing nothing on
-- screen announces - a stone is still made, just the wrong one - so it gets a
-- test rather than an eyeball.
--
-- Run:  lua scripts/test_soulstone.lua

--------------------------------------------------------------------------
-- 1.12 API stubs (the class module only needs enough to reach file scope)
--------------------------------------------------------------------------
function UnitName(unit) if unit == "player" then return "Tester" end end
function UnitClass(unit) if unit == "player" then return "Warlock", "WARLOCK" end end
function GetNumRaidMembers() return 0 end
function GetNumPartyMembers() return 0 end
function GetRaidRosterInfo() return nil end
function GetTime() return 100 end
function GetSpellName() return nil end
function CreateFrame()
    local f = {}
    setmetatable(f, { __index = function() return function() return f end end })
    return f
end
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
function IsRaidLeader() return true end
function IsRaidOfficer() return true end
function IsPartyLeader() return true end
function PallyPower_CheckRaidLeader() return true end

local here = string.gsub(debug.getinfo(1).source, "^@(.*)scripts[/\\][^/\\]*$", "%1")
if here == "" then here = "./" end

AegisRP = { classes = {} }
function AegisRP:NewClass(token)
    local M = { token = token }
    self.classes[token] = M
    return M
end
function AegisRP.IsTestMode() return false end
function AegisRP.NewStrip() return { AddButton = function() end, Finish = function() end } end
function AegisRP.FindSpell() return nil end
function AegisRP.FindBagItem() return nil end
function AegisRP.BagItems() return {} end

local function load(rel)
    local chunk, err = loadfile(here .. rel)
    if not chunk then print("could not load " .. rel .. ": " .. tostring(err)); os.exit(1) end
    local ok, e = pcall(chunk)
    if not ok then print("error running " .. rel .. ": " .. tostring(e)); os.exit(1) end
end

load("Core/Aegis_Assign.lua")
load("Classes/Class_Warlock.lua")

local tier = AegisRP.classes.WARLOCK and AegisRP.classes.WARLOCK.StoneTier

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

print("warlock soulstone tiers")

check("StoneTier is exposed", type(tier), "function")
if type(tier) ~= "function" then print("FAIL - nothing to test"); os.exit(1) end

--------------------------------------------------------------------------
-- 1. The five ITEM names, in order
--------------------------------------------------------------------------
check("Minor Soulstone",   tier("Minor Soulstone"),   1)
check("Lesser Soulstone",  tier("Lesser Soulstone"),  2)
check("Soulstone",         tier("Soulstone"),         3)
check("Greater Soulstone", tier("Greater Soulstone"), 4)
check("Major Soulstone",   tier("Major Soulstone"),   5)

-- the ordering itself, which is the whole point
check("Major beats Minor",   tier("Major Soulstone") > tier("Minor Soulstone"), true)
check("Major beats Greater", tier("Major Soulstone") > tier("Greater Soulstone"), true)
check("plain beats Lesser",  tier("Soulstone") > tier("Lesser Soulstone"), true)
check("Greater beats plain", tier("Greater Soulstone") > tier("Soulstone"), true)

--------------------------------------------------------------------------
-- 2. The five SPELL names. Same ranking has to come out of "Create Soulstone
--    (Major)" as out of "Major Soulstone", because one function serves both.
--------------------------------------------------------------------------
check("Create Soulstone (Minor)",   tier("Create Soulstone (Minor)"),   1)
check("Create Soulstone (Lesser)",  tier("Create Soulstone (Lesser)"),  2)
check("Create Soulstone",           tier("Create Soulstone"),           3)
check("Create Soulstone (Greater)", tier("Create Soulstone (Greater)"), 4)
check("Create Soulstone (Major)",   tier("Create Soulstone (Major)"),   5)

-- This is the exact comparison the shipped bug got wrong. Alphabetically
-- "(Minor)" sorts LAST of the five, so anything that picked by list position
-- picked the weakest; the tier must not agree with that ordering.
check("(Major) outranks (Minor) despite sorting first",
      tier("Create Soulstone (Major)") > tier("Create Soulstone (Minor)"), true)

--------------------------------------------------------------------------
-- 3. Not a soulstone at all -> nil, so a bag walk skips it rather than
--    ranking somebody's Healthstone as a rescue stone
--------------------------------------------------------------------------
check("a healthstone is not a soulstone", tier("Major Healthstone"), nil)
check("a spellstone is not a soulstone",  tier("Greater Spellstone"), nil)
check("an unrelated item",                tier("Runecloth Bandage"), nil)
check("nil name",                         tier(nil), nil)
check("empty name",                       tier(""), nil)

--------------------------------------------------------------------------
-- 4. A name we do not recognise still scores, so a Turtle rename cannot make
--    the button dead - but it never outranks one we CAN identify as better.
--------------------------------------------------------------------------
check("an unknown soulstone is still usable", tier("Ancient Soulstone"), 3)
check("...and loses to a Major", tier("Ancient Soulstone") < tier("Major Soulstone"), true)
check("...and loses to a Greater", tier("Ancient Soulstone") < tier("Greater Soulstone"), true)
check("...but beats a Minor", tier("Ancient Soulstone") > tier("Minor Soulstone"), true)

-- case must not matter: item links and spell names are not consistently cased
check("lower case", tier("major soulstone"), 5)
check("upper case", tier("MINOR SOULSTONE"), 1)

--------------------------------------------------------------------------
print("")
if failures == 0 then
    print("PASS - soulstone tiers rank by name, not by list position")
    os.exit(0)
end
print("FAIL - " .. failures .. " check(s)")
os.exit(1)
