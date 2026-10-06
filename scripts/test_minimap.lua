-- Off-client tests for the minimap button (the MMB table in
-- Core/Aegis_Core.lua, exposed as AegisRP.MinimapButton).
--
-- Since 1.15.3 RallyPower builds its OWN button the way Aegis: Pathfinder
-- does - one Button, a direct child of the Minimap, anchored by its CENTER -
-- and parks the engine's. Three releases before that tried to dress the
-- engine's button (resize it, scale it, inset its art) and each fixed the size
-- and left the shape: a 32px container with a 32px button pinned to its
-- TOPLEFT, which every minimap-button collector showed spilling down and to
-- the right. Most of what follows guards that shape, because a button that is
-- a few pixels wrong still looks like a button.
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

local function Widget(name, parent)
    local f = setmetatable({ _name = name, _parent = parent, _shown = true }, FrameMT)
    function f:SetWidth(v) self._w = v end
    function f:SetHeight(v) self._h = v end
    function f:GetWidth() return self._w or 0 end
    function f:GetHeight() return self._h or 0 end
    function f:GetEffectiveScale() return 1 end
    function f:SetScale(v) self._scale = v end
    function f:GetScale() return self._scale or 1 end
    function f:Show() self._shown = true end
    function f:Hide() self._shown = false end
    function f:IsShown() return self._shown end
    function f:SetParent(v) self._parent = v end
    function f:GetParent() return self._parent end
    function f:GetName() return self._name end
    function f:ClearAllPoints() self.anchors = {} end
    function f:SetPoint(p, rel, rp, x, y)
        self.anchors = self.anchors or {}
        self.anchors[p] = { rel = rel, rp = rp, x = x or 0, y = y or 0 }
    end
    function f:SetScript(k, fn) self["_s_" .. k] = fn end
    function f:GetScript(k) return self["_s_" .. k] end
    function f:SetTexture(t) self.file = t end
    function f:CreateTexture() return Widget(nil, self) end
    function f:CreateFontString() return Widget(nil, self) end
    function f:GetFrameLevel() return 1 end
    function f:GetCenter() return (self._cx or 0), (self._cy or 0) end
    return f
end

function CreateFrame(_, name, parent)
    local f = Widget(name, parent)
    if name then _G[name] = f end
    return f
end
function getglobal(n) return _G[n] end
function setglobal(n, v) _G[n] = v end

UIParent = Widget("UIParent"); UIParent:SetWidth(1024); UIParent:SetHeight(768)
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
GameTooltip = Widget("GameTooltip")
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

local MM = Widget("Minimap", UIParent); MM:SetWidth(140); MM:SetHeight(140)
Minimap = MM; _G.Minimap = MM

-- The engine's button, as PallyPower/MinimapButton.xml builds it: a 32px
-- container that is the Minimap's child, with a 32px button inside it.
local engineFrame = Widget("PallyPowerMinimapButtonFrame", MM)
engineFrame:SetWidth(32); engineFrame:SetHeight(32)
_G.PallyPowerMinimapButtonFrame = engineFrame
local engineButton = Widget("PallyPowerMinimapButton", engineFrame)
_G.PallyPowerMinimapButton = engineButton

-- the engine globals our button routes to
local clicks = {}
function PallyPower_MinimapButton_OnClick(b) table.insert(clicks, b) end
local credits = 0
function PallyPower_ShowCredits() credits = credits + 1 end
function PallyPower_MinimapButton_Init() engineFrame:Show() end
function PallyPower_MinimapButtonOption()
    PP_PerUser.minimapbuttonshow = (MinimapButtonOptionChk_checked == true)
    engineFrame:Show()
end

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
        print(string.format("  ok    %-56s %s", label, tostring(got)))
    else
        print(string.format("  FAIL  %-56s got %s, want %s", label, tostring(got), tostring(want)))
        failures = failures + 1
    end
end
local function near(label, got, want, tol)
    tol = tol or 0.01
    if type(got) ~= "number" then
        print(string.format("  FAIL  %-56s got %s, want %.4f", label, tostring(got), want))
        failures = failures + 1
        return
    end
    local d = got - want; if d < 0 then d = -d end
    if d <= tol then
        print(string.format("  ok    %-56s %.3f", label, got))
    else
        print(string.format("  FAIL  %-56s got %.4f, want %.4f", label, got, want))
        failures = failures + 1
    end
end

local B = MMB.button

--------------------------------------------------------------------------
-- 1. The shape: our own button, the engine's parked
--------------------------------------------------------------------------
print("minimap button - built like Pathfinder's")

check("a button of our own exists from file load", B ~= nil, true)
check("...named so collectors and /fstack can find it", B and B:GetName(), "AegisRP_MinimapButton")
check("...and it is a DIRECT child of the Minimap", B and B:GetParent(), MM)
check("...hidden until settings are in (rule 10)", B and B:IsShown(), false)

check("the engine's container is no longer the Minimap's child",
      engineFrame:GetParent() ~= MM, true)
check("...it is parked in a frame that is never shown",
      engineFrame:GetParent() == MMB.parking and not MMB.parking:IsShown(), true)
engineFrame:Show()
check("...and the engine calling Show() on it does nothing", engineFrame:IsShown(), false)

AegisRP_Settings.minimapSize = nil
AegisRP_ApplyMinimapButton()
check("applied: shown", B:IsShown(), true)
check("applied: our own button is sized", B:GetWidth(), 26)
check("...square", B:GetHeight(), 26)
check("...and not scaled", B:GetScale(), 1)

-- the art fills the button by BOTH corners, so it can never spill out of it
local ic = MMB.icon
check("the icon is anchored by its top-left corner", ic.anchors.TOPLEFT ~= nil, true)
check("...and by its bottom-right corner", ic.anchors.BOTTOMRIGHT ~= nil, true)
check("...flush with the button at rest", ic.anchors.TOPLEFT.x == 0 and ic.anchors.TOPLEFT.y == 0, true)
check("...to the button itself, not a container", ic.anchors.TOPLEFT.rel, B)

-- pressed: the art sinks one pixel down and right, then comes back
B:GetScript("OnMouseDown")()
check("pressing sinks the art a pixel right", ic.anchors.TOPLEFT.x, 1)
check("...and a pixel down", ic.anchors.TOPLEFT.y, -1)
check("...with the far corner following", ic.anchors.BOTTOMRIGHT.x, 1)
B:GetScript("OnMouseUp")()
check("releasing restores it", ic.anchors.TOPLEFT.x, 0)

-- hover ring
B:GetScript("OnEnter")()
check("hover shows the gold ring", MMB.ring:IsShown(), true)
check("...and the engine's credits tooltip", credits, 1)
B:GetScript("OnLeave")()
check("leaving hides the ring", MMB.ring:IsShown(), false)

-- clicks are the engine's
arg1 = "RightButton"
B:GetScript("OnClick")()
check("a click goes to the engine's handler", clicks[1], "RightButton")

--------------------------------------------------------------------------
-- 2. Size is clamped, and nonsense falls back to the default
--------------------------------------------------------------------------
print("")
print("minimap button - size")
check("no stored size gives Pathfinder's 26", MMB.Size(), 26)
AegisRP_Settings.minimapSize = 4
check("below the floor clamps up", MMB.Size(), MMB.MIN_SIZE)
AegisRP_Settings.minimapSize = 999
check("above the ceiling clamps down", MMB.Size(), MMB.MAX_SIZE)
AegisRP_Settings.minimapSize = "nonsense"
check("a non-number falls back", MMB.Size(), 26)
AegisRP_Settings.minimapSize = 20
AegisRP_ApplyMinimapButton()
check("the slider resizes the button", B:GetWidth(), 20)
AegisRP_Settings.minimapSize = nil
AegisRP_ApplyMinimapButton()

--------------------------------------------------------------------------
-- 3. Placement: CENTER on the ring, so size never enters the arithmetic
--------------------------------------------------------------------------
print("")
print("minimap button - ring placement")

check("stock ring radius", MMB.Radius(), 80)
MM:SetWidth(200)
check("a resized minimap moves the ring with it", MMB.Radius(), 110)
MM:SetWidth(0)
check("a minimap with no size falls back to stock", MMB.Radius(), 80)
MM:SetWidth(140)

local function placed(angle)
    PP_PerUser.minimapbuttonpos = angle
    B.anchors = {}
    MMB.Position()
    return B.anchors.CENTER
end

local c = placed(30)
check("anchored by its CENTER", c ~= nil, true)
check("...to the Minimap's centre", c and c.rel == MM and c.rp == "CENTER", true)
near("on the ring at 30 deg", math.sqrt(c.x * c.x + c.y * c.y), 80)
c = placed(135); near("on the ring at 135 deg", math.sqrt(c.x * c.x + c.y * c.y), 80)
c = placed(300); near("on the ring at 300 deg", math.sqrt(c.x * c.x + c.y * c.y), 80)

-- the engine's convention, so every saved angle still means the same place
c = placed(0);  near("0 deg is LEFT of the minimap", c.x, -80); near("...level with it", c.y, 0)
c = placed(90); near("90 deg is ABOVE it", c.y, 80);           near("...centred", c.x, 0, 0.001)
c = placed(30); check("30 - the engine default - is upper left", c.x < 0 and c.y > 0, true)

-- the size of the button must not move it: this is what CENTER anchoring buys
AegisRP_Settings.minimapSize = 16; AegisRP_ApplyMinimapButton()
local small = placed(30)
AegisRP_Settings.minimapSize = 32; AegisRP_ApplyMinimapButton()
local big = placed(30)
near("a 16px and a 32px button sit at the same x", small.x, big.x)
near("...and the same y", small.y, big.y)
AegisRP_Settings.minimapSize = nil; AegisRP_ApplyMinimapButton()

-- a missing angle must not throw, and falls back to the engine's 30, not 0
PP_PerUser.minimapbuttonpos = nil
B.anchors = {}
check("a missing stored angle does not throw", pcall(MMB.Position), true)
local miss = B.anchors.CENTER
c = placed(30)
near("...and falls back to the engine's 30", miss.x, c.x)
near("...in y as well", miss.y, c.y)

--------------------------------------------------------------------------
-- 4. Dragging, through the real handler
--------------------------------------------------------------------------
print("")
print("minimap button - drag")

local real = math.atan2
local quads = { {1,1}, {1,-1}, {-1,1}, {-1,-1}, {0,1}, {0,-1}, {1,0}, {-1,0} }
local worst = 0
math.atan2 = nil
for i = 1, table.getn(quads) do
    local y, x = quads[i][1], quads[i][2]
    local d = MMB.Atan2(y, x) - real(y, x)
    if d < 0 then d = -d end
    if d > worst then worst = d end
end
math.atan2 = real
near("the atan2 fallback matches math.atan2 in every quadrant", worst, 0, 1e-9)

-- OnDragStart installs the real Dragging handler; drive it with the cursor
-- in a known direction and ask where the button came to rest.
MM._cx, MM._cy = 400, 300
this = B
B:GetScript("OnDragStart")()
local drag = B:GetScript("OnUpdate")
check("drag start installs a per-frame handler", drag ~= nil, true)

local function dragErr(deg)
    cursorX = MM._cx + 60 * math.cos(math.rad(deg))
    cursorY = MM._cy + 60 * math.sin(math.rad(deg))
    drag()
    local a = B.anchors.CENTER
    local got = math.deg(real(a.y, a.x))
    local d = got - deg
    while d > 180 do d = d - 360 end
    while d < -180 do d = d + 360 end
    return d
end
near("dragging to 30 deg leaves the button at 30 deg", dragErr(30), 0)
near("dragging to 170 deg leaves it at 170", dragErr(170), 0)
near("dragging to 260 deg leaves it at 260", dragErr(260), 0)
near("dragging to 350 deg leaves it at 350", dragErr(350), 0)
cursorX, cursorY = MM._cx + 400, MM._cy + 400; drag()
local far = PP_PerUser.minimapbuttonpos
cursorX, cursorY = MM._cx + 5, MM._cy + 5; drag()
near("a far and a near cursor on one bearing agree", PP_PerUser.minimapbuttonpos, far)

B:GetScript("OnDragStop")()
check("drag stop removes the per-frame handler", B:GetScript("OnUpdate"), nil)

--------------------------------------------------------------------------
-- 5. A collector has taken the button into its own grid
--------------------------------------------------------------------------
print("")
print("minimap button - inside a collector's grid")

local bar = Widget("SomeButtonBar")
B:SetParent(bar)
B:SetWidth(22); B:SetHeight(22)        -- the collector's own slot size
check("reads as adopted", MMB.Adopted(), true)
B.anchors = { CENTER = { rel = bar, x = 5, y = 5 } }
AegisRP_ApplyMinimapButton()
check("its size is left to the collector", B:GetWidth(), 22)
check("its position is left to the collector", B.anchors.CENTER.rel, bar)
this = B
B:GetScript("OnDragStart")()
check("and dragging is the collector's too", B:GetScript("OnUpdate"), nil)
B:SetParent(MM)
check("back on the minimap it is ours again", MMB.Adopted(), false)
AegisRP_ApplyMinimapButton()
check("...and sized again", B:GetWidth(), 26)

--------------------------------------------------------------------------
-- 6. Show/hide follows the engine's own setting, through the engine's paths
--------------------------------------------------------------------------
print("")
print("minimap button - show and hide")

PP_PerUser.minimapbuttonshow = false
AegisRP_ApplyMinimapButton()
check("the engine's 'hidden' setting hides ours", B:IsShown(), false)

MinimapButtonOptionChk_checked = true
PallyPower_MinimapButtonOption()       -- what Options' checkbox calls, by name
check("the options checkbox shows ours", B:IsShown(), true)
check("...and the engine's stays parked", engineFrame:IsShown(), false)

MinimapButtonOptionChk_checked = false
PallyPower_MinimapButtonOption()
check("unticking it hides ours", B:IsShown(), false)

PP_PerUser.minimapbuttonshow = true
PallyPower_MinimapButton_Init()        -- the engine's ADDON_LOADED path
check("the engine's Init shows ours", B:IsShown(), true)
check("...and still not its own", engineFrame:IsShown(), false)

-- the engine positions through this global; it must move OUR button
PP_PerUser.minimapbuttonpos = 90
B.anchors = {}
PallyPower_MinimapButton_UpdatePosition()
check("the engine's UpdatePosition places our button", B.anchors.CENTER ~= nil, true)

--------------------------------------------------------------------------
-- 7. Skins: the art is the icon texture
--------------------------------------------------------------------------
print("")
print("minimap button - skins")

AegisRP_ApplyMinimapSkin("gold")
check("a skin change sets the icon's texture",
      ic.file, "Interface\\AddOns\\Aegis_RallyPower\\Icons\\Minimap_gold")
AegisRP_ApplyMinimapSkin("aegis")
check("the badge is the aegis skin",
      ic.file, "Interface\\AddOns\\Aegis_RallyPower\\Icons\\Minimap_aegis")
AegisRP_ApplyMinimapSkin("nonsense")
check("an unknown skin falls back to the badge", AegisRP_Settings.minimapSkin, "aegis")

AegisRP_Settings.minimapSkin = nil
AegisRP_Settings.minimapSkinAegis = nil
AegisRP_MigrateMinimapSkin()
check("a character on the old default moves to the badge", AegisRP_Settings.minimapSkin, "aegis")
AegisRP_Settings.minimapSkin = "blue"
AegisRP_MigrateMinimapSkin()
check("...but only once - a deliberate blue survives", AegisRP_Settings.minimapSkin, "blue")
AegisRP_Settings.minimapSkin = "gold"
AegisRP_Settings.minimapSkinAegis = nil
AegisRP_MigrateMinimapSkin()
check("a character who already chose a skin keeps it", AegisRP_Settings.minimapSkin, "gold")
check("the badge is first in the skin list", AegisRP_MinimapSkins[1], "aegis")
check("...and the five legacy skins are still there", table.getn(AegisRP_MinimapSkins), 6)

--------------------------------------------------------------------------
print("")
if failures == 0 then
    print("PASS - own button, parked engine, ring placement, drag, collectors, show/hide, skins")
    os.exit(0)
end
print("FAIL - " .. failures .. " check(s)")
os.exit(1)
