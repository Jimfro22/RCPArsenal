-- Actual Core/recap/probe together. External hide/death ordering is injected;
-- native secret lifetime and the client's own window-close ordering are not simulated.
local f=assert(io.open('tests/hub.lua'));local source=f:read('*a');f:close()
source=source:sub(1,assert(source:find('check(db.schemaVersion == 19',1,true))-1)
source=source..[=[
local now,dead=100,false
function GetTime()return now end
function UnitIsDeadOrGhost()return dead end
function UnitGUID()return 'Player-display-lifecycle'end
function UnitClass()return 'Warrior','WARRIOR'end
function UnitHealthMax()return 100000 end
function methods:SetFormattedText(format,value)self.text=string.format(format,value)end
function methods:SetMinMaxValues(lo,hi)self.lo,self.hi=lo,hi end
function methods:UnregisterAllEvents()self.registered={}end
local function dispatch(name,...)
 event(name,...)
 for _,frame in ipairs(objects)do
  if frame~=eventFrame and frame.registered and frame.registered[name]and frame.scripts.OnEvent then
   frame.scripts.OnEvent(frame,name,...)
  end
 end
end
local P,R=RA.DeathRecapDisplayProbe,RA.DeathRecap
R:SetOption('enabled',true)
check(P:Start(),'Integrated display test failed to arm')
local window=named.RCPArsenalProtectedDisplayTest
now=101;combat=true;dispatch('PLAYER_REGEN_DISABLED')
now=102;dispatch('UNIT_COMBAT','player','WOUND','',1200,1)
now=103;dispatch('UNIT_COMBAT','player','HEAL','',300,1)
-- A UI close happens before either recorder receives PLAYER_DEAD.
window:Hide()
check(P:BuildReport():find('State: armed/recording',1,true),'Visibility closed the live recorder')
now=104;dead=true;dispatch('PLAYER_DEAD')
local page=R:GetPage();local report=P:BuildReport()
check(page and page.liveIncoming and #page.liveIncoming.rows==2,'Probe changed normal own-death capture')
check(window:IsShown()and report:find('State: frozen at own death',1,true),'Integrated death did not restore frozen test')
check(report:find('Retained 2 / 8 seconds',1,true)and report:find('text calls accepted 2',1,true),'Integrated death lost display receipts')
check(window.rows[1].amount.text=='300'and window.rows[2].amount.text=='1200','Integrated renderer lost the recorded values')
-- A later close, a refused restart while dead and normal recap review cannot erase it.
window:Hide();check(not P:Start(),'Dead restart replaced the frozen test')
check(P:Show()and window:IsShown()and P:BuildReport():find('Retained 2 / 8 seconds',1,true),'Reopen lost the frozen rows')
now=105;dispatch('UNIT_COMBAT','player','WOUND','',9000,1)
check(P:BuildReport():find('Received 2; public 2;',1,true),'Post-death callback modified frozen rows')
for _,frame in ipairs(objects)do
 if frame~=eventFrame and frame.registered then check(not frame.registered.UNIT_COMBAT,'Frozen probe retained an incoming subscription')end
end
cleanErrors()
nativePrint('PASS: '..checks..' integrated display hide/death/reopen assertions; native acceptance remains pending')
]=]
assert(loadstring(source,'display-lifecycle-integration'))()
