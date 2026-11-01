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
local function X(t)return 48+(t-popup.timeDomain.first)/(popup.timeDomain.last-popup.timeDomain.first)*784 end
local dots,joins=0,0
for _,o in ipairs(objects)do if o.parent==popup and o:IsVisible()and o.color then
 if o.kind=='Texture'and o.width==6 and o.height==2 and o.drawLayer=='OVERLAY'and o.color[4]==.95 then dots=dots+1 end
 if o.kind=='Line'and o.color[4]==.5 then
  joins=joins+1;local first,last=o.start[3],o.finish[3]
  check((first>=X(-1)-.001 and last<=X(-.7)+.001)or(first>=X(-.2)-.001 and last<=X(0)+.001),'Health join crossed explicit missing sample')
  check(o.thickness==1,'Health join lost one-physical-pixel thickness')
 end
end end
check(dots==4 and joins>0,'Live health dots/dashed sample joins absent or missing health synthesized')
page.native.rows[5].recordedHP=nil;U:ShowLast();check(popup.healthPanel.selectedHP==nil and not popup.healthPoint:IsShown(),'Unknown fatal HP gained zero endpoint')
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
U:ShowLast();check(popup.shelfAge.text=='Last check · 1.0s pre-death','Charge verdict age used old cooldown time')
local shelves={};for _,b in ipairs(objects)do if b.parent==popup and b.icon and b.width==32 and b:IsVisible()then shelves[#shelves+1]=b end end
check(#shelves==3,'Item candidates expanded into multiple family shelf icons')
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
 check(popup.selected==nil and popup.selectedItem==nil and popup.healthPanel.selectedHP==nil and not popup.guide:IsShown()and not popup.healthPoint:IsShown(),label..' redraw retained stale selected event geometry')
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
-- The frozen page determines a zero-based scale; inspecting different groups
-- never changes it. Invalid/out-of-range samples remain holes, not clamped data.
local function NativeHP(values,maximum)
 page.native={recapID=50,recapMaxHealth=maximum,rows={}}
 for i,hp in ipairs(values)do page.native.rows[i]={nativeIndex=i==#values and 1 or i+1,nativeOffset=i-#values,kind='damage',amount=1,recordedHP=hp}end
 U:ShowLast()
end
for _,case in ipairs({{5000,10},{26000,30},{99000,100},{0,10}})do
 NativeHP({case[1],1000},100000)
 check(popup.healthGraphScale.upper==case[2]and popup.healthGraphScale.maximum==100000*case[2]/100,'Live graph upper bound did not round up to the next tenth of the reference maximum')
 check(popup.graphScaleTicks[1].text==case[2]..'%'and popup.graphScaleTicks[2].text==case[2]/2 ..'%'and popup.graphScaleTicks[3].text=='0%','Live graph tick labels do not identify the visible range')
 local fixed=popup.healthGraphScale
 for _,button in ipairs(objects)do if button.parent==popup and button.group and button:IsVisible()then button:Fire('OnEnter');check(popup.healthGraphScale==fixed,'Hover rescaled the captured page')end end
 check(popup.healthBar.minimum==0 and popup.healthBar.maximum==100000,'Lower graph scale changed the upper health bar denominator')
end
for _,ceiling in ipairs({10000,100000})do
 NativeHP({1000,ceiling},100000)
 check(popup.selected.nativeIndex==1 and popup.healthGraphScale.upper==ceiling/1000 and popup.pointPercent.text==ceiling/1000 ..'%'and popup.pointPercent.points[1][5]==-10,'Selected live graph ceiling percentage overlaps the recorded-window caption')
end
NativeHP({100000,1000},100000)
check(popup.pointPercent.points[1][5]==10,'Low live HP percentage lost its above-point position')
local hidden=setmetatable({},{__tostring=function()error('Secret health stringified')end})
local publicCheck=issecretvalue;issecretvalue=function(v)return rawequal(v,hidden)or publicCheck(v)end
NativeHP({26000,hidden,100001,-1,0/0,math.huge,'5000',false,1000},100000)
check(popup.healthGraphScale.upper==30 and popup.healthGraphScale.count==2,'Invalid health affected the live scale or became valid marks')
local marks,segments=0,0
for _,o in ipairs(objects)do if o.parent==popup and o:IsVisible()and o.color then
 if o.kind=='Texture'and o.width==6 and o.height==2 and o.color[4]==.95 then marks=marks+1 end
 if o.kind=='Line'and o.color[4]==.5 then segments=segments+1 end
end end
check(marks==2 and segments==0,'Invalid health samples were clamped or bridged')
NativeHP({hidden,false,-1},100000)
check(not popup.healthGraphScale and not popup.graphBase:IsShown()and not popup.graphHelp:IsShown(),'Unavailable health fabricated a graph scale')
for _,tick in ipairs(popup.graphScaleTicks)do check(not tick:IsShown(),'Unavailable health retained a scale tick')end
NativeHP({26000,1000},hidden)
check(not popup.healthGraphScale and not popup.healthPoint:IsShown(),'Secret maximum gained a scale/selected marker')
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
  check(button.height==30 and button.points[1][4]>=33 and button.points[1][4]+button.width<=847,'Named use chips escaped their original single row bounds')
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
check(#chips==8 and not overflow,'Eight compact named chips needlessly hid a fitting ability')
page.casts={{spellID=701,name=string.rep('Long ability ',12),observedAt=98},{spellID=701,name=string.rep('Long ability ',12),observedAt=99}}
U:ShowLast();chips,overflow=UseChips();local long=chips[1]
check(#chips==1 and long.width<=230 and long.useLabel.width>0 and long.useLabel.maxLines==1 and long.useMeta.text=='×2 · 1.0s'and long.useMeta.width>=long.useMeta:GetUnboundedStringWidth(),'Long name clipped the independent count/latest age or expanded the bounded row')
page.native=nil;U:Render()
U:Preview();tooltipLines={};popup.graphHelp:Fire('OnEnter');local previewHelp=table.concat(tooltipLines,' ')
check(popup.rail:IsShown()and popup.death:IsShown(),'Preview did not restore its example timeline')
check(previewHelp:find('fictional example',1,true)and previewHelp:find('stepped health curve',1,true)and not previewHelp:find('Dashed',1,true),'Preview graph help describes the real sample graph')
check(popup.graphLabel.text=='HP'and popup.graphLabel.width==40 and popup.healthPoint.width==12 and popup.healthPoint.height==12 and not popup.graphContext:IsShown(),'Live scale changed Preview composition')
check(popup.pointPercent.points[1][5]==10,'Live graph ceiling avoidance changed Preview percentage placement')
for _,tick in ipairs(popup.graphScaleTicks)do check(not tick:IsShown(),'Live scale ticks leaked into Preview')end
for _,disc in ipairs(popup.healthPoint.discs)do check(disc:IsShown(),'Preview lost its original selected health marker')end
for _,button in ipairs(objects)do if button.parent==popup and button.icon and button.width==30 and button:IsVisible()then
 check(not button.useLabel or not button.useLabel:IsShown()and not button.useMeta:IsShown(),'Live use chip labels leaked into Preview')
end end
for _,line in ipairs(popup.tooltipRecap.lines)do check(not line.recapAmount or not line.recapAmount:IsShown()and not line.recapTime:IsShown(),'Absorb amount/time columns leaked into an ordinary Preview tooltip')end
io.write('PASS: '..checks..' actual-UI pooled artwork, HP gaps, receipt provenance, tooltip reachability and check-age assertions\n')
]=]
assert(loadstring(source,'death-recap-presentation-fixture'))()
