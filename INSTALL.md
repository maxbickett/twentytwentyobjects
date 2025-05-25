# Installation Guide

## Requirements
- OpenMW 0.49 or later
- Lua scripting enabled in OpenMW settings

## Installation Steps

1. **Download** this mod folder
2. **Copy** the entire `InteractableHighlight` folder to your OpenMW data directory:
   - **Windows**: `Documents/My Games/OpenMW/data/`
   - **Linux**: `~/.local/share/openmw/data/`
   - **macOS**: `~/Documents/OpenMW/data/`

3. **Enable Lua scripting** in OpenMW:
   - Open OpenMW Launcher
   - Go to Advanced → Settings
   - Find `[Lua]` section
   - Set `enabled = true`

4. **Add the mod** to your load order:
   - In OpenMW Launcher, go to Data Files
   - Check the box next to `InteractableHighlight.omwscripts`

5. **Launch the game**

## Default Controls
- **F1**: Toggle object labels on/off
- **F2**: Cycle label modes (all objects → containers only → off)

## Settings
- Press ESC → Options → Scripts → Interactable Highlight
- Adjust hotkeys, distance, visual settings

## Troubleshooting
- If labels don't appear: Check that Lua scripting is enabled
- If hotkeys don't work: Check for key conflicts in settings
- Performance issues: Reduce detection distance in settings