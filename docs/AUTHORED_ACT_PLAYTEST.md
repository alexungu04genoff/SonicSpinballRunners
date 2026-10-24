# Authored Act Playtest

This standalone development scene plays one saved Act using the existing 2D ball, flippers, bumper response and shared physics profile. It compiles the editor's canonical terrain silhouettes directly. It does not invoke procedural generation or alter the normal F5/main-game flow.

## Launch

On Windows, double-click **Authored Act Playtest.cmd**. Choose **Example** for the included table, or **Load Act** for a saved `.tres` file. Loading leaves the ball waiting at its authored Spawn; press **Enter** or **Serve** to release it into normal gravity.

In Godot, open `scenes/authored_act_playtest.tscn` and press **F6**. F5 continues to launch the project's usual main scene.

The Windows launcher selects the project's working ANGLE backend. It accepts an optional Act path and an explicit Godot executable:

```powershell
& '.\scripts\authored_act\launch.ps1' -ActPath 'res://data/acts/playtest_showcase.tres'
& '.\scripts\authored_act\launch.ps1' -GodotPath 'C:\Program Files\Godot\Godot.exe' -ActPath 'C:\My Acts\test-table.tres'
```

The scene also accepts a path directly through Godot's user arguments:

```powershell
& 'C:\Program Files\Godot\Godot.exe' --path . --rendering-method gl_compatibility --rendering-driver opengl3_angle res://scenes/authored_act_playtest.tscn -- --act 'res://data/acts/playtest_showcase.tres'
```

Use the [Act Geometry Editor](ACT_GEOMETRY_EDITOR.md) to create or change the file. Save there, then choose **Reload** in the playtest. Runtime play never saves changes back to the Act. Loading a malformed document or an Act without a Spawn marker reports an error; the runtime does not invent a fallback spawn or repair the layout. Activation and connectors may remain unset in an editable draft.

## Controls

| Action | Keyboard | Gamepad |
| --- | --- | --- |
| Release the waiting ball | Enter | X |
| Left flipper | Q | LB |
| Right flipper | E | RB |
| Horizontal steering | Left / Right | Left stick |
| Reset to Spawn and wait | R | Back / View |
| Pause / resume | Escape | Menu / Start |

**Serve** releases a waiting ball; it does not add a special launch impulse. Time a flipper press as the ball reaches the paddle. Holding a paddle keeps it raised without repeatedly applying the powered strike. **Reset** returns the ball to the saved Spawn with velocity and transient motion cleared. The toolbar also provides Load Act, Example, Reload and Pause.

## What the saved Act controls

The Act's top-left remains `(0, 0)`, with X right and Y down. Terrain anchors, quarter-turns and mirrors resolve through `terrain_shapes.gd`; local collision vertices are those transformed cell coordinates multiplied by the saved cell size. Closed silhouettes become solid polygons. Open shapes become consecutive wall segments with no added closing edge. Overlapping stamps remain independent colliders. Rectangular editor footprints never become collision boxes.

Gameplay-object records preserve their exact saved position and resting angle. Round bumpers use their center, slings use their existing local polygon origin, and flippers use their pivot. Left/right type controls the swing direction. The playtest adds no invisible perimeter, connector collar, procedural terrain or automatic correction. Unusual or obstructed authored layouts remain unusual or obstructed at runtime.

The editor's compact object silhouettes are deliberately separate from physical size. Runtime uses the existing table dimensions:

| Runtime object | Physical size |
| --- | --- |
| Ball | Radius 14 px |
| Round bumper | Radius 38 px |
| Triangle sling | Local vertices `(-40,35)`, `(-15,-55)`, `(45,35)`; 85×90 px before rotation |
| Flipper | 130 px pivot-to-tip centerline, capsule radius 13 px |

These sizes do not scale with the construction cell size. The debug view draws the actual runtime bodies around the saved centers and pivots. Compact editor silhouettes can therefore leave apparently clear space that a full-size runtime object occupies; adjust the authored layout after playtesting instead of expecting load-time repositioning.

## Separate lifecycle markers

- **Entry:** the green span on the bottom edge remains physical connection metadata. There is no previous Act in this standalone scene, and Entry does not activate a checkpoint or generate collision.
- **Activation:** an upward swept crossing of its saved Y line, within the Act width, displays/logs `ACT ACTIVATED`. Downward crossings do not activate it.
- **Spawn:** the exact authored point is used on load, manual reset and automatic drain recovery. It is required for playtesting.
- **Red gutter:** the system-owned region begins below the terrain and has the shared one-cell height. Its **bottom**, `Act height + cell_size × RED_GUTTER_CELLS`, is the ball-center drain threshold. The ball may enter the gutter before draining. The threshold applies across all X so a side fall also recovers. A drain resets to Spawn and releases again after 0.25 seconds. The gutter creates no terrain or collision and does not add a thirteenth row.
- **Exit:** an upward swept crossing of the top-edge connector span displays/logs `ACT EXIT REACHED`. It does not load another Act or permanently end the run.

The complete Act and gutter remain framed in the dedicated 2D playtest view. Presentation and marker annotations do not control physics.

## Included representative table

**Example** loads `data/acts/playtest_showcase.tres`, titled **Authored Playtest — Curve Relay**. It is a format-4 Act with a 12×12 grid and 100 px cells: 1200×1200 px of terrain plus the separate 100 px gutter.

Its 14 terrain placements include mirrored open L walls, rotated straight roof rails, solid lower funnels, a curved ramp overlapped by a circle, an inverted open U and a mirrored open S. All walls are authored geometry. The top roof leaves the Exit physically open from X=500 to X=700. The lower funnels feed a pair of normal flippers with an actual gap between their tips.

| Authored item | Local value |
| --- | --- |
| Round bumper center | `(650.5, 350.25)` |
| Triangle sling origin | `(920.25, 625.5)`, resting angle −25° |
| Left / right flipper pivots | `(440, 1050)` / `(760, 1050)`; normal resting angles |
| Spawn | `(530.5, 960.25)`, above the left paddle |
| Activation | Y=850 |
| Entry / Exit | Start cell 5, width 2 |
| Drain threshold | Ball-center Y≥1300 |

Press Enter, then time Q as the ball approaches the left paddle. Use arrows to steer and Q/E to recover falling shots. The sample is a repeatable geometry and interaction showcase, not a completed Zone or a scored objective.

## Loading baseline and verification

Each successful load reports resource-load, terrain-compilation, gameplay-object-construction, presentation-construction and total Act-ready times in milliseconds. The same values appear in the UI and the `AUTHORED_ACT_READY` log line. They are a measurement baseline for this path, not a promise about future Zone assembly or cold-start performance.

Focused runtime and real-physics regression entry points:

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --script res://tests/authored_act_runtime_regression.gd
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --script res://tests/authored_act_physics_smoke.gd
& 'C:\Program Files\Godot\Godot.exe' --path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --script res://tests/authored_act_scene_smoke.gd
```

The sample is authored and saved through `ActGeometry.save_document()`, including its exact numeric persistence checks. Runtime verification covers collision topology, transform mapping, actual shared ball/object interactions, lifecycle crossings, drain recovery and source immutability. The graphical scene smoke exercises file selection, toolbar/keyboard controls, a physical flipper launch through Activation and rendered captures. Human playtesting still judges flipper timing, rebound feel and layout quality. See [verification results](VERIFICATION.md) for measured timings and executed checks.

Multiple Acts, horizontal alignment, compatibility selection, Zone assembly, score gates, rewards and production presentation remain outside this scene.
