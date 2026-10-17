local yTools = _G.yTools
local L = yTools.L

local module = yTools:RegisterModule("Notepad", {
    title = L.UTILITY_NOTEPAD,
    description = L.NOTEPAD_DESCRIPTION,
    defaultEnabled = true,
})

local button, frame, editBox, scrollFrame, measureText, scrollBar, scrollContent
local syncingScroll = false
local updatingLayout = false
local activeTab = 2 -- Keep existing character notes selected initially.
local loadingNotes = false
local NOTEPAD_ICON = "Interface\\Icons\\INV_Misc_Note_05"

local function GetCharacterDB()
    yToolsNotepadDB = yToolsNotepadDB or {}
    return yToolsNotepadDB
end

local function GetNotesDB()
    if activeTab == 1 then
        yToolsNotepadAccountDB = yToolsNotepadAccountDB or {}
        return yToolsNotepadAccountDB
    end
    return GetCharacterDB()
end

local function PositionMinimapButton()
    if not button then return end
    local db = GetCharacterDB()
    if db.buttonFree and db.buttonPosition then
        local position = db.buttonPosition
        button:SetParent(UIParent)
        button:ClearAllPoints()
        button:SetPoint(position[1],UIParent,position[2],position[3],position[4])
        return
    end
    button:SetParent(Minimap)
    button:SetFrameStrata("HIGH")
    button:SetFrameLevel(Minimap:GetFrameLevel()+8)
    local angle = db.buttonAngle or 225
    local radians = math.rad(angle)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER",
        (Minimap:GetWidth()/2+8)*math.cos(radians),
        (Minimap:GetHeight()/2+8)*math.sin(radians))
end

local function SavePosition(widget, key)
    local point, _, relativePoint, x, y = widget:GetPoint()
    GetCharacterDB()[key] = { point, relativePoint, x, y }
end

local function RestorePosition(widget, key)
    local position = GetCharacterDB()[key]
    widget:ClearAllPoints()
    if position then
        widget:SetPoint(position[1], UIParent, position[2], position[3], position[4])
    else
        if key == "buttonPosition" then
            widget:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -8, -42)
        else
            widget:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -13)
        end
    end
end

local function SetScroll(value)
    local maximum = math.max(0, editBox:GetHeight() - scrollFrame:GetHeight())
    local offset = math.max(0, math.min(maximum, value))
    local wasSyncing = syncingScroll
    syncingScroll = true
    scrollFrame:SetVerticalScroll(offset)
    if scrollBar and not wasSyncing then
        scrollBar:SetScrollPercentage(maximum > 0 and offset / maximum or 0, true)
    end
    syncingScroll = wasSyncing
end

local function UpdateLayout()
    if updatingLayout or not editBox or not measureText then return end
    updatingLayout = true
    local width = math.max(1, scrollFrame:GetWidth())
    if editBox:GetWidth() ~= width then editBox:SetWidth(width) end
    measureText:SetWidth(math.max(1, width - 12))
    -- Include the final empty line when the notes end with a newline.
    measureText:SetText((editBox:GetText() or "") .. "\n ")
    local height = math.max(scrollFrame:GetHeight(), measureText:GetStringHeight() + 12)
    if editBox:GetHeight() ~= height then editBox:SetHeight(height) end
    scrollContent:SetSize(width, height)
    scrollFrame:UpdateScrollChildRect()
    if scrollBar then
        local height = math.max(1, editBox:GetHeight())
        local maximum = math.max(0, height - scrollFrame:GetHeight())
        scrollBar:SetVisibleExtentPercentage(math.min(1, scrollFrame:GetHeight() / height))
        scrollBar:SetPanExtentPercentage(maximum > 0 and math.min(1, 42 / maximum) or 1)
    end
    SetScroll(scrollFrame:GetVerticalScroll())
    updatingLayout = false
end

local function CreateNotepad()
    if frame then return end
    activeTab = GetCharacterDB().activeTab == 1 and 1 or 2

    frame = CreateFrame("Frame", "yToolsNotepadFrame", UIParent, "PortraitFrameTemplate")
    frame:SetSize(500 * 2 / 3, 400)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    RestorePosition(frame, "framePosition")
    -- Keep this standalone editor in normal frame levels. The talent planner's
    -- very high decorative levels are not needed for a text input window.
    frame:SetFrameLevel(10)
    frame.NineSlice:SetFrameLevel(11)
    frame.PortraitContainer:SetFrameLevel(10)
    frame.TitleContainer:SetFrameLevel(13)
    frame.CloseButton:SetFrameLevel(14)
    frame:EnableMouse(true)
    frame:SetTitle(L.NOTEPAD)
    frame:SetPortraitToAsset(NOTEPAD_ICON)

    -- The same single-page artwork used by Forever's compact spellbook.
    frame.Bg:SetHorizTile(false)
    frame.Bg:SetVertTile(false)
    frame.Bg:SetAtlas("spellbook-Page-Right-C60", false)
    frame.Bg:ClearAllPoints()
    frame.Bg:SetPoint("TOPLEFT", 2, -21)
    frame.Bg:SetPoint("BOTTOMRIGHT", -21, 2)
    -- Restore the spellbook's header strip for the two note tabs.
    frame.Bg:SetTexCoord(0, 1, 0, 1)
    frame.scrollGutter = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
    frame.scrollGutter:SetPoint("TOPLEFT", frame.Bg, "TOPRIGHT")
    frame.scrollGutter:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    frame.scrollGutter:SetAtlas("_UI-Frame-TitleTileBg", false)
    -- A faint additive copy brightens the artwork without washing out its detail.
    frame.backgroundLight = frame:CreateTexture(nil, "BACKGROUND", nil, -5)
    frame.backgroundLight:SetAllPoints(frame.Bg)
    frame.backgroundLight:SetAtlas("spellbook-Page-Right-C60", false)
    frame.backgroundLight:SetTexCoord(0, 1, 0, 1)
    frame.backgroundLight:SetBlendMode("ADD")
    frame.backgroundLight:SetAlpha(0.07)
    frame.TopTileStreaks:Hide()
    frame:Hide()

    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 58, 0)
    titleBar:SetPoint("TOPRIGHT", -32, 0)
    titleBar:SetHeight(28)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SavePosition(frame, "framePosition")
    end)

    scrollFrame = CreateFrame("ScrollFrame", "yToolsNotepadScrollFrame", frame)
    -- Keep native edit-box selection/caret above the portrait frame artwork.
    local contentLevel = frame.NineSlice:GetFrameLevel() + 1
    scrollFrame:SetFrameLevel(contentLevel)
    scrollFrame:SetPoint("TOPLEFT", 18, -60)
    scrollFrame:SetPoint("BOTTOMRIGHT", -27, 12)

    scrollBar = CreateFrame("EventFrame", "yToolsNotepadScrollBar", frame, "MinimalScrollBar")
    scrollBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -9.5, -26)
    scrollBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -9.5, 6)
    scrollBar:SetFrameLevel(contentLevel)
    scrollBar:Init(1, 1)
    scrollBar:RegisterCallback("OnScroll", function(_, percentage)
        if syncingScroll then return end
        syncingScroll = true
        SetScroll(percentage * math.max(0, editBox:GetHeight() - scrollFrame:GetHeight()))
        syncingScroll = false
    end, module)

    -- Keep the EditBox inside a normal scroll child, so its native caret and
    -- selection are rendered with the same clipping/transform as its text.
    scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetSize(500 * 2 / 3 - 45, 326)
    scrollContent:SetFrameLevel(contentLevel + 1)
    scrollFrame:SetScrollChild(scrollContent)
    editBox = CreateFrame("EditBox", nil, scrollContent)
    editBox:SetFrameLevel(contentLevel + 2)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(0)
    editBox:SetFontObject(ChatFontNormal)
    local fontPath, _, fontFlags = SystemFont_Large:GetFont()
    editBox:SetFont(fontPath, 14, fontFlags)
    editBox:SetShadowOffset(0, 0)
    if SPELLBOOK_FONT_COLOR then
        editBox:SetTextColor(SPELLBOOK_FONT_COLOR:GetRGBA())
    else
        editBox:SetTextColor(0, 0, 0, 1)
    end
    editBox:SetJustifyH("LEFT")
    editBox:SetJustifyV("TOP")
    editBox:SetTextInsets(6, 6, 6, 6)
    editBox:SetWidth(500 * 2 / 3 - 45)
    editBox:SetHeight(326)
    editBox:EnableMouse(true)
    editBox:EnableKeyboard(true)
    editBox:SetPropagateKeyboardInput(false)
    editBox:SetBlinkSpeed(0.5)
    editBox:SetHighlightColor(0.75, 0.85, 1, 0.4)
    editBox:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, 0)
    scrollContent.editBox = editBox

    local function FocusNotes()
        if not editBox:HasFocus() then editBox:SetFocus() end
    end
    -- Focus from blank space too, without an overlay that intercepts dragging
    -- inside the native EditBox or changes its cursor/selection.
    local paperFocus = CreateFrame("Frame", nil, frame)
    paperFocus:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -55)
    paperFocus:SetPoint("BOTTOMRIGHT", frame.Bg, "BOTTOMRIGHT")
    paperFocus:SetFrameLevel(contentLevel - 1)
    paperFocus:EnableMouse(true)
    paperFocus:SetScript("OnMouseDown", FocusNotes)
    scrollFrame:EnableMouse(true)
    scrollFrame:SetScript("OnMouseDown", FocusNotes)
    scrollContent:EnableMouse(true)
    scrollContent:SetScript("OnMouseDown", FocusNotes)
    editBox:SetScript("OnMouseDown", FocusNotes)

    measureText = scrollFrame:CreateFontString(nil, "ARTWORK")
    measureText:SetFontObject(SystemFont_Large)
    measureText:SetFont(fontPath, 14, fontFlags)
    measureText:SetWordWrap(true)
    measureText:Hide()

    editBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        if not loadingNotes then GetNotesDB().text = text end
        if self.layoutText ~= text then
            self.layoutText = text
            UpdateLayout()
        end
    end)
    editBox:SetScript("OnCursorChanged", function(self, x, y, _, height)
        -- Scrolling/reflow can also fire this event. Never resize the EditBox
        -- here: doing so disrupts its native caret and mouse selection.
        local position = self:GetCursorPosition()
        local changed = self.lastCursorPosition ~= position
            or self.lastCursorX ~= x or self.lastCursorY ~= y
        self.lastCursorPosition, self.lastCursorX, self.lastCursorY = position, x, y
        if updatingLayout or syncingScroll or not changed then return end
        local top = -y
        local current = scrollFrame:GetVerticalScroll()
        if top < current then
            SetScroll(top)
        elseif top + height + 12 > current + scrollFrame:GetHeight() then
            SetScroll(top + height + 12 - scrollFrame:GetHeight())
        end
    end)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local function OnMouseWheel(_, delta)
        SetScroll(scrollFrame:GetVerticalScroll() - delta * 42)
    end
    editBox:EnableMouseWheel(true)
    editBox:SetScript("OnMouseWheel", OnMouseWheel)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", OnMouseWheel)
    scrollFrame:SetScript("OnSizeChanged", UpdateLayout)
    frame:SetScript("OnShow", function()
        UpdateLayout()
        editBox:ClearFocus()
    end)
    frame:SetScript("OnHide", function()
        editBox:ClearFocus()
        frame:StopMovingOrSizing()
    end)
    -- Lay out the two tabs explicitly; native category-tab layout can resize
    -- their artwork after creation and reintroduce the narrow character tab.
    local name, surname = (UnitNameUnmodified or UnitName)("player")
    if type(surname) == "string" and surname ~= ""
        and RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled() then
        local separator = Constants and Constants.CharacterNameSeparatorConsts
            and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR or " "
        local ending = separator .. surname
        if name:sub(-#ending) ~= ending then name = name .. ending end
    elseif GetUnitName then
        name = GetUnitName("player", false) or name
    end
    local tabs = CreateFrame("Frame", nil, frame)
    frame.tabs = tabs
    tabs:SetFrameLevel(contentLevel + 1)
    tabs:SetPoint("TOPLEFT", frame, "TOPLEFT", 62, -25)
    tabs:SetSize(frame:GetWidth() - 112, 29)
    tabs.buttons = {}
    function tabs:SetTabSelectedCallback(callback) self.callback = callback end
    function tabs:SetTab(tabID)
        self.callback(tabID)
        self.selectedTabID = tabID
        for id, tab in ipairs(self.buttons) do
            local selected = id == tabID
            local atlases = selected
                and { "uiframe-activetab-left", "_uiframe-activetab-center", "uiframe-activetab-right" }
                or { "uiframe-tab-left", "_uiframe-tab-center", "uiframe-tab-right" }
            for index, texture in ipairs(tab.artwork) do
                texture:SetAtlas(atlases[index], false)
                texture:SetTexCoord(0, 1, 1, 0)
                texture:SetDesaturated(false)
                texture:SetVertexColor(1, 1, 1)
            end
            tab.Text:SetTextColor(1, selected and 1 or 0.82, selected and 1 or 0)
        end
    end
    local accountWidth = 78
    local gap = 7
    for id, label in ipairs({ L.NOTEPAD_ACCOUNT, name }) do
        local tabID = id
        local tab = CreateFrame("Button", nil, tabs)
        tabs.buttons[id] = tab
        tab:SetSize(id == 1 and accountWidth or tabs:GetWidth() - accountWidth - gap, 29)
        tab:SetPoint("TOPLEFT", tabs, "TOPLEFT", id == 1 and 0 or accountWidth + gap, 0)
        tab.artwork = {}
        for index, atlas in ipairs({ "uiframe-tab-left", "_uiframe-tab-center", "uiframe-tab-right" }) do
            local texture = tab:CreateTexture(nil, "BACKGROUND")
            texture:SetAtlas(atlas, false)
            -- Flip vertically only, preserving the original highlighted artwork.
            texture:SetTexCoord(0, 1, 1, 0)
            texture:SetHeight(29)
            tab.artwork[index] = texture
        end
        local left, middle, right = unpack(tab.artwork)
        left:SetWidth(12)
        right:SetWidth(12)
        left:SetPoint("TOPLEFT")
        right:SetPoint("TOPRIGHT")
        middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
        middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
        tab.Text = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tab.Text:SetText(label)
        tab.Text:SetPoint("CENTER", 0, -1)
        tab.Text:SetScale(math.min(1, (tab:GetWidth() - 18) / math.max(1, tab.Text:GetStringWidth())))
        tab:SetScript("OnClick", function() tabs:SetTab(tabID) end)
    end
    tabs:SetTabSelectedCallback(function(tabID)
        editBox:ClearFocus()
        activeTab = tabID
        GetCharacterDB().activeTab = tabID
        loadingNotes = true
        editBox:SetText(GetNotesDB().text or "")
        editBox:SetCursorPosition(0)
        editBox:HighlightText(0, 0)
        loadingNotes = false
        UpdateLayout()
        SetScroll(0)
    end)
    tabs:SetTab(activeTab)
end

local function ToggleNotepad()
    CreateNotepad()
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

local function CreateButton()
    if button then return end
    button = CreateFrame("Button", "yToolsNotepadButton", Minimap)
    button:SetFrameStrata("HIGH")
    button:SetFrameLevel(Minimap:GetFrameLevel()+8)
    button:SetSize(31, 31)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(20, 20)
    button.icon:SetPoint("TOPLEFT", 7, -6)
    button.icon:SetTexture(NOTEPAD_ICON)
    button.mask = button:CreateMaskTexture(nil, "OVERLAY")
    button.mask:SetSize(22, 22)
    button.mask:SetPoint("CENTER", button.icon, "CENTER")
    button.mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask",
        "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    button.icon:AddMaskTexture(button.mask)
    button.ring = button:CreateTexture(nil, "OVERLAY")
    button.ring:SetPoint("TOPLEFT", 0, 0)
    button.ring:SetSize(54,54)
    button.ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button.icon)
    highlight:SetTexture(NOTEPAD_ICON)
    highlight:AddMaskTexture(button.mask)
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.3)
    button:SetHighlightTexture(highlight)
    button:SetMovable(true)
    button:SetClampedToScreen(true)
    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    PositionMinimapButton()
    Minimap:HookScript("OnSizeChanged", PositionMinimapButton)
    local function CanMoveButton()
        return IsControlKeyDown() and IsAltKeyDown() and IsShiftKeyDown()
    end
    local function StopDragging(self)
        if not self.moving then return end
        self.moving = false
        self:StopMovingOrSizing()
        self:SetScript("OnUpdate", nil)
        if self.freeDragging then
            GetCharacterDB().buttonFree = true
            SavePosition(self,"buttonPosition")
        else
            PositionMinimapButton()
        end
    end
    button:SetScript("OnDragStart", function(self, mouseButton)
        self.freeDragging = CanMoveButton()
        if not self.freeDragging and not IsControlKeyDown() then return end
        self.dragged = true
        self.moving = true
        if self.freeDragging then
            self:SetParent(UIParent)
            self:StartMoving()
        else
            GetCharacterDB().buttonFree = false
        end
        GameTooltip:Hide()
        self:SetScript("OnUpdate", function(owner)
            if owner.freeDragging then
                if not CanMoveButton() then StopDragging(owner) end
                return
            end
            if not IsControlKeyDown() then StopDragging(owner); return end
            local cursorX,cursorY = GetCursorPosition()
            local centerX,centerY = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            GetCharacterDB().buttonAngle = math.deg(math.atan2(cursorY/scale-centerY,cursorX/scale-centerX))
            PositionMinimapButton()
        end)
    end)
    button:SetScript("OnDragStop", StopDragging)
    button:SetScript("OnMouseDown", function(self) self.dragged = false end)
    button:SetScript("OnClick", function(self, mouseButton)
        if self.dragged then return end
        if mouseButton == "RightButton" then
            MenuUtil.CreateContextMenu(self, function(_, root)
                root:CreateTitle(L.NOTEPAD)
                root:CreateButton(L.NOTEPAD_RESET_POSITIONS, function()
                    yTools:DispatchSlashCommand("notepad reset")
                end)
            end)
            return
        end
        ToggleNotepad()
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L.NOTEPAD)
        GameTooltip:AddLine(L.NOTEPAD_BUTTON_TOOLTIP, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnHide", function(self)
        StopDragging(self)
        self:StopMovingOrSizing()
        GameTooltip:Hide()
    end)
end

function module:OnEnable()
    CreateButton()
    button:Show()
    if frame then frame:Hide() end
end

function module:OnDisable()
    if frame then frame:Hide() end
    if button then button:Hide() end
end

module:RegisterSlashCommand("notepad", function(_, arguments)
    local command = (arguments or ""):match("^%s*(.-)%s*$"):lower()
    if command == "toggle" then
        ToggleNotepad()
    elseif command == "show" then
        CreateNotepad()
        frame:Show()
    elseif command == "hide" then
        if frame then frame:Hide() end
    elseif command == "reset" then
        local db = GetCharacterDB()
        db.buttonPosition = nil
        db.buttonAngle = nil
        db.buttonFree = nil
        db.framePosition = nil
        if button then
            button:StopMovingOrSizing()
            button.moving = false
            button:SetScript("OnUpdate", nil)
            PositionMinimapButton()
        end
        if frame then
            frame:StopMovingOrSizing()
            RestorePosition(frame, "framePosition")
        end
        yTools:Print(L.NOTEPAD_RESET_DONE)
    else
        yTools:Print(L.NOTEPAD_HELP_TOGGLE)
        yTools:Print(L.NOTEPAD_HELP_SHOW)
        yTools:Print(L.NOTEPAD_HELP_HIDE)
        yTools:Print(L.NOTEPAD_HELP_RESET)
    end
end, L.NOTEPAD_COMMAND_HELP)
