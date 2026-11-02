-- Native sink wiring, not a simulation of private WoW renderer predicates.
local f=assert(io.open('tests/death_recap.lua'));local prefix=f:read('*a');f:close()
prefix=prefix:sub(1,assert(prefix:find('check(optionalCount()==0',1,true))-1)
assert(loadstring(prefix..[=[
combat=true;charges={maxCharges=2,currentCharges=secret,isActive=true};R:SetOption('enabled',true)
dead=true;time=11;event('PLAYER_DEAD');local page=R:GetPage();local row=R:GetCooldownRows(page)[1]
local calls=0;local bar={SetValue=function(_,v)calls=calls+1;check(rawequal(v,secret),'Secret count was altered before the native status-bar sink')end}
check(R:GetRecordedNativeStatusKind(row)=='charge'and R:BindRecordedChargeStatus(bar,row)and calls==1,'Frozen private charge witness did not reach native sink')
check(row.recordedState==nil and row.currentCharges==nil,'Native rendering exposed a private count/state to public Lua')
row.pendingAt=11;check(not R:GetRecordedNativeStatusKind(row)and not R:BindRecordedChargeStatus(bar,row),'Pending charge state was rendered');row.pendingAt=nil
row.coverageEndedAt=11;check(not R:BindRecordedChargeStatus(bar,row),'Ended coverage rendered stale private count');row.coverageEndedAt=nil
check(not R:BindRecordedChargeStatus({SetValue=function()error('native refusal')end},row),'Native refusal escaped')
check(not R:GetRecordedNativeStatusKind(RA.DeathRecapHistory:Snapshot(page).lastAlive.spells[1]),'Private charge state survived serialization')
R:SetOption('enabled',false);dead=false;combat=true;time=20;charges=nil
cooldown={isEnabled=true,isActive=true}
local durations=setmetatable({},{__mode='v'})
C_Spell.GetSpellCooldownDuration=function(_,ignore)
 check(ignore==true,'Private predicate query included the GCD')
 local u=newproxy(true);getmetatable(u).__index={IsActive=function()return secret end,IsZero=function()return false end}
 durations[#durations+1]=u;return u
end
R:SetOption('enabled',true);dead=true;time=20.1;event('PLAYER_DEAD');page=R:GetPage();row=R:GetCooldownRows(page)[1]
local function layer()
 local parent={};parent.glyph={}
 function parent:SetAlphaFromBoolean(value,a,b)check(rawequal(value,secret),'Active predicate was compared or converted');self.args={a,b}end
 function parent.glyph:SetAlphaFromBoolean(value,a,b)check(value==false,'Zero predicate changed');self.args={a,b}end
 return parent
end
local ready,unready=layer(),layer()
check(R:GetRecordedNativeStatusKind(row)=='cooldown'and R:BindRecordedCooldownStatus(ready,unready,row),'Mirror-style frozen ignore-GCD predicates did not reach native alpha sinks')
check(ready.args[1]==0 and ready.glyph.args[1]==1 and unready.args[1]==1 and unready.glyph.args[1]==0,'Ready/unready native predicate gates overlap or reverse')
check(row.recordedState==nil and row.ownCooldownActive==nil,'Private cooldown predicate escaped into public classification')
collectgarbage('collect');check(next(durations)==nil,'Native presentation retained a ticking duration object')
check(not R:GetRecordedNativeStatusKind(RA.DeathRecapHistory:Snapshot(page).lastAlive.spells[1]),'Private booleans survived serialization')
row.pendingAt=21;check(not R:BindRecordedCooldownStatus(ready,unready,row),'Pending cooldown predicate rendered');row.pendingAt=nil
local failed=layer();failed.SetAlphaFromBoolean=function()error('refused')end
function failed:Hide()self.hidden=true end;function unready:Hide()self.hidden=true end
check(not R:BindRecordedCooldownStatus(failed,unready,row)and failed.hidden and unready.hidden,'Partial predicate failure left a misleading overlay')
print('PASS: '..checks..' frozen private charge/cooldown native-sink and serialization assertions; native pixels unverified')
]=]))()
