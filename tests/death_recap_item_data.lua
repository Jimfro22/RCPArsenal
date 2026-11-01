local f=assert(io.open('tests/death_recap.lua'));local source=f:read('*a');f:close()
source=source:sub(1,assert(source:find('check(optionalCount()==0',1,true))-1)
source=source..[=[
local loaded=false;bagIDs={99999}
C_Item.GetItemInfoInstant=function(id)return id,nil,nil,nil,nil,0,1 end
C_Item.IsItemDataCachedByID=function()return loaded end
C_Item.GetItemSpell=function()return 'Healing',1295247 end
C_Item.GetItemCount=function()return 1 end
combat=true;R:SetOption('enabled',true)
local cached=RA.HealingSupplies:GetCached('recap');check(cached.pending[99999]and cached.partial,'Fixture lacks unresolved item data')
local before=R:GetDiagnostics();local bags=bagReads
event('ITEM_DATA_LOAD_RESULT',12345,true);event('ITEM_DATA_LOAD_RESULT',99999,false)
check(bagReads==bags and R:GetDiagnostics().itemQueries==before.itemQueries,'Unrelated/failed item load refreshed supplies')
loaded=true;time=11;event('ITEM_DATA_LOAD_RESULT',99999,true)
check(bagReads==bags+6 and R:GetDiagnostics().spellQueries==before.spellQueries,'Resolved item load duplicated scan or queried spells')
cached=RA.HealingSupplies:GetCached('recap');check(cached.potion==true and cached.candidates[1].id==99999,'Resolved healing item failed to enter shared cache')
local items=R:GetDiagnostics().itemQueries;event('ITEM_DATA_LOAD_RESULT',99999,true)
check(bagReads==bags+6 and R:GetDiagnostics().itemQueries==items,'Duplicate completion reread cached item')
dead=true;time=12;event('PLAYER_DEAD');local row=R:GetPage().lastAlive.supplies[2]
check(row.itemID==99999 and row.observedAt==11 and row.physicalCount==1,'Resolved item evidence not captured before death')
print('PASS: '..checks..' pending item-data completion and spell/item query-isolation assertions')
]=]
assert(loadstring(source,'death-recap-item-data-fixture'))()
