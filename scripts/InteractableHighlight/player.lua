-- player.lua: Player local script for Interactable Highlight Mod
-- Handles object scanning and HUD label management

local nearby = require('openmw.nearby')
local ui = require('openmw.ui')
local util = require('openmw.util')
local types = require('openmw.types')
local self = require('openmw.self')
local async = require('openmw.async')

-- Import utilities
local projection = require('scripts.InteractableHighlight.util.projection')
local logger = require('scripts.InteractableHighlight.util.logger')
local storage = require('scripts.InteractableHighlight.util.storage')

-- Initialize logger
logger.init(storage)

-- Active labels tracking
local activeLabels = {}
local currentProfile = nil
local updateAccumulator = 0
local UPDATE_INTERVAL = 0.016  -- ~60fps updates

-- Label style configuration
local LABEL_STYLE = {
    textSize = 14,
    textColor = util.color.rgb(1, 1, 1),  -- White
    shadowColor = util.color.rgb(0, 0, 0),  -- Black shadow
    shadowOffset = util.vector2(1, 1),
    padding = 4
}

-- Helper: Create a label UI element
local function createLabel(text)
    -- Create label with shadow effect using two text elements
    local label = ui.create({
        layer = 'HUD',
        type = ui.TYPE.Container,
        props = {
            anchor = util.vector2(0.5, 1),  -- Center bottom anchor
            visible = true
        },
        content = ui.content({
            -- Shadow text
            {
                type = ui.TYPE.Text,
                props = {
                    text = text,
                    textSize = LABEL_STYLE.textSize,
                    textColor = LABEL_STYLE.shadowColor,
                    position = LABEL_STYLE.shadowOffset
                }
            },
            -- Main text
            {
                type = ui.TYPE.Text,
                props = {
                    text = text,
                    textSize = LABEL_STYLE.textSize,
                    textColor = LABEL_STYLE.textColor,
                    position = util.vector2(0, 0)
                }
            }
        })
    })
    
    return label
end

-- Helper: Destroy all active labels
local function clearAllLabels()
    logger.debug(string.format('Clearing %d labels', #activeLabels))
    
    for _, labelData in ipairs(activeLabels) do
        if labelData.ui then
            labelData.ui:destroy()
        end
    end
    
    activeLabels = {}
end

-- Helper: Get display name for an object
local function getObjectName(object)
    -- Try type-specific name getter first
    local objType = object.type
    
    -- Different object types have different ways to get names
    if objType == types.NPC then
        return types.NPC.record(object).name
    elseif objType == types.Creature then
        return types.Creature.record(object).name
    elseif objType == types.Container then
        return types.Container.record(object).name
    elseif objType == types.Door then
        return types.Door.record(object).name
    elseif objType == types.Weapon then
        return types.Weapon.record(object).name
    elseif objType == types.Armor then
        return types.Armor.record(object).name
    elseif objType == types.Clothing then
        return types.Clothing.record(object).name
    elseif objType == types.Book then
        return types.Book.record(object).name
    elseif objType == types.Ingredient then
        return types.Ingredient.record(object).name
    elseif objType == types.Miscellaneous then
        return types.Miscellaneous.record(object).name
    elseif objType == types.Activator then
        return types.Activator.record(object).name
    end
    
    -- Fallback to recordId
    return object.recordId or "Unknown"
end

-- Helper: Check if object matches filters
local function matchesFilters(object, filters)
    local objType = object.type
    
    -- Check actor types
    if objType == types.NPC and filters.npcs then
        return true
    elseif objType == types.Creature and filters.creatures then
        return true
    -- Check containers
    elseif objType == types.Container and filters.containers then
        return true
    -- Check doors
    elseif objType == types.Door and filters.doors then
        return true
    -- Check activators
    elseif objType == types.Activator and filters.activators then
        return true
    -- Check items
    elseif filters.items then
        -- Master items toggle
        return true
    else
        -- Check specific item subtypes
        if objType == types.Weapon and filters.weapons then
            return true
        elseif objType == types.Armor and filters.armor then
            return true
        elseif objType == types.Clothing and filters.clothing then
            return true
        elseif objType == types.Book and filters.books then
            return true
        elseif objType == types.Ingredient and filters.ingredients then
            return true
        elseif objType == types.Miscellaneous and filters.misc then
            return true
        end
    end
    
    return false
end

-- Scan for objects and create labels
local function scanAndCreateLabels(profile)
    logger.info(string.format('Scanning with profile: %s', profile.name))
    
    -- Clear existing labels
    clearAllLabels()
    
    local playerPos = self.position
    local radiusSq = profile.radius * profile.radius  -- Square for faster comparison
    local targets = {}
    
    -- Gather all nearby objects based on filters
    -- Items
    if profile.filters.items or profile.filters.weapons or profile.filters.armor or 
       profile.filters.clothing or profile.filters.books or profile.filters.ingredients or 
       profile.filters.misc then
        for _, item in ipairs(nearby.items) do
            local distSq = (item.position - playerPos):length2()
            if distSq <= radiusSq and matchesFilters(item, profile.filters) then
                table.insert(targets, item)
            end
        end
    end
    
    -- Actors (NPCs and Creatures)
    if profile.filters.npcs or profile.filters.creatures then
        for _, actor in ipairs(nearby.actors) do
            -- Skip the player
            if actor ~= self then
                local distSq = (actor.position - playerPos):length2()
                if distSq <= radiusSq and matchesFilters(actor, profile.filters) then
                    table.insert(targets, actor)
                end
            end
        end
    end
    
    -- Containers
    if profile.filters.containers then
        for _, container in ipairs(nearby.containers) do
            local distSq = (container.position - playerPos):length2()
            if distSq <= radiusSq then
                table.insert(targets, container)
            end
        end
    end
    
    -- Doors
    if profile.filters.doors then
        for _, door in ipairs(nearby.doors) do
            local distSq = (door.position - playerPos):length2()
            if distSq <= radiusSq then
                table.insert(targets, door)
            end
        end
    end
    
    -- Activators
    if profile.filters.activators then
        for _, activator in ipairs(nearby.activators) do
            local distSq = (activator.position - playerPos):length2()
            if distSq <= radiusSq then
                table.insert(targets, activator)
            end
        end
    end
    
    logger.debug(string.format('Found %d objects to highlight', #targets))
    
    -- Create labels for all targets
    for _, object in ipairs(targets) do
        local name = getObjectName(object)
        local label = createLabel(name)
        
        table.insert(activeLabels, {
            object = object,
            ui = label,
            name = name
        })
    end
    
    -- Force immediate position update
    updateLabelPositions(0)
end

-- Update label positions
function updateLabelPositions(dt)
    local toRemove = {}
    
    for i, labelData in ipairs(activeLabels) do
        local object = labelData.object
        local label = labelData.ui
        
        -- Check if object still valid
        if not object:isValid() then
            label:destroy()
            table.insert(toRemove, i)
        else
            -- Get label position above object
            local worldPos = projection.getObjectLabelPosition(object)
            local screenPos = projection.worldToScreen(worldPos)
            
            if screenPos and projection.isOnScreen(screenPos, 50) then
                -- Update position
                label.layout.props.position = screenPos
                label.layout.props.visible = true
            else
                -- Hide if off-screen or behind camera
                label.layout.props.visible = false
            end
            
            label:update()
        end
    end
    
    -- Remove invalid labels
    for i = #toRemove, 1, -1 do
        table.remove(activeLabels, toRemove[i])
    end
end

-- Event handler: Show highlights
local function onShowHighlights(eventData)
    currentProfile = eventData.profile
    scanAndCreateLabels(currentProfile)
end

-- Event handler: Hide highlights
local function onHideHighlights(eventData)
    clearAllLabels()
    currentProfile = nil
end

-- Engine handler: Frame update
local function onUpdate(dt)
    -- Only update if we have active labels
    if #activeLabels == 0 then
        return
    end
    
    -- Throttle updates for performance
    updateAccumulator = updateAccumulator + dt
    if updateAccumulator >= UPDATE_INTERVAL then
        updateLabelPositions(updateAccumulator)
        updateAccumulator = 0
    end
end

-- Engine handler: Load
local function onLoad()
    -- Update screen size cache
    projection.updateScreenSize()
    logger.debug('Player script loaded')
end

logger.info('Interactable Highlight player script initialized')

return {
    engineHandlers = {
        onUpdate = onUpdate,
        onLoad = onLoad
    },
    eventHandlers = {
        IH_ShowHighlights = onShowHighlights,
        IH_HideHighlights = onHideHighlights
    }
}