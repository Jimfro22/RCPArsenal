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
local function FightTime(value)
    if value==nil then return "Time unknown"end
    local magnitude=math.floor(math.abs(value))
    return string.format("%s%.0f:%02.0f",value<0 and"-"or"",math.floor(magnitude/60),magnitude%60)
end
local function Relative(value)
    if value==nil then return "Time unknown"end
    local magnitude=string.format("%.1f",math.abs(value))
    return(magnitude~="0.0"and(value<0 and"-"or"+")or"")..magnitude.."s"
end
local function Compact(value)
    value=Number(value)
    if not value or value<0 then return nil end
    if value>=1e6 then return string.format("%.1fm",value/1e6)end
    if value>=1000 then return string.format("%.1fk",value/1000)end
    return string.format("%.0f",value)
end
-- Sharing always uses a small native-hit summary, independent of the open tab.
-- Local healing is a separate bounded receipt-window total; it is never paired
-- with native hits or used to assign them a fight-clock timestamp.
function R:BuildShareReport(page,preview,feedMode)
    if type(page)~="table"or(preview~=true and not self:IsRetainedPage(page))then return nil,"No recorded personal recap"end
    preview=preview==true
    local report={preview=preview,feedMode="named",lines={},entries={},sections={}}
    local tokens={lines={},links={}};reportTokens[report]=tokens
    local Name=ShareNames()
    local function Line(text,parts)
        report.lines[#report.lines+1]=text;tokens.lines[#tokens.lines+1]=parts or{text}
    end
    local died,started=Number(page.diedAt),page.encounter and Number(page.encounter.startedAt)
    local fight=died and started and died>=started and died-started or nil
    local player=Plain(page.playerName)
    local encounter=page.encounter and Plain(page.encounter.name)
    Line((preview and"RCP Preview — sample"or"RCP Death Log")..(player and" · "..player or"")..(encounter and" · "..encounter or"")..(fight and" · Fight "..FightTime(fight)or""))
    local selected={}
    local rows=page.native and page.native.rows or{}
    for i=1,math.min(#rows,64)do
        local row=Public(rows[i])
        if type(row)=="table"then
            local offset,amount=Number(row.nativeOffset),Number(row.amount)
            if Public(row.kind)=="damage"and offset and offset>=-6 and offset<=0 and amount and amount>=0 and amount<=1e15 then
                selected[#selected+1]={row=row,time=offset,index=Number(row.nativeIndex)or i,fatal=Number(row.nativeIndex)==1,amount=amount}
            end
        end
    end
    table.sort(selected,function(a,b)if a.time~=b.time then return a.time<b.time end;return a.index>b.index end)
    while #selected>6 do table.remove(selected,1)end
    local summary={hits=#selected,damage=0,absorbed=0,overkill=0}
    report.summary=summary
    for _,event in ipairs(selected)do
        summary.damage=summary.damage+event.amount
        summary.absorbed=summary.absorbed+math.max(0,Number(event.row.absorbed)or 0)
        summary.overkill=summary.overkill+math.max(0,Number(event.row.overkill)or 0)
    end
    if #selected>0 then
        summary.span=selected[#selected].time-selected[1].time
        local text=string.format("%d hit%s / %.1fs: %s damage",#selected,#selected==1 and""or"s",summary.span,Compact(summary.damage))
        if summary.absorbed>0 then text=text.." · "..Compact(summary.absorbed).." absorbed"end
        if summary.overkill>0 then text=text.." · "..Compact(summary.overkill).." overkill"end
        Line(text)
    else Line("No named hits recorded in the final 6s.")end
    local healing,healSpan
    if preview then
        for _,row in ipairs(page.heals or{})do
            local offset,amount=Number(row.offset),Number(row.amount)
            if offset and offset>=-6 and offset<=0 and amount and amount>=0 then healing=(healing or 0)+amount end
        end
        if healing then healSpan=6 end
    elseif RA.DeathLogModel then
        local incoming=RA.DeathLogModel:Incoming(page)
        if incoming.available then
            healing,healSpan=0,math.min(6,died-page.liveIncoming.startedAt)
            for _,row in ipairs(incoming.rows)do
                if row.kind=="healing"and row.offset>=-6 then healing=healing+row.amount end
            end
        end
    end
    if healing then
        summary.healing,summary.healingSpan=healing,healSpan
        Line(string.format("Healing / last %.1fs: %s",healSpan,Compact(healing)))
    end
    if type(self.GetCooldownRows)=="function"then
        local available={}
        for _,row in ipairs(self:GetCooldownRows(page,preview))do
            if Public(row.recordedState)==true then
                available[#available+1]=row.kind=="stone"and"Healthstone"or row.kind=="potion"and"Healing potion"or Name(row)
            end
        end
        if #available>0 then Line("Available: "..table.concat(available,", "))end
        report.available=available
    end
    for _,event in ipairs(selected)do
        local name,link=Name(event.row)
        local suffix=": "..Compact(event.amount)..(event.fatal and" · Killing blow"or"")
        local prefix="- "..Relative(event.time).." "
        event.kind,event.clock,event.text="damage","native",name..suffix
        event.line=prefix..event.text
        report.entries[#report.entries+1]=event
        if link then tokens.links[link]=true end
        Line(event.line,link and{prefix,{link=link},suffix}or nil)
    end
    report.sections[1]={title="Named hits",clock="native",events=report.entries}
    report.text=table.concat(report.lines,"\n")
    return report
end
function R:BuildShareText(page,preview,feedMode)
    local report,reason=self:BuildShareReport(page,preview,feedMode)
    return report and report.text or nil,reason
end
-- Our conservative 255-raw-byte budget includes markup; it is not a claim
-- about a native transport limit. Links are indivisible; only plain text wraps.
-- The plain compact report stays available even if transport limits fail.
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
local journalMappings=setmetatable({},{__mode="k"})
local function JournalContext(self,page,row)
    page,row=Public(page),Public(row)
    if type(page)~="table"or type(row)~="table"or not self:IsRetainedPage(page)then return end
    local encounter=Public(page.encounter);local native=Public(page.native)
    local rows=type(native)=="table"and Public(native.rows)
    if type(encounter)~="table"or type(rows)~="table"then return end
    local retained=false;for i=1,math.min(#rows,64)do if rows[i]==row then retained=true;break end end
    local boss,difficulty,spell=SpellID(encounter.encounterID),SpellID(encounter.difficulty),SpellID(row.spellID)
    if retained and boss and difficulty and spell then return boss,difficulty,spell end
end
function R:GetJournalMapping(page,row)
    local boss,difficulty,spell=JournalContext(self,page,row);if not boss then return end
    local cached=journalMappings[page]and journalMappings[page][spell]
    if cached then return cached end
    for _,map in ipairs((RA.DeathRecapCatalog or {}).journal or {})do
        if map.verified==true and map.encounterID==boss and map.difficulty==difficulty and map.spellID==spell then return map end
    end
end
local function JournalEncounter(fn,...)
    if type(fn)~="function"then return end
    local ok,_,_,boss,root,_,instance,combatID=pcall(fn,...)
    if ok then
        boss,root,instance,combatID=SpellID(boss),SpellID(root),SpellID(instance),SpellID(combatID)
        if boss and root and instance and combatID then return {journalEncounterID=boss,root=root,instanceID=instance,encounterID=combatID}end
    end
end
-- On-click only. Native encounter IDs and the difficulty-filtered section tree
-- establish the relationship; no global name search or guessed spell-ID table.
local function ResolveJournal(page,row,boss,difficulty)
    local journal=Public(EncounterJournal)
    local priorTier,priorDifficulty=SpellID(Read(EJ_GetCurrentTier)),SpellID(Read(EJ_GetDifficulty))
    if not priorTier or not priorDifficulty then return nil,"Dungeon Journal is unavailable"end
    local priorInstance=type(journal)=="table"and SpellID(journal.instanceID)
    local priorEncounter=type(journal)=="table"and SpellID(journal.encounterID)
    local function Restore()
        pcall(EJ_SelectTier,priorTier)
        if priorInstance then pcall(EJ_SelectInstance,priorInstance)end
        pcall(EJ_SetDifficulty,priorDifficulty)
        if priorEncounter then pcall(EJ_SelectEncounter,priorEncounter)end
    end
    local ok,map,reason=pcall(function()
        local found,calls,visited=nil,0,{}
        local function Inspect(instance,tier)
            if visited[instance]then return end;visited[instance]=true
            EJ_SelectInstance(instance)
            for index=1,64 do
                calls=calls+1;if calls>4096 then error("lookup limit")end
                local ok,_,_,journalID=pcall(EJ_GetEncounterInfoByIndex,index,instance)
                journalID=ok and SpellID(journalID)
                if not journalID then break end
                local entry=JournalEncounter(EJ_GetEncounterInfo,journalID)
                if entry and entry.instanceID==instance and entry.encounterID==boss then entry.tierIndex=tier;found=entry;return end
            end
        end
        local cached=R:GetJournalMapping(page,row)
        if cached then
            local entry=JournalEncounter(EJ_GetEncounterInfo,cached.journalEncounterID)
            if entry and entry.encounterID==boss and entry.instanceID==cached.instanceID then entry.tierIndex=cached.tierIndex;found=entry end
        end
        -- A captured game-map ID avoids enumerating other instances on new
        -- deaths. Older retained pages can still resolve through native tiers.
        local gameMap=SpellID(page.encounter.gameMapID)
        local instance=gameMap and SpellID(Read(C_EncounterJournal and C_EncounterJournal.GetInstanceForGameMap,gameMap))
        if not found and instance then Inspect(instance)end
        if not found then
            local tiers=SpellID(Read(EJ_GetNumTiers));if not tiers or tiers>32 then return nil,"Dungeon Journal is unavailable"end
            local order={priorTier};for tier=tiers,1,-1 do if tier~=priorTier then order[#order+1]=tier end end
            for _,tier in ipairs(order)do
                EJ_SelectTier(tier)
                for _,raid in ipairs({true,false})do
                    for index=1,128 do
                        local candidate=SpellID(Read(EJ_GetInstanceByIndex,index,raid));if not candidate then break end
                        Inspect(candidate,tier);if found then break end
                    end
                    if found then break end
                end
                if found then break end
            end
        end
        if not found then return nil,"Boss not found in the Dungeon Journal"end
        if found.tierIndex then EJ_SelectTier(found.tierIndex)end
        EJ_SelectInstance(found.instanceID);EJ_SetDifficulty(difficulty);EJ_SelectEncounter(found.journalEncounterID)
        if Read(EJ_GetDifficulty)~=difficulty then return nil,"This Journal difficulty is unavailable"end
        local verified=JournalEncounter(EJ_GetEncounterInfo,found.journalEncounterID)
        if not verified or verified.encounterID~=boss or verified.instanceID~=found.instanceID or verified.root~=found.root then return nil,"Boss Journal entry is unavailable"end
        local spell=SpellID(row.spellID);local name=Plain(row.rawSpellName)or Plain(row.name)or Plain(Read(C_Spell and C_Spell.GetSpellName,spell))
        local queue,seen,index,exact,named={found.root},{},1,nil,{}
        while index<=#queue do
            if index>512 then return nil,"Boss Journal entry is too large to search"end
            local id=queue[index];index=index+1
            if not seen[id]then
                seen[id]=true;local info=Read(C_EncounterJournal.GetSectionInfo,id)
                if type(info)~="table"or getmetatable(info)~=nil then return nil,"Boss Journal entry is unavailable"end
                local sibling,child=SpellID(info.siblingSectionID),SpellID(info.firstChildSectionID)
                if sibling then queue[#queue+1]=sibling end
                if Public(info.filteredByDifficulty)==false then
                    local sectionSpell,title=SpellID(info.spellID),Plain(info.title)
                    if sectionSpell==spell then exact=exact or id end
                    if sectionSpell and name and title==name then named[#named+1]=id end
                    if child then queue[#queue+1]=child end
                end
            end
        end
        -- Damage ticks can use a different spell ID from their parent ability.
        -- A unique, exact native section title within this verified boss is a
        -- fallback; repeated titles and fuzzy matches never select a section.
        local section=exact or(#named==1 and named[1])
        if not section then return nil,"Ability not listed separately in this boss's Journal"end
        found.sectionID,found.spellID,found.difficulty=section,spell,difficulty
        found.verified,found.match=true,exact and"spellID"or"exact-section-title"
        return found
    end)
    Restore()
    if not ok then return nil,"Dungeon Journal lookup is unavailable"end
    return map,reason
end
function R:OpenJournal(page,row)
    local boss,difficulty=JournalContext(self,page,row)
    if not boss then return false,"This hit has no recorded boss encounter"end
    if not OpenAllowed()then return false,"Available after combat"end
    if type(EncounterJournal_LoadUI)=="function"then local ok=pcall(EncounterJournal_LoadUI);if not ok then return false,"Dungeon Journal is unavailable"end end
    if not OpenAllowed()then return false,"Available after combat"end
    for _,fn in ipairs({"EJ_GetEncounterInfo","EJ_GetEncounterInfoByIndex","EJ_SelectTier","EJ_SelectInstance","EJ_SetDifficulty","EJ_SelectEncounter","EncounterJournal_OpenJournal"})do
        if type(_G[fn])~="function"then return false,"Dungeon Journal is unavailable"end
    end
    if not C_EncounterJournal or type(C_EncounterJournal.GetSectionInfo)~="function"then return false,"Dungeon Journal is unavailable"end
    local map,reason=ResolveJournal(page,row,boss,difficulty)
    if not map then return false,reason end
    if not self:IsRetainedPage(page)or not OpenAllowed()then return false,"Available after combat"end
    local ok=pcall(function()
        if map.tierIndex then EJ_SelectTier(map.tierIndex)end
        EncounterJournal_OpenJournal(map.difficulty,map.instanceID,map.journalEncounterID,map.sectionID,nil,nil,map.tierIndex)
    end)
    if ok then journalMappings[page]=journalMappings[page]or{};journalMappings[page][map.spellID]=map end
    return ok,ok and"Journal opened"or"Journal entry unavailable"
end
