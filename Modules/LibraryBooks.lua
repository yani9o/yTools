local yTools = _G.yTools
local L, Data = yTools.L, yTools.LibraryBooksData
local module = yTools:RegisterModule("LibraryBooks", {
    title = L.LIBRARY_BOOKS_MODULE,
    description = L.LIBRARY_BOOKS_DESCRIPTION,
    defaultEnabled = true,
    defaults = { hideCompleted = false },
})
local template = "yToolsLibraryBookPinTemplate"
local provider, mixed, queued
local bankOpen, bankReady = false, false
local byItem, byQuest, states = {}, {}, {}
for _, book in ipairs(Data.books) do byItem[book.item], byQuest[book.quest] = book, book end
local function Public(value)
    return not (issecretvalue and issecretvalue(value))
end
local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end
local function CharacterDB()
    yToolsLibraryBooksDB = yToolsLibraryBooksDB or {}
    yToolsLibraryBooksDB.turnedIn = yToolsLibraryBooksDB.turnedIn or {}
    yToolsLibraryBooksDB.banked = yToolsLibraryBooksDB.banked or {}
    yToolsLibraryBooksDB.bankedAt = yToolsLibraryBooksDB.bankedAt or {}
    return yToolsLibraryBooksDB
end
local function ItemCountModule()
    return yTools:GetModule("Tooltip_ItemCount")
end
local function Scan()
    local db = CharacterDB()
    local countItems = C_Item and C_Item.GetItemCount or GetItemCount
    local shared = ItemCountModule()
    local sharedEnabled = shared and shared:IsEnabled()
    local now = GetServerTime and GetServerTime() or (time and time())
    if not Public(now) or type(now) ~= "number" then now = nil end
    for _, book in ipairs(Data.books) do
        local done = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(book.quest)
        if Public(done) and done == true then db.turnedIn[book.item] = true end
        local count = countItems and countItems(book.item, false) or 0
        if not sharedEnabled then
            local total = countItems and countItems(book.item, true) or 0
            if Public(count) and type(count) == "number" and Public(total) and type(total) == "number" and total >= count then
                local observed = total - count
                if observed > 0 or bankReady then
                    db.banked[book.item] = observed > 0 and observed or nil
                    db.bankedAt[book.item] = now
                end
            end
        end
        local bankCount = db.banked[book.item] or 0
        local ownTime = db.bankedAt[book.item]
        if shared and shared.GetCurrentItemCounts then
            local _, stored, known, sharedTime = shared:GetCurrentItemCounts(book.item)
            if not Public(sharedTime) or type(sharedTime) ~= "number" then sharedTime = nil end
            if Public(stored) and type(stored) == "number" and (known or stored > 0) then
                -- Prefer the newer confirmed observation; ties favor ItemCount.
                -- Legacy snapshots are undated, never stamped merely by reading.
                if (sharedTime and (not ownTime or sharedTime >= ownTime))
                    or (not sharedTime and not ownTime) then bankCount = stored end
            end
        end
        -- Only a completed turn-in counts as delivered; owning a book does not.
        states[book.item] = db.turnedIn[book.item] and "done"
            or (Public(count) and type(count) == "number" and count > 0 and "carried")
            or (bankCount > 0 and "bank") or "missing"
    end
end
local function BookName(book)
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(book.item)
    if Public(name) and type(name) == "string" and name ~= "" then return name end
    return book.name
end
local function Position(location, mapID)
    if location.map == mapID then return location.x, location.y end
    local info = C_Map.GetMapInfo(mapID)
    if not info or not Enum or not Enum.UIMapType or info.mapType ~= Enum.UIMapType.Continent then return end
    -- Project only onto the actual ancestor continent, never another continent.
    local parent, seen = location.map, {}
    while parent and parent ~= 0 and parent ~= mapID and not seen[parent] do
        seen[parent] = true
        local zone = C_Map.GetMapInfo(parent)
        parent = zone and zone.parentMapID
    end
    if parent ~= mapID or not C_Map.GetMapRectOnMap then return end
    local left, right, top, bottom = C_Map.GetMapRectOnMap(location.map, mapID)
    if not left or not right or not top or not bottom or right <= left or bottom <= top then return end
    local x, y = left + (right-left)*location.x, top + (bottom-top)*location.y
    if x >= 0 and x <= 1 and y >= 0 and y <= 1 then return x, y end
end

-- MapCanvas provides scaling and panning; only stock game textures are used.
yToolsLibraryBookPinMixin = {}
function yToolsLibraryBookPinMixin:OnLoad()
    self.Icon = self:CreateTexture(nil, "ARTWORK")
    self.Icon:SetAllPoints()
    self.Icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    self.Check = self:CreateTexture(nil, "OVERLAY", nil, 1)
    self.Check:SetSize(14, 14)
    self.Check:SetPoint("BOTTOMRIGHT", 3, -3)
    self.Check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
end
function yToolsLibraryBookPinMixin:OnAcquired(location, x, y)
    self.location = location
    self:UseFrameLevelType("PIN_FRAME_LEVEL_WAYPOINT_LOCATION")
    self:SetSize(18, 18)
    self:SetScalingLimits(1, 1, 1)
    self:SetPosition(x, y)
    local state = states[location.item]
    self.Check:SetShown(state == "done")
    self.Icon:SetDesaturated(true)
    if state == "done" then self.Icon:SetVertexColor(.25, 1, .25)
    elseif state == "carried" or state == "bank" then self.Icon:SetVertexColor(.3, .7, 1)
    else self.Icon:SetVertexColor(1, .82, .2) end
    self:SetAlpha(state == "done" and .65 or 1)
end
function yToolsLibraryBookPinMixin:OnMouseEnter()
    if InCombat() or not self.location then return end
    local location = self.location
    local book = byItem[location.item]
    local state = states[book.item] or "missing"
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(BookName(book), 1, .82, 0)
    local status = state == "done" and L.LIBRARY_BOOKS_DONE
        or state == "carried" and L.LIBRARY_BOOKS_CARRIED
        or state == "bank" and L.LIBRARY_BOOKS_BANK or L.LIBRARY_BOOKS_MISSING
    GameTooltip:AddLine(status, state == "done" and .2 or 1, state == "missing" and .82 or 1, (state == "carried" or state == "bank") and 1 or .2)
    local info = C_Map.GetMapInfo(location.map)
    GameTooltip:AddLine(string.format("%s — %.1f, %.1f", info and info.name or "", location.x*100, location.y*100), 1, 1, 1)
    local locale = GetLocale and GetLocale() or "enUS"
    GameTooltip:AddLine(location.hint[locale] or location.hint.enUS, .9, .9, .9, true)
    if not book.confirmed then GameTooltip:AddLine(L.LIBRARY_BOOKS_UNCONFIRMED, 1, .5, .1, true) end
    GameTooltip:AddLine(L.LIBRARY_BOOKS_PIN_HINT, .6, .7, .8, true)
    GameTooltip:Show()
end
function yToolsLibraryBookPinMixin:OnMouseLeave()
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end
function yToolsLibraryBookPinMixin:OnReleased()
    self:OnMouseLeave()
    self.location = nil
    MapCanvasPinMixin.OnReleased(self)
end
function yToolsLibraryBookPinMixin:ShouldMouseButtonBePassthrough()
    return false
end
function yToolsLibraryBookPinMixin:OnMouseClickAction(button)
    if InCombat() or not self.location then return end
    local loc = self.location
    if button == "RightButton" then
        self:GetMap():SetMapID(loc.map)
    elseif button == "LeftButton" and C_Map.SetUserWaypoint and UiMapPoint
        and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(loc.map) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(loc.map, loc.x, loc.y))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    end
end

local Provider = {}
function Provider:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate(template)
end
function Provider:RefreshAllData()
    if InCombat() then return end
    self:RemoveAllData()
    if not module:IsEnabled() then return end
    local map = self:GetMap()
    local mapID = map:GetMapID()
    if not mapID then return end
    local hide = module:GetDB().hideCompleted
    for _, location in ipairs(Data.locations) do
        if not hide or states[location.item] ~= "done" then
            local x, y = Position(location, mapID)
            if x then map:AcquirePin(template, location, x, y) end
        end
    end
end
Provider.OnMapChanged = Provider.RefreshAllData
local function Attach()
    if InCombat() then return end
    if not module:IsEnabled() then
        if provider then WorldMapFrame:RemoveDataProvider(provider); provider = nil end
        return
    end
    if provider or not WorldMapFrame or not MapCanvasDataProviderMixin or not MapCanvasPinMixin then return end
    if not mixed then
        yToolsLibraryBookPinMixin = CreateFromMixins(MapCanvasPinMixin, yToolsLibraryBookPinMixin)
        mixed = true
    end
    provider = CreateFromMixins(MapCanvasDataProviderMixin, Provider)
    WorldMapFrame:AddDataProvider(provider)
end
local function Refresh()
    if not module:IsEnabled() then return end
    Scan()
    Attach()
    if provider then provider:RefreshAllData() end
    if module.settingsPanel and module.settingsPanel:IsShown() then module.settingsPanel.RefreshForm() end
end
local function QueueRefresh()
    if queued then return end
    queued = true
    C_Timer.After(0, function() queued = false; Refresh() end)
end
function module:OnEnable()
    Refresh()
    if C_Item and C_Item.RequestLoadItemDataByID then
        for _, book in ipairs(Data.books) do C_Item.RequestLoadItemDataByID(book.item) end
    end
end
function module:OnDisable()
    bankOpen, bankReady = false, false
    if provider and InCombat() then
        for pin in provider:GetMap():EnumeratePinsByTemplate(template) do pin:Hide() end
    else Attach() end
end
for _, event in ipairs({"PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE", "BAG_UPDATE_DELAYED", "PLAYERBANKSLOTS_CHANGED", "BANK_TABS_CHANGED"}) do
    module:RegisterEvent(event, QueueRefresh)
end
module:RegisterEvent("BANKFRAME_OPENED", function()
    bankOpen, bankReady = true, false
    QueueRefresh()
    C_Timer.After(.4, function()
        if bankOpen and module:IsEnabled() then
            local counts = ItemCountModule()
            bankReady = not (counts and counts:IsEnabled())
            QueueRefresh()
        end
    end)
end)
module:RegisterEvent("BANKFRAME_CLOSED", function()
    -- Preserve the last confirmed bank counts after closing and across reloads.
    bankOpen, bankReady = false, false
    QueueRefresh()
end)
module:RegisterEvent("QUEST_TURNED_IN", function(_, _, questID)
    if Public(questID) and type(questID) == "number" and byQuest[questID] then
        CharacterDB().turnedIn[byQuest[questID].item] = true
        QueueRefresh()
    end
end)
module:RegisterEvent("ITEM_DATA_LOAD_RESULT", function(_, _, itemID)
    if Public(itemID) and type(itemID) == "number" and byItem[itemID] then QueueRefresh() end
end)
-- The core owns ADDON_LOADED; listen separately for the load-on-demand map.
-- Regen must also detach a provider disabled during combat.
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_REGEN_ENABLED")
loader:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_REGEN_ENABLED" or name == "Blizzard_WorldMap" then
        Attach()
        if module:IsEnabled() then Refresh() end
    end
end)
module:RegisterSlashCommand("librarybooks", function(_, arguments)
    local command = (arguments or ""):lower():match("^%s*(.-)%s*$")
    if command == "hide" or command == "show" then
        module:GetDB().hideCompleted = command == "hide"
        Refresh()
    end
    local done, carried, banked = 0, 0, 0
    for _, book in ipairs(Data.books) do
        if states[book.item] == "done" then done = done + 1
        elseif states[book.item] == "carried" then carried = carried + 1
        elseif states[book.item] == "bank" then banked = banked + 1 end
    end
    yTools:Print(string.format(L.LIBRARY_BOOKS_PROGRESS, done, #Data.books, carried, banked))
end, L.LIBRARY_BOOKS_COMMAND)

function module:CreateOptionsPanel(parentCategory)
    if self.settingsPanel or not parentCategory then return end
    local panel = CreateFrame("Frame")
    panel:Hide()
    panel:SetSize(700, 560)
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 32, -24)
    title:SetText(L.LIBRARY_BOOKS_TITLE)
    local details = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    details:SetPoint("TOPLEFT", 32, -64)
    details:SetWidth(600)
    details:SetJustifyH("LEFT")
    details:SetText(L.LIBRARY_BOOKS_DESCRIPTION)
    local enabled = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    yTools.UI.Check(enabled)
    local enabledLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    enabledLabel:SetPoint("TOPRIGHT", -32, -22)
    enabledLabel:SetText(L.MODULE_OPTIONS_ENABLE)
    enabled:SetPoint("RIGHT", enabledLabel, "LEFT", -5, 0)
    local hide = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    yTools.UI.Check(hide)
    hide:SetPoint("TOPLEFT", 32, -150)
    local hideLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hideLabel:SetPoint("LEFT", hide, "RIGHT", 5, 0)
    hideLabel:SetText(L.LIBRARY_BOOKS_HIDE)
    local progress = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    progress:SetPoint("TOPLEFT", 32, -205)
    panel.RefreshForm = function()
        enabled:SetChecked(module:IsEnabled())
        hide:SetChecked(module:GetDB().hideCompleted)
        local done, carried, banked = 0, 0, 0
        for _, book in ipairs(Data.books) do
            if states[book.item] == "done" then done = done + 1
            elseif states[book.item] == "carried" then carried = carried + 1
            elseif states[book.item] == "bank" then banked = banked + 1 end
        end
        progress:SetText(string.format(L.LIBRARY_BOOKS_PROGRESS, done, #Data.books, carried, banked))
    end
    enabled:SetScript("OnClick", function(button)
        if button:GetChecked() then module:Enable() else module:Disable() end
        panel.RefreshForm()
    end)
    hide:SetScript("OnClick", function(button)
        module:GetDB().hideCompleted = not not button:GetChecked()
        Refresh()
    end)
    panel:SetScript("OnShow", panel.RefreshForm)
    self.settingsPanel = panel
    self.settingsCategory = Settings.RegisterCanvasLayoutSubcategory(parentCategory, panel, L.LIBRARY_BOOKS_TITLE)
end
