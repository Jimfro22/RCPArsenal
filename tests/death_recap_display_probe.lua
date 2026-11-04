-- Synthetic dataflow/lifecycle tests. Opaque userdata are NOT native secrets;
-- only the real client can verify pixels and protected value lifetime.
local checks,created=0,0
local function check(ok,message)checks=checks+1;assert(ok,message)end
local secret=newproxy(true)
local function forbidden()error('Opaque input inspected, formatted or calculated')end
for _,key in ipairs({'__tostring','__add','__sub','__mul','__div','__lt','__le','__concat','__index'})do getmetatable(secret)[key]=forbidden end
function issecretvalue(value)return rawequal(value,secret)end
local objects,named,timers,callbacks={}, {}, {}, {}
local methods={};local function noop()end
local function object(name,parent,kind)
 local o=setmetatable({scripts={},events={},shown=false,parent=parent,kind=kind},{__index=function(_,key)return methods[key]or noop end})
 objects[#objects+1]=o;if name then named[name]=o end;return o
end
function CreateFrame(kind,name,parent)created=created+1;return object(name,parent,kind)end
function methods:CreateFontString()return object(nil,self,'FontString')end
function methods:SetScript(key,fn)self.scripts[key]=fn end
function methods:RegisterEvent(key)self.events[key]=true end
function methods:RegisterUnitEvent(key,unit)self.events[key]=unit end
function methods:UnregisterAllEvents()self.events={}end
function methods:SetText(text)check(not issecretvalue(text),'Raw protected value sent through ordinary text');self.text=text;self.nativeInput=nil end
function methods:SetFormattedText(format,value)
 if rawget(self,'failText')then error('Synthetic native text rejection')end
 check(format=='%d','Unexpected native format');self.nativeInput=value
 if not issecretvalue(value)then self.text=string.format(format,value)else self.text=nil end
end
function methods:GetText()error('Text readback forbidden')end
function methods:SetMinMaxValues(lo,hi)check(lo==0 and hi==1000000,'Reference scale changed');self.lo,self.hi=lo,hi end
function methods:SetValue(value)
 if rawget(self,'failBar')then error('Synthetic native bar rejection')end
 self.nativeValue=value
end
function methods:GetValue()error('Bar readback forbidden')end
function methods:Show()self.shown=true end
function methods:Hide()self.shown=false;if self.scripts.OnHide then self.scripts.OnHide(self)end end
function methods:Fire(key,...)if self.scripts[key]then return self.scripts[key](self,...)end end
UIParent=object('UIParent');UISpecialFrames={}
local time,dead,combat,enabled=10,false,false,false
function GetTime()return time end
function UnitIsDeadOrGhost()return dead end
function InCombatLockdown()return combat end
function UnitHealthMax()check(not combat,'Probe queried live health in combat');return 1000000 end
function GetBuildInfo()return '12.test','synthetic-build','date',120100 end
function GetInstanceInfo()return 'Synthetic instance','raid',16,'Mythic',20,0,false,999 end
C_Timer={NewTimer=function(delay,fn)local t={delay=delay,fn=fn};function t:Cancel()self.cancelled=true end;timers[#timers+1]=t;return t end}
local copied,prints
local RA={VERSION='synthetic',DeathRecap={GetState=function()return{enabled=enabled}end},
 Theme={Colors={surfaceRaised={0,0,0,1},canvasDeep={0,0,0,1}},ApplyRounded=noop},
 DeathRecapUI={ShowDebugText=function(_,text)copied=text;return true end},ApplyFont=noop,Print=function(_,text)prints=text end}
function RA:RegisterCallback(key,fn)callbacks[key]=fn end
assert(loadfile('RCPArsenal/DeathRecapDisplayProbe.lua'))('RCPArsenal',RA)
local P=RA.DeathRecapDisplayProbe
local function event(name,...)
 for _,o in ipairs(objects)do if o.events[name]and o.scripts.OnEvent then o.scripts.OnEvent(o,name,...)end end
end
local function subscriptions()local n=0;for _,o in ipairs(objects)do for _ in pairs(o.events)do n=n+1 end end;return n end
check(created==0 and #timers==0 and subscriptions()==0,'Unarmed module created native work')
check(not P:Start()and created==0,'Disabled recap armed a probe')
enabled=true;combat=true;check(not P:Start()and created==0,'In-combat arm created UI');combat=false
dead=true;check(not P:Start()and created==0,'Dead arm created UI');dead=false
check(P:Start(),'Display test did not arm');local f=named.RCPArsenalProtectedDisplayTest;local firstTimer=timers[#timers]
check(f.shown and firstTimer.delay==120 and subscriptions()==6,'Armed indicator/deadline/subscription bound wrong')
check(#UISpecialFrames==0,'Armed indicator can be dismissed by generic close-all-windows')
local initialCreated=created
event('UNIT_COMBAT','player','WOUND','',secret,1)
check(P:BuildReport():find('Received 0;',1,true),'Out-of-combat feedback entered capture')
time=11;combat=true;event('PLAYER_REGEN_DISABLED')
time=11.1;event('UNIT_COMBAT','player','WOUND','',secret,1)
time=11.2;event('UNIT_COMBAT','player','HEAL','',secret,1)
event('UNIT_COMBAT',secret,'WOUND','',secret,1);event('UNIT_COMBAT','target','WOUND','',secret,1)
event('UNIT_COMBAT','player',secret,'',secret,1);event('UNIT_COMBAT','player','BLOCK','',secret,1)
time=11.3;event('UNIT_COMBAT','player','WOUND','',0,1)
event('UNIT_COMBAT','player','WOUND','',-1,1)
local observer;for _,o in ipairs(objects)do if o.events.UNIT_COMBAT then observer=o end end
local stale=observer.scripts.OnEvent
-- Model an external death-dialog hide BEFORE this observer receives the death.
f:Hide();check(subscriptions()==6 and not firstTimer.cancelled,'External hide discarded the armed capture')
time=12;dead=true;event('PLAYER_DEAD')
local report=P:BuildReport()
check(f.shown and report:find('State: frozen at own death',1,true),'Death did not reopen the hidden test')
check(report:find('Last event: PLAYER_DEAD; window hides: 1',1,true),'Lifecycle diagnostics lost the death/hide order')
check(report:find('Received 3; public 1; protected 2; rejected 1',1,true),'Protected/public/filter counters wrong')
check(report:find('Retained 3 / 8 seconds; protected retained 2; partial no',1,true),'Frozen window changed')
check(report:find('bar calls accepted 3; text calls accepted 3',1,true),'Native sink acceptance not reported')
check(report:find('synthetic-build; instance raid; difficulty 16',1,true),'Capture context absent')
check(subscriptions()==0 and firstTimer.cancelled and created==initialCreated,'Death retained work or allocated in combat')
check(rawequal(f.rows[2].amount.nativeInput,secret)and rawequal(f.rows[2].bar.nativeValue,secret),'Protected heal did not reach native sinks untouched')
check(f.rows[2].kind.text=='Healing'and f.rows[3].kind.text=='Damage','Event kinds lost')
for _,o in ipairs(objects)do if rawget(o,'label')and o.label.text=='COPY STATUS'then o:Fire('OnClick')end end
check(copied==report,'Copy exported protected values or changed metadata')
f:Hide();check(P:Show()and f.shown,'Frozen capture could not reopen')
report=P:BuildReport()
check(not P:Start()and P:BuildReport()==report,'Rearming while dead erased the existing capture')
firstTimer.fn();stale(observer,'UNIT_COMBAT','player','WOUND','',secret,1)
check(P:BuildReport()==report,'Stale callback changed frozen evidence')
f.rows[2].amount.failText=true;f.rows[2].bar.failBar=true;P:Render()
check(f.rows[2].amount.text=='(blocked)'and P:BuildReport():find('bar calls accepted 2; text calls accepted 2',1,true),'Native failure shown as success')
f.rows[2].amount.failText=nil;f.rows[2].bar.failBar=nil
P:Stop();check(P:BuildReport():find('Retained 0 / 8 seconds',1,true)and rawget(f.rows[2].amount,'nativeInput')==nil,'Stop retained an opaque display input')

-- Ring overflow is partial only if overwritten receipts overlap final 8s.
dead=false;combat=false;time=20;P:Start();time=21;combat=true;event('PLAYER_REGEN_DISABLED')
for i=1,300 do time=21+i/1000;event('UNIT_COMBAT','player','WOUND','',secret,1)end
time=22;dead=true;event('PLAYER_DEAD')
check(P:BuildReport():find('Retained 256 / 8 seconds; protected retained 256; partial yes',1,true),'Busy-window loss not explicit')
f:Fire('OnMouseWheel',-1);check(P:BuildReport():find('Rendered rows 17;',1,true),'Wheel did not advance one row')
check(created==initialCreated,'Scrolling grew the native widget pool')
dead=false;combat=false;time=30;P:Start();time=31;combat=true;event('PLAYER_REGEN_DISABLED')
for i=1,300 do time=31+i/1000;event('UNIT_COMBAT','player','WOUND','',secret,1)end
time=50;event('UNIT_COMBAT','player','WOUND','',secret,1);time=51;dead=true;event('PLAYER_DEAD')
check(P:BuildReport():find('Retained 1 / 8 seconds; protected retained 1; partial no',1,true),'Long-fight overflow mislabeled current window')

-- No mixing of fights, and old timeouts cannot stop a replacement arm.
dead=false;combat=false;time=60;P:Start();local old=timers[#timers];local oldCallback=observer.scripts.OnEvent
time=61;P:Start();old.fn();check(P:BuildReport():find('State: armed/recording',1,true),'Old expiry stopped replacement')
oldCallback(observer,'PLAYER_DEAD');check(P:BuildReport():find('State: armed/recording',1,true),'Old listener froze replacement')
time=62;combat=true;event('PLAYER_REGEN_DISABLED');event('UNIT_COMBAT','player','WOUND','',secret,1)
event('PLAYER_REGEN_ENABLED');time=63;event('PLAYER_REGEN_DISABLED');event('UNIT_COMBAT','player','HEAL','',123,1)
time=64;dead=true;event('PLAYER_DEAD')
check(P:BuildReport():find('Received 1; public 1; protected 0',1,true),'Second combat inherited first fight')

dead=false;combat=false;time=70;P:Start();event('PLAYER_ENTERING_WORLD')
check(subscriptions()==0 and P:BuildReport():find('State: world-changed',1,true),'World transition left recorder armed')
time=80;P:Start()
for _,o in ipairs(objects)do if rawget(o,'label')and o.label.text=='CLOSE'then o:Fire('OnClick')end end
check(not f.shown and subscriptions()==0 and timers[#timers].cancelled,'Explicit close left recording active')
check(P:BuildReport():find('State: window-closed',1,true),'Explicit close reason missing')
time=90;P:Start();callbacks.DEATH_RECAP_CHANGED('reset')
check(subscriptions()==6 and P:BuildReport():find('State: armed/recording',1,true),'Normal combat reset canceled the test')
callbacks.PROFILE_RESET();check(subscriptions()==0,'Profile reset left recorder active')
time=100;P:Start();enabled=false;callbacks.DEATH_RECAP_CHANGED('settings');check(subscriptions()==0,'Module disable left recorder active')
enabled=true;time=110;P:Start();time=230;event('PLAYER_REGEN_DISABLED');event('UNIT_COMBAT','player','WOUND','',secret,1)
check(subscriptions()==0 and P:BuildReport():find('State: timeout',1,true),'Delayed expiry callback allowed capture past deadline')
check(not copied:find('userdata',1,true),'Opaque userdata entered export')
print('PASS: '..checks..' protected-display mock assertions; real native widgets, secret lifetime and combat acceptance remain unverified')
