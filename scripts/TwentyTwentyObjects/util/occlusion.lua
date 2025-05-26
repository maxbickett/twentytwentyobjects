-- occlusion.lua: Simple occlusion utilities for player scripts
-- Uses distance and door-based checks instead of raycasting (which requires openmw.world)

local util = require('openmw.util')
local nearby = require('openmw.nearby')
local camera = require('openmw.camera')
local types = require('openmw.types')

local M = {}

-- Cache for occlusion results (cleared each frame)
local occlusionCache = {}
local cacheFrame = 0

-- Helper function to normalize a vector
local function normalizeVector(vec)
    local len = vec:length()
    if len > 0 then
        return vec / len
    else
        return vec
    end
end

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
    -- Basic distance check first - objects too far away might not be visible
    local objDist = (object.position - playerPos):length()
    if objDist > 5000 then  -- Very far objects are likely not visible
        return false
    end
    
    -- If object is behind a closed door, it's probably not visible
    for _, door in ipairs(nearby.doors) do
        if door.isClosed then
            -- Check if door is between player and object
            local doorDist = (door.position - playerPos):length()
            
            -- Door must be closer than object
            if doorDist < objDist then
                -- Get directions
                local toObject = normalizeVector(object.position - playerPos)
                local toDoor = normalizeVector(door.position - playerPos)
                
                -- Check alignment - door must be roughly in the same direction
                local dot = toObject:dot(toDoor)
                if dot > 0.85 then  -- Tighter angle check (about 30 degrees)
                    -- Additional check: is the object close to the door?
                    -- This helps with objects that are just behind doors
                    local objectToDoor = (object.position - door.position):length()
                    if objectToDoor < 300 then  -- Object is near the door
                        return false
                    end
                end
            end
        end
    end
    
    -- Check for walls/containers that might block view
    -- This is a heuristic - large containers between player and object might block view
    for _, container in ipairs(nearby.containers) do
        local containerDist = (container.position - playerPos):length()
        if containerDist < objDist then
            local toObject = normalizeVector(object.position - playerPos)
            local toContainer = normalizeVector(container.position - playerPos)
            
            local dot = toObject:dot(toContainer)
            if dot > 0.9 then  -- Very tight angle
                -- Check if it's a large container (by checking if it has collision)
                local objectToContainer = (object.position - container.position):length()
                if objectToContainer < 150 then
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