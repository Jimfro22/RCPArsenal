-- Rendering inputs, not a simulated WoW renderer. Measure actual configured
-- UI-unit bounds against the static backing, native phase arguments and start
-- order. Native transform composition, artwork/blend and motion need WoW.
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local file=assert(io.open('tests/personal_tools.lua'));local fixture=file:read('*a');file:close()
fixture=fixture:sub(1,assert(fixture:find('local tools = loadTools()',1,true))-1)
local function Lifecycle()
    local env=setmetatable({}, {__index=_G});env._G=env
    env.loadfile=function(path)
        -- Optional local negative controls run the same spatial assertions
        -- against captured alpha.15 modules without editing canonical source.
        if path=='RCPArsenal/ReminderGlow.lua' and RCP_GLOW_TEST_SOURCE then path=RCP_GLOW_TEST_SOURCE end
        if path=='RCPArsenal/PersonalTools.lua' and RCP_GLOW_TEST_TOOLS_SOURCE then path=RCP_GLOW_TEST_TOOLS_SOURCE end
        local fn,err=loadfile(path);if fn then setfenv(fn,env)end;return fn,err
    end
    local fn=assert(loadstring(fixture..[[
local tools=loadTools()
return {tools=tools,RA=RA,frames=frames,ready=ready,metrics=function()return {items=itemCalls,health=healthCalls}end}
]]));setfenv(fn,env);return fn()
end
local function Period(node)
    local period=0
    for _,move in ipairs(node.translations)do period=period+move.Duration end
    return period
end
local function OutsideRoute(renderer,size,style)
    local phases={}
    local largest=0
    for index=1,renderer.count do
        local node=renderer.nodes[index];local texture=node.texture;local p=texture.point
        check(p[1]=='CENTER' and p[2]==renderer.frame and p[3]=='BOTTOMLEFT','Moving texture changed coordinate space')
        local half=style=='PIXEL' and texture.height/2 or texture.width/2
        -- The exact alpha.15 defect: its centerline + half-stroke lay INSIDE
        -- a three-unit gold backing. This assertion fails on captured alpha.15.
        check(p[4]+half<=-1+1e-7 and p[5]+half<=-1+1e-7,
            'Moving glow overlaps static border: expected a one-unit outside gap')
        local x,y=p[4],p[5];local minX,maxX,minY,maxY=x,x,y,y
        for _,move in ipairs(node.translations)do
            check(move.Duration>0,'Perimeter side has no native duration')
            x,y=x+move.x,y+move.y
            minX,maxX=math.min(minX,x),math.max(maxX,x)
            minY,maxY=math.min(minY,y),math.max(maxY,y)
        end
        check(math.abs(x-p[4])<1e-7 and math.abs(y-p[5])<1e-7 and minX<0 and minY<0 and maxX>size and maxY>size,
            'Configured translation deltas do not close around all four outside edges')
        local radius=style=='PIXEL' and (texture.width+texture.height)/2 or texture.width/2
        local required=math.max(-minX,-minY,maxX-size,maxY-size)+radius
        check(renderer.extent+1e-7>=required,'Declared clamp footprint omits moving/turning texture bounds')
        check(texture.alpha==1 and texture.layer=='OVERLAY' and texture.sublevel==7,'Owned texture alpha/layer contract wrong')
        check(node.group.ownerShownAtPlay,'Native group started before its owned visual was shown')
        local phase=node.group.offset/Period(node)
        check(phase>=0 and phase<1,'Native phase seek lies outside its loop')
        phases[math.floor(phase*1000000+0.5)]=true
        largest=math.max(largest,texture.width)
    end
    local phaseCount=0;for _ in pairs(phases)do phaseCount=phaseCount+1 end
    check(phaseCount==renderer.count,'Spark tiers/lines stack at identical initial native phases')
    if style=='AUTOCAST' then check(largest>=4.5 and largest<=27,'Size-aware spark escaped documented bounds') end
end

for _,size in ipairs({24,56,128})do
    for _,kind in ipairs({'stone','potion'})do
        local h=Lifecycle();h.tools:SetOption('reminderIconSize',size);h.tools:PreviewReminder(kind)
        local sample=h.frames[1];local renderer=sample.glow
        local backing=sample.border.color
        check(backing[1]==0.05 and backing[2]==0.04 and backing[3]==0.06 and backing[4]==0.94,
            'Preview gold backing masks style: sample must match the dark live backing')
        for _,style in ipairs({'PIXEL','AUTOCAST','BUTTON'})do
            h.tools:SetGlowOption('style',style)
            check(renderer.style==style and renderer.active,'Native configuration silently fell back')
            local settings=h.tools:GetState().reminderGlow
            renderer.extent=h.RA.ReminderGlow:GetExtent(settings,size)
            if style=='BUTTON' then
                local texture,group=renderer.button.texture,renderer.button.group
                check(texture.width==size*1.6 and texture.height==size*1.6 and texture.width>size*1.4,
                    'Proc footprint was not separated from the icon backing')
                check(math.abs(renderer.extent-(texture.width-size)/2)<1e-7,'Proc footprint/clamp mismatch')
                check(texture.atlas=='UI-HUD-ActionBar-Proc-Loop-Flipbook' and texture.blend=='BLEND' and texture.alpha==1,
                    'Proc native atlas/alpha/blend contract wrong')
                local flip=group.animations[1]
                check(flip.kind=='FlipBook' and flip.FlipBookRows==6 and flip.FlipBookColumns==5 and flip.FlipBookFrames==30
                    and flip.FlipBookFrameWidth==0 and flip.FlipBookFrameHeight==0 and flip.Duration==1,
                    'Proc flipbook disagrees with Blizzard native atlas layout')
                check(group.ownerShownAtPlay,'Proc started while owned visual hidden')
            else OutsideRoute(renderer,size,style) end
            check(renderer.frame.clipsChildren==false and renderer.frame:GetFrameLevel()>renderer.frame.parent:GetFrameLevel(),
                'Owned glow can clip its outside geometry or fall beneath the icon')
            check(sample.clampInsets[3]+1e-7>=renderer.extent+7,'Sample clamp omitted changed halo plus bounce')
            local caption=h.frames[2].strings[1].point
            check(caption[2]==sample.body and caption[5]<=-renderer.extent-4+1e-7,'Halo crosses item caption')
            check(sample.label.point[5]>=renderer.extent+12-1e-7 and sample.clampInsets[3]>=sample.label.point[5]+12-1e-7,
                'Halo/bounce crosses preview heading or clamp omits heading')
        end
        -- Extrema use the SAME saved options, with bounded geometry and seeks.
        for _,value in ipairs({50,150})do
            h.tools:SetGlowOption('autocastSize',value);h.tools:SetGlowOption('style','AUTOCAST')
            renderer.extent=h.RA.ReminderGlow:GetExtent(h.tools:GetState().reminderGlow,size)
            OutsideRoute(renderer,size,'AUTOCAST')
        end
        h.tools:SetGlowOption('pixelLength',16);h.tools:SetGlowOption('pixelThickness',4);h.tools:SetGlowOption('style','PIXEL')
        renderer.extent=h.RA.ReminderGlow:GetExtent(h.tools:GetState().reminderGlow,size);OutsideRoute(renderer,size,'PIXEL')
        check(h.metrics().items==0 and h.metrics().health==0,'Visual sample/configuration queried gameplay data')
        h.tools:StopReminderPreview();check(not renderer.active,'Stopped sample retained native animation')
    end
end
-- Live paths share the outside renderer beneath the separate opaque gate.
for _,id in ipairs({5512,241304})do
    local h=Lifecycle();h.ready(id);h.tools:SetGlowOption('style','AUTOCAST');h.tools:SetOption('consumableReminder',true)
    local live=h.frames[1];local renderer=live.glow.renderer
    check(renderer.frame.parent==live.glow,'Live renderer escaped the native health-alpha ancestor')
    renderer.extent=h.RA.ReminderGlow:GetExtent(h.tools:GetState().reminderGlow,56);OutsideRoute(renderer,56,'AUTOCAST')
    check(h.frames[2].strings[1].point[5]<=-renderer.extent-4+1e-7 and -live.clampInsets[4]>=renderer.extent+4+12+7-1e-7,
        'Live caption/clamp did not clear the actual glow footprint')
end
print(('PASS: %d glow rendering-input assertions (spatial/phase/lifecycle contracts; native visuals pending)'):format(checks))
