-- init.lua: Global script for Twenty Twenty Objects Mod
-- Handles hotkey detection and profile management

local world = require('openmw.world')
local async = require('openmw.async')

-- Import our utility modules
local storage = require('scripts.TwentyTwentyObjects.util.storage')
local logger = require('scripts.TwentyTwentyObjects.util.logger')

-- Initialize utilities
logger.init(storage)
storage.initializeDefaults()

-- Load profiles from storage
local profiles = storage.getProfiles()

-- Track active profile for toggle mode
local activeProfileIndex = nil
local momentaryProfileIndex = nil  -- Track hold-to-show profile

-- Subscribe to storage changes to keep profiles synced
storage.subscribe(async:callback(function(section, key)
    if key == 'profiles' or key == nil then
        profiles = storage.getProfiles()
        logger.debug('Profiles updated from storage')
        logger.table('Updated profiles', profiles)
    end
end))

-- Helper: Check if a key event matches a profile's hotkey
local function isProfileHotkey(profile, key)
    return (key.symbol == profile.key and
            key.withShift == profile.shift and
            key.withCtrl == profile.ctrl and
            key.withAlt == profile.alt)
end

-- Helper: Send event to player
local function sendToPlayer(event, data)
    local player = world.players[1]
    if player then
        player:sendEvent('TTO_' .. event, data)
        logger.debug(string.format('Sent event %s to player', event))
    else
        logger.error('No player found to send event')
    end
end

-- Engine handler: Key press
local function onKeyPress(key)
    -- Check all profiles for matching hotkey
    for index, profile in ipairs(profiles) do
        if isProfileHotkey(profile, key) then
            logger.info(string.format('Hotkey pressed for profile: %s', profile.name))
            
            if profile.modeToggle then
                -- Toggle mode
                if activeProfileIndex == index then
                    -- Turn off active highlighting
                    sendToPlayer('HideHighlights', {})
                    activeProfileIndex = nil
                    logger.debug('Toggle OFF')
                else
                    -- Turn off any existing highlighting first
                    if activeProfileIndex then
                        sendToPlayer('HideHighlights', {})
                    end
                    -- Activate this profile
                    sendToPlayer('ShowHighlights', { profile = profile })
                    activeProfileIndex = index
                    logger.debug('Toggle ON')
                end
            else
                -- Momentary mode (hold-to-show)
                -- Turn off any toggle mode highlighting
                if activeProfileIndex then
                    sendToPlayer('HideHighlights', {})
                    activeProfileIndex = nil
                end
                -- Show highlights for this profile
                sendToPlayer('ShowHighlights', { profile = profile })
                momentaryProfileIndex = index
                logger.debug('Momentary ON')
            end
            
            return  -- Only one profile can match
        end
    end
end

-- Engine handler: Key release
local function onKeyRelease(key)
    -- Check if this is a momentary profile being released
    if momentaryProfileIndex then
        local profile = profiles[momentaryProfileIndex]
        if profile and not profile.modeToggle and isProfileHotkey(profile, key) then
            logger.debug('Momentary OFF')
            sendToPlayer('HideHighlights', {})
            momentaryProfileIndex = nil
        end
    end
end

-- Engine handler: Game load
local function onLoad()
    -- Reset active states on load
    activeProfileIndex = nil
    momentaryProfileIndex = nil
    logger.info('Twenty Twenty Objects mod loaded')
    
    -- Log initial profile count
    logger.debug(string.format('Loaded %d profiles', #profiles))
end

logger.info('Twenty Twenty Objects global script initialized')

return {
    engineHandlers = {
        onKeyPress = onKeyPress,
        onKeyRelease = onKeyRelease,
        onLoad = onLoad
    }
}