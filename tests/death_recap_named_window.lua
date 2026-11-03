-- Actual UI regression: large recent damage must not hide earlier supplied
-- small/fully absorbed hits. This is synthetic data, not a native API proof.
local function Read(path)local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local source=Read('tests/hub.lua');source=source:sub(1,assert(source:find('check(db.schemaVersion == 19',1,true))-1)
local ui=Read('tests/death_recap_ui.lua');local marker='source=source..[=[';local start=assert(ui:find(marker,1,true))+#marker
source=source..ui:sub(start,assert(ui:find('local groupCalls=',start,true))-1)
source=source..[=[
local rows={};local offsets={0,-.7,-1.3,-2.2,-3.3,-4.2,-4.8,-5.4,-6.7,-7.8}
for i,time in ipairs(offsets)do rows[i]={nativeIndex=i,nativeOffset=time,timestamp=2000+time,
 kind='damage',spellID=700+i,name='Synthetic hit '..i,amount=i==1 and 10000000 or i==2 and 100000 or 1,
 absorbed=i>7 and 1 or nil,recordedHP=800000}end
local page={id=1,diedAt=100,class='MAGE',specID=64,casts={},lastAlive={spells={},supplies={}},
 native={recapID=1,recapMaxHealth=1000000,rows=rows}}
R.GetPage=function()return page end;R.GetHistory=function()return{page}end;R.IsRetainedPage=function(self,p)return p==page end
for _,restored in ipairs({false,true})do
 page.restored=restored;U:ShowLast();local popup=named.RCPArsenalDeathRecap
 check(popup.timeDomain.first==-8 and popup.timeDomain.last==0,'Real record shortened to a five-second window')
 check(#popup.viewport.rows==10 and popup.viewport.omitted==0,'Magnitude filter hid supplied small hits inside eight seconds')
 local seen,total={},0
 for _,obj in ipairs(objects)do if obj.parent==popup and obj.group and obj:IsVisible()then
  for _,row in ipairs(obj.group.rows)do check(not seen[row.nativeIndex],'UI duplicated a named hit');seen[row.nativeIndex]=true;total=total+1
   check(row==rows[row.nativeIndex]and row.timestamp==2000+offsets[row.nativeIndex],'Display rewrote raw identity/time')
  end
 end end
 check(total==10 and seen[8]and seen[9]and seen[10],'Earlier retained rows never reached visible icons')
 check(popup.supportMarkerCount>0,'Fully absorbed earlier hits lost their support markers')
end
page.native.recapMaxHealth=nil;U:ShowLast()
check(#named.RCPArsenalDeathRecap.viewport.rows==10,'Missing max health hid known earlier hits')
U:Preview();check(named.RCPArsenalDeathRecap.timeDomain.first==-5,'Live coverage policy changed the approved example composition')
io.write('PASS: '..checks..' actual-UI full-window, outlier, absorbed-hit, saved-record and immutable-row assertions\n')
]=]
assert(loadstring(source,'named-window-regression'))()
