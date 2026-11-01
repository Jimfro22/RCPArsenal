-- Actual recorder callbacks with supplied API answers. These scenarios verify
-- recorder logic, not Blizzard's restricted-data behavior or UI appearance.
local f=assert(io.open('tests/death_recap.lua'));local prefix=f:read('*a');f:close()
prefix=prefix:sub(1,assert(prefix:find('check(optionalCount()==0',1,true))-1)
assert(loadstring(prefix..[=[
RA.DeathRecapCatalog.itemUseSpells[431416]=true
RA.DeathRecapCatalog.itemUseNames={[6262]='Healthstone',[431416]='Healing potion'}
combat=true;R:SetOption('enabled',true)
time=11;event('UNIT_SPELLCAST_SUCCEEDED','player','stone',6262)
time=12;event('UNIT_SPELLCAST_SUCCEEDED','player','potion',431416)
time=13;event('UNIT_SPELLCAST_SUCCEEDED','player','defensive',871)
time=14;event('UNIT_SPELLCAST_SUCCEEDED','party1','foreign',6262)
time=15;event('UNIT_SPELLCAST_SUCCEEDED','player','restricted',secret)
time=100;dead=true;event('PLAYER_DEAD')
local page=R:GetPage()
check(#page.casts==0,'Short display ring unexpectedly became an entire-fight log')
check(page.observedUses[871].observedCount==1,'Early defensive use was lost')
check(page.observedUses[6262]and page.observedUses[6262].observedCount==1
 and page.observedUses[6262].lastSuccessfulUseAt==11,'Early Healthstone use was lost before death')
check(page.observedUses[431416]and page.observedUses[431416].observedCount==1
 and page.observedUses[431416].lastSuccessfulUseAt==12,'Early potion use was lost before death')
local saved=RA.DeathRecapHistory:Snapshot(page)
check(saved.observedUses[6262]and saved.observedUses[431416],'Saved death dropped its consumable use evidence')
assert(loadfile('RCPArsenal/DeathRecapDebug.lua'))('RCPArsenal',RA)
local text=R:BuildDebugText()
check(text:find('OBSERVED USE spellID=6262',1,true)and text:find('OBSERVED USE spellID=431416',1,true),'Debug export omitted consumed items')
local audit=R:GetAvailabilityAudit()
check(audit.consumableUses and #audit.consumableUses==2,'Core audit omitted whole-fight consumable use counts')
local queries=R:GetDiagnostics().spellQueries
local facts=assert(R:BuildCoreFactsText())
check(facts:find('Healthstone: Used 1 time; last 89.0s before death',1,true)
 and facts:find('Healing potion: Used 1 time; last 88.0s before death',1,true),'Plain facts lost early item uses or human-readable timing')
check(R:GetDiagnostics().spellQueries==queries,'Reading plain facts queried current cooldowns')
local frozen=page.observedUses[6262].lastSuccessfulUseAt
dead=false;time=101;event('PLAYER_ALIVE');event('PLAYER_REGEN_DISABLED')
time=102;event('UNIT_SPELLCAST_SUCCEEDED','player','second-stone',6262)
check(page.observedUses[6262].lastSuccessfulUseAt==frozen and page.observedUses[6262].observedCount==1,'Later life mutated an earlier death')
check(R:BuildCoreFactsText()==facts,'Resurrection changed the prior death facts')
R:SetOption('enabled',false)
print('PASS: '..checks..' core long-fight item/defensive recording assertions (supplied API answers)')
]=]))()
