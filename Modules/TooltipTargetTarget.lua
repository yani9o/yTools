local rawCreateFrame = CreateFrame
local function CreateFrame(kind,name,parent,template)
    local nativeScroll = template == "UIPanelScrollFrameTemplate"
    if nativeScroll then template = nil end
    local f = rawCreateFrame(kind,name,parent,template)
    if nativeScroll then yTools.UI.ScrollFrame(f,parent) end
    if kind == "CheckButton" then yTools.UI.Check(f) end
    return f
end
local L = _G.yTools.L
local module = _G.yTools:RegisterModule("TooltipTargetTarget", {
    title = L.TOOLTIP_TARGETTARGET,
    description = L.SHOWS_THE_HOVERED_UNIT_S_CURRENT_TARGET_IN_ITS_TOOLTIP,
    defaultEnabled = true,
    defaults = { showFullName = true },
})

local LABEL = L.TARGET
local NONE = L.NO_TARGET
local installed = false
local worker
local elapsedTime = 0
local tracked = setmetatable({}, {__mode = "k"})
local hooked = setmetatable({}, {__mode = "k"})

local function IsSecret(value)
    if issecretvalue and issecretvalue(value) then return true end
    return type(value) == "table" and issecrettable and issecrettable(value) or false
end

local function PublicUnit(value)
    return not IsSecret(value) and type(value) == "string" and value ~= ""
end

local function ResolveUnit(tooltip, data)
    local info = tooltip.GetProcessingTooltipInfo and tooltip:GetProcessingTooltipInfo()
        or tooltip.GetPrimaryTooltipInfo and tooltip:GetPrimaryTooltipInfo()
    if not IsSecret(info) and type(info) == "table" and not IsSecret(info.getterName)
        and info.getterName == "GetUnit" then
        local args = info.getterArgs
        if not IsSecret(args) and type(args) == "table" and PublicUnit(args[1]) then return args[1] end
    end

    -- Unit-frame tooltips must use the frame's unit, not a stale world mouseover.
    local owner = tooltip.GetOwner and tooltip:GetOwner()
    if not IsSecret(owner) and owner and not (owner.IsForbidden and owner:IsForbidden()) then
        if PublicUnit(owner.unit) then return owner.unit end
        if owner.GetAttribute then
            local unit = owner:GetAttribute("unit")
            if PublicUnit(unit) then return unit end
        end
    end
    if not IsSecret(data) and type(data) == "table" and not IsSecret(data.guid)
        and type(data.guid) == "string" and UnitTokenFromGUID then
        local unit = UnitTokenFromGUID(data.guid)
        if PublicUnit(unit) then return unit end
    end
    return "mouseover"
end

function module:GetTargetName(unit)
    local firstName = UnitName(unit)
    if IsSecret(firstName) then return firstName end
    local name, surname = (UnitNameUnmodified or UnitName)(unit)
    if IsSecret(name) or IsSecret(surname) then return firstName end
    if type(name) == "string" and type(surname) == "string" and surname ~= ""
        and RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled() then
        local separator = Constants and Constants.CharacterNameSeparatorConsts
            and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR or " "
        local ending = separator .. surname
        if self:GetDB().showFullName == false then
            return name:sub(-#ending) == ending and name:sub(1, -#ending - 1) or name
        end
        if name:sub(-#ending) ~= ending then name = name .. ending end
        return name
    end
    if self:GetDB().showFullName == false then return firstName end
    if GetUnitName then
        local ok, fullName = pcall(GetUnitName, unit, false)
        if ok and not IsSecret(fullName) and type(fullName) == "string" and fullName ~= "" then return fullName end
    end
    return firstName
end

local function IsUnitTooltip(tooltip)
    if tooltip.IsTooltipType then
        local ok, result = pcall(tooltip.IsTooltipType, tooltip, Enum.TooltipDataType.Unit)
        return ok and not IsSecret(result) and result == true
    end
    local info = tooltip.GetPrimaryTooltipInfo and tooltip:GetPrimaryTooltipInfo()
    return not IsSecret(info) and type(info) == "table" and info.getterName == "GetUnit"
end

local function UpdateTooltip(tooltip, state, layout)
    if tooltip.IsForbidden and tooltip:IsForbidden() then return end
    if layout and not IsUnitTooltip(tooltip) then tracked[tooltip] = nil; return end
    local name = tooltip:GetName()
    local count = tooltip:NumLines()
    if IsSecret(name) or type(name) ~= "string" or IsSecret(count) or type(count) ~= "number" then return end

    local row
    for index = 1, count do
        local left = _G[name .. "TextLeft" .. index]
        if left and not (left.IsForbidden and left:IsForbidden()) then
            local text = left:GetText()
            if not IsSecret(text) and text == LABEL then row = index; break end
        end
    end
    local added = not row
    if added then
        _G.yTools.UI.TooltipFooterGap(tooltip, "footer")
        tooltip:AddDoubleLine(LABEL, NONE, 1, 0.82, 0, 1, 1, 1)
        row = tooltip:NumLines()
    end
    local right = _G[name .. "TextRight" .. row]
    if not right or (right.IsForbidden and right:IsForbidden()) then return end

    local targetName = module:GetTargetName(state.unit .. "target")
    local secret = IsSecret(targetName)
    if not secret and (type(targetName) ~= "string" or targetName == "") then targetName = NONE end
    -- Comparing secret names would fail in combat; native SetText accepts them.
    if added or secret or IsSecret(state.lastName) or state.lastName ~= targetName then
        right:SetText(targetName)
        state.lastName = targetName
        if layout then tooltip:Show() end
    end
end

local function UpdateVisible()
    local visible = false
    for tooltip, state in pairs(tracked) do
        if not (tooltip.IsForbidden and tooltip:IsForbidden()) and tooltip:IsShown() and IsUnitTooltip(tooltip) then
            visible = true
            UpdateTooltip(tooltip, state, true)
        else
            tracked[tooltip] = nil
        end
    end
    if not visible and worker then worker:Hide() end
end

local function OnTooltip(tooltip, data)
    if not module:IsEnabled() or not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden()) then return end
    local state = {unit = ResolveUnit(tooltip, data)}
    tracked[tooltip] = state
    if not hooked[tooltip] and tooltip.HookScript then
        tooltip:HookScript("OnHide", function(self) tracked[self] = nil end)
        tooltip:HookScript("OnTooltipCleared", function(self) tracked[self] = nil end)
        hooked[tooltip] = true
    end
    -- The native processor performs the initial layout after this callback.
    UpdateTooltip(tooltip, state, false)
    if worker then worker:Show() end
end

function module:OnEnable()
    if not installed and TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit ~= nil then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnTooltip)
        installed = true
    end
    if not worker then
        worker = CreateFrame("Frame")
        worker:Hide()
        worker:SetScript("OnUpdate", function(_, elapsed)
            elapsedTime = elapsedTime + elapsed
            if elapsedTime < 0.1 then return end
            elapsedTime = 0
            if module:IsEnabled() then UpdateVisible() else worker:Hide() end
        end)
    end
    if GameTooltip and not GameTooltip:IsForbidden() and GameTooltip:IsShown()
        and GameTooltip.IsTooltipType and GameTooltip:IsTooltipType(Enum.TooltipDataType.Unit)
        and GameTooltip.RebuildFromTooltipInfo then
        GameTooltip:RebuildFromTooltipInfo()
    end
end

function module:OnDisable()
    if worker then worker:Hide() end
    for tooltip in pairs(tracked) do
        if not (tooltip.IsForbidden and tooltip:IsForbidden()) and tooltip:IsShown()
            and tooltip.RebuildFromTooltipInfo then tooltip:RebuildFromTooltipInfo() end
    end
    tracked = setmetatable({}, {__mode = "k"})
end

module:RegisterEvent("UNIT_TARGET", function()
    if module:IsEnabled() then UpdateVisible() end
end)

module:RegisterEvent("UPDATE_MOUSEOVER_UNIT", function()
    if module:IsEnabled() then UpdateVisible() end
end)

function module:CreateOptionsPanel(parentCategory)
    if self.settingsPanel or not parentCategory or not Settings
        or not Settings.RegisterCanvasLayoutSubcategory then return end
    local panel = CreateFrame("Frame")
    panel:SetSize(700, 560)
    local controls = CreateFrame("Frame", nil, panel)
    controls:SetAllPoints(panel)
    panel.controls = controls
    local function Label(text, x, y, font)
        local label = controls:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
        label:SetPoint("TOPLEFT", x, y)
        label:SetJustifyH("LEFT")
        label:SetText(text)
        return label
    end
    Label(L.TARGET_TARGET_OPTIONS, 32, -24, "GameFontNormalLarge"):SetParent(panel)
    local description = Label(L.TARGET_TARGET_DESCRIPTION, 32, -64)
    description:SetWidth(600)
    local enabled = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    enabled:SetPoint("TOPLEFT", 400, -18)
    panel.enable = enabled
    local enableLabel = enabled:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    enableLabel:SetPoint("LEFT", enabled, "RIGHT", 2, 0)
    enableLabel:SetText(L.MODULE_OPTIONS_ENABLE)
    enableLabel:ClearAllPoints(); enableLabel:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -32, -22)
    enabled:ClearAllPoints(); enabled:SetPoint("RIGHT", enableLabel, "LEFT", -5, 0)
    enabled:SetScript("OnClick", function(owner)
        if owner:GetChecked() then self:Enable() else self:Disable() end
        panel.RefreshForm()
    end)
    local fullName = CreateFrame("CheckButton", nil, controls, "InterfaceOptionsCheckButtonTemplate")
    fullName:SetPoint("TOPLEFT", 32, -110)
    local fullNameLabel = fullName:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fullNameLabel:SetPoint("LEFT", fullName, "RIGHT", 2, 0)
    fullNameLabel:SetText(L.SHOW_FULL_CHARACTER_NAME)
    fullName:SetScript("OnClick", function(owner)
        self:GetDB().showFullName = owner:GetChecked() == true
        UpdateVisible()
    end)
    local details = Label(L.FULL_CHARACTER_NAME_DESCRIPTION, 58, -146, "GameFontHighlightSmall")
    details:SetWidth(560)
    panel.RefreshForm = function()
        enabled:SetChecked(self:IsEnabled())
        controls:SetShown(self:IsEnabled())
        fullName:SetChecked(self:GetDB().showFullName ~= false)
        fullName:SetEnabled(self:IsEnabled())
    end
    panel:SetScript("OnShow", panel.RefreshForm)
    self.settingsPanel = panel
    self.settingsCategory = Settings.RegisterCanvasLayoutSubcategory(parentCategory, panel, L.TARGET_TARGET_OPTIONS)
    panel.RefreshForm()
end
