-- Actual Catalog/Readiness/HubUI modules; native frame and addon APIs are mocked.
-- Checks matrix decisions and action boundaries, not glyph rendering or taint.
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function noop() end
local clock,combat=100,false
local objects,timers,events,callbacks,initializers,sent={},{},{},{},{},{}
local opened,renderCount={},0
local methods={}
function methods:SetText(value) self.text=value;if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self,false) end end
function methods:GetText() return self.text end
function methods:GetObjectType() return self.kind end
function methods:SetScript(event,fn) self.scripts[event]=fn end
function methods:HookScript(event,fn) local previous=self.scripts[event];self.scripts[event]=function(...) if previous then previous(...) end;fn(...) end end
function methods:Fire(event,...) if self.scripts[event] then self.scripts[event](self,...) end end
function methods:Show() local changed=not self.shown;self.shown=true;if changed then self:Fire('OnShow') end end
function methods:Hide() local changed=self.shown;self.shown=false;if changed then self:Fire('OnHide') end end
function methods:SetShown(value) if value then self:Show() else self:Hide() end end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetSize(w,h) self.width,self.height=w,h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:SetPoint(...) self.point={...} end
function methods:SetAllPoints(parent) self.allPoints=parent end
function methods:SetFrameLevel(level) self.level=level end
function methods:GetFrameLevel() return self.level or 0 end
function methods:SetScrollChild(child) self.child=child end
function methods:SetEnabled(value) self.enabled=value end
function methods:SetAlpha(value) self.alpha=value end
function methods:SetTextColor(...) self.color={...} end
function methods:SetSelected(value) self.selected=value end
function methods:SetFocus() self.focus=true end
function methods:ClearFocus() self.focus=false end
function methods:HasFocus() return self.focus==true end
function methods:SetWordWrap(value) self.wrap=value end
local mt={__index=function(_,key)
    if methods[key] then return methods[key] end
    if key:match('^Set') or key=='EnableMouse' or key=='HighlightText' then return noop end
end}
local function Object(kind,parent)
    local object=setmetatable({kind=kind,parent=parent,shown=true,scripts={}},mt)
    objects[#objects+1]=object;return object
end
function CreateFrame(kind,_,parent) return Object(kind,parent) end
function GetTime() return clock end
function time() return 1800000000+clock end
function InCombatLockdown() return combat end
function IsEncounterInProgress() return false end
function issecretvalue() return false end
local units={player={name='Lead',guid='Player-1',online=true,leader=true},party1={name='Raider',guid='Player-2',online=true},party2={name='Offline',guid='Player-3',online=false}}
function UnitFullName(unit) local row=units[unit];if row then return row.name,'Realm' end end
function UnitGUID(unit) return units[unit] and units[unit].guid end
function UnitIsConnected(unit) return units[unit] and units[unit].online end
function UnitIsGroupLeader(unit) return units[unit] and units[unit].leader==true end
function UnitIsGroupAssistant() return false end
function IsInRaid() return false end
function IsInGroup() return true end
function GetNumSubgroupMembers() return 2 end
function GetNormalizedRealmName() return 'Realm' end
function NotifyInspect() error('table initiated talent inspection') end
function SendChatMessage() error('table sent gameplay chat') end
function EnableAddOn() error('table enabled addon') end
function LoadAddOn() error('table loaded addon') end
local function Timer(delay,fn)
    local timer={delay=delay,fn=fn};function timer:Cancel() self.cancelled=true end
    timers[#timers+1]=timer;return timer
end
C_Timer={NewTimer=Timer,NewTicker=function(delay,fn) local timer=Timer(delay,fn);timer.ticker=true;return timer end}
C_ChatInfo={RegisterAddonMessagePrefix=function() return 0 end,SendAddonMessage=function(prefix,message,channel,target) sent[#sent+1]={message=message,channel=channel,target=target};return 0 end}
local installed={{name='NorthernSkyRaidTools',version='1.2.3',enabled=2,loaded=true},{name='RCLootCouncil',version='1.2.3',enabled=0,loaded=true},
    {name='Simulationcraft',version='@project-version@',enabled=2,loaded=false},{name='wowutils',version='1.2.3',enabled=2,loaded=true},{name='BigWigs',version='v400-alpha',enabled=2,loaded=true}}
local function Find(folder) for _,row in ipairs(installed) do if row.name==folder then return row end end end
C_AddOns={GetNumAddOns=function() return #installed end,GetAddOnInfo=function(index) return installed[index].name end,
    GetAddOnEnableState=function(folder,guid) check(guid=='Player-1','wrong metadata character');return folder=='RCPArsenal' and 2 or Find(folder).enabled end,
    IsAddOnLoaded=function(folder) local value=Find(folder).loaded;return value,value end,GetAddOnMetadata=function(folder) return Find(folder).version end}
local RA={ADDON_NAME='RCPArsenal',VERSION='0.15.2-alpha.3',BUILD='0.15.2-alpha.3',READINESS_PROTOCOL=1}
local db={readiness={targets={northernsky='1.2.3',rclootcouncil='1.2.3',simulationcraft='12.1.0-01',wowutils='1.2.3'},revision=0,updatedAt=0,origin=''},
    personalTools={autoRes=false,consumableReminder=false,healthThreshold=40},hudEnabled=false,leaderToolbox={enabled=false},worldMarkers={enabled=false}}
function RA:GetDB() return db end
function RA:RegisterInitializer(fn) initializers[#initializers+1]=fn end
function RA:RegisterEvent(name,fn) events[name]=events[name] or {};table.insert(events[name],fn) end
function RA:RegisterCallback(name,fn) callbacks[name]=callbacks[name] or {};table.insert(callbacks[name],fn) end
function RA:FireCallback(name,...) for _,fn in ipairs(callbacks[name] or {}) do fn(...) end end
function RA:ApplyFont() end
function RA:Print() end
function RA:OpenConfig(key) opened[#opened+1]=key end
function RA:OpenProfileDialog() end
function RA:GetSlashCommandStatus() return '' end
function RA:CreateNorthernSkyPane() return noop end
RA.PersonalTools={StopReminderPreview=noop,GetStatusText=function() return 'Off' end}
local colors={text={1,1,1},textSoft={.7,.7,.7},muted={.4,.4,.4},orange={1,.5,0},magenta={1,0,1},surface={0,0,0},line={.1,.1,.1},lineStrong={.2,.2,.2},input={.1,.1,.1}}
RA.Theme={Colors=colors,SetPoint=function(frame,...) frame:SetPoint(...) end,SetSize=function(frame,...) frame:SetSize(...) end,
    SetWidth=function(frame,value) frame:SetWidth(value) end,SetHeight=function(frame,value) frame:SetHeight(value) end}
RA.ConfigFrame=Object('Frame')
local panes={ADDONS=Object('Frame',RA.ConfigFrame),MYTOOLS=Object('Frame',RA.ConfigFrame),SETTINGS=Object('Frame',RA.ConfigFrame),NORTHERNSKY=Object('Frame',RA.ConfigFrame)}
for _,pane in pairs(panes) do pane:Hide() end
GameTooltip={lines={},SetOwner=noop,SetText=function(self,value) self.lines={value} end,AddLine=function(self,value) self.lines[#self.lines+1]=value end,Show=noop,Hide=noop}
for _,name in ipairs({'Assets','AddonCatalog','Readiness','HubUI'}) do assert(loadfile('RCPArsenal/'..name..'.lua'))('RCPArsenal',RA) end
for _,fn in ipairs(initializers) do fn() end
local function Font(parent) return Object('FontString',parent) end
local function Button(parent,label,width,height,fn)
    local b=Object('Button',parent);b:SetSize(width,height);b.label=Font(b);RA:SetVisualText(b.label,label);b:SetScript('OnClick',fn);return b
end
local kit={Font=Font,Button=Button,Card=function(parent,title,subtitle) local card=Object('Frame',parent);card.title=Font(card);card.subtitle=Font(card);RA:SetVisualText(card.title,title);RA:SetVisualText(card.subtitle,subtitle);return card end,
    Heading=function(parent,title,subtitle) local a,b=Font(parent),Font(parent);RA:SetVisualText(a,title);RA:SetVisualText(b,subtitle) end,
    Toggle=function(parent) return Object('Button',parent) end,Slider=function(parent) return Object('Frame',parent) end,Backdrop=noop,Refresh=noop}
local renderer=RA:CreateHubPanes(panes,kit)
local function Render() renderCount=renderCount+1;check(renderCount<300,'recursive readiness refresh');renderer('ADDONS') end
RA:RegisterCallback('READINESS_UPDATED',function() if panes.ADDONS:IsVisible() then Render() end end)
panes.ADDONS:Show();Render()
local function ButtonNamed(label)
    for _,object in ipairs(objects) do if object.kind=='Button' and object.label and object.label.text==label and object:IsVisible() then return object end end
end
local function Click(label) local button=assert(ButtonNamed(label),'missing button '..label);check(button.enabled~=false,'disabled button '..label);button:Fire('OnClick');return button end
local function Row(name)
    for _,object in ipairs(objects) do if object.cells and object.name.text==name and object:IsVisible() then return object end end
end
local function Tooltip(cell) cell:Fire('OnEnter');return table.concat(GameTooltip.lines,'\n') end
local localRow,remote,offline=assert(Row('Lead-Realm')),assert(Row('Raider-Realm')),assert(Row('Offline-Realm'))
local function Seven(row) local count=0;for _ in pairs(row.cells) do count=count+1 end;check(count==7,'not all seven addon cells exist') end
Seven(localRow);Seven(remote);Seven(offline)
check(localRow.point[5]==0 and remote.point[5]==-34,'local row is not first or compact pitch changed')
for _,entry in ipairs(RA.AddonCatalog.Entries) do
    check(remote.cells[entry.id].version.text=='Unknown' and remote.cells[entry.id].state.text=='No response','nonresponse became installed/missing')
    check(offline.cells[entry.id].state.text=='Offline','offline state lost')
end
check(localRow.cells.rclootcouncil.state.text=='Reload pending' and localRow.cells.rclootcouncil.state.color[1]==colors.orange[1],'matching disabled addon looked healthy')
check(localRow.cells.simulationcraft.version.text=='Unknown' and localRow.cells.simulationcraft.state.text=='Not loaded','loading/placeholder metadata became known loaded version')
check(localRow.cells.autopotion.state.text=='Missing','explicit local absence not shown')
check(Tooltip(localRow.cells.arsenal):find('Protocol 1',1,true),'Arsenal build/protocol missing from tooltip')
Click('Northern Sky');Seven(localRow);Seven(remote)
check(Tooltip(ButtonNamed('Northern Sky')):find('Northern Sky Raid Tools',1,true),'header tooltip lost full addon name')
check(remote.cells.arsenal:IsVisible() and localRow.cells.bigwigs:IsVisible(),'header selection filtered other addons')
local target
for _,object in ipairs(objects) do if object.kind=='EditBox' and object.width==184 then target=object end end
check(target and target.text=='1.2.3' and target.__raVisualText==nil,'target editor not raw or wrong target')
target:SetFocus();target:SetText('9.9.9-beta');target:Fire('OnTextChanged',true)
Render();check(target.text=='9.9.9-beta','readiness callback replaced focused draft')
Click('BigWigs');Click('Northern Sky');check(target.text=='9.9.9-beta','switching header discarded addon draft')
target:Fire('OnEscapePressed');check(target.text=='1.2.3','Escape did not restore saved target')
target:SetFocus();target:SetText('2.0.0-beta');target:Fire('OnTextChanged',true);Click('SAVE')
check(db.readiness.targets.northernsky=='2.0.0-beta' and target.text=='2.0.0-beta','explicit exact target save failed')
Click('CLEAR');check(db.readiness.targets.northernsky==nil and target.text=='','target clear affected wrong addon or failed')
target:SetText('1.2.3');target:Fire('OnTextChanged',true);Click('SAVE')
Click('HIDE DETAILS');Seven(localRow);check(ButtonNamed('SHOW DETAILS') and not ButtonNamed('DOWNLOAD LINK'),'details did not collapse independently')
Click('Northern Sky');check(ButtonNamed('SETUP') and not ButtonNamed('SHOW DETAILS'),'header did not reopen compact details')
Click('SETUP');check(opened[#opened]=='NORTHERNSKY','Northern Sky setup lost nested route')
Click('Arsenal');Click('PROFILES');check(opened[#opened]=='SETTINGS','Arsenal profile route lost')
Click('BigWigs');Click('DOWNLOAD LINK')
local link
for _,object in ipairs(objects) do if object.kind=='EditBox' and object.width==660 then link=object end end
check(link and link.text==RA.AddonCatalog:GetEntry('bigwigs').url and link.__raVisualText==nil,'download link missing/raw editbox retained')
Click('CLOSE')
local before=#sent;Click('REFRESH LOCAL');check(#sent==before,'local refresh queried group')
Click('CHECK GROUP VERSIONS');check(#sent==before+1,'query fanned out per addon instead of once')
local nonce=sent[#sent].message:match('^Q|1|(.+)$')
local function Hex(value) return value and value:gsub('.',function(c) return string.format('%02x',c:byte()) end) or '-' end
local function Reply(id,flags,version,build,protocol)
    local message=table.concat({'R','1',nonce,id,flags,Hex(version),Hex(build),protocol and tostring(protocol) or '-'},'|')
    for _,fn in ipairs(events.CHAT_MSG_ADDON) do fn('CHAT_MSG_ADDON',RA.Readiness.PREFIX,message,'WHISPER','Raider-Realm') end
end
Reply('arsenal','111','0.15.2','wrong-build',2)
check(remote.cells.arsenal.version.text=='Unknown','unsupported protocol was treated as known Arsenal report')
Reply('northernsky','111','1.2.2')
check(remote.cells.northernsky.state.text=='Older' and remote.cells.autopotion.state.text=='Not reported','partial report hid received facts or made unreceived missing')
Reply('arsenal','111','0.15.2','0.15.2',1)
Reply('rclootcouncil','101','1.2.3')
Reply('simulationcraft','111','12.1.0-02')
Reply('wowutils','111','1.2.4')
Reply('autopotion','000')
Reply('bigwigs','111','v400-alpha')
check(remote.cells.autopotion.state.text=='Missing' and remote.cells.rclootcouncil.state.text=='Reload pending','explicit missing/disabled report mishandled')
check(remote.cells.simulationcraft.state.text=='Different' and remote.cells.wowutils.state.text=='Newer' and remote.cells.bigwigs.state.text=='No target','version comparison semantics changed')
check(remote.response.text=='Reported' and Tooltip(remote.cells.arsenal):find('Build 0.15.2 · Protocol 1',1,true),'complete response/build not shown')
Click('USE MY ENABLED ADDON VERSIONS')
check(db.readiness.targets.rclootcouncil=='1.2.3' and db.readiness.targets.autopotion==nil and db.readiness.targets.bigwigs=='v400-alpha','capture erased disabled target or approved absent/unknown metadata')
clock=230;Render();check(Tooltip(remote.cells.northernsky):find('STALE',1,true),'old query omitted stale caveat')
local metadata
for _,object in ipairs(objects) do if object.kind=='FontString' and object.text and object.text:find('STALE · Group query',1,true) then metadata=object end end
check(metadata and metadata.__raVisualText==metadata.text,'stale banner missing independent caption')
local queries=#sent
for _,timer in ipairs(timers) do if timer.ticker and not timer.cancelled then timer.fn() end end
check(#sent==queries,'age ticker sent query')
local selectedTicker
for _,timer in ipairs(timers) do if timer.ticker and not timer.cancelled then selectedTicker=timer end end
panes.ADDONS:Hide();check(selectedTicker and selectedTicker.cancelled,'merged pane hide leaked ticker')
panes.ADDONS:Show();Render()
RA.ConfigFrame:Hide()
for _,timer in ipairs(timers) do check(not timer.ticker or timer.cancelled,'host close leaked addon-table ticker') end
check(not db.hudEnabled and not db.leaderToolbox.enabled and not db.worldMarkers.enabled,'table navigation enabled a gameplay tool')
for _,object in ipairs(objects) do
    if object.kind=='FontString' and object.text~=nil then check(object.__raVisualText==object.text,'owned label bypassed visual caption retention') end
    if object.kind=='EditBox' then check(object.__raVisualText==nil,'editable draft was retained for replay') end
end
print('addon_table: '..checks..' checks passed (offline module decisions only)')
