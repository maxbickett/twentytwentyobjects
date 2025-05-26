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

-- Check if object is in camera's field of view
local function isInFieldOfView(worldPos)
    local camPos = camera.getPosition()
    local toObject = worldPos - camPos
    
    -- Get camera's view transform to extract forward direction
    local viewTransform = camera.getViewTransform()
    
    -- In OpenMW, we can derive the forward direction from the view transform
    -- The view transform converts world to camera space
    -- We need to transform a forward vector from camera space to world space
    -- In camera space, forward is typically (0, 0, -1)
    local camSpaceForward = util.vector3(0, 0, -1)
    
    -- To get world space forward, we need the inverse of the view transform
    -- Since we're dealing with rotation only, we can use the transpose
    -- But let's use a simpler approach: calculate from camera angles
    local yaw = camera.getYaw() + camera.getExtraYaw()
    local pitch = camera.getPitch() + camera.getExtraPitch()
    
    -- Calculate forward vector from yaw and pitch
    -- In OpenMW, yaw 0 points north (positive Y), and increases clockwise
    local camForward = util.vector3(
        math.sin(yaw) * math.cos(pitch),
        math.cos(yaw) * math.cos(pitch),
        math.sin(pitch)
    )
    
    -- Calculate dot product to check if object is in front
    local dot = toObject:dot(camForward)
    
    -- If dot product is negative or very small, object is behind camera
    if dot <= 0 then
        logger.debug(string.format('Object behind camera: dot=%.2f', dot))
        return false
    end
    
    -- Check horizontal field of view
    -- Get the angle between the forward vector and the vector to the object
    local distance = toObject:length()
    if distance > 0 then
        local cosAngle = dot / distance  -- dot / (|toObject| * |camForward|), but |camForward| = 1
        local angle = math.acos(math.min(1, math.max(-1, cosAngle)))
        local fovRad = camera.getFieldOfView()
        
        -- Add some margin to account for screen aspect ratio and edge cases
        local maxAngle = fovRad * 0.8  -- 80% of FOV to be conservative
        
        if angle > maxAngle then
            logger.debug(string.format('Object outside FOV: angle=%.2f, maxAngle=%.2f', 
                math.deg(angle), math.deg(maxAngle)))
            return false
        end
    end
    
    return true
end

-- Convert world position to screen coordinates
-- Returns vector2 or nil if position is behind camera
function M.worldToScreen(worldPos)
    -- First check if object is in field of view
    if not isInFieldOfView(worldPos) then
        return nil
    end
    
    -- Use OpenMW's camera projection function
    local viewportPos = camera.worldToViewportVector(worldPos)
    
    -- Debug logging
    logger.debug(string.format('worldToScreen: pos=%s, viewport=%s (z=%.2f)', 
        tostring(worldPos), tostring(viewportPos), viewportPos.z))
    
    -- The z component is the distance from camera to object
    -- If it's negative or very small, the object is behind or at the camera
    if viewportPos.z <= 1 then
        logger.debug('Object behind camera (z <= 1)')
        return nil
    end
    
    -- Update screen size if needed
    if not screenSize or screenSize.x == 0 then
        M.updateScreenSize()
    end
    
    -- Convert viewport coordinates to screen coordinates
    local screenX = viewportPos.x
    local screenY = viewportPos.y
    
    -- Create screen position vector
    local screenPos = util.vector2(screenX, screenY)
    
    -- Additional bounds checking with reasonable margins
    if not M.isOnScreen(screenPos, 100) then
        logger.debug(string.format('Object outside screen bounds: (%.1f, %.1f)', screenX, screenY))
        return nil
    end
    
    return screenPos
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
        -- Use top of bounding box with minimal clearance
        return util.vector3(
            pos.x,
            pos.y,
            pos.z + bbox.max.z  -- No extra clearance, let jitter solver handle offset
        )
    else
        -- Fallback: use object position plus minimal offset
        -- The jitter solver will handle the actual label placement
        local offset = 0  -- Start at object center
        
        -- Try to determine object type for better offset
        if object.type then
            local types = require('openmw.types')
            if object.type == types.NPC or object.type == types.Creature then
                offset = 50  -- Half height for actors
            elseif object.type == types.Container then
                offset = 0   -- Use center for containers
            elseif object.type == types.Door then
                offset = 40  -- Mid-height for doors
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