-- Real radial + theme, mocked regions/input. Native rendering is not covered.
local f=assert(io.open('tests/marker_radial.lua'));local source=f:read('*a');f:close()
source=source:sub(1,assert(source:find('RaidArsenalDB = {profile = {schemaVersion = 19',1,true))-1)
local target="    assert(loadfile(arg[1] or 'RCPArsenal/MarkerRadial.lua'))('RCPArsenal', RA)"
local replacement=[=[
    assert(loadfile('RCPArsenal/Theme.lua'))('RCPArsenal',RA)
    function RA:ApplyFont(region,size,weight,shadow)region.font={size,weight,shadow}end
    function RA:SetVisualTexture(region,path)region:SetTexture(path);region.registered=true end
]=]..target
local a,b=assert(source:find(target,1,true));source=source:sub(1,a-1)..replacement..source:sub(b+1)
source=source..[=[
RaidArsenalDB={profile={schemaVersion=19,worldMarkers={enabled=true,radialEnabled=true}}}
keys[wheelBinding]={'F12'}
local RA,cycle,clear,eventFrame=loadAddon()
local wheel=named.RCPArsenalWorldMarkerWheel;local root=wheel:GetFrameRef('root');local center=wheel:GetFrameRef('center')
local function point(x,y)move(x*UIParent.scale,y*UIParent.scale)end
local function tick(elapsed)for _,frame in ipairs(frames)do if frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame,elapsed or 0)end end end
local function begin()point(960,540);dispatch(wheel,true)end
local function finish()dispatch(wheel,false)end
local function near(a,b)return math.abs(a-b)<.000001 end
check(not center.choice and not center.hint and not center.help,'Old stacked hub labels retained')
check(center.caption.font[1]==12 and center.caption.font[2]=='REGULAR' and center.caption.width==264,'Shared 12px caption/font changed')
check(center.caption.wordWrap==false and center.caption.justifyH=='CENTER','Caption wraps or is not centered')
check(center.width==282 and center.height==282 and not center.mouse,'Footprint/input changed')
check(near(center.cancelRegion.width,56.02) and not center.cancelRegion.mouse,'Hub size/input changed')
local allocations=#frames
begin()
check(center.caption.text=='Swipe to choose · center cancels' and activePolling()==1 and center.hubBorder.alpha==.52,'Initial neutral cue/polling/outline wrong')
for _,slot in ipairs(center.slots)do check(slot.icon.alpha==1 and slot.highlight.alpha==0 and slot.edge.alpha==0,'Initial selection emphasis retained')end
for scaleIndex,scale in ipairs({.64,.8,1,1.25})do
    finish();UIParent.scale=scale;begin()
    for id,slot in ipairs(center.slots)do
        local angle=(id-1)*math.pi/4
        point(960+math.sin(angle)*92,540+math.cos(angle)*92);tick()
        check(slot.icon.width==30 and slot.icon.height==30 and slot.width==42 and slot.height==42 and not slot.mouse,'Native artwork size/hit frame changed')
        check(slot.icon.registered and slot.icon.texture=='Interface\\TargetingFrame\\UI-RaidTargetingIcon_'..RA.WorldMarkers.Definitions[id].icon,'Native marker path changed')
        check(slot.highlight.alpha==1 and slot.edge.alpha==1 and slot.chevron.alpha==1,'Selected shape incomplete')
        for _,corner in ipairs(slot.corners)do check(corner.alpha==1,'Selected slot corner missing')end
        for other,otherSlot in ipairs(center.slots)do
            check(otherSlot.icon.alpha==(other==id and 1 or .72),'Icon contrast wrong')
            check(otherSlot.highlight.alpha==(other==id and 1 or 0),'Multiple/wrong selected wedges')
        end
        check(center.caption.text==RA.WorldMarkers.Definitions[id].name..' · release to aim; click ground','Selected name/aim cue wrong')
        -- Interpolate the actual UVs at the corresponding clockwise icon center.
        -- Every oriented north mask must sample its north center, with no scale.
        for _,texture in ipairs({slot.backing,slot.highlight,slot.edge})do
            local t=texture.texCoords;local x=.5+math.sin(angle)*92/282;local y=.5-math.cos(angle)*92/282
            local u=(1-x)*((1-y)*t[1]+y*t[3])+x*((1-y)*t[5]+y*t[7])
            local v=(1-x)*((1-y)*t[2]+y*t[4])+x*((1-y)*t[6]+y*t[8])
            check(near(u,.5) and near(v,.5-92/282),'Mask orientation/scale differs from marker center')
        end
    end
    point(960,540+200);tick()
    check(center.slots[1].highlight.alpha==1,'Artwork added an outer selection cutoff')
    point(960,540);tick()
    check(center.caption.text=='Release, Esc or right-click to cancel' and center.hubBorder.alpha==.95,'Returned-center cue/outline wrong')
    for _,slot in ipairs(center.slots)do
        check(slot.icon.alpha==1 and slot.highlight.alpha==0 and slot.edge.alpha==0 and slot.chevron.alpha==0,'Center retains selected art')
        for _,corner in ipairs(slot.corners)do check(corner.alpha==0,'Center retains slot corners')end
    end
end
point(1052,540);tick()
local mutableAccent=RA.Theme:GetAccentEnd()
RA.Theme:SetAccentPreset('BERRY')
check(mutableAccent==RA.Theme:GetAccentEnd(),'Theme accent table identity changed')
for _,slot in ipairs(center.slots)do
    for i=1,3 do check(slot.edge.vertexColor[i]==mutableAccent[i],'Selection edge ignores mutable accent')end
end
tick(11)
check(activePolling()==0 and center.caption.text=='Preview paused · wheel armed · Esc cancels','Timeout cue falsely claims disarmed')
check(wheel:GetAttribute('rcp-wheel-held'),'Cosmetic timeout changed input')
for _,slot in ipairs(center.slots)do check(slot.highlight.alpha==0 and slot.edge.alpha==0 and slot.chevron.alpha==0,'Recovery retained emphasis')end
dispatch(named.RCPArsenalWorldMarkerCancel,true);finish()
check(not root:IsShown() and activePolling()==0,'Cancellation retained art/polling')
begin();point(960,740);tick();UIParent.width=1919;tick()
check(activePolling()==0 and center.caption.text=='Preview paused · wheel armed · Esc cancels','Geometry recovery cue wrong')
dispatch(named.RCPArsenalWorldMarkerCancel,true);finish();UIParent.width=1920
begin();check(center.caption.text=='Swipe to choose · center cancels','Reopen retained cancel/paused cue');finish()
check(#frames==allocations and #timers==0,'Preview/theme/cancel allocated artwork or timers')
check(activePolling()==0 and empty(wheel.overrides),'Idle preview/bindings remained')
print('PASS: '..checks..' radial presentation/theme/UV/lifecycle assertions (offline; native rendering pending)')
]=]
assert(loadstring(source,'radial-presentation-fixture'))()
