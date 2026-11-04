local _,RA=...
local R=RA.DeathRecap
local D={LIMITS={rows=64,spells=32,casts=64,text=60000}};RA.DeathRecapDebug=D

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
local LOADED={"addonVersion","addonBuild","catalogBuild","catalogRevision"}
local NATIVE={"nativeIndex","event","timestamp","nativeOffset","rawSpellID","spellID","rawSpellName","name","school","amount","recordedHP","absorbed","overkill","resisted","blocked","hideCaster","hideCasterStatus","sourceConfirmed","avoidable","deadly"}
local SOURCE={"sourceName"}
local STATUS={"hp","source","absorbed","overkill"}
local CLOCK={"localClock","localSessionStartedAt","localDeathNoticeAt","nativeReadLocalBefore","nativeReadLocalAfter","nativeFirstTimestamp","nativeMinimumTimestamp","nativeMaximumTimestamp","nativeFatalTimestamp","nativeRowCount","nativeTimestampStatus"}
local CHECK={"spellID","baseSpellID","role","defensiveTalentSpellID","observedAt","cooldownAt","chargesAt","source","cooldown","cooldownQuery","isEnabled","isActive","isOnGCD","cooldownEnabledStatus","cooldownActiveStatus","cooldownGCDStatus","chargeQuery","chargeReason","chargeCountStatus","chargeActiveStatus","maxChargesStatus","currentCharges","maxCharges","chargesActive","pendingAt","pendingReason","chargesPendingAt","valid","eventSequence","invalidationGeneration","invalidatedAt","invalidatedBy","ownCooldownQuery","ownCooldownAt","ownCooldownSource","ownCooldownActive","ownCooldownZero","ownCooldownActiveStatus","ownCooldownZeroStatus","ownCooldownState","nativeCooldownActive","nativeCooldownStatus","nativeCooldownAt","nativeCooldownSource"}
local EVENT={"event","observedAt","eventSequence"}
local SAMPLE={"observedAt","source","coverageEndedAt","coverageEndReason","playerGUID","playerName","playerRealm","class","specID","frozenAtCombatEntry"}
local ITEM={"kind","itemID","observedAt","carried","carriedAt","familyAbsenceVerified","partial","inventorySource","physicalCount","remainingUses","countAt","usesAt","cooldown","cooldownAt","cooldownQuery","enableCooldownTimer","source","countStatus","usesStatus","pendingAt","pendingReason"}
local USE={"spellID","role","defensiveTalentSpellID","observedCount","firstSuccessfulUseAt","lastSuccessfulUseAt","source"}
local CAST={"capturedIndex","spellID","name","role","defensiveTalentSpellID","source","observedAt","localDeathRelativeAge"}
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
            -- A public name does not override Blizzard's hide-caster flag.
            -- Never even copy source text unless that flag is public false.
            row.incomingDamageSource=Fields(row.hideCaster==false and source or nil,SOURCE)
            if row.hideCaster~=false then row.incomingDamageSource.unavailable.sourceName="redacted-hideCaster"end
            row.fieldStatus=Fields(source and source.fieldStatus,STATUS);out.rows[i]=row
        end
    end
    out.clock=Fields(input.clockDiagnostic,CLOCK)
    out.read=Fields(input,{"readBefore","readAfter"})
    return out
end
local function Casts(input,deathAt)
    local casts,status=Table(input)
    local out={rows={},status=status,inputCount=casts and #casts or nil,truncated=casts and #casts>D.LIMITS.casts or false}
    if not casts then return out end
    local diedAt,deathStatus=Scalar(deathAt)
    for i=1,math.min(#casts,D.LIMITS.casts)do
        local row=Fields(casts[i],CAST)
        row.capturedIndex=i;row.unavailable.capturedIndex=nil
        -- Both operands belong to the local observation clock, never native time.
        row.localDeathRelativeAge=nil
        if type(diedAt)=="number"and type(row.observedAt)=="number"then
            row.localDeathRelativeAge,row.unavailable.localDeathRelativeAge=Scalar(diedAt-row.observedAt)
        else
            row.unavailable.localDeathRelativeAge=deathStatus or row.unavailable.observedAt or"malformed"
        end
        out.rows[i]=row
    end
    return out
end
local function Sample(input)
    local sample=Table(input);local out={metadata=Fields(input,SAMPLE),spells={},supplies={}}
    local supplies=sample and Table(sample.supplies)
    if supplies then for i=1,math.min(#supplies,34)do out.supplies[i]=Fields(supplies[i],ITEM)end end
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
    local page=Table(R:GetSelectedPage());local native=page and Table(page.native)
    local id=native and ID(native.recapID)
    if page and page.restored then return nil,nil,nil,"Saved death has no current-login native recap identity"end
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
    local page=Table(R:GetSelectedPage())
    if not page then return nil,"No personal death recorded this session"end
    local catalog=Table(RA.DeathRecapCatalog)
    local snapshot={header=Fields(page,HEADER),native=Packet(page.native),lastAlive=Sample(page.lastAlive),deathNotice=Sample(page.deathObservation),precombat=Sample(page.precombatBaseline),
        coverage=Fields(page.useCoverage,COVERAGE),directEvents={},uses={},casts=Casts(page.casts,page.diedAt),
        loaded=Fields({addonVersion=RA.VERSION,addonBuild=RA.BUILD,catalogBuild=catalog and catalog.build,catalogRevision=catalog and catalog.revision},LOADED)}
    local personal=Table(page.personalNativeProbe)
    if personal then snapshot.personalNative={packet=Packet(personal),metadata=Fields(personal,{"source","status","observedAt"})}end
    local late=Table(page.personalNativeProbeLate)
    if late then snapshot.personalNativeLate={packet=Packet(late),metadata=Fields(late,{"source","status","observedAt"})}end
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
    for _,use in ipairs(R:GetRecordedConsumableUses(page))do
        snapshot.uses[#snapshot.uses+1]=Fields(use,USE)
    end
    return snapshot,nil,page
end
local personalLateTimer,personalLatePage
local function CancelPersonalLate()
    if personalLateTimer then personalLateTimer:Cancel()end
    personalLateTimer,personalLatePage=nil,nil
end
function D:CapturePersonalNativeProbe(input)
    local page=Table(input);local live=page and Table(page.liveIncoming);local probe=live and Table(live.probe)
    if not page or page.personalNativeProbe or not probe or probe.stopReason~="own-death"or probe.endedAt~=page.diedAt then return end
    local packet,reason=R:ReadPersonalNativeForProbe(page)
    packet=packet or{rows={}}
    packet.source="personal-default";packet.status=packet.readBefore and"public-response"or(type(reason)=="string"and reason or"unavailable")
    packet.observedAt=Scalar(page.diedAt);page.personalNativeProbe=packet
    if probe.mode=="native-comparison"and C_Timer and type(C_Timer.NewTimer)=="function"then
        CancelPersonalLate()
        local timer
        local ok,value=pcall(C_Timer.NewTimer,1,function()
            if personalLateTimer~=timer or personalLatePage~=page then return end
            personalLateTimer,personalLatePage=nil,nil
            if R:GetPage()~=page or page.restored or not R:GetState().enabled then return end
            local late,why=R:ReadPersonalNativeForProbe(page,"late")
            late=late or{rows={}}
            late.source="personal-default-late";late.status=late.readBefore and"public-response"or(type(why)=="string"and why or"unavailable")
            local clockOK,observed=pcall(GetTime)
            late.observedAt=late.readBefore or(clockOK and Scalar(observed))or nil
            page.personalNativeProbeLate=late;R:SaveNativeDiagnostics(page)
        end)
        if ok and value then timer=value;personalLateTimer,personalLatePage=timer,page end
    end
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
-- Plain evidence readout for testing the recorder independently of the graph.
-- Uses, availability checks and death identity remain distinct. No live spell,
-- bag, charge or clock query is made while viewing this report.
function R:BuildCoreFactsText()
    local page=Table(self:GetSelectedPage())
    if not page then return nil,"No recorded personal death"end
    local audit=self:GetAvailabilityAudit();if not audit then return nil,"No recorded cooldown checks"end
    local Add,Finish=Writer()
    local died=Scalar(page.diedAt)
    local function Text(value,fallback)
        local value=Scalar(value)
        return type(value)=='string'and value or fallback
    end
    local function Age(value)
        local time=Scalar(value)
        if type(died)=='number'and type(time)=='number'and died>=time then return string.format('%.1fs before death',died-time)end
        return 'time not recorded'
    end
    local function Use(row)
        local count=row and Scalar(row.observedCount)
        if type(count)~='number'or count<1 then return 'No use recorded'end
        return 'Used '..string.format('%.0f',count)..(count==1 and' time' or' times')..'; last '..Age(row.lastSuccessfulUseAt)
    end
    local function State(row,ended)
        if not row then return 'No check recorded'end
        local state=self:ClassifyRecordedCheck(row,ended)
        local text=state==true and'Available'or state==false and'Unavailable'or'Not confirmed'
        if type(row.currentCharges)=='number'and type(row.maxCharges)=='number'then
            text=text..string.format(' (%d/%d charges)',row.currentCharges,row.maxCharges)
        elseif row.chargeCountStatus=='restricted'then text=text..' (charge count restricted by Blizzard)'end
        return text
    end
    Add('RCP Death Log - recorded facts')
    Add(Text(page.playerName,'Player')..' - death #'..string.format('%.0f',page.id))
    Add('Uses and availability are separate facts. These checks cannot prove a defensive would have prevented death.')
    Add('')
    Add('DEFENSIVES')
    for _,spell in ipairs(audit.spells)do if spell.role~='utility'then
        Add(Text(spell.name,'Defensive')..': '..Use(spell.use))
        local alive=spell.lastAlive
        Add('  Before death: '..State(alive,alive and alive.coverageEndedAt)..'; '..Age(alive and self:GetRecordedCheckTime(alive)))
        Add('  At death notice: '..State(spell.deathNotice))
    end end
    Add('')
    Add('CONSUMABLES')
    local names=(RA.DeathRecapCatalog or{}).itemUseNames or{}
    for _,use in ipairs(audit.consumableUses or{})do Add(Text(names[use.spellID],'Consumable')..': '..Use(use))end
    if #(audit.consumableUses or{})==0 then Add('No consumable use recorded')end
    for _,family in ipairs(self:GetSupplyFamilies(page))do
        local reasons={available='Available',cooldown='On cooldown',empty='No remaining uses',absent='None in bags'}
        Add(family.name..': '..(reasons[family.familyReason]or'Not confirmed')..'; '..Age(family.observedAt))
        for _,member in ipairs(family.members)do local row=member.row
            if row.physicalCount and row.physicalCount>0 then
                local itemNames=(RA.DeathRecapCatalog or{}).itemNames or{}
                local reason=member.state==true and'Available'or member.state==false and(row.cooldown=='active'and'On cooldown'or row.remainingUses==0 and'No remaining uses'or'Unavailable')or'Not confirmed'
                Add('  '..Text(itemNames[row.itemID],family.name)..': '..string.format('%.0f',row.physicalCount)..' in bags; '..reason)
            end
        end
    end
    Add('')
    local native=Table(page.native);local rows=native and Table(native.rows)
    Add('DAMAGE: '..(rows and #rows..' retained records' or'No native recap attached'))
    local live=Table(page.liveIncoming)
    if live then Add('LIVE INCOMING: '..#(Table(live.rows)or{})..' receipts in the last 8 seconds; /rcp recapdebug live')end
    Add('Coverage: '..(page.useCoverage and page.useCoverage.combatEntryObserved==true and'combat entry observed'or'incomplete combat entry'))
    if page.restored then Add('Saved death; this report does not query your current character.')end
    return Finish()
end
function R:BuildLiveHistoryText(includeRaw)
    local page=Table(self:GetSelectedPage());local live=page and Table(page.liveIncoming)
    if not live then return nil,"No live incoming history in this death; record a new death with Death Recap enabled"end
    local Add,Finish=Writer();local died=Scalar(page.diedAt)
    Add("RCP live incoming history - death #"..string.format("%.0f",page.id))
    Add("Your incoming damage/healing receipts. This feed contains no spell names or attackers.")
    Add("Times are local receipt times before the death notice, separate from Blizzard's named recap.")
    local rows=Table(live.rows)or{}
    Add(string.format("Retained %d receipts / 8 seconds; capacity 256. %d readable receipts this combat; %d restricted amounts; %d rejected amounts.",#rows,Scalar(live.total)or 0,Scalar(live.restricted)or 0,Scalar(live.rejected)or 0))
    if Scalar(live.callbacks)~=nil then
        local function Count(v)local n=Scalar(v);return type(n)=="number"and n or 0 end
        local function Yes(v)return v==true and"yes"or v==false and"no"or"not recorded"end
        Add(string.format("Recorder callbacks: %d; native player-event registration: %s; armed at death: %s.",Count(live.callbacks),Yes(Scalar(live.nativeRegistered)),Yes(Scalar(live.recording))))
        Add(string.format("Skipped: %d inactive; %d unit-filter; %d action-filter.",Count(live.inactive),Count(live.unitRejected),Count(live.actionRejected)))
        for i,entry in ipairs(Table(live.trace)or{})do if i<=6 then
            Add("Callback "..i..": "..FieldText(Fields(entry,{"unit","unitStatus","action","actionStatus","recording"}),{"unit","unitStatus","action","actionStatus","recording"}))
        end end
    end
    if type(D.AppendIncomingProbeText)=="function"then D:AppendIncomingProbeText(Add,live.probe)end
    if Scalar(live.total)and live.total>256 then Add("Capacity reached: the busiest eight-second window may be incomplete.")end
    if #rows==0 then Add("No readable UNIT_COMBAT receipts captured. The native recap is unchanged.")end
    local native=Table(page.native);local nativeRows=native and Table(native.rows)
    if nativeRows then Add("Blizzard's separate named recap retained "..#nativeRows.." hits.")end
    Add("")
    for index=1,math.min(#rows,256)do
        local row=Fields(rows[index],{"observedAt","kind","amount","school"})
        if type(died)=="number"and type(row.observedAt)=="number"and type(row.amount)=="number"
            and died>=row.observedAt and died-row.observedAt<=8 and(row.kind=="damage"or row.kind=="healing")then
            Add(string.format("-%.1fs  %s  %.0f",died-row.observedAt,row.kind=="damage"and"DAMAGE"or"HEAL",row.amount))
        end
    end
    if includeRaw==true then
        Add("RAW LIVE RECEIPTS - local clock only; exact public timestamps, no spell/source matching")
        Add("  death "..FieldText(Fields(page,{"id","diedAt","localSessionStartedAt"}),{"id","diedAt","localSessionStartedAt"}))
        local keys={"sequence","observedAt","kind","amount","flag","school"}
        for index=1,math.min(#rows,256)do Add("  receipt="..index.." "..FieldText(Fields(rows[index],keys),keys))end
    end
    local boundary=Table(live.deathBoundary)
    if boundary then
        Add("")
        Add("DEATH-NOTICE DELIVERY CHECK - excluded from pre-notice chart totals")
        Add("Callbacks delivered after the death notice, within the recorded deadline (up to one second). Delivery time does not prove damage time or killing-blow identity.")
        local keys={"source","clock","noticeAt","deadline","endedAt","active","capacity","callbacks","total","restricted","rejected","unitRejected","actionRejected","truncated","stopReason"}
        Add("  window "..FieldText(Fields(boundary,keys),keys))
        if page.restored and Scalar(boundary.active)==true then Add("Saved before this diagnostic window completed; completion was not recorded.")end
        for index=1,math.min(#(Table(boundary.rows)or{}),32)do
            local row=Fields(boundary.rows[index],{"sequence","observedAt","kind","amount","flag","school"})
            if includeRaw==true then Add("  afterNoticeReceipt="..index.." "..FieldText(row,{"sequence","observedAt","kind","amount","flag","school"}))
            elseif type(died)=="number"and type(row.observedAt)=="number"and row.observedAt>=died and type(row.amount)=="number"then
                Add(string.format("+%.3fs after notice  %s  %.0f",row.observedAt-died,row.kind=="healing"and"HEAL"or"DAMAGE",row.amount))
            end
        end
    end
    return Finish()
end
local function WritePacket(Add,label,packet)
    Add(label.." "..FieldText(packet.metadata,{"recapID","recapMaxHealth","recapMaxHealthStatus","truncated"}))
    Add("  retainedRows="..#packet.rows.." rowContainer="..(packet.rowsStatus or packet.status or"public").." exportTruncated="..tostring(packet.truncated==true))
    if packet.clock then Add("  frozenClock "..FieldText(packet.clock,CLOCK))end
    if packet.read then Add("  readBrackets "..FieldText(packet.read,{"readBefore","readAfter"}))end
    for i,row in ipairs(packet.rows)do
        Add("  arraySlot="..i.." "..FieldText(row,NATIVE))
        Add("    incomingDamageSource "..FieldText(row.incomingDamageSource,SOURCE))
        Add("    capturedFieldStatus "..FieldText(row.fieldStatus,STATUS))
    end
end
local function WriteCasts(Add,casts)
    Add("RECORDED CAST RECEIPTS retainedCount="..Encode(casts.inputCount,casts.status).." exportedCount="..#casts.rows.." exportTruncated="..tostring(casts.truncated))
    Add("  Raw capture order, including item uses; display may group repeated receipts, so icons need not map one-to-one.")
    Add("  localDeathRelativeAge is local death-notice time minus local observedAt, in seconds; no native alignment, duration, or shield contribution.")
    for _,row in ipairs(casts.rows)do Add("  CAST "..FieldText(row,CAST))end
end
local function WriteContext(Add,label,event)
    Add(label.." "..FieldText(event,EVENT,true))
    for i,field in ipairs(event.payload)do Add("      arg"..i.." "..FieldText(field,{"value","status"},true))end
end
local function WriteSample(Add,label,sample)
    Add(label.." "..FieldText(sample.metadata,SAMPLE))
    for _,item in ipairs(sample.supplies)do Add("  item "..FieldText(item,ITEM,true))end
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
            local old,new=Field(a.incomingDamageSource,"sourceName"),Field(b.incomingDamageSource,"sourceName")
            if old~=new then changed=changed+1;Add("  arraySlot="..i.." incomingDamageSource.sourceName frozen="..old.." reread="..new)end
        end
    end
    Add("  changedFieldsOrSlots="..changed.."; comparison covers retained rows only")
end
local function WritePersonalNativeProbe(Add,linked,probe,label)
    if not probe then return end
    Add((label or"PERSONAL DEFAULT PROBE").." "..FieldText(probe.metadata,{"source","status","observedAt"}))
    WritePacket(Add,"FROZEN PERSONAL DEFAULT - diagnostic only, never adopted as a meter ID",probe.packet)
    local personal=probe.packet
    local different,comparable=0,#linked.rows>0 and #personal.rows>0
    for i=1,math.max(#linked.rows,#personal.rows)do
        local a,b=linked.rows[i],personal.rows[i]
        if not a or not b then different=different+1
        else
            local changed=false
            for _,key in ipairs({"timestamp","event","rawSpellID","amount","recordedHP","absorbed","overkill","resisted","blocked","school"})do
                if Field(a,key)~=Field(b,key)then changed=true end
            end
            if a.unavailable.timestamp or b.unavailable.timestamp or a.unavailable.amount or b.unavailable.amount then comparable=false end
            if changed then different=different+1 end
        end
    end
    Add("NATIVE SOURCE COMPARISON - original array slots only; no event identity or clock mapping inferred")
    Add("  linkedRows="..#linked.rows.." personalDefaultRows="..#personal.rows.." differentRows="..different.." capturedFieldsMatch="..(comparable and tostring(different==0)or"not-comparable"))
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
    Add("RCP DEATH LOG DEBUG v2 - captured public fields only")
    Add("Raw original native index 1 is the fatal row. Maximum timestamp is separate; no native/GetTime clock bridge.")
    Add("Unavailable values are not zero/false. HP is event-associated; before/after-hit semantics are unspecified.")
    Add("Incoming native sourceName is damage-source text, not a shield provider. Shield not identified; provider not recorded.")
    Add("Loaded metadata (not capture-time client metadata): "..FieldText(snapshot.loaded,LOADED))
    Add(FieldText(snapshot.header,HEADER));Add("coverage "..FieldText(snapshot.coverage,COVERAGE))
    WriteCasts(Add,snapshot.casts)
    WritePacket(Add,"FROZEN NATIVE",snapshot.native)
    WritePersonalNativeProbe(Add,snapshot.native,snapshot.personalNative)
    WritePersonalNativeProbe(Add,snapshot.native,snapshot.personalNativeLate,"PERSONAL DEFAULT AFTER ONE SECOND")
    if reread==true then
        if comparison then WritePacket(Add,"EXPLICIT SAME-ID REREAD",comparison);WriteDiff(Add,snapshot.native,comparison)
        else local value,status=Scalar(readReason);Add("EXPLICIT SAME-ID REREAD unavailable="..Encode(value,status))end
    end
    Add("PRECOMBAT BASELINE - historical only; never readiness at death")
    WriteSample(Add,"PRECOMBAT CHECKS",snapshot.precombat)
    WriteSample(Add,"LAST ALIVE DEFENSIVE CHECKS",snapshot.lastAlive)
    WriteSample(Add,"DEATH NOTICE DEFENSIVE CHECKS",snapshot.deathNotice)
    for _,name in ipairs({"SPELL_UPDATE_COOLDOWN","SPELL_UPDATE_CHARGES"})do
        local event=snapshot.directEvents[name]
        if event then
            WriteContext(Add,"DIRECT EVENT "..name,event)
        end
    end
    for _,use in ipairs(snapshot.uses)do Add("OBSERVED USE "..FieldText(use,USE))end
    local liveText=self:BuildLiveHistoryText(true);if liveText then Add(liveText)end
    Add("END DEBUG - frozen capture unchanged; no chat submission")
    return Finish()
end

-- One owner-armed diagnostic, separate from recorder samples and death pages.
local capture,captureTimer,captureGeneration=nil,nil,0
local function Guard(value,kind)
    local value,status=Public(value)
    if status then return nil,status=="restricted"and"restricted"or"guard-unavailable"end
    if value==nil then return nil,"not-returned"end
    if type(value)~=kind then return nil,"unexpected-type"end
    if kind=="number"and(value~=value or value==math.huge or value==-math.huge)then return nil,"unexpected-type"end
    return value,"public"
end
local function ReadScalar(fn,kind,...)
    if type(fn)~="function"then return nil,"unavailable"end
    local ok,value=pcall(fn,...);if not ok then return nil,"call-error"end
    return Guard(value,kind)
end
-- Manually armed transport comparison only. Its own frame is unregistered at
-- death, timeout or disable. It never changes global combat-text settings.
local incomingProbe,incomingProbeFrame,incomingProbeTimer
local incomingTextTypes={DAMAGE=true,SPELL_DAMAGE=true,DAMAGE_CRIT=true,SPELL_DAMAGE_CRIT=true,DAMAGE_SHIELD=true,
    HEAL=true,HEAL_CRIT=true,PERIODIC_HEAL=true,PERIODIC_HEAL_CRIT=true,HEAL_ABSORB=true,PERIODIC_HEAL_ABSORB=true,HEAL_CRIT_ABSORB=true}
local function ProbeToken(value)
    local s,status=Guard(value,"string")
    if s and(#s>32 or not s:match("^[%w_]+$"))then return nil,"malformed"end
    return s,status
end
function D:StopIncomingProbe(reason,time)
    if reason~="own-death"then CancelPersonalLate()end
    local owner=incomingProbe
    if not owner or not owner.active then return false end
    time=Guard(time,"number")or ReadScalar(GetTime,"number")
    if reason=="own-death"and(not time or time<owner.armedAt or time>=owner.deadline)then reason="timeout";CancelPersonalLate()end
    owner.active=false;owner.stopReason=reason or"explicit-stop";owner.endedAt=time
    if incomingProbeFrame then incomingProbeFrame:UnregisterAllEvents()end
    if incomingProbeTimer then incomingProbeTimer:Cancel();incomingProbeTimer=nil end
    return true
end
function D:GetIncomingProbeForDeath(time)
    if incomingProbe and incomingProbe.stopReason=="own-death"and incomingProbe.endedAt==time then return incomingProbe end
end
function D:StartIncomingProbe(nativeOnly)
    nativeOnly=nativeOnly==true
    if not R:GetState().enabled then return false,"Enable Death Recap before starting the incoming-event test"end
    local time=ReadScalar(GetTime,"number")
    local duration=nativeOnly==true and 120 or 30
    if not time or time<0 or time+duration==math.huge or not C_Timer or type(C_Timer.NewTimer)~="function"then return false,"Incoming-event test clock or timeout unavailable"end
    self:StopIncomingProbe("replaced",time)
    local owner={active=true,mode=nativeOnly==true and"native-comparison"or"transport",armedAt=time,deadline=time+duration,callbacks=0,playerCallbacks=0,otherCallbacks=0,unreadableUnits=0,textCallbacks=0,textIncomingCallbacks=0,samples={},textSamples={}}
    incomingProbe=owner
    if not nativeOnly then
    incomingProbeFrame=incomingProbeFrame or CreateFrame("Frame")
    local ok=pcall(function()incomingProbeFrame:RegisterEvent("UNIT_COMBAT");incomingProbeFrame:RegisterEvent("COMBAT_TEXT_UPDATE")end)
    if not ok then self:StopIncomingProbe("registration-error",time);return false,"Incoming-event test registration failed"end
    owner.nativeRegistered=ReadScalar(incomingProbeFrame.IsEventRegistered,"boolean",incomingProbeFrame,"UNIT_COMBAT")
    incomingProbeFrame:SetScript("OnEvent",function(_,event,unit,action,flag,amount,school)
        local now=ReadScalar(GetTime,"number")
        if incomingProbe~=owner or not owner.active then return end
        if not now or now<owner.armedAt or now>=owner.deadline then D:StopIncomingProbe("timeout",now);return end
        if event=="COMBAT_TEXT_UPDATE"then
            owner.textCallbacks=owner.textCallbacks+1
            local kind=ProbeToken(unit)
            if kind and not incomingTextTypes[kind]then return end
            if kind then owner.textIncomingCallbacks=owner.textIncomingCallbacks+1 end
            if #owner.textSamples<6 then
                local sample={};sample.action,sample.actionStatus=ProbeToken(unit)
                sample.unit=ReadScalar(C_CombatText and C_CombatText.GetActiveUnit,"string")
                if C_CombatText and type(C_CombatText.GetCurrentEventInfo)=="function"then
                    local called,a,b=pcall(C_CombatText.GetCurrentEventInfo)
                    if called then sample.amount,sample.amountStatus=Guard(a,"number");sample.secondAmount,sample.secondAmountStatus=Guard(b,"number")end
                end
                owner.textSamples[#owner.textSamples+1]=sample
            end
            return
        end
        owner.callbacks=owner.callbacks+1
        local u=ProbeToken(unit)
        if u=="player"then owner.playerCallbacks=owner.playerCallbacks+1
        elseif u then owner.otherCallbacks=owner.otherCallbacks+1
        else owner.unreadableUnits=owner.unreadableUnits+1 end
        if #owner.samples<6 and(u=="player"or not u)then
            local sample={};sample.unit,sample.unitStatus=ProbeToken(unit);sample.action,sample.actionStatus=ProbeToken(action)
            sample.amount,sample.amountStatus=Guard(amount,"number");sample.school=Guard(school,"number")
            owner.samples[#owner.samples+1]=sample
        end
    end)
    end
    local timerOK,timer=pcall(C_Timer.NewTimer,duration,function()if incomingProbe==owner and owner.active then D:StopIncomingProbe("timeout")end end)
    if not timerOK or not timer then self:StopIncomingProbe("timer-error");return false,"Incoming-event test timeout failed"end
    incomingProbeTimer=timer
    return true,nativeOnly and"Native recap comparison armed for two minutes. After death, wait two seconds, then use /rcp recapdebug. Both sources are saved; no Blizzard window is needed."
        or"Incoming-event test armed for 30 seconds. Start combat now; after death use /rcp recapdebug live."
end
function D:AppendIncomingProbeText(Add,input)
    local p=Table(input);if not p then return end
    local metadata={"callbacks","playerCallbacks","otherCallbacks","unreadableUnits","textCallbacks","textIncomingCallbacks","nativeRegistered","stopReason"}
    Add("UNFILTERED TRANSPORT TEST "..FieldText(Fields(p,metadata),metadata))
    for _,group in ipairs({{"UNIT_COMBAT",p.samples},{"COMBAT_TEXT_UPDATE",p.textSamples}})do
        for i,sample in ipairs(Table(group[2])or{})do if i<=6 then
            local keys={"unit","unitStatus","action","actionStatus","amount","amountStatus","secondAmount","secondAmountStatus","school"}
            Add(group[1].." sample "..i..": "..FieldText(Fields(sample,keys),keys,true))
        end end
    end
end
local function Identity()
    local ok,value=pcall(R.GetCooldownDiagnosticIdentity,R)
    local identity=ok and Table(value)
    if not identity then return nil end
    local resolved,base,spec=ID(identity.resolvedSpellID),ID(identity.baseSpellID),ID(identity.specID)
    if resolved and base==55342 and spec then return{resolvedSpellID=resolved,baseSpellID=base,specID=spec}end
end
function D:StopCooldownCapture(reason,time)
    if not capture or not capture.active then return false end
    capture.active=false;capture.stopReason=reason or"explicit-stop"
    capture.endedAt=Guard(time,"number")
    if not capture.endedAt then capture.endedAt=ReadScalar(GetTime,"number")end
    captureGeneration=captureGeneration+1
    if captureTimer then pcall(function()captureTimer:Cancel()end);captureTimer=nil end
    return true
end
local function Current(owner,time)
    if capture~=owner or not owner or not owner.active or owner.generation~=captureGeneration then return false end
    time=Guard(time,"number")
    if not time or time<owner.armedAt then D:StopCooldownCapture("clock-unavailable",time);return false end
    if time>=owner.deadline then D:StopCooldownCapture("timeout",time);return false end
    local identity=Identity()
    if not identity or identity.resolvedSpellID~=owner.resolvedSpellID or identity.baseSpellID~=owner.baseSpellID or identity.specID~=owner.specID then
        D:StopCooldownCapture("identity-changed",time);return false
    end
    return true
end
function D:ValidateCooldownIdentity()
    if capture and capture.active then Current(capture,ReadScalar(GetTime,"number"))end
end
function D:CaptureCombatEntered()if capture and capture.active then capture.combatSeen=true end end
function D:CaptureCombatEnded()if capture and capture.active and capture.combatSeen then self:StopCooldownCapture("combat-ended")end end
local BUILD={"addonVersion","clientVersion","clientVersionStatus","clientBuild","clientBuildStatus","clientInterface","clientInterfaceStatus","buildQueryStatus"}
function D:StartCooldownCapture()
    local identity=Identity();if not identity then return false,"Cooldown capture requires Death Log enabled and a learned supported Mirror Image entry"end
    local time=ReadScalar(GetTime,"number");if not time or time<0 or time+20==math.huge then return false,"Cooldown capture requires a public local clock"end
    if not C_Timer or type(C_Timer.NewTimer)~="function"then return false,"Cooldown capture timeout unavailable"end
    self:StopCooldownCapture("replaced",time);captureGeneration=captureGeneration+1
    local owner={active=true,generation=captureGeneration,resolvedSpellID=identity.resolvedSpellID,baseSpellID=identity.baseSpellID,specID=identity.specID,
        armedAt=time,deadline=time+20,queryAttempts=0,eligibleEvents=0,ambiguousOrUnmatchedSkipped=0,sequence=0,samples={},receipts={},omittedReceipts=0,
        build={addonVersion=RA.VERSION,buildQueryStatus="unavailable"},combatSeen=ReadScalar(InCombatLockdown,"boolean")==true}
    capture=owner
    if type(GetBuildInfo)=="function"then
        local ok,version,build,_,interface=pcall(GetBuildInfo);owner.build.buildQueryStatus=ok and"returned"or"call-error"
        if ok then
            owner.build.clientVersion,owner.build.clientVersionStatus=Guard(version,"string")
            owner.build.clientBuild,owner.build.clientBuildStatus=Guard(build,"string")
            owner.build.clientInterface,owner.build.clientInterfaceStatus=Guard(interface,"number")
        end
    end
    local ok,timer=pcall(C_Timer.NewTimer,20,function()
        if capture==owner and owner.active and captureGeneration==owner.generation then D:StopCooldownCapture("timeout")end
    end)
    if not ok or not timer then self:StopCooldownCapture("timer-unavailable",time);return false,"Cooldown capture timeout unavailable"end
    captureTimer=timer
    return true,"Mirror Image cooldown capture armed for 20 seconds / 32 attempts; use recapdebug cooldowns stop to copy"
end
local function Predicate(object,method)
    local ok,value=pcall(function()return object[method](object)end)
    if not ok then return nil,"method-error"end
    return Guard(value,"boolean")
end
local function Duration(sample,id)
    local ok,object=pcall(C_Spell and C_Spell.GetSpellCooldownDuration,id,true)
    if not ok then sample.factoryStatus="factory-error";return end
    local object,status=Guard(object,"userdata")
    if status~="public"then sample.factoryStatus=status;return end
    sample.factoryStatus="public-userdata"
    sample.hasSecretValues,sample.hasSecretValuesStatus=Predicate(object,"HasSecretValues")
    sample.durationIsActive,sample.durationIsActiveStatus=Predicate(object,"IsActive")
    sample.durationIsZero,sample.durationIsZeroStatus=Predicate(object,"IsZero")
end
function D:CaptureCooldownEvent(context,direct)
    local owner=capture;if not owner or not owner.active then return end
    context=Table(context);if not context or not Current(owner,context.observedAt)then return end
    direct=Table(direct)
    if not direct or ID(direct.spellID)~=owner.resolvedSpellID then owner.ambiguousOrUnmatchedSkipped=owner.ambiguousOrUnmatchedSkipped+1;return end
    owner.eligibleEvents=owner.eligibleEvents+1
    local before,beforeStatus=ReadScalar(GetTime,"number")
    if not Current(owner,before)then return end
    owner.queryAttempts=owner.queryAttempts+1;owner.sequence=owner.sequence+1
    local sample=Fields(direct,CHECK)
    sample.sequence=owner.sequence;sample.eventSequence=context.eventSequence;sample.callbackAt=context.observedAt
    sample.context=Context(context);sample.queryBefore=before;sample.queryBeforeStatus=beforeStatus
    sample.combatLockdown,sample.combatLockdownStatus=ReadScalar(InCombatLockdown,"boolean")
    sample.receiptOrder=#owner.receipts==0 and"before-first-receipt"or"after-receipt"
    sample.hasSecretValuesStatus="not-queried";sample.durationIsActiveStatus="not-queried";sample.durationIsZeroStatus="not-queried"
    Duration(sample,owner.resolvedSpellID)
    sample.queryAfter,sample.queryAfterStatus=ReadScalar(GetTime,"number")
    owner.samples[#owner.samples+1]=sample
    if owner.queryAttempts>=32 then self:StopCooldownCapture("sample-cap",sample.queryAfter)
    elseif not sample.queryAfter or sample.queryAfter<before then self:StopCooldownCapture("clock-unavailable",sample.queryAfter)
    elseif sample.queryAfter>=owner.deadline then self:StopCooldownCapture("timeout",sample.queryAfter)end
end
function D:CaptureCooldownReceipt(spellID,time)
    local owner=capture;if not owner or not owner.active or ID(spellID)~=owner.resolvedSpellID or not Current(owner,time)then return end
    owner.sequence=owner.sequence+1
    if #owner.receipts<2 then owner.receipts[#owner.receipts+1]={sequence=owner.sequence,spellID=spellID,observedAt=time,source="UNIT_SPELLCAST_SUCCEEDED"}
    else owner.omittedReceipts=owner.omittedReceipts+1 end
end
local CAPTURE_HEADER={"resolvedSpellID","baseSpellID","specID","active","armedAt","deadline","endedAt","stopReason","queryAttempts","eligibleEvents","ambiguousOrUnmatchedSkipped","omittedReceipts"}
local CAPTURE_SAMPLE={"sequence","eventSequence","callbackAt","queryBefore","queryBeforeStatus","queryAfter","queryAfterStatus","receiptOrder","combatLockdown","combatLockdownStatus","factoryStatus",
    "hasSecretValues","hasSecretValuesStatus","durationIsActive","durationIsActiveStatus","durationIsZero","durationIsZeroStatus"}
local FLAGS={"spellID","baseSpellID","isEnabled","isActive","isOnGCD","cooldownEnabledStatus","cooldownActiveStatus","cooldownGCDStatus"}
function D:BuildCooldownCaptureText()
    if not capture then return nil,"No cooldown capture; use /rcp recapdebug cooldowns start"end
    local _,trust=Public(nil);if trust then return nil,"Trust check unavailable"end
    local Add,Finish=Writer();local owner=capture
    Add("RCP COOLDOWN CAPTURE v1 - owner-armed Mirror Image; separate from frozen recap and readiness")
    Add(owner.active and"PARTIAL IMMUTABLE COPY - capture continues until stop, deadline, or cap"or"FINAL CAPTURE")
    Add(FieldText(Fields(owner,CAPTURE_HEADER),CAPTURE_HEADER));Add(FieldText(Fields(owner.build,BUILD),BUILD))
    Add("Only synchronous SPELL_UPDATE_COOLDOWN queries, ignoreGCD=true. Owner must confirm the intended off-own-cooldown baseline; no readiness inference.")
    Add("Sequence describes local callback/receipt order, not server cast order. Missing states, nil, secret or failed results remain unknown; no clock bridge or past-data reconstruction.")
    local pre,post=false,false
    for _,sample in ipairs(owner.samples)do if sample.receiptOrder=="before-first-receipt"then pre=true else post=true end end
    Add("retainedSnapshots="..#owner.samples.." retainedReceipts="..#owner.receipts.." preReceiptSamples="..tostring(pre).." postReceiptSamples="..tostring(post))
    for _,sample in ipairs(owner.samples)do
        Add("SAMPLE "..FieldText(Fields(sample,CAPTURE_SAMPLE),CAPTURE_SAMPLE))
        -- Already sanitized CHECK fields retain original missing-field statuses.
        Add("  sameCallbackFlags "..FieldText(sample,FLAGS))
        if sample.context then WriteContext(Add,"  eventContext",sample.context)end
    end
    for _,receipt in ipairs(owner.receipts)do Add("RECEIPT "..FieldText(Fields(receipt,{"sequence","spellID","observedAt","source"}),{"sequence","spellID","observedAt","source"}))end
    Add("END COOLDOWN CAPTURE - public scalars/statuses only; no duration objects retained")
    return Finish()
end
