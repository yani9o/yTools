local L = _G.yTools.L
local module = _G.yTools:RegisterModule("Tooltip_ItemLevel", {
    title = L.TOOLTIP_ITEM_LEVEL,
    description = L.TOOLTIP_ITEM_LEVEL_DESCRIPTION,
    defaultEnabled = true,
})

local installed = false
local tooltips = setmetatable({}, { __mode = "k" })
local pending = setmetatable({}, { __mode = "k" })
local requested = {}

local function IsSecret(value)
    if issecretvalue and issecretvalue(value) then return true end
    return type(value) == "table" and issecrettable and issecrettable(value) or false
end

local function PublicReference(value)
    return not IsSecret(value) and (type(value) == "string" or type(value) == "number")
end

local function ItemReference(tooltip, data)
    if not IsSecret(data.type) and data.type == Enum.TooltipDataType.Macro then
        local ids = _G.yTools:GetModule("Tooltip_ItemID")
        return ids and ids.GetMacroItemID and ids:GetMacroItemID(tooltip, data)
    end
    if TooltipUtil and TooltipUtil.GetDisplayedItem then
        local _, link = TooltipUtil.GetDisplayedItem(tooltip)
        if PublicReference(link) then return link end
    end
    if PublicReference(data.hyperlink) then return data.hyperlink end
    if not IsSecret(data.guid) and type(data.guid) == "string"
        and C_Item and C_Item.GetItemLinkByGUID then
        local link = C_Item.GetItemLinkByGUID(data.guid)
        if PublicReference(link) then return link end
    end
    if PublicReference(data.id) then return data.id end
end

local function HasLevelLine(tooltip, data)
    local nativeLabel = not IsSecret(ITEM_LEVEL) and type(ITEM_LEVEL) == "string"
        and ITEM_LEVEL:match("^(.-)%%")
    local function Matches(text)
        if IsSecret(text) or type(text) ~= "string" then return false end
        text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        local customLabel = L.ITEM_LEVEL_LABEL:gsub(":$", "") .. " "
        return text == L.ITEM_LEVEL_LABEL or text:sub(1, #customLabel) == customLabel
            or (nativeLabel and nativeLabel ~= ""
            and text:sub(1, #nativeLabel) == nativeLabel)
    end
    if not IsSecret(data.lines) and type(data.lines) == "table" then
        for _, line in ipairs(data.lines) do
            if not IsSecret(line) and type(line) == "table" and Matches(line.leftText) then return true end
        end
    end
    local name, count = tooltip:GetName(), tooltip:NumLines()
    if IsSecret(name) or type(name) ~= "string" or IsSecret(count) or type(count) ~= "number" then return false end
    for i = 1, count do
        local line = _G[name .. "TextLeft" .. i]
        if line and not (line.IsForbidden and line:IsForbidden()) and Matches(line:GetText()) then return true end
    end
    return false
end

local function OnTooltip(tooltip, data)
    if not module:IsEnabled() or not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden())
        or IsSecret(data) or type(data) ~= "table" then return end
    tooltips[tooltip] = true
    pending[tooltip] = nil
    if HasLevelLine(tooltip, data) then return end
    local reference = ItemReference(tooltip, data)
    if not PublicReference(reference) then return end
    local getLevel = C_Item and C_Item.GetDetailedItemLevelInfo or GetDetailedItemLevelInfo
    local level = getLevel and getLevel(reference)
    if not IsSecret(level) and level == nil then
        local getInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
        if getInfo then level = select(4, getInfo(reference)) end
    end
    if IsSecret(level) then return end
    if type(level) == "number" then
        if level > 0 then
            local text = L.ITEM_LEVEL_LABEL:gsub(":$", "") .. " " .. math.floor(level)
            if not IsSecret(ITEM_LEVEL) and type(ITEM_LEVEL) == "string" then
                text = string.format(ITEM_LEVEL, math.floor(level))
            end
            tooltip:AddLine(text, 1, .82, 0)
        end
        return
    end
    local getID = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    local id = getID and getID(reference)
    if IsSecret(id) or type(id) ~= "number" or id <= 0 then return end
    pending[tooltip] = id
    if not requested[id] and C_Item and C_Item.RequestLoadItemDataByID then
        requested[id] = true
        C_Item.RequestLoadItemDataByID(id)
    end
end

local function OnItemName(tooltip, line)
    if not module:IsEnabled() or not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden()) then return end
    local info = tooltip.GetProcessingTooltipInfo and tooltip:GetProcessingTooltipInfo()
    if IsSecret(info) or type(info) ~= "table" then return end
    local data = info.tooltipData
    if IsSecret(data) or type(data) ~= "table" or IsSecret(data.type) or IsSecret(line)
        or type(line) ~= "table" then return end
    if data.type == Enum.TooltipDataType.Item then
        if IsSecret(line.type) or line.type ~= Enum.TooltipDataLineType.ItemName then return end
    elseif data.type == Enum.TooltipDataType.Macro then
        -- Macro titles can be ordinary lines, with an empty spacer above them.
        if IsSecret(data.lines) or type(data.lines) ~= "table" then return end
        local title
        for _, candidate in ipairs(data.lines) do
            if not IsSecret(candidate) and type(candidate) == "table" then
                local text = candidate.leftText
                if not IsSecret(text) and type(text) == "string" and text:match("%S") then title = candidate; break end
            end
        end
        if line ~= title then return end
    else return end
    -- Native line processing is still in progress here: adding the level now
    -- places it directly after the name and before binding, stats and effects.
    OnTooltip(tooltip, data)
end

local function RefreshTooltips()
    for tooltip in pairs(tooltips) do
        if not (tooltip.IsForbidden and tooltip:IsForbidden()) and tooltip:IsShown()
            and tooltip.RebuildFromTooltipInfo then tooltip:RebuildFromTooltipInfo() end
    end
end

function module:OnEnable()
    if not installed and TooltipDataProcessor and TooltipDataProcessor.AddLinePostCall
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item ~= nil
        and Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemName ~= nil then
        TooltipDataProcessor.AddLinePostCall(TooltipDataProcessor.AllTypes or Enum.TooltipDataLineType.ItemName, OnItemName)
        installed = true
    end
    RefreshTooltips()
end

function module:OnDisable()
    wipe(pending)
    wipe(requested)
    RefreshTooltips()
end

module:RegisterEvent("GET_ITEM_INFO_RECEIVED", function(_, _, id, success)
    if IsSecret(id) or type(id) ~= "number" or IsSecret(success) then return end
    requested[id] = nil
    for tooltip, itemID in pairs(pending) do
        if itemID == id then
            pending[tooltip] = nil
            if success and not (tooltip.IsForbidden and tooltip:IsForbidden()) and tooltip:IsShown()
                and tooltip.RebuildFromTooltipInfo then tooltip:RebuildFromTooltipInfo() end
        end
    end
end)
