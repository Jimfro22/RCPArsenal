local _, RA = ...
local R=RA.DeathRecap
local function Public(value)
    if type(issecretvalue)~="function"then return nil end
    local ok,secret=pcall(issecretvalue,value);if ok and secret==false then return value,true end
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
-- Link markup is never taken from captured rows. Only public native spell links
-- with the requested integer ID can enter this private report-token store.
local reportTokens=setmetatable({},{__mode="k"})
local function SpellID(value)
    value=Number(value)
    if value and value>0 and value<=2147483647 and value==math.floor(value)then return value end
end
local function UTF8(text)
    local i=1
    while i<=#text do
        local a,b,c,d=text:byte(i,i+3);local count
        if a<128 then count=1
        elseif a>=194 and a<=223 and b and b>=128 and b<=191 then count=2
        elseif a>=224 and a<=239 and b and c and c>=128 and c<=191
            and b>=(a==224 and 160 or 128)and b<=(a==237 and 159 or 191)then count=3
        elseif a>=240 and a<=244 and b and c and d and c>=128 and c<=191 and d>=128 and d<=191
            and b>=(a==240 and 144 or 128)and b<=(a==244 and 143 or 191)then count=4
        else return false end
        i=i+count
    end
    return true
end
local function PlainChat(text)
    text=Public(text)
    return type(text)=="string"and not text:find("[%c|]")and UTF8(text)
end
local function SpellLink(value,id)
    value=Public(value)
    if type(value)~="string"or #value>251 or value:find("%c")or not UTF8(value)then return nil end
    local body=value
    if body:sub(1,2)=="|c"then
        if not body:match("^|c%x%x%x%x%x%x%x%x")or body:sub(-2)~="|r"then return nil end
        body=body:sub(11,-3)
    end
    local linkedID,tail,label=body:match("^|Hspell:(%d+)([:%d]*)|h%[([^%[%]|]+)%]|h$")
    if not linkedID or tonumber(linkedID)~=id or(tail~=""and tail:sub(1,1)~=":")or not Plain(label)then return nil end
    return value,label
end
local function ShareNames()
    local cache,count={},0
    return function(row)
        local id=SpellID(row.spellID);local metadata=id and cache[id]
        if id and not metadata and count<192 then
            count=count+1;metadata={};cache[id]=metadata
            metadata.link,metadata.name=SpellLink(Read(C_Spell and C_Spell.GetSpellLink,id),id)
            if not metadata.name then metadata.name=Plain(Read(C_Spell and C_Spell.GetSpellName,id))end
        end
        local name=metadata and metadata.name or Plain(row.name)or(id and "spell "..string.format("%.0f",id))or"Unknown event"
        return name,metadata and metadata.link
    end
end
local function Amount(value)
    value=Number(value)
    if not value or value<0 then return nil end
    local text=string.format("%.0f",value)
    return text:reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")
end
local function FightTime(value)
    if value==nil then return "Time unknown"end
    local magnitude=math.abs(value)
    local minutes,seconds=math.floor(magnitude/60),math.floor((magnitude%60)*10+.5)/10
    if seconds==60 then minutes,seconds=minutes+1,0 end
    return string.format("%s%.0f:%04.1f",value<0 and(minutes>0 or seconds>0)and"-"or"",minutes,seconds)
end
local function Relative(value)
    if value==nil then return "Time unknown"end
    local magnitude=string.format("%.1f",math.abs(value))
    return(magnitude~="0.0"and(value<0 and"-"or"+")or"")..magnitude.."s"
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
    local tokens={lines={},links={}};reportTokens[report]=tokens
    local Name=ShareNames()
    local function Line(text,parts)
        report.lines[#report.lines+1]=text;tokens.lines[#tokens.lines+1]=parts or{text}
    end
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
    local eventLinks={}
    local function Add(list,kind,time,index,text,name,link)
        order=order+1;local entry={kind=kind,time=time,index=index or order,order=order,text=text};list[#list+1]=entry
        if link then eventLinks[entry]={name=name,link=link};tokens.links[link]=true end
    end
    local rows=page.native and page.native.rows or{}
    local retained,truncated=RetainedRows(rows)
    for _,row in ipairs(retained)do
        local amount=Amount(row.amount)
        local name,link=Name(row)
        local text=name..": "..(row.kind=="damage"and(amount and amount.." damage"or"damage amount unavailable")or(amount and amount.." (event type unknown)"or"event type unknown"))
        if row.kind=="damage"then
            local absorbed,overkill=Amount(row.absorbed),Amount(row.overkill)
            if absorbed and Number(row.absorbed)>0 then text=text.."; "..absorbed.." absorbed"end
            if overkill and Number(row.overkill)>0 then text=text.."; "..overkill.." overkill"end
        end
        if row.nativeIndex==1 then text=text..(row.kind=="damage"and"; fatal hit"or"; death record")end
        local source=Public(row.hideCaster)==false and Plain(row.sourceName)
        if source then text=text.."; recorded source: "..source end
        Add(native,row.kind=="damage"and"damage"or"unknown",Number(row.nativeOffset),Number(row.nativeIndex),text,name,link)
    end
    if preview then
        local heals,supports=page.heals or{},page.supports or{}
        for i=1,math.min(#heals,64)do local row=heals[i]
            local amount=Amount(row.amount)
            local healer=Plain(row.healer);local name,link=Name(row)
            Add(native,"healing",Number(row.offset),Number(row.nativeIndex),name..": "..(amount and amount.." healing"or"healing amount unavailable")..(healer and" from "..healer or""),name,link)
        end
        for i=1,math.min(#supports,64)do local row=supports[i]
            local item=(RA.DeathRecapCatalog or{}).itemUseSpells or{}
            local name,link=Name(row)
            Add(native,"use",Number(row.offset),Number(row.nativeIndex),name..(item[row.spellID]and": item use"or": defensive use"),name,link)
        end
        Add(native,"death",0,math.huge,"Death")
    else
        local casts=page.casts or{}
        for i=math.max(1,#casts-63),#casts do local row=casts[i]
            local observed=Number(row.observedAt)
            local item=(RA.DeathRecapCatalog or{}).itemUseSpells or{}
            local name,link=Name(row)
            Add(localEvents,"use",observed,i,name..(item[row.spellID]and": item use"or": defensive use"),name,link)
        end
        Add(localEvents,"death",died,math.huge,"Death")
    end
    local function Section(title,events,clock)
        Line(title);report.sections[#report.sections+1]={title=title,clock=clock,events=events}
        table.sort(events,SortEvents)
        for _,event in ipairs(events)do
            local stamp
            if clock=="preview"then stamp=fight and event.time and FightTime(fight+event.time)or Relative(event.time)
            elseif clock=="local"then stamp=fight and FightTime(event.time and event.time-started)or Relative(event.time and died and event.time-died)
            else stamp=Relative(event.time)end
            event.clock=clock;event.line="- ["..stamp.."] "..event.text
            report.entries[#report.entries+1]=event
            local decoration=eventLinks[event]
            Line(event.line,decoration and{"- ["..stamp.."] ",{link=decoration.link},event.text:sub(#decoration.name+1)}or nil)
        end
    end
    if preview then Section("Fight timeline",native,"preview")
    else
        local damageOnly=true;for _,event in ipairs(native)do if event.kind~="damage"then damageOnly=false;break end end
        Section(damageOnly and"Damage · times before final recorded hit"or"Recorded events · times before final record",native,"native")
        if #native==0 then Line("Damage records unavailable.")end
        Section(fight and"Abilities used · fight time"or"Abilities used · times before death",localEvents,"local")
        Line("Separate timelines. Uses cover up to 30 seconds; missing uses are unknown. Healing and effect durations were not recorded.")
    end
    if truncated or(page.native and page.native.truncated)then Line("Record is truncated; all retained events are included.")end
    report.text=table.concat(report.lines,"\n")
    return report
end
function R:BuildShareText(page,preview)
    local report,reason=self:BuildShareReport(page,preview)
    return report and report.text or nil,reason
end
-- Our conservative 255-raw-byte budget includes markup; it is not a claim
-- about a native transport limit. Links are indivisible; only plain text wraps.
-- The plain full report stays available even if transport limits fail.
local function ValidMessage(message,links)
    message=Public(message)
    if type(message)~="string"or #message>255 then return false end
    local offset=1
    while offset<=#message do
        local pipe=message:find("|",offset,true)
        if not pipe then return PlainChat(message:sub(offset))end
        if not PlainChat(message:sub(offset,pipe-1))then return false end
        local matched
        for link in pairs(links or{})do
            if message:sub(pipe,pipe+#link-1)==link then matched=link;break end
        end
        if not matched then return false end
        offset=pipe+#matched
    end
    return true
end
function R:BuildShareMessages(report)
    if type(report)~="table"or type(report.lines)~="table"then return nil,"Report unavailable"end
    local private=reportTokens[report];local lines=private and private.lines or report.lines
    local messages,links={},private and private.links or{}
    local function Push(text)
        if not ValidMessage(text,links)then return false,"Report contains unsupported chat text"end
        messages[#messages+1]=text
        if #messages>256 then return false,"Report exceeds the bounded chat size; select text to copy it"end
        return true
    end
    for _,line in ipairs(lines)do
        local parts=private and line or{line};local chunk=""
        for _,part in ipairs(parts)do
            if type(part)=="table"then
                local link=part.link
                if not links[link]then return nil,"Report contains an unverified spell link"end
                if #chunk+#link>255 then
                    local ok,reason=Push(chunk);if not ok then return nil,reason end;chunk="... "
                end
                chunk=chunk..link
            else
                if not PlainChat(part)then return nil,"Report contains unsupported chat text"end
                local remaining=part
                while #remaining>0 do
                    local cut=math.min(#remaining,255-#chunk)
                    if cut<#remaining then
                        while cut>0 and remaining:byte(cut+1)>=128 and remaining:byte(cut+1)<192 do cut=cut-1 end
                        local space
                        for i=1,cut do if remaining:sub(i,i)==" "then space=i end end
                        if space and space>cut/2 then cut=space end
                    end
                    chunk=chunk..remaining:sub(1,cut);remaining=remaining:sub(cut+1)
                    if #remaining>0 then
                        local ok,reason=Push(chunk);if not ok then return nil,reason end;chunk="... "
                    end
                end
            end
        end
        local ok,reason=Push(chunk);if not ok then return nil,reason end
    end
    return messages
end
function R:ValidWhisperTarget(target)
    target=Public(target)
    return type(target)=="string"and #target>0 and #target<=80 and not target:find("[%s%c|/]")
end
function R:ResolveShareTarget()
    if Read(UnitIsPlayer,"target")~=true then return nil,"Target a player to whisper"end
    local guid=Plain(Read(UnitGUID,"target"))
    if not guid or not guid:match("^Player%-%d+%-%x+$")then return nil,"Target identity unavailable"end
    if type(UnitFullName)~="function"then return nil,"Target name unavailable"end
    local ok,rawName,rawRealm=pcall(UnitFullName,"target")
    if not ok then return nil,"Target name unavailable"end
    local name,namePublic=Public(rawName);local realm,realmPublic=Public(rawRealm)
    if not namePublic or not realmPublic or not self:ValidWhisperTarget(name)then return nil,"Target name unavailable"end
    if realm==nil or realm==""then realm=Read(GetNormalizedRealmName)end
    if not self:ValidWhisperTarget(realm)then return nil,"Target realm unavailable"end
    local full=name.."-"..realm
    if not self:ValidWhisperTarget(full)then return nil,"Target name unavailable"end
    return{name=full,guid=guid}
end
local function ShareAllowed(channel,target)
    if channel~="WHISPER"and channel~="SAY"and channel~="PARTY"and channel~="RAID"and channel~="INSTANCE_CHAT"then return false,"Choose a supported channel"end
    if not OpenAllowed()then return false,"Available after combat"end
    if Read(C_ChatInfo and C_ChatInfo.InChatMessagingLockdown)~=false then return false,"Chat is restricted or its status is unknown"end
    if Read(C_SocialRestrictions and C_SocialRestrictions.CanSendChat)~=true then return false,"Chat permission is unavailable"end
    if channel=="PARTY"or channel=="RAID"then
        local category=Number(LE_PARTY_CATEGORY_HOME)
        if not category or Read(channel=="RAID"and IsInRaid or IsInGroup,category)~=true then return false,channel=="RAID"and"Not in a home raid"or"Not in a home party"end
    elseif channel=="INSTANCE_CHAT"then
        local category=Number(LE_PARTY_CATEGORY_INSTANCE)
        if not category or Read(IsInGroup,category)~=true then return false,"Not in an instance group"end
    elseif channel=="WHISPER"and not R:ValidWhisperTarget(target)then return false,"Target a player to whisper"end
    if not C_ChatInfo or type(C_ChatInfo.SendChatMessage)~="function"then return false,"Chat submission unavailable; select text to copy"end
    return true
end
function R:GetShareDestination(channel,target)
    target=Public(target)
    local name,guid=target,nil
    if type(target)=="table"then
        name,guid=Public(target.name),Plain(target.guid)
        if channel=="WHISPER"then
            local current,reason=self:ResolveShareTarget()
            if not current then return nil,reason end
            if not self:ValidWhisperTarget(name)or not guid or current.name~=name or current.guid~=guid then return nil,"Target changed; choose Whisper again"end
        end
    end
    local allowed,reason=ShareAllowed(channel,name);if not allowed then return nil,reason end
    return{channel=channel,target=channel=="WHISPER"and name or nil,targetGUID=channel=="WHISPER"and guid or nil,
        label=channel=="WHISPER"and name or channel=="INSTANCE_CHAT"and"Instance"or channel:sub(1,1)..channel:sub(2):lower(),manual=channel=="SAY"}
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
    if not ValidMessage(message,job.links)then StopShare(job,"stopped","Unsupported chat text");return end
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
    local destination,reason=self:GetShareDestination(channel,target);if not destination then return false,reason end
    local messages;messages,reason=self:BuildShareMessages(report);if not messages or #messages==0 then return false,reason or"Report is empty"end
    if channel~="SAY"and(not C_Timer or type(C_Timer.NewTimer)~="function")then return false,"Chat queue unavailable; select text to copy"end
    local now=Number(Read(GetTime));if not now or Read(current)~=true then return false,"This report is no longer open"end
    shareGeneration=shareGeneration+1
    shareJob={report=report,messages=messages,links=reportTokens[report]and reportTokens[report].links or{},channel=destination.channel,target=destination.target,targetGUID=destination.targetGUID,current=current,changed=changed,
        started=now,deadline=now+(channel=="SAY"and 600 or math.max(30,#messages+15)),submitted=0,status="posting"}
    ShareSubscriptions(true);NotifyShare(shareJob);DispatchShare(shareJob,shareGeneration)
    return true
end
function R:SendNextShare(report)
    if not shareJob or shareJob.report~=report or shareJob.status~="posting"or shareJob.channel~="SAY"then return false end
    DispatchShare(shareJob,shareGeneration);return true
end
for _,event in ipairs({"PLAYER_REGEN_DISABLED","ENCOUNTER_START","PLAYER_LEAVING_WORLD","PLAYER_ENTERING_WORLD","PLAYER_LOGOUT","GROUP_ROSTER_UPDATE"})do
    shareEvents[#shareEvents+1]=RA:RegisterOptionalEvent(event,function()
        if event~="GROUP_ROSTER_UPDATE"or(shareJob and(shareJob.channel=="PARTY"or shareJob.channel=="RAID"or shareJob.channel=="INSTANCE_CHAT"))then R:CancelShare(event=="GROUP_ROSTER_UPDATE"and"Group changed"or"Context changed")end
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
