-- labelRenderer.lua: Enhanced label rendering with better readability
-- Provides multiple label styles and smart contrast adjustment

local ui = require('openmw.ui')
local util = require('openmw.util')

local M = {}

-- Label style definitions
local STYLES = {
    outlined = {
        name = "Outlined",
        render = function(text, style)
            return {
                type = ui.TYPE.Container,
                props = {
                    anchor = util.vector2(0.5, 1),
                    backgroundColor = {0, 0, 0, 0.3},  -- Subtle background
                    borderColor = {0, 0, 0, 0.8},      -- Dark border
                    borderSize = 2,
                    padding = {horizontal = 8, vertical = 4}
                },
                content = ui.content({
                    -- Multiple shadows for better outline
                    {
                        type = ui.TYPE.Text,
                        props = {
                            text = text,
                            textSize = style.textSize,
                            textColor = {0, 0, 0, 1},
                            position = util.vector2(-1, -1)
                        }
                    },
                    {
                        type = ui.TYPE.Text,
                        props = {
                            text = text,
                            textSize = style.textSize,
                            textColor = {0, 0, 0, 1},
                            position = util.vector2(1, -1)
                        }
                    },
                    {
                        type = ui.TYPE.Text,
                        props = {
                            text = text,
                            textSize = style.textSize,
                            textColor = {0, 0, 0, 1},
                            position = util.vector2(-1, 1)
                        }
                    },
                    {
                        type = ui.TYPE.Text,
                        props = {
                            text = text,
                            textSize = style.textSize,
                            textColor = {0, 0, 0, 1},
                            position = util.vector2(1, 1)
                        }
                    },
                    -- Main text
                    {
                        type = ui.TYPE.Text,
                        props = {
                            text = text,
                            textSize = style.textSize,
                            textColor = style.textColor,
                            position = util.vector2(0, 0)
                        }
                    }
                })
            }
        end
    },
    
    solid = {
        name = "Solid Background",
        render = function(text, style)
            return {
                type = ui.TYPE.Container,
                props = {
                    anchor = util.vector2(0.5, 1),
                    backgroundColor = {0, 0, 0, 0.75},  -- Solid dark background
                    borderRadius = 4,
                    padding = {horizontal = 10, vertical = 6}
                },
                content = ui.content({
                    {
                        type = ui.TYPE.Text,
                        props = {
                            text = text,
                            textSize = style.textSize,
                            textColor = style.textColor
                        }
                    }
                })
            }
        end
    },
    
    minimal = {
        name = "Minimal",
        render = function(text, style)
            return {
                type = ui.TYPE.Container,
                props = {
                    anchor = util.vector2(0.5, 1)
                },
                content = ui.content({
                    -- Strong shadow for contrast
                    {
                        type = ui.TYPE.Text,
                        props = {
                            text = text,
                            textSize = style.textSize,
                            textColor = {0, 0, 0, 0.9},
                            position = util.vector2(2, 2)
                        }
                    },
                    {
                        type = ui.TYPE.Text,
                        props = {
                            text = text,
                            textSize = style.textSize,
                            textColor = style.textColor
                        }
                    }
                })
            }
        end
    },
    
    adaptive = {
        name = "Adaptive Contrast",
        render = function(text, style, backgroundColor)
            -- Adjust text color based on background
            local bgLuminance = M.calculateLuminance(backgroundColor or {0.5, 0.5, 0.5})
            local textColor = bgLuminance > 0.5 and {0, 0, 0, 1} or {1, 1, 1, 1}
            
            return {
                type = ui.TYPE.Container,
                props = {
                    anchor = util.vector2(0.5, 1),
                    backgroundColor = bgLuminance > 0.5 and {1, 1, 1, 0.7} or {0, 0, 0, 0.7},
                    borderRadius = 4,
                    padding = {horizontal = 8, vertical = 4}
                },
                content = ui.content({
                    {
                        type = ui.TYPE.Text,
                        props = {
                            text = text,
                            textSize = style.textSize,
                            textColor = textColor
                        }
                    }
                })
            }
        end
    }
}

-- Get current style from settings
function M.getCurrentStyle()
    local appearance = require('openmw.storage').globalSection('TwentyTwentyObjects'):get('appearance') or {}
    return appearance.labelStyle or "outlined"
end

-- Create a label with the current style
function M.createLabel(text, options)
    options = options or {}
    
    local styleName = options.style or M.getCurrentStyle()
    local styleFunc = STYLES[styleName] or STYLES.outlined
    
    -- Get text sizing from settings
    local appearance = require('openmw.storage').globalSection('TwentyTwentyObjects'):get('appearance') or {}
    local textSizes = {
        small = 12,
        medium = 14,
        large = 18
    }
    
    local style = {
        textSize = textSizes[appearance.textSize or "medium"] or 14,
        textColor = {1, 1, 1, appearance.opacity or 0.9}
    }
    
    -- Apply distance scaling if provided
    if options.distanceScale then
        style.textSize = math.max(10, style.textSize * options.distanceScale)
    end
    
    -- Create the label
    local labelLayout = styleFunc.render(text, style, options.backgroundColor)
    
    -- Add any animations or effects
    if options.fadeIn then
        labelLayout.props.alpha = 0  -- Will be animated elsewhere
    end
    
    return ui.create(labelLayout)
end

-- Calculate relative luminance for contrast checking
function M.calculateLuminance(color)
    -- Using simplified relative luminance formula
    local r, g, b = color[1] or 0, color[2] or 0, color[3] or 0
    return 0.299 * r + 0.587 * g + 0.114 * b
end

-- Create icon for object type
function M.getObjectIcon(objectType)
    local icons = {
        NPC = "👤",
        Creature = "🐾", 
        Container = "📦",
        Door = "🚪",
        Weapon = "⚔️",
        Armor = "🛡️",
        Book = "📖",
        Ingredient = "🌿",
        Gold = "💰"
    }
    
    return icons[objectType] or "•"
end

-- Format label text with optional icon
function M.formatLabelText(name, objectType, options)
    options = options or {}
    
    if options.showIcons then
        local icon = M.getObjectIcon(objectType)
        return icon .. " " .. name
    end
    
    if options.abbreviated and #name > 20 then
        return string.sub(name, 1, 17) .. "..."
    end
    
    return name
end

-- Create group label for multiple objects
function M.createGroupLabel(objects, options)
    options = options or {}
    
    local text
    if #objects <= 3 then
        -- List individual names
        local names = {}
        for i, obj in ipairs(objects) do
            table.insert(names, obj.name)
        end
        text = table.concat(names, "\n")
    else
        -- Summary with icons
        local types = {}
        for _, obj in ipairs(objects) do
            types[obj.type] = (types[obj.type] or 0) + 1
        end
        
        local parts = {}
        for objType, count in pairs(types) do
            local icon = M.getObjectIcon(objType)
            table.insert(parts, icon .. " " .. count)
        end
        
        text = table.concat(parts, "  ")
    end
    
    -- Use solid style for groups
    options.style = "solid"
    return M.createLabel(text, options)
end

-- Create label with health bar for NPCs/creatures
function M.createActorLabel(actor, options)
    options = options or {}
    
    local name = M.formatLabelText(actor.name, actor.type, options)
    
    -- Create base label
    local label = M.createLabel(name, options)
    
    -- Add health bar if requested
    if options.showHealth and actor.health then
        local healthPercent = actor.health / actor.maxHealth
        local healthBar = ui.create({
            type = ui.TYPE.Container,
            props = {
                backgroundColor = {0.2, 0.2, 0.2, 0.8},
                height = 4,
                width = 60,
                position = util.vector2(0, label.layout.size.y + 2)
            },
            content = ui.content({
                {
                    type = ui.TYPE.Container,
                    props = {
                        backgroundColor = healthPercent > 0.5 and {0.2, 0.8, 0.2, 1} or 
                                       healthPercent > 0.25 and {0.8, 0.8, 0.2, 1} or
                                       {0.8, 0.2, 0.2, 1},
                        height = 4,
                        width = 60 * healthPercent
                    }
                }
            })
        })
        
        -- Combine label and health bar
        -- Note: This is simplified - actual implementation would need proper layout
    end
    
    return label
end

-- Preload common label styles for performance
function M.preloadStyles()
    -- Pre-create some common labels to warm up the system
    local dummy = M.createLabel("Preload", {style = "outlined"})
    dummy:destroy()
    
    dummy = M.createLabel("Preload", {style = "solid"})
    dummy:destroy()
end

return M