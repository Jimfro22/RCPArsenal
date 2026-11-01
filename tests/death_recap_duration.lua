local f=assert(io.open('tests/death_recap.lua'));local prefix=f:read('*a');f:close();prefix=prefix:sub(1,assert(prefix:find('check(optionalCount()==0',1,true))-1)
local total=0
for _,case in ipairs({{false,true,true},{true,false,false},{false,false,'unknown'},{true,true,'unknown'},{'secret',false,'unknown'},{false,'secret','unknown'},{'nil',true,'unknown'},{true,'error','unknown'}})do
 DURATION_CASE=case
 total=total+assert(loadstring(prefix..[=[
combat=true;R:SetOption('enabled',true)
local case=DURATION_CASE;local calls,predicates=0,0;local objects=setmetatable({},{__mode='v'})
local function result(v)if v=='secret'then return secret elseif v=='nil'then return nil elseif v=='error'then error('predicate')end;return v end
C_Spell.GetSpellCooldownDuration=function(id,ignore)
 calls=calls+1;check(id==871 and ignore==true,'Fallback queried wrong identity/flag')
 local u=newproxy(true);getmetatable(u).__index={IsActive=function()predicates=predicates+1;return result(case[1])end,IsZero=function()predicates=predicates+1;return result(case[2])end}
 objects[#objects+1]=u;return u
end
cooldown={isEnabled=true,isActive=true};time=11;event('SPELL_UPDATE_COOLDOWN',871)
check(calls==1 and predicates==2,'Fallback did not read each immediate predicate exactly once')
dead=true;time=11.01;event('PLAYER_DEAD');local row=R:GetPage().lastAlive.spells[1]
local expected=case[3];if expected=='unknown'then expected=nil end
check(R:ClassifyRecordedCheck(row)==expected,'Opaque/conflicting duration or public false was misclassified')
check(row.ownCooldownAt==11 and row.ownCooldownSource=='ignoreGCD-duration','Fresh scalar source/time missing')
collectgarbage('collect');check(next(objects)==nil,'Duration userdata was retained')
return checks
]=]))()
end
for _,mode in ipairs({'held','charges','positive-charge','nil','table','secret','error'})do
 DURATION_MODE=mode
 total=total+assert(loadstring(prefix..[=[
combat=true;R:SetOption('enabled',true);local calls=0
C_Spell.GetSpellCooldownDuration=function()
 calls=calls+1
 if DURATION_MODE=='error'then error('factory')elseif DURATION_MODE=='secret'then return secret elseif DURATION_MODE=='table'then return{}end
 return nil
end
cooldown={isEnabled=true,isActive=true}
if DURATION_MODE=='held'then cooldown.isEnabled=false
elseif DURATION_MODE=='charges'then charges={maxCharges=2,currentCharges=secret,isActive=true}
elseif DURATION_MODE=='positive-charge'then charges={maxCharges=2,currentCharges=1,isActive=true}end
time=11;event('SPELL_UPDATE_COOLDOWN',871)
local expected=(DURATION_MODE=='held'or DURATION_MODE=='charges'or DURATION_MODE=='positive-charge')and 0 or 1
check(calls==expected,'Fallback crossed held/charge boundary or missed eligible ambiguous query')
dead=true;time=11.01;event('PLAYER_DEAD');local row=R:GetPage().lastAlive.spells[1]
if DURATION_MODE=='held'then check(R:ClassifyRecordedCheck(row)==false,'Held lost negative fact')
elseif DURATION_MODE=='positive-charge'then check(R:ClassifyRecordedCheck(row)==true,'Fresh positive charge count lost')
else check(R:ClassifyRecordedCheck(row)==nil,'Factory/known-charge unknown became available')end
return checks
]=]))()
end
print('PASS: '..total..' guarded production duration assertions;15 scenarios')
