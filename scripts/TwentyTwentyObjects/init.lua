-- init.lua: Global script for Twenty Twenty Objects Mod
-- Handles profile management and player events

local world = require('openmw.world')
local async = require('openmw.async')

-- Import our utility modules
local storage = require('scripts.TwentyTwentyObjects.util.storage')
local logger = require('scripts.TwentyTwentyObjects.util.logger')

-- Initialize utilities
logger.init(storage)
storage.initializeDefaults()

-- Load profiles from storage
-- Note: 'profiles' here is for reference if needed, but primary hotkey matching happens in settings.lua
local profiles = storage.getProfiles() 

-- Track active profile
local activeProfileIndex = nil

-- Subscribe to storage changes to keep profiles synced (e.g., if profile details change)
storage.subscribe(async:callback(function(section, key)
    if key == 'profiles' or key == nil then
        profiles = storage.getProfiles() -- Keep this global 'profiles' copy updated
        logger.debug('Profiles updated in global script from storage')
        -- If the currently active profile's definition changed, we might need to refresh,
        -- but for now, we assume player script handles display based on profile data it receives.
    end
end))

-- Helper: Send event to player
local function sendToPlayer(event, data)
    local player = world.players[1]
    if player then
        player:sendEvent('TTO_' .. event, data)
        logger.debug(string.format('Sent event %s to player with data: %s', event, tostring(data)))
    else
        logger.error('No player found to send event')
    end
end

-- Event handler: Show highlights
local function onShowHighlights(data)
    local profile = data.profile
    local profileIndex = data.profileIndex -- This is the index from the 'profiles' array in settings.lua

    if not profile or profileIndex == nil then
        logger.error("onShowHighlights called with invalid data. Profile: " .. tostring(profile) .. ", Index: " .. tostring(profileIndex))
        return
    end

    if profile.modeToggle then -- This is a toggle-mode profile
        if activeProfileIndex == profileIndex then
            -- This toggle profile is already active, so turn it OFF
            sendToPlayer('HideHighlights', {})
            activeProfileIndex = nil
            logger.debug('Toggle OFF for profile: ' .. profile.name)
        else
            -- A different profile is active, or no profile is active. Turn this one ON.
            if activeProfileIndex then -- If something else was active, hide it first
                sendToPlayer('HideHighlights', {})
            end
            sendToPlayer('ShowHighlights', { profile = profile })
            activeProfileIndex = profileIndex
            logger.debug('Toggle ON for profile: ' .. profile.name)
        end
    else -- This is a momentary (hold-to-show) profile
        -- If another profile is active (e.g., a toggled one), hide it first.
        if activeProfileIndex then
            sendToPlayer('HideHighlights', {})
            -- activeProfileIndex will be updated below.
        end
        sendToPlayer('ShowHighlights', { profile = profile })
        activeProfileIndex = profileIndex -- Track it as active
        logger.debug('Momentary ON for profile: ' .. profile.name)
    end
end

-- Event handler: Hide highlights (typically for momentary release)
local function onHideHighlights(data) -- data is currently empty from settings.lua
    if activeProfileIndex then
        -- Check if the profile to hide is indeed the active one.
        -- For momentary, settings.lua just sends a generic HideHighlights.
        -- We assume it corresponds to the currently active momentary highlight.
        local profileToHideName = "Unknown"
        if profiles[activeProfileIndex] then -- Try to get name for logging
             profileToHideName = profiles[activeProfileIndex].name
        end

        sendToPlayer('HideHighlights', {})
        logger.debug('Highlights OFF, was active: ' .. profileToHideName .. ' (index ' .. tostring(activeProfileIndex) .. ')')
        activeProfileIndex = nil
    else
        logger.debug('onHideHighlights called, but no profile was active.')
    end
end

-- Engine handler: Game load
local function onLoad()
    -- Reset active states on load
    activeProfileIndex = nil
    logger.info('Twenty Twenty Objects global script loaded and reset.')
    
    -- Log initial profile count from storage
    logger.debug(string.format('Loaded %d profiles (from storage in global init)', #storage.getProfiles()))
end

logger.info('Twenty Twenty Objects global script initialized')

return {
    engineHandlers = {
        onLoad = onLoad
    },
    eventHandlers = {
        TTO_ShowHighlights = onShowHighlights,
        TTO_HideHighlights = onHideHighlights
    }
}