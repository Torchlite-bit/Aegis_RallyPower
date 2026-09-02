-- Off-client tests for the strip engine's isolable arithmetic
-- (Core/Aegis_Strip.lua): edge snapping, and the backdrop alpha floor.
--
-- Loads the REAL strip engine against stubbed 1.12 APIs and drives
-- AegisRP.SnapStrip with fabricated frame geometry. Snapping is arithmetic
-- that goes silently wrong rather than visibly breaking - a right-edge
-- off-by-one, or an inverted scale conversion between two strips at different
-- grip scales, still "works", it just parks the frame somewhere slightly
-- wrong. That is exactly what an off-client test is for.
--
-- Coordinate reminder, because the assertions depend on it: GetLeft() and
-- GetTop() are measured from the screen's BOTTOM-left, in the frame's OWN
-- scale space. So a frame sits flush against the screen bottom when its top
-- equals its own height, and against the screen top when its top equals the
-- screen height.
--
-- Run:  lua scripts/test_strip.lua

--------------------------------------------------------------------------
-- 1.12 API stubs
--------------------------------------------------------------------------
local SCREEN_W, SCREEN_H = 1024, 768

function CreateFrame(kind, name)
    local f = {}
    function f:RegisterEvent() end
    function f:UnregisterEvent() end
    function f:SetScript() end
    function f:Hide() end
    function f:Show() end
    return f
end

UIParent = {}
function UIParent:GetWidth() return SCREEN_W end
function UIParent:GetHeight() return SCREEN_H end
function UIParent:GetEffectiveScale() return 1 end

DEFAULT_CHAT_FRAME = { AddMessage = function() end }
function GetTime() return 100 end

AegisRP = {}

local here = string.gsub(debug.getinfo(1).source, "^@(.*)scripts[/\\][^/\\]*$", "%1")
if here == "" then here = "./" end
local chunk, err = loadfile(here .. "Core/Aegis_Strip.lua")
if not chunk then print("could not load Aegis_Strip.lua: " .. tostring(err)); os.exit(1) end
chunk()

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

-- A fake strip frame. `left`/`top` are in this frame's own scale space, which
-- is what the real GetLeft()/GetTop() return.
local function Frame(left, top, w, h, scale, shown)
    local f = { left = left, top = top, w = w, h = h,
                scale = scale or 1, shown = (shown ~= false) }
    function f:GetLeft() return self.left end
    function f:GetTop() return self.top end
    function f:GetWidth() return self.w end
    function f:GetHeight() return self.h end
    function f:GetEffectiveScale() return self.scale end
    function f:IsShown() return self.shown end
    function f:ClearAllPoints() self.cleared = true end
    function f:SetPoint(p, rel, rp, x, y)
        self.anchor = { p = p, rp = rp, x = x, y = y }
        self.left, self.top = x, y
    end
    return f
end

-- drop `f` and report where it ended up
local function drop(f)
    f.anchor = nil
    AegisRP.SnapStrip(f)
    return f.left, f.top
end

-- register a frame as a live strip the snapper should consider
local function asStrip(key, f)
    AegisRP.strips[key] = { frame = f }
    return f
end

print("strip engine - edge snapping")

--------------------------------------------------------------------------
-- 1. Screen edges
--------------------------------------------------------------------------
local W, H = 100, 90

local x, y = drop(Frame(5, 400, W, H))
check("near screen left snaps flush", x, 0)

x, y = drop(Frame(SCREEN_W - W - 4, 400, W, H))
check("near screen right snaps flush", x, SCREEN_W - W)

x, y = drop(Frame(400, SCREEN_H - 6, W, H))
check("near screen top snaps flush", y, SCREEN_H)

x, y = drop(Frame(400, H + 7, W, H))
check("near screen bottom snaps flush", y, H)

-- both axes at once
local f = Frame(6, H + 5, W, H)
x, y = drop(f)
check("a corner snaps on both axes (x)", x, 0)
check("a corner snaps on both axes (y)", y, H)
check("...and re-anchors TOPLEFT/BOTTOMLEFT", f.anchor and (f.anchor.p .. "/" .. f.anchor.rp),
      "TOPLEFT/BOTTOMLEFT")

--------------------------------------------------------------------------
-- 2. Out of range: a frame in open space is left exactly where it was dropped
--------------------------------------------------------------------------
f = Frame(400, 400, W, H)
x, y = drop(f)
check("mid-screen is untouched (x)", x, 400)
check("mid-screen is untouched (y)", y, 400)
check("...and is not re-anchored at all", f.anchor, nil)

-- 13px is outside the 12px threshold; 12 itself is the boundary and must NOT
-- grab, or the snap would be inclusive of a distance it advertises as its limit
check("13px away does not snap", (drop(Frame(13, 400, W, H))), 13)
check("12px away does not snap (exclusive)", (drop(Frame(12, 400, W, H))), 12)
check("11px away does snap", (drop(Frame(11, 400, W, H))), 0)

--------------------------------------------------------------------------
-- 3. Strip-to-strip, same scale
--------------------------------------------------------------------------
AegisRP.strips = {}
asStrip("other", Frame(300, 500, W, H))     -- left 300..400, top 500, bottom 410

x, y = drop(Frame(305, 200, W, H))
check("left edges align to another strip", x, 300)

x, y = drop(Frame(398, 200, W, H))
check("sits against its right edge", x, 400)

x, y = drop(Frame(200, 496, W, H))
check("top edges align to another strip", y, 500)

x, y = drop(Frame(200, 414, W, H))
check("stacks directly under it", y, 410)

x, y = drop(Frame(200, 587, W, H))
check("stacks directly above it", y, 590)

--------------------------------------------------------------------------
-- 4. A strip never snaps to ITSELF, and ignores hidden strips
--------------------------------------------------------------------------
AegisRP.strips = {}
local self1 = asStrip("me", Frame(400, 400, W, H))
x, y = drop(self1)
check("a strip ignores its own edges", x, 400)

AegisRP.strips = {}
asStrip("hidden", Frame(300, 500, W, H, 1, false))
x, y = drop(Frame(305, 200, W, H))
check("a hidden strip is not a snap target", x, 305)

--------------------------------------------------------------------------
-- 5. SCALE. The other strip is at 2.0 and we are at 1.0, so its left edge of
--    300 in ITS space sits at 600 in OURS. Getting this backwards is the bug
--    this test exists for: it would snap to 150 and look plain wrong.
--------------------------------------------------------------------------
AegisRP.strips = {}
asStrip("big", Frame(300, 500, W, H, 2))
x, y = drop(Frame(604, 200, W, H, 1))
check("other strip's edge converts by scale ratio", x, 600)
check("the wrong direction (150) is not chosen", x ~= 150, true)

-- and the screen edges scale too: at scale 2 the screen is 512 wide to us
AegisRP.strips = {}
x, y = drop(Frame(SCREEN_W / 2 - W - 5, 200, W, H, 2))
check("screen right is scale-corrected", x, SCREEN_W / 2 - W)

--------------------------------------------------------------------------
-- 6. The option gates it
--------------------------------------------------------------------------
AegisRP.strips = {}
AegisRP_Settings.stripSnap = false
check("snapping off leaves the frame alone", (drop(Frame(3, 400, W, H))), 3)
AegisRP_Settings.stripSnap = true
check("snapping back on resumes", (drop(Frame(3, 400, W, H))), 0)
AegisRP_Settings.stripSnap = nil
check("unset means on (default true)", (drop(Frame(3, 400, W, H))), 0)

--------------------------------------------------------------------------
-- 7. Degenerate geometry is refused rather than crashing: an un-anchored
--    frame returns nil from GetLeft(), which happens before a frame is placed
--------------------------------------------------------------------------
f = Frame(nil, nil, W, H)
local ok = pcall(drop, f)
check("a frame with no position is skipped", ok and f.anchor == nil, true)

--------------------------------------------------------------------------
-- BACKDROP ALPHA FLOOR
--
-- Transparency is one global multiplier on the only thing that carries state
-- (green covered / red needed / grey off). At 0 every state paints the same
-- nothing while the SKIN border keeps drawing, so the strip reads as broken
-- rather than transparent - and because the setting is per character, one alt
-- looks flat while another looks fine. The floor is what stops that.
--------------------------------------------------------------------------
print("")
print("strip engine - backdrop alpha floor")

AegisRP_Settings.stripAlpha = nil
check("unset falls back to the colour's own alpha", AegisRP.StripAlpha(0.5), 0.5)
check("unset honours a different fallback", AegisRP.StripAlpha(0.8), 0.8)

AegisRP_Settings.stripAlpha = 0.75
check("a set value is used as-is", AegisRP.StripAlpha(0.5), 0.75)

AegisRP_Settings.stripAlpha = 0
check("zero is floored, not obeyed", AegisRP.StripAlpha(0.5), 0.15)
check("...so the state colour still paints", AegisRP.StripAlpha(0.5) > 0, true)

AegisRP_Settings.stripAlpha = 0.05
check("below the floor is raised to it", AegisRP.StripAlpha(0.5), 0.15)

AegisRP_Settings.stripAlpha = 0.15
check("exactly the floor is kept", AegisRP.StripAlpha(0.5), 0.15)

AegisRP_Settings.stripAlpha = 1
check("fully opaque is untouched", AegisRP.StripAlpha(0.5), 1)

AegisRP_Settings.stripAlpha = nil

--------------------------------------------------------------------------
print("")
if failures == 0 then
    print("PASS - snapping (edges, strips, scale, gate) and the alpha floor")
    os.exit(0)
end
print("FAIL - " .. failures .. " check(s)")
os.exit(1)
