local _, RA = ...

local Radial = {}
RA.MarkerRadial = Radial

local cycle, root, center, visual, router
local bindingFirst, bindingSecond
local status = "Marker wheel is off."
local RADIUS = 92

-- Every action is chosen by real hardware input. No elapsed-time or pointer
-- classifier controls the key release; clicking an icon consumes that gesture.
local KEY_ROUTES = [[
    for i = 1, 2 do
        local key = self:GetAttribute("rcp-radial-key" .. i)
        if key then
            for mask = 0, 7 do
                local chord = key
                if mask % 2 == 1 then chord = "SHIFT-" .. chord end
                if math.floor(mask / 2) % 2 == 1 then chord = "CTRL-" .. chord end
                if mask >= 4 then chord = "ALT-" .. chord end
                self:SetBindingClick(true, chord, self:GetName(), key)
            end
        end
    end
]]
local RESET = [[
    local reason = ...
    local source = self:GetAttribute("rcp-radial-source")
    local keepRelease = source and reason ~= "release" and reason ~= "force"
    self:SetAttribute("rcp-radial-held", nil)
    self:SetAttribute("rcp-radial-consumed", keepRelease and true or nil)
    self:SetAttribute("rcp-radial-source", keepRelease and source or nil)
    if reason == "force" then
        for i = 1, 2 do
            local key = self:GetAttribute("rcp-radial-key" .. i)
            if key then self:SetAttribute("rcp-key-down-" .. key, nil) end
        end
    end
    self:SetAttribute("rcp-icon-down", nil)
    self:SetAttribute("rcp-origin-width", nil)
    self:SetAttribute("rcp-origin-height", nil)
    self:SetAttribute("rcp-origin-scale", nil)
    self:SetAttribute("macrotext", nil)
    self:ClearBindings()
    local draining = keepRelease
    for i = 1, 2 do
        local key = self:GetAttribute("rcp-radial-key" .. i)
        if key and self:GetAttribute("rcp-key-down-" .. key) then draining = true end
    end
    if draining then self:RunAttribute("rcp-radial-key-routes") end
    self:GetFrameRef("rcp-radial-root"):Hide()
]]
local CLICK = [[
    local button, down = ...
    if button ~= self:GetAttribute("rcp-radial-key1") and button ~= self:GetAttribute("rcp-radial-key2") then return false end
    if down then
        if self:GetAttribute("rcp-key-down-" .. button) then return false end
        self:SetAttribute("rcp-key-down-" .. button, true)
    else
        self:SetAttribute("rcp-key-down-" .. button, nil)
    end
    local source = self:GetAttribute("rcp-radial-source")
    if source and source ~= button then return false end
    if self:GetAttribute("rcp-radial-consumed") then
        if not down then self:RunAttribute("rcp-radial-reset", "release") end
        return false
    end
    if not self:GetAttribute("enabled") or self:GetAttribute("rcp-input-suppressed")
        or self:GetAttribute("state-rcp-radial-context") == "blocked" then
        if self:GetAttribute("rcp-radial-held") then self:RunAttribute("rcp-radial-reset") end
        return false
    end
    if down then
        if self:GetAttribute("rcp-radial-held") then return false end
        self:SetAttribute("macrotext", nil)
        local root = self:GetFrameRef("rcp-radial-root")
        local x,y = root:GetMousePosition()
        local left,bottom,width,height = root:GetRect()
        local scale = root:GetEffectiveScale()
        if not x or not y or not left or not bottom or not width or not height or not scale or scale <= 0 then return false end
        self:SetAttribute("rcp-radial-held", true)
        self:SetAttribute("rcp-radial-source", button)
        self:SetAttribute("rcp-origin-width", width)
        self:SetAttribute("rcp-origin-height", height)
        self:SetAttribute("rcp-origin-scale", scale)
        local center = self:GetFrameRef("rcp-radial-center")
        center:ClearAllPoints()
        center:SetPoint("CENTER", "$cursor", "BOTTOMLEFT", 0, 0)
        self:RunAttribute("rcp-radial-key-routes")
        for mask = 0, 7 do
            local prefix = ""
            if mask % 2 == 1 then prefix = "SHIFT-" .. prefix end
            if math.floor(mask / 2) % 2 == 1 then prefix = "CTRL-" .. prefix end
            if mask >= 4 then prefix = "ALT-" .. prefix end
            self:SetBindingClick(true, prefix .. "ESCAPE", "RCPArsenalWorldMarkerCancel", "LeftButton")
            self:SetBindingClick(true, prefix .. "BUTTON2", "RCPArsenalWorldMarkerCancel", "LeftButton")
        end
        self:CallMethod("RCPRadialBeginVisual")
        root:Show()
        return false
    end
    if not self:GetAttribute("rcp-radial-held") then
        local draining
        for i = 1, 2 do
            local key = self:GetAttribute("rcp-radial-key" .. i)
            if key and self:GetAttribute("rcp-key-down-" .. key) then draining = true end
        end
        if not draining then self:ClearBindings() end
        return false
    end
    local incompleteClick = self:GetAttribute("rcp-icon-down")
    self:RunAttribute("rcp-radial-reset", "release")
    if incompleteClick then self:CallMethod("RCPMarkerTrace", "icon-cancelled", 0, 0, "");return false end
    local macro, marker, position = self:RunAttribute("rcp-next-sequence")
    if not macro then self:CallMethod("RCPMarkerTrace", "release-blocked", 0, 0, ""); return false end
    self:SetAttribute("macrotext", macro)
    self:CallMethod("RCPMarkerTrace", "release", marker, position, macro)
]]
local ICON_CLICK = [[
    local cycle = self:GetFrameRef("cycle")
    if button ~= "LeftButton" or not self:IsVisible() or not cycle:GetAttribute("rcp-radial-held")
        or cycle:GetAttribute("rcp-radial-consumed") or not cycle:GetAttribute("enabled")
        or cycle:GetAttribute("rcp-input-suppressed") or cycle:GetAttribute("state-rcp-radial-context") == "blocked" then return false end
    local root = cycle:GetFrameRef("rcp-radial-root")
    local left,bottom,width,height = root:GetRect()
    if width ~= cycle:GetAttribute("rcp-origin-width") or height ~= cycle:GetAttribute("rcp-origin-height")
        or root:GetEffectiveScale() ~= cycle:GetAttribute("rcp-origin-scale") then
        cycle:RunAttribute("rcp-radial-reset"); return false
    end
    local marker = self:GetAttribute("rcp-marker")
    if down then cycle:SetAttribute("rcp-icon-down", marker); return false end
    local pressed = cycle:GetAttribute("rcp-icon-down")
    cycle:SetAttribute("rcp-icon-down", nil)
    if pressed ~= marker then return false end
    cycle:SetAttribute("rcp-radial-held", nil)
    cycle:SetAttribute("rcp-radial-consumed", true)
    cycle:SetAttribute("macrotext", nil)
    cycle:SetAttribute("rcp-issued-" .. marker, true)
    cycle:SetAttribute("rcp-pending-marker", marker)
    cycle:CallMethod("RCPMarkerTrace", "icon", marker, 0, self:GetAttribute("macrotext"))
    return nil, "selected"
]]
local ICON_POST = [[
    if message == "selected" then self:GetFrameRef("cycle"):RunAttribute("rcp-radial-reset") end
]]
local CANCEL = [[
    if not down then return false end
    local cycle = self:GetFrameRef("cycle")
    if cycle:GetAttribute("rcp-radial-held") then cycle:RunAttribute("rcp-radial-reset") end
    return false
]]
local CONTEXT = [[
    if name == "state-rcp-radial-context" and value == "blocked" then self:RunAttribute("rcp-radial-reset") end
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
    Text(visual.choice, "CANCEL WHEEL")
    Text(visual.hint, "Right-click or Escape")
end

local function CreateVisual()
    -- Artwork belongs to the actual protected click targets. Their secure
    -- parent shows/hides the entire wheel; no invisible delayed hitboxes.
    visual = center
    Surface(visual, {0.035, 0.036, 0.070, 0.90})
    visual.slots = {}
    for i, definition in ipairs(RA.WorldMarkers.Definitions) do
        local slot = CreateFrame("Button", "RCPArsenalWorldMarkerIcon" .. i, center,
            "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
        local angle = (i - 1) * math.pi / 4
        slot:SetSize(42, 42)
        slot:SetPoint("CENTER", center, "CENTER", math.sin(angle) * RADIUS, math.cos(angle) * RADIUS)
        slot:EnableMouse(true)
        slot:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
        slot:SetAttribute("useOnKeyDown", false)
        slot:SetAttribute("type", "macro")
        slot:SetAttribute("macrotext", "/wm " .. i)
        slot:SetAttribute("rcp-marker", i)
        slot:SetFrameRef("cycle", cycle)
        SecureHandlerWrapScript(slot, "OnClick", cycle, ICON_CLICK, ICON_POST)
        Surface(slot, {0.085, 0.091, 0.151, 0.95})
        slot.highlight = slot:CreateTexture(nil, "BORDER")
        slot.highlight:SetAllPoints()
        local color = RA.Theme and RA.Theme:GetAccentEnd() or {0.973, 0.608, 0.161, 1}
        slot.highlight:SetColorTexture(unpack(color))
        slot.highlight:SetAlpha(0)
        slot:SetScript("OnEnter", function() slot.highlight:SetAlpha(1) end)
        slot:SetScript("OnLeave", function() slot.highlight:SetAlpha(0) end)
        slot.icon = slot:CreateTexture(nil, "ARTWORK")
        slot.icon:SetSize(30, 30)
        slot.icon:SetPoint("CENTER")
        local texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. definition.icon
        if RA.SetVisualTexture then RA:SetVisualTexture(slot.icon, texture) else slot.icon:SetTexture(texture) end
        visual.slots[i] = slot
    end
    visual.choice, visual.hint, visual.help = Label(visual, 11), Label(visual, 9), Label(visual, 9)
    visual.choice:SetPoint("CENTER", visual, "CENTER", 0, 12)
    visual.hint:SetPoint("CENTER", visual, "CENTER", 0, -6)
    visual.help:SetPoint("BOTTOM", visual, "BOTTOM", 0, 8)
    cycle.RCPRadialBeginVisual = function()
        Text(visual.choice, "Release key: next marker")
        Text(visual.hint, "Click icon: aim, then click ground")
        Text(visual.help, "Right-click / Escape cancels")
    end
    cycle:RCPRadialBeginVisual()
end

local function Create()
    root = CreateFrame("Button", "RCPArsenalWorldMarkerRadial", UIParent, "SecureHandlerBaseTemplate")
    root:SetAllPoints(UIParent)
    root:SetFrameStrata("FULLSCREEN_DIALOG")
    -- A hardware right-click surface covers the screen for the entire hold,
    -- including cursor positions outside the wheel.
    root:EnableMouse(true)
    root:RegisterForClicks("RightButtonDown", "RightButtonUp")
    local passthrough = {"LeftButton", "MiddleButton"}
    for button = 4, 31 do passthrough[#passthrough + 1] = "Button" .. button end
    root:SetPassThroughButtons(unpack(passthrough))
    root:SetFrameRef("cycle", cycle)
    SecureHandlerWrapScript(root, "OnClick", cycle, CANCEL)
    root:Hide()
    SecureHandlerWrapScript(root, "OnHide", cycle, HIDE)
    center = CreateFrame("Frame", nil, root, "SecureHandlerBaseTemplate")
    center:SetSize(282, 282)
    center:EnableMouse(false)
    cycle:SetFrameRef("rcp-radial-root", root)
    cycle:SetFrameRef("rcp-radial-center", center)
    local cancel = CreateFrame("Button", "RCPArsenalWorldMarkerCancel", UIParent, "SecureHandlerBaseTemplate")
    cancel:SetSize(1, 1)
    cancel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    cancel:EnableMouse(false)
    cancel:RegisterForClicks("AnyDown", "AnyUp")
    cancel:SetFrameRef("cycle", cycle)
    SecureHandlerWrapScript(cancel, "OnClick", cycle, CANCEL)
    cycle:SetAttribute("rcp-radial-key-routes", KEY_ROUTES)
    cycle:SetAttribute("rcp-radial-click", CLICK)
    cycle:SetAttribute("rcp-radial-reset", RESET)
    SecureHandlerWrapScript(cycle, "OnAttributeChanged", cycle, CONTEXT)
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
        SecureHandlerExecute(cycle, [[self:RunAttribute("rcp-radial-reset", "force")]])
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
    -- The saved native CLICK command cannot identify which bound key began a
    -- gesture. A separate OOC-configured router tags each initial down/up with
    -- its physical base key; temporary secure routes retain that identity after
    -- modifiers change. Saved binding commands and editor identities stay put.
    if enabled and not router then
        router = CreateFrame("Frame", "RCPArsenalWorldMarkerInputRouter", UIParent, "SecureHandlerBaseTemplate")
        router:SetFrameRef("cycle", cycle)
    end
    if router then
        router:SetAttribute("chord1", enabled and bindingFirst or nil)
        router:SetAttribute("chord2", enabled and bindingSecond or nil)
        router:SetAttribute("source1", first or nil)
        router:SetAttribute("source2", second or nil)
        SecureHandlerExecute(router, [[
            self:ClearBindings()
            for i = 1, 2 do
                local chord = self:GetAttribute("chord" .. i)
                local source = self:GetAttribute("source" .. i)
                if chord and source then self:SetBindingClick(true, chord, self:GetFrameRef("cycle"):GetName(), source) end
            end
        ]])
    end
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
RA:RegisterEvent("PLAYER_LEAVING_WORLD", function() if not Radial:Cancel() then RecoveryCue() end end)
RA:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    if not Radial:Cancel() and cycle and cycle:GetAttribute("rcp-radial-held") then RecoveryCue() end
end)
