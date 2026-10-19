-- Offline Lua 5.1 harness: no WoW, native secret enforcement, taint, or raid claim.
local checks = 0
local function check(value, message) checks = checks + 1; assert(value, message) end
local secret = setmetatable({}, {
    __add = function() error("secret arithmetic") end, __sub = function() error("secret arithmetic") end,
    __div = function() error("secret arithmetic") end, __lt = function() error("secret comparison") end,
    __le = function() error("secret comparison") end, __tostring = function() error("secret conversion") end,
})
local frames, timers, tickers, events, callbacks, initializers, items
local healthCalls, itemCalls, scans, accepted, hidden, notices, now
local combat, encounter, raid, grouped, groupCount, groupCombat, exists
local dead, petExistsUnknown, petCombatUnknown
local offer, recovery, healthResult, healthError, itemError
local profile, RA

function issecretvalue(value) return rawequal(value, secret) end
UIParent = { GetEffectiveScale = function() return 0.8 end,
    GetWidth = function() return 1920 end, GetHeight = function() return 1080 end }
Enum = { LuaCurveType = { Step = 1 } }
function InCombatLockdown() return combat end
function IsEncounterInProgress() return encounter end
function IsInRaid() return raid end
function IsInGroup() return grouped end
function GetNumGroupMembers() return groupCount end
function UnitExists(unit)
    scans = scans + 1
    if unit == "pet" and petExistsUnknown then return nil end
    local value = exists[unit]
    if value == nil then return false end
    return value
end
function UnitAffectingCombat(unit)
    if unit == "pet" and petCombatUnknown then return nil end
    return groupCombat[unit] or false
end
function UnitIsDeadOrGhost(unit) check(unit == "player", "Life-state guard must use fixed player token"); return dead end
function ResurrectGetOfferer() return offer end
function GetCorpseRecoveryDelay() return recovery end
function AcceptResurrect() accepted = accepted + 1 end
function StaticPopup_Hide(name) hidden[#hidden + 1] = name end
function GetTime() return now end
function UnitHealth() error("Raw health must not be used") end
function UnitHealthMax() error("Maximum health must not be used") end
function UnitIsUnit() error("Identity comparisons must not be used") end
function UnitGUID() error("Identity queries must not be used") end
function UnitName() error("Identity queries must not be used") end
function UnitHealthPercent(unit, predicted, curve)
    check(unit == "player" and predicted == false and curve ~= nil, "Native curve arguments wrong")
    healthCalls = healthCalls + 1
    if healthError then error("Native health display unavailable") end
    return healthResult
end
for _, name in ipairs({ "UseItemByName", "UseInventoryItem", "CastSpellByName", "SetBinding", "SetBindingClick",
    "SaveBindings", "SetOverrideBinding", "SetOverrideBindingClick", "ClearOverrideBindings" }) do
    _G[name] = function() error("No item, spell, or binding action is allowed") end
end
local function timer(list, delay, fn)
    local handle = { delay = delay, callback = fn, cancelled = false }
    function handle:Cancel() self.cancelled = true end
    list[#list + 1] = handle
    return handle
end
C_Timer = {
    NewTimer = function(delay, fn) return timer(timers, delay, fn) end,
    NewTicker = function(delay, fn) return timer(tickers, delay, fn) end,
}
C_CurveUtil = { CreateCurve = function()
    local object = { points = {} }
    function object:SetType(value) self.kind = value end
    function object:AddPoint(x, y)
        check(type(x) == "number" and type(y) == "number", "Curve points must be ordinary constants")
        self.points[#self.points + 1] = { x, y }
    end
    return object
end }
C_Item = {
    GetItemCount = function(id, bank, uses, reagentBank, accountBank)
        check(bank == false and uses == true and reagentBank == false and accountBank == false,
            "Possession must count bag uses and exclude every bank")
        itemCalls = itemCalls + 1
        if itemError then error("Item APIs unavailable") end
        return items[id] and items[id].count or 0
    end,
    IsUsableItem = function(id)
        local item = items[id] or {}
        return item.usable, item.noMana
    end,
    GetItemCooldown = function(id)
        local item = items[id] or {}
        return item.start, item.duration, item.enabled
    end,
    GetItemIconByID = function(id) return items[id] and items[id].icon end,
}
function CreateFrame(kind, name, parent, template)
    check(kind == "Frame" and template == nil, "Visual must be nonsecure and noninteractive")
    local frame = { name = name, parent = parent, shown = true, scripts = {} }
    local sample = name == "RCPArsenalConsumableReminderPreview"
    function frame:Hide() self.shown = false end
    function frame:Show() self.shown = true end
    function frame:SetAlpha(value)
        -- Sink receives the exact opaque token, never a processed derivative.
        check(rawequal(value, secret) or value == 0 or (sample and value == 1), "Unexpected health/alpha conversion")
        self.alpha = value
    end
    function frame:SetSize(w, h) self.width, self.height = w, h end
    function frame:SetAllPoints() end
    function frame:SetPoint(...) self.point = { ... } end
    function frame:ClearAllPoints() self.point = nil end
    function frame:EnableMouse(value) check(value == false or sample, "Live visual cannot capture clicks"); self.mouse = value end
    function frame:SetFrameLevel(value) self.frameLevel = value end
    function frame:SetFrameStrata(value) end
    function frame:SetMovable(value) check(sample and value == true, "Only explicit sample can move") end
    function frame:SetClampedToScreen(value) check(sample and value == true, "Only explicit sample can clamp") end
    function frame:RegisterForDrag(button) check(sample and button == "LeftButton", "Only explicit sample accepts drag") end
    function frame:StartMoving() check(sample, "Live visual cannot move via mouse"); self.moving = true end
    function frame:StopMovingOrSizing() check(sample, "Live visual cannot move via mouse"); self.moving = false end
    function frame:GetCenter() return self.centerX, self.centerY end
    function frame:GetEffectiveScale() return self.scale or 0.8 end
    function frame:SetScript(name, fn)
        check(sample and (name == "OnDragStart" or name == "OnDragStop"), "No frame timers/action scripts allowed")
        self.scripts[name] = fn
    end
    function frame:CreateTexture()
        local texture = {}
        function texture:SetAllPoints() end
        function texture:SetPoint(...) end
        function texture:SetColorTexture(...) end
        function texture:SetTexCoord(...) end
        function texture:SetTexture(value) self.texture = value end
        return texture
    end
    function frame:CreateFontString()
        return { SetPoint = function() end, SetText = function(self, text) self.text = text end }
    end
    function frame:CreateAnimationGroup()
        local group = { animations = {}, plays = 0, stops = 0 }
        frame.animation = group
        function group:SetLooping(value) check(value == "REPEAT", "Bounce must loop constantly") end
        function group:Play() self.plays = self.plays + 1 end
        function group:Stop() self.stops = self.stops + 1 end
        function group:CreateAnimation(kind)
            check(kind == "Translation", "Bounce must only translate its child")
            local animation = {}
            function animation:SetOrder(value) self.order = value end
            function animation:SetOffset(x, y) check(x == 0 and math.abs(y) == 7, "Bounce must use constant offsets") end
            function animation:SetDuration(value) check(value == 0.45, "Bounce timing must be constant") end
            function animation:SetSmoothing(value) end
            self.animations[#self.animations + 1] = animation
            return animation
        end
        return group
    end
    frames[#frames + 1] = frame
    return frame
end
local function loadTools(settings)
    frames, timers, tickers, events, callbacks, initializers, items = {}, {}, {}, {}, {}, {}, {}
    healthCalls, itemCalls, scans, accepted, hidden, notices, now = 0, 0, 0, 0, {}, 0, 100
    combat, encounter, raid, grouped, groupCount, groupCombat, exists = false, false, false, false, 0, {}, {}
    dead, petExistsUnknown, petCombatUnknown = false, false, false
    offer, recovery, healthResult, healthError, itemError = "Healer", 0, secret, false, false
    profile = { personalTools = settings or { autoRes = false, consumableReminder = false, healthThreshold = 40 } }
    RA = {
        GetDB = function() return profile end,
        RegisterInitializer = function(_, fn) initializers[#initializers + 1] = fn end,
        RegisterCallback = function(_, name, fn) callbacks[name] = fn end,
        RegisterEvent = function(_, name, fn) events[name] = fn end,
        FireCallback = function(_, name) check(name == "PERSONAL_TOOLS_CHANGED", "Wrong callback"); notices = notices + 1 end,
    }
    assert(loadfile("RCPArsenal/PersonalTools.lua"))("RCPArsenal", RA)
    for _, fn in ipairs(initializers) do fn() end
    return RA.PersonalTools
end
local function ready(id)
    items[id] = { count = 3, usable = true, noMana = false, start = 0, duration = 0, enabled = true, icon = id + 1000 }
    return items[id]
end
local function runTimers()
    local pending = timers
    timers = {}
    for _, handle in ipairs(pending) do if not handle.cancelled then handle.callback() end end
end
local function active(list)
    local count = 0
    for _, handle in ipairs(list) do if not handle.cancelled then count = count + 1 end end
    return count
end

local tools = loadTools()
check(#frames == 0 and #timers == 0 and #tickers == 0 and itemCalls == 0 and healthCalls == 0,
    "Off by default must create no frame/timer or scan")
for name, fn in pairs(events) do fn(name, "player") end
check(#frames == 0 and #timers == 0 and #tickers == 0 and itemCalls == 0 and scans == 0,
    "Disabled event handlers must do no work")
check(tools:SetOption("autoRes", true), "Normal res enable failed")
events.RESURRECT_REQUEST(); check(#timers == 1 and accepted == 0, "Res must defer popup cleanup one frame")
runTimers()
check(accepted == 1 and table.concat(hidden, ",") == "RESURRECT,RESURRECT_NO_SICKNESS,RESURRECT_NO_TIMER",
    "Normal res acceptance or popup cleanup failed")
check(#frames == 0 and #tickers == 0, "Auto res must not start the visual")
for _, state in ipairs({ "combat", "encounter", "party", "raid", "pet", "local pet", "secret pet existence",
    "unknown pet existence", "secret pet combat", "unknown pet combat", "secret", "unknown" }) do
    combat, encounter, raid, grouped, groupCombat, exists = false, false, false, false, {}, {}
    petExistsUnknown, petCombatUnknown = false, false
    if state == "combat" then combat = true
    elseif state == "encounter" then encounter = true
    elseif state == "party" then grouped = true; exists.party2 = true; groupCombat.party2 = true
    elseif state == "raid" then raid = true; grouped = true; groupCount = 20; exists.raid20 = true; groupCombat.raid20 = true
    elseif state == "pet" then grouped = true; exists.partypet1 = true; groupCombat.partypet1 = true
    elseif state == "local pet" then exists.pet = true; groupCombat.pet = true
    elseif state == "secret pet existence" then exists.pet = secret
    elseif state == "unknown pet existence" then petExistsUnknown = true
    elseif state == "secret pet combat" then exists.pet = true; groupCombat.pet = secret
    elseif state == "unknown pet combat" then exists.pet = true; petCombatUnknown = true
    elseif state == "secret" then combat = secret
    elseif state == "unknown" then encounter = nil end
    events.RESURRECT_REQUEST(); runTimers()
    check(accepted == 1 and #hidden == 3, "Battle/unknown res must stay manual: " .. state)
end
combat, encounter, raid, grouped, exists, groupCombat = false, false, false, false, {}, {}
petExistsUnknown, petCombatUnknown = false, false
events.RESURRECT_REQUEST(); encounter = true; runTimers()
check(accepted == 1, "Combat must be rechecked after defer")
encounter = false
events.RESURRECT_REQUEST(); exists.pet = true; groupCombat.pet = true; runTimers()
check(accepted == 1, "Local pet combat must be rechecked after defer even while solo")
exists, groupCombat = {}, {}
events.RESURRECT_REQUEST(); tools:SetOption("autoRes", false); runTimers()
check(accepted == 1 and active(timers) == 0, "Disable must cancel pending acceptance")
tools:SetOption("autoRes", true)
for _, delay in ipairs({ 5, -1, secret }) do
    recovery = delay; events.RESURRECT_REQUEST(); runTimers()
    check(accepted == 1, "Recovery delay/unknown must remain manual")
end
recovery, offer = 0, secret
events.RESURRECT_REQUEST(); runTimers()
check(accepted == 1, "Secret offer must remain manual")
offer = ""
events.RESURRECT_REQUEST(); runTimers()
check(accepted == 1, "Missing offer must remain manual")

tools = loadTools()
ready(5512); ready(224464); ready(241304); ready(271884)
check(tools:SetOption("consumableReminder", true), "Reminder enable failed")
check(tools:GetState().itemID == 224464, "Demonic Healthstone must have priority")
check(#frames == 2 and frames[1].shown and rawequal(frames[1].alpha, secret), "Secret alpha must reach parent sink")
check(frames[2].animation.plays == 1 and active(tickers) == 1 and tickers[1].delay == 1,
    "One bounded readiness refresh and constant child bounce required")
local curve = tools:GetReminderCurveForValidation()
check(curve.kind == Enum.LuaCurveType.Step and curve.points[2][1] == 0.4 and curve.points[2][2] == 0,
    "Native curve must use 0-1 domain and editable threshold")
local beforeItems, beforeHealth = itemCalls, healthCalls
events.UNIT_HEALTH("UNIT_HEALTH", "player")
check(itemCalls == beforeItems and healthCalls == beforeHealth + 1, "Health events must not rescan item state")
events.UNIT_HEALTH("UNIT_HEALTH", secret)
events.UNIT_HEALTH("UNIT_HEALTH", "target")
check(healthCalls == beforeHealth + 1, "Ignore unknown/nonplayer unit health events")
items[224464].count = 0; tools:Refresh()
check(tools:GetState().itemID == 5512, "Standard stone fallback missing")
items[5512].start, items[5512].duration = now, 0.5
tools:Refresh()
check(tools:GetState().itemID == 271884, "Even short shared item cooldown must trigger potion fallback")
items[271884].usable = false; tools:Refresh()
check(tools:GetState().itemID == 241304, "Ready supported lower-priority potion fallback failed")
ready(271883); items[241304].count = 0; tools:Refresh()
check(tools:GetState().itemID == 271883, "Concentrated lower-quality fallback failed")
ready(241305); items[271883].enabled = false; tools:Refresh()
check(tools:GetState().itemID == 241305, "Normal lower-quality fallback failed")
items[241305].enabled = 1; tools:Refresh()
check(tools:GetState().itemID == nil and not frames[1].shown, "Legacy numeric enable must fail closed")
for _, field in ipairs({ "count", "usable", "noMana", "start", "duration", "enabled", "icon" }) do
    items = {}; local item = ready(5512); item[field] = secret
    tools:Refresh()
    check(tools:GetState().itemID == nil and not frames[1].shown, "Secret item field must suppress candidate: " .. field)
end
items = {}; ready(5512); itemError = true; tools:Refresh()
check(tools:GetState().itemID == nil, "Item API errors must fail closed")
itemError = false; healthError = true; tools:Refresh()
check(tools:GetState().itemID == nil and not frames[1].shown, "Native display failure must hide reminder")
healthError = false; tools:Refresh()
check(tools:GetState().itemID == 5512, "Reminder failed to recover after API availability returned")
items[5512].duration, items[5512].start = 2, now; tools:Refresh()
check(tools:GetState().itemID == nil, "Cooldown candidate must hide")
now = now + 2; tickers[#tickers].callback()
check(tools:GetState().itemID == 5512, "Bounded refresh must recover a now-ready item")
check(frames[2].animation.plays < healthCalls, "Health refresh must not restart bounce")
check(tools:SetOption("healthThreshold", 500) and tools:GetState().healthThreshold == 99, "Upper clamp missing")
check(tools:SetOption("healthThreshold", -10) and tools:GetState().healthThreshold == 1, "Lower clamp missing")
check(tools:SetOption("healthThreshold", 37.4) and tools:GetState().healthThreshold == 37, "Threshold rounding missing")
check(not tools:SetOption("healthThreshold", secret) and not tools:SetOption("healthThreshold", 0/0), "Secret/nonfinite threshold accepted")
check(not tools:SetOption("autoRes", 1) and not tools:SetOption("unknown", true), "Invalid options accepted")
check(tools:SetReminderPosition(80, -90) and profile.personalTools.reminderPosition.x == 80, "Local move missing")
check(tools:ResetReminderPosition() and profile.personalTools.reminderPosition == nil and frames[1].point[5] == -140,
    "Local recenter failed")
local oldTicker = tickers[#tickers]
tools:SetOption("consumableReminder", false)
check(active(tickers) == 0 and not frames[1].shown and frames[1].alpha == 0, "Disable must cancel and hide")
beforeItems, beforeHealth = itemCalls, healthCalls
for name, fn in pairs(events) do fn(name, "player") end
oldTicker.callback()
check(itemCalls == beforeItems and healthCalls == beforeHealth and active(tickers) == 0, "Disabled late events/timer must stay idle")
tools:SetOption("consumableReminder", true)
profile.personalTools = { autoRes = false, consumableReminder = false, healthThreshold = 40 }
callbacks.PROFILE_RESET()
check(active(tickers) == 0 and not frames[1].shown, "Profile reset must stop enabled visual")
local nativePercent = UnitHealthPercent
UnitHealthPercent = nil
tools:SetOption("consumableReminder", true)
check(active(tickers) == 0 and not frames[1].shown and tools:GetStatusText("consumableReminder"):find("unavailable"),
    "Missing native APIs must gate reminder with an honest status")
UnitHealthPercent = nativePercent

-- Life-state suppression uses only a readable boolean guard, with unknown and
-- secret state failing closed before item scans or the health display sink.
tools = loadTools()
ready(5512)
tools:SetOption("consumableReminder", true)
beforeItems, beforeHealth = itemCalls, healthCalls
dead = true
events.UNIT_HEALTH("UNIT_HEALTH", "player")
check(not frames[1].shown and tools:GetState().itemID == nil and active(tickers) == 0,
    "Death health event must immediately suppress the visual and stop readiness refresh")
check(itemCalls == beforeItems and healthCalls == beforeHealth, "Dead guard must not query item or health data")
dead = false; events.PLAYER_ALIVE()
check(frames[1].shown and tools:GetState().itemID == 5512 and active(tickers) == 1,
    "Returning alive must recover the enabled reminder")
for _, state in ipairs({ "dead", "secret", "nil", "missing" }) do
    dead = state == "dead" and true or state == "secret" and secret or nil
    local lifeAPI = UnitIsDeadOrGhost
    if state == "missing" then UnitIsDeadOrGhost = nil end
    beforeItems, beforeHealth = itemCalls, healthCalls
    tools:Refresh()
    check(not frames[1].shown and active(tickers) == 0 and tools:GetState().itemID == nil,
        "Dead/unknown life state must suppress reminder: " .. state)
    check(itemCalls == beforeItems and healthCalls == beforeHealth, "Life-state suppression must precede item/health queries")
    UnitIsDeadOrGhost = lifeAPI
end
dead = false; events.PLAYER_UNGHOST()
check(frames[1].shown and active(tickers) == 1, "Unghost event must recover enabled reminder")

-- Preview and Move are explicit ordinary samples independent of live opt-in.
tools = loadTools()
check(#frames == 0, "Sample must not allocate automatically")
check(tools:SetReminderPosition(32, -88), "Saved placement setup failed")
local savedPosition = profile.personalTools.reminderPosition
check(tools:PreviewReminder(), "Preview failed while disabled")
local sample = frames[1]
check(#frames == 1 and sample.name == "RCPArsenalConsumableReminderPreview" and sample.shown and sample.alpha == 1,
    "Explicit preview must show only an ordinary sample")
check(sample.width == 56 and sample.height == 56 and sample.mouse == false and sample.label.text:find("SAMPLE"),
    "Preview must be a labeled 56px noninteractive sample")
check(sample.point[4] == 32 and sample.point[5] == -88 and profile.personalTools.reminderPosition == savedPosition,
    "Preview must preserve and use saved position")
check(not tools:GetState().consumableReminder and itemCalls == 0 and healthCalls == 0 and #tickers == 0 and #timers == 0,
    "Preview must not enable live checks or allocate timers")
check(tools:MoveReminder() and #frames == 1 and sample.mouse and tools:GetState().previewMode == "MOVE",
    "Move must reuse explicit sample with drag enabled")
sample.scripts.OnDragStart()
check(sample.moving, "Move sample did not start dragging")
sample.scale, sample.centerX, sample.centerY = 1.2, 700, 320
sample.scripts.OnDragStop()
check(not sample.moving and math.abs(profile.personalTools.reminderPosition.x - 90) < 0.00001
    and math.abs(profile.personalTools.reminderPosition.y + 60) < 0.00001,
    "Drag must persist UIParent center offsets after converting effective scales")
check(not tools:GetState().consumableReminder and healthCalls == 0 and itemCalls == 0 and #tickers == 0,
    "Moving sample must leave live feature disabled and idle")
check(tools:ResetReminderPosition() and profile.personalTools.reminderPosition == nil and sample.point[5] == -140,
    "Reset must recenter visible sample without enabling live reminder")
tools:SetReminderPosition(-40, 120)
tools:StopReminderPreview()
check(not sample.shown and not sample.mouse and tools:GetState().previewMode == nil,
    "Stopping preview must hide and release mouse input")
check(tools:PreviewReminder() and sample.point[4] == -40 and sample.point[5] == 120,
    "Saved moved position must survive preview close/reopen")
combat = true
check(not tools:MoveReminder(), "Combat move must be refused")
events.PLAYER_REGEN_DISABLED("PLAYER_REGEN_DISABLED")
check(not sample.shown and not sample.mouse, "Combat event must stop sample")
combat = false; tools:MoveReminder(); sample.scripts.OnDragStart()
combat = true; sample.scripts.OnDragStop()
check(profile.personalTools.reminderPosition.x == -40 and profile.personalTools.reminderPosition.y == 120,
    "Drag interrupted by combat must not persist unknown placement")
check(healthCalls == 0 and itemCalls == 0 and #tickers == 0 and #timers == 0
    and profile.personalTools.autoRes == false and profile.personalTools.consumableReminder == false,
    "Sample flow must never alter personal opt-ins or access health/items")
print("PASS: " .. checks .. " personal tools assertions (offline Lua mocks; native threshold and raid validation pending)")
