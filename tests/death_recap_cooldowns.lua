-- Actual recorder callback integration; public userdata mocks, no native execution.
local f=assert(io.open('tests/death_recap.lua'));local source=f:read('*a');f:close()
source=source:sub(1,assert(source:find('check(optionalCount()==0',1,true))-1)
source=source..[=[
local subscriptionCount=#subscriptions
assert(loadfile('RCPArsenal/DeathRecapDebug.lua'))('RCPArsenal',RA)
local D=RA.DeathRecapDebug
check(#subscriptions==subscriptionCount,'Diagnostic added an event subscriber')
GetBuildInfo=function()return '12.1.5','70688','fixture',120105 end
check(not D:StartCooldownCapture()and #timers==0,'Disabled observer armed or scheduled')
R:SetOption('enabled',true)
check(not D:StartCooldownCapture(),'Unlearned Mirror Image armed')
RA.DeathRecapCatalog.entries[2]={key='mage_mirror_image',spellID=55342,name='Mirror Image',class='WARRIOR',specs={73},knownSpellIDs={55342},verified=true}
C_Spell.GetBaseSpell=function(id)return id==6655342 and 55342 or id end
R:Refresh()
local observer;for _,subscription in ipairs(subscriptions)do if subscription.event=='SPELL_UPDATE_COOLDOWN'then observer=subscription end end
local enableObserver=observer.SetEnabled;observer.SetEnabled=nil
check(not D:StartCooldownCapture(),'Unavailable existing observer handle allowed arm');observer.SetEnabled=enableObserver
local calls,methodCalls,insideCooldown,beforeEventTimers=0,{},false,0
local returnedObjects=setmetatable({},{__mode='v'})
local factoryMode='public'
local function object(h,a,z)
 local value=newproxy(true);local meta=getmetatable(value)
 meta.__index={HasSecretValues=function()methodCalls[#methodCalls+1]='secret';return h end,
  IsActive=function()methodCalls[#methodCalls+1]='active';return a end,IsZero=function()methodCalls[#methodCalls+1]='zero';return z end}
 meta.__tostring=function()error('Duration stringified')end;meta.__eq=function()error('Duration compared')end
 returnedObjects[#returnedObjects+1]=value;return value
end
C_Spell.GetSpellCooldownDuration=function(id,ignoreGCD)
 calls=calls+1;check(insideCooldown and ignoreGCD==true,'Duration query escaped direct callback or ignored GCD flag')
 check(id==55342 or id==6655342,'Duration query used unrelated ID')
 check(#timers==beforeEventTimers,'Duration query ran after scheduling deferred work')
 if factoryMode=='nil'then return nil elseif factoryMode=='secret'then return secret
 elseif factoryMode=='error'then error(secret)elseif factoryMode=='table'then return{}elseif factoryMode=='number'then return 1
 elseif factoryMode=='predicate-errors'then local v=newproxy(true);getmetatable(v).__index={HasSecretValues=function()error(secret)end,IsActive=function()return nil end,IsZero=function()return 0 end};return v
 elseif factoryMode=='secret-predicate'then return object(true,secret,false)
 elseif factoryMode=='deadline'then time=time+21;return object(false,false,true)
 elseif factoryMode=='backwards'then time=time-1;return object(false,true,false)end
 return object(true,false,false)
end
local function cd(...)
 insideCooldown=true;beforeEventTimers=#timers;event('SPELL_UPDATE_COOLDOWN',...);insideCooldown=false
end
local function report()return assert(D:BuildCooldownCaptureText())end
local function has(text,part)return text:find(part,1,true)~=nil end
local function timeout()for i=#timers,1,-1 do if timers[i].delay==20 then return timers[i]end end end
local b,t,subscriptionsBefore=bagReads,#timers,optionalCount()
check(D:StartCooldownCapture(),'Learned idle observer could not arm')
local firstTimeout=timeout()
check(#timers==t+1 and firstTimeout.delay==20 and calls==0 and bagReads==b and optionalCount()==subscriptionsBefore,'Arming queried or created polling/subscriptions')
local partial=report();check(has(partial,'PARTIAL IMMUTABLE COPY')and has(partial,'queryAttempts=0'),'Armed copy missing partial status')
combat=true;event('PLAYER_REGEN_DISABLED')
check(has(report(),'active=true'),'Combat entry cancelled pre-combat arm')
time=11;cooldown={isEnabled=true,isActive=true,isOnGCD=false}
cd(55342,55342,0,0,nil)
check(calls==1 and #methodCalls==3 and table.concat(methodCalls,',')=='secret,active,zero','Immediate predicate order changed')
local first=report();check(has(first,'factoryStatus="public-userdata"')and has(first,'durationIsActive=false durationIsActiveStatus="public"')and has(first,'isOnGCD=false'),'Public false or userdata was rejected')
check(has(first,'arg1 value=55342')and has(first,'clientBuild="70688"')and has(first,'preReceiptSamples=true postReceiptSamples=false'),'Event/build/receipt provenance missing')
collectgarbage('collect');check(next(returnedObjects)==nil,'Diagnostic retained duration userdata')
time=11.1;event('UNIT_SPELLCAST_SUCCEEDED','player','mirror',55342)
check(calls==1,'Cast receipt queried duration')
time=11.2;cd(nil,nil,nil,nil,nil)
check(calls==2 and has(report(),'preReceiptSamples=true postReceiptSamples=true')and has(report(),'RECEIPT sequence=2'),'Refresh-all or shared receipt sequence missing')
check(partial~=report()and has(partial,'queryAttempts=0'),'Previously displayed string mutated')
local before=calls;cd(secret,55342);cd(12345,12345);event('SPELL_UPDATE_CHARGES')
check(calls==before and has(report(),'ambiguousOrUnmatchedSkipped=2'),'Opaque/unmatched/generic event queried duration')
for _,timer in ipairs(timers)do if not timer.cancelled and(timer.delay==.1 or timer.repeating)then fire(timer)end end
event('PLAYER_TARGET_CHANGED');check(calls==before and has(report(),'active=true'),'Generic timer queried duration or target change cancelled capture')
D:StopCooldownCapture('explicit-stop');local stopped=report();cd(55342,55342);fire(firstTimeout,true)
check(calls==before and report()==stopped,'Stopped capture or old timeout mutated result')
-- Replacing an owner defeats an old finalize callback; timeout never samples.
check(D:StartCooldownCapture());local old=timeout();check(D:StartCooldownCapture());fire(old,true)
check(has(report(),'active=true')and calls==before,'Old owner timeout affected new capture')
local currentTimeout=timeout();time=time+20;fire(currentTimeout,true)
check(has(report(),'stopReason="timeout"')and calls==before,'Timeout queried or failed to finalize')
-- Every attempted factory result consumes one slot, including nil/errors.
for _,mode in ipairs({'nil','secret','error','table','number','predicate-errors','secret-predicate'})do
 factoryMode=mode;check(D:StartCooldownCapture());cd(55342,55342)
 local expected=({['nil']='not-returned',secret='restricted',error='factory-error',table='unexpected-type',number='unexpected-type'})[mode]
 if expected then check(has(report(),'factoryStatus="'..expected..'"'),'Factory boundary failed: '..mode)
 elseif mode=='predicate-errors'then check(has(report(),'hasSecretValuesStatus="method-error"')and has(report(),'durationIsActiveStatus="not-returned"')and has(report(),'durationIsZeroStatus="unexpected-type"'),'Method failure/nil/wrong type became Boolean')
 else check(has(report(),'hasSecretValues=true')and has(report(),'durationIsActiveStatus="restricted"')and has(report(),'durationIsZero=false durationIsZeroStatus="public"'),'Secret predicate leaked or prevented later public predicate')end
end
local trust=issecretvalue
factoryMode='public';check(D:StartCooldownCapture())
issecretvalue=function(value)if type(value)=='userdata'then error('Guard failed')end;return trust(value)end
cd(55342,55342);issecretvalue=trust
check(has(report(),'factoryStatus="guard-unavailable"'),'Failed object secrecy guard was not explicit')
local opaqueResult={};local originalFactory=C_Spell.GetSpellCooldownDuration
C_Spell.GetSpellCooldownDuration=function(id,ignoreGCD)
 calls=calls+1;check(insideCooldown and ignoreGCD==true,'Guard-result probe escaped callback');return object(true,opaqueResult,false)
end
check(D:StartCooldownCapture())
issecretvalue=function(value)if rawequal(value,opaqueResult)then error('Guard failed')end;return trust(value)end
cd(55342,55342);issecretvalue=trust;C_Spell.GetSpellCooldownDuration=originalFactory
check(has(report(),'durationIsActiveStatus="guard-unavailable"')and has(report(),'durationIsZero=false durationIsZeroStatus="public"'),'Failed predicate guard leaked value or blocked independent later result')
factoryMode='nil';check(D:StartCooldownCapture());local capBefore=calls
for i=1,40 do cd(55342,55342)end
check(calls-capBefore==32 and has(report(),'queryAttempts=32')and has(report(),'retainedSnapshots=32')and has(report(),'stopReason="sample-cap"'),'Attempt cap exceeded or failed attempts were free')
factoryMode='public';check(D:StartCooldownCapture());time=time+20;local deadlineCalls=calls;cd(55342,55342)
check(calls==deadlineCalls and has(report(),'stopReason="timeout"'),'At-deadline event queried')
check(D:StartCooldownCapture());factoryMode='deadline';cd(55342,55342)
check(has(report(),'retainedSnapshots=1')and has(report(),'stopReason="timeout"'),'Query completion past deadline left capture active')
check(D:StartCooldownCapture());factoryMode='backwards';cd(55342,55342)
check(has(report(),'stopReason="clock-unavailable"'),'Clock going backwards during query left capture active')
factoryMode='public';check(D:StartCooldownCapture());time=time-1;local clockCalls=calls;cd(55342,55342)
check(calls==clockCalls and has(report(),'stopReason="clock-unavailable"'),'Clock going backwards before query was accepted')
-- Unchanged roster preserves the arm; actual resolved/base or spec change stops.
check(D:StartCooldownCapture());event('SPELLS_CHANGED');check(has(report(),'active=true'),'Unchanged roster cancelled capture')
override=6655342;RA.DeathRecapCatalog.entries[2].knownSpellIDs={55342,6655342};event('SPELLS_CHANGED')
check(has(report(),'stopReason="identity-changed"'),'Changed resolved identity did not stop')
check(D:StartCooldownCapture());cd(449336,55342);cd(6655342,nil)
check(has(report(),'resolvedSpellID=6655342')and has(report(),'queryAttempts=2'),'Resolved identity/base match not honored')
local specFunction=GetSpecializationInfo;GetSpecializationInfo=function()return 62 end;event('PLAYER_SPECIALIZATION_CHANGED','player')
check(has(report(),'stopReason="identity-changed"'),'Spec change did not stop')
GetSpecializationInfo=specFunction;override=nil;event('SPELLS_CHANGED')
check(D:StartCooldownCapture());event('PLAYER_REGEN_ENABLED');check(has(report(),'stopReason="combat-ended"'),'Combat end did not stop')
combat=false;R:Refresh();check(D:StartCooldownCapture());event('PLAYER_REGEN_ENABLED')
check(has(report(),'active=true'),'Spurious combat end cancelled arm that had not entered combat')
combat=true;event('PLAYER_REGEN_DISABLED');dead=true;event('PLAYER_DEAD')
check(has(report(),'stopReason="own-death"'),'Own death did not stop')
local frozen=assert(R:BuildDebugText());local noQueries=calls;report();D:StopCooldownCapture('explicit-stop')
check(calls==noQueries and R:BuildDebugText()==frozen,'Show/stop changed capture or queried duration')
dead=false;combat=false;event('PLAYER_ALIVE');check(D:StartCooldownCapture());event('PLAYER_ENTERING_WORLD')
check(has(report(),'stopReason="world-transition"'),'World transition did not stop')
check(D:StartCooldownCapture());RA:FireCallback('PROFILE_RESET')
check(has(report(),'stopReason="profile-reset"'),'Profile reset did not stop')
check(D:StartCooldownCapture());R:SetOption('enabled',false)
check(has(report(),'stopReason="disabled"'),'Disable did not stop')
local priorTime=GetTime;GetTime=function()return secret end;R:SetOption('enabled',true)
check(not D:StartCooldownCapture(),'Opaque arm time accepted');GetTime=priorTime
local oldTrust=issecretvalue;issecretvalue=nil
check(not D:StartCooldownCapture(),'Absent secrecy guard armed capture');issecretvalue=oldTrust
check(#subscriptions==subscriptionCount,'Capture added subscriptions')
print('PASS: '..checks..' bounded cooldown capability assertions (offline)')
]=]
assert(loadstring(source,'death-recap-cooldowns-fixture'))()
