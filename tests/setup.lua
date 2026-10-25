-- Focused Setup state/save contract, actual Setup.lua + actual Core setters.
-- Run from a repository root, or pass Core.lua and Setup.lua snapshot paths.
-- Offline only: native protected input/visual/audio behavior is not simulated.
local corePath = arg[1] or 'RCPArsenal/Core.lua'
local setupPath = arg[2] or 'RCPArsenal/Setup.lua'
local checks, combat, encounter = 0, false, false
local frames, calls, notifications, RA, db, setup
local secret = {}
local function check(v, message) checks = checks + 1; assert(v, message) end
local function clone(value)
    if type(value) ~= 'table' then return value end
    local out = {}; for key, item in pairs(value) do out[key] = clone(item) end; return out
end
local function equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end
    for key, value in pairs(a) do if not equal(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
function issecretvalue(value) return rawequal(value, secret) end
function InCombatLockdown() return combat end
function IsEncounterInProgress() return encounter end
function CreateFrame()
    local frame = {scripts = {}}
    function frame:RegisterEvent() end
    function frame:UnregisterEvent() end
    function frame:SetScript(key, fn) self.scripts[key] = fn end
    frames[#frames + 1] = frame
    return frame
end
for _, name in ipairs({'PlaySound', 'PlaySoundFile', 'SendAddonMessage', 'SendChatMessage', 'NotifyInspect', 'AcceptResurrect', 'UseItemByName'}) do
    _G[name] = function() error('Setup must not directly perform optional work: ' .. name) end
end
C_ChatInfo = {SendAddonMessage = function() error('Setup sent network traffic') end}
C_Timer = {After = function() error('Setup queued delayed work') end, NewTimer = function() error('Setup queued timer') end}
local function record(name, value, extra) calls[#calls + 1] = {name, value, extra} end
local function count(name)
    local n = 0; for _, call in ipairs(calls) do if call[1] == name then n = n + 1 end end; return n
end
local function options()
    local out = {}; for _, option in ipairs(notifications) do out[option] = (out[option] or 0) + 1 end; return out
end
local function fresh(existing, configure)
    combat, encounter, frames, calls, notifications = false, false, {}, {}, {}
    RA = {}
    assert(loadfile(corePath))('RCPArsenal', RA)
    RaidArsenalDB = {profile = RA:CreateDefaultProfile()}
    RA.WasExistingInstall = existing == true
    db = RaidArsenalDB.profile
    if configure then configure(db) end
    RA.PersonalTools = {Refresh = function(_, readiness) record('personalRefresh', readiness) end}
    RA.RaidLeaderToolbox = {Refresh = function() record('quickRefresh') end}
    RA.ReminderSounds = {Get = function(_, id) return {label = id == 'sound_6' and 'Sound 6' or 'Chosen sound'} end}
    function RA:ScheduleInspectionScan(reason, delay, force) record('scan', reason, delay) end
    function RA:StopInspectionScan() record('stopScan') end
    function RA:RefreshHUD() record('hudRefresh') end
    function RA:RearmSecureActions() record('rearm') end
    function RA:Print(message) error('Unexpected callback failure: ' .. message) end
    local actualHUD, actualQuickBar = RA.SetHUDEnabled, RA.SetQuickBarEnabled
    function RA:SetHUDEnabled(value) record('hudSetter', value); return actualHUD(self, value) end
    function RA:SetQuickBarEnabled(value, missing) record('quickSetter', value, missing); return actualQuickBar(self, value, missing) end
    RA:RegisterCallback('PERSONAL_TOOLS_CHANGED', function(option) notifications[#notifications + 1] = option end)
    RA:RegisterCallback('TOOLS_CHANGED', function() record('toolsCallback') end)
    assert(loadfile(setupPath))('RCPArsenal', RA)
    setup = RA.Setup
end
local function quiet(message)
    check(#calls == 0 and #notifications == 0, message .. ': optional activation/refresh/scan/audio callback occurred')
end
local function event(name)
    for _, frame in ipairs(frames) do if frame.scripts.OnEvent then frame.scripts.OnEvent(frame, name) end end
end
fresh(false)
check(setup:IsFirstRunPending(),'Fresh General routing missing')
setup:PresentIntroduction()
check(not setup:IsFirstRunPending() and not setup:HasDraft(),'General visit staged a draft')
check(setup.Begin==nil and setup.Set==nil and setup.Save==nil and setup.Reload==nil,'Retired draft/save API remains active')
local baseline=clone(db)
RA:FireCallback('PROFILE_IMPORTED');RA:FireCallback('PROFILE_RESET')
check(equal(db,baseline) and not setup:HasDraft(),'Profile lifecycle applied staged choices')
quiet('Metadata lifecycle')
fresh(true)
check(not setup:IsFirstRunPending() and setup:GetRole()=='RAIDER','Existing install changed neutral routing/role')
RaidArsenalDB.setup={completed=true,role='LEADER',returnTab='SETUP'}
check(setup:GetRole()=='LEADER' and RaidArsenalDB.setup.returnTab==nil,'Saved role lost or legacy editor route retained')
check(not setup:HasDraft() and not setup:IsFirstRunPending(),'Saved metadata created an editor')
quiet('Existing metadata')
RA.ReminderSounds=nil
local defaults=RA:CreateDefaultProfile()
check(not defaults.personalTools.autoRes and not defaults.personalTools.autoResInCombat,'Optional resurrection defaults changed')
for _,value in ipairs({false,1,'true',secret,{}}) do
    local profile=RA:CreateDefaultProfile();profile.personalTools.autoRes=true;profile.personalTools.autoResInCombat=value
    RA:NormalizeProfile(profile)
    check(profile.personalTools.autoRes and profile.personalTools.autoResInCombat==false,'Invalid child inherited parent permission')
end
local profile=RA:CreateDefaultProfile();profile.personalTools.autoResInCombat=true
RA:NormalizeProfile(profile)
check(not profile.personalTools.autoRes and profile.personalTools.autoResInCombat,'Stored child altered parent or lost explicit choice')
print('PASS: '..checks..' settings metadata and profile assertions')
