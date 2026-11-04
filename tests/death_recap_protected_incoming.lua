-- Private storage/native sink contract. Opaque proxies are not WoW secrets.
local checks=0;local function check(value,message)checks=checks+1;assert(value,message)end
local secret=newproxy(true);local function forbidden()error('Opaque amount inspected')end
for _,name in ipairs({'__tostring','__eq','__lt','__le','__add','__sub','__mul','__div','__concat','__index'})do getmetatable(secret)[name]=forbidden end
function issecretvalue(v)return rawequal(v,secret)end
function UnitHealthMax()return 850900 end
local callbacks={};local RA={RegisterCallback=function(_,key,fn)callbacks[key]=fn end}
assert(loadfile('RCPArsenal/DeathRecapProtectedIncoming.lua'))('RCPArsenal',RA)
local I=RA.DeathRecapProtectedIncoming
local function clean(v)
 check(not issecretvalue(v),'Raw protected input escaped private storage')
 if type(v)=='table'then for k,x in pairs(v)do clean(k);clean(x)end end
end
check(I:Describe({})==nil,'Empty module invented a capture')
I:PrepareReference();I:Begin(10)
I:Capture(9,'WOUND','',secret,1);I:Capture(11,'BLOCK','',secret,1)
I:Capture(11,'WOUND','',-1,1);I:Capture(11,'HEAL','',0/0,1)
I:Capture(11,'WOUND','',secret,1);I:Capture(12,'HEAL','CRITICAL',secret,1);I:Capture(12.1,'WOUND','',123,64)
local page={};local summary=I:Freeze(page,13);local view=I:Describe(page)
check(summary.retained==3 and summary.protected==2 and not summary.partial,'Mixed capture/filter summary wrong')
check(view.damageCount==2 and view.healingCount==1 and view.rows[2].flag=='CRITICAL','Public projection lost kind/order')
clean(summary);clean(view);check(next(page)==nil,'Private packet attached to saved page')
view.rows[1].sequence=900;check(I:Describe(page).rows[1].sequence==1,'Public projection mutated private receipt')
local bar={SetMinMaxValues=function(self,lo,hi)check(lo==0 and hi==850900,'Unstable reference');end,
 SetValue=function(self,value)self.input=value end,GetValue=forbidden}
local label={SetFormattedText=function(self,format,value)check(format=='%d','Changed native formatting');self.input=value end,GetText=forbidden}
local b,t=I:Paint(page,2,bar,label)
check(b and t and rawequal(bar.input,secret)and rawequal(label.input,secret)and label.__raNativeText,'Protected inputs changed before native sinks')
check(not I:Paint(page,999,bar,label),'Missing sequence used another receipt')
page.diedAt=13
check(I:CaptureLate(page,13.1,'WOUND','',secret,1).protected==1,'Protected late receipt was discarded')
I:CaptureLate(page,13.2,'HEAL','',7,1)
local late=I:DescribeLate(page);clean(late)
check(#late.rows==2 and late.rows[1].offset>0 and late.rows[2].kind=='healing','Late receipts lost delivery times or public members')
I:PaintLate(page,1,label);check(rawequal(label.input,secret),'Late amount changed before native sink')
check(#I:Describe(page).rows==3,'Late receipt entered pre-notice history')
I:CaptureLate(page,14.01,'WOUND','',secret,1);check(#I:DescribeLate(page).rows==2,'Late capture exceeded one-second boundary')
for n=1,40 do I:CaptureLate(page,13.3,'WOUND','',secret,1)end
check(#I:DescribeLate(page).rows==32 and I:DescribeLate(page).partial,'Late capture exceeded its cap or hid loss')
I:Begin(20);I:Capture(21,'WOUND','',22,1);check(I:Freeze({},22)==nil,'Public-only capture replaced arithmetic path')
check(I:Describe(page)~=nil,'New fight erased earlier death')
I:Begin(30);for n=1,300 do I:Capture(30+n/1000,'WOUND','',secret,1)end
local busy={};summary=I:Freeze(busy,31);check(summary.retained==256 and summary.partial,'Busy capture bounds/loss flag wrong')
I:Begin(40);for n=1,300 do I:Capture(40+n/1000,'WOUND','',secret,1)end
I:Capture(60,'HEAL','',secret,1);local sparse={};summary=I:Freeze(sparse,61)
check(summary.retained==1 and not summary.partial,'Old overflow mislabeled final eight seconds')
I:Prune({busy,sparse});check(I:Describe(page)==nil and I:Describe(busy)~=nil,'Public-only deaths could leave evicted private history alive')
check(I:DescribeLate(page)==nil,'Evicted death retained private late amounts')
for n=1,5 do I:Begin(100+n);I:Capture(101+n,'HEAL','',secret,1);I:Freeze({},102+n)end
check(I:Describe(page)==nil and I:Describe(busy)==nil,'More than five deaths retained opaque amounts')
I:Begin(200);I:Capture(201,'WOUND','',secret,1);I:Cancel();check(I:Freeze({},202)==nil,'Cancelled capture survived')
callbacks.PROFILE_RESET();check(I:Describe(sparse)==nil,'Profile reset retained private amounts')
print('PASS: '..checks..' opaque incoming storage, projection, sinks, bounds and lifecycle assertions')
