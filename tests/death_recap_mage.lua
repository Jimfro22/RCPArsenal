-- Current Mage candidate coverage and activation identity are runtime-gated.
local f=assert(io.open('tests/death_recap.lua'));local source=f:read('*a');f:close()
source=source:sub(1,assert(source:find('check(optionalCount()==0',1,true))-1)
source=source..[=[
assert(loadfile('RCPArsenal/DeathRecapCatalog.lua'))('RCPArsenal',RA)
UnitClass=function()return 'Mage','MAGE'end;GetSpecializationInfo=function()return 62 end
local learned={[45438]=true,[235450]=true,[342245]=true,[55342]=true,[110959]=true}
C_SpellBook.IsSpellKnown=function(id)return learned[id]or false end
R:SetOption('enabled',true);combat=true;event('PLAYER_REGEN_DISABLED')
check(R:GetDiagnostics().trackedSpells==5,'Learned Arcane families missing or trigger/return counted as family')
event('UNIT_SPELLCAST_SUCCEEDED','player','cast',55342);event('UNIT_SPELLCAST_SUCCEEDED','player','cast',110959)
event('UNIT_SPELLCAST_SUCCEEDED','player','cast',110960);event('UNIT_SPELLCAST_SUCCEEDED','player','cast',342247)
time=200;dead=true;event('PLAYER_DEAD');local page=R:GetPage();local audit=R:GetAvailabilityAudit();local ids={}
for _,row in ipairs(audit.spells)do ids[row.spellID]=true end
check(ids[55342]and ids[110959]and ids[45438]and #audit.spells==5,'Mage audit roster omitted selected identities')
check(page.observedUses[55342].observedCount==1 and page.observedUses[110959].observedCount==1 and not page.observedUses[110960]and not page.observedUses[342247],'Trigger or return became initial activation use')
R:SetOption('enabled',false);dead=false;learned[45438]=nil;learned[414658]=true;R:SetOption('enabled',true);dead=true;event('PLAYER_DEAD');ids={}
for _,row in ipairs(R:GetAvailabilityAudit().spells)do ids[row.spellID]=true end
check(ids[414658]and not ids[45438]and R:GetDiagnostics().trackedSpells==5,'Ice Cold replacement omitted or doubled family')
R:SetOption('enabled',false);dead=false;learned[55342]=nil;learned[110959]=nil;R:SetOption('enabled',true)
check(R:GetDiagnostics().trackedSpells==3,'Unlearned Mage talents treated as available')
R:SetOption('enabled',false)
print('PASS: '..checks..' Mage learned/override/activation-family assertions (offline; native delivery pending)')
]=]
assert(loadstring(source,'death-recap-mage-fixture'))()
