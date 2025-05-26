-- settings.lua: Menu script for Twenty Twenty Objects Mod
-- Creates the configuration interface in OpenMW's settings menu

local ui = require('openmw.ui')
local I = require('openmw.interfaces')
local async = require('openmw.async')
local input = require('openmw.input') -- For key press handling WITHIN THE MENU (e.g. binding)
-- local world = require('openmw.world') -- REMOVED: Not available in MENU context

-- Import utilities
local storage_module = require('scripts.TwentyTwentyObjects.util.storage')
local logger_module = require('scripts.TwentyTwentyObjects.util.logger')

-- Forward declare variables
local profiles = {} -- Will be loaded in onInit
local generalSettings = {} -- For logger debug state

-- Current state (non-storage dependent)
local selectedProfileIndex = 1
local awaitingKeypress = false

-- Helper: Get key display name
local function getKeyDisplayName(profile)
    local parts = {}
    if profile.alt then table.insert(parts, "Alt") end
    if profile.ctrl then table.insert(parts, "Ctrl") end
    if profile.shift then table.insert(parts, "Shift") end
    table.insert(parts, string.upper(profile.key))
    return table.concat(parts, " + ")
end

-- Helper: Create a checkbox widget
local function createCheckbox(label, checked, onChange)
    return {
        type = ui.TYPE.Flex,
        props = {
            horizontal = true,
            arrange = ui.ALIGNMENT.Start
        },
        content = ui.content({
            {
                name = label .. "_checkbox",
                type = ui.TYPE.TextEdit,  -- Using TextEdit as checkbox placeholder
                props = {
                    text = checked and "[X]" or "[ ]",
                    readOnly = true
                },
                events = {
                    mouseClick = function()
                        onChange(not checked)
                    end
                }
            },
            {
                type = ui.TYPE.Text,
                props = {
                    text = " " .. label,
                    textSize = 14
                }
            }
        })
    }
end

-- Helper: Create a number input widget
local function createNumberInput(label, value, min, max, onChange)
    return {
        type = ui.TYPE.Flex,
        props = {
            horizontal = true,
            arrange = ui.ALIGNMENT.Start
        },
        content = ui.content({
            {
                type = ui.TYPE.Text,
                props = {
                    text = label .. ": ",
                    textSize = 14
                }
            },
            {
                name = label .. "_input",
                type = ui.TYPE.TextEdit,
                props = {
                    text = tostring(value),
                    textSize = 14
                },
                events = {
                    textChanged = function(newText)
                        local num = tonumber(newText)
                        if num and num >= min and num <= max then
                            onChange(num)
                        end
                    end
                }
            }
        })
    }
end

-- Helper: Save current profiles to storage
local function saveProfiles()
    if not storage_module then return end -- Guard
    storage_module.setProfiles(profiles)
    logger_module.debug("Profiles saved to storage")
end

-- Helper: Create profile editor layout
local function createProfileEditor()
    if #profiles == 0 then
        return {
            type = ui.TYPE.Text,
            props = {
                text = "No profiles configured. Click 'Add Profile' to create one.",
                textSize = 14
            }
        }
    end
    
    local profile = profiles[selectedProfileIndex]
    if not profile then
        return {
            type = ui.TYPE.Text,
            props = {
                text = "Select a profile to edit",
                textSize = 14
            }
        }
    end
    
    return {
        type = ui.TYPE.Flex,
        props = {
            vertical = true,
            arrange = ui.ALIGNMENT.Start
        },
        content = ui.content({
            -- Profile name
            {
                type = ui.TYPE.Flex,
                props = {
                    horizontal = true,
                    arrange = ui.ALIGNMENT.Start
                },
                content = ui.content({
                    {
                        type = ui.TYPE.Text,
                        props = {
                            text = "Name: ",
                            textSize = 16
                        }
                    },
                    {
                        name = "profile_name",
                        type = ui.TYPE.TextEdit,
                        props = {
                            text = profile.name,
                            textSize = 16
                        },
                        events = {
                            textChanged = function(newText)
                                profile.name = newText
                                saveProfiles()
                            end
                        }
                    }
                })
            },
            
            -- Hotkey
            {
                type = ui.TYPE.Flex,
                props = {
                    horizontal = true,
                    arrange = ui.ALIGNMENT.Start
                },
                content = ui.content({
                    {
                        type = ui.TYPE.Text,
                        props = {
                            text = "Hotkey: " .. getKeyDisplayName(profile) .. " ",
                            textSize = 16
                        }
                    },
                    {
                        type = ui.TYPE.Text,
                        props = {
                            text = awaitingKeypress and "[Press a key...]" or "[Click to change]",
                            textSize = 14,
                            textColor = ui.CONSOLE_COLOR.Info
                        },
                        events = {
                            mouseClick = function()
                                awaitingKeypress = true
                                logger_module.debug("Waiting for keypress...")
                            end
                        }
                    }
                })
            },
            
            -- Mode
            createCheckbox("Toggle Mode (vs Hold)", profile.modeToggle, function(checked)
                profile.modeToggle = checked
                saveProfiles()
            end),
            
            -- Radius
            createNumberInput("Radius", profile.radius, 50, 5000, function(value)
                profile.radius = value
                saveProfiles()
            end),
            
            -- Filters header
            {
                type = ui.TYPE.Text,
                props = {
                    text = "\nObject Filters:",
                    textSize = 16
                }
            },
            
            -- Actor filters
            {
                type = ui.TYPE.Text,
                props = {
                    text = "  Actors:",
                    textSize = 14
                }
            },
            createCheckbox("    NPCs", profile.filters.npcs, function(checked)
                profile.filters.npcs = checked
                saveProfiles()
            end),
            createCheckbox("    Creatures", profile.filters.creatures, function(checked)
                profile.filters.creatures = checked
                saveProfiles()
            end),
            
            -- Item filters
            {
                type = ui.TYPE.Text,
                props = {
                    text = "  Items:",
                    textSize = 14
                }
            },
            createCheckbox("    All Items", profile.filters.items, function(checked)
                profile.filters.items = checked
                -- If checking "All Items", enable all subtypes
                if checked then
                    profile.filters.weapons = true
                    profile.filters.armor = true
                    profile.filters.clothing = true
                    profile.filters.books = true
                    profile.filters.ingredients = true
                    profile.filters.misc = true
                end
                saveProfiles()
            end),
            createCheckbox("      Weapons", profile.filters.weapons, function(checked)
                profile.filters.weapons = checked
                -- If unchecking a subtype, uncheck "All Items"
                if not checked then
                    profile.filters.items = false
                end
                saveProfiles()
            end),
            createCheckbox("      Armor", profile.filters.armor, function(checked)
                profile.filters.armor = checked
                if not checked then
                    profile.filters.items = false
                end
                saveProfiles()
            end),
            createCheckbox("      Clothing", profile.filters.clothing, function(checked)
                profile.filters.clothing = checked
                if not checked then
                    profile.filters.items = false
                end
                saveProfiles()
            end),
            createCheckbox("      Books", profile.filters.books, function(checked)
                profile.filters.books = checked
                if not checked then
                    profile.filters.items = false
                end
                saveProfiles()
            end),
            createCheckbox("      Ingredients", profile.filters.ingredients, function(checked)
                profile.filters.ingredients = checked
                if not checked then
                    profile.filters.items = false
                end
                saveProfiles()
            end),
            createCheckbox("      Misc Items", profile.filters.misc, function(checked)
                profile.filters.misc = checked
                if not checked then
                    profile.filters.items = false
                end
                saveProfiles()
            end),
            
            -- World objects
            {
                type = ui.TYPE.Text,
                props = {
                    text = "  World Objects:",
                    textSize = 14
                }
            },
            createCheckbox("    Containers", profile.filters.containers, function(checked)
                profile.filters.containers = checked
                saveProfiles()
            end),
            createCheckbox("    Doors", profile.filters.doors, function(checked)
                profile.filters.doors = checked
                saveProfiles()
            end),
            createCheckbox("    Activators", profile.filters.activators, function(checked)
                profile.filters.activators = checked
                saveProfiles()
            end)
        })
    }
end

-- Helper: Create profile list
local function createProfileList()
    local items = {}
    for i, profile in ipairs(profiles) do
        table.insert(items, {
            type = ui.TYPE.Text,
            props = {
                text = (i == selectedProfileIndex and "> " or "  ") .. profile.name,
                textSize = 14,
                textColor = i == selectedProfileIndex and ui.CONSOLE_COLOR.Success or ui.CONSOLE_COLOR.Default
            },
            events = {
                mouseClick = function()
                    selectedProfileIndex = i
                    I.TwentyTwentyObjects.refreshUI()
                end
            }
        })
    end
    
    return {
        type = ui.TYPE.Flex,
        props = {
            vertical = true,
            arrange = ui.ALIGNMENT.Start
        },
        content = ui.content(items)
    }
end

-- Create the main settings layout
local function createSettingsLayout()
    return {
        type = ui.TYPE.Flex,
        props = {
            horizontal = true,
            arrange = ui.ALIGNMENT.Start
        },
        content = ui.content({
            -- Left panel: Profile list
            {
                type = ui.TYPE.Flex,
                props = {
                    vertical = true,
                    arrange = ui.ALIGNMENT.Start
                },
                content = ui.content({
                    {
                        type = ui.TYPE.Text,
                        props = {
                            text = "Profiles:",
                            textSize = 16
                        }
                    },
                    createProfileList(),
                    -- Buttons
                    {
                        type = ui.TYPE.Flex,
                        props = {
                            horizontal = true,
                            arrange = ui.ALIGNMENT.Start
                        },
                        content = ui.content({
                            {
                                type = ui.TYPE.Text,
                                props = {
                                    text = "[Add]",
                                    textSize = 14,
                                    textColor = ui.CONSOLE_COLOR.Info
                                },
                                events = {
                                    mouseClick = function()
                                        -- Add new profile
                                        table.insert(profiles, {
                                            name = "New Profile",
                                            key = 'h',
                                            shift = true, ctrl = false, alt = false,
                                            radius = 1000,
                                            filters = {},
                                            modeToggle = false
                                        })
                                        selectedProfileIndex = #profiles
                                        saveProfiles()
                                        I.TwentyTwentyObjects.refreshUI()
                                    end
                                }
                            },
                            {
                                type = ui.TYPE.Text,
                                props = {
                                    text = " [Remove]",
                                    textSize = 14,
                                    textColor = ui.CONSOLE_COLOR.Error
                                },
                                events = {
                                    mouseClick = function()
                                        if #profiles > 0 then
                                            table.remove(profiles, selectedProfileIndex)
                                            selectedProfileIndex = math.min(selectedProfileIndex, #profiles)
                                            saveProfiles()
                                            I.TwentyTwentyObjects.refreshUI()
                                        end
                                    end
                                }
                            }
                        })
                    }
                })
            },
            
            -- Spacer
            {
                type = ui.TYPE.Text,
                props = {
                    text = "    ",
                    textSize = 14
                }
            },
            
            -- Right panel: Profile editor
            {
                name = "profile_editor",
                type = ui.TYPE.Container,
                content = ui.content({
                    createProfileEditor()
                })
            }
        })
    }
end

-- Interface for updating UI
local settingsPage = nil

I.TwentyTwentyObjects = {
    refreshUI = function()
        if settingsPage then
            settingsPage.element.layout.content = ui.content({
                createSettingsLayout()
            })
            settingsPage.element:update()
        end
    end
}

-- Helper: Check if a key event matches a profile's hotkey
local function isProfileHotkey(profile, key)
    return (key.symbol == profile.key and
            key.withShift == profile.shift and
            key.withCtrl == profile.ctrl and
            key.withAlt == profile.alt)
end

-- Helper: Send event to global script
local function sendToGlobal(event, data)
    world.sendGlobalEvent('TTO_' .. event, data or {})
end

-- Engine handler: Key press
local function onKeyPress(key)
    -- Check all profiles for matching hotkey
    for index, profile in ipairs(profiles) do
        if isProfileHotkey(profile, key) then
            logger_module.info(string.format('Hotkey pressed for profile: %s', profile.name))
            
            if profile.modeToggle then
                -- Toggle mode
                sendToGlobal('ShowHighlights', { profile = profile, profileIndex = index })
            else
                -- Momentary mode (hold-to-show)
                sendToGlobal('ShowHighlights', { profile = profile, profileIndex = index })
            end
            
            return  -- Only one profile can match
        end
    end
end

-- Engine handler: Key release
local function onKeyRelease(key)
    -- Check all profiles for matching hotkey
    for index, profile in ipairs(profiles) do
        if not profile.modeToggle and isProfileHotkey(profile, key) then
            -- Only hide for non-toggle (momentary) profiles
            sendToGlobal('HideHighlights', {})
            return
        end
    end
end

-- Initialize on load
local function onInit()
    -- local engine_storage = require('openmw.storage') -- No longer needed here
    -- storage_module.init(engine_storage) -- No longer needed here

    generalSettings = storage_module.get('general', { debug = false })
    logger_module.init(storage_module, generalSettings.debug)

    profiles = storage_module.getProfiles()

    -- If profiles was empty (e.g. first run or reset), create default set
    if #profiles == 0 then
        logger_module.info("No profiles in storage for settings.lua. Initializing defaults.")
        -- This is where you might re-add the original default profiles if desired for this script
        -- For example:
        -- profiles = {
        --     { name = "Default Profile 1", key='h', shift=true, ...etc... },
        --     { name = "Default Profile 2", key='j', shift=false, ...etc... }
        -- }
        -- storage_module.setProfiles(profiles) -- And save them back
        -- For now, we assume that if it's empty, it's intended to be, or settings_improved created some.
    end
    
    -- Ensure selectedProfileIndex is valid after loading profiles
    if selectedProfileIndex > #profiles and #profiles > 0 then
        selectedProfileIndex = #profiles
    elseif #profiles == 0 then
        selectedProfileIndex = 1 -- Or adjust UI to show "No profiles, add one"
    end

    -- Subscribe to storage changes to keep local 'profiles' table synced
    -- This is important if another script (like init.lua or a future one) modifies profiles.
    storage_module.subscribe(async:callback(function(section, key)
        if key == 'profiles' or key == nil then
            logger_module.debug("[settings.lua] Profiles changed in storage, reloading.")
            profiles = storage_module.getProfiles()
            if settingsPage and settingsPage.element then -- Refresh UI if page exists
                I.TwentyTwentyObjects.refreshUI()
            end
        end
    end))

    -- Register settings page
    settingsPage = ui.registerSettingsPage({
        key = 'TwentyTwentyObjects',
        l10n = 'TwentyTwentyObjects',
        name = 'Twenty Twenty Objects',
        element = ui.create({
            type = ui.TYPE.Container,
            content = ui.content({
                createSettingsLayout()
            })
        })
    })
    
    logger_module.info('Settings page registered')
end

return {
    interfaceName = 'TwentyTwentyObjects',
    interface = I.TwentyTwentyObjects,
    engineHandlers = {
        onInit = onInit
        -- onKeyPress = onKeyPress, -- REMOVED: Game hotkeys belong in PLAYER script
        -- onKeyRelease = onKeyRelease -- REMOVED: Game hotkeys belong in PLAYER script
    }
}