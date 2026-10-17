local L = _G.yTools.L
local yTools = _G.yTools

local module = yTools:RegisterModule(
    "HitIndicator",
    {
        title = L.UNITFRAMES_HIDE_HIT_INDICATOR,
        description = L.HIDES_THE_HIT_INDICATOR_ON_PLAYERFRAME,
        defaultEnabled = true,
    }
)


------------------------------------------------------------
-- Update
------------------------------------------------------------

local function Update()
    local main = PlayerFrame and PlayerFrame.PlayerFrameContent
        and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
    local indicators = {}
    if main and main.HitIndicator then indicators[#indicators + 1] = main.HitIndicator end
    if PetHitIndicator then indicators[#indicators + 1] = PetHitIndicator end
    for _, indicator in ipairs(indicators) do
        -- Native combat feedback may show the text again after an event.
        if not indicator.yToolsHooked then
            indicator.yToolsHooked = true
            hooksecurefunc(indicator, "Show", function()
                if module:IsEnabled() then indicator:Hide() end
            end)
        end
        if module:IsEnabled() then indicator:Hide() end
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
module:RegisterEvent("UNIT_PET", Update)
