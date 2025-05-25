-- storage.lua: Storage utilities for Twenty Twenty Objects Mod
-- Handles persistent settings and profile management

local storage = require('openmw.storage')

-- Storage section for this mod's data
local modConfig = storage.globalSection('TwentyTwentyObjects')

local M = {}

-- Get a setting with optional default value
function M.get(key, default)
    local value = modConfig:get(key)
    if value == nil then
        return default
    end
    return value
end

-- Set a setting value
function M.set(key, value)
    modConfig:set(key, value)
end

-- Subscribe to storage changes
function M.subscribe(callback)
    modConfig:subscribe(callback)
end

-- Check if profiles exist
function M.hasProfiles()
    local profiles = M.getProfiles() -- This will always return a table (and fixes storage if needed)
    return #profiles > 0
end

-- Get all profiles
function M.getProfiles()
    local profilesData = modConfig:get('profiles')
    if type(profilesData) == 'table' then
        return profilesData
    else
        -- If profilesData is nil or not a table, initialize/correct it in storage
        if profilesData ~= nil then
            print('[TTO Storage WARN] Profiles data in storage was not a table (type: ' .. type(profilesData) .. '). Resetting to empty table.')
        else
            print('[TTO Storage INFO] Profiles not found in storage. Initializing with an empty table.')
        end
        local newProfiles = {}
        modConfig:set('profiles', newProfiles) -- Correct the storage
        return newProfiles
    end
end

-- Set all profiles
function M.setProfiles(profiles)
    modConfig:set('profiles', profiles)
end

-- Initialize with default profiles if none exist
function M.initializeDefaults()
    if not M.hasProfiles() then
        local defaults = {
            {
                name = "All Items (Default)",
                key = 'x',
                shift = true, ctrl = false, alt = false,
                radius = 1500,
                filters = {
                    items = true,
                    containers = true,
                    weapons = true,
                    armor = true,
                    clothing = true,
                    books = true,
                    ingredients = true,
                    misc = true
                },
                modeToggle = false
            },
            {
                name = "NPCs & Creatures",
                key = 'p',
                shift = true, ctrl = false, alt = false,
                radius = 300,
                filters = {
                    npcs = true,
                    creatures = true
                },
                modeToggle = true
            }
        }
        M.setProfiles(defaults)
        return true
    end
    return false
end

return M