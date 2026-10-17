local L = _G.yTools.L
local yTools = _G.yTools

local module = yTools:RegisterModule(
	"LuaErrors",
	{
		title = L.UI_HIDE_LUA_ERRORS,
		description = L.ACTIVATE_TO_HIDE_LUA_ERRORS,
		defaultEnabled = true,
	}
)

------------------------------------------------------------
-- Update
------------------------------------------------------------

local function Update()
	if module:IsEnabled() then
		SetCVar("scriptErrors", 0)
	else
		SetCVar("scriptErrors", 1)
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

module:RegisterEvent("ADDON_LOADED", function()
	Update()
end)
