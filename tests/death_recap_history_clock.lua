-- Fabricated clocks and payloads exercise production save/load and alignment.
local f=assert(io.open('tests/death_recap.lua'));local prefix=f:read('*a');f:close()
prefix=prefix:sub(1,assert(prefix:find('check(optionalCount()==0',1,true))-1)
assert(loadstring(prefix..[=[
assert(loadfile('RCPArsenal/DeathLogModel.lua'))('RCPArsenal',RA)
local H,M=RA.DeathRecapHistory,RA.DeathLogModel
local page={id=17,diedAt=40,localSessionStartedAt=20,casts={{spellID=871,observedAt=38.125,source='UNIT_SPELLCAST_SUCCEEDED'}},
 native={recapID=71,recapMaxHealth=10000,rows={{nativeIndex=1,timestamp=300,nativeOffset=0,kind='damage',event='SPELL_DAMAGE',spellID=701,amount=100,recordedHP=90,absorbed=0,
 fieldStatus={hp='public',source='restricted',absorbed='public',overkill='malformed'}}},
 clockDiagnostic={localClock='GetTime',localSessionStartedAt=20,localDeathNoticeAt=40,nativeFatalTimestamp=300,nativeMaximumTimestamp=300,nativeRowCount=1}},
 personalNativeProbe={source='personal-default',status='public-response',observedAt=40,readBefore=40.001,readAfter=40.002,
 rows={{nativeIndex=1,timestamp=300,nativeOffset=0,event='SPELL_DAMAGE',amount=100,fieldStatus={absorbed='public',overkill='not-recorded'}}}}}
local before=M:AlignUses(page);check(before.anchorValid and #before.aligned==1,'Synthetic source anchor invalid')
RaidArsenalDB={};H:Save({page},17);local loaded=H:Load();local restored=loaded[1]
local after=M:AlignUses(restored)
check(after.anchorValid and #after.aligned==1 and after.aligned[1].offset==before.aligned[1].offset,'Save/load dropped the native/local death anchor or retimed the cast')
check(restored.native.clockDiagnostic.localDeathNoticeAt==40,'Saved local death notice lost its numeric type')
check(restored.native.rows[1].absorbed==0 and restored.native.rows[1].fieldStatus.absorbed=='public'and restored.native.rows[1].fieldStatus.overkill=='malformed','Numeric amounts and textual field statuses collided')
check(restored.personalNativeProbe.readBefore==40.001 and restored.personalNativeProbe.readAfter==40.002 and restored.personalNativeProbe.rows[1].fieldStatus.overkill=='not-recorded','Personal comparison lost read brackets or status provenance')
check(restored.native.clockDiagnostic.localDeathNoticeAt==page.diedAt and not page.restored,'Serialization mutated the live source page')
page.native.clockDiagnostic.localDeathNoticeAt=secret
page.native.rows[1].fieldStatus={hp=42,source=true,absorbed=secret,overkill={}}
page.personalNativeProbe.readBefore=secret;page.personalNativeProbe.rows[1].amount=secret
local scrubbed=H:Snapshot(page)
check(scrubbed.native.clockDiagnostic.localDeathNoticeAt==nil and not M:AlignUses(scrubbed).anchorValid,'Restricted clock became an alignment witness')
check(next(scrubbed.native.rows[1].fieldStatus)==nil and scrubbed.personalNativeProbe.readBefore==nil and scrubbed.personalNativeProbe.rows[1].amount==nil,'Typed status override serialized a private/malformed value')
assert(loadfile('RCPArsenal/DeathRecapDebug.lua'))('RCPArsenal',RA)
R.GetSelectedPage=function()return restored end
local report=assert(R:BuildDebugText())
check(report:find('localDeathNoticeAt=40',1,true)and report:find('absorbed="public" overkill="malformed"',1,true),'Restored export hides retained clock/status facts')
check(report:find('readBefore=40.000999999999998',1,true)and report:find('FROZEN PERSONAL DEFAULT',1,true),'Restored default comparison disappeared from export')
print('PASS: '..checks..' typed history round-trip, exact read brackets, cast alignment and secret rejection assertions')
]=]))()
