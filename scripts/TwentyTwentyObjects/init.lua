-- init.lua: Global script for Twenty Twenty Objects Mod
-- Handles profile management and player events

local world = require('openmw.world')
local async = require('openmw.async')
local I = require('openmw.interfaces') -- Added for script interface

-- Import our utility modules
local storage_module = require('scripts.TwentyTwentyObjects.util.storage')
local logger_module = require('scripts.TwentyTwentyObjects.util.logger')

-- Script-local variables, will be populated in onLoad
local profiles = {} -- Loaded profiles from storage
local activeProfileId = nil -- Store ID or unique name of the active profile, not index
local momentaryActiveProfileId = nil -- For momentary presses

local generalSettings = {} -- For logger debug state

-- Helper: Send event to player (rendering scripts)
local function sendToPlayerRenderer(event, data)
    local player = world.players[1]
    if player then
        player:sendEvent(event, data) -- Event names TTO_ShowHighlights, TTO_HideHighlights
        logger_module.debug(string.format('[Global] Sent event %s to player renderer with data: %s', event, tostring(data)))
    else
        logger_module.error('[Global] No player found to send event to renderer')
    end
end

-- Interface for HotkeyListener to call
I.TTO_Globals = {
    keyEvent = function(data) -- data will be {eventType = "press"/"release", profile = profileObject, key = keyEventObject}
        logger_module.debug("[Global] Received keyEvent: type=" .. data.eventType .. ", profile=" .. data.profile.name)

        local profile = data.profile
        local eventType = data.eventType

        if eventType == "press" then
            if profile.modeToggle then -- Toggle mode
                if activeProfileId == profile.name then -- This toggle profile is already active, turn it OFF
                    sendToPlayerRenderer('TTO_HideHighlights', {})
                    activeProfileId = nil
                    logger_module.debug('[Global] Toggle OFF for profile: ' .. profile.name)
                else -- A different profile is active, or no profile is active. Turn this one ON.
                    if activeProfileId then -- If something else was active, hide it first
                        sendToPlayerRenderer('TTO_HideHighlights', {})
                    end
                    sendToPlayerRenderer('TTO_ShowHighlights', { profile = profile })
                    activeProfileId = profile.name
                    logger_module.debug('[Global] Toggle ON for profile: ' .. profile.name)
                end
            else -- Momentary mode (hold-to-show)
                -- If another profile is active (e.g., a different momentary or a toggled one), hide it first.
                if activeProfileId then
                    sendToPlayerRenderer('TTO_HideHighlights', {})
                end
                if momentaryActiveProfileId and momentaryActiveProfileId ~= profile.name then
                     sendToPlayerRenderer('TTO_HideHighlights', {})
                end

                sendToPlayerRenderer('TTO_ShowHighlights', { profile = profile })
                momentaryActiveProfileId = profile.name 
                activeProfileId = profile.name -- Also set activeProfileId for momentary to simplify general hiding
                logger_module.debug('[Global] Momentary ON for profile: ' .. profile.name)
            end
        elseif eventType == "release" then
            if not profile.modeToggle and momentaryActiveProfileId == profile.name then
                -- This was a momentary profile being released
                sendToPlayerRenderer('TTO_HideHighlights', {})
                momentaryActiveProfileId = nil
                activeProfileId = nil -- Clear active id as well
                logger_module.debug('[Global] Momentary OFF for profile: ' .. profile.name)
            end
        end
    end
}

-- Engine handler: Game load (also serves as main initialization point)
local function onLoad(savedScriptData) -- OpenMW passes saved data to onLoad
    generalSettings = storage_module.get('general', { debug = false })
    logger_module.init(storage_module, generalSettings.debug)
    storage_module.initializeDefaults()
    profiles = storage_module.getProfiles()
    logger_module.debug(string.format('[Global] Loaded %d profiles', #profiles))

    activeProfileId = nil
    momentaryActiveProfileId = nil

    if savedScriptData then
        logger_module.debug("[Global] Processing saved script data...")
        activeProfileId = savedScriptData.activeProfileId
        momentaryActiveProfileId = savedScriptData.momentaryActiveProfileId
        -- If loading an active profile, may need to resend ShowHighlights to player renderer
        if activeProfileId then
            local foundProfile = nil
            for _, p in ipairs(profiles) do
                if p.name == activeProfileId then
                    foundProfile = p
                    break
                end
            end
            if foundProfile then
                logger_module.debug("[Global] Restoring active highlight for: " .. foundProfile.name)
                sendToPlayerRenderer('TTO_ShowHighlights', { profile = foundProfile })
            else
                activeProfileId = nil -- Profile no longer exists
            end
        end
    end

    storage_module.subscribe(async:callback(function(section, key)
        if key == 'profiles' or key == nil then
            profiles = storage_module.getProfiles()
            logger_module.debug('[Global] Profiles reloaded from storage. Count: ' .. #profiles)
            -- Check if activeProfileId is still valid
            if activeProfileId then
                local stillExists = false
                for _,p in ipairs(profiles) do if p.name == activeProfileId then stillExists = true break end end
                if not stillExists then
                    logger_module.debug("[Global] Active profile "..activeProfileId.." no longer exists after storage update. Hiding highlights.")
                    sendToPlayerRenderer('TTO_HideHighlights', {})
                    activeProfileId = nil
                    momentaryActiveProfileId = nil
                end
            end
        elseif key == 'general' or key == nil then
            local newGeneralSettings = storage_module.get('general', { debug = false })
            if newGeneralSettings.debug ~= generalSettings.debug then
                generalSettings.debug = newGeneralSettings.debug
                logger_module.init(storage_module, generalSettings.debug)
                logger_module.info("[Global] Logger debug state updated to: " .. tostring(generalSettings.debug))
            end
        end
    end))
    logger_module.info('[Global] Script initialized/loaded.')
end

local function onSave()
   return { activeProfileId = activeProfileId, momentaryActiveProfileId = momentaryActiveProfileId }
end

return {
    engineHandlers = {
        onLoad = onLoad,
        onSave = onSave
    },
    eventHandlers = {
        -- No longer directly handling TTO_ShowHighlights/TTO_HideHighlights from MENU scripts
        -- These are now internal commands to the player renderer scripts.
        -- The new TTO_GlobalKeyEvent is handled by the interface I.TTO_Globals.keyEvent
    }
}