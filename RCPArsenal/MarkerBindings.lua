local _, RA = ...
local Bindings = {}
RA.MarkerBindings = Bindings

-- Only these three native CLICK actions are editable here. This module
-- never invokes them, changes their secure attributes or installs overrides.
local pending, writing, cancelledRelease
local status = "Click a key slot to edit."
local function Secret(value) return type(issecretvalue) == "function" and issecretvalue(value) end
local function Text(value, maximum)
    return not Secret(value) and type(value) == "string" and #value > 0 and #value <= (maximum or 256)
        and not value:find("[%z\r\n]")
end
local function Action(action)
    return Text(action) and RA.WorldMarkers and (action == RA.WorldMarkers.PlaceBinding or action == RA.WorldMarkers.ClearBinding or action == RA.WorldMarkers.WheelBinding)
end
local function Call(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end
local function OutOfCombat()
    local ok, value = Call(InCombatLockdown)
    return ok and not Secret(value) and value == false
end
local function Scope()
    local ok, value = Call(GetCurrentBindingSet)
    if ok and not Secret(value) and (value == 1 or value == 2) then return value end
end
local function ScopeLabel(scope)
    return scope == 1 and "Account keybinds" or scope == 2 and "Character keybinds" or "Binding scope unavailable"
end
local function Context(action)
    local ok, value = Call(C_KeyBindings and C_KeyBindings.GetBindingContextForAction, action)
    if not ok or Secret(value) then return false end
    if value ~= nil and (type(value) ~= "number" or value < 0 or value ~= math.floor(value) or value == math.huge) then return false end
    return true, value
end
local function Keys(action, context)
    local ok, first, second, extra = Call(GetBindingKey, action, nil, context)
    if not ok or Secret(first) or Secret(second) or Secret(extra) or extra ~= nil
        or (first ~= nil and not Text(first, 96)) or (second ~= nil and not Text(second, 96)) then return nil end
    return {first, second}
end
local function BindingAt(key, context)
    local ok, value = Call(GetBindingAction, key, false, context)
    if not ok or Secret(value) or type(value) ~= "string" or #value > 256 or value:find("[%z\r\n]") then return nil end
    return value
end
local function SameKeys(a, b) return a and b and a[1] == b[1] and a[2] == b[2] end
local function Compact(keys)
    local result = {}
    for index = 1, 2 do if keys[index] then result[#result + 1] = keys[index] end end
    return result
end
local function Label(action)
    if RA.WorldMarkers and action == RA.WorldMarkers.PlaceBinding then return "Place next world marker" end
    if RA.WorldMarkers and action == RA.WorldMarkers.ClearBinding then return "Clear all world markers" end
    if RA.WorldMarkers and action == RA.WorldMarkers.WheelBinding then return "Hold world marker wheel" end
    local ok, value = Call(GetBindingName, action)
    return ok and Text(value) and value or action
end
local function Notify() RA:FireCallback("MARKER_BINDINGS_CHANGED") end
function Bindings:Cancel(reason)
    if pending and pending.releaseKey then cancelledRelease = pending.releaseKey end
    pending = nil
    if reason then status = reason end
    Notify()
end
function Bindings:GetStatusText() return status end
function Bindings:GetHeldKey() return cancelledRelease or (pending and pending.releaseKey) end
function Bindings:IsHeldRelease(input)
    if not cancelledRelease or not Text(input, 96) then return false end
    local ok, key = Call(GetConvertedKeyOrButton, input)
    return ok and Text(key, 96) and key == cancelledRelease
end
function Bindings:GetState(action)
    local scope = Scope()
    local ok, context = Context(action)
    local keys = ok and Action(action) and Keys(action, context)
    return {keys = keys or {}, available = scope ~= nil and keys ~= nil,
        editable = scope ~= nil and keys ~= nil and not cancelledRelease and OutOfCombat() and type(SetBinding) == "function" and type(SaveBindings) == "function",
        scope = scope, scopeLabel = ScopeLabel(scope), status = status}
end
function Bindings:GetPending()
    if not pending then return nil end
    return {action = pending.action, label = Label(pending.action), slot = pending.slot, currentKey = pending.keys[pending.slot],
        scopeLabel = ScopeLabel(pending.scope), proposedKey = pending.key,
        awaitingRelease = pending.releaseKey ~= nil,
        conflict = pending.conflict ~= nil and pending.conflict ~= "", conflictLabel = pending.conflict and Label(pending.conflict)}
end
function Bindings:Begin(action, slot)
    if not OutOfCombat() then return false, "Change keybinds after combat." end
    if cancelledRelease then return false, "Release the previous captured key first." end
    if not Action(action) or Secret(slot) or (slot ~= 1 and slot ~= 2) then return false, "Choose a marker key slot." end
    local state = self:GetState(action)
    local ok, context = Context(action)
    if not state.editable or not ok or type(GetBindingAction) ~= "function" then return false, "Key editing unavailable; use WoW keybinds." end
    pending = {action = action, slot = slot, scope = state.scope, context = context, keys = state.keys}
    status = "Press a key. Escape cancels."
    Notify()
    return true
end
local function StillCurrent(edit)
    if not OutOfCombat() then return false, "Change keybinds after combat." end
    local ok, context = Context(edit.action)
    if Scope() ~= edit.scope or not ok or context ~= edit.context or not SameKeys(Keys(edit.action, context), edit.keys) then
        return false, "Bindings or scope changed; choose the slot again."
    end
    return true
end
local function Write(key, action, context)
    if not OutOfCombat() then return false end
    local ok, value = Call(SetBinding, key, action, context)
    return ok and not Secret(value) and value == true
end
local function Save(scope)
    if not OutOfCombat() or Scope() ~= scope then return false end
    local ok, value = Call(SaveBindings, scope)
    -- The native editor does not use a SaveBindings return value. Accept its
    -- normal nil result, but not an explicit false/secret/error.
    return ok and not Secret(value) and (value == nil or value == true) and Scope() == scope
end
local function Restore(backup, context, scope)
    if not OutOfCombat() or Scope() ~= scope then return false end
    local touched, restored = {}, true
    for _, row in ipairs(backup) do
        for index = 1, 2 do if row.keys[index] then touched[row.keys[index]] = true end end
    end
    for key in pairs(touched) do if not Write(key, nil, context) then restored = false end end
    for _, row in ipairs(backup) do
        for index = 1, 2 do
            if row.keys[index] and row.action ~= "" and not Write(row.keys[index], row.action, context) then restored = false end
        end
    end
    for _, row in ipairs(backup) do
        for index = 1, 2 do
            if row.keys[index] and BindingAt(row.keys[index], context) ~= row.action then restored = false end
        end
    end
    return restored and Save(scope)
end
local function Commit(replace)
    local edit = pending
    if not edit then return false, "Choose a key slot first." end
    if edit.releaseKey then return false, "Release the captured key first." end
    local valid, reason = StillCurrent(edit)
    if not valid then Bindings:Cancel(reason); return false, reason end
    local conflict = ""
    if edit.key then conflict = BindingAt(edit.key, edit.context) end
    if conflict == nil then return false, "Current key assignment unavailable." end
    if conflict ~= "" and conflict ~= edit.action then
        if not replace or conflict ~= edit.conflict then
            edit.conflict = conflict
            status = "This key is assigned to another action. Replace or Cancel."
            Notify(); return false, "conflict"
        end
    end
    local backup = {{action = edit.action, keys = edit.keys}}
    if conflict ~= "" and conflict ~= edit.action then
        backup[#backup + 1] = {action = conflict, keys = {edit.key}}
    end
    -- Include a previously unassigned candidate in rollback too, so a failed
    -- save cannot leave it bound. No global LoadBindings/reset is used.
    if edit.key and conflict == "" then backup[#backup + 1] = {action = "", keys = {edit.key}} end
    local desired = {edit.keys[1], edit.keys[2]}; desired[edit.slot] = edit.key
    desired = Compact(desired)
    writing = true
    local success = true
    for index = 1, 2 do if edit.keys[index] and not Write(edit.keys[index], nil, edit.context) then success = false; break end end
    if success then
        for _, key in ipairs(desired) do if not Write(key, edit.action, edit.context) then success = false; break end end
    end
    success = success and SameKeys(Keys(edit.action, edit.context), desired)
    if success then success = Save(edit.scope) and SameKeys(Keys(edit.action, edit.context), desired) end
    if success then
        status = (edit.key and "Binding saved. " or "Key unbound. ") .. ScopeLabel(edit.scope) .. "."
    else
        local restored = Restore(backup, edit.context, edit.scope)
        status = restored and "Change failed; previous bindings restored." or "Change failed; bindings may have changed. Check WoW keybinds."
    end
    writing, pending = nil, nil
    Notify()
    return success, status
end
function Bindings:Capture(input)
    if not pending then return false, "Choose a key slot first." end
    if not OutOfCombat() then self:Cancel("Change keybinds after combat."); return false, status end
    if not Text(input, 96) then return false, "Unsupported key." end
    if pending.releaseKey then
        if input == "ESCAPE" then
            pending.cancelOnRelease = true; status = "Release the captured key to cancel."; Notify()
        end
        return false, "Release the captured key first."
    end
    if input == "ESCAPE" then
        pending.releaseKey, pending.cancelOnRelease = "ESCAPE", true
        status = "Release Escape to cancel."; Notify(); return false, status
    end
    local ok, key = Call(GetConvertedKeyOrButton, input)
    if not ok or not Text(key, 96) then return false, "Key capture unavailable; use WoW keybinds." end
    local ignored, ignore = Call(IsKeyPressIgnoredForBinding, key)
    if not ignored or Secret(ignore) or type(ignore) ~= "boolean" then return false, "Key capture unavailable; use WoW keybinds." end
    if ignore then return false, "Press a key with the modifier." end
    local chordOK, chord = Call(CreateKeyChordStringUsingMetaKeyState, key)
    if not chordOK or not Text(chord, 96) then return false, "Key chord unavailable." end
    pending.key, pending.conflict, pending.releaseKey = chord, nil, key
    status = "Release the captured key to continue."
    Notify(); return false, status
end
function Bindings:Release(input)
    if cancelledRelease then
        if self:IsHeldRelease(input) then cancelledRelease = nil; Notify() end
        return false, status
    end
    if not pending or not pending.releaseKey then return false end
    local ok, key = Call(GetConvertedKeyOrButton, input)
    if not ok or not Text(key, 96) or key ~= pending.releaseKey then return false end
    pending.releaseKey = nil
    if pending.cancelOnRelease then self:Cancel("Binding cancelled."); return false, status end
    if pending.key == pending.keys[pending.slot] then self:Cancel("Binding unchanged."); return true, status end
    if pending.key == pending.keys[3 - pending.slot] then
        pending.key = nil; status = "Already assigned in the other slot; choose another key."
        Notify(); return false, status
    end
    return Commit(false)
end
function Bindings:Replace() return Commit(true) end
function Bindings:Clear(action, slot)
    local ok, reason = self:Begin(action, slot)
    if not ok then return false, reason end
    if not pending.keys[slot] then self:Cancel("Key already unbound."); return true, status end
    return Commit(false)
end
RA:RegisterEvent("PLAYER_REGEN_DISABLED", function() Bindings:Cancel("Change keybinds after combat.") end)
RA:RegisterEvent("UPDATE_BINDINGS", function()
    if pending and not writing then Bindings:Cancel("Bindings changed; choose the slot again.") end
end)
RA:RegisterCallback("PROFILE_RESET", function() Bindings:Cancel("Binding cancelled.") end)
