-- Lua 5.1 behavior harness for the passive protocol. No engine/taint simulation.
local checks = 0
local function check(value, message) checks = checks + 1; assert(value, message) end
local clock, combat, grouped, raid, timers, sent, units, addons, db, restriction
local events, callbacks, initializers, prefixResult, sendResult, secretToken, addonCalls, arsenalEnableState
local RA
local function Advance(seconds)
    local untilTime = clock + seconds
    while true do
        local candidate
        for _, timer in ipairs(timers) do
            if not timer.cancelled and not timer.fired and timer.at <= untilTime
                and (not candidate or timer.at < candidate.at) then candidate = timer end
        end
        if not candidate then break end
        clock = candidate.at
        candidate.fired = true
        candidate.fn()
    end
    clock = untilTime
end
local function Event(name, ...)
    for _, fn in ipairs(events[name] or {}) do fn(name, ...) end
end
local function Member(name, guid, leader, assist, online)
    return {name = name, realm = "TestRealm", guid = guid, leader = leader or false, assist = assist or false, online = online ~= false}
end
local function Setup(options)
    options = options or {}
    clock, combat, grouped, raid, timers, sent, restriction = 100, false, true, false, {}, {}, false
    events, callbacks, initializers, addonCalls = {}, {}, {}, {}
    prefixResult, sendResult = options.prefixResult or 0, options.sendResult or 0
    arsenalEnableState = 2
    units = { player = Member("Lead", "Player-1", true), party1 = Member("Mage", "Player-2"), party2 = Member("Rogue", "Player-3", false, false, false) }
    addons = {
        {name = "NorthernSkyRaidTools", version = "1.2.3", enabled = 2, loaded = true},
        {name = "RCLootCouncil", version = "3.4.0", enabled = 0, loaded = false},
        {name = "Simulationcraft", version = "@project-version@", enabled = 2, loaded = false, loading = true},
        {name = "wowutils", version = "1.0.7", enabled = 2, loaded = true},
        {name = "BigWigs", version = "v400-alpha", enabled = 2, loaded = true},
    }
    db = {readiness = {targets = {autopotion = "3.0.0", simulationcraft = "12.1.0-01"}, revision = 0, updatedAt = 0, origin = ""}, shown = false, demoMode = false,
        scan = {showStrip = false}, worldMarkers = {enabled = false}, leaderToolbox = {enabled = false}}
    function GetTime() return clock end
    function time() return 2000000 + math.floor(clock) end
    function InCombatLockdown() return combat end
    function IsInRaid() return raid end
    function IsInGroup(category) if category == 2 then return false end; return grouped end
    function GetNumSubgroupMembers() return grouped and 2 or 0 end
    function GetNumGroupMembers() return raid and 3 or (grouped and 3 or 0) end
    function UnitFullName(unit) local row = units[unit]; if row then return row.name, row.realm end end
    function UnitName(unit) return units[unit] and units[unit].name end
    function UnitGUID(unit) return units[unit] and units[unit].guid end
    function UnitIsConnected(unit) return units[unit] and units[unit].online end
    function UnitIsGroupLeader(unit) return units[unit] and units[unit].leader end
    function UnitIsGroupAssistant(unit) return units[unit] and units[unit].assist end
    function UnitIsUnit(a, b) return units[a] == units[b] end
    function GetNormalizedRealmName() return "TestRealm" end
    LE_PARTY_CATEGORY_INSTANCE = 2
    secretToken = setmetatable({}, {__tostring = function() error("secret stringification") end})
    function issecretvalue(value) return rawequal(value, secretToken) end
    C_Timer = {NewTimer = function(delay, fn)
        local timer = {at = clock + delay, fn = fn}
        function timer:Cancel() self.cancelled = true end
        timers[#timers + 1] = timer
        return timer
    end}
    C_RestrictedActions = {GetAddOnRestrictionState = function(kind) return restriction and 2 or 0 end}
    Enum = {AddOnRestrictionType = {Combat = 0, Encounter = 1, Chat = 5}}
    C_ChatInfo = {
        RegisterAddonMessagePrefix = function(prefix) check(#prefix <= 16, "prefix too long"); return prefixResult end,
        SendAddonMessage = function(prefix, message, channel, target)
            check(not combat and not restriction, "Sent under a restriction")
            check(#message <= 240, "packet exceeds 240 bytes")
            sent[#sent + 1] = {prefix = prefix, message = message, channel = channel, target = target}
            return sendResult
        end,
    }
    local function Find(folder)
        for _, row in ipairs(addons) do if row.name == folder then return row end end
    end
    C_AddOns = {
        GetNumAddOns = function() return #addons end,
        GetAddOnInfo = function(index) return addons[index].name end,
        GetAddOnEnableState = function(folder, character)
            check(character == "Player-1", "enable state did not query current character GUID")
            addonCalls[#addonCalls + 1] = {folder, character}
            if folder == "RCPArsenal" then return arsenalEnableState end
            return Find(folder).enabled
        end,
        IsAddOnLoaded = function(folder) local row = Find(folder); return row.loaded or row.loading or false, row.loaded end,
        GetAddOnMetadata = function(folder, key) check(key == "Version", "wrong metadata"); return Find(folder).version end,
    }
    for _, name in ipairs({"NotifyInspect", "SendChatMessage", "LoadAddOn", "EnableAddOn", "DisableAddOn", "CreateFrame"}) do
        _G[name] = function() error("Readiness touched gameplay/scan/UI: " .. name) end
    end
    RA = {VERSION = "0.15.0-alpha.1", BUILD = "0.15.0-alpha.1", READINESS_PROTOCOL = 1, ADDON_NAME = "RCPArsenal"}
    function RA:GetDB() return db end
    function RA:RegisterInitializer(fn) initializers[#initializers + 1] = fn end
    function RA:RegisterEvent(name, fn) events[name] = events[name] or {}; table.insert(events[name], fn) end
    function RA:RegisterCallback(name, fn) callbacks[name] = callbacks[name] or {}; table.insert(callbacks[name], fn) end
    function RA:FireCallback(name, ...) for _, fn in ipairs(callbacks[name] or {}) do fn(...) end end
    RA.StartInspection = function() error("readiness started a scan") end
    assert(loadfile("RCPArsenal/AddonCatalog.lua"))("RCPArsenal", RA)
    assert(loadfile("RCPArsenal/Readiness.lua"))("RCPArsenal", RA)
    for _, fn in ipairs(initializers) do fn() end
    return RA.Readiness, RA.AddonCatalog
end
local function Hex(value) return (value:gsub(".", function(c) return string.format("%02x", c:byte()) end)) end
local function Nonce()
    return sent[#sent].message:match("^Q|1|(.+)$")
end
local function Deliver(message, sender, channel)
    Event("CHAT_MSG_ADDON", RA.Readiness.PREFIX, message, channel or "WHISPER", sender or "Mage-TestRealm")
end
local function Response(nonce, id, flags, version, build, protocol)
    return table.concat({"R", "1", nonce, id or "northernsky", flags or "111", version and Hex(version) or "-", build and Hex(build) or "-", tostring(protocol or "-")}, "|")
end
local function Mage() return RA.Readiness:GetSnapshot().byGUID["Player-2"] end

local R, C = Setup()
local report = C:GetLocalReport()
check(#C.Entries == 7 and #report.rows == 7, "catalog must include six tools and Arsenal")
check(report.byID.autopotion.installed == false, "absent addon not detected")
check(report.byID.rclootcouncil.enabled == false and report.byID.rclootcouncil.status == "disabled", "disabled state lost")
check(report.byID.simulationcraft.loaded == false, "loading was misreported as loaded")
check(report.byID.simulationcraft.version == nil, "packager placeholder became a version")
check(report.byID.wowutils.folder == "wowutils", "canonical lowercase folder not detected")
check(report.byID.arsenal.version == RA.VERSION and report.byID.arsenal.build == RA.BUILD and report.byID.arsenal.protocol == 1, "Arsenal identity incomplete")
report.byID.northernsky.version = "mutated"
check(C:GetLocalReport().byID.northernsky.version == "1.2.3", "caller mutated cached local report")
check(C:NormalizeVersion(secretToken) == nil, "secret version accepted")
for _, version in ipairs({"", "unknown", "@project-version@", "latest", "${VERSION}", "1\n2", string.rep("1", 65)}) do check(C:NormalizeVersion(version) == nil, "bad version accepted") end
local states = {
    {"1.2.3", "1.2.3", "current"}, {"1.2.2", "1.2.3", "outdated"}, {"1.2.4", "1.2.3", "ahead"},
    {"1.2.3-alpha", "1.2.3", "different"}, {"12.1.0-01", "12.1.0-02", "different"},
    {"v400-alpha", "v400-beta", "different"}, {"1.2", "1.2.0", "different"}, {"1.02", "1.2", "different"},
    {"10000000.2", "9999999.2", "different"}, {nil, "1.2", "unknown"}, {"1.2", nil, "no_target"},
}
for _, case in ipairs(states) do check(R:CompareVersion(case[1], case[2]) == case[3], "unsafe version ordering") end
check(not R:SetTarget("bad", "1.0"), "unknown target ID accepted")
check(not R:SetTarget("northernsky", "latest"), "bad approved target accepted")
check(R:UseLocalTargets(), "capture failed")
check(db.readiness.targets.autopotion == "3.0.0" and db.readiness.targets.simulationcraft == "12.1.0-01", "capture erased missing/unknown target")
check(db.readiness.targets.northernsky == "1.2.3" and db.readiness.origin == "Lead-TestRealm" and db.readiness.updatedAt > 0, "approved target stamp incomplete")
check(db.readiness.revision == 1, "capture did not increment revision")
check(db.readiness.targets.rclootcouncil == nil, "capture approved a disabled addon")
check(R:SetTarget("northernsky", "1.2.4") and db.readiness.revision == 2, "manual target save failed")
check(R:SetTarget("northernsky", "") and db.readiness.targets.northernsky == nil, "clear target failed")
combat = true
check(not R:SetTarget("northernsky", "1.2.4") and not R:UseLocalTargets(), "combat edited approval")
combat = false
check(not db.shown and not db.scan.showStrip and not db.leaderToolbox.enabled and not db.worldMarkers.enabled, "passive reporting changed feature toggles")

R = Setup()
check(R:QueryGroup(), "leader query rejected")
local nonce = Nonce()
check(#sent == 1 and sent[1].channel == "PARTY", "query did more than one group fanout")
check(R:GetSnapshot().status == "checking", "query status missing")
check(R:GetSnapshot().byGUID["Player-3"].status == "offline", "offline member not distinct")
check(Mage().status == "unknown" and Mage().addons.northernsky.state == "unknown", "no response became missing")
Deliver(Response(nonce, "northernsky", "111", "1.2.3"), "Intruder-TestRealm")
Deliver(Response(nonce, "northernsky", "111", "1.2.3"), nil, "PARTY")
Deliver(Response(nonce .. "a", "northernsky", "111", "1.2.3"))
Deliver((Response(nonce, "northernsky", "111", "1.2.3"):gsub("R|1", "R|2", 1)))
Deliver(Response(nonce, "bad", "111", "1.2.3"))
Deliver(Response(nonce, "northernsky", "100", "1.2.3") .. "|extra")
Deliver(Response(nonce, "northernsky", "000", "1.2.3"))
Deliver(Response(nonce, "northernsky", "uuu", "1.2.3"))
Deliver(Response(nonce, "arsenal", "111", "0.15.0", "0.15.0", 2))
Deliver("R|1|" .. nonce .. "|northernsky|111|zz|-|-")
Deliver(string.rep("x", 251))
Event("CHAT_MSG_ADDON", R.PREFIX, secretToken, "WHISPER", "Mage-TestRealm")
Event("CHAT_MSG_ADDON", secretToken, "x", "WHISPER", "Mage-TestRealm")
check(Mage().receivedCount == 0, "malformed/unauthorized/unsupported response accepted")
Deliver(Response(nonce, "northernsky", "111", "1.2.3"))
check(Mage().receivedCount == 1 and Mage().status == "responding", "valid response rejected")
Deliver(Response(nonce, "northernsky", "000"))
check(Mage().receivedCount == 1 and Mage().addons.northernsky.installed, "duplicate rewrote accepted data")
Advance(13)
check(R:GetSnapshot().status == "timeout" and Mage().status == "partial", "timeout did not preserve partial response")
check(Mage().addons.autopotion.state == "unknown", "partial missing packet became missing addon")
Deliver(Response(nonce, "autopotion", "000"))
check(Mage().receivedCount == 1, "late response accepted")
check(not R:QueryGroup(), "cooldown not enforced")
Advance(3)
check(R:QueryGroup(), "query after cooldown rejected")
local nextNonce = Nonce()
check(nextNonce ~= nonce, "nonce reused")
Deliver(Response(nonce, "autopotion", "000"))
check(Mage().receivedCount == 0, "old nonce replay accepted")
for _, entry in ipairs(RA.AddonCatalog.Entries) do
    if entry.id == "arsenal" then Deliver(Response(nextNonce, entry.id, "111", "0.15.0-alpha.1", "0.15.0-alpha.1", 1))
    else Deliver(Response(nextNonce, entry.id, entry.id == "autopotion" and "000" or "111", entry.id ~= "autopotion" and "1.2.3" or nil)) end
end
check(R:GetSnapshot().status == "complete" and Mage().status == "complete", "full response did not complete")
check(Mage().addons.autopotion.state == "missing", "explicit missing report not shown")
Advance(121)
check(R:GetSnapshot().stale, "old snapshot not flagged")

R = Setup()
check(R:QueryGroup(), "query failed")
nonce = Nonce()
units.party1.guid = "Player-Replacement"
Deliver(Response(nonce, "autopotion", "000"))
check(R:GetSnapshot().status == "invalidated", "roster GUID replacement did not invalidate")
check(R:GetSnapshot().byGUID["Player-Replacement"].receivedCount == 0, "old response assigned to replacement")
Advance(13)
check(R:GetSnapshot().status == "invalidated", "cancelled timeout rewrote invalidation")

R = Setup()
check(R:QueryGroup(), "query failed")
nonce = Nonce()
combat = true
Event("PLAYER_REGEN_DISABLED")
Deliver(Response(nonce, "autopotion", "000"))
Advance(20)
check(#sent == 1 and R:GetSnapshot().status == "invalidated" and Mage().receivedCount == 0, "combat did not cancel/ignore query")
check(not R:QueryGroup(), "combat query accepted")
combat = false
restriction = true
check(not R:QueryGroup(), "client chat restriction ignored")
restriction = false

-- An ordinary member responds passively to an actual leader, with optional
-- tools, HUD, scan, marker and Quick Bar toggles all disabled.
R = Setup()
units.player.leader, units.party1.leader = false, true
check(not R:QueryGroup(), "nonleader queried group")
Deliver("Q|1|a-b-c", "Mage-TestRealm", "PARTY")
Advance(4)
check(#sent == 7, "authorized query did not yield exactly seven bounded rows")
for _, packet in ipairs(sent) do check(packet.channel == "WHISPER" and packet.target == "Mage-TestRealm", "response fanout target was not actual requester") end
Deliver("Q|1|a-b-c", "Mage-TestRealm", "PARTY")
Advance(16)
check(#sent == 7, "query replay produced more responses")
Deliver("Q|1|d-e-f", "Mage-TestRealm", "PARTY")
combat = true
Event("PLAYER_REGEN_DISABLED")
Advance(4)
check(#sent == 7, "combat did not cancel reply timers")
combat = false
Advance(16)
Deliver("Q|1|d-e-1", "Mage-TestRealm", "PARTY")
units.party1.guid = "Player-ReplacedLeader"
Advance(4)
check(#sent == 7, "roster change did not cancel queued replies")

R = Setup()
Deliver("Q|1|a-b-c", "Mage-TestRealm", "PARTY")
Advance(4)
check(#sent == 0, "nonleader query elicited response")
units.party1.assist = true
Deliver("Q|1|d-e-f", "Mage-TestRealm", "WHISPER")
Advance(4)
check(#sent == 0, "whisper query accepted")
Deliver("Q|1|d-e-f", "Mage-TestRealm", "PARTY")
sendResult = 8
Advance(4)
check(#sent == 1, "throttled reply was retried or batch continued")

R = Setup({sendResult = 11})
check(not R:QueryGroup() and R:GetSnapshot().status == "unavailable", "send lockdown enum treated as success")
Advance(20)
check(#sent == 1, "failed send retried")
R = Setup({prefixResult = 2})
check(not R:QueryGroup() and #sent == 0, "invalid prefix enum treated as success")
R = Setup({prefixResult = 1})
check(R:QueryGroup(), "duplicate prefix result should allow communication")

R, C = Setup()
C_AddOns.GetAddOnInfo = function() error("metadata unavailable") end
local unknownReport = C:RefreshLocal()
check(unknownReport.byID.autopotion.installed == nil, "failed enumeration became missing")
C_AddOns.GetNumAddOns = function() return secretToken end
check(C:RefreshLocal().byID.bigwigs.status == "unknown", "secret API count inspected")
R = Setup()
check(R:QueryGroup(), "query failed")
nonce = Nonce()
local nativeFullName=UnitFullName;local malformedIdentityReads=0
UnitFullName=function(...) malformedIdentityReads=malformedIdentityReads+1;return nativeFullName(...) end
for i = 1, 25 do Deliver("bad") end
check(malformedIdentityReads==0,'Malformed packet caused roster identity walks')
Deliver(Response(nonce, "autopotion", "000"))
check(Mage().receivedCount == 0, "per-sender receive rate bound missing")
UnitFullName=nativeFullName

R = Setup()
units.party1.online = false
check(R:QueryGroup() and R:GetSnapshot().status == "complete", "offline members delayed query completion")
R = Setup()
units.party1.guid = nil
check(not R:QueryGroup(), "incomplete ordinary roster produced an incomplete snapshot")
R = Setup()
check(R:QueryGroup(), "query failed")
Event("ADDON_RESTRICTION_STATE_CHANGED", 5, 1)
Advance(20)
check(R:GetSnapshot().status == "invalidated", "pre-activation restriction event did not cancel query")
C_ChatInfo.AreOutgoingAddonChatMessagesRestricted = function() return true end
check(not R:QueryGroup(), "realm-wide outgoing comm restriction ignored")
C_ChatInfo.AreOutgoingAddonChatMessagesRestricted = function() return false end
C_RestrictedActions.GetAddOnRestrictionState = function() return 1 end
check(not R:QueryGroup(), "activating restriction treated as inactive")
C_RestrictedActions.GetAddOnRestrictionState = function() return secretToken end
check(not R:QueryGroup(), "secret restriction state inspected")
C_RestrictedActions.GetAddOnRestrictionState = function() return 0 end
IsEncounterInProgress = function() return true end
check(not R:QueryGroup(), "direct encounter state ignored")
IsEncounterInProgress = nil

-- Round-trip actual encoded catalog packets, including long exact metadata.
R = Setup()
units.player.leader, units.party1.leader = false, true
addons[1].version = string.rep("1", 64)
RA.BUILD = string.rep("2", 32)
Deliver("Q|1|a-b-c", "Mage-TestRealm", "PARTY")
Advance(4)
local actualPackets = sent
check(#actualPackets == 7, "long legal metadata stopped a response batch")
R = Setup()
check(R:QueryGroup(), "query failed")
nonce = Nonce()
for _, packet in ipairs(actualPackets) do Deliver((packet.message:gsub("a%-b%-c", nonce, 1))) end
check(R:GetSnapshot().status == "complete", "actual encoded catalog packets failed round-trip")
check(Mage().addons.northernsky.version == string.rep("1", 64), "exact long version changed on wire")
check(Mage().addons.arsenal.build == string.rep("2", 32), "Arsenal build changed on wire")

-- Eligibility mirrors query gates and remains a read-only API for the UI.
R = Setup()
local callbacksSeen = 0
RA:RegisterCallback("READINESS_UPDATED", function() callbacksSeen = callbacksSeen + 1 end)
local beforeGeneration, beforeTimers = R:GetSnapshot().generation, #timers
for i = 1, 4 do
    local eligible, reason = R:GetQueryEligibility()
    check(eligible and reason == nil, "eligible leader has no UI eligibility")
end
check(#sent == 0 and #timers == beforeTimers and callbacksSeen == 0 and R:GetSnapshot().generation == beforeGeneration,
    "eligibility mutated readiness state or emitted work")
RA.InEncounter = true -- A stale inspection/HUD cache must not block the hub.
check(R:GetQueryEligibility() and R:QueryGroup(), "stale cached encounter flag blocked native-safe readiness")
local eligible, reason = R:GetQueryEligibility()
check(not eligible and reason:find("already running", 1, true), "active query eligibility gate missing")
Advance(13)
eligible, reason = R:GetQueryEligibility()
check(not eligible and reason:find("Wait", 1, true), "cooldown eligibility gate missing")
Advance(3)
check(R:GetQueryEligibility(), "completed cooldown left UI ineligible")
combat = true
check(not R:GetQueryEligibility(), "combat UI query enabled")
combat = false
restriction = true
check(not R:GetQueryEligibility(), "restricted UI query enabled")
restriction = false
units.player.leader = false
check(not R:GetQueryEligibility(), "member UI query enabled")
units.player.assist = true
check(R:GetQueryEligibility(), "assistant UI query disabled")
grouped = false
check(not R:GetQueryEligibility(), "solo UI query enabled")
grouped = true
units.party1.guid = nil
check(not R:GetQueryEligibility(), "incomplete roster UI query enabled")

-- Resolve short event senders through the current roster, never payload names.
R = Setup()
check(R:QueryGroup(), "query failed")
nonce = Nonce()
Deliver(Response(nonce, "northernsky", "111", "1.2.3"), "Mage")
check(Mage().receivedCount == 1, "unique local-realm short sender was rejected")
R = Setup()
units.party1.realm = "OtherRealm"
check(R:QueryGroup(), "query failed")
nonce = Nonce()
Deliver(Response(nonce, "northernsky", "111", "1.2.3"), "Mage")
check(Mage().receivedCount == 0, "offrealm-only short sender was accepted")
Deliver(Response(nonce, "northernsky", "111", "1.2.3"), "Mage-OtherRealm")
check(Mage().receivedCount == 1, "qualified offrealm roster sender was rejected")
R = Setup()
units.party2 = Member("Mage", "Player-3")
units.party2.realm = "OtherRealm"
check(R:QueryGroup(), "query failed")
nonce = Nonce()
Deliver(Response(nonce, "northernsky", "111", "1.2.3"), "Mage")
check(Mage().receivedCount == 0, "ambiguous cross-realm short sender was accepted")
for _, sender in ipairs({"Mage-Injected", "Mage-TestRealm-Injected", " Mage", "Mage|TestRealm", "Mage\n"}) do
    Deliver(Response(nonce, "northernsky", "111", "1.2.3"), sender)
end
check(Mage().receivedCount == 0, "injected sender identity was accepted")
Deliver(Response(nonce, "northernsky", "111", "1.2.3"), "Mage-TestRealm")
check(Mage().receivedCount == 1, "qualified sender was rejected because another realm shared the short name")
R = Setup()
units.player.leader, units.party1.leader = false, true
Deliver("Q|1|a-b-c", "Mage", "PARTY")
Advance(4)
check(#sent == 7 and sent[1].target == "Mage-TestRealm", "short leader query did not bind replies to canonical roster identity")

-- Blizzard can disable a running addon for the next reload. Preserve that
-- configured character state independently of installed and currently loaded.
R, C = Setup()
arsenalEnableState = 0
local disabledArsenal = C:RefreshLocal().byID.arsenal
check(disabledArsenal.installed and disabledArsenal.loaded and disabledArsenal.enabled == false and disabledArsenal.status == "disabled",
    "running Arsenal ignored a pending disable in Blizzard's AddOns list")
check(R:SetTarget("arsenal", "0.14.0") and R:UseLocalTargets() and db.readiness.targets.arsenal == "0.14.0",
    "capture replaced the approved target from disabled Arsenal metadata")
units.player.leader, units.party1.leader = false, true
Deliver("Q|1|a-b-c", "Mage-TestRealm", "PARTY")
Advance(4)
local disabledPackets = sent
check(#disabledPackets == 7 and disabledPackets[1].message:find("|arsenal|101|", 1, true),
    "passive response did not report Arsenal configured-disabled but loaded")
R = Setup()
check(R:QueryGroup(), "query failed")
nonce = Nonce()
for _, packet in ipairs(disabledPackets) do Deliver((packet.message:gsub("a%-b%-c", nonce, 1))) end
check(R:GetSnapshot().status == "complete" and Mage().addons.arsenal.enabled == false and Mage().addons.arsenal.loaded
    and Mage().addons.arsenal.state == "disabled" and Mage().addons.arsenal.protocol == 1,
    "protocol rejected disabled-but-loaded Arsenal or confused protocol support with enable state")
R = Setup()
check(R:QueryGroup(), "query failed")
nonce = Nonce()
Deliver(Response(nonce, "arsenal", "1u1", "0.15.0-alpha.1", "0.15.0-alpha.1", 1))
check(Mage().receivedCount == 1 and Mage().addons.arsenal.enabled == nil and Mage().addons.arsenal.state == "unknown",
    "unknown Arsenal enable state became enabled or unsupported")

-- A combat roster event clears the live fingerprint; regen must still replace
-- old snapshot GUIDs before any manual query is requested.
R = Setup()
check(R:QueryGroup(), "query failed")
nonce = Nonce()
Deliver(Response(nonce, "northernsky", "111", "1.2.3"))
combat = true
Event("PLAYER_REGEN_DISABLED")
units.party1 = Member("NewMage", "Player-New")
Event("GROUP_ROSTER_UPDATE")
combat = false
Event("PLAYER_REGEN_ENABLED")
local replacedSnapshot = R:GetSnapshot()
check(replacedSnapshot.byGUID["Player-2"] == nil and replacedSnapshot.byGUID["Player-New"] ~= nil,
    "regen retained a departed GUID after combat roster replacement")
check(replacedSnapshot.status == "invalidated" and replacedSnapshot.byGUID["Player-New"].status == "unknown"
    and replacedSnapshot.byGUID["Player-New"].addons.northernsky.state == "unknown",
    "regen retained readiness values for a replacement member")
Advance(20)
check(R:GetSnapshot().status == "invalidated", "cancelled old query timeout changed the rebuilt snapshot")
R = Setup()
units.party1 = Member("RefreshMage", "Player-Refresh")
check(R:RefreshLocal() and R:GetSnapshot().byGUID["Player-2"] == nil and R:GetSnapshot().byGUID["Player-Refresh"] ~= nil,
    "explicit local refresh retained a departed roster GUID")
print("readiness: " .. checks .. " checks passed")
