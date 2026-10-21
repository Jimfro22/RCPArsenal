-- Actual RaidGroups + actual Core subscription/callback machinery. Fictional
-- rosters and asynchronous server ACKs; no WoW/native/taint acceptance claim.
local checks=0
local corePath=arg[1]
if not corePath then
    local file=io.open('RCPArsenal/Core.lua')
    if file then file:close();corePath='RCPArsenal/Core.lua' else corePath='baseline/RCPArsenal/Core.lua' end
end
local function check(value,message) checks=checks+1;assert(value,message) end
local function copy(value)
    if type(value)~="table" then return value end
    local out={};for k,v in pairs(value)do out[k]=copy(v)end;return out
end
local function same(a,b)
    if type(a)~=type(b)then return false end
    if type(a)~="table"then return a==b end
    for k,v in pairs(a)do if not same(v,b[k])then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end
    return true
end
local function roster(count)
    local out={}
    for i=1,count do out[i]={guid=('Player-1-%06x'):format(i),name=('Raider%02d'):format(i),realm='TestRealm',group=math.floor((i-1)/5)+1,online=true} end
    return out
end
local function fresh(count,saved)
    local h={roster=roster(count or 10),reads=0,timers={},calls={},frames={},overrides={},callbacks=0,
        inRaid=true,home=true,instance=false,combat=false,encounter=false,leader=true,assistant=false,
        sorting=false,pending=false,explicitSession=false}
    h.secret=setmetatable({},{__tostring=function()error('Secret tostring')end,__index=function()error('Secret indexing')end})
    local env=setmetatable({}, {__index=_G});env._G=env;h.env=env
    env.issecretvalue=function(v)return rawequal(v,h.secret)end
    env.LE_PARTY_CATEGORY_HOME=1;env.LE_PARTY_CATEGORY_INSTANCE=2
    local function api(name,fn)
        env[name]=function(...)
            h.reads=h.reads+1
            if h.overrides[name]then return h.overrides[name](...)end
            return fn(...)
        end
    end
    local function member(unit)local index=tonumber(unit:match('^raid(%d+)$'));return index and h.roster[index]end
    api('IsInRaid',function(category)if category==1 then return h.home end;return h.inRaid end)
    api('IsInGroup',function(category)check(category==2,'Unexpected instance category');return h.instance end)
    api('InCombatLockdown',function()return h.combat end)
    api('IsEncounterInProgress',function()return h.encounter end)
    api('UnitIsGroupLeader',function()return h.leader end)
    api('UnitIsGroupAssistant',function()return h.assistant end)
    api('GetNumGroupMembers',function()return #h.roster end)
    api('GetRaidRosterInfo',function(i)
        local row=h.roster[i]
        if not row then return nil end
        return row.name..'-'..row.realm,0,row.group,70,'Warrior','WARRIOR','Zone',row.online
    end)
    api('UnitFullName',function(unit)local row=member(unit);if row then return row.name,row.realm end end)
    api('UnitGUID',function(unit)local row=member(unit);return row and row.guid end)
    api('UnitAffectingCombat',function(unit)local row=member(unit);return row and row.combat==true end)
    api('UnitGroupRolesAssigned',function(unit)local row=member(unit);return row and row.role end)
    api('GetNormalizedRealmName',function()return 'TestRealm'end)
    env.CreateFrame=function()
        local f={scripts={},events={}}
        function f:RegisterEvent(name)self.events[name]=true end
        function f:RegisterUnitEvent(name)self.events[name]=true end
        function f:UnregisterEvent(name)self.events[name]=nil end
        function f:SetScript(name,fn)self.scripts[name]=fn end
        h.frames[#h.frames+1]=f;return f
    end
    env.C_Timer={NewTimer=function(duration,fn)
        check(h.explicitSession,'Timer outside explicit Apply')
        check(duration>0 and duration<=5,'Unbounded operation timeout')
        if h.timerFailure then error('Timer failed')end
        local t={duration=duration,fn=fn,cancelled=false};function t:Cancel()self.cancelled=true end
        h.timers[#h.timers+1]=t;return t
    end}
    local function mutation(kind,i,j)
        check(h.explicitSession,'Group action outside explicit Apply')
        check(not h.combat and not h.encounter and (h.leader or h.assistant),'Action bypassed context/authority')
        check(not h.sorting and not h.pending,'Action raced legacy group job')
        check(not h.pendingCommand,'Second move submitted before ACK')
        check(#h.calls<40,'Apply exceeded finite operation bound')
        local first=h.roster[i];check(first~=nil,'Stale source index')
        local command={kind=kind,index=i,otherIndex=kind=='swap' and j or nil,guid=first.guid,targetGroup=kind=='move' and j or nil}
        if kind=='swap'then check(h.roster[j]~=nil,'Stale swap index');command.otherGuid=h.roster[j].guid end
        h.calls[#h.calls+1]=command
        if h.actionFailure then error('Native rejection')end
        h.pendingCommand=command
        if h.synchronous then h:ack(true)end
    end
    env.SetRaidSubgroup=function(i,g)return mutation('move',i,g)end
    env.SwapRaidSubgroup=function(i,j)return mutation('swap',i,j)end
    for _,name in ipairs({'InviteUnit','UninviteUnit','SetRaidTarget','SetRaidTargetIcon','ConvertToRaid','SetPartyAssignment','PromoteToLeader','PromoteToAssistant','SendChatMessage'})do
        env[name]=function()error('Forbidden planner side effect: '..name)end
    end
    env.C_ChatInfo={SendAddonMessage=function()error('Planner sent addon message')end}
    local function load(path)
        local fn=assert(loadfile(path));setfenv(fn,env);return fn
    end
    local RA={};h.RA=RA
    load(corePath)('RCPArsenal',RA)
    env.RaidArsenalDB=saved or {profile=RA:CreateDefaultProfile()}
    RA.Print=function(_,message)error(message)end
    RA.RaidLeaderToolbox={IsSorting=function()return h.sorting end,IsGroupOperationPending=function()return h.pending end}
    h.beforeRegistration=copy(h.frames[1].events)
    load('RCPArsenal/RaidGroups.lua')('RCPArsenal',RA);h.groups=RA.RaidGroups
    RA:RegisterCallback('RAID_GROUPS_CHANGED',function()h.callbacks=h.callbacks+1 end)
    function h:event(name)
        for _,f in ipairs(self.frames)do if f.events[name] and f.scripts.OnEvent then f.scripts.OnEvent(f,name)end end
    end
    function h:member(guid)for _,row in ipairs(self.roster)do if row.guid==guid then return row end end end
    function h:ack(rotate)
        local cmd=self.pendingCommand;check(cmd~=nil,'No submitted operation to ACK')
        local first=self:member(cmd.guid);check(first~=nil,'Source disappeared before simulated ACK')
        if cmd.kind=='move'then first.group=cmd.targetGroup
        else local other=self:member(cmd.otherGuid);check(other~=nil,'Swap member disappeared');first.group,other.group=other.group,first.group end
        self.pendingCommand=nil
        if rotate and #self.roster>1 then local row=table.remove(self.roster,1);self.roster[#self.roster+1]=row end
        self:event('GROUP_ROSTER_UPDATE')
    end
    function h:expire(force)
        local timer=self.timers[#self.timers];check(timer~=nil,'No timeout to fire')
        if force or not timer.cancelled then timer.fn()end
    end
    function h:openDraft()
        check(self.groups:Open(),'Open failed')
        check(self.groups:FromCurrentRaid(),'From current failed')
        return self.groups:GetState()
    end
    function h:start()
        local p,why=self.groups:PrepareApply();check(p~=nil,why or 'Preview failed')
        self.explicitSession=true
        local ok,err=self.groups:Apply(p.id);return ok,err,p
    end
    function h:complete()
        local iterations=0
        while self.groups:IsApplying()do iterations=iterations+1;check(iterations<=40,'Apply did not terminate');self:ack(true)end
        local result=self.groups:GetState().apply
        check(result.status=='complete','Apply did not report confirmed completion: '..tostring(result.reason))
    end
    return h
end
local function idFor(state,guid)
    for id,row in pairs(state.view.entries)do if row.guid==guid then return id end end
end
local function represented(state)
    local seen,count={},0
    for g=1,8 do check(#state.view.groups[g]==5,'Slot array is not five explicit slots')
        for s=1,5 do local id=state.view.groups[g][s];if id then check(not seen[id] and state.view.entries[id],'Lost/duplicate grouped card');seen[id]=true;count=count+1 end end
    end
    for _,id in ipairs(state.view.tray)do check(not seen[id] and state.view.entries[id],'Lost/duplicate tray card');seen[id]=true;count=count+1 end
    for id in pairs(state.view.entries)do check(seen[id],'Entry invisible in groups/tray')end
    return count
end

-- Construction/GetState remain lazy even with saved layouts present.
local h=fresh(10);local g=h.groups
check(h.reads==0 and #h.timers==0 and #h.calls==0,'Module construction performed optional work')
check(same(h.frames[1].events,h.beforeRegistration),'Inactive module registered active native events')
check(h.env.RaidArsenalDB.raidGroupLayouts==nil,'Constructor initialized saved state')
for _=1,3 do check(g:GetState().draft==nil and #g:ListLayouts()==0,'Idle state invented a draft/layout')end
check(h.reads==0 and h.env.RaidArsenalDB.raidGroupLayouts==nil,'Getters queried or wrote saved state')

local state=h:openDraft();check(represented(state)==10,'Current raid lost members')
local first,second=state.view.groups[1][1],state.view.groups[2][1]
local initial=copy(state.view)
check(g:Move(first,2,1),'Occupied drop failed');state=g:GetState()
check(state.view.groups[2][1]==first and state.view.groups[1][1]==second and represented(state)==10,'Occupied drop failed lossless swap')
check(g:Move(first,nil,nil) and #g:GetState().view.tray==1,'Tray move failed')
check(not g:PrepareApply(),'Unplaced present raider did not block Apply')
check(g:Move(first,2,1),'Tray-to-slot move failed');check(represented(g:GetState())==10,'Tray drop lost a raider')
local beforeReads=h.reads
check(g:SaveLayout('Boss One') and #h.calls==0 and #h.timers==0,'Save had live effects')
check(h.reads==beforeReads,'Save queried live roster')
local stored=h.env.RaidArsenalDB.raidGroupLayouts.items['Boss One']
local function noRuntimeIdentity(v)
    if type(v)=='table'then for k,x in pairs(v)do check(k~='guid' and k~='index','Saved runtime identity');noRuntimeIdentity(x)end
    elseif type(v)=='string'then check(not v:match('^Player%-'),'Saved session GUID')end
end
noRuntimeIdentity(stored)
local saved=copy(h.env.RaidArsenalDB)
local reopened=fresh(10,saved);reopened.groups:Open();check(reopened.groups:LoadLayout('Boss One'),'Layout did not survive reload')
check(represented(reopened.groups:GetState())==10 and #reopened.calls==0,'Load lost people or changed raid')
local detached=reopened.groups:GetState();detached.view.groups[1][1]=false;detached.draft.revision=999
check(represented(reopened.groups:GetState())==10 and reopened.groups:GetState().draft.revision~=999,'Getter exposed mutable state')

-- Exact reviewed targets, occupied full groups, fresh indices after each ACK.
h=fresh(40);g=h.groups;state=h:openDraft()
for group=1,4 do for slot=1,5 do check(g:Move(state.view.groups[group][slot],group+4,slot),'Full group swap edit failed')end end
local p=assert(g:PrepareApply());check(p.changedCount==40 and p.operationCount<=40,'Full forty-player preview wrong')
local target=copy(p.targets);p.targets[h.roster[1].guid]=1
h.explicitSession=true;check(g:Apply(p.id),'Full raid Apply failed')
check(#h.calls==1,'Apply issued multiple operations without ACK')
local timer=h.timers[#h.timers];h:event('GROUP_ROSTER_UPDATE')
check(#h.calls==1 and h.timers[#h.timers]==timer,'Unchanged roster event ACKed/retried/reset timeout')
check(g:GetState().preview and g:GetState().preview.status=='applying','Reviewed targets vanished during Apply')
check(not g:Move(g:GetState().view.groups[1][1],3,1),'Apply allowed target edits')
check(not g:Apply(p.id),'Apply admitted a concurrent job')
h:ack(true);local afterFirst=#h.calls;timer.fn()
check(g:IsApplying() and g:GetState().apply.confirmed==1 and #h.calls==afterFirst,'Prior operation timeout stopped/retried a later step')
h:complete()
for _,member in ipairs(h.roster)do check(member.group==target[member.guid],'Actual result differs from immutable reviewed targets')end
state=g:GetState();check(state.apply.confirmed==state.apply.total and #state.apply.log==state.apply.total,'Confirmed log incomplete')
check(#h.calls<=40 and h.pendingCommand==nil,'Apply bound/pending command wrong')
for _,t in ipairs(h.timers)do check(t.cancelled,'Finished job retained timeout')end
h:expire(true);check(g:GetState().apply.status=='complete','Stale timeout changed completion')

-- A nonfull group uses move, and No changes is a genuine zero-action result.
h=fresh(6);g=h.groups;state=h:openDraft();check(g:Move(state.view.groups[1][1],2,2),'Move to free slot failed')
check(h:start(),'Move Apply failed');check(h.calls[1].kind=='move','Free capacity did not use a move');h:complete()
local calls=#h.calls;check(h:start(),'No-op Apply failed');check(#h.calls==calls and not g:IsApplying(),'No-op Apply made live changes')

-- Preview invalidation never silently rewrites draft; new raiders are visible.
h=fresh(10);g=h.groups;state=h:openDraft();local revision=state.draft.revision
p=assert(g:PrepareApply());h.roster[1].group=3;h:event('GROUP_ROSTER_UPDATE')
state=g:GetState();check(state.draft.stale and state.preview==nil and state.draft.revision==revision,'Roster change rewrote draft or retained preview')
h.explicitSession=true;check(not g:Apply(p.id) and #h.calls==0,'Stale preview issued an operation')
h.roster[#h.roster+1]={guid='Player-1-0000ff',name='Newraider',realm='TestRealm',group=3,online=true}
h:event('GROUP_ROSTER_UPDATE');state=g:GetState();check(represented(state)==11 and #state.view.tray==1,'New current raider disappeared instead of appearing in tray')
check(not g:PrepareApply(),'Unreviewed new member was silently assigned')
local new=idFor(state,'Player-1-0000ff');check(g:Move(new,3,2) and g:PrepareApply(),'Explicit new-member placement failed')

-- Membership/index reorder alone is harmless; group changes stop in flight.
h=fresh(10);g=h.groups;state=h:openDraft();g:Move(state.view.groups[1][1],2,1);check(h:start(),'Race setup failed')
local submitted=#h.calls;h.roster[2].group=3;h:event('GROUP_ROSTER_UPDATE')
state=g:GetState();check(state.apply.status=='stopped' and state.apply.unknownResult and #h.calls==submitted,'Concurrent subgroup change failed to stop')
h:expire(true);check(#h.calls==submitted,'Stopped job resumed from timeout')

-- Context gates are rechecked before start and during ACK, not only in UI.
for _,case in ipairs({'combat','encounter','authority','instance','busy','pending','unknownCombat','unknownAuthority','missingGuard'})do
 h=fresh(10);g=h.groups;state=h:openDraft();g:Move(state.view.groups[1][1],2,1);p=assert(g:PrepareApply())
 if case=='combat'then h.combat=true elseif case=='encounter'then h.encounter=true
 elseif case=='authority'then h.leader=false elseif case=='instance'then h.instance=true
 elseif case=='busy'then h.sorting=true elseif case=='pending'then h.pending=true
 elseif case=='unknownCombat'then h.overrides.UnitAffectingCombat=function()return h.secret end
 elseif case=='unknownAuthority'then h.overrides.UnitIsGroupLeader=function()return h.secret end
 else h.RA.RaidLeaderToolbox.IsGroupOperationPending=nil end
 h.explicitSession=true;check(not g:Apply(p.id) and #h.calls==0,'Context/guard bypass before Apply: '..case)
end
for _,event in ipairs({'PLAYER_REGEN_DISABLED','ENCOUNTER_START','PLAYER_LEAVING_WORLD'})do
 h=fresh(10);g=h.groups;state=h:openDraft();g:Move(state.view.groups[1][1],2,1);check(h:start(),'Interrupt setup failed')
 calls=#h.calls;h:event(event);state=g:GetState()
 check(state.apply.status=='stopped' and state.apply.unknownResult and #h.calls==calls,'Interrupt did not stop pending job: '..event)
 h:expire(true);check(#h.calls==calls,'Interrupt auto-resumed job')
end
h=fresh(10);g=h.groups;state=h:openDraft();g:Move(state.view.groups[1][1],2,1);check(h:start(),'Timeout setup failed')
h:expire();state=g:GetState();check(state.apply.status=='stopped' and state.apply.unknownResult and #h.calls==1,'Timeout did not stop without retry')
check(g:IsApplying() and not g:PrepareApply(),'Unknown submitted result admitted a competing review/job')
h:ack(true);check(#h.calls==1 and not g:IsApplying(),'Late ACK resumed stopped job')
check(not g:GetState().apply.unknownResult and g:GetState().apply.status=='stopped','Settled result auto-resumed or remained uncertain')

-- Missing/secret identity data fails closed and leaves the last ordinary view.
for _,api in ipairs({'GetNumGroupMembers','GetRaidRosterInfo','UnitGUID','UnitFullName'})do
 h=fresh(10);g=h.groups;h:openDraft();local before=g:GetState().view
 h.overrides[api]=function()return h.secret end
 check(not g:RefreshRoster() and g:GetState().liveError and g:GetState().draft.stale,'Unavailable roster did not fail closed: '..api)
 check(same(before,g:GetState().view),'Unavailable identity rewrote ordinary draft/view')
 check(not g:PrepareApply() and #h.calls==0,'Unavailable identity allowed preview/action')
end
h=fresh(10);g=h.groups;state=h:openDraft()
check(not g:Move(h.secret,1,1) and not g:Move(state.view.groups[1][1],h.secret,1),'Secret edit input accepted')
check(not g:SaveLayout(h.secret) and not g:LoadLayout(h.secret) and not g:DeleteLayout(h.secret),'Secret storage input accepted')
check(not g:ParseNote(h.secret) and not g:ImportNote('invitelist:A-Realm;',h.secret),'Secret import input accepted')

-- WowUtils first slice: terminal semicolon, interior holes, boss selection,
-- unlisted live keep-group/tray, ghosts/explicit mapping, malformed atomicity.
h=fresh(6);g=h.groups;h:openDraft()
local note='EncounterID:123;Difficulty:Mythic;Name:Boss A\r\ninvitelist:Raider01-TestRealm,,Absent-OtherRealm,,,Raider06-TestRealm;\r\nEncounterID:124;Difficulty:Heroic;Name:Boss B\ninvitelist:Raider02-TestRealm;'
local sections=assert(g:ParseNote(note));check(#sections==2 and #sections[1].slots==6 and sections[1].slots[2]==false,'Parser lost positional holes or added semicolon slot')
check(g:ImportNote(note,1) and #h.calls==0,'Import triggered actions or failed')
state=g:GetState();check(represented(state)==7,'Import lost missing/current people')
check(state.view.entries[state.view.groups[1][3]].missing,'Absent imported player not visible')
check(not g:PrepareApply() and #state.view.tray==1,'Imported ghost silently displaced an unlisted current raider')
check(g:Move(state.view.tray[1],2,2) and g:PrepareApply(),'Reviewed current targets plus known absent ghost failed preview')
local before=copy(g:GetState().draft)
for _,bad in ipairs({'invitelist:A-Realm,A-Realm;','invitelist:A-Realm;B-Realm;','EncounterID:1;Difficulty:M;Name:B\ninvitelist:A-Realm;\ninvitelist:B-Realm;',string.rep('x',65537)})do
 check(not g:ImportNote(bad,1) and same(before,g:GetState().draft),'Malformed import changed draft')
end
check(not g:ParseNote('EncounterID:1;Difficulty:Mythic;Name:No list'),'Missing export treated as empty roster')
local forty={};for i=1,40 do forty[i]='Fictional'..i..'-Realm'end
sections=assert(g:ParseNote('invitelist:'..table.concat(forty,',')..';'))
check(#sections[1].slots==40,'Full forty export became group nine')
check(not g:ParseNote('invitelist:'..table.concat(forty,',')..',Extra-Realm;'),'Over-capacity export accepted')
check(g:ImportNote('invitelist:Raider01;',1),'Short-name import failed local draft creation')
check(not g:PrepareApply(),'Unresolved short identity allowed Apply preview')
state=g:GetState();local unresolved=state.view.groups[1][1]
check(g:ResolveEntry(unresolved,h.roster[1].guid),'Explicit mapping failed')
check(represented(g:GetState())==6,'Explicit mapping duplicated/lost raider')
state=g:GetState();check(#state.view.tray==1 and g:Move(state.view.tray[1],1,2) and g:PrepareApply(),'Unlisted current raider could not be explicitly placed after mapping')
check(g:SaveLayout('Resolved boss') and #h.calls==0,'Resolved named save failed/had action')
check(not g:RemoveEntry(unresolved),'Remove allowed a current raider to disappear')

-- Plan before raid, edit a ghost slot, then explicitly reconcile exact full
-- names after joins. No staged target/position is silently overwritten.
h=fresh(0);h.inRaid=false;g=h.groups
check(g:ImportNote('EncounterID:321;Difficulty:Mythic;Name:Before Raid\ninvitelist:Raider01-TestRealm,,,,,Raider06-TestRealm;',1),'Premade import outside raid failed')
state=g:GetState();local ghost=state.view.groups[1][1]
check(g:Move(ghost,3,2) and g:SaveLayout('Before Raid'),'Premade ghost edits/save failed')
local edited=copy(g:GetState().view.groups)
check(h.reads==0 and #h.calls==0,'Premade local import/save queried or acted')
h.roster=roster(6);h.inRaid=true;h.roster[3].online=false
check(g:Open() and g:GetState().draft.stale,'Joined roster failed to mark premade draft stale')
check(same(g:GetState().view.groups,edited),'Join silently rewrote staged target positions')
check(g:Reconcile() and same(g:GetState().view.groups,edited),'Explicit reconciliation changed manual slot edits')
state=g:GetState();check(state.view.entries[ghost].guid==h.roster[1].guid and state.view.entries[ghost].liveGroup==1,'Exact join was not bound at staged target')
local offline=state.view.entries[idFor(state,h.roster[3].guid)]
check(offline.class=='WARRIOR' and offline.online==false and offline.offline,'Offline/class metadata missing')
for _,id in ipairs(copy(state.view.tray))do
 local current=g:GetState();local member=current.view.entries[id];local group=member.liveGroup;local free
 for slot=1,5 do if not current.view.groups[group][slot]then free=slot;break end end
 check(free and g:Move(id,group,free),'Joined unlisted member could not be deliberately placed')
end
p=assert(g:PrepareApply());check(p.changedCount==1 and p.targets[h.roster[1].guid]==3,'Reviewed premade plan lost manual target')
check(h:start(),'Reconciled premade plan failed Apply');h:complete()
check(h:member('Player-1-000001').group==3,'Reconciled plan applied wrong target')

-- Reconcile is not a short-name matcher or an implicit duplicate-card merge.
h=fresh(1);g=h.groups;g:Open();check(g:ImportNote('invitelist:Raider01;',1),'Unresolved import failed')
local beforeGroups=copy(g:GetState().view.groups);check(g:Reconcile(),'No-match reconcile failed')
check(same(beforeGroups,g:GetState().view.groups) and not g:PrepareApply(),'Reconcile guessed a short name')
h=fresh(0);h.inRaid=false;g=h.groups;g:ImportNote('invitelist:Raider01-TestRealm;',1)
h.roster=roster(1);h.inRaid=true;g:Open();state=g:GetState();local newLive=state.view.tray[1]
check(g:Move(newLive,2,1),'Explicit new live edit failed')
beforeGroups=copy(g:GetState().view.groups)
check(not g:Reconcile() and same(beforeGroups,g:GetState().view.groups),'Reconcile silently chose between two staged cards')

-- Entry count remains bounded across multiple entirely different raids; new
-- members remain visible even when adding another local card is rejected.
h=fresh(40);g=h.groups;h:openDraft()
local function replacement(offset)
 local rows=roster(40)
 for i,row in ipairs(rows)do row.guid=('Player-1-%06x'):format(offset+i);row.name='Other'..offset..'x'..i end
 return rows
end
h.roster=replacement(100);h:event('GROUP_ROSTER_UPDATE');state=g:GetState()
for i,id in ipairs(copy(state.view.tray))do check(g:Move(id,math.floor((i-1)/5)+1,(i-1)%5+1),'Bounded new-member addition failed')end
h.roster=replacement(200);h:event('GROUP_ROSTER_UPDATE');state=g:GetState()
local revision=state.draft.revision
check(represented(state)==120 and not g:Move(state.view.tray[#state.view.tray],1,1),'Accumulated draft exceeded 80-entry bound')
check(g:GetState().draft.revision==revision,'Rejected bounded edit changed draft')

-- Sparse/secret/malformed saved variables never replace a valid local draft.
h=fresh(6);g=h.groups;h:openDraft();check(g:SaveLayout('Good'),'Storage setup failed')
before=copy(g:GetState().draft);stored=h.env.RaidArsenalDB.raidGroupLayouts.items.Good
stored.boss={label=h.secret}
check(not g:LoadLayout('Good') and same(before,g:GetState().draft),'Secret saved label changed draft')
stored.boss={label='Good'};stored.slots[2]=nil
check(not g:LoadLayout('Good') and same(before,g:GetState().draft),'Sparse saved slots changed draft')
check(not g:SaveLayout(string.rep('x',81)) and not g:ParseNote('invitelist:Bad|Name-Realm;'),'Unbounded/markup input accepted')

-- Deterministic property cases: valid full-roster permutations always converge
-- without scratch space or changing already-correct targets unnecessarily.
local seed=1729
local function random(n)seed=(seed*48271)%2147483647;return seed%n+1 end
for trial=1,12 do
 h=fresh(40);g=h.groups;h:openDraft()
 for _=1,25 do
  state=g:GetState();local a,b=random(40),random(40)
  local ag,as=math.floor((a-1)/5)+1,(a-1)%5+1
  local bg,bs=math.floor((b-1)/5)+1,(b-1)%5+1
  check(g:Move(state.view.groups[ag][as],bg,bs),'Permutation edit failed')
 end
 p=assert(g:PrepareApply());local targets=copy(p.targets)
 check(p.operationCount<=40,'Permutation plan exceeded bound')
 check(h:start(),'Permutation Apply failed');h:complete()
 for _,row in ipairs(h.roster)do check(row.group==targets[row.guid],'Permutation failed reviewed membership')end
 check(#h.calls<=40,'Permutation exceeded operation bound')
end

-- Synchronous callback delivery cannot recursively submit an unacknowledged
-- operation or overwrite a terminal completion with a stale waiting state.
h=fresh(10);g=h.groups;state=h:openDraft();g:Move(state.view.groups[1][1],2,1);h.synchronous=true
check(h:start() and g:GetState().apply.status=='complete' and not g:IsApplying(),'Reentrant ACK broke completion')
check(#h.calls==1 and h.pendingCommand==nil,'Reentrant ACK duplicated a call')

-- Native/API/timer failures fail before work where detectable; after an API
-- submission failure the result is conservatively fenced, without retry.
h=fresh(10);g=h.groups;state=h:openDraft();g:Move(state.view.groups[1][1],2,1)
h.env.SwapRaidSubgroup=nil;p=assert(g:PrepareApply())
check(not p.canApply,'Unavailable required API left preview enabled');h.explicitSession=true
check(not g:Apply(p.id) and #h.calls==0 and #h.timers==0,'Unavailable required API caused a partial job')
h=fresh(10);g=h.groups;state=h:openDraft();g:Move(state.view.groups[1][1],2,1);h.timerFailure=true
check(not h:start() and #h.calls==0 and not g:IsApplying(),'Timeout allocation failure submitted a move')
h=fresh(10);g=h.groups;state=h:openDraft();g:Move(state.view.groups[1][1],2,1);h.actionFailure=true
check(not h:start() and #h.calls==1 and g:GetState().apply.unknownResult,'Native failure retried or claimed success')
check(not g:PrepareApply(),'Failed native submission was allowed to overlap a new job')
-- Explicit recovery is conditioned on the reviewed fresh roster and known
-- metadata. It cannot be a timer retry or a claim the old native call cancelled.
local stopped=g:GetState();beforeGroups=copy(stopped.view.groups)
check(g:RefreshRoster() and g:GetState().apply.canRecover,'Unchanged failed result lacked practical recovery')
check(not g:RecoverStopped('wrong fingerprint') and g:IsApplying(),'Recovery ignored reviewed roster binding')
h.overrides.UnitGUID=function()return h.secret end
check(not g:RecoverStopped(stopped.live.fingerprint) and g:IsApplying(),'Recovery accepted unavailable metadata')
h.overrides.UnitGUID=nil;h.combat=true
check(not g:RecoverStopped(stopped.live.fingerprint) and g:IsApplying(),'Recovery accepted combat')
h.combat=false;h.leader=false
check(not g:RecoverStopped(stopped.live.fingerprint) and g:IsApplying(),'Recovery accepted missing authority')
h.leader=true
check(g:RecoverStopped(stopped.live.fingerprint) and not g:IsApplying() and #h.calls==1,'Explicit recovery retried/failed to release fence')
state=g:GetState();check(state.apply.recovered and state.apply.unknownResult and state.apply.priorRequestMaySettle,'Recovery falsely claimed prior cancellation')
check(same(beforeGroups,state.view.groups) and state.preview==nil,'Recovery rewrote draft or reused stale preview')
h.actionFailure=false;check(h:start(),'Fresh explicit Apply failed after recovery');h:complete()

-- A prior late result after acknowledgement still interrupts a newly approved
-- job if it differs from that job's exact expected before/after groups.
h=fresh(6);g=h.groups;state=h:openDraft();local changing=state.view.groups[1][1]
g:Move(changing,2,2);check(h:start(),'Late-result setup failed');h:expire()
local late=h.pendingCommand;local observed=g:GetState().live.fingerprint
check(g:RecoverStopped(observed),'Late-result recovery failed')
h.pendingCommand=nil -- old command retained separately, still may arrive
g:Move(changing,3,1);check(h:start(),'New reviewed target after recovery failed')
h:member(late.guid).group=late.targetGroup;h:event('GROUP_ROSTER_UPDATE')
check(g:GetState().apply.status=='stopped' and #h.calls==2,'Late prior result did not interrupt the new job')
h:ack(true);check(#h.calls==2 and g:GetState().apply.status=='stopped','Late-result stop resumed automatically')

-- Authority loss / member combat during an outstanding move stop immediately,
-- and the eventual result never starts the rest of that reviewed plan.
for _,case in ipairs({'authority','memberCombat','pendingSort','membership'})do
 h=fresh(10);g=h.groups;state=h:openDraft();g:Move(state.view.groups[1][1],2,1);g:Move(state.view.groups[1][2],2,2)
 check(h:start(),'In-flight context setup failed')
 if case=='authority'then h.leader=false elseif case=='memberCombat'then h.roster[4].combat=true
 elseif case=='pendingSort'then h.pending=true else table.remove(h.roster,4)end
 h:event('GROUP_ROSTER_UPDATE')
 check(g:GetState().apply.status=='stopped' and #h.calls==1,'In-flight context change continued: '..case)
 h:ack(true);check(#h.calls==1 and g:GetState().apply.status=='stopped','Late context ACK resumed: '..case)
end

-- Close retains local draft, tears down timeout/subscriptions, fences a
-- potentially late result, and only a fresh explicit open observes settlement.
h=fresh(10);g=h.groups;state=h:openDraft();g:Move(state.view.groups[1][1],2,1);check(h:start(),'Close setup failed')
local last=h.timers[#h.timers];g:Close()
check(last.cancelled and g:GetState().draft and g:GetState().apply.status=='stopped' and not h.frames[1].events.GROUP_ROSTER_UPDATE,'Close leaked resources or draft')
h:ack(true);check(g:IsApplying(),'Hidden stopped planner unexpectedly observed roster events')
check(g:Open() and not g:IsApplying() and not g:GetState().apply.unknownResult,'Reopen did not observe late result')
check(#h.calls==1,'Reopen resumed cancelled plan')

-- Local saved layouts are separate from a portable/resettable profile.
h=fresh(6);g=h.groups;h:openDraft();g:SaveLayout('Keep boss');local layouts=h.env.RaidArsenalDB.raidGroupLayouts
h.RA:ResetProfile();check(h.env.RaidArsenalDB.raidGroupLayouts==layouts and #g:ListLayouts()==1,'Profile reset erased local boss layouts')

-- Eligibility transitions invalidate either direction, without changing the
-- draft, resuming jobs or requiring a membership/subgroup fingerprint change.
for _,case in ipairs({'combat','encounter','authority','pending'})do
 h=fresh(10);g=h.groups;state=h:openDraft();g:Move(state.view.groups[1][1],2,1)
 local revision=g:GetState().draft.revision
 if case=='combat'then h.combat=true elseif case=='encounter'then h.encounter=true
 elseif case=='authority'then h.leader=false else h.pending=true end
 p=assert(g:PrepareApply());check(not p.canApply,'Ineligible review incorrectly enabled: '..case)
 if case=='combat'then h.combat=false;h:event('PLAYER_REGEN_ENABLED')
 elseif case=='encounter'then h.encounter=false;h:event('ENCOUNTER_END')
 elseif case=='authority'then h.leader=true;h:event('PARTY_LEADER_CHANGED')
 else h.pending=false;h.RA:FireCallback('RAID_GROUP_OPERATION_CHANGED')end
 state=g:GetState();check(state.preview==nil and state.draft.revision==revision and state.live.canApply,'Eligibility recovery retained disabled preview/rewrote draft: '..case)
 check(#h.calls==0 and #h.timers==0,'Eligibility recovery auto-started work')
 p=assert(g:PrepareApply());check(p.canApply,'Deliberate fresh review stayed disabled: '..case)
 h.pending=true;h.RA:FireCallback('RAID_GROUP_OPERATION_CHANGED')
 check(g:GetState().preview==nil and not g:GetState().live.canApply,'Eligibility loss retained allowed preview')
end
-- The optional subscriptions and busy callback must remain inactive when hidden.
g:Close();beforeReads=h.reads;h:event('PLAYER_REGEN_ENABLED');h:event('PARTY_LEADER_CHANGED');h.RA:FireCallback('RAID_GROUP_OPERATION_CHANGED')
check(h.reads==beforeReads,'Hidden eligibility recovery queried roster')
h=fresh(6);g=h.groups;state=h:openDraft();g:Move(state.view.groups[1][1],2,2);h.leader=false
p=assert(g:PrepareApply());check(not p.canApply,'Authority-ineligible preview enabled')
h.leader=true;h.explicitSession=true
check(not g:Apply(p.id) and #h.calls==0,'Previously ineligible token became actionable without a new eligible review')
check(h:start(),'New eligible review after authority recovery failed');h:complete()

-- Storage and parser count limits, duplicate/cross-realm identity behavior.
h=fresh(6);g=h.groups;h:openDraft();beforeReads=h.reads
for i=1,50 do check(g:SaveLayout('Boss '..i),'Bounded named layout save failed')end
check(#g:ListLayouts()==50 and not g:SaveLayout('Boss 51'),'Named layout count unbounded')
check(not g:SaveLayout('Boss 1'),'Save as silently replaced a different existing layout')
check(g:LoadLayout('Boss 1') and g:SaveLayout('Boss 1') and #g:ListLayouts()==50,'Explicit active-name save did not replace locally')
check(g:DeleteLayout('Boss 2') and g:SaveLayout('Boss 51') and h.reads==beforeReads and #h.calls==0,'Storage edits queried/acted or failed reuse')
local many={};for i=1,33 do many[#many+1]='EncounterID:'..i..';Difficulty:Mythic;Name:Boss '..i..'\ninvitelist:Person-Realm;'end
check(not g:ParseNote(table.concat(many,'\n')),'Section count limit absent')
check(not g:ParseNote('EncounterID:1;Difficulty:M;Name:B\ninvitelist:A-Realm;\nEncounterID:1;Difficulty:M;Name:C\ninvitelist:B-Realm;'),'Duplicate sections silently merged')
h=fresh(6);g=h.groups;h.roster[2].name=h.roster[1].name;h.roster[2].realm='OtherRealm';h:openDraft()
check(g:ImportNote('invitelist:Raider01;',1) and g:Reconcile() and not g:PrepareApply(),'Ambiguous cross-realm short name auto-mapped')
h=fresh(6);g=h.groups;h:openDraft();h.roster[2].name=h.roster[1].name
check(not g:RefreshRoster() and not g:PrepareApply(),'Duplicate complete live identity accepted')
h=fresh(6);g=h.groups;local r=h.reads;check(g:SetVisible(false) and g:SetVisible(false) and h.reads==r,'Idempotent hidden visibility queried roster')
check(g:SetVisible(true),'Visible observation failed');r=h.reads;check(g:SetVisible(true) and h.reads==r,'Repeated visibility refresh queried again')
check(not g:ParseNote('EncounterID:001;Difficulty: Mythic ;Name:B\ninvitelist:A-Realm;\nEncounterID:1;Difficulty:Mythic;Name:C\ninvitelist:B-Realm;'),'Whitespace/leading-zero duplicate header bypassed detection')
h=fresh(6);g=h.groups;state=h:openDraft();h.combat=true;h.overrides.UnitGUID=function()return h.secret end
beforeReads=h.reads
check(g:Move(state.view.groups[1][1],2,2) and g:SaveLayout('Combat draft'),'Ordinary retained draft could not be edited/saved in combat')
check(h.reads==beforeReads and #h.calls==0 and #h.timers==0,'Local combat edit queried restricted identity or acted')
check(not g:PrepareApply() and #h.calls==0,'Restricted combat data permitted Apply')
h=fresh(6);g=h.groups;h:openDraft();local priorDraft=copy(g:GetState().draft.groups)
h.inRaid=false;h:event('GROUP_ROSTER_UPDATE');state=g:GetState()
check(state.live==nil and state.liveError and state.draft.stale and same(priorDraft,state.draft.groups),'Known raid leave retained a false current roster or discarded edits')
for _,row in pairs(state.view.entries)do check(row.missing and row.guid==nil,'Known departed raider displayed as currently present')end

-- Closed observer has no active subgroup subscription or idle timer/query work.
h=fresh(10);g=h.groups;h:openDraft();g:Close();beforeReads=h.reads
h:event('GROUP_ROSTER_UPDATE');for _=1,3 do g:GetState()end
check(h.reads==beforeReads and #h.timers==0 and not h.frames[1].events.GROUP_ROSTER_UPDATE,'Hidden idle planner kept observing/polling')
check(h.env.RaidArsenalDB.raidGroupLayouts==nil,'Observing/editing initialized persistent layouts')

-- Unsaved content ignores live metadata/indices but follows real persisted
-- slots, tray and boss fields. Save as never overwrites a different layout.
h=fresh(2);g=h.groups;state=h:openDraft()
check(state.layout.contentDirty and g:SaveLayout('Baseline'),'New draft/save baseline failed')
check(not g:GetState().layout.contentDirty,'Successful save remained dirty')
local first=g:GetState().view.groups[1][1]
check(g:Move(first,2,1) and g:GetState().layout.contentDirty,'Local move did not become unsaved')
check(g:Move(first,1,1) and not g:GetState().layout.contentDirty,'Returning to saved slots did not become clean')
h.roster[1].role='HEALER';h.roster[1].online=false;h.roster[1].group=3
h:event('PLAYER_ROLES_ASSIGNED');check(not g:GetState().layout.contentDirty,'Live role/offline/group change dirtied local layout')
local r=table.remove(h.roster,1);h.roster[#h.roster+1]=r;h:event('GROUP_ROSTER_UPDATE')
check(not g:GetState().layout.contentDirty,'Raid index reorder dirtied layout')
check(g:SaveLayout('Copy') and not g:SaveLayout('Baseline'),'Save as overwrote a different saved entry')
check(g:LoadLayout('Baseline') and g:SaveLayout('Baseline'),'Loading did not authorize explicit active-name update')
local joined=roster(3)[3];h.roster[#h.roster+1]=joined;h:event('GROUP_ROSTER_UPDATE')
check(not g:GetState().layout.contentDirty and #g:GetState().view.tray==1,'Synthetic live join changed local saved comparison')
check(g:SaveLayout('Baseline'),'Saving staged content with synthetic card failed')
check(h.env.RaidArsenalDB.raidGroupLayouts.items.Baseline.slots[3]==false,'Save silently adopted a synthetic live card')
check(g:LoadLayout('Baseline') and g:GetState().layout.contentDirty,'Load hid adopted extra raiders behind a false saved baseline')
check(g:SaveLayout('Baseline') and not g:GetState().layout.contentDirty,'Explicit adopted layout save did not establish clean content')
check(g:DeleteLayout('Baseline') and g:GetState().layout.contentDirty,'Deleting active saved entry left a false saved state')

-- Atomic import/save persists unresolved names without guessing a realm.
h=fresh(0);h.inRaid=false;g=h.groups
local note='EncounterID:99;Difficulty:Heroic;Name:Boss Import\ninvitelist:ShortName,,Absent-OtherRealm;'
check(g:GetImportName(note,1)=='Boss Import' and h.env.RaidArsenalDB.raidGroupLayouts==nil and h.reads==0,'Import name preview wrote/read native state')
local ok,name=g:ImportAndSaveNote(note,1)
check(ok and name=='Boss Import' and not g:GetState().layout.contentDirty,'Atomic import was not saved cleanly')
local original=copy(h.env.RaidArsenalDB.raidGroupLayouts.items[name])
ok,name=g:ImportAndSaveNote(note,1)
check(ok and name=='Boss Import (2)' and same(original,h.env.RaidArsenalDB.raidGroupLayouts.items['Boss Import']),'Collision import overwrote existing content')
check(g:LoadLayout(name),'Imported unresolved layout not loadable')
state=g:GetState();check(state.view.entries[state.view.groups[1][1]].unresolved and state.view.entries[state.view.groups[1][3]].missing,'Unresolved/absent import did not round trip')
local snapshot,layout,items=copy(state.draft),copy(state.layout),copy(h.env.RaidArsenalDB.raidGroupLayouts.items)
check(not g:ImportAndSaveNote('invitelist:A-Realm,A-Realm;',1) and same(snapshot,g:GetState().draft) and same(layout,g:GetState().layout) and same(items,h.env.RaidArsenalDB.raidGroupLayouts.items),'Malformed atomic import changed draft/store/baseline')
for i=1,48 do h.env.RaidArsenalDB.raidGroupLayouts.items['Limit '..i]=copy(original) end
items=copy(h.env.RaidArsenalDB.raidGroupLayouts.items)
check(not g:ImportAndSaveNote(note,1) and same(snapshot,g:GetState().draft) and same(layout,g:GetState().layout) and same(items,h.env.RaidArsenalDB.raidGroupLayouts.items),'Full-store import was not atomic')
check(h.reads==0 and #h.calls==0 and #h.timers==0,'Local import/save started native work')

-- Local role ordering/splits preserve every staged ID, pinned ghost/unresolved
-- slots and explicit tray entries. Unknown current roles refuse atomically.
local function classifier(_,member)
    if member.role=='TANK' or member.role=='HEALER' then return member.role end
    if member.role=='DAMAGER' then return member.class=='MAGE' and 'RANGED' or 'MELEE' end
end
for _,mode in ipairs({'ROLE_SORT','SPLIT_ODD_EVEN','SPLIT_ADJACENT'})do
 h=fresh(40);g=h.groups;h.RA.RaidLeaderToolbox.GetDraftMemberKind=classifier
 for i,row in ipairs(h.roster)do row.role=({'TANK','DAMAGER','DAMAGER','HEALER'})[(i-1)%4+1] end
 state=h:openDraft();check(g:SaveLayout('Before sort'),'Sort baseline failed')
 local entries=copy(state.draft.entries)
 check(g:SortDraft(mode),'Local sort failed: '..mode)
 state=g:GetState();local seen,sideRoles={},{{},{}}
 for group=1,8 do
  local last=0
  for slot=1,5 do
   local id=state.draft.groups[group][slot];check(id and entries[id] and not seen[id],'Sort lost/duplicated card or exceeded capacity');seen[id]=true
   local entry=state.view.entries[id];local kind=classifier(nil,{role=entry.role,class=entry.class})
   local side=mode=='SPLIT_ODD_EVEN' and ((group-1)%2+1) or (group<=4 and 1 or 2)
   sideRoles[side][kind]=(sideRoles[side][kind]or 0)+1
   local rank=({TANK=1,MELEE=2,RANGED=3,HEALER=4})[kind];check(rank>=last,'Sort did not order roles within groups');last=rank
  end
 end
 check(same(state.draft.entries,entries) and not state.preview and state.layout.contentDirty,'Sort mutated identities or failed dirty/preview invalidation')
 if mode~='ROLE_SORT' then for _,kind in ipairs({'TANK','MELEE','RANGED','HEALER'})do check(math.abs((sideRoles[1][kind]or 0)-(sideRoles[2][kind]or 0))<=1,'Split did not balance known roles')end end
 local sorted=copy(state.draft.groups);check(g:SortDraft(mode) and same(sorted,g:GetState().draft.groups),'Local sort not deterministic')
 check(#h.calls==0 and #h.timers==0,'Local sort submitted native actions/timers')
end
h=fresh(10);g=h.groups;h.RA.RaidLeaderToolbox.GetDraftMemberKind=classifier
for _,row in ipairs(h.roster)do row.role='DAMAGER'end
g:Open();check(g:ImportNote('invitelist:Ghost,,Absent-Realm;',1),'Pinned-card setup failed');state=g:GetState()
local pinned1,pinned3,tray=state.draft.groups[1][1],state.draft.groups[1][3],copy(state.draft.tray)
local all=copy(state.draft.entries)
for _,mode in ipairs({'ROLE_SORT','SPLIT_ODD_EVEN','SPLIT_ADJACENT'})do
 check(g:SortDraft(mode),'Sort with pinned cards failed')
 state=g:GetState();check(state.draft.groups[1][1]==pinned1 and state.draft.groups[1][3]==pinned3 and same(state.draft.tray,tray) and same(state.draft.entries,all),'Sort changed pinned/absent/unresolved/tray cards')
end
local before=copy(g:GetState().draft);h.roster[2].role=nil
check(not g:SortDraft('ROLE_SORT') and same(before,g:GetState().draft),'Unknown role partially edited the draft')
h.overrides.UnitGroupRolesAssigned=function()return h.secret end
check(g:RefreshRoster() and g:GetState().live.members[1].role==nil,'Secret optional role broke ordinary roster capture')
check(not g:SortDraft('ROLE_SORT') and same(before,g:GetState().draft),'Secret role was guessed or changed draft')
g:Close();local reads=h.reads;h:event('PLAYER_ROLES_ASSIGNED');check(h.reads==reads,'Hidden planner observed role events')
print(('PASS: %d raid-group actual-module assertions (fictional asynchronous roster; native APIs/taint pending)'):format(checks))
