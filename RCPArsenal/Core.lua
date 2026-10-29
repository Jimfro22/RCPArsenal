local ADDON_NAME, RA = ...

_G.RCPArsenal = RA
_G.RaidArsenal = RA -- legacy global retained for compatibility

RA.ADDON_NAME = ADDON_NAME
RA.VERSION = "0.15.3-alpha.26"
RA.BUILD = RA.VERSION
RA.READINESS_PROTOCOL = 1
RA.CATALOG_VERSION = 6
RA.PROFILE_SCHEMA = 19
RA.InEncounter = false
RA.Initialized = false
RA.DebugEnabled = false

-- Saved appearance data only. Never accepts live health or native alpha.
function RA:NormalizeReminderGlow(value)
    local function public(v) return not (type(issecretvalue) == "function" and issecretvalue(v)) end
    local source = public(value) and type(value) == "table" and value or {}
    local function number(key, default, minimum, maximum, step)
        local v = source[key]
        if not public(v) or type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then v = default end
        return math.floor(math.max(minimum, math.min(maximum, v)) / step + 0.5) * step
    end
    local style = source.style
    if not public(style) or type(style) ~= "string" or not ({STEADY=true, PIXEL=true, BUTTON=true, AUTOCAST=true})[style] then style = "STEADY" end
    local color = public(source.color) and type(source.color) == "table" and source.color or {}
    local rgb = {}
    for i, default in ipairs({1, 0.72, 0.18}) do
        local v = color[i]
        if not public(v) or type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then v = default end
        rgb[i] = math.max(0, math.min(1, v))
    end
    return {style=style, color=rgb, pixelLines=number("pixelLines",8,1,12,1), pixelSpeed=number("pixelSpeed",1,0.5,2,0.1),
        pixelLength=number("pixelLength",10,4,16,1), pixelThickness=number("pixelThickness",2,1,4,1),
        buttonSpeed=number("buttonSpeed",1,0.5,2,0.1), autocastGroups=number("autocastGroups",4,1,8,1),
        autocastSpeed=number("autocastSpeed",1,0.5,2,0.1), autocastSize=number("autocastSize",100,50,150,5)}
end

-- A report is only current when its class-specific catalog revision matches.
-- This lets future updates invalidate one class instead of rescanning the raid.
RA.CLASS_CATALOG_REVISIONS = {
    PALADIN = 2,
    PRIEST = 2,
    MONK = 2,
}

-- Shared reminder limit: Unicode code points, never a byte cut inside UTF-8.
-- Malformed saved input retains its valid prefix. Native edit-box limits use
-- the same 60-character cap; getter, setter and migration call this helper.
function RA:NormalizeReminderText(value)
    if type(value) ~= "string" or (type(issecretvalue) == "function" and issecretvalue(value)) then return "" end
    value = value:gsub("[\r\n]", " ")
    local position, last = 1, 0
    for count = 1, 60 do
        local first = value:byte(position)
        if not first then break end
        local width = first < 128 and 1 or (first >= 194 and first <= 223 and 2)
            or (first >= 224 and first <= 239 and 3) or (first >= 240 and first <= 244 and 4)
        if not width then break end
        local valid = true
        for offset = 1, width - 1 do
            local byte = value:byte(position + offset)
            if not byte or byte < 128 or byte > 191 then valid = false; break end
        end
        local second = value:byte(position + 1)
        if (first == 224 and second and second < 160) or (first == 237 and second and second > 159)
            or (first == 240 and second and second < 144) or (first == 244 and second and second > 143) then valid = false end
        if not valid then break end
        last = position + width - 1
        position = last + 1
    end
    return value:sub(1, last)
end

local eventFrame = CreateFrame("Frame")
local eventHandlers = {}
local initializers = {}
local callbacks = {}

local DEFAULTS = {
    profile = {
        schemaVersion = RA.PROFILE_SCHEMA,
        hudEnabled = false,
        shown = false,
        locked = false,
        mode = "COMPACT",

        -- Detailed mode remains a readable table. Compact mode is the primary
        -- encounter HUD and sizes itself to the ability tiles it contains.
        detailedWidth = 286,
        scale = 1.25,
        opacity = 0.96,
        autoShowEncounter = false,
        hideWhenSolo = false,
        leaderOnly = false,
        demoMode = false,
        accentPreset = "SUNSET", -- SUNSET, CRIMSON, BERRY
        hudDirection = "RIGHT", -- AUTO, RIGHT, LEFT, DOWN, UP

        content = {
            showTooltips = true,
        },

        position = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 360,
            y = 34,
        },
        positionAnchorVersion = 0,

        -- Compact HUD presentation. Every value is deliberately independent:
        -- tile size controls information density while profile.scale scales the
        -- complete HUD without changing wrap behavior.
        compact = {
            iconSize = 28,
            nameLength = 4,
            nameFontSize = 8,
            tileGap = 3,
            rowGap = 2,
            categoryGap = 4,
            wrapAfter = 8,
            overflowMode = "WRAP",      -- WRAP or LIMIT
            showEmptyState = false,
            backgroundStyle = "RIBBONS", -- NONE, ICONS, TILES, RIBBONS, PANEL
            categoryLabels = "SHORT",    -- HIDDEN, SHORT, FULL
            labelWidth = 34,
            panelPadding = 4,
        },

        scan = {
            showStrip = false,
            scale = 1.10,
            wrapAfter = 9,
            demoPreview = false,
        },

        actions = {
            -- Exactly one primary left-click channel is used at a time. This
            -- prevents one hardware click from emitting multiple chat lines
            -- and tripping Blizzard's chat throttle during rapid calls.
            leftClickMode = "OFF", -- WHISPER, SAY, OFF
            sayEnabled = false,        -- legacy mirror for older profiles
            whisperEnabled = false,     -- legacy mirror for older profiles
            raidWarningEnabled = false,
            sayTemplate = "{name} - {spell}",
            whisperTemplate = "RAID LEAD: USE {spell}",
            raidWarningTemplate = "{name} - {spell}",
        },

        -- Local opt-in only. Do not put numeric order defaults here:
        -- CopyDefaults would refill deliberately removed/empty sequence slots.
        worldMarkers = { enabled = false, radialEnabled = false },
        personalTools = { autoRes = false, autoResInCombat = false, consumableReminder = false, healthThreshold = 40,
            reminderStoneText = "Use Healthstone", reminderPotionText = "Use healing potion", reminderIconSize = 56, reminderCombat = "IN_COMBAT", reminderSound = true,
            reminderSoundChannel = "Master", reminderSoundChoice = "sound_6", reminderEmptyTextSize = 48, reminderShowOnCooldown = false, reminderSoundWhenEffectsMuted = false, reminderStoneGlow = true },
        readiness = { targets = {}, revision = 0, updatedAt = 0, origin = "" },

        -- Small hover puck that expands into pre-pull raid utilities. By
        -- default it is visible to every raid member; users can optionally
        -- hide it unless they are raid lead/assist. Privileged actions remain
        -- permission-gated either way.
        -- Its placement is intentionally local and is not part of portable
        -- profile import/export.
        leaderToolbox = {
            enabled = false,
            showForNonLeaders = true,
            closeDelay = 1.0,
            tooltipDelay = 0.75,
            puckSize = 30,
            countdownSeconds = 15,
            flyoutDirection = "AUTO", -- AUTO, RIGHT, LEFT, DOWN, UP
            showMissing = true,
            panicEnabled = false,
            panicMessage = "PANIC: USE DEFENSIVES + HEALTH POTIONS NOW!",
            position = {
                point = "LEFT",
                relativePoint = "LEFT",
                x = 12,
                y = 70,
            },
            positionAnchorVersion = 0,
        },

        -- Groups 7 and 8 are normally bench groups for this raid. They are
        -- excluded from the scan denominator, pending strip, and combat HUD.
        ignoredRaidGroups = {
            [7] = true,
            [8] = true,
        },

        categories = {
            RAID_DEFENSIVE = true,
            RAID_HEALING = true,
            MOVEMENT = true,
            EXTERNALS = false,
            MANA = false,
            UTILITY = false,
            RECOVERY = true,
        },
        abilities = {},
        abilityOrder = {},
    },
}

local function CopyDefaults(source, destination)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(destination[key]) ~= "table" then
                destination[key] = {}
            end
            CopyDefaults(value, destination[key])
        elseif destination[key] == nil then
            destination[key] = value
        end
    end
end

function RA:NormalizeWorldMarkerSettings(settings)
    settings = type(settings) == "table" and settings or {}
    settings.enabled = settings.enabled == true
    settings.radialEnabled = settings.radialEnabled == true
    local source = settings.order
    if type(source) ~= "table" then source = {1, 2, 3, 4, 5, 6, 7, 8} end
    local order, seen = {}, {}
    for i = 1, 8 do
        local marker = tonumber(source[i])
        if marker and marker == math.floor(marker) and marker >= 1 and marker <= 8 and not seen[marker] then
            order[#order + 1] = marker
            seen[marker] = true
        end
    end
    settings.order = order
    return settings
end

local function MigrateProfile(profile)
    local schema = tonumber(profile.schemaVersion) or 0

    if schema < 3 then
        profile.width = nil
        profile.mode = "COMPACT"
        profile.detailedWidth = 258
        schema = 3
    end

    if schema < 4 then
        profile.compactWidth = nil
        profile.mode = "COMPACT"
        profile.positionAnchorVersion = 0
        schema = 4
    end

    if schema < 5 then
        -- v0.4's approved proportions were physically too small in the live
        -- client. Existing users on the untouched default migrate to 125%; a
        -- deliberately customized scale is preserved.
        local oldScale = tonumber(profile.scale)
        if not oldScale or (oldScale >= 0.99 and oldScale <= 1.01) then
            profile.scale = 1.25
        end
        profile.detailedWidth = math.max(258, tonumber(profile.detailedWidth) or 286)
        schema = 5
    end

    if schema < 6 then
        -- The earlier alpha shipped with groups 5 and 6 as the default bench
        -- groups. Only translate that exact untouched pattern; custom group
        -- selections survive the upgrade.
        local ignored = profile.ignoredRaidGroups or {}
        -- Defaults are copied before migration, so 7/8 may already be present
        -- here. Clear the mistaken v0.5 default pair and establish 7/8 as the
        -- new default. Other custom group exclusions are preserved.
        ignored[5] = nil
        ignored[6] = nil
        ignored[7] = true
        ignored[8] = true
        profile.ignoredRaidGroups = ignored
        profile.abilityOrder = profile.abilityOrder or {}

        -- Recover profiles that were left hidden by the v0.5.1 hotfix. This is
        -- a one-time alpha migration; users can immediately hide it again from
        -- the new HUD visibility control.
        profile.shown = true
        -- "Leader-only" describes the install model, not a requirement that
        -- the local character hold raid lead or assist. Keep the optional
        -- visibility filter available, but default/migrate it off.
        profile.leaderOnly = false
        profile.positionAnchorVersion = 0
        schema = 6
    end

    if schema < 7 then
        -- v0.7 replaces only the settings presentation. Combat HUD, filters,
        -- cache, positioning, and secure actions remain untouched.
        schema = 7
    end

    if schema < 8 then
        -- v0.8 aligns the combat HUD with Obsidian Ember, enables the useful
        -- scan demo by default, and adds portable settings profiles.
        profile.scan = profile.scan or {}
        profile.scan.demoPreview = true
        profile.compact = profile.compact or {}
        if profile.compact.roundedIcons == nil then
            profile.compact.roundedIcons = true
        end
        -- Normalize to a top-left anchor so the completed HUD occupies the
        -- exact same origin as the temporary scan shell when it collapses.
        profile.positionAnchorVersion = 0
        schema = 8
    end

    if schema < 9 then
        -- v0.9 rebrands to RCP Arsenal, adds three accent presets and an
        -- optional native spell tooltip on Content icons. Existing visual and
        -- scanning settings are intentionally preserved.
        profile.accentPreset = profile.accentPreset or "SUNSET"
        profile.content = profile.content or {}
        if profile.content.showTooltips == nil then
            profile.content.showTooltips = true
        end
        schema = 9
    end

    if schema < 10 then
        -- v0.10 introduces the local Raid Leader Toolbox. Its default puck is
        -- near the left edge and expands on hover. Existing HUD placement is
        -- untouched.
        profile.leaderToolbox = profile.leaderToolbox or {}
        if profile.leaderToolbox.enabled == nil then profile.leaderToolbox.enabled = true end
        profile.leaderToolbox.closeDelay = tonumber(profile.leaderToolbox.closeDelay) or 1.0
        profile.leaderToolbox.position = profile.leaderToolbox.position or {
            point = "LEFT", relativePoint = "LEFT", x = 12, y = 70,
        }
        schema = 10
    end

    if schema < 11 then
        -- v0.11 rebuilds the Raid Leader Toolbox, adds left-click Say +
        -- Whisper, and migrates both movable frames to scale-safe physical
        -- top-left coordinates. Existing locations are captured in place on
        -- the first visible refresh rather than being reset.
        profile.actions = profile.actions or {}
        if profile.actions.sayEnabled == nil then profile.actions.sayEnabled = true end
        profile.actions.sayTemplate = tostring(profile.actions.sayTemplate or "{name} - {spell}")
        profile.positionAnchorVersion = 0
        profile.leaderToolbox = profile.leaderToolbox or {}
        profile.leaderToolbox.positionAnchorVersion = 0
        if profile.leaderToolbox.showMissing == nil then profile.leaderToolbox.showMissing = true end
        schema = 11
    end

    if schema < 12 then
        -- v0.11.2 keeps /say as an optional left-click action but disables it
        -- by default. Two chat lines per tile click can hit Blizzard's chat
        -- throttle surprisingly quickly during rapid raid-leader callouts.
        -- This alpha migration intentionally turns Say off once for existing
        -- v0.11 profiles; users can explicitly re-enable it in Actions.
        profile.actions = profile.actions or {}
        profile.actions.sayEnabled = false
        schema = 12
    end

    if schema < 13 then
        -- v0.12 makes Say and Whisper mutually exclusive left-click modes,
        -- adds the raid-leader Panic button, and keeps all v0.11 placement
        -- data intact. When an older profile had both channels enabled, use
        -- Whisper as the safer single-message migration target.
        profile.actions = profile.actions or {}
        local a = profile.actions
        -- Defaults are copied before migration, so derive from the legacy
        -- booleans unconditionally for schema-12 profiles.
        if a.sayEnabled == true and a.whisperEnabled == false then
            a.leftClickMode = "SAY"
        elseif a.whisperEnabled ~= false then
            a.leftClickMode = "WHISPER"
        elseif a.sayEnabled == true then
            a.leftClickMode = "SAY"
        else
            a.leftClickMode = "OFF"
        end
        profile.leaderToolbox = profile.leaderToolbox or {}
        if profile.leaderToolbox.panicEnabled == nil then profile.leaderToolbox.panicEnabled = true end
        profile.leaderToolbox.panicMessage = tostring(profile.leaderToolbox.panicMessage or "PANIC: USE DEFENSIVES + HEALTH POTIONS NOW!")
        schema = 13
    end

    if schema < 14 then
        -- v0.12.1 hardens both movable overlays around stable, unscaled
        -- anchors. The saved v2 top-left coordinates are already expressed in
        -- UIParent space, so no destructive position reset is required. The
        -- Raid Leader Dock also gains explicit puck and tooltip timing prefs.
        profile.leaderToolbox = profile.leaderToolbox or {}
        if profile.leaderToolbox.tooltipDelay == nil then profile.leaderToolbox.tooltipDelay = 0.75 end
        if profile.leaderToolbox.puckSize == nil then profile.leaderToolbox.puckSize = 30 end
        schema = 14
    end

    if schema < 15 then
        -- v0.13 reorganizes Quick Bar preferences, adds direction controls,
        -- a checkmark-only launcher, missing-buff badge states, pin/click-away
        -- behavior, and session-scoped undo for raid sorting.
        profile.leaderToolbox = profile.leaderToolbox or {}
        if profile.leaderToolbox.flyoutDirection == nil then profile.leaderToolbox.flyoutDirection = "AUTO" end
        if profile.hudDirection == nil then profile.hudDirection = "RIGHT" end
        schema = 15
    end

    if schema < 16 then
        -- v0.13.1 adds a configurable left-click pull countdown to the Quick
        -- Bar puck. It defaults to 15 seconds and can be cancelled by clicking
        -- the puck again before the countdown window expires.
        profile.leaderToolbox = profile.leaderToolbox or {}
        if profile.leaderToolbox.countdownSeconds == nil then profile.leaderToolbox.countdownSeconds = 15 end
        schema = 16
    end

    if schema < 17 then
        -- v0.13.4 keeps the Quick Bar available to normal raid members by
        -- default, but adds an opt-out that hides it unless the player is raid
        -- lead or assist. Existing profiles preserve the v0.13.3 behavior.
        profile.leaderToolbox = profile.leaderToolbox or {}
        if profile.leaderToolbox.showForNonLeaders == nil then profile.leaderToolbox.showForNonLeaders = true end
        schema = 17
    end

    if schema < 18 then
        profile.worldMarkers = RA:NormalizeWorldMarkerSettings(profile.worldMarkers)
        profile.worldMarkers.enabled = false
        schema = 18
    end
    profile.worldMarkers = RA:NormalizeWorldMarkerSettings(profile.worldMarkers)

    if schema < 19 then
        -- One-time hub rollout: inherited true defaults were not explicit
        -- consent. Preserve positions, content, templates and visual prefs.
        profile.hudEnabled, profile.shown = false, false
        profile.autoShowEncounter, profile.demoMode = false, false
        profile.scan = profile.scan or {}
        profile.scan.showStrip, profile.scan.demoPreview = false, false
        profile.leaderToolbox = profile.leaderToolbox or {}
        profile.leaderToolbox.enabled, profile.leaderToolbox.panicEnabled = false, false
        profile.leaderToolbox.showMissing = false
        profile.actions = profile.actions or {}
        profile.actions.leftClickMode, profile.actions.sayEnabled = "OFF", false
        profile.actions.whisperEnabled, profile.actions.raidWarningEnabled = false, false
        schema = 19
    end
    profile.hudEnabled = profile.hudEnabled == true
    profile.demoMode = profile.hudEnabled and profile.demoMode == true
    if not profile.hudEnabled then profile.shown = false end
    profile.personalTools = type(profile.personalTools) == "table" and profile.personalTools or {}
    profile.personalTools.autoRes = profile.personalTools.autoRes == true
    profile.personalTools.autoResInCombat = profile.personalTools.autoResInCombat == true
    profile.personalTools.consumableReminder = profile.personalTools.consumableReminder == true
    profile.personalTools.healthThreshold = math.max(1, math.min(99, tonumber(profile.personalTools.healthThreshold) or 40))
    local personal = profile.personalTools
    for key, default in pairs({ reminderStoneText = "Use Healthstone", reminderPotionText = "Use healing potion" }) do
        local value = personal[key]
        if type(value) ~= "string" then value = type(personal.reminderText) == "string" and personal.reminderText or default end
        personal[key] = RA:NormalizeReminderText(value)
    end
    personal.reminderIconSize = math.max(24, math.min(128, tonumber(personal.reminderIconSize) or 56))
    personal.reminderEmptyTextSize = math.max(16, math.min(96, tonumber(personal.reminderEmptyTextSize) or 48))
    if personal.reminderTextSize ~= nil then personal.reminderTextSize = math.max(8, math.min(32, tonumber(personal.reminderTextSize) or 10)) end
    personal.reminderSoundChannel = RA.ReminderSounds and RA.ReminderSounds:NormalizeChannel(personal.reminderSoundChannel)
        or (personal.reminderSoundChannel == "SFX" and "SFX" or "Master")
    personal.reminderSoundChoice = RA.ReminderSounds and RA.ReminderSounds:NormalizeID(personal.reminderSoundChoice) or "sound_6"
    personal.reminderShowOnCooldown = personal.reminderShowOnCooldown == true
    personal.reminderSoundWhenEffectsMuted = personal.reminderSoundWhenEffectsMuted == true
    personal.reminderStoneGlow = personal.reminderStoneGlow ~= false
    personal.reminderGlow = RA:NormalizeReminderGlow(personal.reminderGlow)
    if personal.reminderSound == nil then personal.reminderSound = true else personal.reminderSound = personal.reminderSound == true end
    if personal.reminderCombat ~= "BOTH" and personal.reminderCombat ~= "IN_COMBAT" and personal.reminderCombat ~= "OUT_OF_COMBAT" then personal.reminderCombat = "IN_COMBAT" end
    profile.readiness = type(profile.readiness) == "table" and profile.readiness or {}
    profile.readiness.targets = type(profile.readiness.targets) == "table" and profile.readiness.targets or {}
    profile.readiness.revision = math.max(0, tonumber(profile.readiness.revision) or 0)
    profile.readiness.updatedAt = tonumber(profile.readiness.updatedAt) or 0
    profile.readiness.origin = type(profile.readiness.origin) == "string" and profile.readiness.origin or ""

    profile.schemaVersion = RA.PROFILE_SCHEMA
    profile.scale = math.max(0.75, math.min(2.0, tonumber(profile.scale) or 1.25))
    profile.opacity = math.max(0.25, math.min(1.0, tonumber(profile.opacity) or 0.96))
    profile.detailedWidth = math.max(240, math.min(520, tonumber(profile.detailedWidth) or 286))
    profile.positionAnchorVersion = tonumber(profile.positionAnchorVersion) or 0

    if profile.mode ~= "DETAILED" and profile.mode ~= "COMPACT" then
        profile.mode = "COMPACT"
    end

    local compact = profile.compact or {}
    profile.compact = compact

    -- Accept fields from experimental v0.5 previews and older v0.4 profiles.
    compact.iconSize = compact.iconSize or compact.tileSize or 28
    compact.nameFontSize = compact.nameFontSize or compact.nameFont or 8
    compact.rowGap = compact.rowGap or compact.tileRowGap or 2
    compact.iconSize = math.max(20, math.min(42, tonumber(compact.iconSize) or 28))
    compact.nameLength = math.max(0, math.min(8, tonumber(compact.nameLength) or 4))
    compact.nameFontSize = math.floor(math.max(6, math.min(13, tonumber(compact.nameFontSize) or 8)) + 0.5)
    compact.tileGap = math.max(0, math.min(10, tonumber(compact.tileGap) or 3))
    compact.rowGap = math.max(0, math.min(10, tonumber(compact.rowGap) or 2))
    compact.categoryGap = math.max(0, math.min(16, tonumber(compact.categoryGap) or 4))
    compact.wrapAfter = math.max(3, math.min(14, tonumber(compact.wrapAfter) or 8))
    compact.overflowMode = compact.overflowMode == "LIMIT" and "LIMIT" or "WRAP"
    if compact.showEmptyState == nil then compact.showEmptyState = false end
    if compact.roundedIcons == nil then compact.roundedIcons = true end
    compact.roundedIcons = compact.roundedIcons ~= false
    compact.labelWidth = math.max(34, math.min(120, tonumber(compact.labelWidth) or 34))
    compact.panelPadding = math.max(0, math.min(16, tonumber(compact.panelPadding) or 4))

    local backgroundAliases = {
        RIBBON = "RIBBONS",
        RIBBONS = "RIBBONS",
        ICON = "ICONS",
        ICONS = "ICONS",
        TILE = "TILES",
        TILES = "TILES",
        NONE = "NONE",
        PANEL = "PANEL",
    }
    compact.backgroundStyle = backgroundAliases[compact.backgroundStyle] or "RIBBONS"

    local validLabels = {
        HIDDEN = true,
        SHORT = true,
        FULL = true,
    }
    if not validLabels[compact.categoryLabels] then
        compact.categoryLabels = "SHORT"
    end

    local scan = profile.scan or {}
    profile.scan = scan
    scan.scale = scan.scale or compact.scanScale or 1.10
    if scan.showStrip == nil then
        scan.showStrip = compact.showScanStrip == true
    end
    scan.wrapAfter = scan.wrapAfter or compact.wrapAfter or 9
    scan.scale = math.max(0.75, math.min(2.0, tonumber(scan.scale) or 1.10))
    scan.wrapAfter = math.max(4, math.min(14, tonumber(scan.wrapAfter) or 9))
    if scan.demoPreview == nil then scan.demoPreview = false end

    profile.abilityOrder = profile.abilityOrder or {}

    profile.ignoredRaidGroups = profile.ignoredRaidGroups or {}

    local validAccents = { SUNSET = true, CRIMSON = true, BERRY = true }
    profile.accentPreset = validAccents[profile.accentPreset] and profile.accentPreset or "SUNSET"
    local validDirections = { AUTO = true, RIGHT = true, LEFT = true, DOWN = true, UP = true }
    profile.hudDirection = validDirections[profile.hudDirection] and profile.hudDirection or "RIGHT"
    profile.content = profile.content or {}
    if profile.content.showTooltips == nil then profile.content.showTooltips = true end
    profile.content.showTooltips = profile.content.showTooltips ~= false

    local leaderToolbox = profile.leaderToolbox or {}
    profile.leaderToolbox = leaderToolbox
    leaderToolbox.enabled = leaderToolbox.enabled == true
    if leaderToolbox.showForNonLeaders == nil then leaderToolbox.showForNonLeaders = true end
    leaderToolbox.showForNonLeaders = leaderToolbox.showForNonLeaders ~= false
    leaderToolbox.showMissing = leaderToolbox.showMissing ~= false
    leaderToolbox.panicEnabled = leaderToolbox.panicEnabled == true
    leaderToolbox.panicMessage = tostring(leaderToolbox.panicMessage or "PANIC: USE DEFENSIVES + HEALTH POTIONS NOW!")
    leaderToolbox.closeDelay = math.max(0.15, math.min(3.0, tonumber(leaderToolbox.closeDelay) or 1.0))
    leaderToolbox.tooltipDelay = math.max(0.20, math.min(2.5, tonumber(leaderToolbox.tooltipDelay) or 0.75))
    leaderToolbox.puckSize = math.floor(math.max(24, math.min(44, tonumber(leaderToolbox.puckSize) or 30)) + 0.5)
    leaderToolbox.countdownSeconds = math.floor(math.max(1, math.min(3600, tonumber(leaderToolbox.countdownSeconds) or 15)) + 0.5)
    leaderToolbox.flyoutDirection = validDirections[leaderToolbox.flyoutDirection] and leaderToolbox.flyoutDirection or "AUTO"
    leaderToolbox.position = leaderToolbox.position or { point = "LEFT", relativePoint = "LEFT", x = 12, y = 70 }
    leaderToolbox.position.point = leaderToolbox.position.point or "LEFT"
    leaderToolbox.position.relativePoint = leaderToolbox.position.relativePoint or "LEFT"
    leaderToolbox.position.x = tonumber(leaderToolbox.position.x) or 12
    leaderToolbox.position.y = tonumber(leaderToolbox.position.y) or 70
    leaderToolbox.positionAnchorVersion = tonumber(leaderToolbox.positionAnchorVersion) or 0

    local actions = profile.actions or {}
    profile.actions = actions
    local validLeftClickModes = { WHISPER = true, SAY = true, OFF = true }
    if not validLeftClickModes[actions.leftClickMode] then
        if actions.sayEnabled == true and actions.whisperEnabled == false then
            actions.leftClickMode = "SAY"
        elseif actions.whisperEnabled == true then
            actions.leftClickMode = "WHISPER"
        elseif actions.sayEnabled == true then
            actions.leftClickMode = "SAY"
        else
            actions.leftClickMode = "OFF"
        end
    end
    -- Keep legacy booleans synchronized for old exports/addon integrations,
    -- but never permit both channels to be armed on the same click.
    actions.sayEnabled = actions.leftClickMode == "SAY"
    actions.whisperEnabled = actions.leftClickMode == "WHISPER"
    actions.raidWarningEnabled = actions.raidWarningEnabled == true
    actions.sayTemplate = tostring(actions.sayTemplate or "{name} - {spell}")
    actions.whisperTemplate = tostring(actions.whisperTemplate or "RAID LEAD: USE {spell}")
    actions.raidWarningTemplate = tostring(actions.raidWarningTemplate or "{name} - {spell}")

end

function RA:RegisterInitializer(func)
    initializers[#initializers + 1] = func
end

local function RefreshEventRegistration(event)
    local handlers = eventHandlers[event]
    local active, unit, general = false, nil, false
    for i = 1, #handlers do
        local entry = handlers[i]
        if entry.enabled then
            active = true
            if not entry.unit or (unit and unit ~= entry.unit) then general = true end
            unit = entry.unit or unit
        end
    end
    if general or type(eventFrame.RegisterUnitEvent) ~= "function" then unit = nil end
    if active == handlers.registered and unit == handlers.unit then return end
    if handlers.registered then eventFrame:UnregisterEvent(event) end
    handlers.registered, handlers.unit = active, unit
    if active then
        if unit then eventFrame:RegisterUnitEvent(event, unit) else eventFrame:RegisterEvent(event) end
    end
end
local Subscription = {}
function Subscription:SetEnabled(enabled)
    enabled = not (type(issecretvalue) == "function" and issecretvalue(enabled)) and enabled == true
    if self.enabled == enabled then return end
    self.enabled = enabled
    RefreshEventRegistration(self.event)
end
local subscriptionMeta = {__index = Subscription}
local function AddEventHandler(event, func, enabled, unit)
    if not eventHandlers[event] then eventHandlers[event] = {registered = false} end
    local entry = setmetatable({event = event, callback = func, enabled = enabled, unit = unit}, subscriptionMeta)
    local handlers = eventHandlers[event]
    handlers[#handlers + 1] = entry
    RefreshEventRegistration(event)
    return entry
end
function RA:RegisterEvent(event, func) return AddEventHandler(event, func, true) end
-- Optional callbacks remain in a stable dispatch list; disabled subscribers
-- are skipped before pcall, and unshared native events are unsubscribed.
function RA:RegisterOptionalEvent(event, func, unit) return AddEventHandler(event, func, false, unit) end

function RA:RegisterCallback(name, func)
    if not callbacks[name] then
        callbacks[name] = {}
    end
    callbacks[name][#callbacks[name] + 1] = func
end

function RA:FireCallback(name, ...)
    local handlers = callbacks[name]
    if not handlers then
        return
    end

    for i = 1, #handlers do
        local ok, err = pcall(handlers[i], ...)
        if not ok then
            self:Print("Callback error: " .. tostring(err))
        end
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local handlers = eventHandlers[event]
    if not handlers then
        return
    end

    for i = 1, #handlers do
        local entry = handlers[i]
        if entry.enabled then
            local ok, err = pcall(entry.callback, event, ...)
            if not ok then RA:Print(event .. " error: " .. tostring(err)) end
        end
    end
end)

function RA:Print(message)
    print("|cffff0f7bRCP|r |cfff89b29Arsenal|r: " .. tostring(message))
end

function RA:Debug(message)
    if self.DebugEnabled then
        self:Print("|cff8b95a5DEBUG|r " .. tostring(message))
    end
end

function RA:GetDB()
    return RaidArsenalDB and RaidArsenalDB.profile
end

function RA:IsHUDEnabled()
    local db = self:GetDB()
    return db and db.hudEnabled == true or false
end

function RA:IsInspectionEnabled()
    return self:IsHUDEnabled()
end

function RA:SetHUDEnabled(enabled)
    if InCombatLockdown() then return false, "Change this after combat." end
    local db = self:GetDB()
    db.hudEnabled, db.shown = enabled == true, enabled == true
    if not enabled then
        db.demoMode = false
        if self.StopInspectionScan then self:StopInspectionScan() end
    elseif self.ScheduleInspectionScan then
        self:ScheduleInspectionScan("HUD explicitly enabled", 0.1, false)
    end
    self:FireCallback("TOOLS_CHANGED")
    if self.RefreshHUD then self:RefreshHUD() end
    return true
end

function RA:SetQuickBarEnabled(enabled, reviewedShowMissing)
    if InCombatLockdown() then return false, "Change this after combat." end
    local toolbox = self:GetDB().leaderToolbox
    -- Explicit activation adopts provider coverage even for legacy defaults.
    -- Ordinary refresh/normalization preserves a later deliberate OFF choice.
    if enabled == true then toolbox.showMissing = reviewedShowMissing ~= false end
    toolbox.enabled = enabled == true
    if self.RaidLeaderToolbox then self.RaidLeaderToolbox:Refresh() end
    self:FireCallback("TOOLS_CHANGED")
    return true
end

function RA:GetClassCatalogRevision(classFile)
    return (self.CLASS_CATALOG_REVISIONS and self.CLASS_CATALOG_REVISIONS[classFile]) or 1
end

function RA:GetFullUnitName(unit)
    local name, realm = UnitFullName(unit)
    if (issecretvalue and (issecretvalue(name) or issecretvalue(realm))) or type(name) ~= "string" or name == "" then
        return nil
    end
    if not realm or realm == "" then
        realm = GetNormalizedRealmName and GetNormalizedRealmName() or (GetRealmName and GetRealmName())
        if issecretvalue and issecretvalue(realm) then return nil end
        if type(realm) == "string" then realm = realm:gsub("%s", "") end
    end
    if type(realm) == "string" and realm ~= "" then
        return name .. "-" .. realm
    end
    return name
end

function RA:FormatInspectionEvidenceSummary(summary)
    summary = summary or self:GetScanSummary()
    return string.format("%d confirmed · %d cached · %d unknown", summary.confirmed or summary.inspected or 0, summary.cached or 0, summary.unknown or 0)
end

function RA:GetInspectionEvidenceText(report)
    if not report then return "Specialization and talents unknown." end
    if report.source == "DEMO" then return "Demo data." end
    local cached = report.cached == true or report.source == "PERSISTED_CACHE"
    local text = cached and "Saved inspection; not confirmed this session."
        or (report.sessionVerified == true and (report.originalSource == "LOCAL" and "Observed locally this session." or "Inspected this session.") or "Inspection evidence unavailable.")
    local stamp = report.confirmedAt
    if type(stamp) == "number" and not (issecretvalue and issecretvalue(stamp)) and stamp > 0 then
        local clock = GetServerTime or time
        local ok, now = false, nil
        if clock then ok, now = pcall(clock) end
        if ok and type(now) == "number" and not (issecretvalue and issecretvalue(now)) and now >= stamp then
            local age = now - stamp
            local elapsed = age < 60 and "under 1m" or (age < 3600 and (math.floor(age / 60) .. "m") or (age < 86400 and (math.floor(age / 3600) .. "h") or (math.floor(age / 86400) .. "d")))
            text = text .. " Last confirmed " .. elapsed .. " ago."
        end
    end
    return text .. " Talents may have changed; /rcp rescan refreshes them."
end

function RA:GetShortName(fullName)
    if not fullName then
        return "?"
    end
    return fullName:match("^[^-]+") or fullName
end

function RA:GetClassColor(classFile)
    -- UnitClass/GetRaidRosterInfo can briefly return a nil class token while
    -- the roster is changing. C_ClassColor throws on nil, so validate first
    -- and always provide a neutral, readable fallback.
    if type(classFile) ~= "string" or classFile == "" then
        return 0.76, 0.79, 0.84
    end

    local fallback = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if fallback then
        return fallback.r, fallback.g, fallback.b
    end

    if C_ClassColor and type(C_ClassColor.GetClassColor) == "function" then
        local ok, color = pcall(C_ClassColor.GetClassColor, classFile)
        if ok and color then
            return color.r or 0.76, color.g or 0.79, color.b or 0.84
        end
    end

    return 0.76, 0.79, 0.84
end

function RA:ColorizeName(name, classFile)
    local r, g, b = self:GetClassColor(classFile)
    return string.format("|cff%02x%02x%02x%s|r", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), name)
end

function RA:Round(value)
    return math.floor(value + 0.5)
end

local function RoundPosition(value)
    value = tonumber(value) or 0
    if value >= 0 then
        return math.floor(value * 1000 + 0.5) / 1000
    end
    return math.ceil(value * 1000 - 0.5) / 1000
end

-- Region:GetLeft()/GetTop() are expressed in the region's effective scale.
-- Persisting those values directly causes a scaled HUD to drift after reload.
-- Convert through physical screen pixels into UIParent coordinates first.
function RA:GetFrameTopLeftInUIParent(frame)
    if not frame or not frame.GetLeft or not frame.GetTop then return nil end
    local left, top = frame:GetLeft(), frame:GetTop()
    if type(left) ~= "number" or type(top) ~= "number" then return nil end

    local frameScale = frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
    local parentScale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if type(frameScale) ~= "number" or frameScale <= 0 then frameScale = 1 end
    if type(parentScale) ~= "number" or parentScale <= 0 then parentScale = 1 end

    local ratio = frameScale / parentScale
    return left * ratio, top * ratio
end

function RA:CaptureFrameTopLeft(frame, destination)
    destination = destination or {}
    local left, top = self:GetFrameTopLeftInUIParent(frame)
    local parentHeight = UIParent and UIParent.GetHeight and UIParent:GetHeight() or nil
    if not left or not top or type(parentHeight) ~= "number" then
        return false
    end

    destination.point = "TOPLEFT"
    destination.relativePoint = "TOPLEFT"
    destination.x = RoundPosition(left)
    destination.y = RoundPosition(top - parentHeight)
    return true
end

function RA:RestoreFrameTopLeft(frame, position, fallback)
    if not frame then return end
    position = position or fallback or {}
    fallback = fallback or {}
    local x = tonumber(position.x)
    local y = tonumber(position.y)
    if x == nil then x = tonumber(fallback.x) or 0 end
    if y == nil then y = tonumber(fallback.y) or 0 end

    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
end

function RA:IsFrameOffscreen(frame, margin)
    if not frame or not UIParent then return false end
    local left, top = self:GetFrameTopLeftInUIParent(frame)
    local width, height = frame:GetWidth(), frame:GetHeight()
    local frameScale = frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
    local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local parentWidth, parentHeight = UIParent:GetWidth(), UIParent:GetHeight()
    if not left or not top or type(width) ~= "number" or type(height) ~= "number"
        or type(parentWidth) ~= "number" or type(parentHeight) ~= "number" then
        return false
    end
    local ratio = (type(frameScale) == "number" and frameScale > 0 and frameScale or 1)
        / (type(parentScale) == "number" and parentScale > 0 and parentScale or 1)
    local right = left + width * ratio
    local bottom = top - height * ratio
    margin = tonumber(margin) or 8
    return right < margin or left > parentWidth - margin or top < margin or bottom > parentHeight - margin
end

function RA:CreateDefaultProfile()
    local profile = {}
    CopyDefaults(DEFAULTS.profile, profile)
    MigrateProfile(profile)
    return profile
end

function RA:NormalizeProfile(profile)
    MigrateProfile(profile)
    return profile
end

function RA:ApplyImportedProfile(profile)
    if type(profile) ~= "table" or InCombatLockdown() then
        return false
    end

    -- Normalize donor settings before restoring local intent. Old schema
    -- migrations must never undo switches explicitly chosen on this client.
    MigrateProfile(profile)
    local current = RaidArsenalDB and RaidArsenalDB.profile or nil
    if current then
        -- Portable appearance/content preferences do not change local tool
        -- activation, targets, placement, or marker/keybinding choices.
        profile.position = current.position
        profile.positionAnchorVersion = current.positionAnchorVersion
        profile.shown = current.shown
        profile.hudEnabled = current.hudEnabled
        profile.demoMode, profile.autoShowEncounter = current.demoMode, current.autoShowEncounter
        profile.personalTools, profile.readiness = current.personalTools, current.readiness
        profile.scan = profile.scan or {}
        profile.scan.showStrip, profile.scan.demoPreview = current.scan.showStrip, current.scan.demoPreview
        profile.actions = profile.actions or {}
        for _, key in ipairs({"leftClickMode", "sayEnabled", "whisperEnabled", "raidWarningEnabled"}) do
            profile.actions[key] = current.actions[key]
        end

        -- World-marker opt-in and sequence are local. Keybindings belong to
        -- Blizzard, never to portable profiles. Imports cannot enable this tool.
        profile.worldMarkers = current.worldMarkers

        profile.leaderToolbox = profile.leaderToolbox or {}
        local currentToolbox = current.leaderToolbox or {}
        profile.leaderToolbox.enabled = currentToolbox.enabled
        profile.leaderToolbox.panicEnabled = currentToolbox.panicEnabled
        profile.leaderToolbox.showMissing = currentToolbox.showMissing
        profile.leaderToolbox.position = currentToolbox.position
        profile.leaderToolbox.positionAnchorVersion = currentToolbox.positionAnchorVersion
    end

    RaidArsenalDB.profile = profile
    if self.Theme and self.Theme.SetAccentPreset then
        self.Theme:SetAccentPreset(profile.accentPreset, false)
    end
    self:FireCallback("PROFILE_RESET", "IMPORT")
    self:FireCallback("PROFILE_IMPORTED")
    return true
end

function RA:ResetProfile()
    RaidArsenalDB.profile = self:CreateDefaultProfile()
    if self.Theme and self.Theme.SetAccentPreset then
        self.Theme:SetAccentPreset(RaidArsenalDB.profile.accentPreset, false)
    end
    self:FireCallback("PROFILE_RESET")
end

RA:RegisterEvent("ADDON_LOADED", function(_, loadedAddon)
    if loadedAddon ~= ADDON_NAME then
        return
    end

    RA.WasExistingInstall = type(RaidArsenalDB) == "table" and type(RaidArsenalDB.profile) == "table"
    RaidArsenalDB = RaidArsenalDB or {}
    CopyDefaults(DEFAULTS, RaidArsenalDB)
    MigrateProfile(RaidArsenalDB.profile)

    for i = 1, #initializers do
        local ok, err = pcall(initializers[i])
        if not ok then
            RA:Print("Initialization error: " .. tostring(err))
        end
    end

    RA.Initialized = true
    RA:FireCallback("INITIALIZED")
end)
