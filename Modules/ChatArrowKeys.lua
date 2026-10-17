local L = _G.yTools.L
local yTools = _G.yTools

local module = yTools:RegisterModule(
    "ChatArrowKeys",
    {
        title = L.CHAT_ARROW_KEYS,
        description = L.ALLOWS_ARROW_KEYS_IN_CHAT_EDIT_BOXES_WITHOUT_HOLDING_ALT,
        defaultEnabled = true,
    }
)


------------------------------------------------------------
-- Enable behavior
------------------------------------------------------------

local function FixChatEditBox(editBox)
    if not module:IsEnabled() then
        return
    end

    if not editBox then
        return
    end

    editBox:SetAltArrowKeyMode(false)

    if not editBox.yToolsArrowKeysHooked then
        editBox.yToolsArrowKeysHooked = true

        hooksecurefunc(
            editBox,
            "SetAltArrowKeyMode",
            function(self, enabled)
                if not module:IsEnabled() then
                    return
                end

                if enabled then
                    self:SetAltArrowKeyMode(false)
                end
            end
        )
    end
end


------------------------------------------------------------
-- Apply to existing chat windows
------------------------------------------------------------

local function EnableChatArrowKeys()
    if not module:IsEnabled() then
        return
    end

    for i = 1, NUM_CHAT_WINDOWS do
        local editBox =
            _G["ChatFrame" .. i .. "EditBox"]

        if editBox then
            FixChatEditBox(editBox)
        end
    end

    if ChatFrameUtil
        and ChatFrameUtil.ForEachChatFrame
    then
        ChatFrameUtil.ForEachChatFrame(
            function(chatFrame)
                if chatFrame
                    and chatFrame.editBox
                then
                    FixChatEditBox(
                        chatFrame.editBox
                    )
                end
            end
        )
    end
end


------------------------------------------------------------
-- Restore default behavior
------------------------------------------------------------

local function DisableChatArrowKeys()
    for i = 1, NUM_CHAT_WINDOWS do
        local editBox =
            _G["ChatFrame" .. i .. "EditBox"]

        if editBox then
            editBox:SetAltArrowKeyMode(true)
        end
    end

    if ChatFrameUtil
        and ChatFrameUtil.ForEachChatFrame
    then
        ChatFrameUtil.ForEachChatFrame(
            function(chatFrame)
                if chatFrame
                    and chatFrame.editBox
                then
                    chatFrame.editBox:SetAltArrowKeyMode(true)
                end
            end
        )
    end
end


------------------------------------------------------------
-- Chat activation hook
------------------------------------------------------------

local function HookChatActivation()
    if not module:IsEnabled() then
        return
    end

    if not ChatFrameUtil
        or not ChatFrameUtil.ActivateChat
    then
        return
    end

    if ChatFrameUtil.yToolsArrowKeysHooked then
        return
    end

    ChatFrameUtil.yToolsArrowKeysHooked = true

    hooksecurefunc(
        ChatFrameUtil,
        "ActivateChat",
        function(editBox)
            if module:IsEnabled() then
                FixChatEditBox(editBox)
            end
        end
    )
end


------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------

function module:OnEnable()
    EnableChatArrowKeys()
    HookChatActivation()
end


function module:OnDisable()
    DisableChatArrowKeys()
end


------------------------------------------------------------
-- Events
------------------------------------------------------------

module:RegisterEvent("PLAYER_ENTERING_WORLD",function()
	EnableChatArrowKeys()
	HookChatActivation()
end)
