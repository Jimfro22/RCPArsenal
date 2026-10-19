-- Actual manual protocol, bounded identity/snapshot mocks. No WoW/network/FPS proof.
local checks=0
local function check(v,m) checks=checks+1;assert(v,m) end
local secret={}
function issecretvalue(v) return v==secret end
local now, combat, encounter, raid, restricted, registered, sendResult
local events, callbacks, init, sent, timers, scans, rosterCalls, roster, bags
function GetTime() return now end
function InCombatLockdown() return combat end
function IsEncounterInProgress() return encounter end
function IsInRaid() return raid end
local function copy(t) local out={};for k,v in pairs(t) do out[k]=type(v)=='table' and copy(v) or v end;return out end
local RA,S
local function setup()
    now,combat,encounter,raid,restricted,registered,sendResult=100,false,false,true,nil,true,0
    events,callbacks,init,sent,timers,scans,rosterCalls={},{},{},{},{},0,0
    bags={stone=true,potion=false}
    local lead={name='Lead-Realm',guid='P1',leader=true,isPlayer=true,online=true}
    local assist={name='Assist-Realm',guid='P2',assistant=true,online=true}
    local member={name='Member-Realm',guid='P3',online=true}
    local offline={name='Offline-Realm',guid='P4',online=false}
    roster={list={lead,assist,member,offline},byGUID={},fingerprint='one'}
    for _,m in ipairs(roster.list) do roster.byGUID[m.guid]=m end
    C_ChatInfo={RegisterAddonMessagePrefix=function() return registered end,SendAddonMessage=function(prefix,packet,channel,target)
        sent[#sent+1]={prefix=prefix,packet=packet,channel=channel,target=target};return sendResult end}
    C_Timer={NewTimer=function(delay,fn) local t={delay=delay,fn=fn};function t:Cancel() self.cancelled=true end;timers[#timers+1]=t;return t end,
        NewTicker=function() error('No polling') end,After=function() error('No retry') end}
    RA={Readiness={GetRestrictionReason=function() return restricted end,
        GetGroupIdentitySnapshot=function() rosterCalls=rosterCalls+1;return copy(roster),'RAID' end,
        ResolveRosterSender=function(_,r,name)
            for _,m in ipairs(r.list) do if m.name:lower()==name:lower() then return m end end
        end},HealingSupplies={MAP_REVISION=1,Snapshot=function() scans=scans+1;return copy(bags) end}}
    function RA:RegisterEvent(name,fn) events[name]=fn end
    function RA:RegisterCallback(name,fn) callbacks[name]=fn end
    function RA:RegisterInitializer(fn) init[#init+1]=fn end
    function RA:FireCallback(name) check(name=='SUPPLIES_UPDATED','Wrong callback') end
    assert(loadfile('RCPArsenal/SupplyCheck.lua'))('RCPArsenal',RA);S=RA.SupplyCheck
    for _,fn in ipairs(init) do fn() end
end
local function recv(packet,sender,channel,prefix) events.CHAT_MSG_ADDON('CHAT_MSG_ADDON',prefix or S.PREFIX,packet,channel or 'WHISPER',sender or 'Assist-Realm') end
local function nonce() return sent[1].packet:match('^Q|1|([^|]+)|1$') end
setup()
check(scans==0 and #timers==0 and #sent==0 and rosterCalls==0,'Initialization must do no inventory/network/timer/roster work')
for i=1,50 do S:GetSnapshot() end
for _,event in ipairs({'GROUP_ROSTER_UPDATE','PLAYER_REGEN_DISABLED','ENCOUNTER_START','PLAYER_ENTERING_WORLD'}) do events[event]() end
check(scans==0 and #timers==0 and #sent==0 and rosterCalls==0,'Idle UI/events must do no inventory/network/timer/roster work')
for i=1,100 do recv('unrelated','Member-Realm','RAID','OtherAddon');recv('Q|2|abc-1-1|1','Assist-Realm','RAID') end
check(rosterCalls==0 and scans==0,'Unrelated traffic caused work')
for _,case in ipairs({'combat','secret combat','unknown combat','encounter','not raid','restricted','member','send fail'}) do
    setup()
    if case=='combat' then combat=true elseif case=='secret combat' then combat=secret elseif case=='unknown combat' then combat=nil
    elseif case=='encounter' then encounter=true elseif case=='not raid' then raid=false elseif case=='restricted' then restricted='Restricted'
    elseif case=='member' then roster.list[1].leader=false elseif case=='send fail' then sendResult=3 end
    check(not S:Query() and scans==0 and #timers==0,'Ineligible request scanned/started: '..case)
end
setup();check(S:Query(),'Leader query refused');local n=nonce()
check(scans==1 and #sent==1 and #timers==1 and timers[1].delay==12,'One request must do one local snapshot + one window timer')
check(not S:Query() and scans==1 and #sent==1,'Pending click duplicated query')
local snap=S:GetSnapshot();check(snap.rows[1].stone==true and snap.rows[1].potion==false and snap.rows[2].status=='no_reply' and snap.rows[4].status=='offline','Zero/no reply/offline distinction lost')
snap.rows[1].potion=true;check(S:GetSnapshot().rows[1].potion==false,'UI mutated protocol snapshot')
for _,packet in ipairs({'R|1|abc-1-1|1|1|1','R|1|'..n..'|2|1|1','R|1|'..n..'|1|2|1','R|1|'..n..'|1|1|1|extra'}) do recv(packet) end
check(S:GetSnapshot().rows[2].status=='no_reply','Malformed/stale/unsupported reply accepted')
recv('R|1|'..n..'|1|0|u')
snap=S:GetSnapshot();check(snap.rows[2].stone==false and snap.rows[2].potion==nil and snap.rows[2].status=='reported','Known zero versus unknown lost')
local before=rosterCalls
for i=1,100 do recv('R|1|'..n..'|1|1|1');recv('R|1|'..n..'|1|1|1','Outsider-Realm') end
check(rosterCalls==before and scans==1,'Duplicate/outsider replies caused native roster or bag work')
recv('R|1|'..n..'|1|1|1','Member-Realm','RAID');check(S:GetSnapshot().rows[3].status=='no_reply','Non-whisper response accepted')
now=113;timers[1].fn();snap=S:GetSnapshot();check(snap.status=='complete' and snap.rows[3].status=='no_reply','Finite timeout changed no reply into zero')
recv('R|1|'..n..'|1|1|1','Member-Realm');check(S:GetSnapshot().rows[3].status=='no_reply','Late response accepted')
check(not S:Query() and scans==1,'Cooldown allowed another scan')
now=121;check(S:Query() and scans==2,'Explicit check after cooldown failed')
n=sent[#sent].packet:match('^Q|1|([^|]+)|1$')
roster.fingerprint='changed';recv('R|1|'..n..'|1|1|1')
check(S:GetSnapshot().status=='stale' and timers[#timers].cancelled,'Roster mismatch did not cancel window')
setup();S:Query();local t=timers[1];events.PLAYER_REGEN_DISABLED()
check(t.cancelled and S:GetSnapshot().status=='stale' and scans==1,'Combat did not cancel without more bag work')
-- Responder permits one authorized request/snapshot/reply, irrespective of UI or personal opt-in.
setup();recv('Q|1|abc-1-1|1','Member-Realm','RAID');check(scans==0 and #sent==0,'Member request accepted')
recv('Q|1|abc-1-1|1','Assist-Realm','WHISPER');check(scans==0,'Whisper query accepted')
recv('Q|1|abc-1-1|1','Assist-Realm','RAID')
check(scans==1 and #sent==1 and #timers==0 and sent[1].packet=='R|1|abc-1-1|1|1|0' and sent[1].target=='Assist-Realm','One bounded bags-only response failed')
for i=1,100 do recv('Q|1|abc-1-1|1','Assist-Realm','RAID');recv('Q|1|abc-2-1|1','Assist-Realm','RAID') end
check(scans==1 and #sent==1,'Responder rate limit/replay failed')
now=121;recv('Q|1|abc-1-1|1','Assist-Realm','RAID');check(scans==1,'Old nonce replay accepted')
bags={};recv('Q|1|abc-2-1|1','Assist-Realm','RAID')
check(scans==2 and sent[2].packet=='R|1|abc-2-1|1|u|u','Unknown inventory reported as zero')
setup();for i=1,100 do recv('Q|1|abc-'..string.format('%x',i)..'-1|1','Member-Realm','RAID') end
check(rosterCalls==8 and scans==0,'Unapproved inbound query work not bounded')
setup();combat=secret;recv('Q|1|abc-1-1|1','Assist-Realm','RAID');check(scans==0 and rosterCalls==0,'Secret combat allowed request')
print('PASS: '..checks..' manual supply protocol assertions (actual module; bounded offline mocks)')
