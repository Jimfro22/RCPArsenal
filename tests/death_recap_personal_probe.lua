-- Synthetic default-vs-meter responses; this cannot prove native equivalence.
local f=assert(io.open('tests/death_recap.lua'));local prefix=f:read('*a');f:close()
prefix=prefix:sub(1,assert(prefix:find('check(optionalCount()==0',1,true))-1)
assert(loadstring(prefix..[=[
function CreateFrame()
 local f={registered={}}
 function f:RegisterEvent(name)self.registered[name]=true end
 function f:IsEventRegistered(name)return self.registered[name]==true end
 function f:UnregisterAllEvents()self.registered={}end
 function f:SetScript(_,fn)self.fn=fn end
 return f
end
assert(loadfile('RCPArsenal/DeathRecapDebug.lua'))('RCPArsenal',RA);local D=RA.DeathRecapDebug
local reads,personal,linked=0,{{timestamp=200,event='SPELL_DAMAGE',spellId=701,spellName='Personal spell',amount=340,currentHP=90,hideCaster=false}},
 {{timestamp=199,event='SPELL_DAMAGE',spellId=702,spellName='Meter spell',amount=290,currentHP=80,hideCaster=false}}
C_DeathRecap.HasRecapEvents=function(id)return true end
C_DeathRecap.GetRecapMaxHealth=function(id)return id and 9000 or 10000 end
C_DeathRecap.GetRecapEvents=function(id)if id==nil then reads=reads+1;return personal end;return linked end
check(not R:ReadPersonalNativeForProbe(nil)and reads==0,'Missing page queried personal recap')
R:SetOption('enabled',true);event('DAMAGE_METER_CURRENT_SESSION_UPDATED')
check(D:StartIncomingProbe(),'Probe failed to arm')
combat=true;time=11;event('PLAYER_REGEN_DISABLED')
time=11.125;event('UNIT_COMBAT','player','WOUND','CRITICAL',123,4)
time=11.25;event('UNIT_COMBAT','player','HEAL','',25,2)
meterRows={{isLocalPlayer=true,deathRecapID=71}}
dead=true;time=12;event('PLAYER_DEAD');local page=R:GetPage();local frozen=page.personalNativeProbe
check(reads==1 and frozen and frozen.source=='personal-default'and frozen.status=='public-response','Own armed death did not capture exactly one default response')
check(frozen.readBefore==12 and frozen.readAfter==12 and frozen.rows[1].amount==340 and frozen.rows[1].nativeOffset==0,'Default payload/read brackets were not frozen')
check(page.native.recapID==71 and page.native.rows[1].amount==290 and page.native.rows[1].spellID==702,'Diagnostic default response replaced or merged the linked timeline')
personal[1].amount=999;D:CapturePersonalNativeProbe(page)
check(not R:ReadPersonalNativeForProbe(page)and reads==1 and frozen.rows[1].amount==340,'Repeated probe/read or later API mutation changed frozen facts')
local report=assert(R:BuildDebugText());local readable=assert(R:BuildLiveHistoryText())
check(report:find('capturedFieldsMatch=false',1,true)and report:find('differentRows=1',1,true),'Different responses were presented as equivalent')
check(report:find('RAW LIVE RECEIPTS',1,true)and report:find('sequence=1 observedAt=11.125 kind="damage" amount=123 flag="CRITICAL" school=4',1,true),'Exact receipt time/identity/flag/amount lost in full export')
check(not readable:find('RAW LIVE RECEIPTS',1,true)and readable:find('DAMAGE  123',1,true),'Concise live readout became an unreadable raw dump')
check(reads==1,'Frozen export re-queried current native state')
local saved=RA.DeathRecapHistory:Snapshot(page)
check(saved.personalNativeProbe.rows[1].amount==340 and saved.personalNativeProbe.readBefore==12 and saved.personalNativeProbe.recapMaxHealth==10000,'Safe history omitted the bounded personal snapshot')
-- Ordinary deaths do no new default queries; stale/expired probes do not attach.
R:SetOption('enabled',false);dead=false;combat=false;time=20;meterRows={};R:SetOption('enabled',true);event('DAMAGE_METER_CURRENT_SESSION_UPDATED')
combat=true;event('PLAYER_REGEN_DISABLED');dead=true;time=21;event('PLAYER_DEAD')
check(not R:GetPage().personalNativeProbe and reads==1,'Unarmed death paid for or inherited the default diagnostic')
-- Failed public responses are labelled without manufacturing an empty match.
R:SetOption('enabled',false);dead=false;combat=false;time=30;meterRows={};R:SetOption('enabled',true);event('DAMAGE_METER_CURRENT_SESSION_UPDATED');check(D:StartIncomingProbe(),'Second probe failed')
combat=true;event('PLAYER_REGEN_DISABLED');personal=secret;meterRows={{isLocalPlayer=true,deathRecapID=72}}
dead=true;time=31;event('PLAYER_DEAD');local failed=R:GetPage()
check(reads==2 and #failed.personalNativeProbe.rows==0 and failed.personalNativeProbe.status~='public-response'and failed.native.rows[1].amount==290,'Restricted default read contaminated the accepted native packet')
check(R:BuildDebugText():find('capturedFieldsMatch=not-comparable',1,true),'Unavailable response was classified as a matching empty recap')
R:SetOption('enabled',false)
print('PASS: '..checks..' owner-armed default/meter isolation, exact local export, once-only bounds and private response assertions')
]=]))()
