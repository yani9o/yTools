local yTools = _G.yTools
local L = yTools.L
local module = yTools:RegisterModule("ClassTrainer", {
    title = L.TOOLS_CLASS_TRAINER,
    description = L.CLASS_TRAINER_DESCRIPTION,
    defaultEnabled = true,
})

local visiting, scanning, queued, captureAll = false, false, false, false
local book, panel, tab, windowState
local previousTabArt, returnTabButton
local customPageClose
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

-- Filter services too: trainer titles can be missing, and old snapshots can
-- already contain these skills. Keep the same rule when reading saved entries.
local ridingSkills = {
    ["Apprentice Riding"] = true, ["Journeyman Riding"] = true,
    ["Expert Riding"] = true, ["Artisan Riding"] = true, ["Master Riding"] = true,
    ["Unerfahrenes Reiten"] = true, ["Geübtes Reiten"] = true,
    ["Gekonntes Reiten"] = true,
    ["Gewandtes Reiten"] = true, ["Meisterhaftes Reiten"] = true,
}

local function IsRidingSkill(spell)
    local name = spell.name
    if not Public(name) or type(name) ~= "string" then return false end
    -- Some trainer entries include the rank directly in their name.
    name = name:gsub("%s*%b()$", ""):match("^%s*(.-)%s*$")
    return ridingSkills[name] == true
end

local excludedTrainerNames = {
    ["Woo Ping"] = true, ["Buliwyf Stonehand"] = true, ["Bixi Wobblebonk"] = true,
    ["Ilyenia Moonfire"] = true, ["Hanashi"] = true, ["Sayoc"] = true,
    ["Ansekhwa"] = true, ["Archibald"] = true,
    ["Belia Thundergranite"] = true, ["Claude Erksine"] = true, ["Grokor"] = true,
    ["Karrina Mekenda"] = true, ["Peria Lamenur"] = true, ["Zudd"] = true,
    ["Bolyun"] = true, ["Caelyb"] = true, ["Harruk"] = true,
    ["Hesuwa Thunderhorn"] = true, ["Keldas"] = true, ["Nalesette Wildbringer"] = true,
    ["Reban Freerunner"] = true, ["Silvaria"] = true, ["Xao'tsu"] = true,
}

local excludedTrainerTitles = {
    ["weapon master"] = true, ["pet trainer"] = true, ["demon trainer"] = true,
    ["riding trainer"] = true, ["riding instructor"] = true, ["riding master"] = true,
    ["reitlehrer"] = true, ["reitlehrerin"] = true,
    ["reitausbilder"] = true, ["reitausbilderin"] = true,
    ["waffenmeister"] = true, ["waffenmeisterin"] = true,
    ["tierausbilder"] = true, ["tierausbilderin"] = true,
    ["tiertrainer"] = true, ["tiertrainerin"] = true,
    ["begleitertrainer"] = true, ["begleitertrainerin"] = true,
    ["dämonenausbilder"] = true, ["dämonenausbilderin"] = true,
}

local function IsExcludedTrainer()
    local name = UnitName("npc")
    if Public(name) and name and excludedTrainerNames[name] then return true end
    local data = C_TooltipInfo and C_TooltipInfo.GetUnit and C_TooltipInfo.GetUnit("npc")
    if not Public(data) or not data then return false end
    local lines = data.lines
    if not Public(lines) then return false end
    for index = 2, #(lines or {}) do
        local line = lines[index]
        if Public(line) and line then
            local title = line.leftText
            if Public(title) and type(title) == "string"
                and excludedTrainerTitles[title:lower():match("^%s*<?%s*(.-)%s*>?%s*$")] then
                return true
            end
        end
    end
    return false
end

local function IsClassTrainer()
    if IsTradeskillTrainer and IsTradeskillTrainer() then return false end
    if not C_Trainer or not C_Trainer.GetTrainerType or not Enum or not Enum.TrainerType then return false end
    return C_Trainer.GetTrainerType() == Enum.TrainerType.General and not IsExcludedTrainer()
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

local function HasUnmetRequirements(spell)
    if UnitLevel("player") < spell.level then return true end
    for _, requirement in ipairs(spell.requirements or {}) do
        if not requirement.met then return true end
    end
    return false
end

local function LearnableCost(spells)
    local total, count = 0, 0
    for _, spell in ipairs(spells) do
        if not Learned(spell) and not HasUnmetRequirements(spell) then
            total = total + math.max(0, spell.cost or 0)
            count = count + 1
        end
    end
    return total, count
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
                if not IsRidingSkill(spell) then result[#result + 1] = spell end
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
        if not IsRidingSkill(spell) then list[#list + 1] = spell end
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
                local learned = Learned(spell)
                -- The saved trainer status can be stale after the player levels up.
                local unavailable = not learned and spell.state == "unavailable" and HasUnmetRequirements(spell)
                item.icon:SetDesaturated(unavailable)
                item.disabledBG:SetShown(unavailable)
                item.name:SetText(spell.name)
                item.rank:SetText(spell.rank ~= "" and "(" .. spell.rank .. ")" or "")
                item.name:SetTextColor(1, .82, 0)
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
    local total, count = LearnableCost(list)
    panel.totalCost:SetText(count > 0 and (L.CLASS_TRAINER_TOTAL_COST .. " " .. GetMoneyString(total)) or "")
    panel.totalCost:SetShown(count > 0)
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

local function HideSpellbookControls()
    if windowState or (InCombatLockdown and InCombatLockdown()) then return end
    local parent = book:GetParent()
    windowState = {controls = {}}
    -- These controls belong to the normal spellbook and do not fit the trainer view.
    local function HideControl(control)
        if not control then return end
        -- Keep native spellbook controls alive. Hide/Show runs their native
        -- lifecycle handlers from addon execution and can taint pooled spells.
        windowState.controls[#windowState.controls + 1] = {frame = control, alpha = control:GetAlpha()}
        control:SetAlpha(0)
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
end

local function RestoreSpellbookControls()
    local state = windowState
    if not state or (InCombatLockdown and InCombatLockdown()) then return end
    windowState = nil
    for _, control in ipairs(state.controls) do control.frame:SetAlpha(control.alpha) end
end

local function HideReturnTabTooltip()
    local state = previousTabArt
    if GameTooltip and (GameTooltip:IsOwned(returnTabButton)
        or (state and GameTooltip:IsOwned(state.button))) then
        GameTooltip:Hide()
    end
end

local function ShowReturnTabTooltip(proxy)
    if not previousTabArt or not GameTooltip then return end
    local button = previousTabArt.button
    local onEnter = button:GetScript("OnEnter")
    if onEnter then
        onEnter(button)
        if GameTooltip:IsOwned(button) then return end
    end
    local text = (button.GetTooltipText and button:GetTooltipText()) or button.tooltipText
        or (button.GetText and button:GetText())
    if not text or text == "" then return end
    GameTooltip:SetOwner(proxy, button.tooltipAnchor or "ANCHOR_TOP", button.tooltipAnchorX, button.tooltipAnchorY)
    GameTooltip:SetText(text)
    GameTooltip:Show()
end

local function RestorePreviousTabArt()
    if returnTabButton then
        HideReturnTabTooltip()
        returnTabButton:Hide()
    end
    if not previousTabArt then return end
    local state = previousTabArt
    previousTabArt = nil
    for _, region in ipairs(state.active) do region.texture:SetAlpha(region.alpha) end
    -- A native tab switch may already have applied the correct artwork.
    local currentID = book.GetTab and book:GetTab() or state.tabs.selectedTabID
    local stillSelected = currentID and state.id and currentID == state.id
    if not currentID or not state.id then
        stillSelected = not state.button.IsSelected or state.button:IsSelected()
    end
    if stillSelected then
        if state.iconChecked then state.button:SetChecked(true) end
        if state.font then state.button.Text:SetFontObject(state.font) end
        for _, region in ipairs(state.inactive) do region.texture:SetShown(region.shown) end
    end
end

local function ShowPreviousTabAsInactive(onReturn)
    local tabs = book.CategoryTabSystem
    if not tabs then return end
    local id = book.GetTab and book:GetTab() or tabs.selectedTabID
    local selected = id and tabs.GetTabButton and tabs:GetTabButton(id)
    for _, button in ipairs(selected and {selected} or tabs.tabs or {tabs:GetChildren()}) do
        if button == selected or (button.IsSelected and button:IsSelected())
            or (button.GetChecked and button:GetChecked()) then
            local state = {button = button, tabs = tabs, id = id, active = {}, inactive = {}}
            if button.SquareBackgroundActive or button.SquareBackgroundActiveGlow then
                local background = button.SquareBackground
                if background then
                    state.inactive[#state.inactive + 1] = {texture = background, shown = background:IsShown()}
                    background:Show()
                end
                for _, name in ipairs({"SquareBackgroundActive", "SquareBackgroundActiveGlow"}) do
                    local texture = button[name]
                    if texture then
                        state.active[#state.active + 1] = {texture = texture, alpha = texture:GetAlpha()}
                        texture:SetAlpha(0)
                    end
                end
            elseif button.Icon and button.SetChecked then
                -- Spellbook icon tabs draw the gold border from their checked state.
                -- Leave the tab system's selected ID and callback untouched.
                state.iconChecked = true
                button:SetChecked(false)
            end
            previousTabArt = state
            -- Change only textures, leaving Blizzard's selection and button state intact.
            for _, side in ipairs({"Left", "Middle", "Right"}) do
                local inactive, active = button[side], button[side .. "Active"]
                if inactive and active then
                    state.inactive[#state.inactive + 1] = {texture = inactive, shown = inactive:IsShown()}
                    state.active[#state.active + 1] = {texture = active, alpha = active:GetAlpha()}
                    inactive:Show()
                    active:SetAlpha(0)
                end
            end
            for _, name in ipairs({"LeftHighlight", "MiddleHighlight", "RightHighlight"}) do
                local texture = button[name]
                if texture then
                    state.active[#state.active + 1] = {texture = texture, alpha = texture:GetAlpha()}
                    texture:SetAlpha(0)
                end
            end
            if button.Text and button.Text.GetFontObject then
                state.font = button.Text:GetFontObject()
                button.Text:SetFontObject(button.unselectedFontObject or GameFontNormalSmall)
            end
            if not returnTabButton then
                returnTabButton = CreateFrame("Button", nil, book)
                returnTabButton:EnableMouse(true)
                returnTabButton:RegisterForClicks("LeftButtonUp")
                returnTabButton:SetScript("OnClick", onReturn)
                returnTabButton:SetScript("OnEnter", ShowReturnTabTooltip)
                returnTabButton:SetScript("OnLeave", HideReturnTabTooltip)
            end
            -- The same proxy is reused by multiple addon pages.
            returnTabButton:SetScript("OnClick", onReturn)
            returnTabButton:ClearAllPoints()
            returnTabButton:SetAllPoints(button)
            returnTabButton:SetFrameLevel(button:GetFrameLevel() + 1)
            returnTabButton:Show()
            return
        end
    end
end

local function ClosePanel()
    if customPageClose then return end
    RestorePreviousTabArt()
    if panel then panel:Hide(); panel.tabHeader:Hide() end
    RestoreSpellbookControls()
    if tab then tab:SetChecked(false) end
    -- Never write Blizzard's selectedTabID or run native tab selection here.
    -- Those values are read by secure spellbook and drag handlers.
end

local function OpenTrainerPanel()
    if customPageClose then customPageClose() end
    InstallTab()
    if not panel or not book:IsVisible() then return false end
    if not panel:IsShown() then
        HideSpellbookControls()
        panel.tabHeader:Show()
        panel:Show()
        tab:SetChecked(true)
        ShowPreviousTabAsInactive(ClosePanel)
        module:RefreshList()
    end
    return true
end

-- Addon-owned spellbook pages share the return-tab proxy and alpha handling.
-- This remains available when ClassTrainer itself is disabled.
function module:BeginCustomPage(owner, onReturn)
    if customPageClose then customPageClose() end
    ClosePanel()
    book = owner
    customPageClose = onReturn
    HideSpellbookControls()
    ShowPreviousTabAsInactive(onReturn)
end

function module:EndCustomPage()
    if not customPageClose then return end
    customPageClose = nil
    RestorePreviousTabArt()
    RestoreSpellbookControls()
end

function module:RestoreCustomPageControls()
    if not customPageClose and (not panel or not panel:IsShown()) then RestoreSpellbookControls() end
end

InstallTab = function()
    if tab or not module:IsEnabled() then return end
    local parent = PlayerSpellsFrame
    book = parent and parent.SpellBookFrame
    if not book then return end
    -- Keep Blizzard's tab IDs and protected spell buttons untouched.
    -- The native hover texture extends left of the side tab. Clip it at
    -- the window edge without moving the tab or changing its tooltip.
    local tabClip = CreateFrame("Frame", nil, book)
    tabClip:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT")
    tabClip:SetSize(120, 120)
    tabClip:SetClipsChildren(true)
    tab = CreateFrame("Frame", nil, tabClip, "LargeSideTabButtonTemplate")
    tab:SetFrameLevel(book:GetFrameLevel() + 5)
    tab:EnableMouse(true)
    tab:SetFillToInterior(true)
    tab.Icon:SetTexture("Interface\\icons\\INV_SideTab_Stats_c60")
    tab.tooltipText = L.CLASS_TRAINER
    tab:SetChecked(false)
    tab:SetPoint("BOTTOMLEFT", book, "BOTTOMRIGHT", -1, 20)
    module.sideTab = tab
    tab:SetCustomOnMouseUpHandler(function(_, button, upInside)
        if button ~= "LeftButton" or not upInside then return end
        if panel:IsShown() then ClosePanel() else OpenTrainerPanel() end
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
    panel.totalCost = panel:CreateFontString(nil, "OVERLAY", "NumberFontNormalRight")
    panel.totalCost:SetPoint("BOTTOMRIGHT", -LIST_RIGHT, 32)
    panel.totalCost:SetJustifyH("RIGHT")
    panel.totalCost:Hide()
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
    if not customPageClose and (not panel or not panel:IsShown()) then RestoreSpellbookControls() end
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


module:RegisterSlashCommand("classtrainer", function(_, arguments)
    local command = (arguments or ""):match("^%s*(.-)%s*$"):lower()
    if command == "reset" then
        visiting, captureAll = false, false
        yToolsClassTrainerDB = {spells = {}}
        if panel and panel:IsShown() then
            panel.bar:SetValue(0)
            module:RefreshList()
        end
        yTools:Print(L.CLASS_TRAINER_RESET_DONE)
    elseif command == "" then
        if OpenTrainerPanel() then return end
        local util = PlayerSpellsUtil
        local open = util and (util.OpenToSpellBookTab or util.ToggleSpellBookFrame)
        if open then open()
        elseif ToggleSpellBook then ToggleSpellBook(BOOKTYPE_SPELL) end
        if not OpenTrainerPanel() then
            C_Timer.After(0, function()
                if module:IsEnabled() and not OpenTrainerPanel() then
                    yTools:Print(L.CLASS_TRAINER_OPEN_FAILED)
                end
            end)
        end
    else
        yTools:Print(L.CLASS_TRAINER_COMMAND_HELP)
    end
end, L.CLASS_TRAINER_COMMAND_HELP)

yTools.commands.classtrainer.allowDisabled = function(arguments)
    return arguments:match("^%s*(.-)%s*$"):lower() == "reset"
end
