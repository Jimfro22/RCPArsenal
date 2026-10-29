-- Actual addon/snippet behavior in Lua 5.1. This cannot prove WoW hardware,
-- taint, cursor raycasts, native focus routing, or combat permission behavior.
local checks, actions, attempts, randomCalls = 0, {}, 0, 0
local combat, restricted, visualCall, hardware = false, false, false, false
local cursorX, cursorY, now = 960, 540, 0
local frames, named, timers, handlers, events, initializers = {}, {}, {}, {}, {}, {}
local place = 'CLICK RCPArsenalWorldMarkerCycle:LeftButton'
local clearBinding = 'CLICK RCPArsenalWorldMarkerClear:LeftButton'
local keys = {[place] = {'CTRL-F9', 'F10'}, [clearBinding] = {'F11'}}
local permitted = true
local function check(value, message) checks = checks + 1; assert(value, message) end
UIParent = {width = 1920, height = 1080}
function UIParent:GetRect() return 0, 0, self.width, self.height end
function UIParent:GetEffectiveScale() return 1 end
function UIParent:IsVisible() return true end
function GetCursorPosition() return cursorX, cursorY end
function InCombatLockdown() return combat end
function IsInRaid() return true end
function IsInGroup() return true end
function UnitIsGroupLeader() return permitted end
function UnitIsGroupAssistant() return false end
function GetBindingKey(action) return unpack(keys[action] or {}) end
for _, name in ipairs({'SetBinding', 'SaveBindings', 'SetOverrideBindingClick', 'ClearOverrideBindings', 'PlaceRaidMarker', 'RunMacroText', 'MouselookStop', 'SetCursorPosition', 'SpellTargetPosition', 'SpellTargetUnit', 'SpellStopTargeting', 'SpellIsTargeting'}) do
    _G[name] = function() error('Forbidden insecure/protected global: ' .. name) end
end
local function guard(frame)
    if frame.protected then
        check(not visualCall, 'Presentation wrote a protected frame')
        check(not combat or restricted, 'Insecure protected frame mutation in combat')
    end
end
local scope = {math = math, random = function(low, high)
    check(restricted and hardware and low == 1 and high == 8, 'Random outside the secure hardware release')
    randomCalls = randomCalls + 1
    return 6
end}
local function compile(body, signature, control)
    check(not body:find('function') and not body:find('[{}]'), 'Invalid restricted snippet syntax')
    local chunk = assert(loadstring('return function(' .. signature .. ')\n' .. body .. '\nend'))
    local env = setmetatable({control = control}, {__index = scope})
    setfenv(chunk, env)
    local fn = chunk()
    return function(...)
        local previous = restricted
        restricted = true
        local first,second,third = fn(...)
        restricted = previous
        return first,second,third
    end
end
local anchor = {BOTTOMLEFT = {0, 0}, BOTTOM = {.5, 0}, BOTTOMRIGHT = {1, 0},
    LEFT = {0, .5}, CENTER = {.5, .5}, RIGHT = {1, .5},
    TOPLEFT = {0, 1}, TOP = {.5, 1}, TOPRIGHT = {1, 1}}
function CreateFrame(kind, name, parent, templates)
    local f = {name = name, parent = parent or UIParent, protected = templates ~= nil, attrs = {}, refs = {},
        scripts = {}, wrappers = {}, postWrappers = {}, shown = true, overrides = {}, width = 1, height = 1, writes = 0}
    guard(f)
    function f:GetName() return self.name end
    function f:SetSize(w, h) guard(self); check(type(w) == 'number' and type(h) == 'number', 'Non-numeric frame dimensions'); self.width, self.height = w, h end
    function f:SetWidth(w) self:SetSize(w, self.height) end
    function f:SetHeight(h) self:SetSize(self.width, h) end
    function f:GetWidth() local _, _, w = self:GetRect(); return w end
    function f:GetHeight() local _, _, _, h = self:GetRect(); return h end
    function f:GetEffectiveScale() return 1 end
    function f:ClearAllPoints() guard(self); self.point, self.all = nil, nil end
    function f:SetAllPoints(relative) guard(self); self.all = relative or self.parent end
    function f:SetPoint(point, relative, relativePoint, x, y)
        guard(self)
        if relative == '$cursor' then relative, relativePoint, x, y = UIParent, 'BOTTOMLEFT', cursorX + x, cursorY + y end
        self.point = {point, relative or self.parent, relativePoint or point, x or 0, y or 0}
    end
    function f:GetRect()
        if self.all then return self.all:GetRect() end
        local p = self.point
        if not p then return 0, 0, self.width, self.height end
        local l, b, w, h = p[2]:GetRect()
        return l + w * anchor[p[3]][1] + p[4] - self.width * anchor[p[1]][1],
            b + h * anchor[p[3]][2] + p[5] - self.height * anchor[p[1]][2], self.width, self.height
    end
    function f:GetMousePosition()
        local l, b, w, h = self:GetRect()
        if cursorX < l or cursorY < b or cursorX > l + w or cursorY > b + h then return nil end
        return (cursorX - l) / w, (cursorY - b) / h
    end
    function f:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function f:IsShown() return self.shown end
    function f:Show() guard(self); self.shown = true end
    function f:Hide()
        guard(self); local shown = self.shown; self.shown = false
        if shown then for _, fn in ipairs(self.wrappers.OnHide or {}) do fn(self) end end
    end
    function f:EnableMouse(v) guard(self); self.mouse = v end
    function f:EnableMouseMotion(v) guard(self); self.motion = v end
    function f:SetPassThroughButtons(...) guard(self);self.passthrough={};for _,button in ipairs({...})do self.passthrough[button]=true end end
    function f:SetFrameStrata(v) guard(self); self.strata = v end
    function f:RegisterForClicks(...) guard(self); self.clicks = {...} end
    function f:RegisterEvent() end
    function f:UnregisterEvent() end
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:SetFrameRef(key, value) guard(self); self.refs[key] = value end
    function f:GetFrameRef(key) return self.refs[key] end
    function f:GetAttribute(key) return self.attrs[key] end
    function f:SetAttribute(key, value)
        guard(self); self.writes = self.writes + 1; self.attrs[key] = value
        for _, fn in ipairs(self.wrappers.OnAttributeChanged or {}) do fn(self, key, value) end
    end
    function f:RunAttribute(key, ...) return compile(assert(self.attrs[key]), 'self,...', self)(self, ...) end
    function f:SetBindingClick(priority, key, target, button)
        check(restricted and priority == true, 'Transient override outside secure path')
        self.overrides[key] = {target, button}
    end
    function f:ClearBindings() check(restricted, 'Override cleanup outside secure path'); self.overrides = {} end
    function f:CallMethod(method, ...)
        local priorRestricted, priorVisual = restricted, visualCall
        restricted, visualCall = false, true
        self[method](self, ...)
        restricted, visualCall = priorRestricted, priorVisual
        -- Blizzard CallMethod deliberately returns no values.
    end
    local function region()
        local r = CreateFrame('Frame', nil, f)
        function r:SetText(v) self.text = v end
        function r:SetTexture(v) self.texture = v end
        function r:SetColorTexture(...) self.color = {...} end
        function r:SetAlpha(v) self.alpha = v end
        return r
    end
    function f:CreateTexture() return region() end
    function f:CreateFontString() return region() end
    frames[#frames + 1] = f
    if name then named[name] = f; _G[name] = f end
    return f
end
function SecureHandlerWrapScript(frame, event, control, body, postBody)
    check(not combat, 'Installing secure wrapper in combat')
    local signature = event == 'OnClick' and 'self,button,down' or event == 'OnAttributeChanged' and 'self,name,value' or 'self'
    frame.wrappers[event] = frame.wrappers[event] or {}
    local fn = compile(body, signature, control)
    table.insert(frame.wrappers[event], 1, fn)
    if postBody then frame.postWrappers[fn] = compile(postBody, 'self,message,button,down', control) end
end
function SecureHandlerExecute(frame, body)
    check(not combat, 'Insecure Execute during combat')
    return compile(body, 'self', frame)(frame)
end
function RegisterStateDriver(frame, name, expression)
    check(not combat, 'Registering state driver in combat')
    frame.driver = expression; frame:SetAttribute('state-' .. name, 'ready')
end
function UnregisterStateDriver(frame) check(not combat, 'Removing state driver in combat'); frame.driver = nil end
C_Timer = {NewTimer = function(delay, fn)
    local timer = {delay = delay, fn = fn}
    function timer:Cancel() self.cancelled = true end
    timers[#timers + 1] = timer
    return timer
end}
local function fireTimer(timer, force)
    if force or not timer.cancelled then
        local prior = hardware; hardware = false; timer.fn(); hardware = prior
    end
end
local function loadAddon()
    local RA = {}
    assert(loadfile('RCPArsenal/Core.lua'))('RCPArsenal', RA)
    assert(loadfile('RCPArsenal/ProfileIO.lua'))('RCPArsenal', RA)
    RA.Categories, RA.CatalogByKey = {}, {}
    assert(loadfile('RCPArsenal/WorldMarkers.lua'))('RCPArsenal', RA)
    assert(loadfile(arg[1] or 'RCPArsenal/MarkerRadial.lua'))('RCPArsenal', RA)
    local eventFrame
    for _, frame in ipairs(frames) do if frame.scripts.OnEvent then eventFrame = frame end end
    eventFrame.scripts.OnEvent(eventFrame, 'ADDON_LOADED', 'RCPArsenal')
    return RA, named.RCPArsenalWorldMarkerCycle, named.RCPArsenalWorldMarkerClear, eventFrame
end
local function dispatch(frame, down, button)
    button=button or (frame==named.RCPArsenalWorldMarkerCycle and frame:GetAttribute('rcp-radial-enabled') and 'F9' or 'LeftButton')
    local old = hardware; hardware = true
    if frame.scripts.PreClick then frame.scripts.PreClick(frame,button,down) end
    local post = {}
    for _, fn in ipairs(frame.wrappers.OnClick or {}) do
        local first,message = fn(frame, button, down)
        if first == false then hardware = old; return end
        if message ~= nil and frame.postWrappers[fn] then post[#post+1] = {frame.postWrappers[fn],message} end
    end
    if frame:GetAttribute('type') and (down == frame:GetAttribute('useOnKeyDown')) then
        attempts = attempts + 1
        check(hardware, 'Protected action without actual input')
        if permitted then
            local catcher=frame:GetFrameRef('rcp-radial-root')
            actions[#actions + 1] = {frame:GetAttribute('type'), frame:GetAttribute('macrotext'), cursorX, cursorY,
                {held=frame:GetAttribute('rcp-radial-held'),catcherShown=catcher and catcher:IsShown(),overrides=next(frame.overrides)~=nil}}
        end
    end
    for _, entry in ipairs(post) do entry[1](frame,entry[2],button,down) end
    hardware = old
end
local function move(x, y)
    cursorX, cursorY = x, y
    for _, frame in ipairs(frames) do
        if frame.motion and frame:IsVisible() and frame:GetMousePosition() then
            for _, fn in ipairs(frame.wrappers.OnEnter or {}) do fn(frame) end
        end
    end
end
local function activePolling()
    local count = 0
    for _, f in ipairs(frames) do if f.scripts.OnUpdate then count = count + 1 end end
    return count
end
local function empty(t) return next(t) == nil end
RaidArsenalDB = {profile = {schemaVersion = 19}}
local RA, cycle, clear, eventFrame = loadAddon()
local function event(name) eventFrame.scripts.OnEvent(eventFrame, name) end
local function down() dispatch(cycle, true) end
local function up() dispatch(cycle, false) end
local function begin() move(960,540);down() end
local function icon(marker,phase) dispatch(named['RCPArsenalWorldMarkerIcon'..marker],phase,'LeftButton') end
local function choose(marker) icon(marker,true);icon(marker,false) end
local function routes(expected)
    for mask=0,7 do
        local prefix=''
        if mask%2==1 then prefix='SHIFT-'..prefix end
        if math.floor(mask/2)%2==1 then prefix='CTRL-'..prefix end
        if mask>=4 then prefix='ALT-'..prefix end
        for _,key in ipairs({'F9','F10'})do check(cycle.overrides[prefix..key]~=nil,'Missing complete release route '..prefix..key)end
        check((cycle.overrides[prefix..'ESCAPE']~=nil)==expected,'Wrong Escape capture')
        check((cycle.overrides[prefix..'BUTTON2']~=nil)==expected,'Wrong RMB capture')
    end
end
check(not RA.WorldMarkers:IsRadialEnabled() and not named.RCPArsenalWorldMarkerRadial,'OFF mode created wheel')
down();up();check(#actions==0,'Disabled action ran')
RA.WorldMarkers:SetEnabled(true)
down();up();check(#actions==1 and actions[1][2]=='/wm [@cursor] 1','Wheel-OFF down action changed')
RA.WorldMarkers:SetOrder({8,4});RA.WorldMarkers:SetRadialEnabled(true)
local root,cancel=named.RCPArsenalWorldMarkerRadial,named.RCPArsenalWorldMarkerCancel
check(not cycle:GetAttribute('useOnKeyDown'),'Wheel is not release-based')
local before=#actions
local router=named.RCPArsenalWorldMarkerInputRouter
check(router.overrides['CTRL-F9'][2]=='F9' and router.overrides.F10[2]=='F10','Initial native chords lack source tags')
begin();routes(true)
for marker=1,8 do
    local target=named['RCPArsenalWorldMarkerIcon'..marker]
    check(target:IsVisible() and target.mouse and target.icon.texture and target.parent==cycle:GetFrameRef('rcp-radial-center'),'Invisible/unbound icon target')
    check(target:GetAttribute('macrotext')=='/wm '..marker and target:GetAttribute('useOnKeyDown')==false,'Icon macro/phase differs')
end
check(#timers==0 and activePolling()==0 and #actions==before,'Wheel uses a timer/poll or action to open')
event('UPDATE_BINDINGS');check(cycle:GetAttribute('rcp-radial-held'),'Binding event cancelled same hold')
down();up();check(#actions==before+1 and actions[#actions][2]=='/wm [@cursor] 8','Simple/repeat-down release failed')
check(empty(cycle.overrides) and not root:IsShown(),'Release stranded controls')
before=#actions;up();check(#actions==before,'Duplicate up placed')
-- Every endpoint and duration uses the same automatic release branch. Native
-- raycast success is outside this fixture; simulated time never selects action.
for _,duration in ipairs({0.01,0.10,0.40,100})do
    for _,point in ipairs({{0,0},{30,0},{100,0},{-150,300},{500,-300},{-961,0},{961,0},{0,541}})do
        RA.WorldMarkers:SetOrder({8,4});begin();now=now+duration
        move(1100,540);move(900,700);move(960+point[1],540+point[2]);before=#actions;up()
        local last=RA.WorldMarkers:GetLastAction()
        check(#actions==before+1 and last.branch=='release' and last.macro=='/wm [@cursor] 8','Movement/duration selected reticle')
        check(not root:IsShown() and empty(cycle.overrides),'Arbitrary endpoint stranded wheel')
    end
end
combat=true
for marker=1,8 do
    begin();before=#actions;local index=cycle:GetAttribute('index')
    icon(marker,false);check(#actions==before and cycle:GetAttribute('rcp-radial-held'),'Unmatched icon up selected')
    icon(marker,true);check(#actions==before,'Icon down armed before completed click')
    icon(marker,false)
    check(#actions==before+1 and actions[#actions][2]=='/wm '..marker and cycle:GetAttribute('index')==index,'Icon did not aim exactly once without advancing sequence')
    check(not root:IsShown() and not cycle:GetAttribute('rcp-radial-held') and cycle:GetAttribute('rcp-radial-consumed'),'Icon cleanup/latch missing')
    routes(false)
    dispatch(cycle,true,'F10');dispatch(cycle,false,'F10');check(cycle:GetAttribute('rcp-radial-consumed'),'Other binding drained clicked gesture')
    down();down();icon(marker,false);check(#actions==before+1 and not root:IsShown(),'Consumed repeat reopened/placed')
    up();up();check(#actions==before+1 and empty(cycle.overrides) and not cycle:GetAttribute('rcp-radial-consumed'),'Matching release was not suppressed once')
end
begin();before=#actions;dispatch(cancel,true);down();dispatch(cycle,false,'F10')
check(#actions==before and cycle:GetAttribute('rcp-radial-consumed'),'Cancel lost original owner/repeat suppression');up()
begin();before=#actions;dispatch(cycle,true,'F10');up()
check(#actions==before+1 and cycle.overrides['ALT-SHIFT-F10'],'Secondary held key lost modifier release route')
dispatch(cycle,true,'F10');check(#actions==before+1 and not root:IsShown(),'Secondary repeat opened a new gesture')
dispatch(cycle,false,'F10');check(empty(cycle.overrides),'Secondary release did not finish draining routes')
RA.WorldMarkers:SetOrder({8,4}) -- deferred while combat; saved state must stay.
combat=false;RA.WorldMarkers:SetOrder({8,4})
-- Input ordering: key release wins before an unfinished icon click; completed
-- icon click wins before key release. Never reuse selection as an auto action.
begin();before=#actions;icon(3,true);up();icon(3,false)
check(#actions==before,'Incomplete deliberate icon press fell through to automatic placement')
begin();before=#actions;icon(1,true);icon(2,false);check(#actions==before,'Different-icon release selected');up()
check(#actions==before+1 and actions[#actions][2]:find('[@cursor]',1,true),'Mismatched icon click consumed key')
begin();before=#actions;icon(3,true);dispatch(cancel,true);icon(3,false);up()
check(#actions==before and empty(cycle.overrides),'Cancel race placed')
for mask=0,7 do
    local prefix=''
    if mask%2==1 then prefix='SHIFT-'..prefix end
    if math.floor(mask/2)%2==1 then prefix='CTRL-'..prefix end
    if mask>=4 then prefix='ALT-'..prefix end
    for _,input in ipairs({'ESCAPE','BUTTON2'})do
        begin();before=#actions;local target=cycle.overrides[prefix..input]
        dispatch(named[target[1]],true);up();dispatch(cancel,false);up()
        check(#actions==before and empty(cycle.overrides) and not root:IsShown(),'Modified cancel placed/stranded')
    end
end
begin();before=#actions;move(8,8);dispatch(root,true,'RightButton');up()
check(#actions==before and empty(cycle.overrides),'Direct fullscreen RMB failed')
begin();before=#actions;restricted=true;root:Hide();restricted=false;up()
check(#actions==before and empty(cycle.overrides),'Native root hide failed cancellation')
begin();choose(3);before=#actions;restricted=true;cycle:SetAttribute('state-rcp-radial-context','blocked');restricted=false;dispatch(cycle,true,'F10');dispatch(cycle,false,'F10');check(cycle:GetAttribute('rcp-radial-consumed'),'Other binding drained cancelled gesture');up()
check(#actions==before and empty(cycle.overrides) and not cycle:GetAttribute('rcp-radial-consumed'),'Blocked context stranded consumed release')
down();check(not root:IsShown(),'Blocked context opened wheel')
restricted=true;cycle:SetAttribute('state-rcp-radial-context','ready');restricted=false
for _,selected in ipairs({false,true})do
    begin();if selected then choose(3)end;before=#actions;dispatch(clear,true);up()
    check(#actions==before+1 and actions[#actions][1]=='worldmarker' and empty(cycle.overrides),'Clear failed held/consumed cleanup')
end
-- The icon geometry is a click target, never a release classifier. Reject a
-- stale click after display geometry changes, without issuing a fallback.
begin();before=#actions;UIParent.width=1280;choose(3);up();UIParent.width=1920
check(#actions==before and empty(cycle.overrides),'Stale icon geometry selected')
permitted=false;begin();before=#actions;choose(3);up()
check(#actions==before and attempts>#actions and empty(cycle.overrides),'Permission simulation bypassed or stranded')
check(RA.WorldMarkers:GetPermissionText():find('Requires raid leader',1,true),'Missing permission explanation')
permitted=true
keys[place]={'BUTTON4','ALT-BUTTON5'};event('UPDATE_BINDINGS');move(960,540);dispatch(cycle,true,'BUTTON4')
check(cycle.overrides.BUTTON4 and cycle.overrides['ALT-BUTTON5'] and root.passthrough.Button4,'Side-button release route missing')
choose(3);check(cycle.overrides['CTRL-BUTTON4'] and cycle.overrides['ALT-SHIFT-BUTTON5'] and not cycle.overrides.ESCAPE,'Consumed side-button route/cancel capture wrong');dispatch(cycle,false,'BUTTON4')
keys[place]={'CTRL-F9','F10'};event('UPDATE_BINDINGS')
for _,alias in ipairs({'LeftButton','RightButton','Button1','BUTTON2','ALT-RightButton','SHIFT-MouseWheelUp'})do
    keys[place]={alias,'F10'};event('UPDATE_BINDINGS')
    check(not RA.WorldMarkers:IsRadialEnabled() and RA:GetDB().worldMarkers.radialEnabled,'Unsupported alias armed hold')
end
keys[place]={'CTRL-F9','F10'};event('UPDATE_BINDINGS')
local editor={pending=true}
function editor:GetPending()return self.pending and {}or nil end
function editor:GetHeldKey()return nil end
RA.MarkerBindings=editor;RA:FireCallback('MARKER_BINDINGS_CHANGED');before=#actions;begin();up();dispatch(clear,true)
check(#actions==before and cycle:GetAttribute('rcp-input-suppressed'),'Editor guard failed')
editor.pending=false;RA:FireCallback('MARKER_BINDINGS_CHANGED')
RA.WorldMarkers:SetInputSuppressed(true,'placement');before=#actions;begin();up();check(#actions==before,'Placement guard failed')
RA.WorldMarkers:SetInputSuppressed(false,'placement')
RA.WorldMarkers:SetOrder({});before=#actions;begin();move(1200,700);up()
check(#actions==before and RA.WorldMarkers:GetLastAction().branch=='release-blocked' and empty(cycle.overrides),'Empty release did not no-op')
begin();choose(1);up();check(actions[#actions][2]=='/wm 1','Icon depends on sequence membership')
local settings=RA:GetDB().worldMarkers;local exported=assert(RA:ExportProfileString());RA:ImportProfileString(exported)
check(RA:GetDB().worldMarkers==settings and settings.radialEnabled and #settings.order==0,'Portable profile replaced local marker settings')
RA.WorldMarkers:SetRadialEnabled(false)
check(not RA.WorldMarkers:IsRadialEnabled() and empty(cycle.overrides) and #timers==0 and activePolling()==0,'OFF retained work')
RA:ResetProfile();check(not RA:GetDB().worldMarkers.enabled and not RA.WorldMarkers:IsRadialEnabled(),'Profile reset armed feature')
RA.WorldMarkers:SetEnabled(true);RA.WorldMarkers:SetRadialEnabled(true);RA.WorldMarkers:SetOrder({})
local loaded,loadedCycle=loadAddon()
check(loaded.WorldMarkers:IsRadialEnabled() and #loaded:GetDB().worldMarkers.order==0,'Reload lost local wheel choice')
loaded:ResetProfile();check(not loaded.WorldMarkers:IsRadialEnabled() and not loadedCycle:GetAttribute('type'),'Reload reset failed')
check(randomCalls==0 and #timers==0 and activePolling()==0,'Wheel added random/timed/polling action selection')
print('PASS: '..checks..' click-wheel/profile/input assertions (offline; native hardware/taint/click-through acceptance pending)')
