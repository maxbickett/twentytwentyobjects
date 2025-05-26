-- projection.lua: World-to-screen projection utilities for Interactable Highlight mod
-- Handles converting 3D world positions to 2D screen coordinates

local ui = require('openmw.ui')
local util = require('openmw.util')
local camera = require('openmw.camera')

local M = {}

-- Cache screen size to avoid repeated lookups
local screenSize = ui.screenSize()

-- Logger for debugging
local logger = require('scripts.TwentyTwentyObjects.util.logger')

-- Update cached screen size (call on resolution change)
function M.updateScreenSize()
    screenSize = ui.screenSize()
    logger.debug(string.format('Screen size updated: %dx%d', screenSize.x, screenSize.y))
end

-- Convert world position to screen coordinates
-- Returns vector2 or nil if position is behind camera
function M.worldToScreen(worldPos)
    -- Use OpenMW's camera projection function
    local viewportPos = camera.worldToViewportVector(worldPos)
    
    -- Check if behind camera (negative z means behind)
    if viewportPos.z < 0 then
        return nil
    end
    
    -- Update screen size if needed
    if not screenSize or screenSize.x == 0 then
        M.updateScreenSize()
    end
    
    -- The x and y components are already in screen coordinates!
    -- (0,0) is top-left corner of screen
    return util.vector2(viewportPos.x, viewportPos.y)
end

-- Get the top-center position of an object's bounding box
function M.getObjectLabelPosition(object)
    local pos = object.position
    
    -- Try to get bounding box if the method exists
    local bbox = nil
    local success, result = pcall(function() return object:getBoundingBox() end)
    if success then
        bbox = result
    end
    
    if bbox and bbox.max and bbox.max.z then
        -- Use top of bounding box
        return util.vector3(
            pos.x,
            pos.y,
            pos.z + bbox.max.z + 10  -- Add 10 units above for clearance
        )
    else
        -- Fallback: use object position plus offset
        -- Different offsets for different object types
        local offset = 50  -- Default offset
        
        -- Try to determine object type for better offset
        if object.type then
            local types = require('openmw.types')
            if object.type == types.NPC or object.type == types.Creature then
                offset = 100  -- Taller offset for actors
            elseif object.type == types.Container then
                offset = 30   -- Lower offset for containers
            elseif object.type == types.Door then
                offset = 80   -- Medium offset for doors
            end
        end
        
        return pos + util.vector3(0, 0, offset)
    end
end

-- Check if screen position is within visible bounds
function M.isOnScreen(screenPos, margin)
    margin = margin or 0
    return screenPos.x >= -margin and 
           screenPos.x <= screenSize.x + margin and
           screenPos.y >= -margin and 
           screenPos.y <= screenSize.y + margin
end

-- Clamp screen position to stay within bounds
function M.clampToScreen(screenPos, margin)
    margin = margin or 10
    return util.vector2(
        math.max(margin, math.min(screenSize.x - margin, screenPos.x)),
        math.max(margin, math.min(screenSize.y - margin, screenPos.y))
    )
end

-- Get distance-based scale factor for labels
function M.getDistanceScale(distance, minDist, maxDist)
    minDist = minDist or 100
    maxDist = maxDist or 2000
    
    -- Clamp distance to range
    distance = math.max(minDist, math.min(maxDist, distance))
    
    -- Linear interpolation (could use other curves)
    local t = (distance - minDist) / (maxDist - minDist)
    return 1.0 - (t * 0.5)  -- Scale from 100% to 50%
end

return M