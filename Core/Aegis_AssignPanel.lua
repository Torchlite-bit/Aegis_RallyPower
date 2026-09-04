--=============================================================================
-- Aegis_AssignPanel.lua  -  "Who covers what" (milestone step 3)
--
-- The raid-leader coordination grid, styled after
-- docs\AegisRP_assignment_concept.html: dark gold-framed panel, five
-- tabs, class-coloured caster rows, chip cells, a coverage line, and the
-- classic PallyPower bottom-button row (Refresh / Clear / Options / Reset
-- Position / Presets).
--
--   Blessings   LIVE against the legacy PallyPower engine: rows are the
--               paladins known from PLPWR SELF broadcasts (AllPallys), cells
--               cycle through PallyPower_PerformCycle/Backwards - the SAME
--               functions the /pp grid uses - so every edit writes the legacy
--               tables and sends the byte-identical ASSIGN message. Paladins
--               on stock PallyPower/PallyPowerTW interoperate unchanged.
--   Totems      shaman x element grid + auto group, over AegisRP_Assign.
--   Raid Buffs   caster x class buff grid (Priest/Mage/Druid), over the model.
--   Debuffs / Utility
--               duty cards from the module-declared catalog: click cycles
--               who's responsible. All non-blessing tabs sync over RPCX
--               (Core\Aegis_Sync.lua) to other AegisRP users.
--
-- TEST MODE seats a full fake 40-man raid of lore characters (every class,
-- with specs) so each tab is exercisable solo. Fake blessing edits stay in a
-- session-only table (the legacy tables and the PLPWR wire are never touched
-- for fake names); fake totem/duty rows live in the normal store and are
-- swept by PruneToRoster when test mode turns off.
--
-- Entry points: right-click a strip's title area, right-click the paladin
-- buff bar (grafted below - PallyPower.lua stays untouched), or /rpc assign.
-- 1.12 rules: pooled rows (frames can't be deleted), implicit this/arg1,
-- Lua 5.0 (table.getn, no #/gmatch/select/%).
--=============================================================================

AegisRP_Settings = AegisRP_Settings or {}

local A = AegisRP.Assign   -- loads before this file (TOC order)

--------------------------------------------------------------------------
-- theme (colors lifted from the concept page)
--------------------------------------------------------------------------

local FRAME_W, FRAME_H = 760, 680
local NAME_W   = 170         -- caster-name + skills column (blessings tab)
local ROW_H    = 40
local CELL_H   = 36          -- concept cells, scaled to fit ten columns
local MAX_ROWS = 8           -- pooled caster rows per grid tab
-- Pooled duty cards, 2 columns x 9 rows. Cards are 46 tall on a 48 pitch from
-- y-46, so row 9 ends at -476; p.hint sits in the bottom ~36px of the panel,
-- which puts the real ceiling just under -493. Do NOT raise this to 20 without
-- moving the hint - the extra row would render underneath it. Overflow is
-- silent (surplus duties simply never draw), so scripts/test_duties.lua
-- asserts the visible debuff duties still fit; raise the copy there too.
local DUTY_POOL = 18

local GOLD        = { 0.78, 0.67, 0.43 }
local GOLD_BRIGHT = { 0.96, 0.88, 0.66 }
local GOLD_DIM    = { 0.48, 0.40, 0.26 }
local INK         = { 0.91, 0.87, 0.78 }
local INK_DIM     = { 0.60, 0.56, 0.47 }
local INK_FAINT   = { 0.44, 0.40, 0.33 }
local OK_GREEN    = { 0.36, 0.88, 0.48 }
local GAP_RED     = { 1.00, 0.42, 0.42 }

local CLASS_RGB = {
    WARRIOR = { 0.78, 0.61, 0.43 }, PALADIN = { 0.96, 0.55, 0.73 },
    HUNTER  = { 0.67, 0.83, 0.45 }, ROGUE   = { 1.00, 0.96, 0.41 },
    PRIEST  = { 0.92, 0.92, 0.92 }, SHAMAN  = { 0.23, 0.63, 1.00 },
    MAGE    = { 0.41, 0.80, 0.94 }, WARLOCK = { 0.58, 0.51, 0.79 },
    DRUID   = { 1.00, 0.49, 0.04 },
}
local ECOL = {
    Earth = { 0.55, 0.35, 0.17 }, Fire = { 0.83, 0.41, 0.12 },
    Water = { 0.18, 0.50, 0.69 }, Air  = { 0.12, 0.62, 0.53 },
}

-- legacy blessing-grid class ids 0-9 (PallyPower's own column order) plus
-- the classic frame's two extra columns: 10 = Aura, 11 = Seal
local CLASS_LABEL = { [0] = "Warrior", "Rogue", "Priest", "Druid", "Paladin",
                      "Hunter", "Mage", "Warlock", "Shaman", "Pet",
                      "Aura", "Seal" }
local BLESS_COLS = 11        -- grid columns run 0..11
local FAKE_MAX = { [10] = 6, [11] = 5 }   -- preview cycle: 7 auras, 6 seals
local BLESS_ROWS = 6         -- blessing rows are tall (two skills strips)
local BLESS_ROW_H = 62

-- display order: Aura and Seal lead the grid (slots 1-2), then the classes
local COL_AT = { [0] = 10, [1] = 11 }
for c = 0, 9 do COL_AT[c + 2] = c end

-- vanilla max ranks (preview paladins only)
local BLESS_MAXRANK = { [0] = 6, 7, 1, 3, 1, 1 }
local AURA_MAXRANK  = { [0] = 7, 5, 1, 3, 3, 3, 1 }

-- aura ids shown in the skills row: Devotion, Retribution, Concentration,
-- Sanctity. The resistance auras are identical on every paladin (no ranks
-- worth comparing, no talents), so they'd only add noise.
local AURA_SHOW = { 0, 1, 2, 6 }

local PANEL_BD = {
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
local CELL_BD = {
    bgFile   = "Interface\\AddOns\\Aegis_RallyPower\\Skins\\Smooth",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false, tileSize = 8, edgeSize = 8,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

-- Icon paths are DISPLAY-ONLY fallbacks for duties of other classes (your own
-- class resolves from the spellbook first). Verify on Turtle; fix here.

-- Totem chip icons, keyed by full spell name. Display-only fallbacks for
-- shamans other than yourself (your own spellbook resolves first, exactly);
-- verify on Turtle and fix here if any icon looks wrong.
local TOTEM_ICONS = {
    ["Strength of Earth Totem"] = "Interface\\Icons\\Spell_Nature_EarthBindTotem",
    ["Stoneskin Totem"]         = "Interface\\Icons\\Spell_Nature_StoneSkinTotem",
    ["Tremor Totem"]            = "Interface\\Icons\\Spell_Nature_TremorTotem",
    ["Earthbind Totem"]         = "Interface\\Icons\\Spell_Nature_StrengthOfEarthTotem02",
    ["Stoneclaw Totem"]         = "Interface\\Icons\\Spell_Nature_StoneClawTotem",
    ["Searing Totem"]           = "Interface\\Icons\\Spell_Fire_SearingTotem",
    ["Magma Totem"]             = "Interface\\Icons\\Spell_Fire_SelfDestruct",
    ["Fire Nova Totem"]         = "Interface\\Icons\\Spell_Fire_SealOfFire",
    ["Flametongue Totem"]       = "Interface\\Icons\\Spell_Nature_GuardianWard",
    ["Frost Resistance Totem"]  = "Interface\\Icons\\Spell_FrostResistanceTotem_01",
    ["Mana Spring Totem"]       = "Interface\\Icons\\Spell_Nature_ManaRegenTotem",
    ["Healing Stream Totem"]    = "Interface\\Icons\\INV_Spear_04",
    ["Mana Tide Totem"]         = "Interface\\Icons\\Spell_Frost_SummonWaterElemental",
    ["Poison Cleansing Totem"]  = "Interface\\Icons\\Spell_Nature_PoisonCleansingTotem",
    ["Disease Cleansing Totem"] = "Interface\\Icons\\Spell_Nature_DiseaseCleansingTotem",
    ["Fire Resistance Totem"]   = "Interface\\Icons\\Spell_FireResistanceTotem_01",
    ["Windfury Totem"]          = "Interface\\Icons\\Spell_Nature_Windfury",
    ["Grace of Air Totem"]      = "Interface\\Icons\\Spell_Nature_InvisibilityTotem",
    ["Nature Resistance Totem"] = "Interface\\Icons\\Spell_Nature_NatureResistanceTotem",
    ["Windwall Totem"]          = "Interface\\Icons\\Spell_Nature_EarthBind",
    ["Grounding Totem"]         = "Interface\\Icons\\Spell_Nature_GroundingTotem",
    ["Sentry Totem"]            = "Interface\\Icons\\Spell_Nature_RemoveCurse",
    ["Tranquil Air Totem"]      = "Interface\\Icons\\Spell_Nature_Brilliance",
}

--------------------------------------------------------------------------
-- test-mode preview raid: 40 lore characters, every class and spec.
-- Session-only names; nothing about them ever reaches the PLPWR wire.
--------------------------------------------------------------------------

local ROSTER40 = {
    { "Varian",     "WARRIOR", "Protection" },
    { "Grommash",   "WARRIOR", "Fury" },
    { "Saurfang",   "WARRIOR", "Arms" },
    { "Muradin",    "WARRIOR", "Fury" },
    { "Broxigar",   "WARRIOR", "Arms" },
    { "Garrosh",    "WARRIOR", "Fury" },
    { "Valeera",    "ROGUE",   "Combat" },
    { "Garona",     "ROGUE",   "Subtlety" },
    { "Mathias",    "ROGUE",   "Assassination" },
    { "Vanessa",    "ROGUE",   "Combat" },
    { "Rexxar",     "HUNTER",  "Beast Mastery" },
    { "Alleria",    "HUNTER",  "Marksmanship" },
    { "Sylvanas",   "HUNTER",  "Marksmanship" },
    { "Halduron",   "HUNTER",  "Survival" },
    { "Jaina",      "MAGE",    "Frost" },
    { "Khadgar",    "MAGE",    "Arcane" },
    { "Antonidas",  "MAGE",    "Frost" },
    { "Rhonin",     "MAGE",    "Fire" },
    { "Aegwynn",    "MAGE",    "Arcane" },
    { "Guldan",     "WARLOCK", "Destruction" },
    { "Wilfred",    "WARLOCK", "Affliction" },
    { "Ritssyn",    "WARLOCK", "Demonology" },
    { "Kanrethad",  "WARLOCK", "Destruction" },
    { "Anduin",     "PRIEST",  "Holy" },
    { "Velen",      "PRIEST",  "Discipline" },
    { "Tyrande",    "PRIEST",  "Holy" },
    { "Moira",      "PRIEST",  "Shadow" },
    { "Benedictus", "PRIEST",  "Holy" },
    { "Whitemane",  "PRIEST",  "Discipline" },
    { "Malfurion",  "DRUID",   "Restoration" },
    { "Cenarius",   "DRUID",   "Balance" },
    { "Hamuul",     "DRUID",   "Restoration" },
    { "Fandral",    "DRUID",   "Feral" },
    { "Thrall",     "SHAMAN",  "Enhancement" },
    { "Drekthar",   "SHAMAN",  "Restoration" },
    { "Nobundo",    "SHAMAN",  "Elemental" },
    { "Rehgar",     "SHAMAN",  "Enhancement" },
    { "Uther",      "PALADIN", "Holy" },
    { "Arthas",     "PALADIN", "Retribution" },
    { "Tirion",     "PALADIN", "Protection" },
}
local FAKE, SPEC, FAKE_GROUP = {}, {}, {}
for i, r in ipairs(ROSTER40) do
    FAKE[r[1]] = r[2]; SPEC[r[1]] = r[3]
    FAKE_GROUP[r[1]] = math.floor((i - 1) / 5) + 1   -- groups 1-8, five a group
end
-- Exposed so the sync + prune layers can tell preview names from real ones:
-- fake rows are editable/visible for solo testing but never touch the wire
-- and survive a roster change while test mode is on.
AegisRP.PreviewNames = FAKE

--------------------------------------------------------------------------
-- shared state + small helpers
--------------------------------------------------------------------------

local frame                  -- the panel (created lazily)
local tabBtns  = {}
local panels   = {}
local currentTab
local pills    = {}

-- Preview-paladin blessings: [fakePally][classID] = bid. Saved with the
-- settings so they survive /reload while test mode stays on (the Core clears
-- the table when test mode turns off); the legacy tables and the PLPWR wire
-- never see fake names.
local function TestBless()
    AegisRP_Settings.testBless = AegisRP_Settings.testBless or {}
    return AegisRP_Settings.testBless
end

local TAB_INFO = {
    { label = "Blessings",  live = true  },
    { label = "Totems",     live = false },
    { label = "Raid Buffs", live = false },
    { label = "Debuffs",    live = false },
    { label = "Rotations",  live = true  },   -- kick + taunt trackers (live CDs)
    { label = "Roles",      live = true  },   -- tanks/healers ride PLPWR
    { label = "Crowd Ctrl", live = false },   -- one row per raid mark
}
-- tab 4 is the debuff duty-card list; tab 3 is the caster x class buff grid;
-- tab 5 is the kick/taunt rotation tracker; tab 6 is the roles grid; tab 7 is
-- the crowd-control mark list.
local DUTY_TAB = { [4] = "debuff" }

local function Me() return UnitName("player") end

local function Msg(t)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffff00Aegis:|r " .. t)
end

local function TitleCase(s)
    if not s then return "?" end
    return string.upper(string.sub(s, 1, 1)) .. string.lower(string.sub(s, 2))
end

-- May I edit OTHER people's rows? Lead/assist, or Free Assignment is on
-- (test mode leads; solo leads). Single source of truth: the model's gate.
local function LeaderLike()
    return A.IAmLead() or A.GetFreeAssign()
end

-- Group members of one class token: you first, then the real roster, then
-- (test mode) the preview raid's members of that class.
local function MembersOfClass(token)
    local out, seen = {}, {}
    local function add(name)
        if name and not seen[name] then seen[name] = true; table.insert(out, name) end
    end
    local _, mycls = UnitClass("player")
    if mycls == token then add(Me()) end
    local n = GetNumRaidMembers()
    if n > 0 then
        for i = 1, n do
            local u = "raid" .. i
            local _, cls = UnitClass(u)
            if cls == token then add(UnitName(u)) end
        end
    else
        for i = 1, GetNumPartyMembers() do
            local u = "party" .. i
            local _, cls = UnitClass(u)
            if cls == token then add(UnitName(u)) end
        end
    end
    if AegisRP.IsTestMode() then
        for _, r in ipairs(ROSTER40) do
            if r[2] == token then add(r[1]) end
        end
    end
    return out
end

-- Row subtitle: "Holy Paladin *" for preview raiders, "Paladin - you" for
-- yourself, plain class for everyone else.
local function SubFor(name, token)
    if AegisRP.IsTestMode() and FAKE[name] and name ~= Me() then
        return (SPEC[name] or "") .. " " .. TitleCase(FAKE[name]) .. " |cffff8800*|r"
    end
    if name == Me() then return TitleCase(token) .. " - you" end
    return TitleCase(token)
end

local function ElementList()
    if A and table.getn(A.elements) > 0 then return A.elements end
    return { "Earth", "Fire", "Water", "Air" }
end

-- 9px/10px themed FontString factory
local function Fnt(parent, size, c, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetFont("Fonts\\FRIZQT__.TTF", size)
    fs:SetTextColor(c[1], c[2], c[3])
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

-- skinned clickable cell (grid cells, chips, cards all start here)
local function MakeCell(parent, w, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(w); b:SetHeight(h)
    b:SetBackdrop(CELL_BD)
    b:SetBackdropColor(0.10, 0.088, 0.07, 0.92)
    b:SetBackdropBorderColor(0.05, 0.05, 0.05, 1)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:EnableMouseWheel(true)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b); hl:SetTexture(1, 1, 1, 0.13)
    return b
end

-- Real spell tooltip (name, rank, description) when the spell is in YOUR
-- spellbook, so the assigner can read what each spell does; the caller
-- appends assignment context after it. Returns false when the spell isn't
-- known so the caller draws its plain header instead.
local function SpellTip(owner, spellName)
    if not spellName then return false end
    local sp = AegisRP.FindSpell and AegisRP.FindSpell(spellName)
    if not sp or not sp.index then return false end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetSpell(sp.index, "spell")   -- literal: BOOKTYPE_SPELL may not exist
    return true
end

-- OnEnter errors die silently in 1.12 (the tooltip just never appears), so
-- every tooltip handler goes through this: failures print like the panel's
-- refresh errors instead of vanishing.
local function SafeTip(fn)
    return function()
        local ok, err = pcall(fn)
        if not ok then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff5555Aegis error:|r "
                .. tostring(err) .. " |cffaaaaaa(tooltip)|r")
        end
    end
end

local RefreshCurrent   -- forward declaration (handlers below close over it)

--------------------------------------------------------------------------
-- BLESSINGS TAB - live rows through the legacy engine; preview rows local
--------------------------------------------------------------------------

local blessRows   = {}
local blessHeader = {}

-- A row is a "preview" row when the name is a test-raid paladin that the
-- legacy engine does NOT know (a real guildie named Uther stays real).
local function IsFakeRow(name)
    if not AegisRP.IsTestMode() then return false end
    if AllPallys and AllPallys[name] then return false end
    return FAKE[name] == "PALADIN"
end

-- Paladin rows: you first, the real AllPallys sorted, then the preview raid.
local function PallyList()
    local out, seen = {}, {}
    if AllPallys then
        for name in pairs(AllPallys) do
            if not seen[name] then seen[name] = true; table.insert(out, name) end
        end
    end
    table.sort(out)
    for i, n in ipairs(out) do
        if n == Me() then table.remove(out, i); table.insert(out, 1, n); break end
    end
    if AegisRP.IsTestMode() then
        for _, r in ipairs(ROSTER40) do
            if r[2] == "PALADIN" and not seen[r[1]] then
                seen[r[1]] = true; table.insert(out, r[1])
            end
        end
    end
    return out
end

local function BlessBid(pally, class)
    local bid
    if IsFakeRow(pally) then
        local t = TestBless()[pally]
        bid = t and t[class]
    elseif class == 10 then
        bid = PallyPower_AuraAssignments and PallyPower_AuraAssignments[pally]
    elseif class == 11 then
        bid = PallyPower_SealAssignments and PallyPower_SealAssignments[pally]
    else
        local t = PallyPower_Assignments and PallyPower_Assignments[pally]
        bid = t and t[class]
    end
    if bid == nil then bid = -1 end
    return bid
end

-- icon / localized name for a column's assignment (10 = aura, 11 = seal)
local function BlessIconFor(class, bid)
    if class == 10 then return AuraIcons and AuraIcons[bid] end
    if class == 11 then return SealIcons and SealIcons[bid] end
    return BlessingIcon and BlessingIcon[bid]
end

local function BlessNameFor(class, bid)
    local t
    if class == 10 then t = PallyPower_AuraID
    elseif class == 11 then t = PallyPower_SealID
    else t = PallyPower_BlessingID end
    return t and t[bid]
end

-- Full spellbook name for a cell. The legacy ID tables hold SHORT names
-- ("Wisdom", "Retribution", "the Crusader") - rebuilt here with the same
-- patterns the locale scans with ("Blessing of (.*)", "(.*) Aura",
-- "Seal of (.*)"), so FindSpell can hit the real spellbook entry and the
-- tooltip can show the actual spell text.
local function BlessSpellName(class, bid)
    local short = BlessNameFor(class, bid)
    if not short then return nil end
    if class == 10 then return short .. " Aura" end
    if class == 11 then return "Seal of " .. short end
    return "Blessing of " .. short
end

-- letter fallback when the icon tables aren't populated (odd class states)
local function BlessAbbrev(class, bid)
    local n = BlessNameFor(class, bid)
    if not n then return "?" end
    local _, _, w = string.find(n, "of%s+(%a+)")
    return string.sub(w or n, 1, 2)
end

-- Per-paladin blessing skills (icon strip under the name, like the classic
-- frame's left column): [bid 0-5] = { rank, talent } plus the Symbol of Kings
-- count. Real paladins come from AllPallys (SELF/SYMCOUNT broadcasts);
-- preview paladins get max ranks with +5 talent on their spec's blessing.
local function SkillsFor(pally)
    if IsFakeRow(pally) then
        local talentBid = (SPEC[pally] == "Holy") and 0 or 1  -- Wisdom / Might
        local out = {}
        for id = 0, 5 do
            out[id] = { rank = BLESS_MAXRANK[id], talent = (id == talentBid) and 5 or 0 }
        end
        return out, 20
    end
    local sk = AllPallys and AllPallys[pally]
    if not sk then return nil end
    return sk, sk.symbols
end

-- Aura ranks/talents for the second skills row (talents improve auras, so
-- the assigner can see who's best specced for the aura duty).
local function AuraSkillsFor(pally)
    if IsFakeRow(pally) then
        local out = {}
        for id = 0, 6 do
            local tal = 0
            if SPEC[pally] == "Protection" and id == 0 then tal = 5 end   -- Devotion
            if SPEC[pally] == "Retribution" and id == 1 then tal = 3 end  -- Retribution
            out[id] = { rank = AURA_MAXRANK[id], talent = tal }
        end
        return out
    end
    return AllPallysAuras and AllPallysAuras[pally]
end

local function BlessCycle(pally, class, dir)
    if IsFakeRow(pally) then
        -- preview store only: the wire and the legacy tables never see fakes
        local tb = TestBless()
        tb[pally] = tb[pally] or {}
        local cur = tb[pally][class]
        if cur == nil then cur = -1 end
        if class == 10 then
            -- cycle only the rankable auras (resistances skipped)
            local n = table.getn(AURA_SHOW)
            local idx = 0
            for i = 1, n do if AURA_SHOW[i] == cur then idx = i end end
            idx = idx + dir
            if idx > n then idx = 0 elseif idx < 0 then idx = n end
            cur = (idx > 0) and AURA_SHOW[idx] or -1
        else
            local top = FAKE_MAX[class] or 5
            cur = cur + dir
            if cur > top then cur = -1 elseif cur < -1 then cur = top end
        end
        if IsShiftKeyDown() and class <= 9 then
            for c = 0, 9 do tb[pally][c] = cur end   -- aura/seal excluded, as legacy
        else
            tb[pally][class] = cur
        end
        RefreshCurrent()
        return
    end
    if not (PallyPower_CanControl and PallyPower_CanControl(pally)) then
        Msg("You can't assign for " .. pally .. " (need lead/assist, or their Free Assign).")
        return
    end
    if class == 10 then
        -- Aura cycling skips the resistance auras (identical on every
        -- paladin). Same table write + byte-identical AASSIGN message the
        -- legacy right-click clear path sends; the legacy aura cycle itself
        -- can't filter (PallyPower.lua stays untouched).
        PallyPower_AuraAssignments = PallyPower_AuraAssignments or {}
        local known = AllPallysAuras and AllPallysAuras[pally]
        local list = {}
        for i = 1, table.getn(AURA_SHOW) do
            local id = AURA_SHOW[i]
            if (not known) or known[id] then table.insert(list, id) end
        end
        local n = table.getn(list)
        local cur = PallyPower_AuraAssignments[pally]
        if cur == nil then cur = -1 end
        local idx = 0
        for i = 1, n do if list[i] == cur then idx = i end end
        idx = idx + dir
        if idx > n then idx = 0 elseif idx < 0 then idx = n end
        local aid = (idx > 0) and list[idx] or -1
        PallyPower_AuraAssignments[pally] = aid
        if PallyPower_SendMessage then
            PallyPower_SendMessage("AASSIGN " .. pally .. " " .. aid)
        end
        if PallyPower_UpdateUI then pcall(PallyPower_UpdateUI) end
        RefreshCurrent()
        return
    end
    -- the legacy cycle assumes the row table exists (ParseMessage creates it)
    PallyPower_Assignments[pally] = PallyPower_Assignments[pally] or {}
    if dir < 0 then
        PallyPower_PerformCycleBackwards(pally, class, false)
    else
        PallyPower_PerformCycle(pally, class, false)
    end
    RefreshCurrent()
end

local function BlessCellClick()
    BlessCycle(this.pally, this.classID, (arg1 == "RightButton") and -1 or 1)
end

local function BlessCellWheel()
    BlessCycle(this.pally, this.classID, (arg1 and arg1 > 0) and -1 or 1)
end

local function BlessCellTip()
    if AegisRP_Settings.tooltips == false then return end
    local pally, class = this.pally, this.classID
    local bid = BlessBid(pally, class)
    local spellName = (bid >= 0) and BlessNameFor(class, bid) or nil
    -- real spell tooltip first (description readable by the assigner),
    -- assignment context appended under it
    if spellName and SpellTip(this, BlessSpellName(class, bid)) then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(pally .. "  -  " .. (CLASS_LABEL[class] or "?"), 1, 1, 1)
    else
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(pally .. "  -  " .. (CLASS_LABEL[class] or "?"), 1, 1, 1)
        if spellName then
            GameTooltip:AddLine(spellName, 0.5, 1, 0.5)
        else
            local what = (class == 10 and "aura") or (class == 11 and "seal") or "blessing"
            GameTooltip:AddLine("No " .. what .. " assigned", 0.7, 0.7, 0.7)
        end
    end
    GameTooltip:AddLine("Click: next  -  Right-click: previous  -  Wheel: cycle", 0.6, 0.6, 0.6)
    if class <= 9 then
        GameTooltip:AddLine("Shift: set ALL classes at once", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

local function BuildBlessings(p)
    -- column headers: Aura and Seal lead, then class icons (COL_AT order)
    for pos = 0, BLESS_COLS do
        local c = COL_AT[pos]
        local t = p:CreateTexture(nil, "ARTWORK")
        t:SetWidth(24); t:SetHeight(24)
        t:SetPoint("TOPLEFT", p, "TOPLEFT", NAME_W + pos * 44 + 9, -42)
        local l = Fnt(p, 8, c >= 10 and GOLD or INK_DIM, "CENTER")
        l:SetWidth(44); l:SetHeight(9)
        l:SetPoint("TOPLEFT", p, "TOPLEFT", NAME_W + pos * 44 - 1, -68)
        l:SetText(CLASS_LABEL[c])
        blessHeader[c] = t
    end
    -- separator between the name/skills column and the assignment grid
    local sep = p:CreateTexture(nil, "ARTWORK")
    sep:SetTexture(0.78, 0.67, 0.43)
    sep:SetAlpha(0.25)
    sep:SetWidth(1); sep:SetHeight(44 + BLESS_ROWS * BLESS_ROW_H)
    sep:SetPoint("TOPLEFT", p, "TOPLEFT", NAME_W - 12, -40)
    for r = 1, BLESS_ROWS do
        local row = { cells = {}, skillIcon = {}, skillText = {},
                      auraIcon = {}, auraText = {} }
        local y = -84 - (r - 1) * BLESS_ROW_H
        row.name = Fnt(p, 11, INK)
        row.name:SetWidth(NAME_W - 22); row.name:SetHeight(12)
        row.name:SetPoint("TOPLEFT", p, "TOPLEFT", 6, y - 2)
        row.sub = Fnt(p, 8, INK_FAINT)
        row.sub:SetWidth(NAME_W - 22); row.sub:SetHeight(9)
        row.sub:SetPoint("TOPLEFT", p, "TOPLEFT", 6, y - 15)
        -- skills strip 1: the paladin's six blessings, rank+talent on each icon
        for id = 0, 5 do
            local si = p:CreateTexture(nil, "ARTWORK")
            si:SetWidth(16); si:SetHeight(16)
            si:SetPoint("TOPLEFT", p, "TOPLEFT", 6 + id * 22, y - 26)
            si:Hide()
            local st = Fnt(p, 8, GOLD_BRIGHT, "RIGHT")
            st:SetWidth(24); st:SetHeight(9)
            st:SetPoint("BOTTOMRIGHT", si, "BOTTOMRIGHT", 4, -2)
            row.skillIcon[id] = si
            row.skillText[id] = st
        end
        -- skills strip 2: the rankable auras (resistance auras skipped -
        -- identical on every paladin)
        for i = 1, table.getn(AURA_SHOW) do
            local id = AURA_SHOW[i]
            local si = p:CreateTexture(nil, "ARTWORK")
            si:SetWidth(16); si:SetHeight(16)
            si:SetPoint("TOPLEFT", p, "TOPLEFT", 6 + (i - 1) * 22, y - 45)
            si:Hide()
            local st = Fnt(p, 8, GOLD_BRIGHT, "RIGHT")
            st:SetWidth(24); st:SetHeight(9)
            st:SetPoint("BOTTOMRIGHT", si, "BOTTOMRIGHT", 4, -2)
            row.auraIcon[id] = si
            row.auraText[id] = st
        end
        for pos = 0, BLESS_COLS do
            local c = COL_AT[pos]
            local b = MakeCell(p, 42, CELL_H)
            -- vertically centred against the 62px row (name + two skill strips)
            b:SetPoint("TOPLEFT", p, "TOPLEFT", NAME_W + pos * 44,
                y - (BLESS_ROW_H - CELL_H) / 2)
            b.classID = c
            local icon = b:CreateTexture(nil, "ARTWORK")
            icon:SetWidth(28); icon:SetHeight(28)
            icon:SetPoint("CENTER", b, "CENTER", 0, 0)
            b.icon = icon
            local txt = Fnt(b, 12, GOLD_BRIGHT, "CENTER")
            txt:SetPoint("CENTER", b, "CENTER", 0, 0)
            b.text = txt
            b:SetScript("OnClick", BlessCellClick)
            b:SetScript("OnMouseWheel", BlessCellWheel)
            b:SetScript("OnEnter", SafeTip(BlessCellTip))
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            b:Hide()
            row.cells[c] = b
        end
        blessRows[r] = row
    end
end

local function RefreshBlessings(p)
    for c = 0, 9 do
        if PallyPower_ClassTexture and PallyPower_ClassTexture[c] then
            blessHeader[c]:SetTexture(PallyPower_ClassTexture[c])
        end
    end
    if AuraIcons and AuraIcons[0] then blessHeader[10]:SetTexture(AuraIcons[0]) end
    if SealIcons and SealIcons[0] then blessHeader[11]:SetTexture(SealIcons[0]) end
    local pallys = PallyList()
    local pc = CLASS_RGB.PALADIN
    for r = 1, BLESS_ROWS do
        local row = blessRows[r]
        local pally = pallys[r]
        if pally then
            local fake = IsFakeRow(pally)
            local control = fake or (PallyPower_CanControl and PallyPower_CanControl(pally))
            row.name:SetText(pally)
            row.name:SetTextColor(pc[1], pc[2], pc[3])
            -- sub line carries the Symbol of Kings count (SYMCOUNT broadcasts)
            local sk, symbols = SkillsFor(pally)
            local sub = SubFor(pally, "PALADIN")
            if symbols then
                sub = sub .. "  |cffffe080" .. symbols .. " sym|r"
            end
            row.sub:SetText(sub)
            -- skills strip 1: available blessings, "rank+talent" on each icon
            for id = 0, 5 do
                local entry = sk and sk[id]
                if type(entry) == "table" and entry.rank then
                    row.skillIcon[id]:SetTexture(BlessingIcon and BlessingIcon[id])
                    row.skillIcon[id]:Show()
                    local tal = tonumber(entry.talent) or 0
                    row.skillText[id]:SetText(entry.rank .. (tal > 0 and ("+" .. tal) or ""))
                    row.skillText[id]:Show()
                else
                    row.skillIcon[id]:Hide()
                    row.skillText[id]:Hide()
                end
            end
            -- skills strip 2: their rankable auras with rank+talent
            local ak = AuraSkillsFor(pally)
            for i = 1, table.getn(AURA_SHOW) do
                local id = AURA_SHOW[i]
                local entry = ak and ak[id]
                if type(entry) == "table" and entry.rank then
                    row.auraIcon[id]:SetTexture(AuraIcons and AuraIcons[id])
                    row.auraIcon[id]:Show()
                    local tal = tonumber(entry.talent) or 0
                    row.auraText[id]:SetText(entry.rank .. (tal > 0 and ("+" .. tal) or ""))
                    row.auraText[id]:Show()
                else
                    row.auraIcon[id]:Hide()
                    row.auraText[id]:Hide()
                end
            end
            for c = 0, BLESS_COLS do
                local b = row.cells[c]
                b.pally = pally
                local bid = BlessBid(pally, c)
                if bid >= 0 then
                    local tex = BlessIconFor(c, bid)
                    if tex then
                        b.icon:SetTexture(tex)
                        b.icon:Show()
                        b.text:SetText("")
                    else
                        b.icon:Hide()
                        b.text:SetText(BlessAbbrev(c, bid))
                    end
                    b.icon:SetAlpha(control and 1 or 0.4)
                    b:SetBackdropColor(0.13, 0.115, 0.085, 0.95)
                else
                    b.icon:Hide()
                    b.text:SetText("+")
                    b.text:SetTextColor(INK_FAINT[1], INK_FAINT[2], INK_FAINT[3])
                    b:SetBackdropColor(0.10, 0.088, 0.07, 0.6)
                end
                if bid >= 0 then
                    b.text:SetTextColor(GOLD_BRIGHT[1], GOLD_BRIGHT[2], GOLD_BRIGHT[3])
                end
                b:Show()
            end
        else
            row.name:SetText(""); row.sub:SetText("")
            for id = 0, 5 do
                row.skillIcon[id]:Hide(); row.skillText[id]:Hide()
            end
            for i = 1, table.getn(AURA_SHOW) do
                row.auraIcon[AURA_SHOW[i]]:Hide()
                row.auraText[AURA_SHOW[i]]:Hide()
            end
            for c = 0, BLESS_COLS do row.cells[c]:Hide() end
        end
    end
    -- coverage: any class (pets excluded) nobody blesses
    if table.getn(pallys) == 0 then
        p.cover:SetText("")
        p.hint:SetText("No paladins known yet - they appear when they broadcast on PLPWR "
            .. "(group with one, or /rpc test for the preview raid).")
        return
    end
    local gaps = {}
    for c = 0, 8 do
        local got = false
        for _, pl in ipairs(pallys) do
            if BlessBid(pl, c) >= 0 then got = true end
        end
        if not got then table.insert(gaps, CLASS_LABEL[c]) end
    end
    if table.getn(gaps) == 0 then
        p.cover:SetTextColor(OK_GREEN[1], OK_GREEN[2], OK_GREEN[3])
        p.cover:SetText("Coverage: every class has a blessing.")
    else
        p.cover:SetTextColor(GAP_RED[1], GAP_RED[2], GAP_RED[3])
        p.cover:SetText("No blessing: " .. table.concat(gaps, ", "))
    end
    p.hint:SetText("Click a cell to cycle that paladin's blessing, aura or seal "
        .. "(right-click backwards, shift = all classes). Byte-compatible with stock PallyPower.")
end

--------------------------------------------------------------------------
-- TOTEMS TAB - party column + shaman x element chips, over the model
--------------------------------------------------------------------------

local totemRows = {}
local PARTY_W, ELEM_W = 64, 116

local function ShortTotem(name)
    if not name then return nil end
    name = string.gsub(name, " Totem$", "")
    name = string.gsub(name, "^Strength of ", "Str. of ")
    name = string.gsub(name, " Resistance$", " Res.")
    return name
end

local function CycleTotem(shaman, element, dir)
    local list = A.totems[element] or {}
    local n = table.getn(list)
    if n == 0 then return end
    local cur = A.GetTotem(shaman, element)
    local idx = 0
    for i = 1, n do if list[i].name == cur then idx = i end end
    idx = idx + dir
    if idx > n then idx = 0 elseif idx < 0 then idx = n end
    local ok = A.SetTotem(shaman, element, (idx > 0) and list[idx].name or nil)
    if not ok then Msg("You can't assign for " .. shaman .. " (need lead/assist).") end
    RefreshCurrent()
end

-- The group column is AUTOMATIC: totems only reach the shaman's own
-- subgroup, so showing anything else would let assignments disagree with
-- reality. Real members come from the raid roster; preview raiders have
-- fixed groups (five a group).
local function GroupOf(name)
    local n = GetNumRaidMembers()
    if n > 0 then
        for i = 1, n do
            local rname, _, subgroup = GetRaidRosterInfo(i)
            if rname == name then return subgroup end
        end
    end
    if AegisRP.IsTestMode() and FAKE_GROUP[name] then
        return FAKE_GROUP[name]
    end
    return 1
end

-- Chip icon for a totem: your own spellbook first (exact), static fallback
-- for other shamans' totems.
local function TotemIconFor(totemName)
    if not totemName then return nil end
    local sp = AegisRP.FindSpell and AegisRP.FindSpell(totemName)
    if sp and sp.texture then return sp.texture end
    return TOTEM_ICONS[totemName]
end

local function TotemCellClick()
    if this.element then
        CycleTotem(this.shaman, this.element, (arg1 == "RightButton") and -1 or 1)
    end
end

local function TotemCellWheel()
    if this.element then
        CycleTotem(this.shaman, this.element, (arg1 and arg1 > 0) and -1 or 1)
    end
end

local function TotemCellTip()
    if AegisRP_Settings.tooltips == false then return end
    if this.element then
        local cur = A.GetTotem(this.shaman, this.element)
        -- real spell tooltip when the totem is in your spellbook
        if cur and SpellTip(this, cur) then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(this.shaman .. "  -  " .. this.element, 1, 1, 1)
        else
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText(this.shaman .. "  -  " .. this.element, 1, 1, 1)
            if cur then GameTooltip:AddLine(cur, 0.5, 1, 0.5)
            else GameTooltip:AddLine("No totem assigned", 0.7, 0.7, 0.7) end
        end
        GameTooltip:AddLine("Click: next  -  Right-click: previous  -  Wheel: cycle", 0.6, 0.6, 0.6)
    else
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(this.shaman .. "  -  group", 1, 1, 1)
        GameTooltip:AddLine("Group " .. GroupOf(this.shaman), 0.5, 1, 0.5)
        GameTooltip:AddLine("Set automatically from the raid roster - totems only reach "
            .. "the shaman's own subgroup.", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

local function BuildTotems(p)
    local heads = { "Group" }
    local els = ElementList()
    for i = 1, table.getn(els) do table.insert(heads, els[i]) end
    for i = 1, table.getn(heads) do
        local x = (i == 1) and NAME_W or (NAME_W + PARTY_W + 4 + (i - 2) * (ELEM_W + 2))
        local w = (i == 1) and PARTY_W or ELEM_W
        local col = (i == 1) and INK_DIM or (ECOL[heads[i]] or INK_DIM)
        local shade = { col[1] * 1.5, col[2] * 1.5, col[3] * 1.5 }
        if shade[1] > 1 then shade[1] = 1 end
        if shade[2] > 1 then shade[2] = 1 end
        if shade[3] > 1 then shade[3] = 1 end
        local fs = Fnt(p, 10, shade, "CENTER")
        fs:SetWidth(w); fs:SetHeight(11)
        fs:SetPoint("TOPLEFT", p, "TOPLEFT", x, -48)
        fs:SetText(heads[i])
    end
    for r = 1, MAX_ROWS do
        local row = { cells = {} }
        local y = -64 - (r - 1) * ROW_H
        row.name = Fnt(p, 11, INK)
        row.name:SetWidth(NAME_W - 10); row.name:SetHeight(12)
        row.name:SetPoint("TOPLEFT", p, "TOPLEFT", 6, y - 3)
        row.sub = Fnt(p, 8, INK_FAINT)
        row.sub:SetWidth(NAME_W - 10); row.sub:SetHeight(9)
        row.sub:SetPoint("TOPLEFT", p, "TOPLEFT", 6, y - 17)
        for i = 1, 1 + table.getn(els) do
            local x = (i == 1) and NAME_W or (NAME_W + PARTY_W + 4 + (i - 2) * (ELEM_W + 2))
            local w = (i == 1) and PARTY_W or ELEM_W
            local b = MakeCell(p, w, CELL_H)
            b:SetPoint("TOPLEFT", p, "TOPLEFT", x, y)
            if i == 1 then
                -- group cell: centred read-only text
                local txt = Fnt(b, 10, INK, "CENTER")
                txt:SetWidth(w - 4); txt:SetHeight(CELL_H)
                txt:SetPoint("CENTER", b, "CENTER", 0, 0)
                b.text = txt
            else
                -- element chip: totem icon + name
                local icon = b:CreateTexture(nil, "ARTWORK")
                icon:SetWidth(26); icon:SetHeight(26)
                icon:SetPoint("LEFT", b, "LEFT", 4, 0)
                b.icon = icon
                local txt = Fnt(b, 9, INK)
                txt:SetWidth(w - 38); txt:SetHeight(CELL_H - 4)
                txt:SetPoint("LEFT", b, "LEFT", 33, 0)
                b.text = txt
            end
            b:SetScript("OnClick", TotemCellClick)
            b:SetScript("OnMouseWheel", TotemCellWheel)
            b:SetScript("OnEnter", SafeTip(TotemCellTip))
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            b:Hide()
            row.cells[i] = b
        end
        totemRows[r] = row
    end
end

local function RefreshTotems(p)
    local els = ElementList()
    local shamans = MembersOfClass("SHAMAN")
    local sc = CLASS_RGB.SHAMAN
    for r = 1, MAX_ROWS do
        local row = totemRows[r]
        local shaman = shamans[r]
        if shaman then
            row.name:SetText(shaman)
            row.name:SetTextColor(sc[1], sc[2], sc[3])
            row.sub:SetText(SubFor(shaman, "SHAMAN"))
            local pb = row.cells[1]
            pb.shaman = shaman; pb.element = nil
            pb.text:SetText("Grp " .. GroupOf(shaman))
            pb.text:SetTextColor(INK[1], INK[2], INK[3])
            pb:SetBackdropColor(0.10, 0.088, 0.07, 0.92)
            pb:Show()
            for i = 1, table.getn(els) do
                local b = row.cells[i + 1]
                local el = els[i]
                b.shaman = shaman; b.element = el
                local cur = A.GetTotem(shaman, el)
                if cur then
                    local ec = ECOL[el] or { 0.2, 0.2, 0.2 }
                    local tex = TotemIconFor(cur)
                    if tex then b.icon:SetTexture(tex); b.icon:Show()
                    else b.icon:Hide() end
                    b.text:SetText(ShortTotem(cur))
                    b.text:SetTextColor(1, 1, 1)
                    b:SetBackdropColor(ec[1], ec[2], ec[3], 0.55)
                else
                    b.icon:Hide()
                    b.text:SetText("+")
                    b.text:SetTextColor(INK_FAINT[1], INK_FAINT[2], INK_FAINT[3])
                    b:SetBackdropColor(0.10, 0.088, 0.07, 0.6)
                end
                b:Show()
            end
        else
            row.name:SetText(""); row.sub:SetText("")
            for i = 1, table.getn(row.cells) do row.cells[i]:Hide() end
        end
    end
    if table.getn(shamans) == 0 then
        p.cover:SetText("")
        p.hint:SetText("No shamans in your group. /rpc test seats the preview raid so you "
            .. "can try the panel solo.")
        return
    end
    local gaps = {}
    for i = 1, table.getn(els) do
        local got = false
        for _, s in ipairs(shamans) do
            if A.GetTotem(s, els[i]) then got = true end
        end
        if not got then table.insert(gaps, els[i]) end
    end
    if table.getn(gaps) == 0 then
        p.cover:SetTextColor(OK_GREEN[1], OK_GREEN[2], OK_GREEN[3])
        p.cover:SetText("Coverage: every element is assigned.")
    else
        p.cover:SetTextColor(GAP_RED[1], GAP_RED[2], GAP_RED[3])
        p.cover:SetText("No totem: " .. table.concat(gaps, ", "))
    end
    p.hint:SetText("Click an element to cycle that shaman's totem. Group = their current "
        .. "subgroup (automatic - totems only reach their own group). Synced to the raid; "
        .. "each shaman's row drives their strip.")
end

--------------------------------------------------------------------------
-- RAID BUFFS TAB - the blessings tab's shape applied to Priest/Mage/Druid:
-- a caster x class grid over the model's class-buff domain. Each cell is
-- which buff that caster gives that class; a caster's own class-buff strip
-- follows their row (step-1b), so assigning here retargets their buttons
-- and lets buffers split the raid by class.
--------------------------------------------------------------------------

local buffRows = {}
local buffHeader = {}
local BUFF_ROWS = 9
local BUFFER_CLASSES = { "PRIEST", "MAGE", "DRUID" }

local function BuffCatalog(token)
    local m = AegisRP.classes and AegisRP.classes[token]
    return (m and m.buffs) or {}
end

-- rows: the buffers of the three classes (you first within your class);
-- preview raiders capped at three per class so all three classes fit
local function BufferList()
    local out = {}
    for _, tok in ipairs(BUFFER_CLASSES) do
        local fakes = 0
        local members = MembersOfClass(tok)
        for i = 1, table.getn(members) do
            local nm = members[i]
            if AegisRP.IsTestMode() and FAKE[nm] and nm ~= Me() then
                fakes = fakes + 1
                if fakes <= 3 then table.insert(out, { name = nm, token = tok }) end
            else
                table.insert(out, { name = nm, token = tok })
            end
        end
    end
    return out
end

local function BuffIconFor(token, buffName)
    local cat = BuffCatalog(token)
    for i = 1, table.getn(cat) do
        local bd = cat[i]
        if (bd.name == buffName or bd.group == buffName) and bd.icons and bd.icons[1] then
            return "Interface\\Icons\\" .. bd.icons[1]
        end
    end
    return nil
end

local function CycleClassBuff(caster, token, classID, dir)
    local cat = BuffCatalog(token)
    local n = table.getn(cat)
    if n == 0 then return end
    local cur = A.GetClassBuff(caster, classID)
    local idx = 0
    for i = 1, n do
        if (cat[i].name or cat[i].group) == cur then idx = i end
    end
    idx = idx + dir
    if idx > n then idx = 0 elseif idx < 0 then idx = n end
    local val = nil
    if idx > 0 then val = cat[idx].name or cat[idx].group end
    if not A.SetClassBuff(caster, classID, val) then
        Msg("You can't assign for " .. caster .. " (need lead/assist).")
    end
    RefreshCurrent()
end

local function BuffCellClick()
    CycleClassBuff(this.caster, this.token, this.classID, (arg1 == "RightButton") and -1 or 1)
end

local function BuffCellWheel()
    CycleClassBuff(this.caster, this.token, this.classID, (arg1 and arg1 > 0) and -1 or 1)
end

local function BuffCellTip()
    if AegisRP_Settings.tooltips == false then return end
    local cur = A.GetClassBuff(this.caster, this.classID)
    if cur and SpellTip(this, cur) then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(this.caster .. "  -  " .. (CLASS_LABEL[this.classID] or "?"), 1, 1, 1)
    else
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(this.caster .. "  -  " .. (CLASS_LABEL[this.classID] or "?"), 1, 1, 1)
        if cur then GameTooltip:AddLine(cur, 0.5, 1, 0.5)
        else GameTooltip:AddLine("No buff assigned", 0.7, 0.7, 0.7) end
    end
    GameTooltip:AddLine("Click: next  -  Right-click: previous  -  Wheel: cycle", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function BuildBuffGrid(p)
    -- The class header is TWO widgets: an icon and the class name under it.
    -- Both have to be reachable, or the group view can't hide the half it
    -- doesn't own. Labels park on the panel so they cost no file-scope local
    -- (CreatePanel is near the 32-upvalue ceiling).
    p.classHdrLbl = {}
    for c = 0, 9 do
        local t = p:CreateTexture(nil, "ARTWORK")
        t:SetWidth(24); t:SetHeight(24)
        t:SetPoint("TOPLEFT", p, "TOPLEFT", NAME_W + c * 44 + 9, -42)
        local l = Fnt(p, 8, INK_DIM, "CENTER")
        l:SetWidth(44); l:SetHeight(9)
        l:SetPoint("TOPLEFT", p, "TOPLEFT", NAME_W + c * 44 - 1, -68)
        l:SetText(CLASS_LABEL[c])
        buffHeader[c] = t
        p.classHdrLbl[c] = l
    end
    for r = 1, BUFF_ROWS do
        local row = { cells = {} }
        local y = -84 - (r - 1) * ROW_H
        row.name = Fnt(p, 11, INK)
        row.name:SetWidth(NAME_W - 22); row.name:SetHeight(12)
        row.name:SetPoint("TOPLEFT", p, "TOPLEFT", 6, y - 3)
        row.sub = Fnt(p, 8, INK_FAINT)
        row.sub:SetWidth(NAME_W - 22); row.sub:SetHeight(9)
        row.sub:SetPoint("TOPLEFT", p, "TOPLEFT", 6, y - 17)
        for c = 0, 9 do
            local b = MakeCell(p, 42, CELL_H)
            b:SetPoint("TOPLEFT", p, "TOPLEFT", NAME_W + c * 44, y)
            b.classID = c
            local icon = b:CreateTexture(nil, "ARTWORK")
            icon:SetWidth(28); icon:SetHeight(28)
            icon:SetPoint("CENTER", b, "CENTER", 0, 0)
            b.icon = icon
            local txt = Fnt(b, 12, GOLD_BRIGHT, "CENTER")
            txt:SetPoint("CENTER", b, "CENTER", 0, 0)
            b.text = txt
            b:SetScript("OnClick", BuffCellClick)
            b:SetScript("OnMouseWheel", BuffCellWheel)
            b:SetScript("OnEnter", SafeTip(BuffCellTip))
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            b:Hide()
            row.cells[c] = b
        end
        buffRows[r] = row
    end
end

local function RefreshBuffGrid(p)
    for c = 0, 9 do
        if PallyPower_ClassTexture and PallyPower_ClassTexture[c] then
            buffHeader[c]:SetTexture(PallyPower_ClassTexture[c])
        end
    end
    local rows = BufferList()
    for r = 1, BUFF_ROWS do
        local row = buffRows[r]
        local entry = rows[r]
        if entry then
            local cc = CLASS_RGB[entry.token] or INK
            row.name:SetText(entry.name)
            row.name:SetTextColor(cc[1], cc[2], cc[3])
            row.sub:SetText(SubFor(entry.name, entry.token))
            for c = 0, 9 do
                local b = row.cells[c]
                b.caster = entry.name; b.token = entry.token
                local cur = A.GetClassBuff(entry.name, c)
                if cur then
                    local tex = BuffIconFor(entry.token, cur)
                    if tex then
                        b.icon:SetTexture(tex); b.icon:Show(); b.icon:SetAlpha(1)
                        b.text:SetText("")
                    else
                        b.icon:Hide()
                        b.text:SetText(string.sub(cur, 1, 2))
                        b.text:SetTextColor(GOLD_BRIGHT[1], GOLD_BRIGHT[2], GOLD_BRIGHT[3])
                    end
                    b:SetBackdropColor(0.13, 0.115, 0.085, 0.95)
                else
                    b.icon:Hide()
                    b.text:SetText("+")
                    b.text:SetTextColor(INK_FAINT[1], INK_FAINT[2], INK_FAINT[3])
                    b:SetBackdropColor(0.10, 0.088, 0.07, 0.6)
                end
                b:Show()
            end
        else
            row.name:SetText(""); row.sub:SetText("")
            for c = 0, 9 do row.cells[c]:Hide() end
        end
    end
    if table.getn(rows) == 0 then
        p.cover:SetText("")
        p.hint:SetText("No priests, mages or druids in your group. /rpc test seats the "
            .. "preview raid so you can try the panel solo.")
        return
    end
    local gaps = {}
    for c = 0, 8 do
        local got = false
        for i = 1, table.getn(rows) do
            if A.GetClassBuff(rows[i].name, c) then got = true end
        end
        if not got then table.insert(gaps, CLASS_LABEL[c]) end
    end
    if table.getn(gaps) == 0 then
        p.cover:SetTextColor(OK_GREEN[1], OK_GREEN[2], OK_GREEN[3])
        p.cover:SetText("Coverage: every class has a buffer.")
    else
        p.cover:SetTextColor(GAP_RED[1], GAP_RED[2], GAP_RED[3])
        p.cover:SetText("No buffer: " .. table.concat(gaps, ", "))
    end
    p.hint:SetText("Click a cell to cycle which buff that caster gives the class - their own "
        .. "strip follows their row, so buffers can split the raid by class. Synced to the raid.")
end

--------------------------------------------------------------------------
-- RAID BUFFS, GROUP VIEW: caster x raid group, several buffs per cell.
--
-- Assigning by GROUP is the shape raids actually organise around for
-- priest/mage/druid buffs, because the group version lands on a PARTY - see
-- the gbuff domain in Aegis_Assign.lua for why the class grid is really a
-- paladin mechanic. The class view stays behind a toggle rather than being
-- deleted: a leader can retarget another caster's per-class strip buttons
-- from it, and nothing else in the addon can do that.
--
-- Every cell holds one small toggle per buff the caster's class can give, so
-- "group 2 gets Fortitude AND Spirit" is two clicks in one cell rather than a
-- cycle through subsets.
--
-- Layout constants live in ONE table deliberately: CreatePanel sits near the
-- Lua 5.0 32-upvalue ceiling and every file-scope local it reaches costs one.
--------------------------------------------------------------------------

local GBUF = {
    ROWS  = 9,        -- pooled caster rows
    COLS  = 8,        -- raid groups 1..8
    CELLW = 62,
    STEP  = 66,
    SUBW  = 19,       -- one buff toggle inside a cell
    SUBH  = 30,
    TOP   = -84,
    HDR   = -60,
    MAXB  = 3,        -- widest catalog (priest); spare toggles stay hidden
}

local groupRows = {}

local function GroupViewOn()
    return AegisRP_Settings.buffView ~= "class"
end

local function GroupBuffClick()
    if not (this.caster and this.group and this.buffName) then return end
    if not A.ToggleGroupBuff(this.caster, this.group, this.buffName) then
        Msg("You can't assign for " .. this.caster .. " (need lead/assist).")
        return
    end
    RefreshCurrent()
end

local function GroupBuffTip()
    if AegisRP_Settings.tooltips == false then return end
    if not this.buffName then return end
    if not SpellTip(this, this.buffName) then
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(this.buffName, 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(this.caster .. "  -  Group " .. this.group, 1, 1, 1)
    if A.HasGroupBuff(this.caster, this.group, this.buffName) then
        GameTooltip:AddLine("Assigned - click to remove", 0.36, 0.88, 0.48)
    else
        GameTooltip:AddLine("Not assigned - click to assign", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

local function BuffViewToggle()
    AegisRP_Settings.buffView = GroupViewOn() and "class" or "group"
    RefreshCurrent()
end

local function BuffViewTip()
    if AegisRP_Settings.tooltips == false then return end
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText("Assignment view", 1, 1, 1)
    GameTooltip:AddLine("By Group - which raid groups this caster covers, and with which "
        .. "buffs. A group can take several.", 0.7, 0.7, 0.7, 1)
    GameTooltip:AddLine("By Class - the per-class grid. It retargets that caster's own "
        .. "strip buttons, which only this view can do.", 0.7, 0.7, 0.7, 1)
    GameTooltip:Show()
end

local function BuildGroupGrid(p)
    -- view toggle, parked on the panel so it costs no file-scope local.
    -- Anchored top-right (the same corner the Rotations tab's view switch
    -- uses) rather than at NAME_W: that spot sat right on top of the class
    -- icon header row (icons start at NAME_W+9, y-42; the toggle was at
    -- NAME_W, y-40), so the pill painted over Warrior/Rogue's icons and its
    -- own text overflowed a box too narrow for "View: By Class/Group".
    local tg = MakeCell(p, 120, 18)
    tg:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -20)
    tg.label = Fnt(tg, 10, GOLD, "CENTER")
    tg.label:SetWidth(116); tg.label:SetHeight(13)
    tg.label:SetPoint("CENTER", tg, "CENTER", 0, 0)
    tg:SetScript("OnClick", BuffViewToggle)
    tg:SetScript("OnEnter", SafeTip(BuffViewTip))
    tg:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p.buffToggle = tg

    p.groupHdr = {}
    for g = 1, GBUF.COLS do
        local l = Fnt(p, 10, GOLD, "CENTER")
        l:SetWidth(GBUF.CELLW); l:SetHeight(11)
        l:SetPoint("TOPLEFT", p, "TOPLEFT", NAME_W + (g - 1) * GBUF.STEP, GBUF.HDR)
        l:SetText("Group " .. g)
        p.groupHdr[g] = l
    end

    for r = 1, GBUF.ROWS do
        local row = { cells = {} }
        local y = GBUF.TOP - (r - 1) * ROW_H
        row.name = Fnt(p, 11, INK)
        row.name:SetWidth(NAME_W - 22); row.name:SetHeight(12)
        row.name:SetPoint("TOPLEFT", p, "TOPLEFT", 6, y - 3)
        row.sub = Fnt(p, 8, INK_FAINT)
        row.sub:SetWidth(NAME_W - 22); row.sub:SetHeight(9)
        row.sub:SetPoint("TOPLEFT", p, "TOPLEFT", 6, y - 17)
        for g = 1, GBUF.COLS do
            local cell = MakeCell(p, GBUF.CELLW, CELL_H)
            cell:SetPoint("TOPLEFT", p, "TOPLEFT",
                          NAME_W + (g - 1) * GBUF.STEP, y)
            cell:EnableMouse(false)          -- the toggles inside take the clicks
            cell.toggles = {}
            for i = 1, GBUF.MAXB do
                local t = MakeCell(cell, GBUF.SUBW, GBUF.SUBH)
                t:SetPoint("LEFT", cell, "LEFT", 2 + (i - 1) * (GBUF.SUBW + 1), 0)
                local ic = t:CreateTexture(nil, "ARTWORK")
                ic:SetWidth(15); ic:SetHeight(15)
                ic:SetPoint("CENTER", t, "CENTER", 0, 0)
                t.icon = ic
                t.txt = Fnt(t, 9, GOLD_BRIGHT, "CENTER")
                t.txt:SetWidth(GBUF.SUBW); t.txt:SetHeight(10)
                t.txt:SetPoint("CENTER", t, "CENTER", 0, 0)
                t.group = g
                t:SetScript("OnClick", GroupBuffClick)
                t:SetScript("OnEnter", SafeTip(GroupBuffTip))
                t:SetScript("OnLeave", function() GameTooltip:Hide() end)
                t:Hide()
                cell.toggles[i] = t
            end
            cell:Hide()
            row.cells[g] = cell
        end
        groupRows[r] = row
    end
end

local function RefreshGroupGrid(p)
    local rows = BufferList()
    local covered = {}          -- [group] = true once any caster covers it
    for r = 1, GBUF.ROWS do
        local row = groupRows[r]
        local entry = rows[r]
        if entry then
            local cc = CLASS_RGB[entry.token] or INK
            row.name:SetText(entry.name)
            row.name:SetTextColor(cc[1], cc[2], cc[3])
            local cat = BuffCatalog(entry.token)
            local n = table.getn(cat)
            row.sub:SetText(SubFor(entry.name, entry.token))
            for g = 1, GBUF.COLS do
                local cell = row.cells[g]
                local any = false
                for i = 1, GBUF.MAXB do
                    local t = cell.toggles[i]
                    local bd = cat[i]
                    if bd and i <= n then
                        local nm = bd.name or bd.group
                        t.caster = entry.name
                        t.buffName = nm
                        local on = A.HasGroupBuff(entry.name, g, nm)
                        if on then any = true; covered[g] = true end
                        local tex = BuffIconFor(entry.token, nm)
                        if tex then
                            t.icon:SetTexture(tex); t.icon:Show()
                            t.icon:SetAlpha(on and 1 or 0.25)
                            t.txt:SetText("")
                        else
                            t.icon:Hide()
                            t.txt:SetText(string.sub(nm, 1, 2))
                        end
                        if on then
                            t:SetBackdropColor(0.10, 0.22, 0.11, 0.95)
                        else
                            t:SetBackdropColor(0.10, 0.088, 0.07, 0.55)
                        end
                        t:Show()
                    else
                        t.caster = nil; t.buffName = nil
                        t:Hide()
                    end
                end
                if any then
                    cell:SetBackdropColor(0.13, 0.115, 0.085, 0.95)
                else
                    cell:SetBackdropColor(0.10, 0.088, 0.07, 0.6)
                end
                cell:Show()
            end
        else
            row.name:SetText(""); row.sub:SetText("")
            for g = 1, GBUF.COLS do row.cells[g]:Hide() end
        end
    end

    if table.getn(rows) == 0 then
        p.cover:SetText("")
        p.hint:SetText("No priests, mages or druids in your group. /rpc test seats the "
            .. "preview raid so you can try the panel solo.")
        return
    end
    -- coverage is per GROUP here, not per class: which parties has nobody taken
    local gaps = {}
    local live = GetNumRaidMembers() > 0 and 8 or 1
    for g = 1, live do
        if not covered[g] then table.insert(gaps, tostring(g)) end
    end
    if table.getn(gaps) == 0 then
        p.cover:SetTextColor(OK_GREEN[1], OK_GREEN[2], OK_GREEN[3])
        p.cover:SetText("Coverage: every group has a buffer.")
    else
        p.cover:SetTextColor(GAP_RED[1], GAP_RED[2], GAP_RED[3])
        p.cover:SetText("No buffer for group: " .. table.concat(gaps, ", "))
    end
    p.hint:SetText("Click a buff to give it to that group - a group can take several from "
        .. "one caster. Group buffs land on a party, which is why this view is by group. "
        .. "Synced to the raid.")
end

-- Tab 3 entry point: swap the two views and hide whichever isn't showing.
local function RefreshBuffTab(p)
    local grp = GroupViewOn()
    if p.buffToggle then
        p.buffToggle.label:SetText(grp and "View: By Group" or "View: By Class")
        p.buffToggle:Show()
    end
    for g = 1, GBUF.COLS do
        if p.groupHdr and p.groupHdr[g] then
            if grp then p.groupHdr[g]:Show() else p.groupHdr[g]:Hide() end
        end
    end
    for c = 0, 9 do
        if buffHeader[c] then
            if grp then buffHeader[c]:Hide() else buffHeader[c]:Show() end
        end
        -- the class NAME under each icon is a separate widget; missing it left
        -- "Warrior Rogue Priest ..." showing through under the group headers
        if p.classHdrLbl and p.classHdrLbl[c] then
            if grp then p.classHdrLbl[c]:Hide() else p.classHdrLbl[c]:Show() end
        end
    end
    if grp then
        for r = 1, BUFF_ROWS do
            local row = buffRows[r]
            if row then
                row.name:SetText(""); row.sub:SetText("")
                for c = 0, 9 do row.cells[c]:Hide() end
            end
        end
        RefreshGroupGrid(p)
    else
        for r = 1, GBUF.ROWS do
            local row = groupRows[r]
            if row then
                row.name:SetText(""); row.sub:SetText("")
                for g = 1, GBUF.COLS do row.cells[g]:Hide() end
            end
        end
        RefreshBuffGrid(p)
    end
end

--------------------------------------------------------------------------
-- DUTY TABS - Debuffs / Utility as two-column cards
--------------------------------------------------------------------------

local dutyCards = { [4] = {} }

local function DutyList(tabkey)
    local out = {}
    for i = 1, table.getn(A.dutyOrder) do
        local def = A.duties[A.dutyOrder[i]]
        if def and def.tab == tabkey and not def.hidden then table.insert(out, def) end
    end
    return out
end

-- Your own spellbook first (exact, right rank), then the icon the duty
-- carries. The fallback matters for everyone ELSE's duties: a mage looking at
-- the Debuffs tab can't resolve Faerie Fire from their spellbook, and a card
-- with no icon is what a missing fallback looks like.
--
-- The icon rides on the duty definition rather than a lookup table in this
-- file on purpose - as a parallel table it was a second place to remember, and
-- Faerie Fire and Demoralizing Roar shipped blank in 1.8.0 for exactly that
-- reason. scripts/test_duties.lua now fails if a duty has no icon.
local function DutyIcon(def)
    if def.spell then
        local sp = AegisRP.FindSpell and AegisRP.FindSpell(def.spell)
        if sp and sp.texture then return sp.texture end
    end
    return def.icon
end

-- Holders text: "-", "Name", "Name +2" (tooltip lists everyone)
local function HolderText(key)
    local holders = A.GetDutyCasters(key)
    local n = table.getn(holders)
    if n == 0 then return nil, holders end
    local t = holders[1].caster
    if n > 1 then t = t .. " +" .. (n - 1) end
    return t, holders
end

-- Lead/assist (or test mode) cycles none -> each candidate -> none; everyone
-- else toggles their own claim.
local function CycleDutyHolder(key, dir)
    local def = A.duties[key]
    if not def then return end
    local cands = MembersOfClass(def.class)
    local holders = A.GetDutyCasters(key)

    if not LeaderLike() then
        -- a member may only claim/unclaim their OWN role, and only when their
        -- class matches the duty (a priest can't take a warrior debuff)
        local _, mycls = UnitClass("player")
        local mine = false
        for i = 1, table.getn(holders) do
            if holders[i].caster == Me() then mine = true end
        end
        if mine then
            A.ClearDuty(Me(), key)
        elseif mycls ~= def.class then
            Msg("Only a " .. TitleCase(def.class) .. " can take " .. (def.spell or key) .. ".")
        elseif not A.SetDuty(Me(), key, true) then
            Msg("You can't take " .. (def.spell or key) .. " right now.")
        end
        RefreshCurrent()
        return
    end

    local n = table.getn(cands)
    if n == 0 then
        -- nobody of this class present: clear any stale holder, else say so
        for i = 1, table.getn(holders) do A.ClearDuty(holders[i].caster, key) end
        if table.getn(holders) == 0 then
            Msg("No " .. TitleCase(def.class) .. " in the group for " .. (def.spell or key) .. ".")
        end
        RefreshCurrent()
        return
    end
    local curTarget = holders[1] and holders[1].target      -- preserve the target
    local val = true
    if def.target ~= "none" and type(curTarget) == "string" then val = curTarget end

    -- A `multi` duty ACCUMULATES owners instead of replacing them: several
    -- warriors really do stack Sunder, and several mages really do stack
    -- Scorch. Forward adds the next candidate who isn't already on it and
    -- wraps to empty once everyone is; backward drops the last one added.
    -- Single-owner duties (curses, Expose) keep the plain replace-cycle,
    -- because two people casting them just overwrite each other.
    if def.multi then
        local held = {}
        for i = 1, table.getn(holders) do held[holders[i].caster] = true end
        if dir > 0 then
            for i = 1, n do
                if not held[cands[i]] then
                    A.SetDuty(cands[i], key, val)
                    RefreshCurrent()
                    return
                end
            end
            -- everyone already has it: wrap round to nobody
            for i = 1, table.getn(holders) do A.ClearDuty(holders[i].caster, key) end
        else
            for i = n, 1, -1 do
                if held[cands[i]] then
                    A.ClearDuty(cands[i], key)
                    RefreshCurrent()
                    return
                end
            end
        end
        RefreshCurrent()
        return
    end

    local cur = holders[1] and holders[1].caster or nil
    local idx = 0
    for i = 1, n do if cands[i] == cur then idx = i end end
    idx = idx + dir
    if idx > n then idx = 0 elseif idx < 0 then idx = n end
    for i = 1, table.getn(holders) do
        A.ClearDuty(holders[i].caster, key)
    end
    if idx > 0 then
        A.SetDuty(cands[idx], key, val)
    end
    RefreshCurrent()
end

-- Targeted utility duties (Fear Ward, Innervate, Soulstone) carry
-- WHO they go on in the duty value: true = caster's choice, "@TANK"/"@HEALER"
-- = a marked role. Cycle the current holder(s) through those.
local TARGET_OPTS = { true, "@TANK", "@HEALER" }
local function TargetLabel(t)
    if t == "@TANK" then return "Tank" end
    if t == "@HEALER" then return "Healer" end
    if type(t) == "string" then return t end        -- a specific player name
    return nil
end

local function CycleDutyTarget(key, dir)
    local def = A.duties[key]
    if not def or def.target == "none" then return end
    local holders = A.GetDutyCasters(key)
    if table.getn(holders) == 0 then
        Msg("Assign a caster first (left-click), then set the target.")
        return
    end
    for i = 1, table.getn(holders) do
        local h = holders[i]
        local idx = 1
        for j = 1, table.getn(TARGET_OPTS) do if TARGET_OPTS[j] == h.target then idx = j end end
        idx = idx + dir
        if idx > table.getn(TARGET_OPTS) then idx = 1
        elseif idx < 1 then idx = table.getn(TARGET_OPTS) end
        A.SetDuty(h.caster, key, TARGET_OPTS[idx])
    end
    RefreshCurrent()
end

local function DutyCardClick()
    local def = A.duties[this.dutyKey]
    -- right-click a targeted duty picks its target (Tank/Healer); otherwise
    -- right-click cycles the holder backwards
    if arg1 == "RightButton" and def and def.target ~= "none" then
        CycleDutyTarget(this.dutyKey, 1)
    else
        CycleDutyHolder(this.dutyKey, (arg1 == "RightButton") and -1 or 1)
    end
end

local function DutyCardWheel()
    CycleDutyHolder(this.dutyKey, (arg1 and arg1 > 0) and -1 or 1)
end

local function DutyCardTip()
    if AegisRP_Settings.tooltips == false then return end
    local def = A.duties[this.dutyKey]
    if not def then return end
    -- real spell tooltip when the duty's spell is in your spellbook
    if SpellTip(this, def.spell) then
        GameTooltip:AddLine(" ")
    else
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(def.spell or this.dutyKey, 1, 1, 1)
    end
    local _, holders = HolderText(this.dutyKey)
    for i = 1, table.getn(holders) do
        local h = holders[i]
        local t = h.caster
        if type(h.target) == "string" then t = t .. "  ->  " .. (TargetLabel(h.target) or h.target) end
        GameTooltip:AddLine(t, 0.5, 1, 0.5)
    end
    if table.getn(holders) == 0 then GameTooltip:AddLine("Unassigned", 0.7, 0.7, 0.7) end
    if def.target ~= "none" then
        GameTooltip:AddLine("Left-click: who casts it", 0.6, 0.6, 0.6)
        GameTooltip:AddLine("Right-click: send to Tank / Healer", 0.6, 0.6, 0.6)
    else
        GameTooltip:AddLine("Click: cycle who's responsible (right-click backwards)", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

local function BuildDutyTab(p, tabIndex)
    for i = 1, DUTY_POOL do
        local col = math.mod(i - 1, 2)          -- 0 left, 1 right
        local rowN = math.floor((i - 1) / 2)
        local card = MakeCell(p, 346, 46)
        card:SetPoint("TOPLEFT", p, "TOPLEFT", col * 366, -46 - rowN * 48)
        local icon = card:CreateTexture(nil, "ARTWORK")
        icon:SetWidth(32); icon:SetHeight(32)
        icon:SetPoint("LEFT", card, "LEFT", 8, 0)
        card.icon = icon
        card.name = Fnt(card, 11, INK)
        card.name:SetWidth(200); card.name:SetHeight(12)
        card.name:SetPoint("TOPLEFT", card, "TOPLEFT", 48, -9)
        card.sub = Fnt(card, 9, INK_FAINT)
        card.sub:SetWidth(200); card.sub:SetHeight(10)
        card.sub:SetPoint("TOPLEFT", card, "TOPLEFT", 48, -26)
        card.holder = Fnt(card, 11, INK, "RIGHT")
        card.holder:SetWidth(90); card.holder:SetHeight(12)
        card.holder:SetPoint("RIGHT", card, "RIGHT", -8, 0)
        card:SetScript("OnClick", DutyCardClick)
        card:SetScript("OnMouseWheel", DutyCardWheel)
        card:SetScript("OnEnter", SafeTip(DutyCardTip))
        card:SetScript("OnLeave", function() GameTooltip:Hide() end)
        card:Hide()
        dutyCards[tabIndex][i] = card
    end
end

local function RefreshDutyTab(p, tabIndex)
    local defs = DutyList(DUTY_TAB[tabIndex])
    local cards = dutyCards[tabIndex]
    local assigned = 0
    for i = 1, DUTY_POOL do
        local card = cards[i]
        local def = defs[i]
        if def then
            card.dutyKey = def.key
            local tex = DutyIcon(def)
            if tex then card.icon:SetTexture(tex); card.icon:Show()
            else card.icon:Hide() end
            card.name:SetText(def.spell or def.key)
            if def.target ~= "none" then
                card.sub:SetText(TitleCase(def.class) .. " - right-click: target")
            else
                card.sub:SetText(TitleCase(def.class)
                    .. (def.multi and " - any number" or " - one owner"))
            end
            local txt = HolderText(def.key)
            if txt and def.target ~= "none" then
                local hs = A.GetDutyCasters(def.key)
                local tl = hs[1] and TargetLabel(hs[1].target)
                if tl then txt = txt .. " |cffaaaaaa->|r " .. tl end
            end
            if txt then
                assigned = assigned + 1
                local cc = CLASS_RGB[def.class] or INK
                card.holder:SetText(txt)
                card.holder:SetTextColor(cc[1], cc[2], cc[3])
                card:SetBackdropColor(0.13, 0.115, 0.085, 0.95)
            else
                card.holder:SetText("-")
                card.holder:SetTextColor(INK_FAINT[1], INK_FAINT[2], INK_FAINT[3])
                card:SetBackdropColor(0.10, 0.088, 0.07, 0.7)
            end
            card:Show()
        else
            card:Hide()
        end
    end
    local total = table.getn(defs)
    p.note:SetText(assigned .. "/" .. total .. " assigned")
    if total > assigned then
        p.note:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    else
        p.note:SetTextColor(OK_GREEN[1], OK_GREEN[2], OK_GREEN[3])
    end
    p.cover:SetText("")
    p.hint:SetText("Click a card to set who's responsible (lead/assist sets anyone; others "
        .. "claim or unclaim themselves). Stacking debuffs - Sunder, Scorch - take SEVERAL "
        .. "owners: each click adds another, right-click drops the last. Synced to the raid.")
end

--------------------------------------------------------------------------
-- ROLES TAB - mark tanks / healers (over PallyPower's own Tanks/Healers, so
-- it's shared with stock PallyPower and drives its no-Salvation-on-tanks
-- rule) and give a tank its own blessing (per-player NormalAssignments).
--------------------------------------------------------------------------

local roleCells = {}
-- healer grid sits UNDER the three tank-slot dropdowns, so it's a 3-wide grid
-- (fits a 40-man roster) starting lower on the panel.
local ROLE_COLS, ROLE_ROWS = 3, 14
local ROLE_CELL_W = 228

-- every raid/party member (you first); preview raid in test mode
local function AllMembers()
    local out, seen = {}, {}
    local function add(n) if n and not seen[n] then seen[n] = true; table.insert(out, n) end end
    add(Me())
    local n = GetNumRaidMembers()
    if n > 0 then
        for i = 1, n do add(UnitName("raid" .. i)) end
    else
        for i = 1, GetNumPartyMembers() do add(UnitName("party" .. i)) end
    end
    if AegisRP.IsTestMode() then
        for _, r in ipairs(ROSTER40) do add(r[1]) end
    end
    return out
end

local function MemberClass(name)
    if name == Me() then local _, c = UnitClass("player"); return c end
    local n = GetNumRaidMembers()
    if n > 0 then
        for i = 1, n do
            if UnitName("raid" .. i) == name then local _, c = UnitClass("raid" .. i); return c end
        end
    else
        for i = 1, GetNumPartyMembers() do
            if UnitName("party" .. i) == name then local _, c = UnitClass("party" .. i); return c end
        end
    end
    if AegisRP.IsTestMode() and FAKE[name] then return FAKE[name] end
    return nil
end

--------------------------------------------------------------------------
-- CROWD CONTROL TAB - one row per raid mark: which spell goes on it, and
-- who casts it.
--
-- MARK-major, because that is the instruction a raid actually gives ("sheep
-- the moon, banish the square"), while the STORE stays caster-major like
-- every other domain - that is what the sync protocol ships and what
-- PruneToRoster cleans, so a mage who leaves takes their mark with them and
-- there is nothing extra to tidy. A.GetCCForMark derives this view on demand;
-- it is never stored, so there is no second copy to drift.
--
-- Two axes on one row, because one is unusable at raid size: wheel picks the
-- SPELL (a short list, filtered to classes actually present) and click picks
-- WHO (usually two or three people). A single combined list of every
-- (player, spell) pair is over thirty entries in a 40-man - and a dropdown of
-- that is exactly the UIDropDownMenu overflow hard rule 17 warns about.
--
-- ALL OF IT HANGS OFF ONE TABLE, deliberately. This file is at the OTHER Lua
-- ceiling: a chunk may declare 200 file-scope locals and it is already at the
-- line. Nineteen locals for this feature would not compile - the same fix as
-- the group-buff grid's GBUF, applied to functions as well as constants.
--------------------------------------------------------------------------

local CC = {
    rows  = {},
    -- The spell a row SHOWS while nobody holds the mark. Panel-local: it is a
    -- pending choice, not a plan, so it is never saved and never broadcast.
    pick  = {},
    ROW_H = 44,
    MARKS = {
        { name = "Star",     tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1", rgb = { 0.98, 0.90, 0.32 } },
        { name = "Circle",   tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2", rgb = { 0.95, 0.60, 0.24 } },
        { name = "Diamond",  tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3", rgb = { 0.79, 0.51, 0.87 } },
        { name = "Triangle", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4", rgb = { 0.44, 0.83, 0.44 } },
        { name = "Moon",     tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_5", rgb = { 0.85, 0.88, 0.95 } },
        { name = "Square",   tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6", rgb = { 0.35, 0.66, 0.95 } },
        { name = "Cross",    tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7", rgb = { 0.93, 0.36, 0.33 } },
        { name = "Skull",    tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8", rgb = { 0.92, 0.92, 0.88 } },
    },
    -- Rows read in KILL order (Skull first), which is how a leader calls them.
    -- The INDEX is the wire identity and is unaffected by this.
    ORDER = { 8, 7, 6, 5, 4, 3, 2, 1 },
}

-- Which classes have anybody here, in ONE roster walk. Eight rows each asking
-- MembersOfClass would be eight 40-man walks on every refresh tick.
function CC.Presence()
    local out = {}
    local _, mine = UnitClass("player")
    if mine then out[mine] = true end
    local n = GetNumRaidMembers()
    if n > 0 then
        for i = 1, n do local _, c = UnitClass("raid" .. i); if c then out[c] = true end end
    else
        for i = 1, GetNumPartyMembers() do
            local _, c = UnitClass("party" .. i); if c then out[c] = true end
        end
    end
    if AegisRP.IsTestMode() then
        for _, r in ipairs(ROSTER40) do out[r[2]] = true end
    end
    return out
end

-- The wheel's list: CC spells someone present can actually cast. Falls back to
-- the WHOLE catalog when nobody qualifies - a leader planning before the raid
-- fills up still needs to pick, and an empty wheel is a dead control.
function CC.Choices(pres)
    local all = DutyList("cc")
    if not pres then return all end
    local out = {}
    for i = 1, table.getn(all) do
        if pres[all[i].class] then table.insert(out, all[i]) end
    end
    if table.getn(out) == 0 then return all end
    return out
end

-- What a row shows: the model's answer first, then the pending pick, then the
-- first choice so a fresh row always has something to wheel away from.
-- Returns def, holder name (nil when unassigned), and the claim count.
function CC.RowSpell(mark, choices)
    local holders = A.GetCCForMark(mark)
    if holders[1] then
        return A.duties[holders[1].key], holders[1].caster, table.getn(holders)
    end
    local def = CC.pick[mark] and A.duties[CC.pick[mark]]
    return def or choices[1], nil, 0
end

-- Step through the people who can cast `def`, wrapping through "unassigned"
-- so a row can always be emptied without needing a second gesture.
function CC.CycleCaster(mark, def, dir)
    if not def then return end
    local cands = MembersOfClass(def.class)
    local n = table.getn(cands)
    if n == 0 then
        Msg("No " .. TitleCase(def.class) .. " in the group for " .. (def.spell or def.key) .. ".")
        return
    end
    local holders = A.GetCCForMark(mark)
    local cur = holders[1] and holders[1].caster
    local at = 0
    for i = 1, n do if cands[i] == cur then at = i end end
    at = at + (dir or 1)
    if at > n then at = 0 elseif at < 0 then at = n end
    if at == 0 then A.AssignMark(mark, nil) else A.AssignMark(mark, cands[at], def.key) end
end

function CC.CycleSpell(mark, dir)
    local choices = CC.Choices(CC.Presence())
    local n = table.getn(choices)
    if n == 0 then return end
    local def = CC.RowSpell(mark, choices)
    local at = 1
    for i = 1, n do if choices[i] == def then at = i end end
    at = at + (dir or 1)
    if at > n then at = 1 elseif at < 1 then at = n end
    local pick = choices[at]
    CC.pick[mark] = pick.key

    -- Keep the holder when their class can still cast it; otherwise hand the
    -- mark to the first candidate for the new spell. Wheeling to Banish and
    -- being told "Banish - Gul'dan" is the point; making the leader click
    -- again for the only possible answer is not. If that class is not here at
    -- all the mark empties rather than keeping a caster who cannot cast it.
    local holders = A.GetCCForMark(mark)
    local cur = holders[1] and holders[1].caster
    if cur and MemberClass(cur) == pick.class then
        A.AssignMark(mark, cur, pick.key)
    else
        local cands = MembersOfClass(pick.class)
        if cands[1] then A.AssignMark(mark, cands[1], pick.key)
        elseif cur then A.AssignMark(mark, nil) end
    end
end

-- My own class's CC entries, in catalog order. The member path below cycles
-- only these: a priest can no more sap than they can Sunder.
function CC.Mine()
    local _, mycls = UnitClass("player")
    local all, out = DutyList("cc"), {}
    for i = 1, table.getn(all) do
        if all[i].class == mycls then table.insert(out, all[i]) end
    end
    return out, mycls
end

function CC.IHold(mark)
    local holders = A.GetCCForMark(mark)
    for i = 1, table.getn(holders) do
        if holders[i].caster == Me() then return true end
    end
    return false
end

function CC.RowClick(dir)
    local mark = this.mark
    if not mark then return end
    local def = CC.RowSpell(mark, CC.Choices(CC.Presence()))

    if not LeaderLike() then
        -- a member may only claim or unclaim THEMSELVES, and only with a spell
        -- their own class has - the same rule the duty cards use
        if CC.IHold(mark) then
            A.SetCC(Me(), mark, nil)
            RefreshCurrent()
            return
        end
        local mine, mycls = CC.Mine()
        if table.getn(mine) == 0 then
            Msg("A " .. TitleCase(mycls or "?") .. " has no crowd control to assign.")
        else
            -- prefer the spell the row already shows when it is one of mine
            local pick = mine[1]
            if def and def.class == mycls then pick = def end
            if not A.SetCC(Me(), mark, pick.key) then
                Msg("You can't take that mark right now.")
            end
        end
        RefreshCurrent()
        return
    end

    CC.CycleCaster(mark, def, dir)
    RefreshCurrent()
end

function CC.RowWheel()
    local mark = this.mark
    if not mark then return end
    local dir = (arg1 and arg1 > 0) and 1 or -1
    if not LeaderLike() then
        -- a member wheels only their OWN claim, through their own spells
        if not CC.IHold(mark) then return end
        local mine = CC.Mine()
        local n = table.getn(mine)
        if n < 2 then return end
        local cur, at = A.GetCC(Me(), mark), 1
        for i = 1, n do if mine[i].key == cur then at = i end end
        at = at + dir
        if at > n then at = 1 elseif at < 1 then at = n end
        A.SetCC(Me(), mark, mine[at].key)
        RefreshCurrent()
        return
    end
    CC.CycleSpell(mark, dir)
    RefreshCurrent()
end

-- Marking the target from here is the one thing a CC plan cannot do without:
-- the plan says "sheep the moon" and something has to put a moon on a mob.
-- SetRaidTarget is confirmed present on Turtle 1.18.1, and still guarded - a
-- capability is established, not assumed.
function CC.MarkClick()
    local mark = this.mark
    if not mark then return end
    if not SetRaidTarget then
        Msg("This client has no SetRaidTarget, so marks can't be set from here.")
        return
    end
    if not UnitExists("target") then
        Msg("Target the mob first, then click the icon to mark it.")
        return
    end
    SetRaidTarget("target", mark)
end

function CC.MarkTip()
    if AegisRP_Settings.tooltips == false then return end
    local m = CC.MARKS[this.mark]
    if not m then return end
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:AddLine(m.name, m.rgb[1], m.rgb[2], m.rgb[3])
    GameTooltip:AddLine("Click to put this mark on your current target.", 1, 1, 1)
    GameTooltip:AddLine("In a raid that needs lead or assist.", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

function CC.RowTip()
    if AegisRP_Settings.tooltips == false then return end
    local mark = this.mark
    local m = CC.MARKS[mark]
    if not m then return end
    local def = CC.RowSpell(mark, CC.Choices(CC.Presence()))
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:AddLine(m.name, m.rgb[1], m.rgb[2], m.rgb[3])
    if def then
        GameTooltip:AddLine(def.spell or def.key, 1, 1, 1)
        if def.note then GameTooltip:AddLine(def.note, 0.7, 0.7, 0.7) end
        if def.dur and def.dur > 0 then
            GameTooltip:AddLine("Holds about " .. def.dur .. "s", 0.6, 0.6, 0.6)
        end
    end
    local holders = A.GetCCForMark(mark)
    if table.getn(holders) == 0 then
        GameTooltip:AddLine("Unassigned", 0.7, 0.7, 0.7)
    else
        for i = 1, table.getn(holders) do
            local hd = A.duties[holders[i].key]
            GameTooltip:AddLine(holders[i].caster .. "  ->  "
                .. ((hd and hd.spell) or holders[i].key), 0.5, 1, 0.5)
        end
        if table.getn(holders) > 1 then
            GameTooltip:AddLine("Two people are on this mark - only one should be.",
                1, 0.42, 0.42)
        end
    end
    GameTooltip:AddLine("Wheel: which spell", 0.6, 0.6, 0.6)
    GameTooltip:AddLine("Click: who casts it (right-click cycles back)", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

function CC.Build(p)
    for i = 1, table.getn(CC.ORDER) do
        local mark = CC.ORDER[i]
        local row = MakeCell(p, 708, CC.ROW_H)
        row:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -46 - (i - 1) * (CC.ROW_H + 2))
        row.mark = mark

        -- the mark icon is its own button INSIDE the row: clicking it marks
        -- your target, clicking anywhere else assigns the caster
        local mb = MakeCell(row, 34, 34)
        mb:SetPoint("LEFT", row, "LEFT", 5, 0)
        mb.mark = mark
        local mi = mb:CreateTexture(nil, "ARTWORK")
        mi:SetWidth(24); mi:SetHeight(24)
        mi:SetPoint("CENTER", mb, "CENTER", 0, 0)
        mi:SetTexture(CC.MARKS[mark].tex)
        mb:SetScript("OnClick", CC.MarkClick)
        -- MakeCell enables the wheel on every cell, so without this the wheel
        -- would go dead over the third of the row nearest the icon
        mb:SetScript("OnMouseWheel", CC.RowWheel)
        mb:SetScript("OnEnter", SafeTip(CC.MarkTip))
        mb:SetScript("OnLeave", function() GameTooltip:Hide() end)

        row.mname = Fnt(row, 11, CC.MARKS[mark].rgb)
        row.mname:SetWidth(64); row.mname:SetHeight(12)
        row.mname:SetPoint("TOPLEFT", row, "TOPLEFT", 46, -16)
        row.mname:SetText(CC.MARKS[mark].name)

        local si = row:CreateTexture(nil, "ARTWORK")
        si:SetWidth(26); si:SetHeight(26)
        si:SetPoint("LEFT", row, "LEFT", 116, 0)
        row.spellIcon = si

        row.spell = Fnt(row, 11, INK)
        row.spell:SetWidth(200); row.spell:SetHeight(12)
        row.spell:SetPoint("TOPLEFT", row, "TOPLEFT", 150, -9)
        row.note = Fnt(row, 9, INK_FAINT)
        row.note:SetWidth(200); row.note:SetHeight(10)
        row.note:SetPoint("TOPLEFT", row, "TOPLEFT", 150, -26)

        row.who = Fnt(row, 12, INK, "RIGHT")
        row.who:SetWidth(230); row.who:SetHeight(13)
        row.who:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -8)
        row.whoSub = Fnt(row, 9, INK_FAINT, "RIGHT")
        row.whoSub:SetWidth(230); row.whoSub:SetHeight(10)
        row.whoSub:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -26)

        row:SetScript("OnClick", function()
            CC.RowClick((arg1 == "RightButton") and -1 or 1)
        end)
        row:SetScript("OnMouseWheel", CC.RowWheel)
        row:SetScript("OnEnter", SafeTip(CC.RowTip))
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        CC.rows[i] = row
    end
end

function CC.Refresh(p)
    local pres = CC.Presence()
    local choices = CC.Choices(pres)
    local assigned, clash = 0, 0
    for i = 1, table.getn(CC.ORDER) do
        local row, mark = CC.rows[i], CC.ORDER[i]
        local def, who, n = CC.RowSpell(mark, choices)
        if def then
            local tex = DutyIcon(def)
            if tex then row.spellIcon:SetTexture(tex); row.spellIcon:Show()
            else row.spellIcon:Hide() end
            row.spell:SetText(def.spell or def.key)
            row.note:SetText(def.note or TitleCase(def.class))
        else
            row.spellIcon:Hide()
            row.spell:SetText("|cff777777no crowd control in the catalog|r")
            row.note:SetText("")
        end
        if who then
            assigned = assigned + 1
            local rgb = CLASS_RGB[def and def.class] or INK
            row.who:SetText(who)
            row.who:SetTextColor(rgb[1], rgb[2], rgb[3])
            if n > 1 then
                clash = clash + 1
                row.whoSub:SetText("|cffff6b6b" .. (n - 1) .. " other claim"
                    .. ((n > 2) and "s" or "") .. "|r")
            else
                row.whoSub:SetText(SubFor(who, (def and def.class) or ""))
            end
            row:SetBackdropColor(0.13, 0.115, 0.085, 0.95)
        else
            row.who:SetText("-")
            row.who:SetTextColor(INK_FAINT[1], INK_FAINT[2], INK_FAINT[3])
            if def and not pres[def.class] then
                row.whoSub:SetText("no " .. TitleCase(def.class) .. " here")
            else
                row.whoSub:SetText("unassigned")
            end
            row:SetBackdropColor(0.10, 0.088, 0.07, 0.7)
        end
    end
    -- There is no "complete" here: a pull needs the CC it needs, not eight.
    -- So the count is plain, and the only thing worth colouring is a clash.
    p.note:SetText(assigned .. " assigned")
    if clash > 0 then
        p.note:SetTextColor(GAP_RED[1], GAP_RED[2], GAP_RED[3])
        p.cover:SetText("|cffff6b6bTwo people are on the same mark on "
            .. clash .. " row" .. ((clash > 1) and "s" or "") .. ".|r")
    else
        p.note:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        p.cover:SetText("")
    end
    p.hint:SetText("One row per raid mark, in kill order. Wheel a row for the spell, click "
        .. "it for who casts it (right-click cycles back). Click the icon to put that mark "
        .. "on your current target. Lead/assist assigns anyone; everyone else claims or "
        .. "drops their own mark. Synced to the raid.")
end

--------------------------------------------------------------------------
-- ROTATION TABS - who interrupts, and who taunts.
--
-- Two rotations, one engine. They ask the same question ("whose turn is it?")
-- and answer it the same way, so kicks and taunts share every line below and
-- differ only in a catalog entry: which spells, how long the cooldown, which
-- classes have one. A third rotation costs a table entry, not another engine.
--
-- YOUR own cooldown is exact (GetSpellCooldown); other people's are best
-- effort - they broadcast theirs over RPCX (exact, and at any distance), and
-- with SuperWoW we also observe their casts and time it locally as a fallback.
-- We can't read another player's spellbook, so capability is by CLASS, not
-- spec: a fury warrior appears in the taunt list, and a leader who knows the
-- raid simply doesn't put them in the rotation.
--------------------------------------------------------------------------

-- names = spell(s) to match, best first; cd = seconds (Vanilla defaults,
-- Turtle-unverified - edit here if a value differs); icon = fallback texture
-- for members whose spell we can't read.
local INTERRUPTS = {
    WARRIOR = { names = { "Pummel", "Shield Bash" }, cd = 10,
                icon = "Interface\\Icons\\Ability_Warrior_PunishingBlow", label = "Pummel / Shield Bash" },
    ROGUE   = { names = { "Kick" }, cd = 10,
                icon = "Interface\\Icons\\Ability_Kick", label = "Kick" },
    MAGE    = { names = { "Counterspell" }, cd = 30,
                icon = "Interface\\Icons\\Spell_Frost_IceShock", label = "Counterspell" },
    SHAMAN  = { names = { "Earth Shock" }, cd = 6,
                icon = "Interface\\Icons\\Spell_Nature_EarthShock", label = "Earth Shock" },
    WARLOCK = { names = { "Spell Lock" }, cd = 24,
                icon = "Interface\\Icons\\Spell_Shadow_MindRot", label = "Spell Lock (pet)" },
}

-- Taunts. Warrior Taunt and druid Growl only. Mocking Blow is a taunt too, but
-- on a two-minute cooldown it is never part of a rotation and one `cd` per
-- class means listing it would time every warrior's Taunt wrong. Turtle's
-- tanking paladins and shamans hold threat without a taunt as far as we have
-- verified on-realm - if that changes, one entry here is the whole fix.
local TAUNTS = {
    WARRIOR = { names = { "Taunt" }, cd = 10,
                icon = "Interface\\Icons\\Spell_Nature_Reincarnation", label = "Taunt" },
    DRUID   = { names = { "Growl" }, cd = 10,
                icon = "Interface\\Icons\\Ability_Physical_Taunt", label = "Growl" },
    -- Turtle's own tanking taunts. Name, range, cooldown and effect are
    -- confirmed on-realm from their tooltips; both are instant on a 10s
    -- cooldown, so they fit the one-cd-per-class shape unchanged.
    --
    -- The ICONS are a guess and were NOT confirmed - these are Turtle custom
    -- spells and their art may be anything. It only shows on OTHER members'
    -- rows: your own row takes the real texture from your spellbook via
    -- MyAbility. Correct them here if they look wrong in the Rotations tab.
    --
    -- Earthshaker Slam additionally "Requires Shields". We cannot see another
    -- player's equipment, and a detection that cannot answer must not close a
    -- gate, so a shaman shows as available and the leader decides - the same
    -- call as listing a fury warrior in the taunt list.
    PALADIN = { names = { "Hand of Reckoning" }, cd = 10,
                icon = "Interface\\Icons\\Spell_Holy_UnyieldingFaith", label = "Hand of Reckoning" },
    SHAMAN  = { names = { "Earthshaker Slam" }, cd = 10,
                icon = "Interface\\Icons\\Ability_Warrior_ShieldBash", label = "Earthshaker Slam (shield)" },
}

-- Everything that differs between the two rotations, and all of their live
-- state. The functions below take one of these records and are otherwise
-- identical, which is the whole point of the table.
--   ready/src : OTHER players' cooldowns - when they're up again, and how we
--               learned it ("sync" = they told us, exact and at any range;
--               "seen" = we watched their cast, so they had to be visible).
--               A synced report always wins.
--   send      : global name of the sync sender (looked up with getglobal, so
--               load order between the panel and the sync layer can't bite).
local ROT = {
    kick = {
        kind = "kick", cat = INTERRUPTS, order = { "WARRIOR", "ROGUE", "SHAMAN", "MAGE", "WARLOCK" },
        title = "Kick", verb = "kick", noun = "interrupt", act = "interrupted the cast",
        send = "AegisRP_SendKick", sound = "kickSound",
        sim = { "Grommash", "Valeera", "Thrall", "Jaina", "Guldan" },
        ready = {}, src = {}, cells = {}, myReady = true, testUntil = 0,
    },
    taunt = {
        kind = "taunt", cat = TAUNTS, order = { "WARRIOR", "PALADIN", "DRUID", "SHAMAN" },
        title = "Taunt", verb = "taunt", noun = "taunt", act = "taunted the boss",
        send = "AegisRP_SendTaunt", sound = "tauntSound",
        sim = { "Grommash", "Tirion", "Fandral", "Rehgar" },
        ready = {}, src = {}, cells = {}, myReady = true, testUntil = 0,
    },
}
local ROT_KINDS = { "kick", "taunt" }        -- fixed iteration order

-- Observe OTHER players' rotation abilities through the shared cast watcher
-- (Core\Aegis_CastWatch.lua owns the single UNIT_CASTEVENT handler). Confirmed
-- working on Turtle 1.18.1. Always-on, so the timers stay warm whether or not
-- the panel is open; without SuperWoW this never fires and others show "ready".
-- UNIT_CASTEVENT storms, so this stays O(1): one class lookup, then at most a
-- handful of string compares against two small catalogs.
if AegisRP.CastWatch then
    AegisRP.CastWatch.Subscribe(function(caster, target, spell, id, evt)
        if evt ~= "CAST" and evt ~= "START" then return end
        if not spell or caster == Me() then return end
        local cls = MemberClass(caster)
        if not cls then return end
        for k = 1, table.getn(ROT_KINDS) do
            local r = ROT[ROT_KINDS[k]]
            local info = r.cat[cls]
            if info then
                for i = 1, table.getn(info.names) do
                    if info.names[i] == spell then
                        r.ready[caster] = GetTime() + info.cd
                        r.src[caster] = "seen"
                    end
                end
            end
        end
    end)
end

-- Installed by the sync layer when a member reports their own ability going on
-- cooldown (RPCX "KICK" / "TNT"). Exact, and - unlike watching their cast - it
-- reaches us however far away they are, which is the whole point: observation
-- needs them in range, a broadcast doesn't.
function AegisRP.NoteRemoteCooldown(kind, name, cd)
    local r = ROT[kind]
    if not (r and name and cd and cd > 0) then return end
    r.ready[name] = GetTime() + cd
    r.src[name] = "sync"
end

-- kept because it was the documented entry point before taunts existed
function AegisRP.NoteRemoteKick(name, cd)
    AegisRP.NoteRemoteCooldown("kick", name, cd)
end

-- MY ability for a rotation: the first of my class's spells I actually know.
-- Returns spell record, catalog info, and the matched spell name.
local function MyAbility(r)
    local _, tok = UnitClass("player")
    local info = tok and r.cat[tok]
    if not info then return nil, nil, nil end
    for i = 1, table.getn(info.names) do
        local nm = info.names[i]
        local sp = AegisRP.FindSpell and AegisRP.FindSpell(nm)
        if sp then return sp, info, nm end
    end
    return nil, info, nil
end

-- Does MY class have this ability at all? Resolved once and cached on the
-- record - a character's class can't change, so the always-on tickers below
-- shouldn't re-derive it every tick (nor run at all on a priest). UnitClass is
-- unreliable before PLAYER_LOGIN, so nil means "not resolved yet", not "no".
local function MyClassHas(r)
    if r.myHas == nil then
        local _, tok = UnitClass("player")
        if not tok then return false end
        r.myHas = r.cat[tok] and true or false
    end
    return r.myHas
end

-- remaining cooldown (seconds) for a member, or 0 when ready/unknown.
local function RotRemaining(r, name)
    if name == Me() then
        -- test mode can't fake GetSpellCooldown, so the simulation stamps
        -- r.testUntil instead and we read that while testing
        if AegisRP.IsTestMode() then
            local t = r.testUntil - GetTime()
            return (t > 0) and t or 0
        end
        local sp = MyAbility(r)
        if not sp then return 0 end
        local start, dur = GetSpellCooldown(sp.index, "spell")
        if start and dur and dur > 1.5 then
            local t = start + dur - GetTime()
            if t > 0 then return t end
        end
        return 0
    end
    local t = r.ready[name]
    if t and t > GetTime() then return t - GetTime() end
    return 0
end

-- Announce MY cooldown the moment it starts, so members who can't see me still
-- get an exact timer. This reads my OWN cooldown rather than a cast event, so
-- it needs no SuperWoW - even a bare 1.12 client contributes to everyone else's
-- tab. Always-on (not gated on the panel being open), and it sends the real
-- remaining time, so talent-reduced cooldowns and the poll delay both come out
-- right. One poller drives both rotations: a protection warrior has an
-- interrupt AND a taunt, and that shouldn't cost two OnUpdates.
local rotPollAccum = 0
local rotPoll = CreateFrame("Frame")
rotPoll:SetScript("OnUpdate", function()
    rotPollAccum = rotPollAccum + (arg1 or 0)
    if rotPollAccum < 0.2 then return end
    rotPollAccum = 0
    for k = 1, table.getn(ROT_KINDS) do
        local r = ROT[ROT_KINDS[k]]
        if MyClassHas(r) then
            local sp = MyAbility(r)
            if sp then
                local start, dur = GetSpellCooldown(sp.index, "spell")
                local rem = 0
                if start and dur and dur > 1.5 then rem = start + dur - GetTime() end
                if rem > 0 then
                    if r.myReady then
                        local send = getglobal(r.send)
                        if send then send(rem) end
                    end
                    r.myReady = false
                else
                    r.myReady = true
                end
            end
        end
    end
end)

--------------------------------------------------------------------------
-- WHOSE TURN IS IT? - derived, never stored.
--
-- A rotation is only a priority ORDER. Who is up is "the first person in that
-- order whose ability is actually available", so using it puts you on cooldown
-- and hands the top spot to the next person by itself. No turn pointer exists
-- to drift between clients, survive a wipe wrongly, or need syncing - every
-- client computes the same answer from the same shared data.
--------------------------------------------------------------------------

-- raid/party unit token for a name, or nil when they aren't grouped with us
local function UnitTokenOf(name)
    if not name then return nil end
    local n = GetNumRaidMembers()
    if n > 0 then
        for i = 1, n do
            if UnitName("raid" .. i) == name then return "raid" .. i end
        end
        return nil
    end
    if name == Me() then return "player" end
    for i = 1, GetNumPartyMembers() do
        if UnitName("party" .. i) == name then return "party" .. i end
    end
    return nil
end

-- Can `name` act right now? Off cooldown, present and alive. A dead or absent
-- member is skipped rather than stalling the whole rotation behind them.
local function RotAvailable(r, name)
    if RotRemaining(r, name) > 0 then return false end
    if AegisRP.IsTestMode() then return true end   -- preview raid is always "there"
    local unit = UnitTokenOf(name)
    if not unit then return false end              -- left the group
    if UnitIsDeadOrGhost(unit) then return false end
    return true
end

-- The ordered available members: [1] is up now, [2] is on deck.
local function RotQueue(r)
    local order = A.GetRotation(r.kind)
    local out = {}
    for i = 1, table.getn(order) do
        if RotAvailable(r, order[i]) then table.insert(out, order[i]) end
    end
    return out
end

-- My standing: "now" | "deck" | "hold" | "cd" | nil (not in the rotation)
local function MyRotState(r)
    local me = Me()
    if not A.RotationIndexOf(r.kind, me) then return nil end
    if RotRemaining(r, me) > 0 then return "cd" end
    local q = RotQueue(r)
    if q[1] == me then return "now" end
    if q[2] == me then return "deck" end
    return "hold"
end

--------------------------------------------------------------------------
-- THE ROTATION STRIPS - your personal cue, not a roster.
--
-- The panel's Rotations tab is where a rotation gets PLANNED; a strip is where
-- it gets USED, so it answers exactly one question at a glance: is it me?
-- Colours keep the addon's language - red means act, never "you're fine" - so
-- it reads the same way as every other strip under pressure.
--------------------------------------------------------------------------

local ROT_STATE = {
    now  = { state = "need" },                              -- label is built per rotation
    deck = { label = "|cffffcc00On deck|r",  state = "warn" },
    hold = { label = "|cff5be07aHolding|r",  state = "good" },
    cd   = { label = "|cff888888Cooldown|r", state = "off"  },
}

-- "|cffRRGGBB" for a class token, so a strip row can colour a name the way the
-- panel grid does. (%02x is string.format's escape, not the banned % operator.)
local function ClassHex(tok)
    local c = tok and CLASS_RGB[tok]
    if not c then return "|cffcccccc" end
    return string.format("|cff%02x%02x%02x",
        math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255))
end

local function RotRowsOn() return AegisRP_Settings.rotQueue and true or false end

-- One queue row: the Nth name in the rotation ORDER, not the Nth available
-- person. Rows therefore keep the same names while cooldowns tick, instead of
-- reshuffling under your eye every time someone's ability comes back - the
-- live part is the status on the right, and "UP" marks whoever is actually on.
local function RotRowRefresh(r, idx, b)
    local name = A.GetRotation(r.kind)[idx]
    if not name then
        b:SetIcon("Interface\\Icons\\INV_Misc_QuestionMark")
        b:SetLabel("|cff666666" .. idx .. ". -|r")
        b:SetSub(""); b:SetTimer(""); b:SetState("off")
        return
    end
    local tok = MemberClass(name)
    local info = tok and r.cat[tok]
    local tex = info and info.icon
    if name == Me() then
        local sp = MyAbility(r)
        if sp and sp.texture then tex = sp.texture end
    end
    b:SetIcon(tex)
    b:SetLabel(ClassHex(tok) .. idx .. ". " .. name .. "|r")
    local rem = RotRemaining(r, name)
    b:SetTimer(rem > 0 and AegisRP.FmtTime(rem) or "")
    local q = RotQueue(r)
    if name == q[1] then
        b:SetSub("|cffff4040UP|r");            b:SetState("need")
    elseif rem > 0 then
        b:SetSub("|cff888888cooldown|r");      b:SetState("off")
    elseif RotAvailable(r, name) then
        b:SetSub("|cff5be07aready|r");         b:SetState("good")
    else
        b:SetSub("|cff888888away|r");          b:SetState("off")
    end
end

local function BuildRotStrip(r)
    if r.strip then return r.strip end
    r.strip = AegisRP.NewStrip(r.kind, r.title)
    r.strip:AddButton{
        -- keyed per rotation, not "rotation": Reflow gates a button on
        -- AegisRP_Settings["btn_" .. key], so a shared key would make hiding
        -- the kick button hide the taunt one with it
        key = r.kind,
        refresh = function(b)
            local st = MyRotState(r)
            local sp, info = MyAbility(r)
            b:SetIcon((sp and sp.texture) or (info and info.icon))
            if not st then
                -- not in the rotation: say so rather than implying readiness
                b:SetLabel("|cffffd100" .. r.title .. "|r")
                b:SetSub("|cff888888not in rotation|r")
                b:SetTimer(""); b:SetState("off")
                return
            end
            local d = ROT_STATE[st]
            b:SetLabel(d.label or ("|cffff4040" .. string.upper(r.verb) .. " NOW|r"))
            b:SetState(d.state)
            local rem = RotRemaining(r, Me())
            b:SetTimer(rem > 0 and AegisRP.FmtTime(rem) or "")
            local q = RotQueue(r)
            if st == "now" then
                b:SetSub(q[2] and ("|cff999999then " .. q[2] .. "|r") or "")
            elseif q[1] then
                b:SetSub("|cff999999up: " .. q[1] .. "|r")
            else
                b:SetSub("|cffff6060nobody ready|r")
            end
        end,
        onClick = function() if AegisRP_AssignPanelToggle then AegisRP_AssignPanelToggle() end end,
        tooltip = function(b, tt)
            tt:AddLine(r.title .. " rotation", 1, 1, 1)
            local order = A.GetRotation(r.kind)
            if table.getn(order) == 0 then
                tt:AddLine("No rotation set - a leader sets one on the panel's Rotations tab.",
                    0.7, 0.7, 0.7)
            else
                for i = 1, table.getn(order) do
                    local nm = order[i]
                    local mark = RotAvailable(r, nm) and "|cff5be07a*|r " or "|cff777777-|r "
                    local rem = RotRemaining(r, nm)
                    tt:AddLine(mark .. i .. ". " .. nm
                        .. (rem > 0 and ("  |cffff6060" .. math.floor(rem + 0.5) .. "s|r") or ""),
                        0.85, 0.85, 0.85)
                end
                tt:AddLine("Whoever is highest and off cooldown is up.", 0.55, 0.55, 0.62)
            end
            tt:AddLine("Click: open the assignment panel.", 0.6, 0.6, 0.6)
        end,
    }
    -- The optional "next three" rows (Options > Settings > Show the next three).
    -- Off by default: the one button above answers "is it me", which is all
    -- most people want mid-pull, and three more rows is a lot of screen for a
    -- question the tooltip already answers on demand.
    for i = 1, 3 do
        local idx = i
        r.strip:AddButton{
            key = r.kind .. "q" .. idx,
            visible = RotRowsOn,
            refresh = function(b) RotRowRefresh(r, idx, b) end,
            onClick = function()
                if AegisRP_AssignPanelToggle then AegisRP_AssignPanelToggle() end
            end,
            tooltip = function(b, tt)
                local name = A.GetRotation(r.kind)[idx]
                if not name then
                    tt:AddLine(r.title .. " rotation", 1, 1, 1)
                    tt:AddLine("Slot " .. idx .. " is empty - a leader fills it on the "
                        .. "panel's Rotations tab.", 0.7, 0.7, 0.7)
                    return
                end
                tt:AddLine(name, 1, 1, 1)
                local info = r.cat[MemberClass(name)]
                if info then
                    tt:AddLine((info.label or r.title) .. "  -  " .. info.cd .. "s CD",
                        0.7, 0.9, 0.7)
                end
                local rem = RotRemaining(r, name)
                if rem > 0 then
                    tt:AddLine("On cooldown: " .. math.floor(rem + 0.5) .. "s", 1, 0.5, 0.4)
                elseif RotAvailable(r, name) then
                    tt:AddLine("Ready", 0.4, 0.9, 0.5)
                else
                    tt:AddLine("Dead or out of the group - the rotation skips them.",
                        0.8, 0.5, 0.5)
                end
                tt:AddLine("#" .. idx .. " in the " .. r.verb .. " rotation.", 0.55, 0.55, 0.62)
            end,
        }
    end
    r.strip:Finish()
    return r.strip
end

-- True when the player's class has the ability at all (drives whether the strip
-- and its options exist). Exported for the Options tab.
function AegisRP.HasInterrupt() return MyClassHas(ROT.kick) end
function AegisRP.HasTaunt()     return MyClassHas(ROT.taunt) end

function AegisRP.BuildKickStrip()  return BuildRotStrip(ROT.kick)  end
function AegisRP.BuildTauntStrip() return BuildRotStrip(ROT.taunt) end

-- Build the strips once, for classes that actually have the ability. Deferred
-- to login because it needs the player's class. Hiding works exactly like every
-- other strip - /rpc kick, /rpc taunt - and the strip engine remembers it.
local rotInit = CreateFrame("Frame")
rotInit:RegisterEvent("PLAYER_LOGIN")
rotInit:SetScript("OnEvent", function()
    for k = 1, table.getn(ROT_KINDS) do
        local r = ROT[ROT_KINDS[k]]
        if MyClassHas(r) then
            local ok, err = pcall(BuildRotStrip, r)
            if not ok then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff5555Aegis error:|r " .. tostring(err)
                    .. " |cffaaaaaa(" .. r.kind .. " strip)|r")
            end
        end
    end
end)

-- /rpc kick, /rpc taunt - show/hide (also builds on first use)
local function ToggleRotStrip(r)
    if not MyClassHas(r) then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffff00Aegis:|r your class has no " .. r.noun .. ".")
        return
    end
    local s = BuildRotStrip(r)
    if s and s.Toggle then s:Toggle() end
end

function AegisRP_ToggleKickStrip()  ToggleRotStrip(ROT.kick)  end
function AegisRP_ToggleTauntStrip() ToggleRotStrip(ROT.taunt) end

--------------------------------------------------------------------------
-- TEST-MODE SIMULATION - watch a rotation actually run, solo.
--
-- Every few seconds a pretend mob casts (or drops threat) and whoever is up
-- handles it, which starts their cooldown and hands the top spot to the next
-- person. The point is that YOUR strip cycles through all four states on its
-- own - up, cooldown, holding, on deck - so the thing can be judged without a
-- raid. The rotations used are the preview ones (a separate store), so nothing
-- here touches a real raid's plan or the wire.
--------------------------------------------------------------------------

local SIM_PERIOD = 4              -- a simulated event this often, per rotation

local function SeedSimRotation(r)
    if table.getn(A.GetRotation(r.kind)) > 0 then return true end
    local list = {}
    for i = 1, table.getn(r.sim) do
        local nm = r.sim[i]
        -- only seat preview names the fake raid actually has the ability for
        if r.cat[MemberClass(nm)] then table.insert(list, nm) end
    end
    -- The preview raid is seated asynchronously when test mode turns on, so an
    -- empty result means "not ready yet" - report failure and retry next tick
    -- rather than locking in a rotation of one.
    if table.getn(list) == 0 then return false end
    if r.cat[MemberClass(Me())] then table.insert(list, 1, Me()) end
    return A.SetRotation(r.kind, list)
end

local function SimAct(r, who)
    local info = r.cat[MemberClass(who)]
    local cd = (info and info.cd) or 10
    if who == Me() then
        r.testUntil = GetTime() + cd
    else
        r.ready[who] = GetTime() + cd
        r.src[who] = "sync"
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cffff8800[test]|r "
        .. ((who == Me()) and "|cff5be07ayou|r" or who) .. " " .. r.act .. " ("
        .. cd .. "s cooldown).")
end

local rotSim = CreateFrame("Frame")
rotSim:SetScript("OnUpdate", function()
    if not AegisRP.IsTestMode() then
        for k = 1, table.getn(ROT_KINDS) do
            ROT[ROT_KINDS[k]].seeded = false      -- re-seed next time test mode comes on
        end
        return
    end
    for k = 1, table.getn(ROT_KINDS) do
        local r = ROT[ROT_KINDS[k]]
        if not r.seeded then
            r.seeded = SeedSimRotation(r) and true or false
            r.simAccum = 0
        elseif MyClassHas(r) then
            -- only simulate rotations the player is actually in: a mage
            -- watching taunts cycle would just be noise in their chat
            r.simAccum = (r.simAccum or 0) + (arg1 or 0)
            if r.simAccum >= SIM_PERIOD then
                r.simAccum = 0
                local q = RotQueue(r)
                if q[1] then
                    SimAct(r, q[1])
                else
                    DEFAULT_CHAT_FRAME:AddMessage("|cffff8800[test]|r a " .. r.verb
                        .. " was needed - everyone was on cooldown.")
                end
            end
        end
    end
end)

-- The "you're up" cue. Fires on the edge into `now` only, so it can't machine-
-- gun while you sit at the top of a rotation waiting.
local rotCueAccum = 0
local rotCue = CreateFrame("Frame")
rotCue:SetScript("OnUpdate", function()
    rotCueAccum = rotCueAccum + (arg1 or 0)
    if rotCueAccum < 0.2 then return end
    rotCueAccum = 0
    for k = 1, table.getn(ROT_KINDS) do
        local r = ROT[ROT_KINDS[k]]
        if MyClassHas(r) then
            local st = MyRotState(r)
            if st == "now" and r.lastState ~= "now"
               and AegisRP_Settings[r.sound] ~= false then
                PlaySoundFile("Interface\\Addons\\Aegis_RallyPower\\Sounds\\ding.mp3")
            end
            r.lastState = st
        end
    end
end)

--------------------------------------------------------------------------
-- THE ROTATIONS TAB - one grid, two views.
--
-- Kicks and taunts get one tab rather than two because the panel's tab row is
-- full at six and because they are the same list with a different ability
-- column; the view switch is the same control the Raid Buffs tab already uses.
--------------------------------------------------------------------------

local ROT_COLS, ROT_ROWS = 2, 15
local ROT_CELL_W = 344

local function RotView()
    return ROT[AegisRP_Settings.rotView or "kick"] or ROT.kick
end

-- capable members: you first, then everyone else in class order.
local function RotMembers(r)
    local me = Me()
    local _, mytok = UnitClass("player")
    local all = AllMembers()
    local out = {}
    if mytok and r.cat[mytok] then table.insert(out, me) end
    for _, tok in ipairs(r.order) do
        for i = 1, table.getn(all) do
            local nm = all[i]
            if nm ~= me and MemberClass(nm) == tok then table.insert(out, nm) end
        end
    end
    return out
end

local function RotCellTip()
    if AegisRP_Settings.tooltips == false then return end
    local r = RotView()
    local name = this.member
    local tok = MemberClass(name)
    local info = tok and r.cat[tok]
    local shown = false
    if name == Me() then
        local _, _, nm = MyAbility(r)
        if nm then shown = SpellTip(this, nm) end
    end
    if not shown then
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(name, 1, 1, 1)
    end
    if info then
        GameTooltip:AddLine((info.label or r.title) .. "  -  " .. info.cd .. "s CD", 0.7, 0.9, 0.7)
    end
    local rem = RotRemaining(r, name)
    if rem > 0 then
        GameTooltip:AddLine("On cooldown: " .. math.floor(rem + 0.5) .. "s", 1, 0.5, 0.4)
    else
        GameTooltip:AddLine("Ready", 0.4, 0.9, 0.5)
    end
    if name ~= Me() then
        local src = r.src[name]
        if src == "sync" then
            GameTooltip:AddLine("Exact - reported by their Aegis, any distance.", 0.5, 0.8, 0.6)
        elseif src == "seen" then
            GameTooltip:AddLine("Observed from their cast (needed them in range).", 0.55, 0.55, 0.62)
        else
            GameTooltip:AddLine(SUPERWOW_VERSION
                and "No data yet - they report it when they use it, or we watch them cast."
                or "Others' live cooldowns need SuperWoW, or Aegis on their client.",
                0.55, 0.55, 0.62)
        end
    end
    GameTooltip:Show()
end

-- Click a row to put someone in the rotation (or take them out); wheel moves
-- them up and down it. Both are leader-gated by the model, so a member just
-- gets told rather than silently having nothing happen.
local function RotCellClick()
    local r = RotView()
    if not A.ToggleRotationMember(r.kind, this.member) then
        if table.getn(A.GetRotation(r.kind)) >= A.MaxRotation()
           and not A.RotationIndexOf(r.kind, this.member) then
            Msg("The rotation is full (" .. A.MaxRotation() .. ").")
        else
            Msg("Only the raid leader / assist can set the " .. r.verb
                .. " rotation (or turn on Free Assign).")
        end
        return
    end
    RefreshCurrent()
end

local function RotCellWheel()
    local r = RotView()
    if not A.RotationIndexOf(r.kind, this.member) then return end   -- not in it
    if not A.MoveRotationMember(r.kind, this.member, (arg1 > 0) and -1 or 1) then return end
    RefreshCurrent()
end

local function RotViewToggle()
    AegisRP_Settings.rotView = (AegisRP_Settings.rotView == "taunt") and "kick" or "taunt"
    RefreshCurrent()
end

local function RotViewTip()
    if AegisRP_Settings.tooltips == false then return end
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText("Rotation", 1, 1, 1)
    GameTooltip:AddLine("Kick - who interrupts, in what order.", 0.7, 0.7, 0.7, 1)
    GameTooltip:AddLine("Taunt - who picks the boss up, in what order.", 0.7, 0.7, 0.7, 1)
    GameTooltip:AddLine("They are separate lists and sync separately; each has its "
        .. "own strip.", 0.55, 0.55, 0.62, 1)
    GameTooltip:Show()
end

local function BuildRotTab(p)
    -- view toggle, parked on the panel so it costs no file-scope local
    local tg = MakeCell(p, 92, 18)
    tg:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -20)
    tg.label = Fnt(tg, 10, GOLD, "CENTER")
    tg.label:SetWidth(92); tg.label:SetHeight(11)
    tg.label:SetPoint("CENTER", tg, "CENTER", 0, 0)
    tg:SetScript("OnClick", RotViewToggle)
    tg:SetScript("OnEnter", SafeTip(RotViewTip))
    tg:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p.rotToggle = tg

    for i = 1, ROT_COLS * ROT_ROWS do
        local col = math.mod(i - 1, ROT_COLS)
        local rowN = math.floor((i - 1) / ROT_COLS)
        local b = MakeCell(p, ROT_CELL_W, 24)
        b:SetPoint("TOPLEFT", p, "TOPLEFT", col * (ROT_CELL_W + 8), -44 - rowN * 26)
        local ic = b:CreateTexture(nil, "ARTWORK")
        ic:SetWidth(18); ic:SetHeight(18)
        ic:SetPoint("LEFT", b, "LEFT", 6, 0)
        b.icon = ic
        b.name = Fnt(b, 11, INK)
        b.name:SetWidth(200); b.name:SetHeight(12)
        b.name:SetPoint("LEFT", b, "LEFT", 30, 0)
        b.stat = Fnt(b, 11, INK_DIM, "RIGHT")
        b.stat:SetWidth(90); b.stat:SetHeight(12)
        b.stat:SetPoint("RIGHT", b, "RIGHT", -8, 0)
        b.pos = Fnt(b, 11, GOLD, "RIGHT")
        b.pos:SetWidth(46); b.pos:SetHeight(12)
        b.pos:SetPoint("RIGHT", b, "RIGHT", -100, 0)
        b:SetScript("OnEnter", SafeTip(RotCellTip))
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetScript("OnClick", RotCellClick)
        b:SetScript("OnMouseWheel", RotCellWheel)
        b:EnableMouseWheel(true)
        b:Hide()
        p.rotCells = p.rotCells or {}
        p.rotCells[i] = b
    end
end

local function RefreshRotTab(p)
    local r = RotView()
    if p.rotToggle then
        p.rotToggle.label:SetText("|cffd8b98a" .. r.title .. " \226\150\190|r")
    end
    local members = RotMembers(r)
    local cap = ROT_COLS * ROT_ROWS
    local ready, oncd = 0, 0
    local q = RotQueue(r)
    local upNow, upNext = q[1], q[2]
    for i = 1, cap do
        local b = p.rotCells[i]
        local name = members[i]
        if name then
            b.member = name
            local tok = MemberClass(name)
            local info = tok and r.cat[tok]
            local cc = (tok and CLASS_RGB[tok]) or INK
            b.name:SetText(name)
            b.name:SetTextColor(cc[1], cc[2], cc[3])
            local tex = info and info.icon
            if name == Me() then
                local sp = MyAbility(r)
                if sp and sp.texture then tex = sp.texture end
            end
            if tex then b.icon:SetTexture(tex); b.icon:Show() else b.icon:Hide() end
            -- rotation position, and who is actually up right now
            local slot = A.RotationIndexOf(r.kind, name)
            if slot then
                if name == upNow then
                    b.pos:SetText("|cffff6060UP|r")
                elseif name == upNext then
                    b.pos:SetText("|cffffcc00next|r")
                else
                    b.pos:SetText("|cffaa9966#" .. slot .. "|r")
                end
            else
                b.pos:SetText("")
            end
            local rem = RotRemaining(r, name)
            if rem > 0 then
                oncd = oncd + 1
                b.stat:SetText("|cffff6060" .. math.floor(rem + 0.5) .. "s|r")
                b:SetBackdropColor(0.16, 0.09, 0.08, 0.9)
            else
                ready = ready + 1
                b.stat:SetText("|cff5be07aReady|r")
                b:SetBackdropColor(slot and 0.10 or 0.09, 0.13, slot and 0.16 or 0.09, 0.85)
            end
            b:Show()
        else
            b:Hide()
        end
    end
    p.note:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    local rot = table.getn(A.GetRotation(r.kind))
    p.note:SetText(ready .. " ready, " .. oncd .. " on CD"
        .. (rot > 0 and ("  |cffaa9966|  rotation of " .. rot
            .. (upNow and (" - |cffff6060" .. upNow .. "|r|cffaa9966 is up") or " - none ready")
            .. "|r") or ""))
    if table.getn(members) == 0 then
        p.cover:SetText("|cffaa8866Nobody here has a " .. r.verb .. ".|r")
    else
        p.cover:SetText("")
    end
    p.hint:SetText("Click a name to put them in the " .. r.verb
        .. " rotation; wheel moves them up or down it. "
        .. "Whoever sits highest AND is off cooldown is up next, so using it hands the "
        .. "spot to the next person automatically and the dead or absent get skipped. "
        .. "Your own cooldown is exact; others report theirs over sync, or are observed "
        .. "from their casts when in range.")
end

-- Tank slots: Main Tank + two off-tanks, chosen from dropdowns. Membership
-- rides PallyPower_Tanks (SetRole) so blessings + the no-Salv rule + interop
-- keep working; the MT/OT ORDER is Aegis-only and rides RPCX.
local SLOT_LABELS = { "Main Tank", "Off-Tank 1", "Off-Tank 2" }
local tankDD = {}          -- dropdown frames
local tankBlessDD = {}     -- per-slot blessing dropdowns ("gets instead of Salv")

-- Only classes that can actually hold a target can be tanks, so the tank
-- dropdowns list them alone: this keeps the menu short (a 40-man's rogues,
-- hunters, mages, warlocks and priests would blow past the UIDropDownMenu
-- button cap and clip names) and removes nonsensical picks. Shaman is included
-- because Turtle WoW has a tanking shaman spec. Edit here if that changes.
local TANK_CLASSES = { WARRIOR = true, PALADIN = true, DRUID = true, SHAMAN = true }
local function CanTank(name) return TANK_CLASSES[MemberClass(name)] and true or false end

-- 1.12 UIDropDownMenu_SetWidth reads the implicit `this`; set it explicitly.
local function DDWidth(dd, w)
    local saved = this
    this = dd
    UIDropDownMenu_SetWidth(w, dd)
    this = saved
end

local function SetSlot(i, name)
    if name == "" then name = nil end
    if not A.SetTankSlot(i, name) then
        Msg("Only the raid leader / assist can set tanks (or turn on Free Assign).")
    end
    RefreshCurrent()
end

local function ToggleHealer(name)
    if A.TankSlotOf(name) then
        Msg(name .. " is a tank (set in the slots above); clear that slot to change.")
        return
    end
    local cur = A.GetRole(name)
    if not A.SetRole(name, (cur == "HEALER") and nil or "HEALER") then
        Msg("Only the raid leader / assist can set roles (or turn on Free Assign).")
    end
    RefreshCurrent()
end

-- The class ID a tank's blessing override is stored under (PallyPower keys
-- NormalAssignments by the TARGET's class).
local function TankCid(name)
    local tok = MemberClass(name)
    return tok and AegisRP.Token2ClassID and AegisRP.Token2ClassID[tok]
end

-- Set slot i's tank to blessing `bid` (-1 = class default). The dropdown menu
-- only offers castable picks; this re-checks permission on the way in.
local function SetTankBless(i, bid)
    local who = A.GetTankSlot(i)
    if not who then return end
    local cid = TankCid(who)
    if not cid then return end
    if not (AegisRP.PreviewNames and AegisRP.PreviewNames[who])
       and not (AllPallys and next(AllPallys)) then
        Msg("No paladins known - a tank blessing needs a paladin to cast it.")
        return
    end
    if not A.SetTankBlessing(who, cid, bid) then
        Msg("You can't set that blessing (need lead/assist).")
    end
    RefreshCurrent()
end

-- Current blessing short-name for a slot's tank ("Kings"), or nil = default.
local function SlotBlessName(who)
    local cid = who and TankCid(who)
    local bid = cid and A.GetTankBlessing(who, cid) or -1
    if bid >= 0 and PallyPower_BlessingID and PallyPower_BlessingID[bid] then
        return PallyPower_BlessingID[bid]
    end
    return nil
end

-- one tank-slot dropdown, capturing its slot index `i` (proven Options-tab
-- pattern: closure over the frame rather than the implicit `this`).
local function MakeTankDD(p, i)
    local nm = "AegisRP_RoleTankDD" .. i
    local dd = CreateFrame("Frame", nm, p, "UIDropDownMenuTemplate")
    UIDropDownMenu_Initialize(dd, function()
        local cur = A.GetTankSlot(i)
        local none = {}
        none.text = "(none)"; none.value = ""
        if not cur then none.checked = 1 end
        none.func = function() SetSlot(i, "") end
        UIDropDownMenu_AddButton(none)
        -- Only tank-capable classes (keeps the list short and sensible). The
        -- currently-set tank is always offered, even if a stale assignment put
        -- a non-tank class here, so the slot stays visible and clearable.
        local names = AllMembers()
        for j = 1, table.getn(names) do
            local who = names[j]
            if CanTank(who) or who == cur then
                local it = {}
                it.text = who; it.value = who
                if who == cur then it.checked = 1 end
                it.func = function() SetSlot(i, who) end
                UIDropDownMenu_AddButton(it)
            end
        end
    end)
    DDWidth(dd, 130)
    dd.glob = nm
    return dd
end

-- per-slot blessing dropdown: shows what that tank currently gets ("Class
-- default" / "Kings" / ...) and lists every blessing a paladin present can
-- actually cast (preview tanks offer all six - sandbox, no real cast). This
-- is the "what does my MT get instead of Salv" control.
local function MakeBlessDD(p, i)
    local nm = "AegisRP_RoleBlessDD" .. i
    local dd = CreateFrame("Frame", nm, p, "UIDropDownMenuTemplate")
    UIDropDownMenu_Initialize(dd, function()
        local who = A.GetTankSlot(i)
        if not who then
            local it = {}
            it.text = "(no tank in this slot)"
            it.func = function() end
            UIDropDownMenu_AddButton(it)
            return
        end
        local cid = TankCid(who)
        local cur = cid and A.GetTankBlessing(who, cid) or -1
        local preview = AegisRP.PreviewNames and AegisRP.PreviewNames[who]
        local function add(bid, label)
            local it = {}
            it.text = label
            if bid == cur then it.checked = 1 end
            it.func = function() SetTankBless(i, bid) end
            UIDropDownMenu_AddButton(it)
        end
        add(-1, "Class default")
        -- only blessings a paladin here can cast (a non-castable override
        -- would silently drop the tank's blessing); preview offers all six
        for bid = 0, 5 do
            if preview or A.TankBlessingCastable(bid) then
                add(bid, (PallyPower_BlessingID and PallyPower_BlessingID[bid])
                    or ("Blessing " .. bid))
            end
        end
    end)
    DDWidth(dd, 130)
    dd.glob = nm
    return dd
end

local function RoleCellTip()
    if AegisRP_Settings.tooltips == false then return end
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText(this.member, 1, 1, 1)
    local slot = A.TankSlotOf(this.member)
    if slot then
        GameTooltip:AddLine(SLOT_LABELS[slot] .. " (set in the slots above)", 0.6, 0.9, 0.6)
    else
        local role = A.GetRole(this.member)
        GameTooltip:AddLine(role == "HEALER" and "Healer" or "No role", 0.7, 0.9, 0.7)
        GameTooltip:AddLine("Left-click: toggle Healer", 0.6, 0.6, 0.6)
    end
    GameTooltip:AddLine("Shared with PallyPower.", 0.5, 0.6, 0.8)
    GameTooltip:Show()
end

local function RoleCellClick()
    ToggleHealer(this.member)
end

local function BuildRoles(p)
    -- three tank-slot columns across the top: who tanks, and what blessing
    -- they get instead of their class default (the no-Salv override)
    for i = 1, 3 do
        local x = (i - 1) * 236
        local capfs = Fnt(p, 11, GOLD)
        capfs:SetWidth(150); capfs:SetHeight(12)
        capfs:SetPoint("TOPLEFT", p, "TOPLEFT", x + 20, -46)
        capfs:SetText(SLOT_LABELS[i])
        local dd = MakeTankDD(p, i)
        dd:SetPoint("TOPLEFT", p, "TOPLEFT", x, -58)
        tankDD[i] = dd
        local bcap = Fnt(p, 9, INK_DIM)
        bcap:SetWidth(200); bcap:SetHeight(10)
        bcap:SetPoint("TOPLEFT", p, "TOPLEFT", x + 20, -92)
        bcap:SetText("gets (instead of Salv):")
        local bdd = MakeBlessDD(p, i)
        bdd:SetPoint("TOPLEFT", p, "TOPLEFT", x, -102)
        tankBlessDD[i] = bdd
    end
    -- healer grid below (3 columns; every member, click toggles Healer)
    for i = 1, ROLE_COLS * ROLE_ROWS do
        local col = math.mod(i - 1, ROLE_COLS)
        local rowN = math.floor((i - 1) / ROLE_COLS)
        local b = MakeCell(p, ROLE_CELL_W, 24)
        b:SetPoint("TOPLEFT", p, "TOPLEFT", col * (ROLE_CELL_W + 8), -142 - rowN * 25)
        b.name = Fnt(b, 11, INK)
        b.name:SetWidth(132); b.name:SetHeight(12)
        b.name:SetPoint("LEFT", b, "LEFT", 8, 0)
        b.role = Fnt(b, 10, INK_DIM, "RIGHT")
        b.role:SetWidth(70); b.role:SetHeight(12)
        b.role:SetPoint("RIGHT", b, "RIGHT", -6, 0)
        b:SetScript("OnClick", RoleCellClick)
        b:SetScript("OnEnter", SafeTip(RoleCellTip))
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:Hide()
        roleCells[i] = b
    end
end

local function RefreshRoles(p)
    -- tank slots: who, and the blessing they get (readable at a glance)
    for i = 1, 3 do
        local who = A.GetTankSlot(i)
        local txt = getglobal(tankDD[i].glob .. "Text")
        if txt then txt:SetText(who or "(none)") end
        local btxt = getglobal(tankBlessDD[i].glob .. "Text")
        if btxt then
            if who then
                local bn = SlotBlessName(who)
                btxt:SetText(bn and ("|cff5be07a" .. bn .. "|r") or "Class default")
            else
                btxt:SetText("|cff777777-|r")
            end
        end
    end
    -- healer grid
    local members = AllMembers()
    local cap = ROLE_COLS * ROLE_ROWS
    local ntank, nheal = 0, 0
    for i = 1, 3 do if A.GetTankSlot(i) then ntank = ntank + 1 end end
    for i = 1, cap do
        local b = roleCells[i]
        local name = members[i]
        if name then
            b.member = name
            local tok = MemberClass(name)
            local cc = (tok and CLASS_RGB[tok]) or INK
            b.name:SetText(name)
            b.name:SetTextColor(cc[1], cc[2], cc[3])
            local slot = A.TankSlotOf(name)
            if slot then
                b.role:SetText("|cff5be07aTank|r")
                b:SetBackdropColor(0.10, 0.15, 0.09, 0.9)
            elseif A.GetRole(name) == "HEALER" then
                nheal = nheal + 1
                b.role:SetText("|cff5b8fffHealer|r")
                b:SetBackdropColor(0.09, 0.11, 0.16, 0.9)
            else
                b.role:SetText("|cff777777-|r")
                b:SetBackdropColor(0.10, 0.088, 0.07, 0.7)
            end
            b:Show()
        else
            b:Hide()
        end
    end
    p.note:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    p.note:SetText(ntank .. (ntank == 1 and " tank, " or " tanks, ")
        .. nheal .. (nheal == 1 and " healer" or " healers"))
    p.cover:SetText("")
    p.hint:SetText("Pick your Main Tank and off-tanks from the top dropdowns; the dropdown "
        .. "under each slot sets the blessing that tank gets instead of Salvation "
        .. "(only blessings a paladin here can cast). Left-click a name below to mark "
        .. "a Healer. Shared with PallyPower and its no-Salvation-on-tanks rule.")
end

--------------------------------------------------------------------------
-- status pills (top right, concept header): TEST / leader / free assign / sync
--------------------------------------------------------------------------

local function MakePill(parent, w)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(w); b:SetHeight(17)
    b:SetBackdrop(CELL_BD)
    b:SetBackdropColor(0.09, 0.08, 0.06, 0.9)
    b:SetBackdropBorderColor(0.23, 0.20, 0.15, 1)
    local fs = Fnt(b, 9, INK_DIM, "CENTER")
    fs:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.text = fs
    return b
end

local function UpdatePills()
    if not pills.leader then return end
    if AegisRP.IsTestMode() then
        pills.test:Show()
    else
        pills.test:Hide()
    end
    local iLead = A.IAmLead()
    if GetNumRaidMembers() > 0 then
        pills.leader.text:SetText(iLead and "|cff5be07a\226\151\143|r Lead/Assist"
                                        or "|cff777777\226\151\143|r Member")
    elseif GetNumPartyMembers() > 0 then
        pills.leader.text:SetText(iLead and "|cff5be07a\226\151\143|r Party Lead"
                                        or "|cff777777\226\151\143|r Member")
    else
        pills.leader.text:SetText("|cff5be07a\226\151\143|r Solo")
    end
    -- Free Assignment is a synced raid-wide flag; only a leader can flip it,
    -- so it reflects the same value on every client
    pills.free:Show()
    if A.GetFreeAssign() then
        pills.free.text:SetText("|cff5be07a\226\151\143|r Free Assign: on")
    elseif iLead then
        pills.free.text:SetText("|cff777777\226\151\143|r Free Assign: off")
    else
        pills.free.text:SetText("|cff555555\226\151\143|r Free Assign: off")
    end
end

--------------------------------------------------------------------------
-- frame, tabs, bottom buttons
--------------------------------------------------------------------------

local function StyleTabs()
    for i = 1, table.getn(tabBtns) do
        local b = tabBtns[i]
        if i == currentTab then
            -- active tab merges into the content box (same fill, gold edge)
            b:SetBackdropColor(0.08, 0.072, 0.058, 1)
            b:SetBackdropBorderColor(GOLD_DIM[1], GOLD_DIM[2], GOLD_DIM[3], 1)
            b.label:SetTextColor(GOLD_BRIGHT[1], GOLD_BRIGHT[2], GOLD_BRIGHT[3])
        else
            b:SetBackdropColor(0.06, 0.052, 0.042, 0.95)
            b:SetBackdropBorderColor(0.18, 0.16, 0.12, 1)
            b.label:SetTextColor(INK_DIM[1], INK_DIM[2], INK_DIM[3])
        end
    end
end

local function RefreshInner()
    UpdatePills()
    local p = panels[currentTab]
    if currentTab == 1 then RefreshBlessings(p)
    elseif currentTab == 2 then RefreshTotems(p)
    elseif currentTab == 3 then RefreshBuffTab(p)
    elseif currentTab == 5 then RefreshRotTab(p)
    elseif currentTab == 6 then RefreshRoles(p)
    elseif currentTab == 7 then CC.Refresh(p)
    elseif DUTY_TAB[currentTab] then RefreshDutyTab(p, currentTab) end
end

RefreshCurrent = function()
    if not frame or not frame:IsShown() then return end
    local ok, err = pcall(RefreshInner)
    if not ok then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff5555Aegis error:|r "
            .. tostring(err) .. " |cffaaaaaa(assignment panel)|r")
    end
end

local function ShowTab(i)
    if not panels[i] then i = 1 end
    currentTab = i
    AegisRP_Settings.assignLastTab = i
    for n = 1, table.getn(panels) do
        if n == i then panels[n]:Show() else panels[n]:Hide() end
    end
    StyleTabs()
    RefreshCurrent()
end

-- Clear = the CURRENT tab only (blessings go through the legacy CLEAR
-- broadcast; totem/duty rows clear for every caster you may edit).
local function ClearCurrentTab()
    if currentTab == 1 then
        AegisRP_Settings.testBless = nil
        if PallyPower_Clear then PallyPower_Clear() end
        Msg("Blessing assignments cleared (for everyone you may edit).")
    elseif currentTab == 2 then
        local els = ElementList()
        for _, s in ipairs(MembersOfClass("SHAMAN")) do
            if A.CanEdit(Me(), s) then
                for i = 1, table.getn(els) do A.SetTotem(s, els[i], nil) end
                A.SetTotemParty(s, nil)
            end
        end
        Msg("Totem assignments cleared.")
    elseif currentTab == 3 then
        -- clear whichever view is on screen, not both: the two are separate
        -- plans and wiping the hidden one would be invisible destruction
        local grp = GroupViewOn()
        for _, entry in ipairs(BufferList()) do
            if A.CanEdit(Me(), entry.name) then
                if grp then A.ClearGroupBuffs(entry.name)
                else
                    for c = 0, 9 do A.SetClassBuff(entry.name, c, nil) end
                    -- the per-player overrides are exceptions TO the class
                    -- rows, so clearing the rows without them would leave
                    -- invisible leftovers pointing at buffs nobody assigned
                    A.ClearPlayerBuffs(entry.name)
                end
            end
        end
        Msg(grp and "Group buff assignments cleared."
                or "Per-class buff assignments and player overrides cleared.")
    elseif DUTY_TAB[currentTab] then
        for _, def in ipairs(DutyList(DUTY_TAB[currentTab])) do
            local holders = A.GetDutyCasters(def.key)
            for i = 1, table.getn(holders) do
                if A.CanEdit(Me(), holders[i].caster) then
                    A.ClearDuty(holders[i].caster, def.key)
                end
            end
        end
        Msg("Assignments on this tab cleared.")
    elseif currentTab == 5 then
        -- clear the view you're looking at, not both: the two rotations are
        -- separate plans and wiping the hidden one would be invisible damage
        local r = RotView()
        for k in pairs(r.ready) do r.ready[k] = nil end
        if A.ClearRotation(r.kind) then
            Msg(r.title .. " rotation and timers cleared.")
        else
            Msg(r.title .. " timers reset (only a leader can clear the rotation).")
        end
    elseif currentTab == 6 then
        A.ClearTankSlots()
        for _, name in ipairs(AllMembers()) do
            if A.GetRole(name) then A.SetRole(name, nil) end
        end
        Msg("Raid roles cleared.")
    elseif currentTab == 7 then
        for m = 1, (A.MaxMarks and A.MaxMarks()) or 8 do
            local holders = A.GetCCForMark(m)
            for i = 1, table.getn(holders) do
                if A.CanEdit(Me(), holders[i].caster) then
                    A.SetCC(holders[i].caster, m, nil)
                end
            end
        end
        -- the pending picks are panel state, not a plan, but leaving them
        -- would make a cleared tab still look half-filled
        for m in pairs(CC.pick) do CC.pick[m] = nil end
        Msg("Crowd-control assignments cleared.")
    end
    RefreshCurrent()
end

-- One entry per tab, in a table rather than as more file-scope locals.
-- CreatePanel sits near the Lua 5.0 32-upvalue ceiling (hard rule 9) and every
-- file-scope local it reaches costs one: seven builders as seven locals cost
-- seven, as one table they cost one. That is what made room for a seventh tab.
-- Tab 3 has two views, so entries are lists; the tab index is passed through
-- for the duty tab, which is shared and needs to know which one it is.
local TAB_BUILD = {
    { BuildBlessings },
    { BuildTotems },
    { BuildBuffGrid, BuildGroupGrid },
    { BuildDutyTab },
    { BuildRotTab },
    { BuildRoles },
    { CC.Build },
}

local function CreatePanel()
    local f = CreateFrame("Frame", "AegisRP_AssignFrame", UIParent)
    frame = f
    f:SetWidth(FRAME_W); f:SetHeight(FRAME_H)
    f:SetScale(AegisRP_Settings.assignScale or 1)   -- before the SetPoint
    local pos = AegisRP_Settings.assignPos
    if pos then f:SetPoint(pos.p, UIParent, pos.rel or pos.p, pos.x, pos.y)
    else f:SetPoint("CENTER", UIParent, "CENTER", 0, 30) end
    f:SetBackdrop(PANEL_BD)
    f:SetBackdropColor(0.055, 0.05, 0.04, 0.96)
    f:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
    f:SetFrameStrata("DIALOG")
    if f.SetToplevel then f:SetToplevel(true) end      -- click brings it forward
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() f:StartMoving() end)
    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        -- keep the relative point: grip-scaling re-anchors TOPLEFT->BOTTOMLEFT
        local p, _, rp, x, y = f:GetPoint()
        AegisRP_Settings.assignPos = { p = p, rel = rp, x = x, y = y }
        -- options follows: dragging this aside is also how you make room for
        -- it on a screen too narrow to fit both side by side
        if AegisRP.DockPanels then AegisRP.DockPanels() end
    end)
    f:Hide()
    tinsert(UISpecialFrames, "AegisRP_AssignFrame")   -- ESC closes

    -- header: eyebrow + title (concept), close button, status pills
    local eyebrow = Fnt(f, 9, GOLD_DIM)
    eyebrow:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -12)
    eyebrow:SetText("AEGIS: RALLYPOWER  \194\183  ASSIGNMENTS")
    local h1 = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    h1:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -24)
    h1:SetTextColor(GOLD_BRIGHT[1], GOLD_BRIGHT[2], GOLD_BRIGHT[3])
    h1:SetText("Who Covers What")

    CreateFrame("Button", nil, f, "UIPanelCloseButton"):SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

    -- pills right-to-left: sync, free assign, leader, test
    pills.sync = MakePill(f, 72)
    pills.sync:SetPoint("TOPRIGHT", f, "TOPRIGHT", -34, -26)
    pills.sync.text:SetText("|cff5b8fff\226\151\143|r SYNC")
    pills.sync:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:SetText("Sync", 1, 1, 1)
        GameTooltip:AddLine("Blessings sync over PLPWR (stock-PallyPower compatible).", 0.6, 1, 0.6, 1)
        GameTooltip:AddLine("Totems, duties and raid buffs sync over RPCX to other", 0.6, 1, 0.6, 1)
        GameTooltip:AddLine("Aegis: RallyPower users. /rpc sync forces a refresh.", 0.6, 1, 0.6, 1)
        GameTooltip:Show()
    end)
    pills.sync:SetScript("OnLeave", function() GameTooltip:Hide() end)

    pills.free = MakePill(f, 108)
    pills.free:SetPoint("RIGHT", pills.sync, "LEFT", -4, 0)
    pills.free:SetScript("OnClick", function()
        -- leader-only flip; A.SetFreeAssign gates and syncs it to the raid
        if not A.SetFreeAssign(not A.GetFreeAssign()) then
            Msg("Only the raid leader / assist can change Free Assignment.")
            return
        end
        UpdatePills()
    end)
    pills.free:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:SetText("Free Assignment", 1, 1, 1)
        GameTooltip:AddLine("When ON, ANY member may edit ANY row - the leader lets people "
            .. "spread the assignments out themselves.", 0.8, 0.8, 0.8, 1)
        GameTooltip:AddLine("Leader-controlled and synced to the whole raid.", 0.6, 1, 0.6, 1)
        if A.IAmLead() then
            GameTooltip:AddLine("Click to toggle.", 0.6, 0.6, 0.6)
        else
            GameTooltip:AddLine("Only the leader can change this.", 0.7, 0.5, 0.5)
        end
        GameTooltip:Show()
    end)
    pills.free:SetScript("OnLeave", function() GameTooltip:Hide() end)

    pills.leader = MakePill(f, 88)
    pills.leader:SetPoint("RIGHT", pills.free, "LEFT", -4, 0)

    pills.test = MakePill(f, 78)
    pills.test:SetPoint("RIGHT", pills.leader, "LEFT", -4, 0)
    pills.test.text:SetText("|cffff8800\226\151\143|r TEST RAID")
    pills.test:Hide()

    -- Tab row: the buttons DIVIDE the width rather than each taking a fixed
    -- 120. Six at 120 already filled 744 of the frame's 760, so a seventh tab
    -- ran off the edge; deriving the width means adding one narrows them all
    -- instead of breaking the row.
    local nTabs = table.getn(TAB_INFO)
    local tabW = math.floor((FRAME_W - 28 - (nTabs - 1) * 2) / nTabs)
    for i = 1, nTabs do
        local idx = i
        local b = CreateFrame("Button", nil, f)
        b:SetWidth(tabW); b:SetHeight(26)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", 14 + (i - 1) * (tabW + 2), -50)
        b:SetBackdrop(CELL_BD)
        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("CENTER", b, "CENTER", 0, 0)
        local dot = TAB_INFO[i].live and "|cff5be07a\226\151\143|r " or "|cffd8b98a\226\151\143|r "
        fs:SetText(dot .. TAB_INFO[i].label)
        b.label = fs
        b:SetScript("OnClick", function() ShowTab(idx) end)
        tabBtns[i] = b
    end

    -- content box
    -- tabs sit flush on the box top edge (concept: attached tabs)
    local box = CreateFrame("Frame", nil, f)
    box:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -75)
    box:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 62)
    box:SetBackdrop(PANEL_BD)
    box:SetBackdropColor(0.08, 0.072, 0.058, 0.9)
    box:SetBackdropBorderColor(0.23, 0.20, 0.15, 1)

    -- content panels + per-tab chrome (title, desc, note, hint, coverage)
    local CHROME = {
        { "Blessings", "Each paladin's blessing per class, plus their aura and seal - the live PallyPower grid." },
        { "Totems", "Which totem each shaman drops per element, and which group they cover." },
        { "Raid buff coverage", "Which buff each priest, mage and druid gives every class - their strips follow their rows." },
        { "Target debuff duty", "Who maintains each debuff on the kill target." },
        { "Rotations", "Who interrupts and who taunts, in what order, and whose is off cooldown." },
        { "Raid roles", "Main Tank + off-tanks (dropdowns), healers, and each tank's own blessing." },
        { "Crowd control", "Which mark each sheep, sap, banish, shackle or trap goes on." },
    }
    for i = 1, table.getn(TAB_INFO) do
        local p = CreateFrame("Frame", nil, box)
        p:SetPoint("TOPLEFT", box, "TOPLEFT", 10, -8)
        p:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -10, 6)
        p:Hide()
        local t = Fnt(p, 15, GOLD_BRIGHT)
        t:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
        t:SetText(CHROME[i][1])
        local d = Fnt(p, 10, INK_DIM)
        d:SetWidth(520); d:SetHeight(11)
        d:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -21)
        d:SetText(CHROME[i][2])
        p.note = Fnt(p, 11, GOLD, "RIGHT")
        p.note:SetWidth(130); p.note:SetHeight(12)
        p.note:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -4)
        p.hint = Fnt(p, 9, INK_FAINT)
        p.hint:SetWidth(708); p.hint:SetHeight(22)
        p.hint:SetJustifyV("BOTTOM")
        p.hint:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 0, 14)
        p.cover = Fnt(p, 10, INK_DIM)
        p.cover:SetWidth(708); p.cover:SetHeight(11)
        p.cover:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 0, 1)
        panels[i] = p
    end
    for i = 1, table.getn(TAB_BUILD) do
        local list = TAB_BUILD[i]
        for j = 1, table.getn(list) do list[j](panels[i], i) end
    end

    -- bottom buttons: the classic PallyPower frame's row, on our panel
    local function BottomButton(name, label, onclick)
        local b = CreateFrame("Button", name, f, "GameMenuButtonTemplate")
        b:SetWidth(100); b:SetHeight(21)
        b:SetText(label)
        b:SetScript("OnClick", onclick)
        return b
    end
    local bRefresh = BottomButton("AegisRP_AssignBtnRefresh", "Refresh", function()
        -- universal refresh: PallyPower's blessing report request (paladins
        -- resend blessings/symbols) AND our RPCX re-request (everyone resends
        -- totems/duties/raid buffs), so the whole plan reconciles on demand
        if PallyPower_Refresh then pcall(PallyPower_Refresh) end
        if AegisRP_SyncNow then pcall(AegisRP_SyncNow) end
        RefreshCurrent()
    end)
    bRefresh:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 10)
    local bClear = BottomButton("AegisRP_AssignBtnClear", "Clear", ClearCurrentTab)
    bClear:SetPoint("RIGHT", bRefresh, "LEFT", -4, 0)
    local bOptions = BottomButton("AegisRP_AssignBtnOptions", "Options", function()
        if AegisRP_OptionsToggle then AegisRP_OptionsToggle() end
    end)
    bOptions:SetPoint("RIGHT", bClear, "LEFT", -4, 0)
    local bReset = BottomButton("AegisRP_AssignBtnReset", "Reset Position", function()
        AegisRP_Settings.assignPos = nil
        AegisRP_Settings.assignScale = nil
        f:SetScale(1)
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    end)
    bReset:SetPoint("RIGHT", bOptions, "LEFT", -4, 0)

    -- scale grip, bottom-right (the PallyPower resize corner); scaling
    -- re-anchors the frame, so persist the new position with the scale
    AegisRP.AddScaleGrip(f, "assignScale", function()
        AegisRP_Settings.assignPos = { p = "TOPLEFT", rel = "BOTTOMLEFT",
            x = f:GetLeft(), y = f:GetTop() }
        -- a rescale changes how much room is left beside it, so the side the
        -- options frame docks on can change too
        if AegisRP.DockPanels then AegisRP.DockPanels() end
    end)
    -- blessing presets are a paladin feature (same dropdown as the classic frame)
    local _, mycls = UnitClass("player")
    if mycls == "PALADIN" and PallyPowerMinimapPresetsDropDown then
        local bPresets = BottomButton("AegisRP_AssignBtnPresets", "Presets", function()
            PallyPowerMinimapPresetsDropDown.point = "TOPRIGHT"
            PallyPowerMinimapPresetsDropDown.relativePoint = "BOTTOMLEFT"
            ToggleDropDownMenu(1, nil, PallyPowerMinimapPresetsDropDown,
                "AegisRP_AssignBtnPresets", 0, 0)
        end)
        bPresets:SetPoint("RIGHT", bReset, "LEFT", -4, 0)
    end

    f:SetScript("OnShow", function()
        -- opening this while the options frame is up re-docks options beside
        -- it rather than leaving one window on top of the other
        if AegisRP.DockPanels then AegisRP.DockPanels() end
        if AegisRP.RaisePanel then
            AegisRP.RaisePanel(f, getglobal("AegisRP_OptionsFrame"))
        end
        ShowTab(AegisRP_Settings.assignLastTab or 1)
    end)

    -- slow repaint while open: rosters, legacy PLPWR traffic and remote
    -- assignment edits all land without any event of ours
    local accum = 0
    f:SetScript("OnUpdate", function()
        accum = accum + (arg1 or 0)
        if accum < 1 then return end
        accum = 0
        RefreshCurrent()
    end)

    -- repaint immediately when the model changes under us
    A.Subscribe(function() RefreshCurrent() end)
end

-- Entry points: strip title right-click, paladin buff bar right-click,
-- /rpc assign.
function AegisRP_AssignPanelToggle()
    if not frame then CreatePanel() end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

--------------------------------------------------------------------------
-- legacy grafts (PallyPower.lua/.xml stay untouched - we replace globals
-- and re-script XML buttons at load, exactly like the pop-out does)
--------------------------------------------------------------------------

-- Right-clicking the paladin buff bar opens OUR panel; a left-click keeps
-- the classic assignment frame (still reachable, aura/seal columns included).
if PallyPowerBuffBar_MouseUp then
    local origMouseUp = PallyPowerBuffBar_MouseUp
    PallyPowerBuffBar_MouseUp = function()
        local wasShown = PallyPowerFrame and PallyPowerFrame:IsVisible()
        origMouseUp()
        if arg1 == "RightButton" and PallyPowerFrame
           and PallyPowerFrame:IsVisible() and not wasShown then
            PallyPowerFrame:Hide()
            AegisRP_AssignPanelToggle()
        end
    end
end

-- The classic frame's Options button opens OUR tabbed options panel (the
-- classic options frame stays reachable via /rpc legacy).
if PallyPowerFrameOptions then
    PallyPowerFrameOptions:SetScript("OnClick", function()
        if AegisRP_OptionsToggle then
            AegisRP_OptionsToggle()
        elseif PallyPower_Options then
            PallyPower_Options()
        end
    end)
end
