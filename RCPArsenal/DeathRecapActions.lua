local _, RA = ...
local R=RA.DeathRecap
local function Public(value)
    if type(issecretvalue)~="function"then return nil end
    local ok,secret=pcall(issecretvalue,value);if ok and secret==false then return value end
end
local function Read(fn,...)
    if type(fn)~="function"then return nil end
    local ok,value=pcall(fn,...);if ok then return Public(value)end
end
local function OpenAllowed()
    return Read(InCombatLockdown)==false
end
function R:BuildShareText(page,preview)
    if type(page)~="table"or(preview~=true and page~=self:GetPage())then return nil,"No recorded personal recap"end
    local text=preview==true and"RCP Preview report: fictional sample data."or"RCP personal recap: partial capture."
    if page.native then
        local fatal
        for _,row in ipairs(page.native.rows)do if row.nativeIndex==1 then fatal=row end end
        local label=fatal and fatal.kind=="damage"and" Recorded hit: "or" Native record: "
        if fatal and fatal.name and not fatal.name:find("[|\r\n]")then text=text..label..fatal.name.."."
        elseif fatal and fatal.spellID then text=text..label.."spell "..fatal.spellID.."."end
        if fatal and fatal.amount then text=text.." Amount "..string.format("%.0f",fatal.amount).."."end
    else text=text.." Current native records unavailable."end
    return text
end
function R:PrepareShare(channel,target,page,preview)
    local text,reason=self:BuildShareText(page,preview)
    if not text then return false,reason end
    if channel~="WHISPER"and channel~="SAY"and channel~="PARTY"and channel~="RAID"then return false,"Choose a supported channel"end
    if Read(C_ChatInfo and C_ChatInfo.InChatMessagingLockdown or InChatMessagingLockdown)~=false then return false,"Chat is restricted or its status is unknown"end
    if Read(C_SocialRestrictions and C_SocialRestrictions.CanSendChat)~=true then return false,"Chat permission is unavailable"end
    if channel=="PARTY"and Read(IsInGroup)~=true then return false,"Not in a party"end
    if channel=="RAID"and Read(IsInRaid)~=true then return false,"Not in a raid"end
    if channel=="WHISPER"then
        target=Public(target)
        if type(target)~="string"or #target==0 or #target>80 or target:find("[%s|/\r\n%z]")then return false,"Enter a valid whisper recipient"end
    end
    if type(ChatFrame_OpenChat)~="function"or type(ChatEdit_GetActiveWindow)~="function"or type(ChatEdit_UpdateHeader)~="function"then return false,"Native composer unavailable; copy the summary"end
    local ok=pcall(function()
        ChatFrame_OpenChat(text)
        local box=ChatEdit_GetActiveWindow();if not box then error("composer unavailable")end
        box:SetAttribute("chatType",channel)
        if channel=="WHISPER"then box:SetAttribute("tellTarget",target)end
        ChatEdit_UpdateHeader(box)
    end)
    return ok,ok and "Chat prepared; review and submit in the native composer"or"Native composer unavailable; copy the summary"
end
function R:GetJournalMapping(page,row)
    if type(page)~="table"or type(row)~="table"or page~=self:GetPage()or not page.encounter or not row.spellID then return nil end
    for _,map in ipairs((RA.DeathRecapCatalog or {}).journal or {})do
        if map.verified==true and map.encounterID==page.encounter.encounterID and map.difficulty==page.encounter.difficulty
            and map.spellID==row.spellID then return map end
    end
end
function R:OpenJournal(page,row)
    local map=self:GetJournalMapping(page,row)
    if not map then return false,"No verified Journal mapping"end
    if not OpenAllowed()then return false,"Available after combat"end
    local ok=pcall(function()
        if type(EncounterJournal_LoadUI)=="function"then EncounterJournal_LoadUI()end
        local info=Read(C_EncounterJournal and C_EncounterJournal.GetSectionInfo,map.sectionID)
        if type(info)~="table"or Public(info.spellID)~=row.spellID or Public(info.filteredByDifficulty)~=false then error("section unverified")end
        if type(EncounterJournal_OpenJournal)~="function"then error("journal unavailable")end
        EncounterJournal_OpenJournal(map.difficulty,map.instanceID,map.journalEncounterID,map.sectionID)
    end)
    return ok,ok and "Journal opened"or"Journal entry unavailable"
end
