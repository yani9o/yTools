local L = _G.yTools.L
local yTools = _G.yTools

local module = yTools:RegisterModule(
    "StanceBar",
    {
        title = L.ACTIONBARS_HIDE_STANCEBAR,
        description = L.HIDES_THE_STANCEBAR,
        defaultEnabled = false,
    }
)

------------------------------------------------------------
-- Update
------------------------------------------------------------

local function Update()
    if not StanceBar then
        return
    end

    if InCombatLockdown() then
        return
    end

    if module:IsEnabled() then
        StanceBar:SetAlpha(0)
		StanceBar:EnableMouse(false)

        if not module.StanceHooked then
            hooksecurefunc(StanceBar, "Show", function(self)
                if module:IsEnabled() and not InCombatLockdown() then
                    self:SetAlpha(0)
                end
            end)

            module.StanceHooked = true
        end
    else
        StanceBar:SetAlpha(1)
		StanceBar:EnableMouse(true)
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