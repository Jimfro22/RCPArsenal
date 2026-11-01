local _,RA=...
local UI={};RA.DeathRecapUI=UI
local R,T=RA.DeathRecap,RA.Theme
local C=T.Colors
local frame,share,actionShield,current,sample,examplePage
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
    if value==nil then return "—"end
    for _,unit in ipairs({{1e12,"t"},{1e9,"b"},{1e6,"m"},{1e3,"k"}})do
        if value>=unit[1]then return string.format(value%unit[1]==0 and"%.0f%s"or"%.1f%s",value/unit[1],unit[2])end
    end
    return tostring(value)
end
local tooltipOwner,tooltipBuilding,tooltipPlacing,tooltipHooked,tooltipRecap,tooltipNative
local function Metric(value)
    if type(issecretvalue)~="function"then return nil end
    local ok,secret=pcall(issecretvalue,value)
    if not ok or secret~=false or type(value)~="number"or value~=value or math.abs(value)==math.huge then return nil end
    return value
end
local function ReadMetric(owner,method)
    if not owner or type(owner[method])~="function"then return nil end
    local ok,value=pcall(owner[method],owner);return ok and Metric(value)or nil
end
local function Bounds(owner)
    local scale=ReadMetric(owner,"GetEffectiveScale")
    local x,y,w,h=ReadMetric(owner,"GetLeft"),ReadMetric(owner,"GetBottom"),ReadMetric(owner,"GetWidth"),ReadMetric(owner,"GetHeight")
    if not scale or scale<=0 or not x or not y or not w or not h or w<0 or h<0 then return nil end
    return {left=x*scale,bottom=y*scale,right=(x+w)*scale,top=(y+h)*scale,scale=scale}
end
local function Overlap(x,y,w,h,rect,pad)
    if not rect then return 0 end;pad=pad or 0
    return math.max(0,math.min(x+w,rect.right+pad)-math.max(x,rect.left-pad))*math.max(0,math.min(y+h,rect.top+pad)-math.max(y,rect.bottom-pad))
end
function UI:TooltipRect(screen,panel,target,band,point,w,h)
    local inset,gap=12,12
    local function Clamp(v,lo,hi)return math.max(lo,math.min(math.max(lo,hi),v))end
    local function Fits(x,y)return x>=inset and y>=inset and x+w<=screen.right-inset and y+h<=screen.top-inset end
    local sideY=Clamp(panel.top-h,inset,screen.top-inset-h)
    local alongX=Clamp(panel.left,inset,screen.right-inset-w)
    for _,p in ipairs({{panel.right+gap,sideY},{panel.left-gap-w,sideY},{alongX,panel.bottom-gap-h},{alongX,panel.top+gap}})do
        if Fits(p[1],p[2])then return p[1],p[2],"outside"end
    end
    local best,score
    for _,p in ipairs({{inset,inset},{screen.right-inset-w,inset},{inset,screen.top-inset-h},{screen.right-inset-w,screen.top-inset-h}})do
        local x,y=Clamp(p[1],inset,screen.right-inset-w),Clamp(p[2],inset,screen.top-inset-h)
        local candidate={Overlap(x,y,w,h,target,8),Overlap(x,y,w,h,band),Overlap(x,y,w,h,point,4),Overlap(x,y,w,h,panel)}
        local wins=score==nil
        if score then for i=1,4 do if candidate[i]~=score[i]then wins=candidate[i]<score[i];break end end end
        if wins then best,score={x,y},candidate end
    end
    return best[1],best[2],(w>screen.right-24 or h>screen.top-24)and"oversize"or"fallback"
end
local function ClearTooltipTracking()
    tooltipOwner=nil;tooltipNative=false
    if tooltipRecap then tooltipRecap:Hide()end
    if frame then frame.tooltipPlacement=nil end
end
local function PositionTooltip()
    if tooltipBuilding or tooltipPlacing or not tooltipOwner or not frame or not frame:IsShown()or not tooltipRecap or not tooltipRecap:IsShown()then return end
    if tooltipNative and(not GameTooltip or not GameTooltip:IsShown())then return end
    if tooltipNative and GameTooltip.GetOwner and GameTooltip:GetOwner()~=tooltipOwner then ClearTooltipTracking();return end
    tooltipPlacing=true
    local panel,target=Bounds(frame),Bounds(tooltipOwner)
    local sw,sh,ss=ReadMetric(UIParent,"GetWidth"),ReadMetric(UIParent,"GetHeight"),ReadMetric(UIParent,"GetEffectiveScale")
    local tw,th,ts=0,0,1
    if tooltipNative then tw,th,ts=ReadMetric(GameTooltip,"GetWidth"),ReadMetric(GameTooltip,"GetHeight"),ReadMetric(GameTooltip,"GetEffectiveScale")end
    local rw,rh,rs=ReadMetric(tooltipRecap,"GetWidth"),ReadMetric(tooltipRecap,"GetHeight"),ReadMetric(tooltipRecap,"GetEffectiveScale")
    if panel and target and sw and sh and ss and ss>0 and tw and th and(not tooltipNative or(tw>0 and th>0))and ts and ts>0 and rw and rh and rs and rs>0 and sw>0 and sh>0 then
        local gap=tooltipNative and 6 or 0
        local width,height=math.max(tw*ts,rw*rs),th*ts+gap+rh*rs
        local band={left=panel.left,right=panel.right,top=panel.top,bottom=panel.top-(132+(frame.shelfShift or 0))*panel.scale}
        local point=frame.healthPanel and Bounds(frame.healthPanel)or nil
        local x,y,mode=UI:TooltipRect({right=sw*ss,top=sh*ss},panel,target,band,point,width,height)
        if tooltipNative then GameTooltip:ClearAllPoints();GameTooltip:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",x/ts,(y+rh*rs+gap)/ts)end
        tooltipRecap:ClearAllPoints();tooltipRecap:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",x/rs,y/rs)
        frame.tooltipPlacement={left=x,bottom=y,right=x+width,top=y+height,mode=mode}
    else
        tooltipRecap:ClearAllPoints()
        if tooltipNative then
            GameTooltip:ClearAllPoints();GameTooltip:SetPoint("BOTTOM",frame,"TOP",0,12)
            tooltipRecap:SetPoint("TOPLEFT",GameTooltip,"BOTTOMLEFT",0,-6)
        else tooltipRecap:SetPoint("BOTTOM",frame,"TOP",0,12)end
        frame.tooltipPlacement=nil
    end
    if tooltipNative then GameTooltip:SetClampedToScreen(true)end;tooltipPlacing=false
end
local function RecapBox(lines,color,heading,focusIndex)
    if not tooltipRecap then
        tooltipRecap=CreateFrame("Frame",nil,UIParent);tooltipRecap:SetFrameStrata("TOOLTIP");Surface(tooltipRecap,C.canvasDeep);T:ApplyRounded(tooltipRecap,C.lineStrong,8,"border","BORDER")
        tooltipRecap.scroll=CreateFrame("ScrollFrame",nil,tooltipRecap);tooltipRecap.scroll:SetAllPoints(tooltipRecap);tooltipRecap.scroll:SetClipsChildren(true)
        tooltipRecap.body=CreateFrame("Frame",nil,tooltipRecap.scroll);tooltipRecap.scroll:SetScrollChild(tooltipRecap.body);tooltipRecap.lines={}
    end
    frame.tooltipRecap=tooltipRecap
    local first=heading and 1 or 2
    local width,count=220,math.min(80,math.max(0,#lines-first+1))
    for i=#tooltipRecap.lines+1,count do
        local f=Font(tooltipRecap.body,i==1 and 13 or 12,i==1 and"BOLD"or"REGULAR")
        f:SetWordWrap(true);f:SetNonSpaceWrap(true);f:SetMaxLines(0);tooltipRecap.lines[i]=f
    end
    for i,f in ipairs(tooltipRecap.lines)do
        f:Hide();if f.recapIcon then f.recapIcon:Hide()end
        if f.recapAmount then f.recapAmount:Hide();f.recapTime:Hide()end;f.detailWidth=nil
        if i<=count then
            local line=lines[i+first-1];local text=type(line)=="table"and line.text or line
            local tint=type(line)=="table"and line.color or color or C.textSoft
            f.iconSpellID=type(line)=="table"and line.iconSpellID or nil
            if f.iconSpellID then
                f.recapIcon=f.recapIcon or tooltipRecap.body:CreateTexture(nil,"ARTWORK")
                Size(f.recapIcon,18,18);RA:RegisterSpellIcon(f.recapIcon,f.iconSpellID)
            end
            if heading and i==1 then tint=C.text end
            f:SetHeight(0);f:SetWidth(0);Text(f,text);f:SetTextColor(unpack(tint))
            width=math.max(width,(ReadMetric(f,"GetUnboundedStringWidth")or ReadMetric(f,"GetStringWidth")or 0)+(f.iconSpellID and 44 or 20))
            if type(line)=="table"and line.amountText then
                f.recapAmount=f.recapAmount or Font(tooltipRecap.body,12)
                f.recapTime=f.recapTime or Font(tooltipRecap.body,11)
                Text(f.recapAmount,line.amountText);Text(f.recapTime,line.timeText)
                f.recapAmount:SetTextColor(unpack(line.amountColor or C.text));f.recapTime:SetTextColor(unpack(C.muted))
                f.amountWidth=math.min(150,math.max(50,ReadMetric(f.recapAmount,"GetUnboundedStringWidth")or f.recapAmount:GetStringWidth()))
                f.timeWidth=math.min(70,math.max(36,ReadMetric(f.recapTime,"GetUnboundedStringWidth")or f.recapTime:GetStringWidth()))
                f.detailWidth=f.amountWidth+f.timeWidth+20;width=360
            end
        end
    end
    width=math.min(360,width);local y=8
    for i=1,count do
        local f=tooltipRecap.lines[i];local inset=f.iconSpellID and 34 or 10;f:SetWidth(width-inset-10-(f.detailWidth or 0));f:SetHeight(0)
        f:SetWordWrap(true);f:SetNonSpaceWrap(true);f:SetMaxLines(0);f:Show()
        f:ClearAllPoints();Point(f,"TOPLEFT",tooltipRecap.body,"TOPLEFT",inset,-y);f.recapY=y
        if f.iconSpellID then f.recapIcon:ClearAllPoints();Point(f.recapIcon,"TOPLEFT",tooltipRecap.body,"TOPLEFT",10,-y);f.recapIcon:Show()end
        if f.detailWidth then
            for _,detail in ipairs({f.recapAmount,f.recapTime})do detail:ClearAllPoints();detail:SetWordWrap(false);detail:SetJustifyH("RIGHT");detail:SetHeight(18);detail:Show()end
            f.recapAmount:SetWidth(f.amountWidth);f.recapTime:SetWidth(f.timeWidth)
            Point(f.recapAmount,"TOPRIGHT",tooltipRecap.body,"TOPRIGHT",-20-f.timeWidth,-y)
            Point(f.recapTime,"TOPRIGHT",tooltipRecap.body,"TOPRIGHT",-10,-y)
        end
        -- Clear the previous pooled height before native wrap measurement.
        -- Otherwise a formerly short row can ellipsize instead of growing.
        local h=ReadMetric(f,"GetStringHeight")or(i==1 and 16 or 15)
        h=math.ceil(math.max(f.iconSpellID and 18 or(i==1 and 16 or 15),h))+2;f:SetHeight(h);y=y+h+3
    end
    local total=math.max(24,y+5)
    local available=384;local sh,ss,rs=ReadMetric(UIParent,"GetHeight"),ReadMetric(UIParent,"GetEffectiveScale"),ReadMetric(tooltipRecap,"GetEffectiveScale")
    if sh and sh>0 and ss and ss>0 and rs and rs>0 then
        local native=tooltipNative and(ReadMetric(GameTooltip,"GetHeight")or 0)*(ReadMetric(GameTooltip,"GetEffectiveScale")or 1)/rs or 0
        available=math.max(40,math.min(384,sh*ss/rs-native-48))
    end
    local height=math.min(total,available);Size(tooltipRecap,width,height);Size(tooltipRecap.body,width,total)
    tooltipRecap.overflowing=total>height
    local focus=focusIndex and tooltipRecap.lines[focusIndex-first+1]
    local scroll=focus and math.max(0,focus.recapY+focus:GetHeight()+8-height)or 0
    tooltipRecap.scroll:SetVerticalScroll(math.min(total-height,scroll));tooltipRecap:Show()
end
local function Tooltip(button,lines,spellID,itemID,color,focusIndex)
    if(share and share:IsShown())then return end
    if not GameTooltip then return end
    local previousOwner,previousNative=tooltipOwner,tooltipNative
    tooltipBuilding=true
    if previousNative and GameTooltip.GetOwner and GameTooltip:GetOwner()==previousOwner then GameTooltip:Hide()end
    tooltipOwner=button;tooltipNative=spellID~=nil or itemID~=nil
    if tooltipNative then GameTooltip:SetOwner(button,"ANCHOR_NONE")end
    local function Native(fn,id)
        local called,value=pcall(fn,GameTooltip,id);if not called or type(issecretvalue)~="function"then return false end
        local checked,secret=pcall(issecretvalue,value);return checked and secret==false and value~=false
    end
    local ok=false
    if spellID then ok=Native(GameTooltip.SetSpellByID,spellID)
    elseif itemID and GameTooltip.SetItemByID then ok=Native(GameTooltip.SetItemByID,itemID)end
    if tooltipNative and not ok then GameTooltip:SetText(lines[1]or"Details")end
    -- Spell/item facts have a companion; ordinary help is one card.
    RecapBox(lines,color,not tooltipNative,focusIndex);if tooltipNative then GameTooltip:Show()end;tooltipBuilding=false;PositionTooltip()
    if not tooltipHooked and GameTooltip.HookScript then
        tooltipHooked=true;GameTooltip:HookScript("OnSizeChanged",PositionTooltip)
        GameTooltip:HookScript("OnHide",function()if tooltipNative and not tooltipBuilding and not tooltipPlacing then ClearTooltipTracking()end end)
        GameTooltip:HookScript("OnTooltipCleared",function()
            if tooltipNative and not tooltipBuilding and not tooltipPlacing and tooltipOwner and GameTooltip.GetOwner and GameTooltip:GetOwner()~=tooltipOwner then ClearTooltipTracking()end
        end)
    end
end
local function HideTooltip(target)
    if target and target~=tooltipOwner then return end
    local owner,wasNative=tooltipOwner,tooltipNative;ClearTooltipTracking()
    if wasNative and owner and GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner()==owner then GameTooltip:Hide()end
end
local function Icon(parent,size)
    local b=CreateFrame("Button",nil,parent);Size(b,size,size);Surface(b,C.lineStrong)
    b.icon=b:CreateTexture(nil,"ARTWORK");Size(b.icon,size-4,size-4);Point(b.icon,"CENTER",b,"CENTER",0,0)
    b.icon:SetTexCoord(.08,.92,.08,.92)
    b.badge=Font(b,11,"BOLD");Point(b.badge,"BOTTOMRIGHT",b,"BOTTOMRIGHT",1,-2)
    b:SetScript("OnLeave",HideTooltip);return b
end
local function Artwork(button,row)
    if row.spellID and RA.RegisterSpellIcon then RA:RegisterSpellIcon(button.icon,row.spellID)
    else
        local texture=row.icon or(row.kind=="stone"and"Interface\\Icons\\INV_Stone_04"or row.kind=="potion"and"Interface\\Icons\\INV_Potion_51"or 134400)
        -- Replace any prior spell registration on this recycled icon. A plain
        -- SetTexture leaves the asset broker free to restore its old artwork.
        RA:RegisterVisualTexture(button.icon,texture,T.Assets.White)
    end
end
local M=RA.DeathLogModel
local pink,lavender,amber,absorbBlue={1,.46,.40},{.69,.61,.80},{1,.91,.56},{.36,.70,1}
local selected,model,domain,extraHeight,contentShift
local memberChoices,renderRevision={},0
local closing=false
local TIER_GAP=84
local BASE_HEIGHT,HEALTH_TOP=360,320
local HEALTH_WIDTH=784
local damagePool,supportPool,shelfPool={},{},{}
local function Place(region,point,relative,relativePoint,x,y)
    region:ClearAllPoints();Point(region,point,relative,relativePoint,x,y)
end
local function Number(value,positive)
    if type(issecretvalue)~="function"then return nil end
    local ok,secret=pcall(issecretvalue,value)
    if not ok or secret~=false or type(value)~="number"or value~=value or value==math.huge or value==-math.huge or value<0 or(positive and value==0)then return nil end
    return value
end
local function Raw(value)return tostring(value)end
local function CapturedText(value)
    if type(issecretvalue)~="function"then return nil end
    local ok,secret=pcall(issecretvalue,value)
    if ok and secret==false and type(value)=="string"and #value>0 and #value<=128 and not value:find("[%c|]")then return value end
end
local CLASS_FILES={WARRIOR=true,PALADIN=true,HUNTER=true,ROGUE=true,PRIEST=true,DEATHKNIGHT=true,SHAMAN=true,MAGE=true,WARLOCK=true,MONK=true,DRUID=true,DEMONHUNTER=true,EVOKER=true}
local function CapturedClassColor(value)
    local class=CapturedText(value)
    if not class or not CLASS_FILES[class]then return unpack(C.text)end
    -- The class palette is static client metadata. Never query a current unit
    -- or call a live class/identity API while rendering an old page.
    local ok,r,g,b=pcall(function()
        local color=RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        return color and color.r,color and color.g,color and color.b
    end)
    r,g,b=Metric(r),Metric(g),Metric(b)
    if ok and r and g and b and r>=0 and g>=0 and b>=0 and r<=1 and g<=1 and b<=1 then return r,g,b end
    return unpack(C.text)
end
local function Header(page,example)
    local name,realm=CapturedText(page.playerName),CapturedText(page.playerRealm)
    frame.capturedFullName=name and(name..(realm and("-"..realm)or""))or nil
    Text(frame.playerName,name or"");frame.playerName:SetTextColor(CapturedClassColor(page.class));frame.playerName:SetShown(name~=nil)
    frame.coverage:SetShown(example)
    if not name then
        frame.coverage:SetWidth(70);Place(frame.coverage,"TOPLEFT",frame,"TOPLEFT",174,-26)
        Place(frame.info,"TOPLEFT",frame,"TOPLEFT",example and 218 or 174,-23);return
    end
    local previewWidth=example and math.min(70,ReadMetric(frame.coverage,"GetUnboundedStringWidth")or frame.coverage:GetStringWidth())or 0
    local cap=math.min(280,550-174-16-8-(example and previewWidth+8 or 0))
    local width=math.min(cap,ReadMetric(frame.playerName,"GetUnboundedStringWidth")or frame.playerName:GetStringWidth())
    frame.playerName:SetWidth(width)
    local nextX=174+width+8
    if example then frame.coverage:SetWidth(previewWidth);Place(frame.coverage,"TOPLEFT",frame,"TOPLEFT",nextX,-26);nextX=nextX+previewWidth+8 end
    Place(frame.info,"TOPLEFT",frame,"TOPLEFT",nextX,-23)
end
local function ExactAmount(value)
    local text=string.format("%.0f",value)
    return text:reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")
end
local function RecapAge(offset)
    return offset==0 and "Final recorded hit"or string.format("%.1fs %s final recorded hit",math.abs(offset),offset<0 and"before"or"after")
end
local function UseAge(page,time)
    time=Number(time);local death=Number(page.diedAt)
    return time and death and death>=time and string.format("%.1fs before the death notice",death-time)or"Time not recorded"
end
function UI:GroupRecordedUses(page,receipts)
    local groups,byID={},{}
    local uses=receipts or page.casts or{}
    for index=math.max(1,#uses-R.LIMITS.casts+1),#uses do local row=uses[index]
        local id=Number(row.spellID,true);local key=id or("receipt:"..index)
        local group=byID[key]
        if not group then group={spellID=id,name=row.name,rows={},lastIndex=index};byID[key]=group;groups[#groups+1]=group end
        group.rows[#group.rows+1]=row;group.lastIndex=index
    end
    table.sort(groups,function(a,b)return a.lastIndex>b.lastIndex end)
    return groups
end
local function At(time)return string.format("%s%.1fs",time<0 and"−"or"",math.abs(time))end
local function IsExample()return sample==true and current~=nil and current==examplePage end
local function ActionPage(page,preview)
    return current~=nil and current==page and(preview==true and IsExample()or preview==false and not sample and R:IsRetainedPage(current))
end
local function X(time)return 48+(time-domain.first)/(domain.last-domain.first)*784 end
local function SamplePage()
    local page={id=0,diedAt=132,class="MAGE",specID=62,playerName="Example Mage",playerRealm="Example Realm",encounter={encounterID=3429,name="The Coiled Altar",difficulty=16,startedAt=0},
        maxHealth=400000,healthPoints={{offset=-5,hp=372000}},transitions={-3.5,-2.2,-1.8,-.5},
        heals={{offset=-4.2,amount=9000,name="Flash Heal",spellID=2061,healer="Example healer",hp=336000},
            {offset=-3.15,amount=11000,name="Renew",spellID=139,healer="Example healer",hp=211000}},
        supports={{spellID=235450,name="Prismatic Barrier",offset=-3.5,finish=-2.2,exampleHP=200000,nativeOffset=-3.5,nativeIndex=201},
            {spellID=342245,auraSpellID=342246,name="Alter Time",offset=-1.8,finish=-.5,exampleHP=128000,nativeOffset=-1.8,nativeIndex=202}},
        defaultSelection=1,native={rows={}},casts={},lastAlive=R:GetCooldownPreviewPage().lastAlive}
    local definitions={{-4.8,1285017,"Axegrinder",15000,357000,"axe-A"},{-4.6,1285017,"Axegrinder",15000,342000,"axe-A"},
        {-4.4,1285017,"Axegrinder",15000,327000,"axe-A"},{-3.6,1306906,"Venomfang",136000,200000,"boss"},
        {-3,1283290,"Noxious Ground",16000,195000,"ground-A"},{-2.8,1283290,"Noxious Ground",16000,179000,"ground-A"},
        {-2.3,1299684,"Sever",51000,128000,"boss"},{-1.3,1285017,"Axegrinder",34000,94000,"axe-B"},
        {-1.1,1285017,"Axegrinder",34000,60000,"axe-B"},{-.9,1285017,"Axegrinder",34000,26000,"axe-B"},
        {0,1306906,"Venomfang",45000,0,"boss"}}
    for i,d in ipairs(definitions)do
        local row={nativeIndex=i==#definitions and 1 or i+1,nativeOffset=d[1],spellID=d[2],name=d[3],kind="damage",amount=d[4],
            exampleHP=d[5],sourceKey=d[6],sourceConfirmed=true,sourceName="Example "..d[6]}
        if i==4 then row.absorbed=20000 end
        if i==#definitions then row.overkill=19000 end
        page.native.rows[#page.native.rows+1]=row
        page.healthPoints[#page.healthPoints+1]={offset=d[1],hp=d[5]}
    end
    for i,heal in ipairs(page.heals)do heal.exampleHP=heal.hp;heal.effectiveHealing=heal.amount;heal.nativeOffset=heal.offset;heal.nativeIndex=100+i;page.healthPoints[#page.healthPoints+1]={offset=heal.offset,hp=heal.hp}end
    for _,support in ipairs(page.supports)do page.healthPoints[#page.healthPoints+1]={offset=support.offset,hp=support.exampleHP}end
    table.sort(page.healthPoints,function(a,b)return a.offset<b.offset end)
    return page
end
local previewJournal={
    [1285017]={sectionID=36846,sectionSpellID=1283832},[1306906]={sectionID=35594,sectionSpellID=1282287},
    [1299684]={sectionID=36254,sectionSpellID=1299680},[1283290]={sectionID=35590,sectionSpellID=1283290}}
local function Public(value)
    if type(issecretvalue)~="function"then return nil end
    local ok,secret=pcall(issecretvalue,value);if ok and secret==false then return value end
end
local function Journal(row,page)
    if page~=current then return false,"This log is no longer open"end
    if not IsExample()then return R:OpenJournal(page,row)end
    local map=previewJournal[row.spellID]
    if not map or page.encounter.encounterID~=3429 or page.encounter.difficulty~=16 then return false,"No verified Journal entry"end
    local function Allowed()local ok,value=pcall(InCombatLockdown);return ok and Public(value)==false and page==current and IsExample()end
    if not Allowed()then return false,"Journal available after combat"end
    local ok=pcall(function()
        if type(EncounterJournal_LoadUI)~="function"then error("unavailable")end
        EncounterJournal_LoadUI();if not Allowed()then error("combat")end
        if type(EJ_SelectInstance)~="function"or type(EJ_SetDifficulty)~="function"or type(EJ_SelectEncounter)~="function"
            or type(EJ_GetEncounterInfo)~="function"or not C_EncounterJournal or type(C_EncounterJournal.GetSectionInfo)~="function"
            or type(EncounterJournal_OpenJournal)~="function"then error("unavailable")end
        EJ_SelectInstance(1320);EJ_SetDifficulty(16);EJ_SelectEncounter(2883)
        local _,_,encounter,root,_,instance,dungeon,mapID=EJ_GetEncounterInfo(2883)
        if Public(encounter)~=2883 or Public(root)~=35058 or Public(instance)~=1320 or Public(dungeon)~=3429 or Public(mapID)~=3004 then error("context")end
        local queue,seen,found={35058},{},false
        local index=1
        while index<=#queue and index<=128 do
            local id=queue[index];index=index+1
            if not seen[id]then
                seen[id]=true
                local info=Public(C_EncounterJournal.GetSectionInfo(id))
                if type(info)~="table"or getmetatable(info)~=nil then error("section")end
                if id==map.sectionID then
                    if Public(info.spellID)~=map.sectionSpellID or Public(info.filteredByDifficulty)~=false then error("relationship")end
                    found=true;break
                end
                local sibling,child=Number(info.siblingSectionID,true),Number(info.firstChildSectionID,true)
                if sibling then queue[#queue+1]=sibling end
                if child and Public(info.filteredByDifficulty)==false then queue[#queue+1]=child end
            end
        end
        if not found or not Allowed()then error("unverified")end
        EncounterJournal_OpenJournal(16,1320,2883,map.sectionID)
    end)
    return ok,ok and"Journal opened"or"Journal entry unavailable"
end
local function Rect(pool,index,parent,x,y,w,h,color,alpha,layer)
    local t=pool[index]or parent:CreateTexture(nil,"ARTWORK");pool[index]=t
    Size(t,math.max(1,w),math.max(1,h));Place(t,"TOPLEFT",parent,"TOPLEFT",x,-y);t:SetColorTexture(color[1],color[2],color[3],alpha or 1);t:SetDrawLayer(layer or"ARTWORK");t:Show();return t
end
local function HidePool(pool)for _,obj in ipairs(pool)do obj:Hide()end end
local function Segments(x,first,last,rects)
    local cuts={};for _,r in ipairs(rects or{})do
        if x>=r.left-2 and x<=r.right+2 then local a,b=math.max(first,r.top-2),math.min(last,r.bottom+2);if b>a then cuts[#cuts+1]={a,b}end end
    end
    table.sort(cuts,function(a,b)return a[1]<b[1]end)
    local out,cursor={},first
    for _,cut in ipairs(cuts)do if cut[1]>cursor then out[#out+1]={cursor,cut[1]}end;cursor=math.max(cursor,cut[2])end
    if cursor<last then out[#out+1]={cursor,last}end;return out
end
local function Stem(pool,x,first,last,color,alpha,exclusions)
    HidePool(pool);local n=0
    for _,range in ipairs(Segments(x,first,last,exclusions))do n=n+1;Rect(pool,n,frame,x,range[1],1,range[2]-range[1],color,alpha)end
end
local function Guide(x,first,last)
    local n=0;HidePool(frame.guide.dashes)
    for _,range in ipairs(Segments(x,first,last,frame.textExclusions))do
        for i=math.floor((range[1]-first)/9),math.ceil((range[2]-first)/9)do
            local a,b=math.max(range[1],first+i*9),math.min(range[2],first+i*9+5)
            if b>a and n<96 then n=n+1;Rect(frame.guide.dashes,n,frame.guide,0,a-first,1,b-a,pink,.85)end
        end
    end
end
local function DamageBadges(b)
    if b.countBadge then return end
    b.countBadge=CreateFrame("Frame",nil,b);Size(b.countBadge,24,16);Place(b.countBadge,"BOTTOMRIGHT",b,"BOTTOMRIGHT",-2,2)
    Surface(b.countBadge,{.035,.027,.055,.96});b.countText=Font(b.countBadge,11,"BOLD");Place(b.countText,"CENTER",b.countBadge,"CENTER",0,0)
    b.selectedBorder=CreateFrame("Frame",nil,b);Size(b.selectedBorder,50,50);Place(b.selectedBorder,"CENTER",b,"CENTER",0,0)
    b.selectedBorder.edges={}
    Rect(b.selectedBorder.edges,1,b.selectedBorder,0,0,50,2,pink);Rect(b.selectedBorder.edges,2,b.selectedBorder,0,48,50,2,pink)
    Rect(b.selectedBorder.edges,3,b.selectedBorder,0,0,2,50,pink);Rect(b.selectedBorder.edges,4,b.selectedBorder,48,0,2,50,pink);b.selectedBorder:Hide()
end
local dragging,dragProfile
local positionEvents={}
local function PositionDemand(shown)
    for _,event in ipairs(positionEvents)do event:SetEnabled(shown==true)end
end
local function MoveAllowed()
    local ok,value=pcall(InCombatLockdown)
    return ok and Public(value)==false
end
local function PositionSettings()
    local db=RA:GetDB();return db,type(db)=="table"and type(db.deathRecap)=="table"and db.deathRecap or nil
end
local function StoredPosition()
    local _,settings=PositionSettings();local position=settings and Public(settings.position)
    if type(position)~="table"or getmetatable(position)~=nil then return nil end
    local x,y=Metric(position.x),Metric(position.y)
    if Public(position.point)=="TOPLEFT"and Public(position.relativePoint)=="TOPLEFT"and x and y and math.abs(x)<1000000 and math.abs(y)<1000000 then return x,y end
end
local function RestorePosition()
    if not frame or dragging then return end
    local x,y=StoredPosition()
    local pw,ph=ReadMetric(UIParent,"GetWidth"),ReadMetric(UIParent,"GetHeight")
    local fs,ps=ReadMetric(frame,"GetEffectiveScale"),ReadMetric(UIParent,"GetEffectiveScale")
    local fw,fh=ReadMetric(frame,"GetWidth"),ReadMetric(frame,"GetHeight")
    if not pw or not ph or pw<=0 or ph<=0 or not fs or not ps or fs<=0 or ps<=0 or not fw or not fh then
        Place(frame,"CENTER",UIParent,"CENTER",0,50);return
    end
    fw,fh=fw*fs/ps,fh*fs/ps
    x,y=x or(pw-fw)/2,y or-(ph-fh)/2+50
    x=math.max(0,math.min(math.max(0,pw-fw),x))
    y=math.min(0,math.max(-math.max(0,ph-fh),y))
    -- Store/use the addon's existing UIParent-space top-left convention. Height
    -- changes grow down from this anchor; a smaller screen keeps the header in reach.
    Place(frame,"TOPLEFT",UIParent,"TOPLEFT",x,y)
end
local function StopDragging(save)
    if not dragging then return end
    local owner=dragProfile;dragging,dragProfile=nil,nil
    frame:StopMovingOrSizing()
    local db,settings=PositionSettings()
    if save and MoveAllowed()and owner==db and settings and type(RA.CaptureFrameTopLeft)=="function"then
        local position={};local ok,captured=pcall(RA.CaptureFrameTopLeft,RA,frame,position)
        local x,y=Metric(position.x),Metric(position.y)
        if ok and captured==true and x and y and math.abs(x)<1000000 and math.abs(y)<1000000 then
            settings.position={point="TOPLEFT",relativePoint="TOPLEFT",x=x,y=y}
        end
    end
    RestorePosition()
end
function UI:ResetPosition()
    if not MoveAllowed()then return false end
    StopDragging(false)
    local _,settings=PositionSettings();if settings then settings.position=nil end
    RestorePosition();return true
end
local function StopMotion()
    for _,b in ipairs(damagePool)do if b.span then b.span:SetScript("OnUpdate",nil)end end
end
function UI:Hide()
    if closing then return end;closing=true
    StopDragging(false);PositionDemand(false)
    StopMotion();HideTooltip();R:CancelShare("Log closed");if share then if share.copy then share.copy:ClearFocus()end;share:Hide()end;if actionShield then actionShield:Hide()end
    if frame then
        frame:Hide();frame.selected,frame.selectedItem=nil,nil;frame.healthPanel:SetScript("OnEnter",nil)
        if frame.historyMenu then frame.historyMenu:Hide()end
        for _,b in ipairs(damagePool)do b.group=nil;b:SetScript("OnEnter",nil);b:SetScript("OnClick",nil);b:SetScript("OnMouseWheel",nil)
            if b.span then b.span:SetScript("OnEnter",nil);b.span:SetScript("OnMouseWheel",nil)end
            if b.amountTarget then b.amountTarget:SetScript("OnEnter",nil);b.amountTarget:SetScript("OnMouseWheel",nil);b.amountTarget:SetScript("OnClick",nil)end
        end
        for _,pool in ipairs({supportPool,shelfPool,frame.supportMarkers or{},frame.castMarkers or{}})do for _,b in ipairs(pool)do b:SetScript("OnEnter",nil)end end
    end;sample,current,examplePage=false,nil,nil;selected,model,domain=nil,nil,nil;memberChoices={};renderRevision=renderRevision+1;closing=false
    RA:FireCallback("DEATH_RECAP_VISIBILITY",false)
end
function UI:IsShown()return frame and frame:IsShown()or false end
local function RefreshReminderSwitch()
    if not frame or not frame.reminder then return end
    local b=frame.reminder;local enabled=RA.PersonalTools:GetState().consumableReminder==true
    b.enabledSetting=enabled
    T:SetRoundedColor(b.track,enabled and C.activeDark or C.input,"base")
    Place(b.knob,enabled and"RIGHT"or"LEFT",b.track,enabled and"RIGHT"or"LEFT",enabled and-1 or 1,0)
    b.knob:SetVertexColor(enabled and 1 or .56,enabled and 1 or .55,enabled and 1 or .66,enabled and 1 or .85)
    if tooltipOwner==b and not tooltipNative and tooltipRecap and tooltipRecap:IsShown()then
        RecapBox({"Consumable reminder","Healthstone and healing-potion alerts.",enabled and"On · Click to turn off."or"Off · Click to turn on."},nil,true);PositionTooltip()
    end
end
local function Ensure()
    if frame then return end
    frame=CreateFrame("Frame","RCPArsenalDeathRecap",UIParent);Size(frame,880,BASE_HEIGHT);Point(frame,"CENTER",UIParent,"CENTER",0,50)
    frame:SetFrameStrata("DIALOG");frame:SetClampedToScreen(true);frame:EnableMouse(true);Surface(frame,C.canvasDeep);T:ApplyRounded(frame,{.48,.34,.52,.65},8,"border","BORDER")
    frame:SetMovable(true)
    frame.dragHandle=CreateFrame("Frame",nil,frame);Size(frame.dragHandle,550,52);Place(frame.dragHandle,"TOPLEFT",frame,"TOPLEFT",0,0)
    frame.dragHandle:EnableMouse(true);frame.dragHandle:RegisterForDrag("LeftButton")
    frame.dragHandle:SetScript("OnDragStart",function()
        if current and frame:IsVisible()and not(share and share:IsShown())and MoveAllowed()then
            dragProfile=RA:GetDB();dragging=true;HideTooltip();frame:StartMoving()
        end
    end)
    frame.dragHandle:SetScript("OnDragStop",function()StopDragging(true)end)
    frame.title=Label(frame,"Death Log",24,20,-18,142);RA:ApplyFont(frame.title,24,"BOLD",false)
    frame.historyNav=CreateFrame("Frame",nil,frame);Size(frame.historyNav,70,24);Place(frame.historyNav,"TOPLEFT",frame,"TOPLEFT",486,-22)
    frame.historyPrev=Button(frame.historyNav,"‹",18,function()UI:ShowHistory((frame.historyIndex or 1)+1)end);Place(frame.historyPrev,"LEFT",frame.historyNav,"LEFT",0,0)
    frame.historyPicker=Button(frame.historyNav,"1/1",30,function()
        if share and share:IsShown()then return end
        frame.historyMenu:SetShown(not frame.historyMenu:IsShown())
    end);Place(frame.historyPicker,"LEFT",frame.historyNav,"LEFT",19,0)
    frame.historyNext=Button(frame.historyNav,"›",18,function()UI:ShowHistory((frame.historyIndex or 1)-1)end);Place(frame.historyNext,"RIGHT",frame.historyNav,"RIGHT",0,0)
    frame.historyMenu=CreateFrame("Frame",nil,frame);Size(frame.historyMenu,420,150);Place(frame.historyMenu,"TOPRIGHT",frame.historyNav,"BOTTOMRIGHT",0,-4);frame.historyMenu:SetFrameLevel(frame:GetFrameLevel()+16);Surface(frame.historyMenu,C.canvasDeep)
    frame.historyButtons={}
    for i=1,5 do local index=i
        local b=Button(frame.historyMenu,"",404,function()UI:ShowHistory(index)end);frame.historyButtons[i]=b
        Place(b,"TOPLEFT",frame.historyMenu,"TOPLEFT",8,-8-(i-1)*28);b.label:SetWidth(390);b.label:SetWordWrap(false);b.label:SetMaxLines(1);b.label:SetJustifyH("LEFT")
    end
    frame.historyMenu:Hide()

    frame.playerName=Label(frame,"",14,174,-25,280,C.text);RA:ApplyFont(frame.playerName,14,"BOLD",false);frame.playerName:SetHeight(18);frame.playerName:SetWordWrap(false);frame.playerName:SetMaxLines(1);frame.playerName:Hide()
    frame.coverage=Label(frame,"Preview",10,174,-26,70,C.muted)
    frame.close=CreateFrame("Button",nil,frame);Size(frame.close,28,28);Point(frame.close,"TOPLEFT",frame,"TOPLEFT",832,-18)
    frame.close.label=Label(frame.close,"×",24,1,-1,26);frame.close:SetScript("OnClick",function()UI:Hide()end)
    frame.share=CreateFrame("Button",nil,frame);Size(frame.share,136,28);Point(frame.share,"TOPLEFT",frame,"TOPLEFT",674,-19)
    frame.share.icon=frame.share:CreateTexture(nil,"ARTWORK");Size(frame.share.icon,22,22);Point(frame.share.icon,"LEFT",frame.share,"LEFT",0,0)
    RA:RegisterVisualTexture(frame.share.icon,T.Assets.NavActions,T.Assets.White);frame.share.label=Label(frame.share,"Post to chat",12,28,-7,108)
    frame.share:SetScript("OnClick",function()UI:OpenShare()end)
    frame.reminder=CreateFrame("Button",nil,frame);Size(frame.reminder,72,28);Point(frame.reminder,"TOPLEFT",frame,"TOPLEFT",578,-18)
    frame.reminder.icon=frame.reminder:CreateTexture(nil,"ARTWORK");Size(frame.reminder.icon,22,22);Point(frame.reminder.icon,"LEFT",frame.reminder,"LEFT",0,0)
    RA:RegisterVisualTexture(frame.reminder.icon,"Interface\\Icons\\INV_Potion_51",T.Assets.White)
    frame.reminder.track=CreateFrame("Frame",nil,frame.reminder);Size(frame.reminder.track,40,20);Place(frame.reminder.track,"RIGHT",frame.reminder,"RIGHT",0,0);Surface(frame.reminder.track,C.input)
    frame.reminder.knob=frame.reminder.track:CreateTexture(nil,"OVERLAY");Size(frame.reminder.knob,18,18);RA:RegisterVisualTexture(frame.reminder.knob,T.Assets.SliderThumb,T.Assets.White)
    frame.reminder:SetScript("OnClick",function()if not(share and share:IsShown())and ActionPage(current,IsExample())then RA.PersonalTools:SetOption("consumableReminder",not RA.PersonalTools:GetState().consumableReminder);RefreshReminderSwitch()end end)
    frame.reminder:SetScript("OnEnter",function(self)Tooltip(self,{"Consumable reminder","Healthstone and healing-potion alerts.",RA.PersonalTools:GetState().consumableReminder and"On · Click to turn off."or"Off · Click to turn on."})end)
    frame.reminder:SetScript("OnLeave",HideTooltip);RefreshReminderSwitch()
    if frame.share.SetMotionScriptsWhileDisabled then frame.share:SetMotionScriptsWhileDisabled(true)end
    frame.share:SetScript("OnEnter",function(self)Tooltip(self,{"Post to chat","Open this report in chat"})end)
    frame.share:SetScript("OnLeave",HideTooltip)
    frame.info=CreateFrame("Button",nil,frame);Size(frame.info,16,20);Point(frame.info,"TOPLEFT",frame,"TOPLEFT",218,-23)
    frame.info.label=Label(frame.info,"i",12,4,0,12,C.textSoft)
    frame.info:SetScript("OnEnter",function(self)
        local lines={"Encounter",frame.contextText or"Personal recap"}
        if frame.capturedFullName then lines[#lines+1]="Player: "..frame.capturedFullName end
        if IsExample()then lines[#lines+1]="Fictional sample"end
        if current and current.native and current.native.truncated then lines[#lines+1]="Partial death record"end
        if frame.viewport and frame.viewport.omitted>0 then lines[#lines+1]=frame.viewport.omitted.." retained events outside this timeline window; included in the full report"end
        if current and not IsExample()and not current.native then
            lines[#lines+1]=current.nativeStatus or"Hit details unavailable"
        end
        Tooltip(self,lines)
    end);frame.info:SetScript("OnLeave",HideTooltip)
    frame.percent=Label(frame,"—",20,48,-(HEALTH_TOP-30),58,pink);frame.percent:SetHeight(24);frame.percent:SetJustifyV("MIDDLE");RA:ApplyFont(frame.percent,20,"BOLD",false)
    frame.healthPanel=CreateFrame("Button",nil,frame);Size(frame.healthPanel,HEALTH_WIDTH,18);Point(frame.healthPanel,"TOPLEFT",frame,"TOPLEFT",48,-HEALTH_TOP)
    frame.healthTrack=frame.healthPanel:CreateTexture(nil,"BACKGROUND");frame.healthTrack:SetAllPoints(frame.healthPanel);frame.healthTrack:SetColorTexture(unpack(C.surfaceRaised))
    frame.healthBar=CreateFrame("StatusBar",nil,frame.healthPanel);Size(frame.healthBar,HEALTH_WIDTH,14);Point(frame.healthBar,"TOPLEFT",frame.healthPanel,"TOPLEFT",0,-2)
    frame.healthBar:SetStatusBarTexture(T.Assets.White);frame.healthBar:SetStatusBarColor(unpack(pink))
    frame.hp=Label(frame,"",11,552,-(HEALTH_TOP-23),280,C.textSoft);frame.hp:SetJustifyH("RIGHT")
    frame.healthContext=Label(frame,"Selected health",11,116,-(HEALTH_TOP-23),400,C.muted)
    frame.healing=CreateFrame("Frame",nil,frame.healthPanel);frame.healing:SetFrameLevel(frame.healthBar:GetFrameLevel()+2)
    frame.healing.fill=frame.healing:CreateTexture(nil,"OVERLAY");frame.healing.fill:SetAllPoints(frame.healing);frame.healing.fill:SetColorTexture(unpack(C.success));frame.healing:Hide()
    frame.shelf=Label(frame,"Cooldowns",12,550,-83,28,C.textSoft);frame.shelf:SetHeight(18);frame.shelf:SetJustifyV("MIDDLE")
    frame.shelfAge=Label(frame,"",10,590,-106,266,C.muted)
    frame.rail=frame:CreateTexture(nil,"ARTWORK");frame.rail:SetColorTexture(.58,.53,.65,.70)
    frame.ticks={};frame.tickLabels={};frame.tickMarks={};for i=1,6 do frame.ticks[i]=Font(frame,11,nil,C.textSoft);frame.tickMarks[i]=frame:CreateTexture(nil,"ARTWORK");frame.tickMarks[i]:SetColorTexture(unpack(C.lineStrong))end
    frame.fight=Label(frame,"",11,690,-177,170,C.textSoft);frame.fight:SetJustifyH("RIGHT")
    frame.death=Font(frame,11,"BOLD",pink);frame.death:Hide()
    frame.guide=CreateFrame("Frame",nil,frame);frame.guide.dashes={};for i=1,96 do local t=frame.guide:CreateTexture(nil,"ARTWORK");frame.guide.dashes[i]=t;t:Hide()end;frame.guide:Hide()
    frame.interval=frame:CreateTexture(nil,"BACKGROUND");frame.interval:SetColorTexture(pink[1],pink[2],pink[3],.04);frame.interval:Hide()
    frame.empty=Label(frame,"No hit details recorded",12,48,-270,784,C.muted)
    if type(UISpecialFrames)=="table"then table.insert(UISpecialFrames,"RCPArsenalDeathRecap")end
    frame:SetScript("OnHide",function()if not closing then UI:Hide()end end)
    frame:Hide()
end
local function Roster(page,example,time)return R:GetCooldownRows(page,example)end
local function State(row,example)return row.recordedState,row.detail end
local function CooldownSlots(rows)
    local slots,col,line,gap={},0,0,0
    local itemCount=0;for _,row in ipairs(rows)do if row.kind then itemCount=itemCount+1 end end
    local itemsStarted=false
    for i,row in ipairs(rows)do
        if row.kind and not itemsStarted then
            itemsStarted=true
            if itemCount<=7 and col>0 and 7-col<itemCount then col,line,gap=0,line+1,0 end
            if col>0 then gap=6 end
        end
        slots[i]={x=590+col*38+gap,line=line}
        col=col+1;if col==7 then col,line,gap=0,line+1,0 end
    end
    return slots
end
function UI:PaintCooldownStatus(b,texture,state,row)
    local shade=state==false and .4 or 1
    if state==nil then texture:SetVertexColor(.55,.65,.85);texture:SetAlpha(.8)else texture:SetVertexColor(shade,shade,shade);texture:SetAlpha(1)end
    texture:SetDesaturated(state==false)
    if not b.statusBadge then
        b.statusBadge=CreateFrame("Frame",nil,b);Size(b.statusBadge,16,16);Place(b.statusBadge,"BOTTOMRIGHT",b,"BOTTOMRIGHT",2,-2);Surface(b.statusBadge,C.canvasDeep)
        b.statusLines={b.statusBadge:CreateLine(nil,"OVERLAY"),b.statusBadge:CreateLine(nil,"OVERLAY")}
        for _,line in ipairs(b.statusLines)do line:SetThickness(2)end
        b.info=Font(b.statusBadge,11,"BOLD",C.textSoft);Place(b.info,"CENTER",b.statusBadge,"CENTER",0,0)
    end
    -- Expressway has no checkmark glyph. Draw both proven states so their
    -- meaning survives font changes; the unknown question mark is text.
    Text(b.info,state==true and"✓"or state==false and"×"or"?");b.info:SetShown(state==nil);b.recordedState=state
    b.info:SetTextColor(unpack(C.textSoft));b.nativeChargeCount=state==nil and row and R:RenderRecordedChargeCount(b.info,row)or false
    if b.nativeChargeCount then b.info:SetTextColor(unpack(C.text))end
    for _,line in ipairs(b.statusLines)do line:SetShown(state~=nil);line:SetColorTexture(unpack(state==true and C.success or C.danger))end
    if state==true then
        b.statusLines[1]:SetStartPoint("TOPLEFT",b.statusBadge,3,-8);b.statusLines[1]:SetEndPoint("TOPLEFT",b.statusBadge,6,-11)
        b.statusLines[2]:SetStartPoint("TOPLEFT",b.statusBadge,6,-11);b.statusLines[2]:SetEndPoint("TOPLEFT",b.statusBadge,13,-4)
    elseif state==false then
        b.statusLines[1]:SetStartPoint("TOPLEFT",b.statusBadge,4,-4);b.statusLines[1]:SetEndPoint("TOPLEFT",b.statusBadge,12,-12)
        b.statusLines[2]:SetStartPoint("TOPLEFT",b.statusBadge,12,-4);b.statusLines[2]:SetEndPoint("TOPLEFT",b.statusBadge,4,-12)
    end
end
local function Shelf(page,example,time)
    Text(frame.shelf,"CDs");frame.shelfSource=example and"Preview death snapshot"or"Last recorded check"
    Text(frame.shelfAge,"")
    local rows=Roster(page,example,time);local signature={}
    for _,row in ipairs(rows)do local state=State(row,example);signature[#signature+1]=tostring(row.spellID or row.itemID or row.kind)..":"..tostring(state)end
    local key=table.concat(signature,";")
    if frame.shelfKey==key then return end;frame.shelfKey=key;HidePool(shelfPool)
    local slots=CooldownSlots(rows)
    frame.shelfAge:Hide()
    for i,row in ipairs(rows)do
        local b=shelfPool[i]or Icon(frame,32);shelfPool[i]=b
        local line,x=slots[i].line,slots[i].x
        Place(b,"TOPLEFT",frame,"TOPLEFT",x,-76-line*38);Artwork(b,row);Text(b.badge,"");b:Show()
        local state,detail=State(row,example);UI:PaintCooldownStatus(b,b.icon,state,row)
        b.detailMember=0;b:EnableMouseWheel(row.members and #row.members>1 or false)
        local function ShowShelf(self)
            if current~=page or example~=IsExample()then return end
            local lines={row.name or(row.kind=="stone"and"Healthstone"or row.kind=="potion"and"Healing potion"or"Defensive")}
            if example then lines[#lines+1]=detail end
            local focusIndex
            if not example then
                local checked=R:GetRecordedCheckTime(row)
                if not row.kind then
                    local use=page.observedUses and page.observedUses[row.spellID]
                    if use and Number(use.observedCount,true)then
                        lines[#lines+1]=(use.observedCount==1 and"Used once"or"Used "..use.observedCount.." times").." · Last "..UseAge(page,use.lastSuccessfulUseAt)
                    else lines[#lines+1]="No use recorded"end
                    local status
                    if state==true then status="Available when checked"
                    elseif state==false then status=row.cooldown=="held"and"Cooldown on hold when checked"or row.currentCharges==0 and"No charges when checked"or"On cooldown when checked"
                    elseif row.pendingAt or row.chargesPendingAt then status="Availability not confirmed"
                    elseif row.chargeQuery=="public"and row.currentCharges==nil then status="Charges not confirmed"
                    elseif row.cooldown=="active-context-unknown"or row.cooldown=="gcd-observed"then status="Cooldown uncertain"
                    else status="Availability not recorded"end
                    lines[#lines+1]=status
                else lines[#lines+1]=state==true and"Available when checked"or state==false and"Unavailable when checked"or"Availability not confirmed"end
                if checked then lines[#lines+1]="Checked "..UseAge(page,checked)end
                if row.chargesActive==true and not row.chargesPendingAt then lines[#lines+1]="Recharging when checked"..(row.chargesAt and(" · "..UseAge(page,row.chargesAt))or"")end
                if row.currentCharges~=nil and not row.chargesPendingAt and not row.pendingAt then lines[#lines+1]="Charges: "..row.currentCharges end
                if row.physicalCount~=nil then lines[#lines+1]="Carried: "..row.physicalCount end
                if row.remainingUses~=nil then lines[#lines+1]="Uses left: "..row.remainingUses end
                if b.nativeChargeCount then lines[#lines+1]="Captured charge count displayed directly by Blizzard; availability remains unconfirmed."
                elseif page.restored and row.chargeCountStatus=="restricted"then lines[#lines+1]="Opaque charge count was not saved; unavailable after reload."end
                for _,note in ipairs(R:GetPrecombatNotes(row))do lines[#lines+1]=note end
                if row.members and #row.members>1 then lines[#lines+1]="Mouse wheel: inspect recorded items"end
                for index,member in ipairs(row.members or{})do
                    local item=member.row
                    local text=(item.itemID and"Item "..item.itemID or"Bag check")..": "..member.detail
                    if item.physicalCount~=nil then text=text.." · Carried: "..item.physicalCount end
                    if item.remainingUses~=nil then text=text.." · Uses left: "..item.remainingUses end
                    if item.observedAt then text=text..string.format(" · Checked %.1fs before death",page.diedAt-item.observedAt)end
                    if item.carriedAt then text=text..string.format(" · Bag check %.1fs before death",page.diedAt-item.carriedAt)end
                    lines[#lines+1]=text;if self.detailMember==index then focusIndex=#lines end
                end
            end
            local itemID=row.itemID or(row.members and #row.members==1 and row.representativeItemID)
            Tooltip(self,lines,row.spellID,itemID,nil,focusIndex)
        end
        b:SetScript("OnEnter",ShowShelf)
        b:SetScript("OnMouseWheel",function(self,delta)
            if not row.members or #row.members<2 then return end
            self.detailMember=math.max(0,math.min(#row.members,self.detailMember+(delta<0 and 1 or -1)));ShowShelf(self)
        end)
    end
end
local function Health(page,row,example,item)
    frame.healthBar:Hide();frame.healing:Hide();Text(frame.hp,"");Text(frame.percent,"—")
    local max=example and page.maxHealth or page.native and Number(page.native.recapID,true)and Number(page.native.recapMaxHealth,true)
    local allowed=example or page.native and Number(page.native.recapID,true)
    local hp=allowed and Number(example and row.exampleHP or row.recordedHP)or nil
    frame.healthPanel.selectedHP,frame.healthPanel.selectedMax=hp,max
    frame.healthPanel.effectiveHealing=nil
    local context=row.nativeIndex and(row.nativeIndex==1 and(row.kind=="damage"and"Killing blow"or"Death record")or"Selected event")or"Selected health"
    Text(frame.healthContext,context..(row.nativeIndex and row.nativeIndex~=1 and(" · "..At(row.nativeOffset))or""))
    if hp~=nil then
        Text(frame.hp,Raw(hp)..(max and" / "..Raw(max)or""))
        if max and hp<=max then
            frame.healthBar:SetMinMaxValues(0,max);frame.healthBar:SetValue(hp);frame.healthBar:Show();Text(frame.percent,string.format("%.0f%%",hp/max*100))
            -- Only the controlled Preview has effective-heal and post-heal HP
            -- evidence. Native damage/absorb credits cannot supply this segment.
            local heal=example and Number(row.effectiveHealing,true)
            if heal and heal<=hp then
                frame.healthPanel.effectiveHealing=heal
                Size(frame.healing,heal/max*HEALTH_WIDTH,14);Place(frame.healing,"TOPLEFT",frame.healthPanel,"TOPLEFT",(hp-heal)/max*HEALTH_WIDTH,-2);frame.healing:Show()
            end
        end
    else Text(frame.hp,"Health not recorded")end
    frame.healthPanel:SetScript("OnEnter",function(self)
        local lines={"Health",hp~=nil and(Raw(hp)..(max and" / "..Raw(max)or"").." health")or"Health not recorded for this event"}
        if hp==nil and max then lines[#lines+1]="Max health: "..Raw(max)end
        if hp and max and hp>max then lines[#lines+1]="Above the recorded health scale"end
        if frame.healthPanel.effectiveHealing then lines[#lines+1]={text=Amount(frame.healthPanel.effectiveHealing).." effective healing · Fictional sample",color=C.success}end
        Tooltip(self,lines)
    end);frame.healthPanel:SetScript("OnLeave",HideTooltip)
end
local function Representative(item)return item.representative or item.rows[1]end
local function Select(page,row,item,force)
    if page~=current or not row then return end
    if not force and((share and share:IsShown()))then return end
    if not force and selected==row and frame.selectedItem==item then return end
    selected=row;frame.selected=row;frame.selectedItem=item;Health(page,row,IsExample(),item);Shelf(page,IsExample(),row.nativeOffset)
    local focusX=item and item.iconX or X(row.nativeOffset)
    Place(frame.guide,"TOPLEFT",frame,"TOPLEFT",focusX,-130-(contentShift or 0));Size(frame.guide,1,HEALTH_TOP-40-130+extraHeight-(contentShift or 0));Guide(focusX,130+(contentShift or 0),HEALTH_TOP-40+extraHeight);frame.guide:Show()
    for _,b in ipairs(damagePool)do if b.selectedBorder then b.selectedBorder:SetShown(b:IsShown()and b.group==item)end end
    if item then Place(frame.interval,"TOPLEFT",frame,"TOPLEFT",X(item.first),-130-(contentShift or 0));Size(frame.interval,math.max(1,X(item.last)-X(item.first)),HEALTH_TOP-40-130+extraHeight-(contentShift or 0));frame.interval:Show()else frame.interval:Hide()end
end
local function SelectedTooltip(b,page,target)
    local item=b.group;local row=item.rows[b.member or 1];local lines={#item.rows>1 and"Damage cluster"or row.name or"Recorded event"}
    local focusIndex
    local amount=row.amount~=nil and Amount(row.amount)or"Amount unavailable"
    if #item.rows==1 then
        lines[#lines+1]=amount..(row.amount~=nil and(row.kind=="damage"and" damage"or" recorded")or"")
        lines[#lines+1]=RecapAge(row.nativeOffset)
    else
        local total=item.amountComplete and Amount(item.amount)or(item.knownAmounts>0 and"≥"..Amount(item.amount)or"Amount unavailable")
        local noun="hits";for _,member in ipairs(item.rows)do if member.kind~="damage"then noun="events";break end end
        lines[#lines+1]=total..(noun=="hits"and" damage"or" recorded").." · "..#item.rows.." "..noun
        local representative=Representative(item)
        lines[#lines+1]="Icon: "..(representative.name or"Recorded hit")..(representative.amount==nil and" · Representative event"or item.amountComplete and" · Largest hit"or" · Largest known hit")
        if item.fatalRow then lines[#lines+1]=item.fatalRow.kind=="damage"and"Contains killing blow"or"Contains death record"end
        lines[#lines+1]="Mouse wheel: inspect each hit"
        for i,member in ipairs(item.rows)do
            local source=member.sourceName and member.hideCaster~=true and member.hideCasterStatus~="restricted"and(" · "..member.sourceName)or""
            lines[#lines+1]=(i==b.member and"› "or"")..string.format("%.1fs · ",member.nativeOffset)..(member.name or"Recorded hit").." · "..(member.amount~=nil and ExactAmount(member.amount)or"Amount unavailable")..source..(member.nativeIndex==1 and(member.kind=="damage"and" · Killing blow"or" · Death record")or"")..(i==b.member and" · Health shown"or"")
            if i==b.member then focusIndex=#lines end
        end
    end
    if row.sourceName and row.hideCaster~=true and row.hideCasterStatus~="restricted"then lines[#lines+1]={text="Source: "..row.sourceName,color=C.textSoft}end
    if row.nativeIndex==1 then lines[#lines+1]=row.kind=="damage"and"Killing blow"or"Death record"end
    local mitigation={}
    for _,field in ipairs({{"overkill","Overkill"},{"resisted","Resisted"},{"blocked","Blocked"}})do
        local value=Number(row[field[1]]);if value and value>0 then mitigation[#mitigation+1]=field[2].." "..Amount(value)end
    end
    if #mitigation>0 then lines[#lines+1]=table.concat(mitigation," · ")end
    Tooltip(target or b,lines,row.spellID,nil,pink,focusIndex)
end
local function Nearest(item,time,currentRow)
    local best,distance
    for i,row in ipairs(item.rows)do
        local d=math.abs(row.nativeOffset-time)
        if not distance or d<distance or d==distance and row==currentRow then best,distance=i,d end
    end
    return best
end
local function CursorTime()
    if type(GetCursorPosition)~="function"then return nil end
    local x=Number(GetCursorPosition());local scale=frame:GetEffectiveScale()
    if not x or not scale or scale<=0 then return nil end
    local logical=x/scale-frame:GetLeft();return domain.first+(logical-48)/784*(domain.last-domain.first),logical
end
local function PrepareCastMarkers(page,example,alignment)
    frame.castMarkers=frame.castMarkers or{};HidePool(frame.castMarkers)
    for _,b in ipairs(frame.castMarkers)do HidePool(b.stems or{});HidePool(b.connectors or{})end
    frame.castAlignment=alignment
    local visible,plotted={},{}
    for _,entry in ipairs(frame.castAlignment and frame.castAlignment.aligned or{})do
        if entry.offset>=domain.first and entry.offset<=domain.last then visible[#visible+1]=entry;plotted[entry.index]=true end
    end
    frame.castFallback={}
    if not example then local uses=page.casts or{};for index=math.max(1,#uses-R.LIMITS.casts+1),#uses do local row=uses[index]
        if not plotted[index]then frame.castFallback[#frame.castFallback+1]=row end
    end end
    table.sort(visible,function(a,b)if a.offset==b.offset then return a.index<b.index end;return a.offset<b.offset end)
    local lanes=math.ceil(#visible/12);local ends,counts={},{}
    for lane=1,lanes do ends[lane],counts[lane]=-100,0 end
    for i,entry in ipairs(visible)do
        local b=frame.castMarkers[i]or Icon(frame,30);frame.castMarkers[i]=b
        local x=X(entry.offset);local lane
        for candidate=1,lanes do if counts[candidate]<12 and x-29>ends[candidate]then lane=candidate;break end end
        if not lane then for candidate=1,lanes do if counts[candidate]<12 and(not lane or ends[candidate]<ends[lane])then lane=candidate end end end
        b.entry,b.lane,b.timeX=entry,lane,x;b.iconX=math.max(x,ends[lane]+29);ends[lane]=b.iconX+29;counts[lane]=counts[lane]+1
        b.stems=b.stems or{};b.connectors=b.connectors or{}
        b.age=b.age or Font(b,10,"REGULAR",lavender);Place(b.age,"TOP",b,"BOTTOM",0,-3);Text(b.age,string.format("~%.1fs",entry.age))
    end
    for lane=1,lanes do local right=832
        for i=#visible,1,-1 do local b=frame.castMarkers[i];if b.lane==lane then b.iconX=math.min(b.iconX,right);right=b.iconX-58 end end
    end
    frame.castMarkerCount=#visible
    return lanes*48
end
local function RenderCastMarkers(page,shelfExtra,rail,revision)
    for i=1,frame.castMarkerCount do
        local b=frame.castMarkers[i];local entry=b.entry;local y=120+shelfExtra+(b.lane-1)*48
        Place(b,"TOP",frame,"TOPLEFT",b.iconX,-y);Artwork(b,entry.row);Text(b.badge,"");b:Show();b.damageY=y
        frame.textExclusions[#frame.textExclusions+1]={left=b.iconX-27,right=b.iconX+27,top=y-2,bottom=y+44}
        b:SetScript("OnEnter",function(self)
            if current~=page or revision~=renderRevision or IsExample()or(share and share:IsShown())then return end
            Tooltip(self,{entry.row.name or"Recorded cast",string.format("~%.1fs before death; aligned to death notification.",entry.age),R:GetRecordedUseRole(entry.row)=="utility"and"Recorded utility cast · Timing is approximate"or"Recorded successful cast · Timing is approximate"},entry.row.spellID,nil,lavender)
        end)
        b:SetScript("OnLeave",HideTooltip)
    end
    for i=1,frame.castMarkerCount do local b=frame.castMarkers[i]
        local y=b.damageY+46
        Rect(b.connectors,1,frame,math.min(b.iconX,b.timeX),y,math.max(1,math.abs(b.iconX-b.timeX)),1,lavender,.55)
        Stem(b.stems,b.timeX,y,rail-2,lavender,.55,frame.textExclusions)
    end
end
local function PrepareSupportMarkers(page,example)
    frame.supportMarkers=frame.supportMarkers or{};HidePool(frame.supportMarkers);for _,b in ipairs(frame.supportMarkers)do HidePool(b.stems or{});HidePool(b.brackets or{})end;frame.healTargets={}
    local rows={}
    if example then for _,row in ipairs(page.heals)do rows[#rows+1]={row=row,kind="healing",amount=row.amount}end end
    frame.absorbMeasure=frame.absorbMeasure or Font(frame,13,"BOLD");frame.absorbMeasure:Hide()
    local function AbsorbLabel(amount,count)return "+"..Amount(amount)..(count>1 and" ×"..count or"")end
    local clusters=M:GroupAbsorbs(model.rows,X,function(amount,count)
        Text(frame.absorbMeasure,AbsorbLabel(amount,count));return ReadMetric(frame.absorbMeasure,"GetUnboundedStringWidth")or frame.absorbMeasure:GetStringWidth()
    end)
    for _,group in ipairs(clusters)do rows[#rows+1]=group end
    table.sort(rows,function(a,b)if a.row.nativeOffset==b.row.nativeOffset then return a.row.nativeIndex<b.row.nativeIndex end;return a.row.nativeOffset<b.row.nativeOffset end)
    local laneEnds={};local maxLane=1
    for i,entry in ipairs(rows)do
        local b=frame.supportMarkers[i]or CreateFrame("Button",nil,frame);frame.supportMarkers[i]=b
        b.label=b.label or Font(b,13,"BOLD");b.label:SetJustifyH("CENTER");Place(b.label,"CENTER",b,"CENTER",0,0)
        b.color=entry.kind=="healing"and C.success or absorbBlue;b.label:SetTextColor(unpack(b.color))
        Text(b.label,AbsorbLabel(entry.amount,entry.rows and #entry.rows or 1))
        b.visualWidth=ReadMetric(b.label,"GetUnboundedStringWidth")or b.label:GetStringWidth()
        b.markerWidth=math.max(28,b.visualWidth+8);b.label:SetWidth(b.visualWidth)
        local x=entry.x or X(entry.row.nativeOffset);local lane=entry.lane or 1
        while not entry.lane and laneEnds[lane]and x-b.markerWidth/2<laneEnds[lane]+2 do lane=lane+1 end
        laneEnds[lane]=x+b.markerWidth/2;maxLane=math.max(maxLane,lane)
        b.entry,b.lane,b.timeX=entry,lane,x;Size(b,b.markerWidth,20);b.stems=b.stems or{};b.brackets=b.brackets or{}
        if entry.kind=="healing"then frame.healTargets[#frame.healTargets+1]=b end
    end
    frame.supportMarkerCount=#rows
    return math.max(0,maxLane-1)*20
end
local function RenderSupports(page,example,shelfExtra,rail,revision)
    local support=example and page.supports or UI:GroupRecordedUses(page,frame.castFallback)
    frame.recordedUseGroups=not example and support or nil
    local supportCount=math.min(#support,8)
    local overflow,chipWidths,chipLabels,usedWidth=nil,{},{},0
    if not example then
        frame.useMeasure=frame.useMeasure or Font(frame,11);frame.useMeasure:Hide()
        supportCount=0
        for i,group in ipairs(support)do
            local row=group.rows[#group.rows];local time,death=Number(row.observedAt),Number(page.diedAt)
            local age=time and death and death>=time and string.format("%.1fs",death-time)or"time unknown"
            local name=group.name or row.name or(group.spellID and("Spell "..group.spellID))or"Recorded use"
            local detail=(R:GetRecordedUseRole(row)=="utility"and"Utility · "or"")..(#group.rows>1 and("×"..#group.rows.." · ")or"")..age
            Text(frame.useMeasure,detail);local detailWidth=ReadMetric(frame.useMeasure,"GetUnboundedStringWidth")or frame.useMeasure:GetStringWidth()
            Text(frame.useMeasure,name.."  "..detail)
            local width=math.min(230,math.max(90,(ReadMetric(frame.useMeasure,"GetUnboundedStringWidth")or frame.useMeasure:GetStringWidth())+44))
            local reserve=i<#support and 44 or 0
            if i>8 or(i==8 and i<#support)or usedWidth+width+reserve>488 then break end
            supportCount=i;chipWidths[i]=width;chipLabels[i]={name=name,detail=detail,detailWidth=detailWidth};usedWidth=usedWidth+width+8
        end
    end
    if not example and supportCount<#support then
        overflow={groupCount=#support-supportCount,rows={}}
        for i=supportCount+1,#support do local group=support[i]
            for index,receipt in ipairs(group.rows)do overflow.rows[#overflow.rows+1]={group=group,receipt=receipt,index=index}end
        end
        supportCount=supportCount+1
    end
    frame.usesLabel=frame.usesLabel or Label(frame,"Used before death",10,48,-58,400,C.muted)
    Place(frame.usesLabel,"TOPLEFT",frame,"TOPLEFT",48,-58);frame.usesLabel:SetShown(not example and supportCount>0)
    local nextX=48
    for i=1,supportCount do local more=overflow and i==supportCount;local group=support[i];local row=example and group or group.rows[#group.rows];local b=supportPool[i]or Icon(frame,30);supportPool[i]=b
        b.useGroup=not example and not more and group or nil;b.useOverflow=more and overflow or nil;b.detailMember=0
        local detailCount=more and #overflow.rows or not example and #group.rows or 0
        b:EnableMouseWheel(detailCount>1);b:SetScript("OnMouseWheel",nil)
        local x=example and X(math.max(domain.first,row.offset))or nextX+15
        local width=example and 30 or more and 36 or chipWidths[i]
        Size(b,width,30);Place(b,"TOPLEFT",frame,"TOPLEFT",x-15,-(example and 104+shelfExtra or 76));nextX=nextX+width+8
        b.icon:ClearAllPoints();Point(b.icon,example and"CENTER"or"LEFT",b,example and"CENTER"or"LEFT",example and 0 or 2,0)
        if b.useLabel then b.useLabel:Hide();b.useMeta:Hide()end
        b.icon:Show();if b.overflowLabel then b.overflowLabel:Hide()end
        if more then
            b.icon:Hide();Text(b.badge,"");b.overflowLabel=b.overflowLabel or Font(b,11,"BOLD")
            Place(b.overflowLabel,"CENTER",b,"CENTER",0,0);Text(b.overflowLabel,"+"..overflow.groupCount);b.overflowLabel:Show()
        else
            Artwork(b,row);Text(b.badge,"")
            if not example then
                local label=chipLabels[i]
                b.useLabel=b.useLabel or Font(b,11);Place(b.useLabel,"LEFT",b,"LEFT",34,0)
                b.useMeta=b.useMeta or Font(b,11,nil,C.textSoft);Place(b.useMeta,"RIGHT",b,"RIGHT",-6,0)
                b.useLabel:SetWidth(width-46-label.detailWidth);b.useLabel:SetWordWrap(false);b.useLabel:SetMaxLines(1);Text(b.useLabel,label.name);b.useLabel:Show()
                b.useMeta:SetWidth(label.detailWidth);b.useMeta:SetWordWrap(false);b.useMeta:SetMaxLines(1);Text(b.useMeta,label.detail);b.useMeta:Show()
            end
        end
        b:Show()
        b.lines=b.lines or{};HidePool(b.lines)
        if example and row.finish then
            local scale=math.max(.1,ReadMetric(frame,"GetEffectiveScale")or 1)
            local function Snap(value)return math.floor(value*scale+.5)/scale end
            local start,finish=Snap(x+17),Snap(X(row.finish));local middle=119+shelfExtra
            local stroke=math.max(1,math.floor(4*scale+.5))/scale;local cap=math.max(1,math.floor(3*scale+.5))/scale
            if finish>start then Rect(b.lines,1,frame,start,Snap(middle-stroke/2),finish-start,stroke,lavender)end
            Rect(b.lines,2,frame,Snap(finish-cap/2),Snap(middle-6),cap,Snap(12),lavender)
            b.activationStems=b.activationStems or{};Stem(b.activationStems,x,137+shelfExtra,rail-2,lavender,.6,frame.textExclusions)
        end
        local function ShowUse(self)
            if current~=page or revision~=renderRevision then return end
            if more then
                local lines={overflow.groupCount.." more recorded abilities",#overflow.rows..(#overflow.rows==1 and" use recorded"or" uses recorded")}
                local focusIndex
                if #overflow.rows>1 then lines[#lines+1]="Mouse wheel to inspect uses"end
                for index,detail in ipairs(overflow.rows)do
                    local ability=detail.group;local receipt=detail.receipt
                    local name=ability.name or receipt.name or(ability.spellID and("Spell "..ability.spellID))or"Recorded use"
                    local count=#ability.rows>1 and(" · Use "..detail.index.."/"..#ability.rows)or""
                    lines[#lines+1]={text=name..count..(R:GetRecordedUseRole(receipt)=="utility"and" · Utility"or"").." · "..UseAge(page,receipt.observedAt),iconSpellID=ability.spellID}
                    if self.detailMember==index then focusIndex=#lines end
                end
                Tooltip(self,lines,nil,nil,nil,focusIndex);return
            end
            local lines={row.name or"Recorded use",example and"Recorded defensive activation"or(#group.rows==1 and"Used once"or"Used "..#group.rows.." times")}
            if R:GetRecordedUseRole(row)=="utility"then lines[#lines+1]="Recorded utility use"end
            local focusIndex
            if not example then
                for index,receipt in ipairs(group.rows)do
                    lines[#lines+1]=UseAge(page,receipt.observedAt)
                    if self.detailMember==index then focusIndex=#lines end
                end
                if #group.rows>1 then lines[#lines+1]="Mouse wheel to inspect uses"end
            end
            Tooltip(self,lines,row.spellID,nil,nil,focusIndex)
        end
        b:SetScript("OnEnter",ShowUse)
        if detailCount>1 then b:SetScript("OnMouseWheel",function(self,delta)
            self.detailMember=math.max(0,math.min(detailCount,self.detailMember+(delta<0 and 1 or -1)));ShowUse(self)
        end)end
    end
    for i=1,frame.supportMarkerCount do local b=frame.supportMarkers[i];local entry=b.entry;local row=entry.row
        local y=147+shelfExtra+(frame.castExtra or 0)+(b.lane-1)*20;Place(b,"CENTER",frame,"TOPLEFT",b.timeX,-y);b:Show()
        if entry.rows and #entry.rows>1 then
            local first,last=X(entry.first),X(entry.last)
            Rect(b.brackets,1,frame,first,rail-5,math.max(1,last-first),1,b.color,.7)
            Rect(b.brackets,2,frame,first,rail-8,1,6,b.color,.7);Rect(b.brackets,3,frame,last,rail-8,1,6,b.color,.7)
            Stem(b.stems,(first+last)/2,y+13,rail-5,b.color,.6,frame.textExclusions)
        else Stem(b.stems,X(row.nativeOffset),y+13,rail-2,b.color,.6,frame.textExclusions)end
        b.detailMember=0;b:EnableMouseWheel(entry.rows and #entry.rows>1 or false)
        local function ShowSupport(self)
            if current~=page or revision~=renderRevision or example~=IsExample()then return end
            if entry.kind=="healing"then Select(page,row,nil);Tooltip(self,{row.name,"+"..Amount(entry.amount).." healing","Healer: "..row.healer},row.spellID,nil,C.success)
            else
                local amount=Raw(entry.amount);local whole,rest=amount:match("^(%d+)(.*)$")
                if whole then amount=whole:reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")..rest end
                local members=entry.rows or{row};local lines
                if example then lines={"Shield absorption · "..#members..(#members==1 and" hit"or" hits"),"Total absorbed: "..amount,"Shield source not recorded."}
                else lines={ExactAmount(entry.amount).." absorbed"..(#members>1 and(" · "..#members.." hits")or""),{text="Shield not identified",color=C.muted},{text="Times relative to final recorded hit",color=C.muted}}end
                local focusIndex
                if example and #members>1 then lines[#lines+1]="Mouse wheel: inspect absorbed hits"end
                for index,member in ipairs(members)do
                    if example then lines[#lines+1]=string.format("%.3fs · %s · %s",member.nativeOffset,Raw(member.absorbed),member.name or"Recorded hit")
                    else lines[#lines+1]={text=member.name or"Recorded hit",iconSpellID=member.spellID,color=C.text,
                        amountText=ExactAmount(member.absorbed),amountColor=absorbBlue,timeText=string.format("%.1fs",member.nativeOffset)}end
                    if self.detailMember==index then focusIndex=#lines end
                end
                Tooltip(self,lines,nil,nil,absorbBlue,focusIndex)
                if not example and tooltipRecap.overflowing then
                    table.insert(lines,4,{text="Scroll to inspect hits",color=C.muted})
                    Tooltip(self,lines,nil,nil,absorbBlue,focusIndex and focusIndex+1)
                end
            end
        end
        b:SetScript("OnEnter",ShowSupport);b:SetScript("OnLeave",HideTooltip)
        b:SetScript("OnMouseWheel",function(self,delta)
            if not entry.rows or #entry.rows<2 then return end
            self.detailMember=math.max(0,math.min(#entry.rows,self.detailMember+(delta<0 and 1 or -1)));ShowSupport(self)
        end)
    end
end
function UI:Render()
    if not frame or not current then return end
    StopMotion();HideTooltip();renderRevision=renderRevision+1;local revision=renderRevision;local page,example=current,IsExample();frame.shelfKey=nil
    for _,pool in ipairs({damagePool,supportPool,shelfPool})do HidePool(pool)end
    for _,b in ipairs(damagePool)do if b.span then b.span:Hide()end;if b.amountTarget then b.amountTarget:Hide()end;if b.brackets then HidePool(b.brackets)end;if b.stems then HidePool(b.stems)end end
    for _,b in ipairs(supportPool)do if b.lines then HidePool(b.lines)end;if b.activationStems then HidePool(b.activationStems)end end
    local rows=page.native and page.native.rows or{}
    local referenceMax=example and Number(page.maxHealth,true)or page.native and Number(page.native.recapID,true)and Number(page.native.recapMaxHealth,true)
    local alignment=not example and M:AlignUses(page)or nil
    local viewport=M:Viewport(rows,referenceMax,alignment);frame.viewport=viewport
    model=M:Group(viewport.rows,example and page.transitions or{},{items=16});domain={first=viewport.first,last=viewport.last}
    frame.timeDomain=domain
    local castExtra=PrepareCastMarkers(page,example,alignment);frame.castExtra=castExtra
    local supportExtra=PrepareSupportMarkers(page,example);frame.supportExtra=supportExtra
    local elapsed=page.encounter and page.encounter.startedAt and page.diedAt-page.encounter.startedAt
    Text(frame.fight,elapsed and string.format("Fight %d:%02d",math.floor(elapsed/60),math.floor(elapsed%60))or"")
    local deathX=832;for _,row in ipairs(model.rows)do if row.nativeIndex==1 then deathX=X(row.nativeOffset);break end end
    local fightExtra=0;local fightWidth=ReadMetric(frame.fight,"GetUnboundedStringWidth")or frame.fight:GetStringWidth()
    if elapsed then for i=1,frame.supportMarkerCount do local b=frame.supportMarkers[i]
        if b.timeX+b.visualWidth/2>deathX-fightWidth-4 and b.timeX-b.visualWidth/2<deathX+4 then fightExtra=20;break end
    end end
    frame.fightSlotExtra=fightExtra
    frame.info:Show();Header(page,example)
    local records=R:GetHistory();local active=1
    for i,record in ipairs(records)do if record==page then active=i end end
    frame.historyIndex=active;frame.historyNav:SetShown(not example and #records>0)
    Text(frame.historyPicker.label,active.."/"..math.max(1,#records));frame.historyPrev:SetEnabled(active<#records);frame.historyNext:SetEnabled(active>1)
    for i,b in ipairs(frame.historyButtons)do local record=records[i];b:SetShown(record~=nil)
        if record then
            local label=record.encounter and record.encounter.name or record.playerName or record.class or"Personal death"
            local stamp="Death "..record.id
            if record.recordedAt and type(date)=="function"then local ok,value=pcall(date,"%m/%d %H:%M",record.recordedAt);if ok and CapturedText(value)then stamp=value end end
            Text(b.label,i.." · "..label..(record.playerName and(" · "..record.playerName)or"").." · "..stamp)
        end
    end
    frame.historyMenu:SetHeight(16+#records*28)

    frame.contextText=(page.specID==62 and"Arcane Mage"or page.class or"Personal")..(page.encounter and page.encounter.name and" · "..page.encounter.name or"")..(page.encounter and page.encounter.difficulty==16 and" · Mythic"or"")
    RefreshReminderSwitch()
    frame.share:SetEnabled(true);frame.share:SetAlpha(1)
    local roster=Roster(page,example,selected and selected.nativeOffset or 0);local shelfExtra=math.max(0,math.ceil(#roster/7)-1)*38;frame.shelfShift=shelfExtra
    local tierTotal=math.max(1,math.ceil(#model.items/8));local tierEnd,tierCount={},{}
    for tier=1,tierTotal do tierEnd[tier],tierCount[tier]=-100,0 end
    for _,item in ipairs(model.items)do
        local x=(X(item.first)+X(item.last))/2;local tier
        for candidate=1,tierTotal do
            if tierCount[candidate]<8 and x-46>tierEnd[candidate]then tier=candidate;break end
        end
        if not tier then for candidate=1,tierTotal do
            if tierCount[candidate]<8 and(not tier or tierEnd[candidate]<tierEnd[tier])then tier=candidate end
        end end
        tierCount[tier]=tierCount[tier]+1
        item.tier=tier;item.iconX=math.max(x,tierEnd[tier]+46);tierEnd[tier]=item.iconX+46
    end
    -- Artwork can pack; spans retain actual time while focus follows its icon.
    for tier=1,tierTotal do local right=832
        for i=#model.items,1,-1 do local item=model.items[i];if item.tier==tier then item.iconX=math.min(item.iconX,right);right=item.iconX-92 end end
    end
    contentShift=shelfExtra;extraHeight=shelfExtra+castExtra+supportExtra+fightExtra+(tierTotal-1)*TIER_GAP;Size(frame,880,BASE_HEIGHT+extraHeight);RestorePosition()
    local viewWidth,viewHeight=UIParent:GetWidth(),UIParent:GetHeight()
    if viewWidth and viewHeight and viewWidth>40 and viewHeight>80 then frame:SetScale(math.min(1,(viewWidth-40)/880,(viewHeight-80)/(BASE_HEIGHT+extraHeight)))end
    local hasTimeline=example or #model.rows>0
    local rail=168+shelfExtra+castExtra+supportExtra+fightExtra;Place(frame.rail,"TOPLEFT",frame,"TOPLEFT",48,-rail);Size(frame.rail,784,1);frame.rail:SetShown(hasTimeline)
    for i=1,6 do local time=domain.first+(domain.last-domain.first)*(i-1)/5;local x=X(time)
        Place(frame.ticks[i],"TOP",frame,"TOPLEFT",x,-rail-10);frame.tickLabels[i]=hasTimeline and(time==0 and"0s"or string.format(time%1==0 and"%s%.0fs"or"%s%.1fs",time<0 and"−"or"",math.abs(time)))or"";Text(frame.ticks[i],frame.tickLabels[i]);frame.ticks[i]:SetShown(hasTimeline)
        Place(frame.tickMarks[i],"TOPLEFT",frame,"TOPLEFT",x,-rail+4);Size(frame.tickMarks[i],1,8);frame.tickMarks[i]:SetShown(hasTimeline)
    end
    Place(frame.fight,"TOPRIGHT",frame,"TOPRIGHT",-20,-rail+25);frame.fight:SetShown(hasTimeline)
    frame.death:Hide();frame.deathX=nil
    for _,row in ipairs(model.rows)do if row.nativeIndex==1 then
        local x=X(row.nativeOffset);frame.deathX=x;Place(frame.death,"TOP",frame,"TOPLEFT",x,-rail-10);Text(frame.death,"Death");frame.death:Show()
        for i=1,6 do local time=domain.first+(domain.last-domain.first)*(i-1)/5;if math.abs(X(time)-x)<32 then Text(frame.ticks[i],"");frame.tickLabels[i]=""end end
    end end
    Place(frame.fight,"BOTTOMRIGHT",frame,"TOPLEFT",frame.deathX or 832,-rail+8)
    Place(frame.healthPanel,"TOPLEFT",frame,"TOPLEFT",48,-HEALTH_TOP-extraHeight)
    Place(frame.percent,"TOPLEFT",frame,"TOPLEFT",48,-(HEALTH_TOP-30)-extraHeight)
    Place(frame.hp,"TOPLEFT",frame,"TOPLEFT",552,-(HEALTH_TOP-23)-extraHeight)
    Place(frame.healthContext,"TOPLEFT",frame,"TOPLEFT",116,-(HEALTH_TOP-23)-extraHeight)
    frame.guide:Hide();frame.interval:Hide();frame.empty:SetShown(#model.rows==0)
    Text(frame.empty,page.restored and not page.native and"Saved death: hit details were not captured"or not example and not page.native and(page.nativeAttempts and page.nativeAttempts<R.LIMITS.attempts and"Hit details are loading"or"Hit details unavailable")or viewport.retainedCount>0 and"No recorded events in this window · Full report has older events"or"No hit details recorded")
    for index,item in ipairs(model.items)do
        local b=damagePool[index]or Icon(frame,46);damagePool[index]=b;b.group=item
        local keys={};for _,row in ipairs(item.rows)do keys[#keys+1]=row.nativeIndex end;local groupKey=table.concat(keys,":")
        b.member=1
        local initialMember=item.fatalRow or Representative(item)
        for i,row in ipairs(item.rows)do if row==initialMember then b.member=i end end
        for i,row in ipairs(item.rows)do if row.nativeIndex==memberChoices[groupKey]then b.member=i end end
        local y=rail+50+(item.tier-1)*TIER_GAP;Place(b,"TOP",frame,"TOPLEFT",item.iconX,-y);b:Show()
        DamageBadges(b);Text(b.badge,"")
        b.icon:Show();Artwork(b,Representative(item))
        Text(b.countText,"×"..#item.rows);Size(b.countBadge,math.max(24,b.countText:GetStringWidth()+8),16);b.countBadge:SetShown(#item.rows>1)
        b.mixedLabel=b.mixedLabel or Font(b,11,"BOLD",pink);Place(b.mixedLabel,"CENTER",b,"CENTER",0,0);Text(b.mixedLabel,"")
        b.amount=b.amount or Font(b,15,"BOLD",pink);Place(b.amount,"BOTTOM",b,"TOP",0,14)
        Text(b.amount,item.amountComplete and Amount(item.amount)or(item.knownAmounts>0 and"≥"..Amount(item.amount)or"—"))
        b.brackets=b.brackets or{}
        local first,last=X(item.first),X(item.last);local spanY=y-6
        Rect(b.brackets,1,frame,first,spanY,math.max(1,last-first),1,pink)
        Rect(b.brackets,2,frame,first,spanY-3,1,7,pink);Rect(b.brackets,3,frame,last,spanY-3,1,7,pink)
        Rect(b.brackets,4,frame,math.min(item.iconX,(first+last)/2),spanY,math.abs(item.iconX-(first+last)/2),1,pink,.5)
        T:SetRoundedColor(b,C.lineStrong,"base");b.selectedBorder:Hide()
        b.fatalMark=b.fatalMark or Font(b,11,"BOLD",pink);Place(b.fatalMark,"TOPLEFT",b,"TOPLEFT",-2,6);Text(b.fatalMark,item.fatal and"†"or"")
        b.span=b.span or CreateFrame("Button",nil,frame);Size(b.span,math.max(1,last-first),12);Place(b.span,"CENTER",frame,"TOPLEFT",(first+last)/2,-spanY);b.scrubAvailable=item.count>1 and last>first;b.span:SetShown(b.scrubAvailable)
        local function ChooseMember(i,target)
            if current~=page or example~=IsExample()or revision~=renderRevision or(share and share:IsShown())then return end
            memberChoices[groupKey]=item.rows[i].nativeIndex;b.member=i;Select(page,item.rows[i],item);SelectedTooltip(b,page,target)
        end
        b.amountTarget=b.amountTarget or CreateFrame("Button",nil,frame);b.amountWidth=math.max(46,math.min(84,b.amount:GetStringWidth()+8));b.damageY=y;b.spanY=spanY;Size(b.amountTarget,b.amountWidth,22);Place(b.amountTarget,"BOTTOM",b,"TOP",0,12);b.amountTarget:Show()
        b:SetScript("OnEnter",function(self)ChooseMember(b.member,self)end);b.amountTarget:SetScript("OnEnter",function(self)ChooseMember(b.member,self)end);b.amountTarget:SetScript("OnLeave",HideTooltip)
        b:SetScript("OnLeave",HideTooltip)
        local function Wheel(target,delta)
            local next=b.member+(delta>0 and-1 or 1);if next<1 then next=#item.rows elseif next>#item.rows then next=1 end
            ChooseMember(next,target);local _,x=CursorTime();b.lastCursorX=x
        end
        b:EnableMouseWheel(true);b:SetScript("OnMouseWheel",Wheel);b.span:EnableMouseWheel(true);b.span:SetScript("OnMouseWheel",Wheel);b.amountTarget:EnableMouseWheel(true);b.amountTarget:SetScript("OnMouseWheel",Wheel)
        b.span:SetScript("OnEnter",function(self)
            if current~=page or example~=IsExample()or revision~=renderRevision or not self:IsShown()then return end
            local time,x=CursorTime();b.lastCursorX=x;if time then ChooseMember(Nearest(item,time,selected),self)else ChooseMember(b.member,self)end
            self:SetScript("OnUpdate",function()
                local time,x=CursorTime();if current~=page or revision~=renderRevision or not time then self:SetScript("OnUpdate",nil);return end
                if not b.lastCursorX or math.abs(x-b.lastCursorX)>=.5 then b.lastCursorX=x;local i=Nearest(item,time,selected);if i~=b.member then ChooseMember(i,self)end end
            end)
        end)
        b.span:SetScript("OnLeave",function(self)self:SetScript("OnUpdate",nil);HideTooltip(self)end)
        b:SetScript("OnClick",function()if current~=page or example~=IsExample()or revision~=renderRevision then return end;local _,reason=Journal(item.rows[b.member],page);RA:Print(reason)end)
    end
    -- Colliding scrub targets cannot unambiguously choose a group. Preserve
    -- their true brackets and use disjoint icon/amount + wheel access instead.
    local function DisableSpan(b)
        b.scrubAvailable=false;b.span:Hide();b.span:SetScript("OnEnter",nil);b.span:SetScript("OnMouseWheel",nil);b.span:SetScript("OnUpdate",nil)
    end
    for i=1,#model.items do
        local a=damagePool[i];local ga=a.group
        if ga.count>1 and ga.last>ga.first then
            local ax=(X(ga.first)+X(ga.last))/2;local aw=math.max(1,X(ga.last)-X(ga.first))
            for j=1,i-1 do
                local b=damagePool[j];local gb=b.group
                if gb.tier==ga.tier and gb.count>1 and gb.last>gb.first then
                    local bx=(X(gb.first)+X(gb.last))/2;local bw=math.max(1,X(gb.last)-X(gb.first))
                    if math.abs(ax-bx)<(aw+bw)/2 then DisableSpan(a);DisableSpan(b)end
                end
            end
        end
    end
    for i=1,#model.items do
        local a=damagePool[i];local ga=a.group
        if not a.scrubAvailable then DisableSpan(a)
        else
            local ax=(X(ga.first)+X(ga.last))/2;local aw=math.max(1,X(ga.last)-X(ga.first));local top,bottom=a.spanY-6,a.spanY+6
            for j=1,#model.items do if i~=j then
                local b=damagePool[j];local bx=b.group.iconX
                local overIcon=math.abs(ax-bx)<(aw+46)/2 and top<b.damageY+46 and bottom>b.damageY
                local overAmount=math.abs(ax-bx)<(aw+b.amountWidth)/2 and top<b.damageY-12 and bottom>b.damageY-34
                if overIcon or overAmount then DisableSpan(a);break end
            end end
        end
    end
    -- Text exclusion rectangles use owned, public layout coordinates only.
    frame.textExclusions={}
    for i=1,#model.items do local b=damagePool[i]
        frame.textExclusions[#frame.textExclusions+1]={left=b.group.iconX-b.amountWidth/2,right=b.group.iconX+b.amountWidth/2,top=b.damageY-34,bottom=b.damageY-12}
    end
    for i=1,6 do if frame.tickLabels[i]~=""then
        local x=X(domain.first+(domain.last-domain.first)*(i-1)/5);local width=frame.ticks[i]:GetStringWidth()
        frame.textExclusions[#frame.textExclusions+1]={left=x-width/2,right=x+width/2,top=rail+10,bottom=rail+23}
    end end
    if frame.death:IsShown()then local x=frame.deathX or 832;local width=frame.death:GetStringWidth();frame.textExclusions[#frame.textExclusions+1]={left=x-width/2,right=x+width/2,top=rail+10,bottom=rail+23}end
    if frame.fight:IsShown()then
        local right=frame.deathX or 832;local width=math.min(170,frame.fight:GetStringWidth());local height=ReadMetric(frame.fight,"GetStringHeight")or 14
        frame.textExclusions[#frame.textExclusions+1]={left=right-width,right=right,top=rail-8-height,bottom=rail-8}
    end
    for i=1,frame.supportMarkerCount do local b=frame.supportMarkers[i];local y=147+shelfExtra+(frame.castExtra or 0)+(b.lane-1)*20
        frame.textExclusions[#frame.textExclusions+1]={left=b.timeX-b.visualWidth/2,right=b.timeX+b.visualWidth/2,top=y-10,bottom=y+10}
    end
    for i=1,#model.items do local b=damagePool[i];b.stems=b.stems or{};Stem(b.stems,(X(b.group.first)+X(b.group.last))/2,rail,b.spanY,pink,.55,frame.textExclusions)end
    RenderCastMarkers(page,shelfExtra,rail,revision)
    RenderSupports(page,example,shelfExtra,rail,revision)
    local choice;for _,row in ipairs(model.rows)do if row==selected then choice=row;break end end
    if not choice then for _,row in ipairs(model.rows)do if row.nativeIndex==(example and page.defaultSelection or 1)then choice=row end end end
    choice=choice or model.rows[1]
    if choice then local item;for _,g in ipairs(model.items)do for _,row in ipairs(g.rows)do if row==choice then item=g end end end;Select(page,choice,item,true)else selected=nil;frame.selected=nil;frame.selectedItem=nil;Health(page,{nativeOffset=0},example);Shelf(page,example,0)end
end
function UI:ShowPage(page)
    if not R:SelectHistoryPage(page)then return false end
    self:Hide();Ensure();current,sample=page,false;self:Render();frame:Show();PositionDemand(true);RA:FireCallback("DEATH_RECAP_VISIBILITY",true,page);return true
end
function UI:ShowLast()
    local page=R:GetPage()or R:GetHistory()[1];if not page then RA:Print("No recorded death available");return false end
    return self:ShowPage(page)
end
function UI:ShowHistory(index)
    if share and share:IsShown()then return false end
    local page=R:GetHistory()[index];if not page then return false end
    return self:ShowPage(page)
end
function UI:Preview()
    self:Hide();Ensure();examplePage=SamplePage();current,sample=examplePage,true;self:Render();frame:Show();PositionDemand(true);RA:FireCallback("DEATH_RECAP_VISIBILITY",true);return true
end
local function HideActionShieldIfUnused()
    if actionShield and not(share and share:IsShown())then actionShield:Hide()end
end
local function ShowActionShield()
    if not actionShield then
        actionShield=CreateFrame("Button",nil,frame);actionShield:SetAllPoints(frame)
        actionShield:SetFrameStrata("DIALOG");actionShield:SetFrameLevel(frame:GetFrameLevel()+18);actionShield:EnableMouse(true)
        local shade=actionShield:CreateTexture(nil,"BACKGROUND");shade:SetAllPoints(actionShield);shade:SetColorTexture(0,0,0,.25)
        actionShield:SetScript("OnClick",function()if share then share:Hide()end;actionShield:Hide()end)
        frame.actionShield=actionShield
    end
    actionShield:SetFrameLevel(frame:GetFrameLevel()+18);actionShield:Show()
end
local Share={}
function Share.Scroll(value,fromSlider)
    value=Metric(value);if not value then return end
    value=math.max(0,math.min(share.scrollMaximum or 0,value));share.scrollPosition=value
    share.reportScroll:SetVerticalScroll(value)
    if not fromSlider then share.scrollbar:SetValue(value)end
end
function Share.Layout()
    local expanded=share.expanded==true
    local count=share.channels.INSTANCE_CHAT:IsShown()and 5 or 4
    local statusY=expanded and 316 or 70+count*42
    local manual=share.jobStatus=="posting"and share.manual
    Size(share,expanded and 600 or 316,expanded and 396 or statusY+96+(manual and 34 or 0))
    if expanded then Place(share,"CENTER",frame,"CENTER",0,0)else Place(share,"TOPRIGHT",frame.share,"BOTTOMRIGHT",0,-8)end
    share.title:SetWidth(expanded and 450 or 230);share.context:SetWidth(expanded and 568 or 284)
    share.choices:SetShown(not expanded);share.reportScroll:SetShown(expanded);share.back:SetShown(expanded)
    Place(share.status,"TOPLEFT",share,"TOPLEFT",16,-statusY);Size(share.status,expanded and 568 or 284,expanded and 30 or 48)
    Place(share.progress,"TOPLEFT",share,"TOPLEFT",16,-(expanded and 346 or statusY+50))
    share.progress:SetWidth((expanded and 568 or 284)*(share.submitted or 0)/math.max(1,share.total or 1))
    share.nextLine:SetShown(manual);share.nextLine:SetEnabled(manual)
    if expanded then
        Place(share.copyButton,"BOTTOMLEFT",share,"BOTTOMLEFT",16,16);Size(share.copyButton,144,28)
        Place(share.back,"BOTTOMLEFT",share,"BOTTOMLEFT",168,16);Size(share.back,88,28)
        Place(share.nextLine,"BOTTOMLEFT",share,"BOTTOMLEFT",264,16);Size(share.nextLine,216,28)
    else
        Place(share.copyButton,"BOTTOMLEFT",share,"BOTTOMLEFT",16,16);Size(share.copyButton,168,28)
        Place(share.nextLine,"BOTTOMLEFT",share,"BOTTOMLEFT",16,50);Size(share.nextLine,284,28)
    end
    Text(share.copyButton.label,expanded and"SELECT TEXT"or"VIEW / COPY")
    Place(share.close,"BOTTOMRIGHT",share,"BOTTOMRIGHT",-16,16);Size(share.close,96,28)
    share.scrollMaximum=math.max(0,share.body:GetHeight()-share.reportScroll:GetHeight())
    share.scrollbar:SetMinMaxValues(0,share.scrollMaximum);share.scrollbar:SetShown(expanded and share.scrollMaximum>0)
    Share.Scroll(share.scrollPosition or 0)
end
function Share.Progress(state)
    if not share then return end
    share.jobStatus,share.submitted,share.total,share.manual=state.status,state.submitted,state.total,state.manual
    Share.targetEvent:SetEnabled(false);Share.groupEvent:SetEnabled(false);share.tip:Hide()
    for _,button in pairs(share.channels)do button:SetEnabled(false);button:SetAlpha(.45)end
    local destination=state.channel=="WHISPER"and state.target or state.channel=="INSTANCE_CHAT"and"Instance"or state.channel:sub(1,1)..state.channel:sub(2):lower()
    local progress=state.submitted.." / "..state.total
    local text=state.status=="complete"and("Submitted "..progress.." to "..destination)
        or state.status=="posting"and("Submitting "..progress.." to "..destination..(state.manual and" · One line per click"or""))
        or("Stopped · "..progress.." submitted"..(state.reason and" · "..state.reason or""))
    Text(share.status,text);Text(share.close.label,state.status=="posting"and"CANCEL"or"CLOSE")
    share.progress:Show();Share.Layout()
end
function Share.Tip(button)
    if not share:IsShown()or share.expanded then return end
    local text=button.detailText or""
    if text==""then return end
    share.tip.text:SetWidth(264);share.tip.text:SetHeight(0);Text(share.tip.text,text)
    local height=math.max(18,ReadMetric(share.tip.text,"GetStringHeight")or 18)
    share.tip.text:SetHeight(height);Size(share.tip,284,height+16)
    Place(share.tip,"BOTTOMRIGHT",button,"TOPRIGHT",0,4);share.tip:Show()
end
function Share.RefreshDestinations(refreshTarget)
    if not share or share.jobStatus then return end
    if refreshTarget then
        share.target,share.targetReason=R:ResolveShareTarget();share.targetRevision=(share.targetRevision or 0)+1
    end
    local generation,targetRevision=share.generation,share.targetRevision
    local snapshot=share.target
    for _,channel in ipairs({"WHISPER","SAY","PARTY","RAID","INSTANCE_CHAT"})do
        local button=share.channels[channel]
        local destination,reason=R:GetShareDestination(channel,channel=="WHISPER"and snapshot or nil)
        local visible=channel~="INSTANCE_CHAT"or destination~=nil
        button:SetShown(visible)
        button:SetEnabled(destination~=nil and share.messageError==nil);button:SetAlpha(button:IsEnabled()and 1 or .45)
        local detail=channel=="WHISPER"and(snapshot and snapshot.name or share.targetReason or"Target a player")
            or channel=="SAY"and"One line per click"or destination and"Full report"or reason
        button.detailText=channel=="WHISPER"and snapshot and(snapshot.name..((share.messageError or reason)and("\n"..(share.messageError or reason))or""))or share.messageError or(destination and detail or reason or detail)
        Text(button.detail,detail or"")
        button:SetScript("OnMouseDown",function(self)
            if not self:IsEnabled()then return end
            self.press={generation=generation,targetRevision=targetRevision};T:SetRoundedColor(self,C.surfacePressed,"base")
        end)
        button:SetScript("OnClick",function(self)
            if not share:IsShown()or share.generation~=generation or share.jobStatus or not self:IsEnabled()then return end
            local press=self.press;self.press=nil;share.tip:Hide()
            if(channel=="WHISPER"and targetRevision~=share.targetRevision)or(press and(press.generation~=generation or(channel=="WHISPER"and press.targetRevision~=share.targetRevision)))then
                Share.RefreshDestinations(true);Text(share.status,"Target changed · Nothing submitted");return
            end
            if not ActionPage(share.page,share.preview)then Text(share.status,"Report changed · Nothing submitted");return end
            local destination,reason=R:GetShareDestination(channel,channel=="WHISPER"and snapshot or nil)
            if not destination then
                Share.RefreshDestinations(channel=="WHISPER");Text(share.status,(reason or"Unavailable").." · Nothing submitted");return
            end
            local report,page,preview=share.report,share.page,share.preview
            local ok,message=R:StartShare(channel,channel=="WHISPER"and snapshot or nil,report,function()
                return frame:IsShown()and share:IsShown()and share.generation==generation and share.report==report and ActionPage(page,preview)
            end,function(state)
                if share.generation==generation and share.report==report then Share.Progress(state)end
            end)
            if not ok then Text(share.status,(message or"Unavailable").." · Nothing submitted")end
        end)
    end
    Share.Layout()
end
Share.targetEvent=RA:RegisterOptionalEvent("PLAYER_TARGET_CHANGED",function()
    if share and share:IsShown()and not share.jobStatus then
        local pressed=share.channels.WHISPER.press
        Share.RefreshDestinations(true)
        if pressed then Text(share.status,"Target changed · Nothing submitted")end
    end
end)
Share.groupEvent=RA:RegisterOptionalEvent("GROUP_ROSTER_UPDATE",function()
    if share and share:IsShown()and not share.jobStatus then Share.RefreshDestinations(false)end
end)
function Share.ShowReport(report)
    share.report=report;share.reportRows=share.reportRows or{}
    share.messages,share.messageError=R:BuildShareMessages(report)
    share.payloadText=report.text or table.concat(report.lines or{},"\n")
    local y=8
    for i,line in ipairs(report.lines or{})do
        local text=share.reportRows[i]
        if not text then text=Font(share.body,12,"REGULAR");share.reportRows[i]=text end
        text:SetWidth(524);text:SetHeight(0);text:SetWordWrap(true);text:SetNonSpaceWrap(true);text:SetMaxLines(0)
        Text(text,line);Place(text,"TOPLEFT",share.body,"TOPLEFT",10,-y);text:Show()
        local height=math.max(18,math.ceil(ReadMetric(text,"GetStringHeight")or 18)+2);text:SetHeight(height);y=y+height+2
    end
    for i=#(report.lines or{})+1,#share.reportRows do share.reportRows[i]:Hide()end
    share.body:SetHeight(y+8);share.copy:SetHeight(y+8);share.copy:SetText(share.payloadText);share.copy:ClearFocus();share.copy:Hide()
    share.scrollPosition=0
    Text(share.context,(share.preview and"Preview"or"Captured recap").." · "..#(report.entries or{}).." events"..(share.messages and" · "..#share.messages.." messages"or" · Copy available"))
end
function Share.Create()
    share=CreateFrame("Frame",nil,frame);share:SetFrameStrata("DIALOG");share:SetFrameLevel(frame:GetFrameLevel()+20);share:SetClampedToScreen(true);share:EnableMouse(true)
    Surface(share,{C.surface[1],C.surface[2],C.surface[3],1});frame.shareChooser=share
    share:SetScript("OnHide",function()
        R:CancelShare("Report closed");Share.targetEvent:SetEnabled(false);Share.groupEvent:SetEnabled(false);share.generation=(share.generation or 0)+1
        share.copy:ClearFocus();share.tip:Hide();for _,button in pairs(share.channels)do button.press=nil end
        HideActionShieldIfUnused()
    end)
    share.title=Label(share,"Post Death Log",14,16,-16,230)
    share.context=Label(share,"",11,16,-40,284,C.textSoft)
    local cross=Button(share,"X",24,function()share:Hide()end);Point(cross,"TOPRIGHT",share,"TOPRIGHT",-12,-10)
    share.choices=CreateFrame("Frame",nil,share);Size(share.choices,284,210);Point(share.choices,"TOPLEFT",share,"TOPLEFT",16,-62)
    share.channels={}
    for index,channel in ipairs({"WHISPER","SAY","PARTY","RAID","INSTANCE_CHAT"})do
        local button=Button(share.choices,channel=="INSTANCE_CHAT"and"Instance"or channel:sub(1,1)..channel:sub(2):lower(),284,function()end)
        Size(button,284,36);Place(button,"TOPLEFT",share.choices,"TOPLEFT",0,-(index-1)*42)
        Place(button.label,"TOPLEFT",button,"TOPLEFT",10,-4);button.label:SetJustifyH("LEFT");button.label:SetWidth(264)
        button.detail=Label(button,"",10,10,-20,264,C.textSoft);button.detail:SetWordWrap(false);button.detail:SetMaxLines(1)
        button:SetScript("OnEnter",function(self)Share.Tip(self);if self:IsEnabled()then T:SetRoundedColor(self,C.surfaceHover,"base")end end)
        button:SetScript("OnLeave",function(self)share.tip:Hide();T:SetRoundedColor(self,C.surfaceRaised,"base")end)
        if button.SetMotionScriptsWhileDisabled then button:SetMotionScriptsWhileDisabled(true)end
        share.channels[channel]=button
    end
    share.tip=CreateFrame("Frame",nil,share);share.tip:SetFrameStrata("TOOLTIP");share.tip:SetClampedToScreen(true);Surface(share.tip,C.canvasDeep)
    share.tip.text=Label(share.tip,"",11,10,-8,264,C.textSoft);share.tip.text:SetWordWrap(true);share.tip.text:SetNonSpaceWrap(true);share.tip.text:SetMaxLines(0);share.tip:Hide()
    share.reportScroll=CreateFrame("ScrollFrame",nil,share);Place(share.reportScroll,"TOPLEFT",share,"TOPLEFT",16,-68);Size(share.reportScroll,568,236);share.reportScroll:SetClipsChildren(true);Surface(share.reportScroll,C.surfaceRaised)
    share.body=CreateFrame("Frame",nil,share.reportScroll);Size(share.body,544,236);share.reportScroll:SetScrollChild(share.body)
    share.reportScroll:EnableMouseWheel(true);share.reportScroll:SetScript("OnMouseWheel",function(_,delta)delta=Metric(delta);if delta then Share.Scroll((share.scrollPosition or 0)-delta*36)end end)
    share.scrollbar=CreateFrame("Slider",nil,share);share.scrollbar:SetOrientation("VERTICAL");share.scrollbar:SetValueStep(1);share.scrollbar:SetObeyStepOnDrag(true)
    Place(share.scrollbar,"TOPRIGHT",share.reportScroll,"TOPRIGHT",-3,-4);Size(share.scrollbar,10,228)
    share.scrollbar:SetThumbTexture(T.Assets.White);share.scrollbar:GetThumbTexture():SetVertexColor(unpack(C.textSoft));share.scrollbar:GetThumbTexture():SetSize(8,24)
    share.scrollbar:SetScript("OnValueChanged",function(_,value)Share.Scroll(value,true)end)
    share.copy=CreateFrame("EditBox",nil,share.body);Size(share.copy,544,236);Point(share.copy,"TOPLEFT",share.body,"TOPLEFT",0,0);share.copy:SetAutoFocus(false);share.copy:SetMultiLine(true);share.copy:SetMaxLetters(0);share.copy:SetTextInsets(10,10,8,8);share.copy:SetJustifyV("TOP");Surface(share.copy,C.surfaceRaised)
    RA:ApplyFont(share.copy,12,"REGULAR",false);share.copy:EnableMouse(true);share.copy:SetScript("OnEscapePressed",function()share:Hide()end)
    share.copy:SetScript("OnTextChanged",function(self)if share.payloadText and self:GetText()~=share.payloadText then self:SetText(share.payloadText);self:HighlightText()end end)
    share.copy:SetScript("OnCursorChanged",function(_,_,y,_,height)
        y=Metric(y);height=Metric(height);if not y then return end
        local top,visible=math.max(0,-y),share.reportScroll:GetHeight();local offset=share.scrollPosition or 0
        if top<offset then Share.Scroll(top)elseif top+(height or 18)>offset+visible then Share.Scroll(top+(height or 18)-visible)end
    end)
    share.status=Label(share,"",11,16,-300,284,C.textSoft);share.status:SetWordWrap(true);share.status:SetNonSpaceWrap(true);share.status:SetMaxLines(0)
    share.progress=share:CreateTexture(nil,"ARTWORK");share.progress:SetColorTexture(unpack(C.activeSoft));Size(share.progress,0,2)
    share.copyButton=Button(share,"VIEW / COPY",168,function()
        if not share.report then return end
        share.tip:Hide()
        if not share.expanded then share.expanded=true;Share.Layout()
        else share.copy:Show();share.copy:SetFocus();share.copy:HighlightText()end
    end)
    share.back=Button(share,"BACK",88,function()share.expanded=false;share.copy:ClearFocus();Share.Layout()end)
    share.nextLine=Button(share,"NEXT SAY LINE",216,function()
        if share:IsShown()and share.jobStatus=="posting"and share.manual and ActionPage(share.page,share.preview)then R:SendNextShare(share.report)end
    end)
    share.close=Button(share,"CLOSE",96,function()if share.jobStatus=="posting"then R:CancelShare("Cancelled")else share:Hide()end end)
    share:Hide()
end
function UI:OpenShare()
    StopMotion();HideTooltip()
    if not ActionPage(current,IsExample())then return end
    if share and share:IsShown()then return end
    if not share then Share.Create()end
    local sameSubmitted=share.page==current and share.preview==IsExample()and(share.submitted or 0)>0
    share.generation=(share.generation or 0)+1;share.expanded=false
    if not sameSubmitted then
        R:CancelShare("Report replaced");share.page,share.preview=current,IsExample()
        share.jobStatus=nil;share.submitted=0;share.total=0;share.manual=false;share.progress:Hide()
        local report,reason=R:BuildShareReport(current,share.preview)
        if not report then RA:Print(reason or"Report unavailable");return end
        Share.ShowReport(report);Text(share.close.label,"CLOSE")
        Text(share.status,share.messageError or"Choose a destination to post. Say sends one line per click.")
    end
    local generation,report=share.generation,share.report
    share.nextLine:SetScript("OnClick",function()
        if share:IsShown()and share.generation==generation and share.report==report and share.jobStatus=="posting"and share.manual and ActionPage(share.page,share.preview)then R:SendNextShare(report)end
    end)
    share:SetFrameLevel(frame:GetFrameLevel()+20);share:Show();ShowActionShield()
    if not sameSubmitted then Share.RefreshDestinations(true);Share.targetEvent:SetEnabled(true);Share.groupEvent:SetEnabled(true)else Share.Layout()end
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
    local reset=kit.Button(group,"RESET POSITION",150,30,function()UI:ResetPosition()end);Point(reset,"LEFT",settings,"RIGHT",10,0)
    local character=kit.Button(group,"CHECK CHARACTER",160,30,function()local ok,why=RA.DeathRecapEntry:CheckCharacter();if not ok and why then RA:Print(why)end end);Point(character,"LEFT",reset,"RIGHT",10,0)
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
    elseif kind=="native"and frame and frame:IsShown()and not sample and R:IsRetainedPage(current)then UI:Render()end
end)
RA:RegisterCallback("ACCENT_THEME_CHANGED",function()if frame and frame:IsShown()then UI:Render()end end)

RA:RegisterCallback("PERSONAL_TOOLS_CHANGED",RefreshReminderSwitch)
for _,name in ipairs({"DISPLAY_SIZE_CHANGED","UI_SCALE_CHANGED","PLAYER_REGEN_DISABLED"})do
    positionEvents[#positionEvents+1]=RA:RegisterOptionalEvent(name,function()
        if frame and frame:IsShown()then StopDragging(false);RestorePosition()end
    end)
end
RA:RegisterCallback("PROFILE_RESET",function()UI:Hide();RestorePosition()end)
