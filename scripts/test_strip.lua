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
-- the strip engine looks the vendored engine's movable frames up by name
function getglobal(n) return _G[n] end
-- AegisRP.StripScale branches on the player's class
local playerClass = "PRIEST"
function UnitClass() return playerClass, playerClass end

AegisRP = {}

local here = string.gsub(debug.getinfo(1).source, "^@(.*)scripts[/\\][^/\\]*$", "%1")
if here == "" then here = "./" end
local chunk, err = loadfile(here .. "Core/Aegis_Strip.lua")
if not chunk then print("could not load Aegis_Strip.lua: " .. tostring(err)); os.exit(1) end
chunk()

--------------------------------------------------------------------------
local failures = 0
local ok                     -- reused by several pcall checks below
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
    function f:GetRight() return self.left and (self.left + self.w) end
    function f:GetTop() return self.top end
    function f:GetWidth() return self.w end
    function f:GetHeight() return self.h end
    function f:GetEffectiveScale() return self.scale end
    function f:IsShown() return self.shown end
    function f:Hide() self.shown = false end
    function f:Show() self.shown = true end
    function f:ClearAllPoints() self.cleared = true end
    function f:SetPoint(p, rel, rp, x, y)
        self.anchor = { p = p, rel = rel, rp = rp, x = x, y = y }
        -- only a UIParent anchor gives absolute coordinates; a frame-to-frame
        -- anchor is resolved by the client, so leave our fake position alone
        if rel == UIParent then self.left, self.top = x, y end
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
-- 3b. The vendored engine's own frames are snap targets too.
--
--     A paladin runs the legacy engine and has NO class-buff strip, so their
--     Taunt strip's only sensible neighbour is PallyPowerBuffBar - and until
--     it was added here, the snapper could not see it and the strip had
--     nothing to line up with but the screen edge.
--
--     The bar is also 110 wide while every strip of ours is 100, and its own
--     buttons sit 5px in - so the COLUMN a player sees runs 305..405 for a
--     frame whose left is 300. Snapping FRAME edges lines up two boxes and
--     leaves the two columns 5px out of step, and the column is the only part
--     of either frame anyone can see. The pad in FOREIGN_SNAP is what these
--     assertions pin.
--------------------------------------------------------------------------
AegisRP.strips = {}
local BAR_W = 110                             -- the real PallyPowerBuffBar width
PallyPowerBuffBar = Frame(300, 500, BAR_W, H)

-- 302 is 2px from the bar's FRAME left and 3px from its button column, so an
-- unpadded snapper picks 300 and a padded one picks 305: the one drop that
-- tells the two implementations apart.
f = Frame(302, 200, W, H)
x, y = drop(f)
check("snaps to the bar's button column, not its frame", x, 305)
-- the column is exactly our width, so the left and right candidates are the
-- same number and one snap lines up BOTH sides. That is what the pad buys.
check("...which lines the right edges up as well", x + W, 300 + BAR_W - 5)

x, y = drop(Frame(200, 415, W, H))
check("stacks under the legacy buff bar", y, 410)

PallyPowerBuffBar.shown = false
x, y = drop(Frame(302, 200, W, H))
check("a hidden legacy frame is not a target", x, 302)
PallyPowerBuffBar.shown = true

-- an engine frame that was never created must not error
PallyPowerBuffBar = nil
PallyPowerFrame = nil
ok = pcall(drop, Frame(302, 200, W, H))
check("absent engine frames are skipped", ok, true)

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
ok = pcall(drop, f)
check("a frame with no position is skipped", ok and f.anchor == nil, true)

--------------------------------------------------------------------------
-- PANEL DOCKING
--
-- The options frame and the assignment panel both open centred, so opening
-- both put one on top of the other. Docked they sit side by side - and which
-- SIDE is arithmetic across two independent scales, which is the same class of
-- silently-wrong-not-broken bug the snapping above is tested for. On a screen
-- too narrow for the pair (4:3 and 5:4 are, at 1024 and 960 units) there is a
-- third answer, and getting that one wrong parks a frame off screen.
--------------------------------------------------------------------------
print("")
print("panel docking")

AegisRP.strips = {}
PallyPowerBuffBar = nil
PallyPowerFrame = nil

local PANEL_W, OPTS_W = 760, 360
local function dockPair(panelLeft, panelTop, panelScale, screenW)
    SCREEN_W = screenW or 1365
    AegisRP_AssignFrame  = Frame(panelLeft, panelTop, PANEL_W, 600, panelScale or 1)
    AegisRP_OptionsFrame = Frame(0, 0, OPTS_W, 480, 1)
    return AegisRP.DockPanels()
end

-- 1. Widescreen, panel left of centre: room to the right, so options docks
--    there with the tops aligned.
dockPair(100, 700)
local a = AegisRP_OptionsFrame.anchor
check("docks to the panel's right", a and (a.p .. "/" .. a.rp), "TOPLEFT/TOPRIGHT")
check("...relative to the panel itself", a and a.rel == AegisRP_AssignFrame, true)
check("...with the tops level", a and a.y, 0)

-- 2. Panel pushed to the right edge: no room that side, so it flips to the left
dockPair(1365 - PANEL_W - 20, 700)
a = AegisRP_OptionsFrame.anchor
check("flips to the panel's left", a and (a.p .. "/" .. a.rp), "TOPRIGHT/TOPLEFT")
check("...still relative to the panel", a and a.rel == AegisRP_AssignFrame, true)

-- 3. A 4:3 screen cannot fit 760 + 360 + a gap either side of the panel. The
--    frame must still land ON screen: against the edge with more room, top
--    still aligned, rather than off the side or squarely over the panel.
dockPair(132, 700, 1, 1024)
a = AegisRP_OptionsFrame.anchor
check("no room either side: anchors to the screen", a and (a.p .. "/" .. a.rp),
      "TOPLEFT/BOTTOMLEFT")
check("...against the roomier edge", a and a.x, 1024 - OPTS_W - 6)
check("...top still aligned with the panel", a and a.y, 700)
check("...and fully on screen", a and (a.x >= 0 and a.x + OPTS_W <= 1024), true)

-- panel hard against the LEFT edge: the right side is now the roomy one, but
-- still not roomy enough, so it clamps right rather than flipping
dockPair(0, 700, 1, 1024)
check("left-hugging panel still clamps on screen",
      AegisRP_OptionsFrame.anchor.x, 1024 - OPTS_W - 6)

-- 4. SCALE. The panel carries a grip and the options frame does not, so the
--    fit test has to be in SCREEN pixels. At scale 2 a panel whose own left is
--    100 actually starts at 200 and ends at 960 - which leaves 140px on a
--    1100-wide screen, not the 620 a scale-blind comparison would compute.
--    Getting that backwards docks it to the right and hangs it off the edge.
AegisRP.strips = {}
SCREEN_W = 1100
AegisRP_AssignFrame  = Frame(100, 350, 380, 300, 2)
AegisRP_OptionsFrame = Frame(0, 0, OPTS_W, 480, 1)
AegisRP.DockPanels()
a = AegisRP_OptionsFrame.anchor
check("a scaled panel's room is measured in screen pixels",
      a and (a.p .. "/" .. a.rp), "TOPLEFT/BOTTOMLEFT")
check("...not the 620px a scale-blind test would find", a.rp ~= "TOPRIGHT", true)
-- and the top is converted out of the panel's space into ours: 350 at scale 2
-- is 700 on screen, which is 700 in a frame at scale 1
check("...and the top converts by the scale ratio", a and a.y, 700)

-- 5. Nothing to dock to is not an error, and must not move anything
AegisRP_OptionsFrame:Hide()
check("a hidden options frame docks nothing", AegisRP.DockPanels(), false)
AegisRP_OptionsFrame:Show()
AegisRP_AssignFrame:Hide()
check("a hidden panel docks nothing", AegisRP.DockPanels(), false)
AegisRP_AssignFrame = nil
check("an absent panel docks nothing", AegisRP.DockPanels(), false)
AegisRP_OptionsFrame = nil

--------------------------------------------------------------------------
-- TOPLEVEL, NOT SetFrameLevel
--
-- Raising one of these windows with SetFrameLevel does NOT carry its children:
-- they keep the absolute level they were created at. The window's own frame
-- ends up above its own buttons, and since the window is mouse-enabled (that
-- is how it gets dragged) it then swallows every click meant for them - the
-- frame looks perfectly normal and nothing inside it works.
--
-- That shipped in 1.13.1 and made the options frame dead to the mouse the
-- moment it docked, which is why the absence of a raise is worth an assertion:
-- nothing about the source says "do not add one here".
--------------------------------------------------------------------------
print("")
print("panel z-order")

local win = Frame(100, 400, 360, 480, 1)
win.level = 1
function win:GetFrameLevel() return self.level end
function win:SetFrameLevel(v) self.level = v end
function win:SetToplevel(v) self.toplevel = v end
-- a button created inside the window: one level up, and it must stay there
local childLevel = 2

AegisRP.MakeToplevel(win)
check("marks the window toplevel", win.toplevel, true)
check("...and leaves its frame level alone", win.level, 1)
check("...so its own buttons still sit above it", childLevel > win.level, true)

-- and it must not throw on a client without the call, or on nothing at all
win.SetToplevel = nil
ok = pcall(AegisRP.MakeToplevel, win)
check("a client without SetToplevel is fine", ok, true)
ok = pcall(AegisRP.MakeToplevel, nil)
check("no frame at all is fine", ok, true)

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
check("zero is floored, not obeyed", AegisRP.StripAlpha(0.5), 0.3)
check("...so the state colour still paints", AegisRP.StripAlpha(0.5) > 0, true)

AegisRP_Settings.stripAlpha = 0.05
check("below the floor is raised to it", AegisRP.StripAlpha(0.5), 0.3)

-- 0.15 was the old floor and was still too faint to read as a colour; it must
-- now be raised like any other below-floor value rather than passed through
AegisRP_Settings.stripAlpha = 0.15
check("the old floor is itself now raised", AegisRP.StripAlpha(0.5), 0.3)

AegisRP_Settings.stripAlpha = 0.3
check("exactly the floor is kept", AegisRP.StripAlpha(0.5), 0.3)

AegisRP_Settings.stripAlpha = 1
check("fully opaque is untouched", AegisRP.StripAlpha(0.5), 1)

AegisRP_Settings.stripAlpha = nil

--------------------------------------------------------------------------
-- SCALE RESOLUTION
--
-- Which slider owns a strip's size is class-dependent, and getting it wrong is
-- invisible in the source: a Paladin has no class-buff strip of ours (the
-- legacy buff bar is it), so their Kick and Taunt strips must follow the
-- ENGINE's buff-bar scale. Following uiScale there means following a slider
-- that class never sees, so it stays 1 forever and the strips can never be
-- matched to the bar they dock against.
--------------------------------------------------------------------------
print("")
print("strip engine - scale resolution")

AegisRP_Settings.uiScale = 0.9
AegisRP_Settings.stripScale_kick = nil
PP_PerUser = nil
playerClass = "PRIEST"
check("a non-Paladin follows uiScale", AegisRP.StripScale("kick"), 0.9)

AegisRP_Settings.stripScale_kick = 1.25
check("a per-strip grip scale wins", AegisRP.StripScale("kick"), 1.25)
AegisRP_Settings.stripScale_kick = nil

playerClass = "PALADIN"
PP_PerUser = { scalebar = 1.2 }
check("a Paladin follows the engine's buff-bar scale", AegisRP.StripScale("kick"), 1.2)

AegisRP_Settings.stripScale_kick = 0.7
check("...but their grip scale still wins", AegisRP.StripScale("kick"), 0.7)
AegisRP_Settings.stripScale_kick = nil

-- PP_PerUser belongs to the engine and is absent on eight of nine classes, and
-- missing a key on the ninth (SavedVariables predating it). Neither may throw.
PP_PerUser = nil
check("no engine config falls back instead of erroring", AegisRP.StripScale("kick"), 0.9)
PP_PerUser = {}
check("engine config without the key falls back", AegisRP.StripScale("kick"), 0.9)

playerClass = "PRIEST"
PP_PerUser = { scalebar = 1.2 }
check("a non-Paladin ignores the engine's slider", AegisRP.StripScale("kick"), 0.9)

AegisRP_Settings.uiScale = nil
PP_PerUser = nil
check("nothing set at all is 1.0", AegisRP.StripScale("kick"), 1)
check("...and with no strip key either", AegisRP.StripScale(), 1)
playerClass = "PRIEST"

--------------------------------------------------------------------------
-- STRIP VISIBILITY
--
-- SetStripShown is the single writer for a strip's shown state: the slash
-- commands, the Options checkboxes and a strip's own Toggle all route through
-- it. The invariant worth pinning is that the frame and its saved flag can
-- never disagree - two rival writers is exactly how a strip ends up hidden
-- with a ticked "Show" box, or reappearing on every login after being closed.
--------------------------------------------------------------------------
print("")
print("strip engine - visibility")

AegisRP.strips = {}
AegisRP_Settings.stripHidden_demo = nil
local demo = asStrip("demo", Frame(100, 300, W, H))

check("a fresh strip reads as shown", AegisRP.IsStripShown("demo"), true)

AegisRP.SetStripShown("demo", false)
check("hiding updates the frame", demo:IsShown(), false)
check("...and the saved flag", AegisRP_Settings.stripHidden_demo, true)
check("...and IsStripShown agrees", AegisRP.IsStripShown("demo"), false)

AegisRP.SetStripShown("demo", true)
check("showing updates the frame", demo:IsShown(), true)
check("...and clears the saved flag", AegisRP_Settings.stripHidden_demo, false)
check("...and IsStripShown agrees", AegisRP.IsStripShown("demo"), true)

-- a hidden flag must survive for a strip that has not been built yet, so the
-- choice is not silently lost between logins
AegisRP.strips = {}
AegisRP_Settings.stripHidden_notbuilt = nil
local okUnbuilt = pcall(AegisRP.SetStripShown, "notbuilt", false)
check("an unbuilt strip does not error", okUnbuilt, true)
check("...and still remembers the choice", AegisRP.IsStripShown("notbuilt"), false)

--------------------------------------------------------------------------
print("")
if failures == 0 then
    print("PASS - snapping, docking, z-order, alpha floor, scale and visibility")
    os.exit(0)
end
print("FAIL - " .. failures .. " check(s)")
os.exit(1)
