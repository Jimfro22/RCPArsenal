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
local function Number(value)
    value=Public(value)
    if type(value)=="number"and value==value and math.abs(value)~=math.huge then return value end
end
local function Plain(value)
    value=Public(value)
    if type(value)=="string"and #value>0 and #value<=128 and not value:find("[%c|]")then return value end
end
local function Name(row)
    local id=Number(row.spellID)
    return Plain(row.name)or(id and "spell "..string.format("%.0f",id))or"Unknown event"
end
local function Amount(value)
    value=Number(value)
    if not value or value<0 then return nil end
    local text=string.format("%.0f",value)
    return text:reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")
end
local function FightTime(value)
    if value==nil or value<0 then return nil end
    local centiseconds=math.floor(value*100+.5)
    return string.format("%d:%05.2f",math.floor(centiseconds/6000),(centiseconds%6000)/100)
end
local function Relative(value,label)
    return value and string.format("%s%+.2fs",label,value)or(label.."time unavailable")
end
local function SortEvents(a,b)
    if a.time~=b.time then return(a.time or math.huge)<(b.time or math.huge)end
    if a.kind=="death"or b.kind=="death"then return a.kind~="death"and b.kind=="death"end
    if a.index~=b.index then return a.index<b.index end
    return a.order<b.order
end
local function RetainedRows(input)
    -- Match the display's bounded oversize retention without calculating group
    -- totals or trusting an optional amount for arithmetic.
    local rows,fatal,largest,maximum={},nil,nil,nil
    for i=1,math.min(#input,256)do
        local row=input[i];local amount=Number(row.amount)
        if row.nativeIndex==1 then fatal=row end
        if row.nativeIndex~=1 and row.kind=="damage"and amount and(not maximum or amount>maximum)then largest,maximum=row,amount end
        if i<=64 then rows[#rows+1]=row end
    end
    for _,important in ipairs({fatal or false,largest or false})do if important then
        local present=false;for _,row in ipairs(rows)do if row==important then present=true end end
        if not present then for i=#rows,1,-1 do if rows[i]~=fatal and rows[i]~=largest then rows[i]=important;break end end end
    end end
    return rows,#input>64
end
-- A report is a snapshot of retained facts, not an aggregation of rendered
-- groups. Interleaved groups and equal-time hits keep every original row.
function R:BuildShareReport(page,preview)
    if type(page)~="table"or(preview~=true and page~=self:GetPage())then return nil,"No recorded personal recap"end
    preview=preview==true
    local report={preview=preview,lines={},entries={},sections={}}
    local function Line(text)report.lines[#report.lines+1]=text end
    local context={page.specID==62 and"Arcane Mage"or Plain(page.class)or"Personal"}
    if page.encounter then
        context[#context+1]=Plain(page.encounter.name)
        if page.encounter.difficulty==16 then context[#context+1]="Mythic"end
    end
    Line((preview and"RCP Preview — fictional sample"or"RCP Death Log — partial capture").." · "..table.concat(context," / "))
    local died,started=Number(page.diedAt),page.encounter and Number(page.encounter.startedAt)
    local fight=died and started and died>=started and died-started or nil
    local native,localEvents={},{}
    local order=0
    local function Add(list,kind,time,index,text)
        order=order+1;list[#list+1]={kind=kind,time=time,index=index or order,order=order,text=text}
    end
    local rows=page.native and page.native.rows or{}
    local retained,truncated=RetainedRows(rows)
    for _,row in ipairs(retained)do
        local amount=Amount(row.amount)
        local text=Name(row)..": "..(row.kind=="damage"and(amount and amount.." damage"or"damage amount unavailable")or(amount and amount.." (event type unknown)"or"event type unknown"))
        if row.kind=="damage"then
            local absorbed,overkill=Amount(row.absorbed),Amount(row.overkill)
            if absorbed and Number(row.absorbed)>0 then text=text.."; "..absorbed.." absorbed"end
            if overkill and Number(row.overkill)>0 then text=text.."; "..overkill.." overkill"end
        end
        if row.nativeIndex==1 then text=text..(row.kind=="damage"and"; fatal hit"or"; death record")end
        Add(native,row.kind=="damage"and"damage"or"unknown",Number(row.nativeOffset),Number(row.nativeIndex),text)
    end
    if preview then
        local heals,supports=page.heals or{},page.supports or{}
        for i=1,math.min(#heals,64)do local row=heals[i]
            local amount=Amount(row.amount)
            local healer=Plain(row.healer)
            Add(native,"healing",Number(row.offset),Number(row.nativeIndex),Name(row)..": "..(amount and amount.." healing"or"healing amount unavailable")..(healer and" from "..healer or""))
        end
        for i=1,math.min(#supports,64)do local row=supports[i]
            local item=(RA.DeathRecapCatalog or{}).itemUseSpells or{}
            Add(native,"use",Number(row.offset),Number(row.nativeIndex),Name(row)..(item[row.spellID]and": item use"or": defensive use"))
        end
        Add(native,"death",0,math.huge,"Death")
    else
        local casts=page.casts or{}
        for i=math.max(1,#casts-63),#casts do local row=casts[i]
            local observed=Number(row.observedAt)
            local item=(RA.DeathRecapCatalog or{}).itemUseSpells or{}
            Add(localEvents,"use",observed,i,Name(row)..(item[row.spellID]and": observed item use"or": observed defensive use"))
        end
        Add(localEvents,"death",died,math.huge,"Death observed")
    end
    local function Section(title,events,clock)
        Line(title);report.sections[#report.sections+1]={title=title,clock=clock,events=events}
        table.sort(events,SortEvents)
        for _,event in ipairs(events)do
            local stamp
            if clock=="preview"then stamp=fight and event.time and FightTime(fight+event.time)or Relative(event.time,"sample ")
            elseif clock=="local"then stamp=started and event.time and FightTime(event.time-started)or Relative(event.time and died and event.time-died,"local ")
            else stamp=Relative(event.time,"recap ")end
            event.clock=clock;event.line="- ["..stamp.."] "..event.text
            report.entries[#report.entries+1]=event;Line(event.line)
        end
    end
    if preview then Section("Fight timeline",native,"preview")
    else
        Section("Native recap (relative to latest retained event; fight time unavailable)",native,"native")
        if #native==0 then Line("Native records unavailable.")end
        Section("Local observations (not aligned to native recap)",localEvents,"local")
        Line("Uses cover the last 30 seconds or fewer; missing uses are unknown. Live healing and effect durations were not captured.")
    end
    if truncated or(page.native and page.native.truncated)then Line("Native capture is truncated; all retained report rows are included.")end
    report.text=table.concat(report.lines,"\n")
    return report
end
function R:BuildShareText(page,preview)
    local report,reason=self:BuildShareReport(page,preview)
    return report and report.text or nil,reason
end
-- 255 bytes is our conservative plain-text submission budget. It is not a
-- claim about a documented server throttle. Never cut a UTF-8 code point or
-- silently drop the tail of a report to fit that budget.
function R:BuildShareMessages(report)
    if type(report)~="table"or type(report.lines)~="table"then return nil,"Report unavailable"end
    local messages={}
    for _,line in ipairs(report.lines)do
        line=Public(line)
        if type(line)~="string"or line:find("[%c|]")then return nil,"Report contains unsupported chat text"end
        local remaining,prefix=line,""
        repeat
            local limit=255-#prefix;local cut=math.min(#remaining,limit)
            if cut<#remaining then
                while cut>0 do local nextByte=remaining:byte(cut+1);if not nextByte or nextByte<128 or nextByte>=192 then break end;cut=cut-1 end
                if cut==0 then return nil,"Report contains unsupported text encoding"end
                local space
                for i=1,cut do if remaining:sub(i,i)==" "then space=i end end
                if space and space>cut/2 then cut=space end
            end
            messages[#messages+1]=prefix..remaining:sub(1,cut)
            remaining=remaining:sub(cut+1);prefix="... "
            if #messages>256 then return nil,"Report exceeds the bounded chat size; select text to copy it"end
        until #remaining==0
    end
    return messages
end
function R:ValidWhisperTarget(target)
    target=Public(target)
    return type(target)=="string"and #target>0 and #target<=80 and not target:find("[%s%c|/]")
end
local function ShareAllowed(channel,target)
    if channel~="WHISPER"and channel~="SAY"and channel~="PARTY"and channel~="RAID"then return false,"Choose a supported channel"end
    if not OpenAllowed()then return false,"Available after combat"end
    if Read(C_ChatInfo and C_ChatInfo.InChatMessagingLockdown)~=false then return false,"Chat is restricted or its status is unknown"end
    if Read(C_SocialRestrictions and C_SocialRestrictions.CanSendChat)~=true then return false,"Chat permission is unavailable"end
    if channel=="PARTY"and Read(IsInGroup)~=true then return false,"Not in a party"end
    if channel=="RAID"and Read(IsInRaid)~=true then return false,"Not in a raid"end
    if channel=="WHISPER"then
        if not R:ValidWhisperTarget(target)then return false,"Enter a valid whisper recipient"end
    end
    if not C_ChatInfo or type(C_ChatInfo.SendChatMessage)~="function"then return false,"Chat submission unavailable; select text to copy"end
    return true
end
local shareJob,shareTimer,shareGeneration=nil,nil,0
local shareEvents={}
local function ShareSubscriptions(active)
    for _,subscription in ipairs(shareEvents)do subscription:SetEnabled(active)end
end
local function NotifyShare(job)
    if job.changed then pcall(job.changed,{status=job.status,submitted=job.submitted,total=#job.messages,channel=job.channel,target=job.target,reason=job.reason,manual=job.channel=="SAY"})end
end
local function StopShare(job,status,reason)
    if job~=shareJob then return end
    shareGeneration=shareGeneration+1
    if shareTimer then shareTimer:Cancel();shareTimer=nil end
    job.status,job.reason=status,reason;ShareSubscriptions(false);NotifyShare(job)
end
function R:CancelShare(reason)
    if shareJob and shareJob.status=="posting"then StopShare(shareJob,"stopped",reason or"Cancelled")end
end
local function DispatchShare(job,generation)
    if shareJob~=job or shareGeneration~=generation or job.status~="posting"then return end
    local current=job.current and Read(job.current)
    if current~=true then StopShare(job,"stopped","This report is no longer open");return end
    local now=Number(Read(GetTime))
    if not now or now<job.started or now>job.deadline then StopShare(job,"stopped","Report submission expired");return end
    local allowed,reason=ShareAllowed(job.channel,job.target)
    if not allowed then StopShare(job,"stopped",reason);return end
    local message=Public(job.messages[job.submitted+1])
    if type(message)~="string"or #message>255 or message:find("[%c|]")then StopShare(job,"stopped","Unsupported chat text");return end
    local ok=pcall(C_ChatInfo.SendChatMessage,message,job.channel,nil,job.target)
    if not ok then StopShare(job,"stopped","Chat submission failed; no retry queued");return end
    job.submitted=job.submitted+1
    if job.submitted==#job.messages then StopShare(job,"complete");return end
    NotifyShare(job)
    if shareJob~=job or shareGeneration~=generation or job.status~="posting"then return end
    if job.channel~="SAY"then
        local scheduled,timer=pcall(C_Timer.NewTimer,1,function()
            if shareJob~=job or shareGeneration~=generation then return end
            shareTimer=nil;DispatchShare(job,generation)
        end)
        if not scheduled or not timer then StopShare(job,"stopped","Unable to schedule remaining messages");return end
        shareTimer=timer
    end
end
function R:StartShare(channel,target,report,current,changed)
    if shareJob and shareJob.status=="posting"then return false,"A report is already posting"end
    if shareJob and shareJob.report==report and shareJob.submitted>0 then return false,"This report was already submitted in part or in full"end
    local allowed,reason=ShareAllowed(channel,target);if not allowed then return false,reason end
    local messages;messages,reason=self:BuildShareMessages(report);if not messages or #messages==0 then return false,reason or"Report is empty"end
    if channel~="SAY"and(not C_Timer or type(C_Timer.NewTimer)~="function")then return false,"Chat queue unavailable; select text to copy"end
    local now=Number(Read(GetTime));if not now or Read(current)~=true then return false,"This report is no longer open"end
    shareGeneration=shareGeneration+1
    shareJob={report=report,messages=messages,channel=channel,target=channel=="WHISPER"and target or nil,current=current,changed=changed,
        started=now,deadline=now+(channel=="SAY"and 600 or math.max(30,#messages+15)),submitted=0,status="posting"}
    ShareSubscriptions(true);NotifyShare(shareJob);DispatchShare(shareJob,shareGeneration)
    return true
end
function R:SendNextShare(report)
    if not shareJob or shareJob.report~=report or shareJob.status~="posting"or shareJob.channel~="SAY"then return false end
    DispatchShare(shareJob,shareGeneration);return true
end
for _,event in ipairs({"PLAYER_REGEN_DISABLED","ENCOUNTER_START","PLAYER_ENTERING_WORLD","PLAYER_LOGOUT","GROUP_ROSTER_UPDATE"})do
    shareEvents[#shareEvents+1]=RA:RegisterOptionalEvent(event,function()
        if event~="GROUP_ROSTER_UPDATE"or(shareJob and(shareJob.channel=="PARTY"or shareJob.channel=="RAID"))then R:CancelShare(event=="GROUP_ROSTER_UPDATE"and"Group changed"or"Context changed")end
    end)
end
RA:RegisterCallback("PROFILE_RESET",function()R:CancelShare("Profile changed")end)
RA:RegisterCallback("DEATH_RECAP_CHANGED",function(kind)
    if kind=="death"or kind=="life"or(kind=="settings"and not R:GetState().enabled)then R:CancelShare("Recap context changed")end
end)
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
