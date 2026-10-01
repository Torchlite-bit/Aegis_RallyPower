-- Off-client tests for the minimap button's ring arithmetic
-- (the MMB table in Core/Aegis_Core.lua, exposed as AegisRP.MinimapButton).
--
-- The button rides a circle around the minimap at an angle the ENGINE stores
-- (PP_PerUser.minimapbuttonpos, in degrees). Two things make that worth a test
-- rather than an eyeball:
--
--   * it is silently wrong rather than visibly broken. A button a few pixels
--     off the ring, or drifting as the size changes, still looks like a button.
--   * the offsets are TOPLEFT-relative while the thing being placed is a
--     CENTRE on a circle, so every formula carries a half-size term. The
--     engine hardcoded that half-size as 16 for its fixed 32px button, which
--     is exactly what breaks the moment the button can be resized.
--
-- Coordinate reminder: SetPoint("TOPLEFT", Minimap, "TOPLEFT", x, y) measures
-- y UPWARD, so a frame below the minimap's top-left has a negative y.
--
-- Run:  lua scripts/test_minimap.lua

--------------------------------------------------------------------------
-- 1.12 API stubs
--------------------------------------------------------------------------
local FrameMT = {}
FrameMT.__index = function(_, k)
    -- widget methods are CamelCase; data fields the addon sets are not
    if type(k) == "string" and string.find(k, "^%u") then return function() return nil end end
    return nil
end

local function Widget(name)
    local f = setmetatable({ _name = name }, FrameMT)
    function f:SetWidth(v) self._w = v end
    function f:SetHeight(v) self._h = v end
    function f:GetWidth() return self._w or 0 end
    function f:GetHeight() return self._h or 0 end
    function f:GetEffectiveScale() return 1 end
    function f:ClearAllPoints() self.anchor = nil end
    function f:SetPoint(p, rel, rp, x, y) self.anchor = { p = p, rel = rel, rp = rp, x = x, y = y } end
    function f:SetScript(k, fn) self["_s_" .. k] = fn end
    function f:GetScript(k) return self["_s_" .. k] end
    function f:CreateTexture() return Widget() end
    function f:CreateFontString() return Widget() end
    function f:SetParent(v) self._parent = v end
    function f:GetParent() return self._parent or UIParent end
    function f:SetScale(v) self._scale = v end
    function f:GetScale() return self._scale or 1 end
    function f:RegisterForDrag(...) self._drag = arg and arg[1] or nil end
    function f:GetFrameLevel() return 1 end
    function f:GetCenter() return (self._cx or 0), (self._cy or 0) end
    return f
end

function CreateFrame(_, name) local f = Widget(name); if name then _G[name] = f end; return f end
function getglobal(n) return _G[n] end
function setglobal(n, v) _G[n] = v end

UIParent = Widget("UIParent"); UIParent:SetWidth(1024); UIParent:SetHeight(768)
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
function GetTime() return 0 end
function UnitClass() return "Warlock", "WARLOCK" end
function UnitName() return "Tester" end
function UnitExists() return false end
function GetNumRaidMembers() return 0 end
function GetNumPartyMembers() return 0 end
local cursorX, cursorY = 0, 0
function GetCursorPosition() return cursorX, cursorY end
-- this client's cos/sin take DEGREES (the engine relies on it, see CLAUDE.md)
function cos(d) return math.cos(math.rad(d)) end
function sin(d) return math.sin(math.rad(d)) end

SlashCmdList = {}
AegisRP = {}
AegisRP_Settings = {}
PP_PerUser = { minimapbuttonpos = 30 }

local MM = Widget("Minimap"); MM:SetWidth(140); MM:SetHeight(140)
Minimap = MM; _G.Minimap = MM

local here = string.gsub(debug.getinfo(1).source, "^@(.*)scripts[/\\][^/\\]*$", "%1")
if here == "" then here = "./" end
local chunk, err = loadfile(here .. "Core/Aegis_Core.lua")
if not chunk then print("could not load Aegis_Core.lua: " .. tostring(err)); os.exit(1) end
chunk()

local MMB = AegisRP.MinimapButton
if not MMB then print("AegisRP.MinimapButton is not exposed"); os.exit(1) end

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
local function near(label, got, want, tol)
    tol = tol or 0.01
    local d = got - want; if d < 0 then d = -d end
    if d <= tol then
        print(string.format("  ok    %-54s %.3f", label, got))
    else
        print(string.format("  FAIL  %-54s got %.4f, want %.4f", label, got, want))
        failures = failures + 1
    end
end

print("minimap button - size, ring and drag angle")

--------------------------------------------------------------------------
-- 1. Size is clamped, and nonsense falls back to the default
--------------------------------------------------------------------------
AegisRP_Settings.minimapSize = nil
check("no stored size gives the default", MMB.Size(), MMB.DEFAULT_SIZE)
check("...which is smaller than the 32px art", MMB.DEFAULT_SIZE < 32, true)
AegisRP_Settings.minimapSize = 4
check("below the floor clamps up", MMB.Size(), MMB.MIN_SIZE)
AegisRP_Settings.minimapSize = 999
check("above the ceiling clamps down", MMB.Size(), MMB.MAX_SIZE)
AegisRP_Settings.minimapSize = "nonsense"
check("a non-number falls back", MMB.Size(), MMB.DEFAULT_SIZE)
AegisRP_Settings.minimapSize = nil

--------------------------------------------------------------------------
-- 2. The ring is measured off the minimap, not hardcoded
--------------------------------------------------------------------------
local cx, cy, r = MMB.Ring()
check("stock minimap centre x", cx, 70)
check("stock minimap centre y", cy, 70)
check("stock ring radius", r, 80)

MM:SetWidth(200); MM:SetHeight(200)
local cx2, _, r2 = MMB.Ring()
check("a resized minimap moves the centre", cx2, 100)
check("...and the radius follows it", r2, 110)
MM:SetWidth(140); MM:SetHeight(140)

MM:SetWidth(0); MM:SetHeight(0)
local _, _, r3 = MMB.Ring()
check("a minimap with no size falls back to stock", r3, 80)
MM:SetWidth(140); MM:SetHeight(140)

--------------------------------------------------------------------------
-- 3. Position puts the button's CENTRE on the ring
--
-- The whole point of the rewrite: the engine placed a TOPLEFT using a
-- half-size of 16 because its button was always 32. Anything else and the
-- centre leaves the circle.
--------------------------------------------------------------------------
local frame = _G.PallyPowerMinimapButtonFrame or CreateFrame("Frame", "PallyPowerMinimapButtonFrame")

-- where does the button's centre land, relative to the minimap's centre?
local function centreOffset(angle, size)
    PP_PerUser.minimapbuttonpos = angle
    AegisRP_Settings.minimapSize = size
    frame.anchor = nil
    MMB.Position()
    local a = frame.anchor
    if not a then return nil end
    local mcx, mcy = MMB.Ring()
    return (a.x + size / 2) - mcx, (a.y - size / 2) + mcy
end

local function radius(angle, size)
    local dx, dy = centreOffset(angle, size)
    return math.sqrt(dx * dx + dy * dy)
end

near("centre sits on the ring at 0 deg",   radius(0, 26),   80)
near("centre sits on the ring at 30 deg",  radius(30, 26),  80)
near("centre sits on the ring at 135 deg", radius(135, 26), 80)
near("centre sits on the ring at 300 deg", radius(300, 26), 80)

-- the regression the size-awareness exists for
local dx16, dy16 = centreOffset(30, 16)
local dx32, dy32 = centreOffset(30, 32)
near("the same angle is the same place at size 16 and 32 (x)", dx16, dx32)
near("...and in y", dy16, dy32)
near("a 16px button is still on the ring", radius(30, 16), 80)
near("a 32px button is still on the ring", radius(30, 32), 80)

-- direction: the engine's 0 is LEFT of the minimap and 90 is ABOVE it, which
-- is what makes the stored default of 30 land upper-left where players have it
local dx, dy = centreOffset(0, 26)
near("0 deg is left of the minimap (x)", dx, -80)
near("...and level with it (y)", dy, 0)
dx, dy = centreOffset(90, 26)
near("90 deg is above the minimap (y)", dy, 80)
near("...and centred (x)", dx, 0, 0.001)
dx, dy = centreOffset(30, 26)
check("30 deg - the engine default - is up and to the left", dx < 0 and dy > 0, true)

-- A missing stored angle must not place the button at 0 or throw: the engine's
-- own default is 30, and this is the key the PP_PerUser repair exists for.
PP_PerUser.minimapbuttonpos = nil
AegisRP_Settings.minimapSize = 26
frame.anchor = nil
local okPos = pcall(MMB.Position)
check("a missing stored angle does not throw", okPos, true)
local mcx, mcy = MMB.Ring()
local ndx = (frame.anchor.x + 13) - mcx
local ndy = (frame.anchor.y - 13) + mcy
local d30x, d30y = centreOffset(30, 26)
near("...and falls back to the engine's 30, not 0", ndx, d30x)
near("...in y as well", ndy, d30y)
PP_PerUser.minimapbuttonpos = 30

--------------------------------------------------------------------------
-- 4. Atan2 - the drag inverse, and its fallback
--------------------------------------------------------------------------
local real = math.atan2
local quads = { {1,1}, {1,-1}, {-1,1}, {-1,-1}, {0,1}, {0,-1}, {1,0}, {-1,0} }
local worst = 0
math.atan2 = nil                      -- force the hand-rolled branch
for i = 1, table.getn(quads) do
    local y, x = quads[i][1], quads[i][2]
    local d = MMB.Atan2(y, x) - real(y, x)
    if d < 0 then d = -d end
    if d > worst then worst = d end
end
math.atan2 = real
near("the atan2 fallback matches math.atan2 in every quadrant", worst, 0, 1e-9)

-- Drag round-trip, through the REAL handler.
--
-- Driving a copy of the formula from the test would prove nothing: the first
-- version of this did exactly that, and sabotage walked a mirrored drag angle
-- straight past it. So this calls the driver's own OnUpdate with the cursor in
-- a known place, then asks Position() where the button went.
MM._cx, MM._cy = 400, 300            -- the minimap's centre, in screen coords
local drag = MMB.driver and MMB.driver:GetScript("OnUpdate")
check("the drag driver has an OnUpdate", drag ~= nil, true)

-- put the cursor at `deg` around the minimap, run one drag frame, and report
-- where the button's centre ended up relative to the minimap centre
local function dragTo(deg)
    cursorX = MM._cx + 60 * math.cos(math.rad(deg))
    cursorY = MM._cy + 60 * math.sin(math.rad(deg))
    drag()
    AegisRP_Settings.minimapSize = 26
    frame.anchor = nil
    MMB.Position()
    local a = frame.anchor
    local mx, my = MMB.Ring()
    local bx, by = (a.x + 13) - mx, (a.y - 13) + my
    return math.deg(math.atan2(by, bx))
end

-- the button must come to rest in the SAME direction the cursor was in
local function dragErr(deg)
    local got = dragTo(deg)
    local d = got - deg
    while d > 180 do d = d - 360 end
    while d < -180 do d = d + 360 end
    return d
end
near("dragging to 30 deg leaves the button at 30 deg",   dragErr(30),  0)
near("dragging to 170 deg leaves it at 170 deg",         dragErr(170), 0)
near("dragging to 260 deg leaves it at 260 deg",         dragErr(260), 0)
near("dragging to 350 deg leaves it at 350 deg",         dragErr(350), 0)
-- and the cursor's DISTANCE must not matter: the button rides the ring
cursorX, cursorY = MM._cx + 400, MM._cy + 400
drag()
local far = PP_PerUser.minimapbuttonpos
cursorX, cursorY = MM._cx + 5, MM._cy + 5
drag()
near("a far cursor and a near one at the same bearing agree",
     PP_PerUser.minimapbuttonpos, far)

--------------------------------------------------------------------------
-- 5. A button-collector addon has taken the button into a bar of its own
--
-- This is the 1.15.0 bug. Those addons re-parent the button out of the minimap
-- and lay it out in a row, and they may re-apply the size they measured, or
-- pin the button by anchors, after we have set ours - so setting WIDTH silently
-- did nothing and the button stayed 32 against neighbours at ~25. Re-anchoring
-- it to the minimap ring every PLAYER_ENTERING_WORLD was the other half: a tug
-- of war with the bar over where the button lives.
--------------------------------------------------------------------------
print("")
print("minimap button - a collector addon owns the button")

local btnFrame = _G.PallyPowerMinimapButton or CreateFrame("Button", "PallyPowerMinimapButton")
btnFrame:SetParent(frame)
frame:SetParent(MM)
AegisRP_Settings.minimapSize = 26

check("on the minimap, nothing is adopted", MMB.Adopted(), false)
AegisRP_ApplyMinimapButton()
check("...so width carries the size", frame:GetWidth(), 26)
check("...the button too", btnFrame:GetWidth(), 26)
check("...scale stays 1", frame:GetScale(), 1)
check("...and drag is ours", MMB.drag, true)
frame.anchor = nil
AegisRP_ApplyMinimapButton()
check("...and it is placed on the ring", frame.anchor ~= nil, true)

-- now a bar adopts the container
local bar = Widget("SomeButtonBar")
frame:SetParent(bar)
check("a re-parented container reads as adopted", MMB.Adopted(), true)

frame.anchor = nil
AegisRP_ApplyMinimapButton()
check("adopted: width is left at the art's native size", frame:GetWidth(), MMB.ART)
check("...the button too", btnFrame:GetWidth(), MMB.ART)
check("...the size rides on scale instead", frame:GetScale(), 26 / MMB.ART)
check("...which still renders 26 wide", frame:GetWidth() * frame:GetScale(), 26)
check("...placement is left to the bar", frame.anchor, nil)
check("...and drag is handed back", MMB.drag, false)

-- the slider must still move it while adopted
AegisRP_Settings.minimapSize = 20
AegisRP_ApplyMinimapButton()
check("the slider still resizes an adopted button",
      frame:GetWidth() * frame:GetScale(), 20)
AegisRP_Settings.minimapSize = 26

-- a bar that adopts the BUTTON instead of the container counts too
frame:SetParent(MM)
btnFrame:SetParent(bar)
check("a re-parented button reads as adopted", MMB.Adopted(), true)
btnFrame:SetParent(frame)
check("...and putting it back clears it", MMB.Adopted(), false)

-- going back to the minimap must undo the scale, or the two compound
AegisRP_ApplyMinimapButton()
check("back on the minimap, scale returns to 1", frame:GetScale(), 1)
check("...and width carries the size again", frame:GetWidth(), 26)

--------------------------------------------------------------------------
-- 6. The one-time move to the Aegis badge
--------------------------------------------------------------------------
AegisRP_Settings.minimapSkin = nil
AegisRP_Settings.minimapSkinAegis = nil
AegisRP_MigrateMinimapSkin()
check("a character on the old default moves to the badge",
      AegisRP_Settings.minimapSkin, "aegis")

AegisRP_Settings.minimapSkin = "blue"
AegisRP_MigrateMinimapSkin()
check("...but only once - a deliberate blue survives",
      AegisRP_Settings.minimapSkin, "blue")

AegisRP_Settings.minimapSkin = "gold"
AegisRP_Settings.minimapSkinAegis = nil
AegisRP_MigrateMinimapSkin()
check("a character who already chose a skin keeps it",
      AegisRP_Settings.minimapSkin, "gold")

check("the badge is first in the skin list", AegisRP_MinimapSkins[1], "aegis")
check("...and the legacy skins are still there", table.getn(AegisRP_MinimapSkins), 6)

--------------------------------------------------------------------------
print("")
if failures == 0 then
    print("PASS - size clamp, ring placement, drag angle and the skin migration")
    os.exit(0)
end
print("FAIL - " .. failures .. " check(s)")
os.exit(1)
