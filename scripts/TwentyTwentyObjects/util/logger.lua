-- logger.lua: Debug logging wrapper for Interactable Highlight mod
-- Provides conditional logging based on debug setting

local async = require('openmw.async')

local M = {}

-- Log levels
M.LEVEL = {
    DEBUG = 'DEBUG',
    INFO = 'INFO',
    WARN = 'WARN',
    ERROR = 'ERROR'
}

-- Cache debug state to avoid repeated storage lookups
local debugEnabled = false
local storage = nil

-- Initialize logger with storage reference
function M.init(storageModule)
    storage = storageModule
    debugEnabled = storage.get('debug', false)
    
    -- Subscribe to debug setting changes
    storage.subscribe(async:callback(function(section, key)
        if key == 'debug' or key == nil then
            debugEnabled = storage.get('debug', false)
        end
    end))
end

-- Internal logging function
local function doLog(level, message)
    if level == M.LEVEL.ERROR or level == M.LEVEL.WARN or debugEnabled then
        -- Use async to avoid blocking main thread
        async:runAfter(0, function()
            print(string.format('[IH][%s] %s', level, tostring(message)))
        end)
    end
end

-- Public logging methods
function M.debug(message)
    doLog(M.LEVEL.DEBUG, message)
end

function M.info(message)
    doLog(M.LEVEL.INFO, message)
end

function M.warn(message)
    doLog(M.LEVEL.WARN, message)
end

function M.error(message)
    doLog(M.LEVEL.ERROR, message)
end

-- Log a table (useful for debugging)
function M.table(name, tbl)
    if not debugEnabled then return end
    
    local function tableToString(t, indent)
        indent = indent or 0
        local spaces = string.rep("  ", indent)
        local result = "{\n"
        
        for k, v in pairs(t) do
            result = result .. spaces .. "  " .. tostring(k) .. " = "
            if type(v) == "table" then
                result = result .. tableToString(v, indent + 1)
            else
                result = result .. tostring(v)
            end
            result = result .. ",\n"
        end
        
        result = result .. spaces .. "}"
        return result
    end
    
    doLog(M.LEVEL.DEBUG, name .. ": " .. tableToString(tbl))
end

return M