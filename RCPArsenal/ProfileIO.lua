local _, RA = ...

local PREFIX = "RCPA11:"
local LEGACY_PREFIXES = { "RCPA9:", "RA8:" }

local function PercentEncode(value)
    return (tostring(value or ""):gsub("([^%w%-%._~])", function(char)
        return string.format("%%%02X", string.byte(char))
    end))
end

local function PercentDecode(value)
    value = tostring(value or "")
    return (value:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end))
end

local function Bool(value)
    return value and "1" or "0"
end

local function ParseBool(value)
    return value == "1" or value == "true" or value == "TRUE"
end

local function SortedKeys(tbl)
    local keys = {}
    for key in pairs(tbl or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

local function JoinMap(tbl)
    local output = {}
    local keys = SortedKeys(tbl)
    for i = 1, #keys do
        local key = keys[i]
        output[#output + 1] = tostring(key) .. ":" .. Bool(tbl[key] ~= false)
    end
    return table.concat(output, ",")
end

local function ParseMap(value, validKeys)
    local output = {}
    for pair in tostring(value or ""):gmatch("[^,]+") do
        local key, state = pair:match("^([^:]+):([01])$")
        if key and (not validKeys or validKeys[key]) then
            output[key] = state == "1"
        end
    end
    return output
end

local function JoinGroups(ignored)
    local output = {}
    for group = 1, 8 do
        if ignored and ignored[group] then
            output[#output + 1] = tostring(group)
        end
    end
    return table.concat(output, ",")
end

local function ParseGroups(value)
    local output = {}
    for token in tostring(value or ""):gmatch("[^,]+") do
        local group = tonumber(token)
        if group and group >= 1 and group <= 8 then
            output[group] = true
        end
    end
    return output
end

local function JoinOrder(orderByCategory)
    local sections = {}
    for i = 1, #RA.Categories do
        local categoryKey = RA.Categories[i].key
        local order = orderByCategory and orderByCategory[categoryKey]
        if type(order) == "table" and #order > 0 then
            sections[#sections + 1] = categoryKey .. ":" .. table.concat(order, ",")
        end
    end
    return table.concat(sections, ";")
end

local function ParseOrder(value)
    local output = {}
    local validCategories = {}
    for i = 1, #RA.Categories do
        validCategories[RA.Categories[i].key] = true
    end

    for section in tostring(value or ""):gmatch("[^;]+") do
        local categoryKey, list = section:match("^([^:]+):(.*)$")
        if categoryKey and validCategories[categoryKey] then
            local order = {}
            local seen = {}
            for abilityKey in tostring(list or ""):gmatch("[^,]+") do
                local ability = RA.CatalogByKey and RA.CatalogByKey[abilityKey]
                if ability and ability.category == categoryKey and not seen[abilityKey] then
                    seen[abilityKey] = true
                    order[#order + 1] = abilityKey
                end
            end
            output[categoryKey] = order
        end
    end
    return output
end

local function AddField(fields, key, value)
    fields[#fields + 1] = key .. "=" .. PercentEncode(value)
end

function RA:ExportProfileString()
    local db = self:GetDB()
    if not db then
        return nil, "No profile is loaded."
    end

    if self.EnsureAbilityOrder then
        self:EnsureAbilityOrder()
    end

    local fields = {}
    AddField(fields, "catalog", tostring(self.CATALOG_VERSION or 0))
    AddField(fields, "mode", db.mode)
    AddField(fields, "accentPreset", db.accentPreset or "SUNSET")
    AddField(fields, "hudDirection", db.hudDirection or "RIGHT")
    AddField(fields, "content.showTooltips", Bool(not db.content or db.content.showTooltips ~= false))
    AddField(fields, "scale", string.format("%.3f", db.scale or 1.25))
    AddField(fields, "opacity", string.format("%.3f", db.opacity or 0.96))
    AddField(fields, "detailedWidth", tostring(db.detailedWidth or 286))
    AddField(fields, "autoShowEncounter", Bool(db.autoShowEncounter ~= false))
    AddField(fields, "hideWhenSolo", Bool(db.hideWhenSolo == true))
    AddField(fields, "leaderOnly", Bool(db.leaderOnly == true))
    AddField(fields, "locked", Bool(db.locked == true))
    AddField(fields, "demoMode", Bool(db.demoMode == true))

    local compact = db.compact or {}
    AddField(fields, "compact.iconSize", tostring(compact.iconSize or 28))
    AddField(fields, "compact.nameLength", tostring(compact.nameLength or 4))
    AddField(fields, "compact.nameFontSize", tostring(compact.nameFontSize or 8))
    AddField(fields, "compact.tileGap", tostring(compact.tileGap or 3))
    AddField(fields, "compact.rowGap", tostring(compact.rowGap or 2))
    AddField(fields, "compact.categoryGap", tostring(compact.categoryGap or 4))
    AddField(fields, "compact.wrapAfter", tostring(compact.wrapAfter or 8))
    AddField(fields, "compact.overflowMode", compact.overflowMode or "WRAP")
    AddField(fields, "compact.showEmptyState", Bool(compact.showEmptyState == true))
    AddField(fields, "compact.backgroundStyle", compact.backgroundStyle or "RIBBONS")
    AddField(fields, "compact.categoryLabels", compact.categoryLabels or "SHORT")
    AddField(fields, "compact.labelWidth", tostring(compact.labelWidth or 34))
    AddField(fields, "compact.panelPadding", tostring(compact.panelPadding or 4))
    AddField(fields, "compact.roundedIcons", Bool(compact.roundedIcons ~= false))

    local scan = db.scan or {}
    AddField(fields, "scan.showStrip", Bool(scan.showStrip ~= false))
    AddField(fields, "scan.scale", string.format("%.3f", scan.scale or 1.10))
    AddField(fields, "scan.wrapAfter", tostring(scan.wrapAfter or 9))
    AddField(fields, "scan.demoPreview", Bool(scan.demoPreview ~= false))

    local actions = db.actions or {}
    AddField(fields, "actions.leftClickMode", actions.leftClickMode or "WHISPER")
    AddField(fields, "actions.sayEnabled", Bool(actions.leftClickMode == "SAY"))
    AddField(fields, "actions.whisperEnabled", Bool(actions.leftClickMode == "WHISPER"))
    AddField(fields, "actions.raidWarningEnabled", Bool(actions.raidWarningEnabled ~= false))
    AddField(fields, "actions.sayTemplate", actions.sayTemplate or "{name} - {spell}")
    AddField(fields, "actions.whisperTemplate", actions.whisperTemplate or "RAID LEAD: USE {spell}")
    AddField(fields, "actions.raidWarningTemplate", actions.raidWarningTemplate or "{name} - {spell}")

    local toolbox = db.leaderToolbox or {}
    AddField(fields, "leaderToolbox.enabled", Bool(toolbox.enabled ~= false))
    AddField(fields, "leaderToolbox.showForNonLeaders", Bool(toolbox.showForNonLeaders ~= false))
    AddField(fields, "leaderToolbox.showMissing", Bool(toolbox.showMissing ~= false))
    AddField(fields, "leaderToolbox.panicEnabled", Bool(toolbox.panicEnabled ~= false))
    AddField(fields, "leaderToolbox.panicMessage", toolbox.panicMessage or "PANIC: USE DEFENSIVES + HEALTH POTIONS NOW!")
    AddField(fields, "leaderToolbox.closeDelay", string.format("%.2f", toolbox.closeDelay or 1.0))
    AddField(fields, "leaderToolbox.tooltipDelay", string.format("%.2f", toolbox.tooltipDelay or 0.75))
    AddField(fields, "leaderToolbox.puckSize", tostring(toolbox.puckSize or 30))
    AddField(fields, "leaderToolbox.countdownSeconds", tostring(toolbox.countdownSeconds or 15))
    AddField(fields, "leaderToolbox.flyoutDirection", toolbox.flyoutDirection or "AUTO")

    local validCategories = {}
    for i = 1, #self.Categories do validCategories[self.Categories[i].key] = true end
    AddField(fields, "ignoredGroups", JoinGroups(db.ignoredRaidGroups))
    AddField(fields, "categories", JoinMap(db.categories))

    local abilityOverrides = {}
    for key, value in pairs(db.abilities or {}) do
        if self.CatalogByKey and self.CatalogByKey[key] then
            abilityOverrides[key] = value ~= false
        end
    end
    AddField(fields, "abilities", JoinMap(abilityOverrides))
    AddField(fields, "abilityOrder", JoinOrder(db.abilityOrder))

    table.sort(fields)
    return PREFIX .. table.concat(fields, "&")
end

local function SetNumber(target, key, value)
    local number = tonumber(value)
    if number then target[key] = number end
end

function RA:ImportProfileString(text)
    if InCombatLockdown() then
        return false, "Profiles cannot be imported during combat."
    end

    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local activePrefix
    if text:sub(1, #PREFIX) == PREFIX then
        activePrefix = PREFIX
    else
        for i = 1, #LEGACY_PREFIXES do
            local legacy = LEGACY_PREFIXES[i]
            if text:sub(1, #legacy) == legacy then
                activePrefix = legacy
                break
            end
        end
    end
    if not activePrefix then
        return false, "That is not an RCP Arsenal profile string."
    end

    local rawFields = {}
    local body = text:sub(#activePrefix + 1)
    for pair in body:gmatch("[^&]+") do
        local key, value = pair:match("^([^=]+)=(.*)$")
        if key then rawFields[key] = PercentDecode(value) end
    end

    local profile = self:CreateDefaultProfile()
    profile.mode = rawFields.mode or profile.mode
    profile.accentPreset = rawFields.accentPreset or profile.accentPreset
    if rawFields.hudDirection then profile.hudDirection = rawFields.hudDirection end
    profile.content = profile.content or {}
    if rawFields["content.showTooltips"] then profile.content.showTooltips = ParseBool(rawFields["content.showTooltips"]) end
    SetNumber(profile, "scale", rawFields.scale)
    SetNumber(profile, "opacity", rawFields.opacity)
    SetNumber(profile, "detailedWidth", rawFields.detailedWidth)
    if rawFields.autoShowEncounter then profile.autoShowEncounter = ParseBool(rawFields.autoShowEncounter) end
    if rawFields.hideWhenSolo then profile.hideWhenSolo = ParseBool(rawFields.hideWhenSolo) end
    if rawFields.leaderOnly then profile.leaderOnly = ParseBool(rawFields.leaderOnly) end
    if rawFields.locked then profile.locked = ParseBool(rawFields.locked) end
    if rawFields.demoMode then profile.demoMode = ParseBool(rawFields.demoMode) end

    local compact = profile.compact
    SetNumber(compact, "iconSize", rawFields["compact.iconSize"])
    SetNumber(compact, "nameLength", rawFields["compact.nameLength"])
    SetNumber(compact, "nameFontSize", rawFields["compact.nameFontSize"])
    SetNumber(compact, "tileGap", rawFields["compact.tileGap"])
    SetNumber(compact, "rowGap", rawFields["compact.rowGap"])
    SetNumber(compact, "categoryGap", rawFields["compact.categoryGap"])
    SetNumber(compact, "wrapAfter", rawFields["compact.wrapAfter"])
    if rawFields["compact.overflowMode"] then compact.overflowMode = rawFields["compact.overflowMode"] end
    if rawFields["compact.showEmptyState"] then compact.showEmptyState = ParseBool(rawFields["compact.showEmptyState"]) end
    if rawFields["compact.backgroundStyle"] then compact.backgroundStyle = rawFields["compact.backgroundStyle"] end
    if rawFields["compact.categoryLabels"] then compact.categoryLabels = rawFields["compact.categoryLabels"] end
    SetNumber(compact, "labelWidth", rawFields["compact.labelWidth"])
    SetNumber(compact, "panelPadding", rawFields["compact.panelPadding"])
    if rawFields["compact.roundedIcons"] then compact.roundedIcons = ParseBool(rawFields["compact.roundedIcons"]) end

    local scan = profile.scan
    if rawFields["scan.showStrip"] then scan.showStrip = ParseBool(rawFields["scan.showStrip"]) end
    SetNumber(scan, "scale", rawFields["scan.scale"])
    SetNumber(scan, "wrapAfter", rawFields["scan.wrapAfter"])
    if rawFields["scan.demoPreview"] then scan.demoPreview = ParseBool(rawFields["scan.demoPreview"]) end

    local actions = profile.actions
    if rawFields["actions.leftClickMode"] then
        actions.leftClickMode = rawFields["actions.leftClickMode"]
    elseif rawFields["actions.sayEnabled"] ~= nil or rawFields["actions.whisperEnabled"] ~= nil then
        local oldSay = rawFields["actions.sayEnabled"] and ParseBool(rawFields["actions.sayEnabled"]) or false
        local oldWhisper = rawFields["actions.whisperEnabled"] and ParseBool(rawFields["actions.whisperEnabled"]) or false
        if oldSay and not oldWhisper then actions.leftClickMode = "SAY"
        elseif oldWhisper then actions.leftClickMode = "WHISPER"
        elseif oldSay then actions.leftClickMode = "SAY"
        else actions.leftClickMode = "OFF" end
    end
    actions.sayEnabled = actions.leftClickMode == "SAY"
    actions.whisperEnabled = actions.leftClickMode == "WHISPER"
    if rawFields["actions.raidWarningEnabled"] then actions.raidWarningEnabled = ParseBool(rawFields["actions.raidWarningEnabled"]) end
    if rawFields["actions.sayTemplate"] then actions.sayTemplate = rawFields["actions.sayTemplate"] end
    if rawFields["actions.whisperTemplate"] then actions.whisperTemplate = rawFields["actions.whisperTemplate"] end
    if rawFields["actions.raidWarningTemplate"] then actions.raidWarningTemplate = rawFields["actions.raidWarningTemplate"] end

    local toolbox = profile.leaderToolbox
    if rawFields["leaderToolbox.enabled"] then toolbox.enabled = ParseBool(rawFields["leaderToolbox.enabled"]) end
    if rawFields["leaderToolbox.showForNonLeaders"] then toolbox.showForNonLeaders = ParseBool(rawFields["leaderToolbox.showForNonLeaders"]) end
    if rawFields["leaderToolbox.showMissing"] then toolbox.showMissing = ParseBool(rawFields["leaderToolbox.showMissing"]) end
    if rawFields["leaderToolbox.panicEnabled"] then toolbox.panicEnabled = ParseBool(rawFields["leaderToolbox.panicEnabled"]) end
    if rawFields["leaderToolbox.panicMessage"] then toolbox.panicMessage = rawFields["leaderToolbox.panicMessage"] end
    SetNumber(toolbox, "closeDelay", rawFields["leaderToolbox.closeDelay"])
    SetNumber(toolbox, "tooltipDelay", rawFields["leaderToolbox.tooltipDelay"])
    SetNumber(toolbox, "puckSize", rawFields["leaderToolbox.puckSize"])
    SetNumber(toolbox, "countdownSeconds", rawFields["leaderToolbox.countdownSeconds"])
    if rawFields["leaderToolbox.flyoutDirection"] then toolbox.flyoutDirection = rawFields["leaderToolbox.flyoutDirection"] end

    profile.ignoredRaidGroups = ParseGroups(rawFields.ignoredGroups)

    local validCategories = {}
    for i = 1, #self.Categories do validCategories[self.Categories[i].key] = true end
    if rawFields.categories then
        profile.categories = ParseMap(rawFields.categories, validCategories)
    end

    if rawFields.abilities then
        profile.abilities = ParseMap(rawFields.abilities, self.CatalogByKey)
    end

    if rawFields.abilityOrder then
        profile.abilityOrder = ParseOrder(rawFields.abilityOrder)
    end

    self:NormalizeProfile(profile)
    if not self:ApplyImportedProfile(profile) then
        return false, "The profile could not be applied."
    end

    if self.EnsureAbilityOrder then self:EnsureAbilityOrder() end
    if self.OnIgnoredRaidGroupsChanged then self:OnIgnoredRaidGroupsChanged() end
    if self.OnCapabilityFiltersChanged then self:OnCapabilityFiltersChanged() end
    if self.RefreshHUD then self:RefreshHUD() end

    local exportedCatalog = tonumber(rawFields.catalog)
    if exportedCatalog and exportedCatalog ~= self.CATALOG_VERSION then
        return true, "Profile imported. Unknown or changed abilities were safely ignored."
    end
    return true, "Profile imported successfully."
end
