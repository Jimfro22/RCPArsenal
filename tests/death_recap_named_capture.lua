-- Actual recorder -> saved snapshot -> viewport -> grouping. Synthetic native
-- packets prove Arsenal does not impose a ten-hit limit; they do not prove
-- what the live client exposes or join anonymous incoming receipts to names.
local f=assert(io.open('tests/death_recap.lua'));local prefix=f:read('*a');f:close()
prefix=prefix:sub(1,assert(prefix:find('check(optionalCount()==0',1,true))-1)
for _,count in ipairs({10,20,64,65})do
 local source=prefix..'\nlocal inputCount='..count..'\n'..[=[
assert(loadfile('RCPArsenal/DeathLogModel.lua'))('RCPArsenal',RA)
function GetInstanceInfo()return 'Synthetic raid','raid',16,'Mythic',20,0,false,700 end
R:SetOption('enabled',true);event('DAMAGE_METER_CURRENT_SESSION_UPDATED')
event('ENCOUNTER_START',924,'Synthetic boss',16)
combat=true;event('PLAYER_REGEN_DISABLED');meterRows={{isLocalPlayer=true,deathRecapID=1}};link='death:1'
for i=1,inputCount do
 events[i]={destGUID='Player-self',event='SPELL_DAMAGE',timestamp=1000-(i-1)*.12,
  spellId=1000+i,spellName='Synthetic '..i,amount=100,currentHP=1000,hideCaster=false}
end
dead=true;time=20;event('PLAYER_DEAD');local page=assert(R:GetPage());local native=assert(page.native)
local retained=math.min(inputCount,64)
check(#native.rows==retained,'Recorder capped readable native packet to ten hits')
check(native.truncated==(inputCount>64),'Recorder bound did not disclose truncation')
check(page.encounter.gameMapID==700,'Native game-map ID was not captured at encounter start')
local saved=assert(RA.DeathRecapHistory:Snapshot(page))
check(saved.encounter.gameMapID==700 and #saved.native.rows==retained,'Reload snapshot lost map or named rows')
local M=RA.DeathLogModel;local coverage=M:NamedCoverage(saved)
check(coverage.count==retained and math.abs(coverage.span-(retained-1)*.12)<.00001,'Named coverage includes anonymous feed, padding or wrong span')
local viewport=M:Viewport(saved.native.rows,1000)
check(#viewport.rows==retained,'Viewport discarded supplied in-window significant hits')
local groups=M:Group(viewport.rows);local seen,total={},0
for _,item in ipairs(groups.items)do for _,row in ipairs(item.rows)do
 check(not seen[row.nativeIndex],'Grouping duplicated a native hit');seen[row.nativeIndex]=true;total=total+1
 local original=events[row.nativeIndex]
 check(row.timestamp==original.timestamp and row.spellID==original.spellId and row.name==original.spellName,'Identity or timestamp changed in capture/history/grouping')
end end
check(total==retained,'Grouping omitted a supplied native hit')
check(M:NamedCoverage({liveIncoming={rows={{kind='healing',amount=999}}}}).count==0,'Anonymous receipt became named data')
local malformed=RA.DeathRecapHistory:Snapshot({id=1,diedAt=1,encounter={gameMapID=secret}})
check(malformed.encounter.gameMapID==nil,'Restricted game-map ID was saved')
malformed=RA.DeathRecapHistory:Snapshot({id=1,diedAt=1,encounter={gameMapID=1.5}})
check(malformed.encounter.gameMapID==nil,'Malformed game-map ID was saved')
io.write('PASS: '..inputCount..' supplied named rows; '..retained..' preserved through capture/save/viewport/grouping\n')
]=]
 assert(loadstring(source,'named-capture-'..count))()
end
