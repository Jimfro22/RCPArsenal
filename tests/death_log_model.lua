local checks=0;local function check(v,m)checks=checks+1;assert(v,m)end
local RA={};assert(loadfile('RCPArsenal/DeathLogModel.lua'))('RCPArsenal',RA)
local M=RA.DeathLogModel;local fixtures=assert(loadfile('tests/fixtures/death_log/synthetic_density.lua'))()
for _,f in ipairs(fixtures)do
    local before={};for i,row in ipairs(f.damage)do before[i]={row=row,time=row.nativeOffset,amount=row.amount,index=row.nativeIndex}end
    local model=M:Group(f.damage,{})
    local seen,n={},0;local fatal,major=0,0
    for _,item in ipairs(model.items)do
        for _,row in ipairs(item.rows)do check(not seen[row],'Row duplicated');seen[row]=true;n=n+1 end
        if item.fatal then fatal=fatal+1;check(#item.rows==1 and item.rows[1].nativeIndex==1,'Fatal hidden in aggregate')end
        if item.major then major=major+1;check(#item.rows==1,'Largest preceding hit hidden')end
        if item.mixed then check(item.spellID==nil,'Mixed amount retained single spell artwork')end
    end
    check(n==#f.damage and fatal==1 and major==1,'Lost raw row/fatal/major')
    for i,saved in ipairs(before)do check(f.damage[i]==saved.row and saved.row.nativeOffset==saved.time and saved.row.amount==saved.amount and saved.row.nativeIndex==saved.index,'Grouping mutated raw input')end
    check(model.operations<=512,'Grouping exceeded deterministic work bound')
end
local second=M:Group(fixtures[2].damage,{})
check(#second.items==5 and second.items[1].count==4 and second.items[3].count==2,'Synthetic nine-hit example did not preserve early/late bursts')
check(second.items[2].first>second.items[1].first and second.items[2].first<second.items[1].last and second.items[4].first>second.items[3].first and second.items[4].first<second.items[3].last,'Interleaved separate hits lost true interval placement')
check(second.items[1].rows[1].sourceKey~=second.items[3].rows[1].sourceKey,'Different source instances merged')
local duplicate={}
for i=1,16 do duplicate[i]={nativeIndex=i,nativeOffset=-1,kind='damage',spellID=55,sourceName='Same visible name',amount=i}end
local unknown=M:Group(duplicate,{},{items=16})
check(#unknown.items==16,'Source names falsely establish one source instance')
for _,row in ipairs(duplicate)do row.sourceKey='A';row.sourceConfirmed=true end
local known=M:Group(duplicate,{},{items=16})
local n=0;for _,g in ipairs(known.items)do n=n+#g.rows end
check(n==16,'Equal spell/exact time rows were deduped')
local transition={
 {nativeIndex=2,nativeOffset=-2,spellID=55,sourceKey='A',sourceConfirmed=true,kind='damage',amount=1},
 {nativeIndex=3,nativeOffset=-1.8,spellID=55,sourceKey='A',sourceConfirmed=true,kind='damage',amount=1},
 {nativeIndex=4,nativeOffset=-1.6,spellID=55,sourceKey='A',sourceConfirmed=true,kind='damage',amount=1},
 {nativeIndex=5,nativeOffset=-1,spellID=99,sourceKey='A',sourceConfirmed=true,kind='damage',amount=100},
 {nativeIndex=1,nativeOffset=0,spellID=55,sourceKey='A',sourceConfirmed=true,kind='damage',amount=1}}
local split=M:Group(transition,{-1.9},{items=16});check(#split.items==4 and split.items[1].count==1 and split.items[2].count==2,'Important transition was crossed')
local mixed=M:Group(duplicate,{}, {items=3})
check(#mixed.items<=3,'Dense grouping cap not applied')
local references=assert(loadfile('tests/fixtures/death_log/screenshot_density.lua'))()
for _,f in ipairs(references)do
    local g=M:Group(f.damage,{});local seen,count={},0
    for _,item in ipairs(g.items)do
        local previous=-math.huge
        for _,row in ipairs(item.rows)do check(not seen[row.screenshotID],'Screenshot row duplicated');seen[row.screenshotID]=true;count=count+1;check(row.nativeOffset>=previous,'Mixed constituents lost chronology');previous=row.nativeOffset end
        if item.fatal then check(#item.rows==1,'Screenshot fatal was grouped')end
        if item.major then check(#item.rows==1,'Screenshot major preceding hit was grouped')end
    end
    check(count==#f.damage and not g.truncated,'Screenshot retained constituents lost to old16row cap')
    if f.id=='log2'then check(#g.items==5,'Screenshot log2 overlapping bursts failed five-item composition')end
    if f.id=='log3'then check(g.major.amount==671890 and count==37,'Screenshot log3 large preceding hit or dense rows lost')end
end
local oversized={}
for i=1,80 do oversized[i]={nativeIndex=i+1,nativeOffset=i-80,spellID=i,kind='damage',amount=i}end
oversized[80].nativeIndex=1;oversized[79].amount=999999
local bounded=M:Group(oversized,{})
local fatalKept,majorKept=false,false
for _,row in ipairs(bounded.rows)do fatalKept=fatalKept or row==oversized[80];majorKept=majorKept or row==oversized[79]end
check(#bounded.rows==64 and bounded.truncated and fatalKept and majorKept,'Oversize cap lost inspected fatal/major or failed disclosure')
local overlap={}
for i,t in ipairs({-5,-4.7,-4.9,-4.8,-3,0})do overlap[i]={nativeIndex=i==6 and 1 or i+1,nativeOffset=t,spellID=i<=2 and 1 or i<=4 and 2 or 3,sourceKey=i<=2 and 'A'or'B',sourceConfirmed=true,kind='damage',amount=i==5 and 1000 or 1}end
local compact=M:Group(overlap,{}, {items=3})
check(compact.items[1].mixed and compact.items[1].first==-5 and compact.items[1].last==-4.7,'Overlapping compaction shortened true span')
for i=2,#compact.items[1].rows do check(compact.items[1].rows[i-1].nativeOffset<=compact.items[1].rows[i].nativeOffset,'Overlapping compaction wheel chronology moved backward')end
local blocked=M:Group(overlap,{-4.85},{items=3})
for _,item in ipairs(blocked.items)do check(not(item.first< -4.85 and item.last>=-4.85),'Mixed compaction concealed an important transition')end
local start=os.clock();for i=1,1000 do M:Group(duplicate,{})end
print('PASS: '..checks..' Death Log synthetic grouping assertions;1000 builds '..string.format('%.4fs',os.clock()-start)..' (local Lua timing, not WoW CPU)')
