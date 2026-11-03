-- Actual recorder with fabricated callbacks. This proves isolation/lifecycle,
-- not native callback order or identification of any real killing blow.
local f=assert(io.open('tests/death_recap.lua'));local prefix=f:read('*a');f:close()
prefix=prefix:sub(1,assert(prefix:find('check(optionalCount()==0',1,true))-1)
local helpers=[=[
local function windowTimer()
 local found,n=nil,0
 for _,t in ipairs(timers)do if not t.cancelled and not t.repeating and t.delay==.25 then found=t;n=n+1 end end
 check(n<=1,'More than one delivery-window timer pending');return found
end
local function die()
 combat=true;R:SetOption('enabled',true);time=10.5;event('UNIT_COMBAT','player','WOUND','',125,1)
 time=11;dead=true;event('PLAYER_DEAD');local page=assert(R:GetPage())
 return page,assert(page.liveIncoming.deathBoundary),windowTimer()
end
]=]
local cases={
 {name='delivery_and_chart_isolation',body=[=[
 local count=#subscriptions;local page,boundary,t=die();check(t and #subscriptions==count,'Delivery audit added subscriptions or omitted its close timer')
 local before=R:GetDiagnostics().spellQueries;local bags=bagReads;local nativeReads=R:GetDiagnostics().nativeReads
 event('PLAYER_DEAD');check(windowTimer()==t and R:GetPage()==page,'Duplicate death replaced the delivery owner')
 event('UNIT_COMBAT','player','WOUND','CRITICAL',777,1)
 time=11.05;event('UNIT_COMBAT','player','HEAL','',5,2)
 -- A combat-end notification may precede a queued player callback.
 event('PLAYER_REGEN_ENABLED');time=11.1;event('UNIT_COMBAT','player','WOUND','ABSORB',0,4)
 time=11.25;event('UNIT_COMBAT','player','WOUND','',225,1);fire(t)
 check(boundary.total==4 and #boundary.rows==4 and boundary.rows[1].observedAt==11 and boundary.rows[4].observedAt==11.25,'Boundary lost same-tick/last-tick callbacks or changed their clocks')
 check(not boundary.active and boundary.stopReason=='window-ended'and t.cancelled,'Window did not close/cancel cleanly')
 check(page.liveIncoming.total==1 and #page.liveIncoming.rows==1 and page.liveIncoming.rows[1].amount==125,'Post-notice receipt entered frozen pre-death feed')
 assert(loadfile('RCPArsenal/DeathLogModel.lua'))('RCPArsenal',RA)
 local model=RA.DeathLogModel:Incoming(page)
 check(model.available and #model.rows==1 and model.damageTotal==125,'Delivery audit changed chart damage totals')
 assert(loadfile('RCPArsenal/DeathRecapActions.lua'))('RCPArsenal',RA)
 local text=assert(R:BuildShareText(page,false,'history'))
 check(text:find('125',1,true)and not text:find('777',1,true)and not text:find('225',1,true),'Delivery audit entered player chat report or history feed selection was lost')
 local saved=RA.DeathRecapHistory:Snapshot(page);local copy=saved.liveIncoming.deathBoundary
 check(copy.noticeAt==11 and copy.deadline==11.25 and copy.endedAt==11.25 and #copy.rows==4 and not copy.active,'Bounded delivery evidence did not survive saving')
 check(R:GetDiagnostics().spellQueries==before and bagReads==bags and R:GetDiagnostics().nativeReads==nativeReads,'Delivery receipts or close timer queried character/native state')
 assert(loadfile('RCPArsenal/DeathRecapDebug.lua'))('RCPArsenal',RA)
 local debug=assert(R:BuildLiveHistoryText(true))
 check(debug:find('DEATH-NOTICE DELIVERY CHECK',1,true)and debug:find('excluded from charts and totals',1,true)and debug:find('afterNoticeReceipt=1',1,true)and debug:find('amount=777',1,true),'Debug lost separated raw delivery evidence')
 time=11.26;event('UNIT_COMBAT','player','WOUND','',999,1);fire(t,true)
 check(boundary.total==4 and #boundary.rows==4,'Closed callback/timer mutated frozen delivery packet')
 ]=]},
 {name='filters_capacity_and_secret_serialization',body=[=[
 local page,boundary,t=die()
 time=11.01
 event('UNIT_COMBAT','target','WOUND','',50,1);event('UNIT_COMBAT',secret,'WOUND','',50,1)
 event('UNIT_COMBAT','player','MISS','',0,1);event('UNIT_COMBAT','player',secret,'',0,1)
 event('UNIT_COMBAT','player','WOUND','',secret,1);event('UNIT_COMBAT','player','WOUND','',-1,1)
 for i=1,40 do event('UNIT_COMBAT','player','WOUND',secret,i,secret)end
 check(boundary.callbacks==46 and boundary.unitRejected==2 and boundary.actionRejected==2 and boundary.restricted==1 and boundary.rejected==1,'Diagnostic filters lost a stage or exposed a protected payload')
 check(boundary.total==40 and #boundary.rows==16 and boundary.truncated and boundary.rows[16].amount==16,'Diagnostic capacity was unbounded or rewrote receipt order')
 time=11.25;fire(t)
 local saved=RA.DeathRecapHistory:Snapshot(page).liveIncoming.deathBoundary
 check(#saved.rows==16 and saved.rows[1].flag==nil and saved.rows[1].school==nil,'Protected metadata entered saved diagnostic evidence')
 ]=]},
}
for _,transition in ipairs({'disabled','alive','world','new-session'})do
 cases[#cases+1]={name='cancel_'..transition,body=([=[
 local page,boundary,t=die();time=11.02
 %s
 local reason,ended=boundary.stopReason,boundary.endedAt;local before=R:GetDiagnostics().spellQueries
 check(not boundary.active and t.cancelled,'Lifecycle boundary left diagnostic window active')
 time=11.05;event('UNIT_COMBAT','player','WOUND','',333,1);fire(t,true)
 check(boundary.total==0 and boundary.stopReason==reason and boundary.endedAt==ended,'New life or stale timer wrote an older death')
 check(R:GetDiagnostics().spellQueries==before,'Stale diagnostic timer queried current character')
 ]=]):format(transition=='disabled'and"R:SetOption('enabled',false)"or transition=='alive'and"dead=false;event('PLAYER_ALIVE')"or transition=='world'and"event('PLAYER_ENTERING_WORLD')"or"dead=false;event('PLAYER_REGEN_DISABLED')")}
end
cases[#cases+1]={name='expired_clock_and_missing_timer',body=[=[
 local page,boundary,t=die();time=11.251;event('UNIT_COMBAT','player','WOUND','',444,1)
 check(boundary.total==0 and not boundary.active and boundary.stopReason=='window-ended','Late dispatch exceeded the diagnostic window')
 dead=false;time=20;event('PLAYER_ALIVE');time=21;dead=true;event('PLAYER_DEAD');page=R:GetPage();boundary=page.liveIncoming.deathBoundary
 time=20.99;event('UNIT_COMBAT','player','WOUND','',444,1)
 check(boundary.total==0 and boundary.stopReason=='clock-unavailable','Backwards clock entered after-notice evidence')
 R:SetOption('enabled',false);dead=false;time=30;R:SetOption('enabled',true)
 local original=C_Timer.NewTimer;C_Timer.NewTimer=function(delay,fn)if delay==.25 then return nil end;return original(delay,fn)end
 time=31;dead=true;event('PLAYER_DEAD');page=R:GetPage();boundary=page.liveIncoming.deathBoundary
 check(not boundary.active and boundary.stopReason=='timer-error'and #boundary.rows==0,'Unavailable timer left an open diagnostic window')
 ]=]}
local assertions=0
for _,case in ipairs(cases)do assertions=assertions+assert(loadstring(prefix..helpers..case.body..'\nreturn checks',case.name))()end
print('PASS: '..assertions..' death-notice delivery/isolation assertions across '..#cases..' synthetic recorder scenarios (offline)')
