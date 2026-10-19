local _, RA = ...
local Adapter = {}
RA.NSRTAdapter = Adapter

-- Adapter only: Northern Sky remains separately installed and owns its engine.
-- Internal calls are deliberately limited to this reviewed stock release.
Adapter.SUPPORTED_VERSION = "12.1.32"
Adapter.SOURCE_COMMIT = "1f737b68d84f724ba690f8797dae991c1c863ab7"
Adapter.MAX_NOTE_BYTES = 65536
local state, signature, sequence = nil, nil, 0
local notifying = false
local boundAPI, deferredTimer, deferredAttempt
local applying, noteBackup, profileBackup, placementBackup, previewOwned = false, nil, nil, nil, false
local previewTimer, stopPending, refreshTimer, selectedProfile
local noteKeys = {"Reminders", "PersonalReminders", "SharedNotes", "PersonalNotes", "ActiveReminder", "ActivePersonalReminder", "StoredSharedReminder", "StoredPersonalReminder", "AutoLoadNote", "InviteList"}
local runtimeKeys = {"Reminder", "PersonalReminder", "LoadedPersonalReminder", "ReminderReceivedTime"}
local function Secret(value) return type(issecretvalue) == "function" and issecretvalue(value) end
local function String(value, maximum, empty)
    if Secret(value) or type(value) ~= "string" or #value > (maximum or 128) or (not empty and value == "") then return nil end
    return value
end
local function Copy(value, depth, seen, budget)
    if Secret(value) then error("Restricted data is unavailable.") end
    local kind = type(value)
    if kind == "nil" or kind == "boolean" then return value end
    if kind == "number" then if value ~= value or value == math.huge or value == -math.huge then error("Invalid numeric data.") end; return value end
    if kind == "string" then budget.bytes = budget.bytes + #value; if budget.bytes > 2097152 then error("NSRT data exceeds the adapter backup limit.") end; return value end
    if kind ~= "table" or (depth or 0) > 20 then error("Unsupported NSRT data.") end
    seen = seen or {}
    if seen[value] then error("Cyclic NSRT data is unsupported.") end
    seen[value] = true
    local result = {}
    for key, item in pairs(value) do
        budget.nodes = budget.nodes + 1
        if budget.nodes > 30000 then error("NSRT data exceeds the adapter backup limit.") end
        if type(key) ~= "string" and type(key) ~= "number" then error("Unsupported NSRT data key.") end
        result[key] = Copy(item, (depth or 0) + 1, seen, budget)
    end
    seen[value] = nil
    return result
end
local function Clone(value) return Copy(value, 0, {}, {nodes = 0, bytes = 0}) end
local function Equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do if not Equal(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
local function Cancel(timer) if timer and type(timer.Cancel) == "function" then timer:Cancel() end end
local function Notify()
    if notifying then return end
    notifying = true
    RA:FireCallback("NSRT_ADAPTER_CHANGED")
    notifying = false
end
local function Publish(value)
    local changed = not state or not Equal(state, value)
    state = value
    if changed then Notify() end
end
local function NativeRestriction()
    if (InCombatLockdown and InCombatLockdown()) or (IsEncounterInProgress and IsEncounterInProgress()) then return "Northern Sky changes are available outside combat and encounters." end
    if C_RestrictedActions and type(C_RestrictedActions.GetAddOnRestrictionState) == "function" and Enum and Enum.AddOnRestrictionType then
        for _, name in ipairs({"Combat", "Encounter", "Chat"}) do
            local kind = Enum.AddOnRestrictionType[name]
            if kind ~= nil then
                local ok, value = pcall(C_RestrictedActions.GetAddOnRestrictionState, kind)
                if not ok or Secret(value) or value ~= 0 then return "The client currently restricts addon changes." end
            end
        end
    end
    if C_Secrets and type(C_Secrets.ShouldAurasBeSecret) == "function" then
        local ok, value = pcall(C_Secrets.ShouldAurasBeSecret)
        if not ok or Secret(value) or value ~= false then return "Northern Sky processing is restricted by the client." end
    end
end
local function Call(target, method, ...)
    if type(target) ~= "table" or type(target[method]) ~= "function" then return false, "This Northern Sky API is unavailable." end
    return pcall(target[method], target, ...)
end
local function Version()
    if not C_AddOns or type(C_AddOns.GetAddOnMetadata) ~= "function" then return nil end
    local ok, value = pcall(C_AddOns.GetAddOnMetadata, "NorthernSkyRaidTools", "Version")
    return ok and String(value, 64) or nil
end
local function Note(value)
    if value == nil then return "" end
    local text = String(value, Adapter.MAX_NOTE_BYTES, true)
    if not text or text:find("%z") then error("The note is unavailable or exceeds 64 KiB.") end
    return text
end
local function Capture()
    local api, internal, db = _G.NSAPI, _G.NorthernSkyRaidTools, _G.NSRT
    if type(api) ~= "table" or type(internal) ~= "table" or type(db) ~= "table" then return nil, "Load Northern Sky Raid Tools before using this page." end
    local ok, personal, shared = Call(api, "GetReminderString")
    if not ok then return nil, "Northern Sky note reads are unavailable." end
    local profileOK, profile = Call(api, "GetCurrentProfileKey")
    if not profileOK or not String(profile, 128) then return nil, "Northern Sky has not finished loading its profile." end
    local dbValues = {}
    local excluded = {Profiles = true, EncounterAlerts = true, AuraTrackingSettings = true, AuraGlows = true, AuraSounds = true, NickNames = true}
    for key, value in pairs(db) do if not excluded[key] then dbValues[key] = value end end
    local runtime = {}
    for i = 1, #runtimeKeys do runtime[runtimeKeys[i]] = internal[runtimeKeys[i]] end
    local values = {version = Version(), profile = profile, personal = Note(personal), shared = Note(shared),
        storedShared = db.StoredSharedReminder, activeName = db.ActiveReminder,
        autoShare = db.ReminderSettings and db.ReminderSettings.AutoShare, runtime = runtime, dbValues = dbValues}
    return Clone(values), nil, api, internal, db
end
local function ReadCurrent()
    local ok, values, reason, api, internal, db = pcall(Capture)
    if not ok then return nil, "Northern Sky data is unavailable or exceeds safe backup limits." end
    return values, reason, api, internal, db
end
local function Observe()
    local current, reason, api, internal, db = ReadCurrent()
    if not current then return nil, reason end
    if not signature or signature.api ~= api or signature.internal ~= internal or signature.db ~= db or not Equal(signature.values, current) then
        sequence = sequence + 1
        signature = {api = api, internal = internal, db = db, values = current}
    end
    return current, nil, api, internal, db
end
local function Context() return "nsrt-" .. sequence end
local function Guard(expected, capability)
    local restriction = NativeRestriction()
    if restriction then return nil, restriction end
    local current, reason, api, internal, db = Observe()
    if not current then return nil, reason end
    if current.version ~= Adapter.SUPPORTED_VERSION then return nil, "This action supports stock Northern Sky " .. Adapter.SUPPORTED_VERSION .. "; open Northern Sky settings for other versions." end
    if applying then return nil, "A Northern Sky change is already in progress." end
    if type(expected) == "table" then expected = expected.context end
    if expected ~= Context() then return nil, "Northern Sky changed after this view loaded. Refresh before applying." end
    if capability == "note" and (type(internal.ImportReminder) ~= "function" or type(internal.SetReminder) ~= "function" or type(internal.ProcessReminder) ~= "function" or type(internal.UpdateReminderFrame) ~= "function" or type(internal.FireCallback) ~= "function" or type(db.Reminders) ~= "table" or type(db.InviteList) ~= "table") then
        return nil, "The reviewed Northern Sky note contract is unavailable."
    end
    if (capability == "note" or capability == "profile") and (not db.ReminderSettings or db.ReminderSettings.AutoShare ~= false) then
        return nil, "Turn off Northern Sky Auto Share in its own settings before applying a local note or profile."
    end
    return current, nil, api, internal, db
end
local function RefreshRuntime(internal)
    internal:ProcessReminder()
    internal:UpdateReminderFrame(true)
    internal:FireCallback("NSRT_REMINDER_CHANGED", internal.PersonalReminder, internal.Reminder)
end
local function Bind(api)
    if boundAPI == api or type(api.RegisterCallback) ~= "function" then return end
    if boundAPI and type(boundAPI.UnregisterCallback) == "function" then pcall(boundAPI.UnregisterCallback, Adapter, "NSRT_REMINDER_CHANGED") end
    local ok = pcall(api.RegisterCallback, Adapter, "NSRT_REMINDER_CHANGED", function(owner)
        if owner == Adapter and not applying then Adapter:Refresh() end
    end, Adapter)
    if ok then boundAPI = api end
end
-- Reviewed placement fields are native NSRT values; there is no scale API.
local anchors = {"TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT"}
Adapter.PlacementSections = {
    {id = "IconSettings", label = "Spell icons", sizes = {{"Width", 20, 200}, {"Height", 20, 200}}},
    {id = "BarSettings", label = "Reminder bars", sizes = {{"Width", 80, 500}, {"Height", 1, 100}}},
    {id = "TextSettings", label = "Reminder text", sizes = {{"FontSize", 5, 200}}},
    {id = "CircleSettings", label = "Reminder circles", sizes = {{"Size", 40, 200}}},
    {id = "ReminderFrame", label = "Shared note", sizes = {{"Width", 100, 2000}, {"Height", 100, 2000}, {"FontSize", 5, 200}}},
    {id = "PersonalReminderFrame", label = "Personal note", sizes = {{"Width", 100, 2000}, {"Height", 100, 2000}, {"FontSize", 5, 200}}},
    {id = "ExtraReminderFrame", label = "Extra note", sizes = {{"Width", 100, 2000}, {"Height", 100, 2000}, {"FontSize", 5, 200}}},
}
local function PlacementFields(section)
    for i = 1, #Adapter.PlacementSections do
        local entry = Adapter.PlacementSections[i]
        if entry.id == section then
            local fields = {{key = "Anchor", label = "Anchor", options = Clone(anchors)}, {key = "relativeTo", label = "Relative anchor", options = Clone(anchors)},
                {key = "xOffset", label = "Horizontal offset", min = -10000, max = 10000}, {key = "yOffset", label = "Vertical offset", min = -10000, max = 10000}}
            for j = 1, #entry.sizes do
                local size = entry.sizes[j]
                fields[#fields + 1] = {key = size[1], label = size[1], min = size[2], max = size[3]}
            end
            return fields, entry.label
        end
    end
end
local function ValidPlacement(section, settings)
    local fields = PlacementFields(section)
    if not fields or type(settings) ~= "table" then return false end
    for i = 1, #fields do
        local field, value = fields[i], settings[fields[i].key]
        if Secret(value) then return false end
        if field.options then
            local valid = false
            for j = 1, #field.options do if value == field.options[j] then valid = true end end
            if not valid then return false end
        elseif type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return false end
    end
    return true
end
function Adapter:Refresh()
    if NativeRestriction() then
        Publish({available = false, reason = NativeRestriction(), capabilities = {}, reasons = {}, canRestoreNote = false, canRestoreProfile = false})
        return false, state.reason, self:GetStatus()
    end
    local current, reason, api, internal = Observe()
    if current then Bind(api) end
    local nextState = {available = current ~= nil, reason = reason, version = current and current.version or Version(), supportedVersion = self.SUPPORTED_VERSION,
        compatible = current and current.version == self.SUPPORTED_VERSION or false, generation = sequence, context = current and Context() or nil,
        profile = current and current.profile or nil, autoShare = current and current.autoShare,
        capabilities = {}, reasons = {}, canRestoreNote = false, canRestoreProfile = false, preview = previewOwned, stopPending = stopPending == true}
    local previousState = state
    state = nextState
    local caps = state.capabilities
    caps.notes, caps.profiles = current ~= nil, current ~= nil and type(api.GetProfileKeys) == "function"
    caps.openSettings = type(_G.NSAPI) == "table" and type(_G.NSAPI.OpenConfig) == "function"
    caps.applyNote = state.compatible and type(internal.ImportReminder) == "function" and type(internal.SetReminder) == "function"
        and type(internal.ProcessReminder) == "function" and type(internal.UpdateReminderFrame) == "function" and type(internal.FireCallback) == "function" and state.autoShare == false
    caps.placement = false
    if current and type(_G.NSRT.ReminderSettings) == "table" then
        for i = 1, #self.PlacementSections do
            local section = self.PlacementSections[i].id
            if ValidPlacement(section, _G.NSRT.ReminderSettings[section]) then caps.placement = true; break end
        end
    end
    caps.setPlacement = state.compatible and caps.placement and type(internal.UpdateExistingFrames) == "function" and type(internal.UpdateReminderFrame) == "function"
        and type(internal.ProcessReminder) == "function" and type(internal.FireCallback) == "function"
    caps.applyProfile = state.compatible and state.autoShare == false and type(api.ExportProfile) == "function" and type(api.ImportProfileString) == "function"
        and type(api.SetProfile) == "function" and type(api.ProfileExists) == "function" and type(internal.SaveProfile) == "function" and caps.setPlacement
    caps.preview = false
    state.reasons.applyNote = not state.compatible and "Install the reviewed stock Northern Sky version before applying notes."
        or (state.autoShare ~= false and "Turn off Auto Share in Northern Sky settings for a local-only apply." or (not caps.applyNote and "The reviewed note APIs are unavailable." or nil))
    state.reasons.applyProfile = not caps.applyProfile and (state.autoShare ~= false and "Turn off Auto Share in Northern Sky settings before applying a local profile copy." or "The reviewed profile clone and refresh APIs are unavailable.") or nil
    state.reasons.setPlacement = not caps.setPlacement and "The reviewed placement and refresh APIs are unavailable." or nil
    state.canRestoreNote = noteBackup ~= nil and caps.applyNote and noteBackup.api == api and noteBackup.internal == internal and noteBackup.db == _G.NSRT and Equal(noteBackup.after, current)
    state.canRestoreProfile = profileBackup ~= nil and caps.applyProfile and profileBackup.api == api and profileBackup.internal == internal and profileBackup.db == _G.NSRT and Equal(profileBackup.after, current)
        and Equal(_G.NSRT.Profiles[profileBackup.original], profileBackup.originalProfile) and Equal(_G.NSRT.Profiles[profileBackup.clone], profileBackup.cloneProfile)
    state = previousState
    Publish(nextState)
    return current ~= nil, reason, self:GetStatus()
end
function Adapter:GetStatus()
    local result = Clone(state or {available = false, reason = "Refresh to detect Northern Sky.", capabilities = {}, reasons = {}})
    local reason = NativeRestriction()
    if reason then
        result.reason, result.available = reason, false
        for key in pairs(result.capabilities) do result.capabilities[key] = false end
        result.canRestoreNote, result.canRestoreProfile = false, false
    end
    local catalog = RA.AddonCatalog
    if type(catalog) == "table" and type(catalog.GetLocalReport) == "function" then
        local ok, report = pcall(catalog.GetLocalReport, catalog)
        local row = ok and type(report) == "table" and type(report.byID) == "table" and report.byID.northernsky
        if type(row) == "table" then result.installed, result.enabled, result.loaded = row.installed, row.enabled, row.loaded end
    elseif C_AddOns then
        if type(C_AddOns.GetAddOnInfo) == "function" then
            local ok, name = pcall(C_AddOns.GetAddOnInfo, "NorthernSkyRaidTools")
            if ok and not Secret(name) then result.installed = type(name) == "string" and name ~= "" end
        end
        if type(C_AddOns.IsAddOnLoaded) == "function" then
            local ok, _, loaded = pcall(C_AddOns.IsAddOnLoaded, "NorthernSkyRaidTools")
            if ok and not Secret(loaded) and type(loaded) == "boolean" then result.loaded = loaded end
        end
    end
    return result
end
function Adapter:GetNotes()
    local ok, reason = self:Refresh()
    if not ok then return false, reason end
    local current = signature.values
    return true, nil, {personal = current.personal, shared = current.shared, storedShared = current.storedShared,
        activeName = current.activeName, profile = current.profile, version = current.version, context = Context(), generation = sequence}
end
function Adapter:OpenSettings()
    local reason = NativeRestriction()
    if reason then return false, reason end
    local ok, opened = Call(_G.NSAPI, "OpenConfig")
    if not ok or opened ~= true then return false, "Northern Sky settings could not be opened yet. Refresh after it finishes loading." end
    return true
end
function Adapter:GetProfiles()
    local ok, reason = self:Refresh()
    if not ok then return false, reason end
    local success, keys = Call(_G.NSAPI, "GetProfileKeys")
    if not success or type(keys) ~= "table" then return false, "Northern Sky profile reads are unavailable." end
    local names = {}
    for key, value in pairs(keys) do
        if not String(key, 128) or value ~= true or #names >= 256 then return false, "Northern Sky returned an unsupported profile list." end
        names[#names + 1] = key
    end
    table.sort(names)
    return true, nil, {names = names, current = state.profile, context = state.context}
end
function Adapter:ApplyLocalNote(text, expected)
    if not String(text, self.MAX_NOTE_BYTES, true) or text:find("%z") then return false, "Enter a note up to 64 KiB without null bytes." end
    local before, reason, api, internal, db = Guard(expected, "note")
    if not before then return false, reason end
    if noteBackup then return false, "Restore the previous Arsenal note before applying another one." end
    local name = "RCP Arsenal Local " .. tostring(time and time() or 0) .. "-" .. tostring(sequence)
    local suffix = 0
    while db.Reminders[name] ~= nil or db.InviteList[name] ~= nil do suffix = suffix + 1; if suffix > 100 then return false, "Could not reserve a unique local note name." end; name = name .. "-" .. suffix end
    applying = true
    local ok = pcall(function()
        internal:ImportReminder(name, text, false, false, true, nil)
        if db.Reminders[name] ~= text then error("Import did not retain the exact note.") end
        internal:SetReminder(name, false)
        if internal.Reminder ~= text or db.StoredSharedReminder ~= text or db.ActiveReminder ~= name then error("Note activation did not match the requested local note.") end
    end)
    applying = false
    if not ok then
        -- Only the adapter-owned key and three shared runtime fields are rolled
        -- back; existing notes are never imported over or removed.
        db.Reminders[name], db.InviteList[name] = nil, nil
        internal.Reminder, db.StoredSharedReminder, db.ActiveReminder = before.runtime.Reminder, before.storedShared, before.activeName
        applying = true; pcall(RefreshRuntime, internal); applying = false
        self:Refresh()
        return false, "Northern Sky could not apply the local note; previous shared state was restored."
    end
    local after, readReason = Observe()
    noteBackup = {before = before, after = after, name = name, api = api, internal = internal, db = db}
    self:Refresh()
    return true, nil, {name = name, context = state.context, backup = "session"}
end
function Adapter:RestoreLastNote(expected)
    local current, reason, api, internal, db = Guard(expected, "note")
    if not current then return false, reason end
    local backup = noteBackup
    if not backup then return false, "There is no Arsenal note to restore in this session." end
    if backup.api ~= api or backup.internal ~= internal or backup.db ~= db or not Equal(current, backup.after) then return false, "Northern Sky changed since the Arsenal note was applied. Restore is blocked to preserve those changes." end
    applying = true
    internal.Reminder, db.StoredSharedReminder, db.ActiveReminder = backup.before.runtime.Reminder, backup.before.storedShared, backup.before.activeName
    db.Reminders[backup.name], db.InviteList[backup.name] = nil, nil
    local ok = pcall(RefreshRuntime, internal)
    applying = false
    if not ok then self:Refresh(); return false, "The previous shared note was restored, but Northern Sky display refresh failed." end
    noteBackup = nil
    self:Refresh()
    return true, nil, {context = state.context}
end
local function ProfileContract(api, internal, db)
    for _, method in ipairs({"ExportProfile", "ImportProfileString", "SetProfile", "ProfileExists"}) do if type(api[method]) ~= "function" then return false end end
    for _, method in ipairs({"SaveProfile", "ProcessReminder", "UpdateReminderFrame", "UpdateExistingFrames", "FireCallback"}) do if type(internal[method]) ~= "function" then return false end end
    return type(db.Profiles) == "table" and type(db.ReminderSettings) == "table"
end
local function NativeRefresh(internal)
    internal:ProcessReminder()
    internal:UpdateReminderFrame(true)
    internal:UpdateExistingFrames()
    internal:FireCallback("NSRT_REMINDER_CHANGED", internal.PersonalReminder, internal.Reminder)
end
local function QueueNativeRefresh(api, internal, db)
    Cancel(refreshTimer)
    if not C_Timer or type(C_Timer.NewTimer) ~= "function" then return end
    local expected = Context()
    refreshTimer = C_Timer.NewTimer(0, function()
        refreshTimer = nil
        if NativeRestriction() or applying then return end
        local current, _, actualAPI, actualInternal, actualDB = Observe()
        if not current or expected ~= Context() or api ~= actualAPI or internal ~= actualInternal or db ~= actualDB then return end
        applying = true; pcall(NativeRefresh, internal); applying = false
        Adapter:Refresh()
    end)
end
local function CapturePreserved(current)
    local result = {notes = {}, runtime = Clone(current.runtime), placements = {}, autoShare = current.autoShare}
    for i = 1, #noteKeys do result.notes[noteKeys[i]] = Clone(current.dbValues[noteKeys[i]]) end
    local function Walk(value, path, depth)
        if type(value) ~= "table" or depth > 12 then return end
        if value.Anchor ~= nil then
            local fields = {}
            for _, key in ipairs({"Anchor", "relativeTo", "xOffset", "yOffset", "Width", "Height", "FontSize", "Size"}) do fields[key] = Clone(value[key]) end
            result.placements[#result.placements + 1] = {path = Clone(path), fields = fields}
        end
        for key, child in pairs(value) do
            if type(child) == "table" then
                path[#path + 1] = key; Walk(child, path, depth + 1); path[#path] = nil
            end
        end
    end
    Walk(current.dbValues.ReminderSettings, {"ReminderSettings"}, 0)
    Walk(current.dbValues.Settings, {"Settings"}, 0)
    return result
end
local function RestorePreserved(preserved, internal, db)
    for i = 1, #noteKeys do local key = noteKeys[i]; db[key] = Clone(preserved.notes[key]) end
    for i = 1, #runtimeKeys do local key = runtimeKeys[i]; internal[key] = Clone(preserved.runtime[key]) end
    if type(db.ReminderSettings) ~= "table" then error("Reminder settings were not loaded.") end
    db.ReminderSettings.AutoShare = preserved.autoShare
    for i = 1, #preserved.placements do
        local placement, target = preserved.placements[i], db
        for j = 1, #placement.path do
            local key = placement.path[j]
            if type(target[key]) ~= "table" then target[key] = {} end
            target = target[key]
        end
        for _, key in ipairs({"Anchor", "relativeTo", "xOffset", "yOffset", "Width", "Height", "FontSize", "Size"}) do target[key] = Clone(placement.fields[key]) end
    end
end
function Adapter:SelectProfile(name)
    local ok, reason = self:Refresh()
    if not ok then return false, reason end
    local api, db = _G.NSAPI, _G.NSRT
    if not String(name, 128) or type(db.Profiles) ~= "table" or type(db.Profiles[name]) ~= "table" then return false, "Choose an existing Northern Sky profile." end
    local copied, profile = pcall(Clone, db.Profiles[name])
    if not copied then return false, "This profile exceeds safe adapter backup limits." end
    selectedProfile = {name = name, values = profile, context = Context(), api = api, db = db}
    return true, nil, {name = name, current = state.profile, context = Context()}
end
function Adapter:ApplyProfile(name, expected)
    local before, reason, api, internal, db = Guard(expected, "profile")
    if not before then return false, reason end
    if not ProfileContract(api, internal, db) then return false, "The reviewed clone and refresh profile APIs are unavailable." end
    if profileBackup then return false, "Restore the previous Arsenal profile copy before applying another one." end
    local selection = selectedProfile
    if not selection or selection.name ~= name or selection.context ~= Context() or selection.api ~= api or selection.db ~= db
        or not Equal(selection.values, db.Profiles[name]) then return false, "The selected source profile changed. Select it again before applying." end
    local copied, preserved = pcall(CapturePreserved, before)
    if not copied then return false, "Could not capture a complete notes and placement backup." end
    local original, cloneName = before.profile, nil
    local base = "RCP Arsenal Copy " .. tostring(time and time() or 0) .. "-" .. tostring(sequence)
    while db.Profiles[base] ~= nil do base = base .. "-2"; if #base > 120 then return false, "Could not reserve an Arsenal profile name." end end
    applying = true
    local ok, failure = pcall(function()
        local existingProfiles = {}
        for key in pairs(db.Profiles) do existingProfiles[key] = true end
        local sourceExport = api:ExportProfile(name, false)
        if not String(sourceExport, 2097152) then error("Source export was unavailable.") end
        local sourceAfterExport = Clone(db.Profiles[name])
        local originalExport = api:ExportProfile(original, false)
        if not String(originalExport, 2097152) then error("Original export was unavailable.") end
        if NativeRestriction() or _G.NSAPI ~= api or _G.NorthernSkyRaidTools ~= internal or _G.NSRT ~= db or db.CurrentProfile ~= original
            or not Equal(sourceAfterExport, db.Profiles[name]) then error("Profile identity changed before import.") end
        cloneName = api:ImportProfileString(sourceExport, base, false, true)
        if not String(cloneName, 128) or db.CurrentProfile ~= cloneName or type(db.Profiles[cloneName]) ~= "table" or existingProfiles[cloneName] or cloneName:sub(1, #base) ~= base then error("The clone was not activated with a new identity.") end
        if NativeRestriction() or _G.NSAPI ~= api or _G.NorthernSkyRaidTools ~= internal or _G.NSRT ~= db then error("Clone ownership changed.") end
        RestorePreserved(preserved, internal, db)
        if db.CurrentProfile ~= cloneName then error("Clone ownership changed.") end
        internal:SaveProfile()
        NativeRefresh(internal)
    end)
    applying = false
    if not ok then
        -- Restore only while still holding the original or the exact owned clone.
        local owned = not NativeRestriction() and _G.NSAPI == api and _G.NorthernSkyRaidTools == internal and _G.NSRT == db
            and (db.CurrentProfile == original or (cloneName and db.CurrentProfile == cloneName and cloneName ~= original and cloneName ~= name))
        local restored = false
        if owned then
            applying = true
            restored = pcall(function()
                if db.CurrentProfile ~= original and api:SetProfile(original) ~= true then error("Original profile unavailable.") end
                if db.CurrentProfile ~= original then error("Original identity unavailable.") end
                RestorePreserved(preserved, internal, db)
                internal:SaveProfile()
                NativeRefresh(internal)
            end)
            applying = false
        end
        self:Refresh()
        return false, restored and "Profile copy failed; the original profile, notes, and placement were restored."
            or "Profile copy failed after Northern Sky changed. Automatic rollback was blocked to preserve intervening changes.", {partial = not restored, clone = cloneName}
    end
    local after = Observe()
    profileBackup = {before = before, preserved = preserved, after = after, original = original, clone = cloneName,
        originalProfile = Clone(db.Profiles[original]), cloneProfile = Clone(db.Profiles[cloneName]), api = api, internal = internal, db = db}
    selectedProfile = nil
    QueueNativeRefresh(api, internal, db)
    self:Refresh()
    return true, nil, {name = cloneName, source = name, original = original, context = state.context, backup = "session"}
end
function Adapter:RestoreLastProfile(expected)
    local current, reason, api, internal, db = Guard(expected, "profile")
    if not current then return false, reason end
    local backup = profileBackup
    if not backup or not ProfileContract(api, internal, db) then return false, "There is no supported profile copy to restore in this session." end
    if backup.api ~= api or backup.internal ~= internal or backup.db ~= db or not Equal(current, backup.after)
        or not Equal(db.Profiles[backup.original], backup.originalProfile) or not Equal(db.Profiles[backup.clone], backup.cloneProfile) then
        return false, "Northern Sky changed since the Arsenal profile copy was applied. Restore is blocked to preserve those changes."
    end
    applying = true
    local ok = pcall(function()
        if api:SetProfile(backup.original) ~= true or db.CurrentProfile ~= backup.original then error("Original profile was not activated.") end
        RestorePreserved(backup.preserved, internal, db)
        internal:SaveProfile()
        NativeRefresh(internal)
    end)
    applying = false
    if not ok then self:Refresh(); return false, "Northern Sky could not completely restore the original profile; refresh and inspect its settings.", {partial = true} end
    profileBackup = nil
    QueueNativeRefresh(api, internal, db)
    self:Refresh()
    return true, nil, {name = backup.original, retainedCopy = backup.clone, context = state.context}
end
function Adapter:GetPlacement(section)
    local ok, reason = self:Refresh()
    if not ok then return false, reason end
    local fields, label = PlacementFields(section)
    local settings = _G.NSRT.ReminderSettings and _G.NSRT.ReminderSettings[section]
    if not fields or type(settings) ~= "table" then return false, "This native placement section is unavailable." end
    local values = {}
    for i = 1, #fields do
        local field, value = fields[i], settings[fields[i].key]
        if field.options then
            local valid = false
            for j = 1, #field.options do if value == field.options[j] then valid = true end end
            if not valid then return false, "This placement has an unsupported anchor; correct it in Northern Sky settings." end
        elseif Secret(value) or type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
            return false, "This placement has unavailable numeric values; correct it in Northern Sky settings."
        end
        values[field.key] = Clone(value)
    end
    return true, nil, {section = section, label = label, fields = fields, values = values, context = Context(), profile = state.profile}
end
function Adapter:SetPlacement(section, values, expected)
    local before, reason, api, internal, db = Guard(expected, "placement")
    if not before then return false, reason end
    if type(internal.UpdateExistingFrames) ~= "function" or type(internal.UpdateReminderFrame) ~= "function" or type(internal.ProcessReminder) ~= "function" or type(internal.FireCallback) ~= "function" then return false, "Northern Sky display refresh APIs are unavailable." end
    local fields = PlacementFields(section)
    local target = db.ReminderSettings and db.ReminderSettings[section]
    if not fields or type(target) ~= "table" or Secret(values) or type(values) ~= "table" then return false, "Choose a supported native placement section." end
    local allowed, changed = {}, {}
    for i = 1, #fields do allowed[fields[i].key] = fields[i] end
    for key, value in pairs(values) do
        local field = allowed[key]
        if not field or Secret(value) then return false, "Only the displayed native placement fields can be changed." end
        if field.options then
            local valid = false
            for j = 1, #field.options do if value == field.options[j] then valid = true end end
            if not valid then return false, "Choose a valid native anchor." end
        elseif type(value) ~= "number" or value ~= value or value < field.min or value > field.max then return false, "Enter placement values within the displayed limits." end
        changed[key] = value
    end
    local previous = Clone(target)
    applying = true
    local ok = pcall(function() for key, value in pairs(changed) do target[key] = value end; NativeRefresh(internal) end)
    applying = false
    if not ok then
        local owned = _G.NSRT == db and _G.NorthernSkyRaidTools == internal and db.CurrentProfile == before.profile and db.ReminderSettings[section] == target
        if owned then for key in pairs(changed) do target[key] = previous[key] end; applying = true; pcall(NativeRefresh, internal); applying = false end
        self:Refresh()
        return false, owned and "Placement refresh failed; prior values were restored." or "Placement changed during refresh; rollback was blocked to preserve those changes.", {partial = not owned}
    end
    Observe()
    QueueNativeRefresh(api, internal, db)
    self:Refresh()
    return true, nil, {section = section, context = state.context}
end
function Adapter:PreviewPlacement() return false, "Use the Arsenal sample or Northern Sky settings to preview placement." end
function Adapter:StopPreview() Cancel(previewTimer); previewTimer = nil; previewOwned, stopPending = false, false; return true end

local function Defer()
    Cancel(deferredTimer)
    deferredTimer = nil
    deferredAttempt = 0
    if type(_G.NSAPI) ~= "table" and type(_G.NorthernSkyRaidTools) ~= "table" then Adapter:Refresh(); return end
    local function Try()
        deferredTimer = nil
        if NativeRestriction() then return end
        local ok = Adapter:Refresh()
        if ok or deferredAttempt >= 5 or not C_Timer or type(C_Timer.NewTimer) ~= "function" then return end
        deferredAttempt = deferredAttempt + 1
        deferredTimer = C_Timer.NewTimer(math.min(4, 0.25 * 2 ^ (deferredAttempt - 1)), Try)
    end
    Try()
end
RA:RegisterInitializer(Defer)
RA:RegisterEvent("ADDON_LOADED", function(_, name) if name == "NorthernSkyRaidTools" or name == "NorthernSkyRaidTools_UI" then Defer() end end)
RA:RegisterEvent("PLAYER_ENTERING_WORLD", Defer)
RA:RegisterEvent("PLAYER_REGEN_ENABLED", Defer)
RA:RegisterEvent("PLAYER_REGEN_DISABLED", function() Cancel(deferredTimer); Cancel(refreshTimer); deferredTimer = nil; refreshTimer = nil; Adapter:StopPreview(); Notify() end)
RA:RegisterEvent("ENCOUNTER_START", function() Cancel(deferredTimer); Cancel(refreshTimer); deferredTimer = nil; refreshTimer = nil; Adapter:StopPreview(); Notify() end)
