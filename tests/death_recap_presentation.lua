local function Read(path)local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local source=Read('tests/hub.lua');source=source:sub(1,assert(source:find('check(db.schemaVersion == 19',1,true))-1)
local ui=Read('tests/death_recap_ui.lua');local marker='source=source..[=[';local start=assert(ui:find(marker,1,true))+#marker
source=source..ui:sub(start,assert(ui:find('local groupCalls=',start,true))-1)
source=source..[=[
function methods:SetMinMaxValues(low,high)self.minimum,self.maximum=low,high end
function methods:SetTextColor(...)self.textColor={...}end
local page={id=501,diedAt=100,casts={{spellID=235450,name='Barrier',observedAt=99}},lastAlive={spells={},supplies={}},native={recapID=50,recapMaxHealth=100000,rows={}}}
R.GetPage=function()return page end
for _,id in ipairs({1285017,1306906,1283290,235450})do spellIcons[id]=id+100000 end
U:Preview()
local values={{-1,14000},{-.7,10000},{-.4,nil},{-.2,1000},{0,0}}
for i,v in ipairs(values)do page.native.rows[i]={nativeIndex=i==5 and 1 or i+1,nativeOffset=v[1],kind='damage',amount=i,name='Hit '..i,recordedHP=v[2]}end
U:ShowLast();local popup=named.RCPArsenalDeathRecap
RA:RefreshVisualAssets()
for _,b in ipairs(objects)do if b.parent==popup and b.group and b:IsVisible()and not b.group.mixed then check(b.icon.texture==134400,'Recycled nil-spell hit retained Preview artwork')end end
check(popup.usesLabel:IsShown()and popup.usesLabel.text=='Used before death','Live Barrier receipt has no visible provenance label')
local selected=popup.selected
for _,b in ipairs(objects)do if b.parent==popup and b.useGroup and b:IsVisible()then
 tooltipLines={};b:Fire('OnEnter');local copy=table.concat(tooltipLines,' ')
 check(copy:find('Used once',1,true)and copy:find('1.0s before the death notice',1,true)and not copy:find('duration',1,true),'Recorded use acquired inferred native timing/duration')
 check(popup.selected==selected,'Use hover changed selected health')
 check(b.useLabel.text=='Barrier'and b.useMeta.text=='1.0s'and b.height==30 and b.icon.width==26,'Use chip lost its visible name/latest age or changed its original icon/row height')
end end
local function NoHealthPlot()
 for _,key in ipairs({'healthPoint','pointPercent','healthGraphScale','graphBase','graphHelp','graphLabel','graphContext','graphScaleTicks','absorb','absorbLabel','hatches'})do
  check(popup[key]==nil,'Removed health plot/debt field remains: '..key)
 end
 check(popup.healthPanel.width==popup.rail.width and popup.healthPanel.points[1][4]==popup.rail.points[1][4], 'Selected health bar is not aligned with the native timeline')
 check(popup.healthPanel.points[1][5]<popup.rail.points[1][5] and popup.percent.points[1][5]>popup.healthPanel.points[1][5]and popup.hp.points[1][5]>popup.healthPanel.points[1][5],'Selected health bar or its metadata left the bottom composition')
end
local function SelectNative(index)
 for _,button in ipairs(objects)do if button.parent==popup and button.group and button:IsVisible()then
  for member,row in ipairs(button.group.rows)do if row.nativeIndex==index then button.member=member;button:Fire('OnEnter');return button,row end end
 end end
 error('No visible native row '..index)
end
NoHealthPlot()
for i,v in ipairs(values)do
 local index=i==5 and 1 or i+1;SelectNative(index)
 check(popup.healthPanel.selectedHP==v[2], 'Selected member substituted another retained HP sample')
 check(popup.healthBar:IsShown()==(v[2]~=nil),'Missing selected health was synthesized or public zero erased')
 check(not popup.healing:IsShown()and popup.healthPanel.effectiveHealing==nil,'Native health acquired a healing contribution')
end
page.native.rows[5].recordedHP=nil;U:ShowLast();check(popup.healthPanel.selectedHP==nil and not popup.healthBar:IsShown()and popup.percent.text=='—','Unknown fatal HP gained zero health')
page.native.rows={}
for i=1,64 do page.native.rows[i]={nativeIndex=i,nativeOffset=0,kind='damage',amount=i,absorbed=100,recordedHP=1000,name='Hit '..i}end
U:ShowLast();local cluster
for _,b in ipairs(popup.supportMarkers)do if b:IsShown()and #b.entry.rows>15 then cluster=b;break end end
check(cluster and cluster:GetScript('OnMouseWheel'),'Dense absorption has no detail navigation')
selected=popup.selected;cluster:Fire('OnEnter')
for i=1,#cluster.entry.rows do cluster:Fire('OnMouseWheel',-1)end
local card=popup.tooltipRecap;local lastLine=card.lines[#cluster.entry.rows+4]
check(card.scroll:GetVerticalScroll()>0 and lastLine.recapY+lastLine.height-card.scroll:GetVerticalScroll()<=card.height,'Last absorbed member cannot be inspected')
check(popup.selected==selected,'Absorb detail wheel moved selected hit/health')
check(card.lines[4].text=='Scroll to inspect hits','Overflowing absorbed members lack their navigation hint')
-- Three tied raw hits fit without wheel instructions or repeated timing prose.
local denseNative=page.native
page.native={recapID=50,recapMaxHealth=100000,rows={}}
for i=1,3 do page.native.rows[i]={nativeIndex=i,nativeOffset=-.3,kind='damage',amount=100,absorbed=1667,recordedHP=1000*i,spellID=i==2 and 1306906 or 1285017,name=i==2 and 'Other incoming ability' or 'Saber Slash'}end
U:ShowLast();local trio=popup.supportMarkers[1];selected=popup.selected;trio:Fire('OnEnter');card=popup.tooltipRecap
check(card.lines[1].text=='5,001 absorbed · 3 hits'and not card.overflowing,'Three tied absorb receipts lost their total or unnecessarily overflowed')
check(card.lines[2].text=='Shield not identified'and card.lines[2].textColor[1]==RA.Theme.Colors.muted[1],'Unknown shield identity lost its muted treatment')
check(card.lines[3].text=='Times relative to final recorded hit','Absorb rows lack their one shared timing caption')
for i=1,3 do local line=card.lines[i+3]
 check(line.text==(i==2 and 'Other incoming ability' or 'Saber Slash')and line.iconSpellID==(i==2 and 1306906 or 1285017),'Absorb coalescing replaced a mixed incoming identity')
 check(line.textColor[1]==RA.Theme.Colors.text[1]and line.recapAmount.text=='1,667'and line.recapAmount.textColor[1]==.36 and line.recapAmount.textColor[2]==.70,'Absorb identity and amount lost their separate white/blue colors')
 check(line.recapTime.text=='-0.3s'and line.recapTime.textColor[1]==RA.Theme.Colors.muted[1]and line.width>0,'Short absorb time is missing, mislabeled or overlapping the identity region')
end
for _,line in ipairs(card.lines)do if line:IsShown()then check(not line.text:find('Scroll',1,true)and not line.text:find('Incoming:',1,true),'Three fitting members retained redundant instructions')end end
check(popup.selected==selected,'Compact absorb tooltip changed selected health')
page.native.rows[1].absorbed=1e15;U:ShowLast();popup.supportMarkers[1]:Fire('OnEnter');card=popup.tooltipRecap
local largeAmount=card.lines[4]
check(largeAmount.recapAmount.text=='1,000,000,000,000,000'and largeAmount.recapAmount.width>=largeAmount.recapAmount:GetUnboundedStringWidth()and largeAmount.width>0,'Maximum public exact absorb amount clipped or consumed the incoming identity region')
page.native=denseNative
page.lastAlive.spells={{spellID=235450,cooldown='active',observedAt=50,cooldownAt=50,chargesAt=99,chargeQuery='public',currentCharges=1,maxCharges=2}}
page.lastAlive.supplies={}
for i=1,32 do page.lastAlive.supplies[i]={kind='potion',itemID=100+i,physicalCount=1,remainingUses=i,cooldown='inactive',observedAt=99,carriedAt=50}end
U:ShowLast();check(not popup.shelfAge:IsShown()and popup.shelfAge.text=='','Shelf retained visible check-age text')
local shelves={};for _,b in ipairs(objects)do if b.parent==popup and b.icon and b.width==32 and b:IsVisible()then shelves[#shelves+1]=b end end
check(#shelves==3,'Item candidates expanded into multiple family shelf icons')
local chargeAgeFound=false
for _,b in ipairs(shelves)do
 check(b.info.text==(b.recordedState==true and'✓'or b.recordedState==false and'×'or'?'),'Shelf glyph disagrees with recorded availability')
 tooltipSpell=nil;tooltipLines={};b:Fire('OnEnter')
 if tooltipSpell==235450 then
  chargeAgeFound=true;local copy=table.concat(tooltipLines,' ')
  check(copy:find('Checked 1.0s',1,true)and not copy:find('Checked 50.0s',1,true),'Hidden shelf age was lost from hover or charge verdict borrowed old cooldown time')
 end
end
check(chargeAgeFound,'Recorded spell check was omitted from shelf hover')
local family
for _,b in ipairs(shelves)do if b.wheel then family=b end end
check(family,'Multi-item family cannot be inspected');family:Fire('OnEnter')
for i=1,32 do family:Fire('OnMouseWheel',-1)end
card=popup.tooltipRecap;local found
for _,line in ipairs(card.lines)do if line:IsShown()and line.text:find('Item 132:',1,true)then found=line end end
check(found and found.recapY+found.height-card.scroll:GetVerticalScroll()<=card.height,'Last family candidate was truncated/unreachable')
local populated=page.native;page.encounter={startedAt=10};page.native=nil;page.nativeAttempts=1
local function CheckEmptyAxis(label)
 U:Render()
 check(popup.selected==nil and popup.selectedItem==nil and popup.healthPanel.selectedHP==nil and not popup.guide:IsShown()and not popup.healthBar:IsShown()and not popup.healing:IsShown(),label..' redraw retained stale selected event geometry')
 check(not popup.rail:IsShown()and not popup.fight:IsShown()and not popup.death:IsShown()and popup.deathX==nil,label..' retained a native time axis')
 for i=1,6 do check(not popup.ticks[i]:IsShown()and not popup.tickMarks[i]:IsShown()and popup.tickLabels[i]=='',label..' retained a fabricated tick')end
 check(popup.empty:IsShown()and popup.usesLabel:IsShown(),label..' hid the empty status or independent recorded uses')
 local shelfCount,useCount=0,0
 for _,b in ipairs(objects)do if b.parent==popup and b.icon and b:IsVisible()then
  if b.width==32 then shelfCount=shelfCount+1 elseif b.useGroup or b.useOverflow then useCount=useCount+1 end
 end end
 check(shelfCount==3 and useCount==1,label..' hid independent supply/spell evidence or use receipts')
 U:ShowLast();check(not popup.rail:IsShown()and not popup.guide:IsShown(),label..' manual reopen restored fabricated geometry')
end
CheckEmptyAxis('Loading native recap')
page.nativeAttempts=R.LIMITS.attempts;CheckEmptyAxis('Unavailable native recap')
page.native={recapID=50,recapMaxHealth=100000,rows={}};CheckEmptyAxis('Empty native packet')
page.native=populated;RA:FireCallback('DEATH_RECAP_CHANGED','native')
check(popup.rail:IsShown()and popup.fight:IsShown()and popup.death:IsShown()and not popup.empty:IsShown(),'Filled native page did not restore its axis')
for i=1,6 do check(popup.ticks[i]:IsShown()and popup.tickMarks[i]:IsShown(),'Filled native page retained hidden tick objects')end
-- The selected original row alone determines health. The native recap maximum
-- remains its denominator; invalid values stay unknown and absorption adds no HP.
local function NativeHP(values,maximum)
 page.native={recapID=50,recapMaxHealth=maximum,rows={}}
 for i,hp in ipairs(values)do page.native.rows[i]={nativeIndex=i==#values and 1 or i+1,nativeOffset=(i-#values)*.1,kind='damage',amount=1,recordedHP=hp}end
 U:ShowLast()
end
for _,value in ipairs({0,5000,26000,99000,100000})do
 NativeHP({value,1000},100000);SelectNative(2)
 check(popup.healthPanel.selectedHP==value and popup.hp.text==value..' / 100000'and popup.percent.text==string.format('%.0f%%',value/100000*100),'Selected raw health/value percentage was rescaled or replaced')
 check(popup.healthBar.minimum==0 and popup.healthBar.maximum==100000,'Selected health denominator changed with visible samples')
 check(not popup.healing:IsShown()and popup.healthPanel.effectiveHealing==nil,'Native selected health gained an inferred heal')
 NoHealthPlot()
end
local hidden=setmetatable({},{__tostring=function()error('Secret health stringified')end})
local publicCheck=issecretvalue;issecretvalue=function(v)return rawequal(v,hidden)or publicCheck(v)end
for _,bad in ipairs({hidden,false,-1,0/0,math.huge,'5000',{}})do
 NativeHP({bad,1000},100000);SelectNative(2)
 check(popup.healthPanel.selectedHP==nil and not popup.healthBar:IsShown()and popup.percent.text=='—'and popup.hp.text=='Health not recorded','Invalid selected health became zero, a bar or a percentage')
end
NativeHP({100001,1000},100000);SelectNative(2)
check(popup.healthPanel.selectedHP==100001 and popup.hp.text=='100001 / 100000'and not popup.healthBar:IsShown()and popup.percent.text=='—','Out-of-scale raw HP was clamped or used as valid percentage')
for _,maximum in ipairs({hidden,false,0,-1,0/0,math.huge,'100000',{}})do
 NativeHP({26000,1000},maximum);SelectNative(2)
 check(popup.healthPanel.selectedHP==26000 and popup.hp.text=='26000'and popup.healthPanel.selectedMax==nil and not popup.healthBar:IsShown()and popup.percent.text=='—','Unavailable maximum erased public raw HP or fabricated a health denominator')
end
NativeHP({26000,1000},100000)
page.native.rows[1].absorbed=100000;page.native.rows[1].effectiveHealing=25000;page.native.rows[1].exampleHP=99999
page.heals={{offset=-.1,amount=25000,effectiveHealing=25000,exampleHP=99999}};page.sample=true;page.origin='example'
U:ShowLast();SelectNative(2)
check(popup.healthPanel.selectedHP==26000 and not popup.healing:IsShown()and popup.healthPanel.effectiveHealing==nil,'Live forged sample/absorption fields contributed to health')
for _,target in ipairs(popup.healTargets)do check(not target:IsVisible(),'Live forged sample created a selectable healing event')end
page.heals=nil;page.sample=nil;page.origin=nil
issecretvalue=publicCheck

-- Names, counts and latest ages fit the original row; any remaining verified
-- identities enter one overflow chip. Every retained receipt stays reachable.
local function UseChips()
 local chips,overflow={},nil
 for _,button in ipairs(objects)do if button.parent==popup and(button.useGroup or button.useOverflow)and button:IsVisible()then
  chips[#chips+1]=button;if button.useOverflow then overflow=button end
 end end
 table.sort(chips,function(a,b)return a.points[1][4]<b.points[1][4]end)
 return chips,overflow
end
NativeHP({26000,1000},100000)
for _,count in ipairs({8,9,64,8})do
 page.casts={};for i=1,count do page.casts[i]={spellID=600+i,name='Retained ability '..i,observedAt=75+i*.3}end
 U:ShowLast();local chips,overflow=UseChips();local seen={};local receipts=0
 check(#chips<=8,'Use overflow expanded the single row')
 check(chips[1].useGroup.spellID==600+count,'Newest use group did not lead the row')
 for _,button in ipairs(chips)do
  check(button.height==30 and button.points[1][5]==-76 and button.points[1][4]>=48 and button.points[1][4]+button.width<=536,'Named use chips escaped their bounded row beside the CD shelf')
  if button.useGroup then for _,receipt in ipairs(button.useGroup.rows)do check(not seen[receipt],'Use receipt appears in multiple chips');seen[receipt]=true;receipts=receipts+1 end end
 end
 if overflow then
  check(overflow.overflowLabel.text=='+'..(count-#chips+1)and not overflow.icon:IsShown()and overflow.wheel,'Overflow lacks its count, hides no old artwork, or cannot scroll')
  for _,detail in ipairs(overflow.useOverflow.rows)do check(not seen[detail.receipt],'Use receipt duplicated in overflow');seen[detail.receipt]=true;receipts=receipts+1 end
  selected=popup.selected;overflow:Fire('OnEnter')
  for i=1,#overflow.useOverflow.rows do overflow:Fire('OnMouseWheel',-1)end
  local card=popup.tooltipRecap;local last=card.lines[3+#overflow.useOverflow.rows]
  check(last and last:IsShown()and last.text:find('Retained ability 1',1,true)and last.recapY+last.height-card.scroll:GetVerticalScroll()<=card.height,'Oldest overflow receipt cannot be inspected')
  check(popup.selected==selected and not GameTooltip:IsShown(),'Overflow hover changed HP or claimed one native spell identity')
 else check(chips[#chips].icon:IsShown()and(not chips[#chips].overflowLabel or not chips[#chips].overflowLabel:IsShown())and not chips[#chips].wheel,'Fitting groups retained overflow artwork/navigation')end
 check(receipts==count,'Overflow dropped a retained use receipt')
end
page.casts={{spellID=701,name='Repeated oldest',observedAt=70},{spellID=701,name='Repeated oldest',observedAt=71},{spellID=701,name='Repeated oldest',observedAt=72}}
for i=2,9 do page.casts[#page.casts+1]={spellID=700+i,name='Other '..i,observedAt=75+i}end
U:ShowLast();local chips,overflow=UseChips();overflow:Fire('OnEnter')
local copy=table.concat(tooltipLines,' ')
check(#overflow.useOverflow.rows>=4 and copy:find('Use 1/3',1,true)and copy:find('Use 2/3',1,true)and copy:find('Use 3/3',1,true),'Overflow collapsed repeated members into an aggregate timestamp')
page.casts={{spellID=701,name='Single',observedAt=99}};U:ShowLast();chips,overflow=UseChips()
check(#chips==1 and not overflow and chips[1].icon:IsShown()and not chips[1].wheel,'Pooled overflow state survived a sparse page')
page.casts={};for i=1,8 do page.casts[i]={spellID=700+i,name='A',observedAt=99}end
U:ShowLast();chips,overflow=UseChips()
check(#chips==5 and overflow and overflow.useOverflow.groupCount==4,'Compact receipt row did not reserve bounded space for overflow')
local compactReceipts=0;for _,chip in ipairs(chips)do if chip.useGroup then compactReceipts=compactReceipts+#chip.useGroup.rows end end
check(compactReceipts+#overflow.useOverflow.rows==8,'Compact receipt overflow omitted an original use')
page.casts={{spellID=701,name=string.rep('Long ability ',12),observedAt=98},{spellID=701,name=string.rep('Long ability ',12),observedAt=99}}
U:ShowLast();chips,overflow=UseChips();local long=chips[1]
check(#chips==1 and long.width<=230 and long.useLabel.width>0 and long.useLabel.maxLines==1 and long.useMeta.text=='×2 · 1.0s'and long.useMeta.width>=long.useMeta:GetUnboundedStringWidth(),'Long name clipped the independent count/latest age or expanded the bounded row')
-- Only validated native/local anchors admit approximate successful-cast
-- markers. Their positions do not turn a receipt into healing or readiness.
do
 local originalPage=page
 page={id=502,diedAt=100,localSessionStartedAt=60,lastAlive={spells={{spellID=235450,name='Barrier',observedAt=99,cooldown='held'}},supplies={}},casts={
  {spellID=235450,name='Old retained Barrier',observedAt=91,source='UNIT_SPELLCAST_SUCCEEDED'},
  {spellID=235450,name='First recent Barrier',observedAt=98.5,source='UNIT_SPELLCAST_SUCCEEDED'},
  {spellID=235450,name='Repeated recent Barrier',observedAt=98.5,source='UNIT_SPELLCAST_SUCCEEDED'},
  {spellID=55342,name='Derived Mirror',observedAt=99,source='DERIVED_FROM_AGGREGATE_ENDPOINT'}},native={recapID=51,recapMaxHealth=100000,rows={
  {nativeIndex=3,nativeOffset=-2,timestamp=1998,kind='damage',amount=100,recordedHP=26000},
  {nativeIndex=1,nativeOffset=-.25,timestamp=1999.75,kind='damage',amount=1000,recordedHP=1000},
  {nativeIndex=2,nativeOffset=0,timestamp=2000,kind='unknown',recordedHP=1000}},clockDiagnostic={localClock='GetTime',localDeathNoticeAt=100,localSessionStartedAt=60,nativeFatalTimestamp=1999.75,nativeMaximumTimestamp=2000,nativeRowCount=3}}}
 local function NoCastMarkers(message)
  check(popup.castMarkerCount==0 and popup.castExtra==0,message..' retained a cast lane')
  for _,marker in ipairs(popup.castMarkers)do
   check(not marker:IsShown(),message..' retained a cast marker')
   for _,lines in ipairs({marker.stems,marker.connectors})do for _,line in ipairs(lines)do check(not line:IsShown(),message..' retained a cast connector')end end
  end
 end
 U:ShowLast();local firstMarker=popup.castMarkers[1]
 check(popup.castAlignment.anchorValid and #popup.castAlignment.aligned==3 and #popup.castAlignment.unaligned==1 and popup.castMarkerCount==2,'Cast alignment lost repeated successes, included derived receipt or clamped an older cast into view')
 check(popup.castExtra==48 and #page.casts==4 and popup.timeDomain.first==-5,'Approximate markers changed the native time window or retained receipt list')
 check(#popup.castFallback==2 and popup.castFallback[1]==page.casts[1]and popup.castFallback[2]==page.casts[4],'Fallback did not retain only the offscreen and unaligned receipts')
 local fallbackSeen={};local fallbackCount=0
 for _,chip in ipairs(UseChips())do
  local receipts=chip.useGroup and chip.useGroup.rows or{}
  for _,row in ipairs(receipts)do fallbackSeen[row]=true;fallbackCount=fallbackCount+1 end
  for _,detail in ipairs(chip.useOverflow and chip.useOverflow.rows or{})do fallbackSeen[detail.receipt]=true;fallbackCount=fallbackCount+1 end
 end
 check(fallbackCount==2 and fallbackSeen[page.casts[1]]and fallbackSeen[page.casts[4]]and not fallbackSeen[page.casts[2]]and not fallbackSeen[page.casts[3]],'Fallback chips duplicated plotted receipts or omitted unplotted receipts')
 local beforeHP,beforeSelected=popup.healthPanel.selectedHP,popup.selected;local shelfStates={}
 for _,button in ipairs(objects)do if button.parent==popup and button.recordedState~=nil and button:IsVisible()then shelfStates[button]=button.recordedState end end
 local seenReceipt={}
 for i=1,popup.castMarkerCount do local marker=popup.castMarkers[i]
  seenReceipt[marker.entry.index]=true
  check(marker.entry.row==page.casts[marker.entry.index]and marker.entry.offset==-1.75 and marker.entry.age==1.5 and marker.age.text=='~1.5s','Approximate marker lost exact receipt or death-notice-relative age')
  check(marker.timeX==48+3.25/5*784 and marker.iconX>=48 and marker.iconX<=832 and marker:IsShown(),'Packed cast marker retimed its connector or escaped the native axis')
  tooltipLines={};tooltipSpell=nil;marker:Fire('OnEnter');local copy=table.concat(tooltipLines,' ')
  check(tooltipSpell==235450 and copy:find('~1.5s before death; aligned to death notification.',1,true)and copy:find('Recorded successful cast · Timing is approximate',1,true),'Approximate cast tooltip lost its explicit alignment disclosure')
  check(popup.selected==beforeSelected and popup.healthPanel.selectedHP==beforeHP and not popup.healing:IsShown(),'Cast marker changed raw selected HP or synthesized healing')
  for button,state in pairs(shelfStates)do check(button.recordedState==state,'Cast marker inferred a cooldown availability change')end
  marker:Fire('OnLeave')
 end
 check(seenReceipt[2]and seenReceipt[3]and not seenReceipt[1]and not seenReceipt[4],'Cast markers deduplicated repeats or exposed an unaligned receipt')
 check(firstMarker.iconX~=popup.castMarkers[2].iconX and firstMarker.timeX==popup.castMarkers[2].timeX,'Equal-time cast packing moved their actual-time connector positions')
 local report=assert(R:BuildShareText(page));check(report:find('Old retained Barrier',1,true)and report:find('Derived Mirror',1,true),'Cast viewport filtering cropped the full original-use report')
 local stale=firstMarker:GetScript('OnEnter');U:Render();stale(firstMarker);check(not popup.tooltipRecap:IsShown(),'Old cast-marker callback survived redraw')
 U:OpenShare();firstMarker:Fire('OnEnter');check(not popup.tooltipRecap:IsShown()and popup.selected==beforeSelected,'Cast-marker hover bypassed the report modal');popup.shareChooser.close:Fire('OnClick')
 for i=1,13 do page.casts[i]={spellID=235450,name='Repeated Barrier',observedAt=99,source='UNIT_SPELLCAST_SUCCEEDED'}end
 U:ShowLast();check(popup.castMarkerCount==13 and popup.castExtra==96,'Dense cast receipts were dropped or failed to reserve another marker lane')
 check(#popup.castFallback==0 and #popup.recordedUseGroups==0 and #UseChips()==0 and not popup.usesLabel:IsShown(),'Fully plotted receipts retained duplicate fallback chips or caption')
 local counts={};for i=1,popup.castMarkerCount do local marker=popup.castMarkers[i];counts[marker.lane]=(counts[marker.lane]or 0)+1;check(marker.timeX==48+3.75/5*784,'Dense packing changed cast time')end
 check(counts[1]<=12 and counts[2]<=12,'Cast marker lane exceeded its packing capacity')
 page.native.clockDiagnostic.localDeathNoticeAt=99;U:ShowLast();NoCastMarkers('Stale clock anchor')
 check(#page.casts==13 and #popup.recordedUseGroups[1].rows==13,'Unaligned marker cleanup discarded factual use receipts')
 check(#popup.castFallback==13 and popup.usesLabel:IsShown(),'Stale anchor did not restore all retained receipts to fallback')
 for i,row in ipairs(popup.castFallback)do check(row==page.casts[i],'Stale-anchor fallback substituted or reordered an original receipt')end
 page.native.clockDiagnostic.localDeathNoticeAt=100;page.native.clockDiagnostic.nativeFatalTimestamp=hidden
 issecretvalue=function(v)return rawequal(v,hidden)or publicCheck(v)end
 U:ShowLast();NoCastMarkers('Secret clock anchor');issecretvalue=publicCheck
 page.native.clockDiagnostic.nativeFatalTimestamp=1999.75;U:ShowLast();check(popup.castMarkerCount==13,'Valid cast anchors did not restore markers')
 local hiddenCallback=popup.castMarkers[1]:GetScript('OnEnter');U:Hide();hiddenCallback(popup.castMarkers[1]);check(not popup.tooltipRecap:IsShown(),'Hidden cast marker callback reopened details')
 U:Preview();NoCastMarkers('Preview mode');check(popup.castAlignment==nil,'Preview borrowed live clock alignment')
 page=originalPage;U:ShowLast()
end
-- Eligible projected cast offsets extend the native viewport before filtering
-- damage. Rendering reuses one alignment result and never substitutes age.
do
 local originalPage=page;local M=RA.DeathLogModel
 local align,viewport=M.AlignUses,M.Viewport;local calls,latestAlignment,viewportAlignment=0,nil,nil
 M.AlignUses=function(self,input)calls=calls+1;latestAlignment=align(self,input);return latestAlignment end
 M.Viewport=function(self,rows,maximum,alignment)viewportAlignment=alignment;return viewport(self,rows,maximum,alignment)end
 local rows={
  {nativeIndex=5,nativeOffset=-8.3,timestamp=1991.7,kind='damage',name='Old report tail',amount=90000,recordedHP=90000},
  {nativeIndex=4,nativeOffset=-6.8,timestamp=1993.2,kind='damage',name='Newly visible small hit',amount=1000,recordedHP=89000},
  {nativeIndex=3,nativeOffset=-2,timestamp=1998,kind='damage',name='Recent major hit',amount=50000,recordedHP=39000},
  {nativeIndex=1,nativeOffset=0,timestamp=2000,kind='damage',name='Exact fatal receipt',amount=1000,recordedHP=1000},
  {nativeIndex=2,nativeOffset=0,timestamp=2000,kind='unknown',name='Final unknown receipt'}}
 page={id=503,diedAt=100,localSessionStartedAt=60,lastAlive={spells={},supplies={}},casts={
  {spellID=235450,name='Barrier',observedAt=94.4,source='UNIT_SPELLCAST_SUCCEEDED'},
  {spellID=414658,name='Ice Cold',observedAt=93.5,source='UNIT_SPELLCAST_SUCCEEDED'},
  {spellID=55342,name='Mirror Image',observedAt=95.4,source='UNIT_SPELLCAST_SUCCEEDED'}},native={recapID=52,recapMaxHealth=100000,rows=rows,
  clockDiagnostic={localClock='GetTime',localDeathNoticeAt=100,localSessionStartedAt=60,nativeFatalTimestamp=2000,nativeMaximumTimestamp=2000,nativeRowCount=5}}}
 local function RenderSpan(span)
  local before=calls;U:ShowLast()
  check(calls==before+1 and viewportAlignment==latestAlignment and popup.castAlignment==latestAlignment,'Render recomputed alignment or passed different projections to viewport and markers')
  check(popup.timeDomain.first==-span and popup.timeDomain.last==0,'Projected-use viewport has the wrong whole-second span')
 end
 local function Marker(index)for i=1,popup.castMarkerCount do local marker=popup.castMarkers[i];if marker.entry.index==index then return marker end end end
 local function Near(a,b)return type(a)=='number'and math.abs(a-b)<.00001 end
 local report=assert(R:BuildShareText(page));RenderSpan(7)
 check(popup.castMarkerCount==3 and #popup.castFallback==0 and not popup.usesLabel:IsShown(),'The 5.6/6.5/4.6-second cast case omitted markers or retained duplicate fallback chips')
 for i,offset in ipairs({-5.6,-6.5,-4.6})do local marker=Marker(i)
  check(marker and Near(marker.entry.offset,offset)and Near(marker.timeX,48+(offset+7)/7*784),'Cast-driven expansion changed the validated projected position')
 end
 local admitted=false;for _,row in ipairs(popup.viewport.rows)do if row==rows[2]then admitted=true end end
 check(admitted and popup.viewport.omitted==1 and popup.selected==rows[4]and popup.hp.text=='1000 / 100000','Expanded cast window lost newly admitted native damage or changed fatal HP')
 check(page.native.rows==rows and #rows==5 and R:BuildShareText(page)==report,'Cast-driven viewport changed original history or full report')
 local selectedRow=popup.selected;Marker(2):Fire('OnEnter');check(popup.selected==selectedRow and popup.hp.text=='1000 / 100000','Newly visible cast hover selected another health sample')
 rows[4].timestamp,rows[4].nativeOffset=1999.4,-.6;page.native.clockDiagnostic.nativeFatalTimestamp=1999.4;RenderSpan(8)
 check(Near(Marker(2).entry.offset,-7.1)and Marker(2).age.text=='~6.5s','Shifted fatal/native maximum was replaced with the local age label')
 rows[4].timestamp,rows[4].nativeOffset=2000,0;page.native.clockDiagnostic.nativeFatalTimestamp=2000
 page.casts[1].observedAt=92;RenderSpan(8)
 check(Marker(1)and Marker(1).entry.offset==-8 and Marker(1).timeX==48,'Exactly eight-second projected use was clipped or moved inward')
 page.casts[1].observedAt=91.999;RenderSpan(7)
 check(not Marker(1)and popup.castMarkerCount==2 and #popup.castFallback==1 and popup.castFallback[1]==page.casts[1],'Older-than-eight use stretched/clamped the view or disappeared from fallback')
 page.native.clockDiagnostic.localDeathNoticeAt=99;RenderSpan(5)
 check(popup.castMarkerCount==0 and #popup.castFallback==3,'Stale alignment extended the viewport or discarded factual receipts')
 page.native.clockDiagnostic.localDeathNoticeAt=100;local clock=page.native.clockDiagnostic;page.native.clockDiagnostic=nil;RenderSpan(5)
 check(popup.castMarkerCount==0 and #popup.castFallback==3,'Missing alignment anchor extended the viewport')
 page.native.clockDiagnostic=clock;page.casts[2].source='DERIVED_FROM_AGGREGATE_ENDPOINT';RenderSpan(5)
 check(popup.castMarkerCount==1 and Marker(3)and #popup.castFallback==2,'Unverified receipt widened the viewport or a valid recent marker disappeared')
 rows[2].nativeOffset,rows[2].timestamp,rows[2].amount=-7.7,1992.3,25000;RenderSpan(8)
 check(popup.viewport.omitted==1 and popup.selected==rows[4],'Existing damage-driven eight-second rule regressed after cast expansion')
 M.AlignUses,M.Viewport=align,viewport;page=originalPage;U:ShowLast()
end
page.native=nil;U:Render()
U:Preview();NoHealthPlot()
check(popup.rail:IsShown()and popup.death:IsShown(),'Preview did not restore its example timeline')
local healTarget=popup.healTargets[1];local healRow=healTarget.entry.row
local previewHP,previewHeal=healRow.exampleHP,healRow.effectiveHealing
healTarget:Fire('OnEnter')
local function Near(a,b)return type(a)=='number'and math.abs(a-b)<.00001 end
check(popup.selected==healRow and popup.healthPanel.selectedHP==336000 and popup.hp.text=='336000 / 400000'and popup.percent.text=='84%','Preview heal did not select its explicit post-heal HP')
check(popup.healthPanel.effectiveHealing==9000 and popup.healing:IsShown()and Near(popup.healing.width,9000/400000*popup.healthPanel.width)and Near(popup.healing.points[1][4],(336000-9000)/400000*popup.healthPanel.width),'Preview effective-heal segment does not occupy the recorded post-heal portion')
tooltipLines={};popup.healthPanel:Fire('OnEnter');local previewHelp=table.concat(tooltipLines,' ')
check(previewHelp:find('9k effective healing',1,true)and previewHelp:find('Fictional sample',1,true),'Synthetic healing contribution lost its provenance')
issecretvalue=function(v)return rawequal(v,hidden)or publicCheck(v)end
for _,bad in ipairs({hidden,false,-1,0,0/0,math.huge,'9000',{},336001})do
 healRow.effectiveHealing=bad;U:Render();popup.healTargets[1]:Fire('OnEnter')
 check(popup.healthPanel.selectedHP==336000 and popup.healthPanel.effectiveHealing==nil and not popup.healing:IsShown(),'Invalid/excess synthetic heal created a green contribution')
end
healRow.effectiveHealing=previewHeal
for _,bad in ipairs({hidden,false,-1,0/0,math.huge,'336000',{},400001})do
 healRow.exampleHP=bad;U:Render();popup.healTargets[1]:Fire('OnEnter')
 check(popup.healthPanel.effectiveHealing==nil and not popup.healing:IsShown(),'Unknown/out-of-range synthetic post-heal HP created a green contribution')
end
issecretvalue=publicCheck;healRow.exampleHP=previewHP;healRow.effectiveHealing=previewHeal;U:Render();SelectNative(1)
check(popup.healthPanel.selectedHP==0 and not popup.healing:IsShown()and popup.healthPanel.effectiveHealing==nil,'Leaving Preview healing retained its green contribution')
local absorbed
for _,target in ipairs(popup.supportMarkers)do if target:IsShown()and target.entry.kind=='absorbed'then absorbed=target;break end end
check(absorbed~=nil,'Preview protective absorption disappeared')
selected=popup.selected;absorbed:Fire('OnEnter')
check(popup.selected==selected and popup.healthPanel.selectedHP==0 and not popup.healing:IsShown(),'Protective absorption changed selected HP or became effective healing')
popup.healTargets[1]:Fire('OnEnter')
for _,button in ipairs(objects)do if button.parent==popup and button.icon and button.width==30 and button:IsVisible()then
 check(not button.useLabel or not button.useLabel:IsShown()and not button.useMeta:IsShown(),'Live use chip labels leaked into Preview')
end end
for _,line in ipairs(popup.tooltipRecap.lines)do check(not line.recapAmount or not line.recapAmount:IsShown()and not line.recapTime:IsShown(),'Absorb amount/time columns leaked into an ordinary Preview tooltip')end
io.write('PASS: '..checks..' actual-UI pooled artwork, selected health, synthetic healing, receipt provenance, tooltip reachability and hidden check-age assertions\n')
]=]
assert(loadstring(source,'death-recap-presentation-fixture'))()
