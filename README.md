# Sonic Spinball Runners

Godot 4 / GDScript pinball with authored Acts and seamless Endless streaming. An invisible 2D ball owns collisions; collisionless 3D scenery, character visuals and shaders follow it. Windows is the current target.

## Play

- **Play Act.cmd** or Godot **F5** opens the themed authored player, initially **Second Simple**. Use **Load Act…** for another saved `.tres`, then **F5 / Reload Act** after saving editor changes. A failed reload preserves the active world.
- **Play Endless.cmd** streams seven authored Acts: **Second Simple**, **Third Complex**, **First Try Smooth Decor**, **RampMania**, **Reverse C Spring**, **Secret Entry** and **SpringUp**. Each Zone selects three distinct shuffled Acts; the next Zone uses another theme. Acts connect physically, backgrounds overlap and lighting blends. No score gates.
- **Act Geometry Editor.cmd** opens the editor. Terrain, gameplay objects, decor, ring trails and markers share undo/redo and exact saved geometry. Verify checks the authored runtime; it does not guarantee reachability.
- **Bake Endless.cmd** builds all 56 Act/theme variants offline, with simplified curves, shared assets, spatial batches and flat surface materials for this trial. Re-bake after changing an Act, referenced art or the bake pipeline. Normal Endless startup loads valid bakes and does not silently regenerate them.
- Version-6 bakes also record successful physics validation. Endless reuses it only for matching sources and pipelines, shares source documents at startup, and keeps construction in the offline builder.

**Play Green Hill.cmd** remains an existing art-review launcher. **Authored Act Playtest.cmd** remains a diagnostic view of a saved Act. Both use authored geometry.

Controls: **Enter** launches; **Q/E** flip; **arrows** steer; **Space** uses the selected character's special; **R** retries; **Escape** pauses. In the authored player, **O** switches overview/follow, **F1** opens physics tools and **F11** enters Player View. **F4 / Shift+F4** control the N64-ish/VHS/CRT filters. The HUD stays outside world shaders.

Endless also has **T** for a camera tour with the ball parked, **N** for a diagnostic boundary jump and **F3** for streaming statistics. The tour tests scenery transitions without pushing the ball into geometry. See [Endless mode](docs/ENDLESS_MODE.md) for loading limits, bake files and current performance measurements.

## Authored gameplay

Sonic, Tails, Knuckles and Shadow use shared physics profiles and centralized modifiers. Their ball-form presentation, specials, ring collection, Scorecraft and optional session Chao remain available. Act reloads preserve the engine, camera and explicit development settings while resetting the run.

The editor supports terrain stamps and composites, flippers, bumpers, one-way gates, switch banks, springs, spinners, magnetic fields, elevated rails, decor and ring patterns. Saved collision geometry remains authoritative. Art and visual detail reductions never alter physics.

Eight presentation themes share the same authored data: Green Hill, Chemical Plant, Rooftop Run, Casino Night, Sky Sanctuary, Ice Cap, Lava Reef and Aquarium Park. Theme shaders and animated props remain enabled during gameplay.

The procedural alpha was retired on 2026-10-26 at the user's request. Its random table generator, chunk/grid catalogues, connector assembly, Score Attack and old score-gated Zone progression are removed. Earlier design and art documents retain historical measurements; their generated-mode instructions no longer describe current play. Editor previews and offline baking still construct meshes from authored data.

## Development and checks

Open `project.godot` with Godot 4.7.2. Windows launchers use Compatibility / ANGLE by default. No external character model is required. Keep source Acts and imported art in Git; ignored `.bake` files are derived locally and must be included when packaging a verified build.

Run lightweight checks with `godot --headless --path . --script res://tests/<test>.gd`. Useful entry points:

- `profile_regression.gd`, `physics_regression.gd`: shared tuning, steering, authored input and collisionless presentation.
- `authored_main_game_regression.gd`, `act_reload_workflow.gd`: Act replacement, four character abilities, scoring, camera and failed reload preservation.
- `authored_source_physics_regression.gd`, `geometry_bake_regression.gd`: baked versus freshly compiled collisions and serialization.
- `endless_regression.gd`, `endless_cache_regression.gd`, `endless_detail_regression.gd`: ordering/seams, cache sharing and visual detail limits.
- `endless_batch_regression.gd`, `endless_border_regression.gd`: spatial instance buffers, animation bindings and low-triangle trim.
- `endless_scene_smoke.gd -- --require-bakes`: rendered startup and transitions; use Compatibility / ANGLE without `--headless` to exercise shaders.
- `endless_stream_profile.gd`: continuous camera tour with frame, resource, render, memory and draw-call diagnostics.

[Living game design](docs/GAME_DESIGN.md) · [Act editor](docs/ACT_GEOMETRY_EDITOR.md) · [Authored gimmicks](docs/AUTHORED_GIMMICKS.md) · [Authored runtime](docs/PLAYFIELD_SOURCES.md) · [Endless](docs/ENDLESS_MODE.md)
