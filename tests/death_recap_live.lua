-- Actual addon event dispatcher, recorder, association and UI together.
-- Native APIs are controlled fixtures; this does not prove live event order.
local function Read(path)local f=assert(io.open(path));local text=f:read('*a');f:close();return text end
local source=Read('tests/hub.lua')
source=source:sub(1,assert(source:find('check(db.schemaVersion == 19',1,true))-1)
local ui=Read('tests/death_recap_ui.lua');local marker='source=source..[=['
local first=assert(ui:find(marker,1,true))+#marker
source=source..ui:sub(first,assert(ui:find('local groupCalls=',first,true))-1)
source=source..[=[
local now,dead=100,false
function GetTime()return now end
function UnitIsDeadOrGhost(unit)check(unit=='player','Queried another death unit');return dead end
function UnitGUID(unit)check(unit=='player','Queried another identity');return 'Player-live-fixture'end
function UnitClass()return 'Warrior','WARRIOR'end
function GetSpecialization()return 1 end
function GetSpecializationInfo()return 73 end
Enum=Enum or{};Enum.SpellBookSpellBank={Player=0};Enum.DamageMeterSessionType={Current=1};Enum.DamageMeterType={Deaths=9}
C_SpellBook={IsSpellKnown=function(id)return id==871 end}
local active=false
C_Spell.GetOverrideSpell=function(id)return id end
C_Spell.IsSpellPassive=function()return false end
C_Spell.GetSpellCooldown=function()return {isEnabled=true,isActive=active,isOnGCD=false}end
C_Spell.GetSpellCharges=function()return nil end
C_Container={GetContainerNumSlots=function()return 0 end}
local meterRows,nativeRows={},{}
C_DamageMeter={GetCombatSessionFromType=function(kind,metric)check(kind==1 and metric==9,'Wrong current session query');return {combatSources=meterRows}end,
 GetCombatSessionFromID=function(id,metric)check(id==23 and metric==9,'Wrong explicit session query');return {combatSources=meterRows}end}
local requested={}
C_DeathRecap={HasRecapEvents=function(id)check(type(id)=='number','Used default recap selection');requested[#requested+1]=id;return #nativeRows>0 end,
 GetRecapEvents=function(id)check(id==77 or id==78 or id==79,'Read an unrelated native recap');return nativeRows end,
 GetRecapMaxHealth=function()return 100000 end}
local function NativeRows(amount)
 return {{timestamp=500,currentHP=0,spellId=123,event='SPELL_DAMAGE',amount=amount,spellName='Fatal fixture',destGUID='Player-live-fixture'},
 {timestamp=498,currentHP=60000,spellId=124,event='SPELL_DAMAGE',amount=40000,spellName='Prior fixture',destGUID='Player-live-fixture'}}
end
local function FetchTimer()
 for i=#timers,1,-1 do local timer=timers[i];if timer.delay==.5 and not timer.cancelled and not timer.fired and not timer.ticker then return timer end end
end
local reads=R:GetDiagnostics().nativeReads
event('PLAYER_DEAD');check(R:GetPage()==nil and not named.RCPArsenalDeathRecap and R:GetDiagnostics().nativeReads==reads,'OFF captured or opened a death')
R:SetOption('enabled',true);event('DAMAGE_METER_CURRENT_SESSION_UPDATED');event('DAMAGE_METER_COMBAT_SESSION_UPDATED',9,23)
event('ENCOUNTER_START',101,'Live integration fixture',16);combat=true;event('PLAYER_REGEN_DISABLED')
now=101;event('UNIT_SPELLCAST_SUCCEEDED','player','cast-fixture',871);active=true;event('SPELL_UPDATE_COOLDOWN')
meterRows={{isLocalPlayer=true,deathRecapID=77}};nativeRows=NativeRows(61000);now=102;dead=true;event('PLAYER_DEAD')
local page=R:GetPage();local popup=named.RCPArsenalDeathRecap
check(page and page.native and page.native.recapID==77 and page.observedUses[871].observedCount==1,'Actual own-death event did not capture native and local evidence')
check(not popup or not popup:IsShown(),'Default auto-open interrupted the death dialog')
check(U:ShowLast(),'Manual own-death view unavailable');popup=named.RCPArsenalDeathRecap
check(popup and popup:IsShown()and not popup.coverage:IsShown()and popup.selected.nativeIndex==1 and popup.healthPanel.selectedHP==0,'Manual open did not show the captured native page')
check(popup.contextText:find('Live integration fixture',1,true)and not popup.context and not popup.health,'Live context lost or approved labels returned')
local report=R:BuildShareReport(page,false);check(report.text:find('61,000 damage',1,true)and report.text:find('Shield Wall',1,true)and not report.text:find('fictional',1,true),'Live report lost captured evidence or leaked Preview')
nativeRows[1].amount=1;check(page.native.rows[1].amount==61000,'Native input mutated the frozen page')
local lastAlive=page.lastAlive.spells[1].cooldown;active=false;event('SPELL_UPDATE_COOLDOWN');check(page.lastAlive.spells[1].cooldown==lastAlive,'Post-death event changed the frozen living check')
dead=false;event('PLAYER_ALIVE');check(not popup:IsShown()and R:GetPage()==page,'Resurrection reopened or discarded the retained page')
R:SetOption('autoOpen',false);meterRows[2]={isLocalPlayer=true,deathRecapID=78};nativeRows=NativeRows(62000);now=105;dead=true;event('PLAYER_DEAD')
check(R:GetPage()~=page and R:GetPage().native.recapID==78 and not popup:IsShown(),'Disabled auto-open prevented capture or opened the popup')
check(U:ShowLast()and popup:IsShown()and popup.selected.amount==62000,'Manual live review did not use the retained native page')
dead=false;event('PLAYER_ALIVE');R:SetOption('autoOpen',true);now=108;dead=true;event('PLAYER_DEAD')
page=R:GetPage();local pending=FetchTimer();check(not page.native and pending and popup:IsShown(),'Pending native page did not open or schedule bounded completion')
U:Hide();event('PLAYER_DEAD');check(not pending.cancelled and R:GetPage()==page,'Duplicate death stranded pending capture')
dead=false;event('PLAYER_ALIVE');check(not pending.cancelled and not popup:IsShown(),'Resurrection cancelled or reopened pending personal capture')
meterRows[3]={isLocalPlayer=true,deathRecapID=79};nativeRows=NativeRows(63000);now=108.5;pending.fired=true;pending.callback()
check(page.native and page.native.recapID==79 and not popup:IsShown(),'Late native capture failed or reopened a user-closed popup')
check(U:ShowLast()and popup.selected.amount==63000,'Manual review did not expose late native capture')
R:SetOption('enabled',false);reads=R:GetDiagnostics().nativeReads;pending.callback();event('PLAYER_DEAD')
check(not popup:IsShown()and R:GetDiagnostics().nativeReads==reads and not R:GetDiagnostics().fetchPending and not R:GetDiagnostics().tickerActive,'Disabled integration retained work or reopened UI')
cleanErrors()
nativePrint('PASS: '..checks..' real-module own-death capture, auto-open, freeze and late-fill integration assertions (offline; native event order pending)')
]=]
assert(loadstring(source,'death-recap-live-integration'))()
