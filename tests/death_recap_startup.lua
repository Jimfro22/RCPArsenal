-- The real recorder must establish an alive baseline without depending on a
-- DAMAGE_METER_CURRENT_SESSION_UPDATED notification after enabling/loading.
local f=assert(io.open('tests/death_recap.lua'));local source=f:read('*a');f:close()
source=source:sub(1,assert(source:find('check(optionalCount()==0',1,true))-1)
source=source..[=[
assert(loadfile('RCPArsenal/DeathRecapDebug.lua'))('RCPArsenal',RA)
local reads=0
C_DamageMeter.GetCombatSessionFromType=function()
 reads=reads+1;if combat then return secret end
 return {combatSources=meterRows}
end
R:SetOption('enabled',true)
check(R:GetDiagnostics().association.baselineKnown,'Alive out-of-combat enable waited for an optional meter event')
check(reads==1 and #timers==0,'Alive setup polled or queried more than once')
combat=true;event('PLAYER_REGEN_DISABLED')
meterRows={{isLocalPlayer=true,deathRecapID=40}}
events={{timestamp=100,event='SPELL_DAMAGE',spellId=123,amount=100}}
time=12;dead=true;event('PLAYER_DEAD');local page=R:GetPage()
check(page.association.known and page.nativeReason=='meter_unreadable','Startup baseline did not survive a restricted death read')
fire(timers[#timers]);combat=false;event('PLAYER_REGEN_ENABLED')
check(page.native and page.native.recapID==40,'Startup death did not receive its new personal recap after combat')
check(page.nativeAssociation.baselineKnown and page.nativeAssociation.baselineSource=='enabled-out-of-combat'
 and page.nativeAssociation.baselineReason=='known-empty','Frozen association setup evidence missing')
local saved=assert(RA.DeathRecapHistory:Snapshot(page))
check(saved.nativeAssociation.baselineSource=='enabled-out-of-combat'and saved.association==nil,'History lost public setup evidence or saved the live association token')
local text=assert(R:BuildDebugText())
check(text:find('NATIVE ASSOCIATION',1,true)and text:find('baselineSource="enabled-out-of-combat"',1,true),'Debug omitted frozen association evidence')
local readsBefore=reads;event('PLAYER_ALIVE');event('PLAYER_UNGHOST')
check(reads==readsBefore,'Dead life notifications queried an alive baseline')
dead=false;event('PLAYER_ALIVE');event('PLAYER_ENTERING_WORLD')
check(reads==readsBefore and assert(R:BuildDebugText()):find('baselineSource="enabled-out-of-combat"',1,true),'Known alive notifications rescanned or rewrote the prior frozen diagnosis')
-- An old nonempty Current session after reload is not a clean baseline.
R:SetOption('enabled',false);R:SetOption('enabled',true)
check(not R:GetDiagnostics().association.baselineKnown,'Old personal rows after reload were certified as a clean epoch')
-- A restricted startup can be retried at a real alive/OOC lifecycle boundary.
R:SetOption('enabled',false);dead=false;meterRows={};combat=false
local opaque=true
C_DamageMeter.GetCombatSessionFromType=function()reads=reads+1;return opaque and secret or{combatSources=meterRows}end
R:SetOption('enabled',true);check(not R:GetDiagnostics().association.baselineKnown,'Opaque startup was declared clean')
opaque=false;event('PLAYER_ENTERING_WORLD')
check(R:GetDiagnostics().association.baselineKnown,'World-ready alive boundary did not recover readable empty startup')
-- Failed/missed deaths cannot be repaired retroactively with a later empty set.
event('DAMAGE_METER_RESET');combat=true;event('DAMAGE_METER_CURRENT_SESSION_UPDATED')
opaque=true;event('DAMAGE_METER_CURRENT_SESSION_UPDATED')
time=20;dead=true;event('PLAYER_DEAD');page=R:GetPage()
check(page.nativeReason=='alive_baseline_unverified','Unobserved startup invented identity')
opaque=false;dead=false;combat=false;event('PLAYER_ALIVE');event('PLAYER_REGEN_ENABLED')
check(not R:GetDiagnostics().association.baselineKnown and not page.native,'Later alive event retroactively certified an unresolved death')
check(page.nativeAssociation.baselineReason=='meter_unreadable','Frozen failure cause lost')
local before=reads;R:SetOption('enabled',false);event('PLAYER_ENTERING_WORLD');event('PLAYER_REGEN_ENABLED')
check(reads==before,'Disabled alive observer queried the meter')
print('PASS: '..checks..' alive startup, restricted retry, frozen diagnostics and unresolved-death guards (offline)')
]=]
assert(loadstring(source,'death-recap-startup-fixture'))()
