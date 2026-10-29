-- Actual editor transaction module; native input capture/taint acceptance pending.
local checks=0
local function check(v,m) checks=checks+1;assert(v,m) end
local secret=setmetatable({}, {__eq=function() error('secret equality') end,__lt=function() error('secret comparison') end,__tostring=function() error('secret conversion') end})
function issecretvalue(v) return rawequal(v,secret) end
local place='CLICK RCPArsenalWorldMarkerCycle:LeftButton'
local clear='CLICK RCPArsenalWorldMarkerClear:LeftButton'
local wheel='CLICK RCPArsenalWorldMarkerWheel:LeftButton'
local combat,scope,context,store,order,writes,saves,events,callbacks,RA,editor
local failWrite,failSave,secretRead,modifiers,handlers
function InCombatLockdown() return combat end
function GetCurrentBindingSet() return scope end
C_KeyBindings={GetBindingContextForAction=function() return context end}
function GetBindingKey(action,ignored,ctx)
    check(ignored==nil and ctx==context,'Wrong binding context on key read')
    local result={}
    for _,key in ipairs(order) do if store[key]==action then result[#result+1]=key end end
    return unpack(result)
end
function GetBindingAction(key,overrides,ctx)
    check(overrides==false and ctx==context,'Scope passed as context or override mapping used')
    if secretRead then return secret end
    return store[key] or ''
end
function GetBindingName(action) return action=='JUMP' and 'Jump' or action end
local function change(key,action)
    for index=#order,1,-1 do if order[index]==key then table.remove(order,index) end end
    store[key]=action
    if action then order[#order+1]=key end
end
function SetBinding(key,action,ctx)
    check(combat==false and ctx==context,'Binding mutation in combat or wrong context')
    writes[#writes+1]={key,action,ctx}
    if failWrite then local failed=failWrite;failWrite=nil;if failed=='error' then error('write error') end;return failed end
    change(key,action)
    if events.UPDATE_BINDINGS then events.UPDATE_BINDINGS() end
    return true
end
function SaveBindings(set)
    check(combat==false and set==scope,'Wrong account/character scope on save')
    saves[#saves+1]=set
    if failSave then failSave=nil;error('save error') end
    -- Real native call has no return, not boolean true.
end
for _,name in ipairs({'LoadBindings','SetBindingClick','SetOverrideBinding','SetOverrideBindingClick','ClearOverrideBindings','RunBinding'}) do
    _G[name]=function() error('Forbidden global reset/override/action') end
end
function GetConvertedKeyOrButton(input) return input=='Button4' and 'BUTTON4' or input end
function IsKeyPressIgnoredForBinding(key) return key=='LSHIFT' or key=='LCTRL' or key=='BUTTON1' or key=='BUTTON2' or key=='UNKNOWN' end
function CreateKeyChordStringUsingMetaKeyState(key) return (modifiers or '')..key end
local function setup()
    combat,scope,context=false,1,nil
    store,order,writes,saves,events,callbacks={},{},{},{},{},{}
    failWrite,failSave,secretRead,modifiers=nil,nil,nil,nil
    handlers={}
    change('F9',place);change('F10',place);change('F11',clear);change('SPACE','JUMP');change('J','JUMP');change('K','OPENALLBAGS')
    RA={WorldMarkers={PlaceBinding=place,ClearBinding=clear,WheelBinding=wheel}}
    function RA:RegisterEvent(name,fn) events[name]=fn end
    function RA:RegisterCallback(name,fn) handlers[name]=fn end
    function RA:FireCallback(name) callbacks[#callbacks+1]=name end
    assert(loadfile('RCPArsenal/MarkerBindings.lua'))('RCPArsenal',RA)
    editor=RA.MarkerBindings
end
local function gesture(key)
    editor:Capture(key)
    check(#writes==0 and #saves==0,'Captured keydown mutated bindings before release')
    return editor:Release(key)
end
setup()
local state=editor:GetState(place)
check(state.keys[1]=='F9' and state.keys[2]=='F10' and state.scopeLabel=='Account keybinds' and state.editable,'Current two keys/scope missing')
check(not editor:Begin('JUMP',1) and not editor:Begin(place,3) and #writes==0,'Arbitrary action/slot accepted')
check(editor:Begin(place,1),'Begin failed')
check(not editor:Capture('LSHIFT') and editor:GetPending() and #writes==0,'Modifier-only press committed')
modifiers='ALT-CTRL-SHIFT-';editor:Capture('F8')
check(editor:GetPending().awaitingRelease and not editor:Replace() and #writes==0,'Replace bypassed matching release')
check(not editor:Release('F7') and #writes==0 and editor:GetPending(),'Wrong release ended capture')
check(editor:Release('F8') and store['ALT-CTRL-SHIFT-F8']==place and store.F10==place and store.F9==nil,'Modified key replacement lost alternate or retained old key')
check(#saves==1 and saves[1]==1 and store.K=='OPENALLBAGS','Account save failed or unrelated key changed')
setup();scope,context=2,7
check(editor:Begin(place,2) and gesture('Button4'),'Mouse/modifier conversion or character scope failed')
check(store.F9==place and store.BUTTON4==place and store.F10==nil and saves[1]==2,'Alternate slot/character scope not preserved')
setup();editor:Begin(place,1)
check(not gesture('SPACE') and editor:GetPending().conflict and editor:GetPending().conflictLabel=='Jump' and #writes==0,'Conflict mutated before confirmation')
editor:Cancel('Cancelled.');check(store.SPACE=='JUMP' and store.J=='JUMP' and #writes==0 and #saves==0,'Cancel changed conflicting bindings')
setup();editor:Begin(place,1);gesture('SPACE')
check(editor:Replace() and store.SPACE==place and store.J=='JUMP' and store.F10==place and store.K=='OPENALLBAGS','Confirmed conflict damaged other assignments')
setup();editor:Begin(place,2);gesture('F11')
check(editor:GetPending().conflictLabel=='Clear all world markers' and #writes==0,'Other Arsenal action conflict missing')
editor:Cancel();check(store.F11==clear and #saves==0,'Other marker conflict cancel wrote keys')
setup();editor:Begin(place,1);editor:Capture('ESCAPE')
check(editor:GetPending() and #writes==0,'Escape cancelled before consuming release')
editor:Release('ESCAPE');check(not editor:GetPending() and #saves==0,'Escape did not cancel cleanly')
setup();editor:Begin(place,1);editor:Capture('F8');combat=true;events.PLAYER_REGEN_DISABLED();combat=false
check(not editor:GetPending() and editor:GetHeldKey()=='F8' and editor:IsHeldRelease('F8')
    and not editor:IsHeldRelease('F7'),'Combat cancellation lost matching release identity')
check(not editor:Release('F8') and not editor:GetHeldKey() and #writes==0 and #saves==0,'Combat deferred a captured assignment')
setup();editor:Begin(place,1);editor:Capture('F8');handlers.PROFILE_RESET()
check(not editor:GetPending() and editor:GetHeldKey()=='F8' and not editor:Release('F8')
    and #writes==0 and #saves==0,'Profile reset committed a captured assignment')
setup();combat=secret;check(not editor:Begin(place,1) and #writes==0,'Unknown combat accepted')
setup();editor:Begin(place,1);editor:Capture('F8');scope=2
check(not editor:Release('F8') and #writes==0,'Changed scope was silently switched/saved')
setup();editor:Begin(place,1);editor:Capture('F8');change('F9','JUMP')
check(not editor:Release('F8') and #writes==0,'Stale target keys overwritten')
setup();editor:Begin(place,1);editor:Capture('F8');events.UPDATE_BINDINGS()
check(not editor:GetPending() and #writes==0,'External binding event retained stale capture')
setup();editor:Begin(place,1);secretRead=true
check(not gesture('F8') and #writes==0 and #saves==0,'Unreadable conflict treated as unbound')
setup();editor:Begin(place,1);gesture('SPACE');change('SPACE','OPENALLBAGS')
check(not editor:Replace() and editor:GetPending().conflictLabel=='OPENALLBAGS' and #writes==0,'Changed conflict overwrote a new action without confirmation')
setup();editor:Begin(place,1)
check(not gesture('F10') and store.F9==place and store.F10==place and #writes==0,'Other slot key was silently moved')
setup();check(editor:Clear(place,1) and store.F9==nil and store.F10==place and #saves==1,'Unbind lost alternate key')
setup();failWrite=false
-- Explicit false and error on a write must fail, restore only touched mappings,
-- and leave all unrelated assignments and secure actions alone.
for _,failure in ipairs({'false','error','secret'}) do
    setup();editor:Begin(place,1);editor:Capture('F8')
    failWrite=failure=='false' and false or failure=='secret' and secret or 'error'
    -- false is a value, not a disabled failure flag.
    if failure=='false' then
        local native=SetBinding;local once=true
        SetBinding=function(...) if once then once=false;return false end;return native(...) end
        check(not editor:Release('F8'),'False write claimed success');SetBinding=native
    else check(not editor:Release('F8'),'Failed write claimed success') end
    check(store.F9==place and store.F10==place and store.F8==nil and store.K=='OPENALLBAGS','Failure did not restore changed mappings')
end
setup();editor:Begin(place,1);editor:Capture('SPACE');editor:Release('SPACE');failSave=true
check(not editor:Replace() and store.SPACE=='JUMP' and store.J=='JUMP' and store.F9==place and store.F10==place,'Save error did not restore assignments')
for _,write in ipairs(writes) do check(write[1]~='J' and write[1]~='K','Rollback wrote an untouched mapping') end
check(editor:GetStatusText():find('previous bindings restored',1,true),'Verified restoration feedback missing')
setup();scope=0;check(not editor:GetState(place).editable and not editor:Begin(place,1) and #writes==0,'Unknown binding scope accepted')
setup()
check(editor:GetState(wheel).keys[1]==nil and #writes==0 and #saves==0,'New wheel key was assigned automatically')
check(editor:Begin(wheel,1) and gesture('F12'),'Optional wheel missing from editor allowlist')
check(GetBindingAction('F12',false,context)==wheel and GetBindingAction('F9',false,context)==place and GetBindingAction('F10',false,context)==place and GetBindingAction('F11',false,context)==clear,'Explicit wheel edit overwrote primary/Clear')
check(editor:Clear(wheel,1) and editor:GetState(wheel).keys[1]==nil,'Wheel inline unbind failed')
print('PASS: '..checks..' marker binding editor assertions (actual module; native capture and taint pending)')
