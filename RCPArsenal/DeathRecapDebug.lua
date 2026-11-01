local _,RA=...
local R=RA.DeathRecap
local D={LIMITS={rows=64,spells=32,text=60000}};RA.DeathRecapDebug=D

-- Diagnostics deliberately use a field allowlist. Never recursively serialize
-- native results, traverse unknown tables, or stringify opaque values.
local function Public(value)
    if type(issecretvalue)~="function"then return nil,"trust-check-unavailable"end
    local ok,secret=pcall(issecretvalue,value)
    if not ok or(secret~=false and secret~=true)then return nil,"trust-check-failed"end
    if secret then return nil,"restricted"end
    return value
end
local function Table(value)
    local public,status=Public(value)
    if status then return nil,status end
    if public==nil then return nil,"not-recorded"end
    if type(public)~="table"or getmetatable(public)~=nil then return nil,"malformed"end
    return public
end
local function Scalar(value)
    local public,status=Public(value)
    if status then return nil,status end
    if public==nil then return nil,"not-recorded"end
    if type(public)=="number"then
        if public~=public or public==math.huge or public==-math.huge then return nil,"malformed"end
        return public
    end
    if type(public)=="boolean"then return public end
    if type(public)=="string"and #public<=256 and not public:find("[%c|]")then return public end
    return nil,"malformed"
end
local function ID(value)
    local value=Scalar(value)
    if type(value)=="number"and value>0 and value<=2147483647 and value==math.floor(value)then return value end
end
local function Encode(value,status)
    if status then return "<"..status..">"end
    if type(value)=="number"then return string.format("%.17g",value)end
    if type(value)=="boolean"then return value and"true"or"false"end
    if type(value)=="string"then return string.format("%q",value)end
    return "<not-recorded>"
end
local function Fields(source,keys)
    local source,parentStatus=Table(source)
    local out={unavailable={}}
    for _,key in ipairs(keys)do
        if source then out[key],out.unavailable[key]=Scalar(source[key])
        else out.unavailable[key]=parentStatus end
    end
    return out
end
local function Field(row,key)return Encode(row[key],row.unavailable[key])end
local function FieldText(row,keys,compact)
    local out={}
    for _,key in ipairs(keys)do if not compact or row.unavailable[key]~="not-recorded"then out[#out+1]=key.."="..Field(row,key)end end
    return #out>0 and table.concat(out," ")or"<not-recorded>"
end
local HEADER={"id","specID","class","diedAt","localSessionStartedAt","nativeReason","nativeStatus"}
local NATIVE={"nativeIndex","event","timestamp","nativeOffset","rawSpellID","spellID","amount","recordedHP","absorbed","overkill","resisted","blocked","hideCaster","avoidable","deadly"}
local STATUS={"hp","source","absorbed","overkill"}
local CLOCK={"localClock","localSessionStartedAt","localDeathNoticeAt","nativeReadLocalBefore","nativeReadLocalAfter","nativeFirstTimestamp","nativeMinimumTimestamp","nativeMaximumTimestamp","nativeFatalTimestamp","nativeRowCount","nativeTimestampStatus"}
local CHECK={"spellID","baseSpellID","observedAt","cooldownAt","chargesAt","source","cooldown","cooldownQuery","isEnabled","isActive","isOnGCD","cooldownEnabledStatus","cooldownActiveStatus","cooldownGCDStatus","chargeQuery","chargeReason","chargeCountStatus","chargeActiveStatus","maxChargesStatus","currentCharges","maxCharges","chargesActive","pendingAt","pendingReason","chargesPendingAt","valid","eventSequence","invalidationGeneration","invalidatedAt","invalidatedBy"}
local EVENT={"event","observedAt","eventSequence"}
local SAMPLE={"observedAt","source","coverageEndedAt","coverageEndReason"}
local USE={"spellID","observedCount","firstSuccessfulUseAt","lastSuccessfulUseAt","source"}
local COVERAGE={"startedAt","combatEntryObserved","reason","endedAt","rejectedReceipts","lateReceipts"}

local function Context(input)
    local source=Table(input);if not source then return nil end
    local event=Fields(source,EVENT);event.payload={}
    local payload=Table(source.payload)
    for i=1,5 do event.payload[i]=Fields(payload and payload[i],{"value","status"})end
    return event
end

local function Packet(native)
    local input,parentStatus=Table(native)
    local out={metadata=Fields(native,{"recapID","recapMaxHealth","recapMaxHealthStatus","truncated"}),rows={},status=parentStatus}
    if not input then return out end
    local rows,rowStatus=Table(input.rows);out.rowsStatus=rowStatus
    if rows then
        out.inputCount=#rows;out.truncated=#rows>D.LIMITS.rows or Scalar(input.truncated)==true
        for i=1,math.min(#rows,D.LIMITS.rows)do
            local source=Table(rows[i]);local row=Fields(rows[i],NATIVE)
            row.fieldStatus=Fields(source and source.fieldStatus,STATUS);out.rows[i]=row
        end
    end
    out.clock=Fields(input.clockDiagnostic,CLOCK)
    out.read=Fields(input,{"readBefore","readAfter"})
    return out
end
local function Sample(input)
    local sample=Table(input);local out={metadata=Fields(input,SAMPLE),spells={}}
    local spells=sample and Table(sample.spells)
    if spells then for i=1,math.min(#spells,D.LIMITS.spells)do
        local source=Table(spells[i]);local row=Fields(spells[i],CHECK)
        row.directCooldown=Fields(source and source.directCooldown,CHECK)
        row.genericCooldown=Fields(source and source.genericCooldown,CHECK)
        local _,directStatus=Table(source and source.directCooldown)
        local _,genericStatus=Table(source and source.genericCooldown)
        row.hasDirect=directStatus~="not-recorded";row.hasGeneric=genericStatus~="not-recorded"
        local direct=source and Table(source.directCooldown)
        row.directContext=Context(direct and direct.context)
        out.spells[i]=row
    end end
    return out
end
local function Accepted()
    local page=Table(R:GetPage());local native=page and Table(page.native)
    local id=native and ID(native.recapID)
    if not id then return nil,nil,nil,"No accepted personal native recap ID recorded this session"end
    return page,native,id
end
function R:OpenBlizzardRecap()
    local page,native,id,reason=Accepted()
    if not page then return false,reason end
    if type(OpenDeathRecapUI)~="function"then return false,"Blizzard recap opener unavailable"end
    local ok=pcall(OpenDeathRecapUI,id)
    if not ok then return false,"Blizzard recap request failed"end
    -- The native function has no success return and toggles an already-open ID.
    return true,"Requested Blizzard recap ID "..string.format("%.0f",id)
end
function D:GetFrozenSnapshot()
    local page=Table(R:GetPage())
    if not page then return nil,"No personal death recorded this session"end
    local snapshot={header=Fields(page,HEADER),native=Packet(page.native),lastAlive=Sample(page.lastAlive),deathNotice=Sample(page.deathObservation),
        coverage=Fields(page.useCoverage,COVERAGE),directEvents={},uses={}}
    local contexts=Table(page.directSpellEvents)
    for _,name in ipairs({"SPELL_UPDATE_COOLDOWN","SPELL_UPDATE_CHARGES"})do
        snapshot.directEvents[name]=Context(contexts and contexts[name])
    end
    local known=Table(page.knownEntries);local uses=Table(page.observedUses)
    if known then for i=1,math.min(#known,D.LIMITS.spells)do
        local entry=Table(known[i]);local id=entry and ID(entry.spellID)
        if id then
            local row=Fields(uses and uses[id],USE);row.spellID=id;row.unavailable.spellID=nil
            snapshot.uses[#snapshot.uses+1]=row
        end
    end end
    return snapshot,nil,page
end
local function Writer()
    local lines,bytes,full={},0,false
    local marker="[Diagnostic text truncated at bounded output limit.]"
    local function Add(line)
        if full then return end
        if bytes+#line+1>D.LIMITS.text-#marker-1 then lines[#lines+1]=marker;full=true;return end
        lines[#lines+1]=line;bytes=bytes+#line+1
    end
    return Add,function()return table.concat(lines,"\n")end
end
local function WritePacket(Add,label,packet)
    Add(label.." "..FieldText(packet.metadata,{"recapID","recapMaxHealth","recapMaxHealthStatus","truncated"}))
    Add("  retainedRows="..#packet.rows.." rowContainer="..(packet.rowsStatus or packet.status or"public").." exportTruncated="..tostring(packet.truncated==true))
    if packet.clock then Add("  frozenClock "..FieldText(packet.clock,CLOCK))end
    if packet.read then Add("  readBrackets "..FieldText(packet.read,{"readBefore","readAfter"}))end
    for i,row in ipairs(packet.rows)do
        Add("  arraySlot="..i.." "..FieldText(row,NATIVE))
        Add("    capturedFieldStatus "..FieldText(row.fieldStatus,STATUS))
    end
end
local function WriteContext(Add,label,event)
    Add(label.." "..FieldText(event,EVENT,true))
    for i,field in ipairs(event.payload)do Add("      arg"..i.." "..FieldText(field,{"value","status"},true))end
end
local function WriteSample(Add,label,sample)
    Add(label.." "..FieldText(sample.metadata,SAMPLE))
    for i,row in ipairs(sample.spells)do
        Add("  check="..i.." "..FieldText(row,CHECK,true))
        if row.hasDirect then Add("    directCooldown "..FieldText(row.directCooldown,CHECK,true))end
        if row.directContext then WriteContext(Add,"    directCooldown.context",row.directContext)end
        if row.hasGeneric then Add("    genericCooldown "..FieldText(row.genericCooldown,CHECK,true))end
    end
end
local function WriteDiff(Add,before,after)
    Add("INDEX-WISE DIFF: original array slots; no stable cross-read event identity inferred")
    local changed=0
    for _,key in ipairs({"recapMaxHealth","recapMaxHealthStatus","truncated"})do
        local old,new=Field(before.metadata,key),Field(after.metadata,key)
        if old~=new then changed=changed+1;Add("  packet."..key.." frozen="..old.." reread="..new)end
    end
    if #before.rows~=#after.rows then changed=changed+1;Add("  retainedRows frozen="..#before.rows.." reread="..#after.rows)end
    for i=1,math.max(#before.rows,#after.rows)do
        local a,b=before.rows[i],after.rows[i]
        if not a or not b then changed=changed+1;Add("  arraySlot="..i..(a and" removed"or" added"))
        else
            for _,key in ipairs(NATIVE)do
                local old,new=Field(a,key),Field(b,key)
                if old~=new then changed=changed+1;Add("  arraySlot="..i.." "..key.." frozen="..old.." reread="..new)end
            end
            for _,key in ipairs(STATUS)do
                local old,new=Field(a.fieldStatus,key),Field(b.fieldStatus,key)
                if old~=new then changed=changed+1;Add("  arraySlot="..i.." fieldStatus."..key.." frozen="..old.." reread="..new)end
            end
        end
    end
    Add("  changedFieldsOrSlots="..changed.."; comparison covers retained rows only")
end
function R:BuildDebugText(reread)
    local snapshot,reason,page=D:GetFrozenSnapshot()
    if not snapshot then return nil,reason end
    local comparison,readReason
    if reread==true then
        local current,_,id,why=Accepted()
        if current~=page then return nil,why or"Recorded page changed"end
        if type(self.ReadNativePacketForDebug)~="function"then return nil,"Diagnostic native reader unavailable"end
        local packet
        packet,readReason=self:ReadNativePacketForDebug()
        local latest,_,latestID=Accepted()
        if latest~=page or latestID~=id then return nil,"Recorded page changed during diagnostic read"end
        if packet then comparison=Packet(packet)end
    end
    local Add,Finish=Writer()
    Add("RCP DEATH LOG DEBUG v1 - captured public fields only")
    Add("Raw original native index 1 is the fatal row. Maximum timestamp is separate; no native/GetTime clock bridge.")
    Add("Unavailable values are not zero/false. HP is event-associated; before/after-hit semantics are unspecified.")
    Add(FieldText(snapshot.header,HEADER));Add("coverage "..FieldText(snapshot.coverage,COVERAGE))
    WritePacket(Add,"FROZEN NATIVE",snapshot.native)
    if reread==true then
        if comparison then WritePacket(Add,"EXPLICIT SAME-ID REREAD",comparison);WriteDiff(Add,snapshot.native,comparison)
        else local value,status=Scalar(readReason);Add("EXPLICIT SAME-ID REREAD unavailable="..Encode(value,status))end
    end
    WriteSample(Add,"LAST ALIVE DEFENSIVE CHECKS",snapshot.lastAlive)
    WriteSample(Add,"DEATH NOTICE DEFENSIVE CHECKS",snapshot.deathNotice)
    for _,name in ipairs({"SPELL_UPDATE_COOLDOWN","SPELL_UPDATE_CHARGES"})do
        local event=snapshot.directEvents[name]
        if event then
            WriteContext(Add,"DIRECT EVENT "..name,event)
        end
    end
    for _,use in ipairs(snapshot.uses)do Add("OBSERVED USE "..FieldText(use,USE))end
    Add("END DEBUG - frozen capture unchanged; no chat submission")
    return Finish()
end
