local _,RA=...
local A={};RA.DeathRecapAssociation=A
local enabled,epoch,witnessed,baseline,unmatched,blocked=false,0,false,nil,0,false
local accepted,acceptedCount,latestHint={},0,nil
A.MAX_ACCEPTED=256
local stats={reads=0,rows=0}
local function Public(value)
    if type(issecretvalue)~="function"then return nil end
    local ok,secret=pcall(issecretvalue,value);if ok and secret==false then return value end
end
local function ID(value)
    value=Public(value)
    if type(value)=="number"and value==value and value>0 and value<2147483648 and value==math.floor(value)then return value end
end
local function Table(value)
    value=Public(value);if type(value)=="table"and getmetatable(value)==nil then return value end
end
local function Copy(set)local out={};for key in pairs(set or{})do out[key]=true end;return out end
local function Scan()
    if not enabled or not C_DamageMeter or not Enum or not Enum.DamageMeterType or not Enum.DamageMeterSessionType then return nil,"meter_unavailable"end
    local fn=C_DamageMeter.GetCombatSessionFromType
    if type(fn)~="function"then return nil,"meter_unavailable"end
    stats.reads=stats.reads+1
    local ok,value=pcall(fn,Enum.DamageMeterSessionType.Current,Enum.DamageMeterType.Deaths)
    local session=ok and Table(value)
    local rows=session and Table(session.combatSources)
    if not rows then return nil,"meter_unreadable"end
    if #rows>128 then return nil,"meter_overflow"end
    local set,count={},0
    for index=1,#rows do
        stats.rows=stats.rows+1
        local row=Table(rows[index]);if not row then return nil,"meter_unreadable"end
        local own=Public(row.isLocalPlayer)
        if type(own)~="boolean"then return nil,"identity_unreadable"end
        if own then
            local recapID=ID(row.deathRecapID);if not recapID then return nil,"identity_unreadable"end
            if not set[recapID]then count=count+1;set[recapID]=true end
            if count>64 then return nil,"personal_id_overflow"end
        end
    end
    return set
end
function A:SetEnabled(value)
    if enabled==(value==true)then return end
    enabled=value==true;epoch=epoch+1;witnessed=false;latestHint=nil;baseline=nil;unmatched=0;blocked=false;accepted={};acceptedCount=0
end
function A:NewEpoch(alive)
    epoch=epoch+1;witnessed=false;latestHint=nil;baseline=nil;unmatched=0;blocked=false
    if not enabled or not alive then return end
    local set=Scan()
    -- A witnessed clean native epoch with a complete empty personal set is
    -- required. Late enable/reload or a nonempty/opaque baseline stays unknown.
    if set and next(set)==nil then baseline=set;witnessed=true end
end
function A:Update(kind,id,alive)
    if not enabled or not Enum or not Enum.DamageMeterType or Public(kind)~=Enum.DamageMeterType.Deaths then return false end
    local value=Public(id)
    if value~=0 then value=ID(value)end
    if value==nil then return false end
    -- Overall0 and positive notifications are dirty hints, not session binding
    -- evidence. Current owns identity; restricted getters cannot poison it here.
    latestHint=value;return true
end
function A:Freeze()
    unmatched=unmatched+1
    if unmatched~=1 then blocked=true end
    return {epoch=epoch,source="Current",baseline=Copy(baseline),known=witnessed and baseline~=nil and not blocked,
        ordinal=unmatched}
end
function A:Candidate(token)
    if not enabled or not token or token.epoch~=epoch then return nil,"meter_epoch_changed"end
    if not token.known or not witnessed or not baseline then return nil,"alive_baseline_unverified"end
    if blocked or unmatched~=1 or token.ordinal~=1 then return nil,"multiple_or_unresolved_deaths"end
    local set,reason=Scan();if not set then return nil,reason end
    for id in pairs(token.baseline)do if not set[id]then return nil,"baseline_ids_removed"end end
    local chosen,count=nil,0
    for id in pairs(set)do
        if not token.baseline[id]then chosen=id;count=count+1 end
    end
    if count~=1 or accepted[chosen]then return nil,"personal_id_delta_ambiguous"end
    if acceptedCount>=self.MAX_ACCEPTED then return nil,"accepted_id_limit"end
    return chosen,nil,set
end
function A:Commit(token,id,set)
    if token.epoch~=epoch or unmatched~=1 or accepted[id]or acceptedCount>=self.MAX_ACCEPTED then return false end
    accepted[id]=true;acceptedCount=acceptedCount+1;baseline=Copy(set);unmatched=0;return true
end
function A:GetDiagnostics()
    return {reads=stats.reads,rows=stats.rows,epoch=epoch,baselineKnown=witnessed and baseline~=nil and not blocked,
        unmatchedDeaths=unmatched,sessionBound=false,source="Current",latestSessionHint=latestHint,acceptedIDs=acceptedCount,acceptedLimit=self.MAX_ACCEPTED}
end
