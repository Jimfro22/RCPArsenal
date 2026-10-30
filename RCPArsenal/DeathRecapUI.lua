local _,RA=...
local UI={};RA.DeathRecapUI=UI
local R,T=RA.DeathRecap,RA.Theme
local C=T.Colors
local frame,share,bell,current,sample,examplePage
local eventPool,observationPool,usePool,healPool,healthPool={},{},{},{},{}
local healthModel,plot,layout
local Point,Size=T.SetPoint,T.SetSize
local function Text(region,value)RA:SetVisualText(region,value or "")end
local function Font(parent,size,weight,color)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    RA:ApplyFont(f,size,weight or "REGULAR",false);f:SetJustifyH("LEFT")
    f:SetTextColor(unpack(color or C.text));return f
end
local function Label(parent,text,size,x,y,width,color)
    local f=Font(parent,size,nil,color);Point(f,"TOPLEFT",parent,"TOPLEFT",x,y);f:SetWidth(width);Text(f,text);return f
end
local function Surface(owner,color,key)
    T:ApplyRounded(owner,color,8,key or"base")
end
local function Button(parent,text,width,callback)
    local b=CreateFrame("Button",nil,parent);Size(b,width,24);Surface(b,C.surfaceRaised)
    b.label=Font(b,11,"BOLD");Point(b.label,"CENTER",b,"CENTER",0,0);b.label:SetJustifyH("CENTER");Text(b.label,text)
    b:SetScript("OnClick",callback)
    b:SetScript("OnEnter",function(self)if self:IsEnabled()then T:SetRoundedColor(self,C.surfaceHover,"base")end end)
    b:SetScript("OnLeave",function(self)T:SetRoundedColor(self,C.surfaceRaised,"base")end)
    b:SetScript("OnMouseDown",function(self)if self:IsEnabled()then T:SetRoundedColor(self,C.surfacePressed,"base")end end)
    b:SetScript("OnMouseUp",function(self)T:SetRoundedColor(self,C.surfaceRaised,"base")end)
    return b
end
local function Amount(value)
    if value==nil then return"Unknown"end
    for _,unit in ipairs({{1e12,"t"},{1e9,"b"},{1e6,"m"},{1e3,"k"}})do
        if value>=unit[1]then return string.format("~%.1f%s",value/unit[1],unit[2])end
    end
    return tostring(value)
end
local function Tooltip(button,lines,spellID,itemID)
    if not GameTooltip then return end
    GameTooltip:SetOwner(button,"ANCHOR_RIGHT")
    local ok=false
    if spellID then ok=pcall(GameTooltip.SetSpellByID,GameTooltip,spellID)
    elseif itemID and GameTooltip.SetItemByID then ok=pcall(GameTooltip.SetItemByID,GameTooltip,itemID)end
    if not ok then GameTooltip:SetText(lines[1]or"Unknown")end
    for _,line in ipairs(lines)do GameTooltip:AddLine(line,.79,.77,.84,true)end
    GameTooltip:Show()
end
local function HideTooltip()if GameTooltip then GameTooltip:Hide()end end
local function Icon(parent,size)
    local b=CreateFrame("Button",nil,parent);Size(b,size,size);Surface(b,C.lineStrong)
    b.icon=b:CreateTexture(nil,"ARTWORK");Size(b.icon,size-4,size-4);Point(b.icon,"CENTER",b,"CENTER",0,0)
    b.icon:SetTexCoord(.08,.92,.08,.92)
    b.badge=Font(b,9,"BOLD");Point(b.badge,"BOTTOMRIGHT",b,"BOTTOMRIGHT",1,-2)
    b:SetScript("OnLeave",HideTooltip);return b
end
local function Artwork(button,row)
    if row.spellID and RA.RegisterSpellIcon then RA:RegisterSpellIcon(button.icon,row.spellID)
    else
        local texture=row.icon or(row.kind=="stone"and"Interface\\Icons\\INV_Stone_04"or row.kind=="potion"and"Interface\\Icons\\INV_Potion_51"or 134400)
        if RA.SetVisualTexture then RA:SetVisualTexture(button.icon,texture)else button.icon:SetTexture(texture)end
    end
end
local function Observation(row,page)
    local time=row.observedAt
    local age=time and page.diedAt and page.diedAt-time
    local state="unknown"
    if age and age>=0 and age<=R.LIMITS.seconds then
        if row.kind then
            local bagAge=row.carriedAt and page.diedAt-row.carriedAt
            if not bagAge or bagAge<0 or bagAge>R.LIMITS.seconds then state="unknown"
            elseif row.carried==false then state="absent"
            elseif row.carried==true and row.remainingUses==0 then state="empty"
            elseif row.carried==true and row.remainingUses and row.remainingUses>0 then
                if row.cooldown=="inactive"and row.usable==true and row.insufficientPower==false then state="fact"
                elseif row.cooldown=="active"then state="cooldown"end
            end
        elseif row.cooldown=="held"or row.isEnabled~=true or(row.chargeQuery~="public"and row.chargeQuery~="not_applicable")then state="unknown"
        elseif row.chargeQuery=="public"and(not row.maxCharges or row.currentCharges==nil)then state="unknown"
        elseif row.maxCharges and row.currentCharges==nil then state="unknown"
        elseif row.currentCharges==0 then state="cooldown"
        elseif row.cooldown=="active"and row.chargeQuery=="not_applicable"then state="cooldown"
        elseif row.cooldown=="inactive"or(row.currentCharges and row.currentCharges>0)then state="fact"end
    end
    local reason
    if state=="unknown"then
        if not age or age<0 or age>R.LIMITS.seconds then reason="The check is missing or too old."
        elseif row.kind then
            local bagAge=row.carriedAt and page.diedAt-row.carriedAt
            reason=(not bagAge or bagAge<0 or bagAge>R.LIMITS.seconds)and"The bag check is missing or too old."or"Item readiness could not be confirmed."
        elseif row.chargeQuery=="unreadable"then reason="The charge count could not be read."
        elseif row.cooldown=="held"or row.isEnabled~=true then reason="The spell check is unavailable."
        else reason="The cooldown or charge check is incomplete."end
    end
    return state,reason,age
end
-- Fictional Arcane Mage encounter. This page is owned only by Preview; it is
-- never attached to the recorder, retained history, inventory or sharing path.
local function SamplePage()
    return {id=0,diedAt=132,encounter={startedAt=0},exampleClass="Arcane Mage",maxHealth=100000,
        healthPoints={{offset=-4.5,hp=92000},{offset=-4.1,hp=68000},{offset=-3.2,hp=77000},
            {offset=-2.2,hp=46200},{offset=-1,hp=33300},{offset=0,hp=0}},
        heals={{spellID=2061,name="Flash Heal",offset=-3.2,amount=9000,hp=77000}},
        casts={{spellID=235450,name="Prismatic Barrier",observedAt=130.5,exampleOffset=-1.5}},
        lastAlive={supplies={
            {kind="stone",name="Healthstone",itemID=5512,carried=true,carriedAt=131.8,observedAt=131.8,remainingUses=1,
                usable=true,insufficientPower=false,cooldown="inactive",source="example",exampleState="Off cooldown"},
            {kind="potion",name="Healing potion",itemID=241304,carried=false,carriedAt=131.8,observedAt=131.8,
                cooldown="unknown",source="example",exampleState="No item"}},
            spells={{spellID=235450,name="Prismatic Barrier",category="minor",isEnabled=true,cooldown="active",observedAt=131.8,source="example",exampleState="Used"},
                {spellID=342245,name="Alter Time",category="minor",isEnabled=true,cooldown="inactive",chargeQuery="not_applicable",observedAt=131.8,source="example",exampleState="Off cooldown"},
                {spellID=45438,name="Ice Block",category="major",isEnabled=true,cooldown="active",observedAt=131.8,source="example",exampleState="Cooldown"}}},
        native={rows={{spellID=12294,name="Mortal Strike",kind="damage",amount=24000,nativeOffset=-4.1,nativeIndex=2,exampleHP=68000},
            {spellID=686,name="Shadow Bolt",kind="damage",amount=30800,nativeOffset=-2.2,nativeIndex=3,exampleHP=46200},
            {spellID=172,name="Corruption",kind="damage",amount=12900,nativeOffset=-1,nativeIndex=4,exampleHP=33300},
            {spellID=116858,name="Chaos Bolt",kind="damage",amount=38400,nativeOffset=0,nativeIndex=1,exampleHP=0,exampleOverkill=5100}}}}
end
local function IsExample()return sample==true and current~=nil and current==examplePage end
local function Place(region,point,relative,relativePoint,x,y)
    region:ClearAllPoints();Point(region,point,relative,relativePoint,x,y)
end
local function HealthNumber(value,positive)
    if type(issecretvalue)~="function"then return nil end
    local ok,secret=pcall(issecretvalue,value)
    if not ok or secret~=false or type(value)~="number"or value~=value or value==math.huge or value==-math.huge
        or value<0 or(positive and value==0)then return nil end
    return value
end
local function HealthText(value)
    local text=tostring(value)
    local integer,tail=text:match("^(%d+)(.*)$")
    if not integer or text:find("[eE]")then return text end
    repeat local n;integer,n=integer:gsub("^(%d+)(%d%d%d)","%1,%2")until n==0
    return integer..tail
end
-- Native offsets already use the accepted recap's latest timestamp as zero.
-- Keep that convention; a killing-row marker is not a new clock origin.
local function Offset(row)return row.nativeOffset end
local function X(offset)return 84+(offset-plot.left)/(plot.right-plot.left)*500 end
local function BuildHealth(page,rows,example)
    local model={origin=example and"example"or"recorded",points={},hasRaw=false,hasMarks=false}
    if example then
        model.max=page.maxHealth
        for _,point in ipairs(page.healthPoints)do model.points[#model.points+1]={offset=point.offset,hp=point.hp}end
        model.hasRaw,model.hasMarks,model.connect=true,true,true
    elseif page.native and HealthNumber(page.native.recapID,true)then
        model.max=HealthNumber(page.native.recapMaxHealth,true)
        for _,row in ipairs(rows)do
            local hp=HealthNumber(row.recordedHP)
            if hp~=nil then
                model.hasRaw=true
                if model.max and hp<=model.max then
                    model.hasMarks=true;model.points[#model.points+1]={offset=Offset(row),hp=hp,nativeIndex=row.nativeIndex}
                end
            end
        end
    end
    return model
end
local function HealthRect(index,x,y,width,height,color,alpha)
    local texture=healthPool[index]or frame:CreateTexture(nil,"ARTWORK");healthPool[index]=texture
    Size(texture,math.max(1,width),math.max(1,height));Place(texture,"TOPLEFT",frame,"TOPLEFT",x,-y)
    texture:SetColorTexture(color[1],color[2],color[3],alpha or 1);texture:Show()
end
local function DrawHealth()
    for _,texture in ipairs(healthPool)do texture:Hide()end
    frame.healthPanel:Hide();frame.healthBar:Hide();frame.healthTrack:Hide();frame.healthPoint:Hide()
    frame.healthPanel.selectedHP,frame.healthPanel.selectedMax,frame.healthPanel.selectedRatio=nil,nil,nil
    Text(frame.hp,"")
    if not healthModel.hasRaw then return end
    frame.healthPanel:Show();Text(frame.health,healthModel.origin=="example"and"Health"or"Recorded health")
    local index=0
    if healthModel.hasMarks then
        local previous
        for _,point in ipairs(healthModel.points)do
            local x,y=X(point.offset),118+(1-point.hp/healthModel.max)*75
            if healthModel.connect and previous then
                index=index+1;HealthRect(index,previous.x,previous.y,math.max(1,x-previous.x),2,C.success)
                index=index+1;HealthRect(index,x,math.min(previous.y,y),2,math.max(1,math.abs(y-previous.y)),C.success)
                index=index+1;HealthRect(index,previous.x,previous.y,math.max(1,x-previous.x),193-previous.y,C.success,.10)
            end
            index=index+1;HealthRect(index,x-2,y-2,5,5,C.textSoft)
            previous={x=x,y=y}
        end
    end
end
local function SelectHealth(page,row,example,hp,offset)
    if page~=current or example~=IsExample()then return end
    frame.healthBar:Hide();frame.healthTrack:Hide();frame.healthPoint:Hide()
    local panel=frame.healthPanel
    panel.selectedHP,panel.selectedMax,panel.selectedRatio=nil,nil,nil
    if not healthModel.hasRaw then Text(frame.hp,"");return end
    hp=HealthNumber(hp)
    local title=example and"Example health"or"Recorded health"
    panel.selectedMax=healthModel.max
    if hp==nil then Text(frame.hp,title..": Unknown");return end
    panel.selectedHP,panel.selectedMax=hp,healthModel.max
    local text=HealthText(hp)
    if healthModel.max and hp<=healthModel.max then
        local ratio=hp/healthModel.max;panel.selectedRatio=ratio
        frame.healthBar:SetMinMaxValues(0,healthModel.max);frame.healthBar:SetValue(hp)
        frame.healthBar:SetStatusBarColor(unpack(hp==0 and C.danger or C.success));frame.healthTrack:Show();frame.healthBar:Show()
        text=text.." / "..HealthText(healthModel.max)..string.format(" · %.1f%%",math.floor(ratio*1000)/10)
        if healthModel.hasMarks then
            Place(frame.healthPoint,"CENTER",frame,"TOPLEFT",X(offset),-118-(1-ratio)*75);frame.healthPoint:Show()
        end
    end
    if example then text=text..string.format(" · %.1fs",offset)end
    Text(frame.hp,text)
end
local function HealthHover()
    local panel=frame.healthPanel
    local lines={IsExample()and"Example health"or"Recorded health"}
    if IsExample()then lines[#lines+1]="Fictional Arcane Mage example; these values are not a reading of your character."
    else lines[#lines+1]="Health reported with this event; before/after-hit timing is unspecified."end
    if panel.selectedHP~=nil then lines[#lines+1]="Reported health: "..HealthText(panel.selectedHP)
    else lines[#lines+1]="Health was not recorded for this event."end
    if panel.selectedMax then
        lines[#lines+1]="Scaled to the max health supplied with this recap: "..HealthText(panel.selectedMax)
        lines[#lines+1]="This is one recap reference, not each event's maximum."
        if panel.selectedHP and panel.selectedHP>panel.selectedMax then lines[#lines+1]="This value is outside the recap scale; no bar is drawn."end
    else lines[#lines+1]="A maximum health value was not recorded; no bar is drawn."end
    Tooltip(panel,lines)
end
local function FriendlyState(row,page,example)
    local state,reason,age=Observation(row,page)
    local label=state=="fact"and"Off cooldown"or state=="cooldown"and"Cooldown"or state=="absent"and"No item"or state=="empty"and"Empty"or"Unknown"
    if not row.kind and state=="fact"and row.currentCharges and row.cooldown~="inactive"then label=row.currentCharges..(row.currentCharges==1 and" charge"or" charges")end
    if not row.kind and state=="cooldown"and row.currentCharges==0 then label="No charges"end
    local name=row.name or(row.kind=="stone"and"Healthstone"or row.kind=="potion"and"Healing potion"or"Defensive")
    local lines={name}
    if example then
        label=row.exampleState
        lines[#lines+1]="Example data · Arcane Mage"
        lines[#lines+1]=label.." in this fictional example."
        if row.spellID==235450 then
            lines[#lines+1]="Prismatic Barrier was used 1.5s before the example death."
            lines[#lines+1]="Separately checked: Cooldown. Its use does not invent a health change."
        end
        if row.spellID==45438 then lines[#lines+1]="This example chooses Ice Block."end
    else
        lines[#lines+1]=label=="Off cooldown"and"Off cooldown when checked; this does not prove it could be used at the killing hit."
            or label=="No item"and"No item in the recorded bag check."or label.." in the recorded check."
        if reason then lines[#lines+1]=reason end
        if age and age>=0 then lines[#lines+1]=string.format("Checked %.1fs before the death notice.",age)end
        if row.kind and row.carriedAt then
            lines[#lines+1]=string.format("Bag checked %.1fs before the death notice.",math.max(0,page.diedAt-row.carriedAt))
        end
        if row.remainingUses~=nil then lines[#lines+1]="Remaining uses when checked: "..row.remainingUses end
        if row.currentCharges~=nil and row.maxCharges then lines[#lines+1]="Charges when checked: "..row.currentCharges.." / "..row.maxCharges end
    end
    return label,lines
end
function UI:Hide()
    if share then share.copy:ClearFocus();share.recipient:ClearFocus();share:Hide()end;if bell then bell:Hide()end
    if frame then frame:Hide()end;sample,current,examplePage=false,nil,nil;healthModel,plot,layout=nil,nil,nil
end
local function Ensure()
    if frame then return end
    frame=CreateFrame("Frame","RCPArsenalDeathRecap",UIParent);Size(frame,640,480)
    Point(frame,"CENTER",UIParent,"CENTER",0,60);frame:SetFrameStrata("DIALOG");frame:SetClampedToScreen(true);frame:EnableMouse(true)
    Surface(frame,C.canvasDeep);T:ApplyRounded(frame,C.lineStrong,8,"border","BORDER")
    frame:Hide();frame.title=Label(frame,"Why did I die?",19,20,-18,210);RA:ApplyFont(frame.title,19,"BOLD",false)
    frame.fight=Label(frame,"Fight —",12,240,-23,92,C.textSoft)
    frame.close=Button(frame,"×",24,function()UI:Hide()end);Point(frame.close,"TOPRIGHT",frame,"TOPRIGHT",-16,-18)
    frame.share=Button(frame,"SHARE",64,function()UI:OpenShare()end);Point(frame.share,"TOPRIGHT",frame.close,"TOPLEFT",-8,0)
    frame.bell=Button(frame,"REMINDER",82,function()UI:OpenBell()end);Point(frame.bell,"TOPRIGHT",frame.share,"TOPLEFT",-8,0)
    frame.coverage=Label(frame,"",11,20,-55,220,C.textSoft)
    frame.instruction=Label(frame,"Hover a hit or item for details",11,245,-55,375,C.textSoft)
    frame.help=CreateFrame("Button",nil,frame);Size(frame.help,220,22);Point(frame.help,"TOPLEFT",frame,"TOPLEFT",20,-52)
    frame.help:SetScript("OnEnter",function(self)
        Tooltip(self,IsExample()and{"Example data · Arcane Mage","A fictional encounter to try the display. Share and reminder changes are disabled."}or{"Some details unavailable","Only captured facts are shown. Missing health or healing is not reconstructed.","Cooldown checks are observations, not proof a button could prevent the death."})
    end);frame.help:SetScript("OnLeave",HideTooltip)
    frame.healthPanel=CreateFrame("Frame",nil,frame);Size(frame.healthPanel,540,26);Point(frame.healthPanel,"TOPLEFT",frame,"TOPLEFT",80,-78);frame.healthPanel:EnableMouse(true)
    frame.healthPanel:SetScript("OnEnter",HealthHover);frame.healthPanel:SetScript("OnLeave",HideTooltip)
    frame.health=Label(frame,"Recorded health",11,20,-89,62,C.muted)
    frame.healthBar=CreateFrame("StatusBar",nil,frame.healthPanel);Size(frame.healthBar,200,7);Point(frame.healthBar,"TOPLEFT",frame.healthPanel,"TOPLEFT",4,-9)
    frame.healthBar:SetStatusBarTexture(T.Assets.White)
    frame.healthTrack=frame.healthPanel:CreateTexture(nil,"BACKGROUND");Size(frame.healthTrack,200,7);Point(frame.healthTrack,"TOPLEFT",frame.healthPanel,"TOPLEFT",4,-9);frame.healthTrack:SetColorTexture(unpack(C.surfaceRaised))
    frame.hp=Font(frame.healthPanel,13,"BOLD");Point(frame.hp,"TOPLEFT",frame.healthPanel,"TOPLEFT",214,-3);frame.hp:SetWidth(320)
    frame.healthPoint=frame:CreateTexture(nil,"OVERLAY");Size(frame.healthPoint,8,8);frame.healthPoint:SetColorTexture(unpack(T:GetAccentEnd()))
    frame.damage=Label(frame,"Damage",12,20,-229,60,C.textSoft)
    frame.empty=Label(frame,"No hit details recorded",12,84,-229,500,C.muted)
    frame.healing=Label(frame,"Healing",12,20,-289,60,C.textSoft)
    frame.uses=Label(frame,"Used",12,20,-334,60,C.textSoft)
    frame.useText=Label(frame,"",11,84,-334,500,C.textSoft)
    frame.ticks={};for index=1,4 do frame.ticks[index]=Font(frame,11,nil,C.textSoft)end
    frame.axis,frame.axisEnd=frame.ticks[1],frame.ticks[4]
    frame.guide=frame:CreateTexture(nil,"ARTWORK");Size(frame.guide,1,240);frame.guide:SetColorTexture(unpack(C.lineStrong));frame.guide:Hide()
    frame.skull=frame:CreateTexture(nil,"ARTWORK");Size(frame.skull,22,22)
    if RA.SetVisualTexture then RA:SetVisualTexture(frame.skull,"Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")else frame.skull:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")end
    frame.divider=frame:CreateTexture(nil,"ARTWORK");Size(frame.divider,600,1);frame.divider:SetColorTexture(unpack(C.lineStrong))
    frame.last=Label(frame,"Defensives & items",13,20,-399,330);RA:ApplyFont(frame.last,13,"BOLD",false)
    frame.observationEmpty=Label(frame,"No item or defensive details recorded",11,20,-432,500,C.muted)
    frame.details=Button(frame,"DETAILS ›",68,function()end);Size(frame.details,68,28);frame.details:SetEnabled(false);frame.details:SetAlpha(.5)
    frame.details:SetScript("OnEnter",function(self)Tooltip(self,{"More details are not available yet"})end);frame.details:SetScript("OnLeave",HideTooltip)
    frame:SetScript("OnHide",function()if share then share:Hide()end;if bell then bell:Hide()end;HideTooltip()end)
    if UISpecialFrames then table.insert(UISpecialFrames,"RCPArsenalDeathRecap")end
end
function UI:Render()
    if not frame or not current then return end
    local page,example=current,IsExample()
    Text(frame.coverage,example and"Example data · Arcane Mage"or"Some details unavailable")
    local encounter=page.encounter;local elapsed=encounter and encounter.startedAt and page.diedAt-encounter.startedAt
    Text(frame.fight,elapsed and elapsed>=0 and string.format("Fight %d:%02d",math.floor(elapsed/60),math.floor(elapsed%60))or"Fight —")
    frame.share:SetEnabled(not example);frame.share:SetAlpha(example and .45 or 1)
    frame.bell:SetEnabled(not example);frame.bell:SetAlpha(example and .45 or 1)
    for _,pool in ipairs({eventPool,observationPool,usePool,healPool})do for _,b in ipairs(pool)do b:Hide()end end
    local rows=page.native and page.native.rows or{}
    plot={left=example and-4.5 or 0,right=0}
    for _,row in ipairs(rows)do local offset=Offset(row);plot.left=math.min(plot.left,offset);plot.right=math.max(plot.right,offset)end
    if plot.right-plot.left<.1 then plot.left=plot.left-.1 end
    healthModel=BuildHealth(page,rows,example)
    local healthHeight=healthModel.hasMarks and 128 or healthModel.hasRaw and 42 or 0
    layout={hit=84+healthHeight,heal=278,used=323,axis=365,footer=394,height=480}
    if not example then
        layout.hit=96+healthHeight;layout.axis=layout.hit+76
        layout.used=layout.axis+31;layout.footer=layout.used+46;layout.height=layout.footer+81
        if #(page.casts or{})==0 then layout.footer=layout.axis+34;layout.height=layout.footer+81 end
    end
    frame.health:SetWidth(example and 62 or 108)
    Place(frame.healthBar,"TOPLEFT",frame.healthPanel,"TOPLEFT",example and 4 or 56,-9)
    Place(frame.healthTrack,"TOPLEFT",frame.healthPanel,"TOPLEFT",example and 4 or 56,-9)
    Place(frame.hp,"TOPLEFT",frame.healthPanel,"TOPLEFT",example and 214 or 266,-3);frame.hp:SetWidth(example and 320 or 268)
    frame.health:SetShown(healthModel.hasRaw);DrawHealth()
    Place(frame.damage,"TOPLEFT",frame,"TOPLEFT",20,-layout.hit-17)
    Place(frame.empty,"TOPLEFT",frame,"TOPLEFT",84,-layout.hit-17);frame.empty:SetShown(#rows==0)
    local ordered={};for _,row in ipairs(rows)do ordered[#ordered+1]=row end
    table.sort(ordered,function(a,b)return a.nativeOffset==b.nativeOffset and a.nativeIndex<b.nativeIndex or a.nativeOffset<b.nativeOffset end)
    local groups={}
    for _,row in ipairs(ordered)do local x=X(Offset(row));local g=groups[#groups]
        if g and x-g.x<48 then g.rows[#g.rows+1]=row else groups[#groups+1]={x=x,rows={row}}end
    end
    local allDamage=#rows>0;for _,row in ipairs(rows)do if row.kind~="damage"then allDamage=false end end
    Text(frame.damage,allDamage and"Damage"or"Events")
    local ticks={plot.left,plot.left+(plot.right-plot.left)/3,plot.left+2*(plot.right-plot.left)/3,0}
    if example then ticks={-4.5,-3,-1.5,0}end
    for index,label in ipairs(frame.ticks)do
        Place(label,"TOP",frame,"TOPLEFT",X(ticks[index]),-layout.axis)
        Text(label,index==4 and"Death"or string.format("%s%.1fs",ticks[index]<0 and"−"or"+",math.abs(ticks[index])));label:SetShown(#rows>0)
    end
    frame.guide:Hide();frame.skull:Hide()
    for _,row in ipairs(rows)do if row.nativeIndex==1 then
        Place(frame.skull,"CENTER",frame,"TOPLEFT",X(Offset(row)),-layout.hit+17);frame.skull:Show()
    end end
    local function Choose(row,hp,offset)
        if page~=current or example~=IsExample()then return end
        Place(frame.guide,"TOP",frame,"TOPLEFT",X(offset),healthModel.hasMarks and-118 or-layout.hit)
        Size(frame.guide,1,layout.axis-(healthModel.hasMarks and 118 or layout.hit));frame.guide:Show()
        SelectHealth(page,row,example,hp,offset)
    end
    for index,g in ipairs(groups)do
        local b=eventPool[index]or Icon(frame,44);eventPool[index]=b;b.group,b.selected=g,1
        for i,member in ipairs(g.rows)do if member.nativeIndex==1 then b.selected=i end end
        Place(b,"TOPLEFT",frame,"TOPLEFT",g.x-22,-layout.hit);b:Show()
        b.amount=b.amount or Font(b,13,"BOLD");b.amount:SetWidth(82);b.amount:SetJustifyH("CENTER");Place(b.amount,"TOP",b,"BOTTOM",0,-5)
        local function Select()
            if page~=current or example~=IsExample()then return end
            local row=g.rows[b.selected];Artwork(b,row)
            Text(b.amount,(row.kind=="damage"and row.amount~=nil and"−"or"")..Amount(row.amount));Text(b.badge,#g.rows>1 and"×"..#g.rows or"")
            T:SetRoundedColor(b,row.nativeIndex==1 and C.danger or C.lineStrong,"base")
            local mapping=not example and R:GetJournalMapping(page,row)
            if mapping then
                b.journal=b.journal or Button(b,"J",14,function()end)
                b.journal:SetScript("OnClick",function()local _,reason=R:OpenJournal(page,g.rows[b.selected]);RA:Print(reason)end)
                b.journal:SetEnabled(not InCombatLockdown());Place(b.journal,"BOTTOMRIGHT",b,"TOPRIGHT",0,2);b.journal:Show()
            elseif b.journal then b.journal:Hide()end
        end
        Select()
        b:SetScript("OnClick",function()if page~=current then return end;b.selected=b.selected%#g.rows+1;Select();b:GetScript("OnEnter")(b)end)
        b:SetScript("OnEnter",function(self)
            if page~=current or example~=IsExample()then return end
            local row=g.rows[b.selected];local offset=Offset(row)
            Choose(row,example and row.exampleHP or row.recordedHP,offset)
            local eventName=row.kind=="damage"and"Recorded hit"or"Recorded event"
            local lines={row.name or eventName,row.nativeIndex==1 and"Killing blow"or eventName,row.amount~=nil and"Amount: "..tostring(row.amount)or"Amount not recorded"}
            if example then lines[#lines+1]="Example data · fictional Arcane Mage encounter"end
            if example and row.exampleOverkill then lines[#lines+1]="Example overkill: "..HealthText(row.exampleOverkill)end
            if #g.rows>1 then lines[#lines+1]="Grouped events; click to view each event"
                for _,member in ipairs(g.rows)do lines[#lines+1]=string.format("%.2fs · %s",Offset(member),member.name or"Unknown hit")end
            end
            Tooltip(self,lines,row.spellID)
        end)
    end
    frame.healing:SetShown(example)
    if example then
        Place(frame.healing,"TOPLEFT",frame,"TOPLEFT",20,-layout.heal-11)
        for index,heal in ipairs(page.heals)do
            local b=healPool[index]or Icon(frame,28);healPool[index]=b
            Place(b,"TOPLEFT",frame,"TOPLEFT",X(heal.offset)-14,-layout.heal);Artwork(b,heal);Text(b.badge,"");b:Show()
            b.amount=b.amount or Font(b,11,"BOLD",C.success);Place(b.amount,"TOP",b,"BOTTOM",0,-3);Text(b.amount,"+"..Amount(heal.amount))
            b:SetScript("OnEnter",function(self)
                if page~=current or not IsExample()then return end
                Choose(heal,heal.hp,heal.offset);Tooltip(self,{heal.name,"Example healing received: "..HealthText(heal.amount),"Example data; not a recorded real heal."},heal.spellID)
            end)
        end
    end
    local casts=page.casts or{};local count=math.min(#casts,8)
    frame.uses:SetShown(example or count>0);Place(frame.uses,"TOPLEFT",frame,"TOPLEFT",20,-layout.used-11)
    Text(frame.useText,#casts>8 and"Showing 8 of "..#casts.." casts"or"");Place(frame.useText,"TOPLEFT",frame,"TOPLEFT",350,-layout.used-7)
    for index=1,count do
        local b=usePool[index]or Icon(frame,24);usePool[index]=b;local cast=casts[#casts-count+index]
        local x=example and X(cast.exampleOffset)-12 or 84+(index-1)*32
        Place(b,"TOPLEFT",frame,"TOPLEFT",x,-layout.used);Artwork(b,cast);Text(b.badge,"");b:Show()
        b.nameLabel=b.nameLabel or Font(b,11,"BOLD",C.textSoft)
        Place(b.nameLabel,"LEFT",b,"RIGHT",7,0);Text(b.nameLabel,example and cast.name or"");b.nameLabel:SetShown(example)
        b:SetScript("OnEnter",function(self)
            if page~=current or example~=IsExample()then return end
            local lines={cast.name or"Used",example and"Example data · used 1.5s before the example death"or"Recorded cast; its effect duration is not shown."}
            if not example and cast.observedAt and page.diedAt>=cast.observedAt then
                lines[#lines+1]=string.format("Recorded %.1fs before the death notice.",page.diedAt-cast.observedAt)
            end
            Tooltip(self,lines,cast.spellID)
        end)
    end
    local tray={}
    if page.lastAlive then
        for _,row in ipairs(page.lastAlive.supplies)do tray[#tray+1]=row end
        if example then for _,row in ipairs(page.lastAlive.spells)do tray[#tray+1]=row end
        else for _,category in ipairs({"major","minor"})do for _,row in ipairs(page.lastAlive.spells)do if row.category==category then tray[#tray+1]=row end end end end
    end
    Place(frame.divider,"TOPLEFT",frame,"TOPLEFT",20,-layout.footer+9)
    Place(frame.last,"TOPLEFT",frame,"TOPLEFT",20,-layout.footer)
    Place(frame.details,"TOPRIGHT",frame,"TOPRIGHT",-20,-layout.footer-31)
    Place(frame.observationEmpty,"TOPLEFT",frame,"TOPLEFT",20,-layout.footer-33);frame.observationEmpty:SetShown(#tray==0)
    for index,row in ipairs(tray)do
        local b=observationPool[index]or Icon(frame,32);observationPool[index]=b
        local column,line=(index-1)%5,math.floor((index-1)/5)
        Place(b,"TOP",frame,"TOPLEFT",74+column*100,-layout.footer-20-line*64)
        local label,lines=FriendlyState(row,page,example);Artwork(b,row);Text(b.badge,"")
        local positive=label=="Off cooldown"or label:find("charge",1,true)and label~="No charges"
        b.icon:SetAlpha((positive or label=="Used")and 1 or label=="Unknown"and .7 or .35)
        b.stateLabel=b.stateLabel or Font(b,11,nil,C.textSoft);b.stateLabel:SetWidth(98);b.stateLabel:SetJustifyH("CENTER")
        Place(b.stateLabel,"TOP",b,"BOTTOM",0,-4);Text(b.stateLabel,label)
        T:SetRoundedColor(b,positive and C.success or C.lineStrong,"base");b:Show()
        b:SetScript("OnEnter",function(self)if page==current and example==IsExample()then Tooltip(self,lines,row.spellID,row.itemID)end end)
    end
    local extra=math.max(0,math.ceil(#tray/5)-1)*64;Size(frame,640,layout.height+extra)
    local selected
    if example then for _,row in ipairs(ordered)do if row.nativeIndex~=1 and(not selected or row.nativeOffset>selected.nativeOffset)then selected=row end end
    else
        for _,row in ipairs(ordered)do if row.nativeIndex==1 then selected=row;break end end
        selected=selected or ordered[1]
    end
    if selected then Choose(selected,example and selected.exampleHP or selected.recordedHP,Offset(selected))end
end
function UI:ShowLast()
    local page=R:GetPage();if not page then RA:Print("No recap recorded this session");return false end
    self:Hide();Ensure();current,sample=page,false;self:Render();frame:Show();return true
end
function UI:Preview()
    self:Hide();Ensure();examplePage=SamplePage();current,sample=examplePage,true;self:Render();frame:Show();return true
end
function UI:OpenBell()
    if sample then return end
    if share then share:Hide()end
    if not bell then
        bell=CreateFrame("Frame",nil,frame);Size(bell,350,110);Point(bell,"TOPRIGHT",frame,"TOPRIGHT",-16,-48);Surface(bell,C.surface)
        Label(bell,"Enable the existing consumable reminder?",12,12,-12,326)
        Label(bell,"Your threshold, sound and appearance stay saved.",10,12,-34,326,C.textSoft)
        local enable=Button(bell,"ENABLE",100,function()
            if not sample and bell:IsShown()and current==R:GetPage()then R:EnableReminder()end;bell:Hide()
        end);Point(enable,"BOTTOMLEFT",bell,"BOTTOMLEFT",12,12)
        local cancel=Button(bell,"CANCEL",100,function()bell:Hide()end);Point(cancel,"BOTTOMRIGHT",bell,"BOTTOMRIGHT",-12,12)
    end
    if RA.PersonalTools:GetState().consumableReminder then RA:OpenConfig("MYTOOLS");return end
    bell:Show()
end
function UI:OpenShare()
    if sample or not current or current~=R:GetPage()then return end
    if bell then bell:Hide()end
    if not share then
        share=CreateFrame("Frame",nil,frame);Size(share,430,218);Point(share,"TOPRIGHT",frame,"TOPRIGHT",-16,-48);Surface(share,C.surface)
        share.copy=CreateFrame("EditBox",nil,share,"InputBoxTemplate");Size(share.copy,398,42);Point(share.copy,"TOPLEFT",share,"TOPLEFT",16,-14);share.copy:SetAutoFocus(false);share.copy:SetMultiLine(true)
        RA:ApplyFont(share.copy,11,"REGULAR",false)
        share.recipient=CreateFrame("EditBox",nil,share,"InputBoxTemplate");Size(share.recipient,250,24);Point(share.recipient,"TOPLEFT",share,"TOPLEFT",16,-106);share.recipient:SetAutoFocus(false);share.recipient:SetMaxLetters(80)
        RA:ApplyFont(share.recipient,11,"REGULAR",false)
        share.targetLabel=Label(share,"Whisper recipient",10,16,-87,250,C.muted)
        share.status=Label(share,"Review in chat; this button never sends.",10,16,-141,398,C.textSoft)
        local channels={"WHISPER","SAY","PARTY","RAID"}
        for index,channel in ipairs(channels)do
            local b=Button(share,channel,92,function()share.channel=channel;share.recipient:SetShown(channel=="WHISPER");share.targetLabel:SetShown(channel=="WHISPER")end)
            Point(b,"TOPLEFT",share,"TOPLEFT",16+(index-1)*100,-60)
        end
        local open=Button(share,"OPEN CHAT",140,function()
            if sample or not share:IsShown()or current~=R:GetPage()then return end
            local _,reason=R:PrepareShare(share.channel,share.recipient:GetText(),current);Text(share.status,reason)
        end);Point(open,"BOTTOMLEFT",share,"BOTTOMLEFT",16,12)
        local close=Button(share,"CLOSE",92,function()share:Hide()end);Point(close,"BOTTOMRIGHT",share,"BOTTOMRIGHT",-16,12)
    end
    share.copy:SetText(R:BuildShareText(current));share.channel="WHISPER";share.recipient:Show();share.targetLabel:Show();share:Show()
end
function UI:CreateSettings(parent,kit)
    local group=CreateFrame("Frame",nil,parent);Size(group,918,112)
    local expanded=false
    local toggle=kit.Toggle(group,"Death Recap","Review your own death using available recorded data.",
        function()return R:GetState().enabled end,function(value)R:SetOption("enabled",value);kit.Refresh()end)
    T.SetWidth(toggle,918);Point(toggle,"TOPLEFT",group,"TOPLEFT",0,0);toggle:SetCompact(true)
    local view=kit.Button(group,"VIEW LAST",130,30,function()UI:ShowLast()end);Point(view,"TOPLEFT",group,"TOPLEFT",0,-52)
    local preview=kit.Button(group,"PREVIEW RECAP",130,30,function()UI:Preview()end);Point(preview,"LEFT",view,"RIGHT",10,0)
    local settings=kit.Button(group,"DISPLAY +",130,30,function()expanded=not expanded;kit.Refresh()end);Point(settings,"LEFT",preview,"RIGHT",10,0)
    local auto=kit.Toggle(group,"Open after my death","Closing or resurrecting keeps the last recap for manual review.",function()return R:GetState().autoOpen end,function(value)R:SetOption("autoOpen",value);kit.Refresh()end)
    T.SetWidth(auto,918);Point(auto,"TOPLEFT",group,"TOPLEFT",0,-100);auto:SetCompact(true)
    function group:Refresh()
        local state=R:GetState();view:SetEnabled(state.hasPage);view:SetAlpha(state.hasPage and 1 or .45)
        Text(settings.label,expanded and"DISPLAY −"or"DISPLAY +");auto:SetShown(expanded);self:SetHeight(expanded and 156 or 96)
    end
    RA:RegisterCallback("DEATH_RECAP_CHANGED",function(kind)if kind=="settings"or kind=="death"then kit.Refresh()end end)
    group:Refresh();return group
end
RA:RegisterCallback("DEATH_RECAP_CHANGED",function(kind)
    if kind=="death"then UI:Hide();if R:GetState().autoOpen then UI:ShowLast()end
    elseif kind=="life"or(kind=="settings"and not R:GetState().enabled)then UI:Hide()
    elseif kind=="native"and frame and frame:IsShown()and not sample and current==R:GetPage()then UI:Render()end
end)
RA:RegisterCallback("ACCENT_THEME_CHANGED",function()if frame and frame:IsShown()then UI:Render()end end)
