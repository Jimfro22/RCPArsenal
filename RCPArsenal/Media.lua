local ADDON_NAME, RA = ...

-- RCP Arsenal never requires a bundled font. It prefers Expressway from
-- LibSharedMedia, then an optional user-supplied copy in the addon Media folder,
-- and finally WoW's built-in Arial Narrow. Font files are intentionally not
-- shipped inside the addon archive.
local MEDIA_PATH = "Interface\\AddOns\\" .. tostring(ADDON_NAME or "RCPArsenal") .. "\\Media\\"
local LOCAL_REGULAR = MEDIA_PATH .. "Expressway.TTF"
local LOCAL_BOLD = MEDIA_PATH .. "Expressway Bold.ttf"
local FALLBACK = "Fonts\\ARIALN.TTF"
local resolvedFonts = {}
local fontSerial = 0
local sharedMedia

local function FontDetails(instance)
    if not instance or not instance.GetFont then return nil end
    local ok, path, height = pcall(instance.GetFont, instance)
    if ok and type(path) == "string" and path ~= "" and type(height) == "number" and height > 0 then
        return path, height
    end
end

local function NormalizePath(path)
    return path:lower():gsub("/", "\\")
end

function RA:InvalidateFontCache()
    -- Previously resolved FontObjects remain untouched. Existing captions keep
    -- their working native font until the new choice is applied to that region.
    resolvedFonts = {}
    if self.RequestVisualAssetRefresh then self:RequestVisualAssetRefresh() end
end

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

    if sharedMedia ~= media and type(media.RegisterCallback) == "function" then
        sharedMedia = media
        pcall(media.RegisterCallback, RA, "LibSharedMedia_Registered", function(_, mediaType)
            if mediaType == "font" then RA:InvalidateFontCache() end
        end)
    end

    for i = 1, #names do
        local success, path = pcall(media.Fetch, media, "font", names[i], true)
        if success and type(path) == "string" and path ~= "" then
            return path
        end
    end
    return nil
end

local function ResolveFont(size, weight)
    local key = tostring(weight or "REGULAR") .. ":" .. tostring(size)
    if resolvedFonts[key] then return resolvedFonts[key] end

    -- Optional paths are tested on one FontObject, never on live captions.
    -- SetFont's boolean alone is insufficient: the native instance must expose
    -- the requested file and a valid height through GetFont afterwards. The
    -- same native loading workaround is used in WeakAuras/RegionTypes/Text.lua.
    local font
    if CreateFont then
        fontSerial = fontSerial + 1
        local ok, created = pcall(CreateFont, "RCPArsenalResolvedFont" .. fontSerial)
        if ok then font = created end
    end
    if font and font.SetFontObject and GameFontNormal then
        pcall(font.SetFontObject, font, GameFontNormal)
    end

    local candidates = RA:GetFontCandidates(weight)
    if font then
        for i = 1, #candidates do
            local ok, result = pcall(font.SetFont, font, candidates[i], size, "")
            local actualPath = FontDetails(font)
            if ok and result == true and actualPath and NormalizePath(actualPath) == NormalizePath(candidates[i]) then
                local resolved = {object = font, path = actualPath, size = size}
                resolvedFonts[key] = resolved
                return resolved
            end
        end
    end

    -- CreateFont is always available in Retail; this path also leaves reduced
    -- test/compatibility environments on a game-supplied font.
    local resolved = {path = FALLBACK, size = size}
    resolvedFonts[key] = resolved
    return resolved
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
    -- Read text before any font mutation. Some native failures invalidate the
    -- FontString; reading GetText only after SetFont cannot recover its caption.
    local text = self.GetVisualText and self:GetVisualText(fontString)
    local color = fontString.GetTextColor and {fontString:GetTextColor()}
    local justifyH = fontString.GetJustifyH and fontString:GetJustifyH()
    local justifyV = fontString.GetJustifyV and fontString:GetJustifyV()
    local spacing = fontString.GetSpacing and fontString:GetSpacing()
    local fontChanged = false
    if not FontDetails(fontString) and fontString.SetFontObject and GameFontNormal then
        pcall(fontString.SetFontObject, fontString, GameFontNormal)
        fontChanged = true
    end

    local resolved = ResolveFont(size, weight)
    if fontString.__raResolvedFont ~= resolved or not FontDetails(fontString) then
        if resolved.object and fontString.SetFontObject then
            pcall(fontString.SetFontObject, fontString, resolved.object)
        else
            pcall(fontString.SetFont, fontString, resolved.path, size, "")
        end
        fontString.__raResolvedFont = resolved
        fontChanged = true
    end
    local applied = FontDetails(fontString) ~= nil
    if not applied then
        if fontString.SetFontObject and GameFontNormal then pcall(fontString.SetFontObject, fontString, GameFontNormal) end
        pcall(fontString.SetFont, fontString, FALLBACK, size, "")
        applied = FontDetails(fontString) ~= nil
        fontChanged = true
    end

    if color and color[1] ~= nil and fontString.SetTextColor then fontString:SetTextColor(unpack(color)) end
    if justifyH and fontString.SetJustifyH then fontString:SetJustifyH(justifyH) end
    if justifyV and fontString.SetJustifyV then fontString:SetJustifyV(justifyV) end
    if spacing and fontString.SetSpacing then fontString:SetSpacing(spacing) end
    if text ~= nil and fontString.SetText then
        local ok, current = false, nil
        if fontString.GetText then ok, current = pcall(fontString.GetText, fontString) end
        local editable = fontString.GetObjectType and fontString:GetObjectType() == "EditBox"
        -- Do not fire editable OnTextChanged on every warm-up pass. Restore a
        -- draft only if a native font mutation actually discarded its text.
        if not (issecretvalue and issecretvalue(current))
            and (not ok or current ~= text or (fontChanged and not editable)) then
            pcall(fontString.SetText, fontString, text)
        end
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
    local path = ResolveFont(10, "REGULAR").path
    return path == FALLBACK and "Blizzard Arial Narrow" or "Expressway", path
end

RA:RegisterEvent("ADDON_LOADED", function() RA:InvalidateFontCache() end)
RA:RegisterEvent("PLAYER_LOGIN", function() RA:InvalidateFontCache() end)
