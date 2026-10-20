local _, RA = ...
function RA:CreateSetupPane(parent, kit)
    local T, C, Setup = self.Theme, self.Theme.Colors, self.Setup
    local function Text(owner, value, size, x, y, width)
        local label = kit.Font(owner, size or 10, C.textSoft, "REGULAR")
        self:SetVisualText(label, value)
        label:SetWordWrap(true); T.SetWidth(label, width or 420)
        T.SetPoint(label, "TOPLEFT", owner, "TOPLEFT", x or 0, y or 0)
        return label
    end
    local function Set(key, value) Setup:Set(key, value) end
    local function Toggle(owner, label, detail, key, x, y, width)
        local control = kit.Toggle(owner, label, detail, function() return Setup:Get(key) end, function(value) Set(key, value) end)
        T.SetWidth(control, width or 426); T.SetPoint(control, "TOPLEFT", owner, "TOPLEFT", x or 16, y)
        return control
    end
    kit.Heading(parent, "Set up Arsenal", "Turn on only what you want. You can change everything later.")
    local role = kit.Segmented(parent, "HOW DO YOU USE ARSENAL?", {{label="RAIDER",value="RAIDER"},{label="RAID LEADER",value="LEADER"}},
        function() return Setup:Get("role") or "RAIDER" end, function(value) Set("role",value) end)
    T.SetPoint(role,"TOPLEFT",parent,"TOPLEFT",0,-62);T.SetSize(role,458,54);role:Layout(458)
    Text(parent,"Presentation only. Raid permissions still apply.",9,0,-122,458)
    Text(parent,"MORNING BREW ADDONS · We use these addons. Download and install outside WoW.",8.5,0,-490,760)
    local checklist=kit.Button(parent,"VIEW CHECKLIST",142,22,function()RA:OpenConfig("ADDONS")end)
    T.SetPoint(checklist,"TOPRIGHT",parent,"TOPRIGHT",0,-483)
    local chips={}
    for index,entry in ipairs(RA.AddonCatalog.Entries) do
        if not entry.internal then
            local definition=entry
            local chip=kit.Button(parent,entry.name,467,28,function()RA:ShowAddonLink(definition.id)end)
            local offset=index-2
            T.SetPoint(chip,"TOPLEFT",parent,"TOPLEFT",(offset%2)*483,-510-math.floor(offset/2)*30)
            chip.label:SetWordWrap(false);chip.label:SetHeight(24);RA:ApplyFont(chip.label,10,"REGULAR",false)
            chip:HookScript("OnEnter",function(self)
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(definition.name)
                GameTooltip:AddLine(definition.priority.." · "..definition.description,0.76,0.80,0.86,true)
                GameTooltip:AddLine("Copy its download link, then install outside WoW. This does not install or configure it.",0.76,0.80,0.86,true);GameTooltip:Show()
            end)
            chip:HookScript("OnLeave",function()GameTooltip:Hide()end)
            chips[definition.id]=chip
        end
    end
    local everyone=kit.Card(parent,"FOR EVERYONE","Optional personal tools. Existing child preferences are preserved.")
    T.SetPoint(everyone,"TOPLEFT",parent,"TOPLEFT",0,-150);T.SetSize(everyone,458,326)
    Toggle(everyone,"Accept normal resurrection","Combat resurrection stays manual.","autoRes",16,-48)
    Toggle(everyone,"Healthstone / potion reminder","Ready Healthstone first, then a potion. You use the item.","reminder",16,-102)
    local reminder=CreateFrame("Frame",nil,everyone)
    T.SetPoint(reminder,"TOPLEFT",everyone,"TOPLEFT",16,-156);T.SetSize(reminder,426,170)
    local threshold=kit.Slider(reminder,"SHOW AT OR BELOW",1,99,1,function()return Setup:Get("threshold") or 40 end,
        function(value)Set("threshold",value)end,function(value)return tostring(value).."% health"end)
    T.SetPoint(threshold,"TOPLEFT",reminder,"TOPLEFT",0,0);T.SetWidth(threshold,426)
    Toggle(reminder,"Play low-health sound","Native warning ~35%; separate from visual health.","sound",0,-62,205)
    Toggle(reminder,"Healthstone edge glow","Healthstone only at ≤35%, while visible.","glow",221,-62,205)
    local savedSound=Text(reminder,"",9,0,-125,286)
    local sampleResult=Text(parent,"Team-check replies stay available with tools off.",9,0,-134,950)
    local play=kit.Button(reminder,"PLAY SOUND SAMPLE",154,28,function()
        local ok,reason=RA.PersonalTools:PreviewReminderSound()
        RA:SetVisualText(sampleResult,reason or (ok and "Played the saved sound sample." or "Sound sample unavailable."))
    end)
    T.SetPoint(play,"TOPRIGHT",reminder,"TOPRIGHT",0,-126)
    local leader=kit.Card(parent,"RAID-LEADER CHOICES","These controls grant no group permissions.")
    T.SetPoint(leader,"TOPRIGHT",parent,"TOPRIGHT",0,-150);T.SetSize(leader,478,326)
    local leaderChoices=CreateFrame("Frame",nil,leader);leaderChoices:SetAllPoints(leader)
    Toggle(leaderChoices,"Enable Quick Bar","Hover puck for ready checks, countdowns and raid setup.","quickBar",16,-48,446)
    local missing=Toggle(leaderChoices,"Missing provider classes","Group classes only; no inspection.","missing",32,-110,430)
    Toggle(leaderChoices,"Enable Available Cooldowns","Inspects the group for available abilities. No live cooldown timers.","hud",16,-164,446)
    local callout=kit.Segmented(leaderChoices,"TILE LEFT-CLICK",{{label="OFF",value="OFF"},{label="WHISPER",value="WHISPER"},{label="SAY",value="SAY"}},
        function()return Setup:Get("leftClick") or "OFF"end,function(value)Set("leftClick",value)end)
    T.SetPoint(callout,"TOPLEFT",leaderChoices,"TOPLEFT",32,-226);T.SetSize(callout,430,54);callout:Layout(430)
    local calloutHelp=Text(leaderChoices,"Whisper sends the clicked player a callout. Say is nearby chat. Off sends neither.",9,32,-286,430)
    local raider=CreateFrame("Frame",nil,leader);raider:SetAllPoints(leader)
    Text(raider,"Your raid lead can still request supported addon and supply checks.\n\nOptional tools stay as reviewed here. Existing raid tools on a setup replay keep their saved choices.",12,20,-80,434)
    local showLeader=kit.Button(raider,"SHOW RAID-LEADER CHOICES",310,34,function()Set("role","LEADER")end)
    T.SetPoint(showLeader,"TOPLEFT",raider,"TOPLEFT",20,-228)
    local summary=Text(parent,"",9.3,0,-620,540)
    local count=Text(parent,"",10,0,-602,540)
    local function Finish(save)
        local ok,result
        if save then ok,result=Setup:Save() else ok,result=Setup:Skip() end
        if not ok then RA:SetVisualText(sampleResult,result or "Choices unavailable.");return end
        RA:OpenConfig(result or "ADDONS")
    end
    local skip=kit.Button(parent,"SKIP FOR NOW",174,34,function()Finish(false)end)
    T.SetPoint(skip,"BOTTOMRIGHT",parent,"BOTTOMRIGHT",-214,10)
    local save=kit.Button(parent,"SAVE CHOICES",200,34,function()Finish(true)end,true)
    T.SetPoint(save,"BOTTOMRIGHT",parent,"BOTTOMRIGHT",0,10)
    return function()
        local report=RA.AddonCatalog:GetLocalReport()
        for id,chip in pairs(chips)do
            local entry,row=RA.AddonCatalog:GetEntry(id),report.byID[id] or {}
            local status=row.installed==false and "Not detected" or row.installed==true and row.enabled==false and "Disabled" or row.installed==true and "Installed" or "Unknown"
            local name=id=="northernsky" and "Northern Sky" or entry.name
            RA:SetVisualText(chip.label,name.." · "..entry.priority.." · "..status)
        end
        local isLeader=Setup:Get("role")=="LEADER"
        leaderChoices:SetShown(isLeader);raider:SetShown(not isLeader)
        reminder:SetShown(Setup:Get("reminder")==true)
        missing:SetShown(Setup:Get("quickBar")==true)
        callout:SetShown(Setup:Get("hud")==true);calloutHelp:SetShown(Setup:Get("hud")==true)
        local personal=RA:GetDB().personalTools
        local sound=RA.ReminderSounds:Get(personal.reminderSoundChoice)
        RA:SetVisualText(savedSound,(sound and sound.label or "Sound 6").." · "..(personal.reminderSoundChannel or "Master").."\nSaved sound and audio policy.")
        local selected,detail=Setup:GetSummary()
        RA:SetVisualText(count,tostring(selected).." tools selected")
        RA:SetVisualText(summary,detail:gsub("\n"," · "))
        local restricted=InCombatLockdown() or RA.InEncounter or (IsEncounterInProgress and IsEncounterInProgress())
        save:SetEnabled(not restricted);save:SetAlpha(restricted and 0.5 or 1)
        if restricted then RA:SetVisualText(sampleResult,"Finish setup after combat. Your draft is kept; nothing applies automatically.") end
    end
end
