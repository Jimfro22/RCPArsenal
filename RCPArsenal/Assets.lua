local _, RA = ...

-- Visual recovery owns no frames, secure attributes, layout, or inspection.
-- Keep failed registrations: SetTexture/SetFont success does not establish
-- that the client has rendered the resource yet. A small warm-up burst also
-- reapplies successful resources, then stops until another visible demand.
local registrations = setmetatable({}, {__mode = "k"})
local requestedSpells = {}
local retryDelays = {0.10, 0.25, 0.65, 1.50, 3.00, 6.00}
local retryTimer
local retryIndex = 0
local generation = 0
local refreshing = false
local FALLBACK_ICON = 134400

local function IsVisible(region)
    if region.IsVisible then return region:IsVisible() end
    if region.IsShown and not region:IsShown() then return false end
    local parent = region.GetParent and region:GetParent()
    if parent and parent ~= region then return IsVisible(parent) end
    return true
end

local function HasVisibleAssets()
    for region in pairs(registrations) do
        if IsVisible(region) then return true end
    end
    return false
end

function RA:CancelVisualAssetRefresh()
    generation = generation + 1
    if retryTimer and retryTimer.Cancel then retryTimer:Cancel() end
    retryTimer = nil
    retryIndex = 0
end

local function SetTexture(region, asset, entry)
    if asset == nil or asset == "" or asset == 0 then return false end
    local ok, result
    if entry.filterMode then
        ok, result = pcall(region.SetTexture, region, asset, "CLAMP", "CLAMP", entry.filterMode)
        if not ok then ok, result = pcall(region.SetTexture, region, asset) end
    else
        ok, result = pcall(region.SetTexture, region, asset)
    end
    -- pcall's status only says the call did not throw. Retail returns false
    -- when the requested texture could not be set.
    if not ok or result == false then return false end
    if region.GetTexture then
        local readOK, texture = pcall(region.GetTexture, region)
        if readOK and (texture == nil or texture == "" or texture == 0) then return false end
    end
    return true
end

local function GetSpellIcon(spellID)
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, icon = pcall(C_Spell.GetSpellTexture, spellID)
        if ok and icon and icon ~= 0 and icon ~= "" then return icon end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and info and info.iconID and info.iconID ~= 0 then return info.iconID end
    end
end

local function RefreshRegistration(region, entry)
    if entry.kind == "font" then
        if RA.ApplyFont then
            entry.ready = RA:ApplyFont(region, entry.size, entry.weight, entry.shadow, true)
            -- Reapplying a font must also invalidate an already assigned glyph.
            if region.GetText and region.SetText then
                local text = region:GetText()
                if text ~= nil then region:SetText(text) end
            end
        end
        return
    end

    local asset = entry.asset
    if entry.spellID then
        asset = GetSpellIcon(entry.spellID)
        if not asset and IsVisible(region) and not requestedSpells[entry.spellID] and C_Spell and C_Spell.RequestLoadSpellData then
            requestedSpells[entry.spellID] = true
            pcall(C_Spell.RequestLoadSpellData, entry.spellID)
        end
    elseif entry.resolve then
        asset = entry.resolve()
    end
    entry.ready = SetTexture(region, asset, entry)
    entry.usingFallback = not entry.ready
    if not entry.ready then SetTexture(region, entry.fallback or FALLBACK_ICON, entry) end
end

local function RefreshOne(region, entry)
    -- One rejected resource must not abort the rest of a pass or strand the
    -- broker in its refreshing state. Retain it for the remaining attempts.
    local ok = pcall(RefreshRegistration, region, entry)
    if not ok then
        entry.ready = false
        if entry.kind == "texture" then SetTexture(region, entry.fallback or FALLBACK_ICON, entry) end
    end
end

function RA:RefreshVisualAssets()
    if refreshing then return end
    refreshing = true
    for region, entry in pairs(registrations) do
        if IsVisible(region) then RefreshOne(region, entry) end
    end
    refreshing = false
end

local function ScheduleNextRetry()
    if retryIndex >= #retryDelays or not HasVisibleAssets() then
        RA:CancelVisualAssetRefresh()
        return
    end
    retryIndex = retryIndex + 1
    local token = generation
    retryTimer = C_Timer.NewTimer(retryDelays[retryIndex], function()
        if generation ~= token then return end
        retryTimer = nil
        RA:RefreshVisualAssets()
        ScheduleNextRetry()
    end)
end

function RA:RequestVisualAssetRefresh()
    if not self.Initialized or refreshing or retryTimer or not HasVisibleAssets() then return end
    if C_Timer and C_Timer.NewTimer then
        retryIndex = 0
        ScheduleNextRetry()
    else
        self:RefreshVisualAssets()
    end
end

function RA:WatchVisualAssets(frame)
    if not frame or not frame.HookScript or frame.__rcpaAssetWatch then return end
    frame.__rcpaAssetWatch = true
    frame:HookScript("OnShow", function() RA:RequestVisualAssetRefresh() end)
    frame:HookScript("OnHide", function()
        if not HasVisibleAssets() then RA:CancelVisualAssetRefresh() end
    end)
end

local function Register(region, entry)
    registrations[region] = entry
    RA:WatchVisualAssets(region.GetParent and region:GetParent())
    RefreshOne(region, entry)
    if IsVisible(region) then RA:RequestVisualAssetRefresh() end
    return region
end

function RA:RegisterVisualTexture(texture, asset, fallback, filterMode)
    if not texture or not texture.SetTexture then return texture end
    local entry = registrations[texture]
    if entry and entry.kind == "texture" and entry.asset == asset and not entry.spellID and not entry.resolve
        and entry.fallback == fallback and entry.filterMode == filterMode then
        RefreshOne(texture, entry)
        return texture
    end
    return Register(texture, {kind = "texture", asset = asset, fallback = fallback, filterMode = filterMode})
end

function RA:RegisterResolvedTexture(texture, resolve, fallback)
    if not texture or not texture.SetTexture then return texture end
    local entry = registrations[texture]
    if entry and entry.resolve == resolve then
        RefreshOne(texture, entry)
        return texture
    end
    return Register(texture, {kind = "texture", resolve = resolve, fallback = fallback})
end

function RA:RegisterSpellIcon(texture, spellID, fallback)
    if not texture or not texture.SetTexture then return texture end
    local entry = registrations[texture]
    if entry and entry.spellID == spellID and entry.fallback == fallback then
        RefreshOne(texture, entry)
        return texture
    end
    return Register(texture, {kind = "texture", spellID = spellID, fallback = fallback})
end

function RA:RegisterVisualFont(fontString, size, weight, shadow, ready)
    local old = registrations[fontString]
    registrations[fontString] = {kind = "font", size = size, weight = weight, shadow = shadow, ready = ready}
    self:WatchVisualAssets(fontString.GetParent and fontString:GetParent())
    -- Ordinary HUD relayout calls ApplyFont repeatedly. Only new/changed font
    -- demand starts a burst; retries themselves never rearm the timer queue.
    if not old or old.size ~= size or old.weight ~= weight or old.shadow ~= shadow then
        if IsVisible(fontString) then self:RequestVisualAssetRefresh() end
    end
end

RA:RegisterCallback("INITIALIZED", function() RA:RequestVisualAssetRefresh() end)
RA:RegisterCallback("VISUAL_ASSET_REFRESH", function() RA:RefreshVisualAssets() end)
RA:RegisterEvent("PLAYER_LOGIN", function() RA:RequestVisualAssetRefresh() end)
RA:RegisterEvent("PLAYER_ENTERING_WORLD", function() RA:RequestVisualAssetRefresh() end)
RA:RegisterEvent("SPELL_DATA_LOAD_RESULT", function(_, spellID, success)
    if not success then return end
    local visible = false
    for region, entry in pairs(registrations) do
        if entry.spellID == spellID and IsVisible(region) then
            RefreshOne(region, entry)
            visible = true
        end
    end
    if visible then RA:RequestVisualAssetRefresh() end
end)
