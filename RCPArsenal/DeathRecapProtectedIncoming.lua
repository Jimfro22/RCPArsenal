local _,RA=...
local I={LIMITS={rows=256,seconds=8,pages=5}};RA.DeathRecapProtectedIncoming=I
-- Raw amounts live only here. Page tables, models, saved variables and reports
-- receive public metadata, never these values or a reference to their container.
local active,referenceMaximum
local retained,order={},{}
local function Secret(value)
    if type(issecretvalue)~="function"then return nil end
    local ok,result=pcall(issecretvalue,value)
    if ok and(result==true or result==false)then return result end
end
local function Number(value)
    if Secret(value)~=false then return nil end
    if type(value)=="number"and value==value and value>=0 and value<=1e15 then return value end
end
local function Token(value)
    if Secret(value)==false and type(value)=="string"and #value<=32 and value:match("^[%w_]*$")then return value end
end
function I:PrepareReference()
    referenceMaximum=nil
    if type(UnitHealthMax)=="function"then
        local ok,value=pcall(UnitHealthMax,"player");if ok then referenceMaximum=Number(value)end
    end
end
function I:Cancel()active=nil end
function I:Clear()active=nil;retained={};order={};referenceMaximum=nil end
function I:Begin(at)
    active=nil;at=Number(at);if not at then return end
    active={startedAt=at,slots={},count=0,referenceMaximum=referenceMaximum and referenceMaximum>0 and referenceMaximum or 1000000}
end
function I:Capture(at,action,flag,amount,school)
    local o=active;if not o then return end
    at=Number(at);action=Token(action)
    if not at or at<o.startedAt or(action~="WOUND"and action~="HEAL")then return end
    local secret=Secret(amount)
    if secret==nil or(secret==false and not Number(amount))then return end
    o.count=o.count+1;local index=(o.count-1)%self.LIMITS.rows+1
    if o.slots[index]then o.lostAt=o.slots[index].at end
    o.slots[index]={sequence=o.count,at=at,kind=action=="HEAL"and"healing"or"damage",flag=Token(flag),school=Number(school),protected=secret,amount=amount}
end
function I:Freeze(page,at)
    local o=active;active=nil;at=Number(at)
    if not o or not at or at<o.startedAt then return nil end
    local packet={rows={},bySequence={},protected=0,damageCount=0,healingCount=0,diedAt=at,referenceMaximum=o.referenceMaximum,
        partial=o.lostAt~=nil and at-o.lostAt<=self.LIMITS.seconds}
    for sequence=math.max(1,o.count-self.LIMITS.rows+1),o.count do
        local row=o.slots[(sequence-1)%self.LIMITS.rows+1]
        if row and row.at<=at and at-row.at<=self.LIMITS.seconds then
            packet.rows[#packet.rows+1]=row;packet.bySequence[row.sequence]=row
            if row.protected then packet.protected=packet.protected+1 end
            local key=row.kind=="healing"and"healingCount"or"damageCount";packet[key]=packet[key]+1
        end
    end
    -- Public-only deaths keep the existing arithmetic/chart path and persistence.
    if packet.protected==0 then return nil end
    retained[page]=packet;order[#order+1]=page
    while #order>self.LIMITS.pages do retained[table.remove(order,1)]=nil end
    return{retained=#packet.rows,protected=packet.protected,partial=packet.partial}
end
function I:Describe(page)
    local packet=retained[page]
    if not packet then return nil end
    local out={available=true,nativeDisplay=true,rows={},damageCount=packet.damageCount,healingCount=packet.healingCount,
        protected=packet.protected,partial=packet.partial,referenceMaximum=packet.referenceMaximum}
    for _,row in ipairs(packet.rows)do
        out.rows[#out.rows+1]={sequence=row.sequence,offset=row.at-packet.diedAt,kind=row.kind,flag=row.flag,school=row.school}
    end
    return out
end
function I:Prune(pages)
    local keep={};for _,page in ipairs(pages)do keep[page]=true end
    for index=#order,1,-1 do
        if not keep[order[index]]then retained[order[index]]=nil;table.remove(order,index)end
    end
end
function I:Paint(page,sequence,bar,label)
    local packet=retained[page];local row=packet and packet.bySequence[sequence]
    if not row then return false,false end
    local barOK,textOK=true,true
    if bar then
        barOK=pcall(bar.SetMinMaxValues,bar,0,packet.referenceMaximum)
        barOK=barOK and pcall(bar.SetValue,bar,row.amount)or false
        if not barOK then pcall(bar.SetValue,bar,0)end
    end
    if label then
        label.__raNativeText=true;label.__raVisualText=nil
        textOK=pcall(label.SetFormattedText,label,"%d",row.amount)
        if not textOK then label:SetText("(blocked)")end
    end
    return barOK,textOK
end
RA:RegisterCallback("PROFILE_RESET",function()I:Clear()end)
