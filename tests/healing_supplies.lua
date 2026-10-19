-- Actual bounded inventory module, mocked public native APIs; no native FPS claim.
local checks, ids, info, metadata, spells, cached, calls, fault, sizes = 0
local secret = {}
function issecretvalue(v) return v == secret end
local function check(v,m) checks=checks+1; assert(v,m) end
local function setup()
    ids,info,metadata,spells,cached,calls,fault,sizes={},{},{},{},{},{slots=0,id=0,info=0,meta=0,spell=0},nil,{}
end
setup()
C_Container={
    GetContainerNumSlots=function(bag) check(bag>=0 and bag<=5,'Bank accessed');calls.slots=calls.slots+1;return sizes[bag] or (bag==0 and #ids or 0) end,
    GetContainerItemID=function(bag,slot) calls.id=calls.id+1;if fault=='id' then error('missing') end;return bag==0 and ids[slot] or nil end,
    GetContainerItemInfo=function(bag,slot) calls.info=calls.info+1;if fault=='info' then error('missing') end;return info[ids[slot]] end,
}
C_Item={
    GetItemInfoInstant=function(id) calls.meta=calls.meta+1;local m=metadata[id] or {};return id,nil,nil,nil,nil,m[1],m[2] end,
    IsItemDataCachedByID=function(id) return cached[id] end,
    GetItemSpell=function(id) calls.spell=calls.spell+1;return nil,spells[id] end,
    RequestLoadItemDataByID=function() error('No data loads') end,
    GetItemCount=function() error('No separate bag/bank/count scans') end,
    GetItemCooldown=function() error('No cooldown query') end,
    IsUsableItem=function() error('No usability query') end,
}
local RA={};assert(loadfile('RCPArsenal/HealingSupplies.lua'))('RCPArsenal',RA)
local S=RA.HealingSupplies
local function put(id,count,icon) ids[#ids+1]=id;info[id]={stackCount=count or 1,iconFileID=icon} end
local r=S:Snapshot();check(r.stone==false and r.potion==false and calls.slots==6 and calls.id==0,'Empty bags known zero')
for _,id in ipairs({271884,271883,241304,241305}) do
    setup();put(id,1);r=S:Snapshot()
    check(r.potion==true and r.stone==false and r.itemID==id and calls.meta==0 and calls.spell==0,'Known family lost without spell/icon cache')
end
setup();put(241304,10,101);put(5512,1,202);put(224464,1,303);put(271884,2,404)
r=S:Snapshot();check(r.stone==true and r.potion==true and r.itemID==224464 and r.icon==303,'Stone priority or separate report lost')
setup();put(241305);put(271883);put(241304);put(271884);r=S:Snapshot();check(r.itemID==271884,'Potion priority lost')
for _,id in ipairs({241300,241288,241308}) do
    setup();put(id);r=S:Snapshot();check(r.potion==false and not r.itemID and calls.meta==0,'Non-healing potion accepted')
end
setup();put(99999);metadata[99999]={0,1};cached[99999]=true;spells[99999]=1295247
r=S:Snapshot();check(r.potion==true and r.itemID==99999,'Audited use-spell family fallback lost')
for _,spec in ipairs({{0,1,999}, {0,1,1236648}, {0,1,1236994}, {0,1,1236616}, {2,1,1295247}}) do
    setup();put(99999);metadata[99999]={spec[1],spec[2]};cached[99999]=true;spells[99999]=spec[3]
    r=S:Snapshot();check(r.potion~=true and not r.itemID,'Unrelated family falsely healing')
    if spec[3]==999 then check(r.potion==nil,'Unrecognized potion became zero') end
end
for _,case in ipairs({'missing metadata','missing spell','uncached','secret count','missing count','secret class','secret id','failed id','failed info'}) do
    setup();put(99999);metadata[99999]={0,1};cached[99999]=true;spells[99999]=1295247
    if case=='missing metadata' then metadata[99999]=nil
    elseif case=='missing spell' then spells[99999]=nil
    elseif case=='uncached' then cached[99999]=false
    elseif case=='secret count' then info[99999].stackCount=secret
    elseif case=='missing count' then info[99999].stackCount=nil
    elseif case=='secret class' then metadata[99999][1]=secret
    elseif case=='secret id' then ids[1]=secret
    elseif case=='failed id' then fault='id'
    elseif case=='failed info' then fault='info' end
    r=S:Snapshot();check(r.potion==nil and not r.itemID,'Unavailable data became zero/carried: '..case)
    if case=='uncached' then check(calls.spell==0,'Uncached spell lookup attempted') end
end
setup();put(271884,secret);r=S:Snapshot();check(r.potion==nil and not r.itemID,'Known ID secret count became carried/zero')
setup();put(5512,secret);r=S:Snapshot();check(r.stone==nil and not r.itemID,'Secret stone count became known')
setup();put(5512);put(99999);r=S:Snapshot();check(r.stone==true and r.potion==nil and r.itemID==5512,'Unknown potion erased affirmative stone')
setup();sizes[0]=101;r=S:Snapshot();check(r.stone==nil and r.potion==nil and calls.id==0,'Oversized bag not bounded/unknown')
setup();for bag=0,5 do sizes[bag]=100 end
r=S:Snapshot();check(calls.slots==6 and calls.id==600 and r.slots==600,'Worst-case bag bound differs')
setup();local containers=C_Container;C_Container=nil;r=S:Snapshot();C_Container=containers
check(r.stone==nil and r.potion==nil,'Missing API became empty')
print('PASS: '..checks..' healing inventory assertions (actual module; bounded offline API mocks)')
