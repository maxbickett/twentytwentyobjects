# Interactable Highlight for OpenMW

A dynamic object highlighting mod for OpenMW 0.49+ that displays floating text labels above interactable objects when triggered by customizable hotkeys. Perfect for finding loot in dark dungeons, tracking NPCs in crowded cities, or spotting that elusive book on a cluttered shelf.

## Features

- **Customizable Hotkey Profiles**: Create multiple profiles with different key combinations and filters
- **Object Type Filtering**: Highlight specific object types:
  - NPCs and Creatures
  - Items (weapons, armor, clothing, books, ingredients, misc)
  - Containers
  - Doors
  - Activators
- **Floating World Labels**: Clean text labels that hover above objects in 3D space
- **Two Display Modes**:
  - **Hold Mode**: Labels appear while holding the hotkey
  - **Toggle Mode**: Press once to show, press again to hide
- **Range Control**: Set custom detection radius for each profile (50-5000 units)
- **In-Game Configuration**: Full settings menu integrated with OpenMW's mod settings
- **Performance Optimized**: Event-driven design with no idle processing
- **Full Compatibility**: Works with all content mods including Tamriel Rebuilt

## Requirements

- OpenMW 0.49.0 or newer (requires Lua scripting support)

## Installation

### Manual Installation

1. Download the latest release
2. Extract the `InteractableHighlight` folder to your OpenMW `Data Files` directory
3. Open the OpenMW Launcher
4. Go to the Data Files tab
5. Enable `InteractableHighlight.omwscripts`
6. Launch the game

### Directory Structure
```
Data Files/
└── InteractableHighlight/
    ├── InteractableHighlight.omwscripts
    └── scripts/
        └── InteractableHighlight/
            ├── init.lua
            ├── player.lua
            ├── settings.lua
            └── util/
                ├── logger.lua
                ├── projection.lua
                └── storage.lua
```

## Usage

### Default Profiles

The mod comes with two pre-configured profiles:

1. **All Items (Default)** - `Shift + X`
   - Highlights all items and containers within 1500 units
   - Hold mode (labels disappear when key is released)

2. **NPCs & Creatures** - `Shift + P`
   - Highlights NPCs and creatures within 300 units
   - Toggle mode (press once to show, press again to hide)

### Configuring Profiles

1. Open the game menu (Esc)
2. Go to Settings → Mods → Interactable Highlight
3. Select a profile to edit or click "Add" to create a new one
4. Configure:
   - **Name**: Display name for the profile
   - **Hotkey**: Click "Change" and press your desired key combination
   - **Mode**: Toggle between hold-to-show and toggle mode
   - **Radius**: Detection range in game units
   - **Filters**: Select which object types to highlight

### Tips

- Use smaller radius values in crowded areas to avoid label clutter
- Create specialized profiles for different situations (e.g., "Alchemy Ingredients" for ingredient hunting)
- Combine with OpenMW's view distance settings for best performance
- Labels automatically hide when objects are behind the camera or off-screen

## Performance

This mod is designed with performance in mind:

- No background processing when highlights are inactive
- Efficient spatial queries using OpenMW's built-in nearby object lists
- Smart culling of off-screen labels
- Optimized update intervals for smooth label tracking

### Performance Tips

- Keep radius values reasonable (under 2000 for dense areas)
- Disable unnecessary object type filters
- Use hold mode instead of toggle mode when doing quick scans
- Consider your view distance settings when setting large radius values

## Troubleshooting

### Labels not appearing
- Ensure the mod is properly enabled in the launcher
- Check that your hotkey isn't conflicting with other mods or game controls
- Verify objects are within the configured radius
- Make sure the appropriate filters are enabled

### Performance issues
- Reduce the radius value
- Limit the number of active filters
- Check if other script-heavy mods are running
- Ensure object paging settings are reasonable

### Hotkey conflicts
- The mod will detect if a hotkey is already used by another profile
- Choose modifier combinations (Shift/Ctrl/Alt) to avoid conflicts
- Common game keys to avoid: E (activate), R (ready), Space (jump)

## Compatibility

This mod is fully compatible with:
- All content expansions (Tamriel Rebuilt, SHOTN, etc.)
- Other UI mods
- Graphics replacers
- Most gameplay mods

No known incompatibilities.

## Credits

- Developed for OpenMW 0.49+
- Inspired by similar functionality in other games
- Thanks to the OpenMW team for the excellent Lua API

## License

This mod is released under the MIT License. See LICENSE file for details.

## Changelog

See CHANGELOG.md for version history.

## Support

For bug reports and feature requests, please use the mod's issue tracker or contact the author on the OpenMW forums.