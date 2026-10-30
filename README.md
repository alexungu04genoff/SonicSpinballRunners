# Sonic Spinball Runners

Sonic momentum, pinball physics and a configurable roguelite run, built with Godot 4 / GDScript for Windows. An invisible 2D ball owns collisions; collisionless 3D scenery, characters and effects follow it.

## Two workflows

- **Gameplay:** Act Geometry Editor → Play Act → Bake Prototype → Play Prototype.
- **Graphics and performance:** theme/graphics work → Bake Endless → Play Endless.

**Play Prototype.cmd** opens the main game: choose Sonic, Tails, Knuckles or Shadow, Challenge or Practice, 1–7 Zones, and the Act/theme pools. Each Zone has three distinct authored Acts. A seed reproduces the course. Reach each score target, touch its Goal Ring, choose an SRA Buddy and continue. Challenge has finite Balls; Practice has unlimited retries. Soft retries preserve Act objectives and earned score. Results automatically archive telemetry v2 and optional Run feel notes locally, with Copy run data and Open telemetry folder controls. See [Prototype](docs/PLAYABLE_PROTOTYPE.md).

**Act Geometry Editor.cmd** authors terrain, gameplay objects, decor, ring trails, Spawn, Goal and connectors with undo/redo. Save, load and Verify share the runtime geometry rules; Verify does not guarantee reachability. **Play Act.cmd** (or Godot F5) opens the themed standalone player, initially **First Try Smooth Decor**. Load Act selects another `.tres`; Reload Act / F5 reloads a saved edit while preserving camera and session settings. A rejected reload preserves the active world.

**Bake Prototype.cmd** prepares all five production Acts in all eight themes: 40 variants. Committed `.tres` files in `data/acts/Authored` are production content discovered by run setup:

- First Try Smooth Decor
- RampMania
- Reverse C Spring
- Secret Entry
- SpringUp

**Bake Endless.cmd** prepares the separate seven-Act stress pool in `data/endless` across all eight themes: 56 variants. **Play Endless.cmd** streams three shuffled Acts per Zone with no score gates and unlimited checkpoint retries. It keeps the historical Second Simple and Third Complex snapshots as useful streaming fixtures. Its tour, warm-up, caches and profiler support graphics work. See [Endless](docs/ENDLESS_MODE.md).

Two specialist launchers remain deliberately: **Authored Act Playtest.cmd** exposes the diagnostic 2D/3D player used by editor tests; **Play Green Hill.cmd** is retained for ongoing local art-review work. Use the six workflow launchers above for ordinary development.

## Controls

| Action | Prototype keyboard | Controller |
| --- | --- | --- |
| Flippers | Q / E | LB / RB |
| Steer | Arrow keys | Left stick |
| Launch | X | X |
| Special | Space | A |
| Retry | R | Back / View |
| Pause / resume | Enter or Escape | Menu / Start |
| Fullscreen | F11 | — |

Standalone Play Act and Endless retain **Enter** to launch and **Escape** to pause. Play Act also has **O** for overview/follow, **F1** for physics tools and **F11** for Player View. **F4 / Shift+F4** control post-processing. Endless has **T** for its camera tour, **N** for a diagnostic boundary jump and **F3** for streaming statistics.

## Shared systems

Characters, Adventure Buddies and temporary abilities use shared physics profiles and centralized modifiers. The old Ice/Spring/Magnet/Practice Chao Lab is retired; the eleven current SRA Buddies and their portraits remain. The procedural alpha, generated Free Play, Score Attack and old score-gated Green Hill progression are also retired. Historical documentation records those experiments.

Eight production themes share authored geometry: Green Hill, Chemical Plant, Rooftop Run, Casino Night, Sky Sanctuary, Ice Cap, Lava Reef and Aquarium Park. Ball forms, motion trails, Specials, cameras and theme switching require no imported character model. Art changes never own collision.

## Build and checks

Use Godot **4.7.2**. Windows launchers default to Compatibility / ANGLE. Keep authored sources and current art in Git; `.bake` sidecars and `test-results/` are ignored. Re-bake after source, art or pipeline changes. Normal streaming validates existing bakes instead of silently rebuilding them during play.

`tools/export_prototype.ps1 -WindowsTemplate <matching-local-Windows-release-template>` snapshots the working source, imports and bakes it, exports a standalone embedded EXE, verifies packaged resources and creates a ZIP under `test-results/prototype-build/`. It does not download assets or publish a release.

Run focused checks with `godot --headless --path . --script res://tests/<test>.gd` after importing the project. Useful checks include profiles/physics, `scorecraft_regression`, `buddy_scoring_regression`, `enemy_regression`, `authored_main_game_regression`, `geometry_bake_regression`, `prototype_plan_regression`, `prototype_setup_regression`, `prototype_archive_regression` and `endless_regression`. Rendered `endless_scene_smoke.gd -- --require-bakes` and `endless_stream_profile.gd` exercise actual graphics and transitions; use Compatibility / ANGLE without `--headless`.

[Shared project brain](docs/PROJECT_BRAIN.md) · [Living design](docs/GAME_DESIGN.md) · [Act editor](docs/ACT_GEOMETRY_EDITOR.md) · [Authored runtime](docs/PLAYFIELD_SOURCES.md) · [Scoring](docs/ACT_SCORING.md)
