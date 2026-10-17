local yTools = _G.yTools
local L = yTools.L
local module = yTools:RegisterModule("Tooltip_QuestID", {
    title = L.TOOLTIP_QUEST_IDS,
    description = L.TOOLTIP_QUEST_IDS_DESCRIPTION,
    defaultEnabled = true,
})

local hooked = setmetatable({}, { __mode = "k" })
local globalHooks = {}
local processorInstalled, mapInstalled = false, false
local detailsLabel, detailsOwner, detailsButton
local npcButton, npcLabel
local npcPanels = setmetatable({}, { __mode = "k" })

local function IsSecret(value)
    return (issecretvalue and issecretvalue(value))
        or (type(value) == "table" and issecrettable and issecrettable(value)) or false
end

local function ShowQuestLink(id)
    if not module:IsEnabled() then return end
    if IsSecret(id) or type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then return end
    local copyLinks = yTools:GetModule("CopyLinks")
    if not copyLinks or not copyLinks.ShowLink then return end
    local locale = GetLocale() == "deDE" and "de" or "en"
    copyLinks:ShowLink(("https://www.wowhead.com/forever/%s/quest=%d"):format(locale, id))
end

local function AddID(tooltip, id)
    if not module:IsEnabled() or not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden())
        or IsSecret(id) or type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then return end
    local name, count = tooltip:GetName(), tooltip:NumLines()
    if IsSecret(name) or IsSecret(count) or type(name) ~= "string" or type(count) ~= "number" then return end
    for index = 1, count do
        local line = _G[name .. "TextLeft" .. index]
        if line and not (line.IsForbidden and line:IsForbidden()) then
            local text = line:GetText()
            if not IsSecret(text) and text == L.QUEST_ID then return end
        end
    end
    yTools.UI.TooltipFooterGap(tooltip, "ids")
    tooltip:AddDoubleLine(L.QUEST_ID, tostring(id), 1, .82, 0, 1, 1, 1)
    return true
end

local function OnQuestTooltip(tooltip, data)
    if not IsSecret(data) and type(data) == "table" then AddID(tooltip, data.id) end
end

local function OnHyperlink(tooltip, link)
    if IsSecret(link) or type(link) ~= "string" then return end
    local id = link:match("^quest:(%d+)") or link:match("|Hquest:(%d+)")
    if id and AddID(tooltip, tonumber(id)) then tooltip:Show() end
end

local function OnQuestEntry(button)
    if not module:IsEnabled() or not button or (button.IsForbidden and button:IsForbidden()) then return end
    local info = button.info
    local id
    if not IsSecret(info) and type(info) == "table" then id = info.questID end
    if IsSecret(id) then return end
    if id == nil then id = button.questID end
    if IsSecret(id) then return end
    if id == nil then
        local index = button.questLogIndex
        if not IsSecret(index) and type(index) == "number" and C_QuestLog and C_QuestLog.GetQuestIDForLogIndex then
            id = C_QuestLog.GetQuestIDForLogIndex(index)
        end
    end
    if GameTooltip and GameTooltip:IsShown() and AddID(GameTooltip, id) then GameTooltip:Show() end
end

local function UpdateDetailsHeader()
    if not detailsLabel then return end
    local id = detailsOwner.questID
    if module:IsEnabled() and detailsOwner:IsShown() and not IsSecret(id)
        and type(id) == "number" and id > 0 and id == math.floor(id) then
        detailsLabel:SetFormattedText("%s %d", L.QUEST_ID, id)
        detailsLabel:Show()
        detailsButton:Show()
    else
        detailsLabel:Hide()
        detailsButton:Hide()
    end
end

local function InstallDetailsHeader()
    local details = QuestMapFrame and QuestMapFrame.DetailsFrame
    if not detailsLabel and details and not (details.IsForbidden and details:IsForbidden()) then
        local header = details.BackFrame or details
        local back = header.BackButton or details.BackButton
        if not back then return end
        detailsOwner = details
        detailsLabel = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        detailsLabel:SetPoint("LEFT", back, "RIGHT", 10, 0)
        detailsLabel:SetPoint("RIGHT", header, "RIGHT", -12, 0)
        detailsLabel:SetJustifyH("RIGHT")
        detailsLabel:Hide()
        detailsButton = CreateFrame("Button", nil, header)
        detailsButton:SetPoint("TOPLEFT", detailsLabel, "TOPLEFT", 0, 3)
        detailsButton:SetPoint("BOTTOMRIGHT", detailsLabel, "BOTTOMRIGHT", 0, -3)
        detailsButton:RegisterForClicks("LeftButtonUp")
        detailsButton:SetScript("OnClick", function() ShowQuestLink(detailsOwner.questID) end)
        detailsButton:SetScript("OnEnter", function() detailsLabel:SetTextColor(1, .82, 0) end)
        detailsButton:SetScript("OnLeave", function() detailsLabel:SetTextColor(1, 1, 1) end)
        detailsButton:Hide()
        details:HookScript("OnShow", UpdateDetailsHeader)
        details:HookScript("OnHide", function() detailsLabel:Hide(); detailsButton:Hide() end)
    end
    if hooksecurefunc and not globalHooks.QuestMapFrame_ShowQuestDetails
        and type(QuestMapFrame_ShowQuestDetails) == "function" then
        hooksecurefunc("QuestMapFrame_ShowQuestDetails", UpdateDetailsHeader)
        globalHooks.QuestMapFrame_ShowQuestDetails = true
    end
    UpdateDetailsHeader()
end

local function NPCQuestID()
    if not QuestFrame or not QuestFrame:IsShown() or not GetQuestID then return end
    local showingQuest = false
    for _, name in ipairs({ "QuestFrameDetailPanel", "QuestFrameProgressPanel", "QuestFrameRewardPanel" }) do
        local panel = _G[name]
        if panel and panel:IsShown() then showingQuest = true; break end
    end
    if not showingQuest then return end
    local ok, id = pcall(GetQuestID)
    if ok and not IsSecret(id) and type(id) == "number" and id > 0 and id == math.floor(id) then return id end
end

local function UpdateNPCHeader()
    if not npcButton then return end
    local id = module:IsEnabled() and NPCQuestID()
    if id then
        npcLabel:SetFormattedText("%s %d", L.QUEST_ID, id)
        npcButton:Show()
    else
        npcButton:Hide()
    end
end

local function ScheduleNPCHeader()
    UpdateNPCHeader()
    -- Quest events can run before Blizzard switches the visible detail panel.
    if C_Timer and C_Timer.After then C_Timer.After(0, UpdateNPCHeader) end
end

local function InstallNPCHeader()
    if not npcButton and QuestFrame and not (QuestFrame.IsForbidden and QuestFrame:IsForbidden()) then
        npcButton = CreateFrame("Button", nil, QuestFrame)
        npcButton:Hide()
        npcButton:SetSize(180, 20)
        npcButton:SetPoint("TOPRIGHT", QuestFrame, "TOPRIGHT", -20, -36)
        npcLabel = npcButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        npcLabel:SetAllPoints()
        npcLabel:SetJustifyH("RIGHT")
        npcButton:RegisterForClicks("LeftButtonUp")
        npcButton:SetScript("OnClick", function() ShowQuestLink(NPCQuestID()) end)
        npcButton:SetScript("OnEnter", function() npcLabel:SetTextColor(1, .82, 0) end)
        npcButton:SetScript("OnLeave", function() npcLabel:SetTextColor(1, 1, 1) end)
        QuestFrame:HookScript("OnShow", ScheduleNPCHeader)
        QuestFrame:HookScript("OnHide", function() npcButton:Hide() end)
    end
    for _, name in ipairs({ "QuestFrameDetailPanel", "QuestFrameProgressPanel", "QuestFrameRewardPanel" }) do
        local panel = _G[name]
        if panel and not npcPanels[panel] and not (panel.IsForbidden and panel:IsForbidden()) then
            panel:HookScript("OnShow", ScheduleNPCHeader)
            panel:HookScript("OnHide", ScheduleNPCHeader)
            npcPanels[panel] = true
        end
    end
    UpdateNPCHeader()
end

local function InstallHooks()
    InstallDetailsHeader()
    InstallNPCHeader()
    if not processorInstalled and TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Quest ~= nil then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Quest, OnQuestTooltip)
        processorInstalled = true
    end
    if hooksecurefunc then
        for _, name in ipairs({ "GameTooltip", "ItemRefTooltip" }) do
            local tooltip = _G[name]
            if tooltip and not hooked[tooltip] and tooltip.SetHyperlink
                and not (tooltip.IsForbidden and tooltip:IsForbidden()) then
                hooksecurefunc(tooltip, "SetHyperlink", OnHyperlink)
                hooked[tooltip] = true
            end
        end
        -- Quest-log entries build plain text tooltips, outside the data processor.
        for _, name in ipairs({ "QuestMapLogTitleButton_OnEnter", "QuestLogTitleButton_OnEnter" }) do
            if not globalHooks[name] and type(_G[name]) == "function" then
                hooksecurefunc(name, OnQuestEntry)
                globalHooks[name] = true
            end
        end
    end
    if not mapInstalled and EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("MapCanvas.QuestPin.OnEnter", function(_, pin, id)
            if GameTooltip and GameTooltip:IsShown() and AddID(GameTooltip, id) then GameTooltip:Show() end
        end, module)
        mapInstalled = true
    end
end

function module:OnEnable() InstallHooks() end
function module:OnDisable()
    if detailsLabel then detailsLabel:Hide() end
    if detailsButton then detailsButton:Hide() end
    if npcButton then npcButton:Hide() end
end
module:RegisterEvent("ADDON_LOADED", function()
    if module:IsEnabled() then InstallHooks() end
end)
for _, event in ipairs({ "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_FINISHED", "QUEST_GREETING", "GOSSIP_SHOW" }) do
    module:RegisterEvent(event, function()
        if module:IsEnabled() then InstallNPCHeader(); ScheduleNPCHeader() end
    end)
end
