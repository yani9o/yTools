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

-- Capture the original call path once per minute for yTools blocks. Repeated
-- chat notifications alone cannot identify which native path was tainted.
local lastBlockedAt = -math.huge
module:RegisterEvent("ADDON_ACTION_BLOCKED", function(_, _, addonName, action)
    if (issecretvalue and (issecretvalue(addonName) or issecretvalue(action)))
        or addonName ~= yTools.name or type(action) ~= "string" or not debugstack then return end
    local now = GetTime()
    if now - lastBlockedAt < 60 then return end
    lastBlockedAt = now
    local stack = debugstack(2, 12, 0)
    yTools.lastBlockedAction = {action = action, stack = stack}
    yTools:Print(string.format(L.BLOCKED_ACTION_TRACE, action, stack))
end)
