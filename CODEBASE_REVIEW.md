# TwentyTwentyObjects Codebase Review

## Issues Found and Fixes Applied

### 1. **Immediate Error Fixed**
- **Issue**: `attempt to concatenate field 'shows' (a nil value)` in settings_improved.lua
- **Cause**: PRESETS array was missing the 'shows' field
- **Fix**: Added 'shows' field to all preset definitions

### 2. **Storage System Issues**
- **Issue**: "Profiles data in storage was not a table (type: userdata)"
- **Cause**: OpenMW storage returns userdata objects that need proper handling
- **Analysis**: The storage module correctly handles this by returning empty table, but the warning is spammy
- **Recommendation**: This is actually working as designed - OpenMW storage returns userdata until properly initialized

### 3. **UI Layout Issues (Previously Fixed)**
- Added scrollable container for tab content
- Fixed preset card sizing with autoSize property
- Added missing createPerformancePreset function

### 4. **Architecture Analysis**

#### Strengths:
1. **Modular Design**: Good separation of concerns with util modules
2. **Event-Driven**: Proper use of OpenMW's event system
3. **Storage Abstraction**: Good encapsulation of storage operations
4. **Logging System**: Comprehensive debug logging

#### Weaknesses:
1. **Missing Utility Modules**: player_native.lua requires many util modules that may have issues
2. **Complex Initialization**: Multiple initialization points that could fail
3. **Profile Storage**: The userdata warning suggests profiles aren't being saved properly

### 5. **Potential Issues to Investigate**

1. **Missing Dependencies in player_native.lua**:
   - projection module
   - spatial module  
   - occlusion module
   - labelRenderer_native module
   - labelLayout_jitter module

2. **Async Operations**: Heavy use of async callbacks which could fail silently

3. **Storage Initialization Timing**: The storage module might be accessed before OpenMW's storage system is ready

### 6. **Recommendations**

1. **Simplify Initial State**: Start with empty profiles instead of defaults to avoid storage conflicts
2. **Add Error Boundaries**: Wrap critical sections in pcall to prevent cascading failures
3. **Reduce Module Dependencies**: Consider consolidating some util modules
4. **Add Fallback Rendering**: If advanced rendering fails, fall back to simple text labels

### 7. **Next Steps**

1. Test if the mod loads without errors after the 'shows' field fix
2. Check if labels appear when using the hotkeys
3. Monitor logs for any remaining errors
4. Consider simplifying the rendering pipeline if issues persist 