-- Regression for public baseline -> restricted first deaths update -> public
-- own-ID delta after combat. Native Current is authoritative; hints do not bind.
local f=assert(io.open('tests/death_recap.lua'));local source=f:read('*a');f:close()
source=source:sub(1,assert(source:find('check(optionalCount()==0',1,true))-1)
source=source..[=[
local currentID=12;local rowsByID={[12]={},[13]={}}
local currentReads,explicitReads=0,0
C_DamageMeter.GetCombatSessionFromType=function(kind,metric)
 check(kind==Enum.DamageMeterSessionType.Current and metric==Enum.DamageMeterType.Deaths,'Wrong authoritative source')
 currentReads=currentReads+1;if combat then return secret end
 return {combatSources=rowsByID[currentID]}
end
C_DamageMeter.GetCombatSessionFromID=function()explicitReads=explicitReads+1;error('Event hint was treated as established session identity')end
local function pair(id)
 event('DAMAGE_METER_COMBAT_SESSION_UPDATED',9,0);event('DAMAGE_METER_COMBAT_SESSION_UPDATED',9,id)
end
R:SetOption('enabled',true);event('DAMAGE_METER_CURRENT_SESSION_UPDATED')
check(R:GetDiagnostics().association.baselineKnown,'Clean public Current baseline missing')
combat=true;event('PLAYER_REGEN_DISABLED');rowsByID[12]={{isLocalPlayer=false,deathRecapID=1002}}
local before=currentReads;time=11;pair(12)
check(currentReads==before and R:GetDiagnostics().association.baselineKnown,'Restricted first update poisoned or rescanned witnessed baseline')
time=12;dead=true;rowsByID[12]={{isLocalPlayer=true,deathRecapID=1003}}
events={{timestamp=100,event='SPELL_DAMAGE',spellId=123,amount=100,currentHP=0}}
event('PLAYER_DEAD');local page=R:GetPage()
check(page.association.known and not page.native and page.nativeReason=='meter_unreadable','Restricted attempt did not stay retryable')
fire(timers[#timers]);check(page.nativeAttempts==2 and not R:GetDiagnostics().fetchPending,'Restricted combat retry did not stop at two attempts')
local timerCount=#timers;before=currentReads
for i=1,1000 do pair(12)end
check(page.nativeAttempts==2 and #timers==timerCount and currentReads==before,'Combat hints exhausted the reserved public retry')
time=13;combat=false;event('PLAYER_REGEN_ENABLED')
check(page.native and page.native.recapID==1003 and explicitReads==0 and page.nativeAttempts==3,'Public Current delta failed after combat')
-- A changed positive hint alone neither binds a different session nor poisons
-- the epoch. Paired Overall/positive notifications perform zero row scans.
dead=false;event('PLAYER_ALIVE');currentID=13;event('DAMAGE_METER_CURRENT_SESSION_UPDATED');before=currentReads
for i=1,1000 do pair(i%2==0 and 13 or 99)end
check(currentReads==before and R:GetDiagnostics().association.baselineKnown,'Dirty hints rebound/poisoned/scanned Current')
-- Already accepted ID cannot be relabelled as another death after a reset.
dead=true;time=14;rowsByID[13]={{isLocalPlayer=true,deathRecapID=1003}};event('PLAYER_DEAD')
check(not R:GetPage().native and R:GetPage().nativeReason=='personal_id_delta_ambiguous','Previously accepted ID reused across meter epochs')
local stale=timers[#timers];event('DAMAGE_METER_RESET');before=currentReads;fire(stale,true)
check(currentReads==before and not R:GetPage().native,'Stale previous-epoch callback adopted a packet')
R:SetOption('enabled',false);before=currentReads;pair(13);event('DAMAGE_METER_CURRENT_SESSION_UPDATED')
check(currentReads==before,'OFF meter observer queried native source')
-- A newly reported Current epoch whose alive baseline is already restricted
-- remains unverified. A later public death packet cannot reconstruct that past.
dead=false;combat=true;rowsByID[currentID]={};R:SetOption('enabled',true);event('DAMAGE_METER_CURRENT_SESSION_UPDATED')
check(not R:GetDiagnostics().association.baselineKnown,'Restricted epoch was fabricated as an empty alive baseline')
dead=true;time=15;rowsByID[currentID]={{isLocalPlayer=true,deathRecapID=1004}};event('PLAYER_DEAD')
combat=false;time=16;event('PLAYER_REGEN_ENABLED')
check(not R:GetPage().native and R:GetPage().nativeReason=='alive_baseline_unverified','Later public packet supplied an unwitnessed historical baseline')
print('PASS: '..checks..' authoritative Current, restricted retry, hint coalescing and cross-epoch anti-reuse assertions')
]=]
assert(loadstring(source,'death-recap-meter-fixture'))()
