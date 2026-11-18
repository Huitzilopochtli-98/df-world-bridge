# World Bridge

World Bridge is a DFHack mod for fortress-funded crossings between islands.
This is version **0.5.0-dev**, an unfinished development build. Use a copied
save: it creates world-construction records and consumes real blocks.

Supported Windows Steam builds are **Dwarf Fortress 53.17 with DFHack 53.17-r1**
and **Dwarf Fortress 53.16 with DFHack 53.16-r3**. The mod checks the exact
game and DFHack build before enabling its native adapters.

## Install from this repository

1. Close Dwarf Fortress and make a separate copy of the save you want to test.
2. Click **Code > Download ZIP** on GitHub and extract it. Open the folder
   containing `Install-WorldBridge.ps1`.
3. Open PowerShell in that folder and run:

   ```powershell
   .\Install-WorldBridge.ps1
   ```

   The installer finds your Steam game and DFHack automatically, including
   installations in different folders or Steam libraries. It shows both paths,
   verifies copied files, and backs up World Bridge files before replacing them.
   Add `-WhatIf` to preview the installation without changing files.
4. Start the game through DFHack and load your copied fortress.
5. Open the DFHack command launcher and run **`world-bridge`**.

For a portable installation or a specific copy, run
`./Install-WorldBridge.ps1 -GamePath 'C:\path\to\Dwarf Fortress'` instead.
If more than one Steam copy is found, use this option to choose one. An advanced
`-HackPath` option can select the DFHack folder containing `dfhack-run.exe`.

You can also install manually: copy `lua/world-bridge` into DFHack's `hack/lua`
folder, then copy the contents of `dfhack-config/scripts` into that folder in
the game installation. The DFHack and game folders can be separate.

## Plan and fund a bridge

The planner opens over Dwarf Fortress's graphical world map. Click directly
on the map to choose shores. **A** and **B** mark your selected shores;
yellow **+** marks the preview, and **=** marks project water tiles. Completed
projects are green. The panel on the right shows costs, progress, and controls.

Use **W/A/S/D**, arrow keys over the map, or a **middle-mouse drag** to pan.
Press **Ctrl+C** to center on your fortress. **Esc** closes the planner and
leaves the native world map open. If the game shows its world-map help first,
read it and click **Okay**; the planner will open afterward.

1. Click a land tile on one shore, then land on the other shore.
2. Review the route, required blocks, and construction time.
3. Click **Create previewed project** or press **Ctrl+N**, then confirm.
4. Select the project in the list and click **Deliver blocks** (**Ctrl+D**).
5. Enter the number of blocks to consume. The mod uses eligible individual
   blocks lying on the ground; reserved, forbidden, contained, and job-bound
   blocks are excluded.
6. Once fully funded, construction time starts. Continue playing. The
   scheduler completes the project when enough game time has passed.

New projects cost **100 blocks and 14 game days per water world tile**.
For example, three water tiles require **300 blocks and 42 game days**.
Shore tiles do not add to the cost. Projects saved by an earlier version keep
their recorded cost, duration, and progress.
If delivery fails, the mod restores the removed blocks and the previous
project accounting. A failed restoration pauses the game and reports the issue.
Projects are stored in the world and belong to their originating fortress.
Only that fortress can fund and advance them. The planner currently supports
cardinal routes through ocean or lake, with a limit of 64 water tiles.

## Cancel a project or remove a bridge

Select a project owned by your fortress and press **Ctrl+X** in the planner.
Review the confirmation before proceeding. Delivered blocks are spent and will
not be returned. Canceling an unfinished project frees its route for reuse.

For a completed bridge, turn off raid routing (**Ctrl+T**) and caravan access
(**Ctrl+E**) first if enabled. Wait for guided squads and caravans to finish.
Removal checks the world records and every recorded deck tile. It restores
the original terrain tiles on the loaded map and lets existing water refill
the space. It refuses occupied or altered decks, nearby obstructions or
changed water boundaries, and deck sections on an unloaded fortress map.

At the DFHack prompt, run `world-bridge cancel <id>` for an unfinished project
or `world-bridge remove <id>` for a completed bridge. Review the preview and
append `--confirm` to proceed. Pause the game before removing a completed bridge.

## Experimental raid travel

**Ctrl+T** toggles automatic raid routing for the current fortress. Completed,
verified projects can extend the native world-map raid choices. Assign squads
through the game's normal world map. The runtime waits for all assigned
members to assemble into one army, guides it over the bridge route, and
handles its return trip. Tested examples include two squads, both directions,
and saving and restarting the game during a guided trip.

The guard blocks other mission types at destinations made accessible only
by a bridge. If another DFHack screen covers the guard, it removes temporary
accessibility; reselect the site after returning. If a partial army leaves
before assembly, or guidance cannot be verified, the game pauses.

Use `world-bridge guidance-status` to inspect pending missions. After fixing a
reported issue, `world-bridge retry-guidance <controller-id>` requests another
check; it does not unpause the game. An empty native mission can remain
pending until you assign squads or remove it in the game's mission UI.

## Experimental caravan access

Press **Ctrl+E** in the planner, or run `world-bridge trade-access on`, to let
completed bridges extend trade access for this fortress. Leave it on while
playing. Use `world-bridge trade-status` to inspect the added connections.

The mod looks for peaceful trading civilizations with a currently owned market
that becomes reachable through a verified bridge. Dwarf Fortress still decides
when a caravan visits and whether the fortress meets its trading requirements.
Build a trade depot and trade through the game's normal interface. Enabling
this option does not immediately summon merchants.

Press **Ctrl+E** again, or run `world-bridge trade-access off`, to withdraw the
access flags added by the mod. Native access flags are preserved. Caravans
already scheduled or visiting continue normally. The setting is saved for
the current fortress and starts off in a new fortress.

Two copies of the same traded fortress were tested through normal calendar
progression. With this option off, the existing human trading partner visited.
With it on, that partner and three newly connected human civilizations all
reached the depot. Separate tests verified saving and restarting, and a normal
trade with a newly connected merchant. Caravan world routes are not exposed
like squad missions, so their travel over individual bridge tiles was not
observed.

## Current limits

This development build is not a finished world-travel implementation.
Other mission types, split armies, and all land-pathing cases are not verified.
The current navigation rules approximate native land passability. Trade access
uses the game's shared proximity flag, so keep this feature experimental;
other mods that change the same flag can conflict with it.

Completed bridges can now place a local elevated deck where their route
intersects a loaded fortress map. This is enabled by default for the world;
**Ctrl+L** or `world-bridge local-decks off` disables automatic placement.
Select a completed project and use **Build local deck** (**Ctrl+B**) to place
or verify it explicitly. The project has already paid the world-scale cost.

The placement planner searches beside existing construction for natural pier
bases, preserves ocean source flags, and adds a dry shore approach when it
finds reachable ground. It refuses occupied tiles, aquifers, unrevealed
terrain, unsafe liquids, and blocked headroom. Placement replaces some
natural floor bases and displaces water inside solid pillars. Existing
construction records are not replaced. A failed transaction rolls back its
new records and tile changes. A recorded placement that has been altered is
reported rather than repaired automatically.

The default deck clears the highest water surface in its route: absolute
elevation 101 for ocean crossings, or the lake's reported surface plus one.
The first local placement fixes that height across later maps. Advanced
testing can use `world-bridge preview-local <project-id> <local-z>` and
`world-bridge build-local <project-id> <local-z>`. Different terrain, lakes,
large routes, corners, all shore approaches, and long-term water behavior
still need broader verification. The copied-game tests are not a guarantee
for every world.

In one ocean test, all 758 recorded deck, support, and stair cells still
verified after a full game year, including winter. Both ends remained
reachable from the shore. That is evidence for this section, not every climate
or crossing. A separate elevated-lake test placed a complete three-wide bend
at absolute elevation 107; native pathfinding connected its two ends. Other
terrain and shore conditions still need testing. A dwarf also walked around
the lake bend using ordinary local movement, after fixture placement at one end.

The planner uses the normal 1× world map and displays its route markers there.
Close World Map Zoom or other DFHack windows before opening the planner.
The standalone `gui/world-bridge-markers` experiment is still available for
viewing completed bridge indicators outside the planner.

Do not remove or disable the mod during a guided trip. Guidance changes
native mission targets temporarily; keep the mod installed until the trip
finishes. Native world-construction records remain in the save after unsubscribing.
Use the planner to remove a bridge you no longer want.

## Commands and source

Run `world-bridge help` for the development commands. The normal entry point
is the project planner: **`world-bridge`**.

The Lua implementation is in `lua/world-bridge`. `tests` contains the Lua
regression tests and PowerShell installer checks. With Lua 5.3 installed, run `./Run-Tests.ps1`; use
`-Lua 'C:\path\to\lua.exe'` if it is not on your command path. The package
does not contain game files or saves. Run `./tests/test_installer.ps1` to check
installation discovery, file placement, backups, and preview mode using
temporary fixtures.

MIT licensed. You may use, change, and redistribute the source; see `LICENSE`.
