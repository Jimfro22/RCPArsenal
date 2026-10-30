local _,RA=...
local UI={};RA.DeathRecapUI=UI
local R,T=RA.DeathRecap,RA.Theme
local C=T.Colors
local frame,share,bell,current,sample
local eventPool,observationPool,usePool={},{},{}
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
    b.label=Font(b,10,"BOLD");Point(b.label,"CENTER",b,"CENTER",0,0);b.label:SetJustifyH("CENTER");Text(b.label,text)
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
        elseif row.cooldown=="inactive"or(row.currentCharges and row.currentCharges>0)then state="fact"end
    end
    local name=row.name or(row.kind=="stone"and"Healthstone"or"Healing potion")
    local lines={name,"Frozen last-alive observation; full pre-fatal castability is unknown.",
        age and age>=0 and string.format("Observed %.1fs before local death notification",age)or"Observation time unavailable",
        "Source: "..(row.source or"Unknown"),"Native cooldown: "..(row.cooldown or"Unknown")}
    if row.itemID then
        lines[#lines+1]="Item "..row.itemID.."; this item only"
        lines[#lines+1]=row.remainingUses~=nil and("Remaining uses observed: "..row.remainingUses)or"Remaining uses: Unknown"
        lines[#lines+1]="Carriage and cooldown have independent observation times; known item families only."
    elseif row.maxCharges then lines[#lines+1]="Charges: "..(row.currentCharges~=nil and row.currentCharges or"Unknown").." / "..row.maxCharges end
    if row.kind then lines[#lines+1]=row.carriedAt and string.format("Bag cache evaluated %.1fs before local death notification",math.max(0,page.diedAt-row.carriedAt))or"Bag observation time: Unknown"end
    if state=="unknown"then lines[#lines+1]="Unknown or stale; no unavailable/unused inference"end
    return state,lines
end
local function SamplePage()
    return {sample=true,id=0,diedAt=10,coverage="Illustrative data only",casts={{spellID=871,observedAt=8}},
        lastAlive={supplies={{kind="stone",itemID=5512,carried=true,carriedAt=9.8,observedAt=9.8,remainingUses=1,usable=true,insufficientPower=false,cooldown="inactive",source="sample"}},
            spells={{spellID=871,name="Shield Wall",category="major",cooldown="unknown",source="sample"}}},
        native={rows={{spellID=12294,amount=24000,nativeOffset=-4.5,nativeIndex=2,event="SPELL_DAMAGE"},
            {spellID=686,amount=30800,nativeOffset=-2.5,nativeIndex=3,event="SPELL_DAMAGE"},
            {spellID=172,amount=12900,nativeOffset=-1.2,nativeIndex=4,event="SPELL_DAMAGE"},
            {spellID=116858,amount=38400,nativeOffset=0,nativeIndex=1,event="SPELL_DAMAGE"}}}}
end
function UI:Hide()
    if share then share.copy:ClearFocus();share.recipient:ClearFocus();share:Hide()end;if bell then bell:Hide()end
    if frame then frame:Hide()end;sample,current=false,nil
end
local function Ensure()
    if frame then return end
    frame=CreateFrame("Frame","RCPArsenalDeathRecap",UIParent);Size(frame,560,325)
    Point(frame,"CENTER",UIParent,"CENTER",0,80);frame:SetFrameStrata("DIALOG");frame:SetClampedToScreen(true);frame:EnableMouse(true)
    Surface(frame,C.canvasDeep);T:ApplyRounded(frame,C.lineStrong,8,"border","BORDER")
    frame:Hide();frame.title=Label(frame,"Why did I die?",17,19,-17,180)
    RA:ApplyFont(frame.title,17,"BOLD",false)
    frame.fight=Label(frame,"Fight —",10,190,-22,100,C.muted)
    frame.close=Button(frame,"×",24,function()UI:Hide()end);Point(frame.close,"TOPRIGHT",frame,"TOPRIGHT",-14,-17)
    frame.share=Button(frame,"SHARE",58,function()UI:OpenShare()end);Point(frame.share,"TOPRIGHT",frame.close,"TOPLEFT",-8,0)
    frame.bell=Button(frame,"REMINDER",72,function()UI:OpenBell()end);Point(frame.bell,"TOPRIGHT",frame.share,"TOPLEFT",-6,0)
    frame.coverage=Label(frame,"Partial recap",10,19,-54,520,C.muted)
    frame.health=Label(frame,"Health history unavailable",11,75,-84,300,C.textSoft)
    frame.hp=Label(frame,"HP snapshot —",10,400,-84,140,C.muted)
    frame.damage=Label(frame,"Damage",9,19,-119,56,C.muted)
    frame.empty=Label(frame,"No readable recap data",11,75,-121,435,C.muted)
    frame.healing=Label(frame,"Healing",9,19,-179,56,C.muted)
    Label(frame,"Not recorded",10,75,-179,430,C.muted)
    frame.uses=Label(frame,"Uses",9,19,-219,56,C.muted)
    frame.useText=Label(frame,"Not recorded",10,75,-219,430,C.muted)
    frame.axis=Label(frame,"Native recap time unavailable",10,75,-250,220,C.muted)
    frame.axisEnd=Font(frame,10,nil,C.muted);Point(frame.axisEnd,"TOPRIGHT",frame,"TOPLEFT",507,-250);frame.axisEnd:SetJustifyH("RIGHT")
    frame.guide=frame:CreateTexture(nil,"ARTWORK");Size(frame.guide,1,145);frame.guide:SetColorTexture(unpack(C.lineStrong));frame.guide:Hide()
    frame.skull=frame:CreateTexture(nil,"ARTWORK");Size(frame.skull,20,20)
    if RA.SetVisualTexture then RA:SetVisualTexture(frame.skull,"Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")else frame.skull:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")end
    frame.skull:Hide()
    frame.last=Label(frame,"Last\nobserved",9,19,-286,58,C.muted)
    frame.observationEmpty=Label(frame,"Last-alive evidence unavailable",10,78,-293,330,C.muted)
    frame.details=Button(frame,"DETAILS ›",74,function()end);Point(frame.details,"TOPRIGHT",frame,"TOPRIGHT",-19,-286);frame.details:SetEnabled(false);frame.details:SetAlpha(.5)
    frame.details:SetScript("OnEnter",function(self)Tooltip(self,{"Advanced details are not part of this first build"})end);frame.details:SetScript("OnLeave",HideTooltip)
    frame:SetScript("OnHide",function()if share then share:Hide()end;if bell then bell:Hide()end;HideTooltip()end)
    if UISpecialFrames then table.insert(UISpecialFrames,"RCPArsenalDeathRecap")end
end
function UI:Render()
    if not frame or not current then return end
    local page=current
    Text(frame.coverage,sample and"Sample preview · Partial recap"or"Partial recap · observed facts only; castability unknown")
    local encounter=page.encounter;local elapsed=encounter and encounter.startedAt and page.diedAt-encounter.startedAt
    Text(frame.fight,elapsed and elapsed>=0 and string.format("Fight %d:%02d",math.floor(elapsed/60),math.floor(elapsed%60))or"Fight —")
    frame.share:SetEnabled(not sample);frame.share:SetAlpha(sample and .45 or 1)
    frame.bell:SetEnabled(not sample);frame.bell:SetAlpha(sample and .45 or 1)
    for _,pool in ipairs({eventPool,observationPool,usePool})do for _,b in ipairs(pool)do b:Hide()end end
    local rows=page.native and page.native.rows or{}
    local ordered={};for _,row in ipairs(rows)do ordered[#ordered+1]=row end
    table.sort(ordered,function(a,b)return a.nativeOffset==b.nativeOffset and a.nativeIndex<b.nativeIndex or a.nativeOffset<b.nativeOffset end)
    local left=ordered[1]and math.min(-.1,ordered[1].nativeOffset)or-1
    local groups={}
    for _,row in ipairs(ordered)do
        local x=75+(row.nativeOffset-left)/(-left)*432
        local g=groups[#groups]
        if g and x-g.x<42 then g.rows[#g.rows+1]=row else groups[#groups+1]={x=x,rows={row}}end
    end
    frame.empty:SetShown(#groups==0)
    local allDamage=#rows>0;for _,row in ipairs(rows)do if row.kind~="damage"then allDamage=false end end
    Text(frame.damage,#groups>0 and(allDamage and"Damage"or"Records")or"Damage")
    Text(frame.axis,#groups>0 and string.format("%.1fs native",left)or"Native recap time unavailable")
    Text(frame.axisEnd,#groups>0 and"0s native"or"");frame.guide:Hide();frame.skull:Hide()
    for _,row in ipairs(rows)do if row.nativeIndex==1 then
        Point(frame.skull,"CENTER",frame,"TOPLEFT",75+(row.nativeOffset-left)/(-left)*432,-79);frame.skull:Show()
    end end
    for index,g in ipairs(groups)do
        local b=eventPool[index]or Icon(frame,38);eventPool[index]=b
        b.group,b.selected=g,1
        for i,member in ipairs(g.rows)do if member.nativeIndex==1 then b.selected=i end end
        Point(b,"TOPLEFT",frame,"TOPLEFT",g.x-19,-103);b:Show()
        b.amount=b.amount or Font(b,10,"BOLD");b.amount:SetWidth(74);b.amount:SetJustifyH("CENTER");Point(b.amount,"TOP",b,"BOTTOM",0,-5)
        local function Select()
            local row=g.rows[b.selected];Artwork(b,row)
            Text(b.amount,Amount(row.amount))
            local fatal=row.nativeIndex==1
            Text(b.badge,#g.rows>1 and"×"..#g.rows or"")
            T:SetRoundedColor(b,fatal and C.danger or C.lineStrong,"base")
            local mapping=not sample and R:GetJournalMapping(page,row)
            if mapping then
                b.journal=b.journal or Button(b,"J",14,function()end)
                b.journal:SetScript("OnClick",function()local _,reason=R:OpenJournal(page,g.rows[b.selected]);RA:Print(reason)end)
                b.journal:SetEnabled(not InCombatLockdown())
                b.journal:SetScript("OnEnter",function(self)Tooltip(self,{InCombatLockdown()and"Available after combat"or"Open verified Journal entry"})end)
                Point(b.journal,"BOTTOMRIGHT",b,"TOPRIGHT",0,2);b.journal:Show()
            elseif b.journal then b.journal:Hide()end
        end
        Select()
        b:SetScript("OnClick",function()b.selected=b.selected%#g.rows+1;Select();b:GetScript("OnEnter")(b)end)
        b:SetScript("OnEnter",function(self)
            local row=g.rows[b.selected];local lines={row.name or"Native record",string.format("Native offset %.2fs",row.nativeOffset),row.nativeIndex==1 and"Native killing blow"or"Recorded event",row.amount~=nil and"Recorded amount: "..tostring(row.amount)or"Recorded amount: Unknown"}
            Point(frame.guide,"TOP",frame,"TOPLEFT",75+(row.nativeOffset-left)/(-left)*432,-103);frame.guide:Show()
            if #g.rows>1 then
                lines[#lines+1]="Grouped events; click to cycle exact records"
                for _,member in ipairs(g.rows)do lines[#lines+1]=string.format("%.2fs · %s%s",member.nativeOffset,member.name or"Unknown event",member.nativeIndex==1 and" · native killing blow"or"")end
            end
            Tooltip(self,lines,row.spellID)
        end)

    end
    local casts=page.casts or{};local count=math.min(#casts,8)
    Text(frame.useText,#casts>0 and"Cast recorded · Time not aligned"or"Not recorded")
    frame.useText:ClearAllPoints();Point(frame.useText,"TOPLEFT",frame,"TOPLEFT",#casts>0 and 300 or 75,-219);frame.useText:SetWidth(#casts>0 and 240 or 430)
    for index=1,count do
        local b=usePool[index]or Icon(frame,20);usePool[index]=b;local cast=casts[#casts-count+index]
        Point(b,"TOPLEFT",frame,"TOPLEFT",75+(index-1)*26,-211);Artwork(b,cast);Text(b.badge,"");b:Show()
        b:SetScript("OnEnter",function(self)Tooltip(self,{"Successful cast recorded","Local receipt time; not aligned to native damage timeline"},cast.spellID)end)
    end
    if #casts>8 then Text(frame.useText,"Last 8 of "..#casts.." recorded casts · unaligned")end
    local tray={}
    if page.lastAlive then
        for _,row in ipairs(page.lastAlive.supplies)do tray[#tray+1]=row end
        for _,category in ipairs({"major","minor"})do for _,row in ipairs(page.lastAlive.spells)do if row.category==category then tray[#tray+1]=row end end end
    end
    frame.observationEmpty:SetShown(#tray==0)
    for index,row in ipairs(tray)do
        local b=observationPool[index]or Icon(frame,30);observationPool[index]=b
        Point(b,"TOPLEFT",frame,"TOPLEFT",78+((index-1)%8)*39,-282-math.floor((index-1)/8)*40)
        local state,lines=Observation(row,page);Artwork(b,row)
        local positive=state=="fact";local unknown=state=="unknown"
        b.icon:SetAlpha(positive and 1 or unknown and .7 or .35)
        Text(b.badge,positive and"✓"or unknown and"?"or"×")
        T:SetRoundedColor(b,positive and C.success or C.lineStrong,"base");b:Show()
        b:SetScript("OnEnter",function(self)Tooltip(self,lines,row.spellID,row.itemID)end)
    end
    local extra=math.max(0,math.ceil(#tray/8)-1)*40;Size(frame,560,325+extra)
end
function UI:ShowLast()
    local page=R:GetPage();if not page then RA:Print("No recap recorded this session");return false end
    self:Hide();Ensure();current,sample=page,false;self:Render();frame:Show();return true
end
function UI:Preview()
    self:Hide();Ensure();current,sample=SamplePage(),true;self:Render();frame:Show();return true
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
