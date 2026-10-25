# One engine, multiple level sources

Normal human authored playtesting happens in **Play Green Hill.cmd**, the existing `experiments/visual_lab/visual_lab.tscn` application extending `scripts/game.gd`. An Act supplies a playfield to that game. It does not own another runtime loop.

## Playing a saved Act

1. Launch **Play Green Hill.cmd**. The existing generated Free Play remains the default.
2. Choose **Authored Act** in the footer's **Level source** selector, or press **Load Act…**.
3. Select a saved `.tres` containing a Spawn point. The picker pauses play; successful loading or cancellation restores the previous pause state.
4. Press **Enter / gamepad X** to release the waiting ball. Q/E or LB/RB operate the paddles, arrows/stick steer, and Space/A activates the selected character's special.
5. Save changes in the Act Editor, then use **Start / replay** to reload the current file. Choose **Generated / Existing** to return to the remembered seed, difficulty and construction mode.

The same HUD supplies Rings / Score, character selection, special meter/instructions, Scorecraft, Chao Lab, Start / replay and F1 tuning. Escape pauses, R resets and relaunches, O toggles overview/follow, and C opens the existing character study. Source changes clear score, ring progress, meter, combo and temporary character state through the ordinary new-run path. Physics overrides, camera tuning and the selected character persist. Leaving a generated Zone restores the sandbox Chao as before.

For this single-Act milestone, authored play is **Free Play**. The existing Score Attack and Green Hill Zone choices remain visible but disabled with an explanation. No goal, score gate, draft transition or multi-Act assembly is inferred from an Exit marker. Generated modes retain their existing behavior.

The app rejects invalid replacements before removing the current world. An invalid file or missing Spawn reports its error and preserves the active run. Source files are never modified. A failed explicit startup path shows an error instead of silently generating a substitute table.

To start the same main Green Hill app directly with an Act, after normal project import:

```powershell
& 'C:\Program Files\Godot\Godot.exe' --path . --rendering-method gl_compatibility --rendering-driver opengl3_angle res://experiments/visual_lab/visual_lab.tscn -- --act 'res://data/acts/scale_comparison.tres'
```

Direct authored startup bypasses both `TableGenerator` and `ZoneGenerator`. The 50 px-cell `scale_comparison.tres` contains all four gameplay-object types, rings and simple terrain. `playtest_showcase.tres` contains the larger curved terrain sample.

## Ownership and contract

`game.gd` creates one `PhysicsTuning`, `PlaygroundInput`, `PlaygroundBall`, `RingField`, `Scorecraft`, `CharacterSpecials` and HUD. Those instances survive source changes. `TablePresentation`, its `Camera3D`, `WorldEnvironment`, key light and the Green Hill character presenter survive too; only playfield geometry, object meshes and per-layout feedback are rebuilt.

`scripts/playfield_data.gd` is the small common contract:

- World and terrain bounds, exact Spawn, and ring positions.
- References to the installed bumper targets and static terrain bodies.
- Shared bumper-radius and Knuckles glide-surface queries.
- Optional authored Resource and compiler descriptors for the terrain renderer.

Generated data is extracted from real installed `TableChunk` descriptors. Authored data comes from `ActGeometry`, `AuthoredActRuntimeCompiler` and the editor's deterministic ring-trail expansion. Authored loading creates no chunks and invokes no procedural generation or reachability validation. The legacy layout dictionary carries only empty chunk/junction lists, bounds and a display signature at this boundary; gameplay does not invent chunk indices for authored geometry.

The compiler installs terrain, bumpers and `PlaygroundFlipper` instances using the game's existing ball, tuning and controls. The game owns their lifetime. Changing source replaces those level objects, updates the existing ball's collision radius, populates the existing ring field and performs the shared new-run reset. Invalid resources are checked before the live geometry is removed. The existing generated optimization may retain an unchanged lower deck and its paddles.

Character abilities query this contract instead of iterating generated chunks. Sonic targets real bumpers, Tails uses the shared flight implementation, Knuckles recognizes eligible static terrain, and Shadow uses the same area-target scoring path. No source-specific ability implementation or tuning profile exists. Generated checkpoint rails and housings retain their previous glide exclusions.

## Physics, dimensions and presentation

Shared `PhysicsTuning`, ball integration, flipper strikes and bumper collision response remain authoritative. Gravity, mass, steering, counter-steering, launch impulses, special behavior and modifier resolution use the same units and defaults for both sources. Geometry may legitimately change the resulting trajectory.

Authored dimensions continue to come from `scripts/act_dimensions.gd`: ball radius 0.14 cell, round bumper radius 0.25 cell, sling height 0.6 cell, flipper centerline 0.65 cell and capsule radius 0.05 cell, ring radius 0.09 cell. Only object dimensions follow cell size; saved centers, pivots, rotations and terrain footprints remain exact. Generated dimensions remain unchanged. Changing cell size does not normalize traversal time or retune gravity.

Green Hill uses the authored silhouette adapter within the same presentation instance. A continuous grass/checker platform covers the Act's terrain rectangle and stops before the gutter. This is a visual floor, with no added collider or hidden perimeter. Solid terrain stamps are raised brown-and-cream obstacles using the generated wall palette and exact blocked silhouettes. Open paths use the same wall styling along consecutive vertices, without closing their ends. Grass consistently means traversable floor rather than solid collision terrain.

The camera retains its normal Real Pinball angle, presets, tuning and overview toggle. Follow frames a local play window relative to the ball radius, keeping compact authored Sonic comparable in screen size to generated Sonic. Its reference window is 800×1100 physics pixels at the normal 14 px radius; generated framing remains unchanged. Cropped authored views follow side lanes as well as vertical play. Overview still fits the entire Act and gutter. Both axes retain the same `TablePresentation.SCALE`; neither physics nor world geometry is stretched. All 3D geometry stays collisionless.

Authored trails populate the same `RingField`, so ordinary collection, profile magnetism, ring scores, special-meter charge, Scorecraft and cosmetic pickup flight apply automatically. Reset/drain follows normal Free Play rules: it clears temporary motion/combo state and returns to Spawn without restoring collected rings. Clearing a rack still schedules the ordinary rack reset. New runs and source changes repopulate all rings.

## Single-Act lifecycle and timing

Spawn is the serve/reset location. The bottom of the one-cell red gutter is the ball-center drain threshold at every X, including side falls. The normal game waits 0.65 seconds after a drain, resets, then releases after 0.25 seconds. Manual R uses the same normal reset/relaunch path. Entry remains connection metadata.

`ActLifecycle.crossings()` runs inside `game.gd`'s existing physics loop. Upward Activation and Exit crossings increment debug counters and log events. They do not change score, pause play, transition Acts or replace the normal HUD.

`AUTHORED_MAIN_READY` reports resource load, terrain compilation, gameplay-object creation, ring population, Green Hill construction and total ready time. `game.authored_timings` exposes the same values. Total time includes installation, normal reset and UI setup; it excludes engine import/startup and the first GPU frame. No generation search enters these measurements.

## Diagnostics and checks

`scenes/authored_act_playtest.tscn` and **Authored Act Playtest.cmd** remain isolated low-level geometry/lifecycle regression tools. Their toolbar, counters, overview framing and simplified reset behavior are diagnostic, not the target human gameplay experience. Do not expand that scene into a second production game. Reusable Resource loading, compilation and lifecycle helpers stay shared. See [diagnostic controls](AUTHORED_ACT_PLAYTEST.md).

- `tests/authored_main_game_regression.gd` checks same-instance ownership, actual source/picker controls, run resets, authored replay, failure preservation, no-generator authored startup, camera persistence, rings/scoring/meter, all four specials and lifecycle behavior. Run with ANGLE for framebuffer captures or `--headless` for logic checks.
- `tests/authored_source_physics_regression.gd` constructs equivalent generated and authored walls, paddles, bumper and rings, then compares real acceleration, steering, counter-steering, rebounds, strikes, pickups and serve behavior across all four character profiles.
- Existing character, Scorecraft, Score Attack, Zone, ring and presentation regressions cover the shared path after the change. [Verification](VERIFICATION.md) records executed checks and measurements.

Human playtesting still owns flipper timing, smaller-world camera comfort and layout quality. Multiple authored Acts, connector alignment, pools, score gates and Chao draft transitions remain deferred.
