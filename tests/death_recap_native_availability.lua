-- Recorder/persistence checks for guarded native cooldown snapshots. The fake
-- widget exercises transport, calibration and freezing, NOT Retail secrecy or
-- spell semantics. Those still require a native charge-cycle check.
local file=assert(io.open('tests/death_recap.lua'));local prefix=file:read('*a');file:close()
prefix=prefix:sub(1,assert(prefix:find('check(optionalCount()==0',1,true))-1)
local setup=[=[
local remaining,ownActive,mode=2,false,'normal'
local created,applied,factories,clears=0,0,0,0
local durations=setmetatable({},{__mode='k'})
local parent
function CreateFrame(kind,_,owner)
 created=created+1
 if kind=='Frame'then
  parent={hidden=false,Hide=function(self)self.hidden=true end};return parent
 end
 check(kind=='Cooldown'and owner==parent and parent.hidden,'Probe touched a visible or external frame')
 local w={shown=false}
 function w:SetDrawSwipe(v)check(v==false)end
 function w:SetDrawEdge(v)check(v==false)end
 function w:SetHideCountdownNumbers(v)check(v==true)end
 function w:SetCooldown(start,duration)
  check(start==time and duration==60,'Calibration inspected a secret cooldown')
  self.shown=mode~='stuck-hidden'
 end
 function w:Clear()clears=clears+1;self.shown=mode=='stuck-shown'end
 function w:SetCooldownFromDurationObject(duration,clearIfZero)
  check(type(duration)=='userdata'and clearIfZero==true,'Probe did not use native duration-object transport')
  applied=applied+1
  if mode=='setter-error'then error('setter blocked')end
  if mode=='no-op'then return end
  if mode=='restricted'then self.shown=secret;return end
  self.shown=ownActive
  if mode=='expires-between-reads'and applied%2==0 then self.shown=not ownActive end
 end
 function w:IsShown()
  if mode=='getter-error'then error('getter blocked')end
  if mode=='malformed'then return 'false'end
  return self.shown
 end
 function w:IsVisible()error('Parent visibility is not cooldown state')end
 return w
end
charges={maxCharges=2,currentCharges=secret,isActive=true}
cooldown={isEnabled=true,isActive=true}
C_Spell.GetSpellCooldownDuration=function(_,ignore)
 check(ignore==true,'GCD was included');factories=factories+1
 if mode=='factory-nil'then return end
 if mode=='factory-error'then error('factory blocked')end
 if mode=='factory-table'then return{}end
 if mode=='factory-secret'then return secret end
 local value=newproxy(true)
 getmetatable(value).__index={IsActive=function()return secret end,IsZero=function()return secret end}
 durations[value]=true;return value
end
local function freeze()
 dead=true;time=time+.01;event('PLAYER_DEAD');return assert(R:GetPage())
end
local function row(page)return R:GetCooldownRows(page)[1]end
local function saved(page)return assert(RA.DeathRecapHistory:Snapshot(page))end
local function start()combat=true;R:SetOption('enabled',true)end
assert(loadfile('RCPArsenal/DeathRecapDebug.lua'))('RCPArsenal',RA)
]=]
local cases={}
local function add(name,body)cases[#cases+1]={name=name,body=body}end
for _,count in ipairs({0,1,2})do
 add('charge_count_'..count,[=[
 remaining=]=]..count..[=[;ownActive=remaining==0
 start();local page=freeze();local live=row(page);local restored=row(saved(page))
 check(live.recordedState==(remaining>0)and restored.recordedState==live.recordedState,'Charge availability was lost or confused with recharge')
 check(live.currentCharges==nil and restored.currentCharges==nil,'Native availability fabricated a charge count')
 check(restored.nativeCooldownStatus=='public'and restored.nativeCooldownSource=='ignoreGCD-widget','Public provenance did not survive serialization')
 check(restored.checkedAt==page.lastAlive.spells[1].nativeCooldownAt,'Fresh native check inherited an older callback time')
 check(created==2 and clears>0,'Probe allocated per spell/sample or left its cooldown running')
 collectgarbage('collect');check(next(durations)==nil,'Frozen record retained a ticking native duration object')
 local before=factories;RaidArsenalDB={};RA.DeathRecapHistory:Save({page},page.id)
 local pages=RA.DeathRecapHistory:Load()
 check(#pages==1 and row(pages[1]).recordedState==live.recordedState and factories==before,'Reload reconstructed availability from current character state')
 local audit=assert(R:GetAvailabilityAudit());local facts=assert(R:BuildCoreFactsText())
 check(R:ClassifyRecordedCheck(audit.spells[1].lastAlive)==live.recordedState,'Audit dropped native evidence used by the displayed badge')
 check(audit.spells[1].displayed.state==live.recordedState and audit.spells[1].displayed.observedAt==live.checkedAt,'Audit state or check time diverged from the displayed native fact')
 local label=remaining>0 and'Available'or'Unavailable'
 check(facts:find('Before death: '..label,1,true)and facts:find('At death notice: '..label,1,true),'Readable report disagreed with frozen native availability')
 local pageBeforeQueries=factories;local savedPage=pages[1]
 local selection=R.GetSelectedPage;R.GetSelectedPage=function()return savedPage end
 local restoredAudit=assert(R:GetAvailabilityAudit());local restoredFacts=assert(R:BuildCoreFactsText())
 check(restoredAudit.spells[1].displayed.state==row(savedPage).recordedState,'Restored audit disagreed with restored badge')
 check(restoredFacts:find('Before death: '..label,1,true)and restoredFacts:find('At death notice: '..label,1,true),'Restored facts dropped saved native evidence')
 check(restoredFacts:find('Saved death',1,true)and factories==pageBeforeQueries,'Reading restored facts queried current cooldown state')
 R.GetSelectedPage=selection
 ]=])
end
add('mirror_without_event_gcd_flag',[=[
 charges=nil;ownActive=true
 start();time=11;event('UNIT_SPELLCAST_SUCCEEDED','player','mirror-test',871)
 time=11.1;event('SPELL_UPDATE_COOLDOWN')
 local page=freeze();check(row(page).recordedState==false and row(saved(page)).recordedState==false,'Mirror-style own cooldown became a question mark after nil-GCD update/reload')
 check(page.casts[1].spellID==871,'Cooldown snapshot replaced successful-use evidence')
 local facts=assert(R:BuildCoreFactsText())
 check(facts:find('Before death: Unavailable',1,true)and facts:find('At death notice: Unavailable',1,true),'Ordinary own-cooldown evidence was dropped from the text report')
]=])
add('global_cooldown_only',[=[
 charges=nil;ownActive=false;cooldown.isOnGCD=true
 start();time=11;event('SPELL_UPDATE_COOLDOWN',871)
 local page=freeze();check(row(page).recordedState==true and row(saved(page)).recordedState==true,'Global cooldown alone made an available defensive unavailable')
]=])
add('new_cast_invalidates_then_reconciles',[=[
 start();time=11;event('UNIT_SPELLCAST_SUCCEEDED','player','charge-test',871)
 local page=freeze();check(row(page).recordedState==nil,'Pending own cast retained its old ready check')
 R:SetOption('enabled',false);dead=false;time=20;ownActive=true;start()
 time=21;event('SPELL_UPDATE_CHARGES')
 page=freeze();check(row(page).recordedState==false and row(saved(page)).recordedState==false,'Fresh depleted state failed to replace ready state')
]=])
add('regained_charge_replaces_depleted',[=[
 ownActive=true;start()
 ownActive=false;time=11;event('SPELL_UPDATE_CHARGES')
 local page=freeze();check(row(page).recordedState==true and row(saved(page)).recordedState==true,'Charge regained was still reported unavailable')
]=])
add('readable_counter_keeps_precedence',[=[
 charges.currentCharges=1;ownActive=true;start();local page=freeze()
 check(row(page).recordedState==true and factories==0,'Unneeded native probe overrode an explicit remaining charge')
]=])
for _,failure in ipairs({'stuck-hidden','stuck-shown','setter-error','getter-error','restricted','malformed','no-op','expires-between-reads','factory-nil','factory-error','factory-table','factory-secret'})do
 add('fail_closed_'..failure,"mode='"..failure.."';"..[=[
 start();local page=freeze();local live=row(page);local restored=row(saved(page))
 check(live.recordedState==nil and restored.recordedState==nil,'Unusable native witness fabricated readiness')
 check(live.nativeCooldownActive==nil and restored.nativeCooldownActive==nil,'Failed/protected native read was saved as a boolean')
 local audit=assert(R:GetAvailabilityAudit());local facts=assert(R:BuildCoreFactsText())
 check(audit.spells[1].displayed.state==nil and facts:find('Before death: Not confirmed',1,true),'Failed native witness became a definitive audit/report result')
 ]=])
end
add('held_cooldown_does_not_probe',[=[
 cooldown.isEnabled=false;start();local page=freeze()
 check(row(page).recordedState==false and factories==0 and created==0,'Held cooldown consumed a probe or became available')
]=])
add('disabled_is_idle',[=[
 check(created==0 and factories==0 and #timers==0 and optionalCount()==0,'Disabled Death Log allocated/queried native observer')
]=])
local assertions=0
for _,case in ipairs(cases)do assertions=assertions+assert(loadstring(prefix..setup..case.body..'\nreturn checks',case.name))()end
print('PASS: '..assertions..' native-availability transport assertions across '..#cases..' synthetic recorder scenarios (offline)')
