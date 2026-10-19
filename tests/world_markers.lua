-- Offline Lua 5.1 harness. Does not simulate hardware, taint, or the WoW engine.
local combat, restricted = false, false
local frames, events, messages = {}, {}, {}
local keys = {
    ['CLICK RCPArsenalWorldMarkerCycle:LeftButton'] = 'CTRL-F9',
    ['CLICK RCPArsenalWorldMarkerClear:LeftButton'] = 'CTRL-F10',
}
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
UIParent = {}
function InCombatLockdown() return combat end
function IsInRaid() return false end
function IsInGroup() return false end
function UnitIsGroupLeader() return false end
function UnitIsGroupAssistant() return false end
function GetBindingKey(name) return keys[name] end
for _, name in ipairs({'SetBinding', 'SetBindingClick', 'SaveBindings', 'SetOverrideBinding', 'SetOverrideBindingClick', 'ClearOverrideBindings'}) do
    _G[name] = function() error('Addon must not change native bindings') end
end
local originalPrint = print
print = function(text) messages[#messages + 1] = tostring(text) end
function CreateFrame(kind, name, parent, templates)
    check(not combat or not (templates and templates:find('Secure')), 'Protected frames must be created outside combat')
    local frame = {attrs = {}, scripts = {}, refs = {}, writes = 0, parent = parent}
    function frame:RegisterEvent(event) end
    function frame:SetScript(event, fn) self.scripts[event] = fn end
    function frame:SetSize(w, h) self.width, self.height = w, h end
    function frame:SetPoint(...) end
    function frame:EnableMouse(value) self.mouse = value end
    function frame:RegisterForClicks(...) self.clicks = {...} end
    function frame:SetFrameRef(key, value) check(not combat, 'Frame refs configured in combat'); self.refs[key] = value end
    function frame:GetFrameRef(key) return self.refs[key] end
    function frame:SetAttribute(key, value)
        check(not combat or restricted, 'Insecure protected attribute mutation in combat')
        self.writes = self.writes + 1
        self.attrs[key] = value
    end
    function frame:GetAttribute(key) return self.attrs[key] end
    if name then _G[name] = frame; frames[name] = frame else events[#events + 1] = frame end
    return frame
end
function SecureHandlerWrapScript(frame, script, control, body)
    check(not combat, 'Secure wrapper installed in combat')
    check(script == 'OnClick', 'Unexpected wrapped script')
    check(not body:find('%.%.%.') and not body:find('function') and not body:find('[{}]'), 'Restricted snippet contains unsupported syntax')
    -- The real restricted wrapper uses named self/button/down, not varargs.
    local compile = assert(loadstring('return function(self, button, down)\n' .. body .. '\nend'))
    setfenv(compile, {}) -- No inaccessible WoW globals in the restricted pre-body.
    frame.pre = compile()
end
local function loadAddon()
    frames, events = {}, {}
    RCPArsenalWorldMarkerCycle, RCPArsenalWorldMarkerClear = nil, nil
    local RA = {}
    assert(loadfile('RCPArsenal/Core.lua'))('RCPArsenal', RA)
    assert(loadfile('RCPArsenal/ProfileIO.lua'))('RCPArsenal', RA)
    RA.Categories, RA.CatalogByKey = {}, {}
    assert(loadfile('RCPArsenal/WorldMarkers.lua'))('RCPArsenal', RA)
    events[1].scripts.OnEvent(events[1], 'ADDON_LOADED', 'RCPArsenal')
    return RA, frames.RCPArsenalWorldMarkerCycle, frames.RCPArsenalWorldMarkerClear
end
local function event(name)
    events[1].scripts.OnEvent(events[1], name)
end
local function modified(frame, key)
    -- LeftButton suffix precedence in SecureButton_GetModifiedAttribute is
    -- essential: reserved macro1 would shadow the macrotext action entirely.
    return frame:GetAttribute(key .. '1') or frame:GetAttribute(key)
end
local function click(frame, down)
    restricted = true
    local allowed = frame.pre(frame, 'LeftButton', down)
    restricted = false
    if allowed == false or not down then return nil end
    local kind = modified(frame, 'type')
    if kind == 'macro' then
        if modified(frame, 'macro') then return 'named-macro', modified(frame, 'macro') end
        return 'macrotext', modified(frame, 'macrotext')
    elseif kind == 'worldmarker' then
        return modified(frame, 'action'), modified(frame, 'marker')
    end
end
RaidArsenalDB = {profile = {schemaVersion = 17}}
local RA, cycle, clear = loadAddon()
check(RA.PROFILE_SCHEMA == 19, 'Schema migration missing')
check(not RA:GetDB().worldMarkers.enabled and #RA:GetDB().worldMarkers.order == 8, 'Legacy profile must start off')
check(cycle:GetAttribute('type') == nil and clear:GetAttribute('type') == nil, 'Disabled actions armed')
check(cycle.width == 1 and cycle.height == 1 and cycle.mouse == false, 'Action frames must be quiet and mouse-transparent')
check(click(cycle, true) == nil and click(clear, true) == nil, 'Disabled click did something')
check(RA.WorldMarkers:SetEnabled(true), 'Enable failed')
check(RA.WorldMarkers:SetOrder({8, 4, 8, 0, 9, '2', false, 1}), 'Order setup failed')
check(table.concat(RA:GetDB().worldMarkers.order, ',') == '8,4,2,1', 'Duplicate/invalid markers not normalized')
for _, id in ipairs({8, 4, 2, 1, 8}) do
    local kind, macro = click(cycle, true)
    check(kind == 'macrotext' and macro == '/wm [@cursor] ' .. id, 'Cursor macro or reserved-attribute precedence failed')
    local index = cycle:GetAttribute('index')
    check(click(cycle, false) == nil and cycle:GetAttribute('index') == index, 'Release advanced or acted twice')
end
local kind, marker = click(clear, true)
check(kind == 'clear' and marker == nil, 'Clear all must use native worldmarker clear with nil marker')
check(cycle:GetAttribute('index') == 1, 'Clear did not restart sequence')
check(table.concat(RA:GetDB().worldMarkers.order, ',') == '8,4,2,1', 'Clear altered configured order')
RA.WorldMarkers:SetOrder({})
check(#RA:GetDB().worldMarkers.order == 0 and click(cycle, true) == nil, 'Empty order must stay empty and inactive')
check(click(clear, true) == 'clear', 'Empty sequence must not break the separate clear action')
RA, cycle, clear = loadAddon()
check(#RA:GetDB().worldMarkers.order == 0 and click(cycle, true) == nil, 'Reload silently refilled empty order')
RA.WorldMarkers:SetOrder({7, 3})
combat = true
local before = cycle.writes + clear.writes
check(not RA.WorldMarkers:SetEnabled(false), 'Combat disable should require waiting')
check(not RA.WorldMarkers:SetOrder({1}), 'Combat editing should require waiting')
check(before == cycle.writes + clear.writes, 'Combat setter mutated protected attributes')
local action, macro = click(cycle, true)
check(action == 'macrotext' and macro == '/wm [@cursor] 7', 'Restricted combat cycle failed')
RA:GetDB().worldMarkers.enabled = false -- External profile change; applying is deferred.
RA:FireCallback('PROFILE_RESET')
local effective, pending = RA.WorldMarkers:GetState()
check(effective and pending and before + 2 == cycle.writes + clear.writes, 'Deferred change did not preserve honest effective state')
combat = false
event('PLAYER_REGEN_ENABLED')
effective, pending = RA.WorldMarkers:GetState()
check(not effective and not pending and click(cycle, true) == nil, 'Deferred disable not applied')
check(keys[RA.WorldMarkers.PlaceBinding] == 'CTRL-F9' and keys[RA.WorldMarkers.ClearBinding] == 'CTRL-F10', 'Disable changed player keybindings')
RA.WorldMarkers:SetOrder({2, 6})
local localSettings = RA:GetDB().worldMarkers
local export = assert(RA:ExportProfileString())
check(not export:find('worldMarkers'), 'Local marker config leaked into portable profile')
check(RA:ImportProfileString(export .. '&worldMarkers.enabled=1'), 'Profile import failed')
check(RA:GetDB().worldMarkers == localSettings and not localSettings.enabled and table.concat(localSettings.order, ',') == '2,6', 'Import changed local opt-in or order')
RA.WorldMarkers:SetEnabled(true)
check(RA:ImportProfileString('RA8:mode=COMPACT'), 'Legacy profile import failed')
check(RA:GetDB().worldMarkers.enabled and table.concat(RA:GetDB().worldMarkers.order, ',') == '2,6', 'Legacy import lost explicit local intent')
RA, cycle, clear = loadAddon()
check(RA:GetDB().worldMarkers.enabled and RA.WorldMarkers:GetNextMarker() == 2, 'Enabled saved order did not survive reload')
RA:ResetProfile()
check(not RA:GetDB().worldMarkers.enabled and click(cycle, true) == nil, 'Explicit profile reset must disarm new feature')
RA.WorldMarkers:SetEnabled(true)
combat = true
RA, cycle, clear = loadAddon()
effective, pending = RA.WorldMarkers:GetState()
check(cycle == nil and clear == nil and not effective and pending, 'Reload in combat must defer secure creation')
combat = false
event('PLAYER_REGEN_ENABLED')
check(RA.WorldMarkers:GetState() and frames.RCPArsenalWorldMarkerCycle:GetAttribute('type') == 'macro', 'Deferred initialization did not recover after combat')
for _, text in ipairs(messages) do check(not text:find(' error:'), 'Unexpected callback/initialization error: ' .. text) end
print = originalPrint
print('PASS: ' .. checks .. ' marker/profile/snippet assertions (offline Lua harness; no WoW runtime claim)')
