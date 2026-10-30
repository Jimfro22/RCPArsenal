-- Real Config/Setup/Hub modules through the existing isolated frame fixture.
-- This checks state/routing/layout bounds, not native rendering or taint.
local file=assert(io.open('tests/setup_placement.lua'));local source=file:read('*a');file:close()
source=source:sub(1,assert(source:find('local h=Lifecycle();local RA=h.RA',1,true))-1)
source=source..[[
local function prepared(saved)
    local h=Lifecycle(saved)
    h.methods.SetTextColor=function(self,...)self.textColor={...}end
    h.methods.SetJustifyH=function(self,value)self.justifyH=value end
    function h:button(prefix)
        for _,o in ipairs(self.objects)do if o.label and o.label.text:find(prefix,1,true)==1 and o:IsVisible()then return o end end
    end
    function h:disclose(prefix)local b=self:button(prefix);check(b~=nil,'Missing disclosure '..prefix);b:Fire('OnClick');return b end
    function h:control(title)
        for _,o in ipairs(self.objects)do if o.title and o.title.text==title and o:IsVisible()then return o end end
    end
    return h,h.RA
end
local function quiet(h,before)
    local after=h.metrics()
    check(after.sent==before.sent and after.inspects==before.inspects and after.talents==before.talents,'Navigation performed optional group work')
end
-- General is an immediate local settings surface, without a staged editor.
local h,RA=prepared();local before=h.metrics()
RA:OpenConfig()
check(h:visible('General') and h:control('Auto resurrection') and h:control('Consumable reminder')
    and h:control('Quick Bar') and h:control('Available Cooldowns'),'General masters missing')
check(not RA.Setup:HasDraft() and RA.Setup.Save==nil and not h:button('REVIEW CHOICES') and not h:button('RESUME REVIEW'),'Retired review remains reachable')
quiet(h,before)
local timerCount=#h.timers
h:control('Auto resurrection'):Fire('OnClick')
check(RA:GetDB().personalTools.autoRes and not RA:GetDB().personalTools.autoResInCombat and #h.timers==timerCount,'General res required Apply or replayed an offer')
h:control('Auto resurrection'):Fire('OnClick')
local scans=0;RA.ScheduleInspectionScan=function()scans=scans+1 end
h:control('Available Cooldowns'):Fire('OnClick')
check(RA:IsHUDEnabled() and scans==1,'HUD immediate activation did not use its setter')
h:control('Available Cooldowns'):Fire('OnClick')
RA:GetDB().leaderToolbox.showMissing=false
h:control('Quick Bar'):Fire('OnClick')
check(RA:GetDB().leaderToolbox.enabled and RA:GetDB().leaderToolbox.showMissing,'Quick Bar activation lost existing provider default')
RA:GetDB().leaderToolbox.showMissing=false;RA:OpenConfig('GENERAL')
check(not RA:GetDB().leaderToolbox.showMissing,'Refresh reset an enabled child choice')
h:control('Quick Bar'):Fire('OnClick')
h.setCombat(true);h:control('Available Cooldowns'):Fire('OnClick')
check(not RA:IsHUDEnabled() and h:visible('Change this after combat.'),'Rejected General setting was silent or queued')
h:control('Quick Bar'):Fire('OnClick')
check(not RA:GetDB().leaderToolbox.enabled and h:visible('Change this after combat.'),'Rejected Quick Bar change was silent or applied')
local optionSetter=RA.PersonalTools.SetOption
RA.PersonalTools.SetOption=function()return false,'Profile unavailable.'end
h:control('Auto resurrection'):Fire('OnClick')
check(not RA:GetDB().personalTools.autoRes and h:visible('Profile unavailable.'),'Unavailable Personal parent silently failed')
RA.PersonalTools.SetOption=optionSetter
h.setCombat(false);h.event('PLAYER_REGEN_ENABLED')
check(not RA:IsHUDEnabled(),'Combat end applied a rejected setting')
quiet(h,before)
-- Compact addon names always offer their CurseForge link; local state only styles the row.
local report={byID={}};local localRefreshes=0
local ids={'northernsky','rclootcouncil','simulationcraft','wowutils','autopotion','bigwigs'}
local values={{true,true,true},{true,true,true},{true,false,true},{true,true,false},{false,false,false},{true,nil,true}}
for i,id in ipairs(ids)do local v=values[i];report.byID[id]={installed=v[1],enabled=v[2],loaded=v[3]}end
RA.AddonCatalog.GetLocalReport=function()return report end
RA.AddonCatalog.RefreshLocal=function()localRefreshes=localRefreshes+1;return report end
RA:OpenConfig('MYTOOLS');RA:OpenConfig('GENERAL')
local addonRows={}
for _,o in ipairs(h.objects)do if o.state and o:IsVisible()then addonRows[#addonRows+1]=o end end
check(#addonRows==6 and h:visible('Morning Brew addons') and not h:button('Morning Brew addons'),'Addon rows are collapsed or incomplete')
local function RowButton(row)
    local buttons={}
    for _,o in ipairs(h.objects)do if o.parent==row and o.kind=='Button'then buttons[#buttons+1]=o end end
    check(#buttons==1,'Addon row retained a separate action column')
    return buttons[1]
end
local function RowText(row,value)
    for _,o in ipairs(h.objects)do if o.parent==row and o.kind=='FontString' and o.text==value then return o end end
end
local function colorIs(label,color)
    local value=label.textColor or {}
    return value[1]==color[1] and value[2]==color[2] and value[3]==color[3] and value[4]==color[4]
end
local expected={'Installed','Installed','Disabled · reload required','Not loaded','Missing','Unknown'}
local colors=RA.Theme.Colors
for i,row in ipairs(addonRows)do
    local name=RowButton(row);local entry=RA.AddonCatalog:GetEntry(ids[i])
    local priority=RowText(row,i<=4 and 'Important' or 'Optional')
    local status=RowText(row,expected[i])
    check(row:GetHeight()==42 and name.label.text==entry.name and name:IsEnabled(),'Missing clickable addon name '..i)
    check(priority and not RowText(row,'Core') and not RowText(row,'Team tool'),'Wrong addon priority label '..i)
    check(status and status.justifyH=='RIGHT' and #status.points==1 and status.points[1][1]=='TOPRIGHT'
        and status.points[1][2]==row and status.points[1][3]=='TOPRIGHT' and status.points[1][4]<0,'Addon status is not right aligned '..i)
    check(status:GetWidth()-status.points[1][4]+486<=row:GetWidth(),'Addon status overlaps the priority column '..i)
    local active=i==1 or i==2 or i==4
    local color=active and colors.magenta or colors.muted
    check(colorIs(name.label,color) and colorIs(status,color) and colorIs(priority,active and colors.textSoft or colors.muted),'Wrong installed/disabled addon colors '..i)
    local lines={};local line=h.env.GameTooltip.AddLine
    h.env.GameTooltip.AddLine=function(_,value)lines[#lines+1]=value end
    name:Fire('OnEnter');name:Fire('OnLeave');h.env.GameTooltip.AddLine=line
    check(table.concat(lines,' '):find('Click to copy its CurseForge download link.',1,true) and colorIs(name.label,color),'Addon link hover is missing or loses state color '..i)
end
check(h:visible('Installed') and h:visible('Disabled · reload required') and h:visible('Not loaded') and h:visible('Missing') and h:visible('Unknown'),'Addon states conflated')
local count=localRefreshes
for i,row in ipairs(addonRows)do
    local entry=RA.AddonCatalog:GetEntry(ids[i]);RowButton(row):Fire('OnClick')
    local link
    for _,o in ipairs(h.objects)do if o.kind=='EditBox' and o:IsVisible() and o:GetText()==entry.url then link=o end end
    check(h:visible(entry.name..' — copy link to your browser') and link and link:HasFocus()
        and entry.url:find('https://www.curseforge.com/wow/addons/',1,true)==1,'Addon name opened the wrong CurseForge link '..i)
    check(h:click('CLOSE') and h:visible('Morning Brew addons'),'Addon link did not return to General '..i)
end
check(localRefreshes==count,'Addon name click refreshed metadata instead of opening its link')
check(RA.AddonCatalog:GetEntry('northernsky').priority=='Core' and RA.AddonCatalog:GetEntry('wowutils').priority=='Team tool','Display labels changed catalog priority data')
report.byID.northernsky={installed=true,enabled=false,loaded=false}
report.byID.autopotion={installed=true,enabled=true,loaded=true}
RA:OpenConfig('MYTOOLS');RA:OpenConfig('GENERAL')
check(RowText(addonRows[1],'Disabled') and colorIs(RowButton(addonRows[1]).label,colors.muted),'Disabled addon retained its installed color')
check(RowText(addonRows[5],'Installed') and colorIs(RowButton(addonRows[5]).label,colors.magenta),'Newly installed addon retained its missing color')
quiet(h,before)
-- All ordinary pages restore; both legacy setup entry points become General.
for _,tab in ipairs({'GENERAL','MYTOOLS','ADDONS','QUICKBAR','RAIDGROUPS','CONTENT','HUD','SCANNING','ACTIONS','WORLDMARKERS','SETTINGS','NORTHERNSKY','SETUP','invalid'})do
    h,RA=prepared({profile={schemaVersion=19},navigation={lastTab=tab,cooldownTab='HUD'},setup={completed=true,role='LEADER',returnTab='SETUP'}})
    RA:OpenConfig()
    local expected=(tab=='SETUP' or tab=='invalid') and 'GENERAL' or tab
    check(h.env.RaidArsenalDB.navigation.lastTab==expected and not RA.Setup:HasDraft(),'Saved routing failed: '..tab)
    check(RA.Setup:GetRole()=='LEADER' and h.env.RaidArsenalDB.setup.returnTab==nil,'Role changed or legacy draft route retained')
    quiet(h,{sent=0,inspects=0,talents=0})
end
h,RA=prepared({profile={schemaVersion=19,personalTools={autoResInCombat=true,reminderSound=false,healthThreshold=71,reminderGlow={style='PIXEL'}},actions={leftClickMode='WHISPER'},leaderToolbox={showMissing=false}},setup={completed=true,role='LEADER'}})
RA:OpenConfig('MYTOOLS');check(not h:control('Also accept during combat'):IsEnabled() and RA.PersonalTools:GetState().autoResInCombat,'Parent OFF lost stored dependent choice')
RA:OpenConfig('GENERAL');h:control('Auto resurrection'):Fire('OnClick')
check(RA:GetDB().personalTools.autoRes and RA:GetDB().personalTools.autoResInCombat,'Immediate parent edit changed child')
RA:OpenConfig('MYTOOLS');check(h:control('Also accept during combat'):IsEnabled(),'General parent did not update dependent control')
h.env.SlashCmdList.RCPARSENAL('setup');check(h:visible('General') and not RA.Setup:HasDraft(),'Setup slash opened old editor')
RA:OpenConfig('SETUP');RA:OpenConfig('QUICKBAR');check(not h:button('RESUME REVIEW'),'Footer resume remains')
local imported=RA:CreateDefaultProfile();check(RA:ApplyImportedProfile(imported),'Import failed')
check(RA:GetDB().personalTools.healthThreshold==71 and not RA:GetDB().personalTools.reminderSound and RA:GetDB().personalTools.reminderGlow.style=='PIXEL'
    and RA:GetDB().actions.leftClickMode=='WHISPER' and not RA:GetDB().leaderToolbox.showMissing and RA.Setup:GetRole()=='LEADER','Navigation/import overwrote saved preferences')
check(not RA.Setup:HasDraft() and not RA.Setup.Save,'Import recreated draft lifecycle')
RA:ResetProfile();check(not RA:GetDB().personalTools.autoRes and not RA:GetDB().personalTools.autoResInCombat and not RA.Setup:HasDraft(),'Reset enabled optional behavior or editor')
-- One scroll body, quiet default options; all accepted details remain reachable.
h,RA=prepared({profile={schemaVersion=19,personalTools={consumableReminder=true,reminderStoneText='Use |Hitem:1|h[stone]|h',reminderGlow={style='PIXEL'}}},setup={completed=true}})
RA:OpenConfig('MYTOOLS');before=h.metrics();timerCount=#h.timers
check(h:control('Visual health threshold') and h:control('Show reminder'),'Visible basics missing')
check(not h:control('ICON SIZE') and not h:control('Warning sound (35%)') and not h:control('Healthstone message'),'Details start expanded')
local originalStatus=RA.PersonalTools.GetStatusText
RA.PersonalTools.GetStatusText=function(self,key)if key=='consumableReminder' then return 'No supported healing item carried. Low-health visual: OUT OF POTIONS!' end;return originalStatus(self,key)end
RA:FireCallback('PERSONAL_TOOLS_CHANGED');check(h:visible('No healing items carried.'),'Known empty inventory lost concise exception')
RA.PersonalTools.GetStatusText=originalStatus;RA:FireCallback('PERSONAL_TOOLS_CHANGED')
local threshold=h:control('Visual health threshold')
local config=threshold.parent;local body=config.parent;local scroll=body.parent
check(scroll.kind=='ScrollFrame' and scroll.child==body and body:GetWidth()==918,'Personal options lack one 918-wide scroll child')
check(body:GetHeight()<=598,'Default Personal Tools needlessly overflows viewport')
RA.PersonalTools:SetOption('autoRes',true);h.setCombat(true);h.event('RESURRECT_REQUEST');h.setCombat(false)
local resReason
for _,o in ipairs(h.objects)do if o.parent==body and o.kind=='FontString' and o.points[1] and o.text==RA.PersonalTools:GetStatusText('autoRes')then resReason=o end end
check(resReason~=nil,'Resurrection reason missing')
local metric=resReason.GetStringHeight;resReason.GetStringHeight=function()return 96 end
RA:FireCallback('PERSONAL_TOOLS_CHANGED')
check(-h:control('Consumable reminder').points[1][5]>=96+58,'Wrapped status did not move following section')
resReason.GetStringHeight=metric;RA.PersonalTools:SetOption('autoRes',false);RA:FireCallback('PERSONAL_TOOLS_CHANGED')
local appearance=h:disclose('Appearance ')
check(h:control('ICON SIZE') and h:control('TEXT SIZE') and h:control('EMPTY WARNING SIZE') and h:control('Glow at 35% or lower'),'Appearance omitted controls')
h:disclose('Advanced glow')
check(h:control('LINES') and h:control('THICKNESS') and body:GetHeight()>598,'Advanced Pixel controls do not extend scroll body')
scroll:SetVerticalScroll(80)
local lines=h:control('LINES');lines.slider:SetValue(10)
check(h:control('LINES') and scroll:GetVerticalScroll()==80 and RA:GetDB().personalTools.reminderGlow.pixelLines==10,'Slider collapsed details or reset scroll')
scroll:SetHeight(598);scroll:SetVerticalScroll(10000)
h:disclose('Messages ')
check(not h:control('LINES') and h:control('Healthstone message'),'Messages did not close Appearance')
check(scroll:GetVerticalScroll()>=0 and scroll:GetVerticalScroll()<=math.max(0,body:GetHeight()-598),'Folding did not clamp to the viewport after adding Recap settings')
local message=h:control('Healthstone message')
check(message.box:GetText()=='Use |Hitem:1|h[stone]|h','Caption editor interpreted literal pipes')
message.box:SetFocus();message.box:SetText('New | texture');message.box:Fire('OnEnterPressed')
check(RA:GetDB().personalTools.reminderStoneText=='New | texture','Caption commit lost literal text')
h:disclose('Sound ')
check(not h:control('Healthstone message') and h:control('Warning sound (35%)'),'Sound did not close Messages')
check(h:click('Sound 6  v'),'Sound chooser missing')
for _,choice in ipairs(RA.ReminderSounds:GetOptions())do check(h:button(choice.label),'Missing sound choice '..choice.label)end
check(h:click('Built-in alert') and RA:GetDB().personalTools.reminderSoundChoice=='builtin_alert','Built-in option did not save')
h:disclose('Item behavior ')
check(h:control('SHOW ITEMS') and not h:control('Warning sound (35%)'),'Item behavior did not close Sound')
local items=h:control('SHOW ITEMS');items.buttons[2].frame:Fire('OnClick')
check(RA:GetDB().personalTools.reminderShowOnCooldown,'Any carried control failed')
quiet(h,before);check(#h.timers==timerCount,'Detail edits started polling')
-- Closing configuration removes owned picker sessions before it hides controls.
h:disclose('Appearance ');h:disclose('Advanced glow')
local picker={hides=0}
function picker:Hide()self.hides=self.hides+1 end
function picker:SetupColorPickerAndShow(info)self.swatchFunc=info.swatchFunc;self.cancelFunc=info.cancelFunc end
function picker:GetColorRGB()return 0.1,0.2,0.3 end
h.env.ColorPickerFrame=picker
check(h:click('Pixel Glow  v'),'Style selector missing')
local styleRow=h:button('Steady border')
check(styleRow and styleRow.parent.clampedToScreen,'Style menu is not clamped at fitted sizes')
scroll:Fire('OnVerticalScroll',20);check(not styleRow:IsVisible(),'Scroll left style menu floating')
check(h:click('Color'),'Color picker action missing')
local scrolledSwatch=picker.swatchFunc
scroll:Fire('OnVerticalScroll',20)
check(picker.hides==1,'Scroll left owned picker open')
scrolledSwatch();check(RA:GetDB().personalTools.reminderGlow.color[1]==1,'Scrolled stale picker wrote color')
check(h:click('Color'),'Color picker could not reopen after scroll')
local stale=picker.swatchFunc
h:control('Consumable reminder'):Fire('OnClick')
check(picker.hides==2 and not h:control('ICON SIZE') and not RA:GetDB().personalTools.consumableReminder,'Master OFF hid controls without picker cleanup')
stale();check(RA:GetDB().personalTools.reminderGlow.color[1]==1,'Stale picker wrote after master OFF')
-- Cached raid checks are available with puck OFF and query only explicitly.
RA:OpenConfig('QUICKBAR');before=h.metrics();timerCount=#h.timers
local queries=0;local Query=RA.SupplyCheck.Query
RA.SupplyCheck.Query=function(self,...)queries=queries+1;return Query(self,...)end
check(h:click('RAID CHECKS') and h:visible('Carried healing supplies') and queries==0,'Raid checks opened with a query')
check(h:click('CHECK SUPPLIES') and queries==1 and h:visible('Join a raid to check supplies.'),'Explicit supplies check failed')
check(not RA:GetDB().leaderToolbox.enabled and #h.timers==timerCount,'Raid checks activated puck/polling');quiet(h,before)
check(h:click('CLOSE') and h:click('RAID CHECKS') and queries==1,'Cached reopen repeated request')
print('PASS: '..checks..' settings cleanup lifecycle/UI assertions (offline actual modules; native fit pending)')
]]
assert(loadstring(source))()
