local _, RA = ...

RA.Categories = {
    { key = "RAID_DEFENSIVE", name = "Raid Defensives", shortName = "Defense", compactLabel = "DEF", order = 10 },
    { key = "RAID_HEALING", name = "Raid Healing", shortName = "Healing", compactLabel = "HEAL", order = 20 },
    { key = "MOVEMENT", name = "Movement", shortName = "Movement", compactLabel = "MOVE", order = 30 },
    { key = "EXTERNALS", name = "Externals", shortName = "Externals", compactLabel = "EXT", order = 40 },
    { key = "MANA", name = "Mana Tools", shortName = "Mana", compactLabel = "MANA", order = 50 },
    { key = "UTILITY", name = "Utility", shortName = "Utility", compactLabel = "UTIL", order = 60 },
    { key = "RECOVERY", name = "Recovery", shortName = "Recovery", compactLabel = "REZ", order = 70 },
}

-- Current Midnight 12.1 raid-lead catalog. The list is intentionally narrower
-- than a historical cooldown database: it prioritizes abilities a raid leader
-- is likely to call, while keeping modern optional/niche tools available behind
-- explicit filters. A remote ability is shown only when its spell is present in
-- Blizzard's inspected build data or is one of the very small guaranteed base
-- class abilities below.
--
-- tier: CORE, OPTIONAL, NICHE
-- defaultEnabled controls the recommended initial content set.
RA.Catalog = {
    -- RAID DEFENSIVES
    { key = "spirit_link", name = "Spirit Link Totem", callout = "SPIRIT LINK", spellID = 98008, cooldown = 180, knownSpellIDs = {98008}, category = "RAID_DEFENSIVE", class = "SHAMAN", specs = { [264] = true }, tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "power_word_barrier", name = "Power Word: Barrier", callout = "BARRIER", spellID = 62618, cooldown = 180, knownSpellIDs = {62618}, category = "RAID_DEFENSIVE", class = "PRIEST", specs = { [256] = true }, choiceGroup = "DISC_MAJOR", choicePriority = 1, tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "aura_mastery", name = "Aura Mastery", callout = "AURA MASTERY", spellID = 31821, cooldown = 180, knownSpellIDs = {31821}, category = "RAID_DEFENSIVE", class = "PALADIN", specs = { [65] = true }, tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "rallying_cry", name = "Rallying Cry", callout = "RALLY", spellID = 97462, cooldown = 180, knownSpellIDs = {97462}, category = "RAID_DEFENSIVE", class = "WARRIOR", tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "anti_magic_zone", name = "Anti-Magic Zone", callout = "AMZ", spellID = 51052, cooldown = 120, knownSpellIDs = {51052}, category = "RAID_DEFENSIVE", class = "DEATHKNIGHT", tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "darkness", name = "Darkness", callout = "DARKNESS", spellID = 196718, cooldown = 180, knownSpellIDs = {196718}, category = "RAID_DEFENSIVE", class = "DEMONHUNTER", tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "zephyr", name = "Zephyr", callout = "ZEPHYR", spellID = 374227, cooldown = 120, knownSpellIDs = {374227}, category = "RAID_DEFENSIVE", class = "EVOKER", tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "ancestral_protection", name = "Ancestral Protection Totem", callout = "ANCESTRAL PROTECTION", spellID = 207399, cooldown = 240, knownSpellIDs = {207399}, category = "RAID_DEFENSIVE", class = "SHAMAN", tier = "NICHE", defaultEnabled = false, activeSupport = "PLANNED_AURA" },
    { key = "earthen_wall", name = "Earthen Wall Totem", callout = "EARTHEN WALL", spellID = 198838, cooldown = 60, knownSpellIDs = {198838}, category = "RAID_DEFENSIVE", class = "SHAMAN", tier = "NICHE", defaultEnabled = false, activeSupport = "PLANNED_AURA" },

    -- RAID HEALING / MAJOR THROUGHPUT
    { key = "evangelism", name = "Evangelism", callout = "EVANGELISM", spellID = 472433, cooldown = 90, knownSpellIDs = {472433, 246287}, category = "RAID_HEALING", class = "PRIEST", specs = { [256] = true }, tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "ultimate_penitence", name = "Ultimate Penitence", callout = "ULTIMATE PENITENCE", spellID = 421453, cooldown = 240, knownSpellIDs = {421453}, category = "RAID_HEALING", class = "PRIEST", specs = { [256] = true }, choiceGroup = "DISC_MAJOR", choicePriority = 2, tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_CAST" },
    { key = "divine_hymn", name = "Divine Hymn", callout = "HYMN", spellID = 64843, cooldown = 180, knownSpellIDs = {64843}, category = "RAID_HEALING", class = "PRIEST", specs = { [257] = true }, tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_CAST" },
    { key = "apotheosis", name = "Apotheosis", callout = "APOTHEOSIS", spellID = 200183, cooldown = 120, knownSpellIDs = {200183}, category = "RAID_HEALING", class = "PRIEST", specs = { [257] = true }, tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "avenging_wrath", name = "Avenging Wrath", callout = "WINGS", spellID = 31884, cooldown = 120, knownSpellIDs = {31884, 384376, 384442}, category = "RAID_HEALING", class = "PALADIN", specs = { [65] = true }, choiceGroup = "HOLY_WINGS", choicePriority = 1, tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "avenging_crusader", name = "Avenging Crusader", callout = "AVENGING CRUSADER", spellID = 216331, cooldown = 120, knownSpellIDs = {216331}, category = "RAID_HEALING", class = "PALADIN", specs = { [65] = true }, choiceGroup = "HOLY_WINGS", choicePriority = 2, tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "celestial_conduit", name = "Celestial Conduit", callout = "CELESTIAL CONDUIT", spellID = 443028, cooldown = 90, knownSpellIDs = {443028}, category = "RAID_HEALING", class = "MONK", specs = { [270] = true }, tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_CAST" },
    { key = "revival", name = "Revival", callout = "REVIVAL", spellID = 115310, cooldown = 180, knownSpellIDs = {115310}, category = "RAID_HEALING", class = "MONK", specs = { [270] = true }, choiceGroup = "MISTWEAVER_REVIVAL", choicePriority = 1, tier = "CORE", defaultEnabled = true, activeSupport = "STATIC_ONLY" },
    { key = "restoral", name = "Restoral", callout = "RESTORAL", spellID = 388615, cooldown = 180, knownSpellIDs = {388615}, category = "RAID_HEALING", class = "MONK", specs = { [270] = true }, choiceGroup = "MISTWEAVER_REVIVAL", choicePriority = 2, tier = "CORE", defaultEnabled = true, activeSupport = "STATIC_ONLY" },
    { key = "invoke_yulon", name = "Invoke Yu'lon", callout = "YU'LON", spellID = 322118, cooldown = 180, knownSpellIDs = {322118}, category = "RAID_HEALING", class = "MONK", specs = { [270] = true }, choiceGroup = "MISTWEAVER_CELESTIAL", choicePriority = 1, tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "invoke_chiji", name = "Invoke Chi-Ji", callout = "CHI-JI", spellID = 325197, cooldown = 180, knownSpellIDs = {325197}, category = "RAID_HEALING", class = "MONK", specs = { [270] = true }, choiceGroup = "MISTWEAVER_CELESTIAL", choicePriority = 2, tier = "OPTIONAL", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "rewind", name = "Rewind", callout = "REWIND", spellID = 363534, cooldown = 240, knownSpellIDs = {363534}, category = "RAID_HEALING", class = "EVOKER", specs = { [1468] = true }, tier = "CORE", defaultEnabled = true, activeSupport = "STATIC_ONLY" },
    { key = "stasis", name = "Stasis", callout = "STASIS", spellID = 370537, cooldown = 90, knownSpellIDs = {370537, 370564}, category = "RAID_HEALING", class = "EVOKER", specs = { [1468] = true }, tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "dream_flight", name = "Dream Flight", callout = "DREAM FLIGHT", spellID = 359816, cooldown = 120, knownSpellIDs = {359816}, category = "RAID_HEALING", class = "EVOKER", specs = { [1468] = true }, tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_CAST" },
    { key = "tip_the_scales", name = "Tip the Scales", callout = "TIP THE SCALES", spellID = 370553, cooldown = 120, knownSpellIDs = {370553}, category = "RAID_HEALING", class = "EVOKER", specs = { [1468] = true }, tier = "OPTIONAL", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "tranquility", name = "Tranquility", callout = "TRANQUILITY", spellID = 740, cooldown = 180, knownSpellIDs = {740}, category = "RAID_HEALING", class = "DRUID", specs = { [105] = true }, tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_CAST" },
    { key = "incarnation_tree", name = "Incarnation: Tree of Life", callout = "TREE", spellID = 33891, cooldown = 180, knownSpellIDs = {33891}, category = "RAID_HEALING", class = "DRUID", specs = { [105] = true }, tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "convoke_spirits", name = "Convoke the Spirits", callout = "CONVOKE", spellID = 391528, cooldown = 120, knownSpellIDs = {391528, 323764}, category = "RAID_HEALING", class = "DRUID", specs = { [105] = true }, tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_CAST" },
    { key = "resto_ascendance", name = "Ascendance", callout = "ASCENDANCE", spellID = 114052, cooldown = 180, knownSpellIDs = {114052}, category = "RAID_HEALING", class = "SHAMAN", specs = { [264] = true }, tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "healing_tide", name = "Healing Tide Totem", callout = "HEALING TIDE", spellID = 108280, cooldown = 180, knownSpellIDs = {108280}, category = "RAID_HEALING", class = "SHAMAN", specs = { [264] = true }, tier = "NICHE", defaultEnabled = false, activeSupport = "PLANNED_AURA" },
    { key = "flourish", name = "Flourish", callout = "FLOURISH", spellID = 197721, cooldown = 90, knownSpellIDs = {197721}, category = "RAID_HEALING", class = "DRUID", specs = { [105] = true }, tier = "NICHE", defaultEnabled = false, activeSupport = "PLANNED_AURA" },
    { key = "emerald_communion", name = "Emerald Communion", callout = "EMERALD COMMUNION", spellID = 370960, cooldown = 180, knownSpellIDs = {370960}, category = "RAID_HEALING", class = "EVOKER", specs = { [1468] = true }, tier = "NICHE", defaultEnabled = false, activeSupport = "PLANNED_CAST" },
    { key = "vampiric_embrace", name = "Vampiric Embrace", callout = "VAMPIRIC EMBRACE", spellID = 15286, cooldown = 120, knownSpellIDs = {15286}, category = "RAID_HEALING", class = "PRIEST", specs = { [258] = true }, tier = "NICHE", defaultEnabled = false, activeSupport = "PLANNED_AURA" },

    -- MOVEMENT
    { key = "wind_rush", name = "Wind Rush Totem", callout = "WIND RUSH", spellID = 192077, cooldown = 120, knownSpellIDs = {192077}, category = "MOVEMENT", class = "SHAMAN", tier = "CORE", defaultEnabled = true, activeSupport = "STATIC_ONLY" },
    { key = "stampeding_roar", name = "Stampeding Roar", callout = "ROAR", spellID = 77761, cooldown = 120, knownSpellIDs = {77761, 106898, 77764}, category = "MOVEMENT", class = "DRUID", tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "time_spiral", name = "Time Spiral", callout = "TIME SPIRAL", spellID = 374968, cooldown = 120, knownSpellIDs = {374968}, category = "MOVEMENT", class = "EVOKER", tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "spatial_paradox", name = "Spatial Paradox", callout = "SPATIAL PARADOX", spellID = 406732, cooldown = 60, knownSpellIDs = {406732, 406789, 407497}, category = "MOVEMENT", class = "EVOKER", tier = "OPTIONAL", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "demonic_gateway", name = "Demonic Gateway", callout = "GATEWAY", spellID = 111771, cooldown = 90, knownSpellIDs = {111771}, category = "MOVEMENT", class = "WARLOCK", guaranteedClasses = { WARLOCK = true }, tier = "CORE", defaultEnabled = true, activeSupport = "STATIC_ONLY" },
    { key = "rescue", name = "Rescue", callout = "RESCUE", spellID = 370665, cooldown = 60, knownSpellIDs = {370665}, category = "MOVEMENT", class = "EVOKER", tier = "OPTIONAL", defaultEnabled = false, activeSupport = "STATIC_ONLY" },

    -- EXTERNALS
    { key = "pain_suppression", name = "Pain Suppression", callout = "PAIN SUPPRESSION", spellID = 33206, cooldown = 180, knownSpellIDs = {33206}, category = "EXTERNALS", class = "PRIEST", specs = { [256] = true }, tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "guardian_spirit", name = "Guardian Spirit", callout = "GUARDIAN SPIRIT", spellID = 47788, cooldown = 180, knownSpellIDs = {47788}, category = "EXTERNALS", class = "PRIEST", specs = { [257] = true }, tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "ironbark", name = "Ironbark", callout = "IRONBARK", spellID = 102342, cooldown = 60, knownSpellIDs = {102342}, category = "EXTERNALS", class = "DRUID", specs = { [105] = true }, tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "life_cocoon", name = "Life Cocoon", callout = "LIFE COCOON", spellID = 116849, cooldown = 120, knownSpellIDs = {116849}, category = "EXTERNALS", class = "MONK", specs = { [270] = true }, tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "blessing_sacrifice", name = "Blessing of Sacrifice", callout = "SACRIFICE", spellID = 6940, cooldown = 120, knownSpellIDs = {6940}, category = "EXTERNALS", class = "PALADIN", tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "time_dilation", name = "Time Dilation", callout = "TIME DILATION", spellID = 357170, cooldown = 60, knownSpellIDs = {357170}, category = "EXTERNALS", class = "EVOKER", specs = { [1468] = true }, tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "blessing_protection", name = "Blessing of Protection", callout = "BOP", spellID = 1022, cooldown = 300, knownSpellIDs = {1022}, category = "EXTERNALS", class = "PALADIN", choiceGroup = "PALADIN_PROTECTION_BLESSING", choicePriority = 1, tier = "OPTIONAL", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "blessing_spellwarding", name = "Blessing of Spellwarding", callout = "SPELLWARDING", spellID = 204018, cooldown = 180, knownSpellIDs = {204018}, category = "EXTERNALS", class = "PALADIN", choiceGroup = "PALADIN_PROTECTION_BLESSING", choicePriority = 2, tier = "OPTIONAL", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "intervene", name = "Intervene", callout = "INTERVENE", spellID = 3411, cooldown = 30, knownSpellIDs = {3411}, category = "EXTERNALS", class = "WARRIOR", tier = "OPTIONAL", defaultEnabled = false, activeSupport = "PLANNED_AURA" },
    { key = "lay_on_hands", name = "Lay on Hands", callout = "LAY ON HANDS", spellID = 633, cooldown = 600, knownSpellIDs = {633}, category = "EXTERNALS", class = "PALADIN", guaranteedClasses = { PALADIN = true }, tier = "OPTIONAL", defaultEnabled = false, activeSupport = "STATIC_ONLY" },

    -- MANA
    { key = "innervate", name = "Innervate", callout = "INNERVATE", spellID = 29166, cooldown = 180, knownSpellIDs = {29166}, category = "MANA", class = "DRUID", tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "mana_tide", name = "Mana Tide Totem", callout = "MANA TIDE", spellID = 16191, cooldown = 180, knownSpellIDs = {16191}, category = "MANA", class = "SHAMAN", specs = { [264] = true }, tier = "CORE", defaultEnabled = true, activeSupport = "PLANNED_AURA" },
    { key = "symbol_of_hope", name = "Symbol of Hope", callout = "SYMBOL OF HOPE", spellID = 64901, cooldown = 180, knownSpellIDs = {64901}, category = "MANA", class = "PRIEST", specs = { [257] = true }, tier = "OPTIONAL", defaultEnabled = true, activeSupport = "PLANNED_CAST" },

    -- UTILITY
    { key = "mass_dispel", name = "Mass Dispel", callout = "MASS DISPEL", spellID = 32375, cooldown = 120, knownSpellIDs = {32375}, category = "UTILITY", class = "PRIEST", tier = "CORE", defaultEnabled = true, activeSupport = "STATIC_ONLY" },
    { key = "tremor_totem", name = "Tremor Totem", callout = "TREMOR", spellID = 8143, cooldown = 60, knownSpellIDs = {8143}, category = "UTILITY", class = "SHAMAN", tier = "CORE", defaultEnabled = true, activeSupport = "STATIC_ONLY" },
    { key = "poison_cleansing", name = "Poison Cleansing Totem", callout = "POISON CLEANSING", spellID = 383013, cooldown = 45, knownSpellIDs = {383013}, category = "UTILITY", class = "SHAMAN", tier = "OPTIONAL", defaultEnabled = true, activeSupport = "STATIC_ONLY" },
    { key = "ring_of_peace", name = "Ring of Peace", callout = "RING OF PEACE", spellID = 116844, cooldown = 45, knownSpellIDs = {116844}, category = "UTILITY", class = "MONK", tier = "OPTIONAL", defaultEnabled = true, activeSupport = "STATIC_ONLY" },
    { key = "gorefiends_grasp", name = "Gorefiend's Grasp", callout = "GOREFIEND'S", spellID = 108199, cooldown = 120, knownSpellIDs = {108199}, category = "UTILITY", class = "DEATHKNIGHT", tier = "OPTIONAL", defaultEnabled = true, activeSupport = "STATIC_ONLY" },
    { key = "ursols_vortex", name = "Ursol's Vortex", callout = "VORTEX", spellID = 102793, cooldown = 60, knownSpellIDs = {102793}, category = "UTILITY", class = "DRUID", tier = "OPTIONAL", defaultEnabled = true, activeSupport = "STATIC_ONLY" },
    { key = "sigil_of_chains", name = "Sigil of Chains", callout = "SIGIL OF CHAINS", spellID = 202138, cooldown = 60, knownSpellIDs = {202138}, category = "UTILITY", class = "DEMONHUNTER", tier = "OPTIONAL", defaultEnabled = true, activeSupport = "STATIC_ONLY" },
    { key = "mass_entanglement", name = "Mass Entanglement", callout = "MASS ROOT", spellID = 102359, cooldown = 30, knownSpellIDs = {102359}, category = "UTILITY", class = "DRUID", tier = "NICHE", defaultEnabled = false, activeSupport = "STATIC_ONLY" },
    { key = "capacitor_totem", name = "Capacitor Totem", callout = "CAPACITOR", spellID = 192058, cooldown = 60, knownSpellIDs = {192058}, category = "UTILITY", class = "SHAMAN", tier = "OPTIONAL", defaultEnabled = false, activeSupport = "STATIC_ONLY" },
    { key = "blinding_light", name = "Blinding Light", callout = "BLINDING LIGHT", spellID = 115750, cooldown = 90, knownSpellIDs = {115750}, category = "UTILITY", class = "PALADIN", tier = "NICHE", defaultEnabled = false, activeSupport = "STATIC_ONLY" },
    { key = "shroud", name = "Shroud of Concealment", callout = "SHROUD", spellID = 114018, cooldown = 300, knownSpellIDs = {114018}, category = "UTILITY", class = "ROGUE", guaranteedClasses = { ROGUE = true }, tier = "OPTIONAL", defaultEnabled = false, activeSupport = "STATIC_ONLY" },
    { key = "leap_of_faith", name = "Leap of Faith", callout = "GRIP", spellID = 73325, cooldown = 90, knownSpellIDs = {73325}, category = "UTILITY", class = "PRIEST", guaranteedClasses = { PRIEST = true }, tier = "OPTIONAL", defaultEnabled = false, activeSupport = "STATIC_ONLY" },

    -- RECOVERY
    { key = "combat_resurrection", name = "Combat Resurrection", callout = "BATTLE REZ", spellID = 20484, cooldown = 600, knownSpellIDs = {20484, 61999, 20707, 391054}, category = "RECOVERY", class = nil, guaranteedClasses = { DRUID = true, DEATHKNIGHT = true, WARLOCK = true }, tier = "CORE", defaultEnabled = true, activeSupport = "STATIC_ONLY" },
}

RA.CatalogByKey = {}
RA.CatalogByIndex = {}
RA.CategoryByKey = {}

for i = 1, #RA.Categories do
    RA.CategoryByKey[RA.Categories[i].key] = RA.Categories[i]
end

for i = 1, #RA.Catalog do
    local ability = RA.Catalog[i]
    ability.index = i
    ability.tier = ability.tier or "OPTIONAL"
    if ability.defaultEnabled == nil then
        ability.defaultEnabled = ability.tier ~= "NICHE"
    end
    RA.CatalogByKey[ability.key] = ability
    RA.CatalogByIndex[i] = ability
end


local TIER_PRIORITY = {
    CORE = 1,
    OPTIONAL = 2,
    NICHE = 3,
}

local function DefaultAbilitySort(a, b)
    local aTier = TIER_PRIORITY[a.tier] or 9
    local bTier = TIER_PRIORITY[b.tier] or 9
    if aTier ~= bTier then
        return aTier < bTier
    end

    local aCooldown = tonumber(a.cooldown) or 0
    local bCooldown = tonumber(b.cooldown) or 0
    if aCooldown ~= bCooldown then
        return aCooldown > bCooldown
    end

    return (a.name or a.key) < (b.name or b.key)
end

function RA:GetDefaultOrderedAbilities(categoryKey)
    local result = {}
    for i = 1, #self.Catalog do
        local ability = self.Catalog[i]
        if ability.category == categoryKey then
            result[#result + 1] = ability
        end
    end
    table.sort(result, DefaultAbilitySort)
    return result
end

function RA:EnsureAbilityOrder(categoryKey)
    local db = self:GetDB()
    if not db then
        return
    end
    db.abilityOrder = db.abilityOrder or {}

    local function EnsureCategory(key)
        local existing = db.abilityOrder[key]
        if type(existing) ~= "table" then
            existing = {}
        end

        local valid = {}
        local output = {}
        for i = 1, #existing do
            local abilityKey = existing[i]
            local ability = self.CatalogByKey[abilityKey]
            if ability and ability.category == key and not valid[abilityKey] then
                valid[abilityKey] = true
                output[#output + 1] = abilityKey
            end
        end

        local defaults = self:GetDefaultOrderedAbilities(key)
        for i = 1, #defaults do
            local abilityKey = defaults[i].key
            if not valid[abilityKey] then
                valid[abilityKey] = true
                output[#output + 1] = abilityKey
            end
        end
        db.abilityOrder[key] = output
    end

    if categoryKey then
        EnsureCategory(categoryKey)
    else
        for i = 1, #self.Categories do
            EnsureCategory(self.Categories[i].key)
        end
    end
end

function RA:GetOrderedAbilities(categoryKey)
    self:EnsureAbilityOrder(categoryKey)
    local db = self:GetDB()
    local result = {}
    local order = db and db.abilityOrder and db.abilityOrder[categoryKey] or nil
    if type(order) == "table" then
        for i = 1, #order do
            local ability = self.CatalogByKey[order[i]]
            if ability and ability.category == categoryKey then
                result[#result + 1] = ability
            end
        end
    end
    return result
end

function RA:MoveAbility(categoryKey, abilityKey, direction)
    local db = self:GetDB()
    if not db then
        return false
    end
    self:EnsureAbilityOrder(categoryKey)
    local order = db.abilityOrder[categoryKey]
    local current
    for i = 1, #order do
        if order[i] == abilityKey then
            current = i
            break
        end
    end
    if not current then
        return false
    end

    local target = current + (direction < 0 and -1 or 1)
    if target < 1 or target > #order then
        return false
    end
    order[current], order[target] = order[target], order[current]
    self:RefreshHUD()
    self:FireCallback("ABILITY_ORDER_CHANGED", categoryKey)
    return true
end

function RA:ResetAbilityOrder(categoryKey)
    local db = self:GetDB()
    if not db then
        return
    end
    db.abilityOrder = db.abilityOrder or {}
    if categoryKey then
        db.abilityOrder[categoryKey] = nil
        self:EnsureAbilityOrder(categoryKey)
    else
        wipe(db.abilityOrder)
        self:EnsureAbilityOrder()
    end
    self:RefreshHUD()
    self:FireCallback("ABILITY_ORDER_CHANGED", categoryKey)
end

function RA:GetCooldownLabel(ability)
    local seconds = tonumber(ability and ability.cooldown) or 0
    if seconds <= 0 then
        return ""
    elseif seconds % 60 == 0 then
        return tostring(seconds / 60) .. "m"
    end
    return tostring(seconds) .. "s"
end

local function PlayerKnowsSpell(spellID)
    if C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook then
        return C_SpellBook.IsSpellKnownOrInSpellBook(spellID)
    elseif _G.IsPlayerSpell then
        return _G.IsPlayerSpell(spellID)
    elseif _G.IsSpellKnown then
        return _G.IsSpellKnown(spellID)
    end
    return false
end

function RA:GetAbilityName(ability)
    if C_Spell and C_Spell.GetSpellName then
        local name = C_Spell.GetSpellName(ability.spellID)
        if name and name ~= "" then
            return name
        end
    end
    return ability.name
end

function RA:GetAbilityCallout(ability)
    return ability.callout or string.upper(self:GetAbilityName(ability))
end

function RA:GetAbilityTexture(ability)
    if C_Spell and C_Spell.GetSpellTexture then
        local texture = C_Spell.GetSpellTexture(ability.spellID)
        if texture then
            return texture
        end
    end
    return 134400
end

function RA:IsAbilityKnown(ability)
    for i = 1, #ability.knownSpellIDs do
        if PlayerKnowsSpell(ability.knownSpellIDs[i]) then
            return true
        end
    end
    return false
end

function RA:IsAbilityGuaranteedFor(ability, classFile, specID)
    if ability.guaranteedClasses and ability.guaranteedClasses[classFile] then
        return true
    end
    if ability.guaranteedSpecs and ability.guaranteedSpecs[specID] then
        return true
    end
    return false
end

function RA:IsAbilityApplicableToSpec(ability, specID)
    if not ability.specs then
        return true
    end
    return type(specID) == "number" and ability.specs[specID] == true
end

function RA:BuildCapabilitiesFromSpellSet(classFile, specID, selectedSpellSet, baselineSpellSet)
    local capabilities = {}
    local evidence = {}
    selectedSpellSet = type(selectedSpellSet) == "table" and selectedSpellSet or {}
    baselineSpellSet = type(baselineSpellSet) == "table" and baselineSpellSet or {}

    local candidates = {}
    local selectedChoiceGroups = {}

    local function Matches(ability, spellSet)
        for j = 1, #ability.knownSpellIDs do
            if spellSet[ability.knownSpellIDs[j]] then
                return true
            end
        end
        return false
    end

    for i = 1, #self.Catalog do
        local ability = self.Catalog[i]
        if (not ability.class or ability.class == classFile) and self:IsAbilityApplicableToSpec(ability, specID) then
            local evidenceType
            if Matches(ability, selectedSpellSet) then
                evidenceType = "SELECTED_TALENT"
            elseif not ability.choiceGroup and Matches(ability, baselineSpellSet) then
                evidenceType = "BASELINE_SPEC"
            elseif self:IsAbilityGuaranteedFor(ability, classFile, specID) then
                evidenceType = "GUARANTEED_CLASS"
            end

            if evidenceType then
                candidates[#candidates + 1] = { ability = ability, evidence = evidenceType }
                if ability.choiceGroup and evidenceType == "SELECTED_TALENT" then
                    local current = selectedChoiceGroups[ability.choiceGroup]
                    if not current or (ability.choicePriority or 99) > (current.choicePriority or 99) then
                        selectedChoiceGroups[ability.choiceGroup] = ability
                    end
                end
            end
        end
    end

    for i = 1, #candidates do
        local candidate = candidates[i]
        local ability = candidate.ability
        local include = true
        if ability.choiceGroup then
            include = selectedChoiceGroups[ability.choiceGroup] == ability
        end
        if include then
            capabilities[#capabilities + 1] = ability.index
            evidence[ability.index] = candidate.evidence
        end
    end

    return capabilities, evidence
end

function RA:ScanLocalCapabilities(specID)
    local capabilities = {}
    local _, playerClass = UnitClass("player")
    local selectedByChoice = {}
    local matches = {}

    for i = 1, #self.Catalog do
        local ability = self.Catalog[i]
        if (not ability.class or ability.class == playerClass) and self:IsAbilityApplicableToSpec(ability, specID) then
            if self:IsAbilityKnown(ability) then
                matches[#matches + 1] = ability
                if ability.choiceGroup then
                    local current = selectedByChoice[ability.choiceGroup]
                    if not current or (ability.choicePriority or 99) > (current.choicePriority or 99) then
                        selectedByChoice[ability.choiceGroup] = ability
                    end
                end
            end
        end
    end

    -- Spell replacements can leave both the base and override spell appearing
    -- known. Prefer the active override when Blizzard exposes it.
    if C_SpellBook and C_SpellBook.FindSpellOverrideByID then
        for i = 1, #matches do
            local ability = matches[i]
            if ability.choiceGroup then
                local ok, overrideID = pcall(C_SpellBook.FindSpellOverrideByID, ability.spellID)
                if ok and type(overrideID) == "number" and overrideID ~= ability.spellID then
                    for j = 1, #matches do
                        local other = matches[j]
                        if other.choiceGroup == ability.choiceGroup then
                            for k = 1, #other.knownSpellIDs do
                                if other.knownSpellIDs[k] == overrideID then
                                    selectedByChoice[ability.choiceGroup] = other
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    for i = 1, #matches do
        local ability = matches[i]
        if not ability.choiceGroup or selectedByChoice[ability.choiceGroup] == ability then
            capabilities[#capabilities + 1] = ability.index
        end
    end

    return capabilities
end

function RA:IsCategoryEnabled(categoryKey)
    local db = self:GetDB()
    return db and db.categories[categoryKey] ~= false
end

function RA:IsAbilityEnabled(ability)
    local db = self:GetDB()
    if not db or not self:IsCategoryEnabled(ability.category) then
        return false
    end

    local explicit = db.abilities[ability.key]
    if explicit ~= nil then
        return explicit
    end
    return ability.defaultEnabled ~= false
end

function RA:ResetAbilityVisibilityToRecommended(categoryKey)
    local db = self:GetDB()
    if not db then
        return
    end

    for i = 1, #self.Catalog do
        local ability = self.Catalog[i]
        if not categoryKey or ability.category == categoryKey then
            db.abilities[ability.key] = nil
        end
    end
    self:OnCapabilityFiltersChanged()
end

-- Returns whether this class could contribute at least one ability currently
-- enabled in the HUD. Classes with no enabled tools are resolved without an
-- inspect request, which keeps the initial pass fast.
function RA:ClassNeedsCapabilityInspection(classFile)
    if not classFile then
        return true
    end

    for i = 1, #self.Catalog do
        local ability = self.Catalog[i]
        if self:IsAbilityEnabled(ability) then
            if ability.class == classFile then
                return true
            end

            if not ability.class and ability.guaranteedClasses and ability.guaranteedClasses[classFile] then
                return true
            end
        end
    end

    return false
end

function RA:OnCapabilityFiltersChanged()
    self:RefreshHUD()

    if self.StopInspectionScan then
        self:StopInspectionScan()
    end

    if self.ScheduleInspectionScan and not self.InEncounter and not InCombatLockdown() then
        self:ScheduleInspectionScan("capability filters changed", 0.10, false)
    end
end


RA:RegisterInitializer(function()
    RA:EnsureAbilityOrder()
end)
