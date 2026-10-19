local _, RA = ...

local Tools = {}
RA.PersonalTools = Tools

-- Independently authored from Blizzard's b9be9379 UI/API contracts and the
-- 2026-10-18 RCP feasibility report. EasyAutoAcceptRes b902c0d7 was a behavior
-- reference only; no implementation is incorporated here.
--
-- Normal res is deliberately conservative. RESURRECT_REQUEST does not identify
-- battle res, and a dead player's own combat flag is insufficient.
-- The consumable visual is experimental until its native threshold boundary,
-- readiness, and raid restriction behavior are verified on the target client.
local POPUPS = { "RESURRECT", "RESURRECT_NO_SICKNESS", "RESURRECT_NO_TIMER" }
local DEFAULT_THRESHOLD = 40 -- Editable implementation default, not a user preference.
local DEFAULT_POSITION = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -140 }
local VALID_POINTS = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true,
    CENTER = true, RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true }

-- Fixed item allowlist; no bag tooltip parsing or spell/defensive fallback.
-- Stones: Blizzard_CooldownViewer/CooldownViewerItemData.lua at b9be9379.
-- Potion IDs: Midnight Potion Macros, retrieved 2026-10-19:
-- https://gist.github.com/Luckyone961/24b605b97ad48565b8a4667a79377fb6
-- Item data: https://www.wowhead.com/item=271883 and /item=241304
-- Other qualities/special variants are intentionally not inferred.
local CANDIDATES = {
    { id = 224464, kind = "Healthstone" },
    { id = 5512, kind = "Healthstone" },
    { id = 271884, kind = "Health potion" },
    { id = 271883, kind = "Health potion" },
    { id = 241304, kind = "Health potion" },
    { id = 241305, kind = "Health potion" },
}

local reminder, bounce, curve, curveThreshold, readinessTicker, resTimer
local preview, previewMode, previewMoving
local selectedItem, bouncing
local reminderReason = "Off."
local resReason = "Off."

local function IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function Number(value)
    if IsSecret(value) or type(value) ~= "number" then return nil end
    if value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
end

local function ReadBoolean(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, value = pcall(func, ...)
    if not ok or IsSecret(value) or type(value) ~= "boolean" then return nil end
    return value
end

local function Threshold(value)
    local number = Number(value)
    return math.floor(math.max(1, math.min(99, number or DEFAULT_THRESHOLD)) + 0.5)
end

local function Settings()
    local db = RA:GetDB()
    return db and type(db.personalTools) == "table" and db.personalTools or nil
end

local function Enabled(key)
    local settings = Settings()
    return settings and settings[key] == true
end

local function Notify()
    RA:FireCallback("PERSONAL_TOOLS_CHANGED")
end

local function CancelRes()
    if resTimer then resTimer:Cancel(); resTimer = nil end
end

local function StopReadiness()
    if readinessTicker then readinessTicker:Cancel(); readinessTicker = nil end
end

local function HideReminder(reason)
    selectedItem = nil
    reminderReason = reason
    if reminder then
        reminder:SetAlpha(0)
        reminder:Hide()
        if bouncing then bounce:Stop(); bouncing = false end
    end
end

local function ReminderAPIsAvailable()
    return type(issecretvalue) == "function" and type(UnitHealthPercent) == "function"
        and C_CurveUtil and type(C_CurveUtil.CreateCurve) == "function"
        and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step ~= nil
        and C_Item and type(C_Item.GetItemCount) == "function"
        and type(C_Item.IsUsableItem) == "function" and type(C_Item.GetItemCooldown) == "function"
        and type(C_Item.GetItemIconByID) == "function" and type(GetTime) == "function"
        and C_Timer and type(C_Timer.NewTicker) == "function"
end

local function PositionFrame(frame)
    if not frame then return end
    local settings = Settings()
    local position = settings and settings.reminderPosition
    position = type(position) == "table" and position or DEFAULT_POSITION
    local point = VALID_POINTS[position.point] and position.point or DEFAULT_POSITION.point
    local relative = VALID_POINTS[position.relativePoint] and position.relativePoint or point
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, relative, Number(position.x) or 0, Number(position.y) or -140)
end

local function PositionReminder()
    PositionFrame(reminder)
    PositionFrame(preview)
end

local function CreateReminder()
    if reminder then return end
    -- A Frame with no secure template, item action, click, tooltip, or mouse
    -- input. Secret alpha never gates interaction with another action surface.
    reminder = CreateFrame("Frame", "RCPArsenalConsumableReminder", UIParent)
    reminder:Hide()
    reminder:SetAlpha(0)
    reminder:SetSize(56, 56)
    reminder:EnableMouse(false)
    reminder:SetFrameStrata("HIGH")
    local child = CreateFrame("Frame", nil, reminder)
    child:SetAllPoints()
    child:EnableMouse(false)
    local border = child:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.05, 0.04, 0.06, 0.94)
    reminder.icon = child:CreateTexture(nil, "ARTWORK")
    reminder.icon:SetPoint("TOPLEFT", 3, -3)
    reminder.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    reminder.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local label = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOP", child, "BOTTOM", 0, -4)
    label:SetText("Press your item/macro key")
    bounce = child:CreateAnimationGroup()
    bounce:SetLooping("REPEAT")
    for order = 1, 2 do
        local translation = bounce:CreateAnimation("Translation")
        translation:SetOrder(order)
        translation:SetOffset(0, order == 1 and 7 or -7)
        translation:SetDuration(0.45)
        translation:SetSmoothing("IN_OUT")
    end
    PositionReminder()
end

local function BuildCurve(threshold)
    if curve and curveThreshold == threshold then return true end
    local ok, value = pcall(function()
        local value = C_CurveUtil.CreateCurve()
        value:SetType(Enum.LuaCurveType.Step)
        value:AddPoint(0, 1)
        value:AddPoint(threshold / 100, 0)
        value:AddPoint(1, 0)
        return value
    end)
    if not ok then curve, curveThreshold = nil, nil; return false end
    curve, curveThreshold = value, threshold
    return true
end

local function ApplyHealthAlpha()
    if not reminder or not selectedItem or not Enabled("consumableReminder") then return end
    -- ReadBoolean rejects secret/unknown life state before Lua branches. This
    -- guard also handles a death health event before PLAYER_DEAD is dispatched.
    if ReadBoolean(UnitIsDeadOrGhost, "player") ~= false then
        StopReadiness()
        HideReminder("Player dead or life state unknown; visual suppressed.")
        Notify()
        return
    end
    -- The live result exists only as an argument to its documented display
    -- sink. Never compare, format, convert, store, read back, or branch on it.
    local ok = pcall(function()
        reminder:SetAlpha(UnitHealthPercent("player", false, curve))
    end)
    if not ok then HideReminder("Native health display unavailable; visual suppressed.") end
end

local function ReadyItem(candidate, now)
    local ok, count, usable, noMana, start, duration, enabled, icon = pcall(function()
        local count = C_Item.GetItemCount(candidate.id, false, true, false, false)
        local usable, noMana = C_Item.IsUsableItem(candidate.id)
        local start, duration, enabled = C_Item.GetItemCooldown(candidate.id)
        return count, usable, noMana, start, duration, enabled, C_Item.GetItemIconByID(candidate.id)
    end)
    if not ok then return nil end
    -- All inputs are checked for secrecy before any comparison/arithmetic.
    count, start, duration, icon = Number(count), Number(start), Number(duration), Number(icon)
    if IsSecret(usable) or IsSecret(noMana) or IsSecret(enabled) then return nil end
    if not count or count <= 0 or usable ~= true or noMana ~= false or enabled ~= true
        or not start or not duration or not icon or icon <= 0 or start < 0 or duration < 0 then return nil end
    if duration > 0 and start + duration > now then return nil end
    return icon
end

function Tools:Refresh()
    local previousItem, previousReason, previousRes = selectedItem, reminderReason, resReason
    if not Enabled("autoRes") then CancelRes(); resReason = "Off."
    elseif resReason == "Off." then resReason = "On. Combat/encounter offers stay manual; client confirmation pending." end

    if not Enabled("consumableReminder") then
        StopReadiness()
        HideReminder("Off.")
    elseif not ReminderAPIsAvailable() then
        StopReadiness()
        HideReminder("Required Retail display/item APIs unavailable; visual suppressed.")
    elseif ReadBoolean(UnitIsDeadOrGhost, "player") ~= false then
        StopReadiness()
        HideReminder("Player dead or life state unknown; visual suppressed.")
    else
        local settings = Settings()
        local now = Number(GetTime())
        if not now or not BuildCurve(Threshold(settings.healthThreshold)) then
            StopReadiness()
            HideReminder("Native curve or clock unavailable; visual suppressed.")
        else
            local candidate, icon
            for _, item in ipairs(CANDIDATES) do
                icon = ReadyItem(item, now)
                if icon then candidate = item; break end
            end
            if candidate then
                CreateReminder()
                selectedItem = candidate.id
                reminder.icon:SetTexture(icon)
                reminderReason = candidate.kind .. " ready. Native threshold boundary and raid behavior need client validation."
                reminder:Show()
                if not bouncing then bounce:Play(); bouncing = true end
                ApplyHealthAlpha()
            else
                HideReminder("No ready supported Healthstone or healing potion.")
            end
            -- At most six fixed-item checks per second, only while opted in.
            -- Events refresh promptly; this covers readiness changes without
            -- bag/cooldown events and does not reconstruct reuse from a timer.
            if not readinessTicker then
                readinessTicker = C_Timer.NewTicker(1, function()
                    Tools:Refresh()
                end)
            end
        end
    end
    if previousItem ~= selectedItem or previousReason ~= reminderReason or previousRes ~= resReason then Notify() end
end

local function NormalResIsSafe()
    if type(issecretvalue) ~= "function" then return false end
    if ReadBoolean(InCombatLockdown) ~= false or ReadBoolean(IsEncounterInProgress) ~= false then return false end
    -- A dead player's local pet can remain in combat even while solo and
    -- personal lockdown is false. Check it before the solo early return.
    local petExists = ReadBoolean(UnitExists, "pet")
    if petExists == nil or (petExists and ReadBoolean(UnitAffectingCombat, "pet") ~= false) then return false end
    local raid, grouped = ReadBoolean(IsInRaid), ReadBoolean(IsInGroup)
    if raid == nil or grouped == nil then return false end
    local prefix, count = "party", 4
    if raid then
        if type(GetNumGroupMembers) ~= "function" then return false end
        local ok, size = pcall(GetNumGroupMembers)
        size = ok and Number(size) or nil
        if not size or size < 1 or size > 40 or size ~= math.floor(size) then return false end
        prefix, count = "raid", size
    elseif not grouped then return true end
    -- Fixed group tokens only. No GUID, name, or UnitIsUnit comparison. These
    -- guards do not identify an offer's spell type; unknown combat state stays
    -- manual. No universal battle-res classification is claimed.
    for index = 1, count do
        for _, unit in ipairs({ prefix .. index, prefix .. "pet" .. index }) do
            local exists = ReadBoolean(UnitExists, unit)
            if exists == nil then return false end
            if exists and ReadBoolean(UnitAffectingCombat, unit) ~= false then return false end
        end
    end
    return true
end

local function RequestNormalRes()
    CancelRes()
    if not Enabled("autoRes") then return end
    if not NormalResIsSafe() then
        resReason = "Offer left manual: combat, encounter, or group state is active or unknown."
        Notify()
        return
    end
    if not C_Timer or type(C_Timer.NewTimer) ~= "function" or type(AcceptResurrect) ~= "function"
        or type(StaticPopup_Hide) ~= "function" or type(ResurrectGetOfferer) ~= "function"
        or type(GetCorpseRecoveryDelay) ~= "function" then
        resReason = "Offer left manual: resurrection APIs unavailable."
        Notify()
        return
    end
    -- Defer one frame so Blizzard has raised the appropriate dialog, then
    -- recheck combat. No names are retained or compared across the deferral.
    resTimer = C_Timer.NewTimer(0, function()
        resTimer = nil
        if not Enabled("autoRes") then return end
        if not NormalResIsSafe() then
            resReason = "Offer left manual: combat, encounter, or group state changed."
            Notify()
            return
        end
        local ok, offer, delay = pcall(function() return ResurrectGetOfferer(), GetCorpseRecoveryDelay() end)
        delay = Number(delay)
        if not ok or IsSecret(offer) or type(offer) ~= "string" or offer == "" or delay ~= 0 then
            resReason = "Offer left manual: unavailable offer or recovery delay."
        elseif pcall(AcceptResurrect) then
            for _, popup in ipairs(POPUPS) do StaticPopup_Hide(popup) end
            resReason = "Resurrection acceptance requested outside detected combat; client confirmation pending."
        else
            resReason = "Offer left manual: acceptance unavailable."
        end
        Notify()
    end)
end

function Tools:SetOption(key, value)
    local db = RA:GetDB()
    if not db then return false, "Profile unavailable." end
    if IsSecret(key) or IsSecret(value) then return false, "Invalid personal tool option." end
    if key ~= "autoRes" and key ~= "consumableReminder" and key ~= "healthThreshold" then
        return false, "Unknown personal tool option."
    end
    if key == "healthThreshold" then
        if not Number(value) then return false, "Choose a numeric health threshold." end
        value = Threshold(value)
    elseif type(value) ~= "boolean" then return false, "Choose on or off." end
    if type(db.personalTools) ~= "table" then
        db.personalTools = { autoRes = false, consumableReminder = false, healthThreshold = DEFAULT_THRESHOLD }
    end
    db.personalTools[key] = value
    self:Refresh()
    Notify()
    return true
end

function Tools:SetReminderPosition(x, y)
    x, y = Number(x), Number(y)
    if not x or not y then return false, "Choose numeric offsets." end
    local settings = Settings()
    if not settings then return false, "Profile unavailable." end
    settings.reminderPosition = { point = "CENTER", relativePoint = "CENTER",
        x = math.max(-4096, math.min(4096, x)), y = math.max(-4096, math.min(4096, y)) }
    PositionReminder()
    Notify()
    return true
end

function Tools:ResetReminderPosition()
    local settings = Settings()
    if not settings then return false, "Profile unavailable." end
    settings.reminderPosition = nil
    PositionReminder()
    Notify()
    return true
end

local function SavePreviewPosition()
    local centerX, centerY = preview:GetCenter()
    centerX, centerY = Number(centerX), Number(centerY)
    local frameScale = Number(preview:GetEffectiveScale())
    local parentScale = Number(UIParent:GetEffectiveScale())
    local width, height = Number(UIParent:GetWidth()), Number(UIParent:GetHeight())
    if not centerX or not centerY or not frameScale or frameScale <= 0 or not parentScale or parentScale <= 0
        or not width or not height then return false end
    -- Region coordinates use its effective scale. Convert physical pixels to
    -- UIParent coordinates before saving center-relative native offsets.
    return Tools:SetReminderPosition(centerX * frameScale / parentScale - width / 2,
        centerY * frameScale / parentScale - height / 2)
end

local function CreatePreview()
    if preview then return end
    -- This ordinary sample is independent of the health-alpha parent and is
    -- allocated only by an explicit Preview/Move click. It has no item action,
    -- inventory query, health query, animation, or timer.
    preview = CreateFrame("Frame", "RCPArsenalConsumableReminderPreview", UIParent)
    preview:Hide()
    preview:SetAlpha(1)
    preview:SetSize(56, 56)
    preview:SetFrameStrata("DIALOG")
    preview:SetMovable(true)
    preview:SetClampedToScreen(true)
    preview:EnableMouse(false)
    preview:RegisterForDrag("LeftButton")
    local border = preview:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.95, 0.65, 0.20, 1)
    local icon = preview:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3, 3)
    icon:SetTexture("Interface\\Icons\\INV_Stone_04")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    preview.label = preview:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    preview.label:SetPoint("BOTTOM", preview, "TOP", 0, 5)
    local caption = preview:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    caption:SetPoint("TOP", preview, "BOTTOM", 0, -4)
    caption:SetText("Press your item/macro key")
    preview:SetScript("OnDragStart", function()
        if previewMode == "MOVE" and ReadBoolean(InCombatLockdown) == false then
            previewMoving = true
            preview:StartMoving()
        end
    end)
    preview:SetScript("OnDragStop", function()
        if not previewMoving then return end
        previewMoving = false
        preview:StopMovingOrSizing()
        if ReadBoolean(InCombatLockdown) ~= false or not SavePreviewPosition() then PositionReminder() end
    end)
end

function Tools:StopReminderPreview()
    if preview then
        preview:StopMovingOrSizing()
        preview:Hide()
        preview:EnableMouse(false)
    end
    previewMoving, previewMode = false, nil
    return true
end

function Tools:PreviewReminder()
    if not Settings() then return false, "Profile unavailable." end
    self:StopReminderPreview()
    CreatePreview()
    PositionFrame(preview)
    previewMode = "PREVIEW"
    preview.label:SetText("PREVIEW - SAMPLE")
    preview:Show()
    return true
end

function Tools:MoveReminder()
    if ReadBoolean(InCombatLockdown) ~= false then return false, "Move this after combat." end
    local ok, reason = self:PreviewReminder()
    if not ok then return false, reason end
    previewMode = "MOVE"
    preview.label:SetText("DRAG TO MOVE - SAMPLE")
    preview:EnableMouse(true)
    return true
end

function Tools:GetStatusText(key)
    if key == "autoRes" then return resReason end
    if key == "consumableReminder" then return reminderReason end
    return "Normal res: " .. resReason .. " Reminder: " .. reminderReason
end

function Tools:GetState()
    return { autoRes = Enabled("autoRes") == true, consumableReminder = Enabled("consumableReminder") == true,
        healthThreshold = Threshold((Settings() or {}).healthThreshold), itemID = selectedItem,
        reminderStatus = reminderReason, autoResStatus = resReason, previewMode = previewMode }
end

-- For the report's synthetic boundary probe only; contains ordinary points,
-- never sampled health or alpha. A Lua mock does not certify native equality.
function Tools:GetReminderCurveForValidation()
    return curve
end

RA:RegisterInitializer(function() Tools:Refresh() end)
RA:RegisterCallback("PROFILE_RESET", function() Tools:StopReminderPreview(); Tools:Refresh(); PositionReminder() end)
RA:RegisterEvent("RESURRECT_REQUEST", RequestNormalRes)
for _, event in ipairs({ "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN",
    "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_ALIVE",
    "PLAYER_DEAD", "PLAYER_UNGHOST" }) do
    RA:RegisterEvent(event, function(eventName)
        if eventName == "PLAYER_REGEN_DISABLED" then Tools:StopReminderPreview() end
        if Enabled("consumableReminder") then Tools:Refresh() end
    end)
end
for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH" }) do
    RA:RegisterEvent(event, function(_, unit)
        if Enabled("consumableReminder") and not IsSecret(unit) and unit == "player" then ApplyHealthAlpha() end
    end)
end
