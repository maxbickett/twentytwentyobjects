# Twenty Twenty Objects for OpenMW (0.49+)

I developed this mod to let you see the names of objects wihtout having to hover your target over everything. It also has some pretty nift features to let you configure specifc hot keys to pop up specific item types at specific distances, so you're not always cluttered.  Along the way I built some cool features that let you set multiple hotkeys and customize what kinds of objects show up and at what distance.

This is a dynamic object highlighting mod for OpenMW 0.49+ that displays floating text labels above interactable objects when triggered by customizable hotkeys. Perfect for finding loot in dark dungeons, tracking NPCs in crowded cities, or spotting that elusive book on a cluttered shelf.

I picked up Morrowind this weekend after a youtube video hit me in the nostalgia.  It was the first videogame world I fell in love with.  Back in 2008 I loved it so much that I got involved in creating a mod - the first thing I ever did in software (shoutout to the Less Generic NPC Project).  It has been 15 years since I played it, though, and one of the first things I noticed was how annoying it was to point my cursor at everything on every shelf.  So, I looked for a mod to fix it, and was surprised not to find one. Please, don't tell me if I should have looked harder. 

Instead of playing the game, I spent the entire time coding.  I have work tomorrow, and I didn't even get to Balmora.  I hope that this makes someone else's game experience nicer. Create github issues if you see opportunities for improvement!  I know the settings UI is a bit nonstandard, I had to do some custom stuff and this is for all practical purposes my first mod.  

## Features

- **Customizable Hotkey Profiles**: Create multiple profiles with different key combinations and filters
- **Smart Occlusion**: Labels won't show through walls or closed doors
- **Object Type Filtering**: Highlight specific object types:
  - NPCs and Creatures
  - Items (weapons, armor, clothing, books, ingredients, misc)
  - Containers
  - Doors
  - Activators
- **Native Morrowind Styling**: 
  - Exact match to vanilla tooltip appearance
  - Dark blue-gray background with yellowish-white text
  - Proper Morrowind font and padding
  - Seamless visual integration
- **Intelligent Label Placement**:
  - Smart jittering prevents overlaps while maintaining clarity
  - Thin connecting lines show exactly which label belongs to which object
  - Priority-based positioning (NPCs get best spots)
  - No confusing grouping - every object gets its own label
- **Two Display Modes**:
  - **Hold Mode**: Labels appear while holding the hotkey
  - **Toggle Mode**: Press once to show, press again to hide
- **User-Friendly Configuration**:
  - Quick-start presets for common use cases
  - Visual settings preview
  - Tabbed interface with helpful tooltips
- **Performance Optimized**: 
  - Hierarchical spatial hashing for fast queries
  - Frustum culling and level-of-detail system
  - Configurable quality settings
  - No idle processing
- **Full Compatibility**: Works with all content mods including Tamriel Rebuilt

## Requirements

- OpenMW 0.49.0 or newer (requires Lua scripting support)

## Installation

### Manual Installation

1. Download the latest release
2. Extract the `TwentyTwentyObjects` folder
3. Add the scripts location to your OpenMW config
4. Open the OpenMW Launcher
6. Enable `TwentyTwentyObjects.omwscripts`
7. Launch the game

### Directory Structure
```
TwentyTwentyObjects/
├── TwentyTwentyObjects.omwscripts
└── scripts/
    └── TwentyTwentyObjects/
        ├── init.lua
        ├── player_native.lua
        ├── settings_improved.lua
        ├── hotkeyListener.lua
        └── util/
            ├── labelLayout_jitter.lua
            ├── labelRenderer_native.lua
            ├── logger.lua
            ├── occlusion.lua
            ├── projection.lua
            ├── spatial.lua
            └── storage.lua
```

## Quick Start

New to the mod? Follow these steps:

1. Open Settings → Mods → Twenty Twenty Objects
2. Click the "Quick Start" tab
3. Choose a preset that matches your playstyle:
   - **🗡️ Loot Hunter**: Find valuable items and containers (Press E)
   - **👥 NPC Tracker**: Locate NPCs in towns or dungeons (Press Q)
   - **💎 Thief's Eye**: Spot valuable items in shops (Shift+Z)
   - **🏛️ Dungeon Delver**: See everything in dark dungeons (Press X)
4. Click "Use This Preset" to activate
5. Return to game and press the hotkey!

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
2. Go to Settings → Mods → Twenty Twenty Objects
3. Select a profile to edit or click "Add" to create a new one
4. Configure:
   - **Name**: Display name for the profile
   - **Hotkey**: Click "Change" and press your desired key combination
   - **Mode**: Toggle between hold-to-show and toggle mode
   - **Radius**: Detection range in game units
   - **Filters**: Select which object types to highlight

### Understanding the Display

When you activate highlighting:
- **Labels appear in Morrowind's native tooltip style** - dark background with yellowish text
- **Thin lines connect labels to objects** when labels need to move to avoid overlap
- **Important objects (NPCs) get priority** for the best label positions
- **Every object gets its own label** - no confusing "5 items" groups

The system intelligently spreads labels out so they don't overlap, while maintaining clear visual connections to their objects.

### Performance Settings

The **Performance** tab offers:
- Max labels limit (5-100)
- Occlusion quality (hide labels behind walls) - enabled by default
- Update rate control
- Smart grouping toggle

### Tips

- **Can't see what a label points to?** Follow the thin connecting line to the object
- **Too many labels?** Reduce your detection radius or filter object types
- **Performance issues?** Use the "Potato" preset or disable occlusion checking
- **Finding specific items?** Create custom profiles for different scenarios
- **Dense loot pile?** Labels automatically spread out with lines showing what's what
- Labels automatically hide when objects are behind walls (with occlusion enabled)

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
