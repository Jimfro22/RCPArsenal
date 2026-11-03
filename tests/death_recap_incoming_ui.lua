-- Actual renderer and share builder with synthetic, separate native/live data.
local function Read(path)local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local source=Read('tests/hub.lua');source=source:sub(1,assert(source:find('check(db.schemaVersion == 19',1,true))-1)
local ui=Read('tests/death_recap_ui.lua');local marker='source=source..[=[';local start=assert(ui:find(marker,1,true))+#marker
source=source..ui:sub(start,assert(ui:find('local groupCalls=',start,true))-1)
source=source..[=[
local page={id=71,diedAt=100,localSessionStartedAt=80,class='MAGE',specID=62,casts={
 {spellID=235450,name='Barrier',observedAt=89,source='UNIT_SPELLCAST_SUCCEEDED'},
 {spellID=55342,name='Mirror Image',observedAt=96,source='UNIT_SPELLCAST_SUCCEEDED'}},lastAlive={spells={},supplies={}},
 native={recapID=71,recapMaxHealth=100000,rows={{nativeIndex=1,nativeOffset=0,timestamp=1000,kind='damage',spellID=701,name='Named native hit',amount=777,recordedHP=500}}},
 liveIncoming={source='UNIT_COMBAT:player',clock='GetTime',startedAt=80,endedAt=100,combatEntryObserved=true,rows={
 {sequence=1,observedAt=92.1,kind='damage',amount=120,school=4},
 {sequence=2,observedAt=96,kind='healing',amount=300,school=1},
 {sequence=3,observedAt=99.8,kind='damage',amount=100,school=1},
 {sequence=4,observedAt=99.9,kind='damage',amount=90,school=64}},deathBoundary={source='UNIT_COMBAT:player',clock='GetTime',noticeAt=100,deadline=101,active=true,rows={
 {sequence=1,observedAt=100.4,kind='damage',amount=895,school=1},
 {sequence=2,observedAt=100.45,kind='damage',amount=650,school=4}}}}}
R.GetPage=function()return page end
R.GetHistory=function()return{page}end
R.IsRetainedPage=function(self,p)return p==page end
U:ShowLast();local popup=named.RCPArsenalDeathRecap;local chart=popup.incomingChart
check(popup.feedMode=='history'and popup.feedSelector:IsShown()and chart:IsShown()and popup.timeDomain.first==-8,'Live death did not default to the separate full-window view')
check(popup.incomingHistory.damageTotal==310 and popup.incomingHistory.healingTotal==300 and chart.damageTotal.text=='310'and chart.healTotal.text=='300','History totals include native damage or omit healing')
check(not popup.healthPanel:IsShown()and not popup.percent:IsShown()and popup.healthPanel.selectedHP==nil,'Incoming receipts acquired a native health snapshot')
check(popup.castMarkerCount==1 and popup.castMarkers[1].age.text=='4.0s'and popup.usesLabel.text=='Earlier uses','Own cast used native alignment or older casts vanished')
check(chart.lateHelp:IsShown()and chart.lateHelp.label.text=='Collecting late reports','Open delivery window appeared complete')
page.liveIncoming.deathBoundary.active=false;RA:FireCallback('DEATH_RECAP_CHANGED','delivery')
check(chart.lateHelp.label.text=='Late reports · 2'and chart.damageTotal.text=='310','Completed delivery callback did not refresh the late-report link or changed chart totals')
chart.lateHelp:Fire('OnEnter');local oldLate=chart.lateHelp.scripts.OnEnter
check(popup.tooltipRecap:IsShown()and popup.tooltipRecap.eventHeading.text=='Received after death'and popup.tooltipRecap.eventRows[1].entry.timeText=='+0.40s','Late tooltip guessed hit time or omitted arrival label')
chart.lateHelp:Fire('OnMouseWheel',-1)
check(popup.tooltipRecap.eventRows[2].background:IsShown(),'Late report wheel could not focus the next receipt')
chart.lateHelp:Fire('OnLeave')
local grouped
for _,b in ipairs(chart.bars)do if b:IsVisible()and #b.group.rows==2 then grouped=b end end
check(grouped and grouped.wheel,'Multiple receipts have no grouped inspection target')
GameTooltip:Hide();grouped:Fire('OnEnter');local before=chart.selection.member;local stale=grouped.scripts.OnEnter
check(not GameTooltip:IsShown()and chart.guide:IsShown()and popup.tooltipRecap:IsShown(),'Anonymous history opened a guessed spell tooltip or lacks hover focus')
local copy=table.concat(tooltipLines,' ')
check(copy:find('Physical damage',1,true)and copy:find('Arcane damage',1,true)and not copy:find('Named native hit',1,true),'History tooltip borrowed native names')
grouped:Fire('OnMouseWheel',-1);check(chart.selection.member~=before and popup.tooltipRecap.eventRows[chart.selection.member].background:IsShown(),'Wheel cannot inspect/highlight every retained receipt')
local report=assert(R:BuildShareReport(page,false,'history'))
check(report.feedMode=='history'and #report.entries==9 and #report.sections==2,'History report omitted receipts/uses/death or its separate late-delivery section')
check(report.text:find('Healing: 300',1,true)and report.text:find('Damage: 120',1,true)and not report.text:find('777',1,true),'History report excludes healing or double-counts native hits')
check(report.text:find('[+0.40s received]',1,true)and report.text:find('Damage reported: 895',1,true)and report.sections[2].clock=='delivery','Sharing backdated a late report or omitted its distinct receipt clock')
local namedReport=assert(R:BuildShareReport(page,false,'named'))
check(namedReport.text:find('777 damage',1,true)and not namedReport.text:find('Healing: 300',1,true),'Named report silently includes anonymous amounts')
popup.feedSelector.named:Fire('OnClick')
check(popup.feedMode=='named'and not chart:IsShown()and popup.healthPanel:IsShown()and popup.healthPanel.selectedHP==500,'Named view lost original health/details')
oldLate(chart.lateHelp);check(not popup.tooltipRecap:IsShown(),'Stale late-report hover leaked into named view')
local selection=chart.selection;stale(grouped);check(chart.selection==selection and not popup.tooltipRecap:IsShown(),'Stale history hover leaked across view switch')
popup.feedSelector.history:Fire('OnClick');U:OpenShare()
local share=popup.shareChooser
check(share.report.feedMode=='history'and share.payloadText:find('Healing: 300',1,true),'Post to chat ignores selected feed')
share.close:Fire('OnClick');U:Hide()
check(not chart:IsShown()and not popup.feedSelector:IsShown()and not chart.guide:IsShown(),'Closing log left incoming UI visible')
page.liveIncoming=nil;U:ShowLast()
check(popup.feedMode=='named'and not popup.feedSelector:IsShown()and popup.healthPanel:IsShown(),'Older death without incoming receipts lost original view')
io.write('PASS: '..checks..' actual-UI source separation, eight-second view, cast timing, inspection, sharing and lifecycle assertions\n')
]=]
assert(loadstring(source,'incoming-ui-test'))()
