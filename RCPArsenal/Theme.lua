local ADDON_NAME, RA = ...

local Theme = {}
RA.Theme = Theme

Theme.MediaPath = "Interface\\AddOns\\" .. tostring(ADDON_NAME or "RCPArsenal") .. "\\Media\\"
Theme.Assets = {
    White = "Interface\\Buttons\\WHITE8X8",

    -- Seamless, single-texture rounded surfaces. Texture slicing preserves
    -- corners without the interior grid lines created by the old 9-piece
    -- renderer at fractional UI scales.
    RoundedSurfaceSmall = Theme.MediaPath .. "RoundedSurfaceSmall",
    RoundedBorderSmall = Theme.MediaPath .. "RoundedBorderSmall",
    RoundedSurfaceLarge = Theme.MediaPath .. "RoundedSurfaceLarge",
    RoundedBorderLarge = Theme.MediaPath .. "RoundedBorderLarge",

    GradientSunset = Theme.MediaPath .. "GradientSunset",
    GradientSunsetWash = Theme.MediaPath .. "GradientSunsetWash",
    GradientBerry = Theme.MediaPath .. "GradientBerry",
    GradientCrimson = Theme.MediaPath .. "GradientCrimson",
    GradientCrimsonWash = Theme.MediaPath .. "GradientCrimsonWash",
    GradientDigitalBerry = Theme.MediaPath .. "GradientDigitalBerry",
    GradientDigitalBerryWash = Theme.MediaPath .. "GradientDigitalBerryWash",
    GradientSunsetTop = Theme.MediaPath .. "GradientSunsetTop",
    GradientCrimsonTop = Theme.MediaPath .. "GradientCrimsonTop",
    GradientDigitalBerryTop = Theme.MediaPath .. "GradientDigitalBerryTop",
    SunsetGlow = Theme.MediaPath .. "SunsetGlow",
    Atmosphere = Theme.MediaPath .. "PanelAtmosphere",

    Logo = Theme.MediaPath .. "RCPLogo",
    Checkmark = Theme.MediaPath .. "RCPCheckmark",
    AddonIcon = Theme.MediaPath .. "RCPAddonIcon",
    SliderThumb = Theme.MediaPath .. "SliderThumb",
    NavHUD = Theme.MediaPath .. "NavHUD",
    NavContent = Theme.MediaPath .. "NavContent",
    NavScanning = Theme.MediaPath .. "NavScanning",
    NavActions = Theme.MediaPath .. "NavActions",
    IconEye = Theme.MediaPath .. "IconEye",
    IconTarget = Theme.MediaPath .. "IconTarget",
    IconLock = Theme.MediaPath .. "IconLock",
    IconPlay = Theme.MediaPath .. "IconPlay",
    RoundedIconMask = Theme.MediaPath .. "RoundedIconMask",
    ChevronUp = Theme.MediaPath .. "ChevronUp",
    ChevronDown = Theme.MediaPath .. "ChevronDown",
    DockSort = Theme.MediaPath .. "DockSort",
}

-- Obsidian Ember: warm graphite surfaces with a restrained, user-selectable
-- accent gradient. magenta/orange are intentionally mutable tables so existing
-- references in the UI update when the accent preset changes.
Theme.Colors = {
    canvas = {0.035, 0.036, 0.070, 0.995},
    canvasDeep = {0.021, 0.022, 0.046, 0.998},
    sidebar = {0.051, 0.043, 0.092, 0.995},
    surface = {0.065, 0.070, 0.120, 0.985},
    surfaceRaised = {0.085, 0.091, 0.151, 0.995},
    surfaceHover = {0.108, 0.105, 0.175, 1},
    surfacePressed = {0.125, 0.082, 0.158, 1},
    input = {0.038, 0.042, 0.078, 0.995},
    footer = {0.052, 0.043, 0.085, 0.995},

    text = {0.965, 0.955, 0.985, 1},
    textSoft = {0.790, 0.765, 0.835, 1},
    muted = {0.610, 0.590, 0.680, 1},
    faint = {0.420, 0.405, 0.500, 1},

    magenta = {1.000, 0.059, 0.482, 1},
    orange = {0.973, 0.608, 0.161, 1},
    violet = {0.706, 0.161, 0.976, 1},
    blue = {0.149, 0.773, 0.953, 1},
    activeDark = {0.235, 0.045, 0.205, 1},
    activeSoft = {0.330, 0.065, 0.250, 0.78},

    success = {0.380, 0.850, 0.555, 1},
    warning = {0.980, 0.660, 0.235, 1},
    danger = {0.975, 0.255, 0.330, 1},

    line = {0.690, 0.625, 0.800, 0.105},
    lineStrong = {0.870, 0.765, 0.950, 0.180},
    transparent = {0, 0, 0, 0},
    white = {1, 1, 1, 1},
}

Theme.AccentPresets = {
    SUNSET = {
        name = "Sunset Ember",
        primary = Theme.Assets.GradientSunset,
        wash = Theme.Assets.GradientSunsetWash,
        secondary = Theme.Assets.GradientDigitalBerry,
        top = Theme.Assets.GradientSunsetTop,
        start = {1.000, 0.059, 0.482, 1},
        finish = {0.973, 0.608, 0.161, 1},
    },
    CRIMSON = {
        name = "Crimson Violet",
        primary = Theme.Assets.GradientCrimson,
        wash = Theme.Assets.GradientCrimsonWash,
        secondary = Theme.Assets.GradientDigitalBerry,
        top = Theme.Assets.GradientCrimsonTop,
        start = {0.847, 0.118, 0.298, 1},
        finish = {0.561, 0.212, 1.000, 1},
    },
    BERRY = {
        name = "Digital Berry",
        primary = Theme.Assets.GradientDigitalBerry,
        wash = Theme.Assets.GradientDigitalBerryWash,
        secondary = Theme.Assets.GradientSunset,
        top = Theme.Assets.GradientDigitalBerryTop,
        start = {0.706, 0.161, 0.976, 1},
        finish = {0.149, 0.773, 0.953, 1},
    },
}
Theme.ActiveAccent = "SUNSET"
Theme.GradientTextures = setmetatable({}, {__mode = "k"})
Theme.AssetTextures = setmetatable({}, {__mode = "k"})

local function SetPoint(region, ...)
    if PixelUtil and PixelUtil.SetPoint then
        PixelUtil.SetPoint(region, ...)
    else
        region:SetPoint(...)
    end
end

local function SetSize(region, width, height)
    if PixelUtil and PixelUtil.SetSize then
        PixelUtil.SetSize(region, width, height)
    else
        region:SetSize(width, height)
    end
end

local function SetWidth(region, width)
    if PixelUtil and PixelUtil.SetWidth then
        PixelUtil.SetWidth(region, width)
    else
        region:SetWidth(width)
    end
end

local function SetHeight(region, height)
    if PixelUtil and PixelUtil.SetHeight then
        PixelUtil.SetHeight(region, height)
    else
        region:SetHeight(height)
    end
end

Theme.SetPoint = SetPoint
Theme.SetSize = SetSize
Theme.SetWidth = SetWidth
Theme.SetHeight = SetHeight

local function CopyInto(target, source)
    for i = 1, 4 do
        target[i] = source[i]
    end
end

local function ColorTexture(texture, color)
    texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
end

function Theme:GetAccentPreset(key)
    return self.AccentPresets[key or self.ActiveAccent] or self.AccentPresets.SUNSET
end

function Theme:GetAccentAsset(role)
    local preset = self:GetAccentPreset()
    if role == "WASH" then
        return preset.wash
    elseif role == "SECONDARY" then
        return preset.secondary
    elseif role == "TOP" then
        return preset.top or preset.primary
    end
    return preset.primary
end

function Theme:GetAccentStart()
    return self.Colors.magenta
end

function Theme:GetAccentEnd()
    return self.Colors.orange
end

function Theme:RegisterAssetTexture(texture, asset)
    if not texture or not asset then return texture end
    texture.__raAssetPath = asset
    self.AssetTextures[texture] = true
    texture:SetTexture(asset)
    return texture
end

function Theme:RefreshAssetTextures()
    for texture in pairs(self.AssetTextures) do
        if texture and texture.SetTexture and texture.__raAssetPath then
            texture:SetTexture(texture.__raAssetPath)
        end
    end
end

function Theme:RefreshAllAssets()
    self:RefreshAssetTextures()
    self:RefreshAccentTextures()
end

function Theme:RegisterAccentTexture(texture, role)
    if not texture then return texture end
    texture.__raAccentRole = role or "PRIMARY"
    self.GradientTextures[texture] = true
    texture:SetTexture(self:GetAccentAsset(texture.__raAccentRole))
    return texture
end

function Theme:RefreshAccentTextures()
    for texture in pairs(self.GradientTextures) do
        if texture and texture.SetTexture then
            texture:SetTexture(self:GetAccentAsset(texture.__raAccentRole))
        end
    end
end

function Theme:SetAccentPreset(key, notify)
    key = self.AccentPresets[key] and key or "SUNSET"
    self.ActiveAccent = key
    local preset = self.AccentPresets[key]
    CopyInto(self.Colors.magenta, preset.start)
    CopyInto(self.Colors.orange, preset.finish)
    -- Keep these derived states coherent with the selected accent family.
    self.Colors.activeDark[1] = preset.start[1] * 0.25
    self.Colors.activeDark[2] = preset.start[2] * 0.25
    self.Colors.activeDark[3] = preset.start[3] * 0.32
    self.Colors.activeSoft[1] = preset.start[1] * 0.42
    self.Colors.activeSoft[2] = preset.start[2] * 0.42
    self.Colors.activeSoft[3] = preset.start[3] * 0.48
    self:RefreshAccentTextures()
    if notify ~= false and RA.FireCallback then
        RA:FireCallback("ACCENT_THEME_CHANGED", key)
    end
end

local function IsBorderKey(key)
    return tostring(key or ""):lower():find("border", 1, true) ~= nil
end

local function CreateSeamlessSurface(owner, key, radius, layer, sublevel, offsets)
    owner.__raRounded = owner.__raRounded or {}
    if owner.__raRounded[key] then
        return owner.__raRounded[key]
    end

    radius = math.max(3, tonumber(radius) or 10)
    layer = layer or "BACKGROUND"
    sublevel = sublevel or -2
    offsets = offsets or {0, 0, 0, 0}
    local left, top, right, bottom = offsets[1] or 0, offsets[2] or 0, offsets[3] or 0, offsets[4] or 0

    local texture = owner:CreateTexture(nil, layer, nil, sublevel)
    local large = radius >= 13
    local border = IsBorderKey(key)
    local asset
    local margin
    if large then
        asset = border and Theme.Assets.RoundedBorderLarge or Theme.Assets.RoundedSurfaceLarge
        margin = 18
    else
        asset = border and Theme.Assets.RoundedBorderSmall or Theme.Assets.RoundedSurfaceSmall
        margin = 10
    end
    Theme:RegisterAssetTexture(texture, asset)
    SetPoint(texture, "TOPLEFT", owner, "TOPLEFT", left, top)
    SetPoint(texture, "BOTTOMRIGHT", owner, "BOTTOMRIGHT", right, bottom)

    -- Current Retail supports texture slicing. It renders this as one texture,
    -- so there are no overlapping pieces or grid seams. On an unexpected older
    -- client, the texture simply stretches as a seamless rounded shape.
    if texture.SetTextureSliceMargins then
        pcall(texture.SetTextureSliceMargins, texture, margin, margin, margin, margin)
    end
    if texture.SetTextureSliceMode then
        local stretched = Enum and Enum.UITextureSliceMode and Enum.UITextureSliceMode.Stretched or 0
        pcall(texture.SetTextureSliceMode, texture, stretched)
    end
    if texture.SetTexelSnappingBias then
        pcall(texture.SetTexelSnappingBias, texture, 0)
    end
    if texture.SetSnapToPixelGrid then
        pcall(texture.SetSnapToPixelGrid, texture, false)
    end

    local group = {surface = texture}
    owner.__raRounded[key] = group
    return group
end

function Theme:ApplyRounded(owner, color, radius, key, layer, sublevel, offsets)
    local group = CreateSeamlessSurface(owner, key or "base", radius or 10, layer, sublevel, offsets)
    self:SetRoundedColor(owner, color, key or "base")
    return group
end

function Theme:SetRoundedColor(owner, color, key)
    local group = owner.__raRounded and owner.__raRounded[key or "base"]
    if not group then return end
    for _, texture in pairs(group) do
        ColorTexture(texture, color)
    end
end

function Theme:SetRoundedAlpha(owner, alpha, key)
    local group = owner.__raRounded and owner.__raRounded[key or "base"]
    if not group then return end
    for _, texture in pairs(group) do
        texture:SetAlpha(alpha)
    end
end

function Theme:SetRoundedShown(owner, shown, key)
    local group = owner.__raRounded and owner.__raRounded[key or "base"]
    if not group then return end
    for _, texture in pairs(group) do
        texture:SetShown(shown)
    end
end

function Theme:AddShadow(owner, radius, alpha)
    local group = CreateSeamlessSurface(owner, "shadow", (radius or 10) + 5, "BACKGROUND", -8, {-8, 5, 8, -11})
    local color = {0, 0, 0, alpha or 0.42}
    for _, texture in pairs(group) do ColorTexture(texture, color) end
    return group
end

local function InferGradientRole(theme, asset)
    if asset == theme.Assets.GradientBerry or asset == theme.Assets.GradientDigitalBerry then
        return "SECONDARY"
    elseif asset == theme.Assets.GradientSunsetWash or asset == theme.Assets.GradientCrimsonWash or asset == theme.Assets.GradientDigitalBerryWash then
        return "WASH"
    end
    return "PRIMARY"
end

function Theme:AddGradient(owner, asset, alpha, inset, layer, sublevel)
    local texture = owner:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or -1)
    local role = InferGradientRole(self, asset)
    self:RegisterAccentTexture(texture, role)
    inset = inset or 3
    SetPoint(texture, "TOPLEFT", owner, "TOPLEFT", inset, -inset)
    SetPoint(texture, "BOTTOMRIGHT", owner, "BOTTOMRIGHT", -inset, inset)
    texture:SetAlpha(alpha or 1)
    owner.__raGradient = texture
    return texture
end

function Theme:AddTopWash(owner, asset, alpha, height, inset)
    local texture = owner:CreateTexture(nil, "BACKGROUND", nil, -1)
    self:RegisterAccentTexture(texture, "WASH")
    inset = inset or 2
    SetPoint(texture, "TOPLEFT", owner, "TOPLEFT", inset, -inset)
    SetPoint(texture, "TOPRIGHT", owner, "TOPRIGHT", -inset, -inset)
    SetHeight(texture, height or 74)
    texture:SetAlpha(alpha or 0.20)
    return texture
end

function Theme:AddAtmosphere(owner, alpha)
    local texture = owner:CreateTexture(nil, "BACKGROUND", nil, -5)
    self:RegisterAssetTexture(texture, self.Assets.Atmosphere)
    texture:SetAllPoints(owner)
    texture:SetAlpha(alpha or 0.36)
    return texture
end

function Theme:ApplyBackdropTemplate(owner)
    if owner.SetBackdrop then
        owner:SetBackdrop({bgFile = self.Assets.White})
        owner:SetBackdropColor(0, 0, 0, 0)
        owner:SetBackdropBorderColor(0, 0, 0, 0)
    end
end

function Theme:ApplyIconMask(texture, owner)
    if not texture or texture.__raRoundedMask then
        return texture and texture.__raRoundedMask or nil
    end

    owner = owner or (texture.GetParent and texture:GetParent()) or nil
    if not owner or type(owner.CreateMaskTexture) ~= "function" or type(texture.AddMaskTexture) ~= "function" then
        return nil
    end

    local ok, mask = pcall(owner.CreateMaskTexture, owner, nil, "ARTWORK")
    if not ok or not mask then return nil end

    local configured = pcall(function()
        self:RegisterAssetTexture(mask, self.Assets.RoundedIconMask)
        mask:SetAllPoints(texture)
        texture:AddMaskTexture(mask)
    end)

    if not configured then
        if mask.Hide then mask:Hide() end
        return nil
    end

    texture.__raRoundedMask = mask
    return mask
end

function Theme:CreateIcon(parent, asset, size, color)
    local texture = parent:CreateTexture(nil, "ARTWORK")
    self:RegisterAssetTexture(texture, asset)
    SetSize(texture, size or 20, size or 20)
    if color then texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1) end
    return texture
end

RA:RegisterInitializer(function()
    local db = RA:GetDB()
    Theme:SetAccentPreset(db and db.accentPreset or "SUNSET", false)
end)
