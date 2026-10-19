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
local addonName = ...
local yTools = _G.yTools
local optionsTitle = "|cff4b7dccy|rTools"

if not yTools then
    return
end


------------------------------------------------------------
-- Options state
------------------------------------------------------------

local optionsPanel
local optionsCategory
local moduleScrollFrame
local moduleContent
local moduleControls = {}
local categoryControls = {}
local categoryToggle
local moduleCategories = {}
-- SavedVariables can replace their global table after this file is evaluated.
-- Resolve the account table when building the options list, after addon loading.
local function GetCategoryCollapsed()
    local optionsDB = yTools:GetDB()
    optionsDB.categoryCollapsed = type(optionsDB.categoryCollapsed)=="table" and optionsDB.categoryCollapsed or {}
    return optionsDB.categoryCollapsed
end
local BuildModuleControls


------------------------------------------------------------
-- Layout constants
------------------------------------------------------------

local LEFT = 32
local TOP = -24

local HEADER_GAP = 60

local MODULE_LABEL_X = 32
local MODULE_LABEL_Y = -90

local MODULE_OFFSET_X = 0
local MODULE_OFFSET_Y = 30

local MODULE_ROW_HEIGHT = 50

local TITLE_OFFSET_X = 20
local TITLE_OFFSET_Y = 2

local DESCRIPTION_OFFSET_X = 0
local DESCRIPTION_OFFSET_Y = -6

local PANEL_WIDTH = 700
local PANEL_HEIGHT = 560

local SCROLL_TOP = -115
local SCROLL_BOTTOM = 20

local SCROLLBAR_WIDTH = 24


------------------------------------------------------------
-- Create module row
------------------------------------------------------------

local function CreateModuleRow(
    parent,
    module,
    yOffset
)
    local row = CreateFrame(
        "Frame",
        nil,
        parent
    )

    row:SetPoint(
        "TOPLEFT",
        parent,
        "TOPLEFT",
        LEFT + MODULE_OFFSET_X,
        yOffset + MODULE_OFFSET_Y
    )

    row:SetPoint(
        "RIGHT",
        parent,
        "RIGHT",
        -32 + MODULE_OFFSET_X,
        0
    )

    row:SetHeight(
        MODULE_ROW_HEIGHT
    )

    row.module = module


    --------------------------------------------------------
    -- Default Blizzard checkbox
    --------------------------------------------------------

    local checkbox = CreateFrame(
        "CheckButton",
        nil,
        row,
        "InterfaceOptionsCheckButtonTemplate"
    )

    checkbox:SetPoint(
        "TOPLEFT",
        row,
        "TOPLEFT",
        8,
        0
    )

    checkbox:SetChecked(
        module:IsEnabled()
    )

    checkbox:SetHitRectInsets(
        0,
        -400,
        0,
        -4
    )

    row.checkbox = checkbox


    --------------------------------------------------------
    -- Module title
    --------------------------------------------------------

    local title = row:CreateFontString(
        nil,
        "ARTWORK",
        "GameFontNormal"
    )

    title:SetPoint(
        "TOPLEFT",
        checkbox,
        "TOPRIGHT",
        TITLE_OFFSET_X,
        TITLE_OFFSET_Y
    )

    title:SetText(
        (module:GetTitle():match("^.-%s*>%s*(.+)$") or module:GetTitle())
    )

    row.title = title


    --------------------------------------------------------
    -- Module description
    --------------------------------------------------------

    local description = row:CreateFontString(
        nil,
        "ARTWORK",
        "GameFontHighlightSmall"
    )

    description:SetPoint(
        "TOPLEFT",
        title,
        "BOTTOMLEFT",
        DESCRIPTION_OFFSET_X,
        DESCRIPTION_OFFSET_Y
    )

    description:SetPoint(
        "RIGHT",
        row,
        "RIGHT",
        0,
        0
    )

    description:SetJustifyH("LEFT")
    description:SetJustifyV("TOP")
    description:SetWordWrap(true)

    description:SetText(
        module:GetDescription()
    )

    row.description = description


    --------------------------------------------------------
    -- Checkbox click
    --------------------------------------------------------

    checkbox:SetScript(
        "OnClick",
        function(self)
            if self:GetChecked() then
                module:Enable()
            else
                module:Disable()
            end
        end
    )


    return row
end


------------------------------------------------------------
-- Clear rows
------------------------------------------------------------

local function ClearModuleControls()
    for _, row in ipairs(moduleControls) do
        row:Hide()
        row:SetParent(nil)
    end

    wipe(moduleControls)
    for _, header in ipairs(categoryControls) do header:Hide(); header:SetParent(nil) end
    wipe(categoryControls)
end


------------------------------------------------------------
-- Sort modules
--
-- Modules are sorted by their display title.
-- If a title is unavailable, the registered module name
-- is used instead.
------------------------------------------------------------

local function SortModules(modules)
    table.sort(
        modules,
        function(a, b)
            local aTitle =
                a:GetTitle()
                or a:GetName()
                or ""

            local bTitle =
                b:GetTitle()
                or b:GetName()
                or ""

            return aTitle:lower() < bTitle:lower()
        end
    )
end


------------------------------------------------------------
-- Build module list
------------------------------------------------------------

BuildModuleControls = function()
    if not optionsPanel or not moduleScrollFrame or not moduleContent then return end
    local previousScroll = moduleScrollFrame:GetVerticalScroll()
    ClearModuleControls()
    local _, order = yTools:GetModules()
    local groups, categories, categoryNames = {}, {}, {}
    for _, id in ipairs(order) do
        local module = yTools:GetModule(id)
        local category = module:GetTitle():match("^(.-)%s*>") or "UI"
        category = category:match("^%s*(.-)%s*$")
        if category == "Utilities" then category = "Utility" end
        local categoryKey = category:lower()
        categoryNames[categoryKey] = categoryNames[categoryKey] or category
        category = categoryNames[categoryKey]
        if not groups[category] then groups[category] = {}; categories[#categories + 1] = category end
        table.insert(groups[category], module)
    end
    table.sort(categories, function(a,b) return a:lower() < b:lower() end)
    moduleCategories = categories
    local collapsed = GetCategoryCollapsed()
    local offset = -12
    for _, category in ipairs(categories) do
        local categoryName = category
        local modules = groups[category]
        if collapsed[category] == nil then collapsed[category] = true end
        SortModules(modules)
        local header = CreateFrame("Button", nil, moduleContent)
        header:SetPoint("TOPLEFT", moduleContent, "TOPLEFT", LEFT - 4, offset)
        header:SetPoint("RIGHT", moduleContent, "RIGHT", -32, 0)
        header:SetHeight(26)
        header:SetNormalAtlas("common-button-list-collapseExpand")
        header:SetHighlightAtlas("questlog-header-glow-yellow")
        local highlight=header:GetHighlightTexture()
        highlight:ClearAllPoints()
        highlight:SetPoint("TOPLEFT",header,"TOPLEFT",0,3)
        highlight:SetPoint("BOTTOMRIGHT",header,"BOTTOMRIGHT",0,3)
        header:SetScript("OnClick",function()
            collapsed[categoryName] = not collapsed[categoryName]
            BuildModuleControls()
        end)
        categoryControls[#categoryControls + 1] = header
        local toggle = CreateFrame("Button", nil, header, "CollapseButtonTemplate")
        toggle:SetSize(16,16)
        toggle:SetPoint("LEFT",7,0)
        toggle:UpdateCollapsedState(collapsed[category])
        toggle.Icon:ClearAllPoints();toggle.Icon:SetPoint("CENTER");toggle.Icon:SetSize(12,collapsed[category] and 12 or 3)
        toggle:EnableMouse(false)
        toggle:SetScript("OnClick", function()
            collapsed[categoryName] = not collapsed[categoryName]
            BuildModuleControls()
        end)
        local label = header:CreateFontString(nil,"ARTWORK","GameFontNormal")
        label:SetPoint("LEFT",toggle,"RIGHT",8,0)
        label:SetText(category)
        local count = header:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
        count:SetPoint("RIGHT",-8,0)
        count:SetText("(" .. #modules .. ")")
        offset = offset - 32
        if not collapsed[category] then
            for _, module in ipairs(modules) do
                local row = CreateModuleRow(moduleContent,module,offset - MODULE_OFFSET_Y)
                moduleControls[#moduleControls + 1] = row
                offset = offset - MODULE_ROW_HEIGHT
            end
        end
        offset = offset - 10
    end
    if categoryToggle then
        local allCollapsed = true
        for _, category in ipairs(categories) do
            if not collapsed[category] then allCollapsed = false; break end
        end
        categoryToggle:UpdateCollapsedState(allCollapsed)
        categoryToggle.Icon:ClearAllPoints()
        categoryToggle.Icon:SetPoint("CENTER")
        categoryToggle.Icon:SetSize(12, allCollapsed and 12 or 3)
    end
    moduleContent:SetHeight(math.max(50, -offset + 20))
    moduleScrollFrame:UpdateScrollChildRect()
    moduleScrollFrame:SetVerticalScroll(math.min(previousScroll, math.max(0,moduleScrollFrame:GetVerticalScrollRange())))
end


------------------------------------------------------------
-- Create options page
------------------------------------------------------------

function yTools:CreateOptionsPanel()
    if optionsPanel then
        return
    end


    --------------------------------------------------------
    -- Main canvas
    --------------------------------------------------------

    optionsPanel = CreateFrame("Frame")

    optionsPanel:SetSize(
        PANEL_WIDTH,
        PANEL_HEIGHT
    )


    --------------------------------------------------------
    -- Header
    --------------------------------------------------------

    local title =
        optionsPanel:CreateFontString(
            nil,
            "ARTWORK",
            "GameFontNormalLarge"
        )

    title:SetPoint(
        "TOPLEFT",
        optionsPanel,
        "TOPLEFT",
        LEFT,
        TOP
    )

    title:SetText(optionsTitle)


    --------------------------------------------------------
    -- Header description
    --------------------------------------------------------

    local subtitle =
        optionsPanel:CreateFontString(
            nil,
            "ARTWORK",
            "GameFontHighlight"
        )

    subtitle:SetPoint(
        "TOPLEFT",
        title,
        "BOTTOMLEFT",
        0,
        -6
    )

    subtitle:SetText(
        L.ENABLE_OR_DISABLE_INDIVIDUAL_YTOOLS_MODULES_YTOOLS_HELP
    )


    --------------------------------------------------------
    -- Modules heading
    --------------------------------------------------------

    local modulesTitle =
        optionsPanel:CreateFontString(
            nil,
            "ARTWORK",
            "GameFontNormal"
        )

    modulesTitle:SetPoint(
        "TOPLEFT",
        optionsPanel,
        "TOPLEFT",
        MODULE_LABEL_X,
        MODULE_LABEL_Y
    )

    modulesTitle:SetText(L.MODULES)

    categoryToggle = CreateFrame("Button", nil, optionsPanel, "CollapseButtonTemplate")
    categoryToggle:SetSize(16,16)
    categoryToggle:SetPoint("LEFT", modulesTitle, "RIGHT", 8, 0)
    categoryToggle:SetScript("OnClick", function()
        local collapsed = GetCategoryCollapsed()
        local anyExpanded = false
        for _, category in ipairs(moduleCategories) do
            if not collapsed[category] then anyExpanded = true; break end
        end
        for _, category in ipairs(moduleCategories) do
            collapsed[category] = anyExpanded
        end
        BuildModuleControls()
    end)


    --------------------------------------------------------
    -- Scroll frame
    --------------------------------------------------------

    moduleScrollFrame = CreateFrame(
        "ScrollFrame",
        nil,
        optionsPanel,
        "UIPanelScrollFrameTemplate"
    )

    moduleScrollFrame:SetPoint(
        "TOPLEFT",
        optionsPanel,
        "TOPLEFT",
        0,
        SCROLL_TOP
    )

    moduleScrollFrame:SetPoint(
        "BOTTOMRIGHT",
        optionsPanel,
        "BOTTOMRIGHT",
        -SCROLLBAR_WIDTH,
        SCROLL_BOTTOM
    )


    --------------------------------------------------------
    -- Scroll child
    --------------------------------------------------------

    moduleContent = CreateFrame(
        "Frame",
        nil,
        moduleScrollFrame
    )

    moduleContent:SetWidth(
        PANEL_WIDTH - LEFT - 60
    )

    moduleContent:SetHeight(
        1
    )

    moduleScrollFrame:SetScrollChild(
        moduleContent
    )


    --------------------------------------------------------
    -- Register Settings category
    --------------------------------------------------------

    if not Settings
        or not Settings.RegisterCanvasLayoutCategory
        or not Settings.RegisterAddOnCategory
    then
        yTools:Print(
            "|cffff0000yTools:|r "
            .. L.SETTINGS_API_IS_UNAVAILABLE
        )

        return
    end


    optionsCategory =
        Settings.RegisterCanvasLayoutCategory(
            optionsPanel,
            optionsTitle
        )

    if optionsCategory.GetID then
        optionsPanel.yToolsCategoryID =
            optionsCategory:GetID()
    else
        optionsPanel.yToolsCategoryID =
            optionsCategory.ID
    end

    Settings.RegisterAddOnCategory(
        optionsCategory
    )


    self.optionsCategory = optionsCategory
    local optionPages = {
        { id = "CastBars", title = L.CASTBARS_OPTIONS },
        { id = "TooltipVendorPrice", title = L.TOOLTIP_VENDOR_PRICE },
        { id = "BagSlots", title = L.BAG_SLOTS_OPTIONS },
        { id = "CharacterStats", title = L.CHARACTERSTATS_OPTIONS },
        { id = "Macro", title = L.MACRO_MANAGER },
        { id = "Notepad", title = L.NOTEPAD },
        { id = "PlayerBorder", title = L.PLAYER_BORDER },
        { id = "TooltipTargetTarget", title = L.TARGET_TARGET_OPTIONS },
        { id = "Fishing", title = L.FISHING_OPTIONS },
    }
    table.sort(optionPages, function(first, second)
        local function SortTitle(text)
            return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
        end
        return SortTitle(first.title) < SortTitle(second.title)
    end)
    for _, page in ipairs(optionPages) do
        local optionModule = self:GetModule(page.id)
        if optionModule and optionModule.CreateOptionsPanel then
            optionModule:CreateOptionsPanel(optionsCategory)
        end
    end

    -- Start with the module subpages visible; users can still collapse them.
    if optionsCategory.SetExpanded then
        optionsCategory:SetExpanded(true)
    end

    --------------------------------------------------------
    -- Build rows
    --------------------------------------------------------

    BuildModuleControls()
end


------------------------------------------------------------
-- Refresh checkbox states
------------------------------------------------------------

function yTools:RefreshOptionsPanel()
    for _, row in ipairs(moduleControls) do
        local module = row.module

        if module and row.checkbox then
            row.checkbox:SetChecked(
                module:IsEnabled()
            )
        end
    end
end


------------------------------------------------------------
-- Open options
------------------------------------------------------------

function yTools:OpenOptionsPanel()
    if not optionsPanel then
        self:CreateOptionsPanel()
    end

    if not optionsCategory then
        return
    end

    local categoryID

    if optionsCategory.GetID then
        categoryID =
            optionsCategory:GetID()
    else
        categoryID =
            optionsCategory.ID
            or optionsPanel.yToolsCategoryID
    end

    if Settings
        and Settings.OpenToCategory
    then
        Settings.OpenToCategory(
            categoryID
        )
    end
end
