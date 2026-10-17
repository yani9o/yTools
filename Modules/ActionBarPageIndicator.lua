local L = _G.yTools.L
local yTools = _G.yTools

local module = yTools:RegisterModule(
	"ActionBarPageIndicator",
	{
		title = L.ACTIONBARS_HIDE_PAGE_INDICATOR,
		description = L.HIDES_THE_ACTION_BAR_PAGE_INDICATOR,
		defaultEnabled = true,
	}
)


------------------------------------------------------------
-- Update
------------------------------------------------------------

local hooked = setmetatable({}, {__mode = "k"})

local function Update()
    if not MainActionBar
        or not MainActionBar.ActionBarPageNumber
    then
        return
    end

    local indicator = MainActionBar.ActionBarPageNumber
    if not hooked[indicator] then
        hooked[indicator] = true
        -- OnShow also covers SetShown(true) and a hidden parent becoming visible.
        indicator:HookScript("OnShow", function(self)
            if module:IsEnabled() then
                self:Hide()
            end
        end)
    end

    if module:IsEnabled() then
        indicator:Hide()
    else
        indicator:Show()
    end
end


------------------------------------------------------------
-- Module lifecycle
------------------------------------------------------------

function module:OnEnable()
    Update()
end


function module:OnDisable()
    Update()
end


------------------------------------------------------------
-- Events
------------------------------------------------------------

module:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    Update()
end)

module:RegisterEvent("ADDON_LOADED",function()
    Update()
end)

module:RegisterEvent("ACTIONBAR_PAGE_CHANGED", function()
    Update()
end)
