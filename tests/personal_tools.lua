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
local offer, recovery, healthResult, healthError, itemError, healthRatio, reportedHealthRatio, nativeAlpha
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
-- Model native normalized input and right-continuous Step evaluation,
-- independently of the module's chosen points. Live alpha stays an opaque token.
local function float32(value)
    if value == 0 then return 0 end
    local fraction, exponent = math.frexp(value)
    return math.ldexp(math.floor(fraction * 2^24 + 0.5) / 2^24, exponent)
end
function UnitHealthPercent(unit, predicted, curve)
    check(unit == "player" and predicted == true and curve ~= nil, "Native curve arguments wrong")
    healthCalls = healthCalls + 1
    if healthError then error("Native health display unavailable") end
    nativeAlpha = curve:Evaluate(float32(predicted and healthRatio or reportedHealthRatio or healthRatio))
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
        self.points[#self.points + 1] = { float32(x), y }
    end
    function object:GetPoint(index) return {x=self.points[index][1], y=self.points[index][2]} end
    function object:Evaluate(x)
        local result = self.points[1][2]
        for _, point in ipairs(self.points) do
            if x < point[1] then break end
            result = point[2]
        end
        return result
    end
    return object
end }
local function bagIDs()
    local ids = {}
    for id, item in pairs(items) do if issecretvalue(item.count) or item.count ~= 0 then ids[#ids+1] = id end end
    table.sort(ids); return ids
end
C_Container = {
    GetContainerNumSlots = function(bag)
        if itemError then error("Item APIs unavailable") end
        return bag == 0 and #bagIDs() or 0
    end,
    GetContainerItemID = function(bag, slot) itemCalls = itemCalls + 1; return bagIDs()[slot] end,
    GetContainerItemInfo = function(bag, slot)
        local item = items[bagIDs()[slot]]
        return { stackCount = item.count, iconFileID = item.icon }
    end,
}
C_Item = { GetItemCount = function() error("No separate counts") end,
    IsUsableItem = function() error("No readiness check") end,
    GetItemCooldown = function() error("No cooldown check") end }
function CreateFrame(kind, name, parent, template)
    check(kind == "Frame" and template == nil, "Visual must be nonsecure and noninteractive")
    local frame = { name = name, parent = parent, shown = true, scripts = {} }
    local sample = name == "RCPArsenalConsumableReminderPreview"
    function frame:Hide() self.shown = false end
    function frame:Show()
        local changed = not self.shown; self.shown = true
        if changed and self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function frame:SetAlpha(value)
        -- Sink receives the exact opaque token, never a processed derivative.
        check(rawequal(value, secret) or value == 0 or value == 1, "Unexpected health/alpha conversion")
        self.alpha = value
        self.renderAlpha = rawequal(value, secret) and nativeAlpha or value
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
        check((sample and (name == "OnDragStart" or name == "OnDragStop")) or (name == "OnShow" and self.name == "RCPArsenalConsumableReminder"), "No frame timers/action scripts allowed")
        self.scripts[name] = fn
    end
    function frame:CreateTexture()
        local texture = {}
        function texture:Hide() self.shown = false end
        function texture:Show() self.shown = true end
        function texture:SetAllPoints() end
        function texture:SetPoint(...) end
        function texture:SetColorTexture(...) end
        function texture:SetTexCoord(...) end
        function texture:SetTexture(value) self.texture = value end
        return texture
    end
    function frame:CreateFontString()
        local text = { SetPoint = function() end, SetText = function(self, text) self.text = text end,
            SetTextHeight = function(self, size) self.textHeight = size end,
            SetWidth = function(self, width) self.width = width end, SetWordWrap = function() end }
        self.strings = self.strings or {}; self.strings[#self.strings+1] = text
        return text
    end
    function frame:CreateAnimationGroup()
        local group = { animations = {}, plays = 0, stops = 0 }
        frame.animation = group
        function group:SetLooping(value) check(value == "REPEAT", "Bounce must loop constantly") end
        function group:Play() self.plays = self.plays + 1; self.playing = true end
        function group:Stop() self.stops = self.stops + 1; self.playing = false end
        function group:IsPlaying() return self.playing == true end
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
-- Load the actual shared Core normalizer without booting its event frame.
local coreTextRA = {}
local coreTextEnv = setmetatable({ CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end }, {__index=_G})
coreTextEnv._G = coreTextEnv
local coreTextChunk = assert(loadfile("RCPArsenal/Core.lua"))
setfenv(coreTextChunk, coreTextEnv); coreTextChunk("RCPArsenal", coreTextRA)
local function loadTools(settings)
    frames, timers, tickers, events, callbacks, initializers, items = {}, {}, {}, {}, {}, {}, {}
    healthCalls, itemCalls, scans, accepted, hidden, notices, now = 0, 0, 0, 0, {}, 0, 100
    combat, encounter, raid, grouped, groupCount, groupCombat, exists = false, false, false, false, 0, {}, {}
    dead, petExistsUnknown, petCombatUnknown = false, false, false
    offer, recovery, healthResult, healthError, itemError = "Healer", 0, secret, false, false
    healthRatio, reportedHealthRatio, nativeAlpha = .35, nil, nil
    profile = { personalTools = settings or { autoRes = false, consumableReminder = false, healthThreshold = 40 } }
    RA = {
        NormalizeReminderText = coreTextRA.NormalizeReminderText,
        GetDB = function() return profile end,
        RegisterInitializer = function(_, fn) initializers[#initializers + 1] = fn end,
        RegisterCallback = function(_, name, fn) callbacks[name] = fn end,
        RegisterEvent = function(_, name, fn) events[name] = fn end,
        FireCallback = function(_, name) check(name == "PERSONAL_TOOLS_CHANGED", "Wrong callback"); notices = notices + 1 end,
    }
    assert(loadfile("RCPArsenal/HealingSupplies.lua"))("RCPArsenal", RA)
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
check(frames[2].animation.plays == 1 and #tickers == 0,
    "Inventory selection must use events with no readiness ticker")
local curve = tools:GetReminderCurveForValidation()
check(curve.kind == Enum.LuaCurveType.Step and math.abs(curve.points[2][1] - 0.4) < 1e-7 and curve:Evaluate(0.4) == 1 and curve:Evaluate(0.400001) == 0,
    "Native curve must use 0-1 domain and editable threshold")
local beforeItems, beforeHealth = itemCalls, healthCalls
events.UNIT_HEALTH("UNIT_HEALTH", "player")
check(itemCalls == beforeItems and healthCalls == beforeHealth + 1, "Health events must not rescan item state")
events.UNIT_HEALTH("UNIT_HEALTH", secret)
events.UNIT_HEALTH("UNIT_HEALTH", "target")
check(healthCalls == beforeHealth + 1, "Ignore unknown/nonplayer unit health events")
items[224464].count = 0; tools:Refresh()
check(tools:GetState().itemID == 5512, "Standard stone fallback missing")
items[5512].start, items[5512].duration, items[5512].usable = now, 100, false
tools:Refresh()
check(tools:GetState().itemID == 5512, "Carried stone must ignore cooldown/usability")
items[5512].count = 0; tools:Refresh()
check(tools:GetState().itemID == 271884, "Carried potion fallback missing")
items[271884].count = 0; ready(271883); tools:Refresh()
check(tools:GetState().itemID == 271883, "Concentrated lower rank missing")
items[271883].count = 0; tools:Refresh()
check(tools:GetState().itemID == 241304, "Silvermoon fallback missing")
items[241304].count = 0; ready(241305); tools:Refresh()
check(tools:GetState().itemID == 241305, "Silvermoon lower rank missing")
items = {}; tools:Refresh()
check(tools:GetState().itemID == nil and frames[1].shown and not frames[1].icon.shown and not frames[1].border.shown,
    "Confirmed empty bags require text-only visual")
check(frames[2].strings[1].text == "OUT OF POTIONS" and rawequal(frames[1].alpha,secret), "Empty warning must share native alpha sink")
healthRatio=.7;events.UNIT_HEALTH("UNIT_HEALTH","player")
check(frames[1].renderAlpha==0, "Empty warning did not hide natively on recovery")
healthRatio=.35;events.UNIT_HEALTH("UNIT_HEALTH","player")
check(frames[1].renderAlpha==1, "Empty warning did not reappear natively while low")
ready(5512); items[5512].count=secret; tools:Refresh()
check(not frames[1].shown, "Unknown inventory must never show definitive empty warning")
items[5512].count=1;items[5512].icon=secret;tools:Refresh()
check(tools:GetState().itemID==5512 and frames[1].shown, "Missing icon must preserve known carriage")
itemError=true;tools:Refresh();check(not frames[1].shown,"Inventory API failure must suppress visual")
itemError=false;healthError=true;tools:Refresh()
check(tools:GetState().itemID==nil and not frames[1].shown,"Native display failure must hide reminder")
healthError=false;tools:Refresh();check(tools:GetState().itemID==5512,"Reminder failed to recover")
-- Native animation can be stopped independently of a stale Lua flag.
frames[2].animation:Stop();events.UNIT_HEALTH("UNIT_HEALTH","player")
check(frames[2].animation:IsPlaying(),"Native stopped bounce was not restarted")
check(tools:SetOption("healthThreshold", 500) and tools:GetState().healthThreshold == 99, "Upper clamp missing")
check(tools:SetOption("healthThreshold", -10) and tools:GetState().healthThreshold == 1, "Lower clamp missing")
check(tools:SetOption("healthThreshold", 37.4) and tools:GetState().healthThreshold == 37, "Threshold rounding missing")
check(not tools:SetOption("healthThreshold", secret) and not tools:SetOption("healthThreshold", 0/0), "Secret/nonfinite threshold accepted")
check(not tools:SetOption("autoRes", 1) and not tools:SetOption("unknown", true), "Invalid options accepted")
check(tools:SetReminderPosition(80, -90) and profile.personalTools.reminderPosition.x == 80, "Local move missing")
check(tools:ResetReminderPosition() and profile.personalTools.reminderPosition == nil and frames[1].point[5] == -140,
    "Local recenter failed")
tools:SetOption("consumableReminder", false)
check(active(tickers) == 0 and not frames[1].shown and frames[1].alpha == 0, "Disable must cancel and hide")
beforeItems, beforeHealth = itemCalls, healthCalls
for name, fn in pairs(events) do fn(name, "player") end
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
check(frames[1].shown and tools:GetState().itemID == 5512 and active(tickers) == 0,
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
check(frames[1].shown and active(tickers) == 0, "Unghost event must recover enabled reminder")

-- Preview and Move are explicit ordinary samples independent of live opt-in.
tools = loadTools()
check(#frames == 0, "Sample must not allocate automatically")
check(tools:SetReminderPosition(32, -88), "Saved placement setup failed")
local savedPosition = profile.personalTools.reminderPosition
check(tools:PreviewReminder(), "Preview failed while disabled")
local sample = frames[1]
check(#frames == 2 and sample.name == "RCPArsenalConsumableReminderPreview" and sample.shown and sample.alpha == 1,
    "Explicit preview must show only an ordinary sample")
check(sample.width == 56 and sample.height == 56 and sample.mouse == false and sample.label.text:find("SAMPLE") and frames[2].animation:IsPlaying(),
    "Preview must be a labeled 56px noninteractive sample")
check(sample.point[4] == 32 and sample.point[5] == -88 and profile.personalTools.reminderPosition == savedPosition,
    "Preview must preserve and use saved position")
check(not tools:GetState().consumableReminder and itemCalls == 0 and healthCalls == 0 and #tickers == 0 and #timers == 0,
    "Preview must not enable live checks or allocate timers")
check(tools:MoveReminder() and #frames == 2 and sample.mouse and tools:GetState().previewMode == "MOVE" and not frames[2].animation:IsPlaying(),
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
-- Appearance choices are public configuration; they do not opt into health
-- checks or change the saved anchor. Native animation Play has a void return.
combat = false
local anchor = profile.personalTools.reminderPosition
local itemsBefore, healthBefore = itemCalls, healthCalls
check(tools:SetOption("reminderStoneText", "Use your heal!"), "Custom reminder text rejected")
check(tools:SetOption("reminderIconSize", 80) and tools:SetOption("reminderTextSize", 22), "Independent sizes rejected")
check(sample.width == 80 and sample.height == 80 and frames[2].strings[1].text == "Use your heal!" and frames[2].strings[1].textHeight == 22,
    "Appearance choices did not update existing sample without recreating it")
check(profile.personalTools.reminderPosition == anchor and not tools:GetState().consumableReminder
    and itemCalls == itemsBefore and healthCalls == healthBefore, "Appearance change enabled checks or changed placement")
check(not tools:SetOption("reminderIconSize", secret) and not tools:SetOption("reminderTextSize",0/0)
    and not tools:SetOption("reminderStoneText",secret) and not tools:SetOption("reminderCombat","bad"), "Invalid appearance/combat choice accepted")
check(tools:SetOption("reminderIconSize",999) and tools:GetState().reminderIconSize == 128, "Icon size clamp missing")
check(tools:SetOption("reminderTextSize",1) and tools:GetState().reminderTextSize == 8, "Text size clamp missing")
check(tools:PreviewReminder("potion") and frames[2].strings[1].text=="Use healing potion" and frames[2].animation:IsPlaying(), "Preview did not demonstrate bounce independently of opt-in")
tools:StopReminderPreview()
check(not frames[2].animation:IsPlaying(), "Stopping preview left bounce running")

tools = loadTools()
ready(5512)
tools:SetOption("consumableReminder",true)
check(tools:GetState().reminderCombat == "BOTH" and frames[1].shown, "New combat option changed existing default visibility")
tools:SetOption("reminderCombat","IN_COMBAT")
check(not frames[1].shown, "In-combat choice showed live reminder out of combat")
combat=true;events.PLAYER_REGEN_DISABLED("PLAYER_REGEN_DISABLED")
check(frames[1].shown, "In-combat choice did not recover on combat event")
tools:SetOption("reminderCombat","OUT_OF_COMBAT")
check(not frames[1].shown, "Out-of-combat choice showed live reminder in combat")
combat=false;events.PLAYER_REGEN_ENABLED("PLAYER_REGEN_ENABLED")
check(frames[1].shown and tools:GetState().consumableReminder, "Combat visibility change lost opt-in or did not recover")
-- Hidden-mode bag events invalidate without scanning; re-entry reads fresh bags.
for _, mode in ipairs({"IN_COMBAT", "OUT_OF_COMBAT"}) do
    tools=loadTools();ready(5512);tools:SetOption("consumableReminder",true)
    combat = mode == "OUT_OF_COMBAT"
    tools:SetOption("reminderCombat",mode)
    local before=itemCalls
    items={};events.BAG_UPDATE_DELAYED("BAG_UPDATE_DELAYED")
    check(itemCalls==before and not frames[1].shown,"Hidden bag event scanned or showed reminder")
    combat=not combat
    events[combat and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED"](combat and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
    check(tools:GetState().itemID==nil and frames[2].strings[1].text=="OUT OF POTIONS" and frames[1].shown,
        "Mode re-entry reused removed item from hidden cache")
end
-- Only a relevant genuinely pending bag item can trigger data reconciliation.
tools=loadTools();ready(99999)
C_Item.GetItemInfoInstant=function(id) return id,nil,nil,nil,nil,0,1 end
C_Item.IsItemDataCachedByID=function() return false end
C_Item.GetItemSpell=function() return nil,1295247 end
tools:SetOption("consumableReminder",true)
local before=itemCalls
for i=1,5 do events.ITEM_DATA_LOAD_RESULT("ITEM_DATA_LOAD_RESULT",100000+i,true) end
check(itemCalls==before,"Unrelated item-data events rescanned bags")
C_Item.IsItemDataCachedByID=function() return true end
events.ITEM_DATA_LOAD_RESULT("ITEM_DATA_LOAD_RESULT",99999,true)
check(itemCalls==before+1 and tools:GetState().itemID==99999,"Relevant pending result did not cause one needed refresh")
events.ITEM_DATA_LOAD_RESULT("ITEM_DATA_LOAD_RESULT",99999,true)
check(itemCalls==before+1,"Resolved item-data result rescanned again")
C_Item.GetItemSpell=function() return nil,99999 end
tools:Refresh();before=itemCalls
events.ITEM_DATA_LOAD_RESULT("ITEM_DATA_LOAD_RESULT",99999,true)
check(itemCalls==before,"Cached unrecognized potion was left pending")
tools=loadTools()
check(tools:SetOption("reminderStoneText", "|Tbad:60|t\nGo"), "Literal text option failed")
check(tools:PreviewReminder("stone") and frames[2].strings[1].text == "||Tbad:60||t Go", "Message interpreted markup or retained newline")
-- No artificial low-health wait: both player events write alpha in their
-- own callback at a fixed clock, without timers, inventory or a bounce phase.
tools=loadTools();ready(5512);healthRatio=.8
tools:SetOption("healthThreshold",60);tools:SetOption("consumableReminder",true)
check(frames[1].renderAlpha==0,"Above-threshold setup failed")
for _,eventName in ipairs({"UNIT_HEALTH","UNIT_MAXHEALTH"}) do
    local beforeItems,beforeHealth,beforeTime=itemCalls,healthCalls,now
    healthRatio=.59;events[eventName](eventName,"player")
    check(frames[1].renderAlpha==1 and healthCalls==beforeHealth+1 and now==beforeTime,
        "Player health event deferred its native alpha write")
    check(itemCalls==beforeItems and #timers==0 and #tickers==0,"Health event scanned or queued a refresh")
    healthRatio=.8;events[eventName](eventName,"player")
    check(frames[1].renderAlpha==0,"Recovery waited for a timer/animation phase")
end
-- Predicted native health can already be low while server-reported health
-- remains above the setting. Never read/compare either in addon code.
reportedHealthRatio,healthRatio=.75,.59
local priorItems=itemCalls
events.UNIT_HEALTH("UNIT_HEALTH","player")
check(frames[1].renderAlpha==1 and itemCalls==priorItems,"Reminder opted out of native predicted health")
reportedHealthRatio=nil
-- UTF-8 limits agree across setter/getter and the actual profile normalizer.
for _, entry in ipairs({
    {string.rep("界",21), string.rep("界",21)},
    {"A"..string.rep("界",60), "A"..string.rep("界",59)},
    {string.rep("é",61), string.rep("é",60)},
    {string.rep("😀",21), string.rep("😀",21)},
    {string.rep("😀",61), string.rep("😀",60)},
}) do
    check(tools:SetOption("reminderStoneText",entry[1]) and profile.personalTools.reminderStoneText==entry[2], "Setter split/truncated a UTF-8 character")
    profile.personalTools.reminderPotionText=entry[1]
    check(tools:GetState().reminderPotionText==entry[2], "Getter UTF-8 limit differs")
    local normalized=coreTextRA:CreateDefaultProfile()
    normalized.personalTools.reminderStoneText,normalized.personalTools.reminderPotionText=entry[1],entry[1]
    coreTextRA:NormalizeProfile(normalized)
    check(normalized.personalTools.reminderStoneText==entry[2] and normalized.personalTools.reminderPotionText==entry[2],"Profile normalization split/truncated UTF-8")
end
check(coreTextRA:NormalizeReminderText("valid"..string.char(240,159))=="valid", "Incomplete UTF-8 tail retained")
print("PASS: " .. checks .. " personal tools assertions (offline Lua mocks; native threshold and raid validation pending)")
