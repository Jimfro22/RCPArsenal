-- Ground-truth scenarios feed the actual recorder through its event handlers.
-- Public/restricted API answers are supplied; this does not certify Retail.
local f=assert(io.open('tests/death_recap.lua'));local prefix=f:read('*a');f:close()
prefix=prefix:sub(1,assert(prefix:find('check(optionalCount()==0',1,true))-1)
local total=0
local cases={
 {name='one of two Barriers spent',charges=1,spent=1,expected=true},
 {name='both Barriers spent',charges=0,spent=2,expected=false},
 {name='used Barrier recharged',charges=2,spent=1,expected=true},
 {name='restricted Barrier count',charges='restricted',spent=1,expected='unconfirmed'},
 {name='death before charge callback',charges=1,spent=1,pending=true,expected='unconfirmed'},
}
for _,case in ipairs(cases)do
    CORE_CASE=case
    total=total+assert(loadstring(prefix..[=[
local case=CORE_CASE
UnitClass=function()return 'Mage','MAGE' end
GetSpecializationInfo=function()return 62 end
RA.DeathRecapCatalog={entries={
 {key='barrier',spellID=235450,name='Prismatic Barrier',class='MAGE',specs={62},knownSpellIDs={235450},category='minor',verified=true},
 {key='ice',spellID=414658,name='Ice Cold',class='MAGE',specs={62},knownSpellIDs={414658},category='major',verified=true},
},itemUseSpells={[6262]=true,[431416]=true}}
local spellCharges={
 [235450]={maxCharges=2,currentCharges=2,isActive=false},
 [414658]={maxCharges=1,currentCharges=1,isActive=false},
}
local spellCooldowns={
 [235450]={isEnabled=true,isActive=false},
 [414658]={isEnabled=true,isActive=false},
}
C_Spell.GetSpellCharges=function(id)return spellCharges[id]end
C_Spell.GetSpellCooldown=function(id)return spellCooldowns[id]end
local stock={[5512]=3,[241304]=1}
bagIDs={5512,241304}
C_Item.GetItemCount=function(id)return stock[id]or 0 end
local itemCooldowns={}
C_Item.GetItemCooldown=function(id)
 if itemCooldowns[id]then return 11,300,true end
 return 0,0,true
end
R:SetOption('enabled',true)
local baseline=assert(R:CheckCharacter())
check(baseline.spells[1].currentCharges==2 and baseline.spells[2].currentCharges==1,'Precombat kit/charge baseline wrong')
local idleQueries=R:GetDiagnostics().spellQueries
time=20
for i=1,20 do R:GetDiagnostics();R:GetState()end
check(R:GetDiagnostics().spellQueries==idleQueries and not R:GetDiagnostics().tickerActive,'Idle core check created polling')
combat=true;event('PLAYER_REGEN_DISABLED')
for i=1,case.spent do
 time=21+i;event('UNIT_SPELLCAST_SUCCEEDED','player','barrier-'..i,235450)
end
spellCharges[235450]={maxCharges=2,currentCharges=case.charges=='restricted'and secret or case.charges,isActive=case.charges~=2}
if not case.pending then time=24;event('SPELL_UPDATE_CHARGES')end
time=24.1;event('UNIT_SPELLCAST_SUCCEEDED','player','ice',414658)
spellCharges[414658]={maxCharges=1,currentCharges=0,isActive=false}
spellCooldowns[414658]={isEnabled=true,isActive=true,isOnGCD=false}
time=24.2;event('SPELL_UPDATE_COOLDOWN',414658)
time=24.3;event('UNIT_SPELLCAST_SUCCEEDED','player','stone',6262)
stock[5512]=2;itemCooldowns[5512]=true
event('BAG_UPDATE_COOLDOWN')
time=24.5;dead=true;event('PLAYER_DEAD')
local page=R:GetPage();local rows=R:GetCooldownRows(page)
local byID={};local stone,potion
for _,row in ipairs(rows)do
 if row.spellID then byID[row.spellID]=row elseif row.kind=='stone'then stone=row elseif row.kind=='potion'then potion=row end
end
local expected=case.expected;if expected=='unconfirmed'then expected=nil end
check(byID[235450].recordedState==expected,'Barrier availability wrong: '..case.name)
check(byID[414658].recordedState==false,'Ice Cold with zero charges appeared available')
check(stone.recordedState==false and potion.recordedState==true,'Independent carried Healthstone/potion readiness wrong')
check(page.observedUses[235450].observedCount==case.spent and page.observedUses[414658].observedCount==1,'Defensive use count was inferred from cooldown rather than receipts')
check(page.observedUses[6262].observedCount==1 and not page.observedUses[431416],'Consumable used/unused receipts were conflated')
check(page.precombatBaseline.spells[1].currentCharges==2,'Combat overwrote starting charge count')
if case.charges=='restricted'then check(byID[235450].currentCharges==nil,'Restricted count was invented from precombat kit/use count')end
local oldState=byID[235450].recordedState
assert(loadfile('RCPArsenal/DeathRecapDebug.lua'))('RCPArsenal',RA)
local facts=assert(R:BuildCoreFactsText())
check(facts:find('Prismatic Barrier: Used '..case.spent,1,true)and facts:find('Ice Cold: Used 1 time',1,true),'Core facts omitted named defensive receipts')
if case.charges=='restricted'then check(facts:find('charge count restricted by Blizzard',1,true),'Core facts concealed missing native charge evidence')end
spellCharges[235450]={maxCharges=2,currentCharges=2,isActive=false}
spellCooldowns[414658]={isEnabled=true,isActive=false}
event('SPELL_UPDATE_CHARGES');event('SPELL_UPDATE_COOLDOWN')
for _,row in ipairs(R:GetCooldownRows(page))do if row.spellID==235450 then check(row.recordedState==oldState,'Postdeath recharge changed frozen availability')end end
local q=R:GetDiagnostics().spellQueries
for i=1,20 do R:GetCooldownRows(page);R:GetAvailabilityAudit()end
check(R:GetDiagnostics().spellQueries==q,'Reading a death queried current cooldowns')
R:SetOption('enabled',false)
check(optionalCount()==0 and not R:GetDiagnostics().tickerActive,'Core tracking continued while OFF')
print('PASS scenario: '..case.name)
return checks
]=]))()
end
CORE_CASE=nil
print('PASS: '..total..' Arcane Mage defensive/consumable/death assertions; '..#cases..' supplied-state scenarios')
