-- Real Config/Setup/Hub modules through the existing isolated frame fixture.
-- This checks state/routing/layout bounds, not native rendering or taint.
local file=assert(io.open('tests/setup_placement.lua'));local source=file:read('*a');file:close()
source=source:sub(1,assert(source:find('local h=Lifecycle();local RA=h.RA',1,true))-1)
source=source..[[
local function prepared(saved)
    local h=Lifecycle(saved)
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
-- New neutral opens General once, without staging, starting tools or polling.
local h,RA=prepared();local before=h.metrics()
RA:OpenConfig()
check(h:visible('General') and h:visible('Welcome to Arsenal. Turn on only the tools you want.'),'Fresh overview introduction missing')
check(not RA.Setup:HasDraft() and h.env.RaidArsenalDB.navigation.lastTab=='GENERAL','Overview started/stored editor')
quiet(h,before)
local timerCount=#h.timers
h:disclose('Morning Brew addons')
check(#h.timers==timerCount,'Local addon disclosure started polling')
for _,entry in ipairs(RA.AddonCatalog.Entries)do if not entry.internal then
    local chip=h:button(entry.name..'\n');check(chip and chip.label.text:find(entry.priority,1,true),'Team addon/priority/local status missing: '..entry.name)
    chip:Fire('OnClick');check(h:click('CLOSE'),'Addon link modal missing')
end end
quiet(h,before)
check(h:click('SKIP FOR NOW') and not RA.Setup:HasDraft() and h.env.RaidArsenalDB.setup.completed,'Overview Skip did not dismiss onboarding')
check(h.env.RaidArsenalDB.setup.role=='RAIDER' and not RA:IsHUDEnabled(),'Overview Skip changed role or HUD')
RA:OpenConfig('MYTOOLS');check(h:click('RESUME REVIEW')==nil,'Permanent Setup/review shelf action remains')
-- Every saved ordinary route reopens; a saved legacy editor is overview only.
for _,tab in ipairs({'GENERAL','MYTOOLS','ADDONS','QUICKBAR','CONTENT','HUD','SCANNING','ACTIONS','WORLDMARKERS','SETTINGS','NORTHERNSKY','SETUP','invalid'}) do
    h,RA=prepared({profile={schemaVersion=19},navigation={lastTab=tab,cooldownTab='HUD'}})
    RA:OpenConfig()
    local expected=(tab=='SETUP' or tab=='invalid') and 'GENERAL' or tab
    check(h.env.RaidArsenalDB.navigation.lastTab==expected and not RA.Setup:HasDraft(),'Saved route migration failed: '..tab)
    quiet(h,{sent=0,inspects=0,talents=0})
end
h,RA=prepared();h.env.SlashCmdList.RCPARSENAL('tools')
check(h:visible('Personal Tools') and not RA.Setup:HasDraft(),'Fresh explicit tools deep link overridden')
h:control('GENERAL'):Fire('OnClick');RA:OpenConfig('QUICKBAR');RA:CloseConfig('CONTEXT');RA:OpenConfig()
check(h:visible('Quick Bar') and not RA.Setup:IsFirstRunPending(),'Sidebar General visit did not mark introduction presented')
h.env.SlashCmdList.RCPARSENAL('general');check(h:visible('General') and not RA.Setup:HasDraft(),'General slash failed')
h.env.SlashCmdList.RCPARSENAL('setup');check(RA.Setup:HasDraft() and h:visible('Review choices'),'Explicit setup slash did not begin review')
check(h.env.RaidArsenalDB.navigation.lastTab=='GENERAL','Explicit setup polluted saved ordinary route')
RA.Setup:Set('role','LEADER');RA.Setup:Set('hud',true);RA:OpenConfig('QUICKBAR')
check(h:button('RESUME REVIEW') and RA.Setup:Get('hud'),'Paused review lost master/resume action')
RA:OpenConfig('GENERAL');check(h:visible('Available Cooldowns · Off'),'General rendered paused master as saved')
local resumeCount=0;for _,o in ipairs(h.objects)do if o.label and o.label.text=='RESUME REVIEW' and o:IsVisible()then resumeCount=resumeCount+1 end end
check(resumeCount==1,'General duplicated its primary Resume action in the shelf')
check(h:click('RESUME REVIEW') and RA.Setup:Get('role')=='LEADER','Resume lost role')
check(h:click('SKIP FOR NOW') and h.env.RaidArsenalDB.setup.role=='RAIDER' and not RA:IsHUDEnabled(),'First review Skip saved role/master')
-- Replay Cancel and paused close discard role, preserving last ordinary page.
h,RA=prepared({profile={schemaVersion=19},setup={completed=true,role='LEADER'},navigation={lastTab='HUD'}})
RA:OpenConfig();RA:OpenSetup();check(RA.Setup:Get('role')=='LEADER' and not RA.Setup:IsFirstUseDraft(),'Saved replay role lost')
RA.Setup:Set('role','RAIDER');RA.Setup:Set('reminder',true);RA:OpenConfig('MYTOOLS');RA:OpenSetup()
check(RA.Setup:Get('reminder') and h:click('CANCEL'),'Replay Cancel missing')
check(h.env.RaidArsenalDB.navigation.lastTab=='HUD' and h.env.RaidArsenalDB.setup.role=='LEADER'
    and not RA:GetDB().personalTools.consumableReminder,'Cancel lost original return or saved role/master')
RA:OpenSetup();RA.Setup:Set('role','RAIDER');RA:OpenConfig('QUICKBAR');RA:CloseConfig();RA:OpenConfig()
check(h:visible('Quick Bar') and not RA.Setup:HasDraft() and h.env.RaidArsenalDB.setup.role=='LEADER','Paused user close did not discard/preserve role/last tab')
-- Closing while the editor itself is active retains the last ordinary page,
-- even though clearing its draft synchronously exits the empty editor.
for _,ordinary in ipairs({'MYTOOLS','HUD','QUICKBAR'}) do
    RA:OpenConfig(ordinary);RA:OpenSetup();RA.Setup:Set('role','RAIDER');RA:CloseConfig()
    check(not RA.Setup:HasDraft() and h.env.RaidArsenalDB.navigation.lastTab==ordinary,'Active review close overwrote ordinary route '..ordinary)
    RA:OpenConfig();check(h.env.RaidArsenalDB.navigation.lastTab==ordinary and not RA.Setup:HasDraft(),'Reopen recreated editor/lost route '..ordinary)
end
RA:OpenConfig('MYTOOLS');RA:OpenSetup();RA.ConfigFrame:Hide();RA:OpenConfig()
check(h.env.RaidArsenalDB.navigation.lastTab=='MYTOOLS' and not RA.Setup:HasDraft(),'Unlabelled native Escape-style close lost ordinary page')
-- A child-only change is immediate and is not owned by the four-master review.
RA:OpenSetup();RA.Setup:Set('role','LEADER');RA.Setup:Set('reminder',true)
RA:GetDB().personalTools.healthThreshold=71;RA:GetDB().personalTools.reminderSound=false
RA:GetDB().personalTools.reminderGlow.pixelLines=11;RA:GetDB().actions.leftClickMode='WHISPER'
RA:GetDB().leaderToolbox.showMissing=false
check(not RA.Setup:GetConflict() and h:click('SAVE CHOICES'),'Child-only edits incorrectly invalidated review')
check(RA:GetDB().personalTools.healthThreshold==71 and not RA:GetDB().personalTools.reminderSound and RA:GetDB().personalTools.reminderGlow.pixelLines==11
    and RA:GetDB().actions.leftClickMode=='WHISPER' and not RA:GetDB().leaderToolbox.showMissing,'Review overwrote a child choice')
RA:OpenConfig('MYTOOLS');RA:OpenSetup();RA.Setup:Set('hud',true);RA:OpenConfig('MYTOOLS')
RA.PersonalTools:SetOption('autoRes',true);RA:OpenSetup()
check(RA.Setup:GetConflict() and not RA.Setup:Save(),'Conflicting master edit was silently overwritten')
check(h:click('RELOAD CHOICES') and not RA.Setup:GetConflict() and RA.Setup:Get('autoRes') and not RA.Setup:Get('hud'),'Reload did not replace stale choices')
check(h:click('CANCEL') and h:visible('Personal Tools'),'Reload lost original return destination')
-- Import invalidates even same-object notifications; full reset leaves no empty editor.
RA:OpenSetup();RA.Setup:Set('hud',true)
local imported=RA:CreateDefaultProfile()
check(RA:ApplyImportedProfile(imported) and RA.Setup:HasDraft() and RA.Setup:GetConflict(),'Actual import silently cleared or accepted old draft')
check(not RA.Setup:Save() and h:click('RELOAD CHOICES') and not RA.Setup:GetConflict(),'Imported profile lacks deliberate reload')
RA:FireCallback('PROFILE_IMPORTED')
check(RA.Setup:HasDraft() and RA.Setup:GetConflict(),'Same-object import callback did not invalidate review')
check(h:click('CANCEL'),'Import conflict Cancel unavailable')
RA:OpenSetup();RA.Setup:Set('hud',true);RA:ResetProfile()
check(not RA.Setup:HasDraft() and h:visible('General') and not h:button('SAVE CHOICES'),'Full reset retained a Save-enabled empty review')
-- One scroll body, quiet default options; all accepted details remain reachable.
h,RA=prepared({profile={schemaVersion=19,personalTools={consumableReminder=true,reminderStoneText='Use |Hitem:1|h[stone]|h',reminderGlow={style='PIXEL'}}},setup={completed=true}})
RA:OpenConfig('MYTOOLS');before=h.metrics();timerCount=#h.timers
check(h:control('HEALTH THRESHOLD') and h:control('WHEN TO SHOW'),'Visible basics missing')
check(not h:control('ICON SIZE') and not h:control('Warning sound') and not h:control('Healthstone message'),'Details start expanded')
local threshold=h:control('HEALTH THRESHOLD')
local config=threshold.parent;local body=config.parent;local scroll=body.parent
check(scroll.kind=='ScrollFrame' and scroll.child==body and body:GetWidth()==918,'Personal options lack one 918-wide scroll child')
check(body:GetHeight()<=598,'Default Personal Tools needlessly overflows viewport')
local resReason
for _,o in ipairs(h.objects)do if o.parent==body and o.kind=='FontString' and o.points[1] and o.text==RA.PersonalTools:GetStatusText('autoRes')then resReason=o end end
check(resReason~=nil,'Resurrection reason missing')
local metric=resReason.GetStringHeight;resReason.GetStringHeight=function()return 96 end
RA:FireCallback('PERSONAL_TOOLS_CHANGED')
check(-h:control('Consumable reminder').points[1][5]>=96+58,'Wrapped status did not move following section')
resReason.GetStringHeight=metric;RA:FireCallback('PERSONAL_TOOLS_CHANGED')
local appearance=h:disclose('Appearance · ')
check(h:control('ICON SIZE') and h:control('TEXT SIZE') and h:control('EMPTY WARNING SIZE') and h:control('Glow at 35% or lower'),'Appearance omitted controls')
h:disclose('Advanced glow')
check(h:control('LINES') and h:control('THICKNESS') and body:GetHeight()>598,'Advanced Pixel controls do not extend scroll body')
scroll:SetVerticalScroll(80)
local lines=h:control('LINES');lines.slider:SetValue(10)
check(h:control('LINES') and scroll:GetVerticalScroll()==80 and RA:GetDB().personalTools.reminderGlow.pixelLines==10,'Slider collapsed details or reset scroll')
h:disclose('Messages · ')
check(not h:control('LINES') and h:control('Healthstone message'),'Messages did not close Appearance')
check(scroll:GetVerticalScroll()==0,'Folding did not clamp old scroll range')
local message=h:control('Healthstone message')
check(message.box:GetText()=='Use |Hitem:1|h[stone]|h','Caption editor interpreted literal pipes')
message.box:SetFocus();message.box:SetText('New | texture');message.box:Fire('OnEnterPressed')
check(RA:GetDB().personalTools.reminderStoneText=='New | texture','Caption commit lost literal text')
h:disclose('Sound · ')
check(not h:control('Healthstone message') and h:control('Warning sound'),'Sound did not close Messages')
check(h:click('Sound 6  v'),'Sound chooser missing')
for _,choice in ipairs(RA.ReminderSounds:GetOptions())do check(h:button(choice.label),'Missing sound choice '..choice.label)end
check(h:click('Built-in alert') and RA:GetDB().personalTools.reminderSoundChoice=='builtin_alert','Built-in option did not save')
h:disclose('Item behavior · ')
check(h:control('SHOW ITEMS') and not h:control('Warning sound'),'Item behavior did not close Sound')
local items=h:control('SHOW ITEMS');items.buttons[2].frame:Fire('OnClick')
check(RA:GetDB().personalTools.reminderShowOnCooldown,'Any carried control failed')
quiet(h,before);check(#h.timers==timerCount,'Detail edits started polling')
-- Closing configuration removes owned picker sessions before it hides controls.
h:disclose('Appearance · ');h:disclose('Advanced glow')
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
