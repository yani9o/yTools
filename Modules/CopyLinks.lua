local yTools = _G.yTools
local L = yTools.L
local module = yTools:RegisterModule("CopyLinks", {
    title = L.CHAT_COPY_LINKS,
    description = L.CHAT_COPY_LINKS_DESCRIPTION,
    defaultEnabled = true,
})

local PREFIX = "ytoolsurl:"
local hookedFrames = setmetatable({}, { __mode = "k" })
local installedFilters = {}
local installedWindowHooks = {}
local copyFrame, editBox

local function IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

-- Store the URL in the hyperlink itself: no growing cache and no lost links
-- when old chat history is restored. Hex also keeps pipes out of link metadata.
local function Encode(url)
    return (url:gsub(".", function(char) return string.format("%02x", char:byte()) end))
end

local function Decode(link)
    if IsSecret(link) or type(link) ~= "string" or link:sub(1, #PREFIX) ~= PREFIX then return end
    local encoded = link:sub(#PREFIX + 1)
    if #encoded == 0 or #encoded > 4096 or #encoded % 2 ~= 0 or encoded:find("[^%x]") then return end
    local url = encoded:gsub("%x%x", function(pair) return string.char(tonumber(pair, 16)) end)
    if url:find("[%c|]") then return end
    local lower = url:lower()
    if lower:match("^https?://") or lower:match("^www%.") then return url end
end

local function LinkPlainText(text)
    local function Replace(start, candidate)
        -- Avoid matching a URL prefix embedded in another word.
        if start > 1 and text:sub(start - 1, start - 1):match("[%w_]") then return candidate end
        local url, suffix = candidate, ""
        while url:match("[.,;:!?]$") do
            suffix = url:sub(-1) .. suffix
            url = url:sub(1, -2)
        end
        for _, pair in ipairs({ { "(", ")" }, { "[", "]" }, { "{", "}" } }) do
            local function Count(char)
                local _, n = url:gsub("%" .. char, "")
                return n
            end
            while url:sub(-1) == pair[2] and Count(pair[2]) > Count(pair[1]) do
                suffix = url:sub(-1) .. suffix
                url = url:sub(1, -2)
            end
        end
        if #url > 2048 or not url:find("%.") then return candidate end
        return "|H" .. PREFIX .. Encode(url) .. "|h|cffffffff[" .. url .. "]|r|h" .. suffix
    end
    local pattern = "()[hH][tT][tT][pP][sS]?://[^%s<>\"|]+"
    -- Match both URL forms in one pass so generated links are never relinked.
    local result, cursor = {}, 1
    while cursor <= #text do
        local a, b = text:find(pattern, cursor)
        local c, d = text:find("()[wW][wW][wW]%.[^%s<>\"|]+", cursor)
        if c and (not a or c < a) then a, b = c, d end
        if not a then result[#result + 1] = text:sub(cursor); break end
        result[#result + 1] = text:sub(cursor, a - 1)
        result[#result + 1] = Replace(a, text:sub(a, b))
        cursor = b + 1
    end
    return table.concat(result)
end

local function Linkify(text)
    if IsSecret(text) or type(text) ~= "string" then return text end
    local result, cursor = {}, 1
    while cursor <= #text do
        local start, marker = text:find("|[HTA]", cursor)
        if not start then result[#result + 1] = LinkPlainText(text:sub(cursor)); break end
        result[#result + 1] = LinkPlainText(text:sub(cursor, start - 1))
        local kind = text:sub(marker, marker)
        local finish
        if kind == "H" then
            local _, labelStart = text:find("|h", marker + 1, true)
            if labelStart then
                local _, labelEnd = text:find("|h", labelStart + 1, true)
                finish = labelEnd
            end
        else
            local _, textureEnd = text:find(kind == "T" and "|t" or "|a", marker + 1, true)
            finish = textureEnd
        end
        if not finish then result[#result + 1] = text:sub(start); break end
        result[#result + 1] = text:sub(start, finish)
        cursor = finish + 1
    end
    return table.concat(result)
end

local function RemoveLinks(text)
    if IsSecret(text) or type(text) ~= "string" then return text end
    return (text:gsub("|H(ytoolsurl:%x+)|h.-|h", function(link)
        return Decode(link) or ("|H" .. link .. "|h|h")
    end))
end

local function CreateCopyFrame()
    if copyFrame then return end
    copyFrame = CreateFrame("Frame", "yToolsCopyLinkFrame", UIParent, "PortraitFrameTemplate")
    copyFrame:SetSize(430, 160)
    copyFrame:SetPoint("CENTER")
    copyFrame:SetFrameStrata("DIALOG")
    copyFrame:SetFrameLevel(10)
    copyFrame.NineSlice:SetFrameLevel(11)
    copyFrame.PortraitContainer:SetFrameLevel(10)
    copyFrame.TitleContainer:SetFrameLevel(13)
    copyFrame.CloseButton:SetFrameLevel(14)
    copyFrame:SetClampedToScreen(true)
    copyFrame:SetMovable(true)
    copyFrame:SetTitle(L.COPY_LINK)
    copyFrame:SetPortraitToAsset("Interface\\icons\\inv_blacksmithing_toolbox_01")
    copyFrame.Bg:SetAtlas("QuestLog-main-background", false)
    copyFrame.TopTileStreaks:Hide()
    for _, handle in ipairs({ copyFrame.TitleContainer, copyFrame.PortraitContainer }) do
        handle:EnableMouse(true)
        handle:RegisterForDrag("LeftButton")
        handle:SetScript("OnDragStart", function() copyFrame:StartMoving() end)
        handle:SetScript("OnDragStop", function() copyFrame:StopMovingOrSizing() end)
    end

    local inset = CreateFrame("Frame", nil, copyFrame)
    inset:SetPoint("TOPLEFT", 16, -48)
    inset:SetPoint("BOTTOMRIGHT", -16, 39)
    inset:SetFrameLevel(12)
    yTools.UI.InputBorder(inset)
    local scroll = CreateFrame("ScrollFrame", nil, inset)
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -24, 6)
    scroll:SetFrameLevel(13)
    yTools.UI.ScrollFrame(scroll, inset)
    editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetWidth(360)
    editBox:SetHeight(60)
    editBox:SetMaxLetters(0)
    editBox:EnableMouse(true)
    editBox:EnableKeyboard(true)
    editBox:SetTextInsets(0, 0, 0, 0)
    scroll:SetScrollChild(editBox)
    scroll:SetScript("OnSizeChanged", function(self, width)
        editBox:SetWidth(math.max(1, width))
        self:UpdateScrollChildRect()
    end)
    editBox:SetScript("OnEscapePressed", function() copyFrame:Hide() end)
    editBox:SetScript("OnEnterPressed", function() copyFrame:Hide() end)
    editBox:SetScript("OnTextChanged", function() scroll:UpdateScrollChildRect() end)
    editBox:SetScript("OnCursorChanged", function(_, _, y, _, height)
        local offset = -y
        local current = scroll:GetVerticalScroll()
        if offset < current then scroll:SetVerticalScroll(offset)
        elseif offset + height > current + scroll:GetHeight() then
            scroll:SetVerticalScroll(offset + height - scroll:GetHeight())
        end
    end)
    local hint = copyFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOMLEFT", 16, 16)
    hint:SetPoint("BOTTOMRIGHT", -16, 16)
    hint:SetJustifyH("LEFT")
    hint:SetText(L.COPY_LINK_HINT)
    copyFrame:SetScript("OnHide", function() editBox:ClearFocus() end)
    tinsert(UISpecialFrames, "yToolsCopyLinkFrame")
    copyFrame:Hide()
end

local function ShowLink(url)
    CreateCopyFrame()
    copyFrame:Show()
    editBox:SetText(url)
    editBox:SetCursorPosition(0)
    editBox:SetFocus()
    editBox:HighlightText()
end

-- Other modules can use the copy window independently of chat link detection.
function module:ShowLink(url)
    if IsSecret(url) or type(url) ~= "string" then return end
    ShowLink(url)
end

local function HookFrame(frame)
    if not frame or frame == _G.ChatFrame2 or frame == _G.CombatLogChatFrame
        or hookedFrames[frame] or (frame.IsForbidden and frame:IsForbidden()) then return end
    hookedFrames[frame] = true
    local original = frame:GetScript("OnHyperlinkClick")
    frame:SetScript("OnHyperlinkClick", function(self, link, text, button, ...)
        if not IsSecret(link) and type(link) == "string" and link:sub(1, #PREFIX) == PREFIX then
            if module:IsEnabled() and button == "LeftButton" then
                local url = Decode(link)
                if url then ShowLink(url) end
            end
            return
        end
        if original then return original(self, link, text, button, ...) end
    end)
end

local function ForEachChatFrame(callback)
    if ChatFrameUtil and ChatFrameUtil.ForEachChatFrame then
        ChatFrameUtil.ForEachChatFrame(callback)
    else
        for i = 1, NUM_CHAT_WINDOWS or 10 do callback(_G["ChatFrame" .. i]) end
    end
end

local function TransformHistory(frame, transform)
    if not frame or frame == _G.ChatFrame2 or frame == _G.CombatLogChatFrame
        or (frame.IsForbidden and frame:IsForbidden()) or not frame.TransformMessages then return end
    frame:TransformMessages(function(text)
        return not IsSecret(text) and type(text) == "string" and transform(text) ~= text
    end, function(text, ...) return transform(text), ... end)
end

local function Filter(_, _, message, ...)
    if not module:IsEnabled() then return false, message, ... end
    return false, Linkify(message), ...
end

local function Install()
    if ChatFrame_AddMessageEventFilter then
        local events = {
            "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
            "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
            "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
            "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
            "CHAT_MSG_CHANNEL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_SYSTEM",
        }
        for _, group in pairs(ChatTypeGroup or {}) do
            for _, event in ipairs(group) do events[#events + 1] = event end
        end
        for _, event in ipairs(events) do
            if not installedFilters[event] then
                ChatFrame_AddMessageEventFilter(event, Filter)
                installedFilters[event] = true
            end
        end
    end
    for _, name in ipairs({ "FCF_OpenNewWindow", "FCF_OpenTemporaryWindow" }) do
        if _G[name] and not installedWindowHooks[name] then
            hooksecurefunc(name, function()
                if module:IsEnabled() then ForEachChatFrame(HookFrame) end
            end)
            installedWindowHooks[name] = true
        end
    end
    ForEachChatFrame(HookFrame)
end

function module:OnEnable()
    Install()
    ForEachChatFrame(function(frame) TransformHistory(frame, Linkify) end)
end

function module:OnDisable()
    if copyFrame then copyFrame:Hide() end
    ForEachChatFrame(function(frame) TransformHistory(frame, RemoveLinks) end)
end

module:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    Install()
    ForEachChatFrame(function(frame) TransformHistory(frame, Linkify) end)
end)
