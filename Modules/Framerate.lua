local L = _G.yTools.L
local yTools = _G.yTools

local module = yTools:RegisterModule(
	"Framerate",
	{
		title = L.UI_FRAMERATE,
		description = L.REPOSITION_FRAMERATE_TO_TOP_LEFT,
		defaultEnabled = true,
	}
)


------------------------------------------------------------
-- Local state
------------------------------------------------------------

local updating = false


------------------------------------------------------------
-- Database
------------------------------------------------------------

local function GetDB()
	return module:GetDB()
end


------------------------------------------------------------
-- Initialize saved visibility
------------------------------------------------------------

local function InitializeVisibility()
	if not FramerateFrame then
		return
	end

	local DB = GetDB()

	if DB.visible == nil then
		DB.visible = FramerateFrame:IsShown()
	end
end


------------------------------------------------------------
-- Save visibility
------------------------------------------------------------

local function SaveVisibility()
	if not FramerateFrame then
		return
	end

	local DB = GetDB()

	local visible =
		FramerateFrame:IsShown()

	DB.visible = visible
end


------------------------------------------------------------
-- Restore visibility
------------------------------------------------------------

local function RestoreVisibility()
	if not FramerateFrame then
		return
	end

	local DB = GetDB()

	--------------------------------------------------------
	-- Make sure there is always a value.
	--------------------------------------------------------

	if DB.visible == nil then
		InitializeVisibility()
	end

	if DB.visible then
		FramerateFrame:Show()
	else
		FramerateFrame:Hide()
	end
end


------------------------------------------------------------
-- Update
------------------------------------------------------------

local function Update()
	if not FramerateFrame then
		return
	end

	updating = true


	--------------------------------------------------------
	-- Position
	--------------------------------------------------------

	if module:IsEnabled() then
		----------------------------------------------------
		-- yTools position
		----------------------------------------------------

		FramerateFrame:ClearAllPoints()

		FramerateFrame:SetPoint(
			"TOPLEFT",
			UIParent,
			"TOPLEFT",
			1,
			-1
		)

		FramerateFrame:SetScale(0.75)

	else
		----------------------------------------------------
		-- Blizzard position
		----------------------------------------------------

		FramerateFrame:ClearAllPoints()

		FramerateFrame:SetPoint(
			"BOTTOMRIGHT",
			UIParent,
			"BOTTOMRIGHT",
			-2,
			2
		)

		FramerateFrame:SetScale(1)
	end


	--------------------------------------------------------
	-- Restore visibility
	--------------------------------------------------------

	RestoreVisibility()


	updating = false
end


------------------------------------------------------------
-- Hook visibility changes
------------------------------------------------------------

local function HookVisibility()
	if not FramerateFrame then
		return
	end

	if FramerateFrame.yToolsVisibilityHooked then
		return
	end

	FramerateFrame.yToolsVisibilityHooked = true

	hooksecurefunc(
		FramerateFrame,
		"SetShown",
		function()
			if updating then
				return
			end

			SaveVisibility()
		end
	)
end


------------------------------------------------------------
-- Module lifecycle
------------------------------------------------------------

function module:OnEnable()
	if not FramerateFrame then
		return
	end

	HookVisibility()
	InitializeVisibility()
	Update()
end


function module:OnDisable()
	Update()
end


------------------------------------------------------------
-- Events
------------------------------------------------------------

module:RegisterEvent(
	"PLAYER_ENTERING_WORLD",
	function()
		if not FramerateFrame then
			return
		end

		HookVisibility()
		InitializeVisibility()
		Update()
	end
)


module:RegisterEvent(
	"ADDON_LOADED",
	function()
		if not FramerateFrame then
			return
		end

		HookVisibility()
		InitializeVisibility()
		Update()
	end
)
