local _,RA=...
local P={LIMITS={seconds=8,rows=256,armSeconds=120,visible=16}};RA.DeathRecapDisplayProbe=P
local owner,observer,window,expiry
local function Secret(value)
    if type(issecretvalue)~="function"then return nil end
    local ok,result=pcall(issecretvalue,value)
    if ok and(result==true or result==false)then return result end
end
local function Public(value)if Secret(value)==false then return value end end
local function Number(value)
    value=Public(value)
    if type(value)=="number"and value==value and value>=0 and value<math.huge then return value end
end
local function String(value)
    value=Public(value)
    if type(value)=="string"and #value<=128 and not value:find("[%c|]")then return value end
end
local function Read(fn,...)
    if type(fn)~="function"then return end
    local ok,value=pcall(fn,...);if ok then return Public(value)end
end
local function Now()return Number(Read(GetTime))end
local function Metadata()
    local data={}
    if type(GetBuildInfo)=="function"then
        local ok,version,build,_,interface=pcall(GetBuildInfo)
        if ok then data.version=String(version);data.build=String(build);data.interface=Number(interface)end
    end
    if type(GetInstanceInfo)=="function"then
        local ok,_,kind,difficulty,_,_,_,_,id=pcall(GetInstanceInfo)
        if ok then data.instanceType=String(kind);data.difficulty=Number(difficulty);data.instanceID=Number(id)end
    end
    return data
end
local function Disconnect()
    if observer then observer:UnregisterAllEvents();observer:SetScript("OnEvent",nil)end
    if expiry then expiry:Cancel();expiry=nil end
end
local function Text(parent,text,size,x,y,width)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    RA:ApplyFont(f,size,"REGULAR",false);f:SetJustifyH("LEFT")
    f:SetSize(width,18);f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);f:SetText(text);return f
end
local function Button(parent,text,x,fn)
    local b=CreateFrame("Button",nil,parent);b:SetSize(108,26);b:SetPoint("BOTTOMLEFT",parent,"BOTTOMLEFT",x,16)
    RA.Theme:ApplyRounded(b,RA.Theme.Colors.surfaceRaised,5,"base")
    b.label=Text(b,text,11,10,-5,90);b:SetScript("OnClick",fn);return b
end
local function CreateWindow()
    if window then return window end
    local f=CreateFrame("Frame","RCPArsenalProtectedDisplayTest",UIParent)
    f:SetSize(640,570);f:SetPoint("CENTER",UIParent,"CENTER",0,0);f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true);f:EnableMouse(true);f:SetMovable(true);f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function(self)self:StartMoving()end)
    f:SetScript("OnDragStop",function(self)self:StopMovingOrSizing()end)
    RA.Theme:ApplyRounded(f,RA.Theme.Colors.canvasDeep,8,"base")
    Text(f,"Protected-number display test",18,20,-18,600)
    f.status=Text(f,"",12,20,-48,600);f.count=Text(f,"",11,20,-72,600)
    Text(f,"Receipt time      Event",10,20,-105,350);Text(f,"Amount",10,505,-105,100)
    f.rows={}
    -- Allocate the fixed visible pool outside combat when the test is armed.
    for i=1,P.LIMITS.visible do
        local row=CreateFrame("Frame",nil,f);row:SetSize(600,22);row:SetPoint("TOPLEFT",f,"TOPLEFT",20,-126-(i-1)*22)
        row.time=Text(row,"",11,0,-2,90);row.kind=Text(row,"",11,100,-2,100)
        row.bar=CreateFrame("StatusBar",nil,row);row.bar:SetSize(260,4);row.bar:SetPoint("TOPLEFT",row,"TOPLEFT",205,-11)
        row.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        row.amount=Text(row,"",11,485,-2,115);row.amount:SetJustifyH("RIGHT");row:Hide();f.rows[i]=row
    end
    f.note=Text(f,"",10,20,-488,600)
    Text(f,"Receipt times only. No spell names. Test values remain in memory until reload.",10,20,-508,600)
    Button(f,"COPY STATUS",20,function()
        local shown,reason=RA.DeathRecapUI:ShowDebugText(P:BuildReport());if not shown then RA:Print(reason)end
    end)
    Button(f,"CLOSE",512,function()f:Hide()end)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel",function(_,delta)
        delta=Number(math.abs(delta))and delta or 0
        if owner and owner.frozen and delta~=0 then owner.offset=math.max(0,math.min(math.max(0,#owner.rows-P.LIMITS.visible),(owner.offset or 0)+(delta<0 and 1 or -1)));P:Render()end
    end)
    f:SetScript("OnHide",function()if owner and owner.active then P:Stop("window-closed")end end)
    local width,height=Number(Read(UIParent.GetWidth,UIParent)),Number(Read(UIParent.GetHeight,UIParent))
    if width and height and width>40 and height>80 then f:SetScale(math.min(1,(width-32)/640,(height-32)/570))end
    if type(UISpecialFrames)=="table"then table.insert(UISpecialFrames,"RCPArsenalProtectedDisplayTest")end
    window=f
    return f
end
function P:Render()
    if not window or not owner then return end
    local o=owner;window.status:SetText(o.active and(o.recording and"RECORDING — incoming events only"or"ARMED — enter combat within two minutes")or o.frozen and"FROZEN — check the numbers below"or("STOPPED — "..o.reason))
    window.count:SetText(string.format("Received: %d  |  Protected: %d  |  Public: %d  |  Rejected: %d",o.count,o.protected,o.public,o.rejected))
    local rows=o.rows or{};local offset=o.offset or 0
    for i,ui in ipairs(window.rows)do
        local row=rows[#rows-offset-i+1]
        if row then
            ui.time:SetText(string.format("%.1fs",row.at-o.noticeAt));ui.kind:SetText(row.kind=="healing"and"Healing"or"Damage")
            local color=row.kind=="healing"and{.3,.9,.55}or{1,.3,.35}
            ui.kind:SetTextColor(unpack(color));ui.amount:SetTextColor(unpack(color));ui.bar:SetStatusBarColor(unpack(color))
            -- These native setters explicitly accept protected arguments. Lua
            -- never formats, sums, compares, ranks or reads back the amount.
            local scaleOK=pcall(ui.bar.SetMinMaxValues,ui.bar,0,o.referenceMaximum)
            row.barAccepted=scaleOK and pcall(ui.bar.SetValue,ui.bar,row.amount)or false
            row.textAccepted=pcall(ui.amount.SetFormattedText,ui.amount,"%d",row.amount)
            if not row.barAccepted then pcall(ui.bar.SetValue,ui.bar,0)end
            if not row.textAccepted then ui.amount:SetText("(blocked)")end
            ui.amount.__raNativeText=true;ui:Show()
        else
            -- Clear hidden slots without ever inspecting their prior text/value.
            ui.amount:SetText("");pcall(ui.bar.SetValue,ui.bar,0);ui:Hide()
        end
    end
    window.note:SetText(o.frozen and string.format("%d retained / 8 seconds%s. Newest first; scroll one row. Bars cap at %.0f.",#rows,o.partial and" — capacity exceeded"or"",o.referenceMaximum)
        or"Close or /rcp recapdebug display stop cancels this test.")
end
function P:Stop(reason)
    if not owner then return end
    Disconnect();owner.active=false;owner.recording=false;owner.frozen=false;owner.reason=reason or"explicit-stop"
    owner.slots={};owner.rows={};self:Render()
end
local function Freeze(o,at)
    Disconnect();o.active=false;o.recording=false;o.frozen=true;o.noticeAt=at;o.rows={};o.offset=0
    o.partial=o.lostAt~=nil and at-o.lostAt<=P.LIMITS.seconds
    for _,row in pairs(o.slots)do if row.at<=at and at-row.at<=P.LIMITS.seconds then o.rows[#o.rows+1]=row end end
    table.sort(o.rows,function(a,b)if a.at~=b.at then return a.at<b.at end;return a.sequence<b.sequence end)
    o.slots={};P:Render();window:Show()
end
local function Event(o,event,unit,action,_,amount)
    if owner~=o or not o.active then return end
    local at=Now();if not at or at<o.armedAt then P:Stop("clock-unavailable");return end
    if at>=o.deadline then P:Stop("timeout");return end
    if event=="PLAYER_ENTERING_WORLD"or event=="PLAYER_LOGOUT"then P:Stop("world-changed");return end
    if event=="PLAYER_REGEN_DISABLED"then
        o.recording=true;o.startedAt=at;o.metadata=Metadata();o.slots={};o.count=0;o.public=0;o.protected=0;o.rejected=0;o.lostAt=nil
        P:Render();return
    end
    if event=="PLAYER_REGEN_ENABLED"then o.recording=false;P:Render();return end
    if event=="PLAYER_DEAD"then
        if o.startedAt then Freeze(o,at)else P:Stop("no-combat-observed")end
        return
    end
    if event~="UNIT_COMBAT"or not o.recording then return end
    if String(unit)~="player"then return end
    action=String(action);if action~="WOUND"and action~="HEAL"then return end
    local secret=Secret(amount)
    if secret==nil or(secret==false and(not Number(amount)or amount>1e15))then o.rejected=o.rejected+1;return end
    o.count=o.count+1
    if secret then o.protected=o.protected+1 else o.public=o.public+1 end
    local index=(o.count-1)%P.LIMITS.rows+1;local previous=o.slots[index]
    if previous then o.lostAt=previous.at end
    o.slots[index]={at=at,kind=action=="HEAL"and"healing"or"damage",protected=secret,sequence=o.count,amount=amount}
end
function P:Start()
    local state=RA.DeathRecap:GetState()
    if not state.enabled then return false,"Enable Personal Tools > Death Recap before arming the display test"end
    if Read(UnitIsDeadOrGhost,"player")~=false or Read(InCombatLockdown)~=false then return false,"Arm the display test alive and outside combat"end
    local at=Now()
    if not at or Secret(0)~=false or not C_Timer or type(C_Timer.NewTimer)~="function"then return false,"Display test timer or public clock unavailable"end
    self:Stop("replaced")
    local ok=pcall(CreateWindow);if not ok then return false,"Display test window could not be created"end
    if not observer then observer=CreateFrame("Frame")end
    local o={active=true,recording=false,armedAt=at,deadline=at+self.LIMITS.armSeconds,count=0,protected=0,public=0,rejected=0,
        slots={},rows={},reason="armed",metadata=Metadata(),referenceMaximum=Number(Read(UnitHealthMax,"player"))or 1000000}
    if o.referenceMaximum==0 then o.referenceMaximum=1000000 end
    owner=o
    local registered=pcall(function()
        observer:RegisterUnitEvent("UNIT_COMBAT","player")
        for _,name in ipairs({"PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","PLAYER_DEAD","PLAYER_ENTERING_WORLD","PLAYER_LOGOUT"})do observer:RegisterEvent(name)end
        observer:SetScript("OnEvent",function(_,...)Event(o,...)end)
    end)
    if not registered then self:Stop("registration-failed");return false,"Display test events could not be registered"end
    local timerOK,timer=pcall(C_Timer.NewTimer,self.LIMITS.armSeconds,function()if owner==o and o.active then P:Stop("timeout")end end)
    if not timerOK or not timer then self:Stop("timer-failed");return false,"Display test timer failed"end
    expiry=timer;self:Render();window:Show()
    return true,"Display test armed for two minutes. Enter a dungeon/raid fight, die, then screenshot this test window and click COPY STATUS before /reload."
end
function P:Show()
    if not owner then return false,"No display test this login; use /rcp recapdebug display start"end
    self:Render();window:Show();return true,"Showing the current display test"
end
function P:BuildReport()
    if not owner then return "RCP protected display test: no capture this login"end
    local o=owner;local rows=o.rows or{};local protected,drawn,bars,text=0,0,0,0
    for _,row in ipairs(rows)do
        if row.protected then protected=protected+1 end
        if row.barAccepted~=nil or row.textAccepted~=nil then drawn=drawn+1 end
        if row.barAccepted then bars=bars+1 end;if row.textAccepted then text=text+1 end
    end
    local meta=o.metadata or{}
    return table.concat({"RCP protected-number display test v1", "Arsenal "..RA.VERSION,
        "Client "..(meta.version or"not recorded").." build "..(meta.build or"not recorded").."; instance "..(meta.instanceType or"not recorded").."; difficulty "..(meta.difficulty or"not recorded"),
        "State: "..(o.frozen and"frozen at own death"or o.active and"armed/recording"or o.reason),
        string.format("Received %d; public %d; protected %d; rejected %d",o.count,o.public,o.protected,o.rejected),
        string.format("Retained %d / 8 seconds; protected retained %d; partial %s",#rows,protected,o.partial and"yes"or"no"),
        string.format("Rendered rows %d; bar calls accepted %d; text calls accepted %d",drawn,bars,text),
        "Setter acceptance does not prove visible pixels; attach a screenshot.",
        "Times are local receipt times. Spell names and attackers are not supplied.",
        "Protected amounts are excluded from this report, chat, and saved history. Reload clears the test."},"\n")
end
RA:RegisterCallback("DEATH_RECAP_CHANGED",function(kind)
    if owner and(kind=="reset"or kind=="settings"and not RA.DeathRecap:GetState().enabled)then P:Stop("recap-settings-changed")end
end)
