-- occlusion.lua: Simple occlusion utilities for player scripts
-- Uses distance and door-based checks instead of raycasting (which requires openmw.world)

local util = require('openmw.util')
local nearby = require('openmw.nearby')

local M = {}

-- Cache for occlusion results (cleared each frame)
local occlusionCache = {}
local cacheFrame = 0

-- Simple visibility check using distance and doors
function M.isObjectVisible(object, playerPos)
    -- Generate cache key
    local key = tostring(object)
    
    -- Check cache first
    if occlusionCache[key] and occlusionCache[key].frame == cacheFrame then
        return occlusionCache[key].visible
    end
    
    -- Default to visible
    local visible = true
    
    -- Check if object is behind closed doors
    visible = M.quickDoorCheck(object, playerPos)
    
    -- Cache result
    occlusionCache[key] = {
        frame = cacheFrame,
        visible = visible
    }
    
    return visible
end

-- Alias for compatibility
function M.isLargeObjectVisible(object, playerPos)
    return M.isObjectVisible(object, playerPos)
end

-- Check using nearby doors (player script compatible)
function M.quickDoorCheck(object, playerPos)
    -- If object is behind a closed door, it's probably not visible
    for _, door in ipairs(nearby.doors) do
        if door.isClosed then
            -- Check if door is between player and object
            local doorDist = (door.position - playerPos):length2()
            local objDist = (object.position - playerPos):length2()
            
            if doorDist < objDist then
                -- Door is closer than object, check if it blocks line of sight
                local toObject = (object.position - playerPos):normalized()
                local toDoor = (door.position - playerPos):normalized()
                
                local dot = toObject:dot(toDoor)
                if dot > 0.8 then  -- Door is roughly in the way
                    return false
                end
            end
        end
    end
    
    return true
end

-- Update cache frame
function M.newFrame()
    cacheFrame = cacheFrame + 1
    -- Clear cache periodically to prevent memory bloat
    if cacheFrame % 100 == 0 then
        occlusionCache = {}
    end
end

-- Get occlusion method based on performance setting
function M.getOcclusionMethod(quality)
    if quality == "high" or quality == "medium" then
        return M.isObjectVisible
    elseif quality == "low" then
        return M.quickDoorCheck
    else
        return function() return true end  -- No occlusion
    end
end

return M