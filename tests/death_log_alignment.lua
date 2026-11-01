-- Offline approximate presentation alignment; no native clock-synchronization
-- or event-causality claim. The helper may inspect only frozen public evidence.
local checks=0;local function check(value,message)checks=checks+1;assert(value,message)end
local secret=setmetatable({},{__tostring=function()error('Secret formatted')end,__index=function()error('Secret indexed')end})
function issecretvalue(value)return rawequal(value,secret)end
local liveReads=0
local function Forbidden()liveReads=liveReads+1;error('Alignment read live state or scheduled work')end
GetTime,UnitGUID=Forbidden,Forbidden
C_Spell={GetSpellCooldown=Forbidden,GetSpellCharges=Forbidden,GetSpellTexture=Forbidden}
C_Item={GetItemCooldown=Forbidden,GetItemCount=Forbidden}
C_DeathRecap={GetRecapEvents=Forbidden};C_Timer={NewTimer=Forbidden,NewTicker=Forbidden,After=Forbidden}
local RA={};assert(loadfile('RCPArsenal/DeathLogModel.lua'))('RCPArsenal',RA)
local M=RA.DeathLogModel
local function Near(a,b)return type(a)=='number'and math.abs(a-b)<1e-9 end
local function Receipt(time,id,source)
    return {observedAt=time,spellID=id or 235450,source=source or'UNIT_SPELLCAST_SUCCEEDED',name='Captured use'}
end
local function Page()
    return {id=10,captureGeneration=20,diedAt=100,localSessionStartedAt=60,
        casts={Receipt(97.7)},lastAlive={spells={{cooldown='unknown'}}},observedUses={[235450]={observedCount=1}},
        native={recapID=50,rows={{nativeIndex=1,timestamp=500,nativeOffset=0}},clockDiagnostic={
            localClock='GetTime',localDeathNoticeAt=100,localSessionStartedAt=60,
            nativeFatalTimestamp=500,nativeMaximumTimestamp=500,nativeRowCount=1}}}
end
local function Copy(value)
    if type(value)~='table'or rawequal(value,secret)then return value end
    local out={};for key,item in pairs(value)do out[key]=Copy(item)end;return out
end
local function Equal(a,b)
    if rawequal(a,secret)or rawequal(b,secret)then return rawequal(a,b)end
    if type(a)~='table'or type(b)~='table'then return a==b or type(a)=='number'and type(b)=='number'and a~=a and b~=b end
    for key,value in pairs(a)do if not Equal(value,b[key])then return false end end
    for key in pairs(b)do if a[key]==nil then return false end end
    return true
end
local function Run(page)
    local before=Copy(page);local result=M:AlignUses(page)
    check(Equal(page,before),'Alignment changed raw capture, readiness or use history')
    check(result.approximate==true and type(result.aligned)=='table'and type(result.unaligned)=='table','Alignment omitted approximate provenance or split results')
    check(result.examined<=64 and #result.aligned+#result.unaligned==result.examined,'Alignment exceeded bounded ring or lost a receipt')
    for _,entry in ipairs(result.unaligned)do check(type(entry.reason)=='string'and not entry.reason:find('|',1,true),'Unaligned result omitted a safe static reason')end
    return result
end
local page=Page();local result=Run(page)
check(result.anchorValid and not result.reason and #result.aligned==1 and #result.unaligned==0,'Complete matching frozen anchor rejected')
check(result.aligned[1].row==page.casts[1]and result.aligned[1].index==1 and result.aligned[1].approximate and Near(result.aligned[1].age,2.3)and Near(result.aligned[1].offset,-2.3),'97.7/100 receipt did not align approximately to -2.3')
page.native.rows[2]={nativeIndex=2,timestamp=500.2,nativeOffset=0};page.native.rows[1].nativeOffset=-.2
page.native.clockDiagnostic.nativeMaximumTimestamp=500.2;page.native.clockDiagnostic.nativeRowCount=2
result=Run(page);check(Near(result.aligned[1].offset,-2.5)and Near(result.aligned[1].age,2.3),'Fatal-to-maximum delta was omitted or local age changed')
page.casts={Receipt(97.7),Receipt(97.7),Receipt(70),Receipt(100)}
result=Run(page)
check(#result.aligned==4 and result.aligned[1].row~=result.aligned[2].row and result.aligned[1].offset==result.aligned[2].offset,'Repeated receipts were deduplicated')
check(Near(result.aligned[3].age,30)and Near(result.aligned[3].offset,-30.2)and Near(result.aligned[4].offset,-.2),'Inclusive30s/death boundaries were lost or offscreen offset was clamped')

local badAnchors={
 function(p)p.native=nil end,
 function(p)p.native.recapID=nil end,
 function(p)p.native.recapID=0 end,
 function(p)p.native.recapID=-1 end,
 function(p)p.native.recapID=.5 end,
 function(p)p.native.recapID=secret end,
 function(p)p.native.clockDiagnostic=nil end,
 function(p)p.native.clockDiagnostic.localClock='GetTimePreciseSec' end,
 function(p)p.native.clockDiagnostic.localClock=secret end,
 function(p)p.diedAt=nil end,
 function(p)p.diedAt=math.huge end,
 function(p)p.localSessionStartedAt=nil end,
 function(p)p.localSessionStartedAt=101 end,
 function(p)p.native.clockDiagnostic.localDeathNoticeAt=99 end,
 function(p)p.native.clockDiagnostic.localSessionStartedAt=59 end,
 function(p)p.native.clockDiagnostic.localDeathNoticeAt=secret end,
 function(p)p.native.clockDiagnostic.nativeFatalTimestamp=nil end,
 function(p)p.native.clockDiagnostic.nativeMaximumTimestamp=secret end,
 function(p)p.native.clockDiagnostic.nativeMaximumTimestamp=0/0 end,
 function(p)p.native.clockDiagnostic.nativeFatalTimestamp=math.huge end,
 function(p)p.native.clockDiagnostic.nativeFatalTimestamp=501 end,
 function(p)p.native.clockDiagnostic.nativeFatalTimestamp=499 end,
 function(p)p.native.clockDiagnostic.nativeMaximumTimestamp=501 end,
 function(p)p.native.rows={} end,
 function(p)p.native.rows=secret end,
 function(p)p.native.rows[1]=secret end,
 function(p)p.native.rows[1].timestamp=nil end,
 function(p)p.native.rows[1].timestamp=secret end,
 function(p)p.native.rows[1].nativeIndex=secret end,
 function(p)p.native.rows[1].nativeIndex=2 end,
 function(p)p.native.rows[3]={nativeIndex=3,timestamp=500};p.native.clockDiagnostic.nativeRowCount=3 end,
 function(p)p.native.rows[2]={nativeIndex=1,timestamp=500};p.native.clockDiagnostic.nativeRowCount=2 end,
 function(p)p.native.clockDiagnostic.nativeRowCount=2 end,
 function(p)p.native.clockDiagnostic.nativeRowCount=secret end,
 function(p)for i=2,65 do p.native.rows[i]={nativeIndex=i,timestamp=500}end;p.native.clockDiagnostic.nativeRowCount=65 end,
}
for index,change in ipairs(badAnchors)do
    page=Page();change(page);result=Run(page)
    check(not result.anchorValid and type(result.reason)=='string'and #result.aligned==0 and #result.unaligned==1,'Missing/stale/nonfinite anchor silently aligned a use: '..index)
    check(result.unaligned[1].offset==nil,'Failed anchor fell back to a zero/native offset')
end
page=Page();page.native.clockDiagnostic.nativeRowCount=nil
check(Run(page).anchorValid,'Optional missing diagnostic row count rejected otherwise verifiable raw anchors')
page=Page();page.native.clockDiagnostic.nativeFatalTimestamp=-1e308;page.native.clockDiagnostic.nativeMaximumTimestamp=1e308
page.native.rows={{nativeIndex=1,timestamp=-1e308},{nativeIndex=2,timestamp=1e308}};page.native.clockDiagnostic.nativeRowCount=2
check(not Run(page).anchorValid,'Overflowing finite-anchor subtraction produced an aligned infinity')

page=Page();page.casts={Receipt(59),Receipt(100.1),Receipt(69.999),Receipt(98,1,'DERIVED_FROM_AGGREGATE_ENDPOINT'),Receipt(98,1,'UNIT_SPELLCAST_START'),Receipt(98,0),Receipt(secret),secret}
result=Run(page)
check(result.anchorValid and #result.aligned==0 and #result.unaligned==8,'Invalid source/time/identity receipt became an aligned use')
check(result.unaligned[1].reason=='use-outside-session'and result.unaligned[3].reason=='use-outside-retained-window'and result.unaligned[4].reason=='unverified-use-source','Rejection reasons lost their actual evidence boundary')
check(result.unaligned[8].row==nil,'Restricted receipt container escaped through an unaligned row')
page=Page();page.casts={};for i=1,70 do page.casts[i]=Receipt(90+i/100,235450)end
result=Run(page)
check(result.truncated and result.examined==64 and #result.aligned==64 and result.aligned[1].index==7 and result.aligned[64].index==70,'Alignment did not match the newest retained64-receipt ring')
check(result.aligned[1].row==page.casts[7]and result.aligned[64].row==page.casts[70],'Receipt ring indices were rewritten')
page=Page();page.casts=secret;result=Run(page)
check(result.examined==0 and #result.aligned==0,'Restricted receipt container was enumerated')
result=M:AlignUses(secret);check(not result.anchorValid and result.reason=='page-unavailable'and result.examined==0,'Restricted page was inspected')
local trust=issecretvalue;issecretvalue=nil;result=M:AlignUses(Page())
check(not result.anchorValid and #result.aligned==0,'Absent public-value checker permitted alignment')
issecretvalue=function()error('Trust check failed')end;result=M:AlignUses(Page())
check(not result.anchorValid and #result.aligned==0,'Failed public-value check permitted alignment');issecretvalue=trust
check(liveReads==0,'Pure alignment invoked a native state/artwork query or scheduler')
print('PASS: '..checks..' approximate frozen-use alignment, anchor validity, privacy, bounds and immutability assertions')
