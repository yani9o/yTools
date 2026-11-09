local yTools = _G.yTools
local L = yTools.L
local module = yTools:RegisterModule("LearnAll", {
    title = L.LEARN_ALL_MODULE,
    description = L.LEARN_ALL_DESCRIPTION,
    defaultEnabled = true,
})

local button, running, pending, timer, queued, trainerGUID
local Refresh, Advance
local function Public(value)
    return not issecretvalue or not issecretvalue(value)
end
local function IsPetTrainer()
    if not C_Trainer or not C_Trainer.GetTrainerType or not Enum or not Enum.TrainerType then return false end
    local trainerType = C_Trainer.GetTrainerType()
    return Public(trainerType) and trainerType == Enum.TrainerType.Pet
end
local function Currency()
    if IsPetTrainer() then
        if not C_PetInfo or not C_PetInfo.GetPetTrainingPoints then return 0 end
        local total, used = C_PetInfo.GetPetTrainingPoints()
        if Public(total) and Public(used) and type(total) == "number" and type(used) == "number" then
            return total - used
        end
        return 0
    end
    local money = GetMoney()
    return Public(money) and type(money) == "number" and money or 0
end
local function ServiceKey(index, name, rank)
    return name .. "\031" .. (type(rank) == "string" and rank or "")
end
local function Services()
    local list, total = {}, 0
    if not GetNumTrainerServices or not GetTrainerServiceInfo or not GetTrainerServiceCost then return list, total end
    local count = GetNumTrainerServices()
    if not Public(count) or type(count) ~= "number" then return list, total end
    for index = 1, count do
        local name, state, _, _, rank = GetTrainerServiceInfo(index)
        if Public(name) and Public(state) and Public(rank) and type(name) == "string" and state == "available" then
            local cost, profession = GetTrainerServiceCost(index)
            local canLearn = Public(profession)
            if canLearn and profession and GetProfessions then
                local _, second = GetProfessions()
                canLearn = Public(second) and second == nil
            end
            if canLearn and Public(cost) and type(cost) == "number" and cost >= 0 then
                list[#list + 1] = {index = index, key = ServiceKey(index, name, rank), cost = cost, profession = profession}
                total = total + cost
            end
        end
    end
    return list, total
end
local function Visible()
    return module:IsEnabled() and ClassTrainerFrame and ClassTrainerFrame:IsShown() and not IsPetTrainer()
end
local function Stop()
    running, pending, trainerGUID = nil, nil, nil
    if timer then timer:Cancel(); timer = nil end
end
local function Wake()
    if not running or timer then return end
    timer = C_Timer.NewTimer(0.1, function() timer = nil; Advance() end)
end
Advance = function()
    if not running then return end
    if not Visible() or InCombatLockdown() then Stop(); Refresh(); return end
    local guid = UnitGUID("npc")
    if not Public(guid) or guid ~= trainerGUID then Stop(); Refresh(); return end
    local services = Services()
    if pending then
        for _, service in ipairs(services) do
            if service.key == pending.key then
                if GetTime() - pending.at < 4 then Wake(); return end
                -- A rejected/stalled purchase must not be sent repeatedly.
                Stop(); Refresh(); return
            end
        end
        pending = nil
    end
    local service = services[1]
    if not service or service.cost > Currency() then Stop(); Refresh(); return end
    if service.profession then
        -- Preserve Blizzard's confirmation when acquiring a primary profession.
        Stop()
        if ClassTrainer_SetSelection and ClassTrainerTrainButton_OnClick then
            local map = ClassTrainerFrame.skillIndexToDisplayIndex
            ClassTrainer_SetSelection(map and map[service.index] or service.index)
            ClassTrainerTrainButton_OnClick(ClassTrainerTrainButton)
        end
        Refresh(); return
    end
    pending = {key = service.key, at = GetTime()}
    BuyTrainerService(service.index)
    Wake()
end
local function Start()
    if running or not Visible() or InCombatLockdown() then return end
    local services, total = Services()
    if #services == 0 or total > Currency() then return end
    local guid = UnitGUID("npc")
    if not Public(guid) or type(guid) ~= "string" then return end
    trainerGUID, running = guid, true
    Refresh()
    Advance()
end
local function CostText(total)
    if IsPetTrainer() then return string.format(L.LEARN_ALL_POINTS, total) end
    return GetMoneyString(total)
end
local function ShowCost()
    if not button or not button:IsShown() then return end
    local services, total = Services()
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:SetText(L.LEARN_ALL_TOOLTIP_TITLE)
    GameTooltip:AddDoubleLine(string.format(L.LEARN_ALL_COUNT, #services), CostText(total), 1, 1, 1, 1, 1, 1)
    GameTooltip:Show()
end
Refresh = function()
    if not Visible() then
        Stop()
        if button then
            if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
            button:Hide()
        end
        return
    end
    local train = ClassTrainerTrainButton or ClassTrainerFrame.TrainButton
    if not train then return end
    if not button then
        button = CreateFrame("Button", "yToolsLearnAllButton", ClassTrainerFrame, "MagicButtonTemplate")
        button:SetSize(70, 22)
        button:SetPoint("RIGHT", train, "LEFT", -6, 0)
        button:SetScript("OnClick", Start)
        button:SetScript("OnEnter", ShowCost)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        button:SetMotionScriptsWhileDisabled(true)
    end
    local services, total = Services()
    button:SetText(running and L.LEARN_ALL_WORKING or L.LEARN_ALL_BUTTON)
    button:SetEnabled(not running and not InCombatLockdown() and #services > 0 and total <= Currency())
    button:Show()
    if GameTooltip:IsOwned(button) then ShowCost() end
end
local function Schedule()
    if queued then return end
    queued = true
    C_Timer.After(0, function() queued = nil; Refresh(); if running then Wake() end end)
end
function module:OnEnable() Schedule() end
function module:OnDisable() Stop(); if button then button:Hide() end end
for _, event in ipairs({"TRAINER_SHOW", "TRAINER_UPDATE", "TRAINER_SERVICE_INFO_NAME_UPDATE", "PLAYER_MONEY", "UNIT_PET_TRAINING_POINTS", "PLAYER_REGEN_ENABLED"}) do
    module:RegisterEvent(event, Schedule)
end
module:RegisterEvent("TRAINER_CLOSED", function() Stop(); if button then button:Hide() end end)
module:RegisterEvent("PLAYER_REGEN_DISABLED", function() Stop(); Refresh() end)
module:RegisterSlashCommand("learnall", Start, L.LEARN_ALL_COMMAND)
