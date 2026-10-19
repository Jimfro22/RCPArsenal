local _, RA = ...
local Supplies = {}
RA.HealingSupplies = Supplies

-- Reviewed baseline 2026-10-19. Item/use-spell families are data, not a
-- universal healing classifier. Unknown potion families stay unknown.
-- Evidence and limits: docs/HEALING_SUPPLIES.md. No third-party code/assets.
Supplies.MAP_REVISION = 1
Supplies.MAP_VERSION = "2026-10-19.1"
Supplies.MAX_SLOTS_PER_BAG = 100
local stones = { [224464] = 1, [5512] = 2 }
local potions = { [271884] = 1, [271883] = 2, [241304] = 3, [241305] = 4 }
local healingSpells = { [1295247] = true, [1234768] = true }
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
    local result = { mapRevision = self.MAP_REVISION, slots = 0, pending = {} }
    if type(issecretvalue) ~= "function" or not C_Container
        or type(C_Container.GetContainerNumSlots) ~= "function"
        or type(C_Container.GetContainerItemID) ~= "function"
        or type(C_Container.GetContainerItemInfo) ~= "function" then return result end
    local incomplete, unknownStone, unknownPotion, classification = false, false, false, {}
    local chosen, chosenRank
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
                                if not chosenRank or rank < chosenRank then
                                    local icon = Integer(info.iconFileID, 1, 2147483647)
                                    chosen, chosenRank = { id = id, kind = entry.kind,
                                        icon = icon or (entry.kind == "stone" and "Interface\\Icons\\INV_Stone_04" or "Interface\\Icons\\INV_Potion_51") }, rank
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
    result.itemID, result.kind, result.icon = chosen and chosen.id, chosen and chosen.kind, chosen and chosen.icon
    return result
end
