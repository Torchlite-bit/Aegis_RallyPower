-- Off-client test for the pet-owner gate (Core/Aegis_Assign is not involved;
-- this is Core/Aegis_Core.lua's AegisRP.PetOwnerUnit / PetSkippedForBuffs).
--
-- Vanilla has no "is this unit a pet, and whose" query, so ownership is read
-- off the index a pet token shares with its owner. That makes the gate a piece
-- of string parsing plus one class lookup - isolable, and wrong in ways nothing
-- on screen would announce:
--
--   * Get the token shapes wrong and the gate never fires. The paladin fix
--     depends on matching the shapes the VENDORED engine builds (raidpetN,
--     partypetN, pet - PallyPower.lua:2985-3004), so those are pinned here.
--   * Treat "I cannot tell whose pet this is" as "not a hunter's" and a hunter
--     pet silently stops being buffable during roster churn, with nothing
--     saying why. That is the failure the "a detection that cannot answer must
--     never close a gate" rule exists to prevent, so it gets its own check.
--
-- Run:  lua scripts/test_pets.lua

--------------------------------------------------------------------------
-- 1.12 API stubs
--------------------------------------------------------------------------
-- [unit] = class token; a unit absent from this table answers nil, which is
-- the "cannot tell" case (out of range, mid roster change, not loaded yet)
local CLASS = {}

function UnitClass(u)
    local c = CLASS[u]
    if not c then return nil end
    return c, c
end
function UnitName(u) if u == "player" then return "Tester" end end
function GetNumRaidMembers() return 0 end
function GetNumPartyMembers() return 0 end
function GetRaidRosterInfo() return nil end
function GetTime() return 100 end
function GetSpellName() return nil end
function getglobal(n) return _G[n] end
function CreateFrame()
    local f = {}
    setmetatable(f, { __index = function() return function() return f end end })
    return f
end
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
UIParent = setmetatable({}, { __index = function() return function() return 1 end end })
SlashCmdList = {}

local here = string.gsub(debug.getinfo(1).source, "^@(.*)scripts[/\\][^/\\]*$", "%1")
if here == "" then here = "./" end

AegisRP = {}
local chunk, err = loadfile(here .. "Core/Aegis_Core.lua")
if not chunk then print("could not load Aegis_Core.lua: " .. tostring(err)); os.exit(1) end
local ok, e = pcall(chunk)
if not ok then print("error running Aegis_Core.lua: " .. tostring(e)); os.exit(1) end

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

local owner = AegisRP.PetOwnerUnit
local skip  = AegisRP.PetSkippedForBuffs

print("pet ownership")

--------------------------------------------------------------------------
-- 1. Token shapes. These are not ours to choose: they are what the VENDORED
--    engine puts in its roster, and the paladin gate only fires on a match.
--------------------------------------------------------------------------
check("the player's own pet", owner("pet"), "player")
check("a party pet", owner("partypet3"), "party3")
check("a raid pet", owner("raidpet17"), "raid17")
check("...two digits, not truncated", owner("raidpet40"), "raid40")

check("a player unit is not a pet", owner("raid17"), nil)
check("'player' is not a pet", owner("player"), nil)
check("'target' is not a pet", owner("target"), nil)
-- the engine never builds this shape; matching it would map to the wrong owner
check("retail-style raid12pet is not matched", owner("raid12pet"), nil)
check("a trailing-garbage token is refused", owner("raidpet3x"), nil)

--------------------------------------------------------------------------
-- 2. The gate itself
--------------------------------------------------------------------------
print("")
print("pet buff gate")

CLASS["raid3"]  = "HUNTER"
CLASS["raid5"]  = "WARLOCK"
CLASS["player"] = "PALADIN"
CLASS["party2"] = "WARLOCK"

check("a warlock's demon is skipped", skip("raidpet5"), true)
check("a warlock's demon in a party is skipped", skip("partypet2"), true)
check("a hunter's pet is NOT skipped", skip("raidpet3"), false)
check("a player is never skipped", skip("raid5"), false)
check("...not even the warlock themselves", skip("raid5"), false)
check("a non-unit string is not skipped", skip("target"), false)

--------------------------------------------------------------------------
-- 3. "Cannot tell" is PERMISSION, not refusal.
--
--    raid9 has no class here: out of range, mid roster change, not yet loaded.
--    Skipping on that answer would make a hunter pet quietly unbuffable with
--    nothing on screen to explain it. Letting one blessing through in that
--    window is the cheaper mistake, and it is the behaviour we had anyway.
--------------------------------------------------------------------------
check("an unknown owner is NOT skipped", skip("raidpet9"), false)
check("...and stays unskipped once known to be a hunter",
      (function() CLASS["raid9"] = "HUNTER"; return skip("raidpet9") end)(), false)
check("...but IS skipped once known to be a warlock",
      (function() CLASS["raid9"] = "WARLOCK"; return skip("raidpet9") end)(), true)
-- and back to unknown: the gate must reopen rather than latch shut
CLASS["raid9"] = nil
check("losing the class reopens the gate", skip("raidpet9"), false)

--------------------------------------------------------------------------
print("")
if failures == 0 then
    print("PASS - pet token shapes and the owner-class gate")
    os.exit(0)
end
print("FAIL - " .. failures .. " check(s)")
os.exit(1)
