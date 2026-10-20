local _, RA = ...
local Placement = {}
RA.Placement = Placement
local session, bar, samples = nil, nil, {}
local maskedSurfaces, cleanupPending
local ids = {"HUD", "QUICKBAR", "REMINDER"}
local function Secret(value) return type(issecretvalue) == "function" and issecretvalue(value) end
local function Number(value) return not Secret(value) and type(value) == "number" and value == value and math.abs(value) < 1000000 end
local function Copy(position) local out = {}; for key,value in pairs(position or {}) do out[key] = value end; return out end
local function Restricted() return InCombatLockdown() or RA.InEncounter or (IsEncounterInProgress and IsEncounterInProgress()) end
local function RestoreLiveSurfaces()
    if not maskedSurfaces then return true end
    local waiting={}
    for _,item in ipairs(maskedSurfaces)do
        if item.driver and InCombatLockdown() then waiting[#waiting+1]=item
        else
            if item.driver then
                local ok=pcall(UnregisterStateDriver,item.frame,"visibility")
                if not ok then waiting[#waiting+1]=item end
            end
            if not item.driver or not InCombatLockdown() then
                if not item.noCombatRestore or not InCombatLockdown() then pcall(item.frame.Show,item.frame) end
            end
        end
    end
    maskedSurfaces=#waiting>0 and waiting or nil
    cleanupPending=maskedSurfaces~=nil
    if not InCombatLockdown() then
        if RA.UpdateHUDVisibility then RA:UpdateHUDVisibility() end
        if RA.RaidLeaderToolbox then RA.RaidLeaderToolbox:Refresh() end
    end
    return not cleanupPending
end
local function MaskLiveSurfaces()
    if cleanupPending then return false,"Finish the previous secure layout handoff after combat." end
    local all={}
    for _,list in ipairs({RA.GetHUDLayoutSurfaces and RA:GetHUDLayoutSurfaces() or {},
        RA.RaidLeaderToolbox.GetLayoutSurfaces and RA.RaidLeaderToolbox:GetLayoutSurfaces() or {}})do
        for _,item in ipairs(list)do if item.frame and item.frame:IsShown() then
            local ok,protected=pcall(item.frame.IsProtected,item.frame)
            if not ok or Secret(protected) or type(protected)~="boolean" then return false,"Native frame protection is unavailable." end
            if protected and (type(RegisterStateDriver)~="function" or type(UnregisterStateDriver)~="function") then return false,"Secure visibility handoff is unavailable; close this after combat." end
            all[#all+1]={frame=item.frame,protected=protected,noCombatRestore=item.noCombatRestore}
        end end
    end
    maskedSurfaces=all;RA.LayoutPreviewActive=true
    for _,item in ipairs(all)do
        if item.protected then
            local ok=pcall(RegisterStateDriver,item.frame,"visibility",item.noCombatRestore and "hide" or "[combat] show; hide")
            if not ok then RA.LayoutPreviewActive=false;RestoreLiveSurfaces();return false,"Secure visibility handoff failed; live display restored." end
            item.driver=true
        else item.frame:Hide() end
    end
    RA.PersonalTools:SetLayoutMasked(true)
    return true
end
local function Positions()
    local db = RA:GetDB()
    return {HUD=Copy(db.position), QUICKBAR=Copy(db.leaderToolbox.position), REMINDER=Copy(db.personalTools.reminderPosition),
        hudVersion=db.positionAnchorVersion, puckVersion=db.leaderToolbox.positionAnchorVersion, profile=db}
end
local function Unchanged(original)
    local current=Positions()
    if current.profile~=original.profile or current.hudVersion~=original.hudVersion or current.puckVersion~=original.puckVersion then return false end
    for _,id in ipairs(ids) do
        for _,key in ipairs({"point","relativePoint","x","y"}) do if current[id][key]~=original[id][key] then return false end end
    end
    return true
end
local function Font(parent,text,size,color)
    local label=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    RA:ApplyFont(label,size or 11,"REGULAR",false);label:SetTextColor(unpack(color or RA.Theme.Colors.text));label:SetJustifyH("LEFT")
    RA:SetVisualText(label,text or "");return label
end
local function Backdrop(frame,color,border)
    RA.Theme:ApplyRounded(frame,border or RA.Theme.Colors.magenta,9,"outline","BACKGROUND",-5)
    RA.Theme:ApplyRounded(frame,color or RA.Theme.Colors.surface,8,"base","BACKGROUND",-4,{1,-1,-1,1})
end
local function Button(owner,text,width,fn)
    local button=CreateFrame("Button",nil,owner,"BackdropTemplate")
    button:SetSize(width,30);Backdrop(button,RA.Theme.Colors.surfaceRaised,RA.Theme.Colors.line)
    button.label=Font(button,text,10);button.label:SetPoint("CENTER",button,"CENTER",0,0)
    button:SetScript("OnClick",fn);return button
end
local function Enabled(id)
    local db=RA:GetDB()
    return id=="HUD" and db.hudEnabled==true or id=="QUICKBAR" and db.leaderToolbox.enabled==true or id=="REMINDER" and db.personalTools.consumableReminder==true
end
local function RenderReminder()
    local frame=samples.REMINDER
    if not frame or not session then return end
    local personal=RA:GetDB().personalTools
    local kind=session.kind
    frame.icon:SetShown(kind~="empty")
    frame.glow:SetShown((kind=="stone" or kind=="potion") and personal.reminderStoneGlow~=false)
    frame.icon:SetTexture(kind=="potion" and "Interface\\Icons\\INV_Potion_51" or "Interface\\Icons\\INV_Stone_04")
    local text=kind=="empty" and "OUT OF POTIONS!" or (kind=="potion" and personal.reminderPotionText or personal.reminderStoneText)
    local size=kind=="empty" and (personal.reminderEmptyTextSize or 48) or (personal.reminderTextSize or 10)
    local width=math.max(1,UIParent:GetWidth()-32)
    if kind=="empty" then size=math.min(size,width/(#"OUT OF POTIONS!"+1)) end
    RA:ApplyFont(frame.caption,math.max(6,size),"REGULAR",false)
    frame.caption:ClearAllPoints();frame.caption:SetPoint("TOP",frame,"BOTTOM",0,-4)
    frame.caption:SetWidth(math.min(width,kind=="empty" and (#"OUT OF POTIONS!"+1)*size or math.max(260,frame:GetWidth())))
    RA:SetVisualText(frame.caption,(text or ""):gsub("|","||"))
    if frame.SetClampRectInsets then frame:SetClampRectInsets(-math.max(0,(frame.caption:GetWidth()-frame:GetWidth())/2),math.max(0,(frame.caption:GetWidth()-frame:GetWidth())/2),24,-math.max(24,size*2)) end
end
local function CreateSamples()
    if bar then return end
    local T,C=RA.Theme,RA.Theme.Colors
    bar=CreateFrame("Frame","RCPArsenalPlacementSession",UIParent,"BackdropTemplate")
    bar:Hide();bar:SetSize(972,106);bar:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",24,24);bar:SetFrameStrata("DIALOG");Backdrop(bar,C.canvasDeep,C.magenta)
    bar.title=Font(bar,"",12);bar.title:SetPoint("TOPLEFT",bar,"TOPLEFT",14,-10)
    local help=Font(bar,"Examples use saved layout; live content can change size. No item, callout, marker or audio actions. Northern Sky is separate.",9,C.textSoft)
    help:SetPoint("TOPLEFT",bar,"TOPLEFT",14,-31)
    local save=Button(bar,"SAVE POSITIONS",146,function()Placement:Save()end);save:SetPoint("BOTTOMLEFT",bar,"BOTTOMLEFT",14,12);bar.save=save
    local cancel=Button(bar,"CANCEL",100,function()Placement:Cancel("Cancelled")end);cancel:SetPoint("LEFT",save,"RIGHT",8,0)
    local reset=Button(bar,"RESTORE STARTING POSITIONS",238,function()Placement:RestoreStarting()end);reset:SetPoint("LEFT",cancel,"RIGHT",8,0);bar.reset=reset
    local x=530
    for _,entry in ipairs({{"STONE","stone",102},{"POTION","potion",102},{"EMPTY","empty",102}}) do
        local kind=entry[2]
        local button=Button(bar,entry[1],entry[3],function()if session then session.kind=kind;RenderReminder()end end)
        button:SetPoint("BOTTOMLEFT",bar,"BOTTOMLEFT",x,12);x=x+entry[3]+8
    end
    bar:SetScript("OnHide",function()if session then Placement:Cancel("Cancelled")end end)
    if type(UISpecialFrames)=="table" then table.insert(UISpecialFrames,"RCPArsenalPlacementSession") end
    for _,id in ipairs(ids) do
        local key=id
        local frame=CreateFrame("Frame","RCPArsenalPlacement"..id,UIParent,"BackdropTemplate")
        frame:Hide();frame:SetFrameStrata("HIGH");frame:SetMovable(true);frame:SetClampedToScreen(true);frame:EnableMouse(true);frame:RegisterForDrag("LeftButton")
        Backdrop(frame,C.surface,C.orange)
        frame.title=Font(frame,"",10,C.orange);frame.title:SetPoint("BOTTOMLEFT",frame,"TOPLEFT",0,5)
        frame:SetScript("OnDragStart",function(self)if session and session.mode=="MOVE" and not Restricted() then self:StartMoving() end end)
        frame:SetScript("OnDragStop",function(self)
            self:StopMovingOrSizing()
            if not session or session.mode~="MOVE" then return end
            local position={}
            if Restricted() or not RA:CaptureFrameTopLeft(self,position) then Placement:Cancel("Placement cancelled; starting positions kept.");return end
            Placement:SetPosition(key,position.x,position.y)
        end)
        samples[id]=frame
    end
    local hud=CreateFrame("Frame",nil,samples.HUD)
    hud:SetPoint("TOPLEFT",samples.HUD,"TOPLEFT",0,0);hud:SetSize(302,118);samples.HUD.body=hud
    hud.note=Font(hud,"AVAILABLE COOLDOWNS · EXAMPLE",10);hud.note:SetPoint("TOPLEFT",hud,"TOPLEFT",10,-10)
    hud.tiles={}
    for i,label in ipairs({"ALPHA","BRAVO","CHARLIE"}) do
        local tile=CreateFrame("Frame",nil,hud,"BackdropTemplate");tile:SetSize(88,46);tile:SetPoint("TOPLEFT",hud,"TOPLEFT",10+(i-1)*94,-31);Backdrop(tile,C.surfaceRaised,C.line)
        tile.label=Font(tile,label,8);tile.label:SetPoint("BOTTOM",tile,"BOTTOM",0,0)
        tile.icon=tile:CreateTexture(nil,"ARTWORK");RA:RegisterSpellIcon(tile.icon,({98008,62618,31821})[i]);hud.tiles[i]=tile
    end
    hud.strip=CreateFrame("Frame",nil,hud,"BackdropTemplate");Backdrop(hud.strip,C.surfaceRaised,C.line)
    hud.strip.label=Font(hud.strip,"SCAN EXAMPLE 13/20",8,C.textSoft);hud.strip.label:SetPoint("TOPLEFT",hud.strip,"TOPLEFT",5,-3)
    hud.category=Font(hud,"DEF",8,C.textSoft)
    hud.panic=CreateFrame("Frame",nil,hud,"BackdropTemplate");hud.panic:SetSize(18,22);Backdrop(hud.panic,C.surfaceRaised,C.danger)
    hud.panic.label=Font(hud.panic,"!",12,C.danger);hud.panic.label:SetPoint("CENTER",hud.panic,"CENTER",0,0)
    local puck=samples.QUICKBAR
    puck.mark=Font(puck,"RCP",9);puck.mark:SetPoint("CENTER",puck,"CENTER",0,0)
    puck.dock=CreateFrame("Frame",nil,puck,"BackdropTemplate");Backdrop(puck.dock,C.surfaceRaised,C.line)
    puck.dock.label=Font(puck.dock,"READY · PULL · SORT · SPLIT",9);puck.dock.label:SetPoint("CENTER",puck.dock,"CENTER",0,0)
    local reminder=samples.REMINDER
    reminder.glow=reminder:CreateTexture(nil,"BACKGROUND");reminder.glow:SetPoint("TOPLEFT",reminder,"TOPLEFT",-3,3);reminder.glow:SetPoint("BOTTOMRIGHT",reminder,"BOTTOMRIGHT",3,-3);reminder.glow:SetColorTexture(1,0.72,0.18,0.65)
    reminder.icon=reminder:CreateTexture(nil,"ARTWORK");reminder.icon:SetPoint("TOPLEFT",reminder,"TOPLEFT",3,-3);reminder.icon:SetPoint("BOTTOMRIGHT",reminder,"BOTTOMRIGHT",-3,3)
    reminder.caption=Font(reminder,"",10);reminder.caption:SetJustifyH("CENTER")
end
local function RenderHUDExample()
    local root,db=samples.HUD,RA:GetDB()
    local body=root.body
    local layout=RA:GetHUDPlacementMetrics()
    local width,height,y
    body:SetScale(layout.scale);root:SetScale(1)
    body.note:SetShown(layout.mode=="DETAILED")
    if layout.mode=="DETAILED" then
        local d=layout.detailed
        width=layout.detailedWidth;y=d.contentTop-d.categoryHeight
        body.category:ClearAllPoints();body.category:SetPoint("TOPLEFT",body,"TOPLEFT",d.leftInset,d.contentTop)
        RA:SetVisualText(body.category,"RAID DEFENSIVES · EXAMPLE");RA:ApplyFont(body.category,d.categoryFont,"BOLD",false);body.category:Show()
        for i,tile in ipairs(body.tiles)do
            tile:ClearAllPoints();tile:SetPoint("TOPLEFT",body,"TOPLEFT",d.outerInset,y-(i-1)*(d.rowHeight+d.rowGap))
            tile:SetSize(width-d.outerInset*2,d.rowHeight)
            tile.icon:ClearAllPoints();tile.icon:SetPoint("LEFT",tile,"LEFT",d.leftInset,0);tile.icon:SetSize(d.iconSize,d.iconSize)
            tile.label:ClearAllPoints();tile.label:SetPoint("LEFT",tile.icon,"RIGHT",5,0);RA:ApplyFont(tile.label,d.nameFont,"REGULAR",false)
            RA:SetVisualText(tile.label,({"Spirit Link · ALPHA","Barrier · BRAVO","Aura Mastery · CHARLIE"})[i]);tile.label:Show()
        end
        height=math.max(d.minimumHeight,-y+3*(d.rowHeight+d.rowGap)+d.outerInset)
        body.strip:Hide()
    else
        local m=layout.compact
        local lane=RA.CompactLayout:GetLaneGeometry(3,m)
        width=lane.laneWidth+m.panelPadding*2;y=-m.panelPadding
        if m.scanVisible then
            local scan=RA.CompactLayout:GetScanGeometry(3,m)
            body.strip:ClearAllPoints();body.strip:SetPoint("TOPLEFT",body,"TOPLEFT",m.panelPadding,y);body.strip:SetSize(scan.shellWidth,scan.shellHeight)
            RA:ApplyFont(body.strip.label,m.scanStatusFont,"REGULAR",false);body.strip:Show();width=math.max(width,scan.shellWidth+m.panelPadding*2);y=y-scan.shellHeight-m.categoryGap
        else body.strip:Hide() end
        body.category:ClearAllPoints();body.category:SetPoint("TOPLEFT",body,"TOPLEFT",m.panelPadding+m.lanePadding,y-m.lanePadding)
        RA:SetVisualText(body.category,m.labelMode=="FULL" and "Raid Defensives" or "DEF");RA:ApplyFont(body.category,m.categoryFont,"REGULAR",false);body.category:SetShown(m.labelWidth>0)
        for i,tile in ipairs(body.tiles)do
            local x,ty=RA.CompactLayout:GetTilePosition(i,m,lane)
            tile:ClearAllPoints();tile:SetPoint("TOPLEFT",body,"TOPLEFT",m.panelPadding+x,y+ty);tile:SetSize(m.tileWidth,m.tileHeight)
            tile.icon:ClearAllPoints();tile.icon:SetPoint("TOP",tile,"TOP",0,0);tile.icon:SetSize(m.iconSize,m.iconSize)
            tile.label:ClearAllPoints();tile.label:SetPoint("TOP",tile.icon,"BOTTOM",0,-1);RA:ApplyFont(tile.label,m.nameFont,"REGULAR",false)
            RA:SetVisualText(tile.label,({"ALPHA","BRAVO","CHARLIE"})[i]:sub(1,m.nameLength));tile.label:SetShown(m.nameLength>0)
            tile:SetShown(m.overflowMode~="LIMIT" or i<=m.wrapAfter)
        end
        height=-y+lane.laneHeight+m.panelPadding
    end
    body.panic:SetShown(db.leaderToolbox.panicEnabled==true);body.panic:ClearAllPoints();body.panic:SetPoint("RIGHT",body,"TOPLEFT",-5,y-11)
    -- Fixed sample providers use the real layout metrics. Actual group
    -- content can produce a different footprint; never clip sample tiles to
    -- an unrelated empty/hidden live HUD rectangle.
    body:SetSize(width,height);root:SetSize(width*layout.scale,height*layout.scale);body:SetAlpha(db.opacity or 0.96)
    if root.SetClampRectInsets then root:SetClampRectInsets(db.leaderToolbox.panicEnabled and -24*layout.scale or 0,0,24,0)end
end
local function RenderQuickBarExample()
    local root=samples.QUICKBAR
    local m=RA.RaidLeaderToolbox:GetPlacementMetrics()
    local direction=m.direction
    if m.auto then
        local x,y=RA:GetFrameTopLeftInUIParent(root);x,y=x or 0,y or 0
        local spaces={RIGHT=UIParent:GetWidth()-x,LEFT=x,UP=UIParent:GetHeight()-y,DOWN=y}
        direction="RIGHT";for _,key in ipairs({"LEFT","UP","DOWN"})do if spaces[key]>spaces[direction] then direction=key end end
    end
    root:SetSize(m.puckSize,m.puckSize);root.dock:SetSize(m.width,m.height);root.dock:ClearAllPoints()
    if direction=="LEFT" then root.dock:SetPoint("RIGHT",root,"LEFT",-6,0)
    elseif direction=="UP" then root.dock:SetPoint("BOTTOM",root,"TOP",0,6)
    elseif direction=="DOWN" then root.dock:SetPoint("TOP",root,"BOTTOM",0,-6)
    else root.dock:SetPoint("LEFT",root,"RIGHT",6,0)end
    RA:SetVisualText(root.dock.label,"READY · PULL · SORT · SPLIT"..(m.showMissing and " · MISSING" or ""));root.dock:Show()
    if root.SetClampRectInsets then root:SetClampRectInsets(direction=="LEFT" and -(m.width+6) or 0,direction=="RIGHT" and m.width+6 or 0,direction=="UP" and m.height+30 or 24,direction=="DOWN" and -(m.height+6) or 0)end
end
local function RenderPositions()
    for _,id in ipairs(ids) do RA:RestoreFrameTopLeft(samples[id],session.staged[id]);samples[id]:Show() end
end
function Placement:IsActive() return session~=nil end
function Placement:GetState()
    if not session then return {active=false} end
    local positions={};for _,id in ipairs(ids)do positions[id]=Copy(session.staged[id])end
    return {active=true,mode=session.mode,kind=session.kind,positions=positions}
end
function Placement:SetPosition(id,x,y)
    if not session or session.mode~="MOVE" or not samples[id] or not Number(x) or not Number(y) or Restricted() then return false end
    session.staged[id]={point="TOPLEFT",relativePoint="TOPLEFT",x=x,y=y}
    RA:RestoreFrameTopLeft(samples[id],session.staged[id])
    if id=="QUICKBAR" then RenderQuickBarExample() end
    return true
end
function Placement:Start(mode,onClose)
    if mode~="MOVE" and mode~="PREVIEW" then return false,"Choose Preview all or Move all." end
    if Restricted() then return false,"Open placement after combat or the encounter." end
    if RA.MarkerBindings and (RA.MarkerBindings:GetPending() or RA.MarkerBindings:GetHeldKey()) then return false,"Finish the captured key gesture first." end
    if session then self:Cancel("Replaced",true) end
    if RA.PersonalTools then RA.PersonalTools:StopReminderPreview() end
    CreateSamples()
    local original=Positions()
    session={mode=mode,kind="stone",original=original,staged={},starting={},onClose=onClose}
    local db=RA:GetDB()
    local liveFrames={HUD=_G.RCPArsenalHUD,QUICKBAR=_G.RCPArsenalRaidLeaderPuck,REMINDER=_G.RCPArsenalConsumableReminder}
    RenderHUDExample()
    samples.QUICKBAR:SetSize(db.leaderToolbox.puckSize or 30,db.leaderToolbox.puckSize or 30);samples.QUICKBAR:SetScale(1)
    samples.REMINDER:SetSize(db.personalTools.reminderIconSize or 56,db.personalTools.reminderIconSize or 56);samples.REMINDER:SetScale(1)
    for _,id in ipairs(ids) do
        local frame,position=samples[id],original[id]
        local live=liveFrames[id]
        local left,top
        if live then left,top=RA:GetFrameTopLeftInUIParent(live) end
        frame:ClearAllPoints()
        if Number(left) and Number(top) then frame:SetPoint("TOPLEFT",UIParent,"TOPLEFT",left,top-UIParent:GetHeight())
        elseif id~="REMINDER" and (id=="HUD" and original.hudVersion or original.puckVersion or 0)>=2 then RA:RestoreFrameTopLeft(frame,position)
        else frame:SetPoint(position.point or "CENTER",UIParent,position.relativePoint or position.point or "CENTER",position.x or 0,position.y or (id=="REMINDER" and -140 or 0)) end
        frame:Show()
        local staged={}
        if not RA:CaptureFrameTopLeft(frame,staged) then self:Cancel("Position unavailable",true);return false,"Placement coordinates are unavailable." end
        session.staged[id],session.starting[id]=staged,Copy(staged)
        local label=id=="HUD" and "Available Cooldowns" or id=="QUICKBAR" and "Quick Bar" or "Consumable reminder"
        RA:SetVisualText(frame.title,label..(Enabled(id) and " · sample" or " · Off · placement sample")..(mode=="MOVE" and " · Preview position" or ""))
        frame.title:SetWordWrap(true);frame.title:SetWidth(math.min(320,UIParent:GetWidth()-32))
        frame:EnableMouse(mode=="MOVE")
    end
    RA:SetVisualText(bar.title,mode=="MOVE" and "MOVE ALL · samples — drag the labeled frames. Save applies positions." or "PREVIEW ALL · fixed samples using saved appearance. No tools are enabled.")
    bar.save:SetShown(mode=="MOVE");bar.reset:SetShown(mode=="MOVE")
    bar:SetScale(math.min(1,math.max(0.1,(UIParent:GetWidth()-48)/972)))
    RenderReminder();RenderQuickBarExample();bar:Show()
    local masked,maskReason=MaskLiveSurfaces()
    if not masked then self:Cancel(maskReason,true);return false,maskReason end
    if RA.WorldMarkers.SetInputSuppressed then RA.WorldMarkers:SetInputSuppressed(true,"placement") end
    return true
end
function Placement:RestoreStarting()
    if not session or Restricted() then return false end
    for _,id in ipairs(ids)do session.staged[id]=Copy(session.starting[id])end
    RenderPositions();RenderQuickBarExample();return true
end
function Placement:Cancel(reason,silent)
    if not session then return end
    local close=session.onClose;session=nil
    for _,id in ipairs(ids)do samples[id]:StopMovingOrSizing();samples[id]:Hide()end
    bar:Hide()
    RA.LayoutPreviewActive=false
    RA.PersonalTools:SetLayoutMasked(false)
    RestoreLiveSurfaces()
    if RA.WorldMarkers.SetInputSuppressed then RA.WorldMarkers:SetInputSuppressed(false,"placement") end
    if close and not silent then close(reason or "Cancelled") end
end
RA:RegisterEvent("PLAYER_REGEN_ENABLED",function()if cleanupPending then RestoreLiveSurfaces() end end)
local function RefreshLivePositions()
    if RA.RefreshHUDPosition and RA:RefreshHUDPosition()==false then error("HUD position handoff refused") end
    if RA.RaidLeaderToolbox.RefreshPosition and RA.RaidLeaderToolbox:RefreshPosition()==false then error("Quick Bar position handoff refused") end
    if RA.PersonalTools.RefreshReminderPosition and RA.PersonalTools:RefreshReminderPosition()==false then error("Reminder position handoff refused") end
end
function Placement:Save()
    if not session or session.mode~="MOVE" then return false,"Open Move all first." end
    if Restricted() then self:Cancel("Placement cancelled by combat; starting positions kept.");return false end
    if not Unchanged(session.original) then self:Cancel("Positions changed outside this session; newer values kept.");return false end
    for _,id in ipairs(ids)do
        local actual={}
        if not RA:CaptureFrameTopLeft(samples[id],actual) or not Number(actual.x) or not Number(actual.y) then return false,"Placement coordinates are unavailable." end
        session.staged[id]=actual
    end
    local db,original=RA:GetDB(),session.original
    db.position=Copy(session.staged.HUD);db.positionAnchorVersion=3
    db.leaderToolbox.position=Copy(session.staged.QUICKBAR);db.leaderToolbox.positionAnchorVersion=3
    db.personalTools.reminderPosition=Copy(session.staged.REMINDER)
    local ok=pcall(RefreshLivePositions)
    if not ok then
        db.position,db.positionAnchorVersion=Copy(original.HUD),original.hudVersion
        db.leaderToolbox.position,db.leaderToolbox.positionAnchorVersion=Copy(original.QUICKBAR),original.puckVersion
        db.personalTools.reminderPosition=next(original.REMINDER) and Copy(original.REMINDER) or nil
        pcall(RefreshLivePositions);self:Cancel("Placement could not be applied; starting positions restored.");return false
    end
    self:Cancel("Positions saved")
    RA:FireCallback("OVERLAY_POSITION_CHANGED")
    return true
end
for _,name in ipairs({"PLAYER_REGEN_DISABLED","ENCOUNTER_START","DISPLAY_SIZE_CHANGED","UI_SCALE_CHANGED"})do
    RA:RegisterEvent(name,function()Placement:Cancel("Placement cancelled by combat or display change; starting positions kept.")end)
end
for _,name in ipairs({"PROFILE_RESET","PROFILE_IMPORTED","OVERLAY_POSITION_CHANGED"})do
    RA:RegisterCallback(name,function()Placement:Cancel("Placement cancelled because settings or positions changed.")end)
end
