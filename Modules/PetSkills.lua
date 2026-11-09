local yTools = _G.yTools
local L = yTools.L
local Data = yTools.PetSkillsData
local module = yTools:RegisterModule("PetSkills", {
    title = L.PET_SKILLS_MODULE,
    description = L.PET_SKILLS_DESCRIPTION,
    characterDefault = function()
        local _, class = UnitClass("player")
        return not (issecretvalue and issecretvalue(class)) and class == "HUNTER"
    end,
})
local page, tab, tabClip, book, search, skillScroll, skillContent, detailScroll, detailContent
local skillRows, detailRows, entries = {}, {}, {}
local selected, query = nil, ""
local HOVER_TEXTURE = "Interface\\QuestFrame\\UI-QuestTitleHighlight"
local InstallTab, Refresh, OpenPage
local searchCollapsed = {Categories = {}, Abilities = {}}
local sessionCollapsed = {Categories = {}, Abilities = {}, Zones = {}}
local function SortKey(text)
    return text:gsub("Ä", "a"):gsub("ä", "a"):gsub("Ö", "o"):gsub("ö", "o")
        :gsub("Ü", "u"):gsub("ü", "u"):gsub("ß", "ss"):lower()
end
local function Collapsed(kind, key)
    if query ~= "" and searchCollapsed[kind] then return searchCollapsed[kind][key] == true end
    return sessionCollapsed[kind][key] ~= false
end
local function ToggleGroup(kind, key)
    local closed = not Collapsed(kind, key)
    if query ~= "" and searchCollapsed[kind] then
        searchCollapsed[kind][key] = closed
    else
        sessionCollapsed[kind][key] = closed
    end
    if closed and kind == "Categories" then
        local children = query ~= "" and searchCollapsed.Abilities or sessionCollapsed.Abilities
        for abilityKey, ability in pairs(Data.abilities) do
            if (ability.passive == true) == (key == "passive") then children[abilityKey] = true end
        end
    end
end
local function GroupLabel(text, collapsed)
    return (collapsed and "[+] " or "[-] ") .. text
end
local function Public(value)
    return not (issecretvalue and issecretvalue(value)) and not (type(value) == "table" and issecrettable and issecrettable(value))
end
local function Text(value)
    if Public(value) and type(value) == "string" and value ~= "" then return value end
end
local function SpellInfo(entry)
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(entry.rank.spell_id)
    if Public(info) and type(info) == "table" then
        local icon = Public(info.iconID) and info.iconID or nil
        return Text(info.name) or entry.ability.name, icon or 132164
    end
    return entry.ability.name, 132164
end
local function NPCName(id, fallback)
    if not InCombatLockdown() and C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local ok, data = pcall(C_TooltipInfo.GetHyperlink, string.format("unit:Creature-0-0-0-0-%d-0", id))
        if ok and Public(data) and type(data) == "table" and Public(data.lines) and type(data.lines) == "table" then
            local line = data.lines[1]
            if Public(line) and type(line) == "table" then
                local name = Text(line.leftText)
                if name and name ~= UNKNOWNOBJECT then return name end
            end
        end
    end
    return fallback or ("NPC " .. id)
end
local function MapName(mapID, fallback)
    local info = mapID and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return info and Text(info.name) or fallback or L.PET_SKILLS_UNKNOWN_ZONE
end
local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local digits = {}
for i = 1, #alphabet do digits[alphabet:byte(i)] = i - 1 end
local function FirstPoint(packed)
    if type(packed) ~= "string" or #packed < 3 then return end
    local a, b, c = packed:byte(1, 3)
    if not digits[a] or not digits[b] or not digits[c] then return end
    local value = digits[a] * 4096 + digits[b] * 64 + digits[c]
    local x, y = math.floor(value / 501) / 5, (value % 501) / 5
    if x <= 100 and y <= 100 then return x, y end
end
local function FamilyName(name)
    return L["PET_FAMILY_" .. name:upper():gsub(" ", "_")] or name
end
local function LevelText(npc)
    if not npc.min then return L.PET_SKILLS_UNKNOWN_LEVEL end
    return npc.max and npc.max ~= npc.min and (npc.min .. "–" .. npc.max) or tostring(npc.min)
end
local function Sources(entry)
    local result = {}
    if entry.ability.passive or entry.key == "growl" then
        local faction = UnitFactionGroup("player")
        faction = Text(faction) and faction:lower() or nil
        for id, trainer in pairs(Data.trainers) do
            if not faction or trainer.side == "both" or trainer.side == faction then
                local point = trainer.coords and trainer.coords[1]
                result[#result + 1] = {name = NPCName(id, trainer.name), mapID = trainer.ui_map_id,
                    x = point and point.x, y = point and point.y,
                    location = MapName(trainer.ui_map_id, trainer.zone), kind = L.PET_SKILLS_TRAINER}
            end
        end
    else
        for _, id in ipairs(entry.rank.npc_ids or {}) do
            local npc = Data.npcs[id]
            if npc and not (Data.hidden and Data.hidden[id]) then
                local name, found = NPCName(id, npc.name), false
                for mapID, packed in pairs(npc.maps or {}) do
                    local x, y = FirstPoint(packed)
                    result[#result + 1] = {name = name, mapID = mapID, x = x, y = y,
                        location = MapName(mapID), kind = string.format(L.PET_SKILLS_BEAST_LEVEL, LevelText(npc)),
                        level = npc.min or 99, minLevel = npc.min, maxLevel = npc.max or npc.min}
                    found = true
                end
                if not found then
                    local locations = {}
                    if npc.map then locations[1] = {mapID = npc.map, name = MapName(npc.map)} end
                    if #locations == 0 then
                        for _, zoneID in ipairs(npc.zones or {}) do
                            local name = C_Map.GetAreaInfo and Text(C_Map.GetAreaInfo(zoneID))
                            local mapID
                            for candidate, areaID in pairs(Data.zoneMaps or {}) do
                                if areaID == zoneID and (not mapID or candidate < mapID) then mapID = candidate end
                            end
                            locations[#locations + 1] = {mapID = mapID, name = MapName(mapID, name)}
                        end
                    end
                    if #locations == 0 then locations[1] = {name = L.PET_SKILLS_UNKNOWN_ZONE} end
                    for _, location in ipairs(locations) do
                        result[#result + 1] = {name = name, mapID = location.mapID, location = location.name,
                            kind = string.format(L.PET_SKILLS_BEAST_LEVEL, LevelText(npc)),
                            level = npc.min or 99, minLevel = npc.min, maxLevel = npc.max or npc.min}
                    end
                end
            end
        end
    end
    table.sort(result, function(a, b)
        if SortKey(a.location) ~= SortKey(b.location) then return SortKey(a.location) < SortKey(b.location) end
        if SortKey(a.name) ~= SortKey(b.name) then return SortKey(a.name) < SortKey(b.name) end
        if a.name ~= b.name then return a.name < b.name end
        if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) < (b.level or 0) end
        return (a.mapID or 0) < (b.mapID or 0)
    end)
    return result
end
local function ShowMap(source)
    if not source.mapID or InCombatLockdown() then return end
    if source.x and source.y and C_Map.SetUserWaypoint and UiMapPoint and
        (not C_Map.CanSetUserWaypointOnMap or C_Map.CanSetUserWaypointOnMap(source.mapID)) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(source.mapID, source.x / 100, source.y / 100))
    end
    if OpenWorldMap then OpenWorldMap(source.mapID) end
end
local function BuildEntries()
    entries = {}
    for key, ability in pairs(Data.abilities) do
        for _, rank in ipairs(ability.ranks) do
            local entry = {key = key, ability = ability, rank = rank}
            entry.name, entry.icon = SpellInfo(entry)
            entries[#entries + 1] = entry
        end
    end
    table.sort(entries, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        if a.key ~= b.key then return a.key < b.key end
        return a.rank.rank < b.rank.rank
    end)
end
local function SkillLayout()
    local groups, byKey, matches = {}, {}, {}
    for _, entry in ipairs(entries) do
        local haystack = SortKey(entry.name .. " " .. entry.ability.name .. " " .. entry.rank.rank .. " " .. (entry.rank.pet_level or 1))
        if query == "" or haystack:find(SortKey(query), 1, true) then
            matches[#matches + 1] = entry
            local group = byKey[entry.key]
            if not group then
                group = {key = entry.key, name = entry.name, icon = entry.icon,
                    passive = entry.ability.passive == true, firstRank = entry.rank.rank, ranks = {}}
                byKey[entry.key] = group; groups[#groups + 1] = group
            end
            group.ranks[#group.ranks + 1] = entry
            if entry.rank.rank < group.firstRank then
                group.name, group.icon, group.firstRank = entry.name, entry.icon, entry.rank.rank
            end
        end
    end
    table.sort(groups, function(a, b)
        if SortKey(a.name) ~= SortKey(b.name) then return SortKey(a.name) < SortKey(b.name) end
        return a.key < b.key
    end)
    local layout = {}
    for _, category in ipairs({{key = "family", name = L.PET_SKILLS_FAMILY_SKILLS, passive = false},
        {key = "passive", name = L.PET_SKILLS_PASSIVES, passive = true}}) do
        local present = false
        for _, group in ipairs(groups) do if group.passive == category.passive then present = true; break end end
        if present then
            layout[#layout + 1] = {kind = "category", key = category.key,
                text = GroupLabel(category.name, Collapsed("Categories", category.key))}
            if not Collapsed("Categories", category.key) then
                for _, group in ipairs(groups) do
                    if group.passive == category.passive then
                        table.sort(group.ranks, function(a, b) return a.rank.rank < b.rank.rank end)
                        layout[#layout + 1] = {kind = "ability", key = group.key, icon = group.icon,
                            text = GroupLabel(group.name, Collapsed("Abilities", group.key))}
                        if not Collapsed("Abilities", group.key) then
                            for _, entry in ipairs(group.ranks) do
                                layout[#layout + 1] = {kind = "rank", entry = entry,
                                    text = string.format(L.PET_SKILLS_RANK_ROW, entry.rank.pet_level or 1, entry.name, entry.rank.rank)}
                            end
                        end
                    end
                end
            end
        end
    end
    return layout, matches
end
local function ZoneGroups(sources)
    local groups, byName = {}, {}
    for _, source in ipairs(sources) do
        local group = byName[source.location]
        if not group then
            group = {name = source.location, sources = {}}
            byName[source.location] = group; groups[#groups + 1] = group
        end
        group.sources[#group.sources + 1] = source
        if source.minLevel then group.minLevel = math.min(group.minLevel or source.minLevel, source.minLevel) end
        if source.maxLevel then group.maxLevel = math.max(group.maxLevel or source.maxLevel, source.maxLevel) end
    end
    table.sort(groups, function(a, b)
        if SortKey(a.name) ~= SortKey(b.name) then return SortKey(a.name) < SortKey(b.name) end
        return a.name < b.name
    end)
    for _, group in ipairs(groups) do
        table.sort(group.sources, function(a, b)
            if SortKey(a.name) ~= SortKey(b.name) then return SortKey(a.name) < SortKey(b.name) end
            if a.name ~= b.name then return a.name < b.name end
            if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) < (b.level or 0) end
            return (a.mapID or 0) < (b.mapID or 0)
        end)
    end
    return groups
end
local function Label(parent, text, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    label:SetText(text)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(true)
    return label
end
local function Details(keepScroll)
    for _, row in ipairs(detailRows) do row:Hide() end
    if not keepScroll then detailScroll:SetVerticalScroll(0) end
    if not selected then detailContent:SetHeight(1); return end
    local y, index = 0, 0
    local width = math.max(100, detailScroll:GetWidth())
    local function Add(text, header)
        index = index + 1
        local row = detailRows[index]
        if not row then
            row = CreateFrame("Button", nil, detailContent)
            row.label = Label(row, "")
            row.label:SetPoint("TOPLEFT", 3, -3)
            row.label:SetPoint("TOPRIGHT", -3, -3)
            row.hover = row:CreateTexture(nil, "HIGHLIGHT")
            row.hover:SetAllPoints()
            row.hover:SetTexture(HOVER_TEXTURE)
            row.hover:SetBlendMode("ADD")
            row:SetScript("OnClick", function(self)
                if self.action then self.action() elseif self.source then ShowMap(self.source) end
            end)
            row:SetScript("OnEnter", function(self)
                if self.source and self.source.mapID then
                    GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
                    GameTooltip:SetText(L.PET_SKILLS_OPEN_MAP)
                    GameTooltip:Show()
                end
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            detailRows[index] = row
        end
        row.source, row.action = nil, nil
        row.hover:Hide()
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -y); row:SetWidth(width)
        row.label:SetFontObject(header and GameFontNormal or GameFontHighlight)
        row.label:SetText(text)
        local height = math.max(22, row.label:GetStringHeight() + 12)
        row:SetHeight(height); row:Show(); y = y + height
        return row
    end
    Add(selected.name .. " — " .. string.format(L.PET_SKILLS_RANK, selected.rank.rank), true)
    Add(string.format(L.PET_SKILLS_REQUIREMENTS, selected.rank.pet_level or 1, selected.rank.training_cost or 0))
    local families = {}
    for _, family in ipairs(selected.ability.learned_by or {}) do families[#families + 1] = FamilyName(family) end
    Add(L.PET_SKILLS_FAMILIES, true)
    Add(#families > 0 and table.concat(families, ", ") or L.PET_SKILLS_ALL_FAMILIES)
    Add(L.PET_SKILLS_SOURCES, true)
    local sources = Sources(selected)
    if #sources == 0 then Add(L.PET_SKILLS_NO_SOURCE) end
    for _, group in ipairs(ZoneGroups(sources)) do
        local zone = group.name
        local title = zone
        if group.minLevel and group.maxLevel then
            title = title .. (group.minLevel == group.maxLevel and string.format(" (%d)", group.minLevel)
                or string.format(" (%d-%d)", group.minLevel, group.maxLevel))
        end
        local header = Add(GroupLabel(title, Collapsed("Zones", zone)), true)
        header.action = function() ToggleGroup("Zones", zone); Details(true) end
        header.hover:Show()
        if not Collapsed("Zones", zone) then
            for _, source in ipairs(group.sources) do
                local coords = source.x and string.format(" (%.1f, %.1f)", source.x, source.y) or ""
                local row = Add(source.name .. "\n" .. source.kind .. coords)
                row.source = source
                row.hover:Show()
            end
        end
    end
    Add(L.PET_SKILLS_DATA_NOTE)
    detailContent:SetSize(width, math.max(1, y))
end
Refresh = function()
    if not page or not page:IsShown() then return end
    BuildEntries()
    local layout, matches = SkillLayout()
    local previousID = selected and selected.rank.spell_id
    local selectedMatch
    for _, entry in ipairs(matches) do
        if entry.rank.spell_id == previousID then selectedMatch = entry; break end
    end
    -- Only an explicit rank click selects a skill; fresh sessions and searches
    -- must not populate the details with an arbitrary first result.
    selected = selectedMatch
    local y, width = 0, math.max(100, skillScroll:GetWidth())
    for _, row in ipairs(skillRows) do row:Hide() end
    for index, item in ipairs(layout) do
        local row = skillRows[index]
        if not row then
            row = CreateFrame("Button", nil, skillContent)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(26, 26); row.icon:SetPoint("LEFT", 3, 0)
            row.label = Label(row, "")
            row:SetHighlightTexture(HOVER_TEXTURE, "ADD")
            row.selection = row:CreateTexture(nil, "BACKGROUND")
            row.selection:SetAllPoints(); row.selection:SetColorTexture(.45, .32, .05, .35)
            row:SetScript("OnClick", function(self)
                local item = self.item
                if item.kind == "rank" then selected = item.entry; Details()
                else ToggleGroup(item.kind == "category" and "Categories" or "Abilities", item.key) end
                Refresh()
            end)
            row:SetScript("OnEnter", function(self)
                if self.item.kind ~= "rank" then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(self.item.entry.rank.spell_id)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            skillRows[index] = row
        end
        row.item = item
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -y); row:SetWidth(width)
        row.label:ClearAllPoints()
        row.label:SetPoint("TOPLEFT", item.kind == "ability" and 35 or 3, -5)
        row.label:SetPoint("TOPRIGHT", -4, -5)
        row.label:SetFontObject(item.kind == "rank" and GameFontHighlightSmall or GameFontNormal)
        row.label:SetText(item.text)
        row.icon:SetShown(item.icon ~= nil)
        if item.icon then row.icon:SetTexture(item.icon) end
        row.selection:SetShown(item.entry ~= nil and selected ~= nil and item.entry.rank.spell_id == selected.rank.spell_id)
        local height = math.max(item.kind == "ability" and 36 or 28, row.label:GetStringHeight() + 10)
        row:SetHeight(height); row:Show(); y = y + height
    end
    skillContent:SetSize(width, math.max(1, y))
    page.empty:SetShown(#matches == 0)
    if (selected and selected.rank.spell_id) ~= previousID then Details() end
end

function module:ClosePage()
    if not page or not page:IsShown() then return end
    page:Hide(); page.tabHeader:Hide(); tab:SetChecked(false)
    yTools:GetModule("ClassTrainer"):EndCustomPage()
end
local function CreatePage()
    page = CreateFrame("Frame", "yToolsPetSkillsPage", book)
    page:Hide(); page:EnableMouse(true)
    page:SetFrameLevel(book:GetFrameLevel() + 1101)
    page:SetPoint("TOPLEFT", book, "TOPLEFT", 3, -56)
    page:SetPoint("BOTTOMRIGHT", book, "BOTTOMRIGHT", -3, 0)
    page.tabHeader = book:CreateTexture(nil, "BACKGROUND", nil, -1)
    page.tabHeader:SetPoint("TOPLEFT", book, "TOPLEFT", 3, 0)
    page.tabHeader:SetPoint("BOTTOMRIGHT", book, "TOPRIGHT", -3, -56)
    page.tabHeader:SetColorTexture(.08, .075, .065, 1)
    page.tabHeader:Hide()
    page.background = page:CreateTexture(nil, "BACKGROUND")
    page.background:SetAllPoints(); page.background:SetColorTexture(.055, .045, .035, 1)
    local title = Label(page, L.PET_SKILLS_TITLE, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -12)
    search = CreateFrame("EditBox", "yToolsPetSkillsSearchBox", page, "InputBoxTemplate")
    search:SetAutoFocus(false); search:SetHeight(24)
    search:SetPoint("TOPLEFT", 18, -43); search:SetPoint("TOPRIGHT", -28, -43)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    search:SetScript("OnTextChanged", function(self)
        query = self:GetText():lower():match("^%s*(.-)%s*$")
        searchCollapsed = {Categories = {}, Abilities = {}}
        skillScroll:SetVerticalScroll(0); Refresh()
    end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    search.hint = Label(page, L.PET_SKILLS_SEARCH, "GameFontDisableSmall")
    search.hint:SetPoint("LEFT", search, "LEFT", 3, 0)
    search:HookScript("OnTextChanged", function(self) search.hint:SetShown(self:GetText() == "") end)
    skillScroll = CreateFrame("ScrollFrame", nil, page)
    skillScroll:SetPoint("TOPLEFT", 12, -79); skillScroll:SetPoint("BOTTOMLEFT", 12, 12)
    skillScroll:SetWidth(180)
    skillContent = CreateFrame("Frame", nil, skillScroll)
    skillContent:SetSize(180, 1); skillScroll:SetScrollChild(skillContent)
    yTools.UI.ScrollFrame(skillScroll, page)
    detailScroll = CreateFrame("ScrollFrame", nil, page)
    detailScroll:SetPoint("TOPLEFT", skillScroll, "TOPRIGHT", 30, 0)
    detailScroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -28, 12)
    detailContent = CreateFrame("Frame", nil, detailScroll)
    detailContent:SetSize(200, 1); detailScroll:SetScrollChild(detailContent)
    yTools.UI.ScrollFrame(detailScroll, page)
    page.empty = Label(skillContent, L.PET_SKILLS_NO_RESULTS)
    page.empty:SetPoint("TOPLEFT", 5, -5); page.empty:SetWidth(170)
    page:SetScript("OnSizeChanged", function()
        if page:IsShown() then Refresh(); Details() end
    end)
end
InstallTab = function()
    if not module:IsEnabled() then return end
    book = PlayerSpellsFrame and PlayerSpellsFrame.SpellBookFrame
    if not book then return end
    if tab then tabClip:Show(); return end
    tabClip = CreateFrame("Frame", nil, book)
    tabClip:SetPoint("BOTTOMLEFT", PlayerSpellsFrame, "BOTTOMRIGHT", 0, 60)
    tabClip:SetSize(120, 140); tabClip:SetClipsChildren(true)
    tab = CreateFrame("Frame", nil, tabClip, "LargeSideTabButtonTemplate")
    tab:SetFrameLevel(book:GetFrameLevel() + 5)
    tab:EnableMouse(true); tab:SetFillToInterior(true)
    tab.Icon:SetTexture("Interface\\icons\\Ability_Hunter_BeastTraining")
    tab.tooltipText = L.PET_SKILLS_TITLE
    tab:SetChecked(false)
    local trainer = yTools:GetModule("ClassTrainer")
    if trainer.sideTab then tab:SetPoint("BOTTOMLEFT", trainer.sideTab, "TOPLEFT", 0, 2)
    else tab:SetPoint("BOTTOMLEFT", book, "BOTTOMRIGHT", -1, 82) end
    CreatePage()
    tab:SetCustomOnMouseUpHandler(function(_, mouse, inside)
        if mouse == "LeftButton" and inside then
            if page:IsShown() then module:ClosePage() else OpenPage() end
        end
    end)
    local function Close() module:ClosePage() end
    book:HookScript("OnHide", Close)
    for _, name in ipairs({"SetTab", "OnActiveCategoryChanged", "SelectNextTab"}) do
        if book[name] then hooksecurefunc(book, name, Close) end
    end
    local tabs = book.CategoryTabSystem
    if tabs then
        if tabs.SetTab then hooksecurefunc(tabs, "SetTab", Close) end
        local function HookClicks()
            for _, button in ipairs({tabs:GetChildren()}) do
                if button:IsObjectType("Button") and not button.yToolsPetSkillsHook then
                    button.yToolsPetSkillsHook = true; button:HookScript("OnClick", Close)
                end
            end
        end
        HookClicks(); tabs:HookScript("OnShow", HookClicks)
    end
end
OpenPage = function()
    if not module:IsEnabled() then return false end
    if InCombatLockdown() then yTools:Print(L.PET_SKILLS_COMBAT); return false end
    InstallTab()
    if not book or not book:IsVisible() then return false end
    if not page:IsShown() then
        yTools:GetModule("ClassTrainer"):BeginCustomPage(book, function() module:ClosePage() end)
        page.tabHeader:Show(); page:Show(); tab:SetChecked(true); Refresh(); Details()
    end
    return true
end
function module:OnEnable() InstallTab() end
function module:OnDisable() self:ClosePage(); if tabClip then tabClip:Hide() end end
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_REGEN_ENABLED")
loader:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_REGEN_ENABLED" then
        -- Also restore a page disabled/closed during combat when ClassTrainer
        -- is disabled and therefore has no active module event handlers.
        yTools:GetModule("ClassTrainer"):RestoreCustomPageControls()
    elseif name == "Blizzard_PlayerSpells" then InstallTab() end
end)
module:RegisterEvent("SPELL_DATA_LOAD_RESULT", function() if page and page:IsShown() then Refresh(); Details() end end)
module:RegisterSlashCommand("petskills", function()
    if OpenPage() or InCombatLockdown() then return end
    local util = PlayerSpellsUtil
    local open = util and (util.OpenToSpellBookTab or util.ToggleSpellBookFrame)
    if open then open() elseif ToggleSpellBook then ToggleSpellBook(BOOKTYPE_SPELL) end
    if not OpenPage() then C_Timer.After(0, OpenPage) end
end, L.PET_SKILLS_COMMAND)
