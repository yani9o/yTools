local yTools = _G.yTools
local L = yTools.L

local module = yTools:RegisterModule("AutoQuest", {
    title = L.AUTO_QUEST_MODULE,
    description = L.AUTO_QUEST_DESCRIPTION,
    defaultEnabled = false,
    defaults = { modifier = "CTRL", requireModifier = false },
})

local function SelectGossipQuest()
    local gossip = C_GossipInfo
    if not gossip or not gossip.GetOptions or not gossip.GetActiveQuests
        or not gossip.GetAvailableQuests or not gossip.SelectActiveQuest
        or not gossip.SelectAvailableQuest then
        return
    end

    -- Leave vendors, trainers and other dialogue options accessible.
    if #(gossip.GetOptions() or {}) > 0 then return end

    for _, quest in ipairs(gossip.GetActiveQuests() or {}) do
        if quest.isComplete and not quest.repeatable and quest.questID then
            gossip.SelectActiveQuest(quest.questID)
            return
        end
    end

    for _, quest in ipairs(gossip.GetAvailableQuests() or {}) do
        if not quest.repeatable and quest.questID then
            gossip.SelectAvailableQuest(quest.questID)
            return
        end
    end
end

local function SelectGreetingQuest()
    if GetNumActiveQuests and GetActiveTitle and SelectActiveQuest then
        for index = 1, GetNumActiveQuests() do
            local _, complete = GetActiveTitle(index)
            local questID = GetActiveQuestID and GetActiveQuestID(index)
            if complete and questID and C_QuestLog and C_QuestLog.IsRepeatableQuest
                and not C_QuestLog.IsRepeatableQuest(questID) then
                SelectActiveQuest(index)
                return
            end
        end
    end

    if GetNumAvailableQuests and GetAvailableQuestInfo and SelectAvailableQuest then
        for index = 1, GetNumAvailableQuests() do
            local _, _, repeatable = GetAvailableQuestInfo(index)
            if not repeatable then
                SelectAvailableQuest(index)
                return
            end
        end
    end
end

local function RequiresMoney()
    return not GetQuestMoneyToGet or (GetQuestMoneyToGet() or 0) > 0
end

local function IsQuestModifierDown(modifier)
    if modifier == "SHIFT" then return IsShiftKeyDown() end
    if modifier == "ALT" then return IsAltKeyDown() end
    return IsControlKeyDown()
end

local interaction
local function ShouldAutomate()
    local db = module:GetDB()
    local modifierDown = not not IsQuestModifierDown(db.modifier)
    return modifierDown == db.requireModifier
end

local function TryAdvance(state)
    if interaction ~= state or state.phase ~= "QUEST_PROGRESS" or state.advanced
        or not module:IsEnabled() or InCombatLockdown() or not state.automate
        or GetQuestID() ~= state.questID then
        return
    end
    if IsQuestCompletable and IsQuestCompletable() and CompleteQuest and not RequiresMoney() then
        state.advanced = true
        CompleteQuest()
    end
end

local function OnQuestEvent(_, event)
    if event == "QUEST_FINISHED" then
        interaction = nil
        return
    end
    if InCombatLockdown() then
        interaction = nil
        return
    end
    if event == "QUEST_ITEM_UPDATE" then
        if interaction then TryAdvance(interaction) end
        return
    end

    if event == "GOSSIP_SHOW" or event == "QUEST_GREETING" then
        interaction = { automate = ShouldAutomate(), openedAt = GetTime() }
        if interaction.automate then
            if event == "GOSSIP_SHOW" then SelectGossipQuest() else SelectGreetingQuest() end
        end
        return
    end

    local questID = GetQuestID()
    local state = interaction
    -- Keep the key decision as the dialog advances; the server may respond
    -- after the player has already let go of the modifier.
    local fromGreeting = state and not state.phase and GetTime() - state.openedAt <= 2
    local sameTurnIn = state and event == "QUEST_COMPLETE" and state.questID == questID
        and (state.phase == "QUEST_PROGRESS" or state.phase == "QUEST_COMPLETE")
    if not fromGreeting and not sameTurnIn then
        state = { automate = ShouldAutomate() }
    end
    interaction = state
    state.phase = event
    state.questID = questID
    if not state.automate then return end

    if event == "QUEST_DETAIL" then
        if AcceptQuest and not (QuestGetAutoAccept and QuestGetAutoAccept()) then
            AcceptQuest()
        end
    elseif event == "QUEST_PROGRESS" then
        TryAdvance(state)
        if not state.advanced then
            -- Item requirements can finish updating after QUEST_PROGRESS.
            C_Timer.After(0, function() TryAdvance(state) end)
        end
    elseif event == "QUEST_COMPLETE" then
        if not GetNumQuestChoices or not GetQuestReward or RequiresMoney() then return end
        local choices = GetNumQuestChoices()
        if choices == 0 then
            GetQuestReward(0)
        elseif choices and choices > 0 and not state.rewardPrompted then
            state.rewardPrompted = true
            yTools:Print(L.AUTO_QUEST_CHOOSE_REWARD)
        end
    end
end

function module:OnDisable()
    interaction = nil
end

for _, event in ipairs({
    "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS",
    "QUEST_ITEM_UPDATE", "QUEST_COMPLETE", "QUEST_FINISHED",
}) do
    module:RegisterEvent(event, OnQuestEvent)
end

function module:CreateOptionsPanel(parentCategory)
    if self.settingsPanel or not parentCategory then return end
    local panel = CreateFrame("Frame")
    panel:Hide()
    panel:SetSize(700, 560)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 32, -24)
    title:SetText(L.AUTO_QUEST_TITLE)

    local details = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    details:SetPoint("TOPLEFT", 32, -64)
    details:SetWidth(600)
    details:SetJustifyH("LEFT")
    details:SetText(L.AUTO_QUEST_DESCRIPTION)

    local enabled = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    yTools.UI.Check(enabled)
    local enabledLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    enabledLabel:SetPoint("TOPRIGHT", -32, -22)
    enabledLabel:SetText(L.MODULE_OPTIONS_ENABLE)
    enabled:SetPoint("RIGHT", enabledLabel, "LEFT", -5, 0)

    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", details, "BOTTOMLEFT", 0, -26)
    label:SetText(L.AUTO_QUEST_MODIFIER)

    local dropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
    dropdown:SetWidth(220)
    yTools.UI.DropdownLayout(dropdown)

    local requireModifier = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    yTools.UI.Check(requireModifier)
    requireModifier:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -20)
    local requireLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    requireLabel:SetPoint("LEFT", requireModifier, "RIGHT", 5, 0)
    requireLabel:SetText(L.AUTO_QUEST_REQUIRE_MODIFIER)
    requireModifier:SetScript("OnClick", function(button)
        module:GetDB().requireModifier = not not button:GetChecked()
    end)

    local names = { SHIFT = SHIFT_KEY, CTRL = CTRL_KEY, ALT = ALT_KEY }
    local function Refresh()
        enabled:SetChecked(module:IsEnabled())
        requireModifier:SetChecked(module:GetDB().requireModifier)
        yTools.UI.DropdownLabel(dropdown, names[module:GetDB().modifier] or names.CTRL)
    end
    dropdown:SetupMenu(function(_, root)
        for _, key in ipairs({ "SHIFT", "CTRL", "ALT" }) do
            local modifier = key
            root:CreateRadio(names[modifier], function()
                return module:GetDB().modifier == modifier
            end, function()
                module:GetDB().modifier = modifier
                Refresh()
            end)
        end
    end)

    enabled:SetScript("OnClick", function(button)
        if button:GetChecked() then module:Enable() else module:Disable() end
        Refresh()
    end)
    panel.RefreshForm = Refresh
    panel:SetScript("OnShow", Refresh)
    self.settingsPanel = panel
    self.settingsCategory = Settings.RegisterCanvasLayoutSubcategory(parentCategory, panel, L.AUTO_QUEST_TITLE)
end
