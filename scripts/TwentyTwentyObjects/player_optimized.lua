-- player_optimized.lua: Optimized player script for Twenty Twenty Objects Mod
-- Handles object scanning and label display with performance optimizations

local nearby = require('openmw.nearby')
local ui = require('openmw.ui')
local util = require('openmw.util')
local types = require('openmw.types')
local self = require('openmw.self')
local async = require('openmw.async')

-- Import utilities
local projection = require('scripts.TwentyTwentyObjects.util.projection')
local logger_module = require('scripts.TwentyTwentyObjects.util.logger')
local storage_module = require('scripts.TwentyTwentyObjects.util.storage')
local spatial = require('scripts.TwentyTwentyObjects.util.spatial')
local labelLayout = require('scripts.TwentyTwentyObjects.util.labelLayout')

-- Forward declare
local generalSettings = {}

-- Performance configuration
local CONFIG = {
    MAX_LABELS = 25,              -- Maximum labels to show at once
    UPDATE_INTERVAL = 0.033,      -- ~30fps for label updates
    SCAN_INTERVAL = 0.25,         -- Rescan objects 4 times per second
    GROUP_THRESHOLD = 60,         -- Group labels within 60 pixels
    CULL_DISTANCE = 3000,         -- Don't show labels beyond this distance
    MIN_LABEL_SIZE = 10,          -- Minimum readable text size
    MAX_LABEL_SIZE = 18,          -- Maximum text size
    FADE_DURATION = 0.2,          -- Fade in/out duration
    LOD_DISTANCES = {             -- Level of detail thresholds
        NEAR = 500,               -- Full detail
        MEDIUM = 1500,            -- Reduced detail
        FAR = 3000                -- Minimal detail
    }
}

-- State tracking
local activeLabels = {}
local currentProfile = nil
local updateAccumulator = 0
local scanAccumulator = 0
local frameCount = 0
local labelIdCounter = 0

-- Cache for performance
local labelCache = {}
local visibilityCache = {}

-- Enhanced label style with size scaling
local function getLabelStyle(distance)
    local scale = 1.0
    if distance then
        -- Scale based on distance
        if distance < CONFIG.LOD_DISTANCES.NEAR then
            scale = 1.0
        elseif distance < CONFIG.LOD_DISTANCES.MEDIUM then
            scale = 0.8
        else
            scale = 0.6
        end
    end
    
    return {
        textSize = math.max(CONFIG.MIN_LABEL_SIZE, CONFIG.MAX_LABEL_SIZE * scale),
        textColor = util.color.rgba(1, 1, 1, 1),
        shadowColor = util.color.rgba(0, 0, 0, 0.8),
        shadowOffset = util.vector2(1, 1),
        padding = 4
    }
end

-- Create optimized label with caching
local function createOptimizedLabel(text, style, id)
    -- Check cache first
    if labelCache[id] and labelCache[id].text == text then
        return labelCache[id].ui
    end
    
    local label = ui.create({
        layer = 'HUD',
        type = ui.TYPE.Container,
        props = {
            anchor = util.vector2(0.5, 1),
            visible = true,
            alpha = 0  -- Start invisible for fade-in
        },
        content = ui.content({
            {
                type = ui.TYPE.Text,
                props = {
                    text = text,
                    textSize = style.textSize,
                    textColor = style.shadowColor,
                    position = style.shadowOffset
                }
            },
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
    })
    
    -- Cache the label
    labelCache[id] = {
        ui = label,
        text = text,
        style = style
    }
    
    return label
end

-- Optimized object scanning with spatial hashing
local function scanObjectsOptimized(profile)
    logger_module.debug('Optimized scan starting')
    
    local playerPos = self.position
    local candidates = {}
    
    -- Clear spatial hash for fresh scan
    spatial.spatialHash:clear()
    
    -- First pass: frustum culling and spatial insertion
    local function processObjectList(objects, typeCheck)
        for _, obj in ipairs(objects) do
            -- Early frustum check
            if spatial.isInFrustum(obj.position) then
                -- Insert into spatial hash
                spatial.spatialHash:insert(obj, obj.position)
                
                -- Calculate priority
                local priority = spatial.calculatePriority(obj, playerPos)
                
                table.insert(candidates, {
                    object = obj,
                    position = obj.position,
                    priority = priority,
                    distance = (obj.position - playerPos):length()
                })
            end
        end
    end
    
    -- Process each object type if filtered
    if profile.filters.npcs or profile.filters.creatures then
        processObjectList(nearby.actors, function(obj)
            return (profile.filters.npcs and obj.type == types.NPC) or
                   (profile.filters.creatures and obj.type == types.Creature)
        end)
    end
    
    if profile.filters.items or profile.filters.weapons or profile.filters.armor or 
       profile.filters.clothing or profile.filters.books or profile.filters.ingredients or 
       profile.filters.misc then
        processObjectList(nearby.items)
    end
    
    if profile.filters.containers then
        processObjectList(nearby.containers)
    end
    
    if profile.filters.doors then
        processObjectList(nearby.doors)
    end
    
    -- Second pass: radius check using spatial hash
    local results = spatial.spatialHash:queryRadius(playerPos, profile.radius)
    
    -- Sort by priority and cull
    table.sort(results, function(a, b)
        return a.priority > b.priority
    end)
    
    -- Keep only top N objects
    local culled = {}
    for i = 1, math.min(#results, CONFIG.MAX_LABELS * 2) do  -- Keep 2x for grouping
        culled[i] = results[i]
    end
    
    return culled
end

-- Create labels with overlap prevention
local function createLabelsWithLayout(objects)
    local labelData = {}
    labelLayout.solver:clear()
    
    -- First, calculate all screen positions
    for _, objData in ipairs(objects) do
        local worldPos = projection.getObjectLabelPosition(objData.object)
        local screenPos = projection.worldToScreen(worldPos)
        
        if screenPos and projection.isOnScreen(screenPos, 50) then
            local name = getObjectName(objData.object)
            local style = getLabelStyle(objData.distance)
            
            -- Estimate label size (rough approximation)
            local labelWidth = #name * style.textSize * 0.6
            local labelHeight = style.textSize * 1.5
            
            table.insert(labelData, {
                object = objData.object,
                name = name,
                screenPos = screenPos,
                width = labelWidth,
                height = labelHeight,
                priority = objData.priority,
                distance = objData.distance,
                style = style
            })
        end
    end
    
    -- Group nearby labels if too many
    if #labelData > CONFIG.MAX_LABELS then
        local groups = labelLayout.groupNearbyLabels(labelData, CONFIG.GROUP_THRESHOLD)
        labelData = {}
        
        for _, group in ipairs(groups) do
            local merged = labelLayout.createGroupLabel(group)
            merged.style = getLabelStyle(merged.distance)
            table.insert(labelData, merged)
        end
    end
    
    -- Cull by priority if still too many
    labelData = labelLayout.cullLabelsByPriority(labelData, CONFIG.MAX_LABELS)
    
    -- Create actual labels with layout solving
    local newLabels = {}
    for _, data in ipairs(labelData) do
        -- Generate unique ID
        labelIdCounter = labelIdCounter + 1
        local labelId = string.format("label_%d", labelIdCounter)
        
        -- Solve for non-overlapping position
        local finalPos = labelLayout.solver:addLabel(
            data.screenPos,
            data.width,
            data.height,
            data.priority,
            data
        )
        
        -- Apply smooth movement
        finalPos = labelLayout.smoothLabelPosition(labelId, finalPos, CONFIG.UPDATE_INTERVAL)
        
        -- Create the label UI
        local label = createOptimizedLabel(data.name, data.style, labelId)
        
        table.insert(newLabels, {
            id = labelId,
            object = data.object,
            ui = label,
            name = data.name,
            targetPos = finalPos,
            currentPos = finalPos,
            alpha = 0,  -- For fade-in
            targetAlpha = labelLayout.calculateLabelAlpha(data, self.position, CONFIG.CULL_DISTANCE),
            priority = data.priority,
            isGroup = data.isGroup
        })
    end
    
    return newLabels
end

-- Smooth label updates with interpolation
local function updateLabelsSmooth(dt)
    local toRemove = {}
    
    for i, labelData in ipairs(activeLabels) do
        local label = labelData.ui
        
        -- Update alpha for fade effects
        if labelData.alpha < labelData.targetAlpha then
            labelData.alpha = math.min(labelData.targetAlpha, 
                                      labelData.alpha + dt / CONFIG.FADE_DURATION)
        elseif labelData.alpha > labelData.targetAlpha then
            labelData.alpha = math.max(labelData.targetAlpha, 
                                      labelData.alpha - dt / CONFIG.FADE_DURATION)
        end
        
        -- Remove fully faded labels
        if labelData.alpha <= 0 and labelData.targetAlpha <= 0 then
            label:destroy()
            table.insert(toRemove, i)
        else
            -- Update position with smoothing
            local smoothPos = labelLayout.smoothLabelPosition(
                labelData.id,
                labelData.targetPos,
                dt
            )
            
            label.layout.props.position = smoothPos
            label.layout.props.alpha = labelData.alpha
            label:update()
        end
    end
    
    -- Remove dead labels
    for i = #toRemove, 1, -1 do
        table.remove(activeLabels, toRemove[i])
    end
end

-- Main update function with dual-rate updates
local function onUpdate(dt)
    if not currentProfile or #activeLabels == 0 then
        return
    end
    
    frameCount = frameCount + 1
    
    -- Update label positions at reduced rate
    updateAccumulator = updateAccumulator + dt
    if updateAccumulator >= CONFIG.UPDATE_INTERVAL then
        updateLabelsSmooth(updateAccumulator)
        updateAccumulator = 0
    end
    
    -- Rescan objects at even lower rate
    scanAccumulator = scanAccumulator + dt
    if scanAccumulator >= CONFIG.SCAN_INTERVAL then
        -- Quick visibility check for existing labels
        for _, labelData in ipairs(activeLabels) do
            if labelData.object and labelData.object:isValid() then
                local worldPos = projection.getObjectLabelPosition(labelData.object)
                local screenPos = projection.worldToScreen(worldPos)
                
                if screenPos and projection.isOnScreen(screenPos, 50) then
                    labelData.targetPos = screenPos
                    labelData.targetAlpha = labelLayout.calculateLabelAlpha(
                        labelData, self.position, CONFIG.CULL_DISTANCE
                    )
                else
                    labelData.targetAlpha = 0  -- Fade out
                end
            else
                labelData.targetAlpha = 0  -- Object gone, fade out
            end
        end
        
        scanAccumulator = 0
    end
end

-- Show highlights with optimizations
local function onShowHighlights(eventData)
    currentProfile = eventData.profile
    
    -- Clear existing labels with fade-out
    for _, labelData in ipairs(activeLabels) do
        labelData.targetAlpha = 0
    end
    
    -- Scan and create new labels
    local objects = scanObjectsOptimized(currentProfile)
    local newLabels = createLabelsWithLayout(objects)
    
    -- Merge with existing (for smooth transitions)
    for _, newLabel in ipairs(newLabels) do
        table.insert(activeLabels, newLabel)
    end
    
    -- Update temporal cache
    spatial.updateTemporalCache(objects)
end

-- Hide highlights with fade-out
local function onHideHighlights(eventData)
    -- Fade out all labels
    for _, labelData in ipairs(activeLabels) do
        labelData.targetAlpha = 0
    end
    
    currentProfile = nil
    
    -- Cleanup will happen in update loop
end

-- Load handler
local function onLoad()
    -- local engine_storage = require('openmw.storage') -- No longer needed here
    -- storage_module.init(engine_storage) -- No longer needed here

    generalSettings = storage_module.get('general', { debug = false })
    logger_module.init(storage_module, generalSettings.debug)

    projection.updateScreenSize()
    
    -- Clear caches
    labelCache = {}
    visibilityCache = {}
    labelLayout.cleanupSmoothPositions({})
    
    logger_module.debug('Optimized player script loaded')
end

-- Helper function (kept from original)
local function getObjectName(object)
    local objType = object.type
    
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
    
    return object.recordId or "Unknown"
end

logger_module.info('Interactable Highlight optimized player script (player_optimized.lua) parsed.')

return {
    engineHandlers = {
        onUpdate = onUpdate,
        onLoad = onLoad
    },
    eventHandlers = {
        TTO_ShowHighlights = onShowHighlights,
        TTO_HideHighlights = onHideHighlights
    }
}