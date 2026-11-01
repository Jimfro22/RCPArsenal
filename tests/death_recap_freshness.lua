-- Actual recorder: independent fresh facts, immediate charge snapshots, and
-- receipt reconciliation. Offline fixtures do not certify native event order.
local f=assert(io.open('tests/death_recap.lua'));local prefix=f:read('*a');f:close()
prefix=prefix:sub(1,assert(prefix:find('check(optionalCount()==0',1,true))-1)
local helpers=[=[
local function pending()
 local found,count
 count=0
 for _,t in ipairs(timers)do if not t.cancelled and not t.repeating and t.delay==.1 then found=t;count=count+1 end end
 check(count<=1,'More than one coalesced observation was pending')
 return found,count
end
local function ticker()
 for i=#timers,1,-1 do if not timers[i].cancelled and timers[i].repeating then return timers[i]end end
end
local function freeze(id)
 dead=true;time=time+.01;event('PLAYER_DEAD')
 local page=R:GetPage()
 for _,row in ipairs(page.lastAlive.spells)do if row.spellID==(id or 871)then return row,page end end
 error('Expected tracked row was absent')
end
local function extra(id)
 RA.DeathRecapCatalog.entries[#RA.DeathRecapCatalog.entries+1]={key='extra'..id,spellID=id,name='Extra',class='WARRIOR',specs={73},knownSpellIDs={id},category='minor',verified=true}
end
]=]
local cases={}
local function add(name,body)cases[#cases+1]={name=name,body=body}end

for _,state in ipairs({'inactive','held','gcd-observed','active'})do
 add('fresh_or_retained_'..state,([=[
 charges={maxCharges=2,currentCharges=1,isActive=true}
 cooldown={isEnabled=%s,isActive=%s,isOnGCD=%s}
 combat=true;R:SetOption('enabled',true)
 time=11;event('SPELL_UPDATE_COOLDOWN',871)
 check(not pending(),'Fully observed direct callback scheduled redundant scalar reconciliation')
 local t=assert(ticker(),'Recharge/active state should retain the existing ticker')
 time=12;fire(t)
 local row=freeze()
 check(row.directCooldown and row.directCooldown.valid==true and row.directCooldown.observedAt==11 and row.directCooldown.cooldownAt==11,'Direct provenance was discarded, invalidated, or retimed')
 check(row.chargesAt==12 and row.currentCharges==1,'Independent fresh charge witness was not retained')
 %s
 ]=]):format(state=='held'and'false'or'true',(state=='inactive'or state=='held')and'false'or'true',state=='gcd-observed'and'true'or'false',
 (state=='inactive'or state=='held')and
 "check(row.cooldown=='"..state.."' and row.cooldownAt==12 and row.observedAt==12 and row.source=='interval' and row.isOnGCD==nil and row.cooldownGCDStatus=='not-event-context','Fresh independent cooldown fact inherited an old timestamp or event-only GCD')"or
 "check(row.cooldown=='"..state.."' and row.cooldownAt==11 and row.observedAt==11 and row.source=='retained-cooldown-event','Event-dependent interpretation was renewed by generic flags');check(row.genericCooldown and row.genericCooldown.observedAt==12 and row.genericCooldown.source=='interval','New generic observation provenance was lost')"))
end

add('targeted_charge_before_imminent_death',[=[
extra(999);local queries={};local chargeByID={[871]={maxCharges=2,currentCharges=0,isActive=false},[999]={maxCharges=2,currentCharges=2,isActive=false}}
C_Spell.GetSpellCharges=function(id)queries[#queries+1]=id;return chargeByID[id]end
combat=true;R:SetOption('enabled',true)
local n,bags,items=#queries,bagReads,itemCalls
chargeByID[871]={maxCharges=2,currentCharges=1,isActive=true};time=11;event('SPELL_UPDATE_COOLDOWN',871)
check(#queries==n+1 and queries[#queries]==871 and bagReads==bags and itemCalls==items,'Targeted callback queried unrelated identities or inventory')
check(not pending(),'Complete direct evidence queued a redundant scalar read')
local row,page=freeze()
check(row.currentCharges==1 and row.maxCharges==2 and row.chargesAt==11 and row.chargeQuery=='public' and not row.chargesPendingAt,'Death before a timer lost the newly readable count')
check(R:ClassifyRecordedCheck(row)==true,'Fresh positive charge count did not qualify independently of normal cooldown')
check(page.lastAlive.spells[2].chargesAt==10 and page.lastAlive.spells[2].currentCharges==2,'Targeted callback refreshed a different tracked spell')
]=])

local replacements={
 {name='nil',expression='nil',query='not_applicable',state='true'},
 {name='error',expression="error('charge query failed')",query='error',state='nil'},
 {name='secret_container',expression='secret',query='unreadable',state='nil'},
 {name='wrong_container',expression='42',query='malformed',state='nil'},
 {name='metatable_container',expression="setmetatable({},{__index=function()error('Malformed charge container indexed')end})",query='malformed',state='nil'},
 {name='secret_count',expression='{maxCharges=2,currentCharges=secret,isActive=true}',query='public',state='nil'},
 {name='fractional_count',expression='{maxCharges=2,currentCharges=.5,isActive=true}',query='public',state='nil'},
 {name='over_max_count',expression='{maxCharges=2,currentCharges=3,isActive=true}',query='public',state='nil'},
 {name='missing_max',expression='{currentCharges=1,isActive=true}',query='public',state='nil'},
 {name='secret_max',expression='{maxCharges=secret,currentCharges=1,isActive=true}',query='public',state='nil'},
}
for _,case in ipairs(replacements)do
 add('replace_charge_'..case.name,([=[
 charges={maxCharges=2,currentCharges=2,isActive=false};combat=true;R:SetOption('enabled',true)
 C_Spell.GetSpellCharges=function()return %s end
 time=11;event('SPELL_UPDATE_COOLDOWN',871)
 local row=freeze()
 check(row.currentCharges==nil and row.chargesAt==11 and row.chargeQuery=='%s' and not row.chargesPendingAt,'New charge result inherited a prior count or pending marker')
 check(R:ClassifyRecordedCheck(row)==%s,'Replacement result incorrectly granted or erased availability')
 ]=]):format(case.expression,case.query,case.state))
end
add('replace_charge_unsupported',[=[
charges={maxCharges=2,currentCharges=2,isActive=false};combat=true;R:SetOption('enabled',true)
C_Spell.GetSpellCharges=nil;time=11;event('SPELL_UPDATE_COOLDOWN',871)
local row=freeze()
check(row.currentCharges==nil and row.maxCharges==nil and row.chargesActive==nil and row.chargesAt==11 and row.chargeQuery=='unsupported' and not row.chargesPendingAt,'Unsupported query reused an old charge field')
check(R:ClassifyRecordedCheck(row)==nil,'Unsupported charge query became available')
]=])
add('fresh_charge_zero_and_held',[=[
charges={maxCharges=2,currentCharges=1,isActive=false};combat=true;R:SetOption('enabled',true)
charges={maxCharges=2,currentCharges=0,isActive=true};time=11;event('SPELL_UPDATE_COOLDOWN',871)
local row=freeze();check(row.currentCharges==0 and R:ClassifyRecordedCheck(row)==false,'Fresh zero count was discarded')
R:SetOption('enabled',false);dead=false;charges={maxCharges=2,currentCharges=1,isActive=false};cooldown={isEnabled=false,isActive=false};R:SetOption('enabled',true)
time=12;event('SPELL_UPDATE_COOLDOWN',871);row=freeze()
check(row.currentCharges==1 and row.cooldown=='held' and R:ClassifyRecordedCheck(row)==false,'Fresh charge count overrode held cooldown')
]=])

add('direct_identity_bounds',[=[
for id=1001,1032 do extra(id)end
local count,ids=0,{};C_Spell.GetSpellCharges=function(id)count=count+1;ids[id]=(ids[id]or 0)+1;return nil end
C_Spell.GetBaseSpell=function(id)return id==871 and 123 or id end
combat=true;R:SetOption('enabled',true);check(R:GetDiagnostics().trackedSpells==32,'Tracked catalog bound changed')
local before=count;time=11;event('SPELL_UPDATE_COOLDOWN',9999,9999)
check(count==before and not pending(),'Unmatched public identity queried charges or scheduled observation')
event('SPELL_UPDATE_COOLDOWN',9999,123)
check(count==before+1 and ids[871]==2,'Matching current base did not query only the selected identity')
event('SPELL_UPDATE_COOLDOWN',nil,secret)
check(count==before+33,'Refresh-all exceeded or missed bounded selected identities')
local snapshot=count;event('SPELL_UPDATE_COOLDOWN',secret,123)
check(count==snapshot and pending(),'Secret event identity was queried or failed conservative invalidation')
]=])

add('receipt_reconciliation_is_dirty_and_coalesced',[=[
extra(999);local queries={};C_Spell.GetSpellCharges=function(id)queries[#queries+1]=id;return nil end
combat=true;R:SetOption('enabled',true);check(not ticker() and not pending(),'Inactive baseline started polling')
local n=#queries;time=11;event('UNIT_SPELLCAST_SUCCEEDED','player','first',871)
local t=assert(pending(),'Accepted cast did not request a living follow-up check')
time=11.01;event('UNIT_SPELLCAST_SUCCEEDED','player','second',871)
check(pending()==t and #queries==n,'Repeated receipt created duplicate observation or queried synchronously')
time=11.1;fire(t)
check(#queries==n+1 and queries[#queries]==871 and not pending() and not ticker(),'Coalescer scanned a clean identity or created polling')
local row,page=freeze()
check(not row.pendingAt and row.source=='coalesced-events' and row.observedAt==11.1 and R:ClassifyRecordedCheck(row)==true,'Follow-up check did not reconcile the dirty identity')
check(#page.casts==2 and page.observedUses[871].observedCount==2,'Rapid separate cast receipts were collapsed')
]=])
add('unaccepted_receipts_no_work',[=[
combat=true;R:SetOption('enabled',true);local n=#timers;local before=R:GetDiagnostics().spellQueries
event('UNIT_SPELLCAST_SUCCEEDED','party1','cast',871)
event('UNIT_SPELLCAST_SUCCEEDED','player','cast',999999)
event('UNIT_SPELLCAST_SUCCEEDED','player','cast',secret)
check(#timers==n and R:GetDiagnostics().spellQueries==before and not pending() and not ticker(),'Rejected or unrelated receipt scheduled observations')
]=])
add('item_receipt_uses_existing_coalescer',[=[
bagIDs={5512};C_Item.GetItemCount=function()return 3 end;combat=true;R:SetOption('enabled',true)
local before=R:GetDiagnostics().spellQueries;local items=itemCalls
time=11;event('UNIT_SPELLCAST_SUCCEEDED','player','stone',6262);local t=assert(pending())
check(itemCalls==items,'Receipt synchronously queried item readiness')
time=11.1;fire(t)
check(itemCalls>items and R:GetDiagnostics().spellQueries==before and not pending(),'Item receipt failed to reconcile inventory or rechecked clean spells')
]=])
for _,boundary in ipairs({'death','disable','combat-end','new-session'})do
 add('pending_receipt_'..boundary,([=[
 combat=true;R:SetOption('enabled',true);time=11;event('UNIT_SPELLCAST_SUCCEEDED','player','cast',871)
 local t=assert(pending());local frozen
 %s
 local before=R:GetDiagnostics().spellQueries;local bags=bagReads;fire(t,true)
 check(R:GetDiagnostics().spellQueries==before and bagReads==bags,'Old receipt timer queried after a lifecycle boundary')
 if frozen then check(frozen.pendingAt==11 and R:ClassifyRecordedCheck(frozen)==nil,'Uncompleted follow-up invented availability before death')end
 ]=]):format(boundary=='death'and'frozen=freeze()'or boundary=='disable'and"R:SetOption('enabled',false)"or boundary=='combat-end'and"combat=false;event('PLAYER_REGEN_ENABLED')"or"time=12;event('PLAYER_REGEN_DISABLED')"))
end

local assertions=0
for _,case in ipairs(cases)do assertions=assertions+assert(loadstring(prefix..helpers..case.body..'\nreturn checks',case.name))()end
print('PASS: '..assertions..' freshness/charge/receipt assertions across '..#cases..' recorder scenarios (offline)')
