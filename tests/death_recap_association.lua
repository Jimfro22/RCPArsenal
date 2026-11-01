local checks=0
local function check(value,message)checks=checks+1;assert(value,message)end
local secret=setmetatable({},{__tostring=function()error('Opaque value formatted')end})
function issecretvalue(value)return rawequal(value,secret)end
Enum={DamageMeterSessionType={Current=1},DamageMeterType={Deaths=9}}
local rows,explicitRows={},nil
C_DamageMeter={GetCombatSessionFromType=function(kind,metric)check(kind==1 and metric==9,'Wrong meter alias/type');return {combatSources=rows}end,
    GetCombatSessionFromID=function(id,metric)check(id>0 and metric==9,'Wrong explicit query');return {combatSources=explicitRows or rows}end}
local RA={};assert(loadfile('RCPArsenal/DeathRecapAssociation.lua'))('RCPArsenal',RA)
local A=RA.DeathRecapAssociation
A:NewEpoch(true);check(A:GetDiagnostics().reads==0,'Disabled association queried meter')
A:SetEnabled(true);local token=A:Freeze()
check(not A:Candidate(token),'Late enable/reload fabricated a complete alive baseline')
A:NewEpoch(true);A:Update(9,1,true);token=A:Freeze()
check(token.known and not A:Candidate(token),'Empty delta became a current native death')
local reads=A:GetDiagnostics().reads;local visits=A:GetDiagnostics().rows
for _=1,1000 do A:Update(9,1,true)end
check(A:GetDiagnostics().reads==reads and A:GetDiagnostics().rows==visits,'Repeated same-session events rescanned meter')
rows={{isLocalPlayer=false,deathRecapID=secret},{isLocalPlayer=true,deathRecapID=10}}
local id,reason,set=A:Candidate(token);check(id==10 and not reason,'Exactly one personal ID not selected independently of foreign row')
check(A:Commit(token,id,set),'Personal record commit rejected')
token=A:Freeze();rows={{isLocalPlayer=true,deathRecapID=10},{isLocalPlayer=true,deathRecapID=11},{isLocalPlayer=true,deathRecapID=12}}
check(not A:Candidate(token),'Multiple new IDs became one current death')
local second=A:Freeze();check(not A:Candidate(second),'Unresolved previous own death ignored')
rows={};A:NewEpoch(true);A:Update(9,1,true);token=A:Freeze()
rows={{isLocalPlayer=true,deathRecapID=20}};explicitRows={{isLocalPlayer=true,deathRecapID=21}}
check(A:Candidate(token)==20 and not A:GetDiagnostics().sessionBound,'Unproven explicit-session hint replaced authoritative Current')
explicitRows=nil;A:NewEpoch(true);check(not A:GetDiagnostics().baselineKnown,'Nonempty new epoch declared clean/complete')
rows={};A:NewEpoch(true);A:Update(9,1,true);token=A:Freeze();A:NewEpoch(true)
check(not A:Candidate(token),'Reset/alias epoch reused prior death token')
rows={};A:NewEpoch(true);A:Update(9,1,true);token=A:Freeze();A:Update(9,2,true)
check(A:GetDiagnostics().baselineKnown and not A:Candidate(token),'Changed hint poisoned baseline or empty delta became death')
rows={{isLocalPlayer=true,deathRecapID=22}};check(A:Candidate(token)==22,'Changed hint prevented fresh authoritative Current delta')
rows=secret;A:NewEpoch(true);check(not A:GetDiagnostics().baselineKnown,'Opaque parent became empty set')
rows={{isLocalPlayer=secret,deathRecapID=1}};A:NewEpoch(true)
check(not A:GetDiagnostics().baselineKnown,'Opaque local-player flag traversed/inferred')
rows={{isLocalPlayer=true,deathRecapID=secret}};A:NewEpoch(true)
check(not A:GetDiagnostics().baselineKnown,'Opaque personal ID accepted')
rows={};for i=1,129 do rows[i]={isLocalPlayer=false}end
local prior=A:GetDiagnostics().rows;A:NewEpoch(true)
check(not A:GetDiagnostics().baselineKnown and A:GetDiagnostics().rows==prior,'Row overflow traversed or became complete')
rows={};for i=1,65 do rows[i]={isLocalPlayer=true,deathRecapID=i}end;A:NewEpoch(true)
check(not A:GetDiagnostics().baselineKnown,'Personal ID overflow became complete')
rows={};A:NewEpoch(true);A:Update(9,1,true);token=A:Freeze();rows={{isLocalPlayer=true,deathRecapID=30}}
id,reason,set=A:Candidate(token);check(id==30 and A:Commit(token,id,set),'Clean personal association failed')
token=A:Freeze();rows={{isLocalPlayer=true,deathRecapID=31}}
check(not A:Candidate(token),'Removed baseline IDs ignored')
A:SetEnabled(false);A:SetEnabled(true)
for i=1,A.MAX_ACCEPTED do
 rows={};A:NewEpoch(true);token=A:Freeze();rows={{isLocalPlayer=true,deathRecapID=i}}
 id,reason,set=A:Candidate(token);check(id==i and A:Commit(token,id,set),'Bounded anti-reuse set rejected a fresh own ID')
end
rows={};A:NewEpoch(true);token=A:Freeze();rows={{isLocalPlayer=true,deathRecapID=A.MAX_ACCEPTED+1}}
id,reason=A:Candidate(token);check(not id and reason=='accepted_id_limit'and A:GetDiagnostics().acceptedIDs==A.MAX_ACCEPTED,'Accepted identity storage grew unbounded or forgot anti-reuse evidence')
A:SetEnabled(false);reads=A:GetDiagnostics().reads
A:NewEpoch(true);A:Update(9,1,true);A:Candidate(token)
check(A:GetDiagnostics().reads==reads,'Disabled/reset code did native work')
print('PASS: '..checks..' native personal-ID association/epoch/ambiguity/bounds assertions (offline; native synchronization pending)')
