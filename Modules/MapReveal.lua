local yTools = _G.yTools
local L = yTools.L
local module = yTools:RegisterModule("MapReveal", {
    title = L.MAP_REVEAL_MODULE,
    description = L.MAP_REVEAL_DESCRIPTION,
    defaultEnabled = true,
})

local providers = {}
local function AreaKey(width, height, x, y)
    return table.concat({width, height, x, y}, ":")
end
local function TileSize(size, tile, index, count)
    local pixels = index < count and tile or size % tile
    if pixels == 0 then pixels = tile end
    local fileSize = 16
    while fileSize < pixels do fileSize = fileSize * 2 end
    return pixels, fileSize
end
local Provider = {}
function Provider:RemoveAllData()
    for _, texture in ipairs(self.textures or {}) do
        texture:Hide()
        texture.grey:Hide()
    end
    self.used = 0
end
function Provider:OnAdded(map)
    MapCanvasDataProviderMixin.OnAdded(self, map)
    self.textures, self.used = {}, 0
    self.frame = CreateFrame("Frame", nil, map:GetCanvas())
    self.frame:SetAllPoints()
    self.frame:EnableMouse(false)
end
function Provider:OnRemoved(map)
    self:RemoveAllData()
    self.frame:Hide()
    MapCanvasDataProviderMixin.OnRemoved(self, map)
end
function Provider:OnGlobalAlphaChanged()
    self.frame:SetAlpha(self:GetMap():GetGlobalAlpha() or 1)
end
function Provider:RefreshAllData()
    self:RemoveAllData()
    if not module:IsEnabled() then return end
    local map = self:GetMap()
    local mapID = map:GetMapID()
    local art = mapID and C_Map.GetMapArtID(mapID)
    local areas = art and yTools.MapRevealData[art]
    if not areas then return end
    local layerIndex = map:GetCanvasContainer():GetCurrentLayerIndex()
    local layers = C_Map.GetMapArtLayers(mapID)
    local layer = layers and layers[layerIndex]
    if not layer or not layer.tileWidth or not layer.tileHeight then return end
    self.layerIndex = layerIndex
    local known = {}
    for _, area in ipairs(C_MapExplorationInfo.GetExploredMapTextures(mapID) or {}) do
        -- Mouseover highlights do not represent permanently explored terrain.
        if not area.isShownByMouseOver then
            known[AreaKey(area.textureWidth, area.textureHeight, area.offsetX, area.offsetY)] = true
        end
    end
    local levels = map:GetPinFrameLevelsManager()
    self.frame:SetFrameLevel(levels:GetValidFrameLevel("PIN_FRAME_LEVEL_MAP_EXPLORATION") - 1)
    self:OnGlobalAlphaChanged()
    for _, area in ipairs(areas) do
        local width, height, x, y = area[1], area[2], area[3], area[4]
        if not known[AreaKey(width, height, x, y)] then
            local columns, rows = math.ceil(width / layer.tileWidth), math.ceil(height / layer.tileHeight)
            for row = 1, rows do
                local h, fh = TileSize(height, layer.tileHeight, row, rows)
                for column = 1, columns do
                    local file = area[4 + (row - 1) * columns + column]
                    if file then
                        self.used = self.used + 1
                        local texture = self.textures[self.used]
                        if not texture then
                            texture = self.frame:CreateTexture(nil, "ARTWORK")
                            self.textures[self.used] = texture
                            map:AddMaskableTexture(texture)
                            -- Keep the map art opaque. A separate grey layer
                            -- follows the tile's alpha, including irregular edges.
                            texture.grey = self.frame:CreateTexture(nil, "ARTWORK", nil, 1)
                            texture.grey:SetAllPoints(texture)
                            texture.grey:SetColorTexture(0.5, 0.5, 0.5, 0.5)
                            texture.greyMask = self.frame:CreateMaskTexture()
                            texture.greyMask:SetAllPoints(texture)
                            texture.grey:AddMaskTexture(texture.greyMask)
                            map:AddMaskableTexture(texture.grey)
                        end
                        local w, fw = TileSize(width, layer.tileWidth, column, columns)
                        texture:SetTexture(file, nil, nil, "TRILINEAR")
                        texture:SetSize(w, h)
                        texture:SetTexCoord(0, w / fw, 0, h / fh)
                        texture.greyMask:SetTexture(file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                        texture.greyMask:SetTexCoord(0, w / fw, 0, h / fh)
                        texture:ClearAllPoints()
                        texture:SetPoint("TOPLEFT", x + (column - 1) * layer.tileWidth, -(y + (row - 1) * layer.tileHeight))
                        texture:Show()
                        texture.grey:Show()
                    end
                end
            end
        end
    end
end
Provider.OnMapChanged = Provider.RefreshAllData
function Provider:OnCanvasScaleChanged()
    if self.layerIndex ~= self:GetMap():GetCanvasContainer():GetCurrentLayerIndex() then self:RefreshAllData() end
end
local function Attach()
    if not module:IsEnabled() or not MapCanvasDataProviderMixin or not C_MapExplorationInfo then return end
    for _, map in pairs({WorldMapFrame, BattlefieldMapFrame}) do
        if map.AddDataProvider and not providers[map] then
            local provider = CreateFromMixins(MapCanvasDataProviderMixin, Provider)
            providers[map] = provider
            map:AddDataProvider(provider)
            if map:IsShown() then provider:RefreshAllData() end
        end
    end
end
function module:OnEnable() Attach() end
function module:OnDisable()
    for map, provider in pairs(providers) do map:RemoveDataProvider(provider) end
    providers = {}
end
module:RegisterEvent("ADDON_LOADED", Attach)
module:RegisterEvent("PLAYER_ENTERING_WORLD", Attach)
module:RegisterEvent("MAP_EXPLORATION_UPDATED", function()
    for map, provider in pairs(providers) do if map:IsShown() then provider:RefreshAllData() end end
end)
module:RegisterSlashCommand("mapreveal", function()
    if module:IsEnabled() then module:Disable() else module:Enable() end
end, L.MAP_REVEAL_COMMAND)
yTools.commands.mapreveal.allowDisabled = true
