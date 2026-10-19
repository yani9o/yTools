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
-- Double right-click in the world with a fishing rod equipped to cast Fishing.
if not _G.yTools then
    return
end

local fishingModule = _G.yTools:RegisterModule("Fishing", {
    title = L.AUTOMATION_FISHING,
    description = L.DOUBLE_RIGHT_CLICK_IN_THE_WORLD_WITH_A_FISHING_ROD_EQUIPPED_TO_CAST_FISHING_DOES_NOT,
    defaultEnabled = true,
    defaults = { enhanceSounds = false, doubleVolume = true },
})

if not fishingModule then
    return
end

local DOUBLE_CLICK = 0.35
local MAX_MOVEMENT = 8 -- Physical cursor pixels; excludes camera drags.
local FISHING_SPELLS = { 7620, 7731, 7732, 18248, 33095, 51294, 88868, 131474 }

local owner, firstClick, pressed, armed
local generation = 0
local pendingClear = false
local worker = CreateFrame("Frame")

local function EnsureOwner()
    if owner or InCombatLockdown() then
        return
    end

    owner = CreateFrame("Frame", "yToolsFishingBindingOwner", UIParent, "SecureHandlerStateTemplate")

    -- Secure cleanup can remove the temporary binding when combat begins.
    owner:SetAttribute("_onstate-combat", [[
        if newstate == "combat" then self:ClearBindings() end
    ]])
    RegisterStateDriver(owner, "combat", "[combat]combat;idle")
end

local function Clear()
    generation = generation + 1
    firstClick, pressed, armed = nil, nil, nil
    worker:SetScript("OnUpdate", nil)

    if owner then
        if InCombatLockdown() then
            pendingClear = true
        else
            ClearOverrideBindings(owner)
            pendingClear = false
        end
    end
end

local function HasRod()
    local item = GetInventoryItemID("player", 16)
    if not item then
        return false
    end

    local info = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if not info then
        return false
    end

    local _, _, _, _, _, class, subclass = info(item)
    return class == 2 and subclass == 20
end

local function FishingName()
    for _, id in ipairs(FISHING_SPELLS) do
        local playerSpell = IsPlayerSpell and IsPlayerSpell(id)
        local spellKnown = IsSpellKnown and IsSpellKnown(id)

        if playerSpell or spellKnown then
            if C_Spell and C_Spell.GetSpellName then
                return C_Spell.GetSpellName(id)
            end
            if GetSpellInfo then
                return GetSpellInfo(id)
            end
        end
    end
end

local function InWorld()
    if GetMouseFoci then
        local foci = GetMouseFoci()
        -- This client can return an empty focus list over the world background.
        return not foci or #foci == 0 or foci[1] == WorldFrame
    end

    local focus = GetMouseFocus and GetMouseFocus()
    return focus == nil or focus == WorldFrame
end

local function Eligible()
    if not fishingModule:IsEnabled() or InCombatLockdown() then
        return false
    end
    if not HasRod() or not InWorld() then
        return false
    end
    if IsMouseButtonDown("LeftButton") or IsModifierKeyDown() then
        return false
    end
    if UnitExists("mouseover") or UnitIsDeadOrGhost("player") then
        return false
    end
    if UnitCastingInfo("player") or UnitChannelInfo("player") then
        return false
    end
    if GetNumLootItems() > 0 or IsPlayerMoving() or IsMounted() then
        return false
    end

    -- Preserve normal interactions with world objects, including the bobber.
    if GameTooltip and GameTooltip:IsShown() and GameTooltip:GetOwner() == WorldFrame then
        return false
    end

    return true
end

local function Moved(click)
    local x, y = GetCursorPosition()
    return math.abs(x - click.x) > MAX_MOVEMENT or math.abs(y - click.y) > MAX_MOVEMENT
end

local function MouseDown(button)
    if not HasRod() then
        return
    end

    if button ~= "RightButton" or not Eligible() then
        Clear()
        return
    end

    EnsureOwner()

    local now = GetTime()
    local x, y = GetCursorPosition()
    local previous = firstClick
    pressed = { time = now, x = x, y = y }
    firstClick = nil

    if not previous then
        return
    end
    if now - previous.time > DOUBLE_CLICK or now - previous.time < 0.04 or Moved(previous) then
        return
    end

    local spell = FishingName()
    if not owner or not spell then
        return
    end

    generation = generation + 1
    armed = pressed

    -- Let WoW execute Fishing through its binding system on hardware release.
    SetOverrideBindingSpell(owner, true, "BUTTON2", spell)

    local thisGeneration = generation
    worker:SetScript("OnUpdate", function()
        if armed and (InCombatLockdown() or Moved(armed) or GetTime() - armed.time > DOUBLE_CLICK) then
            Clear()
        end
    end)

    C_Timer.After(DOUBLE_CLICK + 0.1, function()
        if generation == thisGeneration then
            Clear()
        end
    end)
end

local function MouseUp(button)
    if not HasRod() then
        return
    end

    if button ~= "RightButton" then
        return
    end

    if armed then
        local thisGeneration = generation
        worker:SetScript("OnUpdate", nil)
        if IsMouselooking() then
            MouselookStop()
        end

        -- Allow the native release binding to execute before removing it.
        C_Timer.After(0, function()
            if generation == thisGeneration then
                Clear()
            end
        end)
        return
    end

    if pressed and GetTime() - pressed.time <= DOUBLE_CLICK and not Moved(pressed) and Eligible() then
        firstClick = pressed
    else
        firstClick = nil
    end
    pressed = nil
end

-- Volume changes are temporary and are saved before applying so /reload can
-- recover them too. The master volume is doubled while fishing, capped at 1.
local SOUND_LEVELS = {
    Sound_MasterVolume = "double",
    Sound_EnableSFX = 1,
    Sound_EnableSoundWhenGameIsInBG = 1,
    Sound_SFXVolume = 1,
    Sound_MusicVolume = "quiet",
    Sound_AmbienceVolume = "quiet",
    Sound_DialogVolume = "quiet",
}
local soundActive = false
local function ReadSoundCVar(name)
    local getter = C_CVar and C_CVar.GetCVar or GetCVar
    local ok, value = pcall(getter, name)
    return ok and value or nil
end
local function WriteSoundCVar(name, value)
    local setter = C_CVar and C_CVar.SetCVar or SetCVar
    return pcall(setter, name, value)
end
local function SameSoundValue(a, b)
    local first, second = tonumber(a), tonumber(b)
    return a == b or (first ~= nil and second ~= nil and math.abs(first - second) < 0.000001)
end
local function RestoreSounds()
    local db = fishingModule:GetDB()
    for name, saved in pairs(db.soundRestore or {}) do
        -- Respect a manual change made through the sound options while fishing.
        if not SameSoundValue(ReadSoundCVar(name), saved.applied)
            or WriteSoundCVar(name, saved.original) then
            db.soundRestore[name] = nil
        end
    end
    if db.soundRestore and not next(db.soundRestore) then db.soundRestore = nil end
    soundActive = false
end
local function IsFishingChannel()
    if InCombatLockdown() then return false end
    local ok, fishing = pcall(function()
        local name, _, _, _, _, _, _, spellID = UnitChannelInfo("player")
        if not name then return false end
        for _, id in ipairs(FISHING_SPELLS) do if spellID == id then return true end end
        return name == FishingName()
    end)
    return ok and fishing == true
end
local function UpdateSounds()
    local db = fishingModule:GetDB()
    if not fishingModule:IsEnabled() or not db.enhanceSounds or not IsFishingChannel() then
        RestoreSounds()
        return
    end
    if soundActive then return end
    RestoreSounds()
    db.soundRestore = db.soundRestore or {}
    for name, level in pairs(SOUND_LEVELS) do
        local original = ReadSoundCVar(name)
        local desired = level == "quiet" and tonumber(original) and tonumber(original) * 0.1 or level
        if level == "double" and tonumber(original) then
            desired = math.min(1, math.max(0, tonumber(original) * 2))
        end
        if original ~= nil and (name ~= "Sound_MasterVolume" or db.doubleVolume)
            and desired ~= "quiet" and not SameSoundValue(original, desired) then
            db.soundRestore[name] = { original = original, applied = desired }
            if not WriteSoundCVar(name, desired) then db.soundRestore[name] = nil end
        end
    end
    soundActive = true
end

function fishingModule:OnEnable()
    EnsureOwner()
    Clear()
    RestoreSounds()
    UpdateSounds()
end

function fishingModule:OnDisable()
    Clear()
    RestoreSounds()
end

fishingModule:RegisterEvent("GLOBAL_MOUSE_DOWN", function(_, _, button)
    MouseDown(button)
end)

fishingModule:RegisterEvent("GLOBAL_MOUSE_UP", function(_, _, button)
    MouseUp(button)
end)

fishingModule:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function(_, _, slot)
    if slot == 16 then
        Clear()
    end
end)

fishingModule:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    EnsureOwner()
    Clear()
end)

fishingModule:RegisterEvent("SPELLS_CHANGED", function()
    Clear()
end)

-- Keep cleanup independent of the module's enabled event subscriptions.
worker:RegisterEvent("PLAYER_REGEN_DISABLED")
worker:RegisterEvent("PLAYER_REGEN_ENABLED")
worker:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        Clear()
    else
        if fishingModule:IsEnabled() then
            EnsureOwner()
        end
        if pendingClear then
            Clear()
        end
    end
end)

-- Sound cleanup remains subscribed even when this module is disabled.
local soundEvents = CreateFrame("Frame")
for _, event in ipairs({ "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_CHANNEL_STOP", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_DEAD" }) do
    soundEvents:RegisterEvent(event)
end
soundEvents:SetScript("OnEvent", function(_, event, unit)
    if event:find("^UNIT_") and unit ~= "player" then return end
    if event == "PLAYER_LOGOUT" or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_DEAD" then
        RestoreSounds()
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        RestoreSounds()
    else
        UpdateSounds()
    end
end)

function fishingModule:CreateOptionsPanel(parentCategory)
    if self.settingsPanel or not parentCategory or not Settings
        or not Settings.RegisterCanvasLayoutSubcategory then return end
    local panel = CreateFrame("Frame")
    panel:SetSize(700, 560)
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 32, -24)
    title:SetText(L.FISHING_OPTIONS)
    local details = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    details:SetPoint("TOPLEFT", 32, -64)
    details:SetWidth(600)
    details:SetJustifyH("LEFT")
    details:SetText(L.DOUBLE_RIGHT_CLICK_IN_THE_WORLD_WITH_A_FISHING_ROD_EQUIPPED_TO_CAST_FISHING_DOES_NOT)
    local enabled = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    enabled:SetPoint("TOPLEFT", 400, -18)
    local enabledLabel = enabled:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    enabledLabel:SetPoint("LEFT", enabled, "RIGHT", 2, 0)
    enabledLabel:SetText(L.MODULE_OPTIONS_ENABLE)
    enabledLabel:ClearAllPoints(); enabledLabel:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -32, -22)
    enabled:ClearAllPoints(); enabled:SetPoint("RIGHT", enabledLabel, "LEFT", -5, 0)
    enabled:SetScript("OnClick", function(owner)
        if owner:GetChecked() then self:Enable() else self:Disable() end
        panel.RefreshForm()
    end)
    local sounds = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    sounds:SetPoint("TOPLEFT", 32, -120)
    local soundsLabel = sounds:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    soundsLabel:SetPoint("LEFT", sounds, "RIGHT", 2, 0)
    soundsLabel:SetText(L.ENHANCE_FISHING_SOUNDS)
    sounds:SetScript("OnClick", function(owner)
        self:GetDB().enhanceSounds = owner:GetChecked() == true
        UpdateSounds()
        panel.RefreshForm()
    end)
    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", 58, -156)
    description:SetWidth(560)
    description:SetJustifyH("LEFT")
    description:SetText(L.FISHING_SOUNDS_DESCRIPTION)
    local volume = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    volume:SetPoint("TOPLEFT", description, "BOTTOMLEFT", -2, -12)
    local volumeLabel = volume:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    volumeLabel:SetPoint("LEFT", volume, "RIGHT", 2, 0)
    volumeLabel:SetText(L.DOUBLE_FISHING_VOLUME)
    volume:SetScript("OnClick", function(owner)
        self:GetDB().doubleVolume = owner:GetChecked() == true
        RestoreSounds()
        UpdateSounds()
    end)
    panel.RefreshForm = function()
        enabled:SetChecked(self:IsEnabled())
        sounds:SetChecked(self:GetDB().enhanceSounds == true)
        sounds:SetShown(self:IsEnabled())
        description:SetShown(self:IsEnabled())
        volume:SetChecked(self:GetDB().doubleVolume == true)
        volume:SetShown(self:IsEnabled())
        volume:SetEnabled(self:GetDB().enhanceSounds == true)
    end
    panel:SetScript("OnShow", panel.RefreshForm)
    self.settingsPanel = panel
    self.settingsCategory = Settings.RegisterCanvasLayoutSubcategory(parentCategory, panel, L.FISHING_OPTIONS)
    panel.RefreshForm()
end

local yTools = _G.yTools
fishingModule:RegisterSlashCommand("fishing", function()
    yTools:InitializeOptions()
    fishingModule:CreateOptionsPanel(yTools.optionsCategory)
    local category = fishingModule.settingsCategory
    if category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(category.GetID and category:GetID() or category.ID)
    end
end, L.FISHING_COMMAND_HELP)
-- Options must remain reachable when this module is disabled.
yTools.commands.fishing.allowDisabled = true
