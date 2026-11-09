local yTools = _G.yTools
local L = yTools.L
local function Hunter()
    local _, class = UnitClass("player")
    return not (issecretvalue and issecretvalue(class)) and class == "HUNTER"
end
local module = yTools:RegisterModule("HunterBar", {
    title = L.HUNTERBAR_MODULE,
    description = L.HUNTERBAR_DESCRIPTION,
    characterDefault = Hunter,
    defaults = {
        barMode = "DEFAULT", movementOpacity = .4, lateDelays = {},
        attach = "TOP", fitWidth = true, width = 240, height = 24, gap = 5,
        rangeAlign = "CENTER", timerAlign = "RIGHT", rangeVertical = "ON", timerVertical = "ON", alwaysShow = false, alwaysShowCombat = false, alwaysShowTarget = false, opacity = .5, shotFlash = false,
        barColor = {0, 1, 0}, windupColor = {1, 0, 0},
        position = {"CENTER", "CENTER", 0, -180},
    },
})

local opening, wasMoving, stationarySince, movementEvent
local lateStop, lateEstimate, lateBlocked, lateSpeed
local lateHistory = {}

local function ResetLateStop()
    lateStop, lateEstimate, lateBlocked, lateSpeed = nil, nil, nil, nil
end

local RANGED_SLOT = GetInventorySlotInfo and GetInventorySlotInfo("RangedSlot") or 18

local function ClearLateHistory()
    module:GetDB().lateDelays = {}
    lateHistory = {}
    ResetLateStop()
end

local function LateEntry(speed)
    local entry = lateHistory[speed]
    if not entry then
        local saved = module:GetDB().lateDelays[speed]
        local valid = type(saved) == "number" and saved >= .2 and saved <= 1.5
        entry = {samples = {}, estimate = valid and saved or nil, needsValidation = valid}
        lateHistory[speed] = entry
    end
    return entry
end

local function LearnLateTime(speed, value)
    -- Ignore long holds and incomplete windups; keep a short rolling history.
    if value < .2 or value > 1.5 then return end
    local entry = LateEntry(speed)
    local saved = module:GetDB().lateDelays
    if entry.needsValidation then
        entry.needsValidation = false
        -- Normal retry timing varies by several hundred milliseconds.
        if math.abs(value - entry.estimate) > .5 then
            saved[speed], entry.estimate = nil, nil
        end
    end
    local lateSamples = entry.samples
    lateSamples[#lateSamples + 1] = value
    if #lateSamples > 9 then table.remove(lateSamples, 1) end
    if #lateSamples < 3 then return end
    local ordered = {unpack(lateSamples)}
    table.sort(ordered)
    local mid = math.floor((#ordered + 1) / 2)
    entry.estimate = #ordered % 2 == 1 and ordered[mid] or (ordered[mid] + ordered[mid + 1]) / 2
    saved[speed] = entry.estimate
end
local debugTrace, debugStart, debugStop, debugPhase, debugFull, debugLastShot
local function Trace(event, details)
    local now = GetTime()
    yTools:Print(string.format("HunterBar +%.3fs %s%s", now - debugStart, event,
        details and (" " .. details) or ""))
end
local frame, preview, active, duration, expires, dragging, styledNative
local elapsedSinceLayout = 0
local SHOT_FLASH_DURATION, SHOT_FLASH_SPREAD = .28, 9
local shotFlashAt
local rangeResult, rangeTicker
local ApplyLayout, UpdateDisplay
local function PublicNumber(value)
    return not (issecretvalue and issecretvalue(value)) and type(value) == "number"
        and value == value and value > -math.huge and value < math.huge
end
local function Castbar()
    return PlayerCastingBarFrame or CastingBarFrame
end
local function Windup()
    local value = .5
    local haste = GetRangedHaste and GetRangedHaste()
    if PublicNumber(haste) and haste > -100 then value = value / (1 + haste / 100) end
    if value > 0 and GetNetStats then
        local _, _, _, worldLatency = GetNetStats()
        if PublicNumber(worldLatency) and worldLatency > 0 then
            value = value + worldLatency / 1000
        end
    end
    return value
end
local function WeaponSpeed()
    if UnitRangedDamage then
        local speed = UnitRangedDamage("player")
        if PublicNumber(speed) and speed > 0 then return speed end
    end
    if UnitAttackSpeed then
        local _, _, speed = UnitAttackSpeed("player")
        if PublicNumber(speed) and speed > 0 then return speed end
    end
end
local function CheckRangedWeapon()
    if not GetInventoryItemID then return end
    local weapon = GetInventoryItemID("player", RANGED_SLOT)
    if (issecretvalue and issecretvalue(weapon)) or not weapon then return end
    local speed = WeaponSpeed()
    if not speed then return end
    local db = module:GetDB()
    if db.lateWeapon and db.lateWeapon ~= weapon then
        ResetLateStop()
        if db.lateWeaponSpeed and math.abs(db.lateWeaponSpeed - speed) > .000001 then
            ClearLateHistory()
        end
    end
    db.lateWeapon, db.lateWeaponSpeed = weapon, speed
end

local function SpeedKey(speed)
    return speed and math.floor(speed * 100 + .5)
end

local function StopDragging()
    if not dragging or not frame then return end
    dragging = false
    frame:StopMovingOrSizing()
    local point, _, relative, x, y = frame:GetPoint()
    module:GetDB().position = {point, relative, x, y}
    ApplyLayout()
end

local function NativeStyle()
    if not frame then return end
    local native = SwingTimerRangedFrame
    styledNative = native
    local function CopyAsset(destination, source, fallback)
        local atlas = source and source.GetAtlas and source:GetAtlas()
        if atlas then destination:SetAtlas(atlas)
        elseif source and source.GetTexture and source:GetTexture() then
            destination:SetTexture(source:GetTexture())
        else destination:SetAtlas(fallback) end
    end
    CopyAsset(frame.Background, native and native.Background, "ui-swingtimerbar-background")
    CopyAsset(frame.Border, native and native.Border, "ui-swingtimerbar-frame")
    local texture = native and native.StatusBar and native.StatusBar:GetStatusBarTexture()
    -- Apply the atlas to the texture itself. SetStatusBarTexture receives file
    -- assets on clients where passing an atlas name is not supported.
    CopyAsset(frame.bar:GetStatusBarTexture(), texture, "ui-swingtimerbar-filling-ranged")
    for _, half in ipairs(frame.centerFills) do
        CopyAsset(half, texture, "ui-swingtimerbar-filling-ranged")
        half:SetDesaturated(true)
    end
    frame.centerUV = {frame.centerFills[1]:GetTexCoord()}
    if #frame.centerUV ~= 8 then frame.centerUV = {0, 0, 0, 1, 1, 0, 1, 1} end
    CopyAsset(frame.pip, native and native.StatusBar and native.StatusBar.Pip, "ui-swingtimerbar-pip")
end

local function CreateBar()
    if frame then return end
    -- Independent frame: never reuse the native swing mixin, Edit Mode state,
    -- secure spell buttons, or the player castbar's visibility/event scripts.
    frame = CreateFrame("Frame", "yToolsHunterBar", UIParent)
    frame:Hide()
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("MEDIUM")
    frame.Background = frame:CreateTexture(nil, "BACKGROUND")
    frame.Background:SetAllPoints()
    frame.Background:SetAtlas("ui-swingtimerbar-background")
    frame.Border = frame:CreateTexture(nil, "BORDER")
    frame.Border:SetAllPoints()
    frame.Border:SetAtlas("ui-swingtimerbar-frame")
    local bar = CreateFrame("StatusBar", nil, frame)
    frame.bar = bar
    bar:SetPoint("TOPLEFT", 5, -4)
    bar:SetPoint("BOTTOMRIGHT", -5, 4)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    frame.centerFills = {}
    for _, side in ipairs({"RIGHT", "LEFT"}) do
        local half = bar:CreateTexture(nil, "ARTWORK")
        half:SetPoint("TOP"..side, bar, "TOP")
        half:SetPoint("BOTTOM"..side, bar, "BOTTOM")
        half:Hide()
        table.insert(frame.centerFills, half)
    end
    frame.pip = bar:CreateTexture(nil, "OVERLAY")
    frame.pip:SetAtlas("ui-swingtimerbar-pip", true)
    frame.pip:SetPoint("RIGHT", bar:GetStatusBarTexture(), "RIGHT")
    local glow = CreateFrame("Frame", nil, bar)
    glow:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    glow:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    frame.shotFlash = glow
    for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
        local horizontal = side == "TOP" or side == "BOTTOM"
        local forward = side == "TOP" or side == "RIGHT"
        local first = horizontal and side .. "LEFT" or "TOP" .. side
        local last = horizontal and side .. "RIGHT" or "BOTTOM" .. side
        local rim = glow:CreateTexture(nil, "OVERLAY")
        rim:SetPoint(first, glow, first)
        rim:SetPoint(last, glow, last)
        if horizontal then rim:SetHeight(2) else rim:SetWidth(2) end
        rim:SetColorTexture(1, 1, .95, 1)
        rim:SetBlendMode("ADD")
        local halo = glow:CreateTexture(nil, "ARTWORK")
        local opposite = horizontal and (forward and "BOTTOM" or "TOP") or (forward and "LEFT" or "RIGHT")
        halo:SetPoint(horizontal and opposite .. "LEFT" or "TOP" .. opposite, glow, first)
        halo:SetPoint(horizontal and opposite .. "RIGHT" or "BOTTOM" .. opposite, glow, last)
        if horizontal then halo:SetHeight(4) else halo:SetWidth(4) end
        halo:SetColorTexture(1, 1, 1, 1)
        halo:SetBlendMode("ADD")
        local gold, clear = CreateColor(1, .90, .58, .9), CreateColor(1, .90, .58, 0)
        halo:SetGradient(horizontal and "VERTICAL" or "HORIZONTAL", forward and gold or clear, forward and clear or gold)
    end
    glow:Hide()
    frame.time = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.range = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.time:SetPoint("RIGHT", -10, 0)
    NativeStyle()
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        if module:GetDB().attach == "FREE" and IsControlKeyDown() and IsAltKeyDown() and IsShiftKeyDown() then
            dragging = true; frame:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", StopDragging)
    frame:SetScript("OnMouseUp", StopDragging)
    frame:SetScript("OnHide", StopDragging)
    frame:SetScript("OnUpdate", function(_, elapsed)
        if dragging and not IsMouseButtonDown("LeftButton") then StopDragging() end
        elapsedSinceLayout = elapsedSinceLayout + elapsed
        if elapsedSinceLayout >= .2 then
            elapsedSinceLayout = 0
            if not dragging then ApplyLayout() end
        end
        UpdateDisplay()
    end)
end

local function AlignText()
    local db, bar = module:GetDB(), frame.bar
    local groups = {ON = {}, ABOVE = {}, BELOW = {}}
    local function Add(text, align, vertical)
        text:ClearAllPoints()
        local visible = (align == "LEFT" or align == "CENTER" or align == "RIGHT")
            and (text ~= frame.range or (text:GetText() or "") ~= "")
        text:SetShown(not not visible)
        if not visible then return end
        local row = groups[vertical] or groups.ON
        row[align] = row[align] or {}
        table.insert(row[align], text)
    end
    Add(frame.range, db.rangeAlign, db.rangeVertical)
    Add(frame.time, db.timerAlign, db.timerVertical)
    for vertical, row in pairs(groups) do
        for point, group in pairs(row) do
            local width = (#group - 1) * 8
            for _, text in ipairs(group) do width = width + text:GetStringWidth() end
            local x = point == "LEFT" and 10 or point == "RIGHT" and -10 - width or -width / 2
            local anchor, target, y = "LEFT", point, 0
            if vertical == "ABOVE" then
                anchor, target, y = "BOTTOMLEFT", point == "CENTER" and "TOP" or "TOP"..point, 3
            elseif vertical == "BELOW" then
                anchor, target, y = "TOPLEFT", point == "CENTER" and "BOTTOM" or "BOTTOM"..point, -3
            end
            for _, text in ipairs(group) do
                text:SetPoint(anchor, vertical == "ON" and bar or frame, target, x, y)
                x = x + text:GetStringWidth() + 8
            end
        end
    end
end

local function ReadRange(fn, ...)
    if not fn then return end
    local ok, value = pcall(fn, ...)
    if not ok or (issecretvalue and issecretvalue(value)) then return end
    if value == true or value == 1 then return true end
    if value == false or value == 0 then return false end
end

local function LateSampleBlocked()
    return ReadRange(UnitCanAttack, "player", "target") ~= true
        or ReadRange(UnitIsDeadOrGhost, "target") == true
        or ReadRange(C_Spell and C_Spell.IsSpellInRange, 75, "target") == false
end

local function UpdateRange()
    local text = frame.range
    local shoot, result
    if preview and not active then result = "20–30 " .. L.HUNTERBAR_YARDS
    elseif ReadRange(UnitCanAttack, "player", "target") and not ReadRange(UnitIsDeadOrGhost, "target") then
        shoot = ReadRange(C_Spell and C_Spell.IsSpellInRange, 75, "target")
        local minRange, maxRange = 8, nil
        if C_Spell and C_Spell.GetSpellInfo then
            local info = C_Spell.GetSpellInfo(75)
            if not (issecretvalue and issecretvalue(info)) and type(info) == "table"
                and not (issecrettable and issecrettable(info)) then
                if PublicNumber(info.minRange) and info.minRange > 0 then minRange = info.minRange end
                if PublicNumber(info.maxRange) and info.maxRange >= minRange then maxRange = info.maxRange end
            end
        end
        local lo, hi = 0, nil
        local check = C_Item and C_Item.IsItemInRange
        for _, probe in ipairs({{20, 10645}, {30, 835}, {35, 24269}}) do
            local inside = ReadRange(check, probe[2], "target")
            if inside == true then hi = math.min(hi or probe[1], probe[1])
            elseif inside == false then lo = math.max(lo, probe[1]) end
        end
        if shoot == true then lo = math.max(lo, minRange); hi = maxRange and math.min(hi or maxRange, maxRange) or hi
        elseif shoot == false and maxRange then
            if hi and hi <= maxRange and lo < minRange then hi = minRange
            elseif lo >= minRange then lo = math.max(lo, maxRange) end
        end
        local yards = " " .. L.HUNTERBAR_YARDS
        if hi and lo < hi then
            result = lo == 0 and ("<" .. hi .. yards) or (lo .. "–" .. hi .. yards)
        elseif not hi and lo > 0 then result = ">" .. lo .. yards end
    end
    rangeResult = not (preview and not active) and result or nil
    local label = result or (shoot == false and L.HUNTERBAR_OUT_OF_RANGE)
    text:SetText(module:GetDB().rangeAlign ~= "NONE" and label or "")
    if shoot == false then text:SetTextColor(1, .23, .19) else text:SetTextColor(1, 1, 1) end
end

ApplyLayout = function()
    if not frame or dragging then return end
    if SwingTimerRangedFrame and styledNative ~= SwingTimerRangedFrame then NativeStyle() end
    local db, anchor = module:GetDB(), Castbar()
    local width = db.width
    local attached = db.attach ~= "FREE" and anchor ~= nil
    if attached and db.fitWidth then
        local nativeWidth = anchor:GetWidth()
        if PublicNumber(nativeWidth) and nativeWidth > 0 then
            width = nativeWidth * anchor:GetEffectiveScale() / frame:GetEffectiveScale()
        end
    end
    -- Only our own frame is moved/resized, even during combat.
    frame:ClearAllPoints()
    if attached then
        if db.attach == "TOP" then frame:SetPoint("BOTTOM", anchor, "TOP", 0, db.gap)
        else frame:SetPoint("TOP", anchor, "BOTTOM", 0, -db.gap) end
    else
        local p = db.position
        frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    end
    frame:SetSize(math.max(60, width), db.height)
    frame:SetAlpha(db.opacity)
    frame:EnableMouse(db.attach == "FREE")
    frame.bar:SetStatusBarColor(unpack(db.barColor))
    UpdateRange(); AlignText()
end

local function VisibilityMode()
    local db = module:GetDB()
    if db.visibility then return db.visibility end
    if db.alwaysShow then return "ALWAYS" end
    if db.alwaysShowTarget then return db.alwaysShowCombat and "EITHER" or "TARGET" end
    return "COMBAT"
end

UpdateDisplay = function()
    if not frame then return end
    local db = module:GetDB()
    local visibility = VisibilityMode()
    local visible = module:IsEnabled() and (Hunter() or preview)
        and (preview or active or visibility == "ALWAYS"
            or ((visibility == "COMBAT" or visibility == "EITHER") and InCombatLockdown and InCombatLockdown())
            or ((visibility == "TARGET" or visibility == "EITHER") and rangeResult ~= nil))
    frame:SetShown(visible)
    if not visible then return end
    local total, remaining = duration or WeaponSpeed() or 2.5, 0
    local windup = math.min(total, Windup())
    local running = expires ~= nil or (preview and not active)
    if preview and not active then remaining = total - (GetTime() % total)
    elseif expires then remaining = math.min(total, math.max(0, expires - GetTime())) end

    local winding = running and windup > 0 and (opening or (remaining < total and remaining <= windup))
    local centered = db.barMode == "YAHT"
    local moving = false
    local now = GetTime()
    if winding and not (preview and not active) then
        local speed = GetUnitSpeed and GetUnitSpeed("player")
        local playerMoving = ReadRange(IsPlayerMoving)
        moving = movementEvent == true or playerMoving == true
            or (PublicNumber(speed) and speed > 0) or ReadRange(IsFalling) == true
        if moving then
            wasMoving, stationarySince = true, nil
            ResetLateStop()
        elseif wasMoving then
            wasMoving, stationarySince = nil, now
            if not opening then
                lateSpeed = SpeedKey(WeaponSpeed() or total)
                local entry = LateEntry(lateSpeed)
                lateStop, lateEstimate = now, entry and entry.estimate
                lateBlocked = lateSpeed ~= SpeedKey(total)
                if lateBlocked then lateEstimate = nil end
                if debugTrace then
                    Trace("LATE_ESTIMATE", string.format("%.3fs samples=%d", lateEstimate or windup, entry and #entry.samples or 0))
                end
            end
        end
    else
        wasMoving, stationarySince = nil, nil
        ResetLateStop()
    end
    if lateStop then
        local currentSpeed = SpeedKey(WeaponSpeed())
        if currentSpeed and currentSpeed ~= lateSpeed then
            lateBlocked, lateEstimate = true, nil
        elseif not lateBlocked and LateSampleBlocked() then
            lateBlocked = true
        end
    end
    local fill, displayTime, waitingRelease = 0, remaining, false
    if running then
        if winding then
            local draw = math.max(0, windup - remaining)
            if moving then
                draw, displayTime = 0, 0
            elseif lateStop and lateEstimate then
                local elapsed = math.max(0, now - lateStop)
                draw = windup * math.min(1, elapsed / lateEstimate)
                displayTime = math.max(0, lateEstimate - elapsed)
            elseif stationarySince then
                draw = math.min(draw, now - stationarySince)
                displayTime = windup - draw
            end
            -- The estimate can fill the bar; only PLAYER_SWING starts recovery.
            fill = math.min(draw / windup, 1)
            waitingRelease = not moving and displayTime <= 0
            if not moving and not waitingRelease then displayTime = math.max(.1, displayTime) end
        else
            fill = math.max(0, (remaining - windup) / math.max(.001, total - windup))
        end
    end
    if debugTrace and expires and not (preview and not active) then
        if winding and not debugPhase then
            debugPhase = true
            Trace("WINDUP", string.format("moving=%s estimate=%.3fs remaining=%.3fs",
                tostring(moving), windup, remaining))
        end
        if moving then debugFull = nil end
        if waitingRelease and not debugFull then
            debugFull = now
            Trace("FULL", debugStop and string.format("since_stop=%.3fs", now - debugStop))
        end
    end
    frame:SetAlpha(db.opacity * (moving and db.movementOpacity or 1))
    local color = winding and db.windupColor or db.barColor
    frame.bar:GetStatusBarTexture():SetDesaturated(true)
    frame.bar:SetStatusBarColor(unpack(color))
    frame.bar:SetValue(centered and 0 or fill)
    local uv = frame.centerUV
    local function U(i, t) return uv[i] + (uv[i+4] - uv[i]) * t end
    for i, half in ipairs(frame.centerFills) do
        local shown = centered and fill > 0
        half:SetShown(shown)
        if shown then
            local left, right = .5, .5
            if i == 1 then left = left - fill / 2 else right = right + fill / 2 end
            half:SetWidth(math.max(.01, frame.bar:GetWidth() * fill / 2))
            half:SetTexCoord(U(1, left), U(2, left), U(3, left), U(4, left),
                U(1, right), U(2, right), U(3, right), U(4, right))
            half:SetVertexColor(unpack(color))
        end
    end
    if not db.shotFlash then
        shotFlashAt = nil
        frame.shotFlash:Hide()
    elseif shotFlashAt then
        local remainingFlash = math.max(0, 1 - (now - shotFlashAt) / SHOT_FLASH_DURATION)
        local glow = frame.shotFlash
        if remainingFlash > 0 then
            -- Ease out so the bright part of the flash moves past the rim quickly.
            local spread = SHOT_FLASH_SPREAD * (1 - remainingFlash ^ 3)
            glow:SetPoint("TOPLEFT", frame.bar, "TOPLEFT", -spread, spread)
            glow:SetPoint("BOTTOMRIGHT", frame.bar, "BOTTOMRIGHT", spread, -spread)
            glow:SetAlpha(remainingFlash)
            glow:Show()
        else
            glow:Hide()
            shotFlashAt = nil
        end
    end
    frame.pip:SetShown(not centered and fill > 0)
    if waitingRelease then frame.time:SetText("…")
    else frame.time:SetFormattedText("%.1f", displayTime) end
    AlignText()
end

function module:OnEnable()
    if Hunter() then CheckRangedWeapon() end
    CreateBar(); NativeStyle(); ApplyLayout(); UpdateDisplay()
    if Hunter() and C_Timer and C_Timer.NewTicker and not rangeTicker then
        rangeTicker = C_Timer.NewTicker(.2, function()
            local mode = VisibilityMode()
            if not frame:IsShown() and (mode == "TARGET" or mode == "EITHER")
                and ReadRange(UnitCanAttack, "player", "target") then
                UpdateRange()
                UpdateDisplay()
            end
        end)
    end
end
function module:OnDisable()
    if rangeTicker then rangeTicker:Cancel(); rangeTicker = nil end
    ResetLateStop()
    active, duration, expires, preview, opening = nil, nil, nil, nil, nil
    StopDragging()
    if frame then frame:Hide() end
end
module:RegisterEvent("PLAYER_SWING", function(_, _, swingDuration, swingType)
    local ranged = Enum and Enum.PlayerSwingType and Enum.PlayerSwingType.Ranged or 2
    if not Hunter() or not PublicNumber(swingType) or swingType ~= ranged
        or not PublicNumber(swingDuration) or swingDuration <= 0 then return end
    CheckRangedWeapon()
    local now = GetTime()
    local currentSpeed = SpeedKey(WeaponSpeed())
    if lateStop and not lateBlocked and (not currentSpeed or currentSpeed == lateSpeed)
        and not LateSampleBlocked() then
        LearnLateTime(lateSpeed, now - lateStop)
    end
    ResetLateStop()
    if debugTrace then
        local details = {}
        if debugLastShot then details[#details+1] = string.format("since_shot=%.3fs", now - debugLastShot) end
        if debugStop then details[#details+1] = string.format("since_stop=%.3fs", now - debugStop) end
        if debugFull then details[#details+1] = string.format("since_full=%.3fs", now - debugFull) end
        Trace("SHOT", table.concat(details, " "))
        debugLastShot, debugStop, debugPhase, debugFull = now, nil, nil, nil
    end
    shotFlashAt = module:GetDB().shotFlash and now or nil
    duration = WeaponSpeed() or swingDuration
    opening, wasMoving, stationarySince, expires, active = nil, nil, nil, GetTime() + duration, true
    CreateBar(); ApplyLayout(); UpdateDisplay()
end)
module:RegisterEvent("START_AUTOREPEAT_SPELL", function()
    if not Hunter() then return end
    ResetLateStop()
    active = true
    duration = WeaponSpeed() or 2.5
    if debugTrace then
        debugStop, debugPhase, debugFull, debugLastShot = nil, nil, nil, nil
        Trace("AUTO_START", string.format("cycle=%.3fs", duration))
    end
    opening, wasMoving, stationarySince = true, nil, nil
    expires = GetTime() + math.min(duration, Windup())
    CreateBar(); ApplyLayout(); UpdateDisplay()
end)
module:RegisterEvent("STOP_AUTOREPEAT_SPELL", function()
    ResetLateStop()
    if debugTrace then Trace("AUTO_STOP") end
    active, duration, expires, opening = nil, nil, nil, nil
    UpdateDisplay()
end)
module:RegisterEvent("PLAYER_STARTED_MOVING", function()
    movementEvent = true
    if debugTrace and active then
        debugStop, debugFull = nil, nil
        Trace("MOVE_START")
    end
    UpdateDisplay()
end)
module:RegisterEvent("PLAYER_STOPPED_MOVING", function()
    movementEvent = false
    if debugTrace and active then
        debugStop = GetTime()
        local _, _, _, worldLatency
        if GetNetStats then _, _, _, worldLatency = GetNetStats() end
        Trace("MOVE_STOP", string.format("phase=%s world_ms=%s",
            debugPhase and "red" or "grey", PublicNumber(worldLatency) and tostring(worldLatency) or "n/a"))
    end
    UpdateDisplay()
end)
module:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    ResetLateStop()
    movementEvent = nil
    if Hunter() then CheckRangedWeapon() end
    active, duration, expires, opening = nil, nil, nil, nil
    CreateBar(); ApplyLayout(); UpdateDisplay()
end)
module:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function(_, _, slot)
    if slot ~= RANGED_SLOT or not Hunter() then return end
    ResetLateStop()
    CheckRangedWeapon()
    UpdateDisplay()
end)
module:RegisterEvent("PLAYER_REGEN_DISABLED", function() UpdateDisplay() end)
module:RegisterEvent("PLAYER_REGEN_ENABLED", function() UpdateDisplay() end)
module:RegisterEvent("PLAYER_TARGET_CHANGED", function()
    if lateStop then lateBlocked = true end
    if frame then UpdateRange() end
    UpdateDisplay()
end)
module:RegisterEvent("PLAYER_DEAD", function()
    ResetLateStop()
    active, duration, expires, opening = nil, nil, nil, nil
    UpdateDisplay()
end)

function module:CreateOptionsPanel(parentCategory)
    if self.settingsPanel or not parentCategory then return end
    local panel = CreateFrame("Frame")
    panel:Hide(); panel:SetSize(700, 560)
    local scroll = CreateFrame("ScrollFrame", nil, panel)
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -34, 12)
    yTools.UI.ScrollFrame(scroll, panel)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(666, 730)
    scroll:SetScrollChild(content)
    scroll:HookScript("OnSizeChanged", function(_, width) content:SetWidth(math.max(1, width)) end)
    local function Label(text, x, y, font)
        local label = content:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
        label:SetPoint("TOPLEFT", x, y); label:SetText(text)
        return label
    end
    Label(L.HUNTERBAR_TITLE, 32, -24, "GameFontNormalLarge")
    local details = Label(L.HUNTERBAR_DESCRIPTION, 32, -64, "GameFontHighlight")
    details:SetWidth(620); details:SetJustifyH("LEFT")
    local refreshers = {}
    local function Changed() ApplyLayout(); UpdateDisplay() end
    local function Check(label, key, x, y)
        local button = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
        yTools.UI.Check(button); button:SetPoint("TOPLEFT", x, y)
        local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", button, "RIGHT", 5, 0); text:SetText(label)
        button:SetScript("OnClick", function() module:GetDB()[key] = button:GetChecked() == true; Changed() end)
        refreshers[#refreshers+1] = function() button:SetChecked(module:GetDB()[key]); button:SetEnabled(module:IsEnabled()) end
        return button, text
    end
    local enabled, enabledLabel = Check(L.MODULE_OPTIONS_ENABLE, "unused", 400, -18)
    table.remove(refreshers)
    enabledLabel:SetFontObject(GameFontHighlight)
    enabledLabel:ClearAllPoints(); enabledLabel:SetPoint("TOPRIGHT", content, "TOPRIGHT", -32, -22)
    enabled:ClearAllPoints(); enabled:SetPoint("RIGHT", enabledLabel, "LEFT", -5, 0)
    enabled:SetScript("OnClick", function()
        if enabled:GetChecked() then module:Enable() else module:Disable() end
        panel.RefreshForm()
    end)
    Label(L.HUNTERBAR_ATTACH, 32, -125)
    local dropdown = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("TOPLEFT", 32, -147); dropdown:SetWidth(240)
    yTools.UI.DropdownLayout(dropdown)
    local choices = {{"FREE", L.HUNTERBAR_FREE}, {"TOP", L.HUNTERBAR_TOP}, {"BOTTOM", L.HUNTERBAR_BOTTOM}}
    dropdown:SetupMenu(function(_, root)
        for _, choice in ipairs(choices) do
            local value, name = choice[1], choice[2]
            root:CreateRadio(name, function() return module:GetDB().attach == value end, function()
                StopDragging(); module:GetDB().attach = value; panel.RefreshForm(); Changed()
            end)
        end
    end)
    refreshers[#refreshers+1] = function()
        for _, choice in ipairs(choices) do
            if choice[1] == module:GetDB().attach then yTools.UI.DropdownLabel(dropdown, choice[2]) end
        end
        dropdown:SetEnabled(module:IsEnabled())
    end
    Check(L.HUNTERBAR_FIT_WIDTH, "fitWidth", 342, -144)
    local function Number(label, key, x, y, low, high)
        Label(label, x, y)
        local input = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
        input:SetPoint("TOPLEFT", x+6, y-23); input:SetSize(110, 25)
        input:SetAutoFocus(false); input:SetMaxLetters(8)
        local function Save()
            local value = tonumber((input:GetText():gsub(",", ".")))
            if PublicNumber(value) then module:GetDB()[key] = math.max(low, math.min(high, value)); Changed() end
            input:SetText(tostring(module:GetDB()[key]))
        end
        input:SetScript("OnEnterPressed", function() Save(); input:ClearFocus() end)
        input:SetScript("OnEditFocusLost", Save)
        input:SetScript("OnEscapePressed", function() input:SetText(tostring(module:GetDB()[key])); input:ClearFocus() end)
        refreshers[#refreshers+1] = function() input:SetText(tostring(module:GetDB()[key])); input:SetEnabled(module:IsEnabled()) end
    end
    Number(L.HUNTERBAR_WIDTH, "width", 32, -195, 60, 1200)
    Number(L.HUNTERBAR_HEIGHT, "height", 342, -195, 12, 80)
    Number(L.HUNTERBAR_GAP, "gap", 32, -265, 0, 100)
    local function Choice(label, key, x, y, positions, getValue, width)
        getValue = getValue or function() return module:GetDB()[key] end
        Label(label, x, y)
        local button = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
        button:SetPoint("TOPLEFT", x, y - 22); button:SetWidth(width or 180)
        yTools.UI.DropdownLayout(button)
        button:SetupMenu(function(_, root)
            for _, choice in ipairs(positions) do
                local value, text = choice[1], choice[2]
                root:CreateRadio(text, function() return getValue() == value end, function()
                    module:GetDB()[key] = value; panel.RefreshForm(); Changed()
                end)
            end
        end)
        refreshers[#refreshers+1] = function()
            for _, choice in ipairs(positions) do
                if getValue() == choice[1] then yTools.UI.DropdownLabel(button, choice[2]) end
            end
            button:SetEnabled(module:IsEnabled())
        end
    end
    local positions = {{"LEFT", L.HUNTERBAR_LEFT}, {"CENTER", L.HUNTERBAR_CENTER},
        {"RIGHT", L.HUNTERBAR_RIGHT}, {"NONE", L.HUNTERBAR_NONE}}
    Choice(L.HUNTERBAR_RANGE_POSITION, "rangeAlign", 32, -330, positions)
    Choice(L.HUNTERBAR_TIMER_POSITION, "timerAlign", 342, -330, positions)
    local rows = {{"ON", L.HUNTERBAR_ON_BAR}, {"ABOVE", L.HUNTERBAR_ABOVE}, {"BELOW", L.HUNTERBAR_BELOW}}
    Choice(L.HUNTERBAR_RANGE_VERTICAL, "rangeVertical", 32, -395, rows)
    Choice(L.HUNTERBAR_TIMER_VERTICAL, "timerVertical", 342, -395, rows)
    Choice(L.HUNTERBAR_LAYOUT, "barMode", 32, -530, {{ "DEFAULT", L.HUNTERBAR_STANDARD }, {"YAHT", L.HUNTERBAR_CENTERED}})
    Number(L.HUNTERBAR_MOVEMENT_OPACITY, "movementOpacity", 342, -530, 0, 1)
    Choice(L.HUNTERBAR_SHOW_WHEN, "visibility", 32, -460, {
        {"ALWAYS", L.HUNTERBAR_ALWAYS_SHOW},
        {"COMBAT", L.HUNTERBAR_ALWAYS_SHOW_COMBAT},
        {"TARGET", L.HUNTERBAR_ALWAYS_SHOW_TARGET},
        {"EITHER", L.HUNTERBAR_SHOW_COMBAT_OR_TARGET},
    }, VisibilityMode, 240)
    Check(L.HUNTERBAR_SHOT_FLASH, "shotFlash", 342, -482)
    Number(L.HUNTERBAR_OPACITY, "opacity", 32, -600, .1, 1)
    local function Color(label, key, x, y)
        Label(label, x, y)
        local button = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        button:SetSize(56, 24); button:SetPoint("TOPLEFT", x, y-23)
        local swatch = button:CreateTexture(nil, "OVERLAY")
        swatch:SetPoint("TOPLEFT", 5, -4); swatch:SetPoint("BOTTOMRIGHT", -5, 4)
        local function Refresh() swatch:SetColorTexture(unpack(module:GetDB()[key])) end
        button:SetScript("OnClick", function()
            if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then return end
            local color = module:GetDB()[key]
            local original = {unpack(color)}
            local function Set(r, g, b) module:GetDB()[key] = {r, g, b}; Refresh(); Changed() end
            ColorPickerFrame:SetupColorPickerAndShow({r=color[1], g=color[2], b=color[3], hasOpacity=false,
                swatchFunc=function() Set(ColorPickerFrame:GetColorRGB()) end,
                cancelFunc=function() Set(unpack(original)) end})
        end)
        refreshers[#refreshers+1] = function() Refresh(); button:SetEnabled(module:IsEnabled()) end
    end
    Color(L.HUNTERBAR_BAR_COLOR, "barColor", 342, -600)
    Color(L.HUNTERBAR_WINDUP_COLOR, "windupColor", 500, -600)
    local hint = Label(L.HUNTERBAR_DRAG_HINT, 32, -670, "GameFontHighlightSmall")
    hint:SetWidth(620); hint:SetJustifyH("LEFT")
    panel.RefreshForm = function()
        enabled:SetChecked(module:IsEnabled())
        for _, refresh in ipairs(refreshers) do refresh() end
        preview = module:IsEnabled() and panel:IsShown()
        CreateBar(); Changed()
    end
    panel:SetScript("OnShow", panel.RefreshForm)
    panel:SetScript("OnHide", function() preview = false; StopDragging(); UpdateDisplay() end)
    self.settingsPanel = panel
    self.settingsCategory = Settings.RegisterCanvasLayoutSubcategory(parentCategory, panel, L.HUNTERBAR_TITLE)
end
module:RegisterSlashCommand("hunterbar", function(_, arguments)
    if (arguments or ""):lower():match("^%s*debug%s*$") then
        if not module:IsEnabled() or not Hunter() then return end
        debugTrace = not debugTrace
        debugStart, debugStop, debugPhase, debugFull, debugLastShot = GetTime(), nil, nil, nil, nil
        Trace(debugTrace and "DEBUG_ON" or "DEBUG_OFF")
        return
    end
    yTools:InitializeOptions()
    module:CreateOptionsPanel(yTools.optionsCategory)
    local category = module.settingsCategory
    if category then yTools:OpenSettingsCategory(category.GetID and category:GetID() or category.ID) end
end, L.HUNTERBAR_COMMAND_HELP)
yTools.commands.hunterbar.allowDisabled = true
