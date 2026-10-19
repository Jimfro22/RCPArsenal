-- Offline Lua 5.1 assertions. This cannot simulate WoW rendering or taint.
local checks, combat, mediaReady = 0, false, true
local timers, objects, named, events, callbacks, initializers = {}, {}, {}, {}, {}, {}
local spellIcons, spellRequests = {}, {}
local geometryWrites, attributeWrites, scanCalls = 0, 0, 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
local function noop() end
local methods = {}
function methods:GetFrameLevel() return self.level or 0 end
function methods:GetThumbTexture() return self.thumb end
function methods:SetThumbTexture(value) self.thumb = self:CreateTexture(); self.thumb:SetTexture(value) end
function methods:GetValue() return self.value or 0 end
function methods:SetValue(value) self.value = value; if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,value) end end
function methods:SetScrollChild(child) self.child = child end
function methods:HasFocus() return self.focus end
function methods:SetFocus() self.focus = true end
function methods:ClearFocus() self.focus = false end
function methods:IsEnabled() return self.enabled ~= false end
function methods:Enable() self.enabled = true end
function methods:Disable() self.enabled = false end
function methods:SetEnabled(value) self.enabled = value end
function methods:GetParent() return self.parent end
function methods:SetParent(parent) self.parent = parent end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:HookScript(event, fn)
    self.hooks[event] = self.hooks[event] or {}
    table.insert(self.hooks[event], fn)
end
function methods:Fire(event, ...)
    if self.scripts[event] then self.scripts[event](self, ...) end
    for _, fn in ipairs(self.hooks[event] or {}) do fn(self, ...) end
end
function methods:Show() local changed = not self.shown; self.shown = true; if changed then self:Fire('OnShow') end end
function methods:Hide() local changed = self.shown; self.shown = false; if changed then self:Fire('OnHide') end end
function methods:SetShown(value) if value then self:Show() else self:Hide() end end
function methods:SetSize(w, h) geometryWrites = geometryWrites + 1; self.width, self.height = w, h end
function methods:SetWidth(w) geometryWrites = geometryWrites + 1; self.width = w end
function methods:SetHeight(h) geometryWrites = geometryWrites + 1; self.height = h end
function methods:SetPoint(...) geometryWrites = geometryWrites + 1; self.points[#self.points + 1] = {...} end
function methods:ClearAllPoints() geometryWrites = geometryWrites + 1; self.points = {} end
function methods:SetAllPoints(other) geometryWrites = geometryWrites + 1; self.allPoints = other end
function methods:GetWidth() return self.width or 0 end
function methods:GetHeight() return self.height or 0 end
function methods:GetLeft() return 300 end
function methods:GetTop() return 600 end
function methods:GetRight() return 700 end
function methods:GetBottom() return 300 end
function methods:GetCenter() return 500, 500 end
function methods:GetScale() return self.scale or 1 end
function methods:GetEffectiveScale() return self.scale or 1 end
function methods:SetScale(value) geometryWrites = geometryWrites + 1; self.scale = value end
function methods:SetAttribute(key, value) attributeWrites = attributeWrites + 1; self.attrs[key] = value end
function methods:GetAttribute(key) return self.attrs[key] end
function methods:SetTexture(asset, wrapH, wrapV, filter)
    self.textureCalls = (self.textureCalls or 0) + 1
    self.lastDesired = asset
    if self.alwaysFail or (type(asset) == 'string' and asset:find('AddOns', 1, true) and not mediaReady) then
        self.texture = nil
        return false -- A successful pcall is not successful SetTexture.
    end
    self.texture, self.filter = asset, filter
    return true
end
function methods:GetTexture() return self.texture end
function methods:SetFont(path, size)
    self.fontCalls = (self.fontCalls or 0) + 1
    if self.failFonts then return false end
    if path == 'Fonts\\ARIALN.TTF' or (path == 'SharedExpressway.ttf' and mediaReady) then
        self.font, self.fontSize = path, size
        return true
    end
    return false
end
function methods:GetFont() return self.font, self.fontSize end
function methods:SetText(text) self.text = text; self.textCalls = (self.textCalls or 0) + 1 end
function methods:GetText() return self.text end
function methods:GetStringWidth() return #(self.text or '') * 6 end
function methods:GetStringHeight() return self.fontSize or 10 end
local objectMeta = {__index = function(_, key)
    if methods[key] then return methods[key] end
    if key:match('^Set') or key:match('^Register') or key == 'EnableMouse' or key == 'AddMaskTexture' or key == 'HighlightText' or key == 'StopMovingOrSizing' or key == 'StartMoving' then return noop end
end}
local function object(kind, name, parent)
    local frame = setmetatable({kind = kind, name = name, parent = parent, shown = true, scripts = {}, hooks = {}, attrs = {}, points = {}}, objectMeta)
    objects[#objects + 1] = frame
    if name then named[name] = frame; _G[name] = frame end
    return frame
end
function methods:CreateTexture() return object('Texture', nil, self) end
function methods:CreateMaskTexture() return object('MaskTexture', nil, self) end
function methods:CreateFontString() return object('FontString', nil, self) end
function methods:CreateAnimationGroup()
    local group = object('AnimationGroup', nil, self)
    group.CreateAnimation = function() return object('Animation', nil, group) end
    group.Play, group.Stop = noop, noop
    return group
end
function CreateFrame(kind, name, parent) return object(kind, name, parent) end
UIParent = object('Frame', 'UIParent')
UIParent:SetSize(1920, 1080)
GameTooltip = object('Frame', 'GameTooltip')
function InCombatLockdown() return combat end
function IsInRaid() return false end
function IsInGroup() return false end
function UnitIsGroupLeader() return false end
function UnitIsGroupAssistant() return false end
function GetNumGroupMembers() return 0 end
function GetCVarBool() return true end
function GetTime() return 0 end
function GetCursorPosition() return 500, 500 end
function UnitName() return 'Test', 'Realm' end
function GetRealmName() return 'Realm' end
function UnitClass() return 'Mage', 'MAGE' end
function UnitExists() return false end
function UnitGUID() return 'player-guid' end
function Ambiguate(name) return name end
function LibStub()
    return {Fetch = function() if mediaReady then return 'SharedExpressway.ttf' end end}
end
C_Spell = {
    GetSpellTexture = function(id) return spellIcons[id] end,
    GetSpellInfo = function() return nil end,
    RequestLoadSpellData = function(id) spellRequests[id] = (spellRequests[id] or 0) + 1 end,
}
C_Timer = {NewTimer = function(delay, fn)
    local timer = {delay = delay, callback = fn, Cancel = function(self) self.cancelled = true end}
    timers[#timers + 1] = timer
    return timer
end}
C_Timer.After = function(delay, fn) C_Timer.NewTimer(delay, fn) end
local function pending()
    local count = 0
    for _, timer in ipairs(timers) do if not timer.cancelled and not timer.fired then count = count + 1 end end
    return count
end
local function drain(limit)
    local fired = 0
    while true do
        local nextTimer
        for _, timer in ipairs(timers) do if not timer.cancelled and not timer.fired then nextTimer = timer; break end end
        if not nextTimer then break end
        fired = fired + 1
        check(fired <= (limit or 6), 'Retry queue exceeded its bounded pass count')
        nextTimer.fired = true
        nextTimer.callback()
    end
    return fired
end

-- Load the actual module order, events, schema migration and lazy hub. These
-- mocks check addon decisions; they do not establish game rendering or taint.
local messages, sent, talentReads, inspectCalls = {}, 0, 0, 0
local nativePrint = print
print = function(value) messages[#messages + 1] = tostring(value) end
SlashCmdList = {}
C_Timer.NewTicker = function(delay, fn)
    local timer = C_Timer.NewTimer(delay, fn); timer.ticker = true; return timer
end
function UnitFullName() return 'Test', 'Realm' end
function GetNormalizedRealmName() return 'Realm' end
function time() return 1800000000 end
function UnitIsConnected() return true end
function IsEncounterInProgress() return false end
function UnitIsUnit(a,b) return a == b end
function UnitGroupRolesAssigned() return 'DAMAGER' end
function wipe(t) for key in pairs(t) do t[key] = nil end; return t end
C_AddOns = {
    GetNumAddOns = function() return 1 end,
    GetAddOnInfo = function() return 'RCPArsenal' end,
}
C_ChatInfo = {
    RegisterAddonMessagePrefix = function() return 0 end,
    SendAddonMessage = function() sent = sent + 1; return 0 end,
}
C_SpecializationInfo = {GetSpecialization = function() talentReads = talentReads + 1; return nil end}
C_Traits = setmetatable({}, {__index = function() return function() talentReads = talentReads + 1; return nil end end})
NotifyInspect = function() inspectCalls = inspectCalls + 1 end
ClearInspectPlayer = function() end
local RA = {}
assert(loadfile('RCPArsenal/Core.lua'))('RCPArsenal', RA)
local eventFrame = objects[#objects]
for line in io.lines('RCPArsenal/RCPArsenal.toc') do
    if line:match('%.lua$') and line ~= 'Core.lua' then
        assert(loadfile('RCPArsenal/' .. line))('RCPArsenal', RA)
    end
end
local function event(name, ...) eventFrame.scripts.OnEvent(eventFrame, name, ...) end
local function cleanErrors()
    for _, value in ipairs(messages) do
        check(not value:lower():find('error:'), 'Real module callback failed: ' .. value)
    end
end
RaidArsenalDB = {profile = {schemaVersion = 18, shown = true, demoMode = true,
    autoShowEncounter = true, position = {point = 'TOPLEFT', relativePoint = 'TOPLEFT', x = 200, y = -50},
    positionAnchorVersion = 1, categories = {MANA = true}, abilities = {spirit_link = false},
    leaderToolbox = {enabled = true, panicEnabled = true, showMissing = true},
    actions = {leftClickMode = 'WHISPER', raidWarningEnabled = true},
    worldMarkers = {enabled = true, order = {8,4,2}},
}}
-- Marker secure native wrapper is covered separately; emulate the API's setup.
SecureHandlerWrapScript = function() end
GetBindingKey = function() return nil end
GetBindingAction = function() return '' end
GetCurrentBindingSet = function() return 1 end
event('ADDON_LOADED','RCPArsenal')
cleanErrors()
local db = RA:GetDB()
check(db.schemaVersion == 19 and not db.hudEnabled and not db.shown and not db.demoMode, 'Legacy HUD must become quiet once')
check(not db.autoShowEncounter and not db.scan.showStrip and not db.leaderToolbox.enabled and not db.leaderToolbox.panicEnabled, 'Inherited overlays stayed active')
check(db.actions.leftClickMode == 'OFF' and not db.actions.raidWarningEnabled, 'Inherited announcements stayed active')
check(db.worldMarkers.enabled and table.concat(db.worldMarkers.order,',') == '8,4,2', 'Schema-18 marker intent was reset')
check(db.categories.MANA and db.abilities.spirit_link == false and db.position.x == 200, 'Quiet migration lost content or position')
check(not named.RCPArsenalHUD:IsShown() and not named.RCPArsenalRaidLeaderPuck:IsShown(), 'Disabled overlays are shown')
check(named.RCPArsenalConsumableReminder == nil, 'Off reminder allocated a frame')
check(talentReads == 0 and inspectCalls == 0, 'Off initialization read talents or inspected')
local offEvents = {'PLAYER_LOGIN','PLAYER_ENTERING_WORLD','GROUP_ROSTER_UPDATE','READY_CHECK','SPELLS_CHANGED','TRAIT_CONFIG_UPDATED','PLAYER_SPECIALIZATION_CHANGED','INSPECT_READY','PLAYER_REGEN_DISABLED','PLAYER_REGEN_ENABLED'}
for _ = 1, 3 do for _, name in ipairs(offEvents) do event(name,'player') end end
check(not RA:RequestInspectionScan('off', true) and not RA:ScheduleInspectionScan('off',0,true), 'Off manual scan bypassed opt-in')
check(not RA:SetInspectionPaused(false), 'Off resume bypassed opt-in')
check(not RA:ClearInspectionCache(), 'Off clear cache bypassed opt-in')
RA:OnCapabilityFiltersChanged()
check(talentReads == 0 and inspectCalls == 0, 'Off events/settings read talents or inspected')
check(pending() == 0, 'Quiet startup left timers running')
check(sent == 0, 'Quiet startup queried the group')
event('ENCOUNTER_START'); check(RA.InEncounter, 'Encounter bookkeeping depends on inspection')
event('ENCOUNTER_END'); check(not RA.InEncounter, 'Encounter state stayed latched after end')

-- Command entry always returns to Addons and retains legacy compatibility.
check(SLASH_RCPARSENAL1 == '/rcp' and SLASH_RCPARSENAL2 == '/rcparsenal' and SLASH_RCPARSENAL3 == '/rcpa', 'Slash aliases changed')
local other = function() end
hash_SlashCmdList = {['/RCP'] = other}
check(RA:GetSlashCommandStatus():find('another addon') and hash_SlashCmdList['/RCP'] == other, 'Collision status overwrote another handler')
hash_SlashCmdList = nil
SlashCmdList.RCPARSENAL('settings')
check(RA.ConfigFrame:IsShown(), 'Real config did not open')
cleanErrors()
local function hasVisibleText(text)
    for _, region in ipairs(objects) do if region.text == text and region:IsVisible() and (text ~= 'Morning Brew' or (region.fontSize or 0) >= 20) then return true end end
    return false
end
check(hasVisibleText('Settings') and not hasVisibleText('Morning Brew'), 'Settings pane navigation failed')
SlashCmdList.RCPARSENAL('')
check(hasVisibleText('Morning Brew') and not hasVisibleText('Settings'), 'Bare /rcp did not return to Addons')
check(talentReads == 0 and inspectCalls == 0 and sent == 0, 'Opening the hub performed scans or network requests')
SlashCmdList.RCPARSENAL('raid')
check(hasVisibleText('Raid tools'), 'Raid tools pane missing')
check(hasVisibleText('OPTIONAL'), 'Optional addons are not visibly separated')
SlashCmdList.RCPARSENAL('scan'); SlashCmdList.RCPARSENAL('rescan'); SlashCmdList.RCPARSENAL('resume'); SlashCmdList.RCPARSENAL('clearcache'); SlashCmdList.RCPARSENAL('demoscan')
check(not db.hudEnabled and not db.demoMode and talentReads == 0, 'Legacy slash actions silently enabled inspection')
RA:OpenConfig('MYTOOLS'); cleanErrors()
check(hasVisibleText('My tools'), 'My tools did not open')
local function clickVisible(label)
    for _, obj in ipairs(objects) do
        if obj.label and obj.label.text == label and obj:IsVisible() and obj:IsEnabled() then obj:Fire('OnClick'); return true end
    end
    return false
end
check(clickVisible('PREVIEW'), 'Reminder preview button missing')
check(RA.PersonalTools:GetState().previewMode == 'PREVIEW' and not RA:GetDB().personalTools.consumableReminder, 'Preview changed activation')
check(clickVisible('MOVE') and RA.PersonalTools:GetState().previewMode == 'MOVE', 'Move button did not select mover')
check(clickVisible('STOP PREVIEW') and RA.PersonalTools:GetState().previewMode == nil, 'Stop button left sample active')
check(clickVisible('PREVIEW'), 'Preview could not reopen')
RA:OpenConfig('ADDONS')
check(RA.PersonalTools:GetState().previewMode == nil, 'Navigation left reminder sample visible')
RA:OpenConfig('MYTOOLS'); clickVisible('MOVE'); RA:CloseConfig()
check(RA.PersonalTools:GetState().previewMode == nil and not RA:GetDB().personalTools.consumableReminder, 'Host close left mover active or enabled reminder')


-- Reusing link modal prevents stacked windows and host-close resurrection.
RA:OpenConfig('ADDONS')
local link
for _, obj in ipairs(objects) do if obj.label and obj.label.text == 'LINK' and obj:IsVisible() then link = obj; break end end
check(link ~= nil, 'Catalog link control missing')
link:Fire('OnClick'); local count = #objects
link:Fire('OnClick'); check(count == #objects, 'Repeated link click stacked dialogs')
RA:CloseConfig(); RA:OpenConfig('ADDONS')
check(not hasVisibleText('BigWigs — copy link to your browser'), 'Host close resurfaced a modal')
RA:OpenConfig('HUD')
check(not named.RCPArsenalHUD:IsShown() and not db.hudEnabled, 'Opening appearance enabled the HUD')
RA:RecoverHUD(); check(not db.hudEnabled and not db.shown, 'Reset position enabled the HUD')

-- Imports preserve every local switch and version target while applying content.
db.readiness.targets = {northernsky='1.2.3'}; local targets = db.readiness
local personal = db.personalTools
RA:OpenConfig('SETTINGS')
local beforeReset = RA:GetDB()
check(clickVisible('RESET PROFILE') and RA:GetDB() == beforeReset, 'Reset ran before consequence confirmation')
check(clickVisible('CANCEL') and RA:GetDB() == beforeReset, 'Reset cancel changed the profile')
local imported = assert(RA:ExportProfileString())
check(RA:ImportProfileString(imported), 'Portable round trip failed')
check(RA:GetDB().readiness == targets and RA:GetDB().personalTools == personal and not RA:GetDB().hudEnabled and RA:GetDB().worldMarkers.enabled, 'Import changed local opt-ins or targets')
local schedule = RA.ScheduleInspectionScan
local scheduled = 0
RA.ScheduleInspectionScan = function() scheduled = scheduled + 1; return true end
-- A puck-only raid startup must remain scan-free, including pinned shutdown.
IsInRaid = function() return true end
IsInGroup = function() return true end
GetNumGroupMembers = function() return 1 end
GetRaidRosterInfo = function() return 'Test-Realm',2,1,80,'Mage','MAGE','Raid',true,false,nil,false,'DAMAGER' end
IsMouseButtonDown = function() return false end
check(RA:SetQuickBarEnabled(true) and scheduled == 0 and not RA:IsHUDEnabled(), 'Puck enable started inspection')
check(named.RCPArsenalRaidLeaderPuck:IsShown(), 'Puck-only raid view did not show')
check(talentReads == 0 and inspectCalls == 0, 'Puck-only startup read talents or inspected')
RA.RaidLeaderToolbox:SetPinned(true)
check(named.RCPArsenalRaidLeaderToolbox:IsShown(), 'Pinned dock did not open')
check(RA:SetQuickBarEnabled(false), 'Puck disable failed')
check(not named.RCPArsenalRaidLeaderToolbox:IsShown() and not named.RCPArsenalRaidLeaderPuck:IsShown(), 'Pinned dock stayed visible when switched off')
check(named.RCPArsenalQuickBarClickMonitor.scripts.OnUpdate == nil, 'Disabled dock retained update monitor')
check(RA:SetQuickBarEnabled(true), 'Puck reenable failed')
IsInRaid = function() return false end
IsInGroup = function() return false end
GetNumGroupMembers = function() return 0 end
check(RA:SetHUDEnabled(true) and scheduled == 1 and RA:IsInspectionEnabled(), 'Explicit HUD enable did not schedule inspection')
RA:NormalizeProfile(RA:GetDB())
check(RA:IsHUDEnabled() and RA:GetDB().shown and RA:GetDB().leaderToolbox.enabled, 'Schema-19 explicit choices did not survive normalization')
local oldDonor = RA:CreateDefaultProfile(); oldDonor.schemaVersion = 17
check(RA:ApplyImportedProfile(oldDonor), 'Old donor import failed')
check(RA:IsHUDEnabled() and RA:GetDB().shown and RA:GetDB().leaderToolbox.enabled and RA:GetDB().worldMarkers.enabled, 'Old donor migration reset local opt-in')
check(RA:SetHUDEnabled(false) and not RA:IsInspectionEnabled(), 'HUD disable failed')
RA.ScheduleInspectionScan = schedule
RA:ResetProfile(); cleanErrors()
check(not RA:GetDB().hudEnabled and not RA:GetDB().leaderToolbox.enabled and not RA:GetDB().worldMarkers.enabled and next(RA:GetDB().readiness.targets) == nil, 'Reset is not quiet')
RA:CloseConfig()
cleanErrors()

-- Exercise the real NSRT pane against a controlled adapter boundary. Adapter
-- transactions themselves are checked in nsrt_adapter.lua with stock-shaped APIs.
RA:OpenConfig('NORTHERNSKY'); cleanErrors()
check(hasVisibleText('Northern Sky'), 'NSRT setup pane did not open')
local earlyEditor
for _,obj in ipairs(objects) do if obj.kind == 'EditBox' and obj:IsVisible() then earlyEditor=obj; break end end
check(earlyEditor ~= nil, 'NSRT missing-addon draft editor unavailable')
earlyEditor:SetText('Draft typed before Northern Sky loaded'); earlyEditor:Fire('OnTextChanged')
local adapter = RA.NSRTAdapter
local originals = {}
for key,value in pairs(adapter) do originals[key] = value end
local noteWrites, profileWrites, placementWrites, selections = 0,0,0,0
local nsrtContext, sharedText = 'ui-1', 'Shared runtime original'
local noteUndo, profileUndo, placementUndo = false,false,false
local restoreCalls, releaseCalls = 0,0
local savedText
local capabilities = {notes=true,profiles=true,applyNote=true,applyProfile=true,placement=true,setPlacement=true,openSettings=true}
function adapter:GetStatus()
    return {available=true,version='12.1.32',compatible=true,profile='Original',context=nsrtContext,capabilities=capabilities,reasons={},canRestoreNote=noteUndo,canRestoreProfile=profileUndo,canRestorePlacement=placementUndo,hasNoteBackup=noteUndo,hasProfileBackup=profileUndo,hasPlacementBackup=placementUndo}
end
function adapter:Refresh() return true end
function adapter:GetNotes() return true,nil,{personal='Personal text',shared=sharedText,profile='Original',activeName='Raid note',context=nsrtContext} end
function adapter:GetProfiles() return true,nil,{names={'Original','Raid setup'},current='Original',context=nsrtContext} end
function adapter:SelectProfile(name) selections=selections+1; return true,nil,{name=name,context=nsrtContext} end
function adapter:ApplyLocalNote(text,context)
    check(context == nsrtContext, 'UI used an unreviewed note context')
    savedText=text; noteWrites=noteWrites+1; sharedText=text; nsrtContext='ui-3'; noteUndo=true; return true
end
function adapter:ApplyProfile(name,context) profileWrites=profileWrites+1; profileUndo=true; return true end
function adapter:RestoreLastNote(context)
    check(context == nsrtContext, 'Note restore UI omitted/freshened expected context')
    restoreCalls=restoreCalls+1; noteUndo=false
    sharedText,nsrtContext='Restored original note','ui-restored-'..restoreCalls
    return true
end
function adapter:RestoreLastProfile(context) check(context == nsrtContext, 'Profile restore UI omitted/freshened expected context'); restoreCalls=restoreCalls+1; profileUndo=false; return true end
function adapter:RestoreLastPlacement(context) check(context == nsrtContext, 'Placement restore UI omitted expected context'); restoreCalls=restoreCalls+1; placementUndo=false; return true end
function adapter:ReleaseUndo(kind,context) check(kind == 'note' and context == nsrtContext, 'Keep Current UI lost kind/context'); releaseCalls=releaseCalls+1; noteUndo=false; return true end
function adapter:GetPlacement(section)
    return true,nil,{label='Test placement',context=nsrtContext,values={Anchor='CENTER',relativeTo='CENTER',xOffset=0,yOffset=0,Width=200,Height=40},fields={
        {key='Anchor',label='Anchor',options={'CENTER','TOP'}},{key='relativeTo',label='Relative',options={'CENTER','TOP'}},
        {key='xOffset',label='X',min=-100,max=100},{key='yOffset',label='Y',min=-100,max=100},
        {key='Width',label='Width',min=100,max=500},{key='Height',label='Height',min=20,max=100}}}
end
function adapter:SetPlacement(section,values,context) placementWrites=placementWrites+1; placementUndo=true; return true end
RA:FireCallback('NSRT_ADAPTER_CHANGED'); cleanErrors()
check(earlyEditor:GetText() == 'Draft typed before Northern Sky loaded', 'Late addon load silently replaced a dirty draft')
check(not clickVisible('SAVE LOCAL ARSENAL COPY'), 'Unreviewed late-load draft allowed apply')
check(clickVisible('REPLACE DRAFT') and clickVisible('CONFIRM'), 'Explicit draft replacement route failed')
local editor
for _,obj in ipairs(objects) do if obj.kind == 'EditBox' and obj.text == sharedText and obj:IsVisible() then editor=obj; break end end
check(editor ~= nil, 'Shared runtime note did not populate real editor')
editor:SetText('My retained draft'); editor:Fire('OnTextChanged')
sharedText,nsrtContext='Incoming replacement','ui-2'
RA:FireCallback('NSRT_ADAPTER_CHANGED')
check(editor:GetText() == 'My retained draft' and noteWrites == 0, 'Background refresh lost draft or wrote note')
check(not clickVisible('SAVE LOCAL ARSENAL COPY'), 'Changed note context left apply enabled')
check(clickVisible('PROFILES') and clickVisible('Raid setup'), 'Saved profile selector missing')
check(selections == 1 and profileWrites == 0, 'Profile selection applied a profile')
check(clickVisible('NOTES') and editor:GetText() == 'My retained draft', 'Subview visit lost draft')
check(clickVisible('REVIEW CURRENT SHARED') and editor:GetText() == sharedText, 'Current note review did not show received runtime text')
check(clickVisible('KEEP DRAFT + USE REVIEWED CONTEXT') and clickVisible('CONFIRM'), 'Reviewed context acknowledgement failed')
check(editor:GetText() == 'My retained draft', 'Context acknowledgement replaced the draft')
check(clickVisible('SAVE LOCAL ARSENAL COPY') and noteWrites == 0, 'Note applied before consequence confirmation')
check(clickVisible('CONFIRM') and noteWrites == 1 and savedText == 'My retained draft', 'Confirmed local copy did not use retained draft')
editor:SetText('New unsaved draft after applying'); editor:Fire('OnTextChanged')
check(clickVisible('RESTORE PREVIOUS LOCAL NOTE') and clickVisible('CONFIRM') and restoreCalls == 1, 'Note restore did not send expected context')
check(editor:GetText() == 'New unsaved draft after applying', 'Successful note restore discarded a newer unsaved draft')
check(not clickVisible('SAVE LOCAL ARSENAL COPY'), 'Restored native context allowed an unreviewed retained draft to apply')
check(clickVisible('REPLACE DRAFT') and clickVisible('CONFIRM') and editor:GetText() == 'Restored original note', 'Explicit replacement did not load the restored native note')
check(clickVisible('SAVE LOCAL ARSENAL COPY') and clickVisible('CONFIRM') and noteWrites == 2, 'Clean-draft restore setup failed')
check(clickVisible('RESTORE PREVIOUS LOCAL NOTE') and clickVisible('CONFIRM') and restoreCalls == 2, 'Clean-draft note restore failed')
check(editor:GetText() == 'Restored original note' and clickVisible('SAVE LOCAL ARSENAL COPY') and clickVisible('CANCEL'), 'Clean draft did not reload the restored note with a current context')
noteUndo=true; nsrtContext='ui-4'; RA:FireCallback('NSRT_ADAPTER_CHANGED')
check(clickVisible('KEEP CURRENT / RELEASE UNDO') and releaseCalls == 0, 'Undo release skipped consequence review')
check(clickVisible('CONFIRM') and releaseCalls == 1, 'Keep Current did not release local undo')
check(clickVisible('PROFILES') and clickVisible('Raid setup'), 'Profile selection could not reopen')
check(clickVisible('APPLY SETTINGS AS ARSENAL COPY') and profileWrites == 0, 'Profile applied before consequence confirmation')
check(clickVisible('CONFIRM') and profileWrites == 1, 'Profile apply action failed')
check(clickVisible('RESTORE PREVIOUS SESSION PROFILE') and clickVisible('CONFIRM') and restoreCalls == 3, 'Profile restore did not send expected context')
check(clickVisible('PLACEMENT') and clickVisible('PREVIEW PLACEMENT'), 'Native placement sample control failed')
check(named.RCPArsenalNSRTPlacementSample:IsShown() and placementWrites == 0, 'Placement sample wrote NSRT settings')
check(clickVisible('STOP PREVIEW') and not named.RCPArsenalNSRTPlacementSample:IsShown(), 'Stop placement sample failed')
check(clickVisible('APPLY LOCAL PLACEMENT') and placementWrites == 1, 'Placement apply action failed')
check(clickVisible('RESTORE LAST') and clickVisible('CONFIRM') and restoreCalls == 4, 'Placement restore did not send expected context')
check(clickVisible('PREVIEW PLACEMENT'), 'Placement sample did not reopen')
RA:CloseConfig()
check(not named.RCPArsenalNSRTPlacementSample:IsShown(), 'Closing hub left NSRT placement sample visible')
for key in pairs(adapter) do adapter[key]=nil end
for key,value in pairs(originals) do adapter[key]=value end
cleanErrors()
print = nativePrint
print('PASS: ' .. checks .. ' hub/migration/quiet-lifecycle assertions (actual addon modules; offline frame mocks)')
