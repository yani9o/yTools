local L = _G.yTools.L
local module = _G.yTools:RegisterModule(
	"CastOnKeyRelease", {
		title = L.ACTIONBARS_CAST_ON_KEY_RELEASE,
		description = L.ENABLED_CAST_ON_KEY_RELEASE_DISABLED_CAST_ON_KEY_PRESS,
		defaultEnabled = true,
	}
)

local CVAR = "ActionButtonUseKeyDown"
local pending = false
local combatEvents = CreateFrame("Frame")
combatEvents:RegisterEvent("PLAYER_REGEN_ENABLED")

local function Apply()
    -- Apply protected action-button settings after combat, including a disable
    -- requested while fighting.
    if InCombatLockdown() then pending = true; return end
    pending = false
    local value = module:IsEnabled() and "0" or "1"
    if GetCVar(CVAR) ~= value then
        SetCVar(CVAR, value)
    end
end
combatEvents:SetScript("OnEvent", function() if pending then Apply() end end)

function module:OnEnable()
    -- Clear the saved restoration value from earlier versions.
    self:GetDB().originalValue = nil
    Apply()
end

function module:OnDisable()
    self:GetDB().originalValue = nil
    Apply()
end

module:RegisterEvent("PLAYER_ENTERING_WORLD", Apply)
module:RegisterEvent("CVAR_UPDATE", function(_, _, name)
    if type(name) == "string" and name:lower() == CVAR:lower() then Apply() end
end)
