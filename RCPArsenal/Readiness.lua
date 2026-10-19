local _, RA = ...
local Catalog = RA.AddonCatalog
local Readiness = {}
RA.Readiness = Readiness

Readiness.PREFIX = "RCPArsenalReady"
Readiness.PROTOCOL = 1
Readiness.QUERY_TIMEOUT = 12
Readiness.QUERY_COOLDOWN = 15
Readiness.MAX_PACKET_BYTES = 240
Readiness.SNAPSHOT_LIFETIME = 120
local entries = Catalog.Entries
local snapshot, request, replyQueue
local registered, nonceCounter, generation = false, 0, 0
local lastQuery, lastReply = -math.huge, -math.huge
local recentQueries, receiveCounts = {}, {}
local rosterFingerprint

local function Secret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end
local function Plain(value, limit)
    if Secret(value) or type(value) ~= "string" or #value == 0 or #value > (limit or 128) or value:find("[%c|]") then return nil end
    return value
end
local function Now() return GetTime and GetTime() or 0 end
local function Combat()
    return (InCombatLockdown and InCombatLockdown())
        or (IsEncounterInProgress and IsEncounterInProgress())
end
local function Notify() RA:FireCallback("READINESS_UPDATED") end
local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = Copy(item) end
    return result
end
local function Cancel(timer)
    if timer and type(timer.Cancel) == "function" then timer:Cancel() end
end
local function CancelReply()
    if replyQueue then Cancel(replyQueue.timer); replyQueue = nil end
end
local function CancelRequest()
    if request then Cancel(request.timer); request = nil end
end
local function TimersAvailable()
    return C_Timer and type(C_Timer.NewTimer) == "function"
end

-- A numeric sequence is only ordered within a conservative common format.
-- Suffixes, hashes, different component counts, and unknown schemes stay exact.
local function NumericParts(value)
    if not value:match("^%d+[%.%d]*$") or value:find("%.%.") or value:sub(-1) == "." then return nil end
    local parts = {}
    for token in value:gmatch("[^.]+") do
        if #token > 6 or #parts == 6 then return nil end
        parts[#parts + 1] = tonumber(token)
    end
    return parts
end
function Readiness:CompareVersion(version, target)
    version, target = Catalog:NormalizeVersion(version), Catalog:NormalizeVersion(target)
    if not version then return "unknown" end
    if not target then return "no_target" end
    if version == target then return "current" end
    local actual, approved = NumericParts(version), NumericParts(target)
    if actual and approved and #actual == #approved then
        for i = 1, #actual do
            if actual[i] < approved[i] then return "outdated" end
            if actual[i] > approved[i] then return "ahead" end
        end
    end
    return "different"
end

local function Settings()
    local db = RA:GetDB()
    if type(db) ~= "table" then return nil end
    if type(db.readiness) ~= "table" then db.readiness = {} end
    local settings = db.readiness
    if type(settings.targets) ~= "table" then settings.targets = {} end
    settings.revision = tonumber(settings.revision) or 0
    settings.updatedAt = tonumber(settings.updatedAt) or 0
    settings.origin = type(settings.origin) == "string" and settings.origin or ""
    return settings
end
local function LocalName()
    local name, realm = UnitFullName("player")
    if not Plain(name, 64) then return nil end
    realm = Plain(realm, 64) or (GetNormalizedRealmName and Plain(GetNormalizedRealmName(), 64))
        or (GetRealmName and Plain(GetRealmName(), 64))
    if not realm then return nil end
    return name .. "-" .. realm:gsub("%s", "")
end
local function StampTargets(settings)
    settings.revision = math.min(2147483646, math.max(0, math.floor(settings.revision))) + 1
    settings.updatedAt = time and time() or 0
    settings.origin = LocalName() or "Local character"
    Notify()
end
function Readiness:SetTarget(id, version)
    if Combat() then return false, "Approved targets can be edited outside combat." end
    if not Catalog:GetEntry(id) then return false, "Unknown addon." end
    local settings = Settings()
    if not settings then return false, "Settings are unavailable." end
    if version == "" then version = nil end
    if version ~= nil then
        version = Catalog:NormalizeVersion(version)
        if not version then return false, "Enter an exact version, up to 64 characters; placeholders are unknown." end
    end
    if settings.targets[id] == version then return true end
    settings.targets[id] = version
    StampTargets(settings)
    return true
end
function Readiness:UseLocalTargets()
    if Combat() then return false, "Approved targets can be captured outside combat." end
    local settings = Settings()
    if not settings then return false, "Settings are unavailable." end
    local report, changed = Catalog:RefreshLocal(), 0
    for i = 1, #entries do
        local row = report.byID[entries[i].id]
        if row.installed == true and row.enabled == true and row.version and settings.targets[row.id] ~= row.version then
            settings.targets[row.id] = row.version
            changed = changed + 1
        end
    end
    -- Capture approval is a deliberate action, even when exact versions match.
    StampTargets(settings)
    return true, changed
end
function Readiness:GetTargets()
    return Copy(Settings() or { targets = {}, revision = 0, updatedAt = 0, origin = "" })
end

-- Each snapshot binds realm-qualified names AND GUIDs from ordinary OOC roster
-- APIs. Wire senders never select a unit or inject their own identity.
local function Roster()
    if Combat() then return nil end
    local list, byName, byGUID, fingerprint = {}, {}, {}, {}
    local playerGUID = UnitGUID("player")
    if not Plain(playerGUID, 80) then return nil end
    local function Add(unit)
        local name, realm = UnitFullName(unit)
        local guid = UnitGUID(unit)
        if not Plain(name, 64) or not Plain(guid, 80) then return end
        realm = Plain(realm, 64) or (GetNormalizedRealmName and Plain(GetNormalizedRealmName(), 64))
            or (GetRealmName and Plain(GetRealmName(), 64))
        if not realm then return end
        name = name .. "-" .. realm:gsub("%s", "")
        if byGUID[guid] then return end
        local connected = UnitIsConnected(unit)
        if Secret(connected) or type(connected) ~= "boolean" then connected = nil end
        local leader, assist = UnitIsGroupLeader(unit), UnitIsGroupAssistant(unit)
        leader = not Secret(leader) and leader == true
        assist = not Secret(assist) and assist == true
        local member = { name = name, guid = guid, unit = unit, online = connected,
            leader = leader, assistant = assist, isPlayer = guid == playerGUID }
        list[#list + 1], byName[name:lower()], byGUID[guid] = member, member, member
        fingerprint[#fingerprint + 1] = guid .. ":" .. name .. ":" .. tostring(connected) .. ":" .. tostring(leader) .. ":" .. tostring(assist)
    end
    if IsInRaid() then
        local count = GetNumGroupMembers()
        if Secret(count) or type(count) ~= "number" or count < 1 or count > 40 then return nil end
        for i = 1, count do Add("raid" .. i) end
        if #list ~= count then return nil end
    else
        Add("player")
        local count = IsInGroup() and GetNumSubgroupMembers() or 0
        if Secret(count) or type(count) ~= "number" or count < 0 or count > 4 then return nil end
        for i = 1, count do Add("party" .. i) end
        if #list ~= count + 1 then return nil end
    end
    table.sort(fingerprint)
    return { list = list, byName = byName, byGUID = byGUID, fingerprint = table.concat(fingerprint, ";") }
end
local function GroupChannel()
    if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    return IsInRaid() and "RAID" or (IsInGroup() and "PARTY" or nil)
end

-- Restriction state and actual send results both matter in current clients.
function Readiness:GetRestrictionReason()
    if Combat() then return "Readiness is unavailable during combat or encounters." end
    if C_RestrictedActions and Enum and Enum.AddOnRestrictionType then
        for _, name in ipairs({ "Combat", "Chat", "Encounter" }) do
            local kind = Enum.AddOnRestrictionType[name]
            if kind ~= nil then
                if type(C_RestrictedActions.GetAddOnRestrictionState) == "function" then
                    local ok, state = pcall(C_RestrictedActions.GetAddOnRestrictionState, kind)
                    if not ok or Secret(state) or type(state) ~= "number" or state ~= 0 then
                        return "Addon communication is restricted by the client."
                    end
                elseif type(C_RestrictedActions.IsAddOnRestrictionActive) == "function" then
                    local ok, active = pcall(C_RestrictedActions.IsAddOnRestrictionActive, kind)
                    if not ok or Secret(active) or active ~= false then return "Addon communication is restricted by the client." end
                end
            end
        end
    end
    if C_ChatInfo and type(C_ChatInfo.AreOutgoingAddonChatMessagesRestricted) == "function" then
        local ok, restricted = pcall(C_ChatInfo.AreOutgoingAddonChatMessagesRestricted)
        if not ok or Secret(restricted) or restricted ~= false then return "Outgoing addon communication is restricted by this realm." end
    end
    if not registered then return "Readiness communication is unavailable in this client." end
    if not TimersAvailable() then return "Readiness timers are unavailable in this client." end
    return nil
end
local function Send(message, channel, target)
    if Readiness:GetRestrictionReason() or type(message) ~= "string" or #message > Readiness.MAX_PACKET_BYTES then return false end
    local api = C_ChatInfo and C_ChatInfo.SendAddonMessage
    if type(api) ~= "function" then return false end
    local ok, result = pcall(api, Readiness.PREFIX, message, channel, target)
    -- Numeric enum Success is zero. False/nil and every error stop this batch.
    return ok and not Secret(result) and (result == 0 or result == true)
end

local function UnknownAddons()
    local addons = {}
    for i = 1, #entries do addons[entries[i].id] = { id = entries[i].id } end
    return addons
end
local function LocalMember(member)
    local localReport = Catalog:RefreshLocal()
    member.addons, member.receivedCount, member.status = localReport.byID, #entries, "local"
    member.respondedAt = Now()
end
local function NewSnapshot(roster, state)
    local rows, byGUID = {}, {}
    for i = 1, #roster.list do
        local member = Copy(roster.list[i])
        member.addons = UnknownAddons()
        member.receivedCount = 0
        member.status = member.online == false and "offline" or "unknown"
        if member.isPlayer then LocalMember(member) end
        rows[#rows + 1], byGUID[member.guid] = member, member
    end
    return { rows = rows, byGUID = byGUID, status = state or "idle", generation = generation,
        queriedAt = nil, completedAt = nil, rosterFingerprint = roster.fingerprint }
end
function Readiness:RefreshLocal()
    local roster = Roster()
    if not roster then return false end
    if not snapshot then snapshot = NewSnapshot(roster)
    elseif snapshot.rosterFingerprint ~= roster.fingerprint then
        -- Roster events during combat cannot safely rebuild ordinary unit data.
        -- Compare the snapshot itself after combat, even when the live cache's
        -- fingerprint was cleared while the group was changing.
        CancelRequest()
        CancelReply()
        generation = generation + 1
        snapshot = NewSnapshot(roster, "invalidated")
        snapshot.reason = "The group roster changed; query the group again."
    else
        for i = 1, #snapshot.rows do
            if snapshot.rows[i].isPlayer then LocalMember(snapshot.rows[i]); break end
        end
    end
    rosterFingerprint = roster.fingerprint
    Notify()
    return true
end
local function Invalidate(reason)
    CancelRequest()
    CancelReply()
    generation = generation + 1
    if snapshot then
        snapshot.status, snapshot.reason, snapshot.invalidatedAt = "invalidated", reason, Now()
        for i = 1, #snapshot.rows do
            local member = snapshot.rows[i]
            if not member.isPlayer then
                member.addons, member.receivedCount = UnknownAddons(), 0
                member.status = member.online == false and "offline" or "unknown"
            end
        end
    end
    Notify()
end
local function ValidateRoster(roster)
    roster = roster or Roster()
    if not roster then return nil end
    if rosterFingerprint and rosterFingerprint ~= roster.fingerprint then
        Invalidate("The group roster changed; query the group again.")
        snapshot = NewSnapshot(roster, "invalidated")
        snapshot.reason = "The group roster changed; query the group again."
    end
    rosterFingerprint = roster.fingerprint
    return roster
end
local function Finish(state, reason)
    if not request then return end
    CancelRequest()
    snapshot.status, snapshot.reason, snapshot.completedAt = state, reason, Now()
    for i = 1, #snapshot.rows do
        local member = snapshot.rows[i]
        if not member.isPlayer and member.online ~= false then
            member.status = member.receivedCount == #entries and "complete" or (member.receivedCount > 0 and "partial" or "unknown")
        end
    end
    Notify()
end
local function QueryEligibility()
    local reason = Readiness:GetRestrictionReason()
    if reason then return false, reason end
    if not GroupChannel() then return false, "Join a party or raid to query readiness." end
    local roster = Roster()
    if not roster then return false, "The group roster is not available." end
    local player
    for i = 1, #roster.list do if roster.list[i].isPlayer then player = roster.list[i]; break end end
    if not player or not (player.leader or player.assistant) then return false, "Only the group leader or an assistant can query readiness." end
    if request then return false, "A readiness query is already running." end
    if Now() - lastQuery < Readiness.QUERY_COOLDOWN then return false, "Wait a few seconds before querying again." end
    return true, nil, roster
end
-- Read-only UI eligibility: no cache, settings, callbacks, timers, or comms.
function Readiness:GetQueryEligibility()
    local eligible, reason = QueryEligibility()
    return eligible, reason
end
function Readiness:QueryGroup()
    local eligible, reason, roster = QueryEligibility()
    if not eligible then return false, reason end
    ValidateRoster(roster)
    generation, nonceCounter = generation + 1, nonceCounter + 1
    local nonce = string.format("%x-%x-%x", math.floor(Now() * 1000) % 2147483647, nonceCounter % 65536, math.random(0, 16777215))
    snapshot = NewSnapshot(roster, "checking")
    snapshot.queriedAt = Now()
    request = { nonce = nonce, roster = roster, generation = generation, deadline = Now() + self.QUERY_TIMEOUT, counts = {}, total = 0 }
    if not Send("Q|1|" .. nonce, GroupChannel()) then
        Finish("unavailable", "The client did not send the readiness query; results are unknown.")
        return false, snapshot.reason
    end
    lastQuery = Now()
    local awaiting = false
    for i = 1, #snapshot.rows do
        if not snapshot.rows[i].isPlayer and snapshot.rows[i].online ~= false then awaiting = true; break end
    end
    if not awaiting then Finish("complete", "All online group members responded."); return true end
    request.timer = C_Timer.NewTimer(self.QUERY_TIMEOUT, function()
        if request and request.nonce == nonce then Finish("timeout", "Query finished. No response means unknown; missing is reported explicitly.") end
    end)
    Notify()
    return true
end

local function Split(message)
    local result = {}
    for field in (message .. "|"):gmatch("(.-)|") do
        result[#result + 1] = field
        if #result > 8 then return nil end
    end
    return result
end
local function Hex(value)
    if value == nil then return "-" end
    return (value:gsub(".", function(char) return string.format("%02x", string.byte(char)) end))
end
local function Unhex(value, maximum)
    if value == "-" then return nil, true end
    if #value == 0 or #value > maximum * 2 or #value % 2 ~= 0 or value:find("[^%da-f]") then return nil, false end
    local decoded = value:gsub("..", function(pair) return string.char(tonumber(pair, 16)) end)
    local normalized = Catalog:NormalizeVersion(decoded, maximum)
    return normalized, normalized ~= nil and normalized == decoded
end
local function Flag(value) return value == true and "1" or (value == false and "0" or "u") end
local function Bool(value) if value == "1" then return true elseif value == "0" then return false end end
local function ResponsePacket(nonce, row)
    return table.concat({ "R", "1", nonce, row.id, Flag(row.installed) .. Flag(row.enabled) .. Flag(row.loaded),
        Hex(row.version), Hex(row.id == "arsenal" and row.build or nil), row.id == "arsenal" and tostring(row.protocol or "-") or "-" }, "|")
end
local function BeginReply(roster, sender, nonce)
    if replyQueue or Now() - lastReply < 5 then return end
    local seen = recentQueries[sender.guid]
    if seen and (seen.nonces[nonce] or Now() - seen.at < Readiness.QUERY_COOLDOWN) then return end
    seen = seen or { nonces = {}, order = {} }
    seen.nonces[nonce], seen.at = true, Now()
    seen.order[#seen.order + 1] = nonce
    if #seen.order > 8 then seen.nonces[table.remove(seen.order, 1)] = nil end
    recentQueries[sender.guid] = seen
    lastReply = Now()
    local packets, report = {}, Catalog:RefreshLocal()
    for i = 1, #entries do
        packets[i] = ResponsePacket(nonce, report.rows[i])
        if #packets[i] > Readiness.MAX_PACKET_BYTES then return end
    end
    local queue = { packets = packets, index = 1, senderGUID = sender.guid, target = sender.name, fingerprint = roster.fingerprint, expires = Now() + Readiness.QUERY_TIMEOUT }
    replyQueue = queue
    local function Next()
        if replyQueue ~= queue then return end
        if Readiness:GetRestrictionReason() or Now() >= queue.expires then CancelReply(); return end
        local current = ValidateRoster()
        if not current or replyQueue ~= queue or current.fingerprint ~= queue.fingerprint then CancelReply(); return end
        local authorized = current.byGUID[queue.senderGUID]
        if not authorized or not authorized.online or not (authorized.leader or authorized.assistant)
            or not Send(queue.packets[queue.index], "WHISPER", queue.target) then CancelReply(); return end
        queue.index = queue.index + 1
        if queue.index > #queue.packets then CancelReply()
        else queue.timer = C_Timer.NewTimer(0.20, Next) end
    end
    queue.timer = C_Timer.NewTimer(0.10 + math.random(0, 80) / 100, Next)
end
local function ReceiveResponse(fields, sender)
    if #fields ~= 8 or not request or snapshot.status ~= "checking" or Now() >= request.deadline
        or fields[3] ~= request.nonce or request.generation ~= generation then return end
    local expected = request.roster.byGUID[sender.guid]
    if not expected or expected.name ~= sender.name or expected.online == false or expected.isPlayer then return end
    local member, id = snapshot.byGUID[sender.guid], fields[4]
    if not member or not Catalog:GetEntry(id) or member.addons[id].receivedAt then return end
    if not fields[5]:match("^[01u][01u][01u]$") then return end
    local version, versionOK = Unhex(fields[6], 64)
    local build, buildOK = Unhex(fields[7], 32)
    if not versionOK or not buildOK then return end
    local protocol
    if id == "arsenal" then
        if not fields[8]:match("^%d+$") or #fields[8] > 3 then return end
        protocol = tonumber(fields[8])
        -- Unsupported clients cannot supply trustworthy protocol-one rows.
        if protocol ~= Readiness.PROTOCOL or fields[5]:sub(1, 1) ~= "1" or fields[5]:sub(3, 3) ~= "1" then return end
    elseif fields[7] ~= "-" or fields[8] ~= "-" then return end
    if fields[5]:sub(1, 1) == "0" and (fields[5] ~= "000" or version or build) then return end
    if fields[5]:sub(1, 1) == "u" and (fields[5] ~= "uuu" or version or build) then return end
    member.addons[id] = { id = id, installed = Bool(fields[5]:sub(1, 1)), enabled = Bool(fields[5]:sub(2, 2)),
        loaded = Bool(fields[5]:sub(3, 3)), version = version, build = build, protocol = protocol, receivedAt = Now() }
    member.receivedCount, member.respondedAt = member.receivedCount + 1, Now()
    member.status = member.receivedCount == #entries and "complete" or "responding"
    request.total = request.total + 1
    local done = true
    for i = 1, #snapshot.rows do
        local row = snapshot.rows[i]
        if not row.isPlayer and row.online ~= false and row.receivedCount ~= #entries then done = false; break end
    end
    if done then Finish("complete", "All online group members responded.") else Notify() end
end
local function ResolveSender(roster, senderName)
    if senderName:find("-", 1, true) then return roster.byName[senderName:lower()] end
    -- Same-realm addon events may omit the realm. Bind that spelling only to
    -- an actual local-realm roster member, and reject every short-name clash.
    local realm = GetNormalizedRealmName and Plain(GetNormalizedRealmName(), 64)
        or (GetRealmName and Plain(GetRealmName(), 64))
    if not realm then return nil end
    realm = realm:gsub("%s", "")
    local candidate = roster.byName[(senderName .. "-" .. realm):lower()]
    if not candidate then return nil end
    local matches = 0
    for i = 1, #roster.list do
        if roster.list[i].name:match("^[^-]+"):lower() == senderName:lower() then matches = matches + 1 end
    end
    return matches == 1 and candidate or nil
end
-- Shared identity-only helpers for the independent manual supply protocol.
-- These do not refresh addon metadata or create/query a readiness snapshot.
function Readiness:GetGroupIdentitySnapshot() return Roster(), GroupChannel() end
function Readiness:ResolveRosterSender(roster, senderName) return ResolveSender(roster, senderName) end

local function OnMessage(_, prefix, message, channel, senderName)
    -- Never concatenate, pattern-match, or compare secret event values first.
    if Secret(prefix) or Secret(message) or Secret(channel) or Secret(senderName) then return end
    if type(prefix) ~= "string" or prefix ~= Readiness.PREFIX or type(message) ~= "string"
        or #message == 0 or #message > Readiness.MAX_PACKET_BYTES or message:find("%c")
        or type(channel) ~= "string" or not Plain(senderName, 128)
        or Readiness:GetRestrictionReason() then return end
    local roster = ValidateRoster()
    if not roster then return end
    local sender = ResolveSender(roster, senderName)
    if not sender or sender.isPlayer or sender.online ~= true then return end
    local bucket = receiveCounts[sender.guid]
    if not bucket or Now() - bucket.at >= 15 then bucket = { at = Now(), count = 0 }; receiveCounts[sender.guid] = bucket end
    bucket.count = bucket.count + 1
    if bucket.count > 24 then return end
    local fields = Split(message)
    if not fields or fields[2] ~= "1" or not fields[3] or #fields[3] < 3 or #fields[3] > 24 or not fields[3]:match("^[%da-f]+%-[%da-f]+%-[%da-f]+$") then return end
    if fields[1] == "Q" then
        if #fields ~= 3 or channel ~= GroupChannel() or not (sender.leader or sender.assistant) then return end
        BeginReply(roster, sender, fields[3])
    elseif fields[1] == "R" and channel == "WHISPER" then ReceiveResponse(fields, sender) end
end

local function Decorate(row, targets)
    for i = 1, #entries do
        local addon = row.addons[entries[i].id]
        addon.target = Catalog:NormalizeVersion(targets[addon.id])
        addon.versionState = Readiness:CompareVersion(addon.version, addon.target)
        if row.status == "offline" then addon.state = "offline"
        elseif addon.installed == false then addon.state = "missing"
        elseif addon.installed == nil then addon.state = "unknown"
        elseif addon.enabled == false then addon.state = "disabled"
        elseif addon.loaded == false then addon.state = "not_loaded"
        elseif addon.loaded == nil or addon.enabled == nil then addon.state = "unknown"
        else addon.state = addon.versionState end
    end
end
function Readiness:GetSnapshot()
    if not snapshot and not Combat() then
        local roster = ValidateRoster()
        if roster then snapshot = NewSnapshot(roster) end
    end
    local result = Copy(snapshot or { rows = {}, byGUID = {}, status = "unknown" })
    local settings = Settings() or { targets = {} }
    result.targets, result.revision, result.updatedAt, result.origin = Copy(settings.targets), settings.revision, settings.updatedAt, settings.origin
    result.stale = result.queriedAt ~= nil and Now() - result.queriedAt > self.SNAPSHOT_LIFETIME
    result.restriction = self:GetRestrictionReason()
    result.byGUID = {}
    for i = 1, #result.rows do
        Decorate(result.rows[i], settings.targets)
        result.byGUID[result.rows[i].guid] = result.rows[i]
    end
    return result
end
function Readiness:GetRows() return self:GetSnapshot().rows end
function Readiness:GetStatusText()
    local state = self:GetSnapshot()
    if state.restriction then return state.restriction end
    if state.stale then return "This readiness snapshot is old. Query again for current results." end
    if state.status == "checking" then return "Checking group addon versions…" end
    return state.reason or "Approve exact local versions, then query the group. No response means unknown."
end

RA:RegisterInitializer(function()
    local api = C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix
    if type(api) == "function" then
        local ok, result = pcall(api, Readiness.PREFIX)
        registered = ok and not Secret(result) and (result == true or result == 0 or result == 1)
    end
    Readiness:RefreshLocal()
end)
RA:RegisterEvent("CHAT_MSG_ADDON", OnMessage)
RA:RegisterEvent("GROUP_ROSTER_UPDATE", function()
    if Combat() then Invalidate("The group changed during combat; query again outside combat."); rosterFingerprint = nil; return end
    local roster = ValidateRoster()
    if roster and (not snapshot or snapshot.rosterFingerprint ~= roster.fingerprint) then snapshot = NewSnapshot(roster, "invalidated") end
    -- Bound session-only anti-replay/rate state to actual roster identities.
    if roster then
        for guid in pairs(recentQueries) do if not roster.byGUID[guid] then recentQueries[guid] = nil end end
        for guid in pairs(receiveCounts) do if not roster.byGUID[guid] then receiveCounts[guid] = nil end end
    end
    Notify()
end)
RA:RegisterEvent("PLAYER_REGEN_DISABLED", function() Invalidate("Combat began; query again outside combat.") end)
RA:RegisterEvent("ENCOUNTER_START", function() Invalidate("An encounter began; query again afterward.") end)
RA:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    Invalidate("The world changed; query again for current results.")
    rosterFingerprint = nil
    if not Combat() then snapshot = nil; Readiness:RefreshLocal() end
end)
RA:RegisterEvent("PLAYER_REGEN_ENABLED", function() Readiness:RefreshLocal() end)
RA:RegisterCallback("PROFILE_RESET", function() Notify() end)
RA:RegisterCallback("PROFILE_IMPORTED", function() Notify() end)

RA:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED", function(_, kind, state)
    if Secret(kind) or Secret(state) or type(kind) ~= "number" or type(state) ~= "number" then return end
    local types = Enum and Enum.AddOnRestrictionType
    if types and (kind == types.Combat or kind == types.Chat or kind == types.Encounter) and state ~= 0 then
        -- The API's IsActive predicate is false during this pre-activation event.
        Invalidate("Client communication restrictions changed; query again when available.")
    end
end)
