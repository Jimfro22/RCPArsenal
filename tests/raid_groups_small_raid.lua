-- Actual planner with fictional small organized raids. No native ACK claim.
local file=assert(io.open('tests/raid_groups.lua'));local source=file:read('*a');file:close()
source=source:sub(1,assert(source:find('local h=fresh(10);local g=h.groups',1,true))-1)
source=source..[=[
local function small(size,online)
    local h=fresh(1);local g=h.groups
    h.roster[1].name='Qtpantts';h.roster[1].realm='Illidan'
    check(g:Open(),'Small organized raid capture failed')
    local tokens={};for i=1,size do tokens[i]='Absent'..i..'-OtherRealm'end
    tokens[10]="Fro-Zul'jin"
    local ok,name=g:ImportAndSaveNote('Name:Small Raid\ninvitelist:'..table.concat(tokens,',')..';',1)
    check(ok,name or 'Saved import failed')
    local saved=copy(h.env.RaidArsenalDB.raidGroupLayouts.items[name])
    local s=g:GetState();local oldFro=s.view.groups[2][5]
    check(g:Move(oldFro,nil,nil),'Absent Fro could not be moved to tray')
    check(g:Move(idFor(g:GetState(),h.roster[1].guid),1,5),'Qtpantts target failed')
    h.roster[2]={guid='Player-1-000002',name='Fro',realm='Zuljin',group=1,online=online}
    check(g:RefreshRoster(),'Fresh late join failed')
    local state=g:GetState();local liveFro=idFor(state,h.roster[2].guid)
    check(liveFro==oldFro,'Late join generated a duplicate instead of binding exact full identity')
    check(g:Move(liveFro,2,5),'Fro target failed')
    local p=assert(g:PrepareApply())
    check(p.canApply and p.changedCount==1 and p.operationCount==1 and #p.missing==size-1,'Absent template or redundant Fro blocked valid current targets')
    check(p.targets[h.roster[1].guid]==1 and p.targets[h.roster[2].guid]==2,'Small raid target inferred incorrectly')
    check(represented(g:GetState())==size+1,'Template identity was lost')
    local count=0;for _,row in pairs(g:GetState().view.entries)do if row.guid==h.roster[2].guid then count=count+1;check(row.offline==not online,'Offline late join metadata lost')end end
    check(count==1,'Duplicate current Fro remains visible')
    check(same(saved,h.env.RaidArsenalDB.raidGroupLayouts.items[name]),'Planning silently rewrote saved template')
    check(#h.calls==0 and #h.timers==0,'Planning acted on raid')
    check(g:Reconcile() and g:PrepareApply().changedCount==1,'Reconcile lost the planned target')
    check(g:SaveLayout(name) and g:LoadLayout(name) and g:PrepareApply().changedCount==1,'Saved/reloaded small raid failed')
    local ok,why=h:start();check(ok,why);h:complete()
    check(h:member('Player-1-000002').group==2,'Small raid ACK applied wrong identity')
    return h,g
end
for _,size in ipairs({20,40})do for _,online in ipairs({true,false})do small(size,online)end end
-- An organized raid with only one current player may apply a template target.
local h=fresh(1);local g=h.groups;check(g:Open(),'Solo organized raid failed')
local names={};for i=1,40 do names[i]='Absent'..i..'-OtherRealm'end;names[6]='Raider01-TestRealm'
check(g:ImportNote('invitelist:'..table.concat(names,',')..';',1),'One-player template failed')
local p=assert(g:PrepareApply());check(p.canApply and p.changedCount==1 and #p.missing==39,'One-player Apply blocked by absent template')
check(h:start(),'One-player Apply failed');h:complete()
-- An unresolved TRAY card contributes no target. Keep it as unused data while
-- two distinct current full identities remain explicitly covered.
h=fresh(2);g=h.groups;h.roster[1].name='Twin';h.roster[1].realm='Illidan';h.roster[2].name='Twin';h.roster[2].realm='Thrall'
check(g:Open() and g:ImportNote('invitelist:Twin-Illidan,Twin,,,,Twin-Thrall;',1),'Ambiguous fixture failed')
local s=g:GetState();local short=s.view.groups[1][2]
local blocked,why=g:PrepareApply();check(not blocked and why:find('Match Twin',1,true),'Ambiguous GROUP target silently guessed')
check(g:Move(short,nil,nil),'Could not retain unused tray placeholder')
p=assert(g:PrepareApply());check(p.canApply and #p.unusedPlaceholders==1 and #p.missing==0,'Unused tray ambiguity blocked complete GUID targets or was called absent')
check(g:GetState().view.entries[short].unusedPlaceholder,'Unused tray disclosure missing')
local first=idFor(g:GetState(),h.roster[1].guid);check(g:Move(first,nil,nil),'Current player tray fixture failed')
blocked,why=g:PrepareApply();check(not blocked and why:find('Twin-Illidan',1,true) and why:find('needs a target',1,true),'Real unassigned current GUID was ignored')
-- Create a dynamic unbound duplicate through public edits: bind another
-- absent card after a late join. Competing groups block with a named reason;
-- moving the redundant card to tray safely coalesces it instead.
h=fresh(1);g=h.groups;check(g:Open(),'Duplicate fixture open failed')
check(g:ImportNote('invitelist:Joined-OtherRealm,,,,,Other-OtherRealm;',1),'Duplicate import failed')
s=g:GetState();local original=s.view.groups[1][1];local other=s.view.groups[2][1]
h.roster[2]={guid='Player-1-000002',name='Joined',realm='OtherRealm',group=1,online=false};check(g:RefreshRoster(),'Duplicate late join failed')
check(g:ResolveEntry(other,h.roster[2].guid),'Explicit duplicate mapping fixture failed')
blocked,why=g:PrepareApply();check(not blocked and why:find('Joined-OtherRealm',1,true) and why:find('Multiple group targets',1,true),'Conflicting current group targets were silently chosen')
check(g:Move(other,nil,nil),'Redundant card could not move to tray')
s=g:GetState();check(s.view.entries[other]==nil and s.view.entries[original].guid==h.roster[2].guid and s.view.mergedTrayDuplicates==1,'Dynamic unbound tray duplicate did not coalesce by unique fresh full identity')
check(g:Reconcile(),'Reconcile rejected redundant tray duplicate')
check(g:SaveLayout('Coalesced'),'Canonical duplicate save failed')
check(g:LoadLayout('Coalesced') and represented(g:GetState())==2,'Saved canonical layout lost present/absent identities')
check(#h.calls==0,'Duplicate repair caused live group action')
print('PASS: '..checks..' small-raid/late-join/unused-tray assertions (offline; native ACK acceptance pending)')
]=]
assert(loadstring(source))()
