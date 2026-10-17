local yTools = _G.yTools
local L = yTools.L
local module = yTools:RegisterModule("CharacterStats", {
    title = L.UI_CHARACTERSTATS,
    description = L.CHARACTERSTATS_DESCRIPTION,
    defaultEnabled = true,
})

local hookedPane, pending, display, preview
local catalog = {}
local rows = {}
local snapshots, hookedStats = {}, {}
local previewSnapshots, previewValues = {}, {}
local PREVIEW_HEIGHT = CHARACTER_FRAME_HEIGHT or 512
local PREVIEW_VIEWPORT_HEIGHT = PREVIEW_HEIGHT - 120
local ReadPreviewStats
local RebuildOptions

local function GetPreferences()
    yToolsCharacterStatsDB = type(yToolsCharacterStatsDB) == "table" and yToolsCharacterStatsDB or {}
    local db = yToolsCharacterStatsDB
    for _, key in ipairs({ "categoryOrder", "statOrder", "hiddenCategories", "hiddenStats", "collapsedCategories" }) do
        db[key] = type(db[key]) == "table" and db[key] or {}
    end
    return db
end

local function Ordered(items, saved)
    local byKey, result, seen = {}, {}, {}
    for _, item in ipairs(items) do byKey[item.key] = item end
    for _, key in ipairs(saved or {}) do
        if byKey[key] and not seen[key] then result[#result + 1] = byKey[key]; seen[key] = true end
    end
    for _, item in ipairs(items) do
        if not seen[item.key] then result[#result + 1] = item end
    end
    return result
end

local function StatKey(name, id)
    return name .. ":" .. tostring(id or "")
end

-- Labels are localized constants; never run native stat calculations from addon code.
local labelKeys = {
    MOVESPEED = "STAT_MOVEMENT_SPEED", STRENGTH = "SPELL_STAT1_NAME",
    AGILITY = "SPELL_STAT2_NAME", STAMINA = "SPELL_STAT3_NAME",
    INTELLECT = "SPELL_STAT4_NAME", SPIRIT = "SPELL_STAT5_NAME",
    MAINHAND_DAMAGE = "INVTYPE_WEAPONMAINHAND", OFFHAND_DAMAGE = "INVTYPE_WEAPONOFFHAND",
    RANGED_DAMAGE = "INVTYPE_RANGED", ATTACK_AP = "ATTACK_POWER", RANGED_ATTACK_AP = "RANGED_ATTACK_POWER",
    HITCHANCE = "STAT_HIT_CHANCE", CRITCHANCE = "STAT_CRITICAL_STRIKE", HASTE = "STAT_HASTE",
    EXPERTISE = "STAT_EXPERTISE", ARMORPEN = "STAT_ARMOR_PENETRATION",
    SPELLPOWER = "STAT_SPELLPOWER", SPELLHEALING = "STAT_SPELLHEALING",
    SPELLPENETRATION = "STAT_SPELL_PENETRATION", DODGE = "STAT_DODGE",
    BLOCK = "STAT_BLOCK", PARRY = "STAT_PARRY", ARMOR = "STAT_ARMOR",
}
local function StatLabel(stat)
    if stat.stat == "POWER" and UnitPowerType then
        local _, token = UnitPowerType("player")
        if token and _G[token] then return _G[token] end
    end
    return _G[labelKeys[stat.stat] or stat.stat] or _G["STAT_" .. stat.stat] or stat.stat
end

local function BuildCatalog()
    catalog = {}
    for _, category in ipairs(PAPERDOLL_STATCATEGORIES or {}) do
        if not category.unit or category.unit == "player" then
            local first = category.stats and category.stats[1]
            if first then
                local group = { key = "category:" .. first.stat, name = category.categoryName, stats = {} }
                for _, stat in ipairs(category.stats) do
                    group.stats[#group.stats + 1] = { key = StatKey(stat.stat, stat.id), name = StatLabel(stat) }
                end
                catalog[#catalog + 1] = group
            end
        end
    end
    if STAT_CATEGORY_RESISTANCE then
        local group = { key = "resistance", name = STAT_CATEGORY_RESISTANCE, stats = {} }
        for _, school in ipairs({ 7, 3, 5, 4, 6 }) do
            local name = _G["DAMAGE_SCHOOL" .. school]
            if name then group.stats[#group.stats + 1] = { key = "school:" .. school, name = name } end
        end
        catalog[#catalog + 1] = group
    end
end

-- Rearrange native display data without changing the global stat definitions.
-- Primary-stat tooltip calculations depend on their original array positions.
function module:FilterElements(elements)
    local db = GetPreferences()
    local groups, current, unknown = {}, nil, {}
    local byName = {}
    for _, group in ipairs(catalog) do byName[group.name] = group end
    for _, element in ipairs(elements or {}) do
        if element.isHeader then
            local definition = byName[element.name]
            current = definition and { definition = definition, header = element, stats = {} } or nil
            if current then groups[definition.key] = current else unknown[#unknown + 1] = element end
        elseif current then
            local key = element.name and StatKey(element.name, element.id)
            if not key then
                for _, stat in ipairs(current.definition.stats) do
                    if element.labelText == stat.name then key = stat.key; break end
                end
            end
            current.stats[#current.stats + 1] = { key = key or "unknown:" .. #current.stats, element = element }
        else unknown[#unknown + 1] = element end
    end
    local result = {}
    for _, definition in ipairs(Ordered(catalog, db.categoryOrder)) do
        local group = groups[definition.key]
        if group and not db.hiddenCategories[definition.key] then
            local stats = {}
            for _, stat in ipairs(Ordered(group.stats, db.statOrder[definition.key])) do
                if not db.hiddenStats[definition.key .. "/" .. stat.key] then stats[#stats + 1] = stat.element end
            end
            if #stats > 0 then
                result[#result + 1] = group.header
                for index, element in ipairs(stats) do
                    local copy = {}
                    for key, value in pairs(element) do copy[key] = value end
                    copy.statIndex = index
                    result[#result + 1] = copy
                end
            end
        end
    end
    for _, element in ipairs(unknown) do result[#result + 1] = element end
    return result
end

-- Capture the results of Blizzard's own updates. Secret formatted strings can
-- be passed to FontStrings; addon code must not calculate or compare the stats.
local dynamicTooltips = {
    STRENGTH = true, AGILITY = true, STAMINA = true, INTELLECT = true, SPIRIT = true,
    MAINHAND_DAMAGE = true, OFFHAND_DAMAGE = true, RANGED_DAMAGE = true,
    SPELLPOWER = true, MOVESPEED = true, HASTE = true, DEFENSE = true,
    ARMOR = true, HITCHANCE = true, CRITCHANCE = true, EXPERTISE = true,
}
local function CopyTooltipTable(source, snapshot, seen)
    if issecretvalue and issecretvalue(source) then snapshot.hasSecret = true; return nil end
    if seen[source] then return seen[source] end
    local copy = {}; seen[source] = copy
    for key, value in pairs(source) do
        if issecretvalue and issecretvalue(value) then snapshot.hasSecret = true end
        if type(value) == "table" then
            if not value.GetObjectType then copy[key] = CopyTooltipTable(value, snapshot, seen) end
        elseif type(value) ~= "function" and type(value) ~= "userdata" then copy[key] = value end
    end
    return copy
end

local function CaptureStats()
    for name, info in pairs(PAPERDOLL_STATINFO or {}) do
        if info.updateFunc and not hookedStats[info] then
            hookedStats[info] = true
            local statName = name
            hooksecurefunc(info, "updateFunc", function(frame, unit, id)
                if unit ~= "player" or not frame.Label or not frame.Value then return end
                local snapshot = { label = frame.Label:GetText(), value = frame.Value:GetText(), hasSecret = false }
                for key, value in pairs(frame) do
                    local kind = type(value)
                    if (kind == "number" or kind == "string" or kind == "boolean")
                        and key ~= "label" and key ~= "value" and key ~= "hasSecret" then
                        snapshot[key] = value
                        if issecretvalue and issecretvalue(value) then snapshot.hasSecret = true end
                    elseif kind == "table" and not value.GetObjectType then
                        snapshot[key] = CopyTooltipTable(value, snapshot, {})
                    end
                end
                snapshot.onEnterFunc = dynamicTooltips[statName] and frame.onEnterFunc or nil
                snapshots[StatKey(statName, id)] = snapshot
            end)
        end
    end
end

local function StatTooltip(button)
    local snapshot = button.yToolsSnapshot
    if snapshot and not InCombatLockdown() and not snapshot.hasSecret then
        CharacterStatFrameMixin.OnEnter(button)
        button.UpdateTooltip = StatTooltip
        return
    end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    for _, key in ipairs({ "tooltip", "tooltip2", "tooltip3" }) do
        local text = button[key]
        if type(text) == "string" then GameTooltip:AddLine(text, 1, 1, 1, true) end
    end
    GameTooltip:Show()
end

local function InitializeStat(button, element)
    if element.isHeader then button.Title:SetText(element.name); return end
    -- A recycled row must not retain scalar tooltip data from another stat.
    for key in pairs(button.yToolsCopiedFields or {}) do button[key] = nil end
    button.yToolsCopiedFields = {}
    local snapshot = element.snapshot or (element.name and snapshots[StatKey(element.name, element.id)])
    button.yToolsSnapshot = snapshot
    if snapshot then
        for key, value in pairs(snapshot) do
            if key ~= "label" and key ~= "value" and key ~= "hasSecret" then
                button[key] = value
                button.yToolsCopiedFields[key] = true
            end
        end
        button.Label:SetText(snapshot.label)
        button.Value:SetText(snapshot.value)
    else
        button.Label:SetText(element.labelText and format(STAT_FORMAT, element.labelText)
            or StatLabel({ stat = element.name or "" }))
        button.Value:SetText(element.valueText or "")
        for _, key in ipairs({ "tooltip", "tooltip2", "tooltip3" }) do
            button[key] = element[key]
            button.yToolsCopiedFields[key] = true
        end
    end
    button.Background:SetShown(element.statIndex % 2 == 1)
    if button.Icon then
        button.Icon:Hide()
        if element.texture then
            button.Icon:SetTexture(element.texture)
            button.Icon:SetTexCoord(element.textureCoordL or 0, element.textureCoordR or 1,
                element.textureCoordT or 0, element.textureCoordB or 1)
            button.Icon:Show()
        elseif element.atlas then
            button.Icon:SetAtlas(element.atlas, false)
            button.Icon:SetTexCoord(0, 1, 0, 1)
            button.Icon:Show()
        end
    end
    button.UpdateTooltip = StatTooltip
    button.Label:SetPoint("RIGHT", button.Value, "LEFT", -6, 0)
    button.Label:SetJustifyH("LEFT")
    button.Label:SetWordWrap(false)
    button.Label:SetMaxLines(1)
    button:SetScript("OnEnter", StatTooltip)
    button:SetScript("OnLeave", GameTooltip_Hide)
end

-- Use an addon-owned ScrollBox. Never replace the native ScrollBox's provider:
-- Blizzard reads that provider while opening/closing the character panel.
local function RestoreNativeDisplay(pane)
    if display then display:Hide() end
    if pane and pane.ScrollBox then pane.ScrollBox:SetAlpha(1) end
    if pane and pane.ScrollBar then pane.ScrollBar:SetAlpha(1) end
end

local function InitializeList(host)
    local view = CreateScrollBoxListLinearView(0, 8, 0, 0, 0)
    view:SetElementFactory(function(factory, element)
        local template = element.isHeader and "CharacterStatFrameCategoryScrollBoxElementTemplate"
            or (element.texture or element.atlas) and "CharacterStatFrameScrollBoxIconElementTemplate"
            or "CharacterStatFrameScrollBoxLabelElementTemplate"
        factory(template, InitializeStat)
    end)
    ScrollUtil.InitScrollBoxListWithScrollBar(host.ScrollBox, host.ScrollBar, view)
end

local function GetDisplay(pane)
    if display then return display end
    display = CreateFrame("Frame", nil, pane)
    display:SetAllPoints(pane)
    display:SetFrameLevel(pane:GetFrameLevel() + 20)
    display:EnableMouse(true)
    display.ScrollBox = CreateFrame("Frame", nil, display, "WowScrollBoxList")
    display.ScrollBox:SetAllPoints(pane.ScrollBox)
    display.ScrollBox:SetEdgeFadeLength(45)
    display.ScrollBar = CreateFrame("EventFrame", nil, display, "MinimalScrollBar")
    display.ScrollBar:SetAllPoints(pane.ScrollBar)
    InitializeList(display)
    return display
end

local function GetPreview()
    if preview then return preview end
    preview = CreateFrame("Frame", nil, UIParent, "PortraitFrameTemplate")
    preview:SetSize(270, 570)
    preview:SetPoint("TOPRIGHT", SettingsPanel or module.settingsPanel, "TOPLEFT", -12, 0)
    preview:SetFrameStrata("FULLSCREEN_DIALOG")
    preview:SetFrameLevel((SettingsPanel and SettingsPanel:GetFrameLevel() or 100) + 50)
    if preview.CloseButton then preview.CloseButton:Hide() end
    preview:SetTitle(L.CHARACTERSTATS_OPTIONS)
    preview:SetPortraitToAsset("Interface\\icons\\inv_blacksmithing_toolbox_01")
    local background = preview:CreateTexture(nil, "BACKGROUND")
    background:SetPoint("TOPLEFT", 10, -60); background:SetPoint("BOTTOMRIGHT", -10, 12)
    local _, class = UnitClass("player")
    if class then background:SetAtlas("UI-Character-Info-" .. class .. "-BG", false) end
    preview.ScrollBox = CreateFrame("Frame", nil, preview, "WowScrollBoxList")
    preview.ScrollBox:SetPoint("BOTTOMLEFT", 16, 20)
    preview.ScrollBox:SetPoint("BOTTOMRIGHT", -34, 20)
    preview.ScrollBox:SetEdgeFadeLength(45)
    preview.ScrollBar = CreateFrame("EventFrame", nil, preview, "MinimalScrollBar")
    preview.ScrollBar:SetPoint("TOPLEFT", preview.ScrollBox, "TOPRIGHT", 5, -12)
    preview.ScrollBar:SetPoint("BOTTOMLEFT", preview.ScrollBox, "BOTTOMRIGHT", 5, 0)
    InitializeList(preview)
    preview:Hide()
    return preview
end

local function PositionPreview()
    local host = GetPreview()
    local settings = SettingsPanel or module.settingsPanel
    if host.yToolsAnchor ~= settings then
        host:ClearAllPoints()
        host:SetPoint("TOPRIGHT", settings, "TOPLEFT", -12, 0)
        host.yToolsAnchor = settings
    end
    if host.yToolsHeight ~= PREVIEW_HEIGHT then
        host:SetHeight(PREVIEW_HEIGHT); host.yToolsHeight = PREVIEW_HEIGHT
    end
    if host.yToolsViewportHeight ~= PREVIEW_VIEWPORT_HEIGHT then
        host.ScrollBox:SetHeight(PREVIEW_VIEWPORT_HEIGHT); host.yToolsViewportHeight = PREVIEW_VIEWPORT_HEIGHT
    end
    local level = (settings and settings:GetFrameLevel() or 100) + 50
    if host.yToolsLevel ~= level then host:SetFrameLevel(level); host.yToolsLevel = level end
    return host
end

local resistanceNames = { [7] = "ARCANE_RESIST", [3] = "FIRE_RESIST", [5] = "FROST_RESIST", [4] = "NATURE_RESIST", [6] = "SHADOW_RESIST" }
local function PreviewElements()
    local elements = {}
    for _, category in ipairs(PAPERDOLL_STATCATEGORIES or {}) do
        if not category.unit or category.unit == "player" then
            local group = {}
            for _, stat in ipairs(category.stats or {}) do
                local snapshot = previewSnapshots[StatKey(stat.stat, stat.id)]
                local visible = true
                if stat.showFunc then
                    local ok, shown = pcall(stat.showFunc)
                    visible = ok and shown == true
                end
                if snapshot and stat.hideAt ~= nil then
                    local value = previewValues[StatKey(stat.stat, stat.id)]
                    if not (issecretvalue and issecretvalue(value)) and value == stat.hideAt then visible = false end
                end
                if visible then
                    group[#group + 1] = { name = stat.stat, id = stat.id, unit = "player", statIndex = #group + 1,
                        texture = stat.texture, textureCoordL = stat.textureCoordL, textureCoordR = stat.textureCoordR,
                        textureCoordT = stat.textureCoordT, textureCoordB = stat.textureCoordB, snapshot = snapshot }
                end
            end
            if #group > 0 then
                elements[#elements + 1] = { isHeader = true, name = category.categoryName }
                for _, row in ipairs(group) do elements[#elements + 1] = row end
            end
        end
    end
    if STAT_CATEGORY_RESISTANCE then
        elements[#elements + 1] = { isHeader = true, name = STAT_CATEGORY_RESISTANCE }
        for index, school in ipairs({ 7, 3, 5, 4, 6 }) do
            local snapshot = previewSnapshots[StatKey(resistanceNames[school])]
            elements[#elements + 1] = { statIndex = index, labelText = _G["DAMAGE_SCHOOL" .. school],
                valueText = snapshot and snapshot.value or "", tooltip = snapshot and snapshot.tooltip,
                tooltip2 = snapshot and snapshot.tooltip2, tooltip3 = snapshot and snapshot.tooltip3 }
        end
    end
    return elements
end

local function RefreshStats()
    local pane = CharacterStatsPaneScrollBox
    if not pane or not pane.ScrollBox or not pane.elementData then return end
    local enabled = module:IsEnabled()
    local data = enabled and module:FilterElements(pane.elementData) or pane.elementData
    -- Clone headers as well, so native initializers only receive owned tables.
    local owned = {}
    for index, element in ipairs(data) do
        local copy = {}
        for key, value in pairs(element) do copy[key] = value end
        owned[index] = copy
    end
    if enabled then
        local host = GetDisplay(pane)
        host.ScrollBox:SetDataProvider(CreateDataProvider(owned), ScrollBoxConstants.RetainScrollPosition)
        pane.ScrollBox:SetAlpha(0); pane.ScrollBar:SetAlpha(0); host:Show()
    else RestoreNativeDisplay(pane) end
    if preview and preview:IsShown() then
        -- Separate row tables: the preview and character pane never share mutable rows.
        local source = PreviewElements()
        local previewData = enabled and module:FilterElements(source) or source
        local copy = {}
        for index, element in ipairs(previewData) do
            local row = {}; for key, value in pairs(element) do row[key] = value end
            copy[index] = row
        end
        preview.ScrollBox:SetDataProvider(CreateDataProvider(copy), ScrollBoxConstants.RetainScrollPosition)
    end
end

local function QueueRefresh()
    if pending then return end
    pending = true
    C_Timer.After(0, function()
        pending = false
        RefreshStats()
    end)
end

local function Install()
    local pane = CharacterStatsPaneScrollBox
    if not pane or not pane.UpdateStats then return end
    CaptureStats()
    if #catalog == 0 then BuildCatalog() end
    if hookedPane ~= pane then
        hooksecurefunc(pane, "UpdateStats", QueueRefresh)
        hookedPane = pane
    end
end

local function SaveOrder(items)
    local order = {}
    for _, item in ipairs(items) do order[#order + 1] = item.key end
    return order
end

local function Move(group, key, delta)
    local db = GetPreferences()
    local items = group and Ordered(group.stats, db.statOrder[group.key]) or Ordered(catalog, db.categoryOrder)
    for index, item in ipairs(items) do
        if item.key == key then
            local destination = index + delta
            if destination >= 1 and destination <= #items then
                items[index], items[destination] = items[destination], items[index]
                if group then db.statOrder[group.key] = SaveOrder(items) else db.categoryOrder = SaveOrder(items) end
            end
            break
        end
    end
    RefreshStats()
    RebuildOptions()
end

local function StyleArrow(button, up)
    button:SetSize(18, 18)
    local art = button:CreateTexture(nil, "ARTWORK")
    -- Same glyph and fixed dimensions in both directions (as in yAuras).
    art:SetPoint("CENTER", button, "CENTER", 0, up and 2.5 or -2.5)
    local atlas = "common-dropdown-a-button-open-shadowless"
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
    local asset = info and (info.file or info.filename)
    if asset then
        art:SetTexture(asset)
        if up then art:SetTexCoord(info.rightTexCoord, info.leftTexCoord, info.bottomTexCoord, info.topTexCoord)
        else art:SetTexCoord(info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord) end
    else
        art:SetAtlas(atlas, false)
        art:SetRotation(up and math.pi or 0)
    end
    art:SetSize(18, 18)
    art:SetSnapToPixelGrid(true); art:SetTexelSnappingBias(0)
    button:SetScript("OnEnter", function() art:SetBlendMode("ADD") end)
    button:SetScript("OnLeave", function() art:SetBlendMode("BLEND") end)
    button:SetScript("OnEnable", function() art:SetAlpha(1) end)
    button:SetScript("OnDisable", function() art:SetAlpha(.35) end)
end

local function CreateRow(content)
    local row = CreateFrame("Button", nil, content)
    row:SetHeight(26)
    row.background = row:CreateTexture(nil, "BACKGROUND")
    row.background:SetAllPoints()
    row.background:SetAtlas("common-button-list-collapseExpand", false)
    row:SetHighlightAtlas("questlog-header-glow-yellow")
    row.highlight = row:GetHighlightTexture()
    row.highlight:ClearAllPoints()
    row.highlight:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 3)
    row.highlight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 3)
    row.check = CreateFrame("CheckButton", nil, row, "InterfaceOptionsCheckButtonTemplate")
    yTools.UI.Check(row.check)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetPoint("LEFT", row.check, "RIGHT", 5, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", -58, 0)
    row.label:SetJustifyH("LEFT")
    for _, direction in ipairs({ "up", "down" }) do
        local button = CreateFrame("Button", nil, row)
        StyleArrow(button, direction == "up")
        button:SetPoint("RIGHT", row, "RIGHT", direction == "up" and -30 or -6, 0)
        yTools.UI.Tooltip(button, direction == "up" and L.CHARACTERSTATS_UP or L.CHARACTERSTATS_DOWN)
        button:SetScript("OnClick", function() Move(row.group, row.key, direction == "up" and -1 or 1) end)
        row[direction] = button
    end
    row.collapse = CreateFrame("Button", nil, row, "CollapseButtonTemplate")
    row.collapse:SetSize(16, 16); row.collapse:SetPoint("LEFT", 5, 0)
    row.collapse:EnableMouse(false)
    row:SetScript("OnClick", function()
        if row.group then return end
        local db = GetPreferences()
        db.collapsedCategories[row.key] = not db.collapsedCategories[row.key]
        RebuildOptions()
    end)
    row.check:SetScript("OnClick", function(button)
        local db = GetPreferences()
        local hidden = row.group and db.hiddenStats or db.hiddenCategories
        local key = row.group and row.group.key .. "/" .. row.key or row.key
        hidden[key] = button:GetChecked() ~= true or nil
        RefreshStats()
        RebuildOptions()
    end)
    return row
end

RebuildOptions = function()
    local panel = module.settingsPanel
    if not panel then return end
    local db, rowIndex, offset = GetPreferences(), 0, 0
    local function AddRow(item, group, index, count)
        rowIndex = rowIndex + 1
        local row = rows[rowIndex]
        if not row then row = CreateRow(panel.content); rows[rowIndex] = row end
        row.group, row.key = group, item.key
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 0, -offset)
        row:SetPoint("RIGHT", panel.content, "RIGHT", -4, 0)
        row.background:SetShown(not group)
        row.highlight:SetAlpha(group and 0 or 1)
        row.check:ClearAllPoints()
        row.check:SetPoint("LEFT", group and 45 or 25, 0)
        row.collapse:SetShown(not group)
        row.collapse:UpdateCollapsedState(db.collapsedCategories[item.key] == true)
        row.collapse.Icon:ClearAllPoints(); row.collapse.Icon:SetPoint("CENTER")
        row.collapse.Icon:SetSize(12, db.collapsedCategories[item.key] and 12 or 3)
        row.label:SetText(item.name)
        row.check:SetChecked(not (group and db.hiddenStats[group.key .. "/" .. item.key] or not group and db.hiddenCategories[item.key]))
        local active = module:IsEnabled() and (not group or not db.hiddenCategories[group.key])
        row.check:SetEnabled(active)
        row.up:SetEnabled(module:IsEnabled() and index > 1)
        row.down:SetEnabled(module:IsEnabled() and index < count)
        row:Show()
        offset = offset + 28
    end
    local categories = Ordered(catalog, db.categoryOrder)
    local anyExpanded = false
    for _, group in ipairs(categories) do
        if not db.collapsedCategories[group.key] then anyExpanded = true; break end
    end
    panel.categoryToggle:UpdateCollapsedState(not anyExpanded)
    panel.categoryToggle.Icon:ClearAllPoints(); panel.categoryToggle.Icon:SetPoint("CENTER")
    panel.categoryToggle.Icon:SetSize(12, anyExpanded and 3 or 12)
    for index, group in ipairs(categories) do
        AddRow(group, nil, index, #categories)
        local stats = Ordered(group.stats, db.statOrder[group.key])
        if not db.collapsedCategories[group.key] then
            for statIndex, stat in ipairs(stats) do AddRow(stat, group, statIndex, #stats) end
        end
        offset = offset + 6
    end
    for index = rowIndex + 1, #rows do rows[index]:Hide() end
    panel.content:SetHeight(math.max(1, offset))
    panel.scroll:UpdateScrollChildRect()
    panel.enabled:SetChecked(module:IsEnabled())
end

ReadPreviewStats = function()
    if InCombatLockdown() then return end
    local scratch = module.previewStatFrame
    if not scratch then
        scratch = CreateFrame("Frame", nil, UIParent, "CharacterStatFrameTemplate")
        scratch:Hide()
        module.previewStatFrame = scratch
    end
    local function Read(stat, id)
        local info = PAPERDOLL_STATINFO and PAPERDOLL_STATINFO[stat]
        if not info or not info.updateFunc then return end
        scratch.onEnterFunc, scratch.UpdateTooltip = nil, nil
        local ok, value = pcall(info.updateFunc, scratch, "player", id)
        if ok then
            local key = StatKey(stat, id)
            -- Use the function's returned value for native hideAt filtering.
            -- Some unequipped-weapon updaters return zero without updating the frame.
            previewValues[key] = value
            previewSnapshots[key] = snapshots[key]
        end
    end
    for _, category in ipairs(PAPERDOLL_STATCATEGORIES or {}) do
        if not category.unit or category.unit == "player" then
            for _, stat in ipairs(category.stats or {}) do Read(stat.stat, stat.id) end
        end
    end
    for _, name in pairs(resistanceNames) do Read(name) end
end

function module:CreateOptionsPanel(parentCategory)
    if self.settingsPanel or not parentCategory or not Settings or not Settings.RegisterCanvasLayoutSubcategory then return end
    local panel = CreateFrame("Frame")
    -- Settings reparents canvas pages only when selected. An unparented page
    -- otherwise starts visible and runs OnUpdate immediately after login.
    panel:Hide()
    panel:SetSize(700, 560)
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 32, -24); title:SetText(L.CHARACTERSTATS_OPTIONS)
    panel.categoryToggle = CreateFrame("Button", nil, panel, "CollapseButtonTemplate")
    panel.categoryToggle:SetSize(16, 16)
    panel.categoryToggle:SetPoint("TOPLEFT", panel, "TOPLEFT", 37, -100)
    panel.categoryToggle:SetScript("OnClick", function()
        local db = GetPreferences()
        local anyExpanded = false
        for _, group in ipairs(catalog) do
            if not db.collapsedCategories[group.key] then anyExpanded = true; break end
        end
        for _, group in ipairs(catalog) do db.collapsedCategories[group.key] = anyExpanded end
        RebuildOptions()
    end)
    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hint:SetPoint("TOPLEFT", 32, -62); hint:SetWidth(590); hint:SetJustifyH("LEFT"); hint:SetText(L.CHARACTERSTATS_HINT)
    panel.categoryToggle:ClearAllPoints()
    panel.categoryToggle:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 5, -24)
    panel.enabled = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    yTools.UI.Check(panel.enabled)
    panel.enabled:SetPoint("TOPRIGHT", -140, -24)
    local enabledLabel = panel.enabled:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    enabledLabel:SetPoint("LEFT", panel.enabled, "RIGHT", 5, 0); enabledLabel:SetText(L.CHARACTERSTATS_ENABLE)
    panel.enabled:SetScript("OnClick", function(button) if button:GetChecked() then self:Enable() else self:Disable() end end)
    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetSize(300, 24); reset:SetPoint("BOTTOMLEFT", 32, 20); reset:SetText(L.CHARACTERSTATS_RESET)
    reset:SetScript("OnClick", function()
        yToolsCharacterStatsDB = {}
        RefreshStats(); RebuildOptions()
    end)
    panel.scroll = CreateFrame("ScrollFrame", nil, panel)
    panel.scroll:SetPoint("TOPLEFT", panel.categoryToggle, "BOTTOMLEFT", -5, -8); panel.scroll:SetPoint("BOTTOMRIGHT", -48, 60)
    yTools.UI.ScrollFrame(panel.scroll, panel)
    panel.content = CreateFrame("Frame", nil, panel.scroll)
    panel.content:SetSize(590, 1); panel.scroll:SetScrollChild(panel.content)
    panel.scroll:HookScript("OnSizeChanged", function(_, width) panel.content:SetWidth(width) end)
    self.settingsPanel = panel
    self.settingsCategory = Settings.RegisterCanvasLayoutSubcategory(parentCategory, panel, L.CHARACTERSTATS_OPTIONS)
    panel:SetScript("OnShow", function()
        Install(); BuildCatalog(); RebuildOptions()
        if SettingsPanel and SettingsPanel:IsShown() and panel:IsVisible() then
            PositionPreview():Show()
        end
        -- Read into an owned frame; never invoke the native pane updater.
        ReadPreviewStats()
        panel.previewElapsed = 0
        QueueRefresh()
    end)
    -- Canvas pages can be shown before Settings finishes its initial layout.
    -- Keep the preview bound to the visible page after that layout completes.
    panel:SetScript("OnUpdate", function(_, elapsed)
        if not SettingsPanel or not SettingsPanel:IsShown() or not panel:IsVisible() then
            if preview then preview:Hide() end
            return
        end
        local host = PositionPreview()
        if not host:IsShown() then host:Show(); QueueRefresh() end
        panel.previewElapsed = (panel.previewElapsed or 0) + (elapsed or 0)
        if panel.previewElapsed >= 1 then
            panel.previewElapsed = 0
            ReadPreviewStats(); QueueRefresh()
        end
    end)
    panel:SetScript("OnHide", function() if preview then preview:Hide() end end)
    Install(); RebuildOptions()
end

function module:OnEnable() Install(); QueueRefresh(); RebuildOptions() end
function module:OnDisable() QueueRefresh(); RebuildOptions() end
module:RegisterEvent("PLAYER_ENTERING_WORLD", function() Install(); QueueRefresh() end)
module:RegisterEvent("ADDON_LOADED", function() Install() end)
module:RegisterEvent("PLAYER_REGEN_DISABLED", QueueRefresh)
module:RegisterEvent("PLAYER_REGEN_ENABLED", QueueRefresh)

module:RegisterSlashCommand("charstats", function()
    yTools:InitializeOptions()
    module:CreateOptionsPanel(yTools.optionsCategory)
    local category = module.settingsCategory
    if category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(category.GetID and category:GetID() or category.ID)
    end
end, L.CHARACTERSTATS_COMMAND_HELP)
-- Options must remain reachable when this module is disabled.
yTools.commands.charstats.allowDisabled = true
