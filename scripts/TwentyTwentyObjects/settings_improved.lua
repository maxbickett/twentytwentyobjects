print("[TTO DEBUG SETTINGS_IMPROVED] Script parsing started.")
-- settings_improved.lua: Enhanced menu script for Twenty Twenty Objects Mod
-- Creates an improved configuration interface with quick-start presets

local ui = require('openmw.ui')
local I = require('openmw.interfaces')
local async = require('openmw.async')
local input = require('openmw.input') -- For key press handling WITHIN THE MENU (e.g. binding)
-- Attempt to load the optional helper library `openmw_aux.util` for its `map` helper.
-- If it isn't present (typical on fresh installs), gracefully fall back to a minimal local implementation
local ok, auxUtil = pcall(require, 'openmw_aux.util')
local util = require('openmw.util')
local col = util.color.rgb
local v2 = util.vector2  -- Shorthand like PCP uses

-- Make any given layout fill the available space and become scrollable so content never overlaps
local function scrollWrap(innerLayout)
    return {
        type = ui.TYPE.Container,
        props = { scrollable = true, relativeSize = v2(1,1) },
        content = ui.content({ innerLayout })
    }
end

local logger_module = require('scripts.TwentyTwentyObjects.util.logger')
local storage_module = require('scripts.TwentyTwentyObjects.util.storage') -- ADDED THIS
-- storage_module will be required later when data push comes from Global -- This comment is now outdated

-- Initialize logger with default settings
logger_module.init(false) -- Start with debug off

local map  ---@type fun(tbl:table, fn:fun(any):any):table
if ok and auxUtil and auxUtil.map then
    map = auxUtil.map
else
    -- Simple fallback – build a new array by applying fn to each element (ipairs order)
    map = function(tbl, fn)
        local out = {}
        for i, v in ipairs(tbl or {}) do
            out[i] = fn(v)
        end
        return out
    end
end
-- `auxUtil` is only needed for `map`; we don't keep a global reference if the require failed.

-- UI Colors
local DEFAULT_TEXT_COLOR    = col(0.9, 0.9, 0.9)    -- Light gray for better visibility
local HEADER_TEXT_COLOR     = col(1.0, 0.9, 0.75)   -- Slightly brighter for main headers
local TAB_ACTIVE_BG_COLOR   = col(0.2, 0.3, 0.4)
local TAB_INACTIVE_BG_COLOR = col(0.1, 0.1, 0.1, 0.5)
local TAB_ACTIVE_TEXT_COLOR = col(1, 1, 1)
local TAB_INACTIVE_TEXT_COLOR = col(0.8, 0.8, 0.8)
local CLICKABLE_TEXT_COLOR  = col(0.7, 0.85, 1)     -- Light blue for clickable things
local VALUE_TEXT_COLOR      = col(0.8, 0.95, 0.8)   -- Light green for values
local HOVER_BG_COLOR        = col(0.3, 0.4, 0.5, 0.8) -- For hover effects

-- Preset configurations for common use cases
local PRESETS = {
    {
        name = "Loot Hunter",
        description = "Highlights valuable items and containers",
        icon = "🗡️",
        shows = "Items, Weapons, Armor, Containers",
        profile = {
            name = "Loot Hunter",
            key = 'm', shift = false, ctrl = false, alt = false,
            radius = 1200,
            filters = {
                items = true, weapons = true, armor = true, 
                clothing = true, misc = true,
                containers = true
            },
            modeToggle = false
        }
    },
    {
        name = "NPC Tracker", 
        description = "Find NPCs and creatures in towns or dungeons",
        icon = "👥",
        shows = "NPCs only",
        profile = {
            name = "NPC Tracker",
            key = 'n', shift = false, ctrl = false, alt = false,
            radius = 800,
            filters = {npcs = true, creatures = false},
            modeToggle = true
        }
    },
    {
        name = "Thief's Eye",
        description = "Spot valuable items in shops and homes",
        icon = "💎",
        shows = "All valuable items",
        profile = {
            name = "Thief's Eye",
            key = 'b', shift = false, ctrl = false, alt = false,
            radius = 600,
            filters = {
                items = true, weapons = true, armor = true,
                clothing = true, books = true, misc = true
            },
            modeToggle = false
        }
    },
    {
        name = "Dungeon Delver",
        description = "Everything useful in dark dungeons",
        icon = "🏛️",
        shows = "NPCs, Creatures, Containers, Doors, Items",
        profile = {
            name = "Dungeon Delver",
            key = 'v', shift = false, ctrl = false, alt = false,
            radius = 1500,
            filters = {
                npcs = true, creatures = true,
                containers = true, doors = true,
                items = true, weapons = true, armor = true
            },
            modeToggle = false
        }
    }
}

-- Tab definitions
local TABS = {
    {id = "presets", label = "Quick Start", icon = "⚡"},
    {id = "profiles", label = "My Profiles", icon = "📋"},
    {id = "appearance", label = "Appearance", icon = "🎨"},
    {id = "performance", label = "Performance", icon = "⚙️"},
    {id = "help", label = "Help", icon = "❓"}
}

-- Forward declare variables that will be initialized by the refresh event
local profiles = {}
local appearanceSettings = {
    labelStyle = "native",
    textSize = "medium",
    lineStyle = "straight",
    lineColor = {r=0.8, g=0.8, b=0.8, a=0.7},
    backgroundColor = {r=0, g=0, b=0, a=0.5},
    showIcons = true,
    enableAnimations = true,
    animationSpeed = "normal",
    fadeDistance = true,
    groupSimilar = false,
    opacity = 0.8
}
local performanceSettings = {
    maxLabels = 20,
    updateInterval = "medium",
    scanInterval = "medium",
    distanceCulling = true,
    cullDistance = 2000,
    occlusionChecks = "basic",
    smartGrouping = false
}
local generalSettings = {
    debug = false
} 

-- UI State
local currentTab = "presets"  
local selectedProfileIndex = 1
local awaitingKeypress = false
-- local showingPreview = false -- Not currently used in the restored logic, can be added if needed

-- Root UI element of the settings page (assigned in onInit)
local rootElement = nil

-- Helper to wrap UI event callbacks (OpenMW requires async:callback in MENU context)
local callbackWrapCount = 0
local c = function(fn) 
    callbackWrapCount = callbackWrapCount + 1
    -- Only log every 10th callback to reduce spam
    if callbackWrapCount % 10 == 1 then
        logger_module.debug("[Settings] Creating async callback wrapper #" .. callbackWrapCount)
    end
    if not async then
        logger_module.error("[Settings] ERROR: async is nil!")
        return fn
    end
    if not async.callback then
        logger_module.error("[Settings] ERROR: async.callback is nil!")
        return fn
    end
    local wrapped = async:callback(fn)
    return wrapped
end

-- Forward declarations for all helper functions
local createAppearanceSettings, createPerformanceSettings, createHelpContent, createProfileList, createSettingsSection
local createToggle, createRangeSlider, createCheckbox, createFilterCategories, createStylePreview

-- Helper: Save current profiles to storage
local function saveProfiles()
    if not storage_module then return end -- Guard against calls before onInit
    -- Menu context is read-only for storage; send to global script for saving
    local core = require('openmw.core')
    core.sendGlobalEvent('TTO_UpdateProfiles', {profiles = profiles})
    logger_module.debug("Profiles update event sent to global script")
end

-- Helper: Save appearance settings
local function saveAppearanceSettings()
    if not storage_module then return end
    -- Menu context is read-only for storage; send to global script for saving
    local core = require('openmw.core')
    core.sendGlobalEvent('TTO_UpdateAppearance', {appearance = appearanceSettings})
    logger_module.debug("Appearance settings update event sent to global script")
end

-- Helper: Save performance settings
local function savePerformanceSettings()
    if not storage_module then return end
    -- Menu context is read-only for storage; send to global script for saving
    local core = require('openmw.core')
    core.sendGlobalEvent('TTO_UpdatePerformance', {performance = performanceSettings})
    logger_module.debug("Performance settings update event sent to global script")
end

-- Helper: Save general settings
local function saveGeneralSettings()
    if not storage_module then return end
    -- Menu context is read-only for storage; send to global script for saving
    local core = require('openmw.core')
    core.sendGlobalEvent('TTO_UpdateGeneral', {general = generalSettings})
    logger_module.debug("General settings update event sent to global script")
end

-- Helper: Create tab button
local function createTabButton(tab, isActive)
    return {
        type = ui.TYPE.Container,
        props = {
            backgroundColor = isActive and TAB_ACTIVE_BG_COLOR or TAB_INACTIVE_BG_COLOR,
            borderColor = isActive and {0.4, 0.5, 0.6, 1} or {0.2, 0.2, 0.2, 1},
            borderSize = isActive and 2 or 1,
            borderRadius = {4, 4, 0, 0}, -- Rounded top corners only
            padding = {horizontal = 15, vertical = 8},
            margin = {right = 2},
            minWidth = 100
        },
        content = ui.content({
            {
                type = ui.TYPE.Text,
                props = {
                    text = tab.icon .. " " .. tab.label,
                    textSize = 16,
                    textColor = isActive and TAB_ACTIVE_TEXT_COLOR or TAB_INACTIVE_TEXT_COLOR,
                    textAlign = ui.ALIGNMENT.Center
                }
            }
        }),
        events = {
            mouseClick = c(function()
                currentTab = tab.id
                I.TwentyTwentyObjects.refreshUI()
            end),
            mouseEnter = c(function(e)
                if not isActive then
                    e.target.props.backgroundColor = HOVER_BG_COLOR
                    e.target:update()
                end
            end),
            mouseLeave = c(function(e)
                if not isActive then
                    e.target.props.backgroundColor = TAB_INACTIVE_BG_COLOR
                    e.target:update()
                end
            end)
        }
    }
end

-- Create preset card
local function createPresetCard(preset)
    return {
        type = ui.TYPE.Container,
        props = {
            backgroundColor = {0.1, 0.1, 0.1, 0.8},
            borderColor = {0.3, 0.3, 0.3, 1},
            borderSize = 2,
            padding = 15,
            margin = {bottom = 8},
            minWidth = 250,
            autoSize = true
        },
        content = ui.content({
            {
                type = ui.TYPE.Flex,
                props = {
                    vertical = true,
                    arrange = ui.ALIGNMENT.Start,
                    autoSize = true
                },
                content = ui.content({
                    {
                        type = ui.TYPE.Text,
                        props = {
                            text = preset.name,
                            textSize = 18,
                            textColor = HEADER_TEXT_COLOR,
                            margin = {bottom = 5}
                        }
                    },
                    {
                        type = ui.TYPE.Text,
                        props = {
                            text = preset.description,
                            textSize = 14,
                            textColor = DEFAULT_TEXT_COLOR,
                            margin = {bottom = 10}
                        }
                    },
                    {
                        type = ui.TYPE.Container,
                        props = {
                            backgroundColor = {0.2, 0.2, 0.2, 0.5},
                            padding = 10,
                            borderRadius = 4,
                            margin = {bottom = 10},
                            autoSize = true
                        },
                        content = ui.content({
                            {
                                type = ui.TYPE.Text,
                                props = {
                                    text = "Shows: " .. preset.shows,
                                    textSize = 12,
                                    textColor = VALUE_TEXT_COLOR
                                }
                            }
                        })
                    },
                    {
                        type = ui.TYPE.Container,
                        props = {
                            backgroundColor = {0.2, 0.3, 0.4, 1},
                            padding = {horizontal = 20, vertical = 10},
                            borderRadius = 4,
                            autoSize = true
                        },
                        content = ui.content({
                            {
                                type = ui.TYPE.Text,
                                props = {
                                    text = "Use This Preset",
                                    textSize = 14,
                                    textAlign = ui.ALIGNMENT.Center,
                                    textColor = TAB_ACTIVE_TEXT_COLOR
                                }
                            }
                        }),
                        events = {
                            mouseClick = c(function()
                                -- Add preset as new profile
                                table.insert(profiles, preset.profile)
                                selectedProfileIndex = #profiles
                                currentTab = "profiles"
                                saveProfiles()
                                I.TwentyTwentyObjects.refreshUI()
                            end),
                            mouseEnter = c(function(e)
                                e.target.props.backgroundColor = HOVER_BG_COLOR
                                e.target:update()
                            end),
                            mouseLeave = c(function(e)
                                e.target.props.backgroundColor = {0.2, 0.3, 0.4, 1}
                                e.target:update()
                            end)
                        }
                    }
                })
            }
        })
    }
end

-- Helper: Create visual key display
local function createKeyDisplay(profile)
    local keyParts = {}
    if profile.alt then table.insert(keyParts, "Alt") end
    if profile.ctrl then table.insert(keyParts, "Ctrl") end  
    if profile.shift then table.insert(keyParts, "Shift") end
    table.insert(keyParts, string.upper(profile.key))
    
    return {
        type = ui.TYPE.Container,
        props = {
            backgroundColor = {0.2, 0.2, 0.2, 1},
            borderColor = {0.4, 0.4, 0.4, 1},
            borderSize = 2,
            padding = 10,
            borderRadius = 4
        },
        content = ui.content({
            {
                type = ui.TYPE.Text,
                props = {
                    text = table.concat(keyParts, " + "),
                    textSize = 18,
                    textColor = col(1, 1, 0.8), -- Keep this bright yellow for keys
                    font = "MonoFont"  -- If available
                }
            }
        })
    }
end

-- Create content based on current tab
local function createTabContent()
    print("[TTO DEBUG SETTINGS_IMPROVED] createTabContent() called for tab: " .. currentTab)
    if currentTab == "presets" then
        local presetCards = map(PRESETS or {}, createPresetCard)
        -- Add a test button at the end
        table.insert(presetCards, {
            type = ui.TYPE.Container,
            props = {
                backgroundColor = {0.5, 0.2, 0.2, 1},
                padding = 20,
                margin = {top = 20},
                autoSize = true
            },
            content = ui.content({
                {
                    type = ui.TYPE.Text,
                    props = {
                        text = "TEST BUTTON - Click Me!",
                        textSize = 16,
                        textColor = col(1, 1, 1)
                    }
                }
            }),
            events = {
                mouseClick = c(function()
                    print("[TTO DEBUG SETTINGS_IMPROVED] TEST BUTTON CLICKED!")
                end)
            }
        })
        
        return { 
            type = ui.TYPE.Flex, 
            props = { 
                vertical = true,
                arrange = ui.ALIGNMENT.Start,
                autoSize = true
            }, 
            content = ui.content(presetCards) 
        }
    elseif currentTab == "profiles" then
        if not profiles or #profiles == 0 then return {type=ui.TYPE.Text, props={text="No profiles yet.", textColor = DEFAULT_TEXT_COLOR}} end
        local profile = profiles[selectedProfileIndex]
        if not profile then return {type=ui.TYPE.Text, props={text="Selected profile not found.", textColor = DEFAULT_TEXT_COLOR}} end
        return { 
            type = ui.TYPE.Flex, 
            props = { 
                horizontal = true,
                arrange = ui.ALIGNMENT.Start
            }, 
            content = ui.content({ 
                {
                    type = ui.TYPE.Container,
                    props = {
                        minWidth = 200,
                        margin = {right = 20}
                    },
                    content = ui.content({ createProfileList() })
                },
                {
                    type = ui.TYPE.Container,
                    props = {
                        relativeSize = v2(1, 0)  -- Take remaining width
                    },
                    content = ui.content({ createSettingsSection(profile) })
                }
            }) 
        }
    elseif currentTab == "appearance" then
        return createAppearanceSettings()
    elseif currentTab == "performance" then
        return createPerformanceSettings()
    elseif currentTab == "help" then
        return createHelpContent()
    end
    return {type=ui.TYPE.Text, props={text="Unknown tab: " .. currentTab, textColor = DEFAULT_TEXT_COLOR}}
end

-- Create settings section with better organization
createSettingsSection = function(profile)
    -- Ensure profile has filters
    if not profile.filters then
        profile.filters = {}
    end
    
    return {
        type = ui.TYPE.Flex,
        props = {
            vertical = true,
            arrange = ui.ALIGNMENT.Start,
            maxWidth = 600  -- Prevent content from stretching too wide
        },
        content = ui.content({
            -- Hotkey display
            {
                type = ui.TYPE.Container,
                props = {
                    backgroundColor = {0.1, 0.1, 0.1, 0.8},
                    padding = 15,
                    margin = {bottom = 10},
                    borderColor = {0.4, 0.4, 0.4, 1},
                    borderSize = 1
                },
                content = ui.content({
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
                                    text = "Hotkey",
                                    textSize = 16,
                                    margin = {bottom = 10},
                                    textColor = HEADER_TEXT_COLOR
                                }
                            },
                            {
                                type = ui.TYPE.Flex,
                                props = {
                                    horizontal = true,
                                    arrange = ui.ALIGNMENT.Start
                                },
                                content = ui.content({
                                    createKeyDisplay(profile),
                                    {
                                        type = ui.TYPE.Widget,
                                        props = {
                                            relativeSize = v2(1, 0)  -- Spacer that takes up remaining horizontal space
                                        }
                                    },
                                    {
                                        type = ui.TYPE.Container,
                                        props = {
                                            backgroundColor = {0.2, 0.2, 0.4, 1},
                                            padding = {horizontal = 15, vertical = 8},
                                            borderRadius = 4
                                        },
                                        content = ui.content({
                                            {
                                                type = ui.TYPE.Text,
                                                props = {
                                                    text = "Change Key",
                                                    textSize = 14,
                                                    textColor = CLICKABLE_TEXT_COLOR
                                                }
                                            }
                                        }),
                                        events = {
                                            mouseClick = c(function()
                                                -- TODO: Implement key binding
                                                print("[TTO DEBUG] Key binding not yet implemented")
                                            end),
                                            mouseEnter = c(function(e)
                                                e.target.props.backgroundColor = HOVER_BG_COLOR
                                                e.target:update()
                                            end),
                                            mouseLeave = c(function(e)
                                                e.target.props.backgroundColor = {0.2, 0.2, 0.4, 1}
                                                e.target:update()
                                            end)
                                        }
                                    }
                                })
                            }
                        })
                    }
                })
            },
            -- Basic settings
            {
                type = ui.TYPE.Container,
                props = {
                    backgroundColor = {0.05, 0.05, 0.05, 0.5},
                    padding = 15,
                    margin = {bottom = 10}
                },
                content = ui.content({
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
                                    text = "Basic Settings",
                                    textSize = 18,
                                    margin = {bottom = 10},
                                    textColor = HEADER_TEXT_COLOR
                                }
                            },
                            -- Mode toggle
                            createToggle("Hold to Show", not profile.modeToggle, function(value)
                                profile.modeToggle = not value
                                saveProfiles() -- Saves the entire 'profiles' table
                            end),
                            -- Range slider with visual indicator
                            createRangeSlider("Detection Range", profile.radius, 100, 3000, function(value)
                                profile.radius = value
                                saveProfiles() -- Saves the entire 'profiles' table
                            end)
                        })
                    }
                })
            },
            
            -- Filter settings with categories
            {
                type = ui.TYPE.Container,
                props = {
                    backgroundColor = {0.05, 0.05, 0.05, 0.5},
                    padding = 15
                },
                content = ui.content({
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
                                    text = "What to Highlight",
                                    textSize = 18,
                                    margin = {bottom = 10},
                                    textColor = HEADER_TEXT_COLOR
                                }
                            },
                            createFilterCategories(profile.filters)
                        })
                    }
                })
            }
        })
    }
end

-- Create visual toggle switch
createToggle = function(label, value, onChange)
    return {
        type = ui.TYPE.Flex,
        props = {
            horizontal = true,
            arrange = ui.ALIGNMENT.Start,
            margin = {bottom = 10}
        },
        content = ui.content({
            {
                type = ui.TYPE.Text,
                props = {
                    text = label .. ": ",
                    textSize = 14,
                    minWidth = 150,
                    textColor = DEFAULT_TEXT_COLOR
                }
            },
            {
                type = ui.TYPE.Container,
                props = {
                    backgroundColor = value and {0.2, 0.4, 0.2, 1} or {0.3, 0.2, 0.2, 1},
                    minWidth = 60,
                    height = 25,
                    borderRadius = 12,
                    padding = 2
                },
                content = ui.content({
                    {
                        type = ui.TYPE.Container,
                        props = {
                            backgroundColor = {1, 1, 1, 1},
                            width = 21,
                            height = 21,
                            borderRadius = 10,
                            position = value and v2(37, 0) or v2(0, 0)
                        }
                    }
                }),
                events = {
                    mouseClick = c(function()
                        onChange(not value)
                        I.TwentyTwentyObjects.refreshUI()
                    end)
                }
            }
        })
    }
end

-- Create range slider with visual feedback
createRangeSlider = function(label, value, min, max, onChange)
    -- Guard against nil value
    if not value then value = min end
    local percent = (value - min) / (max - min)
    
    return {
        type = ui.TYPE.Flex,
        props = {
            vertical = true,
            margin = {bottom = 15}
        },
        content = ui.content({
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
                            text = label,
                            textSize = 14,
                            textColor = DEFAULT_TEXT_COLOR
                        }
                    },
                    {
                        type = ui.TYPE.Widget,
                        props = {
                            relativeSize = v2(1, 0)  -- Spacer that takes up remaining horizontal space
                        }
                    },
                    {
                        type = ui.TYPE.Text,
                        props = {
                            text = tostring(math.floor(value)) .. " units",
                            textSize = 14,
                            textColor = VALUE_TEXT_COLOR
                        }
                    }
                })
            },
            {
                type = ui.TYPE.Container,
                props = {
                    backgroundColor = {0.2, 0.2, 0.2, 1},
                    height = 8,
                    borderRadius = 4,
                    margin = {top = 5}
                },
                content = ui.content({
                    {
                        type = ui.TYPE.Container,
                        props = {
                            backgroundColor = {0.4, 0.6, 0.8, 1},
                            height = 8,
                            width = percent * 300,  -- Assuming 300px width
                            borderRadius = 4
                        }
                    }
                }),
                events = {
                    mouseClick = c(function(e)
                        -- Simple click position to value conversion
                        local clickPercent = e.position.x / 300
                        local newValue = min + (max - min) * clickPercent
                        onChange(math.floor(newValue))
                        I.TwentyTwentyObjects.refreshUI()
                    end)
                }
            }
        })
    }
end

-- Create filter categories with visual grouping
createFilterCategories = function(filters)
    return {
        type = ui.TYPE.Flex,
        props = {
            vertical = true,
            arrange = ui.ALIGNMENT.Start
        },
        content = ui.content({
            -- Characters category
            {
                type = ui.TYPE.Container,
                props = {
                    margin = {bottom = 15}
                },
                content = ui.content({
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
                                    text = "📍 Characters",
                                    textSize = 16,
                                    textColor = HEADER_TEXT_COLOR, -- Use header for category
                                    margin = {bottom = 5}
                                }
                            },
                            createCheckbox("NPCs", filters.npcs, function(v)
                                filters.npcs = v
                                saveProfiles() -- Saves the entire 'profiles' table
                            end),
                            createCheckbox("Creatures", filters.creatures, function(v)
                                filters.creatures = v
                                saveProfiles() -- Saves the entire 'profiles' table
                            end)
                        })
                    }
                })
            },
            
            -- Items category
            {
                type = ui.TYPE.Container,
                props = {
                    margin = {bottom = 15}
                },
                content = ui.content({
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
                                    text = "🎒 Items",
                                    textSize = 16,
                                    textColor = HEADER_TEXT_COLOR, -- Use header for category
                                    margin = {bottom = 5}
                                }
                            },
                            createCheckbox("All Items", filters.items, function(v)
                                filters.items = v
                                if v then
                                    -- Enable all subtypes
                                    filters.weapons = true
                                    filters.armor = true
                                    filters.clothing = true
                                    filters.books = true
                                    filters.ingredients = true
                                    filters.misc = true
                                end
                                saveProfiles() -- Saves the entire 'profiles' table
                                I.TwentyTwentyObjects.refreshUI()
                            end),
                            -- Indented subtypes
                            {
                                type = ui.TYPE.Flex,
                                props = {
                                    vertical = true,
                                    arrange = ui.ALIGNMENT.Start,
                                    margin = {left = 20}
                                },
                                content = ui.content({
                                    createCheckbox("Weapons", filters.weapons, function(v)
                                        filters.weapons = v
                                        if not v then filters.items = false end
                                        saveProfiles() -- Saves the entire 'profiles' table
                                    end),
                                    createCheckbox("Armor", filters.armor, function(v)
                                        filters.armor = v
                                        if not v then filters.items = false end
                                        saveProfiles() -- Saves the entire 'profiles' table
                                    end),
                                    createCheckbox("Books", filters.books, function(v)
                                        filters.books = v
                                        if not v then filters.items = false end
                                        saveProfiles() -- Saves the entire 'profiles' table
                                    end)
                                })
                            }
                        })
                    }
                })
            },
            
            -- World objects category
            {
                type = ui.TYPE.Container,
                content = ui.content({
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
                                    text = "🏛️ World Objects",
                                    textSize = 16,
                                    textColor = HEADER_TEXT_COLOR, -- Use header for category
                                    margin = {bottom = 5}
                                }
                            },
                            createCheckbox("Containers", filters.containers, function(v)
                                filters.containers = v
                                saveProfiles() -- Saves the entire 'profiles' table
                            end),
                            createCheckbox("Doors", filters.doors, function(v)
                                filters.doors = v
                                saveProfiles() -- Saves the entire 'profiles' table
                            end)
                        })
                    }
                })
            }
        })
    }
end

-- Create visual checkbox
createCheckbox = function(label, checked, onChange)
    return {
        type = ui.TYPE.Flex,
        props = {
            horizontal = true,
            arrange = ui.ALIGNMENT.Start,
            margin = {bottom = 5}
        },
        content = ui.content({
            {
                type = ui.TYPE.Container,
                props = {
                    backgroundColor = checked and col(0.2, 0.4, 0.2, 1) or col(0.2, 0.2, 0.2, 1),
                    borderColor = col(0.4, 0.4, 0.4, 1),
                    borderSize = 1,
                    width = 18,
                    height = 18,
                    margin = {right = 8}
                },
                content = ui.content({
                    checked and {
                        type = ui.TYPE.Text,
                        props = {
                            text = "✓",
                            textSize = 14,
                            textAlign = ui.ALIGNMENT.Center,
                            textColor = TAB_ACTIVE_TEXT_COLOR -- White checkmark
                        }
                    } or {}
                }),
                events = {
                    mouseClick = c(function()
                        onChange(not checked)
                        I.TwentyTwentyObjects.refreshUI()
                    end)
                }
            },
            {
                type = ui.TYPE.Text,
                props = {
                    text = label,
                    textSize = 14,
                    textColor = DEFAULT_TEXT_COLOR
                }
            }
        })
    }
end

-- Create appearance settings
createAppearanceSettings = function()

    return {
        type = ui.TYPE.Flex,
        props = {
            vertical = true,
            arrange = ui.ALIGNMENT.Start
        },
        content = ui.content({
            {
                type = ui.TYPE.Text,
                props = {
                    text = "Customize how labels look",
                    textSize = 16,
                    margin = {bottom = 20},
                    textColor = DEFAULT_TEXT_COLOR
                }
            },
            
            -- Label style selector
            {
                type = ui.TYPE.Container,
                props = {
                    backgroundColor = {0.05, 0.05, 0.05, 0.5},
                    padding = 15,
                    margin = {bottom = 10}
                },
                content = ui.content({
                    {
                        type = ui.TYPE.Text,
                        props = {
                            text = "Label Style",
                            textSize = 16,
                            margin = {bottom = 10},
                            textColor = HEADER_TEXT_COLOR
                        }
                    },
                    -- Style previews
                    {
                        type = ui.TYPE.Flex,
                        props = {
                            horizontal = true,
                            arrange = ui.ALIGNMENT.Start
                        },
                        content = ui.content({
                            createStylePreview("Outlined", "outlined", appearanceSettings.labelStyle == "outlined"),
                            createStylePreview("Solid BG", "solid", appearanceSettings.labelStyle == "solid"),
                            createStylePreview("Minimal", "minimal", appearanceSettings.labelStyle == "minimal")
                        })
                    }
                })
            },
            
            -- Other appearance options
            createToggle("Fade with distance", appearanceSettings.fadeDistance, function(v)
                appearanceSettings.fadeDistance = v
                saveAppearanceSettings()
            end),
            
            createToggle("Group similar items", appearanceSettings.groupSimilar, function(v)
                appearanceSettings.groupSimilar = v
                saveAppearanceSettings()
            end),
            
            createRangeSlider("Label opacity", appearanceSettings.opacity * 100, 30, 100, function(v)
                appearanceSettings.opacity = v / 100
                saveAppearanceSettings()
            end)
        })
    }
end

-- Create style preview card
createStylePreview = function(name, style, isSelected)
    return {
        type = ui.TYPE.Container,
        props = {
            backgroundColor = isSelected and {0.2, 0.3, 0.4, 1} or {0.1, 0.1, 0.1, 1},
            borderColor = isSelected and {0.4, 0.5, 0.6, 1} or {0.2, 0.2, 0.2, 1},
            borderSize = 2,
            padding = 10,
            margin = 5,
            minWidth = 100
        },
        content = ui.content({
            -- Preview of the style
            {
                type = ui.TYPE.Container,
                props = {
                    margin = {bottom = 10},
                    padding = 5,
                    backgroundColor = style == "solid" and {0, 0, 0, 0.7} or {0, 0, 0, 0},
                    borderColor = style == "outlined" and {0, 0, 0, 1} or {0, 0, 0, 0},
                    borderSize = style == "outlined" and 2 or 0
                },
                content = ui.content({
                    {
                        type = ui.TYPE.Text,
                        props = {
                            text = "Iron Sword",
                            textSize = 14,
                            textColor = col(1, 1, 1) -- White text for preview on various BGs
                        }
                    }
                })
            },
            {
                type = ui.TYPE.Text,
                props = {
                    text = name,
                    textSize = 12,
                    textAlign = ui.ALIGNMENT.Center,
                    textColor = DEFAULT_TEXT_COLOR
                }
            }
        }),
        events = {
            mouseClick = c(function()
                appearanceSettings.labelStyle = style
                saveAppearanceSettings()
                I.TwentyTwentyObjects.refreshUI()
            end)
        }
    }
end

-- Create performance settings
createPerformanceSettings = function()
    
    -- Helper function to create performance preset buttons
    local function createPerformancePreset(name, level, isSelected)
        return {
            type = ui.TYPE.Container,
            props = {
                backgroundColor = isSelected and {0.2, 0.3, 0.4, 1} or {0.1, 0.1, 0.1, 1},
                borderColor = isSelected and {0.4, 0.5, 0.6, 1} or {0.2, 0.2, 0.2, 1},
                borderSize = 2,
                padding = 10,
                margin = 5,
                minWidth = 80
            },
            content = ui.content({
                {
                    type = ui.TYPE.Text,
                    props = {
                        text = name,
                        textSize = 14,
                        textAlign = ui.ALIGNMENT.Center,
                        textColor = isSelected and TAB_ACTIVE_TEXT_COLOR or DEFAULT_TEXT_COLOR
                    }
                }
            }),
            events = {
                mouseClick = c(function()
                    -- Apply performance preset
                    if level == "low" then
                        performanceSettings.maxLabels = 10
                        performanceSettings.updateInterval = "low"
                        performanceSettings.occlusionChecks = "none"
                        performanceSettings.smartGrouping = false
                    elseif level == "balanced" then
                        performanceSettings.maxLabels = 20
                        performanceSettings.updateInterval = "medium"
                        performanceSettings.occlusionChecks = "basic"
                        performanceSettings.smartGrouping = false
                    elseif level == "high" then
                        performanceSettings.maxLabels = 50
                        performanceSettings.updateInterval = "high"
                        performanceSettings.occlusionChecks = "basic"
                        performanceSettings.smartGrouping = true
                    end
                    savePerformanceSettings()
                    I.TwentyTwentyObjects.refreshUI()
                end)
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
            {
                type = ui.TYPE.Text,
                props = {
                    text = "Adjust for better performance",
                    textSize = 16,
                    margin = {bottom = 20},
                    textColor = DEFAULT_TEXT_COLOR
                }
            },
            
            -- Performance presets
            {
                type = ui.TYPE.Container,
                props = {
                    backgroundColor = {0.05, 0.05, 0.05, 0.5},
                    padding = 15,
                    margin = {bottom = 10}
                },
                content = ui.content({
                    {
                        type = ui.TYPE.Text,
                        props = {
                            text = "Quick Settings",
                            textSize = 16,
                            margin = {bottom = 10},
                            textColor = HEADER_TEXT_COLOR
                        }
                    },
                    {
                        type = ui.TYPE.Flex,
                        props = {
                            horizontal = true
                        },
                        content = ui.content({
                            createPerformancePreset("Potato", "low", performanceSettings.updateInterval == "low"),
                            createPerformancePreset("Balanced", "balanced", performanceSettings.updateInterval == "balanced"),
                            createPerformancePreset("Ultra", "high", performanceSettings.updateInterval == "high")
                        })
                    }
                })
            },
            
            -- Advanced settings
            {
                type = ui.TYPE.Text,
                props = {
                    text = "Advanced Settings",
                    textSize = 16,
                    margin = {top = 20, bottom = 10},
                    textColor = HEADER_TEXT_COLOR
                }
            },
            
            createRangeSlider("Max labels shown", performanceSettings.maxLabels, 5, 50, function(v)
                performanceSettings.maxLabels = v
                savePerformanceSettings()
            end),
            
            createToggle("Hide labels behind walls", performanceSettings.occlusionChecks ~= "none", function(v)
                performanceSettings.occlusionChecks = v and "basic" or "none"
                savePerformanceSettings()
            end),
            
            createToggle("Smart grouping", performanceSettings.smartGrouping, function(v)
                performanceSettings.smartGrouping = v
                savePerformanceSettings()
            end),

            {
                type = ui.TYPE.Text,
                props = {
                    text = (generalSettings.debug and "[X] Debug Logging" or "[ ] Debug Logging"),
                    textSize = 14,
                    textColor = DEFAULT_TEXT_COLOR
                },
                events = {
                    mouseClick = c(function()
                        generalSettings.debug = not generalSettings.debug
                        saveGeneralSettings()
                        logger_module.init(storage_module, generalSettings.debug) -- Re-init logger with new debug state
                        I.TwentyTwentyObjects.refreshUI()
                    end)
                }
            }
        })
    }
end

-- Create help content
createHelpContent = function()
    return {
        type = ui.TYPE.Flex,
        props = {
            vertical = true,
            arrange = ui.ALIGNMENT.Start,
            autoSize = true
        },
        content = ui.content({
            {
                type = ui.TYPE.Text,
                props = {
                    text = "Getting Started",
                    textSize = 20,
                    textColor = HEADER_TEXT_COLOR,
                    margin = {bottom = 15}
                }
            },
            {
                type = ui.TYPE.Container,
                props = {
                    backgroundColor = {0.05, 0.05, 0.05, 0.5},
                    padding = 15,
                    margin = {bottom = 10},
                    autoSize = true
                },
                content = ui.content({
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
                                    text = "1. Go to Quick Start and choose a preset",
                                    textSize = 14,
                                    textColor = col(0.9, 0.9, 0.9),
                                    margin = {bottom = 5}
                                }
                            },
                            {
                                type = ui.TYPE.Text,
                                props = {
                                    text = "2. Press the hotkey in-game to see labels",
                                    textSize = 14,
                                    textColor = col(0.9, 0.9, 0.9),
                                    margin = {bottom = 5}
                                }
                            },
                            {
                                type = ui.TYPE.Text,
                                props = {
                                    text = "3. Customize in My Profiles tab",
                                    textSize = 14,
                                    textColor = col(0.9, 0.9, 0.9)
                                }
                            }
                        })
                    }
                })
            },
            {
                type = ui.TYPE.Text,
                props = {
                    text = "Tips",
                    textSize = 18,
                    textColor = HEADER_TEXT_COLOR,
                    margin = {top = 15, bottom = 10}
                }
            },
            {
                type = ui.TYPE.Container,
                props = {
                    backgroundColor = {0.05, 0.05, 0.05, 0.5},
                    padding = 15,
                    margin = {bottom = 10},
                    autoSize = true
                },
                content = ui.content({
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
                                    text = "• Hold mode: Labels show while key is held",
                                    textSize = 14,
                                    textColor = col(0.9, 0.9, 0.9),
                                    margin = {bottom = 5}
                                }
                            },
                            {
                                type = ui.TYPE.Text,
                                props = {
                                    text = "• Toggle mode: Press once to show, again to hide",
                                    textSize = 14,
                                    textColor = col(0.9, 0.9, 0.9),
                                    margin = {bottom = 5}
                                }
                            },
                            {
                                type = ui.TYPE.Text,
                                props = {
                                    text = "• Smaller radius = better performance",
                                    textSize = 14,
                                    textColor = col(0.9, 0.9, 0.9),
                                    margin = {bottom = 5}
                                }
                            },
                            {
                                type = ui.TYPE.Text,
                                props = {
                                    text = "• Labels won't show through walls",
                                    textSize = 14,
                                    textColor = col(0.9, 0.9, 0.9)
                                }
                            }
                        })
                    }
                })
            },
            {
                type = ui.TYPE.Text,
                props = {
                    text = "Common Issues",
                    textSize = 18,
                    textColor = HEADER_TEXT_COLOR,
                    margin = {top = 15, bottom = 10}
                }
            },
            {
                type = ui.TYPE.Container,
                props = {
                    backgroundColor = {0.05, 0.05, 0.05, 0.5},
                    padding = 15,
                    autoSize = true
                },
                content = ui.content({
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
                                    text = "• No labels? Check your filters and radius",
                                    textSize = 14,
                                    textColor = col(0.9, 0.9, 0.9),
                                    margin = {bottom = 5}
                                }
                            },
                            {
                                type = ui.TYPE.Text,
                                props = {
                                    text = "• Too many labels? Reduce radius or filters",
                                    textSize = 14,
                                    textColor = col(0.9, 0.9, 0.9),
                                    margin = {bottom = 5}
                                }
                            },
                            {
                                type = ui.TYPE.Text,
                                props = {
                                    text = "• Can't see labels? Check Appearance settings",
                                    textSize = 14,
                                    textColor = col(0.9, 0.9, 0.9)
                                }
                            }
                        })
                    }
                })
            }
        })
    }
end

-- Helper: list of profiles on Profiles tab
createProfileList = function()
    local rows = {}
    for i, prof in ipairs(profiles) do
        table.insert(rows, {
            type = ui.TYPE.Container,
            props = {
                autoSize = true,
                margin = {bottom = 4},
                backgroundColor = (i == selectedProfileIndex) and TAB_ACTIVE_BG_COLOR or {0,0,0,0},
                padding = 8,
                borderRadius = 4
            },
            content = ui.content({
                {
                    type = ui.TYPE.Text,
                    props = { 
                        text = prof.name or ("Profile "..i), 
                        textColor = (i == selectedProfileIndex) and TAB_ACTIVE_TEXT_COLOR or DEFAULT_TEXT_COLOR,
                        textSize = 14
                    }
                }
            }),
            events = {
                mouseClick = c(function()
                    selectedProfileIndex = i
                    I.TwentyTwentyObjects.refreshUI()
                end)
            }
        })
    end
    
    -- Add "New Profile" button
    table.insert(rows, {
        type = ui.TYPE.Container,
        props = {
            backgroundColor = {0.1, 0.2, 0.1, 0.8},
            borderColor = {0.2, 0.4, 0.2, 1},
            borderSize = 1,
            padding = 8,
            margin = {top = 10},
            autoSize = true
        },
        content = ui.content({
            {
                type = ui.TYPE.Text,
                props = {
                    text = "+ Add New Profile",
                    textColor = CLICKABLE_TEXT_COLOR,
                    textSize = 14
                }
            }
        }),
        events = {
            mouseClick = c(function()
                -- Create new default profile
                local newProfile = {
                    name = "New Profile " .. (#profiles + 1),
                    key = 'x',
                    shift = false,
                    ctrl = false,
                    alt = false,
                    radius = 1000,
                    filters = {
                        items = true,
                        containers = true
                    },
                    modeToggle = false
                }
                table.insert(profiles, newProfile)
                selectedProfileIndex = #profiles
                saveProfiles()
                I.TwentyTwentyObjects.refreshUI()
            end),
            mouseEnter = c(function(e)
                e.target.props.backgroundColor = {0.2, 0.3, 0.2, 1}
                e.target.props.borderColor = {0.3, 0.5, 0.3, 1}
                e.target:update()
            end),
            mouseLeave = c(function(e)
                e.target.props.backgroundColor = {0.1, 0.2, 0.1, 0.8}
                e.target.props.borderColor = {0.2, 0.4, 0.2, 1}
                e.target:update()
            end)
        }
    })
    
    return {
        type = ui.TYPE.Flex,
        props = {
            vertical = true,
            arrange = ui.ALIGNMENT.Start,
            minWidth = 200
        },
        content = ui.content(rows)
    }
end

-- Main layout
local function createMainLayout()
    print("[TTO DEBUG SETTINGS_IMPROVED] createMainLayout() called.")
    return {
        type = ui.TYPE.Container,
        props = { relativeSize = v2(1,1), anchor = v2(0,0) },
        content = ui.content({
            {
                type = ui.TYPE.Flex,
                props = { vertical = true, arrange = ui.ALIGNMENT.Start, relativeSize = v2(1,1) },
                content = ui.content({
                    -- Title
                    { 
                        type = ui.TYPE.Text, 
                        props = { 
                            text = "🔍 Interactable Highlight Settings", 
                            textSize = 24, 
                            textAlign = ui.ALIGNMENT.Center,
                            margin = {bottom = 10}
                        } 
                    },
                    -- Tab bar with proper container
                    {
                        type = ui.TYPE.Container,
                        props = {
                            backgroundColor = {0.05, 0.05, 0.05, 0.3},
                            borderColor = {0.3, 0.3, 0.3, 1},
                            borderSize = {0, 0, 2, 0}, -- Bottom border only
                            margin = {bottom = 5}
                        },
                        content = ui.content({
                            {
                                type = ui.TYPE.Flex, 
                                props = { 
                                    horizontal = true,
                                    arrange = ui.ALIGNMENT.Start
                                }, 
                                content = ui.content(map(TABS or {}, function(tab) return createTabButton(tab, currentTab == tab.id) end))
                            }
                        })
                    },
                    -- Tab content with proper scrolling and text wrapping
                    { 
                        type = ui.TYPE.Container, 
                        props = { 
                            scrollable = true,
                            relativeSize = v2(1, 1),
                            padding = 15,
                            backgroundColor = {0.05, 0.05, 0.05, 0.2}
                        }, 
                        content = ui.content({ 
                            {
                                type = ui.TYPE.Container,
                                props = {
                                    autoSize = true,
                                    maxWidth = 800 -- Limit width to prevent horizontal scrolling
                                },
                                content = ui.content({ createTabContent() })
                            }
                        }) 
                    }
                })
            }
        })
    }
end

-- Local function for the interface
local function exposed_refreshUI()
    print("[TTO DEBUG SETTINGS_IMPROVED] exposed_refreshUI() called.")
    if rootElement then
        print("[TTO DEBUG SETTINGS_IMPROVED] exposed_refreshUI() - Updating layout.")
        rootElement.layout = createMainLayout()
        rootElement:update()
        print("[TTO DEBUG SETTINGS_IMPROVED] exposed_refreshUI() - Layout updated.")
    else
        print("[TTO DEBUG SETTINGS_IMPROVED] exposed_refreshUI() - rootElement is nil (page not created yet?).")
    end
end

-- Initialize
local function onInit()
    print("[TTO DEBUG SETTINGS_IMPROVED] onInit() (Full UI) called.")
    print("[TTO DEBUG SETTINGS_IMPROVED] Registering settings page (Full UI)...")

    -- Create a placeholder element now so we can update it later regardless of API internals
    rootElement = ui.create({
        type = ui.TYPE.Container,
        props = { relativeSize = v2(1,1), anchor = v2(0,0)},
        content = ui.content({
            {
                type = ui.TYPE.Text,
                props = { text = 'Loading full settings UI...', textSize = 16 }
            }
        })
    })

    ui.registerSettingsPage({
        key  = 'TwentyTwentyObjects',
        l10n = 'TwentyTwentyObjects',
        name = 'TwentyTwentyObjects',
        element = rootElement
    })
    print("[TTO DEBUG SETTINGS_IMPROVED] Settings page registered (Full UI).")
end

-- function called from Global script once storage ready
local function refresh(data) -- This is the ACTUAL refresh for the full UI
    print("[TTO DEBUG SETTINGS_IMPROVED] ACTUAL refresh() function called.")
    if not data then 
        print("[TTO DEBUG SETTINGS_IMPROVED] ACTUAL refresh() called with no data, returning.")
        return 
    end
    profiles           = data.profiles or {}
    appearanceSettings = data.appearance or {
        labelStyle = "native",
        textSize = "medium",
        lineStyle = "straight",
        lineColor = {r=0.8, g=0.8, b=0.8, a=0.7},
        backgroundColor = {r=0, g=0, b=0, a=0.5},
        showIcons = true,
        enableAnimations = true,
        animationSpeed = "normal",
        fadeDistance = true,
        groupSimilar = false,
        opacity = 0.8
    }
    performanceSettings= data.performance or {
        maxLabels = 20,
        updateInterval = "medium",
        scanInterval = "medium",
        distanceCulling = true,
        cullDistance = 2000,
        occlusionChecks = "basic",
        smartGrouping = false
    }
    generalSettings    = data.general or {
        debug = false
    }
    selectedProfileIndex = 1 -- Reset selected index
    currentTab = "presets" -- Reset to default tab

    if not storage_module then print("[TTO ERROR] storage_module is nil in refresh!") end
    if not logger_module then print("[TTO ERROR] logger_module is nil in refresh!") end
    
    print("[TTO DEBUG SETTINGS_IMPROVED] Profiles count: " .. #profiles)
    logger_module.init(generalSettings.debug) -- Ensure logger is using current debug state

    if rootElement then
        print("[TTO DEBUG SETTINGS_IMPROVED] ACTUAL refresh() - Updating main layout.")
        exposed_refreshUI() -- This will call createMainLayout and update
    else
        print("[TTO DEBUG SETTINGS_IMPROVED] ACTUAL refresh() - rootElement is nil (page not initialized yet).")
    end
    print("[TTO DEBUG SETTINGS_IMPROVED] ACTUAL refresh() completed.")
end

local function handlePleaseRefreshSettingsEvent(eventData)
    print("[TTO DEBUG SETTINGS_IMPROVED] Received PleaseRefreshSettingsEvent (Full UI target).")
    if eventData and eventData.dataToRefreshWith then
        refresh(eventData.dataToRefreshWith) -- Call the actual refresh function
    else
        print("[TTO DEBUG SETTINGS_IMPROVED] PleaseRefreshSettingsEvent (Full UI target) received no dataToRefreshWith.")
        refresh(nil) 
    end
end

print("[TTO DEBUG SETTINGS_IMPROVED] Defining interface and event handlers (Full UI)...")

return {
    interfaceName = 'TwentyTwentyObjects', -- Must match the name used in I.TwentyTwentyObjects.* calls
    interface = { 
        refresh = refresh, -- Actual refresh
        refreshUI = exposed_refreshUI
    },
    engineHandlers = {
        onInit = onInit
    },
    eventHandlers = {
        PleaseRefreshSettingsEvent = handlePleaseRefreshSettingsEvent
    }
}