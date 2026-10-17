local yTools = _G.yTools
local L = yTools.L
local module = yTools:RegisterModule("ClassTrainer", {
    title = L.TOOLS_CLASS_TRAINER,
    description = L.CLASS_TRAINER_DESCRIPTION,
    defaultEnabled = true,
})

local visiting, scanning, queued, captureAll = false, false, false, false
local book, panel, tab, windowState
local rows, headers = {}, {}
local ScheduleScan, InstallTab

local function DB()
    yToolsClassTrainerDB = type(yToolsClassTrainerDB) == "table" and yToolsClassTrainerDB or {}
    local db = yToolsClassTrainerDB
    db.spells = type(db.spells) == "table" and db.spells or {}
    return db
end

local function Public(value)
    return not issecretvalue or not issecretvalue(value)
end

local function IsClassTrainer()
    if IsTradeskillTrainer and IsTradeskillTrainer() then return false end
    if not C_Trainer or not C_Trainer.GetTrainerType or not Enum or not Enum.TrainerType then return false end
    return C_Trainer.GetTrainerType() == Enum.TrainerType.General
end

local function SpellKey(spell)
    if spell.id then return tostring(spell.id) end
    return spell.name .. "\031" .. (spell.rank or "")
end

local function IsLearned(id)
    if not id then return false end
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    return C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id) == true
end

local function Learned(spell)
    return spell.state == "used" or IsLearned(spell.id)
end

local function TooltipLines(data)
    local lines = {}
    for _, line in ipairs(data and data.lines or {}) do
        if Public(line.leftText) and type(line.leftText) == "string" and line.leftText ~= "" then
            lines[#lines + 1] = line.leftText
        end
    end
    return lines
end

local function ReadRequirements(index)
    local requirements = {}
    if GetTrainerServiceSkillReq then
        local name, rank, met = GetTrainerServiceSkillReq(index)
        if Public(name) and type(name) == "string" and name ~= "" then
            requirements[#requirements + 1] = {name = name, rank = rank, met = met == true or met == 1}
        end
    end
    if GetTrainerServiceNumAbilityReq and GetTrainerServiceAbilityReq then
        for abilityIndex = 1, GetTrainerServiceNumAbilityReq(index) do
            local name, met = GetTrainerServiceAbilityReq(index, abilityIndex)
            if Public(name) and type(name) == "string" and name ~= "" then
                requirements[#requirements + 1] = {name = name, met = met == true or met == 1}
            end
        end
    end
    return requirements
end

local function RequirementText(spell)
    local parts = {}
    if spell.level > 1 then
        local met = UnitLevel("player") >= spell.level
        parts[#parts + 1] = string.format(met and TRAINER_REQ_LEVEL or TRAINER_REQ_LEVEL_RED, spell.level)
    end
    for _, requirement in ipairs(spell.requirements or {}) do
        if requirement.rank then
            parts[#parts + 1] = string.format(requirement.met and TRAINER_REQ_SKILL_RANK
                or TRAINER_REQ_SKILL_RANK_RED, requirement.name, requirement.rank)
        else
            parts[#parts + 1] = string.format(requirement.met and TRAINER_REQ_ABILITY
                or TRAINER_REQ_ABILITY_RED, requirement.name)
        end
    end
    if #parts == 0 then return "" end
    return REQUIRES_LABEL .. " " .. table.concat(parts, PLAYER_LIST_DELIMITER)
end

-- Read the modern Forever return order, not the old Classic trainer API.
local function ReadServices()
    local result = {}
    for index = 1, GetNumTrainerServices() do
        local name, state, icon, level, rank, category = GetTrainerServiceInfo(index)
        if Public(name) and type(name) == "string" and name ~= ""
            and (state == "available" or state == "unavailable" or state == "used") then
            local cost, profession = GetTrainerServiceCost(index)
            if not profession then
                local data = C_TooltipInfo and C_TooltipInfo.GetTrainerService(index)
                local id = data and data.id
                if not Public(id) or type(id) ~= "number" or id <= 0 then id = nil end
                local spell = {
                    id = id, name = name, state = state, icon = icon,
                    level = type(level) == "number" and level or 0,
                    rank = type(rank) == "string" and rank or "",
                    category = type(category) == "string" and category or "",
                    cost = type(cost) == "number" and cost or 0,
                    order = index, tooltip = TooltipLines(data), requirements = ReadRequirements(index),
                }
                result[#result + 1] = spell
            end
        end
    end
    return result
end

function module:ScanTrainer(allServices)
    if scanning or not visiting or not self:IsEnabled() or not IsClassTrainer()
        or not GetNumTrainerServices or not GetTrainerServiceInfo or not GetTrainerServiceCost then return end
    scanning = true
    -- Temporarily expose all services, then restore the user's trainer filters.
    -- Filter-generated updates use a read-only pass, so they cannot start a loop.
    local filters = {}
    local ok, services = pcall(function()
        if allServices and GetTrainerServiceTypeFilter and SetTrainerServiceTypeFilter then
            for _, filter in ipairs({ "available", "unavailable", "used" }) do
                local value = GetTrainerServiceTypeFilter(filter)
                filters[filter] = value == true or value == 1
                if not filters[filter] then SetTrainerServiceTypeFilter(filter, true) end
            end
        end
        return ReadServices()
    end)
    for _, filter in ipairs({ "available", "unavailable", "used" }) do
        if filters[filter] == false then SetTrainerServiceTypeFilter(filter, false) end
    end
    scanning = false
    if not ok then
        if geterrorhandler then geterrorhandler()(services) end
        return
    end
    local db = DB()
    -- Merge visits: different class trainers may offer different subsets.
    -- Never erase unseen spells just because a trainer/filter does not list them.
    for _, spell in ipairs(services) do
        local key = SpellKey(spell)
        if spell.id then db.spells[spell.name .. "\031" .. spell.rank] = nil end
        db.spells[key] = spell
    end
    db.scanned = true
    db.trainer = UnitName("npc") or ""
    db.grouped = TrainerUI_UseCategories and TrainerUI_UseCategories()
        and C_Trainer.GetCategorizeTrainerUI and C_Trainer.GetCategorizeTrainerUI() or false
    if panel and panel:IsShown() then self:RefreshList() end
end

ScheduleScan = function(allServices)
    if not visiting or scanning then return end
    captureAll = captureAll or allServices == true
    if queued then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        local all = captureAll
        captureAll = false
        if visiting then module:ScanTrainer(all) end
    end)
end

function module:GetDisplaySpells()
    local list = {}
    for _, spell in pairs(DB().spells) do
        list[#list + 1] = spell
    end
    -- Like the trainer: alphabetical categories, native service order within them.
    local grouped = DB().grouped
    table.sort(list, function(a, b)
        local learnedA, learnedB = Learned(a), Learned(b)
        if learnedA ~= learnedB then return not learnedA end
        if learnedA then
            if a.name ~= b.name then return a.name < b.name end
            if (a.rank or "") ~= (b.rank or "") then return (a.rank or "") < (b.rank or "") end
        elseif grouped and a.category ~= b.category then return a.category < b.category end
        if a.order ~= b.order then return a.order < b.order end
        if a.name ~= b.name then return a.name < b.name end
        return (a.rank or "") < (b.rank or "")
    end)
    return list
end

local function ShowSpellTooltip(row)
    local spell = row.spell
    if not spell then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if spell.id then
        GameTooltip:SetSpellByID(spell.id)
    else
        GameTooltip:SetText(spell.name, 1, 1, 1)
        for index = 2, #(spell.tooltip or {}) do
            GameTooltip:AddLine(spell.tooltip[index], 1, 1, 1, true)
        end
    end
    GameTooltip:Show()
end

local TRAINER_TEXTURE = "Interface\\ClassTrainerFrame\\TrainerTextures"
local ROW_HEIGHT, ROW_STEP, HEADER_STEP = 47, 47, 30
local LIST_LEFT, LIST_TOP, LIST_RIGHT, LIST_BOTTOM = 8, 32, 20, 50

local function NewRow()
    local row = CreateFrame("Button", nil, panel)
    row:SetFrameLevel(panel:GetFrameLevel() + 2)
    row:SetHeight(ROW_HEIGHT)
    row.background = row:CreateTexture(nil, "BACKGROUND")
    row.background:SetAllPoints()
    row.background:SetTexture(TRAINER_TEXTURE)
    row.background:SetTexCoord(.00195313, .57421875, .65820313, .75000000)
    row.disabledBG = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.disabledBG:SetPoint("TOPLEFT", 2, -2)
    row.disabledBG:SetPoint("BOTTOMRIGHT", -2, 2)
    row.disabledBG:SetColorTexture(.55, .55, .55, 1)
    row.disabledBG:SetBlendMode("MOD")
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture(TRAINER_TEXTURE)
    highlight:SetTexCoord(.00195313, .57421875, .75390625, .84570313)
    highlight:SetBlendMode("ADD")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(36, 36)
    row.icon:SetPoint("LEFT", 6, 0)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, -1)
    row.name:SetHeight(12)
    row.name:SetJustifyH("LEFT")
    row.rank = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.rank:SetPoint("BOTTOMLEFT", row.name, "BOTTOMRIGHT", 5, -1)
    row.requirement = row:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Small")
    row.requirement:SetPoint("LEFT", row.name, "LEFT", 0, -19)
    row.requirement:SetPoint("RIGHT", row, "RIGHT", -12, 0)
    row.requirement:SetJustifyH("LEFT")
    row.requirement:SetJustifyV("MIDDLE")
    row.requirement:SetWordWrap(true)
    row.requirement:SetHeight(30)
    row.money = CreateFrame("Frame", nil, row, "SmallMoneyFrameTemplate")
    SmallMoneyFrame_OnLoad(row.money)
    MoneyFrame_SetType(row.money, "STATIC")
    row.money:SetPoint("TOPRIGHT", 5, -7)
    row:SetScript("OnEnter", ShowSpellTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnHide", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    return row
end

-- Draw whole visible rows directly on the panel. No separate clipped render layer.
local function RenderRows()
    local offset = panel.bar:GetValue()
    local height = math.max(1, panel:GetHeight() - LIST_TOP - LIST_BOTTOM)
    for _, row in ipairs(rows) do row:Hide() end
    for _, header in ipairs(headers) do header:Hide() end
    local rowCount, headerCount, visibleY = 0, 0, 0
    for _, entry in ipairs(panel.entries) do
        if entry.y + entry.height > offset then
            if visibleY + entry.height > height then break end
            local top = visibleY
            local item
            if entry.spell then
                rowCount = rowCount + 1
                item = rows[rowCount] or NewRow()
                rows[rowCount], item.spell = item, entry.spell
                local spell = entry.spell
                item.icon:SetTexture(spell.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                item.icon:SetDesaturated(spell.state == "unavailable")
                item.disabledBG:SetShown(spell.state == "unavailable")
                item.name:SetText(spell.name)
                item.rank:SetText(spell.rank ~= "" and "(" .. spell.rank .. ")" or "")
                item.name:SetTextColor(1, .82, 0)
                local learned = Learned(spell)
                item.requirement:SetText(learned and L.CLASS_TRAINER_LEARNED or RequirementText(spell))
                item.requirement:SetTextColor(1, 1, 1)
                if learned or spell.cost <= 0 then item.money:Hide()
                else
                    MoneyFrame_Update(item.money, spell.cost)
                    item.money:Show()
                end
            else
                headerCount = headerCount + 1
                item = headers[headerCount]
                if not item then
                    item = CreateFrame("Frame", nil, panel)
                    item:SetFrameLevel(panel:GetFrameLevel() + 2)
                    item:SetHeight(28)
                    item.background = item:CreateTexture(nil, "BACKGROUND")
                    item.background:SetAllPoints()
                    item.background:SetAtlas("common-button-list-collapseExpand", false)
                    item.text = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    item.text:SetPoint("LEFT", 10, 0)
                    item.divider = item:CreateTexture(nil, "ARTWORK")
                    item.divider:SetColorTexture(.6, .47, .2, .7)
                    item.divider:SetHeight(1)
                    item.divider:SetPoint("TOPLEFT", 2, 0)
                    item.divider:SetPoint("TOPRIGHT", -2, 0)
                    headers[headerCount] = item
                end
                item.text:SetText(entry.category)
            end
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", panel, "TOPLEFT", LIST_LEFT, -LIST_TOP-top)
            item:SetWidth(math.max(1, panel:GetWidth() - LIST_LEFT - LIST_RIGHT))
            item:Show()
            visibleY = top + (entry.spell and ROW_STEP or HEADER_STEP)
        end
    end
end

function module:RefreshList()
    if not panel then return end
    local list, db = self:GetDisplaySpells(), DB()
    panel.empty:SetText(not db.scanned and L.CLASS_TRAINER_VISIT or L.CLASS_TRAINER_EMPTY)
    panel.empty:SetShown(#list == 0)
    panel.info:SetText(db.scanned and string.format(L.CLASS_TRAINER_SNAPSHOT, db.trainer or "") or "")
    local y, lastCategory, learnedSection = 0, nil, false
    panel.entries = {}
    for _, spell in ipairs(list) do
        local learned = Learned(spell)
        if learned and not learnedSection then
            panel.entries[#panel.entries + 1] = {category = L.CLASS_TRAINER_LEARNED, y = y, height = 28}
            y = y + HEADER_STEP
            learnedSection = true
        elseif not learned and db.grouped and spell.category ~= "" and spell.category ~= lastCategory then
            panel.entries[#panel.entries + 1] = {category = spell.category, y = y, height = 28}
            lastCategory = spell.category
            y = y + HEADER_STEP
        end
        panel.entries[#panel.entries + 1] = {spell = spell, y = y, height = ROW_HEIGHT}
        y = y + ROW_STEP
    end
    local height = math.max(1, panel:GetHeight() - LIST_TOP - LIST_BOTTOM)
    panel.bar:SetMinMaxValues(0, math.max(0, y - height))
    panel.bar:SetVisibleExtentPercentage(math.min(1, height / math.max(1, y)))
    RenderRows()
end

local function CompactWindow()
    if windowState or (InCombatLockdown and InCombatLockdown()) then return end
    local parent = book:GetParent()
    windowState = {
        parent = parent, width = parent:GetWidth(), height = parent:GetHeight(),
        bookWidth = book:GetWidth(), bookHeight = book:GetHeight(), controls = {},
    }
    -- These controls belong to the normal spellbook and do not fit the trainer view.
    local function HideControl(control)
        if not control then return end
        windowState.controls[#windowState.controls + 1] = {frame = control, shown = control:IsShown()}
        control:Hide()
    end
    HideControl(book.TopBar)
    HideControl(book.PagedSpellsFrame)
    HideControl(book.SearchPreviewContainer)
    HideControl(book.BookBGLeft)
    HideControl(book.BookBGRight)
    HideControl(book.BookBGHalved)
    HideControl(book.BookCornerFlipbook)
    HideControl(book.Bookmark)
    HideControl(book.SearchBox)
    HideControl(book.SearchBoxIcon)
    HideControl(book.SettingsDropdown)
    HideControl(book.SettingsTopFaceIcon)
    HideControl(parent.MaximizeMinimizeButton)
    parent:SetSize(338, 486)
    book:SetSize(332, 468)
end

local function RestoreWindow()
    local state = windowState
    if not state or (InCombatLockdown and InCombatLockdown()) then return end
    windowState = nil
    state.parent:SetSize(state.width, state.height)
    book:SetSize(state.bookWidth, state.bookHeight)
    for _, control in ipairs(state.controls) do control.frame:SetShown(control.shown) end
end

local function ClosePanel()
    if panel then panel:Hide(); panel.tabHeader:Hide() end
    RestoreWindow()
    if tab then tab:SetChecked(false) end
    if book and book.CategoryTabSystem then
        book.CategoryTabSystem:SetTabVisuallySelected(book:GetTab())
    end
end

InstallTab = function()
    if tab or not module:IsEnabled() then return end
    local parent = PlayerSpellsFrame
    book = parent and parent.SpellBookFrame
    if not book then return end
    -- Keep Blizzard's tab IDs and protected spell buttons untouched.
    tab = CreateFrame("Frame", nil, book, "LargeSideTabButtonTemplate")
    tab:SetFrameLevel(book:GetFrameLevel() + 5)
    tab:EnableMouse(true)
    tab:SetFillToInterior(true)
    tab.Icon:SetTexture("Interface\\icons\\INV_SideTab_Stats_c60")
    tab.tooltipText = L.CLASS_TRAINER
    tab:SetChecked(false)
    tab:SetPoint("BOTTOMLEFT", book, "BOTTOMRIGHT", -1, 20)
    tab:SetCustomOnMouseUpHandler(function(_, button, upInside)
        if button ~= "LeftButton" or not upInside then return end
        if panel:IsShown() then ClosePanel()
        else
            if book.CategoryTabSystem then book.CategoryTabSystem:SetTabVisuallySelected(nil) end
            CompactWindow()
            panel.tabHeader:Show()
            panel:Show()
            tab:SetChecked(true)
            module:RefreshList()
        end
    end)
    panel = CreateFrame("Frame", nil, book)
    panel:Hide()
    panel.tabHeader = book:CreateTexture(nil, "BACKGROUND", nil, -1)
    panel.tabHeader:SetPoint("TOPLEFT", book, "TOPLEFT", 3, 0)
    panel.tabHeader:SetPoint("BOTTOMRIGHT", book, "TOPRIGHT", -3, -56)
    panel.tabHeader:SetColorTexture(.08, .075, .065, 1)
    panel.tabHeader:Hide()
    panel:SetFrameLevel(book:GetFrameLevel() + 1100)
    panel:EnableMouse(true)
    panel:SetPoint("TOPLEFT", book, "TOPLEFT", 3, -56)
    panel:SetPoint("BOTTOMRIGHT", book, "BOTTOMRIGHT", -3, 0)
    panel.background = panel:CreateTexture(nil, "BACKGROUND")
    panel.background:SetAllPoints()
    panel.background:SetColorTexture(.055, .045, .035, 1)
    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.title:SetPoint("TOPLEFT", LIST_LEFT, -10)
    panel.title:SetText(L.CLASS_TRAINER)
    panel.title:SetTextColor(1, .82, 0)
    panel.info = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.info:SetPoint("BOTTOMLEFT", LIST_LEFT, 10)
    panel.info:SetPoint("BOTTOMRIGHT", -LIST_RIGHT, 10)
    panel.info:SetJustifyH("LEFT")
    panel.info:SetTextColor(.8, .7, .5)
    panel.entries = {}
    panel.viewport = CreateFrame("Frame", nil, panel)
    panel.viewport:SetFrameLevel(panel:GetFrameLevel() + 1)
    panel.viewport:SetPoint("TOPLEFT", LIST_LEFT, -LIST_TOP)
    panel.viewport:SetPoint("BOTTOMRIGHT", -LIST_RIGHT, LIST_BOTTOM)
    panel.viewport:SetClipsChildren(false)
    panel.listBackground = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
    panel.listBackground:SetPoint("TOPLEFT", panel.viewport, "TOPLEFT", -3, 4)
    panel.listBackground:SetPoint("BOTTOMRIGHT", panel.viewport, "BOTTOMRIGHT", 3, -4)
    panel.listBackground:SetTexture(TRAINER_TEXTURE)
    panel.listBackground:SetTexCoord(.00195313, .58593750, .00195313, .65429688)
    panel.bar = yTools.UI.Scrollbar(panel)
    panel.bar:SetFrameLevel(panel.viewport:GetFrameLevel() + 2)
    panel.bar:SetPoint("TOPLEFT", panel.viewport, "TOPRIGHT", 6, 0)
    panel.bar:SetPoint("BOTTOMLEFT", panel.viewport, "BOTTOMRIGHT", 6, 0)
    panel.bar:SetScript("OnValueChanged", RenderRows)
    panel.viewport:EnableMouseWheel(true)
    panel.viewport:SetScript("OnMouseWheel", function(_, delta)
        panel.bar:SetValue(panel.bar:GetValue() - delta * ROW_STEP)
    end)
    panel:SetScript("OnSizeChanged", function()
        if panel:IsShown() then module:RefreshList() end
    end)
    panel.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.empty:SetPoint("TOPLEFT", 32, -76)
    panel.empty:SetPoint("RIGHT", -48, 0)
    panel.empty:SetJustifyH("LEFT")
    panel.empty:SetTextColor(.9, .85, .75)
    panel.empty:SetWordWrap(true)
    panel:SetScript("OnShow", function()
        -- Anchor-derived sizes can settle after Show returns.
        C_Timer.After(0, function()
            if panel:IsShown() then module:RefreshList() end
        end)
    end)
    book:HookScript("OnHide", ClosePanel)
    -- Returning to a native school/general/pet tab dismisses the trainer view.
    if book.SetTab then hooksecurefunc(book, "SetTab", ClosePanel) end
    if book.OnActiveCategoryChanged then hooksecurefunc(book, "OnActiveCategoryChanged", ClosePanel) end
    local categoryTabs = book.CategoryTabSystem
    if categoryTabs then
        if categoryTabs.SetTab then hooksecurefunc(categoryTabs, "SetTab", ClosePanel) end
        -- Even clicking the currently selected tab should return to its spells.
        local function HookTabClicks()
            for _, button in ipairs({categoryTabs:GetChildren()}) do
                if button:IsObjectType("Button") and not button.yToolsTrainerClickHook then
                    button.yToolsTrainerClickHook = true
                    button:HookScript("OnClick", ClosePanel)
                end
            end
        end
        HookTabClicks()
        categoryTabs:HookScript("OnShow", HookTabClicks)
    end
    if book.SelectNextTab then hooksecurefunc(book, "SelectNextTab", ClosePanel) end
    book:HookScript("OnShow", function() tab:SetShown(module:IsEnabled()) end)
end

module:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    if not panel or not panel:IsShown() then RestoreWindow() end
end)
module:RegisterEvent("TRAINER_SHOW", function()
    visiting = true
    ScheduleScan(true)
end)
module:RegisterEvent("TRAINER_UPDATE", function() ScheduleScan(false) end)
module:RegisterEvent("TRAINER_SERVICE_INFO_NAME_UPDATE", function() ScheduleScan(false) end)
module:RegisterEvent("TRAINER_CLOSED", function() visiting = false end)
module:RegisterEvent("SPELLS_CHANGED", function()
    if visiting then ScheduleScan(false) end
    if panel and panel:IsShown() then module:RefreshList() end
end)
module:RegisterEvent("PLAYER_LEVEL_UP", function()
    if panel and panel:IsShown() then module:RefreshList() end
end)
-- The core handles ADDON_LOADED itself rather than dispatching it to modules.
-- Listen independently so opening the load-on-demand spellbook installs the tab.
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, name)
    if name == "Blizzard_PlayerSpells" then InstallTab() end
end)
function module:OnEnable()
    DB()
    InstallTab()
    if tab then tab:Show() end
end
function module:OnDisable()
    visiting = false
    ClosePanel()
    if tab then tab:Hide() end
end
