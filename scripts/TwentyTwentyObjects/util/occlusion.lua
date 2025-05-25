-- occlusion.lua: Raycasting utilities to hide labels behind walls
-- Critical for preventing immersion-breaking see-through-walls labels

local world = require('openmw.world')
local util = require('openmw.util')
local nearby = require('openmw.nearby')

local M = {}

-- Cache for occlusion results (cleared each frame)
local occlusionCache = {}
local cacheFrame = 0

-- Raycast from player to object to check for obstructions
function M.isObjectVisible(object, playerPos)
    -- Generate cache key
    local key = tostring(object)
    
    -- Check cache first
    if occlusionCache[key] and occlusionCache[key].frame == cacheFrame then
        return occlusionCache[key].visible
    end
    
    -- Get object center position
    local targetPos = object.position
    local bbox = object:getBoundingBox()
    if bbox then
        -- Use center of bounding box
        targetPos = object.position + util.vector3(0, 0, (bbox.max.z - bbox.min.z) / 2)
    end
    
    -- Cast ray from player eye level to object
    local eyeOffset = util.vector3(0, 0, 60)  -- Approximate eye height
    local rayStart = playerPos + eyeOffset
    local rayEnd = targetPos
    
    -- Perform raycast
    local hitResult = world.castRay(rayStart, rayEnd, {
        ignore = {object},  -- Don't hit the target object itself
        collisionType = world.COLLISION_TYPE.World  -- Check world geometry
    })
    
    -- Object is visible if ray reaches it without hitting anything
    local visible = (hitResult.hit == false)
    
    -- Cache result
    occlusionCache[key] = {
        frame = cacheFrame,
        visible = visible
    }
    
    return visible
end

-- Check multiple points on large objects for better accuracy
function M.isLargeObjectVisible(object, playerPos)
    local bbox = object:getBoundingBox()
    if not bbox then
        return M.isObjectVisible(object, playerPos)
    end
    
    -- Check corners of bounding box
    local testPoints = {
        object.position + util.vector3(bbox.min.x, bbox.min.y, bbox.max.z),  -- Top corners
        object.position + util.vector3(bbox.max.x, bbox.min.y, bbox.max.z),
        object.position + util.vector3(bbox.min.x, bbox.max.y, bbox.max.z),
        object.position + util.vector3(bbox.max.x, bbox.max.y, bbox.max.z),
        object.position + util.vector3(0, 0, bbox.max.z)  -- Top center
    }
    
    -- Object is visible if ANY test point is visible
    for _, point in ipairs(testPoints) do
        local eyeOffset = util.vector3(0, 0, 60)
        local rayStart = playerPos + eyeOffset
        
        local hitResult = world.castRay(rayStart, point, {
            ignore = {object},
            collisionType = world.COLLISION_TYPE.World
        })
        
        if not hitResult.hit then
            return true  -- At least one point is visible
        end
    end
    
    return false
end

-- Fast approximate check using nearby doors
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
    if quality == "high" then
        return M.isLargeObjectVisible
    elseif quality == "medium" then
        return M.isObjectVisible
    elseif quality == "low" then
        return M.quickDoorCheck
    else
        return function() return true end  -- No occlusion
    end
end

return M