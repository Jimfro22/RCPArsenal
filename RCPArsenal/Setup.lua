local _, RA = ...
local Setup = {}
RA.Setup = Setup
local draft, original, originalProfile, returnTab
local fields = {"autoRes", "reminder", "threshold", "sound", "glow", "quickBar", "missing", "hud", "leftClick"}
local function Secret(value) return type(issecretvalue) == "function" and issecretvalue(value) end
local function Copy(value) local out = {}; for key, item in pairs(value or {}) do out[key] = item end; return out end
local function Metadata()
    if not RaidArsenalDB then return nil end
    if type(RaidArsenalDB.setup) ~= "table" then
        RaidArsenalDB.setup = {completed = RA.WasExistingInstall == true, role = "RAIDER"}
    end
    return RaidArsenalDB.setup
end
local function Values()
    local db = RA:GetDB()
    if not db then return nil end
    local personal, toolbox = db.personalTools, db.leaderToolbox
    return {autoRes = personal.autoRes == true, reminder = personal.consumableReminder == true,
        threshold = personal.healthThreshold, sound = personal.reminderSound ~= false, glow = personal.reminderStoneGlow ~= false,
        quickBar = toolbox.enabled == true, missing = toolbox.showMissing ~= false,
        hud = db.hudEnabled == true, leftClick = db.actions.leftClickMode or "OFF"}
end
function Setup:IsFirstRunPending()
    local state = Metadata()
    return state and state.completed ~= true and state.presented ~= true or false
end
function Setup:Begin(previousTab, restart)
    if restart then draft = nil end
    if draft then return true end
    original, originalProfile = Values(), RA:GetDB()
    if not original then return false, "Profile unavailable." end
    draft = Copy(original)
    local meta = Metadata()
    meta.presented = true
    draft.role = meta.role == "LEADER" and "LEADER" or "RAIDER"
    returnTab = type(previousTab) == "string" and previousTab ~= "SETUP" and previousTab or meta.returnTab or "ADDONS"
    meta.returnTab = returnTab
    return true
end
function Setup:Get(key)
    local values = draft or Values() or {}
    return values[key]
end
function Setup:GetDraft() return draft and Copy(draft) end
function Setup:HasDraft() return draft~=nil end
function Setup:Set(key, value)
    if not draft or Secret(key) or Secret(value) then return false, "Open Setup first." end
    if key == "role" then
        if value ~= "RAIDER" and value ~= "LEADER" then return false end
    elseif key == "leftClick" then
        if value ~= "OFF" and value ~= "WHISPER" and value ~= "SAY" then return false end
    elseif key == "threshold" then
        if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return false end
        value = math.floor(math.max(1, math.min(99, value)) + 0.5)
    elseif (key ~= "autoRes" and key ~= "reminder" and key ~= "sound" and key ~= "glow" and key ~= "quickBar"
        and key ~= "missing" and key ~= "hud") or type(value) ~= "boolean" then return false end
    draft[key] = value
    RA:FireCallback("SETUP_CHANGED")
    return true
end
function Setup:GetSummary()
    local value = draft or Values() or {}
    local selected = {}
    if value.autoRes then selected[#selected + 1] = "Normal resurrection" end
    if value.reminder then
        local personal = RA:GetDB().personalTools
        local sound = RA.ReminderSounds:Get(personal.reminderSoundChoice)
        selected[#selected + 1] = "Reminder at " .. tostring(value.threshold) .. "%"
            .. (value.sound and ("; sound: " .. (sound and sound.label or "Sound 6") .. " / " .. (personal.reminderSoundChannel or "Master")) or "; sound off")
            .. (value.glow and "; icon glow at ≤35%" or "; glow off")
    end
    if value.quickBar then selected[#selected + 1] = "Quick Bar; provider classes " .. (value.missing and "on" or "off") end
    if value.hud then selected[#selected + 1] = "Available Cooldowns: HUD + inspection; tile click " .. value.leftClick end
    return #selected, #selected > 0 and table.concat(selected, "\n") or "No optional tools selected. Team-check replies stay available."
end
local function Complete()
    local meta = Metadata()
    meta.completed, meta.role = true, draft.role
    meta.returnTab = nil
    local tab = returnTab
    draft, original, originalProfile, returnTab = nil, nil, nil, nil
    return tab
end
function Setup:Skip()
    if not draft then return false, "Open Setup first." end
    return true, Complete()
end
function Setup:Save()
    if not draft then return false, "Open Setup first." end
    if InCombatLockdown() or RA.InEncounter or (IsEncounterInProgress and IsEncounterInProgress()) then return false, "Keep these choices; save deliberately after combat or the encounter." end
    local current, db = Values(), RA:GetDB()
    if db ~= originalProfile then return false, "Settings changed elsewhere. Skip this draft, then reopen Setup to review current choices." end
    for _, key in ipairs(fields) do
        if current[key] ~= original[key] then return false, "Settings changed elsewhere. Skip this draft, then reopen Setup to review current choices." end
    end
    local personal, toolbox = db.personalTools, db.leaderToolbox
    personal.autoRes, personal.consumableReminder, personal.healthThreshold = draft.autoRes, draft.reminder, draft.threshold
    personal.reminderSound, personal.reminderStoneGlow = draft.sound, draft.glow
    db.actions.leftClickMode = draft.leftClick
    db.actions.whisperEnabled, db.actions.sayEnabled = draft.leftClick == "WHISPER", draft.leftClick == "SAY"
    toolbox.showMissing = draft.missing
    if draft.quickBar ~= current.quickBar then RA:SetQuickBarEnabled(draft.quickBar, draft.missing)
    elseif draft.missing ~= current.missing and RA.RaidLeaderToolbox then RA.RaidLeaderToolbox:Refresh() end
    if draft.hud ~= current.hud then RA:SetHUDEnabled(draft.hud)
    elseif draft.leftClick ~= current.leftClick and RA.RearmSecureActions then RA:RearmSecureActions() end
    if draft.autoRes ~= current.autoRes or draft.reminder ~= current.reminder or draft.threshold ~= current.threshold or draft.glow ~= current.glow then
        RA.PersonalTools:Refresh(draft.reminder ~= current.reminder)
    end
    for _,change in ipairs({{"sound","reminderSound"},{"glow","reminderStoneGlow"},{"reminder","consumableReminder"},{"autoRes","autoRes"},{"threshold","healthThreshold"}}) do
        if draft[change[1]] ~= current[change[1]] then RA:FireCallback("PERSONAL_TOOLS_CHANGED",change[2]) end
    end
    return true, Complete()
end
RA:RegisterInitializer(Metadata)
RA:RegisterCallback("PROFILE_RESET", function() draft, original, originalProfile, returnTab = nil, nil, nil, nil end)
