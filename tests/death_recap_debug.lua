-- Actual recorder wrapper + diagnostic module. Offline evidence only.
local f=assert(io.open('tests/death_recap.lua'));local source=f:read('*a');f:close()
source=source:sub(1,assert(source:find('check(optionalCount()==0',1,true))-1)
source=source..[=[
assert(loadfile('RCPArsenal/DeathRecapDebug.lua'))('RCPArsenal',RA)
local D=RA.DeathRecapDebug
local opens,nativeCalls,hasCalls,maxCalls=0,0,0,0
OpenDeathRecapUI=function(id)check(id==17,'Native opener used default/foreign ID');opens=opens+1 end
local ok,reason=R:OpenBlizzardRecap();check(not ok and opens==0,'Missing page opened native UI')
check(not R:BuildDebugText(),'Missing page invented debug report')
check(not R:ReadNativePacketForDebug(),'Missing page reread native data')
R:SetOption('enabled',true);event('DAMAGE_METER_CURRENT_SESSION_UPDATED');event('DAMAGE_METER_COMBAT_SESSION_UPDATED',9,1)
combat=true;event('PLAYER_REGEN_DISABLED')
time=11;event('SPELL_UPDATE_COOLDOWN',871,871,0,0,1)
meterRows={{isLocalPlayer=true,deathRecapID=17}}
events={{timestamp=100.00000000000001,destGUID='Player-self',event='SWING_DAMAGE',spellId=7,amount=13997,currentHP=12509,hideCaster=false},
 {timestamp=102,destGUID='Player-self',event='SPELL_DAMAGE',spellId=123,amount=29686,currentHP=119005,absorbed=0}}
local function getEvents(id)check(id==17,'Reread used default/foreign ID');nativeCalls=nativeCalls+1;return events end
C_DeathRecap.GetRecapEvents=getEvents
C_DeathRecap.HasRecapEvents=function(id)check(id==17,'Has used default/foreign ID');hasCalls=hasCalls+1;return true end
C_DeathRecap.GetRecapMaxHealth=function(id)check(id==17,'Max used default/foreign ID');maxCalls=maxCalls+1;return 850900 end
dead=true;time=12;event('PLAYER_DEAD');local page=R:GetPage();local captured=page.native
check(captured and captured.recapID==17 and captured.rows[1].nativeIndex==1,'Fixture did not accept native record')
check(captured.rows[1].nativeOffset<0 and captured.rows[1].amount<captured.rows[2].amount,'Fixture did not separate fatal/max/largest')
local q,n,h,m,b,t,ar=R:GetDiagnostics().spellQueries,nativeCalls,hasCalls,maxCalls,bagReads,#timers,R:GetDiagnostics().association.reads
local frozen=assert(R:BuildDebugText())
check(frozen:find('timestamp=100.00000000000001',1,true),'Diagnostic rounded raw timestamp')
check(frozen:find('rawSpellID=7 spellID=88163',1,true),'Raw swing identity merged with display identity')
check(frozen:find('hideCaster=false',1,true)and frozen:find('absorbed=0',1,true),'False/zero became unavailable')
check(frozen:find('directCooldown ',1,true)and frozen:find('directCooldown.context ',1,true)and frozen:find('arg5 value=1',1,true),'Frozen direct check/context missing')
check(frozen:find('nativeMaximumTimestamp=102',1,true)and frozen:find('nativeFatalTimestamp=100.00000000000001',1,true),'Fatal conflated with maximum timestamp')
for i=1,20 do check(R:BuildDebugText()==frozen,'Frozen diagnostic changed without capture changes')end
check(nativeCalls==n and hasCalls==h and maxCalls==m and bagReads==b and #timers==t and R:GetDiagnostics().spellQueries==q and R:GetDiagnostics().association.reads==ar,'Ordinary diagnostic collected or scheduled work')
local snapshot=D:GetFrozenSnapshot();snapshot.native.rows[1].amount=999;snapshot.lastAlive.spells[1].directCooldown.isActive=true
check(R:BuildDebugText()==frozen,'Diagnostic snapshot exposed mutable frozen references')
events[1].amount=22145;events[1].timestamp=103;events[1].currentHP=99
check(R:BuildDebugText()==frozen,'Frozen export followed live native input')
local reread=assert(R:BuildDebugText(true))
check(nativeCalls==n+1 and hasCalls==h+1 and maxCalls==m+1,'Explicit reread made more than one packet read')
check(reread:find('arraySlot=1 amount frozen=13997 reread=22145',1,true)and reread:find('arraySlot=1 recordedHP frozen=12509 reread=99',1,true),'Index-wise fatal change was not reported')
check(page.native==captured and captured.rows[1].amount==13997 and R:BuildDebugText()==frozen,'Reread replaced frozen packet')
check(#timers==t and bagReads==b and R:GetDiagnostics().association.reads==ar and R:GetDiagnostics().spellQueries==q,'Reread scheduled/polled unrelated work')
ok,reason=R:OpenBlizzardRecap();check(ok and opens==1 and reason=='Requested Blizzard recap ID 17','Native no-return opener reported failure or wrong ID')
OpenDeathRecapUI=function()error('native load failure')end
ok,reason=R:OpenBlizzardRecap();check(not ok and reason=='Blizzard recap request failed','Native opener error escaped')
OpenDeathRecapUI=nil;check(not R:OpenBlizzardRecap(),'Absent opener reported success')
local savedID=captured.recapID
for _,bad in ipairs({secret,0,-1,17.5,0/0,math.huge,'17',false,{}})do
 captured.recapID=bad;n=nativeCalls
 check(not R:OpenBlizzardRecap()and not R:ReadNativePacketForDebug()and not R:BuildDebugText(true),'Bad ID accepted')
 check(nativeCalls==n,'Bad ID queried native API')
end
captured.recapID=savedID
-- Default export is safe with unsupported/opaque scalars and markup-bearing text.
local rawAmount,rawEvent=captured.rows[1].amount,captured.rows[1].event
captured.rows[1].amount=secret;captured.rows[1].event='bad|Hspell:1|h'
local unsafe=assert(R:BuildDebugText());check(unsafe:find('amount=<restricted>',1,true)and unsafe:find('event=<malformed>',1,true)and not unsafe:find('|',1,true),'Opaque/markup value escaped export')
captured.rows[1].amount=rawAmount;captured.rows[1].event=rawEvent
local savedGet=C_DeathRecap.GetRecapEvents
C_DeathRecap.GetRecapEvents=function()nativeCalls=nativeCalls+1;return secret end
local unavailable=assert(R:BuildDebugText(true));check(unavailable:find('REREAD unavailable=',1,true)and page.native==captured,'Opaque reread overwrote packet or did not report unavailable')
C_DeathRecap.GetRecapEvents=function()error('getter failure')end
check(R:BuildDebugText(true):find('REREAD unavailable=',1,true),'API error escaped diagnostic action')
C_DeathRecap.GetRecapEvents=function()return{{timestamp=101,destGUID='Player-other',event='SPELL_DAMAGE'}}end
check(R:BuildDebugText(true):find('foreign_native_destination',1,true),'Foreign diagnostic packet accepted')
C_DeathRecap.GetRecapEvents=function()page.native={recapID=17,rows={}};return events end
local packet,why=R:ReadNativePacketForDebug();check(not packet and why=='Recorded page changed during diagnostic read','Changed capture pointer accepted')
page.native=captured
-- Reread row/iteration cap applies even when the API returns more records.
events={};for i=1,90 do events[i]={timestamp=100+i*.01,event='SPELL_DAMAGE',spellId=100+i,amount=i,currentHP=100-i}end
C_DeathRecap.GetRecapEvents=savedGet
packet=assert(R:ReadNativePacketForDebug());check(#packet.rows==64 and packet.truncated,'Native reread exceeded retained row limit')
local oversized=assert(R:BuildDebugText(true));check(not oversized:find('arraySlot=65',1,true)and oversized:find('truncated=true',1,true),'Export exceeded native row bound')
-- Every output remains copyable within its explicitly marked text bound.
local originalLimit=D.LIMITS.text;D.LIMITS.text=700
local bounded=assert(R:BuildDebugText());check(#bounded<=700 and bounded:find('[Diagnostic text truncated at bounded output limit.]',1,true),'Text cap silently cut output')
D.LIMITS.text=originalLimit
R:SetOption('enabled',false);n,h,m,b,t=nativeCalls,hasCalls,maxCalls,bagReads,#timers
check(R:BuildDebugText()and optionalCount()==0,'OFF lost frozen export or added subscriptions')
check(nativeCalls==n and hasCalls==h and maxCalls==m and bagReads==b and #timers==t,'OFF frozen export did native work')
local oldTrust=issecretvalue;issecretvalue=nil
check(not R:BuildDebugText()and not R:OpenBlizzardRecap()and not R:ReadNativePacketForDebug(),'Missing trust checker did work')
issecretvalue=oldTrust
print('PASS: '..checks..' diagnostic frozen/native-ID/reread/bounds assertions (offline)')
]=]
assert(loadstring(source,'death-recap-debug-fixture'))()
