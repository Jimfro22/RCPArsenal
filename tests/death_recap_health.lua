-- Run the actual recorder with a fresh explicit personal-recap association for
-- every denominator case. Offline field guards do not prove native availability.
local f=assert(io.open('tests/death_recap.lua'));local fixture=f:read('*a');f:close()
fixture=fixture:sub(1,assert(fixture:find("check(optionalCount()==0",1,true))-1)
local run=fixture..[=[
local maxReads=0
local maxValues={1000,false,secret,0,-1,0/0,math.huge,-math.huge,'1000',{}}
local maximum=maxValues[HP_CASE]
C_DeathRecap.GetRecapMaxHealth=function(id)
    maxReads=maxReads+1;check(id==1,'HP denominator queried a default/foreign recap');return maximum
end
if HP_CASE==12 then C_DeathRecap.GetRecapMaxHealth=nil end
R:SetOption('enabled',true)
event('DAMAGE_METER_CURRENT_SESSION_UPDATED');event('DAMAGE_METER_COMBAT_SESSION_UPDATED',9,1)
combat=true;event('PLAYER_REGEN_DISABLED');dead=true;time=12;event('PLAYER_DEAD')
check(maxReads==0,'HP queried before explicit own identity accepted')
meterRows={{isLocalPlayer=true,deathRecapID=1}};link='death:1'
local hpValues={0,750,1200,false,secret,-1,0/0,math.huge,-math.huge,'750',{}}
events={}
for i,value in ipairs(hpValues)do
    events[i]={destGUID='Player-self',timestamp=100-i,event='SPELL_DAMAGE',spellId=100+i,amount=50,currentHP=value}
end
-- nil HP is still an otherwise good damage row.
events[#events+1]={destGUID='Player-self',timestamp=80,event='SPELL_DAMAGE',spellId=112,amount=50}
fire(timers[#timers]);local page=R:GetPage()
check(page.native and page.native.recapID==1 and #page.native.rows==12,'HP field rejected a valid damage row/record')
check(maxReads==(HP_CASE==12 and 0 or 1),'HP denominator getter availability/call bound failed')
check(page.native.recapMaxHealth==(HP_CASE==1 and 1000 or nil),'Invalid max became a stored denominator')
for i,row in ipairs(page.native.rows)do
    check(row.recordedHP==(i<=3 and hpValues[i] or nil),'Invalid/missing HP became zero, opaque, or inferred')
    check(row.amount==50 and row.nativeOffset==row.timestamp-99,'HP extension changed damage/native clock')
    check(row.currentHP==nil and row.healthPercent==nil,'Opaque source or derived percentage retained')
end
check(page.native.rows[1].recordedHP==0 and page.native.rows[3].recordedHP==1200,'Raw zero/out-of-scale HP lost independently of max')
R:SetOption('enabled',false)
print('PASS: '..checks..' explicit native health field-guard assertions (case '..HP_CASE..'; offline)')
]=]
for i=1,12 do HP_CASE=i;assert(loadstring(run,'death-recap-health-case-'..i))()end
HP_CASE=nil
