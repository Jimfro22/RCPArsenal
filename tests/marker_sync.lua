-- Actual modules and native-scope restricted fixture. No native protection,
-- placement-success, terrain or every-third input cadence claim.
local f=assert(io.open('tests/marker_radial.lua'));local source=f:read('*a');f:close()
source=source:sub(1,assert(source:find('RaidArsenalDB = {profile = {schemaVersion = 19}}',1,true))-1)
source=source..[=[
local native,reads,bad,scale={},0,nil,1
local secret=setmetatable({},{__tostring=function()error('Secret conversion')end})
function issecretvalue(v)return rawequal(v,secret)end
function IsRaidMarkerActive(id)
    check(not restricted and not combat,'Native marker query inside restricted/combat code')
    reads=reads+1
    if bad==id then return secret end
    return native[id]==true
end
RaidArsenalDB={profile={schemaVersion=19}}
local RA,cycle,clear,eventFrame=loadAddon()
local function event(name)eventFrame.scripts.OnEvent(eventFrame,name)end
check(reads==0,'OFF markers queried activity')
RA.WorldMarkers:SetEnabled(true);RA.WorldMarkers:SetOrder({3,4,2});RA.WorldMarkers:SetRadialEnabled(true)
local root=named.RCPArsenalWorldMarkerRadial
function UIParent:GetEffectiveScale()return scale end
function root:GetEffectiveScale()return scale end
function root:GetMousePosition()
    local l,b,w,h=self:GetRect();if not w or not h then return nil end
    local x,y=cursorX/scale-l,cursorY/scale-b
    if x<0 or y<0 or x>w or y>h then return nil end
    return x/w,y/h
end
local function key(dx,dy,displayed)
    move(960*scale,540*scale);dispatch(cycle,true)
    move((960+dx)*scale,(540+dy)*scale)
    if displayed then
        fireTimer(timers[#timers])
        local expected=(dx*dx+dy*dy>71.01*71.01) and 'Release to aim' or 'Center release places next'
        local found=false;for _,frame in ipairs(frames)do if frame:IsVisible() and frame.text==expected then found=true end end
        check(found,'Visual and secure activation boundaries differ')
    end
    dispatch(cycle,false)
end
for _,s in ipairs({0.64,0.8,1,1.25})do
    scale=s
    for _,point in ipairs({{0,0},{26,0},{30,0},{50,50},{71,0},{-71,0}})do
        RA.WorldMarkers:SetOrder({3,4,2});key(point[1],point[2],true)
        local issued=RA.WorldMarkers:GetLastAction()
        check(issued.branch=='center' and issued.marker==3 and issued.position==1 and issued.macro=='/wm [@cursor] 3','Center jitter selected reticle at scale '..s)
    end
    for _,point in ipairs({{71.1,0,3},{0,71.1,1},{-71.1,0,7},{50.3,50.3,2}})do
        key(point[1],point[2],true);local issued=RA.WorldMarkers:GetLastAction()
        check(issued.branch=='sector' and issued.marker==point[3] and issued.macro=='/wm '..point[3],'Sector geometry differs at scale '..s)
    end
end
scale=1
-- No dependence on the freshly reanchored hidden center's rect.
local center=cycle:GetFrameRef('rcp-radial-center');local rect=center.GetRect
center.GetRect=function()error('Center layout queried to classify input')end
RA.WorldMarkers:SetOrder({3,4,2});key(30,0)
check(RA.WorldMarkers:GetLastAction().branch=='center','Stable origin was not used')
center.GetRect=rect
move(960,540);dispatch(cycle,true);local oldWidth=UIParent.width;UIParent.width=1280
local before=#actions;dispatch(cycle,false);check(#actions==before and RA.WorldMarkers:GetLastAction().branch=='ignored','Viewport changed mid-hold but action was issued');UIParent.width=oldWidth
move(960,540);dispatch(cycle,true);scale=0.8;before=#actions;dispatch(cycle,false)
check(#actions==before and RA.WorldMarkers:GetLastAction().branch=='ignored','Scale changed mid-hold but action was issued');scale=1
-- Actual activity, independent of placement source, skips Diamond.
RA.WorldMarkers:SetOrder({3,4,2});native[3]=true;event('RAID_TARGET_UPDATE');key(0,0)
check(RA.WorldMarkers:GetLastAction().macro=='/wm [@cursor] 4','Confirmed active Diamond was overwritten')
-- Own sector arm alone is not an ACK; cancelled OOC reticle restores sequence.
native={};RA.WorldMarkers:SetOrder({3,4,2});key(100,0)
check(cycle:GetAttribute('rcp-pending-marker')==3 and cycle:GetAttribute('index')==1,'Reticle arm was committed as placement')
key(0,0);check(RA.WorldMarkers:GetLastAction().macro=='/wm [@cursor] 3','Inactive/cancelled OOC selection advanced sequence')
-- Native activity observed after manual placement advances by sequence position.
RA.WorldMarkers:SetOrder({8,3,4});key(100,0);native[3]=true;event('RAID_TARGET_UPDATE');key(0,0)
check(RA.WorldMarkers:GetLastAction().macro=='/wm [@cursor] 4','Manual Diamond did not advance custom sequence')
RA.WorldMarkers:SetOrder({8,4});key(100,0);native[3]=true;event('RAID_TARGET_UPDATE');key(0,0)
check(RA.WorldMarkers:GetLastAction().macro=='/wm [@cursor] 8','Sector outside custom order reordered it')
-- A secret result prevents the entire snapshot from being committed.
native={};RA.WorldMarkers:SetOrder({3,4,2});native[1]=true;bad=3
local writes=cycle.writes;check(not RA.WorldMarkers:ResyncActive() and cycle.writes==writes and cycle:GetAttribute('rcp-active-1')==false,'Partial secret snapshot changed protected occupancy')
bad=nil;check(RA.WorldMarkers:ResyncActive() and cycle:GetAttribute('rcp-active-1')==true,'Readable full snapshot failed')
-- Existing secure hardware paths use local issued reservations in combat.
native={};RA.WorldMarkers:SetOrder({8,3,4});combat=true
local beforeReads=reads;key(100,0);key(0,0)
check(reads==beforeReads and RA.WorldMarkers:GetLastAction().macro=='/wm [@cursor] 4','Combat queried activity or ignored local sector reservation')
check(RA.WorldMarkers:GetActivityStatusText():find('local issued',1,true),'Combat activity limitation not disclosed')
combat=false;event('PLAYER_REGEN_ENABLED')
-- Full confirmed occupancy preserves wrap/reuse; inactive markers win first.
native={[3]=true,[4]=true};RA.WorldMarkers:SetOrder({3,4});before=#actions;key(0,0)
check(#actions==before+1 and RA.WorldMarkers:GetLastAction().macro=='/wm [@cursor] 3' and RA.WorldMarkers:GetLastAction().position==1,'All-active snapshot broke configured wrap/reuse')
RA.WorldMarkers:SetRadialEnabled(false);check(RA.WorldMarkers:GetNextMarker()==3,'All-active next display differs from wrap selector')
dispatch(clear,true);native={};event('RAID_TARGET_UPDATE');dispatch(cycle,true)
check(RA.WorldMarkers:GetLastAction().macro=='/wm [@cursor] 3' and RA.WorldMarkers:GetNextMarker()==4,'Clear/fresh snapshot did not reset sequence/display')
RA.WorldMarkers:SetRadialEnabled(true);RA.WorldMarkers:SetOrder({});before=#actions;key(0,0)
local diagnostic=RA.WorldMarkers:GetLastAction()
check(#actions==before and diagnostic.branch=='center-blocked' and diagnostic.marker==0 and diagnostic.position==0 and diagnostic.macro=='','Empty sequence no-op diagnostic is stale')
RA.WorldMarkers:SetOrder({3,4})
local old=IsRaidMarkerActive
for _,kind in ipairs({'missing','throwing','malformed'})do
    if kind=='missing' then IsRaidMarkerActive=nil elseif kind=='throwing' then IsRaidMarkerActive=function()error('Unavailable')end else IsRaidMarkerActive=function()return 1 end end
    writes=cycle.writes;check(not RA.WorldMarkers:ResyncActive() and cycle.writes==writes,'Unavailable activity wrote a partial state: '..kind)
end
IsRaidMarkerActive=old
local combatAPI=InCombatLockdown
for _,unknown in ipairs({'nil','secret','throwing'})do
    if unknown=='nil' then InCombatLockdown=function()return nil end elseif unknown=='secret' then InCombatLockdown=function()return secret end else InCombatLockdown=function()error('Unknown combat')end end
    writes=cycle.writes;beforeReads=reads
    check(not RA.WorldMarkers:ResyncActive() and cycle.writes==writes and reads==beforeReads,'Unreadable combat allowed activity queries/writes: '..unknown)
end
InCombatLockdown=combatAPI
RA.WorldMarkers:SetEnabled(false);beforeReads=reads;event('RAID_TARGET_UPDATE');dispatch(cycle,true)
check(reads==beforeReads,'Disabled marker subscription still queried activity')
check(randomCalls==0,'Marker path introduced random selection')
print('PASS: '..checks..' marker synchronization/geometry assertions (offline actual modules; native acceptance pending)')
]=]
assert(loadstring(source))()
