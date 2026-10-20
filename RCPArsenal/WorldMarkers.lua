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
    local count = self:GetAttribute("count") or 0
    if count == 0 then return false end
    local index = self:GetAttribute("index") or 1
    local macro = self:GetAttribute("rcp-sequence-macro-" .. index)
    if not macro then return false end
    self:SetAttribute("macrotext", macro)
    index = index + 1
    if index > count then index = 1 end
    self:SetAttribute("index", index)
]]
local CLEAR_SNIPPET = [[
    if self:GetAttribute("rcp-input-suppressed") then return false end
    if not down then return false end
    if not self:GetAttribute("enabled") then return false end
    local cycle = self:GetFrameRef("cycle")
    if cycle:GetAttribute("rcp-radial-reset") then cycle:RunAttribute("rcp-radial-reset") end
    cycle:SetAttribute("index", 1)
]]

local cycle, clear
local effectiveEnabled = false
local pending = false
local inputSuppressed = false

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
    for i = 1, 8 do
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
    Notify()
    return true
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
    return "Hold and choose a marker; release to aim, then left-click the ground to place. Center release places nothing. Escape/right-click cancels."
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
    return cycle:GetAttribute("marker" .. (cycle:GetAttribute("index") or 1))
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
    if pending or not cycle then Markers:ApplyConfig() else Notify() end
end)
RA:RegisterEvent("PLAYER_REGEN_DISABLED", Notify)
RA:RegisterEvent("UPDATE_BINDINGS", function()
    if RA.MarkerRadial and Markers:GetSettings().radialEnabled == true and RA.MarkerRadial:NeedsBindingRefresh() then
        Markers:ApplyConfig()
    else Notify() end
end)
RA:RegisterEvent("GROUP_ROSTER_UPDATE", Notify)
