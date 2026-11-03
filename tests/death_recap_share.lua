-- Compact sharing uses frozen named hits from either tab. No native delivery claim.
local checks=0
local function check(value,message)checks=checks+1;assert(value,message)end
local secret=setmetatable({},{__tostring=function()error('Secret stringified')end})
function issecretvalue(value)return rawequal(value,secret)end
local page
local R={GetPage=function()return page end}
function R:IsRetainedPage(value)return value==page end
function R:GetCooldownRows(value)return value.cooldownRows or{}end
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
local function has(text,part)return text:find(part,1,true)~=nil end
local function row(index,time,name,amount)
 return{nativeIndex=index,nativeOffset=time,spellID=123,name=name,kind='damage',amount=amount}
end
page={id=1,playerName='Fro',diedAt=100,encounter={name='Test encounter',startedAt=0},casts={{spellID=235450,name='Do not dump cast history',observedAt=99}},
 native={rows={}},cooldownRows={{spellID=414658,name='Ice Cold',recordedState=true},{spellID=235450,name='Barrier',recordedState=false},
 {spellID=55342,name='Mirror Image',recordedState=nil},{kind='potion',recordedState=true}}}
for i=1,12 do page.native.rows[i]=row(i,-(i-1)*.5,'Hit '..i,1000+i)end
page.native.rows[1].overkill=500;page.native.rows[2].absorbed=250
page.native.rows[13]=row(13,-6.01,'Too old',99999)
page.native.rows[14]={nativeIndex=14,nativeOffset=-.2,spellID=55,kind='unknown',amount=99999,name='Not damage'}
page.liveIncoming={source='UNIT_COMBAT:player',clock='GetTime',startedAt=80,endedAt=100,rows={
 {kind='healing',observedAt=93.99,sequence=1,amount=900000},
 {kind='healing',observedAt=94,sequence=2,amount=300},
 {kind='damage',observedAt=99,sequence=3,amount=88888},
 {kind='healing',observedAt=99,sequence=4,amount=700}}}
local original=page.native.rows
local report=assert(R:BuildShareReport(page,false,'history'))
check(report.feedMode=='named'and #report.entries==6 and #report.sections==1,'Share did not cap to six named hits')
check(report.text==R:BuildShareText(page,false,'named'),'Selected tab changes the shared report')
check(page.native.rows==original and #original==14,'Sharing mutated stored data')
check(report.entries[1].index==6 and report.entries[6].index==1,'Latest hits are not chronological with fatal last')
check(not has(report.text,'Too old')and not has(report.text,'Not damage')and not has(report.text,'88.9k')and not has(report.text,'dump cast'),'History/older/unknown records leaked into chat')
check(report.summary.damage==6021 and report.summary.absorbed==250 and report.summary.overkill==500,'Selected hit totals differ from members')
check(report.summary.healing==1000 and report.summary.healingSpan==6 and has(report.text,'Healing / last 6.0s: 1.0k'),'Separate six-second healing total is wrong')
check(has(report.text,'Available: Ice Cold, Healing potion')and not has(report.text,'Barrier')and not has(report.text,'Mirror Image'),'Unconfirmed/unavailable abilities called available')
for _,entry in ipairs(report.entries)do
 check(not has(entry.line,'absorbed')and not has(entry.line,'overkill')and not has(entry.line,'source'),'Per-hit line is not concise')
 check(entry.clock=='native'and not has(entry.line,'1:3'),'Named hit was assigned an unproven fight time')
end
check(#report.lines==10 and has(report.text,'Fro')and has(report.text,'Killing blow'),'Compact report context or bounded lines missing')
local missing={id=2};check(not R:BuildShareReport(missing),'Stale record accepted')
page.native.rows={row(1,0,'Fatal',secret),row(2,-1,'Earlier',50),row(3,-1,'Same time',70)}
report=assert(R:BuildShareReport(page));check(#report.entries==2 and report.entries[1].index==3,'Restricted amount used or equal-time native order lost')
page.native=nil;page.cooldownRows={};page.liveIncoming=nil
report=assert(R:BuildShareReport(page));check(#report.entries==0 and has(report.text,'No named hits recorded')and not has(report.text,'Healing /'),'Missing facts became zero or anonymous history dump')
local preview={id=0,diedAt=132,native={rows={row(1,0,'Sample hit',45000)}},heals={{offset=-1,amount=9000}}}
check(not R:BuildShareReport(preview),'Unmarked sample accepted')
check(has(assert(R:BuildShareReport(preview,true)).text,'Preview — sample'),'Preview identification lost')

-- Verified native links stay atomic and frozen; captured markup is never a link.
local reads=0
local nativeLink='|cff71d5ff|Hspell:123:0|h[Verified hit]|h|r'
C_Spell={GetSpellLink=function(id)reads=reads+1;return id==123 and nativeLink end}
page.native={rows={row(1,0,'Captured',100),row(2,-.2,'Captured',200)}}
local linked=assert(R:BuildShareReport(page));check(reads==1 and not has(linked.text,'|'),'Metadata not cached or copy has markup')
local output=table.concat(assert(R:BuildShareMessages(linked)),'\n')
check(has(output,nativeLink),'Verified clickable spell link missing')
linked.lines[1]='|Hunsafe|h';linked.chatLines={{nativeLink}}
check(table.concat(assert(R:BuildShareMessages(linked)),'\n')==output,'Public report mutation changed frozen transport')
check(not R:BuildShareMessages({lines={nativeLink}}),'Unverified native-looking markup accepted')
for _,bad in ipairs({secret,'|Hspell:1|h[Wrong ID]|h','|Hitem:123|h[Item]|h','|Hspell:123|h[Name\n]|h'})do
 C_Spell.GetSpellLink=function()return bad end;C_Spell.GetSpellName=function()return 'Verified fallback' end
 local safe=assert(R:BuildShareReport(page));check(has(safe.text,'Verified fallback')and not has(table.concat(assert(R:BuildShareMessages(safe))),'|'),'Bad link not rejected')
end
local label=string.rep('界',40);local longLink='|cff71d5ff|Hspell:123:'..string.rep('0:',42)..'0|h['..label..']|h|r'
C_Spell.GetSpellLink=function()return longLink end
local wide=assert(R:BuildShareReport(page));local found=false
for _,message in ipairs(assert(R:BuildShareMessages(wide)))do check(#message<=255,'Message byte budget exceeded');if has(message,'|')then check(has(message,longLink),'Long link split');found=true end end
check(found,'Long valid native link lost')
C_Spell=nil
for _,invalid in ipairs({'bad\nline','|Hunsafe|h',string.char(128),string.char(192,128),string.char(240,159)})do
 check(not R:BuildShareMessages({lines={invalid}}),'Unsafe text or UTF-8 accepted')
end
local excessive={lines={}};for i=1,257 do excessive.lines[i]='Line '..i end
check(not R:BuildShareMessages(excessive),'Oversized message count not bounded')

local linkedMessages=assert(R:BuildShareMessages(linked))

-- Namespaced ordinary-chat API; no addon transport, native messages or live
-- input. Dispatch is explicit, paced, cancelable and reports submission only.
local time,combat,restricted,permission,group,raid,instance=100,false,false,true,true,true,false
LE_PARTY_CATEGORY_HOME,LE_PARTY_CATEGORY_INSTANCE=1,2
local calls,timers,progress={}, {},nil
function GetTime()return time end
function InCombatLockdown()return combat end
function IsInGroup(category)check(category==1 or category==2,'Group category omitted');return category==2 and instance or(category==1 and group)end
function IsInRaid(category)check(category==1,'Raid category omitted');return raid end
C_ChatInfo={InChatMessagingLockdown=function()return restricted end,SendChatMessage=function(text,channel,language,target)
 calls[#calls+1]={text=text,channel=channel,target=target};check(language==nil,'Language was guessed')
end}
C_SocialRestrictions={CanSendChat=function()return permission end}
C_Timer={NewTimer=function(delay,fn)
 check(delay==1,'Queue interval changed');local timer={fn=fn};function timer:Cancel()self.cancelled=true end;timers[#timers+1]=timer;return timer
end}
-- Resolve current public player identity only when opening/choosing. Snapshot
-- comparison prevents a second-click target switch, while queues keep the
-- chosen recipient if target later changes.
local targetPlayer,targetName,targetRealm,targetGUID=true,'Friend','Realm','Player-1-ABC123'
local targetReads=0
function UnitIsPlayer(unit)check(unit=='target','Wrong target unit');return targetPlayer end
function UnitFullName(unit)targetReads=targetReads+1;check(unit=='target','Wrong name unit');return targetName,targetRealm end
function UnitGUID(unit)check(unit=='target','Wrong GUID unit');return targetGUID end
function GetNormalizedRealmName()return 'HomeRealm' end
local target=assert(R:ResolveShareTarget())
check(target.name=='Friend-Realm'and target.guid=='Player-1-ABC123','Target snapshot is not Name-Realm/GUID')
local destination=assert(R:GetShareDestination('WHISPER',target))
check(destination.target==target.name and destination.targetGUID==target.guid and destination.label==target.name,'Destination lost frozen player identity')
targetGUID='Player-1-DEF456';check(not R:GetShareDestination('WHISPER',target),'Changed target GUID accepted');targetGUID=target.guid
targetName='Other';check(not R:GetShareDestination('WHISPER',target),'Changed target name accepted');targetName='Friend'
for _,value in ipairs({false,secret})do targetPlayer=value;check(not R:ResolveShareTarget(),'Nonplayer/secret target accepted')end;targetPlayer=true
targetName=secret;check(not R:ResolveShareTarget(),'Secret target name accepted');targetName='Friend'
targetRealm=secret;check(not R:ResolveShareTarget(),'Secret realm became home realm');targetRealm=''
check(R:ResolveShareTarget().name=='Friend-HomeRealm','Public empty realm did not normalize')
targetRealm=nil;check(R:ResolveShareTarget().name=='Friend-HomeRealm','Public nil realm did not normalize');targetRealm='Realm'
targetGUID=secret;check(not R:ResolveShareTarget(),'Secret GUID accepted');targetGUID=target.guid
targetName='Bad|Name';check(not R:ResolveShareTarget(),'Markup target accepted');targetName='Friend'
check(not R:GetShareDestination('WHISPER',secret),'Secret target snapshot inspected or accepted')
check(not R:GetShareDestination('INSTANCE_CHAT'),'Absent instance group accepted')
instance=true;group=false;raid=false
check(not R:GetShareDestination('PARTY')and not R:GetShareDestination('RAID'),'Instance group silently became home destination')
check(R:GetShareDestination('INSTANCE_CHAT').channel=='INSTANCE_CHAT','Explicit instance destination unavailable')
instance=false;group=true;raid=true
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
check(R:StartShare('WHISPER',target,outbound,current,changed),'Whisper queue failed')
local readsAtStart=targetReads;targetName='ChangedAfterSend';targetGUID='Player-1-ABCD00'
check(#calls==1 and calls[1].target=='Friend-Realm'and progress.submitted==1 and progress.status=='posting','Explicit first submission absent')
check(not R:StartShare('RAID',nil,outbound,current,changed),'Concurrent queue accepted')
outbound.lines[2]='MUTATED'
nextTimer();check(#calls==2 and calls[2].text=='- Event 2','Queued payload was not frozen')
check(calls[2].target=='Friend-Realm'and targetReads==readsAtStart,'Queue re-resolved or redirected Whisper target')
targetName='Friend';targetGUID=target.guid
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
for _,name in ipairs({'PLAYER_REGEN_DISABLED','ENCOUNTER_START','PLAYER_LEAVING_WORLD','PLAYER_ENTERING_WORLD','PLAYER_LOGOUT'})do
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
instance=true
local instanceReport=fresh();local countBefore=#calls
check(R:StartShare('INSTANCE_CHAT',nil,instanceReport,current,changed),'Explicit instance queue failed')
check(calls[#calls].channel=='INSTANCE_CHAT'and #calls==countBefore+1,'Instance route was redirected')
event('GROUP_ROSTER_UPDATE');nextTimer(true)
check(#calls==countBefore+1 and progress.status=='stopped','Instance group change left queue active')
instance=false
local linkedCount=#calls
check(R:StartShare('WHISPER',target,linked,current,changed),'Validated linked report failed dispatch')
for i=2,#linkedMessages do nextTimer()end
check(#calls==linkedCount+#linkedMessages and progress.status=='complete','Linked report lost tail')
local receivedLinks=0
for i=linkedCount+1,#calls do if has(calls[i].text,nativeLink)then receivedLinks=receivedLinks+1 end end
check(receivedLinks==2,'Validated native links failed final dispatch guard')
check(activeSubscriptions()==0,'Idle queue left optional events active')
print('PASS: '..checks..' compact Death Log report assertions (offline)')
