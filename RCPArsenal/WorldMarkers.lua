local _, RA = ...

local Markers = {}
RA.WorldMarkers = Markers

-- World-marker IDs differ from target-icon IDs. Only the artwork is shared.
Markers.Definitions = {
    { name = "Blue square", icon = 6 },
    { name = "Green triangle", icon = 4 },
    { name = "Purple diamond", icon = 3 },
    { name = "Red cross", icon = 7 },
    { name = "Yellow star", icon = 1 },
    { name = "Orange circle", icon = 2 },
    { name = "Silver moon", icon = 5 },
    { name = "White skull", icon = 8 },
}
Markers.PlaceBinding = "CLICK RCPArsenalWorldMarkerCycle:LeftButton"
Markers.ClearBinding = "CLICK RCPArsenalWorldMarkerClear:LeftButton"
_G.BINDING_HEADER_RCPARSENAL_MARKERS = "RCP Arsenal — World markers"
_G["BINDING_NAME_" .. Markers.PlaceBinding] = "Place next world marker"
_G["BINDING_NAME_" .. Markers.ClearBinding] = "Clear all world markers"

-- Runs in Blizzard's restricted handler environment BEFORE the secure action.
-- A fixed down phase prevents a key's release from advancing a second time.
local CYCLE_SNIPPET = [[
    if self:GetAttribute("rcp-input-suppressed") then return false end
    if self:GetAttribute("rcp-radial-enabled") then
        return self:RunAttribute("rcp-radial-click", button, down)
    end
    if not down then return false end
    if not self:GetAttribute("enabled") then return false end
    self:SetAttribute("macrotext", nil)
    local macro, marker, position = self:RunAttribute("rcp-next-sequence")
    if not macro then self:CallMethod("RCPMarkerTrace", "cursor-blocked", 0, 0, "");return false end
    self:SetAttribute("macrotext", macro)
    self:CallMethod("RCPMarkerTrace", "cursor", marker, position, macro)
]]
-- Native activity is queried only by ordinary code outside combat. Restricted
-- input combines that last readable snapshot with bounded local issued history;
-- neither an issued macro nor an armed reticle is a placement acknowledgment.
local NEXT_SNIPPET = [[
    local count = self:GetAttribute("count") or 0
    if count == 0 then return end
    local index = self:GetAttribute("index") or 1
    local pending = self:GetAttribute("rcp-pending-marker")
    if pending then
        for i = 1, count do
            if self:GetAttribute("marker" .. i) == pending then index = i % count + 1 end
        end
    end
    local fallback
    for offset = 0, count - 1 do
        local position = (index + offset - 1) % count + 1
        local marker = self:GetAttribute("marker" .. position)
        if not self:GetAttribute("rcp-active-" .. marker) then
            if not fallback then fallback = position end
            if not self:GetAttribute("rcp-issued-" .. marker) then fallback = position; break end
        end
    end
    -- Preserve the cycler's wrap/reuse behavior after every configured marker
    -- is active; prefer an inactive candidate whenever one exists.
    if not fallback then fallback = index end
    local marker = self:GetAttribute("marker" .. fallback)
    local macro = self:GetAttribute("rcp-sequence-macro-" .. fallback)
    if not macro then return end
    if self:GetAttribute("rcp-issued-" .. marker) then
        -- Cycle local attempts only when no unreserved candidate remains.
        for i = 1, 8 do self:SetAttribute("rcp-issued-" .. i, nil) end
    end
    self:SetAttribute("rcp-issued-" .. marker, true)
    self:SetAttribute("rcp-pending-marker", nil)
    self:SetAttribute("index", fallback % count + 1)
    return macro, marker, fallback
]]
local CLEAR_SNIPPET = [[
    if self:GetAttribute("rcp-input-suppressed") then return false end
    if not down then return false end
    if not self:GetAttribute("enabled") then return false end
    local cycle = self:GetFrameRef("cycle")
    if cycle:GetAttribute("rcp-radial-reset") then cycle:RunAttribute("rcp-radial-reset") end
    cycle:SetAttribute("index", 1)
    cycle:SetAttribute("rcp-pending-marker", nil)
    for i = 1, 8 do
        cycle:SetAttribute("rcp-issued-" .. i, nil)
        cycle:SetAttribute("rcp-active-" .. i, nil)
    end
    cycle:CallMethod("RCPMarkerTrace", "clear", 0, 1, "clear requested")
]]

local cycle, clear
local effectiveEnabled = false
local pending = false
local inputSuppressed = false
local lastAction, activityStatus, activitySubscription
local function Secret(value)
    if type(issecretvalue) ~= "function" then return true end
    local ok, result = pcall(issecretvalue, value)
    return not ok or result ~= false
end

local function CanReadActivity()
    if type(InCombatLockdown)~="function" then return false end
    local ok,value=pcall(InCombatLockdown)
    return ok and not Secret(value) and value==false
end

local function Notify()
    RA:FireCallback("WORLD_MARKERS_CHANGED")
end

local function CreateActions()
    if cycle then return end
    -- Independent of the settings window and puck: no visible overlay, and
    -- hiding settings or disabling Quick Bar cannot disable the hardware path.
    cycle = CreateFrame("Button", "RCPArsenalWorldMarkerCycle", UIParent,
        "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
    clear = CreateFrame("Button", "RCPArsenalWorldMarkerClear", UIParent,
        "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
    for _, action in ipairs({cycle, clear}) do
        action:SetSize(1, 1)
        action:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
        action:EnableMouse(false)
        action:RegisterForClicks("AnyDown", "AnyUp")
        action:SetAttribute("useOnKeyDown", true)
    end
    cycle:SetAttribute("rcp-next-sequence", NEXT_SNIPPET)
    cycle.RCPMarkerTrace=function(_,branch,marker,position,macro)
        lastAction={branch=branch,marker=marker,position=position,macro=macro}
        if branch=="clear" then activityStatus="Clear requested; activity awaits a readable resync." end
    end
    cycle:SetScript("PreClick",function(_,_,down)
        if down and not cycle:GetAttribute("rcp-radial-held") then Markers:ResyncActive() end
    end)
    clear:SetFrameRef("cycle", cycle)
    SecureHandlerWrapScript(cycle, "OnClick", cycle, CYCLE_SNIPPET)
    SecureHandlerWrapScript(clear, "OnClick", clear, CLEAR_SNIPPET)
end

function Markers:GetSettings()
    return RA:GetDB().worldMarkers
end

function Markers:ApplyConfig()
    if InCombatLockdown() then
        pending = true
        Notify()
        return false, "Changes are pending until combat ends."
    end
    CreateActions()
    local settings = self:GetSettings()
    local order = settings.order
    local radial = RA.MarkerRadial and settings.radialEnabled == true
    effectiveEnabled = settings.enabled == true
    cycle:SetAttribute("enabled", effectiveEnabled and (#order > 0 or radial))
    cycle:SetAttribute("type", effectiveEnabled and (#order > 0 or radial) and "macro" or nil)
    cycle:SetAttribute("macrotext", nil)
    cycle:SetAttribute("count", #order)
    cycle:SetAttribute("index", 1)
    cycle:SetAttribute("rcp-pending-marker", nil)
    for i = 1, 8 do
        cycle:SetAttribute("rcp-active-" .. i, nil)
        cycle:SetAttribute("rcp-issued-" .. i, nil)
        cycle:SetAttribute("marker" .. i, order[i])
        cycle:SetAttribute("rcp-sequence-macro-" .. i, order[i] and ("/wm [@cursor] " .. order[i]) or nil)
    end
    clear:SetAttribute("enabled", effectiveEnabled)
    clear:SetAttribute("type", effectiveEnabled and "worldmarker" or nil)
    clear:SetAttribute("action", "clear")
    clear:SetAttribute("marker", nil) -- Blizzard's clear-all path uses nil.
    cycle:SetAttribute("rcp-input-suppressed", inputSuppressed)
    clear:SetAttribute("rcp-input-suppressed", inputSuppressed)
    if RA.MarkerRadial then RA.MarkerRadial:Configure(cycle, effectiveEnabled and radial) end
    pending = false
    if activitySubscription then activitySubscription:SetEnabled(effectiveEnabled) end
    self:ResyncActive()
    Notify()
    return true
end

function Markers:ResyncActive()
    if not cycle or not effectiveEnabled or inputSuppressed or not CanReadActivity() then return false end
    if type(IsRaidMarkerActive) ~= "function" then activityStatus="Activity unavailable; using local issued history.";return false end
    local snapshot={}
    for marker=1,8 do
        local ok,value=pcall(IsRaidMarkerActive,marker)
        if not ok or Secret(value) or type(value)~="boolean" then
            activityStatus="Activity unreadable; using the last snapshot and local issued history."
            return false
        end
        snapshot[marker]=value
    end
    -- Commit the complete snapshot only. A cancelled/failed reticle is not an
    -- active marker; an existing active marker is not proof of who placed it.
    local selected=cycle:GetAttribute("rcp-pending-marker")
    if selected and snapshot[selected] then
        for position,marker in ipairs(self:GetSettings().order) do
            if marker==selected then cycle:SetAttribute("index",position % #self:GetSettings().order + 1) end
        end
    end
    for marker=1,8 do
        cycle:SetAttribute("rcp-active-" .. marker,snapshot[marker])
        cycle:SetAttribute("rcp-issued-" .. marker,nil)
    end
    cycle:SetAttribute("rcp-pending-marker",nil)
    activityStatus="Readable activity snapshot; inactive markers are preferred, then the configured order wraps."
    return true
end
function Markers:GetActivityStatusText()
    if not effectiveEnabled then return "Marker tool is off." end
    return not CanReadActivity() and "Combat/unknown context uses the last readable snapshot and local issued choices; pending/cancelled reticles may remain reserved until a safe resync." or activityStatus or "Local issued history only."
end
function Markers:GetLastAction()
    if not lastAction then return nil end
    return {branch=lastAction.branch,marker=lastAction.marker,position=lastAction.position,macro=lastAction.macro}
end

function Markers:SetEnabled(enabled)
    if InCombatLockdown() then return false, "Change this after combat." end
    self:GetSettings().enabled = enabled == true
    return self:ApplyConfig()
end

function Markers:SetOrder(order)
    if InCombatLockdown() then return false, "Change this after combat." end
    local settings = self:GetSettings()
    local normalized = RA:NormalizeWorldMarkerSettings({enabled = settings.enabled, order = order})
    settings.order = normalized.order
    return self:ApplyConfig()
end

function Markers:SetRadialEnabled(enabled)
    if InCombatLockdown() then return false, "Change this after combat." end
    if not RA.MarkerRadial then return false, "Marker wheel is unavailable." end
    self:GetSettings().radialEnabled = enabled == true
    return self:ApplyConfig()
end

function Markers:IsRadialEnabled()
    return cycle and cycle:GetAttribute("rcp-radial-enabled") == true or false
end

function Markers:GetModeHelp()
    if #self:GetSettings().order == 0 then
        return "Marker order empty: center release does nothing. Choose an outer marker; release to aim, then click ground. Right-click/Escape cancels."
    end
    return "Center release places the next available sequence marker, even after a long hold. Inactive markers are preferred; when all are active the order wraps and reuses. Choose a sector; release to aim, then left-click ground. Right-click/Escape cancels."
end

function Markers:GetRadialStatusText()
    return RA.MarkerRadial and RA.MarkerRadial:GetStatusText() or "Marker wheel is unavailable."
end

-- The key editor keeps this set through the matching captured release. If an
-- editor is closed by combat, keep the existing secure guard until safe again.
local suppressionOwners = {}
function Markers:SetInputSuppressed(suppressed, owner)
    owner = owner or "editor"
    if owner ~= "editor" and owner ~= "placement" then return false end
    suppressionOwners[owner] = suppressed == true or nil
    inputSuppressed = suppressionOwners.editor == true or suppressionOwners.placement == true
    if InCombatLockdown() then pending = true; return false end
    if not cycle then return true end
    if RA.MarkerRadial then RA.MarkerRadial:Cancel() end
    cycle:SetAttribute("rcp-input-suppressed", inputSuppressed)
    clear:SetAttribute("rcp-input-suppressed", inputSuppressed)
    return true
end

function Markers:GetNextMarker()
    if not cycle or not effectiveEnabled or self:IsRadialEnabled() then return nil end
    local count=cycle:GetAttribute("count") or 0
    if count==0 then return nil end
    local start=cycle:GetAttribute("index") or 1
    local selected=cycle:GetAttribute("rcp-pending-marker")
    for i=1,count do if cycle:GetAttribute("marker"..i)==selected then start=i%count+1 end end
    local fallback
    for offset=0,count-1 do
        local marker=cycle:GetAttribute("marker"..((start+offset-1)%count+1))
        if not cycle:GetAttribute("rcp-active-"..marker) then
            fallback=fallback or marker
            if not cycle:GetAttribute("rcp-issued-"..marker) then return marker end
        end
    end
    return fallback or cycle:GetAttribute("marker"..start)
end

function Markers:GetState()
    return effectiveEnabled, pending
end

function Markers:GetPermissionText()
    if IsInRaid() and not UnitIsGroupLeader("player") and not UnitIsGroupAssistant("player") then
        return "Requires raid leader or assist. You can set up your order now."
    end
    return "In raids, placement and clearing require leader or assist. Blizzard checks permissions and valid terrain."
end

function Markers:GetBindingText(action)
    local first, second = GetBindingKey(action)
    if not first then return "Unbound" end
    return first .. (second and (" / " .. second) or "")
end

RA:RegisterInitializer(function() Markers:ApplyConfig() end)
RA:RegisterCallback("PROFILE_RESET", function() Markers:ApplyConfig() end)
RA:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    if pending or not cycle then Markers:ApplyConfig() else Markers:ResyncActive();Notify() end
end)
RA:RegisterEvent("PLAYER_REGEN_DISABLED", Notify)
RA:RegisterEvent("UPDATE_BINDINGS", function()
    if RA.MarkerRadial and Markers:GetSettings().radialEnabled == true and RA.MarkerRadial:NeedsBindingRefresh() then
        Markers:ApplyConfig()
    else Notify() end
end)
RA:RegisterEvent("GROUP_ROSTER_UPDATE", Notify)

activitySubscription=RA:RegisterOptionalEvent("RAID_TARGET_UPDATE",function() Markers:ResyncActive();Notify() end)
