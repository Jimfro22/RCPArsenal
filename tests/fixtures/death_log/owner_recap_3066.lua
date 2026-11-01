-- Owner recap 3066: a manually extracted subset of the 2026-11-01
-- /rcp recapdebug reread pasted in the root chat, not the full raw export.
-- Values below mirror owner-recap3066-extracted.json, including raw HP and
-- native timestamps. nil means JSON null/omitted, never zero or a negative fact.
-- Do not add potion counts, spell names, source identities or clock alignment:
-- none were supplied in this subset. Native event 1 is fatal, but its HP is 45326.
local fixture = {
    sourceFile = "owner-recap3066-extracted.json",
    sourceSHA256 = "74a7ab72d9abf3bda4834b70eb6f530f1fb5b80112be3310e4bcafffb201eae1",
}
fixture.raw = {
    source = "Owner /rcp recapdebug reread pasted in root chat 2026-11-01. Manually extracted subset, not full raw export.",
    recapID = 3066,
    specID = 62,
    class = "MAGE",
    diedAt = 46006.757,
    sessionStart = 45981.475,
    maxHealth = 850900,
    frozenReadBefore = 46006.757,
    frozenReadAfter = 46006.757,
    rereadBefore = 47312.034,
    rereadAfter = 47312.034,
    changedFieldsOrSlots = 0,
    coverage = {
        combatEntryObserved = true,
        rejectedReceipts = 0,
        lateReceipts = 0,
    },
    nativeRows = {
        [1] = {
            nativeIndex = 1,
            event = "SPELL_DAMAGE",
            timestamp = 1793504614.704,
            spellID = 1302525,
            amount = 110425,
            recordedHP = 45326,
            absorbed = 12268,
            overkill = 65356,
            hideCaster = false,
        },
        [2] = {
            nativeIndex = 2,
            event = "SWING_DAMAGE",
            timestamp = 1793504614.488,
            spellID = 88163,
            amount = 27511,
            recordedHP = 72995,
            absorbed = 3056,
            overkill = nil,
            hideCaster = false,
        },
        [3] = {
            nativeIndex = 3,
            event = "SPELL_PERIODIC_DAMAGE",
            timestamp = 1793504614.113,
            spellID = 294741,
            amount = 15014,
            recordedHP = 88095,
            absorbed = 1667,
            overkill = nil,
            hideCaster = false,
        },
        [4] = {
            nativeIndex = 4,
            event = "SPELL_PERIODIC_DAMAGE",
            timestamp = 1793504614.113,
            spellID = 294741,
            amount = 15014,
            recordedHP = 103195,
            absorbed = 1667,
            overkill = nil,
            hideCaster = false,
        },
        [5] = {
            nativeIndex = 5,
            event = "SPELL_PERIODIC_DAMAGE",
            timestamp = 1793504614.113,
            spellID = 294741,
            amount = 15014,
            recordedHP = 118295,
            absorbed = 1667,
            overkill = nil,
            hideCaster = false,
        },
        [6] = {
            nativeIndex = 6,
            event = "SPELL_PERIODIC_DAMAGE",
            timestamp = 1793504613.9,
            spellID = 1309786,
            amount = 14058,
            recordedHP = 132353,
            absorbed = nil,
            overkill = nil,
            hideCaster = false,
        },
        [7] = {
            nativeIndex = 7,
            event = "SPELL_PERIODIC_DAMAGE",
            timestamp = 1793504613.8,
            spellID = 1302693,
            amount = 30434,
            recordedHP = 162961,
            absorbed = 3380,
            overkill = nil,
            hideCaster = false,
        },
        [8] = {
            nativeIndex = 8,
            event = "SPELL_PERIODIC_DAMAGE",
            timestamp = 1793504613.642,
            spellID = 294741,
            amount = 15014,
            recordedHP = 177341,
            absorbed = 1667,
            overkill = nil,
            hideCaster = false,
        },
        [9] = {
            nativeIndex = 9,
            event = "SWING_DAMAGE",
            timestamp = 1793504613.284,
            spellID = 88163,
            amount = 30830,
            recordedHP = 208348,
            absorbed = 3425,
            overkill = nil,
            hideCaster = false,
        },
        [10] = {
            nativeIndex = 10,
            event = "SPELL_PERIODIC_DAMAGE",
            timestamp = 1793504612.9,
            spellID = 1309786,
            amount = 14848,
            recordedHP = 223196,
            absorbed = nil,
            overkill = nil,
            hideCaster = false,
        },
    },
    uses = {
        [1] = {
            spellID = 414658,
            count = 1,
            first = 45997.202,
            last = 45997.202,
        },
        [2] = {
            spellID = 235450,
            count = 2,
            first = 45983.795,
            last = 46001.522000000004,
        },
        [3] = {
            spellID = 342245,
            count = nil,
        },
        [4] = {
            spellID = 55342,
            count = 1,
            first = 45988.377,
            last = 45988.377,
        },
        [5] = {
            spellID = 110959,
            count = nil,
        },
    },
    lastAlive = {
        observedAt = 46006.641,
        source = "item-event",
        checks = {
            [1] = {
                spellID = 414658,
                baseSpellID = 45438,
                observedAt = 46004.85,
                cooldownAt = 46004.85,
                chargesAt = 46006.282,
                cooldown = "active",
                isActive = true,
                isOnGCD = false,
                cooldownGCDStatus = "public",
                chargeQuery = "public",
                chargeCountStatus = "restricted",
                maxCharges = 1,
                chargesActive = false,
            },
            [2] = {
                spellID = 235450,
                observedAt = 46004.85,
                cooldownAt = 46004.85,
                chargesAt = 46006.282,
                cooldown = "inactive",
                isActive = false,
                cooldownGCDStatus = "not-recorded",
                chargeQuery = "public",
                chargeCountStatus = "restricted",
                maxCharges = 2,
                chargesActive = true,
            },
            [3] = {
                spellID = 342245,
                observedAt = 46004.85,
                cooldownAt = 46004.85,
                chargesAt = 46004.953,
                cooldown = "inactive",
                isActive = false,
                cooldownGCDStatus = "not-recorded",
                chargeQuery = "not_applicable",
            },
            [4] = {
                spellID = 55342,
                observedAt = 46004.85,
                cooldownAt = 46004.85,
                chargesAt = 46006.282,
                cooldown = "active-context-unknown",
                isActive = true,
                cooldownGCDStatus = "not-recorded",
                chargeQuery = "not_applicable",
            },
            [5] = {
                spellID = 110959,
                baseSpellID = 66,
                observedAt = 46004.85,
                cooldownAt = 46004.85,
                chargesAt = 46004.953,
                cooldown = "inactive",
                isActive = false,
                cooldownGCDStatus = "not-recorded",
                chargeQuery = "not_applicable",
            },
        },
    },
    directEvent = {
        lastPerSpellSequence = 103,
        lastPerSpellPayload = {
            [1] = nil,
            [2] = nil,
            [3] = nil,
            [4] = nil,
            [5] = nil,
        },
        lastGlobalSequence = 104,
        lastGlobalObservedAt = 46004.85,
        lastGlobalPayload = {
            [1] = 449336,
            [2] = nil,
            [3] = nil,
            [4] = nil,
            [5] = nil,
        },
    },
    deathNotice = {
        observedAt = 46006.757,
        spellActive = {
            ["55342"] = true,
            ["110959"] = false,
            ["235450"] = false,
            ["342245"] = false,
            ["414658"] = true,
        },
        barrierCharges = {
            currentCharges = "restricted",
            maxCharges = 2,
            chargesActive = true,
        },
        note = "Death queries outside cooldown event; direct values retained as separate evidence.",
    },
}

local function Copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, item in pairs(value) do out[key] = Copy(item) end
    return out
end

-- Returns fresh normalized page inputs for the actual UI/model. The page id
-- is a fixture identifier. Native offsets are DERIVED from the latest native
-- timestamp, never from local diedAt. All raw timestamps/HP remain untouched.
-- Optional individual casts are DERIVED from the aggregate endpoints only;
-- the owner subset has no exported individual receipt list. Opt in explicitly
-- for a grouped-receipt rendering fixture and label that artifact accordingly.
function fixture.NewPage(includeDerivedReceipts)
    local raw = fixture.raw
    local page = {
        id = raw.recapID,
        specID = raw.specID,
        class = raw.class,
        diedAt = raw.diedAt,
        maxHealth = raw.maxHealth,
        localSessionStartedAt = raw.sessionStart,
        useCoverage = Copy(raw.coverage),
        casts = {},
        observedUses = {},
        lastAlive = {
            observedAt = raw.lastAlive.observedAt,
            source = raw.lastAlive.source,
            spells = Copy(raw.lastAlive.checks),
            -- No item data in the extracted subset; empty does not mean absent.
            supplies = {},
        },
        native = {
            recapID = raw.recapID,
            recapMaxHealth = raw.maxHealth,
            readBefore = raw.frozenReadBefore,
            readAfter = raw.frozenReadAfter,
            rows = {},
        },
        fixtureProvenance = {
            sourceFile = fixture.sourceFile,
            individualReceipts = "Not included in the source subset",
            nativeOffsets = "DERIVED: native timestamp minus maximum native timestamp",
        },
    }
    page.useCoverage.startedAt = raw.sessionStart
    local maximum
    for _, row in ipairs(raw.nativeRows) do
        maximum = math.max(maximum or row.timestamp, row.timestamp)
    end
    for _, source in ipairs(raw.nativeRows) do
        local row = Copy(source)
        row.kind = "damage" -- All ten captured event kinds are damage events.
        row.nativeOffset = row.timestamp - maximum
        page.native.rows[#page.native.rows + 1] = row
    end
    local function DerivedCast(use, timestamp, endpoint)
        page.casts[#page.casts + 1] = {
            spellID = use.spellID,
            observedAt = timestamp,
            source = "DERIVED_FROM_AGGREGATE_ENDPOINT",
            derived = true,
            derivation = "DERIVED from aggregate count " .. use.count .. " / " .. endpoint .. "; not an exported individual receipt",
        }
    end
    for _, use in ipairs(raw.uses) do
        if use.count ~= nil then
            page.observedUses[use.spellID] = {
                spellID = use.spellID,
                observedCount = use.count,
                firstSuccessfulUseAt = use.first,
                lastSuccessfulUseAt = use.last,
            }
            if includeDerivedReceipts then
                if use.count == 1 and use.first == use.last and use.first ~= nil then
                    DerivedCast(use, use.first, "first equals last")
                elseif use.count == 2 and use.first ~= nil and use.last ~= nil then
                    DerivedCast(use, use.first, "first")
                    DerivedCast(use, use.last, "last")
                end
            end
        end
    end
    if includeDerivedReceipts then
        page.fixtureProvenance.individualReceipts = "DERIVED from aggregate count 1/2 endpoints; not the raw exported receipt list"
        table.sort(page.casts, function(a, b)
            if a.observedAt == b.observedAt then return a.spellID < b.spellID end
            return a.observedAt < b.observedAt
        end)
    end
    return page
end

return fixture
