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

## Multi-account kill-history sync

VoidMark includes optional Windows AutoSync utilities for players using multiple WoW accounts on the same computer. Single-account users do not need to install AutoSync.

To enable it, close WoW and run `INSTALL_AUTO_SYNC.bat`. The sync utility waits until all WoW clients are closed before merging supported VoidMark kill-history data between detected Classic Era account SavedVariables.

## Versioning

VoidMark uses semantic-style releases:

- `v1.0.0` — major release
- `v1.0.1` — fixes
- `v1.1.0` — new features

See `CHANGELOG.md` for release notes.
