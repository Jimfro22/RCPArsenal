-- Real dispatcher, recorder, history, sharing and UI; opaque amounts only reach
-- native setter mocks. This cannot verify vertical native bar pixels in WoW.
local function Read(path)local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local source=Read('tests/hub.lua');source=source:sub(1,assert(source:find('check(db.schemaVersion == 19',1,true))-1)
local ui=Read('tests/death_recap_ui.lua');local marker='source=source..[=[';local first=assert(ui:find(marker,1,true))+#marker
source=source..ui:sub(first,assert(ui:find('local groupCalls=',first,true))-1)
source=source..[=[
local opaque=newproxy(true);local function forbidden()error('Opaque amount inspected or read back')end
for _,key in ipairs({'__tostring','__eq','__lt','__le','__add','__sub','__mul','__div','__concat','__index'})do getmetatable(opaque)[key]=forbidden end
function issecretvalue(v)return rawequal(v,opaque)end
local now,dead=100,false
function GetTime()return now end
function UnitIsDeadOrGhost()return dead end
function UnitHealthMax()return 100000 end
function methods:SetFormattedText(format,value)
 check(format=='%d','Unexpected native format');self.nativeInput=value
 self.text=issecretvalue(value)and''or string.format(format,value)
end
local ordinarySetText=methods.SetText
function methods:SetText(value)check(not issecretvalue(value),'Opaque amount escaped through ordinary text');self.nativeInput=nil;ordinarySetText(self,value)end
function methods:SetMinMaxValues(lo,hi)if self.kind=='StatusBar'then check(lo==0 and hi==100000,'Public reference changed')end;self.lo,self.hi=lo,hi end
function methods:SetOrientation(v)self.orientation=v end
function methods:SetReverseFill(v)self.reverseFill=v end
local ordinaryGetText=methods.GetText
function methods:GetText()if self.__raNativeText then forbidden()end;return ordinaryGetText(self)end
local meterRows={}
Enum=Enum or{};Enum.DamageMeterSessionType={Current=1};Enum.DamageMeterType={Deaths=9}
C_DamageMeter={GetCombatSessionFromType=function()return{combatSources=meterRows}end,GetCombatSessionFromID=function()return{combatSources=meterRows}end}
C_DeathRecap={HasRecapEvents=function()return true end,GetRecapMaxHealth=function()return 100000 end,
 GetRecapEvents=function()return{{timestamp=1000,event='SPELL_DAMAGE',spellId=701,spellName='Named native hit',amount=777,currentHP=500}}end}
local I=RA.DeathRecapProtectedIncoming
R:SetOption('enabled',true);event('DAMAGE_METER_CURRENT_SESSION_UPDATED');event('DAMAGE_METER_COMBAT_SESSION_UPDATED',9,1)
combat=true;event('PLAYER_REGEN_DISABLED')
now=102;event('UNIT_COMBAT','player','WOUND','',opaque,1)
now=106;event('UNIT_COMBAT','player','HEAL','CRITICAL',opaque,1)
event('UNIT_COMBAT','player','WOUND','',120,64)
now=107;event('UNIT_COMBAT','player','HEAL','',3,1)
now=109.9;event('UNIT_COMBAT','player','WOUND','',opaque,4)
meterRows={{isLocalPlayer=true,deathRecapID=71}};now=110;dead=true;event('PLAYER_DEAD')
local page=R:GetPage();check(page.liveIncoming.nativeDisplay.protected==3 and page.liveIncoming.nativeDisplay.retained==5,'Actual death did not freeze private incoming amounts')
check(#page.liveIncoming.rows==2 and page.liveIncoming.rows[1].amount==120,'Protected input entered the public recorder')
-- A protected hit arrives after PLAYER_DEAD; the same existing window owns it.
now=110.2;event('UNIT_COMBAT','player','WOUND','',opaque,1)
now=110.25;event('UNIT_COMBAT','player','HEAL','',7,1)
event('UNIT_COMBAT','target','WOUND','',opaque,1);event('UNIT_COMBAT','player','BLOCK','',opaque,1)
event('UNIT_COMBAT','player','WOUND','',-1,1)
check(page.liveIncoming.nativeLateDisplay.retained==2,'Invalid late input cleared a prior native summary')
local lateTimer;for _,timer in ipairs(timers)do if timer.delay==1 and not timer.cancelled then lateTimer=timer end end
check(lateTimer~=nil,'Late capture added or lost the existing window timer')
now=111;lateTimer.callback()
now=111.2;event('UNIT_COMBAT','player','WOUND','',opaque,1)
check(#I:DescribeLate(page).rows==2,'Closed native late window accepted another receipt')
check(page.liveIncoming.nativeLateDisplay.retained==2 and page.liveIncoming.nativeLateDisplay.protected==1,'Real post-notice event lost its protected amount')
check(#page.liveIncoming.rows==2 and #I:Describe(page).rows==5,'Late receipt changed pre-notice data')
local function clean(value)
 check(not issecretvalue(value),'Opaque amount escaped into public data')
 if type(value)=='table'then for key,v in pairs(value)do clean(key);clean(v)end end
end
clean(page);clean(RA.DeathRecapHistory:Snapshot(page));clean(RaidArsenalDB)
check(R:BuildCoreFactsText():find('INCOMING HISTORY: 5 events / last 8s (2 public amounts, 3 protected amounts)',1,true),'Facts report hid the native display behind public receipt counts')
check(R:BuildCoreFactsText():find('AFTER DEATH NOTICE: 2 events delivered separately',1,true),'Facts report hid late native events')
U:ShowLast();local popup=named.RCPArsenalDeathRecap;local chart=popup.protectedIncomingChart
check(popup.feedMode=='history'and chart:IsShown()and chart.visibleBars==5 and chart.painted==5 and chart.blocked==0,'Protected death failed to select native-rendered history')
check(popup.incomingHistory.damageTotal==nil and popup.incomingHistory.healingTotal==nil,'Protected view invented numeric totals')
local opaqueBars=0
for _,bar in ipairs(chart.bars)do if rawequal(bar.value,opaque)then opaqueBars=opaqueBars+1 end;check(bar.orientation=='VERTICAL','Native bar has wrong orientation')end
check(opaqueBars==3,'Opaque values did not reach individual native bars')
local healing
for _,target in ipairs(chart.targets)do if target.group.kind=='healing'and target.group.rows[1].flag=='CRITICAL'then healing=target end end
check(healing~=nil,'Protected healing has no inspection target');GameTooltip:Hide();healing:Fire('OnEnter')
check(chart.details:IsShown()and rawequal(chart.details.rows[1].amount.nativeInput,opaque),'Hover lost protected healing amount')
check(chart.details.rows[1].kind.text=='Healing · Critical'and not GameTooltip:IsShown(),'Protected tooltip borrowed spell attribution')
local stale=healing.scripts.OnEnter
U:OpenShare();check(not chart.details:IsShown(),'Protected tooltip covered the chat chooser')
stale(healing);check(not chart.details:IsShown(),'Protected hover remained active above the chat chooser')
popup.shareChooser.close:Fire('OnClick');healing:Fire('OnEnter')
healing:Fire('OnLeave');chart.lateHelp:Fire('OnEnter')
check(chart.lateHelp.label.text=='Received after death · 2'and chart.details:IsShown(),'Late native inspection link is missing')
check(rawequal(chart.details.rows[1].amount.nativeInput,opaque)and chart.details.rows[2].amount.nativeInput==7,'Late tooltip lost protected or public amounts')
check(chart.details.rows[1].time.text=='+0.2s'and chart.visibleBars==5 and not chart.guide:IsShown(),'Late tooltip backdated an event onto the timeline')
local oldLate=chart.lateHelp.scripts.OnEnter
chart.lateHelp:Fire('OnLeave');check(not chart.details:IsShown()and chart.details.rows[1].amount.nativeInput==nil,'Late tooltip left native values visible')
healing:Fire('OnLeave');popup.feedSelector.named:Fire('OnClick')
check(popup.feedMode=='named'and not chart:IsShown()and not chart.details:IsShown()and popup.healthPanel:IsShown(),'Named view retained protected chart or lost HP')
for _,bar in ipairs(chart.bars)do check(bar.value==0,'Hidden chart retained native protected input')end
stale(healing);check(not chart.details:IsShown(),'Stale hover reopened a protected tooltip')
oldLate(chart.lateHelp);check(not chart.details:IsShown(),'Stale late hover leaked into named view')
local report=assert(R:BuildShareReport(page,false,'history'))
check(report.text:find('777 damage',1,true)and not report.text:find('Healing /',1,true),'Share invented or exported a protected healing total')
clean(report)
popup.feedSelector.history:Fire('OnClick');healing:Fire('OnEnter');local created=#objects
U:Hide();U:ShowLast();healing:Fire('OnEnter')
check(#objects==created and chart.details:IsShown(),'Reopen grew widgets or lost protected values')
-- A second retained page has its own amounts; switching back restores the first.
local second={id=99,diedAt=130,liveIncoming={},lastAlive={spells={},supplies={}},native=page.native}
I:Begin(120);I:Capture(129,'WOUND','',opaque,1);second.liveIncoming.nativeDisplay=I:Freeze(second,130)
R.GetHistory=function()return{second,page}end;R.IsRetainedPage=function(_,p)return p==page or p==second end
U:ShowPage(second);check(chart.visibleBars==1,'Second page inherited prior protected receipts')
U:ShowPage(page);check(chart.visibleBars==5 and chart.painted==5,'History switch lost prior native display')
-- Busy windows retain one native bar per receipt, with bounded browsing.
local busy={id=100,diedAt=201,liveIncoming={},lastAlive={spells={},supplies={}},native=page.native}
I:Begin(200);for n=1,256 do I:Capture(200+n/10000,'WOUND','',opaque,1)end
busy.liveIncoming.nativeDisplay=I:Freeze(busy,201)
R.GetHistory=function()return{busy,second,page}end;R.IsRetainedPage=function(_,p)return p==page or p==second or p==busy end
U:ShowPage(busy)
check(chart.visibleBars==256 and #chart.bars==256 and chart.painted==256,'Busy view omitted protected events or exceeded its pool')
local target=chart.targets[1];target:Fire('OnEnter')
check(chart.details:IsShown()and #chart.details.rows==12,'Busy native tooltip did not use a bounded visible pool')
for n=1,256 do target:Fire('OnMouseWheel',-1)end
check(target.member==256,'Tooltip wheel cannot browse every busy-window receipt')
local maximumObjects=#objects
for n=1,4 do U:ShowPage(page);U:ShowPage(busy);target:Fire('OnEnter')end
check(#objects==maximumObjects and #chart.bars==256,'Repeated review grew the native widget pool')
-- Public pre-notice amounts and protected late amounts can share a death.
local publicPage={id=101,diedAt=220,lastAlive={spells={},supplies={}},native=page.native,
 liveIncoming={source='UNIT_COMBAT:player',clock='GetTime',startedAt=210,endedAt=220,
 rows={{sequence=1,observedAt=219,kind='damage',amount=12}},
 deathBoundary={source='UNIT_COMBAT:player',clock='GetTime',noticeAt=220,deadline=221,active=false,restricted=1,rows={}}}}
publicPage.liveIncoming.nativeLateDisplay=I:CaptureLate(publicPage,220.2,'WOUND','',opaque,1)
R.GetHistory=function()return{publicPage,page}end;R.IsRetainedPage=function(_,p)return p==page or p==publicPage end
U:ShowPage(publicPage);local publicChart=popup.incomingChart
check(publicChart:IsShown()and not chart:IsShown(),'Protected late receipt replaced a valid public chart')
publicChart.lateHelp:Fire('OnEnter')
check(publicChart.details:IsShown()and rawequal(publicChart.details.rows[1].amount.nativeInput,opaque),'Public chart cannot inspect protected late data')
publicPage.liveIncoming.rows={};U:ShowPage(publicPage)
check(chart:IsShown()and chart.visibleBars==0,'Late-only capture invented pre-notice events or lost inspection access')
chart.lateHelp:Fire('OnEnter');check(chart.details:IsShown(),'Late-only protected amount is inaccessible')
-- Saved public metadata survives reload; private values cannot be persisted.
local saved=RA.DeathRecapHistory:Snapshot(page);saved.restored=true;I:Clear()
R.GetHistory=function()return{saved}end;R.GetPage=function()return saved end;R.IsRetainedPage=function(_,p)return p==saved end
U:ShowLast()
check(popup.feedMode=='named'and not chart:IsShown()and popup.incomingNotice:IsShown(),'Restored page pretended partial public receipts were full history')
check(saved.liveIncoming.nativeDisplay.protected==3 and #saved.liveIncoming.rows==2,'Reload boundary lost its public explanation or public receipts')
check(R:BuildCoreFactsText():find('session-only amounts cleared',1,true),'Saved facts claimed cleared values were still in memory')
clean(saved);U:Hide();check(not popup.incomingNotice:IsShown(),'Closing recap left the reload notice visible')
cleanErrors()
nativePrint('PASS: '..checks..' real-module protected history, native sinks, hover, switching, sharing and reload-boundary assertions')
]=]
assert(loadstring(source,'protected-incoming-ui'))()
