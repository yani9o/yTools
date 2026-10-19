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
local dragging = false
local StopDragging


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
    FramerateFrame:EnableMouse(module:IsEnabled() and not GetDB().locked)


	--------------------------------------------------------
	-- Position
	--------------------------------------------------------

	if module:IsEnabled() then
		----------------------------------------------------
		-- yTools position
		----------------------------------------------------

		FramerateFrame:ClearAllPoints()

        local position = GetDB().position or {"TOPLEFT", "TOPLEFT", 1, -1}
        FramerateFrame:SetPoint(position[1], UIParent, position[2], position[3], position[4])

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
    FramerateFrame:SetMovable(true)
    FramerateFrame:SetClampedToScreen(true)
    FramerateFrame:EnableMouse(module:IsEnabled() and not GetDB().locked)
    FramerateFrame:RegisterForDrag("LeftButton")
    FramerateFrame:HookScript("OnDragStart", function(frame)
        if not module:IsEnabled() or GetDB().locked then return end
        dragging = true
        frame:StartMoving()
    end)
    StopDragging = function(frame)
        if not dragging then return end
        frame:StopMovingOrSizing()
        dragging = false
        local point, _, relativePoint, x, y = frame:GetPoint()
        GetDB().position = {point, relativePoint, x, y}
    end
    FramerateFrame:HookScript("OnDragStop", StopDragging)
    FramerateFrame:HookScript("OnHide", StopDragging)
    FramerateFrame:HookScript("OnShow", function() if not updating then SaveVisibility() end end)
    FramerateFrame:HookScript("OnHide", function() if not updating then SaveVisibility() end end)

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

module:RegisterSlashCommand("framerate", function(_, arguments)
    if not FramerateFrame then return end
    if arguments:lower():match("^reset%s*$") then
        GetDB().position = nil
        Update()
        yTools:Print(L.FRAMERATE_RESET_DONE)
    elseif arguments:lower():match("^toggle%s*$") then
        FramerateFrame:SetShown(not FramerateFrame:IsShown())
        SaveVisibility()
    elseif arguments:lower():match("^lock%s*$") then
        local db = GetDB()
        db.locked = not db.locked
        if db.locked and StopDragging then StopDragging(FramerateFrame) end
        FramerateFrame:EnableMouse(not db.locked)
        yTools:Print(db.locked and L.FRAMERATE_LOCKED or L.FRAMERATE_UNLOCKED)
    else
        yTools:Print(L.FRAMERATE_LOCK_HELP)
        yTools:Print(L.FRAMERATE_TOGGLE_HELP)
        yTools:Print(L.FRAMERATE_RESET_HELP)
    end
end, L.FRAMERATE_COMMAND_HELP)
