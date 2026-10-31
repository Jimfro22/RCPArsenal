-- Synthetic density/regression inputs based only on handoff summaries.
-- These are NOT supplied logs, parsed Warcraft Logs, or live API examples.
local function hit(index,time,spell,source,amount)
    return {nativeIndex=index,nativeOffset=time,kind='damage',spellID=spell,name='Synthetic '..spell,
        sourceKey=source,sourceConfirmed=true,sourceName='Synthetic source',amount=amount}
end
local first={damage={},heals={},shieldCredits={}}
for i=1,8 do first.damage[i]=hit(i,-5+i*.6,100+i%3,'synthetic-A',10000+i)end
first.damage[4].amount=0;first.damage[4].absorbed=45000
first.shieldCredits={{incomingIndex=4,amount=30000,provider='Example ally A'},{incomingIndex=4,amount=15000,provider='Example ally B'}}
for i=1,30 do first.heals[i]={offset=-5+i/6,amount=1000,spellID=2061,healer='Synthetic healer'}end
-- Exact displayed geometry from log2, still a presentation-only fixture:
-- stable source keys encode screenshot suffixes, not a native ID contract.
local second={damage={}}
for i,time in ipairs({-2.54,-2.28,-2.04,-1.79})do second.damage[#second.damage+1]=hit(i+1,time,1285017,'screenshot-Axegrinder-10',10000)end
second.damage[#second.damage+1]=hit(6,-2.47,200,'screenshot-boss',137103)
for i,time in ipairs({-.52,-.26})do second.damage[#second.damage+1]=hit(i+6,time,1285017,'screenshot-Axegrinder-8',11000)end
second.damage[#second.damage+1]=hit(9,-.45,200,'screenshot-boss',138342)
second.damage[#second.damage+1]=hit(1,0,1285017,'screenshot-Axegrinder-8',69754)
local third={damage={},support={{spellID=11426,start=-8,finish=-.2,openLeft=true,fictional=true}}}
for i=1,7 do third.damage[#third.damage+1]=hit(i+1,-5+i*.55,300,'venom-instance',9000)end
third.damage[#third.damage+1]=hit(9,-.45,301,'boss-instance',672000)
third.damage[#third.damage+1]=hit(1,-.03,300,'venom-instance',9000)
return {first,second,third}
