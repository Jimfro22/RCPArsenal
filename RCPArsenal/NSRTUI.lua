local _, RA = ...

function RA:CreateNorthernSkyPane(parent, kit)
    local A, T, C = RA.NSRTAdapter, RA.Theme, RA.Theme.Colors
    local Point, Size, Width = T.SetPoint, T.SetSize, T.SetWidth
    local subview, noteKind, loading = "NOTES", "shared", false
    local noteData, noteContext, profileContext, placementContext, reviewedNote, livePersonal
    local selectedProfile, selectedSection
    local draft, sourceShared = nil, nil
    local currentStatus, refresh
    local refreshing = false
    local panels, tabs, profileRows, sectionButtons, placementInputs = {}, {}, {}, {}, {}
    local message, confirmation, confirmTitle, confirmBody, confirmAction
    local recoveryOverlay, recoveryBox, recoveryTitle, recoveryData, recoveryKind = nil, nil, nil, nil, "originalExport"
    local recoveryChoices = {}
    local placementSample
    local function Literal(value)
        return type(value) == "string" and value:gsub("|", "||") or "Unknown"
    end
    local function Text(owner, value, size, x, y, width, color)
        local text = kit.Font(owner, size or 11, color or C.textSoft, "REGULAR")
        text:SetText(value or ""); text:SetWordWrap(true)
        Point(text, "TOPLEFT", owner, "TOPLEFT", x or 0, y or 0)
        if width then Width(text, width) end
        return text
    end
    local function Tri(value)
        if value == true then return "Yes" end
        if value == false then return "No" end
        return "Unknown"
    end
    local function Enable(button, enabled)
        button:SetEnabled(enabled == true); button:SetAlpha(enabled and 1 or 0.45)
    end
    local function Say(ok, reason)
        message:SetText(reason or (ok and "Done." or "Unavailable."))
    end
    local function StopPreview()
        if placementSample then placementSample:Hide() end
    end
    local function Confirm(title, description, action)
        if not confirmation then
            confirmation = CreateFrame("Frame", nil, RA.ConfigFrame, "BackdropTemplate")
            confirmation:SetAllPoints(RA.ConfigFrame); confirmation:EnableMouse(true)
            confirmation:SetFrameLevel(RA.ConfigFrame:GetFrameLevel() + 180)
            kit.Backdrop(confirmation, {0,0,0,0.7}, C.line, 14, false)
            local card = CreateFrame("Frame", nil, confirmation, "BackdropTemplate")
            Size(card, 640, 230); Point(card, "CENTER", confirmation, "CENTER", 0, 0)
            card:EnableMouse(true); kit.Backdrop(card, C.surface, C.lineStrong, 14, true)
            confirmTitle = Text(card, "", 16, 22, -20, 596, C.text)
            confirmBody = Text(card, "", 11, 22, -60, 596)
            local cancel = kit.Button(card, "CANCEL", 150, 34, function() confirmation:Hide() end)
            Point(cancel, "BOTTOMRIGHT", card, "BOTTOMRIGHT", -190, 18)
            local apply = kit.Button(card, "CONFIRM", 150, 34, function()
                confirmation:Hide()
                local callback = confirmAction; confirmAction = nil
                if callback then callback() end
                refresh(false)
            end, true)
            Point(apply, "BOTTOMRIGHT", card, "BOTTOMRIGHT", -22, 18)
        end
        confirmTitle:SetText(title); confirmBody:SetText(description); confirmAction = action
        confirmation:Show()
    end
    local function ReleaseUndo(kind)
        local expected = kind == "recovery" and currentStatus.recovery and currentStatus.recovery.token or currentStatus.context
        local backupKind = kind == "recovery" and currentStatus.recovery and currentStatus.recovery.kind or kind
        local label = ({note = "note", profile = "profile", placement = "placement"})[backupKind] or "recovery"
        Confirm("Keep current state and release " .. label .. " backup?", "Northern Sky will stay exactly as it is. Arsenal will forget this session's " .. label .. " undo or recovery record, so it can no longer restore that backup. Copy any recovery text first. No Northern Sky setting is changed by this action.", function()
            local ok, reason = A:ReleaseUndo(kind, expected); Say(ok, reason)
        end)
    end
    local function Editor(owner, x, y, width, height, maximum)
        local back = CreateFrame("Frame", nil, owner, "BackdropTemplate")
        Size(back, width, height); Point(back, "TOPLEFT", owner, "TOPLEFT", x, y)
        kit.Backdrop(back, C.input, C.line, 8, false)
        local scroll = CreateFrame("ScrollFrame", nil, back, "UIPanelScrollFrameTemplate")
        Point(scroll, "TOPLEFT", back, "TOPLEFT", 12, -10)
        Point(scroll, "BOTTOMRIGHT", back, "BOTTOMRIGHT", -28, 10)
        local box = CreateFrame("EditBox", nil, scroll)
        box:SetMultiLine(true); box:SetAutoFocus(false); box:SetMaxLetters(maximum or 65536)
        Width(box, width - 44); T.SetHeight(box, height - 20)
        RA:ApplyFont(box, 11, "REGULAR", false)
        box:SetTextColor(unpack(C.text)); scroll:SetScrollChild(box)
        box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        return box, scroll
    end

    kit.Heading(parent, "Northern Sky", "Use your separately installed Northern Sky Raid Tools. Changes here are explicit and stay out of combat.")
    local status = Text(parent, "", 10.5, 0, -60, 650)
    local uiInfo = Text(parent, "", 9.2, 678, -130, 272, C.muted)
    local original = kit.Button(parent, "OPEN NORTHERN SKY SETTINGS", 248, 32, function()
        local ok, reason = A:OpenSettings(); Say(ok, reason)
    end)
    Point(original, "TOPRIGHT", parent, "TOPRIGHT", 0, -54)
    local check = kit.Button(parent, "REFRESH", 116, 30, function()
        A:Refresh(); refresh(true)
    end)
    Point(check, "TOPRIGHT", parent, "TOPRIGHT", 0, -93)
    local link = kit.Button(parent, "DOWNLOAD LINK", 144, 30, function()
        RA:ShowAddonLink("northernsky")
    end)
    Point(link, "TOPRIGHT", parent, "TOPRIGHT", -128, -93)
    local defs = {{"NOTES","NOTES"},{"PROFILES","PROFILES"},{"PLACEMENT","PLACEMENT"}}
    for i, definition in ipairs(defs) do
        local button = kit.Button(parent, definition[2], 200, 32, function()
            StopPreview(); subview = definition[1]; refresh(false)
        end)
        Point(button, "TOPLEFT", parent, "TOPLEFT", (i-1)*212, -112)
        tabs[definition[1]] = button
        local panel = CreateFrame("Frame", nil, parent)
        Size(panel, 950, 455); Point(panel, "TOPLEFT", parent, "TOPLEFT", 0, -164)
        panel:Hide(); panels[definition[1]] = panel
    end
    message = Text(parent, "No Northern Sky settings are changed when this page opens.", 10, 0, -633, 950, C.muted)

    local notes = panels.NOTES
    local noteCard = kit.Card(notes, "SHARED NOTE — LOCAL DRAFT", "Northern Sky syntax is retained. Editing this box does not save or send anything.")
    Size(noteCard, 640, 455); Point(noteCard, "TOPLEFT", notes, "TOPLEFT", 0, 0)
    local noteBox, noteScroll = Editor(noteCard, 16, -104, 608, 285)
    local shared = kit.Button(noteCard, "SHARED DRAFT", 190, 30, function()
        noteKind = "shared"; refresh(false)
    end)
    Point(shared, "TOPLEFT", noteCard, "TOPLEFT", 16, -64)
    local personal = kit.Button(noteCard, "VIEW PERSONAL", 160, 30, function()
        noteKind = "personal"; refresh(false)
    end)
    Point(personal, "LEFT", shared, "RIGHT", 10, 0)
    local reviewCurrent = kit.Button(noteCard, "REVIEW CURRENT SHARED", 200, 30, function()
        local ok, reason, data = A:GetNotes()
        if ok then reviewedNote, noteKind = data, "current" end
        Say(ok, reason); refresh(false)
    end)
    Point(reviewCurrent, "LEFT", personal, "RIGHT", 10, 0)
    local loadCurrent = kit.Button(noteCard, "REPLACE DRAFT", 240, 32, function()
        local function load()
            local ok, reason, data = A:GetNotes()
            if ok then
                noteData, noteContext, sourceShared, draft = data, data.context, data.shared, data.shared
            end
            Say(ok, reason); refresh(false)
        end
        if draft and sourceShared and draft ~= sourceShared then
            Confirm("Replace this unsaved draft?", "The shared draft in Arsenal will be replaced with Northern Sky's current local note. This does not apply a note or change Northern Sky.", load)
        else load() end
    end)
    Point(loadCurrent, "BOTTOMLEFT", noteCard, "BOTTOMLEFT", 16, 18)
    local useContext = kit.Button(noteCard, "KEEP DRAFT + USE REVIEWED CONTEXT", 346, 32, function()
        if not reviewedNote then return end
        local expected = reviewedNote
        Confirm("Use this reviewed note context?", "Keep your draft and prepare to save it against profile " .. Literal(expected.profile) .. ", active note " .. Literal(expected.activeName) .. ". Applying still requires a separate Save local Arsenal copy action. Nothing changes in Northern Sky now.", function()
            noteData, noteContext, sourceShared, noteKind = expected, expected.context, expected.shared, "shared"
        end)
    end)
    Point(useContext, "BOTTOMRIGHT", noteCard, "BOTTOMRIGHT", -16, 18)
    local noteHint = Text(noteCard, "", 9.2, 16, -394, 608, C.muted)
    noteBox:SetScript("OnTextChanged", function(box)
        if loading then return end
        if noteKind == "shared" then
            draft = box:GetText() or ""
            noteHint:SetText(draft ~= sourceShared and "Unsaved shared draft." or "Current shared note loaded.")
        else
            loading = true; box:SetText(noteKind == "current" and (reviewedNote and reviewedNote.shared or "") or (livePersonal or "")); loading = false
        end
    end)
    local details = kit.Card(notes, "LOCAL SCOPE", "Shared means the note used locally by Northern Sky.")
    Size(details, 294, 455); Point(details, "TOPRIGHT", notes, "TOPRIGHT", 0, 0)
    local noteScope = Text(details, "", 10.5, 16, -70, 262)
    local noteReason = Text(details, "", 10, 16, -185, 262, C.orange)
    Text(details, "Undo is available during this login session; reloading loses it.", 9.5, 16, -266, 262, C.muted)
    local applyNote = kit.Button(details, "SAVE LOCAL ARSENAL COPY", 262, 38, function()
        Confirm("Save and select a local note copy?", "Creates an Arsenal-owned shared-note copy in Northern Sky and selects it locally. Existing team notes stay in the library. Nothing is sent by Arsenal. Northern Sky AutoShare must be off. Turning AutoShare on later can send the active copy on a ready/pull check. Session restore requires unchanged ownership and context.", function()
            local ok, reason = A:ApplyLocalNote(draft or "", noteContext); Say(ok, reason)
            if ok then noteData, noteContext, sourceShared, draft = nil, nil, nil, nil end
        end)
    end, true)
    Point(applyNote, "BOTTOMLEFT", details, "BOTTOMLEFT", 16, 72)
    local restoreNote = kit.Button(details, "RESTORE PREVIOUS LOCAL NOTE", 262, 36, function()
        local expectedContext = currentStatus.context
        Confirm("Restore the previous local note?", "Restores the session backup only if Northern Sky still has the note copy and context owned by this operation. Intervening changes are not overwritten.", function()
            local ok, reason = A:RestoreLastNote(expectedContext); Say(ok, reason)
            if ok then
                local dirty = draft ~= nil and draft ~= sourceShared
                noteData, noteContext, sourceShared, reviewedNote, noteKind = nil, nil, nil, nil, "shared"
                if not dirty then draft = nil end
            end
        end)
    end)
    Point(restoreNote, "BOTTOMLEFT", details, "BOTTOMLEFT", 16, 20)
    local keepNote = kit.Button(details, "KEEP CURRENT / RELEASE UNDO", 262, 30, function() ReleaseUndo("note") end)
    Point(keepNote, "BOTTOMLEFT", details, "BOTTOMLEFT", 16, 124)

    local profiles = panels.PROFILES
    local profileCard = kit.Card(profiles, "SAVED PROFILES", "Selecting a row does not apply it.")
    Size(profileCard, 450, 455); Point(profileCard, "TOPLEFT", profiles, "TOPLEFT", 0, 0)
    local profileScroll = CreateFrame("ScrollFrame", nil, profileCard, "UIPanelScrollFrameTemplate")
    Point(profileScroll, "TOPLEFT", profileCard, "TOPLEFT", 16, -68)
    Point(profileScroll, "BOTTOMRIGHT", profileCard, "BOTTOMRIGHT", -32, 16)
    local profileChild = CreateFrame("Frame", nil, profileScroll)
    Size(profileChild, 398, 365); profileScroll:SetScrollChild(profileChild)
    local profileDetails = kit.Card(profiles, "APPLY AS A COPY", "Copies keep notes and layout. Undo ends on reload.")
    Size(profileDetails, 484, 455); Point(profileDetails, "TOPRIGHT", profiles, "TOPRIGHT", 0, 0)
    local profileText = Text(profileDetails, "", 11, 18, -72, 448)
    local profileReason = Text(profileDetails, "", 10.5, 18, -245, 448, C.orange)
    local applyProfile = kit.Button(profileDetails, "APPLY SETTINGS AS ARSENAL COPY", 448, 38, function()
        Confirm("Apply profile settings as a new copy?", "Source: " .. Literal(selectedProfile) .. ". Northern Sky will create and activate a new Arsenal-owned profile for this character. Current notes, local placement, and AutoShare are preserved. Originals are retained. Some original addon behavior still requires client validation.", function()
            local ok, reason = A:ApplyProfile(selectedProfile, profileContext); Say(ok, reason)
            if ok then selectedProfile, profileContext = nil, nil end
        end)
    end, true)
    Point(applyProfile, "BOTTOMLEFT", profileDetails, "BOTTOMLEFT", 18, 74)
    local restoreProfile = kit.Button(profileDetails, "RESTORE PREVIOUS SESSION PROFILE", 448, 36, function()
        local expectedContext = currentStatus.context
        Confirm("Restore the previous session profile?", "Return to the original profile and preserved local state only if the applied Arsenal copy has not been changed. The copy stays in Northern Sky; no original profile is deleted.", function()
            local ok, reason = A:RestoreLastProfile(expectedContext); Say(ok, reason)
            if ok then selectedProfile, profileContext = nil, nil end
        end)
    end)
    Point(restoreProfile, "BOTTOMLEFT", profileDetails, "BOTTOMLEFT", 18, 22)

    local placement = panels.PLACEMENT
    local placementCard = kit.Card(placement, "LOCAL PLACEMENT", "Edit original saved positions and dimensions; this is not a reminder enable switch.")
    Size(placementCard, 950, 455); Point(placementCard, "TOPLEFT", placement, "TOPLEFT", 0, 0)
    local placementLabel = Text(placementCard, "", 11, 20, -118, 900, C.text)
    local placementReason = Text(placementCard, "", 10.5, 20, -300, 900, C.orange)
    local applyPlacement = kit.Button(placementCard, "APPLY LOCAL PLACEMENT", 260, 36, function()
        local values = {}
        for key, control in pairs(placementInputs) do
            if control:IsShown() then
                local value = control:GetInputValue()
                if value == nil then Say(false, "Complete every displayed placement field before applying."); return end
                values[key] = value
            end
        end
        local ok, reason = A:SetPlacement(selectedSection, values, placementContext); Say(ok, reason)
        if ok then placementContext = nil end
        refresh(false)
    end, true)
    Point(applyPlacement, "BOTTOMLEFT", placementCard, "BOTTOMLEFT", 20, 24)
    local previewPlacement = kit.Button(placementCard, "PREVIEW PLACEMENT", 240, 36, function()
        local ok, reason, data = A:GetPlacement(selectedSection)
        if not ok then Say(false, reason); return end
        local values = data.values
        for _, field in ipairs(data.fields) do
            local input = placementInputs[field.key]
            local value = input and input:GetInputValue()
            if value == nil or (not field.options and (value ~= value or value < field.min or value > field.max)) then
                Say(false, "Enter a valid " .. (field.label or field.key) .. " before previewing."); return
            end
            values[field.key] = value
        end
        if not placementSample then
            placementSample = CreateFrame("Frame", "RCPArsenalNSRTPlacementSample", UIParent, "BackdropTemplate")
            placementSample:SetFrameStrata("DIALOG")
            placementSample:SetFrameLevel(RA.ConfigFrame:GetFrameLevel() + 120)
            placementSample:EnableMouse(false)
            kit.Backdrop(placementSample, {0.15,0.09,0.2,0.65}, C.orange, 6, false)
            placementSample.label = Text(placementSample, "PLACEMENT SAMPLE", 12, 8, -8, 250, C.text)
        end
        placementSample:ClearAllPoints()
        placementSample:SetPoint(values.Anchor, UIParent, values.relativeTo, values.xOffset, values.yOffset)
        Size(placementSample, values.Width or values.Size or 260, values.Height or values.Size or 50)
        placementSample.label:SetText((data.label or selectedSection) .. " — SAMPLE")
        placementSample:Show()
        Say(true, "Sample only. Apply local placement to save these coordinates in Northern Sky.")
    end)
    Point(previewPlacement, "LEFT", applyPlacement, "RIGHT", 14, 0)
    local stopPlacement = kit.Button(placementCard, "STOP PREVIEW", 190, 36, StopPreview)
    Point(stopPlacement, "LEFT", previewPlacement, "RIGHT", 14, 0)
    local restorePlacement = kit.Button(placementCard, "RESTORE LAST", 178, 36, function()
        local expectedContext = currentStatus.context
        Confirm("Restore the session placement backup?", "Restore the original values for the last edited Northern Sky section only if its profile and owned values are unchanged. Other settings stay intact.", function()
            local ok, reason = A:RestoreLastPlacement(expectedContext); Say(ok, reason)
            if ok then placementContext = nil end
        end)
    end)
    Point(restorePlacement, "LEFT", stopPlacement, "RIGHT", 14, 0)
    local keepPlacement = kit.Button(placementCard, "KEEP CURRENT / RELEASE UNDO", 310, 30, function() ReleaseUndo("placement") end)
    Point(keepPlacement, "TOPRIGHT", placementCard, "TOPRIGHT", -20, -300)
    Width(placementReason, 590)
    Text(placementCard, "Adjust position, dimensions, and text size for this local profile.", 10.5, 20, -348, 900)

    local function RecoveryText(kind)
        if not recoveryData then return nil end
        if kind ~= "placement" then
            local value = recoveryData[kind]
            return type(value) == "string" and value or nil
        end
        local placement = recoveryData.placement
        if type(placement) ~= "table" or type(placement.values) ~= "table" then return nil end
        local lines = {"Northern Sky placement backup", "Profile: " .. tostring(recoveryData.original or "Unknown"),
            "Section: " .. tostring(placement.label or placement.section or "Unknown")}
        for _, key in ipairs({"Anchor", "relativeTo", "xOffset", "yOffset", "Width", "Height", "FontSize", "TimerFontSize", "Size"}) do
            local value = placement.values[key]
            lines[#lines + 1] = key .. " = " .. (value == nil and "unset" or tostring(value))
        end
        return table.concat(lines, "\n")
    end
    local function SelectRecovery(kind)
        recoveryKind = kind
        recoveryBox:SetText(RecoveryText(kind) or "")
        for key, button in pairs(recoveryChoices) do
            Enable(button, RecoveryText(key) ~= nil); button:SetSelected(key == kind)
        end
    end
    local function ShowRecovery()
        local ok, reason, data = A:GetRecoveryBackup()
        if not ok then Say(false, reason); return end
        recoveryData = data
        if not recoveryOverlay then
            recoveryOverlay = CreateFrame("Frame", nil, RA.ConfigFrame, "BackdropTemplate")
            recoveryOverlay:SetAllPoints(RA.ConfigFrame); recoveryOverlay:EnableMouse(true)
            recoveryOverlay:SetFrameLevel(RA.ConfigFrame:GetFrameLevel() + 150)
            kit.Backdrop(recoveryOverlay, {0,0,0,0.7}, C.line, 14, false)
            local card = CreateFrame("Frame", nil, recoveryOverlay, "BackdropTemplate")
            Size(card, 780, 460); Point(card, "CENTER", recoveryOverlay, "CENTER", 0, 0)
            card:EnableMouse(true); kit.Backdrop(card, C.surface, C.lineStrong, 14, true)
            recoveryTitle = Text(card, "", 12, 20, -20, 740, C.text)
            recoveryBox = Editor(card, 20, -120, 740, 270, 0)
            local choices = {{"originalExport","ORIGINAL PROFILE EXPORT"},{"shared","SHARED NOTE BACKUP"},{"personal","PERSONAL NOTE BACKUP"},{"placement","PLACEMENT SETTINGS"}}
            for i, choice in ipairs(choices) do
                local key = choice[1]
                local button = kit.Button(card, choice[2], 179, 30, function() SelectRecovery(key) end)
                recoveryChoices[key] = button
                Point(button, "TOPLEFT", card, "TOPLEFT", 20+(i-1)*187, -76)
            end
            Text(card, "Local backup only. Select/copy it before repair or releasing this record.", 9.8, 20, -396, 700)
            local release = kit.Button(card, "KEEP CURRENT / RELEASE BACKUP", 310, 32, function()
                recoveryOverlay:Hide(); ReleaseUndo("recovery")
            end)
            Point(release, "BOTTOMLEFT", card, "BOTTOMLEFT", 20, 18)
            local copy = kit.Button(card, "SELECT TEXT", 140, 32, function() recoveryBox:SetFocus(); recoveryBox:HighlightText() end)
            Point(copy, "BOTTOMRIGHT", card, "BOTTOMRIGHT", -178, 18)
            local close = kit.Button(card, "CLOSE", 140, 32, function() recoveryOverlay:Hide() end)
            Point(close, "BOTTOMRIGHT", card, "BOTTOMRIGHT", -20, 18)
        end
        local label = ({note = "Note", profile = "Profile", placement = "Placement"})[data.kind] or "Profile"
        recoveryTitle:SetText(label .. " recovery backup · original " .. Literal(data.original) .. " · observed " .. Literal(data.observedProfile) .. "\n" .. Literal(data.phase) .. ": " .. Literal(data.reason))
        local initial = data.kind == "placement" and "placement" or (data.kind == "note" and "shared" or "originalExport")
        if RecoveryText(initial) == nil then initial = "shared" end
        SelectRecovery(initial)
        recoveryOverlay:Show()
    end
    local recoveryEntry = kit.Button(parent, "RECOVERY BACKUP", 210, 30, ShowRecovery)
    Point(recoveryEntry, "TOPRIGHT", parent, "TOPRIGHT", 0, -628)
    recoveryEntry:Hide()
    local recoveryButton = kit.Button(profileDetails, "REVIEW RECOVERY BACKUP", 218, 30, ShowRecovery)
    Point(recoveryButton, "TOPLEFT", profileDetails, "TOPLEFT", 18, -296)
    local keepProfile = kit.Button(profileDetails, "KEEP CURRENT / RELEASE UNDO", 218, 30, function() ReleaseUndo("profile") end)
    Point(keepProfile, "LEFT", recoveryButton, "RIGHT", 12, 0)

    -- Group controls so the refresh closure stays below Lua 5.1 upvalue limits.
    local view = {
        status = status,
        original = original,
        panels = panels,
        tabs = tabs,
        noteBox = noteBox,
        noteCard = noteCard,
        shared = shared,
        personal = personal,
        reviewCurrent = reviewCurrent,
        useContext = useContext,
        noteHint = noteHint,
        noteScope = noteScope,
        noteReason = noteReason,
        applyNote = applyNote,
        restoreNote = restoreNote,
        keepNote = keepNote,
        loadCurrent = loadCurrent,
        profileRows = profileRows,
        profileChild = profileChild,
        profileText = profileText,
        profileReason = profileReason,
        applyProfile = applyProfile,
        restoreProfile = restoreProfile,
        recoveryButton = recoveryButton,
        keepProfile = keepProfile,
        sectionButtons = sectionButtons,
        placementCard = placementCard,
        placementLabel = placementLabel,
        placementInputs = placementInputs,
        placementReason = placementReason,
        applyPlacement = applyPlacement,
        previewPlacement = previewPlacement,
        restorePlacement = restorePlacement,
        keepPlacement = keepPlacement,
    }
    refresh = function(reload)
        if refreshing then return end
        refreshing = true
        A:Refresh()
        currentStatus = A:GetStatus()
        recoveryEntry:SetShown(currentStatus.recovery ~= nil)
        Width(message, currentStatus.recovery and 720 or 950)
        local caps, reasons = currentStatus.capabilities or {}, currentStatus.reasons or {}
        view.status:SetText("Northern Sky " .. Literal(currentStatus.version) .. "  ·  " .. (currentStatus.available and (currentStatus.compatible and "Connected" or "Read-only") or "Unavailable") .. "\nInstalled " .. Tri(currentStatus.installed) .. " · Enabled " .. Tri(currentStatus.enabled) .. " · Loaded " .. Tri(currentStatus.loaded) .. (currentStatus.reason and (" · " .. currentStatus.reason) or ""))
        uiInfo:SetText("Original UI: installed " .. Tri(currentStatus.uiInstalled) .. " · enabled " .. Tri(currentStatus.uiEnabled) .. " · loaded " .. Tri(currentStatus.uiLoaded))
        Enable(view.original, caps.openSettings)
        for key, panel in pairs(view.panels) do panel:SetShown(key == subview) end
        for key, button in pairs(view.tabs) do button:SetSelected(key == subview) end
        if subview == "NOTES" then
            local ok, reason, data = A:GetNotes()
            if ok then livePersonal = data.personal end
            if ok and not noteData then
                local hadDraft = draft ~= nil
                noteData, noteContext, sourceShared = data, nil, data.shared
                if not hadDraft then draft, noteContext = data.shared, data.context end
            elseif ok and reload and (draft == nil or draft == sourceShared) then
                noteData, noteContext, sourceShared, draft = data, data.context, data.shared, data.shared
            end
            loading = true
            local text = noteKind == "personal" and (livePersonal or "") or (noteKind == "current" and (reviewedNote and reviewedNote.shared or "") or (draft or ""))
            if view.noteBox:GetText() ~= text then view.noteBox:SetText(text) end
            loading = false
            view.noteCard.title:SetText(noteKind == "personal" and "PERSONAL NOTE — VIEW ONLY" or (noteKind == "current" and "CURRENT SHARED NOTE — REVIEW" or "SHARED NOTE — LOCAL DRAFT"))
            view.shared:SetSelected(noteKind == "shared"); view.personal:SetSelected(noteKind == "personal"); view.reviewCurrent:SetSelected(noteKind == "current")
            Enable(view.useContext, noteKind == "current" and reviewedNote ~= nil)
            view.noteHint:SetText(noteKind == "personal" and "Personal note is view-only here." or (noteKind == "current" and "Review snapshot. Your shared draft is retained." or ((draft ~= sourceShared) and "Unsaved shared draft." or "Current shared note loaded.")))
            local changed = ok and noteContext and data.context ~= noteContext
            local shownContext = noteKind == "current" and reviewedNote or (noteKind == "personal" and data or noteData)
            view.noteScope:SetText("Profile: " .. Literal(shownContext and shownContext.profile) .. "\nActive note: " .. Literal(shownContext and shownContext.activeName) .. "\n\nYour draft stays in Arsenal until you save a local copy. Restore is available only in this session and unchanged context.")
            view.noteReason:SetText((not noteContext and draft ~= nil and ok) and "Your draft is retained. Review the current shared note and acknowledge its context before applying." or (changed and "Northern Sky changed. Keep your draft; review the current note before applying." or (reasons.applyNote or reason or "If you turn AutoShare on later, Northern Sky can send the active copy on a ready/pull check.")))
            Enable(view.applyNote, caps.applyNote and noteKind == "shared" and not changed and noteContext ~= nil)
            Enable(view.restoreNote, currentStatus.canRestoreNote)
            Enable(view.keepNote, currentStatus.hasNoteBackup)
            Enable(view.loadCurrent, caps.notes)
        elseif subview == "PROFILES" then
            local ok, reason, data = A:GetProfiles()
            local names = ok and data.names or {}
            for i, name in ipairs(names) do
                local button = view.profileRows[i]
                if not button then
                    button = kit.Button(view.profileChild, "", 398, 32, function() end)
                    Point(button, "TOPLEFT", view.profileChild, "TOPLEFT", 0, -(i-1)*38)
                    view.profileRows[i] = button
                end
                button.label:SetText(Literal(name)); button:SetSelected(name == selectedProfile)
                button.label:SetWordWrap(false)
                button.label:ClearAllPoints()
                Point(button.label, "LEFT", button, "LEFT", 10, 0)
                Point(button.label, "RIGHT", button, "RIGHT", -10, 0)
                button.label:SetJustifyH("LEFT")
                button:SetScript("OnClick", function()
                    local selected, why, selection = A:SelectProfile(name)
                    if selected then selectedProfile, profileContext = name, selection.context end
                    Say(selected, why); refresh(false)
                end)
                button:Show()
            end
            for i = #names + 1, #view.profileRows do view.profileRows[i]:Hide() end
            T.SetHeight(view.profileChild, math.max(365, #names * 38))
            view.profileText:SetText("Current: " .. Literal(currentStatus.profile) .. "\nSelected source: " .. Literal(selectedProfile) .. "\n\nApply creates and selects a separate Arsenal-owned copy. Your current notes, local placement, and AutoShare are preserved; the selected original is retained. No shared extra-data import or send is performed.")
            view.profileReason:SetText((currentStatus.hasProfileBackup and not currentStatus.canRestoreProfile) and "Northern Sky changed; undo cannot overwrite it. Keep Current releases this session undo." or (reasons.applyProfile or reason or ""))
            Enable(view.applyProfile, caps.applyProfile and selectedProfile ~= nil and profileContext ~= nil)
            Enable(view.restoreProfile, currentStatus.canRestoreProfile)
            Enable(view.recoveryButton, currentStatus.recovery ~= nil)
            Enable(view.keepProfile, currentStatus.hasProfileBackup)
        else
            local sections = A.PlacementSections or {}
            if not selectedSection and sections[1] then selectedSection = sections[1].id end
            for i, section in ipairs(sections) do
                local button = view.sectionButtons[i]
                if not button then
                    button = kit.Button(view.placementCard, "", 124, 30, function() end)
                    Point(button, "TOPLEFT", view.placementCard, "TOPLEFT", 20+(i-1)*129, -68)
                    view.sectionButtons[i] = button
                end
                button.label:SetText(section.label); button:SetSelected(selectedSection == section.id)
                button:SetScript("OnClick", function()
                    StopPreview(); selectedSection, placementContext = section.id, nil; refresh(false)
                end)
                button:Show()
            end
            local ok, reason, data = A:GetPlacement(selectedSection)
            local fields = ok and data.fields or {}
            view.placementLabel:SetText(ok and (data.label or selectedSection) or (reason or "Placement unavailable; use original settings."))
            for _, input in pairs(view.placementInputs) do input:Hide(); input.title:Hide() end
            for i, field in ipairs(fields) do
                local input = view.placementInputs[field.key]
                if not input then
                    if field.options then
                        input = kit.Button(view.placementCard, "", 200, 34, function() end)
                        input:SetScript("OnClick", function(control)
                            local nextIndex = 1
                            for index, option in ipairs(control.options) do
                                if option == control.value then nextIndex = index % #control.options + 1; break end
                            end
                            control.value = control.options[nextIndex]
                            control.label:SetText(Literal(control.value))
                        end)
                        function input:GetInputValue() return self.value end
                    else
                        input = CreateFrame("EditBox", nil, view.placementCard, "BackdropTemplate")
                        Size(input, 200, 34); input:SetAutoFocus(false); input:SetMaxLetters(12)
                        kit.Backdrop(input, C.input, C.line, 8, false); RA:ApplyFont(input, 11, "REGULAR", false)
                        input:SetTextInsets(10,10,0,0)
                        input:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
                        function input:GetInputValue() return tonumber(self:GetText()) end
                    end
                    input.title = Text(view.placementCard, "", 10, 0, 0, 200)
                    view.placementInputs[field.key] = input
                end
                input:ClearAllPoints(); input.title:ClearAllPoints()
                local x, y = 20+((i-1)%4)*224, -176-math.floor((i-1)/4)*74
                Point(input.title, "TOPLEFT", view.placementCard, "TOPLEFT", x, y+20)
                Point(input, "TOPLEFT", view.placementCard, "TOPLEFT", x, y)
                local fieldLabel = ({FontSize = "Font size", TimerFontSize = "Timer font size", xOffset = "Horizontal offset", yOffset = "Vertical offset", relativeTo = "Relative anchor"})[field.key] or field.label or field.key
                input.title:SetText(fieldLabel .. (field.options and " (click to cycle)" or (" (" .. field.min .. "–" .. field.max .. ")")))
                if field.options then
                    input.options = field.options
                    if not placementContext or reload then input.value = data.values[field.key]; input.label:SetText(Literal(input.value)) end
                elseif not placementContext or reload then input:SetText(tostring(data.values[field.key] or "")) end
                input:Show(); input.title:Show()
            end
            if ok and (not placementContext or reload) then placementContext = data.context end
            view.placementReason:SetText(reasons.setPlacement or reason or "Changes affect only this local Northern Sky profile. Preview is a labeled sample, not an active reminder.")
            local changed = ok and placementContext and placementContext ~= data.context
            if changed then view.placementReason:SetText("Northern Sky placement changed. Refresh to review its current values before applying.") end
            Enable(view.applyPlacement, caps.setPlacement and placementContext ~= nil and not changed)
            Enable(view.previewPlacement, caps.placement and ok)
            Enable(view.restorePlacement, currentStatus.canRestorePlacement)
            Enable(view.keepPlacement, currentStatus.hasPlacementBackup)
        end
        refreshing = false
    end
    parent:HookScript("OnHide", function()
        StopPreview(); if confirmation then confirmation:Hide() end
        if recoveryOverlay then recoveryOverlay:Hide() end
    end)
    RA.ConfigFrame:HookScript("OnHide", function()
        StopPreview(); if confirmation then confirmation:Hide() end
        if recoveryOverlay then recoveryOverlay:Hide() end
    end)
    RA:RegisterEvent("PLAYER_REGEN_DISABLED", StopPreview)
    RA:RegisterCallback("NSRT_ADAPTER_CHANGED", function()
        if parent:IsVisible() then refresh(false) end
    end)
    return refresh
end
