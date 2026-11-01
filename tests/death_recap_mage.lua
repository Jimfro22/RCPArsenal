-- Current Mage candidate coverage and activation identity are runtime-gated.
local f=assert(io.open('tests/death_recap.lua'));local source=f:read('*a');f:close()
source=source:sub(1,assert(source:find('check(optionalCount()==0',1,true))-1)
source=source..[=[
assert(loadfile('RCPArsenal/DeathRecapCatalog.lua'))('RCPArsenal',RA)
UnitClass=function()return 'Mage','MAGE'end;local selectedSpec=62;GetSpecializationInfo=function()return selectedSpec end
local learned={[45438]=true,[235450]=true,[342245]=true,[55342]=true,[110959]=true,[1309497]=true}
C_SpellBook.IsSpellKnown=function(id)return learned[id]or false end
R:SetOption('enabled',true);combat=true;event('PLAYER_REGEN_DISABLED')
check(R:GetDiagnostics().trackedSpells==5,'Learned Arcane families missing or trigger/return counted as family')
time=199
event('UNIT_SPELLCAST_SUCCEEDED','player','cast',55342);event('UNIT_SPELLCAST_SUCCEEDED','player','cast',110959)
event('UNIT_SPELLCAST_SUCCEEDED','player','cast',110960);event('UNIT_SPELLCAST_SUCCEEDED','player','cast',342247)
time=200;dead=true;event('PLAYER_DEAD');local page=R:GetPage();local audit=R:GetAvailabilityAudit();local ids={}
for _,row in ipairs(audit.spells)do ids[row.spellID]=true end
check(ids[55342]and ids[110959]and ids[45438]and #audit.spells==5,'Mage audit roster omitted selected identities')
check(page.observedUses[55342].observedCount==1 and page.observedUses[110959].observedCount==1 and not page.observedUses[110960]and not page.observedUses[342247],'Trigger or return became initial activation use')
check(#page.casts==2 and page.casts[2].spellID==110959 and page.casts[2].role=='utility'and page.observedUses[110959].role=='utility','Eligible utility activation lost its receipt or role')
for _,row in ipairs(page.knownEntries)do if row.spellID==110959 then check(row.role=='utility','Utility role missing from frozen eligibility')end end
for _,row in ipairs(page.lastAlive.spells)do if row.spellID==110959 then check(row.role=='utility','Utility role missing from frozen check')end end
for _,row in ipairs(audit.spells)do if row.spellID==110959 then check(row.role=='utility'and row.use.role=='utility','Utility role missing from audit')end end
check(R:GetRecordedUseRole({spellID=110959})=='utility'and R:GetRecordedUseRole({spellID=110959,role='defensive'})=='utility','Legacy Greater Invisibility became a defensive')
check(R:GetRecordedUseRole({spellID=55342})=='utility'and R:GetRecordedUseRole({spellID=45438,role='utility'})=='utility','Explicit utility/default defensive role changed')
check(R:GetRecordedUseRole(secret)=='defensive'and R:GetRecordedUseRole({role=secret,spellID=secret})=='defensive','Opaque role fields were trusted')
check(R:GetRecordedUseRole(setmetatable({},{__index=function()error('Role indexed metatable')end}))=='defensive','Role read non-plain table')
R:SetOption('enabled',false);dead=false;learned[45438]=nil;learned[414658]=true;R:SetOption('enabled',true);dead=true;event('PLAYER_DEAD');ids={}
for _,row in ipairs(R:GetAvailabilityAudit().spells)do ids[row.spellID]=true end
check(ids[414658]and not ids[45438]and R:GetDiagnostics().trackedSpells==5,'Ice Cold replacement omitted or doubled family')
R:SetOption('enabled',false);dead=false;learned[55342]=nil;learned[110959]=nil;R:SetOption('enabled',true)
check(R:GetDiagnostics().trackedSpells==3,'Unlearned Mage talents treated as available')
R:SetOption('enabled',false);learned[66]=true;R:SetOption('enabled',true)
check(R:GetDiagnostics().trackedSpells==3,'Ordinary Invisibility created Greater Invisibility eligibility')
event('UNIT_SPELLCAST_SUCCEEDED','player','cast',66);event('UNIT_SPELLCAST_SUCCEEDED','player','cast',110959)
dead=true;event('PLAYER_DEAD');page=R:GetPage()
check(#page.casts==0 and not page.observedUses[66]and not page.observedUses[110959],'Ordinary or unlearned Invisibility receipt gained tracked utility identity')
-- Capture-time qualification controls Mirror's defensive role, including old
-- pages. Passive/effect identities never become successful activation receipts.
local qualifiedPage=page
for _,case in ipairs({{62,true,'defensive'},{62,false,'utility'},{62,secret,'utility'},{63,true,'utility'},{64,true,'utility'}})do
 R:SetOption('enabled',false);dead=false;selectedSpec=case[1];learned[55342]=true;learned[1309497]=case[2]
 R:SetOption('enabled',true);event('UNIT_SPELLCAST_SUCCEEDED','player','mirror',55342)
 for _,id in ipairs({1309497,1309793,1309787})do event('UNIT_SPELLCAST_SUCCEEDED','player','effect',id)end
 dead=true;event('PLAYER_DEAD');local frozen=R:GetPage();local mirror
 for _,row in ipairs(frozen.knownEntries)do if row.spellID==55342 then check(not mirror,'Mirror duplicated by utility fallback');mirror=row end end
 check(mirror and mirror.role==case[3]and R:GetRecordedUseRole(mirror)==case[3],'Mirror role ignored spec/current public talent qualification')
 check(#frozen.casts==1 and frozen.casts[1].spellID==55342 and R:GetRecordedUseRole(frozen.casts[1])==case[3],'Mirror receipt role or activation identity lost')
 check((mirror.defensiveTalentSpellID==1309497)==(case[3]=='defensive'),'Talent qualification was fabricated or omitted')
end
check(R:GetRecordedUseRole({spellID=55342,role='defensive'})=='utility','Legacy unqualified Mirror became defensive')
check(R:GetRecordedUseRole({spellID=55342,role='defensive',defensiveTalentSpellID=secret})=='utility','Opaque talent granted Mirror defensive role')
check(R:GetRecordedUseRole({spellID=55342,role='defensive',defensiveTalentSpellID=1309497})=='defensive','Frozen public qualification was lost')
R:SetOption('enabled',false)
print('PASS: '..checks..' Mage learned/override/activation-family assertions (offline; native delivery pending)')
]=]
assert(loadstring(source,'death-recap-mage-fixture'))()
