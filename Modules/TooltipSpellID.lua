local L = _G.yTools.L
local module = _G.yTools:RegisterModule("Tooltip_SpellID", {
    title = L.TOOLTIP_SPELL_IDS,
    description = L.SHOWS_SPELL_IDS_IN_SPELL_ACTION_BAR_BUFF_AND_DEBUFF_TOOLTIPS,
    defaultEnabled = true,
})

local LABEL = L.SPELL_ID
local installed = false

local function IsSecret(value)
    if issecretvalue and issecretvalue(value) then
        return true
    end
    return type(value) == "table" and issecrettable and issecrettable(value) or false
end



local function AddID(tooltip, id)
    if not module:IsEnabled() then
        return
    end
    local restricted = IsSecret(id)
    if type(id) ~= "number" or (not restricted and (id <= 0 or id ~= math.floor(id))) then
        return
    end
    if not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden()) then
        return
    end

    -- Check every existing line so tooltip refreshes never duplicate this ID.
    -- Restricted tooltip text must never be compared from addon code.
    local name = tooltip:GetName()
    if not IsSecret(name) and name then
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
    if restricted then
        -- Secret IDs can be displayed by a native FontString, but must never
        -- be compared, formatted in Lua, or used as lookup keys.
        if not name or IsSecret(name) then return end
        tooltip:AddDoubleLine(LABEL, "0000000", 1, 0.82, 0, 1, 1, 1)
        local right = _G[name .. "TextRight" .. tooltip:NumLines()]
        if right and right.SetFormattedText and not (right.IsForbidden and right:IsForbidden()) then
            right:SetFormattedText("%d", id)
        end
    else
        tooltip:AddDoubleLine(LABEL, tostring(id), 1, 0.82, 0, 1, 1, 1)
    end
    -- The native tooltip processor shows and lays out the tooltip after this call.
    return true
end

local auraMethods = {
    SetUnitBuff = "buff", SetUnitDebuff = "debuff", SetUnitAura = "aura",
    SetUnitBuffByAuraInstanceID = "instance", SetUnitDebuffByAuraInstanceID = "instance",
    SetUnitAuraByAuraInstanceID = "instance",
}

local function AuraSpellID(mode, unit, index, filter)
    if IsSecret(unit) or type(unit) ~= "string" or IsSecret(index) or type(index) ~= "number"
        or IsSecret(filter) then return end
    local api = C_UnitAuras
    local getter = api and (mode == "instance" and api.GetAuraDataByAuraInstanceID
        or mode == "buff" and api.GetBuffDataByIndex
        or mode == "debuff" and api.GetDebuffDataByIndex
        or mode == "aura" and api.GetAuraDataByIndex)
    if not getter and api and mode ~= "instance" then
        getter = api.GetAuraDataByIndex
        filter = filter or (mode == "debuff" and "HARMFUL" or "HELPFUL")
    end
    if getter then
        local ok, aura = pcall(getter, unit, index, filter)
        if ok and not IsSecret(aura) and type(aura) == "table" then return aura.spellId end
    elseif mode ~= "instance" then
        local legacy = mode == "buff" and UnitBuff or mode == "debuff" and UnitDebuff or UnitAura
        if legacy then
            local result = {pcall(legacy, unit, index, filter)}
            if result[1] then return result[11] end
        end
    end
end

local function OnAuraTooltip(tooltip, data)
    if not module:IsEnabled() then return end
    local info = tooltip.GetProcessingTooltipInfo and tooltip:GetProcessingTooltipInfo()
    if not IsSecret(info) and type(info) == "table" and not IsSecret(info.getterName) then
        local method = type(info.getterName) == "string" and info.getterName:gsub("^Get", "Set")
        local mode = method and auraMethods[method]
        local args = info.getterArgs
        if mode and not IsSecret(args) and type(args) == "table" then
            local id = AuraSpellID(mode, args[1], args[2], args[3])
            if IsSecret(id) or id ~= nil then AddID(tooltip, id); return end
        end
    end
    if not IsSecret(data) and type(data) == "table" then AddID(tooltip, data.id) end
end

local function OnTooltip(tooltip, data)
    if not module:IsEnabled() or IsSecret(data) or type(data) ~= "table" then
        return
    end
    AddID(tooltip, data.id)
end

local function OnMacroTooltip(tooltip, data)
    if not module:IsEnabled() or IsSecret(data) or type(data) ~= "table" then
        return
    end
    local index = data.id
    if IsSecret(index) or type(index) ~= "number" or index <= 0 or not GetMacroSpell then
        return
    end
    -- Ask the client which spell the macro currently displays, including modifiers.
    AddID(tooltip, GetMacroSpell(index))
end

local function OnActionTooltip(tooltip, slot)
    if not module:IsEnabled() or IsSecret(slot) or type(slot) ~= "number"
        or not GetActionInfo then
        return
    end
    local kind, id, subtype = GetActionInfo(slot)
    if IsSecret(kind) or IsSecret(id) or IsSecret(subtype) or kind ~= "macro" then
        return
    end

    local spellID
    if subtype == "spell" then
        spellID = id
    elseif subtype ~= "item" and type(id) == "number" and id > 0 and GetMacroSpell then
        spellID = GetMacroSpell(id)
    end
    -- SetAction has already laid out the tooltip; resize it only when we add a line.
    if AddID(tooltip, spellID) then
        tooltip:Show()
    end
end

function module:OnEnable()
    if installed then return end
    if not TooltipDataProcessor or not TooltipDataProcessor.AddTooltipPostCall
        or not Enum or not Enum.TooltipDataType then
        return
    end

    local types = Enum.TooltipDataType
    if types.Spell ~= nil then
        TooltipDataProcessor.AddTooltipPostCall(types.Spell, OnTooltip)
    end
    if types.UnitAura ~= nil then
        TooltipDataProcessor.AddTooltipPostCall(types.UnitAura, OnAuraTooltip)
    end
    if types.PetAction ~= nil then
        TooltipDataProcessor.AddTooltipPostCall(types.PetAction, OnTooltip)
    end
    if types.Totem ~= nil then
        TooltipDataProcessor.AddTooltipPostCall(types.Totem, OnTooltip)
    end
    if types.Macro ~= nil then
        TooltipDataProcessor.AddTooltipPostCall(types.Macro, OnMacroTooltip)
    end
    -- Some macro action tooltips don't use the native Spell tooltip type.
    if GameTooltip and GameTooltip.SetAction and hooksecurefunc then
        hooksecurefunc(GameTooltip, "SetAction", OnActionTooltip)
    end
    if GameTooltip and hooksecurefunc then
        for method, mode in pairs(auraMethods) do
            if GameTooltip[method] then
                hooksecurefunc(GameTooltip, method, function(tooltip, unit, index, filter)
                    if not module:IsEnabled() then return end
                    if AddID(tooltip, AuraSpellID(mode, unit, index, filter)) then tooltip:Show() end
                end)
            end
        end
    end
    installed = true
end

-- Native callbacks cannot be removed; the enabled check keeps disabled modules inert.
