--=============================================================================
-- Class_Druid.lua  -  Druid module for AegisRP
--
-- A class-buff strip (like Priest/Mage): one button per raid class showing the
-- buff assigned to that class. Wheel cycles Mark of the Wild <-> Thorns for
-- that class; left-click casts the group version, right-click tops off the next
-- member, hover opens the player pop-out. The engine (Core) drives coverage,
-- casting and the strip; the module only supplies the buff data.
--=============================================================================

local M = AegisRP:NewClass("DRUID")

M.buffs = {
    { name = "Mark of the Wild", group = "Gift of the Wild",
      icons = { "Spell_Nature_Regeneration" }, pet = true,
      dur = 30*60, gdur = 60*60 },
    { name = "Thorns",
      icons = { "Spell_Nature_Thorns" },
      dur = 10*60 },
}

-- Debuff durations are Vanilla defaults and Turtle-UNVERIFIED - check on-realm
-- and edit here if they differ. Faerie Fire has two spells: the caster one and
-- the Feral talent version usable in forms. They apply the SAME debuff and
-- share an icon, so tracking covers both either way; both are listed so a
-- feral gets a button they can actually press while shifted, and KNOWN gating
-- means an untalented druid never sees the Feral one.
local FAERIE_DUR = 40
local ROAR_DUR   = 30

M.debuffs = {
    { name = "Faerie Fire", dur = FAERIE_DUR,
      icon = "Spell_Nature_FaerieFire" },
    { name = "Faerie Fire (Feral)", dur = FAERIE_DUR,
      icon = "Spell_Nature_FaerieFire" },
    { name = "Demoralizing Roar", dur = ROAR_DUR,
      icon = "Ability_Druid_DemoralizingRoar" },
}

function M:OnActivate()
    AegisRP.BuildClassBuffs()
end

function M:Toggle()
    AegisRP.BuildClassBuffs():Toggle()
end

-- Assignment model: Druid duties. Wids are stable.
if AegisRP.Assign then
    local D = AegisRP.Assign.RegisterDuty
    D{ key="MARK",      wid=5,  class="DRUID", tab="raidbuff", spell="Mark of the Wild", target="none",   multi=false, dur=30*60, icon="Interface\\Icons\\Spell_Nature_Regeneration" }
    D{ key="THORNS",    wid=6,  class="DRUID", tab="raidbuff", spell="Thorns",           target="none",   multi=false, dur=10*60, icon="Interface\\Icons\\Spell_Nature_Thorns" }
    D{ key="INNERVATE", wid=20, class="DRUID", tab="utility",  spell="Innervate",        target="player", multi=true,  dur=0, icon="Interface\\Icons\\Spell_Nature_Lightning" }
    -- One duty per EFFECT, not per spell: the raid plan cares that Faerie Fire
    -- is up, not which of the two spells put it there.
    D{ key="FAERIEFIRE", wid=26, class="DRUID", tab="debuff",   spell="Faerie Fire",       target="none", multi=false, dur=FAERIE_DUR, icon="Interface\\Icons\\Spell_Nature_FaerieFire" }
    D{ key="DEMOROAR",   wid=27, class="DRUID", tab="debuff",   spell="Demoralizing Roar", target="none", multi=false, dur=ROAR_DUR, icon="Interface\\Icons\\Ability_Druid_DemoralizingRoar" }
end
