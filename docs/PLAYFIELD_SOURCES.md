# Authored Act play, Prototype and Endless

Standalone Play Act supports level authoring; Prototype is the configurable roguelite run; Endless is the separate graphics/streaming stress test. Gameplay flows through Act Geometry Editor → Play Act → Bake Prototype → Play Prototype. Graphics work flows through Bake Endless → Play Endless. The alpha's random table generator, generated chunk recipes, Score Attack and score-gated Green Hill Zone have been retired. Historical design and verification documents may still describe those prototypes.

## Launch and reload

1. Open **Play Act.cmd**. The default is First Try Smooth Decor from the production authored pool.
2. Choose **Load Act…** to open a saved `.tres` containing a Spawn point. The picker pauses play and restores the previous pause state.
3. Press Enter / gamepad X to release the ball; Q/E or LB/RB operate flippers, arrows/stick steer, and Space/A activates the selected special.
4. Save changes in the Act Editor, then choose **Reload Act** or press F5. Invalid saves preserve the current playable Act.

Reload rebuilds authored terrain, objects, rings, decor and presentation, then resets to Spawn. Theme, retro filters, camera tuning, follow/overview choice, fullscreen state and the previous pause state persist. **Replay Act** uses the same saved file. Character selection, Scorecraft and F1 tuning remain available. The old Chao Lab is retired; Prototype uses the current Adventure Buddy system. Scores in standalone play are optional feedback, without a target or gate.

For a specific Act, launch `experiments/visual_lab/visual_lab.tscn` with `-- --act res://data/acts/scale_comparison.tres`. Missing files or Spawn points report an error; no generated substitute is created.

**Play Endless.cmd** starts the streamed mode: three authored Acts per themed Zone, seamless entrances, independently prepared next-theme scenery and blended backgrounds/lighting. See [Endless mode](ENDLESS_MODE.md) for offline baking and streaming details. Its random seed chooses authored Act/theme order, not procedural geometry.

## Ownership and contract

`game.gd` creates one `PhysicsTuning`, `PlaygroundInput`, `PlaygroundBall`, `RingField`, `Scorecraft`, `CharacterSpecials` and HUD. Those instances survive Act changes. `TablePresentation`, its `Camera3D`, `WorldEnvironment`, key light and the Green Hill character presenter survive too; only playfield geometry, object meshes and per-layout feedback are rebuilt.

`scripts/playfield_data.gd` is the small common contract:

- World and terrain bounds, exact Spawn, and ring positions.
- References to the installed bumper targets and static terrain bodies.
- Shared bumper-radius and Knuckles glide-surface queries.
- Authored Resource and compiler descriptors for the terrain renderer.

`PlayfieldData.from_authored()` receives `ActGeometry` and compiler descriptors. Ring trails use the editor's deterministic expansion. There is no generated-source adapter or placeholder chunk layout. Endless initializes this contract from opening-Act metadata; streamed baked collision shapes and objects are installed as they become ready.

The compiler installs terrain, bumpers and `PlaygroundFlipper` instances using the game's existing ball, tuning and controls. The game owns their lifetime. Changing source replaces those level objects, updates the existing ball's collision radius, populates the existing ring field and performs the shared new-run reset. Invalid resources are checked before the live geometry is removed.

Format-6 composite terrain uses its stored final local-cell polygon and ordinary terrain transform. The compiler builds one solid body per composite; editor hit testing and Green Hill extrusion consume the same transformed points. Composite polygons bypass presentation union and outline cleanup, including the deck-envelope input. Runtime loading performs validation and collision/mesh construction, without repeating editor-time boolean unions or smoothing. Source stamps removed by Apply therefore create no internal cliff faces or overlapping bodies. Primitive stamps and open walls retain their existing paths.

Character abilities query this contract instead of iterating generated chunks. Sonic targets real bumpers, Tails uses the shared flight implementation, Knuckles recognizes eligible static terrain, and Shadow uses the same area-target scoring path. No source-specific ability implementation or tuning profile exists.

## Physics, dimensions and presentation

Shared `PhysicsTuning`, ball integration, flipper strikes and bumper collision response remain authoritative. Gravity, mass, steering, counter-steering, launch impulses, special behavior and modifier resolution use the same units and defaults across the play modes. Geometry may legitimately change the resulting trajectory.

Authored dimensions continue to come from `scripts/act_dimensions.gd`: ball radius 0.14 cell, round bumper radius 0.25 cell, sling height 0.6 cell, flipper centerline 0.65 cell and capsule radius 0.05 cell, ring radius 0.09 cell. Only object dimensions follow cell size; saved centers, pivots, rotations and terrain footprints remain exact. Changing cell size does not normalize traversal time or retune gravity.

Green Hill uses the authored silhouette adapter within the same presentation instance. Walls and solid stamps have bright textured grass caps, a leafy turf edge and orange/brown checker soil sides; the playable floor uses a darker grass texture at gameplay height. Raised height, side faces and shadows distinguish solid terrain from the floor. The procedural textures take their visual cues from [SEGA's Sonic Mania screenshots](https://www.sega.jp/game/detail/sonicmania/); no external texture files are required. Open paths retain their unclosed topology and exact footprint.

The deck follows the outside contour of connected side walls, extending beneath them rather than forming a grass shelf outside the table. It remains continuous through the playable interior and stops before the gutter. The presentation infers this contour from long connected walls on both sides (at least half the terrain height); small interior obstacles do not pinch it. Incomplete/open layouts without a reliable pair retain the terrain rectangle as a fallback. This inference changes no saved data, collider, entry/exit or drain behavior. All 3D geometry remains collisionless.

The camera retains its Real Pinball angle, presets and overview toggle. Authored follow uses a **2× zoom baseline** on the ball-relative 800×1100 reference window (14 px reference radius), giving a 200×275 px local window at 50 px cells before projection padding. **F1 → Camera follow tuning → Follow zoom** adjusts the follow framing by 0.6–2.5×; O still fits the entire Act and gutter regardless of that setting. Close views follow side lanes, scale the dead zone/look-ahead with zoom, and catch fast ball movement before it reaches the screen edge while preserving the camera speed cap and fixed angle. Both axes retain the same `TablePresentation.SCALE`; neither physics nor world geometry is stretched.

Authored trails populate the same `RingField`, so ordinary collection, profile magnetism, ring scores, special-meter charge, Scorecraft and cosmetic pickup flight apply automatically. Reset/drain follows the shared Act rules: it clears temporary motion/combo state and returns to Spawn without restoring collected rings. Clearing a rack still schedules the ordinary rack reset. New runs and Act changes repopulate all rings.

## Single-Act lifecycle and timing

Spawn is the serve/reset location. The bottom of the one-cell red gutter is the ball-center drain threshold at every X, including side falls. The normal game waits 0.65 seconds after a drain, resets, then releases after 0.25 seconds. Manual R uses the same normal reset/relaunch path. Entry remains connection metadata.

`ActLifecycle.crossings()` runs inside `game.gd`'s existing physics loop. Upward Activation and Exit crossings increment debug counters and log events. They do not change score, pause play, transition Acts or replace the normal HUD.

`AUTHORED_MAIN_READY` reports resource load, terrain compilation, gameplay-object creation, ring population, presentation construction and total ready time. `game.authored_timings` exposes the same values. Total time includes installation, normal reset and UI setup; it excludes engine import/startup and the first GPU frame. No generation search enters these measurements.

## Diagnostics and checks

`scenes/authored_act_playtest.tscn` and **Authored Act Playtest.cmd** remain isolated low-level geometry/lifecycle regression tools. Their toolbar, counters, overview framing and simplified reset behavior are diagnostic, not the target human gameplay experience. Do not expand that scene into a second production game. Reusable Resource loading, compilation and lifecycle helpers stay shared. See [diagnostic controls](AUTHORED_ACT_PLAYTEST.md).

- `tests/authored_main_game_regression.gd` checks same-instance ownership, actual Act/picker controls, run resets, authored replay, failure preservation, no-generator authored startup, camera persistence, rings/scoring/meter, all four specials and lifecycle behavior. Run with ANGLE for framebuffer captures or `--headless` for logic checks.
- `tests/authored_source_physics_regression.gd` compares fresh and baked authored collisions, steering, strikes, rebounds, pickups and serve behavior across all four characters.
- Character, generic modifier, SRA Buddy, Scorecraft, ring, presentation and Endless regressions cover the shared engine. Retired generator/Score Attack/old Zone tests were removed with those features.

Human playtesting still owns flipper timing, camera comfort and layout quality. Unlimited-duration Endless coordinate rebasing and production packaging remain future work.
