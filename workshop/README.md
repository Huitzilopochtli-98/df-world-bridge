# World Bridge — Workshop edition

World Bridge adds fortress-funded crossings between islands and continents.
This Workshop download contains the working Lua mod. It does not need the
PowerShell installer.

## Start here

1. Install DFHack for your game. This development build supports **Windows,
   Steam Dwarf Fortress 53.16, and DFHack 53.16-r3**.
2. Subscribe to World Bridge and let Steam finish downloading it.
3. Restart the game through DFHack, then load a **copied fortress save**.
4. Press **Ctrl+Shift+D**, type **`world-bridge`**, and press Enter.
5. Close the game's world-map help if it appears. Click land on each shore.
6. Review the route, create the project, and deliver blocks from the right panel.

You can use an existing world. You do not need to enable this as a world-generation
mod. Do not install both the manual ZIP and Workshop copies; older manual files
can take priority over Workshop commands.

## Cost and controls

Each water world tile costs **100 blocks and 14 game days**. Both shore tiles
are free. Three water tiles cost 300 blocks and 42 days. Construction time starts
after the project is fully funded. Old saved projects retain their original costs.

- Click shores on the native graphical world map. A/B mark the shores; yellow
  + marks the preview; = marks a project.
- W/A/S/D, arrows over the map, or middle drag: pan. Ctrl+C: center on the fort.
- Ctrl+N: create. Ctrl+D: deliver. Ctrl+B: build or verify a local deck.
- Ctrl+T: experimental raid routing. Ctrl+E: optional caravan access.
- Ctrl+L: automatic local decks. Esc closes the planner.

## Development limits

Use a copied save. Projects consume real blocks and create world-construction
records that remain after removing the mod. A local deck can replace natural
floor bases and displace water inside its solid pillars. Conflicts pause the
game instead of repainting altered construction.

Other mission types and split armies are guarded or unsupported. Land routing
approximates native passability. Caravans can be enabled for newly connected
peaceful trading civilizations, but their individual world-tile routes are not
observed. Do not unsubscribe during a guided squad trip; let it finish first.

The planner uses the normal 1x world map. Close World Map Zoom or other DFHack
windows before opening it. Other DF/DFHack builds need verification first;
the mod checks the exact supported build before enabling its native adapters.

The source is included as readable Lua in `lua/world-bridge` and
`scripts_modinstalled`. MIT licensed; changes, extensions and redistribution
are welcome. See LICENSE. This is an independent mod.
