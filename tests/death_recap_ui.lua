-- Actual addon modules and UI callbacks in the existing native-region fixture.
-- This checks decisions/layout inputs; it is not native rendering or taint QA.
local f=assert(io.open('tests/hub.lua'));local source=f:read('*a');f:close()
source=source:sub(1,assert(source:find('check(db.schemaVersion == 19',1,true))-1)
source=source..[=[
function methods:GetScript(name)return self.scripts[name]end
function methods:SetAlpha(value)check(type(value)=='number' and value==value and value>=0 and value<=1,'Invalid native alpha argument');self.alpha=value end
function methods:GetValue()error('Recap read back a native bar value')end
local tooltipSpell,tooltipLines=nil,{}
function GameTooltip:SetSpellByID(id)tooltipSpell=id end
function GameTooltip:AddLine(line)table.insert(tooltipLines,line)end
local R,U=RA.DeathRecap,RA.DeathRecapUI
check(not db.deathRecap.enabled and db.deathRecap.autoOpen and not named.RCPArsenalDeathRecap,'Default OFF eagerly built popup')
local page={id=10,diedAt=100,casts={{spellID=871,observedAt=99}},native={rows={
    {spellID=123,name='Earlier',kind='damage',nativeOffset=-4.5,nativeIndex=2,amount=10000000000000},
    {spellID=124,name='Fatal',kind='damage',nativeOffset=-4.4,nativeIndex=1,amount=200},
    {spellID=125,name='Unclassified',kind='unknown',nativeOffset=0,nativeIndex=3}}},
    lastAlive={supplies={{kind='potion',carried=false,carriedAt=1,observedAt=99.9,cooldown='unknown'}},spells={
        {spellID=871,name='Zero charges',category='major',observedAt=99.9,isEnabled=true,cooldown='inactive',chargeQuery='public',maxCharges=2,currentCharges=0},
        {spellID=23920,name='Opaque charges',category='minor',observedAt=99.9,isEnabled=true,cooldown='inactive',chargeQuery='unreadable'},
        {spellID=1234,name='Positive narrow fact',category='minor',observedAt=99.9,isEnabled=true,cooldown='inactive',chargeQuery='not_applicable'}}}}
R.GetPage=function()return page end
local stateGetter=R.GetState
R.GetState=function(self)local s=stateGetter(self);s.hasPage=page~=nil;return s end
local function under(obj,ancestor)
    while obj do if obj==ancestor then return true end;obj=obj.parent end
end
local function button(label,visible)
    for _,obj in ipairs(objects)do
        if obj.label and obj.label.text==label and under(obj,named.RCPArsenalDeathRecap)and(visible==false or obj:IsVisible())then return obj end
    end
end
local function tray()
    local out={};for _,obj in ipairs(objects)do if obj.parent==named.RCPArsenalDeathRecap and obj.icon and obj.width==32 and obj:IsVisible()then out[#out+1]=obj end end;return out
end
check(U:ShowLast(),'View last refused recorded data')
local popup=named.RCPArsenalDeathRecap
check(popup.width==640 and popup.height<480 and not popup.keyboard and not popup.focus,'Popup geometry/focus capture changed')
check(popup.hp.text=='' and not popup.healthPanel:IsShown() and not popup.healing:IsShown() and popup.damage.text=='Events','Unknown HP/event kind became health/damage')
local rows=tray();check(#rows==4,'Observation tray lost rows')
check(rows[1].stateLabel.text=='Unknown' and rows[1].icon.alpha==.7,'Old absence became current unavailable')
check(rows[2].stateLabel.text=='No charges' and rows[2].icon.alpha==.35,'Zero charges became positive fact')
check(rows[3].stateLabel.text=='Unknown' and rows[3].icon.alpha==.7,'Opaque charge query became positive fact')
check(rows[4].stateLabel.text=='Off cooldown','Verified narrow cooldown fact missing')
tooltipLines={};rows[1]:Fire('OnEnter')
local itemHelp=table.concat(tooltipLines,' ')
check(itemHelp:find('99.0s',1,true),'Absence tooltip omitted actual bag-cache age')
check(not itemHelp:find('Source:',1,true) and not itemHelp:find('Native cooldown',1,true) and not itemHelp:find('Frozen last-alive',1,true),'Normal tooltip retained developer provenance dump')
local grouped
for _,obj in ipairs(objects)do if obj.parent==popup and obj.group and #obj.group.rows==2 then grouped=obj end end
check(grouped and grouped.group.rows[grouped.selected].nativeIndex==1,'Group did not preserve/select native killing row')
grouped:Fire('OnEnter');check(tooltipSpell==124 and popup.guide:IsShown(),'Selected native tooltip/guide missing')
check(#grouped.amount.text<12 and grouped.amount.width==82,'Large amount not bounded/compacted')
grouped:Fire('OnClick');check(tooltipSpell==123 and grouped.group.rows[grouped.selected].nativeIndex==2,'Cycling kept stale tooltip/selection')
check(grouped.group.rows[1].nativeOffset==-4.5 and grouped.group.rows[2].nativeOffset==-4.4 and popup.axis.text=='−4.5s','Renderer rebased native time to the killing row')
check(popup.axisEnd.points[1][4]==584 and popup.axisEnd.text=='Death','Axis endpoint uses proportional whitespace')
-- Preview must close live popovers and execution-time callbacks must recheck.
db.personalTools.consumableReminder=false
U:OpenBell();local enable=button('ENABLE');check(enable and enable:IsVisible(),'Live reminder confirmation absent')
local saved={};for key,value in pairs(db.personalTools)do saved[key]=value end
local beforePage=R:GetPage();local diagnostics=R:GetDiagnostics();U:Preview()
check(not enable:IsVisible() and popup.coverage.text=='Example data · Arcane Mage','Preview inherited live confirmation or lacks sample label')
enable:Fire('OnClick')
check(not db.personalTools.consumableReminder and R:GetPage()==beforePage,'Stale live callback in sample changed settings/history')
for key,value in pairs(saved)do check(db.personalTools[key]==value,'Preview changed child preferences')end
check(R:GetDiagnostics().samples==diagnostics.samples and R:GetDiagnostics().nativeReads==diagnostics.nativeReads,'Preview queried recorder/native model')
U:OpenShare();check(not button('OPEN CHAT'),'Sample opened live share')

-- Explicit Preview alone owns its fictional health/heal arrays.
check(popup.width==640 and popup.height==480 and popup.fight.text=='Fight 2:12','Example geometry or encounter clock incorrect')
check(popup.instruction.text=='Hover a hit or item for details','Player instruction missing')
check(popup.healthPanel.selectedHP==33300 and popup.healthPanel.selectedMax==100000 and popup.healthPanel.selectedRatio==.333 and popup.healthBar:IsShown(),'Preview did not open a filled exact last-nonfatal bar')
check(popup.hp.text:find('33,300',1,true) and popup.hp.text:find('33.3%',1,true) and popup.hp.text:find('-1.0s',1,true),'Exact example health/percent/time unreadable')
rows=tray();local ids={};local labels={'Off cooldown','No item','Used','Off cooldown','Cooldown'}
for i,b in ipairs(rows)do ids[b.icon.__raSpellID or 0]=true;check(b.stateLabel.text==labels[i] and b.stateLabel.fontSize==11,'Example state copy/font/order wrong')end
check(#rows==5 and rows[3].icon.alpha==1,'Example Mage defensive tray missing/used barrier faded')
local expectedIDs={5512,241304,235450,342245,45438}
for i,b in ipairs(rows)do
    tooltipSpell=nil;tooltipLines={};b:Fire('OnEnter')
    if i>=3 then check(tooltipSpell==expectedIDs[i],'Example defensive identity is not the chosen Arcane fixture')end
    check(b.points[1][5]==-414 and b.height==32 and b.stateLabel.points[1][5]==-4,'Footer clipped the intended bottom margin')
end
check(popup.divider.points[1][5]==-385 and popup.details.height==28,'Example footer geometry drifted')
local function hits()
    local out={};for _,obj in ipairs(objects)do if obj.parent==popup and obj.group and obj:IsVisible()then out[#out+1]=obj end end;return out
end
local function hoverHit(nativeIndex)
    for _,b in ipairs(hits())do for i,row in ipairs(b.group.rows)do if row.nativeIndex==nativeIndex then b.selected=i;b:Fire('OnEnter');return b end end end
    error('Missing hit '..nativeIndex)
end
local fixtureIDs={};for _,b in ipairs(hits())do for _,row in ipairs(b.group.rows)do fixtureIDs[row.spellID]=true end end
check(fixtureIDs[12294] and fixtureIDs[686] and fixtureIDs[172] and fixtureIDs[116858],'Example damage fixture incomplete')
hoverHit(1);check(popup.healthPanel.selectedHP==0 and popup.healthBar:IsShown() and popup.hp.text:find('0.0%',1,true),'Known example fatal zero became missing')
hoverHit(2);check(popup.healthPanel.selectedHP==68000,'Example hit failed to select exact HP')
local frameCount,timerCount=#objects,#timers
for i=1,50 do hoverHit(4)end
check(#objects==frameCount and #timers==timerCount,'Hover allocated frames or timers')
for _,obj in ipairs(objects)do if under(obj,popup)then check(obj.scripts.OnUpdate==nil,'Recap added a frame poller')end end
local reads=0;local oldGetPage=R.GetPage;R.GetPage=function()reads=reads+1;return page end
U:Preview();check(reads==0,'Preview read real history');R.GetPage=oldGetPage
-- A real page carrying plausible fixture fields must remain real. Only the
-- accepted native HP fields and fixed recap denominator may drive its display.
local realPage=page
page={id=11,diedAt=100,sample=true,origin='example',maxHealth=100000,
    healthPoints={{offset=-4.5,hp=92000},{offset=0,hp=0}},heals={{offset=-1,hp=77000}},casts={},
    native={recapID=5,recapMaxHealth=1000,rows={
        {nativeIndex=2,nativeOffset=-4.5,spellID=123,kind='damage',amount=50,recordedHP=750,exampleHP=92000},
        {nativeIndex=3,nativeOffset=-3,spellID=124,kind='damage',amount=50,exampleHP=77000},
        {nativeIndex=4,nativeOffset=-1,spellID=125,kind='damage',amount=50,recordedHP=1200},
        {nativeIndex=1,nativeOffset=0,spellID=126,kind='damage',amount=50,recordedHP=0}}},
    lastAlive={supplies={},spells={{spellID=871,category='major',observedAt=99.9,isEnabled=true,cooldown='active',chargeQuery='not_applicable',exampleState='Used'}}}}
U:ShowLast();check(popup.coverage.text=='Some details unavailable' and not popup.healing:IsShown() and popup.health.text=='Recorded health','Real page adopted fictional origin/healing')
check(popup.healthPanel.selectedHP==0,'Initial native selection did not match the killing event');hoverHit(2)
check(popup.healthPanel.selectedHP==750 and popup.healthPanel.selectedRatio==.75,'Public native snapshot/recap max did not drive real bar')
check(tray()[1].stateLabel.text=='Cooldown','Real state adopted fictional override')
local function markCount()
    local n=0;for _,obj in ipairs(objects)do if obj.parent==popup and obj.kind=='Texture' and obj:IsVisible() and obj.width==5 and obj.height==5 then n=n+1 end end;return n
end
check(markCount()==2,'Native ribbon connected/interpolated gaps or out-of-scale HP')
hoverHit(3);check(not popup.healthBar:IsShown() and not popup.healthTrack:IsShown() and popup.healthPanel.selectedHP==nil and popup.hp.text=='Recorded health: Unknown','Unknown row retained prior bar/value')
tooltipLines={};popup.healthPanel:Fire('OnEnter');local help=table.concat(tooltipLines,' ');check(help:find('Health was not recorded for this event.',1,true) and help:find('1,000',1,true) and not help:find('maximum health value was not recorded',1,true),'Unknown HP misreported a valid max as missing')
hoverHit(4);check(popup.healthPanel.selectedHP==1200 and not popup.healthBar:IsShown() and popup.hp.text=='1,200','Out-of-scale HP was lost or clamped')
hoverHit(1);check(popup.healthPanel.selectedHP==0 and popup.healthBar:IsShown(),'Real public zero was treated as missing')
local private=setmetatable({},{__tostring=function()error('Secret HP stringified')end})
issecretvalue=function(value)return rawequal(value,private)end
local invalid={false,private,-1,0/0,math.huge,-math.huge,'42',{}}
for _,value in ipairs(invalid)do
    page.native.rows[1].recordedHP=value;U:ShowLast();hoverHit(2)
    check(popup.healthPanel.selectedHP==nil and not popup.healthBar:IsShown(),'Invalid HP became a known value')
end
page.native.rows[1].recordedHP=750
for _,value in ipairs({false,private,0,-1,0/0,math.huge,-math.huge,'1000',{}})do
    page.native.recapMaxHealth=value;U:ShowLast();hoverHit(2)
    check(popup.healthPanel.selectedHP==750 and popup.hp.text=='750' and not popup.healthBar:IsShown() and markCount()==0,'Invalid denominator lost raw HP or invented scale')
end
page.native.recapMaxHealth=nil;U:ShowLast();hoverHit(2)
check(popup.healthPanel.selectedHP==750 and not popup.healthBar:IsShown(),'Missing denominator lost raw HP')
page.native.recapID=nil;U:ShowLast();check(not popup.healthPanel:IsShown(),'Unidentified page supplied native health')
-- The initial bar and grouped icon must refer to the same killing event.
page.native.recapID=5;page.native.recapMaxHealth=1000
page.native.rows={
    {nativeIndex=2,nativeOffset=-4.5,spellID=123,kind='damage',amount=10,recordedHP=750},
    {nativeIndex=1,nativeOffset=-4.4,spellID=124,kind='damage',amount=10,recordedHP=200},
    {nativeIndex=3,nativeOffset=0,spellID=125,kind='unknown'}}
U:ShowLast();local initialGroup=hits()[1]
check(initialGroup.group.rows[initialGroup.selected].nativeIndex==1 and popup.healthPanel.selectedHP==200,'Initial grouped icon and health value describe different events')
-- All sixteen bounded records remain reachable, including collapsed groups.
page.native.rows={};for i=1,16 do page.native.rows[i]={nativeIndex=i,nativeOffset=(i-16)*.001,spellID=100+i,kind='damage',amount=i}end
U:ShowLast();local seen={}
for _,b in ipairs(hits())do for i=1,#b.group.rows do b:Fire('OnClick');seen[b.group.rows[b.selected].nativeIndex]=true end end
for i=1,16 do check(seen[i],'Grouped hit lost member '..i)end
page=realPage;U:ShowLast()

U:ShowLast();U:OpenShare();local open=button('OPEN CHAT');check(open,'Live public composer dialog absent')
local composerCalls=0
check(C_ChatInfo.HasRestrictions==nil,'Fixture invented an unsupported chat query')
C_ChatInfo.InChatMessagingLockdown=function()return false end
C_SocialRestrictions={CanSendChat=function()return true end}
local box={SetAttribute=function(self,key,value)self[key]=value end}
ChatFrame_OpenChat=function(text)composerCalls=composerCalls+1;check(not text:find('10000000000000',1,true),'Unselected/unknown event serialized as fatal')end
ChatEdit_GetActiveWindow=function()return box end;ChatEdit_UpdateHeader=function()end
U:Preview();open:Fire('OnClick');check(composerCalls==0,'Stale live Share callback acted in preview')
U:ShowLast();U:OpenBell();enable=button('ENABLE');enable:Fire('OnClick')
check(db.personalTools.consumableReminder,'Explicit real confirmation did not enable existing reminder')
for key,value in pairs(saved)do if key~='consumableReminder'then check(db.personalTools[key]==value,'Bell changed child option')end end
RA.PersonalTools:SetOption('consumableReminder',false)
-- Manual close/life events and disabled auto-open cannot resurrect the popup.
db.deathRecap.autoOpen=true;RA:FireCallback('DEATH_RECAP_CHANGED','death');check(popup:IsShown(),'Death opt-in auto popup did not show')
U:Hide();RA:FireCallback('DEATH_RECAP_CHANGED','native');check(not popup:IsShown(),'Late data reopened closed popup')
U:ShowLast();RA:FireCallback('DEATH_RECAP_CHANGED','life');check(not popup:IsShown()and R:GetPage()==beforePage,'Resurrection did not close/preserve')
db.deathRecap.autoOpen=false;U:ShowLast();RA:FireCallback('DEATH_RECAP_CHANGED','death');check(not popup:IsShown(),'Auto-open OFF retained previous page popup')
-- Explicit sharing is guarded, prepares only native text and never sends.
local ok,reason=R:PrepareShare('WHISPER','',page);check(not ok and composerCalls==0,'Blank whisper target accepted')
ok=R:PrepareShare('WHISPER','Friend-Realm',page);check(ok and composerCalls==1 and box.chatType=='WHISPER'and box.tellTarget=='Friend-Realm','Native composer/recipient incorrect')
ok=R:PrepareShare('SAY',nil,page);check(ok and composerCalls==2 and box.chatType=='SAY','Supported API-only surface did not prepare native chat')
C_ChatInfo.InChatMessagingLockdown=function()return true end
check(not R:PrepareShare('SAY',nil,page)and composerCalls==2,'Chat lockdown bypassed')
check(not R:GetJournalMapping(nil,nil)and not R:OpenJournal(page,page.native.rows[1]),'Missing Journal mapping navigated')
check(sent==0 and talentReads==0 and inspectCalls==0,'UI sent messages or inspected raid')
cleanErrors()
nativePrint('PASS: '..checks..' actual death recap UI/preview/charge/group/share/lifecycle assertions (offline; native visuals pending)')
]=]
assert(loadstring(source,'death-recap-ui-fixture'))()
