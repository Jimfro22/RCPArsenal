-- Two source snapshots for one explicitly armed death. No native timing claim.
local f=assert(io.open('tests/death_recap.lua'));local prefix=f:read('*a');f:close()
prefix=prefix:sub(1,assert(prefix:find('check(optionalCount()==0',1,true))-1)
assert(loadstring(prefix..[=[
local frames=0
function CreateFrame()frames=frames+1;error('Native-only comparison must not create a transport frame')end
assert(loadfile('RCPArsenal/DeathRecapDebug.lua'))('RCPArsenal',RA);local D=RA.DeathRecapDebug
local reads=0
local linked={{timestamp=200,event='SWING_DAMAGE',amount=15000,currentHP=10000,overkill=5000,hideCaster=false}}
local personal=linked
C_DeathRecap.HasRecapEvents=function()return true end
C_DeathRecap.GetRecapMaxHealth=function()return 100000 end
C_DeathRecap.GetRecapEvents=function(id)if id==nil then reads=reads+1;return personal end;return linked end
check(not D:StartIncomingProbe(true)and frames==0 and reads==0,'Disabled comparison read or allocated')
RaidArsenalDB={}
R:SetOption('enabled',true);event('DAMAGE_METER_CURRENT_SESSION_UPDATED')
check(D:StartIncomingProbe(true)and frames==0 and reads==0,'Arming comparison registered transport or queried native data')
local expiry=timers[#timers];check(expiry.delay==120,'Native comparison does not cover a fight over 30 seconds')
combat=true;time=11;event('PLAYER_REGEN_DISABLED')
meterRows={{isLocalPlayer=true,deathRecapID=71}};dead=true;time=50;event('PLAYER_DEAD')
local page=R:GetPage();local first=page.personalNativeProbe
check(first and first.rows[1].amount==15000 and reads==1 and expiry.cancelled,'Long fight lost initial personal snapshot or arm timeout remained active')
check(page.liveIncoming.probe.mode=='native-comparison'and page.native.recapID==71,'Comparison lost its mode or changed association')
local lateTimer=timers[#timers];check(lateTimer.delay==1,'Comparison did not schedule exactly one delayed check')
personal={{timestamp=208,event='SPELL_DAMAGE',spellId=999,name='Synthetic later hit',amount=2500,currentHP=2000,overkill=500,hideCaster=false}}
time=51;fire(lateTimer)
local late=page.personalNativeProbeLate
check(reads==2 and late and late.rows[1].amount==2500 and late.readBefore==51 and late.observedAt==51,'Late personal response was not frozen at its actual read time')
check(page.native.rows[1].amount==15000 and first.rows[1].amount==15000,'Diagnostic replaced the accepted recap or initial snapshot')
personal[1].amount=999;fire(lateTimer,true)
check(reads==2 and late.rows[1].amount==2500,'Stale timer reread or native table mutation changed saved facts')
check(not R:ReadPersonalNativeForProbe(page,'late'),'Completed late response reread outside the one-shot bound')
local text=assert(R:BuildDebugText())
check(text:find('PERSONAL DEFAULT AFTER ONE SECOND',1,true)and text:find('capturedFieldsMatch=false',1,true),'Export hides changed native/default responses')
local restored=RA.DeathRecapHistory:Load()
check(restored[1].personalNativeProbe.rows[1].amount==15000 and restored[1].personalNativeProbeLate.rows[1].amount==2500,
 'Both independently captured responses did not survive history save/load')
check(restored[1].personalNativeProbeLate.observedAt==51 and restored[1].liveIncoming.probe.mode=='native-comparison','History lost phase timing or mode')

-- An expired, disabled or replaced arm cannot leak a later native query.
R:SetOption('enabled',false);dead=false;combat=false;time=60;meterRows={};R:SetOption('enabled',true);event('DAMAGE_METER_CURRENT_SESSION_UPDATED')
check(D:StartIncomingProbe(true),'Second comparison did not arm');combat=true;event('PLAYER_REGEN_DISABLED')
meterRows={{isLocalPlayer=true,deathRecapID=72}};dead=true;time=61;event('PLAYER_DEAD');lateTimer=timers[#timers]
local before=reads;R:SetOption('enabled',false);time=62;fire(lateTimer,true)
check(lateTimer.cancelled and reads==before,'Disabled comparison left a delayed native query active')
dead=false;combat=false;time=70;meterRows={};R:SetOption('enabled',true);event('DAMAGE_METER_CURRENT_SESSION_UPDATED')
check(D:StartIncomingProbe(true),'Deadline comparison failed');combat=true;event('PLAYER_REGEN_DISABLED')
time=190;dead=true;event('PLAYER_DEAD')
check(not R:GetPage().personalNativeProbe and reads==before,'Late timeout callback allowed a death at/after the deadline')
R:SetOption('enabled',false)
io.write('PASS: '..checks..' native-only arm, two-phase capture, no transport, immutable source, persistence and cancellation checks\n')
]=]))()
