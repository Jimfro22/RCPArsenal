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
-- inventory, and raid restriction behavior are verified on the target client.
local POPUPS = { "RESURRECT", "RESURRECT_NO_SICKNESS", "RESURRECT_NO_TIMER" }
local GENERIC_POTION_ICON = "Interface\\Icons\\INV_Potion_51" -- Preview illustration only.
local DEFAULT_THRESHOLD = 40 -- Editable implementation default, not a user preference.
local DEFAULT_POSITION = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -140 }
local VALID_POINTS = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true,
    CENTER = true, RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true }

local reminder, bounce, curve, curveThreshold, resTimer
local reminderLabel, previewCaption
local COMBAT_MODES = { BOTH = true, IN_COMBAT = true, OUT_OF_COMBAT = true }
local preview, previewMode, previewMoving, previewBounce
local selectedItem, selectedKind, inventory, bouncing
local previewKind = "stone"
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

local function IconSize()
    return math.floor(math.max(24, math.min(128, Number((Settings() or {}).reminderIconSize) or 56)) + 0.5)
end

local function TextSize()
    local saved = Number((Settings() or {}).reminderTextSize)
    if not saved and GameFontNormalSmall and GameFontNormalSmall.GetFont then
        local ok, _, height = pcall(GameFontNormalSmall.GetFont, GameFontNormalSmall)
        if ok then saved = Number(height) end
    end
    return math.floor(math.max(8, math.min(32, saved or 10)) + 0.5)
end

local function ReminderText(kind)
    if kind == "empty" then return "OUT OF POTIONS" end
    local settings = Settings() or {}
    local text = settings[kind == "stone" and "reminderStoneText" or "reminderPotionText"]
    if type(text) ~= "string" or IsSecret(text) then text = settings.reminderText end
    if type(text) ~= "string" or IsSecret(text) then text = kind == "stone" and "Use Healthstone" or "Use healing potion" end
    return RA:NormalizeReminderText(text)
end

local function CombatMode()
    local mode = (Settings() or {}).reminderCombat
    return COMBAT_MODES[mode] and mode or "BOTH"
end

local function CombatAllowsReminder()
    local mode = CombatMode()
    if mode == "BOTH" then return true end
    local combat = ReadBoolean(InCombatLockdown)
    return combat ~= nil and (combat == (mode == "IN_COMBAT"))
end

local function ApplyAppearance(frame, label, kind)
    if not frame then return end
    frame:SetSize(IconSize(), IconSize())
    if label then
        if RA.ApplyFont then RA:ApplyFont(label, TextSize(), "REGULAR", false)
        elseif label.SetTextHeight then label:SetTextHeight(TextSize()) end
        if label.SetWidth then label:SetWidth(math.max(260, IconSize())) end
        if label.SetWordWrap then label:SetWordWrap(true) end
        local text = ReminderText(kind):gsub("|", "||") -- Literal text, never links/textures/commands.
        if RA.SetVisualText then RA:SetVisualText(label, text) else label:SetText(text) end
    end
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

local function HideReminder(reason)
    selectedItem, selectedKind = nil, nil
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
        and RA.HealingSupplies and type(RA.HealingSupplies.Snapshot) == "function"
end

local function CreateBounce(body)
    local animation = body:CreateAnimationGroup()
    animation:SetLooping("REPEAT")
    for order = 1, 2 do
        local translation = animation:CreateAnimation("Translation")
        translation:SetOrder(order)
        translation:SetOffset(0, order == 1 and 7 or -7)
        translation:SetDuration(0.45)
        translation:SetSmoothing("IN_OUT")
    end
    return animation
end

local function StartBounce()
    if not bounce then return end
    local playing = ReadBoolean(bounce.IsPlaying, bounce)
    if playing == false or (playing == nil and not bouncing) then bounce:Play() end
    bouncing = true
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
    reminder.border = border
    border:SetAllPoints()
    border:SetColorTexture(0.05, 0.04, 0.06, 0.94)
    reminder.icon = child:CreateTexture(nil, "ARTWORK")
    reminder.icon:SetPoint("TOPLEFT", 3, -3)
    reminder.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    reminder.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local label = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    reminderLabel = label
    label:SetPoint("TOP", child, "BOTTOM", 0, -4)
    ApplyAppearance(reminder, label)
    child:SetAlpha(1)
    bounce = CreateBounce(child)
    reminder:SetScript("OnShow", function()
        if selectedKind and Enabled("consumableReminder") then StartBounce() end
    end)
    PositionReminder()
end

local function BuildCurve(threshold)
    if curve and curveThreshold == threshold then return true end
    local ok, value = pcall(function()
        local value = C_CurveUtil.CreateCurve()
        value:SetType(Enum.LuaCurveType.Step)
        local boundary = threshold / 100
        -- Step promotes the next point on equality. Keep the boundary at 1,
        -- then place 0 one expected binary32 precision step above it. Native
        -- point readback checks the constant, not UnitHealth input precision;
        -- threshold equality still needs target-client acceptance.
        local _, exponent = math.frexp(boundary)
        local above = boundary + math.ldexp(1, exponent - 24)
        value:AddPoint(0, 1)
        value:AddPoint(boundary, 1)
        value:AddPoint(above, 0)
        value:AddPoint(1, 0)
        -- Read back the ordinary stored point so the test does not assume
        -- Lua doubles and native point storage round this constant identically.
        local stored = value:GetPoint(3)
        local nativeAbove = stored and Number(stored.x)
        if not nativeAbove or nativeAbove <= boundary then return nil end
        -- Validate native interpolation using public constants only. No live
        -- health, derived alpha or secret value is inspected by this probe.
        for _, test in ipairs({{0, 1}, {boundary / 2, 1}, {boundary, 1}, {nativeAbove, 0}, {1, 0}}) do
            if Number(value:Evaluate(test[1])) ~= test[2] then return nil end
        end
        return value
    end)
    if not ok or not value then curve, curveThreshold = nil, nil; return false end
    curve, curveThreshold = value, threshold
    return true
end

local function ApplyHealthAlpha()
    if not reminder or not selectedKind or not Enabled("consumableReminder") then return end
    -- ReadBoolean rejects secret/unknown life state before Lua branches. This
    -- guard also handles a death health event before PLAYER_DEAD is dispatched.
    if ReadBoolean(UnitIsDeadOrGhost, "player") ~= false then
        HideReminder("Player dead or life state unknown; visual suppressed.")
        Notify()
        return
    end
    -- The live result exists only as an argument to its documented display
    -- sink. Never compare, format, convert, store, read back, or branch on it.
    local ok = pcall(function()
        reminder:SetAlpha(UnitHealthPercent("player", false, curve))
    end)
    if not ok then HideReminder("Native health display unavailable; visual suppressed.") else StartBounce() end
end

function Tools:Refresh(refreshInventory)
    -- Invalidate before visibility/life guards, without scanning hidden bags.
    if refreshInventory ~= false then inventory = nil end
    local previousItem, previousReason, previousRes = selectedItem, reminderReason, resReason
    if not Enabled("autoRes") then CancelRes(); resReason = "Off."
    elseif resReason == "Off." then resReason = "On. Combat/encounter offers stay manual; client confirmation pending." end
    if not Enabled("consumableReminder") then
        inventory = nil
        HideReminder("Off.")
    elseif not CombatAllowsReminder() then
        HideReminder("Hidden by combat setting.")
    elseif not ReminderAPIsAvailable() then
        HideReminder("Required Retail display APIs unavailable; reminder hidden.")
    elseif ReadBoolean(UnitIsDeadOrGhost, "player") ~= false then
        HideReminder("Player dead or life state unknown; visual suppressed.")
    elseif not BuildCurve(Threshold((Settings() or {}).healthThreshold)) then
        HideReminder("Native curve unavailable; reminder hidden.")
    else
        if not inventory then inventory = RA.HealingSupplies:Snapshot() end
        if inventory.itemID then
            CreateReminder()
            selectedItem, selectedKind = inventory.itemID, inventory.kind
            ApplyAppearance(reminder, reminderLabel, selectedKind)
            reminder.icon:Show(); reminder.border:Show()
            reminder.icon:SetTexture(inventory.icon)
            reminderReason = (selectedKind == "stone" and "Healthstone" or "Healing potion") .. " carried. Cooldown readiness isn't checked."
            reminder:Show()
            StartBounce()
            ApplyHealthAlpha()
        elseif inventory.stone == false and inventory.potion == false then
            CreateReminder()
            selectedItem, selectedKind = nil, "empty"
            ApplyAppearance(reminder, reminderLabel, selectedKind)
            reminder.icon:Hide(); reminder.border:Hide()
            reminderReason = "No supported healing item carried. Low-health visual: OUT OF POTIONS."
            reminder:Show()
            StartBounce()
            ApplyHealthAlpha()
        else
            HideReminder("Inventory unavailable or potion family unknown; reminder hidden.")
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
    if key ~= "autoRes" and key ~= "consumableReminder" and key ~= "healthThreshold"
        and key ~= "reminderStoneText" and key ~= "reminderPotionText" and key ~= "reminderIconSize" and key ~= "reminderTextSize" and key ~= "reminderCombat" then
        return false, "Unknown personal tool option."
    end
    if key == "healthThreshold" then
        if not Number(value) then return false, "Choose a numeric health threshold." end
        value = Threshold(value)
    elseif key == "reminderStoneText" or key == "reminderPotionText" then
        if type(value) ~= "string" then return false, "Enter reminder text." end
        value = RA:NormalizeReminderText(value)
    elseif key == "reminderIconSize" or key == "reminderTextSize" then
        local size = Number(value)
        if not size then return false, "Choose a numeric size." end
        local minimum, maximum = key == "reminderIconSize" and 24 or 8, key == "reminderIconSize" and 128 or 32
        value = math.floor(math.max(minimum, math.min(maximum, size)) + 0.5)
    elseif key == "reminderCombat" then
        if type(value) ~= "string" or not COMBAT_MODES[value] then return false, "Choose a combat visibility option." end
    elseif type(value) ~= "boolean" then return false, "Choose on or off." end
    if type(db.personalTools) ~= "table" then
        db.personalTools = { autoRes = false, consumableReminder = false, healthThreshold = DEFAULT_THRESHOLD }
    end
    db.personalTools[key] = value
    ApplyAppearance(reminder, reminderLabel, selectedKind)
    ApplyAppearance(preview, previewCaption, previewKind)
    self:Refresh(key == "consumableReminder")
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
    -- inventory query, health query, or timer. Its bounce uses the same visual
    -- animation as the live reminder, on an independent ordinary-alpha parent.
    preview = CreateFrame("Frame", "RCPArsenalConsumableReminderPreview", UIParent)
    preview:Hide()
    preview:SetAlpha(1)
    preview:SetSize(56, 56)
    preview:SetFrameStrata("DIALOG")
    preview:SetFrameLevel((RA.ConfigFrame and RA.ConfigFrame:GetFrameLevel() or 0) + 120)
    preview:SetMovable(true)
    preview:SetClampedToScreen(true)
    preview:EnableMouse(false)
    preview:RegisterForDrag("LeftButton")
    local body = CreateFrame("Frame", nil, preview)
    body:SetAllPoints()
    body:SetAlpha(1)
    body:EnableMouse(false)
    local border = body:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.95, 0.65, 0.20, 1)
    local icon = body:CreateTexture(nil, "ARTWORK")
    preview.icon = icon
    icon:SetPoint("TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3, 3)
    icon:SetTexture(GENERIC_POTION_ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    previewBounce = CreateBounce(body)
    preview.label = preview:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    preview.label:SetPoint("BOTTOM", preview, "TOP", 0, 5)
    local caption = body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    previewCaption = caption
    caption:SetPoint("TOP", body, "BOTTOM", 0, -4)
    ApplyAppearance(preview, caption)
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
        if previewBounce then previewBounce:Stop() end
        preview:StopMovingOrSizing()
        preview:Hide()
        preview:EnableMouse(false)
    end
    previewMoving, previewMode = false, nil
    return true
end

function Tools:PreviewReminder(kind)
    if kind == "stone" or kind == "potion" then previewKind = kind end
    if not Settings() then return false, "Profile unavailable." end
    self:StopReminderPreview()
    CreatePreview()
    PositionFrame(preview)
    ApplyAppearance(preview, previewCaption, previewKind)
    preview.icon:SetTexture(previewKind == "stone" and "Interface\\Icons\\INV_Stone_04" or GENERIC_POTION_ICON)
    previewMode = "PREVIEW"
    preview.label:SetText("BOUNCE PREVIEW - SAMPLE")
    preview:Show()
    previewBounce:Play()
    return true
end

function Tools:MoveReminder(kind)
    if ReadBoolean(InCombatLockdown) ~= false then return false, "Move this after combat." end
    local ok, reason = self:PreviewReminder(kind)
    if not ok then return false, reason end
    previewMode = "MOVE"
    previewBounce:Stop()
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
        reminderStoneText = ReminderText("stone"), reminderPotionText = ReminderText("potion"), reminderIconSize = IconSize(), reminderTextSize = TextSize(), reminderCombat = CombatMode(),
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
RA:RegisterEvent("ITEM_DATA_LOAD_RESULT", function(_, itemID, success)
    if Enabled("consumableReminder") and Number(itemID) and not IsSecret(success) and success == true
        and inventory and inventory.pending and inventory.pending[itemID] then Tools:Refresh() end
end)
for _, event in ipairs({ "BAG_UPDATE_DELAYED",
    "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_ALIVE",
    "PLAYER_DEAD", "PLAYER_UNGHOST" }) do
    RA:RegisterEvent(event, function(eventName)
        if eventName == "PLAYER_REGEN_DISABLED" then Tools:StopReminderPreview() end
        if Enabled("consumableReminder") then
            Tools:Refresh(eventName == "BAG_UPDATE_DELAYED" or eventName == "PLAYER_ENTERING_WORLD")
        end
    end)
end
for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH" }) do
    RA:RegisterEvent(event, function(_, unit)
        if Enabled("consumableReminder") and not IsSecret(unit) and unit == "player" then ApplyHealthAlpha() end
    end)
end
