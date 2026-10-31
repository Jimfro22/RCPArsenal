local _,RA=...
local UI={};RA.DeathRecapUI=UI
local R,T=RA.DeathRecap,RA.Theme
local C=T.Colors
local frame,share,bell,current,sample,examplePage
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
local tooltipOwner,tooltipBuilding,tooltipPlacing,tooltipHooked
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
-- Bounded screen-space placement only; no data, text or bar-value readback.
function UI:TooltipRect(screen,panel,target,band,point,w,h)
    local inset,gap=12,12
    local function Clamp(v,lo,hi)return math.max(lo,math.min(math.max(lo,hi),v))end
    local function Fits(x,y)return x>=inset and y>=inset and x+w<=screen.right-inset and y+h<=screen.top-inset end
    local sideY=Clamp(panel.top-h,inset,screen.top-inset-h)
    local alongX=Clamp(panel.left,inset,screen.right-inset-w)
    local outside={{panel.right+gap,sideY},{panel.left-gap-w,sideY},{alongX,panel.bottom-gap-h},{alongX,panel.top+gap}}
    for _,p in ipairs(outside)do if Fits(p[1],p[2])then return p[1],p[2],"outside"end end
    local candidates={{inset,inset},{screen.right-inset-w,inset},{inset,screen.top-inset-h},{screen.right-inset-w,screen.top-inset-h}}
    local best,score
    for _,p in ipairs(candidates)do
        local x,y=Clamp(p[1],inset,screen.right-inset-w),Clamp(p[2],inset,screen.top-inset-h)
        local candidate={Overlap(x,y,w,h,target,8),Overlap(x,y,w,h,band),Overlap(x,y,w,h,point,4),Overlap(x,y,w,h,panel)}
        local wins=score==nil
        if score then for i=1,4 do if candidate[i]~=score[i]then wins=candidate[i]<score[i];break end end end
        if wins then best,score={x,y},candidate end
    end
    return best[1],best[2],(w>screen.right-24 or h>screen.top-24)and"oversize"or"fallback"
end
local function PositionTooltip()
    if tooltipBuilding or tooltipPlacing or not tooltipOwner or not frame or not frame:IsShown()or not GameTooltip or not GameTooltip:IsShown()then return end
    if GameTooltip.GetOwner and GameTooltip:GetOwner()~=tooltipOwner then return end
    tooltipPlacing=true
    local panel,target=Bounds(frame),Bounds(tooltipOwner);local sw,sh,ss=ReadMetric(UIParent,"GetWidth"),ReadMetric(UIParent,"GetHeight"),ReadMetric(UIParent,"GetEffectiveScale")
    local tw,th,ts=ReadMetric(GameTooltip,"GetWidth"),ReadMetric(GameTooltip,"GetHeight"),ReadMetric(GameTooltip,"GetEffectiveScale")
    if panel and target and sw and sh and ss and ss>0 and tw and th and tw>0 and th>0 and ts and ts>0 and sw>0 and sh>0 then
        local band={left=panel.left,right=panel.right,top=panel.top,bottom=panel.top-(132+(frame.shelfShift or 0))*panel.scale}
        local point=frame.healthPoint and frame.healthPoint:IsShown()and Bounds(frame.healthPoint)or nil
        local x,y,mode=UI:TooltipRect({right=sw*ss,top=sh*ss},panel,target,band,point,tw*ts,th*ts)
        GameTooltip:ClearAllPoints();GameTooltip:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",x/ts,y/ts)
        frame.tooltipPlacement={left=x,bottom=y,right=x+tw*ts,top=y+th*ts,mode=mode}
    else
        GameTooltip:ClearAllPoints();GameTooltip:SetPoint("BOTTOM",frame,"TOP",0,12);frame.tooltipPlacement=nil
    end
    GameTooltip:SetClampedToScreen(true);tooltipPlacing=false
end
local function Tooltip(button,lines,spellID,itemID)
    if not GameTooltip then return end
    tooltipBuilding=true;tooltipOwner=button;GameTooltip:SetOwner(button,"ANCHOR_NONE")
    local function Native(fn,id)
        local called,value=pcall(fn,GameTooltip,id);if not called or type(issecretvalue)~="function"then return false end
        local checked,secret=pcall(issecretvalue,value);return checked and secret==false and value~=false
    end
    local ok=false
    if spellID then ok=Native(GameTooltip.SetSpellByID,spellID)
    elseif itemID and GameTooltip.SetItemByID then ok=Native(GameTooltip.SetItemByID,itemID)end
    if not ok then GameTooltip:SetText(lines[1]or"Details")end
    -- The native tooltip already supplies the spell/item title.
    for i=2,#lines do GameTooltip:AddLine(lines[i],.79,.77,.84,true)end
    GameTooltip:Show();tooltipBuilding=false;PositionTooltip()
    if not tooltipHooked and GameTooltip.HookScript then
        tooltipHooked=true;GameTooltip:HookScript("OnSizeChanged",PositionTooltip)
    end
end
local function HideTooltip(target)
    if target and target~=tooltipOwner then return end
    local owner=tooltipOwner
    tooltipOwner=nil;if frame then frame.tooltipPlacement=nil end
    if owner and GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner()==owner then GameTooltip:Hide()end
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
        if RA.SetVisualTexture then RA:SetVisualTexture(button.icon,texture)else button.icon:SetTexture(texture)end
    end
end
local M=RA.DeathLogModel
local pink,lavender,amber={.91,.63,.72},{.69,.53,.86},{1,.69,.13}
local selected,model,domain,extraHeight,contentShift
local memberChoices,renderRevision={},0
local closing=false
local TIER_GAP=100
local damagePool,supportPool,shelfPool,graphPool={},{},{},{}
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
local function At(time)return string.format("%s%.2fs",time<0 and"−"or"",math.abs(time))end
local function IsExample()return sample==true and current~=nil and current==examplePage end
local function X(time)return 48+(time-domain.first)/(domain.last-domain.first)*784 end
local function SamplePage()
    local page={id=0,diedAt=132,class="MAGE",specID=62,encounter={encounterID=3429,name="The Coiled Altar",difficulty=16,startedAt=0},
        maxHealth=400000,healthPoints={{offset=-5,hp=372000}},transitions={-3.5,-2.2,-1.8,-.5},
        heals={{offset=-4.2,amount=9000,name="Flash Heal",spellID=2061,healer="Example healer",hp=336000},
            {offset=-3.15,amount=11000,name="Renew",spellID=139,healer="Example healer",hp=211000}},
        supports={{spellID=235450,name="Prismatic Barrier",offset=-3.5,finish=-2.2,exampleHP=200000,nativeOffset=-3.5,nativeIndex=201},
            {spellID=342245,auraSpellID=342246,name="Alter Time",offset=-1.8,finish=-.5,exampleHP=128000,nativeOffset=-1.8,nativeIndex=202}},
        defaultSelection=8,native={rows={}},casts={},lastAlive={spells={},supplies={}}}
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
    for i,heal in ipairs(page.heals)do heal.exampleHP=heal.hp;heal.nativeOffset=heal.offset;heal.nativeIndex=100+i;page.healthPoints[#page.healthPoints+1]={offset=heal.offset,hp=heal.hp}end
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
local function Rect(pool,index,parent,x,y,w,h,color,alpha)
    local t=pool[index]or parent:CreateTexture(nil,"ARTWORK");pool[index]=t
    Size(t,math.max(1,w),math.max(1,h));Place(t,"TOPLEFT",parent,"TOPLEFT",x,-y);t:SetColorTexture(color[1],color[2],color[3],alpha or 1);t:Show();return t
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
        for i=math.floor((range[1]-first)/8),math.ceil((range[2]-first)/8)do
            local a,b=math.max(range[1],first+i*8),math.min(range[2],first+i*8+4)
            if b>a and n<96 then n=n+1;Rect(frame.guide.dashes,n,frame.guide,0,a-first,1,b-a,pink,.85)end
        end
    end
end
local function DamageBadges(b)
    if b.countBadge then return end
    b.countBadge=CreateFrame("Frame",nil,b);Size(b.countBadge,24,16);Place(b.countBadge,"BOTTOMRIGHT",b,"BOTTOMRIGHT",-2,2)
    Surface(b.countBadge,{.035,.027,.055,.96});b.countText=Font(b.countBadge,11,"BOLD");Place(b.countText,"CENTER",b.countBadge,"CENTER",0,0)
    b.absorbBadge=CreateFrame("Frame",nil,b);Size(b.absorbBadge,18,18);Place(b.absorbBadge,"TOPRIGHT",b,"TOPRIGHT",-2,-2);Surface(b.absorbBadge,{.035,.027,.055,.96})
    b.absorbBadge.lines={}
    if type(b.absorbBadge.CreateLine)=="function"then
        local points={{4,3},{14,3},{14,8},{9,14},{4,8},{4,3}}
        for i=1,5 do local line=b.absorbBadge:CreateLine(nil,"OVERLAY");line:SetThickness(1.25);line:SetColorTexture(.92,.88,.97,1)
            line:SetStartPoint("TOPLEFT",b.absorbBadge,points[i][1],-points[i][2]);line:SetEndPoint("TOPLEFT",b.absorbBadge,points[i+1][1],-points[i+1][2]);b.absorbBadge.lines[i]=line
        end
    else
        Size(b.absorbBadge,26,16);b.absorbBadge.label=Font(b.absorbBadge,11,"BOLD");Place(b.absorbBadge.label,"CENTER",b.absorbBadge,"CENTER",0,0);Text(b.absorbBadge.label,"ABS")
    end
    b.selectedBorder=CreateFrame("Frame",nil,b);Size(b.selectedBorder,50,50);Place(b.selectedBorder,"CENTER",b,"CENTER",0,0)
    b.selectedBorder.edges={}
    Rect(b.selectedBorder.edges,1,b.selectedBorder,0,0,50,1,pink);Rect(b.selectedBorder.edges,2,b.selectedBorder,0,49,50,1,pink)
    Rect(b.selectedBorder.edges,3,b.selectedBorder,0,0,1,50,pink);Rect(b.selectedBorder.edges,4,b.selectedBorder,49,0,1,50,pink);b.selectedBorder:Hide()
end
local function AbsorbCue(b,row)
    local value=Number(row.absorbed);b.absorbBadge.recordedAmount=value;b.absorbBadge:SetShown(value~=nil and value>0)
end
local function Hatch(width)
    local n=0
    for base=-14,width,8 do
        local first,last=math.max(0,base),math.min(width,base+14)
        if last>first then
            n=n+1;local line=frame.hatches[n]
            if line then line:SetStartPoint("TOPLEFT",frame.absorb,first,-(14-(first-base)));line:SetEndPoint("TOPLEFT",frame.absorb,last,-(14-(last-base)));line:Show()end
        end
    end
    for i=n+1,#frame.hatches do frame.hatches[i]:Hide()end
    Size(frame.absorbEdge,1,14);Place(frame.absorbEdge,"TOPRIGHT",frame.absorb,"TOPRIGHT",0,0)
end
local function StopMotion()
    for _,b in ipairs(damagePool)do if b.span then b.span:SetScript("OnUpdate",nil)end end
end
function UI:Hide()
    if closing then return end;closing=true
    StopMotion();HideTooltip();if share then share.copy:ClearFocus();share.recipient:ClearFocus();share:Hide()end;if bell then bell:Hide()end
    if frame then
        frame:Hide();frame.selected,frame.selectedItem=nil,nil;frame.healthPanel:SetScript("OnEnter",nil)
        for _,b in ipairs(damagePool)do b.group=nil;b:SetScript("OnEnter",nil);b:SetScript("OnClick",nil);b:SetScript("OnMouseWheel",nil)
            if b.span then b.span:SetScript("OnEnter",nil);b.span:SetScript("OnMouseWheel",nil)end
            if b.amountTarget then b.amountTarget:SetScript("OnEnter",nil);b.amountTarget:SetScript("OnMouseWheel",nil);b.amountTarget:SetScript("OnClick",nil)end
        end
        for _,pool in ipairs({supportPool,shelfPool,frame.healTargets or{}})do for _,b in ipairs(pool)do b:SetScript("OnEnter",nil)end end
    end;sample,current,examplePage=false,nil,nil;selected,model,domain=nil,nil,nil;memberChoices={};renderRevision=renderRevision+1;closing=false
end
local function Ensure()
    if frame then return end
    frame=CreateFrame("Frame","RCPArsenalDeathRecap",UIParent);Size(frame,880,440);Point(frame,"CENTER",UIParent,"CENTER",0,50)
    frame:SetFrameStrata("DIALOG");frame:SetClampedToScreen(true);frame:EnableMouse(true);Surface(frame,C.canvasDeep);T:ApplyRounded(frame,{.48,.34,.52,.65},8,"border","BORDER")
    frame.title=Label(frame,"Death Log",24,20,-18,142);RA:ApplyFont(frame.title,24,"BOLD",false)
    frame.context=Label(frame,"",13,162,-26,462,C.textSoft)
    frame.coverage=Label(frame,"Preview",11,510,-25,108,pink)
    frame.close=CreateFrame("Button",nil,frame);Size(frame.close,28,28);Point(frame.close,"TOPLEFT",frame,"TOPLEFT",832,-18)
    frame.close.label=Label(frame.close,"×",24,1,-1,26);frame.close:SetScript("OnClick",function()UI:Hide()end)
    frame.bell=CreateFrame("Button",nil,frame);Size(frame.bell,24,28);Point(frame.bell,"TOPLEFT",frame,"TOPLEFT",636,-18)
    frame.bell.label=Label(frame.bell,"!",24,6,0,20);RA:ApplyFont(frame.bell.label,24,"BOLD",false);frame.bell:SetScript("OnClick",function()UI:OpenBell()end)
    frame.share=CreateFrame("Button",nil,frame);Size(frame.share,136,28);Point(frame.share,"TOPLEFT",frame,"TOPLEFT",674,-19)
    frame.share.icon=frame.share:CreateTexture(nil,"ARTWORK");Size(frame.share.icon,22,22);Point(frame.share.icon,"LEFT",frame.share,"LEFT",0,0)
    RA:RegisterVisualTexture(frame.share.icon,T.Assets.NavActions,T.Assets.White);frame.share.label=Label(frame.share,"Post to chat",12,28,-7,108)
    frame.share:SetScript("OnClick",function()UI:OpenShare()end)
    for _,b in ipairs({frame.bell,frame.share})do
        if b.SetMotionScriptsWhileDisabled then b:SetMotionScriptsWhileDisabled(true)end
        b:SetScript("OnEnter",function(self)Tooltip(self,{self==frame.bell and"Consumable reminder"or"Post to chat",IsExample()and"Unavailable in Preview"or self==frame.bell and"Open the consumable reminder options"or"Prepare a summary in the chat editor"})end)
        b:SetScript("OnLeave",HideTooltip)
    end
    frame.info=CreateFrame("Button",nil,frame);Size(frame.info,16,20);Point(frame.info,"TOPLEFT",frame,"TOPLEFT",610,-23)
    frame.info.label=Label(frame.info,"i",12,4,0,12,C.textSoft)
    frame.info:SetScript("OnEnter",function(self)Tooltip(self,{"Recorded details",current and current.native and current.native.truncated and"The native record exceeded the64-row capture limit; capture is partial."or"Captured event coverage may be incomplete.","Only captured facts are shown. Native event and local cooldown clocks cannot yet be aligned.","Healing and effect durations are not reconstructed. Heal-absorb history may be unavailable."})end);frame.info:SetScript("OnLeave",HideTooltip)
    frame.health=Label(frame,"Health",12,20,-76,125,C.textSoft);frame.percent=Label(frame,"—",20,137,-71,56,pink);RA:ApplyFont(frame.percent,20,"BOLD",false)
    frame.healthPanel=CreateFrame("Button",nil,frame);Size(frame.healthPanel,292,18);Point(frame.healthPanel,"TOPLEFT",frame,"TOPLEFT",194,-76)
    frame.healthTrack=frame.healthPanel:CreateTexture(nil,"BACKGROUND");frame.healthTrack:SetAllPoints(frame.healthPanel);frame.healthTrack:SetColorTexture(unpack(C.surfaceRaised))
    frame.healthBar=CreateFrame("StatusBar",nil,frame.healthPanel);Size(frame.healthBar,292,14);Point(frame.healthBar,"TOPLEFT",frame.healthPanel,"TOPLEFT",0,-2)
    frame.healthBar:SetStatusBarTexture(T.Assets.White);frame.healthBar:SetStatusBarColor(unpack(pink))
    frame.hp=Label(frame,"",11,194,-100,142,C.muted)
    frame.absorb=CreateFrame("Frame",nil,frame.healthPanel);frame.absorb:SetFrameLevel(frame.healthBar:GetFrameLevel()+2);frame.absorb:SetClipsChildren(true);frame.absorb:Hide();frame.hatches={}
    frame.absorbFill=frame.absorb:CreateTexture(nil,"BACKGROUND");frame.absorbFill:SetAllPoints(frame.absorb);frame.absorbFill:SetColorTexture(amber[1],amber[2],amber[3],.12)
    if type(frame.absorb.CreateLine)=="function"then
        for i=1,40 do local line=frame.absorb:CreateLine(nil,"OVERLAY");line:SetThickness(2);line:SetColorTexture(amber[1],amber[2],amber[3],.95);frame.hatches[i]=line end
    else
        frame.absorbNative=frame.absorb:CreateTexture(nil,"OVERLAY");frame.absorbNative:SetAllPoints(frame.absorb);frame.absorbNative:SetAtlas("RaidFrame-Absorb-Overlay");frame.absorbNative:SetVertexColor(unpack(amber))
    end
    frame.absorbEdge=frame.absorb:CreateTexture(nil,"OVERLAY");frame.absorbEdge:SetColorTexture(amber[1],amber[2],amber[3],1)
    frame.absorbLabel=Label(frame,"",11,348,-100,138,amber);frame.absorbLabel:SetJustifyH("RIGHT")
    frame.shelf=Label(frame,"Cooldowns",12,510,-76,152,C.textSoft)
    frame.shelfAge=Label(frame,"",11,510,-97,152,C.muted)
    frame.rail=frame:CreateTexture(nil,"ARTWORK");frame.rail:SetColorTexture(.58,.53,.65,.70)
    frame.ticks={};frame.tickLabels={};frame.tickMarks={};for i=1,6 do frame.ticks[i]=Font(frame,11,nil,C.textSoft);frame.tickMarks[i]=frame:CreateTexture(nil,"ARTWORK");frame.tickMarks[i]:SetColorTexture(unpack(C.lineStrong))end
    frame.fight=Label(frame,"",11,690,-177,170,C.textSoft)
    frame.death=Font(frame,11,"BOLD",pink);frame.death:Hide()
    frame.graphLabel=Label(frame,"HP",11,20,-333,40,C.muted)
    frame.graphBase=frame:CreateTexture(nil,"ARTWORK");frame.graphBase:SetColorTexture(unpack(C.lineStrong))
    frame.guide=CreateFrame("Frame",nil,frame);frame.guide.dashes={};for i=1,96 do local t=frame.guide:CreateTexture(nil,"ARTWORK");frame.guide.dashes[i]=t;t:Hide()end;frame.guide:Hide()
    frame.interval=frame:CreateTexture(nil,"BACKGROUND");frame.interval:SetColorTexture(pink[1],pink[2],pink[3],.04);frame.interval:Hide()
    frame.healthPoint=CreateFrame("Frame",nil,frame);Size(frame.healthPoint,12,12);frame.healthPoint:SetFrameLevel(frame:GetFrameLevel()+3)
    local disc=T.MediaPath.."RadialHub"
    frame.healthPoint.discs={}
    for i,size in ipairs({12,8,4})do local t=frame.healthPoint:CreateTexture(nil,"OVERLAY",nil,i);Size(t,size,size);Point(t,"CENTER",frame.healthPoint,"CENTER",0,0);RA:RegisterVisualTexture(t,disc,T.Assets.White);t:SetVertexColor(unpack(i==2 and C.canvasDeep or pink));frame.healthPoint.discs[i]=t end
    frame.pointPercent=Font(frame.healthPoint,12,"BOLD",pink);frame.healthPoint:Hide()
    frame.tombstone=frame:CreateTexture(nil,"ARTWORK");Size(frame.tombstone,22,26);frame.tombstone:SetAtlas("deathrecap-icon-tombstone");frame.tombstone:Hide()
    frame.empty=Label(frame,"No hit details recorded",12,48,-270,784,C.muted)
    if type(UISpecialFrames)=="table"then table.insert(UISpecialFrames,"RCPArsenalDeathRecap")end
    frame:SetScript("OnHide",function()if not closing then UI:Hide()end end)
    frame:Hide()
end
local function Roster(page,example,time)
    if example then
        return {{spellID=342245,name="Alter Time",category="minor",cooldown=time>=-1.8 and"active"or"inactive",chargeQuery="not_applicable",exact=true},
            {spellID=45438,name="Ice Block",category="major",cooldown="active",chargeQuery="not_applicable",exact=true},
            {spellID=235450,name="Prismatic Barrier",category="minor",cooldown=time>=-3.5 and"active"or"inactive",chargeQuery="not_applicable",exact=true},
            {kind="stone",itemID=5512,name="Healthstone",cooldown="inactive",physicalCount=1,remainingUses=1,exact=true},
            {kind="potion",itemID=241304,name="Healing potion",physicalCount=0,cooldown="unknown",exact=true}}
    end
    local rows={};local sample=page.lastAlive
    for _,row in ipairs(sample and sample.spells or page.knownEntries or{})do rows[#rows+1]=row end
    for _,row in ipairs(sample and sample.supplies or{})do rows[#rows+1]=row end
    return rows
end
local function State(row,example)
    local suffix=example and" at this moment"or" when checked"
    if row.pendingAt then return nil,"A later change was awaiting a new check"end
    if not example and current.lastAlive and current.lastAlive.coverageEndedAt then return nil,"Recording ended after this check"end
    if row.kind then
        if row.physicalCount==0 and row.remainingUses and row.remainingUses>0 then return nil,"The independent stock checks disagree"end
        if row.familyAbsenceVerified or row.physicalCount==0 then return false,(row.itemID and"No stock of this item"or"No item in the complete bag check")..suffix end
        if row.physicalCount and row.physicalCount>0 and row.remainingUses==0 then return false,"Empty"..suffix end
        local stock=row.physicalCount and row.physicalCount>0 or row.remainingUses and row.remainingUses>0
        if stock and row.cooldown=="inactive"then return true,"Off cooldown"..suffix end
        if stock and row.cooldown=="active"then return false,"Cooldown active"..suffix end
        return nil,row.cooldown=="inactive"and"Off cooldown when checked; stock was not confirmed"or"Item state was not fully recorded"
    end
    if row.cooldown=="held"then return false,"Cooldown on hold"..suffix end
    if row.currentCharges and row.currentCharges>0 then return true,row.currentCharges..(row.currentCharges==1 and" charge"or" charges")..suffix end
    if row.currentCharges==0 then return false,"No charges"..suffix end
    if row.cooldown=="inactive"then return true,"Off cooldown"..suffix end
    if row.cooldown=="active"and row.chargeQuery=="not_applicable"then return false,"Cooldown active"..suffix end
    if row.cooldown=="gcd-only"then return nil,"A global cooldown was observed; other cooldown state was not established"end
    if row.chargeReason=="restricted"or row.chargeCountStatus=="restricted"then return nil,"Charge count was not provided by Blizzard"end
    if row.cooldownQuery=="restricted"or row.cooldownEnabledStatus=="restricted"or row.cooldownActiveStatus=="restricted"then return nil,"Cooldown state was not provided by Blizzard"end
    return nil,row.cooldown=="active"and"Cooldown active when checked; charge count was not recorded"or row.cooldownQuery and"State check unavailable"or"Not recorded"
end
local function Shelf(page,example,time)
    Text(frame.shelf,example and"Cooldowns · "..At(time)or"Last recorded check")
    Text(frame.shelfAge,"")
    local rows=Roster(page,example,time);local signature={}
    if not example then
        local youngest,oldest
        for _,row in ipairs(rows)do if row.observedAt and page.diedAt>=row.observedAt then local age=page.diedAt-row.observedAt;youngest=math.min(youngest or age,age);oldest=math.max(oldest or age,age)end end
        Text(frame.shelfAge,youngest and(youngest==oldest and string.format("%.1fs before notice",youngest)or string.format("%.1f–%.1fs before notice",youngest,oldest))or"Not recorded")
    end
    for _,row in ipairs(rows)do local state=State(row,example);signature[#signature+1]=tostring(row.spellID or row.itemID or row.kind)..":"..tostring(state)end
    local key=table.concat(signature,";")
    if frame.shelfKey==key then return end;frame.shelfKey=key;HidePool(shelfPool)
    table.sort(rows,function(a,b)
        local function Rank(row)local state=State(row,example);return(row.kind and 10 or 0)+(state==true and 0 or state==nil and 3 or 6)+(row.category=="major"and 0 or 1)end
        local ar,br=Rank(a),Rank(b);if ar==br then return(a.spellID or a.itemID or 0)<(b.spellID or b.itemID or 0)end;return ar<br
    end)
    for i,row in ipairs(rows)do
        local b=shelfPool[i]or Icon(frame,32);shelfPool[i]=b
        local col,line=(i-1)%5,math.floor((i-1)/5);local x=663+col*37+(row.kind and 10 or 0)
        Place(b,"TOPLEFT",frame,"TOPLEFT",x,-66-line*38);Artwork(b,row);Text(b.badge,"");b:Show()
        local state,detail=State(row,example);local shade=state==false and .4 or 1;b.icon:SetVertexColor(shade,shade,shade);b.icon:SetAlpha(1)
        b.info=b.info or Font(b,11,"BOLD",C.textSoft);Place(b.info,"BOTTOMRIGHT",b,"BOTTOMRIGHT",2,-2);Text(b.info,(state==nil or not example)and"i"or"")
        b:SetScript("OnEnter",function(self)
            if current~=page or example~=IsExample()then return end
            local lines={row.name or(row.kind=="stone"and"Healthstone"or row.kind=="potion"and"Healing potion"or"Defensive"),detail}
            if example then lines[#lines+1]="Recorded cooldown and stock only"
            else
                lines[#lines+1]="This is a separate recorded check, not a snapshot at the selected hit. A cooldown check is not a survival verdict."
                if row.carriedAt then lines[#lines+1]=string.format("Bag scan: %.2fs before the death notice.",page.diedAt-row.carriedAt)end
                if row.pendingAt then lines[#lines+1]="A later cast or update may have changed this check."end
                if row.chargeReason=="restricted"or row.chargeCountStatus=="restricted"then lines[#lines+1]="Charge count was not provided by Blizzard."end
                if row.observedAt then lines[#lines+1]=string.format("Separate check: %.2fs before the death notice.",page.diedAt-row.observedAt)end
                if row.cooldown and row.cooldown~="unknown"then lines[#lines+1]="Last checked: "..(row.cooldown=="inactive"and"off cooldown"or row.cooldown=="held"and"cooldown on hold"or"cooldown active")end
                if row.currentCharges~=nil then lines[#lines+1]="Charges in that check: "..row.currentCharges end
                if row.countStatus=="restricted"then lines[#lines+1]="Stock was not provided by Blizzard."end
                if row.usesStatus=="restricted"then lines[#lines+1]="Remaining uses were not provided by Blizzard."end
                if row.physicalCount~=nil then lines[#lines+1]="Stock in that check: "..row.physicalCount end
                if row.remainingUses~=nil then lines[#lines+1]="Uses in that check: "..row.remainingUses end
            end
            Tooltip(self,lines,row.spellID,row.itemID)
        end)
    end
end
local function Health(page,row,example)
    frame.healthBar:Hide();frame.healthPoint:Hide();frame.absorb:Hide();frame.absorbLabel:Hide();Text(frame.hp,"");Text(frame.percent,"—")
    local max=example and page.maxHealth or page.native and Number(page.native.recapID,true)and Number(page.native.recapMaxHealth,true)
    local allowed=example or page.native and Number(page.native.recapID,true)
    local hp=allowed and Number(example and row.exampleHP or row.recordedHP)or nil
    frame.healthPanel.selectedHP,frame.healthPanel.selectedMax=hp,max
    if hp~=nil then
        Text(frame.hp,Raw(hp)..(max and" / "..Raw(max)or""))
        if max and hp<=max then
            frame.healthBar:SetMinMaxValues(0,max);frame.healthBar:SetValue(hp);frame.healthBar:Show();Text(frame.percent,string.format("%.0f%%",hp/max*100))
            Place(frame.healthPoint,"CENTER",frame,"TOPLEFT",X(row.nativeOffset),-350-extraHeight-(1-hp/max)*60);frame.healthPoint:Show()
            local pointX=X(row.nativeOffset);Text(frame.pointPercent,string.format("%.0f%%",hp/max*100))
            local left=pointX+10+frame.pointPercent:GetStringWidth()>860
            Place(frame.pointPercent,left and"RIGHT"or"LEFT",frame.healthPoint,"CENTER",left and-10 or 10,10)
        end
    end
    local debt=example and row.nativeOffset>=-2.7 and row.nativeOffset< -1.5 and 80000 or nil
    frame.healthPanel.healAbsorb=debt
    if debt and max and hp and hp<=max then
        local width=math.min(292,debt/max*292);local start=math.max(0,(hp-debt)/max*292)
        Size(frame.absorb,math.min(width,292-start),14);Place(frame.absorb,"TOPLEFT",frame.healthPanel,"TOPLEFT",start,-2);frame.absorb:Show()
        Hatch(math.min(width,292-start));Text(frame.absorbLabel,Amount(debt).." heal absorb");frame.absorbLabel:Show()
    end
    frame.healthPanel:SetScript("OnEnter",function(self)
        local lines={"Recorded health",hp~=nil and"Health reported with this event: "..Raw(hp)or"Health was not recorded for this event."}
        if max then lines[#lines+1]="Scaled to the max health supplied with this recap: "..Raw(max)..". This is one recap reference."
        else lines[#lines+1]=not example and page.native and page.native.recapMaxHealthStatus=="restricted"and"The recap maximum was not provided by Blizzard."or"A usable recap maximum was not recorded."end
        if not example and row.fieldStatus and row.fieldStatus.hp=="restricted"then lines[#lines+1]="Health was not provided by Blizzard for this event."end
        if not example then lines[#lines+1]="Before/after-hit timing is unspecified."end
        if hp and max and hp>max then lines[#lines+1]="Outside the recap scale; no bar is drawn."end
        if debt then lines[#lines+1]="Healing debt: "..debt..". Healing needed to clear the absorb; not extra HP or a protective shield."end
        Tooltip(self,lines)
    end);frame.healthPanel:SetScript("OnLeave",HideTooltip)
end
local function Select(page,row,item,force)
    if page~=current or not row then return end
    if not force and selected==row and frame.selectedItem==item then return end
    selected=row;frame.selected=row;frame.selectedItem=item;Text(frame.health,"Health · "..At(row.nativeOffset));Health(page,row,IsExample());Shelf(page,IsExample(),row.nativeOffset)
    Place(frame.guide,"TOPLEFT",frame,"TOPLEFT",X(row.nativeOffset),-130-(contentShift or 0));Size(frame.guide,1,280+extraHeight-(contentShift or 0));Guide(X(row.nativeOffset),130+(contentShift or 0),410+extraHeight);frame.guide:Show()
    for _,b in ipairs(damagePool)do if b.selectedBorder then b.selectedBorder:SetShown(b:IsShown()and b.group==item)end end
    if item then Place(frame.interval,"TOPLEFT",frame,"TOPLEFT",X(item.first),-130-(contentShift or 0));Size(frame.interval,math.max(1,X(item.last)-X(item.first)),280+extraHeight-(contentShift or 0));frame.interval:Show()else frame.interval:Hide()end
end
local function SelectedTooltip(b,page,target)
    local item=b.group;local row=item.rows[b.member or 1];local lines={item.mixed and"Mixed events"or row.name or"Recorded event"}
    local amount=row.amount~=nil and Amount(row.amount)or"Amount unavailable"
    if #item.rows==1 then
        lines[#lines+1]=amount..(row.amount~=nil and(row.kind=="damage"and" damage"or" recorded")or"").." · "..At(row.nativeOffset)
    else
        local total=item.amountComplete and Amount(item.amount)or(item.amount>0 and"≥"..Amount(item.amount)or"Amount unavailable")
        local noun="hits";for _,member in ipairs(item.rows)do if member.kind~="damage"then noun="events";break end end
        lines[#lines+1]=total.." total · "..#item.rows.." "..noun.." · "..At(item.first).."…"..At(item.last)
        lines[#lines+1]="Selected "..b.member.."/"..#item.rows.." · "..amount.." · "..At(row.nativeOffset)
    end
    if row.sourceName and row.hideCaster~=true and row.hideCasterStatus~="restricted"then lines[#lines+1]="Source: "..row.sourceName end
    if row.nativeIndex==1 then lines[#lines+1]="Killing blow"end
    local mitigation={}
    for _,field in ipairs({{"absorbed","Absorbed"},{"overkill","Overkill"},{"resisted","Resisted"},{"blocked","Blocked"}})do
        local value=Number(row[field[1]]);if value and value>0 then mitigation[#mitigation+1]=field[2].." "..Amount(value)end
    end
    if #mitigation>0 then lines[#lines+1]=table.concat(mitigation," · ")end
    if #item.rows>1 then
        for i=math.max(1,b.member-2),math.min(#item.rows,b.member+3)do
            local member=item.rows[i];lines[#lines+1]=(i==b.member and"› "or"  ")..i.." · "..At(member.nativeOffset).." · "..(item.mixed and(member.name or"Event").." · "or"")..(member.amount~=nil and Amount(member.amount)or"Amount unavailable")
        end
        lines[#lines+1]=item.last>item.first and b.scrubAvailable and"Move across the span or scroll to inspect events"or"Scroll to inspect events"
    end
    local mapping
    if not item.mixed then if IsExample()then mapping=previewJournal[row.spellID]else mapping=R:GetJournalMapping(page,row)end end
    if mapping then lines[#lines+1]="Click: Journal (after combat)"end
    Tooltip(target or b,lines,not item.mixed and row.spellID or nil)
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
local function DrawGraph(page,example)
    HidePool(graphPool);local points={};local max=example and page.maxHealth or page.native and Number(page.native.recapID,true)and Number(page.native.recapMaxHealth,true)
    if example then points=page.healthPoints
    elseif max then for _,row in ipairs(model.rows)do local hp=Number(row.recordedHP);if hp~=nil and hp<=max then points[#points+1]={offset=row.nativeOffset,hp=hp}end end end
    frame.graphLabel:SetShown(#points>0);frame.graphBase:SetShown(#points>0)
    if #points==0 then return end
    local n,previous=0
    for _,point in ipairs(points)do
        local x,y=X(point.offset),350+extraHeight+(1-point.hp/max)*60
        if example and previous then
            n=n+1;Rect(graphPool,n,frame,previous.x,previous.y,math.max(1,x-previous.x),1,pink)
            n=n+1;Rect(graphPool,n,frame,x,math.min(previous.y,y),1,math.max(1,math.abs(previous.y-y)),pink)
            n=n+1;Rect(graphPool,n,frame,previous.x,previous.y,math.max(1,x-previous.x),410+extraHeight-previous.y,pink,.08)
        end
        n=n+1;Rect(graphPool,n,frame,x-1,y-1,2,2,pink,.35);previous={x=x,y=y}
    end
end
function UI:Render()
    if not frame or not current then return end
    StopMotion();HideTooltip();renderRevision=renderRevision+1;local revision=renderRevision;local page,example=current,IsExample();frame.shelfKey=nil
    for _,pool in ipairs({damagePool,supportPool,shelfPool})do HidePool(pool)end
    for _,b in ipairs(damagePool)do if b.span then b.span:Hide()end;if b.amountTarget then b.amountTarget:Hide()end;if b.brackets then HidePool(b.brackets)end;if b.stems then HidePool(b.stems)end end
    for _,b in ipairs(supportPool)do if b.lines then HidePool(b.lines)end end
    local rows=page.native and page.native.rows or{}
    model=M:Group(rows,example and page.transitions or{});domain={first=-5,last=0}
    for _,row in ipairs(model.rows)do domain.first=math.min(domain.first,row.nativeOffset);domain.last=math.max(domain.last,row.nativeOffset)end
    if domain.last-domain.first<.1 then domain.first=domain.last-.1 end
    frame.coverage:SetShown(example);frame.info:SetShown(not example)
    Text(frame.context,(page.specID==62 and"Arcane Mage"or page.class or"Personal")..(page.encounter and page.encounter.name and" · "..page.encounter.name or"")..(page.encounter and page.encounter.difficulty==16 and" · Mythic"or""))
    frame.context:SetWidth(example and 344 or 440);frame.share:SetEnabled(not example);frame.share:SetAlpha(example and .72 or 1);frame.bell:SetEnabled(not example);frame.bell:SetAlpha(example and .72 or 1)
    local roster=Roster(page,example,selected and selected.nativeOffset or 0);local shelfExtra=math.max(0,math.ceil(#roster/5)-1)*38;frame.shelfShift=shelfExtra
    local tierEnd={-100,-100};local spanEnd={-math.huge,-math.huge};local secondTier=false
    for _,item in ipairs(model.items)do
        local x=(X(item.first)+X(item.last))/2;local tier
        if item.count>1 and item.last>item.first then
            tier=item.first>spanEnd[1]and 1 or 2;spanEnd[tier]=item.last
        else tier=x-46>tierEnd[1]and 1 or 2 end
        if tier==2 then secondTier=true end
        item.tier=tier;item.iconX=math.max(x,tierEnd[tier]+46);tierEnd[tier]=item.iconX+46
    end
    -- Artwork can pack; true-time spans, connectors and cursors never move.
    for tier=1,2 do local right=832
        for i=#model.items,1,-1 do local item=model.items[i];if item.tier==tier then item.iconX=math.min(item.iconX,right);right=item.iconX-92 end end
    end
    contentShift=shelfExtra;extraHeight=shelfExtra+(secondTier and TIER_GAP or 0);Size(frame,880,440+extraHeight)
    local viewWidth,viewHeight=UIParent:GetWidth(),UIParent:GetHeight()
    if viewWidth and viewHeight and viewWidth>40 and viewHeight>80 then frame:SetScale(math.min(1,(viewWidth-40)/880,(viewHeight-80)/(440+extraHeight)))end
    local rail=202+shelfExtra;Place(frame.rail,"TOPLEFT",frame,"TOPLEFT",48,-rail);Size(frame.rail,784,1)
    for i=1,6 do local time=domain.first+(domain.last-domain.first)*(i-1)/5;local x=X(time)
        Place(frame.ticks[i],"TOP",frame,"TOPLEFT",x,-rail-10);frame.tickLabels[i]=string.format("%s%.0fs",time<0 and"−"or"",math.abs(time));Text(frame.ticks[i],frame.tickLabels[i])
        Place(frame.tickMarks[i],"TOPLEFT",frame,"TOPLEFT",x,-rail+4);Size(frame.tickMarks[i],1,8)
    end
    local elapsed=page.encounter and page.encounter.startedAt and page.diedAt-page.encounter.startedAt
    Text(frame.fight,elapsed and string.format(example and"Fight %d:%02d"or"Fight %d:%02d · death notice",math.floor(elapsed/60),math.floor(elapsed%60))or"")
    Place(frame.fight,"TOPRIGHT",frame,"TOPRIGHT",-20,-rail+25)
    frame.death:Hide()
    for _,row in ipairs(model.rows)do if row.nativeIndex==1 then
        local x=X(row.nativeOffset);frame.deathX=x;Place(frame.death,"TOP",frame,"TOPLEFT",x,-rail-10);Text(frame.death,"Death");frame.death:Show()
        for i=1,6 do local time=domain.first+(domain.last-domain.first)*(i-1)/5;if math.abs(X(time)-x)<32 then Text(frame.ticks[i],"");frame.tickLabels[i]=""end end
    end end
    Place(frame.graphLabel,"TOPLEFT",frame,"TOPLEFT",20,-333-extraHeight);Place(frame.graphBase,"TOPLEFT",frame,"TOPLEFT",48,-410-extraHeight);Size(frame.graphBase,784,1)
    frame.guide:Hide();frame.interval:Hide();frame.tombstone:Hide();frame.empty:SetShown(#rows==0)
    for index,item in ipairs(model.items)do
        local b=damagePool[index]or Icon(frame,46);damagePool[index]=b;b.group=item
        local keys={};for _,row in ipairs(item.rows)do keys[#keys+1]=row.nativeIndex end;local groupKey=table.concat(keys,":")
        b.member=Nearest(item,(item.first+item.last)/2,selected)
        for i,row in ipairs(item.rows)do if row.nativeIndex==memberChoices[groupKey]then b.member=i end end
        for i,row in ipairs(item.rows)do if row==selected then b.member=i end end
        local y=rail+52+(item.tier-1)*TIER_GAP;Place(b,"TOP",frame,"TOPLEFT",item.iconX,-y);b:Show()
        DamageBadges(b);Text(b.badge,"")
        if item.mixed then b.icon:Hide()else b.icon:Show();Artwork(b,item.rows[b.member])end
        Text(b.countText,"×"..#item.rows);Size(b.countBadge,math.max(24,b.countText:GetStringWidth()+8),16);b.countBadge:SetShown(#item.rows>1)
        AbsorbCue(b,item.rows[b.member])
        b.mixedLabel=b.mixedLabel or Font(b,11,"BOLD",pink);Place(b.mixedLabel,"CENTER",b,"CENTER",0,0);Text(b.mixedLabel,item.mixed and"Mixed"or"")
        b.amount=b.amount or Font(b,15,"BOLD",pink);Place(b.amount,"BOTTOM",b,"TOP",0,14)
        Text(b.amount,item.amountComplete and Amount(item.amount)or(item.amount>0 and"≥"..Amount(item.amount)or"—"))
        b.brackets=b.brackets or{}
        local first,last=X(item.first),X(item.last);local spanY=y-6
        Rect(b.brackets,1,frame,first,spanY,math.max(1,last-first),1,pink)
        Rect(b.brackets,2,frame,first,spanY-3,1,7,pink);Rect(b.brackets,3,frame,last,spanY-3,1,7,pink)
        Rect(b.brackets,4,frame,math.min(item.iconX,(first+last)/2),spanY,math.abs(item.iconX-(first+last)/2),1,pink,.5)
        T:SetRoundedColor(b,item.fatal and C.danger or C.lineStrong,"base");b.selectedBorder:Hide()
        b.span=b.span or CreateFrame("Button",nil,frame);Size(b.span,math.max(1,last-first),12);Place(b.span,"CENTER",frame,"TOPLEFT",(first+last)/2,-spanY);b.scrubAvailable=item.count>1 and last>first;b.span:SetShown(b.scrubAvailable)
        local function ChooseMember(i,target)
            if current~=page or example~=IsExample()or revision~=renderRevision then return end
            memberChoices[groupKey]=item.rows[i].nativeIndex;b.member=i;AbsorbCue(b,item.rows[i]);Select(page,item.rows[i],item);SelectedTooltip(b,page,target)
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
        b:SetScript("OnClick",function()if current~=page or example~=IsExample()or revision~=renderRevision or item.mixed then return end;local _,reason=Journal(item.rows[b.member],page);RA:Print(reason)end)
        if item.fatal then Place(frame.tombstone,"CENTER",frame,"TOPLEFT",X(item.first),-410-extraHeight);frame.tombstone:Show()end
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
    for i=1,#model.items do local b=damagePool[i];b.stems=b.stems or{};Stem(b.stems,(X(b.group.first)+X(b.group.last))/2,rail,b.spanY,pink,.55,frame.textExclusions)end
    local support=example and page.supports or page.casts or{}
    local supportCount=math.min(#support,8)
    for i=1,supportCount do local row=support[example and i or #support-supportCount+i];local b=supportPool[i]or Icon(frame,30);supportPool[i]=b
        local x=example and X(math.max(domain.first,row.offset))or 48+(i-1)*36
        Place(b,"TOPLEFT",frame,"TOPLEFT",x-15,-138-shelfExtra);Artwork(b,row);Text(b.badge,example and""or"i");b:Show()
        b.lines=b.lines or{};HidePool(b.lines)
        if example and row.finish then
            Rect(b.lines,1,frame,x,150+shelfExtra,X(row.finish)-x,1,lavender);Rect(b.lines,2,frame,X(row.finish),147+shelfExtra,1,7,lavender)
            Rect(b.lines,3,frame,x,171+shelfExtra,1,rail-2-(171+shelfExtra),lavender,.6)
        end
        b:SetScript("OnEnter",function(self)
            if current~=page or revision~=renderRevision then return end
            if example and IsExample()then Select(page,row,nil)end
            local lines={row.name or"Recorded cast",example and(row.openLeft and"Active before this window"or At(row.offset).."…"..At(row.finish or row.offset))or"Recorded cast; effect duration is not recorded."}
            if not example then lines[#lines+1]="This cast cannot be aligned to the hit timeline."end
            if not example and row.observedAt and page.diedAt>=row.observedAt then lines[#lines+1]=string.format("Recorded %.2fs before the death notice.",page.diedAt-row.observedAt)end
            if not example and #support>supportCount then lines[#lines+1]="Showing the latest "..supportCount.." of "..#support.." recorded casts."end
            Tooltip(self,lines,row.spellID)
        end)
    end
    frame.healTargets=frame.healTargets or{};HidePool(frame.healTargets);frame.healStems=frame.healStems or{};HidePool(frame.healStems)
    if example then for i,heal in ipairs(page.heals)do
        local b=frame.healTargets[i]or CreateFrame("Button",nil,frame);frame.healTargets[i]=b;Size(b,66,20);Place(b,"CENTER",frame,"TOPLEFT",X(heal.offset),-181-shelfExtra)
        b.label=b.label or Font(b,13,"BOLD",C.success);Place(b.label,"CENTER",b,"CENTER",0,0);Text(b.label,"+"..Amount(heal.amount));b:Show()
        Rect(frame.healStems,i,frame,X(heal.offset),194+shelfExtra,1,rail-2-(194+shelfExtra),C.success,.6)
        b:SetScript("OnEnter",function(self)if current==page and IsExample()and revision==renderRevision then Select(page,heal,nil);Tooltip(self,{heal.name,"+"..Amount(heal.amount).." healing · "..At(heal.offset),"Healer: "..heal.healer},heal.spellID)end end);b:SetScript("OnLeave",HideTooltip)
    end end
    DrawGraph(page,example)
    local choice=selected
    if not choice then for _,row in ipairs(model.rows)do if row.nativeIndex==(example and page.defaultSelection or 1)then choice=row end end end
    choice=choice or model.rows[1]
    if choice then local item;for _,g in ipairs(model.items)do for _,row in ipairs(g.rows)do if row==choice then item=g end end end;Select(page,choice,item,true)else Text(frame.health,"Health");Health(page,{nativeOffset=0},example);Shelf(page,example,0)end
end
function UI:ShowLast()
    local page=R:GetPage();if not page then RA:Print("No log recorded this session");return false end
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
