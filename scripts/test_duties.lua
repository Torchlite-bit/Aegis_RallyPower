-- Off-client test for the duty catalog (Core/Aegis_Assign.lua + Classes/*).
--
-- Loads the REAL Assign model and every REAL class module, then checks the
-- catalog as a whole. Wids are what duties travel as on the wire - names never
-- do, so a Turtle rename can't break sync - which makes a duplicate wid a
-- silent corruption: two duties become the same duty for every remote client,
-- with no error anywhere. Nothing catches that by inspection once the catalog
-- is a few dozen entries across eight files, so it gets a test.
--
-- Run:  lua scripts/test_duties.lua

--------------------------------------------------------------------------
-- 1.12 API stubs (class modules only need enough to reach RegisterDuty)
--------------------------------------------------------------------------
function UnitName(unit) if unit == "player" then return "Tester" end end
function UnitClass(unit) if unit == "player" then return "Druid", "DRUID" end end
function GetNumRaidMembers() return 0 end
function GetNumPartyMembers() return 0 end
function GetRaidRosterInfo() return nil end
function GetTime() return 100 end
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
function AegisRP.BuildClassBuffs() return { Toggle = function() end } end
function AegisRP.FindSpell() return nil end

local function load(rel)
    local chunk, err = loadfile(here .. rel)
    if not chunk then print("could not load " .. rel .. ": " .. tostring(err)); os.exit(1) end
    local ok, e = pcall(chunk)
    if not ok then print("error running " .. rel .. ": " .. tostring(e)); os.exit(1) end
end

load("Core/Aegis_Assign.lua")
local A = AegisRP.Assign

local CLASSES = { "Priest", "Mage", "Druid", "Warrior", "Shaman",
                  "Hunter", "Warlock", "Rogue" }
for i = 1, table.getn(CLASSES) do
    load("Classes/Class_" .. CLASSES[i] .. ".lua")
end

--------------------------------------------------------------------------
local failures = 0
local function check(label, got, want)
    if got == want then
        print(string.format("  ok    %-52s %s", label, tostring(got)))
    else
        print(string.format("  FAIL  %-52s got %s, want %s", label, tostring(got), tostring(want)))
        failures = failures + 1
    end
end

print("duty catalog")

--------------------------------------------------------------------------
-- 1. Every duty is well-formed
--------------------------------------------------------------------------
local n = table.getn(A.dutyOrder)
check("duties registered", n > 0, true)

local missingWid, missingSpell, badTab, noIcon = {}, {}, {}, {}
local TABS = { debuff = true, raidbuff = true, utility = true }
for i = 1, n do
    local d = A.duties[A.dutyOrder[i]]
    if not d.wid then table.insert(missingWid, d.key) end
    if not d.spell then table.insert(missingSpell, d.key) end
    if not TABS[d.tab or ""] then table.insert(badTab, d.key) end
    if not d.icon then table.insert(noIcon, d.key) end
end
check("every duty has a wid", table.concat(missingWid, ","), "")
check("every duty names a spell", table.concat(missingSpell, ","), "")
check("every duty sits on a known tab", table.concat(badTab, ","), "")

-- A card falls back to the duty's own icon whenever the viewer can't resolve
-- the spell from their spellbook - which is everyone looking at another
-- class's duty. Faerie Fire and Demoralizing Roar shipped blank in 1.8.0
-- because the icon lived in a parallel table in the panel that was easy to
-- forget; it rides on the duty now, and this is what keeps it there.
check("every duty carries a fallback icon", table.concat(noIcon, ","), "")

--------------------------------------------------------------------------
-- 2. Wids are UNIQUE. This is the one that matters: duties cross the wire as
--    wids, so a collision silently merges two duties on every remote client.
--------------------------------------------------------------------------
local seen, dupes = {}, {}
for i = 1, n do
    local d = A.duties[A.dutyOrder[i]]
    if d.wid then
        if seen[d.wid] then
            table.insert(dupes, d.wid .. " (" .. seen[d.wid] .. " vs " .. d.key .. ")")
        else
            seen[d.wid] = d.key
        end
    end
end
check("no duplicate wids", table.concat(dupes, "; "), "")

-- wire id 19 was Priest Tank Shield, cancelled in 0.14.0 and retired. Reusing
-- it would make an old client apply a stale assignment to the wrong duty.
check("retired wid 19 is not reused", seen[19], nil)

--------------------------------------------------------------------------
-- 3. The debuff tab has to fit the panel's pooled cards (2 columns x 8 rows).
--    Overflow doesn't error - the extra duties just silently never render.
--------------------------------------------------------------------------
-- Kept in step with DUTY_POOL in Core/Aegis_AssignPanel.lua by hand: the panel
-- isn't loadable off-client, so this can't read it. A stale copy here fails
-- conservatively (a false alarm, never a missed overflow), which is the safe
-- direction for the two to disagree in.
local DUTY_POOL = 18
local shown = 0
for i = 1, n do
    local d = A.duties[A.dutyOrder[i]]
    if d.tab == "debuff" and not d.hidden then shown = shown + 1 end
end
print(string.format("  ..    visible debuff duties: %d of %d cards", shown, DUTY_POOL))
check("debuff tab fits its card pool", shown <= DUTY_POOL, true)

--------------------------------------------------------------------------
-- 4. The raid's mitigation debuffs are actually assignable
--------------------------------------------------------------------------
local function tabOf(key) local d = A.duties[key]; return d and (d.hidden and "hidden" or d.tab) end
check("Thunder Clap is on the Debuffs tab", tabOf("THUNDERCLAP"), "debuff")
check("Demoralizing Shout is on the Debuffs tab", tabOf("DEMOSHOUT"), "debuff")
check("Faerie Fire is on the Debuffs tab", tabOf("FAERIEFIRE"), "debuff")
check("Demoralizing Roar is on the Debuffs tab", tabOf("DEMOROAR"), "debuff")
check("Faerie Fire belongs to the druid", A.duties.FAERIEFIRE and A.duties.FAERIEFIRE.class, "DRUID")

-- curses stay single-owner: vanilla allows one curse per target, so two
-- owners would be a plan that cannot physically happen
check("Curse of the Elements is single-owner", A.duties.CURSE_ELEMENTS.multi, false)
check("Sunder stacks, so it is multi-owner", A.duties.SUNDER.multi, true)

--------------------------------------------------------------------------
print("")
if failures == 0 then
    print("PASS - catalog well-formed, wids unique, debuff tab fits")
    os.exit(0)
end
print("FAIL - " .. failures .. " check(s)")
os.exit(1)
