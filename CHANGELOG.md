# Development changes

## 0.4.2-dev

- Adds support for Steam Dwarf Fortress 53.17 with DFHack 53.17-r1 on Windows.
- Keeps support for Steam Dwarf Fortress 53.16 with DFHack 53.16-r3 on Windows.

## 0.4.1-dev

- Full Steam Workshop delivery, with Lua modules loaded from the subscribed
  mod folder. No manual mod-file installation or new world is required.
- Installer automatically finds the Steam game from its app manifest and
  library folders, including renamed install directories.
- Follows the game's DFHack hook file when DFHack is installed separately.
- Keeps manual GamePath and HackPath options for specific or portable copies.
- Reports both selected paths and preserves WhatIf previews and file backups.
- Verified discovery and installation with 55 checks in PowerShell 5.1 and 7.

## 0.4.0-dev

- New projects require 100 blocks and 14 game days per water world tile.
- Existing saved projects retain their original accounting and progress.
- Replaces the ASCII terrain planner with the native graphical world map.
- Click shores directly on the map; preview routes and existing projects are
  marked over the terrain. Project and funding controls sit beside the map.
- Adds native-map panning with W/A/S/D, arrows over the map, and middle drag.
- Keeps planner clicks from triggering native selections or mission orders.
- Refreshes preview text after each selection and keeps the camera in bounds.

## 0.3.0-dev

- Optional caravan access through verified completed bridges, with Ctrl+E and
  `trade-access on|off`. Uses current territory ownership and reachable markets.
- Keeps native diplomacy, trading seasons, progress checks and arrival events.
- Persists ownership of added proximity flags, restores them on disable or
  route loss, and preserves native access flags when changing fortresses.
- Native rollback, ordinary depot trade, GUI toggle and full restart checks.
- Matched natural-calendar controls: the existing human partner reached the
  depot in both arms; three bridge-connected human partners also reached it
  with trade access enabled. No forced arrivals or calendar jumps in these runs.
- Fills the outside corner of a bent deck for complete three-wide clearance.
- Chooses a new deck's elevation from its route's ocean or lake water levels.
- Verified a 512-cell elevated-lake bend, native end-to-end pathfinding, and
  an actual dwarf's walk around the bend.
- Verified the earlier ocean section through a full game year.

## 0.2.1-dev

- Roll back the full block delivery when item removal or ledger saving fails.
- Restore original ground positions, item flags, and project accounting.
- Exclude blocks with native reservations or world-data references.
- Verified normal delivery and two injected failure cases in the copied game.
- Verified the 758-cell ocean section and shore paths after winter into spring.

## 0.2.0-dev

- Transactional local deck placement with a persistent placement ledger.
- Lateral pier search that preserves existing construction records.
- Dry shore approach planning, including constructed stairs.
- Placement verification and refusal to repaint changed tiles.
- Automatic local synchronization on map load and project completion.
- Local deck controls in the planner and command interface.
- Rollback checks, including an injected save failure in the copied game.

## 0.1.0-dev

- In-game shore selection, route/cost preview, project list, and block delivery.
- Persistent project accounting and timed native world-construction records.
- Experimental guarded raid accessibility and automatic outbound/return routing.
- Recovery of guided raids after saving and restarting the game.
- Pending mission status and retry commands, with assembly/departure checks.
- Read-only local deck preflight and experimental native-map markers.
- Windows installer with file verification and replacement backups.

This build is incomplete. See the README's current limits.
