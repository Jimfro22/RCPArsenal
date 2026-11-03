-- Real settings and update-log modules; offline lifecycle and layout checks.
local f = assert(io.open('tests/hub.lua')); local prefix = f:read('*a'); f:close()
prefix = prefix:sub(1, assert(prefix:find('check(db.schemaVersion == 19', 1, true)) - 1)
assert(loadstring(prefix .. [=[
UISpecialFrames = {}
check(RA.ReleaseNotes[1].version == RA.VERSION, 'Latest notes do not match this build')
check(not RA.UpdateLogUI.overlay, 'Update log allocated on login')
RA:OpenConfig('GENERAL')
check(not RA.UpdateLogUI.overlay, 'Opening settings automatically opened/allocated notes')
local button
for _, o in ipairs(objects) do
    if o.label and o.label.text == "WHAT'S NEW" then button = o end
end
check(button and button:IsVisible(), 'Missing top-left update log entry')
local p = button.points[1]
check(p[1] == 'TOPLEFT' and p[3] == 'TOPLEFT' and p[4] == 70 and p[5] == -63,
    'Update entry left the branding area')
check(-p[5] + button:GetHeight() < 88 and p[4] + button:GetWidth() < 238,
    'Update entry overlaps navigation or sidebar edge')
local sentBefore, talentsBefore, inspectBefore, timersBefore = sent, talentReads, inspectCalls, #timers
button:Fire('OnClick')
local overlay = named.RCPArsenalUpdateLog
check(overlay and overlay:IsVisible() and overlay:GetParent() == RA.ConfigFrame,
    'Notes did not open inside settings')
check(overlay.dialog:GetWidth() < RA.ConfigFrame:GetWidth()
    and overlay.dialog:GetHeight() < RA.ConfigFrame:GetHeight(), 'Notes exceed settings bounds')
check(overlay.scroll.child:GetHeight() > 490, 'Older notes cannot be scrolled into view')
check(UISpecialFrames[#UISpecialFrames] == 'RCPArsenalUpdateLog', 'Notes missing Escape registration')
check(not overlay.scripts.OnUpdate and not overlay.registered, 'Notes poll or register gameplay events')
check(sent == sentBefore and talentReads == talentsBefore and inspectCalls == inspectBefore
    and #timers == timersBefore, 'Reading notes queries gameplay, network, or timers')
check(RaidArsenalDB.navigation.lastTab == 'GENERAL' and not db.hudEnabled
    and not db.personalTools.consumableReminder, 'Notes changed navigation or enabled a tool')
overlay.scroll:SetVerticalScroll(450)
overlay.closeButton:Fire('OnClick'); check(not overlay:IsShown(), 'Close did not hide notes')
local count = #objects
button:Fire('OnClick')
check(RA.UpdateLogUI.overlay == overlay and #objects == count
    and overlay.scroll:GetVerticalScroll() == 0, 'Reopening notes reallocates or starts halfway down')
RA:OpenConfig('MYTOOLS'); check(not overlay:IsShown(), 'Changing page retained the notes overlay')
button:Fire('OnClick'); RA:CloseConfig(); check(not overlay:IsShown(), 'Settings close retained notes')
RA:OpenConfig(); check(not overlay:IsShown(), 'Settings reopen resurrected notes')
RA:CloseConfig(); UIParent:SetSize(800, 600); RA:OpenConfig('GENERAL'); button:Fire('OnClick')
check(overlay:GetParent() == RA.ConfigFrame and RA.ConfigFrame:GetScale() < 1,
    'Small-screen notes do not inherit the fitted settings scale')
local oldArg = arg; arg = {'--check'}
assert(loadfile('tools/export_release_notes.lua'))()
arg = oldArg
cleanErrors()
print('update log: ' .. checks .. ' checks passed (offline; native text rendering still needs a glance)')
]=]))()
