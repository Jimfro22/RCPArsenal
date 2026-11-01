-- Pending native capture belongs to the frozen death, not the new alive session.
local f=assert(io.open('tests/death_recap.lua'));local source=f:read('*a');f:close()
source=source:sub(1,assert(source:find('check(optionalCount()==0',1,true))-1)
source=source..[=[
local function Start(at)
 R:SetOption('enabled',false);time=at;dead=false;combat=true;meterRows={};events={}
 R:SetOption('enabled',true);event('DAMAGE_METER_CURRENT_SESSION_UPDATED');event('DAMAGE_METER_COMBAT_SESSION_UPDATED',9,1)
 dead=true;time=at+1;event('PLAYER_DEAD');return R:GetPage(),timers[#timers]
end
local function Available(id)
 meterRows={{isLocalPlayer=true,deathRecapID=id}};events={{destGUID='Player-self',timestamp=100,event='SPELL_DAMAGE',spellId=123,amount=100}}
end
local page,pending=Start(100)
dead=false;time=101.1;event('PLAYER_ALIVE');event('PLAYER_UNGHOST')
check(not pending.cancelled and R:GetDiagnostics().fetchPending and R:GetPage()==page,'Fast resurrection invalidated the frozen pending death')
Available(1);fire(pending);check(page.native and page.native.recapID==1,'Personal native record arriving after resurrection was lost')
page,pending=Start(200);fire(pending)
check(page.nativeAttempts==2 and not R:GetDiagnostics().fetchPending,'In-combat fallback attempt bound changed')
local count,reads=#timers,R:GetDiagnostics().association.reads
for i=1,100 do event('DAMAGE_METER_COMBAT_SESSION_UPDATED',1,1)end
check(#timers==count and R:GetDiagnostics().association.reads==reads,'Unrelated meter type scheduled or scanned native capture')
Available(2);event('DAMAGE_METER_COMBAT_SESSION_UPDATED',9,1)
local wake=timers[#timers];check(#timers==count+1 and wake.delay==.1 and R:GetDiagnostics().fetchPending,'Relevant late meter update did not schedule bounded completion')
for i=1,1000 do event('DAMAGE_METER_COMBAT_SESSION_UPDATED',9,1)end
check(#timers==count+1 and page.nativeAttempts==2,'Repeated meter update duplicated pending work')
fire(wake);check(page.native and page.native.recapID==2 and page.nativeAttempts==3,'Late meter data did not complete the existing personal page')
count=#timers;reads=R:GetDiagnostics().nativeReads
for i=1,1000 do event('DAMAGE_METER_COMBAT_SESSION_UPDATED',9,1)end
check(#timers==count and R:GetDiagnostics().nativeReads==reads,'Completed death kept collecting native data')
page,pending=Start(300);dead=false;event('PLAYER_ALIVE');time=302;dead=true;event('PLAYER_DEAD')
local newer,newTimer=R:GetPage(),timers[#timers]
check(newer~=page and pending.cancelled and newTimer~=pending,'New death did not replace the pending capture generation')
fire(pending,true);check(R:GetPage()==newer and not newTimer.cancelled and R:GetDiagnostics().fetchPending,'Stale fetch callback cleared newer pending capture')
page,pending=Start(400);fire(pending);event('DAMAGE_METER_COMBAT_SESSION_UPDATED',9,1);wake=timers[#timers];fire(wake)
count=#timers;reads=R:GetDiagnostics().association.reads
for i=1,1000 do event('DAMAGE_METER_COMBAT_SESSION_UPDATED',9,1)end
combat=false;event('PLAYER_REGEN_ENABLED')
check(page.nativeAttempts==3 and #timers==count and R:GetDiagnostics().association.reads==reads,'Native attempts exceeded the per-death shared budget')
for _,boundary in ipairs({'PLAYER_ENTERING_WORLD','DAMAGE_METER_CURRENT_SESSION_UPDATED','DAMAGE_METER_RESET','disable','profile'})do
 page,pending=Start(time+10);reads=R:GetDiagnostics().nativeReads
 if boundary=='disable'then R:SetOption('enabled',false)
 elseif boundary=='profile'then RA:FireCallback('PROFILE_RESET')else event(boundary)end
 Available(3);fire(pending,true)
 check(pending.cancelled and not page.native and R:GetDiagnostics().nativeReads==reads,'Invalidated native fetch ran after '..boundary)
end
R:SetOption('enabled',false);check(optionalCount()==0 and not R:GetDiagnostics().fetchPending,'OFF kept native fetch demand')
print('PASS: '..checks..' bounded frozen-page native capture lifetime and event-wake assertions (offline; native event order pending)')
]=]
assert(loadstring(source,'death-recap-fetch-fixture'))()
