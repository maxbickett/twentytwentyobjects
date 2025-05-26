# TwentyTwentyObjects UI/UX Improvement Plan

## Executive Summary
This document outlines the UI/UX improvements needed for the TwentyTwentyObjects settings menu to enhance usability, visual feedback, and overall user experience. The plan references successful patterns from the PCP mod while maintaining the unique identity of TTO.

## Current State Analysis

### Strengths
- Tab-based navigation system
- Visual preset cards with clear descriptions
- Color-coded UI elements (headers, values, clickable items)
- Hover effects on interactive elements

### Weaknesses
- Key binding functionality not implemented ("Change Key" button does nothing)
- No visual feedback when settings are saved
- Slider interaction is basic (click-only, no drag)
- No confirmation dialogs for destructive actions
- Missing tooltips for complex settings
- No visual preview of label appearance changes
- Profile management lacks delete/rename functionality

## User Stories & Acceptance Criteria

### 1. Key Binding Configuration
**User Story**: As a player, I want to easily change hotkeys for my profiles so I can avoid conflicts with other mods.

**Acceptance Criteria**:
- [ ] Clicking "Change Key" enters a listening mode with clear visual feedback
- [ ] Display "Press any key..." overlay during binding mode
- [ ] Show current key combination while waiting for input
- [ ] Allow ESC to cancel binding
- [ ] Validate against reserved keys (ESC, Enter, etc.)
- [ ] Show success/error feedback after binding

**Implementation Details**:
```lua
-- Visual overlay during key binding
{
    type = ui.TYPE.Container,
    props = {
        backgroundColor = {0, 0, 0, 0.8},
        position = v2(0, 0),
        relativeSize = v2(1, 1),
        visible = awaitingKeypress
    },
    content = ui.content({
        {
            type = ui.TYPE.Text,
            props = {
                text = "Press any key combination...\n(ESC to cancel)",
                textAlign = ui.ALIGNMENT.Center,
                textSize = 24
            }
        }
    })
}
```

### 2. Interactive Sliders
**User Story**: As a player, I want to drag sliders to quickly adjust values instead of clicking multiple times.

**Acceptance Criteria**:
- [ ] Sliders respond to mouse drag
- [ ] Show real-time value updates while dragging
- [ ] Snap to reasonable increments (50 units for range, 5 for other values)
- [ ] Highlight active slider track
- [ ] Support keyboard input for precise values

**Implementation Details**:
```lua
-- Enhanced slider with drag support
events = {
    mousePress = c(function(e)
        isDragging = true
        updateSliderValue(e.position.x)
    end),
    mouseRelease = c(function(e)
        isDragging = false
    end),
    mouseMove = c(function(e)
        if isDragging then
            updateSliderValue(e.position.x)
        end
    end)
}
```

### 3. Save Confirmation & Feedback
**User Story**: As a player, I want clear feedback when my settings are saved so I know my changes took effect.

**Acceptance Criteria**:
- [ ] Show toast notification on successful save
- [ ] Animate save button on click
- [ ] Display "Saved!" text briefly
- [ ] Use success color (green) for positive feedback
- [ ] Auto-fade notification after 2 seconds

**Implementation Details**:
```lua
-- Toast notification system
local function showToast(message, type)
    local toast = {
        type = ui.TYPE.Container,
        props = {
            backgroundColor = type == "success" and {0.2, 0.5, 0.2, 0.9} or {0.5, 0.2, 0.2, 0.9},
            position = v2(ui.screenSize().x / 2, 50),
            anchor = v2(0.5, 0),
            padding = 15,
            borderRadius = 8
        },
        content = ui.content({
            {
                type = ui.TYPE.Text,
                props = {
                    text = message,
                    textColor = {1, 1, 1, 1}
                }
            }
        })
    }
    -- Animate and auto-remove
end
```

### 4. Profile Management
**User Story**: As a player, I want to rename and delete profiles to keep my list organized.

**Acceptance Criteria**:
- [ ] Right-click context menu on profiles
- [ ] Inline rename with text input
- [ ] Delete confirmation dialog
- [ ] Duplicate profile option
- [ ] Reorder profiles via drag & drop

**Implementation Details**:
```lua
-- Context menu for profile actions
local function createContextMenu(profile, position)
    return {
        type = ui.TYPE.Container,
        props = {
            position = position,
            backgroundColor = {0.1, 0.1, 0.1, 0.95},
            borderColor = {0.3, 0.3, 0.3, 1},
            borderSize = 1
        },
        content = ui.content({
            createMenuItem("Rename", function() startRename(profile) end),
            createMenuItem("Duplicate", function() duplicateProfile(profile) end),
            createMenuItem("Delete", function() confirmDelete(profile) end)
        })
    }
end
```

### 5. Visual Preview System
**User Story**: As a player, I want to preview how labels will look before applying changes.

**Acceptance Criteria**:
- [ ] Live preview panel in Appearance tab
- [ ] Update preview as settings change
- [ ] Show sample labels with different states
- [ ] Include line style preview
- [ ] Demonstrate animation effects

**Implementation Details**:
```lua
-- Preview panel with sample labels
local function createPreviewPanel()
    return {
        type = ui.TYPE.Container,
        props = {
            backgroundColor = {0.05, 0.05, 0.05, 0.8},
            minHeight = 200,
            borderRadius = 4
        },
        content = ui.content({
            createSampleLabel("Iron Sword", {distance = "near"}),
            createSampleLabel("Wooden Door", {distance = "far", line = true}),
            createSampleLabel("NPC Name", {animated = true})
        })
    }
end
```

### 6. Enhanced Tooltips
**User Story**: As a player, I want helpful tooltips that explain what each setting does.

**Acceptance Criteria**:
- [ ] Hover tooltips for all settings
- [ ] Include current value and valid range
- [ ] Show keyboard shortcuts where applicable
- [ ] Position intelligently to avoid screen edges
- [ ] Consistent styling with game UI

### 7. Improved Filter UI
**User Story**: As a player, I want a clearer way to select what objects to highlight.

**Acceptance Criteria**:
- [ ] Visual icons for each category
- [ ] Select all/none buttons per category
- [ ] Show count of selected filters
- [ ] Collapsible categories to save space
- [ ] Search/filter for specific object types

## Visual Design Guidelines

### Color Palette
- **Primary**: `{0.2, 0.3, 0.4}` - Active elements
- **Success**: `{0.2, 0.5, 0.2}` - Positive feedback
- **Warning**: `{0.5, 0.4, 0.2}` - Caution states
- **Error**: `{0.5, 0.2, 0.2}` - Error states
- **Hover**: `{0.3, 0.4, 0.5, 0.8}` - Interactive hover

### Typography
- **Headers**: 18px, `HEADER_TEXT_COLOR`
- **Body**: 14px, `DEFAULT_TEXT_COLOR`
- **Values**: 14px, `VALUE_TEXT_COLOR`
- **Buttons**: 14px, `CLICKABLE_TEXT_COLOR`

### Spacing
- **Section padding**: 15px
- **Element margins**: 5-10px
- **Button padding**: 8-15px horizontal, 8-10px vertical

### Animation Timings
- **Hover transitions**: 0.15s ease-out
- **Toggle animations**: 0.2s ease-in-out
- **Toast notifications**: 0.3s fade-in, 2s display, 0.3s fade-out

## Technical Considerations

### Performance
- Debounce slider updates to prevent excessive events
- Cache UI elements that don't change frequently
- Use visibility toggling instead of recreation
- Limit animation frame updates

### Compatibility
- Test with different screen resolutions
- Ensure gamepad navigation works
- Support keyboard-only interaction
- Maintain compatibility with screen readers

### State Management
- Centralize UI state in module scope
- Use events for cross-component communication
- Implement undo/redo for settings changes
- Save draft changes before confirming

## Implementation Priority

1. **High Priority** (Core Functionality)
   - Key binding implementation
   - Save feedback system
   - Interactive sliders

2. **Medium Priority** (Enhanced Usability)
   - Profile management features
   - Tooltips system
   - Visual preview

3. **Low Priority** (Polish)
   - Animations and transitions
   - Advanced filter UI
   - Keyboard shortcuts

## Testing Checklist

- [ ] All interactive elements have hover states
- [ ] Tab navigation works correctly
- [ ] Settings persist after game restart
- [ ] No UI elements overlap at minimum resolution
- [ ] Error states are clearly communicated
- [ ] All text is localization-ready
- [ ] Performance remains smooth with menu open

## References
- PCP mod UI patterns for consistent OpenMW mod experience
- Morrowind vanilla UI guidelines for familiarity
- Modern UI best practices adapted for game context 