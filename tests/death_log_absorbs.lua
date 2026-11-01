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
print('PASS: '..checks..' bounded absorb conservation, provenance and measured hitbox assertions')
