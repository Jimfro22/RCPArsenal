-- Small native-region mock for the separate copy dialog and actual slash routes.
local checks,created=0,0
local function check(value,message)checks=checks+1;assert(value,message)end
local secret=setmetatable({},{__tostring=function()error('Secret stringified')end})
function issecretvalue(value)return rawequal(value,secret)end
local objects,named={},{}
local methods={}
local function noop()end
local meta={__index=function(_,key)return methods[key]or noop end}
local function object(name,parent)
 local v=setmetatable({scripts={},parent=parent,shown=false,width=760,height=480},meta)
 objects[#objects+1]=v;if name then named[name]=v end;return v
end
function CreateFrame(_,name,parent)created=created+1;return object(name,parent)end
function methods:CreateFontString()return object(nil,self)end
function methods:SetScript(name,fn)self.scripts[name]=fn end
function methods:Fire(name,...)if self.scripts[name]then return self.scripts[name](self,...)end end
function methods:SetSize(w,h)self.width,self.height=w,h end
function methods:SetWidth(w)self.width=w end
function methods:SetHeight(h)self.height=h end
function methods:GetWidth()return self.width end
function methods:GetHeight()return self.height end
function methods:GetStringHeight()local _,lines=(self.text or''):gsub('\n','');return(lines+1)*14 end
function methods:SetText(text)self.text=text;self:Fire('OnTextChanged')end
function methods:GetText()return self.text end
function methods:SetMaxLetters(value)self.maxLetters=value end
function methods:SetAutoFocus(value)self.autoFocus=value end
function methods:SetFocus()self.focus=true end
function methods:ClearFocus()self.focus=false end
function methods:HighlightText()self.highlighted=true end
function methods:SetVerticalScroll(value)self.scroll=value end
function methods:SetScrollChild(value)self.child=value end
function methods:Show()self.shown=true end
function methods:Hide()self.shown=false;self:Fire('OnHide')end
UIParent=object('UIParent');UIParent:SetSize(1920,1080)
UISpecialFrames={};SlashCmdList={}
local R={};local calls={open=0,build=0,reread=0};local messages={}
local RA={DeathRecap=R,DeathRecapUI={},DeathRecapDebug={LIMITS={text=60000}},Theme={Colors={text={1,1,1,1},surfaceRaised={0,0,0,1},canvasDeep={0,0,0,1}}}}
function RA:ApplyFont()end
function RA:SetVisualText(owner,value)owner:SetText(value)end
function RA:Print(text)messages[#messages+1]=text end
function RA.Theme.SetSize(owner,w,h)owner:SetSize(w,h)end
function RA.Theme.SetPoint()end
function RA.Theme:ApplyRounded()end
function R:OpenBlizzardRecap()calls.open=calls.open+1;return true,'Requested Blizzard recap ID 17'end
function R:BuildDebugText(reread)calls.build=calls.build+1;if reread then calls.reread=calls.reread+1 end;return 'raw index 1\nnumber=100.00000000000001'end
function RA.DeathRecapDebug:StartCooldownCapture()calls.start=(calls.start or 0)+1;return true,'Armed capture'end
function RA.DeathRecapDebug:StopCooldownCapture(reason)calls.stop=(calls.stop or 0)+1;check(reason=='explicit-stop','Wrong stop reason')end
function RA.DeathRecapDebug:BuildCooldownCaptureText()calls.show=(calls.show or 0)+1;return 'bounded cooldown capture'end
assert(loadfile('RCPArsenal/DeathRecapDebugUI.lua'))('RCPArsenal',RA)
assert(loadfile('RCPArsenal/Commands.lua'))('RCPArsenal',RA)
check(created==0,'Loading debug UI created frames')
local U=RA.DeathRecapUI
for _,text in ipairs({secret,false,{},'bad|Hspell:1|h','bad\rline','bad\0line',string.rep('x',60001)})do check(not U:ShowDebugText(text),'Unsafe copy text accepted')end
check(created==0,'Rejected input created UI')
local text=string.rep('raw 17\n',80)
check(U:ShowDebugText(text),'Valid copy text rejected')
local dialog=named.RCPArsenalDeathRecapDebug;local count=created
check(dialog.shown and dialog.payload==text and dialog.box:GetText()==text,'Dialog payload changed')
check(not dialog.box.focus and dialog.box.autoFocus==false and dialog.box.maxLetters>=60000,'Copy box steals focus or truncates allowed payload')
dialog.select:Fire('OnClick');check(dialog.box.focus and dialog.box.highlighted,'Select All failed')
dialog.box:SetText('edited');check(dialog.box:GetText()==text and dialog.payload==text,'Read-only snapshot editable')
dialog.scroll:Fire('OnMouseWheel',-3);check(dialog.offset>0,'Long report did not scroll')
dialog.box:Fire('OnCursorChanged',0,-900,0,16);check(dialog.offset>0,'Cursor scroll failed')
dialog.box:Fire('OnEscapePressed');check(not dialog.shown and not dialog.box.focus,'Escape retained dialog/focus')
check(UISpecialFrames[1]=='RCPArsenalDeathRecapDebug','Escape registry missing')
U:ShowDebugText('replacement');check(created==count and dialog.payload=='replacement'and dialog.offset==0,'Reopen grew UI or retained old data/scroll')
dialog.select:Fire('OnClick');dialog.close:Fire('OnClick');check(not dialog.shown and not dialog.box.focus,'Close retained focus')
local slash=SlashCmdList.RCPARSENAL
slash('recapdebug');check(calls.build==1 and calls.reread==0 and dialog.payload=='raw index 1\nnumber=100.00000000000001','Plain slash reread or routed incorrectly')
slash('recapdebug reread');check(calls.build==2 and calls.reread==1,'Explicit reread route failed')
local priorPayload=dialog.payload
slash('recapdebug cooldowns start');check(calls.start==1 and dialog.payload==priorPayload and messages[#messages]=='Armed capture','Start opened a copy or failed to arm')
slash('recapdebug cooldowns');slash('recapdebug cooldowns show');check(calls.show==2 and calls.start==1 and dialog.payload=='bounded cooldown capture','Show rearmed or failed to open immutable copy')
slash('recapdebug cooldowns stop');check(calls.stop==1 and calls.show==3,'Stop did not finalize and show')
slash('recapdebug capability');check(calls.start==1 and calls.build==2,'Removed capability command still queried')
slash('recapdebug 17');check(calls.build==2 and messages[#messages]=='Usage: /rcp recapdebug [reread] or cooldowns [start||stop||show]','Unexpected debug arg executed')
slash('recapblizzard 17');check(calls.open==0,'Slash supplied ID allowed')
slash('recapblizzard');check(calls.open==1 and messages[#messages]=='Requested Blizzard recap ID 17','Native request route failed')
R.BuildDebugText=function()return nil,'No captured page'end
local prior=dialog.payload;slash('recapdebug');check(messages[#messages]=='No captured page'and dialog.payload==prior,'Failure changed reviewable payload')
print('PASS: '..checks..' diagnostic copy UI/command assertions (offline)')
