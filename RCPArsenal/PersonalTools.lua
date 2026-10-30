local _, RA = ...

local Tools = {}
RA.PersonalTools = Tools

-- Independently authored from Blizzard's b9be9379 UI/API contracts and the
-- 2026-10-18 RCP feasibility report. EasyAutoAcceptRes b902c0d7 was a behavior
-- reference only; no implementation is incorporated here.
--
-- Incoming offers have no spell classification. The default policy checks all
-- combat contexts; the separate explicit opt-in skips that policy only.
-- The consumable visual is experimental until its native threshold boundary,
-- inventory, and raid restriction behavior are verified on the target client.
local GENERIC_POTION_ICON = "Interface\\Icons\\INV_Potion_51" -- Preview illustration only.
local DEFAULT_THRESHOLD = 40 -- Editable implementation default, not a user preference.
local DEFAULT_POSITION = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -140 }
local VALID_POINTS = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true,
    CENTER = true, RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true }

local reminder, bounce, curve, curveThreshold, glowCurve35, resTimer
local resGeneration = 0
local layoutMasked, reminderDesiredShown = false, false
local reminderEvents, resurrectionEvent = {}, nil
local readinessTimer, readinessGeneration, lastExpiry = nil, 0, nil
local reminderLabel, previewCaption
local UpdateSampleGlow
local COMBAT_MODES = { BOTH = true, IN_COMBAT = true, OUT_OF_COMBAT = true }
local preview, previewMode, previewMoving, previewBounce
local selectedItem, selectedKind, inventory, bouncing
local soundSupplyReady = false
local previewKind = "stone"
local reminderReason = "Off."
local resReason = "Off."
local function IsItemIcon(kind) return kind == "stone" or kind == "potion" end

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

local function EmptyTextSize()
    return math.floor(math.max(16, math.min(96, Number((Settings() or {}).reminderEmptyTextSize) or 48)) + 0.5)
end

local function ReminderText(kind)
    if kind == "empty" then return "OUT OF POTIONS!" end
    local settings = Settings() or {}
    local text = settings[kind == "stone" and "reminderStoneText" or "reminderPotionText"]
    if type(text) ~= "string" or IsSecret(text) then text = settings.reminderText end
    if type(text) ~= "string" or IsSecret(text) then text = kind == "stone" and "Use Healthstone" or "Use healing potion" end
    return RA:NormalizeReminderText(text)
end

local function SoundEnabled()
    local value = (Settings() or {}).reminderSound
    return value == nil or (not IsSecret(value) and value == true)
end

local function SoundSelection()
    local settings = Settings() or {}
    local sounds = RA.ReminderSounds
    return sounds and sounds:NormalizeID(settings.reminderSoundChoice) or "sound_6",
        sounds and sounds:NormalizeChannel(settings.reminderSoundChannel) or "Master"
end

local function CombatMode()
    local mode = (Settings() or {}).reminderCombat
    return COMBAT_MODES[mode] and mode or "IN_COMBAT"
end

local function CombatAllowsReminder()
    local mode = CombatMode()
    if mode == "BOTH" then return true end
    local combat = ReadBoolean(InCombatLockdown)
    return combat ~= nil and (combat == (mode == "IN_COMBAT"))
end

local function Metric(object, method)
    if not object then return nil end
    local ok, value = pcall(function() return object[method](object) end)
    return ok and Number(value) or nil
end
local function GlowExtent(kind)
    if not IsItemIcon(kind) or (Settings() or {}).reminderStoneGlow == false then return 0 end
    return RA.ReminderGlow:GetExtent(RA:NormalizeReminderGlow((Settings() or {}).reminderGlow),IconSize())
end
local function FitAndClamp(frame, label, kind, requestedSize)
    if not label then return end
    local width = Metric(label, "GetStringWidth")
    local height = Metric(label, "GetStringHeight")
    if not width or width <= 0 then width = kind == "empty" and (#"OUT OF POTIONS!" + 1) * requestedSize or math.max(260, IconSize()) end
    if not height or height <= 0 then height = requestedSize * 1.2 end
    if kind == "empty" then
        local screenW, screenH = Metric(UIParent, "GetWidth"), Metric(UIParent, "GetHeight")
        local parentScale, frameScale = Metric(UIParent, "GetEffectiveScale"), Metric(frame, "GetEffectiveScale")
        local ratio = parentScale and parentScale > 0 and frameScale and frameScale > 0 and frameScale / parentScale or 1
        if screenW and screenH and screenW > 32 and screenH > IconSize() + 32 then
            local availableW, availableH = screenW / ratio - 16, screenH / ratio - IconSize() - 32
            local fit = math.min(1, availableW / (width + 2), availableH / (height + 2))
            if fit > 0 and fit < 1 then
                local size = math.max(6, math.floor(requestedSize * fit))
                -- The shared font helper rounds to whole units (minimum 6).
                -- Measure the applied font, never scaled pre-fit metrics. A
                -- bounded decrement handles native glyph rounding as well.
                for attempt = 1, 96 do
                    if RA.ApplyFont then RA:ApplyFont(label, size, "REGULAR", false)
                    elseif label.SetTextHeight then label:SetTextHeight(size) end
                    width, height = Metric(label, "GetStringWidth"), Metric(label, "GetStringHeight")
                    if not width or width <= 0 then width = (#"OUT OF POTIONS!" + 1) * size end
                    if not height or height <= 0 then height = size * 1.2 end
                    if (width + 2 <= availableW and height + 2 <= availableH) or size <= 6 then break end
                    size = size - 1
                end
            end
        end
        width, height = width + 2, height + 2
        if label.SetWidth then label:SetWidth(width) end
    end
    local itemIcon = IsItemIcon(kind)
    local clamped = kind == "empty" or itemIcon or frame.isPreview == true
    if frame.SetClampedToScreen then pcall(frame.SetClampedToScreen, frame, clamped) end
    if frame.SetClampRectInsets then
        local extent = GlowExtent(kind)
        local side = clamped and math.max(itemIcon and extent or 0, (width - IconSize()) / 2) or 0
        local headingHeight=Metric(frame.label,"GetStringHeight")
        if not headingHeight or headingHeight<=0 then headingHeight=12 end
        local heading = frame.isPreview and itemIcon and (headingHeight+5) or 0
        local top = clamped and math.max(frame.isPreview and 20 or 7, itemIcon and extent+7+heading or 7) or 0
        local bottom = clamped and -(4 + extent + height + 7) or 0
        -- Native offset signs match Blizzard EditMode's selection-bound clamp.
        -- Include the entire caption and +/-7 animation, without saving a move.
        pcall(frame.SetClampRectInsets, frame, -side, side, top, bottom)
    end
end

local function ApplyAppearance(frame, label, kind)
    if not frame then return end
    frame:SetSize(IconSize(), IconSize())
    if label then
        local extent=GlowExtent(kind)
        label:ClearAllPoints()
        label:SetPoint("TOP",frame.body or frame,"BOTTOM",0,-4-extent)
        if frame.isPreview and frame.label then
            frame.label:ClearAllPoints()
            frame.label:SetPoint("BOTTOM",frame,"TOP",0,IsItemIcon(kind) and extent+7+5 or 5)
        end
        local size = kind == "empty" and EmptyTextSize() or TextSize()
        if RA.ApplyFont then RA:ApplyFont(label, size, "REGULAR", false)
        elseif label.SetTextHeight then label:SetTextHeight(size) end
        -- Fixed empty-warning text gets a full-em-per-character width, rather
        -- than the ordinary caption's narrow wrapping box. Same icon anchor.
        if label.SetWidth then label:SetWidth(kind == "empty" and (#"OUT OF POTIONS!" + 1) * size or math.max(260, IconSize())) end
        if label.SetWordWrap then label:SetWordWrap(kind ~= "empty") end
        local text = ReminderText(kind):gsub("|", "||") -- Literal text, never links/textures/commands.
        if RA.SetVisualText then RA:SetVisualText(label, text) else label:SetText(text) end
        FitAndClamp(frame, label, kind, size)
    end
end

local function Enabled(key)
    local settings = Settings()
    return settings and settings[key] == true
end

local function SyncEventDemand()
    local enabled = Enabled("consumableReminder") == true
    if RA.HealingSupplies and RA.HealingSupplies.SetConsumer then RA.HealingSupplies:SetConsumer("reminder",enabled) end
    for _, subscription in ipairs(reminderEvents) do subscription:SetEnabled(enabled) end
    if resurrectionEvent then resurrectionEvent:SetEnabled(Enabled("autoRes") == true) end
end

local function Notify(option)
    RA:FireCallback("PERSONAL_TOOLS_CHANGED", option)
end

local function CancelRes()
    resGeneration = resGeneration + 1
    local timer = resTimer
    resTimer = nil
    if timer then pcall(function() timer:Cancel() end) end
end
local function RefreshResurrection()
    if resurrectionEvent then resurrectionEvent:SetEnabled(Enabled("autoRes") == true) end
    resReason = Enabled("autoRes") and "On. Waiting for a future offer; client confirmation pending." or "Off."
end

local function CancelReadiness()
    readinessGeneration = readinessGeneration + 1
    local timer = readinessTimer
    readinessTimer = nil
    if timer then pcall(function() timer:Cancel() end) end
end

local function HideGlow()
    if reminder and reminder.glow then
        if reminder.glow.renderer then reminder.glow.renderer:Stop() end
        pcall(reminder.glow.SetAlpha, reminder.glow, 0)
        pcall(reminder.glow.Hide, reminder.glow)
    end
end

local function HideReminder(reason)
    reminderDesiredShown = false
    selectedItem, selectedKind = nil, nil
    reminderReason = reason
    HideGlow()
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
    ApplyAppearance(reminder, reminderLabel, selectedKind)
    ApplyAppearance(preview, previewCaption, previewKind)
end

local function CreateStoneGlow(body)
    local glow = CreateFrame("Frame", nil, body)
    glow:Hide(); glow:SetAllPoints(body); glow:EnableMouse(false); glow:SetAlpha(0)
    glow.renderer = RA.ReminderGlow:Create(glow)
    return glow
end

local function PrepareGlowAppearance()
    if reminder and reminder.glow and Enabled("consumableReminder") and IsItemIcon(selectedKind)
        and (Settings() or {}).reminderStoneGlow ~= false then
        reminder.glow.renderer:Configure(RA:NormalizeReminderGlow((Settings() or {}).reminderGlow), IconSize())
    end
end

UpdateSampleGlow = function()
    if not preview or not preview.glow then return end
    if previewMode and IsItemIcon(previewKind) and (Settings() or {}).reminderStoneGlow ~= false then
        preview.glow:Configure(RA:NormalizeReminderGlow((Settings() or {}).reminderGlow), IconSize())
        preview.glow:Start()
    else preview.glow:Stop() end
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
    reminder.body = child
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
    local glowOK, glow = pcall(CreateStoneGlow, child)
    reminder.glow = glowOK and glow or nil
    bounce = CreateBounce(child)
    reminder:SetScript("OnShow", function()
        if selectedKind and Enabled("consumableReminder") then StartBounce() end
    end)
    PositionReminder()
end

local function CreateHealthCurve(threshold)
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
    return ok and value or nil
end

local function BuildCurve(threshold)
    if curve and curveThreshold == threshold then return true end
    local value = CreateHealthCurve(threshold)
    if not value then curve, curveThreshold = nil, nil; return false end
    curve, curveThreshold = value, threshold
    return true
end

local function PrepareGlowCurve()
    if Enabled("consumableReminder") and IsItemIcon(selectedKind) and reminder and reminder.glow
        and (Settings() or {}).reminderStoneGlow ~= false and not glowCurve35 then glowCurve35 = CreateHealthCurve(35) end
end

local function ApplyHealthAlpha()
    if not reminder or not selectedKind or not Enabled("consumableReminder") then return end
    -- ReadBoolean rejects secret/unknown life state before Lua branches. This
    -- guard also handles a death health event before PLAYER_DEAD is dispatched.
    if ReadBoolean(UnitIsDeadOrGhost, "player") ~= false then
        CancelReadiness()
        HideReminder("Player dead or life state unknown; visual suppressed.")
        Notify()
        return
    end
    -- The live result exists only as an argument to its documented display
    -- sink. Never compare, format, convert, store, read back, or branch on it.
    -- Match native health bars' default predicted-health path. Opting out can
    -- lag their displayed health; prediction and the curve stay in-engine.
    local ok = pcall(function()
        reminder:SetAlpha(UnitHealthPercent("player", true, curve))
    end)
    if not ok then
        CancelReadiness(); HideReminder("Native health display unavailable; visual suppressed."); return
    end
    if IsItemIcon(selectedKind) and reminder.glow and (Settings() or {}).reminderStoneGlow ~= false and not layoutMasked then
        local glowOK = glowCurve35 and pcall(function()
            reminder.glow:SetAlpha(UnitHealthPercent("player", true, glowCurve35))
            reminder.glow:Show()
            reminder.glow.renderer:Start()
        end)
        if not glowOK then HideGlow() end
    else HideGlow() end
    StartBounce()
end

local function ItemReadiness(candidate, now)
    if not now or not C_Item or type(C_Item.GetItemCooldown) ~= "function" or type(C_Item.IsUsableItem) ~= "function" then return "unknown" end
    local ok, start, duration, enabled, usable, noMana = pcall(function()
        local start, duration, enabled = C_Item.GetItemCooldown(candidate.id)
        local usable, noMana = C_Item.IsUsableItem(candidate.id)
        return start, duration, enabled, usable, noMana
    end)
    if not ok or IsSecret(enabled) or IsSecret(usable) or IsSecret(noMana)
        or type(enabled) ~= "boolean" or type(usable) ~= "boolean" or type(noMana) ~= "boolean" then return "unknown" end
    start, duration = Number(start), Number(duration)
    if not start or not duration or start < 0 or duration < 0 then return "unknown" end
    local deadline = Number(start + duration)
    if not deadline or not enabled then return "unknown" end
    if duration > 0 and deadline > now then return "cooldown", deadline end
    if usable == true and noMana == false then return "ready" end
    return "unusable"
end

local function SelectCarried(snapshot)
    local now
    if type(GetTime) == "function" then local ok, value = pcall(GetTime); if ok then now = Number(value) end end
    if now and now < 0 then now = nil end
    local selected, earliest, states = nil, nil, {}
    for index, candidate in ipairs(snapshot.candidates or {}) do
        local state, deadline = ItemReadiness(candidate, now)
        states[index] = state
        if state == "ready" and not selected then selected = candidate end
        if deadline and (not earliest or deadline < earliest) then earliest = deadline end
    end
    if selected then return selected, "ready", earliest, now end
    if Enabled("reminderShowOnCooldown") and snapshot.candidates and snapshot.candidates[1] then
        return snapshot.candidates[1], states[1] or "unknown", earliest, now
    end
    return nil, "unavailable", earliest, now
end

local function ScheduleExpiry(deadline, now, snapshot)
    if not deadline or not now or deadline <= now or (lastExpiry and deadline <= lastExpiry)
        or not C_Timer or type(C_Timer.NewTimer) ~= "function" then return end
    local delay = Number(deadline - now + 0.05)
    if not delay or delay <= 0 then return end
    local generation = readinessGeneration
    local ownedTimer
    local ok, timer = pcall(C_Timer.NewTimer, delay, function()
        if readinessTimer == ownedTimer then readinessTimer = nil end
        if generation ~= readinessGeneration or inventory ~= snapshot or not Enabled("consumableReminder") then return end
        lastExpiry = deadline
        -- Only cached candidates are reconciled. Display still uses the same
        -- direct opaque native-alpha sink; no Lua health decision or audio.
        Tools:Refresh(false)
    end)
    if ok then ownedTimer, readinessTimer = timer, timer end
end

function Tools:Refresh(refreshInventory)
    SyncEventDemand()
    CancelReadiness()
    -- Invalidate before visibility/life guards, without scanning hidden bags.
    if refreshInventory ~= false then
        inventory, lastExpiry = nil, nil
        if RA.HealingSupplies and RA.HealingSupplies.InvalidateCache then RA.HealingSupplies:InvalidateCache() end
    end
    local previousItem, previousReason, previousRes = selectedItem, reminderReason, resReason
    local previousSoundReady = soundSupplyReady
    soundSupplyReady = false
    if not Enabled("autoRes") then CancelRes(); resReason = "Off."
    elseif resReason == "Off." then RefreshResurrection() end
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
        if not inventory then
            inventory = RA.HealingSupplies.GetCached and RA.HealingSupplies:GetCached("reminder") or RA.HealingSupplies:Snapshot()
        end
        local candidate, readiness, deadline, now = SelectCarried(inventory)
        -- SelectCarried prefers any positively ready candidate before its
        -- optional cooldown/unknown visual fallback. Audio never uses that
        -- fallback or queries inventory from a health/native-warning hook.
        soundSupplyReady = readiness == "ready"
        ScheduleExpiry(deadline, now, inventory)
        if candidate then
            CreateReminder()
            selectedItem, selectedKind = candidate.id, candidate.kind
            PrepareGlowCurve()
            ApplyAppearance(reminder, reminderLabel, selectedKind)
            PrepareGlowAppearance()
            PositionFrame(reminder)
            reminder.icon:Show(); reminder.border:Show()
            reminder.icon:SetTexture(candidate.icon)
            local label = selectedKind == "stone" and "Healthstone" or "Healing potion"
            reminderReason = label .. (readiness == "ready" and " ready (carried)." or readiness == "cooldown" and " carried; on cooldown." or " carried; readiness not confirmed.")
            reminderDesiredShown = true
            if not layoutMasked then reminder:Show() end
            StartBounce()
            ApplyHealthAlpha()
        elseif inventory.stone == false and inventory.potion == false then
            CreateReminder()
            selectedItem, selectedKind = nil, "empty"
            ApplyAppearance(reminder, reminderLabel, selectedKind)
            PositionFrame(reminder)
            reminder.icon:Hide(); reminder.border:Hide()
            reminderReason = "No supported healing item carried. Low-health visual: OUT OF POTIONS!"
            reminderDesiredShown = true
            if not layoutMasked then reminder:Show() end
            StartBounce()
            ApplyHealthAlpha()
        elseif inventory.stone == true or inventory.potion == true then
            HideReminder("Healing supplies carried; no known-ready item. Prompt hidden.")
        else
            HideReminder("Inventory unavailable or potion family unknown; reminder hidden.")
        end
    end
    if previousSoundReady ~= soundSupplyReady then Notify("reminderSupply") end
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

local function HardcoreAllowsResurrection()
    local rules = C_GameRules
    if IsSecret(rules) or type(rules) ~= "table" then return false end
    local ok, predicate = pcall(function() return rules.IsHardcoreActive end)
    if not ok or IsSecret(predicate) then return false end
    if predicate ~= nil then return ReadBoolean(predicate) == false end
    -- Mainline's optional predicate may be absent (UI source 15881d522c44).
    -- Only positively identified Retail may omit it; nil == nil is no gate.
    local project, mainline = Number(WOW_PROJECT_ID), Number(WOW_PROJECT_MAINLINE)
    return project ~= nil and mainline ~= nil and project > 0
        and project == math.floor(project) and project == mainline
end

local function OfferIsReady()
    if type(issecretvalue) ~= "function" or type(AcceptResurrect) ~= "function"
        or type(ResurrectGetOfferer) ~= "function" then return false end
    if not HardcoreAllowsResurrection() or ReadBoolean(UnitIsDeadOrGhost, "player") ~= true then return false end
    local ok, offer = pcall(ResurrectGetOfferer)
    if not ok or IsSecret(offer) or type(offer) ~= "string" or offer == "" then return false end
    -- Sickness takes precedence in Blizzard's dialog selection. Neither flag
    -- classifies the spell. No-timer offers do not use corpse recovery delay.
    local sickness = ReadBoolean(ResurrectHasSickness)
    if sickness == nil then return false end
    local timed = sickness or ReadBoolean(ResurrectHasTimer)
    if timed == nil then return false end
    if timed then
        if type(GetCorpseRecoveryDelay) ~= "function" then return false end
        local valid, delay = pcall(GetCorpseRecoveryDelay)
        if not valid or Number(delay) ~= 0 then return false end
    end
    return true
end
local function RequestNormalRes()
    CancelRes()
    if not Enabled("autoRes") then return end
    if not Enabled("autoResInCombat") and not NormalResIsSafe() then
        resReason = "Offer left manual: combat, encounter, or group state is active or unknown."
        Notify(); return
    end
    if not C_Timer or type(C_Timer.NewTimer) ~= "function" then
        resReason = "Offer left manual: resurrection timer unavailable."
        Notify(); return
    end
    local generation = resGeneration
    local ok, timer = pcall(C_Timer.NewTimer, 0, function()
        -- Ownership and settings precede all writes. A forced cancelled callback
        -- cannot clear a newer timer or publish delayed status.
        if generation ~= resGeneration or not Enabled("autoRes") then return end
        CancelRes() -- consume once, including guard failures and throwing calls
        if not Enabled("autoResInCombat") and not NormalResIsSafe() then
            resReason = "Offer left manual: combat, encounter, or group state changed."
        elseif not OfferIsReady() then
            resReason = "Offer left manual: offer, game rules, life state, or recovery delay unavailable."
        elseif pcall(AcceptResurrect) then
            resReason = "Resurrection acceptance requested; client confirmation pending."
        else
            resReason = "Offer left manual: acceptance unavailable."
        end
        -- Blizzard owns popup dismissal. A non-throwing request is not proof of
        -- acceptance; preserve its manual controls if the client rejects it.
        Notify()
    end)
    if ok then resTimer = timer
    else resReason = "Offer left manual: resurrection timer unavailable."; Notify() end
end

function Tools:SetOption(key, value)
    local db = RA:GetDB()
    if not db then return false, "Profile unavailable." end
    if IsSecret(key) or IsSecret(value) then return false, "Invalid personal tool option." end
    if key ~= "autoRes" and key ~= "autoResInCombat" and key ~= "consumableReminder" and key ~= "healthThreshold"
        and key ~= "reminderStoneText" and key ~= "reminderPotionText" and key ~= "reminderIconSize" and key ~= "reminderTextSize" and key ~= "reminderEmptyTextSize" and key ~= "reminderCombat" and key ~= "reminderSound" and key ~= "reminderSoundChoice" and key ~= "reminderSoundChannel" and key ~= "reminderShowOnCooldown" and key ~= "reminderSoundWhenEffectsMuted" and key ~= "reminderStoneGlow" and key ~= "reminderGlow" then
        return false, "Unknown personal tool option."
    end
    if key == "reminderGlow" then
        if type(value) ~= "table" then return false, "Choose glow appearance settings." end
        value = RA:NormalizeReminderGlow(value)
    elseif key == "healthThreshold" then
        if not Number(value) then return false, "Choose a numeric health threshold." end
        value = Threshold(value)
    elseif key == "reminderStoneText" or key == "reminderPotionText" then
        if type(value) ~= "string" then return false, "Enter reminder text." end
        value = RA:NormalizeReminderText(value)
    elseif key == "reminderIconSize" or key == "reminderTextSize" or key == "reminderEmptyTextSize" then
        local size = Number(value)
        if not size then return false, "Choose a numeric size." end
        local minimum = key == "reminderIconSize" and 24 or key == "reminderEmptyTextSize" and 16 or 8
        local maximum = key == "reminderIconSize" and 128 or key == "reminderEmptyTextSize" and 96 or 32
        value = math.floor(math.max(minimum, math.min(maximum, size)) + 0.5)
    elseif key == "reminderCombat" then
        if type(value) ~= "string" or not COMBAT_MODES[value] then return false, "Choose a combat visibility option." end
    elseif key == "reminderSoundChoice" then
        if not RA.ReminderSounds or not RA.ReminderSounds:Get(value) then return false, "Choose a listed sound." end
    elseif key == "reminderSoundChannel" then
        if type(value) ~= "string" or (value ~= "SFX" and value ~= "Master") then return false, "Choose Sound Effects or Master." end
    elseif type(value) ~= "boolean" then return false, "Choose on or off." end
    if type(db.personalTools) ~= "table" then
        db.personalTools = { autoRes = false, consumableReminder = false, healthThreshold = DEFAULT_THRESHOLD }
    end
    if key == "autoRes" or key == "autoResInCombat" then
        if db.personalTools[key] ~= value then
            CancelRes()
            db.personalTools[key] = value
            RefreshResurrection()
            Notify(key)
        end
        return true
    end
    db.personalTools[key] = value
    -- Audio preferences do not refresh inventory, visuals or health.
    if key == "reminderSound" or key == "reminderSoundChoice" or key == "reminderSoundChannel" or key == "reminderSoundWhenEffectsMuted" then Notify(key); return true end
    if key == "reminderStoneGlow" or key == "reminderGlow" then
        ApplyAppearance(reminder, reminderLabel, selectedKind)
        ApplyAppearance(preview, previewCaption, previewKind)
        -- Only the owned visual changes. Preserve the supply cache/expiry and
        -- audio latch; OFF tools stay unallocated and health hooks never retry.
        if (Settings() or {}).reminderStoneGlow ~= false then
            PrepareGlowCurve(); PrepareGlowAppearance(); ApplyHealthAlpha()
        else HideGlow() end
        UpdateSampleGlow()
        Notify(key)
        return true
    end
    ApplyAppearance(reminder, reminderLabel, selectedKind)
    ApplyAppearance(preview, previewCaption, previewKind)
    UpdateSampleGlow()
    self:Refresh(key == "consumableReminder")
    Notify(key)
    return true
end

function Tools:SetGlowOption(key, value)
    local appearance = RA:NormalizeReminderGlow((Settings() or {}).reminderGlow)
    if IsSecret(key) or IsSecret(value) or type(key) ~= "string" or appearance[key] == nil then return false, "Unknown glow setting." end
    if key == "style" then
        if type(value) ~= "string" or not ({STEADY=true,PIXEL=true,BUTTON=true,AUTOCAST=true})[value] then return false, "Choose a glow style." end
    elseif key == "color" then
        if type(value) ~= "table" then return false, "Choose a glow color." end
        for index=1,3 do if not Number(value[index]) then return false, "Choose a glow color." end end
    elseif not Number(value) then return false, "Choose a numeric glow setting." end
    appearance[key] = value
    return self:SetOption("reminderGlow", appearance)
end

function Tools:ResetGlowSettings()
    Notify("reminderGlowReset")
    return self:SetOption("reminderGlow", {})
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
    RA:FireCallback("OVERLAY_POSITION_CHANGED")
    return true
end

function Tools:ResetReminderPosition()
    local settings = Settings()
    if not settings then return false, "Profile unavailable." end
    settings.reminderPosition = nil
    PositionReminder()
    Notify()
    RA:FireCallback("OVERLAY_POSITION_CHANGED")
    return true
end

function Tools:RefreshReminderPosition()
    PositionReminder()
    return true
end
function Tools:SetLayoutMasked(masked)
    layoutMasked = masked == true
    if reminder then reminder:SetShown(not layoutMasked and reminderDesiredShown) end
    if layoutMasked then HideGlow() else ApplyHealthAlpha() end
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
    preview.isPreview = true
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
    preview.body = body
    body:SetAllPoints()
    body:SetAlpha(1)
    body:EnableMouse(false)
    local border = body:CreateTexture(nil, "BACKGROUND")
    preview.border = border
    border:SetAllPoints()
    border:SetColorTexture(0.05, 0.04, 0.06, 0.94) -- Match the live backing; glow supplies the gold.
    local icon = body:CreateTexture(nil, "ARTWORK")
    preview.icon = icon
    icon:SetPoint("TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3, 3)
    icon:SetTexture(GENERIC_POTION_ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    preview.glow = RA.ReminderGlow:Create(body)
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
        if preview.glow then preview.glow:Stop() end
        preview:StopMovingOrSizing()
        preview:Hide()
        preview:EnableMouse(false)
    end
    previewMoving, previewMode = false, nil
    return true
end

function Tools:PreviewReminder(kind)
    if kind == "stone" or kind == "potion" or kind == "empty" then previewKind = kind end
    if not Settings() then return false, "Profile unavailable." end
    self:StopReminderPreview()
    CreatePreview()
    PositionFrame(preview)
    ApplyAppearance(preview, previewCaption, previewKind)
    PositionFrame(preview)
    if previewKind == "empty" then preview.icon:Hide(); preview.border:Hide()
    else preview.icon:Show(); preview.border:Show() end
    preview.icon:SetTexture(previewKind == "stone" and "Interface\\Icons\\INV_Stone_04" or GENERIC_POTION_ICON)
    previewMode = "PREVIEW"
    preview.label:SetText("BOUNCE PREVIEW - SAMPLE")
    preview:Show()
    previewBounce:Play()
    UpdateSampleGlow()
    return true
end

function Tools:MoveReminder(kind)
    if ReadBoolean(InCombatLockdown) ~= false then return false, "Move this after combat." end
    local ok, reason = self:PreviewReminder(kind)
    if not ok then return false, reason end
    previewMode = "MOVE"
    preview.border:Show() -- Existing sample anchor remains draggable even for text-only setup.
    previewBounce:Stop()
    preview.label:SetText("DRAG TO MOVE - SAMPLE")
    preview:EnableMouse(true)
    return true
end

function Tools:IsNativeSoundOptedIn()
    return Enabled("consumableReminder") == true and SoundEnabled()
end

function Tools:GetNativeSoundEligibility()
    if not Enabled("consumableReminder") then return false, "Reminder is off." end
    if not SoundEnabled() then return false, "Sound is off." end
    if not CombatAllowsReminder() then return false, "Hidden by combat setting." end
    if ReadBoolean(UnitIsDeadOrGhost, "player") ~= false then return false, "Player dead or life state unknown." end
    if not soundSupplyReady then return false, "No known-ready healing item carried." end
    return true
end

function Tools:PreviewReminderSound()
    if not RA.NativeWarningAudio then return false, "Native game sound unavailable." end
    return RA.NativeWarningAudio:Preview()
end

function Tools:GetStatusText(key)
    if key == "autoRes" then return resReason end
    if key == "consumableReminder" then return reminderReason end
    return "Auto resurrection: " .. resReason .. " Reminder: " .. reminderReason
end

function Tools:GetState()
    local soundChoice, soundChannel = SoundSelection()
    return { autoRes = Enabled("autoRes") == true, autoResInCombat = Enabled("autoResInCombat") == true, consumableReminder = Enabled("consumableReminder") == true,
        reminderStoneGlow = (Settings() or {}).reminderStoneGlow ~= false,
        reminderGlow = RA:NormalizeReminderGlow((Settings() or {}).reminderGlow),
        reminderSoundWhenEffectsMuted = Enabled("reminderSoundWhenEffectsMuted") == true, reminderShowOnCooldown = Enabled("reminderShowOnCooldown") == true, reminderSound = SoundEnabled(), reminderSoundChoice = soundChoice, reminderSoundChannel = soundChannel, healthThreshold = Threshold((Settings() or {}).healthThreshold), itemID = selectedItem,
        reminderStoneText = ReminderText("stone"), reminderPotionText = ReminderText("potion"), reminderIconSize = IconSize(), reminderTextSize = TextSize(), reminderEmptyTextSize = EmptyTextSize(), reminderCombat = CombatMode(),
        reminderStatus = reminderReason, autoResStatus = resReason, previewMode = previewMode }
end

-- For the report's synthetic boundary probe only; contains ordinary points,
-- never sampled health or alpha. A Lua mock does not certify native equality.
function Tools:GetReminderCurveForValidation()
    return curve
end

RA:RegisterInitializer(function() Tools:Refresh() end)
RA:RegisterCallback("PROFILE_RESET", function()
    CancelRes(); RefreshResurrection(); Tools:StopReminderPreview(); Tools:Refresh(); PositionReminder()
end)
RA:RegisterCallback("PROFILE_IMPORTED", function() CancelRes(); RefreshResurrection() end)
resurrectionEvent = RA:RegisterOptionalEvent("RESURRECT_REQUEST", RequestNormalRes)
local function ReminderEvent(event, callback, unit)
    reminderEvents[#reminderEvents + 1] = RA:RegisterOptionalEvent(event, callback, unit)
end
ReminderEvent("ITEM_DATA_LOAD_RESULT", function(_, itemID, success)
    if Enabled("consumableReminder") and Number(itemID) and not IsSecret(success) and success == true
        and inventory and inventory.pending and inventory.pending[itemID] then Tools:Refresh() end
end)
for _, event in ipairs({ "BAG_UPDATE_DELAYED",
    "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_ALIVE",
    "PLAYER_DEAD", "PLAYER_UNGHOST" }) do
    ReminderEvent(event, function(eventName)
        if Enabled("consumableReminder") then
            Tools:Refresh(eventName == "BAG_UPDATE_DELAYED" or eventName == "PLAYER_ENTERING_WORLD")
        end
    end)
end
-- Signals only: payloads are ignored. No bag enumeration on these events.
for _, event in ipairs({"BAG_UPDATE_COOLDOWN", "ACTION_USABLE_CHANGED", "SPELL_UPDATE_USABLE", "PLAYER_LEVEL_UP"}) do
    ReminderEvent(event, function()
        if Enabled("consumableReminder") then Tools:Refresh(false) end
    end)
end
for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH" }) do
    ReminderEvent(event, function(_, unit)
        if Enabled("consumableReminder") and not IsSecret(unit) and unit == "player" then ApplyHealthAlpha() end
    end, "player")
end
RA:RegisterEvent("PLAYER_REGEN_DISABLED", function() Tools:StopReminderPreview() end)

-- Public viewport changes only: no health, readiness or bag work.
for _, event in ipairs({"DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED"}) do
    RA:RegisterEvent(event, PositionReminder)
end
