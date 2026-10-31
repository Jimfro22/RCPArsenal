-- Actual modules and native-region callbacks; offline decisions, not WoW pixels.
local f=assert(io.open('tests/hub.lua'));local source=f:read('*a');f:close()
source=source:sub(1,assert(source:find('check(db.schemaVersion == 19',1,true))-1)
source=source..[=[
function methods:GetScript(name)return self.scripts[name]end
function methods:SetAlpha(v)check(type(v)=='number'and v==v and v>=0 and v<=1,'Invalid native alpha');self.alpha=v end
function methods:SetVertexColor(r,g,b)self.rgb={r,g,b}end
function methods:SetAtlas(atlas)self.atlas=atlas end
function methods:EnableMouseWheel(v)self.wheel=v end
function methods:GetValue()error('Historical UI read back a native bar value')end
local tooltipSpell,tooltipLines=nil,{}
function GameTooltip:SetSpellByID(id)tooltipSpell=id end
function GameTooltip:AddLine(line)tooltipLines[#tooltipLines+1]=line end
UISpecialFrames={}
local R,U=RA.DeathRecap,RA.DeathRecapUI
local groupCalls=0;local originalGroup=RA.DeathLogModel.Group;RA.DeathLogModel.Group=function(self,...)groupCalls=groupCalls+1;return originalGroup(self,...)end
check(not db.deathRecap.enabled and not named.RCPArsenalDeathRecap,'DefaultOFF created UI')
local page={id=10,diedAt=100,class='MAGE',specID=62,encounter={name='Example real encounter',startedAt=0},casts={{spellID=235450,observedAt=99}},
 native={recapID=1,recapMaxHealth=100000,rows={
 {nativeIndex=2,nativeOffset=-4.5,spellID=123,name='Tick',kind='damage',amount=100,recordedHP=90000,sourceConfirmed=true,sourceKey='A'},
 {nativeIndex=3,nativeOffset=-4.3,spellID=123,name='Tick',kind='damage',amount=100,recordedHP=80000,sourceConfirmed=true,sourceKey='A'},
 {nativeIndex=4,nativeOffset=-3.5,spellID=124,name='Major',kind='damage',amount=200000,recordedHP=70000},
 {nativeIndex=1,nativeOffset=0,spellID=125,name='Fatal',kind='damage',amount=100,recordedHP=0}}},
 lastAlive={observedAt=99.9,spells={
 {spellID=45438,name='Zero charges',category='major',observedAt=99.9,cooldown='inactive',chargeQuery='public',maxCharges=2,currentCharges=0},
 {spellID=342245,name='On hold',category='minor',observedAt=99.9,cooldown='held',chargeQuery='public',currentCharges=1,maxCharges=2},
 {spellID=235450,name='Old unchanged check',category='minor',observedAt=55,cooldown='inactive',chargeQuery='unreadable',chargeReason='restricted'}},
 supplies={{kind='stone',itemID=5512,carried=true,carriedAt=45,observedAt=99.9,physicalCount=1,remainingUses=1,cooldown='inactive',usable=false},
 {kind='potion',itemID=241304,observedAt=99.9,physicalCount=0,cooldown='inactive'}}}}
local pageReads=0
R.GetPage=function()pageReads=pageReads+1;return page end
local getter=R.GetState;R.GetState=function(self)local s=getter(self);s.hasPage=page~=nil;return s end
local function under(obj,ancestor)while obj do if obj==ancestor then return true end;obj=obj.parent end end
local function button(label,hidden)
 for _,obj in ipairs(objects)do if obj.label and obj.label.text==label and under(obj,named.RCPArsenalDeathRecap)and(hidden or obj:IsVisible())then return obj end end
end
check(U:ShowLast(),'Real log unavailable');local popup=named.RCPArsenalDeathRecap
local function hits()local out={};for _,obj in ipairs(objects)do if obj.parent==popup and obj.group and obj:IsVisible()then out[#out+1]=obj end end;return out end
local function shelves()local out={};for _,obj in ipairs(objects)do if obj.parent==popup and obj.icon and obj.width==32 and obj:IsVisible()then out[#out+1]=obj end end;return out end
local function hover(index)
 for _,b in ipairs(hits())do for i,row in ipairs(b.group.rows)do if row.nativeIndex==index then b.member=i;b:Fire('OnEnter');return b end end end;error('Missing raw event '..index)
end
check(UISpecialFrames[1]=='RCPArsenalDeathRecap'and popup:GetScript('OnHide'),'Escape/nativehide cleanup missing')
check(popup.title.text=='Death Log'and popup.width==880 and popup.height>=440,'Composition lost Death Log hierarchy')
check(popup.shelf.text=='Last recorded check'and popup.shelfAge.text:find('45.0',1,true),'Real shelf falsely follows native clock or erases old check')
check(popup.selected.nativeIndex==1 and popup.healthPanel.selectedHP==0 and popup.healthBar:IsShown(),'Initial fatal health selection mismatch')
check(popup.tombstone.atlas=='deathrecap-icon-tombstone','Death used fabricated skull art')
check(not button('DETAILS ›')and not button('Grouped')and not button('Individual'),'Unapproved controls appeared')
local foundOld,foundStock,foundHold=false,false,false
for _,b in ipairs(shelves())do tooltipLines={};tooltipSpell=nil;b:Fire('OnEnter');local help=table.concat(tooltipLines,' ')
 if help:find('Old unchanged check',1,true)then foundOld=true;check(b.icon.rgb[1]==1 and help:find('off cooldown',1,true)and help:find('45.00s',1,true)and help:find('not provided by Blizzard',1,true),'Age or secret charge erased public cooldown fact')end
 if help:find('Healthstone',1,true)then foundStock=true;check(b.icon.rgb[1]==1 and help:find('55.00s',1,true),'Old cache/fresh stock or generic unusability erased cooldown fact')end
 if help:find('On hold',1,true)then foundHold=true;check(b.icon.rgb[1]==.4 and b.icon.alpha==1,'On hold state not precise static dim')end
end
check(foundOld and foundStock and foundHold,'Known shelf rows omitted')
local grouped=hover(2);check(#grouped.group.rows==2,'Confirmed same-source burst not grouped')
tooltipLines={};grouped:Fire('OnEnter');check(table.concat(tooltipLines,' '):find('Event 1/2',1,true),'Group moment not explicit')
grouped:Fire('OnMouseWheel',-1);check(popup.selected.nativeIndex==3 and popup.healthPanel.selectedHP==80000,'Wheel did not select exact constituent HP')
check(grouped.amountTarget and grouped.amountTarget:IsVisible(),'Amount has no actual hover/wheel target');grouped.amountTarget:Fire('OnEnter')
local click=grouped:GetScript('OnClick');click();check(popup.selected.nativeIndex==3,'Journal click also cycled events')
hover(4);RA:FireCallback('ACCENT_THEME_CHANGED');for _,b in ipairs(hits())do if b.group.spellID==123 then grouped=b end end;grouped:Fire('OnEnter');check(popup.selected.nativeIndex==3,'Redraw forgot group constituent')
local staleClick=grouped:GetScript('OnClick');RA:FireCallback('ACCENT_THEME_CHANGED');staleClick();check(popup.selected.nativeIndex==3,'Stale render action changed selection')
-- Scrub is bounded pointer input while hovering only; stationary pointer cannot
-- undo wheel choice. No re-grouping or periodic capture is attached to it.
local x=300+48+(.5/5)*784;GetCursorPosition=function()return x,400 end
grouped.span:Fire('OnEnter');check(popup.selected.nativeIndex==2,'Span scrub missed exact nearest event')
grouped.span:Fire('OnMouseWheel',-1);grouped.span:Fire('OnUpdate');check(popup.selected.nativeIndex==3,'Stationary scrub undid wheel selection')
x=x+32;grouped.span:Fire('OnUpdate');grouped.span:Fire('OnLeave');check(grouped.span:GetScript('OnUpdate')==nil,'Pointer tracker survived leave')
local beforeFrames,beforeTimers,beforeGroups=#objects,#timers,groupCalls
for i=1,50 do hover(2);hover(3)end
check(#objects==beforeFrames and #timers==beforeTimers and groupCalls==beforeGroups,'Hover allocated or regrouped')
local fatal=page.native.rows[4];fatal.nativeOffset=-1;page.native.rows[5]={nativeIndex=5,nativeOffset=0,spellID=126,kind='unknown'}
U:ShowLast();check(popup.ticks[6].text=='0s'and popup.death:IsShown()and popup.death.points[1][4]==48+4/5*784 and popup.fight.text=='Fight 1:40 (notice)','Latest native time mislabeled as Death or clocks conflated')
fatal.nativeOffset=0;page.native.rows[5]=nil;U:ShowLast()
-- Preview identity and complete synthetic selected-time display.
local beforePage=page;local diagnostics=R:GetDiagnostics();local prefs={};for k,v in pairs(db.personalTools)do prefs[k]=v end
U:OpenBell();local enable=button('ENABLE');check(enable,'Live reminder confirmation missing')
local reads=pageReads;U:Preview();check(pageReads==reads,'Preview read retained real page')
check(popup.coverage:IsShown()and popup.coverage.text=='Example data'and popup.context.text:find('Arcane Mage · The Coiled Altar · Mythic',1,true),'Preview context/label incorrect')
check(popup.healthPanel.selectedHP==128000 and popup.percent.text=='32%'and popup.absorb:IsShown()and popup.healthPanel.healAbsorb==80000,'Example default health/debt not coherent')
check(popup.shelf.text=='Cooldowns · −2.30s','Example shelf not tied to exact selected moment')
check(not enable:IsVisible(),'Preview inherited live action popover');enable:Fire('OnClick')
for k,v in pairs(prefs)do check(db.personalTools[k]==v,'Preview changed preferences')end
check(page==beforePage and R:GetDiagnostics().nativeReads==diagnostics.nativeReads,'Preview changed recorder')
U:OpenShare();check(not button('OPEN CHAT'),'Preview opened live composer')
popup.healTargets[1]:Fire('OnEnter');check(popup.selected.nativeOffset==-4.2 and popup.healthPanel.selectedHP==336000 and popup.shelf.text=='Cooldowns · −4.20s','Example heal failed synchronized explicit snapshot')
for _,obj in ipairs(objects)do if obj.parent==popup and obj.icon and obj.width==30 and obj:IsVisible()then obj:Fire('OnEnter');check(popup.selected.nativeOffset==-3.5 or popup.selected.nativeOffset==-1.8,'Example defensive failed to select its actual time');break end end
RA:FireCallback('ACCENT_THEME_CHANGED');check(popup.guide:IsShown(),'Support selection disappeared on redraw')
local healerArtwork=0
for _,b in ipairs(popup.healTargets)do check(not b.icon and b.label.text:sub(1,1)=='+','Healing regained large artwork')end
local oldJournal;local mapped
for _,b in ipairs(hits())do if b.group.spellID==1285017 then mapped=b;break end end
check(mapped,'Coiled preview mapping missing');oldJournal=mapped:GetScript('OnClick')
local opens,loads,selectedContext=0,0,{}
EncounterJournal_LoadUI=function()loads=loads+1 end
EJ_SelectInstance=function(id)selectedContext.instance=id end;EJ_SetDifficulty=function(id)selectedContext.difficulty=id end;EJ_SelectEncounter=function(id)selectedContext.encounter=id end
EJ_GetEncounterInfo=function()return 'The Coiled Altar','',2883,35058,nil,1320,3429,3004 end
local wrongSection=false
C_EncounterJournal={GetSectionInfo=function(id)
 check(selectedContext.difficulty==16 and selectedContext.encounter==2883,'Section validated in old Journal context')
 if id==35058 then return {spellID=1,firstChildSectionID=36846,filteredByDifficulty=false}end
 return {spellID=wrongSection and 1285017 or 1283832,filteredByDifficulty=false}
end}
local function Navigate(d,i,e,s)opens=opens+1;check(d==16 and i==1320 and e==2883 and s==36846,'Journal tuple wrong')end
EncounterJournal_OpenJournal=nil;EncounterJournal_LoadUI=function()loads=loads+1;EncounterJournal_OpenJournal=Navigate end
local member=mapped.member;oldJournal();check(opens==1 and mapped.member==member,'Normal click failed exact section relationship or also cycled')
wrongSection=true;oldJournal();check(opens==1,'DamageID incorrectly accepted as section spellID');wrongSection=false
combat=true;local loadCount=loads;oldJournal();check(loads==loadCount and opens==1,'Combat click loaded/navigated Journal');combat=false
EncounterJournal_LoadUI=function()loads=loads+1;combat=true end;oldJournal();check(opens==1,'Deferred combat check missing');combat=false
EncounterJournal_LoadUI=function()loads=loads+1 end
-- Real-looking fixture fields cannot activate the synthetic data path.
local realPage=page
page={id=11,diedAt=100,sample=true,origin='example',maxHealth=400000,healthPoints={{offset=-5,hp=400000}},heals={{offset=-1,amount=9000}},supports={{offset=-2,finish=0,spellID=235450}},
 native={recapID=2,recapMaxHealth=1000,rows={{nativeIndex=2,nativeOffset=-1,spellID=123,kind='damage',amount=10,recordedHP=750,exampleHP=99999},{nativeIndex=3,nativeOffset=-.7,spellID=124,kind='damage',amount=10},{nativeIndex=4,nativeOffset=-.5,spellID=125,kind='damage',amount=10,recordedHP=1200},{nativeIndex=1,nativeOffset=0,spellID=126,kind='damage',amount=10,recordedHP=0}}},
 casts={},knownEntries={{spellID=235450,name='Known without observation',category='minor'}}}
U:ShowLast();oldJournal();check(opens==1,'Stale preview callback navigated')
check(not popup.coverage:IsShown()and not popup.absorb:IsShown()and popup.shelf.text=='Last recorded check','Real page adopted sample fields')
for _,b in ipairs(popup.healTargets)do check(not b:IsVisible(),'Synthetic heals leaked into real page')end
for _,obj in ipairs(objects)do if obj.width==30 and obj.parent==popup and obj.icon then check(not obj:IsVisible(),'Synthetic defensive interval/use leaked')end end
hover(2);check(popup.healthPanel.selectedHP==750 and popup.percent.text=='75%','Native selected raw health wrong')
hover(3);check(popup.healthPanel.selectedHP==nil and not popup.healthBar:IsShown(),'Missing row retained stale HP')
tooltipLines={};popup.healthPanel:Fire('OnEnter');local help=table.concat(tooltipLines,' ');check(help:find('1000',1,true)and help:find('not recorded for this event',1,true),'Missing HP erased valid denominator')
hover(4);check(popup.healthPanel.selectedHP==1200 and not popup.healthBar:IsShown()and popup.hp.text:find('1200',1,true),'Out-of-scale raw HP clamped/lost')
local secret=setmetatable({},{__tostring=function()error('Secret formatted')end});issecretvalue=function(value)return rawequal(value,secret)end
for _,value in ipairs({false,secret,-1,0/0,math.huge,-math.huge,'750',{}})do page.native.rows[1].recordedHP=value;U:ShowLast();hover(2);check(popup.healthPanel.selectedHP==nil and not popup.healthBar:IsShown(),'Bad HP became public value')end
page.native.rows[1].recordedHP=750
for _,value in ipairs({false,secret,0,-1,0/0,math.huge,'1000',{}})do page.native.recapMaxHealth=value;U:ShowLast();hover(2);check(popup.healthPanel.selectedHP==750 and not popup.healthBar:IsShown(),'Bad max erased raw HP or supplied bar')end
-- Every one of64retained rows is reachable even at identical times. Mixed
-- sums have no single spell artwork; fatal and largest preceding stay separate.
page.native.recapMaxHealth=1000;page.native.rows={}
for i=1,64 do page.native.rows[i]={nativeIndex=i,nativeOffset=-1,spellID=100+i,kind='damage',amount=i,recordedHP=i}end
U:ShowLast();local seen={}
for _,b in ipairs(hits())do
 if b.group.last==b.group.first then check(not b.span:IsShown()and b.span:GetScript('OnEnter')==nil,'Equal-time group kept a colliding scrub hitbox')end
 if b.group.mixed then check(b.group.spellID==nil and not b.icon:IsShown(),'Mixed sum uses single-spell artwork')end
 for i=1,#b.group.rows do b:Fire('OnMouseWheel',-1);seen[popup.selected.nativeIndex]=true end
end
for i=1,64 do check(seen[i],'Dense group lost constituent '..i)end
-- Three overlapping positive spans keep their true bracket intervals while
-- ambiguous mouse frames are removed. Their distinct glyph/amount wheel paths
-- still expose every constituent.
page={id=12,diedAt=100,casts={},native={recapID=3,recapMaxHealth=1000,rows={}}}
local nextIndex=2
for group=1,3 do for member=1,3 do
 page.native.rows[#page.native.rows+1]={nativeIndex=nextIndex,nativeOffset=-5+group*.2+(member-1)*.5,spellID=600+group,sourceKey='fixture-'..group,sourceConfirmed=true,kind='damage',amount=1}
 nextIndex=nextIndex+1
end end
page.native.rows[#page.native.rows+1]={nativeIndex=nextIndex,nativeOffset=-1.2,spellID=700,kind='damage',amount=1000}
page.native.rows[#page.native.rows+1]={nativeIndex=1,nativeOffset=0,spellID=701,kind='damage',amount=1}
U:ShowLast();local disabled=0;local overlapSeen={}
for _,b in ipairs(hits())do
 if b.group.count>1 and not b.scrubAvailable then disabled=disabled+1;check(not b.span:IsShown()and b.span:GetScript('OnMouseWheel')==nil,'Ambiguous span still intercepts neighbor')end
 for i=1,#b.group.rows do b.amountTarget:Fire('OnMouseWheel',-1);overlapSeen[popup.selected.nativeIndex]=true end
end
check(disabled>=2,'Overlapping positive-span component did not use fallback')
for i=1,11 do check(overlapSeen[i],'Fallback lost constituent '..i)end
page=realPage
local savedSpells=page.lastAlive.spells;page.lastAlive.spells={}
for i=1,12 do page.lastAlive.spells[i]={spellID=500+i,name='Shelf '..i,observedAt=99,cooldown='inactive',category='minor'}end
U:ShowLast();hover(2);check(popup.guide.points[1][5]< -130 and popup.guide.points[1][5]-popup.guide.height==popup.graphBase.points[1][5],'Wrapped shelf left guide crossing its icons')
page.lastAlive.spells=savedSpells
U:ShowLast();U:OpenShare();local open=button('OPEN CHAT');check(open,'Live share absent')
local composerCalls=0;C_ChatInfo.InChatMessagingLockdown=function()return false end;C_SocialRestrictions={CanSendChat=function()return true end}
local box={SetAttribute=function(self,k,v)self[k]=v end};ChatFrame_OpenChat=function()composerCalls=composerCalls+1 end;ChatEdit_GetActiveWindow=function()return box end;ChatEdit_UpdateHeader=function()end
U:Preview();open:Fire('OnClick');check(composerCalls==0,'Stale composer callback acted in Preview')
U:ShowLast();U:OpenBell();button('ENABLE'):Fire('OnClick');check(db.personalTools.consumableReminder,'Explicit live reminder confirmation failed')
RA.PersonalTools:SetOption('consumableReminder',false)
db.deathRecap.autoOpen=true;RA:FireCallback('DEATH_RECAP_CHANGED','death');check(popup:IsShown(),'Auto popup missing')
popup:Hide();check(not popup.selected,'Native hide did not clear private selected context');RA:FireCallback('DEATH_RECAP_CHANGED','native');check(not popup:IsShown(),'Late data reopened closed popup')
U:ShowLast();RA:FireCallback('DEATH_RECAP_CHANGED','life');check(not popup:IsShown()and page==beforePage,'Life event discarded history or kept popup')
db.deathRecap.autoOpen=false;U:ShowLast();RA:FireCallback('DEATH_RECAP_CHANGED','death');check(not popup:IsShown(),'AutoopenOFF retained popup')
local ok=R:PrepareShare('WHISPER','',page);check(not ok and composerCalls==0,'Blank recipient accepted')
ok=R:PrepareShare('WHISPER','Friend-Realm',page);check(ok and composerCalls==1 and box.tellTarget=='Friend-Realm','Native composer target wrong')
C_ChatInfo.InChatMessagingLockdown=function()return true end;check(not R:PrepareShare('SAY',nil,page)and composerCalls==1,'Chat lockdown bypassed')
check(sent==0 and talentReads==0 and inspectCalls==0,'UI sent/inspected raid')
cleanErrors();nativePrint('PASS: '..checks..' actual Death Log selection/group/shelf/preview/Journal/lifecycle assertions (offline; native acceptance pending)')
]=]
assert(loadstring(source,'death-log-ui-fixture'))()
