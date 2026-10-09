# Changelog - Advanced City Builder

All notable changes to the Advanced City Builder mod and its tooling.
Format: [Keep a Changelog](https://keepachangelog.com/). Last Updated: 2026-10-05.

## [Unreleased]

### Added
- 2026-10-05: game-wide street angle mod settings (TODO P1 "organic streets beyond the initial core",
  idea 1). The new `content/mod.script.lua` `preRunFn` applies them to BaseConfig:
  - "Organic street growth" (`acb_growth_angle`) -> `townMajorStreetAngleRange` (all town growth).
  - "Organic streets in new towns" (`acb_initial_angle`) -> `townInitialMajorStreetAngleRange` (initial
    layout of towns made without this tool; also the default of the tool's angle slider).
  - Both are 0-20 degrees in 2.5-degree steps, default 0. At 0 the game's value is left unchanged.
  - Logged when Diagnostic logging is On.
  Offline Lua 5.2 checks (6 cases: defaults, 0 with other values preset, max, clamping, missing params)
  pass. Untested in game (TESTING A12-A14).
- `content/scripts/advanced_city_builder/road_angles.lua`: one shared definition of the angle options for
  the mod settings and the tool.

### Changed
- 2026-10-05: `_metadata/description.html` (in-game mod browser and mod.io text) generated from README.md;
  it is now regenerated after every README change.
- 2026-10-05: the tool's Initial Road Angle Range now offers 0-20 degrees in 2.5-degree steps (was 0-90
  in 3-degree steps), the same options as the mod settings (author decision). The panel key was renamed to
  `acb_initial_road_angle`, so remembered v0 values are not reinterpreted.

### Verified
- 2026-10-05: the author reports v0 working very well in the map editor, including sliders up to 3200
  (200 % setting) and per-district cargo needs. Known limitation documented: streets revert to a 90° grid
  outside the initial core (growth uses the global angle range). No code changed.

### Changed
- 2026-10-05: modinfo author "TangoEchoXray" (was "Advanced City Builder contributors"). An
  identifying-information scan of the mod folder (all text files plus the cover PNG's metadata chunks) is clean.

### Changed
- 2026-10-05: district capacities (R/C/I) are sliders from 50 to the maximum in steps of 50 (were 15
  fixed buttons 50-1600). The default stays 100.

### Added
- 2026-10-05: mod setting "Maximum town capacity" (`acb_max_capacity`: 100 %, 125 %, 150 %, 200 % of the
  normal maximum 1600, i.e. 1600/2000/2400/3200; default 100 %). Offline Lua 5.2 checks cover every
  setting. Capacities above 1600 are untested in game.
- 2026-10-05: mod setting "Diagnostic logging" (`mod.json` param `acb_logging`, Off/On, default Off). All
  `[ACB]` log lines now go through it. New log line `[ACB] town builder:...` with the values sent to the
  town builder, written once per change. Offline Lua 5.2 checks: Off = no lines, On = lines without
  duplicates, config unavailable = off without errors (that last case found and fixed a would-be Lua error).

### Verified
- 2026-10-05: the author reports v0 working in the map editor.

### Fixed
- 2026-10-05: in-game validation failed with `Texture error: Could not find texture ''`. Added the
  required cover image `_metadata/0.png` (1920x1080, no text; procedurally drawn: organic streets,
  districts tinted by direction). Re-validation pending.

## [v0] - 2026-10-05 - proof of concept (untested in game)

### Added
- Mod packaging: `mod.json` (modId `advanced_city_builder`, tentative), `_metadata/modinfo.json`
  (Script Mod, author TangoEchoXray), `strings.json`, public `README.md`.
- Town > Tools > "Advanced City Builder" (`content/gui/construction/tools/advanced_city_builder_tool.*`).
  Duplicates the Experimental Town Builder:
  - R/C/I sizes 50-1600
  - Initial Road Angle Range 0-90 degrees
  - Capacity Scaling Factor 0.25-2.0
  Plus **one cargo need per district: None / Random / any cargo** (default Random). It uses a custom
  action that drives the native TownBuilder directly.
- the internal notes (install and checks A0-A9). Offline check under Lua 5.2 with stubbed APIs passed.

## [setup] - 2026-10-05

### Added
- 2026-10-05: project set up (folder structure, the internal notes with the author's intent, TODO with research
  questions). Starting points documented in the internal notes. Nothing is
  designed or built yet.
- 2026-10-05: base game's Experimental Town Builder documented as the primary reference (files, native
  `TownBuilder` fields, availability, coverage vs. this mod's goals).
