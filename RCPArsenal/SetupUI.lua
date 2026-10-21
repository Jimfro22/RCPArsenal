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
-- Local addon metadata only. The version-query workflow remains on Addons.
local function Addons(parent, kit, refresh)
    local T, expanded, chips = RA.Theme, false, {}
    local header=kit.Button(parent,"Morning Brew addons · 6 addons +",918,34,function()
        expanded=not expanded; refresh()
    end)
    local details=CreateFrame("Frame",nil,parent); T.SetSize(details,918,220); details:Hide()
    Text(kit,details,"Download and install outside WoW.",10,0,0,918)
    local n=0
    for _,entry in ipairs(RA.AddonCatalog.Entries) do
        if not entry.internal then
            local definition=entry
            local chip=kit.Button(details,entry.name,451,56,function()RA:ShowAddonLink(definition.id)end)
            T.SetPoint(chip,"TOPLEFT",details,"TOPLEFT",(n%2)*467,-28-math.floor(n/2)*62)
            chip.label:SetWordWrap(true);chip.label:SetHeight(48);RA:ApplyFont(chip.label,10,"REGULAR",false)
            chip:HookScript("OnEnter",function(owner)
                GameTooltip:SetOwner(owner,"ANCHOR_RIGHT");GameTooltip:SetText(definition.name)
                GameTooltip:AddLine(definition.priority.." · "..definition.description,0.76,0.80,0.86,true)
                GameTooltip:AddLine("Copy its download link, then install outside WoW.",0.76,0.80,0.86,true);GameTooltip:Show()
            end)
            chip:HookScript("OnLeave",function()GameTooltip:Hide()end)
            chips[entry.id]=chip;n=n+1
        end
    end
    return function(y)
        header:ClearAllPoints();T.SetPoint(header,"TOPLEFT",parent,"TOPLEFT",0,-y)
        details:ClearAllPoints();T.SetPoint(details,"TOPLEFT",header,"BOTTOMLEFT",0,-8)
        details:SetShown(expanded)
        RA:SetVisualText(header.label,"Morning Brew addons · 6 addons "..(expanded and "-" or "+"))
        if expanded then
            local report=RA.AddonCatalog:GetLocalReport()
            for id,chip in pairs(chips) do
                local entry,row=RA.AddonCatalog:GetEntry(id),(report.byID or {})[id] or {}
                local status=row.installed==false and "Not detected" or row.installed==true and row.enabled==false and "Disabled" or row.installed==true and "Installed" or "Unknown"
                RA:SetVisualText(chip.label,entry.name.."\n"..entry.priority.." · "..status)
            end
        end
        return y+34+(expanded and 228 or 0)
    end
end
function RA:CreateGeneralPane(parent,kit)
    local T,Setup=self.Theme,self.Setup
    kit.Heading(parent,"General","Choose the tools you want.")
    local body,Resize=Body(parent)
    local welcome=Text(kit,body,"Welcome to Arsenal. Turn on only the tools you want.",12,0,0,918)
    local title=Text(kit,body,"Your tools",13,0,-34,918)
    local rows={}
    for i,row in ipairs({{"autoRes","Normal resurrection"},{"reminder","Consumable reminder"},{"quickBar","Quick Bar"},{"hud","Available Cooldowns"}}) do
        rows[i]=Text(kit,body,"",11,((i-1)%2)*467,-66-math.floor((i-1)/2)*30,451)
        rows[i].choiceKey,rows[i].choiceLabel=row[1],row[2]
    end
    local role=Text(kit,body,"",10,0,-136,918)
    local pending=Text(kit,body,"Choices not saved.",10,0,-162,380)
    local review=kit.Button(body,"REVIEW CHOICES",190,34,function()RA:OpenSetup()end,true)
    T.SetPoint(review,"TOPLEFT",body,"TOPLEFT",0,-190)
    local discard=kit.Button(body,"DISCARD",130,34,function()Setup:Cancel();kit.Refresh()end)
    T.SetPoint(discard,"LEFT",review,"RIGHT",10,0)
    local skip=kit.Button(body,"SKIP FOR NOW",160,34,function()Setup:Skip();kit.Refresh()end)
    T.SetPoint(skip,"LEFT",review,"RIGHT",10,0)
    local Refresh
    local addonLayout=Addons(body,kit,function()Refresh()end)
    Refresh=function()
        welcome:SetShown(Setup:IsIntroduction())
        for _,row in ipairs(rows) do RA:SetVisualText(row,row.choiceLabel.." · "..(Setup:GetCurrent(row.choiceKey) and "On" or "Off")) end
        RA:SetVisualText(role,"Presentation: "..(Setup:GetRole()=="LEADER" and "Raid leader" or "Raider"))
        pending:SetShown(Setup:HasDraft())
        RA:SetVisualText(review.label,Setup:HasDraft() and "RESUME REVIEW" or "REVIEW CHOICES")
        discard:SetShown(Setup:HasDraft());skip:SetShown(Setup:IsIntroduction() and not Setup:HasDraft())
        Resize(addonLayout(246)+14)
    end
    return Refresh
end
function RA:CreateSetupPane(parent,kit)
    local T,Setup=self.Theme,self.Setup
    kit.Heading(parent,"Review choices","Changes apply when you save.")
    local body,Resize=Body(parent,64)
    local role=kit.Segmented(body,"REVIEW AS",{{label="RAIDER",value="RAIDER"},{label="RAID LEADER",value="LEADER"}},
        function()return Setup:Get("role") or "RAIDER"end,function(value)Setup:Set("role",value)end)
    T.SetPoint(role,"TOPLEFT",body,"TOPLEFT",0,0);T.SetSize(role,451,54);role:Layout(451)
    Text(kit,body,"Presentation only. Raid permissions still apply.",10,0,-64,918)
    local personal=kit.Card(body,"PERSONAL TOOLS","")
    T.SetPoint(personal,"TOPLEFT",body,"TOPLEFT",0,-96);T.SetSize(personal,451,190)
    local leader=kit.Card(body,"RAID LEADER TOOLS","")
    T.SetPoint(leader,"TOPLEFT",body,"TOPLEFT",467,-96);T.SetSize(leader,451,190)
    local function Toggle(owner,label,detail,key,y)
        local control=kit.Toggle(owner,label,detail,function()return Setup:Get(key)end,function(value)Setup:Set(key,value)end)
        T.SetWidth(control,419);T.SetPoint(control,"TOPLEFT",owner,"TOPLEFT",16,y)
    end
    Toggle(personal,"Normal resurrection","Ordinary offers; combat resurrection stays manual.","autoRes",-64)
    Toggle(personal,"Consumable reminder","Ready Healthstone first, then healing potion.","reminder",-124)
    Toggle(leader,"Quick Bar","Hover puck for raid setup controls.","quickBar",-64)
    Toggle(leader,"Available Cooldowns","Enables the HUD and inspection.","hud",-124)
    local leaderSummary=Text(kit,body,"Existing leader tools stay as saved.",10,467,-114,451)
    local Refresh
    local addonLayout=Addons(body,kit,function()Refresh()end)
    local status=Text(kit,parent,"",10,0,-610,460)
    local function Finish(save)
        local ok,result
        if save then ok,result=Setup:Save()
        elseif Setup:IsFirstUseDraft() then ok,result=Setup:Skip()
        else ok,result=Setup:Cancel() end
        if ok then RA:OpenConfig(result or "GENERAL") else RA:SetVisualText(status,result or "Choices unavailable.");Refresh() end
    end
    local cancel=kit.Button(parent,"CANCEL",156,34,function()Finish(false)end)
    T.SetPoint(cancel,"BOTTOMRIGHT",parent,"BOTTOMRIGHT",-210,16)
    local save=kit.Button(parent,"SAVE CHOICES",200,34,function()Finish(true)end,true)
    T.SetPoint(save,"BOTTOMRIGHT",parent,"BOTTOMRIGHT",0,16)
    local reload=kit.Button(body,"RELOAD CHOICES",180,32,function()Setup:Reload();RA:SetVisualText(status,"");kit.Refresh()end)
    Refresh=function()
        local isLeader=Setup:Get("role")=="LEADER"
        leader:SetShown(isLeader);leaderSummary:SetShown(not isLeader and (Setup:Get("quickBar") or Setup:Get("hud")))
        local conflict=Setup:GetConflict()
        reload:ClearAllPoints();T.SetPoint(reload,"TOPLEFT",body,"TOPLEFT",0,-302);reload:SetShown(conflict~=nil)
        Resize(addonLayout(conflict and 350 or 302)+14)
        RA:SetVisualText(cancel.label,Setup:IsFirstUseDraft() and "SKIP FOR NOW" or "CANCEL")
        local restricted=InCombatLockdown() or RA.InEncounter or (IsEncounterInProgress and IsEncounterInProgress())
        save:SetEnabled(not restricted and not conflict);save:SetAlpha((restricted or conflict) and 0.5 or 1)
        RA:SetVisualText(status,conflict or (restricted and "Save after combat. Your choices are kept." or ""))
    end
    return Refresh
end
