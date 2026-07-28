--=============================================================================
-- Aegis_CastWatch.lua  -  shared SuperWoW cast observation
--
-- ONE UNIT_CASTEVENT handler for the whole addon. SuperWoW fires it for every
-- cast it can see and hands us the caster, the target and the spell id:
--
--     arg1 = caster GUID   arg2 = target GUID   arg3 = event   arg4 = spell id
--
-- Validated in-game on Turtle 1.18.1: UnitName() resolves a GUID, SpellInfo()
-- resolves the id to a name, and `event` is "CAST" for a completed cast (also
-- "START" for one that has begun, "MAINHAND"/"OFFHAND" for melee swings, which
-- we drop as noise). This is the foundation the cast-exact shared timers stand
-- on - it is the only way a 1.12 client can learn what SOMEONE ELSE just cast.
--
-- Consumers subscribe rather than each registering their own frame:
--
--     AegisRP.CastWatch.Subscribe(function(caster, target, spell, id, evt)
--         ...
--     end)
--
-- caster/target are player NAMES (target falls back to the caster on a self
-- cast); spell is the resolved spell name, or nil when the id doesn't resolve.
-- Watchers are pcall-isolated, so one erroring consumer can't blind the others.
--
-- Without SuperWoW the module still loads and Subscribe() still works - it just
-- never fires, so every consumer degrades to its own-casts-only behaviour.
--
-- `/rpc castdbg` toggles raw logging of everything seen here (verbose).
-- 1.12 rules: implicit arg1..argN, Lua 5.0 (table.getn, no #/select/%).
--=============================================================================

AegisRP_Settings = AegisRP_Settings or {}
-- Match Aegis_Core's initializer exactly, so this file is safe to load either
-- side of it if the TOC is ever reordered.
AegisRP = AegisRP or { classes = {}, active = nil }

local HAS_SUPERWOW = (SUPERWOW_VERSION ~= nil)

local watchers = {}
local CW = {}
AegisRP.CastWatch = CW

-- Is real cast observation available? (Consumers use this to word their
-- tooltips honestly: "observed" vs "assumed ready".)
function CW.Available()
    return HAS_SUPERWOW
end

function CW.Subscribe(fn)
    if type(fn) == "function" then table.insert(watchers, fn) end
end

--------------------------------------------------------------------------
-- spell id -> name, memoised (SpellInfo is a SuperWoW addition; guard it).
-- A miss caches `false` so a bad id isn't re-pcall'd on every swing.
--------------------------------------------------------------------------

local nameCache = {}

local function SpellNameFromId(id)
    if not id then return nil end
    local hit = nameCache[id]
    if hit ~= nil then
        if hit == false then return nil end
        return hit
    end
    if not SpellInfo then return nil end
    local ok, nm = pcall(SpellInfo, id)
    if not ok then nm = nil end
    nameCache[id] = nm or false
    return nm
end
CW.SpellName = SpellNameFromId

--------------------------------------------------------------------------
-- dispatch
--------------------------------------------------------------------------

local function Dispatch(casterGUID, targetGUID, evt, spellID)
    local caster = UnitName(casterGUID)          -- SuperWoW accepts a GUID
    if not caster then return end
    local target = targetGUID and UnitName(targetGUID)
    if not target then target = caster end       -- self cast (or no target)
    local spell = SpellNameFromId(spellID)

    if AegisRP_Settings._castDbg then
        DEFAULT_CHAT_FRAME:AddMessage("|cff88ccffcastdbg:|r name=" .. caster
            .. " tgt=" .. target .. " evt=" .. tostring(evt)
            .. " sid=" .. tostring(spellID) .. " spell=" .. tostring(spell))
    end

    for i = 1, table.getn(watchers) do
        local ok, err = pcall(watchers[i], caster, target, spell, spellID, evt)
        if not ok then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff5555Aegis error:|r "
                .. tostring(err) .. " |cffaaaaaa(cast watcher)|r")
        end
    end
end

if HAS_SUPERWOW then
    local f = CreateFrame("Frame")
    f:RegisterEvent("UNIT_CASTEVENT")
    f:SetScript("OnEvent", function()
        -- melee swings fire constantly and carry no spell we track
        if arg3 == "MAINHAND" or arg3 == "OFFHAND" then return end
        local ok, err = pcall(Dispatch, arg1, arg2, arg3, arg4)
        if not ok then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff5555Aegis error:|r "
                .. tostring(err) .. " |cffaaaaaa(cast watch)|r")
        end
    end)
end
