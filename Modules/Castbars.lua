local L = _G.yTools.L
local yTools = _G.yTools

local module = yTools:RegisterModule(
	"CastBars",
	{
		title = L.UNITFRAMES_CAST_BAR_POSITIONS,
		description = L.LOCKS_THE_TARGET_AND_FOCUS_CAST_BARS_TO_CUSTOM_POSITIONS,
		defaultEnabled = true,
        defaults = { targetY = 200, focusY = 50 },
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
			TargetFrameSpellBar:SetPoint("CENTER", UIParent, "CENTER", 0, module:GetDB().targetY)
		end

		if FocusFrameSpellBar then
			FocusFrameSpellBar:ClearAllPoints()
			FocusFrameSpellBar:SetPoint("BOTTOM", TargetFrameSpellBar, "TOP", 0, module:GetDB().focusY)
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

function module:CreateOptionsPanel(parentCategory)
    if self.settingsPanel or not parentCategory then return end
    local panel = CreateFrame("Frame")
    panel:Hide(); panel:SetSize(700, 560)
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 32, -24); title:SetText(L.CASTBARS_OPTIONS)
    local details = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    details:SetPoint("TOPLEFT", 32, -64); details:SetWidth(600); details:SetJustifyH("LEFT")
    details:SetText(L.LOCKS_THE_TARGET_AND_FOCUS_CAST_BARS_TO_CUSTOM_POSITIONS)
    local enabled = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    yTools.UI.Check(enabled)
    enabled:SetPoint("TOPLEFT", 400, -18)
    local enabledLabel = enabled:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    enabledLabel:SetPoint("LEFT", enabled, "RIGHT", 5, 0); enabledLabel:SetText(L.MODULE_OPTIONS_ENABLE)
    enabledLabel:ClearAllPoints(); enabledLabel:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -32, -22)
    enabled:ClearAllPoints(); enabled:SetPoint("RIGHT", enabledLabel, "LEFT", -5, 0)
    enabled:SetScript("OnClick", function(button)
        if button:GetChecked() then module:Enable() else module:Disable() end
        panel.RefreshForm()
    end)
    local fields = {}
    local function Coordinate(label, key, y)
        local text = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("TOPLEFT", 32, y); text:SetText(label)
        local input = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        input:SetSize(100, 26); input:SetPoint("TOPLEFT", 38, y-24)
        input:SetAutoFocus(false); input:SetMaxLetters(7)
        local function Save()
            local value = tonumber(input:GetText())
            if value and value == value and math.abs(value) <= 10000 then
                module:GetDB()[key] = value
                Update()
            end
            input:SetText(tostring(module:GetDB()[key]))
        end
        input:SetScript("OnEnterPressed", function() Save(); input:ClearFocus() end)
        input:SetScript("OnEditFocusLost", Save)
        input:SetScript("OnEscapePressed", function() input:SetText(tostring(module:GetDB()[key])); input:ClearFocus() end)
        fields[key] = input
    end
    Coordinate(L.CASTBARS_TARGET_Y, "targetY", -140)
    Coordinate(L.CASTBARS_FOCUS_Y, "focusY", -214)
    panel.RefreshForm = function()
        enabled:SetChecked(module:IsEnabled())
        for key, input in pairs(fields) do input:SetText(tostring(module:GetDB()[key])); input:SetEnabled(module:IsEnabled()) end
    end
    panel:SetScript("OnShow", panel.RefreshForm)
    self.settingsPanel = panel
    self.settingsCategory = Settings.RegisterCanvasLayoutSubcategory(parentCategory, panel, L.CASTBARS_OPTIONS)
end

module:RegisterSlashCommand("castbars", function()
    yTools:InitializeOptions()
    module:CreateOptionsPanel(yTools.optionsCategory)
    local category = module.settingsCategory
    if category then Settings.OpenToCategory(category.GetID and category:GetID() or category.ID) end
end, L.CASTBARS_COMMAND_HELP)
yTools.commands.castbars.allowDisabled = true
