-- Actual recorder, frozen projection and persistence. Synthetic public/opaque
-- values exercise our logic; native combat timing still needs an in-game check.
local file=assert(io.open('tests/death_recap.lua'));local prefix=file:read('*a');file:close()
prefix=prefix:sub(1,assert(prefix:find('check(optionalCount()==0',1,true))-1)
local helpers=[=[
local function freeze()
 dead=true;time=time+.01;event('PLAYER_DEAD');return assert(R:GetPage())
end
local function find(page,id)
 for _,row in ipairs(R:GetCooldownRows(page))do if row.spellID==(id or 871)then return row end end
 error('Missing cooldown row')
end
local function saved(page)return assert(RA.DeathRecapHistory:Snapshot(page))end
local function lastTicker()
 for i=#timers,1,-1 do if timers[i].repeating and not timers[i].cancelled then return timers[i]end end
end
]=]
local cases={
 {name='single_charge_inactive',body=[=[
 charges={maxCharges=1,currentCharges=secret,isActive=false}
 combat=true;R:SetOption('enabled',true)
 local page=freeze();local row=find(page)
 check(row.recordedState==true and find(saved(page)).recordedState==true,'Single-charge inactive cooldown became unconfirmed after saving')
 check(row.currentCharges==nil and not R:GetRecordedNativeStatusKind(row),'Single-charge display depended on its opaque counter')
 ]=]},
 {name='single_charge_own_cooldown',body=[=[
 charges={maxCharges=1,currentCharges=secret,isActive=false}
 combat=true;R:SetOption('enabled',true)
 cooldown={isEnabled=true,isActive=true,isOnGCD=false};time=11;event('SPELL_UPDATE_COOLDOWN',871)
 time=12;event('SPELL_UPDATE_CHARGES')
 local page=freeze();local row=find(page)
 check(row.recordedState==false and find(saved(page)).recordedState==false,'Public single-charge own cooldown failed to persist as unavailable')
 check(row.cooldownAt==11 and row.directCooldown.valid and row.directCooldown.observedAt==11,'Charge update renewed or invalidated independent cooldown provenance')
 check(row.currentCharges==nil and not R:GetRecordedNativeStatusKind(row),'Private count overrode known ordinary cooldown')
 ]=]},
 {name='single_charge_gcd_and_reset',body=[=[
 charges={maxCharges=1,currentCharges=secret,isActive=false}
 combat=true;R:SetOption('enabled',true)
 cooldown={isEnabled=true,isActive=true,isOnGCD=true};time=11;event('SPELL_UPDATE_COOLDOWN',871)
 local page=freeze();check(find(saved(page)).recordedState==nil,'GCD alone was treated as proof of own cooldown availability')
 R:SetOption('enabled',false);dead=false;time=20;R:SetOption('enabled',true)
 cooldown={isEnabled=true,isActive=true,isOnGCD=false};event('SPELL_UPDATE_COOLDOWN',871)
 cooldown={isEnabled=true,isActive=false};time=21;event('SPELL_UPDATE_COOLDOWN',871)
 page=freeze();check(find(saved(page)).recordedState==true and find(page).cooldownAt==21,'Fresh reset did not replace the prior active single-charge cooldown')
 ]=]},
 {name='single_charge_counter_does_not_bypass_own_cooldown',body=[=[
 charges={maxCharges=1,currentCharges=1,isActive=false};combat=true;R:SetOption('enabled',true)
 cooldown={isEnabled=true,isActive=true,isOnGCD=false};time=11;event('SPELL_UPDATE_COOLDOWN',871)
 local page=freeze();check(find(page).recordedState==false and find(saved(page)).recordedState==false,'Single-charge wrapper granted availability despite its active own cooldown')
 ]=]},
 {name='multiple_charges_stay_independent',body=[=[
 charges={maxCharges=2,currentCharges=secret,isActive=true}
 combat=true;R:SetOption('enabled',true)
 local page=freeze();local row=find(page)
 check(row.recordedState==nil and find(saved(page)).recordedState==nil,'Recharging or an inactive normal cooldown guessed a remaining multi-charge count')
 check(R:GetRecordedNativeStatusKind(row)=='charge','Live multi-charge native evidence was lost')
 local called=false
 check(R:BindRecordedChargeStatus({SetValue=function(_,value)called=true;check(rawequal(value,secret),'Opaque charge count was changed')end},row)and called,'Multi-charge native sink was replaced with a guessed public state')
 ]=]},
 {name='noncharge_unrelated_charge_event',body=[=[
 UnitClass=function()return 'Mage','MAGE'end;GetSpecializationInfo=function()return 62 end
 RA.DeathRecapCatalog.entries[1].class='MAGE';RA.DeathRecapCatalog.entries[1].specs={62}
 RA.DeathRecapCatalog.entries[2]={key='mirror_fixture',spellID=55342,name='Mirror Image',class='MAGE',specs={62},knownSpellIDs={55342},category='minor',requiredTalentSpellIDs={1309497},verified=true}
 local queryByID={}
 C_Spell.GetSpellCharges=function(id)queryByID[id]=(queryByID[id]or 0)+1;if id==871 then return{maxCharges=2,currentCharges=secret,isActive=true}end end
 C_Spell.GetSpellCooldown=function(id)if id==55342 then return{isEnabled=true,isActive=true,isOnGCD=false}else return{isEnabled=true,isActive=false}end end
 combat=true;R:SetOption('enabled',true)
 time=11;event('SPELL_UPDATE_COOLDOWN',55342)
 local before=queryByID[55342];local bagBefore=bagReads
 time=12;event('SPELL_UPDATE_CHARGES')
 check(queryByID[55342]==before+1 and bagReads==bagBefore,'Charge reconciliation exceeded its existing one-read-per-spell budget or scanned inventory')
 local page=freeze();local row=find(page,55342)
 check(row.recordedState==false and find(saved(page),55342).recordedState==false,'Unrelated charge event erased saved noncharge unavailability')
 check(row.cooldownAt==11 and row.directCooldown.valid and row.directCooldown.observedAt==11,'Unrelated charge event refreshed noncharge evidence age')
 ]=]},
 {name='noncharge_changes_still_invalidate',body=[=[
 charges=nil;combat=true;R:SetOption('enabled',true)
 cooldown={isEnabled=true,isActive=true,isOnGCD=false};time=11;event('SPELL_UPDATE_COOLDOWN',871)
 cooldown={isEnabled=true,isActive=false};time=12;fire(assert(lastTicker()))
 local page=freeze();local row=find(page)
 check(row.recordedState==true and find(saved(page)).recordedState==true,'Ordinary cooldown expiration did not replace prior active evidence')
 check(not row.directCooldown.valid and row.directCooldown.invalidatedBy=='generic-flags-changed','Changed flags retained valid stale direct evidence')
 R:SetOption('enabled',false);dead=false;time=20;R:SetOption('enabled',true)
 cooldown={isEnabled=true,isActive=true,isOnGCD=false};event('SPELL_UPDATE_COOLDOWN',871)
 time=21;event('UNIT_SPELLCAST_SUCCEEDED','player','new-cast',871)
 page=freeze();row=find(page)
 check(row.recordedState==nil and find(saved(page)).recordedState==nil and row.pendingAt==21,'New own cast reused previous cooldown status before reconciliation')
 ]=]},
 {name='unestablished_charge_kind_is_refreshed',body=[=[
 C_Spell.GetSpellCharges=function()return secret end
 combat=true;R:SetOption('enabled',true)
 cooldown={isEnabled=true,isActive=true,isOnGCD=false};time=11;event('SPELL_UPDATE_COOLDOWN',871)
 time=12;event('SPELL_UPDATE_CHARGES')
 local page=freeze();local row=find(page)
 check(row.recordedState==nil and not row.directCooldown.valid and row.directCooldown.invalidatedBy=='charge-event','Unestablished charge kind was exempted from charge invalidation')
 ]=]},
 {name='charge_model_change_is_observed',body=[=[
 charges=nil;combat=true;R:SetOption('enabled',true)
 cooldown={isEnabled=true,isActive=true,isOnGCD=false};time=11;event('SPELL_UPDATE_COOLDOWN',871)
 charges={maxCharges=2,currentCharges=secret,isActive=true};time=12;event('SPELL_UPDATE_CHARGES')
 local page=freeze();local row=find(page)
 check(row.maxCharges==2 and row.chargeQuery=='public' and row.recordedState==nil,'New charge model inherited noncharge availability')
 check(not row.directCooldown.valid and row.directCooldown.invalidatedBy=='charge-model-changed','Changed charge API kind retained its prior event interpretation')
 ]=]},
 {name='single_charge_duration_predicates',body=[=[
 charges={maxCharges=1,currentCharges=secret,isActive=false};cooldown={isEnabled=true,isActive=true}
 local queries,predicates=0,0
 C_Spell.GetSpellCooldownDuration=function(_,ignore)
  queries=queries+1;check(ignore==true,'Single-charge duration included GCD')
  local value=newproxy(true);getmetatable(value).__index={IsActive=function()predicates=predicates+1;return true end,IsZero=function()predicates=predicates+1;return false end};return value
 end
 combat=true;R:SetOption('enabled',true);local page=freeze()
 check(queries>0 and find(page).recordedState==false and find(saved(page)).recordedState==false,'Readable single-charge own-duration result did not persist')
 R:SetOption('enabled',false);dead=false;time=20;charges={maxCharges=2,currentCharges=secret,isActive=true};local before,priorPredicates=queries,predicates
 R:SetOption('enabled',true);page=freeze()
 check(queries>before and predicates==priorPredicates and find(page).recordedState==nil,'Multi-charge spell used ordinary predicates without a readable native availability witness')
 ]=]},
 {name='single_charge_private_predicates_do_not_become_public',body=[=[
 charges={maxCharges=1,currentCharges=secret,isActive=false};cooldown={isEnabled=true,isActive=true}
 C_Spell.GetSpellCooldownDuration=function()
  local value=newproxy(true);getmetatable(value).__index={IsActive=function()return secret end,IsZero=function()return secret end};return value
 end
 combat=true;R:SetOption('enabled',true);local page=freeze();local row=find(page)
 check(row.recordedState==nil and R:GetRecordedNativeStatusKind(row)=='cooldown','Single-charge opaque state was guessed or the irrelevant counter replaced its cooldown sink')
 local restored=find(saved(page))
 check(restored.recordedState==nil and not R:GetRecordedNativeStatusKind(restored),'Protected single-charge predicates were serialized as public readiness')
 ]=]},
 {name='saved_history_load_uses_only_frozen_public_fields',body=[=[
 charges={maxCharges=1,currentCharges=secret,isActive=false};combat=true;R:SetOption('enabled',true)
 cooldown={isEnabled=true,isActive=true,isOnGCD=false};time=11;event('SPELL_UPDATE_COOLDOWN',871)
 local page=freeze();R:SetOption('enabled',false)
 RaidArsenalDB={};RA.DeathRecapHistory:Save({page},page.id)
 local before=R:GetDiagnostics().spellQueries;local pages=RA.DeathRecapHistory:Load()
 check(#pages==1 and pages[1].restored and find(pages[1]).recordedState==false,'Loading saved public single-charge evidence lost its unavailable result')
 check(not R:GetRecordedNativeStatusKind(find(pages[1]))and R:GetDiagnostics().spellQueries==before and optionalCount()==0,'Saved readiness depended on private witnesses or queried the current character')
 RaidArsenalDB=nil
 ]=]},
}
local assertions=0
for _,case in ipairs(cases)do assertions=assertions+assert(loadstring(prefix..helpers..case.body..'\nreturn checks',case.name))()end
print('PASS: '..assertions..' saved-readiness assertions across '..#cases..' synthetic recorder scenarios (offline)')
