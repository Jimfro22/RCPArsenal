local _, RA = ...

-- Folder identities come from each author's TOC/package, never a display title.
-- Source links document detection; download links are informational only.
local Catalog = {}
RA.AddonCatalog = Catalog
Catalog.Entries = {
    { id = "arsenal", name = "RCP Arsenal", priority = "Core", folders = { "RCPArsenal" },
      description = "The raid's shared setup hub and passive readiness reporter.",
      url = "https://www.readycheckpull.com", source = "RCPArsenal.toc", internal = true },
    { id = "northernsky", name = "Northern Sky Raid Tools", priority = "Core", folders = { "NorthernSkyRaidTools" },
      description = "Raid reminders, assignments, and encounter tools from Northern Sky.",
      url = "https://www.curseforge.com/wow/addons/northern-sky-raid-tools",
      source = "https://github.com/Reloe/NorthernSkyRaidTools/blob/main/NorthernSkyRaidTools/NorthernSkyRaidTools.toc" },
    { id = "rclootcouncil", name = "RCLootCouncil", priority = "Core", folders = { "RCLootCouncil" },
      description = "Shares loot candidates and council decisions with the raid.",
      url = "https://www.curseforge.com/wow/addons/rclootcouncil",
      source = "https://github.com/evil-morfar/RCLootCouncil2/blob/master/RCLootCouncil.toc" },
    { id = "simulationcraft", name = "Simulationcraft", priority = "Important", folders = { "Simulationcraft", "SimulationCraft" },
      description = "Exports your current character for SimulationCraft and Raidbots.",
      url = "https://www.curseforge.com/wow/addons/simulationcraft",
      source = "https://github.com/simulationcraft/simc-addon/blob/master/.pkgmeta" },
    { id = "wowutils", name = "WowUtils", priority = "Team tool", folders = { "wowutils", "WowUtils" },
      description = "Connects the team's WowUtils data and in-game raid tools.",
      url = "https://www.curseforge.com/wow/addons/wowutils",
      source = "https://github.com/wowutils/addon/blob/main/wowutils.toc" },
    { id = "autopotion", name = "AutoPotion", priority = "Optional", folders = { "AutoPotion" },
      description = "Maintains healthstone and potion macros for your own keypresses.",
      url = "https://www.curseforge.com/wow/addons/auto-potion",
      source = "https://github.com/ollidiemaus/AutoPotion/blob/main/AutoPotion.toc" },
    { id = "bigwigs", name = "BigWigs", priority = "Optional", folders = { "BigWigs" },
      description = "Provides modular boss encounter warnings and timers.",
      url = "https://www.curseforge.com/wow/addons/big-wigs",
      source = "https://github.com/BigWigsMods/BigWigs/blob/master/BigWigs.toc" },
}
local entriesByID = {}
for i = 1, #Catalog.Entries do
    local entry = Catalog.Entries[i]
    entry.order = i
    entriesByID[entry.id] = entry
end

local function IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function PlainString(value)
    return not IsSecret(value) and type(value) == "string" and value or nil
end

-- Exact strings are retained. Unexpanded packager placeholders and absent or
-- excessively large metadata cannot become an approved target or a wire value.
function Catalog:NormalizeVersion(value, maximum)
    value = PlainString(value)
    if not value then return nil end
    value = value:match("^%s*(.-)%s*$")
    if #value == 0 or #value > (maximum or 64) or value:find("[%c|@${}]")
        or not value:find("%d") then return nil end
    return value
end

function Catalog:GetEntry(id)
    return entriesByID[id]
end

local function Call(api, ...)
    if type(api) ~= "function" then return false end
    return pcall(api, ...)
end

local function CopyRow(row)
    local copy = {}
    for key, value in pairs(row) do copy[key] = value end
    return copy
end

local localReport
function Catalog:RefreshLocal()
    local api = C_AddOns or {}
    local installed, enumerated = {}, false
    local ok, count = Call(api.GetNumAddOns)
    if ok and not IsSecret(count) and type(count) == "number" and count >= 0 and count <= 3000 then
        enumerated = true
        for i = 1, count do
            local infoOK, name = Call(api.GetAddOnInfo, i)
            name = infoOK and PlainString(name) or nil
            if name then installed[name:lower()] = name else enumerated = false end
        end
    end
    local report = { rows = {}, byID = {}, refreshedAt = GetTime and GetTime() or 0,
        version = self:NormalizeVersion(RA.VERSION), build = self:NormalizeVersion(RA.BUILD, 32),
        protocol = RA.READINESS_PROTOCOL }
    local character = UnitGUID and PlainString(UnitGUID("player")) or nil
    for i = 1, #self.Entries do
        local entry = self.Entries[i]
        local row = { id = entry.id, name = entry.name }
        for j = 1, #entry.folders do
            local folder = installed[entry.folders[j]:lower()]
            if folder then row.folder = folder; row.installed = true; break end
        end
        if entry.internal then
            row.folder, row.installed, row.loaded = RA.ADDON_NAME or "RCPArsenal", true, true
            -- Running code proves loaded, but the next-reload enable state can
            -- already be disabled through Blizzard's AddOns list.
            if character then
                local enabledOK, enabled = Call(api.GetAddOnEnableState, row.folder, character)
                if enabledOK and not IsSecret(enabled) and type(enabled) == "number" then row.enabled = enabled > 0 end
            end
            row.version, row.build, row.protocol = report.version, report.build, report.protocol
        elseif row.installed then
            -- Native AddonList supplies addonName, character GUID. Never change state.
            if character then
                local enabledOK, enabled = Call(api.GetAddOnEnableState, row.folder, character)
                if enabledOK and not IsSecret(enabled) and type(enabled) == "number" then row.enabled = enabled > 0 end
            end
            -- First return means loaded OR loading. Only the second is loaded.
            local loadedOK, _, loaded = Call(api.IsAddOnLoaded, row.folder)
            if loadedOK and not IsSecret(loaded) and type(loaded) == "boolean" then row.loaded = loaded end
            local versionOK, version = Call(api.GetAddOnMetadata, row.folder, "Version")
            row.version = versionOK and self:NormalizeVersion(version) or nil
        elseif enumerated then
            row.installed, row.enabled, row.loaded = false, false, false
        end
        if row.installed == false then row.status = "missing"
        elseif row.installed == nil then row.status = "unknown"
        elseif row.enabled == false then row.status = "disabled"
        elseif row.loaded == false then row.status = "not_loaded"
        elseif row.enabled == nil or row.loaded == nil then row.status = "unknown"
        else row.status = "loaded" end
        report.rows[i], report.byID[entry.id] = row, row
    end
    localReport = report
    return self:GetLocalReport()
end

function Catalog:GetLocalReport()
    if not localReport then return self:RefreshLocal() end
    local copy = { rows = {}, byID = {}, refreshedAt = localReport.refreshedAt,
        version = localReport.version, build = localReport.build, protocol = localReport.protocol }
    for i = 1, #localReport.rows do
        local row = CopyRow(localReport.rows[i])
        copy.rows[i], copy.byID[row.id] = row, row
    end
    return copy
end

RA:RegisterInitializer(function() Catalog:RefreshLocal() end)
RA:RegisterEvent("ADDON_LOADED", function() localReport = nil end)
RA:RegisterEvent("PLAYER_ENTERING_WORLD", function() localReport = nil end)
