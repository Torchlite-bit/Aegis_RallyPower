--=============================================================================
-- Aegis_BagScan.lua  -  coalesce PallyPower's per-BAG_UPDATE inventory scan
--
-- THE STALL. Opening a mailbox runs the stock MAIL_SHOW handler, which calls
-- OpenBackpack(). On the FIRST open of mail carrying attachments the client
-- has never cached, it re-fires BAG_UPDATE many times in a single frame while
-- each item resolves. PallyPower answers every one of those synchronously with
-- a full bags-0-to-4 walk (PallyPower.lua:576 -> PallyPower_ScanInventory),
-- so N events cost N x ~80 GetContainerItemLink calls in one frame. On a
-- patched client against a custom server, where an uncached lookup is far more
-- expensive than a local hit, that is the multi-second freeze - and it happens
-- only once per session because the second open finds a warm cache.
--
-- RallyPower has no mailbox code; it is simply on the far end of BAG_UPDATE.
--
-- THE FIX. While BAG_UPDATE is being dispatched, the scan only raises a dirty
-- flag; the real scan runs at most ONCE per frame from the OnUpdate below.
-- Calls from anywhere else (init at PallyPower.lua:1740, /pp refresh at :3069)
-- stay synchronous, because those consume PP_Symbols on the next line.
--
-- UNCACHED SLOTS. On 1.12 an item that has not resolved yet gives a texture
-- from GetContainerItemInfo but nil from GetContainerItemLink. We never spin
-- waiting on it: the resolve fires its own BAG_UPDATE, so nil just means "not
-- yet, try next event". We use that only to hold the scan back briefly, so a
-- half-populated bag cannot broadcast a wrong SYMCOUNT to the raid - with a
-- time cap so a permanently-unresolvable slot can't wedge the scan forever.
--
-- Wraps rather than edits: PallyPower/ stays byte-identical to stock.
-- Lua 5.0 / 1.12 only: implicit `event`/`arg1` globals, table.getn, no #/%.
--=============================================================================

AegisRP = AegisRP or { classes = {}, active = nil }

local HOLD_CAP = 5      -- seconds we'll wait on unresolved items before scanning anyway

local pending    = false   -- a BAG_UPDATE arrived; a scan is owed
local heldFor    = 0       -- seconds we've been holding for unresolved items
local flushes    = 0       -- diagnostics: real scans run
local coalesced  = 0       -- diagnostics: BAG_UPDATE scans folded away

-- Is every occupied slot's item actually resolved? Returns false on the FIRST
-- unresolved slot, so this is cheapest exactly when the storm is loudest.
local function BagsResolved()
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        if slots then
            for slot = 1, slots do
                local tex = GetContainerItemInfo(bag, slot)
                -- occupied (texture present) but no link yet = still resolving
                if tex and not GetContainerItemLink(bag, slot) then
                    return false
                end
            end
        end
    end
    return true
end

-- Exposed for the off-client test and for /rpc bagscan.
AegisRP.BagScan = {
    Stats   = function() return flushes, coalesced, pending end,
    Reset   = function() pending = false; heldFor = 0; flushes = 0; coalesced = 0 end,
    -- One frame's worth of flushing. `elapsed` is the frame delta.
    Tick    = function(elapsed)
        if not pending then return false end
        if not BagsResolved() then
            heldFor = heldFor + (elapsed or 0)
            if heldFor < HOLD_CAP then return false end
            -- cap reached: scan anyway rather than never. A partial count
            -- self-corrects on the next BAG_UPDATE.
        end
        pending = false
        heldFor = 0
        flushes = flushes + 1
        if AegisRP.BagScan._real then AegisRP.BagScan._real() end
        return true
    end,
}

-- Install the wrapper. Guarded so a load order that hasn't run PallyPower yet
-- simply leaves the engine alone rather than erroring.
if PallyPower_ScanInventory then
    AegisRP.BagScan._real = PallyPower_ScanInventory

    PallyPower_ScanInventory = function()
        -- `event` is the 1.12 dispatch global, set while a handler runs. Only
        -- the BAG_UPDATE storm path defers; every other caller is immediate.
        if event == "BAG_UPDATE" then
            pending = true
            coalesced = coalesced + 1
            return
        end
        if AegisRP.BagScan._real then AegisRP.BagScan._real() end
    end

    local f = CreateFrame("Frame", "AegisRP_BagScanFlush")
    f:SetScript("OnUpdate", function()
        AegisRP.BagScan.Tick(arg1 or 0)
    end)
end
