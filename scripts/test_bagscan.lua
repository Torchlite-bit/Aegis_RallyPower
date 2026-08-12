-- Off-client test for Core/Aegis_BagScan.lua
--
-- Reproduces the mailbox-open storm without a game client: fires N BAG_UPDATE
-- dispatches in a single frame and asserts the expensive inventory scan runs
-- ONCE, not N times. Also covers the uncached-item hold, its time cap, and
-- that non-BAG_UPDATE callers stay synchronous.
--
-- Run:  lua scripts/test_bagscan.lua
-- The addon file under test is Lua 5.0-compatible, so it loads unchanged here.

--------------------------------------------------------------------------
-- Minimal 1.12 API stubs
--------------------------------------------------------------------------
local BAGS = {}            -- BAGS[bag][slot] = { tex=..., link=... or nil }
local scanCalls = 0        -- how many times the REAL scan ran
local frame                -- the OnUpdate frame the addon creates

function GetContainerNumSlots(bag)
    return BAGS[bag] and table.getn(BAGS[bag]) or 0
end

function GetContainerItemInfo(bag, slot)
    local it = BAGS[bag] and BAGS[bag][slot]
    if not it then return nil end
    return it.tex, 1, nil
end

function GetContainerItemLink(bag, slot)
    local it = BAGS[bag] and BAGS[bag][slot]
    if not it then return nil end
    return it.link          -- nil = item not resolved yet (uncached)
end

function CreateFrame(kind, name)
    frame = { scripts = {} }
    function frame:SetScript(which, fn) self.scripts[which] = fn end
    return frame
end

-- the engine function we are wrapping
function PallyPower_ScanInventory()
    scanCalls = scanCalls + 1
end

--------------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------------
local function fillBags(nSlots, resolved)
    BAGS = {}
    for bag = 0, 4 do
        BAGS[bag] = {}
        for slot = 1, nSlots do
            BAGS[bag][slot] = { tex = "tex", link = resolved and "[Item]" or nil }
        end
    end
end

-- one dispatched BAG_UPDATE, exactly as the 1.12 handler shape does it
local function fireBagUpdate()
    event = "BAG_UPDATE"
    PallyPower_ScanInventory()
    event = nil
end

local function frameTick(elapsed)
    arg1 = elapsed or 0.016
    frame.scripts["OnUpdate"]()
    arg1 = nil
end

local failures = 0
local function check(label, got, want)
    if got == want then
        print(string.format("  ok    %-52s %s", label, tostring(got)))
    else
        print(string.format("  FAIL  %-52s got %s, want %s", label, tostring(got), tostring(want)))
        failures = failures + 1
    end
end

--------------------------------------------------------------------------
-- load the real addon file
--------------------------------------------------------------------------
local here = string.gsub(debug.getinfo(1).source, "^@(.*)scripts[/\\][^/\\]*$", "%1")
if here == "" then here = "./" end
local chunk, err = loadfile(here .. "Core/Aegis_BagScan.lua")
if not chunk then print("could not load addon file: " .. tostring(err)); os.exit(1) end
chunk()

print("Aegis_BagScan - mailbox storm")

--------------------------------------------------------------------------
-- 1. THE REGRESSION: 100 BAG_UPDATEs in one frame must cost ONE scan
--------------------------------------------------------------------------
fillBags(20, true)                       -- 5 bags x 20 slots, all resolved
AegisRP.BagScan.Reset(); scanCalls = 0
for i = 1, 100 do fireBagUpdate() end

check("scans during the storm (before any frame)", scanCalls, 0)
frameTick()
check("scans after one frame", scanCalls, 1)

local flushes, coalesced = AegisRP.BagScan.Stats()
check("flushes", flushes, 1)
check("BAG_UPDATE scans folded away", coalesced, 100)

-- further frames with no new events must not rescan
frameTick(); frameTick()
check("idle frames do not rescan", scanCalls, 1)

--------------------------------------------------------------------------
-- 2. Unresolved items: hold rather than broadcast a half-populated count
--------------------------------------------------------------------------
fillBags(20, true)
BAGS[3][7].link = nil                    -- one slot still resolving
AegisRP.BagScan.Reset(); scanCalls = 0
for i = 1, 50 do fireBagUpdate() end
frameTick()
check("held while an item is unresolved", scanCalls, 0)

BAGS[3][7].link = "[Item]"               -- it resolves...
frameTick()
check("scans once resolved", scanCalls, 1)

--------------------------------------------------------------------------
-- 3. The hold is capped, so a never-resolving slot can't wedge the scan
--------------------------------------------------------------------------
fillBags(20, true)
BAGS[2][3].link = nil                    -- never resolves
AegisRP.BagScan.Reset(); scanCalls = 0
fireBagUpdate()
frameTick(1.0); frameTick(1.0); frameTick(1.0); frameTick(1.0)
check("still holding before the cap", scanCalls, 0)
frameTick(1.5)                           -- total 5.5s > HOLD_CAP
check("scans anyway after the cap", scanCalls, 1)

--------------------------------------------------------------------------
-- 4. Non-BAG_UPDATE callers stay synchronous (init reads PP_Symbols at once)
--------------------------------------------------------------------------
fillBags(20, true)
AegisRP.BagScan.Reset(); scanCalls = 0
event = nil
PallyPower_ScanInventory()               -- e.g. PallyPower.lua:1740
check("direct call runs immediately", scanCalls, 1)
local _, c2 = AegisRP.BagScan.Stats()
check("direct call is not coalesced", c2, 0)

--------------------------------------------------------------------------
print("")
if failures == 0 then
    print("PASS - storm of 100 collapsed to 1 scan")
    os.exit(0)
end
print("FAIL - " .. failures .. " check(s)")
os.exit(1)
