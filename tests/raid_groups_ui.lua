-- Real pane + Config toolkit + RaidGroups core. Fictional roster/ACK APIs.
-- Does not establish native WoW rendering, restricted API or taint acceptance.
local checks=0
local function check(value,message)checks=checks+1;assert(value,message)end
local function read(path)local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local setup=read('tests/setup_placement.lua')
local boundary=assert(setup:find('\nlocal h=Lifecycle();local RA=h.RA',1,true))
local Lifecycle=assert(loadstring(setup:sub(1,boundary-1)..'\nreturn Lifecycle'))()
local h=Lifecycle();local RA,env=h.RA,h.env
local kit
local original=RA.CreateHubPanes
RA.CreateHubPanes=function(self,panes,provided)kit=provided;return original(self,panes,provided)end
RA:OpenConfig('GENERAL');check(kit~=nil,'Config toolkit unavailable')
local pane=env.CreateFrame('Frame',nil,RA.ConfigFrame);pane:SetSize(950,660);pane:Hide()
local reads,actions,visibleCalls,getters=0,{},0,0
local leader,unreadable,pending,combat=true,false,false,false
local roster={}
for i=1,40 do roster[i]={guid=('Player-1-%06x'):format(i),name=('Raider%02d'):format(i),realm='TestRealm',group=math.floor((i-1)/5)+1,online=true}end
roster[1].name='Twin';roster[1].realm='AlphaRealm'
roster[6].name='Twin';roster[6].realm='BetaRealm';roster[6].online=false
local function member(unit)local i=tonumber((unit or ''):match('^raid(%d+)$'));return i and roster[i]end
env.LE_PARTY_CATEGORY_HOME=1;env.LE_PARTY_CATEGORY_INSTANCE=2
env.IsInRaid=function()reads=reads+1;return true end
env.IsInGroup=function()reads=reads+1;return false end
env.GetNumGroupMembers=function()reads=reads+1;return #roster end
env.GetRaidRosterInfo=function(i)
    reads=reads+1;local r=roster[i]
    return r.name..'-'..r.realm,0,r.group,70,'Warrior','WARRIOR','Zone',r.online
end
env.UnitFullName=function(unit)reads=reads+1;local r=member(unit);if r then return r.name,r.realm end end
env.UnitGUID=function(unit)reads=reads+1;local r=member(unit);return r and not unreadable and r.guid or nil end
env.UnitAffectingCombat=function()reads=reads+1;return combat end
env.InCombatLockdown=function()reads=reads+1;return combat end
env.UnitIsGroupLeader=function()reads=reads+1;return leader end
env.UnitIsGroupAssistant=function()reads=reads+1;return false end
env.IsEncounterInProgress=function()reads=reads+1;return false end
RA.RaidLeaderToolbox.IsGroupOperationPending=function()return pending end
RA.RaidLeaderToolbox.IsSorting=function()return false end
env.SetRaidSubgroup=function(i,g)actions[#actions+1]={kind='move',i=i,g=g}end
env.SwapRaidSubgroup=function(i,j)actions[#actions+1]={kind='swap',i=i,j=j}end
for _,name in ipairs({'InviteUnit','UninviteUnit','ConvertToRaid','SendChatMessage','SetPartyAssignment','PromoteToAssistant'})do
    env[name]=function()error('Forbidden side effect: '..name)end
end
env.RAID_CLASS_COLORS={WARRIOR={r=.78,g=.61,b=.43}}
h.methods.AddLine=function(self,text)self.lines=self.lines or {};self.lines[#self.lines+1]=text end
local mouseOver,focus={},{}
env.MouseIsOver=function(frame)check(frame~=nil,'MouseIsOver received nil frame');return mouseOver[frame]==true end
env.GetMouseFoci=function()return focus end
local corePath=arg[1]or'RCPArsenal/RaidGroups.lua'
assert(env.loadfile(corePath))('RCPArsenal',RA)
local core=RA.RaidGroups
local getState,setVisible=core.GetState,core.SetVisible
core.GetState=function(self,...)getters=getters+1;return getState(self,...)end
core.SetVisible=function(self,...)visibleCalls=visibleCalls+1;return setVisible(self,...)end
local beforeTimers=#h.timers
assert(env.loadfile('RCPArsenal/RaidGroupsUI.lua'))('RCPArsenal',RA)
local refresh=RA:CreateRaidGroupsPane(pane,kit);local ui=pane.raidGroupsUI
check(reads==0 and getters==0 and visibleCalls==0,'Pane constructor touched core/roster')
check(env.RaidArsenalDB.raidGroupLayouts==nil and #h.timers==beforeTimers,'Pane constructor wrote saves/created timers')
for _,obj in ipairs(h.objects)do if obj.parent==pane then check(not obj.scripts.OnUpdate,'Planner installed background OnUpdate')end end
RA:FireCallback('RAID_GROUPS_CHANGED');refresh()
check(reads==0 and getters==0,'Hidden callback/getter performed work')
local function button(text)
    for _,obj in ipairs(h.objects)do if obj.kind=='Button' and obj.label and obj.label.text==text and obj:IsVisible()then return obj end end
end
local function click(text)
    local b=button(text);check(b and b:IsEnabled(),'Missing/disabled button '..text);b:Fire('OnMouseDown');b:Fire('OnClick','LeftButton');return b
end
local function card(g,s,mouse)local b=ui.slots[g][s];b:Fire('OnMouseDown');b:Fire('OnClick',mouse or'LeftButton');return b end
local function nameBox()
    for _,obj in ipairs(h.objects)do if obj.kind=='EditBox' and obj.parent==pane then return obj end end
end
local function statusContains(text)
    for _,obj in ipairs(h.objects)do if obj.kind=='FontString' and obj.parent==pane and obj.text and obj.text:find(text,1,true)then return true end end
end
pane:Show()
check(visibleCalls==1 and reads>0 and core:GetState().draft~=nil,'Visible pane failed to open/capture/init draft')
check(#actions==0 and #h.timers==beforeTimers,'Opening pane started group actions/timers')
for g=1,8 do
    check(ui.groups[g]:IsVisible() and #ui.slots[g]==5,'Missing visible group '..g)
    for s=1,5 do check(ui.slots[g][s].entryID~=nil,'Missing present card')end
    local p=ui.groups[g].points[#ui.groups[g].points]
    check(p[4]>=0 and p[4]+228<=950 and -p[5]+188<=500,'Group outside 950x660 pane')
end
check(ui.slots[1][1].detail.text:find('AlphaRealm',1,true),'First duplicate realm invisible')
check(ui.slots[2][1].detail.text:find('BetaRealm',1,true) and ui.slots[2][1].detail.text:find('Offline',1,true),'Second duplicate/offline detail invisible')
ui.slots[2][1]:Fire('OnEnter');check(env.GameTooltip.text=='Twin-BetaRealm','Tooltip lost full identity')
local first,second=ui.slots[1][1].entryID,ui.slots[2][1].entryID
card(1,1);card(2,1)
check(ui.slots[2][1].entryID==first and ui.slots[1][1].entryID==second and #actions==0,'Click move did not swap locally')
check(statusContains('2 group changes') and ui.slots[1][1].detail.text:find('G2 > G1',1,true),'Changed count/live-target group missing')
local source,target=ui.slots[2][1],ui.slots[3][1]
source:Fire('OnDragStart');focus={source};mouseOver={[target]=true};source:Fire('OnDragStop')
check(target.entryID==first and #actions==0,'Drop followed captured source instead of destination')
target:Fire('OnClick','LeftButton');check(ui.selected==nil,'Post-drag click changed selection')
card(3,1);check(ui.selected==first,'Next genuine click was swallowed');card(3,1)
-- A drop outside owned targets leaves every slot unchanged.
source=ui.slots[3][1];source:Fire('OnDragStart');mouseOver={};focus={source};source:Fire('OnDragStop')
check(ui.slots[3][1].entryID==first,'Outside drag edited draft')
nameBox():SetText('');click('SAVE');check(statusContains('name'),'Invalid Save name had no feedback')
nameBox():SetText('Boss One');click('SAVE');check(statusContains('Layout saved locally.'),'Save success hidden by preview')
check(env.RaidArsenalDB.raidGroupLayouts.items['Boss One']~=nil,'Save did not persist named layout')
local savedSlots=env.RaidArsenalDB.raidGroupLayouts.items['Boss One'].slots
click('FROM RAID');click('LOAD');ui.modalRows[1]:Fire('OnClick')
check(nameBox():GetText()=='Boss One' and ui.state.view.entries[ui.slots[3][1].entryID].fullName==savedSlots[11] and #actions==0,'Load did not restore only the selected local layout')
local items=env.RaidArsenalDB.raidGroupLayouts.items
for i=1,49 do local label='Limit '..i;items[label]={name=label,slots={},tray={}}end
nameBox():SetText('Over limit');click('SAVE');check(statusContains('50'),'Layout limit feedback hidden')
for i=1,49 do items['Limit '..i]=nil end
leader=false;click('REVIEW CHANGES')
check(not button('APPLY TO RAID'):IsEnabled() and button('REVIEW CHANGES'):IsEnabled(),'Ineligible preview stranded Review')
check(statusContains('leader or assistant'),'Missing authority reason: '..tostring(ui.state.preview and ui.state.preview.reason)..' / '..tostring(ui.message))
leader=true;pending=true;click('REVIEW CHANGES');check(not button('APPLY TO RAID'):IsEnabled(),'Pending legacy work enabled Apply')
pending=false;click('REVIEW CHANGES');check(button('APPLY TO RAID'):IsEnabled() and #actions==0,'Review did not recover current eligibility')
click('APPLY TO RAID');check(#actions==1 and button('CANCEL APPLY')~=nil,'Explicit Apply did not submit exactly one operation')
check(not button('SAVE'):IsEnabled(),'Active job allowed edits')
click('CANCEL APPLY');check(button('REVIEW RAID')~=nil and not button('REVIEW CHANGES'):IsEnabled(),'Uncertain result did not fence UI')
local revision=core:GetState().draft.revision
click('REVIEW RAID');check(ui.modalMode=='recovery' and ui.recoverConfirm:IsEnabled(),'Recovery did not display current groups')
check(ui.modalStatus.text:find('prior move may still settle',1,true),'Recovery uncertainty warning missing')
check(ui.listChild:GetHeight()==40*34,'Recovery did not give each raider a scrollable row')
for _,member in ipairs(roster)do
    local label='Group '..member.group..' · '..member.name..'-'..member.realm
    local found=0
    for _,row in ipairs(ui.modalRows)do if row:IsShown() and row.item.label==label then found=found+1 end end
    check(found==1,'Recovery omitted/combined a full identity: '..label)
end
-- Fingerprint race must retain fence and require another observed review.
roster[1].group,roster[6].group=roster[6].group,roster[1].group
click('ACKNOWLEDGE GROUPS');check(ui.modalMode=='recovery' and ui.modalStatus.text:find('changed',1,true),'Recovery accepted changed observed fingerprint')
ui.modal:Fire('OnKeyDown','ESCAPE');click('REVIEW RAID');click('ACKNOWLEDGE GROUPS')
check(not core:IsApplying() and core:GetState().draft.revision==revision and #actions==1,'Recovery resumed/applied/replaced draft')
check(button('REVIEW CHANGES'):IsEnabled() and not button('APPLY TO RAID'):IsEnabled(),'Recovery skipped required fresh preview or kept UI locked: '..tostring(button('REVIEW CHANGES'):IsEnabled())..' / '..tostring(button('APPLY TO RAID'):IsEnabled())..' / '..tostring(ui.state.preview)..' / '..tostring(ui.state.apply.recovered))
check(statusContains('draft retained'),'Recovery acknowledgement hidden')
click('LOAD');check(not ui.recoverConfirm:IsShown(),'Recovery control leaked into another modal')
ui.modal:Fire('OnKeyDown','ESCAPE');check(not ui.modal:IsShown() and ui.modal.keyboard==false,'Modal Escape/keyboard cleanup failed')
-- No current fingerprint/identity data means no acknowledgement route.
local uncertainGetter=core.GetState
core.GetState=function(self)local state=uncertainGetter(self);state.apply={status='stopped',unknownResult=true};return state end
unreadable=true;refresh();click('REVIEW RAID')
check(not ui.modal:IsShown() and statusContains('unavailable'),'Missing metadata opened an actionable recovery')
unreadable=false;core.GetState=uncertainGetter;core:RefreshRoster();refresh()
-- Save feedback must survive a completed prior job as well.
local oldGetter=core.GetState
core.GetState=function(self)local state=oldGetter(self);state.apply={status='complete',confirmed=1,total=1};return state end
nameBox():SetText('Boss Two');click('SAVE');check(statusContains('Layout saved locally.'),'Complete status hid Save success')
nameBox():SetText('');click('SAVE');check(statusContains('name'),'Complete status hid Save failure')
core.GetState=oldGetter
-- Import requires explicit section selection and remains local.
click('IMPORT WOWUTILS');ui.paste:SetText('EncounterID:122;Difficulty:Heroic;Name:Stale Section\ninvitelist:Twin-AlphaRealm;')
ui.paste:Fire('OnTextChanged');click('READ SECTIONS')
check(not ui.paste:HasFocus(),'Reading sections retained hidden paste focus')
local importRevision=core:GetState().draft.revision
ui.paste:SetText('EncounterID:123;Difficulty:Heroic;Name:Changed Section\ninvitelist:Twin-BetaRealm;');ui.paste:Fire('OnTextChanged')
ui.modalRows[1]:Fire('OnClick')
check(not ui.importConfirm:IsEnabled(),'Retained section callback re-enabled changed paste')
ui.importConfirm:Fire('OnClick','LeftButton')
check(core:GetState().draft.revision==importRevision and #actions==1 and ui.modal:IsShown(),'Stale import changed draft or closed recovery route')
ui.modal:Fire('OnKeyDown','ESCAPE')
click('IMPORT WOWUTILS');ui.paste:SetText('EncounterID:123;Difficulty:Heroic;Name:Boss Import\ninvitelist:Future-TestRealm,,Twin-AlphaRealm;')
ui.paste:Fire('OnTextChanged');click('READ SECTIONS')
check(not ui.importConfirm:IsEnabled() and #actions==1,'Parsing imported/applied without explicit choice')
check(ui.modalRows[1]:IsShown(),'Parsed section missing');ui.modalRows[1]:Fire('OnClick');click('IMPORT DRAFT')
check(nameBox():GetText()=='Boss Import' and #actions==1,'Import did not update only named local draft')
local imported=core:GetState();local futureID=imported.view.groups[1][1]
check(imported.view.entries[futureID].missing,'Absent planned card vanished')
-- Explicit exact reconciliation maps a joining planned player without replacing slots.
table.remove(roster,40);roster[#roster+1]={guid='Player-1-0000ff',name='Future',realm='TestRealm',group=8,online=true}
click('UPDATE RAID');local reconciled=core:GetState()
check(reconciled.view.groups[1][1]==futureID and reconciled.view.entries[futureID].guid=='Player-1-0000ff','Update raid replaced staged slots or failed exact joining match')
check(#actions==1,'Reconciliation changed live groups')
local ghost
for id,entry in pairs(reconciled.view.entries)do if entry.missing then ghost=id;break end end
check(ghost~=nil,'Removed current raider did not remain an absent card')
local ghostButton
for _,row in ipairs(ui.tray)do if row.entryID==ghost then ghostButton=row;break end end
for g=1,8 do for s=1,5 do if ui.slots[g][s].entryID==ghost then ghostButton=ui.slots[g][s]end end end
check(ghostButton~=nil,'Absent card invisible');ghostButton:Fire('OnMouseDown');ghostButton:Fire('OnClick','RightButton')
check(ui.modalMode=='resolve','Absent card options unreachable')
click('REMOVE ABSENT CARD');check(not core:GetState().view.entries[ghost] and #actions==1,'Absent removal affected current raid')
-- Long paste/section lists stay within scrollable bounds and clear focus.
click('IMPORT WOWUTILS');ui.paste:SetText(string.rep('x\n',1000));ui.paste:Fire('OnTextChanged')
check(ui.paste:GetHeight()>320 and ui.paste:GetHeight()<=16000,'Long paste escaped scroll bound')
ui.paste:Fire('OnCursorChanged',0,-800,1,14);check(ui.pasteScroll:GetVerticalScroll()>0,'Paste cursor failed to scroll into view')
ui.paste:Fire('OnEscapePressed');check(not ui.paste:HasFocus() and not ui.modal:IsShown(),'Paste Escape retained keyboard focus')
-- Plain text errors are escaped before reaching a rendered region.
local save=core.SaveLayout;core.SaveLayout=function()return false,'Invalid |Hplayer:Evil|hlink|h' end
click('SAVE');check(statusContains('||Hplayer:Evil||hlink||h'),'Dynamic status rendered executable markup');core.SaveLayout=save
pane:Hide();local hiddenReads,hiddenGetters=reads,getters
RA:FireCallback('RAID_GROUPS_CHANGED');refresh()
check(reads==hiddenReads and getters==hiddenGetters and not ui.active,'Hidden pane refreshed/reopened core')
check(core:GetState().draft~=nil and not ui.modal:IsShown() and ui.selected==nil and ui.dragging==nil,'Hide discarded draft or retained interactive state')
check(#actions==1,'Local editor made unexpected game actions')
print(('raid_groups_ui.lua: %d assertions passed'):format(checks))
