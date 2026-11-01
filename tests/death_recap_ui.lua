-- Actual modules and native-region callbacks; offline decisions, not WoW pixels.
local f=assert(io.open('tests/hub.lua'));local source=f:read('*a');f:close()
source=source:sub(1,assert(source:find('check(db.schemaVersion == 19',1,true))-1)
source=source..[=[
function methods:GetScript(name)return self.scripts[name]end
function methods:SetAlpha(v)check(type(v)=='number'and v==v and v>=0 and v<=1,'Invalid native alpha');self.alpha=v end
function methods:SetVertexColor(r,g,b)self.rgb={r,g,b}end
function methods:SetTextColor(...)self.textColor={...}end
function methods:SetAtlas(atlas)self.atlas=atlas end
function methods:CreateLine()return object('Line',nil,self)end
function methods:SetThickness(value)self.thickness=value end
function methods:SetStartPoint(...)self.start={...}end
function methods:SetEndPoint(...)self.finish={...}end
function methods:SetFrameLevel(value)self.level=value end
function methods:SetClipsChildren(value)self.clips=value end
-- A finite-height model reproduces the native ellipsis contract. This is
-- drawing-input coverage, not a replacement for the client screenshots.
function methods:SetWordWrap(value)self.wordWrap=value end
function methods:SetNonSpaceWrap(value)self.nonSpaceWrap=value end
function methods:SetMaxLines(value)self.maxLines=value end
function methods:SetFrameStrata(value)self.strata=value end
function methods:GetFrameStrata()return self.strata or(self.parent and self.parent:GetFrameStrata())or'MEDIUM'end
function methods:GetFrameLevel()return self.level or(self.parent and self.parent:GetFrameLevel()+1)or 0 end
function methods:EnableMouse(value)self.mouseEnabled=value end
function methods:SetTextInsets(...)self.textInsets={...}end
function methods:SetJustifyH(value)self.justifyH=value end
function methods:GetUnboundedStringWidth()
 local width=0;for line in ((self.text or'')..'\n'):gmatch('(.-)\n')do width=math.max(width,#line*6)end;return width
end
function methods:GetStringHeight()
 local natural=0;local width=self.width or 0
 for line in ((self.text or'')..'\n'):gmatch('(.-)\n')do
  natural=natural+((self.wordWrap and width>0)and math.max(1,math.ceil(#line*6/width))or 1)*(self.fontSize or 10)
 end
 if self.maxLines and self.maxLines>0 then natural=math.min(natural,self.maxLines*(self.fontSize or 10))end
 self.measuredWithHeight=self.height or 0;self.naturalWrappedHeight=natural
 return(self.height and self.height>0)and math.min(self.height,natural)or natural
end
GameTooltip:SetFrameStrata('TOOLTIP')
local nativeCreateFrame=CreateFrame
CreateFrame=function(kind,name,parent,template)local o=nativeCreateFrame(kind,name,parent);o.template=template;return o end
function methods:SetColorTexture(...)self.color={...}end
function methods:SetDrawLayer(value)self.drawLayer=value end
function methods:EnableMouseWheel(v)self.wheel=v end
function methods:GetValue()error('Historical UI read back a native bar value')end
local tooltipSpell,tooltipItem,tooltipLines=nil,nil,{}
function GameTooltip:SetSpellByID(id)tooltipSpell=id;tooltipItem=nil;self.nativeDescription='Native spell description '..id end
function GameTooltip:SetItemByID(id)tooltipItem=id;tooltipSpell=nil;self.nativeDescription='Native item description '..id end
function GameTooltip:SetOwner(owner,mode)self.owner,self.anchorMode=owner,mode end
function GameTooltip:GetOwner()return self.owner end
function GameTooltip:AddLine()error('Recap facts appended to native tooltip')end
local priorVisualText=RA.SetVisualText
function RA:SetVisualText(region,value)
 local popup=named.RCPArsenalDeathRecap
 if popup and popup.tooltipRecap and(region.parent==popup.tooltipRecap or region.parent==popup.tooltipRecap.body)then tooltipLines[#tooltipLines+1]=value end
 return priorVisualText(self,region,value)
end
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
check(popup.title.text=='Death Log'and popup.width==880 and popup.height>=360,'Composition lost Death Log hierarchy')
local function NoHealthPlot()
 check(not popup.graphBase and not popup.graphLabel and not popup.graphHelp and not popup.graphContext and not popup.healthPoint and not popup.pointPercent,'Removed health plot or sample marker returned')
 check(not popup.absorb and not popup.absorbLabel and popup.healthPanel.healAbsorb==nil,'Shield absorption or healing debt contributed to selected health')
end
NoHealthPlot()
check(popup.shelf.text=='CDs'and popup.shelfSource=='Last recorded check'and popup.shelfAge.text==''and not popup.shelfAge:IsShown(),'Real shelf lost check provenance or retained visible age text')
check(popup.selected.nativeIndex==1 and popup.healthPanel.selectedHP==0 and popup.healthBar:IsShown(),'Initial fatal health selection mismatch')
check(popup.death:IsShown()and popup.healthContext.text:find('Killing blow',1,true),'Fatal selection lost its exact death label')
check(not button('DETAILS ›')and not button('Grouped')and not button('Individual'),'Unapproved controls appeared')
local foundOld,foundStock,foundHold=false,false,false
for _,b in ipairs(shelves())do tooltipLines={};tooltipSpell=nil;b:Fire('OnEnter');local help=table.concat(tooltipLines,' ')
 check(b.statusBadge and #b.statusLines==2 and b.info:IsShown()==(b.recordedState==nil),'Recorded-state badge lost its drawn/text visibility contract')
 for _,line in ipairs(b.statusLines)do check(line:IsShown()==(b.recordedState~=nil),'Proven state glyph was hidden or unknown state acquired a check/cross')end
 if tooltipSpell==235450 then foundOld=true;check(b.recordedState==nil and b.info.text=='?'and b.icon.rgb[1]==.55 and (help:find('not recorded',1,true)or help:find('not confirmed',1,true))and not help:find('Available when checked',1,true)and help:find('Checked 45.0s',1,true),'Unknown charge availability became ready or erased the independent inactive fact/age')end
 if tooltipItem==5512 then foundStock=true;check(b.recordedState==true and b.info.text=='✓'and b.icon.rgb[1]==1 and help:find('Carried: 1',1,true)and help:find('Uses left: 1',1,true),'Old cache/fresh stock or generic unusability erased cooldown fact')end
 if tooltipSpell==342245 then
 for _,line in ipairs(b.statusLines)do check(line.color[1]==RA.Theme.Colors.danger[1]and line.color[2]==RA.Theme.Colors.danger[2]and line.color[3]==RA.Theme.Colors.danger[3]and line.thickness==2,'Confirmed unavailable cross is not clearly red')end
 check(b.statusLines[1].start[3]==4 and b.statusLines[1].finish[3]==12 and b.statusLines[2].start[3]==12 and b.statusLines[2].finish[3]==4,'Unavailable badge strokes do not form an X')
 foundHold=true;check(b.recordedState==false and b.info.text=='×'and b.icon.rgb[1]==.4 and b.icon.alpha==1,'On hold state not precise static dim')end
end
check(foundOld and foundStock and foundHold,'Known shelf rows omitted')
local grouped=hover(2);check(#grouped.group.rows==2,'Confirmed same-source burst not grouped')
tooltipLines={};grouped:Fire('OnEnter');check(table.concat(tooltipLines,' '):find('2 hits',1,true),'Group moment not explicit')
local groupFocusX=popup.guide.points[1][4];local groupArtwork=grouped.icon.texture
grouped:Fire('OnMouseWheel',-1);check(grouped.group.rows[grouped.member].nativeIndex==3 and popup.selected.nativeIndex==3 and popup.healthPanel.selectedHP==80000 and grouped.icon.texture==groupArtwork and popup.guide.points[1][4]==groupFocusX and groupFocusX==grouped.group.iconX,'Member detail did not select exact HP or changed fixed cluster artwork/position')
NoHealthPlot()
check(popup.hp.text=='80000 / 100000'and popup.percent.text=='80%'and not popup.healing:IsShown(),'Selected member health lost its raw denominator or acquired healing')
check(grouped.amountTarget and grouped.amountTarget:IsVisible(),'Amount has no actual hover/wheel target');grouped.amountTarget:Fire('OnEnter')
local click=grouped:GetScript('OnClick');click();check(popup.selected.nativeIndex==3,'Journal click changed selected member')
hover(4);RA:FireCallback('ACCENT_THEME_CHANGED');for _,b in ipairs(hits())do if b.group.spellID==123 then grouped=b end end;grouped:Fire('OnEnter');check(popup.selected.nativeIndex==3 and grouped.group.rows[grouped.member].nativeIndex==3,'Redraw forgot selected member/detail')
local staleClick=grouped:GetScript('OnClick');RA:FireCallback('ACCENT_THEME_CHANGED');staleClick();check(popup.selected.nativeIndex==3,'Stale render action changed selection')
-- Scrub is bounded pointer input while hovering only; stationary pointer cannot
-- undo wheel choice. No re-grouping or periodic capture is attached to it.
local function timelineX(time)return 48+(time-popup.timeDomain.first)/(popup.timeDomain.last-popup.timeDomain.first)*784 end
local x=300+timelineX(-4.5);GetCursorPosition=function()return x,400 end
grouped.span:Fire('OnEnter');check(popup.selected.nativeIndex==2,'Span scrub missed exact nearest event')
grouped.span:Fire('OnMouseWheel',-1);grouped.span:Fire('OnUpdate');check(popup.selected.nativeIndex==3 and grouped.group.rows[grouped.member].nativeIndex==3,'Stationary scrub undid exact selected member')
x=x+32;grouped.span:Fire('OnUpdate');grouped.span:Fire('OnLeave');check(grouped.span:GetScript('OnUpdate')==nil,'Pointer tracker survived leave')
local beforeFrames,beforeTimers,beforeGroups=#objects,#timers,groupCalls
for i=1,50 do hover(2);hover(3)end
check(#objects==beforeFrames and #timers==beforeTimers and groupCalls==beforeGroups,'Hover allocated or regrouped')
local fatal=page.native.rows[4];fatal.nativeOffset=-1;page.native.rows[5]={nativeIndex=5,nativeOffset=0,spellID=126,kind='unknown'}
U:ShowLast();check(popup.ticks[6].text=='0s'and popup.death:IsShown()and popup.death.points[1][4]==timelineX(-1) and popup.fight.text=='Fight 1:40','Latest native time mislabeled as Death or clocks conflated')
fatal.nativeOffset=0;page.native.rows[5]=nil;U:ShowLast()
-- Header identity comes only from the frozen page. Its static class palette
-- and measured name width must not turn historical rendering into live reads.
do
 local oldName,oldRealm,oldClass=page.playerName,page.playerRealm,page.class
 local oldUnitName,oldFullName,oldUnitClass,oldClassAPI,oldPalette=UnitName,UnitFullName,UnitClass,C_ClassColor,RAID_CLASS_COLORS
 local reads=0;local function NoIdentityRead()reads=reads+1;error('Historical UI queried live identity')end
 UnitName,UnitFullName,UnitClass=NoIdentityRead,NoIdentityRead,NoIdentityRead;C_ClassColor={GetClassColor=NoIdentityRead}
 RAID_CLASS_COLORS={MAGE={r=.25,g=.75,b=1},WARRIOR={r=.75,g=.5,b=.25},BOGUS={r=1,g=0,b=0}}
 local function Color(r,g,b)
  return popup.playerName.textColor[1]==r and popup.playerName.textColor[2]==g and popup.playerName.textColor[3]==b
 end
 local function Neutral()return Color(RA.Theme.Colors.text[1],RA.Theme.Colors.text[2],RA.Theme.Colors.text[3])end
 page.playerName,page.playerRealm,page.class='Jímfro','CapturedRealm','MAGE';U:ShowLast()
 check(popup.playerName:IsShown()and popup.playerName.text=='Jímfro'and popup.capturedFullName=='Jímfro-CapturedRealm'and Color(.25,.75,1),'Header omitted captured name/realm or ignored its captured class color')
 check(popup.playerName.fontSize==14 and popup.playerName.points[1][4]==174 and popup.playerName.points[1][5]==-25 and popup.playerName.maxLines==1 and not popup.playerName.wordWrap and popup.title.fontSize==24,'Captured name changed title hierarchy or one-line geometry')
 check(popup.playerName.width==popup.playerName:GetUnboundedStringWidth()and popup.playerName.width<280 and popup.info.points[1][4]==174+popup.playerName.width+8 and popup.info.points[1][4]+popup.info.width<550,'Short name reserved the full width or collided with header controls')
 tooltipLines={};popup.info:Fire('OnEnter');check(table.concat(tooltipLines,' '):find('Player: Jímfro-CapturedRealm',1,true),'Info hover omitted full captured identity');popup.info:Fire('OnLeave')
 page.playerName=string.rep('LongName',16);page.playerRealm='LongRealm';U:ShowLast()
 check(popup.playerName.width==280 and popup.playerName.text==page.playerName and popup.info.points[1][4]==462 and popup.info.points[1][4]+popup.info.width<550,'Long name wrapped, lost full text or escaped its cap')
 tooltipLines={};popup.info:Fire('OnEnter');check(table.concat(tooltipLines,' '):find(page.playerName..'-LongRealm',1,true),'Long-name ellipsis discarded full identity from help');popup.info:Fire('OnLeave')
 page.playerName='UnknownClass';page.class='BOGUS';U:ShowLast();check(Neutral(),'Unknown captured class borrowed a palette entry')
 page.class='WARRIOR';U:ShowLast();check(Color(.75,.5,.25),'Captured class change retained previous name color')
 RAID_CLASS_COLORS.WARRIOR={r=2,g=.5,b=.25};U:Render();check(Neutral(),'Out-of-range static palette was accepted')
 local hidden=setmetatable({},{__tostring=function()error('Secret header identity stringified')end});local public=issecretvalue
 issecretvalue=function(value)return rawequal(value,hidden)or public(value)end
 for _,bad in ipairs({false,hidden,'',string.rep('X',129),'Bad|r','Bad\nName'})do
  page.playerName=bad;U:ShowLast();check(not popup.playerName:IsShown()and popup.playerName.text==''and popup.capturedFullName==nil and popup.info.points[1][4]==174,'Invalid legacy name became visible or borrowed another identity')
 end
 page.playerName='ValidName';page.playerRealm=hidden;page.class=hidden;U:ShowLast()
 check(popup.playerName.text=='ValidName'and popup.capturedFullName=='ValidName'and Neutral(),'Secret realm/class erased public name or leaked into header')
 issecretvalue=public;page.playerName,page.playerRealm,page.class=nil,nil,'MAGE';U:ShowLast()
 check(not popup.playerName:IsShown()and popup.capturedFullName==nil and popup.info.points[1][4]==174,'Missing legacy identity retained stale name or changed the existing header')
 U:Preview();check(popup.playerName.text=='Example Mage'and popup.capturedFullName=='Example Mage-Example Realm'and popup.coverage:IsShown()and Color(.25,.75,1),'Preview identity borrowed the real page or lost fictional class/name')
 check(popup.coverage.points[1][4]==174+popup.playerName.width+8 and popup.info.points[1][4]==popup.coverage.points[1][4]+popup.coverage.width+8 and popup.info.points[1][4]+popup.info.width<550,'Preview label/name/info exceeded the shared header budget')
 U:OpenShare();local samplePage=popup.shareChooser.page;popup.shareChooser.close:Fire('OnClick');samplePage.playerName,samplePage.playerRealm=nil,nil;U:Render()
 check(not popup.playerName:IsShown()and popup.capturedFullName==nil and popup.coverage:IsShown()and popup.coverage.points[1][4]==174 and popup.info.points[1][4]==218,'Missing sample identity erased Preview or retained the named header layout')
 U:ShowLast();check(not popup.playerName:IsShown()and not popup.coverage:IsShown()and popup.capturedFullName==nil,'Preview identity/color leaked into a missing-name live page')
 check(reads==0,'Historical header issued a current-unit or live class-color query')
 UnitName,UnitFullName,UnitClass,C_ClassColor,RAID_CLASS_COLORS=oldUnitName,oldFullName,oldUnitClass,oldClassAPI,oldPalette
 page.playerName,page.playerRealm,page.class=oldName,oldRealm,oldClass
end
-- Preview identity and complete synthetic selected-time display.
local beforePage=page;local diagnostics=R:GetDiagnostics();local prefs={};for k,v in pairs(db.personalTools)do prefs[k]=v end
U:OpenShare();local liveForm=popup.shareChooser;local staleLiveSend=liveForm.channels.WHISPER:GetScript('OnClick')
local reads=pageReads;U:Preview();check(pageReads==reads,'Preview read retained real page')
check(popup.coverage:IsShown()and popup.coverage.text=='Preview'and not popup.context and popup.contextText=='Arcane Mage · The Coiled Altar · Mythic','Hidden context or Preview label incorrect')
check(popup.playerName.text=='Example Mage'and popup.coverage.points[1][4]==174+popup.playerName.width+8 and popup.info.points[1][4]==popup.coverage.points[1][4]+popup.coverage.width+8 and popup.info.points[1][5]==-23,'Preview info target did not follow its captured name and sample label')
tooltipLines={};popup.info:Fire('OnEnter');local contextHelp=table.concat(tooltipLines,' ');check(contextHelp:find('Arcane Mage · The Coiled Altar · Mythic',1,true)and contextHelp:find('Fictional sample',1,true),'Hidden Preview context was lost from help');popup.info:Fire('OnLeave')
check(popup.selected.nativeIndex==1 and popup.healthPanel.selectedHP==0 and popup.percent.text=='0%'and not popup.healing:IsShown(),'Preview did not default to recorded death')
check(popup.shelf.text=='CDs'and popup.shelfSource=='Preview death snapshot','Example shelf not tied to exact selected moment')
check(not liveForm:IsShown(),'Preview inherited live report dialog');staleLiveSend(liveForm.channels.WHISPER)
for k,v in pairs(prefs)do check(db.personalTools[k]==v,'Preview changed preferences')end
check(page==beforePage and R:GetDiagnostics().nativeReads==diagnostics.nativeReads,'Preview changed recorder')
U:OpenShare();check(popup.shareChooser:IsShown(),'Private Preview report action missing');popup.shareChooser.close:Fire('OnClick')
popup.healTargets[1]:Fire('OnEnter');check(popup.selected.nativeIndex==101 and popup.healthPanel.selectedHP==336000 and popup.healthPanel.effectiveHealing==9000 and popup.healing:IsShown()and popup.shelfSource=='Preview death snapshot','Preview heal did not select its own validated HP/healing segment')
for _,obj in ipairs(objects)do if obj.parent==popup and obj.icon and obj.width==30 and obj:IsVisible()then obj:Fire('OnEnter');check(popup.selected.nativeIndex==101,'Defensive hover changed selected health');break end end
RA:FireCallback('ACCENT_THEME_CHANGED');check(popup.guide:IsShown(),'Support selection disappeared on redraw')
local healerArtwork=0
for _,b in ipairs(popup.healTargets)do check(not b.icon and b.label.text:sub(1,1)=='+','Healing regained large artwork')end
-- Focused alpha31 presentation evidence. This proves drawing inputs/layers and
-- decisions; only a native screenshot can confirm visible amber/ring pixels.
U:Preview();local sever=hover(8)
check(popup.hp.text=='128000 / 400000'and popup.healthPanel.selectedHP==128000 and popup.percent.text=='32%','Selected damage HP changed')
NoHealthPlot();check(not popup.healing:IsShown()and popup.healthPanel.effectiveHealing==nil,'Damage or debt fabricated effective healing')
local dashed=0;for _,t in ipairs(popup.guide.dashes)do if t:IsShown()then dashed=dashed+1;check(t.width==1 and t.height<=5,'Guide became solid')end end
check(dashed>1 and dashed<=96,'Guide dashes not bounded')
check(sever.selectedBorder:IsShown()and not sever.countBadge:IsShown(),'Singleton selected/count treatment wrong')
local groupedPreview
for _,b in ipairs(hits())do if #b.group.rows>1 then groupedPreview=b;break end end
check(groupedPreview.countBadge:IsShown()and groupedPreview.countBadge.width>=24 and groupedPreview.countText.fontSize==11,'Count backing/legibility missing')
local absorbed=hover(5);check(not absorbed.absorbBadge,'Damage icon retained a shield badge')
local blueCount=0
for _,marker in ipairs(popup.supportMarkers)do if marker:IsShown()and marker.entry.kind=='absorbed'then
 blueCount=blueCount+1;check(marker.entry.amount==20000 and marker.label.text=='+20k'and marker.timeX==48+1.4/5*784 and marker.color[1]==.36 and marker.color[2]==.70 and marker.color[3]==1,'Absorbed marker changed amount/time or blue identity')
 local markerSelected,markerHP=popup.selected,popup.healthPanel.selectedHP;tooltipSpell=nil;tooltipLines={};marker:Fire('OnEnter');local shieldHelp=table.concat(tooltipLines,' ')
 check(not GameTooltip:IsShown()and tooltipSpell==nil and popup.tooltipRecap.lines[1].text=='Shield absorption · 1 hit'and shieldHelp:find('Total absorbed: 20,000',1,true)and shieldHelp:find('Shield source not recorded.',1,true)and not shieldHelp:find('healing',1,true)and not shieldHelp:find('remaining',1,true),'Shield help invented healing, capacity or source identity')
 check(popup.selected==markerSelected and popup.healthPanel.selectedHP==markerHP and #popup.healTargets==2,'Absorption hover changed selected health or became healing');marker:Fire('OnLeave')
end end
check(blueCount==1,'Recorded absorption was omitted or counted twice')
local function cross(x,first,last,r)return x>r.left-2 and x<r.right+2 and first<r.bottom+2 and last>r.top-2 end
for _,b in ipairs(hits())do for _,stem in ipairs(b.stems or{})do if stem:IsShown()then
 local x,y=stem.points[1][4],-stem.points[1][5]
 for _,r in ipairs(popup.textExclusions)do check(not cross(x,y,y+stem.height,r),'Connector crosses text/amount target')end
end end end
for _,t in ipairs(popup.guide.dashes)do if t:IsShown()then
 local x=popup.guide.points[1][4];local y=-popup.guide.points[1][5]-t.points[1][5]
 for _,r in ipairs(popup.textExclusions)do check(not cross(x,y,y+t.height,r),'Selected dash crosses text')end
end end
local supportStems=0
for _,obj in ipairs(objects)do if obj.parent==popup and obj.icon and obj.width==30 and obj:IsVisible()then check(obj.activationStems and #obj.activationStems>0,'Aligned activation stem missing');supportStems=supportStems+1 end end
check(supportStems==2 and #popup.healTargets==2,'Preview support connections missing')
tooltipLines={};hover(8);local single=table.concat(tooltipLines,' ')
check(tooltipSpell==1299684 and GameTooltip.nativeDescription=='Native spell description 1299684','Native spell tooltip discarded')
check(single:find('51k damage',1,true)and not single:find('−2.30s',1,true)and not single:find('1/1',1,true)and not single:find('combined',1,true)and not single:find('fictional',1,true),'Singleton tooltip retained boilerplate')
tooltipLines={};popup.healTargets[1]:Fire('OnEnter');local healHelp=table.concat(tooltipLines,' ')
check(tooltipSpell==2061 and healHelp:find('+9k healing',1,true)and not healHelp:find('−4.20s',1,true)and healHelp:find('Healer:',1,true)and not healHelp:find('Example healing',1,true),'Healing tooltip lost spell-specific native identity/summary')
check(popup.selected.nativeIndex==101 and popup.hp.text=='336000 / 400000'and popup.healing:IsShown()and popup.healthPanel.effectiveHealing==9000,'Preview heal did not select its own raw HP and effective healing')
local retained=popup.selected;popup.healTargets[1]:Fire('OnLeave');check(popup.selected==retained and popup.healthBar:IsShown(),'Leave reset selection')
check(not popup.bell and not popup.reminder.label and not U.OpenBell and popup.reminder:IsEnabled()and popup.share:IsEnabled(),'Unified Preview reminder action unavailable or obsolete bell remained')
tooltipLines={};popup.share:Fire('OnEnter');check(table.concat(tooltipLines,' '):find('Open this report in chat',1,true),'Report help is unclear')
-- Exercise the actual placement callback with measured mock UI rectangles.
local rects={};local oldLeft,oldBottom,oldScale=methods.GetLeft,methods.GetBottom,methods.GetEffectiveScale
function methods:GetLeft()return rects[self]and rects[self].left or oldLeft(self)end
function methods:GetBottom()return rects[self]and rects[self].bottom or oldBottom(self)end
function methods:GetEffectiveScale()return rects[self]and rects[self].scale or oldScale(self)end
local cases=0
local function area(a,b)return math.max(0,math.min(a.right,b.right)-math.max(a.left,b.left))*math.max(0,math.min(a.top,b.top)-math.max(a.bottom,b.bottom))end
for _,parentScale in ipairs({.8,1,1.25})do for _,panelScale in ipairs({.64,.8,1})do
 local sw,sh=1920*parentScale,1080*parentScale
 UIParent:SetSize(1920,1080);rects[UIParent]={left=0,bottom=0,scale=parentScale}
 for _,corner in ipairs({'center','left','right','top','bottom'})do
  local pw,ph=popup.width*panelScale,popup.height*panelScale
  local px,py=(sw-pw)/2,(sh-ph)/2
  if corner=='left'then px=12 elseif corner=='right'then px=sw-pw-12 elseif corner=='top'then py=sh-ph-12 elseif corner=='bottom'then py=12 end
  rects[popup]={left=px/panelScale,bottom=py/panelScale,scale=panelScale}
  local b=sever;rects[b]={left=(px+(b.group.iconX-23)*panelScale)/panelScale,bottom=(py+ph-(b.damageY+46)*panelScale)/panelScale,scale=panelScale}
  GameTooltip:SetSize(280,260);rects[GameTooltip]={left=0,bottom=0,scale=.9}
  b:Fire('OnEnter');local r=popup.tooltipPlacement
  check(r and r.left>=12 and r.bottom>=12 and r.right<=sw-12 and r.top<=sh-12,'Tooltip escaped measured screen at non-unit scale')
  local panel={left=px,right=px+pw,bottom=py,top=py+ph}
  if r.mode=='outside'then check(area(r,panel)==0,'Claimed outside tooltip overlaps recap')end
  local target={left=px+(b.group.iconX-23)*panelScale,right=px+(b.group.iconX+23)*panelScale,bottom=py+ph-(b.damageY+46)*panelScale,top=py+ph-b.damageY*panelScale}
  check(area(r,target)==0,'Tooltip covers hovered event despite room')
  local point=GameTooltip.points[#GameTooltip.points];check(math.abs(point[4]*.9-r.left)<.001 and math.abs(point[5]*.9-(r.top-GameTooltip.height*.9))<.001,'Tooltip offsets mixed effective scales')
  GameTooltip:SetSize(320,300);GameTooltip:Fire('OnSizeChanged');check(math.abs(popup.tooltipPlacement.right-popup.tooltipPlacement.left-288)<.001,'Native tooltip size change left stale placement')
  b:Fire('OnLeave');check(not GameTooltip:IsShown()and popup.tooltipPlacement==nil,'Tooltip ownership/placement survived leave')
  cases=cases+1
 end
end end
check(cases==45 and not GameTooltip:GetScript('OnUpdate'),'Placement added polling or omitted scale/edge cases')
rects={};methods.GetLeft,methods.GetBottom,methods.GetEffectiveScale=oldLeft,oldBottom,oldScale;UIParent:SetSize(0,0)
U:Preview()
-- Another UI may acquire the shared native tooltip before recap cleanup runs.
local foreign=CreateFrame('Frame',nil,UIParent)
for _,operation in ipairs({'leave','hide','render'})do
 local b=hover(8)
 GameTooltip:SetOwner(foreign,'ANCHOR_RIGHT');GameTooltip:SetText('Foreign tooltip');GameTooltip:Show()
 local beforePoint=GameTooltip.points[#GameTooltip.points];GameTooltip:Fire('OnSizeChanged')
 check(GameTooltip.points[#GameTooltip.points]==beforePoint,'Resize moved another owner tooltip')
 if operation=='leave'then b:Fire('OnLeave')elseif operation=='hide'then U:Hide()else U:Render()end
 check(GameTooltip:IsShown()and GameTooltip:GetOwner()==foreign,'Recap '..operation..' hid another owner tooltip')
 GameTooltip:Hide();U:Preview()
end
local own=hover(8);own:Fire('OnLeave');check(not GameTooltip:IsShown(),'Recap leave retained its own tooltip')
local staleTargets={sever,sever.amountTarget}
for _,b in ipairs(hits())do if b.span:IsShown()then staleTargets[#staleTargets+1]=b.span;break end end
check(#staleTargets==3,'Stale leave fixture omitted span target')
for _,older in ipairs(staleTargets)do
 older:Fire('OnEnter');local newer=popup.healTargets[1];newer:Fire('OnEnter')
 older:Fire('OnLeave')
 check(GameTooltip:IsShown()and GameTooltip:GetOwner()==newer,'Stale leave hid a newer recap tooltip')
 newer:Fire('OnLeave');check(not GameTooltip:IsShown(),'Stale leave cleared newer owner tracking')
end
local copyPage=page;page={id=13,diedAt=100,casts={},native={recapID=4,rows={}}}
U:ShowLast();check(popup.empty:IsShown()and not popup.context and not popup.health and popup.info.points[1][4]==174 and popup.info.points[1][5]==-23,'Empty live log restored labels or lost anchored help')
for i=1,20 do page.native.rows[i]={nativeIndex=i,nativeOffset=-1+i*.01,spellID=500+i,kind=i<=2 and 'damage' or 'unknown',amount=i==2 and 200 or nil}end
U:ShowLast();local unknownGroup;local unknownCount=0
for _,b in ipairs(hits())do for _,row in ipairs(b.group.rows)do if row.kind=='unknown'then
 unknownCount=unknownCount+1;unknownGroup=b;check(#b.group.rows==1,'Unknown event was absorbed into a damage cluster')
end end end
check(unknownGroup and unknownCount==18,'Unknown-event density fixture lost original receipts')
tooltipLines={};unknownGroup:Fire('OnEnter');local unknownCopy=table.concat(tooltipLines,' ')
check(tooltipSpell==unknownGroup.group.rows[1].spellID and unknownCopy:find('Amount unavailable',1,true)and not unknownCopy:find(' damage',1,true)and not unknownCopy:find(' hits',1,true),'Unknown event kinds became damage hits: '..unknownCopy)
page.native.rows[1].kind='unknown';U:ShowLast();tooltipLines={};hover(1)
check(popup.healthContext.text:find('Death record',1,true)and not popup.healthContext.text:find('Killing blow',1,true)and not table.concat(tooltipLines,' '):find('Killing blow',1,true),'Unknown fatal event acquired a confirmed damage/killing-blow claim')
-- Mixed sources/spells cluster by raw time. Artwork stays on the largest hit,
-- while the exact fatal member and each original member retain their own HP.
do
 local clusterRows={
  {nativeIndex=3,nativeOffset=-.4,spellID=731,name='Earlier largest',kind='damage',amount=50001,recordedHP=60000,sourceName='Visible caster',hideCaster=false},
  {nativeIndex=2,nativeOffset=-.2,spellID=732,name='Middle hit',kind='damage',amount=15002,recordedHP=45000,sourceName='Hidden caster',hideCaster=true},
  {nativeIndex=1,nativeOffset=0,spellID=733,name='Exact fatal',kind='damage',amount=10003,recordedHP=1234,sourceName='Restricted caster',hideCasterStatus='restricted'}}
 page={id=14,diedAt=100,casts={},native={recapID=5,recapMaxHealth=100000,rows=clusterRows}}
 U:ShowLast();local cluster=hits()[1]
 check(#hits()==1 and #cluster.group.rows==3 and cluster.group.representative==clusterRows[1]and cluster.group.fatalRow==clusterRows[3],'Half-second mixed cluster lost largest artwork or exact fatal member')
 check(popup.selected==clusterRows[3]and popup.hp.text=='1234 / 100000'and popup.percent.text=='1%','Fatal selection substituted largest-hit HP or invented zero health')
 local art=cluster.icon.texture;tooltipLines={};tooltipSpell=nil;cluster:Fire('OnEnter');local detail=table.concat(tooltipLines,' ')
 check(popup.selected==clusterRows[3]and popup.hp.text=='1234 / 100000'and cluster.group.rows[cluster.member]==clusterRows[3]and cluster.icon.texture==art and tooltipSpell==733,'First actual cluster hover replaced fatal receipt with largest-hit HP/spell')
 check(detail:find('3 hits',1,true)and detail:find('Contains killing blow',1,true),'Mixed fatal hover lost cluster or killing-blow detail')
 for _,fact in ipairs({'-0.4s · Earlier largest · 50,001 · Visible caster','-0.2s · Middle hit · 15,002','0.0s · Exact fatal · 10,003 · Killing blow · Health shown'})do
  check(detail:find(fact,1,true),'Cluster detail lost exact original receipt: '..fact)
 end
 check(not detail:find('Hidden caster',1,true)and not detail:find('Restricted caster',1,true),'Mixed cluster exposed a hidden or restricted source')
 cluster:Fire('OnMouseWheel',-1)
 check(popup.selected==clusterRows[1]and popup.hp.text=='60000 / 100000'and tooltipSpell==731 and cluster.icon.texture==art,'Cluster wheel failed to wrap to original HP/native spell while preserving artwork')
 RA:FireCallback('ACCENT_THEME_CHANGED');cluster=hits()[1];tooltipSpell=nil;cluster:Fire('OnEnter')
 check(popup.selected==clusterRows[1]and cluster.group.rows[cluster.member]==clusterRows[1]and popup.hp.text=='60000 / 100000'and tooltipSpell==731 and cluster.icon.texture==art,'Redraw discarded the inspected cluster member or changed fixed artwork')
 U:ShowLast();cluster=hits()[1];tooltipSpell=nil;cluster.amountTarget:Fire('OnEnter')
 check(popup.selected==clusterRows[3]and cluster.group.rows[cluster.member]==clusterRows[3]and popup.hp.text=='1234 / 100000'and tooltipSpell==733 and cluster.icon.texture==art,'Reopen or first amount hover failed to reset to the exact fatal receipt')
 cluster.amountTarget:Fire('OnMouseWheel',-1)
 check(popup.selected==clusterRows[1]and popup.hp.text=='60000 / 100000'and tooltipSpell==731 and cluster.icon.texture==art,'Amount wheel failed to inspect actual member HP/native spell with fixed artwork')
 U:ShowLast();cluster=hits()[1];tooltipSpell=nil;cluster:Fire('OnEnter')
 check(popup.selected==clusterRows[3]and popup.hp.text=='1234 / 100000'and tooltipSpell==733 and cluster.icon.texture==art,'Reopening retained an earlier inspected member on first icon hover')
end
-- The viewport is presentation-only. Important earlier hits extend it in whole
-- seconds, while outside-window receipts remain in the copy report unchanged.
do
 local domainRows={
  {nativeIndex=5,nativeOffset=-20,spellID=741,name='Historical tail',kind='damage',amount=90000,recordedHP=90000},
  {nativeIndex=4,nativeOffset=-7.4,spellID=742,name='Small old hit',kind='damage',amount=1000,recordedHP=89000},
  {nativeIndex=3,nativeOffset=-6.2,spellID=743,name='Important older hit',kind='damage',amount=21000,recordedHP=68000},
  {nativeIndex=2,nativeOffset=-2,spellID=744,name='Largest recent hit',kind='damage',amount=50000,recordedHP=18000},
  {nativeIndex=1,nativeOffset=0,spellID=745,name='Fatal recent hit',kind='damage',amount=80000,recordedHP=1234}}
 page={id=15,diedAt=100,casts={},native={recapID=6,recapMaxHealth=100000,rows=domainRows}}
 U:ShowLast()
 check(popup.timeDomain.first==-7 and popup.timeDomain.last==0 and popup.viewport.omitted==2,'Eligible older native hit did not extend to the next whole second')
 check(page.native.rows==domainRows and #page.native.rows==5 and domainRows[1].nativeOffset==-20,'Viewport cropped or retimed retained page history')
 local report=assert(R:BuildShareText(page))
 for _,row in ipairs(domainRows)do check(report:find(row.name,1,true),'Full report omitted original history outside the viewport')end
 U:OpenShare();check(popup.shareChooser.copy:GetText()==report,'Visible report chooser copied only viewport events');popup.shareChooser.close:Fire('OnClick')
 tooltipLines={};popup.info:Fire('OnEnter');check(table.concat(tooltipLines,' '):find('2 retained events outside this timeline window; included in the full report',1,true),'Window clipping lost discoverable report disclosure');popup.info:Fire('OnLeave')
 page.native.recapMaxHealth=nil;U:ShowLast();check(popup.timeDomain.first==-5 and popup.viewport.omitted==3,'Unavailable max health did not use the relative important-hit threshold')
 domainRows[3].amount=25000;U:ShowLast();check(popup.timeDomain.first==-7,'Half-largest earlier hit did not extend the window')
 domainRows[3].nativeOffset=-7.2;U:ShowLast();check(popup.timeDomain.first==-8,'Qualifying hit inside the last eight seconds did not extend to eight')
 domainRows[3].nativeOffset=-8.01;U:ShowLast();check(popup.timeDomain.first==-5,'Older-than-eight hit or large fatal hit widened the window')
 check(#page.native.rows==5 and assert(R:BuildShareText(page)):find('Historical tail',1,true),'Repeated viewport updates lost full retained history')
end
page=copyPage;U:Preview()
-- Alpha32 companion tooltip, fixed Preview endpoint and actual reminder switch.
U:Preview();check(popup.selected.nativeIndex==1 and not popup.context and not popup.health,'Removed labels returned or default death changed')
local shelfPositions={};for _,b in ipairs(shelves())do shelfPositions[b]={b.points[1][4],b.points[1][5],b.icon.rgb[1]}end
local h=popup.healTargets[1];h:Fire('OnEnter')
for b,pos in pairs(shelfPositions)do check(b.points[1][4]==pos[1]and b.points[1][5]==pos[2]and b.icon.rgb[1]==pos[3],'Hover reordered/changed death shelf')end
local recap=popup.tooltipRecap
check(recap:IsShown()and recap.width>=220 and recap.width<=360 and recap.lines[1].fontSize==13,'Recap companion sizing/summary incorrect')
check(recap.lines[1].text=='+9k healing'and recap.lines[2].text:find('Healer:',1,true),'Companion lost healing recap facts')
GameTooltip:Fire('OnTooltipCleared');check(recap:IsShown(),'Same-owner native refresh discarded recap facts')
h:Fire('OnLeave');check(not recap:IsShown(),'Companion survived owned leave')
check(popup.reminder.points[1][4]==578 and popup.reminder.points[1][5]==-18 and popup.reminder.width==72 and popup.reminder.height==28,'Reminder compound target moved or widened the header')
check(popup.reminder.icon.parent==popup.reminder and popup.reminder.icon.width==22 and popup.reminder.icon.height==22 and popup.reminder.icon.points[1][1]=='LEFT','Reminder icon is not inside the same click target')
check(popup.reminder.track.parent==popup.reminder and popup.reminder.track.width==40 and popup.reminder.track.height==20 and popup.reminder.track.points[1][1]=='RIGHT'and popup.reminder.knob.width==18,'Existing reminder switch geometry changed')
check(popup.reminder.icon.texture=='Interface\\Icons\\INV_Potion_51','Reminder illustration changed with inventory or uses unverified art')
local previousReminder=db.personalTools.consumableReminder
popup.reminder:Fire('OnClick');check(db.personalTools.consumableReminder~=previousReminder and popup.reminder.enabledSetting==db.personalTools.consumableReminder,'Reminder switch did not change/synchronize actual setting')
RA.PersonalTools:SetOption('consumableReminder',previousReminder);check(popup.reminder.enabledSetting==previousReminder,'External setting did not synchronize switch')
for _,marker in ipairs(popup.supportMarkers)do if marker:IsShown()then for _,stem in ipairs(marker.stems)do if stem:IsShown()then
 local x,y=stem.points[1][4],-stem.points[1][5];for _,r in ipairs(popup.textExclusions)do check(not cross(x,y,y+stem.height,r),'Support connector crossed a label')end
end end end end
U:ShowLast();for _,marker in ipairs(popup.supportMarkers)do check(not marker:IsShown(),'Preview support leaked into real fixture');for _,stem in ipairs(marker.stems)do check(not stem:IsShown(),'Old support stem survived fewer markers')end end
U:Preview()
-- Alpha33: finite-height wrap, one-card help and explicit modal ordering.
local oldSourceName=page.native.rows[1].sourceName
local smallHeight,largeHeight
for i,text in ipairs({'A',string.rep('Long',24),'A',string.rep('X',96)})do
 page.native.rows[1].sourceName=text;U:ShowLast();hover(2)
 local card=popup.tooltipRecap;local sourceRow
 for _,f in ipairs(card.lines)do if f:IsShown()then
  check(f.wordWrap and f.nonSpaceWrap and f.maxLines==0 and f.measuredWithHeight==0,'Pooled row measured with a stale height/wrap constraint')
  check(f.height>=f.naturalWrappedHeight,'Wrapped text exceeds allocated row height')
  if f.text:find('Source:',1,true)then sourceRow=f end
 end end
 check(sourceRow,'Source row disappeared')
 if i==1 then smallHeight=card.height elseif i==2 then largeHeight=card.height;check(largeHeight>smallHeight and sourceRow.height>sourceRow.fontSize,'Long row did not expand after a short row')
 elseif i==3 then check(card.height==smallHeight,'Short replacement did not shrink pooled card')
 else check(card.height==largeHeight,'Long non-space token did not wrap after reuse')end
end
page.native.rows[1].sourceName=oldSourceName;U:Preview()
check(popup.height==360 and popup.supportExtra==0 and popup.fightSlotExtra==0,'Normal Preview retained artificial shelf/support/timer height')
local expectedSlots={590,628,666,704,748,786};local slotCount=0
for _,b in ipairs(shelves())do slotCount=slotCount+1;check(b.points[1][4]==expectedSlots[slotCount]and b.points[1][5]==-76,'Seven fixed CD slots did not stay on one row')end
check(slotCount==6,'Preview did not exclude utility Greater Invisibility')
check(not popup.health and popup.percent.points[1][4]==48 and popup.percent.width==58,'Selected health percentage is not aligned to the bottom timeline')
check(popup.width==880 and popup.healthPanel.points[1][4]==48 and popup.healthPanel.width==784 and popup.hp.points[1][4]==552 and popup.hp.width==280 and popup.hp.justifyH=='RIGHT','Bottom selected health bar/value geometry changed')
check(popup.healthPanel.points[1][5]==-320 and popup.percent.points[1][5]==-290 and popup.hp.points[1][5]==-297 and popup.healthPanel.points[1][4]==popup.rail.points[1][4]and popup.healthPanel.width==popup.rail.width,'Selected health bar is not below and aligned with the timeline')
check(popup.shelf.points[1][4]==550 and popup.shelf.width==28 and popup.shelfAge.text==''and not popup.shelfAge:IsShown(),'CD shelf moved or visible age returned')
NoHealthPlot()
popup.reminder:Fire('OnEnter');check(not GameTooltip:IsShown()and popup.tooltipRecap:IsShown()and popup.tooltipRecap.lines[1].text=='Consumable reminder','Non-spell help is not a single card')
local toggledFrom=db.personalTools.consumableReminder
popup.reminder:Fire('OnClick');check(popup.tooltipRecap.lines[2].text=='Healthstone and healing-potion alerts.'and popup.tooltipRecap.lines[3].text==(db.personalTools.consumableReminder and'On · Click to turn off.'or'Off · Click to turn on.'),'Visible reminder help did not follow the setting')
RA.PersonalTools:SetOption('consumableReminder',toggledFrom)
local function checkModal(form)
 check(form.mouseEnabled and form:GetFrameStrata()=='DIALOG'and popup.actionShield:IsShown()and popup.actionShield.mouseEnabled,'Modal lacks an input barrier')
 for _,o in ipairs(objects)do if under(o,popup)and o~=popup and o~=form and not under(o,form)and not under(o,popup.actionShield)and o:IsVisible()and(o.kind=='Frame'or o.kind=='Button'or o.kind=='StatusBar'or o.kind=='EditBox')then
  check(o:GetFrameLevel()<form:GetFrameLevel(),'Content draws above modal plane')
 end end
 for _,o in ipairs(objects)do if o~=form and under(o,form)and(o.kind=='Button'or o.kind=='EditBox')then check(o:GetFrameLevel()>form:GetFrameLevel(),'Modal control is below its background')end end
end
-- Two-click chooser: opening freezes readable facts and sends nothing.
local chatCalls,chatRestricted,chatPermission,homeGroup,homeRaid,instanceGroup={},false,true,false,false,false
local targetPlayer,targetName,targetRealm,targetGUID=false,nil,nil,nil
LE_PARTY_CATEGORY_HOME,LE_PARTY_CATEGORY_INSTANCE=1,2
C_ChatInfo.InChatMessagingLockdown=function()return chatRestricted end
C_SocialRestrictions={CanSendChat=function()return chatPermission end}
C_ChatInfo.SendChatMessage=function(text,channel,_,target)chatCalls[#chatCalls+1]={text=text,channel=channel,target=target}end
IsInGroup=function(category)return category==2 and instanceGroup or(category==1 and homeGroup)end
IsInRaid=function(category)return category==1 and homeRaid end
UnitIsPlayer=function(unit)return unit=='target'and targetPlayer end
UnitFullName=function(unit)if unit=='target'then return targetName,targetRealm end;return 'Test','Realm'end
UnitGUID=function(unit)return unit=='target'and targetGUID or'Player-1-AAAA'end
local function setTarget(name,guid)
 targetPlayer=name~=nil;targetName,targetRealm,targetGUID=name,name and'Realm'or nil,guid
 event('PLAYER_TARGET_CHANGED')
end
local function choose(form,channel)
 local action=form.channels[channel];action:Fire('OnMouseDown');action:Fire('OnMouseUp');action:Fire('OnClick')
end
hover(8);popup.share:Fire('OnClick');local shareForm=popup.shareChooser;checkModal(shareForm)
check(#chatCalls==0,'Opening chooser submitted chat')
check(not GameTooltip:IsShown()and not popup.tooltipRecap:IsShown(),'Opening share retained old tooltip')
check(not shareForm.copy.template and not shareForm.recipient and not shareForm.send and shareForm.copy.textInsets[1]==10,'Typed recipient/separate Send/default editbox chrome remained')
local fullReport=shareForm.report
check(#fullReport.entries==16 and fullReport.entries[16].kind=='death','Full Preview events/death missing')
check(fullReport.text:find('Arcane Mage',1,true)and fullReport.text:find('The Coiled Altar',1,true)and fullReport.text:find('Mythic',1,true),'Hidden popup context disappeared from the full report')
local expectedTimes={-4.8,-4.6,-4.4,-4.2,-3.6,-3.5,-3.15,-3,-2.8,-2.3,-1.8,-1.3,-1.1,-.9,0,0}
for i,time in ipairs(expectedTimes)do check(fullReport.entries[i].time==time,'Preview report chronology changed')end
local axeCount=0;for _,item in ipairs(fullReport.entries)do if item.line:find('Axegrinder',1,true)then axeCount=axeCount+1 end end
check(axeCount==6 and fullReport.entries[15].line:find('45,000 damage; 19,000 overkill; fatal hit',1,true),'Report collapsed hits or confused inspected hit with fatal')
check(fullReport.entries[5].line:find('20,000 absorbed',1,true)and fullReport.entries[4].line:find('9,000 healing',1,true),'Full report lost support facts')
check(shareForm.width==316 and not shareForm.expanded and not shareForm.reportScroll:IsShown()and not shareForm.scrollbar:IsShown(),'Default share is not a compact chooser')
check(not shareForm.channels.WHISPER:IsEnabled()and not shareForm.channels.PARTY:IsEnabled()and not shareForm.channels.RAID:IsEnabled()and not shareForm.channels.INSTANCE_CHAT:IsShown(),'Unavailable destination looks ready')
check(shareForm.channels.SAY:IsEnabled()and shareForm.channels.SAY.detail.text=='One line per click','SAY fallback is hidden or promises whole-report activation')
check(shareForm.context.text:find(#shareForm.messages..' messages',1,true),'Accurate transport count missing')
check(eventFrame.registered.PLAYER_TARGET_CHANGED,'Open chooser did not subscribe to target changes')
setTarget('Friend','Player-1-ABC123')
check(shareForm.channels.WHISPER:IsEnabled()and shareForm.channels.WHISPER.detail.text=='Friend-Realm','Current player target did not populate Whisper')
shareForm.channels.WHISPER:Fire('OnEnter');check(shareForm.tip:IsShown()and shareForm.tip.text.text=='Friend-Realm','Full target hover missing')
shareForm.channels.WHISPER:Fire('OnLeave');check(not shareForm.tip:IsShown(),'Target hover survived leave')
local savedWhisper=shareForm.channels.WHISPER:GetScript('OnClick')
setTarget('Other','Player-1-ABC124');setTarget('Friend','Player-1-ABC123');savedWhisper(shareForm.channels.WHISPER)
check(#chatCalls==0 and shareForm.status.text:find('Target changed',1,true),'Old target callback sent after target changed away and back')
local longName=string.rep('Long',16);setTarget(longName,'Player-1-ABC125')
shareForm.channels.WHISPER:Fire('OnEnter');check(shareForm.tip.text.text==longName..'-Realm'and shareForm.tip.text.height>=shareForm.tip.text.naturalWrappedHeight,'Long target name was truncated in hover')
shareForm.channels.WHISPER:Fire('OnLeave')
local originalCompactHeight=shareForm.height;setTarget(nil);check(shareForm.height==originalCompactHeight,'Target availability resized chooser')
homeGroup=true;homeRaid=true;instanceGroup=true;event('GROUP_ROSTER_UPDATE')
check(shareForm.channels.PARTY:IsEnabled()and shareForm.channels.RAID:IsEnabled()and shareForm.channels.INSTANCE_CHAT:IsShown()and #chatCalls==0,'Group change failed explicit capabilities or auto-submitted')
homeGroup=false;homeRaid=false;instanceGroup=false;event('GROUP_ROSTER_UPDATE')
check(not shareForm.channels.PARTY:IsEnabled()and not shareForm.channels.INSTANCE_CHAT:IsShown(),'Group loss retained stale destinations')
shareForm.copyButton:Fire('OnClick')
check(shareForm.width==600 and shareForm.height==396 and shareForm.reportScroll.clips and shareForm.scrollMaximum>0 and shareForm.reportScroll:IsShown(),'Expanded full report lacks bounded scrolling viewport')
check(not shareForm.copy:IsShown()and not shareForm.copy:HasFocus(),'Copy expansion stole focus before selection')
shareForm.reportScroll:Fire('OnMouseWheel',-10000);check(shareForm.reportScroll:GetVerticalScroll()==shareForm.scrollMaximum,'Wheel cannot reach last report line')
shareForm.scrollbar:SetValue(0);check(shareForm.scrollPosition==0,'Scrollbar cannot return to report start')
shareForm.copyButton:Fire('OnClick');check(shareForm.copy:IsShown()and shareForm.copy:GetText()==fullReport.text,'Selectable plain report differs from immutable facts')
shareForm.copy:SetText('Changed report');shareForm.copy:Fire('OnTextChanged',true);check(shareForm.copy:GetText()==fullReport.text and shareForm.report==fullReport,'Copy field altered frozen report')
shareForm.back:Fire('OnClick');check(shareForm.width==316 and not shareForm.reportScroll:IsShown()and not shareForm.copy:HasFocus(),'Returning to destinations retained expanded copy input')
local heldSelection=popup.selected;popup.healTargets[1]:Fire('OnEnter');hover(2);check(popup.selected==heldSelection and not popup.tooltipRecap:IsShown(),'Underlying chart reacted through modal')
popup.actionShield:Fire('OnClick');check(not shareForm:IsShown()and not popup.actionShield:IsShown()and not eventFrame.registered.PLAYER_TARGET_CHANGED,'Outside click retained modal/barrier/target subscription')
-- A transport failure cannot hide the independent full plain copy.
local buildMessages=R.BuildShareMessages;R.BuildShareMessages=function()return nil,'Report too large; select text to copy it'end
U:OpenShare();check(shareForm:IsShown()and shareForm.messageError and not shareForm.channels.SAY:IsEnabled(),'Chunk failure hid report or enabled transport')
shareForm.copyButton:Fire('OnClick');shareForm.copyButton:Fire('OnClick')
check(shareForm.copy:HasFocus()and shareForm.copy:GetText()==shareForm.report.text and shareForm.status.text:find('too large',1,true),'Chunk failure lost plain copy or reason')
shareForm.copy:Fire('OnEscapePressed');R.BuildShareMessages=buildMessages
check(not shareForm:IsShown()and not popup.actionShield:IsShown(),'Copy Escape retained modal')
U:Preview();hover(8);NoHealthPlot();check(popup.hp.text=='128000 / 400000'and not popup.healing:IsShown(),'Selected damage health was replaced by debt or inferred healing')
local wrappedSource=popup.tooltipRecap.lines[1]
RA:ApplyFont(wrappedSource,13,'BOLD',false);hover(8)
check(wrappedSource.wordWrap and wrappedSource.nonSpaceWrap and wrappedSource.maxLines==0 and wrappedSource.measuredWithHeight==0,'Font refresh/return skipped local wrap layout')
U:Preview()
-- A killing-blow absorption stays at its timestamp below a separate timer slot.
local savedFatalAbsorb=page.native.rows[4].absorbed;page.native.rows[4].absorbed=7000;U:ShowLast()
local endpointMarker
for _,marker in ipairs(popup.supportMarkers)do if marker:IsShown()and marker.entry.row.nativeIndex==1 then endpointMarker=marker end end
check(endpointMarker and endpointMarker.entry.first==0 and endpointMarker.timeX<=popup.deathX and popup.fightSlotExtra==20,'Endpoint absorption lost timestamp or timer slot')
local markerBottom=-endpointMarker.points[1][5]+10;local fightTop=-popup.fight.points[1][5]-14
check(fightTop>=markerBottom+4,'Killing-blow absorption overlaps fight timer')
page.native.rows[4].absorbed=savedFatalAbsorb;U:Preview()
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
check(not popup.coverage:IsShown()and not popup.healing:IsShown()and popup.shelf.text=='CDs'and popup.shelfSource=='Last recorded check','Real page adopted sample fields')
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
-- Every retained row remains reachable even at identical times. A mixed
-- temporal cluster keeps its largest-hit artwork and exact fatal receipt.
page.native.recapMaxHealth=1000;page.native.rows={}
for i=1,64 do page.native.rows[i]={nativeIndex=i,nativeOffset=-1,spellID=100+i,kind='damage',amount=i,recordedHP=i}end
U:ShowLast();local seen={}
for _,b in ipairs(hits())do
 if b.group.last==b.group.first then check(not b.span:IsShown()and b.span:GetScript('OnEnter')==nil,'Equal-time group kept a colliding scrub hitbox')end
 check(b.icon:IsShown()and b.group.representative and b.group.spellID==b.group.representative.spellID,'Cluster artwork lost the fixed largest-hit representative')
 for i=1,#b.group.rows do b:Fire('OnMouseWheel',-1);seen[b.group.rows[b.member].nativeIndex]=true end
end
for i=1,64 do check(seen[i],'Dense group lost constituent '..i)end
U:OpenShare();checkModal(popup.shareChooser);popup.shareChooser.close:Fire('OnClick')
-- Interleaved source histories use chronological half-second clusters. Their
-- exact spans and glyph/amount wheel paths still expose every constituent.
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
 for i=1,#b.group.rows do b.amountTarget:Fire('OnMouseWheel',-1);overlapSeen[b.group.rows[b.member].nativeIndex]=true end
end
for i,a in ipairs(hits())do if a.scrubAvailable then for j,b in ipairs(hits())do if j<i and b.scrubAvailable and a.group.tier==b.group.tier then
 check(a.group.first>=b.group.last or b.group.first>=a.group.last,'Enabled cluster scrub spans overlap ambiguously')
end end end end
for i=1,11 do check(overlapSeen[i],'Fallback lost constituent '..i)end
page=realPage
local savedSpells=page.lastAlive.spells;page.lastAlive.spells={}
for i=1,12 do page.lastAlive.spells[i]={spellID=500+i,name='Shelf '..i,observedAt=99,cooldown='inactive',category='minor'}end
U:ShowLast();hover(2);check(popup.guide.points[1][5]< -130 and popup.guide.points[1][5]-popup.guide.height==popup.healthPanel.points[1][5]+40,'Wrapped shelf guide no longer stops before the selected health readout')
page.lastAlive.spells=savedSpells
U:ShowLast();U:OpenShare();local liveBeforePreview=popup.shareChooser
local staleDestination=liveBeforePreview.channels.SAY:GetScript('OnClick')
U:Preview();staleDestination(liveBeforePreview.channels.SAY);check(#chatCalls==0,'Stale destination callback acted in Preview')
popup.share:Fire('OnClick');local previewForm=popup.shareChooser;local previewPage=previewForm.page
check(previewForm.copy:GetText():find('fictional sample',1,true),'Preview copy report lost provenance')
check(not R:BuildShareText(previewPage),'Unmarked sample accepted as recorded recap')
local beforeChatTimers=#timers;choose(previewForm,'SAY')
check(#chatCalls==1 and chatCalls[1].channel=='SAY'and chatCalls[1].text:find('RCP Preview — fictional sample',1,true)and #timers==beforeChatTimers,'Destination click did not synchronously submit first SAY line')
check(previewForm.nextLine:IsShown()and previewForm.close.label.text=='CANCEL'and not previewForm.channels.WHISPER:IsEnabled(),'Posting state/control locks absent')
check(not eventFrame.registered.PLAYER_TARGET_CHANGED,'Submission retained live target subscription')
local lockedTarget=previewForm.target;setTarget('QueuedTarget','Player-1-AB00CD');check(previewForm.target==lockedTarget,'Posting chooser re-read target')
setTarget(nil)
local firstNext=previewForm.nextLine:GetScript('OnClick')
previewForm.nextLine:Fire('OnClick');check(#chatCalls==2 and chatCalls[2].text==previewForm.messages[2],'Manual SAY did not preserve second line')
previewForm.close:Fire('OnClick');check(previewForm:IsShown()and previewForm.jobStatus=='stopped'and previewForm.status.text:find('2 / ',1,true)and previewForm.status.text:find('submitted',1,true),'Cancellation hid partial submission progress')
previewForm.nextLine:Fire('OnClick');choose(previewForm,'SAY');check(#chatCalls==2,'Stopped report restarted')
previewForm.close:Fire('OnClick');popup.share:Fire('OnClick');choose(previewForm,'SAY');check(#chatCalls==2 and previewForm.jobStatus=='stopped','Close/reopen duplicated partially submitted snapshot')
local modalReminder=db.personalTools.consumableReminder;popup.reminder:Fire('OnClick');check(db.personalTools.consumableReminder==modalReminder,'Reminder toggled through the report modal')
button('CLOSE'):Fire('OnClick');popup.reminder:Fire('OnClick');check(db.personalTools.consumableReminder,'Preview did not enable actual reminder')
for k,v in pairs(prefs)do if k~='consumableReminder'then check(db.personalTools[k]==v,'Preview toggle changed child preferences')end end
popup.reminder:Fire('OnClick');check(not db.personalTools.consumableReminder,'Preview did not disable actual reminder')
RA.PersonalTools:SetOption('consumableReminder',true);check(popup.reminder.enabledSetting,'Reminder action failed to follow external setting');popup.reminder:Fire('OnClick')
local staleReminder=popup.reminder:GetScript('OnClick');U:Hide();staleReminder();check(not db.personalTools.consumableReminder,'Hidden reminder callback changed the setting')
local sampleCalls=#chatCalls
U:ShowLast();local reminderPage=page;page={id=999,diedAt=100};popup.reminder:Fire('OnClick');check(not db.personalTools.consumableReminder,'Stale live page changed reminder setting');page=reminderPage
U:ShowLast();popup.reminder:Fire('OnClick');check(db.personalTools.consumableReminder,'Explicit live reminder toggle failed')
RA.PersonalTools:SetOption('consumableReminder',false)
db.deathRecap.autoOpen=true;RA:FireCallback('DEATH_RECAP_CHANGED','death');check(popup:IsShown(),'Auto popup missing')
popup:Hide();check(not popup.selected,'Native hide did not clear private selected context');RA:FireCallback('DEATH_RECAP_CHANGED','native');check(not popup:IsShown(),'Late data reopened closed popup')
U:ShowLast();RA:FireCallback('DEATH_RECAP_CHANGED','life');check(not popup:IsShown()and page==beforePage,'Life event discarded history or kept popup')
db.deathRecap.autoOpen=false;U:ShowLast();RA:FireCallback('DEATH_RECAP_CHANGED','death');check(not popup:IsShown(),'AutoopenOFF retained popup')
U:ShowLast();popup.share:Fire('OnClick');local liveForm=popup.shareChooser
choose(liveForm,'WHISPER');check(#chatCalls==sampleCalls,'No-target Whisper accepted')
setTarget('Friend','Player-1-ABC123');local whisper=liveForm.channels.WHISPER
check(whisper:IsEnabled()and whisper.detail.text=='Friend-Realm','Current target did not enable Whisper')
whisper:Fire('OnMouseDown');setTarget('Other','Player-1-DEF456');whisper:Fire('OnMouseUp');whisper:Fire('OnClick')
check(#chatCalls==sampleCalls and liveForm.status.text:find('Target changed',1,true),'Target change during press submitted to refreshed recipient')
-- Native state can change before its notification arrives; click revalidation
-- must reject that too, then require a new deliberate click.
whisper:Fire('OnMouseDown');targetName='Third';targetGUID='Player-1-123ABC';whisper:Fire('OnClick')
check(#chatCalls==sampleCalls and whisper.detail.text=='Third-Realm','Unnotified target switch bypassed click revalidation')
choose(liveForm,'WHISPER')
check(#chatCalls==sampleCalls+1 and chatCalls[#chatCalls].target=='Third-Realm'and liveForm.jobStatus=='posting','Second click Whisper target wrong')
choose(liveForm,'WHISPER');check(#chatCalls==sampleCalls+1,'Double destination activation duplicated first line')
local queued=timers[#timers];setTarget('NewTarget','Player-1-654ABC');queued.callback()
check(#chatCalls==sampleCalls+2 and chatCalls[#chatCalls].target=='Third-Realm','Target change rerouted active queue')
local nextQueued=timers[#timers];popup.actionShield:Fire('OnClick');nextQueued.callback()
check(#chatCalls==sampleCalls+2 and nextQueued.cancelled and not liveForm:IsShown()and liveForm.jobStatus=='stopped','Backdrop close retained queued work or lost stop state')
popup.share:Fire('OnClick');choose(liveForm,'WHISPER');check(#chatCalls==sampleCalls+2,'Reopen resent partial live report')
-- A fresh report blocks lockdown, preserves copy and does not auto-resume.
U:Preview();chatRestricted=true;popup.share:Fire('OnClick');choose(liveForm,'SAY')
check(#chatCalls==sampleCalls+2 and not liveForm.channels.SAY:IsEnabled(),'Chat lockdown bypassed')
chatRestricted=false;check(#chatCalls==sampleCalls+2,'Eligibility change auto-submitted')
liveForm.close:Fire('OnClick');popup.share:Fire('OnClick')
-- Explicit instance routing is exposed only with the matching capability.
instanceGroup=true;homeGroup=false;homeRaid=false;liveForm.close:Fire('OnClick');popup.share:Fire('OnClick')
check(liveForm.channels.INSTANCE_CHAT:IsShown()and liveForm.channels.INSTANCE_CHAT:IsEnabled()and not liveForm.channels.PARTY:IsEnabled(),'Instance group silently became Party or lost explicit action')
choose(liveForm,'INSTANCE_CHAT');check(chatCalls[#chatCalls].channel=='INSTANCE_CHAT','Explicit instance destination redirected')
local instanceQueued=timers[#timers];U:Hide();instanceQueued.callback();check(instanceQueued.cancelled and not liveForm:IsShown(),'Main close did not cancel queued report')
-- A ready action from an older open cannot submit a newly opened report.
U:Preview();popup.share:Fire('OnClick');local oldReady=liveForm.channels.SAY:GetScript('OnClick');liveForm.close:Fire('OnClick');popup.share:Fire('OnClick')
local beforeStale=#chatCalls;oldReady(liveForm.channels.SAY);check(#chatCalls==beforeStale,'Old chooser generation submitted after reopen')
choose(liveForm,'SAY');firstNext();check(#chatCalls==beforeStale+1,'Old SAY continuation acted on new report')
U:Hide()
-- Old captures cannot inherit today's Mirror talent. Utility uses remain
-- visible as observed facts while both defensive availability surfaces omit them.
page={id=777,diedAt=100,class='MAGE',specID=62,casts={{spellID=110959,name='Greater Invisibility',observedAt=94},{spellID=55342,name='Mirror Image',observedAt=93}},
 native={rows={{nativeIndex=1,nativeOffset=0,kind='damage',amount=1,recordedHP=0}}},lastAlive={spells={
 {spellID=110959,name='Greater Invisibility',known=true,cooldown='inactive',chargeQuery='not_applicable'},
 {spellID=55342,name='Mirror Image',known=true,cooldown='inactive',chargeQuery='not_applicable'}},supplies={}}}
U:ShowLast();check(#shelves()==2,'Legacy utility appeared on defensive availability shelf')
check(#RA.DeathRecapEntry:GetRows(page)==2,'Legacy utility appeared on compact defensive card')
local utilityChips=0
for _,b in ipairs(objects)do if b.parent==popup and b.useGroup and b:IsVisible()then
 utilityChips=utilityChips+1;check(b.useMeta.text:find('Utility',1,true),'Utility chip lost its visible role')
 tooltipLines={};b:Fire('OnEnter');check(table.concat(tooltipLines,' '):find('Recorded utility use',1,true),'Utility hover implied defensive use')
end end
check(utilityChips==2,'Eligible utility receipts disappeared')
local utilityReport=assert(R:BuildShareText(page))
check(utilityReport:find('Greater Invisibility: utility use',1,true)and utilityReport:find('Mirror Image: utility use',1,true),'Full report reclassified legacy utility casts')
page.lastAlive.spells[2].role='defensive';page.lastAlive.spells[2].defensiveTalentSpellID=1309497
U:ShowLast();check(#shelves()==3 and #RA.DeathRecapEntry:GetRows(page)==3,'Captured learned Refractive Images qualification lost defensive shelf/card')
U:Preview()
for _,b in ipairs(shelves())do tooltipSpell=nil;b:Fire('OnEnter');check(tooltipSpell~=110959,'Preview restored Greater Invisibility defensive icon')end
U:Hide()
-- Drag persistence uses native UIParent-space capture; cancellation never
-- overwrites settings and clamps keep the header reachable after screen changes.
U:ShowLast();local starts,stops=0,0
popup.StartMoving=function()starts=starts+1 end;popup.StopMovingOrSizing=function()stops=stops+1 end
local movedLeft,movedTop=120,900
popup.GetLeft=function()return movedLeft end;popup.GetTop=function()return movedTop end
popup:SetScale(.8);UIParent:SetScale(1);UIParent:SetSize(1920,1080)
local previousPosition=db.deathRecap.position
popup.dragHandle:Fire('OnDragStart');popup.dragHandle:Fire('OnDragStop')
check(starts==1 and stops==1 and db.deathRecap.position.point=='TOPLEFT'and db.deathRecap.position.x==96 and db.deathRecap.position.y==-360,'Drag did not persist scaled UIParent-space anchor')
U:Hide();U:ShowLast();check(popup.points[1][1]=='TOPLEFT'and popup.points[1][4]==96 and popup.points[1][5]==-360,'Reopen lost saved anchor')
local savedPosition=db.deathRecap.position
combat=true;popup.dragHandle:Fire('OnDragStart');popup.dragHandle:Fire('OnDragStop');check(starts==1 and db.deathRecap.position==savedPosition,'Combat drag changed saved position');combat=false
popup.dragHandle:Fire('OnDragStart');U:Hide();check(stops==2 and db.deathRecap.position==savedPosition,'Hide saved a partial drag or failed to stop movement')
U:ShowLast();popup.dragHandle:Fire('OnDragStart');local originalDB=RA.GetDB;local otherProfile={deathRecap={position={point='TOPLEFT',relativePoint='TOPLEFT',x=10,y=-10}}}
RA.GetDB=function()return otherProfile end;popup.dragHandle:Fire('OnDragStop');check(otherProfile.deathRecap.position.x==10 and db.deathRecap.position==savedPosition,'Profile switch saved old drag into another profile');RA.GetDB=originalDB
U:ShowLast();popup.dragHandle:Fire('OnDragStart');event('PLAYER_REGEN_DISABLED');check(db.deathRecap.position==savedPosition,'Combat entry committed an unfinished drag')
U:ResetPosition();check(db.deathRecap.position==nil,'Reset position did not clear saved anchor')
db.deathRecap.position={point='TOPLEFT',relativePoint='TOPLEFT',x=99999,y=-99999};U:ShowLast()
check(popup.points[1][4]>=0 and popup.points[1][4]<=1920-popup.width*.8 and popup.points[1][5]<=0 and popup.points[1][5]>=-(1080-popup.height*.8),'Saved offscreen position was not clamped')
UIParent:SetSize(1000,600);event('DISPLAY_SIZE_CHANGED');check(popup.points[1][4]<=1000-popup.width*.8 and popup.points[1][5]>=-(600-popup.height*.8),'Resolution change did not clamp visible window')
popup:SetScale(1);UIParent:SetSize(1920,1080);U:ResetPosition();U:Hide()
-- The header controls browse retained records while the latest death stays
-- bound to its own Summary/native association; the selected report follows it.
local actualHistory,actualRetained=R.GetHistory,R.IsRetainedPage
local latestFixture=page;local olderFixture={id=1001,diedAt=90,playerName='Saved player',restored=true,class='MAGE',casts={},lastAlive={spells={},supplies={}},native={recapID=1001,recapMaxHealth=100,rows={{nativeIndex=1,nativeOffset=0,kind='damage',amount=5,recordedHP=17}}}}
R.GetHistory=function()return{latestFixture,olderFixture}end
R.IsRetainedPage=function(self,p)return p==latestFixture or p==olderFixture end
U:ShowLast();check(popup.historyNav:IsShown()and popup.historyPicker.label.text=='1/2'and popup.historyPrev:IsEnabled()and not popup.historyNext:IsEnabled(),'History selector state incorrect at latest')
popup.historyPicker:Fire('OnClick');check(popup.historyMenu:IsShown()and popup.historyButtons[2].label.text:find('Saved player',1,true),'History menu lost concise identity')
popup.historyButtons[2]:Fire('OnClick');check(R:GetSelectedPage()==olderFixture and R:GetPage()==latestFixture and popup.healthPanel.selectedHP==17 and popup.historyPicker.label.text=='2/2','UI history selection replaced latest or borrowed selected HP')
check(R:BuildShareText(olderFixture):find('5 damage',1,true),'Selected history report omitted its own native row')
U:OpenShare();check(not U:ShowHistory(1),'History switched behind share modal');popup.shareChooser.close:Fire('OnClick')
popup.historyNext:Fire('OnClick');check(R:GetSelectedPage()==latestFixture and popup.historyPicker.label.text=='1/2','Newer navigation did not return to latest')
R.GetHistory,R.IsRetainedPage=actualHistory,actualRetained;U:Hide()
local nativeText={__raNativeText=true,GetText=function()error('Read back native secret Text aspect')end}
check(RA:GetVisualText(nativeText)==nil,'Asset recovery read native charge text')
check(sent==0 and talentReads==0 and inspectCalls==0,'UI sent/inspected raid')
cleanErrors();nativePrint('PASS: '..checks..' actual Death Log selection/group/shelf/preview/Journal/lifecycle assertions (offline; native acceptance pending)')
]=]
assert(loadstring(source,'death-log-ui-fixture'))()
