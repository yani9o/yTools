local yTools = _G.yTools
local L = yTools.L
local module = yTools:RegisterModule("Leylines", {
    title = L.LEYLINES_MODULE,
    description = L.LEYLINES_DESCRIPTION,
    characterDefault = function()
        local name, race = UnitRace("player")
        if (not issecretvalue or not issecretvalue(race)) and race == "Skyborne" then return true end
        if (not issecretvalue or not issecretvalue(name)) and name == "Skyborne" then return true end
        -- Read Leyline is the Skyborne racial; also handle localized or changed race tokens.
        local known = IsPlayerSpell and IsPlayerSpell(1259705)
        return (not issecretvalue or not issecretvalue(known)) and known == true
    end,
})
local template = "yToolsLeylinePinTemplate"
local provider, mixed
local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end

yToolsLeylinePinMixin = {}
function yToolsLeylinePinMixin:OnLoad()
    local icon = self:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetAtlas("MagePortalAlliance")
end
function yToolsLeylinePinMixin:OnAcquired(x, y)
    self:UseFrameLevelType("PIN_FRAME_LEVEL_WAYPOINT_LOCATION")
    self:SetScalingLimits(1, 1, 1)
    self:SetPosition(x, y)
end
-- These are display-only pins and never configure mouse button passthrough.
function yToolsLeylinePinMixin:CheckMouseButtonPassthrough() end

local Provider = {}
function Provider:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate(template)
end
function Provider:RefreshAllData()
    if InCombat() then return end
    self:RemoveAllData()
    if not module:IsEnabled() then return end
    local map = self:GetMap()
    local mapID = map:GetMapID()
    local points = mapID and yTools.LeylineLocations[mapID]
    if not points then return end
    for _, point in ipairs(points) do
        map:AcquirePin(template, point[1], point[2])
    end
end
Provider.OnMapChanged = Provider.RefreshAllData

local function Refresh()
    if InCombat() or not WorldMapFrame then return end
    if not module:IsEnabled() then
        if provider then WorldMapFrame:RemoveDataProvider(provider); provider = nil end
        return
    end
    if not MapCanvasDataProviderMixin or not MapCanvasPinMixin then return end
    if not mixed then
        yToolsLeylinePinMixin = CreateFromMixins(MapCanvasPinMixin, yToolsLeylinePinMixin)
        mixed = true
    end
    if not provider then
        provider = CreateFromMixins(MapCanvasDataProviderMixin, Provider)
        WorldMapFrame:AddDataProvider(provider)
    end
    provider:RefreshAllData()
end
function module:OnEnable() Refresh() end
function module:OnDisable()
    if provider and InCombat() then
        for pin in provider:GetMap():EnumeratePinsByTemplate(template) do pin:Hide() end
    else Refresh() end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_REGEN_ENABLED")
loader:RegisterEvent("PLAYER_REGEN_DISABLED")
loader:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_REGEN_DISABLED" then
        if provider then
            for pin in provider:GetMap():EnumeratePinsByTemplate(template) do pin:Hide() end
        end
    elseif event == "PLAYER_REGEN_ENABLED" or name == "Blizzard_WorldMap" then
        Refresh()
    end
end)
