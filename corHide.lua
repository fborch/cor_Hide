-- corHide.lua
-- Hides registered UI frames unless: in combat, targeting an attackable unit,
-- grouped, or inside a dungeon / delve / raid instance.

corHide = {}
local CH = corHide

local DB_DEFAULTS = { frames = {}, conditionalFrames = {} }

-- Returns true when at least one condition requires the frames to be visible.
local function ShouldShowFrames()
    -- In combat
    if UnitAffectingCombat("player") then
        return true
    end

    -- Targeting something the player can attack
    if UnitExists("target") and UnitCanAttack("player", "target") then
        return true
    end

    -- In a party or raid group
    if IsInGroup() or IsInRaid() then
        return true
    end

    -- Inside a dungeon, raid, delve (scenario), or any matchmade instance
    local _, instanceType = GetInstanceInfo()
    if instanceType == "party"
    or instanceType == "raid"
    or instanceType == "scenario"   -- delves, brawler's guild, etc.
    or instanceType == "pvp" then
        return true
    end

    return false
end

-- Tracks which condition frames have already been hooked to avoid duplicates.
local hookedFrames = {}

local function TryHookConditionalFrame(conditionFrameName)
    if hookedFrames[conditionFrameName] then return end
    local frame = _G[conditionFrameName]
    if frame then
        frame:HookScript("OnShow", function() CH.UpdateFrames() end)
        frame:HookScript("OnHide", function() CH.UpdateFrames() end)
        hookedFrames[conditionFrameName] = true
    end
end

-- Apply visibility to every registered frame name.
function CH.UpdateFrames()
    if not corHideDB then return end

    -- Standard frames: shown/hidden based on combat / group / instance / target.
    local show = ShouldShowFrames()
    for frameName in pairs(corHideDB.frames) do
        local frame = _G[frameName]
        if frame then
            if show then frame:Show() else frame:Hide() end
        end
    end

    -- Conditional frames: hide target whenever its condition frame is visible,
    -- regardless of any other conditions.
    for targetName, conditionName in pairs(corHideDB.conditionalFrames) do
        TryHookConditionalFrame(conditionName)
        local target    = _G[targetName]
        local condition = _G[conditionName]
        if target and condition then
            if condition:IsShown() then
                target:Hide()
            else
                target:Show()
            end
        end
    end
end

function CH.RegisterConditionalFrame(targetName, conditionName)
    corHideDB.conditionalFrames[targetName] = conditionName
    TryHookConditionalFrame(conditionName)
    CH.UpdateFrames()
end

function CH.UnregisterConditionalFrame(targetName)
    corHideDB.conditionalFrames[targetName] = nil
    CH.UpdateFrames()
end

-- ── Event handling ────────────────────────────────────────────────────────────

local eventFrame = CreateFrame("Frame")

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")   -- entered combat
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")    -- left combat
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= "corHide" then return end

        -- Initialise / migrate saved variables
        if not corHideDB then
            corHideDB = CopyTable(DB_DEFAULTS)
        end
        if not corHideDB.frames then
            corHideDB.frames = {}
        end
        if not corHideDB.conditionalFrames then
            corHideDB.conditionalFrames = {}
        end
    else
        CH.UpdateFrames()
    end
end)

-- ── Slash commands ────────────────────────────────────────────────────────────

SLASH_CORHIDE1 = "/corhide"
SLASH_CORHIDE2 = "/ch"

SlashCmdList["CORHIDE"] = function()
    corHide_GUI:Toggle()
end
