local _, RA = ...
local Supplies = {}
RA.HealingSupplies = Supplies

-- Reviewed baseline 2026-10-19. Item/use-spell families are data, not a
-- universal healing classifier. Unknown potion families stay unknown.
-- Evidence and limits: docs/HEALING_SUPPLIES.md. No third-party code/assets.
Supplies.MAP_REVISION = 2
Supplies.MAP_VERSION = "2026-10-19.2"
Supplies.MAX_SLOTS_PER_BAG = 100
Supplies.MAX_CANDIDATES = 32
local stones = { [224464] = 1, [5512] = 2 }
local potions = {}
-- Facts from AutoPotion 80196daa plus independently verified use-spell records;
-- independently authored ranking/selection, not imported addon logic.
for rank, id in ipairs({271884, 271883, 245918, 241304, 245919, 241305,
    244849, 244839, 244838, 244835, 212944, 211880, 212943, 211879, 212942, 211878}) do potions[id] = rank end
local healingSpells = { [1295247] = true, [1234768] = true, [1238009] = true, [431416] = true }
local otherPotions = { [241300] = true, [241288] = true, [241308] = true }
local otherSpells = { [1236648] = true, [1236994] = true, [1236616] = true }
local function Secret(value) return type(issecretvalue) == "function" and issecretvalue(value) end
local function Integer(value, minimum, maximum)
    if Secret(value) or type(value) ~= "number" or value ~= value or value < minimum or value > maximum or value ~= math.floor(value) then return nil end
    return value
end
local function Kind(id)
    if stones[id] then return "stone", stones[id] end
    if potions[id] then return "potion", potions[id] end
    if otherPotions[id] then return "other" end
    if not C_Item or type(C_Item.GetItemInfoInstant) ~= "function" then return "unknown" end
    local ok, _, _, _, _, _, class, subclass = pcall(C_Item.GetItemInfoInstant, id)
    class, subclass = Integer(class, 0, 100), Integer(subclass, 0, 100)
    if not ok or not class or not subclass then return "unknown", nil, true end
    -- Enum.ItemClass.Consumable = 0, Enum.ItemConsumableSubclass.Potion = 1.
    if class ~= 0 or subclass ~= 1 then return "other" end
    if type(C_Item.IsItemDataCachedByID) ~= "function" or type(C_Item.GetItemSpell) ~= "function" then return "unknown" end
    local cached, ready = pcall(C_Item.IsItemDataCachedByID, id)
    if not cached or Secret(ready) or ready ~= true then return "unknown", nil, true end
    local got, _, spell = pcall(C_Item.GetItemSpell, id)
    spell = Integer(spell, 1, 2147483647)
    if not got or not spell then return "unknown", nil, true end
    if healingSpells[spell] then return "potion", 100 end
    if otherSpells[spell] then return "other" end
    return "unknown"
end

-- One synchronous, bounded bags-only evaluation. No banks, equipment,
-- cooldowns, usability, tooltip parsing, data requests, retries or timers.
-- Presence is independent of stack count/Healthstone charges. Results with
-- unreadable slots never assert absence. Positive evidence remains carried.
function Supplies:Snapshot()
    local result = { mapRevision = self.MAP_REVISION, slots = 0, pending = {}, candidates = {} }
    if type(issecretvalue) ~= "function" or not C_Container
        or type(C_Container.GetContainerNumSlots) ~= "function"
        or type(C_Container.GetContainerItemID) ~= "function"
        or type(C_Container.GetContainerItemInfo) ~= "function" then return result end
    local incomplete, unknownStone, unknownPotion, classification = false, false, false, {}
    local seen = {}
    for bag = 0, 5 do -- Backpack, four equipped bags, reagent bag; never a bank.
        local ok, slots = pcall(C_Container.GetContainerNumSlots, bag)
        slots = Integer(slots, 0, self.MAX_SLOTS_PER_BAG)
        if not ok or not slots then incomplete = true
        else
            for slot = 1, slots do
                result.slots = result.slots + 1
                local got, id = pcall(C_Container.GetContainerItemID, bag, slot)
                if not got or Secret(id) then incomplete = true
                elseif id ~= nil then
                    id = Integer(id, 1, 2147483647)
                    if not id then incomplete = true
                    else
                        local entry = classification[id]
                        if not entry then
                            local kind, rank, pending = Kind(id)
                            entry = { kind = kind, rank = rank, pending = pending }; classification[id] = entry
                        end
                        if entry.kind == "unknown" then
                            unknownPotion = true
                            if entry.pending then result.pending[id] = true end
                        elseif entry.kind == "stone" or entry.kind == "potion" then
                            local infoOK, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
                            info = infoOK and not Secret(info) and type(info) == "table" and info or nil
                            local count = info and Integer(info.stackCount, 1, 100000)
                            if not count then
                                if entry.kind == "stone" then unknownStone = true else unknownPotion = true end
                            else
                                result[entry.kind] = true
                                local rank = entry.kind == "stone" and entry.rank or 1000 + entry.rank
                                if not seen[id] then
                                    seen[id] = true
                                    local icon = Integer(info.iconFileID, 1, 2147483647)
                                    result.candidates[#result.candidates + 1] = { id = id, kind = entry.kind, rank = rank,
                                        icon = icon or (entry.kind == "stone" and "Interface\\Icons\\INV_Stone_04" or "Interface\\Icons\\INV_Potion_51") }
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if result.stone ~= true and not incomplete and not unknownStone then result.stone = false end
    if result.potion ~= true and not incomplete and not unknownPotion then result.potion = false end
    result.partial = incomplete or unknownStone or unknownPotion
    table.sort(result.candidates, function(a, b) return a.rank == b.rank and a.id < b.id or a.rank < b.rank end)
    while #result.candidates > self.MAX_CANDIDATES do
        result.candidatesTruncated = true
        table.remove(result.candidates)
    end
    local chosen = result.candidates[1]
    result.itemID, result.kind, result.icon = chosen and chosen.id, chosen and chosen.kind, chosen and chosen.icon
    return result
end

-- Shared local cache. The explicit raid check still calls Snapshot directly.
-- Optional consumers share one event-invalidated bags evaluation; rendering,
-- health signals and cooldown signals never invalidate or enumerate bags.
local consumers, cache, subscriptions = {}, nil, {}
local cacheGeneration=0
function Supplies:SetConsumer(key, enabled)
    if key ~= "reminder" and key ~= "recap" then return end
    consumers[key] = enabled == true or nil
    local active = consumers.reminder == true or consumers.recap == true
    for _, subscription in ipairs(subscriptions) do subscription:SetEnabled(active) end
    if not active then cache = nil end
end
function Supplies:InvalidateCache()
    cacheGeneration=cacheGeneration+1
    cache = nil
end
function Supplies:GetCached(key)
    if consumers[key] ~= true then return nil end
    if not cache then
        cache = self:Snapshot()
        cache.cacheGeneration=cacheGeneration
        local ok, value = pcall(function() return GetTime() end)
        if ok and not Secret(value) and type(value) == "number" and value == value and value >= 0 and value < math.huge then
            cache.observedAt = value
        end
    end
    return cache
end
if RA.RegisterOptionalEvent then
    for _, event in ipairs({"BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD"}) do
        subscriptions[#subscriptions+1] = RA:RegisterOptionalEvent(event,function() Supplies:InvalidateCache() end)
    end
    subscriptions[#subscriptions+1] = RA:RegisterOptionalEvent("ITEM_DATA_LOAD_RESULT",function(_,id,success)
        id = Integer(id,1,2147483647)
        if id and not Secret(success) and success == true and cache and cache.pending[id] then
            Supplies:InvalidateCache()
            if RA.FireCallback then RA:FireCallback("HEALING_SUPPLIES_ITEM_DATA_READY",id)end
        end
    end)
end
