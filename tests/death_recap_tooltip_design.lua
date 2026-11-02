-- Synthetic receipts and region metrics exercise the actual tooltip painter.
local function Read(path)local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local source=Read('tests/hub.lua');source=source:sub(1,assert(source:find('check(db.schemaVersion == 19',1,true))-1)
local ui=Read('tests/death_recap_ui.lua');local marker='source=source..[=[';local start=assert(ui:find(marker,1,true))+#marker
source=source..ui:sub(start,assert(ui:find('local groupCalls=',start,true))-1)
source=source..[=[
RAID_CLASS_COLORS={MAGE={r=.2,g=.8,b=1}}
local page={id=45,diedAt=100,lastAlive={spells={},supplies={}},native={recapID=45,recapMaxHealth=100000,rows={
 {nativeIndex=3,nativeOffset=-.4,kind='damage',spellID=731,name='First spell',amount=50123,recordedHP=60000,sourceName='Example caster',sourceClass='MAGE',hideCaster=false},
 {nativeIndex=2,nativeOffset=-.2,kind='damage',spellID=732,name='Second spell',amount=15234,recordedHP=44766,sourceName='Hidden source',hideCaster=true},
 {nativeIndex=1,nativeOffset=0,kind='damage',spellID=733,name='Final spell',amount=51000,recordedHP=44766,overkill=6234,sourceName='Example creature',hideCaster=false}}}}
R.GetPage=function()return page end;U:ShowLast();local popup=named.RCPArsenalDeathRecap
local function Hit()
 for _,b in ipairs(objects)do if b.parent==popup and b.group and b:IsVisible()then return b end end
 error('No hit marker')
end
local hit=Hit();hit:Fire('OnEnter');local card=popup.tooltipRecap
check(card.eventHeading.text=='116.4k damage'and card.eventCount.text=='3 hits','Tooltip lost the damage/count hierarchy')
check(card.eventHeading.textColor[1]==RA.Theme.Colors.text[1]and card.eventCount.textColor[1]==RA.Theme.Colors.muted[1],'Header and count lost separate contrast')
local first,second,last=card.eventRows[1],card.eventRows[2],card.eventRows[3]
check(first.ability.text=='First spell'and first.time.text=='-0.4s'and first.amount.text=='50,123'and first.source.text=='Example caster','Per-hit columns do not preserve their original facts')
check(first.ability.textColor[1]==RA.Theme.Colors.text[1]and first.time.textColor[1]==RA.Theme.Colors.muted[1]and first.amount.textColor[1]==RA.Theme.Colors.danger[1],'Entire damage row is still one color')
check(first.source.textColor[1]==.2 and first.source.textColor[2]==.8 and last.source.textColor[1]==RA.Theme.Colors.muted[1],'Captured player class color or neutral creature source changed')
check(not second.source:IsShown()and second.source.text=='','Hidden source reached the event table')
check(last.status.text=='Killing blow'and last.mitigation.text=='6.2k overkill'and last.selected and last.background:IsShown()and last.selection:IsShown(),'Fatal/selected/mitigation meaning was lost')
check(not first.background:IsShown()and not first.selection:IsShown()and first.ability.points[1][4]>first.time.points[1][4]and first.amount.points[1][1]=='TOPRIGHT','Selection highlight or visual column alignment is wrong')
check(card.eventHint:IsShown()and card.eventHint.side=='wheel'and card.eventHint.label.text=='Scroll to browse','Group hover has no compact wheel affordance')
hit:Fire('OnMouseWheel',-1)
check(popup.selected==page.native.rows[1]and first.background:IsShown()and not last.background:IsShown(),'Wheel navigation no longer connects selected receipt, highlight and health')
-- Large clusters remain scrollable while summary and hint stay pinned.
page.native.rows={}
for i=1,64 do page.native.rows[i]={nativeIndex=i,nativeOffset=0,kind='damage',spellID=731,name='Repeated spell',amount=i,recordedHP=1000}end
U:ShowLast();hit=Hit();hit:Fire('OnEnter')
for i=2,64 do hit:Fire('OnMouseWheel',-1)end
card=popup.tooltipRecap;local final=card.eventRows[64]
check(card.overflowing and final.selected and card.scroll:GetVerticalScroll()>0,'Dense selected hit is inaccessible')
check(final.y+final.rowHeight-card.scroll:GetVerticalScroll()<=card.scroll.height+.001,'Dense selected hit extends beyond its visible viewport')
check(card.eventHeading:IsShown()and card.eventHint:IsShown()and card.eventHeading.parent==card and card.eventHint.parent==card,'Dense list scrolled its header or interaction hint away')
-- Returning to generic help clears the pooled event rows and decorations.
popup.reminder:Fire('OnEnter')
check(not first:IsShown()and not card.eventHeading:IsShown()and not card.eventCount:IsShown()and not card.eventHint:IsShown(),'Event-table rows leaked into an unrelated tooltip')
U:ShowLast();page.native.rows={page.native.rows[1]};U:ShowLast();Hit():Fire('OnEnter')
check(card.eventRows[1]:IsShown()and not card.eventRows[2]:IsShown()and not card.eventHint:IsShown(),'Single event retained old rows or a redundant scroll instruction')
io.write('PASS: '..checks..' structured tooltip facts/hierarchy/colors/privacy/selection/density/pooling assertions\n')
]=]
assert(loadstring(source,'death-recap-tooltip-design'))()
