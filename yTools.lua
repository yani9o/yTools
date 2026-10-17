local addonName, addon = ...
local L = addon.L

------------------------------------------------------------
-- yTools CORE
--
-- Generic functionality only.
--
-- This file knows NOTHING about individual features.
------------------------------------------------------------

local yTools = { L = L }

_G.yTools = yTools

yTools.name = addonName
yTools.title = "|cff4b7dccy|r|cffffffffTools|r"

local chatPrint=print
function yTools:Print(...)
    local parts={}
    for i=1,select("#",...) do parts[i]=tostring(select(i,...)) end
    local message=table.concat(parts," ")
    message=message:gsub("^|c%x%x%x%x%x%x%x%xyTools:|r%s*",""):gsub("^yTools:%s*","")
    chatPrint(self.title .. ": " .. message)
end

yTools.modules = {}
yTools.moduleOrder = {}
yTools.commands = {}

yTools._initialized = false
yTools._optionsInitialized = false

------------------------------------------------------------
-- SavedVariables
------------------------------------------------------------

local function InitializeDB()

    yToolsDB = yToolsDB or {}
    yToolsDB.modules = yToolsDB.modules or {}

end


function yTools:GetDB()

    InitializeDB()

    return yToolsDB
end


function yTools:GetModuleDB(
    moduleID,
    defaults
)

    InitializeDB()

    local modulesDB =
        yToolsDB.modules

    if not modulesDB[moduleID] then

        modulesDB[moduleID] = {}

    end

    local moduleDB =
        modulesDB[moduleID]

    if defaults then

        for key, value in pairs(defaults) do

            if moduleDB[key] == nil then

                moduleDB[key] = value

            end

        end

    end

    return moduleDB
end


------------------------------------------------------------
-- Error handling
------------------------------------------------------------

function yTools:HandleError(
    module,
    operation,
    err
)

    local moduleName =
        module
        and module.id
        or L.UNKNOWN

    yTools:Print(
        L.CFFFF0000YTOOLS_ERROR_R
        .. moduleName
        .. L.FAILED_DURING
        .. tostring(operation)
        .. ": "
        .. tostring(err)
    )

    if self.debug
        and debugstack
    then

        yTools:Print(
            "|cff888888"
            .. debugstack(3)
            .. "|r"
        )

    end
end


function yTools:CallModule(
    module,
    operation,
    callback,
    ...
)

    if not callback then

        return true

    end

    local args = { ... }

    local ok, err =
        xpcall(
            function()

                callback(
                    module,
                    unpack(args)
                )

            end,
            function(message)

                return tostring(message)
                    .. "\n"
                    .. (
                        debugstack
                        and debugstack(3)
                        or ""
                    )

            end
        )

    if not ok then

        self:HandleError(
            module,
            operation,
            err
        )

        return false
    end

    return true
end


------------------------------------------------------------
-- Module prototype
------------------------------------------------------------

local ModulePrototype = {}


function ModulePrototype:GetDB()

    return yTools:GetModuleDB(
        self.id,
        self.defaults
    )
end


function ModulePrototype:IsEnabled()

    return self.enabled == true
end


function ModulePrototype:Enable()

    if self.enabled then

        return

    end

    self.enabled = true

    local db = self:GetDB()

    db.enabled = true

    if yTools._initialized then

        yTools:ActivateModuleEvents(
            self
        )

        if self.OnEnable then

            yTools:CallModule(
                self,
                "OnEnable",
                self.OnEnable
            )

        end

    end

    yTools:RefreshOptions()
end


function ModulePrototype:Disable()

    if not self.enabled then

        return

    end

    self.enabled = false

    local db = self:GetDB()

    db.enabled = false

    yTools:DeactivateModuleEvents(
        self
    )

    if yTools._initialized
        and self.OnDisable
    then

        yTools:CallModule(
            self,
            "OnDisable",
            self.OnDisable
        )

    end

    yTools:RefreshOptions()
end


function ModulePrototype:RegisterEvent(
    event,
    callback
)

    if type(event) ~= "string" then

        error(
            L.REGISTEREVENT_REQUIRES_AN_EVENT_NAME
        )

    end

    if type(callback) ~= "function" then

        error(
            L.REGISTEREVENT_REQUIRES_A_CALLBACK
        )

    end

    self.eventHandlers[event] =
        self.eventHandlers[event] or {}

    table.insert(
        self.eventHandlers[event],
        callback
    )

    if self:IsEnabled()
        and yTools._initialized
    then

        yTools:ActivateModuleEvent(
            self,
            event
        )

    end
end


function ModulePrototype:UnregisterEvent(
    event,
    callback
)

    local handlers =
        self.eventHandlers[event]

    if not handlers then

        return

    end

    if callback then

        for i = #handlers, 1, -1 do

            if handlers[i] == callback then

                table.remove(
                    handlers,
                    i
                )

            end

        end

    else

        self.eventHandlers[event] = nil

    end

    yTools:ReconcileCoreEvent(
        event
    )
end


function ModulePrototype:RegisterSlashCommand(
    command,
    callback,
    help
)

    if type(command) ~= "string" then

        error(
            L.REGISTERSLASHCOMMAND_REQUIRES_A_COMMAND
        )

    end

    if type(callback) ~= "function" then

        error(
            L.REGISTERSLASHCOMMAND_REQUIRES_A_CALLBACK
        )

    end

    command =
        command:lower()

    if yTools.commands[command] then

        error(
            L.SLASH_COMMAND_ALREADY_REGISTERED
            .. command
        )

    end

    yTools.commands[command] = {

        module = self,
        callback = callback,
        help = help,

    }

end


function ModulePrototype:GetTitle()

    return self.title or self.id
end


function ModulePrototype:GetDescription()

    return self.description or ""
end


------------------------------------------------------------
-- Module registration
------------------------------------------------------------

function yTools:RegisterModule(
    moduleID,
    metadata
)

    if type(moduleID) ~= "string"
        or moduleID == ""
    then

        error(
            L.YTOOLS_REGISTERMODULE_REQUIRES_A_MODULE_ID
        )

    end

    if self.modules[moduleID] then

        error(
            L.YTOOLS_MODULE_ALREADY_REGISTERED
            .. moduleID
        )

    end

    metadata = metadata or {}

    local module =
        setmetatable({

            id = moduleID,

            title =
                metadata.title
                or moduleID,

            description =
                metadata.description
                or "",

            defaultEnabled =
                metadata.defaultEnabled
                == true,

            defaults =
                metadata.defaults
                or {},

            eventHandlers = {},
            enabled = false,

        }, {
            __index = ModulePrototype,
        })

    self.modules[moduleID] =
        module

    table.insert(
        self.moduleOrder,
        moduleID
    )

    return module
end


function yTools:GetModule(
    moduleID
)

    return self.modules[moduleID]
end


function yTools:GetModules()

    return self.modules,
        self.moduleOrder
end


------------------------------------------------------------
-- Module state
------------------------------------------------------------

function yTools:InitializeModuleState(
    module
)

    local db =
        module:GetDB()

    if db.enabled == nil then

        db.enabled =
            module.defaultEnabled

    end

    module.enabled =
        db.enabled == true
end


function yTools:InitializeAllModuleStates()

    for _, moduleID in ipairs(
        self.moduleOrder
    ) do

        local module =
            self.modules[moduleID]

        if module then

            self:InitializeModuleState(
                module
            )

        end

    end
end


------------------------------------------------------------
-- Core event management
------------------------------------------------------------

local coreEventFrame =
    CreateFrame("Frame")

local registeredCoreEvents = {}


local function AnyEnabledModuleNeedsEvent(
    event
)

    for _, moduleID in ipairs(
        yTools.moduleOrder
    ) do

        local module =
            yTools.modules[moduleID]

        if module
            and module:IsEnabled()
            and module.eventHandlers[event]
        then

            return true

        end

    end

    return false
end


function yTools:ActivateModuleEvent(
    module,
    event
)

    if not module:IsEnabled() then

        return

    end

    if not registeredCoreEvents[event] then

        coreEventFrame:RegisterEvent(
            event
        )

        registeredCoreEvents[event] =
            true

    end
end


function yTools:ActivateModuleEvents(
    module
)

    for event in pairs(
        module.eventHandlers
    ) do

        self:ActivateModuleEvent(
            module,
            event
        )

    end
end


function yTools:DeactivateModuleEvents(
    module
)

    for event in pairs(
        module.eventHandlers
    ) do

        self:ReconcileCoreEvent(
            event
        )

    end
end


function yTools:ReconcileCoreEvent(
    event
)

    if AnyEnabledModuleNeedsEvent(
        event
    ) then

        if not registeredCoreEvents[event] then

            coreEventFrame:RegisterEvent(
                event
            )

            registeredCoreEvents[event] =
                true

        end

    elseif registeredCoreEvents[event] then

        coreEventFrame:UnregisterEvent(
            event
        )

        registeredCoreEvents[event] =
            nil

    end
end


------------------------------------------------------------
-- Event dispatch
------------------------------------------------------------

local function DispatchModuleEvent(
    module,
    event,
    ...
)

    if not module:IsEnabled() then

        return

    end

    local handlers =
        module.eventHandlers[event]

    if not handlers then

        return

    end

    for _, callback in ipairs(
        handlers
    ) do

        yTools:CallModule(
            module,
            L.EVENT .. event,
            callback,
            event,
            ...
        )

    end
end


local function DispatchEvent(
    event,
    ...
)

    for _, moduleID in ipairs(
        yTools.moduleOrder
    ) do

        local module =
            yTools.modules[moduleID]

        if module
            and module:IsEnabled()
        then

            DispatchModuleEvent(
                module,
                event,
                ...
            )

        end

    end
end


------------------------------------------------------------
-- Core event handler
------------------------------------------------------------

coreEventFrame:SetScript(
    "OnEvent",
    function(_, event, ...)

        if event == "ADDON_LOADED" then

            local loadedAddon = ...

            if loadedAddon == addonName then

                InitializeDB()

            end

            return
        end


        if event == "PLAYER_LOGIN" then

            if not yTools._initialized then

                yTools._initialized = true

                yTools:InitializeAllModuleStates()

                for _, moduleID in ipairs(
                    yTools.moduleOrder
                ) do

                    local module =
                        yTools.modules[moduleID]

                    if module
                        and module:IsEnabled()
                    then

                        yTools:ActivateModuleEvents(
                            module
                        )

                        if module.OnEnable then

                            yTools:CallModule(
                                module,
                                "OnEnable",
                                module.OnEnable
                            )

                        end

                    end

                end

                yTools:InitializeOptions()

            end

        end

        DispatchEvent(
            event,
            ...
        )

    end
)


coreEventFrame:RegisterEvent(
    "ADDON_LOADED"
)

coreEventFrame:RegisterEvent(
    "PLAYER_LOGIN"
)


------------------------------------------------------------
-- Slash commands
------------------------------------------------------------

local function TrimMessage(
    message
)

    message = message or ""

    return message:match(
        "^%s*(.-)%s*$"
    )
end


local function PrintHelp()

    yTools:Print(
        "|cff00ccff===== yTools =====|r"
    )

    yTools:Print(
        L.CFF00FF00_YTOOLS_OPTIONS_R_OPEN_YTOOLS_OPTIONS
    )


    local commands = {}

    for command, info in pairs(
        yTools.commands
    ) do

        if not info.hidden then
            table.insert(commands, { command = command, info = info })
        end

    end


    table.sort(
        commands,
        function(a, b)

            return a.command < b.command

        end
    )


    for _, entry in ipairs(
        commands
    ) do

        local info = entry.info

        yTools:Print(
            "|cff00ff00/ytools "
            .. entry.command
            .. "|r - "
            .. (
                info.help
                or L.MODULE_COMMAND
            )
        )

    end
end


------------------------------------------------------------
-- Slash command dispatcher
------------------------------------------------------------

function yTools:DispatchSlashCommand(
    message
)

    message =
        TrimMessage(message)


    --------------------------------------------------------
    -- Bare /ytools
    --
    -- Show help instead of opening options.
    --------------------------------------------------------

    if message == "" then

        PrintHelp()

        return
    end


    --------------------------------------------------------
    -- Global options aliases.
    --
    -- These are handled by the core and therefore do not
    -- belong to any module.
    --------------------------------------------------------

    local command =
        message:match(
            "^(%S+)"
        )

    command =
        command
        and command:lower()
        or ""


    if command == "options"
        or command == "config"
    then

        self:OpenOptions()

        return
    end


    --------------------------------------------------------
    -- Module command.
    --------------------------------------------------------

    local arguments

    command, arguments =
        message:match(
            "^(%S+)%s*(.*)$"
        )

    command =
        command
        and command:lower()
        or ""

    arguments =
        arguments or ""


    local entry =
        self.commands[command]


    if not entry then

        PrintHelp()

        return
    end


    local module =
        entry.module


    local allowDisabled = entry.allowDisabled
    if type(allowDisabled) == "function" then allowDisabled = allowDisabled(arguments) end
    if not module:IsEnabled() and not allowDisabled then

        yTools:Print(
            "|cffff0000yTools:|r "
            .. module:GetTitle()
            .. L.IS_DISABLED
        )

        return
    end


    self:CallModule(
        module,
        L.SLASH_COMMAND .. command,
        entry.callback,
        arguments
    )
end


SLASH_YTOOLS1 = "/ytools"

SlashCmdList.YTOOLS =
    function(message)

        yTools:DispatchSlashCommand(
            message
        )

    end


------------------------------------------------------------
-- Options API hooks
------------------------------------------------------------

function yTools:InitializeOptions()

    if self._optionsInitialized then

        return

    end

    self._optionsInitialized = true

    if self.CreateOptionsPanel then

        self:CreateOptionsPanel()

    end
end


function yTools:OpenOptions()

    if not self._optionsInitialized then

        self:InitializeOptions()

    end

    if self.OpenOptionsPanel then

        self:OpenOptionsPanel()

        return
    end

    PrintHelp()
end


function yTools:RefreshOptions()

    if self.RefreshOptionsPanel then

        self:RefreshOptionsPanel()

    end
end


------------------------------------------------------------
-- Debug
------------------------------------------------------------

function yTools:SetDebug(
    enabled
)

    self.debug =
        enabled == true
end


function yTools:IsDebugEnabled()

    return self.debug == true
end

-- Blizzard addon-compartment entry.
function yTools_OnAddonCompartmentClick()
    yTools:OpenOptionsPanel()
end
