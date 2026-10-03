## 1.3.3
- Removed the visible Enemy Moves version text from the banner.
- Sap Alert no longer plays an audio warning.
- Sap Alert now broadcasts SAPPED to RAID when in a raid, PARTY when in a party, and stays silent in chat when solo.
- Personal on-screen Sap warning remains enabled when Sap Alert is ON.

## 1.3.2
- Added a personal Sap safety alert that fires only when Sap lands on the player.
- Alert is on-screen only with a raid-warning sound; no chat message is sent.
- Added Sap Alert: ON / OFF to the main VoidMark gear menu.
- Sap Alert defaults to ON until explicitly disabled.

## 1.3.1
- Panic is now fixed to the Banner/bar style.
- Removed Panic style selection controls from Gank Tracker options.
- Panic enable/disable remains on the main VoidMark gear menu.
- Preserved the 60-second grace period and Nearby-list auto-show/hide behavior.

## 1.3.0
- Removed the SHOW PANIC checkbox from Gank Tracker options.
- Added Panic: ON / OFF to the main VoidMark gear menu.
- Panic enable/disable behavior and the 60-second grace/Nearby visibility logic are unchanged.

## 1.2.9
- Panic button now stays visible for 60 seconds after being enabled.
- After that grace period, Panic is only shown while the VoidMark/Spy Nearby list contains at least one player.
- Panic automatically reappears when Nearby becomes non-empty and hides again when Nearby becomes empty.
- Disabling Panic still hides it immediately.

## 1.2.8
- Cleaned up Enemy Moves target/status row spacing.
- Shortened the idle status to NO COOLDOWNS.
- Disabled status text wrapping and tightened the target-name column.

## 1.2.7
- Enemy Moves target display now shows only the short player name (realm removed).
- Removed class text from the target label.
- Added the class icon to the left of the target name.
- Target name now uses the player's class color.

## 1.2.6
- Gear menu now shows Enemy Moves: ON / OFF.
- Clicking the item persistently enables or disables Enemy Moves instead of merely showing or hiding the current panel.
- Re-enabling immediately resumes current-target tracking.

## 1.2.5
- Enemy Moves now hides immediately when the hostile target is lost.
- Exception: if the current target is a Rogue and VoidMark observes Vanish while that Rogue remains in the Nearby list, the panel stays on that Rogue for up to 30 seconds.
- Hover preview behavior is unchanged: it only overrides the current target for players with live tracked cooldowns.

## 1.2.4
- Shifted the Enemy Moves banner crop to frame the VOIDMARK wordmark itself instead of the hood artwork on the left.
- Header now uses the wordmark as the visual center of the compact panel.

## 1.2.3
- Enemy Moves now follows the current hostile player target by default.
- Hovering a player in the VoidMark list temporarily overrides the panel only when that player has at least one live tracked cooldown.
- Hovering a player with no tracked cooldowns leaves the panel on the current target.
- Removed stale pinned/last-enemy fallback behavior.

## 1.2.2
- Switched Enemy Moves back to the original high-resolution VoidMarkGeneratedHeader.tga for a sharper header.
- Cropped the original banner to the compact VOIDMARK + FIND • TRACK • GANK section.
- Reduced the header height to fit the compact crop without blurring.

## 1.2.1
- Added a dedicated EnemyMovesHeader.tga converted directly from the user-provided VOIDMARK / FIND • TRACK • GANK reference image.
- Enemy Moves now uses that texture directly instead of cropping VoidMarkGeneratedHeader.tga.
- Removed old banner crop coordinates and reduced the frame/header around the dedicated asset.

## 1.2.0
- Reworked Enemy Moves to match the user-provided compact VoidMark logo crop.
- Banner now uses a centered horizontal crop while preserving the full vertical artwork and correct logo/tagline proportions.
- Target/class moved into the existing status strip so the header remains clean with no extra spacer bar.
- Status text is right-aligned alongside the target/class label.
- Fixed target/status anchor creation order before release.

## 1.1.9
- Cropped the existing VoidMark banner to the compact logo-heavy section used for Enemy Moves.
- Reduced Enemy Moves width from 336 to 286 and shortened the banner/header.
- Repositioned target text, version, and OPT controls for the smaller frame.
- Cooldown tracking behavior is unchanged.

## 1.1.8
- Restored the full Enemy Moves VoidMark banner artwork top-to-bottom.
- Removed the vertical crop that was hiding the lower half of the image.
- Banner now trims only slightly from the left/right edges and has more vertical room to avoid squashing.

## 1.1.6
- Removed the separate target-name spacer row beneath the Enemy Moves banner.
- Target/class now sits directly on the lower-left of the VoidMark banner.
- Status strip now starts immediately below the banner for a tighter layout.

## 1.1.5
- Reworked Enemy Moves header into a compact branded layout.
- VoidMark art is now a short logo strip instead of dominating the panel.
- Target/class moved to a separate clean text line beneath the banner with no background bar.
- Version and OPT controls were repositioned for the shorter header.

## 1.1.4
- Fixed the Enemy Moves VoidMark banner looking vertically squashed.
- Banner now uses a centered vertical crop so the original artwork keeps its proportions inside the compact header.
- Slightly increased banner opacity for cleaner logo detail.

## 1.1.3
- Removed the dark Enemy Moves header bar.
- Target/class text now floats directly over the VoidMark banner.
- Header separator line is hidden for a cleaner integrated look.

## 1.1.2
- Simplified Enemy Moves banner header by removing the redundant ENEMY MOVES title.
- Reduced banner/header height and tightened spacing.
- Target/class is now the sole header label over the VoidMark banner.
- Lowered version/OPT slightly for cleaner alignment.
- Cooldown row visuals and tracking behavior are unchanged.

## 1.1.1
- Enemy Moves now uses VoidMark's own generated banner artwork across the header.
- Module title and target/class are overlaid on a dark translucent lower band for readability.
- Version and OPT controls remain in the upper-right over the banner.
- Cooldown tracking and pin/hover behavior are unchanged.

## 1.1.0
- Reworked Enemy Moves into a more polished VoidMark-style panel without changing tracking behavior.
- Added a darker black-violet shell, brighter purple accent line, stronger border treatment, improved title/header spacing, and hover styling on the OPT button.
- Rebuilt cooldown rows with flat cleaner bars, category accent strips, framed icons, subtle sheen, stronger timer contrast, and improved text spacing.
- Active rows now visually drain using the active-effect duration while the right-side number continues to show recast cooldown.

## 1.0.9
- Enemy Moves now hides and clears a pinned enemy as soon as that player drops out of VoidMark's Nearby tracker.
- Vanish/target loss still keeps the panel pinned while the enemy remains tracked by VoidMark.

## 1.0.8
- Enemy Moves active header now includes the live effect countdown, e.g. ACTIVE: Evasion (13s).
- Active row countdowns now include an explicit seconds suffix.
- Enemy Moves keeps the last hostile player pinned through target loss/Vanished state until another hostile player is targeted.
- Hovering a player in the VoidMark list temporarily previews that player's live tracked cooldowns, then restores the pinned/current target on mouse leave.

## 1.0.7
- Enemy Moves active rows now show the active-effect countdown inline, e.g. Evasion ACTIVE (8s), while preserving the recast cooldown on the right.

## 1.0.6
- Tightened Enemy Moves cooldown accuracy for talented Frost Nova, Earth Shock, and Lay on Hands.
- Grounding Totem now tracks only its recast timer instead of implying the totem is still active.
- Replaced the overly confident "ALL TRACKED MOVES READY" state with "NO OBSERVED COOLDOWNS" when VoidMark has not observed a current cooldown.

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
