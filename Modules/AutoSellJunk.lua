local L = _G.yTools.L
local yTools = _G.yTools

local module = yTools:RegisterModule(
    "AutoSellJunk",
    {
        title = L.AUTOMATION_AUTO_SELL_JUNK,
        description = L.AUTOMATICALLY_SELLS_JUNK_ITEMS_WHEN_VISITING_A_MERCHANT,
        defaultEnabled = true,
    }
)


------------------------------------------------------------
-- Local state
------------------------------------------------------------

local merchantHooked = false
local autoSellHooked = false
local popupHooked = false
local soundHooked = false

local sellTriggered = false
local waitingForPopup = false


------------------------------------------------------------
-- Auto Sell popup
------------------------------------------------------------

local function IsAutoSellPopup()
    local popup = _G.StaticPopup1

    if not popup
        or not popup:IsShown()
    then
        return false
    end

    local data = popup.data

    return data
        and data.callback
            == _G.MerchantFrame_OnSellAllJunkButtonConfirmed
end


------------------------------------------------------------
-- Confirm Auto Sell
------------------------------------------------------------

local function ConfirmAutoSell()
    if not module:IsEnabled()
        or not waitingForPopup
    then
        return
    end

    if not IsAutoSellPopup() then
        return
    end

    waitingForPopup = false

    local button = _G.StaticPopup1Button1

    if not button
        or not button:IsShown()
        or not button:IsEnabled()
    then
        return
    end

    button:Click()
end


------------------------------------------------------------
-- Suppress Auto Sell confirmation sound
------------------------------------------------------------

local function SetupSoundHook()
    if soundHooked then
        return
    end

    soundHooked = true

    hooksecurefunc(
        "PlaySound",
        function(sound)
            if not module:IsEnabled()
                or not waitingForPopup
                or sound ~= 850
            then
                return
            end

            ------------------------------------------------
            -- Play a different sound to obtain a handle.
            -- The handle immediately before it belongs
            -- to the sound that was just played.
            ------------------------------------------------

            local played, handle = PlaySound(851)

            if played and handle then
                StopSound(handle - 1)
                StopSound(handle)
            end
        end
    )
end


------------------------------------------------------------
-- Auto Sell
------------------------------------------------------------

local function SellJunk()
    if not module:IsEnabled()
        or sellTriggered
    then
        return
    end

    local button = _G.MerchantSellAllJunkButton

    if not button
        or not button:IsShown()
        or not button:IsEnabled()
    then
        return
    end

    sellTriggered = true
    waitingForPopup = true

    button:Click()
end


------------------------------------------------------------
-- Setup Auto Sell
------------------------------------------------------------

local function SetupAutoSell()
    if autoSellHooked then
        return true
    end

    local button = _G.MerchantSellAllJunkButton

    if not button then
        return false
    end

    autoSellHooked = true

    button:HookScript(
        "OnShow",
        function()
            SellJunk()
        end
    )

    return true
end


------------------------------------------------------------
-- Setup confirmation
------------------------------------------------------------

local function SetupConfirmation()
    if popupHooked then
        return true
    end

    local popup = _G.StaticPopup1

    if not popup then
        return false
    end

    popupHooked = true

    popup:HookScript(
        "OnShow",
        function()
            ConfirmAutoSell()
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

    sellTriggered = false
    waitingForPopup = false

    SetupAutoSell()
    SetupConfirmation()

    SellJunk()
end


------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------

function module:OnEnable()
    SetupSoundHook()

    if not merchantHooked then
        merchantHooked = true

        module:RegisterEvent(
            "MERCHANT_SHOW",
            OnMerchantShow
        )
    end

    SetupAutoSell()
    SetupConfirmation()
end


function module:OnDisable()
    sellTriggered = false
    waitingForPopup = false
end
