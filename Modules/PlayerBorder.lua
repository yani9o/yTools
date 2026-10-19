local rawCreateFrame = CreateFrame
local function CreateFrame(kind,name,parent,template)
    local nativeScroll = template == "UIPanelScrollFrameTemplate"
    if nativeScroll then template = nil end
    local f = rawCreateFrame(kind,name,parent,template)
    if nativeScroll then yTools.UI.ScrollFrame(f,parent) end
    if kind == "CheckButton" then yTools.UI.Check(f) end
    return f
end
local L = _G.yTools.L
local yTools = _G.yTools

local module = yTools:RegisterModule(
    "PlayerBorder",
    {
        title = L.UNITFRAMES_PLAYER_BORDER_YTOOLS_PLAYERBORDER,
        description = L.ADDS_A_SELECTABLE_BORDER_TO_THE_PLAYER_FRAME,
        defaultEnabled = true,
    }
)


------------------------------------------------------------
-- Variants
------------------------------------------------------------

local VARIANTS = {
    [0] = {
        key = "default",
        name = L.DEFAULT_DISABLED,
    },

    [1] = {
        key = "silver",
        name = L.SILVER,

        atlas =
            "ui-hud-unitframe-target-portraiton-boss-rare-silver",

        width = 100,
        height = 100,

        point = "LEFT",
        relativePoint = "LEFT",
        x = 0.1,
        y = 0,
    },

    [2] = {
        key = "gold",
        name = L.GOLD,

        atlas =
            "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold",

        width = 100,
        height = 100,

        point = "LEFT",
        relativePoint = "LEFT",
        x = 0,
        y = 0,
    },

    [3] = {
        key = "winged-silver",
        name = L.SILVER_WINGS,

        atlas =
            "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Silver-Winged",

        width = 109,
        height = 88.5,

        point = "LEFT",
        relativePoint = "LEFT",
        x = -7.36669,
        y = -2.315,
    },

    [4] = {
        key = "winged-gold",
        name = L.GOLD_WINGS,

        atlas =
            "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold-Winged",

        width = 110,
        height = 90,

        point = "LEFT",
        relativePoint = "LEFT",
        x = -10.8,
        y = 0,
    },
}


------------------------------------------------------------
-- Lookup tables
------------------------------------------------------------

local KEY_TO_STYLE = {}

for style, variant in pairs(VARIANTS) do
    KEY_TO_STYLE[variant.key] = style
end


------------------------------------------------------------
-- Local state
------------------------------------------------------------

local chain


------------------------------------------------------------
-- Database
------------------------------------------------------------

local function GetDB()
    return module:GetDB()
end


------------------------------------------------------------
-- Current style
------------------------------------------------------------

local function GetCurrentStyle()
    local DB = GetDB()
    local value = DB.variant

    --------------------------------------------------------
    -- String value
    --------------------------------------------------------

    if type(value) == "string" then
        local style =
            KEY_TO_STYLE[value:lower()]

        if style then
            return style
        end
    end

    --------------------------------------------------------
    -- Numeric value
    --------------------------------------------------------

    if type(value) == "number"
        and VARIANTS[value]
    then
        return value
    end

    --------------------------------------------------------
    -- Invalid / missing value
    --------------------------------------------------------

    DB.variant = "default"

    return 0
end


------------------------------------------------------------
-- Silver appearance
------------------------------------------------------------

local function UpdateSilverAppearance(style)
    local frameTexture =
        _G.PlayerFrame
        and _G.PlayerFrame.PlayerFrameContainer
        and _G.PlayerFrame.PlayerFrameContainer.FrameTexture

    local levelBackground =
        _G.PlayerFrame
        and _G.PlayerFrame.PlayerFrameContent
        and _G.PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
        and _G.PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.LevelBackgroundCircle
		
	local PvpCircle =
		_G. PlayerFrame
		and _G. PlayerFrame.PlayerFrameContent
		and _G. PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
		and _G. PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.PvpBackgroundCircle

    local isSilver =
        style == 1
        or style == 3

    if frameTexture then
        frameTexture:SetDesaturated(isSilver)
    end

    if levelBackground then
        levelBackground:SetDesaturated(isSilver)
    end

    if PvpCircle then
        PvpCircle:SetDesaturated(isSilver)
	
		if PlayerPVPTimerText then
			PlayerPVPTimerText:ClearAllPoints()
			PlayerPVPTimerText:SetPoint("TOP", PvpCircle, "BOTTOMLEFT", 0, 0)
		end
    end
	
end


------------------------------------------------------------
-- Setup
------------------------------------------------------------

local function SetupChain()
    if not module:IsEnabled() then
        return false
    end

    local container =
        _G.PlayerFrame
        and _G.PlayerFrame.PlayerFrameContainer

    if not container then
        return false
    end

    if not chain then
        chain = container:CreateTexture(
            nil,
            "ARTWORK",
            nil,
            2
        )
    end

    local style =
        GetCurrentStyle()

    --------------------------------------------------------
    -- Normal / disabled
    --------------------------------------------------------

    if style == 0 then
        chain:Hide()

        UpdateSilverAppearance(0)

        return true
    end

    local variant =
        VARIANTS[style]

    if not variant then
        chain:Hide()

        UpdateSilverAppearance(0)

        return false
    end

    --------------------------------------------------------
    -- Texture
    --------------------------------------------------------

    chain:SetAtlas(
        variant.atlas
    )

    --------------------------------------------------------
    -- Size
    --------------------------------------------------------

    chain:SetSize(
        variant.width,
        variant.height
    )

    --------------------------------------------------------
    -- Position
    --------------------------------------------------------

    chain:ClearAllPoints()

    chain:SetPoint(
        variant.point,
        container,
        variant.relativePoint,
        variant.x,
        variant.y
    )

    --------------------------------------------------------
    -- Mirror horizontally
    --------------------------------------------------------

    chain:SetTexCoord(
        1, 0,
        0, 1
    )

    chain:Show()

    --------------------------------------------------------
    -- Update player frame colors
    --------------------------------------------------------

    UpdateSilverAppearance(style)

    return true
end


------------------------------------------------------------
-- Print options
------------------------------------------------------------

local function PrintOptions()
    yTools:Print(
        L.CFF00CCFF_YTOOLS_PORTRAIT_BORDER_R
    )

    yTools:Print(
        "|cff00ff00/ytools playerborder options|r -> "
        .. L.PLAYERBORDER_OPTIONS_COMMAND_HELP
    )

    yTools:Print(
        "|cff00ff00/ytools playerborder |cffffff00x|r"
    )

    for style = 0, 4 do
        local variant =
            VARIANTS[style]

        yTools:Print(
            "|cffffff00"
            .. style
            .. " | "
            .. variant.key
            .. "|r - "
            .. variant.name
        )
    end

    local current =
        GetCurrentStyle()

    local variant =
        VARIANTS[current]

    yTools:Print(
        L.CFF00FF00CURRENT_R
        .. current
        .. " | "
        .. variant.key
        .. " - "
        .. variant.name
    )
end


------------------------------------------------------------
-- Set style
------------------------------------------------------------

local function SetStyle(value)
    local style

    --------------------------------------------------------
    -- Numeric value
    --------------------------------------------------------

    local number =
        tonumber(value)

    if number
        and number == math.floor(number)
        and VARIANTS[number]
    then
        style = number
    else
        ----------------------------------------------------
        -- String value
        ----------------------------------------------------

        local key =
            tostring(value):lower()

        style =
            KEY_TO_STYLE[key]
    end

    if not style then
        yTools:Print(
            "|cffff0000yTools:|r "
            .. L.UNKNOWN_PORTRAIT_BORDER
            .. tostring(value)
        )

        PrintOptions()

        return
    end

    local DB = GetDB()
    local variant = VARIANTS[style]

    --------------------------------------------------------
    -- Store canonical string value.
    --------------------------------------------------------

    DB.variant = variant.key

    SetupChain()

    yTools:Print(
        "|cff00ff00yTools:|r "
        .. L.PORTRAIT_BORDER_CHANGED_TO
        .. variant.name
        .. "."
    )
end


------------------------------------------------------------
-- Settings form
------------------------------------------------------------

local settingsPanel, settingsCategory

function module:CreateOptionsPanel(parentCategory)
    if settingsPanel or not parentCategory or not Settings
        or not Settings.RegisterCanvasLayoutSubcategory then return end
    local panel = CreateFrame("Frame")
    panel:SetSize(700, 560)
    settingsPanel = panel
    self.settingsPanel = panel

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 32, -24)
    title:SetText(L.PLAYER_BORDER)
    local enable = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    enable:SetPoint("TOPLEFT", 400, -18)
    local enableLabel = enable:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    enableLabel:SetPoint("LEFT", enable, "RIGHT", 2, 0)
    enableLabel:SetText(L.MODULE_OPTIONS_ENABLE)
    enableLabel:ClearAllPoints(); enableLabel:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -32, -22)
    enable:ClearAllPoints(); enable:SetPoint("RIGHT", enableLabel, "LEFT", -5, 0)
    panel.enable = enable

    local controls = CreateFrame("Frame", nil, panel)
    controls:SetAllPoints(panel)
    panel.controls = controls
    local description = controls:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    description:SetPoint("TOPLEFT", 32, -64)
    description:SetText(L.CHOOSE_THE_BORDER_AROUND_YOUR_PLAYER_PORTRAIT_CHANGES_APPLY_IMMEDIATELY)
    local label = controls:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 32, -110)
    label:SetText(L.BORDER_STYLE)
    local dropdown = CreateFrame("DropdownButton", nil, controls, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("TOPLEFT", 32, -132)
    dropdown:SetSize(220,26)
    panel.styleDropdown = dropdown

    local function RefreshForm()
        enable:SetChecked(module:IsEnabled())
        controls:SetShown(module:IsEnabled())
        dropdown:SetDefaultText(VARIANTS[GetCurrentStyle()].name)
    end
    panel.RefreshForm = RefreshForm
    dropdown:SetupMenu(function(_,root)
        for style = 0,4 do
            local value=style
            root:CreateRadio(VARIANTS[value].name,function()return GetCurrentStyle()==value end,function()
                if not module:IsEnabled() then return end
                SetStyle(value)
                RefreshForm()
            end)
        end
    end)
    enable:SetScript("OnClick", function(self)
        if self:GetChecked() then module:Enable() else module:Disable() end
        RefreshForm()
    end)
    panel:SetScript("OnShow", RefreshForm)
    settingsCategory = Settings.RegisterCanvasLayoutSubcategory(parentCategory, panel, L.PLAYER_BORDER)
    RefreshForm()
end

function module:OpenOptionsPanel()
    yTools:CreateOptionsPanel()
    self:CreateOptionsPanel(yTools.optionsCategory)
    if settingsCategory and Settings.OpenToCategory then
        Settings.OpenToCategory(settingsCategory:GetID())
    end
end


------------------------------------------------------------
-- Disable
------------------------------------------------------------

local function DisableChain()
    if chain then
        chain:Hide()
    end

    --------------------------------------------------------
    -- Always restore the normal player-frame colors.
    --------------------------------------------------------

    UpdateSilverAppearance(0)
end


------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------

function module:OnEnable()
    SetupChain()
    if settingsPanel then settingsPanel.RefreshForm() end
end


function module:OnDisable()
    DisableChain()
    if settingsPanel then settingsPanel.RefreshForm() end
end


------------------------------------------------------------
-- Events
------------------------------------------------------------

module:RegisterEvent(
    "PLAYER_ENTERING_WORLD",
    function()
        SetupChain()
    end
)


------------------------------------------------------------
-- Slash command
------------------------------------------------------------

module:RegisterSlashCommand(
    "playerborder",
    function(_, arguments)
        if arguments == nil
            or type(arguments) ~= "string"
        then
            PrintOptions()
            return
        end

        arguments = string.match(
            arguments,
            "^%s*(.-)%s*$"
        )

        local subcommand = arguments:lower()
        if subcommand == "ui" or subcommand == "options" or subcommand == "config" then
            module:OpenOptionsPanel()
            return
        end

        if arguments == "" then
            PrintOptions()
            return
        end

        SetStyle(arguments)
    end,
    L.SHOW_OR_CHANGE_PLAYERFRAME_BORDER
)

yTools.commands.playerborder.allowDisabled = function(arguments)
    local command = (arguments or ""):match("^%s*(.-)%s*$"):lower()
    return command == "ui" or command == "options" or command == "config"
end
