-- Production event recorder; fabricated event payloads, not native acceptance.
local f=assert(io.open('tests/death_recap.lua'));local prefix=f:read('*a');f:close()
prefix=prefix:sub(1,assert(prefix:find('check(optionalCount()==0',1,true))-1)
assert(loadstring(prefix..[=[
local sub
for _,s in ipairs(subscriptions)do if s.event=='UNIT_COMBAT'then sub=s end end
check(sub and sub.unit=='player'and not sub.enabled,'Incoming subscription lacks native player filter or default OFF')
event('UNIT_COMBAT','player','WOUND','',99,1)
R:SetOption('enabled',true);event('UNIT_COMBAT','player','WOUND','',99,1)
combat=true;event('PLAYER_REGEN_DISABLED');local queries=R:GetDiagnostics().spellQueries;local bags=bagReads;local timerCount=#timers
-- Irrelevant or unsafe payloads must neither contaminate the stream nor invoke a full cooldown/bag scan.
for _,args in ipairs({{'target','WOUND','',100,1},{secret,'WOUND','',100,1},{'player',secret,'',100,1},{'player','MISS','',0,1},
 {'player','WOUND','',secret,1},{'player','WOUND','',-1,1},{'player','WOUND','',math.huge,1}})do event('UNIT_COMBAT',unpack(args))end
for i=1,400 do time=10+i/100;event('UNIT_COMBAT','player',i%2==0 and'HEAL'or'WOUND',i==399 and'CRITICAL'or'',i,1)end
check(R:GetDiagnostics().spellQueries==queries and bagReads==bags and #timers==timerCount,'Incoming capture added polling, spell queries or bag scans')
dead=true;time=14.1;event('PLAYER_DEAD');local page=R:GetPage();local live=page.liveIncoming
check(live.source=='UNIT_COMBAT:player'and live.clock=='GetTime'and live.total==400 and #live.rows==256,'Live ring lost its separate identity/clock or capacity')
check(live.restricted==1 and live.rejected==2,'Unsafe incoming amounts were treated as public numbers')
check(live.rows[1].sequence==145 and live.rows[256].sequence==400 and live.rows[1].amount==145,'Ring wrap did not retain chronological newest receipts')
check(live.rows[255].kind=='damage'and live.rows[255].flag=='CRITICAL'and live.rows[256].kind=='healing','Damage/heal classification changed')
check(not live.rows[1].spellID and not live.rows[1].sourceName and not live.rows[1].recordedHP,'Anonymous incoming receipts acquired fabricated spell/source/HP')
time=15;event('UNIT_COMBAT','player','WOUND','',999,1);check(live.total==400,'Dead stream changed a frozen death')
local saved=RA.DeathRecapHistory:Snapshot(page)
check(saved.liveIncoming.total==400 and #saved.liveIncoming.rows==256 and saved.liveIncoming.rows[1].sequence==145,'Allowlisted history lost bounded live receipts')
assert(loadfile('RCPArsenal/DeathRecapDebug.lua'))('RCPArsenal',RA)
local text=assert(R:BuildLiveHistoryText())
check(text:find('capacity 256',1,true)and text:find('Capacity reached',1,true)and text:find('DAMAGE  399',1,true)and not text:find('999',1,true),'Live diagnostic lost bounds, public amounts or frozen identity')
-- A subsequent combat has no prior-life receipts, and elapsed time prunes only at death.
dead=false;combat=false;event('PLAYER_ALIVE');event('PLAYER_REGEN_ENABLED')
event('UNIT_COMBAT','player','WOUND','',1234,1)
combat=true;time=20;event('PLAYER_REGEN_DISABLED')
event('UNIT_COMBAT','player','WOUND','',1,1)
time=22;event('UNIT_COMBAT','player','WOUND','',2,1)
time=30;dead=true;event('PLAYER_DEAD');local second=R:GetPage()
check(second.liveIncoming.total==2 and #second.liveIncoming.rows==1 and second.liveIncoming.rows[1].amount==2,'Eight-second window included stale/OOC/prior-life receipts or dropped exact boundary')
local firstText=R:BuildLiveHistoryText();R:SelectHistoryPage(page)
check(R:BuildLiveHistoryText()==text and R:BuildLiveHistoryText()~=firstText,'Live readout ignores selected death')
R:SetOption('enabled',false);check(optionalCount()==0,'Disabled live recorder left subscriptions active')
print('PASS: '..checks..' production live incoming filter/ring/window/freeze/history/secret/demand assertions; native stream unverified')
]=]))()
