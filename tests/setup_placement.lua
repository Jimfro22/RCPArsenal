-- Reuse the actual-module frame fixture, before its feature assertions. Each
-- lifecycle has separate globals; tests drive controller/UI decisions only.
local checks=0
local function check(value,message)checks=checks+1;assert(value,message)end
local function clone(v)if type(v)~='table'then return v end;local out={};for k,x in pairs(v)do out[k]=clone(x)end;return out end
local file=assert(io.open('tests/hub.lua'));local fixture=file:read('*a');file:close()
local marker="event('ADDON_LOADED','RCPArsenal')"
local boundary=assert(fixture:find(marker,1,true))
fixture=fixture:sub(1,boundary-1)
local function Lifecycle(saved)
    local env=setmetatable({_requestedSaved=clone(saved),UISpecialFrames={}}, {__index=_G});env._G=env
    env.loadfile=function(path)local fn,err=loadfile(path);if fn then setfenv(fn,env)end;return fn,err end
    local source=fixture..[[
RaidArsenalDB=_requestedSaved
event('ADDON_LOADED','RCPArsenal')
return {RA=RA,objects=objects,named=named,timers=timers,methods=methods,event=event,
setCombat=function(value)combat=value end,
metrics=function()return {sent=sent,talents=talentReads,inspects=inspectCalls,attributes=attributeWrites,frames=#objects}end}
]]
    local fn=assert(loadstring(source));setfenv(fn,env);local h=fn();h.env=env
    local function rect(self)
        if self==env.UIParent then return 0,self:GetHeight()end
        if self.fixedLeft then return self.fixedLeft,self.fixedTop end
        local p=self.points[#self.points] or {'TOPLEFT',env.UIParent,'TOPLEFT',0,0}
        local point,relative,anchor,x,y=p[1],p[2],p[3],p[4] or 0,p[5] or 0
        if type(relative)~='table'then relative=env.UIParent;anchor='TOPLEFT' end
        anchor=type(anchor)=='string' and anchor or 'CENTER'
        local w,h=relative:GetWidth(),relative:GetHeight()
        local ax=anchor:find('LEFT') and 0 or anchor:find('RIGHT') and w or w/2
        local ay=anchor:find('TOP') and h or anchor:find('BOTTOM') and 0 or h/2
        local scale=self:GetEffectiveScale()
        local left=ax+x-(point:find('RIGHT') and self:GetWidth()*scale or not point:find('LEFT') and self:GetWidth()*scale/2 or 0)
        local top=ay+y+(point:find('BOTTOM') and self:GetHeight()*scale or not point:find('TOP') and self:GetHeight()*scale/2 or 0)
        return left/scale,top/scale
    end
    h.methods.GetLeft=function(self)local x=rect(self);return x end
    h.methods.GetTop=function(self)local _,y=rect(self);return y end
    h.methods.SetClampRectInsets=function(self,...)self.clampInsets={...}end
    function h:click(text)
        for _,obj in ipairs(self.objects)do if obj.label and obj.label.text==text and obj:IsVisible() and obj:IsEnabled()then obj:Fire('OnClick');return true end end
    end
    function h:visible(text)
        for _,obj in ipairs(self.objects)do if obj.text==text and obj:IsVisible()then return true end end
        return false
    end
    return h
end

local h=Lifecycle();local RA=h.RA
check(not RA.ConfigFrame and not RA.Placement:IsActive(),'Fresh login opened setup or placement')
check(h.metrics().frames==5 and h.metrics().sent==0 and h.metrics().inspects==0 and h.metrics().talents==0,'Fresh OFF setup added runtime frames/queries')
RA:OpenConfig()
check(h:visible('Set up Arsenal') and RA.Setup:HasDraft(),'First fresh neutral open did not present Setup')
RA.Setup:Set('role','LEADER');RA.Setup:Set('threshold',67);RA.Setup:Set('sound',false);RA.Setup:Set('glow',false)
RA.Setup:Set('reminder',true)
check(h:visible('Icon edge glow') and h:visible('Healthstone or potion at ≤35%, while visible.'),'Welcome glow copy still excludes potion or hides visibility condition')
RA.Setup:Set('reminder',false)
check(not RA:GetDB().hudEnabled and not RA:GetDB().personalTools.consumableReminder and RA:GetDB().personalTools.healthThreshold==40,'Draft/role editing applied runtime preferences')
check(h:click('VIEW CHECKLIST') and h:visible('Addons & versions') and RA.Setup:Get('threshold')==67,'Checklist navigation discarded the draft')
RA:CloseConfig();RA:OpenConfig()
check(h:visible('Addons & versions') and RA.Setup:HasDraft(),'Paused setup forced the welcome over the selected page')
check(h:click('BACK TO SETUP') and RA.Setup:Get('role')=='LEADER' and RA.Setup:Get('sound')==false,'Back to Setup lost role/child choices')
RA:CloseConfig()
check(not RA.Setup:HasDraft() and not RA.Setup:IsFirstRunPending() and h.env.RaidArsenalDB.setup.completed,'X/Escape-style host hide did not discard/dismiss first-use Setup')
RA:OpenConfig();check(h:visible('Addons & versions'),'Dismissed setup reopened on every neutral call')
check(not RA:GetDB().personalTools.consumableReminder and RA:GetDB().personalTools.reminderStoneGlow,'Dismissal changed child preferences')

h=Lifecycle({profile={schemaVersion=19,personalTools={reminderSound=false,reminderSoundChoice='sound_2',reminderSoundChannel='SFX',reminderSoundWhenEffectsMuted=true,reminderStoneGlow=false,reminderGlow={style='AUTOCAST',pixelLines=9,autocastGroups=6}},actions={leftClickMode='SAY'},leaderToolbox={enabled=false,showMissing=false}},navigation={lastTab='HUD'}});RA=h.RA
RA:OpenConfig();check(h:visible('Display & Position'),'Existing OFF installation lost saved-tab behavior')
RA:OpenSetup();check(RA.Setup:Get('sound')==false and RA.Setup:Get('glow')==false and RA.Setup:Get('leftClick')=='SAY','Setup replay lost valid saved children')
RA.Setup:Set('role','LEADER');RA.Setup:Set('reminder',true);RA.Setup:Set('quickBar',true);RA.Setup:Set('threshold',61)
local count,summary=RA.Setup:GetSummary()
check(count==2 and summary:find('sound off',1,true) and summary:find('provider classes off',1,true),'Setup summary misstated child/activation consequences')
local ok,destination=RA.Setup:Save()
check(ok and destination=='HUD' and RA:GetDB().personalTools.consumableReminder and RA:GetDB().leaderToolbox.enabled,'Reviewed choices failed to save/return')
check(not RA:GetDB().leaderToolbox.showMissing and not RA:IsHUDEnabled(),'Quick Bar enable default overrode reviewed child or enabled inspection')
check(RA:GetDB().personalTools.reminderSoundChoice=='sound_2' and RA:GetDB().personalTools.reminderSoundChannel=='SFX' and RA:GetDB().personalTools.reminderSoundWhenEffectsMuted,'Setup changed unrelated saved sound selection/routing')
check(RA:GetDB().personalTools.reminderGlow.style=='AUTOCAST' and RA:GetDB().personalTools.reminderGlow.pixelLines==9 and RA:GetDB().personalTools.reminderGlow.autocastGroups==6,'Setup overwrote saved appearance values')
check(h.metrics().inspects==0 and h.metrics().sent==0,'Quick Bar-only setup inspected or communicated')
RA:OpenConfig('ADDONS');RA:OpenSetup();RA.Setup:Set('hud',true)
local scans=0;RA.ScheduleInspectionScan=function()scans=scans+1 end
h.setCombat(true);check(not RA.Setup:Save() and not RA:IsHUDEnabled() and RA.Setup:Get('hud'),'Combat applied or discarded setup draft')
h.setCombat(false);h.event('PLAYER_REGEN_ENABLED')
check(not RA:IsHUDEnabled() and scans==0,'Combat end automatically saved setup')
check(RA.Setup:Save() and RA:IsHUDEnabled() and scans==1,'Explicit HUD setup did not activate exactly once')
RA.Setup:Begin('HUD');check(RA.Setup:Save() and scans==1,'Unchanged replay restarted inspection')
RA.Setup:Begin('HUD');RA.Setup:Set('threshold',73);RA:GetDB().personalTools.healthThreshold=29
check(not RA.Setup:Save() and RA:GetDB().personalTools.healthThreshold==29,'Stale Setup overwrote newer preferences')

h=Lifecycle({profile={schemaVersion=19,position={point='TOPLEFT',relativePoint='TOPLEFT',x=124,y=-87},positionAnchorVersion=3,
leaderToolbox={position={point='TOPLEFT',relativePoint='TOPLEFT',x=69,y=-211},positionAnchorVersion=3},
personalTools={reminderPosition={point='TOPLEFT',relativePoint='TOPLEFT',x=900,y=-380}}}});RA=h.RA
local liveReminder=h.env.CreateFrame('Frame','RCPArsenalConsumableReminder',h.env.UIParent)
liveReminder:SetSize(56,56);liveReminder:SetPoint('TOPLEFT',h.env.UIParent,'TOPLEFT',900,-380)
local before=h.metrics()
check(RA.Placement:Start('MOVE'),'Move session failed')
check(h:click('POTION') and h.named.RCPArsenalPlacementREMINDER.glow.frame:IsShown(),'Potion placement sample omitted saved icon glow')
check(h:click('EMPTY') and not h.named.RCPArsenalPlacementREMINDER.glow.frame:IsShown(),'Empty placement sample retained icon glow')
check(h:click('STONE') and h.named.RCPArsenalPlacementREMINDER.glow.frame:IsShown(),'Stone placement sample lost icon glow')
local sampleGlow=h.named.RCPArsenalPlacementREMINDER.glow
local staged=RA.Placement:GetState().positions.REMINDER.x
RA.PersonalTools:SetGlowOption('style','PIXEL')
check(sampleGlow.style=='PIXEL' and sampleGlow.active and RA.Placement:IsActive() and RA.Placement:GetState().positions.REMINDER.x==staged,'Saved style did not update active placement without changing session/anchor')
RA.PersonalTools:SetGlowOption('style','BUTTON')
check(sampleGlow.style=='BUTTON' and h.named.RCPArsenalPlacementREMINDER.glow==sampleGlow,'Global item sample failed style reuse')
local sampleFrame=h.named.RCPArsenalPlacementREMINDER
local halo=RA.ReminderGlow:GetExtent(RA.PersonalTools:GetState().reminderGlow,RA:GetDB().personalTools.reminderIconSize)
check(sampleFrame.caption.points[#sampleFrame.caption.points][5]<=-halo-4+0.000001
    and sampleFrame.title.points[#sampleFrame.title.points][5]>=halo+5-0.000001,'Placement sample labels overlap glow halo')
local textBefore,sizeBefore=RA:GetDB().personalTools.reminderStoneText,RA:GetDB().personalTools.reminderTextSize
local heightBefore=sampleFrame.caption.GetStringHeight
RA:GetDB().personalTools.reminderStoneText=string.rep('W',60);RA:GetDB().personalTools.reminderTextSize=32
sampleFrame.caption.GetStringHeight=function()return 320 end
RA.PersonalTools:SetGlowOption('color',{1,0.72,0.18})
check(-sampleFrame.clampInsets[4]>=halo+4+320,'Placement clamp assumed two lines instead of measured wrapped caption height')
sampleFrame.caption.GetStringHeight=function()return 0 end
RA.PersonalTools:SetGlowOption('color',{1,0.72,0.18})
check(-sampleFrame.clampInsets[4]>halo+4+32*2,'Zero-metric caption fallback still assumes two lines')
sampleFrame.caption.GetStringHeight=heightBefore
RA:GetDB().personalTools.reminderStoneText,RA:GetDB().personalTools.reminderTextSize=textBefore,sizeBefore
RA.PersonalTools:SetGlowOption('color',{1,0.72,0.18})


RA.PersonalTools:SetOption('reminderStoneGlow',false)
check(not sampleGlow.active and RA.Placement:IsActive(),'Saved OFF retained global sample glow or ended placement')
RA.PersonalTools:SetOption('reminderStoneGlow',true)
check(sampleGlow.active,'Saved ON did not refresh active global item sample')

local state=RA.Placement:GetState()
check(state.positions.HUD.x==124 and state.positions.HUD.y==-87 and state.positions.QUICKBAR.x==69 and state.positions.QUICKBAR.y==-211,'Unallocated OFF surface inherited the live reminder anchor')
check(state.positions.REMINDER.x==900 and state.positions.REMINDER.y==-380,'Reminder sample lost its own live anchor')
check(h.named.RCPArsenalPlacementHUD:GetScale()==1 and h.named.RCPArsenalPlacementHUD.body:GetScale()==RA:GetDB().scale,'Scaled artwork changed the unscaled coordinate anchor')
check(RA:GetDB().position.x==124 and not RA:IsHUDEnabled() and not RA:GetDB().leaderToolbox.enabled and not RA:GetDB().personalTools.consumableReminder,'Placement changed live anchors/enables before Save')
check(RA.Placement:SetPosition('HUD',222,-333) and RA.Placement:SetPosition('QUICKBAR',333,-444) and RA.Placement:SetPosition('REMINDER',444,-555),'Staged move rejected valid coordinates')
check(RA.Placement:Save(),'Atomic position save failed')
check(RA:GetDB().position.x==222 and RA:GetDB().leaderToolbox.position.x==333 and RA:GetDB().personalTools.reminderPosition.x==444,'Save did not commit all three staged anchors')
check(h.metrics().sent==before.sent and h.metrics().inspects==before.inspects and h.metrics().talents==before.talents,'Placement initiated scan/communication')
check(RA.Placement:Start('MOVE'),'Move could not reopen');RA.Placement:SetPosition('HUD',811,-222)
RA.Placement:SetPosition('QUICKBAR',1800,-400)
check(h.named.RCPArsenalPlacementQUICKBAR.dock.points[1][1]=='RIGHT','AUTO dock did not turn left after dragging to the right edge')
check(RA.Placement:RestoreStarting() and RA.Placement:GetState().positions.HUD.x==222,'Restore starting positions failed')
check(h.named.RCPArsenalPlacementQUICKBAR.dock.points[1][1]=='LEFT','Restore starting positions retained the dragged AUTO dock direction')
RA.Placement:Cancel();check(RA:GetDB().position.x==222 and not sampleGlow.active,'Cancel saved a staged position or retained glow animation')
RA.Placement:Start('MOVE');RA.Placement:SetPosition('HUD',822,-333);RA:GetDB().position.x=901
check(not RA.Placement:Save() and not RA.Placement:IsActive() and RA:GetDB().position.x==901,'Stale layout overwrote an external position change')
RA.Placement:Start('MOVE');RA.Placement:SetPosition('HUD',444,-123)
local restore=RA.RefreshHUDPosition;RA.RefreshHUDPosition=function()return false end
check(not RA.Placement:Save() and RA:GetDB().position.x==901 and RA:GetDB().leaderToolbox.position.x==333 and RA:GetDB().personalTools.reminderPosition.x==444,'Refused native handoff claimed success or left partial position writes')
RA.RefreshHUDPosition=restore
RA.Placement:Start('MOVE');h.event('DISPLAY_SIZE_CHANGED');check(not RA.Placement:IsActive() and RA:GetDB().position.x==901,'Viewport change saved or retained stale placement')
RA.Placement:Start('MOVE');RA:ResetProfile();check(not RA.Placement:IsActive(),'Profile reset retained stale placement')

h=Lifecycle();RA=h.RA;RA:OpenSetup();RA.Setup:Set('role','LEADER');RA.Setup:Set('threshold',73)
check(RA:BeginGlobalPlacement('MOVE') and not RA.ConfigFrame:IsShown() and RA.Setup:HasDraft(),'Collapsing to placement discarded Setup')
h.named.RCPArsenalPlacementSession:Hide()
check(RA.ConfigFrame:IsShown() and RA.Setup:Get('threshold')==73 and not RA.Placement:IsActive(),'Escape/cancel did not restore the same draft/page')
RA:BeginGlobalPlacement('MOVE');RA.Placement:SetPosition('HUD',777,-222);local originalX=RA:GetDB().position.x
h.setCombat(true);h.event('PLAYER_REGEN_DISABLED')
check(not RA.Placement:IsActive() and RA:GetDB().position.x==originalX and RA.Setup:Get('threshold')==73,'Combat cancellation saved/cleared staged state')
h.setCombat(false);h.event('PLAYER_REGEN_ENABLED')
check(RA.ConfigFrame:IsShown() and RA.Setup:Get('threshold')==73 and RA:GetDB().personalTools.healthThreshold==40,'Safe UI restoration applied the Setup draft')
RA:GetDB().personalTools.reminderStoneText='Use |Hitem:1|h[stone]|h';RA:BeginGlobalPlacement('PREVIEW')
check(h.named.RCPArsenalPlacementREMINDER.caption.text=='Use ||Hitem:1||h[stone]||h','Global reminder caption interpreted literal pipes')
check(h.named.RCPArsenalPlacementREMINDER.caption.points[1][1]=='TOP' and h.named.RCPArsenalPlacementREMINDER.caption.points[1][3]=='BOTTOM','Reminder caption moved off its live below-anchor rule')
RA.Placement:Cancel()
h=Lifecycle();RA=h.RA;RA:OpenConfig();RA.Setup:Set('threshold',37)
h.event('ENCOUNTER_START')
check(RA.Setup:HasDraft() and RA.Setup:Get('threshold')==37 and not h.env.RaidArsenalDB.setup.completed,'Automatic encounter hide dismissed/completed Setup')
h.event('ENCOUNTER_END');RA:OpenConfig('SETUP')
check(RA.Setup:Get('threshold')==37,'Encounter return lost the paused Setup draft')

-- A visible protected HUD must be restored by the native combat visibility
-- driver, not an insecure Show during cancellation. Drivers exist only while
-- handing off an already-created live surface, never for OFF placeholders.
h=Lifecycle();RA=h.RA;RA:GetDB().compact.showEmptyState=true;RA:SetHUDEnabled(true)
local hud=h.named.RCPArsenalHUD
check(hud and hud:IsShown(),'Protected handoff fixture has no visible HUD')
hud.IsProtected=function()return true,true end
local drivers,registered,removed={},0,0
h.env.RegisterStateDriver=function(frame,state,condition)
    check(not h.env.InCombatLockdown() and state=='visibility','Driver installed during combat or for wrong state')
    drivers[frame]=condition;registered=registered+1;frame:Hide()
end
h.env.UnregisterStateDriver=function(frame,state)
    check(not h.env.InCombatLockdown() and state=='visibility','Driver removed insecurely during combat')
    drivers[frame]=nil;removed=removed+1
end
check(RA:BeginGlobalPlacement('MOVE') and not hud:IsShown() and h.named.RCPArsenalPlacementHUD:IsShown(),'Protected live surface was duplicated beside its placement sample')
check(registered==1 and drivers[hud]=='[combat] show; hide','Protected handoff did not arm native combat restoration')
RA:RefreshHUD();check(not hud:IsShown(),'Background HUD refresh bypassed the preview mask')
local oldX=RA:GetDB().position.x
h.setCombat(true)
-- Emulate the native secure state driver's show. OnShow must not reconfigure
-- protected input/drag flags; ordinary event cleanup follows independently.
for frame,condition in pairs(drivers)do if condition=='[combat] show; hide'then frame:Show()end end
h.event('PLAYER_REGEN_DISABLED')
check(hud:IsShown() and not RA.Placement:IsActive() and not h.named.RCPArsenalPlacementHUD:IsShown(),'Combat cancellation left duplicate samples or lost native live restoration')
check(removed==0 and drivers[hud] and RA:GetDB().position.x==oldX,'Combat attempted driver removal or committed staged coordinates')
h.setCombat(false);h.event('PLAYER_REGEN_ENABLED')
check(removed==1 and next(drivers)==nil and hud:IsShown() and not RA.LayoutPreviewActive,'Safe cleanup did not return visibility ownership to the HUD')
local actualRegister=h.env.RegisterStateDriver;h.env.RegisterStateDriver=nil
check(not RA.Placement:Start('MOVE') and hud:IsShown() and not RA.Placement:IsActive(),'Missing native handoff fell back to duplicates or hid the live HUD')
h.env.RegisterStateDriver=actualRegister

-- Changing icon/name/wrap/scan metrics must change the independent sample
-- footprint, while preserving the one unscaled persistent anchor.
RA:SetHUDEnabled(false);RA:GetDB().compact.iconSize=24;RA:GetDB().compact.nameLength=0;RA:GetDB().compact.wrapAfter=8;RA:GetDB().scan.showStrip=false
RA.Placement:Start('PREVIEW');local smallWidth,smallHeight=h.named.RCPArsenalPlacementHUD:GetWidth(),h.named.RCPArsenalPlacementHUD:GetHeight();RA.Placement:Cancel()
RA:GetDB().compact.iconSize=64;RA:GetDB().compact.nameLength=8;RA:GetDB().compact.wrapAfter=2;RA:GetDB().scan.showStrip=true
RA.Placement:Start('PREVIEW')
check(h.named.RCPArsenalPlacementHUD:GetWidth()~=smallWidth and h.named.RCPArsenalPlacementHUD:GetHeight()>smallHeight,'HUD sample ignored saved icon/name/wrap/scan layout')
check(h.named.RCPArsenalPlacementQUICKBAR.dock:IsShown(),'Quick Bar sample omitted its attached dock')
RA.Placement:Cancel()
print('PASS: '..checks..' setup/global placement assertions (actual addon modules; native rendering/hardware/secure restoration pending)')
