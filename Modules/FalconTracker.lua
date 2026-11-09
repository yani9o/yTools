local yTools = _G.yTools
local L = yTools.L
local module = yTools:RegisterModule("FalconTracker", {
    title = L.FALCON_TRACKER_MODULE,
    description = L.FALCON_TRACKER_DESCRIPTION,
    defaultEnabled = false,
    defaults = {hideBlizzardSummons = false, scale = 1, zoomIcons = false},
})

local FALCON = 1293241
local ARCANE_SHOT = 3044
local shotRank = ARCANE_SHOT
local ranks = {[FALCON] = true, [1293525] = true, [1293526] = true, [1293527] = true}
local frame, anchor, dragging
local slots = {}
local shotIconColors, shotRimColors
local pendingCast, summonTimers = nil, {}
local summonSpells = {[1293248] = true, [1312637] = true, [1312639] = true}
local hiddenRow, originalAlpha

local function Public(value)
    return not issecretvalue or not issecretvalue(value)
end

local function Hunter()
    local _, class = UnitClass("player")
    return Public(class) and class == "HUNTER"
end

local function Knows(spell)
    local known = C_SpellBook and C_SpellBook.IsSpellKnown or IsSpellKnown or IsPlayerSpell
    if not known then return false end
    local learned = known(spell)
    return Public(learned) and learned
end

local function CanTrack()
    if not Hunter() then return false end
    for spell in pairs(ranks) do
        if Knows(spell) then return true end
    end
    return false
end

local function PaintTime(timer, remaining)
    local low = remaining > 0 and remaining < 3
    timer:SetText(remaining <= 0 and "" or low and string.format("%.1f", math.max(.1, remaining))
        or tostring(math.ceil(remaining)))
    timer:SetTextColor(1, low and .25 or 1, low and .2 or 1)
end

local function BindTimer(timer)
    if not (C_DurationUtil and C_DurationUtil.CreateDurationTextBinding and C_StringUtil
        and C_StringUtil.CreateNumericRuleFormatter and C_CurveUtil and C_CurveUtil.CreateColorCurve
        and CreateColor and Enum and Enum.NumericRuleFormatRounding and Enum.LuaCurveType
        and Enum.DurationTextBindingProperty) then return end
    local formatter = C_StringUtil.CreateNumericRuleFormatter()
    formatter:SetBreakpoints({
        {threshold = 0, format = ""},
        {threshold = .000001, format = "%.1f"},
        {threshold = 3, format = "%d", step = 1, rounding = Enum.NumericRuleFormatRounding.Up},
    })
    local colors = C_CurveUtil.CreateColorCurve()
    colors:SetType(Enum.LuaCurveType.Step)
    colors:AddPoint(0, CreateColor(1, .25, .2, 1))
    colors:AddPoint(3, CreateColor(1, 1, 1, 1))
    local binding = C_DurationUtil.CreateDurationTextBinding()
    binding:SetFontString(timer)
    binding:SetFormatter(formatter)
    binding:SetTextColorCurve(colors, Enum.DurationTextBindingProperty.RemainingDuration)
    binding:SetUpdateInterval(0)
    binding:SetExpiredText("")
    binding:SetZeroDurationText("")
    binding:SetEnabled(false)
    return binding
end

local function UpdateShotCooldown()
    local shot = slots.shot
    local cooldown = slots.shot and slots.shot.cooldown
    if not cooldown or not C_Spell then return end
    shot.durationObject, shot.cooldownEnd = nil, nil
    if shot.binding then shot.binding:SetEnabled(false) end
    PaintTime(shot.timer, 0)
    if C_Spell.GetSpellCooldownDuration and cooldown.SetCooldownFromDurationObject then
        local object = C_Spell.GetSpellCooldownDuration(shotRank, true)
        if object then
            cooldown:SetCooldownFromDurationObject(object)
            -- A ready update can arrive while the old cooldown is still flashing.
            local remaining = object.GetRemainingDuration and object:GetRemainingDuration()
            if not Public(remaining) or type(remaining) ~= "number" or remaining > 0 then
                shot.flash:SetCooldownFromDurationObject(object)
            end
            if shot.binding then
                shot.binding:SetDuration(object)
                shot.binding:SetEnabled(true)
            else
                shot.durationObject = object
            end
            return
        end
    elseif C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(shotRank)
        if info and Public(info.startTime) and Public(info.duration) and Public(info.isOnGCD)
            and not info.isOnGCD and type(info.startTime) == "number" and type(info.duration) == "number" then
            cooldown:SetCooldown(info.startTime, info.duration)
            if info.startTime + info.duration > GetTime() then
                shot.flash:SetCooldown(info.startTime, info.duration)
            end
            shot.cooldownEnd = info.startTime + info.duration
            return
        end
    end
    cooldown:Clear()
end

local function MoveKeys()
    return IsControlKeyDown() and IsAltKeyDown() and IsShiftKeyDown()
end

local function RestoreBlizzardRow()
    if not hiddenRow then return end
    local ok, alpha = pcall(hiddenRow.GetAlpha, hiddenRow)
    if ok and Public(alpha) and alpha == 0 then
        pcall(hiddenRow.SetAlpha, hiddenRow, originalAlpha)
    end
    hiddenRow, originalAlpha = nil, nil
end

local function UpdateBlizzardRow()
    local row = module:GetDB().hideBlizzardSummons and _G.TotemFrame
    if hiddenRow and hiddenRow ~= row then RestoreBlizzardRow() end
    if not row then return end
    local ok, alpha = pcall(row.GetAlpha, row)
    if ok and Public(alpha) and type(alpha) == "number" and alpha > 0 then
        if pcall(row.SetAlpha, row, 0) then
            hiddenRow, originalAlpha = row, alpha
        end
    end
end

local function Place()
    if dragging then return end
    local position = module:GetDB().position
    if anchor == UIParent then return end
    anchor = UIParent
    frame:ClearAllPoints()
    if position and (position[1] ~= "CENTER" or position[2] ~= "CENTER") then
        frame:SetPoint(position[1], UIParent, position[2], position[3], position[4])
    else
        local ratio = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
        local x, y = 0, -140
        if position then x, y = position[3], position[4] end
        frame:SetPoint("CENTER", UIParent, "CENTER", x * ratio, y * ratio)
    end
end

local function FrameCenterPosition()
    local x, y = frame:GetCenter()
    local px, py = UIParent:GetCenter()
    if x and y and px and py then
        local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
        return x * ratio - px, y * ratio - py
    end
end

local function CenterPosition()
    local position = module:GetDB().position
    if not position then return 0, -140 end
    if position[1] == "CENTER" and position[2] == "CENTER" then return position[3], position[4] end
    if frame then
        Place()
        local x, y = FrameCenterPosition()
        if x then return x, y end
    end
    return 0, -140
end

local function Update(now)
    for index, native in pairs(summonTimers) do
        local remaining = native.object:GetRemainingDuration()
        if Public(remaining) and type(remaining) == "number" and remaining <= 0 then
            summonTimers[index] = nil
        end
    end
    local first, second = summonTimers[1], summonTimers[2]
    if not first or (second and second.started < first.started) then
        first, second = second, first
    end
    local attackable = UnitCanAttack("player", "target")
    local inCombat = UnitAffectingCombat("player")
    if not first and not second and not (Public(inCombat) and inCombat)
        and not (Public(attackable) and attackable) and not MoveKeys() then
        if not dragging then frame:Hide() end
        return
    end
    Place()
    local wasShown = frame:IsShown()
    frame:Show()
    if not wasShown then UpdateShotCooldown() end
    local shot = slots.shot
    if not shot.binding or shot.cooldownEnd then
        local object = shot.durationObject
        local remaining = object and object.GetRemainingDuration and object:GetRemainingDuration()
        local readable = Public(remaining) and type(remaining) == "number"
        shot.cooldown:SetHideCountdownNumbers(readable or shot.cooldownEnd ~= nil)
        PaintTime(shot.timer, readable and remaining or (shot.cooldownEnd or now) - now)
    end
    frame:EnableMouse(not not (dragging or MoveKeys()))
    for index = 1, 2 do
        local slot = slots[index]
        local native = index == 1 and first or second
        slot.icon:SetDesaturated(not native)
        slot:SetAlpha(native and 1 or .3)
        if slot.nativeTimer ~= native then
            slot.nativeTimer = native
            if slot.binding then slot.binding:SetEnabled(false) end
            PaintTime(slot.timer, 0)
            if native then
                slot.binding:SetDuration(native.object)
                slot.binding:SetEnabled(true)
                slot.cooldown:SetCooldownFromDurationObject(native.object)
                slot.flash:SetCooldownFromDurationObject(native.object)
            else
                slot.cooldown:Clear()
            end
        end
    end
    local both = first and second
    shot.icon:SetDesaturated(not both)
    shot.rim:SetDesaturated(not both)
    if both and shotIconColors and first.object.EvaluateRemainingDuration then
        shot.icon:SetVertexColor(first.object:EvaluateRemainingDuration(shotIconColors):GetRGBA())
        shot.rim:SetVertexColor(first.object:EvaluateRemainingDuration(shotRimColors):GetRGBA())
    elseif both then
        local remaining = first.object:GetRemainingDuration()
        local readable = Public(remaining) and type(remaining) == "number"
        if readable and remaining < 6 then
            shot.icon:SetVertexColor(1, .28, .23)
            shot.rim:SetVertexColor(1, .18, .12)
        elseif readable and remaining <= 7.5 then
            shot.icon:SetVertexColor(1, .93, .30)
            shot.rim:SetVertexColor(1, .78, .18)
        else
            shot.icon:SetVertexColor(1, 1, 1)
            shot.rim:SetVertexColor(1, 1, 1)
        end
    else
        shot.icon:SetVertexColor(1, 1, 1)
        shot.rim:SetVertexColor(1, 1, 1)
    end
end

local function ApplyIconStyle()
    local zoom = not not module:GetDB().zoomIcons
    for _, slot in pairs(slots) do
        local lo, hi = zoom and .08 or 0, zoom and .92 or 1
        slot.icon:SetTexCoord(lo, hi, lo, hi)
        if slot.mask and slot.maskApplied == zoom then
            if zoom then slot.icon:RemoveMaskTexture(slot.mask) else slot.icon:AddMaskTexture(slot.mask) end
            slot.maskApplied = not zoom
        end
        slot.rim:SetShown(not zoom)
        local pixel = PixelUtil and PixelUtil.GetPixelToUIUnitFactor
            and PixelUtil.GetPixelToUIUnitFactor() / slot:GetEffectiveScale() or 1
        for i, edge in ipairs(slot.squareEdges) do
            if i <= 2 then edge:SetHeight(pixel) else edge:SetWidth(pixel) end
            edge:SetShown(not not zoom)
        end
        local inset = zoom and 0 or 3 * slot.size / 45
        slot.cooldown:ClearAllPoints()
        slot.cooldown:SetPoint("TOPLEFT", slot.icon, "TOPLEFT", inset, -inset)
        slot.cooldown:SetPoint("BOTTOMRIGHT", slot.icon, "BOTTOMRIGHT", -inset, inset)
    end
end

local function Create()
    if frame then return end
    if C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor and Enum and Enum.LuaCurveType then
        local function ShotColors(redGreen, redBlue, yellowGreen, yellowBlue)
            local curve = C_CurveUtil.CreateColorCurve()
            curve:SetType(Enum.LuaCurveType.Step)
            curve:AddPoint(0, CreateColor(1, redGreen, redBlue, 1))
            curve:AddPoint(6, CreateColor(1, yellowGreen, yellowBlue, 1))
            curve:AddPoint(7.500001, CreateColor(1, 1, 1, 1))
            return curve
        end
        shotIconColors = ShotColors(.28, .23, .93, .30)
        shotRimColors = ShotColors(.18, .12, .78, .18)
    end
    frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    local shotSize, falconSize, spacing = 45, 33, 45
    frame:SetSize(2 * spacing + falconSize, shotSize)
    frame:SetScale(module:GetDB().scale or 1)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        if MoveKeys() then
            dragging = true
            frame:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function()
        if not dragging then return end
        frame:StopMovingOrSizing()
        dragging = nil
        local x, y = FrameCenterPosition()
        if x then module:GetDB().position = {"CENTER", "CENTER", x, y} end
        anchor = nil
        Update(GetTime())
        if module.settingsPanel then module.settingsPanel.RefreshForm() end
    end)
    local function Icon(size, x, spell, fallback, timer)
        local slot = CreateFrame("Frame", nil, frame)
        slot.size = size
        slot:SetSize(size, size)
        slot:SetPoint("CENTER", frame, "CENTER", x, 0)
        slot.icon = slot:CreateTexture(nil, "ARTWORK")
        slot.icon:SetAllPoints()
        local texture = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spell)
        slot.icon:SetTexture(Public(texture) and texture or fallback)
        -- Match yAuras' default, unzoomed spell icon style.
        if slot.CreateMaskTexture and slot.icon.AddMaskTexture then
            local mask = slot:CreateMaskTexture(nil, "ARTWORK")
            if mask.SetAtlas and pcall(mask.SetAtlas, mask, "UI-HUD-ActionBar-IconFrame-Mask", true) then
                local factor = size / 45
                mask:SetSize(mask:GetWidth() * factor, mask:GetHeight() * factor)
                mask:SetPoint("CENTER", slot.icon)
                slot.icon:AddMaskTexture(mask)
                slot.mask, slot.maskApplied = mask, true
            end
        end
        slot.rim = slot:CreateTexture(nil, "OVERLAY")
        if not (slot.rim.SetAtlas and pcall(slot.rim.SetAtlas, slot.rim, "UI-HUD-ActionBar-IconFrame", false)) then
            slot.rim:SetTexture("Interface\\Buttons\\UI-Quickslot2")
            slot.rim:SetTexCoord(.2, .8, .2, .8)
        end
        slot.rim:SetPoint("TOPLEFT", slot.icon)
        slot.rim:SetSize(size * 46 / 45, size)
        slot.squareEdges = {}
        local corners = {{"TOPLEFT","TOPRIGHT"},{"BOTTOMLEFT","BOTTOMRIGHT"},
            {"TOPLEFT","BOTTOMLEFT"},{"TOPRIGHT","BOTTOMRIGHT"}}
        for i, points in ipairs(corners) do
            local edge = slot:CreateTexture(nil, "OVERLAY", nil, 7)
            edge:SetColorTexture(0, 0, 0, 1)
            edge:SetPoint(points[1], slot.icon, points[1])
            edge:SetPoint(points[2], slot.icon, points[2])
            slot.squareEdges[i] = edge
        end
        for _, region in ipairs({slot.icon, slot.rim}) do
            if region.SetSnapToPixelGrid then region:SetSnapToPixelGrid(true) end
            if region.SetTexelSnappingBias then region:SetTexelSnappingBias(0) end
        end
        local cooldown = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
        cooldown:SetDrawSwipe(true)
        cooldown:SetSwipeColor(0, 0, 0, .65)
        cooldown:SetDrawEdge(false)
        cooldown:SetDrawBling(false)
        cooldown:SetUseCircularEdge(false)
        cooldown:SetReverse(timer)
        cooldown:SetHideCountdownNumbers(timer)
        cooldown:EnableMouse(false)
        slot.cooldown = cooldown
        slot.timer = cooldown:CreateFontString(nil, "OVERLAY", nil, 7)
        slot.timer:SetFont("Fonts\\FRIZQT__.TTF", 20 * size / 45, "OUTLINE")
        slot.timer:SetPoint("CENTER")
        if not timer or (GetTotemDuration and cooldown.SetCooldownFromDurationObject) then
            slot.binding = BindTimer(slot.timer)
        end
        if not timer then cooldown:SetHideCountdownNumbers(slot.binding ~= nil) end
        return slot
    end
    slots[1] = Icon(falconSize, -spacing, FALCON, "Interface\\Icons\\Ability_Hunter_AspectOfTheHawk", true)
    slots.shot = Icon(shotSize, 0, ARCANE_SHOT, "Interface\\Icons\\Ability_ImpalingBolt", false)
    slots[2] = Icon(falconSize, spacing, FALCON, "Interface\\Icons\\Ability_Hunter_AspectOfTheHawk", true)
    for _, slot in pairs(slots) do
        -- The swipe is cleared as soon as its timer disappears. Keep the
        -- completion animation on a separate frame so it can finish.
        local flash = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
        flash:SetAllPoints(slot.cooldown)
        flash:SetFrameLevel(slot.cooldown:GetFrameLevel())
        flash:SetDrawSwipe(false)
        flash:SetDrawEdge(false)
        flash:SetDrawBling(true)
        flash:SetHideCountdownNumbers(true)
        flash:EnableMouse(false)
        slot.flash = flash
    end
    ApplyIconStyle()
    local elapsed = 0
    frame:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= .05 then
            elapsed = 0
            Update(GetTime())
        end
    end)
end

local function Reset()
    pendingCast, summonTimers = nil, {}
    RestoreBlizzardRow()
    if not frame then return end
    if dragging then frame:StopMovingOrSizing() end
    dragging, anchor = nil, nil
    frame:Hide()
end

local function Refresh()
    if not CanTrack() then Reset(); return end
    UpdateBlizzardRow()
    Create()
    Update(GetTime())
end

module:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(_, _, unit, _, spell)
    if not Public(unit) or unit ~= "player" or not Public(spell)
        or not ranks[spell] or not CanTrack() then return end
    pendingCast = GetTime()
end)

local function MatchSummonSlot(slot)
    if not GetTotemDuration or not Public(slot) or type(slot) ~= "number" then return end
    local now = GetTime()
    local cast = pendingCast
    local age = cast and now - cast
    local inWindow = age and age >= .55 and age <= 1.25
    local bound
    for index = 1, 2 do
        if summonTimers[index] and summonTimers[index].slot == slot then bound = index; break end
    end
    if not inWindow and not bound then return end
    local ok, object = pcall(GetTotemDuration, slot)
    if not ok or not Public(object) then return end
    if not object then
        if bound then
            summonTimers[bound] = nil
            if frame then Update(now) end
        end
        return
    end
    if not inWindow then return end
    if GetTotemInfo then
        local readable, _, _, _, _, _, _, id = pcall(GetTotemInfo, slot)
        if readable and Public(id) and type(id) == "number" and id > 0
            and not ranks[id] and not summonSpells[id] then return end
    end
    local readable, remaining = pcall(function() return object:GetRemainingDuration() end)
    if readable and Public(remaining) and type(remaining) == "number" then
        if remaining < 16.5 or remaining > 18.1 then return end
    end
    Create()
    if not slots[1].binding or not slots[2].binding then return end
    pendingCast = nil
    local first, second = summonTimers[1], summonTimers[2]
    local index = bound or (not first and 1 or not second and 2 or (first.started <= second.started and 1 or 2))
    summonTimers[index] = {slot = slot, object = object, started = now}
    Update(now)
end
module:RegisterEvent("PLAYER_DEAD", function() Reset(); Refresh() end)
local function RefreshSpellbook()
    if not CanTrack() then Reset(); return end
    shotRank = ARCANE_SHOT
    for spell = 14287, 14281, -1 do
        if Knows(spell) then shotRank = spell; break end
    end
    Refresh()
    if frame:IsShown() then UpdateShotCooldown() end
end

module:RegisterEvent("PLAYER_ENTERING_WORLD", function() Reset(); RefreshSpellbook() end)
module:RegisterEvent("PLAYER_TARGET_CHANGED", Refresh)
module:RegisterEvent("PLAYER_REGEN_DISABLED", Refresh)
module:RegisterEvent("PLAYER_REGEN_ENABLED", Refresh)
module:RegisterEvent("MODIFIER_STATE_CHANGED", Refresh)
module:RegisterEvent("SPELLS_CHANGED", RefreshSpellbook)
module:RegisterEvent("SPELL_UPDATE_COOLDOWN", function()
    if frame and frame:IsShown() then UpdateShotCooldown() end
end)
module:RegisterEvent("PLAYER_TOTEM_UPDATE", function(_, _, slot)
    if not CanTrack() then return end
    UpdateBlizzardRow()
    MatchSummonSlot(slot)
end)
local function ResetPosition()
    if dragging then
        frame:StopMovingOrSizing()
        dragging = nil
    end
    module:GetDB().position = nil
    anchor = nil
    if frame then Update(GetTime()) end
    if module.settingsPanel then module.settingsPanel.RefreshForm() end
end

function module:CreateOptionsPanel(parentCategory)
    if self.settingsPanel or not parentCategory or not Settings
        or not Settings.RegisterCanvasLayoutSubcategory then return end
    local panel = CreateFrame("Frame")
    panel:Hide()
    panel:SetSize(700, 560)
    local function Label(text, x, y, font)
        local label = panel:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
        label:SetPoint("TOPLEFT", x, y)
        label:SetText(text)
        return label
    end
    Label(L.FALCON_TRACKER_TITLE, 32, -24, "GameFontNormalLarge")
    local enabled = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    yTools.UI.Check(enabled)
    local enabledLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    enabledLabel:SetText(L.MODULE_OPTIONS_ENABLE)
    enabledLabel:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -32, -22)
    enabled:SetPoint("RIGHT", enabledLabel, "LEFT", -5, 0)
    enabled:SetScript("OnClick", function(button)
        if button:GetChecked() then module:Enable() else module:Disable() end
        panel.RefreshForm()
    end)
    local details = Label(L.FALCON_TRACKER_DESCRIPTION, 32, -64, "GameFontHighlight")
    details:SetWidth(600)
    details:SetJustifyH("LEFT")

    local hide = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    yTools.UI.Check(hide)
    hide:SetPoint("TOPLEFT", details, "BOTTOMLEFT", 0, -22)
    local hideLabel = hide:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hideLabel:SetPoint("LEFT", hide, "RIGHT", 5, 0)
    hideLabel:SetText(L.FALCON_TRACKER_HIDE_SUMMONS)
    hide:SetScript("OnClick", function(button)
        module:GetDB().hideBlizzardSummons = not not button:GetChecked()
        if CanTrack() then UpdateBlizzardRow() end
    end)

    local scale = CreateFrame("Frame", nil, panel, "MinimalSliderWithSteppersTemplate")
    scale:SetSize(210, 24)
    scale:SetPoint("TOPLEFT", 160, -155)
    local scaleLabel = Label(L.FALCON_TRACKER_SCALE, 32, -158)
    scaleLabel:ClearAllPoints()
    scaleLabel:SetPoint("LEFT", panel, "TOPLEFT", 32, -167)
    local formatters = {
        [MinimalSliderWithSteppersMixin.Label.Right] = function(value)
            return ("%d%%"):format(math.floor(value + .5))
        end,
    }
    scale:Init((module:GetDB().scale or 1) * 100, 10, 200, 38, formatters)
    scale:RegisterCallback("OnValueChanged", function(_, value)
        module:GetDB().scale = value / 100
        if frame then
            frame:SetScale(value / 100)
            ApplyIconStyle()
            anchor = nil
            Place()
        end
    end, panel)

    local zoom = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    yTools.UI.Check(zoom)
    zoom:SetPoint("TOPLEFT", panel, "TOPLEFT", 32, -187)
    local zoomLabel = zoom:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    zoomLabel:SetPoint("LEFT", zoom, "RIGHT", 5, 0)
    zoomLabel:SetText(L.FALCON_TRACKER_ZOOM_ICONS)
    zoom:SetScript("OnClick", function(button)
        module:GetDB().zoomIcons = not not button:GetChecked()
        if frame then ApplyIconStyle() end
    end)

    Label(L.FALCON_TRACKER_POSITION, 32, -221)
    local function PositionInput(label, offset, axis)
        local caption = Label(label, offset, -250)
        local input = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        input:SetPoint("TOPLEFT", caption, "BOTTOMLEFT", 4, -5)
        input:SetSize(92, 24)
        input:SetAutoFocus(false)
        input:SetMaxLetters(12)
        local function Save()
            local value = tonumber((input:GetText():gsub(",", ".")))
            if value and value == value and math.abs(value) < math.huge then
                value = math.max(-10000, math.min(10000, value))
                local x, y = CenterPosition()
                module:GetDB().position = {"CENTER", "CENTER", axis == 1 and value or x, axis == 2 and value or y}
                anchor = nil
                if frame then Place() end
            end
            panel.RefreshForm()
        end
        input:SetScript("OnEnterPressed", function() input:ClearFocus() end)
        input:SetScript("OnEditFocusLost", function()
            if not input.cancelled then Save() end
        end)
        input:SetScript("OnEscapePressed", function()
            input.cancelled = true
            input:ClearFocus()
            input.cancelled = nil
            panel.RefreshForm()
        end)
        return input
    end
    local xInput, yInput = PositionInput("X", 32, 1), PositionInput("Y", 155, 2)
    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetPoint("TOPLEFT", 32, -311)
    reset:SetSize(185, 24)
    reset:SetText(L.FALCON_TRACKER_RESET_POSITION)
    reset:SetScript("OnClick", ResetPosition)
    panel.RefreshForm = function()
        enabled:SetChecked(module:IsEnabled())
        local db = module:GetDB()
        hide:SetChecked(db.hideBlizzardSummons)
        zoom:SetChecked(db.zoomIcons)
        local x, y = CenterPosition()
        if not xInput:HasFocus() then xInput:SetText((("%.2f"):format(x):gsub("%.?0+$", ""))) end
        if not yInput:HasFocus() then yInput:SetText((("%.2f"):format(y):gsub("%.?0+$", ""))) end
    end
    panel:SetScript("OnShow", panel.RefreshForm)
    self.settingsPanel = panel
    self.settingsCategory = Settings.RegisterCanvasLayoutSubcategory(parentCategory, panel, L.FALCON_TRACKER_TITLE)
end

module:RegisterSlashCommand("falcontracker", function(_, arguments)
    local command = (arguments or ""):match("^%s*(.-)%s*$"):lower()
    if command == "reset" then
        ResetPosition()
        yTools:Print(L.FALCON_TRACKER_POSITION_RESET)
        return
    end
    if command ~= "totems" then
        yTools:Print(L.FALCON_TRACKER_RESET_HELP)
        yTools:Print(L.FALCON_TRACKER_TOTEMS_HELP)
        return
    end
    local db = module:GetDB()
    db.hideBlizzardSummons = not db.hideBlizzardSummons
    if CanTrack() then UpdateBlizzardRow() end
    if module.settingsPanel then module.settingsPanel.RefreshForm() end
    yTools:Print(db.hideBlizzardSummons and L.FALCON_TRACKER_TOTEMS_HIDDEN or L.FALCON_TRACKER_TOTEMS_SHOWN)
end, "/ytools falcontracker")
yTools.commands.falcontracker.allowDisabled = function(arguments)
    local command = (arguments or ""):match("^%s*(.-)%s*$"):lower()
    return command == "" or command == "reset"
end
module.OnEnable = RefreshSpellbook
module.OnDisable = Reset
