local _, RA = ...
local Recap = {}
RA.DeathRecap = Recap
Recap.LIMITS = { spells=32, casts=64, samples=1, seconds=30, rows=64, attempts=3, interval=.5 }
local passive, active, ticker, fetchTimer, eventTimer = {}, {}, nil, nil, nil
local session, last, generation, serial = nil, nil, 0, 0
local Association=RA.DeathRecapAssociation
local encounterContext;local encounterSerial=0
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
        -- Native's swing identity is display metadata, never a cast receipt.
        local rawName=String(row.spellName,96)
        rows[#rows+1]={timestamp=timestamp,destGUID=destination,spellID=kind=="SWING_DAMAGE"and 88163 or spell,kind=damage and"damage"or"unknown",
            name=kind=="SWING_DAMAGE"and(String(ACTION_SWING,96)or"Melee")or rawName,
            rawSpellID=spell,rawSpellName=rawName,event=kind,amount=amount,nativeIndex=index,
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
                entries[#entries+1]={key=entry.key,spellID=selected,baseSpellID=ID(Call(C_Spell and C_Spell.GetBaseSpell,selected)),name=entry.name,category=entry.category,known=true}
            elseif known==nil or (known==true and (not supported or passive==nil))then unknown=unknown+1 end
        elseif entry.verified==true and eligible and entry.class==class then
            overflow=true
        end
    end
    return entries,spec,class,overflow,unknown
end
local function SpellObservation(entry,time,reason,flagsOnly)
    stats.spellQueries=stats.spellQueries+1
    local row={spellID=entry.spellID,key=entry.key,name=entry.name,category=entry.category,
        known=entry.known,observedAt=time,cooldownAt=time,source=reason,cooldown="unknown",cooldownGCDStatus="not-event-context"}
    local value,status=Query(C_Spell and C_Spell.GetSpellCooldown,entry.spellID)
    local info=Table(value);row.cooldownQuery=info and"public"or(status=="public"and"malformed"or status)
    if info then
        row.isEnabled,row.isActive=Bool(info.isEnabled),Bool(info.isActive)
        row.cooldownEnabledStatus,row.cooldownActiveStatus=FieldStatus(info.isEnabled,"boolean"),FieldStatus(info.isActive,"boolean")
        if reason=="cooldown-event" then
            row.isOnGCD=Bool(info.isOnGCD);row.cooldownGCDStatus=FieldStatus(info.isOnGCD,"boolean")
        end
        if row.isEnabled==false then row.cooldown="held"
        elseif row.isEnabled==true and row.isActive==false then row.cooldown="inactive"
        elseif row.isEnabled==true and row.isActive==true then
            row.cooldown="active-context-unknown"
            if row.isOnGCD==true then row.cooldown="gcd-observed"
            elseif row.isOnGCD==false then row.cooldown="active"end
        end
    end
    if flagsOnly then return row end
    row.chargesAt=time
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
        row.chargesActive=Bool(charges.isActive);row.chargeActiveStatus=FieldStatus(charges.isActive,"boolean");row.maxChargesStatus=FieldStatus(charges.maxCharges,"number")
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
    for _,row in ipairs(rows)do if not spellID or row.spellID==spellID then
        row.pendingAt=row.pendingAt or time;row.pendingReason=reason
        if row.directCooldown then row.directCooldown.valid=false;row.directCooldown.invalidatedAt=time;row.directCooldown.invalidatedBy=reason end
    end end
    if domain=="items"then session.itemsDirty=true end
end
local cooldownFields={"cooldown","cooldownAt","cooldownQuery","isEnabled","isActive","isOnGCD","cooldownEnabledStatus","cooldownActiveStatus","cooldownGCDStatus"}
local function ActiveCooldown(row)
    return row.cooldown=="active"or row.cooldown=="gcd-observed"or row.cooldown=="active-context-unknown"
end
local function ReconcileSpell(entry,previous,time,reason,death)
    local row=SpellObservation(entry,time,reason)
    local direct=previous and Copy(previous.directCooldown)
    row.directCooldown=direct
    if direct and direct.valid then
        if direct.isEnabled~=row.isEnabled or direct.isActive~=row.isActive or row.cooldownQuery~="public"then
            direct.valid=false;direct.invalidatedAt=time;direct.invalidatedBy="generic-flags-changed"
        elseif not death then
            -- Keep the direct check's original age. The newer generic flags and
            -- charges are separate observations; they cannot renew its GCD fact.
            row.genericCooldown={observedAt=time,isEnabled=row.isEnabled,isActive=row.isActive,cooldown=row.cooldown,source=reason}
            for _,key in ipairs(cooldownFields)do row[key]=direct[key]end
            row.observedAt=direct.observedAt;row.source="retained-cooldown-event"
        end
    end
    return row
end
local function Observe(reason,death)
    local time=Now();if not session or not time or (not death and not Alive())then return nil end
    local previousSample=session.lastAlive
    local itemReason=reason=="item-event"or reason=="bags-event"or reason=="item-data-event"
    local refreshItems=death or not previousSample or itemReason or(reason=="coalesced-events"and session.itemsDirty)
    if reason=="interval"then for _,row in ipairs(previousSample and previousSample.supplies or{})do if row.cooldown=="active"or row.pendingAt then refreshItems=true end end end
    local sample={observedAt=time,source=reason,spells={},supplies=refreshItems and SupplyObservations(time,reason,death)or Copy(previousSample.supplies)}
    if not death and refreshItems then session.itemsDirty=false end
    stats.samples=stats.samples+1
    for index,entry in ipairs(session.entries)do
        local previous=previousSample and previousSample.spells[index]
        if previous and(itemReason or(not previous.pendingAt and not previous.chargesPendingAt and reason=="interval" and not ActiveCooldown(previous)and previous.chargesActive~=true))then
            sample.spells[#sample.spells+1]=Copy(previous)
        else sample.spells[#sample.spells+1]=ReconcileSpell(entry,previous,time,reason,death)end
    end
    if not death then
        session.lastAlive=sample
        if RefreshTicker then RefreshTicker()end
    end
    return sample
end
local function ScheduleObservation()
    if eventTimer or not session or not C_Timer or not C_Timer.NewTimer then return end
    local owner=session;local timer
    timer=C_Timer.NewTimer(.1,function()
        if eventTimer~=timer or session~=owner then return end
        eventTimer=nil
        if Enabled()and Alive()and Combat()then Observe("coalesced-events",false)end
    end)
    eventTimer=timer
end
local function NewSession(reason,combatEntryObserved)
    if not Enabled()or not Alive()then return end
    Notify("reset")
    local entries,spec,class,overflow,unknown=BuildEntries()
    session={entries=entries,specID=spec,class=class,casts={},observedUses={},directSpellEvents={},startedAt=Now(),combatEntryObserved=combatEntryObserved==true,
        playerGUID=String(Call(UnitGUID,"player")),coverage=reason,overflow=overflow,unknownKnown=unknown,
        encounter=Copy(encounterContext),eventAt={}}
end
RefreshTicker=function()
    local needed=false
    if Enabled()and Alive()and Combat()and session and session.lastAlive then
        for _,row in ipairs(session.lastAlive.spells)do
            if ActiveCooldown(row)or row.chargesActive==true then needed=true end
        end
        for _,row in ipairs(session.lastAlive.supplies)do if row.cooldown=="active"then needed=true end end
    end
    if not needed then if ticker then ticker:Cancel();ticker=nil end;return end
    if not ticker and C_Timer and C_Timer.NewTicker then
        local owner=session;local timer
        timer=C_Timer.NewTicker(Recap.LIMITS.interval,function()
            if ticker~=timer or session~=owner then return end
            if Enabled()and Alive()and Combat()then Observe("interval",false)else StopRecording()end
        end);ticker=timer
    end
end
local function BeginCombat(reason,combatEntryObserved)
    StopRecording();NewSession(reason,combatEntryObserved)
    if not Enabled()or not Alive()or not session then return end
    Observe("pull-baseline",false)
    for _,subscription in ipairs(active)do subscription:SetEnabled(true)end
end
local FetchNative
local function ReservePublicRetry(page)
    -- A restricted Current container may stay unreadable for the whole fight.
    -- Preserve the final shared attempt for combat end instead of spending it
    -- on another dirty hint while the same access boundary still applies.
    return page.nativeAttempts>=Recap.LIMITS.attempts-1 and page.nativeReason=="meter_unreadable"and Combat()
end
local function ScheduleNative(page,token,delay)
    if fetchTimer or ReservePublicRetry(page)or not C_Timer or not C_Timer.NewTimer then return end
    local timer
    timer=C_Timer.NewTimer(delay,function()
        if fetchTimer~=timer then return end
        fetchTimer=nil;FetchNative(page,token)
    end)
    fetchTimer=timer
end
FetchNative=function(page,token)
    if not Enabled()or token~=generation or page.captureGeneration~=generation or last~=page
        or page.native or page.nativeAttempts>=Recap.LIMITS.attempts or ReservePublicRetry(page)then return end
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
                association="Explicit personal death ID delta from authoritative Current in a witnessed clean meter epoch; native synchronization testing pending",
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
    if page.nativeAttempts<Recap.LIMITS.attempts and not(Combat()and page.nativeAttempts>=2)then
        ScheduleNative(page,token,page.nativeAttempts==1 and .5 or 1)
    end
end
local function OnDeath()
    if not Enabled()or(session and session.dead)then return end
    StopRecording();CancelFetch()
    local time=Now();if not session or not time then Notify("unavailable");return end
    serial=serial+1
    local page={id=serial,captureGeneration=generation,diedAt=time,playerGUID=session.playerGUID,specID=session.specID,class=session.class,
        coverage=session.coverage,overflow=session.overflow,unknownKnown=session.unknownKnown,
        encounter=Copy(session.encounter),encounterEndObservation=Copy(session.encounterEndObservation),knownEntries=Copy(session.entries),localSessionStartedAt=session.startedAt,lastAlive=Copy(session.lastAlive),
        casts={},observedUses=Copy(session.observedUses),directSpellEvents=Copy(session.directSpellEvents),useCoverage={startedAt=session.startedAt,combatEntryObserved=session.combatEntryObserved,
            reason=session.coverage,endedAt=session.lastAlive and session.lastAlive.coverageEndedAt,rejectedReceipts=session.rejectedUseReceipts or 0,lateReceipts=session.lateUseReceipts or 0},deathObservation=Observe("death-notification",true),
        association=Association:Freeze(),nativeAttempts=0,nativeStatus="Waiting for a fresh personal native recap"}
    for _,cast in ipairs(session.casts)do if time-cast.observedAt<=Recap.LIMITS.seconds then page.casts[#page.casts+1]=Copy(cast)end end
    session.dead=true;last=page;Notify("death");FetchNative(page,generation)
end
function Recap:ClassifyRecordedCheck(row,coverageEnded,example)
    if row.family then return row.familyState,row.familyDetail end
    local suffix=example and" at this moment"or" when checked"
    if row.pendingAt then return nil,"A later change was awaiting a new check"end
    if coverageEnded then return nil,"Recording ended after this check"end
    if row.kind then
        if row.physicalCount==0 and row.remainingUses and row.remainingUses>0 then return nil,"The independent stock checks disagree"end
        if row.familyAbsenceVerified or row.physicalCount==0 then return false,(row.itemID and"No stock of this item"or"No item in the complete bag check")..suffix end
        if row.physicalCount and row.physicalCount>0 and row.remainingUses==0 then return false,"Empty"..suffix end
        local stock=row.physicalCount and row.physicalCount>0 or row.remainingUses and row.remainingUses>0
        if stock and row.cooldown=="inactive"then return true,"Off cooldown"..suffix end
        if stock and row.cooldown=="active"then return false,"Cooldown active"..suffix end
        return nil,row.cooldown=="inactive"and"Off cooldown when checked; stock was not confirmed"or"Item state was not fully recorded"
    end
    if row.cooldown=="held"then return false,"Cooldown on hold"..suffix end
    if not row.chargesPendingAt and row.currentCharges and row.currentCharges>0 then return true,row.currentCharges..(row.currentCharges==1 and" charge"or" charges")..suffix end
    if not row.chargesPendingAt and row.currentCharges==0 then return false,"No charges"..suffix end
    if row.chargeQuery=="public"and(row.maxCharges or row.chargesActive~=nil)then
        return nil,row.cooldown=="inactive"and"Normal cooldown was inactive; remaining charges were not established"or"Remaining charges were not established"
    end
    if row.cooldown=="inactive"then
        if example or row.chargeQuery=="not_applicable"then return true,"Off cooldown"..suffix end
        return nil,"Normal cooldown was inactive; charge state was not established"
    end
    if row.cooldown=="active"and row.chargeQuery=="not_applicable"then return false,"Cooldown active"..suffix end
    if row.cooldown=="gcd-observed"then return nil,"A global cooldown was observed; other cooldown state was not established"end
    if row.cooldown=="active-context-unknown"then return nil,"An active cooldown was observed outside its update event; global and spell cooldowns could not be separated"end
    if row.chargeReason=="restricted"or row.chargeCountStatus=="restricted"then return nil,"Charge count was not provided by Blizzard"end
    if row.cooldownQuery=="restricted"or row.cooldownEnabledStatus=="restricted"or row.cooldownActiveStatus=="restricted"then return nil,"Cooldown state was not provided by Blizzard"end
    return nil,row.cooldown=="active"and"Cooldown active when checked; charge count was not recorded"or row.cooldownQuery and"State check unavailable"or"Not recorded"
end
-- Pure view of the frozen item candidates. A representative supplies artwork,
-- never family-wide stock, cooldown, or remaining-use claims.
function Recap:GetRecordedCheckTime(row)
    if row.kind and row.familyAbsenceVerified then return row.carriedAt or row.observedAt end
    if not row.kind and row.cooldown~="held"and not row.pendingAt and not row.chargesPendingAt and row.currentCharges~=nil then return row.chargesAt or row.observedAt end
    return row.cooldownAt or row.observedAt
end
function Recap:GetSupplyFamilies(page)
    local result={};local sample=page.lastAlive
    for _,kind in ipairs({"stone","potion"})do
        local family={kind=kind,category=kind,family=true,name=kind=="stone"and"Healthstone"or"Healing potion",members={}}
        local positive,unknown,negative,incomplete,verifiedAbsent
        for _,row in ipairs(sample and sample.supplies or{})do if row.kind==kind then
            local state,detail=self:ClassifyRecordedCheck(row,sample.coverageEndedAt)
            family.members[#family.members+1]={row=row,state=state,detail=detail}
            if state==true then positive=positive or row elseif state==nil then unknown=unknown or row else negative=negative or row end
            if row.partial then incomplete=true end
            if row.familyAbsenceVerified and state==false then verifiedAbsent=true end
            local checked=self:GetRecordedCheckTime(row)
            if checked then family.observedAt=math.min(family.observedAt or checked,checked);family.latestObservedAt=math.max(family.latestObservedAt or checked,checked)end
        end end
        local representative=positive or unknown or negative
        family.icon=representative and representative.icon
        family.representativeItemID=representative and representative.itemID
        if positive then family.familyState=true;family.familyDetail="At least one recorded item was off cooldown when checked"
        elseif unknown or #family.members==0 or incomplete and not verifiedAbsent then family.familyDetail="Item family state was not fully recorded"
        else family.familyState=false;family.familyDetail="Recorded candidates were empty, absent, or on cooldown when checked"end
        result[#result+1]=family
    end
    return result
end
function Recap:GetPage()return last end
-- Explicit diagnostic action only: one sanitized read of the accepted frozen
-- ID. No association, lifecycle timer, or replacement of the captured packet.
function Recap:ReadNativePacketForDebug()
    local page=last;local native=page and Table(page.native)
    local id=native and ID(native.recapID)
    if not id then return nil,"No accepted personal native recap ID recorded this session"end
    local packet,reason=NativePacket(id)
    if last~=page or page.native~=native or ID(native.recapID)~=id then return nil,"Recorded page changed during diagnostic read"end
    if not packet then return nil,reason end
    for _,row in ipairs(packet.rows)do
        if row.destGUID and page.playerGUID and row.destGUID~=page.playerGUID then return nil,"foreign_native_destination"end
    end
    local maximum=0
    for _,row in ipairs(packet.rows)do maximum=math.max(maximum,row.timestamp)end
    for _,row in ipairs(packet.rows)do row.nativeOffset=row.timestamp-maximum end
    packet.recapID=id
    return packet
end
-- Explicit local audit of captured public facts. No spell/item getters, polling
-- or clock conversion; client metadata uses the existing one-time build read.
function Recap:GetAvailabilityAudit()
    if not last then return nil,"No personal death recorded this session"end
    local audit={localDeathID=last.id,nativeRecapID=last.native and last.native.recapID,deathNoticeAt=last.diedAt,specID=last.specID,class=last.class,
        directSpellEvents=Copy(last.directSpellEvents),client=Copy(self:GetDiagnostics().client),catalogRevision=(RA.DeathRecapCatalog or{}).revision,encounter=Copy(last.encounter),coverage=Copy(last.useCoverage),spells={}}
    audit.encounterEndObservation=Copy(last.encounterEndObservation)
    local fields={"observedAt","cooldownAt","chargesAt","source","cooldown","cooldownQuery","isEnabled","isActive","isOnGCD","cooldownEnabledStatus","cooldownActiveStatus",
        "cooldownGCDStatus","chargeQuery","chargeReason","chargeCountStatus","chargeActiveStatus","maxChargesStatus","currentCharges","maxCharges","chargesActive","pendingAt","pendingReason","chargesPendingAt","directCooldown","genericCooldown"}
    local function Check(sample,id)
        for _,row in ipairs(sample and sample.spells or{})do if row.spellID==id then
            local out={};for _,key in ipairs(fields)do out[key]=Copy(row[key])end
            out.coverageEndedAt=sample.coverageEndedAt
            if row.observedAt and last.diedAt>=row.observedAt then out.ageBeforeDeathNotice=last.diedAt-row.observedAt end
            return out
        end end
    end
    for i=1,math.min(#(last.knownEntries or{}),self.LIMITS.spells)do
        local entry=last.knownEntries[i];local use=last.observedUses and last.observedUses[entry.spellID]
        local alive,death=Check(last.lastAlive,entry.spellID),Check(last.deathObservation,entry.spellID)
        local displayed,detail=self:ClassifyRecordedCheck(alive or{},last.lastAlive and last.lastAlive.coverageEndedAt,false)
        audit.spells[#audit.spells+1]={spellID=entry.spellID,name=entry.name,key=entry.key,lastAlive=alive,deathNotice=death,
            displayed={state=displayed,detail=detail,source="lastAlive",observedAt=self:GetRecordedCheckTime(alive or{})},
            use=use and Copy(use)or{observedCount=0,status="No successful use observed in this coverage"}}
    end
    return audit
end
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
    return {enabled=Enabled(),autoOpen=Settings().autoOpen==true,hasPage=last~=nil,
        recording=ticker~=nil,coverage=session and session.coverage or "No alive observations"}
end
function Recap:Refresh()
    Notify("reset")
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
    if key=="autoOpen"then db.deathRecap.manualEntryVersion=1 end
    if key=="enabled"then self:Refresh()else Notify("settings")end
    return true
end
function Recap:EnableReminder()
    return RA.PersonalTools:SetOption("consumableReminder",true)
end
local function Passive(event,callback)passive[#passive+1]=RA:RegisterOptionalEvent(event,callback)end
local function Active(event,callback,unit)active[#active+1]=RA:RegisterOptionalEvent(event,callback,unit)end
Passive("PLAYER_DEAD",OnDeath)
Passive("PLAYER_REGEN_DISABLED",function()BeginCombat("Observed combat entry; bounded 30-second history",true)end)
Passive("PLAYER_REGEN_ENABLED",function()
    if session and session.lastAlive then session.lastAlive.coverageEndedAt=Now();session.lastAlive.coverageEndReason="combat-ended"end
    if session then for _,row in ipairs(session.lastAlive and session.lastAlive.spells or{})do if row.directCooldown then row.directCooldown.valid=false;row.directCooldown.invalidatedBy="coverage-ended"end end end
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
    local relevant=Association:Update(kind,id,Alive())
    if relevant and last and not last.native and last.captureGeneration==generation and last.nativeAttempts<Recap.LIMITS.attempts then
        ScheduleNative(last,generation,.1)
    end
end)
for _,event in ipairs({"PLAYER_ALIVE","PLAYER_UNGHOST","PLAYER_ENTERING_WORLD"})do
    Passive(event,function()
        StopRecording();if event=="PLAYER_ENTERING_WORLD"then CancelFetch();encounterContext=nil end
        if Alive()then
            if Combat()then BeginCombat("Resurrected/entered during combat; incomplete coverage")
            else NewSession("Alive baseline; no combat observations yet")end
        end;Notify("life")
    end)
end
for _,event in ipairs({"PLAYER_SPECIALIZATION_CHANGED","TRAIT_CONFIG_UPDATED","SPELLS_CHANGED"})do
    Passive(event,function(_,unit)
        if event=="PLAYER_SPECIALIZATION_CHANGED"and String(unit,16)and String(unit,16)~="player"then return end
        if session and not session.dead then
            local entries,spec,class,overflow,unknown=BuildEntries()
            local same=spec==session.specID and class==session.class and #entries==#session.entries
            for i,entry in ipairs(entries)do local old=session.entries[i]
                if not old or entry.spellID~=old.spellID or entry.baseSpellID~=old.baseSpellID or entry.key~=old.key then same=false end
            end
            if same then session.overflow=overflow;session.unknownKnown=unknown;return end
        end
        if Combat()then BeginCombat("Spell/spec identity changed; earlier coverage discarded")else NewSession("Spell/spec identity refreshed")end
    end)
end
Passive("ENCOUNTER_START",function(_,id,name,difficulty)
    encounterSerial=encounterSerial+1;encounterContext={auditEpoch=encounterSerial,encounterID=ID(id),name=String(name,96),difficulty=ID(difficulty),startedAt=Now()}
    if session then session.encounter=Copy(encounterContext)end
end)
Passive("ENCOUNTER_END",function(_,id)
    local ended={encounterID=ID(id),observedAt=Now(),auditEpoch=encounterContext and encounterContext.auditEpoch}
    if ended.auditEpoch and session and session.encounter and session.encounter.auditEpoch==ended.auditEpoch then session.encounterEndObservation=Copy(ended)end
    if ended.auditEpoch and last and last.encounter and last.encounter.auditEpoch==ended.auditEpoch and last.encounter.encounterID==ended.encounterID and not last.encounterEndObservation then
        last.encounterEndObservation=Copy(ended)
    end
    encounterContext=nil;if session then session.encounter=nil end
end)
Active("UNIT_SPELLCAST_SUCCEEDED",function(_,unit,_,spellID)
    local ownUnit=String(unit,16)
    if ownUnit~="player"then if ownUnit==nil and session then session.rejectedUseReceipts=(session.rejectedUseReceipts or 0)+1 end;return end
    if not session then return end
    if not Alive()then session.lateUseReceipts=(session.lateUseReceipts or 0)+1;return end
    local time=Now();spellID=ID(spellID)
    if not time or not spellID then session.rejectedUseReceipts=(session.rejectedUseReceipts or 0)+1;return end
    local tracked,trackedName,trackedItemUse=false,nil,false
    for _,entry in ipairs(session.entries)do if entry.spellID==spellID then tracked=true;trackedName=entry.name;break end end
    if (RA.DeathRecapCatalog or {}).itemUseSpells and RA.DeathRecapCatalog.itemUseSpells[spellID]then tracked=true;trackedItemUse=true end
    if not tracked then return end
    if not trackedItemUse then
        local use=session.observedUses[spellID]
        if not use then use={spellID=spellID,observedCount=0,source="UNIT_SPELLCAST_SUCCEEDED",firstSuccessfulUseAt=time};session.observedUses[spellID]=use end
        use.observedCount=use.observedCount+1;use.lastSuccessfulUseAt=time
    end
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
            ScheduleObservation()
        else session.itemEventAt=time;Observe("item-event",false)end
    end)
end
Active("SPELL_UPDATE_COOLDOWN",function(event,...)
    local time=Now();if not session or not session.lastAlive or not time or not Alive()then return end
    session.cooldownSequence=(session.cooldownSequence or 0)+1
    local context={event=event,observedAt=time,eventSequence=session.cooldownSequence,payload={}}
    for i=1,5 do
        local raw=select(i,...);local value,status=Public(raw),FieldStatus(raw,"number")
        local field={status=status};context.payload[i]=field
        if status=="not-recorded"then field.status="public-nil"
        elseif type(value)=="number"and value==value and value~=math.huge and value~=-math.huge then
            if i==3 or i==4 then field.value=value;field.status="public-number"
            else field.value=ID(value);field.status=field.value and"public-number"or"malformed"end
        end
    end
    session.directSpellEvents[event]=context
    local spell,base=context.payload[1],context.payload[2]
    local ambiguous=spell.status~="public-nil"and(spell.status~="public-number"or(base.status~="public-number"and base.status~="public-nil"))
    if ambiguous then Pending("spells",time,"ambiguous-cooldown-identity");ScheduleObservation();return end
    local count=0
    for index,entry in ipairs(session.entries)do
        if spell.status=="public-nil"or spell.value==entry.spellID or spell.value==entry.baseSpellID
            or(base.value and(base.value==entry.spellID or base.value==entry.baseSpellID))then
            local previous=session.lastAlive.spells[index]
            local row=Copy(previous);local direct=SpellObservation(entry,time,"cooldown-event",true)
            direct.baseSpellID=entry.baseSpellID;direct.eventSequence=context.eventSequence;direct.context=Copy(context);direct.valid=true
            direct.invalidationGeneration=context.eventSequence
            for _,key in ipairs(cooldownFields)do row[key]=direct[key]end
            row.observedAt=time;row.source="cooldown-event";row.pendingAt=nil;row.pendingReason=nil
            row.chargesPendingAt=row.chargesPendingAt or time;row.directCooldown=direct;row.genericCooldown=nil
            session.lastAlive.spells[index]=row;count=count+1
        end
    end
    if count>0 then ScheduleObservation();RefreshTicker()end
end)
Active("SPELL_UPDATE_CHARGES",function(event)
    local time=Now();if not session or not time or not Alive()then return end
    session.directSpellEvents[event]={event=event,observedAt=time,payload={}}
    Pending("spells",time,"charge-event")
    if session.eventAt[event]and time-session.eventAt[event]<.1 then
        stats.coalescedEvents=(stats.coalescedEvents or 0)+1;ScheduleObservation()
    else session.eventAt[event]=time;Observe("charge-event",false)end
end)
RA:RegisterCallback("HEALING_SUPPLIES_ITEM_DATA_READY",function()
    if Enabled()and Alive()and Combat()and session then Pending("items",Now(),"item-data-ready");Observe("item-data-event",false)end
end)
RA:RegisterInitializer(function()Recap:Refresh()end)
RA:RegisterCallback("PROFILE_RESET",function()Recap:Refresh()end)
