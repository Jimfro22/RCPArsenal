-- Owner3077: exact public potion checks from the pasted alpha.41 debug export.
-- Healthstone possession was not included in that export, so no owner absence
-- is invented. Separate supplied-state cases exercise the new direct checks.
local f=assert(io.open('tests/death_recap.lua'));local prefix=f:read('*a');f:close()
prefix=prefix:sub(1,assert(prefix:find('check(optionalCount()==0',1,true))-1)
assert(loadstring(prefix..[=[
local page={id=3,diedAt=20805.893,lastAlive={observedAt=20805.813000000002,source='item-event',supplies={
 {kind='stone',carriedAt=20803.786,cooldown='unknown',observedAt=20805.813000000002,pendingAt=20805.863000000001},
 {kind='potion',itemID=241305,physicalCount=299,remainingUses=299,cooldown='active',observedAt=20805.813000000002,pendingAt=20805.863000000001},
}},deathObservation={observedAt=20805.893,source='death-notification',supplies={
 {kind='stone',carriedAt=20803.786,cooldown='unknown',observedAt=20805.893},
 {kind='potion',itemID=241305,physicalCount=299,remainingUses=299,cooldown='active',observedAt=20805.893},
}}}
local families=R:GetSupplyFamilies(page)
check(families[2].familyState==false,'Owner3077 public potion cooldown was erased by earlier pending flag')
check(families[1].familyState==nil,'Owner Healthstone absence was invented from omitted fields')
check(families[2].sampleSource=='death-notification'and families[2].members[1].row.observedAt==20805.893,'Fresh item checks borrowed the living check timestamp')
local projected=R:GetCooldownRows(page)
check(projected[2].kind=='potion'and projected[2].recordedState==false,'Cooldown projection ignored fresh potion evidence')
check(page.lastAlive.supplies[2].pendingAt==20805.863000000001,'Display cleared the original pending evidence')
-- A stale/foreign sample cannot be relabelled as this death's item check.
page.deathObservation.observedAt=20804
check(R:GetSupplyFamilies(page)[2].familyState==nil,'Pre-death sample was accepted as death-notice evidence')
page.deathObservation.observedAt=20805.893;page.deathObservation.source='other'
check(R:GetSupplyFamilies(page)[2].familyState==nil,'Wrong observation source became death-notice evidence')
page.deathObservation.source='death-notification';page.deathObservation.supplies[2].partial=true
local partial=R:GetSupplyFamilies(page)[2]
check(partial.familyState==nil and partial.members[1].state==false,'Known potion cooldown erased alternative-item uncertainty, or uncertainty erased the known cooldown')

RA.DeathRecapCatalog.healthstoneItemIDs={5512,224464}
RA.DeathRecapCatalog.itemNames={[241305]='Silvermoon Health Potion',[5512]='Healthstone',[224464]='Demonic Healthstone'}
local counts,queries={[5512]={0,0},[224464]={0,0},[241305]={299,299}},{}
bagIDs={241305}
C_Item.GetItemCount=function(id,bank,uses)
 check(bank==false,'Death count queried the bank')
 queries[#queries+1]=id
 local row=counts[id];return row and row[uses and 2 or 1]
end
C_Item.GetItemCooldown=function(id)return id==241305 and 11 or 0,id==241305 and 300 or 0,true end
combat=true;R:SetOption('enabled',true)
time=11;event('BAG_UPDATE_COOLDOWN');time=11.05;event('BAG_UPDATE_COOLDOWN')
local beforeDeath=#queries;time=11.08;dead=true;event('PLAYER_DEAD')
local death=R:GetPage();families=R:GetSupplyFamilies(death)
check(#queries-beforeDeath==6,'Death count checks exceeded two Healthstones and one cached potion')
check(families[1].familyState==false and families[1].familyReason=='absent','Confirmed zero Healthstones did not become unavailable')
check(families[2].familyState==false and families[2].familyReason=='cooldown','Carried potion cooldown did not become unavailable')
assert(loadfile('RCPArsenal/DeathRecapDebug.lua'))('RCPArsenal',RA)
local facts=assert(R:BuildCoreFactsText())
check(facts:find('Healthstone: None in bags',1,true)and facts:find('Silvermoon Health Potion: 299 in bags; On cooldown',1,true),'Plain facts hid stock or cooldown reason')
local debug=assert(R:BuildDebugText())
check(debug:find('physicalCount=0',1,true)and debug:find('inventorySource="native-item-count"',1,true),'Diagnostic omitted direct zero-count evidence')
R:SetOption('enabled',false);dead=false;combat=true
-- No warlock/roster lookup is involved. A carried stone stays usable even if
-- it was not discovered by the cached bag scan.
counts[5512]={1,2};R:SetOption('enabled',true);time=20;dead=true;event('PLAYER_DEAD')
check(R:GetSupplyFamilies(R:GetPage())[1].familyState==true,'Direct carried stone was hidden because the cache/provider was absent')
R:SetOption('enabled',false);dead=false;counts[5512]={1,0};R:SetOption('enabled',true);time=21;dead=true;event('PLAYER_DEAD')
families=R:GetSupplyFamilies(R:GetPage())
check(families[1].familyState==false and families[1].familyReason=='empty','Depleted Healthstone was treated as usable or absent')
R:SetOption('enabled',false);dead=false;counts[5512]={secret,secret};R:SetOption('enabled',true);time=22;dead=true;event('PLAYER_DEAD')
check(R:GetSupplyFamilies(R:GetPage())[1].familyState==nil,'Restricted Healthstone count became a false absence')
-- Two direct stones plus all 32 cached potion candidates must survive every
-- projection/persistence boundary, including a usable final potion.
local crowded={id=99,diedAt=30,lastAlive={supplies={}},deathObservation={observedAt=30,source='death-notification',supplies={}}}
for _,id in ipairs({5512,224464})do crowded.deathObservation.supplies[#crowded.deathObservation.supplies+1]={kind='stone',itemID=id,physicalCount=0,remainingUses=0}end
for i=1,32 do crowded.deathObservation.supplies[#crowded.deathObservation.supplies+1]={kind='potion',itemID=10000+i,physicalCount=1,remainingUses=1,cooldown=i==32 and'inactive'or'active'}end
check(R:GetCooldownRows(crowded)[2].recordedState==true,'Projection discarded the usable 34th supply row')
local saved=RA.DeathRecapHistory:Snapshot(crowded)
check(#saved.deathObservation.supplies==34 and R:GetCooldownRows(saved)[2].recordedState==true,'Saved history discarded the final supply candidate')
R:SetOption('enabled',false)
print('PASS: '..checks..' owner3077 potion and direct Healthstone death-check assertions')
]=]))()
