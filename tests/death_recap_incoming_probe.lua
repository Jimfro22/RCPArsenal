-- Synthetic event transport and native-frame model; no user capture data.
local f=assert(io.open('tests/death_recap.lua'));local prefix=f:read('*a');f:close()
prefix=prefix:sub(1,assert(prefix:find('check(optionalCount()==0',1,true))-1)
assert(loadstring(prefix..[=[
local frames={}
function CreateFrame()
 local f={registered={}};frames[#frames+1]=f
 function f:RegisterEvent(name)self.registered[name]=true end
 function f:IsEventRegistered(name)return self.registered[name]==true end
 function f:UnregisterAllEvents()self.registered={}end
 function f:SetScript(_,fn)self.fn=fn end
 return f
end
C_CombatText={GetActiveUnit=function()return 'player'end,GetCurrentEventInfo=function()return secret,secret end}
assert(loadfile('RCPArsenal/DeathRecapDebug.lua'))('RCPArsenal',RA);local D=RA.DeathRecapDebug
check(#frames==0 and not D:StartIncomingProbe()and #frames==0,'Probe allocated/registered while OFF')
R:SetOption('enabled',true);check(D:StartIncomingProbe(),'Enabled probe did not arm')
local probe=frames[1];local timer=timers[#timers]
check(probe.registered.UNIT_COMBAT and probe.registered.COMBAT_TEXT_UPDATE and timer.delay==30,'Probe lacks independent plain subscriptions or bounded timeout')
combat=true;time=11;event('PLAYER_REGEN_DISABLED')
-- Emulate a working unfiltered transport with no player-filtered callbacks.
probe.fn(probe,'UNIT_COMBAT','player','WOUND','',123,1)
probe.fn(probe,'UNIT_COMBAT',secret,secret,'',secret,1)
for i=1,8 do probe.fn(probe,'COMBAT_TEXT_UPDATE','SPELL_AURA_START')end
probe.fn(probe,'COMBAT_TEXT_UPDATE','DAMAGE')
dead=true;time=12;event('PLAYER_DEAD');local page=R:GetPage();local attached=page.liveIncoming.probe
check(page.liveIncoming.callbacks==0 and attached.callbacks==2 and attached.playerCallbacks==1 and attached.unreadableUnits==1,'Separate transports were conflated or no-event recorder masqueraded as no-event engine')
check(attached.textCallbacks==9 and attached.textIncomingCallbacks==1 and attached.samples[2].amount==nil and attached.samples[2].amountStatus=='restricted'and attached.textSamples[1].amountStatus=='restricted','Probe lost relevant incoming samples behind auras or exported a private amount')
check(not attached.active and attached.stopReason=='own-death'and next(probe.registered)==nil and timer.cancelled,'Own death did not stop and unregister the temporary listener')
probe.fn(probe,'UNIT_COMBAT','player','WOUND','',999,1)
check(attached.callbacks==2,'Late probe receipt mutated frozen death')
local text=assert(R:BuildLiveHistoryText())
check(text:find('UNFILTERED TRANSPORT TEST',1,true)and text:find('playerCallbacks=1',1,true)and text:find('COMBAT_TEXT_UPDATE sample',1,true),'Combined readout lacks the independent transport comparison')
local saved=RA.DeathRecapHistory:Snapshot(page)
check(saved.liveIncoming.probe.playerCallbacks==1 and saved.liveIncoming.probe.nativeRegistered==true and #saved.liveIncoming.probe.samples==2,'Bounded public probe history failed to persist')
-- A replacement capture and a stale timeout cannot alter the saved result.
dead=false;combat=false;time=20;event('PLAYER_ALIVE');check(D:StartIncomingProbe(),'Second capture failed')
fire(timer,true);check(probe.registered.UNIT_COMBAT,'Old timeout unregistered the new owner')
R:SetOption('enabled',false);check(next(probe.registered)==nil,'Disable leaked temporary native subscriptions')
R:SetOption('enabled',true);time=30;check(D:StartIncomingProbe(),'Timeout capture failed');local expiry=timers[#timers]
time=60;probe.fn(probe,'UNIT_COMBAT','player','WOUND','',999,1)
check(next(probe.registered)==nil and expiry.cancelled,'Delayed timer permitted collection past the deadline')
check(saved.liveIncoming.probe.callbacks==2 and attached.callbacks==2,'New captures changed prior-life probe history')
-- Registration failure cleans up the first successful event registration.
probe.RegisterEvent=function(self,name)if name=='COMBAT_TEXT_UPDATE'then error('refused')end;self.registered[name]=true end
time=70;check(not D:StartIncomingProbe()and next(probe.registered)==nil,'Partial registration failure left an unbounded listener')
print('PASS: '..checks..' owner-armed incoming transport comparison/bounds/secrets/freeze/cleanup assertions')
]=]))()
