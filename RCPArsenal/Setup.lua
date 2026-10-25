local _, RA = ...
local Setup = {}
RA.Setup = Setup
-- Retain installation metadata and the saved presentation role. The staged
-- editor is retired: no draft, profile reference, return route, or save path.
local function Metadata()
    if not RaidArsenalDB then return nil end
    if type(RaidArsenalDB.setup) ~= "table" then
        RaidArsenalDB.setup = {completed = RA.WasExistingInstall == true, role = "RAIDER"}
    end
    RaidArsenalDB.setup.returnTab = nil
    return RaidArsenalDB.setup
end
function Setup:IsFirstRunPending()
    local state = Metadata()
    return state and state.completed ~= true and state.presented ~= true or false
end
function Setup:PresentIntroduction()
    local state = Metadata()
    if state then state.presented = true end
end
function Setup:GetRole()
    local state = Metadata()
    return state and state.role == "LEADER" and "LEADER" or "RAIDER"
end
function Setup:HasDraft() return false end
RA:RegisterInitializer(Metadata)
