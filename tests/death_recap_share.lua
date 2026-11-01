-- Frozen report facts only. Native rendering, delivery and clock synchronization
-- are separate acceptance concerns; this fixture performs no chat transmission.
local checks=0
local function check(value,message)checks=checks+1;assert(value,message)end
local secret=setmetatable({},{__tostring=function()error('Secret stringified')end})
function issecretvalue(value)return rawequal(value,secret)end
local page
local R={GetPage=function()return page end}
local RA={DeathRecap=R,DeathRecapCatalog={itemUseSpells={[6262]=true}}}
local subscriptions,callbacks={},{}
function RA:RegisterOptionalEvent(event,fn)
 local subscription={event=event,fn=fn,enabled=false};function subscription:SetEnabled(v)self.enabled=v end
 subscriptions[#subscriptions+1]=subscription;return subscription
end
function RA:RegisterCallback(event,fn)callbacks[event]=fn end
local function event(name)for _,s in ipairs(subscriptions)do if s.enabled and s.event==name then s.fn()end end end
assert(loadfile('RCPArsenal/DeathLogModel.lua'))('RCPArsenal',RA)
assert(loadfile('RCPArsenal/DeathRecapActions.lua'))('RCPArsenal',RA)
local function build(preview)
 local report,reason=R:BuildShareReport(page,preview)
 check(report and not reason,'Report unavailable')
 check(R:BuildShareText(page,preview)==report.text,'Text diverges from report snapshot')
 return report
end
local function has(text,part)return text:find(part,1,true)~=nil end
local function row(index,time,name,amount)
 return{nativeIndex=index,nativeOffset=time,spellID=123,name=name,kind='damage',amount=amount,sourceConfirmed=true,sourceKey='A'}
end
page={id=1,diedAt=100,encounter={name='Test encounter',startedAt=0},casts={},native={rows={
 row(2,-5,'First',10),row(3,-4.7,'Third',20),row(4,-4.9,'Second',30),row(1,0,'Fatal',40)}}}
local before={};for i,r in ipairs(page.native.rows)do before[i]=r end
local report=build()
check(#report.entries==5,'Original events or death omitted')
for i,name in ipairs({'First','Second','Third','Fatal'})do check(has(report.entries[i].line,name),'Interleaved group reordered original hits')end
for i,r in ipairs(before)do check(page.native.rows[i]==r,'Build mutated captured row order')end
check(report.entries[1].clock=='native'and has(report.entries[1].line,'recap -5.00s'),'Native offset lost provenance')
check(not has(report.entries[1].line,'1:35'),'Invented native fight timestamp')
check(has(report.entries[5].line,'1:40.00')and report.entries[5].clock=='local','Local death missing fight time')
check(has(report.text,'not aligned to native recap'),'Independent clocks were silently combined')
check(build().text==report.text,'Repeated builds differ')

-- Exact duplicate facts remain distinct, including native fatal before a later
-- unknown event. Native zero is not the local death observation.
page.native.rows={row(3,-1,'Same',15),row(2,-1,'Same',15),row(1,-1,'Fatal',10),
 {nativeIndex=4,nativeOffset=0,spellID=99,name='Unclassified',kind='unknown',event='SPELL_HEAL',amount=8}}
report=build()
check(#report.entries==5,'Equal-time events were deduplicated')
check(report.entries[1].index==1 and report.entries[2].index==2 and report.entries[3].index==3,'Native tie order changed')
check(report.entries[4].kind=='unknown'and has(report.entries[4].line,'event type unknown'),'Unknown native event became healing')
check(report.entries[4].clock=='native'and report.entries[5].kind=='death'and report.entries[5].clock=='local','Native maximum became death')

-- Positive absorption belongs to its original hit. Unknown damage is not zero;
-- markup/secret values never enter plain text or trigger live decoration reads.
page.native.rows={row(1,0,'|Hbad|hInjected|h',nil),row(2,-1,'Zero',0)}
page.native.rows[1].absorbed=20000;page.native.rows[1].overkill=secret
page.native.rows[2].sourceName='Hidden source';page.native.rows[2].hideCaster=true
report=build()
check(#report.entries==3 and has(report.entries[2].line,'spell 123: damage amount unavailable; 20,000 absorbed'),'Absorption duplicated or missing amount became zero')
check(has(report.entries[1].line,'0 damage'),'Public zero lost')
check(not has(report.text,'|')and not has(report.text,'Hidden source'),'Unsafe or hidden source text leaked')
page.native.rows[1].amount=secret;page.native.rows[1].name=secret
report=build();check(has(report.text,'amount unavailable'),'Restricted scalar became amount')

-- Retained uses can exceed the eight visible support icons. Aggregated history
-- never fabricates additional per-use events, healing or availability claims.
page.native=nil;page.casts={};page.observedUses={[123]={observedCount=70,firstSuccessfulUseAt=1,lastSuccessfulUseAt=10}}
for i=1,64 do page.casts[i]={spellID=i==32 and 6262 or 123,name=i~=32 and'Defensive'or nil,observedAt=70+i*.4}end
page.heals={{offset=-1,name='Forged heal',amount=99999}};page.supports={{offset=-2,name='Forged aura',finish=0}}
page.sample=true;page.origin='example'
report=build()
check(#report.entries==65,'Full retained cast ring was capped to visible icons or expanded from summary')
check(has(report.entries[32].line,'spell 6262: observed item use'),'Item receipt misclassified or live name queried')
check(has(report.text,'Native records unavailable')and has(report.text,'last 30 seconds'),'Missing native packet or receipt scope not disclosed')
check(not has(report.text,'Forged')and not has(report.text,'ready')and not has(report.text,'unused defensive'),'Live page trusted fixture fields or invented readiness')
check(not R:BuildShareReport({id=2}),'Stale page accepted')
page.encounter=nil;report=build()
check(has(report.entries[1].line,'local -29.60s')and has(report.entries[65].line,'local +0.00s'),'Missing encounter invented fight time')

-- Private fictional clock can interleave hits, heals, uses and death.
local preview={id=0,diedAt=132,specID=62,class='MAGE',encounter={name='The Coiled Altar',difficulty=16,startedAt=0},
 native={rows={row(2,-4.8,'Axegrinder',15000),row(3,-4.6,'Axegrinder',15000),row(4,-4.4,'Axegrinder',15000),row(1,0,'Venomfang',45000)}},
 heals={{offset=-4.2,name='Flash Heal',spellID=2061,amount=9000,healer='Example healer'}},
 supports={{offset=-3.5,name='Prismatic Barrier',spellID=235450},{offset=-1.8,name='Healthstone',spellID=6262}}}
check(not R:BuildShareReport(preview),'Unmarked sample accepted as recorded page')
local real=page;page=preview;report=build(true);page=real
check(#report.entries==8 and #report.sections==1,'Fictional common timeline is incomplete')
check(has(report.text,'RCP Preview — fictional sample')and has(report.text,'Arcane Mage / The Coiled Altar / Mythic'),'Preview provenance/context missing')
check(has(report.entries[1].line,'2:07.20')and has(report.entries[4].line,'2:07.80'),'Preview fight offsets wrong')
check(has(report.entries[4].line,'9,000 healing from Example healer'),'Healing facts missing')
check(has(report.entries[6].line,'Healthstone: item use'),'Preview item activation missing')
check(report.entries[7].kind=='damage'and report.entries[8].kind=='death'and report.entries[8].time==0,'Death missing or preceding fatal hit')

-- Same bounded native row selection as the display; fatal/largest are retained.
page.native={rows={},truncated=true};page.casts={}
for i=1,80 do page.native.rows[i]=row(i+1,i-80,'Row '..i,i)end
page.native.rows[80].nativeIndex=1;page.native.rows[79].amount=999999
report=build()
check(#report.entries==65 and has(report.text,'capture is truncated'),'Bounded capture scope hidden')
check(has(report.text,'Row 80')and has(report.text,'999,999 damage'),'Displayed fatal/largest row missing')
local long='- [recap -1.00s] '..string.rep('é界',80)..': 1 damage'
local chunks=assert(R:BuildShareMessages({lines={'Header',long,'- [local +0.00s] Death observed'}}))
local reconstructed=''
for i=2,#chunks-1 do
 check(#chunks[i]<=255,'Chunk exceeds conservative byte budget')
 local chunk=i==2 and chunks[i]or chunks[i]:sub(5)
 check(chunk:byte(1)<128 or chunk:byte(1)>=192,'Chunk starts inside UTF-8 character')
 reconstructed=reconstructed..chunk
end
check(reconstructed==long and chunks[#chunks]=='- [local +0.00s] Death observed','Chunking lost text or report tail')
check(not R:BuildShareMessages({lines={'bad\nline'}})and not R:BuildShareMessages({lines={'|Hunsafe|h'}}),'Unsafe chat text accepted')
local excessive={lines={}};for i=1,257 do excessive.lines[i]='Line '..i end
check(not R:BuildShareMessages(excessive),'Oversized report silently truncated')
-- Namespaced ordinary-chat API; no addon transport, native messages or live
-- input. Dispatch is explicit, paced, cancelable and reports submission only.
local time,combat,restricted,permission,group,raid=100,false,false,true,true,true
local calls,timers,progress={}, {},nil
function GetTime()return time end
function InCombatLockdown()return combat end
function IsInGroup()return group end
function IsInRaid()return raid end
C_ChatInfo={InChatMessagingLockdown=function()return restricted end,SendChatMessage=function(text,channel,language,target)
 calls[#calls+1]={text=text,channel=channel,target=target};check(language==nil,'Language was guessed')
end}
C_SocialRestrictions={CanSendChat=function()return permission end}
C_Timer={NewTimer=function(delay,fn)
 check(delay==1,'Queue interval changed');local timer={fn=fn};function timer:Cancel()self.cancelled=true end;timers[#timers+1]=timer;return timer
end}
local open=true
local function current()return open end
local function changed(state)progress=state end
local function nextTimer(force)
 local timer=timers[#timers];check(timer~=nil,'Expected one pending timer');time=time+1
 if force or not timer.cancelled then timer.fn()end
end
local function activeSubscriptions()local n=0;for _,s in ipairs(subscriptions)do if s.enabled then n=n+1 end end;return n end
local outbound={lines={}};for i=1,20 do outbound.lines[i]='- Event '..i end
check(#calls==0 and #timers==0 and activeSubscriptions()==0,'Building reports created chat activity')
check(R:StartShare('WHISPER','Friend-Realm',outbound,current,changed),'Whisper queue failed')
check(#calls==1 and calls[1].target=='Friend-Realm'and progress.submitted==1 and progress.status=='posting','Explicit first submission absent')
check(not R:StartShare('RAID',nil,outbound,current,changed),'Concurrent queue accepted')
outbound.lines[2]='MUTATED'
nextTimer();check(#calls==2 and calls[2].text=='- Event 2','Queued payload was not frozen')
for i=3,20 do nextTimer()end
check(#calls==20 and progress.status=='complete'and progress.total==20 and activeSubscriptions()==0,'Full report stopped at arbitrary line cap or leaked subscriptions')
check(not R:StartShare('WHISPER','Friend-Realm',outbound,current,changed),'Completed snapshot silently resubmitted')
local previous=#calls
local function fresh()return{lines={'Header','- First','- Last'}}end
check(R:StartShare('PARTY',nil,fresh(),current,changed),'Party queue failed')
local cancelledTimer=timers[#timers];R:CancelShare('User cancelled');cancelledTimer.fn()
check(#calls==previous+1 and progress.status=='stopped'and cancelledTimer.cancelled and activeSubscriptions()==0,'Cancelled timer still submitted')
local old=cancelledTimer
check(R:StartShare('RAID',nil,fresh(),current,changed),'New generation failed');old.fn();check(#calls==previous+2,'Stale generation acted on new report')
event('GROUP_ROSTER_UPDATE');nextTimer(true);check(#calls==previous+2 and progress.reason=='Group changed','Changed group retained queue')
for _,name in ipairs({'PLAYER_REGEN_DISABLED','ENCOUNTER_START','PLAYER_ENTERING_WORLD','PLAYER_LOGOUT'})do
 local n=#calls;check(R:StartShare('WHISPER','Friend-Realm',fresh(),current,changed),'Context test start failed');event(name);nextTimer(true)
 check(#calls==n+1 and progress.status=='stopped'and activeSubscriptions()==0,'Context event failed cancellation: '..name)
end
local n=#calls;check(R:StartShare('RAID',nil,fresh(),current,changed),'Restriction test failed');restricted=true;nextTimer()
check(#calls==n+1 and progress.status=='stopped','Mid-queue restriction ignored');restricted=false
for _,value in ipairs({true,secret})do combat=value;check(not R:StartShare('RAID',nil,fresh(),current,changed),'Combat/unknown combat accepted')end;combat=false
permission=secret;check(not R:StartShare('RAID',nil,fresh(),current,changed),'Secret social permission accepted');permission=true
group=false;check(not R:StartShare('PARTY',nil,fresh(),current,changed),'Absent party accepted');group=true
raid=false;check(not R:StartShare('RAID',nil,fresh(),current,changed),'Absent raid accepted');raid=true
check(not R:StartShare('WHISPER','Bad Name',fresh(),current,changed),'Invalid whisper accepted')
local say=fresh();n=#calls;local timerCount=#timers
check(R:StartShare('SAY',nil,say,current,changed),'Manual SAY first line failed')
check(#calls==n+1 and #timers==timerCount and progress.manual,'SAY used a timer')
check(R:SendNextShare(say)and #calls==n+2 and R:SendNextShare(say)and #calls==n+3 and progress.status=='complete','Manual SAY cannot reach report tail')
check(not R:SendNextShare(say)and #calls==n+3,'Manual duplicate submitted')
check(R:StartShare('RAID',nil,fresh(),current,changed),'Close test failed');n=#calls;open=false;nextTimer();check(#calls==n and progress.status=='stopped','Closed page callback sent');open=true
local send=C_ChatInfo.SendChatMessage;C_ChatInfo.SendChatMessage=function()error('Native rejection')end
local priorTimers=#timers;R:StartShare('RAID',nil,fresh(),current,changed)
check(progress.status=='stopped'and progress.submitted==0 and #timers==priorTimers,'Error retried or claimed submission');C_ChatInfo.SendChatMessage=send
check(R:StartShare('RAID',nil,fresh(),current,changed),'Deadline test failed');n=#calls;time=time+1000;nextTimer();check(#calls==n and progress.status=='stopped','Expired queue sent')
check(activeSubscriptions()==0,'Idle queue left optional events active')
print('PASS: '..checks..' full Death Log report assertions (offline)')
