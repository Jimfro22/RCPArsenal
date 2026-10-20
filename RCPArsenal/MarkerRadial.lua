local _, RA = ...

local Radial = {}
RA.MarkerRadial = Radial

local cycle, root, center, visual, timer
local generation, visualHeld, visualAge = 0, false, 0
local originX, originY
local bindingFirst, bindingSecond
local status = "Marker wheel is off."
local DEADZONE, RADIUS, DISPLAY_DELAY, VISUAL_LIMIT = 22, 92, 0.18, 10

-- Only the hardware CLICK handler selects/arms an action. Timing is entirely
-- presentation: a stationary long hold has the same random default as a tap.
local RESET = [[
    self:SetAttribute("rcp-radial-held", nil)
    self:SetAttribute("rcp-radial-aimed", nil)
    self:SetAttribute("macrotext", nil)
    self:ClearBindings()
    self:GetFrameRef("rcp-radial-root"):Hide()
    self:CallMethod("RCPRadialEndVisual")
]]

local CLICK = [[
    local button, down = ...
    if not self:GetAttribute("enabled") or self:GetAttribute("rcp-input-suppressed") then return false end
    if self:GetAttribute("state-rcp-radial-context") == "blocked" then return false end
    if down then
        if self:GetAttribute("rcp-radial-held") then return false end
        self:SetAttribute("macrotext", nil)
        self:SetAttribute("rcp-radial-held", true)
        self:SetAttribute("rcp-radial-aimed", nil)
        local root = self:GetFrameRef("rcp-radial-root")
        local center = self:GetFrameRef("rcp-radial-center")
        center:ClearAllPoints()
        center:SetPoint("CENTER", "$cursor", "BOTTOMLEFT", 0, 0)
        local width, height = root:GetWidth() * 2, root:GetHeight() * 2
        for i = 1, 8 do
            local zone = self:GetFrameRef("rcp-radial-zone" .. i)
            if i == 1 or i == 5 then zone:SetWidth(44) else zone:SetWidth(width) end
            if i == 3 or i == 7 then zone:SetHeight(44) else zone:SetHeight(height) end
        end
        root:Show()
        for i = 1, 2 do
            local key = self:GetAttribute("rcp-radial-key" .. i)
            if key then
                for mask = 0, 7 do
                    local chord = key
                    if mask % 2 == 1 then chord = "SHIFT-" .. chord end
                    if math.floor(mask / 2) % 2 == 1 then chord = "CTRL-" .. chord end
                    if mask >= 4 then chord = "ALT-" .. chord end
                    self:SetBindingClick(true, chord, self:GetName(), "LeftButton")
                end
            end
        end
        self:SetBindingClick(true, "ESCAPE", "RCPArsenalWorldMarkerCancel", "LeftButton")
        self:SetBindingClick(true, "BUTTON2", "RCPArsenalWorldMarkerCancel", "LeftButton")
        local left, bottom = center:GetRect()
        self:CallMethod("RCPRadialBeginVisual", left + 22, bottom + 22)
        return false
    end
    if not self:GetAttribute("rcp-radial-held") then return false end
    local root = self:GetFrameRef("rcp-radial-root")
    local center = self:GetFrameRef("rcp-radial-center")
    local x, y = root:GetMousePosition()
    local marker
    if x and y then
        local left, bottom, width, height = root:GetRect()
        local cl, cb = center:GetRect()
        local dx, dy = left + x * width - cl - 22, bottom + y * height - cb - 22
        if math.abs(dx) <= 22 and math.abs(dy) <= 22 then
            if not self:GetAttribute("rcp-radial-aimed") then marker = random(1, 8) end
        else
            marker = (math.floor((math.atan2(dx, dy) + math.pi / 8) / (math.pi / 4)) % 8) + 1
        end
    end
    self:RunAttribute("rcp-radial-reset")
    if not marker then return false end
    self:SetAttribute("macrotext", "/wm [@cursor] " .. marker)
]]

local AIM = [[
    if control:GetAttribute("rcp-radial-held") then control:SetAttribute("rcp-radial-aimed", true) end
]]
local CANCEL = [[
    if not down then return false end
    local cycle = self:GetFrameRef("cycle")
    if cycle:GetAttribute("rcp-radial-held") then cycle:RunAttribute("rcp-radial-reset") end
    return false
]]
local CONTEXT = [[
    if name == "state-rcp-radial-context" and value == "blocked" and self:GetAttribute("rcp-radial-held") then
        self:RunAttribute("rcp-radial-reset")
    end
]]
local HIDE = [[
    if control:GetAttribute("rcp-radial-held") then control:RunAttribute("rcp-radial-reset") end
]]

local function Text(region, value)
    if RA.SetVisualText then RA:SetVisualText(region, value) else region:SetText(value) end
end

local function Label(parent, size)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    if RA.ApplyFont then RA:ApplyFont(label, size, "BOLD", true) end
    return label
end

local function Surface(frame, color)
    if RA.Theme then RA.Theme:ApplyRounded(frame, color, 12, "radial")
    else
        local texture = frame:CreateTexture(nil, "BACKGROUND")
        texture:SetAllPoints()
        texture:SetColorTexture(unpack(color))
    end
end

local function RecoveryCue()
    if not visual then return end
    visual:SetScript("OnUpdate", nil)
    for _, slot in ipairs(visual.slots) do slot.icon:SetAlpha(0.35); slot.highlight:SetAlpha(0) end
    Text(visual.choice, "RELEASE KEY")
    Text(visual.hint, "or press Escape")
    Text(visual.help, "Release the marker key or press Escape")
    visual:Show()
end

local function UpdateVisual(_, elapsed)
    if not visualHeld then return end
    visualAge = visualAge + elapsed
    -- A lost native key-up must not leave unbounded addon polling. This only
    -- stops the preview; secure Escape/right-click/release still resets input.
    if visualAge >= VISUAL_LIMIT then
        RecoveryCue()
        return
    end
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    local dx, dy = x / scale - originX, y / scale - originY
    local selected
    if math.abs(dx) > DEADZONE or math.abs(dy) > DEADZONE then
        selected = (math.floor((math.atan2(dx, dy) + math.pi / 8) / (math.pi / 4)) % 8) + 1
    end
    for i, slot in ipairs(visual.slots) do
        slot.icon:SetAlpha(selected and selected ~= i and 0.45 or 1)
        slot.highlight:SetAlpha(selected == i and 1 or 0)
    end
    local aimed = cycle:GetAttribute("rcp-radial-aimed")
    Text(visual.choice, selected and RA.WorldMarkers.Definitions[selected].name or aimed and "CANCEL" or "RANDOM")
    Text(visual.hint, "Release to " .. (selected and "place" or aimed and "cancel" or "randomize"))
end

local function CreateVisual()
    visual = CreateFrame("Frame", nil, UIParent)
    visual:SetSize(282, 282)
    visual:SetFrameStrata("TOOLTIP")
    visual:EnableMouse(false)
    Surface(visual, {0.035, 0.036, 0.070, 0.90})
    visual.slots = {}
    for i, definition in ipairs(RA.WorldMarkers.Definitions) do
        local slot = CreateFrame("Frame", nil, visual)
        local angle = (i - 1) * math.pi / 4
        slot:SetSize(42, 42)
        slot:SetPoint("CENTER", visual, "CENTER", math.sin(angle) * RADIUS, math.cos(angle) * RADIUS)
        Surface(slot, {0.085, 0.091, 0.151, 0.95})
        slot.highlight = slot:CreateTexture(nil, "BORDER")
        slot.highlight:SetAllPoints()
        local color = RA.Theme and RA.Theme:GetAccentEnd() or {0.973, 0.608, 0.161, 1}
        slot.highlight:SetColorTexture(unpack(color))
        slot.highlight:SetAlpha(0)
        slot.icon = slot:CreateTexture(nil, "ARTWORK")
        slot.icon:SetSize(30, 30)
        slot.icon:SetPoint("CENTER")
        local texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. definition.icon
        if RA.SetVisualTexture then RA:SetVisualTexture(slot.icon, texture) else slot.icon:SetTexture(texture) end
        visual.slots[i] = slot
    end
    visual.choice, visual.hint, visual.help = Label(visual, 11), Label(visual, 9), Label(visual, 9)
    visual.choice:SetPoint("CENTER", visual, "CENTER", 0, 8)
    visual.hint:SetPoint("CENTER", visual, "CENTER", 0, -10)
    visual.help:SetPoint("BOTTOM", visual, "BOTTOM", 0, 8)
    Text(visual.help, "Escape / right-click cancels")
    visual:Hide()
end

local function EndVisual()
    generation = generation + 1
    visualHeld = false
    if timer then timer:Cancel(); timer = nil end
    if visual then visual:SetScript("OnUpdate", nil); visual:Hide() end
end

local function BeginVisual(_, x, y)
    EndVisual()
    visualHeld, visualAge, originX, originY = true, 0, x, y
    visual:ClearAllPoints()
    visual:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    Text(visual.help, "Escape / right-click cancels")
    local token = generation
    timer = C_Timer.NewTimer(DISPLAY_DELAY, function()
        timer = nil
        if not visualHeld or token ~= generation then return end
        UpdateVisual(visual, 0)
        visual:SetScript("OnUpdate", UpdateVisual)
        visual:Show()
    end)
end

local function Create()
    root = CreateFrame("Frame", "RCPArsenalWorldMarkerRadial", UIParent, "SecureHandlerBaseTemplate")
    root:SetAllPoints(UIParent)
    root:SetFrameStrata("FULLSCREEN_DIALOG")
    root:EnableMouse(false)
    root:Hide()
    SecureHandlerWrapScript(root, "OnHide", cycle, HIDE)
    center = CreateFrame("Frame", nil, root, "SecureHandlerBaseTemplate")
    center:SetSize(DEADZONE * 2, DEADZONE * 2)
    center:EnableMouse(false)
    cycle:SetFrameRef("rcp-radial-root", root)
    cycle:SetFrameRef("rcp-radial-center", center)
    -- Motion-only rectangles tile the region outside the square deadzone.
    -- Showing at the cursor cannot itself count as aiming: Blizzard's secure
    -- OnEnter wrapper only runs its snippet for a genuine motion event.
    local anchors = {
        {"BOTTOM", "TOP"}, {"BOTTOMLEFT", "TOPRIGHT"},
        {"LEFT", "RIGHT"}, {"TOPLEFT", "BOTTOMRIGHT"},
        {"TOP", "BOTTOM"}, {"TOPRIGHT", "BOTTOMLEFT"},
        {"RIGHT", "LEFT"}, {"BOTTOMRIGHT", "TOPLEFT"},
    }
    for i, points in ipairs(anchors) do
        local zone = CreateFrame("Frame", nil, root, "SecureHandlerBaseTemplate")
        zone:SetSize(1, 1)
        zone:SetPoint(points[1], center, points[2], 0, 0)
        zone:EnableMouse(false)
        zone:EnableMouseMotion(true)
        cycle:SetFrameRef("rcp-radial-zone" .. i, zone)
        SecureHandlerWrapScript(zone, "OnEnter", cycle, AIM)
    end
    local cancel = CreateFrame("Button", "RCPArsenalWorldMarkerCancel", UIParent, "SecureHandlerBaseTemplate")
    cancel:SetSize(1, 1)
    cancel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    cancel:EnableMouse(false)
    cancel:RegisterForClicks("AnyDown", "AnyUp")
    cancel:SetFrameRef("cycle", cycle)
    SecureHandlerWrapScript(cancel, "OnClick", cycle, CANCEL)
    cycle:SetAttribute("rcp-radial-click", CLICK)
    cycle:SetAttribute("rcp-radial-reset", RESET)
    SecureHandlerWrapScript(cycle, "OnAttributeChanged", cycle, CONTEXT)
    cycle.RCPRadialBeginVisual, cycle.RCPRadialEndVisual = BeginVisual, EndVisual
    CreateVisual()
end

local function BaseKey(key)
    if key == nil then return nil end
    if type(issecretvalue) == "function" and issecretvalue(key) then return false end
    if type(key) ~= "string" or #key == 0 or #key > 96 or key:find("[%z\r\n]") then return false end
    key = key:upper()
    local previous
    repeat
        previous = key
        key = key:gsub("^ALT%-", ""):gsub("^CTRL%-", ""):gsub("^SHIFT%-", "")
    until previous == key
    if key == "LEFTBUTTON" then key = "BUTTON1"
    elseif key == "RIGHTBUTTON" then key = "BUTTON2"
    elseif key == "MIDDLEBUTTON" then key = "BUTTON3" end
    if key == "" or key:find("WHEEL", 1, true) or key == "BUTTON1" or key == "BUTTON2" or key == "ESCAPE" then return false end
    return key
end

local function BindingValue(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return false end
    if value == nil or type(value) == "string" then return value end
    return false
end

function Radial:NeedsBindingRefresh()
    local first, second = GetBindingKey(RA.WorldMarkers.PlaceBinding)
    return BindingValue(first) ~= bindingFirst or BindingValue(second) ~= bindingSecond
end

function Radial:Cancel()
    if InCombatLockdown() then return false end
    if cycle and cycle:GetAttribute("rcp-radial-reset") then
        SecureHandlerExecute(cycle, [[self:RunAttribute("rcp-radial-reset")]])
    end
    return true
end

function Radial:Configure(action, enabled)
    if InCombatLockdown() then return false end
    cycle = action
    self:Cancel()
    local first, second = GetBindingKey(RA.WorldMarkers.PlaceBinding)
    bindingFirst, bindingSecond = BindingValue(first), BindingValue(second)
    first, second = BaseKey(first), BaseKey(second)
    if enabled and (first == false or second == false) then
        enabled = false
        status = "Sequence mode: the wheel needs a keyboard key or side mouse button with a real release."
    else status = enabled and RA.WorldMarkers:GetModeHelp() or "Marker wheel is off." end
    if enabled and not root then Create() end
    cycle:SetAttribute("rcp-radial-enabled", enabled == true)
    cycle:SetAttribute("useOnKeyDown", enabled ~= true)
    cycle:SetAttribute("rcp-radial-key1", first or nil)
    cycle:SetAttribute("rcp-radial-key2", second or nil)
    if root then
        if enabled then
            RegisterStateDriver(cycle, "rcp-radial-context", "[petbattle] blocked; [vehicleui] blocked; ready")
        else
            UnregisterStateDriver(cycle, "rcp-radial-context")
            cycle:SetAttribute("state-rcp-radial-context", nil)
        end
    end
    return enabled == true
end

function Radial:GetStatusText() return status end

local function RefreshEditorGuard()
    local editor = RA.MarkerBindings
    local suppressed = editor and (editor:GetPending() ~= nil or editor:GetHeldKey() ~= nil)
    RA.WorldMarkers:SetInputSuppressed(suppressed == true, "editor")
end
RA:RegisterCallback("MARKER_BINDINGS_CHANGED", RefreshEditorGuard)
RA:RegisterEvent("PLAYER_LEAVING_WORLD", function() EndVisual(); Radial:Cancel() end)
RA:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    EndVisual()
    if not Radial:Cancel() and cycle and cycle:GetAttribute("rcp-radial-held") then RecoveryCue() end
end)
