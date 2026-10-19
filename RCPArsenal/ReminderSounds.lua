local _, RA = ...
local Sounds = { DEFAULT_ID = "builtin_alert", DEFAULT_CHANNEL = "SFX" }
RA.ReminderSounds = Sounds
local prefix = "Interface\\AddOns\\RCPArsenal\\Media\\Audio\\"
-- Curated IDs only. Saved variables never supply a path or sound-kit number.
-- User-provided file assets and transformation provenance are validated by packaging checks.
local entries = {
    { id = "builtin_alert", label = "Built-in alert", kind = "kit", kitID = 12889 },
    { id = "sound_1", label = "Sound 1", kind = "file", path = prefix .. "RCP_Sound01.ogg" },
    { id = "sound_2", label = "Sound 2", kind = "file", path = prefix .. "RCP_Sound02.ogg" },
    { id = "sound_3", label = "Sound 3", kind = "file", path = prefix .. "RCP_Sound03.ogg" },
    { id = "sound_4", label = "Sound 4", kind = "file", path = prefix .. "RCP_Sound04.ogg" },
    { id = "sound_5", label = "Sound 5", kind = "file", path = prefix .. "RCP_Sound05.ogg" },
    { id = "sound_6", label = "Sound 6", kind = "file", path = prefix .. "RCP_Sound06.ogg" },
}
local byID = {}
for _, entry in ipairs(entries) do byID[entry.id] = entry end
local function Plain(value)
    return not (type(issecretvalue) == "function" and issecretvalue(value)) and type(value) == "string"
end
function Sounds:Get(id)
    if not Plain(id) or not byID[id] then return nil end
    local copy = {}; for key, value in pairs(byID[id]) do copy[key] = value end; return copy
end
function Sounds:NormalizeID(id) return self:Get(id) and id or self.DEFAULT_ID end
function Sounds:NormalizeChannel(channel)
    return Plain(channel) and channel == "Master" and "Master" or "SFX"
end
function Sounds:ChannelLabel(channel) return Plain(channel) and channel == "Master" and "Master" or "Sound Effects" end
function Sounds:GetOptions()
    local options = {}
    for _, entry in ipairs(entries) do options[#options + 1] = { value = entry.id, label = entry.label } end
    return options
end
