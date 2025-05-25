-- labelLayout.lua: Advanced label placement and overlap prevention
-- Implements smart label positioning algorithms

local util = require('openmw.util')
local ui = require('openmw.ui')

local M = {}

-- Label placement solver using "render or wiggle" algorithm
local LabelSolver = {}
LabelSolver.__index = LabelSolver

function LabelSolver:new()
    local self = setmetatable({}, LabelSolver)
    self.placedLabels = {}
    self.labelBounds = {}
    return self
end

-- AABB collision check
function LabelSolver:overlaps(bounds1, bounds2, margin)
    margin = margin or 4
    return not (bounds1.right + margin < bounds2.left or 
                bounds2.right + margin < bounds1.left or
                bounds1.bottom + margin < bounds2.top or
                bounds2.bottom + margin < bounds1.top)
end

-- Calculate label bounds
function LabelSolver:getBounds(position, width, height)
    return {
        left = position.x - width / 2,
        right = position.x + width / 2,
        top = position.y - height,
        bottom = position.y,
        width = width,
        height = height,
        center = position
    }
end

-- Find non-overlapping position using "wiggle" strategy
function LabelSolver:findPosition(idealPos, width, height, priority)
    local bounds = self:getBounds(idealPos, width, height)
    
    -- Check if ideal position works
    local overlapping = false
    for _, existing in ipairs(self.placedLabels) do
        if self:overlaps(bounds, existing.bounds) then
            -- Lower priority labels can't displace higher priority ones
            if priority <= existing.priority then
                overlapping = true
                break
            end
        end
    end
    
    if not overlapping then
        return idealPos
    end
    
    -- Try alternate positions in a spiral pattern
    local offsets = {
        {0, -height - 4},      -- Above
        {0, height + 4},       -- Below  
        {width + 8, 0},        -- Right
        {-width - 8, 0},       -- Left
        {width/2, -height/2},  -- Diagonal positions
        {-width/2, -height/2},
        {width/2, height/2},
        {-width/2, height/2}
    }
    
    for _, offset in ipairs(offsets) do
        local newPos = idealPos + util.vector2(offset[1], offset[2])
        local newBounds = self:getBounds(newPos, width, height)
        
        overlapping = false
        for _, existing in ipairs(self.placedLabels) do
            if self:overlaps(newBounds, existing.bounds) and priority <= existing.priority then
                overlapping = true
                break
            end
        end
        
        if not overlapping then
            return newPos
        end
    end
    
    -- If all positions fail, return original (will overlap but at least visible)
    return idealPos
end

-- Add label to solver
function LabelSolver:addLabel(position, width, height, priority, data)
    local finalPos = self:findPosition(position, width, height, priority)
    local bounds = self:getBounds(finalPos, width, height)
    
    table.insert(self.placedLabels, {
        position = finalPos,
        bounds = bounds,
        priority = priority,
        data = data
    })
    
    return finalPos
end

-- Clear solver for next frame
function LabelSolver:clear()
    self.placedLabels = {}
    self.labelBounds = {}
end

-- Module functions
M.solver = LabelSolver:new()

-- Smart label grouping for dense areas
function M.groupNearbyLabels(labels, threshold)
    threshold = threshold or 50  -- Group labels within 50 pixels
    
    local groups = {}
    local assigned = {}
    
    for i, label in ipairs(labels) do
        if not assigned[i] then
            local group = {label}
            assigned[i] = true
            
            -- Find nearby labels to group
            for j = i + 1, #labels do
                if not assigned[j] then
                    local dist = (label.screenPos - labels[j].screenPos):length()
                    if dist < threshold then
                        table.insert(group, labels[j])
                        assigned[j] = true
                    end
                end
            end
            
            table.insert(groups, group)
        end
    end
    
    return groups
end

-- Create merged label for groups
function M.createGroupLabel(group)
    if #group == 1 then
        return group[1]  -- No grouping needed
    end
    
    -- Calculate center position
    local centerPos = util.vector2(0, 0)
    local names = {}
    local avgPriority = 0
    
    for _, label in ipairs(group) do
        centerPos = centerPos + label.screenPos
        table.insert(names, label.name)
        avgPriority = avgPriority + label.priority
    end
    
    centerPos = centerPos / #group
    avgPriority = avgPriority / #group
    
    -- Create merged text
    local text
    if #group <= 3 then
        text = table.concat(names, ", ")
    else
        text = string.format("%d objects", #group)
    end
    
    return {
        screenPos = centerPos,
        name = text,
        priority = avgPriority,
        isGroup = true,
        count = #group
    }
end

-- Fade labels based on various factors
function M.calculateLabelAlpha(label, playerPos, maxDistance)
    local alpha = 1.0
    
    -- Distance fade
    if label.distance then
        local distanceFactor = label.distance / maxDistance
        alpha = alpha * (1.0 - distanceFactor * 0.5)  -- Fade to 50% at max distance
    end
    
    -- Screen edge fade
    if label.screenPos then
        local screenSize = ui.screenSize()
        local edgeDist = math.min(
            label.screenPos.x,
            label.screenPos.y,
            screenSize.x - label.screenPos.x,
            screenSize.y - label.screenPos.y
        )
        
        if edgeDist < 100 then
            alpha = alpha * (edgeDist / 100)
        end
    end
    
    -- Group size fade (larger groups are more transparent)
    if label.isGroup and label.count > 3 then
        alpha = alpha * 0.7
    end
    
    return math.max(0.3, math.min(1.0, alpha))  -- Clamp between 0.3 and 1.0
end

-- Priority-based culling when too many labels
function M.cullLabelsByPriority(labels, maxLabels)
    maxLabels = maxLabels or 20  -- Show at most 20 labels
    
    if #labels <= maxLabels then
        return labels
    end
    
    -- Sort by priority (highest first)
    table.sort(labels, function(a, b) 
        return a.priority > b.priority 
    end)
    
    -- Keep only the highest priority labels
    local culled = {}
    for i = 1, maxLabels do
        culled[i] = labels[i]
    end
    
    return culled
end

-- Smooth label movement using interpolation
local smoothPositions = {}

function M.smoothLabelPosition(labelId, targetPos, deltaTime)
    deltaTime = deltaTime or 0.016  -- 60fps
    
    if not smoothPositions[labelId] then
        smoothPositions[labelId] = targetPos
        return targetPos
    end
    
    local currentPos = smoothPositions[labelId]
    local diff = targetPos - currentPos
    
    -- Exponential smoothing
    local smoothFactor = 1.0 - math.exp(-8.0 * deltaTime)  -- Adjust 8.0 for smoothness
    local newPos = currentPos + diff * smoothFactor
    
    smoothPositions[labelId] = newPos
    return newPos
end

-- Clean up smooth position cache
function M.cleanupSmoothPositions(activeLabels)
    local active = {}
    for _, label in ipairs(activeLabels) do
        if label.id then
            active[label.id] = true
        end
    end
    
    -- Remove entries for labels that no longer exist
    for id, _ in pairs(smoothPositions) do
        if not active[id] then
            smoothPositions[id] = nil
        end
    end
end

return M