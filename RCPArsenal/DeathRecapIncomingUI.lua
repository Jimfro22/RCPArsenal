local _,RA=...
local U,T=RA.DeathRecapUI,RA.Theme
local C=T.Colors
local function Text(region,value)RA:SetVisualText(region,value or"")end
local function Place(region,point,parent,relative,x,y)region:ClearAllPoints();T.SetPoint(region,point,parent,relative,x,y)end
local function Font(parent,size,color)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    RA:ApplyFont(f,size,"REGULAR",false);f:SetTextColor(unpack(color or C.text));f:SetJustifyH("LEFT");return f
end
local function Amount(n)
    for _,unit in ipairs({{1e12,"t"},{1e9,"b"},{1e6,"m"},{1e3,"k"}})do
        if n>=unit[1]then return string.format(n%unit[1]==0 and"%.0f%s"or"%.1f%s",n/unit[1],unit[2])end
    end
    return string.format("%.0f",n)
end
local function Exact(n)return(string.format("%.0f",n):reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,",""))end
local schools={[1]="Physical",[2]="Holy",[4]="Fire",[8]="Nature",[16]="Frost",[32]="Shadow",[64]="Arcane"}
function U:UpdateIncomingSelector(parent,incoming,mode,choose,help)
    if incoming.sessionOnlyExpired and not parent.incomingNotice then
        parent.incomingNotice=Font(parent,10,C.muted);Place(parent.incomingNotice,"TOPLEFT",parent,"TOPLEFT",48,-65)
        Text(parent.incomingNotice,"Live amounts cleared. They last until reload or reset.")
    end
    if parent.incomingNotice then parent.incomingNotice:SetShown(incoming.sessionOnlyExpired==true)end
    local selector=parent.feedSelector
    if not selector and not incoming.available then return end
    if not selector then
        selector=CreateFrame("Frame",nil,parent);parent.feedSelector=selector
        T.SetSize(selector,300,26);Place(selector,"TOPLEFT",parent,"TOPLEFT",48,-58)
        for i,key in ipairs({"history","named"})do
            local b=CreateFrame("Button",nil,selector);selector[key]=b;T.SetSize(b,140,26)
            Place(b,"TOPLEFT",selector,"TOPLEFT",(i-1)*148,0);T:ApplyRounded(b,C.surfaceRaised,6,"base")
            b.label=Font(b,11);Place(b.label,"CENTER",b,"CENTER",0,0)
            b.line=b:CreateTexture(nil,"OVERLAY");b.line:SetColorTexture(unpack(C.magenta));T.SetSize(b.line,120,2);Place(b.line,"BOTTOM",b,"BOTTOM",0,0)
        end
    end
    selector:SetShown(incoming.available)
    for _,key in ipairs({"history","named"})do local b=selector[key]
        b.active=mode==key;b.line:SetShown(b.active);b.label:SetTextColor(unpack(b.active and C.text or C.textSoft))
        Text(b.label,key=="history"and"8-second history"or"Named hits")
        T:SetRoundedColor(b,b.active and C.surfacePressed or C.surfaceRaised,"base")
        b:SetScript("OnClick",function()choose(key)end)
        b:SetScript("OnEnter",function(self)T:SetRoundedColor(self,C.surfaceHover,"base");if help then help(self,key)end end)
        b:SetScript("OnLeave",function(self)T:SetRoundedColor(self,self.active and C.surfacePressed or C.surfaceRaised,"base");if help then help()end end)
    end
end
function U:HideIncoming(parent)
    if self.HideProtectedIncoming then self:HideProtectedIncoming(parent)end
    local chart=parent.incomingChart;if not chart then return end
    chart:Hide();chart.guide:Hide();chart.selection=nil
    for _,b in ipairs(chart.bars)do b:SetScript("OnEnter",nil);b:SetScript("OnMouseWheel",nil);b:Hide()end
    if chart.lateHelp then chart.lateHelp:SetScript("OnEnter",nil);chart.lateHelp:SetScript("OnMouseWheel",nil);chart.lateHelp:Hide()end
end
function U:RenderIncomingLateReports(chart,page,ctx,baseline)
    if not chart.lateHelp then
        chart.lateHelp=CreateFrame("Button",nil,chart);T.SetSize(chart.lateHelp,214,18)
        chart.lateHelp.label=Font(chart.lateHelp,11,C.textSoft);chart.lateHelp.label:SetJustifyH("RIGHT");chart.lateHelp.label:SetAllPoints(chart.lateHelp)
    end
    local late=RA.DeathLogModel:LateIncoming(page);local lateHelp=chart.lateHelp
    chart.lateHistory=late;lateHelp.member=1
    lateHelp:SetShown(late.available or late.pending or late.partial)
    Place(lateHelp,"TOPRIGHT",chart,"TOPRIGHT",-48,-baseline)
    Text(lateHelp.label,late.pending and"Collecting late reports"or("Late reports · "..#late.rows..(late.partial and" · incomplete"or"")))
    local function ShowLate(self)
        if not ctx.active()or not(late.available or late.pending or late.partial)then return end
        if not late.available then
            ctx.tooltip(self,{"Late reports",late.pending and"Waiting for delayed combat feedback."or"Saved before collection finished.","These reports remain separate from chart totals."});return
        end
        local lines={damageEvents={},compactRows=true,totalText="Received after death",countText=#late.rows..(#late.rows==1 and" report"or" reports"),
            originText="Receipt times only; separate from chart totals.",selectedIndex=self.member}
        for _,row in ipairs(late.rows)do
            lines.damageEvents[#lines.damageEvents+1]={text=row.kind=="absorbed"and"Absorb reported"or row.kind=="healing"and"Healing reported"or(schools[row.school]or"Mixed-school").." damage",
                timeText=string.format("+%.2fs",row.deliveryOffset),amountText=row.kind=="absorbed"and"—"or Exact(row.amount),
                amountColor=row.kind=="healing"and C.success or row.kind=="absorbed"and{.36,.70,1}or C.danger}
        end
        ctx.tooltip(self,lines)
    end
    lateHelp:SetScript("OnEnter",ShowLate);lateHelp:SetScript("OnLeave",ctx.hideTooltip)
    lateHelp:EnableMouseWheel(#late.rows>1)
    lateHelp:SetScript("OnMouseWheel",function(self,delta)
        if not ctx.active()or #late.rows==0 then return end
        self.member=self.member+(delta<0 and 1 or -1);if self.member>#late.rows then self.member=1 elseif self.member<1 then self.member=#late.rows end;ShowLate(self)
    end)
end
function U:RenderIncoming(parent,page,history,ctx)
    local chart=parent.incomingChart
    if not chart then
        chart=CreateFrame("Frame",nil,parent);parent.incomingChart=chart;chart:SetAllPoints(parent);chart:EnableMouse(false)
        chart.bars={};chart.healLegend=Font(chart,11,C.success);chart.damageLegend=Font(chart,11,C.danger)
        Text(chart.healLegend,"+ Healing");Text(chart.damageLegend,"Damage")
        chart.guide=chart:CreateTexture(nil,"BACKGROUND");chart.guide:SetColorTexture(C.textSoft[1],C.textSoft[2],C.textSoft[3],.3);chart.guide:Hide()
        chart.damageTitle=Font(chart,10,C.textSoft);chart.healTitle=Font(chart,10,C.textSoft)
        chart.damageTotal=Font(chart,22,C.danger);chart.healTotal=Font(chart,22,C.success)
        RA:ApplyFont(chart.damageTotal,22,"BOLD",false);RA:ApplyFont(chart.healTotal,22,"BOLD",false)
        chart.note=Font(chart,10,C.muted);chart.note:SetJustifyH("RIGHT")
        chart.help=CreateFrame("Button",nil,chart);T.SetSize(chart.help,214,20)
        chart.lateHelp=CreateFrame("Button",nil,chart);T.SetSize(chart.lateHelp,214,18)
        chart.lateHelp.label=Font(chart.lateHelp,11,C.textSoft);chart.lateHelp.label:SetJustifyH("RIGHT");chart.lateHelp.label:SetAllPoints(chart.lateHelp)
    end
    chart:Show();chart.guide:Hide()
    Place(chart.healLegend,"TOPLEFT",chart,"TOPLEFT",48,-ctx.headerTop)
    Place(chart.damageLegend,"TOPLEFT",chart,"TOPLEFT",144,-ctx.headerTop)
    local baseline=ctx.healthTop-36
    Place(chart.damageTitle,"TOPLEFT",chart,"TOPLEFT",48,-baseline);Text(chart.damageTitle,history.damageCount..(history.damageCount==1 and" damage event"or" damage events")..(history.absorbedCount>0 and(" · "..history.absorbedCount.." absorbed")or""))
    Place(chart.damageTotal,"TOPLEFT",chart,"TOPLEFT",48,-baseline-14);Text(chart.damageTotal,Amount(history.damageTotal))
    Place(chart.healTitle,"TOPLEFT",chart,"TOPLEFT",280,-baseline);Text(chart.healTitle,history.healingCount..(history.healingCount==1 and" healing event"or" healing events"))
    Place(chart.healTotal,"TOPLEFT",chart,"TOPLEFT",280,-baseline-14);Text(chart.healTotal,Amount(history.healingTotal))
    Place(chart.note,"TOPRIGHT",chart,"TOPRIGHT",-48,-baseline-24);Text(chart.note,"Receipt times before death")
    Place(chart.help,"TOPRIGHT",chart,"TOPRIGHT",-48,-baseline-18)
    chart.help:SetScript("OnEnter",function(self)
        if ctx.active()then ctx.tooltip(self,{"Recorded history","Times are callback delivery times, not exact hit times. Combat feedback can arrive late.","Spell names, attackers and health snapshots are not supplied.","Named hits shows Blizzard's separate spell records. Late reports stay separate from these chart totals."})end
    end);chart.help:SetScript("OnLeave",ctx.hideTooltip)
    self:RenderIncomingLateReports(chart,page,ctx,baseline)
    local peak=1
    for i=1,16 do local bucket=history.buckets[i];if bucket then peak=math.max(peak,bucket.damage.amount,bucket.healing.amount)end end
    local used=0
    for i=1,16 do local bucket=history.buckets[i]
        if bucket then for _,kind in ipairs({"damage","healing"})do local group=bucket[kind]
            if #group.rows>0 then
                used=used+1;local b=chart.bars[used]
                if not b then
                    b=CreateFrame("Button",nil,chart);chart.bars[used]=b
                    b.fill=b:CreateTexture(nil,"ARTWORK");b.amountLabel=Font(b,11);b.amountLabel:SetJustifyH("CENTER")
                end
                local healing=kind=="healing";local absorbed=not healing and group.amount==0 and group.rows[1].kind=="absorbed"
                local tint=healing and C.success or absorbed and{.36,.70,1}or C.danger
                local x=48+(i-.5)*49;local h=math.max(2,52*group.amount/peak)
                b.group,b.feedKind,b.bucket,b.member=group,kind,i,1
                for j,row in ipairs(group.rows)do if row.amount>group.rows[b.member].amount then b.member=j end end
                T.SetSize(b,44,healing and 74 or 60);Place(b,"TOP",chart,"TOPLEFT",x,healing and(-ctx.rail+76)or(-ctx.rail-28))
                b.fill:ClearAllPoints();T.SetSize(b.fill,24,h)
                Place(b.fill,healing and"BOTTOM"or"TOP",b,healing and"BOTTOM"or"TOP",0,healing and 1 or 0)
                b.fill:SetColorTexture(tint[1],tint[2],tint[3],.82)
                b.amountLabel:ClearAllPoints();Place(b.amountLabel,healing and"BOTTOM"or"TOP",healing and b.fill or b,healing and"TOP"or"BOTTOM",0,healing and 3 or -2)
                T.SetSize(b.amountLabel,48,14);b.amountLabel:SetTextColor(unpack(tint));Text(b.amountLabel,absorbed and"Absorb"or(healing and"+"or"")..Amount(group.amount))
                if healing then ctx.exclusions[#ctx.exclusions+1]={left=x-24,right=x+24,top=ctx.rail-h-20,bottom=ctx.rail-h-6}end
                local lines={damageEvents={},compactRows=true,totalText=absorbed and"Fully absorbed"or Exact(group.amount)..(healing and" healing"or" damage"),countText=#group.rows..(#group.rows==1 and" event"or" events"),originText="Spell names are not supplied by this feed."}
                for _,row in ipairs(group.rows)do
                    lines.damageEvents[#lines.damageEvents+1]={text=row.kind=="absorbed"and"Fully absorbed"or row.kind=="healing"and(row.critical and"Healing · Critical"or"Healing")or(schools[row.school]or"Mixed-school").." damage"..(row.critical and" · Critical"or""),
                        color=C.text,timeText=string.format("%.1fs",row.offset),amountText=row.kind=="absorbed"and"—"or Exact(row.amount),amountColor=tint}
                end
                local function Show(self)
                    if not ctx.active()then return end
                    chart.selection={bucket=i,kind=kind,member=self.member,entry=group.rows[self.member]}
                    T.SetSize(chart.guide,1,160);Place(chart.guide,"TOP",chart,"TOPLEFT",x,-ctx.rail+78);chart.guide:Show()
                    self.fill:SetColorTexture(tint[1],tint[2],tint[3],1)
                    lines.selectedIndex=self.member;ctx.tooltip(self,lines)
                end
                b:EnableMouseWheel(#group.rows>1);b:SetScript("OnEnter",Show)
                b:SetScript("OnLeave",function(self)self.fill:SetColorTexture(tint[1],tint[2],tint[3],.82);chart.guide:Hide();ctx.hideTooltip(self)end)
                b:SetScript("OnMouseWheel",function(self,delta)
                    if not ctx.active()then return end
                    self.member=self.member+(delta<0 and 1 or -1);if self.member>#group.rows then self.member=1 elseif self.member<1 then self.member=#group.rows end;Show(self)
                end)
                b:Show()
            end
        end end
    end
    for i=used+1,#chart.bars do chart.bars[i]:Hide();chart.bars[i]:SetScript("OnEnter",nil);chart.bars[i]:SetScript("OnMouseWheel",nil)end
    chart.visibleBars=used
end
