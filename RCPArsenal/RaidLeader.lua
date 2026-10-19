local _, RA = ...

-- RCP Arsenal Raid Leader Dock
--
-- A tiny draggable launcher expands into a compact, event-driven toolbox.
-- The dock can remain visible in combat, but raid subgroup operations are never
-- attempted during combat lockdown. No permanent OnUpdate polling is used.
--
-- Left-click SORT: Tanks > Melee > Ranged > Healers
-- Right-click SORT: compact sort-options flyout
-- Left-click ODD/EVEN: split across odd/even group pairs
-- Right-click ODD/EVEN: split adjacent halves (G1+G2 / G3+G4 for 20)
-- Hover MISSING: composition coverage for major raid buffs/debuffs

local Theme = RA.Theme
local TC = Theme and Theme.Colors or {}

local Toolbox = {}
RA.RaidLeaderToolbox = Toolbox

local CLOSE_DELAY_DEFAULT = 1.0
local MOVE_TIMEOUT = 1.25
local MAX_SORT_STEPS = 96
local DOCK_WIDTH = 276
local DOCK_WIDTH_NO_MISSING = 211
local DOCK_HEIGHT = 48
local PUCK_SIZE = 30

local puck
local puckAnchor
local puckDragState
local puckPositionNormalized = false
local missingBadge
local dock
local dockMonitor
local dockPinned = false
local monitorButtonsDown = { left = false, right = false, middle = false }
local lastLayoutSnapshot
local sortButton
local splitButton
local missingButton
local missingPanel
local sortOptionsPanel
local closeTimer
local sortTimer
local statusResetTimer
local puckCountdownTimer
local puckCountdownActive = false
local puckWasDragged = false
local pendingMode
local pendingSourceButton
local pendingUnknownCount = 0
local toolboxWasVisible = false
local missingRows = {}
local missingData = { buffs = {}, debuffs = {}, total = 0 }

local sortState = {
    active = false,
    mode = nil,
    modeLabel = nil,
    sourceButton = nil,
    desiredGroupByName = {},
    eligibleNames = {},
    orderedNames = {},
    eligibleCount = 0,
    initialWrong = 0,
    steps = 0,
    expectedName = nil,
    expectedGroup = nil,
    initialSideByName = {},
    assignedSideByName = {},
    sideLabels = nil,
}

-- Complete 12.1 specialization classification. Devourer (1480) is treated
-- as ranged for group-layout purposes.
local SPEC_KIND = {
    [250] = "TANK", [251] = "MELEE", [252] = "MELEE",
    [577] = "MELEE", [581] = "TANK", [1480] = "RANGED",
    [102] = "RANGED", [103] = "MELEE", [104] = "TANK", [105] = "HEALER",
    [1467] = "RANGED", [1468] = "HEALER", [1473] = "RANGED",
    [253] = "RANGED", [254] = "RANGED", [255] = "MELEE",
    [62] = "RANGED", [63] = "RANGED", [64] = "RANGED",
    [268] = "TANK", [269] = "MELEE", [270] = "HEALER",
    [65] = "HEALER", [66] = "TANK", [70] = "MELEE",
    [256] = "HEALER", [257] = "HEALER", [258] = "RANGED",
    [259] = "MELEE", [260] = "MELEE", [261] = "MELEE",
    [262] = "RANGED", [263] = "MELEE", [264] = "HEALER",
    [265] = "RANGED", [266] = "RANGED", [267] = "RANGED",
    [71] = "MELEE", [72] = "MELEE", [73] = "TANK",
}

-- Classes omitted here have ambiguous melee/ranged damage specializations and
-- wait for RCP Arsenal's cached inspection rather than being guessed.
local DAMAGE_CLASS_FALLBACK = {
    DEATHKNIGHT = "MELEE",
    MAGE = "RANGED",
    MONK = "MELEE",
    PALADIN = "MELEE",
    PRIEST = "RANGED",
    ROGUE = "MELEE",
    WARLOCK = "RANGED",
    WARRIOR = "MELEE",
    EVOKER = "RANGED",
}

local ROLE_PRIORITY = {
    TANK = 1,
    MELEE = 2,
    RANGED = 3,
    HEALER = 4,
}

-- Composition coverage only. An online class in a tracked raid group counts as
-- bringing the corresponding major raid buff/debuff. This intentionally does
-- not claim that the buff is currently applied.
local MAJOR_COVERAGE = {
    buffs = {
        { key = "mark_of_the_wild", name = "Mark of the Wild", class = "DRUID", spellID = 1126 },
        { key = "blessing_of_the_bronze", name = "Blessing of the Bronze", class = "EVOKER", spellID = 364342 },
        { key = "devotion_aura", name = "Devotion Aura", effect = "3% DR", class = "PALADIN", spellID = 465 },
        { key = "arcane_intellect", name = "Arcane Intellect", class = "MAGE", spellID = 1459 },
        { key = "power_word_fortitude", name = "Power Word: Fortitude", class = "PRIEST", spellID = 21562 },
        { key = "skyfury", name = "Skyfury", class = "SHAMAN", spellID = 462854 },
        { key = "battle_shout", name = "Battle Shout", class = "WARRIOR", spellID = 6673 },
    },
    debuffs = {
        { key = "hunters_mark", name = "Hunter's Mark", effect = "+3% damage", class = "HUNTER", spellID = 257284 },
        { key = "chaos_brand", name = "Chaos Brand", class = "DEMONHUNTER", spellID = 1490 },
        { key = "mystic_touch", name = "Mystic Touch", class = "MONK", spellID = 113746 },
    },
}

local function IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function CopyColor(color, alpha)
    color = color or {1, 1, 1, 1}
    return {color[1] or 1, color[2] or 1, color[3] or 1, alpha ~= nil and alpha or color[4] or 1}
end

local function SetPoint(region, ...)
    if Theme and Theme.SetPoint then Theme.SetPoint(region, ...) else region:SetPoint(...) end
end

local function SetSize(region, width, height)
    if Theme and Theme.SetSize then Theme.SetSize(region, width, height) else region:SetSize(width, height) end
end

local function SetWidth(region, width)
    if Theme and Theme.SetWidth then Theme.SetWidth(region, width) else region:SetWidth(width) end
end

local function SetHeight(region, height)
    if Theme and Theme.SetHeight then Theme.SetHeight(region, height) else region:SetHeight(height) end
end

local function ApplySurface(frame, background, border, radius, baseKey)
    if not Theme then return end
    baseKey = baseKey or "rlBase"
    radius = radius or 9
    Theme:ApplyRounded(frame, border or TC.lineStrong or {1, 1, 1, 0.12}, radius + 1, baseKey .. "Border", "BACKGROUND", -5)
    Theme:ApplyRounded(frame, background or TC.surfaceRaised or {0.08, 0.08, 0.12, 0.98}, radius, baseKey, "BACKGROUND", -4, {1, -1, -1, 1})
end

local function SetSurface(frame, background, border, baseKey)
    if not Theme or not frame then return end
    baseKey = baseKey or "rlBase"
    Theme:SetRoundedColor(frame, background or TC.surfaceRaised, baseKey)
    Theme:SetRoundedColor(frame, border or TC.lineStrong, baseKey .. "Border")
end

local function Font(parent, size, color, weight)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    if RA.ApplyFont then
        RA:ApplyFont(fs, size, weight or "REGULAR", false)
    else
        fs:SetFont("Fonts\\ARIALN.TTF", size or 10, "")
    end
    color = color or TC.text or {1, 1, 1, 1}
    fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    fs:SetJustifyV("MIDDLE")
    return fs
end

local function CancelTimer(timer)
    if timer and timer.Cancel then timer:Cancel() end
end

local function CrispTexture(texture)
    if not texture then return end
    if texture.SetTexelSnappingBias then pcall(texture.SetTexelSnappingBias, texture, 0) end
    if texture.SetSnapToPixelGrid then pcall(texture.SetSnapToPixelGrid, texture, false) end
end

local function ApplyCrispIcon(texture, asset)
    if not texture then return end
    if asset then
        -- Retail's Texture:SetTexture accepts an explicit filter mode. Using
        -- the larger transparent RCP artwork with linear filtering plus pixel
        -- grid alignment avoids the crunchy, uneven resample the old 128px
        -- addon icon showed at ~30px.
        if Theme and Theme.RegisterAssetTexture then
            Theme:RegisterAssetTexture(texture, asset, 134400, "LINEAR")
        elseif RA.RegisterVisualTexture then
            RA:RegisterVisualTexture(texture, asset, 134400, "LINEAR")
        else
            local ok, applied = pcall(texture.SetTexture, texture, asset, "CLAMP", "CLAMP", "LINEAR")
            if not ok or applied == false then texture:SetTexture(134400) end
        end
    end
    if texture.SetTexelSnappingBias then pcall(texture.SetTexelSnappingBias, texture, 0) end
    if texture.SetSnapToPixelGrid then pcall(texture.SetSnapToPixelGrid, texture, true) end
end

local function IsLeaderOrAssistant()
    if not IsInRaid() then return false end

    local leader = UnitIsGroupLeader and UnitIsGroupLeader("player")
    if leader ~= nil and not IsSecret(leader) and leader == true then return true end

    local assistant = UnitIsGroupAssistant and UnitIsGroupAssistant("player")
    if assistant ~= nil and not IsSecret(assistant) and assistant == true then return true end

    -- Fallback to the raid roster rank. This makes dock visibility resilient
    -- to clients where one of the unit permission helpers is unavailable or
    -- temporarily returns an unusable value during roster transitions.
    if UnitInRaid and GetRaidRosterInfo then
        local raidIndex = UnitInRaid("player")
        if type(raidIndex) == "number" then
            local _, rank = GetRaidRosterInfo(raidIndex)
            if type(rank) == "number" and rank >= 1 then return true end
        end
    end

    return false
end

local function PrintLeadAccessRequired(action)
    if RA and RA.Print then
        RA:Print(string.format("%s requires raid lead or assist.", action or "This Quick Bar action"))
    end
end

local function GetToolboxDB()
    local db = RA:GetDB()
    if not db then return nil end
    db.leaderToolbox = db.leaderToolbox or {}
    local t = db.leaderToolbox
    if t.enabled == nil then t.enabled = true end
    if t.showForNonLeaders == nil then t.showForNonLeaders = true end
    if t.showMissing == nil then t.showMissing = true end
    t.closeDelay = math.max(0.15, math.min(3.0, tonumber(t.closeDelay) or CLOSE_DELAY_DEFAULT))
    t.tooltipDelay = math.max(0.20, math.min(2.5, tonumber(t.tooltipDelay) or 0.75))
    t.puckSize = math.floor(math.max(24, math.min(44, tonumber(t.puckSize) or PUCK_SIZE)) + 0.5)
    t.countdownSeconds = math.floor(math.max(1, math.min(3600, tonumber(t.countdownSeconds) or 15)) + 0.5)
    local validDirection = { AUTO = true, RIGHT = true, LEFT = true, DOWN = true, UP = true }
    t.flyoutDirection = validDirection[t.flyoutDirection] and t.flyoutDirection or "AUTO"
    t.position = t.position or { point = "LEFT", relativePoint = "LEFT", x = 12, y = 70 }
    return t
end

local function ClearPuckCountdownState()
    puckCountdownActive = false
    if puckCountdownTimer then
        puckCountdownTimer:Cancel()
        puckCountdownTimer = nil
    end
end

local function TogglePuckCountdown()
    local db = GetToolboxDB()
    if not db or not C_PartyInfo or not C_PartyInfo.DoCountdown then return end
    if not IsLeaderOrAssistant() then
        PrintLeadAccessRequired("Countdown")
        return
    end

    if puckCountdownActive then
        -- Equivalent to typing /countdown 0.
        C_PartyInfo.DoCountdown(0)
        ClearPuckCountdownState()
        return
    end

    local seconds = math.floor(math.max(1, math.min(3600, tonumber(db.countdownSeconds) or 15)) + 0.5)
    -- Blizzard's /countdown slash command calls this same API.
    C_PartyInfo.DoCountdown(seconds)
    puckCountdownActive = true

    if C_Timer and C_Timer.NewTimer then
        puckCountdownTimer = C_Timer.NewTimer(seconds, function()
            puckCountdownTimer = nil
            puckCountdownActive = false
        end)
    end
end

local function BindPuckToAnchor()
    if not puck or not puckAnchor then return end
    puck:ClearAllPoints()
    puck:SetPoint("TOPLEFT", puckAnchor, "TOPLEFT", 0, 0)
end

local function SavePuckPosition()
    if not puckAnchor then return end
    local db = GetToolboxDB()
    if not db then return end
    db.position = db.position or {}
    if RA.CaptureFrameTopLeft and RA:CaptureFrameTopLeft(puckAnchor, db.position) then
        db.positionAnchorVersion = 3
        puckPositionNormalized = true
    end
end

local function RestorePuckPosition()
    if not puck or not puckAnchor then return end
    local db = GetToolboxDB()
    local pos = db and db.position or nil
    if db and (tonumber(db.positionAnchorVersion) or 0) >= 2 and RA.RestoreFrameTopLeft then
        RA:RestoreFrameTopLeft(puckAnchor, pos, {x = 12, y = -300})
        BindPuckToAnchor()
        db.positionAnchorVersion = 3
        puckPositionNormalized = true
        return
    end

    -- Legacy position: render once using the original anchor semantics, then
    -- capture the visible top-left after the puck is actually shown.
    puck:ClearAllPoints()
    if pos then
        SetPoint(puck, pos.point or "LEFT", UIParent, pos.relativePoint or "LEFT", pos.x or 12, pos.y or 70)
    else
        SetPoint(puck, "LEFT", UIParent, "LEFT", 12, 70)
    end
    puckPositionNormalized = false
end

local function NormalizePuckPositionIfNeeded()
    if puckPositionNormalized or not puck or not puck:IsShown() or not puckAnchor then return end
    if not RA.GetFrameTopLeftInUIParent then return end

    local left, top = RA:GetFrameTopLeftInUIParent(puck)
    local parentHeight = UIParent and UIParent.GetHeight and UIParent:GetHeight() or nil
    if type(left) ~= "number" or type(top) ~= "number" or type(parentHeight) ~= "number" then return end

    puckAnchor:ClearAllPoints()
    puckAnchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left, top - parentHeight)
    BindPuckToAnchor()
    SavePuckPosition()
end

local function StopPuckDrag(savePosition)
    if not puckAnchor then return end
    local state = puckDragState
    puckDragState = nil
    puckAnchor:SetScript("OnUpdate", nil)
    if savePosition and state then SavePuckPosition() end
end

local function StartPuckDrag()
    if not puck or not puckAnchor or InCombatLockdown() or not GetCursorPosition then return end
    NormalizePuckPositionIfNeeded()
    if not puckPositionNormalized then return end

    local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if type(parentScale) ~= "number" or parentScale <= 0 then parentScale = 1 end
    local cursorX, cursorY = GetCursorPosition()
    cursorX, cursorY = cursorX / parentScale, cursorY / parentScale
    local left, top = puckAnchor:GetLeft(), puckAnchor:GetTop()
    local parentHeight = UIParent:GetHeight()
    if type(left) ~= "number" or type(top) ~= "number" or type(parentHeight) ~= "number" then return end

    puckDragState = {
        cursorX = cursorX,
        cursorY = cursorY,
        left = left,
        top = top,
        parentHeight = parentHeight,
        parentScale = parentScale,
    }

    puckAnchor:SetScript("OnUpdate", function(self)
        local state = puckDragState
        if not state then self:SetScript("OnUpdate", nil); return end
        if InCombatLockdown() then StopPuckDrag(true); return end
        local x, y = GetCursorPosition()
        x, y = x / state.parentScale, y / state.parentScale
        local newLeft = state.left + (x - state.cursorX)
        local newTop = state.top + (y - state.cursorY)
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "TOPLEFT", newLeft, newTop - state.parentHeight)
    end)
end

local function MouseOver(frame)
    if not frame or not frame:IsShown() then return false end
    if MouseIsOver then
        local ok, over = pcall(MouseIsOver, frame)
        return ok and over == true
    elseif frame.IsMouseOver then
        local ok, over = pcall(frame.IsMouseOver, frame)
        return ok and over == true
    end
    return false
end

local function AnyToolboxHovered()
    return MouseOver(puck) or MouseOver(missingBadge) or MouseOver(dock) or MouseOver(missingPanel) or MouseOver(sortOptionsPanel)
end

local function CancelClose()
    CancelTimer(closeTimer)
    closeTimer = nil
end

local CloseDock

local function ResolveDockDirection()
    local db = GetToolboxDB()
    local requested = db and db.flyoutDirection or "AUTO"
    if requested ~= "AUTO" then return requested end
    if not puck or not UIParent then return "RIGHT" end

    local cx, cy = puck:GetCenter()
    local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
    if not cx or not cy or not pw or not ph then return "RIGHT" end

    local spaces = {
        RIGHT = pw - cx,
        LEFT = cx,
        UP = ph - cy,
        DOWN = cy,
    }
    local best, bestSpace = "RIGHT", spaces.RIGHT
    for _, dir in ipairs({"LEFT", "DOWN", "UP"}) do
        if spaces[dir] > bestSpace then
            best, bestSpace = dir, spaces[dir]
        end
    end
    return best
end

local function AnchorDock()
    if not puck or not dock then return end
    local direction = ResolveDockDirection()
    dock:ClearAllPoints()
    if direction == "LEFT" then
        SetPoint(dock, "RIGHT", puck, "LEFT", -6, 0)
    elseif direction == "DOWN" then
        SetPoint(dock, "TOP", puck, "BOTTOM", 0, -6)
    elseif direction == "UP" then
        SetPoint(dock, "BOTTOM", puck, "TOP", 0, 6)
    else
        SetPoint(dock, "LEFT", puck, "RIGHT", 6, 0)
    end
    dock.__rcpaDirection = direction
end

local function AnchorFlyouts()
    if not dock then return end
    local direction = dock.__rcpaDirection or ResolveDockDirection()

    local function AnchorPanel(panel, button)
        if not panel or not button then return end
        panel:ClearAllPoints()
        if direction == "LEFT" then
            SetPoint(panel, "TOPRIGHT", button, "TOPLEFT", -8, 0)
        elseif direction == "DOWN" then
            SetPoint(panel, "TOP", dock, "BOTTOM", 0, -8)
        elseif direction == "UP" then
            SetPoint(panel, "BOTTOM", dock, "TOP", 0, 8)
        else
            SetPoint(panel, "TOPLEFT", button, "TOPRIGHT", 8, 0)
        end
    end

    AnchorPanel(missingPanel, missingButton)
    AnchorPanel(sortOptionsPanel, sortButton)
end

local function StopDockMonitor()
    if dockMonitor then dockMonitor:SetScript("OnUpdate", nil) end
    monitorButtonsDown.left = false
    monitorButtonsDown.right = false
    monitorButtonsDown.middle = false
end

local function StartDockMonitor()
    if not dockMonitor or not IsMouseButtonDown then return end
    dockMonitor:SetScript("OnUpdate", function()
        if dockPinned or not dock or not dock:IsShown() then return end
        local left = IsMouseButtonDown("LeftButton") == true
        local right = IsMouseButtonDown("RightButton") == true
        local middle = IsMouseButtonDown("MiddleButton") == true
        local newPress = (left and not monitorButtonsDown.left)
            or (right and not monitorButtonsDown.right)
            or (middle and not monitorButtonsDown.middle)
        monitorButtonsDown.left = left
        monitorButtonsDown.right = right
        monitorButtonsDown.middle = middle
        if newPress and not AnyToolboxHovered() then
            CloseDock()
        end
    end)
end

local function OpenDock()
    CancelClose()
    if not dock or not puck or not puck:IsShown() then return end
    AnchorDock()
    dock:Show()
    AnchorFlyouts()
    StartDockMonitor()
end

CloseDock = function(force)
    if dockPinned and not force then return end
    CancelClose()
    StopDockMonitor()
    if missingPanel then missingPanel:Hide() end
    if sortOptionsPanel then sortOptionsPanel:Hide() end
    if dock then dock:Hide() end
end

local function ScheduleClose()
    if dockPinned then return end
    CancelClose()
    local db = GetToolboxDB()
    closeTimer = C_Timer.NewTimer(db and db.closeDelay or CLOSE_DELAY_DEFAULT, function()
        closeTimer = nil
        if AnyToolboxHovered() then
            ScheduleClose()
        else
            CloseDock()
        end
    end)
end

local function CancelDelayedTooltip(frame)
    if not frame then return end
    if frame.__rcpaTooltipTimer then
        CancelTimer(frame.__rcpaTooltipTimer)
        frame.__rcpaTooltipTimer = nil
    end
    if GameTooltip then GameTooltip:Hide() end
end

local function ScheduleDelayedTooltip(frame, builder)
    if not frame or type(builder) ~= "function" then return end
    CancelDelayedTooltip(frame)
    local db = GetToolboxDB()
    local delay = db and db.tooltipDelay or 0.75
    frame.__rcpaTooltipTimer = C_Timer.NewTimer(delay, function()
        frame.__rcpaTooltipTimer = nil
        if MouseOver(frame) then builder(frame) end
    end)
end

local function HookHover(frame, onEnter)
    if not frame then return end
    frame:HookScript("OnEnter", function(self)
        OpenDock()
        if onEnter then onEnter(self) end
    end)
    frame:HookScript("OnLeave", ScheduleClose)
end

local function GetSpellTexture(spellID)
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, texture = pcall(C_Spell.GetSpellTexture, spellID)
        if ok and texture then return texture end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and info and info.iconID then return info.iconID end
    end
    return 134400
end

local function BuildTrackedClassSet()
    local classes = {}
    if not IsInRaid() then return classes end
    local count = GetNumGroupMembers()
    for raidIndex = 1, count do
        local _, _, subgroup, _, _, classFile, _, online = GetRaidRosterInfo(raidIndex)
        subgroup = tonumber(subgroup)
        if classFile and subgroup and not RA:IsRaidGroupIgnored(subgroup) then
            local isOnline = online
            if isOnline == nil or IsSecret(isOnline) then isOnline = true end
            if isOnline ~= false then classes[classFile] = true end
        end
    end
    return classes
end

local function RefreshMissingData()
    local classes = BuildTrackedClassSet()
    missingData = { buffs = {}, debuffs = {}, total = 0 }
    for _, section in ipairs({"buffs", "debuffs"}) do
        local source = MAJOR_COVERAGE[section]
        for i = 1, #source do
            local item = source[i]
            if not classes[item.class] then
                missingData[section][#missingData[section] + 1] = item
                missingData.total = missingData.total + 1
            end
        end
    end

    if missingButton then
        missingButton.count:SetText(tostring(missingData.total))
        local color = missingData.total == 0 and TC.success or TC.magenta
        missingButton.count:SetTextColor(color[1], color[2], color[3], color[4] or 1)
        missingButton.label:SetText(missingData.total == 0 and "COVERED" or "MISSING")
    end

    if missingBadge then
        local db = GetToolboxDB()
        local show = db and db.showMissing ~= false and missingData.total > 0 and toolboxWasVisible
        missingBadge:SetShown(show and true or false)
        if show then
            missingBadge.label:SetText(tostring(missingData.total))
            local color = missingData.total <= 2 and (TC.orange or TC.warning) or (TC.danger or TC.magenta)
            missingBadge.label:SetTextColor(color[1], color[2], color[3], 1)
            SetSurface(missingBadge, CopyColor(TC.surfaceRaised, 0.995), CopyColor(color, 0.86), "missingBadge")
        end
    end
end

local function GetMissingRow(index)
    local row = missingRows[index]
    if row then return row end
    row = CreateFrame("Frame", nil, missingPanel, "BackdropTemplate")
    SetSize(row, 218, 22)
    ApplySurface(row, CopyColor(TC.input or TC.surface, 0.66), CopyColor(TC.transparent, 0), 6, "missingRow" .. index)

    row.iconFrame = CreateFrame("Frame", nil, row, "BackdropTemplate")
    SetSize(row.iconFrame, 18, 18)
    SetPoint(row.iconFrame, "LEFT", row, "LEFT", 3, 0)
    ApplySurface(row.iconFrame, TC.input, CopyColor(TC.lineStrong, 0.35), 5, "missingIcon" .. index)
    row.icon = row.iconFrame:CreateTexture(nil, "ARTWORK")
    SetPoint(row.icon, "TOPLEFT", row.iconFrame, "TOPLEFT", 1, -1)
    SetPoint(row.icon, "BOTTOMRIGHT", row.iconFrame, "BOTTOMRIGHT", -1, 1)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    CrispTexture(row.icon)
    if Theme and Theme.ApplyIconMask then Theme:ApplyIconMask(row.icon, row.iconFrame) end

    row.text = Font(row, 9.0, TC.textSoft, "BOLD")
    row.text:SetJustifyH("LEFT")
    SetPoint(row.text, "LEFT", row.iconFrame, "RIGHT", 8, 0)
    SetPoint(row.text, "RIGHT", row, "RIGHT", -6, 0)

    missingRows[index] = row
    return row
end

local function LayoutMissingPanel()
    if not missingPanel then return end
    for i = 1, #missingRows do missingRows[i]:Hide() end

    local y = -42
    local rowIndex = 0
    local sectionsShown = 0

    local function AddSection(label, items)
        if #items == 0 then return end
        sectionsShown = sectionsShown + 1
        local header = sectionsShown == 1 and missingPanel.sectionOne or missingPanel.sectionTwo
        header:SetText(label)
        header:Show()
        header:ClearAllPoints()
        SetPoint(header, "TOPLEFT", missingPanel, "TOPLEFT", 16, y)
        y = y - 20

        for i = 1, #items do
            rowIndex = rowIndex + 1
            local row = GetMissingRow(rowIndex)
            row.item = items[i]
            if RA.RegisterSpellIcon then
                RA:RegisterSpellIcon(row.icon, items[i].spellID)
            else
                row.icon:SetTexture(GetSpellTexture(items[i].spellID))
            end
            row.text:SetText(items[i].effect and (items[i].name .. "  |  " .. items[i].effect) or items[i].name)
            row:ClearAllPoints()
            SetPoint(row, "TOPLEFT", missingPanel, "TOPLEFT", 13, y)
            row:Show()
            y = y - 24
        end
        y = y - 3
    end

    missingPanel.sectionOne:Hide()
    missingPanel.sectionTwo:Hide()

    if missingData.total == 0 then
        missingPanel.empty:SetText("ALL MAJOR RAID BUFFS / DEBUFFS COVERED")
        missingPanel.empty:SetTextColor(TC.success[1], TC.success[2], TC.success[3], 1)
        missingPanel.empty:Show()
        SetHeight(missingPanel, 82)
    else
        missingPanel.empty:Hide()
        AddSection("BUFFS", missingData.buffs)
        AddSection("DEBUFFS", missingData.debuffs)
        SetHeight(missingPanel, math.max(96, -y + 12))
    end
end

local function OpenMissingPanel()
    local db = GetToolboxDB()
    if not db or db.showMissing == false then return end
    RefreshMissingData()
    LayoutMissingPanel()
    OpenDock()
    AnchorFlyouts()
    if sortOptionsPanel then sortOptionsPanel:Hide() end
    missingPanel:Show()
end

local function GetFreshSpecID(fullName, unit, guid, role)
    local rosterInfo = RA.Roster and RA.Roster[fullName]
    local report = RA.Reports and RA.Reports[fullName]
    if report and report.verified and report.guid == guid then
        local fresh = true
        if rosterInfo and RA.IsReportFresh then
            fresh = RA:IsReportFresh(report, rosterInfo)
        elseif report.role and role and report.role ~= role then
            fresh = false
        end
        if fresh and type(report.specID) == "number" then return report.specID end
    end

    if UnitIsUnit and UnitIsUnit(unit, "player") and C_SpecializationInfo then
        local specIndex = C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecialization()
        if specIndex and C_SpecializationInfo.GetSpecializationInfo then
            local specID = C_SpecializationInfo.GetSpecializationInfo(specIndex)
            if type(specID) == "number" and not IsSecret(specID) then return specID end
        end
    end
    return nil
end

local function ResolveKind(member)
    local specID = GetFreshSpecID(member.name, member.unit, member.guid, member.role)
    if specID and SPEC_KIND[specID] then return SPEC_KIND[specID], specID end
    if member.role == "TANK" then return "TANK", specID end
    if member.role == "HEALER" then return "HEALER", specID end
    if member.role == "DAMAGER" then return DAMAGE_CLASS_FALLBACK[member.class], specID end
    return nil, specID
end

local function BuildRaidSnapshot()
    if not IsInRaid() then return nil, "not in a raid" end
    local members, byName, groupSizes = {}, {}, {}
    for group = 1, 8 do groupSizes[group] = 0 end

    local count = GetNumGroupMembers()
    for raidIndex = 1, count do
        local unit = "raid" .. raidIndex
        local rosterName, _, subgroup, _, _, classFile = GetRaidRosterInfo(raidIndex)
        subgroup = tonumber(subgroup)
        if rosterName and subgroup and subgroup >= 1 and subgroup <= 8 then
            groupSizes[subgroup] = groupSizes[subgroup] + 1
            local fullName = RA:GetFullUnitName(unit) or rosterName
            local role = UnitGroupRolesAssigned(unit)
            if role ~= nil and IsSecret(role) then role = nil end
            local member = {
                unit = unit,
                raidIndex = raidIndex,
                name = fullName,
                shortName = RA:GetShortName(fullName),
                guid = UnitGUID(unit),
                group = subgroup,
                class = classFile,
                role = role,
                ignored = RA:IsRaidGroupIgnored(subgroup),
            }
            member.kind, member.specID = ResolveKind(member)
            members[#members + 1] = member
            byName[fullName] = member
        end
    end
    return { members = members, byName = byName, groupSizes = groupSizes }
end

local function BuildOrderedEligible(snapshot)
    local eligible, unknown = {}, {}
    for i = 1, #snapshot.members do
        local member = snapshot.members[i]
        if not member.ignored then
            if not member.kind or not ROLE_PRIORITY[member.kind] then
                unknown[#unknown + 1] = member
            else
                eligible[#eligible + 1] = member
            end
        end
    end
    if #unknown > 0 then return nil, unknown end

    table.sort(eligible, function(a, b)
        local pa, pb = ROLE_PRIORITY[a.kind] or 99, ROLE_PRIORITY[b.kind] or 99
        if pa ~= pb then return pa < pb end
        if a.group ~= b.group then return a.group < b.group end
        return a.raidIndex < b.raidIndex
    end)
    return eligible
end

local function GetTargetGroups(playerCount, requireEven)
    local groupsNeeded = math.max(1, math.ceil(playerCount / 5))
    if requireEven and groupsNeeded % 2 == 1 then groupsNeeded = groupsNeeded + 1 end
    local targetGroups = {}
    for group = 1, 8 do
        if not RA:IsRaidGroupIgnored(group) then
            targetGroups[#targetGroups + 1] = group
            if #targetGroups >= groupsNeeded then break end
        end
    end
    if #targetGroups < groupsNeeded then return nil end
    return targetGroups
end

-- Split planning uses a strict priority ladder:
--   1) role balance (Tank / Melee / Ranged / Healer)
--   2) class balance (spread class utility / raid buffs when possible)
--   3) specialization balance
--   4) preserve the current side / minimize movement
--
-- Role balance is a hard constraint: no class/spec improvement is allowed to
-- make a role split worse. Class/spec balancing only swaps players inside the
-- same role bucket after the role quotas have been chosen.
local SPLIT_ROLE_KEYS = { "TANK", "MELEE", "RANGED", "HEALER" }

local function JoinGroups(groups, firstIndex, lastIndex)
    local parts = {}
    firstIndex = firstIndex or 1
    lastIndex = lastIndex or #groups
    for i = firstIndex, lastIndex do parts[#parts + 1] = "G" .. tostring(groups[i]) end
    return table.concat(parts, "+")
end

local function BuildSplitGroupSides(mode, targetGroups)
    local sideGroups = { A = {}, B = {} }
    local groupSide = {}

    if mode == "SPLIT_ODD_EVEN" then
        for index = 1, #targetGroups do
            local side = (index % 2 == 1) and "A" or "B"
            local group = targetGroups[index]
            sideGroups[side][#sideGroups[side] + 1] = group
            groupSide[group] = side
        end
    else
        local half = math.floor(#targetGroups / 2)
        for index = 1, #targetGroups do
            local side = index <= half and "A" or "B"
            local group = targetGroups[index]
            sideGroups[side][#sideGroups[side] + 1] = group
            groupSide[group] = side
        end
    end

    local labels = {
        A = JoinGroups(sideGroups.A),
        B = JoinGroups(sideGroups.B),
    }
    return sideGroups, groupSide, labels
end

local function BuildRoleQuotaPatterns(eligible)
    local roleCounts = {}
    for i = 1, #SPLIT_ROLE_KEYS do roleCounts[SPLIT_ROLE_KEYS[i]] = 0 end
    for i = 1, #eligible do
        local kind = eligible[i].kind
        roleCounts[kind] = (roleCounts[kind] or 0) + 1
    end

    local oddRoles = {}
    local baseA = {}
    for i = 1, #SPLIT_ROLE_KEYS do
        local kind = SPLIT_ROLE_KEYS[i]
        local count = roleCounts[kind] or 0
        baseA[kind] = math.floor(count / 2)
        if count % 2 == 1 then oddRoles[#oddRoles + 1] = kind end
    end

    local patterns = {}
    local combinations = 2 ^ #oddRoles
    for mask = 0, combinations - 1 do
        local quotaA = {}
        local totalA = 0
        for i = 1, #SPLIT_ROLE_KEYS do
            local kind = SPLIT_ROLE_KEYS[i]
            quotaA[kind] = baseA[kind] or 0
        end
        for i = 1, #oddRoles do
            local divisor = 2 ^ (i - 1)
            if math.floor(mask / divisor) % 2 == 1 then
                local kind = oddRoles[i]
                quotaA[kind] = quotaA[kind] + 1
            end
        end
        for i = 1, #SPLIT_ROLE_KEYS do
            totalA = totalA + (quotaA[SPLIT_ROLE_KEYS[i]] or 0)
        end
        local totalB = #eligible - totalA
        if math.abs(totalA - totalB) <= 1 then
            patterns[#patterns + 1] = quotaA
        end
    end

    -- This should never be needed, but keep a deterministic fallback if a
    -- future role bucket is added incorrectly.
    if #patterns == 0 then patterns[1] = baseA end
    return patterns, roleCounts
end

local function CountIncrement(container, key, side)
    if key == nil then return end
    local entry = container[key]
    if not entry then
        entry = { A = 0, B = 0 }
        container[key] = entry
    end
    entry[side] = (entry[side] or 0) + 1
end

local function BuildGreedySplitAssignment(eligible, roleCounts, quotaA, groupSide, variant)
    local classTotals, specTotals = {}, {}
    for i = 1, #eligible do
        local member = eligible[i]
        local classKey = member.class or ("UNKNOWN:" .. tostring(member.name))
        classTotals[classKey] = (classTotals[classKey] or 0) + 1
        if member.specID then specTotals[member.specID] = (specTotals[member.specID] or 0) + 1 end
    end

    local order = {}
    for i = 1, #eligible do order[i] = { member = eligible[i], index = i } end
    table.sort(order, function(a, b)
        local ma, mb = a.member, b.member
        local ca = classTotals[ma.class or ("UNKNOWN:" .. tostring(ma.name))] or 1
        local cb = classTotals[mb.class or ("UNKNOWN:" .. tostring(mb.name))] or 1
        if ca ~= cb then return ca > cb end

        local classA, classB = tostring(ma.class or ""), tostring(mb.class or "")
        if classA ~= classB then
            if variant == 2 or variant == 4 then return classA > classB end
            return classA < classB
        end

        local sa = ma.specID and (specTotals[ma.specID] or 1) or 0
        local sb = mb.specID and (specTotals[mb.specID] or 1) or 0
        if sa ~= sb then return sa > sb end
        if ma.specID ~= mb.specID then return (ma.specID or 0) < (mb.specID or 0) end

        local pa, pb = ROLE_PRIORITY[ma.kind] or 99, ROLE_PRIORITY[mb.kind] or 99
        if pa ~= pb then return pa < pb end
        if variant == 3 or variant == 4 then return a.index > b.index end
        return a.index < b.index
    end)

    local assignment = {}
    local placedA, placedB = {}, {}
    local classPlaced, specPlaced = {}, {}
    for i = 1, #SPLIT_ROLE_KEYS do
        placedA[SPLIT_ROLE_KEYS[i]] = 0
        placedB[SPLIT_ROLE_KEYS[i]] = 0
    end

    local function SidePlacementCost(member, side)
        local classKey = member.class or ("UNKNOWN:" .. tostring(member.name))
        local classEntry = classPlaced[classKey] or { A = 0, B = 0 }
        local classA = classEntry.A + (side == "A" and 1 or 0)
        local classB = classEntry.B + (side == "B" and 1 or 0)
        local classPenalty = math.abs(classA - classB)

        local specPenalty = 0
        if member.specID then
            local specEntry = specPlaced[member.specID] or { A = 0, B = 0 }
            local specA = specEntry.A + (side == "A" and 1 or 0)
            local specB = specEntry.B + (side == "B" and 1 or 0)
            specPenalty = math.abs(specA - specB)
        end

        local oldSide = groupSide[member.group]
        local movementPenalty = oldSide and oldSide ~= side and 1 or 0
        return classPenalty, specPenalty, movementPenalty
    end

    local function BetterPlacement(aClass, aSpec, aMove, bClass, bSpec, bMove, preferA)
        if aClass ~= bClass then return aClass < bClass end
        if aSpec ~= bSpec then return aSpec < bSpec end
        if aMove ~= bMove then return aMove < bMove end
        return preferA
    end

    for i = 1, #order do
        local member = order[i].member
        local kind = member.kind
        local targetA = quotaA[kind] or 0
        local targetB = (roleCounts[kind] or 0) - targetA
        local allowA = (placedA[kind] or 0) < targetA
        local allowB = (placedB[kind] or 0) < targetB
        local side

        if allowA and not allowB then
            side = "A"
        elseif allowB and not allowA then
            side = "B"
        elseif allowA and allowB then
            local aClass, aSpec, aMove = SidePlacementCost(member, "A")
            local bClass, bSpec, bMove = SidePlacementCost(member, "B")
            local preferA = (variant % 2 == 1)
            if BetterPlacement(aClass, aSpec, aMove, bClass, bSpec, bMove, preferA) then
                side = "A"
            else
                side = "B"
            end
        else
            return nil
        end

        assignment[member.name] = side
        if side == "A" then
            placedA[kind] = (placedA[kind] or 0) + 1
        else
            placedB[kind] = (placedB[kind] or 0) + 1
        end
        CountIncrement(classPlaced, member.class or ("UNKNOWN:" .. tostring(member.name)), side)
        if member.specID then CountIncrement(specPlaced, member.specID, side) end
    end

    return assignment
end

local function ComputeSplitScore(eligible, assignment, groupSide)
    local classCounts, specCounts = {}, {}
    local movementPenalty = 0

    for i = 1, #eligible do
        local member = eligible[i]
        local side = assignment[member.name]
        local classKey = member.class or ("UNKNOWN:" .. tostring(member.name))
        CountIncrement(classCounts, classKey, side)
        if member.specID then CountIncrement(specCounts, member.specID, side) end
        local oldSide = groupSide[member.group]
        if oldSide and oldSide ~= side then movementPenalty = movementPenalty + 1 end
    end

    local classPenalty = 0
    for _, counts in pairs(classCounts) do
        classPenalty = classPenalty + math.abs((counts.A or 0) - (counts.B or 0))
    end

    local specPenalty = 0
    for _, counts in pairs(specCounts) do
        specPenalty = specPenalty + math.abs((counts.A or 0) - (counts.B or 0))
    end

    return classPenalty, specPenalty, movementPenalty
end

local function IsSplitScoreBetter(aClass, aSpec, aMove, bClass, bSpec, bMove)
    if bClass == nil then return true end
    if aClass ~= bClass then return aClass < bClass end
    if aSpec ~= bSpec then return aSpec < bSpec end
    return aMove < bMove
end

local function OptimizeSplitAssignment(eligible, assignment, groupSide)
    if not assignment then return nil end
    local bestClass, bestSpec, bestMove = ComputeSplitScore(eligible, assignment, groupSide)
    local improved = true
    local passes = 0

    while improved and passes < 32 do
        improved = false
        passes = passes + 1

        -- First try the cheapest improvement: one A/B swap inside the same
        -- role bucket. That preserves the role split exactly.
        for i = 1, #eligible - 1 do
            local first = eligible[i]
            for j = i + 1, #eligible do
                local second = eligible[j]
                if first.kind == second.kind and assignment[first.name] ~= assignment[second.name] then
                    assignment[first.name], assignment[second.name] = assignment[second.name], assignment[first.name]
                    local classScore, specScore, moveScore = ComputeSplitScore(eligible, assignment, groupSide)
                    if IsSplitScoreBetter(classScore, specScore, moveScore, bestClass, bestSpec, bestMove) then
                        bestClass, bestSpec, bestMove = classScore, specScore, moveScore
                        improved = true
                        break
                    end
                    assignment[first.name], assignment[second.name] = assignment[second.name], assignment[first.name]
                end
            end
            if improved then break end
        end

        -- Some class improvements require two coordinated role-preserving
        -- swaps (for example, separating a class duplicated across Tank and
        -- Healer without disturbing either role count). If a single swap is a
        -- local minimum, test deterministic two-swap combinations before
        -- accepting the result.
        if not improved then
            local swapPairs = {}
            for i = 1, #eligible - 1 do
                local first = eligible[i]
                for j = i + 1, #eligible do
                    local second = eligible[j]
                    if first.kind == second.kind and assignment[first.name] ~= assignment[second.name] then
                        swapPairs[#swapPairs + 1] = { i, j }
                    end
                end
            end

            for firstPairIndex = 1, #swapPairs - 1 do
                local pairOne = swapPairs[firstPairIndex]
                local a, b = pairOne[1], pairOne[2]
                for secondPairIndex = firstPairIndex + 1, #swapPairs do
                    local pairTwo = swapPairs[secondPairIndex]
                    local c, d = pairTwo[1], pairTwo[2]
                    if a ~= c and a ~= d and b ~= c and b ~= d then
                        local firstA, firstB = eligible[a], eligible[b]
                        local secondA, secondB = eligible[c], eligible[d]
                        assignment[firstA.name], assignment[firstB.name] = assignment[firstB.name], assignment[firstA.name]
                        assignment[secondA.name], assignment[secondB.name] = assignment[secondB.name], assignment[secondA.name]

                        local classScore, specScore, moveScore = ComputeSplitScore(eligible, assignment, groupSide)
                        if IsSplitScoreBetter(classScore, specScore, moveScore, bestClass, bestSpec, bestMove) then
                            bestClass, bestSpec, bestMove = classScore, specScore, moveScore
                            improved = true
                            break
                        end

                        assignment[secondA.name], assignment[secondB.name] = assignment[secondB.name], assignment[secondA.name]
                        assignment[firstA.name], assignment[firstB.name] = assignment[firstB.name], assignment[firstA.name]
                    end
                end
                if improved then break end
            end
        end
    end

    return assignment, bestClass, bestSpec, bestMove
end

local function BuildSmartSplitAssignment(eligible, mode, targetGroups)
    local sideGroups, groupSide, sideLabels = BuildSplitGroupSides(mode, targetGroups)
    local quotaPatterns, roleCounts = BuildRoleQuotaPatterns(eligible)
    local bestAssignment
    local bestClass, bestSpec, bestMove

    for patternIndex = 1, #quotaPatterns do
        local quotaA = quotaPatterns[patternIndex]
        for variant = 1, 4 do
            local assignment = BuildGreedySplitAssignment(eligible, roleCounts, quotaA, groupSide, variant)
            if assignment then
                local classScore, specScore, moveScore
                assignment, classScore, specScore, moveScore = OptimizeSplitAssignment(eligible, assignment, groupSide)
                if IsSplitScoreBetter(classScore, specScore, moveScore, bestClass, bestSpec, bestMove) then
                    bestAssignment = assignment
                    bestClass, bestSpec, bestMove = classScore, specScore, moveScore
                end
            end
        end
    end

    return bestAssignment, sideGroups, groupSide, sideLabels, bestClass, bestSpec, bestMove
end

local function BuildDesiredGroupsFromSides(eligible, assignment, sideGroups, groupSide)
    local desired, used = {}, {}
    for _, side in ipairs({ "A", "B" }) do
        for i = 1, #sideGroups[side] do used[sideGroups[side][i]] = 0 end
    end

    -- First preserve every exact subgroup that is already on the player's
    -- assigned side. This is the strongest possible movement minimization once
    -- role/class/spec side balance has been decided.
    for i = 1, #eligible do
        local member = eligible[i]
        local side = assignment[member.name]
        if groupSide[member.group] == side and (used[member.group] or 0) < 5 then
            desired[member.name] = member.group
            used[member.group] = (used[member.group] or 0) + 1
        end
    end

    local function NextOpenGroup(side)
        local groups = sideGroups[side]
        for i = 1, #groups do
            local group = groups[i]
            if (used[group] or 0) < 5 then return group end
        end
        return nil
    end

    for i = 1, #eligible do
        local member = eligible[i]
        if not desired[member.name] then
            local side = assignment[member.name]
            local group = NextOpenGroup(side)
            if not group then return nil end
            desired[member.name] = group
            used[group] = (used[group] or 0) + 1
        end
    end
    return desired
end

local function BuildSortPlan(mode)
    RA:RefreshRoster()
    local snapshot, err = BuildRaidSnapshot()
    if not snapshot then return nil, err end

    local eligible, unknown = BuildOrderedEligible(snapshot)
    if not eligible then return nil, "unknown roles", unknown end

    local isSplit = mode == "SPLIT_ODD_EVEN" or mode == "SPLIT_ADJACENT"
    local targetGroups = GetTargetGroups(#eligible, isSplit)
    if not targetGroups then return nil, "not enough active groups" end
    if isSplit and #targetGroups < 2 then return nil, "not enough split groups" end

    local desired, names, orderedNames = {}, {}, {}
    local wrong = 0
    local modeLabel = "TANK > MELEE > RANGED > HEALERS"
    local initialSideByName, assignedSideByName, sideLabels

    if not isSplit then
        for index = 1, #eligible do
            local member = eligible[index]
            local targetGroup = targetGroups[math.floor((index - 1) / 5) + 1]
            if not targetGroup then return nil, "split layout overflow" end
            desired[member.name] = targetGroup
            names[member.name] = true
            orderedNames[#orderedNames + 1] = member.name
            if member.group ~= targetGroup then wrong = wrong + 1 end
        end
    else
        local assignment, sideGroups, groupSide, labels, classScore, specScore, moveScore = BuildSmartSplitAssignment(eligible, mode, targetGroups)
        if not assignment then return nil, "could not build balanced split" end
        desired = BuildDesiredGroupsFromSides(eligible, assignment, sideGroups, groupSide)
        if not desired then return nil, "split layout overflow" end

        initialSideByName, assignedSideByName, sideLabels = {}, {}, labels
        for index = 1, #eligible do
            local member = eligible[index]
            names[member.name] = true
            orderedNames[#orderedNames + 1] = member.name
            assignedSideByName[member.name] = assignment[member.name]
            initialSideByName[member.name] = groupSide[member.group]
            if member.group ~= desired[member.name] then wrong = wrong + 1 end
        end

        if mode == "SPLIT_ODD_EVEN" then
            modeLabel = "ODD / EVEN GROUPS"
        else
            modeLabel = tostring(labels.A) .. " / " .. tostring(labels.B)
        end
        RA:Debug(string.format("Smart split score: class=%d spec=%d sideMoves=%d", classScore or 0, specScore or 0, moveScore or 0))
    end

    return {
        mode = mode,
        modeLabel = modeLabel,
        desiredGroupByName = desired,
        eligibleNames = names,
        orderedNames = orderedNames,
        eligibleCount = #eligible,
        initialWrong = wrong,
        targetGroups = targetGroups,
        initialSideByName = initialSideByName,
        assignedSideByName = assignedSideByName,
        sideLabels = sideLabels,
    }
end

local function SetActionButtonState(button, text, state)
    if not button then return end
    button.__state = state or "DEFAULT"
    if button == sortButton then
        button.label:SetText(text or "SORT")
    elseif button == splitButton then
        if text then
            button.left:SetText(text)
            button.right:SetText("")
        else
            button.left:SetText("ODD")
            button.right:SetText("EVEN")
        end
    elseif button.label then
        button.label:SetText(text or button.__defaultLabel or "ACTION")
    end

    local background, border = TC.surfaceRaised, CopyColor(TC.lineStrong, 0.55)
    if state == "WORKING" then
        background, border = TC.activeDark, CopyColor(TC.magenta, 0.68)
    elseif state == "SUCCESS" then
        background, border = CopyColor(TC.success, 0.14), CopyColor(TC.success, 0.72)
    elseif state == "WARNING" then
        background, border = CopyColor(TC.warning, 0.13), CopyColor(TC.warning, 0.72)
    elseif state == "LOCKED" then
        background, border = CopyColor(TC.surfaceRaised, 0.56), CopyColor(TC.lineStrong, 0.24)
    end
    SetSurface(button, background, border, button.__surfaceKey)
    if button.SetAlpha then button:SetAlpha(state == "LOCKED" and 0.42 or 1.0) end
end

local function ResetActionButtonSoon(button, delay)
    CancelTimer(statusResetTimer)
    statusResetTimer = C_Timer.NewTimer(delay or 3.0, function()
        statusResetTimer = nil
        local locked = (button == sortButton or button == splitButton) and (InCombatLockdown() or not IsLeaderOrAssistant())
        SetActionButtonState(button, nil, locked and "LOCKED" or "DEFAULT")
    end)
end

local function ClearSortTimer()
    CancelTimer(sortTimer)
    sortTimer = nil
end

local function QueueSplitSideChangeWhispers()
    if sortState.mode ~= "SPLIT_ODD_EVEN" and sortState.mode ~= "SPLIT_ADJACENT" then return end
    local oldSides = sortState.initialSideByName or {}
    local newSides = sortState.assignedSideByName or {}
    local labels = sortState.sideLabels or { A = "SIDE A", B = "SIDE B" }
    local playerName = RA:GetFullUnitName("player")
    local queued = {}
    local selfMessage

    for i = 1, #sortState.orderedNames do
        local name = sortState.orderedNames[i]
        local oldSide, newSide = oldSides[name], newSides[name]
        if oldSide and newSide and oldSide ~= newSide then
            local message = string.format(
                "RCP Arsenal: Your split side changed: %s -> %s.",
                tostring(labels[oldSide] or oldSide),
                tostring(labels[newSide] or newSide)
            )
            if playerName and name == playerName then
                selfMessage = message
            else
                queued[#queued + 1] = { target = name, message = message }
            end
        end
    end

    if selfMessage then RA:Print(selfMessage:gsub("^RCP Arsenal:%s*", "")) end
    if #queued == 0 then return end

    -- Stagger the whispers slightly so a large reshuffle does not dump every
    -- message into chat on one frame. These fire only after the full split has
    -- been confirmed complete.
    local function MakeSendWhisper(target, message)
        return function()
            if SendChatMessage then
                pcall(SendChatMessage, message, "WHISPER", nil, target)
            end
        end
    end
    for i = 1, #queued do
        local item = queued[i]
        local sendOne = MakeSendWhisper(item.target, item.message)
        if C_Timer and C_Timer.After then
            C_Timer.After((i - 1) * 0.20, sendOne)
        else
            sendOne()
        end
    end
    RA:Print(string.format("Split complete: notifying %d player%s whose side changed.", #queued, #queued == 1 and "" or "s"))
end

local function StopSort(message, state)
    local source = sortState.sourceButton
    local modeLabel = sortState.modeLabel
    ClearSortTimer()
    sortState.active = false
    sortState.mode = nil
    sortState.modeLabel = nil
    sortState.sourceButton = nil
    sortState.desiredGroupByName = {}
    sortState.eligibleNames = {}
    sortState.orderedNames = {}
    sortState.eligibleCount = 0
    sortState.initialWrong = 0
    sortState.steps = 0
    sortState.expectedName = nil
    sortState.expectedGroup = nil
    sortState.initialSideByName = {}
    sortState.assignedSideByName = {}
    sortState.sideLabels = nil

    if message then RA:Print(message) end
    if source then
        local text = state == "SUCCESS" and "DONE" or "STOPPED"
        SetActionButtonState(source, text, state or "WARNING")
        ResetActionButtonSoon(source, state == "SUCCESS" and 2.5 or 3.5)
    end
    if state == "SUCCESS" and modeLabel then
        RA:Debug("Completed " .. modeLabel)
        if modeLabel == "UNDO LAST RAID SORT" then lastLayoutSnapshot = nil end
    end
    if sortOptionsPanel and sortOptionsPanel.undo then
        sortOptionsPanel.undo:SetShown(lastLayoutSnapshot ~= nil and not sortState.active)
    end
end

local function SnapshotMatchesPlan(snapshot)
    local seen = 0
    for name in pairs(sortState.eligibleNames) do
        if not snapshot.byName[name] then return false end
        seen = seen + 1
    end
    local currentEligible = 0
    for i = 1, #snapshot.members do
        if not snapshot.members[i].ignored then currentEligible = currentEligible + 1 end
    end
    return seen == sortState.eligibleCount and currentEligible == sortState.eligibleCount
end

local ProcessSortStep

local function ScheduleSortTimeout()
    ClearSortTimer()
    sortTimer = C_Timer.NewTimer(MOVE_TIMEOUT, function()
        sortTimer = nil
        if sortState.active then ProcessSortStep("timeout") end
    end)
end

local function FindWrongMember(snapshot)
    for i = 1, #sortState.orderedNames do
        local name = sortState.orderedNames[i]
        local targetGroup = sortState.desiredGroupByName[name]
        local member = snapshot.byName[name]
        if member and member.group ~= targetGroup then return member, targetGroup end
    end
end

local function FindSwapPartner(snapshot, mover, targetGroup)
    local fallback
    for i = 1, #snapshot.members do
        local candidate = snapshot.members[i]
        if candidate.group == targetGroup and sortState.eligibleNames[candidate.name] then
            local desired = sortState.desiredGroupByName[candidate.name]
            if desired and desired ~= candidate.group then
                if desired == mover.group then return candidate end
                fallback = fallback or candidate
            end
        end
    end
    return fallback
end

ProcessSortStep = function()
    if not sortState.active then return end
    if InCombatLockdown() then StopSort("Raid sorting stopped: combat started.", "WARNING"); return end
    if not IsLeaderOrAssistant() then StopSort("Raid sorting stopped: raid lead or assist required.", "WARNING"); return end
    if sortState.steps >= MAX_SORT_STEPS then StopSort("Raid sorting timed out.", "WARNING"); return end

    local snapshot = BuildRaidSnapshot()
    if not snapshot or not SnapshotMatchesPlan(snapshot) then
        StopSort("Raid roster changed during sorting. Try again.", "WARNING")
        return
    end

    local mover, targetGroup = FindWrongMember(snapshot)
    if not mover then
        QueueSplitSideChangeWhispers()
        StopSort("Raid sorted: " .. tostring(sortState.modeLabel or "complete") .. ".", "SUCCESS")
        return
    end

    sortState.steps = sortState.steps + 1
    sortState.expectedName = mover.name
    sortState.expectedGroup = targetGroup
    SetActionButtonState(sortState.sourceButton, "WORKING", "WORKING")

    if (snapshot.groupSizes[targetGroup] or 0) < 5 then
        local ok = SetRaidSubgroup and pcall(SetRaidSubgroup, mover.raidIndex, targetGroup)
        if not ok then StopSort("Raid group move was blocked.", "WARNING"); return end
        ScheduleSortTimeout()
        return
    end

    local partner = FindSwapPartner(snapshot, mover, targetGroup)
    if partner then
        local ok = SwapRaidSubgroup and pcall(SwapRaidSubgroup, mover.raidIndex, partner.raidIndex)
        if not ok then StopSort("Raid group swap was blocked.", "WARNING"); return end
        ScheduleSortTimeout()
        return
    end

    StopSort("Could not free raid group " .. tostring(targetGroup) .. ".", "WARNING")
end

local StartSortFromPlan

local function CaptureUndoSnapshot()
    local snapshot = BuildRaidSnapshot()
    if not snapshot then return nil end
    local desired, eligibleNames, orderedNames = {}, {}, {}
    local count = 0
    for i = 1, #snapshot.members do
        local member = snapshot.members[i]
        if not member.ignored then
            desired[member.name] = member.group
            eligibleNames[member.name] = true
            orderedNames[#orderedNames + 1] = member.name
            count = count + 1
        end
    end
    return {
        desiredGroupByName = desired,
        eligibleNames = eligibleNames,
        orderedNames = orderedNames,
        eligibleCount = count,
    }
end

local function BuildUndoPlan()
    if not lastLayoutSnapshot then return nil, "nothing to undo" end
    local snapshot = BuildRaidSnapshot()
    if not snapshot then return nil, "no raid" end
    local wrong = 0
    for name, targetGroup in pairs(lastLayoutSnapshot.desiredGroupByName) do
        local member = snapshot.byName[name]
        if not member or member.ignored then return nil, "raid roster changed" end
        if member.group ~= targetGroup then wrong = wrong + 1 end
    end
    return {
        mode = "UNDO",
        modeLabel = "UNDO LAST RAID SORT",
        desiredGroupByName = lastLayoutSnapshot.desiredGroupByName,
        eligibleNames = lastLayoutSnapshot.eligibleNames,
        orderedNames = lastLayoutSnapshot.orderedNames,
        eligibleCount = lastLayoutSnapshot.eligibleCount,
        initialWrong = wrong,
        isUndo = true,
    }
end

local function StartUndoLastSort(sourceButton)
    if sortState.active then
        SetActionButtonState(sourceButton, "BUSY", "WARNING")
        ResetActionButtonSoon(sourceButton, 2.0)
        return
    end
    if InCombatLockdown() or not IsInRaid() or not IsLeaderOrAssistant() then
        SetActionButtonState(sourceButton, InCombatLockdown() and "COMBAT" or "NO ACCESS", "WARNING")
        ResetActionButtonSoon(sourceButton, 2.5)
        return
    end
    local plan, err = BuildUndoPlan()
    if not plan then
        SetActionButtonState(sourceButton, "NO UNDO", "WARNING")
        ResetActionButtonSoon(sourceButton, 2.5)
        if err then RA:Print("Undo unavailable: " .. tostring(err) .. ".") end
        return
    end
    StartSortFromPlan(plan, sourceButton)
end

StartSortFromPlan = function(plan, sourceButton)
    pendingMode, pendingSourceButton, pendingUnknownCount = nil, nil, 0
    if plan.initialWrong == 0 then
        SetActionButtonState(sourceButton, "DONE", "SUCCESS")
        ResetActionButtonSoon(sourceButton, 2.5)
        RA:Print("Raid is already arranged: " .. plan.modeLabel .. ".")
        if plan.isUndo then lastLayoutSnapshot = nil end
        return
    end
    if not plan.isUndo then
        lastLayoutSnapshot = CaptureUndoSnapshot()
    end

    sortState.active = true
    sortState.mode = plan.mode
    sortState.modeLabel = plan.modeLabel
    sortState.sourceButton = sourceButton
    sortState.desiredGroupByName = plan.desiredGroupByName
    sortState.eligibleNames = plan.eligibleNames
    sortState.orderedNames = plan.orderedNames
    sortState.eligibleCount = plan.eligibleCount
    sortState.initialWrong = plan.initialWrong
    sortState.steps = 0
    sortState.expectedName = nil
    sortState.expectedGroup = nil
    sortState.initialSideByName = plan.initialSideByName or {}
    sortState.assignedSideByName = plan.assignedSideByName or {}
    sortState.sideLabels = plan.sideLabels

    SetActionButtonState(sourceButton, "WORKING", "WORKING")
    ProcessSortStep("start")
end

local function TryStartMode(mode, allowScan, sourceButton)
    OpenDock()
    if sortState.active then
        SetActionButtonState(sourceButton, "BUSY", "WARNING")
        ResetActionButtonSoon(sourceButton, 2.0)
        return
    end
    if InCombatLockdown() then
        SetActionButtonState(sourceButton, "COMBAT", "WARNING")
        ResetActionButtonSoon(sourceButton, 2.5)
        return
    end
    if not IsInRaid() then
        SetActionButtonState(sourceButton, "NO RAID", "WARNING")
        ResetActionButtonSoon(sourceButton, 2.5)
        return
    end
    if not IsLeaderOrAssistant() then
        SetActionButtonState(sourceButton, "NO ACCESS", "WARNING")
        PrintLeadAccessRequired("Raid layout")
        ResetActionButtonSoon(sourceButton, 2.5)
        return
    end

    local plan, err, unknown = BuildSortPlan(mode)
    if plan then StartSortFromPlan(plan, sourceButton); return end

    if err == "unknown roles" and unknown and #unknown > 0 then
        pendingMode = mode
        pendingSourceButton = sourceButton
        pendingUnknownCount = #unknown
        if allowScan and RA.RequestInspectionScan then
            SetActionButtonState(sourceButton, "SCANNING", "WORKING")
            RA:RequestInspectionScan("raid leader layout", false)
        else
            SetActionButtonState(sourceButton, "NEED SPEC", "WARNING")
            ResetActionButtonSoon(sourceButton, 3.5)
        end
        return
    end

    SetActionButtonState(sourceButton, "UNAVAILABLE", "WARNING")
    ResetActionButtonSoon(sourceButton, 3.5)
    RA:Print("Raid layout unavailable: " .. tostring(err or "unknown error") .. ".")
end

local function ToggleSortOptions()
    OpenDock()
    if missingPanel then missingPanel:Hide() end
    AnchorFlyouts()
    sortOptionsPanel:SetShown(not sortOptionsPanel:IsShown())
end

local function RefreshSortOptions()
    if not sortOptionsPanel then return end
    local groups = {}
    for group = 1, 8 do if not RA:IsRaidGroupIgnored(group) then groups[#groups + 1] = tostring(group) end end
    sortOptionsPanel.groups:SetText("TRACKED GROUPS: " .. table.concat(groups, ", "))
    sortOptionsPanel.cancel:SetShown(sortState.active)
    if sortOptionsPanel.undo then
        sortOptionsPanel.undo:SetShown(lastLayoutSnapshot ~= nil and not sortState.active)
    end
end

local function RefreshAccessAppearance()
    if not sortButton or not splitButton then return end
    local locked = InCombatLockdown() or not IsLeaderOrAssistant()

    if sortState.active then
        SetActionButtonState(sortButton, nil, "WORKING")
    else
        SetActionButtonState(sortButton, nil, locked and "LOCKED" or "DEFAULT")
    end
    SetActionButtonState(splitButton, nil, locked and "LOCKED" or "DEFAULT")

    if not IsLeaderOrAssistant() and sortOptionsPanel then
        sortOptionsPanel:Hide()
    end
end

local function RefreshDockGeometry()
    if not dock or not missingButton then return end
    local db = GetToolboxDB()
    local showMissing = not db or db.showMissing ~= false

    if puck and db then
        local size = db.puckSize or PUCK_SIZE
        SetSize(puck, size, size)
        if puck.logo then
            local inset = math.max(3, math.floor(size * 0.15 + 0.5))
            puck.logo:ClearAllPoints()
            SetPoint(puck.logo, "TOPLEFT", puck, "TOPLEFT", inset, -inset)
            SetPoint(puck.logo, "BOTTOMRIGHT", puck, "BOTTOMRIGHT", -inset, inset)
        end
    end

    missingButton:SetShown(showMissing)
    if missingBadge and not showMissing then missingBadge:Hide() end
    if not showMissing and missingPanel then missingPanel:Hide() end
    SetWidth(dock, showMissing and DOCK_WIDTH or DOCK_WIDTH_NO_MISSING)
    AnchorDock()
end

local function RefreshPanicButton()
    -- Panic is attached to the ability HUD as of v0.13. RaidLeader.lua no
    -- longer owns a secure panic button.
    if RA.RefreshPanicButton then RA:RefreshPanicButton() end
end

local function RefreshDockStaticIcons()
    if puck and puck.logo then
        ApplyCrispIcon(puck.logo, Theme and (Theme.Assets.Checkmark or Theme.Assets.Logo) or "Interface\\Icons\\INV_Misc_GroupNeedMore")
    end
    if dock and dock.logo then
        ApplyCrispIcon(dock.logo, Theme and (Theme.Assets.Checkmark or Theme.Assets.Logo) or "Interface\\Icons\\INV_Misc_GroupNeedMore")
    end
    if sortButton and sortButton.icon then
        ApplyCrispIcon(sortButton.icon, Theme and Theme.Assets.DockSort or "Interface\\Buttons\\UI-SortArrow")
    end
end

local function UpdateVisibility()
    if not puck then return end
    local db = GetToolboxDB()
    local profile = RA:GetDB()
    local demoVisible = profile and profile.demoMode == true
    -- The dock itself is safe to display in combat. Only subgroup mutations
    -- are forbidden there, and TryStartMode already blocks those actions.
    -- Demo mode intentionally exposes the puck outside a raid so the complete
    -- interaction can be previewed without forming a group.
    -- By default the Quick Bar is visible to every raid member. Users may
    -- opt to hide it unless they are raid lead/assist; privileged actions are
    -- still independently permission-gated when the bar is visible.
    local canSeeAsMember = IsInRaid() and ((db and db.showForNonLeaders ~= false) or IsLeaderOrAssistant())
    local shouldShow = db and db.enabled ~= false and (demoVisible or canSeeAsMember)
    local becameVisible = shouldShow and not toolboxWasVisible
    toolboxWasVisible = shouldShow and true or false

    if shouldShow then
        puck:Show()
        -- Do not auto-clamp/rewrite the puck position on roster or world
        -- updates. A stable launcher is more important than silently nudging
        -- it when dimensions/UI scale change. Legacy profiles normalize once.
        NormalizePuckPositionIfNeeded()
        RefreshDockGeometry()
        RefreshAccessAppearance()
        RefreshMissingData()
        RefreshPanicButton()
        if becameVisible and IsInRaid() and IsLeaderOrAssistant() and RA.ScheduleInspectionScan then
            RA:ScheduleInspectionScan("raid leader toolbox", 0.20, false)
        end
    else
        if sortState.active then StopSort("Raid sorting stopped.", "WARNING") end
        pendingMode, pendingSourceButton, pendingUnknownCount = nil, nil, 0
        CloseDock()
        puck:Hide()
        RefreshPanicButton()
    end
end

local function CreateAccentEdge(parent)
    local texture = parent:CreateTexture(nil, "ARTWORK")
    if Theme then Theme:RegisterAccentTexture(texture, "TOP") end
    texture:SetAllPoints(parent)
    if texture.SetTextureSliceMargins then pcall(texture.SetTextureSliceMargins, texture, 10, 10, 10, 10) end
    if texture.SetTextureSliceMode then
        local stretched = Enum and Enum.UITextureSliceMode and Enum.UITextureSliceMode.Stretched or 0
        pcall(texture.SetTextureSliceMode, texture, stretched)
    end
    texture:SetAlpha(0.66)
    CrispTexture(texture)
    return texture
end

local function CreateDockButton(parent, width, key)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button.__surfaceKey = key
    SetSize(button, width, 36)
    ApplySurface(button, TC.surfaceRaised, CopyColor(TC.lineStrong, 0.55), 8, key)
    return button
end

local function CreateToolbox()
    local toolboxDB = GetToolboxDB()

    puckAnchor = CreateFrame("Frame", "RCPArsenalRaidLeaderPuckAnchor", UIParent)
    puckAnchor:SetSize(1, 1)
    puckAnchor:SetScale(1)

    dockMonitor = CreateFrame("Frame", "RCPArsenalQuickBarClickMonitor", UIParent)
    dockMonitor:Hide()
    dockMonitor:Show()

    puck = CreateFrame("Button", "RCPArsenalRaidLeaderPuck", UIParent, "BackdropTemplate")
    puck:SetFrameStrata("MEDIUM")
    puck:SetFrameLevel(18)
    puck:SetClampedToScreen(false)
    puck:EnableMouse(true)
    puck:RegisterForDrag("LeftButton")
    SetSize(puck, toolboxDB and toolboxDB.puckSize or PUCK_SIZE, toolboxDB and toolboxDB.puckSize or PUCK_SIZE)
    ApplySurface(puck, TC.canvasDeep, CopyColor(TC.lineStrong, 0.68), 9, "puck")
    if Theme and Theme.AddShadow then Theme:AddShadow(puck, 7, 0.42) end
    BindPuckToAnchor()

    puck.logo = puck:CreateTexture(nil, "ARTWORK")
    ApplyCrispIcon(puck.logo, Theme and (Theme.Assets.Checkmark or Theme.Assets.Logo) or "Interface\\Icons\\INV_Misc_GroupNeedMore")
    puck.logo:SetTexCoord(0, 1, 0, 1)
    SetPoint(puck.logo, "TOPLEFT", puck, "TOPLEFT", 2, -2)
    SetPoint(puck.logo, "BOTTOMRIGHT", puck, "BOTTOMRIGHT", -2, 2)

    puck.pinDot = puck:CreateTexture(nil, "OVERLAY")
    puck.pinDot:SetColorTexture(TC.magenta[1], TC.magenta[2], TC.magenta[3], 1)
    SetSize(puck.pinDot, 4, 4)
    SetPoint(puck.pinDot, "TOPRIGHT", puck, "TOPRIGHT", -2, -2)
    puck.pinDot:Hide()

    -- Missing-buff status occupies the old panic-badge position. Panic
    -- now lives beside the first visible ability category on the main HUD.
    missingBadge = CreateFrame("Button", "RCPArsenalMissingBadge", UIParent, "BackdropTemplate")
    missingBadge:SetFrameStrata("MEDIUM")
    missingBadge:SetFrameLevel(20)
    missingBadge:EnableMouse(true)
    missingBadge:RegisterForClicks("LeftButtonUp")
    SetSize(missingBadge, 18, 18)
    SetPoint(missingBadge, "BOTTOMRIGHT", puck, "BOTTOMRIGHT", 5, -5)
    ApplySurface(missingBadge, CopyColor(TC.surfaceRaised, 0.995), CopyColor(TC.orange, 0.86), 8, "missingBadge")
    missingBadge.label = Font(missingBadge, 9.5, TC.orange, "BOLD")
    missingBadge.label:SetText("1")
    SetPoint(missingBadge.label, "CENTER", missingBadge, "CENTER", 0, 0)
    missingBadge:SetScript("OnEnter", function(self)
        OpenDock()
        OpenMissingPanel()
        ScheduleDelayedTooltip(self, function(owner)
            GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
            GameTooltip:SetText("Missing raid coverage")
            GameTooltip:AddLine("Shows how many major raid buffs/debuffs have no online provider.", 0.82, 0.87, 0.94, true)
            GameTooltip:Show()
        end)
    end)
    missingBadge:SetScript("OnLeave", function(self)
        CancelDelayedTooltip(self)
        ScheduleClose()
    end)
    missingBadge:SetScript("OnClick", function()
        OpenDock()
        if missingPanel:IsShown() then missingPanel:Hide() else OpenMissingPanel() end
    end)
    missingBadge:Hide()

    dock = CreateFrame("Frame", "RCPArsenalRaidLeaderToolbox", UIParent, "BackdropTemplate")
    dock:SetFrameStrata("MEDIUM")
    dock:SetFrameLevel(17)
    dock:SetClampedToScreen(true)
    dock:EnableMouse(true)
    SetSize(dock, DOCK_WIDTH, DOCK_HEIGHT)
    ApplySurface(dock, CopyColor(TC.canvasDeep or TC.surface, 0.99), CopyColor(TC.lineStrong, 0.72), 11, "dock")
    if Theme and Theme.AddShadow then Theme:AddShadow(dock, 11, 0.46) end
    dock.accent = CreateAccentEdge(dock)

    dock.logo = dock:CreateTexture(nil, "ARTWORK")
    ApplyCrispIcon(dock.logo, Theme and (Theme.Assets.Checkmark or Theme.Assets.Logo) or "Interface\\Icons\\INV_Misc_GroupNeedMore")
    dock.logo:SetTexCoord(0, 1, 0, 1)
    SetSize(dock.logo, 34, 34)
    SetPoint(dock.logo, "LEFT", dock, "LEFT", 7, 0)

    sortButton = CreateDockButton(dock, 60, "sortButton")
    SetPoint(sortButton, "LEFT", dock.logo, "RIGHT", 7, 0)
    sortButton.icon = sortButton:CreateTexture(nil, "ARTWORK")
    ApplyCrispIcon(sortButton.icon, Theme and Theme.Assets.DockSort or "Interface\\Buttons\\UI-SortArrow")
    SetSize(sortButton.icon, 18, 18)
    SetPoint(sortButton.icon, "TOP", sortButton, "TOP", 0, -3)
    sortButton.label = Font(sortButton, 7.7, TC.text, "BOLD")
    sortButton.label:SetText("SORT")
    SetPoint(sortButton.label, "BOTTOM", sortButton, "BOTTOM", 0, 5)

    splitButton = CreateDockButton(dock, 92, "splitButton")
    SetPoint(splitButton, "LEFT", sortButton, "RIGHT", 6, 0)
    splitButton.left = Font(splitButton, 9.0, TC.magenta, "BOLD")
    splitButton.left:SetText("ODD")
    splitButton.left:SetJustifyH("CENTER")
    SetPoint(splitButton.left, "LEFT", splitButton, "LEFT", 8, 0)
    SetWidth(splitButton.left, 34)
    splitButton.right = Font(splitButton, 9.0, TC.textSoft, "BOLD")
    splitButton.right:SetText("EVEN")
    splitButton.right:SetJustifyH("CENTER")
    SetPoint(splitButton.right, "RIGHT", splitButton, "RIGHT", -8, 0)
    SetWidth(splitButton.right, 36)
    splitButton.divider = splitButton:CreateTexture(nil, "ARTWORK")
    splitButton.divider:SetColorTexture(TC.lineStrong[1], TC.lineStrong[2], TC.lineStrong[3], 0.30)
    SetSize(splitButton.divider, 1, 20)
    SetPoint(splitButton.divider, "CENTER", splitButton, "CENTER", 0, 0)

    missingButton = CreateDockButton(dock, 59, "missingButton")
    SetPoint(missingButton, "LEFT", splitButton, "RIGHT", 6, 0)
    missingButton.count = Font(missingButton, 14.0, TC.magenta, "BOLD")
    missingButton.count:SetText("0")
    SetPoint(missingButton.count, "TOP", missingButton, "TOP", 0, -4)
    missingButton.label = Font(missingButton, 6.8, TC.textSoft, "BOLD")
    missingButton.label:SetText("MISSING")
    SetPoint(missingButton.label, "BOTTOM", missingButton, "BOTTOM", 0, 5)

    missingPanel = CreateFrame("Frame", "RCPArsenalMissingRaidCoverage", UIParent, "BackdropTemplate")
    missingPanel:SetFrameStrata("MEDIUM")
    missingPanel:SetFrameLevel(21)
    missingPanel:SetClampedToScreen(true)
    missingPanel:EnableMouse(true)
    SetWidth(missingPanel, 244)
    ApplySurface(missingPanel, CopyColor(TC.canvasDeep, 0.995), CopyColor(TC.lineStrong, 0.70), 12, "missingPanel")
    if Theme and Theme.AddShadow then Theme:AddShadow(missingPanel, 12, 0.48) end
    missingPanel.accent = CreateAccentEdge(missingPanel)
    missingPanel.title = Font(missingPanel, 9.4, TC.text, "BOLD")
    missingPanel.title:SetText("MISSING MAJOR RAID BUFFS / DEBUFFS")
    SetPoint(missingPanel.title, "TOPLEFT", missingPanel, "TOPLEFT", 15, -16)
    missingPanel.sectionOne = Font(missingPanel, 8.2, TC.magenta, "BOLD")
    missingPanel.sectionTwo = Font(missingPanel, 8.2, TC.orange, "BOLD")
    missingPanel.empty = Font(missingPanel, 8.5, TC.success, "BOLD")
    missingPanel.empty:SetJustifyH("CENTER")
    SetPoint(missingPanel.empty, "CENTER", missingPanel, "CENTER", 0, -8)
    missingPanel:Hide()

    sortOptionsPanel = CreateFrame("Frame", "RCPArsenalSortOptions", UIParent, "BackdropTemplate")
    sortOptionsPanel:SetFrameStrata("MEDIUM")
    sortOptionsPanel:SetFrameLevel(21)
    sortOptionsPanel:SetClampedToScreen(true)
    sortOptionsPanel:EnableMouse(true)
    SetSize(sortOptionsPanel, 226, 164)
    ApplySurface(sortOptionsPanel, CopyColor(TC.canvasDeep, 0.995), CopyColor(TC.lineStrong, 0.70), 12, "sortOptions")
    if Theme and Theme.AddShadow then Theme:AddShadow(sortOptionsPanel, 12, 0.48) end
    sortOptionsPanel.accent = CreateAccentEdge(sortOptionsPanel)
    sortOptionsPanel.title = Font(sortOptionsPanel, 9.5, TC.text, "BOLD")
    sortOptionsPanel.title:SetText("SORT OPTIONS")
    SetPoint(sortOptionsPanel.title, "TOPLEFT", sortOptionsPanel, "TOPLEFT", 15, -15)
    sortOptionsPanel.order = Font(sortOptionsPanel, 8.0, TC.textSoft, "BOLD")
    sortOptionsPanel.order:SetText("TANKS > MELEE > RANGED > HEALERS")
    SetPoint(sortOptionsPanel.order, "TOPLEFT", sortOptionsPanel, "TOPLEFT", 15, -42)
    sortOptionsPanel.groups = Font(sortOptionsPanel, 7.2, TC.muted, "BOLD")
    SetPoint(sortOptionsPanel.groups, "TOPLEFT", sortOptionsPanel, "TOPLEFT", 15, -61)

    sortOptionsPanel.undo = CreateDockButton(sortOptionsPanel, 200, "sortOptionUndo")
    SetSize(sortOptionsPanel.undo, 200, 28)
    SetPoint(sortOptionsPanel.undo, "BOTTOMLEFT", sortOptionsPanel, "BOTTOMLEFT", 13, 48)
    sortOptionsPanel.undo.__defaultLabel = "UNDO LAST SORT"
    sortOptionsPanel.undo.label = Font(sortOptionsPanel.undo, 8.0, TC.orange, "BOLD")
    sortOptionsPanel.undo.label:SetText("UNDO LAST SORT")
    SetPoint(sortOptionsPanel.undo.label, "CENTER", sortOptionsPanel.undo, "CENTER", 0, 0)
    sortOptionsPanel.undo:Hide()

    sortOptionsPanel.run = CreateDockButton(sortOptionsPanel, 104, "sortOptionRun")
    SetSize(sortOptionsPanel.run, 104, 30)
    SetPoint(sortOptionsPanel.run, "BOTTOMLEFT", sortOptionsPanel, "BOTTOMLEFT", 13, 12)
    sortOptionsPanel.run.label = Font(sortOptionsPanel.run, 8.0, TC.text, "BOLD")
    sortOptionsPanel.run.label:SetText("RUN NORMAL SORT")
    SetPoint(sortOptionsPanel.run.label, "CENTER", sortOptionsPanel.run, "CENTER", 0, 0)

    sortOptionsPanel.cancel = CreateDockButton(sortOptionsPanel, 82, "sortOptionCancel")
    SetSize(sortOptionsPanel.cancel, 82, 30)
    SetPoint(sortOptionsPanel.cancel, "LEFT", sortOptionsPanel.run, "RIGHT", 8, 0)
    sortOptionsPanel.cancel.label = Font(sortOptionsPanel.cancel, 8.0, TC.textSoft, "BOLD")
    sortOptionsPanel.cancel.label:SetText("CANCEL")
    SetPoint(sortOptionsPanel.cancel.label, "CENTER", sortOptionsPanel.cancel, "CENTER", 0, 0)
    sortOptionsPanel:Hide()

    puck:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    puck:SetScript("OnEnter", function(self)
        OpenDock()
        ScheduleDelayedTooltip(self, function(owner)
            GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
            GameTooltip:SetText("RCP Arsenal Quick Bar")
            local db = GetToolboxDB()
            local seconds = db and db.countdownSeconds or 15
            local hasAccess = IsLeaderOrAssistant()
            local restricted = hasAccess and 0.82 or 0.50
            GameTooltip:AddLine(string.format("Left click: %ds countdown / cancel", seconds), restricted, hasAccess and 0.87 or 0.52, hasAccess and 0.94 or 0.56)
            GameTooltip:AddLine("Middle click: pin / unpin", 0.82, 0.87, 0.94)
            GameTooltip:AddLine("Right click: ready check", restricted, hasAccess and 0.87 or 0.52, hasAccess and 0.94 or 0.56)
            if not hasAccess then
                GameTooltip:AddLine("Countdown and Ready Check require raid lead or assist.", 1.0, 0.62, 0.24, true)
            end
            GameTooltip:Show()
        end)
    end)
    puck:SetScript("OnLeave", function(self)
        CancelDelayedTooltip(self)
        ScheduleClose()
    end)
    puck:SetScript("OnClick", function(_, button)
        if button == "LeftButton" then
            -- Dragging the puck should never start or cancel a countdown.
            if puckWasDragged then return end
            TogglePuckCountdown()
        elseif button == "RightButton" then
            if not IsLeaderOrAssistant() then
                PrintLeadAccessRequired("Ready Check")
                return
            end
            if C_PartyInfo and C_PartyInfo.DoReadyCheck then
                C_PartyInfo.DoReadyCheck()
            end
        elseif button == "MiddleButton" then
            dockPinned = not dockPinned
            if puck.pinDot then puck.pinDot:SetShown(dockPinned) end
            if dockPinned then
                OpenDock()
            else
                ScheduleClose()
            end
        end
    end)
    dock:SetScript("OnEnter", OpenDock)
    dock:SetScript("OnLeave", ScheduleClose)

    HookHover(sortButton)
    HookHover(splitButton)
    HookHover(missingButton, OpenMissingPanel)
    HookHover(missingPanel)
    HookHover(sortOptionsPanel)
    HookHover(sortOptionsPanel.run)
    HookHover(sortOptionsPanel.cancel)
    HookHover(sortOptionsPanel.undo)

    sortButton:SetScript("OnClick", function(_, button)
        if not IsLeaderOrAssistant() then
            SetActionButtonState(sortButton, "NO ACCESS", "WARNING")
            PrintLeadAccessRequired("Raid sorting")
            ResetActionButtonSoon(sortButton, 2.5)
            return
        end
        if button == "RightButton" then
            RefreshSortOptions()
            ToggleSortOptions()
        else
            TryStartMode("ROLE_SORT", true, sortButton)
        end
    end)

    splitButton:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            TryStartMode("SPLIT_ADJACENT", true, splitButton)
        else
            TryStartMode("SPLIT_ODD_EVEN", true, splitButton)
        end
    end)

    missingButton:SetScript("OnClick", function()
        if missingPanel:IsShown() then missingPanel:Hide() else OpenMissingPanel() end
    end)

    sortOptionsPanel.undo:SetScript("OnClick", function()
        sortOptionsPanel:Hide()
        StartUndoLastSort(sortOptionsPanel.undo)
    end)

    sortOptionsPanel.run:SetScript("OnClick", function()
        sortOptionsPanel:Hide()
        TryStartMode("ROLE_SORT", true, sortButton)
    end)
    sortOptionsPanel.cancel:SetScript("OnClick", function()
        if sortState.active then StopSort("Raid sorting cancelled.", "WARNING") end
        sortOptionsPanel:Hide()
    end)

    sortButton:SetScript("OnEnter", function(self)
        OpenDock()
        ScheduleDelayedTooltip(self, function(owner)
            GameTooltip:SetOwner(owner, "ANCHOR_TOP")
            GameTooltip:SetText("Sort Raid")
            GameTooltip:AddLine("Left click: Tanks > Melee > Ranged > Healers", 0.82, 0.87, 0.94)
            GameTooltip:AddLine("Right click: Sort options", 0.82, 0.87, 0.94)
            if not IsLeaderOrAssistant() then
                GameTooltip:AddLine("Unavailable: raid lead or assist required.", 1.0, 0.62, 0.24)
            elseif InCombatLockdown() then
                GameTooltip:AddLine("Unavailable in combat.", 1.0, 0.62, 0.24)
            end
            GameTooltip:Show()
        end)
    end)
    sortButton:HookScript("OnLeave", function(self) CancelDelayedTooltip(self); ScheduleClose() end)

    splitButton:SetScript("OnEnter", function(self)
        OpenDock()
        ScheduleDelayedTooltip(self, function(owner)
            GameTooltip:SetOwner(owner, "ANCHOR_TOP")
            GameTooltip:SetText("Split Raid Evenly")
            GameTooltip:AddLine("Left click: Odd / Even groups", 0.82, 0.87, 0.94)
            GameTooltip:AddLine("Right click: G1+G2 / G3+G4 style split", 0.82, 0.87, 0.94)
            if not IsLeaderOrAssistant() then
                GameTooltip:AddLine("Unavailable: raid lead or assist required.", 1.0, 0.62, 0.24)
            elseif InCombatLockdown() then
                GameTooltip:AddLine("Unavailable in combat.", 1.0, 0.62, 0.24)
            end
            GameTooltip:Show()
        end)
    end)
    splitButton:HookScript("OnLeave", function(self) CancelDelayedTooltip(self); ScheduleClose() end)

    missingButton:SetScript("OnEnter", function(self)
        OpenMissingPanel()
        ScheduleDelayedTooltip(self, function(owner)
            GameTooltip:SetOwner(owner, "ANCHOR_TOP")
            GameTooltip:SetText("Missing Major Raid Buffs / Debuffs")
            GameTooltip:AddLine("Based on online players in tracked raid groups.", 0.82, 0.87, 0.94, true)
            GameTooltip:Show()
        end)
    end)
    missingButton:HookScript("OnLeave", function(self) CancelDelayedTooltip(self); ScheduleClose() end)

    puck:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        puckWasDragged = true
        CancelClose()
        CloseDock()
        StartPuckDrag()
    end)
    puck:SetScript("OnDragStop", function()
        StopPuckDrag(true)
        OpenDock()
        -- Keep the drag guard through the release frame in case WoW also
        -- emits OnClick, then clear it for the next intentional click.
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function() puckWasDragged = false end)
        else
            puckWasDragged = false
        end
    end)
    puck:SetScript("OnHide", CloseDock)

    RestorePuckPosition()
    RefreshDockGeometry()
    RefreshAccessAppearance()
    RefreshMissingData()
    dock:Hide()
    UpdateVisibility()
end

function Toolbox:IsSorting() return sortState.active end
function Toolbox:SortByRole() TryStartMode("ROLE_SORT", true, sortButton) end
function Toolbox:SplitOddEven() TryStartMode("SPLIT_ODD_EVEN", true, splitButton) end
function Toolbox:SplitAdjacent() TryStartMode("SPLIT_ADJACENT", true, splitButton) end
function Toolbox:RefreshMissing() RefreshMissingData(); if missingPanel and missingPanel:IsShown() then LayoutMissingPanel() end end
function Toolbox:GetMissingCoverage()
    RefreshMissingData()
    return missingData.total, missingData.buffs, missingData.debuffs
end
function Toolbox:Refresh()
    RefreshDockGeometry()
    UpdateVisibility()
    Toolbox:RefreshMissing()
    RefreshPanicButton()
end
function Toolbox:RefreshGeometry() RefreshDockGeometry() end
function Toolbox:ResetPosition()
    if InCombatLockdown() then return false end
    CloseDock(true)
    dockPinned = false
    if puck and puck.pinDot then puck.pinDot:Hide() end
    local db = GetToolboxDB()
    if not db then return false end
    db.position = { point = "LEFT", relativePoint = "LEFT", x = 12, y = 70 }
    db.positionAnchorVersion = 0
    puckPositionNormalized = false
    RestorePuckPosition()
    RefreshDockGeometry()
    if puck and puck:IsShown() then NormalizePuckPositionIfNeeded() end
    return true
end
function Toolbox:ShowMissingPanel() OpenMissingPanel() end
function Toolbox:RefreshPanic() RefreshPanicButton() end
function Toolbox:IsPinned() return dockPinned end
function Toolbox:SetPinned(value)
    dockPinned = value and true or false
    if puck and puck.pinDot then puck.pinDot:SetShown(dockPinned) end
    if dockPinned then OpenDock() else ScheduleClose() end
end
function Toolbox:Close(force) CloseDock(force == true) end

RA:RegisterInitializer(CreateToolbox)

RA:RegisterEvent("GROUP_ROSTER_UPDATE", function()
    UpdateVisibility()
    RefreshMissingData()
    if missingPanel and missingPanel:IsShown() then LayoutMissingPanel() end
    if sortOptionsPanel and sortOptionsPanel:IsShown() then RefreshSortOptions() end

    if sortState.active then
        local snapshot = BuildRaidSnapshot()
        local expected = snapshot and snapshot.byName[sortState.expectedName]
        if expected and expected.group == sortState.expectedGroup then
            ClearSortTimer()
            C_Timer.After(0.04, function()
                if sortState.active then ProcessSortStep("roster update") end
            end)
        end
    end
end)

RA:RegisterEvent("PLAYER_REGEN_DISABLED", function()
    if puckDragState then StopPuckDrag(true) end
    if sortState.active then StopSort("Raid sorting stopped: combat started.", "WARNING") end
    UpdateVisibility()
end)

RA:RegisterEvent("PLAYER_REGEN_ENABLED", UpdateVisibility)

RA:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(0.35, function()
        if RA.Initialized then
            -- The anchor persists through zone/loading transitions; update
            -- data/visibility only and never rewrite the user's position.
            UpdateVisibility()
            RefreshMissingData()
        end
    end)
end)

RA:RegisterCallback("REPORTS_UPDATED", function()
    RefreshMissingData()
    if missingPanel and missingPanel:IsShown() then LayoutMissingPanel() end

    if pendingMode and not sortState.active and not InCombatLockdown() then
        local plan, err, unknown = BuildSortPlan(pendingMode)
        if plan then
            StartSortFromPlan(plan, pendingSourceButton or sortButton)
        elseif err == "unknown roles" then
            pendingUnknownCount = unknown and #unknown or pendingUnknownCount
            SetActionButtonState(pendingSourceButton or sortButton, "SCANNING", "WORKING")
        end
    end
end)

RA:RegisterCallback("INSPECTION_STATE_CHANGED", function()
    if pendingMode and not sortState.active and RA.IsInspectionRunning and not RA:IsInspectionRunning() then
        local plan, err, unknown = BuildSortPlan(pendingMode)
        if plan then
            StartSortFromPlan(plan, pendingSourceButton or sortButton)
        else
            local source = pendingSourceButton or sortButton
            pendingMode, pendingSourceButton = nil, nil
            pendingUnknownCount = unknown and #unknown or pendingUnknownCount
            SetActionButtonState(source, err == "unknown roles" and "NEED SPEC" or "UNAVAILABLE", "WARNING")
            ResetActionButtonSoon(source, 3.5)
        end
    end
end)

RA:RegisterCallback("DEMO_MODE_CHANGED", function()
    UpdateVisibility()
    RefreshMissingData()
    if missingPanel and missingPanel:IsShown() then LayoutMissingPanel() end
end)

RA:RegisterCallback("PROFILE_RESET", function()
    C_Timer.After(0, function()
        puckPositionNormalized = false
        RestorePuckPosition()
        RefreshDockGeometry()
        UpdateVisibility()
        RefreshMissingData()
    end)
end)

RA:RegisterCallback("PROFILE_IMPORTED", function()
    C_Timer.After(0, function()
        -- Portable imports preserve local position. Apply appearance/timing
        -- prefs without touching the already-stable anchor.
        RefreshDockGeometry()
        UpdateVisibility()
        RefreshMissingData()
    end)
end)

RA:RegisterCallback("VISUAL_ASSET_REFRESH", function()
    RefreshDockStaticIcons()
end)

RA:RegisterCallback("ACCENT_THEME_CHANGED", function()
    if not puck then return end
    -- Accent textures registered with Theme update automatically. Refresh the
    -- state colors and any currently visible composition panel.
    SetSurface(puck, TC.canvasDeep, CopyColor(TC.lineStrong, 0.68), "puck")
    SetSurface(dock, CopyColor(TC.canvasDeep, 0.99), CopyColor(TC.lineStrong, 0.72), "dock")
    local locked = InCombatLockdown() or not IsLeaderOrAssistant()
    SetActionButtonState(sortButton, nil, sortState.active and "WORKING" or (locked and "LOCKED" or "DEFAULT"))
    SetActionButtonState(splitButton, nil, locked and "LOCKED" or "DEFAULT")
    RefreshMissingData()
    if missingPanel and missingPanel:IsShown() then LayoutMissingPanel() end
end)
