local _, RA = ...
local Recap = {}
RA.DeathRecap = Recap
Recap.LIMITS = { spells=32, casts=64, samples=1, seconds=30, rows=64, attempts=3, interval=.5 }
local passive, active, ticker, fetchTimer, eventTimer = {}, {}, nil, nil, nil
local session, last, generation, serial = nil, nil, 0, 0
local Association=RA.DeathRecapAssociation
local encounterContext
local RefreshTicker
local stats={samples=0,spellQueries=0,itemQueries=0,nativeReads=0,casts=0,rejectedNative=0}
local clientBuild

-- Fail closed if the client cannot establish public values. Never stringify,
-- compare, index, count or export an opaque native result before this check.
local function Public(value)
    if type(issecretvalue) ~= "function" then return nil end
    local ok, secret = pcall(issecretvalue,value)
    if not ok or secret ~= false then return nil end
    return value
end
local function Query(fn,...)
    if type(fn)~="function"then return nil,"unsupported"end
    local ok,value=pcall(fn,...);if not ok then return nil,"API-error"end
    if type(issecretvalue)~="function"then return nil,"trust-check-unavailable"end
    local checked,secret=pcall(issecretvalue,value)
    if not checked then return nil,"trust-check-failed"elseif secret==true then return nil,"restricted"elseif secret~=false then return nil,"trust-check-failed"end
    if value==nil then return nil,"nil-returned"end
    return value,"public"
end
local function FieldStatus(value,kind)
    if type(issecretvalue)~="function"then return "trust-check-unavailable"end
    local ok,secret=pcall(issecretvalue,value)
    if not ok or secret~=true and secret~=false then return "trust-check-failed"end
    if secret then return "restricted"end
    if value==nil then return "not-recorded"end
    if type(value)~=kind then return "malformed"end
    if kind=="number"and(value~=value or value==math.huge or value==-math.huge or value<0)then return "malformed"end
    return "public"
end
local function Number(value,low,high)
    value=Public(value)
    if type(value)~="number" or value~=value or value<(low or 0) or value>(high or 1e12) then return nil end
    return value
end
local function ID(value)
    value=Number(value,1,2147483647)
    return value and value==math.floor(value) and value or nil
end
local function Bool(value)
    value=Public(value);if type(value)=="boolean" then return value end
end
local function String(value,limit)
    value=Public(value)
    if type(value)=="string" and #value<=(limit or 128) and not value:find("[%z\r\n]") then return value end
end
local function Table(value)
    value=Public(value);if type(value)=="table" and getmetatable(value)==nil then return value end
end
local function Call(fn,...)
    if type(fn)~="function" then return nil end
    local ok,value=pcall(fn,...);if ok then return value end
end
local function Now()return Number(Call(GetTime))end
local function Alive()return Bool(Call(UnitIsDeadOrGhost,"player"))==false end
local function Combat()return Bool(Call(InCombatLockdown))==true end
local function Known(id)
    local bank=Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if bank==nil then return nil end
    return Bool(Call(C_SpellBook and C_SpellBook.IsSpellKnown,id,bank))
end
local function Settings()local db=RA:GetDB();return db and db.deathRecap or {} end
local function Enabled()return Settings().enabled==true end
local function Copy(value)
    if type(value)~="table" then return value end
    local result={};for key,item in pairs(value)do result[key]=Copy(item)end;return result
end
local function Notify(kind)RA:FireCallback("DEATH_RECAP_CHANGED",kind)end
local function CancelFetch()
    generation=generation+1
    if fetchTimer then fetchTimer:Cancel();fetchTimer=nil end
end
local function StopRecording()
    if ticker then ticker:Cancel();ticker=nil end
    if eventTimer then eventTimer:Cancel();eventTimer=nil end
    for _,subscription in ipairs(active)do subscription:SetEnabled(false)end
end

local function RecordedHealth(value,positive)
    value=Public(value)
    if type(value)~="number"or value~=value or value==math.huge or value==-math.huge
        or value<0 or(positive and value==0)then return nil end
    return value
end
local function NativePacket(recapID)
    stats.nativeReads=stats.nativeReads+1
    if not C_DeathRecap then return nil,"Native recap API unavailable" end
    local has=Bool(Call(C_DeathRecap.HasRecapEvents,recapID))
    if has~=true then return nil,"native_events_unavailable"end
    local readBefore=Now()
    local input=Table(Call(C_DeathRecap.GetRecapEvents,recapID))
    local readAfter=Now()
    if not input or #input==0 then return nil,"Native rows unavailable" end
    local maxValue,maxStatus=Query(C_DeathRecap.GetRecapMaxHealth,recapID)
    local recapMaxHealth=RecordedHealth(maxValue,true)
    if maxStatus=="public"and recapMaxHealth==nil then maxStatus="malformed"end
    local rows={}
    for index=1,math.min(#input,Recap.LIMITS.rows)do
        local row=Table(input[index]);if not row then return nil,"Native row unreadable" end
        local timestamp=Number(row.timestamp)
        local destination=String(row.destGUID,128)
        if not timestamp then return nil,"Native time unreadable"end
        local kind=String(row.event,40)
        local spell=ID(row.spellId)
        local amount=Number(row.amount,0,1e15)
        -- Raw health belongs to this event; its before/after-hit semantics are
        -- unspecified. The one recap max is a reference, not per-event history.
        local damage=kind=="SWING_DAMAGE"or kind=="RANGE_DAMAGE"or kind=="SPELL_DAMAGE"
            or kind=="SPELL_PERIODIC_DAMAGE"or kind=="ENVIRONMENTAL_DAMAGE"or kind=="DAMAGE_SHIELD"or kind=="DAMAGE_SPLIT"
        rows[#rows+1]={timestamp=timestamp,destGUID=destination,spellID=spell,kind=damage and"damage"or"unknown",
            name=String(row.spellName,96),event=kind,amount=amount,nativeIndex=index,
            recordedHP=RecordedHealth(row.currentHP),sourceName=String(row.sourceName,96),hideCaster=Bool(row.hideCaster),
            sourceConfirmed=false,hideCasterStatus=FieldStatus(row.hideCaster,"boolean"),absorbed=Number(row.absorbed,0,1e15),overkill=Number(row.overkill,0,1e15),
            resisted=Number(row.resisted,0,1e15),blocked=Number(row.blocked,0,1e15),school=ID(row.school),
            avoidable=Bool(row.avoidable),deadly=Bool(row.deadly),
            fieldStatus={hp=FieldStatus(row.currentHP,"number"),source=FieldStatus(row.sourceName,"string"),
                absorbed=FieldStatus(row.absorbed,"number"),overkill=FieldStatus(row.overkill,"number")}}
    end
    return {rows=rows,truncated=#input>Recap.LIMITS.rows,recapMaxHealth=recapMaxHealth,recapMaxHealthStatus=maxStatus,readBefore=readBefore,readAfter=readAfter}
end
local function BuildEntries()
    local spec=ID(Call(GetSpecialization))
    spec=spec and ID(Call(GetSpecializationInfo,spec))
    local classOK,class=pcall(function()local _,value=UnitClass("player");return value end)
    class=classOK and String(class,20)or nil
    local entries,overflow,unknown,seen={},false,0,{}
    for _,entry in ipairs((RA.DeathRecapCatalog or {}).entries or {})do
        local eligible=false
        for _,id in ipairs(entry.specs or {})do if id==spec then eligible=true end end
        if entry.verified==true and eligible and entry.class==class and #entries<Recap.LIMITS.spells then
            local selected,known=entry.spellID,false
            for _,id in ipairs(entry.knownSpellIDs or {entry.spellID})do
                local value=Known(id)
                if value==true then selected,known=id,true;break end
                if value==nil then known=nil end
            end
            local resolved=known==true and ID(Call(C_Spell and C_Spell.GetOverrideSpell,selected))or nil
            for _,required in ipairs(entry.requiredTalentSpellIDs or {})do
                if Known(required)~=true then known=nil;break end
            end
            local supported=false
            for _,id in ipairs(entry.knownSpellIDs or {entry.spellID})do if resolved==id then supported=true end end
            local passive=resolved and Bool(Call(C_Spell and C_Spell.IsSpellPassive,resolved))
            if known==true and supported and passive==false and not seen[resolved] then
                selected=resolved;seen[resolved]=true
                entries[#entries+1]={key=entry.key,spellID=selected,name=entry.name,category=entry.category,known=true}
            elseif known==nil or (known==true and (not supported or passive==nil))then unknown=unknown+1 end
        elseif entry.verified==true and eligible and entry.class==class then
            overflow=true
        end
    end
    return entries,spec,class,overflow,unknown
end
local function SpellObservation(entry,time,reason)
    stats.spellQueries=stats.spellQueries+1
    local row={spellID=entry.spellID,key=entry.key,name=entry.name,category=entry.category,
        known=entry.known,observedAt=time,source=reason,cooldown="unknown"}
    local value,status=Query(C_Spell and C_Spell.GetSpellCooldown,entry.spellID)
    local info=Table(value);row.cooldownQuery=info and"public"or(status=="public"and"malformed"or status)
    if info then
        row.isEnabled,row.isActive=Bool(info.isEnabled),Bool(info.isActive)
        row.cooldownEnabledStatus,row.cooldownActiveStatus=FieldStatus(info.isEnabled,"boolean"),FieldStatus(info.isActive,"boolean")
        if row.isEnabled==false then row.cooldown="held"
        elseif row.isEnabled==true and row.isActive==false then row.cooldown="inactive"
        elseif row.isEnabled==true and row.isActive==true then
            row.cooldown="active"
            if reason=="cooldown-event" then
                row.isOnGCD=Bool(info.isOnGCD)
                if row.isOnGCD==true then row.cooldown="gcd-only" end
            end
        end
    end
    local charges
    row.chargeQuery="unsupported"
    if C_Spell and type(C_Spell.GetSpellCharges)=="function"then
        local got,value=pcall(C_Spell.GetSpellCharges,entry.spellID)
        local secretOK,isSecret=pcall(issecretvalue,value)
        if not got then row.chargeQuery="error";row.chargeReason="API-error"
        elseif not secretOK or isSecret~=false then row.chargeQuery="unreadable";row.chargeReason=secretOK and isSecret==true and"restricted"or"trust-check-failed"
        elseif value==nil then row.chargeQuery="not_applicable"
        else charges=Table(value);row.chargeQuery=charges and"public"or"malformed"end
    end
    if charges then
        row.chargesActive=Bool(charges.isActive)
        row.maxCharges=ID(charges.maxCharges)
        row.currentCharges=Number(charges.currentCharges,0,100)
        row.chargeCountStatus=FieldStatus(charges.currentCharges,"number")
        if row.currentCharges and (row.currentCharges~=math.floor(row.currentCharges)
            or not row.maxCharges or row.currentCharges>row.maxCharges)then row.currentCharges=nil end
    end
    return row
end
local function Stock(itemID,uses)
    stats.stockQueries=(stats.stockQueries or 0)+1
    local value,status=Query(C_Item and C_Item.GetItemCount,itemID,false,uses,false,false)
    local count=Number(value,0,100000)
    if count and count==math.floor(count)then return count,"public"end
    return nil,status=="public"and"malformed"or status
end
local function SupplyObservations(time,reason,death)
    local snapshot=RA.HealingSupplies:GetCached("recap")
    local result={}
    for _,kind in ipairs({"stone","potion"})do
        local candidates={}
        for _,candidate in ipairs(snapshot and snapshot.candidates or{})do if candidate.kind==kind then candidates[#candidates+1]=candidate end end
        if #candidates==0 then candidates[1]={kind=kind}end
        for _,candidate in ipairs(candidates)do
            local row={kind=kind,category=kind,source=reason,observedAt=time,cooldown="unknown",itemID=candidate.id,icon=candidate.icon}
            if snapshot then
                row.carried=candidate.id and true or snapshot[kind];row.carriedAt=snapshot.observedAt
                row.cacheGeneration=snapshot.cacheGeneration;row.partial=snapshot.partial or snapshot.candidatesTruncated
                row.familyAbsenceVerified=not candidate.id and snapshot[kind]==false and not snapshot.candidatesTruncated
                if row.itemID then
                    row.physicalCount,row.countStatus=Stock(row.itemID,false);row.countAt=time
                    row.remainingUses,row.usesStatus=Stock(row.itemID,true);row.usesAt=time
                    if C_Item and type(C_Item.GetItemCooldown)=="function"then
                        stats.itemQueries=stats.itemQueries+1
                        local ok,start,duration,enabled=pcall(C_Item.GetItemCooldown,row.itemID)
                        row.cooldownQuery=ok and"public"or"API-error"
                        row.cooldownStartStatus,row.cooldownDurationStatus=FieldStatus(start,"number"),FieldStatus(duration,"number")
                        start,duration,enabled=Number(start),Number(duration),Bool(enabled);row.enableCooldownTimer=enabled
                        if ok and enabled==true and start and duration then row.cooldown=(duration==0 or start+duration<=time)and"inactive"or"active"end
                    else row.cooldownQuery="unsupported"end
                end
            end
            result[#result+1]=row
        end
    end
    return result
end
local function Pending(domain,time,reason,spellID)
    if not session or not session.lastAlive then return end
    local rows=domain=="items"and session.lastAlive.supplies or session.lastAlive.spells
    for _,row in ipairs(rows)do if not spellID or row.spellID==spellID then row.pendingAt=row.pendingAt or time;row.pendingReason=reason end end
end
local function Observe(reason,death)
    local time=Now();if not session or not time or (not death and not Alive())then return nil end
    local sample={observedAt=time,source=reason,spells={},supplies=SupplyObservations(time,reason,death)}
    stats.samples=stats.samples+1
    for index,entry in ipairs(session.entries)do
        local previous=session.lastAlive and session.lastAlive.spells[index]
        if previous and not previous.pendingAt and ((reason=="item-event"or reason=="bags-event")or (reason=="interval" and previous.cooldown~="active"and previous.cooldown~="gcd-only"and previous.chargesActive~=true))then
            sample.spells[#sample.spells+1]=Copy(previous)
        else sample.spells[#sample.spells+1]=SpellObservation(entry,time,reason)end
    end
    if not death then
        session.lastAlive=sample
        if RefreshTicker then RefreshTicker()end
    end
    return sample
end
local function NewSession(reason)
    if not Enabled()or not Alive()then return end
    local entries,spec,class,overflow,unknown=BuildEntries()
    session={entries=entries,specID=spec,class=class,casts={},startedAt=Now(),
        playerGUID=String(Call(UnitGUID,"player")),coverage=reason,overflow=overflow,unknownKnown=unknown,
        encounter=Copy(encounterContext),eventAt={}}
end
RefreshTicker=function()
    local needed=false
    if Enabled()and Alive()and Combat()and session and session.lastAlive then
        for _,row in ipairs(session.lastAlive.spells)do
            if row.cooldown=="active"or row.cooldown=="gcd-only"or row.chargesActive==true then needed=true end
        end
        for _,row in ipairs(session.lastAlive.supplies)do if row.cooldown=="active"then needed=true end end
    end
    if not needed then if ticker then ticker:Cancel();ticker=nil end;return end
    if not ticker and C_Timer and C_Timer.NewTicker then ticker=C_Timer.NewTicker(Recap.LIMITS.interval,function()
        if Enabled()and Alive()and Combat()then Observe("interval",false)else StopRecording()end
    end)end
end
local function BeginCombat(reason)
    StopRecording();NewSession(reason)
    if not Enabled()or not Alive()or not session then return end
    Observe("pull-baseline",false)
    for _,subscription in ipairs(active)do subscription:SetEnabled(true)end
end
local function FetchNative(page,token)
    if not Enabled()or token~=generation or page.captureGeneration~=generation or last~=page then return end
    page.nativeAttempts=page.nativeAttempts+1
    local recapID,reason,set=Association:Candidate(page.association)
    local packet
    if recapID then packet,reason=NativePacket(recapID)end
    if packet then
        local own=true
        for _,row in ipairs(packet.rows)do
            if row.destGUID and page.playerGUID and row.destGUID~=page.playerGUID then own=false end
        end
        if own and #packet.rows>0 and Association:Commit(page.association,recapID,set)then
            local maximum=0;for _,row in ipairs(packet.rows)do maximum=math.max(maximum,row.timestamp)end
            for _,row in ipairs(packet.rows)do row.nativeOffset=row.timestamp-maximum end
            page.native={rows=packet.rows,truncated=packet.truncated,token=packet.token,recapID=recapID,
                recapMaxHealth=packet.recapMaxHealth,recapMaxHealthStatus=packet.recapMaxHealthStatus,
                clockDiagnostic={localClock="GetTime",localSessionStartedAt=page.localSessionStartedAt,localDeathNoticeAt=page.diedAt,
                    nativeReadLocalBefore=packet.readBefore,nativeReadLocalAfter=packet.readAfter,nativeFirstTimestamp=packet.rows[1].timestamp,
                    nativeMaximumTimestamp=maximum,nativeRowCount=#packet.rows,nativeTimestampStatus="public-finite-number"},
                association="Explicit personal death ID delta in a witnessed clean meter epoch; native synchronization testing pending",
                clock="Native relative to latest retained native timestamp; not the local observation clock"}
            local minimum=maximum
            for _,row in ipairs(packet.rows)do
                minimum=math.min(minimum,row.timestamp)
                if row.nativeIndex==1 then page.native.clockDiagnostic.nativeFatalTimestamp=row.timestamp end
            end
            page.native.clockDiagnostic.nativeMinimumTimestamp=minimum
            page.nativeStatus="Personal native record associated; native verification pending"
            page.nativeReason="associated_personal_id";Notify("native");return
        end
        reason="foreign_native_destination"
    end
    page.nativeReason=reason or"association_unverified"
    page.nativeStatus="Current native recap unavailable: "..page.nativeReason
    stats.rejectedNative=stats.rejectedNative+1
    Notify("native")
    if page.nativeAttempts<Recap.LIMITS.attempts and not(Combat()and page.nativeAttempts>=2)and C_Timer and C_Timer.NewTimer then
        fetchTimer=C_Timer.NewTimer(page.nativeAttempts==1 and .5 or 1,function()fetchTimer=nil;FetchNative(page,token)end)
    end
end
local function OnDeath()
    if not Enabled()then return end
    StopRecording();CancelFetch()
    local time=Now();if not session or session.dead or not time then Notify("unavailable");return end
    serial=serial+1
    local page={id=serial,captureGeneration=generation,diedAt=time,playerGUID=session.playerGUID,specID=session.specID,class=session.class,
        coverage=session.coverage,overflow=session.overflow,unknownKnown=session.unknownKnown,
        encounter=Copy(session.encounter),knownEntries=Copy(session.entries),localSessionStartedAt=session.startedAt,lastAlive=Copy(session.lastAlive),
        casts={},deathObservation=Observe("death-notification",true),
        association=Association:Freeze(),nativeAttempts=0,nativeStatus="Waiting for a fresh personal native recap"}
    for _,cast in ipairs(session.casts)do if time-cast.observedAt<=Recap.LIMITS.seconds then page.casts[#page.casts+1]=Copy(cast)end end
    session.dead=true;last=page;Notify("death");FetchNative(page,generation)
end
function Recap:GetPage()return last end
function Recap:GetDiagnostics()
    if not clientBuild then
        clientBuild={}
        if type(GetBuildInfo)=="function"then
            local ok,version,build,_,interface=pcall(GetBuildInfo)
            if ok then clientBuild={version=String(version,32),build=String(build,32),interface=ID(interface)}end
        end
    end
    local result=Copy(stats);result.optionalEnabled=Enabled();result.tickerActive=ticker~=nil
    result.client=Copy(clientBuild);result.catalogBuild=(RA.DeathRecapCatalog or{}).build
    result.fetchPending=fetchTimer~=nil;result.eventRefreshPending=eventTimer~=nil;result.trackedSpells=session and #session.entries or 0
    result.retainedSamples=session and session.lastAlive and 1 or 0;result.retainedCasts=session and #session.casts or 0
    result.catalogOverflow=session and session.overflow or false
    result.association=Association:GetDiagnostics()
    result.nativeClock=last and last.native and Copy(last.native.clockDiagnostic)or nil
    result.nativeStatus=last and last.nativeStatus or "No personal death recorded this session"
    return result
end
function Recap:GetState()
    return {enabled=Enabled(),autoOpen=Settings().autoOpen~=false,hasPage=last~=nil,
        recording=ticker~=nil,coverage=session and session.coverage or "No alive observations"}
end
function Recap:Refresh()
    StopRecording();CancelFetch();session=nil
    local enabled=Enabled()
    Association:SetEnabled(enabled)
    RA.HealingSupplies:SetConsumer("recap",enabled)
    for _,subscription in ipairs(passive)do subscription:SetEnabled(enabled)end
    if enabled then if Combat()then BeginCombat("Enabled/reloaded during combat; incomplete coverage")else NewSession("No combat observations yet")end end
    Notify("settings")
end
function Recap:SetOption(key,value)
    if key~="enabled"and key~="autoOpen"then return false end
    local db=RA:GetDB();db.deathRecap=db.deathRecap or {};db.deathRecap[key]=value==true
    if key=="enabled"then self:Refresh()else Notify("settings")end
    return true
end
function Recap:EnableReminder()
    return RA.PersonalTools:SetOption("consumableReminder",true)
end
local function Passive(event,callback)passive[#passive+1]=RA:RegisterOptionalEvent(event,callback)end
local function Active(event,callback,unit)active[#active+1]=RA:RegisterOptionalEvent(event,callback,unit)end
Passive("PLAYER_DEAD",OnDeath)
Passive("PLAYER_REGEN_DISABLED",function()BeginCombat("Observed combat entry; bounded 30-second history")end)
Passive("PLAYER_REGEN_ENABLED",function()
    if session and session.lastAlive then session.lastAlive.coverageEndedAt=Now();session.lastAlive.coverageEndReason="combat-ended"end
    StopRecording()
    if last and not last.native and last.nativeAttempts<Recap.LIMITS.attempts then
        if fetchTimer then fetchTimer:Cancel();fetchTimer=nil end
        FetchNative(last,generation)
    end
end)
for _,event in ipairs({"DAMAGE_METER_CURRENT_SESSION_UPDATED","DAMAGE_METER_RESET"})do
    Passive(event,function()CancelFetch();Association:NewEpoch(Alive())end)
end
Passive("DAMAGE_METER_COMBAT_SESSION_UPDATED",function(_,kind,id)
    Association:Update(kind,id,Alive())
end)
for _,event in ipairs({"PLAYER_ALIVE","PLAYER_UNGHOST","PLAYER_ENTERING_WORLD"})do
    Passive(event,function()
        StopRecording();CancelFetch();if event=="PLAYER_ENTERING_WORLD"then encounterContext=nil end
        if Alive()then
            if Combat()then BeginCombat("Resurrected/entered during combat; incomplete coverage")
            else NewSession("Alive baseline; no combat observations yet")end
        end;Notify("life")
    end)
end
for _,event in ipairs({"PLAYER_SPECIALIZATION_CHANGED","TRAIT_CONFIG_UPDATED","SPELLS_CHANGED"})do
    Passive(event,function(_,unit)
        if event=="PLAYER_SPECIALIZATION_CHANGED"and String(unit,16)and String(unit,16)~="player"then return end
        if Combat()then BeginCombat("Spell/spec identity changed; earlier coverage discarded")else NewSession("Spell/spec identity refreshed")end
    end)
end
Passive("ENCOUNTER_START",function(_,id,name,difficulty)
    encounterContext={encounterID=ID(id),name=String(name,96),difficulty=ID(difficulty),startedAt=Now()}
    if session then session.encounter=Copy(encounterContext)end
end)
Passive("ENCOUNTER_END",function()encounterContext=nil;if session then session.encounter=nil end end)
Active("UNIT_SPELLCAST_SUCCEEDED",function(_,unit,_,spellID)
    if String(unit,16)~="player"or not Alive()or not session then return end
    local time=Now();spellID=ID(spellID);if not time or not spellID then return end
    local tracked,trackedName,trackedItemUse=false,nil,false
    for _,entry in ipairs(session.entries)do if entry.spellID==spellID then tracked=true;trackedName=entry.name;break end end
    if (RA.DeathRecapCatalog or {}).itemUseSpells and RA.DeathRecapCatalog.itemUseSpells[spellID]then tracked=true;trackedItemUse=true end
    if not tracked then return end
    session.casts[#session.casts+1]={spellID=spellID,name=trackedName,observedAt=time,source="UNIT_SPELLCAST_SUCCEEDED"}
    if trackedItemUse then Pending("items",time,"item-cast-received")else Pending("spells",time,"cast-received",spellID)end
    stats.casts=stats.casts+1
    while #session.casts>Recap.LIMITS.casts or time-session.casts[1].observedAt>Recap.LIMITS.seconds do table.remove(session.casts,1)end
end,"player")
Active("BAG_UPDATE_DELAYED",function()Observe("bags-event",false)end)
for _,event in ipairs({"BAG_UPDATE_COOLDOWN","ACTION_USABLE_CHANGED","SPELL_UPDATE_USABLE"})do
    Active(event,function()
        local time=Now();if not session or not time then return end
        if session.itemEventAt and time-session.itemEventAt<.1 then
            Pending("items",time,"pending-item-update")
            if not eventTimer and C_Timer and C_Timer.NewTimer then
                eventTimer=C_Timer.NewTimer(.1,function()eventTimer=nil;if Enabled()and Alive()and Combat()then Observe("coalesced-events",false)end end)
            end
        else session.itemEventAt=time;Observe("item-event",false)end
    end)
end
for _,pair in ipairs({{"SPELL_UPDATE_COOLDOWN","cooldown-event"},{"SPELL_UPDATE_CHARGES","charge-event"}})do
    local event,reason=pair[1],pair[2]
    Active(event,function()
        local time=Now();if not session or not time then return end
        if session.eventAt[reason]and time-session.eventAt[reason]<.1 then
            Pending("spells",time,"pending-"..reason)
            stats.coalescedEvents=(stats.coalescedEvents or 0)+1
            if not eventTimer and C_Timer and C_Timer.NewTimer then
                eventTimer=C_Timer.NewTimer(.1,function()
                    eventTimer=nil
                    if Enabled()and Alive()and Combat()then Observe("coalesced-events",false)end
                end)
            end
            return
        end
        session.eventAt[reason]=time;Observe(reason,false)
    end)
end
RA:RegisterInitializer(function()Recap:Refresh()end)
RA:RegisterCallback("PROFILE_RESET",function()Recap:Refresh()end)
