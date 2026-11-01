local _, RA = ...
local Entry = {}
RA.DeathRecapEntry = Entry
local R, UI, T = RA.DeathRecap, RA.DeathRecapUI, RA.Theme
local C = T.Colors
local button, token, anchor, layoutHost, placement, shownPage
local binding, pulsing, hovered = 0, false, false
local hooks, subscriptions = {}, {}
local hookDemand

local function Public(value)
    if type(issecretvalue) ~= "function" then return nil end
    local ok, secret = pcall(issecretvalue, value)
    if ok and secret == false then return value end
end
local function Read(object, key)
    local ok, value = pcall(function() return object[key] end)
    if ok then return Public(value) end
end
local function Call(object, method, ...)
    local fn = Read(object, method)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, object, ...)
    if ok then return Public(value) end
end
local function Global(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return Public(value) end
end
local function Number(value)
    value = Public(value)
    if type(value) == "number" and value == value and value > -math.huge and value < math.huge then return value end
end
local function Mutable(frame)
    local ok, method = pcall(function() return frame.CanChangeProtectedState end)
    if not ok or type(issecretvalue) ~= "function" then return false end
    local checked, secret = pcall(issecretvalue, method)
    if not checked or secret ~= false then return false end
    if method == nil then return true end -- Older surfaces may omit this accessor.
    if type(method) ~= "function" then return false end
    local called, allowed = pcall(method, frame)
    return called and Public(allowed) == true
end
local function Accessible(frame)
    frame = Public(frame)
    if type(frame) ~= "table" and type(frame) ~= "userdata" then return nil end
    if Call(frame, "IsForbidden") ~= false then return nil end
    return frame
end
local function Visible(frame)
    return Accessible(frame) and Call(frame, "IsShown") == true and Call(frame, "IsVisible") == true
end
local function Host()
    local frame = Global(StaticPopup_FindVisible, "DEATH")
    if Visible(frame) and Read(frame, "which") == "DEATH" then return frame end
end
local function Enabled()
    local state = R:GetState()
    return state and state.enabled == true
end
local function OwnDeath()
    return Global(UnitIsDeadOrGhost, "player") == true and Global(UnitIsGhost, "player") == false
end
local function Current()
    if not token or not Enabled() or not OwnDeath() or button and not Mutable(button) then return false end
    local page = R:GetPage()
    return page == token.page and page.id == token.id and page.captureGeneration == token.generation
end
local function HideTooltip()
    if button and GameTooltip and Call(GameTooltip, "GetOwner") == button then pcall(GameTooltip.Hide, GameTooltip) end
end
local function StopGlow()
    if not button then return end
    if pulsing then button.pulse:Stop(); pulsing = false end
    button.glow:SetAlpha(.10)
    button.glow:Hide()
end
local function Hide(clearPlacement)
    binding = binding + 1
    anchor = nil
    if clearPlacement then layoutHost, placement = nil, nil end
    hovered = false
    if button then
        StopGlow(); HideTooltip()
        button:SetScript("OnClick", nil)
        button:Hide()
    end
end
local function Clear()
    token, shownPage = nil, nil
    Hide(true)
end
local function Paint()
    if not button then return end
    T:SetRoundedColor(button, hovered and C.surfaceHover or C.surfaceRaised, "base")
    T:SetRoundedColor(button, {C.magenta[1], C.magenta[2], C.magenta[3], hovered and .80 or .45}, "border")
    T:SetRoundedColor(button.glow, {C.magenta[1], C.magenta[2], C.magenta[3], 1}, "border")
end
local function Attention()
    if not button or not button:IsVisible() or not token or token.viewed or hovered then StopGlow(); return end
    button.glow:Show()
    if not pulsing then button.glow:SetAlpha(.10); button.pulse:Play(); pulsing = true end
end
local function EnsureButton()
    if button and button.entryConfigured then return true end
    if not button then button = CreateFrame("Button", "RCPArsenalDeathRecapEntry", UIParent); button:Hide() end
    if not Mutable(button) then return false end
    button:SetFrameStrata("DIALOG"); button:SetFrameLevel(100); button:RegisterForClicks("LeftButtonUp")
    T.SetSize(button, 144, 34)
    T:ApplyRounded(button, C.surfaceRaised, 6, "base")
    T:ApplyRounded(button, {C.magenta[1], C.magenta[2], C.magenta[3], .45}, 6, "border", "OVERLAY")
    button.logo = button:CreateTexture(nil, "ARTWORK")
    T.SetSize(button.logo, 24, 24); T.SetPoint(button.logo, "TOPLEFT", button, "TOPLEFT", 8, -5)
    button.logo:SetVertexColor(1, 1, 1)
    T:RegisterAssetTexture(button.logo, T.Assets.HeaderLogo, nil, "LINEAR")
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    RA:ApplyFont(button.label, 13, "BOLD", false)
    button.label:SetTextColor(unpack(C.text)); button.label:SetJustifyH("LEFT")
    T.SetSize(button.label, 96, 18); T.SetPoint(button.label, "LEFT", button, "LEFT", 40, 0)
    RA:SetVisualText(button.label, "Death Log")
    button.glow = CreateFrame("Frame", nil, button)
    button.glow:EnableMouse(false)
    T.SetPoint(button.glow, "TOPLEFT", button, "TOPLEFT", -2, 2)
    T.SetPoint(button.glow, "BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
    T:ApplyRounded(button.glow, {C.magenta[1], C.magenta[2], C.magenta[3], 1}, 6, "border", "OVERLAY")
    button.glow:SetAlpha(.10); button.glow:Hide()
    button.pulse = button.glow:CreateAnimationGroup(); button.pulse:SetLooping("REPEAT")
    for order, values in ipairs({{.10, .22}, {.22, .10}}) do
        local animation = button.pulse:CreateAnimation("Alpha")
        animation:SetOrder(order); animation:SetDuration(1.4)
        animation:SetFromAlpha(values[1]); animation:SetToAlpha(values[2]); animation:SetSmoothing("IN_OUT")
    end
    button:SetScript("OnHide", function() StopGlow(); HideTooltip(); hovered = false end)
    button:SetScript("OnEnter", function(self)
        if not Current() or anchor ~= Host() then Hide(true); return end
        hovered = true; Paint(); Attention()
        local text = "Open your captured log."
        local page = token.page
        if not page.native then
            text = text .. (R:GetDiagnostics().fetchPending and " Hit details are loading." or " Hit details are unavailable.")
        end
        if GameTooltip then GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(text); GameTooltip:Show() end
    end)
    button:SetScript("OnLeave", function() hovered = false; HideTooltip(); Paint(); Attention() end)
    button:SetScript("OnMouseDown", function() T:SetRoundedColor(button, C.surfacePressed, "base") end)
    button:SetScript("OnMouseUp", Paint)
    button.entryConfigured = true
    return true
end
local function Bounds(frame)
    if not Accessible(frame) then return nil end
    local scale = Number(Call(frame, "GetEffectiveScale"))
    local left, right = Number(Call(frame, "GetLeft")), Number(Call(frame, "GetRight"))
    local top, bottom = Number(Call(frame, "GetTop")), Number(Call(frame, "GetBottom"))
    if not scale or scale <= 0 or not left or not right or not top or not bottom or right <= left or top <= bottom then return nil end
    return {left=left*scale, right=right*scale, top=top*scale, bottom=bottom*scale}
end
local function Place(host)
    if not Mutable(button) then return false end
    local bounds, screen = Bounds(host), Bounds(UIParent)
    local scale = Number(Call(UIParent, "GetEffectiveScale"))
    if not bounds or not screen or not scale or scale <= 0 then return false end
    local action = Call(host, "GetButton", 4)
    if not Visible(action) then action = Call(host, "GetButton", 1) end
    local actionBounds = Visible(action) and Bounds(action) or nil
    local center = actionBounds and (actionBounds.top + actionBounds.bottom)/2
    local w, h, gap, clearance = 144*scale, 34*scale, 8*scale, 10*scale
    local middle = (bounds.left + bounds.right)/2
    local function Fits(left, right, bottom, top)
        return left >= screen.left+clearance and right <= screen.right-clearance
            and bottom >= screen.bottom+clearance and top <= screen.top-clearance
    end
    local rightFits = center and Fits(bounds.right+gap, bounds.right+gap+w, center-h/2, center+h/2)
    local belowFits = Fits(middle-w/2, middle+w/2, bounds.bottom-gap-h, bounds.bottom-gap)
    local mode = layoutHost == host and placement or nil
    if mode == "right" and not rightFits or mode == "below" and not belowFits then mode = nil end
    mode = mode or (rightFits and "right" or belowFits and "below")
    if not mode then return false end
    button:ClearAllPoints()
    if mode == "right" then
        T.SetPoint(button, "LEFT", host, "RIGHT", 8, (center-(bounds.top+bounds.bottom)/2)/scale)
    else T.SetPoint(button, "TOP", host, "BOTTOM", 0, -8) end
    layoutHost, placement = host, mode
    return true
end
local function RefreshNow()
    if not hooks.StaticPopup_Show or not hooks.StaticPopup_OnShow or not hooks.StaticPopup_OnHide then Hide(true); return end
    if not Current() then Hide(true); return end
    local host = Host()
    if not host then Hide(true); return end
    if Call(UI, "IsShown") ~= false then Hide(false); return end
    if not EnsureButton() then Hide(true); return end
    if not Place(host) then Hide(true); return end
    anchor = host; binding = binding + 1
    local clickBinding, clickToken = binding, token
    button:SetScript("OnClick", function()
        if clickBinding ~= binding or clickToken ~= token or anchor ~= host or not Current()
            or Host() ~= host or Call(UI, "IsShown") ~= false then return end
        if UI:ShowLast() == true and token == clickToken then token.viewed = true end
        Entry:Refresh()
    end)
    Paint(); button:Show(); Attention()
end
function Entry:Refresh()
    local ok = pcall(RefreshNow)
    if not ok then pcall(Hide, true) end
end
local function InstallHooks()
    if type(hooksecurefunc) ~= "function" then return end
    local callbacks = {
        StaticPopup_Show = function(which)
            if token and Public(which) == "DEATH" then Entry:Refresh() end
        end,
        StaticPopup_OnShow = function(dialog)
            dialog = Accessible(dialog)
            if token and dialog and (Read(dialog, "which") == "DEATH" or dialog == anchor) then Entry:Refresh() end
        end,
        StaticPopup_OnHide = function(dialog)
            dialog = Public(dialog)
            if dialog and (dialog == anchor or dialog == layoutHost) then Hide(true) end
        end,
    }
    for name, callback in pairs(callbacks) do
        if not hooks[name] and type(_G[name]) == "function" then
            local ok = pcall(hooksecurefunc, name, function(...) pcall(callback, ...) end)
            if ok then hooks[name] = true end
        end
    end
    if hookDemand and hooks.StaticPopup_Show and hooks.StaticPopup_OnShow and hooks.StaticPopup_OnHide then hookDemand:SetEnabled(false) end
end
local function Settings()
    local enabled = Enabled()
    for _, subscription in ipairs(subscriptions) do subscription:SetEnabled(enabled) end
    if not enabled then Clear() end
    InstallHooks(); Entry:Refresh()
end
for _, event in ipairs({"PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_LEAVING_WORLD", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT"}) do
    subscriptions[#subscriptions+1] = RA:RegisterOptionalEvent(event, function()
        if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            local debug = RA.DeathRecapDebug
            if debug and type(debug.StopCooldownCapture) == "function" then pcall(debug.StopCooldownCapture, debug, "world-transition") end
        end
        Clear()
    end)
end
for _, event in ipairs({"DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED"}) do
    subscriptions[#subscriptions+1] = RA:RegisterOptionalEvent(event, function() Entry:Refresh() end)
end
hookDemand = RA:RegisterOptionalEvent("ADDON_LOADED", InstallHooks)
RA:RegisterInitializer(function() hookDemand:SetEnabled(true); Settings() end)
RA:RegisterCallback("DEATH_RECAP_CHANGED", function(kind)
    if kind == "death" then
        local page = R:GetPage()
        if Enabled() and OwnDeath() and type(page) == "table" and Number(page.id) and Number(page.captureGeneration) then
            if not token or token.page ~= page or token.generation ~= page.captureGeneration then
                Hide(true)
                token = {page=page, id=page.id, generation=page.captureGeneration,
                    viewed=shownPage == page and Call(UI, "IsShown") == true}
            end
        else Clear() end
    elseif kind == "life" or kind == "reset" or kind == "unavailable" then Clear()
    elseif kind == "settings" then Settings(); return end
    Entry:Refresh()
end)
RA:RegisterCallback("DEATH_RECAP_VISIBILITY", function(shown, page)
    local visible = Call(UI, "IsShown") == true
    shownPage = shown == true and visible and page or nil
    if shown == true and visible and Current() and page == token.page then token.viewed = true end
    Entry:Refresh()
end)
RA:RegisterCallback("PROFILE_RESET", function() Clear(); Settings() end)
RA:RegisterCallback("PROFILE_IMPORTED", function() Clear(); Settings() end)
RA:RegisterCallback("ACCENT_THEME_CHANGED", function() Paint() end)
