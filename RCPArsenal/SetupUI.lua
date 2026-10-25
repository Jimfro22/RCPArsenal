local _, RA = ...
local function Text(kit, owner, value, size, x, y, width)
    local label = kit.Font(owner, size or 10, RA.Theme.Colors.textSoft, "REGULAR")
    RA:SetVisualText(label, value); label:SetWordWrap(true)
    RA.Theme.SetWidth(label, width or 918)
    RA.Theme.SetPoint(label, "TOPLEFT", owner, "TOPLEFT", x or 0, y or 0)
    return label
end
local function Body(parent, bottom)
    local T = RA.Theme
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    T.SetPoint(scroll,"TOPLEFT",parent,"TOPLEFT",0,-62)
    T.SetPoint(scroll,"BOTTOMRIGHT",parent,"BOTTOMRIGHT",-28,bottom or 0)
    local child = CreateFrame("Frame",nil,scroll); T.SetSize(child,918,598-(bottom or 0)); scroll:SetScrollChild(child)
    local function Resize(height)
        child:SetHeight(height)
        local viewport=scroll:GetHeight()
        if not viewport or viewport<=0 then viewport=598-(bottom or 0) end
        local current=scroll:GetVerticalScroll() or 0
        local maximum=math.max(0,height-viewport)
        if current>maximum then scroll:SetVerticalScroll(maximum) end
    end
    return child, Resize
end
local function Help(owner, title, detail)
    owner:HookScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(title)
        GameTooltip:AddLine(type(detail)=="function" and detail() or detail,0.76,0.80,0.86,true);GameTooltip:Show()
    end)
    owner:HookScript("OnLeave",function()GameTooltip:Hide()end)
end
function RA:CreateGeneralPane(parent,kit)
    local T,C=self.Theme,self.Theme.Colors
    kit.Heading(parent,"General","")
    local body,Resize=Body(parent)
    Text(kit,body,"Personal tools",13,0,0,451)
    Text(kit,body,"Raid tools",13,467,0,451)
    local feedback=Text(kit,body,"",10,0,-124,918);feedback:Hide()
    local function Result(ok,reason)
        RA:SetVisualText(feedback,ok==false and (reason or "Setting unavailable.") or "")
        feedback:SetShown(ok==false);kit.Refresh()
    end
    local function Personal(key,value) Result(RA.PersonalTools:SetOption(key,value)) end
    local definitions={
        {label="Auto resurrection",key="autoRes",column=0,row=0,page="MYTOOLS",
            help="Accepts incoming offers outside detected combat by default. Personal Tools has a separate combat opt-in. Does not cast resurrection.",
            get=function()return RA:GetDB().personalTools.autoRes==true end,set=function(v)Personal("autoRes",v)end},
        {label="Consumable reminder",key="reminder",column=0,row=1,page="MYTOOLS",
            help="Shows a Healthstone or healing potion reminder. You use the item. Sound and glow have separate settings.",
            get=function()return RA:GetDB().personalTools.consumableReminder==true end,set=function(v)Personal("consumableReminder",v)end},
        {label="Quick Bar",key="quickBar",column=1,row=0,page="QUICKBAR",
            help="Shows the raid setup puck and controls. Privileged actions still require raid leader or assistant permission.",
            get=function()return RA:GetDB().leaderToolbox.enabled==true end,set=function(v)Result(RA:SetQuickBarEnabled(v))end},
        {label="Available Cooldowns",key="hud",column=1,row=1,page="COOLDOWNS",
            help="Enables the HUD and inspection to show ability providers. Provider ownership is static; cooldown use and remaining time are not tracked.",
            get=function()return RA:IsHUDEnabled()end,set=function(v)Result(RA:SetHUDEnabled(v))end},
    }
    for _,definition in ipairs(definitions) do
        local d=definition
        local toggle=kit.Toggle(body,d.label,"",d.get,d.set)
        toggle:SetCompact(d.row%2==1);T.SetWidth(toggle,353)
        T.SetPoint(toggle,"TOPLEFT",body,"TOPLEFT",d.column*467,-28-d.row*46)
        Help(toggle,d.label,d.help)
        local settings=kit.Button(body,"Settings",90,44,function()RA:OpenConfig(d.page)end)
        T.SetPoint(settings,"TOPLEFT",body,"TOPLEFT",d.column*467+361,-28-d.row*46)
        Help(settings,d.label,"Open settings. Viewing this page does not enable the tool.")
    end
    local divider=body:CreateTexture(nil,"ARTWORK");divider:SetColorTexture(unpack(C.line));T.SetSize(divider,918,1)
    T.SetPoint(divider,"TOPLEFT",body,"TOPLEFT",0,-140)
    Text(kit,body,"Morning Brew addons",13,0,-160,918)
    local rows,Refresh={},nil
    for _,entry in ipairs(RA.AddonCatalog.Entries) do
        if not entry.internal then
            local d=entry;local index=#rows
            local row=CreateFrame("Frame",nil,body,"BackdropTemplate")
            T.SetSize(row,918,42);T.SetPoint(row,"TOPLEFT",body,"TOPLEFT",0,-190-index*44)
            kit.Backdrop(row,index%2==1 and C.surfaceRaised or C.surface,C.transparent,2,false)
            row:EnableMouse(true)
            Help(row,d.name,d.description.." Installed status is local; it does not establish configuration or the latest version.")
            local name=CreateFrame("Button",nil,row)
            T.SetSize(name,354,42);T.SetPoint(name,"TOPLEFT",row,"TOPLEFT",0,0)
            name.label=Text(kit,name,d.name,11,14,-14,326);name.label:SetWordWrap(false)
            name:SetScript("OnClick",function()RA:ShowAddonLink(d.id)end)
            name:SetScript("OnEnter",function()name.label:SetTextColor(unpack(row.nameColor==C.muted and C.textSoft or C.orange))end)
            name:SetScript("OnLeave",function()name.label:SetTextColor(unpack(row.nameColor or C.muted))end)
            Help(name,d.name,d.description.." Click to copy its CurseForge download link.")
            local priority=Text(kit,row,d.priority=="Optional" and "Optional" or "Important",10,370,-14,116)
            local status=Text(kit,row,"",10,0,0,300)
            status:ClearAllPoints();T.SetPoint(status,"TOPRIGHT",row,"TOPRIGHT",-14,-14)
            status:SetJustifyH("RIGHT");status:SetWordWrap(false)
            rows[#rows+1]={frame=row,entry=d,name=name.label,priority=priority,status=status}
        end
    end
    Refresh=function()
        local report=RA.AddonCatalog:GetLocalReport()
        for _,row in ipairs(rows) do
            local data=(report.byID or {})[row.entry.id] or {}
            local state,label="unknown","Unknown"
            if data.installed==false then state,label="missing","Missing"
            elseif data.installed==true and data.enabled==false then
                state,label="disabled",data.loaded==true and "Disabled · reload required" or "Disabled"
            elseif data.installed==true and data.enabled==true and data.loaded==false then state,label="not_loaded","Not loaded"
            elseif data.installed==true and data.enabled==true and data.loaded==true then state,label="loaded","Installed" end
            row.frame.state=state;RA:SetVisualText(row.status,label)
            local active=data.installed==true and data.enabled==true
            local color=active and C.magenta or C.muted
            row.frame.nameColor=color
            row.name:SetTextColor(unpack(color));row.status:SetTextColor(unpack(color))
            row.priority:SetTextColor(unpack(active and C.textSoft or C.muted))
        end
        Resize(190+#rows*44+14)
    end
    parent:HookScript("OnShow",function()RA.AddonCatalog:RefreshLocal();Refresh()end)
    return Refresh
end
