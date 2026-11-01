local _, RA = ...

local function PrintHelp()
    RA:Print("Commands:")
    print("  |cff3aa7ff/rcp setup|r - open General; Preview all and Move all are on every Arsenal page")
    print("  |cff3aa7ff/rcp hud|r, |cff3aa7ff/rcp quickbar|r, |cff3aa7ff/rcp content|r, |cff3aa7ff/rcp scanning|r - open Arsenal settings")
    print("  |cff3aa7ff/rcp callouts|r, |cff3aa7ff/rcp tools|r, |cff3aa7ff/rcp profiles|r - callouts, personal tools, or profiles")
    print("  |cff3aa7ff/rcp groups|r - draft and save raid groups; Apply to raid remains explicit")
    print("  |cff3aa7ff/rcp versions|r - request group addon versions as leader or assistant")
    print("  |cff3aa7ff/rcp config|r or |cff3aa7ff/rcp addons|r - open Addons & Versions")
    print("  |cff3aa7ff/rcp nsrt|r - open Northern Sky notes, profiles, and local placement")
    print("  |cff3aa7ff/rcp markers|r - configure the normal marker sequence, optional hold wheel and keys")
    print("  |cff3aa7ff/rcp recap|r - view the last personal recap; enable recording in Personal Tools")
    print("  |cff3aa7ff/rcp recappreview|r - private tester; report and reminder controls work")
    print("  |cff3aa7ff/rcp recapstatus|r or |cff3aa7ff/rcp recapaudit|r - safe local capture diagnostics")
    print("  |cff3aa7ff/rcp recapdebug [reread]|r or |cff3aa7ff/rcp recapdebug cooldowns [start||stop||show]|r - copy diagnostics or arm a bounded Mirror Image capture")
    print("  |cff3aa7ff/rcp recapblizzard|r - request Blizzard recap for the accepted frozen ID")
    print("  |cff3aa7ff/rcp show|r or |cff3aa7ff/rcp hide|r - enable or disable the HUD and talent scans")
    print("  |cff3aa7ff/rcp recover|r - reset HUD position without enabling it")
    print("  |cff3aa7ff/rcp scan|r - scan only missing/new tracked players")
    print("  |cff3aa7ff/rcp rescan|r - force a full tracked-roster refresh")
    print("  |cff3aa7ff/rcp clearcache|r - clear saved inspections and scan again")
    print("  |cff3aa7ff/rcp pause|r or |cff3aa7ff/rcp resume|r - pause/resume the inspect queue")
    print("  |cff3aa7ff/rcp compact|r or |cff3aa7ff/rcp detailed|r - change HUD mode")
    print("  |cff3aa7ff/rcp scale 125|r - set overall HUD scale from 75 to 200 percent")
    print("  |cff3aa7ff/rcp lock|r or |cff3aa7ff/rcp unlock|r - lock HUD position")
    print("  |cff3aa7ff/rcp demo|r - toggle solo preview data")
    print("  |cff3aa7ff/rcp demoscan|r - toggle the simulated 13/20 scan overlay")
    print("  |cff3aa7ff/rcp leaderonly|r - limit HUD to leaders and assists")
    print("  |cff3aa7ff/rcp export|r - open the settings export dialog")
    print("  |cff3aa7ff/rcp import|r - open the settings import dialog")
    print("  |cff3aa7ff/rcp status|r - show raid scan coverage")
    print("  |cff3aa7ff/rcp sort|r - Tanks > Melee > Ranged > Healers")
    print("  |cff3aa7ff/rcp split|r - balance roles across odd/even groups")
    print("  |cff3aa7ff/rcp groupsplit|r - balance G1+G2 against G3+G4")
    print("  |cff3aa7ff/rcp missing|r - open the missing raid buffs/debuffs flyout")
    print("  |cff3aa7ff/rcp active <ability_key>|r - preview an ACTIVE state")
    print("  |cff3aa7ff/rcp clearactive|r - clear preview ACTIVE states")
    print("  |cff3aa7ff/rcp reset|r - reset saved layout and filters")
    print("  Compact tiles: |cffffffffleft-click uses Whisper, Say, or Off|r; |cffffffffright-click sends raid warning|r.")
end

local function StartScan(fullRefresh)
    if not RA:IsInspectionEnabled() then
        RA:Print("Enable HUD + talent inspection in Available Cooldowns before scanning.")
        return
    end
    local reason = fullRefresh and "slash full rescan" or "slash scan missing"
    RA:SetInspectionPaused(false)
    if RA:RequestInspectionScan(reason, fullRefresh) then
        if fullRefresh then
            RA:Print("Full tracked-roster rescan started. Ignored groups remain excluded.")
        else
            RA:Print("Scanning only missing/new tracked players.")
        end
    else
        RA:Print("Raid scanning is unavailable during combat.")
    end
end

local function PrintStatus()
    local ready, total, isDemo = RA:GetVerificationStatus()
    if isDemo then
        local reason = RA.GetHUDVisibilityReason and RA:GetHUDVisibilityReason() or nil
        local scanDemo = RA:GetDB().scan and RA:GetDB().scan.demoPreview
        RA:Print("Solo demo data is active" .. (scanDemo and " with scan preview" or "") .. (reason and ("; HUD hidden: " .. reason) or "; HUD visible") .. ".")
        return
    end

    local summary = RA:GetScanSummary()
    local _, _, _, running, currentName, paused = RA:GetInspectionProgress()
    local extra = {}
    if paused then
        extra[#extra + 1] = "paused"
    elseif running then
        extra[#extra + 1] = currentName and ("scanning " .. RA:GetShortName(currentName)) or "scanning"
    end
    extra[#extra + 1] = RA:FormatInspectionEvidenceSummary(summary)
    if summary.filtered > 0 then extra[#extra + 1] = summary.filtered .. " class-skipped" end
    if summary.ignored > 0 then extra[#extra + 1] = summary.ignored .. " ignored" end
    if summary.pending > 0 then extra[#extra + 1] = summary.pending .. " pending" end
    if summary.outOfRange > 0 then extra[#extra + 1] = summary.outOfRange .. " out of range" end
    if summary.offline > 0 then extra[#extra + 1] = summary.offline .. " offline" end
    if summary.failed > 0 then extra[#extra + 1] = summary.failed .. " failed" end

    local suffix = #extra > 0 and (" · " .. table.concat(extra, " · ")) or ""
    RA:Print(string.format("%d/%d tracked players resolved%s. Cached talents may have changed; /rcp rescan refreshes them.", ready, total, suffix))
end

local function HandleSlash(raw)
    local command, rest = (raw or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = string.lower(command or "")

    if command=="recap"then
        if not RA.DeathRecapUI:ShowLast()then RA:OpenConfig("MYTOOLS")end
    elseif command=="recappreview"then RA.DeathRecapUI:Preview()
    elseif command=="recapblizzard"then
        if rest~=""then RA:Print("Usage: /rcp recapblizzard (accepted frozen ID only)");return end
        local _,reason=RA.DeathRecap:OpenBlizzardRecap();RA:Print(reason)
    elseif command=="recapdebug"then
        local mode=rest=="cooldowns"and"show"or rest:match("^cooldowns%s+(%S+)$")
        if mode=="start"then local _,reason=RA.DeathRecapDebug:StartCooldownCapture();RA:Print(reason);return end
        if rest~=""and rest~="reread"and mode~="show"and mode~="stop"then RA:Print("Usage: /rcp recapdebug [reread] or cooldowns [start||stop||show]");return end
        local text,reason
        if mode then
            if mode=="stop"then RA.DeathRecapDebug:StopCooldownCapture("explicit-stop")end
            text,reason=RA.DeathRecapDebug:BuildCooldownCaptureText()
        else text,reason=RA.DeathRecap:BuildDebugText(rest=="reread")end
        if not text then RA:Print(reason);return end
        local shown,why=RA.DeathRecapUI:ShowDebugText(text);if not shown then RA:Print(why)end
    elseif command=="recapaudit"then
        local audit,reason=RA.DeathRecap:GetAvailabilityAudit()
        if not audit then RA:Print(reason);return end
        local function Scalar(value)return value==nil and"not recorded"or tostring(value)end
        RA:Print("Audit build="..Scalar(audit.client and audit.client.build).."; spec="..Scalar(audit.specID).."; local death="..Scalar(audit.localDeathID).."; native recap="..Scalar(audit.nativeRecapID).."; rejected receipts="..Scalar(audit.coverage and audit.coverage.rejectedReceipts).."; late receipts="..Scalar(audit.coverage and audit.coverage.lateReceipts).."; encounter ended="..Scalar(audit.encounterEndObservation and audit.encounterEndObservation.observedAt))
        RA:Print("Defensive audit: local death notice="..Scalar(audit.deathNoticeAt).."; coverage start="..Scalar(audit.coverage and audit.coverage.startedAt).."; combat entry observed="..Scalar(audit.coverage and audit.coverage.combatEntryObserved).."; coverage end="..Scalar(audit.coverage and audit.coverage.endedAt).."; reason="..Scalar(audit.coverage and audit.coverage.reason)..". These are recorded facts, not a readiness verdict.")
        for _,event in ipairs({"SPELL_UPDATE_COOLDOWN","SPELL_UPDATE_CHARGES"})do local context=audit.directSpellEvents and audit.directSpellEvents[event]
            if context then
                local text=event.." direct context at="..Scalar(context.observedAt)
                for i,field in ipairs(context.payload)do text=text.."; arg"..i.."="..Scalar(field.value).." ("..field.status..")"end
                RA:Print(text)
            end
        end
        for _,spell in ipairs(audit.spells)do
            local use=spell.use
            RA:Print((spell.name or"Spell").." ["..spell.spellID.."] observed uses="..use.observedCount.."; first="..Scalar(use.firstSuccessfulUseAt).."; last="..Scalar(use.lastSuccessfulUseAt)..". Missing receipts do not prove unused. Shelf: "..spell.displayed.detail.." ("..spell.displayed.source..").")
            for _,pair in ipairs({{"last alive",spell.lastAlive},{"death notice",spell.deathNotice}})do
                local row=pair[2]or{}
                RA:Print("  "..pair[1]..": at="..Scalar(row.observedAt).."; "..Scalar(row.source).."; enabled="..Scalar(row.isEnabled).."; active="..Scalar(row.isActive).."; GCD="..Scalar(row.isOnGCD).."; charges="..Scalar(row.currentCharges).."/"..Scalar(row.maxCharges).." ("..Scalar(row.chargeQuery).."); pending="..Scalar(row.pendingReason).."; query="..Scalar(row.cooldownQuery))
                RA:Print("    field status: enabled="..Scalar(row.cooldownEnabledStatus).."; active="..Scalar(row.cooldownActiveStatus).."; charges="..Scalar(row.chargeCountStatus).."/"..Scalar(row.chargeReason).."; pending at="..Scalar(row.pendingAt).."; ended at="..Scalar(row.coverageEndedAt))
            end
        end
    elseif command=="recapstatus"then
        local state=RA.DeathRecap:GetDiagnostics()
        RA:Print("Recap "..(state.optionalEnabled and"on"or"off").."; tracked="..state.trackedSpells.."; samples="..state.samples.."; nativeReads="..state.nativeReads.."; "..state.nativeStatus)
        RA:Print("Meter reads="..state.association.reads.."; rows="..state.association.rows.."; clean baseline="..(state.association.baselineKnown and"yes"or"no").."; ticker="..(state.tickerActive and"active"or"off"))
        local clock=state.nativeClock
        if clock then
            local function Scalar(value)return type(value)=="number"and tostring(value)or"not recorded"end
            RA:Print("Clock diagnostic (unvalidated): GetTime session="..Scalar(clock.localSessionStartedAt).."; death notice="..Scalar(clock.localDeathNoticeAt).."; read="..Scalar(clock.nativeReadLocalBefore)..".."..Scalar(clock.nativeReadLocalAfter))
            RA:Print("Native timestamps first="..Scalar(clock.nativeFirstTimestamp).."; min="..Scalar(clock.nativeMinimumTimestamp).."; max="..Scalar(clock.nativeMaximumTimestamp).."; fatal="..Scalar(clock.nativeFatalTimestamp).."; rows="..Scalar(clock.nativeRowCount))
        end
        RA:Print("Client "..(state.client.version or"Unknown").." build "..(state.client.build or"Unknown").." interface "..(state.client.interface or"Unknown").."; catalog "..(state.catalogBuild or"Unknown"))
    elseif command == "" or command == "config" then
        RA:OpenConfig()
    elseif command == "general" then
        RA:OpenConfig("GENERAL")
    elseif command == "setup" then
        RA:OpenSetup()
    elseif command == "addons" then
        RA:OpenConfig("ADDONS")
    elseif command == "cooldowns" then
        RA:OpenConfig("COOLDOWNS")
    elseif command == "hud" then
        RA:OpenConfig("HUD")
    elseif command == "groups" then
        RA:OpenConfig("RAIDGROUPS")
    elseif command == "quickbar" then
        RA:OpenConfig("QUICKBAR")
    elseif command == "content" then
        RA:OpenConfig("CONTENT")
    elseif command == "scanning" then
        RA:OpenConfig("SCANNING")
    elseif command == "callouts" then
        RA:OpenConfig("ACTIONS")
    elseif command == "nsrt" or command == "northernsky" then
        RA:OpenConfig("NORTHERNSKY")
    elseif command == "tools" then
        RA:OpenConfig("MYTOOLS")
    elseif command == "raid" then
        RA:OpenConfig("ADDONS")
    elseif command == "settings" or command == "profiles" then
        RA:OpenConfig("SETTINGS")
    elseif command == "versions" then
        RA:OpenConfig("ADDONS")
        local ok, reason = RA.Readiness:QueryGroup()
        if not ok then RA:Print(reason) end
    elseif command == "markers" then
        RA:OpenConfig("WORLDMARKERS")
    elseif command == "show" then
        RA:ShowHUD()
    elseif command == "hide" then
        RA:HideHUD()
    elseif command == "recover" or command == "recenter" then
        if RA.RecoverHUD then RA:RecoverHUD() end
    elseif command == "toggle" then
        if RA:GetDB().shown then RA:HideHUD() else RA:ShowHUD() end
    elseif command == "scan" or command == "sync" then
        StartScan(false)
    elseif command == "rescan" then
        StartScan(true)
    elseif command == "clearcache" then
        if not RA:IsInspectionEnabled() then
            RA:Print("Enable HUD + talent inspection in Available Cooldowns before scanning.")
        elseif InCombatLockdown() then
            RA:Print("Inspection cache cannot be cleared during combat.")
        elseif RA.ClearInspectionCache then
            RA:ClearInspectionCache()
            RA:Print("Inspection cache cleared. Scanning the tracked roster again.")
        end
    elseif command == "pause" then
        RA:SetInspectionPaused(true)
        RA:Print("Raid scan paused after the current inspect finishes.")
    elseif command == "resume" then
        if RA:IsInspectionEnabled() then
            RA:SetInspectionPaused(false)
            RA:Print("Raid scan resumed.")
        else
            RA:Print("Enable HUD + talent inspection in Available Cooldowns before resuming.")
        end
    elseif command == "compact" then
        RA:SetMode("COMPACT")
    elseif command == "detailed" then
        RA:SetMode("DETAILED")
    elseif command == "scale" then
        local percent = tonumber(rest)
        if not percent then
            RA:Print(string.format("HUD scale is %d%%.", math.floor((RA:GetDB().scale or 1) * 100 + 0.5)))
        else
            percent = math.max(75, math.min(200, percent))
            RA:GetDB().scale = percent / 100
            RA:RefreshHUD()
            RA:Print(string.format("HUD scale set to %d%%.", percent))
        end
    elseif command == "lock" then
        RA:SetLocked(true)
    elseif command == "unlock" then
        RA:SetLocked(false)
    elseif command == "demo" then
        RA:SetDemoMode(not RA:GetDB().demoMode)
        RA:Print("Solo demo mode " .. (RA:GetDB().demoMode and "enabled." or "disabled."))
    elseif command == "demoscan" then
        if not RA:IsHUDEnabled() then
            RA:Print("Enable HUD + talent inspection in Available Cooldowns before using demo data.")
            return
        end
        local db = RA:GetDB()
        db.scan.demoPreview = not db.scan.demoPreview
        if not db.demoMode then db.demoMode = true end
        RA:RefreshHUD()
        RA:Print("Demo scan overlay " .. (db.scan.demoPreview and "enabled." or "disabled."))
    elseif command == "leaderonly" then
        local db = RA:GetDB()
        db.leaderOnly = not db.leaderOnly
        RA:RefreshHUD()
        RA:Print("Leader/assist-only HUD " .. (db.leaderOnly and "enabled." or "disabled."))
    elseif command == "export" then
        if RA.OpenProfileDialog then RA:OpenProfileDialog("EXPORT") end
    elseif command == "import" then
        if RA.OpenProfileDialog then RA:OpenProfileDialog("IMPORT") end
    elseif command == "active" then
        local key = string.lower(rest or "")
        if key == "" then
            RA:Print("Use an ability key, such as spirit_link or rallying_cry.")
        else
            local states = RA:GetActiveStates()
            if RA:SetAbilityActive(key, not states[key]) then
                RA:Print(key .. " ACTIVE preview " .. (states[key] and "enabled." or "disabled."))
            else
                RA:Print("Unknown ability key: " .. key)
            end
        end
    elseif command == "clearactive" then
        RA:ClearActiveStates()
    elseif command == "reset" then
        if InCombatLockdown() then
            RA:Print("Profile reset is unavailable during combat.")
        else
            RA:ResetProfile()
            RA:Print("Profile reset.")
        end
    elseif command == "status" then
        PrintStatus()
    elseif command == "sort" then
        if RA.RaidLeaderToolbox and RA.RaidLeaderToolbox.SortByRole then RA.RaidLeaderToolbox:SortByRole() end
    elseif command == "split" or command == "oddeven" then
        if RA.RaidLeaderToolbox and RA.RaidLeaderToolbox.SplitOddEven then RA.RaidLeaderToolbox:SplitOddEven() end
    elseif command == "groupsplit" or command == "adjacent" then
        if RA.RaidLeaderToolbox and RA.RaidLeaderToolbox.SplitAdjacent then RA.RaidLeaderToolbox:SplitAdjacent() end
    elseif command == "missing" then
        if RA.RaidLeaderToolbox and RA.RaidLeaderToolbox.ShowMissingPanel then RA.RaidLeaderToolbox:ShowMissingPanel() end
    elseif command == "debug" then
        RA.DebugEnabled = not RA.DebugEnabled
        RA:Print("Debug output " .. (RA.DebugEnabled and "enabled." or "disabled."))
    else
        PrintHelp()
    end
end

-- Use the normal chat registration path. Do not overwrite native/general
-- command hashes or another addon's aliases to reclaim a shared command.
function RA:GetSlashCommandStatus()
    local hash = _G.hash_SlashCmdList
    if type(hash) == "table" and hash["/RCP"] and hash["/RCP"] ~= HandleSlash then
        return "/rcp is registered by another addon. Use /rcparsenal to open this hub."
    end
    for key, value in pairs(_G) do
        if type(key) == "string" and key:match("^SLASH_.+%d+$") and not key:match("^SLASH_RCPARSENAL%d+$")
            and type(value) == "string" and value:lower() == "/rcp" then
            return "Another addon also registers /rcp. Use /rcparsenal if it opens the wrong panel."
        end
    end
    return "Legacy Arsenal aliases remain supported."
end
SLASH_RCPARSENAL1 = "/rcp"
SLASH_RCPARSENAL2 = "/rcparsenal"
SLASH_RCPARSENAL3 = "/rcpa"
SLASH_RCPARSENAL4 = "/arsenal"
SLASH_RCPARSENAL5 = "/raidarsenal"
SlashCmdList["RCPARSENAL"] = HandleSlash
