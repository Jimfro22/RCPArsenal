local _, RA = ...
local Cache = {SCHEMA = 1, MAX_ENTRIES = 160, RETENTION_SECONDS = 30 * 24 * 60 * 60}
RA.InspectionCache = Cache
local initialized = false
local blocked = {}
local classes = {WARRIOR=true,PALADIN=true,HUNTER=true,ROGUE=true,PRIEST=true,DEATHKNIGHT=true,SHAMAN=true,MAGE=true,WARLOCK=true,MONK=true,DRUID=true,DEMONHUNTER=true,EVOKER=true}
-- Supported 12.1 player specializations, matching Blizzard's
-- ClassSpecializationsFrame.lua SPEC_FORMAT_STRINGS (b9be9379719047977fca4dba1bb1d9988e8840b3).
-- Unknown future specs require a reviewed catalog update before saved reuse.
local specClasses = {
    [250]="DEATHKNIGHT",[251]="DEATHKNIGHT",[252]="DEATHKNIGHT",
    [577]="DEMONHUNTER",[581]="DEMONHUNTER",[1480]="DEMONHUNTER",
    [102]="DRUID",[103]="DRUID",[104]="DRUID",[105]="DRUID",
    [1467]="EVOKER",[1468]="EVOKER",[1473]="EVOKER",
    [253]="HUNTER",[254]="HUNTER",[255]="HUNTER",
    [62]="MAGE",[63]="MAGE",[64]="MAGE",
    [268]="MONK",[269]="MONK",[270]="MONK",
    [65]="PALADIN",[66]="PALADIN",[70]="PALADIN",
    [256]="PRIEST",[257]="PRIEST",[258]="PRIEST",
    [259]="ROGUE",[260]="ROGUE",[261]="ROGUE",
    [262]="SHAMAN",[263]="SHAMAN",[264]="SHAMAN",
    [265]="WARLOCK",[266]="WARLOCK",[267]="WARLOCK",
    [71]="WARRIOR",[72]="WARRIOR",[73]="WARRIOR",
}
local roles = {TANK=true,HEALER=true,DAMAGER=true}
local evidenceTypes = {SELECTED_TALENT=true,BASELINE_SPEC=true,GUARANTEED_CLASS=true}
local function Secret(value) return type(issecretvalue)=="function" and issecretvalue(value) end
local function Text(value,maximum)
    if Secret(value) or type(value)~="string" or #value==0 or #value>maximum or value:find("[%c|]") then return nil end
    return value
end
local function Number(value,minimum,maximum)
    return not Secret(value) and type(value)=="number" and value==value and value>=minimum and value<=maximum and value==math.floor(value) and value or nil
end
local function Epoch()
    local value = time and time()
    return Number(value,1,4102444800)
end
local function GUID(value) return Text(value,80) and value:match("^Player%-[%w%-]+$") and value or nil end
local function Name(value) return Text(value,128) and value:match("^[^%-]+%-.+$") and value or nil end
function Cache:IsKnownClass(value) return not Secret(value) and type(value)=="string" and classes[value]==true end
function Cache:IsKnownRole(value) return not Secret(value) and type(value)=="string" and roles[value]==true end
function Cache:Now() return Epoch() end
local function Sanitize(entry,now)
    if Secret(entry) or type(entry)~="table" then return nil end
    local guid,name,class=GUID(entry.guid),Name(entry.name),entry.class
    if not guid or not name or not Cache:IsKnownClass(class) or not GUID(entry.observerGUID) then return nil end
    if Secret(entry.source) or (entry.source~="LOCAL" and entry.source~="INSPECT") then return nil end
    local spec=Number(entry.specID,1,100000)
    local revision=Number(entry.classRevision,1,100000)
    if Secret(entry.catalogVersion) or entry.catalogVersion~=RA.CATALOG_VERSION then return nil end
    local confirmed=Number(entry.confirmedAt,1,4102444800)
    if not spec or specClasses[spec]~=class or not revision or revision~=RA:GetClassCatalogRevision(class) or not confirmed or confirmed>now+300 or now-confirmed>Cache.RETENTION_SECONDS then return nil end
    if Secret(entry.role) or (entry.role~=nil and not Cache:IsKnownRole(entry.role)) then return nil end
    if Secret(entry.capabilities) or type(entry.capabilities)~="table" or Secret(entry.evidence) or type(entry.evidence)~="table" then return nil end
    local capabilities,evidence,count={},{},0
    for key,value in pairs(entry.capabilities) do
        count=count+1
        if count>256 or not Text(key,80) or Secret(value) or value~=true then return nil end
        local ability=RA.CatalogByKey and RA.CatalogByKey[key]
        if not ability or (ability.class and ability.class~=class) then return nil end
        if ability.specs and ability.specs[spec]~=true then return nil end
        capabilities[key]=true
    end
    count=0
    for key,value in pairs(entry.evidence) do
        count=count+1
        if count>256 or Secret(key) or Secret(value) then return nil end
        if key=="roleOnly" then if value~=true or next(capabilities) then return nil end; evidence.roleOnly=true
        elseif not Text(key,80) or not capabilities[key] or not evidenceTypes[value] then return nil
        else evidence[key]=value end
    end
    for key in pairs(capabilities) do if not evidence[key] then return nil end end
    return {guid=guid,name=name,class=class,specID=spec,role=entry.role,classRevision=revision,catalogVersion=entry.catalogVersion,confirmedAt=confirmed,
        source=entry.source,observerGUID=entry.observerGUID,capabilities=capabilities,evidence=evidence}
end
function Cache:Initialize()
    if initialized then return true end
    if type(RaidArsenalDB)~="table" then return false end
    local now=Epoch()
    if not now then return false end
    local source=RaidArsenalDB.inspectionCache
    local entries={}
    if not Secret(source) and type(source)=="table" and not Secret(source.schema) and source.schema==self.SCHEMA
        and not Secret(source.entries) and type(source.entries)=="table" then
        local examined=0
        for guid,value in pairs(source.entries) do
            examined=examined+1
            if examined>self.MAX_ENTRIES*4 then break end
            local entry=Sanitize(value,now)
            if entry and not Secret(guid) and guid==entry.guid then entries[#entries+1]=entry end
        end
    end
    table.sort(entries,function(a,b) if a.confirmedAt==b.confirmedAt then return a.guid<b.guid end;return a.confirmedAt>b.confirmedAt end)
    local saved={schema=self.SCHEMA,entries={}}
    for i=1,math.min(self.MAX_ENTRIES,#entries) do saved.entries[entries[i].guid]=entries[i] end
    RaidArsenalDB.inspectionCache=saved
    initialized=true
    return true
end
function Cache:Prune()
    if not self:Initialize() then return end
    local now=Epoch()
    if not now then return end
    local entries={}
    for guid,value in pairs(RaidArsenalDB.inspectionCache.entries) do
        local entry=Sanitize(value,now)
        if entry and not blocked[guid] then entries[#entries+1]=entry end
    end
    table.sort(entries,function(a,b) if a.confirmedAt==b.confirmedAt then return a.guid<b.guid end;return a.confirmedAt>b.confirmedAt end)
    local saved={}
    for i=1,math.min(self.MAX_ENTRIES,#entries) do saved[entries[i].guid]=entries[i] end
    RaidArsenalDB.inspectionCache.entries=saved
end
function Cache:Invalidate(guid)
    if not GUID(guid) then return false end
    blocked[guid]=true
    if self:Initialize() then RaidArsenalDB.inspectionCache.entries[guid]=nil end
    return true
end
function Cache:Clear()
    if not self:Initialize() then return false end
    for guid in pairs(RaidArsenalDB.inspectionCache.entries) do blocked[guid]=true end
    RaidArsenalDB.inspectionCache.entries={}
    return true
end
function Cache:Store(report)
    if Secret(report) or type(report)~="table" or Secret(report.verified) or Secret(report.cached) or Secret(report.source) or report.verified~=true or report.cached==true
        or (report.source~="LOCAL" and report.source~="INSPECT") or not self:Initialize() then return false end
    if Secret(report.capabilities) or type(report.capabilities)~="table" or Secret(report.evidence) or type(report.evidence)~="table" or Secret(report.evidence.roleOnly) then return false end
    local capabilities,evidence={},{}
    local count=0
    for index,value in pairs(report.capabilities or {}) do
        count=count+1
        local ability=not Secret(index) and RA.CatalogByIndex and RA.CatalogByIndex[index]
        if count>256 or Secret(value) or value~=true or not ability or not Text(ability.key,80) then return false end
        capabilities[ability.key]=true
        local fact=report.evidence and report.evidence[index]
        if Secret(fact) then return false end
        if not evidenceTypes[fact] then return false end
        evidence[ability.key]=fact
    end
    if report.evidence and report.evidence.roleOnly==true then evidence.roleOnly=true end
    local observer=UnitGUID and UnitGUID("player")
    local now=Epoch()
    if not now then return false end
    local entry=Sanitize({catalogVersion=RA.CATALOG_VERSION,guid=report.guid,name=report.name,class=report.class,specID=report.specID,role=report.role,
        classRevision=report.classRevision,confirmedAt=report.confirmedAt,source=report.source,observerGUID=observer,
        capabilities=capabilities,evidence=evidence},now)
    if not entry then return false end
    blocked[entry.guid]=nil
    RaidArsenalDB.inspectionCache.entries[entry.guid]=entry
    self:Prune()
    return true
end
function Cache:Get(guid,name,class,role)
    if not GUID(guid) or not Name(name) or not self:Initialize() or blocked[guid] then return nil end
    local entry=RaidArsenalDB.inspectionCache.entries[guid]
    local now=Epoch()
    if not now then return nil end
    entry=Sanitize(entry,now)
    if not entry then RaidArsenalDB.inspectionCache.entries[guid]=nil;return nil end
    if entry.name~=name or (self:IsKnownClass(class) and entry.class~=class) or (self:IsKnownRole(role) and entry.role and role~=entry.role) then
        self:Invalidate(guid)
        return nil
    end
    return entry
end
-- UnitFullName can temporarily omit a cross-realm player's realm. Only a
-- matching ordinary GUID and base name may recover its previous qualified name.
function Cache:ResolveName(guid,shortName)
    if not GUID(guid) or not Text(shortName,128) or shortName:find("-",1,true) or not self:Initialize() or blocked[guid] then return nil end
    local now=Epoch()
    local entry=now and Sanitize(RaidArsenalDB.inspectionCache.entries[guid],now)
    if entry and entry.name:match("^([^%-]+)%-")==shortName then return entry.name end
end
function Cache:RestoreRoster(roster,reports)
    if not self:Initialize() then return 0 end
    local count=0
    for name,info in pairs(roster or {}) do
        if not reports[name] then
            local entry=self:Get(info.guid,name,info.class,info.role)
            if entry then
                local capabilities,evidence={},{}
                for key in pairs(entry.capabilities) do local ability=RA.CatalogByKey[key];capabilities[ability.index]=true;evidence[ability.index]=entry.evidence[key] end
                if entry.evidence.roleOnly then evidence.roleOnly=true end
                reports[name]={name=entry.name,guid=entry.guid,class=entry.class,specID=entry.specID,role=entry.role,classRevision=entry.classRevision,
                    verified=true,source="PERSISTED_CACHE",originalSource=entry.source,cached=true,sessionVerified=false,confirmedAt=entry.confirmedAt,
                    observerGUID=entry.observerGUID,cacheRestoredAt=Epoch(),updatedAt=0,capabilities=capabilities,evidence=evidence}
                count=count+1
            end
        end
    end
    return count
end
