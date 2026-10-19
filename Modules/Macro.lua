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
    "Macro",
    {
        title = L.UTILITIES_MACRO_MANAGER_YTOOLS_MACRO,
        description = L.MACRO_DESCRIPTION,
        defaultEnabled = true,
    }
)


------------------------------------------------------------
-- Constants
------------------------------------------------------------

local MACRO_FRAME_WIDTH = 450
local MACRO_FRAME_HEIGHT = 150

local MACRO_LEFT = 16
local MACRO_TOP = 38
local MACRO_RIGHT = 16
local MACRO_BOTTOM = 16

local MACRO_FRAME_OFFSET_Y = -200

local MACRO_DEFAULT_ICON =
    "INV_Misc_QuestionMark"

local MACRO_MAX_LENGTH = 255


------------------------------------------------------------
-- Local state
------------------------------------------------------------

local macroFrame
local macroEditBox
local macroClickOverlay


------------------------------------------------------------
-- Macro generation
------------------------------------------------------------

local function GenerateHarmMacro(spell, focusModifier)
    focusModifier = focusModifier or "shift"

    return
        "#showtooltip\n"
        .. "/cast [mod:" .. focusModifier .. ",@focus,harm][@mouseover,harm,nodead][]"
        .. spell
end


local function GenerateHelpMacro(spell, focusModifier, playerModifier)
    focusModifier = focusModifier or "shift"
    playerModifier = playerModifier or "ctrl/shift"

    return
        "#showtooltip\n"
        .. "/cast [mod:" .. focusModifier .. ",@focus,help][mod:" .. playerModifier .. ",@player]"
        .. "[@mouseover,help,nodead][]"
        .. spell
end


local function GenerateHybridMacro(
    harmSpell,
    helpSpell,
    focusModifier,
    playerModifier
)
    focusModifier = focusModifier or "shift"
    playerModifier = playerModifier or "ctrl/shift"

    return
        "#showtooltip\n"
        .. "/cast "
        .. "[mod:" .. focusModifier .. ",@focus,harm]"
        .. "[@mouseover,harm,nodead,nomod:" .. playerModifier .. "]"
        .. harmSpell
        .. ";"
        .. "[mod:" .. focusModifier .. ",@focus,help]"
        .. "[mod:" .. playerModifier .. ",@player]"
        .. "[@mouseover,help,nodead]"
        .. "[help]"
        .. helpSpell
        .. ";"
        .. harmSpell
end


local function GenerateGeneralMacro(spell, focusModifier, playerModifier)
    focusModifier = focusModifier or "shift"
    playerModifier = playerModifier or "ctrl/shift"
    return "#showtooltip\n/cast [mod:" .. focusModifier .. ",@focus]"
        .. "[mod:" .. playerModifier .. ",@player][@mouseover,nodead,exists][]" .. spell
end


------------------------------------------------------------
-- Usage
------------------------------------------------------------

local function PrintUsage()

    yTools:Print(
        L.CFF00CCFF_YTOOLS_MACRO_MANAGER_R
    )

    yTools:Print(
        L.CFFFFFF00CHARACTER_MACROS_R
    )

    yTools:Print(
        L.MACRO_USAGE_1
    )

    yTools:Print(
        L.MACRO_USAGE_2
    )

    yTools:Print(
        L.MACRO_USAGE_3
    )

    yTools:Print(
        L.CFFFFFF00GENERAL_MACROS_R
    )

    yTools:Print(
        L.MACRO_USAGE_4
    )

    yTools:Print(
        L.MACRO_USAGE_5
    )

    yTools:Print(
        L.MACRO_USAGE_6
    )
end


------------------------------------------------------------
-- Parse quoted arguments
------------------------------------------------------------

local function ParseQuotedArguments(arguments)

    if type(arguments) ~= "string" then
        return nil
    end

    local result = {}

    local position = 1
    local length = #arguments

    while position <= length do

        ----------------------------------------------------
        -- Skip whitespace.
        ----------------------------------------------------

        while position <= length do

            local character =
                arguments:sub(
                    position,
                    position
                )

            if not character:match("%s") then
                break
            end

            position = position + 1
        end


        ----------------------------------------------------
        -- Nothing left.
        ----------------------------------------------------

        if position > length then
            break
        end


        ----------------------------------------------------
        -- Argument must begin with a quote.
        ----------------------------------------------------

        if arguments:sub(
            position,
            position
        ) ~= "\""
        then
            return nil
        end

        position = position + 1


        ----------------------------------------------------
        -- Find closing quote.
        ----------------------------------------------------

        local startPosition =
            position

        local closingQuote

        while position <= length do

            if arguments:sub(
                position,
                position
            ) == "\""
            then

                closingQuote =
                    position

                break
            end

            position = position + 1
        end


        ----------------------------------------------------
        -- Missing closing quote.
        ----------------------------------------------------

        if not closingQuote then
            return nil
        end


        ----------------------------------------------------
        -- Preserve argument exactly as entered.
        ----------------------------------------------------

        local value =
            arguments:sub(
                startPosition,
                closingQuote - 1
            )


        if value == "" then
            return nil
        end


        result[#result + 1] =
            value


        position =
            closingQuote + 1
    end

    return result
end


------------------------------------------------------------
-- Select all macro text
------------------------------------------------------------

local function SelectMacroText()

    if not macroEditBox then
        return
    end

    macroEditBox:SetFocus()

    macroEditBox:SetCursorPosition(
        0
    )

    macroEditBox:HighlightText(
        0,
        -1
    )
end


------------------------------------------------------------
-- Create macro copy window
------------------------------------------------------------

local function CreateMacroFrame()

    if macroFrame then
        return
    end


    --------------------------------------------------------
    -- Main frame
    --------------------------------------------------------

    macroFrame =
        CreateFrame(
            "Frame",
            "yToolsMacroFrame",
            UIParent,
            "BasicFrameTemplateWithInset"
        )

    macroFrame:SetSize(
        MACRO_FRAME_WIDTH,
        MACRO_FRAME_HEIGHT
    )

    macroFrame:SetPoint(
        "CENTER",
        UIParent,
        "CENTER",
        0,
        MACRO_FRAME_OFFSET_Y
    )

    macroFrame:SetFrameStrata(
        "DIALOG"
    )

    macroFrame:SetClampedToScreen(
        true
    )

    macroFrame:EnableMouse(
        false
    )


    --------------------------------------------------------
    -- UISpecialFrames
    --
    -- Escape closes the window even when the EditBox
    -- does not have focus.
    --------------------------------------------------------

    if not macroFrame._addedToUISpecialFrames then

        tinsert(
            UISpecialFrames,
            "yToolsMacroFrame"
        )

        macroFrame._addedToUISpecialFrames = true

    end


    --------------------------------------------------------
    -- Title
    --------------------------------------------------------

    macroFrame.title =
        macroFrame:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontHighlight"
        )

    macroFrame.title:SetPoint(
        "TOPLEFT",
        8,
        -6
    )

    macroFrame.title:SetText(
        L.MACRO_MANAGER
    )


    --------------------------------------------------------
    -- EditBox
    --
    -- Mouse input is disabled so the macro cannot be
    -- selected or modified directly with the mouse.
    --------------------------------------------------------

    macroEditBox =
        CreateFrame(
            "EditBox",
            nil,
            macroFrame
        )

    macroEditBox:SetMultiLine(
        true
    )

    macroEditBox:SetAutoFocus(
        false
    )

    macroEditBox:SetMaxLetters(
        0
    )

    macroEditBox:SetFontObject(
        ChatFontNormal
    )

    macroEditBox:SetTextColor(
        1,
        1,
        1,
        1
    )

    macroEditBox:SetJustifyH(
        "LEFT"
    )

    macroEditBox:SetJustifyV(
        "TOP"
    )

    macroEditBox:SetTextInsets(
        6,
        6,
        6,
        6
    )

    macroEditBox:SetPoint(
        "TOPLEFT",
        macroFrame,
        "TOPLEFT",
        MACRO_LEFT,
        -MACRO_TOP
    )

    macroEditBox:SetPoint(
        "BOTTOMRIGHT",
        macroFrame,
        "BOTTOMRIGHT",
        -MACRO_RIGHT,
        MACRO_BOTTOM
    )

    macroEditBox:EnableMouse(
        false
    )

    macroEditBox:EnableKeyboard(
        true
    )


    --------------------------------------------------------
    -- Escape while EditBox has focus.
    --------------------------------------------------------

    macroEditBox:SetScript(
        "OnEscapePressed",
        function()

            macroEditBox:ClearFocus()

            macroFrame:Hide()

        end
    )


    --------------------------------------------------------
    -- Full-window click overlay
    --
    -- Clicking anywhere on the copy window selects the
    -- complete macro and focuses the EditBox.
    --------------------------------------------------------

    macroClickOverlay =
        CreateFrame(
            "Button",
            nil,
            macroFrame
        )

    macroClickOverlay:SetAllPoints(
        macroFrame
    )

    macroClickOverlay:SetFrameLevel(
        macroFrame:GetFrameLevel() + 5
    )

    macroClickOverlay:EnableMouse(
        true
    )

    macroClickOverlay:RegisterForClicks(
        "LeftButtonUp",
        "RightButtonUp"
    )

    macroClickOverlay:SetScript(
        "OnClick",
        function()

            SelectMacroText()

        end
    )


    --------------------------------------------------------
    -- Keep close button above overlay.
    --------------------------------------------------------

    if macroFrame.CloseButton then

        macroFrame.CloseButton:SetFrameLevel(
            macroFrame:GetFrameLevel() + 20
        )

    end


    macroFrame:Hide()
end


------------------------------------------------------------
-- Show generated macro in copy window
------------------------------------------------------------

local function ShowMacroCopyWindow(
    macroText,
    macroTitle
)

    CreateMacroFrame()


    macroFrame.title:SetText(
        L.MACRO_MANAGER_2
        .. tostring(macroTitle or "")
    )


    macroEditBox:SetText(
        macroText
    )


    macroFrame:SetFrameStrata(
        "DIALOG"
    )

    macroFrame:Raise()


    if macroClickOverlay then

        macroClickOverlay:SetFrameLevel(
            macroFrame:GetFrameLevel() + 5
        )

    end


    if macroFrame.CloseButton then

        macroFrame.CloseButton:SetFrameLevel(
            macroFrame:GetFrameLevel() + 20
        )

    end


    macroFrame:Show()

    SelectMacroText()
end


------------------------------------------------------------
-- Open Blizzard Macro UI
------------------------------------------------------------

local standaloneMacro, standaloneStrata, macroSettingsHooked

local function RemoveMacroEscapeEntry()
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "MacroFrame" then table.remove(UISpecialFrames, i) end
    end
end

local function RegisterMacroEscapeEntry()
    if not standaloneMacro then return end
    for _, name in ipairs(UISpecialFrames) do if name == "MacroFrame" then return end end
    table.insert(UISpecialFrames, "MacroFrame")
end

local function OpenBlizzardMacroUI()
    if type(MacroFrame_LoadUI) == "function" then MacroFrame_LoadUI() end
    if not MacroFrame then return false end

    local settingsShown = SettingsPanel and SettingsPanel:IsShown()
    if settingsShown or standaloneMacro then
        -- ShowUIPanel rejects non-fullscreen panels while Settings is open.
        -- Direct Show leaves this window outside Settings' panel close pass.
        if not standaloneMacro then
            standaloneStrata = MacroFrame:GetFrameStrata()
            standaloneMacro = true
        end
        if not MacroFrame.__yToolsStandaloneHook then
            MacroFrame.__yToolsStandaloneHook = true
            MacroFrame:HookScript("OnHide", function(self)
                if standaloneMacro then
                    standaloneMacro = false
                    RemoveMacroEscapeEntry()
                    self:SetFrameStrata(standaloneStrata or "HIGH")
                end
            end)
        end
        if settingsShown then
            RemoveMacroEscapeEntry()
            MacroFrame:SetFrameStrata("FULLSCREEN_DIALOG")
            if not macroSettingsHooked then
                macroSettingsHooked = true
                SettingsPanel:HookScript("OnHide", function()
                    C_Timer.After(0, function()
                        if standaloneMacro and not SettingsPanel:IsShown() then
                            MacroFrame:SetFrameStrata(standaloneStrata or "HIGH")
                            RegisterMacroEscapeEntry()
                        end
                    end)
                end)
            end
        else
            RegisterMacroEscapeEntry()
        end
        if MacroFrame:GetNumPoints() == 0 then
            MacroFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
        end
        MacroFrame:Show()
        MacroFrame:Raise()
    elseif type(MacroFrame_Show) == "function" then MacroFrame_Show()
    elseif type(ShowMacroFrame) == "function" then ShowMacroFrame()
    else ShowUIPanel(MacroFrame) end

    return MacroFrame:IsShown()
end

------------------------------------------------------------
-- Select General / Character macro tab
------------------------------------------------------------

local function SelectMacroTab(perCharacter)

    if not MacroFrame then
        return false
    end


    local tab = perCharacter
        and MacroFrameTab2
        or MacroFrameTab1


    if MacroFrame.ChangeTab then

        MacroFrame:ChangeTab(
            perCharacter and 2 or 1
        )

        return true
    end


    if tab then

        tab:Click()

        return true
    end


    return false
end


------------------------------------------------------------
-- Check whether Blizzard's "New" button is available.
------------------------------------------------------------

local function CanCreateMacro()

    if MacroNewButton then

        return MacroNewButton:IsEnabled() == true
    end

    return true
end


------------------------------------------------------------
-- Create the macro
------------------------------------------------------------

local function CreateGeneratedMacro(
    macroName,
    macroText,
    perCharacter
)

    if InCombatLockdown
        and InCombatLockdown()
    then

        return false
    end


    if type(macroName) ~= "string"
        or macroName == ""
        or #macroName > 16
    then

        return false
    end


    if not CanCreateMacro() then
        return false
    end


    local ok,
        result =
        pcall(
            CreateMacro,
            macroName,
            MACRO_DEFAULT_ICON,
            macroText,
            perCharacter
        )


    if not ok
        or not result
    then

        return false
    end


    return true,
        result
end


------------------------------------------------------------
-- Select newly-created macro
------------------------------------------------------------

local function SelectCreatedMacro(macroID)

    if not MacroFrame
        or not macroID
    then

        return
    end


    if MacroFrame.Update then
        MacroFrame:Update()
    end


    --------------------------------------------------------
    -- The generated macro ID is already the actual macro
    -- index. Convert it into the selection index used by
    -- the currently displayed tab.
    --------------------------------------------------------

    local macroBase =
        MacroFrame.macroBase
        or 0


    local selectionIndex =
        macroID - macroBase


    if selectionIndex < 1 then
        selectionIndex = 1
    end


    if MacroFrame.SelectMacro then

        MacroFrame:SelectMacro(
            selectionIndex,
            true
        )

        return
    end


    if type(MacroFrame_SelectMacro) == "function" then

        MacroFrame_SelectMacro(
            macroID
        )

    end
end


------------------------------------------------------------
-- Create macro and update Blizzard UI
------------------------------------------------------------

local function CreateAndSelectMacro(
    macroName,
    macroText,
    perCharacter
)

    if not OpenBlizzardMacroUI() then
        return false
    end


    if not SelectMacroTab(
        perCharacter
    ) then

        return false
    end


    if MacroFrame.Update then
        MacroFrame:Update()
    end


    local success,
        macroID =
        CreateGeneratedMacro(
            macroName,
            macroText,
            perCharacter
        )


    if not success then
        return false
    end


    SelectCreatedMacro(
        macroID
    )

    return true
end


------------------------------------------------------------
-- Create macro or show copy window
--
-- This handles:
--
-- * 255-character limit
-- * macro creation
-- * full macro slots
-- * combat lockdown
-- * other CreateMacro failures
------------------------------------------------------------

local function CreateOrShowMacro(
    macroName,
    macroText,
    perCharacter
)

    --------------------------------------------------------
    -- IMPORTANT:
    --
    -- The -1 is intentional.
    --
    -- This matches the length check required by the
    -- WoW macro API/client behavior.
    --------------------------------------------------------

    local macroLength =
        #macroText - 1


    --------------------------------------------------------
    -- Macro body is too long.
    --
    -- Do not even attempt CreateMacro().
    --------------------------------------------------------

    if macroLength > MACRO_MAX_LENGTH then

        ShowMacroCopyWindow(
            macroText,
            macroName
        )

        yTools:Print(
            "|cffffcc00yTools:|r "
            .. L.THE_GENERATED_MACRO_IS
            .. tostring(macroLength)
            .. L.CHARACTERS_LONG_AND_EXCEEDS_THE
            .. tostring(MACRO_MAX_LENGTH)
            .. L.CHARACTER_LIMIT
            .. L.THE_MACRO_IS_AVAILABLE_IN_THE_COPY_WINDOW
        )

        return false
    end


    --------------------------------------------------------
    -- Try automatic creation.
    --------------------------------------------------------

    if CreateAndSelectMacro(
        macroName,
        macroText,
        perCharacter
    ) then

        return true
    end


    --------------------------------------------------------
    -- Creation failed.
    --
    -- This can happen because:
    --
    -- * no macro slots are available
    -- * Create button is unavailable
    -- * combat lockdown
    -- * invalid API state
    -- * client-specific restrictions
    --------------------------------------------------------

    ShowMacroCopyWindow(
        macroText,
        macroName
    )

    yTools:Print(
        "|cffffcc00yTools:|r "
        .. L.THE_MACRO_COULD_NOT_BE_CREATED_AUTOMATICALLY
        .. L.THE_GENERATED_MACRO_IS_AVAILABLE_IN_THE_COPY_WINDOW
    )
    return false
end


------------------------------------------------------------
-- Generate macro
------------------------------------------------------------

local function GenerateMacro(arguments)

    if type(arguments) ~= "string" then
        PrintUsage()
        return
    end


    --------------------------------------------------------
    -- Extract macro type.
    --------------------------------------------------------

    local macroType,
        remainingArguments =
        arguments:match(
            "^%s*(%S+)%s+(.-)%s*$"
        )


    if not macroType
        or not remainingArguments
        or remainingArguments == ""
    then

        PrintUsage()

        return
    end


    --------------------------------------------------------
    -- Only the macro type is case-insensitive.
    --
    -- Names and spell names remain untouched.
    --------------------------------------------------------

    macroType =
        macroType:lower()


    --------------------------------------------------------
    -- Resolve type and storage.
    --------------------------------------------------------

    local perCharacter = true
    local generatorType


    if macroType == "harm"
        or macroType == "help"
        or macroType == "hybrid"
        or macroType == "dual"
    then

        generatorType = macroType

    elseif macroType == "general-harm" then

        generatorType = "harm"
        perCharacter = false

    elseif macroType == "general-help" then

        generatorType = "help"
        perCharacter = false

    elseif macroType == "general-dual" then
        generatorType = "dual"
        perCharacter = false

    elseif macroType == "general-hybrid" then

        generatorType = "hybrid"
        perCharacter = false

    else

        yTools:Print(
            "|cffff0000yTools:|r "
            .. L.UNKNOWN_MACRO_TYPE
            .. tostring(macroType)
        )

        yTools:Print(
            L.CFFFFFF00VALID_TYPES_R
            .. "harm, help, hybrid, dual, general-harm, general-help, general-hybrid, general-dual"
        )

        PrintUsage()

        return
    end


    --------------------------------------------------------
    -- Parse quoted arguments.
    --------------------------------------------------------

    local args =
        ParseQuotedArguments(
            remainingArguments
        )


    if not args then

        yTools:Print(
            "|cffff0000yTools:|r "
            .. L.INVALID_SYNTAX
        )

        yTools:Print(
            L.CFFFFFF00ALL_ARGUMENTS_MUST_BE_QUOTED_R
        )

        PrintUsage()

        return
    end


    --------------------------------------------------------
    -- Validate argument count.
    --------------------------------------------------------

    local expectedArguments =
        generatorType == "hybrid"
        and 3
        or 2


    if #args ~= expectedArguments then

        if generatorType == "hybrid" then

            yTools:Print(
                "|cffff0000yTools:|r "
                .. L.HYBRID_MACROS_REQUIRE_A_NAME_HARM_SPELL_AND_HELP_SPELL
            )

        else

            yTools:Print(
                "|cffff0000yTools:|r "
                .. generatorType
                .. L.MACROS_REQUIRE_A_NAME_AND_EXACTLY_ONE_SPELL
            )

        end

        yTools:Print(
            "/ytools macro "
            .. macroType
            .. " "
            .. (
                generatorType == "hybrid"
                and L.MACRO_USAGE_7
                or L.MACRO_USAGE_8
            )
        )

        return
    end


    --------------------------------------------------------
    -- Extract common name.
    --------------------------------------------------------

    local macroName =
        args[1]


    --------------------------------------------------------
    -- Generate macro text.
    --------------------------------------------------------

    local macroText


    if generatorType == "harm" then

        macroText =
            GenerateHarmMacro(
                args[2]
            )

    elseif generatorType == "help" then

        macroText =
            GenerateHelpMacro(
                args[2]
            )

    elseif generatorType == "dual" then
        macroText = GenerateGeneralMacro(args[2])

    elseif generatorType == "hybrid" then

        macroText =
            GenerateHybridMacro(
                args[2],
                args[3]
            )

    end


    --------------------------------------------------------
    -- Create or fall back to copy window.
    --------------------------------------------------------

    CreateOrShowMacro(
        macroName,
        macroText,
        perCharacter
    )
end


------------------------------------------------------------
-- Settings form
------------------------------------------------------------

local settingsPanel, settingsCategory

local function Trim(value)
    return (value or ""):match("^%s*(.-)%s*$")
end

local disenchantSpell = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(13262))
    or (GetSpellInfo and GetSpellInfo(13262)) or L.DISENCHANT

local comprehendSpell = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(1296017))
    or (GetSpellInfo and GetSpellInfo(1296017)) or L.COMPREHEND_SCROLL

local function GenerateChannelingMacro(spell, focusModifier)
    return "#showtooltip " .. spell .. "\n/stopcasting [nochanneling]\n/cast [nochanneling,mod:" .. focusModifier
        .. ",@focus,exists][nochanneling,@mouseover,exists,nodead][nochanneling]" .. spell
end

local function GenerateFocusCCMacro(spell)
    return "#showtooltip\n/cast [mod:shift,@focus,harm][@mouseover,harm,nodead][]" .. spell
        .. "\n/focus [nomod:shift,@mouseover,harm,nodead][nomod:shift]"
end

local function NextMacroInput(inputs, current)
    local step = IsShiftKeyDown() and -1 or 1
    for index, input in ipairs(inputs) do
        if input == current then
            for offset = 1, #inputs do
                local nextInput = inputs[(index - 1 + offset * step) % #inputs + 1]
                if nextInput:IsShown() and nextInput:IsEnabled() then
                    current:ClearFocus()
                    nextInput:SetFocus()
                    nextInput:HighlightText()
                    return
                end
            end
        end
    end
end

local PRESET_MACROS = {
    focusCC = { editableSpell = true },
    comprehendScroll = {
        name = "_yScroll",
        text = string.format([[#showtooltip
/run local f=yS or CreateFrame("Button","yS",nil,"SecureActionButtonTemplate") f:RegisterForClicks("AnyDown","AnyUp") f:SetAttribute("type","click") f:SetAttribute("clickbutton",GetMouseFoci()[1])
/use %s
/click yS]], comprehendSpell),
    },
    disenchant = {
        name = "_yDE",
        text = string.format([[#showtooltip %s
/run local f=yDE or CreateFrame("Button","yDE",nil,"SecureActionButtonTemplate") f:RegisterForClicks("AnyDown","AnyUp") f:SetAttribute("type","click") f:SetAttribute("clickbutton",GetMouseFoci()[1])
/use %s
/click yDE]], disenchantSpell, disenchantSpell),
    },
}

function module:CreateOptionsPanel(parentCategory)
    if settingsPanel or not parentCategory or not Settings
        or not Settings.RegisterCanvasLayoutSubcategory then return end

    local panel = CreateFrame("Frame")
    panel:SetSize(700, 560)
    settingsPanel = panel
    self.settingsPanel = panel
    panel.macroType = "dual"
    panel.perCharacter = true
    panel.focusModifier = "shift"
    panel.playerModifier = "ctrl/shift"
    panel.preset = "disenchant"

    local controls = CreateFrame("Frame", nil, panel)
    controls:SetAllPoints(panel)
    panel.controls = controls
    local enable = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    enable:SetPoint("TOPLEFT", 400, -18)
    local enableLabel = enable:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    enableLabel:SetPoint("LEFT", enable, "RIGHT", 2, 0)
    enableLabel:SetText(L.MODULE_OPTIONS_ENABLE)
    enableLabel:ClearAllPoints(); enableLabel:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -32, -22)
    enable:ClearAllPoints(); enable:SetPoint("RIGHT", enableLabel, "LEFT", -5, 0)
    panel.enable = enable
    enable:SetScript("OnClick", function(self)
        if self:GetChecked() then module:Enable() else module:Disable() end
        panel.RefreshForm()
    end)

    local function Label(text, x, y, font)
        local label = controls:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
        label:SetPoint("TOPLEFT", x, y)
        label:SetJustifyH("LEFT")
        label:SetText(text)
        return label
    end

    Label(L.MACRO_MANAGER, 32, -24, "GameFontNormalLarge"):SetParent(panel)
    panel.instructions = Label(L.MACRO_INSTRUCTIONS, 32, -54, "GameFontHighlight")
    Label(L.TYPE, 32, -94)
    Label(L.STORAGE, 290, -94)
    local focusModifierLabel = Label(L.FOCUS_MODIFIER, 32, -148)
    local presetLabel = Label(L.PRESET, 32, -148)
    local playerModifierLabel = Label(L.PLAYER_MODIFIER, 290, -148)
    local nameLabel = Label(L.MACRO_NAME, 32, -207)
    local spellLabel = Label(L.HARM_SPELL, 32, -261)
    local secondLabel = Label(L.HELP_SPELL, 32, -315)
    Label(L.MACRO_TEXT_UPDATES_LIVE_SELECT_AND_PRESS_CTRL_C_TO_COPY, 32, -369)

    local function Input(y, maxLetters)
        local edit = CreateFrame("EditBox", nil, controls, "InputBoxTemplate")
        edit:SetSize(460, 24)
        edit:SetPoint("TOPLEFT", 38, y)
        edit:SetAutoFocus(false)
        edit:SetMaxLetters(maxLetters)
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        return edit
    end
    panel.name = Input(-228, 16)
    panel.spell = Input(-282, 0)
    panel.helpSpell = Input(-336, 0)

    local previewBorder = CreateFrame("Frame", nil, controls, "BackdropTemplate")
    previewBorder:SetPoint("TOPLEFT", 32, -390)
    previewBorder:SetSize(600, 84)
    yTools.UI.InputBorder(previewBorder)
    local previewScroll = CreateFrame("ScrollFrame", nil, previewBorder, "UIPanelScrollFrameTemplate")
    previewScroll:SetPoint("TOPLEFT", 6, -6)
    previewScroll:SetPoint("BOTTOMRIGHT", -28, 6)
    local preview = CreateFrame("EditBox", nil, previewScroll)
    preview:SetSize(566, 72)
    preview:SetAutoFocus(false)
    preview:SetMultiLine(true)
    preview:SetMaxLetters(0)
    preview:SetFontObject(ChatFontNormal)
    preview:SetJustifyH("LEFT")
    preview:SetJustifyV("TOP")
    preview:EnableMouse(true)
    preview:EnableKeyboard(true)
    previewScroll:SetScrollChild(preview)
    preview:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    preview:SetScript("OnCursorChanged", function(_, _, y, _, height)
        local position = -y
        local current = previewScroll:GetVerticalScroll()
        local visible = previewScroll:GetHeight()
        if position < current then
            previewScroll:SetVerticalScroll(math.max(0, position))
        elseif position + height > current + visible then
            previewScroll:SetVerticalScroll(position + height - visible)
        end
    end)
    panel.preview = preview
    panel.previewScroll = previewScroll
    local status = Label("", 32, -525, "GameFontHighlightSmall")
    status:SetWidth(600)
    status:SetJustifyH("LEFT")
    panel.status = status

    local function Build()
        if panel.macroType == "preset" then
            local preset = PRESET_MACROS[panel.preset]
            if not preset then return nil, L.CHOOSE_A_PRESET end
            if not preset.editableSpell then return preset.text, nil, preset.name end
        end
        local name, spell = Trim(panel.name:GetText()), Trim(panel.spell:GetText())
        local helpSpell = Trim(panel.helpSpell:GetText())
        if name == "" then return nil, L.ENTER_A_MACRO_NAME end
        if #name > 16 then return nil, L.MACRO_NAMES_MUST_BE_AT_MOST_16_BYTES end
        if spell == "" then return nil, L.ENTER_A_SPELL_NAME end
        if panel.macroType == "hybrid" and helpSpell == "" then
            return nil, L.ENTER_BOTH_THE_HARM_AND_HELP_SPELL_NAMES
        end
        if spell:find("[\r\n]") or helpSpell:find("[\r\n]") then
            return nil, L.SPELL_NAMES_MUST_BE_ON_ONE_LINE
        end
        local text
        if panel.macroType == "preset" and panel.preset == "focusCC" then text = GenerateFocusCCMacro(spell)
        elseif panel.macroType == "channeling" then text = GenerateChannelingMacro(spell, panel.focusModifier)
        elseif panel.macroType == "harm" then text = GenerateHarmMacro(spell, panel.focusModifier)
        elseif panel.macroType == "help" then text = GenerateHelpMacro(spell, panel.focusModifier, panel.playerModifier)
        elseif panel.macroType == "dual" then text = GenerateGeneralMacro(spell, panel.focusModifier, panel.playerModifier)
        else text = GenerateHybridMacro(spell, helpSpell, panel.focusModifier, panel.playerModifier) end
        return text, nil, name
    end

    local create = CreateFrame("Button", nil, controls, "UIPanelButtonTemplate")
    create:SetSize(160, 24)
    create:SetPoint("TOPLEFT", 32, -486)
    create:SetText(L.CREATE_MACRO)
    panel.create = create
    local resultText = Label("", 204, -491, "GameFontHighlight")
    panel.resultText = resultText
    local resultGeneration = 0
    local function ShowResult(success)
        resultGeneration = resultGeneration + 1
        local generation = resultGeneration
        resultText:SetText(success and L.MACRO_CREATED or L.MACRO_NOT_CREATED)
        resultText:SetTextColor(success and 0 or 1, success and 1 or 0, 0)
        C_Timer.After(3, function()
            if resultGeneration == generation then resultText:SetText("") end
        end)
    end

    local function RefreshForm()
        enable:SetChecked(module:IsEnabled())
        controls:SetShown(module:IsEnabled())
        local hybrid = panel.macroType == "hybrid"
        local preset = panel.macroType == "preset"
        local editable = not preset or (PRESET_MACROS[panel.preset] and PRESET_MACROS[panel.preset].editableSpell)
        focusModifierLabel:SetShown(not preset)
        playerModifierLabel:SetShown(not preset and panel.macroType ~= "channeling")
        presetLabel:SetShown(preset)
        nameLabel:SetShown(editable)
        panel.name:SetShown(editable)
        spellLabel:SetShown(editable)
        panel.spell:SetShown(editable)
        if panel.focusDropdown then panel.focusDropdown:SetShown(not preset) end
        if panel.playerDropdown then panel.playerDropdown:SetShown(not preset and panel.macroType ~= "channeling") end
        if panel.presetDropdown then panel.presetDropdown:SetShown(preset) end
        if panel.playerDropdown then
            local helpful = panel.macroType ~= "harm"
            panel.playerDropdown:SetEnabled(true)
            if not helpful then panel.playerDropdown:SetEnabled(false) end
            playerModifierLabel:SetAlpha(helpful and 1 or .5)
        end
        spellLabel:SetText((panel.macroType == "dual" or panel.macroType == "channeling" or preset) and L.SPELL or (panel.macroType == "help" and L.HELP_SPELL or L.HARM_SPELL))
        panel.helpSpell:SetShown(hybrid)
        secondLabel:SetShown(hybrid)
        local text, err = Build()
        preview:SetText(text or "")
        create:SetEnabled(module:IsEnabled() and text ~= nil)
        if not module:IsEnabled() then
            status:SetText(L.ENABLE_MACRO_MANAGER_IN_THE_YTOOLS_MODULE_LIST_TO_CREATE_MACROS)
        elseif err then status:SetText(err)
        else
            local length = #text - 1
            status:SetText(tostring(length) .. L.TEXT_255_CHARACTERS
                .. (length > MACRO_MAX_LENGTH and L.TOO_LONG_CREATION_OPENS_THE_COPY_WINDOW or ""))
        end
    end
    panel.RefreshForm = RefreshForm

    local function Dropdown(x, choices, initial, choose, y)
        local dropdown = CreateFrame("DropdownButton", nil, controls, "WowStyle1DropdownTemplate")
        dropdown:SetPoint("TOPLEFT", x+16, y or -110)
        dropdown:SetSize(206,26)
        dropdown:SetDefaultText(initial)
        dropdown:SetupMenu(function(_,root)
            for _, choice in ipairs(choices) do
                local value,title = choice[1],choice[2]
                root:CreateRadio(title,function()return choose(nil)==value end,function()
                    choose(value)
                    dropdown:SetDefaultText(title)
                    RefreshForm()
                end)
            end
        end)
        return dropdown
    end
    panel.typeDropdown = Dropdown(16, {{"dual", L.GENERAL}, {"harm", L.HARM}, {"help", L.HELP}, {"hybrid", L.HYBRID}, {"channeling", L.CHANNELING}, {"preset", L.PRESET}}, L.GENERAL, function(value)
        if value then panel.macroType = value end
        return panel.macroType
    end)
    panel.storageDropdown = Dropdown(274, {{"character", L.CHARACTER}, {"general", L.ACCOUNT}}, L.CHARACTER, function(value)
        if value then panel.perCharacter = value == "character" end
        return panel.perCharacter and "character" or "general"
    end)
    panel.focusDropdown = Dropdown(16, {{"alt", L.ALT}, {"ctrl", L.CTRL}, {"shift", L.SHIFT}}, L.SHIFT, function(value)
        if value then panel.focusModifier = value end
        return panel.focusModifier
    end, -164)
    panel.playerDropdown = Dropdown(274, {{"alt", L.ALT}, {"ctrl", L.CTRL}, {"shift", L.SHIFT}, {"ctrl/shift", L.CTRL_OR_SHIFT_DEFAULT}}, L.CTRL_OR_SHIFT_DEFAULT, function(value)
        if value then panel.playerModifier = value end
        return panel.playerModifier
    end, -164)
    panel.presetDropdown = Dropdown(16, {{"disenchant", L.DISENCHANT}, {"comprehendScroll", L.COMPREHEND_SCROLL}, {"focusCC", L.AUTO_FOCUS_CC}}, L.DISENCHANT, function(value)
        if value then panel.preset = value end
        return panel.preset
    end, -164)
    local inputs = {panel.name, panel.spell, panel.helpSpell}
    for _, input in ipairs(inputs) do
        input:SetScript("OnTabPressed", function(self) NextMacroInput(inputs, self) end)
        input:SetScript("OnTextChanged", RefreshForm)
    end
    create:SetScript("OnClick", function()
        if not module:IsEnabled() then RefreshForm(); return end
        local text, err, name = Build()
        if not text then status:SetText(err); return end
        panel.name:ClearFocus()
        panel.spell:ClearFocus()
        panel.helpSpell:ClearFocus()
        local editedText = preview:GetText()
        if Trim(editedText) == "" then
            status:SetText(L.THE_MACRO_TEXT_IS_EMPTY)
            return
        end
        -- Also open the macro window when creation falls back to copying.
        if #editedText - 1 > MACRO_MAX_LENGTH then OpenBlizzardMacroUI() end
        local success = CreateOrShowMacro(name, editedText, panel.perCharacter)
        ShowResult(success == true)
    end)
    preview:SetScript("OnTextChanged", function()
        local text = preview:GetText()
        local generated = Build()
        create:SetEnabled(module:IsEnabled() and generated ~= nil and Trim(text) ~= "")
        if module:IsEnabled() and generated then
            local length = #text - 1
            status:SetText(tostring(math.max(0, length)) .. L.TEXT_255_CHARACTERS
                .. (length > MACRO_MAX_LENGTH and L.TOO_LONG_CREATION_OPENS_THE_COPY_WINDOW or ""))
        end
    end)
    panel:SetScript("OnShow", RefreshForm)
    settingsCategory = Settings.RegisterCanvasLayoutSubcategory(parentCategory, panel, L.MACRO_MANAGER)
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

local function DisableMacro()

    if macroEditBox then
        macroEditBox:ClearFocus()
    end


    if macroFrame then
        macroFrame:Hide()
    end
end


------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------

function module:OnEnable()
    if settingsPanel then settingsPanel.RefreshForm() end
end


function module:OnDisable()

    DisableMacro()
    if settingsPanel then settingsPanel.RefreshForm() end

end


------------------------------------------------------------
-- Slash command
------------------------------------------------------------

module:RegisterSlashCommand(
    "macro",
    function(_, arguments)

        if type(arguments) ~= "string" then

            PrintUsage()
            module:OpenOptionsPanel()

            return
        end


        arguments =
            string.match(
                arguments,
                "^%s*(.-)%s*$"
            )


        if arguments:lower() == "ui" then
            module:OpenOptionsPanel()
            return
        end

        if arguments == "" then

            PrintUsage()
            module:OpenOptionsPanel()

            return
        end


        if not module:IsEnabled() then return end

        GenerateMacro(
            arguments
        )

    end,
    L.GENERATE_AND_CREATE_A_WOW_MACRO
)
