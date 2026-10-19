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
    if not down then return false end
    if not self:GetAttribute("enabled") then return false end
    self:GetFrameRef("cycle"):SetAttribute("index", 1)
]]

local cycle, clear
local effectiveEnabled = false
local pending = false

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
    effectiveEnabled = settings.enabled == true
    cycle:SetAttribute("enabled", effectiveEnabled and #order > 0)
    cycle:SetAttribute("type", effectiveEnabled and #order > 0 and "macro" or nil)
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

function Markers:GetNextMarker()
    if not cycle or not effectiveEnabled then return nil end
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
RA:RegisterEvent("UPDATE_BINDINGS", Notify)
RA:RegisterEvent("GROUP_ROSTER_UPDATE", Notify)
