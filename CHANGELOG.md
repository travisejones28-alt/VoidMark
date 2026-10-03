## 1.0.3
- Expanded Enemy Moves shared potion cooldown detection across PvP/control, protection, healing/mana event types, movement, defensive, and rage potion effects.
- Added direct recognition for FAP, LAP, LIP, Swiftness, Greater Stoneshield, and protection-potion aura effects.

## 1.0.2
- Added native Enemy Moves PvP cooldown tracker with VoidMark-styled target cooldown bars.
- Added current-target Paladin Divine Shield/Divine Protection/Blessing of Protection fallback tracking.
- Added shared 2-minute Potion cooldown tracking when enemy potion use is observable in the combat log.
- Added Enemy Moves to the VoidMark gear menu and /emoves test/debug controls.

# Changelog

All notable VoidMark release changes are recorded here.

## v1.0.1

### Fixed
- Updated offline AutoSync account-folder detection for GitHub/OneDrive working copies junctioned into the WoW AddOns folder
- AutoSync now locates the actual Classic Era installation independently instead of assuming VoidMark physically resides under Interface\\AddOns

## v1.0.0

Initial public GitHub release.

### Included
- Enemy-player tracking and VoidMark UI
- Kill and encounter history
- GankTracker integration
- Kill effects and streak tracking
- Corpse run / return-time integration
- Integrated utility modules
- Optional multi-account offline kill-history AutoSync

### Packaging
- Standardized addon folder and TOC name as `VoidMark`
- Established `v1.0.0` versioning
- Added public README and changelog
- Excluded generated AutoSync log/PID files from source control
