-- Source-bound owner recap regression using actual addon modules and UI input
-- callbacks. This is offline drawing-input coverage, not native acceptance.
local testPrint=print
local function Read(path)
    local f=assert(io.open(path));local text=f:read('*a');f:close();return text
end
local source=Read('tests/hub.lua')
source=source:sub(1,assert(source:find('check(db.schemaVersion == 19',1,true))-1)
local ui=Read('tests/death_recap_ui.lua');local marker='source=source..[=['
local first=assert(ui:find(marker,1,true))+#marker
source=source..ui:sub(first,assert(ui:find('local groupCalls=',first,true))-1)
source=source..[=[
local fixture=assert(loadfile('tests/fixtures/death_log/owner_recap_3066.lua'))()
local page=fixture.NewPage()
R.GetPage=function()return page end
local function Near(a,b)return type(a)=='number'and math.abs(a-b)<.00001 end
local function CheckByID(id)
 for _,row in ipairs(page.lastAlive.spells)do if row.spellID==id then return row end end
 error('Missing owner spell '..id)
end
check(fixture.raw.recapID==3066 and fixture.raw.changedFieldsOrSlots==0,'Owner recap identity/reread agreement lost')
check(#page.native.rows==10 and page.native.recapMaxHealth==850900,'Owner native packet or denominator changed')
check(#page.casts==0 and #page.lastAlive.supplies==0 and not page.encounter and not page.heals and not page.supports,'Subset invented receipt/item/encounter/healing facts')
check(not page.observedUses[342245]and not page.observedUses[110959],'Unavailable aggregate count became zero uses')
local barrier,mirror=CheckByID(235450),CheckByID(55342)
local state,detail=R:ClassifyRecordedCheck(barrier)
check(state==nil and barrier.cooldown=='inactive'and barrier.maxCharges==2 and barrier.currentCharges==nil and barrier.chargeCountStatus=='restricted'and barrier.chargesActive==true,'Owner Barrier gained readiness from inactive normal cooldown or recharge flag')
check(detail:find('Normal cooldown was inactive',1,true)and detail:find('remaining charges were not established',1,true),'Unknown Barrier erased independent cooldown fact')
state,detail=R:ClassifyRecordedCheck(mirror)
check(state==nil and mirror.isActive==true and mirror.isOnGCD==nil and mirror.cooldownGCDStatus=='not-recorded','Owner Mirror Image gained an availability verdict')
check(detail:find('Cooldown active when checked',1,true)and not detail:find('outside',1,true),'Missing GCD context acquired an unsupported event-cause claim')
check(Near(page.diedAt-R:GetRecordedCheckTime(barrier),1.907)and Near(page.diedAt-R:GetRecordedCheckTime(mirror),1.907),'Owner cooldown check age changed')
check(Near(page.diedAt-page.observedUses[235450].lastSuccessfulUseAt,5.235)and Near(page.diedAt-page.observedUses[55342].lastSuccessfulUseAt,18.380),'Use age was replaced with cooldown check age')
check(Near(page.diedAt-barrier.chargesAt,.475),'Independent charge-query age changed')

local model=RA.DeathLogModel:Group(page.native.rows,{})
local seen,tied,count={},0,0
for _,group in ipairs(model.items)do
 for _,row in ipairs(group.rows)do
  check(not seen[row.nativeIndex],'Owner native row duplicated')
  seen[row.nativeIndex]=true;count=count+1
  if row.timestamp==1793504614.113 then
   tied=tied+1
   check(row.spellID==294741 and row.amount==15014 and row.absorbed==1667,'Tied Saber Slash event changed')
  end
 end
 if group.fatal then check(#group.rows==1 and group.rows[1].nativeIndex==1,'Owner fatal hit became a grouped sum')end
end
check(count==10 and tied==3,'Native timestamp ties were deduplicated')
check(model.rows[1].recordedHP==223196 and model.rows[#model.rows].recordedHP==45326,'Raw owner HP endpoints were rewritten')
local expectedHP={45326,72995,88095,103195,118295,132353,162961,177341,208348,223196}
for i,row in ipairs(page.native.rows)do
 check(row.nativeIndex==i and row.recordedHP==expectedHP[i]and row.timestamp==fixture.raw.nativeRows[i].timestamp,'Normalization changed native order, timestamp or raw HP')
 check(row.sourceKey==nil and row.sourceName==nil,'Missing source identity was invented')
end
local absorbs=RA.DeathLogModel:GroupAbsorbs(model.rows,function(t)return 48+(t-model.rows[1].nativeOffset)/(-model.rows[1].nativeOffset)*784 end,function()return 40 end)
local absorbedTotal,absorbMembers=0,0
for _,cluster in ipairs(absorbs)do
 absorbedTotal=absorbedTotal+cluster.amount
 for _,row in ipairs(cluster.rows)do absorbMembers=absorbMembers+1;check(row.absorbed==fixture.raw.nativeRows[row.nativeIndex].absorbed,'Absorb cluster changed owner hit credit')end
end
check(absorbedTotal==28797 and absorbMembers==8,'Owner absorbed amounts were lost or invented')

check(U:ShowLast(),'Owner recap did not open in actual UI')
local popup=named.RCPArsenalDeathRecap
check(popup.width==880 and popup.selected.nativeIndex==1 and popup.healthPanel.selectedHP==45326,'Owner fatal selection acquired zero HP or moved main layout')
check(popup.hp.text=='45326 / 850900'and popup.percent.text=='5%'and popup.healthPoint:IsShown(),'Owner fatal HP/denominator was lost in actual UI')
check(popup.healthGraphScale.upper==30 and popup.healthGraphScale.maximum==255270 and popup.healthGraphScale.count==10,'Owner graph did not use all ten valid samples for its 0–30% scale')
check(popup.graphLabel.text=='Recorded HP · 0–30% of max HP'and popup.graphScaleTicks[1].text=='30%'and popup.graphScaleTicks[2].text=='15%'and popup.graphScaleTicks[3].text=='0%','Owner graph has no explicit shared scale labels')
check(popup.graphContext.text=='10 hits · 1.8s recorded','Owner native window context used local death/use timing or padded domain width')
check(popup.healthPoint.width==8 and popup.healthPoint.height==2,'Owner selected marker can conceal adjacent tied health ticks')
local capturedMarks={}
for _,region in ipairs(objects)do if region.parent==popup and region.kind=='Texture'and region:IsVisible()and region.width==6 and region.height==2 and region.color and region.color[4]==.95 then
 capturedMarks[#capturedMarks+1]={x=region.points[1][4]+3,y=region.points[1][5]-1}
end end
check(#capturedMarks==10,'Owner raw samples were dropped or inferred on the live graph')
local tiedX=48+(page.native.rows[3].nativeOffset-popup.timeDomain.first)/(popup.timeDomain.last-popup.timeDomain.first)*784
local tiedMarks={}
for _,mark in ipairs(capturedMarks)do if math.abs(mark.x-tiedX)<1 then tiedMarks[#tiedMarks+1]=mark end end
table.sort(tiedMarks,function(a,b)return a.y<b.y end)
check(#tiedMarks==3 and tiedMarks[2].y-tiedMarks[1].y>=2 and tiedMarks[3].y-tiedMarks[2].y>=2,'Owner tied HP ticks overlap or moved away from their true native time')
local fixedScale=popup.healthGraphScale
-- Native timestamps stay tied even when collision layout moves the hit icons.
-- At a fractional scale each selected receipt must still expose its own HP.
local previousScale=popup:GetEffectiveScale();popup:SetScale(.8)
local inspectedTies,shiftedTies=0,0
for nativeIndex=3,5 do
 local target,memberIndex
 for _,button in ipairs(objects)do if button.parent==popup and button.group and button:IsVisible()then
  for index,row in ipairs(button.group.rows)do if row.nativeIndex==nativeIndex then target,memberIndex=button,index end end
 end end
 check(target~=nil,'Owner tied event has no selectable hit target')
 target.member=memberIndex;target:Fire('OnEnter');inspectedTies=inspectedTies+1
 local row=page.native.rows[nativeIndex];local point=popup.healthPoint.points[1]
 local expectedY=popup.graphBase.points[1][5]+row.recordedHP/fixedScale.maximum*60
 check(popup:GetEffectiveScale()==.8 and popup.healthPoint:IsVisible()and popup.pointPercent:IsVisible(),'Displaced owner tied event hid its valid selected HP marker/percentage at fractional scale')
 check(popup.selected.nativeIndex==nativeIndex and popup.healthPanel.selectedHP==expectedHP[nativeIndex]and popup.hp.text==expectedHP[nativeIndex]..' / 850900','Tied selection substituted another receipt HP')
 check(Near(point[4],tiedX)and Near(point[4]*.8,tiedX*.8)and Near(point[5],expectedY),'Tied selected marker moved from exact native time/raw-HP position to packed icon position')
 check(popup.pointPercent.text==string.format('%.0f%%',row.recordedHP/850900*100)and popup.healthGraphScale==fixedScale,'Tied selected percentage or frozen graph scale changed')
 if math.abs(target.group.iconX-tiedX)*.8>1 then shiftedTies=shiftedTies+1 end
end
check(inspectedTies==3 and shiftedTies==2,'Owner regression did not exercise all three ties and both collision-displaced hit icons')
popup:SetScale(previousScale)
for _,button in ipairs(objects)do if button.parent==popup and button.group and button:IsVisible()then
 for i,row in ipairs(button.group.rows)do if row.nativeIndex==10 then
  button.member=i;button:Fire('OnEnter')
  check(popup.healthPanel.selectedHP==223196 and popup.hp.text=='223196 / 850900','Oldest owner native HP was reconstructed from damage')
  check(popup.healthGraphScale==fixedScale and popup.percent.text=='26%','Owner inspection changed the graph scale or rescaled the upper health percentage')
 end end
end end
local selected=popup.selected
local inspected=0
for _,button in ipairs(objects)do if button.parent==popup and button.icon and button.width==32 and button:IsVisible()then
 tooltipSpell=nil;tooltipLines={};button:Fire('OnEnter')
 if tooltipSpell==235450 or tooltipSpell==55342 then
  inspected=inspected+1
  local copy=table.concat(tooltipLines,' ')
  check(copy:find('1.9s',1,true),'Owner shelf lost the independent recorded check age')
  check(button.icon.rgb[1]==.55 and not copy:find('outside',1,true),'Owner unknown shelf verdict/neutral reason regressed')
  local expectedUseAge=tooltipSpell==235450 and '5.2s' or '18.4s'
  local expectedCount=tooltipSpell==235450 and 'Used 2 times' or 'Used once'
  check(copy:find(expectedUseAge,1,true)and popup.tooltipRecap.lines[1].text:find(expectedCount,1,true),'Owner shelf did not lead with affirmative use count and its independent use age')
  check(popup.tooltipRecap.lines[1].text:find('death notice',1,true),'Owner local use age was presented on the native recap clock')
  if tooltipSpell==235450 then
   local recharge
   for _,line in ipairs(popup.tooltipRecap.lines)do if line:IsShown()and line.text:find('Recharging when checked',1,true)then recharge=line.text end end
   check(recharge and recharge:find('0.5s',1,true)and not recharge:find('1.9s',1,true),'Owner recharge fact borrowed the older cooldown timestamp')
  end
 end
end end
check(inspected==2 and popup.selected==selected,'Owner shelf hover omitted a spell or changed selected HP')

-- This optional receipt list is deliberately DERIVED, never claimed as the
-- owner's raw per-use export. Count 2 permits exactly its first/last endpoints.
local derived=fixture.NewPage(true)
check(#derived.casts==4 and derived.fixtureProvenance.individualReceipts:find('DERIVED',1,true),'Optional derived receipts lack provenance')
local barriers,mirrors=0,0
local previous=-math.huge
for _,cast in ipairs(derived.casts)do
 check(cast.derived==true and cast.source=='DERIVED_FROM_AGGREGATE_ENDPOINT'and cast.derivation:find('not an exported individual receipt',1,true),'Derived receipt masquerades as raw export')
 check(cast.observedAt>=previous and cast.nativeOffset==nil and cast.finish==nil,'Derived receipt gained native alignment or uptime')
 previous=cast.observedAt
 if cast.spellID==235450 then barriers=barriers+1 elseif cast.spellID==55342 then mirrors=mirrors+1 end
end
check(barriers==2 and mirrors==1,'Aggregate endpoints generated the wrong receipt count')
page=derived;U:ShowLast();selected=popup.selected
check(popup.recordedUseGroups[1].spellID==235450 and popup.recordedUseGroups[2].spellID==414658 and popup.recordedUseGroups[3].spellID==55342,'Owner use groups are not newest first')
local groupCount,groupedBarrier=0,false
for _,button in ipairs(objects)do if button.parent==popup and button.useGroup and button:IsVisible()then
 groupCount=groupCount+1
 if button.useGroup.spellID==235450 then
  groupedBarrier=true;check(#button.useGroup.rows==2 and button.useMeta.text=='×2 · 5.2s','Derived repeated Barrier endpoints did not share a visible count and latest age')
  tooltipLines={};button:Fire('OnEnter');local copy=table.concat(tooltipLines,' ')
  check(copy:find('23.0s',1,true)and copy:find('5.2s',1,true)and copy:find('death notice',1,true),'Grouped receipt tooltip lost either local age or its clock provenance')
  button:Fire('OnMouseWheel',-1);button:Fire('OnMouseWheel',-1)
 end
end end
check(groupCount==3 and groupedBarrier and popup.selected==selected,'Derived receipt grouping lost identities or moved selected HP')
derived.native.rows[1].recordedHP=0
check(fixture.NewPage().native.rows[1].recordedHP==45326 and fixture.raw.nativeRows[1].recordedHP==45326,'Fixture consumers mutated source facts')
cleanErrors()
nativePrint('PASS: '..checks..' owner recap3066 source, classifier, clock, tied-row and actual-UI raw-HP assertions (offline)')
]=]
assert(loadstring(source,'death-recap-owner3066'))()

-- Separate SYNTHETIC recorder scenario: a matching direct event with omitted
-- isOnGCD can yield the same unknown state. This is not the owner's event order.
local recorder=Read('tests/death_recap.lua')
recorder=recorder:sub(1,assert(recorder:find('check(optionalCount()==0',1,true))-1)
recorder=recorder..[=[
function UnitClass()return 'Mage','MAGE'end
function GetSpecializationInfo()return 62 end
RA.DeathRecapCatalog.entries={{key='mirror',spellID=55342,name='Mirror Image',class='MAGE',specs={62},knownSpellIDs={55342},category='minor',verified=true}}
time=100;combat=true;cooldown={isEnabled=true,isActive=false};charges=nil
R:SetOption('enabled',true)
time=100.1;cooldown={isEnabled=true,isActive=true};event('SPELL_UPDATE_COOLDOWN',55342)
time=100.11;dead=true;event('PLAYER_DEAD')
local row=R:GetPage().lastAlive.spells[1]
check(row.spellID==55342 and row.source=='cooldown-event'and row.directCooldown.valid==true and row.cooldownGCDStatus=='not-recorded','Synthetic direct Mirror callback did not preserve missing GCD context')
local verdict,reason=R:ClassifyRecordedCheck(row)
check(verdict==nil and row.cooldown=='active-context-unknown'and reason:find('Cooldown active when checked',1,true)and not reason:find('outside',1,true),'Direct missing-GCD callback gained readiness or false outside-event explanation')
R:SetOption('enabled',false)
return checks
]=]
local directChecks=assert(loadstring(recorder,'death-recap-owner3066-direct-context'))()
testPrint('PASS: '..directChecks..' synthetic direct Mirror Image missing-GCD cause regression assertions (offline)')
