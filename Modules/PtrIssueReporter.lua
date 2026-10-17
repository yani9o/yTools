local L = _G.yTools.L
local yTools = _G.yTools

local module = yTools:RegisterModule(
    "PTRIssueReporter",
    {
        title = L.UI_HIDE_PTR_ISSUE_REPORTER,
        description = L.HIDES_THE_PTR_ISSUE_REPORTER_FRAME,
        defaultEnabled = true,
    }
)


------------------------------------------------------------
-- Hide
------------------------------------------------------------

local function HidePTRReporter()
    if PTR_IssueReporter then
        PTR_IssueReporter:Hide()
    end

    if IssueReporter then
        IssueReporter:Hide()
    end
end


------------------------------------------------------------
-- Show again when disabled
------------------------------------------------------------

local function ShowPTRReporter()
    if PTR_IssueReporter then
        PTR_IssueReporter:Show()
    end

    if IssueReporter then
        IssueReporter:Show()
    end
end


------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------

function module:OnEnable()
    HidePTRReporter()
end


function module:OnDisable()
    ShowPTRReporter()
end


------------------------------------------------------------
-- Events
------------------------------------------------------------

module:RegisterEvent(
    "PLAYER_ENTERING_WORLD",
    function()
        HidePTRReporter()
    end
)
