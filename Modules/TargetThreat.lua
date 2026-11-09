local yTools = _G.yTools
local L = yTools.L
local module = yTools:RegisterModule("TargetThreat", {
    title = L.TARGET_THREAT_MODULE,
    description = L.TARGET_THREAT_DESCRIPTION,
    defaultEnabled = true,
    defaults = {showPet = false},
})

local tab, petTab, worker
local debugEnabled, debugStarted, debugKey, debugPrintedAt = false, 0, nil, -math.huge
local function Public(value)
    return not issecretvalue or not issecretvalue(value)
end

local function FirstPlacePercent(scaledPercent, rawPercent, ownThreat, actor)
    local trace = actor == "player" and debugEnabled and {blocked = {}, pet = "not_scanned"} or nil
    local function Result(value, reason)
        if trace then trace.reason = reason end
        return value, trace
    end
    local function Blocked(unit, field)
        if trace then trace.blocked[#trace.blocked + 1] = unit .. ":" .. field end
    end
    -- Being first in raw threat does not necessarily mean the mob has switched
    -- targets yet. Use amounts, never isTanking or the pull-aggro percentage.
    -- Native percentages can disagree with readable amounts (e.g. raw 87%
    -- while player threat exceeds the pet). Compare contenders before deciding.
    local useAmounts = Public(ownThreat) and type(ownThreat) == "number" and ownThreat > 0
    local own = useAmounts and ownThreat or rawPercent
    if trace then trace.mode = useAmounts and "amount" or "raw_percent" end
    if not Public(own) or type(own) ~= "number" or own <= 0 then return Result(scaledPercent, "PLAYER_THREAT_UNAVAILABLE") end

    local second, restricted = 0, false
    local seenUnits, seenGUIDs = {actor}, {}
    local actorGUID = UnitGUID and UnitGUID(actor)
    if Public(actorGUID) and type(actorGUID) == "string" then seenGUIDs[actorGUID] = true end
    local function Consider(unit)
        if not Public(unit) or type(unit) ~= "string" or unit == actor then return end
        local exists = UnitExists(unit)
        if not Public(exists) then restricted = true; Blocked(unit, "exists"); return end
        if not exists then if trace and unit == "pet" then trace.pet = "missing" end; return end
        -- The same actor can be pet/targettarget/focus/nameplate at once. A
        -- secondary token may return restricted threat even when pet is public.
        local guid = UnitGUID and UnitGUID(unit)
        if Public(guid) and type(guid) == "string" then
            if seenGUIDs[guid] then return end
            seenGUIDs[guid] = true
        else
            local unknownIdentity = false
            for _, known in ipairs(seenUnits) do
                local same = UnitIsUnit(unit, known)
                if Public(same) then
                    if same then return end
                else unknownIdentity = true end
            end
            if unknownIdentity then restricted = true; Blocked(unit, "identity"); return end
        end
        seenUnits[#seenUnits + 1] = unit
        local _, _, _, raw, amount = UnitDetailedThreatSituation(unit, "target")
        local value = amount
        if not useAmounts then value = raw end
        if trace and unit == "pet" then trace.pet = value end
        if not Public(value) then restricted = true; Blocked(unit, "threat"); return end
        if type(value) == "number" and value > second then
            second = value
            if trace then trace.secondUnit = unit end
        end
    end
    Consider(actor == "pet" and "player" or "pet")
    local raid = IsInRaid and IsInRaid()
    if not Public(raid) then restricted = true; Blocked("group", "raid_state") end
    if Public(raid) and raid then
        local count = GetNumGroupMembers and GetNumGroupMembers() or 40
        if Public(count) and type(count) == "number" then
            for i = 1, math.min(count, 40) do Consider("raid" .. i); Consider("raidpet" .. i) end
        else restricted = true; Blocked("raid", "count") end
    else
        local count = GetNumSubgroupMembers and GetNumSubgroupMembers() or 4
        if Public(count) and type(count) == "number" then
            for i = 1, math.min(count, 4) do Consider("party" .. i); Consider("partypet" .. i) end
        else restricted = true; Blocked("party", "count") end
    end
    -- Include accessible contenders outside the group as well.
    for _, unit in ipairs({"targettarget", "focus", "focustarget", "mouseover"}) do Consider(unit) end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do Consider(plate.namePlateUnitToken) end
    end
    if trace then trace.second = second end
    if not restricted and second > 0 and own >= second then return Result(own / second * 100, "RELATIVE_TO_SECOND") end
    -- No visible runner-up or protected threat values: retain the native value.
    return Result(scaledPercent, restricted and "RESTRICTED_UNIT" or (second <= 0 and "NO_RUNNER_UP" or "NOT_FIRST"))
end

local function DebugValue(value)
    if not Public(value) then return "<protected>" end
    if type(value) == "number" then return string.format("%.2f", value) end
    if value == nil then return "nil" end
    if type(value) == "string" then return value end
    if type(value) == "boolean" then return value and "true" or "false" end
    return "<unavailable>"
end
local function DebugSnapshot(trace, normal, raw, own, displayed)
    if not debugEnabled or not trace then return end
    local blocked = table.concat(trace.blocked, ",")
    local key = trace.reason .. "|" .. (trace.secondUnit or "none") .. "|" .. blocked .. "|" .. type(trace.pet)
    local now = GetTime()
    if now - debugPrintedAt < 1 then return end
    debugKey, debugPrintedAt = key, now
    -- Read the pet independently for every snapshot, including early-return
    -- paths, so a state-change-only log cannot hide the rest of the fight.
    local _, _, petScaled, petRaw, petAmount = UnitDetailedThreatSituation("pet", "target")
    local mob = UnitGUID and UnitGUID("target")
    local petExists = UnitExists("pet")
    local tankSelf, tankPet = UnitIsUnit("targettarget", "player"), UnitIsUnit("targettarget", "pet")
    local petTarget = UnitIsUnit("pettarget", "target")
    yTools:Print(string.format("Threat +%.3fs %s mode=%s player=%s raw_pct=%s native_pct=%s shown_pct=%s second=%s second_unit=%s pet=%s blocked=%s mob=%s tank_self=%s tank_pet=%s pet_exists=%s pet_target=%s pet_amount=%s pet_raw=%s pet_scaled=%s",
        now - debugStarted, trace.reason, trace.mode or "none", DebugValue(own), DebugValue(raw), DebugValue(normal),
        DebugValue(displayed), DebugValue(trace.second), trace.secondUnit or "none", DebugValue(trace.pet), blocked ~= "" and blocked or "none",
        DebugValue(mob), DebugValue(tankSelf), DebugValue(tankPet), DebugValue(petExists), DebugValue(petTarget),
        DebugValue(petAmount), DebugValue(petRaw), DebugValue(petScaled)))
end

local glowCurves = {}
local function SetRestrictedGlow(glow, percent, threshold)
    if not C_CurveUtil or not C_CurveUtil.CreateCurve or not Enum
        or not Enum.LuaCurveType or not Enum.LuaCurveType.Step then return end
    local glowCurve = glowCurves[threshold]
    if not glowCurve then
        glowCurve = C_CurveUtil.CreateCurve()
        glowCurve:SetType(Enum.LuaCurveType.Step)
        glowCurve:AddPoint(0, 0)
        glowCurve:AddPoint(threshold, 1)
        glowCurves[threshold] = glowCurve
    end
    glow:SetAlpha(glowCurve:Evaluate(percent))
end

local function CreateTab(target, isPet)
    local scale = isPet and .60 or 1
    local frame = CreateFrame("Frame", nil, target)
    frame:SetSize(64 * scale, 20 * scale)
    frame:SetFrameLevel(math.max(0, target:GetFrameLevel() - 1))
    frame:EnableMouse(false)

    local layouts = {}
    -- Auras use TargetFrame.buffsOnTop even when their container is empty.
    -- Only read that public layout preference; never inspect aura data.
    function frame:UpdatePlacement(anchor)
        local buffsOnTop = target.buffsOnTop
        if not Public(buffsOnTop) then return end
        local above = not buffsOnTop
        if self.above == above and self.anchor == anchor then return end
        self.above, self.anchor = above, anchor
        local content = target.TargetFrameContent
        local main = content and content.TargetFrameContentMain
        local power = (main and main.ManaBar) or target.manabar or _G.TargetFrameManaBar
        local health = target.healthbar or _G.TargetFrameHealthBar
        local name = main and main.ReputationColor
        self:ClearAllPoints()
        if anchor then
            self:SetPoint(above and "BOTTOM" or "TOP", anchor, above and "TOP" or "BOTTOM", 0, above and -2 or 2)
        elseif above then
            if name then
                self:SetPoint("BOTTOM", name, "TOP", 0, 1)
            elseif health then
                self:SetPoint("BOTTOM", health, "TOP", 0, 24)
            else
                self:SetPoint("BOTTOM", target, "TOP", -19, -24)
            end
        elseif power then
            self:SetPoint("TOP", power, "BOTTOM", 0, -1)
        elseif health then
            self:SetPoint("TOP", health, "BOTTOM", 0, -12)
        else
            self:SetPoint("TOP", target, "BOTTOM", -19, 29)
        end
        self.label:ClearAllPoints()
        self.label:SetPoint("CENTER", 0, above and -1 or 1)
        local edge, direction = above and "BOTTOM" or "TOP", above and 1 or -1
        for _, layout in ipairs(layouts) do layout(edge, direction) end
    end

    -- Draw the tab with stock solid regions. The open edge meets the native frame rim.
    local function Fill(parent, color)
        for row = 0, 17 do
            local strip = parent:CreateTexture(nil, "BACKGROUND", nil, color == "red" and -3 or color == "yellow" and -4 or -5)
            local stripRow = row
            layouts[#layouts + 1] = function(edge, direction)
                strip:ClearAllPoints()
                strip:SetPoint(edge, 0, direction * stripRow * scale)
            end
            strip:SetSize((62 - row * .72) * scale, 1.05 * scale)
            local t = row / 17
            if color == "red" then
                local ember = 1 - math.abs(t * 2 - 1)
                strip:SetColorTexture(.32 + .33 * ember, .025 + .04 * ember, .018 + .018 * ember, 1)
            elseif color == "yellow" then
                local amber = 1 - math.abs(t * 2 - 1)
                strip:SetColorTexture(.40 + .24 * amber, .25 + .17 * amber, .025 + .035 * amber, 1)
            else
                strip:SetColorTexture(.19 - .085 * t, .13 - .06 * t, .078 - .033 * t, 1)
            end
        end
    end

    local function Rim(parent, thickness, r, g, b, alpha, spread)
        local function Edge(x1, y1, x2, y2)
            local line = parent:CreateLine(nil, "BACKGROUND", nil, thickness > 2 and -2 or -1)
            layouts[#layouts + 1] = function(edge, direction)
                line:SetStartPoint(edge, x1 * scale, -direction * y1 * scale)
                line:SetEndPoint(edge, x2 * scale, -direction * y2 * scale)
            end
            line:SetThickness(thickness * scale)
            line:SetColorTexture(r, g, b, alpha)
        end
        local top, bottom, y = 31 + spread, 25 + spread, -18 - spread
        Edge(-top, 0, -bottom, y)
        Edge(top, 0, bottom, y)
        Edge(-bottom, y, bottom, y)
    end

    Fill(frame, false)
    Rim(frame, 2.8, .22, .14, .08, 1, .4)
    Rim(frame, 1.2, .67, .49, .29, 1, 0)

    local glow = CreateFrame("Frame", nil, frame)
    glow:SetAllPoints()
    glow:SetFrameLevel(frame:GetFrameLevel())
    glow:EnableMouse(false)
    Fill(glow, "red")
    glow:SetAlpha(0)
    frame.glow = glow

    local warning = CreateFrame("Frame", nil, frame)
    warning:SetAllPoints()
    warning:SetFrameLevel(frame:GetFrameLevel())
    warning:EnableMouse(false)
    Fill(warning, "yellow")
    warning:SetAlpha(0)
    frame.warning = warning

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER", 0, 1)
    if isPet then
        label:SetScale(.78)
        label:SetTextColor(.74, .88, 1)
    end
    frame.label = label
    frame:UpdatePlacement()
    return frame
end

local function Render(tab, percent)
    -- Keep restricted threat numbers out of Lua formatting and arithmetic.
    if issecretvalue and issecretvalue(percent) then
        local shown = pcall(tab.label.SetFormattedText, tab.label, "%.0f%%", percent)
        tab.glow:SetAlpha(0)
        tab.warning:SetAlpha(0)
        if shown then
            pcall(SetRestrictedGlow, tab.warning, percent, 80)
            pcall(SetRestrictedGlow, tab.glow, percent, 100)
        end
        tab:SetShown(shown)
    else
        if percent >= 999.5 then
            local short = string.format("%.2f", percent / 1000):gsub("0+$", ""):gsub("%.$", "")
            tab.label:SetText(short .. "k%")
        else
            tab.label:SetFormattedText("%.0f%%", percent)
        end
        tab.warning:SetAlpha(percent >= 80 and percent < 100 and 1 or 0)
        tab.glow:SetAlpha(percent >= 100 and 1 or 0)
        tab:Show()
    end
end

local function Update()
    local target = _G.TargetFrame
    local exists = target and UnitExists("target")
    if not module:IsEnabled() or not Public(exists) or not exists or not UnitDetailedThreatSituation then
        if tab then tab:Hide() end
        if petTab then petTab:Hide() end
        return
    end

    local _, _, normal, rawPercent, ownThreat = UnitDetailedThreatSituation("player", "target")
    local percent, trace = FirstPlacePercent(normal, rawPercent, ownThreat, "player")
    DebugSnapshot(trace, normal, rawPercent, ownThreat, percent)
    if type(percent) == "number" then
        tab = tab or CreateTab(target)
        tab:UpdatePlacement()
        Render(tab, percent)
    elseif tab then
        tab:Hide()
    end

    if module:GetDB().showPet then
        local petExists = UnitExists("pet")
        if Public(petExists) and petExists then
            local _, _, scaled, raw, amount = UnitDetailedThreatSituation("pet", "target")
            local petPercent = FirstPlacePercent(scaled, raw, amount, "pet")
            if type(petPercent) == "number" then
                petTab = petTab or CreateTab(target, true)
                petTab:UpdatePlacement(tab and tab:IsShown() and tab or nil)
                Render(petTab, petPercent)
                return
            end
        end
    end
    if petTab then petTab:Hide() end
end

function module:CreateOptionsPanel(parentCategory)
    if self.settingsPanel or not parentCategory or not Settings
        or not Settings.RegisterCanvasLayoutSubcategory then return end
    local panel = CreateFrame("Frame")
    panel:Hide()
    panel:SetSize(700, 560)
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 32, -24)
    title:SetText(L.TARGET_THREAT_MODULE)
    local details = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    details:SetPoint("TOPLEFT", 32, -64)
    details:SetWidth(600)
    details:SetJustifyH("LEFT")
    details:SetText(L.TARGET_THREAT_DESCRIPTION)
    local function Check(text, font)
        local button = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
        yTools.UI.Check(button)
        local label = button:CreateFontString(nil, "OVERLAY", font)
        label:SetText(text)
        return button, label
    end
    local enabled, enabledLabel = Check(L.MODULE_OPTIONS_ENABLE, "GameFontHighlight")
    enabledLabel:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -32, -22)
    enabled:SetPoint("RIGHT", enabledLabel, "LEFT", -5, 0)
    local pet, petLabel = Check(L.TARGET_THREAT_SHOW_PET, "GameFontNormal")
    pet:SetPoint("TOPLEFT", details, "BOTTOMLEFT", 0, -26)
    petLabel:SetPoint("LEFT", pet, "RIGHT", 2, 0)
    panel.RefreshForm = function()
        enabled:SetChecked(module:IsEnabled())
        pet:SetChecked(module:GetDB().showPet)
        pet:SetShown(module:IsEnabled())
    end
    enabled:SetScript("OnClick", function(button)
        if button:GetChecked() then module:Enable() else module:Disable() end
        panel.RefreshForm()
    end)
    pet:SetScript("OnClick", function(button)
        module:GetDB().showPet = not not button:GetChecked()
        Update()
    end)
    panel:SetScript("OnShow", panel.RefreshForm)
    self.settingsPanel = panel
    self.settingsCategory = Settings.RegisterCanvasLayoutSubcategory(parentCategory, panel, L.TARGET_THREAT_TITLE)
end

function module:OnEnable()
    if not worker then
        worker = CreateFrame("Frame")
        local elapsedTime = 0
        worker:SetScript("OnUpdate", function(_, elapsed)
            elapsedTime = elapsedTime + elapsed
            if elapsedTime < 0.2 then return end
            elapsedTime = 0
            Update()
        end)
    end
    worker:Show()
    Update()
end
function module:OnDisable()
    if worker then worker:Hide() end
    if tab then tab:Hide() end
    if petTab then petTab:Hide() end
end

for _, event in ipairs({
    "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_ENABLED",
    "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE",
    "GROUP_ROSTER_UPDATE", "UNIT_PET", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
}) do
    module:RegisterEvent(event, Update)
end

module:RegisterSlashCommand("targetthreat", function(_, arguments)
    local command = (arguments or ""):lower():match("^%s*(.-)%s*$")
    if command == "debug" or command == "debug on" or command == "debug off" then
        if command == "debug" then debugEnabled = not debugEnabled
        else debugEnabled = command == "debug on" end
        debugStarted, debugKey, debugPrintedAt = GetTime(), nil, -math.huge
        yTools:Print(debugEnabled and L.TARGET_THREAT_DEBUG_ON or L.TARGET_THREAT_DEBUG_OFF)
        if debugEnabled then Update() end
    else yTools:Print(L.TARGET_THREAT_DEBUG_HELP) end
end, L.TARGET_THREAT_DEBUG_HELP)
