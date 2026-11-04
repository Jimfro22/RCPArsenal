local _,RA=...
local U,T,I=RA.DeathRecapUI,RA.Theme,RA.DeathRecapProtectedIncoming
local C=T.Colors
local function Text(region,value)RA:SetVisualText(region,value or"")end
local function Place(region,point,parent,relative,x,y)region:ClearAllPoints();T.SetPoint(region,point,parent,relative,x,y)end
local function Font(parent,size,color)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    RA:ApplyFont(f,size,"REGULAR",false);f:SetTextColor(unpack(color or C.text));f:SetJustifyH("LEFT");return f
end
local function ClearNative(chart)
    for _,bar in ipairs(chart.bars)do pcall(bar.SetValue,bar,0);bar:Hide()end
    if chart.details then
        chart.details:Hide()
        for _,row in ipairs(chart.details.rows)do row.amount:SetText("");row:Hide()end
    end
end
function U:HideProtectedIncoming(parent)
    local chart=parent.protectedIncomingChart;if not chart then return end
    chart:Hide();chart.guide:Hide();chart.selection=nil;ClearNative(chart)
    for _,b in ipairs(chart.targets)do b:SetScript("OnEnter",nil);b:SetScript("OnMouseWheel",nil);b:Hide()end
    if chart.lateHelp then chart.lateHelp:SetScript("OnEnter",nil);chart.lateHelp:SetScript("OnMouseWheel",nil);chart.lateHelp:Hide()end
end
local schools={[1]="Physical",[2]="Holy",[4]="Fire",[8]="Nature",[16]="Frost",[32]="Shadow",[64]="Arcane"}
local function Details(chart,parent)
    if chart.details then return chart.details end
    local f=CreateFrame("Frame",nil,parent);chart.details=f;T.SetSize(f,344,96)
    f:SetFrameStrata("TOOLTIP");f:SetClampedToScreen(true);f:EnableMouse(false)
    T:ApplyRounded(f,C.canvasDeep,8,"base")
    f.title=Font(f,12);Place(f.title,"TOPLEFT",f,"TOPLEFT",12,-12)
    f.rows={}
    for i=1,12 do
        local row=CreateFrame("Frame",nil,f);f.rows[i]=row;T.SetSize(row,320,26)
        Place(row,"TOPLEFT",f,"TOPLEFT",12,-38-(i-1)*26)
        row.time=Font(row,10,C.muted);Place(row.time,"LEFT",row,"LEFT",0,0)
        row.kind=Font(row,11);Place(row.kind,"LEFT",row,"LEFT",54,0);row.kind:SetWidth(150)
        row.amount=Font(row,11);row.amount.__raNativeText=true;row.amount:SetJustifyH("RIGHT")
        Place(row.amount,"RIGHT",row,"RIGHT",0,0);row.amount:SetWidth(108)
        row.focus=row:CreateTexture(nil,"BACKGROUND");row.focus:SetAllPoints(row);row.focus:SetColorTexture(unpack(C.surfacePressed))
    end
    f.note=Font(f,10,C.muted);Place(f.note,"BOTTOMLEFT",f,"BOTTOMLEFT",12,10)
    return f
end
local function PaintDetails(chart,parent,page,history,member,title,note)
    local f=Details(chart,parent);local count=#history.rows
    local first=math.max(1,math.min(member-5,count-11));local last=math.min(count,first+11)
    f:SetHeight(68+(last-first+1)*26);Place(f,"TOPLEFT",parent,"TOPRIGHT",12,-12)
    Text(f.title,title);Text(f.note,note)
    for i,ui in ipairs(f.rows)do
        local item=history.rows[first+i-1]
        if i<=last-first+1 and item then
            local healing=item.kind=="healing";local color=healing and C.success or C.danger
            Text(ui.time,string.format(history.late and"+%.1fs"or"%.1fs",item.offset))
            Text(ui.kind,healing and(item.flag=="CRITICAL"and"Healing · Critical"or"Healing")or item.flag=="ABSORB"and"Absorb reported"or(schools[item.school]or"Mixed-school").." damage")
            ui.amount:SetTextColor(unpack(color))
            if history.late then I:PaintLate(page,item.sequence,ui.amount)else I:Paint(page,item.sequence,nil,ui.amount)end
            ui.focus:SetShown(first+i-1==member);ui:Show()
        else ui.amount:SetText("");ui:Hide()end
    end
    f:Show();return f
end
function U:ClearIncomingNativeDetails(chart)
    if not chart.details then return end
    chart.details:Hide();for _,row in ipairs(chart.details.rows)do row.amount:SetText("");row:Hide()end
end
function U:ShowProtectedIncomingLate(chart,page,late,ctx,member)
    if not ctx.active()then return end
    ctx.hideTooltip()
    PaintDetails(chart,chart:GetParent(),page,late,member,"Received after death · "..#late.rows,"Delivery times only · Separate from timeline")
end
function U:RenderProtectedIncoming(parent,page,history,ctx)
    local chart=parent.protectedIncomingChart
    if not chart then
        chart=CreateFrame("Frame",nil,parent);parent.protectedIncomingChart=chart;chart:SetAllPoints(parent);chart:EnableMouse(false)
        chart.bars={};chart.targets={};chart.labels={}
        chart.healLegend=Font(chart,11,C.success);Text(chart.healLegend,"+ Healing")
        chart.damageLegend=Font(chart,11,C.danger);Text(chart.damageLegend,"Damage")
        chart.damageCount=Font(chart,12,C.danger);chart.healingCount=Font(chart,12,C.success)
        chart.note=Font(chart,10,C.muted);chart.note:SetJustifyH("RIGHT")
        chart.guide=chart:CreateTexture(nil,"BACKGROUND");chart.guide:SetColorTexture(C.textSoft[1],C.textSoft[2],C.textSoft[3],.3)
    end
    chart:Show();chart.guide:Hide();chart.painted=0;chart.blocked=0
    Place(chart.healLegend,"TOPLEFT",chart,"TOPLEFT",48,-ctx.headerTop)
    Place(chart.damageLegend,"TOPLEFT",chart,"TOPLEFT",144,-ctx.headerTop)
    local bottom=ctx.healthTop-30
    Place(chart.damageCount,"TOPLEFT",chart,"TOPLEFT",48,-bottom);Text(chart.damageCount,history.damageCount..(history.damageCount==1 and" damage event"or" damage events"))
    Place(chart.healingCount,"TOPLEFT",chart,"TOPLEFT",280,-bottom);Text(chart.healingCount,history.healingCount..(history.healingCount==1 and" healing event"or" healing events"))
    Place(chart.note,"TOPRIGHT",chart,"TOPRIGHT",-48,-bottom-24)
    Text(chart.note,history.partial and"Capacity reached · some events omitted"or"Individual events · Hover for amounts · Kept until reload")
    self:RenderIncomingLateReports(chart,page,ctx,bottom)
    local buckets={}
    for _,row in ipairs(history.rows)do
        local index=math.min(16,math.floor((row.offset+8)*2)+1)
        local key=index..":"..row.kind
        local group=buckets[key];if not group then group={index=index,kind=row.kind,rows={}};buckets[key]=group end
        group.rows[#group.rows+1]=row
    end
    local used,targets=0,0
    for index=1,16 do for _,kind in ipairs({"damage","healing"})do
        local group=buckets[index..":"..kind]
        if group then
            local healing=kind=="healing";local color=healing and C.success or C.danger
            local x=48+(index-.5)*49;local count=#group.rows
            -- Each receipt has its OWN native value. Heights are never summed,
            -- ranked, normalized against a secret peak, or read back in Lua.
            for position,row in ipairs(group.rows)do
                used=used+1;local bar=chart.bars[used]
                if not bar then
                    bar=CreateFrame("StatusBar",nil,chart);chart.bars[used]=bar;bar:EnableMouse(false)
                    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8");bar:SetOrientation("VERTICAL")
                    bar.zero=bar:CreateTexture(nil,"OVERLAY");bar.zero:SetColorTexture(.36,.70,1,1)
                end
                local width=math.min(8,40/count);local dx=(position-(count+1)/2)*(40/count)
                T.SetSize(bar,width,52);Place(bar,"TOP",chart,"TOPLEFT",x+dx,healing and(-ctx.rail+54)or(-ctx.rail-28))
                bar:SetReverseFill(not healing);bar:SetStatusBarColor(unpack(color));bar.sequence=row.sequence
                bar.zero:ClearAllPoints();T.SetSize(bar.zero,width,2);Place(bar.zero,"TOP",bar,"TOP",0,0);bar.zero:SetShown(row.flag=="ABSORB")
                local ok=I:Paint(page,row.sequence,bar)
                if ok then chart.painted=chart.painted+1 else chart.blocked=chart.blocked+1 end
                bar:Show()
            end
            targets=targets+1;local b=chart.targets[targets]
            if not b then b=CreateFrame("Button",nil,chart);chart.targets[targets]=b;b.label=Font(b,10,C.muted);b.label:SetJustifyH("CENTER")end
            b.group=group;b.member=count
            T.SetSize(b,46,72);Place(b,"TOP",chart,"TOPLEFT",x,healing and(-ctx.rail+76)or(-ctx.rail-28))
            Place(b.label,"TOP",b,healing and"TOP"or"BOTTOM",0,healing and 0 or -2)
            Text(b.label,count>1 and("×"..count)or"")
            if healing and count>1 then ctx.exclusions[#ctx.exclusions+1]={left=x-24,right=x+24,top=ctx.rail-76,bottom=ctx.rail-62}end
            local function Show(self)
                if not ctx.active()then return end
                ctx.hideTooltip()
                local f=PaintDetails(chart,parent,page,{rows=group.rows},self.member,
                    (healing and"Healing"or"Damage").." · "..count..(count==1 and" event"or" events"),
                    (count>1 and"Scroll · "or"").."Receipt times · Bar limit "..string.format("%.0f",history.referenceMaximum))
                chart.selection={sequence=group.rows[self.member].sequence,offset=group.rows[self.member].offset}
                T.SetSize(chart.guide,1,164);Place(chart.guide,"TOP",chart,"TOPLEFT",x,-ctx.rail+78);chart.guide:Show();f:Show()
            end
            b:EnableMouseWheel(count>1);b:SetScript("OnEnter",Show)
            b:SetScript("OnLeave",function()chart.guide:Hide();if chart.details then chart.details:Hide()end end)
            b:SetScript("OnMouseWheel",function(self,delta)
                if not ctx.active()then return end
                self.member=self.member+(delta<0 and 1 or -1);if self.member>count then self.member=1 elseif self.member<1 then self.member=count end;Show(self)
            end)
            b:Show()
        end
    end end
    for i=used+1,#chart.bars do pcall(chart.bars[i].SetValue,chart.bars[i],0);chart.bars[i]:Hide()end
    for i=targets+1,#chart.targets do chart.targets[i]:Hide();chart.targets[i]:SetScript("OnEnter",nil);chart.targets[i]:SetScript("OnMouseWheel",nil)end
    chart.visibleBars=used
    if chart.blocked>0 then Text(chart.note,"Some bars couldn't be displayed · Hover for amounts")end
end
