-- Actual modules and restricted fixture. No native input, taint, terrain or ACK claim.
local f=assert(io.open('tests/marker_radial.lua'));local source=f:read('*a');f:close()
source=source:sub(1,assert(source:find('RaidArsenalDB = {profile = {schemaVersion = 19',1,true))-1)
source=source..[=[
local native,reads,bad={},0,nil
local secret=setmetatable({},{__tostring=function()error('Secret conversion')end})
function issecretvalue(value)return rawequal(value,secret)end
function IsRaidMarkerActive(marker)
    check(not restricted and not combat,'Activity query inside restricted/combat code')
    reads=reads+1;if bad==marker then return secret end;return native[marker]==true
end
RaidArsenalDB={profile={schemaVersion=19}}
local RA,cycle,clear,eventFrame=loadAddon()
local function event(name)eventFrame.scripts.OnEvent(eventFrame,name)end
check(reads==0,'OFF markers queried activity')
RA.WorldMarkers:SetEnabled(true);RA.WorldMarkers:SetOrder({3,4,2});RA.WorldMarkers:SetRadialEnabled(true)
check(not RA.WorldMarkers:IsRadialEnabled() and not named.RCPArsenalWorldMarkerRadial,'Unbound optional wheel created UI')
keys[wheelBinding]={'F12'};event('UPDATE_BINDINGS')
local wheel=named.RCPArsenalWorldMarkerWheel
local function point(x,y)move((UIParent.left+x)*UIParent.scale,(UIParent.bottom+y)*UIParent.scale)end
local function key(dx,dy)
    point(960,540);dispatch(cycle,true);point(960+(dx or 0),540+(dy or 0));dispatch(cycle,false)
end
local function manual(marker)
    point(960,540);dispatch(wheel,true)
    local icon=wheel:GetFrameRef('center').slots[marker]
    local l,b,w,h=icon:GetRect();move((l+w/2)*icon:GetEffectiveScale(),(b+h/2)*icon:GetEffectiveScale())
    dispatch(wheel,false)
end
for _,scale in ipairs({0.64,0.8,1,1.25})do
    UIParent.scale=scale
    for _,point in ipairs({{0,0},{26,0},{100,0},{-500,200},{1200,1200}})do
        RA.WorldMarkers:SetOrder({3,4,2});key(point[1],point[2]);local action=RA.WorldMarkers:GetLastAction()
        check(action.branch=='cursor' and action.marker==3 and action.position==1 and action.macro=='/wm [@cursor] 3','Independent primary chose reticle')
    end
    for marker=1,8 do manual(marker);local action=RA.WorldMarkers:GetLastAction()
        check(action.branch=='wheel' and action.marker==marker and action.macro=='/wm '..marker,'Manual world-marker mapping differs')
    end
end
UIParent.scale=1
native={[3]=true};RA.WorldMarkers:SetOrder({3,4,2});event('RAID_TARGET_UPDATE');key()
check(RA.WorldMarkers:GetLastAction().macro=='/wm [@cursor] 4','Confirmed Diamond was overwritten')
native={};RA.WorldMarkers:SetOrder({3,4,2});manual(3)
check(cycle:GetAttribute('rcp-pending-marker')==3 and cycle:GetAttribute('index')==1,'Reticle arm claimed placement ACK')
key();check(RA.WorldMarkers:GetLastAction().macro=='/wm [@cursor] 3','Readable inactive/cancelled manual marker advanced sequence')
RA.WorldMarkers:SetOrder({8,3,4});manual(3);native[3]=true;event('RAID_TARGET_UPDATE');key()
check(RA.WorldMarkers:GetLastAction().macro=='/wm [@cursor] 4','Manual Diamond did not guide custom order')
RA.WorldMarkers:SetOrder({8,4});manual(3);event('RAID_TARGET_UPDATE');key()
check(RA.WorldMarkers:GetLastAction().macro=='/wm [@cursor] 8','Manual marker outside order reordered it')
native={};RA.WorldMarkers:SetOrder({3,4,2});native[1]=true;bad=3
local writes=cycle.writes;check(not RA.WorldMarkers:ResyncActive() and cycle.writes==writes and cycle:GetAttribute('rcp-active-1')==false,'Secret result partially committed snapshot')
bad=nil;check(RA.WorldMarkers:ResyncActive() and cycle:GetAttribute('rcp-active-1')==true,'Readable complete snapshot failed')
native={};RA.WorldMarkers:SetOrder({8,3,4});combat=true
local beforeReads=reads;manual(3);key()
check(reads==beforeReads and RA.WorldMarkers:GetLastAction().macro=='/wm [@cursor] 4','Combat queried activity or lost local manual reservation')
check(RA.WorldMarkers:GetActivityStatusText():find('local issued',1,true),'Combat history limit not disclosed')
combat=false;event('PLAYER_REGEN_ENABLED')
native={[3]=true,[4]=true};RA.WorldMarkers:SetOrder({3,4});key()
check(RA.WorldMarkers:GetLastAction().macro=='/wm [@cursor] 3' and RA.WorldMarkers:GetNextMarker()==4,'All-active wrap or independent next display changed')
dispatch(clear,true);native={};event('RAID_TARGET_UPDATE');key()
check(RA.WorldMarkers:GetLastAction().macro=='/wm [@cursor] 3' and RA.WorldMarkers:GetNextMarker()==4,'Clear/fresh activity failed reset')
RA.WorldMarkers:SetOrder({});local before=#actions;key();local diagnostic=RA.WorldMarkers:GetLastAction()
check(#actions==before and diagnostic.branch=='cursor-blocked' and diagnostic.marker==0 and diagnostic.macro=='','Empty primary diagnostic stale')
manual(8);check(RA.WorldMarkers:GetLastAction().macro=='/wm 8','Empty order disabled independent manual wheel')
RA.WorldMarkers:SetOrder({3,4})
local original=IsRaidMarkerActive
for _,kind in ipairs({'missing','throwing','malformed'})do
    if kind=='missing'then IsRaidMarkerActive=nil elseif kind=='throwing'then IsRaidMarkerActive=function()error('Unavailable')end else IsRaidMarkerActive=function()return 1 end end
    writes=cycle.writes;check(not RA.WorldMarkers:ResyncActive() and cycle.writes==writes,'Unavailable activity changed snapshot')
end
IsRaidMarkerActive=original
local combatAPI=InCombatLockdown
for _,unknown in ipairs({'nil','secret','throwing'})do
    if unknown=='nil'then InCombatLockdown=function()return nil end elseif unknown=='secret'then InCombatLockdown=function()return secret end else InCombatLockdown=function()error('Unknown')end end
    writes=cycle.writes;beforeReads=reads
    check(not RA.WorldMarkers:ResyncActive() and cycle.writes==writes and reads==beforeReads,'Unknown combat allowed activity queries/writes')
end
InCombatLockdown=combatAPI
RA.WorldMarkers:SetInputSuppressed(true,'editor');beforeReads=reads;key();check(reads==beforeReads,'Suppressed primary queried activity')
RA.WorldMarkers:SetInputSuppressed(false,'editor')
RA.WorldMarkers:SetEnabled(false);beforeReads=reads;event('RAID_TARGET_UPDATE');key()
check(reads==beforeReads and not RA.WorldMarkers:IsRadialEnabled(),'Disabled marker tool still queried activity/enabled wheel')
check(randomCalls==0,'Random marker choice introduced')
print('PASS: '..checks..' independent-primary/wheel/activity/history assertions (offline; native acceptance pending)')
]=]
assert(loadstring(source))()
