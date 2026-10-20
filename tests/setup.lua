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
check(setup:IsFirstRunPending(), 'New install must offer first run')
local baseline = clone(db)
check(setup:Begin('MYTOOLS'), 'Begin failed')
check(not setup:IsFirstRunPending() and setup:HasDraft(), 'Begin did not mark presentation/draft')
for key, value in pairs({role = 'LEADER', autoRes = true, reminder = true, threshold = 51, sound = false,
    glow = false, quickBar = true, missing = false, hud = true, leftClick = 'WHISPER'}) do
    check(setup:Set(key, value), 'Could not stage ' .. key)
end
local selected, summary = setup:GetSummary()
check(selected == 4 and summary:find('sound off', 1, true) and summary:find('glow off', 1, true)
    and summary:find('provider classes off', 1, true), 'Summary omitted reviewed choices')
setup:Set('glow', true)
local _, glowSummary=setup:GetSummary()
check(glowSummary:find('icon glow at ≤35%',1,true)
    and not glowSummary:find('Healthstone glow',1,true),'Welcome summary still limits glow to Healthstone')
setup:Set('glow', false)
check(equal(db, baseline), 'Begin/Set/Summary activated or changed live profile before Save')
quiet('Staging')
local copy = setup:GetDraft(); copy.hud = false
check(setup:Get('hud') == true, 'GetDraft exposed mutable internal draft')
check(setup:Begin('ADDONS') and setup:Get('hud') == true and RaidArsenalDB.setup.returnTab == 'MYTOOLS', 'Begin/reopen silently restarted staged choices or return tab')
check(setup:Save(), 'Save failed')
check(not setup:HasDraft() and RaidArsenalDB.setup.completed and RaidArsenalDB.setup.role == 'LEADER', 'Save did not complete metadata')
check(db.hudEnabled and db.personalTools.autoRes and db.personalTools.consumableReminder
    and db.personalTools.healthThreshold == 51 and not db.personalTools.reminderSound and not db.personalTools.reminderStoneGlow,
    'Save failed to apply reviewed personal/HUD values')
check(db.leaderToolbox.enabled and db.leaderToolbox.showMissing == false, 'Reviewed missing=false was overwritten by Quick Bar default')
check(db.actions.leftClickMode == 'WHISPER' and db.actions.whisperEnabled and not db.actions.sayEnabled, 'Callout mirrors do not match reviewed mode')
check(count('quickSetter') == 1 and count('hudSetter') == 1 and count('scan') == 1 and count('personalRefresh') == 1, 'Save did not activate changed tools exactly once')
for _, call in ipairs(calls) do
    if call[1] == 'quickSetter' then check(call[2] == true and call[3] == false, 'Quick Bar did not receive reviewed missing preference') end
    if call[1] == 'personalRefresh' then check(call[2] == true, 'Reminder enable did not request readiness refresh') end
end
local changed = options()
for _, key in ipairs({'autoRes', 'consumableReminder', 'healthThreshold', 'reminderSound', 'reminderStoneGlow'}) do
    check(changed[key] == 1, 'Changed option callback missing/duplicated: ' .. key)
end
fresh(true, function(profile)
    profile.hudEnabled, profile.shown = true, true
    profile.leaderToolbox.enabled, profile.leaderToolbox.showMissing = true, false
    profile.personalTools.autoRes, profile.personalTools.consumableReminder = true, true
end)
check(not setup:IsFirstRunPending(), 'Existing install incorrectly offered first run')
baseline = clone(db)
check(setup:Begin('COOLDOWNS') and setup:Save(), 'Existing-enabled unchanged save failed')
quiet('Unchanged enabled save')
check(equal(db, baseline), 'Unchanged Save modified existing preferences')
check(setup:Begin('COOLDOWNS'), 'Replay failed')
setup:Set('autoRes', false); setup:Set('hud', false); setup:Set('missing', true); setup:Set('sound', false)
local ok, destination = setup:Skip()
check(ok and destination == 'COOLDOWNS' and equal(db, baseline), 'Skip changed live choices or lost return tab')
quiet('Skip')
check(setup:Begin('ADDONS') and setup:Get('autoRes') and setup:Get('hud'), 'Replay reused skipped draft instead of current settings')
check(setup:Begin('ADDONS', true) and setup:Get('autoRes'), 'Explicit restart did not use current profile')
fresh(false)
setup:Begin('ADDONS'); setup:Set('sound', false)
check(setup:Save() and count('personalRefresh') == 0 and count('scan') == 0, 'Sound-only save refreshed personal tools/inspection')
check(equal(options(), {reminderSound = 1}), 'Sound-only save did not use exact normal audio option callback')
fresh(false)
setup:Begin('ADDONS'); setup:Set('glow', false)
check(setup:Save() and count('personalRefresh') == 1 and equal(options(), {reminderStoneGlow = 1}), 'Glow-only save missed normal refresh/callback or produced audio callback')
for _, call in ipairs(calls) do if call[1] == 'personalRefresh' then check(call[2] == false, 'Glow-only save requested inventory readiness refresh') end end
fresh(false)
setup:Begin('ADDONS'); setup:Set('reminder', true)
check(setup:Save() and equal(options(), {consumableReminder = 1}), 'Reminder-only save did not notify native reminder/audio path')
fresh(true, function(profile) profile.hudEnabled, profile.shown, profile.leaderToolbox.enabled = true, true, true end)
setup:Begin('ADDONS'); setup:Set('missing', false); setup:Set('leftClick', 'SAY')
check(setup:Save() and count('quickSetter') == 0 and count('hudSetter') == 0 and count('scan') == 0
    and count('quickRefresh') == 1 and count('rearm') == 1, 'Enabled tools were reactivated instead of refreshing changed local option')
for _, blocked in ipairs({'combat', 'encounter'}) do
    fresh(false); baseline = clone(db); setup:Begin('ADDONS'); setup:Set('hud', true); setup:Set('reminder', true)
    if blocked == 'combat' then combat = true else encounter = true end
    check(not setup:Save() and setup:HasDraft() and equal(db, baseline), blocked .. ' Save applied or discarded staged state')
    quiet(blocked .. ' blocked Save')
    combat, encounter = false, false
    event('PLAYER_REGEN_ENABLED'); event('ENCOUNTER_END')
    check(equal(db, baseline) and setup:HasDraft(), blocked .. ' Save resumed itself after context ended')
    quiet(blocked .. ' context ended')
    check(setup:Save() and db.hudEnabled, 'Deliberate retry failed after ' .. blocked)
end
fresh(false); setup:Begin('ADDONS'); setup:Set('hud', true); db.personalTools.reminderSound = false
baseline = clone(db)
check(not setup:Save() and equal(db, baseline) and setup:HasDraft(), 'External represented preference conflict was overwritten')
quiet('Preference conflict')
check(setup:Begin('ADDONS', true) and setup:Get('sound') == false and not setup:Get('hud'), 'Conflict restart did not review current live values')
fresh(false); setup:Begin('ADDONS'); setup:Set('hud', true)
RaidArsenalDB.profile = clone(db); db = RaidArsenalDB.profile; baseline = clone(db)
check(not setup:Save() and equal(db, baseline) and setup:HasDraft(), 'Same-values replacement profile was not detected')
quiet('Profile identity conflict')
fresh(false); setup:Begin('ADDONS'); setup:Set('sound', false)
db.personalTools.reminderSoundChoice, db.personalTools.reminderSoundChannel = 'custom', 'SFX'
check(setup:Save() and db.personalTools.reminderSoundChoice == 'custom' and db.personalTools.reminderSoundChannel == 'SFX', 'Save overwrote an unrepresented audio preference')
fresh(false); setup:Begin('ADDONS'); setup:Set('hud', true)
RA:FireCallback('PROFILE_RESET')
check(not setup:HasDraft() and not setup:Save(), 'Profile reset retained/replayed stale draft')
quiet('Profile reset')
fresh(false); check(not setup:Set('hud', true) and not setup:Save() and not setup:Skip(), 'Closed Setup accepted changes/save/skip')
setup:Begin('ADDONS')
for _, row in ipairs({{'unknown', true}, {'hud', 1}, {'role', 'TANK'}, {'leftClick', 'RAID'}, {'threshold', 0/0}, {'threshold', math.huge}, {'threshold', '50'}, {'hud', secret}}) do
    check(not setup:Set(row[1], row[2]), 'Unsupported/secret staged value accepted')
end
check(not setup:Set(secret, true), 'Secret key accepted')
setup:Set('threshold', -10); check(setup:Get('threshold') == 1, 'Threshold lower clamp failed')
setup:Set('threshold', 110); check(setup:Get('threshold') == 99, 'Threshold upper clamp failed')
setup:Set('threshold', 42.7); check(setup:Get('threshold') == 43, 'Threshold rounding failed')
quiet('Validation and staging')
if setup.Close or setup.Pause then
    print('NOTE: New Close/Pause methods detected; add signature-specific checks before reporting their behavior.')
else print('NOTE: This Setup snapshot has no Close/Pause methods.') end
print('PASS: ' .. checks .. ' focused Setup/Core setter assertions; source paths: ' .. corePath .. ' | ' .. setupPath)
