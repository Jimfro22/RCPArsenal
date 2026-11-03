-- Fabricated late reports, deliberately overlapping native amounts. No event
-- identity or damage time may be inferred from that overlap.
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local secret=setmetatable({},{__tostring=function()error('Secret stringified')end})
function issecretvalue(v)return rawequal(v,secret)end
local RA={};assert(loadfile('RCPArsenal/DeathLogModel.lua'))('RCPArsenal',RA);local M=RA.DeathLogModel
local function receipt(i,at,kind,amount,flag)return{sequence=i,observedAt=at,kind=kind,amount=amount,flag=flag or'',school=1,spellID=999,recordedHP=1,sourceName='Not verified'}end
local packet={source='UNIT_COMBAT:player',clock='GetTime',noticeAt=100,deadline=101,active=false,rows={
 receipt(2,100.45,'damage',650),receipt(1,100.4,'damage',895),receipt(3,101,'healing',20),receipt(4,100,'damage',0,'ABSORB')}}
local page={diedAt=100,native={rows={{nativeIndex=1,amount=895,spellID=123}}},liveIncoming={deathBoundary=packet}}
local late=M:LateIncoming(page)
check(late.valid and late.available and #late.rows==4 and not late.pending and not late.partial,'Late reports lost valid bounds or zero/exact-deadline receipts')
check(late.rows[1].kind=='absorbed'and late.rows[2].amount==895 and math.abs(late.rows[2].deliveryOffset-.4)<.000001,'Late report kind or delivery chronology changed')
check(late.rows[2].offset==nil and late.rows[2].spellID==nil and late.rows[2].sourceName==nil and late.rows[2].nativeIndex==nil and late.rows[2].recordedHP==nil,'Matching amount acquired a guessed spell/hit/health identity')
check(packet.rows[1].sequence==2 and packet.rows[4].kind=='damage'and page.native.rows[1].amount==895,'Projection rewrote original evidence')
packet.active=true;check(M:LateIncoming(page).pending,'Active delivery window was not visible as pending')
page.restored=true;late=M:LateIncoming(page);check(not late.pending and late.partial,'Restored interrupted window remained live or appeared complete')
page.restored=nil;packet.active=false;packet.deadline=100.25;packet.rows={receipt(1,100.1,'damage',10)}
check(#M:LateIncoming(page).rows==1,'Legacy quarter-second saved window became unreadable')
for key,value in pairs({noticeAt=99,deadline=101.1,source='Other',clock='Other'})do
 local old=packet[key];packet[key]=value;check(not M:LateIncoming(page).valid,'Unrelated identity, clock or out-of-bound window was trusted: '..key);packet[key]=old
end
packet.deadline=101
packet.rows={receipt(1,99.99,'damage',1),receipt(2,101.01,'damage',1),receipt(3,100.2,'damage',secret),receipt(4,100.2,'damage',-1),receipt(5,100.2,'unknown',1),receipt(.5,100.2,'damage',1)}
late=M:LateIncoming(page);check(not late.available and late.rejected==6,'Private, invalid or out-of-window report entered the projection')
packet.rows={}
for i=1,40 do packet.rows[i]=receipt(i,100+i/100,'damage',i)end
late=M:LateIncoming(page);check(#late.rows==32 and late.partial and late.rows[32].amount==32,'Late presentation exceeded its bound or hid truncation')
check(not M:LateIncoming(secret).valid and not M:LateIncoming({diedAt=100,liveIncoming={deathBoundary=secret}}).valid,'Opaque containers were indexed')
print('PASS: '..checks..' late-report clock, provenance, legacy-window, isolation and bounded-projection assertions')
