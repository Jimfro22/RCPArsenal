-- Independent event-contract regressions; actual recorder with bounded API mocks.
local f=assert(io.open('tests/death_recap.lua'));local prefix=f:read('*a');f:close()
prefix=prefix:sub(1,assert(prefix:find('check(optionalCount()==0',1,true))-1)
local cases={
  {name='charged_inactive_zero',body=[=[

charges={maxCharges=2,currentCharges=0,isActive=false};combat=true;R:SetOption('enabled',true)
time=11;event('SPELL_UPDATE_COOLDOWN',871);dead=true;time=11.01;event('PLAYER_DEAD')
local row=R:GetPage().lastAlive.spells[1];local state,detail=R:ClassifyRecordedCheck(row)
check(state==false and row.currentCharges==0 and row.chargesAt==11 and not row.chargesPendingAt,'Fresh zero charge count was lost or replaced by a normal-cooldown proxy')
]=]},
  {name='charge_item_isolation',body=[=[

bagIDs={5512};C_Item.GetItemCount=function()return 3 end;combat=true;R:SetOption('enabled',true)
time=11;event('UNIT_SPELLCAST_SUCCEEDED','player','cast',6262);local before=R:GetDiagnostics();local oldItems=itemCalls
 time=11.01;event('SPELL_UPDATE_CHARGES');local after=R:GetDiagnostics()
check(itemCalls==oldItems and after.stockQueries==before.stockQueries,'Charge event performed pending item queries')
]=]},
  {name='nil_with_restricted_base',body=[=[

combat=true;R:SetOption('enabled',true);local before=R:GetDiagnostics().spellQueries
time=11;event('SPELL_UPDATE_COOLDOWN',nil,secret,0,0,5512)
check(R:GetDiagnostics().spellQueries==before+1,'Documented nil refresh-all was rejected due to unused base identity')
]=]},
  {name='stale_ticker',body=[=[

cooldown={isEnabled=true,isActive=true};combat=true;R:SetOption('enabled',true)
local oldTicker=timers[#timers];check(oldTicker.repeating,'Expected active ticker')
R:SetOption('enabled',false);time=20;R:SetOption('enabled',true);local before=R:GetDiagnostics().spellQueries
cooldown={isEnabled=true,isActive=false};time=20.01;fire(oldTicker,true)
check(R:GetDiagnostics().spellQueries==before,'Cancelled ticker read and mutated the new session')
]=]},
  {name='unchanged_roster_unknown',body=[=[

RA.DeathRecapCatalog.entries[2]={key='other',spellID=999,name='Other',class='WARRIOR',specs={73},knownSpellIDs={999},category='major',verified=true}
C_SpellBook.IsSpellKnown=function(id)return id==871 end;combat=true;R:SetOption('enabled',true)
time=11;event('UNIT_SPELLCAST_SUCCEEDED','player','cast',871)
C_SpellBook.IsSpellKnown=function(id)if id==871 then return true else return secret end end
time=12;event('SPELLS_CHANGED');dead=true;time=13;event('PLAYER_DEAD');local page=R:GetPage()
check(page.observedUses[871] and page.observedUses[871].observedCount==1,'Unchanged tracked roster lost valid use history when excluded candidate became unknown')
]=]},
  {name='direct_isolation_and_context',body=[=[

local chargeCalls=0;C_Spell.GetSpellCharges=function()chargeCalls=chargeCalls+1;return charges end
C_Spell.GetBaseSpell=function(id)return id==871 and 123 or id end
bagIDs={5512};C_Item.GetItemCount=function()return 3 end;combat=true;R:SetOption('enabled',true)
local b=R:GetDiagnostics();local q=chargeCalls
cooldown={isEnabled=true,isActive=true,isOnGCD=true};time=11;event('SPELL_UPDATE_COOLDOWN',999,123,-1,0,5512)
cooldown={isEnabled=true,isActive=true,isOnGCD=false};time=11.01;event('SPELL_UPDATE_COOLDOWN',871,nil,-2,0,5512)
local a=R:GetDiagnostics();check(a.spellQueries==b.spellQueries+2,'Missed synchronous flags within coalescing window');check(chargeCalls==q+2 and a.itemQueries==b.itemQueries and a.stockQueries==b.stockQueries,'Direct callback missed matched charge snapshots or queried other domains')
dead=true;time=11.02;event('PLAYER_DEAD');local d=R:GetPage().lastAlive.spells[1].directCooldown
check(d.context.payload[3].value==-2 and d.context.payload[4].value==0 and d.context.payload[5].value==5512 and d.isOnGCD==false,'Direct payload/GCD false lost')
]=]},
}
for _,case in ipairs(cases)do assert(loadstring(prefix..case.body,case.name))()end
print('PASS: '..#cases..' independent direct-event/pending/identity/lifecycle contract scenarios')
