-- Actual addon modules and UI callbacks in the existing native-region fixture.
-- This checks decisions/layout inputs; it is not native rendering or taint QA.
local f=assert(io.open('tests/hub.lua'));local source=f:read('*a');f:close()
source=source:sub(1,assert(source:find('check(db.schemaVersion == 19',1,true))-1)
source=source..[=[
function methods:GetScript(name)return self.scripts[name]end
function methods:SetAlpha(value)self.alpha=value end
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
    local out={};for _,obj in ipairs(objects)do if obj.parent==named.RCPArsenalDeathRecap and obj.icon and obj.width==30 and obj:IsVisible()then out[#out+1]=obj end end;return out
end
check(U:ShowLast(),'View last refused recorded data')
local popup=named.RCPArsenalDeathRecap
check(popup.width==560 and popup.height==325 and not popup.keyboard and not popup.focus,'Popup geometry/focus capture changed')
check(popup.hp.text=='HP snapshot —' and popup.damage.text=='Records','Unknown HP/event kind became health/damage')
local rows=tray();check(#rows==4,'Observation tray lost rows')
check(rows[1].badge.text=='?' and rows[1].icon.alpha==.7,'Old absence became current unavailable')
check(rows[2].badge.text=='×' and rows[2].icon.alpha==.35,'Zero charges became positive fact')
check(rows[3].badge.text=='?' and rows[3].icon.alpha==.7,'Opaque charge query became positive fact')
check(rows[4].badge.text=='✓','Verified narrow cooldown fact missing')
tooltipLines={};rows[1]:Fire('OnEnter')
check(table.concat(tooltipLines,' '):find('99.0s',1,true),'Absence tooltip omitted actual bag-cache age')
local grouped
for _,obj in ipairs(objects)do if obj.parent==popup and obj.group and #obj.group.rows==2 then grouped=obj end end
check(grouped and grouped.group.rows[grouped.selected].nativeIndex==1,'Group did not preserve/select native killing row')
grouped:Fire('OnEnter');check(tooltipSpell==124 and popup.guide:IsShown(),'Selected native tooltip/guide missing')
check(#grouped.amount.text<12 and grouped.amount.width==74,'Large amount not bounded/compacted')
grouped:Fire('OnClick');check(tooltipSpell==123 and grouped.group.rows[grouped.selected].nativeIndex==2,'Cycling kept stale tooltip/selection')
check(popup.axisEnd.points[1][4]==507 and popup.axisEnd.text=='0s native','Axis endpoint uses proportional whitespace')
-- Preview must close live popovers and execution-time callbacks must recheck.
db.personalTools.consumableReminder=false
U:OpenBell();local enable=button('ENABLE');check(enable and enable:IsVisible(),'Live reminder confirmation absent')
local saved={};for key,value in pairs(db.personalTools)do saved[key]=value end
local beforePage=R:GetPage();local diagnostics=R:GetDiagnostics();U:Preview()
check(not enable:IsVisible() and popup.coverage.text:find('Sample preview',1,true),'Preview inherited live confirmation or lacks sample label')
enable:Fire('OnClick')
check(not db.personalTools.consumableReminder and R:GetPage()==beforePage,'Stale live callback in sample changed settings/history')
for key,value in pairs(saved)do check(db.personalTools[key]==value,'Preview changed child preferences')end
check(R:GetDiagnostics().samples==diagnostics.samples and R:GetDiagnostics().nativeReads==diagnostics.nativeReads,'Preview queried recorder/native model')
U:OpenShare();check(not button('OPEN CHAT'),'Sample opened live share')
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
