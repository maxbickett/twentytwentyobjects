-- projection.lua: World-to-screen projection utilities for Interactable Highlight mod
-- Handles converting 3D world positions to 2D screen coordinates

local ui = require('openmw.ui')
local util = require('openmw.util')
local camera = require('openmw.camera')

local M = {}

-- Cache screen size to avoid repeated lookups
local screenSize = ui.screenSize()

-- Update cached screen size (call on resolution change)
function M.updateScreenSize()
    screenSize = ui.screenSize()
end

-- Convert world position to screen coordinates
-- Returns vector2 or nil if position is behind camera
function M.worldToScreen(worldPos)
    -- Get camera position and look direction
    local camPos = camera.getPosition()
    local camMatrix = camera.getViewMatrix()
    
    -- Transform world position to camera space
    local relativePos = worldPos - camPos
    
    -- Apply view matrix transformation
    -- This is simplified - in practice we'd need full matrix math
    -- For now, approximate with basic projection
    local viewPos = util.transform.apply(camMatrix, relativePos)
    
    -- Check if behind camera
    if viewPos.z >= 0 then
        return nil
    end
    
    -- Get field of view
    local fovY = camera.getFieldOfView()
    local aspect = screenSize.x / screenSize.y
    
    -- Project to normalized device coordinates
    local tanHalfFov = math.tan(fovY / 2)
    local projX = viewPos.x / (-viewPos.z * tanHalfFov * aspect)
    local projY = viewPos.y / (-viewPos.z * tanHalfFov)
    
    -- Convert to screen coordinates
    local screenX = (projX + 1) * screenSize.x / 2
    local screenY = (1 - projY) * screenSize.y / 2
    
    return util.vector2(screenX, screenY)
end

-- Get the top-center position of an object's bounding box
function M.getObjectLabelPosition(object)
    local pos = object.position
    local bbox = object:getBoundingBox()
    
    if bbox then
        -- Use top of bounding box
        return util.vector3(
            pos.x,
            pos.y,
            bbox.max.z + 10  -- Add 10 units above for clearance
        )
    else
        -- Fallback: use object position plus offset
        return pos + util.vector3(0, 0, 50)
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