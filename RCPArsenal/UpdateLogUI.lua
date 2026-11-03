local _, RA = ...
local Log = {}
RA.UpdateLogUI = Log

function Log:Hide()
    if self.overlay then self.overlay:Hide() end
end

function Log:Attach(sidebar, kit)
    local T, C = RA.Theme, RA.Theme.Colors
    local Point, Size = T.SetPoint, T.SetSize
    local owner = RA.ConfigFrame
    local overlay
    local function Text(parent, value, size, x, y, width, height, color)
        local text = kit.Font(parent, size, color or C.text, "REGULAR")
        RA:SetVisualText(text, value)
        Point(text, "TOPLEFT", parent, "TOPLEFT", x, y)
        Size(text, width, height)
        text:SetJustifyV("TOP")
        text:SetWordWrap(true)
        return text
    end
    local function Open()
        -- Building the notes is deliberately deferred until the first click.
        if not overlay then
            overlay = CreateFrame("Frame", "RCPArsenalUpdateLog", owner, "BackdropTemplate")
            overlay:SetAllPoints(owner)
            overlay:SetFrameLevel(owner:GetFrameLevel() + 100)
            overlay:EnableMouse(true)
            kit.Backdrop(overlay, {0, 0, 0, 0.72}, C.line, 18, false)
            local dialog = CreateFrame("Frame", nil, overlay, "BackdropTemplate")
            Size(dialog, 960, 620)
            Point(dialog, "CENTER", overlay, "CENTER", 0, 0)
            dialog:EnableMouse(true)
            kit.Backdrop(dialog, C.surface, C.lineStrong, 14, true)
            Text(dialog, "What's new", 22, 28, -24, 760, 30)
            Text(dialog, "Recent Arsenal updates", 11, 28, -60, 760, 20, C.textSoft)
            local close = kit.Button(dialog, "CLOSE", 100, 32, function() overlay:Hide() end)
            Point(close, "TOPRIGHT", dialog, "TOPRIGHT", -28, -24)

            local scroll = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate")
            Point(scroll, "TOPLEFT", dialog, "TOPLEFT", 28, -102)
            Point(scroll, "BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -52, 28)
            local body = CreateFrame("Frame", nil, scroll)
            local width, y = 856, 0
            for _, entry in ipairs(RA.ReleaseNotes) do
                Text(body, entry.title, 16, 0, -y, width, 24)
                y = y + 28
                Text(body, "v" .. entry.version, 10, 0, -y, width, 18, C.magenta)
                y = y + 30
                for _, group in ipairs(entry.groups) do
                    Text(body, group.label, 11, 0, -y, width, 18, C.textSoft)
                    y = y + 24
                    for _, note in ipairs(group.items) do
                        Text(body, "• " .. note, 12, 0, -y, width, 40)
                        y = y + 44
                    end
                end
                local rule = body:CreateTexture(nil, "ARTWORK")
                rule:SetColorTexture(unpack(C.line))
                Size(rule, width, 1)
                Point(rule, "TOPLEFT", body, "TOPLEFT", 0, -y)
                y = y + 26
            end
            Size(body, width, y)
            scroll:SetScrollChild(body)
            overlay.scroll = scroll
            overlay.dialog = dialog
            overlay.closeButton = close
            if type(UISpecialFrames) == "table" then
                table.insert(UISpecialFrames, "RCPArsenalUpdateLog")
            end
            owner:HookScript("OnHide", function() overlay:Hide() end)
            self.overlay = overlay
        end
        overlay.scroll:SetVerticalScroll(0)
        overlay:Show()
    end
    local button = kit.Button(sidebar, "WHAT'S NEW", 138, 20, Open)
    Point(button, "TOPLEFT", sidebar, "TOPLEFT", 70, -63)
    RA:ApplyFont(button.label, 10, "BOLD", false)
    T.SetHeight(button.label, 14)
    return button
end
