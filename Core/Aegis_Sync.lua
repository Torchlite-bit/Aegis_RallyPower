--=============================================================================
-- Aegis_Sync.lua  -  the RPCX sync protocol (Assignment & Sync step 2)
--
-- Broadcasts the totem / duty / raid-buff-grid assignments the model stores
-- (AegisRP_Assign) to the raid, receives and stores others', and gates
-- edits by permission. BLESSINGS ARE UNTOUCHED - they keep riding the legacy
-- PLPWR channel through the engine's own SELF/ASSIGN/AASSIGN/... messages;
-- RPCX carries only what PallyPower never knew about.
--
-- Grammar (docs\DESIGN_SYNC.md): space-delimited head, ";"-delimited payload
--   <v> REQ
--   <v> BLK <caster> <seq> <payload>
--         payload = cTOKEN;t<wids>;d<entries>;b<class.buff>;g<group.buff>
--                   ;p<player.buff>
--         "g" and "p" are additive: a client skips tags it does not know, so
--         they reach new clients without desyncing old ones (no PROTO bump)
--   <v> CLR <caster>
--   <v> FA  <0|1>                          raid-wide Free Assignment flag (leader)
--   <v> TS  <mt> <ot1> <ot2>               tank-slot order, "-" = empty (leader)
--   <v> KO  <name> <name> ...              kick rotation order, "-" = empty (leader)
--   <v> TO  <name> <name> ...              taunt rotation order, "-" = empty (leader)
--   <v> KICK <seconds>                     my interrupt just went on cooldown
--   <v> TNT  <seconds>                     my taunt just went on cooldown
--   <v> CHUNK <caster> <seq> <i> <n> <payload>   one slice of an oversized BLK
-- Wids never cross the wire as spell names (Turtle-rename safe); unknown wids
-- are skipped, not errored (forward-compat). Permission mirrors PallyPower:
-- accept a block for CASTER from SENDER iff sender==caster or sender is
-- lead/assist. Conflicts resolve arrival-order last-writer-wins, exactly as
-- PallyPower resolves two people editing one blessing.
--
-- 1.12 rules: implicit event/arg1..arg4, OnUpdate accumulator, Lua 5.0
-- (table.getn/concat, string.gfind not gmatch, no #/select/%).
--=============================================================================

local A = AegisRP.Assign
if not A then return end        -- Assign.lua loads first; defensive

local PREFIX      = "RPCX"
local PROTO_V     = 1
local FLUSH_DELAY = 0.5         -- debounce a burst of edits into one send
local REQ_THROTTLE = 3         -- min seconds between our own REQ storms
local MAX_LEN     = 250         -- addon-message payload ceiling
local CHUNK_SIZE  = 240         -- max payload per chunk (leave room for header)
local CHUNK_EXPIRE = 30         -- seconds before reassembly buffer expires
local CD_THROTTLE = 1           -- min seconds between our own KICK/TNT broadcasts

local applyingRemote = false    -- true while installing a received block
local dirty = {}                -- set of caster names pending broadcast
local freeDirty = false         -- Free Assignment flag changed, pending send
local tsDirty = false           -- tank-slot order changed, pending send
local koDirty = false           -- kick rotation changed, pending send
local toDirty = false           -- taunt rotation changed, pending send
local flushAccum = 0
local lastReq = -100
local lastCdSent = { KICK = -100, TNT = -100 }   -- last self-cooldown broadcast
local chunks = {}               -- reassembly buffer: [caster][seq] = { chunks, expire_time }

-- Wire telemetry for /rpc slots. Verifying sync used to need two clients side
-- by side and a guess about whether anything crossed the wire at all; these let
-- ONE client's output show whether it is sending, receiving, and from whom.
local stat = { tsSent = nil, tsRecv = nil, tsFrom = nil, rx = 0, rxFrom = nil }
function AegisRP_SyncStats() return stat end

--------------------------------------------------------------------------
-- helpers + lazy catalog reverse maps (catalogs register at class-module
-- load, which is before this file, but building lazily is robust either way)
--------------------------------------------------------------------------

local function Me() return UnitName("player") end

local function ClassOf(name)
    if name == Me() then local _, c = UnitClass("player"); return c end
    local n = GetNumRaidMembers()
    if n > 0 then
        for i = 1, n do
            if UnitName("raid" .. i) == name then local _, c = UnitClass("raid" .. i); return c end
        end
        return nil
    end
    for i = 1, GetNumPartyMembers() do
        if UnitName("party" .. i) == name then local _, c = UnitClass("party" .. i); return c end
    end
    return nil
end

local totemByWid, dutyByWid
local function BuildMaps()
    totemByWid = {}
    for element, list in pairs(A.totems or {}) do
        for i = 1, table.getn(list) do
            local t = list[i]
            if t.wid then totemByWid[t.wid] = { element = element, name = t.name } end
        end
    end
    dutyByWid = {}
    for key, def in pairs(A.duties or {}) do
        if def.wid then dutyByWid[def.wid] = def end
    end
end

local function TotemByWid() if not totemByWid then BuildMaps() end return totemByWid end
local function DutyByWid()  if not dutyByWid  then BuildMaps() end return dutyByWid  end

local function TotemWid(element, name)
    local list = A.totems and A.totems[element]
    if not list then return nil end
    for i = 1, table.getn(list) do
        if list[i].name == name then return list[i].wid end
    end
    return nil
end

local function BuffCatalog(token)
    local m = AegisRP.classes and AegisRP.classes[token]
    return (m and m.buffs) or {}
end

-- buff index into a class catalog, matched on name-or-group (the same value
-- the class-buff domain stores)
local function BuffIndex(cat, value)
    for i = 1, table.getn(cat) do
        if (cat[i].name == value) or (cat[i].group == value) then return i end
    end
    return nil
end

--------------------------------------------------------------------------
-- permission (PallyPower-faithful): who may assert a block for a caster
--------------------------------------------------------------------------

local function LeaderLike(name)
    return PallyPower_CheckRaidLeader and PallyPower_CheckRaidLeader(name)
end

local function CanAccept(sender, caster)
    if sender == caster then return true end
    -- a leader may set anyone's block; Free Assignment opens it to everyone
    return (LeaderLike(sender) and true or false) or A.GetFreeAssign()
end

-- may I broadcast this caster's block? (my own always; others' if I lead -
-- A.IAmLead is party-leader-safe, unlike PallyPower_CheckRaidLeader(Me),
-- which never matches the player's own party leadership). Preview-raid rows
-- never hit the wire.
local function MayAssert(caster)
    if AegisRP.PreviewNames and AegisRP.PreviewNames[caster] then return false end
    return caster == Me() or A.IAmLead()
end

--------------------------------------------------------------------------
-- serialize / deserialize one caster block
--------------------------------------------------------------------------

local function SerializeBlock(name)
    local c = A.GetCaster(name)
    if not c then return nil end
    local token = c.class or ClassOf(name)
    local parts = {}
    if token then table.insert(parts, "c" .. token) end

    if c.totem then
        local wids = {}
        for element, tname in pairs(c.totem) do
            if element ~= "party" and tname then
                local wid = TotemWid(element, tname)
                if wid then table.insert(wids, wid) end
            end
        end
        if table.getn(wids) > 0 then table.insert(parts, "t" .. table.concat(wids, ",")) end
    end

    if c.duty then
        local ents = {}
        for key, val in pairs(c.duty) do
            local def = A.duties and A.duties[key]
            if def and def.wid and val then
                local e = tostring(def.wid)
                if type(val) == "string" then e = e .. "=" .. val end  -- name or @ROLE
                table.insert(ents, e)
            end
        end
        if table.getn(ents) > 0 then table.insert(parts, "d" .. table.concat(ents, ",")) end
    end

    if c.cbuff and token then
        local cat = BuffCatalog(token)
        local ents = {}
        for classID, value in pairs(c.cbuff) do
            local idx = BuffIndex(cat, value)
            if idx then table.insert(ents, classID .. "." .. idx) end
        end
        if table.getn(ents) > 0 then table.insert(parts, "b" .. table.concat(ents, ",")) end
    end

    -- group buffs: <group>.<buffIndex> pairs, same shape as the "b" section.
    -- A group can carry several buffs, so it simply appears several times
    -- (g2.1,2.3,5.1 = group 2 gets buffs 1 and 3, group 5 gets buff 1).
    if c.gbuff and token then
        local cat = BuffCatalog(token)
        local ents = {}
        local maxg = (A.MaxGroups and A.MaxGroups()) or 8
        for g = 1, maxg do
            local set = c.gbuff[g]
            if set then
                -- walk the CATALOG, not the set, so ordering is deterministic
                for i = 1, table.getn(cat) do
                    local nm = cat[i].name or cat[i].group
                    if nm and set[nm] then table.insert(ents, g .. "." .. i) end
                end
            end
        end
        if table.getn(ents) > 0 then table.insert(parts, "g" .. table.concat(ents, ",")) end
    end

    -- per-player overrides: <name>.<buffIndex> pairs. The name has to ride the
    -- wire literally - unlike a class or a group there is no small integer to
    -- send - which is safe because the separators here (";" "," "." and space)
    -- cannot occur in a WoW character name.
    if c.pbuff and token then
        local cat = BuffCatalog(token)
        local names = {}
        for who, value in pairs(c.pbuff) do
            if value then table.insert(names, who) end
        end
        table.sort(names)                       -- pairs() is unordered; the wire isn't
        local ents = {}
        for i = 1, table.getn(names) do
            local idx = BuffIndex(cat, c.pbuff[names[i]])
            if idx then table.insert(ents, names[i] .. "." .. idx) end
        end
        if table.getn(ents) > 0 then table.insert(parts, "p" .. table.concat(ents, ",")) end
    end

    return table.concat(parts, ";")
end

local function DeserializeBlock(caster, seq, payload)
    local block = { seq = tonumber(seq) or 0 }
    local rawB, rawG, rawP = nil, nil, nil
    for section in string.gfind(payload or "", "[^;]+") do
        local tag = string.sub(section, 1, 1)
        local data = string.sub(section, 2)
        if tag == "c" then
            block.class = data
        elseif tag == "t" then
            block.totem = block.totem or {}
            for widS in string.gfind(data, "[^,]+") do
                local info = TotemByWid()[tonumber(widS)]
                if info then block.totem[info.element] = info.name end
            end
        elseif tag == "d" then
            block.duty = block.duty or {}
            for ent in string.gfind(data, "[^,]+") do
                local _, _, widS, tgt = string.find(ent, "^(%d+)=?(.*)$")
                local def = widS and DutyByWid()[tonumber(widS)]
                if def then
                    if tgt == nil or tgt == "" then block.duty[def.key] = true
                    else block.duty[def.key] = tgt end
                end
            end
        elseif tag == "b" then
            rawB = data                       -- resolved after class is known
        elseif tag == "g" then
            rawG = data                       -- ditto: needs the caster's catalog
        elseif tag == "p" then
            rawP = data                       -- ditto
        end
    end
    local token = block.class or ClassOf(caster)
    block.class = token
    if rawB and token then
        local cat = BuffCatalog(token)
        block.cbuff = {}
        for ent in string.gfind(rawB, "[^,]+") do
            local _, _, cidS, idxS = string.find(ent, "^(%d+)%.(%d+)$")
            local cid = tonumber(cidS)
            local bd = cat and idxS and cat[tonumber(idxS)]
            if cid ~= nil and bd then block.cbuff[cid] = bd.name or bd.group end
        end
    end
    if rawG and token then
        local cat = BuffCatalog(token)
        block.gbuff = {}
        for ent in string.gfind(rawG, "[^,]+") do
            local _, _, gS, idxS = string.find(ent, "^(%d+)%.(%d+)$")
            local g = tonumber(gS)
            local bd = cat and idxS and cat[tonumber(idxS)]
            if g and bd then
                block.gbuff[g] = block.gbuff[g] or {}
                block.gbuff[g][bd.name or bd.group] = true
            end
        end
    end
    if rawP and token then
        local cat = BuffCatalog(token)
        block.pbuff = {}
        for ent in string.gfind(rawP, "[^,]+") do
            -- greedy name capture would swallow nothing here: a name has no
            -- dot, so "Bob.2" splits exactly once
            local _, _, nm, idxS = string.find(ent, "^([^.]+)%.(%d+)$")
            local bd = cat and idxS and cat[tonumber(idxS)]
            if nm and bd then block.pbuff[nm] = bd.name or bd.group end
        end
    end
    return block
end

--------------------------------------------------------------------------
-- message chunking for large assignment blocks

local function SplitPayload(payload)
    if string.len(payload) <= CHUNK_SIZE then
        return nil  -- single message, no chunking needed
    end
    local chunks = {}
    local pos = 1
    while pos <= string.len(payload) do
        table.insert(chunks, string.sub(payload, pos, pos + CHUNK_SIZE - 1))
        pos = pos + CHUNK_SIZE
    end
    return chunks
end

local function AssembleChunk(caster, seq, chunkId, totalChunks, payload)
    if not chunks[caster] then chunks[caster] = {} end
    if not chunks[caster][seq] then
        chunks[caster][seq] = { chunks = {}, expire = GetTime() + CHUNK_EXPIRE }
    end
    local assembler = chunks[caster][seq]
    assembler.chunks[chunkId] = payload
    assembler.total = totalChunks
    if table.getn(assembler.chunks) == totalChunks then
        local full = ""
        for i = 1, totalChunks do
            if assembler.chunks[i] then full = full .. assembler.chunks[i]
            else return nil end
        end
        chunks[caster][seq] = nil
        return full
    end
    return nil
end

local function ExpireOldChunks()
    local now = GetTime()
    for caster in pairs(chunks) do
        for seq in pairs(chunks[caster]) do
            if chunks[caster][seq].expire < now then
                chunks[caster][seq] = nil
            end
        end
    end
end

--------------------------------------------------------------------------
-- send
--------------------------------------------------------------------------

local function RawSend(msg)
    -- test mode is a local sandbox: never broadcast (preview edits, and even
    -- real ones, stay off the wire so a tester can't pollute a live raid)
    if AegisRP.IsTestMode and AegisRP.IsTestMode() then return end
    if GetNumRaidMembers() > 0 then
        SendAddonMessage(PREFIX, msg, "RAID", Me())
    elseif GetNumPartyMembers() > 0 then
        SendAddonMessage(PREFIX, msg, "PARTY", Me())
    end
    -- solo: nothing to send
end

local function SendBlock(name)
    local payload = SerializeBlock(name)
    if not payload or payload == "" then return end
    local c = A.GetCaster(name)
    local seq = (c and c.seq) or 0
    local payloadChunks = SplitPayload(payload)
    if not payloadChunks then
        RawSend(PROTO_V .. " BLK " .. name .. " " .. seq .. " " .. payload)
    else
        for i = 1, table.getn(payloadChunks) do
            RawSend(PROTO_V .. " CHUNK " .. name .. " " .. seq .. " " .. i .. " "
                .. table.getn(payloadChunks) .. " " .. payloadChunks[i])
        end
    end
end

local function SendREQ()
    RawSend(PROTO_V .. " REQ")
end

-- My own rotation cooldown (Kick / Taunt tabs). Self-reported and sent the
-- instant it starts, so there is nothing to batch through the flush - and no
-- leader gate, because you can only ever announce your OWN cooldown. Called by
-- the panel's pollers.
--
-- Rate-limited to one per CD_THROTTLE seconds, per message kind so a warrior
-- who taunts and pummels in the same second still reports both. The pollers
-- only fire on a ready->cooldown edge, so in normal play this is already
-- self-limiting; the floor is insurance against a bugged caller or a
-- shared-cooldown spell flickering the edge, since this is the one path that
-- bypasses the flush. The shortest real cooldown here is 6s (Earth Shock), so
-- a 1s floor drops nothing.
local function SendCooldown(cmd, remaining)
    if not remaining or remaining <= 0 then return end
    local now = GetTime()
    if now - (lastCdSent[cmd] or -100) < CD_THROTTLE then return end
    lastCdSent[cmd] = now
    RawSend(PROTO_V .. " " .. cmd .. " " .. string.format("%.1f", remaining))
end

function AegisRP_SendKick(remaining)  SendCooldown("KICK", remaining) end
function AegisRP_SendTaunt(remaining) SendCooldown("TNT",  remaining) end

--------------------------------------------------------------------------
-- dirty set + debounced flush
--------------------------------------------------------------------------

local function MarkDirty(caster)
    if not caster then return end
    if not MayAssert(caster) then return end
    dirty[caster] = true
end

-- queue every block I'm authoritative for (my own; all, if I lead) - used on
-- login, roster change, and as the reply to a REQ
local function MarkAuthoritativeDirty()
    local iLead = A.IAmLead()
    for name in pairs(AegisRP_Assign.casters) do
        if name == Me() or iLead then dirty[name] = true end
    end
    dirty[Me()] = true          -- always assert myself, even with an empty block skipped later
    -- announce free-assign, tank order and the kick rotation
    if iLead then freeDirty = true; tsDirty = true; koDirty = true; toDirty = true end
end

local function Flush()
    -- Free Assignment: only a leader announces it (a caster block skip below
    -- still lets FA go out on its own)
    if freeDirty and A.IAmLead() then
        RawSend(PROTO_V .. " FA " .. (A.GetFreeAssign() and "1" or "0"))
    end
    freeDirty = false
    -- tank-slot order (leader only; shares the raid's MT/OT plan)
    if tsDirty and A.IAmLead() then
        RawSend(PROTO_V .. " TS " .. table.concat(A.EncodeTankSlots(), " "))
        if not (AegisRP.IsTestMode and AegisRP.IsTestMode()) then stat.tsSent = GetTime() end
    end
    tsDirty = false
    -- rotations (leader only; the raid's interrupt and taunt priority orders)
    if koDirty and A.IAmLead() then
        RawSend(PROTO_V .. " KO " .. table.concat(A.EncodeRotation("kick"), " "))
    end
    koDirty = false
    if toDirty and A.IAmLead() then
        RawSend(PROTO_V .. " TO " .. table.concat(A.EncodeRotation("taunt"), " "))
    end
    toDirty = false
    local any = false
    for name in pairs(dirty) do any = true; break end
    if not any then return end
    local pending = dirty
    dirty = {}
    for name in pairs(pending) do
        if MayAssert(name) then SendBlock(name) end
    end
end

--------------------------------------------------------------------------
-- receive
--------------------------------------------------------------------------

local function Receive(sender, msg)
    if sender == Me() then return end            -- our own echo
    stat.rx = stat.rx + 1                        -- any RPCX traffic at all
    stat.rxFrom = sender
    local tok = {}
    for w in string.gfind(msg, "%S+") do table.insert(tok, w) end
    if tonumber(tok[1]) ~= PROTO_V then return end   -- version we don't speak
    local cmd = tok[2]

    if cmd == "REQ" then
        MarkAuthoritativeDirty()                 -- reply on the next flush tick
        return
    end

    if cmd == "BLK" then
        local caster, seq, payload = tok[3], tok[4], tok[5]
        if not caster then return end
        if not CanAccept(sender, caster) then return end
        local block = DeserializeBlock(caster, seq, payload)
        applyingRemote = true
        A.ApplyRemoteBlock(caster, block)
        applyingRemote = false
        return
    end

    if cmd == "CLR" then
        local caster = tok[3]
        if caster and CanAccept(sender, caster) then
            applyingRemote = true
            A.RemoveRemoteBlock(caster)
            applyingRemote = false
        end
        return
    end

    if cmd == "FA" then
        -- only a leader may set the raid-wide Free Assignment flag
        if LeaderLike(sender) then
            applyingRemote = true
            A.ApplyFreeAssign(tok[3] == "1")
            applyingRemote = false
        end
        return
    end

    if cmd == "TS" then
        -- only a leader may set the shared tank-slot order (tok[3..] = slots)
        if LeaderLike(sender) then
            applyingRemote = true
            A.ApplyTankSlots(A.DecodeTankSlots(tok, 3))
            applyingRemote = false
            stat.tsRecv = GetTime(); stat.tsFrom = sender
        end
        return
    end

    if cmd == "KO" or cmd == "TO" then
        -- only a leader may set a shared rotation (tok[3..] = names)
        if LeaderLike(sender) then
            applyingRemote = true
            A.ApplyRotation((cmd == "KO") and "kick" or "taunt",
                            A.DecodeRotation(tok, 3))
            applyingRemote = false
        end
        return
    end

    if cmd == "KICK" or cmd == "TNT" then
        -- a member reporting their own cooldown; they're always authoritative
        -- for themselves, so no permission check applies
        local cd = tonumber(tok[3])
        if cd and cd > 0 and cd < 600 and AegisRP.NoteRemoteCooldown then
            AegisRP.NoteRemoteCooldown((cmd == "KICK") and "kick" or "taunt",
                                       sender, cd)
        end
        return
    end

    if cmd == "CHUNK" then
        local caster, seq, chunkId, totalChunks = tok[3], tok[4], tonumber(tok[5]) or 0, tonumber(tok[6]) or 0
        local payload = tok[7]
        if not (caster and chunkId > 0 and totalChunks > 0 and payload) then return end
        if not CanAccept(sender, caster) then return end
        local fullPayload = AssembleChunk(caster, seq, chunkId, totalChunks, payload)
        if fullPayload then
            local block = DeserializeBlock(caster, seq, fullPayload)
            applyingRemote = true
            A.ApplyRemoteBlock(caster, block)
            applyingRemote = false
        end
        return
    end
end

--------------------------------------------------------------------------
-- local-edit hook: broadcast the changed caster (guarded against the echo
-- of remote applies, and against the domains that ride PLPWR instead)
--------------------------------------------------------------------------

A.Subscribe(function(domain, caster)
    if applyingRemote then return end
    if domain == "free" then
        freeDirty = true          -- leader flipped Free Assignment; broadcast it
        return
    end
    if domain == "tankslots" then
        tsDirty = true            -- leader shares the MT/OT order (gated in Flush)
        return
    end
    if domain == "kickorder" then
        koDirty = true            -- leader shares the interrupt rotation
        return
    end
    if domain == "tauntorder" then
        toDirty = true            -- leader shares the taunt rotation
        return
    end
    if domain == "totem" or domain == "duty" or domain == "cbuff"
       or domain == "gbuff" or domain == "pbuff" then
        MarkDirty(caster)
    end
end)

--------------------------------------------------------------------------
-- request-on-join / roster maintenance
--------------------------------------------------------------------------

local function RequestSync()
    local now = GetTime()
    if now - lastReq < REQ_THROTTLE then return end
    lastReq = now
    SendREQ()                    -- others reply with their blocks
    MarkAuthoritativeDirty()     -- and I push mine to them
end

local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("RAID_ROSTER_UPDATE")
f:RegisterEvent("PARTY_MEMBERS_CHANGED")
f:SetScript("OnEvent", function()
    if event == "CHAT_MSG_ADDON" then
        if arg1 == PREFIX and (arg3 == "RAID" or arg3 == "PARTY") then
            local ok, err = pcall(Receive, arg4, arg2)
            if not ok then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff5555Aegis error:|r "
                    .. tostring(err) .. " |cffaaaaaa(sync receive)|r")
            end
        end
    else
        -- entering world / roster change: drop leavers, then reconcile
        if A.PruneToRoster then A.PruneToRoster() end
        RequestSync()
    end
end)

f:SetScript("OnUpdate", function()
    flushAccum = flushAccum + (arg1 or 0)
    if flushAccum < FLUSH_DELAY then return end
    flushAccum = 0
    ExpireOldChunks()
    local ok, err = pcall(Flush)
    if not ok then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff5555Aegis error:|r "
            .. tostring(err) .. " |cffaaaaaa(sync flush)|r")
    end
end)

-- Exposed for /rpc sync debugging (force a full re-broadcast + request).
function AegisRP_SyncNow()
    lastReq = -100
    RequestSync()
    DEFAULT_CHAT_FRAME:AddMessage("|cffffff00Aegis:|r assignment sync requested.")
end
