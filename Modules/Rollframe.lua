local L = _G.yTools.L
local yTools = _G.yTools

local module = yTools:RegisterModule(
    "Rollframe",
    {
        title = L.UI_ROLLFRAME_YTOOLS_ROLLFRAME,
        description = L.MOVE_THE_DEFAULT_ROLLFRAME,
        defaultEnabled = true,
    }
)


------------------------------------------------------------
-- Defaults
------------------------------------------------------------

local DEFAULTS = {
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = -170,
    locked = true,
    spacing = 4,
}


------------------------------------------------------------
-- State
------------------------------------------------------------

local anchor
local PositionLootFrames
local positioning = false
local stabilizeTime = 0
local refreshTime = 0
local hooksInstalled = false


------------------------------------------------------------
-- Database
------------------------------------------------------------

local function GetDB()
    local DB = module:GetDB()

    for key, value in pairs(DEFAULTS) do
        if DB[key] == nil then
            DB[key] = value
        end
    end

    return DB
end


------------------------------------------------------------
-- Loot frame
------------------------------------------------------------

local function GetLootFrame(index)
    return _G["GroupLootFrame" .. index]
end


local function UpdateAnchorSize()
    if not anchor then return end

    for i = 1, 8 do
        local frame = GetLootFrame(i)
        if frame then
            local width, height = frame:GetSize()
            if width and height and width > 0 and height > 0 then
                -- Match the displayed size even if the loot frame is scaled.
                local scale = frame:GetEffectiveScale() / anchor:GetEffectiveScale()
                anchor:SetSize(width * scale, height * scale)
                return
            end
        end
    end
end


------------------------------------------------------------
-- Anchor
------------------------------------------------------------

local function CreateAnchor()
    if anchor then
        return
    end

    anchor = CreateFrame(
        "Frame",
        "yToolsLootRollMoverAnchor",
        UIParent
    )

    anchor:SetSize(335, 34) -- Fallback until Blizzard creates a loot frame.
    UpdateAnchorSize()
    anchor:SetFrameStrata("DIALOG")
    anchor:SetMovable(true)
    anchor:EnableMouse(true)
    anchor:RegisterForDrag("LeftButton")
    anchor:Hide()

    local bg = anchor:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.72)

    local border = anchor:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", 1, -1)
    border:SetPoint("BOTTOMRIGHT", -1, 1)
    border:SetColorTexture(0.1, 0.8, 0.1, 0.2)

    local text = anchor:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormal"
    )

    text:SetPoint("CENTER", 0, 5)
    text:SetText(L.ROLLFRAME_POSITION)

    local subText = anchor:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )

    subText:SetPoint("TOP", text, "BOTTOM", 0, -1)
    subText:SetText(
        L.DRAG_TO_MOVE_YTOOLS_ROLLFRAME_LOCK
    )

    -- These regions belong to the mover, so locking also hides the arrow.
    local arrowShaft = anchor:CreateTexture(nil, "OVERLAY")
    arrowShaft:SetColorTexture(0.1, 0.8, 0.1, 1)
    arrowShaft:SetSize(2, 18)
    arrowShaft:SetPoint("TOP", anchor, "BOTTOM", 0, -5)

    local arrowLeft = anchor:CreateTexture(nil, "OVERLAY")
    arrowLeft:SetColorTexture(0.1, 0.8, 0.1, 1)
    arrowLeft:SetSize(2, 10)
    arrowLeft:SetPoint("CENTER", anchor, "BOTTOM", -3, -19)
    arrowLeft:SetRotation(math.pi / 4)

    local arrowRight = anchor:CreateTexture(nil, "OVERLAY")
    arrowRight:SetColorTexture(0.1, 0.8, 0.1, 1)
    arrowRight:SetSize(2, 10)
    arrowRight:SetPoint("CENTER", anchor, "BOTTOM", 3, -19)
    arrowRight:SetRotation(-math.pi / 4)

    local growthText = anchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    growthText:SetPoint("TOP", anchor, "BOTTOM", 0, -29)
    growthText:SetText(L.ADDITIONAL_ROLLS_GROW_DOWN)

    anchor:SetScript("OnDragStart", function(self)
        if not GetDB().locked then
            self:StartMoving()
        end
    end)

    anchor:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()

        local point,
            _,
            relativePoint,
            x,
            y = self:GetPoint(1)

        local DB = GetDB()

        DB.point = point
        DB.relativePoint = relativePoint
        DB.x = x
        DB.y = y

        PositionLootFrames()
    end)
end


------------------------------------------------------------
-- Position anchor
------------------------------------------------------------

local function PositionAnchor()
    if not anchor then
        return
    end

    local DB = GetDB()

    anchor:ClearAllPoints()

    anchor:SetPoint(
        DB.point,
        UIParent,
        DB.relativePoint,
        DB.x,
        DB.y
    )
end


------------------------------------------------------------
-- Position loot frames
------------------------------------------------------------

PositionLootFrames = function()
    if not module:IsEnabled() or positioning then
        return
    end

    UpdateAnchorSize()
    positioning = true

    local DB = GetDB()
    local previous

    for i = 1, 8 do
        local frame = GetLootFrame(i)

        if frame then
            frame:ClearAllPoints()

            if previous then
                frame:SetPoint(
                    "TOP",
                    previous,
                    "BOTTOM",
                    0,
                    -DB.spacing
                )
            else
                frame:SetPoint(
                    "TOPLEFT",
                    anchor,
                    "TOPLEFT"
                )
            end

            previous = frame
        end
    end

    positioning = false
end


------------------------------------------------------------
-- Stabilize
------------------------------------------------------------

local function Stabilize(seconds)
    if not module:IsEnabled() then
        return
    end

    stabilizeTime = math.max(
        stabilizeTime,
        seconds or 0.5
    )

    PositionLootFrames()
end


------------------------------------------------------------
-- Button hooks
------------------------------------------------------------

local function HookButton(button)
    if not button or button.__yToolsRollHook then
        return
    end

    button.__yToolsRollHook = true

    button:HookScript("OnClick", function()
        Stabilize(0.75)
    end)
end


------------------------------------------------------------
-- Loot frame hooks
------------------------------------------------------------

local function HookLootFrames()
    if not module:IsEnabled() then
        return
    end

    for i = 1, 8 do
        local frame = GetLootFrame(i)

        if frame then
            if not frame.__yToolsRollFrameHook then
                frame.__yToolsRollFrameHook = true

                frame:HookScript("OnShow", function()
                    Stabilize(0.5)
                end)

                frame:HookScript("OnHide", function()
                    Stabilize(0.75)
                end)
            end

            HookButton(frame.needButton)
            HookButton(frame.greedButton)
            HookButton(frame.disenchantButton)
            HookButton(frame.passButton)

            HookButton(
                _G["GroupLootFrame" .. i .. "NeedButton"]
            )

            HookButton(
                _G["GroupLootFrame" .. i .. "GreedButton"]
            )

            HookButton(
                _G["GroupLootFrame" .. i .. "DisenchantButton"]
            )

            HookButton(
                _G["GroupLootFrame" .. i .. "PassButton"]
            )
        end
    end
end


------------------------------------------------------------
-- Blizzard hooks
------------------------------------------------------------

local function InstallHooks()
    if hooksInstalled or not hooksecurefunc then
        return
    end

    hooksInstalled = true

    if type(AlertFrame_FixAnchors) == "function" then
        hooksecurefunc(
            "AlertFrame_FixAnchors",
            function()
                if not positioning then
                    Stabilize(0.35)
                end
            end
        )
    end

    if type(GroupLootFrame_OpenNewFrame) == "function" then
        hooksecurefunc(
            "GroupLootFrame_OpenNewFrame",
            function()
                if not positioning then
                    Stabilize(0.5)
                end
            end
        )
    end
end


------------------------------------------------------------
-- Lock / unlock
------------------------------------------------------------

local function SetLocked(locked)
    local DB = GetDB()

    DB.locked = locked

    if locked then
        anchor:Hide()

        yTools:Print(
            "|cff00ff00yTools:|r "
            .. L.ROLLFRAME_POSITION_LOCKED
        )
    else
        PositionAnchor()
        anchor:Show()

        yTools:Print(
            "|cff00ff00yTools:|r "
            .. L.ROLLFRAME_POSITION_UNLOCKED
            .. L.DRAG_THE_GREEN_BOX_THEN_USE
            .. L.YTOOLS_ROLLFRAME_LOCK
        )
    end

    Stabilize(0.2)
end


------------------------------------------------------------
-- Reset
------------------------------------------------------------

local function ResetPosition()
    local DB = GetDB()

    DB.point = DEFAULTS.point
    DB.relativePoint = DEFAULTS.relativePoint
    DB.x = DEFAULTS.x
    DB.y = DEFAULTS.y

    PositionAnchor()
    Stabilize(0.2)

    yTools:Print(
        "|cff00ff00yTools:|r "
        .. L.ROLLFRAME_POSITION_RESET
    )
end


------------------------------------------------------------
-- Options
------------------------------------------------------------

local function PrintOptions()
    yTools:Print(
        L.CFF00CCFF_YTOOLS_ROLLFRAME_R
    )

    yTools:Print(
        "|cff00ff00/ytools rollframe toggle|r"
        .. L.TOGGLE_LOCK_STATE
    )

    yTools:Print(
        "|cff00ff00/ytools rollframe move|r"
        .. L.UNLOCK_AND_SHOW_MOVER
    )

    yTools:Print(
        "|cff00ff00/ytools rollframe lock|r"
        .. L.LOCK_AND_HIDE_MOVER
    )

    yTools:Print(
        "|cff00ff00/ytools rollframe reset|r"
        .. L.RESET_POSITION
    )
end


------------------------------------------------------------
-- Slash command
------------------------------------------------------------

module:RegisterSlashCommand(
    "rollframe",
    function(_, arguments)
        local DB = GetDB()

        if arguments == nil
            or type(arguments) ~= "string"
        then
            PrintOptions()
            return
        end

        arguments = string.match(
            arguments,
            "^%s*(.-)%s*$"
        )

        arguments = string.lower(arguments)

        ----------------------------------------------------
        -- No argument = help
        ----------------------------------------------------

        if arguments == "" then
            PrintOptions()

        ----------------------------------------------------
        -- Toggle
        ----------------------------------------------------

        elseif arguments == "toggle" then
            SetLocked(not DB.locked)

        ----------------------------------------------------
        -- Move / unlock
        ----------------------------------------------------

        elseif arguments == "move"
            or arguments == "unlock"
            or arguments == "drag"
        then
            SetLocked(false)

        ----------------------------------------------------
        -- Lock
        ----------------------------------------------------

        elseif arguments == "lock" then
            SetLocked(true)

        ----------------------------------------------------
        -- Reset
        ----------------------------------------------------

        elseif arguments == "reset" then
            ResetPosition()

        ----------------------------------------------------
        -- Unknown
        ----------------------------------------------------

        else
            yTools:Print(
                "|cffff0000yTools:|r "
                .. L.UNKNOWN_ROLLFRAME_COMMAND
                .. arguments
            )

            PrintOptions()
        end
    end,
    L.MOVE_THE_DEFAULT_ROLLFRAME_2
)


------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------

function module:OnEnable()
    CreateAnchor()
    PositionAnchor()
    HookLootFrames()
    InstallHooks()

    local DB = GetDB()

    if DB.locked then
        anchor:Hide()
    else
        anchor:Show()
    end

    Stabilize(0.2)
end


function module:OnDisable()
    stabilizeTime = 0

    if anchor then
        anchor:Hide()
    end

    for i = 1, 8 do
        local frame = GetLootFrame(i)

        if frame then
            frame:ClearAllPoints()
        end
    end

    if type(AlertFrame_FixAnchors) == "function" then
        AlertFrame_FixAnchors()
    end
end


------------------------------------------------------------
-- Events
------------------------------------------------------------

module:RegisterEvent(
    "PLAYER_ENTERING_WORLD",
    function()
        if not module:IsEnabled() then
            return
        end

        HookLootFrames()
        InstallHooks()
        PositionAnchor()
        Stabilize(0.2)
    end
)


module:RegisterEvent(
    "START_LOOT_ROLL",
    function()
        if not module:IsEnabled() then
            return
        end

        HookLootFrames()
        Stabilize(0.6)
    end
)


module:RegisterEvent(
    "CANCEL_LOOT_ROLL",
    function()
        if not module:IsEnabled() then
            return
        end

        Stabilize(0.75)
    end
)


------------------------------------------------------------
-- Lightweight refresh frame
------------------------------------------------------------

local refreshFrame = CreateFrame("Frame")

refreshFrame:SetScript(
    "OnUpdate",
    function(_, elapsed)
        if not module:IsEnabled() then
            return
        end

        if stabilizeTime > 0 then
            stabilizeTime =
                stabilizeTime - elapsed

            PositionLootFrames()

            refreshTime = 0

            return
        end

        refreshTime =
            refreshTime + elapsed

        if refreshTime < 1 then
            return
        end

        refreshTime = 0

        HookLootFrames()

        for i = 1, 8 do
            local frame = GetLootFrame(i)

            if frame and frame:IsShown() then
                PositionLootFrames()
                break
            end
        end
    end
)