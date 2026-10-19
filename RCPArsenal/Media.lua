local ADDON_NAME, RA = ...

-- RCP Arsenal never requires a bundled font. It prefers Expressway from
-- LibSharedMedia, then an optional user-supplied copy in the addon Media folder,
-- and finally WoW's built-in Arial Narrow. Font files are intentionally not
-- shipped inside the addon archive.
local MEDIA_PATH = "Interface\\AddOns\\" .. tostring(ADDON_NAME or "RCPArsenal") .. "\\Media\\"
local LOCAL_REGULAR = MEDIA_PATH .. "Expressway.TTF"
local LOCAL_BOLD = MEDIA_PATH .. "Expressway Bold.ttf"
local FALLBACK = "Fonts\\ARIALN.TTF"

local function AddCandidate(target, value)
    if type(value) ~= "string" or value == "" then
        return
    end
    for i = 1, #target do
        if target[i] == value then
            return
        end
    end
    target[#target + 1] = value
end

local function GetSharedMediaFont(names)
    if not LibStub then
        return nil
    end

    local ok, media = pcall(LibStub, "LibSharedMedia-3.0", true)
    if not ok or not media or type(media.Fetch) ~= "function" then
        return nil
    end

    for i = 1, #names do
        local success, path = pcall(media.Fetch, media, "font", names[i], true)
        if success and type(path) == "string" and path ~= "" then
            return path
        end
    end
    return nil
end

function RA:GetFontCandidates(weight)
    local candidates = {}
    local bold = weight == "BOLD"

    if bold then
        AddCandidate(candidates, GetSharedMediaFont({
            "Expressway Bold",
            "Expressway ExtraBold",
            "Expressway",
        }))
        AddCandidate(candidates, LOCAL_BOLD)
        AddCandidate(candidates, LOCAL_REGULAR)
    else
        AddCandidate(candidates, GetSharedMediaFont({
            "Expressway",
            "Expressway Regular",
            "Expressway Bold",
        }))
        AddCandidate(candidates, LOCAL_REGULAR)
        AddCandidate(candidates, LOCAL_BOLD)
    end

    AddCandidate(candidates, FALLBACK)
    return candidates
end

function RA:ApplyFont(fontString, size, weight, shadow, refreshingAsset)
    if not fontString or type(fontString.SetFont) ~= "function" then
        return false
    end

    -- Whole-number sizes and no outline flag render much more cleanly at the
    -- small sizes used by the combat HUD.
    size = math.max(6, math.floor((tonumber(size) or 10) + 0.5))
    local applied = false
    local candidates = self:GetFontCandidates(weight)
    for i = 1, #candidates do
        local ok, result = pcall(fontString.SetFont, fontString, candidates[i], size, "")
        if ok and result == true then
            applied = true
            break
        end
    end

    if not applied then
        local ok, result = pcall(fontString.SetFont, fontString, FALLBACK, size, "")
        applied = ok and result == true
    end

    if fontString.SetShadowColor and fontString.SetShadowOffset then
        if shadow then
            fontString:SetShadowColor(0, 0, 0, 0.52)
            fontString:SetShadowOffset(1, -1)
        else
            fontString:SetShadowColor(0, 0, 0, 0)
            fontString:SetShadowOffset(0, 0)
        end
    end

    if not refreshingAsset and self.RegisterVisualFont then
        self:RegisterVisualFont(fontString, size, weight, shadow, applied)
    end

    return applied
end

function RA:GetFontStatus()
    local probeParent = CreateFrame("Frame")
    local probe = probeParent:CreateFontString(nil, "OVERLAY")
    local candidates = self:GetFontCandidates("REGULAR")
    for i = 1, #candidates do
        local ok, result = pcall(probe.SetFont, probe, candidates[i], 10, "")
        if ok and result == true then
            local path = candidates[i]
            if path == FALLBACK then
                return "Blizzard Arial Narrow", path
            end
            return "Expressway", path
        end
    end
    return "Blizzard Arial Narrow", FALLBACK
end
