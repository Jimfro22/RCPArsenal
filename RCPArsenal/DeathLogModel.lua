local _,RA=...
local Model={};RA.DeathLogModel=Model
-- Presentation only. Inputs are normalized public recorder facts or the private
-- Example fixture. Raw rows are never rewritten, rounded, removed or deduped.
Model.LIMITS={rows=64,nearby=.6,burst=1.5,items=8,history=256}
local function Time(row)return row.nativeOffset end
local function Sort(a,b)
    if Time(a)==Time(b)then return a.nativeIndex<b.nativeIndex end
    return Time(a)<Time(b)
end
local function Cut(cuts,first,last)
    for _,time in ipairs(cuts or{})do if time>first and time<=last then return true end end
    return false
end
local function Item(rows,mixed)
    local item={rows=rows,first=Time(rows[1]),last=Time(rows[#rows]),amount=0,amountComplete=true,mixed=mixed==true}
    for _,row in ipairs(rows)do
        if row.amount~=nil then item.amount=item.amount+row.amount else item.amountComplete=false end
        if row.nativeIndex==1 then item.fatal=true end
    end
    item.count=#rows
    if not item.mixed then item.spellID=rows[1].spellID;item.name=rows[1].name end
    return item
end
local function SameSource(a,b)
    -- A visible name cannot distinguish two same-named creatures. Only an
    -- independently confirmed stable instance key permits semantic grouping.
    return a.sourceConfirmed==true and b.sourceConfirmed==true and type(a.sourceKey)=="string"
        and a.sourceKey~=""and a.sourceKey==b.sourceKey
end
-- Visual absorption clusters retain every contributing hit. They do not identify
-- a shield/provider or fabricate a single timestamp for an interval.
function Model:GroupAbsorbs(input,position,measure)
    local groups={}
    for i=1,math.min(#input,self.LIMITS.rows)do local row=input[i]
        if row.kind=="damage"and type(row.absorbed)=="number"and row.absorbed>0 then
            groups[#groups+1]={rows={row},amount=row.absorbed,first=Time(row),last=Time(row),kind="absorbed",row=row}
        end
    end
    table.sort(groups,function(a,b)return Sort(a.row,b.row)end)
    for pass=1,self.LIMITS.rows do
        local ends={};local fits=true
        for _,group in ipairs(groups)do
            group.width=math.max(28,measure(group.amount,#group.rows)+8)
            group.x=math.max(48+group.width/2,math.min(832-group.width/2,(position(group.first)+position(group.last))/2))
            local lane=1
            while ends[lane]and group.x-group.width/2<ends[lane]+2 do lane=lane+1 end
            group.lane=lane;ends[lane]=group.x+group.width/2
            if lane>2 then fits=false end
        end
        if fits then return groups end
        local best,gap
        for i=1,#groups-1 do local value=groups[i+1].first-groups[i].last
            if not gap or value<gap then best,gap=i,value end
        end
        if not best then return groups end
        local a,b=groups[best],groups[best+1]
        for _,row in ipairs(b.rows)do a.rows[#a.rows+1]=row end
        a.amount=a.amount+b.amount;a.last=b.last;table.remove(groups,best+1)
    end
    return groups
end
function Model:Group(input,transitions,options)
    options=options or{}
    local rows={};local examined=math.min(#input,256);local fatal,largest
    for i=1,examined do
        local row=input[i]
        if row.nativeIndex==1 then fatal=row end
        if row.nativeIndex~=1 and row.kind=="damage"and row.amount~=nil and(not largest or row.amount>largest.amount)then largest=row end
        if i<=self.LIMITS.rows then rows[#rows+1]=row end
    end
    for _,important in ipairs({fatal or false,largest or false})do
        if important then
            local present=false;for _,row in ipairs(rows)do if row==important then present=true end end
            if not present then for i=#rows,1,-1 do if rows[i]~=fatal and rows[i]~=largest then rows[i]=important;break end end end
        end
    end
    table.sort(rows,Sort)
    local major
    for _,row in ipairs(rows)do
        if row.nativeIndex~=1 and row.kind=="damage"and row.amount~=nil and(not major or row.amount>major.amount)then major=row end
    end
    local groups={};local operations=0
    for _,row in ipairs(rows)do
        local match
        for i=#groups,1,-1 do
            operations=operations+1
            local previous=groups[i];local tail=previous.rows[#previous.rows]
            if row~=major and tail~=major and row.nativeIndex~=1 and not previous.fatal
                and row.kind=="damage"and tail.kind=="damage"and row.spellID~=nil and row.spellID==tail.spellID
                and SameSource(row,tail)and Time(row)-Time(tail)<=(options.nearby or self.LIMITS.nearby)
                and Time(row)-previous.first<=(options.burst or self.LIMITS.burst)
                and not Cut(transitions,Time(tail),Time(row))then match=i;break end
        end
        if match then
            local members={};for _,member in ipairs(groups[match].rows)do members[#members+1]=member end;members[#members+1]=row
            groups[match]=Item(members)
        else groups[#groups+1]=Item({row})end
    end
    table.sort(groups,function(a,b)return a.first==b.first and a.rows[1].nativeIndex<b.rows[1].nativeIndex or a.first<b.first end)
    for _,item in ipairs(groups)do for _,row in ipairs(item.rows)do if row==major then item.major=true end end end
    -- Crowding is an explicit mixed-event interval, never a sum under one
    -- spell's artwork. Fatal and the largest preceding hit remain separate.
    local limit=options.items or self.LIMITS.items
    while #groups>limit do
        local best,distance
        for i=1,#groups-1 do
            operations=operations+1
            local a,b=groups[i],groups[i+1]
            if not a.fatal and not b.fatal and not a.major and not b.major and not Cut(transitions,math.min(a.first,b.first),math.max(a.last,b.last))then
                local gap=b.first-a.last
                if not distance or gap<distance then best,distance=i,gap end
            end
        end
        if not best then break end
        local members={};for _,row in ipairs(groups[best].rows)do members[#members+1]=row end
        for _,row in ipairs(groups[best+1].rows)do members[#members+1]=row end
        table.sort(members,Sort);groups[best]=Item(members,true);table.remove(groups,best+1)
    end
    return {items=groups,rows=rows,major=major,operations=operations,overflow=#groups>limit,
        truncated=#input>self.LIMITS.rows,inputCount=#input,examined=examined,unexamined=#input>examined}
end
