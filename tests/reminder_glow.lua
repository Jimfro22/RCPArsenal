-- Actual native renderer/options with opaque health. Offline lifecycle evidence;
-- native corner motion, flipbook/tint and alpha equality need client acceptance.
local checks=0
local function check(value,message) checks=checks+1; assert(value,message) end
local file=assert(io.open('tests/personal_tools.lua')); local fixture=file:read('*a');file:close()
fixture=fixture:sub(1,assert(fixture:find('local tools = loadTools()',1,true))-1)
local function Lifecycle()
    local env=setmetatable({}, {__index=_G});env._G=env
    env.loadfile=function(path)local fn,err=loadfile(path);if fn then setfenv(fn,env)end;return fn,err end
    local fn=assert(loadstring(fixture..[[
local tools=loadTools()
local h={tools=tools,RA=RA,secret=secret,frames=frames,profile=profile}
function h:ready(id) return ready(id) end
function h:empty() items={} end
function h:health(value) healthRatio=value;events.UNIT_HEALTH('UNIT_HEALTH','player') end
function h:dead(value) dead=value;events.UNIT_HEALTH('UNIT_HEALTH','player') end
function h:combat(value) combat=value;tools:Refresh() end
function h:metrics() return {frames=#frames,textures=nativeTextures,groups=nativeGroups,tracks=nativeTracks,items=itemCalls,cd=cooldownCalls,usability=usabilityCalls,health=healthCalls,timers=#timers,tickers=#tickers} end
function h:expiry() return timers[#timers] end
return h
]]));setfenv(fn,env);return fn()
end
local function sameWork(a,b)
    return a.items==b.items and a.cd==b.cd and a.usability==b.usability and a.timers==b.timers and a.tickers==b.tickers
end
local h=Lifecycle();local tools=h.tools
for _,style in ipairs({'PIXEL','BUTTON','AUTOCAST','STEADY'}) do
    check(tools:SetGlowOption('style',style),'OFF style edit rejected')
    check(tools:SetGlowOption('color',{0.2,0.5,0.8}),'OFF color edit rejected')
end
local off=h:metrics()
check(off.frames==0 and off.groups==0 and off.textures==0 and off.health==0 and off.items==0 and off.timers==0,'OFF configuration performed runtime work')
check(not tools:GetState().consumableReminder and tools:GetState().reminderStoneGlow,'Appearance edits changed opt-ins')
check(not tools:SetGlowOption('style',h.secret) and not tools:SetGlowOption('color',{h.secret,0,0}) and not tools:SetGlowOption('pixelLines',h.secret),'Secret appearance data accepted')
check(not tools:SetGlowOption('unknown',1) and not tools:SetGlowOption('style','BOGUS'),'Unknown appearance option accepted')
local normalized=h.RA:NormalizeReminderGlow({style='bad',color={0/0,2,-1},pixelLines=999,pixelSpeed=-2,pixelLength=math.huge,autocastGroups=0,autocastSize=999})
check(normalized.style=='STEADY' and normalized.color[1]==1 and normalized.color[2]==1 and normalized.color[3]==0
    and normalized.pixelLines==12 and normalized.pixelSpeed==0.5 and normalized.pixelLength==10 and normalized.autocastGroups==1 and normalized.autocastSize==150,'Malformed profile appearance did not normalize safely')
check(h.RA:NormalizeReminderGlow(h.secret).style=='STEADY','Secret whole settings table was inspected')
tools:SetGlowOption('pixelLines',11);tools:SetGlowOption('autocastGroups',7);tools:SetGlowOption('style','PIXEL');tools:SetGlowOption('style','AUTOCAST')
check(tools:GetState().reminderGlow.pixelLines==11 and tools:GetState().reminderGlow.autocastGroups==7,'Inactive values were overwritten')
tools:SetOption('reminderStoneGlow',false);tools:ResetGlowSettings()
check(not tools:GetState().reminderStoneGlow and not tools:GetState().consumableReminder and tools:GetState().reminderGlow.style=='STEADY','Appearance reset changed feature switches')

for _,id in ipairs({5512,241304}) do
    h=Lifecycle();tools=h.tools
    local item=h:ready(id);item.start,item.duration=90,20
    tools:SetOption('reminderShowOnCooldown',true);tools:SetOption('consumableReminder',true)
    local live=h.frames[1];local renderer=live.glow.renderer
    local expiry=h:expiry();local initial=h:metrics()
    check(renderer.style=='STEADY' and renderer.active and initial.groups==0,'Legacy default acquired animated cost')
    local position,sound=h.profile.personalTools.reminderPosition,h.profile.personalTools.reminderSound
    for _,size in ipairs({24,56,128}) do
        tools:SetOption('reminderIconSize',size)
        expiry=h:expiry()
        local before=h:metrics()
        for _,style in ipairs({'PIXEL','BUTTON','AUTOCAST'}) do
            tools:SetGlowOption('style',style)
            check(renderer.style==style and renderer.active,'Selected native style fell back unexpectedly')
            local extent=h.RA.ReminderGlow:GetExtent(tools:GetState().reminderGlow,size)
            check(live.clampInsets[3]>=extent+7 and -live.clampInsets[4]>=extent+7,'Live clamp omitted style halo/bounce')
            if style=='PIXEL' then
                check(renderer.count==8 and #renderer.nodes[1].rotations==4,'Pixel line count/corner tracks wrong')
                tools:SetGlowOption('pixelSpeed',2)
                check(renderer.nodes[1].group.speed==2,'Higher Pixel speed did not increase native rate')
                tools:SetGlowOption('pixelLength',16);tools:SetGlowOption('pixelThickness',4)
                check(renderer.nodes[1].texture.width==16 and renderer.nodes[1].texture.height==4 and live.clampInsets[3]>=17,'Pixel geometry or edited clamp stale')
            elseif style=='BUTTON' then
                tools:SetGlowOption('buttonSpeed',0.5)
                check(renderer.button.group.speed==0.5 and renderer.button.texture.width==size*1.6,'Proc native speed/extent wrong')
                local flip=renderer.button.group.animations[1]
                check(flip.FlipBookRows==6 and flip.FlipBookColumns==5 and flip.FlipBookFrames==30,'Proc atlas flipbook contract wrong')
            else
                tools:SetGlowOption('autocastGroups',8);tools:SetGlowOption('autocastSize',150)
                check(renderer.count==32 and renderer.nodes[1].texture.width==({[24]=13.5,[56]=18,[128]=27})[size] and renderer.nodes[25].texture.width==({[24]=6.75,[56]=9,[128]=13.5})[size],'Autocast groups/tier sizes wrong')
            end
            local after=h:metrics();local plays=renderer.nodes[1] and renderer.nodes[1].group.plays
            for _,health in ipairs({0.349999,0.35,0.350001,0.5,0.2}) do
                h:health(health)
                check(live.glow.renderAlpha==(health<=0.35 and 1 or 0),'Style escaped opaque native threshold')
            end
            check(h:metrics().groups==after.groups and h:metrics().tracks==after.tracks and h:metrics().textures==after.textures
                and (not plays or renderer.nodes[1].group.plays==plays),'Health hook allocated/reconfigured/restarted glow')
        end
        check(sameWork(before,h:metrics()),'Appearance edits touched supply cache/expiry')
    end
    check(not expiry.cancelled and h:expiry()==expiry and h.profile.personalTools.reminderPosition==position and h.profile.personalTools.reminderSound==sound,'Appearance edit disturbed expiry/position/sound')
    -- All native pools are warm; repeated color/style/count/size changes reuse.
    tools:SetGlowOption('style','PIXEL');tools:SetGlowOption('pixelLines',12)
    tools:SetGlowOption('style','AUTOCAST');tools:SetGlowOption('autocastGroups',8)
    local warm=h:metrics()
    for i=1,24 do
        tools:SetGlowOption('style',i%2==0 and 'PIXEL' or 'AUTOCAST')
        tools:SetGlowOption('pixelLines',i%12+1);tools:SetGlowOption('color',{i/24,0.5,1-i/24})
    end
    local changed=h:metrics()
    check(warm.frames==changed.frames and warm.textures==changed.textures and warm.groups==changed.groups and warm.tracks==changed.tracks,'Repeated native edits leaked objects')
    check(changed.groups<=33 and changed.tracks<=177 and #renderer.nodes<=32,'Native object pool exceeded bounds')
    tools:SetLayoutMasked(true);check(not renderer.active,'Placement mask retained live animation')
    tools:SetLayoutMasked(false);check(renderer.active,'Unmask did not restore prepared renderer')
    tools:SetOption('reminderStoneGlow',false);check(not renderer.active,'Saved OFF retained animation')
    h:health(0.1);check(not renderer.active,'Health event restarted OFF glow')
    tools:SetOption('reminderStoneGlow',true);h:dead(true);check(not renderer.active,'Death retained animation')
    h:dead(false);tools:Refresh();tools:SetOption('reminderCombat','IN_COMBAT');check(not renderer.active,'Combat policy retained animation')
    h:combat(true);check(renderer.active,'Public combat re-entry lost glow')
    h:empty();tools:Refresh();check(not renderer.active,'Empty warning retained animation')
    tools:SetOption('consumableReminder',false);check(not renderer.active,'Master OFF retained animation')
end

h=Lifecycle();tools=h.tools
tools:SetGlowOption('style','PIXEL');tools:PreviewReminder('potion')
local sample=h.frames[1];local renderer=sample.glow
check(renderer.active and renderer.style=='PIXEL' and h:metrics().health==0 and h:metrics().items==0,'Explicit sample queried gameplay data')
local mode=tools:GetState().previewMode
tools:SetGlowOption('style','BUTTON');tools:SetGlowOption('color',{0,1,0})
check(renderer.active and renderer.style=='BUTTON' and tools:GetState().previewMode==mode and h:metrics().health==0,'Active sample did not update silently')
tools:MoveReminder('stone');tools:SetOption('reminderIconSize',128)
check(sample.clampInsets[3]>=38.4+7-0.000001 and tools:GetState().previewMode=='MOVE','Move sample clamp/mode stale after style edit')
tools:PreviewReminder('empty');check(not renderer.active,'Empty sample retained animated style')
tools:StopReminderPreview();tools:SetGlowOption('style','AUTOCAST');check(not renderer.active and tools:GetState().previewMode==nil,'Style edit started stopped sample')

-- Inject a failure after the first native Play, then require full cleanup and
-- an already-prepared steady fallback without allocation/retry from health.
h=Lifecycle();tools=h.tools;h:ready(5512);tools:SetGlowOption('style','PIXEL');tools:SetOption('consumableReminder',true)
renderer=h.frames[1].glow.renderer;tools:SetLayoutMasked(true)
renderer.nodes[2].group.Play=function() error('native Play failed') end
local before=h:metrics();tools:SetLayoutMasked(false)
check(renderer.style=='STEADY' and renderer.active and not renderer.nodes[1].group.playing,'Partial native Play leaked an animation')
h:health(0.2)
check(before.groups==h:metrics().groups and before.tracks==h:metrics().tracks,'Play fallback allocated on health')
renderer.frame:Hide();check(not renderer.active,'Hidden renderer retained animation')
print(('PASS: %d adjustable glow assertions (actual renderer; opaque health/native animation mocks)'):format(checks))
