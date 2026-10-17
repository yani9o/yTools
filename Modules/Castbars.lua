local L = _G.yTools.L
local yTools = _G.yTools

local module = yTools:RegisterModule(
	"CastBars",
	{
		title = L.UNITFRAMES_CAST_BAR_POSITIONS,
		description = L.LOCKS_THE_TARGET_AND_FOCUS_CAST_BARS_TO_CUSTOM_POSITIONS,
		defaultEnabled = true,
	}
)

local isMovingCastBars = false

------------------------------------------------------------
-- Update
------------------------------------------------------------

local function Update()
	if isMovingCastBars then return end
	isMovingCastBars = true

	if module:IsEnabled() then
		if TargetFrameSpellBar then
			TargetFrameSpellBar:ClearAllPoints()
			TargetFrameSpellBar:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
		end

		if FocusFrameSpellBar then
			FocusFrameSpellBar:ClearAllPoints()
			FocusFrameSpellBar:SetPoint("BOTTOM", TargetFrameSpellBar, "TOP", 0, 50)
		end
	else
		if TargetFrameSpellBar then
			TargetFrameSpellBar:ClearAllPoints()
			TargetFrameSpellBar:SetPoint("TOPLEFT", TargetFrame, "BOTTOMLEFT", 43, 5)
		end
		if FocusFrameSpellBar then
			FocusFrameSpellBar:ClearAllPoints()
			FocusFrameSpellBar:SetPoint("TOPLEFT", FocusFrame, "BOTTOMLEFT", 43, 5)
		end
	end

	isMovingCastBars = false
end

------------------------------------------------------------
-- Hooks
------------------------------------------------------------

if CastingBarFrame then hooksecurefunc(CastingBarFrame, "SetPoint", Update) end
if TargetFrameSpellBar then hooksecurefunc(TargetFrameSpellBar, "SetPoint", Update) end
if FocusFrameSpellBar then hooksecurefunc(FocusFrameSpellBar, "SetPoint", Update) end

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
