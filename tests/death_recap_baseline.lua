local f=assert(io.open('tests/death_recap.lua'));local prefix=f:read('*a');f:close();prefix=prefix:sub(1,assert(prefix:find('check(optionalCount()==0',1,true))-1)
local body=[=[
local q=R:GetDiagnostics().spellQueries
check(not R:CheckCharacter()and bagReads==0,'Disabled check captured or enabled recording')
R:SetOption('enabled',true)
check(bagReads==6 and R:GetDiagnostics().spellQueries==q+1 and #timers==0,'Enable did not take exactly one bounded baseline or added idle polling')
local before=R:CheckCharacter();check(before and before.spells[1].cooldown=='inactive'and before.observedAt==10,'Manual check did not expose actual baseline')
before.spells[1].cooldown='active';check(R:CheckCharacter().spells[1].cooldown=='inactive','Baseline exposed mutable capture')
local reads=R:GetDiagnostics().spellQueries;for i=1,20 do R:GetState();R:GetDiagnostics();R:GetPage()end
check(R:GetDiagnostics().spellQueries==reads and #timers==0,'Read-only idle access polled')
time=11;event('SPELL_UPDATE_COOLDOWN',999999);check(R:GetDiagnostics().spellQueries==reads,'Unmatched baseline event queried tracked spells')
time=12;event('SPELL_UPDATE_COOLDOWN',871);check(R:GetDiagnostics().spellQueries==reads+1,'Matched baseline event did not query selected identity')
local stock=itemCalls;event('BAG_UPDATE_DELAYED');check(itemCalls>=stock and R:GetDiagnostics().spellQueries==reads+1,'Baseline bag event queried spell state')
-- Historical readiness is frozen separately; unknown combat charge counts must
-- not inherit its checkmark, even when normal cooldown remains inactive.
time=20;combat=true;charges={maxCharges=2,currentCharges=secret,isActive=true};event('PLAYER_REGEN_DISABLED')
check(not R:CheckCharacter(),'Character check ran in combat')
dead=true;time=21;event('PLAYER_DEAD');local page=R:GetPage()
check(page.precombatBaseline and page.precombatBaseline.spells[1].cooldown=='inactive'and page.precombatBaseline.frozenAtCombatEntry==20,'Combat discarded actual precombat snapshot/identity')
check(page.precombatBaseline.playerGUID==page.playerGUID and page.precombatBaseline.specID==page.specID,'Baseline identity did not match combat capture')
check(R:ClassifyRecordedCheck(page.lastAlive.spells[1])==nil,'Historical ready state upgraded an unresolved combat check')
local row=R:GetCooldownRows(page)[1]
check(row.recordedState==nil and row.precombatCheck.state==true and table.concat(R:GetPrecombatNotes(row),' '):find('does not establish readiness at death',1,true),'Unresolved icon lost historical baseline or disclaimer')
local frozen=page.precombatBaseline.spells[1].cooldown
charges=nil;dead=false;combat=false;time=22;event('PLAYER_ALIVE');event('SPELL_UPDATE_COOLDOWN',871)
check(page.precombatBaseline.spells[1].cooldown==frozen,'Later idle updates changed old death baseline')
check(not R:GetDiagnostics().tickerActive,'Idle active observers created polling')
RA.DeathRecapCatalog.entries[1].role='utility';event('TRAIT_CONFIG_UPDATED')
check(R:CheckCharacter().spells[1].role=='utility'and #R:GetCooldownRows({lastAlive=R:CheckCharacter()})==2,'Role-only identity refresh retained stale defensive qualification')
local n=R:GetDiagnostics().spellQueries;R:SetOption('enabled',false)
event('SPELL_UPDATE_COOLDOWN',871);event('SPELL_UPDATE_CHARGES');event('BAG_UPDATE_DELAYED');R:CheckCharacter()
check(R:GetDiagnostics().spellQueries==n and optionalCount()==0,'OFF retained baseline capture demand')
print('PASS: '..checks..' precombat baseline/identity/frozen provenance assertions')
]=]
assert(loadstring(prefix..body))()
