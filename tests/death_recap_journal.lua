-- Real resolver with synthetic native Journal responses. This verifies routing
-- and data boundaries, not the installed client's Journal contents or pixels.
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local secret=setmetatable({},{__tostring=function()error('Restricted value stringified')end})
function issecretvalue(v)return rawequal(v,secret)end
local page,combat,loads,opens,enumerations,sectionReads=nil,false,0,{},0,0
local R={};function R:IsRetainedPage(v)return v==page end
local RA={DeathRecap=R,DeathRecapCatalog={journal={}}}
function RA:RegisterOptionalEvent()return{SetEnabled=function()end}end
function RA:RegisterCallback()end
function InCombatLockdown()return combat end
function EncounterJournal_LoadUI()loads=loads+1 end
EncounterJournal={instanceID=10,encounterID=100}
local tier,difficulty,instance,boss=1,2,10,100
local instances={[1]={[true]={10},[false]={11}},[2]={[true]={20},[false]={21}},[3]={[true]={30},[false]={31}}}
local bosses={[10]={100},[11]={110},[20]={200},[21]={210},[30]={300,301},[31]={310}}
local entries={
 [100]={root=1000,instance=10,combatID=900},[110]={root=1100,instance=11,combatID=901},
 [200]={root=2000,instance=20,combatID=902},[210]={root=2100,instance=21,combatID=903},
 [300]={root=3000,instance=30,combatID=924},[301]={root=3100,instance=30,combatID=925},
 [310]={root=3200,instance=31,combatID=926}}
local sections={
 [3000]={spellID=0,title='Overview',filteredByDifficulty=false,firstChildSectionID=3001,siblingSectionID=3003},
 [3001]={spellID=441,title='Final Ascension',filteredByDifficulty=false,siblingSectionID=3002},
 [3002]={spellID=442,title='Malevolent Presence',filteredByDifficulty=false},
 [3003]={spellID=443,title='Other difficulty',filteredByDifficulty=true,firstChildSectionID=3004},
 [3004]={spellID=444,title='Filtered child',filteredByDifficulty=false},
 [3100]={spellID=445,title='Another boss',filteredByDifficulty=false}}
function EJ_GetCurrentTier()return tier end
function EJ_GetDifficulty()return difficulty end
function EJ_GetNumTiers()return 3 end
function EJ_SelectTier(v)tier=v end
function EJ_SelectInstance(v)instance=v end
function EJ_SelectEncounter(v)boss=v end
function EJ_SetDifficulty(v)difficulty=v end
function EJ_GetInstanceByIndex(i,raid)enumerations=enumerations+1;return instances[tier][raid][i]end
function EJ_GetEncounterInfoByIndex(i,id)
 local id=bosses[id]and bosses[id][i]
 -- The enumeration contract only needs its first three values. Relationship
 -- fields are deliberately absent and must come from GetEncounterInfo(id).
 if id then return 'Boss','Description',id end
end
function EJ_GetEncounterInfo(id)
 local e=entries[id];if e then return 'Boss','Description',id,e.root,'Link',e.instance,e.combatID,700 end
end
C_EncounterJournal={
 GetInstanceForGameMap=function(id)if id==700 then return 30 end end,
 GetSectionInfo=function(id)
  sectionReads=sectionReads+1
  check(difficulty==16 and instance==30 and boss==300,'Sections read in a different boss/difficulty')
  return sections[id]
 end}
function EncounterJournal_OpenJournal(d,i,e,s)
 opens[#opens+1]={difficulty=d,instance=i,encounter=e,section=s}
 check(tier==1 and difficulty==2 and instance==10 and boss==100 or tier==3 and difficulty==2 and instance==10 and boss==100,
  'Resolver did not restore the prior selection before navigation')
end
assert(loadfile('RCPArsenal/DeathRecapActions.lua'))('RCPArsenal',RA)
check(loads==0 and enumerations==0 and sectionReads==0,'Journal work ran without a click')
local function New(spell,name,map)
 local hit={spellID=spell,name=name,rawSpellName=name}
 page={id=1,encounter={encounterID=924,difficulty=16,gameMapID=map},native={rows={hit}}}
 tier,difficulty,instance,boss=1,2,10,100;combat=false
 return hit
end
local hit=New(441,'Final Ascension')
local ok,reason=R:OpenJournal(page,hit)
check(ok and reason=='Journal opened'and #opens==1,'Older page could not discover its native boss')
check(opens[1].difficulty==16 and opens[1].instance==30 and opens[1].encounter==300 and opens[1].section==3001,'Wrong Journal destination')
check(R:GetJournalMapping(page,hit).match=='spellID','Exact native ID match not preferred')
local counted=enumerations;R:OpenJournal(page,hit)
check(enumerations==counted,'Resolved encounter unnecessarily enumerated again')
check(R:OpenJournal(page,{spellID=441,name='Final Ascension'})==false,'Unretained hit accepted')

-- New captures use their frozen game map. Captured spell/tick ID can differ
-- from the Journal parent spell, but the exact title must be unique in boss.
hit=New(1441,'Final Ascension',700);counted=enumerations
ok=R:OpenJournal(page,hit)
check(ok and enumerations==counted and opens[#opens].section==3001,'Captured map or exact section-title fallback failed')
check(R:GetJournalMapping(page,hit).match=='exact-section-title','Fallback misrepresented as a spell-ID match')
sections[3002].title='Final Ascension'
hit=New(1441,'Final Ascension',700);counted=#opens
ok,reason=R:OpenJournal(page,hit)
check(not ok and #opens==counted and reason:find('not listed',1,true),'Ambiguous title selected a guessed section')
check(tier==1 and difficulty==2 and instance==10 and boss==100,'Miss changed the existing Journal selection')
hit=New(441,'Final Ascension',700);ok=R:OpenJournal(page,hit)
check(ok,'Exact spell ID was blocked by duplicate titles');sections[3002].title='Malevolent Presence'

hit=New(1441,'final ascension',700);counted=#opens
check(not R:OpenJournal(page,hit)and #opens==counted,'Fuzzy title match accepted')
hit=New(444,'Filtered child',700)
check(not R:OpenJournal(page,hit),'Wrong-difficulty descendant was traversed')
sections[3002].siblingSectionID=3000;hit=New(441,'Final Ascension',700)
check(R:OpenJournal(page,hit),'Cyclic section pointers prevented a valid bounded lookup');sections[3002].siblingSectionID=nil

-- Missing/restricted/malformed responses never select an arbitrary boss/section.
hit=New(441,'Final Ascension',700);local old=sections[3001].spellID;sections[3001].spellID=secret;sections[3001].title=secret
counted=#opens;check(not R:OpenJournal(page,hit)and #opens==counted,'Restricted section identity used');sections[3001].spellID=old;sections[3001].title='Final Ascension'
hit=New(441,'Final Ascension',700);page.encounter.encounterID=999
check(not R:OpenJournal(page,hit),'Encounter name replaced mismatched combat encounter ID')
hit=New(441,'Final Ascension',700);page.encounter.difficulty=secret
check(not R:OpenJournal(page,hit),'Restricted difficulty accepted')
hit=New(441,'Final Ascension',700);local api=C_EncounterJournal.GetSectionInfo
C_EncounterJournal.GetSectionInfo=function()error('Not loaded')end
check(not R:OpenJournal(page,hit)and tier==1 and difficulty==2 and instance==10 and boss==100,'Error leaked selection or opened Journal');C_EncounterJournal.GetSectionInfo=api

hit=New(441,'Final Ascension',700);combat=true;counted=loads
check(not R:OpenJournal(page,hit)and loads==counted,'Combat request loaded Journal')
combat=false;local loader=EncounterJournal_LoadUI
EncounterJournal_LoadUI=function()loads=loads+1;combat=true end
check(not R:OpenJournal(page,hit),'Combat entered during load was ignored');EncounterJournal_LoadUI=loader;combat=false
hit=New(441,'Final Ascension',700)
local selectDifficulty=EJ_SetDifficulty;EJ_SetDifficulty=function(v)if v~=16 then selectDifficulty(v)end end
check(not R:OpenJournal(page,hit),'Unsupported difficulty accepted');EJ_SetDifficulty=selectDifficulty

-- A positive match is not enough if a malformed/incomplete tree prevents the
-- complete difficulty-scoped verification. Cached sections are revalidated.
hit=New(441,'Final Ascension',700);check(R:OpenJournal(page,hit),'Cache setup failed')
sections[3001].spellID=999;sections[3001].title='Changed ability';counted=#opens
check(not R:OpenJournal(page,hit)and #opens==counted,'Stale cached section bypassed revalidation')
sections[3001].spellID=441;sections[3001].title='Final Ascension'
sections[3002].siblingSectionID=9999
check(not R:OpenJournal(page,hit),'Incomplete Journal tree accepted');sections[3002].siblingSectionID=nil
page=nil;check(not R:OpenJournal({},hit),'Evicted death retained navigation authority')
io.write('PASS: '..checks..' Journal routing, identity, difficulty, cache, restore and failure-boundary assertions (offline)\n')
