-- Production pooled badge painter, with explicit public native-region models.
-- Secret predicate preservation and real fill pixels require the client test.
local function Read(path)local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local source=Read('tests/hub.lua');source=source:sub(1,assert(source:find('check(db.schemaVersion == 19',1,true))-1)
local ui=Read('tests/death_recap_ui.lua');local marker='source=source..[=[';local start=assert(ui:find(marker,1,true))+#marker
source=source..ui:sub(start,assert(ui:find('local groupCalls=',start,true))-1)
source=source..[=[
function methods:SetMinMaxValues(a,b)self.min,self.max=a,b end
function methods:SetStatusBarTexture(path)self.fill=self:CreateTexture(nil,'ARTWORK');self.fill:SetTexture(path)end
function methods:GetStatusBarTexture()return self.fill end
function methods:SetStatusBarColor(...)self.barColor={...}end
function methods:SetAlphaFromBoolean(value,a,b)check(type(value)=='boolean','UI model was given an opaque predicate');self:SetAlpha(value and a or b)end
local rawSet=methods.SetValue
function methods:SetValue(value)rawSet(self,value);if self.fill then self.fillFraction=math.max(0,math.min(1,value))end end
local b=CreateFrame('Button',nil,UIParent);b.icon=b:CreateTexture(nil,'ARTWORK')
local kind,bindCount
R.GetRecordedNativeStatusKind=function()return kind end
R.BindRecordedChargeStatus=function(_,bar,row)
 if kind~='charge'then return false end
 bindCount=(bindCount or 0)+1;bar:SetValue(row.count);return true
end
R.BindRecordedCooldownStatus=function(_,ready,unready,row)
 if kind~='cooldown'then return false end
 ready:SetAlphaFromBoolean(row.active,0,1);ready.glyph:SetAlphaFromBoolean(row.zero,1,0)
 unready:SetAlphaFromBoolean(row.active,1,0);unready.glyph:SetAlphaFromBoolean(row.zero,0,1);return true
end
kind='charge'
for _,count in ipairs({0,1,2})do
 U:PaintCooldownStatus(b,b.icon,nil,{count=count})
 check(not b.info:IsShown()and b.nativeStatus.charge:IsShown()and not b.nativeStatus.ready:IsShown()and not b.nativeStatus.unready:IsShown(),'Charge badge retained numeric/question text or a stray cooldown overlay')
 check(b.nativeStatus.charge.min==0 and b.nativeStatus.charge.max==1 and b.nativeStatus.charge.fillFraction==(count>0 and 1 or 0),'Zero/one/multiple-charge fill does not distinguish none versus some')
 check(b.nativeStatus.charge.check.allPoints==b.nativeStatus.charge.fill and b.statusLines[1]:IsShown(),'Green charge badge is not native-fill anchored or its zero-charge X is absent')
end
kind='cooldown'
for _,pair in ipairs({{false,true},{true,false},{false,false},{true,true}})do
 U:PaintCooldownStatus(b,b.icon,nil,{active=pair[1],zero=pair[2]})
 local n=b.nativeStatus
 check(not n.charge:IsShown()and n.ready:IsShown()and n.unready:IsShown()and b.info:IsShown(),'Cooldown predicates retained charge overlay or lost neutral fallback')
 local green=n.ready.alpha*n.ready.glyph.alpha;local red=n.unready.alpha*n.unready.glyph.alpha
 check(green==(not pair[1]and pair[2]and 1 or 0)and red==(pair[1]and not pair[2]and 1 or 0),'Conflicting predicates acquired a check/X or consistent predicates reversed')
end
kind=nil;U:PaintCooldownStatus(b,b.icon,nil,{})
check(b.info:IsShown()and b.info.text=='?'and not b.nativeStatus.ready:IsShown()and not b.nativeStatus.unready:IsShown(),'Recycled unsupported row retained private presentation')
for _,state in ipairs({false,true})do
 U:PaintCooldownStatus(b,b.icon,state,{})
 check(not b.info:IsShown()and not b.nativeStatus.charge:IsShown()and not b.nativeStatus.ready:IsShown()and not b.nativeStatus.unready:IsShown(),'Public state reused a private overlay')
end
check(bindCount==3 and b.recordedState==true,'Badge painting changed public state or rebound unrelated charges')
io.write('PASS: '..checks..' pooled native badge drawing/zero/one/multiple/conflict/recycle assertions; native pixels unverified\n')
]=]
assert(loadstring(source,'native-status-ui-fixture'))()
