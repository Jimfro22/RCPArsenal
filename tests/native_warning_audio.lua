-- Actual guarded native audio module, public-state mocks; no native raid/taint claim.
local checks=0
local secret=setmetatable({}, {__tostring=function() error('secret conversion') end,__lt=function() error('secret comparison') end})
function issecretvalue(v) return rawequal(v,secret) end
local function check(v,m) checks=checks+1;assert(v,m) end
local native, audio, RA, events, callbacks, initializers, registry, parent
local master, sound, mode, combat, alive, cvar, panel, cinematic, movie
local plays, stops, calls, result, soundHandle, cvarError, panelError, registryFail
local function Eligibility()
    if not master then return false,'Reminder is off.' end
    if not sound then return false,'Sound is off.' end
    if mode=='IN' and combat~=true or mode=='OUT' and combat~=false then return false,'Hidden by combat setting.' end
    if alive~=true then return false,'Player dead or life state unknown.' end
    return true
end
function GetCVarBool(name)
    calls.cvar=calls.cvar+1;check(name=='doNotFlashLowHealthWarning','Unexpected CVar read')
    if cvarError then error('blocked') end;return cvar
end
function GetUIPanel(name)
    calls.panel=calls.panel+1;check(name=='fullscreen','Unexpected panel read')
    if panelError then error('blocked') end;return panel
end
function PlaySound(...)
    local args={...};check(#args==1 and args[1]==12889,'Only built-in kit/default parameters allowed')
    plays[#plays+1]=args
    if result=='error' then error('blocked') end
    return result,soundHandle
end
function StopSound(handle)
    check(not issecretvalue(handle) and type(handle)=='number' and handle>=100,'Stopped an unowned/nonpublic handle')
    stops[#stops+1]=handle
end
for _,name in ipairs({'UnitHealth','UnitHealthMax','UnitHealthPercent','UseItemByName','NotifyInspect','SetCVar','PlaySoundFile'}) do
    _G[name]=function() error('Forbidden audio work: '..name) end
end
C_Timer={NewTimer=function() error('No audio timer') end,NewTicker=function() error('No polling') end,After=function() error('No delayed retry') end}
C_Container=setmetatable({}, {__index=function() error('No bag access') end})
local function Frame(shown)
    local f={shown=shown,hooks={},hookResults={OnShow=true,OnHide=true},hookCalls=0}
    function f:HookScript(script,fn)
        check(script=='OnShow' or script=='OnHide','Unexpected native hook')
        self.hookCalls=self.hookCalls+1
        local r=self.hookResults[script]
        if r=='error' then error('binding blocked') end
        -- Model partial installation even for an indeterminate return.
        if r~=false then self.hooks[script]=self.hooks[script] or {};table.insert(self.hooks[script],fn) end
        return r
    end
    function f:IsShown()
        calls.shown=calls.shown+1
        if self.shownError then error('restricted') end
        return self.shown
    end
    function f:IsVisible()
        calls.visible=calls.visible+1
        if self.visibleError then error('restricted') end
        if self.visibleOverride~=nil then return self.visibleOverride end
        if issecretvalue(self.shown) then return secret end
        return self.shown and parent or false
    end
    function f:Fire(script) for _,fn in ipairs(self.hooks[script] or {}) do fn(self) end end
    function f:Show() self.shown=true;self:Fire('OnShow') end
    function f:Hide() self.shown=false;self:Fire('OnHide') end
    for _,name in ipairs({'SetScript','SetParent','SetAlpha','GetAlpha','GetEffectiveAlpha','GetHealthPercent','DetermineFlashState','SetAttribute','SetForbidden','RegisterEvent'}) do
        f[name]=function() error('Native mutation/health/alpha: '..name) end
    end
    return f
end
local function Setup(options)
    options=options or {}
    master,sound,mode,combat,alive,cvar,panel,cinematic,movie=options.enabled or false,true,options.mode or 'BOTH',false,true,false,nil,nil,nil
    parent=true
    plays,stops,calls,events,callbacks,initializers,registry={},{},{shown=0,visible=0,cvar=0,panel=0,parent=0},{},{},{},{}
    result,soundHandle,cvarError,panelError,registryFail=true,100,false,false,options.registryFail
    SOUNDKIT={ALARM_CLOCK_WARNING_3=12889}
    UIParent={IsVisible=function() calls.parent=calls.parent+1;return parent end}
    CinematicFrame,MovieFrame=nil,nil
    EventRegistry={RegisterCallback=function(_,name,fn,owner)
        if registryFail==name then error('subscription failed') end
        registry[name]=registry[name] or {};table.insert(registry[name],{fn,owner})
    end}
    native=Frame(options.shown or false)
    if options.hookResults then native.hookResults=options.hookResults end
    if options.missing then LowHealthFrame=nil else LowHealthFrame=native end
    if options.noRegistry then EventRegistry=nil end
    RA={PersonalTools={GetNativeSoundEligibility=Eligibility,IsNativeSoundOptedIn=function() return master and sound end}}
    function RA:RegisterEvent(name,fn) events[name]=fn end
    function RA:RegisterCallback(name,fn) callbacks[name]=fn end
    function RA:RegisterInitializer(fn) initializers[#initializers+1]=fn end
    assert(loadfile('RCPArsenal/NativeWarningAudio.lua'))('RCPArsenal',RA)
    audio=RA.NativeWarningAudio
    for _,fn in ipairs(initializers) do fn() end
    if not options.beforeWorld then
        events.PLAYER_ENTERING_WORLD()
        -- Model an explicit stable-world enable for episode tests. Bootstrap
        -- and world-order tests below exercise the silent baseline separately.
        callbacks.PERSONAL_TOOLS_CHANGED('consumableReminder')
    end
end
local function Option(key) callbacks.PERSONAL_TOOLS_CHANGED(key) end
local function ParentEvent(name)
    for _,entry in ipairs(registry[name] or {}) do entry[1](entry[2]) end
end
local function Reads() return calls.shown+calls.visible+calls.cvar+calls.panel+calls.parent end
Setup()
check(native.hookCalls==0 and Reads()==0 and #plays==0,'Fresh OFF did native work')
check(events.UNIT_HEALTH==nil and events.UNIT_MAXHEALTH==nil and events.BAG_UPDATE_DELAYED==nil,'Audio subscribed to health/bags')
for i=1,20 do audio:GetStatusText() end
check(Reads()==0 and #plays==0,'Status rendering read native state')
events.CVAR_UPDATE('CVAR_UPDATE','doNotFlashLowHealthWarning')
check(audio:GetStatusText()=='Reminder is off.' and Reads()==0,'Disabled CVar callback advertised enabled sound')
check(audio:Preview() and #plays==1 and not master and native.hookCalls==0,'Preview changed opt-in/binding')
for _,r in ipairs({false,secret,'error'}) do result=r;check(not audio:Preview(),'Preview claimed playback acceptance') end
result=nil;check(not audio:Preview(),'Nil playback acceptance claimed success')
local before=#plays;SOUNDKIT=nil;check(not audio:Preview() and #plays==before,'Missing kit tried playback')
SOUNDKIT={ALARM_CLOCK_WARNING_3=secret};check(not audio:Preview() and #plays==before,'Secret kit tried playback')

Setup({enabled=true})
check(native.hookCalls==2 and #registry['UI.TopLevelParentShown']==1 and #plays==0,'One lazy additive binding required')
local before=Reads();Option('reminderIconSize');Option('healthThreshold');Option('reminderStoneText')
check(Reads()==before,'Appearance/visual threshold rearmed/read native warning')
native:Show();check(#plays==1,'Eligible clear to shown did not play once')
for i=1,10 do native:Fire('OnShow') end
check(#plays==1,'Duplicate shown callbacks replayed')
local before=Reads();for i=1,20 do audio:GetStatusText() end
check(Reads()==before,'Status is not cached')
native:Hide();native:Show();check(#plays==2,'Genuine clear did not rearm')
check(#stops==1 and stops[1]==100,'New owned clip did not stop only its predecessor')

Setup({enabled=true,shown=true})
check(#plays==0,'Already shown baseline beeped')
native:Fire('OnShow');check(#plays==0,'Already shown duplicate beeped')
native:Hide();native:Show();check(#plays==1,'Initial-shown episode never rearmed after clear')
master=false;Option('consumableReminder');check(#stops==1,'Master disable did not stop owned handle')
local before=Reads();native:Hide();native:Show();check(Reads()==before and #plays==1,'Disabled hooks did native work')
master=true;Option('consumableReminder');check(#plays==1 and native.hookCalls==2,'Re-enable caught up or rebound hooks')
native:Hide();native:Show();check(#plays==2,'Re-enabled clear episode did not play')
sound=false;Option('reminderSound');sound=true;Option('reminderSound');check(#plays==2,'Audio OFF/ON while shown caught up')
callbacks.PROFILE_RESET();check(#plays==2,'Profile reset while shown caught up')
native:Hide();native:Show();check(#plays==3,'Profile-reset clear did not rearm')

Setup({enabled=true})
native:Show();parent=false;native:Fire('OnHide');ParentEvent('UI.TopLevelParentHidden')
parent=true;native:Fire('OnShow');ParentEvent('UI.TopLevelParentShown')
check(#plays==1,'Parent-only hide/show created another warning episode')
native:Hide();native:Show();check(#plays==2,'Parent re-entry did not recover after true own clear')

-- Native parent/world handlers may update their own state after ours.
Setup({enabled=true})
parent=false;ParentEvent('UI.TopLevelParentHidden');native.shown=false
parent=true;ParentEvent('UI.TopLevelParentShown');native:Show()
check(#plays==0,'Parent restoration armed from stale pre-native hidden state')
native:Hide();native:Show();check(#plays==1,'Parent re-entry failed after genuine clear')
Setup({enabled=true,beforeWorld=true})
check(native.hookCalls==2 and Reads()==0 and #plays==0,'Bootstrap failed OOC binding or observed/played before world entry')
events.PLAYER_ENTERING_WORLD();native:Show()
check(#plays==0,'World entry armed from stale pre-native hidden state')
native:Hide();native:Show();check(#plays==1,'World entry did not recover after clear')

for _,case in ipairs({'cvar','fullscreen','cinematic','movie','secret shown','secret visible','shown error','visible error','cvar error','panel error','secret parent','secret panel','secret cinematic'}) do
    Setup({enabled=true})
    if case=='cvar' then cvar=true
    elseif case=='fullscreen' then panel={}
    elseif case=='cinematic' then CinematicFrame={IsShown=function() return true end}
    elseif case=='movie' then MovieFrame={IsShown=function() return true end}
    elseif case=='secret shown' then native.shown=secret
    elseif case=='secret visible' then native.visibleOverride=secret
    elseif case=='shown error' then native.shownError=true
    elseif case=='visible error' then native.visibleError=true
    elseif case=='cvar error' then cvarError=true
    elseif case=='panel error' then panelError=true
    elseif case=='secret parent' then parent=secret
    elseif case=='secret panel' then panel=secret
    elseif case=='secret cinematic' then CinematicFrame=secret end
    if case~='secret shown' then native.shown=true end
    native:Fire('OnShow');check(#plays==0,'Suppressed/unreadable case beeped: '..case)
    cvar,panel,CinematicFrame,MovieFrame,cvarError,panelError,parent=false,nil,nil,nil,false,false,true
    native.shown,native.visibleOverride,native.shownError,native.visibleError=true,nil,false,false
    native:Fire('OnShow');check(#plays==0,'Restored already-shown state caught up: '..case)
    native:Hide();native:Show();check(#plays==1,'Readable clear did not recover: '..case)
end

for _,key in ipairs({'OnShow','OnHide'}) do
    for _,r in ipairs({false,secret,'error','nil'}) do
        local returns={OnShow=true,OnHide=true};returns[key]=r=='nil' and nil or r
        -- Lua's and/or nil idiom cannot represent nil; set it explicitly.
        if r=='nil' then returns[key]=nil end
        Setup({enabled=true,hookResults=returns})
        local before=Reads();native:Show();native:Hide();native:Show()
        check(#plays==0 and Reads()==before,'Partial/failed binding became active')
        events.PLAYER_ENTERING_WORLD();check(native.hookCalls==2,'Failed binding duplicated native listeners')
    end
end
Setup({enabled=true,noRegistry=true});native:Show();check(#plays==0,'Missing parent callbacks still activated audio')

Setup({enabled=true,registryFail='UI.TopLevelParentShown'})
local before=Reads();native:Show();check(#plays==0 and Reads()==before,'Partial parent subscription became active')
registryFail=nil;events.PLAYER_ENTERING_WORLD()
check(native.hookCalls==2 and #registry['UI.TopLevelParentHidden']==1 and #registry['UI.TopLevelParentShown']==1,'Controlled parent callback retry duplicated listeners')
native:Hide();native:Show();check(#plays==1,'Controlled parent callback retry failed')

Setup({enabled=true,missing=true})
check(native.hookCalls==0,'Missing frame bound')
LowHealthFrame=native;events.PLAYER_REGEN_DISABLED();check(native.hookCalls==0,'Missing-frame retry ran on combat lifecycle')
events.PLAYER_ENTERING_WORLD();check(native.hookCalls==2 and #plays==0,'Explicit world retry failed')
events.PLAYER_ENTERING_WORLD();check(native.hookCalls==2,'World entry duplicated hooks')

Setup({enabled=true})
mode='IN';combat=false;Option('reminderCombat')
combat=true;native:Show() -- native hook may run before addon combat event.
events.PLAYER_REGEN_DISABLED();check(#plays==0,'Eligibility transition caught up before addon event')
native:Hide();native:Show();check(#plays==1,'In-combat clear episode failed')
mode='OUT';Option('reminderCombat');combat=false;events.PLAYER_REGEN_ENABLED()
check(#plays==1,'Mode return while already shown caught up')
native:Hide();native:Show();check(#plays==2,'OOC clear episode failed')
alive=false;events.PLAYER_DEAD();check(#stops>=2,'Death did not stop owned playback')
alive=true;events.PLAYER_ALIVE();check(#plays==2,'Alive while shown caught up')

Setup({enabled=true})
cvar=true;events.CVAR_UPDATE('CVAR_UPDATE','doNotFlashLowHealthWarning');native:Show()
cvar=false;events.CVAR_UPDATE('CVAR_UPDATE','doNotFlashLowHealthWarning');native:Fire('OnShow')
check(#plays==0,'CVar off/on while warning active caught up')
native:Hide();native:Show();check(#plays==1,'CVar suppression did not recover after clear')
local before=Reads();events.CVAR_UPDATE('CVAR_UPDATE','unrelated');events.CVAR_UPDATE('CVAR_UPDATE',secret)
check(Reads()==before,'Unrelated/secret CVar event read native state')

-- Binding is opt-in, independent from combat-only playback eligibility.
Setup({enabled=true,mode='IN'})
check(native.hookCalls==2 and Reads()==0 and #plays==0,'In-combat-only opt-in did not bind out of combat')
combat=true;events.PLAYER_REGEN_DISABLED();native:Show();check(#plays==1,'Prebound in-combat warning did not play')
-- Incidental automatic callbacks cannot stop an independent manual preview.
Setup({enabled=true});master=false;Option('consumableReminder')
soundHandle=200;audio:Preview();local beforeStops=#stops
native:Show();parent=false;ParentEvent('UI.TopLevelParentHidden');native:Fire('OnHide')
parent=true;ParentEvent('UI.TopLevelParentShown');events.PLAYER_REGEN_DISABLED()
check(#stops==beforeStops,'Automatic lifecycle stopped a manual preview with master OFF')
check(audio:GetStatusText()=='Reminder is off.','Disabled parent callback advertised enabled sound')
audio:Preview();check(#stops==beforeStops+1 and stops[#stops]==200,'A new manual preview did not stop only its own predecessor')

Setup({enabled=true});result=false;native:Show();check(#plays==1,'Playback attempt missing')
result=true;native:Fire('OnShow');check(#plays==1,'Playback failure retried same episode')
native:Hide();native:Show();check(#plays==2,'Failure never recovered for a new episode')
local before=#plays;audio:Preview();native:Fire('OnShow');check(#plays==before+1,'Preview rearmed the automatic latch')
Setup({enabled=true});soundHandle=secret;native:Show();master=false;Option('consumableReminder')
check(#stops==0,'Secret sound handle was stopped')
print('PASS: '..checks..' native-warning audio assertions (actual module; offline mocks, native acceptance pending)')
