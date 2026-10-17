local L = _G.yTools.L
local yTools = _G.yTools

local pending = false
local originalAlpha = setmetatable({}, {__mode = "k"})
local combatEvents = CreateFrame("Frame")
combatEvents:RegisterEvent("PLAYER_REGEN_ENABLED")

local module = yTools:RegisterModule(
    "BuffList",
    {
        title = L.AURAS_HIDE_BUFF_LIST_BUTTON,
        description = L.HIDES_THE_BUFF_LIST_COLLAPSE_AND_EXPAND_BUTTON,
        defaultEnabled = true,
    }
)


------------------------------------------------------------
-- Show
------------------------------------------------------------

local function ShowBuffButton()
    local button = BuffFrame and BuffFrame.CollapseAndExpandButton
    if button and originalAlpha[button] ~= nil then
        button:SetAlpha(originalAlpha[button])
        originalAlpha[button] = nil
    end
    if InCombatLockdown() then pending = true; return end
    pending = false
    local buffButton =
        BuffFrame
        and BuffFrame.CollapseAndExpandButton

    if buffButton then
        buffButton:Show()
    end
end


------------------------------------------------------------
-- Hide
------------------------------------------------------------

local hooked = setmetatable({}, {__mode = "k"})

local function HideBuffButton()
    if not module:IsEnabled() then
        return
    end

    local buffButton =
        BuffFrame
        and BuffFrame.CollapseAndExpandButton

    if not buffButton then
        return
    end

    if not hooked[buffButton] then
        hooked[buffButton] = true
        -- Blizzard also uses SetShown; hooking only Show misses that path.
        buffButton:HookScript("OnShow", function(self)
            if module:IsEnabled() then
                self:SetAlpha(0)
                if InCombatLockdown() then
                    pending = true
                else
                    self:Hide()
                end
            end
        end)
    end

    -- Aura updates can show this protected button in combat. Alpha can be
    -- changed without changing protected visibility; defer only Hide/Show.
    if originalAlpha[buffButton] == nil then
        originalAlpha[buffButton] = buffButton:GetAlpha()
    end
    buffButton:SetAlpha(0)
    if InCombatLockdown() then pending = true; return end
    pending = false
    buffButton:Hide()
end

-- Keep restoration working after a combat-time disable removes module events.
combatEvents:SetScript("OnEvent", function()
    if not pending then return end
    if module:IsEnabled() then HideBuffButton() else ShowBuffButton() end
end)


------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------

function module:OnEnable()
    HideBuffButton()
end


function module:OnDisable()
    ShowBuffButton()
end


------------------------------------------------------------
-- Events
------------------------------------------------------------

module:RegisterEvent("PLAYER_ENTERING_WORLD",function()
    HideBuffButton()
end)

module:RegisterEvent("ADDON_LOADED",function()
    HideBuffButton()
end)

module:RegisterEvent("UNIT_AURA",function(_, _, unit)
	if unit == "player" then
		HideBuffButton()
	end
end)
