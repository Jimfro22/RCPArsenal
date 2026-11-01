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
local function Death(id)
 dead=true;ghost=false;page={id=id,captureGeneration=id,pending=true,nativeAttempts=1}
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
ShowHost(host);Hidden('Popup alone advertised a retained death')
Death(1);local b=named.RCPArsenalDeathRecapEntry
check(b and b:IsShown()and b.width==144 and b.height==34 and b.parent==UIParent,'Native-first death did not create independent 144x34 entry')
check(b.points[1][1]=='LEFT'and b.points[1][2]==host and b.points[1][4]==8,'Right host gap wrong')
check(b.logo.lastDesired==RA.Theme.Assets.HeaderLogo and b.logo.width==24 and b.logo.height==24 and b.logo.filter=='LINEAR','Existing logo broker/filter/size lost')
check(b.label.text=='Death Log'and b.label.fontSize==13 and b.pulse.looping=='REPEAT','Label or pulse configuration wrong')
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
check(GameTooltip.text=='Open your captured log.','Ready tooltip changed entry promise');b:Fire('OnLeave')
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
-- Geometry uses effective scales and retains a fitting choice for the same host.
HideHost(host);local edge=Host('StaticPopup2',1700,1900,600,750);ShowHost(edge)
check(b:IsShown()and b.points[1][1]=='TOP'and b.points[1][4]==0 and b.points[1][5]==-8,'Right edge did not choose below-host fallback')
edge.left,edge.right=600,1000;event('DISPLAY_SIZE_CHANGED')
check(b.points[1][1]=='TOP','Fitting below placement oscillated during layout refresh')
HideHost(edge);UIParent.scale=.8;UIParent.right,UIParent.top=2400,1350
local scaled=Host('StaticPopup4',500,900,550,700);scaled.scale=1.1
for _,a in pairs(scaled.buttons)do a.scale=1.1 end
ShowHost(scaled);check(b:IsShown()and b.points[1][1]=='LEFT','Fractional-scale bounds rejected safe host')
HideHost(scaled);UIParent.scale=1;UIParent.right,UIParent.top=1920,1080
local blocked=Host('StaticPopup1',1780,1910,8,120);ShowHost(blocked);Hidden('Unsafe right and below placements remained visible')
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
ShowHost(host);host.buttons[4].shown=false;E:Refresh()
check(b:IsShown(),'Hidden native recap button prevented Release-row anchor')
local setPoint=b.SetPoint;b.SetPoint=function()error('anchor denied')end;E:Refresh();Hidden('Failed anchor remained visible');b.SetPoint=setPoint
ShowHost(host);dead=secret;E:Refresh();Hidden('Unknown dead state advertised entry')
dead=true;ghost=secret;E:Refresh();Hidden('Unknown ghost state advertised entry')
ghost=false;ShowHost(host);local activeClick=b.scripts.OnClick;local beforeLogout=opens
local diagnosticStops=0;RA.DeathRecapDebug={StopCooldownCapture=function(_,reason)diagnosticStops=diagnosticStops+1;check(reason=='world-transition','Entry sent wrong diagnostic stop reason')end}
event('PLAYER_LOGOUT');Hidden('Logout retained entry');activeClick();check(opens==beforeLogout,'Old click survived context teardown')
check(diagnosticStops==1,'Existing logout observer did not stop diagnostic')
Death(10);ShowHost(host);RA.DeathRecapDebug.StopCooldownCapture=function()diagnosticStops=diagnosticStops+1;error('Diagnostic failure')end
event('PLAYER_LEAVING_WORLD');Hidden('Diagnostic error prevented entry cleanup');check(diagnosticStops==2,'Existing world-exit observer did not stop diagnostic')
check(nativeWrites==0,'Companion changed native frames')
check(ownedSchedules==0,'Entry created a timer or ticker')
for _,obj in ipairs(objects)do if obj==b or obj.parent==b then check(not obj.scripts.OnUpdate,'Owned per-frame script installed')end end
cleanErrors();nativePrint('PASS: '..checks..' Death Log entry lifecycle/identity/edge/animation assertions (offline)')
]=]
assert(loadstring(source, 'death-recap-entry-fixture'))()
