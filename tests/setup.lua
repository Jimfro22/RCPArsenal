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
check(setup:IsFirstRunPending(),'Fresh introduction missing')
setup:PresentIntroduction();check(not setup:IsFirstRunPending() and not setup:HasDraft(),'Introduction began review')
local baseline=clone(db)
check(setup:Begin('MYTOOLS') and setup:IsFirstUseDraft(),'First review failed')
for key,value in pairs({role='LEADER',autoRes=true,reminder=true,quickBar=true,hud=true}) do check(setup:Set(key,value),'Could not stage '..key) end
check(setup:GetSummary()==4 and equal(db,baseline),'Staging applied settings')
quiet('Staging')
local copy=setup:GetDraft();copy.hud=false;check(setup:Get('hud'),'Draft copy mutable')
check(setup:Begin('ADDONS') and setup:Get('hud'),'Begin restarted draft')
local ok,destination=setup:Save()
check(ok and destination=='GENERAL' and not setup:HasDraft() and RaidArsenalDB.setup.role=='LEADER','First Save metadata/return failed')
check(db.hudEnabled and db.personalTools.autoRes and db.personalTools.consumableReminder and db.leaderToolbox.enabled,'Four masters not applied')
check(count('quickSetter')==1 and count('hudSetter')==1 and count('scan')==1 and count('personalRefresh')==1,'Activation not transition-only')
check(db.personalTools.healthThreshold==baseline.personalTools.healthThreshold and db.personalTools.reminderSound==baseline.personalTools.reminderSound
    and equal(db.personalTools.reminderGlow,baseline.personalTools.reminderGlow) and equal(db.actions,baseline.actions),'Save changed child settings')
check(equal(options(),{autoRes=1,consumableReminder=1}),'Save callbacks changed detailed preferences')
for _,call in ipairs(calls) do if call[1]=='quickSetter' then check(call[3]==nil,'Hidden child override passed to Quick Bar activation') end end
fresh(true,function(profile)
    profile.hudEnabled,profile.shown=true,true;profile.leaderToolbox.enabled,profile.leaderToolbox.showMissing=true,false
    profile.personalTools.autoRes,profile.personalTools.consumableReminder=true,true
end)
baseline=clone(db)
check(setup:Begin('HUD') and not setup:IsFirstUseDraft() and setup:Save(),'Existing unchanged save failed')
quiet('Unchanged Save');check(equal(db,baseline),'Unchanged Save modified preferences')
setup:Begin('MYTOOLS');setup:Set('role','LEADER');setup:Set('hud',false)
ok,destination=setup:Cancel()
check(ok and destination=='MYTOOLS' and equal(db,baseline) and RaidArsenalDB.setup.role=='RAIDER','Cancel wrote draft or role')
quiet('Cancel')
setup:Begin('MYTOOLS');setup:Set('role','LEADER');setup:Skip()
check(RaidArsenalDB.setup.role=='RAIDER' and equal(db,baseline),'Skip wrote role/preferences')
quiet('Skip')
fresh(false);setup:Begin('ADDONS');setup:Set('role','LEADER');setup:Skip()
check(RaidArsenalDB.setup.completed and RaidArsenalDB.setup.role=='RAIDER' and not setup:HasDraft(),'First Skip changed role or retained draft')
quiet('First Skip')
fresh(true,function(profile)profile.leaderToolbox.showMissing=false end)
setup:Begin('HUD');setup:Set('quickBar',true)
check(setup:Save() and db.leaderToolbox.showMissing,'Explicit Quick Bar enable lost provider default')
fresh(true,function(profile)profile.leaderToolbox.enabled=true;profile.leaderToolbox.showMissing=false end)
setup:Begin('HUD');setup:Set('role','LEADER')
check(setup:Save() and not db.leaderToolbox.showMissing and count('quickSetter')==0,'Role-only save reactivated Quick Bar')
for _,blocked in ipairs({'combat','encounter'}) do
    fresh(false);baseline=clone(db);setup:Begin('ADDONS');setup:Set('hud',true);setup:Set('reminder',true)
    if blocked=='combat' then combat=true else encounter=true end
    check(not setup:Save() and setup:HasDraft() and equal(db,baseline),blocked..' applied/discarded draft')
    quiet(blocked);combat,encounter=false,false;event('PLAYER_REGEN_ENABLED');event('ENCOUNTER_END')
    check(equal(db,baseline) and setup:HasDraft(),blocked..' auto-saved');quiet('Context end')
    check(setup:Save() and db.hudEnabled,'Deliberate retry failed')
end
fresh(true);setup:Begin('HUD');setup:Set('hud',true)
db.personalTools.healthThreshold=29;db.personalTools.reminderSound=false;db.personalTools.reminderGlow.style='PIXEL'
db.actions.leftClickMode='SAY';db.leaderToolbox.showMissing=false
check(not setup:GetConflict() and setup:Save(),'Non-staged child edit invalidated review')
check(db.personalTools.healthThreshold==29 and not db.personalTools.reminderSound and db.personalTools.reminderGlow.style=='PIXEL'
    and db.actions.leftClickMode=='SAY' and not db.leaderToolbox.showMissing,'Save overwrote child-only edits')
fresh(true);setup:Begin('HUD');setup:Set('hud',true);db.personalTools.autoRes=true;baseline=clone(db)
check(setup:GetConflict() and not setup:Save() and equal(db,baseline) and setup:HasDraft(),'Master conflict overwritten')
quiet('Conflict')
check(setup:Reload() and setup:Get('autoRes') and not setup:Get('hud') and not setup:IsFirstUseDraft(),'Reload failed current values/mode')
ok,destination=setup:Cancel();check(ok and destination=='HUD','Reload lost original return')
fresh(false);setup:Begin('ADDONS');setup:Set('hud',true);RaidArsenalDB.profile=clone(db);db=RaidArsenalDB.profile;baseline=clone(db)
check(not setup:Save() and equal(db,baseline) and setup:HasDraft(),'Same-values profile replacement not detected');quiet('Profile conflict')
setup:Reload();check(setup:IsFirstUseDraft(),'Reload lost first-use mode')
RA:FireCallback('PROFILE_IMPORTED');check(setup:GetConflict() and setup:HasDraft(),'Import callback failed invalidation')
setup:Reload();check(not setup:GetConflict(),'Import reload remained blocked')
RA:FireCallback('PROFILE_RESET');check(not setup:HasDraft() and not setup:Save(),'Profile reset retained draft');quiet('Profile reset')
fresh(true);check(not setup:Set('hud',true) and not setup:Save() and not setup:Cancel(),'Closed review accepted staging')
setup:Begin('HUD')
for _,row in ipairs({{'threshold',50},{'sound',false},{'glow',false},{'missing',false},{'leftClick','SAY'},
    {'unknown',true},{'hud',1},{'role','TANK'},{'hud',secret},{secret,true}}) do check(not setup:Set(row[1],row[2]),'Unsupported staged choice accepted') end
quiet('Validation')
print('PASS: '..checks..' focused Setup/Core setter assertions')
