# Authored pinball mechanics

**Scoring extension (2026-10-28):** Spinners now expose repeatable goals, and elevated rails provide bounded protection for active combos. See [Act scoring](ACT_SCORING.md) for current authoring defaults and lifecycle rules; earlier implementation notes below remain historical context.

Implemented 2026-10-25 in the existing Act Editor and main game. Gates, cannons and target banks were absent from the starting repository; this milestone adds the minimal common object identity/property foundation and the three requested mechanics. It does not implement those earlier proposed mechanics.

## Try the sandbox

Open `data/acts/pinball_mechanics_sandbox.tres` in the Act Editor. In **Play Green Hill**, use **Load Act…** to choose the same file. Save edits, then **Reload Act** or F5 in the game. Enter releases the ball, Q/E operate the flippers, arrow keys steer, R resets and Escape pauses. O switches follow/overview. All themes use identical physics.

The sandbox has a spinner, an attracting field, a raised curved route over a lower ring lane and its collision rails, and a return onto the table. It deliberately uses primitive scenery. Shot timing and attraction strength remain playtest tuning.

## Editor

The Gameplay palette adds **Spinner**, **Magnetic Field**, and **Elevated Ramp / Rail**. Centers and pivots snap to the current cell grid; Alt places or drags freely. The Gameplay list scrolls to keep the inspector and canvas inside the window. The inspector exposes exact X/Y positions, arbitrary rotation and per-object numeric properties. Duplication makes a new identity; moving, rotating, undoing and Save As preserve identity.

For a rail, click its entry and successive control points, then press Enter to commit the path as one undo action. Escape cancels the unfinished gesture. The final point is the exit. After selecting a saved rail, enable **Edit path points**:

- Drag a handle to move it; Alt allows free coordinates.
- Click empty space to append a point.
- Shift-click inserts into the nearest control segment.
- Right-click a handle removes it, retaining at least two points.
- Turn off point editing to move the entire rail normally.

Each point edit participates in normal undo/redo. Two to 64 control points are supported, with at least 12 pixels between neighboring points. A deterministic sampled Catmull-Rom curve provides the preview, runtime path and 3D deck. Control points, rather than a resampled approximation, are the saved source of truth. Normal rotation transforms the entire route about its saved origin.

## Properties and provisional tuning

Distances use local physics pixels; angles use degrees.

| Mechanic | Defaults | Supported range |
|---|---|---|
| Spinner | width 40, tick score 5, decay 2/s, maximum spin 40 rad/s | width 10–300; score 0–25; decay 0.5–8; spin 1–60 |
| Magnetic field | radius 100, strength 260 px/s², Attract | radius 15–500; strength 0–600; Attract / Repel |
| Elevated rail | width 40, peak height 40, drag 0.06/s, entry speed 100 px/s | width 18–120; height 10–200; drag 0–1; entry speed 30–600 |

The sandbox uses a 60-pixel rail width, 50-pixel peak height and zero rail drag to make the first route reachable with the default flippers. An input-only regression completes it from the ordinary serve. Inspector validation rejects nonfinite or out-of-range values without silently clamping saved data. Physics retains separate operational safety caps.

New rails default to 40 pixels instead of 80, halving the rise for the same path length. Saved heights stay unchanged: select an existing rail and enter 20, 30 or 40 explicitly. Extending the path also makes its ascent less steep. Height is an exact authored value, not an automatic clearance adjustment.

## Ramp presentation

Ramps inherit the active presentation theme without storing a theme in the Act or changing physics. Green Hill uses timber planks, grass trim and wooden posts; Chemical Plant uses alternating yellow/gray inset panels with pale borders, blue side pipes with metal couplings, yellow retaining straps, small cyan indicators and metal posts; Rooftop Run uses terracotta paving and pale stone. Other themes inherit their existing surface and trim materials through the same optional theme hook.

The deck now has a visible 3-pixel fascia/underside and narrow paired supports. A small inlaid directional arrow replaces the large circular entrance pad. Surface patterns follow distance along the route instead of stretching across curves. Inside edges narrow on tight bends to prevent folded strips; the centerline and its gameplay elevation remain unchanged. These remain collisionless visuals on the same raised path.

## Runtime contract

**Spinner:** A swept crossing of the paddle plane imparts spin from normal crossing speed. It has no blocking collider. Rotation decays exponentially; every half-turn produces one fixed Scorecraft award. At most two scoring events are emitted across all spinners per physics tick, and excess complete turns are discarded instead of queued. Ticks neither build/refresh combos nor charge specials. A crossing cooldown prevents boundary chatter. Sweeps stop at the first physical obstruction.

**Magnetic field:** Attraction and repulsion apply additive impulses equivalent to continuous acceleration at 120 Hz. A linear outer falloff and softened center eliminate singularities; overlapping fields share a 600 px/s² total cap. The field never teleports the ball or replaces velocity. Purple inward-moving arcs indicate attraction; coral outward-moving arcs indicate repulsion. Strengths intentionally remain modest enough for steering and shots to escape.

**Elevated rail:** The same `PlaygroundBall` enters an explicit `on_ramp` state only when crossing the entry aperture forwards with sufficient speed and alignment. Its original collision layer and mask are saved; native gravity is suspended while the same force-integration callback constrains its transform. Lower-table collisions, flipper impulses, ring pickups and new specials are excluded while constrained to the route. There is no second ball, engine, 3D collider or gameplay mesh.

Route progress uses signed longitudinal speed. Projected gravity, ascent/descent and drag affect that speed; weak uphill shots can roll backwards and leave at the entry. There is no steering while constrained. Exit restores the saved collision state and resolved gravity and releases tangent velocity. Entry speed is capped at 2400 px/s; the same limit applies on the path. A short exit cooldown prevents immediate re-capture. Long stalls roll back after 12 seconds; an obstructed route has a final 30-second reset-to-serve safeguard.

Visual deck height rises smoothly over the first 22% of path length, holds over the center, and descends over the last 22%. The ball presenter reads that exact height; the existing follow camera already frames the ball's visual plane. Runtime loading rejects routes whose low portions intersect terrain, bumpers or a flipper's swept capsule, and requires rail width to exceed the ball diameter by two pixels. Clearance follows the actual obstacle height plus a 3-pixel deck and 2-pixel air gap. Ordinary terrain is 32.5 pixels tall, so a crossing needs 37.5 pixels of local elevation; bumper and flipper heights scale with their authored size. The full deck width, including trim, is checked. Low 20–30-pixel routes work above clear floor but cannot pass through taller terrain. Drafts with unsafe mouths remain saveable; failed runtime reloads preserve the current run and ball scale. A final collision query at release handles an unexpectedly obstructed mouth by reversing along the rail.

## Persistence and lifecycle

Act format 11 extends the existing gameplay records with `object_id` and `properties`. Formats 2–10 still load without rewriting source files. Legacy identities derive deterministically from their original index and transform, then persist on explicit Save. New editor objects receive random stable IDs. Exact numeric properties and packed control points use the existing byte-preserving native Resource storage pattern; loading validates payload type and length before decoding.

Reset and drain clear spinner energy and rail ownership. Removing/reloading an Act frees its mechanics controller, so no field survives its source. Source changes retain the main ball, physics tuning, Scorecraft, camera and HUD. Pause freezes simulation and cosmetic field motion. In-progress or malformed replacements do not detach the current controller.

## Verification and limits

`tests/pinball_editor_regression.gd` exercises placement, properties, unique duplication, point gestures, undo/redo and exact persistence in a fresh Godot process. `tests/pinball_mechanics_regression.gd` uses the actual Green Hill application and real 120 Hz physics for scoring, field force, raised traversal, lower-ring exclusion, rollback, pause, reset, drain, invalid replacement, reload and source switching.

The focused suite passes 42 main-game checks and 21 editor checks, including an input-only serve/flipper shot through the complete sandbox route. Run physics checks with `--fixed-fps 120`; editor persistence also launches a fresh Godot process.

`tests/ramp_height_theme_regression.gd` verifies exact 20/30/40 heights, actual terrain and bumper clearance, theme switches without changing the ball or path, and collisionless theme geometry. Graphical runs save matched theme views under `test-results/ramp-<theme>.png`.

Graphical ANGLE runs capture the editor and raised traversal under `test-results/pinball-editor.png` and `test-results/pinball-crossover.png`. Existing authored gameplay, runtime, reload and Scorecraft regressions cover compatibility. No test framework dependency was added.

Manual review still owns flipper timing, magnetic strength, rail entry forgiveness and camera readability. This first version is a constrained path, not a free upper playfield. Multiball, moving ramps, elevators, enemies, full 3D loops, scripting and theme-specific physics remain outside scope.
