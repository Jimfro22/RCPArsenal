-- Actual planner, fictional native rosters and asynchronous ACKs. Realm folding
-- is an import alias policy, not a verified native canonicalization algorithm.
local file=assert(io.open('tests/raid_groups.lua'));local source=file:read('*a');file:close()
source=source:sub(1,assert(source:find('local h=fresh(10);local g=h.groups',1,true))-1)
source=source..[=[
local f=assert(io.open('tests/fixtures/raid_groups/coiled_altar_wowutils.txt'));local note=f:read('*a');f:close()
local function owner(mode)
    local h=fresh(20);local g=h.groups;local parsed=assert(g:ParseNote(note))
    for index,value in ipairs(parsed[1].slots)do
        local name,realm=value:match('^([^%-]+)%-(.+)$')
        if mode~='literal' then realm=realm:gsub("'",'')end
        if mode=='hyphen' then realm=realm:gsub('Nerzhul','Ner-zhul'):gsub('MalGanis','Mal-Ganis')end
        h.roster[index]={guid=('Player-1-%06x'):format(index),name=name,realm=realm,group=math.floor((index-1)/5)%4+1,online=index~=7}
        h.roster[index].group=h.roster[index].group%4+1
    end
    check(g:Open(),'Owner roster capture failed')
    local ok,name=g:ImportAndSaveNote(note,1);check(ok,name or 'Owner import failed')
    return h,g,name
end
for _,mode in ipairs({'literal','normalized','hyphen'})do
    local h,g,name=owner(mode);local state=g:GetState();local missing,tray=0,0
    for _,entry in pairs(state.view.entries)do if entry.missing then missing=missing+1 end end
    for _,id in ipairs(state.view.tray)do if state.view.entries[id].guid then tray=tray+1 end end
    check(missing==0 and tray==0 and represented(state)==20,'Owner aliases produced phantom/unassigned cards: '..mode)
    local p=assert(g:PrepareApply());check(p.canApply and p.changedCount==20 and #p.missing==0,'Owner full-group mapping stayed blocked: '..mode)
    check(p.realmAliasCount==(mode=='literal' and 0 or 6),'Alias disclosure count wrong: '..mode)
    check(#h.calls==0 and #h.timers==0,'Import/save/review moved players')
    check(g:LoadLayout(name) and g:PrepareApply().canApply,'Saved owner layout lost matching')
    local ok,why,review=h:start();check(ok,why or 'Owner Apply failed');h:complete()
    for _,row in ipairs(review.changes)do check(h:member(row.guid).group==row.targetGroup,'Owner ACK mapping lost GUID identity')end
    check(g:SaveLayout(name) and g:LoadLayout(name) and g:PrepareApply().changedCount==0,'Reloaded confirmed layout changed targets')
end
-- Legacy saved grouped display name plus a native-alias tray duplicate.
local h,g,name=owner('normalized');local stored=h.env.RaidArsenalDB.raidGroupLayouts.items[name]
for _,i in ipairs({5,6,7,8,15,19})do stored.tray[#stored.tray+1]=h.roster[i].name..'-'..h.roster[i].realm end
check(g:LoadLayout(name),'Legacy alias layout could not load')
local state=g:GetState();check(#state.view.tray==0 and state.draft.mergedRealmAliases==6 and state.layout.contentDirty,'Redundant aliases not reconciled locally/disclosed')
check(#stored.tray==6,'Load silently overwrote saved layout')
local p=assert(g:PrepareApply());check(p.canApply and p.mergedRealmAliases==6,'Legacy aliases still blocked Apply')
check(g:SaveLayout(name) and #h.env.RaidArsenalDB.raidGroupLayouts.items[name].tray==0,'Explicit Save did not store reconciled layout')
check(not g:GetState().draft.mergedRealmAliases and g:GetState().preview.mergedRealmAliases==0 and not g:GetState().layout.contentDirty,'Saved footer retained Save-needed alias warning')
-- Every current member must still have an explicit target, even with all draft
-- slots occupied. Moving an unassigned card onto an absent one retains the
-- absent card in the tray; nobody is arbitrarily reassigned or removed.
for _,size in ipairs({25,40})do
    h=fresh(size);g=h.groups;check(g:Open(),'Full raid capture failed')
    local tokens={}
    for i=1,40 do
        if i<=10 then local j=i<=5 and i+5 or i-5;tokens[i]=h.roster[j].name..'-'..h.roster[j].realm
        else tokens[i]='Absent'..i..'-OtherRealm'end
    end
    check(g:ImportNote('invitelist:'..table.concat(tokens,',')..';',1),'Full template import failed')
    local preview,reason=g:PrepareApply();check(not preview and reason:find('needs a target',1,true) and reason:find('absent card',1,true) and #h.calls==0,'Unassigned full-group blocker is not actionable')
    state=g:GetState();local pending={}
    for _,id in ipairs(state.view.tray)do if state.view.entries[id].guid then pending[#pending+1]=id end end
    check(#pending==size-10,'Present overflow cards disappeared')
    for _,id in ipairs(pending)do
        state=g:GetState();local placed=false
        for group=1,8 do for slot=1,5 do
            local entry=state.view.entries[state.view.groups[group][slot]]
            if not placed and entry and entry.absentPlaceholder then check(g:Move(id,group,slot),'Could not swap onto absent card');placed=true end
        end end
        check(placed,'Full-group template offered no retained-placeholder placement')
    end
    p=assert(g:PrepareApply());check(p.canApply and #p.missing==30,'Retained absent cards blocked complete targets')
    check(represented(g:GetState())==size+30,'Retained identities were deleted')
    local ok,why,review=h:start();check(ok,why);h:complete()
    for _,row in ipairs(review.changes)do check(h:member(row.guid).group==row.targetGroup,'Full-group ACK drifted from reviewed target')end
end
-- Different realms, same short name, and alias collisions stay distinct/manual.
h=fresh(2);g=h.groups;h.roster[1].name='Same';h.roster[1].realm='Illidan';h.roster[2].name='Same';h.roster[2].realm='Thrall';check(g:Open(),'Different-realm capture failed')
check(g:ImportNote('invitelist:Same;',1) and not g:PrepareApply(),'Short-name ambiguity auto-matched')
check(g:ImportNote('invitelist:,,,,,Same-Illidan;',1),'Qualified import failed');p=assert(g:PrepareApply());check(p.targets[h.roster[1].guid]==2 and p.targets[h.roster[2].guid]==1,'Different realm was merged or moved arbitrarily')
h=fresh(2);g=h.groups;h.roster[1].name='Same';h.roster[1].realm='A-B';h.roster[2].name='Same';h.roster[2].realm='AB'
check(not g:Open() and #h.calls==0,'Ambiguous live alias collision accepted')
h,g=owner('normalized');local prior=copy(g:GetState().draft)
check(not g:ImportNote("invitelist:Same-Mal'Ganis,Same-MalGanis;",1) and same(prior,g:GetState().draft),'Duplicate imported aliases were not rejected atomically')
local saved=h.env.RaidArsenalDB.raidGroupLayouts.items['Coiled Altar'];saved.slots[1]="Same-Mal'Ganis";saved.slots[2]='Same-MalGanis'
h.roster[1].name='Same';h.roster[1].realm='MalGanis';check(g:RefreshRoster(),'Single alias roster refresh failed')
check(not g:LoadLayout('Coiled Altar'),'Two group targets for one live alias were silently merged')
-- Fresh membership, authority and combat checks are still required after review.
for _,change in ipairs({'guid','combat','authority'})do
    h,g=owner('normalized');p=assert(g:PrepareApply())
    if change=='guid' then h.roster[1].guid='Player-1-ffffff' elseif change=='combat' then h.combat=true else h.leader=false end
    h.explicitSession=true;check(not g:Apply(p.id) and #h.calls==0,'Alias fix bypassed fresh safety gate: '..change)
end
print('PASS: '..checks..' realm-alias/owner-import/full-group assertions (offline actual planner; native acceptance pending)')
]=]
assert(loadstring(source))()
