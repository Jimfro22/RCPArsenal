local checks=0;local function check(v,m)checks=checks+1;assert(v,m)end
local RA={};assert(loadfile('RCPArsenal/DeathLogModel.lua'))('RCPArsenal',RA)
local M=RA.DeathLogModel
for _,count in ipairs({1,2,10,64})do
    for _,equal in ipairs({true,false})do
        local rows={};local expected=0
        for i=1,count do rows[i]={nativeIndex=i,nativeOffset=equal and -1 or -1+i*.003,kind='damage',absorbed=i*100+1};expected=expected+rows[i].absorbed end
        local function X(t)return 48+(t+1)*784 end
        local groups=M:GroupAbsorbs(rows,X,function(amount,n)return 50+(n>1 and 24 or 0)end)
        local seen,total,ends={},0,{}
        for _,g in ipairs(groups)do
            check(g.lane<=2 and g.x-g.width/2>=48 and g.x+g.width/2<=832,'Absorb label/hitbox escaped bounds or third lane')
            check(not ends[g.lane]or g.x-g.width/2>=ends[g.lane]+2,'Absorb hitboxes overlap');ends[g.lane]=g.x+g.width/2
            local sum=0;for _,row in ipairs(g.rows)do check(not seen[row.nativeIndex],'Absorb member duplicated');seen[row.nativeIndex]=true;sum=sum+row.absorbed end
            check(sum==g.amount and g.first==g.rows[1].nativeOffset and g.last==g.rows[#g.rows].nativeOffset,'Cluster total or true interval changed')
            total=total+g.amount
        end
        check(total==expected,'Absorb total not conserved')
        for i,row in ipairs(rows)do check(seen[i]and row.nativeIndex==i and row.absorbed==i*100+1,'Absorb member dropped or mutated')end
    end
end
local groups=M:GroupAbsorbs({{nativeIndex=1,nativeOffset=0,kind='damage'},{nativeIndex=2,nativeOffset=0,kind='unknown',absorbed=10},{nativeIndex=3,nativeOffset=0,kind='damage',absorbed=0}},function()return 500 end,function()return 50 end)
check(#groups==0,'Unknown/missing/zero absorption invented a positive credit')
-- Identical native times coalesce before layout. This is a generic absorption
-- total even when incoming spells, actors and retained HP values are different.
local mixed={
 {nativeIndex=5,timestamp=100,nativeOffset=-.6,kind='damage',spellID=55,sourceKey='A',sourceConfirmed=true,recordedHP=3000,absorbed=1000},
 {nativeIndex=3,timestamp=100,nativeOffset=-.6,kind='damage',spellID=33,sourceKey='B',sourceConfirmed=true,recordedHP=2000,absorbed=2000},
 {nativeIndex=4,timestamp=100,nativeOffset=-.6,kind='damage',spellID=44,sourceKey='C',sourceConfirmed=true,recordedHP=1000,absorbed=7},
 {nativeIndex=2,timestamp=99.999999,nativeOffset=-.600001,kind='damage',spellID=22,recordedHP=4000,absorbed=400},
}
local before={};for i,row in ipairs(mixed)do before[i]={row=row,hp=row.recordedHP,time=row.timestamp}end
local measured={}
groups=M:GroupAbsorbs(mixed,function(t)return 400+(t+.6)*100 end,function(amount,count)measured[#measured+1]={amount,count};return 40 end)
check(#groups==2 and #groups[1].rows==1 and #groups[2].rows==3,'Exact-time coalescing rounded near times or split equal-time members')
local together=groups[2]
check(together.amount==3007 and together.first==-.6 and together.last==-.6 and measured[2][1]==3007 and measured[2][2]==3,'Equal-time total was not complete before layout measurement')
check(together.spellID==nil and together.sourceKey==nil and together.shieldSpellID==nil,'Mixed absorption cluster claimed shared spell/source/shield identity')
for i,index in ipairs({3,4,5})do check(together.rows[i].nativeIndex==index,'Exact-time member order lost retained native-index ties')end
for i,saved in ipairs(before)do check(mixed[i]==saved.row and mixed[i].recordedHP==saved.hp and mixed[i].timestamp==saved.time,'Absorption grouping mutated the raw input order, HP or time')end
local damage=M:Group(mixed,{},{items=16})
check(#damage.rows==4 and #damage.items==4,'Generic absorption clustering changed damage semantic groups')

local owner=assert(loadfile('tests/fixtures/death_log/owner_recap_3066.lua'))().NewPage()
groups=M:GroupAbsorbs(owner.native.rows,function(t)return 48+(t+1.804)/1.804*784 end,function()return 40 end)
local saber
for _,group in ipairs(groups)do if #group.rows==3 and group.rows[1].nativeIndex==3 then saber=group end end
check(saber and saber.amount==5001 and saber.first==saber.last,'Owner three tied Saber credits did not form one 5001 total')
for i,index in ipairs({3,4,5})do check(saber.rows[i]==owner.native.rows[index]and saber.rows[i].absorbed==1667,'Owner tied Saber hit was deduplicated or its credit rewritten')end
check(owner.native.rows[3].recordedHP==88095 and owner.native.rows[4].recordedHP==103195 and owner.native.rows[5].recordedHP==118295,'Owner tied HP values changed during absorption coalescing')
print('PASS: '..checks..' bounded absorb conservation, provenance and measured hitbox assertions')
