-- Recent pre-pull casts must reach this death's use ledger without importing a
-- prior life, a different spec, stale casts, or an unbounded idle history.
local f=assert(io.open('tests/death_recap.lua'));local prefix=f:read('*a');f:close()
prefix=prefix:sub(1,assert(prefix:find('check(optionalCount()==0',1,true))-1)
assert(loadstring(prefix..[=[
R:SetOption('enabled',true)
time=11;event('UNIT_SPELLCAST_SUCCEEDED','player','prepull-defensive',871)
time=12;event('UNIT_SPELLCAST_SUCCEEDED','player','prepull-stone',6262)
check(#timers==0 and not R:GetDiagnostics().tickerActive,'Pre-pull use scheduled idle polling')
time=14;combat=true;event('PLAYER_REGEN_DISABLED')
time=15;dead=true;event('PLAYER_DEAD');local first=R:GetPage()
check(#first.casts==2 and first.casts[1].observedAt==11 and first.casts[2].observedAt==12,'Combat entry discarded recent pre-pull casts or changed their timestamps')
check(first.observedUses[871].observedCount==1 and first.observedUses[6262].observedCount==1,'Pre-pull use summaries missing')
check(first.useCoverage.startedAt==11 and first.localSessionStartedAt==14,'Pre-pull receipt scope silently changed combat-entry clock')
dead=false;time=16;event('PLAYER_ALIVE');time=17;event('PLAYER_DEAD')
check(#R:GetPage().casts==0 and not R:GetPage().observedUses[871],'Prior-life pre-pull casts were reused')
R:SetOption('enabled',false);dead=false;combat=false;time=30;R:SetOption('enabled',true)
time=31;event('UNIT_SPELLCAST_SUCCEEDED','player','old-prepull',871)
time=65;combat=true;event('PLAYER_REGEN_DISABLED');time=66;dead=true;event('PLAYER_DEAD')
check(#R:GetPage().casts==0 and not R:GetPage().observedUses[871],'Stale pre-pull cast survived bounded handoff')
R:SetOption('enabled',false);dead=false;combat=false;time=70;R:SetOption('enabled',true)
local priorTimers=#timers
for i=1,80 do time=70+i*.01;event('UNIT_SPELLCAST_SUCCEEDED','player','prepull-'..i,871)end
check(R:GetDiagnostics().retainedCasts==64 and #timers==priorTimers,'Pre-pull buffer is unbounded or scheduled idle timers')
time=72;combat=true;event('PLAYER_REGEN_DISABLED');time=73;dead=true;event('PLAYER_DEAD')
check(#R:GetPage().casts==64 and R:GetPage().observedUses[871].observedCount==64,'Pre-pull handoff invented expired receipts from its aggregate count')
R:SetOption('enabled',false)
print('PASS: '..checks..' bounded pre-pull use/life/clock assertions (supplied events)')
]=]))()
