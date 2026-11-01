local f=assert(io.open('tests/death_recap.lua'));local prefix=f:read('*a');f:close();prefix=prefix:sub(1,assert(prefix:find('check(optionalCount()==0',1,true))-1)
assert(loadstring(prefix..[=[
combat=true;charges={maxCharges=2,currentCharges=secret,isActive=true};R:SetOption('enabled',true)
dead=true;time=11;event('PLAYER_DEAD');local page=R:GetPage();local row=R:GetCooldownRows(page)[1]
local calls=0;local font={SetFormattedText=function(self,format,value)calls=calls+1;check(format=='%d'and rawequal(value,secret),'Opaque count was converted or replaced before native formatting')end}
check(row.currentCharges==nil and row.recordedState==nil and R:RenderRecordedChargeCount(font,row)and calls==1,'Opaque native display changed public availability or lost witness')
charges=nil;event('SPELL_UPDATE_COOLDOWN',871);check(R:RenderRecordedChargeCount(font,row)and calls==2,'Later query mutated frozen witness')
local saved=RA.DeathRecapHistory:Snapshot(page)
check(not R:RenderRecordedChargeCount(font,saved.lastAlive.spells[1]),'Opaque witness persisted through allowlisted snapshot')
assert(loadfile('RCPArsenal/DeathRecapDebug.lua'))('RCPArsenal',RA)
check(R:BuildDebugText()and row.currentCharges==nil,'Debug attempted to export opaque count')
row.pendingAt=11;check(not R:RenderRecordedChargeCount(font,row),'Pending projection displayed old opaque count');row.pendingAt=nil
row.coverageEndedAt=11;check(not R:RenderRecordedChargeCount(font,row),'Ended coverage displayed old opaque count');row.coverageEndedAt=nil
check(not R:RenderRecordedChargeCount({SetFormattedText=function()error('native refusal')end},row),'Native formatter refusal escaped')
R:SetOption('enabled',false);local q=R:GetDiagnostics().spellQueries
R:RenderRecordedChargeCount(font,row);check(R:GetDiagnostics().spellQueries==q and optionalCount()==0,'Historical native rendering captured while OFF')
print('PASS: '..checks..' volatile opaque-charge passthrough/frozen/serialization assertions')
]=]))()
