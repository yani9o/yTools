local _, addon = ...
local UI = {}
addon.UI = UI
if _G.yTools and _G.yTools.name == (...) then _G.yTools.UI = UI end

function UI.Check(button)
    button:SetSize(18,18)
    button:SetNormalAtlas("questlog-icon-ticksquare")
    button:GetCheckedTexture():SetAtlas("questlog-icon-checkmark-yellow")
    button:GetNormalTexture():SetAllPoints(button)
    button:GetCheckedTexture():SetAllPoints(button)
    local disabled=button.GetDisabledTexture and button:GetDisabledTexture()
    if disabled then
        disabled:SetAtlas("questlog-icon-ticksquare");disabled:SetAllPoints(button)
        disabled:SetDesaturated(true);disabled:SetVertexColor(.6,.6,.6)
    end
    local disabledChecked=button.GetDisabledCheckedTexture and button:GetDisabledCheckedTexture()
    if disabledChecked then
        disabledChecked:SetAtlas("questlog-icon-checkmark-yellow");disabledChecked:SetAllPoints(button)
        disabledChecked:SetDesaturated(true);disabledChecked:SetVertexColor(.6,.6,.6)
    end
    local pushed = button:GetPushedTexture()
    if pushed then pushed:SetAlpha(0) end
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(); highlight:SetAtlas("questlog-icon-ticksquare")
    highlight:SetBlendMode("ADD"); highlight:SetAlpha(0.3)
    button:SetHighlightTexture(highlight)
end

function UI.Scrollbar(parent)
    local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
    bar:Init(1,1)
    bar.minimum, bar.maximum, bar.value = 0,0,0
    local originalSetScript = bar.SetScript
    function bar:SetScript(event, fn)
        if event == "OnValueChanged" then self.valueCallback = fn
        else originalSetScript(self,event,fn) end
    end
    function bar:SetMinMaxValues(minimum,maximum)
        self.minimum,self.maximum=minimum,math.max(minimum,maximum)
        self:SetPanExtentPercentage(self.maximum>minimum and math.min(1,42/(self.maximum-minimum)) or 1)
        self:SetValue(self.value)
    end
    function bar:GetMinMaxValues() return self.minimum,self.maximum end
    function bar:GetValue() return self.value end
    function bar:SetValue(value)
        local offset=math.max(self.minimum,math.min(self.maximum,value or 0))
        if self.settingValue or math.abs(self.value-offset)<.001 then return end
        self.value=offset
        self.settingValue=true
        self:SetScrollPercentage(self.maximum>self.minimum and (offset-self.minimum)/(self.maximum-self.minimum) or 0,true)
        if self.valueCallback then self.valueCallback(self,offset) end
        self.settingValue=false
    end
    function bar:SetOrientation() end
    function bar:SetValueStep() end
    function bar:SetThumbTexture() end
    bar:RegisterCallback("OnScroll",function(_,percentage)
        if bar.settingValue then return end
        bar:SetValue(bar.minimum+percentage*(bar.maximum-bar.minimum))
    end,bar)
    return bar
end

function UI.ScrollFrame(frame,parent)
    local bar=UI.Scrollbar(parent)
    frame.ScrollBar=bar
    bar:SetPoint("TOPLEFT",frame,"TOPRIGHT",4,0)
    bar:SetPoint("BOTTOMLEFT",frame,"BOTTOMRIGHT",4,0)
    bar:SetScript("OnValueChanged",function(_,value)frame:SetVerticalScroll(value)end)
    local function update()
        local maximum=math.max(0,frame:GetVerticalScrollRange())
        bar:SetMinMaxValues(0,maximum)
        bar:SetVisibleExtentPercentage(frame:GetHeight()/math.max(1,frame:GetHeight()+maximum))
        bar:SetValue(frame:GetVerticalScroll())
    end
    frame:SetScript("OnScrollRangeChanged",update)
    frame:HookScript("OnSizeChanged",update)
    frame:HookScript("OnVerticalScroll",function(_,value)bar:SetValue(value)end)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel",function(_,delta)bar:SetValue(frame:GetVerticalScroll()-delta*42)end)
end

local function HideButtonTextures(button)
    for _, getter in ipairs({"GetNormalTexture","GetPushedTexture","GetHighlightTexture","GetDisabledTexture"}) do
        local texture = button[getter] and button[getter](button)
        if texture then texture:SetAlpha(0) end
    end
end

function UI.IconButton(button,texture)
    HideButtonTextures(button)
    for _, key in ipairs({"Left","Middle","Right"}) do
        if button[key] and button[key].Hide then button[key]:Hide() end
    end
    button:SetSize(26,26)
    local border=CreateFrame("EditBox",nil,button,"InputBoxVisualTemplate")
    border:SetAllPoints();border:SetAutoFocus(false);border:EnableMouse(false);border:EnableKeyboard(false)
    border:SetFrameLevel(button:GetFrameLevel()+1)
    for _,piece in ipairs({border.Left,border.Middle,border.Right}) do piece:SetVertexColor(1,.95,.35) end
    border.Left:ClearAllPoints();border.Left:SetPoint("TOPLEFT");border.Left:SetPoint("BOTTOMLEFT");border.Left:SetWidth(8)
    border.Right:ClearAllPoints();border.Right:SetPoint("TOPRIGHT");border.Right:SetPoint("BOTTOMRIGHT");border.Right:SetWidth(8)
    border.Middle:ClearAllPoints();border.Middle:SetPoint("TOPLEFT",border.Left,"TOPRIGHT");border.Middle:SetPoint("BOTTOMRIGHT",border.Right,"BOTTOMLEFT")
    local icon=border:CreateTexture(nil,"ARTWORK")
    icon:SetPoint("TOPLEFT",4,-4);icon:SetPoint("BOTTOMRIGHT",-4,4);icon:SetTexture(texture)
    local glow=border:CreateTexture(nil,"HIGHLIGHT");glow:SetAllPoints(icon);glow:SetTexture(texture);glow:SetBlendMode("ADD");glow:SetAlpha(.35)
    button:SetHighlightTexture(glow)
    if button.text then button.text:Hide() end
    return border
end

function UI.Arrow(button,up)
    HideButtonTextures(button)
    button:SetSize(18,18)
    local art=button:CreateTexture(nil,"ARTWORK");art:SetPoint("CENTER");art:SetAtlas("common-dropdown-a-button",false);art:SetSize(18,18)
    art:SetRotation(up and math.pi or 0)
    button:SetScript("OnEnter",function()art:SetAtlas("common-dropdown-a-button-hover",false)end)
    button:SetScript("OnLeave",function()art:SetAtlas("common-dropdown-a-button",false);art:SetSize(18,18)end)
    if button.text then button.text:Hide() end
end

function UI.Tooltip(button,text)
    button:HookScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:SetText(text);GameTooltip:Show()
    end)
    button:HookScript("OnLeave",function()GameTooltip:Hide()end)
end

-- Native inset uses a nine-slice border: corners keep their size on tall fields.
function UI.InputBorder(host)
    -- The same native backdrop used by MacroFrameTextBackground.
    local border=CreateFrame("Frame",nil,host,"TooltipBackdropTemplate")
    border:SetAllPoints(host);border:EnableMouse(false)
    border:SetFrameLevel(host:GetFrameLevel())
    return border
end

function UI.DropdownLabel(button,text)
    button:SetDefaultText(text)
    -- Override stale selection text only for this refresh, keeping native menus intact.
    button.text=text
    button:UpdateText()
end

function UI.DropdownLayout(button)
    button:SetHeight(25)
    button.Text:ClearAllPoints()
    button.Text:SetPoint("LEFT",button,"LEFT",8,-1)
    button.Text:SetPoint("RIGHT",button,"RIGHT",-24,-1)
    button.Text:SetJustifyV("MIDDLE")
    button.Arrow:ClearAllPoints();button.Arrow:SetPoint("RIGHT",button,"RIGHT",1,-1)
end

-- Separate native tooltip content from the addon footer, and counts from IDs.
-- Inspect current lines rather than keeping state across tooltip rebuilds.
local tooltipSpacerFonts = setmetatable({}, { __mode = "k" })
local tooltipSpacerHooks = setmetatable({}, { __mode = "k" })
local function RestoreTooltipSpacerFonts(tooltip)
    for line, font in pairs(tooltipSpacerFonts[tooltip] or {}) do
        if not (line.IsForbidden and line:IsForbidden()) then
            line:SetFont(font[1], font[2], font[3])
        end
    end
    tooltipSpacerFonts[tooltip] = nil
end

function UI.TooltipFooterGap(tooltip, section)
    if not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden()) then return end
    local L = _G.yTools.L
    local name, count = tooltip:GetName(), tooltip:NumLines()
    if (issecretvalue and (issecretvalue(name) or issecretvalue(count))) then return end
    if type(count) ~= "number" or count == 0 then return end
    local footer, ids, counts, lastText = false, false, false
    if type(name) == "string" then
        for i = 1, count do
            local line = _G[name .. "TextLeft" .. i]
            if line and not (line.IsForbidden and line:IsForbidden()) then
                local text = line:GetText()
                if not (issecretvalue and issecretvalue(text)) then
                    lastText = text
                    if text == L.ITEM_ID or text == L.SPELL_ID or text == L.QUEST_ID or text == L.NPC_ID then
                        ids, footer = true, true
                    elseif text == L.ITEM_COUNT_TOTAL then
                        counts, footer = true, true
                    elseif text == L.TARGET then
                        footer = true
                    end
                end
            end
        end
    end
    local needsGap = not footer or (section == "ids" and counts and not ids)
    if needsGap and (type(lastText) ~= "string" or lastText:match("%S")) then
        tooltip:AddLine(" ")
        local index = tooltip:NumLines()
        if type(name) ~= "string" or (issecretvalue and issecretvalue(index)) then return end
        local spacer = _G[name .. "TextLeft" .. index]
        if spacer and spacer.GetFont and spacer.SetFont and tooltip.HookScript
            and not (spacer.IsForbidden and spacer:IsForbidden()) then
            local path, size, flags = spacer:GetFont()
            if type(path) == "string" and type(size) == "number" then
                if not tooltipSpacerHooks[tooltip] then
                    tooltip:HookScript("OnTooltipCleared", RestoreTooltipSpacerFonts)
                    tooltipSpacerHooks[tooltip] = true
                end
                tooltipSpacerFonts[tooltip] = tooltipSpacerFonts[tooltip] or {}
                tooltipSpacerFonts[tooltip][spacer] = { path, size, flags or "" }
                spacer:SetFont(path, size / 2, flags or "")
            end
        end
    end
end
