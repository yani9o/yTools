local yTools = _G.yTools
local L = yTools.L
local module = yTools:RegisterModule("CharacterInfoPanel", {
    title = L.UI_CHARACTER_INFO_PANEL,
    description = L.CHARACTER_INFO_PANEL_DESCRIPTION,
    defaultEnabled = true,
})

local CVAR = "characterFrameCollapsed"
local hookedFrame, pending

local function Apply()
    if InCombatLockdown() then return end
    local active = module:IsEnabled()
    if active then
        local db = module:GetDB()
        if db.originalValue == nil then db.originalValue = GetCVar(CVAR) end
        if GetCVar(CVAR) ~= "0" then SetCVar(CVAR, "0") end
    end
    local frame = CharacterFrame
    local button = frame and frame.RightPaneToggleButton
    if button then
        -- Only change widget presentation/input. Calling SetRightPaneCollapsed
        -- from addon execution taints state later read by CharacterFrame:OnShow.
        -- Blizzard reads the CVar when initializing the frame on the next reload.
        local canClick = not active or frame:IsRightPaneCollapsed()
        button:SetEnabled(canClick)
        button:SetAlpha(canClick and 1 or 0)
    end
end

local function QueueApply()
    if pending then return end
    pending = true
    C_Timer.After(0, function() pending = false; Apply() end)
end

local function Install()
    local frame = CharacterFrame
    if not frame or not frame.SetRightPaneCollapsed or hookedFrame == frame then return end
    hookedFrame = frame
    hooksecurefunc(frame, "SetRightPaneCollapsed", QueueApply)
    frame:HookScript("OnShow", QueueApply)
    QueueApply()
end

function module:OnEnable() Install(); QueueApply() end
function module:OnDisable()
    local db = self:GetDB()
    if db.originalValue ~= nil then
        SetCVar(CVAR, db.originalValue)
        db.originalValue = nil
    end
    QueueApply()
end
module:RegisterEvent("ADDON_LOADED", Install)
module:RegisterEvent("PLAYER_ENTERING_WORLD", function() Install(); QueueApply() end)
module:RegisterEvent("PLAYER_REGEN_ENABLED", QueueApply)
