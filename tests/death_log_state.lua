-- Actual recorder field/coverage corrections and scalar diagnostic, offline.
local f=assert(io.open('tests/death_recap.lua'));local source=f:read('*a');f:close()
source=source:sub(1,assert(source:find('check(optionalCount()==0',1,true))-1)
source=source..[=[
time=100;bagIDs={5512};local physical,uses=1,3;local stockCalls=0
C_Item.GetItemCount=function(id,bank,includeUses,reagent,account)
 stockCalls=stockCalls+1;check(id==5512 and bank==false and reagent==false and account==false,'Stock query broadened bag/bank scope')
 return includeUses and uses or physical
end
R:SetOption('enabled',true);event('DAMAGE_METER_CURRENT_SESSION_UPDATED');event('DAMAGE_METER_COMBAT_SESSION_UPDATED',9,1)
combat=true;event('PLAYER_REGEN_DISABLED');local scans,queries=bagReads,R:GetDiagnostics().spellQueries
check(not R:GetDiagnostics().tickerActive,'Inactive baseline added polling')
time=145.1;event('BAG_UPDATE_COOLDOWN');dead=true;time=146;event('PLAYER_DEAD');local page=R:GetPage()
local item=page.lastAlive.supplies[1];local spell=page.lastAlive.spells[1]
check(item.carriedAt==100 and item.countAt==145.1 and item.usesAt==145.1 and item.physicalCount==1 and item.remainingUses==3,'Independent fresh counts lost old cache provenance')
check(item.cooldown=='inactive' and usableCalls==0 and bagReads==scans,'Cooldown required usability or enumerated bags again')
check(spell.observedAt==100 and spell.cooldown=='inactive' and R:GetDiagnostics().spellQueries==queries+1,'Unchanged inactive spell re-polled or timestamp refreshed')
-- Thirty-seven accepted native rows remain separate. Scalar timing is captured
-- around only the existing read; fatal time is not substituted for clock zero.
meterRows={{isLocalPlayer=true,deathRecapID=1}};link='death:1';events={}
for i=1,37 do events[i]={timestamp=250+(i==2 and 1 or-i*.01),destGUID='Player-self',event='SPELL_DAMAGE',spellId=100+i,amount=i,currentHP=1000-i,sourceName='Boss',hideCaster=false,absorbed=10,overkill=0}end
events[1].timestamp=250;events[3].absorbed=secret;events[4].overkill=-1
C_DeathRecap.GetRecapEvents=function(id)check(id==1,'Clock check changed recap identity');time=146.01;return events end
C_DeathRecap.GetRecapMaxHealth=function(id)check(id==1,'Max queried default record');return 1000 end
fire(timers[#timers]);check(page.native and #page.native.rows==37 and not page.native.truncated,'Old16row capture cap dropped native density')
check(page.native.rows[3].absorbed==nil and page.native.rows[3].fieldStatus.absorbed=='restricted' and page.native.rows[4].overkill==nil,'Secret/invalid mitigation field retained')
check(page.native.rows[1].sourceName=='Boss' and page.native.rows[1].sourceConfirmed==false and not page.native.rows[1].sourceKey,'Display name became stable source instance')
local clock=R:GetDiagnostics().nativeClock
check(clock.localSessionStartedAt==100 and clock.localDeathNoticeAt==146 and clock.nativeReadLocalBefore==146 and clock.nativeReadLocalAfter==146.01,'Bounded GetTime read brackets wrong')
check(clock.nativeFatalTimestamp==250 and clock.nativeMaximumTimestamp==251 and clock.nativeMinimumTimestamp==249.63 and clock.nativeRowCount==37,'Diagnostic conflated fatal/latest or lost native range')
local frozenHP=page.native.rows[1].recordedHP;events[1].currentHP=1;event('SPELL_UPDATE_COOLDOWN');check(page.native.rows[1].recordedHP==frozenHP,'Frozen record followed live input')
-- Secret charge count must not erase independent inactive/held cooldown facts.
R:SetOption('enabled',false);dead=false;time=200;charges={maxCharges=2,currentCharges=secret,isActive=true};R:SetOption('enabled',true)
cooldown={isEnabled=true,isActive=false};dead=true;time=201;event('PLAYER_DEAD');local latest=R:GetPage().lastAlive.spells[1]
check(latest.cooldown=='inactive' and latest.currentCharges==nil and latest.chargeCountStatus=='restricted','Restricted charges erased public inactive cooldown')
R:SetOption('enabled',false);dead=false;cooldown={isEnabled=false,isActive=false};time=210;R:SetOption('enabled',true);dead=true;event('PLAYER_DEAD');latest=R:GetPage().lastAlive.spells[1]
check(latest.cooldown=='held','On-hold fact collapsed')
-- A consumable receipt invalidates the item domain without guessing a use.
R:SetOption('enabled',false);dead=false;combat=true;time=215;bagIDs={5512};R:SetOption('enabled',true)
time=215.1;event('UNIT_SPELLCAST_SUCCEEDED','player','cast',6262);dead=true;time=215.11;event('PLAYER_DEAD')
local consumed=R:GetPage().lastAlive.supplies[1]
check(consumed.pendingAt==215.1 and consumed.pendingReason=='item-cast-received' and consumed.remainingUses==3,'Consumable receipt left old item check current or deducted uses')
-- Cast/coalescer invalidations leave explicit pending gaps at freeze.
R:SetOption('enabled',false);dead=false;charges=nil;cooldown={isEnabled=true,isActive=false};time=220;R:SetOption('enabled',true)
time=220.1;event('UNIT_SPELLCAST_SUCCEEDED','player','cast',871);dead=true;time=220.11;event('PLAYER_DEAD');latest=R:GetPage().lastAlive.spells[1]
check(latest.pendingAt==220.1 and latest.pendingReason=='cast-received' and latest.cooldown=='inactive','Cast receipt invented cooldown instead of pending fact')
R:SetOption('enabled',false);dead=false;time=230;R:SetOption('enabled',true);event('SPELL_UPDATE_COOLDOWN')
time=230.02;cooldown={isEnabled=true,isActive=true};event('SPELL_UPDATE_COOLDOWN');dead=true;time=230.03;event('PLAYER_DEAD');local pendingPage=R:GetPage()
check(pendingPage.lastAlive.spells[1].pendingAt==230.02 and pendingPage.lastAlive.spells[1].cooldown=='inactive','Cancelled trailing update erased pending change gap')
R:SetOption('enabled',false);dead=false;time=240;R:SetOption('enabled',true);combat=false;time=241;event('PLAYER_REGEN_ENABLED');dead=true;time=242;event('PLAYER_DEAD')
check(R:GetPage().lastAlive.coverageEndedAt==241,'Combat coverage gap hidden')
-- Cache generation changes without altering reminder independence or bag scope.
R:SetOption('enabled',false);dead=false;combat=true;time=250;R:SetOption('enabled',true);RA.HealingSupplies:SetConsumer('reminder',true)
local cached=RA.HealingSupplies:GetCached('recap');local generation=cached.cacheGeneration;scans=bagReads;bagIDs={};time=251;event('BAG_UPDATE_DELAYED')
local changed=RA.HealingSupplies:GetCached('reminder');check(changed.cacheGeneration>generation and bagReads==scans+6 and changed.stone==false,'Cache invalidation not before recap refresh/shared evaluation')
R:SetOption('enabled',false);check(RA.HealingSupplies:GetCached('reminder')==changed,'Recap OFF broke reminder cache')
RA.HealingSupplies:SetConsumer('reminder',false);check(not R:GetDiagnostics().tickerActive and optionalCount()==0,'OFF retained state collection')
print('PASS: '..checks..' Death Log state/stock/pending/clock assertions (offline)')
]=]
assert(loadstring(source,'death-log-state-fixture'))()
