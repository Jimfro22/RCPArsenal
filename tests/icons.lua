-- Offline Lua 5.1 assertions. This cannot simulate WoW rendering or taint.
local checks, combat, mediaReady = 0, false, false
local timers, objects, named, events, callbacks, initializers = {}, {}, {}, {}, {}, {}
local spellIcons, spellRequests = {}, {}
local geometryWrites, attributeWrites, scanCalls = 0, 0, 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
local function noop() end
local methods = {}
function methods:GetParent() return self.parent end
function methods:SetParent(parent) self.parent = parent end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:HookScript(event, fn)
    self.hooks[event] = self.hooks[event] or {}
    table.insert(self.hooks[event], fn)
end
function methods:Fire(event)
    if self.scripts[event] then self.scripts[event](self) end
    for _, fn in ipairs(self.hooks[event] or {}) do fn(self) end
end
function methods:Show() local changed = not self.shown; self.shown = true; if changed then self:Fire('OnShow') end end
function methods:Hide() local changed = self.shown; self.shown = false; if changed then self:Fire('OnHide') end end
function methods:SetShown(value) if value then self:Show() else self:Hide() end end
function methods:SetSize(w, h) geometryWrites = geometryWrites + 1; self.width, self.height = w, h end
function methods:SetWidth(w) geometryWrites = geometryWrites + 1; self.width = w end
function methods:SetHeight(h) geometryWrites = geometryWrites + 1; self.height = h end
function methods:SetPoint(...) geometryWrites = geometryWrites + 1; self.points[#self.points + 1] = {...} end
function methods:ClearAllPoints() geometryWrites = geometryWrites + 1; self.points = {} end
function methods:SetAllPoints(other) geometryWrites = geometryWrites + 1; self.allPoints = other end
function methods:GetWidth() return self.width or 0 end
function methods:GetHeight() return self.height or 0 end
function methods:GetLeft() return 300 end
function methods:GetTop() return 600 end
function methods:GetRight() return 700 end
function methods:GetBottom() return 300 end
function methods:GetCenter() return 500, 500 end
function methods:GetScale() return self.scale or 1 end
function methods:GetEffectiveScale() return self.scale or 1 end
function methods:SetScale(value) geometryWrites = geometryWrites + 1; self.scale = value end
function methods:SetAttribute(key, value) attributeWrites = attributeWrites + 1; self.attrs[key] = value end
function methods:GetAttribute(key) return self.attrs[key] end
function methods:SetTexture(asset, wrapH, wrapV, filter)
    self.textureCalls = (self.textureCalls or 0) + 1
    self.lastDesired = asset
    if self.alwaysFail or (type(asset) == 'string' and asset:find('AddOns', 1, true) and not mediaReady) then
        self.texture = nil
        return false -- A successful pcall is not successful SetTexture.
    end
    self.texture, self.filter = asset, filter
    return true
end
function methods:GetTexture() return self.texture end
function methods:SetFont(path, size)
    self.fontCalls = (self.fontCalls or 0) + 1
    if self.failFonts then return false end
    if path == 'Fonts\\ARIALN.TTF' or (path == 'SharedExpressway.ttf' and mediaReady) then
        self.font, self.fontSize = path, size
        return true
    end
    return false
end
function methods:GetFont() return self.font, self.fontSize end
function methods:SetText(text) self.text = text; self.textCalls = (self.textCalls or 0) + 1 end
function methods:GetText() return self.text end
function methods:GetStringWidth() return #(self.text or '') * 6 end
function methods:GetStringHeight() return self.fontSize or 10 end
local objectMeta = {__index = function(_, key)
    if methods[key] then return methods[key] end
    if key:match('^Set') or key:match('^Register') or key == 'EnableMouse' or key == 'AddMaskTexture' then return noop end
end}
local function object(kind, name, parent)
    local frame = setmetatable({kind = kind, name = name, parent = parent, shown = true, scripts = {}, hooks = {}, attrs = {}, points = {}}, objectMeta)
    objects[#objects + 1] = frame
    if name then named[name] = frame; _G[name] = frame end
    return frame
end
function methods:CreateTexture() return object('Texture', nil, self) end
function methods:CreateMaskTexture() return object('MaskTexture', nil, self) end
function methods:CreateFontString() return object('FontString', nil, self) end
function methods:CreateAnimationGroup()
    local group = object('AnimationGroup', nil, self)
    group.CreateAnimation = function() return object('Animation', nil, group) end
    group.Play, group.Stop = noop, noop
    return group
end
function CreateFrame(kind, name, parent) return object(kind, name, parent) end
UIParent = object('Frame', 'UIParent')
UIParent:SetSize(1920, 1080)
GameTooltip = object('Frame', 'GameTooltip')
function InCombatLockdown() return combat end
function IsInRaid() return false end
function IsInGroup() return false end
function UnitIsGroupLeader() return false end
function UnitIsGroupAssistant() return false end
function GetNumGroupMembers() return 0 end
function GetCVarBool() return true end
function GetTime() return 0 end
function GetCursorPosition() return 500, 500 end
function UnitName() return 'Test', 'Realm' end
function GetRealmName() return 'Realm' end
function UnitClass() return 'Mage', 'MAGE' end
function UnitExists() return false end
function UnitGUID() return 'player-guid' end
function Ambiguate(name) return name end
function LibStub()
    return {Fetch = function() if mediaReady then return 'SharedExpressway.ttf' end end}
end
C_Spell = {
    GetSpellTexture = function(id) return spellIcons[id] end,
    GetSpellInfo = function() return nil end,
    RequestLoadSpellData = function(id) spellRequests[id] = (spellRequests[id] or 0) + 1 end,
}
C_Timer = {NewTimer = function(delay, fn)
    local timer = {delay = delay, callback = fn, Cancel = function(self) self.cancelled = true end}
    timers[#timers + 1] = timer
    return timer
end}
C_Timer.After = function(delay, fn) C_Timer.NewTimer(delay, fn) end
local function pending()
    local count = 0
    for _, timer in ipairs(timers) do if not timer.cancelled and not timer.fired then count = count + 1 end end
    return count
end
local function drain(limit)
    local fired = 0
    while true do
        local nextTimer
        for _, timer in ipairs(timers) do if not timer.cancelled and not timer.fired then nextTimer = timer; break end end
        if not nextTimer then break end
        fired = fired + 1
        check(fired <= (limit or 6), 'Retry queue exceeded its bounded pass count')
        nextTimer.fired = true
        nextTimer.callback()
    end
    return fired
end
local db = {
    shown = true, hudEnabled = true, demoMode = true, locked = true, mode = 'COMPACT',
    position = {}, leaderToolbox = {enabled = true, panicEnabled = true, showMissing = true},
    compact = {showEmptyState = false}, scan = {showStrip = false}, actions = {},
}
local RA = {Categories = {}, Catalog = {}, CatalogByKey = {}, Reports = {}, Roster = {}}
function RA:RegisterCallback(name, fn) callbacks[name] = callbacks[name] or {}; table.insert(callbacks[name], fn) end
function RA:RegisterEvent(name, fn) events[name] = events[name] or {}; table.insert(events[name], fn) end
function RA:RegisterInitializer(fn) table.insert(initializers, fn) end
function RA:FireCallback(name, ...) for _, fn in ipairs(callbacks[name] or {}) do fn(...) end end
local function event(name, ...) for _, fn in ipairs(events[name] or {}) do fn(name, ...) end end
function RA:GetDB() return db end
function RA:IsHUDEnabled() return db.hudEnabled end
function RA:GetVerificationStatus() return 1, 1, true end
function RA:GetInspectionProgress() return 1, 1, nil, false, nil, false end
function RA:GetPendingScanEntries() return {} end
function RA:GetRosterList() return {} end
function RA:GetDisplayReports() return {} end
function RA:GetAbilityOwners() return {} end
function RA:GetShortName(name) return name end
function RA:GetAbilityName(ability) return ability.name end
function RA:GetAbilityTexture(ability) return spellIcons[ability.spellID] or 134400 end
function RA:GetClassColor() return 1, 1, 1 end
function RA:IsRaidGroupIgnored() return false end
function RA:IsCategoryEnabled() return true end
function RA:IsAbilityEnabled() return true end
function RA:ColorizeName(name) return name end
function RA:Print(text) error(text) end
function RA:RequestInspectionScan() scanCalls = scanCalls + 1; error('Visual recovery requested a talent scan') end
RA.ScheduleInspectionScan = RA.RequestInspectionScan
assert(loadfile('RCPArsenal/Assets.lua'))('RCPArsenal', RA)
assert(loadfile('RCPArsenal/Media.lua'))('RCPArsenal', RA)
assert(loadfile('RCPArsenal/Theme.lua'))('RCPArsenal', RA)

-- Hidden-only registrations and world events must not start retry work.
local hidden = object('Frame', nil, UIParent); hidden:Hide()
local cold = hidden:CreateTexture()
RA:RegisterVisualTexture(cold, 'Interface\\AddOns\\RCPArsenal\\Media\\DockSort', 134400, 'LINEAR')
RA.Initialized = true
event('PLAYER_LOGIN'); event('PLAYER_ENTERING_WORLD'); RA:FireCallback('INITIALIZED')
check(pending() == 0 and cold.texture == 134400, 'Hidden assets scheduled recovery or lacked a fallback')
hidden:Show()
check(pending() == 1, 'Visible demand must create one timer')
for _ = 1, 20 do RA:RequestVisualAssetRefresh() end
check(pending() == 1, 'Repeated demand duplicated the queue')
local before = cold.textureCalls
check(drain() == 6 and cold.textureCalls > before and cold.texture == 134400, 'Persistent failure must remain registered with a visible fallback')
check(pending() == 0, 'Bounded retries failed to stop')
mediaReady = true
hidden:Hide(); hidden:Show(); drain()
check(cold.texture == 'Interface\\AddOns\\RCPArsenal\\Media\\DockSort' and cold.filter == 'LINEAR', 'Delayed artwork failed to recover with its filter')
hidden:Hide()

-- Failed font registrations and a throwing resolver remain recoverable and
-- cannot strand other resources or turn the finite queue into polling.
local faultParent = object('Frame', nil, UIParent)
local failedFont = faultParent:CreateFontString()
failedFont.failFonts = true
failedFont:SetText('!')
check(not RA:ApplyFont(failedFont, 13, 'BOLD', false), 'Font failure was reported as success')
local resolved = faultParent:CreateTexture()
local resolverReady = false
RA:RegisterResolvedTexture(resolved, function()
    if not resolverReady then error('cold resolver fixture') end
    return 44444
end, 134400)
check(resolved.texture == 134400, 'Throwing resolver did not receive a fallback')
check(drain() == 6 and pending() == 0, 'Failed font/resolver did not stop at the bound')
failedFont.failFonts, resolverReady = false, true
faultParent:Hide(); faultParent:Show()
drain()
check(failedFont.font == 'SharedExpressway.ttf' and failedFont:GetText() == '!' and resolved.texture == 44444, 'Failed font/resolver registrations were discarded')
faultParent:Hide()

-- Missing spell data is requested once and repaired in place on its event.
local spellParent = object('Frame', nil, UIParent)
local spellIcon = spellParent:CreateTexture()
RA:RegisterSpellIcon(spellIcon, 12345)
check(spellIcon.texture == 134400 and spellRequests[12345] == 1, 'Cold spell requires fallback plus one data request')
drain()
check(spellRequests[12345] == 1, 'Retries repeated the spell data request')
spellIcons[12345] = 98765
event('SPELL_DATA_LOAD_RESULT', 54321, true)
check(spellIcon.texture == 134400 and pending() == 0, 'Unrelated data event refreshed the wrong spell')
event('SPELL_DATA_LOAD_RESULT', 12345, true)
check(spellIcon.texture == 98765 and pending() == 1, 'Successful spell event did not repair its actual texture')
spellParent:Hide()
check(pending() == 0, 'Hiding the last assets failed to cancel recovery')

-- Load the actual Quick Bar and HUD constructors, retaining all real refs.
RA.Initialized = false
mediaReady = false
assert(loadfile('RCPArsenal/Layout.lua'))('RCPArsenal', RA)
assert(loadfile('RCPArsenal/RaidLeader.lua'))('RCPArsenal', RA)
assert(loadfile('RCPArsenal/UI.lua'))('RCPArsenal', RA)
local realRefreshHUD = RA.RefreshHUD
RA.RefreshHUD = noop -- Create frames before supplying test ability owners.
for _, init in ipairs(initializers) do init() end
RA.RefreshHUD = realRefreshHUD
local ability = {key = 'test', index = 1, spellID = 1126, category = 'RAID_DEFENSIVE', name = 'Test Spell'}
local owner = {name = 'Test-Realm', shortName = 'Test', class = 'MAGE', role = 'DAMAGER'}
RA.Categories = {{key = 'RAID_DEFENSIVE', name = 'Raid Defensives'}}
RA.Catalog = {ability}
function RA:BuildAbilityOwners() return {{owner}} end
RA:RefreshHUD()
RA.RaidLeaderToolbox:ShowMissingPanel()
RA.Initialized = true
RA:FireCallback('INITIALIZED')
check(pending() == 1, 'Actual overlays did not share a single recovery queue')
local panic = named.RCPArsenalHUDPanicButton
local puck = named.RCPArsenalRaidLeaderPuck
local dock = named.RCPArsenalRaidLeaderToolbox
check(panic and panic.label and panic.label:GetText() == '!' and panic:IsShown(), 'Actual PANIC glyph not created and positioned')
check(panic.points[1][1] == 'RIGHT' and panic.points[1][3] == 'LEFT', 'PANIC must stay left of first ability lane')
local actualRefs, spellRefs, textRefs = {puck.logo, dock.logo}, {}, {}
local desiredPaths = {}
for _, region in ipairs(objects) do
    if region.__raAssetPath and region:IsVisible() then
        desiredPaths[region] = region.__raAssetPath
        actualRefs[#actualRefs + 1] = region
    end
    if region.kind == 'FontString' and region:IsVisible() then textRefs[region] = region.fontCalls or 0 end
    if region.item and region.icon then spellRefs[#spellRefs + 1] = region.icon end
end
check(#spellRefs == 10, 'Actual missing-panel spell icon references were not constructed')
check(puck.logo.texture == 134400 and dock.logo.texture == 134400, 'Cold actual artwork did not retain a fallback')
check(panic.label.font == 'Fonts\\ARIALN.TTF', 'PANIC needs a bundled-client font fallback')
local sortIcon
for _, region in ipairs(objects) do if region.__raAssetPath == RA.Theme.Assets.DockSort then sortIcon = region end end
check(sortIcon and sortIcon.texture == 134400 and sortIcon:GetWidth() == 18 and sortIcon:GetHeight() == 18, 'Actual SORT texture missing or zero-sized')
local geometryBefore, attributesBefore = geometryWrites, attributeWrites
combat, mediaReady = true, true
for _, region in ipairs(objects) do if region.item then spellIcons[region.item.spellID] = region.item.spellID + 100000 end end
spellIcons[1126] = 101126
check(drain() == 6, 'Actual overlay warm-up did not terminate after six passes')
check(geometryBefore == geometryWrites and attributesBefore == attributeWrites, 'Asset recovery changed geometry or protected attributes in combat')
check(scanCalls == 0, 'Asset recovery invoked talent inspection')
for region, path in pairs(desiredPaths) do check(region.texture == path, 'Registered actual artwork did not recover: ' .. path) end
for region, count in pairs(textRefs) do check(region.fontCalls > count and region.font == 'SharedExpressway.ttf', 'Actual Quick Bar/HUD font ref did not recover') end
for _, region in ipairs(spellRefs) do check(region.texture ~= 134400, 'Actual flyout spell icon did not recover') end
check(panic.label:GetText() == '!' and sortIcon.filter == 'LINEAR', 'Recovery changed PANIC identity or SORT filter')
local spellHUDCount = 0
for _, region in ipairs(objects) do if region.kind == 'Texture' and region.texture == 101126 and not (region.parent and region.parent.parent and region.parent.parent.item) then spellHUDCount = spellHUDCount + 1 end end
check(spellHUDCount > 0, 'Actual compact ability icon did not register/recover')
combat = false
db.mode = 'DETAILED'
RA:RefreshHUD()
drain()
check(panic:IsShown() and panic.points[1][3] == 'LEFT', 'Detailed layout lost PANIC position')
RA:CancelVisualAssetRefresh()
RA:FireCallback('VISUAL_ASSET_REFRESH')
check(pending() == 0 and scanCalls == 0, 'Manual visual callback scheduled engine work')
-- Reusing an already registered texture must not continually restart retries.
RA:RegisterVisualTexture(cold, cold.__raAssetPath or 'Interface\\AddOns\\RCPArsenal\\Media\\DockSort', 134400, 'LINEAR')
check(pending() == 0, 'Identical registration restarted exhausted recovery')
-- A repeated layout while the parent HUD is already hidden must not expose
-- its separately UIParent-owned PANIC control.
combat = false
db.hideWhenSolo, db.demoMode = true, false
RA:RefreshHUD(); RA:RefreshHUD()
check(not named.RCPArsenalHUD:IsShown() and not panic:IsShown(), 'Repeated hidden HUD layout exposed PANIC alone')
print('PASS: ' .. checks .. ' asset/font/actual-frame assertions (offline Lua harness; no WoW runtime claim)')
