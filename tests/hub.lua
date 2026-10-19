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
function methods:RegisterEvent(name) self.registered=self.registered or {};self.registered[name]=true end
function methods:RegisterUnitEvent(name,unit) self:RegisterEvent(name);self.unitFilters=self.unitFilters or {};self.unitFilters[name]=unit end
function methods:UnregisterEvent(name) if self.registered then self.registered[name]=nil end end
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
function methods:IsMouseEnabled() return true end
function methods:IsProtected() return false,false end
function methods:Enable() self.enabled = true end
function methods:Disable() self.enabled = false end
function methods:SetEnabled(value) self.enabled = value end
function methods:EnableKeyboard(value) check(not combat,'Keyboard capture configured in combat');self.keyboard=value end
function methods:EnableMouseWheel(value) check(not combat,'Wheel capture configured in combat');self.wheel=value end
function methods:SetPropagateKeyboardInput(value) check(not combat,'Restricted keyboard propagation changed in combat');self.propagate=value;self.propagationChanges=(self.propagationChanges or 0)+1 end
function methods:SetPropagateMouseClicks(value) check(not combat,'Restricted mouse propagation changed in combat');self.mousePropagate=value end
function methods:SetPropagateMouseMotion(value) check(not combat,'Restricted mouse motion changed in combat');self.mouseMotion=value end
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
function methods:SetRoundLayoutToNearestPixel(value) self.roundLayout=value end
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
function issecretvalue() return false end
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
local bindingMap,bindingOrder,bindingWrites,bindingSaves,bindingScope,chordPrefix={},{},0,0,1,''
local function putBinding(key,action)
    for i=#bindingOrder,1,-1 do if bindingOrder[i]==key then table.remove(bindingOrder,i) end end
    bindingMap[key]=action;if action then bindingOrder[#bindingOrder+1]=key end
end
putBinding('F9',RA.WorldMarkers.PlaceBinding);putBinding('F10',RA.WorldMarkers.PlaceBinding)
putBinding('F11',RA.WorldMarkers.ClearBinding);putBinding('SPACE','JUMP');putBinding('J','JUMP')
C_KeyBindings={GetBindingContextForAction=function() return 7 end}
GetBindingKey=function(action)
    local keys={};for _,key in ipairs(bindingOrder) do if bindingMap[key]==action then keys[#keys+1]=key end end
    return unpack(keys)
end
GetBindingAction=function(key) return bindingMap[key] or '' end
GetCurrentBindingSet=function() return bindingScope end
GetBindingName=function(action) return action=='JUMP' and 'Jump' or action end
GetConvertedKeyOrButton=function(key) return key=='Button4' and 'BUTTON4' or key end
IsKeyPressIgnoredForBinding=function(key) return key=='LSHIFT' or key=='LCTRL' or key=='UNKNOWN' or key=='BUTTON1' or key=='BUTTON2' end
CreateKeyChordStringUsingMetaKeyState=function(key) return chordPrefix..key end
SetBinding=function(key,action,context)
    check(not combat and context==7,'Editor wrote bindings in combat or used scope as context')
    bindingWrites=bindingWrites+1;putBinding(key,action);event('UPDATE_BINDINGS');return true
end
SaveBindings=function(scope) check(not combat and scope==bindingScope,'Editor saved a different binding scope');bindingSaves=bindingSaves+1 end
event('ADDON_LOADED','RCPArsenal')
cleanErrors()
local db = RA:GetDB()
check(db.schemaVersion == 19 and not db.hudEnabled and not db.shown and not db.demoMode, 'Legacy HUD must become quiet once')
check(not db.autoShowEncounter and not db.scan.showStrip and not db.leaderToolbox.enabled and not db.leaderToolbox.panicEnabled, 'Inherited overlays stayed active')
check(db.actions.leftClickMode == 'OFF' and not db.actions.raidWarningEnabled, 'Inherited announcements stayed active')
check(db.worldMarkers.enabled and table.concat(db.worldMarkers.order,',') == '8,4,2', 'Schema-18 marker intent was reset')
check(db.categories.MANA and db.abilities.spirit_link == false and db.position.x == 200, 'Quiet migration lost content or position')
check(not named.RCPArsenalHUD and not named.RCPArsenalRaidLeaderPuck, 'Disabled startup eagerly allocated optional overlays')
for _,obj in ipairs(objects) do check(obj.kind~='Texture' and obj.kind~='FontString','Disabled startup allocated optional visual resources') end
check(not eventFrame.registered.UNIT_HEALTH and not eventFrame.registered.BAG_UPDATE_DELAYED
    and not eventFrame.registered.TRAIT_CONFIG_UPDATED and eventFrame.registered.CHAT_MSG_ADDON,'Off events registered or passive reporting was disabled')
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

-- Neutral entry restores local navigation; explicit deep links retain intent.
check(SLASH_RCPARSENAL1 == '/rcp' and SLASH_RCPARSENAL2 == '/rcparsenal' and SLASH_RCPARSENAL3 == '/rcpa', 'Slash aliases changed')
local other = function() end
hash_SlashCmdList = {['/RCP'] = other}
check(RA:GetSlashCommandStatus():find('another addon') and hash_SlashCmdList['/RCP'] == other, 'Collision status overwrote another handler')
hash_SlashCmdList = nil
local personalGetState=RA.PersonalTools.GetState
local hiddenPersonalReads=0
RA.PersonalTools.GetState=function(...)hiddenPersonalReads=hiddenPersonalReads+1;return personalGetState(...)end
SlashCmdList.RCPARSENAL('')
check(RA.ConfigFrame:IsShown() and RaidArsenalDB.navigation.lastTab=='ADDONS', 'First open must default to Addons')
check(hiddenPersonalReads==0,'Addons open refreshed hidden personal controls')
RA:CloseConfig()
SlashCmdList.RCPARSENAL('settings')
check(RA.ConfigFrame:IsShown(), 'Real config did not open')
local headerLogo
for _,obj in ipairs(objects) do if obj.__raAssetPath == RA.Theme.Assets.HeaderLogo then headerLogo=obj end end
check(headerLogo and headerLogo:GetWidth()==42 and headerLogo:GetHeight()==42 and headerLogo.roundLayout==true,
    'Header mark did not use its small-size export in the unchanged, natively rounded42-unit bounds')
cleanErrors()
local function hasVisibleText(text)
    for _, region in ipairs(objects) do if region.text == text and region:IsVisible() and (text ~= 'Addons & versions' or (region.fontSize or 0) >= 20) then return true end end
    return false
end
check(hasVisibleText('Profiles & Recovery') and not hasVisibleText('Addons & versions'), 'Profiles pane navigation failed')
SlashCmdList.RCPARSENAL('')
check(hasVisibleText('Profiles & Recovery') and not hasVisibleText('Addons & versions'), 'Bare /rcp reset the last viewed tab')
RA:CloseConfig(); SlashCmdList.RCPARSENAL('config')
check(hasVisibleText('Profiles & Recovery'), 'Generic config command lost last tab on close/reopen')
RA:CloseConfig(); RA:OpenConfig()
check(hasVisibleText('Profiles & Recovery'), 'Generic UI open lost last tab')
check(talentReads == 0 and inspectCalls == 0 and sent == 0, 'Opening the hub performed scans or network requests')
SlashCmdList.RCPARSENAL('raid')
check(hasVisibleText('Addons & versions'), 'Version check pane missing')
check(hasVisibleText('Arsenal') and hasVisibleText('BigWigs'), 'Combined addon headers are missing')
SlashCmdList.RCPARSENAL('scan'); SlashCmdList.RCPARSENAL('rescan'); SlashCmdList.RCPARSENAL('resume'); SlashCmdList.RCPARSENAL('clearcache'); SlashCmdList.RCPARSENAL('demoscan')
check(not db.hudEnabled and not db.demoMode and talentReads == 0, 'Legacy slash actions silently enabled inspection')
local personalSettings=RA:GetDB().personalTools
local originalStoneText,originalPotionText=personalSettings.reminderStoneText,personalSettings.reminderPotionText
personalSettings.reminderStoneText,personalSettings.reminderPotionText='SAVED_STONE_SENTINEL','SAVED_POTION_SENTINEL'
RA:OpenConfig('MYTOOLS'); cleanErrors()
check(hiddenPersonalReads>0,'Showing Personal Tools did not refresh its controls')
RA.PersonalTools.GetState=personalGetState
check(hasVisibleText('Personal tools'), 'Personal tools did not open')
local function clickVisible(label)
    for _, obj in ipairs(objects) do
        if obj.label and obj.label.text == label and obj:IsVisible() and obj:IsEnabled() then obj:Fire('OnClick'); return true end
    end
    return false
end
check(clickVisible('REMINDER TEXT & SOUND +'),'Cold personal pane disclosure missing')
local function visibleField(label)
    for _,obj in ipairs(objects) do if obj.box and obj.title and obj.title.text==label and obj:IsVisible() then return obj.box:GetText() end end
end
check(visibleField('HEALTHSTONE TEXT')=='SAVED_STONE_SENTINEL' and visibleField('HEALING POTION TEXT')=='SAVED_POTION_SENTINEL',
    'First disclosure expansion did not refresh saved reminder text')
check(clickVisible('HIDE REMINDER TEXT & SOUND'),'Reminder disclosure did not collapse')
personalSettings.reminderStoneText='CHANGED_WHILE_COLLAPSED'
RA:FireCallback('PERSONAL_TOOLS_CHANGED')
check(clickVisible('REMINDER TEXT & SOUND +') and visibleField('HEALTHSTONE TEXT')=='CHANGED_WHILE_COLLAPSED',
    'Re-expanding disclosure did not catch up to a changed hidden preference')
personalSettings.reminderStoneText,personalSettings.reminderPotionText=originalStoneText,originalPotionText
check(clickVisible('HIDE REMINDER TEXT & SOUND'),'Reminder disclosure did not return to compact layout')

-- Exercise real entry buttons and Back routes; these are navigation assertions,
-- not a claim that the rendered window is usable in the game client.
local function selectedNav(label)
    for _, obj in ipairs(objects) do
        if obj.title and obj.title.text == label and obj.bar and obj:IsVisible() then
            return obj.bar:IsShown()
        end
    end
    return false
end
local function clickNav(label)
    for _, obj in ipairs(objects) do
        if obj.title and obj.title.text == label and obj.bar and obj:IsVisible() then
            obj:Fire('OnClick'); return true
        end
    end
    return false
end
local function visibleButton(label)
    for _, obj in ipairs(objects) do
        if obj.label and obj.label.text == label and obj:IsVisible() then return true end
    end
    return false
end
local function hasHeading(label)
    for _, obj in ipairs(objects) do
        if obj.text == label and (obj.fontSize or 0) >= 20 and obj:IsVisible() then return true end
    end
    return false
end
local navHUD, navPuck, navMarkers = db.hudEnabled, db.leaderToolbox.enabled, db.worldMarkers.enabled
local navReads, navInspects, navSent = talentReads, inspectCalls, sent
local navPosition, navPuckPosition = db.position, db.leaderToolbox.position
local navX, navY, navPuckX, navPuckY, navScale = db.position.x, db.position.y, db.leaderToolbox.position.x, db.leaderToolbox.position.y, db.scale
local routes = {{'AVAILABLE COOLDOWNS','Available Cooldowns'}, {'ADDONS & VERSIONS','Addons & versions'},
    {'QUICK BAR','Quick Bar'}, {'WORLD MARKERS','World marker cycler'},
    {'PERSONAL TOOLS','Personal tools'}, {'PROFILES & RECOVERY','Profiles & Recovery'}}
local previousBottom = 0
for _, route in ipairs(routes) do
    for _, obj in ipairs(objects) do
        if obj.title and obj.title.text == route[1] and obj.bar then
            local top = -obj.points[1][5]
            check(top >= previousBottom + 4 and top + obj:GetHeight() < obj.parent:GetHeight() - 60,
                route[1] .. ' exceeds the sidebar or overlaps the previous row / bottom hint')
            previousBottom = top + obj:GetHeight()
        end
    end
end
for _, route in ipairs(routes) do
    check(clickNav(route[1]) and hasHeading(route[2]), route[1] .. ' was not directly reachable from the persistent sidebar')
    for _, other in ipairs(routes) do check(selectedNav(other[1]) == (route[1] == other[1]), route[1] .. ' selected the wrong sidebar destination') end
    check(not clickVisible('BACK TO ADDONS') and not clickVisible('BACK TO QUICK BAR'), route[1] .. ' retained a competing parent route')
end
check(clickNav('ADDONS & VERSIONS') and clickVisible('Northern Sky') and clickVisible('SETUP') and selectedNav('ADDONS & VERSIONS'), 'Northern Sky lost its Addons context')
check(clickVisible('BACK TO ADDONS') and hasHeading('Addons & versions'), 'Nested Northern Sky Back did not return to Addons')
check(clickNav('AVAILABLE COOLDOWNS') and hasHeading('Categories'), 'Available Cooldowns did not start on Categories')
local coverageExplanation="Shows which raid members can provide each ability. Cooldown use and remaining time aren't tracked."
check(hasVisibleText(coverageExplanation) and hasVisibleText('Enable Available Cooldowns — HUD & inspection'), 'Master or honest coverage explanation is absent above Categories')
local masterFrame, cooldownScroller
for _,obj in ipairs(objects) do
    if obj.title and obj.title.text=='Enable Available Cooldowns — HUD & inspection' then masterFrame=obj end
end
for _,obj in ipairs(objects) do
    if obj.kind=='ScrollFrame' and obj.parent==masterFrame.parent then cooldownScroller=obj end
end
check(cooldownScroller and -masterFrame.points[1][5] < -cooldownScroller.points[1][5], 'Categories body scroll does not keep the master above it')
local headingParent
for _,obj in ipairs(objects) do if obj.text==coverageExplanation then headingParent=obj.parent end end
check(headingParent==masterFrame.parent and cooldownScroller.child~=headingParent, 'Coverage explanation scrolls with the settings body')
for _, old in ipairs({'HUD','CONTENT','SCANNING','CALLOUTS & PANIC','VERSION CHECK'}) do check(not clickNav(old), 'Duplicate primary destination remains: '..old) end
check(clickVisible('DISPLAY & POSITION') and hasVisibleText('HUD GROWTH DIRECTION') and not clickVisible('HIDE SAMPLE'), 'Display controls or initially hidden sample are wrong')
check(hasVisibleText('HUD OPACITY') and hasVisibleText(coverageExplanation), 'Live opacity or fixed coverage explanation is hidden')
check(clickVisible('SHOW SAMPLE') and clickVisible('HIDE SAMPLE'), 'HUD sample was not explicitly collapsible')
check(hasVisibleText('HUD OPACITY') and hasVisibleText('PRESENTATION'), 'Closing the sample hid common appearance settings')
check(clickNav('QUICK BAR') and not hasVisibleText('HUD GROWTH DIRECTION') and visibleButton('RESET PUCK POSITION'), 'Quick Bar retained unrelated HUD controls or lost its position reset')
check(clickNav('AVAILABLE COOLDOWNS') and clickVisible('CALLOUTS & PANIC') and not clickVisible('TEST WHISPER') and not clickVisible('TEST PANIC'), 'Callout diagnostics are initially exposed')
check(hasVisibleText('Panic: Off'), 'Disabled Panic reason is missing')
check(clickVisible('ADVANCED: TEST CALLOUTS') and hasVisibleText('SECURE CALLOUT STATUS') and clickVisible('CLOSE TESTS'), 'Callout tests could not explicitly open/close')
check(clickVisible('ADVANCED: TEST CALLOUTS'), 'Callout tests could not reopen')
RA:CloseConfig(); RA:OpenConfig('ACTIONS')
check(not hasVisibleText('SECURE CALLOUT STATUS'), 'Closing the host reopened diagnostic tests')
check(not clickVisible('TEST PANIC') and clickVisible('HUD POSITION') and selectedNav('AVAILABLE COOLDOWNS'), 'Panic position link did not select Available Cooldowns')
check(clickVisible('SCANNING') and not hasVisibleText('Demo the scanning state') and hasVisibleText('Inspection off'), 'Scan demo or off-state explanation is wrong')
check(clickVisible('ADVANCED: DEMO') and hasVisibleText('Demo the scanning state'), 'Scan demo could not be deliberately revealed')
check(clickNav('PROFILES & RECOVERY') and not clickVisible('RESET PROFILE'), 'Full reset is not initially behind Advanced')
check(db.hudEnabled == navHUD and db.leaderToolbox.enabled == navPuck and db.worldMarkers.enabled == navMarkers,
    'Settings navigation changed tool opt-ins')
check(talentReads == navReads and inspectCalls == navInspects and sent == navSent, 'Settings navigation inspected or sent a version request')
check(db.position == navPosition and db.leaderToolbox.position == navPuckPosition and db.position.x == navX and db.position.y == navY and
    db.leaderToolbox.position.x == navPuckX and db.leaderToolbox.position.y == navPuckY and db.scale == navScale,
    'Opening settings changed saved geometry')
check(clickNav('PERSONAL TOOLS') and not clickVisible('CONFIGURE'), 'Personal tools retained generic Configure detours')
check(hasVisibleText("Prefers a ready Healthstone, then a ready healing potion. Use your own item/macro key."), 'Reminder copy claims readiness')
check(hasVisibleText('SHOW REMINDER') and hasVisibleText('ICON SIZE') and hasVisibleText('TEXT SIZE') and hasVisibleText('EMPTY WARNING SIZE'), 'Everyday controls hidden')
check(not hasVisibleText('HEALTHSTONE TEXT') and clickVisible('REMINDER TEXT & SOUND +'), 'Text details not initially collapsed')
check(hasVisibleText('HEALTHSTONE TEXT') and hasVisibleText('HEALING POTION TEXT') and hasVisibleText('PREVIEW SAMPLE'), 'Message/sample options missing')
check(hasVisibleText('Low-health sound') and hasVisibleText('Native warning ~35%'), 'Native audio scope/setting missing')
check(hasVisibleText('CHANNEL'), 'Audio threshold distinction missing')
check(hasVisibleText('Empty bags: large OUT OF POTIONS! text, with the icon hidden.') and not hasVisibleText('RAID SUPPLIES'), 'Expanded audio/raid label overlap or hide-empty explanation missing')
local audioToggle
for _,obj in ipairs(objects) do if obj.title and obj.title.text=='Low-health sound' and obj.switch then audioToggle=obj end end
check(audioToggle~=nil and RA:GetDB().personalTools.reminderSound==true, 'Default native sound preference missing')
audioToggle:Fire('OnClick')
check(RA:GetDB().personalTools.reminderSound==false and not RA:GetDB().personalTools.consumableReminder, 'Sound toggle enabled master or failed OFF')
local oldKit,oldPlaySound,oldPlayFile=SOUNDKIT,PlaySound,PlaySoundFile
local previews,beforeSoundTimers,beforeSoundSent=0,#timers,sent
SOUNDKIT={ALARM_CLOCK_WARNING_3=12889}
PlaySoundFile=function(path,channel,...) check(path:find('RCP_Sound06.ogg',1,true) and channel=='Master' and select('#',...)==0,'Preview did not use default Sound 6 / Master');previews=previews+1;return true,7777 end
check(clickVisible('PREVIEW SOUND') and previews==1, 'Explicit sound preview failed')
check(RA:GetDB().personalTools.reminderSound==false and not RA:GetDB().personalTools.consumableReminder
    and #timers==beforeSoundTimers and sent==beforeSoundSent, 'Audio preview changed opt-in or started timer/network work')
SOUNDKIT,PlaySound,PlaySoundFile=oldKit,oldPlaySound,oldPlayFile
local beforeChoiceSounds=previews
check(clickVisible('Sound 6  v') and hasVisibleText('Sound 1'), 'Sound dropdown did not open')
check(clickVisible('Sound 1') and RA:GetDB().personalTools.reminderSoundChoice=='sound_1', 'Sound selection did not save curated ID')
check(previews==beforeChoiceSounds and not RA:GetDB().personalTools.consumableReminder, 'Selection played sound or enabled reminder')
local muteOption,channelControl
for _,obj in ipairs(objects) do
    if obj.label and obj.label.text=='Play when game effects are muted' then muteOption=obj end
    if obj.title and obj.title.text=='CHANNEL' and obj.buttons then channelControl=obj end
end
check(muteOption and muteOption:IsEnabled() and not RA.PersonalTools:GetState().reminderSoundWhenEffectsMuted
    and hasVisibleText('Requires Master. Does not override global sound or master volume.'),'Mute permission default/helper missing')
local channelBottom=-channelControl.points[1][5]+channelControl:GetHeight()
check(-muteOption.points[1][5]>=channelBottom+4,'Muted-effects hit area overlaps channel buttons')
check(clickVisible('Play when game effects are muted') and RA.PersonalTools:GetState().reminderSoundWhenEffectsMuted
    and previews==beforeChoiceSounds,'Mute permission edit played a sound or failed to save')
RA.PersonalTools:SetOption('reminderSoundChannel','SFX')
check(not muteOption:IsEnabled() and not clickVisible('Play when game effects are muted')
    and RA.PersonalTools:GetState().reminderSoundWhenEffectsMuted,'SFX route did not disable/preserve mute permission')
RA.PersonalTools:SetOption('reminderSoundChannel','Master')
check(muteOption:IsEnabled() and clickVisible('Play when game effects are muted') and not RA.PersonalTools:GetState().reminderSoundWhenEffectsMuted,'Master route did not recover existing mute choice')
check(hasVisibleText('Show while on cooldown') and RA:GetDB().personalTools.reminderShowOnCooldown==false, 'Show-on-cooldown default/control wrong')
local personalSnapshot=RA:GetDB().personalTools
local pos=personalSnapshot.reminderPosition
RA.PersonalTools:SetOption('reminderStoneText','Stone now')
RA.PersonalTools:SetOption('reminderPotionText','Potion now')
RA.PersonalTools:SetOption('reminderIconSize',72)
RA.PersonalTools:SetOption('reminderTextSize',18)
RA.PersonalTools:SetOption('reminderCombat','OUT_OF_COMBAT')
check(personalSnapshot.reminderPosition==pos and not personalSnapshot.consumableReminder, 'Options changed anchor/opt-in')
check(clickVisible('RESET POSITION') and personalSnapshot.reminderStoneText=='Stone now' and personalSnapshot.reminderIconSize==72
    and personalSnapshot.reminderTextSize==18 and personalSnapshot.reminderCombat=='OUT_OF_COMBAT', 'Position reset changed appearance/visibility')
local beforeSupplySent, beforeSupplyTimers, beforeSupplyReads=sent,#timers,talentReads
check(clickVisible('VIEW RESULTS') and hasVisibleText('Carried healing supplies'), 'Manual supplies dialog missing')
check(sent==beforeSupplySent and #timers==beforeSupplyTimers and talentReads==beforeSupplyReads, 'Viewing supply results queried/polled/inspected')
check(clickVisible('CLOSE') and clickVisible('VIEW RESULTS') and #timers==beforeSupplyTimers and sent==beforeSupplySent, 'Reopening supply results starts a request')
check(clickVisible('CLOSE') and clickVisible('CHECK RAID SUPPLIES') and hasVisibleText('Join a raid to check supplies.'), 'Ineligible query lacks explanation')
check(sent==beforeSupplySent and #timers==beforeSupplyTimers, 'Ineligible supply action sent/started work')
check(clickVisible('CLOSE') and clickVisible('HIDE REMINDER TEXT & SOUND') and hasVisibleText('RAID SUPPLIES'), 'Disclosure collapse lost raid label')
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
for _, obj in ipairs(objects) do if obj.label and obj.label.text == 'DOWNLOAD LINK' and obj:IsVisible() then link = obj; break end end
check(link ~= nil, 'Catalog link control missing')
link:Fire('OnClick'); local count = #objects
link:Fire('OnClick'); check(count == #objects, 'Repeated link click stacked dialogs')
RA:CloseConfig(); RA:OpenConfig('ADDONS')
check(not hasVisibleText('Northern Sky Raid Tools — copy link to your browser'), 'Host close resurfaced a modal')
RA:OpenConfig('HUD')
check((not named.RCPArsenalHUD or not named.RCPArsenalHUD:IsShown()) and not db.hudEnabled, 'Opening appearance enabled/created the HUD')
RA:RecoverHUD(); check(not db.hudEnabled and not db.shown, 'Reset position enabled the HUD')

-- Imports preserve every local switch and version target while applying content.
db.readiness.targets = {northernsky='1.2.3'}; local targets = db.readiness
local personal = db.personalTools
RA:OpenConfig('SETTINGS')
local beforeReset = RA:GetDB()
check(clickVisible('ADVANCED: FULL PROFILE RESET') and clickVisible('RESET PROFILE') and RA:GetDB() == beforeReset, 'Reset ran before consequence confirmation')
check(clickVisible('CANCEL') and RA:GetDB() == beforeReset, 'Reset cancel changed the profile')
local imported = assert(RA:ExportProfileString())
local navigation = RaidArsenalDB.navigation
check(RA:ImportProfileString(imported), 'Portable round trip failed')
check(RaidArsenalDB.navigation==navigation and navigation.lastTab=='SETTINGS', 'Import changed local navigation')
check(RA:GetDB().readiness == targets and RA:GetDB().personalTools == personal and not RA:GetDB().hudEnabled and RA:GetDB().worldMarkers.enabled, 'Import changed local opt-ins or targets')
local schedule = RA.ScheduleInspectionScan
local scheduled = 0
RA.ScheduleInspectionScan = function() scheduled = scheduled + 1; return true end
db=RA:GetDB()
-- A puck-only raid startup must remain scan-free, including pinned shutdown.
IsInRaid = function() return true end
IsInGroup = function() return true end
GetNumGroupMembers = function() return 1 end
GetRaidRosterInfo = function() return 'Test-Realm',2,1,80,'Mage','MAGE','Raid',true,false,nil,false,'DAMAGER' end
IsMouseButtonDown = function() return false end
db.leaderToolbox.showMissing=false
check(RA:SetQuickBarEnabled(true) and scheduled == 0 and not RA:IsHUDEnabled(), 'Puck enable started inspection')
check(db.leaderToolbox.showMissing, 'Explicit enable did not adopt provider coverage for legacy false')
db.leaderToolbox.showMissing=false
RA:NormalizeProfile(db); RA:OpenConfig('QUICKBAR'); RA:RequestVisualAssetRefresh(); RA.RaidLeaderToolbox:Refresh()
check(not db.leaderToolbox.showMissing, 'Settings, normalization or visual refresh changed deliberate provider OFF')
check(named.RCPArsenalRaidLeaderPuck:IsShown(), 'Puck-only raid view did not show')
check(talentReads == 0 and inspectCalls == 0, 'Puck-only startup read talents or inspected')
RA.RaidLeaderToolbox:SetPinned(true)
check(named.RCPArsenalRaidLeaderToolbox:IsShown(), 'Pinned dock did not open')
check(RA:SetQuickBarEnabled(false), 'Puck disable failed')
check(not named.RCPArsenalRaidLeaderToolbox:IsShown() and not named.RCPArsenalRaidLeaderPuck:IsShown(), 'Pinned dock stayed visible when switched off')
check(named.RCPArsenalQuickBarClickMonitor.scripts.OnUpdate == nil, 'Disabled dock retained update monitor')
check(RA:SetQuickBarEnabled(true) and db.leaderToolbox.showMissing, 'Puck reenable did not restore provider coverage default')
IsInRaid = function() return false end
IsInGroup = function() return false end
GetNumGroupMembers = function() return 0 end
check(RA:SetHUDEnabled(true) and scheduled == 1 and RA:IsInspectionEnabled(), 'Explicit HUD enable did not schedule inspection')
check(eventFrame.registered.TRAIT_CONFIG_UPDATED and eventFrame.registered.INSPECT_READY,'Explicit HUD enable did not subscribe inspection events')
RA:NormalizeProfile(RA:GetDB())
check(RA:IsHUDEnabled() and RA:GetDB().shown and RA:GetDB().leaderToolbox.enabled, 'Schema-19 explicit choices did not survive normalization')
local oldDonor = RA:CreateDefaultProfile(); oldDonor.schemaVersion = 17
check(RA:ApplyImportedProfile(oldDonor), 'Old donor import failed')
check(RA:IsHUDEnabled() and RA:GetDB().shown and RA:GetDB().leaderToolbox.enabled and RA:GetDB().worldMarkers.enabled, 'Old donor migration reset local opt-in')
check(RA:SetHUDEnabled(false) and not RA:IsInspectionEnabled(), 'HUD disable failed')
check(not eventFrame.registered.TRAIT_CONFIG_UPDATED and not eventFrame.registered.INSPECT_READY,'HUD disable retained optional inspection events')
RA.ScheduleInspectionScan = schedule
RA:ResetProfile(); cleanErrors()
check(RaidArsenalDB.navigation==navigation, 'Profile reset discarded local navigation')
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
local savedText, recoveryFixture
local capabilities = {notes=true,profiles=true,applyNote=true,applyProfile=true,placement=true,setPlacement=true,openSettings=true}
function adapter:GetStatus()
    return {available=true,version='12.1.32',compatible=true,profile='Original',context=nsrtContext,capabilities=capabilities,reasons={},canRestoreNote=noteUndo,canRestoreProfile=profileUndo,canRestorePlacement=placementUndo,hasNoteBackup=noteUndo,hasProfileBackup=profileUndo,hasPlacementBackup=placementUndo,recovery=recoveryFixture}
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
function adapter:GetRecoveryBackup() return recoveryFixture ~= nil,nil,recoveryFixture end
function adapter:ReleaseUndo(kind,context)
    if kind == 'recovery' then
        check(recoveryFixture and context == recoveryFixture.token, 'Recovery release UI lost record token')
        recoveryFixture=nil
    else check(kind == 'note' and context == nsrtContext, 'Keep Current UI lost kind/context'); noteUndo=false end
    releaseCalls=releaseCalls+1; return true
end
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
local function recoveryEditor(fragment)
    for _,obj in ipairs(objects) do
        if obj.kind == 'EditBox' and obj:IsVisible() and (obj:GetText() or ''):find(fragment,1,true) then return obj end
    end
end
RA:OpenConfig('NORTHERNSKY')
recoveryFixture={kind='note',token='failed-note-token',original='Original',observedProfile='Original',phase='note-activation-failed',reason='Newer note retained',shared='Previous shared note recovery',personal='Previous personal note recovery'}
RA:FireCallback('NSRT_ADAPTER_CHANGED')
check(clickVisible('RECOVERY BACKUP') and recoveryEditor('Previous shared note recovery'), 'Note recovery did not default to the shared backup from Notes')
check(not clickVisible('ORIGINAL PROFILE EXPORT') and not clickVisible('PLACEMENT SETTINGS'), 'Note recovery offered unavailable export/placement content')
check(clickVisible('PERSONAL NOTE BACKUP') and recoveryEditor('Previous personal note recovery'), 'Personal recovery backup was not selectable')
check(clickVisible('CLOSE'), 'Note recovery could not close')
recoveryFixture={kind='placement',token='failed-placement-token',original='Original',observedProfile='Original',phase='placement-refresh-failed',reason='Newer placement retained',shared='Shared backup',personal='Personal backup',placement={section='BarSettings',label='Bars',values={Anchor='TOPRIGHT',relativeTo='CENTER',xOffset=-83,yOffset=41,Width=287,Height=29,TimerFontSize=17}}}
RA:FireCallback('NSRT_ADAPTER_CHANGED')
check(clickVisible('RECOVERY BACKUP'), 'Placement recovery was not reachable from Notes')
local placementBackupEditor=recoveryEditor('Northern Sky placement backup')
check(placementBackupEditor and placementBackupEditor:GetText():find('Section: Bars',1,true) and placementBackupEditor:GetText():find('Anchor = TOPRIGHT',1,true)
    and placementBackupEditor:GetText():find('xOffset = -83',1,true) and placementBackupEditor:GetText():find('Width = 287',1,true)
    and placementBackupEditor:GetText():find('TimerFontSize = 17',1,true) and placementBackupEditor:GetText():find('FontSize = unset',1,true), 'Placement recovery omitted copyable prior coordinates/dimensions/font or unset fields')
check(not clickVisible('ORIGINAL PROFILE EXPORT') and clickVisible('SELECT TEXT') and placementBackupEditor:HasFocus(), 'Placement recovery offered missing export or could not select backup text')
check(clickVisible('KEEP CURRENT / RELEASE BACKUP') and releaseCalls == 1 and hasVisibleText('Keep current state and release placement backup?'), 'Placement release skipped review or identified the wrong backup')
check(clickVisible('CONFIRM') and releaseCalls == 2 and not recoveryFixture, 'Placement recovery could not release its exact record')
recoveryFixture={kind='profile',token='profile-token',original='Original',observedProfile='Copy',phase='import-failed',reason='Inspect settings',originalExport='Native profile export recovery',shared='Shared backup',personal='Personal backup'}
RA:FireCallback('NSRT_ADAPTER_CHANGED')
check(clickVisible('RECOVERY BACKUP') and recoveryEditor('Native profile export recovery') and not clickVisible('PLACEMENT SETTINGS'), 'Profile recovery did not default to its available native export')
RA:CloseConfig()
check(not recoveryEditor('Native profile export recovery'), 'Closing hub left recovery content visible')
for key in pairs(adapter) do adapter[key]=nil end
for key,value in pairs(originals) do adapter[key]=value end
cleanErrors()

-- Cache provenance is visible in the real HUD/configuration, independently of
-- the save/new-lifecycle tests in inspection_cache.lua.
local fullNameAPI = UnitFullName
UnitFullName = function() return 'Test',nil end
check(RA:GetFullUnitName('player') == 'Test-Realm', 'Same-realm identity was not qualified for stable cache keys')
UnitFullName = function() return 'Test','OtherRealm' end
check(RA:GetFullUnitName('party1') == 'Test-OtherRealm', 'Cross-realm identity fell back to the local realm')
UnitFullName = fullNameAPI
local ability = RA.CatalogByKey.aura_mastery
check(ability ~= nil, 'Cache UI fixture requires an actual Paladin talent capability')
local name='Cached-Realm'
RA.Reports={[name]={name=name,guid='Player-1-CAFE',class='PALADIN',role='HEALER',specID=65,classRevision=RA:GetClassCatalogRevision('PALADIN'),verified=true,source='PERSISTED_CACHE',cached=true,sessionVerified=false,originalSource='INSPECT',observerGUID='Player-1-BEEF',confirmedAt=1799996400,capabilities={[ability.index]=true},evidence={[ability.index]='SELECTED_TALENT'}}}
RA.Roster={[name]={name=name,guid='Player-1-CAFE',class='PALADIN',role='HEALER',unit='party1',subgroup=1,connected=true}}
RA.RosterOrder={RA.Roster[name]}
local cacheProfile=RA:GetDB()
cacheProfile.hudEnabled,cacheProfile.shown,cacheProfile.demoMode,cacheProfile.mode=true,true,false,'COMPACT'
local requestsBefore=inspectCalls
RA:RefreshHUD()
cacheProfile.leaderToolbox.panicEnabled=true
RA:RefreshHUD()
check(RA:GetPanicVisibilityText()=='Visible', 'Enabled Panic did not report its visible native button')
cacheProfile.shown=false;RA:RefreshHUD()
check(RA:GetPanicVisibilityText():find('Waiting for visible HUD category',1,true), 'Hidden HUD failed to explain enabled Panic')
cacheProfile.shown=true;cacheProfile.leaderToolbox.panicEnabled=false
cacheProfile.scan.showStrip=true
RA:SetInspectionPaused(true);RA:RefreshHUD()
check(#RA:GetPendingScanEntries()==0 and RA:IsInspectionPaused(), 'Resolved-paused strip fixture has unexpected work')
local resolvedShell
for _,obj in ipairs(objects) do if obj.text=='1/1' then resolvedShell=obj.parent end end
check(not resolvedShell or not resolvedShell:IsShown(), 'Paused flag kept a resolved empty scan strip visible')
RA:OpenConfig('SCANNING')
check(hasVisibleText('No work pending') and not visibleButton('DISABLE HUD + INSPECTION'), 'No-work strip reason or duplicate master is wrong')
RA:SetInspectionPaused(false)
RA:CloseConfig()
local savedTile
for _,obj in ipairs(objects) do if obj.owner and obj.owner.name==name and obj:IsVisible() then savedTile=obj; break end end
check(savedTile and savedTile.cacheLabel:IsShown(), 'Compact cached provider lacked a visible C marker')
local tooltipLines={}
local oldTooltipAddLine=GameTooltip.AddLine
GameTooltip.AddLine=function(_,text) tooltipLines[#tooltipLines+1]=text end
savedTile:Fire('OnEnter')
local tooltipText=table.concat(tooltipLines,'\n')
check(tooltipText:find('Saved inspection; not confirmed this session.',1,true) and tooltipText:find('1h ago',1,true), 'Cached provider tooltip lost original age/provenance')
GameTooltip.AddLine=oldTooltipAddLine
cacheProfile.mode='DETAILED'; RA:RefreshHUD()
local markedOwner=false
for _,obj in ipairs(objects) do if obj:IsVisible() and type(obj.text)=='string' and obj.text:find('[C]',1,true) then markedOwner=true; break end end
check(markedOwner and hasVisibleText('0 confirmed · 1 cached · 0 unknown'), 'Detailed HUD called a saved report confirmed or omitted its cache marker')
tooltipLines={}
GameTooltip.AddLine=function(_,text) tooltipLines[#tooltipLines+1]=text end
local detailedRow
for _,obj in ipairs(objects) do if obj.owners and obj.owners[1] and obj.owners[1].name==name and obj:IsVisible() then detailedRow=obj; break end end
if detailedRow then detailedRow:Fire('OnEnter') end
tooltipText=table.concat(tooltipLines,'\n')
check(detailedRow and tooltipText:find('Saved inspection; not confirmed this session.',1,true) and tooltipText:find('1h ago',1,true) and tooltipText:find('/rcp rescan',1,true), 'Detailed provider tooltip omitted cached origin, original age or explicit refresh route')
GameTooltip.AddLine=oldTooltipAddLine
RA:OpenConfig('SCANNING')
check(hasVisibleText('1 / 1 RESOLVED') and hasVisibleText('0 confirmed · 1 cached · 0 unknown'), 'Scanning pane conflated reusable cache with current inspection')
SlashCmdList.RCPARSENAL('status')
check(messages[#messages]:find('1 cached',1,true) and not messages[#messages]:find('1 inspected',1,true), 'Status command called historical cache newly inspected')
check(inspectCalls==requestsBefore, 'Showing cached provenance initiated inspection')
local oldCache=RaidArsenalDB.inspectionCache
RaidArsenalDB.inspectionCache={sentinel='PRIVATE-INSPECTION-GUID'}
local portable=RA:ExportProfileString()
check(portable and not portable:find('PRIVATE-INSPECTION-GUID',1,true) and not portable:find('inspectionCache',1,true), 'Portable profile leaked another player inspection cache')
RaidArsenalDB.inspectionCache=oldCache
RA:CloseConfig()

-- Routine role/split layouts may use the same compatible last-known spec
-- after reload, rather than demanding a full scan solely for a new session.
local raid={{name='SavedA',guid='Player-1-AA',group=1},{name='SavedB',guid='Player-1-BB',group=1}}
local function raidUnit(unit) return raid[tonumber((unit or ''):match('^raid(%d+)$')) or (unit=='player' and 1 or 0)] end
IsInRaid=function() return true end
IsInGroup=function() return true end
GetNumGroupMembers=function() return #raid end
UnitExists=function(unit) return raidUnit(unit)~=nil end
UnitIsPlayer=UnitExists
UnitFullName=function(unit) local row=raidUnit(unit); if row then return row.name,'Realm' end end
UnitGUID=function(unit) local row=raidUnit(unit); return row and row.guid end
UnitClass=function(unit) if raidUnit(unit) then return 'Hunter','HUNTER' end end
UnitGroupRolesAssigned=function() return 'DAMAGER' end
UnitIsGroupLeader=function(unit) return unit=='player' end
GetRaidRosterInfo=function(index) local row=raid[index]; return row.name..'-Realm',index==1 and 2 or 0,row.group,80,'Hunter','HUNTER',nil,true end
cacheProfile.leaderToolbox.enabled=true
RA.Reports={}
for _,row in ipairs(raid) do
    local full=row.name..'-Realm'
    RA.Reports[full]={name=full,guid=row.guid,class='HUNTER',role='DAMAGER',specID=255,classRevision=RA:GetClassCatalogRevision('HUNTER'),verified=true,source='PERSISTED_CACHE',cached=true,sessionVerified=false,originalSource='INSPECT',observerGUID=raid[1].guid,confirmedAt=1799996400,capabilities={},evidence={roleOnly=true}}
end
requestsBefore=inspectCalls
for _,command in ipairs({'sort','split','groupsplit'}) do
    raid[2].group=command=='sort' and 1 or 2
    local firstMessage=#messages+1
    SlashCmdList.RCPARSENAL(command)
    local output=table.concat(messages,'\n',firstMessage)
    check(output:find('Using 2 saved specializations',1,true) and output:find('Raid is already arranged',1,true), command..' demanded a reload-only rescan or lost guarded cached spec classification')
    check(inspectCalls==requestsBefore and not RA:IsInspectionRunning() and not RA.RaidLeaderToolbox:IsSorting(), command..' queued inspection or an unexpected move for an already arranged cached layout')
end
for _,row in ipairs(raid) do
    check(RA.InspectionCache:Store({name=row.name..'-Realm',guid=row.guid,class='HUNTER',role='DAMAGER',specID=255,classRevision=RA:GetClassCatalogRevision('HUNTER'),verified=true,source='INSPECT',cached=false,sessionVerified=true,confirmedAt=1799996400,capabilities={},evidence={roleOnly=true}}), 'Puck-only reload fixture did not persist confirmed ordinary facts')
end
cacheProfile.hudEnabled,cacheProfile.shown=false,false
local talentsBefore=talentReads
for _,command in ipairs({'sort','split','groupsplit'}) do
    RA.Reports,RA.Roster,RA.RosterOrder={},{},{}
    raid[2].group=command=='sort' and 1 or 2
    local firstMessage=#messages+1
    SlashCmdList.RCPARSENAL(command)
    local output=table.concat(messages,'\n',firstMessage)
    check(output:find('Using 2 saved specializations',1,true) and output:find('Raid is already arranged',1,true), 'Puck-only '..command..' failed to hydrate saved specs after an empty session')
    check(inspectCalls==requestsBefore and talentReads==talentsBefore and not RA:IsInspectionRunning() and not RA:IsHUDEnabled() and cacheProfile.leaderToolbox.enabled, 'Puck-only '..command..' enabled or collected inspection data')
end
-- Actual key-slot and capture callbacks, including a cancelled held gesture.
RA:OpenConfig('WORLDMARKERS')
local function keyButton(key)
    for _,obj in ipairs(objects) do if obj.label and obj.label.text==key and obj:IsVisible() and obj:IsEnabled() then return obj end end
end
local markerAttributes=attributeWrites
check(keyButton('F9') and keyButton('F10') and keyButton('F11'),'Current primary/alternate marker keys missing')
keyButton('F9'):Fire('OnClick')
local input=named.RCPArsenalMarkerBindingEditor
check(input and input:IsVisible() and input.parent==UIParent and input.keyboard and input.propagate==false,'Capture does not own/consume ordinary input')
local writesBefore,savesBefore=bindingWrites,bindingSaves
input:Fire('OnKeyDown','F8')
check(bindingWrites==writesBefore and bindingSaves==savesBefore and input:IsVisible(),'UI saved or closed on keydown')
input:Fire('OnKeyUp','F7');check(input:IsVisible() and bindingWrites==writesBefore,'Unrelated release ended key capture')
input:Fire('OnKeyUp','F8')
check(not input:IsShown() and bindingMap.F8==RA.WorldMarkers.PlaceBinding and bindingMap.F10==RA.WorldMarkers.PlaceBinding
    and bindingMap.F9==nil and bindingSaves==savesBefore+1 and attributeWrites==markerAttributes,'UI assignment lost alternate or changed secure marker actions')
keyButton('F8'):Fire('OnClick');writesBefore,savesBefore=bindingWrites,bindingSaves
input:Fire('OnKeyDown','SPACE');input:Fire('OnKeyUp','SPACE')
check(input:IsVisible() and hasVisibleText('SPACE is assigned to Jump. Replace it?') and bindingWrites==writesBefore,'UI conflict replaced a key silently')
check(clickVisible('CANCEL') and not input:IsShown() and bindingSaves==savesBefore,'Conflict cancel changed bindings')
for _,path in ipairs({'hide','tab','combat','external','reset','import','cancel','mouse-hide'}) do
    RA:OpenConfig('WORLDMARKERS');keyButton('F8'):Fire('OnClick')
    input=named.RCPArsenalMarkerBindingEditor
    local mouse=path=='mouse-hide';local held=mouse and 'BUTTON4' or 'F7'
    input:Fire(mouse and 'OnMouseDown' or 'OnKeyDown',mouse and 'Button4' or 'F7')
    writesBefore,savesBefore=bindingWrites,bindingSaves
    local propagationBefore=input.propagationChanges
    if path=='hide' or path=='mouse-hide' then RA:CloseConfig()
    elseif path=='tab' then RA:OpenConfig('MYTOOLS')
    elseif path=='combat' then combat=true;event('PLAYER_REGEN_DISABLED')
    elseif path=='external' then event('UPDATE_BINDINGS')
    elseif path=='reset' then RA:ResetProfile()
    elseif path=='import' then RA:ApplyImportedProfile(RA:CreateDefaultProfile())
    else check(clickVisible('CANCEL'),'Capture Cancel missing') end
    check(not RA.MarkerBindings:GetPending() and RA.MarkerBindings:GetHeldKey()==held and input:IsVisible()
        and input.allPoints==UIParent and hasVisibleText('Release '..held..' to finish cancelling. If needed, tap '..held..' again.'),path..' lost held release or cancellation hint')
    input:Fire('OnKeyDown','W');input:Fire('OnKeyUp','W')
    check(input:IsVisible() and input.propagate==false and input.propagationChanges==propagationBefore,path..' changed restricted propagation flags during drain')
    input:Fire(mouse and 'OnMouseUp' or 'OnKeyUp',mouse and 'Button4' or 'F7')
    check(not input:IsShown() and not RA.MarkerBindings:GetHeldKey() and bindingWrites==writesBefore
        and bindingSaves==savesBefore and bindingMap.F7==nil,path..' committed after cancellation or retained input capture')
    if path=='combat' then combat=false;event('PLAYER_REGEN_ENABLED') end
end
-- Recreate the actual Config module's locals while retaining SavedVariables,
-- Capture visuals refit after reopening and while shown at a new viewport.
RA:CloseConfig();UIParent:SetSize(320,480);RA:OpenConfig('WORLDMARKERS');keyButton('F8'):Fire('OnClick')
input=named.RCPArsenalMarkerBindingEditor
local captureVisual
for _,obj in ipairs(objects) do if obj.parent==input and obj.kind=='Frame' and obj.allPoints==RA.ConfigFrame then captureVisual=obj end end
check(captureVisual and captureVisual:GetScale()==RA.ConfigFrame:GetScale() and 580*captureVisual:GetScale()<=UIParent:GetWidth(), 'Reopened key dialog retained first-open scale')
local inputScale,inputPropagation=input:GetScale(),input.propagationChanges
UIParent:SetSize(640,480);event('DISPLAY_SIZE_CHANGED')
check(captureVisual:GetScale()==RA.ConfigFrame:GetScale() and 580*captureVisual:GetScale()<=UIParent:GetWidth()
    and input:GetScale()==inputScale and input.propagationChanges==inputPropagation,'Shown resize changed input guard or failed to refit visual')
check(clickVisible('CANCEL'),'Resize sample did not close')
UIParent:SetSize(1920,1080);RA:CloseConfig()
-- Recreate the actual Config module's locals while retaining SavedVariables,
-- modeling a reload without relying on its prior activeTab in memory.
RA:OpenConfig('HUD'); RA:CloseConfig()
local savedNavigation=RaidArsenalDB.navigation
check(savedNavigation.lastTab=='HUD' and savedNavigation.cooldownTab=='HUD', 'Leaf navigation was not persisted')
assert(loadfile('RCPArsenal/Config.lua'))('RCPArsenal', RA)
RA:OpenConfig()
check(hasVisibleText('HUD OPACITY') and selectedNav('AVAILABLE COOLDOWNS'), 'Module reload lost the last cooldown subtab')
check(clickNav('ADDONS & VERSIONS') and clickNav('AVAILABLE COOLDOWNS') and hasVisibleText('HUD OPACITY'), 'Cooldown sidebar reset the last subtab')
SlashCmdList.RCPARSENAL('content')
check(RaidArsenalDB.navigation.lastTab=='CONTENT', 'Explicit categories deep link ignored')
SlashCmdList.RCPARSENAL('tools'); RA:CloseConfig(); SlashCmdList.RCPARSENAL('')
check(hasVisibleText('Personal tools') and RaidArsenalDB.navigation.lastTab=='MYTOOLS', 'Close/reopen lost explicit deep-link destination')
savedNavigation.privateSentinel='PRIVATE-NAVIGATION-SENTINEL'
check(not RA:ExportProfileString():find('PRIVATE-NAVIGATION-SENTINEL',1,true), 'Portable profile includes navigation state')
RA:CloseConfig(); savedNavigation.lastTab='invalid-pane'; RA:OpenConfig()
check(hasVisibleText('Addons & versions') and savedNavigation.lastTab=='ADDONS', 'Invalid saved pane did not fall back safely')
RaidArsenalDB.navigation='invalid-state'; RA:CloseConfig(); RA:OpenConfig()
check(hasVisibleText('Addons & versions') and type(RaidArsenalDB.navigation)=='table', 'Malformed navigation state was not repaired')
RA:OpenConfig('RAIDTOOLS')
check(hasVisibleText('Addons & versions'), 'Legacy explicit raid-tools route changed')
RA:CloseConfig(); combat=true; SlashCmdList.RCPARSENAL('tools'); combat=false
check(not RA.ConfigFrame:IsShown() and RaidArsenalDB.navigation.lastTab=='ADDONS', 'Combat open mutated saved navigation')
cleanErrors()
print = nativePrint
print('PASS: ' .. checks .. ' hub/migration/quiet-lifecycle assertions (actual addon modules; offline frame mocks)')
