local _, RA = ...

-- The hub only reads addon metadata and saved preferences on open. Network
-- requests and target approval always require the corresponding button click.
function RA:CreateHubPanes(panes, kit)
    local T, C = self.Theme, self.Theme.Colors
    local Point, Size, Width = T.SetPoint, T.SetSize, T.SetWidth
    local Font, Button, Card = kit.Font, kit.Button, kit.Card
    local selectedAddon = "arsenal"
    local refreshers, matrixRows, selectors, targetDrafts = {}, {}, {}, {}
    local feedback, targetBox, matrixMeta, matrixScroll, matrixChild, showDetails
    local lastTargetID, lastTargetValue
    local linkOverlay, linkBox, linkTitle, resetOverlay, supplyOverlay, soundOverlay
    local function SetText(region, value) RA:SetVisualText(region, value or "") end
    local function Text(parent, value, size, x, y, width, color)
        local text = Font(parent, size or 11, color or C.textSoft, "REGULAR")
        SetText(text, value)
        text:SetWordWrap(true)
        Point(text, "TOPLEFT", parent, "TOPLEFT", x or 0, y or 0)
        if width then Width(text, width) end
        return text
    end
    local function Literal(value)
        return type(value) == "string" and value:gsub("|", "||") or "Unknown"
    end
    local function Tri(value)
        if value == true then return "Yes" end
        if value == false then return "No" end
        return "Unknown"
    end
    local function Result(ok, message)
        if feedback then SetText(feedback, message or (ok and "Saved." or "Unavailable.")) end
    end
    function RA:HideHubTransientDialogs()
        if linkOverlay then linkOverlay:Hide() end
        if resetOverlay then resetOverlay:Hide() end
        if supplyOverlay then supplyOverlay:Hide() end
        if soundOverlay then soundOverlay:Hide() end
        if RA.PersonalTools.StopReminderPreview then RA.PersonalTools:StopReminderPreview() end
    end
    local function CopyLink(entry)
        if not linkOverlay then
            linkOverlay = CreateFrame("Frame", nil, RA.ConfigFrame, "BackdropTemplate")
            linkOverlay:SetAllPoints(RA.ConfigFrame)
            linkOverlay:SetFrameLevel(RA.ConfigFrame:GetFrameLevel() + 100)
            linkOverlay:EnableMouse(true)
            kit.Backdrop(linkOverlay, {0, 0, 0, 0.68}, C.line, 14, false)
            local dialog = CreateFrame("Frame", nil, linkOverlay, "BackdropTemplate")
            Size(dialog, 700, 150)
            Point(dialog, "CENTER", linkOverlay, "CENTER", 0, 0)
            dialog:EnableMouse(true)
            kit.Backdrop(dialog, C.surface, C.lineStrong, 14, true)
            linkTitle = Text(dialog, "", 14, 20, -18, 650, C.text)
            linkBox = CreateFrame("EditBox", nil, dialog, "BackdropTemplate")
            Size(linkBox, 660, 34); Point(linkBox, "TOPLEFT", dialog, "TOPLEFT", 20, -51)
            kit.Backdrop(linkBox, C.input, C.line, 8, false)
            RA:ApplyFont(linkBox, 11, "REGULAR", false)
            linkBox:SetTextInsets(10, 10, 0, 0); linkBox:SetAutoFocus(false)
            linkBox:SetScript("OnEscapePressed", function() linkOverlay:Hide() end)
            linkBox:SetScript("OnEnterPressed", function() linkOverlay:Hide() end)
            local close = Button(dialog, "CLOSE", 100, 30, function() linkOverlay:Hide() end)
            Point(close, "BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -20, 15)
            RA.ConfigFrame:HookScript("OnHide", function() linkOverlay:Hide() end)
        end
        SetText(linkTitle, entry.name .. " — copy link to your browser")
        linkBox:SetText(entry.url); linkBox:SetCursorPosition(0)
        linkOverlay:Show(); linkBox:SetFocus(); linkBox:HighlightText()
    end

    function RA:ShowAddonLink(id)
        local entry = RA.AddonCatalog:GetEntry(id)
        if entry then CopyLink(entry) end
    end
    RA.ConfigFrame:HookScript("OnHide", function() RA:HideHubTransientDialogs() end)

    local addons = panes.ADDONS
    kit.Heading(addons, "Addons & versions", "One roster, all seven addons. Select a column for its local setup, download link, and approved target.")
    matrixMeta = Text(addons, "", 9.4, 0, -54, 540)
    local refresh = Button(addons, "REFRESH LOCAL", 156, 32, function()
        -- This action may notify synchronously; the renderer below never calls
        -- RefreshLocal, so READINESS_UPDATED cannot recurse through it.
        if not RA.Readiness:RefreshLocal() then RA.AddonCatalog:RefreshLocal() end
        refreshers.ADDONS()
    end)
    Point(refresh, "TOPRIGHT", addons, "TOPRIGHT", -234, -54)
    local query = Button(addons, "CHECK GROUP VERSIONS", 218, 32, function()
        local ok, reason = RA.Readiness:QueryGroup(); Result(ok, reason)
        refreshers.ADDONS()
    end, true)
    Point(query, "TOPRIGHT", addons, "TOPRIGHT", 0, -54)

    local labels = {current="Matches local target",outdated="Older than local target",ahead="Newer than local target",different="Different version",
        no_target="No target set",unknown="Unknown",missing="Missing",disabled="Disabled",not_loaded="Enabled, not loaded",offline="Offline"}
    local compact = {current="Matches target",outdated="Older",ahead="Newer",different="Different",no_target="No target",unknown="Unknown",
        missing="Missing",disabled="Disabled",not_loaded="Not loaded",offline="Offline"}
    local responseLabels = {unknown="No response",["local"]="Local",local_report="Local",offline="Offline",responding="Responding",partial="Partial response",complete="Reported"}
    local shortNames = {arsenal="Arsenal",northernsky="Northern Sky",rclootcouncil="RCLootCouncil",simulationcraft="Simulationcraft",wowutils="WowUtils",autopotion="AutoPotion",bigwigs="BigWigs"}
    local function Age(stamp)
        return type(stamp)=="number" and tostring(math.max(0, math.floor((GetTime() or 0)-stamp))) .. "s ago" or "Unknown"
    end
    local function LocalState(addon, target)
        local comparison = RA.Readiness:CompareVersion(addon.version, target)
        if addon.installed==false then return "missing",comparison end
        if addon.installed==nil then return "unknown",comparison end
        if addon.enabled==false then return "disabled",comparison end
        if addon.loaded==false then return "not_loaded",comparison end
        if addon.enabled==nil or addon.loaded==nil then return "unknown",comparison end
        return comparison,comparison
    end
    local function Tooltip(owner, lines)
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetText(lines[1], 1, 1, 1)
        for i=2,#lines do GameTooltip:AddLine(lines[i],0.76,0.80,0.86,true) end
        GameTooltip:Show()
    end
    Text(addons, "PLAYER / RESPONSE", 9, 10, -116, 166, C.muted)
    for i, entry in ipairs(RA.AddonCatalog.Entries) do
        local id = entry.id
        local header = Button(addons, shortNames[id] or entry.name, 102, 38, function()
            targetBox:ClearFocus()
            selectedAddon, lastTargetID = id, nil
            showDetails(true)
            refreshers.ADDONS()
        end)
        Point(header, "TOPLEFT", addons, "TOPLEFT", 180+(i-1)*105, -103)
        RA:ApplyFont(header.label, 9.2, "BOLD", false)
        header.label:SetWordWrap(true)
        header:HookScript("OnEnter",function(self)
            Tooltip(self,{Literal(entry.name) .. " · " .. Literal(entry.priority),Literal(entry.description),"Select this column to edit its local target or open setup/download."})
        end)
        header:HookScript("OnLeave",function() GameTooltip:Hide() end)
        selectors[id]=header
    end
    matrixScroll=CreateFrame("ScrollFrame",nil,addons,"UIPanelScrollFrameTemplate")
    Size(matrixScroll,924,282);Point(matrixScroll,"TOPLEFT",addons,"TOPLEFT",0,-149)
    matrixChild=CreateFrame("Frame",nil,matrixScroll)
    Width(matrixChild,915);T.SetHeight(matrixChild,282);matrixScroll:SetScrollChild(matrixChild)
    local empty=Text(matrixChild,"Roster unavailable. Local addon details remain below.",10,10,-12,880,C.muted)

    local details=Card(addons,"LOCAL SETUP & APPROVED TARGET","Select any addon column above. Targets compare installed versions; they do not check the web for newest releases.")
    Size(details,950,204);Point(details,"TOPLEFT",addons,"TOPLEFT",0,-450)
    local collapsed=Text(addons,"Addon details: select a column for its local setup and approved target.",10,0,-461,720,C.muted)
    local reveal=Button(addons,"SHOW DETAILS",180,30,function() showDetails(true) end)
    Point(reveal,"TOPRIGHT",addons,"TOPRIGHT",0,-450)
    local hide=Button(details,"HIDE DETAILS",128,28,function() showDetails(false) end)
    Point(hide,"TOPRIGHT",details,"TOPRIGHT",-18,-10)
    showDetails=function(value) details:SetShown(value);collapsed:SetShown(not value);reveal:SetShown(not value) end
    showDetails(true)
    local detailTitle=Text(details,"",12,18,-62,520,C.text)
    local description=Text(details,"",9.3,18,-84,520)
    local localMeta=Text(details,"",9.2,18,-110,520)
    Text(details,"TARGET VERSION (LOCAL)",9,560,-62,370,C.magenta)
    targetBox=CreateFrame("EditBox",nil,details,"BackdropTemplate")
    Size(targetBox,184,30);Point(targetBox,"TOPLEFT",details,"TOPLEFT",560,-80)
    kit.Backdrop(targetBox,C.input,C.line,8,false)
    RA:ApplyFont(targetBox,11,"REGULAR",false)
    targetBox:SetTextInsets(10,10,0,0);targetBox:SetAutoFocus(false);targetBox:SetMaxLetters(64)
    local targetHint=Text(details,"",8.3,560,-113,372,C.muted)
    targetHint:SetWordWrap(false)
    targetBox:HookScript("OnEnter",function(self)
        local settings=RA.Readiness:GetTargets()
        Tooltip(self,{"Exact local target — " .. Literal(RA.AddonCatalog:GetEntry(selectedAddon).name),
            "Target set " .. tostring(settings.revision or 0) .. " · " .. (settings.origin~="" and Literal(settings.origin) or "Local only"),
            "Saving compares this exact approved string. Download links do not check the web for newest releases."})
    end)
    targetBox:HookScript("OnLeave",function() GameTooltip:Hide() end)
    targetBox:SetScript("OnTextChanged",function(box,userInput)
        if userInput then targetDrafts[selectedAddon]=box:GetText() or "" end
    end)
    targetBox:SetScript("OnEscapePressed",function(box)
        targetDrafts[selectedAddon]=nil;box:ClearFocus();lastTargetID=nil;refreshers.ADDONS()
    end)
    local function SaveTarget()
        local id=selectedAddon
        local ok,reason=RA.Readiness:SetTarget(id,targetBox:GetText() or "")
        if ok then targetDrafts[id]=nil end
        targetBox:ClearFocus();lastTargetID=nil;Result(ok,reason);refreshers.ADDONS()
    end
    targetBox:SetScript("OnEnterPressed",SaveTarget)
    local save=Button(details,"SAVE",92,30,SaveTarget)
    Point(save,"TOPLEFT",details,"TOPLEFT",754,-80)
    local clear=Button(details,"CLEAR",78,30,function()
        local id=selectedAddon
        local ok,reason=RA.Readiness:SetTarget(id,nil)
        if ok then targetDrafts[id]=nil end
        targetBox:ClearFocus();lastTargetID=nil;Result(ok,reason);refreshers.ADDONS()
    end)
    Point(clear,"TOPLEFT",details,"TOPLEFT",854,-80)
    local download=Button(details,"DOWNLOAD LINK",180,30,function() CopyLink(RA.AddonCatalog:GetEntry(selectedAddon)) end)
    Point(download,"TOPLEFT",details,"TOPLEFT",560,-130)
    local setup=Button(details,"SETUP",180,30,function()
        if selectedAddon=="northernsky" then RA:OpenConfig("NORTHERNSKY")
        elseif selectedAddon=="arsenal" then RA:OpenConfig("SETTINGS") end
    end)
    Point(setup,"TOPLEFT",details,"TOPLEFT",752,-130)
    local capture=Button(details,"USE MY ENABLED ADDON VERSIONS",292,30,function()
        local ok,count=RA.Readiness:UseLocalTargets()
        Result(ok,ok and (tostring(count) .. " targets updated from this character.") or count)
        refreshers.ADDONS()
    end)
    Point(capture,"TOPLEFT",details,"TOPLEFT",18,-162)
    feedback=Text(details,"No response means unknown. Only a received report can establish a missing addon.",9.1,324,-165,606,C.muted)

    local function UpdateCell(cell,member,addon,snapshot,localReport)
        local isLocal=member.isPlayer==true
        local received=isLocal or addon.receivedAt~=nil
        local state,comparison=addon.state,addon.versionState
        if isLocal then state,comparison=LocalState(addon,snapshot.targets[addon.id]) end
        if member.status=="offline" then state="offline"
        elseif member.status=="unknown" then state="no_response"
        elseif not received then state="unreported" end
        local pendingReload=received and addon.installed==true and addon.enabled==false and addon.loaded==true
        local version=(state=="offline" or state=="no_response" or state=="unreported") and "Unknown" or Literal(addon.version)
        local caption=state=="no_response" and "No response" or (state=="unreported" and "Not reported" or compact[state] or "Unknown")
        if pendingReload and state=="disabled" then caption="Reload pending" end
        SetText(cell.version,version);SetText(cell.state,caption)
        local color=C.textSoft
        if state=="offline" or state=="no_response" or state=="unreported" or state=="unknown" or (snapshot.stale and not isLocal) then color=C.muted
        elseif state=="missing" or state=="disabled" or state=="not_loaded" or comparison=="outdated" or comparison=="different" then color=C.orange
        elseif state=="current" then color=C.text end
        cell.state:SetTextColor(unpack(color))
        cell.tooltip=function()
            local lines={Literal(RA.AddonCatalog:GetEntry(addon.id).name) .. " — " .. Literal(member.name),
                "Response: " .. (responseLabels[member.status] or "Unknown"),"Version: " .. version,
                "Local target: " .. (snapshot.targets[addon.id] and Literal(snapshot.targets[addon.id]) or "No target set")}
            lines[#lines+1]="Status: " .. (state=="no_response" and "Unknown — no response" or (state=="unreported" and "Unknown — not reported" or labels[state] or "Unknown"))
            if received and state~="offline" and state~="no_response" then
                lines[#lines+1]="Comparison: " .. (labels[comparison] or "Unknown")
                lines[#lines+1]="Installed " .. Tri(addon.installed) .. " · Enabled " .. Tri(addon.enabled) .. " · Loaded " .. Tri(addon.loaded)
                if pendingReload then lines[#lines+1]="Disabled for the next reload; this code is still loaded now." end
                if addon.id=="arsenal" then lines[#lines+1]="Build " .. Literal(addon.build) .. " · Protocol " .. tostring(addon.protocol or "Unknown") end
                lines[#lines+1]=(isLocal and "Local metadata refreshed " .. Age(localReport.refreshedAt) or "Report received " .. Age(addon.receivedAt))
            elseif state=="offline" then lines[#lines+1]="Offline is distinct from a missing addon."
            else lines[#lines+1]="This addon has not been reported. Its installation and version are unknown." end
            if not isLocal then
                lines[#lines+1]="Group query: " .. (snapshot.queriedAt and Age(snapshot.queriedAt) or "Not queried")
                if snapshot.stale then lines[#lines+1]="STALE: query again for current results." end
            end
            return lines
        end
    end
    local matrixSnapshot, matrixLocalReport
    local function RefreshMatrixStatus(snapshot, localReport)
        if not snapshot or not localReport then return end
        local wasStale = snapshot.stale
        snapshot.stale = snapshot.queriedAt ~= nil and (GetTime() or 0) - snapshot.queriedAt > RA.Readiness.SNAPSHOT_LIFETIME
        snapshot.restriction = RA.Readiness:GetRestrictionReason()
        -- Keep native UI eligibility fresh. QueryGroup and each queued send
        -- independently retain their existing current-roster authorization.
        local eligible, reason = RA.Readiness:GetQueryEligibility()
        query:SetEnabled(eligible);query:SetAlpha(eligible and 1 or 0.55)
        local status=snapshot.restriction or snapshot.reason or (snapshot.status=="checking" and "Checking group addon versions…" or "No response means unknown.")
        SetText(matrixMeta,(snapshot.stale and "STALE · " or "") .. (snapshot.queriedAt and ("Group query " .. Age(snapshot.queriedAt)) or "No group query")
            .. " · Local " .. Age(localReport.refreshedAt) .. "\n" .. (not eligible and reason or status or ""))
        local combat=(InCombatLockdown and InCombatLockdown()) or (IsEncounterInProgress and IsEncounterInProgress())
        for _,button in ipairs({save,clear,capture}) do button:SetEnabled(not combat);button:SetAlpha(combat and 0.55 or 1) end
        return wasStale ~= snapshot.stale
    end
    refreshers.ADDONS=function()
        local snapshot=RA.Readiness:GetSnapshot()
        local localReport=RA.AddonCatalog:GetLocalReport()
        matrixSnapshot,matrixLocalReport=snapshot,localReport
        snapshot.targets=snapshot.targets or {}
        local settings=RA.Readiness:GetTargets()
        local target=RA.AddonCatalog:NormalizeVersion(settings.targets[selectedAddon]) or ""
        if lastTargetID~=selectedAddon or (not targetBox:HasFocus() and lastTargetValue~=target) then
            targetBox:SetText(targetDrafts[selectedAddon]~=nil and targetDrafts[selectedAddon] or target)
            lastTargetID,lastTargetValue=selectedAddon,target
        end
        local entry=RA.AddonCatalog:GetEntry(selectedAddon)
        local localAddon=localReport.byID[selectedAddon] or {}
        SetText(detailTitle,entry.name .. " · " .. entry.priority)
        SetText(description,entry.description)
        SetText(localMeta,"Installed " .. Tri(localAddon.installed) .. " · Enabled " .. Tri(localAddon.enabled) .. " · Loaded " .. Tri(localAddon.loaded)
            .. "\nVersion " .. Literal(localAddon.version) .. (selectedAddon=="arsenal" and (" · Build " .. Literal(localAddon.build) .. " · Protocol " .. tostring(localAddon.protocol or "Unknown")) or ""))
        SetText(targetHint,(targetDrafts[selectedAddon]~=nil and "Draft · " or "") .. "Target set " .. tostring(settings.revision or 0) .. " · " .. (settings.origin~="" and Literal(settings.origin) or "Local only"))
        for id,button in pairs(selectors) do button:SetSelected(id==selectedAddon) end
        setup:SetShown(selectedAddon=="northernsky" or selectedAddon=="arsenal")
        SetText(setup.label,selectedAddon=="arsenal" and "PROFILES" or "SETUP")
        RefreshMatrixStatus(snapshot,localReport)
        local rows={}
        for _,member in ipairs(snapshot.rows or {}) do if member.isPlayer then rows[#rows+1]=member end end
        for _,member in ipairs(snapshot.rows or {}) do if not member.isPlayer then rows[#rows+1]=member end end
        empty:SetShown(#rows==0)
        for i,member in ipairs(rows) do
            local row=matrixRows[i]
            if not row then
                row=CreateFrame("Frame",nil,matrixChild)
                Size(row,915,32);Point(row,"TOPLEFT",matrixChild,"TOPLEFT",0,-(i-1)*34)
                kit.Backdrop(row,C.surface,C.line,5,false)
                row.name=Text(row,"",10.1,10,-3,164,C.text);row.name:SetWordWrap(false)
                row.response=Text(row,"",8.6,10,-18,164,C.muted);row.response:SetWordWrap(false)
                row:EnableMouse(true)
                row:SetScript("OnEnter",function(self) Tooltip(self,self.tooltip()) end)
                row:SetScript("OnLeave",function() GameTooltip:Hide() end)
                row.cells={}
                for j,definition in ipairs(RA.AddonCatalog.Entries) do
                    local cell=CreateFrame("Frame",nil,row)
                    Size(cell,105,32);Point(cell,"TOPLEFT",row,"TOPLEFT",180+(j-1)*105,0)
                    cell.version=Text(cell,"",9.4,4,-3,97,C.text);cell.version:SetWordWrap(false)
                    cell.state=Text(cell,"",8.4,4,-18,97,C.textSoft);cell.state:SetWordWrap(false)
                    cell:EnableMouse(true)
                    cell:SetScript("OnEnter",function(self) Tooltip(self,self.tooltip()) end)
                    cell:SetScript("OnLeave",function() GameTooltip:Hide() end)
                    row.cells[definition.id]=cell
                end
                matrixRows[i]=row
            end
            SetText(row.name,Literal(member.name));SetText(row.response,(responseLabels[member.status] or "Unknown")
                .. ((member.status=="partial" or member.status=="responding") and (" " .. tostring(member.receivedCount or 0) .. "/7") or ""))
            row.tooltip=function() return {Literal(member.name),responseLabels[member.status] or "Unknown",member.isPlayer and ("Local metadata refreshed " .. Age(localReport.refreshedAt))
                or (snapshot.stale and "STALE group snapshot" or (snapshot.queriedAt and ("Group query " .. Age(snapshot.queriedAt)) or "Not queried"))} end
            for _,definition in ipairs(RA.AddonCatalog.Entries) do
                local addon=(member.isPlayer and localReport.byID[definition.id]) or (member.addons and member.addons[definition.id]) or {id=definition.id}
                UpdateCell(row.cells[definition.id],member,addon,snapshot,localReport)
            end
            row:Show()
        end
        for i=#rows+1,#matrixRows do
            local row=matrixRows[i]
            row:Hide();row.tooltip=nil
            -- Pooled hidden rows must not retain older whole snapshots via
            -- their hover closures as members leave one at a time.
            for _,cell in pairs(row.cells) do cell.tooltip=nil end
        end
        T.SetHeight(matrixChild,math.max(282,#rows*34))
    end
    refreshers.RAIDTOOLS=refreshers.ADDONS -- compatibility for callers during UI integration
    local matrixTicker
    addons:HookScript("OnShow",function()
        if not matrixTicker and C_Timer and C_Timer.NewTicker then
            matrixTicker=C_Timer.NewTicker(1,function()
                if addons:IsVisible() and RefreshMatrixStatus(matrixSnapshot,matrixLocalReport) then
                    -- Staleness changes cell colors once; ages alone do not
                    -- require new snapshots, rows or hover-tooltip tables.
                    refreshers.ADDONS()
                end
            end)
        end
    end)
    local function StopMatrixTicker()
        if matrixTicker then matrixTicker:Cancel();matrixTicker=nil end
    end
    addons:HookScript("OnHide",StopMatrixTicker)
    RA.ConfigFrame:HookScript("OnHide",StopMatrixTicker)
    RA:RegisterEvent("ADDON_LOADED",function() if addons:IsVisible() then refreshers.ADDONS() end end)

    local tools = panes.MYTOOLS
    kit.Heading(tools, "Personal tools", "Optional resurrection and consumable reminders. Available Cooldowns, Quick Bar, and World Markers have their own settings.")
    local function Tool(label, description, getter, setter, y)
        local toggle = kit.Toggle(tools, label, description, getter, function(value)
            local ok, reason = setter(value)
            if ok == false and reason then RA:Print(reason) end
        end)
        Point(toggle, "TOPLEFT", tools, "TOPLEFT", 0, y); Width(toggle, 950)
    end
    Tool("Accept normal resurrection", "Accepts ordinary resurrection offers. Battle resurrection stays manual while encounter or group combat is active.",
        function() return RA:GetDB().personalTools.autoRes == true end, function(v) return RA.PersonalTools:SetOption("autoRes", v) end, -68)
    Tool("Enable Healthstone / healing potion reminder", "Prefers a ready Healthstone, then a ready healing potion. Use your own item/macro key.",
        function() return RA:GetDB().personalTools.consumableReminder == true end, function(v) return RA.PersonalTools:SetOption("consumableReminder", v) end, -134)
    local threshold = kit.Slider(tools, "HEALTH THRESHOLD — AT OR BELOW", 1, 99, 1,
        function() return RA:GetDB().personalTools.healthThreshold end,
        function(v) RA.PersonalTools:SetOption("healthThreshold", v) end,
        function(v) return string.format("%d%%", v) end)
    Width(threshold, 440); Point(threshold, "TOPLEFT", tools, "TOPLEFT", 16, -205)
    local combatMode = kit.Segmented(tools, "SHOW REMINDER", {
        {label="BOTH", value="BOTH"}, {label="IN COMBAT", value="IN_COMBAT"}, {label="OUT OF COMBAT", value="OUT_OF_COMBAT"},
    }, function() return RA.PersonalTools:GetState().reminderCombat end,
        function(v) RA.PersonalTools:SetOption("reminderCombat", v) end)
    Width(combatMode, 440); Point(combatMode, "TOPLEFT", tools, "TOPLEFT", 494, -205); combatMode:Layout(440)
    local iconSize = kit.Slider(tools, "ICON SIZE", 24, 128, 1,
        function() return RA.PersonalTools:GetState().reminderIconSize end,
        function(v) RA.PersonalTools:SetOption("reminderIconSize", v) end,
        function(v) return tostring(v) .. " px" end)
    Width(iconSize, 280); Point(iconSize, "TOPLEFT", tools, "TOPLEFT", 16, -269)
    local textSize = kit.Slider(tools, "TEXT SIZE", 8, 32, 1,
        function() return RA.PersonalTools:GetState().reminderTextSize end,
        function(v) RA.PersonalTools:SetOption("reminderTextSize", v) end,
        function(v) return tostring(v) .. " px" end)
    Width(textSize, 280); Point(textSize, "TOPLEFT", tools, "TOPLEFT", 335, -269)
    local emptySize = kit.Slider(tools, "EMPTY WARNING SIZE", 16, 96, 1,
        function() return RA.PersonalTools:GetState().reminderEmptyTextSize end,
        function(v) RA.PersonalTools:SetOption("reminderEmptyTextSize", v) end,
        function(v) return tostring(v) .. " px" end)
    Width(emptySize, 280); Point(emptySize, "TOPLEFT", tools, "TOPLEFT", 654, -269)
    local details = CreateFrame("Frame", nil, tools)
    Size(details, 918, 209); Point(details, "TOPLEFT", tools, "TOPLEFT", 16, -377); details:Hide()
    for index, entry in ipairs({ {"HEALTHSTONE TEXT", "reminderStoneText"}, {"HEALING POTION TEXT", "reminderPotionText"} }) do
        local key = entry[2]
        local field = kit.EditBox(details, entry[1], "Blank hides text; 60 characters.",
            function() return RA.PersonalTools:GetState()[key] end,
            function(v) RA.PersonalTools:SetOption(key, v) end)
        if field.SetHeight then field:SetHeight(54) end
        Width(field, 440); Point(field, "TOPLEFT", details, "TOPLEFT", (index - 1) * 478, 0)
        if field.box then field.box:SetMaxLetters(60) end
    end
    local sampleKind = "stone"
    local sampleChoice = kit.Segmented(details, "PREVIEW SAMPLE", {
        {label="HEALTHSTONE", value="stone"}, {label="HEALING POTION", value="potion"}, {label="EMPTY WARNING", value="empty"},
    }, function() return sampleKind end, function(v) sampleKind = v end)
    Width(sampleChoice, 440); Point(sampleChoice, "TOPLEFT", details, "TOPLEFT", 0, -64); sampleChoice:Layout(440)
    local showCooling = kit.Toggle(details, "Show while on cooldown", "Also allows carried items with unusable or unknown readiness.",
        function() return RA.PersonalTools:GetState().reminderShowOnCooldown end,
        function(value) RA.PersonalTools:SetOption("reminderShowOnCooldown", value) end)
    Width(showCooling, 440); Point(showCooling, "TOPLEFT", details, "TOPLEFT", 0, -128)
    Text(details, "Empty bags: large OUT OF POTIONS! text, with the icon hidden.", 9, 0, -184, 440)
    local soundToggle = kit.Toggle(details, "Low-health sound", "Native warning ~35%",
        function() return RA.PersonalTools:GetState().reminderSound end,
        function(value) RA.PersonalTools:SetOption("reminderSound", value) end)
    Width(soundToggle, 180); Point(soundToggle, "TOPLEFT", details, "TOPLEFT", 478, -64)
    soundToggle:SetHeight(42)
    local channel = kit.Segmented(details, "CHANNEL", {{label="SFX",value="SFX"},{label="MASTER",value="Master"}},
        function() return RA.PersonalTools:GetState().reminderSoundChannel end,
        function(value) RA.PersonalTools:SetOption("reminderSoundChannel", value) end)
    Width(channel,112); Point(channel,"TOPLEFT",details,"TOPLEFT",666,-64); channel:Layout(112)
    channel:SetHeight(42)
    local soundStatus = Text(details, "", 9, 478, -184, 440)
    local soundPreview = Button(details, "PREVIEW SOUND", 132, 30, function()
        local _, reason = RA.PersonalTools:PreviewReminderSound()
        SetText(soundStatus, reason)
    end)
    Point(soundPreview, "TOPLEFT", details, "TOPLEFT", 786, -76)
    local mutedPermission = Button(details, "Play when game effects are muted", 440, 16, function()
        RA.PersonalTools:SetOption("reminderSoundWhenEffectsMuted", not RA.PersonalTools:GetState().reminderSoundWhenEffectsMuted)
    end)
    Point(mutedPermission, "TOPLEFT", details, "TOPLEFT", 478, -110)
    mutedPermission.label:ClearAllPoints(); Point(mutedPermission.label, "LEFT", mutedPermission, "LEFT", 23, 0)
    RA:ApplyFont(mutedPermission.label, 9, "REGULAR", false)
    local mutedCheck = mutedPermission:CreateTexture(nil, "OVERLAY")
    T:RegisterAssetTexture(mutedCheck, T.Assets.Checkmark)
    Size(mutedCheck, 12, 12); Point(mutedCheck, "LEFT", mutedPermission, "LEFT", 5, 0)
    Text(details, "Requires Master. Does not override global sound or master volume.", 8.5, 478, -198, 440)
    Text(details, "SOUND", 10, 478, -129, 440, C.text)
    local soundChoice
    local soundRows = {}
    local function RefreshSoundChoice()
        local entry = RA.ReminderSounds and RA.ReminderSounds:Get(RA.PersonalTools:GetState().reminderSoundChoice)
        SetText(soundChoice.label, (entry and entry.label or "Built-in alert") .. "  v")
    end
    local function ChooseSound()
        if not soundOverlay then
            soundOverlay = CreateFrame("Button", nil, RA.ConfigFrame)
            soundOverlay:SetAllPoints(RA.ConfigFrame); soundOverlay:SetFrameLevel(RA.ConfigFrame:GetFrameLevel() + 150)
            soundOverlay:EnableMouse(true); soundOverlay:SetScript("OnClick", function() soundOverlay:Hide() end)
            local menu = CreateFrame("Frame", nil, soundOverlay, "BackdropTemplate")
            local options = RA.ReminderSounds:GetOptions()
            Size(menu, 440, #options * 34 + 12); Point(menu, "BOTTOMLEFT", soundChoice, "TOPLEFT", 0, 4)
            menu:EnableMouse(true); kit.Backdrop(menu, C.surface, C.lineStrong, 10, true)
            for index, option in ipairs(options) do
                local value = option.value
                local row = Button(menu, option.label, 428, 30, function()
                    RA.PersonalTools:SetOption("reminderSoundChoice", value)
                    soundOverlay:Hide(); RefreshSoundChoice()
                end)
                Point(row, "TOPLEFT", menu, "TOPLEFT", 6, -6 - (index - 1) * 34)
                soundRows[index] = {frame=row,value=value,label=option.label}
            end
        end
        local selected = RA.PersonalTools:GetState().reminderSoundChoice
        for _, row in ipairs(soundRows) do SetText(row.frame.label, (row.value == selected and "* " or "") .. row.label) end
        soundOverlay:Show()
    end
    soundChoice = Button(details, "Built-in alert  v", 440, 34, ChooseSound)
    Point(soundChoice, "TOPLEFT", details, "TOPLEFT", 478, -148)
    local preview = Button(tools, "PREVIEW", 100, 34, function() RA.PersonalTools:PreviewReminder(sampleKind) end)
    local move = Button(tools, "MOVE", 100, 34, function() RA.PersonalTools:MoveReminder(sampleKind) end)
    Point(move, "LEFT", preview, "RIGHT", 8, 0)
    local stop = Button(tools, "STOP PREVIEW", 132, 34, function() RA.PersonalTools:StopReminderPreview() end)
    Point(stop, "LEFT", move, "RIGHT", 8, 0)
    local resetReminder = Button(tools, "RESET POSITION", 154, 34, function() RA.PersonalTools:ResetReminderPosition() end)
    Point(resetReminder, "LEFT", stop, "RIGHT", 8, 0)
    local helper = Text(tools, "Automatic ~35% sound needs a ready stone/potion. Preview sound is independent. Routes obey game mute.", 9.5, 16, -435, 914)
    local personalStatus = Text(tools, "", 10, 16, -479, 914)
    personalStatus:SetSpacing(4)
    local supplyLabel = Text(tools, "RAID SUPPLIES", 9, 600, -369, 334)
    local supplyAction, supplyView, supplySummary, supplyState, supplyRows, supplyAgain
    local function SupplyValue(value)
        return value == true and "Carried" or value == false and "None carried" or "Unknown"
    end
    local function RenderSupply()
        local state = RA.SupplyCheck:GetSnapshot()
        if supplyAction then
            supplyAction:SetEnabled(state.status ~= "checking")
            SetText(supplyAction.label, state.status == "checking" and "CHECKING…" or "CHECK RAID SUPPLIES")
        end
        if not supplyOverlay or not supplyOverlay:IsShown() then return end
        local summaries = {}
        for _, kind in ipairs({"stone", "potion"}) do
            local yes, no, unknown, offline = 0, 0, 0, 0
            for _, row in ipairs(state.rows) do
                if row.status == "offline" then offline = offline + 1
                elseif row[kind] == true then yes = yes + 1
                elseif row[kind] == false then no = no + 1 else unknown = unknown + 1 end
            end
            summaries[#summaries+1] = (kind == "stone" and "Healthstone" or "Healing potion") .. " — Players: " .. yes .. " carried · " .. no .. " none · " .. unknown .. " unknown · " .. offline .. " offline"
        end
        SetText(supplySummary, table.concat(summaries, "\n"))
        local age = state.queriedAt and math.max(0, math.floor(GetTime() - state.queriedAt))
        SetText(supplyState, (state.status == "checking" and "Checking…" or state.reason or "No manual check yet.") ..
            (age and (" Last manual check " .. age .. "s ago; bags may have changed.") or ""))
        supplyAgain:SetEnabled(state.status ~= "checking")
        for i, view in ipairs(supplyRows) do
            local row = state.rows[i]
            view.frame:SetShown(row ~= nil)
            if row then
                SetText(view.name, Literal(row.name))
                SetText(view.stone, row.status == "offline" and "Offline" or SupplyValue(row.stone))
                SetText(view.potion, row.status == "offline" and "Offline" or SupplyValue(row.potion))
                SetText(view.state, row.status == "no_reply" and "No reply" or row.status == "offline" and "Offline" or
                    ("Reported " .. math.max(0, math.floor(GetTime() - row.respondedAt)) .. "s ago"))
            end
        end
    end
    local function ShowSupply()
        if not supplyOverlay then
            supplyOverlay = CreateFrame("Frame", nil, RA.ConfigFrame, "BackdropTemplate")
            supplyOverlay:SetAllPoints(RA.ConfigFrame); supplyOverlay:SetFrameLevel(RA.ConfigFrame:GetFrameLevel() + 100)
            supplyOverlay:EnableMouse(true); kit.Backdrop(supplyOverlay, {0,0,0,0.68}, C.line, 14, false)
            local dialog = CreateFrame("Frame", nil, supplyOverlay, "BackdropTemplate")
            Size(dialog, 920, 550); Point(dialog, "CENTER", supplyOverlay, "CENTER", 0, 0)
            dialog:EnableMouse(true); kit.Backdrop(dialog, C.surface, C.lineStrong, 14, true)
            Text(dialog, "Carried healing supplies", 18, 20, -18, 880, C.text)
            Text(dialog, "One manual request. Players with Arsenal report their own bags. No talent inspection or background polling. Carried supplies don't confirm cooldown readiness.", 10, 20, -50, 880)
            supplySummary = Text(dialog, "", 10, 20, -88, 880); supplySummary:SetSpacing(4)
            supplyState = Text(dialog, "", 10, 20, -126, 880)
            for _, field in ipairs({{"PLAYER", 0}, {"HEALTHSTONE", 320}, {"HEALING POTION", 500}, {"REPORT", 680}}) do
                Text(dialog, field[1], 10, 20 + field[2], -164, 170, C.text)
            end
            local scroll = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate")
            Size(scroll, 854, 270); Point(scroll, "TOPLEFT", dialog, "TOPLEFT", 20, -186)
            local child = CreateFrame("Frame", nil, scroll); Size(child, 854, 40 * 28); scroll:SetScrollChild(child)
            supplyRows = {}
            for i = 1, 40 do
                local frame = CreateFrame("Frame", nil, child); Size(frame, 854, 28); Point(frame, "TOPLEFT", child, "TOPLEFT", 0, -(i-1)*28)
                supplyRows[i] = { frame = frame, name = Text(frame, "", 10, 0, -5, 306), stone = Text(frame, "", 10, 320, -5, 170),
                    potion = Text(frame, "", 10, 500, -5, 170), state = Text(frame, "", 9, 680, -5, 170) }
            end
            supplyAgain = Button(dialog, "CHECK AGAIN", 170, 34, function()
                local ok, reason = RA.SupplyCheck:Query()
                RenderSupply(); if not ok then SetText(supplyState, reason) end
            end)
            Point(supplyAgain, "BOTTOMLEFT", dialog, "BOTTOMLEFT", 20, 20)
            local close = Button(dialog, "CLOSE", 120, 34, function() supplyOverlay:Hide() end)
            Point(close, "BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -20, 20)
        end
        supplyOverlay:Show(); RenderSupply()
    end
    supplyAction = Button(tools, "CHECK RAID SUPPLIES", 180, 34, function()
        local ok, reason = RA.SupplyCheck:Query()
        ShowSupply(); if not ok then SetText(supplyState, reason) end
    end)
    supplyView = Button(tools, "VIEW RESULTS", 146, 34, ShowSupply)
    Point(supplyView, "LEFT", supplyAction, "RIGHT", 8, 0)
    local glowDetails = CreateFrame("Frame", nil, tools)
    Size(glowDetails,918,184); Point(glowDetails,"TOPLEFT",tools,"TOPLEFT",16,-377); glowDetails:Hide()
    local PersonalLayout, disclosure, glowDisclosure, styleOverlay, pickerSession
    local function CloseGlowPicker()
        local session=pickerSession; pickerSession=nil
        if session and ColorPickerFrame and ColorPickerFrame.swatchFunc==session.swatch then ColorPickerFrame:Hide() end
    end
    local styleLabels = {STEADY="Steady border",PIXEL="Pixel Glow",BUTTON="Action Button Glow",AUTOCAST="Autocast Shine"}
    local function GlowState() return RA:NormalizeReminderGlow(RA:GetDB().personalTools.reminderGlow) end
    local function GlowEdit(key,value)
        RA.PersonalTools:SetGlowOption(key,value)
        kit.Refresh()
        if PersonalLayout then PersonalLayout() end
    end
    Text(glowDetails,"STYLE",10,0,0,440,C.text)
    local styleChoice
    styleChoice = Button(glowDetails,"Steady border  v",440,30,function()
        if not styleOverlay then
            styleOverlay=CreateFrame("Button",nil,RA.ConfigFrame)
            styleOverlay:SetAllPoints(RA.ConfigFrame); styleOverlay:SetFrameLevel(RA.ConfigFrame:GetFrameLevel()+150)
            styleOverlay:EnableMouse(true); styleOverlay:SetScript("OnClick",function() styleOverlay:Hide() end)
            local menu=CreateFrame("Frame",nil,styleOverlay,"BackdropTemplate")
            Size(menu,440,148); Point(menu,"TOPLEFT",styleChoice,"BOTTOMLEFT",0,-4)
            menu:EnableMouse(true); kit.Backdrop(menu,C.surface,C.lineStrong,10,true)
            for index,value in ipairs({"STEADY","PIXEL","BUTTON","AUTOCAST"}) do
                local key=value
                local row=Button(menu,styleLabels[key],428,30,function() styleOverlay:Hide(); GlowEdit("style",key) end)
                Point(row,"TOPLEFT",menu,"TOPLEFT",6,-6-(index-1)*34)
            end
        end
        styleOverlay:Show()
    end)
    Point(styleChoice,"TOPLEFT",glowDetails,"TOPLEFT",0,-17)
    Text(glowDetails,"COLOR",10,478,0,206,C.text)
    local colorChoice=Button(glowDetails,"Color",206,30,function()
        local picker=ColorPickerFrame
        if not picker or not picker.SetupColorPickerAndShow then RA:Print("Color picker unavailable."); return end
        CloseGlowPicker()
        local db=RA:GetDB(); local personal=db.personalTools
        local original=GlowState().color
        local session={}; pickerSession=session
        local swatch
        local function Current() return pickerSession==session and RA:GetDB()==db and db.personalTools==personal and picker.swatchFunc==swatch end
        swatch=function()
            if Current() then local r,g,b=picker:GetColorRGB(); GlowEdit("color",{r,g,b}) end
        end
        session.swatch=swatch
        picker:SetupColorPickerAndShow({r=original[1],g=original[2],b=original[3],hasOpacity=false,swatchFunc=swatch,
            cancelFunc=function() if Current() then GlowEdit("color",original); pickerSession=nil end end})
    end)
    Point(colorChoice,"TOPLEFT",glowDetails,"TOPLEFT",478,-17)
    local swatch=colorChoice:CreateTexture(nil,"OVERLAY"); Size(swatch,18,18); Point(swatch,"LEFT",colorChoice,"LEFT",9,0)
    local resetGlow=Button(glowDetails,"RESET GLOW SETTINGS",222,30,function()
        CloseGlowPicker(); RA.PersonalTools:ResetGlowSettings(); kit.Refresh(); PersonalLayout()
    end)
    Point(resetGlow,"TOPLEFT",glowDetails,"TOPLEFT",696,-17)
    local glowControls={}
    local function GlowSlider(key,label,minimum,maximum,step,x,y,formatter)
        local control=kit.Slider(glowDetails,label,minimum,maximum,step,function() return GlowState()[key] end,
            function(v) GlowEdit(key,v) end,formatter)
        Width(control,440); Point(control,"TOPLEFT",glowDetails,"TOPLEFT",x,y)
        glowControls[key]=control
    end
    local function Speed(value) return string.format("%.1f×",value) end
    local function Units(value) return tostring(value).." UI units" end
    GlowSlider("pixelLines","LINES",1,12,1,0,-64)
    GlowSlider("pixelSpeed","SPEED",0.5,2,0.1,478,-64,Speed)
    GlowSlider("pixelLength","LINE LENGTH",4,16,1,0,-128,Units)
    GlowSlider("pixelThickness","THICKNESS",1,4,1,478,-128,Units)
    GlowSlider("buttonSpeed","SPEED",0.5,2,0.1,0,-64,Speed)
    GlowSlider("autocastGroups","PARTICLE GROUPS · 4 SPARKS EACH",1,8,1,0,-64)
    GlowSlider("autocastSpeed","SPEED",0.5,2,0.1,478,-64,Speed)
    GlowSlider("autocastSize","SIZE",50,150,5,0,-128,function(v) return tostring(v).."%" end)
    local sparkHelp=Text(glowDetails,"Four spark sizes circulate at different rates.",9,478,-139,440)
    local function RefreshGlow()
        local state=GlowState()
        SetText(styleChoice.label,styleLabels[state.style].."  v")
        swatch:SetColorTexture(state.color[1],state.color[2],state.color[3],1)
        for key,control in pairs(glowControls) do
            local prefix=key:match("^(%l+)%u")
            control:SetShown((prefix=="pixel" and state.style=="PIXEL") or (prefix=="button" and state.style=="BUTTON") or (prefix=="autocast" and state.style=="AUTOCAST"))
        end
        sparkHelp:SetShown(state.style=="AUTOCAST")
        glowDetails:SetHeight(state.style=="STEADY" and 58 or state.style=="BUTTON" and 120 or 184)
    end
    PersonalLayout = function()
        if glowDetails:IsShown() then RefreshGlow() end
        local expanded = details:IsShown() or glowDetails:IsShown()
        supplyLabel:SetShown(not expanded)
        personalStatus:SetWordWrap(not expanded)
        if personalStatus.SetTextHeight then personalStatus:SetTextHeight(expanded and 9 or 10) end
        local y = details:IsShown() and -591 or glowDetails:IsShown() and -(377+glowDetails:GetHeight()+5) or -389
        preview:ClearAllPoints(); Point(preview, "TOPLEFT", tools, "TOPLEFT", 16, y)
        supplyAction:ClearAllPoints(); Point(supplyAction, "TOPLEFT", tools, "TOPLEFT", 600, y)
        supplyLabel:ClearAllPoints(); Point(supplyLabel, "TOPLEFT", tools, "TOPLEFT", 600, y + 20)
        helper:ClearAllPoints(); Point(helper, "TOPLEFT", tools, "TOPLEFT", 16, y - (expanded and 41 or 44))
        personalStatus:ClearAllPoints(); Point(personalStatus, "TOPLEFT", tools, "TOPLEFT", 16, y - (expanded and 56 or 79))
    end
    disclosure = Button(tools, "REMINDER TEXT & SOUND +", 200, 30, function(self)
        details:SetShown(not details:IsShown())
        CloseGlowPicker(); glowDetails:Hide(); SetText(glowDisclosure.label,"GLOW SETTINGS +")
        SetText(self.label, details:IsShown() and "HIDE REMINDER TEXT & SOUND" or "REMINDER TEXT & SOUND +")
        PersonalLayout()
        kit.Refresh()
    end)
    Point(disclosure, "TOPLEFT", tools, "TOPLEFT", 16, -333)
    glowDisclosure=Button(tools,"GLOW SETTINGS +",164,30,function(self)
        if glowDetails:IsShown() then CloseGlowPicker() end
        glowDetails:SetShown(not glowDetails:IsShown())
        details:Hide(); SetText(disclosure.label,"REMINDER TEXT & SOUND +")
        SetText(self.label,glowDetails:IsShown() and "HIDE GLOW SETTINGS" or "GLOW SETTINGS +")
        PersonalLayout(); kit.Refresh()
    end)
    Point(glowDisclosure,"TOPLEFT",tools,"TOPLEFT",232,-333)
    local iconGlow = kit.Toggle(tools, "Icon glow at 35% or lower", "Healthstone or potion, while the reminder is visible.",
        function() return RA.PersonalTools:GetState().reminderStoneGlow end,
        function(value) RA.PersonalTools:SetOption("reminderStoneGlow", value) end)
    Width(iconGlow, 522); iconGlow:SetHeight(38); Point(iconGlow, "TOPLEFT", tools, "TOPLEFT", 412, -329)
    PersonalLayout()
    RA:RegisterCallback("SUPPLIES_UPDATED", RenderSupply)
    RA:RegisterCallback("PROFILE_RESET",CloseGlowPicker)
    RA:RegisterCallback("PROFILE_IMPORTED",CloseGlowPicker)
    RA:RegisterCallback("PERSONAL_TOOLS_CHANGED",function(option) if option=="reminderGlowReset" then CloseGlowPicker() end end)
    tools:HookScript("OnHide", function() CloseGlowPicker(); if styleOverlay then styleOverlay:Hide() end; if supplyOverlay then supplyOverlay:Hide() end; if soundOverlay then soundOverlay:Hide() end end)
    refreshers.MYTOOLS = function()
        local state = RA.PersonalTools:GetState()
        PersonalLayout()
        SetText(soundStatus, RA.NativeWarningAudio and RA.NativeWarningAudio:GetStatusText() or "Native warning unavailable.")
        RefreshSoundChoice()
        mutedPermission:SetEnabled(state.reminderSoundChannel == "Master")
        mutedPermission:SetAlpha(state.reminderSoundChannel == "Master" and 1 or 0.45)
        mutedPermission:SetSelected(state.reminderSoundWhenEffectsMuted)
        mutedCheck:SetShown(state.reminderSoundWhenEffectsMuted)
        local combatLabel = ({BOTH="Both",IN_COMBAT="In combat",OUT_OF_COMBAT="Out of combat"})[state.reminderCombat] or "In combat"
        SetText(personalStatus, ((details:IsShown() or glowDetails:IsShown()) and ("Normal res: " .. (state.autoRes and "On" or "Off") .. " ; Reminder: ")
            or ("Resurrection: " .. RA.PersonalTools:GetStatusText("autoRes") .. "\nReminder: ")) ..
            (state.consumableReminder and ("Enabled · At/below " .. state.healthThreshold .. "% · " .. combatLabel .. " · ") or "") .. RA.PersonalTools:GetStatusText("consumableReminder"))
    end

    local settings = panes.SETTINGS
    kit.Heading(settings, "Profiles & Recovery", "Import or export portable preferences. Appearance and content controls are in Available Cooldowns; tool switches stay on their own pages.")
    local card = Card(settings, "LOCAL PROFILE", "Import and export appearance, content ordering, and callout templates.")
    Size(card, 950, 230); Point(card, "TOPLEFT", settings, "TOPLEFT", 0, -68)
    local import = Button(card, "IMPORT", 180, 36, function() RA:OpenProfileDialog("IMPORT") end)
    Point(import, "TOPLEFT", card, "TOPLEFT", 20, -78)
    local export = Button(card, "EXPORT", 180, 36, function() RA:OpenProfileDialog("EXPORT") end)
    Point(export, "LEFT", import, "RIGHT", 12, 0)
    Text(card, "Import preserves your tool switches, local addon targets, marker sequence, and positions.\nExport keeps portable preferences; full profile reset is in Advanced below.", 11, 20, -134, 900)
    local danger = Card(settings, "FULL PROFILE RESET", "This is not a HUD or puck position reset. Your native keybindings are not changed.")
    Size(danger, 950, 150); Point(danger, "TOPLEFT", settings, "TOPLEFT", 0, -355)
    danger:Hide()
    local advancedReset = Button(settings, "ADVANCED: FULL PROFILE RESET", 300, 34, function(self)
        danger:SetShown(not danger:IsShown())
        SetText(self.label, danger:IsShown() and "HIDE FULL RESET" or "ADVANCED: FULL PROFILE RESET")
    end)
    Point(advancedReset, "TOPLEFT", settings, "TOPLEFT", 0, -310)
    local function HideResetOptions() danger:Hide(); SetText(advancedReset.label, "ADVANCED: FULL PROFILE RESET") end
    settings:HookScript("OnHide", HideResetOptions)
    RA.ConfigFrame:HookScript("OnHide", HideResetOptions)
    local reset = Button(danger, "RESET PROFILE", 210, 34, function()
        if InCombatLockdown() then RA:Print("Reset is unavailable during combat."); return end
        if not resetOverlay then
            resetOverlay = CreateFrame("Frame", nil, RA.ConfigFrame, "BackdropTemplate")
            resetOverlay:SetAllPoints(RA.ConfigFrame)
            resetOverlay:SetFrameLevel(RA.ConfigFrame:GetFrameLevel() + 100)
            resetOverlay:EnableMouse(true)
            kit.Backdrop(resetOverlay, {0, 0, 0, 0.68}, C.line, 14, false)
            local modal = CreateFrame("Frame", nil, resetOverlay, "BackdropTemplate")
            Size(modal, 590, 210); Point(modal, "CENTER", resetOverlay, "CENTER", 0, 0)
            modal:EnableMouse(true); kit.Backdrop(modal, C.surface, C.lineStrong, 14, true)
            Text(modal, "Reset this local Arsenal profile?", 16, 20, -20, 550, C.text)
            Text(modal, "This restores quiet tool defaults and resets appearance, positions, content choices, callout templates, marker order, and local addon targets. Native keybindings stay assigned. Export first to keep portable preferences.", 11, 20, -58, 550)
            local cancel = Button(modal, "CANCEL", 150, 34, function() resetOverlay:Hide() end)
            Point(cancel, "BOTTOMRIGHT", modal, "BOTTOMRIGHT", -188, 18)
            local confirm = Button(modal, "RESET PROFILE", 150, 34, function()
                if InCombatLockdown() then return end
                resetOverlay:Hide(); RA:ResetProfile(); kit.Refresh()
            end, true)
            Point(confirm, "BOTTOMRIGHT", modal, "BOTTOMRIGHT", -20, 18)
            RA.ConfigFrame:HookScript("OnHide", function() resetOverlay:Hide() end)
        end
        resetOverlay:Show()
    end)
    Point(reset, "TOPLEFT", danger, "TOPLEFT", 20, -78)
    local commandStatus = Text(settings, "", 11, 0, -560, 930)
    refreshers.SETTINGS = function()
        SetText(commandStatus, "Open Morning Brew with /rcp. Unique fallback: /rcparsenal.\n" .. (RA.GetSlashCommandStatus and RA:GetSlashCommandStatus() or ""))
    end
    refreshers.NORTHERNSKY = RA:CreateNorthernSkyPane(panes.NORTHERNSKY, kit)
    return function(key)
        if refreshers[key] then refreshers[key]() end
    end
end
