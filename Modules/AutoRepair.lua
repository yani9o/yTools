local L = _G.yTools.L
local yTools = _G.yTools

local module = yTools:RegisterModule(
    "AutoRepair",
    {
        title = L.AUTOMATION_AUTO_REPAIR,
        description = L.AUTOMATICALLY_REPAIRS_EQUIPMENT_WHEN_VISITING_A_MERCHANT,
        defaultEnabled = true,
    }
)


------------------------------------------------------------
-- Local state
------------------------------------------------------------

local merchantHooked = false
local repairHooked = false


------------------------------------------------------------
-- Repair
------------------------------------------------------------

local function RepairEquipment()
    if not module:IsEnabled() then
        return
    end

    local button = _G.MerchantRepairAllButton

    if button
        and button:IsShown()
        and button:IsEnabled()
    then
        button:Click()
    end
end


------------------------------------------------------------
-- Setup Repair
------------------------------------------------------------

local function SetupRepair()
    if repairHooked then
        return true
    end

    local button = _G.MerchantRepairAllButton

    if not button then
        return false
    end

    repairHooked = true

    button:HookScript(
        "OnShow",
        function()
            RepairEquipment()
        end
    )

    return true
end


------------------------------------------------------------
-- Merchant
------------------------------------------------------------

local function OnMerchantShow()
    if not module:IsEnabled() then
        return
    end

    SetupRepair()

    RepairEquipment()
end


------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------

function module:OnEnable()
    if not merchantHooked then
        merchantHooked = true

        module:RegisterEvent(
            "MERCHANT_SHOW",
            OnMerchantShow
        )
    end

    SetupRepair()
end


function module:OnDisable()
end
