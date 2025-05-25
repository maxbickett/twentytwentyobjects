-- settings.lua: Menu script for Twenty Twenty Objects Mod
-- Creates the configuration interface in OpenMW's settings menu

local ui = require('openmw.ui')
local I = require('openmw.interfaces')
local async = require('openmw.async')

-- Import utilities
local storage = require('scripts.TwentyTwentyObjects.util.storage')
local logger = require('scripts.TwentyTwentyObjects.util.logger')

-- Initialize logger
logger.init(storage)

-- Current state
local selectedProfileIndex = 1
local awaitingKeypress = false
local profiles = {}

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
    storage.setProfiles(profiles)
    logger.debug("Profiles saved to storage")
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
                                logger.debug("Waiting for keypress...")
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
    profiles = storage.getProfiles()
    
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

-- Handle keypress for hotkey binding
local function onKeyPress(key)
    if awaitingKeypress and settingsPage then
        local profile = profiles[selectedProfileIndex]
        if profile then
            profile.key = key.symbol
            profile.shift = key.withShift
            profile.ctrl = key.withCtrl
            profile.alt = key.withAlt
            saveProfiles()
            awaitingKeypress = false
            I.TwentyTwentyObjects.refreshUI()
        end
    end
end

-- Initialize on load
local function onInit()
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
    
    logger.info('Settings page registered')
end

return {
    interfaceName = 'TwentyTwentyObjects',
    interface = I.TwentyTwentyObjects,
    engineHandlers = {
        onInit = onInit,
        onKeyPress = onKeyPress
    }
}