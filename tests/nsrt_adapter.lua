-- Lua 5.1 adapter contract harness. Real-client lifecycle and taint remain manual.
local checks = 0
local function check(value, message) checks = checks + 1; assert(value, message) end
local function copy(value) if type(value) ~= "table" then return value end; local out = {}; for k,v in pairs(value) do out[k] = copy(v) end; return out end
local function equal(a,b) if type(a)~=type(b) then return false end; if type(a)~="table" then return a==b end; for k,v in pairs(a) do if not equal(v,b[k]) then return false end end; for k in pairs(b) do if a[k]==nil then return false end end; return true end
local combat, encounter, restricted, secret, clock, timers, calls, events, callbacks, init, notices, exports, version, engine, adapter
local function record(name) calls[#calls+1] = name end
local function event(name, ...) for _, fn in ipairs(events[name] or {}) do fn(name,...) end end
local function advance(seconds)
    local stop = clock + seconds
    local iterations = 0
    while true do
        local first
        for _, timer in ipairs(timers) do if not timer.cancelled and not timer.fired and timer.at <= stop and (not first or timer.at < first.at) then first=timer end end
        if not first then break end
        iterations=iterations+1; check(iterations < 100, "unbounded timer loop")
        clock=first.at; first.fired=true; first.fn()
    end
    clock=stop
end
local function placement(width,height,font,size) return {Anchor="CENTER",relativeTo="CENTER",xOffset=10,yOffset=20,Width=width,Height=height,FontSize=font,Size=size,Font="Original",enabled=true} end
local function setup(missing)
    combat,encounter,restricted,clock=false,false,false,10
    timers,calls,events,callbacks,init,exports={},{},{},{},{},{}
    notices,version=0,"12.1.32"
    secret=setmetatable({},{__tostring=function() error("secret stringification") end})
    function issecretvalue(v) return rawequal(v,secret) end
    function InCombatLockdown() return combat end
    function IsEncounterInProgress() return encounter end
    function GetTime() return clock end
    function time() return 1000 end
    C_RestrictedActions={GetAddOnRestrictionState=function() return restricted and 2 or 0 end}
    C_Secrets={ShouldAurasBeSecret=function() return restricted end}
    Enum={AddOnRestrictionType={Combat=0,Encounter=1,Chat=5}}
    C_Timer={NewTimer=function(delay,fn) local t={at=clock+delay,fn=fn}; function t:Cancel() self.cancelled=true end; timers[#timers+1]=t; return t end}
    C_AddOns={GetAddOnInfo=function() return not missing and "NorthernSkyRaidTools" or nil end, IsAddOnLoaded=function() return not missing, not missing end, GetAddOnMetadata=function(name,key) check(name=="NorthernSkyRaidTools" and key=="Version","metadata signature"); return version end}
    for _, name in ipairs({"SendAddonMessage","SendChatMessage","NotifyInspect","LoadAddOn","EnableAddOn","DisableAddOn","CreateFrame","SetSpecialization"}) do _G[name]=function() error("adapter touched unrelated engine: "..name) end end
    NSRT={CurrentProfile="Original",MainProfile="Original",ProfileKeys={Player="Original"},Settings={Volume=5,GenericDisplay=placement(100,25,14)},
        ReminderSettings={AutoShare=false,IconSettings=placement(80,80,20),BarSettings=placement(250,20,15),TextSettings=placement(nil,nil,30),CircleSettings=placement(nil,nil,15,80),
            ReminderFrame=placement(500,600,14),PersonalReminderFrame=placement(500,600,14),ExtraReminderFrame=placement(500,600,14)},
        Reminders={Original="EncounterID:42\nlibrary differs from runtime"},PersonalReminders={Personal="My private note"},StoredSharedReminder="Stored differs too",ActiveReminder="Original",
        ActivePersonalReminder={[42]="Personal"},StoredPersonalReminder={Player="Personal"},PersonalNotes={one="personal"},SharedNotes={two="shared"},AutoLoadNote={[42]="Original"},InviteList={Original={"A"}},
        EncounterAlerts={shared="must not be imported"},NickNames={A="A"}}
    engine={Reminder="Received runtime note",PersonalReminder="My private note",LoadedPersonalReminder="Personal",ReminderReceivedTime=8}
    local ignored={Profiles=true,ProfileKeys=true,CurrentProfile=true,MainProfile=true,EncounterAlerts=true,NickNames=true}
    local function currentProfile() local out={}; for k,v in pairs(NSRT) do if not ignored[k] then out[k]=copy(v) end end; return out end
    NSRT.Profiles={Original=currentProfile()}
    NSRT.Profiles.RaidPreset=currentProfile()
    NSRT.Profiles.RaidPreset.Settings.Volume=9
    NSRT.Profiles.RaidPreset.Reminders={Preset="Preset shared note"}
    NSRT.Profiles.RaidPreset.PersonalReminders={PresetPersonal="Preset private note"}
    NSRT.Profiles.RaidPreset.StoredSharedReminder="Preset stored shared"
    NSRT.Profiles.RaidPreset.StoredPersonalReminder={Player="PresetPersonal"}
    NSRT.Profiles.RaidPreset.ReminderSettings.AutoShare=true
    NSRT.Profiles.RaidPreset.ReminderSettings.IconSettings.xOffset=999
    function engine:SaveProfile() check(not combat and not encounter and not restricted,"write under restriction"); record("save:"..NSRT.CurrentProfile); NSRT.Profiles[NSRT.CurrentProfile]=currentProfile() end
    function engine:ProcessReminder() check(not combat and not encounter and not restricted,"processing under restriction"); record("process") end
    function engine:UpdateReminderFrame(all) check(all==true,"note frame refresh signature"); record("notes") end
    function engine:UpdateExistingFrames() record("displays") end
    function engine:FireCallback(name,personal,shared)
        check(name=="NSRT_REMINDER_CHANGED" and personal==self.PersonalReminder and shared==self.Reminder,"callback contract")
        record("callback")
        if callbacks[name] then callbacks[name](name,personal,shared) end
    end
    function engine:ImportReminder(name,text,activate,personal,isUpdate,diff)
        check(not combat and not encounter and not restricted,"note write under restriction")
        check(activate==false and personal==false and isUpdate==true and diff==nil,"unsafe note import flags")
        check(NSRT.Reminders[name]==nil and NSRT.InviteList[name]==nil,"overwrote existing note")
        record("import-note"); NSRT.Reminders[name]=text; NSRT.InviteList[name]={"derived"}
    end
    function engine:SetReminder(name,personal)
        check(personal==false,"activated a personal note")
        record("activate-note"); self.Reminder=NSRT.Reminders[name] or ""; NSRT.StoredSharedReminder=self.Reminder; NSRT.ActiveReminder=name
        self:ProcessReminder();self:UpdateReminderFrame(true);self:FireCallback("NSRT_REMINDER_CHANGED",self.PersonalReminder,self.Reminder)
    end
    local function load(name)
        engine:SaveProfile()
        for k,v in pairs(NSRT.Profiles[name]) do if not ignored[k] then NSRT[k]=copy(v) end end
        NSRT.CurrentProfile=name; NSRT.ProfileKeys.Player=name
        local personalName=NSRT.StoredPersonalReminder.Player
        engine.PersonalReminder=NSRT.PersonalReminders[personalName] or ""; engine.LoadedPersonalReminder=personalName
        engine:SaveProfile()
    end
    NSAPI={}
    function NSAPI:GetReminderString(enc) check(enc==nil,"unexpected encounter lookup"); return engine.PersonalReminder,engine.Reminder end
    function NSAPI:GetCurrentProfileKey() return NSRT.CurrentProfile end
    function NSAPI:GetProfileKeys() local keys={};for name in pairs(NSRT.Profiles) do keys[name]=true end;return keys end
    function NSAPI:ProfileExists(name) return NSRT.Profiles[name]~=nil end
    function NSAPI:OpenConfig() record("open-config"); return true end
    function NSAPI:ExportProfile(name,extra)
        check(extra==false,"export included shared data")
        if name==NSRT.CurrentProfile then engine:SaveProfile() end
        local token="profile:"..tostring(#exports+1); exports[#exports+1]=copy(NSRT.Profiles[name]); exports[token]=exports[#exports]; record("export:"..name); return token
    end
    function NSAPI:ImportProfileString(token,name,shared,ignoreShared)
        check(shared==false and ignoreShared==true,"profile imported shared data")
        while NSRT.Profiles[name] do name=name.." 2" end
        NSRT.Profiles[name]=copy(exports[token]); load(name); record("import-profile:"..name); return name
    end
    function NSAPI:SetProfile(name) if not NSRT.Profiles[name] then return false end;load(name);record("set-profile:"..name);return true end
    NSAPI.RegisterCallback=function(target,name,fn,owner) check(target~=NSAPI and owner==target and name=="NSRT_REMINDER_CHANGED","callback must use dot syntax and adapter owner"); callbacks[name]=function(...) fn(owner,...) end end
    NSAPI.UnregisterCallback=function(target,name) callbacks[name]=nil end
    NorthernSkyRaidTools=engine
    local RA={}
    function RA:RegisterInitializer(fn) init[#init+1]=fn end
    function RA:RegisterEvent(name,fn) events[name]=events[name] or {};table.insert(events[name],fn) end
    function RA:FireCallback(name) check(name=="NSRT_ADAPTER_CHANGED","unexpected Arsenal callback");notices=notices+1 end
    if missing then NSAPI,NorthernSkyRaidTools,NSRT=nil,nil,nil end
    assert(loadfile("RCPArsenal/NSRTAdapter.lua"))("RCPArsenal",RA)
    adapter=RA.NSRTAdapter
    for _,fn in ipairs(init) do fn() end
    return adapter
end
local function context() local ok,reason,data=adapter:GetNotes();check(ok,reason);return data.context end
local function notesBundle() local out={};for _,key in ipairs({"Reminders","PersonalReminders","SharedNotes","PersonalNotes","ActiveReminder","ActivePersonalReminder","StoredSharedReminder","StoredPersonalReminder","AutoLoadNote","InviteList"}) do out[key]=copy(NSRT[key]) end;return out end
local A=setup()
check(A:GetStatus().compatible and A:GetStatus().capabilities.applyNote and A:GetStatus().capabilities.applyProfile,"reviewed API capabilities unavailable")
check(#calls==0,"adapter wrote Northern Sky on login/refresh")
local ok,reason,notes=A:GetNotes()
check(ok and notes.personal=="My private note" and notes.shared=="Received runtime note" and notes.storedShared=="Stored differs too","note API return order/runtime semantics wrong")
local before, runtime, current=notesBundle(),copy(engine),NSRT.CurrentProfile
local token=notes.context
NSRT.StoredSharedReminder="Changed elsewhere"
check(not A:ApplyLocalNote("mine",token),"stale editor context accepted")
NSRT.StoredSharedReminder=before.StoredSharedReminder
local originalProfile=copy(NSRT.Profiles.Original)
check(A:ApplyLocalNote("EncounterID:42\n{time:0:10} Everyone move",context()),"local note apply failed")
local owned=NSRT.ActiveReminder
check(owned~="Original" and NSRT.Reminders.Original==before.Reminders.Original and engine.PersonalReminder==runtime.PersonalReminder,"local note overwrote existing/shared/personal library")
check(NSRT.CurrentProfile==current and equal(NSRT.Profiles.Original,originalProfile),"note apply saved or switched a profile")
check(A:GetStatus().canRestoreNote,"note restore not available")
check(A:RestoreLastNote(context()),"note restore failed")
check(equal(notesBundle(),before) and engine.Reminder==runtime.Reminder and engine.PersonalReminder==runtime.PersonalReminder,"restore lost divergent runtime, stored, or library state")
check(NSRT.Reminders[owned]==nil and NSRT.InviteList[owned]==nil,"restore retained adapter-owned note")
check(not A:RestoreLastNote(context()),"restore silently repeated")

A=setup()
NSRT.ReminderSettings.AutoShare=true
check(not A:ApplyLocalNote("local only",context()) and #calls==0 and NSRT.ReminderSettings.AutoShare,"AutoShare was changed or local apply allowed")
A=setup();check(A:ApplyLocalNote("mine",context()),"apply failed")
NSRT.Reminders.Original="Intervening edit"
check(not A:RestoreLastNote(context()) and NSRT.Reminders.Original=="Intervening edit","restore overwrote intervening note change")
A=setup();token=context();version="12.1.33"
check(not A:ApplyLocalNote("mine",token) and #calls==0,"unknown-version mutation permitted")
check(A:GetNotes() and A:OpenSettings(),"safe public reads/settings unavailable on another version")
A=setup();token=context();combat=true
check(not A:ApplyLocalNote("mine",token) and not A:OpenSettings() and not A:GetStatus().capabilities.applyNote,"combat writes/controls allowed")
combat=false;encounter=true;check(not A:ApplyLocalNote("mine",token),"encounter write allowed")
encounter=false;restricted=true;check(not A:ApplyLocalNote("mine",token),"native restriction write allowed")
restricted=false
check(not A:ApplyLocalNote(secret,token) and not A:ApplyLocalNote(string.rep("x",65537),token),"secret/oversized note accepted")

A=setup();before=notesBundle();runtime={Reminder=engine.Reminder,PersonalReminder=engine.PersonalReminder,LoadedPersonalReminder=engine.LoadedPersonalReminder,ReminderReceivedTime=engine.ReminderReceivedTime}
local placements=copy(NSRT.ReminderSettings)
local targetBefore=copy(NSRT.Profiles.RaidPreset)
local allProfilesBefore=copy(NSRT.Profiles)
ok,reason,notes=A:GetProfiles()
check(ok and notes.current=="Original" and #notes.names==2 and notes.names[1]=="Original" and notes.names[2]=="RaidPreset","profile key set was mistaken for array")
ok,reason,notes=A:SelectProfile("RaidPreset");check(ok and #calls==0,"profile selection wrote/exported settings")
ok,reason,notes=A:ApplyProfile("RaidPreset",notes.context);check(ok,reason)
local clone=notes.name
check(clone~="Original" and clone~="RaidPreset" and NSRT.CurrentProfile==clone and NSRT.Settings.Volume==9,"clone-first profile did not activate source settings")
check(equal(NSRT.Profiles.RaidPreset,targetBefore),"source profile was overwritten")
check(equal(notesBundle(),before) and equal(NSRT.ReminderSettings,placements),"profile apply did not preserve all notes, placement, and AutoShare")
for key,value in pairs(runtime) do check(engine[key]==value,"runtime note state changed during profile apply") end
check(A:GetStatus().canRestoreProfile,"profile restore unavailable")
advance(0)
check(A:RestoreLastProfile(context()),"profile restore failed")
check(NSRT.CurrentProfile=="Original" and NSRT.Settings.Volume==5 and NSRT.Profiles[clone]~=nil,"undo lost original identity/settings or deleted owned copy")
check(equal(notesBundle(),before) and equal(NSRT.ReminderSettings,placements),"profile undo lost notes or placement")
for key,value in pairs(runtime) do check(engine[key]==value,"runtime state lost during undo") end
advance(0)

A=setup();ok,reason,notes=A:SelectProfile("RaidPreset");check(ok,reason)
NSRT.Profiles.RaidPreset.Settings.Volume=11
check(not A:ApplyProfile("RaidPreset",notes.context) and #calls==0,"same-key edited source profile bypassed staged identity guard")
A=setup();ok,reason,notes=A:SelectProfile("RaidPreset");check(ok,reason)
check(A:ApplyProfile("RaidPreset",notes.context),"profile apply failed")
NSRT.Settings.Volume=6
check(not A:RestoreLastProfile(context()) and NSRT.Settings.Volume==6,"profile restore overwrote intervening general settings")
A=setup();ok,reason,notes=A:SelectProfile("RaidPreset");check(ok,reason)
check(A:ApplyProfile("RaidPreset",notes.context),"profile apply failed")
NSRT.Profiles.Original.Settings.Volume=77
check(not A:RestoreLastProfile(context()),"profile restore ignored edited original profile")

A=setup()
check(#A.PlacementSections==7,"missing native placement sections")
for _,section in ipairs(A.PlacementSections) do
    ok,reason,notes=A:GetPlacement(section.id);check(ok,reason)
    check(#notes.fields<=8 and notes.values.Anchor=="CENTER" and notes.values.relativeTo=="CENTER","placement schema/anchor shape wrong")
end
ok,reason,notes=A:GetPlacement("IconSettings");check(ok,reason)
check(A:SetPlacement("IconSettings",{xOffset=123,yOffset=-45,Width=100,Height=120,Anchor="TOPLEFT",relativeTo="BOTTOMLEFT"},notes.context),"native placement write failed")
check(NSRT.ReminderSettings.IconSettings.Width==100 and NSRT.ReminderSettings.IconSettings.xOffset==123 and NSRT.ReminderSettings.IconSettings.Font=="Original","placement wrote wrong/native-unknown fields")
advance(0)
check(not A:SetPlacement("IconSettings",{Scale=2},context()),"invented scale API accepted")
check(not A:SetPlacement("IconSettings",{Width=201},context()),"out-of-bounds size accepted")
check(not A:SetPlacement("IconSettings",{Anchor="PLAYER"},context()),"unsupported anchor accepted")
check(not A:SetPlacement("IconSettings",{xOffset=secret},context()),"secret placement accepted")

A=setup();before=notesBundle();runtime=engine.Reminder
engine.SetReminder=function(self,name) self.Reminder=NSRT.Reminders[name];NSRT.ActiveReminder=name;error("test failure") end
check(not A:ApplyLocalNote("mine",context()),"failed activation returned success")
check(equal(notesBundle(),before) and engine.Reminder==runtime,"failed note activation did not restore exact state")
A=setup();ok,reason,notes=A:GetPlacement("IconSettings");check(ok,reason)
engine.UpdateExistingFrames=function() error("test failure") end
check(not A:SetPlacement("IconSettings",{Width=110},notes.context) and NSRT.ReminderSettings.IconSettings.Width==80,"failed native placement refresh did not roll back")
A=setup();ok,reason,notes=A:SelectProfile("RaidPreset");check(ok,reason)
local originalImport=NSAPI.ImportProfileString
NSAPI.ImportProfileString=function(self,...) local name=originalImport(self,...);error("failure after activation") end
check(not A:ApplyProfile("RaidPreset",notes.context),"failed profile activation returned success")
-- No authoritative returned clone identity exists after that exception: fail
-- closed and retain the recoverable copy rather than guessing ownership.
check(NSRT.Profiles.Original~=nil and NSRT.Profiles.RaidPreset~=nil,"profile failure deleted an original profile")

A=setup(true)
check(not A:GetStatus().available and #calls==0,"missing addon was activated")
advance(20)
local timerCount=#timers
advance(100)
check(#timers==timerCount and timerCount==0,"missing-addon startup allocated a timer")
A=setup();local savedAPI,savedEngine,savedDB=NSAPI,NorthernSkyRaidTools,NSRT
NSAPI,NorthernSkyRaidTools,NSRT=nil,nil,nil
A:Refresh();check(not A:GetStatus().available,"unloaded addon still available")
NSAPI,NorthernSkyRaidTools,NSRT=savedAPI,savedEngine,savedDB
event("ADDON_LOADED","NorthernSkyRaidTools")
check(A:GetStatus().available and #calls==0,"late-load did not bind by bounded reads")
A=setup();NSRT.ReminderSettings.IconSettings.Anchor="INVALID"
check(not A:GetPlacement("IconSettings"),"unsafe anchor escaped placement reads")

A=setup()
local countBefore=notices
for i=1,4 do A:GetNotes();A:GetProfiles();A:GetPlacement("IconSettings");A:Refresh() end
check(notices==countBefore,"read APIs broadcast unchanged state")
-- A UI listener may synchronously read all current values without recursion.
local readCallbackCount=0
local fakeRA={}
-- The actual dispatcher in Core is protected; this harness's callback triggers
-- a read after a native NSRT change, exercising publication stability directly.
NSRT.StoredSharedReminder="new native state"
A:Refresh()
countBefore=notices
A:GetNotes();A:GetProfiles();A:GetPlacement("IconSettings")
check(notices==countBefore,"native event refresh caused recursive read notifications")
local nativeCallback=callbacks.NSRT_REMINDER_CHANGED
NSRT.StoredSharedReminder="native callback state"
nativeCallback("NSRT_REMINDER_CHANGED",engine.PersonalReminder,engine.Reminder)
check(notices==countBefore+1,"owner-bound native callback did not publish a changed context")
A=setup(true)
check(#timers==0 and A:GetStatus().installed==false and A:GetStatus().loaded==false,"missing addon detection/timer state untruthful")
print("nsrt_adapter: "..checks.." checks passed")
