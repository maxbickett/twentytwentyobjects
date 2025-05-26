# TwentyTwentyObjects Fixes Summary

## Issues Fixed

### 1. Behind-Camera Detection
**Problem**: Objects behind the camera were still showing labels
**Solution**: 
- Simplified the worldToScreen function to use viewport coordinates more effectively
- Added check for extreme viewport coordinates (abs > 2000) which indicate behind camera projection artifacts
- Added check for negative viewport coordinates (< -50) which indicate behind camera
- Added aggressive screen bounds checking
- Added distance-from-center check to filter objects too far to the sides
- Objects with z <= 1, extreme viewport coords, or outside screen bounds are filtered out

### 2. Occlusion Detection  
**Problem**: Objects behind walls were showing labels
**Solution**:
- Replaced fake occlusion checks with actual raycasting using `nearby.castRay`
- Ray is cast from player position to object position
- Checks for World and Door collision types
- If ray hits something other than the target object, it's occluded

### 3. Performance Optimization
**Problem**: Redundant calculations in the render loop
**Solution**:
- Pre-calculate world and screen positions during gathering phase
- Store positions with candidates to avoid recalculation
- Only update positions when labels are actually shown

### 4. Line Visibility
**Problem**: Lines weren't showing between labels and objects
**Solution**:
- Lowered the threshold for showing lines from 40 to 20 pixels
- Fixed mismatch between `showLine` calculation (20px) and `getLineStyle` function (was 50px)
- Added debug logging to track line creation
- Lines now show when labels are positioned away from their objects

### 5. Debug Logging
**Problem**: Hard to diagnose issues
**Solution**:
- Added extensive debug logging for:
  - Behind-camera detection reasons
  - Occlusion detection with object names
  - Line creation attempts and styles
  - Screen position calculations

## Current Behavior

When you press the hotkey:
1. Objects behind you are filtered out (extreme viewport coordinates)
2. Objects behind walls are filtered via raycasting
3. Labels appear for visible objects
4. Lines connect labels to objects when they're more than 20 pixels apart
5. Debug logs show exactly why objects are filtered

## Testing

To verify the fixes work:
1. Stand in a room with objects in front and behind you
2. Press the hotkey - only objects in front should show labels
3. Look for connecting lines on labels that are offset from objects
4. Check the debug logs for filtering reasons

## Key Changes

### projection.lua
- Removed complex dot product calculations for camera direction
- Simplified to use viewport z-distance and screen bounds
- Added check for negative viewport coordinates (behind camera)
- Added center-distance check for objects too far to the sides
- More aggressive filtering with smaller margins

### occlusion.lua  
- Complete rewrite to use `nearby.castRay` for proper occlusion detection
- Added caching to avoid redundant raycasts
- Support for different performance levels (none = no occlusion check)

### player_native.lua
- Modified scanAndCreateLabels to check visibility during gathering phase
- Pre-calculate positions to avoid redundant calculations
- Objects are filtered out early if behind camera or occluded
- Added debug logging for line creation

### labelLayout_jitter.lua
- Lowered line visibility threshold from 40 to 20 pixels
- Lines will appear more frequently when labels are displaced from objects

## Testing Notes
- Debug logging is enabled to track filtering decisions
- Check console output for:
  - "Object behind camera", "Object has negative viewport coords"
  - "Object occluded by", "Object outside screen bounds"
  - "Creating line for", "Line style:", "No line for"
- The mod should now properly hide labels for:
  - Objects behind the player
  - Objects behind walls/doors
  - Objects far to the sides of the screen
- Lines should appear when labels are more than 20 pixels from their objects 