local f=assert(io.open('tests/death_recap.lua'));local prefix=f:read('*a');f:close();prefix=prefix:sub(1,assert(prefix:find('check(optionalCount()==0',1,true))-1)
prefix=prefix:gsub('local RA={}','RaidArsenalDB=HISTORY_STORE or{};local RA={}',1)
HISTORY_STORE={}
assert(loadstring(prefix..[=[
combat=true;R:SetOption('enabled',true)
for i=1,6 do
 dead=false;time=10+i;event('PLAYER_REGEN_DISABLED');event('UNIT_SPELLCAST_SUCCEEDED','player','cast',871)
 dead=true;time=time+.5;event('PLAYER_DEAD')
end
local records=R:GetHistory();check(#records==5 and records[1].id==6 and records[5].id==2,'Sixth death did not evict only oldest')
check(#RaidArsenalDB.deathRecapHistory.pages==5 and RaidArsenalDB.deathRecapHistory.sequence==6,'Saved history was not capped/serialized')
check(R:SelectHistoryPage(5)and R:GetSelectedPage()==records[5]and R:GetPage()==records[1],'Selected history replaced latest death association')
assert(loadfile('RCPArsenal/DeathRecapActions.lua'))('RCPArsenal',RA)
assert(loadfile('RCPArsenal/DeathRecapDebug.lua'))('RCPArsenal',RA)
check(R:BuildShareText(records[5])and R:BuildDebugText(),'Sharing/debug did not accept selected retained death')
local older=records[5];local oldHP=older.lastAlive.spells[1].cooldown
dead=false;time=30;event('DAMAGE_METER_CURRENT_SESSION_UPDATED');event('DAMAGE_METER_COMBAT_SESSION_UPDATED',9,1);event('PLAYER_REGEN_DISABLED')
dead=true;time=31;event('PLAYER_DEAD');local latest=R:GetPage()
check(latest.id==7 and R:GetSelectedPage()==latest and not R:IsRetainedPage(older),'Evicted selected page did not fall back to newest')
R:SelectHistoryPage(2);local selected=R:GetSelectedPage()
meterRows={{isLocalPlayer=true,deathRecapID=55}};events={{destGUID='Player-self',timestamp=100,event='SPELL_DAMAGE',spellId=123,amount=1,currentHP=0}}
local pending=timers[#timers];fire(pending)
check(latest.native and latest.native.recapID==55 and R:GetSelectedPage()==selected and selected~=latest and selected.native==nil,'Late native arrival changed selected older record or failed current owner')
check(older.lastAlive.spells[1].cooldown==oldHP,'Later death changed an earlier frozen check')
local H=RA.DeathRecapHistory
local bad=H:Snapshot({id=8,diedAt=99,lastAlive={spells={{spellID=871,currentCharges='bad',maxCharges=secret,cooldown='unknown'}},supplies={}},association={private=true},chatTarget='Do not save',callback=function()end})
check(bad and bad.lastAlive.spells[1].currentCharges==nil and bad.lastAlive.spells[1].maxCharges==nil and bad.association==nil and bad.chatTarget==nil and bad.callback==nil,'History sanitizer retained bad/secret/private values')
check(not H:Snapshot(secret)and not H:Snapshot(setmetatable({id=1,diedAt=2},{})),'History accepted opaque or nonplain page')
local ended=H:Snapshot({id=9,diedAt=101,lastAlive={coverageEndedAt=100,spells={{spellID=871,known=true,chargeQuery='not_applicable',cooldown='inactive'}},supplies={}}})
check(ended.lastAlive.coverageEndedAt==100 and R:GetCooldownRows(ended)[1].recordedState==nil,'History reload promoted an ended observation into availability')
HISTORY_STORE=RaidArsenalDB
R:SetOption('enabled',false);local count=R:GetDiagnostics().spellQueries
event('PLAYER_REGEN_DISABLED');event('PLAYER_DEAD');check(R:GetDiagnostics().spellQueries==count,'OFF captured history')
print('PASS: '..checks..' five-death persistence/selection/late-native/sanitizer assertions')
]=]))()
assert(loadstring(prefix..[=[
check(R:GetPage()==nil and R:GetState().hasPage and #R:GetHistory()==5 and R:GetHistory()[1].restored,'Reload did not restore safe history separately from current death')
check(bagReads==0 and R:GetDiagnostics().spellQueries==0 and optionalCount()==0,'OFF history restoration queried character or registered capture')
assert(loadfile('RCPArsenal/DeathRecapDebug.lua'))('RCPArsenal',RA)
check(R:BuildDebugText()and not R:ReadNativePacketForDebug(),'Saved debug failed or reread stale native identity')
combat=true;dead=false;R:SetOption('enabled',true);time=50;dead=true;event('PLAYER_DEAD')
check(R:GetPage().id==8 and #R:GetHistory()==5,'Reload reused death ID or exceeded saved bound')
print('PASS: '..checks..' restored-history/new-login identity assertions')
]=]))()
HISTORY_STORE=nil
