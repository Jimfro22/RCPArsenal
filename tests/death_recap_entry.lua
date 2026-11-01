-- Actual addon/event/asset modules with guarded popup mocks; no native claim.
local f = assert(io.open('tests/hub.lua')); local source = f:read('*a'); f:close()
source = source:sub(1, assert(source:find('check(db.schemaVersion == 19', 1, true))-1)
source = [[
local nativeHooks, hookCounts = {}, {}
function StaticPopup_Show() end
function StaticPopup_OnShow() end
function StaticPopup_OnHide() end
function hooksecurefunc(name, callback)
 nativeHooks[name] = callback; hookCounts[name] = (hookCounts[name] or 0)+1
end
]] .. source .. [=[
if not RA.DeathRecapEntry then
 assert(loadfile('RCPArsenal/DeathRecapEntry.lua'))('RCPArsenal', RA)
end
local R, U, E = RA.DeathRecap, RA.DeathRecapUI, RA.DeathRecapEntry
local enabled, dead, ghost, opened, page, visibleHost = false, false, false, false, nil, nil
local autoOpen=false
local opens, lookupCalls, pulseStarts, pulseStops = 0, 0, 0, 0
local secret = setmetatable({}, {__tostring=function()error('Secret stringified')end})
function issecretvalue(value)return rawequal(value,secret)end
function UnitIsDeadOrGhost()return dead end
function UnitIsGhost()return ghost end
R.GetState=function()return {enabled=enabled,autoOpen=autoOpen}end
R.GetPage=function()return page end
R.GetDiagnostics=function()return {fetchPending=page and page.pending==true}end
U.IsShown=function()return opened end
U.Hide=function()opened=false;RA:FireCallback('DEATH_RECAP_VISIBILITY',false)end
U.ShowLast=function()
 opens=opens+1;opened=true;RA:FireCallback('DEATH_RECAP_VISIBILITY',true,page);return true
end
function StaticPopup_FindVisible(which)
 check(which=='DEATH','Guessed popup identity');lookupCalls=lookupCalls+1;return visibleHost
end
function methods:IsForbidden()return self.forbidden==true end
function methods:GetScript(name)return self.scripts[name]end
function methods:SetFrameLevel(value)self.level=value end
function methods:SetFrameStrata(value)self.strata=value end
function methods:SetVertexColor(...)self.rgb={...}end
function methods:CreateLine()return object('Line',nil,self)end
function methods:SetThickness(v)self.thickness=v end
function methods:SetColorTexture(...)self.color={...}end
function methods:SetStartPoint(...)self.start={...}end
function methods:SetEndPoint(...)self.finish={...}end
function methods:SetAlpha(value)self.alpha=value end
function methods:GetLeft()return self.left end
function methods:GetRight()return self.right end
function methods:GetTop()return self.top end
function methods:GetBottom()return self.bottom end
function methods:GetButton(index)return self.buttons and self.buttons[index]end
function methods:SetFromAlpha(value)self.fromAlpha=value end
function methods:SetToAlpha(value)self.toAlpha=value end
function methods:SetDuration(value)self.duration=value end
function methods:SetOrder(value)self.order=value end
function methods:SetLooping(value)self.looping=value end
function methods:CreateAnimationGroup()
 local group=object('AnimationGroup',nil,self);group.animations={}
 function group:CreateAnimation(kind)local a=object(kind,nil,self);self.animations[#self.animations+1]=a;return a end
 function group:Play()pulseStarts=pulseStarts+1;self.playing=true end
 function group:Stop()pulseStops=pulseStops+1;self.playing=false end
 return group
end
function GameTooltip:SetOwner(owner)self.owner=owner end
function GameTooltip:GetOwner()return self.owner end
function GameTooltip:SetText(text)self.text=text;self.lines={text}end
function GameTooltip:AddLine(text)self.lines[#self.lines+1]=text end
UIParent.left,UIParent.right,UIParent.bottom,UIParent.top=0,1920,0,1080
local nativeWrites=0
local function Host(name,left,right,bottom,top)
 local host=object('Frame',name,UIParent)
 host.which='DEATH';host.left,host.right,host.bottom,host.top=left,right,bottom,top;host.buttons={}
 for _,i in ipairs({1,4})do
  local b=object('Button',nil,host);b.left,b.right,b.bottom,b.top=left+12,right-12,bottom+10,bottom+34;host.buttons[i]=b
 end
 for _,method in ipairs({'SetPoint','ClearAllPoints','SetSize','SetParent','SetScript','HookScript','SetAttribute'})do
  host[method]=function()nativeWrites=nativeWrites+1;error('Native popup mutated')end
  for _,b in pairs(host.buttons)do b[method]=host[method]end
 end
 return host
end
local host=Host('StaticPopup3',600,1000,600,750)
local function ShowHost(value)
 visibleHost=value;value.shown=true;nativeHooks.StaticPopup_OnShow(value);nativeHooks.StaticPopup_Show('DEATH')
end
local function HideHost(value)
 value.shown=false;if visibleHost==value then visibleHost=nil end;nativeHooks.StaticPopup_OnHide(value)
end
local function Close()
 opened=false;RA:FireCallback('DEATH_RECAP_VISIBILITY',false,page)
end
local function Death(id,sample)
 dead=true;ghost=false;page={id=id,captureGeneration=id,diedAt=100,pending=true,nativeAttempts=1,lastAlive=sample}
 RA:FireCallback('DEATH_RECAP_CHANGED','death')
end
local function Hidden(message)
 local b=named.RCPArsenalDeathRecapEntry
 check(not b or not b:IsShown(),message)
 check(not b or not b.pulse.playing,'Hidden entry retained animation')
 check(not b or not b.scripts.OnUpdate,'Entry installed OnUpdate')
end
RA:FireCallback('DEATH_RECAP_CHANGED','settings')
check(not named.RCPArsenalDeathRecapEntry,'Disabled entry allocated visible controls')
enabled=true;RA:FireCallback('DEATH_RECAP_CHANGED','settings')
for _,name in ipairs({'StaticPopup_Show','StaticPopup_OnShow','StaticPopup_OnHide'})do
 check(hookCounts[name]==1,'Missing or duplicate secure post-hook '..name)
end
local ownedSchedules=0
for _,name in ipairs({'NewTimer','NewTicker','After'})do
 local original=C_Timer[name]
 C_Timer[name]=function(...)
  if debug.getinfo(2,'S').source:find('DeathRecapEntry.lua',1,true)then ownedSchedules=ownedSchedules+1 end
  return original(...)
 end
end
-- The entry is a pure projection of the recorded living check. It must not
-- re-check current state, borrow death-notification evidence or classify the kit.
local stateReads,savedAPIs=0,{}
local function DenyStateRead(object,key)
 if not object then return end
 savedAPIs[#savedAPIs+1]={object=object,key=key,value=object[key]}
 object[key]=function()stateReads=stateReads+1;error('Entry attempted a live state query: '..key)end
end
for _,key in ipairs({'GetSpellCooldown','GetSpellCharges','IsSpellKnown','IsSpellUsable'})do DenyStateRead(C_Spell,key)end
for _,key in ipairs({'GetItemCount','GetItemCooldown'})do DenyStateRead(C_Item,key)end
DenyStateRead(RA.HealingSupplies,'GetCached');DenyStateRead(_G,'GetTime')
local function Ready(id,category,time)
 return {spellID=id,name='Defensive '..id,known=true,category=category or'minor',cooldown='inactive',chargeQuery='not_applicable',cooldownAt=time or 98,observedAt=95}
end
local function Available(sample,extra)
 local frozen=extra or{};frozen.diedAt=100;frozen.lastAlive=sample
 return E:GetRows(frozen),frozen
end
local major,minor=Ready(40,'major',97),Ready(10,'minor',98)
local charged=Ready(30,'major',80);charged.cooldown='active';charged.currentCharges=1;charged.chargeQuery='public';charged.chargesAt=99
local positiveStone={kind='stone',itemID=5512,icon=100,name='Recorded stone',physicalCount=1,remainingUses=1,cooldown='inactive',cooldownAt=96,observedAt=96,carriedAt=50}
local positivePotion={kind='potion',itemID=222,icon=102,physicalCount=2,remainingUses=2,cooldown='inactive',cooldownAt=91,observedAt=91,carriedAt=40}
local unknownPotion={kind='potion',itemID=333,icon=103,cooldown='unknown',observedAt=99.5,partial=true}
local rows=Available(nil,{knownEntries={Ready(1)},deathObservation={spells={Ready(2)}}})
check(#rows==3 and not rows.hadCheck and rows[1].recordedState==nil and rows[1].checkedAt==nil,'Missing living check borrowed current kit/death readiness')
local sample={spells={minor,major,charged},supplies={unknownPotion,positivePotion,positiveStone}}
rows=Available(sample)
check(#rows==5 and rows[1].spellID==30 and rows[2].spellID==40 and rows[3].spellID==10 and rows[4].kind=='stone'and rows[5].kind=='potion','Shared ordering diverged')
check(rows[1].checkedAt==99 and rows[4].representativeItemID==5512 and rows[4].checkedAt==96 and rows[5].representativeItemID==222 and rows[5].checkedAt==91,'Shared family projection lost actual positive member/time')
rows[1].name='changed';check(charged.name=='Defensive 30'and sample.spells[1]==minor,'Projection mutated frozen data')
rows=Available({spells={Ready(1)},supplies={positiveStone},coverageEndedAt=99})
for _,row in ipairs(rows)do check(row.recordedState==nil,'Ended coverage became ready/unavailable')end
local negative=Ready(2);negative.cooldown='active'
local unknown=Ready(3);unknown.chargeQuery='public';unknown.maxCharges=2
rows=Available({spells={Ready(1),negative,unknown},supplies={}})
check(rows[1].recordedState==true and rows[2].recordedState==false and rows[3].recordedState==nil,'Full projection dropped or conflated tri-state evidence')
local bounded={spells={},supplies={}}
for i=1,40 do bounded.spells[i]=Ready(i);bounded.supplies[i]={kind='stone',itemID=i,cooldown='unknown'}end
rows=Available(bounded);check(#rows==34 and #rows[33].members==32,'Shared projection exceeded32 spells/items or omitted family icons')
local duplicate=Ready(1);rows=Available({spells={duplicate,duplicate},supplies={}});check(#rows==3,'Duplicate spell icons entered projection')
check(stateReads==0,'Frozen projection queried current APIs')
for _,saved in ipairs(savedAPIs)do saved.object[saved.key]=saved.value end
ShowHost(host);Hidden('Popup alone advertised a retained death')
Death(1);local b=named.RCPArsenalDeathRecapEntry
check(b and b:IsShown()and b.width==160 and b.height==56 and b.parent==UIParent,'Native-first death did not create the compact independent zero-icon card')
check(b.points[1][1]=='BOTTOM'and b.points[1][2]==host and b.points[1][3]=='TOP'and b.points[1][4]==0 and b.points[1][5]==8,'Card did not center above its native host with an eight-unit gap')
check(b.logo.lastDesired==RA.Theme.Assets.HeaderLogo and b.logo.filter=='LINEAR'and b.logo.width==18 and b.logo.height==18,'Existing logo broker/filter or compact size lost')
check(b.label.text=='Death Summary'and b.label.fontSize==13 and b.summary==nil and b.chevron and b.pulse.looping=='REPEAT','Compact card title, chevron or pulse missing, or removed caption remains')
check(b.logo.points[1][4]==10 and b.logo.points[1][5]==-6 and b.label.points[1][4]==36 and b.label.points[1][5]==-6 and b.label.height==18,'Zero-icon card header was not centered in its shorter height')
check(#b.pulse.animations==2 and b.pulse.animations[1].fromAlpha==.10 and b.pulse.animations[1].toAlpha==.22 and b.pulse.animations[1].duration==1.4 and b.pulse.animations[2].duration==1.4,'Pulse escaped 2.8s .10/.22 breath')
local starts=pulseStarts
RA:FireCallback('DEATH_RECAP_CHANGED','native');RA:FireCallback('DEATH_RECAP_CHANGED','death')
check(pulseStarts==starts,'Native update or duplicate death restarted pulse')
b:Fire('OnEnter');check(GameTooltip.text:find('loading',1,true)and not b.pulse.playing,'Pending help/hover attention wrong')
b:Fire('OnLeave');local click=b.scripts.OnClick;click()
check(opens==1 and opened,'Pending entry could not open captured page');Hidden('Open log retained entry')
Close();check(b:IsShown()and not b.pulse.playing,'Closing viewed death restarted attention')
b:Fire('OnEnter');HideHost(host);Hidden('Native hide left floating entry')
check(not GameTooltip:IsShown(),'Native hide left tooltip')
ShowHost(host);check(b:IsShown()and not b.pulse.playing,'Same death did not survive native hide/reshow')
local stale=b.scripts.OnClick
HideHost(host);host.which='RESURRECT';host.shown=true;visibleHost=host;nativeHooks.StaticPopup_OnShow(host)
Hidden('Pooled frame reuse kept entry');stale();check(opens==1,'Old click opened after host reuse')
host.which='DEATH';ShowHost(host);check(b:IsShown(),'Same death did not return after offer dismissal')
page.pending=false;RA:FireCallback('DEATH_RECAP_CHANGED','native');b:Fire('OnEnter')
check(GameTooltip.text:find('unavailable',1,true),'Unavailable tooltip falsely claimed ready/loading');b:Fire('OnLeave')
page.native={};RA:FireCallback('DEATH_RECAP_CHANGED','native');b:Fire('OnEnter')
check(GameTooltip.text=='Open your captured log.','Ready native details changed the open-log promise or invented availability provenance');b:Fire('OnLeave')
stale=b.scripts.OnClick;page={id=99,captureGeneration=99};stale();check(opens==1,'Page replacement opened last page through stale click')
RA:FireCallback('DEATH_RECAP_CHANGED','native');Hidden('Native update latched an unwitnessed page')
Death(2);check(b:IsShown()and b.pulse.playing,'Replacement death did not reset attention')
stale=b.scripts.OnClick;page.captureGeneration=3;stale();check(opens==1,'Changed capture generation bypassed binding')
RA:FireCallback('DEATH_RECAP_CHANGED','native');Hidden('Changed generation remained advertised')
Death(3);ghost=true;nativeHooks.StaticPopup_Show('DEATH');Hidden('Ghost retained entry')
ghost=false;event('PLAYER_ALIVE');nativeHooks.StaticPopup_Show('DEATH');Hidden('Life transition retained old token')
Death(4);event('PLAYER_ENTERING_WORLD');RA:FireCallback('DEATH_RECAP_CHANGED','native');Hidden('World transition revived retained page')
Death(5);enabled=false;RA:FireCallback('DEATH_RECAP_CHANGED','settings');Hidden('Disable retained entry')
enabled=true;RA:FireCallback('DEATH_RECAP_CHANGED','settings');Hidden('Enable advertised an old retained page')
Death(6);RA:FireCallback('PROFILE_RESET');Hidden('Profile reset retained death binding')
Death(61);RA:FireCallback('DEATH_RECAP_CHANGED','reset');Hidden('Same-enabled recorder reset retained death binding')
RA:FireCallback('DEATH_RECAP_CHANGED','settings');Hidden('Settings rearmed a reset page')
Death(62);RA:FireCallback('DEATH_RECAP_CHANGED','unavailable');Hidden('Failed new capture retained death binding')
Death(63);event('PLAYER_LEAVING_WORLD');Hidden('Leaving world retained death binding')
HideHost(host);Death(7);Hidden('No host created free-floating entry');ShowHost(host)
check(b:IsShown(),'Page-first death was not resolved by secure show hook')
-- The actual UI callback opens before the entry receives the death callback.
autoOpen=true;Death(8);check(opened,'Actual UI callback did not honor auto-open');autoOpen=false
Hidden('Auto-open retained entry');Close()
check(b:IsShown()and not b.pulse.playing,'Auto-opened death was later treated as unviewed')
-- Preview hides the entry but must not mark an unopened real death viewed.
Death(9);opened=true;RA:FireCallback('DEATH_RECAP_VISIBILITY',true,{id=0});Hidden('Preview retained entry')
Close();check(b:IsShown()and b.pulse.playing,'Preview consumed real-death attention')
-- The whole card prefers above, then below when above is clipped. It must not
-- overlap the popup or screen edges when neither complete placement fits.
HideHost(host);local edge=Host('StaticPopup2',1850,1910,600,750);ShowHost(edge)
Hidden('Card at horizontal screen edge escaped its above-host fit check')
edge.left,edge.right=600,1000;event('DISPLAY_SIZE_CHANGED')
check(b:IsShown()and b.points[1][1]=='BOTTOM'and b.points[1][2]==edge and b.points[1][3]=='TOP'and b.points[1][5]==8,'Display resize did not restore safe above-host placement')
HideHost(edge);UIParent.scale=.8;UIParent.right,UIParent.top=2400,1350
local scaled=Host('StaticPopup4',500,900,550,700);scaled.scale=1.1
for _,a in pairs(scaled.buttons)do a.scale=1.1 end
ShowHost(scaled);check(b:IsShown()and b.points[1][1]=='BOTTOM'and b.points[1][2]==scaled and b.points[1][5]==8,'Fractional-scale bounds rejected safe above-host card')
HideHost(scaled);UIParent.scale=1;UIParent.right,UIParent.top=1920,1080
local aboveClipped=Host('StaticPopup1',600,1000,900,1080-b.height/2);ShowHost(aboveClipped)
check(b:IsShown()and b.points[1][1]=='TOP'and b.points[1][2]==aboveClipped and b.points[1][3]=='BOTTOM'and b.points[1][4]==0 and b.points[1][5]==-8,'Clipped above card did not use the safe centered below fallback')
aboveClipped.top=750;aboveClipped.bottom=600;event('DISPLAY_SIZE_CHANGED')
check(b:IsShown()and b.points[1][1]=='BOTTOM'and b.points[1][5]==8,'Safe above placement was not restored after resize')
HideHost(aboveClipped);local blocked=Host('StaticPopup1',600,1000,10,1070);ShowHost(blocked);Hidden('Neither full above nor below card fit but the card remained visible')
HideHost(blocked);ShowHost(host);host.forbidden=true;nativeHooks.StaticPopup_Show('DEATH');Hidden('Forbidden host remained visible')
host.forbidden=false;ShowHost(host);host.which=secret;nativeHooks.StaticPopup_Show('DEATH');Hidden('Secret popup identity was trusted')
host.which='DEATH';host.right=secret;nativeHooks.StaticPopup_Show('DEATH');Hidden('Secret geometry was used')
host.right=1000;local saved=StaticPopup_FindVisible;StaticPopup_FindVisible=function()error('lookup denied')end
E:Refresh();Hidden('Failed lookup retained entry');StaticPopup_FindVisible=saved
ShowHost(host);host.IsProtected=function()return true end;E:Refresh()
check(b:IsShown(),'Readable protected native host was rejected without an owned mutation failure')
local beforeGeometry=geometryWrites
b.CanChangeProtectedState=function()return false end;E:Refresh();Hidden('Owned mutation denial retained entry')
check(geometryWrites==beforeGeometry,'Geometry changed after owned mutation denial')
b.CanChangeProtectedState=function()return secret end;E:Refresh();Hidden('Opaque owned mutation permission was trusted')
b.CanChangeProtectedState=function()error('permission denied')end;E:Refresh();Hidden('Failed owned mutation permission was trusted')
b.CanChangeProtectedState=function()return true end;ShowHost(host);check(b:IsShown(),'Public owned permission did not restore eligible entry')
ShowHost(host);host.buttons[4].shown=false;host.buttons[1].shown=false;E:Refresh()
check(b:IsShown()and b.points[1][1]=='BOTTOM','Hidden native action buttons prevented above-popup card placement')
local setPoint=b.SetPoint;b.SetPoint=function()error('anchor denied')end;E:Refresh();Hidden('Failed anchor remained visible');b.SetPoint=setPoint
ShowHost(host);dead=secret;E:Refresh();Hidden('Unknown dead state advertised entry')
dead=true;ghost=secret;E:Refresh();Hidden('Unknown ghost state advertised entry')
ghost=false;ShowHost(host);local activeClick=b.scripts.OnClick;local beforeLogout=opens
local diagnosticStops=0;RA.DeathRecapDebug={StopCooldownCapture=function(_,reason)diagnosticStops=diagnosticStops+1;check(reason=='world-transition','Entry sent wrong diagnostic stop reason')end}
event('PLAYER_LOGOUT');Hidden('Logout retained entry');activeClick();check(opens==beforeLogout,'Old click survived context teardown')
check(diagnosticStops==1,'Existing logout observer did not stop diagnostic')
Death(10);ShowHost(host);RA.DeathRecapDebug.StopCooldownCapture=function()diagnosticStops=diagnosticStops+1;error('Diagnostic failure')end
event('PLAYER_LEAVING_WORLD');Hidden('Diagnostic error prevented entry cleanup');check(diagnosticStops==2,'Existing world-exit observer did not stop diagnostic')

-- Card and plain icon hotspots share the same frozen-page opener. Child-owned
-- hover help and captured click closures must clear with the card's identity.
local function Icons()
 local icons={};for _,icon in ipairs(b.icons)do if icon:IsVisible()then icons[#icons+1]=icon end end
 return icons
end
local function CheckCardLayout(expected,preview)
 local visible=Icons();local strips={};local rowCount=0
 check(#visible==expected and b.width>=160 and b.width<=280 and b.width%4==0 and b.summary==nil,'Compact card bounds/icon count or caption removal changed')
 local headerY=expected==0 and -7 or -6
 check(b.logo.width==18 and b.logo.height==18 and b.logo.points[1][4]==10 and b.logo.points[1][5]==headerY,'Compact logo geometry changed')
 check(b.label.text==(preview and'Death Summary · Preview'or'Death Summary')and b.label.fontSize==13 and b.label.height==18 and b.label.points[1][4]==36 and b.label.points[1][5]==headerY,'Compact header lost title geometry or explicit Preview label')
 check(b.label.width>=b.label:GetStringWidth(),'Compact header clipped its visible title')
 check(b.chevron.width==8 and b.chevron.points[1][4]==-8 and b.chevron.points[1][5]==headerY,'Open cue lost right inset or header alignment')
 for _,icon in ipairs(visible)do
  local x,y=icon.points[1][4],icon.points[1][5]
  check(icon.width==22 and icon.height==22 and x>=8 and x+22<=b.width-8 and -y+22<=b.height-6,'Compact icon or strip padding changed')
  check(y<=-28 and(-y-28)%26==0,'Compact strip has a blank caption band or invalid row step')
  if not strips[y]then strips[y]={first=x,last=x+22};rowCount=rowCount+1 else strips[y].first=math.min(strips[y].first,x);strips[y].last=math.max(strips[y].last,x+22)end
 end
 for _,strip in pairs(strips)do check(math.abs(strip.first-(b.width-strip.last))<.001,'Wrapped icon row is not independently centered')end
 check(b.height==(expected==0 and 32 or 56+(rowCount-1)*26),'Compact card height retained a caption band or lost extra-row spacing')
end
local helperCalls=0;local availableHelper=E.GetRows
E.GetRows=function(self,value)helperCalls=helperCalls+1;return availableHelper(self,value)end
local freshSample={spells={Ready(30,'major',99),Ready(40,'major',97),Ready(10,'minor',98)},supplies={positiveStone,positivePotion}}
Death(11,freshSample);ShowHost(host)
local icons=Icons()
check(#icons==5 and helperCalls==1,'Death card did not cache its positive living-check snapshot once')
check(b.width==160 and b.height==56,'Common five-icon state did not fit the compact 160 by 56 card')
CheckCardLayout(5)
for i,icon in ipairs(icons)do
 check(icon.width==22 and icon.height==22 and icon.points[1][5]==-28,'Normal icon row lost its compact size or vertical position')
 if i>1 then
  local gap=icon.points[1][4]-icons[i-1].points[1][4]-icons[i-1].width
  check(math.abs(gap-(i==4 and 10 or 4))<.001,'Normal icon row lost the small defensive gap or item-family separation')
 end
end
check(b.chevron:IsShown()and not b.previewClose:IsShown(),'Live card exposed preview close or lost open cue')
b:Fire('OnEnter');local cardHelp=table.concat(GameTooltip.lines,' ')
check(cardHelp:find('red X = unavailable',1,true)and cardHelp:find('? = unconfirmed',1,true),'Caption removal lost historical availability or uncertainty from card hover');b:Fire('OnLeave')
for i,icon in ipairs(icons)do
 check(icon.kind=='Button'and icon.parent==b and icon.width==icon.height and not icon.cooldown and not icon.hotkey and next(icon.attrs)==nil,'Evidence icon acquired an action/cooldown/hotkey control')
 check(icon.row and icon.row.checkedAt and(icon.row.spellID or icon.row.representativeItemID),'Available icon lost its frozen identity/check time')
 local before=opens;icon:Fire('OnClick');check(opens==before+1 and opened,'Evidence icon did not open the bound frozen page')
 Hidden('Icon-opened log retained entry');Close();icons=Icons()
end
icons=Icons();icons[1]:Fire('OnEnter')
local iconHelp=table.concat(GameTooltip.lines,' ')
check(GameTooltip:GetOwner()==icons[1]and GameTooltip.text=='Defensive 30'and iconHelp:find('Available when checked',1,true)and iconHelp:find('1.0s before death notice',1,true)and iconHelp:find('Click to open Death Log',1,true),'Available spell hover lost historical availability, captured name/check age or open action')
check(not b.pulse.playing,'Icon hover retained attention animation')
local iconClick=icons[1].scripts.OnClick;local beforeIcons=opens
HideHost(host);Hidden('Host hide retained icon card');check(not GameTooltip:IsShown(),'Host hide left child-owned availability tooltip')
host.which='RESURRECT';host.shown=true;visibleHost=host;nativeHooks.StaticPopup_OnShow(host);iconClick()
check(opens==beforeIcons,'Saved icon click opened after native host reuse')
host.which='DEATH';ShowHost(host);icons=Icons()
freshSample.spells[1].name='Changed after freeze';freshSample.spells[1].cooldown='active'
page.native={};RA:FireCallback('DEATH_RECAP_CHANGED','native');event('UI_SCALE_CHANGED')
icons=Icons();check(helperCalls==1 and #icons==5 and icons[1].row.name=='Defensive 30','Native/layout refresh reclassified or mutated the death-time availability projection')
icons[5]:Fire('OnEnter');check(table.concat(GameTooltip.lines,' '):find('9.0s before death',1,true),'Potion tooltip used newer family check or discovery time')
icons[5]:Fire('OnLeave')
icons[4]:Fire('OnEnter');check(table.concat(GameTooltip.lines,' '):find('Uses remaining when checked: 1',1,true),'Healthstone tooltip omitted its frozen remaining-use count');icons[4]:Fire('OnLeave')
iconClick=icons[1].scripts.OnClick;page.captureGeneration=999;iconClick();check(opens==beforeIcons,'Saved icon click bypassed changed capture generation')
E:Refresh();Hidden('Changed-generation icon card remained visible')
Death(12,{spells={Ready(1)},supplies={}});ShowHost(host);iconClick=Icons()[1].scripts.OnClick
page={id=999,captureGeneration=999};iconClick();check(opens==beforeIcons,'Saved icon click bypassed replaced page identity');E:Refresh();Hidden('Page replacement retained icon card')
Death(13,{spells={Ready(1)},supplies={}});ShowHost(host);iconClick=Icons()[1].scripts.OnClick
ghost=true;iconClick();check(opens==beforeIcons,'Saved icon click opened after release to ghost');E:Refresh();Hidden('Ghost retained icon card');ghost=false
Death(14,{spells={Ready(1)},supplies={}});ShowHost(host);iconClick=Icons()[1].scripts.OnClick
event('PLAYER_ALIVE');iconClick();check(opens==beforeIcons,'Saved icon click survived life cleanup');Hidden('Life cleanup retained icon card')

-- Future larger lists wrap every available icon. No count-only overflow hides
-- evidence, and every wrapped hotspot still opens the same frozen page.
local crowded={spells={},supplies={positiveStone,positivePotion}}
for i=1,32 do crowded.spells[i]=Ready(700+i,i<=4 and'major'or'minor',99)end
Death(15,crowded);ShowHost(host);icons=Icons()
local stone,potion,count,lines=nil,nil,0,{}
for _,icon in ipairs(icons)do
 check(icon.row and not icon.overflow and icon.width==22 and icon.height==22,'Wrapped evidence became a count-only overflow or changed icon size')
 count=count+1
 if icon.row and icon.row.kind=='stone'then stone=icon elseif icon.row and icon.row.kind=='potion'then potion=icon end
 local point=icon.points[1];check(point[4]>=8 and point[4]+icon.width<=b.width-8 and -point[5]+icon.height<=b.height-6,'Available icon lost its side/bottom padding or overflows card bounds')
 lines[point[5]]=true
 local before=opens;icon:Fire('OnClick');check(opens==before+1 and opened,'Wrapped evidence icon did not open its frozen page');Close()
end
local lineCount=0;for _ in pairs(lines)do lineCount=lineCount+1 end
check(#icons==34 and count==34 and stone and potion and lineCount>1 and b.height==56+(lineCount-1)*26,'Wrapped card omitted available icons, lost supply families or grew outside its row-height rule')
CheckCardLayout(34)
check(stone.points[1][5]==potion.points[1][5],'Wrapped item pair split across rows')
local ten={spells={},supplies={positiveStone,positivePotion}}
for i=1,8 do ten.spells[i]=Ready(800+i)end
Death(151,ten);ShowHost(host);icons=Icons()
check(#icons==10 and b.width==280 and b.height==56,'Ten available icons did not fit the 280 by 56 single-row card')
CheckCardLayout(10)
for _,icon in ipairs(icons)do check(icon.points[1][5]==-28,'Normal ten-icon state wrapped unnecessarily')end
local boundary={spells={},supplies={positiveStone,positivePotion}}
for i=1,9 do boundary.spells[i]=Ready(900+i)end
Death(152,boundary);ShowHost(host);icons=Icons();CheckCardLayout(11)
check(b.width==280 and b.height==82 and icons[9].points[1][5]==-28 and icons[10].row.kind=='stone'and icons[11].row.kind=='potion'and icons[10].points[1][5]==-54 and icons[11].points[1][5]==-54,'Near-full spell row split the item pair or left an extra caption band')
Death(16,{spells={Ready(1)},supplies={}});ShowHost(host);check(#Icons()==3 and not Icons()[1].overflow and b.width==160 and b.height==56,'Sparse death retained wrapped rows/extra icons or failed to compact')
CheckCardLayout(3)
Death(17,{spells={{spellID=1,known=true,cooldown='unknown'}},supplies={}});ShowHost(host)
check(#Icons()==3 and b.width==160 and b.height==56,'Unknown-only check retained old icons or a reserved caption band')
CheckCardLayout(3);b:Fire('OnEnter');local emptyHelp=table.concat(GameTooltip.lines,' ')
check(emptyHelp:find('? = unconfirmed.',1,true),'Unknown-only hover lost recorded-check provenance or uncertainty');b:Fire('OnLeave')
Death(18);ShowHost(host);check(#Icons()==2 and b.width==160 and b.height==56,'Missing living sample retained old icons or a reserved caption band')
CheckCardLayout(2);b:Fire('OnEnter');emptyHelp=table.concat(GameTooltip.lines,' ')
check(emptyHelp:find('? = unconfirmed.',1,true),'Missing living sample was confused with a negative/unknown recorded check');b:Fire('OnLeave')
local untimed=Ready(1);untimed.cooldownAt=nil;untimed.observedAt=nil
Death(181,{spells={untimed},supplies={}});ShowHost(host);Icons()[1]:Fire('OnEnter')
check(table.concat(GameTooltip.lines,' '):find('Check time not recorded',1,true),'Missing check time appeared current/at death');Icons()[1]:Fire('OnLeave')
untimed.cooldownAt=101;Death(182,{spells={untimed},supplies={}});ShowHost(host);Icons()[1]:Fire('OnEnter')
check(table.concat(GameTooltip.lines,' '):find('Check time not recorded',1,true)and not table.concat(GameTooltip.lines,' '):find('-1.0s',1,true),'Future check timestamp was rendered as an honest pre-death age');Icons()[1]:Fire('OnLeave')
E.GetRows=availableHelper

-- Card Preview is explicitly synthetic, may run without a death popup, and
-- returns to the exact real token without consuming its unviewed attention.
local previews=0;local originalPreview=U.Preview
U.Preview=function()previews=previews+1;opened=true;RA:FireCallback('DEATH_RECAP_VISIBILITY',true,{id=0});return true end
Death(19,{spells={Ready(1)},supplies={}});ShowHost(host);local realPage=page
check(b.pulse.playing,'New real entry did not begin unviewed')
E:Preview();check(b:IsShown()and b.label.text=='Death Summary · Preview'and b.points[1][2]==UIParent and b.previewClose:IsShown()and not b.chevron:IsShown(),'Preview card was not labelled, independently centered and dismissible')
CheckCardLayout(#Icons(),true)
check(page==realPage and R:GetPage()==realPage,'Card preview replaced the captured real page')
local previewClick=Icons()[1].scripts.OnClick;local beforePreview=opens
previewClick();check(previews==1 and opens==beforePreview and page==realPage,'Preview icon opened/mutated a real death page')
Close();E:HidePreview();check(b:IsShown()and b.label.text=='Death Summary'and b.pulse.playing,'Preview consumed real-death attention or failed to restore the real card')
E:Preview();previewClick=b.scripts.OnClick;b.previewClose:Fire('OnClick');previewClick()
check(previews==1 and b:IsShown()and b.label.text=='Death Summary','Dismissed preview click remained active or close lost real card')
HideHost(host);dead=false;E:Preview();check(b:IsShown()and b.label.text=='Death Summary · Preview','Preview required own death or a native popup')
b:Fire('OnClick');check(previews==2 and opens==beforePreview,'Preview card click did not open only the fictional full log');Close();E:HidePreview();Hidden('No-host preview dismissal retained a floating card')
combat=true;E:Preview();Hidden('Preview entered during combat');combat=false
E:Preview();enabled=false;RA:FireCallback('DEATH_RECAP_CHANGED','settings');Hidden('Disable retained preview mode')
enabled=true;RA:FireCallback('DEATH_RECAP_CHANGED','settings');Hidden('Re-enable revived dismissed preview')
E:Preview();event('PLAYER_ENTERING_WORLD');Hidden('World transition retained preview mode')
E:Preview();RA:FireCallback('PROFILE_RESET');Hidden('Profile reset retained preview mode')
-- Preview also works while recording is disabled. Its existing lifecycle and
-- display subscriptions must be demanded only for that temporary preview.
enabled=false;RA:FireCallback('DEATH_RECAP_CHANGED','settings');E:Preview()
check(b:IsShown()and b.label.text=='Death Summary · Preview','Disabled recorder blocked the independent card preview')
local refreshCalls=0;local entryRefresh=E.Refresh
E.Refresh=function(self)refreshCalls=refreshCalls+1;return entryRefresh(self)end
event('UI_SCALE_CHANGED');check(refreshCalls==1 and b:IsShown(),'Disabled-recorder preview did not observe display/scale changes')
event('PLAYER_ENTERING_WORLD');Hidden('Disabled-recorder preview survived a world transition')
refreshCalls=0;event('UI_SCALE_CHANGED');check(refreshCalls==0,'Dismissed disabled preview retained display-event demand')
E:Preview();local combatClick=b.scripts.OnClick;local beforeCombatPreview=previews
combat=true;combatClick();check(previews==beforeCombatPreview,'Already-open preview click bypassed the out-of-combat gate')
E:Refresh();Hidden('Preview refresh retained a card in combat');combat=false;E:HidePreview()
E:Preview();local beforeDeniedGeometry=geometryWrites;b.CanChangeProtectedState=function()return false end
E:Refresh();Hidden('Preview ignored owned mutation denial');check(geometryWrites==beforeDeniedGeometry,'Preview changed geometry after owned mutation denial')
b.CanChangeProtectedState=function()return true end;E:HidePreview();E.Refresh=entryRefresh
local previewStops=0;local entryHidePreview=E.HidePreview
E.HidePreview=function(self)previewStops=previewStops+1;return entryHidePreview(self)end
E:Preview();check(b:IsShown(),'Disabled-recorder combat-entry fixture did not show preview')
combat=true;event('PLAYER_REGEN_DISABLED');Hidden('Combat entry did not immediately hide disabled-recorder preview')
check(previewStops==1,'Preview combat subscription did not stop exactly one active preview')
event('PLAYER_REGEN_DISABLED');check(previewStops==1,'Combat subscription remained active after preview stopped')
combat=false;E:Preview();E:HidePreview();previewStops=0
combat=true;event('PLAYER_REGEN_DISABLED');check(previewStops==0,'Explicit preview close retained the combat subscription');combat=false
enabled=true;RA:FireCallback('DEATH_RECAP_CHANGED','settings')
E:Preview();Death(20,{spells={Ready(2)},supplies={}});ShowHost(host)
check(b:IsShown()and b.label.text=='Death Summary'and Icons()[1].row.spellID==2,'New real death did not replace preview with its own frozen card')
local retainedPage=page;E:Preview();local stoppedPreviewClick=b.scripts.OnClick;local stoppedPreviewCount=previews
combat=true;event('PLAYER_REGEN_DISABLED')
check(page==retainedPage and R:GetPage()==retainedPage and b:IsShown()and b.label.text=='Death Summary'and Icons()[1].row.spellID==2 and b.pulse.playing,'Combat cancellation erased or marked viewed the real entry behind preview')
combat=false;stoppedPreviewClick();check(previews==stoppedPreviewCount,'Combat-cancelled preview callback revived the sample log')
E.HidePreview=entryHidePreview
U.Preview=originalPreview
-- A real character-check result reuses status paint, remains clearly before
-- combat, and cannot open the fictional death or survive combat entry.
local originalCharacterCheck=R.CheckCharacter;local checkCalls=0
R.CheckCharacter=function()checkCalls=checkCalls+1;return{observedAt=99,spells={Ready(40),{spellID=41,name='Used',known=true,cooldown='active',chargeQuery='not_applicable'}},supplies={}}end
combat=false;dead=false;Close();E:CheckCharacter()
check(checkCalls==1 and b:IsShown()and b.label.text=='Before combat'and #Icons()==4,'Check character panel lost real snapshot/all states or clear label')
local beforeSample=previews;b:Fire('OnClick');check(previews==beforeSample and b:IsShown(),'Character check opened a fictional death')
local negative=false
for _,icon in ipairs(Icons())do if icon.row.spellID==41 then negative=true;check(icon.recordedState==false and icon.statusLines[1]:IsShown(),'Before-combat negative lost drawn X')end end
check(negative,'Before-combat projection dropped unavailable spell')
combat=true;event('PLAYER_REGEN_DISABLED');Hidden('Character check survived combat entry');combat=false;R.CheckCharacter=originalCharacterCheck
check(nativeWrites==0,'Companion changed native frames')
check(ownedSchedules==0,'Entry created a timer or ticker')
for _,obj in ipairs(objects)do local owner=obj;while owner and owner~=b do owner=owner.parent end
 if owner==b then check(not obj.scripts.OnUpdate,'Owned card/icon descendant installed a per-frame script')end
end
cleanErrors();nativePrint('PASS: '..checks..' Death Log entry compact-layout/lifecycle/identity/edge/animation assertions (offline)')
]=]
assert(loadstring(source, 'death-recap-entry-fixture'))()
