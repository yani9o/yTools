local L = _G.yTools.L
local module = _G.yTools:RegisterModule("TooltipVendorPrice", {
    title = L.TOOLTIP_VENDOR_PRICE,
    description = L.SHOWS_THE_VENDOR_PRICE_PER_ITEM_HOLD_SHIFT_TO_SHOW_THE_PRICE_OF_THE_WHOLE_STACK,
    defaultEnabled = true,
})

local installed = false
local tooltips = setmetatable({}, {__mode = "k"})

local function IsSecret(value)
    if issecretvalue and issecretvalue(value) then
        return true
    end
    return type(value) == "table" and issecrettable and issecrettable(value) or false
end

local function PublicNumber(value)
    return not IsSecret(value) and type(value) == "number"
end


local function BagCount(bag, slot)
    if not PublicNumber(bag) or not PublicNumber(slot)
        or not C_Container or not C_Container.GetContainerItemInfo then
        return
    end
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not IsSecret(info) and type(info) == "table" and PublicNumber(info.stackCount) then
        return info.stackCount
    end
end

local function StackCount(tooltip)
    -- Use the tooltip's own bag/slot, independent of combined-bag visual order.
    local info = tooltip.GetProcessingTooltipInfo and tooltip:GetProcessingTooltipInfo()
    if not IsSecret(info) and type(info) == "table" and not IsSecret(info.getterName)
        and info.getterName == "GetBagItem" then
        local args = info.getterArgs
        if not IsSecret(args) and type(args) == "table" then
            local count = BagCount(args[1], args[2])
            if count then return count end
        end
    end

    local owner = tooltip:GetOwner()
    if IsSecret(owner) or not owner or (owner.IsForbidden and owner:IsForbidden()) then
        return
    end
    if owner.GetBagID and owner.GetID then
        local count = BagCount(owner:GetBagID(), owner:GetID())
        if count then return count end
    end

    -- Merchant and loot buttons can expose the quantity directly or as text.
    local count = owner.count
    if PublicNumber(count) then return count end
    if not IsSecret(count) and (type(count) == "table" or type(count) == "userdata")
        and count.GetText and not (count.IsForbidden and count:IsForbidden()) then
        local text = count:GetText()
        if not IsSecret(text) and type(text) == "string" then
            return tonumber(text)
        end
    end
end

local function DisplayedItemPrice(tooltip, data, getInfo)
    local function Lookup(text)
        if IsSecret(text) or type(text) ~= "string" then return end
        text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("^%s*(.-)%s*$")
        if text == "" then return end
        local price = select(11, getInfo(text))
        if PublicNumber(price) and price > 0 then return price end
    end
    -- Some native macro tooltips start with an empty spacer before the title.
    local lines = data.lines
    if not IsSecret(lines) and type(lines) == "table" then
        for index, line in ipairs(lines) do
            if not IsSecret(line) and type(line) == "table" then
                local price = Lookup(line.leftText)
                if price then return price end
            end
        end
    end
    local name = tooltip.GetName and tooltip:GetName()
    local count = tooltip.NumLines and tooltip:NumLines()
    if IsSecret(name) or type(name) ~= "string" or not PublicNumber(count) then return end
    for index = 1, count do
        local line = _G[name .. "TextLeft" .. index]
        if not IsSecret(line) and line and line.GetText
            and not (line.IsForbidden and line:IsForbidden()) then
            local price = Lookup(line:GetText())
            if price then return price end
        end
    end
end

local function MacroIndex(info, fallback)
    local args = info.getterArgs
    if not IsSecret(info.getterName) and info.getterName == "GetAction"
        and not IsSecret(args) and type(args) == "table" and PublicNumber(args[1])
        and GetActionText and GetMacroIndexByName then
        local name = GetActionText(args[1])
        if not IsSecret(name) and type(name) == "string" and name ~= "" then
            local index = GetMacroIndexByName(name)
            if PublicNumber(index) and index > 0 then return index end
        end
    end
    return fallback
end

local function UnitVendorPrice(tooltip)
    local info = tooltip.GetProcessingTooltipInfo and tooltip:GetProcessingTooltipInfo()
    if IsSecret(info) or type(info) ~= "table" then return end
    local data = info.tooltipData
    if IsSecret(data) or type(data) ~= "table" or IsSecret(data.type) then return end
    local types = Enum.TooltipDataType
    if not types then return end
    local getInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
    if not getInfo then return end

    if data.type == types.Macro then
        local price = DisplayedItemPrice(tooltip, data, getInfo)
        if price then return price end
    end

    local reference
    if data.type == types.Item then
        if not IsSecret(data.hyperlink) and type(data.hyperlink) == "string" then
            reference = data.hyperlink
        elseif not IsSecret(data.guid) and type(data.guid) == "string"
            and C_Item and C_Item.GetItemLinkByGUID then
            reference = C_Item.GetItemLinkByGUID(data.guid)
        end
        if not IsSecret(reference) and reference == nil and PublicNumber(data.id) then reference = data.id end
    elseif data.type == types.Macro and GetMacroItem then
        local index = MacroIndex(info, data.id)
        if not PublicNumber(index) or index <= 0 then return end
        -- Retain the API lookup for clients that expose a usable macro index.
        local item, link = GetMacroItem(index)
        if not IsSecret(link) and type(link) == "string" then
            reference = link
        elseif not IsSecret(item) and (type(item) == "number" or type(item) == "string") then
            reference = item
        end
        -- A macro containing only #showtooltip may have no GetMacroItem result.
        -- Resolve its explicit tooltip argument; don't guess from /use lines.
        if reference == nil and GetMacroInfo then
            local _, _, body = GetMacroInfo(index)
            if not IsSecret(body) and type(body) == "string" then
                for text in body:gmatch("[^\r\n]+") do
                    local command, argument = text:match("^%s*(#%S+)%s+(.+)$")
                    if command and (command:lower() == "#showtooltip" or command:lower() == "#show") then
                        if SecureCmdOptionParse then
                            argument = SecureCmdOptionParse(argument)
                        elseif argument:find("[", 1, true) or argument:find(";", 1, true) then
                            argument = nil
                        end
                        if not IsSecret(argument) and type(argument) == "string" then
                            reference = argument:match("^%s*(.-)%s*$")
                            if reference == "" then reference = nil end
                        end
                        break
                    end
                end
            end
        end
    end
    if IsSecret(reference) or (type(reference) ~= "string" and type(reference) ~= "number") then
        return
    end

    local price = select(11, getInfo(reference))
    if PublicNumber(price) and price > 0 then return price end
end

local function IsComparisonTooltip(tooltip)
    -- Blizzard's comparison frames do not consistently set isShopping.
    return tooltip.isShopping
        or tooltip == ShoppingTooltip1 or tooltip == ShoppingTooltip2
        or tooltip == ItemRefShoppingTooltip1 or tooltip == ItemRefShoppingTooltip2
end

local function OnSellPrice(tooltip, line)
    if not module:IsEnabled() or IsSecret(line) or type(line) ~= "table"
        or not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden()) then
        return
    end
    -- Keep Blizzard's comparison tooltips and restricted prices untouched.
    if IsComparisonTooltip(tooltip) then return end
    tooltips[tooltip] = true
    if IsShiftKeyDown() or not PublicNumber(line.price) or line.price <= 0
        or IsSecret(line.maxPrice) then
        return
    end
    if line.maxPrice ~= nil and not PublicNumber(line.maxPrice) then return end
    -- Forever uses -1 (and the native renderer accepts values below 1) to mean
    -- that there is no maximum price. Only positive values describe a range.
    local maximum = line.maxPrice
    if maximum ~= nil and maximum < 1 then maximum = nil end

    local count = StackCount(tooltip)
    if not GameTooltip_OnTooltipAddMoney then return end
    local price, maxPrice
    if PublicNumber(count) then
        if count <= 1 then
            return
        end
        price = math.floor(line.price / count + 0.5)
        maxPrice = maximum and math.floor(maximum / count + 0.5) or nil
    else
        -- Item macros have no bag-slot owner. Read the resolved item's unit price
        -- instead of guessing the quantity from an action-bar button's count.
        if maximum ~= nil then return end
        price = UnitVendorPrice(tooltip)
        if not price or price >= line.price then
            return
        end
    end
    GameTooltip_OnTooltipAddMoney(tooltip, price, maxPrice)
    -- Consume the original sell-price line so Blizzard doesn't append it again.
    return true
end

local function RefreshTooltips()
    for tooltip in pairs(tooltips) do
        if IsComparisonTooltip(tooltip) then
            tooltips[tooltip] = nil
        elseif not (tooltip.IsForbidden and tooltip:IsForbidden()) and tooltip:IsShown()
            and tooltip.RebuildFromTooltipInfo then
            tooltip:RebuildFromTooltipInfo()
        end
    end
end

local refreshPending = false
local function QueueRefreshTooltips()
    if refreshPending then return end
    refreshPending = true
    -- Let Blizzard finish opening/closing comparison tooltips before rebuilding
    -- the main tooltip. Multiple modifier events in one frame need one refresh.
    C_Timer.After(0, function()
        refreshPending = false
        RefreshTooltips()
    end)
end

function module:OnEnable()
    if not installed and TooltipDataProcessor and TooltipDataProcessor.AddLinePreCall
        and Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.SellPrice ~= nil then
        TooltipDataProcessor.AddLinePreCall(Enum.TooltipDataLineType.SellPrice, OnSellPrice)
        installed = true
    end
    RefreshTooltips()
end

function module:OnDisable()
    -- Rebuild visible tooltips with the native stack price immediately.
    RefreshTooltips()
end

module:RegisterEvent("MODIFIER_STATE_CHANGED", function(_, _, key)
    if not IsSecret(key) and (key == "LSHIFT" or key == "RSHIFT") then
        QueueRefreshTooltips()
    end
end)

