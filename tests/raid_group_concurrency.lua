-- Actual Core/RaidLeader with the shared UI fixture; native group APIs mocked.
-- Exercises the isolated legacy busy boundary, then both actual controllers.
local f=assert(io.open('tests/hub.lua'));local source=f:read('*a');f:close()
source=source:sub(1,assert(source:find("event('ADDON_LOADED','RCPArsenal')",1,true))-1)
source=source..[=[
RaidArsenalDB={profile={schemaVersion=19}}
event('ADDON_LOADED','RCPArsenal')
local raid={{name='Aster',guid='Player-1-AA',group=2},{name='Birch',guid='Player-1-BB',group=2},{name='Cedar',guid='Player-1-CC',group=1}}
local class='DRUID'
local function row(unit)return raid[tonumber((unit or ''):match('^raid(%d+)$')) or (unit=='player' and 1 or 0)]end
IsInRaid=function()return true end;IsInGroup=function()return true end
GetNumGroupMembers=function()return #raid end
UnitExists=function(unit)return row(unit)~=nil end
UnitIsPlayer=UnitExists
UnitFullName=function(unit)local r=row(unit);if r then return r.name,'Realm'end end
UnitGUID=function(unit)local r=row(unit);return r and r.guid end
UnitClass=function(unit)if row(unit)then return class,class end end
UnitGroupRolesAssigned=function()return 'DAMAGER'end
UnitIsUnit=function(a,b)return a==b end
UnitIsGroupLeader=function(unit)return unit=='player'end
UnitIsGroupAssistant=function()return false end
GetRaidRosterInfo=function(i)local r=raid[i];return r.name..'-Realm',i==1 and 2 or 0,r.group,80,class,class,nil,true end
RA.GetInspectionUnitName=function(_,unit)local r=row(unit);return r and r.name..'-Realm'end
RA.RefreshRoster=function()end
RA.IsInspectionEnabled=function()return true end
RA.IsInspectionRunning=function()return true end
local scanRequests,moves,changes=0,{},0
RA.RequestInspectionScan=function()scanRequests=scanRequests+1;return true end
SetRaidSubgroup=function(index,group)moves[#moves+1]={'move',raid[index].guid,group}end
SwapRaidSubgroup=function(a,b)moves[#moves+1]={'swap',raid[a].guid,raid[b].guid}end
local realGroups=RA.RaidGroups
local applying=false
RA.RaidGroups={IsApplying=function()return applying end}
local toolbox=RA.RaidLeaderToolbox
RA:RegisterCallback('RAID_GROUP_OPERATION_CHANGED',function()changes=changes+1 end)
RA:SetQuickBarEnabled(true)
check(not toolbox:IsSorting() and not toolbox:IsGroupOperationPending(),'Fresh group job guard is busy')
toolbox:SortByRole()
check(scanRequests==1 and not toolbox:IsSorting() and toolbox:IsGroupOperationPending() and #moves==0,'Unknown roles did not enter observational pending state')
local sortButton,panel
for _,o in ipairs(objects)do
 if o.__surfaceKey=='sortButton'then sortButton=o end
 if o.cancel and o.run and o.undo then panel=o end
end
check(sortButton and panel,'Actual sort controls missing')
sortButton:Fire('OnClick','RightButton')
check(panel:IsShown() and panel.cancel:IsShown(),'Pending sort has no visible Cancel')
panel.cancel:Fire('OnClick')
check(not toolbox:IsGroupOperationPending() and not toolbox:IsSorting(),'Pending Cancel retained its job')
class='MAGE'
RA:FireCallback('REPORTS_UPDATED');RA.IsInspectionRunning=function()return false end;RA:FireCallback('INSPECTION_STATE_CHANGED')
check(#moves==0 and not toolbox:IsGroupOperationPending(),'Cancelled pending sort resumed after late inspection')
-- Planner blocks public and native UI entry points without native submissions.
applying=true;RA:FireCallback('RAID_GROUPS_CHANGED')
local count=#moves
for _,method in ipairs({'SortByRole','SplitOddEven','SplitAdjacent'})do toolbox[method](toolbox)end
panel.undo:Fire('OnClick')
check(#moves==count and not toolbox:IsGroupOperationPending(),'Planner busy allowed Sort/Split/Undo native operations')
check(not sortButton:IsEnabled(),'Planner busy did not disable the actual sort control')
applying=false;RA:FireCallback('RAID_GROUPS_CHANGED');check(sortButton:IsEnabled(),'Sort control did not recover after planner job')
-- A pending legacy request cannot resume into an external planner fence.
class='DRUID';RA.IsInspectionRunning=function()return true end;toolbox:SortByRole()
check(toolbox:IsGroupOperationPending(),'Second pending fixture failed')
applying=true;class='MAGE';RA:FireCallback('REPORTS_UPDATED')
check(not toolbox:IsGroupOperationPending() and #moves==count,'Pending report callback bypassed planner busy guard')
applying=false;RA:FireCallback('REPORTS_UPDATED');RA.IsInspectionRunning=function()return false end;RA:FireCallback('INSPECTION_STATE_CHANGED')
check(#moves==count and not toolbox:IsGroupOperationPending(),'Blocked pending mode resumed after planner finished')
-- Active jobs also advertise busy and remain cancellable.
toolbox:SortByRole();check(toolbox:IsSorting() and toolbox:IsGroupOperationPending() and #moves==count+1,'Known sort did not start one native request')
check(toolbox:CancelGroupOperation() and not toolbox:IsGroupOperationPending(),'Active Cancel failed')
local afterCancel=#moves
for _,t in ipairs(timers)do if t.delay==1.25 and not t.cancelled then t.callback()end end
check(#moves==afterCancel,'Cancelled active job timer submitted another operation')
-- Defensive next-step fence before a delayed roster ACK can submit a second move.
toolbox:SortByRole();local activeCount=#moves;check(toolbox:IsSorting(),'ACK fixture did not start')
local operation=moves[#moves];for _,r in ipairs(raid)do if r.guid==operation[2]then r.group=operation[3]end end
local beforeTimers=#timers
applying=true
event('GROUP_ROSTER_UPDATE')
for i=beforeTimers+1,#timers do local t=timers[i];if t.delay==0.04 and not t.cancelled then t.callback()end end
check(#moves==activeCount and not toolbox:IsSorting(),'Delayed legacy step competed with planner Apply')
applying=false
-- Profile context resets must not strand a pending job behind the shared guard.
class='DRUID';RA.IsInspectionRunning=function()return true end;toolbox:SortByRole();check(toolbox:IsGroupOperationPending(),'Reset pending fixture failed')
RA:FireCallback('PROFILE_RESET')
check(not toolbox:IsGroupOperationPending(),'Profile reset stranded pending legacy sort')
check(changes>=6,'Group job transitions did not notify observers')
-- Route intent is separate from the legacy /rcp raid addon-version shortcut.
SlashCmdList.RCPARSENAL('groups')
check(RaidArsenalDB.navigation.lastTab=='RAIDGROUPS','New groups route did not select its ordinary page')
RA:CloseConfig();SlashCmdList.RCPARSENAL('')
check(RaidArsenalDB.navigation.lastTab=='RAIDGROUPS','Groups last destination did not survive neutral reopen')
SlashCmdList.RCPARSENAL('raid')
check(RaidArsenalDB.navigation.lastTab=='ADDONS','Legacy raid shortcut no longer opens addon versions')
-- The actual new controller admits Apply only after pending legacy Cancel.
check(realGroups~=nil,'Actual RaidGroups module is missing from TOC')
RA.RaidGroups=realGroups
LE_PARTY_CATEGORY_HOME,LE_PARTY_CATEGORY_INSTANCE=1,2
IsInRaid=function()return true end
IsInGroup=function(category)return category~=LE_PARTY_CATEGORY_INSTANCE end
IsEncounterInProgress=function()return false end
UnitAffectingCombat=function()return false end
GetNormalizedRealmName=function()return 'Realm'end
RA.InEncounter=false
local g=RA.RaidGroups
class='DRUID';RA.IsInspectionRunning=function()return true end
toolbox:SortByRole();check(toolbox:IsGroupOperationPending(),'Actual model pending fixture failed')
local nativeCount=#moves
check(g:Open() and g:FromCurrentRaid(),'Actual planner could not capture local draft')
local function entry(guid)for id,e in pairs(g:GetState().view.entries)do if e.guid==guid then return id end end end
local birch=entry('Player-1-BB');check(birch and g:Move(birch,3,1),'Actual local group move failed')
local preview,why=g:PrepareApply();check(preview~=nil,why or 'Pending preview missing')
check(preview.canApply==false and not g:Apply(preview.id) and #moves==nativeCount,'Planner submitted over a pending legacy sort')
sortButton:Fire('OnClick','RightButton');check(panel.cancel:IsShown(),'Pending Cancel disappeared while planner observed')
panel.cancel:Fire('OnClick')
check(not toolbox:IsGroupOperationPending() and g:GetState().live.canApply==true,'Pending Cancel failed to refresh actual planner eligibility')
local ok,p=g:PrepareApply();check(ok and ok.canApply,'Actual planner did not become eligible after Cancel')
preview=ok
check(g:Apply(preview.id) and g:IsApplying() and #moves==nativeCount+1,'Explicit actual Apply failed after pending Cancel')
local submits=#moves;local scanCount=scanRequests
for _,method in ipairs({'SortByRole','SplitOddEven','SplitAdjacent'})do toolbox[method](toolbox)end
RA:FireCallback('REPORTS_UPDATED');RA:FireCallback('INSPECTION_STATE_CHANGED')
check(#moves==submits and scanRequests==scanCount and not toolbox:IsGroupOperationPending(),'Legacy operation competed with actual planner Apply')
local op=moves[#moves];check(op[1]=='move','Expected one vacant-group move')
for _,r in ipairs(raid)do if r.guid==op[2]then r.group=op[3]end end
event('GROUP_ROSTER_UPDATE')
check(not g:IsApplying() and g:GetState().apply.status=='complete' and #moves==submits,'Actual ACK did not complete the one submitted move')
-- A stopped unknown result fences legacy jobs; deliberate recovery preserves
-- the draft and never submits/resumes, even when the last request had no effect.
local aster=entry('Player-1-AA');check(g:Move(aster,4,1),'Recovery draft edit failed')
preview=assert(g:PrepareApply());check(g:Apply(preview.id),'Unknown-result job did not start')
local oldMove=moves[#moves];submits=#moves
check(g:CancelApply() and g:IsApplying(),'Cancelled unacknowledged result did not fence other jobs')
toolbox:SortByRole();check(#moves==submits and scanRequests==scanCount and not toolbox:IsGroupOperationPending(),'Unresolved actual planner result did not block legacy sorting')
check(g:RefreshRoster(),'Fresh unchanged roster unavailable for recovery')
local state=g:GetState();local revision=state.draft.revision
check(g:RecoverStopped(state.live.fingerprint) and not g:IsApplying(),'Explicit known-roster recovery failed')
check(#moves==submits and g:GetState().draft.revision==revision and not g:GetState().preview,'Recovery submitted/resumed or replaced staged edits')
check(g:Move(aster,5,1),'Post-recovery deliberate draft edit failed')
preview=assert(g:PrepareApply());check(g:Apply(preview.id),'Fresh explicit Apply after recovery failed')
submits=#moves
for _,r in ipairs(raid)do if r.guid==oldMove[2]then r.group=oldMove[3]end end
event('GROUP_ROSTER_UPDATE')
check(g:GetState().apply.status=='stopped' and #moves==submits,'Late conflicting prior result failed to stop a new job')
g:Close()
RA:OpenConfig('RAIDGROUPS');check(g:GetState().open,'Actual Config route did not activate planner observation')
RA:CloseConfig('CONTEXT');check(not g:GetState().open,'Ancestor window hide retained planner observation')
RA:OpenConfig();check(g:GetState().open,'Neutral reopen did not restore planner visibility lifecycle')
RA:CloseConfig();check(not g:GetState().open,'User window close retained planner observation')
-- The actual shared classifier reads only verified same-identity local facts.
local function kind(role,className)
 return toolbox:GetDraftMemberKind({role=role,class=className,fullName='Aster-Realm',guid='Player-1-AA'})
end
local scansBefore=#moves;local requestsBefore=scanRequests
check(kind('TANK','DRUID')=='TANK' and kind('HEALER','DRUID')=='HEALER','Assigned tank/healer role not classified')
check(kind('DAMAGER','MAGE')=='RANGED' and kind('DAMAGER','WARRIOR')=='MELEE','Safe damage-class fallback changed')
for _,className in ipairs({'DRUID','SHAMAN','HUNTER','DEMONHUNTER'})do check(kind('DAMAGER',className)==nil,'Ambiguous damage class guessed')end
local usable=RA.IsReportUsable
RA.IsReportUsable=function(_,report,info)check(info.role=='DAMAGER' and info.guid=='Player-1-AA','Classifier supplied stale role/GUID');return report.role=='DAMAGER'end
RA.Reports={['Aster-Realm']={verified=true,name='Aster-Realm',guid='Player-1-AA',class='DEMONHUNTER',role='DAMAGER',specID=1480,cached=true,source='PERSISTED_CACHE'}}
local resolved,fromCache=kind('DAMAGER','DEMONHUNTER');check(resolved=='RANGED' and fromCache,'Validated Devourer/cache provenance lost')
RA.Reports['Aster-Realm'].role='HEALER';check(kind('DAMAGER','DEMONHUNTER')==nil,'Conflicting cached role classified')
RA.Reports['Aster-Realm'].role='DAMAGER';RA.Reports['Aster-Realm'].source='DEMO';check(kind('DAMAGER','DEMONHUNTER')==nil,'Demo report used by draft sorter')
RA.Reports['Aster-Realm'].source='PERSISTED_CACHE';RA.Reports['Aster-Realm'].guid='Player-1-BB';check(kind('DAMAGER','DEMONHUNTER')==nil,'Wrong GUID report classified')
RA.IsReportUsable=usable
check(#moves==scansBefore and scanRequests==requestsBefore,'Pure classifier started native sorting/inspection')
print=nativePrint
print('PASS: '..checks..' shared raid-group controller/routing assertions (actual planner and legacy controllers; offline native APIs)')
]=]
assert(loadstring(source))()
