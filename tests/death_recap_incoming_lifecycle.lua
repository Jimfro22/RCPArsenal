-- Synthetic lifecycle regression: combat-query transitions may lag an event.
-- All event payloads and times below are fabricated test inputs.
local f=assert(io.open('tests/death_recap.lua'));local prefix=f:read('*a');f:close()
prefix=prefix:sub(1,assert(prefix:find('check(optionalCount()==0',1,true))-1)
assert(loadstring(prefix..[=[
R:SetOption('enabled',true)
local sub;for _,s in ipairs(subscriptions)do if s.event=='UNIT_COMBAT'then sub=s end end
function sub:GetNativeRegistration()return true end
-- PLAYER_REGEN_DISABLED is authoritative even while a separate combat query
-- still returns false. End-of-combat must stop intake while that query is true.
time=11;event('PLAYER_REGEN_DISABLED');event('UNIT_COMBAT','player','WOUND','',100,1)
combat=true;time=11.1;event('UNIT_COMBAT','player','HEAL','',20,2)
event('UNIT_COMBAT',secret,'WOUND','',1,1)
event('UNIT_COMBAT','player','BLOCK','',0,1)
time=11.2;event('PLAYER_REGEN_ENABLED');event('UNIT_COMBAT','player','WOUND','',500,1)
time=11.3;dead=true;event('PLAYER_DEAD');local page=R:GetPage();local live=page.liveIncoming
check(live.total==2 and #live.rows==2 and live.rows[1].amount==100 and live.rows[2].amount==20,'Explicit entry/exit did not govern incoming intake')
check(live.callbacks==5 and live.inactive==1 and live.unitRejected==1 and live.actionRejected==1,'Pre-filter counters cannot distinguish callback/filter/lifecycle failures')
check(live.nativeRegistered==true and live.recording==false and live.sessionPrecombat==true and live.lockdownAtDeath==true,'Frozen registration/lifecycle diagnostics were inferred from each other')
check(#live.trace==5 and live.trace[3].unit==nil and live.trace[3].unitStatus=='restricted','Trace lost callbacks or exposed a private unit')
assert(loadfile('RCPArsenal/DeathRecapDebug.lua'))('RCPArsenal',RA)
local text=assert(R:BuildLiveHistoryText());check(text:find('Recorder callbacks: 5',1,true)and text:find('1 inactive; 1 unit-filter; 1 action-filter',1,true),'Plain readout hid the failed stage')
local restored=RA.DeathRecapHistory:Snapshot(page)
check(restored.liveIncoming.callbacks==5 and restored.liveIncoming.sessionPrecombat==true and #restored.liveIncoming.trace==5,'History allowlist lost transport diagnostics')
print('PASS: '..checks..' incoming entry/exit/registration/trace/filter/secret history assertions')
]=]))()
