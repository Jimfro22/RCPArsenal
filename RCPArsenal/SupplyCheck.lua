local _, RA = ...
local Check = { PREFIX = "RCPArsenalSupply", PROTOCOL = 1, TIMEOUT = 12, COOLDOWN = 20, MAX_PACKET = 100 }
RA.SupplyCheck = Check
local registered, request, snapshot, serial = false, nil, nil, 0
local lastQuery, lastReply = -math.huge, -math.huge
local recent = {}
local queryWindow, queryAttempts = -math.huge, 0
local function Secret(value) return type(issecretvalue) == "function" and issecretvalue(value) end
local function Number(value)
    if Secret(value) or type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
end
local function Now()
    if type(GetTime) ~= "function" then return nil end
    local ok, value = pcall(GetTime); return ok and Number(value) or nil
end
local function Bool(fn)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn)
    if ok and not Secret(value) and type(value) == "boolean" then return value end
end
local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}; for key, item in pairs(value) do result[key] = Copy(item) end; return result
end
local function Notify() RA:FireCallback("SUPPLIES_UPDATED") end
local function Restriction()
    if type(issecretvalue) ~= "function" then return "Supply communication is unavailable." end
    if Bool(InCombatLockdown) ~= false or Bool(IsEncounterInProgress) ~= false then return "Check supplies outside combat and encounters." end
    if not registered or not C_Timer or type(C_Timer.NewTimer) ~= "function" or not Now() then return "Supply communication is unavailable." end
    return RA.Readiness:GetRestrictionReason()
end
local function Send(packet, channel, target)
    if Restriction() or #packet > Check.MAX_PACKET then return false end
    local api = C_ChatInfo and C_ChatInfo.SendAddonMessage
    if type(api) ~= "function" then return false end
    local ok, result = pcall(api, Check.PREFIX, packet, channel, target)
    return ok and not Secret(result) and (result == true or result == 0)
end
local function Finish(status, reason)
    if request and request.timer then request.timer:Cancel() end
    request = nil
    if snapshot then snapshot.status, snapshot.reason, snapshot.completedAt = status, reason, Now() end
    Notify()
end
local function Invalidate(reason)
    if request or snapshot then Finish("stale", reason) end
end
local function Eligibility()
    local reason = Restriction()
    if reason then return false, reason end
    if Bool(IsInRaid) ~= true then return false, "Join a raid to check supplies." end
    if request then return false, "Checking…" end
    if Now() - lastQuery < Check.COOLDOWN then return false, "Wait before checking again." end
    local roster, channel = RA.Readiness:GetGroupIdentitySnapshot()
    if not roster or not channel then return false, "Raid roster unavailable." end
    local player
    for _, row in ipairs(roster.list) do if row.isPlayer then player = row; break end end
    if not player or not player.online or not (player.leader or player.assistant) then return false, "Raid lead or assist required." end
    return true, nil, roster, channel
end
function Check:GetQueryEligibility()
    local ok, reason = Eligibility(); return ok, reason
end
local function Complete()
    for _, row in ipairs(snapshot.rows) do
        if row.online ~= false and row.status ~= "reported" then return false end
    end
    return true
end
function Check:Query()
    local ok, reason, roster, channel = Eligibility()
    if not ok then return false, reason end
    serial = (serial + 1) % 65536
    local nonce = string.format("%x-%x-%x", math.floor(Now() * 1000) % 2147483647, serial, math.random(0, 16777215))
    -- Send before any inventory work: a refused query doesn't scan bags.
    if not Send("Q|1|" .. nonce .. "|" .. RA.HealingSupplies.MAP_REVISION, channel) then return false, "Client did not send the supply request." end
    lastQuery = Now()
    snapshot = { rows = {}, status = "checking", queriedAt = Now(), mapRevision = RA.HealingSupplies.MAP_REVISION }
    request = { nonce = nonce, roster = roster, deadline = Now() + self.TIMEOUT }
    for _, member in ipairs(roster.list) do
        local row = { name = member.name, guid = member.guid, online = member.online,
            status = member.online == false and "offline" or "no_reply" }
        if member.isPlayer then
            local localBags = RA.HealingSupplies:Snapshot()
            row.stone, row.potion, row.respondedAt, row.status = localBags.stone, localBags.potion, Now(), "reported"
        end
        snapshot.rows[#snapshot.rows + 1] = row
    end
    if Complete() then Finish("complete", "All online players reported.")
    else
        request.timer = C_Timer.NewTimer(self.TIMEOUT, function()
            if request and request.nonce == nonce then Finish("complete", "Request finished. No reply remains unknown.") end
        end)
        Notify()
    end
    return true
end
local function Flag(value) return value == true and "1" or value == false and "0" or "u" end
local function Decode(value) if value == "1" then return true elseif value == "0" then return false end end
local function Receive(_, prefix, packet, channel, senderName)
    if Secret(prefix) or Secret(packet) or Secret(channel) or Secret(senderName) then return end
    if prefix ~= Check.PREFIX or type(packet) ~= "string" or #packet > Check.MAX_PACKET or packet:find("%c")
        or type(channel) ~= "string" or type(senderName) ~= "string" or #senderName > 128 or senderName:find("[%c|]") then return end
    -- Parse/reject unrelated or malformed traffic before any roster work.
    local kind, nonce, revision, stone, potion = packet:match("^([QR])|1|([%da-f]+%-[%da-f]+%-[%da-f]+)|(%d+)|?([01u]?)|?([01u]?)$")
    if not kind or #nonce > 24 or revision ~= tostring(RA.HealingSupplies.MAP_REVISION) or Restriction() or Bool(IsInRaid) ~= true then return end
    if kind == "Q" and (packet ~= "Q|1|" .. nonce .. "|" .. revision or channel == "WHISPER" or Now() - lastReply < Check.COOLDOWN) then return end
    if kind == "R" and (packet ~= "R|1|" .. nonce .. "|" .. revision .. "|" .. stone .. "|" .. potion or stone == "" or potion == ""
        or channel ~= "WHISPER" or not request or request.nonce ~= nonce or Now() >= request.deadline) then return end
    if kind == "Q" then
        -- At most eight incoming query identity checks per 20 seconds, and
        -- one inventory evaluation/reply globally per 20 seconds.
        if Now() - queryWindow >= Check.COOLDOWN then queryWindow, queryAttempts = Now(), 0 end
        queryAttempts = queryAttempts + 1
        if queryAttempts > 8 then return end
    else
        -- Duplicates/outsiders can't cause another native roster walk. Only a
        -- pending member of this frozen request may reach current validation.
        local expectedSender = RA.Readiness:ResolveRosterSender(request.roster, senderName)
        if not expectedSender or expectedSender.isPlayer then return end
        local pending = false
        for _, row in ipairs(snapshot.rows) do
            if row.guid == expectedSender.guid and row.status == "no_reply" then pending = true; break end
        end
        if not pending then return end
    end
    local roster, groupChannel = RA.Readiness:GetGroupIdentitySnapshot()
    if not roster then return end
    local sender = RA.Readiness:ResolveRosterSender(roster, senderName)
    if not sender or sender.isPlayer or sender.online ~= true then return end
    if kind == "Q" then
        if channel ~= groupChannel or not (sender.leader or sender.assistant) then return end
        local seen = recent[sender.guid]
        if seen and seen[nonce] then return end
        if not seen then seen = { order = {} }; recent[sender.guid] = seen end
        seen[nonce] = true; seen.order[#seen.order + 1] = nonce
        if #seen.order > 8 then seen[table.remove(seen.order, 1)] = nil end
        lastReply = Now() -- Global responder limit, including failed sends.
        local bags = RA.HealingSupplies:Snapshot()
        Send("R|1|" .. nonce .. "|" .. revision .. "|" .. Flag(bags.stone) .. "|" .. Flag(bags.potion), "WHISPER", sender.name)
    else
        if roster.fingerprint ~= request.roster.fingerprint then Invalidate("Raid roster changed; check again."); return end
        local expected = request.roster.byGUID[sender.guid]
        if not expected or expected.name ~= sender.name then return end
        for _, row in ipairs(snapshot.rows) do
            if row.guid == sender.guid and row.status == "no_reply" then
                row.stone, row.potion, row.status, row.respondedAt = Decode(stone), Decode(potion), "reported", Now()
                if Complete() then Finish("complete", "All online players reported.") else Notify() end
                return
            end
        end
    end
end
function Check:GetSnapshot() return Copy(snapshot or { rows = {}, status = "idle" }) end
RA:RegisterInitializer(function()
    local api = C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix
    if type(api) == "function" then
        local ok, result = pcall(api, Check.PREFIX)
        registered = ok and not Secret(result) and (result == true or result == 0 or result == 1)
    end
end)
RA:RegisterEvent("CHAT_MSG_ADDON", Receive)
for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_DISABLED", "ENCOUNTER_START", "PLAYER_ENTERING_WORLD", "ADDON_RESTRICTION_STATE_CHANGED" }) do
    local eventName = event
    RA:RegisterEvent(eventName, function()
        Invalidate("Raid, combat or communication state changed; check again outside combat.")
        if eventName == "GROUP_ROSTER_UPDATE" or eventName == "PLAYER_ENTERING_WORLD" then recent = {} end
    end)
end
