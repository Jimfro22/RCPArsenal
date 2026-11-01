local function Read(path)local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local source=Read('tests/hub.lua');source=source:sub(1,assert(source:find('check(db.schemaVersion == 19',1,true))-1)
local ui=Read('tests/death_recap_ui.lua');local marker='source=source..[=[';local start=assert(ui:find(marker,1,true))+#marker
source=source..ui:sub(start,assert(ui:find('local groupCalls=',start,true))-1)
source=source..[=[
local page={id=501,diedAt=100,casts={{spellID=235450,name='Barrier',observedAt=99}},lastAlive={spells={},supplies={}},native={recapID=50,recapMaxHealth=100000,rows={}}}
R.GetPage=function()return page end
for _,id in ipairs({1285017,1306906,1283290,235450})do spellIcons[id]=id+100000 end
U:Preview()
local values={{-1,14000},{-.7,10000},{-.4,nil},{-.2,1000},{0,0}}
for i,v in ipairs(values)do page.native.rows[i]={nativeIndex=i==5 and 1 or i+1,nativeOffset=v[1],kind='damage',amount=i,name='Hit '..i,recordedHP=v[2]}end
U:ShowLast();local popup=named.RCPArsenalDeathRecap
RA:RefreshVisualAssets()
for _,b in ipairs(objects)do if b.parent==popup and b.group and b:IsVisible()and not b.group.mixed then check(b.icon.texture==134400,'Recycled nil-spell hit retained Preview artwork')end end
check(popup.usesLabel:IsShown()and popup.usesLabel.text=='Recorded uses','Live Barrier receipt has no visible provenance label')
local selected=popup.selected
for _,b in ipairs(objects)do if b.parent==popup and b.icon and b.width==30 and b:IsVisible()then
 tooltipLines={};b:Fire('OnEnter');local copy=table.concat(tooltipLines,' ')
 check(copy:find('Use recorded.',1,true)and copy:find('1.0s before the local death notification',1,true)and copy:find('Timing on this timeline unavailable.',1,true),'Recorded use acquired inferred native timing/duration')
 check(popup.selected==selected,'Use hover changed selected health')
end end
local function X(t)return 48+(t-popup.timeDomain.first)/(popup.timeDomain.last-popup.timeDomain.first)*784 end
local dots,joins=0,0
for _,o in ipairs(objects)do if o.parent==popup and o:IsVisible()and o.color then
 if o.kind=='Texture'and o.width==4 and o.height==4 and o.drawLayer=='OVERLAY'and o.color[4]==.95 then dots=dots+1 end
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
page.lastAlive.spells={{spellID=235450,cooldown='active',observedAt=50,cooldownAt=50,chargesAt=99,chargeQuery='public',currentCharges=1,maxCharges=2}}
page.lastAlive.supplies={}
for i=1,32 do page.lastAlive.supplies[i]={kind='potion',itemID=100+i,physicalCount=1,remainingUses=i,cooldown='inactive',observedAt=99,carriedAt=50}end
U:ShowLast();check(popup.shelfAge.text=='1.0s pre-death','Charge verdict age used old cooldown time')
local shelves={};for _,b in ipairs(objects)do if b.parent==popup and b.icon and b.width==32 and b:IsVisible()then shelves[#shelves+1]=b end end
check(#shelves==3,'Item candidates expanded into multiple family shelf icons')
local family
for _,b in ipairs(shelves)do if b.wheel then family=b end end
check(family,'Multi-item family cannot be inspected');family:Fire('OnEnter')
for i=1,32 do family:Fire('OnMouseWheel',-1)end
card=popup.tooltipRecap;local found
for _,line in ipairs(card.lines)do if line:IsShown()and line.text:find('Item 132:',1,true)then found=line end end
check(found and found.recapY+found.height-card.scroll:GetVerticalScroll()<=card.height,'Last family candidate was truncated/unreachable')
io.write('PASS: '..checks..' actual-UI pooled artwork, HP gaps, receipt provenance, tooltip reachability and check-age assertions\n')
]=]
assert(loadstring(source,'death-recap-presentation-fixture'))()
