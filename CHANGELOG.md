# Changelog

All notable changes to the Interactable Highlight mod will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of Interactable Highlight mod
- Customizable hotkey profiles with modifier support
- Object type filtering system
  - NPCs and Creatures
  - Items (weapons, armor, clothing, books, ingredients, misc)
  - Containers
  - Doors
  - Activators
- Floating text labels with Morrowind-style appearance
- Hold-to-show and toggle display modes
- Configurable detection radius (50-5000 units)
- In-game settings menu integrated with OpenMW
- Persistent profile storage
- Debug logging system
- Performance-optimized scanning and rendering

### Technical
- Event-driven architecture with no idle polling
- Efficient spatial queries using OpenMW's nearby API
- Smart label culling for off-screen objects
- Proper memory management with label cleanup
- Compatible with OpenMW 0.49+

## [1.0.0] - TBD
- First stable release