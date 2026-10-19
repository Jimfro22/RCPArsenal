local _, RA = ...

local function PrintHelp()
    RA:Print("Commands:")
    print("  |cff3aa7ff/rcpa config|r - open the RCP Arsenal settings panel")
    print("  |cff3aa7ff/rcpa show|r or |cff3aa7ff/rcpa hide|r - show or hide the HUD")
    print("  |cff3aa7ff/rcpa recover|r - show and recenter a missing/off-screen HUD")
    print("  |cff3aa7ff/rcpa scan|r - scan only missing/new tracked players")
    print("  |cff3aa7ff/rcpa rescan|r - force a full tracked-roster refresh")
    print("  |cff3aa7ff/rcpa clearcache|r - clear inspected roster data and scan again")
    print("  |cff3aa7ff/rcpa pause|r or |cff3aa7ff/rcpa resume|r - pause/resume the inspect queue")
    print("  |cff3aa7ff/rcpa compact|r or |cff3aa7ff/rcpa detailed|r - change HUD mode")
    print("  |cff3aa7ff/rcpa scale 125|r - set overall HUD scale from 75 to 200 percent")
    print("  |cff3aa7ff/rcpa lock|r or |cff3aa7ff/rcpa unlock|r - lock HUD position")
    print("  |cff3aa7ff/rcpa demo|r - toggle solo preview data")
    print("  |cff3aa7ff/rcpa demoscan|r - toggle the simulated 13/20 scan overlay")
    print("  |cff3aa7ff/rcpa leaderonly|r - limit HUD to leaders and assists")
    print("  |cff3aa7ff/rcpa export|r - open the settings export dialog")
    print("  |cff3aa7ff/rcpa import|r - open the settings import dialog")
    print("  |cff3aa7ff/rcpa status|r - show raid scan coverage")
    print("  |cff3aa7ff/rcpa sort|r - Tanks > Melee > Ranged > Healers")
    print("  |cff3aa7ff/rcpa split|r - balance roles across odd/even groups")
    print("  |cff3aa7ff/rcpa groupsplit|r - balance G1+G2 against G3+G4")
    print("  |cff3aa7ff/rcpa missing|r - open the missing raid buffs/debuffs flyout")
    print("  |cff3aa7ff/rcpa active <ability_key>|r - preview an ACTIVE state")
    print("  |cff3aa7ff/rcpa clearactive|r - clear preview ACTIVE states")
    print("  |cff3aa7ff/rcpa reset|r - reset saved layout and filters")
    print("  Compact tiles: |cffffffffleft-click says + whispers|r; |cffffffffright-click sends raid warning|r.")
end

local function StartScan(fullRefresh)
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
    if summary.inspected > 0 then extra[#extra + 1] = summary.inspected .. " inspected" end
    if summary.filtered > 0 then extra[#extra + 1] = summary.filtered .. " class-skipped" end
    if summary.ignored > 0 then extra[#extra + 1] = summary.ignored .. " ignored" end
    if summary.pending > 0 then extra[#extra + 1] = summary.pending .. " pending" end
    if summary.outOfRange > 0 then extra[#extra + 1] = summary.outOfRange .. " out of range" end
    if summary.offline > 0 then extra[#extra + 1] = summary.offline .. " offline" end
    if summary.failed > 0 then extra[#extra + 1] = summary.failed .. " failed" end

    local suffix = #extra > 0 and (" · " .. table.concat(extra, " · ")) or ""
    RA:Print(string.format("%d/%d tracked players ready%s.", ready, total, suffix))
end

local function HandleSlash(raw)
    local command, rest = (raw or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = string.lower(command or "")

    if command == "" or command == "config" then
        RA:OpenConfig()
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
        if InCombatLockdown() then
            RA:Print("Inspection cache cannot be cleared during combat.")
        elseif RA.ClearInspectionCache then
            RA:ClearInspectionCache()
            RA:Print("Inspection cache cleared. Scanning the tracked roster again.")
        end
    elseif command == "pause" then
        RA:SetInspectionPaused(true)
        RA:Print("Raid scan paused after the current inspect finishes.")
    elseif command == "resume" then
        RA:SetInspectionPaused(false)
        RA:Print("Raid scan resumed.")
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

SLASH_RCPARSENAL1 = "/rcpa"
SLASH_RCPARSENAL2 = "/arsenal"
SLASH_RCPARSENAL3 = "/raidarsenal"
SlashCmdList["RCPARSENAL"] = HandleSlash
