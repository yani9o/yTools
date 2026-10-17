local L = _G.yTools.L
local yTools = _G.yTools

local module = yTools:RegisterModule(
	"MacroText",
	{
		title = L.ACTIONBARS_HIDE_MACRO_TEXT,
		description = L.HIDES_THE_MACRO_NAME_TEXT_DISPLAYED_ON_ACTION_BAR_BUTTONS,
		defaultEnabled = true,
	}
)


------------------------------------------------------------
-- Update macro text visibility
------------------------------------------------------------

local function UpdateMacroText()
    if InCombatLockdown() then
        return
    end

    local alpha = module:IsEnabled() and 0 or 1

    local bars = {
        "ActionButton",
        "MultiBarBottomLeftButton",
        "MultiBarBottomRightButton",
        "MultiBarRightButton",
        "MultiBarLeftButton",
        "BonusActionButton",
    }

    for _, bar in ipairs(bars) do
        for i = 1, 12 do
            local name = _G[bar .. i .. "Name"]

            if name then
                name:SetAlpha(alpha)
            end
        end
    end
end


------------------------------------------------------------
-- Module lifecycle
------------------------------------------------------------

function module:OnEnable()
    UpdateMacroText()
end


function module:OnDisable()
    UpdateMacroText()
end


------------------------------------------------------------
-- Events
------------------------------------------------------------

module:RegisterEvent("PLAYER_LOGIN", function()
    UpdateMacroText()
end)

module:RegisterEvent("ACTIONBAR_SLOT_CHANGED", function()
    UpdateMacroText()
end)

module:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    UpdateMacroText()
end)
