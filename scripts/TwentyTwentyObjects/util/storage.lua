-- storage.lua: Storage utilities for Twenty Twenty Objects Mod
-- Handles persistent settings and profile management

local M = {}

local modConfig = nil
local isInitialized = false -- Tracks if modConfig has been successfully fetched
local engine_storage_ref = nil -- To store the require('openmw.storage') result

-- Internal function to get (and initialize if needed) the modConfig
-- This is the ONLY place require('openmw.storage') and globalSection() should be called.
local function getModConfig()
    if isInitialized and modConfig then
        return modConfig
    end

    -- Try to get the engine storage module instance
    if not engine_storage_ref then
        local status, result = pcall(require, 'openmw.storage')
        if not status or not result then
            print("[TTO Storage ERROR] Failed to require('openmw.storage'): " .. tostring(result))
            return nil -- Cannot proceed
        end
        engine_storage_ref = result
    end

    -- Try to get the global section
    local config_status, config_result = pcall(engine_storage_ref.globalSection, 'TwentyTwentyObjects')
    if not config_status or not config_result then
        print("[TTO Storage ERROR] Failed to get globalSection 'TwentyTwentyObjects': " .. tostring(config_result))
        isInitialized = false -- Mark as failed init attempt to avoid retrying constantly if it's a persistent issue
        modConfig = nil
        return nil -- Cannot proceed
    end
    
    modConfig = config_result
    isInitialized = true
    print("[TTO Storage INFO] Successfully initialized modConfig for 'TwentyTwentyObjects'.")
    return modConfig
end

-- Get a setting with optional default value
function M.get(key, default_value)
    local currentModConfig = getModConfig()
    if not currentModConfig then return default_value end

    local value = currentModConfig:get(key)
    if value == nil then
        return default_value
    end
    return value
end

-- Set a setting value
function M.set(key, value)
    local currentModConfig = getModConfig()
    if not currentModConfig then return end -- Silently fail if storage isn't up
    currentModConfig:set(key, value)
end

-- Subscribe to storage changes
function M.subscribe(callback)
    local currentModConfig = getModConfig()
    if not currentModConfig then return end
    currentModConfig:subscribe(callback)
end

-- Get all profiles
function M.getProfiles()
    local currentModConfig = getModConfig()
    if not currentModConfig then return {} end

    local profilesData = currentModConfig:get('profiles')
    if type(profilesData) == 'table' then
        return profilesData
    else
        if profilesData ~= nil then
            print('[TTO Storage WARN] Profiles data in storage was not a table (type: ' .. type(profilesData) .. '). Resetting to empty table.')
        else
            print('[TTO Storage INFO] Profiles not found or invalid. Initializing with an empty table.')
        end
        local newProfiles = {}
        currentModConfig:set('profiles', newProfiles) 
        return newProfiles
    end
end

-- Check if profiles exist
function M.hasProfiles()
    local currentModConfig = getModConfig()
    if not currentModConfig then return false end -- If storage isn't up, assume no profiles
    
    local profiles = M.getProfiles() 
    return #profiles > 0
end

-- Set all profiles
function M.setProfiles(profiles)
    local currentModConfig = getModConfig()
    if not currentModConfig then return end
    currentModConfig:set('profiles', profiles)
end

-- Initialize with default profiles if none exist
function M.initializeDefaults()
    local currentModConfig = getModConfig() -- Call it to ensure it tries to init
    if not currentModConfig then 
        print("[TTO Storage WARN] Cannot initialize defaults, storage not ready.")
        return true -- Act as if done, to not block, but logged failure
    end

    if not M.hasProfiles() then 
        print("[TTO Storage INFO] initializeDefaults: No profiles found, setting defaults.")
        local defaults = {
            {
                name = "All Items (Default)", key = 'x', shift = true, ctrl = false, alt = false, radius = 1500,
                filters = { items = true, containers = true, weapons = true, armor = true, clothing = true, books = true, ingredients = true, misc = true },
                modeToggle = false
            },
            {
                name = "NPCs & Creatures", key = 'p', shift = true, ctrl = false, alt = false, radius = 300,
                filters = { npcs = true, creatures = true }, modeToggle = true
            }
        }
        M.setProfiles(defaults)
        return true
    end
    return false
end

return M