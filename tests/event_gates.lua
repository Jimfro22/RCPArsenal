-- Actual Core dispatch/subscriptions; no native performance or permission claim.
local checks=0
local function check(v,m) checks=checks+1;assert(v,m) end
local frame
UIParent={}
function CreateFrame()
    frame={events={},filters={},registrations=0,unregistrations=0}
    function frame:RegisterEvent(name)self.events[name]=true;self.filters[name]=nil;self.registrations=self.registrations+1 end
    function frame:RegisterUnitEvent(name,unit)self.events[name]=true;self.filters[name]=unit;self.registrations=self.registrations+1 end
    function frame:UnregisterEvent(name)self.events[name]=nil;self.filters[name]=nil;self.unregistrations=self.unregistrations+1 end
    function frame:SetScript(_,fn)self.event=fn end
    return frame
end
function issecretvalue(value)return type(value)=='table' and value.secret end
local RA={};assert(loadfile('RCPArsenal/Core.lua'))('RCPArsenal',RA)
local function emit(name,unit)
    if frame.events[name] and (not frame.filters[name] or frame.filters[name]==unit) then frame.event(frame,name,unit) end
end
local ordinary,optional=0,0
local base=frame.registrations
local sub=RA:RegisterOptionalEvent('UNIT_HEALTH',function()optional=optional+1 end,'player')
check(not frame.events.UNIT_HEALTH and frame.registrations==base,'Disabled subscription registered native traffic')
for i=1,100 do emit('UNIT_HEALTH','player') end
check(optional==0,'Disabled optional callback ran')
sub:SetEnabled(true)
check(frame.events.UNIT_HEALTH and frame.filters.UNIT_HEALTH=='player','Player-only native filter missing')
local registered=frame.registrations
sub:SetEnabled(true);check(frame.registrations==registered,'Unchanged demand reregistered event')
emit('UNIT_HEALTH','raid1');emit('UNIT_HEALTH','player')
check(optional==1,'Unit filter admitted raid traffic or lost player')
RA:RegisterEvent('UNIT_HEALTH',function()ordinary=ordinary+1 end)
check(frame.filters.UNIT_HEALTH==nil,'General subscriber inherited a restrictive unit filter')
emit('UNIT_HEALTH','raid1');check(ordinary==1 and optional==2,'Shared dispatch lost a subscriber')
sub:SetEnabled(false);emit('UNIT_HEALTH','player')
check(ordinary==2 and optional==2 and frame.events.UNIT_HEALTH,'Disabled optional entry removed shared event')
local only=RA:RegisterOptionalEvent('BAG_UPDATE_COOLDOWN',function()error('disabled callback executed')end)
only:SetEnabled(true);only:SetEnabled(false)
check(not frame.events.BAG_UPDATE_COOLDOWN,'Last disabled subscriber kept native event registered')
only:SetEnabled({secret=true});check(not frame.events.BAG_UPDATE_COOLDOWN,'Unknown demand enabled event')
-- Stable list when a callback disables another entry or itself mid-dispatch.
local first,second,third=0,0,0
local b,c
local a=RA:RegisterOptionalEvent('SYNTHETIC',function()first=first+1;b:SetEnabled(false)end)
b=RA:RegisterOptionalEvent('SYNTHETIC',function()second=second+1 end)
c=RA:RegisterOptionalEvent('SYNTHETIC',function()third=third+1;c:SetEnabled(false)end)
a:SetEnabled(true);b:SetEnabled(true);c:SetEnabled(true);emit('SYNTHETIC')
check(first==1 and second==0 and third==1,'In-dispatch disable skipped or invoked wrong subscriber')
a:SetEnabled(false);check(not frame.events.SYNTHETIC,'Self-disable left registration active')
local x=RA:RegisterOptionalEvent('UNIT_MAXHEALTH',function()end,'player')
local y=RA:RegisterOptionalEvent('UNIT_MAXHEALTH',function()end,'target')
x:SetEnabled(true);y:SetEnabled(true);check(frame.filters.UNIT_MAXHEALTH==nil,'Different units were incorrectly narrowed')
y:SetEnabled(false);check(frame.filters.UNIT_MAXHEALTH=='player','Remaining sole player filter did not restore')
x:SetEnabled(false);check(not frame.events.UNIT_MAXHEALTH,'Player event did not stop')
print('PASS: '..checks..' event demand assertions (actual Core; native dispatch pending)')
