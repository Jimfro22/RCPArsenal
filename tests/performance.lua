-- Actual core, profiler module and settings against controlled native metrics.
-- Verifies measurement scope/lifecycle; does not benchmark native overhead.
local f=assert(io.open('tests/hub.lua'));local prefix=f:read('*a');f:close()
prefix=prefix:sub(1,assert(prefix:find('check(db.schemaVersion == 19',1,true))-1)
assert(loadstring(prefix..[=[
local P=RA.Performance;check(P and not P:IsEnabled(),'Performance did not default OFF')
local secret={};function issecretvalue(v)return rawequal(v,secret)end
local clock,reads,enabledReads=100,0,0
GetTime=function()return clock end
local values={};Enum=Enum or{};Enum.AddOnProfilerMetric={RecentAverageTime=1,PeakTime=4,EncounterAverageTime=2,CountTimeOver1Ms=5,CountTimeOver5Ms=6,CountTimeOver10Ms=7,CountTimeOver50Ms=8}
for _,id in pairs(Enum.AddOnProfilerMetric)do values[id]=0 end
C_AddOnProfiler={IsEnabled=function()enabledReads=enabledReads+1;return true end,
 GetAddOnMetric=function(name,id)check(name=='RCPArsenal','Recorder read another addon');reads=reads+1;return values[id]end}
local baselineObjects,baselineTimers=#objects,#timers
local ownTimers=0
for _,name in ipairs({'NewTimer','NewTicker','After'})do
 local original=C_Timer[name]
 C_Timer[name]=function(...)
  if debug.getinfo(2,'S').source:find('Performance.lua',1,true)then ownTimers=ownTimers+1 end
  return original(...)
 end
end
event('PLAYER_REGEN_DISABLED');event('PLAYER_REGEN_ENABLED');event('ENCOUNTER_START',100,'Boss');event('ENCOUNTER_END',100,'Boss',16,20,0)
check(reads==0 and enabledReads==0 and #objects==baselineObjects and #timers==baselineTimers,'Disabled recorder queried/allocated/polled')
local function indicator()
 for _,o in ipairs(objects)do if o.text=='Performance recording ON'and o.parent and o.parent.scripts.OnClick then return o.parent end end
end
check(P:SetEnabled(true),'Native profiler could not enable');local bar=indicator()
check(bar and bar:IsVisible()and not bar.scripts.OnUpdate and reads==0,'Enabled recorder lacks persistent indicator or polled while idle')
clock=101;combat=true;event('PLAYER_REGEN_DISABLED');check(reads==7,'Fight start did not take exactly one bounded addon snapshot')
for _,o in ipairs(objects)do check(not o.scripts.OnUpdate or o~=bar,'Indicator installed polling')end
values[1]=.04;values[4]=2.5;values[5]=5;values[6]=2;values[7]=1
clock=111;combat=false;event('PLAYER_REGEN_ENABLED')
local report=P:GetReports()[1]
check(report and report.duration==10 and report.over.CountTimeOver1Ms==5 and report.over.CountTimeOver5Ms==2 and report.over.CountTimeOver10Ms==1,'Snapshot interval/deltas incorrect')
check(reads==14 and ownTimers==0,'Recorder added per-frame/interval sampling')
local text=P:BuildReportText();check(text:find('Session peak at finish: 2.500 ms',1,true)and not text:find('Blizzard encounter average',1,true),'Session peak or recent average mislabeled as encounter/fight maximum')
clock=120;event('ENCOUNTER_START',200,'Test Boss')
combat=true;event('PLAYER_REGEN_DISABLED');values[2]=.125;values[6]=5
clock=132;combat=false;event('PLAYER_REGEN_ENABLED')
check(#P:GetReports()==1,'Boss ended from generic combat transition')
event('ENCOUNTER_END',999,'Wrong Boss',16,20,1);check(#P:GetReports()==1,'Unrelated encounter finalized recording')
event('ENCOUNTER_END',200,'Test Boss',16,20,0);report=P:GetReports()[1]
check(report.kind=='boss'and report.duration==12 and report.success==false and report.over.CountTimeOver5Ms==3,'Boss identity/outcome or counter delta lost')
check(P:BuildReportText():find('Blizzard encounter average: 0.125 ms',1,true),'Native boss average not labeled')
clock=140;combat=true;event('PLAYER_REGEN_DISABLED');values[5]=0;values[6]=secret;clock=145;combat=false;event('PLAYER_REGEN_ENABLED')
report=P:GetReports()[1];check(report.over.CountTimeOver1Ms==nil and report.over.CountTimeOver5Ms==nil,'Reset or protected counter was presented as zero')
for i=1,8 do clock=150+i*10;combat=true;event('PLAYER_REGEN_DISABLED');clock=clock+2;combat=false;event('PLAYER_REGEN_ENABLED')end
check(#P:GetReports()==5 and #RaidArsenalDB.performanceReports==5,'Performance report history exceeded five records')
local prior=P:GetReports()[1].name;local copied=P:GetReports();copied[1].name='mutated'
check(P:GetReports()[1].name==prior,'Report access mutated saved evidence')
local before=reads;check(P:SetEnabled(false)and not bar:IsShown(),'Stop left indicator visible')
event('PLAYER_REGEN_DISABLED');event('PLAYER_REGEN_ENABLED');P:BuildReportText();P:GetReports()
check(reads==before,'Stopped recorder still queried metrics or refreshed reports from current state')
local native=C_AddOnProfiler.IsEnabled;C_AddOnProfiler.IsEnabled=function()return false end
check(not P:SetEnabled(true)and not P:IsEnabled()and not bar:IsShown(),'Unavailable profiler enabled recording')
C_AddOnProfiler.IsEnabled=function()return secret end
check(not P:SetEnabled(true),'Secret profiler enabled recording');C_AddOnProfiler.IsEnabled=native
check(P:SetEnabled(true));clock=300;combat=true;event('PLAYER_REGEN_DISABLED');clock=301
bar:Fire('OnClick','RightButton');check(not P:IsEnabled()and not bar:IsShown()and P:GetReports()[1].completed==false,'Indicator stop failed to finalize partial recording')
combat=false;check(P:SetEnabled(true));event('PLAYER_LOGOUT');check(not P:IsEnabled()and not bar:IsShown(),'Logout retained recorder')
check(P:SetEnabled(true));RA:FireCallback('PROFILE_RESET');check(not P:IsEnabled(),'Profile reset retained opt-in')
-- Reload only this module around already sanitized public reports; no current
-- metric query or indicator allocation may occur when loading saved reports.
local initializers={};local register=RA.RegisterInitializer
RA.RegisterInitializer=function(_,fn)initializers[#initializers+1]=fn end
local saved=RaidArsenalDB.performanceReports;table.insert(saved,1,{startedAt=true,endedAt=true,kind='combat'})
before=reads;baselineObjects=#objects
assert(loadfile('RCPArsenal/Performance.lua'))('RCPArsenal',RA)
for _,fn in ipairs(initializers)do fn()end
check(not RA.Performance:IsEnabled()and #RA.Performance:GetReports()<=5 and reads==before and #objects==baselineObjects,'Reload activated recording or queried native profiler')
RA.RegisterInitializer=register
cleanErrors();nativePrint('PASS: '..checks..' performance lifecycle/scope/saved-report assertions (offline; no native overhead claim)')
]=]))()
