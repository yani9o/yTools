local yTools = _G.yTools
local L = yTools.L
local module = _G.yTools:RegisterModule("BagSlots", {
    title = L.BAG_SLOTS_MODULE,
    description = L.BAG_SLOTS_DESCRIPTION,
    defaultEnabled = true,
    defaults = { reverseSlots = false, separateAmmo = false },
})

local worker = CreateFrame("Frame")
local hooked = setmetatable({}, {__mode = "k"})
local baseHeights = setmetatable({}, {__mode = "k"})
local resizing
local pending, refreshing = false, false

local function Defer()
    pending = true
    worker:RegisterEvent("PLAYER_REGEN_ENABLED")
end



local function SetExtraHeight(frame, extra)
    local base = baseHeights[frame] or frame:GetHeight()
    if extra == 0 and not baseHeights[frame] then return end
    baseHeights[frame] = extra > 0 and base or nil
    resizing = frame
    frame:SetHeight(base + extra)
    resizing = nil
end

local function ArrangeLayout(frame)
    if not module:IsEnabled() then
        if baseHeights[frame] and not (InCombatLockdown() and frame:IsProtected()) then
            SetExtraHeight(frame, 0)
        end
        return
    end
    if not frame.EnumerateValidItems then return end
    if InCombatLockdown() and frame:IsProtected() then Defer(); return end
    local left, bottom = frame:GetLeft(), frame:GetBottom()
    if not left or not bottom then return end
    local frameScale = frame:GetEffectiveScale()
    local slots = {}
    -- Default bag frames and item buttons can be positioned in combat.
    -- Defer only when a frame is actually protected.
    -- Read the positions produced by WoW's own layout, including partial rows.
    -- Keep the original bag/slot IDs and all item-button scripts untouched.
    for _, button in frame:EnumerateValidItems() do
        if not button then return end
        if InCombatLockdown() and button:IsProtected() then Defer(); return end
        local x, y = button:GetCenter()
        if not x or not y then return end
        local ratio = button:GetEffectiveScale() / frameScale
        slots[#slots + 1] = {button = button, x = x * ratio - left, y = y * ratio - bottom}
    end
    if #slots == 0 then return end
    table.sort(slots, function(a, b)
        if math.abs(a.y - b.y) > .1 then return a.y > b.y end
        return a.x < b.x
    end)
    -- Reuse WoW's column and row spacing, but fill the grid from top-left.
    -- Reversing occupied positions alone leaves the short row at the top.
    local columns, rows = {}, {}
    local function AddCoordinate(values, value)
        for _, existing in ipairs(values) do
            if math.abs(existing - value) < .1 then return end
        end
        values[#values + 1] = value
    end
    for _, slot in ipairs(slots) do
        AddCoordinate(columns, slot.x)
        AddCoordinate(rows, slot.y)
    end
    table.sort(columns)
    table.sort(rows, function(a, b) return a > b end)
    local db = module:GetDB()
    local regular, ammo = {}, {}
    local ammoBags = {}
    local getFreeSlots = C_Container and C_Container.GetContainerNumFreeSlots or GetContainerNumFreeSlots
    for i = 1, #slots do
        local slot = slots[db.reverseSlots and (#slots - i + 1) or i]
        local bag = db.separateAmmo and getFreeSlots and slot.button.GetBagID and slot.button:GetBagID()
        if bag and bag > 0 and ammoBags[bag] == nil then
            local _, family = getFreeSlots(bag)
            ammoBags[bag] = family == 1 or family == 2 or family == 3
        end
        local group = ammoBags[bag] and ammo or regular
        group[#group + 1] = slot
    end

    local width = #columns
    local regularRows = math.ceil(#regular / width)
    local neededRows = regularRows + math.ceil(#ammo / width)
    local extra = 0
    if neededRows > #rows then
        local pitch = rows[2] and (rows[#rows - 1] - rows[#rows])
        if not pitch or pitch <= 0 then return end
        extra = (neededRows - #rows) * pitch
        for row = #rows + 1, neededRows do rows[row] = rows[row - 1] - pitch end
    end
    SetExtraHeight(frame, extra)

    -- Keep the native bag and slot IDs. Only change the buttons' positions.
    for _, slot in ipairs(slots) do slot.button:ClearAllPoints() end
    local function Place(group, rowOffset)
        for i, slot in ipairs(group) do
            local column = (i - 1) % width + 1
            local row = rowOffset + math.floor((i - 1) / width) + 1
            slot.button:SetPoint("CENTER", frame, "BOTTOMLEFT", columns[column], rows[row] + extra)
        end
    end
    Place(regular, 0)
    Place(ammo, regularRows)
end

local function Refresh()
    local frame = _G.ContainerFrameCombinedBags
    if not frame or not frame.UpdateItemLayout or refreshing then return end
    -- At login the frame can exist before its item buttons have been acquired.
    -- Let WoW create them; our layout/OnShow hooks handle the first real open.
    if not frame:IsShown() or not frame.EnumerateValidItems then return end
    if InCombatLockdown() and frame:IsProtected() then Defer(); return end
    local count = 0
    for _, button in frame:EnumerateValidItems() do
        if not button then return end
        if InCombatLockdown() and button:IsProtected() then Defer(); return end
        count = count + 1
    end
    if count == 0 then return end
    pending = false
    worker:UnregisterEvent("PLAYER_REGEN_ENABLED")
    refreshing = true
    -- Rebuild WoW's original layout first. The hook arranges it only if enabled;
    -- disabling this module therefore restores the original display immediately.
    local ok, err = pcall(frame.UpdateItemLayout, frame)
    refreshing = false
    if not ok then error(err) end
end

local function InstallHooks()
    local frame = _G.ContainerFrameCombinedBags
    if not frame or not frame.UpdateItemLayout or hooked[frame] then return false end
    hooked[frame] = true
    hooksecurefunc(frame, "SetHeight", function(self)
        if resizing ~= self then baseHeights[self] = nil end
    end)
    hooksecurefunc(frame, "UpdateItemLayout", ArrangeLayout)
    frame:HookScript("OnShow", Refresh)
    return true
end

function module:OnEnable()
    InstallHooks()
    Refresh()
    if self.settingsPanel then self.settingsPanel.RefreshForm() end
end

function module:OnDisable()
    Refresh()
    if self.settingsPanel then self.settingsPanel.RefreshForm() end
end

worker:RegisterEvent("ADDON_LOADED")
worker:SetScript("OnEvent", function(_, event)
    if event == "ADDON_LOADED" then
        if InstallHooks() and module:IsEnabled() then Refresh() end
    elseif pending then
        Refresh()
    end
end)

module:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    InstallHooks()
    Refresh()
end)

function module:CreateOptionsPanel(parentCategory)
    if self.settingsPanel or not parentCategory or not Settings
        or not Settings.RegisterCanvasLayoutSubcategory then return end
    local panel = CreateFrame("Frame")
    panel:Hide()
    panel:SetSize(700, 560)
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 32, -24); title:SetText(L.BAG_SLOTS_OPTIONS)
    local function Check(label, y)
        local button = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
        yTools.UI.Check(button)
        button:SetPoint("TOPLEFT", 32, y)
        local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", button, "RIGHT", 5, 0); text:SetText(label)
        button.optionLabel = text
        return button
    end
    local enabled = Check(L.ENABLE_BAG_SLOTS, -18)
    local enabledLabel = enabled.optionLabel
    enabledLabel:SetFontObject(GameFontHighlight)
    enabledLabel:SetText(L.MODULE_OPTIONS_ENABLE)
    enabledLabel:ClearAllPoints(); enabledLabel:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -32, -22)
    enabled:ClearAllPoints(); enabled:SetPoint("RIGHT", enabledLabel, "LEFT", -5, 0)
    local reverse = Check(L.REVERSE_BAG_SLOTS, -150)
    local ammo = Check(L.BAG_SLOTS_SEPARATE_AMMO, -184)
    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    description:SetPoint("TOPLEFT", 32, -64); description:SetWidth(590)
    description:SetJustifyH("LEFT"); description:SetText(L.BAG_SLOTS_DESCRIPTION)
    local function Update()
        enabled:SetChecked(self:IsEnabled())
        reverse:SetChecked(self:GetDB().reverseSlots == true)
        reverse:SetEnabled(self:IsEnabled())
        ammo:SetChecked(self:GetDB().separateAmmo == true)
        ammo:SetEnabled(self:IsEnabled())
    end
    enabled:SetScript("OnClick", function(button)
        if button:GetChecked() then self:Enable() else self:Disable() end
        Update()
    end)
    reverse:SetScript("OnClick", function(button)
        self:GetDB().reverseSlots = button:GetChecked() == true
        Refresh()
    end)
    ammo:SetScript("OnClick", function(button)
        self:GetDB().separateAmmo = button:GetChecked() == true
        Refresh()
    end)
    panel:SetScript("OnShow", Update)
    panel.RefreshForm = Update
    self.settingsPanel = panel
    self.settingsCategory = Settings.RegisterCanvasLayoutSubcategory(parentCategory, panel, L.BAG_SLOTS_OPTIONS)
    Update()
end

module:RegisterSlashCommand("bagslots", function()
    yTools:InitializeOptions()
    module:CreateOptionsPanel(yTools.optionsCategory)
    local category = module.settingsCategory
    if category and Settings and Settings.OpenToCategory then
        yTools:OpenSettingsCategory(category.GetID and category:GetID() or category.ID)
    end
end, L.BAG_SLOTS_COMMAND_HELP)
yTools.commands.bagslots.allowDisabled = true
