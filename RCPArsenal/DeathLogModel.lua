local _,RA=...
local Model={};RA.DeathLogModel=Model
-- Presentation only. Inputs are normalized public recorder facts or the private
-- Example fixture. Raw rows are never rewritten, rounded, removed or deduped.
Model.LIMITS={rows=64,window=.5,items=8,history=256}
local function Time(row)return row.nativeOffset end
local function Sort(a,b)
    if Time(a)==Time(b)then return a.nativeIndex<b.nativeIndex end
    return Time(a)<Time(b)
end
local function Cut(cuts,first,last)
    for _,time in ipairs(cuts or{})do if time>first and time<=last then return true end end
    return false
end
local function Item(rows,major)
    local item={rows=rows,first=Time(rows[1]),last=Time(rows[#rows]),amount=0,amountComplete=true,knownAmounts=0,mixed=false}
    local representative,largest
    for _,row in ipairs(rows)do
        if row.amount~=nil then item.amount=item.amount+row.amount;item.knownAmounts=item.knownAmounts+1 else item.amountComplete=false end
        if row.kind=="damage"then
            representative=representative or row
            if row.amount~=nil and(not largest or row.amount>largest.amount)then largest=row end
        end
        if row.nativeIndex==1 then item.fatalRow=row;item.fatal=true end
        if row==major then item.major=true end
        if row.spellID~=rows[1].spellID or row.name~=rows[1].name then item.mixed=true end
    end
    item.count=#rows
    -- The largest known damage supplies artwork, not fatal identity or an
    -- invented aggregate timestamp/health sample. Ties keep raw chronology.
    item.representative=largest or representative or rows[1]
    item.spellID=item.representative.spellID;item.name=item.representative.name
    return item
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
    -- Exact-time credits share one visual total, regardless of incoming spell
    -- or source. Each distinct hit remains a member; no shield attribution or
    -- internal ordering beyond the retained native index is inferred.
    local exact={}
    for _,group in ipairs(groups)do
        local tail=exact[#exact]
        if tail and tail.first==group.first then
            tail.rows[#tail.rows+1]=group.row;tail.amount=tail.amount+group.amount
        else exact[#exact+1]=group end
    end
    groups=exact
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
local function Retain(input,limits)
    local rows,order={},{};local examined=math.min(#input,limits.history);local fatal,largest
    for i=1,examined do
        local row=input[i]
        order[row]=order[row]or i
        if row.nativeIndex==1 then fatal=row end
        if row.nativeIndex~=1 and row.kind=="damage"and row.amount~=nil and(not largest or row.amount>largest.amount)then largest=row end
        if i<=limits.rows then rows[#rows+1]=row end
    end
    for _,important in ipairs({fatal or false,largest or false})do
        if important then
            local present=false;for _,row in ipairs(rows)do if row==important then present=true end end
            if not present then for i=#rows,1,-1 do if rows[i]~=fatal and rows[i]~=largest then rows[i]=important;break end end end
        end
    end
    table.sort(rows,function(a,b)
        if Time(a)~=Time(b)then return Time(a)<Time(b)end
        if a.nativeIndex~=b.nativeIndex then return a.nativeIndex<b.nativeIndex end
        return order[a]<order[b]
    end)
    return rows,examined
end
local function Public(value)
    if type(issecretvalue)~="function"then return nil end
    local ok,secret=pcall(issecretvalue,value)
    if ok and secret==false then return value,true end
end
local function Table(value)
    value=Public(value)
    if type(value)=="table"and getmetatable(value)==nil then return value end
end
local function Number(value)
    value=Public(value)
    if type(value)=="number"and value==value and value>-math.huge and value<math.huge then return value end
end
-- Viewport selection is a new presentation list, never a crop of the recorded
-- page or share report. Importance only changes presentation: an earlier hit
-- must reach 20% of the public reference max or half the largest known nonfatal
-- hit in the last 8 seconds. Unknown/fatal/out-of-window hits cannot set it.
-- Valid approximate uses can extend this window using their aligned offsets,
-- including the frozen fatal-to-maximum adjustment, never their local ages.
function Model:Viewport(input,maxHealth,alignment)
    local retained,examined=Retain(input,self.LIMITS)
    local maximum=type(maxHealth)=="number"and maxHealth==maxHealth and maxHealth>0 and maxHealth<math.huge and maxHealth or nil
    local function Candidate(row)
        return row.kind=="damage"and row.nativeIndex~=1 and row.amount~=nil and row.amount>0 and Time(row)>=-8 and Time(row)<=0
    end
    local largest
    for _,row in ipairs(retained)do if Candidate(row)then largest=math.max(largest or 0,row.amount)end end
    local age=0
    for _,row in ipairs(retained)do
        if Candidate(row)and(maximum and row.amount>=maximum*.2 or largest and row.amount>=largest*.5)then age=math.max(age,-Time(row))end
    end
    alignment=Table(alignment)
    if alignment and Public(alignment.anchorValid)==true and Public(alignment.approximate)==true then
        local aligned=Table(alignment.aligned)
        for i=1,aligned and math.min(#aligned,self.LIMITS.rows)or 0 do
            local entry=Table(aligned[i]);local offset=entry and Number(entry.offset)
            if offset and Public(entry.approximate)==true and offset>=-8 and offset<=0 then age=math.max(age,-offset)end
        end
    end
    local span=math.max(5,math.min(8,math.ceil(age)))
    local rows={}
    for _,row in ipairs(retained)do if Time(row)>=-span and Time(row)<=0 then rows[#rows+1]=row end end
    return {rows=rows,first=-span,last=0,span=span,omitted=#retained-#rows,retainedCount=#retained,
        truncated=#input>self.LIMITS.rows,inputCount=#input,examined=examined,unexamined=#input>examined}
end
function Model:Group(input,transitions,options)
    options=options or{}
    local rows,examined=Retain(input,self.LIMITS)
    local major
    for _,row in ipairs(rows)do
        if row.nativeIndex~=1 and row.kind=="damage"and row.amount~=nil and(not major or row.amount>major.amount)then major=row end
    end
    local groups={};local operations=0
    for _,row in ipairs(rows)do
        operations=operations+1
        local previous=groups[#groups];local tail=previous and previous[#previous]
        -- Only the current chronological cluster can grow. Its first raw time
        -- fixes the window, so a chain of nearby neighbors cannot widen it.
        if tail and row.kind=="damage"and tail.kind=="damage"
            and Time(row)-Time(previous[1])<=self.LIMITS.window
            and not Cut(transitions,Time(tail),Time(row))then
            previous[#previous+1]=row
        else groups[#groups+1]={row}end
    end
    for index,members in ipairs(groups)do groups[index]=Item(members,major)end
    -- Layout pressure is disclosed, never resolved by merging distant hits.
    local limit=options.items or self.LIMITS.items
    return {items=groups,rows=rows,major=major,operations=operations,overflow=#groups>limit,
        truncated=#input>self.LIMITS.rows,inputCount=#input,examined=examined,unexamined=#input>examined}
end
-- This is an approximate death-notice-to-fatal-event alignment, not evidence
-- that the clocks share an origin or that a use caused any recorded effect.
local function PositiveID(value)
    value=Number(value)
    return value and value>0 and value==math.floor(value)and value or nil
end
local function UseAnchor(page,limit)
    if not page then return nil,"page-unavailable"end
    local native=Table(page.native)
    if not native or not PositiveID(native.recapID)then return nil,"native-recap-unavailable"end
    local clock=Table(native.clockDiagnostic)
    if not clock or Public(clock.localClock)~="GetTime"then return nil,"clock-anchor-unavailable"end
    local died,started=Number(page.diedAt),Number(page.localSessionStartedAt)
    if not died or not started or started>died then return nil,"local-window-unavailable"end
    if Number(clock.localDeathNoticeAt)~=died or Number(clock.localSessionStartedAt)~=started then return nil,"stale-local-anchor"end
    local fatal,maximum=Number(clock.nativeFatalTimestamp),Number(clock.nativeMaximumTimestamp)
    if not fatal or not maximum or fatal>maximum then return nil,"native-clock-anchor-unavailable"end
    local rows=Table(native.rows)
    if not rows or #rows==0 or #rows>limit then return nil,"native-rows-unavailable"end
    local count,countPublic=Public(clock.nativeRowCount)
    if not countPublic or count~=nil and Number(count)~=#rows then return nil,"stale-native-row-count"end
    local rawMaximum,rawFatal,fatalCount=nil,nil,0
    for position=1,#rows do
        local row=Table(rows[position])
        local timestamp=row and Number(row.timestamp)
        local index=row and PositiveID(row.nativeIndex)
        if not timestamp or not index then return nil,"native-timestamp-unavailable"end
        rawMaximum=math.max(rawMaximum or timestamp,timestamp)
        if index==1 then rawFatal=timestamp;fatalCount=fatalCount+1 end
    end
    if fatalCount~=1 or rawFatal~=fatal or rawMaximum~=maximum then return nil,"stale-native-anchor"end
    local delta=Number(fatal-maximum)
    if not delta then return nil,"native-clock-anchor-unavailable"end
    return {died=died,started=started,delta=delta}
end
function Model:AlignUses(input)
    local page=Table(input)
    local anchor,reason=UseAnchor(page,self.LIMITS.rows)
    local result={aligned={},unaligned={},anchorValid=anchor~=nil,reason=reason,approximate=true,examined=0,truncated=false}
    local casts=page and Table(page.casts)
    if not casts then return result end
    result.truncated=#casts>self.LIMITS.rows
    -- Match the recorder/share report's newest retained receipt ring. Repeats
    -- remain distinct; the caller decides which aligned offsets fit its view.
    for index=math.max(1,#casts-self.LIMITS.rows+1),#casts do
        result.examined=result.examined+1
        local row=Table(casts[index]);local failure=reason
        local time=row and Number(row.observedAt)
        local age,offset
        if not row then failure="use-receipt-unavailable"
        elseif not failure then
            if Public(row.source)~="UNIT_SPELLCAST_SUCCEEDED"then failure="unverified-use-source"
            elseif not PositiveID(row.spellID)then failure="use-identity-unavailable"
            elseif not time then failure="use-time-unavailable"
            elseif time<anchor.started or time>anchor.died then failure="use-outside-session"
            else
                age=Number(anchor.died-time)
                if not age or age>30 then failure="use-outside-retained-window"
                else offset=Number(time-anchor.died+anchor.delta);if not offset then failure="use-offset-unavailable"end end
            end
        end
        if failure then result.unaligned[#result.unaligned+1]={row=row,index=index,reason=failure}
        else result.aligned[#result.aligned+1]={row=row,index=index,offset=offset,age=age,approximate=true}end
    end
    return result
end
