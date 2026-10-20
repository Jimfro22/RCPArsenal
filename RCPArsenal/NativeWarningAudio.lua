local _, RA = ...
local Audio = {}
RA.NativeWarningAudio = Audio

-- Native warning proxy, normally 35%; independent of the visual's threshold.
-- No health/alpha reads, polling, inventory, native mutation or copied warning logic.
local records = setmetatable({}, {__mode = "k"})
local bound, attempted, parentShownHook, parentHiddenHook
local worldReady = false
local state, wasEligible = "WAIT_CLEAR", false
local automaticHandle, previewHandle
local routeLabel = "Master"
local statusBody = "Reminder is off."
local status = routeLabel .. " - " .. statusBody
local Reconcile
local function Secret(value) return type(issecretvalue) == "function" and issecretvalue(value) end
local function Boolean(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if not ok or Secret(value) or type(value) ~= "boolean" then return nil end
    return value
end
local function MethodBoolean(object, method)
    if Secret(object) or object == nil then return nil end
    return Boolean(function() return object[method](object) end)
end
local function Handle(value)
    if Secret(value) or type(value) ~= "number" or value ~= value or value <= 0
        or value == math.huge or value ~= math.floor(value) then return nil end
    return value
end
local function StopHandle(handle)
    if handle and type(StopSound) == "function" then pcall(StopSound, handle) end
end
local function StopAutomatic()
    local handle = automaticHandle
    automaticHandle = nil
    StopHandle(handle)
end
local function StopPreview()
    local handle = previewHandle
    previewHandle = nil
    StopHandle(handle)
end
local function SetStatus(body)
    statusBody = body
    status = routeLabel .. " - " .. body
end
local function Selection()
    local sounds = RA.ReminderSounds
    if not sounds then return nil, "Master" end
    local db = type(RA.GetDB) == "function" and RA:GetDB()
    local settings = type(db) == "table" and type(db.personalTools) == "table" and db.personalTools or {}
    local channel = sounds:NormalizeChannel(settings.reminderSoundChannel)
    routeLabel = sounds:ChannelLabel(channel)
    SetStatus(statusBody)
    return sounds:Get(sounds:NormalizeID(settings.reminderSoundChoice)), channel,
        not Secret(settings.reminderSoundWhenEffectsMuted) and settings.reminderSoundWhenEffectsMuted == true
end
local function Volume(name)
    if type(GetCVar) ~= "function" then return nil end
    local ok, value = pcall(GetCVar, name)
    if not ok or Secret(value) or type(value) ~= "string" then return nil end
    value = tonumber(value)
    if not value or value ~= value or value < 0 or value > 1 then return nil end
    return value
end
local function KnownMute(channel, allowEffectsMuted)
    if Boolean(GetCVarBool, "Sound_EnableAllSound") == false then return "WoW sound is disabled." end
    if Volume("Sound_MasterVolume") == 0 then return "WoW master volume is zero." end
    if channel == "Master" and not allowEffectsMuted and Boolean(GetCVarBool, "Sound_EnableSFX") == false then
        return "Game effects are muted; alert permission is off."
    end
    if channel == "SFX" then
        if Boolean(GetCVarBool, "Sound_EnableSFX") == false then return "WoW Sound Effects are disabled." end
        if Volume("Sound_SFXVolume") == 0 then return "WoW Sound Effects volume is zero." end
    end
end
local function PlayAlert()
    local entry, channel, allowEffectsMuted = Selection()
    if type(issecretvalue) ~= "function" or not entry then
        return false, nil, routeLabel .. " - sound selection unavailable."
    end
    local muted = KnownMute(channel, allowEffectsMuted)
    if muted then return false, nil, routeLabel .. " - " .. muted end
    local api, value
    if entry.kind == "kit" then api, value = PlaySound, entry.kitID
    elseif entry.kind == "file" then api, value = PlaySoundFile, entry.path end
    if type(api) ~= "function" then return false, nil, routeLabel .. " - playback unavailable in this client." end
    -- Both paths use the same explicit, sanitized route. No CVar/volume writes.
    local ok, playing, handle = pcall(api, value, channel)
    if not ok or Secret(playing) or playing ~= true then
        return false, nil, routeLabel .. " - playback request failed."
    end
    return true, Handle(handle)
end
local function Disarm(reason)
    state, wasEligible = "WAIT_CLEAR", false
    if reason then SetStatus(reason)
    elseif RA.PersonalTools:IsNativeSoundOptedIn() then SetStatus("Sound enabled - native warning unavailable.")
    else
        local _, offReason = RA.PersonalTools:GetNativeSoundEligibility()
        SetStatus(offReason or "Sound is off.")
    end
    StopAutomatic()
end
local function NativeContext()
    if Boolean(GetCVarBool, "doNotFlashLowHealthWarning") ~= false then return false end
    if type(GetUIPanel) ~= "function" then return false end
    local ok, panel = pcall(GetUIPanel, "fullscreen")
    if not ok or Secret(panel) or panel ~= nil then return false end
    if MethodBoolean(UIParent, "IsVisible") ~= true then return false end
    for index = 1, 2 do
        local frame
        if index == 1 then frame = CinematicFrame else frame = MovieFrame end
        if Secret(frame) then return false end
        if frame ~= nil and MethodBoolean(frame, "IsShown") ~= false then return false end
    end
    return true
end
local function ParentHidden()
    -- Do not treat ancestor OnHide as an own-shown=false warning clear.
    Disarm()
end
local function ParentShown()
    -- Blizzard may evaluate its warning after this callback. A pre-update
    -- hidden state is not a new clear; wait for a later eligible observation.
    Disarm()
end
local function ParentHooks()
    if Secret(EventRegistry) or EventRegistry == nil then return false end
    if not parentHiddenHook then
        local ok = pcall(function() EventRegistry:RegisterCallback("UI.TopLevelParentHidden", ParentHidden, Audio) end)
        parentHiddenHook = ok
    end
    if not parentShownHook then
        local ok = pcall(function() EventRegistry:RegisterCallback("UI.TopLevelParentShown", ParentShown, Audio) end)
        parentShownHook = ok
    end
    return parentHiddenHook and parentShownHook
end
local function Bind(allowRetry)
    local frame = LowHealthFrame
    if Secret(frame) or frame == nil then
        if not attempted or allowRetry then attempted = true end
        return false
    end
    if bound and bound.frame == frame and bound.active then return true end
    if attempted and not allowRetry then return false end
    attempted = true
    local record = records[frame]
    if not record then
        record = { frame = frame, active = false }
        records[frame] = record
        local function Changed()
            -- Partial/old bindings stay inert. Disabled hooks do no native work.
            if record.active and record == bound then Reconcile(true, false, false) end
        end
        local show = Boolean(function() return frame:HookScript("OnShow", Changed) end)
        local hide = Boolean(function() return frame:HookScript("OnHide", Changed) end)
        record.complete = show == true and hide == true
    end
    if not record.complete or not ParentHooks() then return false end
    if bound then bound.active = false end
    record.active, bound = true, record
    state, wasEligible = "WAIT_CLEAR", false
    return true
end

Reconcile = function(allowPlayback, allowRetry, reset)
    -- Hook setup depends only on explicit opt-in, not combat/life playback
    -- eligibility. An In-combat-only profile can bind safely before combat.
    if not RA.PersonalTools:IsNativeSoundOptedIn() then
        local _, reason = RA.PersonalTools:GetNativeSoundEligibility()
        Disarm(reason); return
    end
    if type(issecretvalue) ~= "function" then Disarm(); return end
    if reset then Disarm() end
    if not bound or not bound.active then
        if not attempted or allowRetry then
            if not Bind(allowRetry) then Disarm(); return end
        else Disarm(); return end
    elseif Secret(LowHealthFrame) or LowHealthFrame ~= bound.frame then
        bound.active = false
        bound = nil
        Disarm()
        if allowRetry and Bind(true) then Reconcile(false, false, true) end
        return
    end
    if not worldReady then Disarm(); return end
    local eligible, reason = RA.PersonalTools:GetNativeSoundEligibility()
    if not eligible then Disarm(reason); return end
    if not NativeContext() then Disarm(); return end
    local shown = MethodBoolean(bound.frame, "IsShown")
    local visible = MethodBoolean(bound.frame, "IsVisible")
    if shown == nil or visible == nil then Disarm(); return end
    if shown ~= visible then Disarm(); return end
    -- Eligibility transitions are reconciled inside native callbacks too, so
    -- native/addon event-handler ordering cannot create a catch-up alert.
    if not wasEligible then state = "WAIT_CLEAR" end
    wasEligible = true
    SetStatus("Sound enabled - native warning.")
    if shown == false then
        StopAutomatic()
        state = "ARMED" -- A public, eligible own-warning clear; never alpha.
    elseif state == "ARMED" then
        state = "CONSUMED" -- Consume BEFORE playback, including any failure.
        if allowPlayback then
            StopAutomatic()
            local playing, handle = PlayAlert()
            if playing then automaticHandle = handle end
        end
    else
        state = "CONSUMED" -- Initial/already-shown/suppressed episode is quiet.
    end
end

function Audio:Preview()
    StopPreview()
    local playing, handle, feedback = PlayAlert()
    if playing then
        previewHandle = handle
        return true, routeLabel .. " - preview requested."
    end
    return false, feedback
end
function Audio:GetStatusText() return status end -- Cached only; rendering does no native work.

RA:RegisterInitializer(function() Selection(); Reconcile(false, true, true) end)
RA:RegisterCallback("PERSONAL_TOOLS_CHANGED", function(option)
    if Secret(option) or type(option) ~= "string" then return end
    if option == "reminderSoundChoice" or option == "reminderSoundChannel" or option == "reminderSoundWhenEffectsMuted" then Selection(); return end
    if option == "consumableReminder" or option == "reminderSound" then Reconcile(false, true, true)
    elseif option == "reminderCombat" then Reconcile(false, false, true)
    elseif option == "reminderSupply" then Reconcile(false, false, false) end
end)
RA:RegisterCallback("PROFILE_RESET", function() Selection(); Reconcile(false, false, true) end)
RA:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    worldReady = true
    Reconcile(false, true, true)
    -- The native world handler can precede or follow ours. Binding/status
    -- baseline is silent; its pre-update hidden state cannot arm an episode.
    state, wasEligible = "WAIT_CLEAR", false
    StopAutomatic()
end)
for _, event in ipairs({"PLAYER_ALIVE", "PLAYER_DEAD", "PLAYER_UNGHOST"}) do
    RA:RegisterEvent(event, function() Reconcile(false, false, true) end)
end
for _, event in ipairs({"PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED"}) do
    RA:RegisterEvent(event, function() Reconcile(false, false, false) end)
end
RA:RegisterEvent("CVAR_UPDATE", function(_, name)
    if Secret(name) or type(name) ~= "string" then return end
    name = name:lower()
    if name == "donotflashlowhealthwarning" or name == "screenedgeflash" then
        -- Native processing may run before or after this handler. Do not arm
        -- from its stale pre-update hidden state; await a readable clear.
        Disarm()
    end
end)
