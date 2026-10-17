local L = _G.yTools.L
local yTools = _G.yTools

local module = yTools:RegisterModule(
    "CopyChat",
    {
        title = L.CHAT_COPY_CHAT_YTOOLS_COPYCHAT,
        description = L.ADDS_A_BUTTON_TO_CHAT_WINDOWS_THAT_OPENS_THEIR_CONTENTS_IN_A_COPYABLE_WINDOW,
        defaultEnabled = true,
    }
)


------------------------------------------------------------
-- Local state
------------------------------------------------------------

local copyFrame
local copyScrollFrame
local copyEditBox
local copyScrollBar
local copyTitleBar
local copyMeasureText

local copyScrollUpButton
local copyScrollDownButton

local hookedChatFrames = {}
local temporaryWindowHooked = false

local updatingScroll = false


------------------------------------------------------------
-- Constants
------------------------------------------------------------

local COPY_BUTTON_SIZE = 18

local COPY_FRAME_WIDTH = 650
local COPY_FRAME_HEIGHT = 450

local COPY_LEFT = 16
local COPY_TOP = 38
local COPY_RIGHT = 36
local COPY_BOTTOM = 16

local COPY_SCROLLBAR_WIDTH = 16
local COPY_SCROLLBAR_BUTTON_SIZE = 16

local COPY_WHEEL_STEP = 40


------------------------------------------------------------
-- Helpers
------------------------------------------------------------

local function StripChatText(text)

    if not text then
        return ""
    end

    text = text:gsub("|T.-|t", "")
    text = text:gsub("|A.-|a", "")

    return text
end


------------------------------------------------------------
-- Combat Log
------------------------------------------------------------

local function IsCombatLogFrame(chatFrame)

    if not chatFrame then
        return false
    end

    if chatFrame == _G["ChatFrame2"] then
        return true
    end

    if chatFrame == COMBATLOG then
        return true
    end

    if chatFrame == CombatLogChatFrame then
        return true
    end

    return false
end


------------------------------------------------------------
-- Get chat contents
------------------------------------------------------------

local function GetChatText(chatFrame)

    if not chatFrame then
        return ""
    end

    if IsCombatLogFrame(chatFrame) then
        return ""
    end

    if not chatFrame.GetNumMessages
        or not chatFrame.GetMessageInfo
    then
        return ""
    end

    local messages = {}

    local count =
        chatFrame:GetNumMessages()

    for i = 1, count do

        local text =
            chatFrame:GetMessageInfo(i)

        if text and text ~= "" then

            messages[#messages + 1] =
                StripChatText(text)

        end
    end

    return table.concat(
        messages,
        "\n"
    )
end


------------------------------------------------------------
-- Copy icon
------------------------------------------------------------

local function CreateCopyIcon(button)

    local back =
        button:CreateTexture(
            nil,
            "ARTWORK"
        )

    back:SetTexture(
        "Interface\\Buttons\\WHITE8X8"
    )

    back:SetSize(
        9,
        10
    )

    back:SetPoint(
        "TOPLEFT",
        3,
        -3
    )

    back:SetVertexColor(
        0.55,
        0.55,
        0.55,
        1
    )

    button.copyIconBack =
        back


    local front =
        button:CreateTexture(
            nil,
            "OVERLAY"
        )

    front:SetTexture(
        "Interface\\Buttons\\WHITE8X8"
    )

    front:SetSize(
        9,
        10
    )

    front:SetPoint(
        "BOTTOMRIGHT",
        -3,
        3
    )

    front:SetVertexColor(
        0.75,
        0.75,
        0.75,
        1
    )

    button.copyIconFront =
        front


    local cutout =
        button:CreateTexture(
            nil,
            "OVERLAY"
        )

    cutout:SetTexture(
        "Interface\\Buttons\\WHITE8X8"
    )

    cutout:SetSize(
        6,
        7
    )

    cutout:SetPoint(
        "CENTER",
        front,
        "CENTER"
    )

    cutout:SetVertexColor(
        0.08,
        0.08,
        0.08,
        1
    )

    button.copyIconCutout =
        cutout
end


------------------------------------------------------------
-- Icon highlight
------------------------------------------------------------

local function SetCopyIconHighlight(
    button,
    highlighted
)

    if not button then
        return
    end

    if highlighted then

        button:SetAlpha(
            1
        )

        if button.copyIconBack then

            button.copyIconBack:SetVertexColor(
                0.75,
                0.75,
                0.75,
                1
            )

        end

        if button.copyIconFront then

            button.copyIconFront:SetVertexColor(
                1,
                1,
                1,
                1
            )

        end

    else

        button:SetAlpha(
            0.65
        )

        if button.copyIconBack then

            button.copyIconBack:SetVertexColor(
                0.45,
                0.45,
                0.45,
                1
            )

        end

        if button.copyIconFront then

            button.copyIconFront:SetVertexColor(
                0.70,
                0.70,
                0.70,
                1
            )

        end
    end
end


------------------------------------------------------------
-- Calculate text height
------------------------------------------------------------

local function GetCopyTextHeight()

    if not copyMeasureText
        or not copyEditBox
        or not copyScrollFrame
    then
        return 0
    end

    local width =
        copyScrollFrame:GetWidth()

    if not width
        or width <= 0
    then
        return 0
    end

    local textWidth =
        math.max(
            1,
            width - 12
        )

    copyMeasureText:SetWidth(
        textWidth
    )

    copyMeasureText:SetText(
        copyEditBox:GetText() or ""
    )

    local height =
        copyMeasureText:GetHeight()

    if not height
        or height <= 0
    then
        height = 14
    end

    return height + 12
end


------------------------------------------------------------
-- Get maximum scroll
------------------------------------------------------------

local function GetMaxCopyScroll()

    if not copyScrollFrame
        or not copyEditBox
    then
        return 0
    end

    local visibleHeight =
        copyScrollFrame:GetHeight()

    local contentHeight =
        copyEditBox:GetHeight()

    if not visibleHeight
        or not contentHeight
    then
        return 0
    end

    return math.max(
        0,
        contentHeight - visibleHeight
    )
end


------------------------------------------------------------
-- Set scroll
------------------------------------------------------------

local function SetCopyScroll(value)

    if not copyScrollFrame then
        return
    end

    local maxScroll =
        GetMaxCopyScroll()

    value =
        math.max(
            0,
            math.min(
                maxScroll,
                value or 0
            )
        )

    updatingScroll = true

    copyScrollFrame:SetVerticalScroll(
        value
    )

    if copyScrollBar then

        local current =
            copyScrollBar:GetValue()

        if not current
            or math.abs(
                current - value
            ) > 0.01
        then

            copyScrollBar:SetValue(
                value
            )

        end
    end

    updatingScroll = false
end


------------------------------------------------------------
-- Update scroll range
------------------------------------------------------------

local function UpdateCopyScroll()

    if not copyScrollFrame
        or not copyEditBox
        or not copyScrollBar
    then
        return 0
    end

    local visibleWidth =
        copyScrollFrame:GetWidth()

    local visibleHeight =
        copyScrollFrame:GetHeight()

    if not visibleWidth
        or not visibleHeight
        or visibleWidth <= 0
        or visibleHeight <= 0
    then
        return 0
    end


    --------------------------------------------------------
    -- Keep EditBox exactly the width of the scroll area.
    --------------------------------------------------------

    copyEditBox:SetWidth(
        visibleWidth
    )


    --------------------------------------------------------
    -- Measure wrapped text.
    --------------------------------------------------------

    local textHeight =
        GetCopyTextHeight()

    local contentHeight =
        math.max(
            visibleHeight,
            textHeight
        )

    copyEditBox:SetHeight(
        contentHeight
    )

    copyScrollFrame:SetScrollChild(
        copyEditBox
    )


    --------------------------------------------------------
    -- Calculate maximum scroll.
    --------------------------------------------------------

    local maxScroll =
        math.max(
            0,
            contentHeight - visibleHeight
        )


    copyScrollBar:SetMinMaxValues(
        0,
        maxScroll
    )


    local current =
        copyScrollFrame:GetVerticalScroll()
        or 0

    current =
        math.max(
            0,
            math.min(
                maxScroll,
                current
            )
        )


    updatingScroll = true

    copyScrollFrame:SetVerticalScroll(
        current
    )

    copyScrollBar:SetValue(
        current
    )

    updatingScroll = false


    if maxScroll > 0 then

        copyScrollBar:Show()

        if copyScrollUpButton then
            copyScrollUpButton:Show()
        end

        if copyScrollDownButton then
            copyScrollDownButton:Show()
        end

    else

        copyScrollBar:Hide()

        if copyScrollUpButton then
            copyScrollUpButton:Hide()
        end

        if copyScrollDownButton then
            copyScrollDownButton:Hide()
        end

    end


    return maxScroll
end


------------------------------------------------------------
-- Scroll to bottom
------------------------------------------------------------

local function ScrollCopyToBottom()

    if not copyScrollFrame
        or not copyScrollBar
    then
        return
    end

    local maxScroll =
        GetMaxCopyScroll()

    updatingScroll = true

    copyScrollFrame:SetVerticalScroll(
        maxScroll
    )

    copyScrollBar:SetValue(
        maxScroll
    )

    updatingScroll = false
end


------------------------------------------------------------
-- Close copy window
------------------------------------------------------------

local function CloseCopyFrame()

    if not copyFrame then
        return
    end

    if copyEditBox then
        copyEditBox:ClearFocus()
    end

    copyFrame:Hide()
end


------------------------------------------------------------
-- Create copy window
------------------------------------------------------------

local function CreateCopyFrame()

    if copyFrame then
        return
    end


    --------------------------------------------------------
    -- Main frame
    --------------------------------------------------------

    copyFrame =
        CreateFrame(
            "Frame",
            "yToolsCopyChatFrame",
            UIParent,
            "BasicFrameTemplateWithInset"
        )

    copyFrame:SetSize(
        COPY_FRAME_WIDTH,
        COPY_FRAME_HEIGHT
    )

    copyFrame:SetPoint(
        "CENTER",
        UIParent,
        "CENTER"
    )

    copyFrame:SetFrameStrata(
        "DIALOG"
    )

    -- Block clicks throughout the window, including areas below short chat logs.
    copyFrame:EnableMouse(true)

    copyFrame:SetClampedToScreen(
        true
    )


    --------------------------------------------------------
    -- Enable keyboard input on the frame.
    --
    -- This is only used for Escape when the EditBox does
    -- not currently own keyboard focus.
    --------------------------------------------------------

    copyFrame:EnableKeyboard(
        true
    )

    copyFrame:SetScript(
        "OnKeyDown",
        function(self, key)

            if key == "ESCAPE" then

                CloseCopyFrame()

            end
        end
    )


    --------------------------------------------------------
    -- Title
    --------------------------------------------------------

    copyFrame.title =
        copyFrame:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontHighlight"
        )

    copyFrame.title:SetPoint(
        "TOPLEFT",
        8,
        -6
    )

    copyFrame.title:SetText(
        L.CHAT_COPY
    )


    --------------------------------------------------------
    -- Drag area
    --------------------------------------------------------

    copyTitleBar =
        CreateFrame(
            "Frame",
            nil,
            copyFrame
        )

    copyTitleBar:SetPoint(
        "TOPLEFT",
        copyFrame,
        "TOPLEFT"
    )

    copyTitleBar:SetPoint(
        "TOPRIGHT",
        copyFrame,
        "TOPRIGHT"
    )

    copyTitleBar:SetHeight(
        28
    )

    copyTitleBar:EnableMouse(
        true
    )


    --------------------------------------------------------
    -- ScrollFrame
    --------------------------------------------------------

    copyScrollFrame =
        CreateFrame(
            "ScrollFrame",
            "yToolsCopyChatScrollFrame",
            copyFrame
        )

    copyScrollFrame:SetPoint(
        "TOPLEFT",
        copyFrame,
        "TOPLEFT",
        COPY_LEFT,
        -COPY_TOP
    )

    copyScrollFrame:SetPoint(
        "BOTTOMRIGHT",
        copyFrame,
        "BOTTOMRIGHT",
        -COPY_RIGHT,
        COPY_BOTTOM
    )

    copyScrollFrame:EnableMouse(true)
    copyScrollFrame:EnableMouseWheel(true)
    copyScrollFrame:SetScript("OnMouseDown", function()
        if copyEditBox then copyEditBox:SetFocus() end
    end)


    --------------------------------------------------------
    -- EditBox
    --------------------------------------------------------

    copyEditBox =
        CreateFrame(
            "EditBox",
            nil,
            copyScrollFrame
        )

    copyEditBox:SetMultiLine(
        true
    )

    copyEditBox:SetAutoFocus(
        false
    )

    copyEditBox:SetMaxLetters(
        0
    )

    copyEditBox:SetFontObject(
        ChatFontNormal
    )

    copyEditBox:SetTextColor(
        1,
        1,
        1,
        1
    )

    copyEditBox:SetJustifyH(
        "LEFT"
    )

    copyEditBox:SetJustifyV(
        "TOP"
    )

    copyEditBox:SetTextInsets(
        6,
        6,
        6,
        6
    )

    copyEditBox:SetWidth(
        COPY_FRAME_WIDTH
        - COPY_LEFT
        - COPY_RIGHT
    )

    copyEditBox:SetHeight(
        COPY_FRAME_HEIGHT
        - COPY_TOP
        - COPY_BOTTOM
    )

    copyEditBox:SetPoint(
        "TOPLEFT",
        copyScrollFrame,
        "TOPLEFT",
        0,
        0
    )


    --------------------------------------------------------
    -- Keep native EditBox mouse/keyboard behavior.
    --------------------------------------------------------

    copyEditBox:EnableMouse(
        true
    )

    copyEditBox:EnableMouseWheel(
        true
    )


    --------------------------------------------------------
    -- Escape while EditBox has focus.
    --------------------------------------------------------

    copyEditBox:SetScript(
        "OnEscapePressed",
        function()

            CloseCopyFrame()

        end
    )


    --------------------------------------------------------
    -- Measurement FontString
    --------------------------------------------------------

    copyMeasureText =
        copyScrollFrame:CreateFontString(
            nil,
            "BACKGROUND",
            "ChatFontNormal"
        )

    copyMeasureText:SetJustifyH(
        "LEFT"
    )

    copyMeasureText:SetJustifyV(
        "TOP"
    )

    copyMeasureText:SetWordWrap(
        true
    )

    copyMeasureText:SetWidth(
        COPY_FRAME_WIDTH
        - COPY_LEFT
        - COPY_RIGHT
        - 12
    )

    copyMeasureText:SetText(
        ""
    )


    --------------------------------------------------------
    -- Mouse wheel over EditBox
    --------------------------------------------------------

    copyEditBox:SetScript(
        "OnMouseWheel",
        function(self, delta)

            local current =
                copyScrollFrame:GetVerticalScroll()
                or 0

            local maxScroll =
                GetMaxCopyScroll()

            local newValue =
                current
                - (
                    delta
                    * COPY_WHEEL_STEP
                )

            newValue =
                math.max(
                    0,
                    math.min(
                        maxScroll,
                        newValue
                    )
                )

            SetCopyScroll(
                newValue
            )
        end
    )


    --------------------------------------------------------
    -- Wheel scrolling also works over the empty part of the content area.
    --------------------------------------------------------

    copyScrollFrame:SetScript("OnMouseWheel", copyEditBox:GetScript("OnMouseWheel"))


    --------------------------------------------------------
    -- Scrollbar
    --------------------------------------------------------

    copyScrollBar =
        CreateFrame(
            "Slider",
            "yToolsCopyChatScrollBar",
            copyFrame
        )

    copyScrollBar:SetOrientation(
        "VERTICAL"
    )

    copyScrollBar:SetWidth(
        COPY_SCROLLBAR_WIDTH
    )

    copyScrollBar:SetPoint(
        "TOPRIGHT",
        copyFrame,
        "TOPRIGHT",
        -10,
        -38 - COPY_SCROLLBAR_BUTTON_SIZE
    )

    copyScrollBar:SetPoint(
        "BOTTOMRIGHT",
        copyFrame,
        "BOTTOMRIGHT",
        -10,
        16 + COPY_SCROLLBAR_BUTTON_SIZE
    )

    copyScrollBar:SetMinMaxValues(
        0,
        0
    )

    copyScrollBar:SetValue(
        0
    )

    copyScrollBar:SetValueStep(
        COPY_WHEEL_STEP
    )

    copyScrollBar:SetObeyStepOnDrag(
        false
    )


    --------------------------------------------------------
    -- Default Blizzard scrollbar thumb.
    --------------------------------------------------------

    local thumb =
        copyScrollBar:CreateTexture(
            "yToolsCopyChatScrollBarThumbTexture",
            "OVERLAY"
        )

    thumb:SetTexture(
        "Interface\\Buttons\\UI-ScrollBar-Knob"
    )

    thumb:SetSize(
        16,
        32
    )

    copyScrollBar:SetThumbTexture(
        thumb
    )


    --------------------------------------------------------
    -- Scroll up button.
    --------------------------------------------------------

    copyScrollUpButton =
        CreateFrame(
            "Button",
            "yToolsCopyChatScrollBarScrollUpButton",
            copyFrame
        )

    copyScrollUpButton:SetSize(
        COPY_SCROLLBAR_BUTTON_SIZE,
        COPY_SCROLLBAR_BUTTON_SIZE
    )

    copyScrollUpButton:SetPoint(
        "BOTTOM",
        copyScrollBar,
        "TOP",
        0,
        0
    )

    copyScrollUpButton:SetNormalTexture(
        "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up"
    )

    copyScrollUpButton:SetPushedTexture(
        "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Down"
    )

    copyScrollUpButton:SetHighlightTexture(
        "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Highlight",
        "ADD"
    )


    --------------------------------------------------------
    -- Scroll down button.
    --------------------------------------------------------

    copyScrollDownButton =
        CreateFrame(
            "Button",
            "yToolsCopyChatScrollBarScrollDownButton",
            copyFrame
        )

    copyScrollDownButton:SetSize(
        COPY_SCROLLBAR_BUTTON_SIZE,
        COPY_SCROLLBAR_BUTTON_SIZE
    )

    copyScrollDownButton:SetPoint(
        "TOP",
        copyScrollBar,
        "BOTTOM",
        0,
        0
    )

    copyScrollDownButton:SetNormalTexture(
        "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up"
    )

    copyScrollDownButton:SetPushedTexture(
        "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Down"
    )

    copyScrollDownButton:SetHighlightTexture(
        "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Highlight",
        "ADD"
    )


    --------------------------------------------------------
    -- Up button click.
    --------------------------------------------------------

    copyScrollUpButton:SetScript(
        "OnClick",
        function()

            local value =
                copyScrollBar:GetValue()
                or 0

            copyScrollBar:SetValue(
                math.max(
                    0,
                    value - COPY_WHEEL_STEP
                )
            )
        end
    )


    --------------------------------------------------------
    -- Down button click.
    --------------------------------------------------------

    copyScrollDownButton:SetScript(
        "OnClick",
        function()

            local value =
                copyScrollBar:GetValue()
                or 0

            local minValue,
                maxValue =
                copyScrollBar:GetMinMaxValues()

            copyScrollBar:SetValue(
                math.min(
                    maxValue,
                    value + COPY_WHEEL_STEP
                )
            )
        end
    )


    --------------------------------------------------------
    -- Scrollbar movement.
    --------------------------------------------------------

    copyScrollBar:SetScript(
        "OnValueChanged",
        function(self, value)

            if updatingScroll then
                return
            end

            local maxScroll =
                GetMaxCopyScroll()

            value =
                math.max(
                    0,
                    math.min(
                        maxScroll,
                        value or 0
                    )
                )

            updatingScroll = true

            copyScrollFrame:SetVerticalScroll(
                value
            )

            updatingScroll = false
        end
    )


    --------------------------------------------------------
    -- Mouse wheel over scrollbar.
    --------------------------------------------------------

    copyScrollBar:EnableMouseWheel(
        true
    )

    copyScrollBar:SetScript(
        "OnMouseWheel",
        function(self, delta)

            local current =
                self:GetValue()
                or 0

            local minValue,
                maxValue =
                self:GetMinMaxValues()

            local newValue =
                current
                - (
                    delta
                    * COPY_WHEEL_STEP
                )

            newValue =
                math.max(
                    minValue,
                    math.min(
                        maxValue,
                        newValue
                    )
                )

            self:SetValue(
                newValue
            )
        end
    )


    --------------------------------------------------------
    -- Initial state.
    --------------------------------------------------------

    copyScrollBar:Hide()
    copyScrollUpButton:Hide()
    copyScrollDownButton:Hide()

    copyFrame:Hide()
end


------------------------------------------------------------
-- Show copy window
------------------------------------------------------------

local function ShowCopyChat(chatFrame)

    if not module:IsEnabled() then
        return
    end

    if not chatFrame then

        chatFrame =
            SELECTED_CHAT_FRAME
            or DEFAULT_CHAT_FRAME

    end


    --------------------------------------------------------
    -- Combat Log
    --------------------------------------------------------

    if IsCombatLogFrame(chatFrame) then

        yTools:Print(
            "|cffff0000yTools:|r "
            .. L.COMBAT_LOG_COPYING_IS_NOT_SUPPORTED
        )

        return
    end


    --------------------------------------------------------
    -- Create
    --------------------------------------------------------

    CreateCopyFrame()


    --------------------------------------------------------
    -- Get text
    --------------------------------------------------------

    local text =
        GetChatText(chatFrame)


    --------------------------------------------------------
    -- Set text.
    --------------------------------------------------------

    copyEditBox:SetText(
        text
    )

	
    --------------------------------------------------------
    -- Source name.
    --------------------------------------------------------

    local frameName =
        chatFrame.name

    if not frameName
        and chatFrame.GetName
    then

        frameName =
            chatFrame:GetName()

    end

    if not frameName then
        frameName = "Chat"
    end


    --------------------------------------------------------
    -- Title.
    --------------------------------------------------------

    copyFrame.title:SetText(
        L.CHAT_COPY_2
        .. frameName
    )


    --------------------------------------------------------
    -- Show.
    --------------------------------------------------------

    copyFrame:Show()


    --------------------------------------------------------
    -- Make sure layout is updated.
    --------------------------------------------------------

    copyEditBox:SetWidth(
        copyScrollFrame:GetWidth()
    )

    UpdateCopyScroll()


    --------------------------------------------------------
    -- Start at bottom.
    --------------------------------------------------------

    ScrollCopyToBottom()


    --------------------------------------------------------
    -- Focus and Highlight everything.
    --------------------------------------------------------
	
	copyEditBox:SetFocus()
	copyEditBox:SetCursorPosition(0)
	copyEditBox:HighlightText(0, -1)
	
end


------------------------------------------------------------
-- Copy button
------------------------------------------------------------

local function CreateCopyButton(chatFrame)

    if not chatFrame then
        return
    end

    if not chatFrame.GetMessageInfo
        or not chatFrame.GetNumMessages
    then
        return
    end

    if IsCombatLogFrame(chatFrame) then
        return
    end


    --------------------------------------------------------
    -- Existing button.
    --------------------------------------------------------

    if chatFrame.yToolsCopyChatButton then

        local button =
            chatFrame.yToolsCopyChatButton

        button:Show()

        button:EnableMouse(
            true
        )

        SetCopyIconHighlight(
            button,
            false
        )

        return
    end


    --------------------------------------------------------
    -- Create button.
    --------------------------------------------------------

    local button =
        CreateFrame(
            "Button",
            nil,
            chatFrame
        )

    button:SetSize(
        COPY_BUTTON_SIZE,
        COPY_BUTTON_SIZE
    )

    button:SetPoint(
        "TOPRIGHT",
        chatFrame,
        "TOPRIGHT",
        -2,
        -2
    )

    button:SetFrameLevel(
        chatFrame:GetFrameLevel() + 10
    )

    button.chatFrame =
        chatFrame


    --------------------------------------------------------
    -- Icon.
    --------------------------------------------------------

    CreateCopyIcon(
        button
    )

    SetCopyIconHighlight(
        button,
        false
    )


    --------------------------------------------------------
    -- Tooltip.
    --------------------------------------------------------

    button:SetScript(
        "OnEnter",
        function(self)

            SetCopyIconHighlight(
                self,
                true
            )

            GameTooltip:SetOwner(
                self,
                "ANCHOR_TOP"
            )

            GameTooltip:SetText(
                L.COPY_CHAT
            )

            GameTooltip:AddLine(
                L.COPY_ALL_CHAT_MESSAGES_FROM_THIS_WINDOW,
                1,
                1,
                1
            )

            GameTooltip:Show()
        end
    )


    button:SetScript(
        "OnLeave",
        function(self)

            SetCopyIconHighlight(
                self,
                false
            )

            GameTooltip:Hide()
        end
    )


    --------------------------------------------------------
    -- Click.
    --------------------------------------------------------

    button:SetScript(
        "OnClick",
        function(self)

            if not module:IsEnabled() then
                return
            end

            ShowCopyChat(
                self.chatFrame
            )
        end
    )


    --------------------------------------------------------
    -- Store.
    --------------------------------------------------------

    chatFrame.yToolsCopyChatButton =
        button

    hookedChatFrames[chatFrame] =
        true
end


------------------------------------------------------------
-- Setup one chat frame
------------------------------------------------------------

local function SetupChatFrame(chatFrame)

    if not chatFrame then
        return
    end

    if not module:IsEnabled() then
        return
    end

    CreateCopyButton(
        chatFrame
    )
end


------------------------------------------------------------
-- Setup all chat frames
------------------------------------------------------------

local function SetupChatFrames()

    if not module:IsEnabled() then
        return
    end


    --------------------------------------------------------
    -- Normal chat frames.
    --------------------------------------------------------

    for index = 1, 20 do

        local chatFrame =
            _G["ChatFrame" .. index]

        if chatFrame then

            SetupChatFrame(
                chatFrame
            )

        end
    end


    --------------------------------------------------------
    -- Temporary / whisper windows.
    --------------------------------------------------------

    if CHAT_FRAMES then

        for _, frameName in pairs(CHAT_FRAMES) do

            local chatFrame =
                _G[frameName]

            if chatFrame then

                SetupChatFrame(
                    chatFrame
                )

            end
        end
    end
end


------------------------------------------------------------
-- Temporary chat windows
------------------------------------------------------------

local function HookTemporaryChatWindows()

    if temporaryWindowHooked then
        return
    end

    if type(FCF_OpenTemporaryWindow) == "function" then

        temporaryWindowHooked = true

        hooksecurefunc(
            "FCF_OpenTemporaryWindow",
            function()

                if not module:IsEnabled() then
                    return
                end

                SetupChatFrames()

            end
        )
    end
end


------------------------------------------------------------
-- Disable
------------------------------------------------------------

local function DisableCopyChat()

    if copyFrame then
        copyFrame:Hide()
    end

    for chatFrame in pairs(hookedChatFrames) do

        local button =
            chatFrame.yToolsCopyChatButton

        if button then

            button:Hide()

            button:EnableMouse(
                false
            )

        end
    end
end


------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------

function module:OnEnable()

    HookTemporaryChatWindows()

    SetupChatFrames()
end


function module:OnDisable()

    DisableCopyChat()
end


------------------------------------------------------------
-- Events
------------------------------------------------------------

module:RegisterEvent(
    "PLAYER_ENTERING_WORLD",
    function()

        HookTemporaryChatWindows()

        SetupChatFrames()

    end
)


module:RegisterEvent(
    "UPDATE_CHAT_WINDOWS",
    function()

        SetupChatFrames()

    end
)


module:RegisterEvent(
    "UPDATE_FLOATING_CHAT_WINDOWS",
    function()

        SetupChatFrames()

    end
)


------------------------------------------------------------
-- Slash command
------------------------------------------------------------

module:RegisterSlashCommand(
    "copychat",
    function()

        ShowCopyChat(
            SELECTED_CHAT_FRAME
            or DEFAULT_CHAT_FRAME
        )

    end,
    L.COPY_THE_CONTENTS_OF_THE_SELECTED_CHAT_WINDOW
)
