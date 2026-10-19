local _, RA = ...

local Theme = RA.Theme
local TC = Theme and Theme.Colors or {}

-- Pixel-safe geometry helpers shared with the settings preview. Keeping these
-- local avoids depending on unrelated global UI helpers and guarantees the
-- production HUD uses the same snapping rules as Theme/Layout.
local SetPoint = Theme and Theme.SetPoint or function(region, ...)
    region:SetPoint(...)
end
local SetSize = Theme and Theme.SetSize or function(region, width, height)
    region:SetSize(width, height)
end
local SetWidth = Theme and Theme.SetWidth or function(region, width)
    region:SetWidth(width)
end
local SetHeight = Theme and Theme.SetHeight or function(region, height)
    region:SetHeight(height)
end

local function SetAbilityIcon(texture, ability)
    if RA.RegisterSpellIcon then
        RA:RegisterSpellIcon(texture, ability.spellID)
    else
        texture:SetTexture(RA:GetAbilityTexture(ability))
    end
end

local HUD
local hudAnchor
local shadow
local topAccent
local headerTitle
local headerStatus
local headerMode
local headerLine
local detailedPauseButton
local moveHandle
local panicHUDButton
local panicTooltipTimer
local emptyState

local scanShell
local scanAccent
local scanProgressTrack
local scanProgressFill
local scanCountText
local scanCurrentText
local scanControlButton
local compactEmpty

local categoryPool = {}
local rowPool = {}
local compactLanePool = {}
local compactTilePool = {}
local scanTokenPool = {}

local activeStates = {}
local hudRefreshQueued = false
local scanVisualRefreshQueued = false
local currentMode = "COMPACT"
local positionNormalized = false
local hudDragState = nil
local refreshAfterCombat = false
local hudHasRenderableContent = true
local lastVisibilityReason = nil

local COLORS = {
    panel = TC.canvasDeep or {0.021, 0.022, 0.046, 1},
    panelEdge = TC.lineStrong or {0.35, 0.30, 0.45, 0.25},
    row = TC.surface or {0.065, 0.070, 0.120, 0.98},
    rowHover = TC.surfaceHover or {0.108, 0.105, 0.175, 1},
    text = TC.text or {0.965, 0.955, 0.985, 1},
    muted = TC.textSoft or {0.790, 0.765, 0.835, 1},
    faint = TC.faint or {0.420, 0.405, 0.500, 1},
    accent = TC.magenta or {1.000, 0.059, 0.482, 1},
    accentBlue = TC.blue or {0.149, 0.773, 0.953, 1},
    violet = TC.violet or {0.706, 0.161, 0.976, 1},
    active = TC.success or {0.380, 0.850, 0.555, 1},
    amber = TC.orange or {0.973, 0.608, 0.161, 1},
    danger = TC.danger or {0.975, 0.255, 0.330, 1},
}

local ROLE_COLORS = {
    TANK = {0.25, 0.63, 1.00},
    HEALER = {0.24, 0.89, 0.66},
    DAMAGER = {0.93, 0.35, 0.30},
    NONE = {0.49, 0.54, 0.62},
}

local ROLE_LETTERS = {
    TANK = "T",
    HEALER = "H",
    DAMAGER = "D",
    NONE = "?",
}

local CATEGORY_COMPACT_LABELS = {
    RAID_DEFENSIVE = "DEF",
    RAID_HEALING = "HEAL",
    MOVEMENT = "MOVE",
    EXTERNALS = "EXT",
    MANA = "MANA",
    UTILITY = "UTIL",
    RECOVERY = "REZ",
}

local CATEGORY_LABEL_COLORS = {
    RAID_DEFENSIVE = COLORS.accent,
    RAID_HEALING = COLORS.violet,
    MOVEMENT = COLORS.amber,
    EXTERNALS = COLORS.amber,
    MANA = COLORS.accentBlue,
    UTILITY = COLORS.violet,
    RECOVERY = COLORS.amber,
}

local DETAILED = {
    defaultWidth = 300,
    minWidth = 260,
    maxWidth = 430,
    outerInset = 4,
    headerHeight = 28,
    contentTop = -32,
    categoryHeight = 13,
    categoryFont = 7.2,
    rowHeight = 21,
    rowGap = 1,
    sectionGap = 2,
    iconSize = 16,
    leftInset = 5,
    iconNameGap = 5,
    nameFont = 9.0,
    ownerFont = 7.8,
    ownerWidth = 76,
    ownerMax = 2,
    activeWidth = 35,
    activeHeight = 12,
    activeFont = 6.2,
    minimumHeight = 64,
}

-- Compact mode is generated from profile metrics so it can range from a
-- micro HUD to a large broadcast-friendly overlay without scaling fuzzy text.
local COMPACT_BASE = {
    scanMinWidth = 112,
    scanPadding = 5,
    scanTopHeight = 15,
    scanTokenGap = 3,
    scanRowGap = 2,
    scanControlSize = 17,
    emptyWidth = 82,
    emptyHeight = 22,
}

local function RoundMetric(value)
    return math.floor((tonumber(value) or 0) + 0.5)
end

local function GetCompactMetrics(db)
    if RA.CompactLayout and RA.CompactLayout.GetMetrics then
        return RA.CompactLayout:GetMetrics(db)
    end
    return {}
end

local CLASS_ICON_TEXTURE = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"

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

local function CreateFontString(parent, size, color, weight, shadow)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    ApplyReadableFont(fs, size, weight or "REGULAR", shadow)
    fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("MIDDLE")
    return fs
end

local function CreateSolidTexture(parent, layer, color)
    local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    return texture
end

local function CopyColor(color, alpha)
    return {
        color and color[1] or 0,
        color and color[2] or 0,
        color and color[3] or 0,
        alpha == nil and ((color and color[4]) or 1) or alpha,
    }
end

local function EnsureRoundedFrame(frame, radius)
    if not Theme or frame.__raHUDRounded then
        return
    end
    Theme:ApplyBackdropTemplate(frame)
    Theme:ApplyRounded(frame, CopyColor(TC.transparent or {0, 0, 0, 0}, 0), (radius or 8) + 1, "hudBorder", "BACKGROUND", -5)
    Theme:ApplyRounded(frame, CopyColor(TC.transparent or {0, 0, 0, 0}, 0), radius or 8, "hudBase", "BACKGROUND", -4, {1, -1, -1, 1})
    frame.__raHUDRounded = true
end

local function SetRoundedFrame(frame, background, border, shown, radius)
    shown = shown ~= false
    EnsureRoundedFrame(frame, radius or 8)
    if Theme and frame.__raHUDRounded then
        Theme:SetRoundedShown(frame, shown, "hudBase")
        Theme:SetRoundedShown(frame, shown, "hudBorder")
        if shown then
            Theme:SetRoundedColor(frame, background or TC.surface, "hudBase")
            Theme:SetRoundedColor(frame, border or TC.line, "hudBorder")
        end
        if frame.SetBackdropColor then
            frame:SetBackdropColor(0, 0, 0, 0)
            frame:SetBackdropBorderColor(0, 0, 0, 0)
        end
    elseif frame.SetBackdropColor then
        local bg = shown and (background or COLORS.panel) or {0, 0, 0, 0}
        local edge = shown and (border or COLORS.panelEdge) or {0, 0, 0, 0}
        frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
        frame:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4] or 1)
    end
end

local function ApplyIconMask(texture, owner)
    if Theme and Theme.ApplyIconMask then
        return Theme:ApplyIconMask(texture, owner)
    end
    return nil
end

local function GetDetailedWidth(db)
    return math.max(DETAILED.minWidth, math.min(DETAILED.maxWidth, db.detailedWidth or DETAILED.defaultWidth))
end

local function SplitUTF8(text)
    local chars = {}
    text = tostring(text or "")
    for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        chars[#chars + 1] = char
    end
    return chars
end

local function JoinRange(chars, firstIndex, lastIndex)
    if not chars or #chars == 0 then
        return "?"
    end

    firstIndex = math.max(1, firstIndex or 1)
    lastIndex = math.min(#chars, lastIndex or #chars)
    local output = {}
    for i = firstIndex, lastIndex do
        output[#output + 1] = chars[i]
    end
    return table.concat(output)
end

local function FirstChars(chars, count)
    return JoinRange(chars, 1, math.min(#chars, count))
end

local function LastChars(chars, count)
    return JoinRange(chars, math.max(1, #chars - count + 1), #chars)
end

local function BuildAbbreviationMap(nameLength)
    nameLength = math.max(0, tonumber(nameLength) or 4)
    local names = {}
    local seen = {}

    for i = 1, #(RA.RosterOrder or {}) do
        local info = RA.RosterOrder[i]
        if info and info.name and not seen[info.name] then
            seen[info.name] = true
            names[#names + 1] = info.name
        end
    end

    local reports = RA:GetDisplayReports()
    for name in pairs(reports or {}) do
        if not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end

    table.sort(names, function(a, b)
        return RA:GetShortName(a) < RA:GetShortName(b)
    end)

    local abbreviations = {}
    local used = {}
    for index = 1, #names do
        local fullName = names[index]
        if nameLength == 0 then
            abbreviations[fullName] = ""
        else
            local chars = SplitUTF8(RA:GetShortName(fullName))
            local candidates = { FirstChars(chars, nameLength) }
            for suffixCount = 1, math.min(nameLength - 1, 3) do
                candidates[#candidates + 1] = FirstChars(chars, nameLength - suffixCount) .. LastChars(chars, suffixCount)
            end

            local chosen
            for i = 1, #candidates do
                local candidate = candidates[i]
                local key = string.lower(candidate)
                if candidate ~= "" and not used[key] then
                    chosen = candidate
                    used[key] = true
                    break
                end
            end

            if not chosen then
                local number = tostring(index % 10)
                chosen = FirstChars(chars, math.max(1, nameLength - #number)) .. number
                used[string.lower(chosen)] = true
            end
            abbreviations[fullName] = chosen
        end
    end
    return abbreviations
end

local function GetDisplayAbbreviation(abbreviations, fullName, nameLength)
    nameLength = math.max(0, tonumber(nameLength) or 4)
    if nameLength == 0 then
        return ""
    end
    return abbreviations[fullName] or FirstChars(SplitUTF8(RA:GetShortName(fullName)), nameLength)
end

local function GetCategoryFrame(index)
    local frame = categoryPool[index]
    if frame then
        return frame
    end

    frame = CreateFrame("Frame", nil, HUD)
    frame.label = CreateFontString(frame, 8, COLORS.muted, "BOLD")
    frame.line = CreateSolidTexture(frame, "ARTWORK", {0.12, 0.15, 0.19, 1})

    categoryPool[index] = frame
    return frame
end

local function RestoreRowBackdrop(row)
    row:SetBackdropColor(COLORS.row[1], COLORS.row[2], COLORS.row[3], 0.88)
    if not row.isActive then
        row:SetBackdropBorderColor(0.09, 0.11, 0.14, 0.92)
    end
end

local function GetRowFrame(index)
    local row = rowPool[index]
    if row then
        return row
    end

    row = CreateFrame("Frame", nil, HUD, "BackdropTemplate")
    row:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })

    row.iconBack = CreateSolidTexture(row, "BACKGROUND", {0.010, 0.014, 0.021, 0.92})
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ApplyIconMask(row.icon, row)

    row.nameText = CreateFontString(row, 10, COLORS.text, "BOLD")
    row.nameText:SetWordWrap(false)

    row.ownerText = CreateFontString(row, 8.5, COLORS.muted, "BOLD")
    row.ownerText:SetJustifyH("RIGHT")
    row.ownerText:SetWordWrap(false)

    row.activeBadge = CreateFrame("Frame", nil, row, "BackdropTemplate")
    row.activeBadge:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    row.activeBadge:SetBackdropColor(0.05, 0.18, 0.15, 0.96)
    row.activeBadge:SetBackdropBorderColor(COLORS.active[1], COLORS.active[2], COLORS.active[3], 0.70)
    row.activeBadge.text = CreateFontString(row.activeBadge, 7, COLORS.active, "BOLD")
    row.activeBadge.text:SetText("ACTIVE")
    row.activeBadge.text:SetJustifyH("CENTER")
    SetPoint(row.activeBadge.text, "CENTER", row.activeBadge, "CENTER", 0, 0)
    row.activeBadge:Hide()

    row:SetScript("OnEnter", function(self)
        if HUD:IsMouseEnabled() then
            self:SetBackdropColor(COLORS.rowHover[1], COLORS.rowHover[2], COLORS.rowHover[3], 0.96)
        end
    end)
    row:SetScript("OnLeave", RestoreRowBackdrop)

    rowPool[index] = row
    return row
end

local function GetCompactLane(index)
    local lane = compactLanePool[index]
    if lane then
        return lane
    end

    lane = CreateFrame("Frame", nil, HUD, "BackdropTemplate")
    SetRoundedFrame(lane, TC.surface or COLORS.row, TC.line or COLORS.panelEdge, true, 7)

    lane.accent = lane:CreateTexture(nil, "ARTWORK")
    if Theme then
        -- Use a dedicated rounded top-edge asset instead of laying a straight
        -- 2px line over a curved card. This lets the accent follow the same
        -- corner arc as the ribbon and prevents the tiny left/right mismatch
        -- visible at fractional HUD/UI scales.
        Theme:RegisterAccentTexture(lane.accent, "TOP")
    else
        lane.accent:SetColorTexture(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
    end
    lane.accent:SetAllPoints(lane)
    if lane.accent.SetTextureSliceMargins then
        pcall(lane.accent.SetTextureSliceMargins, lane.accent, 10, 10, 10, 10)
    end
    if lane.accent.SetTextureSliceMode then
        local stretched = Enum and Enum.UITextureSliceMode and Enum.UITextureSliceMode.Stretched or 0
        pcall(lane.accent.SetTextureSliceMode, lane.accent, stretched)
    end
    if lane.accent.SetTexelSnappingBias then
        pcall(lane.accent.SetTexelSnappingBias, lane.accent, 0)
    end
    lane.accent:SetAlpha(0.72)

    lane.label = CreateFontString(lane, 7.0, COLORS.muted, "BOLD")
    lane.label:SetJustifyH("CENTER")

    compactLanePool[index] = lane
    return lane
end

local function ShowTileTooltip(tile)
    if not tile.ability or not tile.owner then
        return
    end

    GameTooltip:SetOwner(tile, "ANCHOR_RIGHT")
    if GameTooltip.SetSpellByID then
        GameTooltip:SetSpellByID(tile.ability.spellID)
    else
        GameTooltip:SetText(RA:GetAbilityName(tile.ability), 1, 1, 1)
    end
    GameTooltip:AddLine("Owner: " .. RA:GetShortName(tile.owner.name), 0.72, 0.78, 0.86)
    GameTooltip:AddLine(" ")
    local actions = RA:GetDB().actions or {}
    local leftClickMode = actions.leftClickMode or "WHISPER"
    if leftClickMode == "SAY" then
        GameTooltip:AddDoubleLine("Left click", "Say callout", 0.35, 0.72, 1, 0.82, 0.87, 0.94)
    elseif leftClickMode == "WHISPER" then
        GameTooltip:AddDoubleLine("Left click", "Whisper player", 0.35, 0.72, 1, 0.82, 0.87, 0.94)
    end
    if actions.raidWarningEnabled ~= false then
        GameTooltip:AddDoubleLine("Right click", "Raid warning", 0.35, 0.72, 1, 0.82, 0.87, 0.94)
        GameTooltip:AddLine("Raid-warning macros require the group to be inside the instance during an encounter.", 0.62, 0.67, 0.74, true)
    end
    GameTooltip:Show()
end

local function SanitizeActionText(text)
    text = tostring(text or "")
    text = text:gsub("[\r\n]+", " "):gsub("%s+", " ")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if #text > 180 then
        text = text:sub(1, 180)
    end
    return text
end

local function FormatActionText(template, ability, owner)
    local values = {
        spell = RA.GetAbilityCallout and RA:GetAbilityCallout(ability) or RA:GetAbilityName(ability),
        name = RA:GetShortName(owner.name),
        player = RA:GetShortName(owner.name),
        full = owner.name,
    }
    local output = tostring(template or "")
    output = output:gsub("{([%a_]+)}", function(token)
        return values[token] or "{" .. token .. "}"
    end)
    return SanitizeActionText(output)
end

local function SanitizePanicText(text)
    text = tostring(text or "PANIC: USE DEFENSIVES + HEALTH POTIONS NOW!")
    text = text:gsub("[\r\n]+", " "):gsub("%s+", " ")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if #text > 180 then text = text:sub(1, 180) end
    if text == "" then text = "PANIC: USE DEFENSIVES + HEALTH POTIONS NOW!" end
    return text
end

local function CancelPanicTooltip()
    if panicTooltipTimer then
        if panicTooltipTimer.Cancel then pcall(panicTooltipTimer.Cancel, panicTooltipTimer) end
        panicTooltipTimer = nil
    end
    if GameTooltip then GameTooltip:Hide() end
end

local function ArmPanicButton()
    if not panicHUDButton or InCombatLockdown() then return end
    local toolbox = RA:GetDB().leaderToolbox or {}
    panicHUDButton:SetAttribute("useOnKeyDown", GetCVarBool and GetCVarBool("ActionButtonUseKeyDown") or false)
    panicHUDButton:SetAttribute("type1", "macro")
    panicHUDButton:SetAttribute("macrotext1", "/rw " .. SanitizePanicText(toolbox.panicMessage))
end

local function PositionPanicButton(anchorFrame)
    if not panicHUDButton or InCombatLockdown() then return end
    if not anchorFrame then
        panicHUDButton:Hide()
        return
    end
    local toolbox = RA:GetDB().leaderToolbox or {}
    if toolbox.panicEnabled == false then
        panicHUDButton:Hide()
        return
    end
    panicHUDButton:ClearAllPoints()
    SetPoint(panicHUDButton, "RIGHT", anchorFrame, "LEFT", -5, 0)
    panicHUDButton:Show()
end

local function ConfigureTileActions(tile, ability, owner)
    if InCombatLockdown() then
        return
    end

    local useOnKeyDown = GetCVarBool and GetCVarBool("ActionButtonUseKeyDown") or false
    tile:SetAttribute("useOnKeyDown", useOnKeyDown and true or false)
    tile.__rcpaActionOwner = owner and owner.name or nil
    tile.__rcpaActionAbility = ability and ability.key or nil

    local actions = RA:GetDB().actions or {}
    local leftClickMode = actions.leftClickMode or "WHISPER"
    local leftMacro
    if leftClickMode == "SAY" then
        local message = FormatActionText(actions.sayTemplate, ability, owner)
        if message ~= "" then leftMacro = "/s " .. message end
    elseif leftClickMode == "WHISPER" then
        local message = FormatActionText(actions.whisperTemplate, ability, owner)
        if message ~= "" then leftMacro = "/w " .. owner.name .. " " .. message end
    end
    if leftMacro then
        tile:SetAttribute("type1", "macro")
        tile:SetAttribute("macrotext1", leftMacro)
    else
        tile:SetAttribute("type1", nil)
        tile:SetAttribute("macrotext1", nil)
    end

    if actions.raidWarningEnabled ~= false then
        local message = FormatActionText(actions.raidWarningTemplate, ability, owner)
        tile:SetAttribute("type2", "macro")
        tile:SetAttribute("macrotext2", "/rw " .. message)
    else
        tile:SetAttribute("type2", nil)
        tile:SetAttribute("macrotext2", nil)
    end
end

local function GetCompactTile(index)
    local tile = compactTilePool[index]
    if tile then
        return tile
    end

    tile = CreateFrame("Button", nil, HUD, "SecureActionButtonTemplate,BackdropTemplate")
    tile:RegisterForClicks("AnyDown", "AnyUp")
    SetRoundedFrame(tile, TC.transparent, TC.transparent, false, 7)

    tile.iconFrame = CreateFrame("Frame", nil, tile, "BackdropTemplate")
    SetRoundedFrame(tile.iconFrame, TC.input or COLORS.panel, TC.lineStrong or COLORS.panelEdge, true, 6)

    tile.icon = tile.iconFrame:CreateTexture(nil, "ARTWORK")
    tile.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    SetPoint(tile.icon, "TOPLEFT", tile.iconFrame, "TOPLEFT", 1, -1)
    SetPoint(tile.icon, "BOTTOMRIGHT", tile.iconFrame, "BOTTOMRIGHT", -1, 1)
    ApplyIconMask(tile.icon, tile.iconFrame)

    tile.activeDot = tile:CreateTexture(nil, "OVERLAY")
    tile.activeDot:SetColorTexture(COLORS.active[1], COLORS.active[2], COLORS.active[3], 1)
    tile.activeDot:Hide()

    tile.nameText = CreateFontString(tile, 8, COLORS.text, "BOLD")
    tile.nameText:SetJustifyH("CENTER")
    tile.nameText:SetWordWrap(false)

    tile.callFlash = tile:CreateTexture(nil, "OVERLAY")
    if Theme then
        Theme:RegisterAccentTexture(tile.callFlash, "PRIMARY")
    else
        tile.callFlash:SetColorTexture(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.28)
    end
    tile.callFlash:SetAllPoints(tile.iconFrame)
    tile.callFlash:SetAlpha(0.42)
    ApplyIconMask(tile.callFlash, tile.iconFrame)
    tile.callFlash:Hide()
    tile.callAnimation = tile.callFlash:CreateAnimationGroup()
    local flashIn = tile.callAnimation:CreateAnimation("Alpha")
    flashIn:SetFromAlpha(0.0)
    flashIn:SetToAlpha(0.8)
    flashIn:SetDuration(0.05)
    flashIn:SetOrder(1)
    local flashOut = tile.callAnimation:CreateAnimation("Alpha")
    flashOut:SetFromAlpha(0.8)
    flashOut:SetToAlpha(0.0)
    flashOut:SetDuration(0.22)
    flashOut:SetOrder(2)
    tile.callAnimation:SetScript("OnPlay", function() tile.callFlash:Show() end)
    tile.callAnimation:SetScript("OnFinished", function() tile.callFlash:Hide() end)

    tile:SetScript("OnEnter", ShowTileTooltip)
    tile:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tile:SetScript("PostClick", function(self)
        if self.callAnimation:IsPlaying() then
            self.callAnimation:Stop()
        end
        self.callAnimation:Play()
    end)

    compactTilePool[index] = tile
    return tile
end

local function GetSpecializationTexture(specID)
    if type(specID) ~= "number" or specID <= 0 or not GetSpecializationInfoByID then
        return nil
    end

    local ok, specOut, specName, specDescription, icon = pcall(GetSpecializationInfoByID, specID)
    if ok and icon then
        return icon
    end
    return nil
end

local function SetClassTexture(texture, classFile, cachedSpecID)
    local specTexture = GetSpecializationTexture(cachedSpecID)
    if specTexture then
        texture:SetTexture(specTexture)
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        return
    end

    if type(classFile) ~= "string" or classFile == "" then
        texture:SetTexture(134400) -- INV_Misc_QuestionMark
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        return
    end

    texture:SetTexture(CLASS_ICON_TEXTURE)
    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
    if coords then
        texture:SetTexCoord(coords[1] + 0.02, coords[2] - 0.02, coords[3] + 0.02, coords[4] - 0.02)
    else
        texture:SetTexture(134400) -- unknown/temporarily unavailable class
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
end

local function GetScanToken(index)
    local token = scanTokenPool[index]
    if token then
        return token
    end

    token = CreateFrame("Frame", nil, scanShell)
    token:EnableMouse(true)
    token:SetScript("OnEnter", function(self)
        if not self.entry then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(RA:GetShortName(self.entry.name), 1, 1, 1)
        local role = self.entry.role or "NONE"
        local state = self.entry.state or "WAITING"
        GameTooltip:AddLine((role == "NONE" and "Unassigned" or role) .. " · " .. state, 0.64, 0.70, 0.78)
        if self.entry.reason and self.entry.reason ~= "" then
            GameTooltip:AddLine(self.entry.reason, 0.78, 0.58, 0.35, true)
        end
        GameTooltip:Show()
    end)
    token:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    token.portraitFrame = CreateFrame("Frame", nil, token, "BackdropTemplate")
    SetRoundedFrame(token.portraitFrame, TC.input or COLORS.panel, TC.line or COLORS.panelEdge, true, 6)
    if token.portraitFrame.SetClipsChildren then
        token.portraitFrame:SetClipsChildren(true)
    end

    token.portrait = token.portraitFrame:CreateTexture(nil, "ARTWORK")
    SetPoint(token.portrait, "TOPLEFT", token.portraitFrame, "TOPLEFT", 1, -1)
    SetPoint(token.portrait, "BOTTOMRIGHT", token.portraitFrame, "BOTTOMRIGHT", -1, 1)
    ApplyIconMask(token.portrait, token.portraitFrame)

    token.sweep = token.portraitFrame:CreateTexture(nil, "OVERLAY")
    token.sweep:SetColorTexture(0.74, 0.91, 1.00, 0.28)
    token.sweep:SetBlendMode("ADD")
    SetSize(token.sweep, 5, 23)
    SetPoint(token.sweep, "RIGHT", token.portraitFrame, "LEFT", -2, 0)

    token.sweepAnimation = token.sweep:CreateAnimationGroup()
    token.sweepAnimation:SetLooping("REPEAT")
    local translation = token.sweepAnimation:CreateAnimation("Translation")
    translation:SetDuration(1.10)
    translation:SetOffset(29, 0)
    token.sweepTranslation = translation
    translation:SetSmoothing("NONE")
    token.sweepAnimation:Stop()
    token.sweep:Hide()

    token.roleBadge = CreateFrame("Frame", nil, token.portraitFrame, "BackdropTemplate")
    SetRoundedFrame(token.roleBadge, TC.canvasDeep or COLORS.panel, TC.lineStrong or COLORS.panelEdge, true, 4)
    SetSize(token.roleBadge, 7, 7)
    SetPoint(token.roleBadge, "BOTTOMRIGHT", token.portraitFrame, "BOTTOMRIGHT", 1, -1)

    token.roleText = CreateFontString(token.roleBadge, 5.1, COLORS.text, "BOLD")
    token.roleText:SetJustifyH("CENTER")
    SetPoint(token.roleText, "CENTER", token.roleBadge, "CENTER", 0, 0)

    token.statusDot = token.portraitFrame:CreateTexture(nil, "OVERLAY")
    SetSize(token.statusDot, 3, 3)
    SetPoint(token.statusDot, "TOPLEFT", token.portraitFrame, "TOPLEFT", 1, -1)
    token.statusDot:Hide()

    token.nameText = CreateFontString(token, 7, COLORS.muted, "BOLD")
    token.nameText:SetJustifyH("CENTER")
    token.nameText:SetWordWrap(false)

    scanTokenPool[index] = token
    return token
end

local function FormatOwners(owners, maxNames)
    if not owners or #owners == 0 then
        return ""
    end

    local output = {}
    local visibleNames = math.min(#owners, maxNames)
    for i = 1, visibleNames do
        local owner = owners[i]
        output[#output + 1] = RA:ColorizeName(owner.shortName, owner.class)
    end

    local text = table.concat(output, " |cff56606d·|r ")
    if #owners > visibleNames then
        text = text .. " |cff76808c+" .. tostring(#owners - visibleNames) .. "|r"
    end
    return text
end

local function ResolveHUDDirection()
    local db = RA:GetDB()
    local requested = db and db.hudDirection or "AUTO"
    if requested ~= "AUTO" then return requested end
    if not hudAnchor or not UIParent then return "RIGHT" end
    local left, top = hudAnchor:GetLeft(), hudAnchor:GetTop()
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    if type(left) ~= "number" or type(top) ~= "number" or type(width) ~= "number" or type(height) ~= "number" then
        return "RIGHT"
    end
    local spaces = {
        RIGHT = width - left,
        LEFT = left,
        UP = height - top,
        DOWN = top,
    }
    local best, bestSpace = "RIGHT", spaces.RIGHT
    for _, dir in ipairs({"LEFT", "DOWN", "UP"}) do
        if spaces[dir] > bestSpace then
            best, bestSpace = dir, spaces[dir]
        end
    end
    return best
end

local function BindHUDToAnchor()
    if not HUD or not hudAnchor then return end
    HUD:ClearAllPoints()
    local direction = ResolveHUDDirection()
    if direction == "LEFT" then
        HUD:SetPoint("TOPRIGHT", hudAnchor, "TOPLEFT", 0, 0)
    elseif direction == "DOWN" then
        HUD:SetPoint("TOP", hudAnchor, "TOPLEFT", 0, 0)
    elseif direction == "UP" then
        HUD:SetPoint("BOTTOM", hudAnchor, "TOPLEFT", 0, 0)
    else
        HUD:SetPoint("TOPLEFT", hudAnchor, "TOPLEFT", 0, 0)
    end
    HUD.__rcpaDirection = direction
end

local function SavePosition()
    if not hudAnchor then return end
    local db = RA:GetDB()
    db.position = db.position or {}
    if RA.CaptureFrameTopLeft and RA:CaptureFrameTopLeft(hudAnchor, db.position) then
        db.positionAnchorVersion = 3
        positionNormalized = true
    end
end

local function RestorePosition()
    if not HUD or not hudAnchor then return end
    local db = RA:GetDB()
    local pos = db.position or {}

    -- v2 already stored UIParent-space top-left coordinates. Put those on an
    -- unscaled one-pixel anchor and never move the HUD itself again. This keeps
    -- the visible top-left fixed when HUD scale, dimensions, scan rows, or
    -- world loading state changes.
    if (tonumber(db.positionAnchorVersion) or 0) >= 2 and RA.RestoreFrameTopLeft then
        RA:RestoreFrameTopLeft(hudAnchor, pos, {x = 360, y = -300})
        BindHUDToAnchor()
        db.positionAnchorVersion = 3
        positionNormalized = true
        return
    end

    -- Legacy profiles are allowed to render once at their original anchor.
    -- After the first real layout/scale pass, NormalizePositionIfNeeded()
    -- captures that exact visible top-left and migrates it to the stable anchor.
    HUD:ClearAllPoints()
    SetPoint(HUD, pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 0)
    positionNormalized = false
end

local function NormalizePositionIfNeeded()
    if positionNormalized or not HUD or not HUD:IsShown() or not hudAnchor then return end
    if not RA.GetFrameTopLeftInUIParent then return end

    local left, top = RA:GetFrameTopLeftInUIParent(HUD)
    local parentHeight = UIParent and UIParent.GetHeight and UIParent:GetHeight() or nil
    if type(left) ~= "number" or type(top) ~= "number" or type(parentHeight) ~= "number" then return end

    hudAnchor:ClearAllPoints()
    hudAnchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left, top - parentHeight)
    BindHUDToAnchor()
    SavePosition()
end

local function StopHUDDrag(savePosition)
    if not hudAnchor then return end
    local state = hudDragState
    hudDragState = nil
    hudAnchor:SetScript("OnUpdate", nil)
    if savePosition and state then
        SavePosition()
    end
end

local function StartHUDDrag()
    if not HUD or not hudAnchor or RA:GetDB().locked or InCombatLockdown() then return end
    if not GetCursorPosition or not UIParent then return end

    -- A legacy position must be converted before drag math begins.
    NormalizePositionIfNeeded()
    if not positionNormalized then return end

    local cursorX, cursorY = GetCursorPosition()
    local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if type(parentScale) ~= "number" or parentScale <= 0 then parentScale = 1 end
    cursorX, cursorY = cursorX / parentScale, cursorY / parentScale

    local left, top = hudAnchor:GetLeft(), hudAnchor:GetTop()
    local parentHeight = UIParent:GetHeight()
    if type(left) ~= "number" or type(top) ~= "number" or type(parentHeight) ~= "number" then return end

    hudDragState = {
        cursorX = cursorX,
        cursorY = cursorY,
        left = left,
        top = top,
        parentHeight = parentHeight,
        parentScale = parentScale,
    }

    hudAnchor:SetScript("OnUpdate", function(self)
        local state = hudDragState
        if not state then
            self:SetScript("OnUpdate", nil)
            return
        end
        if InCombatLockdown() then
            StopHUDDrag(true)
            return
        end

        local x, y = GetCursorPosition()
        x, y = x / state.parentScale, y / state.parentScale
        local newLeft = state.left + (x - state.cursorX)
        local newTop = state.top + (y - state.cursorY)

        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "TOPLEFT", newLeft, newTop - state.parentHeight)
    end)
end

local function ApplyLockState()
    if not HUD then return end

    local locked = RA:GetDB().locked
    -- Moving is isolated to the dedicated mover tab. The HUD body never
    -- begins a drag, so aiming for an ability tile cannot accidentally turn
    -- into a reposition gesture.
    HUD:SetMovable(false)
    HUD:RegisterForDrag()
    HUD:EnableMouse(not locked)

    if moveHandle then
        moveHandle:SetShown(not locked and HUD:IsShown() and not InCombatLockdown())
    end

    if scanControlButton then scanControlButton:EnableMouse(true) end
    if detailedPauseButton then detailedPauseButton:EnableMouse(true) end
end

local function HandleScanControl()
    if RA.InEncounter or InCombatLockdown() then
        return
    end

    local inspected, total = RA:GetVerificationStatus()
    local _, _, _, running, _, paused = RA:GetInspectionProgress()

    if paused then
        RA:SetInspectionPaused(false)
    elseif running then
        RA:SetInspectionPaused(true)
    elseif inspected < total or RA:HasMissingReports() then
        RA:SetInspectionPaused(false)
        RA:RequestInspectionScan("HUD retry missing", false)
    end
end

local function SetScanControlVisual(button, running, paused, incomplete)
    if not button then
        return
    end

    if paused then
        button.text:SetText(">")
        button.text:SetTextColor(COLORS.amber[1], COLORS.amber[2], COLORS.amber[3], 1)
    elseif running then
        button.text:SetText("II")
        button.text:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3], 1)
    elseif incomplete then
        button.text:SetText("R")
        button.text:SetTextColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
    else
        button.text:SetText("")
    end
end

local function SetScanControlTooltip(button)
    button:SetScript("OnEnter", function(self)
        local inspected, total = RA:GetVerificationStatus()
        local _, _, _, running, _, paused = RA:GetInspectionProgress()
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if paused then
            GameTooltip:SetText("Resume raid scan", 1, 1, 1)
            GameTooltip:AddLine("Continues with the next unresolved player.", 0.64, 0.70, 0.78, true)
        elseif running then
            GameTooltip:SetText("Pause raid scan", 1, 1, 1)
            GameTooltip:AddLine("The current inspect is allowed to finish; no next player starts.", 0.64, 0.70, 0.78, true)
        elseif inspected < total then
            GameTooltip:SetText("Retry missing players", 1, 1, 1)
            GameTooltip:AddLine("Only unresolved tracked players are queued.", 0.64, 0.70, 0.78, true)
        else
            GameTooltip:SetText("Raid scan complete", 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function HideDetailedFrames()
    for i = 1, #categoryPool do
        categoryPool[i]:Hide()
    end
    for i = 1, #rowPool do
        rowPool[i]:Hide()
    end
    headerTitle:Hide()
    headerStatus:Hide()
    headerMode:Hide()
    headerLine:Hide()
    topAccent:Hide()
    emptyState:Hide()
    detailedPauseButton:Hide()
end

local function HideCompactFrames()
    scanShell:Hide()
    compactEmpty:Hide()
    for i = 1, #compactLanePool do
        compactLanePool[i]:Hide()
    end
    for i = 1, #compactTilePool do
        compactTilePool[i]:Hide()
    end
    for i = 1, #scanTokenPool do
        local token = scanTokenPool[i]
        token.sweepAnimation:Stop()
        token.sweep:Hide()
        token:Hide()
    end
end

local function LayoutDetailedHeader(width, inspected, total, isDemo, scanning, paused)
    headerTitle:Show()
    headerStatus:Show()
    headerMode:Show()
    headerLine:Show()
    topAccent:Show()

    headerTitle:ClearAllPoints()
    headerStatus:ClearAllPoints()
    headerMode:ClearAllPoints()
    headerLine:ClearAllPoints()

    headerTitle:SetText("RCP ARSENAL")
    ApplyReadableFont(headerTitle, 11.0, "BOLD")
    SetPoint(headerTitle, "TOPLEFT", HUD, "TOPLEFT", 8, -8)

    local incomplete = inspected < total
    detailedPauseButton:SetShown(not RA.InEncounter and not isDemo and (scanning or paused or incomplete))
    detailedPauseButton:ClearAllPoints()
    SetPoint(detailedPauseButton, "TOPRIGHT", HUD, "TOPRIGHT", -5, -5)
    SetSize(detailedPauseButton, 16, 14)
    SetScanControlVisual(detailedPauseButton, scanning, paused, incomplete)

    ApplyReadableFont(headerMode, 8.0, "BOLD")
    headerMode:SetJustifyH("RIGHT")
    if detailedPauseButton:IsShown() then
        SetPoint(headerMode, "RIGHT", detailedPauseButton, "LEFT", -5, 0)
    else
        SetPoint(headerMode, "TOPRIGHT", HUD, "TOPRIGHT", -7, -7)
    end

    ApplyReadableFont(headerStatus, 8.5, "REGULAR")
    headerStatus:SetJustifyH("LEFT")
    SetPoint(headerStatus, "TOPLEFT", headerTitle, "BOTTOMLEFT", 0, -2)
    headerStatus:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], 1)
    if not IsInGroup() then
        headerStatus:SetText("LOCAL READY")
    else
        headerStatus:SetText(string.format("%d/%d READY", inspected, total))
    end

    SetHeight(headerLine, 1)
    SetPoint(headerLine, "TOPLEFT", HUD, "TOPLEFT", 7, -30)
    SetPoint(headerLine, "TOPRIGHT", HUD, "TOPRIGHT", -7, -30)

    if isDemo then
        headerMode:SetText("DEMO")
        headerMode:SetTextColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
    elseif RA.InEncounter then
        headerMode:SetText("LIVE")
        headerMode:SetTextColor(COLORS.active[1], COLORS.active[2], COLORS.active[3], 1)
    elseif paused then
        headerMode:SetText("PAUSED")
        headerMode:SetTextColor(COLORS.amber[1], COLORS.amber[2], COLORS.amber[3], 1)
    elseif scanning then
        headerMode:SetText("SCAN")
        headerMode:SetTextColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
    else
        headerMode:SetText("READY")
        headerMode:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], 1)
    end
end

local function LayoutDetailedCategory(frame, categoryName, y, width)
    frame:ClearAllPoints()
    SetPoint(frame, "TOPLEFT", HUD, "TOPLEFT", 0, y)
    SetSize(frame, width, DETAILED.categoryHeight)

    frame.label:ClearAllPoints()
    ApplyReadableFont(frame.label, DETAILED.categoryFont + 0.6, "BOLD")
    SetPoint(frame.label, "LEFT", frame, "LEFT", DETAILED.outerInset + 2, 0)
    frame.label:SetText(string.upper(categoryName))

    frame.line:ClearAllPoints()
    SetHeight(frame.line, 1)
    SetPoint(frame.line, "LEFT", frame.label, "RIGHT", 7, 0)
    SetPoint(frame.line, "RIGHT", frame, "RIGHT", -(DETAILED.outerInset + 2), 0)
    frame.line:Show()
    frame:Show()

    return y - DETAILED.categoryHeight
end

local function LayoutDetailedRow(row, ability, owners, y, width)
    local rowWidth = width - (DETAILED.outerInset * 2)
    local isActive = activeStates[ability.key] == true

    row.isActive = isActive
    row:ClearAllPoints()
    SetPoint(row, "TOPLEFT", HUD, "TOPLEFT", DETAILED.outerInset, y)
    SetSize(row, rowWidth, DETAILED.rowHeight)

    RestoreRowBackdrop(row)

    SetSize(row.iconBack, DETAILED.iconSize + 2, DETAILED.iconSize + 2)
    row.iconBack:ClearAllPoints()
    SetPoint(row.iconBack, "LEFT", row, "LEFT", DETAILED.leftInset, 0)

    SetSize(row.icon, DETAILED.iconSize, DETAILED.iconSize)
    row.icon:ClearAllPoints()
    SetPoint(row.icon, "CENTER", row.iconBack, "CENTER", 0, 0)
    SetAbilityIcon(row.icon, ability)

    row.activeBadge:SetShown(isActive)
    row.activeBadge:ClearAllPoints()
    SetPoint(row.activeBadge, "RIGHT", row, "RIGHT", -5, 0)
    SetSize(row.activeBadge, DETAILED.activeWidth, DETAILED.activeHeight)
    ApplyReadableFont(row.activeBadge.text, DETAILED.activeFont + 0.4, "BOLD")

    row.ownerText:ClearAllPoints()
    ApplyReadableFont(row.ownerText, DETAILED.ownerFont + 0.4, "BOLD")
    SetWidth(row.ownerText, DETAILED.ownerWidth)
    if isActive then
        SetPoint(row.ownerText, "RIGHT", row.activeBadge, "LEFT", -5, 0)
    else
        SetPoint(row.ownerText, "RIGHT", row, "RIGHT", -6, 0)
    end
    row.ownerText:SetText(FormatOwners(owners, DETAILED.ownerMax))

    row.nameText:ClearAllPoints()
    ApplyReadableFont(row.nameText, DETAILED.nameFont + 0.5, "BOLD")
    SetPoint(row.nameText, "LEFT", row.iconBack, "RIGHT", DETAILED.iconNameGap, 0)
    SetPoint(row.nameText, "RIGHT", row.ownerText, "LEFT", -6, 0)
    row.nameText:SetText(RA:GetAbilityName(ability))

    if isActive then
        row:SetBackdropBorderColor(COLORS.active[1], COLORS.active[2], COLORS.active[3], 0.74)
    end

    row.abilityKey = ability.key
    row:Show()
    return y - DETAILED.rowHeight - DETAILED.rowGap
end

local function RefreshDetailedHUD(db, ownersByAbility, inspected, total, isDemo, scanning, paused)
    HideCompactFrames()
    if panicHUDButton then panicHUDButton:Hide() end

    currentMode = "DETAILED"
    local width = GetDetailedWidth(db)
    SetWidth(HUD, width)
    SetRoundedFrame(HUD, CopyColor(TC.canvasDeep or COLORS.panel, 0.985), CopyColor(TC.lineStrong or COLORS.panelEdge, 0.72), true, 9)

    shadow:SetAlpha(math.min(0.42, (db.opacity or 0.94) * 0.42))
    shadow:Show()

    LayoutDetailedHeader(width, inspected, total, isDemo, scanning, paused)

    for i = 1, #categoryPool do
        categoryPool[i]:Hide()
    end
    for i = 1, #rowPool do
        rowPool[i]:Hide()
    end

    local y = DETAILED.contentTop
    local categoryIndex = 0
    local rowIndex = 0
    local totalVisibleRows = 0

    for c = 1, #RA.Categories do
        local category = RA.Categories[c]
        if RA:IsCategoryEnabled(category.key) then
            local visibleAbilities = {}

            local orderedAbilities = RA.GetOrderedAbilities and RA:GetOrderedAbilities(category.key) or RA.Catalog
            for i = 1, #orderedAbilities do
                local ability = orderedAbilities[i]
                local owners = ownersByAbility[ability.index]
                if ability.category == category.key and owners and #owners > 0 and RA:IsAbilityEnabled(ability) then
                    visibleAbilities[#visibleAbilities + 1] = {ability = ability, owners = owners}
                end
            end

            if #visibleAbilities > 0 then
                categoryIndex = categoryIndex + 1
                local categoryFrame = GetCategoryFrame(categoryIndex)
                y = LayoutDetailedCategory(categoryFrame, category.name, y, width)
                if categoryIndex == 1 then PositionPanicButton(categoryFrame) end

                for i = 1, #visibleAbilities do
                    rowIndex = rowIndex + 1
                    totalVisibleRows = totalVisibleRows + 1
                    y = LayoutDetailedRow(GetRowFrame(rowIndex), visibleAbilities[i].ability, visibleAbilities[i].owners, y, width)
                end

                y = y - DETAILED.sectionGap
            end
        end
    end

    emptyState:SetShown(totalVisibleRows == 0 and db.compact.showEmptyState == true)
    if totalVisibleRows == 0 and db.compact.showEmptyState == true then
        emptyState:ClearAllPoints()
        ApplyReadableFont(emptyState, 9.4, "BOLD")
        SetPoint(emptyState, "TOPLEFT", HUD, "TOPLEFT", 8, DETAILED.contentTop - 8)
        SetPoint(emptyState, "TOPRIGHT", HUD, "TOPRIGHT", -8, DETAILED.contentTop - 8)

        if scanning then
            emptyState:SetText("Inspecting raid loadouts...")
        elseif inspected < total then
            emptyState:SetText("No scanned tools yet")
        else
            emptyState:SetText("No enabled raid tools")
        end
        y = DETAILED.contentTop - 34
    end

    hudHasRenderableContent = totalVisibleRows > 0 or db.compact.showEmptyState == true or scanning
    local height = math.max(DETAILED.minimumHeight, -y + 4)
    SetHeight(HUD, height)
    SetSize(shadow, width + 8, height + 8)
end

local function ConfigureCompactTile(tile, ability, owner, abbreviations, active, metrics)
    tile.ability = ability
    tile.owner = owner
    SetSize(tile, metrics.tileWidth, metrics.tileHeight)

    SetSize(tile.iconFrame, metrics.iconSize, metrics.iconSize)
    tile.iconFrame:ClearAllPoints()
    SetPoint(tile.iconFrame, "TOP", tile, "TOP", 0, 0)
    SetAbilityIcon(tile.icon, ability)

    tile.nameText:ClearAllPoints()
    ApplyReadableFont(tile.nameText, metrics.nameFont, "BOLD")
    if metrics.nameLength > 0 then
        SetPoint(tile.nameText, "TOPLEFT", tile.iconFrame, "BOTTOMLEFT", -3, -1)
        SetPoint(tile.nameText, "TOPRIGHT", tile.iconFrame, "BOTTOMRIGHT", 3, -1)
        tile.nameText:SetText(GetDisplayAbbreviation(abbreviations, owner.name, metrics.nameLength))
        local r, g, b = RA:GetClassColor(owner.class)
        tile.nameText:SetTextColor(r, g, b, 1)
        tile.nameText:Show()
    else
        tile.nameText:SetText("")
        tile.nameText:Hide()
    end

    SetSize(tile.activeDot, math.max(4, RoundMetric(metrics.iconSize * 0.17)), math.max(4, RoundMetric(metrics.iconSize * 0.17)))
    tile.activeDot:ClearAllPoints()
    SetPoint(tile.activeDot, "TOPRIGHT", tile.iconFrame, "TOPRIGHT", 1, 1)
    tile.activeDot:SetShown(active)

    local style = metrics.backgroundStyle
    if style == "TILES" then
        SetRoundedFrame(tile, CopyColor(TC.surfaceRaised or COLORS.row, 0.96), CopyColor(TC.lineStrong or COLORS.panelEdge, 0.72), true, 7)
    else
        SetRoundedFrame(tile, TC.transparent, TC.transparent, false, 7)
    end

    if active then
        SetRoundedFrame(tile.iconFrame, CopyColor(TC.activeDark or COLORS.panel, 0.98), CopyColor(COLORS.active, 1), true, 6)
    elseif style == "NONE" then
        SetRoundedFrame(tile.iconFrame, TC.transparent, TC.transparent, false, 6)
    else
        SetRoundedFrame(tile.iconFrame, CopyColor(TC.input or COLORS.panel, 0.98), CopyColor(TC.lineStrong or COLORS.panelEdge, 0.64), true, 6)
    end

    ConfigureTileActions(tile, ability, owner)
    tile:EnableMouse(true)
    tile:Show()
end

local function ConfigureScanToken(token, entry, abbreviations, paused, metrics)
    token.entry = entry
    SetSize(token, metrics.scanTokenWidth, metrics.scanTokenHeight)

    SetSize(token.portraitFrame, metrics.scanIconSize, metrics.scanIconSize)
    SetSize(token.sweep, math.max(5, RoundMetric(metrics.scanIconSize * 0.22)), metrics.scanIconSize + 6)
    if token.sweepTranslation and token.sweepTranslation.SetOffset then
        token.sweepTranslation:SetOffset(metrics.scanIconSize + 12, 0)
    end
    local badgeSize = math.max(7, RoundMetric(metrics.scanIconSize * 0.34))
    SetSize(token.roleBadge, badgeSize, badgeSize)
    ApplyReadableFont(token.roleText, math.max(5.6, badgeSize * 0.64), "BOLD")
    SetSize(token.statusDot, math.max(3, RoundMetric(metrics.scanIconSize * 0.15)), math.max(3, RoundMetric(metrics.scanIconSize * 0.15)))
    token.portraitFrame:ClearAllPoints()
    SetPoint(token.portraitFrame, "TOP", token, "TOP", 0, 0)

    SetClassTexture(token.portrait, entry.class, entry.cachedSpecID)

    token.nameText:ClearAllPoints()
    ApplyReadableFont(token.nameText, metrics.scanNameFont, "BOLD")
    SetPoint(token.nameText, "TOPLEFT", token.portraitFrame, "BOTTOMLEFT", -2, -1)
    SetPoint(token.nameText, "TOPRIGHT", token.portraitFrame, "BOTTOMRIGHT", 2, -1)
    token.nameText:SetText(GetDisplayAbbreviation(abbreviations, entry.name, metrics.nameLength))
    local r, g, b = RA:GetClassColor(entry.class)
    token.nameText:SetTextColor(r, g, b, entry.state == "OFFLINE" and 0.45 or 0.92)

    local role = entry.role or "NONE"
    local roleColor = ROLE_COLORS[role] or ROLE_COLORS.NONE
    token.roleText:SetText(ROLE_LETTERS[role] or "?")
    token.roleText:SetTextColor(roleColor[1], roleColor[2], roleColor[3], 1)

    token.sweepAnimation:Stop()
    token.sweep:Hide()
    token.statusDot:Hide()
    token.portrait:SetDesaturated(true)
    token.portrait:SetVertexColor(0.58, 0.62, 0.68, 1)
    token:SetAlpha(0.55)
    SetRoundedFrame(token.portraitFrame, CopyColor(TC.input or COLORS.panel, 0.96), CopyColor(TC.line or COLORS.panelEdge, 0.46), true, 6)

    if entry.current then
        token:SetAlpha(1)
        token.portrait:SetVertexColor(0.90, 0.94, 1.00, 1)
        token.portrait:SetDesaturated(paused)
        if paused then
            SetRoundedFrame(token.portraitFrame, CopyColor(TC.input or COLORS.panel, 0.98), CopyColor(COLORS.amber, 0.95), true, 6)
        else
            SetRoundedFrame(token.portraitFrame, CopyColor(TC.activeDark or COLORS.panel, 0.96), CopyColor(COLORS.accentBlue, 1), true, 6)
            token.sweep:Show()
            token.sweepAnimation:Play()
        end
    elseif entry.state == "OUT_OF_RANGE" then
        token:SetAlpha(0.43)
        SetRoundedFrame(token.portraitFrame, CopyColor(TC.input or COLORS.panel, 0.96), CopyColor(COLORS.amber, 0.62), true, 6)
        token.statusDot:SetColorTexture(COLORS.amber[1], COLORS.amber[2], COLORS.amber[3], 0.92)
        token.statusDot:Show()
    elseif entry.state == "TIMEOUT" or entry.state == "FAILED" then
        token:SetAlpha(0.46)
        SetRoundedFrame(token.portraitFrame, CopyColor(TC.input or COLORS.panel, 0.96), CopyColor(COLORS.danger, 0.65), true, 6)
        token.statusDot:SetColorTexture(COLORS.danger[1], COLORS.danger[2], COLORS.danger[3], 0.92)
        token.statusDot:Show()
    elseif entry.state == "OFFLINE" then
        token:SetAlpha(0.26)
        token.portrait:SetVertexColor(0.36, 0.38, 0.42, 1)
    elseif entry.state == "PAUSED" then
        token:SetAlpha(0.62)
        SetRoundedFrame(token.portraitFrame, CopyColor(TC.input or COLORS.panel, 0.96), CopyColor(COLORS.amber, 0.52), true, 6)
    end

    token:Show()
end

local function LayoutScanShell(y, xOffset, abbreviations, inspected, total, isDemo, scanning, currentName, paused, metrics, pending)
    pending = pending or RA:GetPendingScanEntries()
    local incomplete = inspected < total
    local show = metrics.scanVisible and not RA.InEncounter and total > 0 and (incomplete or scanning or paused or #pending > 0)

    for i = 1, #scanTokenPool do
        local token = scanTokenPool[i]
        token.sweepAnimation:Stop()
        token.sweep:Hide()
        token:Hide()
    end

    if not show then
        scanShell:Hide()
        return y, 0, false
    end

    local geometry = RA.CompactLayout and RA.CompactLayout:GetScanGeometry(#pending, metrics) or nil
    local tokenColumns = geometry and geometry.tokenColumns or math.max(1, math.min(#pending, metrics.scanMaxColumns))
    local tokenRows = geometry and geometry.tokenRows or (#pending > 0 and math.ceil(#pending / metrics.scanMaxColumns) or 0)
    local shellWidth = geometry and geometry.shellWidth or metrics.scanMinWidth
    local shellHeight = geometry and geometry.shellHeight or (2 + metrics.scanTopHeight + metrics.scanPadding)

    scanShell:ClearAllPoints()
    SetPoint(scanShell, "TOPLEFT", HUD, "TOPLEFT", xOffset, y)
    SetSize(scanShell, shellWidth, shellHeight)
    scanShell:Show()

    -- The scan shell now has the same decorative rounded top-edge accent as
    -- compact category ribbons. The actual scan progress is intentionally
    -- separated from that decorative edge and sits below the status row, so
    -- it never has to fight the shell's curved top corners.
    scanProgressTrack:ClearAllPoints()
    SetPoint(scanProgressTrack, "TOPLEFT", scanShell, "TOPLEFT", metrics.scanPadding, -(metrics.scanTopHeight + 2))
    SetPoint(scanProgressTrack, "TOPRIGHT", scanShell, "TOPRIGHT", -metrics.scanPadding, -(metrics.scanTopHeight + 2))
    SetHeight(scanProgressTrack, 1)

    local ratio = total > 0 and math.max(0, math.min(1, inspected / total)) or 0
    scanProgressFill:ClearAllPoints()
    SetPoint(scanProgressFill, "TOPLEFT", scanProgressTrack, "TOPLEFT", 0, 0)
    SetHeight(scanProgressFill, 1)
    SetWidth(scanProgressFill, math.max(1, math.max(1, shellWidth - metrics.scanPadding * 2) * ratio))
    if paused then
        scanProgressFill:SetColorTexture(COLORS.amber[1], COLORS.amber[2], COLORS.amber[3], 1)
    elseif Theme then
        scanProgressFill:SetTexture(Theme:GetAccentAsset("SECONDARY"))
        scanProgressFill:SetVertexColor(1, 1, 1, 1)
    else
        scanProgressFill:SetColorTexture(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
    end

    scanCountText:ClearAllPoints()
    ApplyReadableFont(scanCountText, metrics.scanStatusFont, "BOLD")
    SetPoint(scanCountText, "TOPLEFT", scanShell, "TOPLEFT", metrics.scanPadding, -5)
    scanCountText:SetText(string.format("%d/%d", inspected, total))

    scanControlButton:ClearAllPoints()
    SetPoint(scanControlButton, "TOPRIGHT", scanShell, "TOPRIGHT", -3, -3)
    SetSize(scanControlButton, metrics.scanControlSize, metrics.scanControlSize)
    ApplyReadableFont(scanControlButton.text, math.max(7.0, metrics.scanStatusFont), "BOLD")
    SetScanControlVisual(scanControlButton, scanning, paused, incomplete)

    scanCurrentText:ClearAllPoints()
    ApplyReadableFont(scanCurrentText, metrics.scanStatusFont, "BOLD")
    SetPoint(scanCurrentText, "LEFT", scanCountText, "RIGHT", 5, 0)
    SetPoint(scanCurrentText, "RIGHT", scanControlButton, "LEFT", -4, 0)
    if paused then
        scanCurrentText:SetText("PAUSED")
        scanCurrentText:SetTextColor(COLORS.amber[1], COLORS.amber[2], COLORS.amber[3], 1)
    elseif scanning and currentName then
        scanCurrentText:SetText("SCAN " .. GetDisplayAbbreviation(abbreviations, currentName, metrics.nameLength))
        scanCurrentText:SetTextColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
    elseif scanning then
        scanCurrentText:SetText("SCANNING")
        scanCurrentText:SetTextColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
    else
        scanCurrentText:SetText("RETRY")
        scanCurrentText:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], 1)
    end

    local tokenStartY = geometry and geometry.tokenStartY or -(2 + metrics.scanTopHeight + 3)
    for i = 1, #pending do
        local token = GetScanToken(i)
        token:SetParent(scanShell)
        local column = (i - 1) % metrics.scanMaxColumns
        local row = math.floor((i - 1) / metrics.scanMaxColumns)
        local x = metrics.scanPadding + column * (metrics.scanTokenWidth + metrics.scanTokenGap)
        local tokenY = tokenStartY - row * (metrics.scanTokenHeight + metrics.scanRowGap)
        token:ClearAllPoints()
        SetPoint(token, "TOPLEFT", scanShell, "TOPLEFT", x, tokenY)
        ConfigureScanToken(token, pending[i], abbreviations, paused, metrics)
    end

    return y - shellHeight - metrics.categoryGap, shellWidth, true
end

local function BuildCompactCategoryEntries(category, ownersByAbility, metrics)
    local entries = {}
    local orderedAbilities = RA.GetOrderedAbilities and RA:GetOrderedAbilities(category.key) or RA.Catalog
    for i = 1, #orderedAbilities do
        local ability = orderedAbilities[i]
        local owners = ownersByAbility[ability.index]
        if ability.category == category.key and owners and #owners > 0 and RA:IsAbilityEnabled(ability) then
            for ownerIndex = 1, #owners do
                entries[#entries + 1] = {
                    ability = ability,
                    owner = owners[ownerIndex],
                }
            end
        end
    end

    if metrics and metrics.overflowMode == "LIMIT" and #entries > metrics.wrapAfter then
        for i = #entries, metrics.wrapAfter + 1, -1 do
            entries[i] = nil
        end
    end
    return entries
end

local function LayoutCompactLane(lane, category, entries, y, xOffset, tileStartIndex, abbreviations, metrics)
    local geometry = RA.CompactLayout and RA.CompactLayout:GetLaneGeometry(#entries, metrics) or nil
    local hasLabel = geometry and geometry.hasLabel or metrics.labelWidth > 0
    local labelGap = geometry and geometry.labelGap or (hasLabel and 3 or 0)
    local laneWidth = geometry and geometry.laneWidth or metrics.emptyWidth
    local laneHeight = geometry and geometry.laneHeight or metrics.emptyHeight

    lane:ClearAllPoints()
    SetPoint(lane, "TOPLEFT", HUD, "TOPLEFT", xOffset, y)
    SetSize(lane, laneWidth, laneHeight)

    local ribbon = metrics.backgroundStyle == "RIBBONS"
    if ribbon then
        SetRoundedFrame(lane, CopyColor(TC.surface or COLORS.row, 0.96), CopyColor(TC.lineStrong or COLORS.panelEdge, 0.46), true, 8)
        lane.accent:Show()
    else
        SetRoundedFrame(lane, TC.transparent, TC.transparent, false, 7)
        lane.accent:Hide()
    end

    lane.label:SetShown(hasLabel)
    if hasLabel then
        lane.label:ClearAllPoints()
        ApplyReadableFont(lane.label, metrics.categoryFont, "BOLD")
        lane.label:SetJustifyH("CENTER")
        lane.label:SetJustifyV("MIDDLE")
        lane.label:SetWordWrap(false)
        SetPoint(lane.label, "LEFT", lane, "LEFT", metrics.lanePadding, 0)
        SetSize(lane.label, metrics.labelWidth, laneHeight)
        if metrics.labelMode == "FULL" then
            lane.label:SetText(string.upper(category.name))
        else
            lane.label:SetText(category.compactLabel or CATEGORY_COMPACT_LABELS[category.key] or string.upper(category.shortName or category.name))
        end
        local color = CATEGORY_LABEL_COLORS[category.key] or COLORS.muted
        lane.label:SetTextColor(color[1], color[2], color[3], 1)
    end

    lane:Show()
    for i = 1, #entries do
        local tileIndex = tileStartIndex + i - 1
        local tile = GetCompactTile(tileIndex)
        tile:SetParent(lane)
        local x, tileY
        if RA.CompactLayout and geometry then
            x, tileY = RA.CompactLayout:GetTilePosition(i, metrics, geometry)
        else
            local column = (i - 1) % metrics.wrapAfter
            local row = math.floor((i - 1) / metrics.wrapAfter)
            x = metrics.lanePadding + metrics.labelWidth + labelGap + column * (metrics.tileWidth + metrics.tileGap)
            tileY = -metrics.lanePadding - row * (metrics.tileHeight + metrics.tileRowGap)
        end
        tile:ClearAllPoints()
        SetPoint(tile, "TOPLEFT", lane, "TOPLEFT", x, tileY)
        ConfigureCompactTile(tile, entries[i].ability, entries[i].owner, abbreviations, activeStates[entries[i].ability.key] == true, metrics)
    end

    return y - laneHeight - metrics.categoryGap, laneWidth, tileStartIndex + #entries
end

local DEMO_SCAN_PENDING = {
    { name = "Free-Zuljin", class = "SHAMAN", role = "HEALER", state = "CURRENT", current = true, cachedSpecID = 264 },
    { name = "Gold-Zuljin", class = "PRIEST", role = "HEALER", state = "QUEUED", cachedSpecID = 257 },
    { name = "Drog-Zuljin", class = "DEATHKNIGHT", role = "DAMAGER", state = "QUEUED", cachedSpecID = 252 },
    { name = "Rook-Zuljin", class = "PALADIN", role = "TANK", state = "OUT_OF_RANGE", cachedSpecID = 66 },
    { name = "Luck-Zuljin", class = "DRUID", role = "HEALER", state = "QUEUED", cachedSpecID = 105 },
    { name = "Nola-Zuljin", class = "MONK", role = "HEALER", state = "QUEUED", cachedSpecID = 270 },
    { name = "Flad-Zuljin", class = "EVOKER", role = "HEALER", state = "QUEUED", cachedSpecID = 1468 },
}

local function GetDisplayScanState(db, inspected, total, isDemo, scanning, currentName, paused)
    if isDemo and db.scan and db.scan.demoPreview then
        return 13, 20, true, "Free-Zuljin", false, DEMO_SCAN_PENDING
    end
    return inspected, total, scanning, currentName, paused, RA:GetPendingScanEntries()
end

local function RefreshCompactHUD(db, ownersByAbility, inspected, total, isDemo, scanning, currentName, paused)
    HideDetailedFrames()
    HideCompactFrames()
    if panicHUDButton then panicHUDButton:Hide() end

    currentMode = "COMPACT"
    local metrics = GetCompactMetrics(db)
    local pending
    inspected, total, scanning, currentName, paused, pending = GetDisplayScanState(db, inspected, total, isDemo, scanning, currentName, paused)
    local panelStyle = metrics.backgroundStyle == "PANEL"
    if panelStyle then
        SetRoundedFrame(HUD, CopyColor(TC.canvasDeep or COLORS.panel, 0.97), CopyColor(TC.lineStrong or COLORS.panelEdge, 0.68), true, 9)
        shadow:SetAlpha(math.min(0.34, (db.opacity or 0.96) * 0.34))
        shadow:Show()
    else
        SetRoundedFrame(HUD, TC.transparent, TC.transparent, false, 9)
        shadow:Hide()
    end

    local abbreviations = BuildAbbreviationMap(metrics.nameLength)
    -- The scan shell and the first cooldown lane deliberately share this
    -- immutable top-left origin. When the temporary scanner collapses, the
    -- first category occupies the exact same anchored position.
    local xOffset = metrics.panelPadding
    local originY = -metrics.panelPadding
    local y = originY
    local maxContentWidth = 0
    local scanVisible
    local scanWidth
    y, scanWidth, scanVisible = LayoutScanShell(y, xOffset, abbreviations, inspected, total, isDemo, scanning, currentName, paused, metrics, pending)
    maxContentWidth = math.max(maxContentWidth, scanWidth)

    local laneIndex = 0
    local tileIndex = 1
    local visibleTiles = 0
    for c = 1, #RA.Categories do
        local category = RA.Categories[c]
        if RA:IsCategoryEnabled(category.key) then
            local entries = BuildCompactCategoryEntries(category, ownersByAbility, metrics)
            if #entries > 0 then
                laneIndex = laneIndex + 1
                visibleTiles = visibleTiles + #entries
                local laneWidth
                local lane = GetCompactLane(laneIndex)
                y, laneWidth, tileIndex = LayoutCompactLane(lane, category, entries, y, xOffset, tileIndex, abbreviations, metrics)
                if laneIndex == 1 then PositionPanicButton(lane) end
                maxContentWidth = math.max(maxContentWidth, laneWidth)
            end
        end
    end

    if visibleTiles == 0 and not scanVisible and metrics.showEmptyState then
        compactEmpty:ClearAllPoints()
        SetPoint(compactEmpty, "TOPLEFT", HUD, "TOPLEFT", xOffset, y)
        SetSize(compactEmpty, metrics.emptyWidth, metrics.emptyHeight)
        ApplyReadableFont(compactEmpty.text, math.max(8, metrics.nameFont), "BOLD")
        compactEmpty.text:SetText("NO TOOLS")
        compactEmpty:Show()
        maxContentWidth = math.max(maxContentWidth, metrics.emptyWidth)
        y = y - metrics.emptyHeight
    end

    if y < -metrics.panelPadding then
        y = y + metrics.categoryGap
    end
    hudHasRenderableContent = visibleTiles > 0 or scanVisible or metrics.showEmptyState
    local width = math.max(1, maxContentWidth + metrics.panelPadding * 2)
    local height = math.max(1, -y + metrics.panelPadding)
    SetSize(HUD, width, height)
    if panelStyle then
        SetSize(shadow, width + 8, height + 8)
    end
end

function RA:RefreshHUD()
    if not HUD then
        return
    end
    if InCombatLockdown() or self.InEncounter then
        refreshAfterCombat = true
        return
    end

    refreshAfterCombat = false
    local db = self:GetDB()
    local ownersByAbility = self:BuildAbilityOwners()
    local inspected, total, isDemo = self:GetVerificationStatus()
    local _, _, _, scanning, currentName, paused = self:GetInspectionProgress()
    if isDemo and db.scan and db.scan.demoPreview then
        inspected, total, scanning, currentName, paused = GetDisplayScanState(db, inspected, total, isDemo, scanning, currentName, paused)
    end

    HUD:SetScale(db.scale or 1)
    shadow:SetScale(db.scale or 1)
    HUD:SetAlpha(db.opacity or 0.94)
    BindHUDToAnchor()
    ArmPanicButton()

    if db.mode == "DETAILED" then
        RefreshDetailedHUD(db, ownersByAbility, inspected, total, isDemo, scanning, paused)
    else
        RefreshCompactHUD(db, ownersByAbility, inspected, total, isDemo, scanning, currentName, paused)
    end

    self:UpdateHUDVisibility()
    NormalizePositionIfNeeded()
end

function RA:GetHUDVisibilityReason()
    local db = self:GetDB()
    if not db.shown then
        return "HUD is toggled off"
    end
    if db.hideWhenSolo and not IsInGroup() and not db.demoMode then
        return "hidden while solo"
    end
    if db.leaderOnly and IsInGroup() and not UnitIsGroupLeader("player") and not UnitIsGroupAssistant("player") then
        return "leader/assistant-only visibility"
    end
    if not hudHasRenderableContent and not (db.compact and db.compact.showEmptyState) then
        return "no visible tools"
    end
    return nil
end

function RA:UpdateHUDVisibility()
    if not HUD or InCombatLockdown() then
        return
    end

    local reason = self:GetHUDVisibilityReason()
    lastVisibilityReason = reason
    if not reason then
        HUD:Show()
    else
        HUD:Hide()
    end
end

function RA:RecoverHUD()
    if InCombatLockdown() then
        self:Print("HUD recovery is unavailable during combat.")
        return
    end
    local db = self:GetDB()
    db.shown = true
    db.leaderOnly = false
    db.position = { point = "CENTER", relativePoint = "CENTER", x = -360, y = 100 }
    db.positionAnchorVersion = 0
    positionNormalized = false
    RestorePosition()
    self:RefreshHUD()
end

function RA:GetLastHUDVisibilityReason()
    return lastVisibilityReason
end

function RA:ShowHUD()
    if InCombatLockdown() then
        self:Print("The secure HUD cannot be shown during combat. Show it before the pull.")
        return
    end
    self:GetDB().shown = true
    self:RefreshHUD()
end

function RA:HideHUD()
    if InCombatLockdown() then
        self:Print("The secure HUD cannot be hidden during combat.")
        return
    end
    self:GetDB().shown = false
    self:UpdateHUDVisibility()
end

function RA:SetLocked(locked)
    if InCombatLockdown() then
        self:Print("HUD locking cannot be changed during combat.")
        return
    end
    self:GetDB().locked = locked and true or false
    ApplyLockState()
end

function RA:SetMode(newMode)
    if newMode ~= "COMPACT" and newMode ~= "DETAILED" then
        return
    end
    if InCombatLockdown() then
        self:Print("HUD mode cannot be changed during combat.")
        return
    end
    self:GetDB().mode = newMode
    self:RefreshHUD()
end

function RA:SetDemoMode(enabled)
    if InCombatLockdown() then
        self:Print("Demo mode cannot be changed during combat.")
        return
    end
    self:GetDB().demoMode = enabled and true or false
    self:RefreshHUD()
    self:FireCallback("DEMO_MODE_CHANGED", self:GetDB().demoMode)
end

function RA:SetAbilityActive(abilityKey, active)
    if not self.CatalogByKey[abilityKey] then
        return false
    end
    activeStates[abilityKey] = active and true or nil
    self:RefreshHUD()
    return true
end

function RA:ClearActiveStates()
    wipe(activeStates)
    self:RefreshHUD()
end

function RA:GetActiveStates()
    return activeStates
end

function RA:GetSecureActionStatus()
    local visible, armed = 0, 0
    for i = 1, #compactTilePool do
        local tile = compactTilePool[i]
        if tile and tile:IsShown() then
            visible = visible + 1
            local leftArmed = tile:GetAttribute("type1") == "macro" and type(tile:GetAttribute("macrotext1")) == "string"
            local rightArmed = tile:GetAttribute("type2") == "macro" and type(tile:GetAttribute("macrotext2")) == "string"
            if leftArmed or rightArmed then
                armed = armed + 1
            end
        end
    end
    local keyDown = GetCVarBool and GetCVarBool("ActionButtonUseKeyDown") or false
    return armed, visible, keyDown and "KEY DOWN" or "KEY UP"
end

function RA:RefreshPanicButton()
    if InCombatLockdown() then return false end
    ArmPanicButton()
    self:RefreshHUD()
    return true
end

function RA:RearmSecureActions()
    if InCombatLockdown() then return false end
    self:RefreshHUD()
    return true
end

local function QueueHUDRefresh()
    if InCombatLockdown() or RA.InEncounter then
        refreshAfterCombat = true
        return
    end
    if hudRefreshQueued then
        return
    end

    -- During an inspect pass, capability results can arrive roughly twice per
    -- second. Rebuilding every secure tile, rounded surface and category lane on
    -- each reply is unnecessary and can hitch the client. Batch those rebuilds
    -- while still letting the lightweight scan strip animate independently.
    local delay = (RA.IsInspectionRunning and RA:IsInspectionRunning()) and 0.65 or 0
    hudRefreshQueued = true
    C_Timer.After(delay, function()
        hudRefreshQueued = false
        RA:RefreshHUD()
    end)
end

local function RefreshScanVisualsOnly()
    if not HUD or currentMode ~= "COMPACT" or not scanShell or not scanShell:IsShown() then
        return
    end
    if InCombatLockdown() or RA.InEncounter then
        return
    end

    local db = RA:GetDB()
    local metrics = GetCompactMetrics(db)
    local inspected, total, isDemo = RA:GetVerificationStatus()
    local _, _, _, scanning, currentName, paused = RA:GetInspectionProgress()
    local pending
    inspected, total, scanning, currentName, paused, pending = GetDisplayScanState(db, inspected, total, isDemo, scanning, currentName, paused)

    local shellWidth = scanShell:GetWidth() or metrics.scanMinWidth
    local ratio = total > 0 and math.max(0, math.min(1, inspected / total)) or 0
    SetWidth(scanProgressFill, math.max(1, (shellWidth - 2) * ratio))
    scanCountText:SetText(string.format("%d/%d", inspected, total))
    SetScanControlVisual(scanControlButton, scanning, paused, inspected < total)

    if paused then
        scanCurrentText:SetText("PAUSED")
        scanCurrentText:SetTextColor(COLORS.amber[1], COLORS.amber[2], COLORS.amber[3], 1)
    elseif scanning and currentName then
        local abbreviations = BuildAbbreviationMap(metrics.nameLength)
        scanCurrentText:SetText("SCAN " .. GetDisplayAbbreviation(abbreviations, currentName, metrics.nameLength))
        scanCurrentText:SetTextColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
    elseif scanning then
        scanCurrentText:SetText("SCANNING")
        scanCurrentText:SetTextColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
    else
        scanCurrentText:SetText("RETRY")
        scanCurrentText:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], 1)
    end

    -- Re-style existing pending tokens in place. This does not allocate or move
    -- the cooldown lanes, so changing the active inspect target is cheap.
    local pendingByName = {}
    for i = 1, #(pending or {}) do
        pendingByName[pending[i].name] = pending[i]
    end
    local abbreviations = BuildAbbreviationMap(metrics.nameLength)
    for i = 1, #scanTokenPool do
        local token = scanTokenPool[i]
        if token and token:IsShown() and token.entry and token.entry.name then
            local entry = pendingByName[token.entry.name]
            if entry then
                ConfigureScanToken(token, entry, abbreviations, paused, metrics)
            end
        end
    end
end

local function QueueScanVisualRefresh()
    if scanVisualRefreshQueued then return end
    scanVisualRefreshQueued = true
    C_Timer.After(0, function()
        scanVisualRefreshQueued = false
        RefreshScanVisualsOnly()
    end)
end

local function CreateScanButton(parent)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    SetRoundedFrame(button, CopyColor(TC.input or COLORS.panel, 0.98), CopyColor(TC.lineStrong or COLORS.panelEdge, 0.68), true, 6)
    button.text = CreateFontString(button, 6.8, COLORS.text, "BOLD")
    button.text:SetJustifyH("CENTER")
    SetPoint(button.text, "CENTER", button, "CENTER", 0, 0)
    button:SetScript("OnEnter", function(self)
        SetRoundedFrame(self, CopyColor(TC.surfaceHover or COLORS.rowHover, 0.99), CopyColor(TC.magenta or COLORS.accent, 0.55), true, 6)
    end)
    button:SetScript("OnLeave", function(self)
        SetRoundedFrame(self, CopyColor(TC.input or COLORS.panel, 0.98), CopyColor(TC.lineStrong or COLORS.panelEdge, 0.68), true, 6)
    end)
    button:SetScript("OnClick", HandleScanControl)
    SetScanControlTooltip(button)
    return button
end

local function CreateHUD()
    -- Stable, unscaled screen anchor. The secure HUD is attached to this
    -- point and is never itself used as the movable frame.
    hudAnchor = CreateFrame("Frame", "RCPArsenalHUDAnchor", UIParent)
    hudAnchor:SetSize(1, 1)
    hudAnchor:SetScale(1)

    shadow = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    shadow:SetFrameStrata("MEDIUM")
    shadow:SetFrameLevel(8)
    shadow:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
    shadow:SetBackdropColor(0, 0, 0, 0.48)
    shadow:EnableMouse(false)

    HUD = CreateFrame("Frame", "RCPArsenalHUD", UIParent, "BackdropTemplate")
    HUD:SetFrameStrata("MEDIUM")
    HUD:SetFrameLevel(10)
    HUD:SetClampedToScreen(false)
    HUD:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    SetRoundedFrame(HUD, TC.canvasDeep or COLORS.panel, TC.lineStrong or COLORS.panelEdge, true, 8)
    BindHUDToAnchor()

    SetPoint(shadow, "CENTER", HUD, "CENTER", 2, -3)

    -- Detailed mode uses the same rounded top-edge accent asset as the
    -- compact category ribbons and scan shell.
    topAccent = HUD:CreateTexture(nil, "ARTWORK")
    if Theme then
        Theme:RegisterAccentTexture(topAccent, "TOP")
    else
        topAccent:SetColorTexture(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
    end
    topAccent:SetAllPoints(HUD)
    if topAccent.SetTextureSliceMargins then pcall(topAccent.SetTextureSliceMargins, topAccent, 10, 10, 10, 10) end
    if topAccent.SetTextureSliceMode then
        local stretched = Enum and Enum.UITextureSliceMode and Enum.UITextureSliceMode.Stretched or 0
        pcall(topAccent.SetTextureSliceMode, topAccent, stretched)
    end
    if topAccent.SetTexelSnappingBias then pcall(topAccent.SetTexelSnappingBias, topAccent, 0) end
    topAccent:SetAlpha(0.66)

    headerTitle = CreateFontString(HUD, 11, COLORS.text, "BOLD")
    headerStatus = CreateFontString(HUD, 8.5, COLORS.muted, "REGULAR")
    headerMode = CreateFontString(HUD, 8, COLORS.muted, "BOLD")
    headerLine = CreateSolidTexture(HUD, "ARTWORK", {0.11, 0.14, 0.18, 1})
    emptyState = CreateFontString(HUD, 9.5, COLORS.muted, "BOLD")
    emptyState:SetJustifyH("CENTER")

    detailedPauseButton = CreateScanButton(HUD)

    scanShell = CreateFrame("Frame", nil, HUD, "BackdropTemplate")
    SetRoundedFrame(scanShell, CopyColor(TC.surface or COLORS.row, 0.98), CopyColor(TC.lineStrong or COLORS.panelEdge, 0.52), true, 8)

    -- Match the category ribbons exactly: one rounded top-edge asset follows
    -- the scan shell's curved outer shape. Progress itself is drawn lower in
    -- the header and no longer doubles as the shell border.
    scanAccent = scanShell:CreateTexture(nil, "ARTWORK")
    if Theme then
        Theme:RegisterAccentTexture(scanAccent, "TOP")
    else
        scanAccent:SetColorTexture(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
    end
    scanAccent:SetAllPoints(scanShell)
    if scanAccent.SetTextureSliceMargins then
        pcall(scanAccent.SetTextureSliceMargins, scanAccent, 10, 10, 10, 10)
    end
    if scanAccent.SetTextureSliceMode then
        local stretched = Enum and Enum.UITextureSliceMode and Enum.UITextureSliceMode.Stretched or 0
        pcall(scanAccent.SetTextureSliceMode, scanAccent, stretched)
    end
    if scanAccent.SetTexelSnappingBias then
        pcall(scanAccent.SetTexelSnappingBias, scanAccent, 0)
    end
    scanAccent:SetAlpha(0.62)

    scanProgressTrack = CreateSolidTexture(scanShell, "ARTWORK", CopyColor(TC.input or COLORS.panel, 0.90))
    scanProgressFill = scanShell:CreateTexture(nil, "OVERLAY")
    if Theme then
        Theme:RegisterAccentTexture(scanProgressFill, "SECONDARY")
    else
        scanProgressFill:SetColorTexture(COLORS.accentBlue[1], COLORS.accentBlue[2], COLORS.accentBlue[3], 1)
    end

    scanCountText = CreateFontString(scanShell, 7.8, COLORS.muted, "BOLD")
    scanCurrentText = CreateFontString(scanShell, 7.8, COLORS.accent, "BOLD")
    scanCurrentText:SetJustifyH("CENTER")

    scanControlButton = CreateScanButton(scanShell)

    compactEmpty = CreateFrame("Frame", nil, HUD, "BackdropTemplate")
    SetRoundedFrame(compactEmpty, CopyColor(TC.surface or COLORS.row, 0.95), CopyColor(TC.lineStrong or COLORS.panelEdge, 0.55), true, 7)
    compactEmpty.text = CreateFontString(compactEmpty, 8.2, COLORS.muted, "BOLD")
    compactEmpty.text:SetJustifyH("CENTER")
    SetPoint(compactEmpty.text, "CENTER", compactEmpty, "CENTER", 0, 0)

    -- Dedicated mover tab, shown only while the HUD is unlocked. It is
    -- parented to UIParent rather than the secure HUD hierarchy.
    moveHandle = CreateFrame("Button", "RCPArsenalHUDMover", UIParent, "BackdropTemplate")
    moveHandle:SetFrameStrata("MEDIUM")
    moveHandle:SetFrameLevel(12)
    moveHandle:SetClampedToScreen(false)
    moveHandle:EnableMouse(true)
    moveHandle:RegisterForDrag("LeftButton")
    SetSize(moveHandle, 18, 34)
    SetRoundedFrame(moveHandle, CopyColor(TC.surfaceRaised or COLORS.row, 0.98), CopyColor(TC.lineStrong or COLORS.panelEdge, 0.72), true, 7)
    SetPoint(moveHandle, "TOPLEFT", HUD, "TOPRIGHT", 3, -7)
    for i = 1, 6 do
        local dot = moveHandle:CreateTexture(nil, "ARTWORK")
        dot:SetColorTexture(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], 0.82)
        SetSize(dot, 2, 2)
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        SetPoint(dot, "CENTER", moveHandle, "CENTER", col == 0 and -3 or 3, 6 - row * 6)
    end
    moveHandle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Move RCP Arsenal")
        GameTooltip:AddLine("Drag this tab to move the HUD.", 0.82, 0.87, 0.94)
        GameTooltip:Show()
    end)
    moveHandle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    moveHandle:SetScript("OnDragStart", function()
        GameTooltip:Hide()
        StartHUDDrag()
    end)
    moveHandle:SetScript("OnDragStop", function() StopHUDDrag(true) end)
    moveHandle:Hide()

    -- Emergency encounter action lives with the ability categories rather
    -- than the setup-oriented Quick Bar. It is armed out of combat and stays
    -- usable during combat as a secure hardware-click Raid Warning.
    panicHUDButton = CreateFrame("Button", "RCPArsenalHUDPanicButton", UIParent, "SecureActionButtonTemplate,BackdropTemplate")
    panicHUDButton:SetFrameStrata("MEDIUM")
    panicHUDButton:SetFrameLevel(13)
    panicHUDButton:SetClampedToScreen(false)
    panicHUDButton:RegisterForClicks("AnyDown", "AnyUp")
    SetSize(panicHUDButton, 22, 22)
    SetRoundedFrame(panicHUDButton, CopyColor(TC.surfaceRaised or COLORS.row, 0.995), CopyColor(COLORS.danger, 0.86), true, 8)
    panicHUDButton.label = CreateFontString(panicHUDButton, 13.0, COLORS.danger, "BOLD")
    panicHUDButton.label:SetText("!")
    SetPoint(panicHUDButton.label, "CENTER", panicHUDButton, "CENTER", 0, 0)
    panicHUDButton:SetScript("OnEnter", function(self)
        CancelPanicTooltip()
        local delay = ((RA:GetDB().leaderToolbox or {}).tooltipDelay or 0.75)
        panicTooltipTimer = C_Timer.NewTimer(delay, function()
            panicTooltipTimer = nil
            local over = MouseIsOver and MouseIsOver(self)
            if over then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("PANIC")
                GameTooltip:AddLine("Raid Warning: use defensives + health potions now.", 1.0, 0.62, 0.25, true)
                GameTooltip:AddLine("One click = one message.", 0.72, 0.78, 0.86)
                GameTooltip:Show()
            end
        end)
    end)
    panicHUDButton:SetScript("OnLeave", CancelPanicTooltip)
    panicHUDButton:Hide()
    ArmPanicButton()

    HUD:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" and not InCombatLockdown() and RA.OpenConfig then
            RA:OpenConfig()
        end
    end)

    HUD:SetScript("OnShow", function()
        if currentMode == "DETAILED" then shadow:Show() end
        ApplyLockState()
    end)
    HUD:SetScript("OnHide", function()
        shadow:Hide()
        if moveHandle then moveHandle:Hide() end
        if panicHUDButton then panicHUDButton:Hide() end
    end)

    RestorePosition()
    ApplyLockState()
end

RA:RegisterInitializer(function()
    CreateHUD()
    RA:RefreshHUD()
end)

RA:RegisterCallback("REPORTS_UPDATED", QueueHUDRefresh)
RA:RegisterCallback("REPORTS_FROZEN", QueueHUDRefresh)
RA:RegisterCallback("INSPECTION_STATE_CHANGED", QueueScanVisualRefresh)
RA:RegisterCallback("ACCENT_THEME_CHANGED", QueueHUDRefresh)
RA:RegisterCallback("VISUAL_ASSET_REFRESH", function()
    -- PANIC is a glyph, not a spell texture. Registered fonts and icons can
    -- refresh in place without rebuilding the protected HUD or its geometry.
    if panicHUDButton and panicHUDButton.label then
        if RA.ApplyFont then RA:ApplyFont(panicHUDButton.label, 13, "BOLD", false) end
        panicHUDButton.label:SetText("!")
        panicHUDButton.label:SetTextColor(COLORS.danger[1], COLORS.danger[2], COLORS.danger[3], 1)
    end
end)

RA:RegisterCallback("PROFILE_RESET", function()
    positionNormalized = false
    RestorePosition()
    ApplyLockState()
    QueueHUDRefresh()
end)

RA:RegisterCallback("ENCOUNTER_STATE_CHANGED", function(inEncounter)
    if RA.ConfigFrame and RA.ConfigFrame:IsShown() then
        RA.ConfigFrame:Hide()
    end

    if inEncounter and RA:GetDB().autoShowEncounter then
        RA:GetDB().shown = true
        -- Secure tiles must already be visible/configured before combat. Do not
        -- rebuild or show protected frames at the encounter boundary.
        if not HUD:IsShown() then
            refreshAfterCombat = true
        end
        return
    end
    QueueHUDRefresh()
end)

RA:RegisterEvent("PLAYER_REGEN_DISABLED", function()
    if hudDragState then StopHUDDrag(true) end
    if moveHandle then moveHandle:Hide() end
end)

RA:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    ApplyLockState()
    if refreshAfterCombat and not RA.InEncounter then
        QueueHUDRefresh()
    end
end)


RA:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    -- World transitions may change roster data, but they must never rewrite
    -- the user's screen anchor. Refresh content only; position is restored once
    -- when the addon is created and thereafter changes only by explicit drag,
    -- recenter, reset, or a true legacy-position migration.
    C_Timer.After(0.35, function()
        if RA.Initialized and not InCombatLockdown() and not RA.InEncounter then
            QueueHUDRefresh()
        end
    end)
end)
