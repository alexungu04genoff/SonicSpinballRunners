# Authored Act diagnostics

**Normal human authored playtesting happens through the main Green Hill application.** Launch **Play Green Hill.cmd** and use **Level source → Authored Act / Load Act…**. That path retains the normal game's ball, tuning, input, rings, scoring, characters, specials, HUD and camera. See [one engine, multiple level sources](PLAYFIELD_SOURCES.md) for the current gameplay workflow and architecture.

The standalone scene below remains a low-level geometry, scale and lifecycle diagnostic. Its simplified loop, toolbar, counters and reset rules are test fixtures, not a second production gameplay engine. It compiles the same canonical terrain silhouettes and reuses the same primitive physics implementations. Keep reusable loading/compiler/lifecycle helpers shared; add normal gameplay features to `game.gd`.

## Diagnostic launch

On Windows, double-click **Authored Act Playtest.cmd**. Choose **Example** for the curve showcase, **Compare** for a simple scale-reference Act, or **Load Act** for a saved `.tres` file. Loading leaves the ball waiting at its authored Spawn; press **Enter** or **Serve** to release it into normal gravity.

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
| Green Hill / underlying 2D debug view | F2 | Toolbar |
| Construction grid and lifecycle guides in Green Hill | F3 | Toolbar |

**Serve** releases a waiting ball; it does not add a special launch impulse. Time a flipper press as the ball reaches the paddle. Holding a paddle keeps it raised without repeatedly applying the powered strike. **Reset** returns the ball to the saved Spawn with velocity and transient motion cleared. The toolbar also provides Load Act, Example, Reload and Pause.

## What the saved Act controls

The Act's top-left remains `(0, 0)`, with X right and Y down. Terrain anchors, quarter-turns and mirrors resolve through `terrain_shapes.gd`; local collision vertices are those transformed cell coordinates multiplied by the saved cell size. Closed silhouettes become solid polygons. Open shapes become consecutive wall segments with no added closing edge. Overlapping stamps remain independent colliders. Rectangular editor footprints never become collision boxes.

Gameplay-object records preserve their exact saved position and resting angle. Round bumpers use their center, slings use their existing local polygon origin, and flippers use their pivot. Left/right type controls the swing direction. The playtest adds no invisible perimeter, connector collar, procedural terrain or automatic correction. Unusual or obstructed authored layouts remain unusual or obstructed at runtime.

`scripts/act_dimensions.gd` is the shared source for editor silhouettes and authored runtime dimensions. Only dimensions scale with the document's cell size; saved positions, angles and pivots never move:

| Object | Cell-relative size | At 50 px cells | At 100 px cells |
| --- | --- | --- | --- |
| Ball | Radius 0.14 cell | 7 px | 14 px |
| Round bumper | Radius 0.25 cell; diameter 0.5 cell | 12.5 px radius | 25 px radius |
| Triangle sling | Height 0.6 cell; width approximately 0.567 cell | 30×28.33 px height/width | 60×56.67 px height/width |
| Flipper | Centerline 0.65 cell; capsule radius 0.05 cell | 32.5 px + 2.5 px caps | 65 px + 5 px caps |
| Ring | Radius 0.09 cell | 4.5 px | 9 px |

The ball deliberately retains its former 14 px radius at 100 px cells and scales down at smaller authored cell sizes. It remains smaller than the bumper at either scale. Gravity, steering, impulses, angular speeds and profile values retain their existing physics units; this is geometry consistency, not a retuning of traversal time across differently sized worlds. Generated tables retain their existing ball and object dimensions. The sling scales about its original polygon origin; the flipper capsule extends one radius behind the pivot and beyond its centerline tip.

## Green Hill and rings

The shared `TablePresentation` accepts generic terrain/object descriptors from the authored compiler. `GreenHillPresentation` supplies grass, checker cliffs, sky, ocean, lighting and scenery. Filled stamps and generated rails share textured grass caps, leafy edges and checker soil sides, raised above the darker playable grass. Open stamps use matching narrow rails along consecutive vertices. The deck follows connected outer side walls and stops before the gutter; loose layouts without reliable enclosing sides retain a rectangular visual floor. The authored path creates no `TableChunk` and never calls a generator. Visual geometry may merge overlapping solid surfaces, while each saved placement retains its independent collider. The floor adds no collision; all 3D nodes are collisionless.

This diagnostic defaults to a complete Act/gutter overview using the Real Pinball perspective. The main app starts with a substantially closer authored follow view (2× baseline zoom), with an additional Follow zoom multiplier under F1's Camera follow tuning and O for the full overview. X and Y use the same 2D-to-3D mapping scale; camera projection never stretches the underlying geometry. F2 reveals the underlying 2D geometry. F3 adds compact grid, Spawn, Entry, Exit, Activation and drain guides without changing collision or lifecycle behavior.

Saved ring trails expand through the same endpoint/spacing function as the editor. The existing `RingField` handles swept contact and profile magnet collection; the shared presentation supplies the existing cosmetic pickup flight toward the rolling ball. Collection cannot move the ball or award twice for the same active ring. Direct contact uses the actual ball and ring radii; the shared profile's magnet radius stays in physics pixels. Reset/drain restores the rack, and Reload resets the displayed pickup count. No score gate, rack bonus, special ability or progression is added to this standalone scene.

## Separate lifecycle markers

- **Entry:** the green span on the bottom edge remains physical connection metadata. There is no previous Act in this standalone scene, and Entry does not activate a checkpoint or generate collision.
- **Activation:** an upward swept crossing of its saved Y line, within the Act width, displays/logs `ACT ACTIVATED`. Downward crossings do not activate it.
- **Spawn:** the exact authored point is used on load, manual reset and automatic drain recovery. It is required for playtesting.
- **Red gutter:** the system-owned region begins below the terrain and has the shared one-cell height. Its **bottom**, `Act height + cell_size × RED_GUTTER_CELLS`, is the ball-center drain threshold. The ball may enter the gutter before draining. The threshold applies across all X so a side fall also recovers. A drain resets to Spawn and releases again after 0.25 seconds. The gutter creates no terrain or collision and does not add a thirteenth row.
- **Exit:** an upward swept crossing of the top-edge connector span displays/logs `ACT EXIT REACHED`. It does not load another Act or permanently end the run.

The complete Act and gutter remain framed in both views. Presentation and marker annotations do not control physics.

## Included representative table

**Example** loads `data/acts/playtest_showcase.tres`, titled **Authored Playtest — Curve Relay**. It is a format-5 Act with a 12×12 grid and 100 px cells: 1200×1200 px of terrain plus the separate 100 px gutter.

Its 14 terrain placements include mirrored open L walls, rotated straight roof rails, solid lower funnels, a curved ramp overlapped by a circle, an inverted open U and a mirrored open S. All walls are authored geometry. The top roof leaves the Exit physically open from X=500 to X=700. The lower funnels feed a pair of normal flippers with an actual gap between their tips.

| Authored item | Local value |
| --- | --- |
| Round bumper center | `(650.5, 350.25)` |
| Triangle sling origin | `(920.25, 625.5)`, resting angle −25° |
| Left / right flipper pivots | `(440, 1050)` / `(760, 1050)`; normal resting angles |
| Spawn | `(482.5, 960.25)`, above the compact left paddle |
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
& 'C:\Program Files\Godot\Godot.exe' --path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --script res://tests/authored_green_hill_smoke.gd
```

The sample is authored and saved through `ActGeometry.save_document()`, including its exact numeric persistence checks. Runtime verification covers collision topology, transform mapping, actual shared ball/object interactions, lifecycle crossings, drain recovery and source immutability. The graphical scene smoke exercises file selection, toolbar/keyboard controls, a physical flipper launch through Activation and rendered captures. Human playtesting still judges flipper timing, rebound feel and layout quality. See [verification results](VERIFICATION.md) for measured timings and executed checks.

**Compare** loads `data/acts/scale_comparison.tres`, a simple 50 px-cell reference with straight terrain, all four gameplay-object types, exact fractional anchors, rings and lifecycle markers. Open the same file in the Act Editor; use F3 in the playtest to compare grid-relative footprints and F2 to inspect the authoritative bodies. The rendered comparison smoke also checks equivalent geometry at 100 px cells without scaling saved pivots.

Multiple Acts, horizontal alignment, compatibility selection, Zone assembly, score gates and rewards remain outside this scene. Human playtesting still owns the feel of compact paddles and the preferred camera framing.
