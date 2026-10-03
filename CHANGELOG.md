## 1.0.5
- Enemy Moves now always displays time until the ability can be used again; ACTIVE is only a separate state marker.
- Added conservative PvP cooldown values for talented Rogue, Warrior Intercept, Paladin Hammer of Justice, and Blessing of Protection cases.
- Preparation now resets the tracked Rogue abilities it can refresh, including Kick, Kidney Shot, Gouge, Blind, Vanish, Sprint, and Evasion.
- Added missing Rogue Kick ranks and Evasion rank 2.
- Fixed aura-only repeat uses so an expired cooldown can restart even when SPELL_CAST_SUCCESS is not observed.
- Fixed Enemy Moves OPT button and persistent hide/show behavior.

## 1.0.4
- Fixed Enemy Moves shared Potion timer for mana/healing potion combat-log events (SPELL_ENERGIZE / SPELL_HEAL).
- Confirmed Major Mana Potion surfaces as Restore Mana (spell 17531), so recognized potion events now start the 2:00 lockout regardless of event type.

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
