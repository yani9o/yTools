local L = _G.yTools.L
local yTools = _G.yTools

local module = yTools:RegisterModule(
    "Bags",
    {
        title = L.BAGS_MOVABLE_BAGS_YTOOLS_BAGRESET,
        description = L.MAKES_THE_COMBINED_BAG_MOVABLE_AND_SAVES_ITS_POSITION,
        defaultEnabled = true,
    }
)


------------------------------------------------------------
-- Local state
------------------------------------------------------------

local bagFrame
local titleContainer


------------------------------------------------------------
-- Database
------------------------------------------------------------

local function GetDB()
    return module:GetDB()
end


------------------------------------------------------------
-- Find bag
------------------------------------------------------------

local function FindBagFrame()
    return _G.ContainerFrameCombinedBags
end


------------------------------------------------------------
-- Save position
------------------------------------------------------------

local function SaveBagPosition()
    if not bagFrame then
        return
    end

    local point, _, relativePoint, x, y =
        bagFrame:GetPoint(1)

    if point then
        local DB = GetDB()

        DB.bagPosition = {
            point = point,
            relativePoint = relativePoint,
            x = x,
            y = y,
        }
    end
end


------------------------------------------------------------
-- Restore position
------------------------------------------------------------

local function RestoreBagPosition()
    local DB = GetDB()

    if not bagFrame
        or not DB.bagPosition
    then
        return
    end

    local pos = DB.bagPosition

    bagFrame:ClearAllPoints()

    bagFrame:SetPoint(
        pos.point or "CENTER",
        UIParent,
        pos.relativePoint
            or pos.point
            or "CENTER",
        pos.x or 0,
        pos.y or 0
    )
end


------------------------------------------------------------
-- Reset
------------------------------------------------------------

local function ResetBagPosition()
    if not bagFrame then
        yTools:Print(
            "|cffff0000yTools:|r "
            .. L.BAG_FRAME_NOT_FOUND
        )

        return
    end

    local DB = GetDB()

    DB.bagPosition = nil

    bagFrame:ClearAllPoints()

    bagFrame:SetPoint(
        "BOTTOMRIGHT",
        UIParent,
        "BOTTOMRIGHT",
        -60,
        85
    )

    SaveBagPosition()

    yTools:Print(
        "|cff00ff00yTools:|r "
        .. L.BAG_POSITION_RESET
    )
end


------------------------------------------------------------
-- Movement
------------------------------------------------------------

local function SetupBagMovement()
    if not bagFrame then
        return false
    end

    titleContainer =
        bagFrame.TitleContainer

    if not titleContainer then
        return false
    end

    bagFrame:SetMovable(true)
    bagFrame:SetClampedToScreen(true)

    titleContainer:EnableMouse(true)
    titleContainer:RegisterForDrag(
        "LeftButton"
    )

    RestoreBagPosition()

    if not titleContainer.yToolsDragHooked then
        titleContainer.yToolsDragHooked = true

        titleContainer:HookScript(
            "OnDragStart",
            function()
                if not module:IsEnabled() then
                    return
                end

                if not InCombatLockdown() then
                    bagFrame:StartMoving()
                end
            end
        )

        titleContainer:HookScript(
            "OnDragStop",
            function()
                if not module:IsEnabled() then
                    return
                end

                bagFrame:StopMovingOrSizing()

                SaveBagPosition()
            end
        )
    end

    return true
end


------------------------------------------------------------
-- Setup
------------------------------------------------------------

local function SetupBag()
    if not module:IsEnabled() then
        return false
    end

    bagFrame = FindBagFrame()

    if not bagFrame then
        return false
    end

    SetupBagMovement()

    if not bagFrame.yToolsPositionHooked then
        bagFrame.yToolsPositionHooked = true

        hooksecurefunc(
            bagFrame,
            "SetPoint",
            function()
                if not module:IsEnabled() then
                    return
                end

                if bagFrame.yToolsMoving then
                    return
                end

                local DB = GetDB()

                if DB and DB.bagPosition then
                    bagFrame.yToolsMoving = true

                    RestoreBagPosition()

                    bagFrame.yToolsMoving = false
                end
            end
        )
    end

    return true
end


------------------------------------------------------------
-- Disable
------------------------------------------------------------

local function DisableBagMovement()
    if not bagFrame then
        return
    end

    bagFrame:StopMovingOrSizing()
    bagFrame:SetMovable(false)

    if titleContainer then
        titleContainer:EnableMouse(false)
    end
end


------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------

function module:OnEnable()
    SetupBag()
end


function module:OnDisable()
    DisableBagMovement()
end


------------------------------------------------------------
-- Events
------------------------------------------------------------

module:RegisterEvent(
    "PLAYER_ENTERING_WORLD",
    function()
        SetupBag()
    end
)


------------------------------------------------------------
-- Slash command
------------------------------------------------------------

module:RegisterSlashCommand(
    "bagreset",
    function()
        ResetBagPosition()
    end,
    L.RESET_THE_COMBINED_BAG_POSITION
)
