# Advanced City Builder (v0, proof of concept)

Adds an **Advanced City Builder** tool to **Town > Tools**, next to the game's Town Builder and
Experimental Town Builder. It places a town with:

- **District sizes:** a slider each for the residential, commercial and industrial districts, from 50 up
  to the maximum in steps of 50.
- **Initial Road Angle Range:** 0 to 20 degrees in steps of 2.5. 0 gives a strict grid; larger values
  give more varied street directions when the town is created.
- **Capacity Scaling Factor:** 0.25 to 2.0.
- **One cargo need per district:** None, Random (the game picks one) or a specific cargo.

## Mod settings (chosen when you enable the mod for a game)
- **Maximum town capacity:** 100 %, 125 %, 150 % or 200 % of the normal maximum of 1600 (the largest size
  of the game's Experimental Town Builder), i.e. 1600, 2000, 2400 or 3200. Larger towns are slower to
  build and simulate.
- **Organic street growth:** 0 to 20 degrees in steps of 2.5 (default 0). How much the direction of new
  main streets may vary when towns grow. Without it, every town grows as a straight grid beyond its
  initial core. **This applies to all towns in the game**, not only to towns placed with this tool.
- **Organic streets in new towns:** 0 to 20 degrees in steps of 2.5 (default 0). The same for the first
  street layout of new towns created without this tool, such as with the game's Town Builder. It also sets
  the default of this tool's Initial Road Angle Range.
- At 0, the mod leaves the game's own value unchanged, which is a straight grid unless another mod
  changes it. These settings are stored in the savegame and can be changed when you load it.
- **Diagnostic logging:** Off (default) or On. On writes `[ACB]` lines to the game log for troubleshooting.

This is an early proof of concept. Like the game's town builders, it is available where the Town menu's
tools are, i.e. the map editor and sandbox mode.
