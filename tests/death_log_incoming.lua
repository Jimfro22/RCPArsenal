-- Fabricated receipts exercise the real model; no owner gameplay fixture.
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local secret=setmetatable({},{__tostring=function()error('Secret stringified')end})
function issecretvalue(v)return rawequal(v,secret)end
local RA={};assert(loadfile('RCPArsenal/DeathLogModel.lua'))('RCPArsenal',RA);local M=RA.DeathLogModel
local function receipt(n,at,kind,amount,flag)return{sequence=n,observedAt=at,kind=kind,amount=amount,flag=flag or'',school=1,spellID=999,recordedHP=9999,sourceName='Unverified metadata'}end
local page={diedAt=100,localSessionStartedAt=80,liveIncoming={source='UNIT_COMBAT:player',clock='GetTime',startedAt=80,endedAt=100,combatEntryObserved=true,rows={
 receipt(4,99.8,'damage',50),receipt(1,92,'damage',100),receipt(3,99.7,'healing',40,'CRITICAL'),receipt(2,99.7,'damage',0,'ABSORB'),receipt(5,99.8,'damage',50)}},
 native={rows={{nativeIndex=1,amount=12345}}},casts={{spellID=871,observedAt=96,source='UNIT_SPELLCAST_SUCCEEDED'}}}
local model=M:Incoming(page)
check(model.available and #model.rows==5 and model.first==-8 and model.last==0,'Eight-second projection lost exact boundary or stream identity')
check(model.rows[1].sequence==1 and model.rows[2].sequence==2 and model.rows[3].sequence==3,'Receipt chronology/ties changed')
check(model.damageTotal==200 and model.healingTotal==40 and model.damageCount==3 and model.healingCount==1 and model.absorbedCount==1,'Absorbed zero or separate healing was miscounted')
check(#model.buckets[16].damage.rows==3 and model.buckets[16].damage.amount==100 and model.buckets[16].healing.amount==40,'Dense final bucket lost individual events')
check(model.rows[3].critical and not model.rows[1].spellID and not model.rows[1].recordedHP and not model.rows[1].sourceName,'Projection guessed spell/source/health or lost critical flag')
check(page.liveIncoming.rows[1].sequence==4 and page.liveIncoming.rows[1].kind=='damage'and page.native.rows[1].amount==12345,'Presentation rewrote recorder/native facts')
local uses=M:AlignLocalUses(page)
check(uses.anchorValid and #uses.aligned==1 and uses.aligned[1].offset==-4 and uses.aligned[1].localClock and not uses.aligned[1].approximate,'Own casts require a native clock or were retimed')
page.casts[#page.casts+1]={spellID=871,observedAt=99,source='DERIVED'}
check(#M:AlignLocalUses(page).aligned==1,'Unverified cast became a local activation')
for _,bad in ipairs({receipt(6,100.1,'damage',12),receipt(7,91.99,'damage',12),receipt(8,99,'damage',secret),receipt(9,99,'damage',-1),receipt(10,99,'unknown',3),receipt(11,99,'damage',math.huge)})do table.insert(page.liveIncoming.rows,bad)end
local filtered=M:Incoming(page)
check(#filtered.rows==5 and filtered.rejected==6,'Invalid/private/stale receipts contaminated history')
page.liveIncoming.clock='Other';check(not M:Incoming(page).available,'Unrelated clock was silently relabelled')
page.liveIncoming.clock='GetTime';page.liveIncoming.endedAt=99
check(not M:Incoming(page).available and not M:Incoming(secret).available,'Different death or private page supplied live history')
page.liveIncoming.endedAt=100;page.liveIncoming.rows={}
for i=1,256 do page.liveIncoming.rows[i]=receipt(i,92+i/32,'damage',i)end
local dense=M:Incoming(page);local count,total=0,0
for i=1,16 do local b=dense.buckets[i];if b then count=count+#b.damage.rows;total=total+b.damage.amount end end
check(#dense.rows==256 and count==256 and total==32896 and dense.damageTotal==32896,'Bounded dense grouping dropped or duplicated receipts')
print('PASS: '..checks..' incoming provenance, exact retention, grouping, totals, local casts and secret rejection assertions')
