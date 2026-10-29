local _, RA = ...

local Theme = RA.Theme
local TC = Theme.Colors

local frame
local function HideConfig(intent)
    if not frame then return end
    frame.__rcpHideIntent=intent
    frame:Hide()
    frame.__rcpHideIntent=nil
end
local panes = {}
local tabButtons = {}
local controls = {}
local activeTab = "GENERAL"
local selectedCategory = "RAID_DEFENSIVE"
local abilityRows = {}
local categoryRows = {}
local searchText = ""
local statusText
local contentScroll
local contentScrollChild
local previewHUD
local previewLanes = {}
local previewBadge
local scanStatusValue
local scanStatusPill
local scanStatusDetail
local scanPrimaryButton
local profileDialog
local profileDialogBox
local profileDialogMode
local profileDialogStatus
local mainTitle
local mainSubtitle
local actionStatusText
local actionStatusDetail
local hudFooter
local RefreshWorldMarkers
local RefreshConfig
local RefreshHub
local RefreshFooter
local RefreshGeneral
local RefreshRaidGroups
local placementReturnPending
local advancedBack
local cooldownScroll
local cooldownTabs = {}
local panicStatus
local scanStripState

-- Compatibility aliases for the existing page logic. The visual system itself
-- lives in Theme.lua so the settings window can use soft, layered surfaces
-- instead of high-contrast bordered rectangles.
local COLORS = {
    backdrop = TC.canvasDeep,
    panel = TC.surface,
    card = TC.surfaceRaised,
    cardHover = TC.surfaceHover,
    raised = TC.surfacePressed,
    edge = TC.lineStrong,
    edgeSoft = TC.line,
    text = TC.text,
    muted = TC.textSoft,
    faint = TC.muted,
    accent = TC.magenta,
    accentDark = TC.activeDark,
    active = TC.orange,
    amber = TC.orange,
    danger = TC.danger,
    white = TC.white,
}

local TAB_DEFS = {
    { key = "GENERAL", label = "GENERAL", group = "PERSONAL", icon = Theme.Assets.NavContent },
    { key = "MYTOOLS", label = "PERSONAL TOOLS", group = "PERSONAL", icon = Theme.Assets.NavHUD },
    { key = "ADDONS", label = "ADDONS & VERSIONS", group = "RAID LEADER TOOLS", icon = Theme.Assets.NavContent },
    { key = "QUICKBAR", label = "QUICK BAR", group = "RAID LEADER TOOLS", icon = Theme.Assets.NavHUD },
    { key = "RAIDGROUPS", label = "RAID GROUPS", group = "RAID LEADER TOOLS", icon = Theme.Assets.NavContent },
    { key = "COOLDOWNS", label = "AVAILABLE COOLDOWNS", group = "RAID LEADER TOOLS", icon = Theme.Assets.NavHUD },
    { key = "WORLDMARKERS", label = "WORLD MARKERS", group = "RAID LEADER TOOLS", icon = Theme.Assets.NavActions },
    { key = "SETTINGS", label = "PROFILES & RECOVERY", group = "SYSTEM", icon = Theme.Assets.NavActions },
}
local PANE_CONTEXT = {
    NORTHERNSKY = "ADDONS",
    CONTENT = "COOLDOWNS", HUD = "COOLDOWNS", SCANNING = "COOLDOWNS", ACTIONS = "COOLDOWNS",
}
local COOLDOWN_TABS = {
    {key = "CONTENT", label = "CATEGORIES", width = 162},
    {key = "HUD", label = "DISPLAY & POSITION", width = 228},
    {key = "SCANNING", label = "SCANNING", width = 162},
    {key = "ACTIONS", label = "CALLOUTS & PANIC", width = 218},
}
local function PaneContext(key)
    return PANE_CONTEXT[key]
end
local function Navigation()
    -- Local window navigation is independent of portable/resettable profiles.
    if type(RaidArsenalDB.navigation) ~= "table" then RaidArsenalDB.navigation = {} end
    return RaidArsenalDB.navigation
end

local TIER_COLORS = {
    CORE = TC.magenta,
    OPTIONAL = TC.orange,
    NICHE = TC.textSoft,
}

local SetPoint = Theme.SetPoint
local SetSize = Theme.SetSize
local SetWidth = Theme.SetWidth
local SetHeight = Theme.SetHeight

local function CopyColor(color, alpha)
    return {color[1], color[2], color[3], alpha == nil and (color[4] or 1) or alpha}
end

local function SetSurfaceColor(object, color)
    object.__raSurfaceColor = color
    Theme:SetRoundedColor(object, color, "base")
end

local function SetBorderColor(object, color)
    object.__raBorderColor = color
    Theme:SetRoundedColor(object, color, "border")
end

local function Backdrop(object, background, border, radius, shadow)
    Theme:ApplyBackdropTemplate(object)
    radius = radius or 10
    background = background or COLORS.card
    border = border or COLORS.edgeSoft

    Theme:ApplyRounded(object, border, radius + 1, "border", "BACKGROUND", -5)
    Theme:ApplyRounded(object, background, radius, "base", "BACKGROUND", -4, {1, -1, -1, 1})
    if shadow then
        Theme:AddShadow(object, radius, 0.34)
    end
    object.__raSurfaceColor = background
    object.__raBorderColor = border
end

local function ApplyIconMask(texture, owner)
    if Theme and Theme.ApplyIconMask then
        return Theme:ApplyIconMask(texture, owner)
    end
    return nil
end

local function ApplyReadableFont(fontString, size, weight, shadow)
    if RA.ApplyFont then
        RA:ApplyFont(fontString, size, weight or "REGULAR", shadow == true)
    else
        fontString:SetFont("Fonts\\ARIALN.TTF", size, "")
        if fontString.SetShadowColor then
            fontString:SetShadowColor(0, 0, 0, 0)
            fontString:SetShadowOffset(0, 0)
        end
    end
end

local function Font(parent, size, color, style)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local weight = style == "REGULAR" and "REGULAR" or ((style == "BOLD" or size >= 11) and "BOLD" or "REGULAR")
    ApplyReadableFont(fs, size, weight, false)
    fs:SetTextColor(unpack(color or COLORS.text))
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("MIDDLE")
    return fs
end

local function RegisterControl(control)
    controls[#controls + 1] = control
    return control
end
local function RefreshVisibleControls()
    for i = 1, #controls do
        local control = controls[i]
        local owner = control.owner or control
        if control.Refresh and (not owner.IsVisible or owner:IsVisible()) then control:Refresh() end
    end
end

local function CreateGradientOverlay(parent, asset, alpha, inset)
    local texture = Theme:AddGradient(parent, asset or Theme.Assets.GradientSunset, alpha or 0, inset or 2, "BACKGROUND", -2)
    texture:SetBlendMode("BLEND")
    return texture
end

local function CreateButton(parent, label, width, height, onClick, emphasis, iconAsset)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    SetSize(button, width, height or 34)
    Backdrop(button, emphasis and TC.activeDark or TC.surfaceRaised, emphasis and CopyColor(TC.magenta, 0.24) or TC.line, 9, false)

    button.gradient = CreateGradientOverlay(button, Theme.Assets.GradientSunset, emphasis and 0.76 or 0, 2)
    if iconAsset then
        button.icon = Theme:CreateIcon(button, iconAsset, 18, COLORS.white)
        SetPoint(button.icon, "LEFT", button, "LEFT", 13, 0)
    end

    button.label = Font(button, 11.2, emphasis and COLORS.white or COLORS.text, "BOLD")
    RA:SetVisualText(button.label, label)
    button.label:SetJustifyH("CENTER")
    button.label:SetWordWrap(false)
    SetHeight(button.label, 20)
    if iconAsset then
        SetPoint(button.label, "LEFT", button.icon, "RIGHT", 8, 0)
        SetPoint(button.label, "RIGHT", button, "RIGHT", -12, 0)
    else
        SetPoint(button.label, "LEFT", button, "LEFT", 8, 0)
        SetPoint(button.label, "RIGHT", button, "RIGHT", -8, 0)
    end

    button.emphasis = emphasis == true
    button.selected = false

    function button:SetSelected(selected)
        self.selected = selected == true
        if self.selected then
            SetSurfaceColor(self, TC.activeDark)
            SetBorderColor(self, CopyColor(TC.magenta, 0.40))
            self.gradient:SetAlpha(0.78)
            self.label:SetTextColor(unpack(COLORS.white))
        else
            SetSurfaceColor(self, self.emphasis and TC.activeDark or TC.surfaceRaised)
            SetBorderColor(self, self.emphasis and CopyColor(TC.magenta, 0.24) or TC.line)
            self.gradient:SetAlpha(self.emphasis and 0.70 or 0)
            self.label:SetTextColor(unpack(self.emphasis and COLORS.white or COLORS.text))
        end
    end

    button:SetScript("OnEnter", function(self)
        if not self.selected then
            SetSurfaceColor(self, self.emphasis and TC.activeSoft or TC.surfaceHover)
            self.gradient:SetAlpha(self.emphasis and 0.90 or 0.12)
        end
    end)
    button:SetScript("OnLeave", function(self)
        self:SetSelected(self.selected)
    end)
    button:SetScript("OnClick", onClick)
    return button
end

local function CreateIconButton(parent, asset, tooltipText, onClick)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    SetSize(button, 30, 30)
    Backdrop(button, TC.input, TC.line, 9, false)
    button.icon = Theme:CreateIcon(button, asset, 13, TC.textSoft)
    SetPoint(button.icon, "CENTER", button, "CENTER", 0, 0)
    button:SetScript("OnEnter", function(self)
        SetSurfaceColor(self, TC.surfaceHover)
        self.icon:SetVertexColor(unpack(TC.white))
        if tooltipText then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tooltipText, 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function(self)
        SetSurfaceColor(self, TC.input)
        self.icon:SetVertexColor(unpack(TC.textSoft))
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", onClick)
    return button
end

local function CreateCard(parent, titleText, subtitleText, accentAsset)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    Backdrop(card, TC.surface, TC.line, 14, true)
    card.topWash = Theme:AddTopWash(card, accentAsset or Theme.Assets.GradientSunsetWash, 0.055, 72, 2)

    card.accent = card:CreateTexture(nil, "ARTWORK")
    Theme:RegisterAccentTexture(card.accent, (accentAsset == Theme.Assets.GradientBerry or accentAsset == Theme.Assets.GradientDigitalBerry) and "SECONDARY" or "PRIMARY")
    SetSize(card.accent, 72, 3)
    SetPoint(card.accent, "TOPLEFT", card, "TOPLEFT", 18, -1)
    card.accent:SetAlpha(0.80)

    card.divider = card:CreateTexture(nil, "ARTWORK")
    card.divider:SetColorTexture(unpack(TC.line))
    SetHeight(card.divider, 1)
    SetPoint(card.divider, "TOPLEFT", card, "TOPLEFT", 18, -54)
    SetPoint(card.divider, "TOPRIGHT", card, "TOPRIGHT", -18, -54)

    if titleText then
        card.title = Font(card, 13.5, TC.text, "BOLD")
        RA:SetVisualText(card.title, titleText)
        SetPoint(card.title, "TOPLEFT", card, "TOPLEFT", 18, -13)
    end
    if subtitleText then
        card.subtitle = Font(card, 9.7, TC.textSoft, "REGULAR")
        RA:SetVisualText(card.subtitle, subtitleText)
        card.subtitle:SetWordWrap(true)
        SetPoint(card.subtitle, "TOPLEFT", card, "TOPLEFT", 18, -34)
        SetPoint(card.subtitle, "TOPRIGHT", card, "TOPRIGHT", -18, -34)
    end
    return card
end

local function ApplyVisualChange()
    if RA.RefreshHUD then
        RA:RefreshHUD()
    end
    if frame and frame:IsShown() and frame.UpdatePreview then
        frame:UpdatePreview()
    end
end

local function AbilitySetting(ability)
    local explicit = RA:GetDB().abilities[ability.key]
    if explicit ~= nil then
        return explicit
    end
    return ability.defaultEnabled ~= false
end

local function CreateToggle(parent, labelText, description, getter, setter)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    SetHeight(row, 50)
    Backdrop(row, TC.surfaceRaised, TC.line, 10, false)

    row.title = Font(row, 11.5, TC.text, "BOLD")
    SetHeight(row.title, 16)
    RA:SetVisualText(row.title, labelText)
    SetPoint(row.title, "TOPLEFT", row, "TOPLEFT", 14, -9)
    SetPoint(row.title, "TOPRIGHT", row, "TOPRIGHT", -66, -9)

    row.description = Font(row, 9.1, TC.textSoft, "REGULAR")
    RA:SetVisualText(row.description, description or "")
    row.description:SetWordWrap(true)
    SetPoint(row.description, "TOPLEFT", row, "TOPLEFT", 14, -25)
    SetPoint(row.description, "TOPRIGHT", row, "TOPRIGHT", -66, -25)

    row.switch = CreateFrame("Frame", nil, row, "BackdropTemplate")
    SetSize(row.switch, 40, 22)
    SetPoint(row.switch, "RIGHT", row, "RIGHT", -14, 0)
    Backdrop(row.switch, TC.input, TC.line, 11, false)

    row.knob = row.switch:CreateTexture(nil, "OVERLAY")
    Theme:RegisterAssetTexture(row.knob, Theme.Assets.SliderThumb)
    SetSize(row.knob, 20, 20)

    row:SetScript("OnEnter", function(self)
        SetSurfaceColor(self, TC.surfaceHover)
    end)
    row:SetScript("OnLeave", function(self)
        SetSurfaceColor(self, self.compactColor or TC.surfaceRaised)
    end)
    row:SetScript("OnClick", function()
        setter(not getter())
        row:Refresh()
    end)

    function row:SetCompact(alternate)
        self.compactColor = alternate and TC.surfaceRaised or TC.surface
        SetHeight(self, 44)
        Backdrop(self, self.compactColor, TC.transparent, 2, false)
        self.description:Hide()
        self.title:ClearAllPoints()
        SetPoint(self.title, "LEFT", self, "LEFT", 14, 0)
        SetPoint(self.title, "RIGHT", self, "RIGHT", -66, 0)
    end

    function row:Refresh()
        local enabled = getter() and true or false
        if enabled then
            SetSurfaceColor(self.switch, TC.activeDark)
            SetBorderColor(self.switch, CopyColor(TC.magenta, 0.42))
            self.knob:SetVertexColor(1, 1, 1, 1)
            self.knob:ClearAllPoints()
            SetPoint(self.knob, "RIGHT", self.switch, "RIGHT", -1, 0)
        else
            SetSurfaceColor(self.switch, TC.input)
            SetBorderColor(self.switch, TC.line)
            self.knob:SetVertexColor(0.56, 0.55, 0.66, 0.85)
            self.knob:ClearAllPoints()
            SetPoint(self.knob, "LEFT", self.switch, "LEFT", 1, 0)
        end
    end

    return RegisterControl(row)
end

local function RoundStep(value, step)
    step = step or 1
    return math.floor((value / step) + 0.5) * step
end

local function CreateSlider(parent, labelText, minimum, maximum, step, getter, setter, formatter)
    local control = CreateFrame("Frame", nil, parent)
    SetHeight(control, 50)

    control.title = Font(control, 10.8, TC.text, "BOLD")
    RA:SetVisualText(control.title, labelText)
    SetPoint(control.title, "TOPLEFT", control, "TOPLEFT", 0, -1)

    control.value = Font(control, 10.5, TC.orange, "BOLD")
    control.value:SetJustifyH("RIGHT")
    SetPoint(control.value, "TOPRIGHT", control, "TOPRIGHT", 0, -1)

    control.track = CreateFrame("Frame", nil, control, "BackdropTemplate")
    SetHeight(control.track, 7)
    SetPoint(control.track, "LEFT", control, "LEFT", 0, -14)
    SetPoint(control.track, "RIGHT", control, "RIGHT", 0, -14)
    Backdrop(control.track, TC.input, TC.transparent, 4, false)

    control.fill = control.track:CreateTexture(nil, "ARTWORK")
    Theme:RegisterAccentTexture(control.fill, "PRIMARY")
    SetHeight(control.fill, 5)
    SetPoint(control.fill, "LEFT", control.track, "LEFT", 1, 0)

    control.slider = CreateFrame("Slider", nil, control)
    SetHeight(control.slider, 24)
    SetPoint(control.slider, "LEFT", control.track, "LEFT", 0, 0)
    SetPoint(control.slider, "RIGHT", control.track, "RIGHT", 0, 0)
    control.slider:SetOrientation("HORIZONTAL")
    control.slider:SetMinMaxValues(minimum, maximum)
    control.slider:SetValueStep(step)
    if control.slider.SetObeyStepOnDrag then
        control.slider:SetObeyStepOnDrag(true)
    end
    control.slider:SetThumbTexture(Theme.Assets.SliderThumb)
    local thumb = control.slider:GetThumbTexture()
    if thumb then
        Theme:RegisterAssetTexture(thumb, Theme.Assets.SliderThumb)
        SetSize(thumb, 20, 20)
    end

    control.refreshing = false
    control.slider:SetScript("OnValueChanged", function(_, rawValue)
        local value = RoundStep(rawValue, step)
        local ratio = (value - minimum) / math.max(0.0001, maximum - minimum)
        SetWidth(control.fill, math.max(2, (control.track:GetWidth() - 2) * ratio))
        RA:SetVisualText(control.value, formatter and formatter(value) or tostring(value))
        if not control.refreshing then
            setter(value)
        end
    end)

    function control:Refresh()
        self.refreshing = true
        local value = getter()
        self.slider:SetValue(value)
        local ratio = (value - minimum) / math.max(0.0001, maximum - minimum)
        SetWidth(self.fill, math.max(2, (self.track:GetWidth() - 2) * ratio))
        RA:SetVisualText(self.value, formatter and formatter(value) or tostring(value))
        self.refreshing = false
    end

    return RegisterControl(control)
end

local function CreateSegmented(parent, labelText, options, getter, setter)
    local control = CreateFrame("Frame", nil, parent)
    SetHeight(control, 54)
    control.title = Font(control, 10.8, TC.text, "BOLD")
    RA:SetVisualText(control.title, labelText)
    SetPoint(control.title, "TOPLEFT", control, "TOPLEFT", 0, -1)
    control.buttons = {}

    for i = 1, #options do
        local option = options[i]
        local button = CreateFrame("Button", nil, control, "BackdropTemplate")
        Backdrop(button, TC.input, TC.line, 8, false)
        button.gradient = CreateGradientOverlay(button, Theme.Assets.GradientSunset, 0, 2)
        button.text = Font(button, 9.6, TC.textSoft, "BOLD")
        button.text:SetJustifyH("CENTER")
        button.text:SetWordWrap(false)
        RA:SetVisualText(button.text, option.label)
        SetPoint(button.text, "LEFT", button, "LEFT", 4, 0)
        SetPoint(button.text, "RIGHT", button, "RIGHT", -4, 0)
        SetHeight(button.text, 18)
        button:SetScript("OnClick", function()
            setter(option.value)
            control:Refresh()
        end)
        control.buttons[i] = { frame = button, value = option.value }
    end

    function control:Layout(width)
        local gap = 5
        local buttonWidth = (width - gap * (#options - 1)) / #options
        for i = 1, #self.buttons do
            local button = self.buttons[i].frame
            SetSize(button, buttonWidth, 28)
            button:ClearAllPoints()
            SetPoint(button, "BOTTOMLEFT", self, "BOTTOMLEFT", (i - 1) * (buttonWidth + gap), 0)
        end
    end

    function control:Refresh()
        local current = getter()
        for i = 1, #self.buttons do
            local entry = self.buttons[i]
            local selected = entry.value == current
            SetSurfaceColor(entry.frame, selected and TC.activeDark or TC.input)
            SetBorderColor(entry.frame, selected and CopyColor(TC.magenta, 0.38) or TC.line)
            entry.frame.gradient:SetAlpha(selected and 0.72 or 0)
            entry.frame.text:SetTextColor(unpack(selected and TC.white or TC.textSoft))
        end
    end

    return RegisterControl(control)
end

local function CreateEditBox(parent, labelText, description, getter, setter)
    local control = CreateFrame("Frame", nil, parent)
    SetHeight(control, 78)

    control.title = Font(control, 10.8, TC.text, "BOLD")
    RA:SetVisualText(control.title, labelText)
    SetPoint(control.title, "TOPLEFT", control, "TOPLEFT", 0, -1)

    control.description = Font(control, 9.0, TC.muted, "REGULAR")
    RA:SetVisualText(control.description, description or "")
    SetPoint(control.description, "TOPRIGHT", control, "TOPRIGHT", 0, -1)
    control.description:SetJustifyH("RIGHT")

    control.box = CreateFrame("EditBox", nil, control, "BackdropTemplate")
    SetHeight(control.box, 34)
    SetPoint(control.box, "BOTTOMLEFT", control, "BOTTOMLEFT", 0, 0)
    SetPoint(control.box, "BOTTOMRIGHT", control, "BOTTOMRIGHT", 0, 0)
    Backdrop(control.box, TC.input, TC.line, 9, false)
    ApplyReadableFont(control.box, 10.8, "REGULAR")
    control.box:SetTextColor(unpack(TC.text))
    control.box:SetAutoFocus(false)
    control.box:SetMaxLetters(180)
    control.box:SetTextInsets(12, 12, 0, 0)

    local function Commit()
        setter(control.box:GetText())
        ApplyVisualChange()
    end
    control.box:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        Commit()
    end)
    control.box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        control:Refresh()
    end)
    control.box:SetScript("OnEditFocusLost", Commit)

    function control:Refresh()
        if not self.box:HasFocus() then
            self.box:SetText(getter() or "")
        end
    end

    return RegisterControl(control)
end

local function CreateHeading(parent, titleText, subtitleText)
    local title = Font(parent, 21, TC.text, "BOLD")
    RA:SetVisualText(title, titleText)
    SetPoint(title, "TOPLEFT", parent, "TOPLEFT", 2, 0)

    local subtitle = Font(parent, 10.4, TC.textSoft, "REGULAR")
    RA:SetVisualText(subtitle, subtitleText)
    subtitle:SetWordWrap(true)
    SetWidth(subtitle, 856)
    SetPoint(subtitle, "TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    return title, subtitle
end

local function GetPreviewMetrics()
    local db = RA:GetDB()
    if RA.CompactLayout and RA.CompactLayout.GetMetrics then
        return RA.CompactLayout:GetMetrics(db)
    end
    return {}
end

local PREVIEW_DATA = {
    {
        key = "RAID_DEFENSIVE",
        items = {
            { ability = "spirit_link", name = "Axe", class = "SHAMAN" },
            { ability = "aura_mastery", name = "Talia", class = "PALADIN" },
            { ability = "rallying_cry", name = "Kade", class = "WARRIOR" },
        },
    },
    {
        key = "RAID_HEALING",
        items = {
            { ability = "evangelism", name = "Luma", class = "PRIEST" },
            { ability = "celestial_conduit", name = "Misty", class = "MONK" },
            { ability = "rewind", name = "Vinth", class = "EVOKER" },
        },
    },
    {
        key = "MOVEMENT",
        items = {
            { ability = "wind_rush", name = "Axe", class = "SHAMAN" },
            { ability = "stampeding_roar", name = "Leafy", class = "DRUID" },
        },
    },
}

local function EnsurePreviewLane(index)
    local lane = previewLanes[index]
    if lane then
        return lane
    end

    lane = CreateFrame("Frame", nil, previewHUD, "BackdropTemplate")
    Backdrop(lane, TC.surface, TC.line, 10, false)
    lane.accent = lane:CreateTexture(nil, "ARTWORK")
    Theme:RegisterAccentTexture(lane.accent, "PRIMARY")
    SetHeight(lane.accent, 2)
    SetPoint(lane.accent, "TOPLEFT", lane, "TOPLEFT", 8, -1)
    SetPoint(lane.accent, "TOPRIGHT", lane, "TOPRIGHT", -8, -1)
    lane.accent:SetAlpha(0.52)
    lane.label = Font(lane, 8, TC.textSoft, "BOLD")
    lane.label:SetJustifyH("CENTER")
    lane.label:SetJustifyV("MIDDLE")
    lane.tiles = {}
    previewLanes[index] = lane
    return lane
end

local function EnsurePreviewTile(lane, index)
    local tile = lane.tiles[index]
    if tile then
        return tile
    end

    tile = CreateFrame("Frame", nil, lane, "BackdropTemplate")
    Backdrop(tile, TC.transparent, TC.transparent, 8, false)
    tile.iconFrame = CreateFrame("Frame", nil, tile, "BackdropTemplate")
    Backdrop(tile.iconFrame, TC.input, TC.lineStrong, 8, false)
    tile.icon = tile.iconFrame:CreateTexture(nil, "ARTWORK")
    tile.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    SetPoint(tile.icon, "TOPLEFT", tile.iconFrame, "TOPLEFT", 1, -1)
    SetPoint(tile.icon, "BOTTOMRIGHT", tile.iconFrame, "BOTTOMRIGHT", -1, 1)
    ApplyIconMask(tile.icon, tile.iconFrame)
    tile.name = Font(tile, 8, TC.text, "BOLD")
    tile.name:SetJustifyH("CENTER")
    tile.name:SetWordWrap(false)
    lane.tiles[index] = tile
    return tile
end

local function UpdatePreview()
    if not previewHUD then return end

    local db = RA:GetDB()
    local metrics = GetPreviewMetrics()
    local panel = metrics.backgroundStyle == "PANEL"
    SetSurfaceColor(previewHUD, panel and TC.canvasDeep or TC.transparent)
    SetBorderColor(previewHUD, panel and TC.lineStrong or TC.transparent)

    local y = panel and -metrics.panelPadding or 0
    local maximumWidth = 0
    for laneIndex = 1, #PREVIEW_DATA do
        local data = PREVIEW_DATA[laneIndex]
        local lane = EnsurePreviewLane(laneIndex)
        local category = RA.CategoryByKey[data.key]
        local geometry = RA.CompactLayout and RA.CompactLayout:GetLaneGeometry(#data.items, metrics)
        local width = geometry and geometry.laneWidth or 1
        local height = geometry and geometry.laneHeight or 1
        local hasLabel = geometry and geometry.hasLabel or metrics.labelWidth > 0

        lane:ClearAllPoints()
        SetPoint(lane, "TOPLEFT", previewHUD, "TOPLEFT", panel and metrics.panelPadding or 0, y)
        SetSize(lane, width, height)
        local ribbon = metrics.backgroundStyle == "RIBBONS"
        SetSurfaceColor(lane, ribbon and TC.surface or TC.transparent)
        SetBorderColor(lane, ribbon and CopyColor(TC.lineStrong, 0.35) or TC.transparent)
        lane.accent:SetShown(ribbon)

        lane.label:ClearAllPoints()
        SetSize(lane.label, math.max(1, metrics.labelWidth), height)
        SetPoint(lane.label, "LEFT", lane, "LEFT", metrics.lanePadding, 0)
        lane.label:SetShown(hasLabel)
        RA:SetVisualText(lane.label, db.compact.categoryLabels == "FULL" and string.upper(category.name) or category.compactLabel)
        ApplyReadableFont(lane.label, metrics.categoryFont, "BOLD")

        for itemIndex = 1, #data.items do
            local item = data.items[itemIndex]
            local ability = RA.CatalogByKey[item.ability]
            local tile = EnsurePreviewTile(lane, itemIndex)
            SetSize(tile, metrics.tileWidth, metrics.tileHeight)
            tile:ClearAllPoints()
            local x, tileY = RA.CompactLayout:GetTilePosition(itemIndex, metrics, geometry)
            SetPoint(tile, "TOPLEFT", lane, "TOPLEFT", x, tileY)
            SetSize(tile.iconFrame, metrics.iconSize, metrics.iconSize)
            tile.iconFrame:ClearAllPoints()
            SetPoint(tile.iconFrame, "TOP", tile, "TOP", 0, 0)
            tile.icon:SetTexture(RA:GetAbilityTexture(ability))

            local tileBackground = metrics.backgroundStyle == "TILES"
            SetSurfaceColor(tile, tileBackground and TC.surfaceRaised or TC.transparent)
            SetBorderColor(tile, tileBackground and TC.lineStrong or TC.transparent)
            local naked = metrics.backgroundStyle == "NONE"
            SetSurfaceColor(tile.iconFrame, naked and TC.transparent or TC.canvasDeep)
            SetBorderColor(tile.iconFrame, naked and TC.transparent or CopyColor(TC.textSoft, 0.22))

            tile.name:ClearAllPoints()
            ApplyReadableFont(tile.name, metrics.nameFont, "BOLD")
            SetPoint(tile.name, "TOPLEFT", tile.iconFrame, "BOTTOMLEFT", -3, -1)
            SetPoint(tile.name, "TOPRIGHT", tile.iconFrame, "BOTTOMRIGHT", 3, -1)
            RA:SetVisualText(tile.name, string.sub(item.name, 1, metrics.nameLength))
            tile.name:SetShown(metrics.nameLength > 0)
            local r, g, b = RA:GetClassColor(item.class)
            tile.name:SetTextColor(r, g, b, 1)
            tile:Show()
        end
        for itemIndex = #data.items + 1, #lane.tiles do lane.tiles[itemIndex]:Hide() end

        lane:Show()
        y = y - height - metrics.categoryGap
        maximumWidth = math.max(maximumWidth, width)
    end

    local rawWidth = maximumWidth + (panel and metrics.panelPadding * 2 or 0)
    local rawHeight = -y + (panel and metrics.panelPadding or 0) - metrics.categoryGap
    local availableWidth, availableHeight = 450, 140
    local previewScale = math.min(1, availableWidth / math.max(1, rawWidth), availableHeight / math.max(1, rawHeight))
    previewHUD:SetScale(previewScale)
    SetSize(previewHUD, rawWidth, rawHeight)
    RA:SetVisualText(previewBadge, string.format("HUD %d%%  |  ICON %d", math.floor((db.scale or 1) * 100 + 0.5), metrics.iconSize or 28))
end

local function CreateHUDPane(parent)
    CreateHeading(parent, "Display & Position", "Move all stages every overlay together. These local controls affect only the HUD.")

    local settingsCard = CreateCard(parent, "LAYOUT", "Scale the complete HUD or tune its physical tile density independently.")
    SetSize(settingsCard, 438, 598)
    SetPoint(settingsCard, "TOPLEFT", parent, "TOPLEFT", 0, -62)

    local positionCard = CreateCard(parent, "POSITION & DIRECTION", "Growth uses your saved HUD anchor. These controls do not move the puck.")
    SetSize(positionCard, 500, 214)
    SetPoint(positionCard, "TOPRIGHT", parent, "TOPRIGHT", 0, -62)

    local rightCard = CreateCard(parent, "LAYOUT SAMPLE", "Sample providers show appearance without enabling the HUD or inspection.", Theme.Assets.GradientBerry)
    SetSize(rightCard, 500, 334)
    SetPoint(rightCard, "TOPRIGHT", parent, "TOPRIGHT", 0, -290)
    rightCard:Hide()

    previewHUD = CreateFrame("Frame", nil, rightCard, "BackdropTemplate")
    Backdrop(previewHUD, TC.transparent, TC.transparent, 10, false)
    SetPoint(previewHUD, "CENTER", rightCard, "CENTER", 0, -8)

    previewBadge = Font(rightCard, 9.6, TC.violet, "BOLD")
    previewBadge:SetJustifyH("RIGHT")
    SetPoint(previewBadge, "TOPRIGHT", rightCard, "TOPRIGHT", -18, -14)

    local hudOpacity = CreateSlider(settingsCard, "HUD OPACITY", 0.40, 1.00, 0.05,
        function() return RA:GetDB().opacity end,
        function(value) RA:GetDB().opacity = value; ApplyVisualChange() end,
        function(value) return string.format("%d%%", math.floor(value * 100 + 0.5)) end)
    SetPoint(hudOpacity, "TOPLEFT", settingsCard, "TOPLEFT", 18, -541)
    SetWidth(hudOpacity, 402)

    local styleCard = CreateCard(parent, "PRESENTATION", "Control visual structure, category text, and behavior at the tile cap.")
    SetSize(styleCard, 500, 334)
    SetPoint(styleCard, "TOPRIGHT", parent, "TOPRIGHT", 0, -290)

    local sample = CreateButton(positionCard, "SHOW SAMPLE", 150, 32, function(self)
        local show = not rightCard:IsShown()
        rightCard:SetShown(show)
        styleCard:SetShown(not show)
        RA:SetVisualText(self.label, show and "HIDE SAMPLE" or "SHOW SAMPLE")
    end)
    SetPoint(sample, "BOTTOMRIGHT", positionCard, "BOTTOMRIGHT", -18, 18)
    local function HideSample()
        rightCard:Hide(); styleCard:Show(); RA:SetVisualText(sample.label, "SHOW SAMPLE")
    end
    parent:HookScript("OnHide", HideSample)
    RA.ConfigFrame:HookScript("OnHide", HideSample)

    local y = -64
    local mode = CreateSegmented(settingsCard, "HUD MODE", {
        {label = "COMPACT", value = "COMPACT"},
        {label = "DETAILED", value = "DETAILED"},
    }, function() return RA:GetDB().mode end, function(value)
        RA:SetMode(value)
        UpdatePreview()
    end)
    SetPoint(mode, "TOPLEFT", settingsCard, "TOPLEFT", 18, y)
    SetSize(mode, 402, 54)
    mode:Layout(402)
    y = y - 61

    local function SliderAt(label, min, max, step, getter, setter, formatter)
        local slider = CreateSlider(settingsCard, label, min, max, step, getter, function(value)
            setter(value)
            ApplyVisualChange()
        end, formatter)
        SetPoint(slider, "TOPLEFT", settingsCard, "TOPLEFT", 18, y)
        SetWidth(slider, 402)
        y = y - 52
        return slider
    end

    SliderAt("OVERALL SCALE", 0.75, 2.00, 0.05,
        function() return RA:GetDB().scale end,
        function(v) RA:GetDB().scale = v end,
        function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end)
    SliderAt("ICON SIZE", 20, 42, 1,
        function() return RA:GetDB().compact.iconSize end,
        function(v) RA:GetDB().compact.iconSize = v end,
        function(v) return string.format("%d px", v) end)
    SliderAt("PLAYER NAME CHARACTERS", 0, 8, 1,
        function() return RA:GetDB().compact.nameLength end,
        function(v) RA:GetDB().compact.nameLength = v end,
        function(v) return v == 0 and "HIDDEN" or tostring(v) end)
    SliderAt("PLAYER NAME SIZE", 6, 13, 0.5,
        function() return RA:GetDB().compact.nameFontSize end,
        function(v) RA:GetDB().compact.nameFontSize = v end,
        function(v) return string.format("%.1f", v) end)
    SliderAt("TILE SPACING", 0, 10, 1,
        function() return RA:GetDB().compact.tileGap end,
        function(v) RA:GetDB().compact.tileGap = v end)
    SliderAt("WRAPPED ROW SPACING", 0, 10, 1,
        function() return RA:GetDB().compact.rowGap end,
        function(v) RA:GetDB().compact.rowGap = v end)
    SliderAt("CATEGORY SPACING", 0, 16, 1,
        function() return RA:GetDB().compact.categoryGap end,
        function(v) RA:GetDB().compact.categoryGap = v end)
    SliderAt("TILE CAP / WRAP POINT", 3, 14, 1,
        function() return RA:GetDB().compact.wrapAfter end,
        function(v) RA:GetDB().compact.wrapAfter = v end,
        function(v) return tostring(v) .. " TILES" end)

    local hudDirection = CreateSegmented(positionCard, "HUD GROWTH DIRECTION", {
        {label = "AUTO", value = "AUTO"},
        {label = "RIGHT", value = "RIGHT"},
        {label = "LEFT", value = "LEFT"},
        {label = "DOWN", value = "DOWN"},
        {label = "UP", value = "UP"},
    }, function() return RA:GetDB().hudDirection or "AUTO" end, function(value)
        RA:GetDB().hudDirection = value
        ApplyVisualChange()
    end)
    SetPoint(hudDirection, "TOPLEFT", positionCard, "TOPLEFT", 18, -64)
    SetSize(hudDirection, 464, 54)
    hudDirection:Layout(464)
    local positionHelp = Font(positionCard, 9.3, TC.textSoft, "REGULAR")
    RA:SetVisualText(positionHelp, "Unlock below, then drag the HUD grip.\nRecenter resets only the HUD position.")
    SetWidth(positionHelp, 300)
    SetPoint(positionHelp, "TOPLEFT", positionCard, "TOPLEFT", 18, -134)
    local recenter=CreateButton(positionCard,"RECENTER HUD",144,28,function()RA:RecoverHUD();RefreshConfig()end)
    SetPoint(recenter,"TOPLEFT",positionCard,"TOPLEFT",18,-174)
    local lock=CreateButton(positionCard,"LOCK HUD",144,28,function()RA:SetLocked(not RA:GetDB().locked);RefreshConfig()end)
    SetPoint(lock,"LEFT",recenter,"RIGHT",10,0)
    lock.Refresh=function(self)
        RA:SetVisualText(self.label,RA:GetDB().locked and "UNLOCK HUD" or "LOCK HUD")
        self:SetSelected(RA:GetDB().locked)
    end
    RegisterControl(lock)

    local background = CreateSegmented(styleCard, "BACKGROUND STYLE", {
        {label = "NONE", value = "NONE"},
        {label = "ICONS", value = "ICONS"},
        {label = "TILES", value = "TILES"},
        {label = "RIBBONS", value = "RIBBONS"},
        {label = "PANEL", value = "PANEL"},
    }, function() return RA:GetDB().compact.backgroundStyle end, function(value)
        RA:GetDB().compact.backgroundStyle = value
        ApplyVisualChange()
    end)
    SetPoint(background, "TOPLEFT", styleCard, "TOPLEFT", 18, -62)
    SetSize(background, 464, 54)
    background:Layout(464)

    local labels = CreateSegmented(styleCard, "CATEGORY LABELS", {
        {label = "HIDDEN", value = "HIDDEN"},
        {label = "SHORT", value = "SHORT"},
        {label = "FULL", value = "FULL"},
    }, function() return RA:GetDB().compact.categoryLabels end, function(value)
        RA:GetDB().compact.categoryLabels = value
        ApplyVisualChange()
    end)
    SetPoint(labels, "TOPLEFT", styleCard, "TOPLEFT", 18, -120)
    SetSize(labels, 464, 54)
    labels:Layout(464)

    local accent = CreateSegmented(styleCard, "ACCENT GRADIENT", {
        {label = "SUNSET", value = "SUNSET"},
        {label = "CRIMSON", value = "CRIMSON"},
        {label = "BERRY", value = "BERRY"},
    }, function() return RA:GetDB().accentPreset or "SUNSET" end, function(value)
        RA:GetDB().accentPreset = value
        Theme:SetAccentPreset(value)
        ApplyVisualChange()
    end)
    SetPoint(accent, "TOPLEFT", styleCard, "TOPLEFT", 18, -174)
    SetSize(accent, 464, 54)
    accent:Layout(464)

    local overflow = CreateSegmented(styleCard, "AT THE TILE CAP", {
        {label = "WRAP TO NEXT ROW", value = "WRAP"},
        {label = "HIDE EXTRA TILES", value = "LIMIT"},
    }, function() return RA:GetDB().compact.overflowMode end, function(value)
        RA:GetDB().compact.overflowMode = value
        ApplyVisualChange()
    end)
    SetPoint(overflow, "TOPLEFT", styleCard, "TOPLEFT", 18, -230)
    SetSize(overflow, 464, 54)
    overflow:Layout(464)

    local empty = CreateToggle(styleCard, "Show empty-state tile", "Show a small placeholder only when no tools or scan strip are visible.",
        function() return RA:GetDB().compact.showEmptyState == true end,
        function(value) RA:GetDB().compact.showEmptyState = value; ApplyVisualChange() end)
    SetPoint(empty, "TOPLEFT", styleCard, "TOPLEFT", 18, -284)
    SetWidth(empty, 464)
end

local function RefreshCategoryRows()
    local db = RA:GetDB()
    for i = 1, #categoryRows do
        local entry = categoryRows[i]
        local selected = entry.category.key == selectedCategory
        local enabled = db.categories[entry.category.key] ~= false

        -- Reapply the actual text on every refresh. This also repairs category
        -- labels after font/media changes and prevents an empty cached string.
        RA:SetVisualText(entry.label, entry.category.shortName or entry.category.name or entry.category.key)
        entry.label:SetTextColor(unpack(selected and TC.white or TC.textSoft))
        SetSurfaceColor(entry.frame, selected and TC.activeDark or TC.surfaceRaised)
        SetBorderColor(entry.frame, selected and CopyColor(TC.magenta, 0.36) or TC.line)
        entry.gradient:SetAlpha(selected and 0.58 or 0)
        entry.icon:SetVertexColor(unpack(selected and TC.white or TC.muted))
        entry.check:SetColorTexture(unpack(enabled and TC.magenta or CopyColor(TC.muted, 0.35)))
    end
end

local function RefreshAbilityList(resetScroll)
    if not contentScrollChild then
        return
    end

    for i = 1, #abilityRows do
        abilityRows[i]:Hide()
    end

    local normalizedSearch = string.lower(searchText or "")
    local ordered = RA.GetOrderedAbilities and RA:GetOrderedAbilities(selectedCategory) or RA.Catalog
    local visible = {}
    for i = 1, #ordered do
        local ability = ordered[i]
        if ability.category == selectedCategory then
            local name = string.lower(RA:GetAbilityName(ability) or ability.name)
            if normalizedSearch == "" or string.find(name, normalizedSearch, 1, true) then
                visible[#visible + 1] = ability
            end
        end
    end

    for index = 1, #visible do
        local ability = visible[index]
        local row = abilityRows[index]
        if not row then
            row = CreateFrame("Button", nil, contentScrollChild, "BackdropTemplate")
            SetSize(row, 642, 54)
            Backdrop(row, TC.surfaceRaised, TC.line, 10, false)

            row.checkBack = CreateFrame("Frame", nil, row, "BackdropTemplate")
            SetSize(row.checkBack, 20, 20)
            SetPoint(row.checkBack, "LEFT", row, "LEFT", 11, 0)
            Backdrop(row.checkBack, TC.input, TC.line, 6, false)
            row.check = row.checkBack:CreateTexture(nil, "ARTWORK")
            SetSize(row.check, 11, 11)
            SetPoint(row.check, "CENTER", row.checkBack, "CENTER", 0, 0)

            row.iconFrame = CreateFrame("Frame", nil, row, "BackdropTemplate")
            SetSize(row.iconFrame, 34, 34)
            SetPoint(row.iconFrame, "LEFT", row.checkBack, "RIGHT", 10, 0)
            Backdrop(row.iconFrame, TC.canvasDeep, CopyColor(TC.textSoft, 0.20), 8, false)
            row.icon = row.iconFrame:CreateTexture(nil, "ARTWORK")
            row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            SetPoint(row.icon, "TOPLEFT", row.iconFrame, "TOPLEFT", 2, -2)
            SetPoint(row.icon, "BOTTOMRIGHT", row.iconFrame, "BOTTOMRIGHT", -2, 2)
            ApplyIconMask(row.icon, row.iconFrame)
            row.iconFrame:EnableMouse(true)
            row.iconFrame:SetScript("OnEnter", function(self)
                local ability = self:GetParent().ability
                if not ability or not (RA:GetDB().content and RA:GetDB().content.showTooltips ~= false) then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(ability.spellID) else GameTooltip:SetText(RA:GetAbilityName(ability), 1, 1, 1) end
                GameTooltip:Show()
            end)
            row.iconFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

            row.name = Font(row, 11.8, TC.text, "BOLD")
            SetPoint(row.name, "TOPLEFT", row.iconFrame, "TOPRIGHT", 11, -2)
            row.name:SetWordWrap(false)

            row.meta = Font(row, 9.0, TC.textSoft, "REGULAR")
            SetPoint(row.meta, "BOTTOMLEFT", row.iconFrame, "BOTTOMRIGHT", 11, 2)
            row.meta:SetWordWrap(false)

            row.down = CreateIconButton(row, Theme.Assets.ChevronDown, "Move down", function(self)
                if self:GetParent().ability and RA.MoveAbility then
                    RA:MoveAbility(selectedCategory, self:GetParent().ability.key, 1)
                    RefreshAbilityList(false)
                end
            end)
            SetPoint(row.down, "RIGHT", row, "RIGHT", -9, 0)

            row.up = CreateIconButton(row, Theme.Assets.ChevronUp, "Move up", function(self)
                if self:GetParent().ability and RA.MoveAbility then
                    RA:MoveAbility(selectedCategory, self:GetParent().ability.key, -1)
                    RefreshAbilityList(false)
                end
            end)
            SetPoint(row.up, "RIGHT", row.down, "LEFT", -6, 0)

            row.tierBack = CreateFrame("Frame", nil, row, "BackdropTemplate")
            SetSize(row.tierBack, 72, 23)
            SetPoint(row.tierBack, "RIGHT", row.up, "LEFT", -9, 0)
            Backdrop(row.tierBack, TC.input, TC.line, 7, false)
            row.tier = Font(row.tierBack, 8.3, TC.textSoft, "BOLD")
            row.tier:SetJustifyH("CENTER")
            SetPoint(row.tier, "CENTER", row.tierBack, "CENTER", 0, 0)

            SetPoint(row.name, "RIGHT", row.tierBack, "LEFT", -11, 0)
            SetPoint(row.meta, "RIGHT", row.tierBack, "LEFT", -11, 0)

            row:SetScript("OnEnter", function(self)
                SetSurfaceColor(self, TC.surfaceHover)
            end)
            row:SetScript("OnLeave", function(self)
                SetSurfaceColor(self, TC.surfaceRaised)
            end)
            row:SetScript("OnClick", function(self, button)
                if button ~= "LeftButton" then return end
                local current = AbilitySetting(self.ability)
                RA:GetDB().abilities[self.ability.key] = not current
                RefreshAbilityList(false)
                RA:OnCapabilityFiltersChanged()
            end)
            row:RegisterForClicks("LeftButtonUp")
            abilityRows[index] = row
        end

        row.ability = ability
        row:ClearAllPoints()
        SetPoint(row, "TOPLEFT", contentScrollChild, "TOPLEFT", 0, -((index - 1) * 59))
        row.icon:SetTexture(RA:GetAbilityTexture(ability))
        RA:SetVisualText(row.name, RA:GetAbilityName(ability))
        local classLabel = ability.class and string.gsub(ability.class, "_", " ") or "MULTIPLE CLASSES"
        local cooldown = RA.GetCooldownLabel and RA:GetCooldownLabel(ability) or ""
        RA:SetVisualText(row.meta, cooldown ~= "" and (classLabel .. "  ·  " .. cooldown .. " cooldown") or classLabel)
        local enabled = AbilitySetting(ability)
        SetSurfaceColor(row.checkBack, enabled and TC.activeDark or TC.input)
        SetBorderColor(row.checkBack, enabled and CopyColor(TC.magenta, 0.40) or TC.line)
        row.check:SetColorTexture(unpack(enabled and TC.magenta or CopyColor(TC.muted, 0.35)))
        if row.icon.SetDesaturated then row.icon:SetDesaturated(not enabled) end
        row.icon:SetAlpha(enabled and 1 or 0.45)
        row.name:SetTextColor(unpack(enabled and TC.text or TC.muted))
        row.meta:SetTextColor(unpack(enabled and TC.textSoft or TC.faint))

        RA:SetVisualText(row.tier, ability.tier or "OPTIONAL")
        local tierColor = TIER_COLORS[ability.tier] or TC.textSoft
        row.tier:SetTextColor(unpack(tierColor))
        SetBorderColor(row.tierBack, CopyColor(tierColor, 0.35))
        local canMoveUp = index > 1
        local canMoveDown = index < #visible
        row.up:SetAlpha(canMoveUp and 1 or 0.30)
        row.down:SetAlpha(canMoveDown and 1 or 0.30)
        row.up:EnableMouse(canMoveUp)
        row.down:EnableMouse(canMoveDown)
        row:Show()
    end

    SetHeight(contentScrollChild, math.max(468, #visible * 59))
    if resetScroll and contentScroll then
        contentScroll:SetVerticalScroll(0)
    end
    RefreshCategoryRows()
end

local function CreateContentPane(parent)
    CreateHeading(parent, "Categories", "Choose which provider abilities appear and arrange their callout order.")

    local categoryCard = CreateCard(parent, "CATEGORIES", "Select a category. Its checkbox controls visibility.")
    SetSize(categoryCard, 228, 598)
    SetPoint(categoryCard, "TOPLEFT", parent, "TOPLEFT", 0, -62)

    for i = 1, #RA.Categories do
        local category = RA.Categories[i]
        local row = CreateFrame("Button", nil, categoryCard, "BackdropTemplate")
        SetSize(row, 192, 54)
        SetPoint(row, "TOPLEFT", categoryCard, "TOPLEFT", 18, -64 - ((i - 1) * 62))
        Backdrop(row, TC.surfaceRaised, TC.line, 10, false)
        row.gradient = CreateGradientOverlay(row, Theme.Assets.GradientSunset, 0, 2)
        row:RegisterForClicks("LeftButtonUp")

        local iconAsset = Theme.Assets.NavContent
        local icon = Theme:CreateIcon(row, iconAsset, 18, TC.muted)
        SetPoint(icon, "LEFT", row, "LEFT", 12, 0)

        local checkBack = CreateFrame("Button", nil, row, "BackdropTemplate")
        SetSize(checkBack, 18, 18)
        SetPoint(checkBack, "RIGHT", row, "RIGHT", -11, 0)
        Backdrop(checkBack, TC.input, TC.line, 5, false)
        local check = checkBack:CreateTexture(nil, "ARTWORK")
        SetSize(check, 10, 10)
        SetPoint(check, "CENTER", checkBack, "CENTER", 0, 0)

        local label = Font(row, 11.2, TC.textSoft, "BOLD")
        RA:SetVisualText(label, category.shortName or category.name or category.key)
        label:SetWordWrap(true)
        label:SetJustifyH("LEFT")
        SetPoint(label, "LEFT", icon, "RIGHT", 10, 0)
        SetPoint(label, "RIGHT", checkBack, "LEFT", -9, 0)
        SetHeight(label, 22)

        row:SetScript("OnEnter", function(self)
            if selectedCategory ~= category.key then
                SetSurfaceColor(self, TC.surfaceHover)
            end
        end)
        row:SetScript("OnLeave", function(self)
            RefreshCategoryRows()
        end)
        row:SetScript("OnClick", function()
            selectedCategory = category.key
            RefreshAbilityList(true)
            RefreshCategoryRows()
        end)
        checkBack:SetScript("OnClick", function()
            RA:GetDB().categories[category.key] = not (RA:GetDB().categories[category.key] ~= false)
            RA:OnCapabilityFiltersChanged()
            RefreshCategoryRows()
        end)
        categoryRows[i] = {frame = row, category = category, check = check, label = label, gradient = row.gradient, icon = icon}
    end

    local tooltipToggle = CreateToggle(categoryCard, "Spell icon tooltips", "Show the native spell tooltip when an ability icon is hovered.",
        function() return not RA:GetDB().content or RA:GetDB().content.showTooltips ~= false end,
        function(value)
            RA:GetDB().content = RA:GetDB().content or {}
            RA:GetDB().content.showTooltips = value
        end)
    SetPoint(tooltipToggle, "BOTTOMLEFT", categoryCard, "BOTTOMLEFT", 18, 16)
    SetWidth(tooltipToggle, 192)
    SetHeight(tooltipToggle, 92)

    local listCard = CreateCard(parent, "ABILITIES", "Core abilities lead by default; within each tier, longer cooldowns appear first.", Theme.Assets.GradientBerry)
    SetSize(listCard, 708, 598)
    SetPoint(listCard, "TOPRIGHT", parent, "TOPRIGHT", 0, -62)

    local search = CreateFrame("EditBox", nil, listCard, "BackdropTemplate")
    SetSize(search, 220, 34)
    SetPoint(search, "TOPLEFT", listCard, "TOPLEFT", 18, -62)
    Backdrop(search, TC.input, TC.line, 9, false)
    ApplyReadableFont(search, 10.8, "REGULAR")
    search:SetTextColor(unpack(TC.text))
    search:SetAutoFocus(false)
    search:SetTextInsets(12, 12, 0, 0)
    search.instructions = Font(search, 9.4, TC.muted, "REGULAR")
    RA:SetVisualText(search.instructions, "Search abilities")
    SetPoint(search.instructions, "LEFT", search, "LEFT", 12, 0)
    search:SetScript("OnTextChanged", function(self)
        searchText = self:GetText() or ""
        self.instructions:SetShown(searchText == "" and not self:HasFocus())
        RefreshAbilityList(true)
    end)
    search:SetScript("OnEditFocusGained", function(self) self.instructions:Hide() end)
    search:SetScript("OnEditFocusLost", function(self) self.instructions:SetShown((self:GetText() or "") == "") end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local recommended = CreateButton(listCard, "RECOMMENDED", 112, 34, function()
        RA:ResetAbilityVisibilityToRecommended(selectedCategory)
        RefreshAbilityList(false)
    end, true)
    SetPoint(recommended, "TOPLEFT", listCard, "TOPLEFT", 18, -104)

    local allOn = CreateButton(listCard, "ALL ON", 72, 34, function()
        for i = 1, #RA.Catalog do
            local ability = RA.Catalog[i]
            if ability.category == selectedCategory then RA:GetDB().abilities[ability.key] = true end
        end
        RefreshAbilityList(false)
        RA:OnCapabilityFiltersChanged()
    end)
    SetPoint(allOn, "LEFT", recommended, "RIGHT", 8, 0)

    local allOff = CreateButton(listCard, "ALL OFF", 72, 34, function()
        for i = 1, #RA.Catalog do
            local ability = RA.Catalog[i]
            if ability.category == selectedCategory then RA:GetDB().abilities[ability.key] = false end
        end
        RefreshAbilityList(false)
        RA:OnCapabilityFiltersChanged()
    end)
    SetPoint(allOff, "LEFT", allOn, "RIGHT", 8, 0)

    local defaultOrder = CreateButton(listCard, "DEFAULT ORDER", 124, 34, function()
        if RA.ResetAbilityOrder then RA:ResetAbilityOrder(selectedCategory) end
        RefreshAbilityList(true)
    end)
    SetPoint(defaultOrder, "LEFT", allOff, "RIGHT", 8, 0)

    contentScroll = CreateFrame("ScrollFrame", nil, listCard, "UIPanelScrollFrameTemplate")
    SetPoint(contentScroll, "TOPLEFT", listCard, "TOPLEFT", 18, -150)
    SetPoint(contentScroll, "BOTTOMRIGHT", listCard, "BOTTOMRIGHT", -36, 18)
    contentScrollChild = CreateFrame("Frame", nil, contentScroll)
    SetWidth(contentScrollChild, 646)
    SetHeight(contentScrollChild, 468)
    contentScroll:SetScrollChild(contentScrollChild)
end

local function ScanStatusText()
    local inspected, total, isDemo = RA:GetVerificationStatus()
    local processed, scanTotal, _, running, currentName, paused = RA:GetInspectionProgress()
    local summary = RA:GetScanSummary()
    local db = RA:GetDB()
    if isDemo then
        if db.scan and db.scan.demoPreview then
            return "13 / 20 SCANNING", "Simulated pending-player strip and progress animation are active on the demo HUD."
        end
        return "DEMO DATA", "Enable the scan preview below to test the 13/20 pending-player experience."
    end
    if paused then
        return string.format("%d / %d RESOLVED", inspected, total), "Paused after the current inspection. " .. RA:FormatInspectionEvidenceSummary(summary)
    elseif running then
        return string.format("%d / %d SCANNING", processed, scanTotal), currentName and ("Inspecting " .. RA:GetShortName(currentName)) or "Inspecting the next nearby player."
    end
    local details = {}
    details[#details + 1] = RA:FormatInspectionEvidenceSummary(summary)
    if summary.filtered > 0 then details[#details + 1] = summary.filtered .. " class-skipped" end
    if summary.ignored > 0 then details[#details + 1] = summary.ignored .. " ignored" end
    if summary.outOfRange > 0 then details[#details + 1] = summary.outOfRange .. " out of range" end
    if summary.offline > 0 then details[#details + 1] = summary.offline .. " offline" end
    if summary.failed > 0 then details[#details + 1] = summary.failed .. " failed" end
    return string.format("%d / %d RESOLVED", inspected, total), table.concat(details, "  ·  ")
end

local function ScanStripStatusText()
    if not RA:IsInspectionEnabled() then return "Inspection off" end
    if RA.InEncounter then return "Hidden during encounter" end
    local _, _, _, running, _, paused = RA:GetInspectionProgress()
    local pending = RA:GetPendingScanEntries()
    if #pending == 0 and not running then return "No work pending" end
    if paused then return "Paused" end
    if running then return "Scanning" end
    local summary = RA:GetScanSummary()
    if (summary.outOfRange or 0) > 0 then return "Waiting for range" end
    return "Waiting for pending players"
end

local function RefreshScanPane()
    if not scanStatusValue then
        return
    end
    local primary, secondary = ScanStatusText()
    RA:SetVisualText(scanStatusValue, primary)
    if scanStatusDetail then
        RA:SetVisualText(scanStatusDetail, secondary or "")
    end
    if scanStatusPill then
        scanStatusPill.tooltipText = secondary
    end
    if scanStripState then RA:SetVisualText(scanStripState, ScanStripStatusText()) end

    local inspected, total, isDemo = RA:GetVerificationStatus()
    local _, _, _, running, _, paused = RA:GetInspectionProgress()
    if isDemo then
        RA:SetVisualText(scanPrimaryButton.label, "SCAN MISSING")
    elseif paused then
        RA:SetVisualText(scanPrimaryButton.label, "RESUME SCAN")
    elseif running then
        RA:SetVisualText(scanPrimaryButton.label, "PAUSE SCAN")
    elseif inspected < total then
        RA:SetVisualText(scanPrimaryButton.label, "RETRY MISSING")
    else
        RA:SetVisualText(scanPrimaryButton.label, "SCAN MISSING")
    end
    scanPrimaryButton:SetEnabled(RA:IsInspectionEnabled())
    scanPrimaryButton:SetAlpha(RA:IsInspectionEnabled() and 1 or 0.45)
end

local function CreateScanningPane(parent)
    CreateHeading(parent, "Scanning", "C marks saved talents. The master above enables inspection; viewing settings does not.")

    scanStatusPill = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    SetSize(scanStatusPill, 220, 36)
    SetPoint(scanStatusPill, "TOPRIGHT", parent, "TOPRIGHT", 0, -4)
    Backdrop(scanStatusPill, TC.activeDark, CopyColor(TC.magenta, 0.30), 11, false)
    scanStatusPill.gradient = CreateGradientOverlay(scanStatusPill, Theme.Assets.GradientSunset, 0.42, 2)
    scanStatusValue = Font(scanStatusPill, 10.4, TC.white, "BOLD")
    scanStatusValue:SetJustifyH("CENTER")
    SetPoint(scanStatusValue, "CENTER", scanStatusPill, "CENTER", 0, 0)
    scanStatusPill:EnableMouse(true)
    scanStatusPill:SetScript("OnEnter", function(self)
        if self.tooltipText and self.tooltipText ~= "" then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(self.tooltipText, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    scanStatusPill:SetScript("OnLeave", function() GameTooltip:Hide() end)

    scanStatusDetail = Font(parent, 9.0, TC.textSoft, "REGULAR")
    RA:SetVisualText(scanStatusDetail, "Only new, moved-in, or unresolved players enter the queue.")
    SetPoint(scanStatusDetail, "TOPRIGHT", scanStatusPill, "BOTTOMRIGHT", 0, -6)
    scanStatusDetail:SetJustifyH("RIGHT")

    local displayCard = CreateCard(parent, "SCAN OVERLAY", "The pending-player strip disappears automatically when everyone is resolved.")
    SetSize(displayCard, 456, 430)
    SetPoint(displayCard, "TOPLEFT", parent, "TOPLEFT", 0, -62)

    local showStrip = CreateToggle(displayCard, "Show pending-player strip", "Shows class, role, range state, and the current scan target.",
        function() return RA:GetDB().scan.showStrip ~= false end,
        function(value) RA:GetDB().scan.showStrip = value; ApplyVisualChange() end)
    SetPoint(showStrip, "TOPLEFT", displayCard, "TOPLEFT", 18, -62)
    SetWidth(showStrip, 420)

    scanStripState = Font(displayCard, 9.4, TC.orange, "BOLD")
    SetPoint(scanStripState, "TOPLEFT", displayCard, "TOPLEFT", 20, -378)
    SetWidth(scanStripState, 416)

    local demoScan = CreateToggle(displayCard, "Demo the scanning state", "While Demo is on, show a simulated 13/20 progress bar and animated target.",
        function() return RA:GetDB().scan.demoPreview == true end,
        function(value)
            RA:GetDB().scan.demoPreview = value
            ApplyVisualChange()
            RefreshScanPane()
        end)
    SetPoint(demoScan, "TOPLEFT", displayCard, "TOPLEFT", 18, -304)
    SetWidth(demoScan, 420)
    demoScan:Hide()
    local advancedDemo = CreateButton(displayCard, "ADVANCED: DEMO", 210, 32, function(self)
        demoScan:SetShown(not demoScan:IsShown())
        RA:SetVisualText(self.label, demoScan:IsShown() and "HIDE DEMO OPTIONS" or "ADVANCED: DEMO")
    end)
    SetPoint(advancedDemo, "TOPLEFT", displayCard, "TOPLEFT", 18, -258)
    local function HideDemoOptions() demoScan:Hide(); RA:SetVisualText(advancedDemo.label, "ADVANCED: DEMO") end
    parent:HookScript("OnHide", HideDemoOptions)
    RA.ConfigFrame:HookScript("OnHide", HideDemoOptions)

    local scanScale = CreateSlider(displayCard, "SCAN STRIP SCALE", 0.75, 2.00, 0.05,
        function() return RA:GetDB().scan.scale end,
        function(value) RA:GetDB().scan.scale = value; ApplyVisualChange() end,
        function(value) return string.format("%d%%", math.floor(value * 100 + 0.5)) end)
    SetPoint(scanScale, "TOPLEFT", displayCard, "TOPLEFT", 18, -118)
    SetWidth(scanScale, 420)

    local scanWrap = CreateSlider(displayCard, "PENDING PLAYERS PER ROW", 4, 14, 1,
        function() return RA:GetDB().scan.wrapAfter end,
        function(value) RA:GetDB().scan.wrapAfter = value; ApplyVisualChange() end)
    SetPoint(scanWrap, "TOPLEFT", displayCard, "TOPLEFT", 18, -188)
    SetWidth(scanWrap, 420)

    local groupsCard = CreateCard(parent, "TRACKED RAID GROUPS", "Gradient groups are tracked. Groups 7 and 8 default to bench and are ignored.")
    SetSize(groupsCard, 476, 430)
    SetPoint(groupsCard, "TOPRIGHT", parent, "TOPRIGHT", 0, -62)
    groupsCard.groupButtons = {}

    for group = 1, 8 do
        local button = CreateFrame("Button", nil, groupsCard, "BackdropTemplate")
        SetSize(button, 101, 78)
        local column = (group - 1) % 4
        local row = math.floor((group - 1) / 4)
        SetPoint(button, "TOPLEFT", groupsCard, "TOPLEFT", 18 + column * 111, -78 - row * 96)
        Backdrop(button, TC.surfaceRaised, TC.line, 12, false)
        button.gradient = CreateGradientOverlay(button, Theme.Assets.GradientSunset, 0, 2)

        button.number = Font(button, 18, TC.text, "BOLD")
        RA:SetVisualText(button.number, tostring(group))
        button.number:SetJustifyH("CENTER")
        SetPoint(button.number, "TOP", button, "TOP", 0, -12)
        button.state = Font(button, 8.0, TC.textSoft, "BOLD")
        button.state:SetJustifyH("CENTER")
        SetPoint(button.state, "BOTTOM", button, "BOTTOM", 0, 10)
        button:SetScript("OnClick", function()
            local db = RA:GetDB()
            db.ignoredRaidGroups[group] = not db.ignoredRaidGroups[group]
            RA:OnIgnoredRaidGroupsChanged()
            RefreshScanPane()
            for g = 1, #groupsCard.groupButtons do groupsCard.groupButtons[g]:Refresh() end
        end)
        function button:Refresh()
            local ignored = RA:GetDB().ignoredRaidGroups[group] == true
            SetSurfaceColor(self, ignored and TC.input or TC.activeDark)
            SetBorderColor(self, ignored and TC.line or CopyColor(TC.magenta, 0.36))
            self.gradient:SetAlpha(ignored and 0 or 0.64)
            self.number:SetTextColor(unpack(ignored and TC.muted or TC.white))
            RA:SetVisualText(self.state, ignored and "IGNORED" or "TRACKED")
            self.state:SetTextColor(unpack(ignored and TC.faint or TC.orange))
        end
        groupsCard.groupButtons[group] = button
        RegisterControl(button)
    end

    local actionsCard = CreateCard(parent, "SCAN CONTROLS", "A full rescan is only needed after someone changes talents without changing roster position.")
    SetSize(actionsCard, 950, 142)
    SetPoint(actionsCard, "BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)

    scanPrimaryButton = CreateButton(actionsCard, "SCAN MISSING", 170, 38, function()
        if not RA:IsInspectionEnabled() then return end
        local _, _, _, running, _, paused = RA:GetInspectionProgress()
        if paused then
            RA:SetInspectionPaused(false)
        elseif running then
            RA:SetInspectionPaused(true)
        else
            RA:SetInspectionPaused(false)
            RA:RequestInspectionScan("settings scan missing", false)
        end
        C_Timer.After(0.1, RefreshScanPane)
    end, true)
    SetPoint(scanPrimaryButton, "BOTTOMLEFT", actionsCard, "BOTTOMLEFT", 18, 20)

    local full = CreateButton(actionsCard, "FULL RESCAN", 150, 38, function()
        if not RA:IsInspectionEnabled() then return end
        RA:SetInspectionPaused(false)
        RA:RequestInspectionScan("settings full rescan", true)
        C_Timer.After(0.1, RefreshScanPane)
    end)
    SetPoint(full, "LEFT", scanPrimaryButton, "RIGHT", 10, 0)
    RegisterControl({owner = parent, Refresh = function()
        full:SetEnabled(RA:IsInspectionEnabled())
        full:SetAlpha(RA:IsInspectionEnabled() and 1 or 0.45)
    end})

    local clear = CreateButton(actionsCard, "CLEAR CACHE", 150, 38, function()
        RA:ClearInspectionCache()
        C_Timer.After(0.1, RefreshScanPane)
    end)
    SetPoint(clear, "LEFT", full, "RIGHT", 10, 0)
end

local function CreateSecureTestButton(parent, label, macroText, width)
    local button = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate,BackdropTemplate")
    SetSize(button, width or 190, 38)
    Backdrop(button, TC.activeDark, CopyColor(TC.magenta, 0.28), 9, false)
    button.gradient = CreateGradientOverlay(button, Theme.Assets.GradientSunset, 0.64, 2)
    button.label = Font(button, 10.4, TC.white, "BOLD")
    RA:SetVisualText(button.label, label)
    button.label:SetJustifyH("CENTER")
    SetPoint(button.label, "CENTER", button, "CENTER", 0, 0)
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:SetAttribute("type", "macro")
    button:SetAttribute("macrotext", macroText)
    button:SetAttribute("useOnKeyDown", GetCVarBool and GetCVarBool("ActionButtonUseKeyDown") or false)
    return button
end

local function CreateQuickBarPane(parent)
    CreateHeading(parent, "Quick Bar", "")

    local leftCard = CreateFrame("Frame",nil,parent)
    SetSize(leftCard,918,500);SetPoint(leftCard,"TOPLEFT",parent,"TOPLEFT",0,-62)
    local function Help(control,detail)
        control:EnableMouse(true)
        control:HookScript("OnEnter",function(owner)
            GameTooltip:SetOwner(owner,"ANCHOR_RIGHT");GameTooltip:SetText("Quick Bar")
            GameTooltip:AddLine(detail,0.76,0.80,0.86,true);GameTooltip:Show()
        end)
        control:HookScript("OnLeave",function()GameTooltip:Hide()end)
    end
    local toolboxToggle = CreateToggle(leftCard, "Quick Bar", "Independent raid dock. Privileged actions require lead or assist.",
        function() return RA:GetDB().leaderToolbox.enabled == true end,
        function(value)
            RA:SetQuickBarEnabled(value)
            if RA.RaidLeaderToolbox and RA.RaidLeaderToolbox.Refresh then RA.RaidLeaderToolbox:Refresh() end
        end)
    SetPoint(toolboxToggle, "TOPLEFT", leftCard, "TOPLEFT", 0, 0)
    SetWidth(toolboxToggle, 451)
    toolboxToggle:SetCompact(false)
    Help(toolboxToggle,"Independent raid dock. Privileged actions require leader or assistant permission.")

    local nonLeaderToggle = CreateToggle(leftCard, "Show when not Leader/Assist", "Also show the dock to ordinary raid members.",
        function() return RA:GetDB().leaderToolbox.showForNonLeaders ~= false end,
        function(value)
            RA:GetDB().leaderToolbox.showForNonLeaders = value
            if RA.RaidLeaderToolbox and RA.RaidLeaderToolbox.Refresh then RA.RaidLeaderToolbox:Refresh() end
        end)
    SetPoint(nonLeaderToggle, "TOPLEFT", leftCard, "TOPLEFT", 467, 0)
    SetWidth(nonLeaderToggle, 451)
    nonLeaderToggle:SetCompact(false)
    Help(nonLeaderToggle,"Also show the dock to ordinary raid members.")

    local missingToggle = CreateToggle(leftCard, "Missing provider classes", "Defaults on each time Quick Bar is enabled. You can turn it off here.",
        function() return RA:GetDB().leaderToolbox.showMissing ~= false end,
        function(value)
            RA:GetDB().leaderToolbox.showMissing = value
            if RA.RaidLeaderToolbox and RA.RaidLeaderToolbox.Refresh then RA.RaidLeaderToolbox:Refresh() end
        end)
    SetPoint(missingToggle, "TOPLEFT", leftCard, "TOPLEFT", 0, -52)
    SetWidth(missingToggle, 451)
    missingToggle:SetCompact(true)
    Help(missingToggle,"Defaults on each time Quick Bar is enabled. Checks provider classes, not active auras or cooldown availability.")

    local direction = CreateSegmented(leftCard, "FLYOUT DIRECTION", {
        {label = "AUTO", value = "AUTO"},
        {label = "RIGHT", value = "RIGHT"},
        {label = "LEFT", value = "LEFT"},
        {label = "DOWN", value = "DOWN"},
        {label = "UP", value = "UP"},
    }, function() return RA:GetDB().leaderToolbox.flyoutDirection or "AUTO" end, function(value)
        RA:GetDB().leaderToolbox.flyoutDirection = value
        if RA.RaidLeaderToolbox and RA.RaidLeaderToolbox.RefreshGeometry then RA.RaidLeaderToolbox:RefreshGeometry() end
    end)
    SetPoint(direction, "TOPLEFT", leftCard, "TOPLEFT", 467, -52)
    SetSize(direction, 451, 54)
    direction:Layout(451)

    local puckSize = CreateSlider(leftCard, "PUCK SIZE", 24, 44, 1,
        function() return RA:GetDB().leaderToolbox.puckSize or 30 end,
        function(value)
            RA:GetDB().leaderToolbox.puckSize = value
            if RA.RaidLeaderToolbox and RA.RaidLeaderToolbox.RefreshGeometry then RA.RaidLeaderToolbox:RefreshGeometry() end
        end,
        function(value) return string.format("%d px", value) end)
    SetPoint(puckSize, "TOPLEFT", leftCard, "TOPLEFT", 0, -120)
    SetWidth(puckSize, 451)

    local tooltipDelay = CreateSlider(leftCard, "TOOLTIP DELAY", 0.20, 2.50, 0.10,
        function() return RA:GetDB().leaderToolbox.tooltipDelay or 0.75 end,
        function(value) RA:GetDB().leaderToolbox.tooltipDelay = value end,
        function(value) return string.format("%.1f s", value) end)
    SetPoint(tooltipDelay, "TOPLEFT", leftCard, "TOPLEFT", 467, -120)
    SetWidth(tooltipDelay, 451)

    local closeDelay = CreateSlider(leftCard, "MOUSE-OUT CLOSE DELAY", 0.15, 3.00, 0.05,
        function() return RA:GetDB().leaderToolbox.closeDelay or 1.0 end,
        function(value) RA:GetDB().leaderToolbox.closeDelay = value end,
        function(value) return string.format("%.1f s", value) end)
    SetPoint(closeDelay, "TOPLEFT", leftCard, "TOPLEFT", 0, -184)
    SetWidth(closeDelay, 451)

    local countdownSeconds = CreateSlider(leftCard, "PUCK COUNTDOWN", 1, 60, 1,
        function() return RA:GetDB().leaderToolbox.countdownSeconds or 15 end,
        function(value) RA:GetDB().leaderToolbox.countdownSeconds = math.floor(value + 0.5) end,
        function(value) return string.format("%d s", value) end)
    SetPoint(countdownSeconds, "TOPLEFT", leftCard, "TOPLEFT", 467, -184)
    SetWidth(countdownSeconds, 451)

    local resetDock = CreateButton(leftCard, "RESET PUCK POSITION", 220, 40, function()
        if RA.RaidLeaderToolbox and RA.RaidLeaderToolbox.ResetPosition then RA.RaidLeaderToolbox:ResetPosition() end
    end)
    SetPoint(resetDock,"TOPLEFT",leftCard,"TOPLEFT",0,-260)
    Help(resetDock,"Resets only the Quick Bar puck. Outside combat, hold left mouse and drag the puck to move it. Dragging does not start a countdown.")
end

local function CreateWorldMarkersPane(parent)
    local markers = RA.WorldMarkers
    local selected
    local message = ""
    local slots, palette = {}, {}
    CreateHeading(parent, "World marker cycler", "Place ground markers at your cursor. These are not target icons.")

    local toggle = CreateToggle(parent, "Enable world marker cycler", "Off until you choose it. Bindings start unassigned; no extra overlay.",
        function() return markers:GetSettings().enabled end,
        function(value)
            local _, detail = markers:SetEnabled(value)
            message = detail or ""
        end)
    SetPoint(toggle, "TOPLEFT", parent, "TOPLEFT", 0, -62)
    SetWidth(toggle, 462)
    local radialToggle=CreateToggle(parent,"Hold marker wheel (optional)","Center uses your order. Outer marker: release to aim, then click ground.",
        function()return markers:GetSettings().radialEnabled==true end,
        function(value)local _,detail=markers:SetRadialEnabled(value);message=detail or "" end)
    SetPoint(radialToggle,"TOPRIGHT",parent,"TOPRIGHT",0,-62);SetWidth(radialToggle,472)
    radialToggle:HookScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Hold marker wheel · optional prototype")
        GameTooltip:AddLine(markers:GetModeHelp(),0.90,0.92,0.95,true)
        GameTooltip:AddLine("With markers in your order, a center release places the next one at the current cursor, even after a long hold. Right-click or Escape cancels instead.",0.76,0.80,0.86,true)
        GameTooltip:AddLine("Release mouse look before choosing. Releasing over an outer marker opens the ground-targeting reticle; left-click ground to place, or right-click/Escape to cancel. Blizzard checks permissions and valid terrain.",0.76,0.80,0.86,true)
        GameTooltip:AddLine("The optional wheel is experimental; test your keybind in game before a pull. Unsupported keys use the normal sequence; your saved wheel choice is kept.",0.95,0.68,0.36,true)
        GameTooltip:Show()
    end)
    radialToggle:HookScript("OnLeave",function()GameTooltip:Hide()end)

    local orderCard = CreateCard(parent, "MARKER ORDER", "Normal sequence: click to append; select a slot to edit. The optional wheel always offers all eight markers.")
    SetSize(orderCard, 950, 270)
    SetPoint(orderCard, "TOPLEFT", parent, "TOPLEFT", 0, -126)
    local empty = Font(orderCard, 11, TC.textSoft, "REGULAR")
    RA:SetVisualText(empty, "Add at least one marker to use the cycler.")
    SetPoint(empty, "TOPLEFT", orderCard, "TOPLEFT", 18, -166)
    local selection = Font(orderCard, 9.4, TC.textSoft, "REGULAR")
    SetPoint(selection, "BOTTOMLEFT", orderCard, "BOTTOMLEFT", 386, 28)
    SetWidth(selection, 540)

    local function CommitOrder(order)
        local _, detail = markers:SetOrder(order)
        message = detail or ""
        RefreshWorldMarkers()
    end
    local function CopyOrder()
        local result = {}
        for i, id in ipairs(markers:GetSettings().order) do result[i] = id end
        return result
    end
    local function AddTooltip(button, text)
        button:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(text, 1, 1, 1)
            GameTooltip:Show()
        end)
        button:HookScript("OnLeave", function() GameTooltip:Hide() end)
    end
    for id, definition in ipairs(markers.Definitions) do
        local markerID = id
        local add = CreateButton(orderCard, definition.name, 104, 58, function()
            local order = CopyOrder()
            for _, present in ipairs(order) do
                if present == markerID then message = "Already in sequence."; RefreshWorldMarkers(); return end
            end
            order[#order + 1] = markerID
            selected = #order
            CommitOrder(order)
        end)
        SetPoint(add, "TOPLEFT", orderCard, "TOPLEFT", 18 + (id - 1) * 114, -68)
        add.label:ClearAllPoints()
        ApplyReadableFont(add.label, 8.5, "REGULAR")
        SetPoint(add.label, "BOTTOM", add, "BOTTOM", 0, 6)
        local icon = add:CreateTexture(nil, "ARTWORK")
        icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. definition.icon)
        SetSize(icon, 28, 28)
        SetPoint(icon, "TOP", add, "TOP", 0, -4)
        AddTooltip(add, definition.name .. " — append to the ground-marker sequence")
        palette[id] = add

        local slot = CreateButton(orderCard, tostring(id), 104, 50, function()
            selected = markerID
            message = ""
            RefreshWorldMarkers()
        end)
        SetPoint(slot, "TOPLEFT", orderCard, "TOPLEFT", 18 + (id - 1) * 114, -148)
        slot.label:ClearAllPoints()
        SetPoint(slot.label, "LEFT", slot, "LEFT", 10, 0)
        slot.icon = slot:CreateTexture(nil, "ARTWORK")
        SetSize(slot.icon, 30, 30)
        SetPoint(slot.icon, "CENTER", slot, "CENTER", 9, 0)
        slot:HookScript("OnEnter", function(self)
            local worldID = markers:GetSettings().order[markerID]
            if worldID then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(markerID .. ". " .. markers.Definitions[worldID].name, 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        slot:HookScript("OnLeave", function() GameTooltip:Hide() end)
        slots[id] = slot
    end
    local function Move(delta)
        local order = CopyOrder()
        local target = selected and selected + delta
        if target and target >= 1 and target <= #order then
            order[selected], order[target] = order[target], order[selected]
            selected = target
            CommitOrder(order)
        end
    end
    local left = CreateButton(orderCard, "MOVE LEFT", 110, 32, function() Move(-1) end)
    SetPoint(left, "BOTTOMLEFT", orderCard, "BOTTOMLEFT", 18, 18)
    local right = CreateButton(orderCard, "MOVE RIGHT", 110, 32, function() Move(1) end)
    SetPoint(right, "LEFT", left, "RIGHT", 8, 0)
    local remove = CreateButton(orderCard, "REMOVE", 110, 32, function()
        local order = CopyOrder()
        if selected and order[selected] then
            table.remove(order, selected)
            selected = #order > 0 and math.min(selected, #order) or nil
            CommitOrder(order)
        end
    end)
    SetPoint(remove, "LEFT", right, "RIGHT", 8, 0)

    local bindingCard = CreateCard(parent, "KEY BINDINGS", "The same place key uses the normal sequence or your selected wheel mode. Clear all remains separate.")
    SetSize(bindingCard, 950, 194)
    SetPoint(bindingCard, "TOPLEFT", parent, "TOPLEFT", 0, -410)
    local bindings = RA.MarkerBindings
    local bindingRows = {}
    local editorOverlay, editorUnavailable, editorVisual, drainHint, editorTitle, editorInfo, editorPrompt, replaceKey
    local RefreshEditor
    local scopeText = Font(bindingCard, 9.2, TC.textSoft, "REGULAR")
    SetPoint(scopeText, "TOPRIGHT", bindingCard, "TOPRIGHT", -18, -20)
    SetWidth(scopeText, 250); scopeText:SetJustifyH("RIGHT")
    local bindingHelp = Font(bindingCard, 9.2, TC.textSoft, "REGULAR")
    bindingHelp:SetSpacing(4); bindingHelp:SetWordWrap(true)
    SetPoint(bindingHelp, "TOPLEFT", bindingCard, "TOPLEFT", 18, -146)
    SetWidth(bindingHelp, 744)
    local function CancelEditor()
        if bindings:GetPending() then bindings:Cancel("Binding cancelled.") end
        if RefreshEditor then RefreshEditor() end
    end
    local function CreateEditor()
        if editorUnavailable then return false end
        if editorOverlay then return true end
        editorOverlay = CreateFrame("Frame", "RCPArsenalMarkerBindingEditor", UIParent)
        local protectedOK, protected, explicitlyProtected = pcall(function() return editorOverlay:IsProtected() end)
        if type(issecretvalue) ~= "function" or not protectedOK or issecretvalue(protected) or issecretvalue(explicitlyProtected)
            or protected ~= false or explicitlyProtected ~= false then
            pcall(editorOverlay.Hide, editorOverlay)
            editorOverlay, editorUnavailable = nil, true; return false
        end
        editorOverlay:SetAllPoints(UIParent)
        editorOverlay:SetFrameStrata("FULLSCREEN_DIALOG")
        editorOverlay:SetFrameLevel(RA.ConfigFrame:GetFrameLevel() + 200)
        editorOverlay:Hide(); editorOverlay:EnableMouse(true)
        local ok = pcall(function()
            local combat = InCombatLockdown()
            if issecretvalue(combat) or combat ~= false then error("Capture setup requires out of combat.") end
            editorOverlay:EnableKeyboard(true)
            editorOverlay:EnableMouseWheel(true)
            editorOverlay:SetPropagateKeyboardInput(false)
            editorOverlay:SetPropagateMouseClicks(false)
            editorOverlay:SetPropagateMouseMotion(true)
        end)
        if not ok then editorOverlay, editorUnavailable = nil, true; return false end
        editorVisual = CreateFrame("Frame", nil, editorOverlay)
        editorVisual:SetAllPoints(RA.ConfigFrame)
        editorVisual:SetScale(RA.ConfigFrame:GetScale())
        drainHint = Font(editorOverlay, 14, TC.orange, "BOLD")
        SetPoint(drainHint, "CENTER", UIParent, "CENTER", 0, 0)
        SetWidth(drainHint, math.max(1, math.min(580, UIParent:GetWidth() - 32)))
        drainHint:SetJustifyH("CENTER"); drainHint:SetWordWrap(true); drainHint:Hide()
        local shade = editorVisual:CreateTexture(nil, "BACKGROUND")
        shade:SetAllPoints(); shade:SetColorTexture(0, 0, 0, 0.76)
        local dialog = CreateFrame("Frame", nil, editorVisual, "BackdropTemplate")
        SetSize(dialog, 580, 248); SetPoint(dialog, "CENTER", editorVisual, "CENTER", 0, 0)
        SetSurfaceColor(dialog, TC.surfaceRaised); SetBorderColor(dialog, TC.lineStrong)
        editorTitle = Font(dialog, 15, TC.text, "BOLD")
        SetPoint(editorTitle, "TOPLEFT", dialog, "TOPLEFT", 22, -22); SetWidth(editorTitle, 536)
        editorInfo = Font(dialog, 10, TC.textSoft, "REGULAR")
        SetPoint(editorInfo, "TOPLEFT", dialog, "TOPLEFT", 22, -54); SetWidth(editorInfo, 536)
        editorPrompt = Font(dialog, 11, TC.orange, "REGULAR")
        editorPrompt:SetWordWrap(true); editorPrompt:SetSpacing(5)
        SetPoint(editorPrompt, "TOPLEFT", dialog, "TOPLEFT", 22, -88); SetWidth(editorPrompt, 536)
        local hint = Font(dialog, 9.5, TC.textSoft, "REGULAR")
        RA:SetVisualText(hint, "Modifiers supported. Mouse buttons 3+ supported. Escape cancels.")
        SetPoint(hint, "BOTTOMLEFT", dialog, "BOTTOMLEFT", 22, 65); SetWidth(hint, 536)
        replaceKey = CreateButton(dialog, "REPLACE", 130, 32, function() bindings:Replace(); RefreshEditor() end)
        SetPoint(replaceKey, "BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -164, 20)
        local cancel = CreateButton(dialog, "CANCEL", 130, 32, CancelEditor)
        SetPoint(cancel, "BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -22, 20)
        -- All input/propagation flags were configured outside combat above.
        -- Never change restricted flags in an input/combat callback. A cancelled
        -- held gesture briefly drains input until its matching release; a clear
        -- visible hint explains this instead of claiming unrelated input passes.
        local function Press(_, input)
            local edit = bindings:GetPending()
            if edit and (not edit.conflict or input == "ESCAPE") then
                local _, detail = bindings:Capture(input); RefreshEditor(detail)
            end
        end
        local function Release(_, input) local _, detail = bindings:Release(input); RefreshEditor(detail) end
        editorOverlay:SetScript("OnKeyDown", Press); editorOverlay:SetScript("OnKeyUp", Release)
        editorOverlay:SetScript("OnMouseDown", Press); editorOverlay:SetScript("OnMouseUp", Release)
        editorOverlay:SetScript("OnMouseWheel", function() end) -- Consume; wheel editing remains in WoW keybinds.
        editorOverlay:SetScript("OnHide", function()
            if bindings:GetPending() then bindings:Cancel("Binding cancelled.") end
        end)
        return true
    end
    RefreshEditor = function(detail)
        if not editorOverlay then return end
        SetWidth(drainHint, math.max(1, math.min(580, UIParent:GetWidth() - 32)))
        local edit = bindings:GetPending()
        if not edit then
            editorVisual:Hide()
            -- Own ordinary input frame survives host/tab/combat cancellation
            -- only through the held release. No deferred binding write exists.
            local held = bindings:GetHeldKey()
            RA:SetVisualText(drainHint, held and ("Release " .. held .. " to finish cancelling. If needed, tap " .. held .. " again.") or "")
            drainHint:SetShown(held ~= nil)
            editorOverlay:SetShown(held ~= nil)
            return
        end
        -- Config refits on every reopen. Only the visual follows its scale;
        -- the preconfigured UIParent input guard is never scaled/reconfigured.
        editorVisual:SetScale(RA.ConfigFrame:GetScale())
        drainHint:Hide(); editorVisual:Show()
        RA:SetVisualText(editorTitle, "Bind " .. edit.label)
        RA:SetVisualText(editorInfo, (edit.slot == 1 and "Primary" or "Alternate") .. " slot: " .. (edit.currentKey or "Unbound") .. " - " .. edit.scopeLabel)
        local prompt = detail or bindings:GetStatusText()
        if edit.awaitingRelease then prompt = "Release the captured key to continue."
        elseif edit.conflict then prompt = edit.proposedKey .. " is assigned to " .. edit.conflictLabel .. ". Replace it?" end
        RA:SetVisualText(editorPrompt, prompt:gsub("|", "||"))
        replaceKey:SetShown(edit.conflict and not edit.awaitingRelease)
    end
    local function EditKey(action, slot)
        local ok, detail = bindings:Begin(action, slot)
        if not ok then message = detail; RefreshWorldMarkers(); return end
        if not CreateEditor() then
            bindings:Cancel("Key capture unavailable; use WoW keybinds."); RefreshWorldMarkers(); return
        end
        RefreshEditor(); editorOverlay:Show()
    end
    for row, action in ipairs({markers.PlaceBinding, markers.ClearBinding}) do
        local actionLabel = row == 1 and "Place next world marker" or "Clear all world markers"
        local label = Font(bindingCard, 11, TC.text, "BOLD")
        RA:SetVisualText(label, actionLabel)
        SetPoint(label, "TOPLEFT", bindingCard, "TOPLEFT", 18, -(68 + (row - 1) * 36)); SetWidth(label, 264)
        for slot = 1, 2 do
            local bindingAction, bindingSlot = action, slot
            local key = CreateButton(bindingCard, "Unbound", 194, 30, function() EditKey(bindingAction, bindingSlot) end)
            local x, y = slot == 1 and 298 or 548, -(64 + (row - 1) * 36)
            SetPoint(key, "TOPLEFT", bindingCard, "TOPLEFT", x, y)
            local unbind = CreateButton(bindingCard, "X", 30, 30, function()
                local _, detail = bindings:Clear(bindingAction, bindingSlot)
                message = detail or ""; RefreshWorldMarkers()
            end)
            SetPoint(unbind, "LEFT", key, "RIGHT", 4, 0)
            AddTooltip(key, "Edit " .. (slot == 1 and "primary" or "alternate") .. " key: " .. actionLabel)
            AddTooltip(unbind, "Unbind this key: " .. actionLabel .. ". Does not clear placed markers.")
            bindingRows[#bindingRows + 1] = {action=action, slot=slot, key=key, unbind=unbind}
        end
    end
    local setup = CreateButton(bindingCard, "WOW KEYBINDS", 140, 30, function()
        if InCombatLockdown() then return end
        CancelEditor()
        if Settings and Settings.OpenToCategory and Settings.KEYBINDINGS_CATEGORY_ID then
            Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID, BINDING_HEADER_RCPARSENAL_MARKERS)
        else RA:Print("Open Esc > Options > Key Bindings > AddOns > RCP Arsenal - World markers.") end
    end)
    SetPoint(setup, "BOTTOMRIGHT", bindingCard, "BOTTOMRIGHT", -18, 18)
    parent:HookScript("OnHide", CancelEditor)
    RA.ConfigFrame:HookScript("OnHide", CancelEditor)
    RA:RegisterCallback("MARKER_BINDINGS_CHANGED", function() if RefreshEditor then RefreshEditor() end end)
    local function ViewportChanged()
        if not editorOverlay or not editorOverlay:IsShown() then return end
        local ok, combat = pcall(InCombatLockdown)
        if ok and type(issecretvalue) == "function" and not issecretvalue(combat) and combat == false
            and RA.ConfigFrame:IsShown() and RA.ConfigFrame.FitToScreen then RA.ConfigFrame.FitToScreen() end
        RefreshEditor()
    end
    RA:RegisterEvent("DISPLAY_SIZE_CHANGED", ViewportChanged)
    RA:RegisterEvent("UI_SCALE_CHANGED", ViewportChanged)
    local state = Font(parent, 10, TC.orange, "REGULAR")
    SetPoint(state, "TOPLEFT", parent, "TOPLEFT", 0, -616)
    SetWidth(state, 950)
    local permission = Font(parent, 9.2, TC.textSoft, "REGULAR")
    SetPoint(permission, "TOPLEFT", parent, "TOPLEFT", 0, -640)
    SetWidth(permission, 950)

    RefreshWorldMarkers = function()
        local settings = markers:GetSettings()
        local order = settings.order
        local combat = InCombatLockdown()
        local effective, pending = markers:GetState()
        if selected and not order[selected] then selected = nil end
        toggle:Refresh()
        toggle:SetEnabled(not combat)
        toggle:SetAlpha(combat and 0.45 or 1)
        radialToggle:Refresh();radialToggle:SetEnabled(not combat);radialToggle:SetAlpha(combat and 0.45 or 1)
        for id, button in ipairs(palette) do
            local present = false
            for _, markerID in ipairs(order) do if id == markerID then present = true end end
            button:SetSelected(present)
            button:SetEnabled(not combat)
            button:SetAlpha(combat and 0.45 or 1)
            local slot = slots[id]
            slot:SetShown(order[id] ~= nil)
            slot:SetEnabled(not combat)
            slot:SetAlpha(combat and 0.45 or 1)
            slot:SetSelected(selected == id)
            if order[id] then slot.icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. markers.Definitions[order[id]].icon) end
        end
        empty:SetShown(#order == 0 and not markers:IsRadialEnabled())
        left:SetEnabled(not combat and selected ~= nil and selected > 1)
        right:SetEnabled(not combat and selected ~= nil and selected < #order)
        remove:SetEnabled(not combat and selected ~= nil)
        setup:SetEnabled(not combat)
        for _, button in ipairs({left, right, remove, setup}) do
            button:SetAlpha(button:IsEnabled() and 1 or 0.45)
        end
        RA:SetVisualText(selection, message ~= "" and message or (selected and ("Selected: " .. markers.Definitions[order[selected]].name) or "Select a numbered slot to edit it."))
        local bindingState = bindings:GetState(markers.PlaceBinding)
        RA:SetVisualText(scopeText, bindingState.scopeLabel)
        RA:SetVisualText(bindingHelp, combat and "Change keybinds after combat." or bindings:GetStatusText())
        for _, row in ipairs(bindingRows) do
            local binding = bindings:GetState(row.action)
            local key = binding.keys[row.slot]
            RA:SetVisualText(row.key.label, key or (binding.available and "Unbound" or "Unavailable"))
            row.key:SetEnabled(binding.editable); row.key:SetAlpha(binding.editable and 1 or 0.45)
            row.unbind:SetEnabled(binding.editable and key ~= nil); row.unbind:SetAlpha(row.unbind:IsEnabled() and 1 or 0.45)
        end
        RefreshEditor()
        if pending then
            RA:SetVisualText(state, "Changes pending until combat ends. Current actions remain " .. (effective and "enabled." or "off."))
        elseif combat then
            RA:SetVisualText(state, "Change setup after combat. "..(markers:IsRadialEnabled() and markers:GetModeHelp() or "Normal sequence uses the last readable activity snapshot and local issued history. Inactive markers first; reuse the order when all are active."))
        elseif not settings.enabled then
            RA:SetVisualText(state,"World markers off. Prepare your sequence, mode and bindings, then enable when ready.")
        elseif settings.radialEnabled==true then
            RA:SetVisualText(state,markers:GetRadialStatusText())
        elseif #order == 0 then
            RA:SetVisualText(state, "Add at least one marker to use the cycler. Place-next is inactive.")
        else
            RA:SetVisualText(state, "Inactive configured markers first, then wrap/reuse. Uses an out-of-combat activity snapshot or local issued history; attempts are not placement confirmations.")
        end
        RA:SetVisualText(permission, markers:GetPermissionText())
    end
    RegisterControl({owner = parent, Refresh = function() RefreshWorldMarkers() end})
end

local function CreateActionsPane(parent)
    CreateHeading(parent, "Callouts & Panic", "Configure tile callouts. The Panic button moves with the HUD; it has no separate position.")

    local leftCard = CreateCard(parent, "LEFT CLICK", "Choose one callout channel. Say and Whisper are mutually exclusive.")
    SetSize(leftCard, 456, 370)
    SetPoint(leftCard, "TOPLEFT", parent, "TOPLEFT", 0, -62)

    local rightCard = CreateCard(parent, "RIGHT CLICK & PANIC", "Raid Warning stays on right-click; Panic is attached to the first ability category.", Theme.Assets.GradientBerry)
    SetSize(rightCard, 476, 370)
    SetPoint(rightCard, "TOPRIGHT", parent, "TOPRIGHT", 0, -62)

    local leftMode = CreateSegmented(leftCard, "LEFT-CLICK CHANNEL", {
        { label = "WHISPER", value = "WHISPER" },
        { label = "SAY", value = "SAY" },
        { label = "OFF", value = "OFF" },
    },
        function() return RA:GetDB().actions.leftClickMode or "WHISPER" end,
        function(value)
            local actions = RA:GetDB().actions
            actions.leftClickMode = value
            actions.whisperEnabled = value == "WHISPER"
            actions.sayEnabled = value == "SAY"
            ApplyVisualChange()
        end)
    SetPoint(leftMode, "TOPLEFT", leftCard, "TOPLEFT", 18, -64)
    SetWidth(leftMode, 420)
    leftMode:Layout(420)

    local whisperEdit = CreateEditBox(leftCard, "WHISPER MESSAGE", "Used only when WHISPER is selected above.",
        function() return RA:GetDB().actions.whisperTemplate end,
        function(value) RA:GetDB().actions.whisperTemplate = value; ApplyVisualChange() end)
    SetPoint(whisperEdit, "TOPLEFT", leftCard, "TOPLEFT", 18, -134)
    SetWidth(whisperEdit, 420)

    local sayEdit = CreateEditBox(leftCard, "SAY MESSAGE", "Used only when SAY is selected above.",
        function() return RA:GetDB().actions.sayTemplate end,
        function(value) RA:GetDB().actions.sayTemplate = value; ApplyVisualChange() end)
    SetPoint(sayEdit, "TOPLEFT", leftCard, "TOPLEFT", 18, -232)
    SetWidth(sayEdit, 420)

    local raidToggle = CreateToggle(rightCard, "Raid Warning", "Secure right-click action; requires raid lead or assist.",
        function() return RA:GetDB().actions.raidWarningEnabled ~= false end,
        function(value) RA:GetDB().actions.raidWarningEnabled = value; ApplyVisualChange() end)
    SetPoint(raidToggle, "TOPLEFT", rightCard, "TOPLEFT", 18, -64)
    SetWidth(raidToggle, 440)

    local raidEdit = CreateEditBox(rightCard, "RAID WARNING MESSAGE", "{spell}  {name}  {full}",
        function() return RA:GetDB().actions.raidWarningTemplate end,
        function(value) RA:GetDB().actions.raidWarningTemplate = value; ApplyVisualChange() end)
    SetPoint(raidEdit, "TOPLEFT", rightCard, "TOPLEFT", 18, -126)
    SetWidth(raidEdit, 440)

    local panicToggle = CreateToggle(rightCard, "Panic button", "Beside the first HUD category; moves with the HUD. One click sends one Raid Warning.",
        function() return RA:GetDB().leaderToolbox.panicEnabled ~= false end,
        function(value)
            RA:GetDB().leaderToolbox.panicEnabled = value
            if RA.RefreshPanicButton then RA:RefreshPanicButton() else ApplyVisualChange() end
            RefreshConfig()
        end)
    SetPoint(panicToggle, "TOPLEFT", rightCard, "TOPLEFT", 18, -220)
    SetWidth(panicToggle, 440)

    panicStatus = Font(parent, 10, TC.orange, "BOLD")
    SetPoint(panicStatus, "TOPLEFT", parent, "TOPLEFT", 0, -508)
    SetWidth(panicStatus, 930)
    local panicHelp = Font(parent, 9.4, TC.textSoft, "REGULAR")
    RA:SetVisualText(panicHelp, "Panic moves with the HUD and needs a visible ability category. Sending its Raid Warning requires permission.")
    SetPoint(panicHelp, "TOPLEFT", parent, "TOPLEFT", 0, -534)
    SetWidth(panicHelp, 930)

    local panicEdit = CreateEditBox(rightCard, "PANIC RAID WARNING", "One message only; no mass whispering.",
        function() return RA:GetDB().leaderToolbox.panicMessage end,
        function(value)
            RA:GetDB().leaderToolbox.panicMessage = value
            if RA.RefreshPanicButton then RA:RefreshPanicButton() end
        end)
    SetPoint(panicEdit, "TOPLEFT", rightCard, "TOPLEFT", 18, -274)
    SetWidth(panicEdit, 440)

    local diagnostics = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    diagnostics:SetAllPoints(parent)
    diagnostics:SetFrameLevel(parent:GetFrameLevel() + 40)
    diagnostics:EnableMouse(true)
    Backdrop(diagnostics, {0, 0, 0, 0.78}, TC.line, 14, false)
    diagnostics:Hide()
    local advanced = CreateButton(parent, "ADVANCED: TEST CALLOUTS", 260, 34, function() diagnostics:Show() end)
    SetPoint(advanced, "TOPLEFT", parent, "TOPLEFT", 0, -454)
    local hudPosition = CreateButton(parent, "HUD POSITION", 180, 34, function() RA:OpenConfig("HUD") end)
    SetPoint(hudPosition, "TOPRIGHT", parent, "TOPRIGHT", 0, -454)
    parent:HookScript("OnHide", function() diagnostics:Hide() end)
    RA.ConfigFrame:HookScript("OnHide", function() diagnostics:Hide() end)
    local statusCard = CreateCard(diagnostics, "SECURE CALLOUT STATUS", "Explicit hardware-click tests; each test can send its displayed message.")
    SetSize(statusCard, 950, 250)
    SetPoint(statusCard, "CENTER", diagnostics, "CENTER", 0, 0)
    local closeTests = CreateButton(statusCard, "CLOSE TESTS", 140, 32, function() diagnostics:Hide() end)
    SetPoint(closeTests, "TOPRIGHT", statusCard, "TOPRIGHT", -18, -14)

    actionStatusText = Font(statusCard, 14, TC.text, "BOLD")
    SetPoint(actionStatusText, "TOPLEFT", statusCard, "TOPLEFT", 24, -62)
    actionStatusDetail = Font(statusCard, 9.2, TC.textSoft, "REGULAR")
    actionStatusDetail:SetWordWrap(true)
    SetPoint(actionStatusDetail, "TOPLEFT", actionStatusText, "BOTTOMLEFT", 0, -5)
    SetWidth(actionStatusDetail, 600)

    local warning = Font(statusCard, 8.7, TC.orange, "REGULAR")
    RA:SetVisualText(warning, "Raid Warning can be blocked during encounters when a raid member is outside the instance.")
    warning:SetWordWrap(true)
    SetPoint(warning, "BOTTOMLEFT", statusCard, "BOTTOMLEFT", 24, 101)
    SetWidth(warning, 600)

    local playerName = RA:GetFullUnitName("player") or UnitName("player") or "player"
    local testWhisper = CreateSecureTestButton(statusCard, "TEST WHISPER", "/w " .. playerName .. " RCP Arsenal secure whisper test", 155)
    SetPoint(testWhisper, "BOTTOMLEFT", statusCard, "BOTTOMLEFT", 24, 20)
    local testSay = CreateSecureTestButton(statusCard, "TEST SAY", "/s RCP Arsenal secure say test", 115)
    SetPoint(testSay, "LEFT", testWhisper, "RIGHT", 8, 0)
    local testRaid = CreateSecureTestButton(statusCard, "TEST RAID", "/rw RCP Arsenal secure Raid Warning test", 145)
    SetPoint(testRaid, "LEFT", testSay, "RIGHT", 8, 0)

    local testPanic = CreateSecureTestButton(statusCard, "TEST PANIC", "/rw PANIC: USE DEFENSIVES + HEALTH POTIONS NOW!", 120)
    SetPoint(testPanic, "BOTTOMLEFT", statusCard, "BOTTOMLEFT", 24, 60)
    local rearm = CreateButton(statusCard, "REARM", 100, 34, function()
        if RA.RearmSecureActions then RA:RearmSecureActions() end
        RefreshConfig()
    end)
    SetPoint(rearm, "LEFT", testPanic, "RIGHT", 8, 0)
end

local function SetTab(tabKey)
    if tabKey == "RAIDTOOLS" then tabKey = "ADDONS" end
    if tabKey == "SETUP" then tabKey = "GENERAL" end
    local navigation = Navigation()
    if tabKey == "COOLDOWNS" then
        tabKey = PANE_CONTEXT[navigation.cooldownTab] == "COOLDOWNS" and navigation.cooldownTab or "CONTENT"
    end
    if not panes[tabKey] then tabKey = "GENERAL" end
    if tabKey == "GENERAL" then RA.Setup:PresentIntroduction() end
    if RA.HideHubTransientDialogs then RA:HideHubTransientDialogs() end
    activeTab = tabKey
    navigation.lastTab = tabKey
    if PaneContext(tabKey) == "COOLDOWNS" then navigation.cooldownTab = tabKey end
    for key, pane in pairs(panes) do
        pane:SetShown(key == tabKey or (key == "COOLDOWNS" and PaneContext(tabKey) == "COOLDOWNS"))
    end
    for key, button in pairs(cooldownTabs) do button:SetSelected(key == tabKey) end
    if cooldownScroll then cooldownScroll:SetVerticalScroll(0) end
    for key, button in pairs(tabButtons) do
        local selected = key == (PaneContext(tabKey) or tabKey)
        SetSurfaceColor(button, selected and TC.activeDark or TC.transparent)
        SetBorderColor(button, selected and CopyColor(TC.magenta, 0.34) or TC.transparent)
        button.gradient:SetAlpha(selected and 0.66 or 0)
        button.title:SetTextColor(unpack(selected and TC.white or TC.textSoft))
        button.icon:SetVertexColor(unpack(selected and TC.white or TC.muted))
        button.bar:SetShown(selected)
    end
    if hudFooter then hudFooter:Show() end
    if advancedBack then
        advancedBack:SetShown(tabKey == "NORTHERNSKY")
        RA:SetVisualText(advancedBack.label, "BACK TO ADDONS")
    end
    if RefreshConfig then RefreshConfig() end
end

RefreshConfig = function()
    if not frame then
        return
    end
    if RefreshGeneral and panes.GENERAL and panes.GENERAL:IsVisible() then RefreshGeneral() end
    if RefreshRaidGroups and panes.RAIDGROUPS and panes.RAIDGROUPS:IsVisible() then RefreshRaidGroups() end
    RefreshVisibleControls()
    if panes.CONTENT and panes.CONTENT:IsVisible() then RefreshCategoryRows(); RefreshAbilityList(false) end
    if panes.SCANNING and panes.SCANNING:IsVisible() then RefreshScanPane() end
    if panes.HUD and panes.HUD:IsVisible() then UpdatePreview() end
    if panicStatus and panes.ACTIONS:IsVisible() then RA:SetVisualText(panicStatus, "Panic: " .. RA:GetPanicVisibilityText()) end
    if RefreshHub then RefreshHub(activeTab) end

    if actionStatusText and panes.ACTIONS:IsVisible() and RA.GetSecureActionStatus then
        local armed, visible, clickMode = RA:GetSecureActionStatus()
        RA:SetVisualText(actionStatusText, string.format("%d / %d VISIBLE TILES ARMED", armed, visible))
        RA:SetVisualText(actionStatusDetail, "Secure macros execute on " .. clickMode .. ". Left-click uses exactly one selected channel (Whisper, Say, or Off); right-click requests Raid Warning. Reopen or rearm after changing action templates.")
    end

    RefreshFooter()
end

RefreshFooter = function()
    if statusText then statusText:SetShown(PaneContext(activeTab) == "COOLDOWNS") end
    if PaneContext(activeTab) ~= "COOLDOWNS" then return end
    local primary = ScanStatusText()
    local reason = RA.GetHUDVisibilityReason and RA:GetHUDVisibilityReason() or nil
    local hudState = reason and ("HUD HIDDEN: " .. reason) or "HUD VISIBLE"
    local fontName = RA.GetFontStatus and select(1, RA:GetFontStatus()) or "Blizzard font"
    RA:SetVisualText(statusText, primary .. "  •  " .. hudState .. "  •  " .. fontName)
end

local function CreateProfileDialog()
    if profileDialog then
        return profileDialog
    end

    profileDialog = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    profileDialog:SetAllPoints(frame)
    profileDialog:SetFrameLevel(frame:GetFrameLevel() + 30)

    profileDialog.dimmer = profileDialog:CreateTexture(nil, "BACKGROUND")
    profileDialog.dimmer:SetColorTexture(0.010, 0.008, 0.020, 0.78)
    profileDialog.dimmer:SetAllPoints(profileDialog)

    profileDialog.card = CreateFrame("Frame", nil, profileDialog, "BackdropTemplate")
    SetSize(profileDialog.card, 820, 430)
    SetPoint(profileDialog.card, "CENTER", profileDialog, "CENTER", 0, 0)
    Backdrop(profileDialog.card, TC.surface, CopyColor(TC.magenta, 0.22), 18, true)
    Theme:AddTopWash(profileDialog.card, Theme.Assets.GradientSunsetWash, 0.12, 90, 2)

    profileDialog.title = Font(profileDialog.card, 19, TC.text, "BOLD")
    SetPoint(profileDialog.title, "TOPLEFT", profileDialog.card, "TOPLEFT", 24, -22)
    profileDialog.subtitle = Font(profileDialog.card, 10.2, TC.textSoft, "REGULAR")
    SetPoint(profileDialog.subtitle, "TOPLEFT", profileDialog.title, "BOTTOMLEFT", 0, -5)

    local close = CreateButton(profileDialog.card, "X", 38, 38, function() profileDialog:Hide() end)
    SetPoint(close, "TOPRIGHT", profileDialog.card, "TOPRIGHT", -18, -18)

    local editBack = CreateFrame("Frame", nil, profileDialog.card, "BackdropTemplate")
    SetPoint(editBack, "TOPLEFT", profileDialog.card, "TOPLEFT", 24, -90)
    SetPoint(editBack, "BOTTOMRIGHT", profileDialog.card, "BOTTOMRIGHT", -24, 82)
    Backdrop(editBack, TC.input, TC.line, 12, false)

    profileDialogBox = CreateFrame("EditBox", nil, editBack)
    SetPoint(profileDialogBox, "TOPLEFT", editBack, "TOPLEFT", 14, -12)
    SetPoint(profileDialogBox, "BOTTOMRIGHT", editBack, "BOTTOMRIGHT", -14, 12)
    ApplyReadableFont(profileDialogBox, 10.3, "REGULAR")
    profileDialogBox:SetTextColor(unpack(TC.text))
    profileDialogBox:SetMultiLine(true)
    profileDialogBox:SetAutoFocus(false)
    profileDialogBox:SetMaxLetters(32767)
    profileDialogBox:SetTextInsets(0, 0, 0, 0)
    profileDialogBox:SetScript("OnEscapePressed", function(self) self:ClearFocus(); profileDialog:Hide() end)

    profileDialogStatus = Font(profileDialog.card, 9.6, TC.textSoft, "REGULAR")
    SetPoint(profileDialogStatus, "BOTTOMLEFT", profileDialog.card, "BOTTOMLEFT", 24, 28)
    SetPoint(profileDialogStatus, "RIGHT", profileDialog.card, "RIGHT", -230, 0)

    profileDialog.primary = CreateButton(profileDialog.card, "COPY", 176, 40, function()
        if profileDialogMode == "EXPORT" then
            profileDialogBox:SetFocus()
            profileDialogBox:HighlightText()
            RA:SetVisualText(profileDialogStatus, "Press Ctrl+C to copy the highlighted profile string.")
            profileDialogStatus:SetTextColor(unpack(TC.textSoft))
        else
            local ok, message = RA:ImportProfileString(profileDialogBox:GetText())
            RA:SetVisualText(profileDialogStatus, message or (ok and "Profile imported." or "Import failed."))
            profileDialogStatus:SetTextColor(unpack(ok and TC.success or TC.danger))
            if ok then
                RefreshConfig()
            end
        end
    end, true)
    SetPoint(profileDialog.primary, "BOTTOMRIGHT", profileDialog.card, "BOTTOMRIGHT", -24, 20)

    profileDialog:Hide()
    return profileDialog
end

local function OpenProfileDialog(mode)
    if InCombatLockdown() then
        RA:Print("Profile import/export is unavailable during combat.")
        return
    end
    if not frame then
        return
    end
    CreateProfileDialog()
    profileDialogMode = mode == "IMPORT" and "IMPORT" or "EXPORT"
    RA:SetVisualText(profileDialogStatus, "")
    if profileDialogMode == "EXPORT" then
        local text, err = RA:ExportProfileString()
        RA:SetVisualText(profileDialog.title, "EXPORT SETTINGS")
        RA:SetVisualText(profileDialog.subtitle, "Copy this profile string to share your HUD, content, scanning, and action settings.")
        RA:SetVisualText(profileDialog.primary.label, "SELECT ALL")
        profileDialogBox:SetText(text or "")
        RA:SetVisualText(profileDialogStatus, err or "Screen position and inspection cache are intentionally excluded.")
        profileDialogBox:SetFocus()
        profileDialogBox:HighlightText()
    else
        RA:SetVisualText(profileDialog.title, "IMPORT SETTINGS")
        RA:SetVisualText(profileDialog.subtitle, "Paste a RCP Arsenal profile string below. Your local HUD position will be preserved.")
        RA:SetVisualText(profileDialog.primary.label, "IMPORT PROFILE")
        profileDialogBox:SetText("")
        RA:SetVisualText(profileDialogStatus, "Unknown abilities from a different catalog version are safely ignored.")
        profileDialogBox:SetFocus()
    end
    profileDialog:Show()
end

local function CreateConfig()
    local FRAME_WIDTH, FRAME_HEIGHT = 1280, 820

    frame = CreateFrame("Frame", "RCPArsenalConfig", UIParent, "BackdropTemplate")
    RA.ConfigFrame = frame
    SetSize(frame, FRAME_WIDTH, FRAME_HEIGHT)
    SetPoint(frame, "CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    Backdrop(frame, TC.canvasDeep, CopyColor(TC.violet, 0.16), 20, true)
    Theme:AddAtmosphere(frame, 0.42)
    frame:SetScript("OnDragStart", function(self)
        if not InCombatLockdown() then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:Hide()

    local sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    SetSize(sidebar, 238, 728)
    SetPoint(sidebar, "TOPLEFT", frame, "TOPLEFT", 16, -16)
    Backdrop(sidebar, TC.sidebar, CopyColor(TC.violet, 0.10), 17, false)
    Theme:AddTopWash(sidebar, Theme.Assets.GradientSunsetWash, 0.10, 132, 2)

    local main = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    SetSize(main, 996, 728)
    SetPoint(main, "TOPRIGHT", frame, "TOPRIGHT", -16, -16)
    Backdrop(main, TC.canvas, TC.line, 17, false)
    Theme:AddTopWash(main, Theme.Assets.GradientBerry, 0.028, 110, 2)

    local footer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    hudFooter = footer
    SetSize(footer, 1248, 62)
    SetPoint(footer, "BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 14)
    Backdrop(footer, TC.footer, CopyColor(TC.magenta, 0.16), 15, false)

    local logo = Theme:CreateIcon(sidebar, Theme.Assets.HeaderLogo, 42, TC.white)
    -- Native rounding follows FitToScreen's final scale, unlike creation-time
    -- offset rounding alone. Keep the existing 42-unit header footprint.
    if logo.SetRoundLayoutToNearestPixel then logo:SetRoundLayoutToNearestPixel(true) end
    SetPoint(logo, "TOPLEFT", sidebar, "TOPLEFT", 18, -18)

    local title = Font(sidebar, 15.5, TC.text, "BOLD")
    RA:SetVisualText(title, "RCP ARSENAL")
    SetPoint(title, "TOPLEFT", logo, "TOPRIGHT", 10, -4)
    local version = Font(sidebar, 9.4, TC.magenta, "BOLD")
    RA:SetVisualText(version, "v" .. RA.VERSION)
    SetPoint(version, "TOPLEFT", title, "BOTTOMLEFT", 0, -3)

    local navTop, navGroup = -88, nil
    for i = 1, #TAB_DEFS do
        local definition = TAB_DEFS[i]
        if definition.group ~= navGroup then
            local heading = Font(sidebar, 8.8, TC.muted, "BOLD")
            RA:SetVisualText(heading, definition.group)
            SetPoint(heading, "TOPLEFT", sidebar, "TOPLEFT", 20, navTop)
            navTop = navTop - 20
            navGroup = definition.group
        end
        local button = CreateFrame("Button", nil, sidebar, "BackdropTemplate")
        SetSize(button, 206, 42)
        SetPoint(button, "TOPLEFT", sidebar, "TOPLEFT", 16, navTop)
        navTop = navTop - 46
        Backdrop(button, TC.transparent, TC.transparent, 11, false)
        button.gradient = CreateGradientOverlay(button, Theme.Assets.GradientSunset, 0, 2)

        button.bar = button:CreateTexture(nil, "ARTWORK")
        Theme:RegisterAssetTexture(button.bar, Theme.Assets.GradientSunset)
        SetWidth(button.bar, 4)
        SetPoint(button.bar, "TOPLEFT", button, "TOPLEFT", 0, -9)
        SetPoint(button.bar, "BOTTOMLEFT", button, "BOTTOMLEFT", 0, 9)
        button.bar:Hide()

        button.icon = Theme:CreateIcon(button, definition.icon, 20, TC.muted)
        SetPoint(button.icon, "LEFT", button, "LEFT", 13, 0)

        button.title = Font(button, 10.8, TC.textSoft, "BOLD")
        RA:SetVisualText(button.title, definition.label)
        SetPoint(button.title, "LEFT", button.icon, "RIGHT", 12, 0)
        SetPoint(button.title, "RIGHT", button, "RIGHT", -8, 0)
        SetHeight(button.title, 20)
        button.title:SetWordWrap(false)

        button:SetScript("OnEnter", function(self)
            if (PaneContext(activeTab) or activeTab) ~= definition.key then
                SetSurfaceColor(self, TC.surfaceHover)
                self.gradient:SetAlpha(0.10)
            end
        end)
        button:SetScript("OnLeave", function(self)
            local selected = (PaneContext(activeTab) or activeTab) == definition.key
            SetSurfaceColor(self, selected and TC.activeDark or TC.transparent)
            self.gradient:SetAlpha(selected and 0.66 or 0)
        end)
        button:SetScript("OnClick", function() SetTab(definition.key) end)
        tabButtons[definition.key] = button
    end

    advancedBack = CreateButton(main, "BACK TO ADDONS", 206, 34, function()
        SetTab(PaneContext(activeTab) or "ADDONS")
    end)
    advancedBack:SetFrameLevel(main:GetFrameLevel() + 20)
    SetPoint(advancedBack, "TOPRIGHT", main, "TOPRIGHT", -68, -20)
    local hint = Font(sidebar, 10, TC.muted, "REGULAR")
    RA:SetVisualText(hint, "Tools stay optional.\n/rcp reopens your last tab.")
    hint:SetWordWrap(true)
    SetWidth(hint, 200)
    SetPoint(hint, "BOTTOMLEFT", sidebar, "BOTTOMLEFT", 18, 30)

    local close = CreateButton(main, "X", 38, 38, function() HideConfig("USER") end)
    SetPoint(close, "TOPRIGHT", main, "TOPRIGHT", -16, -16)

    local content = CreateFrame("Frame", nil, main)
    SetSize(content, 950, 660)
    SetPoint(content, "TOPLEFT", main, "TOPLEFT", 24, -26)

    for i = 1, #TAB_DEFS do
        local pane = CreateFrame("Frame", nil, content)
        pane:SetAllPoints(content)
        pane:Hide()
        panes[TAB_DEFS[i].key] = pane
    end
    for key in pairs(PANE_CONTEXT) do
        if key == "NORTHERNSKY" then
            local pane = CreateFrame("Frame", nil, content)
            pane:SetAllPoints(content)
            pane:Hide()
            panes[key] = pane
        end
    end

    local cooldownHost = panes.COOLDOWNS
    CreateHeading(cooldownHost, "Available Cooldowns", "")
    local master = CreateToggle(cooldownHost, "Available Cooldowns",
        "",
        function() return RA:IsHUDEnabled() end,
        function(value) RA:SetHUDEnabled(value); RefreshConfig() end)
    master:SetCompact(false)
    master:HookScript("OnEnter", function(owner)
        GameTooltip:SetOwner(owner,"ANCHOR_RIGHT");GameTooltip:SetText("Available Cooldowns")
        GameTooltip:AddLine("Enables the HUD and inspection to show ability providers. Provider ownership is static; cooldown use and remaining time are not tracked.",0.76,0.80,0.86,true)
        GameTooltip:Show()
    end)
    master:HookScript("OnLeave",function()GameTooltip:Hide()end)
    SetPoint(master, "TOPLEFT", cooldownHost, "TOPLEFT", 0, -58)
    SetWidth(master, 950)
    local tabX = 0
    for _, definition in ipairs(COOLDOWN_TABS) do
        local key = definition.key
        local button = CreateButton(cooldownHost, definition.label, definition.width, 32, function() SetTab(key) end)
        SetPoint(button, "TOPLEFT", cooldownHost, "TOPLEFT", tabX, -118)
        cooldownTabs[key] = button
        tabX = tabX + definition.width + 8
    end
    cooldownScroll = CreateFrame("ScrollFrame", nil, cooldownHost, "UIPanelScrollFrameTemplate")
    SetPoint(cooldownScroll, "TOPLEFT", cooldownHost, "TOPLEFT", 0, -164)
    SetPoint(cooldownScroll, "BOTTOMRIGHT", cooldownHost, "BOTTOMRIGHT", 0, 0)
    local cooldownBody = CreateFrame("Frame", nil, cooldownScroll)
    SetSize(cooldownBody, 950, 660)
    cooldownScroll:SetScrollChild(cooldownBody)
    for _, definition in ipairs(COOLDOWN_TABS) do
        local pane = CreateFrame("Frame", nil, cooldownBody)
        pane:SetAllPoints(cooldownBody)
        pane:Hide()
        panes[definition.key] = pane
    end
    RefreshHub = RA:CreateHubPanes(panes, {
        Font = Font, Button = CreateButton, Card = CreateCard, Heading = CreateHeading,
        Toggle = CreateToggle, Slider = CreateSlider, EditBox = CreateEditBox, Segmented = CreateSegmented, Backdrop = Backdrop,
        Refresh = function() RefreshConfig() end,
    })
    RefreshGeneral = RA:CreateGeneralPane(panes.GENERAL, {
        Font = Font, Button = CreateButton, Heading = CreateHeading, Toggle = CreateToggle, Backdrop = Backdrop,
        Refresh = function() RefreshConfig() end,
    })

    RefreshRaidGroups = RA:CreateRaidGroupsPane(panes.RAIDGROUPS, {
        Font = Font, Button = CreateButton, Heading = CreateHeading, Backdrop = Backdrop,
    })

    CreateHUDPane(panes.HUD)
    CreateQuickBarPane(panes.QUICKBAR)
    CreateContentPane(panes.CONTENT)
    CreateScanningPane(panes.SCANNING)
    CreateActionsPane(panes.ACTIONS)
    CreateWorldMarkersPane(panes.WORLDMARKERS)

    local previewAll = CreateButton(footer, "PREVIEW ALL", 150, 42, function()RA:BeginGlobalPlacement("PREVIEW")end, false, Theme.Assets.IconPlay)
    SetPoint(previewAll,"LEFT",footer,"LEFT",12,0)
    local moveAll = CreateButton(footer, "MOVE ALL", 144, 42, function()RA:BeginGlobalPlacement("MOVE")end,false,Theme.Assets.IconTarget)
    SetPoint(moveAll,"LEFT",previewAll,"RIGHT",10,0)
    statusText = Font(footer, 9.3, TC.textSoft, "REGULAR")
    statusText:SetJustifyH("RIGHT")
    SetPoint(statusText, "LEFT", moveAll, "RIGHT", 16, 0)
    SetPoint(statusText, "RIGHT", footer, "RIGHT", -18, 0)

    local function FitToScreen()
        local availableWidth = math.max(1, UIParent:GetWidth() - 24)
        local availableHeight = math.max(1, UIParent:GetHeight() - 24)
        local scale = math.min(1, availableWidth / FRAME_WIDTH, availableHeight / FRAME_HEIGHT)
        frame:SetScale(scale)
    end
    frame.FitToScreen = FitToScreen

    frame.UpdatePreview = UpdatePreview
    frame:SetScript("OnShow", function()
        FitToScreen()
        SetTab(activeTab)
    end)
    if type(UISpecialFrames)=="table" then table.insert(UISpecialFrames,"RCPArsenalConfig") end
end

function RA:OpenConfig(tabKey)
    if InCombatLockdown() then
        self:Print("Configuration is locked during combat.")
        return
    end
    if self.Placement:IsActive() then self.Placement:Cancel("Arsenal opened",true) end
    placementReturnPending = nil
    local requested = tabKey
    if requested == nil then
        requested = self.Setup:IsFirstRunPending() and "GENERAL" or Navigation().lastTab
        if requested == "SETUP" then requested = "GENERAL" end
    end
    if requested == "SETUP" then requested = "GENERAL" end
    activeTab = type(requested) == "string" and requested or "GENERAL"
    if activeTab == "GENERAL" then self.Setup:PresentIntroduction() end
    if not frame then
        CreateConfig()
    end
    local alreadyShown = frame:IsShown()
    frame:Show()
    if alreadyShown then SetTab(activeTab) end
end

function RA:OpenSetup()
    self:OpenConfig("GENERAL") -- compatibility for /rcp setup and old callers
    return not InCombatLockdown()
end

function RA:BeginGlobalPlacement(mode)
    if not frame then self:OpenConfig() end
    if not frame then return false end
    local ok,reason=self.Placement:Start(mode,function(message)
        if InCombatLockdown() or RA.InEncounter or (IsEncounterInProgress and IsEncounterInProgress()) then placementReturnPending=true
        else RA:OpenConfig(activeTab) end
        if message then RA:Print(message) end
    end)
    if ok then HideConfig("PLACEMENT") elseif reason then self:Print(reason) end
    return ok,reason
end

local function RestoreAfterPlacement()
    if placementReturnPending and not InCombatLockdown() and not RA.InEncounter and not (IsEncounterInProgress and IsEncounterInProgress()) then
        placementReturnPending=nil;RA:OpenConfig(activeTab)
    elseif frame and frame:IsShown() then RefreshConfig() end
end
RA:RegisterEvent("PLAYER_REGEN_DISABLED",RestoreAfterPlacement)
RA:RegisterEvent("PLAYER_REGEN_ENABLED",RestoreAfterPlacement)
RA:RegisterEvent("ENCOUNTER_END",RestoreAfterPlacement)

function RA:OpenProfileDialog(mode)
    if not frame then
        self:OpenConfig()
    end
    OpenProfileDialog(mode)
end

function RA:CloseConfig(intent)
    HideConfig(intent=="CONTEXT" and "CONTEXT" or "USER")
end

RA:RegisterInitializer(function()
    -- Lazy by design: no settings frames are allocated until requested.
end)

RA:RegisterCallback("READINESS_UPDATED", function()
    if frame and frame:IsShown() and panes.ADDONS:IsVisible() and RefreshHub then RefreshHub("ADDONS") end
end)
RA:RegisterCallback("TOOLS_CHANGED", function()
    if frame and frame:IsShown() then RefreshConfig() end
end)
RA:RegisterCallback("PERSONAL_TOOLS_CHANGED", function()
    if frame and frame:IsShown() then RefreshConfig() end
end)

RA:RegisterCallback("REPORTS_UPDATED", function()
    if frame and frame:IsShown() then
        -- Capability reports change the scan footer, not addon versions.
        if panes.ADDONS:IsVisible() then RefreshFooter() else RefreshConfig() end
    end
end)
RA:RegisterCallback("ACCENT_THEME_CHANGED", function()
    if frame and frame:IsShown() then RefreshConfig() end
end)

RA:RegisterCallback("INSPECTION_STATE_CHANGED", function()
    -- Scan target/progress changes should not rebuild every settings control.
    -- Only the scanning pane needs to react while an inspect pass is running.
    if frame and frame:IsShown() then
        if panes.SCANNING:IsVisible() then RefreshScanPane() end
        if panicStatus and panes.ACTIONS:IsVisible() then RA:SetVisualText(panicStatus, "Panic: " .. RA:GetPanicVisibilityText()) end
    end
end)
RA:RegisterCallback("PROFILE_RESET", function()
    if frame and frame:IsShown() then RefreshConfig() end
end)

RA:RegisterCallback("ABILITY_ORDER_CHANGED", function()
    if frame and frame:IsShown() and panes.CONTENT:IsVisible() then RefreshAbilityList(false) end
end)

RA:RegisterCallback("WORLD_MARKERS_CHANGED", function()
    if frame and frame:IsShown() and activeTab == "WORLDMARKERS" and RefreshWorldMarkers then RefreshWorldMarkers() end
end)

RA:RegisterCallback("MARKER_BINDINGS_CHANGED", function()
    if frame and frame:IsShown() and activeTab == "WORLDMARKERS" and RefreshWorldMarkers then RefreshWorldMarkers() end
end)
