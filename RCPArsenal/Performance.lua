local _,RA=...
local P={LIMIT=5};RA.Performance=P
local enabled,indicator,current=false,nil,nil
local reports,subscriptions={},{}
local function Public(v)
    if type(issecretvalue)~="function"then return end
    local ok,secret=pcall(issecretvalue,v);if ok and secret==false then return v end
end
local function Number(v)
    v=Public(v);if type(v)=="number"and v==v and v>=0 and v<=1e15 then return v end
end
local function Text(v)
    v=Public(v);if type(v)=="string"and #v<=128 and not v:find("[%c|]")then return v end
end
local function Table(v)v=Public(v);if type(v)=="table"and not getmetatable(v)then return v end end
local function Call(fn,...)
    if type(fn)~="function"then return end
    local ok,v=pcall(fn,...);if ok then return Public(v)end
end
local function Now()return Number(Call(GetTime))end
local function Available()
    return C_AddOnProfiler and type(C_AddOnProfiler.GetAddOnMetric)=="function"
        and Call(C_AddOnProfiler.IsEnabled)==true and Enum and Table(Enum.AddOnProfilerMetric)
end
local keys={"RecentAverageTime","PeakTime","EncounterAverageTime","CountTimeOver1Ms","CountTimeOver5Ms","CountTimeOver10Ms","CountTimeOver50Ms"}
local counts={"CountTimeOver1Ms","CountTimeOver5Ms","CountTimeOver10Ms","CountTimeOver50Ms"}
local scalarKeys={"version","kind","name","reason","startedAt","endedAt","duration","completed","encounterID","success"}
local numericKeys={startedAt=true,endedAt=true,duration=true,encounterID=true}
local booleanKeys={completed=true,success=true}
local function Clean(input)
    input=Table(input);if not input then return end
    local out={}
    for _,key in ipairs(scalarKeys)do
        local v=Public(input[key])
        if booleanKeys[key]then if type(v)=="boolean"then out[key]=v end
        elseif numericKeys[key]then out[key]=Number(v)
        else out[key]=Text(v)end
    end
    if not out.startedAt or not out.endedAt or out.endedAt<out.startedAt or(out.kind~="combat"and out.kind~="boss")then return end
    out.duration=out.endedAt-out.startedAt
    for _,part in ipairs({"before","after","over"})do
        out[part]={};local source=Table(input[part])or{}
        for _,key in ipairs(part=="over"and counts or keys)do out[part][key]=Number(source[key])end
    end
    return out
end
local function Save()
    local root=Table(RaidArsenalDB);if not root then return end
    local stored={};for i=1,math.min(#reports,P.LIMIT)do stored[#stored+1]=Clean(reports[i])end
    root.performanceReports=stored
end
local function Snapshot()
    if not Available()then return end
    local out={};local metrics=Enum.AddOnProfilerMetric
    for _,key in ipairs(keys)do
        local metric=Number(metrics[key])
        if metric then out[key]=Number(Call(C_AddOnProfiler.GetAddOnMetric,RA.ADDON_NAME,metric))end
    end
    return out
end
local function Notify()RA:FireCallback("PERFORMANCE_CHANGED")end
local function Finish(reason,completed,success)
    if not current then return end
    local record=current;current=nil
    local time=Now();if not time or time<record.startedAt then Notify();return end
    record.endedAt=time;record.duration=time-record.startedAt
    record.after=Snapshot()or{};record.reason=reason;record.completed=completed==true
    if Number(success)then record.success=Number(success)==1 end
    record.over={}
    for _,key in ipairs(counts)do
        local before,after=record.before[key],record.after[key]
        if before and after and after>=before then record.over[key]=after-before end
    end
    record=Clean(record);if not record then Notify();return end
    table.insert(reports,1,record);while #reports>P.LIMIT do table.remove(reports)end
    Save();Notify()
end
local function Begin(kind,id,name)
    if not enabled then return end
    if current then
        if kind=="combat"or current.kind=="boss"and current.encounterID==id then return end
        Finish("Boss encounter started",false)
    end
    local time=Now();local snapshot=Snapshot()
    if not time or not snapshot then return end
    current={kind=kind,encounterID=Number(id),name=Text(name)or(kind=="boss"and"Boss encounter"or"Combat"),
        version=RA.VERSION,startedAt=time,before=snapshot}
    Notify()
end
function P:IsEnabled()return enabled end
function P:GetReports()
    local out={};for i,r in ipairs(reports)do out[i]=Clean(r)end;return out
end
function P:BuildReportText()
    if #reports==0 then return nil,enabled and"Record a fight first. Performance recording is ON."or"No performance reports yet. Enable recording in General or use /rcp perf on."end
    local lines={"RCP Arsenal performance",enabled and"Recording ON"or"Recording OFF","Whole-addon CPU measurements from Blizzard's profiler."}
    local function Ms(v)return v and string.format("%.3f ms",v)or"Not recorded"end
    for i,r in ipairs(reports)do
        lines[#lines+1]="";lines[#lines+1]=string.format("%d/%d · %s · %.1fs · %s",i,#reports,r.name or"Combat",r.duration,r.completed and"Finished"or"Partial")
        lines[#lines+1]="Arsenal "..(r.version or"version not recorded")
        if r.kind=="boss"and r.completed then lines[#lines+1]="Blizzard encounter average: "..Ms(r.after.EncounterAverageTime).." per UI tick"end
        lines[#lines+1]="Recent average at finish (last 60 UI ticks): "..Ms(r.after.RecentAverageTime)
        lines[#lines+1]="Session peak at finish: "..Ms(r.after.PeakTime).." (since client startup)"
        for _,pair in ipairs({{1,counts[1]},{5,counts[2]},{10,counts[3]},{50,counts[4]}})do
            local value=r.over[pair[2]];lines[#lines+1]="Ticks over "..pair[1].." ms during this recording: "..(value and string.format("%.0f",value)or"Not recorded / counters reset")
        end
        if not r.completed then lines[#lines+1]="Stopped: "..(r.reason or"Interrupted")end
    end
    lines[#lines+1]="";lines[#lines+1]="Start/end snapshots only. No per-frame sampling or function hooks. Recording overhead has not been benchmarked in the native client."
    return table.concat(lines,"\n")
end
function P:ShowReport()
    local text,why=self:BuildReportText();if not text then return false,why end
    if not RA.DeathRecapUI or type(RA.DeathRecapUI.ShowDebugText)~="function"then return false,"Report viewer unavailable."end
    return RA.DeathRecapUI:ShowDebugText(text)
end
local function Indicator()
    if indicator then return indicator end
    local T,C=RA.Theme,RA.Theme.Colors
    local b=CreateFrame("Button",nil,UIParent,"BackdropTemplate");indicator=b
    T.SetSize(b,284,30);T.SetPoint(b,"TOP",UIParent,"TOP",0,-24)
    b:SetFrameStrata("DIALOG");b:SetClampedToScreen(true);b:RegisterForClicks("LeftButtonUp","RightButtonUp")
    T:ApplyBackdropTemplate(b);T:ApplyRounded(b,C.orange,7,"border","BACKGROUND",-2)
    T:ApplyRounded(b,C.canvasDeep,6,"base","BACKGROUND",-1,{1,-1,-1,1})
    local label=b:CreateFontString(nil,"OVERLAY");RA:ApplyFont(label,12,"BOLD")
    T.SetPoint(label,"CENTER",b,"CENTER",0,0);label:SetTextColor(unpack(C.orange))
    RA:SetVisualText(label,"Performance recording ON")
    b:SetScript("OnClick",function(_,button)
        if button=="RightButton"then local _,why=P:SetEnabled(false);RA:Print(why)
        else local _,why=P:ShowReport();if why then RA:Print(why)end end
    end)
    b:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_BOTTOM");GameTooltip:SetText("Performance recording ON")
        GameTooltip:AddLine("Left-click: recent reports. Right-click: stop recording. Turns off after reload.",.8,.8,.8,true);GameTooltip:Show()
    end)
    b:SetScript("OnLeave",function()GameTooltip:Hide()end)
    return b
end
function P:SetEnabled(value)
    value=Public(value)==true
    if value==enabled then return true,enabled and"Performance recording is ON."or"Performance recording is OFF."end
    if value then
        if not Available()then return false,"Blizzard's addon profiler is unavailable; recording remains OFF."end
        local ok=pcall(function()Indicator():Show()end)
        if not ok then if indicator then pcall(indicator.Hide,indicator)end;return false,"Recording indicator unavailable; recording remains OFF."end
        enabled=true;for _,s in ipairs(subscriptions)do s:SetEnabled(true)end
        if Call(InCombatLockdown)==true then Begin("combat");if current then current.name="Combat · started mid-fight"end end
    else
        Finish("Recording stopped",false);enabled=false
        for _,s in ipairs(subscriptions)do s:SetEnabled(false)end
        if indicator then
            indicator:Hide()
            if Call(GameTooltip.GetOwner,GameTooltip)==indicator then GameTooltip:Hide()end
        end
    end
    Notify();return true,enabled and"Performance recording is ON. Turns off after reload."or"Performance recording is OFF."
end
local function Event(name,fn)subscriptions[#subscriptions+1]=RA:RegisterOptionalEvent(name,fn)end
Event("PLAYER_REGEN_DISABLED",function()Begin("combat")end)
Event("PLAYER_REGEN_ENABLED",function()if current and current.kind=="combat"then Finish("Combat ended",true)end end)
Event("ENCOUNTER_START",function(_,id,name)
    id=Number(id);if id and id>0 and id==math.floor(id)then Begin("boss",id,Text(name))end
end)
Event("ENCOUNTER_END",function(_,id,_,_,_,success)
    if current and current.kind=="boss"and Number(id)and Number(id)==current.encounterID then Finish("Encounter ended",true,success)end
end)
for _,name in ipairs({"PLAYER_LOGOUT","PLAYER_LEAVING_WORLD"})do Event(name,function()P:SetEnabled(false)end)end
RA:RegisterInitializer(function()
    local root=Table(RaidArsenalDB);local stored=root and Table(root.performanceReports)
    for i=1,math.min(stored and #stored or 0,P.LIMIT)do local r=Clean(stored[i]);if r then reports[#reports+1]=r end end
    -- Recording is deliberately session-only and always starts OFF.
end)
RA:RegisterCallback("PROFILE_RESET",function()P:SetEnabled(false)end)
RA:RegisterCallback("PROFILE_IMPORTED",function()P:SetEnabled(false)end)
