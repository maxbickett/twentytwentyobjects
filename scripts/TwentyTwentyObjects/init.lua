-- init.lua: Global script for Twenty Twenty Objects Mod
-- Handles profile management and player events

local world = require('openmw.world')
local async = require('openmw.async')
-- local I = require('openmw.interfaces') -- No longer needed for defining an interface here

-- Import our utility modules
local storage_module = require('scripts.TwentyTwentyObjects.util.storage')
local logger_module = require('scripts.TwentyTwentyObjects.util.logger')

-- Script-local variables, will be populated in onLoad
local profiles = {} -- Loaded profiles from storage
local activeProfileName = nil -- Use profile name (string) for uniqueness
local momentaryActiveProfileName = nil -- For momentary presses

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

-- Event handler for key events from HotkeyListener
local function onGlobalKeyEvent(data) 
    logger_module.debug("[Global] Received TTO_GlobalKeyEvent: type=" .. data.eventType .. ", profile=" .. data.profile.name)

    local profile = data.profile
    local eventType = data.eventType

    if eventType == "press" then
        if profile.modeToggle then 
            if activeProfileName == profile.name then 
                sendToPlayerRenderer('TTO_HideHighlights', {})
                activeProfileName = nil
                logger_module.debug('[Global] Toggle OFF for profile: ' .. profile.name)
            else 
                if activeProfileName then 
                    sendToPlayerRenderer('TTO_HideHighlights', {})
                end
                sendToPlayerRenderer('TTO_ShowHighlights', { profile = profile })
                activeProfileName = profile.name
                logger_module.debug('[Global] Toggle ON for profile: ' .. profile.name)
            end
        else -- Momentary mode
            if activeProfileName and activeProfileName ~= profile.name then
                sendToPlayerRenderer('TTO_HideHighlights', {})
            end
            if momentaryActiveProfileName and momentaryActiveProfileName ~= profile.name then
                 sendToPlayerRenderer('TTO_HideHighlights', {})
            end

            sendToPlayerRenderer('TTO_ShowHighlights', { profile = profile })
            momentaryActiveProfileName = profile.name 
            activeProfileName = profile.name 
            logger_module.debug('[Global] Momentary ON for profile: ' .. profile.name)
        end
    elseif eventType == "release" then
        if not profile.modeToggle and momentaryActiveProfileName == profile.name then
            sendToPlayerRenderer('TTO_HideHighlights', {})
            momentaryActiveProfileName = nil
            activeProfileName = nil 
            logger_module.debug('[Global] Momentary OFF for profile: ' .. profile.name)
        end
    end
end

-- Engine handler: Game load (also serves as main initialization point)
local function onLoad(savedScriptData) -- OpenMW passes saved data to onLoad
    -- local engine_storage = require('openmw.storage') -- No longer needed here
    -- storage_module.init(engine_storage) -- No longer needed here

    generalSettings = storage_module.get('general', { debug = false })
    logger_module.init(storage_module, generalSettings.debug) -- Now init logger

    storage_module.initializeDefaults()
    profiles = storage_module.getProfiles()
    logger_module.debug(string.format('[Global] Loaded %d profiles', #profiles))

    -- push settings to menu interface if available
    local menuIface = require('openmw.interfaces').TTO_Menu
    if menuIface and menuIface.refresh then
        menuIface.refresh({
            profiles    = profiles,
            appearance  = storage_module.get('appearance', {}),
            performance = storage_module.get('performance', {}),
            general     = generalSettings
        })
    end

    activeProfileName = nil
    momentaryActiveProfileName = nil

    if savedScriptData then
        logger_module.debug("[Global] Processing saved script data...")
        activeProfileName = savedScriptData.activeProfileName
        momentaryActiveProfileName = savedScriptData.momentaryActiveProfileName
        -- If loading an active profile, may need to resend ShowHighlights to player renderer
        if activeProfileName then
            local foundProfile = nil
            for _, p in ipairs(profiles) do
                if p.name == activeProfileName then
                    foundProfile = p
                    break
                end
            end
            if foundProfile then
                logger_module.debug("[Global] Restoring active highlight for: " .. foundProfile.name)
                sendToPlayerRenderer('TTO_ShowHighlights', { profile = foundProfile })
            else
                activeProfileName = nil -- Profile no longer exists
            end
        end
    end

    storage_module.subscribe(async:callback(function(section, key)
        if key == 'profiles' or key == nil then
            profiles = storage_module.getProfiles()
            logger_module.debug('[Global] Profiles reloaded from storage. Count: ' .. #profiles)
            -- Check if activeProfileName is still valid
            if activeProfileName then
                local stillExists = false
                for _,p in ipairs(profiles) do if p.name == activeProfileName then stillExists = true break end end
                if not stillExists then
                    logger_module.debug("[Global] Active profile "..activeProfileName.." no longer exists after storage update. Hiding highlights.")
                    sendToPlayerRenderer('TTO_HideHighlights', {})
                    activeProfileName = nil
                    momentaryActiveProfileName = nil
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
   return { activeProfileName = activeProfileName, momentaryActiveProfileName = momentaryActiveProfileName }
end

local function map(tbl, fn)
    local out = {}
    for i,v in ipairs(tbl) do out[i] = fn(v) end
    return out
end

return {
    engineHandlers = {
        onLoad = onLoad,
        onSave = onSave
    },
    eventHandlers = {
        TTO_GlobalKeyEvent = onGlobalKeyEvent -- Added event handler
    }
}