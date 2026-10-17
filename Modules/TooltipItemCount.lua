local yTools = _G.yTools
local L = yTools.L
local module = yTools:RegisterModule("Tooltip_ItemCount", {
    title = L.TOOLTIP_ITEM_COUNT,
    description = L.TOOLTIP_ITEM_COUNT_DESCRIPTION,
    defaultEnabled = true,
})

local installed, bankOpen = false, false
local loggingOut = false
local currentKey, currentRealm
local tooltips = setmetatable({}, { __mode = "k" })
local rendered = setmetatable({}, { __mode = "k" })

local function IsSecret(value)
    if issecretvalue and issecretvalue(value) then return true end
    return type(value) == "table" and issecrettable and issecrettable(value) or false
end

local function PublicNumber(value)
    return not IsSecret(value) and type(value) == "number"
end

local function Storage()
    local db = module:GetDB()
    db.characters = type(db.characters) == "table" and db.characters or {}
    db.accountBanks = nil
    return db
end

local function CurrentCharacter()
    local guid = UnitGUID("player")
    local realm = GetRealmName()
    local name, surname = (UnitNameUnmodified or UnitName)("player")
    if IsSecret(guid) or IsSecret(realm) or IsSecret(name) or IsSecret(surname)
        or type(guid) ~= "string" or type(realm) ~= "string" or type(name) ~= "string" then return end
    if type(surname) == "string" and surname ~= "" and RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled() then
        local separator = Constants and Constants.CharacterNameSeparatorConsts
            and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR or " "
        local ending = separator .. surname
        if name:sub(-#ending) ~= ending then name = name .. ending end
    elseif GetUnitName then
        local fullName = GetUnitName("player", false)
        if not IsSecret(fullName) and type(fullName) == "string" then name = fullName end
    end
    currentRealm, currentKey = realm, realm .. ":" .. guid
    local db = Storage()
    db.characters[currentKey] = db.characters[currentKey] or { bags = {}, bank = {} }
    local record = db.characters[currentKey]
    record.name, record.realm = name, realm
    local _, class = UnitClass("player")
    if not IsSecret(class) and type(class) == "string" then record.class = class end
    return record
end

local function BagIDs()
    local ids = {}
    for bag = 0, NUM_BAG_SLOTS or 4 do ids[#ids + 1] = bag end
    local index = Enum and Enum.BagIndex
    if index and PublicNumber(index.ReagentBag) and index.ReagentBag > (NUM_BAG_SLOTS or 4) then
        ids[#ids + 1] = index.ReagentBag
    end
    if index and PublicNumber(index.Keyring) then ids[#ids + 1] = index.Keyring end
    return ids
end

local function ReadContainers(ids)
    if not C_Container or not C_Container.GetContainerNumSlots or not C_Container.GetContainerItemInfo then return end
    local counts, seen = {}, {}
    for _, bag in ipairs(ids) do
        if not PublicNumber(bag) then return end
        if not seen[bag] then
            seen[bag] = true
            local slots = C_Container.GetContainerNumSlots(bag)
            if not PublicNumber(slots) then return end
            for slot = 1, slots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if IsSecret(info) then return end
                if info then
                    if type(info) ~= "table" or not PublicNumber(info.itemID) or not PublicNumber(info.stackCount) then return end
                    if info.itemID > 0 and info.stackCount > 0 then
                        counts[info.itemID] = (counts[info.itemID] or 0) + info.stackCount
                    end
                end
            end
        end
    end
    return counts
end

local function ReadBank(bankType)
    if not PublicNumber(bankType) or not bankOpen or not C_Bank or not C_Bank.CanViewBank
        or not C_Bank.FetchPurchasedBankTabIDs then return end
    local viewable = C_Bank.CanViewBank(bankType)
    if IsSecret(viewable) or not viewable then return end
    local ids = C_Bank.FetchPurchasedBankTabIDs(bankType)
    if IsSecret(ids) or type(ids) ~= "table" then return end
    local containers = {}
    for _, id in ipairs(ids) do containers[#containers + 1] = id end
    -- Forever keeps the equipped bank bags in their own slot container.
    local bankBags = Enum.BagIndex and Enum.BagIndex.Characterbanktab
    if PublicNumber(bankBags) then containers[#containers + 1] = bankBags end
    return ReadContainers(containers)
end

local function ReadEquipment()
    if not GetInventoryItemID or not GetInventoryItemCount then return end
    local counts, seen = {}, {}
    local function AddSlot(slot)
        if not PublicNumber(slot) or seen[slot] then return true end
        seen[slot] = true
        local id = GetInventoryItemID("player", slot)
        if IsSecret(id) then return false end
        if not id and GetInventoryItemLink then
            local link = GetInventoryItemLink("player", slot)
            if IsSecret(link) then return false end
            if type(link) == "string" then id = tonumber(link:match("item:(%d+)")) end
        end
        if id then
            local count = GetInventoryItemCount("player", slot)
            if not PublicNumber(id) or IsSecret(count) then return false end
            -- An occupied equipment slot owns at least one item. Equipped
            -- containers need not expose a positive stack count.
            count = PublicNumber(count) and math.max(1, count) or 1
            if id > 0 then counts[id] = (counts[id] or 0) + count end
        end
        return true
    end
    for slot = INVSLOT_FIRST_EQUIPPED or 1, INVSLOT_LAST_EQUIPPED or 19 do
        if not AddSlot(slot) then return end
    end
    local inventorySlot = C_Container and C_Container.ContainerIDToInventoryID or ContainerIDToInventoryID
    for _, bag in ipairs(BagIDs()) do
        if bag > 0 then
            local button = _G["CharacterBag" .. (bag - 1) .. "Slot"]
            local slot = button and button.GetID and button:GetID()
            if not PublicNumber(slot) and bag <= (NUM_BAG_SLOTS or 4) and GetInventorySlotInfo then
                slot = GetInventorySlotInfo("Bag" .. (bag - 1) .. "Slot")
            end
            if not PublicNumber(slot) and inventorySlot then slot = inventorySlot(bag) end
            if not AddSlot(slot) then return end
        end
    end
    return counts
end

local function Scan()
    if loggingOut then return end
    local record = CurrentCharacter()
    if not record then return end
    -- The backpack always has slots while inventory data is available. Zero
    -- slots during loading/teardown is not evidence of an empty inventory.
    local backpackSlots = C_Container and C_Container.GetContainerNumSlots
        and C_Container.GetContainerNumSlots(0)
    local bags = PublicNumber(backpackSlots) and backpackSlots > 0 and ReadContainers(BagIDs())
    if bags then record.bags = bags end
    if PublicNumber(backpackSlots) and backpackSlots > 0 then
        local equipped = ReadEquipment()
        if equipped then record.equipped = equipped end
    end
    local types = Enum and Enum.BankType
    if types then
        local bank = ReadBank(types.Character)
        if bank then record.bank, record.bankKnown = bank, true end
    end
end

local function RefreshTooltips()
    for tooltip in pairs(tooltips) do
        if not (tooltip.IsForbidden and tooltip:IsForbidden()) and tooltip:IsShown()
            and tooltip.RebuildFromTooltipInfo then tooltip:RebuildFromTooltipInfo() end
    end
end

local function Update()
    Scan()
    RefreshTooltips()
end

local function HasCounts(tooltip)
    if rendered[tooltip] then return true end
    local name, count = tooltip:GetName(), tooltip:NumLines()
    if IsSecret(name) or type(name) ~= "string" or not PublicNumber(count) then return false end
    for i = 1, count do
        local line = _G[name .. "TextLeft" .. i]
        if line and not (line.IsForbidden and line:IsForbidden()) then
            local text = line:GetText()
            if not IsSecret(text) and text == L.ITEM_COUNT_TOTAL then return true end
        end
    end
    return false
end

function module:AddItemCounts(tooltip, id)
    if not self:IsEnabled() or not PublicNumber(id) or id <= 0 or not tooltip
        or (tooltip.IsForbidden and tooltip:IsForbidden()) then return end
    tooltips[tooltip] = true
    if HasCounts(tooltip) then return end
    if not currentKey and not CurrentCharacter() then return end
    local db = Storage()
    local rows, total = {}, 0
    for key, record in pairs(db.characters) do
        if record.realm == currentRealm then
            local bags, bank = (record.bags or {})[id] or 0, (record.bank or {})[id] or 0
            local equipped = (record.equipped or {})[id] or 0
            if bags + bank + equipped > 0 then
                rows[#rows + 1] = { key = key, record = record, bags = bags, bank = bank, equipped = equipped }
                total = total + bags + bank + equipped
            end
        end
    end
    if #rows == 0 then return end
    yTools.UI.TooltipFooterGap(tooltip, "counts")
    table.sort(rows, function(a, b)
        if a.key == currentKey then return b.key ~= currentKey end
        if b.key == currentKey then return false end
        return a.record.name:lower() < b.record.name:lower()
    end)
    for _, row in ipairs(rows) do
        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[row.record.class]
        local r, g, b = color and color.r or 1, color and color.g or .82, color and color.b or 0
        local amount = string.format("|cff%02x%02x%02x%d|r",
            math.floor(r * 255 + .5), math.floor(g * 255 + .5), math.floor(b * 255 + .5), row.bags + row.bank + row.equipped)
        local details = {}
        if row.bags > 0 then details[#details + 1] = L.ITEM_COUNT_BAGS .. ": " .. row.bags end
        if row.record.bankKnown and row.bank > 0 then
            details[#details + 1] = L.ITEM_COUNT_BANK .. ": " .. row.bank
        end
        if row.equipped > 0 then
            details[#details + 1] = L.ITEM_COUNT_EQUIPPED .. ": " .. row.equipped
        end
        tooltip:AddDoubleLine(row.record.name,
            amount .. (#details > 0 and " (" .. table.concat(details, ", ") .. ")" or ""), r, g, b, 1, 1, 1)
    end
    tooltip:AddDoubleLine(L.ITEM_COUNT_TOTAL, tostring(total), 1, .82, 0, 1, 1, 1)
    rendered[tooltip] = true
end

local function OnTooltip(tooltip, data)
    if not module:IsEnabled() or IsSecret(data) or type(data) ~= "table" then return end
    local id = data.id
    if not IsSecret(data.type) and data.type == Enum.TooltipDataType.Macro then
        local ids = yTools:GetModule("Tooltip_ItemID")
        id = ids and ids.GetMacroItemID and ids:GetMacroItemID(tooltip, data)
    end
    module:AddItemCounts(tooltip, id)
end

function module:OnEnable()
    loggingOut = false
    bankOpen = BankFrame and BankFrame:IsShown() or false
    if not installed and TooltipDataProcessor and TooltipDataProcessor.AddTooltipPreCall
        and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        for _, name in ipairs({ "Item", "Toy", "Macro" }) do
            local kind = Enum.TooltipDataType[name]
            if kind ~= nil then
                TooltipDataProcessor.AddTooltipPreCall(kind, function(tooltip) rendered[tooltip] = nil end)
                TooltipDataProcessor.AddTooltipPostCall(kind, OnTooltip)
            end
        end
        installed = true
    end
    Update()
end

function module:OnDisable()
    bankOpen = false
    wipe(rendered)
    RefreshTooltips()
end

module:RegisterEvent("PLAYER_ENTERING_WORLD", function() loggingOut = false; Update() end)
module:RegisterEvent("BAG_UPDATE_DELAYED", Update)
module:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", Update)
module:RegisterEvent("PLAYERBANKSLOTS_CHANGED", Update)
module:RegisterEvent("BANK_TABS_CHANGED", Update)
module:RegisterEvent("BANKFRAME_OPENED", function()
    bankOpen = true
    Update()
    C_Timer.After(.1, function() if module:IsEnabled() and bankOpen then Update() end end)
end)
module:RegisterEvent("BANKFRAME_CLOSED", function() bankOpen = false; Update() end)
-- Inventory can already be unavailable when logout events are dispatched.
-- SavedVariables writes the snapshots collected by live bag/bank events.
module:RegisterEvent("PLAYER_LOGOUT", function() loggingOut = true end)

module:RegisterSlashCommand("itemcount", function(_, arguments)
    local command, name = (arguments or ""):match("^%s*(%S+)%s*(.-)%s*$")
    if not command or command:lower() ~= "delete" or not name or name == "" then
        yTools:Print(L.ITEM_COUNT_DELETE_HELP)
        return
    end
    local function Normalize(value)
        return (strlower or string.lower)(value:match("^%s*(.-)%s*$"):gsub("%s+", " "))
    end
    local target = Normalize(name)
    local realm = GetRealmName()
    local removed = false
    local characters = Storage().characters
    for key, record in pairs(characters) do
        if record.realm == realm and type(record.name) == "string" and Normalize(record.name) == target then
            characters[key] = nil
            removed = true
        end
    end
    if removed then
        RefreshTooltips()
        yTools:Print(string.format(L.ITEM_COUNT_DELETED, name))
    else
        yTools:Print(string.format(L.ITEM_COUNT_NOT_FOUND, name))
    end
end, L.ITEM_COUNT_COMMAND_HELP)
