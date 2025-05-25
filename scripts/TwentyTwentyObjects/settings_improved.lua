-- settings_improved.lua: Enhanced menu script for Twenty Twenty Objects Mod
-- Creates an improved configuration interface with quick-start presets

local ui = require('openmw.ui')
local I = require('openmw.interfaces')
local async = require('openmw.async')
local input = require('openmw.input') -- For key press handling WITHIN THE MENU (e.g. binding)
-- local world = require('openmw.world') -- REMOVED: Not available in MENU context

local storage_module = require('scripts.TwentyTwentyObjects.util.storage')
local logger_module = require('scripts.TwentyTwentyObjects.util.logger')

-- Forward declare variables that will be initialized in onInit
local profiles = {}
local appearanceSettings = {}
local performanceSettings = {}
local generalSettings = {} -- For debug mode, etc.

-- UI State
local currentTab = "presets"  -- Start with presets for new users
local selectedProfileIndex = 1
local awaitingKeypress = false
local showingPreview = false

-- Preset configurations for common use cases
local PRESETS = {
    {
        name = "Loot Hunter",
        description = "Highlights valuable items and containers",
        icon = "🗡️",
        profile = {
            name = "Loot Hunter",
            key = 'e', shift = false, ctrl = false, alt = false,
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
        profile = {
            name = "NPC Tracker",
            key = 'q', shift = false, ctrl = false, alt = false,
            radius = 800,
            filters = {npcs = true, creatures = false},
            modeToggle = true
        }
    },
    {
        name = "Thief's Eye",
        description = "Spot valuable items in shops and homes",
        icon = "💎",
        profile = {
            name = "Thief's Eye",
            key = 'z', shift = true, ctrl = false, alt = false,
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
        profile = {
            name = "Dungeon Delver",
            key = 'x', shift = false, ctrl = false, alt = false,
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

logger.init(storage)

-- Helper: Save current profiles to storage
local function saveProfiles()
    if not storage_module then return end -- Guard against calls before onInit
    storage_module.setProfiles(profiles)
    logger_module.debug("Profiles saved to storage")
end

-- Helper: Save appearance settings
local function saveAppearanceSettings()
    if not storage_module then return end
    storage_module.set('appearance', appearanceSettings)
    logger_module.debug("Appearance settings saved")
end

-- Helper: Save performance settings
local function savePerformanceSettings()
    if not storage_module then return end
    storage_module.set('performance', performanceSettings)
    logger_module.debug("Performance settings saved")
end

-- Helper: Save general settings
local function saveGeneralSettings()
    if not storage_module then return end
    storage_module.set('general', generalSettings)
    logger_module.debug("General settings saved")
end

-- Helper: Create tab button
local function createTabButton(tab, isActive)
    return {
        type = ui.TYPE.Container,
        props = {
            backgroundColor = isActive and {0.2, 0.3, 0.4, 1} or {0.1, 0.1, 0.1, 0.5},
            borderColor = isActive and {0.4, 0.5, 0.6, 1} or {0.2, 0.2, 0.2, 1},
            borderSize = 1,
            padding = 10,
            margin = 2
        },
        content = ui.content({
            {
                type = ui.TYPE.Text,
                props = {
                    text = tab.icon .. " " .. tab.label,
                    textSize = 16,
                    textColor = isActive and {1, 1, 1, 1} or {0.7, 0.7, 0.7, 1}
                }
            }
        }),
        events = {
            mouseClick = function()
                currentTab = tab.id
                I.TwentyTwentyObjects.refreshUI()
            end
        }
    }
end

-- Helper: Create preset card
local function createPresetCard(preset)
    return {
        type = ui.TYPE.Container,
        props = {
            backgroundColor = {0.1, 0.1, 0.1, 0.8},
            borderColor = {0.3, 0.3, 0.3, 1},
            borderSize = 2,
            padding = 15,
            margin = 5,
            minWidth = 250
        },
        content = ui.content({
            {
                type = ui.TYPE.Text,
                props = {
                    text = preset.icon .. " " .. preset.name,
                    textSize = 20,
                    textColor = {1, 0.9, 0.7, 1}
                }
            },
            {
                type = ui.TYPE.Text,
                props = {
                    text = "\n" .. preset.description,
                    textSize = 14,
                    textColor = {0.8, 0.8, 0.8, 1}
                }
            },
            {
                type = ui.TYPE.Container,
                props = {
                    margin = {top = 15}
                },
                content = ui.content({
                    {
                        type = ui.TYPE.Container,
                        props = {
                            backgroundColor = {0.2, 0.4, 0.2, 1},
                            padding = 8,
                            borderRadius = 4
                        },
                        content = ui.content({
                            {
                                type = ui.TYPE.Text,
                                props = {
                                    text = "Use This Preset",
                                    textSize = 14,
                                    textAlign = ui.ALIGNMENT.Center
                                }
                            }
                        }),
                        events = {
                            mouseClick = function()
                                -- Add preset as new profile
                                table.insert(profiles, preset.profile)
                                selectedProfileIndex = #profiles
                                saveProfiles() -- This will save the updated local 'profiles' table
                                
                                -- Switch to profiles tab
                                currentTab = "profiles"
                                I.TwentyTwentyObjects.refreshUI()
                            end
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
                    textColor = {1, 1, 0.8, 1},
                    font = "MonoFont"  -- If available
                }
            }
        })
    }
end

-- Create content based on current tab
local function createTabContent()
    if currentTab == "presets" then
        -- Presets tab
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
                        text = "Choose a preset to get started quickly:",
                        textSize = 16,
                        margin = {bottom = 20}
                    }
                },
                {
                    type = ui.TYPE.Flex,
                    props = {
                        horizontal = true,
                        wrap = true,
                        arrange = ui.ALIGNMENT.Start
                    },
                    content = ui.content(
                        util.map(PRESETS, createPresetCard)
                    )
                }
            })
        }
        
    elseif currentTab == "profiles" then
        -- Profiles tab (existing functionality but better organized)
        local profile = profiles[selectedProfileIndex]
        
        if not profile then
            return {
                type = ui.TYPE.Text,
                props = {
                    text = "No profiles yet. Go to Quick Start to add one!",
                    textSize = 16
                }
            }
        end
        
        return {
            type = ui.TYPE.Flex,
            props = {
                horizontal = true,
                arrange = ui.ALIGNMENT.Start
            },
            content = ui.content({
                -- Profile list (left)
                {
                    type = ui.TYPE.Container,
                    props = {
                        minWidth = 200,
                        margin = {right = 20}
                    },
                    content = ui.content({
                        createProfileList()
                    })
                },
                
                -- Profile editor (right)
                {
                    type = ui.TYPE.Flex,
                    props = {
                        vertical = true,
                        arrange = ui.ALIGNMENT.Start,
                        grow = 1
                    },
                    content = ui.content({
                        -- Key binding section
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
                                        text = "Hotkey Binding",
                                        textSize = 18,
                                        margin = {bottom = 10}
                                    }
                                },
                                createKeyDisplay(profile),
                                {
                                    type = ui.TYPE.Container,
                                    props = {
                                        margin = {top = 10}
                                    },
                                    content = ui.content({
                                        {
                                            type = ui.TYPE.Text,
                                            props = {
                                                text = awaitingKeypress and "Press any key..." or "[Click to change]",
                                                textSize = 14,
                                                textColor = {0.7, 0.7, 1, 1}
                                            },
                                            events = {
                                                mouseClick = function()
                                                    awaitingKeypress = true
                                                end
                                            }
                                        }
                                    })
                                }
                            })
                        },
                        
                        -- Settings sections
                        createSettingsSection(profile)
                    })
                }
            })
        }
        
    elseif currentTab == "appearance" then
        -- Appearance settings
        return createAppearanceSettings()
        
    elseif currentTab == "performance" then
        -- Performance settings
        return createPerformanceSettings()
        
    elseif currentTab == "help" then
        -- Help tab
        return createHelpContent()
    end
end

-- Create settings section with better organization
local function createSettingsSection(profile)
    return {
        type = ui.TYPE.Flex,
        props = {
            vertical = true,
            arrange = ui.ALIGNMENT.Start
        },
        content = ui.content({
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
                        type = ui.TYPE.Text,
                        props = {
                            text = "Basic Settings",
                            textSize = 18,
                            margin = {bottom = 10}
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
                        type = ui.TYPE.Text,
                        props = {
                            text = "What to Highlight",
                            textSize = 18,
                            margin = {bottom = 10}
                        }
                    },
                    createFilterCategories(profile.filters)
                })
            }
        })
    }
end

-- Create visual toggle switch
local function createToggle(label, value, onChange)
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
                    minWidth = 150
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
                            position = value and {x = 37, y = 0} or {x = 0, y = 0}
                        }
                    }
                }),
                events = {
                    mouseClick = function()
                        onChange(not value)
                        I.TwentyTwentyObjects.refreshUI()
                    end
                }
            }
        })
    }
end

-- Create range slider with visual feedback
local function createRangeSlider(label, value, min, max, onChange)
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
                    arrange = ui.ALIGNMENT.SpaceBetween
                },
                content = ui.content({
                    {
                        type = ui.TYPE.Text,
                        props = {
                            text = label,
                            textSize = 14
                        }
                    },
                    {
                        type = ui.TYPE.Text,
                        props = {
                            text = tostring(math.floor(value)) .. " units",
                            textSize = 14,
                            textColor = {0.7, 0.7, 1, 1}
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
                    mouseClick = function(e)
                        -- Simple click position to value conversion
                        local clickPercent = e.position.x / 300
                        local newValue = min + (max - min) * clickPercent
                        onChange(math.floor(newValue))
                        I.TwentyTwentyObjects.refreshUI()
                    end
                }
            }
        })
    }
end

-- Create filter categories with visual grouping
local function createFilterCategories(filters)
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
                        type = ui.TYPE.Text,
                        props = {
                            text = "📍 Characters",
                            textSize = 16,
                            textColor = {0.9, 0.9, 0.6, 1},
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
            },
            
            -- Items category
            {
                type = ui.TYPE.Container,
                props = {
                    margin = {bottom = 15}
                },
                content = ui.content({
                    {
                        type = ui.TYPE.Text,
                        props = {
                            text = "🎒 Items",
                            textSize = 16,
                            textColor = {0.9, 0.9, 0.6, 1},
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
                        type = ui.TYPE.Container,
                        props = {
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
            },
            
            -- World objects category
            {
                type = ui.TYPE.Container,
                content = ui.content({
                    {
                        type = ui.TYPE.Text,
                        props = {
                            text = "🏛️ World Objects",
                            textSize = 16,
                            textColor = {0.9, 0.9, 0.6, 1},
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
end

-- Create visual checkbox
local function createCheckbox(label, checked, onChange)
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
                    backgroundColor = checked and {0.2, 0.4, 0.2, 1} or {0.2, 0.2, 0.2, 1},
                    borderColor = {0.4, 0.4, 0.4, 1},
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
                            textColor = {1, 1, 1, 1}
                        }
                    } or {}
                }),
                events = {
                    mouseClick = function()
                        onChange(not checked)
                        I.TwentyTwentyObjects.refreshUI()
                    end
                }
            },
            {
                type = ui.TYPE.Text,
                props = {
                    text = label,
                    textSize = 14
                }
            }
        })
    }
end

-- Create appearance settings
local function createAppearanceSettings()
    -- Ensure appearanceSettings is populated
    if not appearanceSettings.labelStyle then
        appearanceSettings = storage_module.get('appearance', { -- Default values if not found
            labelStyle = "native",
            textSize = "medium",
            lineStyle = "straight",
            lineColor = {r=0.8, g=0.8, b=0.8, a=0.7},
            backgroundColor = {r=0, g=0, b=0, a=0.5},
            showIcons = true,
            enableAnimations = true,
            animationSpeed = "normal"
        })
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
                    text = "Customize how labels look",
                    textSize = 16,
                    margin = {bottom = 20}
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
                            margin = {bottom = 10}
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
local function createStylePreview(name, style, isSelected)
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
                            textColor = {1, 1, 1, 1}
                        }
                    }
                })
            },
            {
                type = ui.TYPE.Text,
                props = {
                    text = name,
                    textSize = 12,
                    textAlign = ui.ALIGNMENT.Center
                }
            }
        }),
        events = {
            mouseClick = function()
                appearanceSettings.labelStyle = style
                saveAppearanceSettings()
                I.TwentyTwentyObjects.refreshUI()
            end
        }
    }
end

-- Create performance settings
local function createPerformanceSettings()
    if not performanceSettings.maxLabels then
         performanceSettings = storage_module.get('performance', { -- Default values
            maxLabels = 20,
            updateInterval = "medium", -- e.g., 0.05s
            scanInterval = "medium",   -- e.g., 0.25s
            distanceCulling = true,
            cullDistance = 2000,
            occlusionChecks = "basic" -- none, basic, advanced (raycast)
        })
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
                    margin = {bottom = 20}
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
                            margin = {bottom = 10}
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
                    margin = {top = 20, bottom = 10}
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
                    textSize = 14
                },
                events = {
                    mouseClick = function()
                        generalSettings.debug = not generalSettings.debug
                        saveGeneralSettings()
                        logger_module.init(storage_module, generalSettings.debug) -- Re-init logger with new debug state
                        I.TwentyTwentyObjects.refreshUI()
                    end
                }
            }
        })
    }
end

-- Create help content
local function createHelpContent()
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
                    text = "Getting Started",
                    textSize = 20,
                    textColor = {1, 0.9, 0.7, 1},
                    margin = {bottom = 15}
                }
            },
            {
                type = ui.TYPE.Text,
                props = {
                    text = "1. Go to Quick Start and choose a preset\n" ..
                           "2. Press the hotkey in-game to see labels\n" ..
                           "3. Customize in My Profiles tab\n\n" ..
                           "Tips:\n" ..
                           "• Hold mode: Labels show while key is held\n" ..
                           "• Toggle mode: Press once to show, again to hide\n" ..
                           "• Smaller radius = better performance\n" ..
                           "• Labels won't show through walls\n\n" ..
                           "Common Issues:\n" ..
                           "• No labels? Check your filters and radius\n" ..
                           "• Too many labels? Reduce radius or filters\n" ..
                           "• Can't see labels? Check Appearance settings",
                    textSize = 14,
                    textColor = {0.9, 0.9, 0.9, 1}
                }
            }
        })
    }
end

-- Main layout
local function createMainLayout()
    return {
        type = ui.TYPE.Flex,
        props = {
            vertical = true,
            arrange = ui.ALIGNMENT.Start
        },
        content = ui.content({
            -- Header
            {
                type = ui.TYPE.Container,
                props = {
                    backgroundColor = {0.1, 0.15, 0.2, 1},
                    padding = 15,
                    margin = {bottom = 10}
                },
                content = ui.content({
                    {
                        type = ui.TYPE.Text,
                        props = {
                            text = "🔍 Interactable Highlight Settings",
                            textSize = 24,
                            textAlign = ui.ALIGNMENT.Center
                        }
                    }
                })
            },
            
            -- Tab bar
            {
                type = ui.TYPE.Flex,
                props = {
                    horizontal = true,
                    arrange = ui.ALIGNMENT.Start,
                    margin = {bottom = 20}
                },
                content = ui.content(
                    util.map(TABS, function(tab)
                        return createTabButton(tab, currentTab == tab.id)
                    end)
                )
            },
            
            -- Tab content
            {
                type = ui.TYPE.Container,
                props = {
                    padding = 10
                },
                content = ui.content({
                    createTabContent()
                })
            }
        })
    }
end

-- Interface
I.TwentyTwentyObjects = {
    refreshUI = function()
        if settingsPage then
            settingsPage.element.layout = createMainLayout()
            settingsPage.element:update()
        end
    end
}

-- Initialize
local function onInit()
    -- Initialize logger (now safe as storage is active)
    generalSettings = storage_module.get('general', { debug = false })
    logger_module.init(storage_module, generalSettings.debug)

    -- Load profiles and other settings from storage (now safe)
    profiles = storage_module.getProfiles() -- Ensures a table
    if #profiles == 0 then -- If storage was empty or reset, initialize with a default if desired
        logger_module.info("No profiles found in storage. Consider adding a default or guiding user.")
        -- Example: Add a default starter profile if none exist.
        -- table.insert(profiles, { name = "Default Starter", key = 'h', ... etc ... })
        -- saveProfiles() -- Don't forget to save if you add one
    end

    appearanceSettings = storage_module.get('appearance', {
        labelStyle = "native", textSize = "medium", lineColor = {r=0.8, g=0.8, b=0.8, a=0.7},
        backgroundColor = {r=0, g=0, b=0, a=0.5}, showIcons = true,
        enableAnimations = true, animationSpeed = "normal"
    })
    performanceSettings = storage_module.get('performance', {
        maxLabels = 20, updateInterval = "medium", scanInterval = "medium",
        distanceCulling = true, cullDistance = 2000, occlusionChecks = "basic"
    })
    
    -- Ensure selectedProfileIndex is valid
    if selectedProfileIndex > #profiles and #profiles > 0 then
        selectedProfileIndex = #profiles
    elseif #profiles == 0 then
        selectedProfileIndex = 1 -- Or handle no profiles state in UI
    end

    -- Register settings page
    settingsPage = ui.registerSettingsPage({
        key = 'TwentyTwentyObjects',
        l10n = 'TwentyTwentyObjects',
        name = 'Interactable Highlight',
        element = ui.create(createMainLayout())
    })
    
    logger_module.info('Improved settings page registered')
end

return {
    interfaceName = 'TwentyTwentyObjects',
    interface = I.TwentyTwentyObjects,
    engineHandlers = {
        onInit = onInit
    }
}