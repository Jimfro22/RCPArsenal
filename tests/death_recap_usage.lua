-- Whole-coverage observed uses remain independent of the short timeline ring.
local f=assert(io.open('tests/death_recap.lua'));local source=f:read('*a');f:close()
source=source:sub(1,assert(source:find('check(optionalCount()==0',1,true))-1)
source=source..[=[
R:SetOption('enabled',true);combat=true;event('PLAYER_REGEN_DISABLED')
local beforeQueries=R:GetDiagnostics().spellQueries
for i=1,70 do time=10+i;event('UNIT_SPELLCAST_SUCCEEDED','player','cast',871)end
check(R:GetDiagnostics().retainedCasts<=64 and R:GetDiagnostics().spellQueries==beforeQueries,'Use summary added queries or removed timeline bound')
time=200;dead=true;event('PLAYER_DEAD');local page=R:GetPage();local audit=R:GetAvailabilityAudit()
check(#page.casts==0,'Old use incorrectly retained on30s timeline')
check(page.observedUses[871].observedCount==70 and page.observedUses[871].firstSuccessfulUseAt==11 and page.observedUses[871].lastSuccessfulUseAt==80,'Long-pull observed use lost after timeline expiry')
check(audit.coverage.combatEntryObserved and audit.coverage.startedAt==10 and #audit.spells==1,'Use coverage or tracked bound lost')
local row=audit.spells[1]
check(row.use.observedCount==70 and row.lastAlive.pendingReason=='cast-received'and row.deathNotice.source=='death-notification'and row.deathNotice.observedAt==200,'Audit conflated pending living sample and fresh death query')
local q,t=R:GetDiagnostics().spellQueries,#timers
for i=1,50 do R:GetAvailabilityAudit()end
check(R:GetDiagnostics().spellQueries==q and #timers==t,'Audit collected or scheduled work')
row.use.observedCount=999;row.deathNotice.cooldown='invented'
check(page.observedUses[871].observedCount==70 and page.deathObservation.spells[1].cooldown=='inactive','Audit returned mutable capture references')
R:SetOption('enabled',false);dead=false;time=300;R:SetOption('enabled',true)
time=301;event('UNIT_SPELLCAST_SUCCEEDED','party1','cast',871);event('UNIT_SPELLCAST_SUCCEEDED','player','cast',secret);event('UNIT_SPELLCAST_SUCCEEDED','player','cast',6262)
dead=true;event('PLAYER_DEAD');audit=R:GetAvailabilityAudit()
check(not audit.coverage.combatEntryObserved and audit.spells[1].use.observedCount==0 and audit.spells[1].use.status:find('No successful use observed',1,true),'Incomplete/reloaded coverage became unused or foreign/secret/item use became defensive use')
check(not R:GetPage().observedUses[871],'Unobserved use was synthesized')
R:SetOption('enabled',false);dead=false;combat=true;time=400;R:SetOption('enabled',true)
event('ENCOUNTER_START',10,'Boss',16);dead=true;time=401;event('PLAYER_DEAD');time=402;event('ENCOUNTER_END',10)
local endAudit=R:GetAvailabilityAudit();check(endAudit.encounterEndObservation.observedAt==402,'Own encounter end not linked')
dead=false;time=500;event('ENCOUNTER_START',10,'Boss',16);time=510;event('ENCOUNTER_END',10)
check(R:GetAvailabilityAudit().encounterEndObservation.observedAt==402,'Later pull changed previous death audit')
R:SetOption('enabled',false);dead=false;time=600;R:SetOption('enabled',true);event('ENCOUNTER_START',10,'Boss',16)
dead=true;time=601;event('PLAYER_DEAD');check(not R:GetAvailabilityAudit().encounterEndObservation,'Prior attempt end attached to new death')
dead=false;time=700;event('ENCOUNTER_START',10,'Boss',16);time=710;event('ENCOUNTER_END',10)
check(not R:GetAvailabilityAudit().encounterEndObservation,'Later same-boss attempt attached its end to earlier death')
R:SetOption('enabled',false)
check(optionalCount()==0 and not R:GetDiagnostics().tickerActive,'Use audit added OFF subscriptions or timers')
print('PASS: '..checks..' bounded whole-coverage use and death-observation audit assertions (offline; native accuracy pending)')
]=]
assert(loadstring(source,'death-recap-use-audit-fixture'))()
