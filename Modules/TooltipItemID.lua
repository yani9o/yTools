local L = _G.yTools.L
local module = _G.yTools:RegisterModule("Tooltip_ItemID", {
    title = L.TOOLTIP_ITEM_IDS,
    description = L.SHOWS_ITEM_IDS_IN_BAG_EQUIPMENT_LOOT_LINKED_ITEM_AND_COMPARISON_TOOLTIPS,
    defaultEnabled = true,
})

local LABEL = L.ITEM_ID
local installed = false

local function IsSecret(value)
    if issecretvalue and issecretvalue(value) then
        return true
    end
    return type(value) == "table" and issecrettable and issecrettable(value) or false
end



local function AddID(tooltip, id)
    if not module:IsEnabled() or IsSecret(id) then
        return
    end
    if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then
        return
    end
    if not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden()) then
        return
    end

    -- Counts must precede IDs even when the counter was enabled later.
    local counter = _G.yTools:GetModule("Tooltip_ItemCount")
    if counter and counter.AddItemCounts then counter:AddItemCounts(tooltip, id) end

    -- Check every existing line so tooltip refreshes never duplicate this ID.
    -- Restricted tooltip text must never be compared from addon code.
    local name = tooltip:GetName()
    if name then
        local count = tooltip:NumLines()
        if IsSecret(count) then return end
        for index = 1, count do
            local line = _G[name .. "TextLeft" .. index]
            if line and not (line.IsForbidden and line:IsForbidden()) then
                local text = line:GetText()
                if not IsSecret(text) and text == LABEL then
                    return
                end
            end
        end
    end

    _G.yTools.UI.TooltipFooterGap(tooltip, "ids")
    tooltip:AddDoubleLine(LABEL, tostring(id), 1, 0.82, 0, 1, 1, 1)
    -- The native tooltip processor shows and lays out the tooltip after this call.
    return true
end

local function MacroItemID(tooltip, data)
    local getInfo = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if not getInfo then return end
    local function Lookup(reference)
        if IsSecret(reference) or (type(reference) ~= "string" and type(reference) ~= "number") then return end
        if type(reference) == "string" then
            reference = reference:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("^%s*(.-)%s*$")
            if reference == "" then return end
        end
        local id = getInfo(reference)
        if not IsSecret(id) and id == nil then
            local fullInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
            if fullInfo then
                local _, link = fullInfo(reference)
                if not IsSecret(link) and type(link) == "string" then id = getInfo(link) end
            end
        end
        if not IsSecret(id) and type(id) == "number" and id > 0 then return id end
    end
    if not IsSecret(data) and type(data) == "table" then
        local lines = data.lines
        if not IsSecret(lines) and type(lines) == "table" then
            for _, line in ipairs(lines) do
                if not IsSecret(line) and type(line) == "table" then
                    local id = Lookup(line.leftText)
                    if id then return id end
                end
            end
        end
    end
    local name = tooltip:GetName()
    local count = tooltip:NumLines()
    if not IsSecret(name) and type(name) == "string" and not IsSecret(count) and type(count) == "number" then
        for index = 1, count do
            local line = _G[name .. "TextLeft" .. index]
            if line and line.GetText and not (line.IsForbidden and line:IsForbidden()) then
                local id = Lookup(line:GetText())
                if id then return id end
            end
        end
    end
    local info = tooltip.GetProcessingTooltipInfo and tooltip:GetProcessingTooltipInfo()
    local index = not IsSecret(data) and type(data) == "table" and data.id
    if not IsSecret(info) and type(info) == "table" and not IsSecret(info.getterName)
        and info.getterName == "GetAction" then
        local args = info.getterArgs
        if not IsSecret(args) and type(args) == "table" and not IsSecret(args[1])
            and type(args[1]) == "number" and GetActionText and GetMacroIndexByName then
            local macroName = GetActionText(args[1])
            if not IsSecret(macroName) and type(macroName) == "string" and macroName ~= "" then
                local resolved = GetMacroIndexByName(macroName)
                if not IsSecret(resolved) and type(resolved) == "number" and resolved > 0 then index = resolved end
            end
        end
    end
    if not IsSecret(index) and type(index) == "number" and index > 0 then
        if GetMacroItem then
            local item, link = GetMacroItem(index)
            local id = Lookup(link) or Lookup(item)
            if id then return id end
        end
        if GetMacroInfo then
            local _, _, body = GetMacroInfo(index)
            if not IsSecret(body) and type(body) == "string" then
                for line in body:gmatch("[^\r\n]+") do
                    local command, argument = line:match("^%s*(#%S+)%s+(.+)$")
                    if command and (command:lower() == "#showtooltip" or command:lower() == "#show") then
                        if SecureCmdOptionParse then argument = SecureCmdOptionParse(argument)
                        elseif argument:find("[", 1, true) or argument:find(";", 1, true) then argument = nil end
                        return Lookup(argument)
                    end
                end
            end
        end
    end
end

local function OnMacroTooltip(tooltip, data)
    if not module:IsEnabled() or not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden()) then return end
    local id = MacroItemID(tooltip, data)
    AddID(tooltip, id)
end

function module:GetMacroItemID(tooltip, data)
    return MacroItemID(tooltip, data)
end

local function OnTooltip(tooltip, data)
    if not module:IsEnabled() or IsSecret(data) or type(data) ~= "table" then
        return
    end
    AddID(tooltip, data.id)
end

function module:OnEnable()
    if installed then return end
    if not TooltipDataProcessor or not TooltipDataProcessor.AddTooltipPostCall
        or not Enum or not Enum.TooltipDataType then
        return
    end

    local types = Enum.TooltipDataType
    if types.Item ~= nil then
        TooltipDataProcessor.AddTooltipPostCall(types.Item, OnTooltip)
    end
    if types.Toy ~= nil then
        TooltipDataProcessor.AddTooltipPostCall(types.Toy, OnTooltip)
    end
    if types.Macro ~= nil then
        TooltipDataProcessor.AddTooltipPostCall(types.Macro, OnMacroTooltip)
    end
    installed = true
end

-- Native callbacks cannot be removed; the enabled check keeps disabled modules inert.
