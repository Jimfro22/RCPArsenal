-- Presentation-only chronological clustering. Fixtures contain synthetic or
-- screenshot-derived rows, never a claim about native combat-log availability.
local checks=0;local function check(v,m)checks=checks+1;assert(v,m)end
local RA={};assert(loadfile('RCPArsenal/DeathLogModel.lua'))('RCPArsenal',RA)
local M=RA.DeathLogModel
local function Hit(index,time,amount,spell,source)
    return {nativeIndex=index,nativeOffset=time,kind='damage',amount=amount,spellID=spell or index,
        name='Spell '..(spell or index),sourceName=source,sourceKey=source,sourceConfirmed=source~=nil}
end
local function Snapshot(input)
    local saved={}
    for i,row in ipairs(input)do
        local fields={};for key,value in pairs(row)do fields[key]=value end
        saved[i]={row=row,fields=fields}
    end
    return saved
end
local function Unchanged(input,saved)
    check(#input==#saved,'Grouping changed input length')
    for i,old in ipairs(saved)do
        check(input[i]==old.row,'Grouping reordered or replaced a raw row')
        for key,value in pairs(old.fields)do check(old.row[key]==value,'Grouping changed captured field '..key)end
        for key,value in pairs(old.row)do check(old.fields[key]==value,'Grouping added a captured field '..key)end
    end
end
local function Verify(input,cuts,options)
    local before=Snapshot(input);local model=M:Group(input,cuts or{},options)
    local position,fatalCount,majorCount=0,0,0
    for _,item in ipairs(model.items)do
        check(item.count==#item.rows and item.count>0,'Count omitted or duplicated a hit')
        check(item.first==item.rows[1].nativeOffset and item.last==item.rows[#item.rows].nativeOffset,'Cluster shortened or invented its raw time span')
        check(item.last-item.first<=.5,'Neighbor chaining/density pressure exceeded the fixed anchor window')
        local amount,known,complete,representative,knownLargest,fatal,major=0,0,true,nil,nil,nil,false
        for _,row in ipairs(item.rows)do
            position=position+1;check(model.rows[position]==row,'Clusters lost raw chronological member order')
            if row.amount~=nil then amount=amount+row.amount;known=known+1 else complete=false end
            if row.kind=='damage'then
                representative=representative or row
                if row.amount~=nil and(not knownLargest or row.amount>knownLargest.amount)then knownLargest=row end
            else check(#item.rows==1,'Unknown event was folded into a damage total')end
            if row.nativeIndex==1 then fatal=row end
            if row==model.major then major=true end
        end
        representative=knownLargest or representative or item.rows[1]
        check(item.amount==amount and item.amountComplete==complete and item.knownAmounts==known,'Known total/unknown amount state changed')
        check(item.representative==representative and item.spellID==representative.spellID and item.name==representative.name,'Artwork representative is not the largest known raw damage hit')
        check(item.fatalRow==fatal and(item.fatal==true)==(fatal~=nil),'Fatal identity was inferred from time, amount or artwork')
        check((item.major==true)==major,'Major flag does not identify the group containing the largest preceding hit')
        if item.fatal then fatalCount=fatalCount+1 end
        if item.major then majorCount=majorCount+1 end
    end
    check(position==#model.rows and #model.rows<=64,'Retained member count exceeded64 or lost a raw hit')
    check(model.operations<=64,'Grouping reintroduced a density/backtracking work loop')
    if model.major then check(majorCount==1,'Largest preceding hit was duplicated or omitted')end
    local retainedFatal=0;for _,row in ipairs(model.rows)do if row.nativeIndex==1 then retainedFatal=retainedFatal+1 end end
    check(fatalCount==retainedFatal,'Fatal retained row disappeared from cluster metadata')
    Unchanged(input,before)
    return model
end
check(M.LIMITS.window==.5,'Approved anchored damage window changed')

-- Different abilities/sources and missing source identity do not prevent a
-- nearby damage cluster. Largest damage is artwork; no source is inferred.
local cross={Hit(4,-1,10,100,'A'),Hit(3,-.9,40,200,'B'),Hit(2,-.8,20,300,nil),Hit(1,0,1,400,'C')}
local model=Verify(cross)
check(#model.items==2 and model.items[1].count==3 and model.items[1].amount==70,'Cross-source/cross-ability nearby damage did not cluster')
check(model.items[1].representative==cross[2]and model.items[1].mixed and model.items[1].sourceKey==nil,'Cluster lost largest artwork or claimed one source')
local noSource={Hit(2,-.5,1,100),Hit(3,-.4,2,100),Hit(1,0,3,100)}
model=Verify(noSource)
check(#model.items==1 and model.items[1].count==3,'Unknown source identity blocked the presentation cluster')

-- The window is inclusive at the exact half-second boundary. Values just
-- outside remain separate, and nearby neighbor chains cannot enlarge it.
local boundary={Hit(5,-1,1),Hit(4,-.5,2),Hit(3,-.499999999,3),Hit(2,-.2,4),Hit(1,.1,5)}
model=Verify(boundary)
check(#model.items==3 and model.items[1].count==2 and model.items[2].count==2,'Half-second boundary was rounded or a neighbor chain escaped its anchor')
local chain={Hit(4,-2,1),Hit(3,-1.6,2),Hit(2,-1.2,3),Hit(1,0,4)}
model=Verify(chain,{}, {items=1,nearby=99,burst=99,window=99})
check(#model.items==3 and model.items[1].count==2 and model.overflow,'Legacy options/density target widened the fixed grouping window')
local distant={};for i=1,64 do distant[i]=Hit(i,i*.6,1)end
model=Verify(distant,{}, {items=2})
check(#model.items==64 and model.overflow and model.operations==64,'Density pressure merged distant clusters or exceeded one grouping pass')

-- Explicit Preview transitions and unknown events are barriers; a transition
-- exactly at the first hit is already on its new side and does not split ties.
local transition={Hit(2,-2,1),Hit(3,-1.8,2),Hit(4,-1.6,3),Hit(1,0,4)}
model=Verify(transition,{-1.9})
check(#model.items==3 and model.items[1].count==1 and model.items[2].count==2,'Cluster crossed an explicit transition')
model=Verify(transition,{-2,-1.8})
check(#model.items==3 and model.items[2].first==-1.8,'Boundary transition was assigned to the wrong side')
local unknown={Hit(2,-1,10),{nativeIndex=3,nativeOffset=-.9,kind='unknown',name='Unclassified',amount=8},Hit(4,-.8,20),Hit(1,0,1)}
model=Verify(unknown)
check(#model.items==4 and model.items[2].representative==unknown[2]and model.items[2].amount==8,'Unknown record was dropped or relabelled as damage')

-- Missing amounts are not zero. Known zero can still be the best known damage
-- representative; absorbed/overkill facts do not change the damage total.
local partial={Hit(3,-1,nil),Hit(2,-.9,0),Hit(1,-.8,8)}
partial[3].absorbed=900;partial[3].overkill=4;partial[3].recordedHP=9
model=Verify(partial)
check(model.items[1].amount==8 and not model.items[1].amountComplete and model.items[1].representative==partial[3],'Missing damage became zero or absorption/overkill inflated total')
partial[3].amount=nil;model=Verify(partial)
check(model.items[1].representative==partial[2]and model.items[1].amount==0 and model.items[1].knownAmounts==1 and not model.items[1].amountComplete,'Known zero lost to unknown amount')
partial[2].amount=nil;model=Verify(partial)
check(model.items[1].representative==partial[1]and model.items[1].knownAmounts==0 and not model.items[1].amountComplete,'All-unknown cluster lacks deterministic raw fallback')

-- Native index1 remains fatal even when it is neither latest nor largest. Its
-- HP/overkill are not substituted by the icon representative's observations.
local fatal={Hit(2,-.4,500,200),Hit(1,-.3,10,100),Hit(3,0,300,300)}
fatal[1].recordedHP=700;fatal[1].overkill=0;fatal[2].recordedHP=17;fatal[2].overkill=90
model=Verify(fatal)
local cluster=model.items[1]
check(#model.items==1 and cluster.representative==fatal[1]and cluster.fatalRow==fatal[2]and cluster.major,'Largest/fatal members were forcibly separated or conflated')
check(cluster.fatalRow.recordedHP==17 and cluster.fatalRow.overkill==90 and cluster.last==0,'Fatal endpoint was replaced by largest/latest event')
local unknownFatal={Hit(2,-.1,200),{nativeIndex=1,nativeOffset=0,kind='unknown',amount=1,name='Death record'}}
model=Verify(unknownFatal)
check(#model.items==2 and model.items[2].fatalRow==unknownFatal[2],'Unknown fatal identity was fabricated as damage or lost')

-- Ties retain native index order, then original input order for equal index.
-- Equal facts are separate events; equal amounts pick earliest raw chronology.
local a,b,c,d=Hit(8,-1,30,10),Hit(4,-1,30,20),Hit(4,-1,30,30),Hit(1,-.8,30,40)
local tied={a,b,c,d};model=Verify(tied)
check(model.rows[1]==b and model.rows[2]==c and model.rows[3]==a and model.rows[4]==d,'Equal-time/index sorting is unstable')
check(model.items[1].representative==b and model.items[1].count==4 and model.items[1].amount==120,'Equal facts were deduplicated or artwork tie-breaking changed')
for i=1,20 do local again=M:Group(tied,{})
    check(again.rows[1]==b and again.rows[2]==c and again.items[1].representative==b,'Repeated grouping changed stable tie order')
end
local shuffled={cross[4],cross[3],cross[1],cross[2]};local shuffledModel=Verify(shuffled)
check(shuffledModel.items[1].representative==cross[2]and shuffledModel.items[1].count==3,'Input enumeration changed unique-time grouping')

-- Shared synthetic and screenshot-derived fixtures exercise the same product
-- grouping for Preview/live. Every retained raw hit stays accessible.
local fixtures=assert(loadfile('tests/fixtures/death_log/synthetic_density.lua'))()
for _,fixture in ipairs(fixtures)do Verify(fixture.damage)end
local second=Verify(fixtures[2].damage)
check(#second.items==4 and second.items[1].count==4 and second.items[3].count==3,'Anchored screenshot-style bursts were not chronological cross-ability clusters')
local references=assert(loadfile('tests/fixtures/death_log/screenshot_density.lua'))()
for _,fixture in ipairs(references)do
    local result=Verify(fixture.damage)
    check(#result.rows==#fixture.damage and not result.truncated,'Screenshot rows lost to an obsolete density cap')
    if fixture.id=='log2'then check(#result.items==4,'Screenshot log2 did not use the shared half-second rule')end
    if fixture.id=='log3'then check(result.major.amount==671890 and #result.rows==37,'Screenshot largest preceding hit/raw row count changed')end
end

-- Inspect at most256 inputs; retain at most64 with inspected fatal/largest
-- preserved. No later unexamined event is silently claimed as captured.
local oversized={};for i=1,300 do oversized[i]=Hit(i+1,i-300,i)end
oversized[256].nativeIndex=1;oversized[255].amount=999999;oversized[300].amount=9999999
model=Verify(oversized)
local fatalKept,majorKept=false,false
for _,row in ipairs(model.rows)do fatalKept=fatalKept or row==oversized[256];majorKept=majorKept or row==oversized[255]end
check(#model.rows==64 and model.truncated and model.examined==256 and model.unexamined and fatalKept and majorKept and model.major==oversized[255],'Bounded retention lost inspected fatal/largest or read beyond its disclosed scan')

-- Viewport filtering produces a separate presentation list with integer bounds.
-- Damage grouping/share inputs remain intact; no out-of-window row is clamped.
local function View(input,span,expected,maxHealth,alignment)
    local before=Snapshot(input);local view=M:Viewport(input,maxHealth,alignment)
    check(view.span==span and view.first==-span and view.last==0 and view.span==math.floor(view.span)and span>=5 and span<=8,'Viewport lost its bounded integer window')
    check(view.retainedCount==math.min(#input,64)and view.omitted==view.retainedCount-#view.rows,'Viewport omitted count lost retained-page scope')
    if expected then
        check(#view.rows==#expected,'Viewport retained the wrong number of visible rows')
        for i,index in ipairs(expected)do check(view.rows[i].nativeIndex==index,'Viewport changed chronological row identity or edge-clamped an excluded event')end
    end
    for _,row in ipairs(view.rows)do check(row.nativeOffset>=view.first and row.nativeOffset<=view.last,'Viewport contains an out-of-window raw time')end
    Unchanged(input,before)
    return view
end
View({},5,{})
View({Hit(2,-4.8,10),Hit(1,0,5)},5,{2,1})
View({Hit(2,-5.2,10),Hit(1,0,5)},6,{2,1})
View({Hit(2,-7.2,10),Hit(1,0,5)},8,{2,1})
View({Hit(2,-8,10),Hit(1,0,5)},8,{2,1})
View({Hit(2,-7,10),Hit(3,-1,100),Hit(1,0,500)},5,{3,1},1000)
View({Hit(2,-6.1,20),Hit(3,-1,100),Hit(1,0,500)},7,{2,3,1},100)
View({Hit(2,-6.1,40),Hit(3,-1,50),Hit(1,0,500)},7,{2,3,1},1000)
View({Hit(2,-5.1,25),Hit(3,-1,50),Hit(1,0,500)},6,{2,3,1},1000)
View({Hit(2,-5.1,24.999),Hit(3,-1,50),Hit(1,0,500)},5,{3,1},1000)
View({Hit(2,-7.2,20),Hit(3,-6.2,60),Hit(4,-1,100),Hit(1,0,500)},8,{2,3,4,1},100)
for _,invalidMax in ipairs({0,-1,math.huge,-math.huge,0/0,'100',false,{}})do
    View({Hit(2,-6.1,40),Hit(3,-1,50),Hit(1,0,500)},7,{2,3,1},invalidMax)
    View({Hit(2,-6.1,20),Hit(3,-1,100),Hit(1,0,500)},5,{3,1},invalidMax)
end
View({Hit(1,-7,999999)},5,{})
View({Hit(2,-8.000001,999999),Hit(1,0,5)},5,{1},100)
View({Hit(2,-7,nil),Hit(3,-6,0),Hit(1,0,nil)},5,{1},100)
local edges={Hit(2,-5,1),Hit(3,-5.000001,0),Hit(4,.000001,1),Hit(1,0,1)}
local view=View(edges,5,{2,1})
check(#M:Group(edges,{}).rows==4 and #view.rows==2,'Viewport filter rewrote the complete retained grouping/report input')
local unknownAge={Hit(3,-7,nil),Hit(4,-6,0),{nativeIndex=5,nativeOffset=-7.5,kind='unknown',amount=100000},Hit(2,-4,1),Hit(1,0,1)}
view=View(unknownAge,5,{2,1});check(view.omitted==3,'Unknown or zero damage widened the viewport')
local allUnknown={{nativeIndex=2,nativeOffset=-4,kind='unknown',amount=200},Hit(3,-2,nil),Hit(1,0,nil)}
View(allUnknown,5,{2,3,1})
local retainedFirst={}
for i=1,80 do retainedFirst[i]=Hit(i+1,-20-i,1)end
retainedFirst[80].nativeIndex=1;retainedFirst[80].nativeOffset=0
retainedFirst[79].amount=999999;retainedFirst[79].nativeOffset=-7.2
view=View(retainedFirst,8,{80,1})
check(view.retainedCount==64 and view.omitted==62 and view.examined==80 and view.truncated and not view.unexamined,'Viewport did not apply bounded fatal/major retention before filtering')

-- A validated approximate use can widen the same integer window. These are
-- frozen synthetic receipts, not an assertion that the two clocks coincide.
local secret=setmetatable({},{__tostring=function()error('Secret formatted')end,__index=function()error('Secret indexed')end})
function issecretvalue(value)return rawequal(value,secret)end
local liveReads=0
local function Forbidden()liveReads=liveReads+1;error('Viewport queried live state or scheduled work')end
GetTime,UnitGUID=Forbidden,Forbidden
C_Spell={GetSpellCooldown=Forbidden,GetSpellCharges=Forbidden};C_Item={GetItemCooldown=Forbidden}
C_DeathRecap={GetRecapEvents=Forbidden};C_Timer={NewTimer=Forbidden,NewTicker=Forbidden,After=Forbidden}
local function UsePage(ages,delta)
    delta=delta or 0
    local page={diedAt=100,localSessionStartedAt=60,casts={},native={recapID=50,
        rows={Hit(3,-.6,10),Hit(2,0,20),Hit(1,delta,30)},clockDiagnostic={
            localClock='GetTime',localDeathNoticeAt=100,localSessionStartedAt=60,
            nativeFatalTimestamp=500+delta,nativeMaximumTimestamp=500,nativeRowCount=3}}}
    for _,row in ipairs(page.native.rows)do row.timestamp=500+row.nativeOffset end
    for i,age in ipairs(ages)do page.casts[i]={spellID=235450,observedAt=100-age,source='UNIT_SPELLCAST_SUCCEEDED'}end
    return page
end
local function UseView(page,span,count)
    local castBefore=Snapshot(page.casts);local alignment=M:AlignUses(page)
    local alignedBefore,unalignedBefore=Snapshot(alignment.aligned),Snapshot(alignment.unaligned)
    local result=View(page.native.rows,span,nil,1000,alignment)
    local visible=0
    for _,entry in ipairs(alignment.aligned)do
        if entry.offset>=result.first and entry.offset<=result.last then visible=visible+1 end
    end
    check(visible==count,'Use viewport hid a valid in-range marker or clamped an older receipt')
    Unchanged(page.casts,castBefore);Unchanged(alignment.aligned,alignedBefore);Unchanged(alignment.unaligned,unalignedBefore)
    return result,alignment
end
local page=UsePage({5.6,6.5,4.6})
view,model=UseView(page,7,3)
check(model.anchorValid and #model.aligned==3 and #model.unaligned==0,'Screenshot-style receipts did not retain verified approximate alignment')
check(model.aligned[1].row==page.casts[1]and model.aligned[2].row==page.casts[2],'Viewport reordered receipt identity')
UseView(UsePage({5}),5,1)
UseView(UsePage({5.01}),6,1)
UseView(UsePage({8}),8,1)
view,model=UseView(UsePage({8.01,4.6}),5,1)
check(#model.aligned==2 and model.aligned[1].offset<-8,'Older use was removed from the frozen aligned result/full report')
UseView(UsePage({8.01}),5,0)
UseView(UsePage({0}),5,1)
-- The fatal-to-maximum adjustment, not local receipt age, sets inclusion.
view,model=UseView(UsePage({5.9},-.2),7,1)
check(math.abs(model.aligned[1].offset+6.1)<1e-9 and math.abs(model.aligned[1].age-5.9)<1e-9,'Viewport discarded the shifted native fatal anchor')
UseView(UsePage({7.9},-.2),5,0)
view,model=UseView(UsePage({6.5,6.5,4.6}),7,3)
check(model.aligned[1].row~=model.aligned[2].row and model.aligned[1].offset==model.aligned[2].offset,'Repeated captured uses were merged')
for _,change in ipairs({
    function(p)p.native.clockDiagnostic=nil end,
    function(p)p.native.clockDiagnostic.localDeathNoticeAt=99 end,
    function(p)p.native.clockDiagnostic.nativeFatalTimestamp=499 end,
    function(p)p.native.clockDiagnostic.nativeMaximumTimestamp=math.huge end,
})do
    page=UsePage({6.5});change(page);view,model=UseView(page,5,0)
    check(not model.anchorValid and #model.unaligned==1 and model.unaligned[1].row==page.casts[1],'Invalid anchor invented a marker or removed the fallback receipt')
end
page=UsePage({6.5});page.casts[1].source='DERIVED_FROM_AGGREGATE_ENDPOINT'
view,model=UseView(page,5,0)
check(model.anchorValid and #model.unaligned==1,'Unaligned derived use widened the viewport')
page=UsePage({6.5});page.casts[1].observedAt=nil;UseView(page,5,0)
-- Expansion may expose small damage as a consequence, but never modifies or
-- clamps old rows; omitted damage counts remain about the retained damage list.
page=UsePage({6.5});model=M:AlignUses(page)
local oldSmall={Hit(4,-8.01,1),Hit(3,-7.1,1),Hit(2,-6.9,1),Hit(5,-.6,100),Hit(1,0,500)}
view=View(oldSmall,7,{2,5,1},1000,model)
check(view.omitted==2 and #oldSmall==5,'Use expansion changed omission scope or raw report rows')
View({Hit(2,-7.2,100),Hit(1,0,50)},8,{2,1},1000,model)
-- Foreign or malformed presentation data cannot override the validated anchor,
-- public finite offset bounds, or the 64-entry work limit.
local function Candidate(entries)return {anchorValid=true,approximate=true,aligned=entries,unaligned={{offset=-8}}}end
local function Entry(offset)return {offset=offset,approximate=true}end
for _,bad in ipairs({false,{},secret,{anchorValid=false,approximate=true,aligned={Entry(-8)}},
    {anchorValid=1,approximate=true,aligned={Entry(-8)}},{anchorValid=true,aligned={Entry(-8)}},
    {anchorValid=true,approximate=true,aligned=secret}})do View(page.native.rows,5,nil,1000,bad)end
for _,badOffset in ipairs({math.huge,-math.huge,0/0,'-8',false,secret,-8.01,.01})do
    View(page.native.rows,5,nil,1000,Candidate({Entry(badOffset)}))
end
View(page.native.rows,5,nil,1000,Candidate({secret,{offset=-8}}))
local many={};for i=1,64 do many[i]=Entry(-1)end;many[65]=Entry(-8)
View(page.native.rows,5,nil,1000,Candidate(many));many[64]=Entry(-8)
View(page.native.rows,8,nil,1000,Candidate(many))
local trust=issecretvalue;issecretvalue=nil
View(page.native.rows,5,nil,1000,Candidate({Entry(-8)}))
issecretvalue=function()error('Trust check failed')end
View(page.native.rows,5,nil,1000,Candidate({Entry(-8)}));issecretvalue=trust
check(liveReads==0,'Viewport invoked live state queries or scheduling')
print('PASS: '..checks..' anchored grouping, viewport, largest/fatal identity, chronology and immutability assertions')
