local _, RA = ...

-- The hub only reads addon metadata and saved preferences on open. Network
-- requests and target approval always require the corresponding button click.
function RA:CreateHubPanes(panes, kit)
    local T, C = self.Theme, self.Theme.Colors
    local Point, Size, Width = T.SetPoint, T.SetSize, T.SetWidth
    local Font, Button, Card = kit.Font, kit.Button, kit.Card
    local selectedAddon = "arsenal"
    local refreshers, matrixRows, addonRows, selectors = {}, {}, {}, {}
    local feedback, targetBox, matrixTitle, matrixMeta, matrixScroll, matrixChild
    local lastTargetID, lastTargetValue
    local linkOverlay, linkBox, linkTitle, resetOverlay
    local function Text(parent, value, size, x, y, width, color)
        local text = Font(parent, size or 11, color or C.textSoft, "REGULAR")
        text:SetText(value or "")
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
        if feedback then feedback:SetText(message or (ok and "Saved." or "Unavailable.")) end
    end
    function RA:HideHubTransientDialogs()
        if linkOverlay then linkOverlay:Hide() end
        if resetOverlay then resetOverlay:Hide() end
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
        linkTitle:SetText(entry.name .. " — copy link to your browser")
        linkBox:SetText(entry.url); linkBox:SetCursorPosition(0)
        linkOverlay:Show(); linkBox:SetFocus(); linkBox:HighlightText()
    end

    function RA:ShowAddonLink(id)
        local entry = RA.AddonCatalog:GetEntry(id)
        if entry then CopyLink(entry) end
    end
    RA.ConfigFrame:HookScript("OnHide", function() RA:HideHubTransientDialogs() end)

    local addons = panes.ADDONS
    kit.Heading(addons, "Morning Brew", "Your raid's addon shelf. Install or update addons with your addon manager, then reload WoW.")
    local localMeta = Text(addons, "", 10, 0, -61, 760)
    local refresh = Button(addons, "REFRESH LOCAL", 156, 32, function()
        RA.AddonCatalog:RefreshLocal(); refreshers.ADDONS()
    end)
    Point(refresh, "TOPRIGHT", addons, "TOPRIGHT", 0, -55)
    for i, entry in ipairs(RA.AddonCatalog.Entries) do
        local row = CreateFrame("Frame", nil, addons, "BackdropTemplate")
        Size(row, 950, 73); Point(row, "TOPLEFT", addons, "TOPLEFT", 0, -100 - (i - 1) * 79)
        kit.Backdrop(row, C.surface, C.line, 10, false)
        Text(row, entry.name, 13, 16, -10, 295, C.text)
        Text(row, entry.priority, 9, 320, -12, 110, entry.priority == "Optional" and C.orange or C.magenta)
        Text(row, entry.description, 9.8, 16, -34, 410)
        local details = Text(row, "", 10, 452, -12, 354)
        details:SetSpacing(4)
        local link = Button(row, entry.id == "northernsky" and "SETUP" or "LINK", 94, 32, function()
            if entry.id == "northernsky" then RA:OpenConfig("NORTHERNSKY") else CopyLink(entry) end
        end)
        Point(link, "RIGHT", row, "RIGHT", -14, 0)
        addonRows[entry.id] = details
    end
    refreshers.ADDONS = function()
        local report = RA.AddonCatalog:GetLocalReport()
        localMeta:SetText("Arsenal " .. Literal(report.version) .. "  ·  build " .. Literal(report.build) .. "  ·  protocol " .. tostring(report.protocol or "Unknown"))
        for id, details in pairs(addonRows) do
            local row = report.byID[id] or {}
            details:SetText("Installed " .. Tri(row.installed) .. "  ·  Enabled " .. Tri(row.enabled) .. "  ·  Loaded " .. Tri(row.loaded) .. "\nVersion " .. Literal(row.version))
        end
    end

    local tools = panes.MYTOOLS
    kit.Heading(tools, "Personal tools", "Optional resurrection and consumable reminders. HUD, Quick Bar, and World Markers each have their own sidebar page.")
    local function Tool(label, description, getter, setter, y)
        local toggle = kit.Toggle(tools, label, description, getter, function(value)
            local ok, reason = setter(value)
            if ok == false and reason then RA:Print(reason) end
        end)
        Point(toggle, "TOPLEFT", tools, "TOPLEFT", 0, y); Width(toggle, 950)
    end
    Tool("Accept normal resurrection", "Accepts ordinary resurrection offers. Battle resurrection stays manual while encounter or group combat is active.",
        function() return RA:GetDB().personalTools.autoRes == true end, function(v) return RA.PersonalTools:SetOption("autoRes", v) end, -68)
    Tool("Healthstone / potion reminder", "An optional bouncing reminder for a usable item at low health. Use your own item keybind.",
        function() return RA:GetDB().personalTools.consumableReminder == true end, function(v) return RA.PersonalTools:SetOption("consumableReminder", v) end, -134)
    local threshold = kit.Slider(tools, "Reminder health threshold", 1, 99, 1,
        function() return RA:GetDB().personalTools.healthThreshold end,
        function(v) RA.PersonalTools:SetOption("healthThreshold", v) end,
        function(v) return string.format("%d%%", v) end)
    Width(threshold, 440); Point(threshold, "TOPLEFT", tools, "TOPLEFT", 16, -205)
    local preview = Button(tools, "PREVIEW", 110, 34, function() RA.PersonalTools:PreviewReminder() end)
    Point(preview, "TOPLEFT", tools, "TOPLEFT", 480, -216)
    local move = Button(tools, "MOVE", 110, 34, function() RA.PersonalTools:MoveReminder() end)
    Point(move, "TOPLEFT", tools, "TOPLEFT", 598, -216)
    local stop = Button(tools, "STOP PREVIEW", 110, 34, function() RA.PersonalTools:StopReminderPreview() end)
    Point(stop, "TOPLEFT", tools, "TOPLEFT", 716, -216)
    local resetReminder = Button(tools, "RESET", 110, 34, function() RA.PersonalTools:ResetReminderPosition() end)
    Point(resetReminder, "TOPLEFT", tools, "TOPLEFT", 834, -216)
    Text(tools, "Press your item/macro key when reminded. Preview, Move, and Reset keep your tool switch unchanged.", 10, 16, -269, 914)
    local personalStatus = Text(tools, "", 10, 16, -302, 914)
    personalStatus:SetSpacing(5)
    refreshers.MYTOOLS = function()
        personalStatus:SetText("Resurrection: " .. RA.PersonalTools:GetStatusText("autoRes") .. "\nReminder: " .. RA.PersonalTools:GetStatusText("consumableReminder"))
    end

    local raid = panes.RAIDTOOLS
    kit.Heading(raid, "Version check", "Leaders and assistants can request addon reports. Replies are passive; no talent inspection is required.")
    matrixMeta = Text(raid, "", 10, 0, -60, 720)
    local query = Button(raid, "CHECK GROUP VERSIONS", 218, 34, function()
        local ok, reason = RA.Readiness:QueryGroup(); Result(ok, reason)
        refreshers.RAIDTOOLS()
    end, true)
    Point(query, "TOPRIGHT", raid, "TOPRIGHT", 0, -54)
    local shortNames = {arsenal = "Arsenal", northernsky = "Northern Sky", rclootcouncil = "RCLootCouncil", simulationcraft = "Simulationcraft", wowutils = "WowUtils", autopotion = "AutoPotion", bigwigs = "BigWigs"}
    Text(raid, "TEAM ADDONS", 8.5, 0, -91, 665, C.muted)
    Text(raid, "OPTIONAL", 8.5, 683, -91, 260, C.orange)
    for i, entry in ipairs(RA.AddonCatalog.Entries) do
        local b = Button(raid, shortNames[entry.id], 131, 32, function()
            selectedAddon = entry.id; lastTargetID = nil; refreshers.RAIDTOOLS()
        end)
        Point(b, "TOPLEFT", raid, "TOPLEFT", (i - 1) * 136.5, -104)
        selectors[entry.id] = b
    end
    Text(raid, "LOCAL TARGET", 9, 0, -156, 115, C.magenta)
    targetBox = CreateFrame("EditBox", nil, raid, "BackdropTemplate")
    Size(targetBox, 210, 32); Point(targetBox, "TOPLEFT", raid, "TOPLEFT", 120, -147)
    kit.Backdrop(targetBox, C.input, C.line, 8, false)
    RA:ApplyFont(targetBox, 11, "REGULAR", false)
    targetBox:SetTextInsets(10, 10, 0, 0); targetBox:SetAutoFocus(false); targetBox:SetMaxLetters(64)
    targetBox:SetScript("OnEscapePressed", function(box) box:ClearFocus(); lastTargetID = nil; refreshers.RAIDTOOLS() end)
    local function SaveTarget()
        local ok, reason = RA.Readiness:SetTarget(selectedAddon, targetBox:GetText() or "")
        targetBox:ClearFocus(); lastTargetID = nil; Result(ok, reason); refreshers.RAIDTOOLS()
    end
    targetBox:SetScript("OnEnterPressed", SaveTarget)
    local save = Button(raid, "SAVE TARGET", 130, 32, SaveTarget)
    Point(save, "TOPLEFT", raid, "TOPLEFT", 340, -147)
    local clear = Button(raid, "CLEAR", 88, 32, function()
        local ok, reason = RA.Readiness:SetTarget(selectedAddon, nil)
        targetBox:ClearFocus(); lastTargetID = nil; Result(ok, reason); refreshers.RAIDTOOLS()
    end)
    Point(clear, "TOPLEFT", raid, "TOPLEFT", 480, -147)
    local capture = Button(raid, "USE MY ENABLED ADDON VERSIONS", 292, 32, function()
        local ok, count = RA.Readiness:UseLocalTargets(); lastTargetID = nil
        Result(ok, ok and (tostring(count) .. " targets updated from this character.") or count)
        refreshers.RAIDTOOLS()
    end)
    Point(capture, "TOPRIGHT", raid, "TOPRIGHT", 0, -147)
    feedback = Text(raid, "Targets are saved locally in Arsenal. They compare exact installed versions; they do not check the web for newest releases.", 9.5, 0, -191, 950, C.muted)
    matrixTitle = Text(raid, "", 12, 0, -226, 950, C.text)
    Text(raid, "PLAYER / RESPONSE", 9, 0, -256, 245, C.muted)
    Text(raid, "INSTALLED VERSION", 9, 267, -256, 260, C.muted)
    Text(raid, "STATUS AGAINST TARGET", 9, 550, -256, 260, C.muted)
    matrixScroll = CreateFrame("ScrollFrame", nil, raid, "UIPanelScrollFrameTemplate")
    Point(matrixScroll, "TOPLEFT", raid, "TOPLEFT", 0, -277)
    Point(matrixScroll, "BOTTOMRIGHT", raid, "BOTTOMRIGHT", -26, 2)
    matrixChild = CreateFrame("Frame", nil, matrixScroll)
    Width(matrixChild, 920); T.SetHeight(matrixChild, 360); matrixScroll:SetScrollChild(matrixChild)
    local labels = {current = "Matches target", outdated = "Older than target", ahead = "Newer than target", different = "Different version", no_target = "No target set", unknown = "Unknown", missing = "Missing", disabled = "Disabled", not_loaded = "Enabled, not loaded", offline = "Offline"}
    local responseLabels = {unknown = "No response", local_report = "Local", ["local"] = "Local", offline = "Offline", responding = "Responding", partial = "Partial response", complete = "Reported"}
    refreshers.RAIDTOOLS = function()
        local snapshot = RA.Readiness:GetSnapshot()
        local settings = RA.Readiness:GetTargets()
        local target = settings.targets[selectedAddon] or ""
        if lastTargetID ~= selectedAddon or lastTargetValue ~= target then
            targetBox:SetText(target); lastTargetID, lastTargetValue = selectedAddon, target
        end
        for id, b in pairs(selectors) do b:SetSelected(id == selectedAddon) end
        local entry = RA.AddonCatalog:GetEntry(selectedAddon)
        local age = snapshot.queriedAt and math.max(0, math.floor((GetTime() or 0) - snapshot.queriedAt)) or nil
        matrixTitle:SetText(entry.name .. "  ·  " .. entry.priority .. (age and ("  ·  " .. age .. "s since query" .. (snapshot.stale and " — STALE" or "")) or ""))
        local eligible, reason = RA.Readiness:GetQueryEligibility()
        query:SetEnabled(eligible)
        query:SetAlpha(eligible and 1 or 0.55)
        matrixMeta:SetText((not eligible and reason or RA.Readiness:GetStatusText()) .. "\nLocal target set " .. tostring(settings.revision or 0) .. "  ·  " .. (settings.origin ~= "" and Literal(settings.origin) or "No targets captured"))

        local rows = snapshot.rows or {}
        for i, member in ipairs(rows) do
            local row = matrixRows[i]
            if not row then
                row = CreateFrame("Frame", nil, matrixChild, "BackdropTemplate")
                Size(row, 920, 31); Point(row, "TOPLEFT", matrixChild, "TOPLEFT", 0, -(i - 1) * 34)
                kit.Backdrop(row, C.surface, C.line, 6, false)
                row.name = Text(row, "", 10, 10, -4, 240, C.text)
                row.name:SetWordWrap(false)
                row.version = Text(row, "", 10, 267, -9, 265)
                row.state = Text(row, "", 10, 550, -9, 350)
                matrixRows[i] = row
            end
            local addon = member.addons and member.addons[selectedAddon] or {}
            local response = responseLabels[member.status] or Literal(member.status)
            row.name:SetText(Literal(member.name) .. "  ·  " .. response)
            local unknown = member.status == "unknown" or member.status == "offline"
            row.version:SetText(unknown and "Unknown" or Literal(addon.version))
            local comparison = labels[addon.versionState] or "Unknown"
            local loadState = addon.state ~= addon.versionState and labels[addon.state] or nil
            row.state:SetText(unknown and response or (comparison .. (loadState and (" · " .. loadState) or "")))
            row.state:SetTextColor(unpack(addon.versionState == "current" and C.text or ((addon.versionState == "outdated" or addon.state == "missing" or addon.state == "disabled") and C.orange or C.textSoft)))
            row:Show()
        end
        for i = #rows + 1, #matrixRows do matrixRows[i]:Hide() end
        T.SetHeight(matrixChild, math.max(360, #rows * 34))
    end

    -- Only the visible matrix ages its snapshot and rechecks button eligibility.
    -- This timer performs no network request or talent inspection.
    local matrixTicker
    raid:HookScript("OnShow", function()
        if not matrixTicker then matrixTicker = C_Timer.NewTicker(1, function()
            if raid:IsVisible() then refreshers.RAIDTOOLS() end
        end) end
    end)
    local function StopMatrixTicker()
        if matrixTicker then matrixTicker:Cancel(); matrixTicker = nil end
    end
    raid:HookScript("OnHide", StopMatrixTicker)
    RA.ConfigFrame:HookScript("OnHide", StopMatrixTicker)

    local settings = panes.SETTINGS
    kit.Heading(settings, "Profiles & Recovery", "Import or export portable preferences. Appearance controls are on HUD and Content; tool switches stay on their own pages.")
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
        self.label:SetText(danger:IsShown() and "HIDE FULL RESET" or "ADVANCED: FULL PROFILE RESET")
    end)
    Point(advancedReset, "TOPLEFT", settings, "TOPLEFT", 0, -310)
    local function HideResetOptions() danger:Hide(); advancedReset.label:SetText("ADVANCED: FULL PROFILE RESET") end
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
        commandStatus:SetText("Open Morning Brew with /rcp. Unique fallback: /rcparsenal.\n" .. (RA.GetSlashCommandStatus and RA:GetSlashCommandStatus() or ""))
    end
    refreshers.NORTHERNSKY = RA:CreateNorthernSkyPane(panes.NORTHERNSKY, kit)
    return function(key)
        if refreshers[key] then refreshers[key]() end
    end
end
