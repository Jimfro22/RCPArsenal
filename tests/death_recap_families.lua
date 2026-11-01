local f=assert(io.open('tests/death_recap.lua'));local source=f:read('*a');f:close()
source=source:sub(1,assert(source:find('check(optionalCount()==0',1,true))-1)
source=source..[=[
local function family(rows,ended)
    local page={lastAlive={supplies=rows,coverageEndedAt=ended}}
    local before=R:GetDiagnostics();local n=#timers
    local result=R:GetSupplyFamilies(page)
    check(#result==2 and result[1].kind=='stone'and result[2].kind=='potion','Family shelf changed fixed family count/order')
    local after=R:GetDiagnostics();check(after.itemQueries==before.itemQueries and after.spellQueries==before.spellQueries and #timers==n,'Frozen family view queried or scheduled work')
    return result[1],result[2]
end
local a={kind='potion',itemID=1,physicalCount=1,remainingUses=1,cooldown='inactive',observedAt=90,carriedAt=50,icon=100}
local b={kind='potion',itemID=2,physicalCount=1,remainingUses=1,cooldown='active',observedAt=95,icon=200}
local c={kind='potion',itemID=3,cooldown='unknown',observedAt=99,partial=true}
local stone,potion=family({a,b,c})
check(stone.familyState==nil and potion.familyState==true and #potion.members==3,'Mixed positive family lost evidence or empty family became absent')
check(potion.representativeItemID==1 and potion.icon==100 and not potion.physicalCount and not potion.remainingUses and not potion.cooldown,'Representative facts became family totals')
check(potion.observedAt==90 and potion.latestObservedAt==99 and potion.members[1].row.carriedAt==50,'Aggregation refreshed old bag/check times')
stone,potion=family({b,c});check(potion.familyState==nil,'Unknown alternative became unavailable')
stone,potion=family({b});check(potion.familyState==false,'Complete negative family lost negative state')
b.partial=true;stone,potion=family({b});check(potion.familyState==nil,'Incomplete negative family became unavailable');b.partial=nil
stone,potion=family({{kind='stone',familyAbsenceVerified=true,partial=true,carriedAt=50},c})
check(stone.familyState==false and potion.familyState==nil,'Verified family absence was erased by other-family uncertainty')
stone,potion=family({a},100);check(potion.familyState==nil,'Ended coverage became available')
a.pendingAt=96;stone,potion=family({a});check(potion.familyState==nil,'Pending item became available');a.pendingAt=nil
a.physicalCount=0;stone,potion=family({a});check(potion.familyState==nil,'Conflicting stock was converted to zero/positive');a.physicalCount=1
-- Restricted charge state must never use inactive normal CD as availability.
check(R:ClassifyRecordedCheck({cooldown='inactive',chargeQuery='unreadable',chargeReason='restricted'})==nil,'Restricted charges became ready')
check(R:ClassifyRecordedCheck({cooldown='inactive',chargeQuery='not_applicable'})==true,'Established noncharge inactive fact was lost')
check(R:ClassifyRecordedCheck({cooldown='active-context-unknown',chargeQuery='not_applicable'})==nil,'Generic active fact became own-CD unavailable')
-- Native swing display mapping preserves original spell metadata and index.
R:SetOption('enabled',true);event('DAMAGE_METER_CURRENT_SESSION_UPDATED');event('DAMAGE_METER_COMBAT_SESSION_UPDATED',9,1)
combat=true;event('PLAYER_REGEN_DISABLED');meterRows={{isLocalPlayer=true,deathRecapID=1}}
events={{timestamp=80,event='SWING_DAMAGE',spellId=123,spellName='Wrong raw name',amount=5},{timestamp=90,event='SPELL_DAMAGE',spellId=124,amount=100}}
dead=true;event('PLAYER_DEAD');local packet=R:GetPage().native
check(packet.rows[1].spellID==88163 and packet.rows[1].name=='Melee'and packet.rows[1].rawSpellID==123 and packet.rows[1].rawSpellName=='Wrong raw name','Swing presentation replaced/lost raw identity')
check(packet.rows[1].nativeIndex==1 and packet.rows[1].nativeOffset==-10 and packet.rows[2].nativeOffset==0,'Melee correction changed fatal/latest-time distinction')
print('PASS: '..checks..' frozen family aggregation, charge uncertainty and native melee assertions')
]=]
assert(loadstring(source,'death-recap-family-fixture'))()
