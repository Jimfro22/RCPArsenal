local _, RA = ...
local Groups = {}
RA.RaidGroups = Groups

-- Ordinary local planning. Only Apply(previewID) may create a subgroup job.
-- No queries, saved-variable writes, frames or timers at module construction.
local opened, live, liveError, draft, preview, job, uncertain = false
local serial, entrySerial, previewSerial = 0, 0, 0
local priorRequestMaySettle = false
local TIMEOUT, MAX_LAYOUTS, MAX_ENTRIES = 3, 50, 80
local MAX_PASTE, MAX_LINE, MAX_SECTIONS = 65536, 16384, 32
local applyState = {status="idle", confirmed=0, total=0, inFlight=false, unknownResult=false}
local Observe, SyncSubscriptions, IssueNext

local function Secret(value)
    if type(issecretvalue) ~= "function" then return true end
    local ok, result = pcall(issecretvalue, value)
    return not ok or result ~= false
end
local function Text(value, maximum)
    if Secret(value) or type(value) ~= "string" or #value > maximum or value:find("[%c|]") then return nil end
    return value
end
local function Integer(value, low, high)
    return not Secret(value) and type(value)=="number" and value==value and value>=low and value<=high and value==math.floor(value)
end
local function Copy(value)
    if type(value) ~= "table" then return value end
    local out={}; for key,item in pairs(value) do out[key]=Copy(item) end; return out
end
local function Boolean(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, value=pcall(func,...)
    if not ok or Secret(value) or type(value)~="boolean" then return nil end
    return value
end
local function Identity(value)
    value=Text(value,160)
    if not value or value=="" or value:find("[,;:]") then return nil end
    local name,realm=value:match("^([^%-]+)%-(.+)$")
    if not name or name:find("%s") then return nil end
    realm=realm:gsub("%s","")
    if realm=="" then return nil end
    local full=name.."-"..realm
    return {name=name,realm=realm,fullName=full,key=full:lower()}
end
local function Label(value)
    value=Text(value,80)
    if not value then return nil end
    value=value:match("^%s*(.-)%s*$")
    return value~="" and value or nil
end
local function Emit() RA:FireCallback("RAID_GROUPS_CHANGED") end
local function EmptySlots()
    local slots={}; for g=1,8 do slots[g]={false,false,false,false,false} end; return slots
end
local function Fingerprint(members, assignments)
    local parts={}
    for _,member in ipairs(members) do
        parts[#parts+1]=member.guid..":"..member.key..":"..(assignments and assignments[member.guid] or member.group)
    end
    table.sort(parts); return table.concat(parts,";")
end
local function OtherBusy()
    local toolbox=RA.RaidLeaderToolbox
    if Secret(toolbox) or type(toolbox)~="table" or type(toolbox.IsSorting)~="function" or type(toolbox.IsGroupOperationPending)~="function" then
        return true,"Raid group operation safety integration is unavailable."
    end
    local active=Boolean(toolbox.IsSorting,toolbox)
    local pending=Boolean(toolbox.IsGroupOperationPending,toolbox)
    if active==nil or pending==nil then return true,"Raid group operation state is unavailable." end
    return active or pending,"Quick Bar has an active or pending group operation."
end
local function Eligibility(snapshot)
    if Boolean(InCombatLockdown)~=false then return false,"Apply is unavailable in combat or unknown combat state." end
    if Secret(RA.InEncounter) or RA.InEncounter==true or Boolean(IsEncounterInProgress)~=false then return false,"Apply is unavailable during an encounter or unknown encounter state." end
    if not Integer(LE_PARTY_CATEGORY_HOME,1,10) or not Integer(LE_PARTY_CATEGORY_INSTANCE,1,10)
        or Boolean(IsInRaid,LE_PARTY_CATEGORY_HOME)~=true or Boolean(IsInGroup,LE_PARTY_CATEGORY_INSTANCE)~=false then
        return false,"Apply requires a player-organized raid."
    end
    local leader,assistant=Boolean(UnitIsGroupLeader,"player"),Boolean(UnitIsGroupAssistant,"player")
    if leader==nil or assistant==nil then return false,"Raid authority is unavailable." end
    if not leader and not assistant then return false,"Raid leader or assistant is required." end
    for _,member in ipairs(snapshot.members) do
        if not member.combatKnown or member.inCombat then return false,"Every raid member must have known out-of-combat state." end
    end
    local busy,reason=OtherBusy(); if busy then return false,reason end
    return true
end
local function Capture()
    local inRaid=Boolean(IsInRaid)
    if inRaid==false then return nil,"Not in a raid. Join a raid to capture groups." end
    if inRaid~=true then return nil,"Raid membership is unavailable." end
    if type(GetNumGroupMembers)~="function" or type(GetRaidRosterInfo)~="function" or type(UnitGUID)~="function" or type(UnitFullName)~="function" then return nil,"Roster APIs are unavailable." end
    local ok,count=pcall(GetNumGroupMembers)
    if not ok or not Integer(count,1,40) then return nil,"Raid member count is unavailable." end
    local snapshot={members={},byGuid={},byKey={},counts={0,0,0,0,0,0,0,0}}
    for index=1,count do
        local unit="raid"..index
        local info,rosterName,_,group,_,_,class,_,online=pcall(GetRaidRosterInfo,index)
        local gu,guid=pcall(UnitGUID,unit)
        local full,name,realm=pcall(UnitFullName,unit)
        if not info or not gu or not full or not Text(rosterName,160) or not Text(guid,80)
            or not guid:match("^Player%-%d+%-%x+$") or not Text(name,80) or Secret(realm)
            or not Integer(group,1,8) or Secret(online) or type(online)~="boolean" then return nil,"Raid identity, group or presence data is unavailable." end
        if realm==nil or realm=="" then
            if type(GetNormalizedRealmName)~="function" then return nil,"Realm identity is unavailable." end
            local success,value=pcall(GetNormalizedRealmName); if not success or not Text(value,80) then return nil,"Realm identity is unavailable." end
            realm=value
        end
        if not Text(realm,80) then return nil,"Realm identity is unavailable." end
        local identity=Identity(name.."-"..realm)
        local rosterIdentity=Identity(rosterName)
        if not identity or (rosterIdentity and rosterIdentity.key~=identity.key)
            or (not rosterIdentity and rosterName:lower()~=identity.name:lower()) then return nil,"Raid identity changed during capture." end
        if snapshot.byGuid[guid] or snapshot.byKey[identity.key] then return nil,"Duplicate or ambiguous raid identity." end
        local combat=Boolean(UnitAffectingCombat,unit)
        local member={guid=guid,name=identity.name,realm=identity.realm,fullName=identity.fullName,key=identity.key,
            group=group,index=index,online=online,class=Text(class,32),combatKnown=combat~=nil,inCombat=combat==true}
        snapshot.members[#snapshot.members+1]=member; snapshot.byGuid[guid]=member; snapshot.byKey[member.key]=member
        snapshot.counts[group]=snapshot.counts[group]+1
        if snapshot.counts[group]>5 then return nil,"Live subgroup capacity is inconsistent." end
    end
    local same,newCount=pcall(GetNumGroupMembers)
    if not same or not Integer(newCount,1,40) or newCount~=count then return nil,"Raid membership changed during capture." end
    for _,member in ipairs(snapshot.members) do
        local sameGuid,value=pcall(UnitGUID,"raid"..member.index)
        if not sameGuid or Secret(value) or value~=member.guid then return nil,"Raid indices changed during capture." end
    end
    snapshot.fingerprint=Fingerprint(snapshot.members)
    snapshot.canApply,snapshot.reason=Eligibility(snapshot)
    return snapshot
end
local function Record(snapshot,reason)
    liveError=reason
    if snapshot then
        live=snapshot
        if uncertain then
            local first=snapshot.byGuid[uncertain.guid]
            local second=uncertain.otherGuid and snapshot.byGuid[uncertain.otherGuid]
            local firstSettled=not first or first.group==uncertain.targetGroup
            local secondSettled=not uncertain.otherGuid or not second or second.group==uncertain.otherTargetGroup
            if firstSettled and secondSettled then
                uncertain=nil;applyState.inFlight=false;applyState.unknownResult=false
                applyState.settled=true
                applyState.reason=(applyState.stopReason or "Apply stopped.").." Submitted result observed; prepare a fresh review to continue."
            end
        end
        if draft and draft.basis~=snapshot.fingerprint then draft.stale=true end
        if preview and (preview.fingerprint~=snapshot.fingerprint or preview.canApply~=snapshot.canApply or preview.reason~=snapshot.reason) then preview=nil end
    else
        if reason=="Not in a raid. Join a raid to capture groups." then live=nil end
        if draft then draft.stale=true end
        preview=nil
    end
end
local function NewDraft(boss)
    serial=serial+1
    return {revision=serial,entries={},groups=EmptySlots(),tray={},basis=live and live.fingerprint,stale=false,boss=Copy(boss or {})}
end
local function Entry(model,fullName,guid)
    local identity=Identity(fullName)
    entrySerial=entrySerial+1
    local row={id="entry:"..entrySerial,fullName=identity and identity.fullName or fullName,
        name=identity and identity.name or fullName,realm=identity and identity.realm,key=identity and identity.key,guid=guid}
    model.entries[row.id]=row; return row
end
local function FirstFree(model,group)
    for slot=1,5 do if model.groups[group][slot]==false then return slot end end
end
local function AddLive(model)
    if not live then return end
    local present={}; for _,entry in pairs(model.entries) do if entry.guid then present[entry.guid]=true end end
    for _,member in ipairs(live.members) do if not present[member.guid] then
        local entry=Entry(model,member.fullName,member.guid)
        local slot=FirstFree(model,member.group)
        if slot then model.groups[member.group][slot]=entry.id else model.tray[#model.tray+1]=entry.id end
    end end
end
local function Locate(model,id)
    for group=1,8 do for slot=1,5 do if model.groups[group][slot]==id then return group,slot end end end
    for index,value in ipairs(model.tray) do if value==id then return nil,index end end
end
local function Remove(model,id)
    local group,slot=Locate(model,id)
    if group then model.groups[group][slot]=false elseif slot then table.remove(model.tray,slot) end
    model.entries[id]=nil
end
local function View()
    if not draft then return nil end
    local view={groups=Copy(draft.groups),tray=Copy(draft.tray),entries={}}
    local represented={}
    for id,row in pairs(draft.entries) do
        local member=live and row.guid and live.byGuid[row.guid]
        if member and member.key~=row.key then member=nil end
        local entry=Copy(row);entry.missing=member==nil;entry.unresolved=row.key==nil
        entry.guid=member and member.guid or nil;entry.liveGroup=member and member.group or nil
        if member then entry.class=member.class;entry.online=member.online;entry.offline=not member.online end
        view.entries[id]=entry;if member then represented[member.guid]=true end
    end
    if live then for _,member in ipairs(live.members) do if not represented[member.guid] then
        local id="live:"..member.guid
        view.entries[id]={id=id,name=member.name,realm=member.realm,fullName=member.fullName,key=member.key,
            guid=member.guid,liveGroup=member.group,class=member.class,online=member.online,offline=not member.online,missing=false,unresolved=false}
        view.tray[#view.tray+1]=id
    end end end
    return view
end
local function Edited()
    serial=serial+1;draft.revision=serial;preview=nil;Emit()
end
local function Editable()
    if job then return false,"Stop Apply before editing a layout." end
    if not draft then return false,"Start from the raid, load a layout or import a note first." end
    return true
end

-- Also fences competing jobs while a cancelled/timed-out submission may settle.
function Groups:IsApplying() return job~=nil or uncertain~=nil end
function Groups:GetState()
    local layouts,storageError=self:ListLayouts()
    local reviewed=job and Copy(job.review) or Copy(preview)
    if reviewed and job then reviewed.status="applying" end
    local progress=Copy(applyState)
    progress.priorRequestMaySettle=priorRequestMaySettle
    progress.canRecover=uncertain~=nil and live~=nil and liveError==nil and live.canApply==true
    progress.recoveryFingerprint=uncertain and live and live.fingerprint or nil
    return {open=opened,live=Copy(live),liveError=liveError,draft=Copy(draft),view=View(),preview=reviewed,
        apply=progress,layouts=layouts,storageError=storageError}
end
function Groups:RefreshRoster()
    if job then return Observe() end
    local snapshot,reason=Capture();Record(snapshot,reason);Emit();return snapshot~=nil,reason
end
function Groups:Open()
    opened=true;SyncSubscriptions();return self:RefreshRoster()
end
function Groups:Close()
    opened=false
    if job then self:CancelApply("Planner closed; no further moves will be submitted.") end
    SyncSubscriptions();Emit();return true
end
function Groups:SetVisible(visible)
    if Secret(visible) or type(visible)~="boolean" then return false,"Invalid visibility." end
    if visible==opened then return true end
    if visible then return self:Open() else return self:Close() end
end
function Groups:FromCurrentRaid()
    if job then return false,"Stop Apply before replacing the draft." end
    local snapshot,reason=Capture();Record(snapshot,reason)
    if not snapshot then Emit();return false,reason end
    draft=NewDraft();AddLive(draft);preview=nil;Emit();return true
end
function Groups:Move(id,group,slot)
    local ok,reason=Editable();if not ok then return false,reason end
    if not Text(id,160) then return false,"Invalid card identity." end
    if Secret(group) or Secret(slot) then return false,"Group slot data is unavailable." end
    if group~=nil or slot~=nil then
        if not Integer(group,1,8) or not Integer(slot,1,5) then return false,"Choose a group slot." end
    end
    local view=View();local entry=view.entries[id]
    if not entry then return false,"Card is unavailable." end
    if not draft.entries[id] then
        local count=0;for _ in pairs(draft.entries) do count=count+1 end
        if count>=MAX_ENTRIES then return false,"Remove absent planned cards before adding more current raiders." end
        local added=Entry(draft,entry.fullName,entry.guid);draft.tray[#draft.tray+1]=added.id;id=added.id
    end
    local oldGroup,oldSlot=Locate(draft,id)
    if oldGroup==group and oldSlot==slot then return true end
    if group==nil then
        if oldGroup then draft.groups[oldGroup][oldSlot]=false;draft.tray[#draft.tray+1]=id end
    else
        local displaced=draft.groups[group][slot]
        draft.groups[group][slot]=id
        if oldGroup then draft.groups[oldGroup][oldSlot]=displaced
        elseif oldSlot then
            if displaced then draft.tray[oldSlot]=displaced else table.remove(draft.tray,oldSlot) end
        end
    end
    Edited();return true
end
function Groups:ResolveEntry(id,guid)
    local ok,reason=Editable();if not ok then return false,reason end
    if not Text(id,160) or not Text(guid,80) then return false,"Invalid identity mapping." end
    local row=draft.entries[id];local member=live and live.byGuid[guid]
    if not row or not member then return false,"Choose an imported card and a current raid member." end
    for other,entry in pairs(draft.entries) do if other~=id and entry.guid==guid then Remove(draft,other);break end end
    row.name,row.realm,row.fullName,row.key,row.guid=member.name,member.realm,member.fullName,member.key,member.guid
    Edited();return true
end
function Groups:RemoveEntry(id)
    local ok,reason=Editable();if not ok then return false,reason end
    if not Text(id,160) or not draft.entries[id] then return false,"Card is unavailable." end
    local view=View()
    if not view.entries[id].missing then return false,"Current raiders must remain visible; move the card to the tray instead." end
    Remove(draft,id);Edited();return true
end
function Groups:Reconcile()
    local ok,reason=Editable();if not ok then return false,reason end
    local snapshot;snapshot,reason=Capture();Record(snapshot,reason)
    if not snapshot then Emit();return false,reason end
    local model,assigned=Copy(draft),{}
    for id,row in pairs(model.entries) do
        local member=row.guid and snapshot.byGuid[row.guid]
        if member and member.key==row.key then assigned[member.guid]=id end
    end
    local matched=0
    for id,row in pairs(model.entries) do
        local member=row.key and snapshot.byKey[row.key]
        if member and row.guid~=member.guid then
            if assigned[member.guid] and assigned[member.guid]~=id then
                Emit();return false,"A joined raider already has another draft card; choose an explicit identity mapping."
            end
            row.guid=member.guid;assigned[member.guid]=id;matched=matched+1
        end
    end
    model.basis=snapshot.fingerprint;model.stale=false;draft=model;Edited()
    return true,"Matched "..matched.." exact full-name identities; group slots and edits were preserved."
end

local function Store(write)
    if Secret(RaidArsenalDB) or type(RaidArsenalDB)~="table" then return nil,"Local saved layouts are unavailable." end
    local store=RaidArsenalDB.raidGroupLayouts
    if Secret(store) then return nil,"Local saved layouts are unavailable." end
    if store==nil then
        if not write then return {version=1,items={}} end
        store={version=1,items={}};RaidArsenalDB.raidGroupLayouts=store
    end
    if Secret(store) or type(store)~="table" or getmetatable(store) or Secret(store.version) or store.version~=1
        or Secret(store.items) or type(store.items)~="table" or getmetatable(store.items) then return nil,"Saved layout storage is invalid or unsupported." end
    local count=0
    for name,value in pairs(store.items) do
        count=count+1
        if count>MAX_LAYOUTS or not Label(name) or Secret(value) or type(value)~="table" or getmetatable(value) then return nil,"Saved layout storage exceeds limits or is invalid." end
    end
    return store
end
local function Array(value,maximum,required)
    if Secret(value) or type(value)~="table" or getmetatable(value) then return nil end
    local count,largest=0,0
    for key in pairs(value) do
        if not Integer(key,1,maximum) then return nil end
        count=count+1;largest=math.max(largest,key)
    end
    if count~=largest or (required and count~=required) then return nil end
    return count
end
function Groups:ListLayouts()
    local store,reason=Store(false);if not store then return {},reason end
    local list={};for name in pairs(store.items) do list[#list+1]={name=name} end
    table.sort(list,function(a,b)return a.name<b.name end);return list
end
function Groups:SaveLayout(name)
    local ok,reason=Editable();if not ok then return false,reason end
    name=Label(name);if not name then return false,"Use a plain layout name of at most 80 bytes." end
    local store;store,reason=Store(false);if not store then return false,reason end
    local count=0;for _ in pairs(store.items) do count=count+1 end
    if not store.items[name] and count>=MAX_LAYOUTS then return false,"At most 50 layouts can be saved." end
    local view=View();local slots,tray,seen={},{},{}
    local function Name(id)
        local identity=Identity(view.entries[id].fullName)
        if not identity or seen[identity.key] then return nil end
        seen[identity.key]=true;return identity.fullName
    end
    for group=1,8 do for slot=1,5 do
        local id=view.groups[group][slot]
        local value=id and Name(id) or false
        if id and not value then return false,"Resolve or remove ambiguous identities before saving." end
        slots[#slots+1]=value
    end end
    for _,id in ipairs(view.tray) do
        local value=Name(id);if not value then return false,"Resolve or remove ambiguous identities before saving." end
        tray[#tray+1]=value
    end
    local entries=0;for _ in pairs(seen) do entries=entries+1 end
    if entries>MAX_ENTRIES then return false,"Layout has too many entries." end
    store,reason=Store(true);if not store then return false,reason end
    store.items[name]={name=name,slots=slots,tray=tray,boss=Copy(draft.boss)}
    Emit();return true
end
function Groups:DeleteLayout(name)
    if job then return false,"Stop Apply before deleting a saved layout." end
    name=Label(name);if not name then return false,"Invalid layout name." end
    local store,reason=Store(false);if not store then return false,reason end
    if not store.items[name] then return false,"Layout not found." end
    store.items[name]=nil;Emit();return true
end
local function BoundEntry(model,value)
    local identity=Identity(value)
    local member=identity and live and live.byKey[identity.key]
    return Entry(model,value,member and member.guid)
end
function Groups:LoadLayout(name)
    if job then return false,"Stop Apply before loading a layout." end
    name=Label(name);if not name then return false,"Invalid layout name." end
    local store,reason=Store(false);if not store then return false,reason end
    local saved=store.items[name]
    if not saved then return false,"Layout not found." end
    local count=Array(saved.tray,MAX_ENTRIES)
    if not Array(saved.slots,40,40) or not count then return false,"Saved layout slots are invalid." end
    local boss={label=name}
    if Secret(saved.boss) then return false,"Saved boss data is unavailable." end
    if saved.boss~=nil then
        if type(saved.boss)~="table" or getmetatable(saved.boss) then return false,"Saved boss data is invalid." end
        if Secret(saved.boss.label) or Secret(saved.boss.encounterID) or Secret(saved.boss.difficulty) then return false,"Saved boss data is unavailable." end
        if saved.boss.label~=nil then boss.label=Label(saved.boss.label);if not boss.label then return false,"Saved boss label is invalid." end end
        if saved.boss.encounterID~=nil then if not Integer(saved.boss.encounterID,1,1000000000) then return false,"Saved encounter identifier is invalid." end;boss.encounterID=saved.boss.encounterID end
        if saved.boss.difficulty~=nil then boss.difficulty=Label(saved.boss.difficulty);if not boss.difficulty then return false,"Saved difficulty is invalid." end end
    end
    local model=NewDraft(boss);local seen={}
    local function Add(value)
        local identity=Identity(value)
        if not identity or seen[identity.key] then return nil end
        seen[identity.key]=true;return BoundEntry(model,identity.fullName)
    end
    for index=1,40 do
        local value=saved.slots[index]
        if Secret(value) then return false,"Saved layout identity is unavailable." end
        if value~=false then
            local entry=Add(value);if not entry then return false,"Saved layout contains invalid or duplicate identities." end
            model.groups[math.floor((index-1)/5)+1][(index-1)%5+1]=entry.id
        end
    end
    for _,value in ipairs(saved.tray) do
        local entry=Add(value);if not entry then return false,"Saved layout contains invalid or duplicate identities." end
        model.tray[#model.tray+1]=entry.id
    end
    AddLive(model)
    local entries=0;for _ in pairs(model.entries) do entries=entries+1 end
    if entries>MAX_ENTRIES then return false,"Layout and current raid exceed the entry limit." end
    draft=model;preview=nil;Emit();return true
end

function Groups:ParseNote(text)
    if Secret(text) or type(text)~="string" or #text>MAX_PASTE or text:find("%z") then return nil,"Paste plain notes up to 64 KiB." end
    local sections,current,headers={},nil,{}
    for raw in (text:gsub("\r\n","\n"):gsub("\r","\n").."\n"):gmatch("(.-)\n") do
        if #raw>MAX_LINE then return nil,"A note line is too long." end
        local line=raw:match("^%s*(.-)%s*$")
        if line:match("^EncounterID:") then
            local encounter,difficulty,name=line:match("^EncounterID:(%d+);Difficulty:([^;]+);Name:(.+)$")
            local number=encounter and tonumber(encounter)
            difficulty,name=Label(difficulty),Label(name)
            if not Integer(number,1,1000000000) or not difficulty or not name then return nil,"Invalid encounter header." end
            local key=number..":"..difficulty:lower()
            if headers[key] then return nil,"Duplicate boss/difficulty sections require a separate paste." end
            headers[key]=true;current={label=name,difficulty=difficulty,encounterID=number,slots={},hasInvite=false}
            sections[#sections+1]=current
            if #sections>MAX_SECTIONS then return nil,"Too many boss sections." end
        elseif line:match("^invitelist:") then
            if not current then current={label="Imported layout",slots={},hasInvite=false};sections[#sections+1]=current end
            if current.hasInvite then return nil,"A boss section contains multiple invite lists." end
            local body=line:sub(12)
            if body:sub(-1)==";" then body=body:sub(1,-2) end
            if body:find(";",1,true) then return nil,"Only comma-positioned invite lists are supported." end
            local seen={}
            for token in (body..","):gmatch("(.-),") do
                token=token:match("^%s*(.-)%s*$")
                if #current.slots>=40 then return nil,"An invite list exceeds 40 positional slots." end
                if token=="" then current.slots[#current.slots+1]=false
                else
                    if not Text(token,160) or token:find("[%s;:]") then return nil,"Invalid invite-list identity." end
                    local identity=Identity(token)
                    local key=identity and identity.key or token:lower()
                    if seen[key] then return nil,"Duplicate invite-list identity." end
                    seen[key]=true;current.slots[#current.slots+1]=identity and identity.fullName or token
                end
            end
            current.hasInvite=true
        end
    end
    local found=false;for _,section in ipairs(sections) do if section.hasInvite then found=true end end
    if not found then return nil,"No invite list was exported; the draft is unchanged." end
    return sections
end
function Groups:ImportNote(text,sectionIndex)
    if job then return false,"Stop Apply before importing." end
    local sections,reason=self:ParseNote(text);if not sections then return false,reason end
    if not Integer(sectionIndex,1,#sections) or not sections[sectionIndex].hasInvite then return false,"Choose a section with an exported invite list." end
    local section=sections[sectionIndex]
    local model=NewDraft({label=section.label,encounterID=section.encounterID,difficulty=section.difficulty})
    for index,value in ipairs(section.slots) do if value~=false then
        local entry=BoundEntry(model,value)
        model.groups[math.floor((index-1)/5)+1][(index-1)%5+1]=entry.id
    end end
    AddLive(model);draft=model;preview=nil;Emit();return true
end

local function Targets(snapshot,view)
    local targets,missing,used={},{},{}
    for group=1,8 do for slot=1,5 do
        local id=view.groups[group][slot]
        if id then
            if used[id] or not view.entries[id] then return nil,"Duplicate or invalid draft card." end
            used[id]=true
            local entry=view.entries[id]
            if entry.unresolved then return nil,"Resolve or remove incomplete imported identities before Apply." end
            if entry.guid then
                if targets[entry.guid] then return nil,"A current raider has multiple targets." end
                targets[entry.guid]=group
            else missing[#missing+1]=entry.fullName end
        end
    end end
    for _,id in ipairs(view.tray) do
        local entry=view.entries[id]
        if not entry or used[id] then return nil,"Duplicate or invalid tray card." end
        used[id]=true
        if entry.guid then return nil,"Every current raider needs a group target; the tray is not a bench action." end
        if entry.unresolved then return nil,"Resolve or remove incomplete imported identities before Apply." end
        missing[#missing+1]=entry.fullName
    end
    for _,member in ipairs(snapshot.members) do if not targets[member.guid] then return nil,"A current raider is missing a reviewed target." end end
    local counts={0,0,0,0,0,0,0,0}
    for guid,group in pairs(targets) do
        if not snapshot.byGuid[guid] then return nil,"Draft identity is no longer in this raid." end
        counts[group]=counts[group]+1;if counts[group]>5 then return nil,"Target group exceeds five current raiders." end
    end
    return targets,missing
end
local function Plan(snapshot,targets)
    local current,counts,ordered={},Copy(snapshot.counts),{}
    for _,member in ipairs(snapshot.members) do current[member.guid]=member.group;ordered[#ordered+1]=member.guid end
    table.sort(ordered)
    local plan={}
    for _=1,40 do
        local guid
        for _,value in ipairs(ordered) do if current[value]~=targets[value] then guid=value;break end end
        if not guid then return plan end
        local from,to=current[guid],targets[guid]
        local operation={guid=guid,targetGroup=to,before=Fingerprint(snapshot.members,current)}
        if counts[to]<5 then
            operation.kind="move";current[guid]=to;counts[from]=counts[from]-1;counts[to]=counts[to]+1
        else
            local other
            for _,value in ipairs(ordered) do if current[value]==to and targets[value]~=to then other=value;break end end
            if not other then return nil,"No safe capacity-preserving operation exists." end
            operation.kind="swap";operation.otherGuid=other;operation.otherTargetGroup=from;current[guid],current[other]=to,from
        end
        operation.after=Fingerprint(snapshot.members,current);plan[#plan+1]=operation
    end
    for _,guid in ipairs(ordered) do if current[guid]~=targets[guid] then return nil,"Operation bound exceeded." end end
    return plan
end
local function Capabilities(plan)
    if #plan==0 then return true end
    if type(C_Timer)~="table" or type(C_Timer.NewTimer)~="function" then return false,"Apply timeout API is unavailable." end
    for _,operation in ipairs(plan) do
        local func=operation.kind=="move" and SetRaidSubgroup or SwapRaidSubgroup
        if type(func)~="function" then return false,"A required raid subgroup API is unavailable." end
    end
    return true
end
function Groups:PrepareApply()
    local ok,reason=Editable();if not ok then return nil,reason end
    local snapshot;snapshot,reason=Capture();Record(snapshot,reason)
    if not snapshot then Emit();return nil,reason end
    if uncertain then Emit();return nil,"A submitted subgroup result is still unresolved; refresh after it settles." end
    local targets,missing=Targets(snapshot,View());if not targets then preview=nil;Emit();return nil,missing end
    local plan;plan,reason=Plan(snapshot,targets);if not plan then preview=nil;Emit();return nil,reason end
    local changes={}
    for _,member in ipairs(snapshot.members) do changes[#changes+1]={guid=member.guid,fullName=member.fullName,currentGroup=member.group,targetGroup=targets[member.guid],changed=member.group~=targets[member.guid]} end
    local changed=0;for _,row in ipairs(changes) do if row.changed then changed=changed+1 end end
    local canApply,why=snapshot.canApply,snapshot.reason
    if canApply then canApply,why=Capabilities(plan) end
    previewSerial=previewSerial+1
    preview={id="preview:"..previewSerial,draftRevision=draft.revision,fingerprint=snapshot.fingerprint,targets=targets,
        changes=changes,missing=missing,changedCount=changed,operationCount=#plan,canApply=canApply,reason=why,plan=plan}
    draft.basis=snapshot.fingerprint;draft.stale=false;Emit();return Copy(preview)
end
local function CancelTimer(active)
    if active.timer then pcall(active.timer.Cancel,active.timer);active.timer=nil end
end
local function Finish(status,reason)
    local active=job;if not active then return end
    CancelTimer(active)
    applyState={status=status,reason=reason,stopReason=status=="stopped" and reason or nil,confirmed=active.confirmed,total=#active.plan,
        inFlight=active.waiting==true,unknownResult=status=="stopped" and active.waiting==true,
        review=Copy(active.review),log=Copy(active.log),pending=Copy(active.pending)}
    if status=="stopped" and active.waiting then uncertain=Copy(active.pending) end
    job=nil;preview=nil;SyncSubscriptions();Emit()
end
function Groups:CancelApply(reason)
    if not job then return false,"No Apply job is running." end
    Finish("stopped",Text(reason,200) or "Cancelled; a submitted operation may still settle.");return true
end
function Groups:RecoverStopped(observedFingerprint)
    if job or not uncertain then return false,"There is no stopped unresolved operation to recover." end
    if not Text(observedFingerprint,16384) then return false,"Review the readable current raid groups first." end
    local snapshot,reason=Capture();Record(snapshot,reason)
    if not snapshot then Emit();return false,reason end
    if snapshot.fingerprint~=observedFingerprint then Emit();return false,"Raid groups changed; review the newly observed current groups again." end
    if not snapshot.canApply then Emit();return false,snapshot.reason end
    if not uncertain then Emit();return true,"The submitted result is now observed. Prepare a fresh target preview." end
    uncertain=nil;priorRequestMaySettle=true;preview=nil
    applyState.inFlight=false;applyState.unknownResult=true;applyState.recovered=true
    applyState.reason="Acknowledged the reviewed current groups. A prior request may still settle; prepare a fresh preview before another Apply."
    SyncSubscriptions();Emit();return true,applyState.reason
end
IssueNext=function(snapshot)
    local active=job;if not active then return end
    local reason
    if not snapshot then snapshot,reason=Capture() end
    Record(snapshot,reason)
    if not snapshot then Finish("stopped",reason);return end
    if not snapshot.canApply then Finish("stopped",snapshot.reason);return end
    local operation=active.plan[active.confirmed+1]
    if not operation then Finish("complete","All present targets confirmed.");return end
    if snapshot.fingerprint~=operation.before then Finish("stopped","Roster changed before the next operation.");return end
    local first=snapshot.byGuid[operation.guid]
    local second=operation.otherGuid and snapshot.byGuid[operation.otherGuid]
    local function SameIndex(member)
        if not member then return false end
        local ok,value=pcall(UnitGUID,"raid"..member.index)
        return ok and not Secret(value) and value==member.guid
    end
    if not SameIndex(first) or (operation.kind=="swap" and not SameIndex(second)) then Finish("stopped","Raid indices changed before submission.");return end
    local func=operation.kind=="move" and SetRaidSubgroup or SwapRaidSubgroup
    if type(func)~="function" or type(C_Timer)~="table" or type(C_Timer.NewTimer)~="function" then Finish("stopped","Group action or timeout API is unavailable.");return end
    active.waiting=true;active.pending=operation
    local token=active.confirmed
    local timed,timer=pcall(C_Timer.NewTimer,TIMEOUT,function()
        if job==active and active.waiting and active.confirmed==token then Finish("stopped","Timed out waiting for the exact roster acknowledgement; result may still settle.") end
    end)
    if not timed or Secret(timer) or (type(timer)~="table" and type(timer)~="userdata") or type(timer.Cancel)~="function" then active.waiting=false;Finish("stopped","Could not create an Apply timeout.");return end
    active.timer=timer;active.dispatching=true
    local ok,result
    if operation.kind=="move" then ok,result=pcall(func,first.index,operation.targetGroup)
    else ok,result=pcall(func,first.index,second.index) end
    active.dispatching=false
    if job~=active then return end
    if not ok or Secret(result) or result==false then Finish("stopped","The subgroup call failed or was rejected; result may still settle.");return end
    applyState={status="waiting",confirmed=active.confirmed,total=#active.plan,inFlight=true,unknownResult=false,
        review=Copy(active.review),log=Copy(active.log)}
    Emit()
    if job==active and active.eventPending then active.eventPending=nil;Observe() end
end
Observe=function()
    if job and job.dispatching then job.eventPending=true;return true end
    local snapshot,reason=Capture();Record(snapshot,reason)
    local active=job
    if not active then Emit();return snapshot~=nil,reason end
    if not snapshot then Finish("stopped",reason);return false,reason end
    if not snapshot.canApply then Finish("stopped",snapshot.reason);return false,snapshot.reason end
    local operation=active.pending
    if snapshot.fingerprint==operation.before then Emit();return true end
    if snapshot.fingerprint~=operation.after then Finish("stopped","Unexpected raid membership or subgroup change; no further operations submitted.");return false,"Roster changed." end
    CancelTimer(active);active.waiting=false;active.confirmed=active.confirmed+1
    active.log[#active.log+1]={kind=operation.kind,guid=operation.guid,otherGuid=operation.otherGuid,targetGroup=operation.targetGroup,status="confirmed"}
    if active.confirmed==#active.plan then Finish("complete","All present targets confirmed.") else IssueNext(snapshot) end
    return true
end
function Groups:Apply(id)
    if job or uncertain then return false,"An Apply or unresolved submitted operation is already outstanding." end
    if not Text(id,80) or not preview or preview.id~=id or preview.canApply~=true or not draft or preview.draftRevision~=draft.revision then return false,"Prepare and review a fresh eligible target preview first." end
    local selected=Copy(preview)
    local snapshot,reason=Capture();Record(snapshot,reason)
    if not snapshot or snapshot.fingerprint~=selected.fingerprint then preview=nil;Emit();return false,reason or "Roster changed since the preview; review again." end
    if not snapshot.canApply then preview=nil;Emit();return false,snapshot.reason end
    local available,why=Capabilities(selected.plan)
    if not available then preview=nil;Emit();return false,why end
    if #selected.plan==0 then preview=nil;applyState={status="complete",confirmed=0,total=0,inFlight=false,unknownResult=false,reason="No changes needed."};Emit();return true end
    job={plan=selected.plan,targets=selected.targets,review=selected,log={},confirmed=0,waiting=false}
    SyncSubscriptions();IssueNext(snapshot)
    if not job and applyState.status=="stopped" then return false,applyState.reason end
    return true
end

local subscriptions={}
local function Interrupted(reason)
    preview=nil;if draft then draft.stale=true end
    if live then live.canApply=false;live.reason=reason end
    if job then Finish("stopped",reason) else Emit() end
end
subscriptions[#subscriptions+1]=RA:RegisterOptionalEvent("GROUP_ROSTER_UPDATE",function()Observe()end)
subscriptions[#subscriptions+1]=RA:RegisterOptionalEvent("PLAYER_REGEN_DISABLED",function()Interrupted("Combat started; Apply stopped.")end)
subscriptions[#subscriptions+1]=RA:RegisterOptionalEvent("PLAYER_REGEN_ENABLED",function()Observe()end)
subscriptions[#subscriptions+1]=RA:RegisterOptionalEvent("ENCOUNTER_START",function()Interrupted("Encounter started; Apply stopped.")end)
subscriptions[#subscriptions+1]=RA:RegisterOptionalEvent("ENCOUNTER_END",function()Observe()end)
subscriptions[#subscriptions+1]=RA:RegisterOptionalEvent("PARTY_LEADER_CHANGED",function()Observe()end)
subscriptions[#subscriptions+1]=RA:RegisterOptionalEvent("PLAYER_LEAVING_WORLD",function()Interrupted("World context changed; Apply stopped.")end)
SyncSubscriptions=function()
    local enabled=opened or job~=nil
    for _,subscription in ipairs(subscriptions) do subscription:SetEnabled(enabled) end
end
RA:RegisterCallback("PROFILE_RESET",function()if job then Finish("stopped","Profile context changed; Apply stopped.") end end)
RA:RegisterCallback("RAID_GROUP_OPERATION_CHANGED",function()if opened or job then Observe() end end)
