-- Runs real Core/Catalog/cache/Inspect modules in a fresh Lua global environment
-- for each lifecycle; only WoW APIs are mocked. SavedVariables cross lifecycles
-- as ordinary serialized facts, never module closures or inspection state.
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function Copy(value) if type(value)~="table" then return value end;local out={};for key,item in pairs(value) do out[key]=Copy(item) end;return out end
local function Count(value) local n=0;for _ in pairs(value or {}) do n=n+1 end;return n end
local function Unit(name,guid,class,spec,spell) return {name=name,realm="Realm",guid=guid,class=class,spec=spec,spell=spell,role="DAMAGER",connected=true} end
local function Lifecycle(saved,options)
    options=options or {}
    local env=setmetatable({}, {__index=_G});env._G=env
    local world={clock=100,epoch=1800000000+(options.days or 0)*86400,combat=false,inspected=nil,notify={},talentReads=0,timers={},errors={},frames=0}
    world.units=options.units or {player=Unit("Lead","Player-1","MAGE",62,0),party1=Unit("Healer","Player-2","SHAMAN",264,98008),party2=Unit("Fighter","Player-3","WARRIOR",72,97462)}
    env.RaidArsenalDB=Copy(saved or {profile={schemaVersion=19,hudEnabled=true,demoMode=false,leaderToolbox={enabled=false}}})
    env.print=function(message) world.errors[#world.errors+1]=tostring(message) end
    env.time=function() return world.epoch+math.floor(world.clock) end
    env.GetTime=function() return world.clock end
    local secret=setmetatable({}, {__tostring=function() error("secret value stringified") end});world.secret=secret
    env.issecretvalue=function(value) return rawequal(value,secret) end
    env.InCombatLockdown=function() return world.combat end
    env.UnitExists=function(unit) return world.units[unit]~=nil end
    env.UnitIsPlayer=env.UnitExists
    env.UnitFullName=function(unit) local u=world.units[unit];if u then return u.name,u.realm end end
    env.UnitName=function(unit) return world.units[unit] and world.units[unit].name end
    env.UnitGUID=function(unit) return world.units[unit] and world.units[unit].guid end
    env.UnitClass=function(unit) local u=world.units[unit];return u and u.class,u and u.class end
    env.UnitGroupRolesAssigned=function(unit) return world.units[unit] and world.units[unit].role or "NONE" end
    env.UnitIsConnected=function(unit) return world.units[unit] and world.units[unit].connected end
    env.UnitIsGroupLeader=function() return false end
    env.UnitIsGroupAssistant=function() return false end
    env.GetNormalizedRealmName=function() return "Realm" end
    env.GetRealmName=env.GetNormalizedRealmName
    env.IsInRaid=function() return false end
    env.IsInGroup=function() return world.units.party1~=nil end
    env.GetNumSubgroupMembers=function() local n=0;for i=1,4 do if world.units["party"..i] then n=n+1 end end;return n end
    env.CanInspect=function(unit) return world.units[unit] and world.units[unit].connected~=false end
    env.NotifyInspect=function(unit) world.notify[#world.notify+1]=unit;world.inspected=unit end
    env.ClearInspectPlayer=function() world.inspected=nil end
    env.PlayerKnowsSpell=function() world.talentReads=world.talentReads+1;return false end
    env.wipe=function(value) for key in pairs(value) do value[key]=nil end;return value end
    env.CreateFrame=function()
        world.frames=world.frames+1
        local frame={scripts={}}
        function frame:RegisterEvent() end
        function frame:SetScript(name,fn) self.scripts[name]=fn end
        world.eventFrame=frame
        return frame
    end
    local function Timer(delay,fn)
        local timer={at=world.clock+math.max(0.001,delay),fn=fn};function timer:Cancel() self.cancelled=true end
        world.timers[#world.timers+1]=timer;return timer
    end
    env.C_Timer={NewTimer=Timer,After=function(delay,fn) Timer(delay,fn) end}
    env.C_SpecializationInfo={
        GetSpecialization=function() world.talentReads=world.talentReads+1;return world.units.player.spec and world.units.player.spec>0 and 1 or nil end,
        GetSpecializationInfo=function() return world.units.player.spec end,
        GetInspectSpecialization=function(unit) world.talentReads=world.talentReads+1;return world.units[unit] and world.units[unit].spec or 0 end,
        GetSpellsDisplay=function() return {} end,
    }
    env.C_ClassTalents={GetTraitTreeForSpec=function() world.talentReads=world.talentReads+1;return 1 end,
        GetActiveConfigID=function() return world.activeConfigID end,
        IsConfigPopulated=function() return world.localPopulated==true end}
    env.C_Traits={HasValidInspectData=function() return world.inspected~=nil end,GetTreeNodes=function() return world.treeNodes or {1} end,
        GetNodeInfo=function(configID,nodeID) if configID~=-1 and (world.localNodesReady==false or nodeID==world.localMissingNode) then return nil end;return {activeRank=1,activeEntry={entryID=100},entryIDsWithCommittedRanks={100}} end,
        GetEntryInfo=function(configID) if configID~=-1 and world.localDefinitionsReady==false then return nil end;return {definitionID=100} end,
        GetDefinitionInfo=function() return {spellID=world.units[world.inspected or "player"].spell} end}
    env.Enum={TraitNodeType={Selection=2}}
    local RA={}
    for _,name in ipairs({"Core","Catalog","InspectionCache","Inspect"}) do local fn=assert(loadfile("RCPArsenal/"..name..".lua"));setfenv(fn,env);fn("RCPArsenal",RA) end
    function RA:RefreshHUD() end
    local function Event(name,...)
        world.eventFrame.scripts.OnEvent(world.eventFrame,name,...)
        for _,message in ipairs(world.errors) do check(not message:find("error:",1,true),message) end
    end
    local function Advance(seconds)
        local stop=world.clock+seconds;local iterations=0
        while true do
            local first
            for _,timer in ipairs(world.timers) do if not timer.cancelled and not timer.fired and timer.at<=stop and (not first or timer.at<first.at) then first=timer end end
            if not first then break end
            iterations=iterations+1;check(iterations<200,"unbounded scan timers")
            world.clock=first.at;first.fired=true;first.fn()
        end
        world.clock=stop
    end
    local function Reply()
        local unit=world.inspected
        check(unit~=nil,"no outstanding inspection")
        Event("INSPECT_READY",world.units[unit].guid)
        Advance(0.75)
    end
    Event("ADDON_LOADED","RCPArsenal")
    return RA,env,world,Event,Advance,Reply
end
local RA,E,W,Event,Advance,Reply=Lifecycle()
check(W.frames==1,"cache allocated UI frames")
check(RA:RequestInspectionScan("first ordinary pass",false),"initial scan failed")
Reply();Reply()
check(#W.notify==2 and RA:GetScanSummary().confirmed==3 and RA:GetScanSummary().cached==0,"first lifecycle did not confirm actual reports")
local saved=Copy(E.RaidArsenalDB)
check(saved.inspectionCache.schema==1 and Count(saved.inspectionCache.entries)==3,"confirmed facts did not persist outside the profile")
check(saved.profile.inspectionCache==nil,"cache leaked into portable profile")
local entry=saved.inspectionCache.entries["Player-2"]
check(entry.name=="Healer-Realm" and entry.observerGUID=="Player-1" and entry.source=="INSPECT" and entry.confirmedAt>0,"persisted identity/provenance incomplete")
check(entry.capabilities.spirit_link and entry.evidence.spirit_link=="SELECTED_TALENT" and entry.unit==nil and entry.updatedAt==nil and entry.generation==nil,"cache did not store only stable ordinary facts")

-- Fresh environment: persisted reports reconstruct providers before any scan.
RA,E,W,Event,Advance,Reply=Lifecycle(saved,{days=10})
local restored=RA.Reports["Healer-Realm"]
check(restored and restored.cached and restored.source=="PERSISTED_CACHE" and restored.originalSource=="INSPECT" and restored.confirmedAt==entry.confirmedAt,"reload failed to restore honest provenance")
check(RA:IsReportUsable(restored,RA.Roster[restored.name]) and not RA:IsReportFresh(restored,RA.Roster[restored.name]),"display cache was treated as live specialization")
local summary=RA:GetScanSummary()
check(summary.confirmed==1 and summary.cached==2 and summary.inspected==1 and summary.unknown==0,"cached and current lifecycle counts were conflated")
local owners=RA:BuildAbilityOwners()[RA.CatalogByKey.spirit_link.index]
check(owners and owners[1].cached and owners[1].confirmedAt==entry.confirmedAt and owners[1].observerGUID=="Player-1","provider provenance missing")
for _,name in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","READY_CHECK","GROUP_ROSTER_UPDATE","PLAYER_REGEN_ENABLED"}) do Event(name) end
Advance(35)
check(#W.notify==0 and not RA:HasMissingReports(),"startup/ready/retry/age automatically rescanned retained cache")
check(E.RaidArsenalDB.inspectionCache.entries["Player-2"].confirmedAt==entry.confirmedAt,"cache restore renewed the original confirmation epoch")
Event("ENCOUNTER_START")
local frozen=RA:GetScanSummary()
RA:InvalidateTrackedPlayer("Healer-Realm","changed during encounter")
check(RA:GetScanSummary().cached==frozen.cached and RA.FrozenReports["Healer-Realm"].cached,"frozen evidence/counts drifted with live invalidation")
check(RA.FrozenVerifiedCount==frozen.confirmed and RA.FrozenCachedCount==frozen.cached,"frozen counts promoted saved cache")
Event("ENCOUNTER_END")

local off=Copy(saved);off.profile.hudEnabled=false;off.profile.leaderToolbox.enabled=true
RA,E,W,Event,Advance=Lifecycle(off)
for _,name in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","GROUP_ROSTER_UPDATE","READY_CHECK","TRAIT_CONFIG_UPDATED","SPELLS_CHANGED","PLAYER_SPECIALIZATION_CHANGED","INSPECT_READY","PLAYER_REGEN_ENABLED"}) do Event(name,"party1") end
Advance(30)
check(#W.notify==0 and W.talentReads==0 and Count(RA.Reports)==0,"disabled/puck-only lifecycle started scan work")
RA:RefreshRoster(true)
check(RA:GetScanSummary().cached==3 and RA:GetScanSummary().confirmed==0 and RA.Reports["Healer-Realm"].specID==264,"explicit disabled roster planning failed to restore saved specs")
check(not RA:IsInspectionEnabled() and #W.notify==0 and W.talentReads==0 and Count(W.timers)==0,"explicit saved roster read enabled collection, read talents, or scheduled timers")
check(RA:SetHUDEnabled(true),"later explicit HUD enable failed");Advance(1)
check(#W.notify==0 and RA:GetScanSummary().cached==2,"later enable did not restore cache before queue construction")

local unknownUnits={player=Unit("Lead","Player-1",nil,0,0),party1=Unit("Healer","Player-2",nil,0,98008),party2=Unit("Fighter","Player-3",nil,0,97462)}
for _,unit in pairs(unknownUnits) do unit.role="NONE" end
RA,E,W,Event,Advance,Reply=Lifecycle(saved,{units=unknownUnits})
check(RA:GetScanSummary().cached==3,"unknown startup metadata invalidated cached reports")
Event("GROUP_ROSTER_UPDATE");Event("PLAYER_SPECIALIZATION_CHANGED","party1");Event("SPELLS_CHANGED");Event("TRAIT_CONFIG_UPDATED");Event("READY_CHECK");Advance(15)
check(#W.notify==0 and RA.Reports["Healer-Realm"].cached,"unknown startup events became definite loadout changes")
W.units.player.class,W.units.player.spec="MAGE",62
W.units.party1.class,W.units.party1.spec="SHAMAN",264
W.units.party2.class,W.units.party2.spec="WARRIOR",72
Event("GROUP_ROSTER_UPDATE");Event("PLAYER_SPECIALIZATION_CHANGED","party1");Advance(1)
check(#W.notify==0,"known unchanged metadata rescanned cache")

-- A positive self spec can precede populated talents/spellbook during login.
-- Retain earlier facts until an ordinary signal and readable active config.
local selfSaved=Copy(saved)
selfSaved.inspectionCache.entries["Player-1"]=Copy(entry)
local selfEntry=selfSaved.inspectionCache.entries["Player-1"]
selfEntry.guid,selfEntry.name,selfEntry.source="Player-1","Lead-Realm","LOCAL"
local selfUnits={player=Unit("Lead","Player-1","SHAMAN",264,98008),party1=Unit("Healer","Player-2","SHAMAN",264,98008),party2=Unit("Fighter","Player-3","WARRIOR",72,97462)}
RA,E,W,Event,Advance=Lifecycle(selfSaved,{units=selfUnits})
local selfReport=RA.Reports["Lead-Realm"]
check(selfReport.cached and selfReport.capabilities[RA.CatalogByKey.spirit_link.index],"positive self spec erased saved tools during startup")
Event("SPELLS_CHANGED")
check(RA.Reports["Lead-Realm"]==selfReport,"missing active config replaced cached self")
W.activeConfigID=7
Event("TRAIT_CONFIG_UPDATED")
check(RA.Reports["Lead-Realm"]==selfReport,"unpopulated local config replaced cached self")
W.localPopulated=true;W.localNodesReady=false;W.treeNodes={1,2}
Event("SPELLS_CHANGED")
check(RA.Reports["Lead-Realm"]==selfReport,"unreadable local talent nodes replaced saved self")
W.localNodesReady=true;W.localMissingNode=2
Event("SPELLS_CHANGED")
check(RA.Reports["Lead-Realm"]==selfReport,"partially readable local talents replaced saved self")
W.localMissingNode=nil;W.localDefinitionsReady=false
Event("TRAIT_CONFIG_UPDATED")
check(RA.Reports["Lead-Realm"]==selfReport,"unavailable local definitions replaced saved self")
W.localDefinitionsReady=true
Event("TRAIT_CONFIG_UPDATED")
selfReport=RA.Reports["Lead-Realm"]
check(not selfReport.cached and selfReport.sessionVerified and selfReport.capabilities[RA.CatalogByKey.spirit_link.index]
    and selfReport.evidence[RA.CatalogByKey.spirit_link.index]=="SELECTED_TALENT","ready local config failed to confirm saved tools")
check(#W.notify==0,"self readiness started remote scans")
W.units.player.spec=262;W.activeConfigID=nil
Event("PLAYER_SPECIALIZATION_CHANGED","player")
check(not RA.Reports["Lead-Realm"] and not E.RaidArsenalDB.inspectionCache.entries["Player-1"],"definite self spec change retained incompatible cached facts")

local realmSaved=Copy(saved)
realmSaved.inspectionCache.entries["Player-2"].name="Healer-Away"
local realmUnits={player=Unit("Lead","Player-1","MAGE",62,0),party1=Unit("Healer","Player-2","SHAMAN",264,98008),party2=Unit("Fighter","Player-3","WARRIOR",72,97462)}
realmUnits.party1.realm=nil
RA,E,W,Event,Advance=Lifecycle(realmSaved,{units=realmUnits})
check(RA.Reports["Healer-Away"] and RA.Reports["Healer-Away"].cached and E.RaidArsenalDB.inspectionCache.entries["Player-2"].name=="Healer-Away","unknown startup realm erased known GUID identity")
W.units.party1.realm="Away";Event("GROUP_ROSTER_UPDATE");Event("READY_CHECK");Advance(1)
check(#W.notify==0 and RA.Reports["Healer-Away"].cached,"known unchanged cross-realm identity rescanned saved member")
W.units.party1.realm="Changed";Event("GROUP_ROSTER_UPDATE");Advance(1)
check(#W.notify==1 and W.notify[1]=="party1" and not E.RaidArsenalDB.inspectionCache.entries["Player-2"],"explicit realm mismatch retained incompatible identity")
realmSaved.profile.hudEnabled=false;realmUnits.party1.realm=nil
RA,E,W,Event,Advance=Lifecycle(realmSaved,{units=realmUnits})
check(RA:GetInspectionUnitName("party1",true)=="Healer-Away","explicit disabled snapshot could not resolve saved qualified identity")
RA:RefreshRoster(true)
check(RA.Roster["Healer-Away"] and RA.Reports["Healer-Away"].cached and #W.notify==0 and W.talentReads==0 and Count(W.timers)==0,"explicit cross-realm saved roster read started collection or lost identity")

-- A new or definite changed identity targets only the affected GUID.
RA,E,W,Event,Advance,Reply=Lifecycle(saved)
W.units.party3=Unit("NewFriend","Player-4","WARRIOR",72,97462)
Event("GROUP_ROSTER_UPDATE");Advance(1)
check(#W.notify==1 and W.notify[1]=="party3","new member caused a blanket scan")
Reply()
check(RA.Reports["NewFriend-Realm"].source=="INSPECT","targeted scan did not confirm new member")
W.units.party1.role="HEALER"
Event("GROUP_ROSTER_UPDATE");Advance(1)
check(#W.notify==2 and W.notify[2]=="party1","definite role change did not target exactly the changed member")
Reply()
W.units.party2.spec=73
Event("PLAYER_SPECIALIZATION_CHANGED","party2");Advance(1)
check(#W.notify==3 and W.notify[3]=="party2","definite spec change did not target affected cached member")
Reply()

RA,E,W,Event,Advance,Reply=Lifecycle(saved)
check(RA:RequestInspectionScan("explicit full refresh",true),"full refresh rejected")
check(#RA:GetPendingScanEntries()==2 and RA:GetPendingScanEntries()[1].cached,"manual refresh discarded prior cached provenance")
Reply();Reply()
check(#W.notify==2 and RA:GetScanSummary().cached==0 and RA:GetScanSummary().confirmed==3,"manual full refresh skipped saved members")
check(RA:ClearInspectionCache(),"explicit clear failed");Advance(0.2)
check(#W.notify==3 and E.RaidArsenalDB.inspectionCache.entries["Player-2"]==nil,"clear immediately resurrected persisted reports")
Reply();Reply()

-- Fences old events while no eligible newer request exists.
RA,E,W,Event,Advance,Reply=Lifecycle(saved)
RA:RequestInspectionScan("explicit full",true)
local oldGUID=W.units[W.inspected].guid
local invalidatedName=W.units[W.inspected].name.."-Realm"
RA:InvalidateTrackedPlayer(W.inspected,"explicit loadout invalidation",0.1)
Event("INSPECT_READY",oldGUID)
check(E.RaidArsenalDB.inspectionCache.entries[oldGUID]==nil,"old invalidated reply repopulated persistence")
check(not RA.Reports[invalidatedName],"old invalidated reply recreated a current report")
RA:SetHUDEnabled(false);Event("INSPECT_READY",oldGUID)
check(not RA.Reports[invalidatedName],"disabled late reply recreated report")
RA,E,W,Event,Advance,Reply=Lifecycle(saved)
RA:RequestInspectionScan("explicit full",true)
local oldName=W.units[W.inspected].name.."-Realm";oldGUID=W.units[W.inspected].guid
W.units[W.inspected].guid="Player-Replacement"
Event("GROUP_ROSTER_UPDATE");Event("INSPECT_READY",oldGUID)
check(not RA.Reports[oldName] or RA.Reports[oldName].guid~="Player-Replacement","late old GUID reply was attributed to replacement")

-- Retention, compatibility, malformed data, and bounded global pruning.
for _,mutate in ipairs({
    function(s) s.inspectionCache.schema=99 end,
    function(s) s.inspectionCache.entries["Player-2"].confirmedAt=1 end,
    function(s) s.inspectionCache.entries["Player-2"].catalogVersion=999 end,
    function(s) s.inspectionCache.entries["Player-2"].classRevision=999 end,
    function(s) s.inspectionCache.entries["Player-2"].source="DEMO" end,
    function(s) s.inspectionCache.entries["Player-2"].capabilities={invented=true} end,
    function(s) s.inspectionCache.entries["Player-2"].evidence={} end,
    function(s) local row=s.inspectionCache.entries["Player-2"];row.specID=72;row.capabilities={};row.evidence={roleOnly=true} end,
    function(s) local row=s.inspectionCache.entries["Player-2"];row.specID=99999;row.capabilities={};row.evidence={roleOnly=true} end,
}) do
    local broken=Copy(saved);mutate(broken)
    RA,E,W,Event,Advance=Lifecycle(broken)
    check(not RA.Reports["Healer-Realm"],"invalid/incompatible/expired entry restored")
    Event("READY_CHECK");Advance(0.1)
    check(#W.notify>=1,"invalid retained member was not eligible for targeted recovery")
end
RA,E,W,Event,Advance=Lifecycle(saved,{days=31})
check(RA:GetScanSummary().cached==0,"30-day retention limit was ignored")
local many=Copy(saved)
for i=1,300 do local row=Copy(entry);row.guid="Player-Limit-"..i;row.name="Historical"..i.."-Realm";row.confirmedAt=row.confirmedAt-i;many.inspectionCache.entries[row.guid]=row end
RA,E,W,Event,Advance=Lifecycle(many)
check(Count(E.RaidArsenalDB.inspectionCache.entries)<=160,"persisted cache was not bounded")
local cache=RA.InspectionCache
local fake=Copy(RA.DemoReports["Leafy-Zuljin"]);fake.confirmedAt=E.time()
check(not cache:Store(fake),"DEMO persisted")
fake=Copy(RA.Reports["Lead-Realm"]);fake.source="ERROR";check(not cache:Store(fake),"error report persisted")
fake.source="LOCAL";fake.name=W.secret;check(not cache:Store(fake),"secret identity persisted")
fake.name="Lead-Realm";fake.verified=W.secret;check(not cache:Store(fake),"secret verification persisted")
fake.verified=true;fake.capabilities={};fake.evidence={roleOnly=true};fake.class="SHAMAN";fake.classRevision=RA:GetClassCatalogRevision("SHAMAN");fake.specID=72
check(not cache:Store(fake),"impossible live class/spec pair persisted")
fake.specID=99999;check(not cache:Store(fake),"unknown live spec persisted")
fake.verified=true;fake.capabilities=7;check(not cache:Store(fake),"malformed capabilities accepted")
fake.capabilities={};fake.evidence=7;check(not cache:Store(fake),"malformed evidence accepted")
fake.evidence={};E.time=function() return nil end;check(not cache:Store(fake),"missing epoch accepted")
check(not cache:Get(W.secret,"Lead-Realm"),"secret cache lookup accepted")
print("inspection_cache: "..checks.." checks passed")
