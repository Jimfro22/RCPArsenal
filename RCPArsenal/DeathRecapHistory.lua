local _,RA=...
local H={LIMIT=5};RA.DeathRecapHistory=H
local function Public(v)
    if type(issecretvalue)~='function'then return nil end
    local ok,secret=pcall(issecretvalue,v);if ok and secret==false then return v end
end
local function Plain(v)v=Public(v);if type(v)=='table'and getmetatable(v)==nil then return v end end
local function Scalar(v)
    v=Public(v)
    if type(v)=='boolean'then return v end
    if type(v)=='number'and v==v and math.abs(v)<=1e15 then return v end
    if type(v)=='string'and #v<=256 and not v:find('[%c|]')then return v end
end
local function Set(keys)local out={};for key in keys:gmatch('%S+')do out[key]=true end;return out end
local NUMERIC=Set('id diedAt recordedAt specID localSessionStartedAt nativeAttempts spellID baseSpellID defensiveTalentSpellID observedAt cooldownAt chargesAt currentCharges maxCharges pendingAt chargesPendingAt eventSequence invalidationGeneration invalidatedAt ownCooldownAt itemID icon carriedAt cacheGeneration physicalCount countAt remainingUses usesAt frozenAtCombatEntry auditEpoch encounterID difficulty startedAt endedAt coverageEndedAt rejectedReceipts lateReceipts firstSuccessfulUseAt lastSuccessfulUseAt observedCount recapID recapMaxHealth timestamp rawSpellID amount nativeIndex nativeOffset recordedHP absorbed overkill resisted blocked school nativeReadLocalBefore nativeReadLocalAfter nativeFirstTimestamp nativeMinimumTimestamp nativeMaximumTimestamp nativeFatalTimestamp nativeRowCount value')
local BOOLEAN=Set('known isEnabled isActive isOnGCD chargesActive valid ownCooldownActive ownCooldownZero carried partial familyAbsenceVerified enableCooldownTimer combatEntryObserved truncated hideCaster sourceConfirmed avoidable deadly')
local IDS=Set('spellID baseSpellID defensiveTalentSpellID itemID encounterID specID recapID rawSpellID school nativeIndex')
local function Fields(input,keys)
    input=Plain(input);if not input then return nil end
    local out={}
    for key in keys:gmatch('%S+')do
        local value=Scalar(input[key]);local kind=type(value)
        local accepted=NUMERIC[key]and kind=='number'or BOOLEAN[key]and kind=='boolean'or not NUMERIC[key]and not BOOLEAN[key]and kind=='string'
        if key=='icon'and kind=='string'then accepted=true end
        if IDS[key]and(kind~='number'or value<1 or value>2147483647 or value~=math.floor(value))then accepted=false end
        if accepted then out[key]=value end
    end
    return out
end
local CHECK='spellID baseSpellID key name category role defensiveTalentSpellID known observedAt cooldownAt chargesAt source cooldown cooldownQuery isEnabled isActive isOnGCD cooldownEnabledStatus cooldownActiveStatus cooldownGCDStatus chargeQuery chargeReason chargeCountStatus chargeActiveStatus maxChargesStatus currentCharges maxCharges chargesActive pendingAt pendingReason chargesPendingAt valid eventSequence invalidationGeneration invalidatedAt invalidatedBy ownCooldownQuery ownCooldownAt ownCooldownSource ownCooldownActive ownCooldownZero ownCooldownActiveStatus ownCooldownZeroStatus ownCooldownState'
local ITEM='kind category source observedAt cooldown itemID icon carried carriedAt cacheGeneration partial familyAbsenceVerified physicalCount countStatus countAt remainingUses usesStatus usesAt cooldownQuery cooldownStartStatus cooldownDurationStatus enableCooldownTimer cooldownAt pendingAt pendingReason'
local CAST='spellID name role defensiveTalentSpellID observedAt source'
local CLOCK='localClock localSessionStartedAt localDeathNoticeAt nativeReadLocalBefore nativeReadLocalAfter nativeFirstTimestamp nativeMinimumTimestamp nativeMaximumTimestamp nativeFatalTimestamp nativeRowCount nativeTimestampStatus'
local function Array(input,limit,fn)
    input=Plain(input);local out={};if not input then return out end
    for i=1,math.min(#input,limit)do local row=fn(input[i]);if row then out[#out+1]=row end end;return out
end
local function Context(input)
    local out=Fields(input,'event observedAt eventSequence');if not out then return nil end
    out.payload=Array(input.payload,5,function(v)return Fields(v,'value status')end);return out
end
local function Check(input)
    local out=Fields(input,CHECK);if not out then return nil end
    local direct=Plain(input.directCooldown)
    out.directCooldown=Fields(direct,CHECK)
    if out.directCooldown then out.directCooldown.context=Context(direct.context)end
    out.genericCooldown=Fields(input.genericCooldown,CHECK);return out
end
local function Sample(input)
    local out=Fields(input,'observedAt source coverageEndedAt coverageEndReason playerGUID playerName playerRealm specID class frozenAtCombatEntry');if not out then return nil end
    out.spells=Array(input.spells,32,Check);out.supplies=Array(input.supplies,32,function(v)return Fields(v,ITEM)end)
    out.entries=Array(input.entries,32,function(v)return Fields(v,CHECK)end);return out
end
function H:Snapshot(input)
    input=Plain(input);if not input then return nil end
    local out=Fields(input,'id diedAt recordedAt playerGUID playerName playerRealm class specID localSessionStartedAt nativeAttempts nativeStatus nativeReason')
    if type(out.id)~='number'or out.id<1 or out.id>1e12 or out.id~=math.floor(out.id)or type(out.diedAt)~='number'or out.diedAt<0 then return nil end
    out.knownEntries=Array(input.knownEntries,32,function(v)return Fields(v,CHECK)end)
    out.lastAlive=Sample(input.lastAlive);out.deathObservation=Sample(input.deathObservation);out.precombatBaseline=Sample(input.precombatBaseline)
    out.encounter=Fields(input.encounter,'auditEpoch encounterID name difficulty startedAt')
    out.encounterEndObservation=Fields(input.encounterEndObservation,'encounterID observedAt auditEpoch')
    out.useCoverage=Fields(input.useCoverage,'startedAt combatEntryObserved reason endedAt rejectedReceipts lateReceipts')
    out.casts=Array(input.casts,64,function(v)return Fields(v,CAST)end)
    out.directSpellEvents={};local events=Plain(input.directSpellEvents)
    if events then for _,name in ipairs({'SPELL_UPDATE_COOLDOWN','SPELL_UPDATE_CHARGES'})do out.directSpellEvents[name]=Context(events[name])end end
    out.observedUses={};local uses=Plain(input.observedUses)
    if uses then for _,entry in ipairs(out.knownEntries)do local id=entry.spellID
        if type(id)=='number'and id>0 and id<=2147483647 and id==math.floor(id)then
            out.observedUses[id]=Fields(uses[id],'spellID role defensiveTalentSpellID observedCount firstSuccessfulUseAt lastSuccessfulUseAt source')
        end
    end end
    if uses then local count=0
        for id in pairs((RA.DeathRecapCatalog or{}).itemUseSpells or{})do
            id=Scalar(id)
            if type(id)=='number'and id>0 and id<=2147483647 and id==math.floor(id)and count<32 then
                count=count+1
                out.observedUses[id]=Fields(uses[id],'spellID role observedCount firstSuccessfulUseAt lastSuccessfulUseAt source')
            end
        end
    end
    local native=Plain(input.native)
    if native then
        out.native=Fields(native,'recapID recapMaxHealth recapMaxHealthStatus truncated association clock')
        out.native.clockDiagnostic=Fields(native.clockDiagnostic,CLOCK)
        out.native.rows=Array(native.rows,64,function(v)
            local row=Fields(v,'timestamp destGUID spellID kind name rawSpellID rawSpellName event amount nativeIndex nativeOffset recordedHP sourceName hideCaster sourceConfirmed sourceKey hideCasterStatus absorbed overkill resisted blocked school avoidable deadly')
            if row then row.fieldStatus=Fields(v.fieldStatus,'hp source absorbed overkill')end
            return row
        end)
    end
    return out
end
local function Root()return Plain(RaidArsenalDB)end
function H:Save(pages,sequence)
    local stored={version=1,sequence=sequence,pages={}}
    for i=1,math.min(#pages,self.LIMIT)do local page=self:Snapshot(pages[i]);if page then stored.pages[#stored.pages+1]=page end end
    local root=Root();if root then root.deathRecapHistory=stored end
    return stored
end
function H:Load()
    local root=Root();local stored=root and Plain(root.deathRecapHistory);local pages,sequence,seen={},0,{}
    if stored and Public(stored.version)==1 then
        local serial=Scalar(stored.sequence)
        if type(serial)=='number'and serial>=0 and serial<=1e12 and serial==math.floor(serial)then sequence=serial end
        local source=Plain(stored.pages)or{}
        for i=1,math.min(#source,self.LIMIT)do local page=self:Snapshot(source[i])
            if page and not seen[page.id]then
                seen[page.id]=true;page.restored=true;pages[#pages+1]=page;sequence=math.max(sequence,page.id)
            end
        end
    end
    self:Save(pages,sequence);return pages,sequence
end
