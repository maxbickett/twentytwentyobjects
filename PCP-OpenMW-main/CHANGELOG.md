### Changelog
## 1.0.0
- Initial version

## 1.0.1
- Added a new setting: "Retroactive Starting Health"
- Added four optional .omwaddons for different level-up requirement settings
- Added a level progress indicator to the potential menu
- Fixed a bug when adding PCP to a save with >= 20 level-up progress
- Fixed OpenMW version warning not working
- Fixed health calculations not using the `fLevelUpHealthEndMult` GMST

## 1.0.2
- Added a new setting: "Custom Health Calculation"
- Added a new setting: "Cap Attributes Individually"
- Added more optional .omwaddons for level-up requirements
- Fixed class skills/attributes not initializing correctly for the first play session
- Fixed issues with health gain logic
- Fixed potential displaying incorrectly in rare cases
- Fixed high resolution textures displaying poorly in the menu
- Added correct dependencies to some optional .omwaddons
- Bumped settings version

## 1.1.0
- Added a new setting: "Custom Skill-Attribute Assignment"
- Added a new setting: "Realistic Retroactive Health Gain"
- Added new settings: "Level Progress Per Misc./Minor/Major Skill Increase"
- Added a function to clear progression data from a save file
- Added more specific notifications for settings being changed by updates
- Exposed some hardcoded UI dimensions to localizations
- Fixed several issues with settings UI
- Rewrote descriptions for some settings