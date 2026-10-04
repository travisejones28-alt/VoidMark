# VoidMark

VoidMark is a World of Warcraft Classic Era PvP tracking addon focused on enemy-player awareness, encounter history, kill tracking, and WPvP utilities.

## Installation

1. Download the latest VoidMark release ZIP.
2. Extract the ZIP.
3. Copy the `VoidMark` folder into:
   `World of Warcraft/_classic_era_/Interface/AddOns/`
4. Restart World of Warcraft or reload the UI.

The final addon path should look like:

`Interface/AddOns/VoidMark/VoidMark.toc`

## Updating

Download the newest release and replace the existing `VoidMark` addon folder. Your normal WoW SavedVariables are stored separately and are not part of the addon folder.

## Runback timers

VoidMark 1.3.9 shows a compact yellow countdown, then red elapsed time, on a killed enemy's normal row. The row stays pinned until 60 seconds after the modeled earliest corpse-run return. Unknown location or missing local graveyard coverage produces an immediate warning. These are optimistic estimates, not proof that resurrection cannot happen sooner.

Use `/trb details [name]` to inspect an active timer, or `/trb route [name]` to explicitly calculate an advisory waypoint route. With no name, diagnostics use the selected enemy's active timer or the most recent timer. Use the full realm name when names collide. Routes never postpone the countdown; ordinary kills do not start searches. `/trb routes on|off` controls route work for requested details and own-player calibration, with a default of off for new settings.

`/trb test [normal|nightelf]` creates a test row. `/trb analyze [alliance|horde]` explains local graveyard geometry. `/trb calibrate` measures your own corpse run; release immediately, run directly, and use `/trb calibrate report|cancel|clear` to manage it. Only client-confirmed corpse-range samples with a matching observed release graveyard affect advisory estimates. Enemy sightings never train timing.

Data provenance and limitations: [RunBack/SOURCE-NOTES.md](RunBack/SOURCE-NOTES.md).

For developer validation, run:

```sh
luatex --luaonly tests/regression.lua
luatex --luaonly tests/runback_regression.lua
luatex --luaonly tests/runback_routes.lua
```

## Multi-account kill-history sync

VoidMark includes optional Windows AutoSync utilities for players using multiple WoW accounts on the same computer. Single-account users do not need to install AutoSync.

To enable it, close WoW and run `INSTALL_AUTO_SYNC.bat`. The sync utility waits until all WoW clients are closed before merging supported VoidMark kill-history data between detected Classic Era account SavedVariables.

## Versioning

VoidMark uses semantic-style releases:

- `v1.0.0` — major release
- `v1.0.1` — fixes
- `v1.1.0` — new features

See `CHANGELOG.md` for release notes.
