local input_module = require('openmw.input')
local storage_module = require('scripts.TwentyTwentyObjects.util.storage')
local core_module = require('openmw.core') -- For sendGlobalEvent
local logger_module = require('scripts.TwentyTwentyObjects.util.logger')

-- Forward declare generalSettings for logger
local generalSettings = {}

-- Helper: Check if a key event matches a profile's hotkey
local function isProfileHotkey(profile, keyEvent)
    if not profile or not profile.key or not keyEvent or not keyEvent.symbol then
        -- logger_module.debug("[HotkeyListener] isProfileHotkey: Invalid profile or keyEvent data.")
        return false
    end
    return (keyEvent.symbol == profile.key and
            (keyEvent.withShift == (profile.shift or false)) and
            (keyEvent.withCtrl == (profile.ctrl or false)) and
            (keyEvent.withAlt == (profile.alt or false)))
end

local function onKeyPress(keyEvent)
    -- Profiles are loaded here to ensure the latest version is used on each key press.
    -- This avoids issues if profiles change in settings menu while game is running.
    local currentProfiles = storage_module.getProfiles()
    if not currentProfiles or #currentProfiles == 0 then
        -- logger_module.debug("[HotkeyListener] onKeyPress: No profiles loaded.")
        return
    end

    -- logger_module.debug("[HotkeyListener] KeyPress: " .. keyEvent.symbol)

    for _, profile in ipairs(currentProfiles) do
        if isProfileHotkey(profile, keyEvent) then
            -- logger_module.debug("[HotkeyListener] Matched profile: " .. profile.name)
            core_module.sendGlobalEvent("TTO_GlobalKeyEvent", { eventType = "press", profile = profile, key = keyEvent })
            return -- Process only the first matched profile
        end
    end
end

local function onKeyRelease(keyEvent)
    local currentProfiles = storage_module.getProfiles()
    if not currentProfiles or #currentProfiles == 0 then
        return
    end

    -- logger_module.debug("[HotkeyListener] KeyRelease: " .. keyEvent.symbol)

    for _, profile in ipairs(currentProfiles) do
        if isProfileHotkey(profile, keyEvent) then
            -- logger_module.debug("[HotkeyListener] Matched profile for release: " .. profile.name)
            core_module.sendGlobalEvent("TTO_GlobalKeyEvent", { eventType = "release", profile = profile, key = keyEvent })
            return -- Process only the first matched profile
        end
    end
end

local function onLoad()
    -- local engine_storage = require('openmw.storage') -- No longer needed here
    -- storage_module.init(engine_storage) -- No longer needed here

    generalSettings = storage_module.get('general', { debug = false })
    logger_module.init(generalSettings.debug)
    logger_module.info("[HotkeyListener] Script loaded and initialized.")
end

return {
    engineHandlers = {
        onKeyPress = onKeyPress,
        onKeyRelease = onKeyRelease,
        onLoad = onLoad
    }
} 