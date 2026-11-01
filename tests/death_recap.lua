-- Actual recorder + shared provider with bounded native mocks. No WoW claim.
local checks,time,combat,dead=0,10,false,false
local secret=setmetatable({},{__tostring=function()error('Secret stringified')end})
local function check(value,message)checks=checks+1;assert(value,message)end
function issecretvalue(value)return rawequal(value,secret)end
function GetTime()return time end
function InCombatLockdown()return combat end
function UnitIsDeadOrGhost()return dead end
function UnitGUID(unit)check(unit=='player','Remote unit query');return 'Player-self' end
function UnitClass()return 'Warrior','WARRIOR' end
function GetSpecialization()return 1 end
function GetSpecializationInfo()return 73 end
local known,passive,override=true,false,nil
function IsPlayerSpell()return known end
Enum={SpellBookSpellBank={Player=0},DamageMeterSessionType={Current=1},DamageMeterType={Deaths=9}}
local meterRows={}
C_DamageMeter={GetCombatSessionFromType=function(kind,metric)check(kind==1 and metric==9,'Wrong current meter query');return {combatSources=meterRows}end,GetCombatSessionFromID=function(id,metric)check(id==1 and metric==9,'Wrong explicit session query');return {combatSources=meterRows}end}
C_SpellBook={IsSpellKnown=function()return known end}
local cooldown={isEnabled=true,isActive=false,isOnGCD=true}
local charges,usableCalls=nil,0
C_Spell={GetSpellCooldown=function()return cooldown end,GetSpellCharges=function()return charges end,
    GetOverrideSpell=function(id)return override or id end,IsSpellPassive=function()return passive end}
local link,events='',{}
C_DeathRecap={GetRecapLink=function(id)check(type(id)=='number','Default recap getter used');return link end,HasRecapEvents=function(id)check(type(id)=='number','Default recap getter used');return #events>0 end,GetRecapEvents=function(id)check(type(id)=='number','Default recap getter used');return events end}
local bagReads,itemCalls,bagIDs=0,0,{}
C_Container={GetContainerNumSlots=function(bag)bagReads=bagReads+1;return bag==0 and #bagIDs or 0 end,
    GetContainerItemID=function(_,slot)return bagIDs[slot] end,GetContainerItemInfo=function()return {stackCount=1}end}
C_Item={GetItemCooldown=function()itemCalls=itemCalls+1;return 0,0,true end,
    IsUsableItem=function()usableCalls=usableCalls+1;check(not dead,'Queried dead-item usability');return true end}
local timers={}
local function timer(delay,fn,repeating)
    local t={delay=delay,fn=fn,repeating=repeating};function t:Cancel()self.cancelled=true end;timers[#timers+1]=t;return t
end
C_Timer={NewTimer=function(d,f)return timer(d,f,false)end,NewTicker=function(d,f)return timer(d,f,true)end}
local function fire(t,force)if force or not t.cancelled then if not t.repeating then t.cancelled=true end;t.fn()end end
local subscriptions,callbacks,initializers={},{},{}
local db={deathRecap={enabled=false,autoOpen=true},personalTools={consumableReminder=false,healthThreshold=40,reminderSound=false}}
local RA={}
function RA:GetDB()return db end
function RA:RegisterOptionalEvent(event,fn,unit)
    local s={event=event,fn=fn,enabled=false,unit=unit};function s:SetEnabled(v)self.enabled=v==true end
    subscriptions[#subscriptions+1]=s;return s
end
function RA:RegisterCallback(event,fn)callbacks[event]=callbacks[event]or{};table.insert(callbacks[event],fn)end
function RA:FireCallback(event,...)for _,fn in ipairs(callbacks[event]or{})do fn(...)end end
function RA:RegisterInitializer(fn)initializers[#initializers+1]=fn end
local function event(name,...)for _,s in ipairs(subscriptions)do if s.event==name and s.enabled then s.fn(name,...)end end end
local function optionalCount()local n=0;for _,s in ipairs(subscriptions)do if s.enabled then n=n+1 end end;return n end
RA.DeathRecapCatalog={entries={{key='shield',spellID=871,name='Shield Wall',class='WARRIOR',specs={73},knownSpellIDs={871},category='major',verified=true}},itemUseSpells={[6262]=true}}
RA.PersonalTools={SetOption=function(_,key,value)db.personalTools[key]=value;return true end}
assert(loadfile('RCPArsenal/HealingSupplies.lua'))('RCPArsenal',RA)
assert(loadfile('RCPArsenal/DeathRecapAssociation.lua'))('RCPArsenal',RA)
assert(loadfile('RCPArsenal/DeathRecap.lua'))('RCPArsenal',RA)
for _,fn in ipairs(initializers)do fn()end
local R=RA.DeathRecap
check(optionalCount()==0 and #timers==0 and bagReads==0 and R:GetPage()==nil,'OFF did work or invented death')
R:SetOption('enabled',true)
check(optionalCount()>0 and bagReads==0 and #timers==0,'Idle enable scanned bags or polled')
event('DAMAGE_METER_CURRENT_SESSION_UPDATED');event('DAMAGE_METER_COMBAT_SESSION_UPDATED',9,1)
combat=true;event('PLAYER_REGEN_DISABLED')
check(bagReads==6 and not R:GetDiagnostics().tickerActive and R:GetDiagnostics().trackedSpells==1,'Inactive cooldown baseline polled or missed local baseline')
local scans=bagReads
for i=1,100 do R:GetPage();R:GetState();R:GetDiagnostics()end
check(bagReads==scans,'Read-only rendering queried bags')
time=11;event('UNIT_SPELLCAST_SUCCEEDED','player','cast',871)
cooldown={isEnabled=true,isActive=true,isOnGCD=false};time=11.1;event('SPELL_UPDATE_COOLDOWN')
check(R:GetDiagnostics().tickerActive,'Active native cooldown lacks reconciliation')
charges={maxCharges=2,currentCharges=1,isActive=true};time=11.3;event('SPELL_UPDATE_CHARGES')
dead=true;time=12;event('PLAYER_DEAD')
local page=R:GetPage()
check(page and #page.casts==1 and page.lastAlive.spells[1].currentCharges==1,'Cast/remaining-charge evidence lost')
check(page.lastAlive.spells[1].cooldown=='active-context-unknown' and page.deathObservation.source=='death-notification','Charge-event/death evidence merged with trusted cooldown context')
check(not R:GetDiagnostics().tickerActive and not page.native,'Old/empty native recap accepted')
local firstPage=page;local timerA=timers[#timers]
local pendingAttempts=page.nativeAttempts
event('PLAYER_DEAD')
check(R:GetPage()==page and not timerA.cancelled and R:GetDiagnostics().fetchPending and page.nativeAttempts==pendingAttempts,'Duplicate death notice cancelled the pending personal recap')
meterRows={{isLocalPlayer=true,deathRecapID=1}}
link='death:1';events={{destGUID='Player-self',timestamp=100,event='SPELL_DAMAGE',spellId=123,amount=secret},
    {destGUID='Player-self',timestamp=98,event='SPELL_DAMAGE',spellId=124,amount=100}}
fire(timerA)
check(page.native and page.native.rows[1].amount==nil and page.native.rows[1].nativeIndex==1 and page.native.rows[2].nativeOffset==-2,'Fresh personal recap/Unknown amount/native killing row lost')
check(not page.native.rows[1].currentHP and not page.native.rows[1].healthPercent,'Health synthesized')
event('PLAYER_DEAD');check(R:GetPage()==page,'Duplicate death replaced frozen page')
local frozen=page.lastAlive.spells[1].cooldown
cooldown={isEnabled=true,isActive=false};charges={maxCharges=2,currentCharges=2,isActive=false}
event('SPELL_UPDATE_COOLDOWN');check(page.lastAlive.spells[1].cooldown==frozen,'Historical state refreshed after death')
dead=false;event('PLAYER_ALIVE');combat=false;event('PLAYER_REGEN_ENABLED')
check(R:GetPage()==page and not R:GetDiagnostics().tickerActive,'Resurrection discarded last valid page')
combat=true;event('PLAYER_REGEN_DISABLED');time=15;event('UNIT_SPELLCAST_SUCCEEDED','player','cast',871)
time=15.1;event('SPELL_UPDATE_COOLDOWN');dead=true;time=16;event('PLAYER_DEAD')
local second=R:GetPage();check(second~=firstPage and second.casts[1].spellID==871 and second.lastAlive.spells[1].cooldown=='inactive','Used/reset became unavailable or second death missing')
check(not second.native,'Stale prior death accepted as second death')
meterRows={{isLocalPlayer=true,deathRecapID=1},{isLocalPlayer=true,deathRecapID=2}}
link='death:foreign';events={{destGUID='Player-other',timestamp=200,event='SPELL_DAMAGE',spellId=123,amount=200}}
fire(timers[#timers]);check(not second.native,'Foreign recap accepted')
events={{destGUID='Player-self',timestamp=secret,event='SPELL_DAMAGE',spellId=123,amount=200}}
combat=false;event('PLAYER_REGEN_ENABLED');check(not second.native and second.nativeAttempts==3,'Unreadable destination or retry bound violated')
-- Invalidating shared inventory is lazy, both consumers reuse one evaluation.
dead=false;combat=false;event('PLAYER_ALIVE');RA.HealingSupplies:SetConsumer('reminder',true)
RA.HealingSupplies:InvalidateCache();local before=bagReads;bagIDs={5512};local a=RA.HealingSupplies:GetCached('reminder');local b=RA.HealingSupplies:GetCached('recap')
check(a==b and bagReads==before+6 and b.stone==true,'Independent consumers duplicated/missed supply cache')
RA.HealingSupplies:SetConsumer('reminder',false);check(RA.HealingSupplies:GetCached('recap')==b,'Reminder OFF broke recap cache')
combat=true;event('PLAYER_REGEN_DISABLED');before=usableCalls
dead=true;time=20;event('PLAYER_DEAD');check(usableCalls==before,'Death queried item usability')
check(R:GetPage().lastAlive.supplies[1].carried==true and R:GetPage().lastAlive.supplies[1].carriedAt==a.observedAt,'Verified carried evidence/time lost')
local pending=timers[#timers];R:SetOption('enabled',false);local nativeReads=R:GetDiagnostics().nativeReads
check(optionalCount()==0 and not R:GetDiagnostics().tickerActive and not R:GetDiagnostics().fetchPending,'All-OFF retained optional demand/timers')
fire(pending,true);check(R:GetDiagnostics().nativeReads==nativeReads,'Cancelled retry ran after disable')
before=bagReads;check(RA.HealingSupplies:GetCached('recap')==nil and bagReads==before,'Disabled cache scanned')
-- Late enable while dead must not capture the old native recap.
local previous=R:GetPage();R:SetOption('enabled',true);event('PLAYER_DEAD');check(R:GetPage()==previous,'Late enable fabricated a current death')
R:SetOption('enabled',false)
dead=false;combat=true;known=secret;R:SetOption('enabled',true)
check(R:GetDiagnostics().trackedSpells==0,'Secret learned state activated catalog')
R:SetOption('enabled',false);known=true;passive=true;R:SetOption('enabled',true)
check(R:GetDiagnostics().trackedSpells==0,'Known passive activated catalog')
R:SetOption('enabled',false);passive=false;override=999;R:SetOption('enabled',true)
check(R:GetDiagnostics().trackedSpells==0,'Unverified override activated base')
R:SetOption('enabled',false);override=nil;cooldown={isEnabled=false,isActive=false};charges={maxCharges=2,currentCharges=secret,isActive=true};R:SetOption('enabled',true)
dead=true;time=21;event('PLAYER_DEAD');page=R:GetPage()
check(page.lastAlive.spells[1].cooldown=='held' and page.lastAlive.spells[1].currentCharges==nil,'Held/opaque charges became ready/zero')
R:SetOption('enabled',false);dead=false;cooldown={isEnabled=true,isActive=true,isOnGCD=true};charges=nil;R:SetOption('enabled',true)
dead=true;time=22;event('PLAYER_DEAD');page=R:GetPage()
check(page.lastAlive.spells[1].cooldown=='active-context-unknown' and page.lastAlive.spells[1].isOnGCD==nil,'GCD flag trusted outside cooldown update')
dead=false;event('PLAYER_ALIVE');time=22.2;event('PLAYER_REGEN_DISABLED');time=22.4;event('SPELL_UPDATE_COOLDOWN');dead=true;time=23;event('PLAYER_DEAD')
check(R:GetPage().lastAlive.spells[1].cooldown=='gcd-observed' and R:GetPage().deathObservation.spells[1].cooldown=='active-context-unknown','Event-only GCD/death semantics lost')
local prefs={};for k,v in pairs(db.personalTools)do prefs[k]=v end;R:EnableReminder()
for k,v in pairs(prefs)do if k~='consumableReminder'then check(db.personalTools[k]==v,'Bell changed child preference')end end
check(db.personalTools.consumableReminder==true,'Explicit bell did not enable existing master')
R:SetOption('enabled',false)
-- Coalesced item events cannot swallow a charge/reset update with no ticker.
dead=false;combat=true;cooldown={isEnabled=true,isActive=false};charges={maxCharges=2,currentCharges=2,isActive=false}
R:SetOption('enabled',true);time=30;event('BAG_UPDATE_COOLDOWN');time=30.02;event('BAG_UPDATE_COOLDOWN')
local trailing=timers[#timers]
time=30.03;event('SPELL_UPDATE_CHARGES');charges={maxCharges=2,currentCharges=0,isActive=false};time=30.04;event('SPELL_UPDATE_CHARGES')
fire(trailing);dead=true;time=30.2;event('PLAYER_DEAD')
check(R:GetPage().lastAlive.spells[1].currentCharges==0,'Item trailing callback swallowed dirty charge state')
-- Encounter start before combat entry is retained; end cannot leak to later death.
R:SetOption('enabled',false);dead=false;combat=false;time=40;R:SetOption('enabled',true)
event('ENCOUNTER_START',123,'Boss',16);combat=true;event('PLAYER_REGEN_DISABLED');dead=true;time=41;event('PLAYER_DEAD')
check(R:GetPage().encounter and R:GetPage().encounter.encounterID==123,'Encounter-before-combat ordering discarded context')
dead=false;event('PLAYER_ALIVE');check(R:GetDiagnostics().trackedSpells==1,'Combat resurrection did not restart local recorder')
event('ENCOUNTER_END');dead=true;time=42;event('PLAYER_DEAD');check(not R:GetPage().encounter,'Ended encounter leaked into later death')
R:SetOption('enabled',false)
-- Repeated casts stay bounded and missing/opaque charge API remains explicit.
dead=false;combat=true;charges=secret;time=50;R:SetOption('enabled',true)
for i=1,100 do time=50+i*.1;event('UNIT_SPELLCAST_SUCCEEDED','player','cast',871)end
dead=true;time=61;event('PLAYER_DEAD');page=R:GetPage()
check(#page.casts==64 and not page.history,'Cast bound or compact page retention violated')
check(page.lastAlive.spells[1].chargeQuery=='unreadable','Opaque parent charge status lost')
R:SetOption('enabled',false)
print('PASS: '..checks..' death recap lifecycle/freshness/secret/charge/cache/demand assertions (offline; native acceptance pending)')
