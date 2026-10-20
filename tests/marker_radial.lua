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
for _, name in ipairs({'SetBinding', 'SaveBindings', 'SetOverrideBindingClick', 'ClearOverrideBindings', 'PlaceRaidMarker', 'RunMacroText', 'MouselookStop', 'SetCursorPosition', 'SpellTargetPosition'}) do
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
        local result = fn(...)
        restricted = previous
        return result
    end
end
local anchor = {BOTTOMLEFT = {0, 0}, BOTTOM = {.5, 0}, BOTTOMRIGHT = {1, 0},
    LEFT = {0, .5}, CENTER = {.5, .5}, RIGHT = {1, .5},
    TOPLEFT = {0, 1}, TOP = {.5, 1}, TOPRIGHT = {1, 1}}
function CreateFrame(kind, name, parent, templates)
    local f = {name = name, parent = parent or UIParent, protected = templates ~= nil, attrs = {}, refs = {},
        scripts = {}, wrappers = {}, shown = true, overrides = {}, width = 1, height = 1, writes = 0}
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
function SecureHandlerWrapScript(frame, event, control, body)
    check(not combat, 'Installing secure wrapper in combat')
    local signature = event == 'OnClick' and 'self,button,down' or event == 'OnAttributeChanged' and 'self,name,value' or 'self'
    frame.wrappers[event] = frame.wrappers[event] or {}
    table.insert(frame.wrappers[event], 1, compile(body, signature, control))
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
    assert(loadfile('RCPArsenal/MarkerRadial.lua'))('RCPArsenal', RA)
    local eventFrame
    for _, frame in ipairs(frames) do if frame.scripts.OnEvent then eventFrame = frame end end
    eventFrame.scripts.OnEvent(eventFrame, 'ADDON_LOADED', 'RCPArsenal')
    return RA, named.RCPArsenalWorldMarkerCycle, named.RCPArsenalWorldMarkerClear, eventFrame
end
local function dispatch(frame, down, button)
    button=button or 'LeftButton'
    local old = hardware; hardware = true
    for _, fn in ipairs(frame.wrappers.OnClick or {}) do
        if fn(frame, button, down) == false then hardware = old; return end
    end
    if frame:GetAttribute('type') and (down == frame:GetAttribute('useOnKeyDown')) then
        attempts = attempts + 1
        check(hardware, 'Protected action without actual input')
        if permitted then actions[#actions + 1] = {frame:GetAttribute('type'), frame:GetAttribute('macrotext'), cursorX, cursorY} end
    end
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
local function resetCursor() move(960, 540) end
check(not RA.WorldMarkers:IsRadialEnabled() and not named.RCPArsenalWorldMarkerRadial, 'Fresh/off config created or armed the wheel')
check(#timers == 0 and activePolling() == 0, 'Off state has background timer/polling')
down(); up(); check(#actions == 0, 'Disabled action placed a marker')
RA.WorldMarkers:SetEnabled(true)
down(); up(); check(#actions == 1 and actions[1][2] == '/wm [@cursor] 1', 'Legacy sequence behavior changed')
RA.WorldMarkers:SetOrder({8, 4})
check(RA.WorldMarkers:SetRadialEnabled(true), 'Could not opt into radial mode')
check(RA.WorldMarkers:IsRadialEnabled() and not cycle:GetAttribute('useOnKeyDown'), 'Wheel did not use release action')
local root, cancel = named.RCPArsenalWorldMarkerRadial, named.RCPArsenalWorldMarkerCancel
check(root.mouse and root.clicks[1]=='RightButtonDown' and root.clicks[2]=='RightButtonUp' and root.passthrough.LeftButton and root.passthrough.MiddleButton and root.passthrough.Button4 and root.passthrough.Button31 and not root.passthrough.RightButton,'Full-screen right-click catcher stole other mouse buttons or registered wrong phase')
local previous = #actions
down(); check(#actions == previous and cycle:GetAttribute('rcp-radial-held'), 'Keydown placed or failed to latch')
event('UPDATE_BINDINGS')
check(cycle:GetAttribute('rcp-radial-held'), 'Unchanged/transient binding event cancelled a native hold')
check(cycle.overrides.F9 and cycle.overrides['ALT-CTRL-SHIFT-F9'] and cycle.overrides.F10, 'Modifier release routes missing')
check(cycle.overrides.ESCAPE[1] == cancel.name and cycle.overrides.BUTTON2[1] == cancel.name, 'Cancel overrides missing')
local tapTimer = timers[#timers]
up(); check(#actions == previous and cycle:GetAttribute('macrotext')==nil, 'Center tap placed or retained a marker')
check(not root:IsShown() and empty(cycle.overrides) and tapTimer.cancelled, 'Tap left hold UI/overrides/timer')
fireTimer(tapTimer, true); check(activePolling() == 0 and #actions == previous, 'Stale display timer rearmed or placed')
up(); check(#actions == previous, 'Repeated key-up placed twice')
resetCursor(); down(); local heldTimer = timers[#timers]
down(); check(timers[#timers] == heldTimer, 'Repeated down restarted hold')
combat = true
fireTimer(heldTimer)
check(activePolling() == 1 and #actions == previous, 'Display timer placed a marker or failed to display')
up(); check(#actions==previous and activePolling()==0 and cycle:GetAttribute('macrotext')==nil, 'Stationary displayed hold placed or retained a marker')
for marker = 1, 8 do
    resetCursor(); down()
    local angle = (marker - 1) * math.pi / 4
    move(960 + math.sin(angle) * 120, 540 + math.cos(angle) * 120)
    local before = #actions
    up()
    check(#actions == before + 1 and actions[#actions][2] == '/wm [@cursor] ' .. marker, 'Wrong radial sector ' .. marker)
    check(actions[#actions][3] == cursorX and actions[#actions][4] == cursorY, 'Placement did not use release-position cursor')
    check(empty(cycle.overrides) and not root:IsShown(), 'Sector release stranded state')
end
resetCursor(); down(); move(1100, 540); move(960, 540)
previous = #actions; up()
check(#actions == previous and not cycle:GetAttribute('rcp-radial-held'), 'Return to center failed to cancel')
for _, input in ipairs({'ESCAPE', 'BUTTON2'}) do
    resetCursor(); down(); move(960, 660)
    local target = cycle.overrides[input]
    dispatch(named[target[1]], true); dispatch(cancel, false); up()
    check(#actions == previous and empty(cycle.overrides) and not root:IsShown(), 'Cancel then release placed: ' .. input)
end
-- Test all cancel modifier chords independently of the full-screen pointer
-- path; CTRL-F9 commonly leaves Ctrl held during the right-click.
for mask=0,7 do
    local prefix=''
    if mask%2==1 then prefix='SHIFT-'..prefix end
    if math.floor(mask/2)%2==1 then prefix='CTRL-'..prefix end
    if mask>=4 then prefix='ALT-'..prefix end
    for _,input in ipairs({'ESCAPE','BUTTON2'}) do
        resetCursor();down();move(1100,660)
        local target=cycle.overrides[prefix..input]
        check(target and target[1]==cancel.name,'Missing modified cancel override: '..prefix..input)
        local pending=timers[#timers]
        dispatch(named[target[1]],true);up();dispatch(cancel,false);up()
        check(#actions==previous and not root:IsShown() and not cycle:GetAttribute('rcp-radial-held')
            and cycle:GetAttribute('macrotext')==nil and empty(cycle.overrides) and pending.cancelled and activePolling()==0,
            'Modified cancel left a release action/state: '..prefix..input)
    end
end
-- Model the registered direct RightButton path at center, sector, viewport
-- edge and outside the drawn wheel. Native focus/camera routing is acceptance.
local pointerCases={{960,540,false},{960,540,true},{1080,540,true},{8,8,true},{1910,1070,true}}
for _,entry in ipairs(pointerCases) do
    resetCursor();down();local pending=timers[#timers]
    if entry[3] then fireTimer(pending) end
    move(entry[1],entry[2])
    for _,frame in ipairs(frames)do if frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame,0.05) end end
    dispatch(root,true,'RightButton')
    check(#actions==previous and not root:IsShown() and not cycle:GetAttribute('rcp-radial-held')
        and cycle:GetAttribute('macrotext')==nil and empty(cycle.overrides) and activePolling()==0,'Full-screen right-click failed center/sector/outside cancellation')
    dispatch(root,false,'RightButton');up();up();fireTimer(pending,true)
    check(#actions==previous and not root:IsShown() and activePolling()==0,'Right-click or stale timer rearmed a later release')
end
-- Every no-sector release has identical protected behavior, independent of
-- visual delay, long hold, prior sector and exactly-on-boundary cursor jitter.
for _,offset in ipairs({{0,0},{22,22},{-22,-22},{-22,22}}) do
    for _,displayed in ipairs({false,true}) do
        resetCursor();down();local pending=timers[#timers]
        if displayed then fireTimer(pending) end
        move(960+offset[1],540+offset[2]);up()
        check(#actions==previous and cycle:GetAttribute('macrotext')==nil and empty(cycle.overrides) and not root:IsShown(),
            'Center/deadzone release placed a random marker or stranded state')
    end
end
check(randomCalls==0,'Wheel center path still invokes random placement')
resetCursor(); down(); restricted = true; root:Hide(); restricted = false; up()
check(#actions == previous and empty(cycle.overrides), 'Native overlay/UI hide did not reset protected hold')
resetCursor(); down(); local secure = restricted; restricted = true
cycle:SetAttribute('state-rcp-radial-context', 'blocked'); restricted = secure
up(); check(#actions == previous and empty(cycle.overrides), 'Context cancellation placed/stranded overrides')
down(); check(not cycle:GetAttribute('rcp-radial-held'), 'Blocked context opened a wheel')
restricted = true; cycle:SetAttribute('state-rcp-radial-context', 'ready'); restricted = false
resetCursor(); down(); dispatch(clear, true); dispatch(clear, false); up()
check(#actions == previous + 1 and actions[#actions][1] == 'worldmarker' and empty(cycle.overrides), 'Separate clear did not cancel a pending wheel exactly once')
previous = #actions
check(not RA.WorldMarkers:SetRadialEnabled(false) and RA:GetDB().worldMarkers.radialEnabled, 'Combat setter changed saved mode')
resetCursor(); down(); fireTimer(timers[#timers])
for _, frame in ipairs(frames) do if frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, 11) end end
check(activePolling() == 0 and #actions == previous, 'Lost-release preview did not stop or placed automatically')
local recovery
for _, frame in ipairs(frames) do
    if frame.text == 'Release the marker key or press Escape' and frame:IsVisible() then recovery = true end
end
check(recovery and cycle:GetAttribute('rcp-radial-held') and not empty(cycle.overrides), 'Stopped preview hid the active-hold recovery cue')
event('PLAYER_LEAVING_WORLD'); event('PLAYER_ENTERING_WORLD')
recovery = false
for _, frame in ipairs(frames) do
    if frame.text == 'Release the marker key or press Escape' and frame:IsVisible() then recovery = true end
end
check(recovery and activePolling() == 0, 'Combat world return left invisible active overrides or restarted polling')
dispatch(cancel, true); up(); check(empty(cycle.overrides) and #actions == previous, 'Lost-release Escape recovery placed')
permitted = false
resetCursor(); down(); move(1080, 540); up()
check(#actions == previous and attempts > #actions, 'Permission simulation was bypassed')
check(RA.WorldMarkers:GetPermissionText():find('Requires raid leader', 1, true), 'Permission explanation missing')
permitted, combat = true, false
keys[place]={'BUTTON4','ALT-BUTTON5'};event('UPDATE_BINDINGS')
check(RA.WorldMarkers:IsRadialEnabled(),'Supported side-mouse aliases lost wheel mode')
resetCursor();down();move(1080,540)
check(cycle.overrides.BUTTON4 and cycle.overrides['ALT-BUTTON5'] and root.passthrough.Button4 and root.passthrough.Button5,
    'Right-click catcher swallowed side-button release routes')
local sideCancel=cycle.overrides['ALT-CTRL-BUTTON2'];dispatch(named[sideCancel[1]],true);up()
check(#actions==previous and empty(cycle.overrides) and not root:IsShown(),'Modified cancel after side-button hold left a marker action')
keys[place]={'CTRL-F9','F10'};event('UPDATE_BINDINGS')
for _, alias in ipairs({'LeftButton', 'RightButton', 'Button1', 'Button2', 'BUTTON1', 'BUTTON2', 'CTRL-LeftButton', 'ALT-RightButton', 'SHIFT-MouseWheelUp'}) do
    keys[place] = {alias, 'F10'}; event('UPDATE_BINDINGS')
    check(not RA.WorldMarkers:IsRadialEnabled() and RA:GetDB().worldMarkers.radialEnabled, 'Unsupported Blizzard primary/pulse alias armed a hold: ' .. alias)
end
keys[place] = {'MOUSEWHEELUP', 'F10'}; event('UPDATE_BINDINGS')
check(not RA.WorldMarkers:IsRadialEnabled() and RA:GetDB().worldMarkers.radialEnabled, 'Pulse alias did not safely preserve requested mode and fall back')
check(RA.WorldMarkers:GetRadialStatusText():find('real release', 1, true), 'Pulse fallback status missing')
down(); check(not cycle:GetAttribute('rcp-radial-held') and empty(cycle.overrides) and activePolling() == 0, 'Pulse binding stranded a hold without key-up')
keys[place] = {'CTRL-F9', 'F10'}; event('UPDATE_BINDINGS')
check(RA.WorldMarkers:IsRadialEnabled(), 'Supported bindings did not restore requested mode')
local editor = {pending = true, held = nil}
function editor:GetPending() return self.pending and {} or nil end
function editor:GetHeldKey() return self.held end
RA.MarkerBindings = editor
RA:FireCallback('MARKER_BINDINGS_CHANGED')
previous = #actions; down(); up(); dispatch(clear, true)
check(#actions == previous and cycle:GetAttribute('rcp-input-suppressed') and clear:GetAttribute('rcp-input-suppressed'), 'Key editor failed to suppress both actions')
editor.pending, editor.held = false, 'F9'; RA:FireCallback('MARKER_BINDINGS_CHANGED')
down(); up(); check(#actions == previous, 'Captured key released into a marker')
combat = true; editor.held = nil; RA:FireCallback('MARKER_BINDINGS_CHANGED')
down(); up(); check(#actions == previous and cycle:GetAttribute('rcp-input-suppressed'), 'Combat guard removal mutated protected input')
combat = false; event('PLAYER_REGEN_ENABLED')
check(not cycle:GetAttribute('rcp-input-suppressed'), 'Deferred editor guard failed to recover')
RA.WorldMarkers:SetOrder({})
resetCursor(); down(); move(960, 660); up()
check(actions[#actions][2] == '/wm [@cursor] 1', 'Wheel incorrectly depended on ordinary sequence order')
local settings = RA:GetDB().worldMarkers
local exported = assert(RA:ExportProfileString())
check(not exported:find('worldMarkers'), 'Local wheel choice leaked into portable profile')
RA:ImportProfileString(exported)
check(RA:GetDB().worldMarkers == settings and settings.radialEnabled and #settings.order == 0, 'Portable import replaced local choice or empty order')
RA.WorldMarkers:SetRadialEnabled(false)
check(not RA.WorldMarkers:IsRadialEnabled() and empty(cycle.overrides) and activePolling() == 0 and not cycle.driver, 'Turning off left active work')
down(); up(); check(#RA:GetDB().worldMarkers.order == 0 and not cycle:GetAttribute('rcp-radial-held'), 'Off wheel refilled/ran an empty sequence')
RA:ResetProfile()
check(not RA:GetDB().worldMarkers.enabled and not RA.WorldMarkers:IsRadialEnabled(), 'Profile reset left feature armed')
RA.WorldMarkers:SetEnabled(true); RA.WorldMarkers:SetRadialEnabled(true); RA.WorldMarkers:SetOrder({})
local loaded, loadedCycle = loadAddon()
check(loaded.WorldMarkers:IsRadialEnabled() and loaded:GetDB().worldMarkers.radialEnabled
    and #loaded:GetDB().worldMarkers.order == 0, 'Reload lost explicit wheel choice or empty sequence')
loaded:ResetProfile()
check(not loaded.WorldMarkers:IsRadialEnabled() and not loadedCycle:GetAttribute('type'), 'Reloaded profile reset failed to disarm')
check(keys[place][1] == 'CTRL-F9' and keys[place][2] == 'F10', 'Wheel changed saved native keys')
print('PASS: ' .. checks .. ' wheel/profile/input assertions (offline Lua; native hardware/taint/combat acceptance pending)')
