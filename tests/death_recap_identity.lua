-- Actual recorder lifecycle with a guarded player-name mock installed before
-- initialization. Historical reads must never query the current character.
local f=assert(io.open('tests/death_recap.lua'));local source=f:read('*a');f:close()
source=source:sub(1,assert(source:find('check(optionalCount()==0',1,true))-1)
local install=assert(source:find("assert(loadfile('RCPArsenal/HealingSupplies.lua'))",1,true))
source=source:sub(1,install-1)..[=[
local nameReads,classReads,fullReads,shortReads=0,0,0,0
local currentName,currentRealm,currentClass,nameError='SessionOne','RealmOne','WARRIOR',false
local function ReadIdentity(unit)
 check(unit=='player','Identity capture queried a remote unit');nameReads=nameReads+1
 if nameError then error('Player name unavailable')end
 return currentName,currentRealm
end
function UnitFullName(unit)fullReads=fullReads+1;return ReadIdentity(unit)end
function UnitName(unit)shortReads=shortReads+1;return ReadIdentity(unit)end
function UnitClass(unit)
 check(unit=='player','Class capture queried a remote unit');classReads=classReads+1
 return 'Localized class',currentClass
end
]=]..source:sub(install)
source=source..[=[
check(nameReads==0 and classReads==0 and optionalCount()==0,'Disabled initialization queried player identity')
for _,name in ipairs({'PLAYER_REGEN_DISABLED','PLAYER_DEAD','PLAYER_ALIVE','PLAYER_ENTERING_WORLD','SPELLS_CHANGED'})do event(name)end
for i=1,10 do R:GetPage();R:GetState();R:GetDiagnostics()end
R:Refresh();check(nameReads==0 and classReads==0,'Disabled events or reads queried identity')

combat=true;R:SetOption('enabled',true)
check(nameReads==1 and fullReads==1 and shortReads==0 and classReads==1,'New combat session did not prefer exactly one full-name query')
currentName,currentRealm,currentClass='LaterLiveName','LaterRealm','MAGE'
for i=1,10 do R:GetPage();R:GetState();R:GetDiagnostics()end
event('UNIT_SPELLCAST_SUCCEEDED','player','cast',871);event('SPELL_UPDATE_COOLDOWN')
check(nameReads==1,'Rendering or ordinary capture refreshed session identity')
dead=true;time=time+1;event('PLAYER_DEAD');local first=R:GetPage()
check(first and first.playerName=='SessionOne'and first.playerRealm=='RealmOne'and first.class=='WARRIOR','Death replaced frozen name, realm or class with live identity')
check(nameReads==1 and classReads==1,'Death queried live name or class')
event('PLAYER_DEAD');R:SetOption('autoOpen',false)
for i=1,10 do
 check(R:GetPage()==first and R:GetPage().playerName=='SessionOne'and first.playerRealm=='RealmOne','Historical getter replaced frozen identity')
 R:GetState();R:GetDiagnostics();R:GetSupplyFamilies(first)
end
check(nameReads==1 and classReads==1,'Duplicate death, preferences or historical views re-read identity')

dead=false;time=time+1;event('PLAYER_ALIVE')
check(nameReads==2 and classReads==2,'New alive session did not capture the changed identity once')
currentName,currentRealm,currentClass='ChangedAgain','ChangedRealm','WARRIOR';dead=true;time=time+1;event('PLAYER_DEAD')
local second=R:GetPage()
check(second~=first and second.playerName=='LaterLiveName'and second.playerRealm=='LaterRealm'and second.class=='MAGE','Next session did not freeze its own name/realm/class')
check(first.playerName=='SessionOne'and first.playerRealm=='RealmOne'and first.class=='WARRIOR'and nameReads==2 and classReads==2,'New session rewrote old identity or death queried again')
R:SetOption('enabled',false);local disabledReads=nameReads
for _,name in ipairs({'PLAYER_REGEN_DISABLED','PLAYER_DEAD','PLAYER_ALIVE','PLAYER_ENTERING_WORLD','SPELLS_CHANGED'})do event(name)end
R:GetPage();R:GetState();R:GetDiagnostics();R:Refresh()
check(nameReads==disabledReads,'Disabled recorder retained identity demand')
R:SetOption('enabled',true);check(nameReads==disabledReads,'Enable while dead queried or invented a new session identity');R:SetOption('enabled',false)

local function CaptureIdentity(value,realm,expected,expectedRealm,label,throws,expectedQueries)
 dead=false;combat=true;time=time+1;currentName=value;currentRealm=realm;nameError=throws==true
 local before,beforeShort=nameReads,shortReads;R:SetOption('enabled',true)
 check(nameReads==before+(expectedQueries or 1),label..' changed the one-query session capture contract')
 if UnitFullName then check(shortReads==beforeShort,label..' queried the fallback despite an available full-name API')end
 currentName,currentRealm='Different live name','Different live realm';nameError=false;dead=true;time=time+1;event('PLAYER_DEAD')
 local page=R:GetPage()
 check(page and page.playerName==expected and page.playerRealm==expectedRealm,label..' was accepted, synthesized or replaced at death')
 check(nameReads==before+(expectedQueries or 1),label..' caused a death-time identity query')
 R:SetOption('enabled',false)
end
local function CaptureName(value,expected,label,throws,expectedQueries)
 CaptureIdentity(value,'CapturedRealm',expected,expected and'CapturedRealm'or nil,label,throws,expectedQueries)
end
CaptureName('A','A','One-character public name')
CaptureName(string.rep('N',128),string.rep('N',128),'128-byte public name')
CaptureName('Jímfro','Jímfro','Public UTF-8 name')
for _,case in ipairs({
 {label='Nil name'},
 {label='Empty name',value=''},
 {label='Oversized name',value=string.rep('N',129)},
 {label='Boolean name',value=false},
 {label='Numeric name',value=123},
 {label='Table name',value={}},
 {label='Secret name',value=secret},
 {label='Color markup',value='|cffffffffName|r'},
 {label='Link markup',value='|Hplayer:Name|hName|h'},
 {label='Texture markup',value='|TInterface\\Icons\\INV_Misc_QuestionMark:16|t'},
 {label='API error',value='Never exposed',throws=true},
})do CaptureName(case.value,nil,case.label,case.throws)end
for byte=0,31 do CaptureName('Before'..string.char(byte)..'After',nil,'Control byte '..byte)end
CaptureName('Before'..string.char(127)..'After',nil,'Delete control byte')
for _,case in ipairs({
 {label='Nil realm'}, {label='Empty realm',value=''},
 {label='Oversized realm',value=string.rep('R',129)},
 {label='Boolean realm',value=false}, {label='Numeric realm',value=123},
 {label='Table realm',value={}}, {label='Secret realm',value=secret},
 {label='Realm markup',value='Realm|r'},
})do CaptureIdentity('CapturedName',case.value,'CapturedName',nil,case.label)end
for byte=0,31 do CaptureIdentity('CapturedName','Before'..string.char(byte)..'After','CapturedName',nil,'Realm control byte '..byte)end
CaptureIdentity('CapturedName','Before'..string.char(127)..'After','CapturedName',nil,'Realm delete control byte')
CaptureIdentity('CapturedName',string.rep('R',128),'CapturedName',string.rep('R',128),'128-byte public realm')
check(shortReads==0,'Full-name capture silently used a second identity query')
local fullAPI,nameAPI=UnitFullName,UnitName;UnitFullName=nil
local beforeFallback=shortReads
CaptureIdentity('FallbackName','FallbackRealm','FallbackName','FallbackRealm','Absent full-name API fallback')
check(shortReads==beforeFallback+1,'Unavailable full-name API did not use one guarded UnitName fallback')
UnitName=nil;CaptureName(nil,nil,'Unavailable identity APIs',false,0)
UnitFullName,UnitName=fullAPI,nameAPI
check(optionalCount()==0,'Identity cases left the recorder enabled')
print('PASS: '..checks..' frozen session player identity, public-value validation and disabled-demand assertions (offline)')
]=]
assert(loadstring(source,'death-recap-identity-fixture'))()
