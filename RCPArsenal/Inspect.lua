local _, RA = ...

-- Leader-only, pre-pull capability collection.
-- Other raid members do not need RCP Arsenal installed. This client inspects
-- one unit at a time while out of combat, reads Blizzard's inspected talent
-- configuration, and freezes the current roster snapshot when an encounter begins.
--
-- Incremental lifecycle contract:
--   * Successfully scanned players remain valid while the same GUID stays in an
--     eligible raid group.
--   * Automatic scans only target new, missing, or previously failed players.
--   * A full refresh only happens through an explicit user action.
--   * Raid groups 7 and 8 are excluded by default.

RA.Reports = {}
RA.FrozenReports = nil
RA.Roster = {}
RA.RosterOrder = {}
RA.FrozenRosterCount = nil
RA.FrozenVerifiedCount = nil
RA.InspectFailures = {}
RA.InspectStatus = {}
RA.IgnoredRosterCount = 0

local INSPECT_INTERVAL_MIN = 0.55
local INSPECT_INTERVAL_DEFAULT = 0.70
local INSPECT_INTERVAL_MAX = 1.40
local INSPECT_TIMEOUT = 2.75
local MISSING_RETRY_DELAY = 8.0

local scanTimer
local missingRetryTimer
local inspectTimeoutTimer
local lastInspectRequestAt = 0
local currentInspectInterval = INSPECT_INTERVAL_DEFAULT
local pendingScanReason
local pendingFullRefresh = false
local scanRestartPending = false
local scanRestartFull = false
local resumeMissingAfterCombat = false
local manualPaused = false

local inspectState = {
    running = false,
    generation = 0,
    reason = nil,
    queue = {},
    current = nil,
    processed = 0,
    total = 0,
    failed = 0,
    ownsInspectData = false,
    paused = false,
}

local function IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function GetInspectConfigID()
    if Constants and Constants.TraitConsts and Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID then
        return Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID
    end
    return -1
end

local function GetPlayerSpecID()
    if not C_SpecializationInfo then
        return 0
    end

    local specIndex = C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecialization()
    if specIndex and C_SpecializationInfo.GetSpecializationInfo then
        return select(1, C_SpecializationInfo.GetSpecializationInfo(specIndex)) or 0
    end
    return 0
end

local function BuildCapabilitySet(indexes)
    local set = {}
    for i = 1, #indexes do
        set[indexes[i]] = true
    end
    return set
end

local function CopyTable(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end

local function CopyReport(report)
    return {
        name = report.name,
        guid = report.guid,
        class = report.class,
        specID = report.specID,
        role = report.role,
        classRevision = report.classRevision,
        verified = report.verified,
        source = report.source,
        updatedAt = report.updatedAt,
        generation = report.generation,
        capabilities = CopyTable(report.capabilities),
        evidence = CopyTable(report.evidence),
    }
end

local function SetInspectStatus(name, state, reason)
    if not name then
        return
    end

    RA.InspectStatus[name] = {
        state = state,
        reason = reason,
        updatedAt = GetTime(),
    }
end

local function UserIsInspecting()
    if InspectFrame and InspectFrame.IsShown and InspectFrame:IsShown() then
        return true
    end
    if PlayerSpellsFrame and PlayerSpellsFrame.IsInspecting and PlayerSpellsFrame:IsInspecting() then
        return true
    end
    return false
end

local function SafeClearInspectPlayer()
    if not UserIsInspecting() and ClearInspectPlayer then
        ClearInspectPlayer()
    end
end

-- Remote talent scans repeat the same static spell/definition lookups for every
-- player of a given spec. Cache those immutable relationships for the session so
-- the inspect result path only reads the per-player node state that can change.
local spellAliasCache = {}
local entryAliasCache = {}
local treeNodesCache = {}
local baselineSpellCache = {}

local function MergeSpellSet(destination, source)
    for id in pairs(source or {}) do
        destination[id] = true
    end
end

local function AddSpellAlias(spellSet, spellID, specID)
    if type(spellID) ~= "number" or spellID <= 0 or IsSecret(spellID) then
        return
    end

    local cacheKey = tostring(specID or 0) .. ":" .. tostring(spellID)
    local cached = spellAliasCache[cacheKey]
    if not cached then
        cached = {[spellID] = true}

        if C_Spell and C_Spell.GetBaseSpell then
            local ok, baseSpellID = pcall(C_Spell.GetBaseSpell, spellID, specID or 0)
            if ok and type(baseSpellID) == "number" and baseSpellID > 0 and not IsSecret(baseSpellID) then
                cached[baseSpellID] = true
            end
        end

        if C_SpellBook and C_SpellBook.FindBaseSpellByID then
            local ok, baseSpellID = pcall(C_SpellBook.FindBaseSpellByID, spellID)
            if ok and type(baseSpellID) == "number" and baseSpellID > 0 and not IsSecret(baseSpellID) then
                cached[baseSpellID] = true
            end
        end
        spellAliasCache[cacheKey] = cached
    end

    MergeSpellSet(spellSet, cached)
end

local function AddEntrySpell(spellSet, configID, entryID, specID)
    if type(entryID) ~= "number" or not C_Traits then
        return false
    end

    local cacheKey = tostring(specID or 0) .. ":" .. tostring(entryID)
    local cached = entryAliasCache[cacheKey]
    if cached == false then
        return false
    end

    if not cached then
        local okEntry, entryInfo = pcall(C_Traits.GetEntryInfo, configID, entryID)
        if not okEntry or not entryInfo or not entryInfo.definitionID then
            entryAliasCache[cacheKey] = false
            return false
        end

        local okDefinition, definitionInfo = pcall(C_Traits.GetDefinitionInfo, entryInfo.definitionID)
        if not okDefinition or not definitionInfo then
            entryAliasCache[cacheKey] = false
            return false
        end

        cached = {}
        AddSpellAlias(cached, definitionInfo.spellID, specID)
        AddSpellAlias(cached, definitionInfo.overriddenSpellID, specID)
        if not next(cached) then
            entryAliasCache[cacheKey] = false
            return false
        end
        entryAliasCache[cacheKey] = cached
    end

    MergeSpellSet(spellSet, cached)
    return true
end

local function HasValidInspectData()
    if not C_Traits or not C_Traits.HasValidInspectData then
        return true
    end

    local ok, valid = pcall(C_Traits.HasValidInspectData)
    return ok and valid == true
end

local function BuildInspectSpellSet(specID)
    if not C_Traits or not C_ClassTalents or not C_SpecializationInfo then
        return nil, nil, "talent APIs unavailable"
    end

    if not HasValidInspectData() then
        return nil, nil, "inspect data incomplete"
    end

    local configID = GetInspectConfigID()
    local treeID = C_ClassTalents.GetTraitTreeForSpec and C_ClassTalents.GetTraitTreeForSpec(specID)
    local treeNodes = treeNodesCache[specID]
    if not treeNodes and treeID and C_Traits.GetTreeNodes then
        treeNodes = C_Traits.GetTreeNodes(treeID)
        if type(treeNodes) == "table" then
            treeNodesCache[specID] = treeNodes
        end
    end
    if not treeID or type(treeNodes) ~= "table" then
        return nil, nil, "talent tree unavailable"
    end

    local selectedSpellSet = {}
    local baselineSpellSet = baselineSpellCache[specID]
    if not baselineSpellSet then
        baselineSpellSet = {}
        baselineSpellCache[specID] = baselineSpellSet
    end
    local selectedEntryCount = 0
    local readableNodeCount = 0

    -- Specialization display data is tracked separately. It may confirm true
    -- baseline abilities, but it must never override an inspected choice node.
    if not baselineSpellSet.__built then
        if C_SpecializationInfo.GetSpellsDisplay then
            local ok, baselineSpells = pcall(C_SpecializationInfo.GetSpellsDisplay, specID)
            if ok and type(baselineSpells) == "table" then
                for i = 1, #baselineSpells do
                    AddSpellAlias(baselineSpellSet, baselineSpells[i], specID)
                end
            end
        end
        baselineSpellSet.__built = true
    end

    local selectionType = Enum and Enum.TraitNodeType and Enum.TraitNodeType.Selection
    for i = 1, #treeNodes do
        local ok, nodeInfo = pcall(C_Traits.GetNodeInfo, configID, treeNodes[i])
        if ok and nodeInfo then
            readableNodeCount = readableNodeCount + 1

            -- Ranks can remain represented for an inactive Hero Talent subtree.
            if nodeInfo.subTreeActive ~= false then
                local selectedEntries = {}
                local committed = nodeInfo.entryIDsWithCommittedRanks or {}
                local activeEntryID = nodeInfo.activeEntry and nodeInfo.activeEntry.entryID
                local isSelection = selectionType and nodeInfo.type == selectionType
                if not isSelection and activeEntryID and #committed > 1 then
                    -- Compatibility fallback for clients that omit nodeInfo.type.
                    isSelection = true
                end

                if isSelection and activeEntryID and (nodeInfo.activeRank or 0) > 0 then
                    -- A choice node may retain committed-rank metadata for both
                    -- branches. Only the active entry is an equipped capability.
                    selectedEntries[activeEntryID] = true
                else
                    for j = 1, #committed do
                        selectedEntries[committed[j]] = true
                    end
                    if (nodeInfo.activeRank or 0) > 0 and activeEntryID then
                        selectedEntries[activeEntryID] = true
                    end
                end

                for entryID in pairs(selectedEntries) do
                    if AddEntrySpell(selectedSpellSet, configID, entryID, specID) then
                        selectedEntryCount = selectedEntryCount + 1
                    end
                end
            end
        end
    end

    if readableNodeCount == 0 or selectedEntryCount == 0 then
        return nil, nil, "inspect talent nodes unavailable"
    end

    return selectedSpellSet, baselineSpellSet
end

function RA:IsRaidGroupIgnored(subgroup)
    local db = self:GetDB()
    return db and db.ignoredRaidGroups and db.ignoredRaidGroups[subgroup] == true
end

function RA:RefreshRoster()
    local previousRoster = self.Roster or {}
    local roster = {}
    local order = {}
    local ignoredCount = 0

    local function AddUnit(unit, subgroup, raidIndex)
        if not UnitExists(unit) or not UnitIsPlayer(unit) then
            return
        end

        local fullName = self:GetFullUnitName(unit)
        local guid = UnitGUID(unit)
        if not fullName or not guid or IsSecret(fullName) or IsSecret(guid) then
            return
        end

        local _, classFile = UnitClass(unit)
        local connected = true
        if UnitIsConnected then
            local value = UnitIsConnected(unit)
            if not IsSecret(value) then
                connected = value ~= false
            end
        end

        local info = {
            unit = unit,
            raidIndex = raidIndex,
            subgroup = subgroup,
            guid = guid,
            name = fullName,
            shortName = self:GetShortName(fullName),
            class = classFile,
            role = UnitGroupRolesAssigned(unit),
            connected = connected,
        }

        roster[fullName] = info
        order[#order + 1] = info
    end

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local subgroup = select(3, GetRaidRosterInfo(i))
            if subgroup and self:IsRaidGroupIgnored(subgroup) then
                ignoredCount = ignoredCount + 1
            else
                AddUnit("raid" .. i, subgroup, i)
            end
        end
    elseif IsInGroup() then
        AddUnit("player", 1, 0)
        for i = 1, GetNumSubgroupMembers() do
            AddUnit("party" .. i, 1, i)
        end
    else
        AddUnit("player", 1, 0)
    end

    local changes = {
        added = {},
        removed = {},
        addedCount = 0,
        removedCount = 0,
        changed = {},
        changedCount = 0,
        ignoredCount = ignoredCount,
    }

    for name, info in pairs(roster) do
        local previous = previousRoster[name]
        if not previous or previous.guid ~= info.guid then
            changes.added[name] = true
            changes.addedCount = changes.addedCount + 1
        elseif previous.role ~= info.role or previous.class ~= info.class then
            changes.changed[name] = true
            changes.changedCount = changes.changedCount + 1
        end
    end

    for name, info in pairs(previousRoster) do
        local current = roster[name]
        if not current or current.guid ~= info.guid then
            changes.removed[name] = true
            changes.removedCount = changes.removedCount + 1
        end
    end

    self.Roster = roster
    self.RosterOrder = order
    self.IgnoredRosterCount = ignoredCount
    return changes
end

function RA:IsReportFresh(report, rosterInfo)
    if not report or not report.verified then
        return false
    end

    if report.source == "DEMO" then
        return true
    end

    if not rosterInfo or report.guid ~= rosterInfo.guid then
        return false
    end

    if report.classRevision ~= self:GetClassCatalogRevision(report.class) then
        return false
    end

    -- A sorter-only specialization report is sufficient until the user enables
    -- an Arsenal capability for that class. At that point it must be upgraded
    -- through the full talent scan rather than remaining falsely "fresh" with
    -- an empty capability set.
    if report.evidence and report.evidence.roleOnly and self:ClassNeedsCapabilityInspection(report.class) then
        return false
    end

    -- Role changes are an immediate, no-inspect signal that a same-GUID player
    -- may have changed specialization (for example Ret -> Holy).
    if report.role and rosterInfo.role and report.role ~= rosterInfo.role then
        return false
    end

    return true
end

function RA:PruneReports()
    for name, report in pairs(self.Reports) do
        local rosterInfo = self.Roster[name]
        if not rosterInfo or report.guid ~= rosterInfo.guid then
            self.Reports[name] = nil
            self.InspectFailures[name] = nil
            self.InspectStatus[name] = nil
        end
    end
end

function RA:ClearInspectionCache()
    if self.InEncounter or InCombatLockdown() then
        return false
    end

    self:StopInspectionScan()
    wipe(self.Reports)
    wipe(self.InspectFailures)
    wipe(self.InspectStatus)
    self:RefreshRoster()
    self:StoreLocalReport()
    self:FireCallback("REPORTS_UPDATED")
    self:ScheduleInspectionScan("cache cleared", 0.10, true)
    return true
end

function RA:OnIgnoredRaidGroupsChanged()
    if self.InEncounter or InCombatLockdown() then
        return false
    end

    self:StopInspectionScan()
    self:RefreshRoster()
    self:PruneReports()
    self:StoreLocalReport()
    self:FireCallback("REPORTS_UPDATED")
    if self:HasMissingReports() then
        self:ScheduleInspectionScan("tracked groups changed", 0.10, false)
    end
    return true
end

function RA:StoreLocalReport()
    local name = self:GetFullUnitName("player")
    local guid = UnitGUID("player")
    if not name or not guid then
        return nil
    end

    local _, classFile = UnitClass("player")
    local specID = GetPlayerSpecID()
    local indexes = self:ScanLocalCapabilities(specID)
    local report = {
        name = name,
        guid = guid,
        class = classFile,
        specID = specID,
        role = UnitGroupRolesAssigned("player"),
        classRevision = self:GetClassCatalogRevision(classFile),
        verified = true,
        source = "LOCAL",
        updatedAt = GetTime(),
        capabilities = BuildCapabilitySet(indexes),
        evidence = {},
    }

    self.Reports[name] = report
    self.InspectFailures[name] = nil
    SetInspectStatus(name, "SCANNED")
    return report
end


-- The raid-leader sorter only needs exact specialization for damage classes
-- whose melee/ranged role cannot be derived from class alone. Keep these
-- inspections lightweight: when the class has no enabled Arsenal capability,
-- StoreInspectedReport records specID without walking the talent tree.
local ROLE_ONLY_INSPECT_CLASSES = {
    DRUID = true,
    SHAMAN = true,
    HUNTER = true,
    DEMONHUNTER = true,
}

function RA:ClassNeedsRoleInspection(classFile)
    if not ROLE_ONLY_INSPECT_CLASSES[classFile] or not IsInRaid() then
        return false
    end

    local db = self:GetDB()
    if not db or not db.leaderToolbox or db.leaderToolbox.enabled == false then
        return false
    end

    local leader = UnitIsGroupLeader and UnitIsGroupLeader("player")
    if leader ~= nil and not IsSecret(leader) and leader == true then
        return true
    end
    local assistant = UnitIsGroupAssistant and UnitIsGroupAssistant("player")
    return assistant ~= nil and not IsSecret(assistant) and assistant == true
end

function RA:ClassNeedsAnyInspection(classFile)
    return self:ClassNeedsCapabilityInspection(classFile) or self:ClassNeedsRoleInspection(classFile)
end

function RA:HasMissingReports()
    local playerName = self:GetFullUnitName("player")
    for name, rosterInfo in pairs(self.Roster) do
        if name ~= playerName
            and self:ClassNeedsAnyInspection(rosterInfo.class)
            and not self:IsReportFresh(self.Reports[name], rosterInfo) then
            return true
        end
    end
    return false
end

local function StoreInspectedReport(item)
    local rosterInfo = RA.Roster[item.name]
    if not rosterInfo or rosterInfo.guid ~= item.guid then
        return false, "unit changed", "FAILED"
    end

    local unit = rosterInfo.unit
    if not UnitExists(unit) or UnitGUID(unit) ~= item.guid then
        return false, "unit changed", "FAILED"
    end

    local okSpec, specID = pcall(C_SpecializationInfo.GetInspectSpecialization, unit)
    if not okSpec or type(specID) ~= "number" or specID <= 0 or IsSecret(specID) then
        return false, "specialization unavailable", "FAILED"
    end

    local indexes = {}
    local evidence = {}
    if RA:ClassNeedsCapabilityInspection(rosterInfo.class) then
        if not HasValidInspectData() then
            return false, "inspect data incomplete", "FAILED"
        end
        local ok, selectedSpellSet, baselineSpellSet, buildError = pcall(BuildInspectSpellSet, specID)
        if not ok then
            return false, tostring(selectedSpellSet), "FAILED"
        end

        if not selectedSpellSet then
            return false, buildError or baselineSpellSet or "talent scan failed", "FAILED"
        end

        indexes, evidence = RA:BuildCapabilitiesFromSpellSet(rosterInfo.class, specID, selectedSpellSet, baselineSpellSet)
    else
        -- Spec-only report for the raid sorter. This avoids a full C_Traits
        -- traversal for classes such as Hunter when Arsenal has no enabled
        -- capability requiring talent evidence.
        evidence = { roleOnly = true }
    end
    RA.Reports[item.name] = {
        name = item.name,
        guid = item.guid,
        class = rosterInfo.class,
        specID = specID,
        role = rosterInfo.role,
        classRevision = RA:GetClassCatalogRevision(rosterInfo.class),
        verified = true,
        source = "INSPECT",
        updatedAt = GetTime(),
        generation = inspectState.generation,
        capabilities = BuildCapabilitySet(indexes),
        evidence = evidence or {},
    }

    RA.InspectFailures[item.name] = nil
    SetInspectStatus(item.name, "SCANNED")
    return true
end

local ProcessInspectionQueue
local ScheduleMissingRetry

local function FinishCurrentInspection(success, reason, failureState)
    local item = inspectState.current
    if not item then
        return
    end

    if inspectTimeoutTimer then
        inspectTimeoutTimer:Cancel()
        inspectTimeoutTimer = nil
    end

    inspectState.processed = inspectState.processed + 1
    if success then
        -- Carefully move toward the fast path after successful replies.
        currentInspectInterval = math.max(INSPECT_INTERVAL_MIN, currentInspectInterval - 0.03)
    else
        inspectState.failed = inspectState.failed + 1
        RA.InspectFailures[item.name] = reason or "inspect failed"
        SetInspectStatus(item.name, failureState or "FAILED", reason)

        -- Only server-style failures back the queue off. Being offline or out
        -- of range should not slow every other inspectable player.
        if failureState == "TIMEOUT" or reason == "inspect data incomplete" then
            currentInspectInterval = math.min(INSPECT_INTERVAL_MAX, currentInspectInterval + 0.20)
        end
    end

    inspectState.current = nil
    if inspectState.ownsInspectData then
        inspectState.ownsInspectData = false
        SafeClearInspectPlayer()
    end

    RA:FireCallback("REPORTS_UPDATED")
    RA:FireCallback("INSPECTION_STATE_CHANGED")
end

local function QueuePriority(item)
    local info = RA.Roster[item.name]
    if not info then
        return 99, 99, 99
    end

    local inspectable = 1
    if CanInspect and CanInspect(info.unit, false) then
        inspectable = 0
    end

    local rolePriority = 4
    if info.role == "HEALER" then
        rolePriority = 1
    elseif info.role == "TANK" then
        rolePriority = 2
    elseif info.role == "DAMAGER" then
        rolePriority = 3
    end

    return inspectable, rolePriority, info.subgroup or 99
end

local function SortInspectionQueue(queue)
    table.sort(queue, function(a, b)
        local aRange, aRole, aGroup = QueuePriority(a)
        local bRange, bRole, bGroup = QueuePriority(b)

        if aRange ~= bRange then
            return aRange < bRange
        end
        if aRole ~= bRole then
            return aRole < bRole
        end
        if aGroup ~= bGroup then
            return aGroup < bGroup
        end
        return a.name < b.name
    end)
end

local function FinishScan()
    inspectState.running = false
    inspectState.paused = false
    inspectState.current = nil
    inspectState.queue = {}
    if inspectState.ownsInspectData then
        inspectState.ownsInspectData = false
        SafeClearInspectPlayer()
    end

    RA:FireCallback("INSPECTION_STATE_CHANGED")
    RA:FireCallback("REPORTS_UPDATED")

    if scanRestartPending and not RA.InEncounter and not InCombatLockdown() then
        local full = scanRestartFull
        scanRestartPending = false
        scanRestartFull = false
        C_Timer.After(0.20, function()
            RA:RequestInspectionScan("queued refresh", full)
        end)
    else
        ScheduleMissingRetry()
    end
end

ScheduleMissingRetry = function()
    if missingRetryTimer then
        missingRetryTimer:Cancel()
        missingRetryTimer = nil
    end

    if manualPaused or RA.InEncounter or InCombatLockdown() or not IsInGroup() or not RA:HasMissingReports() then
        return
    end

    missingRetryTimer = C_Timer.NewTimer(MISSING_RETRY_DELAY, function()
        missingRetryTimer = nil
        RA:RequestInspectionScan("retry missing", false)
    end)
end

ProcessInspectionQueue = function()
    if not inspectState.running or inspectState.current then
        return
    end

    if manualPaused then
        inspectState.paused = true
        for i = 1, #inspectState.queue do
            local queued = inspectState.queue[i]
            if queued and queued.name then
                SetInspectStatus(queued.name, "PAUSED", "manual")
            end
        end
        RA:FireCallback("INSPECTION_STATE_CHANGED")
        return
    elseif inspectState.paused then
        inspectState.paused = false
        for i = 1, #inspectState.queue do
            local queued = inspectState.queue[i]
            if queued and queued.name then
                SetInspectStatus(queued.name, "QUEUED")
            end
        end
    end

    if RA.InEncounter or InCombatLockdown() then
        resumeMissingAfterCombat = resumeMissingAfterCombat or RA:HasMissingReports()
        FinishScan()
        return
    end

    if UserIsInspecting() then
        C_Timer.After(0.40, ProcessInspectionQueue)
        return
    end

    local item = table.remove(inspectState.queue, 1)
    if not item then
        FinishScan()
        return
    end

    local rosterInfo = RA.Roster[item.name]
    if not rosterInfo or rosterInfo.guid ~= item.guid then
        inspectState.processed = inspectState.processed + 1
        inspectState.failed = inspectState.failed + 1
        RA.InspectFailures[item.name] = "left tracked roster"
        SetInspectStatus(item.name, "FAILED", "left tracked roster")
        RA:FireCallback("INSPECTION_STATE_CHANGED")
        C_Timer.After(0, ProcessInspectionQueue)
        return
    end

    item.unit = rosterInfo.unit
    if rosterInfo.connected == false then
        inspectState.current = item
        FinishCurrentInspection(false, "offline", "OFFLINE")
        C_Timer.After(0, ProcessInspectionQueue)
        return
    end

    if not CanInspect or not CanInspect(item.unit, false) then
        inspectState.current = item
        FinishCurrentInspection(false, "out of inspect range", "OUT_OF_RANGE")
        C_Timer.After(0.04, ProcessInspectionQueue)
        return
    end

    local delay = math.max(0, currentInspectInterval - (GetTime() - lastInspectRequestAt))
    if delay > 0 then
        table.insert(inspectState.queue, 1, item)
        C_Timer.After(delay, ProcessInspectionQueue)
        return
    end

    inspectState.current = item
    item.requestedAt = GetTime()
    lastInspectRequestAt = item.requestedAt
    SetInspectStatus(item.name, "INSPECTING")

    local ok, err = pcall(NotifyInspect, item.unit)
    if ok then
        inspectState.ownsInspectData = true
    end
    if not ok then
        FinishCurrentInspection(false, tostring(err), "FAILED")
        C_Timer.After(0.04, ProcessInspectionQueue)
        return
    end

    RA:FireCallback("INSPECTION_STATE_CHANGED")
    inspectTimeoutTimer = C_Timer.NewTimer(INSPECT_TIMEOUT, function()
        inspectTimeoutTimer = nil
        if inspectState.current == item then
            FinishCurrentInspection(false, "inspect timed out", "TIMEOUT")
            C_Timer.After(0.04, ProcessInspectionQueue)
        end
    end)
end

function RA:IsInspectionRunning()
    return inspectState.running
end

function RA:GetInspectionProgress()
    local currentName = inspectState.current and inspectState.current.name or nil
    return inspectState.processed, inspectState.total, inspectState.failed, inspectState.running, currentName, manualPaused or inspectState.paused
end

function RA:IsInspectionPaused()
    return manualPaused or inspectState.paused
end

function RA:GetPendingScanEntries()
    local entries = {}
    local playerName = self:GetFullUnitName("player")
    local currentName = inspectState.current and inspectState.current.name or nil
    local queuePosition = {}

    for i = 1, #inspectState.queue do
        local queued = inspectState.queue[i]
        if queued and queued.name then
            queuePosition[queued.name] = i
        end
    end

    for rosterIndex = 1, #self.RosterOrder do
        local info = self.RosterOrder[rosterIndex]
        if info and info.name ~= playerName and self:ClassNeedsAnyInspection(info.class) then
            local reportCurrent = self:IsReportFresh(self.Reports[info.name], info)
            local status = self.InspectStatus[info.name]
            local state = status and status.state or nil
            local activelyQueued = currentName == info.name or queuePosition[info.name] ~= nil
            local refreshPending = pendingFullRefresh and state == "PAUSED"
            local unresolved = not reportCurrent

            if unresolved or activelyQueued or refreshPending then
                if currentName == info.name then
                    state = "INSPECTING"
                elseif manualPaused and activelyQueued then
                    state = "PAUSED"
                elseif not state then
                    state = "WAITING"
                end

                local report = self.Reports[info.name]
                entries[#entries + 1] = {
                    name = info.name,
                    shortName = info.shortName,
                    guid = info.guid,
                    class = info.class,
                    role = info.role,
                    subgroup = info.subgroup,
                    connected = info.connected,
                    state = state,
                    reason = status and status.reason or nil,
                    current = currentName == info.name,
                    queuePosition = queuePosition[info.name],
                    rosterIndex = rosterIndex,
                    cachedSpecID = report and report.specID or nil,
                }
            end
        end
    end

    table.sort(entries, function(a, b)
        if a.current ~= b.current then
            return a.current
        end

        local aQueued = a.queuePosition ~= nil
        local bQueued = b.queuePosition ~= nil
        if aQueued ~= bQueued then
            return aQueued
        end
        if aQueued and a.queuePosition ~= b.queuePosition then
            return a.queuePosition < b.queuePosition
        end

        local priority = {
            PAUSED = 1,
            WAITING = 2,
            QUEUED = 2,
            OUT_OF_RANGE = 3,
            TIMEOUT = 4,
            FAILED = 4,
            OFFLINE = 5,
        }
        local ap = priority[a.state] or 9
        local bp = priority[b.state] or 9
        if ap ~= bp then
            return ap < bp
        end
        return a.rosterIndex < b.rosterIndex
    end)

    return entries
end

function RA:SetInspectionPaused(paused)
    paused = paused and true or false
    if manualPaused == paused then
        return
    end

    manualPaused = paused

    if paused then
        if scanTimer then
            scanTimer:Cancel()
            scanTimer = nil
        end
        if missingRetryTimer then
            missingRetryTimer:Cancel()
            missingRetryTimer = nil
        end

        inspectState.paused = true
        pendingScanReason = pendingScanReason or "manual resume"

        for i = 1, #inspectState.queue do
            local queued = inspectState.queue[i]
            if queued and queued.name then
                SetInspectStatus(queued.name, "PAUSED", "manual")
            end
        end

        if not inspectState.running then
            local playerName = self:GetFullUnitName("player")
            for name, rosterInfo in pairs(self.Roster) do
                if name ~= playerName
                    and self:ClassNeedsAnyInspection(rosterInfo.class)
                    and not self:IsReportFresh(self.Reports[name], rosterInfo) then
                    SetInspectStatus(name, "PAUSED", "manual")
                end
            end
        end
    else
        inspectState.paused = false
        for i = 1, #inspectState.queue do
            local queued = inspectState.queue[i]
            if queued and queued.name then
                SetInspectStatus(queued.name, "QUEUED")
            end
        end

        if inspectState.running then
            C_Timer.After(0, ProcessInspectionQueue)
        elseif not self.InEncounter and not InCombatLockdown() and (pendingFullRefresh or self:HasMissingReports()) then
            self:RequestInspectionScan(pendingScanReason or "manual resume", pendingFullRefresh)
            pendingScanReason = nil
            pendingFullRefresh = false
        end
    end

    self:FireCallback("INSPECTION_STATE_CHANGED")
    self:FireCallback("REPORTS_UPDATED")
end

function RA:ToggleInspectionPaused()
    self:SetInspectionPaused(not manualPaused)
end

function RA:GetScanSummary()
    local summary = {
        scanned = 0,
        inspected = 0,
        filtered = 0,
        total = 0,
        ignored = self.IgnoredRosterCount or 0,
        pending = 0,
        outOfRange = 0,
        offline = 0,
        failed = 0,
    }

    for name, rosterInfo in pairs(self.Roster) do
        summary.total = summary.total + 1

        local reportCurrent = self:IsReportFresh(self.Reports[name], rosterInfo)
        local needsInspection = self:ClassNeedsAnyInspection(rosterInfo.class)
        if reportCurrent then
            summary.scanned = summary.scanned + 1
            summary.inspected = summary.inspected + 1
        elseif not needsInspection then
            -- Resolved from class + current filters; this class has no ability
            -- that could appear in the selected HUD view.
            summary.scanned = summary.scanned + 1
            summary.filtered = summary.filtered + 1
        end

        local status = self.InspectStatus[name]
        local state = status and status.state
        if state == "QUEUED" or state == "INSPECTING" or state == "PAUSED" or state == "WAITING" then
            summary.pending = summary.pending + 1
        elseif state == "OUT_OF_RANGE" then
            summary.outOfRange = summary.outOfRange + 1
        elseif state == "OFFLINE" then
            summary.offline = summary.offline + 1
        elseif state == "TIMEOUT" or state == "FAILED" then
            summary.failed = summary.failed + 1
        end
    end

    return summary
end

function RA:StopInspectionScan()
    if scanTimer then
        scanTimer:Cancel()
        scanTimer = nil
    end
    if missingRetryTimer then
        missingRetryTimer:Cancel()
        missingRetryTimer = nil
    end
    if inspectTimeoutTimer then
        inspectTimeoutTimer:Cancel()
        inspectTimeoutTimer = nil
    end

    local interrupted = {}
    if inspectState.current then
        interrupted[inspectState.current.name] = true
    end
    for i = 1, #inspectState.queue do
        interrupted[inspectState.queue[i].name] = true
    end

    inspectState.running = false
    inspectState.paused = false
    inspectState.queue = {}
    inspectState.current = nil

    if inspectState.ownsInspectData then
        inspectState.ownsInspectData = false
        SafeClearInspectPlayer()
    end

    for name in pairs(interrupted) do
        local rosterInfo = self.Roster[name]
        if self:IsReportFresh(self.Reports[name], rosterInfo) then
            SetInspectStatus(name, "SCANNED")
        else
            SetInspectStatus(name, "PAUSED", "combat")
        end
    end

    pendingScanReason = nil
    pendingFullRefresh = false
    scanRestartPending = false
    scanRestartFull = false
    self:FireCallback("INSPECTION_STATE_CHANGED")
end

function RA:RequestInspectionScan(reason, fullRefresh)
    self:RefreshRoster()
    self:PruneReports()
    self:StoreLocalReport()

    if manualPaused then
        pendingScanReason = reason or pendingScanReason or "manual resume"
        pendingFullRefresh = pendingFullRefresh or fullRefresh == true

        local playerName = self:GetFullUnitName("player")
        for name, rosterInfo in pairs(self.Roster) do
            if name ~= playerName
                and self:ClassNeedsAnyInspection(rosterInfo.class)
                and (fullRefresh == true or not self:IsReportFresh(self.Reports[name], rosterInfo)) then
                SetInspectStatus(name, "PAUSED", "manual")
            end
        end

        self:FireCallback("REPORTS_UPDATED")
        self:FireCallback("INSPECTION_STATE_CHANGED")
        return true
    end

    if self.InEncounter or InCombatLockdown() then
        resumeMissingAfterCombat = resumeMissingAfterCombat or self:HasMissingReports()
        self:FireCallback("REPORTS_UPDATED")
        return false
    end

    if missingRetryTimer then
        missingRetryTimer:Cancel()
        missingRetryTimer = nil
    end

    if inspectState.running then
        scanRestartPending = true
        scanRestartFull = scanRestartFull or fullRefresh == true
        return true
    end

    inspectState.generation = inspectState.generation + 1
    inspectState.paused = false
    inspectState.reason = reason or "manual"
    inspectState.queue = {}
    inspectState.current = nil
    inspectState.processed = 0
    inspectState.failed = 0

    local playerName = self:GetFullUnitName("player")
    for i = 1, #self.RosterOrder do
        local info = self.RosterOrder[i]
        if info.name == playerName then
            SetInspectStatus(info.name, "SCANNED")
        else
            local report = self.Reports[info.name]
            local reportCurrent = self:IsReportFresh(report, info)
            local classNeedsInspection = self:ClassNeedsAnyInspection(info.class)
            local needsInspection = classNeedsInspection and (fullRefresh == true or not reportCurrent)

            if needsInspection then
                inspectState.queue[#inspectState.queue + 1] = {
                    unit = info.unit,
                    guid = info.guid,
                    name = info.name,
                }
                SetInspectStatus(info.name, "QUEUED")
            elseif classNeedsInspection then
                SetInspectStatus(info.name, "SCANNED")
            else
                self.InspectFailures[info.name] = nil
                SetInspectStatus(info.name, "FILTERED", "no enabled tools for class")
            end
        end
    end

    SortInspectionQueue(inspectState.queue)
    inspectState.total = #inspectState.queue
    inspectState.running = inspectState.total > 0

    self:FireCallback("REPORTS_UPDATED")
    self:FireCallback("INSPECTION_STATE_CHANGED")

    if inspectState.running then
        ProcessInspectionQueue()
    else
        FinishScan()
    end

    return true
end

function RA:ScheduleInspectionScan(reason, delay, fullRefresh)
    if self.InEncounter or InCombatLockdown() then
        resumeMissingAfterCombat = resumeMissingAfterCombat or self:HasMissingReports()
        return
    end

    pendingScanReason = reason or pendingScanReason or "scheduled"
    pendingFullRefresh = pendingFullRefresh or fullRefresh == true

    if manualPaused then
        self:FireCallback("INSPECTION_STATE_CHANGED")
        return
    end

    if scanTimer then
        scanTimer:Cancel()
    end
    if missingRetryTimer then
        missingRetryTimer:Cancel()
        missingRetryTimer = nil
    end

    scanTimer = C_Timer.NewTimer(delay or 0.35, function()
        scanTimer = nil
        local queuedReason = pendingScanReason
        local queuedFullRefresh = pendingFullRefresh
        pendingScanReason = nil
        pendingFullRefresh = false
        RA:RequestInspectionScan(queuedReason, queuedFullRefresh)
    end)
end

-- Compatibility alias retained for users of the first alpha.
function RA:RequestSync(reason)
    return self:RequestInspectionScan(reason, false)
end

function RA:FreezeReports(useExistingRoster)
    -- Encounter restrictions are already activating when ENCOUNTER_START fires.
    -- Prefer the last pre-pull roster snapshot rather than touching identity APIs
    -- again at that boundary. A manual call may still request a fresh roster.
    if not useExistingRoster then
        self:RefreshRoster()
    end

    local frozen = {}
    local rosterCount = 0
    local verifiedCount = 0
    for name, rosterInfo in pairs(self.Roster) do
        rosterCount = rosterCount + 1
        local report = self.Reports[name]
        if self:IsReportFresh(report, rosterInfo) then
            frozen[name] = CopyReport(report)
            verifiedCount = verifiedCount + 1
        elseif not self:ClassNeedsAnyInspection(rosterInfo.class) then
            -- This class needs neither capability nor raid-sort specialization
            -- data, so the player is resolved without an inspect request.
            verifiedCount = verifiedCount + 1
        end
    end

    self.FrozenRosterCount = rosterCount
    self.FrozenVerifiedCount = verifiedCount
    self.FrozenReports = frozen
    self:FireCallback("REPORTS_FROZEN")
end

function RA:UnfreezeReports()
    self.FrozenReports = nil
    self.FrozenRosterCount = nil
    self.FrozenVerifiedCount = nil
    self:FireCallback("REPORTS_UPDATED")
end

local function MakeDemoReport(name, classFile, specID, keys)
    local report = {
        name = name,
        guid = "Demo-" .. name,
        class = classFile,
        specID = specID,
        role = "HEALER",
        classRevision = RA:GetClassCatalogRevision(classFile),
        verified = true,
        source = "DEMO",
        updatedAt = GetTime(),
        capabilities = {},
        evidence = {},
    }

    for i = 1, #keys do
        local ability = RA.CatalogByKey[keys[i]]
        if ability then
            report.capabilities[ability.index] = true
        end
    end
    return report
end

RA.DemoReports = {
    ["Axe-Zuljin"] = MakeDemoReport("Axe-Zuljin", "SHAMAN", 264, {
        "spirit_link", "resto_ascendance", "wind_rush", "mana_tide",
        "tremor_totem", "poison_cleansing",
    }),
    ["Leafy-Zuljin"] = MakeDemoReport("Leafy-Zuljin", "DRUID", 105, {
        "convoke_spirits", "tranquility", "stampeding_roar", "ironbark",
        "innervate", "ursols_vortex", "combat_resurrection",
    }),
    ["Luma-Zuljin"] = MakeDemoReport("Luma-Zuljin", "PRIEST", 256, {
        "evangelism", "ultimate_penitence", "pain_suppression", "mass_dispel",
    }),
    ["Talia-Zuljin"] = MakeDemoReport("Talia-Zuljin", "PALADIN", 65, {
        "avenging_crusader", "aura_mastery", "blessing_sacrifice",
        "blessing_protection", "lay_on_hands", "combat_resurrection",
    }),
    ["Misty-Zuljin"] = MakeDemoReport("Misty-Zuljin", "MONK", 270, {
        "celestial_conduit", "invoke_yulon", "revival", "life_cocoon",
    }),
    ["Kade-Zuljin"] = MakeDemoReport("Kade-Zuljin", "WARRIOR", 72, {
        "rallying_cry", "intervene",
    }),
    ["Voidlock-Zuljin"] = MakeDemoReport("Voidlock-Zuljin", "WARLOCK", 267, {
        "demonic_gateway", "combat_resurrection",
    }),
}

function RA:GetDisplayReports()
    local db = self:GetDB()
    if db and db.demoMode and not IsInGroup() then
        return self.DemoReports, true
    end

    if self.InEncounter and self.FrozenReports then
        return self.FrozenReports, false
    end
    return self.Reports, false
end

function RA:GetVerificationStatus()
    local reports, isDemo = self:GetDisplayReports()
    if isDemo then
        local count = 0
        for _ in pairs(reports) do
            count = count + 1
        end
        return count, count, true
    end

    if self.InEncounter and self.FrozenRosterCount then
        return self.FrozenVerifiedCount or 0, self.FrozenRosterCount, false
    end

    local rosterCount = 0
    local verifiedCount = 0
    for name, rosterInfo in pairs(self.Roster) do
        rosterCount = rosterCount + 1
        if self:IsReportFresh(reports[name], rosterInfo)
            or not self:ClassNeedsAnyInspection(rosterInfo.class) then
            verifiedCount = verifiedCount + 1
        end
    end

    return verifiedCount, rosterCount, false
end

function RA:BuildAbilityOwners()
    local reports, isDemo = self:GetDisplayReports()
    local ownersByAbility = {}

    for name, report in pairs(reports) do
        local usable = report.verified
        if usable and not isDemo and not self.InEncounter then
            local rosterInfo = self.Roster[name]
            usable = rosterInfo ~= nil and self:IsReportFresh(report, rosterInfo)
        end

        if usable then
            for index in pairs(report.capabilities or {}) do
                local ability = self.CatalogByIndex[index]
                if ability then
                    ownersByAbility[index] = ownersByAbility[index] or {}
                    ownersByAbility[index][#ownersByAbility[index] + 1] = {
                        name = report.name,
                        shortName = self:GetShortName(report.name),
                        class = report.class,
                        specID = report.specID,
                        verified = true,
                        source = report.source,
                    }
                end
            end
        end
    end

    for _, owners in pairs(ownersByAbility) do
        table.sort(owners, function(a, b)
            return a.shortName < b.shortName
        end)
    end

    return ownersByAbility
end

function RA:InvalidateTrackedPlayer(unitOrName, reason, delay)
    local name
    local rosterInfo
    if type(unitOrName) == "string" and self.Roster[unitOrName] then
        name = unitOrName
        rosterInfo = self.Roster[name]
    elseif type(unitOrName) == "string" and UnitExists(unitOrName) then
        local fullName = self:GetFullUnitName(unitOrName)
        rosterInfo = fullName and self.Roster[fullName] or nil
        name = rosterInfo and fullName or nil
    end

    if not name or not rosterInfo then
        return false
    end

    local playerName = self:GetFullUnitName("player")
    if name == playerName then
        self:StoreLocalReport()
        self:FireCallback("REPORTS_UPDATED")
        return true
    end

    self.Reports[name] = nil
    self.InspectFailures[name] = nil
    SetInspectStatus(name, "QUEUED", reason or "specialization changed")
    self:FireCallback("REPORTS_UPDATED")
    self:FireCallback("INSPECTION_STATE_CHANGED")

    if self.InEncounter or InCombatLockdown() then
        resumeMissingAfterCombat = true
    else
        self:ScheduleInspectionScan(reason or "specialization changed", delay or 0.75, false)
    end
    return true
end

RA:RegisterInitializer(function()
    RA:RefreshRoster()
    RA:PruneReports()
    RA:StoreLocalReport()
end)

RA:RegisterEvent("PLAYER_LOGIN", function()
    RA:ScheduleInspectionScan("login", 1.0, false)
end)

RA:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    RA:ScheduleInspectionScan("entering world", 0.8, false)
end)

RA:RegisterEvent("GROUP_ROSTER_UPDATE", function()
    local changes = RA:RefreshRoster()
    RA:PruneReports()
    RA:StoreLocalReport()

    -- Same-GUID role/class transitions invalidate only the affected player.
    for name in pairs(changes.changed or {}) do
        local report = RA.Reports[name]
        local rosterInfo = RA.Roster[name]
        if report and rosterInfo and (report.role ~= rosterInfo.role or report.class ~= rosterInfo.class) then
            RA.Reports[name] = nil
            RA.InspectFailures[name] = nil
            SetInspectStatus(name, "QUEUED", "role or class changed")
        end
    end

    RA:FireCallback("REPORTS_UPDATED")

    if changes.addedCount > 0 or changes.changedCount > 0 then
        if RA.InEncounter or InCombatLockdown() then
            resumeMissingAfterCombat = true
        else
            RA:ScheduleInspectionScan(changes.addedCount > 0 and "new tracked player" or "tracked player changed", 0.45, false)
        end
    end
    -- Pure removals never rescan unchanged players.
end)

RA:RegisterEvent("SPELLS_CHANGED", function()
    RA:StoreLocalReport()
    RA:FireCallback("REPORTS_UPDATED")
end)

RA:RegisterEvent("TRAIT_CONFIG_UPDATED", function()
    RA:StoreLocalReport()
    RA:FireCallback("REPORTS_UPDATED")
end)

RA:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function(_, unit)
    if unit == "player" then
        RA:StoreLocalReport()
        RA:FireCallback("REPORTS_UPDATED")
    else
        -- Blizzard supplies the changed unit token. Clear only that player's
        -- cached tools and queue a targeted refresh after talents settle.
        RA:InvalidateTrackedPlayer(unit, "specialization changed", 0.75)
    end
end)

RA:RegisterEvent("READY_CHECK", function()
    -- Ready checks only fill holes. Existing GUID-matched reports are retained.
    RA:RequestInspectionScan("ready check", false)
end)

RA:RegisterEvent("INSPECT_READY", function(_, guid)
    local item = inspectState.current
    if not item or guid ~= item.guid then
        return
    end

    local success, reason, failureState = StoreInspectedReport(item)
    FinishCurrentInspection(success, reason, failureState)
    C_Timer.After(0.02, ProcessInspectionQueue)
end)

RA:RegisterEvent("PLAYER_REGEN_DISABLED", function()
    resumeMissingAfterCombat = resumeMissingAfterCombat or inspectState.running or RA:HasMissingReports()
    RA:StopInspectionScan()
end)

RA:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    if not manualPaused and not RA.InEncounter and (resumeMissingAfterCombat or RA:HasMissingReports()) then
        resumeMissingAfterCombat = false
        RA:ScheduleInspectionScan("resume missing", 0.45, false)
    end
end)

RA:RegisterEvent("ENCOUNTER_START", function()
    resumeMissingAfterCombat = resumeMissingAfterCombat or RA:HasMissingReports()
    RA:StopInspectionScan()
    RA.InEncounter = true
    RA:FreezeReports(true)
    RA:FireCallback("ENCOUNTER_STATE_CHANGED", true)
end)

RA:RegisterEvent("ENCOUNTER_END", function()
    RA.InEncounter = false
    RA:UnfreezeReports()
    RA:FireCallback("ENCOUNTER_STATE_CHANGED", false)

    -- Do not refresh successful reports after every boss. Only resume if a
    -- tracked player joined during the encounter or somebody is still missing.
    if not manualPaused and (resumeMissingAfterCombat or RA:HasMissingReports()) then
        resumeMissingAfterCombat = false
        RA:ScheduleInspectionScan("missing after encounter", 0.65, false)
    end
end)
