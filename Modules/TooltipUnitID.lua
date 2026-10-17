local L = _G.yTools.L
local module = _G.yTools:RegisterModule("TooltipUnitID", {
    title = L.TOOLTIP_UNIT_IDS,
    description = L.SHOWS_NPC_ENTRY_IDS_IN_CREATURE_PET_VEHICLE_AND_CORPSE_TOOLTIPS,
    defaultEnabled = false,
})

local LABEL = L.NPC_ID
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
end

local function OnTooltip(tooltip, data)
    if not module:IsEnabled() or IsSecret(data) or type(data) ~= "table" then
        return
    end
    local guid = data.guid
    if IsSecret(guid) then return end

    if type(guid) == "string" then
        -- Modern GUIDs store the NPC entry in the sixth hyphen-separated field.
        local kind, id = guid:match("^([^-]+)%-[^-]+%-[^-]+%-[^-]+%-[^-]+%-(%d+)%-")
        if kind == "Creature" or kind == "Vehicle" or kind == "Pet" then
            AddID(tooltip, tonumber(id))
        end
        -- Player GUIDs have no NPC entry ID.
    elseif guid == nil then
        AddID(tooltip, data.id)
    end
end

function module:OnEnable()
    if installed then return end
    if not TooltipDataProcessor or not TooltipDataProcessor.AddTooltipPostCall
        or not Enum or not Enum.TooltipDataType then
        return
    end

    local types = Enum.TooltipDataType
    if types.Unit ~= nil then
        TooltipDataProcessor.AddTooltipPostCall(types.Unit, OnTooltip)
    end
    if types.Corpse ~= nil then
        TooltipDataProcessor.AddTooltipPostCall(types.Corpse, OnTooltip)
    end
    installed = true
end

-- Native callbacks cannot be removed; the enabled check keeps disabled modules inert.
