-- Actual HealingSupplies, PersonalTools and NativeWarningAudio together.
-- Reuse the item/opaque-health fixture; each lifecycle has isolated globals.
local checks = 0
local function check(value, message) checks = checks + 1; assert(value, message) end
local file = assert(io.open('tests/personal_tools.lua'))
local source = file:read('*a'); file:close()
source = source:sub(1, assert(source:find('local tools = loadTools()', 1, true)) - 1)
local function Lifecycle()
    local env = setmetatable({}, {__index = _G}); env._G = env
    env.loadfile = function(path)
        local chunk, err = loadfile(path)
        if chunk then setfenv(chunk, env) end
        return chunk, err
    end
    local chunk = assert(loadstring(source .. [[
local tools = loadTools({autoRes=false, consumableReminder=false, reminderCombat='IN_COMBAT'})
local audioEvents, personalEvents, registry = {}, {}, {}
for name, fn in pairs(events) do personalEvents[name] = fn end
local registerEvent, fireCallback = RA.RegisterEvent, RA.FireCallback
function RA:RegisterEvent(name, fn) audioEvents[name] = fn; registerEvent(self, name, fn) end
function RA:RegisterCallback(name, fn)
    local previous = callbacks[name]
    callbacks[name] = function(...) if previous then previous(...) end; fn(...) end
end
function RA:FireCallback(name, ...)
    fireCallback(self, name, ...)
    if callbacks[name] then callbacks[name](...) end
end
local native = {shown=false, hooks={}, hookCalls=0}
function native:HookScript(name, fn)
    self.hookCalls=self.hookCalls+1; self.hooks[name]=fn; return true
end
function native:IsShown() return self.shown end
function native:IsVisible() return self.shown end
function native:Fire(name) if self.hooks[name] then self.hooks[name](self) end end
function native:Show() self.shown=true; self:Fire('OnShow') end
function native:Hide() self.shown=false; self:Fire('OnHide') end
for _, name in ipairs({'GetAlpha','GetEffectiveAlpha','SetAlpha','SetScript','DetermineFlashState'}) do
    native[name]=function() error('Native health read/mutation: '..name) end
end
LowHealthFrame = native
function UIParent:IsVisible() return true end
EventRegistry = {RegisterCallback=function(_, name, fn) registry[name]=fn end}
function GetCVarBool(name) return name ~= 'doNotFlashLowHealthWarning' end
function GetCVar() return '1' end
function GetUIPanel() return nil end
CinematicFrame, MovieFrame = nil, nil
local plays, stops, nextHandle, playback = {}, {}, 1000, true
function PlaySoundFile(path, channel)
    nextHandle=nextHandle+1
    plays[#plays+1]={path=path,channel=channel,handle=nextHandle}
    return playback, nextHandle
end
function StopSound(handle) stops[#stops+1]=handle end
function SetCVar() error('No audio CVar mutation') end
local bagCalls = 0
local slots = C_Container.GetContainerNumSlots
C_Container.GetContainerNumSlots = function(...) bagCalls=bagCalls+1; return slots(...) end
local firstAudioInitializer = #initializers+1
assert(loadfile('RCPArsenal/NativeWarningAudio.lua'))('RCPArsenal', RA)
for index=firstAudioInitializer,#initializers do initializers[index]() end
events.PLAYER_ENTERING_WORLD('PLAYER_ENTERING_WORLD')
local h = {tools=tools, audio=RA.NativeWarningAudio, native=native, plays=plays, stops=stops, secret=secret}
function h:ready(id) return ready(id) end
function h:empty() items={} end
function h:combat(value) combat=value end
function h:itemError(value) itemError=value end
function h:clock(value) now=value end
function h:playback(value) playback=value end
function h:signal(name, ...) if events[name] then events[name](name, ...) end end
function h:audioFirst(name)
    if audioEvents[name] then audioEvents[name](name) end
    if personalEvents[name] then personalEvents[name](name) end
end
function h:expiry()
    for _, timer in ipairs(timers) do
        if not timer.cancelled and not timer.fired then timer.callback(); return true end
    end
    return false
end
function h:metrics()
    return {bags=bagCalls,items=itemCalls,cooldowns=cooldownCalls,usability=usabilityCalls,
        health=healthCalls,frames=#frames,timers=#timers,tickers=#tickers}
end
function h:caption() return frames[2] and frames[2].strings[1].text end
return h
]]))
    setfenv(chunk, env)
    return chunk()
end
local function sameItemWork(a, b)
    return a.bags == b.bags and a.items == b.items and a.cooldowns == b.cooldowns and a.usability == b.usability
end

local cases = {
    {name='empty', ready=false, setup=function() end},
    {name='all cooling', ready=false, setup=function(h)
        local stone=h:ready(5512); stone.start=100; stone.duration=20; stone.usable=false
        local potion=h:ready(271884); potion.start=100; potion.duration=30; potion.usable=false
    end},
    {name='unknown cooldown', ready=false, setup=function(h) h:ready(5512).start=h.secret end},
    {name='unusable', ready=false, setup=function(h) h:ready(5512).usable=false end},
    {name='unknown inventory', ready=false, setup=function(h) h:itemError(true) end},
    {name='ready stone', ready=true, item=5512, setup=function(h) h:ready(5512) end},
    {name='ready potion', ready=true, item=271884, setup=function(h) h:ready(271884) end},
    {name='cooling stone and ready potion', ready=true, item=271884, setup=function(h)
        local stone=h:ready(5512); stone.start=100; stone.duration=20; stone.usable=false
        h:ready(271884)
    end},
}
for _, case in ipairs(cases) do
    for _, showCooldown in ipairs({false, true}) do
        local h=Lifecycle(); h:combat(true); case.setup(h)
        h.tools:SetOption('reminderShowOnCooldown',showCooldown)
        h.tools:SetOption('consumableReminder',true)
        check(h.tools:GetNativeSoundEligibility()==case.ready, case.name..': cached eligibility wrong')
        if case.item then check(h.tools:GetState().itemID==case.item, case.name..': visual selection changed') end
        if case.name=='empty' then check(h:caption()=='OUT OF POTIONS!', 'Empty visual lost while silencing sound') end
        if showCooldown and case.name=='all cooling' then
            check(h.tools:GetState().itemID==5512, 'Show-on-cooldown visual was suppressed by audio policy')
        end
        local before=h:metrics()
        h.native:Show(); h.native:Fire('OnShow'); h:signal('UNIT_HEALTH','player'); h.tools:GetNativeSoundEligibility()
        check(#h.plays==(case.ready and 1 or 0), case.name..': automatic playback ignored ready supply')
        check(sameItemWork(before,h:metrics()), case.name..': health/native hook queried items')
        if case.ready then
            check(h.plays[1].path:find('RCP_Sound06.ogg',1,true) and h.plays[1].channel=='Master', 'Automatic warning did not use Sound 6')
        end
    end
end

-- Loss stops only our automatic handle, even when the displayed item stays
-- the same under Show on cooldown. Recovery during low health never catches up.
for _, loss in ipairs({'empty','cooldown','unknown'}) do
    local h=Lifecycle(); h:combat(true); h:ready(5512)
    h.tools:SetOption('reminderShowOnCooldown',true); h.tools:SetOption('consumableReminder',true)
    h.native:Show(); check(#h.plays==1, 'Ready initial warning did not play')
    h.audio:Preview(); local automatic, preview=h.plays[1].handle,h.plays[2].handle
    if loss=='empty' then h:empty()
    elseif loss=='cooldown' then local stone=h:ready(5512); stone.start=100;stone.duration=20;stone.usable=false
    else h:ready(5512).start=h.secret end
    h:signal(loss=='empty' and 'BAG_UPDATE_DELAYED' or 'BAG_UPDATE_COOLDOWN')
    check(not h.tools:GetNativeSoundEligibility() and #h.stops==1 and h.stops[1]==automatic and h.stops[1]~=preview,
        loss..': supply loss did not stop only automatic handle')
    h:ready(5512);h:signal('BAG_UPDATE_DELAYED')
    local before=h:metrics()
    h.native:Fire('OnShow');h:signal('UNIT_HEALTH','player');h:signal('BAG_UPDATE_COOLDOWN')
    check(#h.plays==2 and h.tools:GetNativeSoundEligibility(), loss..': recovery caught up or rearmed active warning')
    check(sameItemWork(before,h:metrics())==false, 'Cooldown signal did not reconcile readiness')
    h.native:Hide();h.native:Show()
    check(#h.plays==3, loss..': eligible clear/new warning did not recover')
end

-- A public cached-candidate expiry can restore eligibility, never playback.
local h=Lifecycle();h:combat(true)
local stone=h:ready(5512);stone.start=100;stone.duration=2
h.tools:SetOption('consumableReminder',true);h.native:Show()
check(#h.plays==0 and not h.tools:GetNativeSoundEligibility(), 'Cooling item warned before expiry')
h:clock(102.05);local before=h:metrics();check(h:expiry(), 'Existing public expiry was not scheduled')
check(h:metrics().bags==before.bags and h.tools:GetNativeSoundEligibility() and #h.plays==0, 'Expiry scanned bags or caught up while low')
h.native:Hide();h.native:Show();check(#h.plays==1,'Post-expiry eligible clear/new warning failed')

-- Native/addon combat callback ordering cannot catch up on a warning that
-- began before the newly allowed policy had a ready cache.
for _, audioFirst in ipairs({false,true}) do
    h=Lifecycle();h:ready(271884);h.tools:SetOption('consumableReminder',true)
    h:combat(true);h.native:Show()
    if audioFirst then h:audioFirst('PLAYER_REGEN_DISABLED') else h:signal('PLAYER_REGEN_DISABLED') end
    h.native:Fire('OnShow')
    check(h.tools:GetNativeSoundEligibility() and #h.plays==0,'Combat ordering created catch-up sound')
    h.native:Hide();h.native:Show();check(#h.plays==1,'Combat ordering prevented a new eligible episode')
end

-- Preview is explicit, independent of inventory/master, and cannot rearm.
h=Lifecycle();before=h:metrics()
check(h.audio:Preview() and #h.plays==1 and not h.tools:GetState().consumableReminder,'Empty/OFF manual Preview was blocked or enabled master')
check(sameItemWork(before,h:metrics()) and h.native.hookCalls==0,'Manual Preview queried items or bound native warning')
h:combat(true);h.tools:SetOption('consumableReminder',true);h.native:Show()
check(h.audio:Preview() and #h.plays==2,'Empty enabled manual Preview was blocked')
h:ready(271884);h:signal('BAG_UPDATE_DELAYED');h.native:Fire('OnShow')
check(#h.plays==2,'Preview or supply gain rearmed an active warning')
h.tools:SetOption('consumableReminder',false);before=h:metrics()
for _=1,3 do
    for _, event in ipairs({'BAG_UPDATE_DELAYED','BAG_UPDATE_COOLDOWN','ACTION_USABLE_CHANGED','UNIT_HEALTH','PLAYER_REGEN_DISABLED'}) do h:signal(event,'player') end
    h.native:Hide();h.native:Show()
end
check(sameItemWork(before,h:metrics()) and h:metrics().health==before.health and #h.plays==2,'Disabled late hooks/events did work or played')
h=Lifecycle();before=h:metrics()
check(before.frames==0 and before.bags==0 and before.cooldowns==0 and before.timers==0 and before.tickers==0 and h.native.hookCalls==0,
    'Fresh disabled lifecycle allocated/scanned/bound')
h:combat(true);h:ready(271884);h.tools:SetOption('consumableReminder',true);h.native:Show()
before=h:metrics();local stopsBefore=#h.stops
h.tools:SetOption('reminderStoneGlow',false);h.tools:SetOption('reminderStoneGlow',true);h.native:Fire('OnShow')
for _,style in ipairs({'PIXEL','BUTTON','AUTOCAST','STEADY'}) do h.tools:SetGlowOption('style',style);h.tools:SetGlowOption('color',{0.2,0.4,0.6}) end
h.tools:ResetGlowSettings();h.native:Fire('OnShow')
check(sameItemWork(before,h:metrics()) and #h.plays==1 and #h.stops==stopsBefore and h.tools:GetNativeSoundEligibility(),
    'Icon glow edits refreshed supply readiness or reset/replayed/stopped automatic audio')
print(('PASS: %d integrated consumable/audio assertions (actual modules; offline item/native mocks)'):format(checks))
