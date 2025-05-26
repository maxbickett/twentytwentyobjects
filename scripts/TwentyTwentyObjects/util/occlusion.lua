-- occlusion.lua: Occlusion detection utilities for Interactable Highlight mod
-- Handles checking if objects are visible or hidden behind walls

local nearby = require('openmw.nearby')
local util = require('openmw.util')
local self = require('openmw.self')

local M = {}

-- Logger for debugging
local logger = require('scripts.TwentyTwentyObjects.util.logger')

-- Cache for occlusion results (cleared each frame)
local occlusionCache = {}
local cacheFrame = -1

-- Clear cache for new frame
function M.newFrame()
    occlusionCache = {}
    cacheFrame = cacheFrame + 1
end

-- Check if object is occluded using raycasting
local function checkOcclusionRaycast(object, playerPos)
    -- Get object center position (add some height to avoid ground collision)
    local objectPos = object.position + util.vector3(0, 0, 50)
    
    -- Cast ray from player to object
    local result = nearby.castRay(playerPos, objectPos, {
        ignore = self,  -- Ignore the player
        collisionType = nearby.COLLISION_TYPE.World + nearby.COLLISION_TYPE.Door  -- Check walls and doors
    })
    
    -- If we hit something and it's not our target object, it's occluded
    if result.hit and result.hitObject ~= object then
        logger.debug(string.format('Object %s occluded by %s', 
            object.recordId or 'unknown', 
            result.hitObject and result.hitObject.recordId or 'terrain'))
        return false
    end
    
    -- Not occluded
    return true
end

-- Simple occlusion check (always visible)
local function checkOcclusionNone(object, playerPos)
    return true
end

-- Get occlusion check method based on performance setting
function M.getOcclusionMethod(setting)
    if setting == "none" then
        return checkOcclusionNone
    else
        -- Use raycast for all other settings (low, medium, high)
        return checkOcclusionRaycast
    end
end

-- Check if object is visible (wrapper with caching)
function M.isVisible(object, playerPos, performanceSetting)
    local key = tostring(object)
    
    -- Check cache
    if occlusionCache[key] ~= nil then
        return occlusionCache[key]
    end
    
    -- Get appropriate check method
    local checkMethod = M.getOcclusionMethod(performanceSetting or "medium")
    
    -- Perform check and cache result
    local visible = checkMethod(object, playerPos)
    occlusionCache[key] = visible
    
    return visible
end

return M