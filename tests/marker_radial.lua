-- Actual addon/snippet behavior in Lua 5.1. This cannot prove WoW hardware,
-- taint, cursor raycasts, native focus routing, or combat permission behavior.
local checks, actions, attempts, randomCalls = 0, {}, 0, 0
local combat, restricted, visualCall, hardware = false, false, false, false
local cursorX, cursorY, now = 960, 540, 0
local frames, named, timers, handlers, events, initializers = {}, {}, {}, {}, {}, {}
local place = 'CLICK RCPArsenalWorldMarkerCycle:LeftButton'
local clearBinding = 'CLICK RCPArsenalWorldMarkerClear:LeftButton'
local wheelBinding = 'CLICK RCPArsenalWorldMarkerWheel:LeftButton'
local keys = {[place] = {'CTRL-F9', 'F10'}, [clearBinding] = {'F11'}, [wheelBinding] = {}}
local permitted = true
local function check(value, message) checks = checks + 1; assert(value, message) end
UIParent = {left=0,bottom=0,width = 1920, height = 1080,scale=1}
function UIParent:GetRect() return self.left,self.bottom,self.width,self.height end
function UIParent:GetEffectiveScale() return self.scale end
function issecretvalue()return false end
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
    function f:GetEffectiveScale() return (self.scale or 1)*self.parent:GetEffectiveScale() end
    function f:SetScale(v)guard(self);self.scale=v end
    function f:ClearAllPoints() guard(self); self.point, self.all = nil, nil end
    function f:SetAllPoints(relative) guard(self); self.all = relative or self.parent end
    function f:SetPoint(point, relative, relativePoint, x, y)
        guard(self)
        if relative == '$cursor' then relative, relativePoint, x, y = UIParent, 'BOTTOMLEFT', cursorX + x, cursorY + y end
        self.point = {point, relative or self.parent, relativePoint or point, x or 0, y or 0}
    end
    function f:GetRect()
        local scale=self:GetEffectiveScale()
        if self.all then
            local l,b,w,h=self.all:GetRect();local ratio=self.all:GetEffectiveScale()/scale
            return l*ratio,b*ratio,w*ratio,h*ratio
        end
        local p=self.point
        if not p then return 0,0,self.width,self.height end
        local l,b,w,h=p[2]:GetRect();local relativeScale=p[2]:GetEffectiveScale()
        return ((l+w*anchor[p[3]][1])*relativeScale+p[4]*scale-self.width*scale*anchor[p[1]][1])/scale,
            ((b+h*anchor[p[3]][2])*relativeScale+p[5]*scale-self.height*scale*anchor[p[1]][2])/scale,self.width,self.height
    end
    function f:GetMousePosition()
        local l,b,w,h=self:GetRect();local scale=self:GetEffectiveScale()
        local x,y=cursorX/scale,cursorY/scale
        if x<l or y<b or x>l+w or y>b+h then return nil end
        return (x-l)/w,(y-b)/h
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
    button=button or 'LeftButton'
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
RaidArsenalDB = {profile = {schemaVersion = 19,worldMarkers={enabled=true,radialEnabled=true,order={1,2,3,4,5,6,7,8}}}}
local RA,cycle,clear,eventFrame=loadAddon()
local function event(name)eventFrame.scripts.OnEvent(eventFrame,name)end
local function point(x,y)move((UIParent.left+x)*UIParent.scale,(UIParent.bottom+y)*UIParent.scale)end
local function primary()dispatch(cycle,true);dispatch(cycle,false)end
check(cycle:GetAttribute('useOnKeyDown')==true and not RA.WorldMarkers:IsRadialEnabled(),'Legacy wheel toggle changed instant phase')
check(not named.RCPArsenalWorldMarkerRadial and not named.RCPArsenalWorldMarkerInputRouter and #keys[wheelBinding]==0,'Upgrade assigned/created wheel or router')
local before=#actions
for _,offset in ipairs({{0,0},{900,500},{-1200,-800},{2000,3000}})do
    point(960,540);dispatch(cycle,true);move(cursorX+offset[1],cursorY+offset[2]);dispatch(cycle,false)
    check(#actions==before+1 and actions[#actions][2]:find('/wm [@cursor] ',1,true)==1,'Moving primary tap did not place on down')
    before=#actions
end
check(empty(cycle.overrides) and activePolling()==0 and #timers==0,'Primary installed routes or visual work')
keys[wheelBinding]={'F12','SHIFT-F12'};event('UPDATE_BINDINGS')
local wheel=named.RCPArsenalWorldMarkerWheel;local root=named.RCPArsenalWorldMarkerRadial
check(wheel and RA.WorldMarkers:IsRadialEnabled() and not wheel:GetAttribute('useOnKeyDown'),'Separate binding did not enable release action')
check(cycle:GetAttribute('useOnKeyDown') and RA.WorldMarkers:GetNextMarker(),'Wheel disabled instant state/next display')
local function begin(x,y)point(x or 960,y or 540);dispatch(wheel,true)end
local function finish()dispatch(wheel,false)end
local function previewTick(elapsed)for _,f in ipairs(frames)do if f.scripts.OnUpdate then f.scripts.OnUpdate(f,elapsed or 0)end end end
begin();before=#actions;primary()
check(#actions==before+1 and actions[#actions][2]:find('[@cursor]',1,true) and wheel:GetAttribute('rcp-wheel-held'),'Primary failed while separate wheel open')
check(empty(cycle.overrides) and not wheel.overrides.F9 and not wheel.overrides.F10 and not wheel.overrides.F11,'Wheel captured primary/Clear')
finish();check(#actions==before+1 and empty(wheel.overrides) and not root:IsShown() and activePolling()==0,'Center release placed or stranded work')
local expectedIcons={6,4,3,7,1,2,5,8}
-- Actual rendered centers, non-unit effective scales, viewport offsets, edges.
for _,scale in ipairs({0.64,0.8,1,1.25})do
    UIParent.scale=scale
    for _,offset in ipairs({{0,0},{80,-40}})do
        UIParent.left,UIParent.bottom=offset[1],offset[2]
        for _,origin in ipairs({{960,540},{8,8},{1912,1072}})do
            for marker=1,8 do
                begin(origin[1],origin[2]);local center=wheel:GetFrameRef('center');local art=center.slots[marker]
                check(art.mouse==false and art.icon.texture=='Interface\\TargetingFrame\\UI-RaidTargetingIcon_'..expectedIcons[marker],'World ID/artwork order mismatch')
                local l,b,w,h=art:GetRect();move((l+w/2)*art:GetEffectiveScale(),(b+h/2)*art:GetEffectiveScale());previewTick()
                local inside=root:GetMousePosition()~=nil
                for id,slot in ipairs(center.slots)do check(slot.highlight.alpha==((inside and id==marker)and 1 or 0),'Preview/secure sector disagreement')end
                before=#actions;finish()
                check(#actions==before+(inside and 1 or 0),'Outside/release action count mismatch')
                if inside then check(actions[#actions][2]=='/wm '..marker and RA.WorldMarkers:GetLastAction().marker==marker,'Rendered icon selected wrong world-marker ID')end
                check(not root:IsShown() and empty(wheel.overrides) and activePolling()==0,'Sector retained captures before ground input')
                dispatch(wheel,false);check(#actions==before+(inside and 1 or 0),'Duplicate up repeated targeting')
            end
        end
    end
end
UIParent.scale,UIParent.left,UIParent.bottom=1,0,0
before=#actions
for _,p in ipairs({{0,0},{28,0},{-28,0},{0,28}})do begin();point(960+p[1],540+p[2]);finish();check(#actions==before,'Center radius did not cancel')end
for _,kind in ipairs({'left','bottom','width','height','scale'})do
    begin();point(1052,540);local old=UIParent[kind];UIParent[kind]=old+(kind=='scale'and 0.1 or 20);previewTick()
    for _,slot in ipairs(wheel:GetFrameRef('center').slots)do check(slot.highlight.alpha==0,'Stale geometry retained active highlight')end
    finish();check(#actions==before and empty(wheel.overrides),'Changed viewport/scale armed a marker');UIParent[kind]=old
end
for _,combatValue in ipairs({false,true})do
    combat=combatValue
    for mask=0,7 do
        local prefix=''
        if mask%2==1 then prefix='SHIFT-'..prefix end
        if math.floor(mask/2)%2==1 then prefix='CTRL-'..prefix end
        if mask>=4 then prefix='ALT-'..prefix end
        for _,cancelKey in ipairs({'ESCAPE','BUTTON2'})do
            begin();point(1052,540);local target=wheel.overrides[prefix..cancelKey]
            check(target and wheel.overrides[prefix..'F12'],'Missing modified wheel/cancel route')
            dispatch(named[target[1]],true);dispatch(wheel,true)
            check(not root:IsShown() and wheel:GetAttribute('rcp-wheel-cancelled') and not wheel.overrides.ESCAPE and not wheel.overrides.BUTTON2,'Cancel reopened or retained native target keys')
            finish();check(#actions==before and empty(wheel.overrides) and activePolling()==0,'Cancelled release placed/stranded')
        end
    end
end
combat=false
begin();point(1052,540);dispatch(root,true,'RightButton');finish();check(#actions==before,'Direct RMB cancellation placed')
begin();restricted=true;root:Hide();restricted=false;dispatch(wheel,true);finish();check(#actions==before and empty(wheel.overrides),'Native hide/repeat rearmed')
begin();restricted=true;wheel:SetAttribute('state-rcp-wheel-context','blocked');restricted=false;finish();check(#actions==before and empty(wheel.overrides),'Context cancel placed')
restricted=true;wheel:SetAttribute('state-rcp-wheel-context','ready');restricted=false
begin();dispatch(clear,true);finish();check(#actions==before+1 and actions[#actions][1]=='worldmarker' and empty(wheel.overrides),'Clear failed to cancel wheel');before=#actions
-- Pause only cosmetic polling; explicitly keep the armed-state cue honest.
begin();point(1052,540);previewTick(11)
check(activePolling()==0 and wheel:GetFrameRef('center').choice.text=='Preview paused; wheel armed','Preview timeout falsely claims disabled action')
for _,slot in ipairs(wheel:GetFrameRef('center').slots)do check(slot.highlight.alpha==0,'Paused preview kept selected highlight')end
dispatch(named.RCPArsenalWorldMarkerCancel,true);finish();check(#actions==before,'Paused preview cancellation placed')
-- Unsafe same-base chords and distinct alternative wheel bases never steal
-- instant/Clear, nor are they automatically reassigned.
for _,binding in ipairs({{'SHIFT-F9'},{'CTRL-F11'},{'F12','F13'},{'MOUSEWHEELUP'},{'RightButton'}})do
    keys[wheelBinding]=binding;event('UPDATE_BINDINGS');check(not RA.WorldMarkers:IsRadialEnabled(),'Unsafe wheel keys enabled')
    primary();before=before+1;check(#actions==before and empty(wheel.overrides) and not root:IsShown(),'Unsafe wheel config stole primary')
end
local getKeys,isSecret=GetBindingKey,issecretvalue
local secret={}
for _,which in ipairs({place,clearBinding})do
    for _,kind in ipairs({'throw','secret','number','extra'})do
        keys[wheelBinding]={'F12'}
        issecretvalue=function(value)return rawequal(value,secret)end
        GetBindingKey=function(action)
            if action==which then
                if kind=='throw'then error('Unreadable keys')elseif kind=='secret'then return secret
                elseif kind=='number'then return 42 else return 'F9',nil,'F13'end
            end
            return getKeys(action)
        end
        event('UPDATE_BINDINGS');check(not RA.WorldMarkers:IsRadialEnabled() and empty(wheel.overrides),'Unreadable instant/Clear keys left wheel enabled: '..kind)
        primary();before=before+1;check(#actions==before and cycle:GetAttribute('useOnKeyDown'),'Unreadable wheel binding snapshot broke instant')
        GetBindingKey,issecretvalue=getKeys,isSecret;event('UPDATE_BINDINGS')
    end
end
keys[wheelBinding]={'F12'}
for _,which in ipairs({place,clearBinding})do
    local saved=keys[which];keys[which]={};event('UPDATE_BINDINGS')
    check(RA.WorldMarkers:IsRadialEnabled(),'Known nil unbound keys were treated as unreadable')
    keys[which]=saved;event('UPDATE_BINDINGS')
end
keys[wheelBinding]={'BUTTON4'};event('UPDATE_BINDINGS');check(RA.WorldMarkers:IsRadialEnabled(),'Side-button wheel unavailable')
begin();check(wheel.overrides['ALT-CTRL-BUTTON4'] and root.passthrough.Button4,'Side-button release route/catcher wrong');finish();check(empty(wheel.overrides),'Side-button center left routes')
RA.WorldMarkers:SetOrder({});before=#actions;primary();check(#actions==before and RA.WorldMarkers:GetLastAction().branch=='cursor-blocked','Empty instant order did not no-op')
begin();point(1052,540);finish();check(#actions==before+1 and actions[#actions][2]=='/wm 3','Independent wheel depended on instant order');before=#actions
RA.WorldMarkers:SetInputSuppressed(true,'placement');begin();primary();finish();check(#actions==before and not root:IsShown(),'Placement guard failed')
RA.WorldMarkers:SetInputSuppressed(false,'placement')
RA.WorldMarkers:SetRadialEnabled(false);check(not RA.WorldMarkers:IsRadialEnabled() and not root:IsShown() and empty(wheel.overrides),'Wheel OFF did not clean up')
RA.WorldMarkers:SetOrder({8});primary();check(actions[#actions][2]=='/wm [@cursor] 8' and cycle:GetAttribute('useOnKeyDown'),'Wheel OFF altered instant')
check(keys[place][1]=='CTRL-F9' and keys[place][2]=='F10' and keys[clearBinding][1]=='F11','Saved primary/Clear keys changed')
check(not named.RCPArsenalWorldMarkerInputRouter and not named.RCPArsenalWorldMarkerIcon1 and #timers==0 and randomCalls==0,'Retired architecture/timer remains')
RA:ResetProfile();check(not RA.WorldMarkers:IsRadialEnabled() and not root:IsShown() and empty(wheel.overrides),'Profile reset left wheel active')
print('PASS: '..checks..' separate-wheel/instant/isolation/scaled-art/cancel assertions (offline; native acceptance pending)')
