local _, RA = ...
local Setup = {}
RA.Setup = Setup
local draft, original, originalProfile, returnTab, firstUse, invalidated
-- The review owns only these masters. Detailed preferences stay on their pages.
local fields = {"autoRes", "reminder", "quickBar", "hud"}
local function Secret(value) return type(issecretvalue) == "function" and issecretvalue(value) end
local function Copy(value) local out = {}; for key, item in pairs(value or {}) do out[key] = item end; return out end
local function Metadata()
    if not RaidArsenalDB then return nil end
    if type(RaidArsenalDB.setup) ~= "table" then RaidArsenalDB.setup = {completed = RA.WasExistingInstall == true, role = "RAIDER"} end
    return RaidArsenalDB.setup
end
local function Values()
    local db = RA:GetDB()
    if not db then return nil end
    return {autoRes = db.personalTools.autoRes == true, reminder = db.personalTools.consumableReminder == true,
        quickBar = db.leaderToolbox.enabled == true, hud = db.hudEnabled == true}
end
function Setup:IsFirstRunPending()
    local state = Metadata()
    return state and state.completed ~= true and state.presented ~= true or false
end
function Setup:PresentIntroduction() local state = Metadata(); if state then state.presented = true end end
function Setup:IsIntroduction() local state = Metadata(); return state and state.completed ~= true or false end
function Setup:GetRole() local state = Metadata(); return state and state.role == "LEADER" and "LEADER" or "RAIDER" end
function Setup:GetCurrent(key) return (Values() or {})[key] end
function Setup:Begin(previousTab, restart)
    if draft and not restart then return true end
    local destination, mode = returnTab, firstUse
    original, originalProfile = Values(), RA:GetDB()
    if not original then return false, "Profile unavailable." end
    draft = Copy(original); draft.role = self:GetRole(); invalidated = nil
    local meta = Metadata(); meta.presented = true
    firstUse = mode == nil and self:IsIntroduction() or mode
    returnTab = destination or (type(previousTab) == "string" and previousTab ~= "SETUP" and previousTab) or "GENERAL"
    if firstUse then returnTab = "GENERAL" end
    return true
end
function Setup:Reload() if not draft then return false end; return self:Begin(returnTab, true) end
function Setup:IsFirstUseDraft() return firstUse == true end
function Setup:Get(key) return (draft or Values() or {})[key] end
function Setup:GetDraft() return draft and Copy(draft) end
function Setup:HasDraft() return draft ~= nil end
function Setup:Set(key, value)
    if not draft or Secret(key) or Secret(value) then return false, "Open Review choices first." end
    if key == "role" then
        if value ~= "RAIDER" and value ~= "LEADER" then return false end
    elseif (key ~= "autoRes" and key ~= "reminder" and key ~= "quickBar" and key ~= "hud") or type(value) ~= "boolean" then return false end
    draft[key] = value; RA:FireCallback("SETUP_CHANGED"); return true
end
function Setup:GetSummary()
    local value, selected = draft or Values() or {}, {}
    for _, row in ipairs({{"autoRes","Normal resurrection"},{"reminder","Consumable reminder"},{"quickBar","Quick Bar"},{"hud","Available Cooldowns"}}) do
        if value[row[1]] then selected[#selected + 1] = row[2] end
    end
    return #selected, #selected > 0 and table.concat(selected, " · ") or "No optional tools selected. Team-check replies stay available."
end
function Setup:GetConflict()
    if not draft then return nil end
    if invalidated or RA:GetDB() ~= originalProfile then return "Settings changed elsewhere. Reload choices to replace this draft." end
    local current = Values()
    for _, key in ipairs(fields) do
        if current[key] ~= original[key] then return "Settings changed elsewhere. Reload choices to replace this draft." end
    end
end
local function Clear()
    local destination = returnTab or "GENERAL"
    draft, original, originalProfile, returnTab, firstUse, invalidated = nil, nil, nil, nil, nil, nil
    local meta = Metadata(); if meta then meta.returnTab = nil end -- retire legacy persisted editor routing
    RA:FireCallback("SETUP_CHANGED")
    return destination
end
function Setup:Cancel()
    if not draft then return false, "Open Review choices first." end
    return true, Clear()
end
function Setup:Skip()
    local meta = Metadata()
    if not meta then return false end
    meta.completed, meta.presented = true, true
    Clear()
    return true, "GENERAL"
end
function Setup:Dismiss()
    if self:IsIntroduction() then return self:Skip() end
    if draft then return self:Cancel() end
    return true
end
function Setup:Save()
    if not draft then return false, "Open Review choices first." end
    if InCombatLockdown() or RA.InEncounter or (IsEncounterInProgress and IsEncounterInProgress()) then return false, "Save after combat or the encounter. Your choices are kept." end
    local conflict = self:GetConflict(); if conflict then return false, conflict end
    local current, db = Values(), RA:GetDB()
    db.personalTools.autoRes, db.personalTools.consumableReminder = draft.autoRes, draft.reminder
    -- Explicit OFF -> ON retains the Quick Bar activation default. An unchanged
    -- enabled master does not touch a later provider-coverage preference.
    if draft.quickBar ~= current.quickBar then RA:SetQuickBarEnabled(draft.quickBar) end
    if draft.hud ~= current.hud then RA:SetHUDEnabled(draft.hud) end
    if draft.autoRes ~= current.autoRes or draft.reminder ~= current.reminder then RA.PersonalTools:Refresh(draft.reminder ~= current.reminder) end
    for _, row in ipairs({{"autoRes","autoRes"},{"reminder","consumableReminder"}}) do
        if draft[row[1]] ~= current[row[1]] then RA:FireCallback("PERSONAL_TOOLS_CHANGED", row[2]) end
    end
    local meta = Metadata(); meta.completed, meta.role = true, draft.role
    return true, Clear()
end
RA:RegisterInitializer(Metadata)
local function Invalidate()
    if draft then invalidated = true; RA:FireCallback("SETUP_CHANGED") end
end
RA:RegisterCallback("PROFILE_RESET", function(reason) if reason == "IMPORT" then Invalidate() else Clear() end end)
RA:RegisterCallback("PROFILE_IMPORTED", Invalidate)
