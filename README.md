# Sonic Spinball Runners — Physics Playground

A local Godot 4/GDScript pinball prototype. Gameplay uses an invisible 2D rigid body and 2D collision geometry. A separate, collisionless 3D scene renders the table through a tilted orthographic camera. No external artwork or dependencies are required.

## Run

Open `project.godot` in Godot 4 and press **F6** from `scenes/playground.tscn`, or **F5** to run the project. The prototype was tested with **Godot 4.7.2** on Windows, using the Compatibility renderer.

For this machine, PowerShell can launch it with:

```powershell
& 'C:\Program Files\Godot\Godot.exe' --path 'E:\Sonic Spinball Runners'
```

The ball starts at the serve marker. Press **Enter** or gamepad **X** to launch. Draining automatically respawns and relaunches the ball. There is no lives limit in the playground.

| Action | Keyboard | Windows gamepad |
| --- | --- | --- |
| Left flipper | Q | LB |
| Right flipper | E | RB |
| Horizontal steering | Left/right arrows | Left analog stick |
| Launch | Enter | X |
| Reset and relaunch | R | Back/View |
| Pause/resume | Escape | Menu/Start |
| Reserved special | Space | A |
| Toggle tuning panel | F1 | — |

Both flippers can be held simultaneously. Special input currently displays a status message; it does not consume the meter or execute an ability.

## What is playable

- Two spacious, manually assembled sections with a continuous open connector at physics `y = 700`.
- Segmented curved rails, three circular bumpers, two triangular bumpers, and 17 rings.
- Two physical flippers with a short, edge-triggered launch window. Holding a flipper keeps it raised; it does not repeatedly award launch impulses.
- Rings award 25 points; bumpers award 100. Clearing all rings awards 500 and restores the ring rack after one second.
- Rings contribute five special-meter points and bumpers two, scaled by the profile. Meter caps at 100; specials remain future work.
- Rings move toward the ball within the magnet radius. Magnetism does not alter ball momentum.
- Automatic drain recovery, a fixed serve, two test profiles, an example Chao modifier, and live tuning.

## Runtime structure

`scenes/playground.tscn` is the entry scene. Its controller builds this small runtime tree from resources:

```text
PhysicsPlayground                         scripts/game.gd
├── PhysicsTuning                         base profile + overrides + modifiers
├── InputRouter                           named input actions / virtual-input seam
├── PhysicsWorld (Node2D)
│   ├── UpperChunk                        static 2D rails, bumpers, Marker2D nodes
│   ├── LowerChunk                        static 2D rails, bumpers, Marker2D nodes
│   ├── PlayerPhysics (RigidBody2D)        invisible circle, radius 14 px
│   ├── LeftFlipper (AnimatableBody2D)
│   └── RightFlipper (AnimatableBody2D)
├── Rings                                 collection and attraction state
├── TableView / Collisionless3DViewport
│   └── Presentation                      camera, lights, meshes, debug geometry
└── DebugAndHUD (CanvasLayer)              live tuning, telemetry, score, pause
```

Authoritative layout is in `data/upper_chunk.tres` and `data/lower_chunk.tres`. Character defaults are in `data/balanced.tres` and `data/floaty.tres`. The example modifier is `data/practice_chao.tres`.

Physics lives in `scripts/ball.gd`, `scripts/flipper.gd`, and `scripts/table_chunk.gd`. `scripts/ring_field.gd` owns collectibles. `scripts/game.gd` handles score, meter, drain/serve, and signal wiring. Rendering is isolated in `scripts/presentation.gd`. Future models can replace `ball_visual` and listen to existing bumper/flipper signals without changing collisions.

### Coordinate mapping

The table is 800 × 1400 physics pixels. Positive 2D Y points down the table. One physics pixel is 0.01 3D world units:

```text
3D position = ((physics_x - 400) × 0.01, visual_height, (physics_y - 700) × 0.01)
```

All geometry and gameplay visuals use `TablePresentation.map_point()`. Height is cosmetic. No `CollisionObject3D` exists in the presentation tree. The orthographic camera sits at `(0, 18, 6.5)` and looks at the table center. Flipper visual rotation is the negative of the physical angle around the 3D Y axis.

### Chunk contract

`ChunkData` stores grid position and dimensions (100 pixels per cell), top/bottom connection rectangles, rail polylines, bumpers, ring positions, spawn markers, and independent visual attachment metadata. The two sections are each 8 × 7 cells. Only three approximate lanes are populated, leaving generous routes between obstacles.

Horizontal mirroring and cell shifts are represented in the resource and applied to geometry, objects, and markers. There is no rotation field. Connector compatibility and transformed layouts must be reviewed manually; no generator or automated layout validator is included. Both authored sections share rail endpoints at `(55, 700)` and `(745, 700)` and add no cross-table collider at the join. The lower exit leads to the drain; flippers use the lower section's marker positions.

Visual attachment metadata is a future theme hook. The current renderer uses primitive materials; it does not load themed assets.

## Physics and live tuning

The simulation runs at 120 Hz with world gravity 700 px/s². Ball mass is one kilogram. All profile fields, labels, units, and allowed limits are centralized in `PhysicsProfile.FIELDS`.

The panel edits session values before modifiers. Its **Active values** section shows final effective values. Click a numeric field, enter a value, then press Enter to return keyboard control to the game. Gameplay keys are suppressed while editing a numeric field. Profile switching clears session edits but preserves the Chao toggle. **Restore profile defaults** clears edits for the selected profile and also preserves that toggle. Ball reset preserves tuning, score, rings, and meter.

| Field | Balanced | Floaty | Meaning |
| --- | ---: | ---: | --- |
| Steering acceleration | 1000 | 1000 | px/s² at strength 1.0 |
| Counter-steering deceleration | 1000 | 1000 | px/s² at strength 1.0, opposing total horizontal motion |
| Steering contribution limit | 120 | 120 | px/s of accumulated steering assistance |
| Steering release deceleration | 1400 | 1400 | px/s² at strength 1.0 |
| Steering strength | 0.065 | 0.065 | Acceleration/deceleration multiplier |
| Gravity scale | 1.0 | 0.58 | Multiplier on 700 px/s² gravity |
| Maximum downward speed | 1500 | 1000 | px/s; downward component only |
| Rolling acceleration | 80 | 80 | Additional downhill contact acceleration |
| Rolling drag | 0.10 | 0.10 | Contact tangential damping in 1/s |
| Rolling assistance cutoff | 900 | 900 | Stops adding rolling acceleration above this tangent speed |
| Flipper launch strength | 1050 | 1050 | Impulse divided by mass, before leverage factor |
| Bumper rebound multiplier | 1.0 | 1.0 | Scales the target outward normal speed |
| Wall restitution | 0.72 | 0.72 | Rail normal-speed retention |
| Ring magnet radius | 85 | 85 | px |
| Ring attraction speed | 180 | 180 | px/s |
| Special meter charge | 1.0 | 1.0 | Multiplier on earned charge |

These values are provisional, not approved character balance.

### What “6.5% steering” means

At full stick, `1000 × 0.065 = 65 px/s²` of steering assistance accumulates toward a separate ±120 px/s contribution limit. Release removes that contribution at `1400 × 0.065 = 91 px/s²`. Analog magnitude scales the target contribution; the action deadzone is 0.18. This is a percentage of configured steering acceleration, **not** a percentage of the ball's velocity or total trajectory.

Each tick applies only the change in steering contribution as an impulse. Existing horizontal and vertical momentum remains intact. Collision contact clears the bookkeeping contribution without applying a cancelling impulse: the rebound becomes physical momentum. Therefore the contribution budget is per free-flight interval; sustained rail contact can continue receiving bounded steering acceleration. This is intentional and should be judged in playtesting.

Counter-steering now has an independent rate, used when the commanded correction opposes total horizontal velocity. Its default matches the original rate. The **Steering** dropdown provides Original, Quick/tight, Air control, and Stronger brake session presets. The new readout exposes raw/routed input, horizontal velocity, actual steering acceleration/impulse, contribution/target, saturation, blockers, and collision resets. Start playtesting with Air control; startup defaults are unchanged. See [Steering investigation](docs/STEERING_INVESTIGATION.md) for the trace, preset values, and limitations, including why release unwinds temporary braking.

There is no global speed clamp. The downward limiter removes only excess downward velocity using an impulse. Rolling assistance applies along supporting contact tangents; its speed cutoff never clamps overall velocity. Air drag is zero. Full velocity replacement occurs only for deliberate reset/serve operations inside `_integrate_forces()`.

### Collision reliability and flippers

The ball uses shape CCD, thick capsule rails, 120 Hz physics, and contact reporting. Testing this Godot build found native CCD missed some fast rail impacts. A supplemental [`PhysicsServer2D.body_test_motion()`](https://docs.godotengine.org/en/stable/classes/class_physicsserver2d.html#class-physicsserver2d-method-body-test-motion) sweep checks actual 2D shapes when travel exceeds half the ball radius per tick. It applies a normal rebound impulse conservatively, at most one physics tick before contact. This avoids tunneling in the tested cases without introducing 3D collisions or a global velocity cap. Extreme speeds may show an early rebound; test new layouts and engine versions.

Flippers rotate at 12 rad/s upward and 7 rad/s on release. A press opens a 0.11-second strike window, applies at most one boost to a nearby ball, and scales it by contact leverage. The normal moving-body response remains active. The launch-strength stat controls the extra boost, not total post-collision speed. This makes tuning explicit while keeping passive physical contact.

### Modifier stacking and limits

For each property:

```text
starting_value = session override, if present; otherwise character base value
effective = clamp((starting_value + sum(additions))
                  × product(multipliers), property minimum, property maximum)
```

More explicitly, choose the session override when one exists; otherwise choose the character value. Add every modifier's additive amount, multiply every multiplier, then clamp once. Missing additions are zero; missing multipliers are one. Resolve from scratch after every change; resources are never modified. Multipliers stack multiplicatively (two ×1.25 effects produce ×1.5625), subject to field limits. There is no modifier inventory yet.

Practice Chao applies ×1.25 steering acceleration and ×1.15 flipper launch strength. Bounds include steering strength 0–0.3, acceleration 0–4000, flipper strength 200–2200, gravity 0.1–2.0, bumper multiplier 0.25–2.5, and restitution 0–0.95. All other limits are in the same schema and enforced by both resolver and panel.

## Verification

From PowerShell, using the installed executable:

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path 'E:\Sonic Spinball Runners' --editor --import --quit
& 'C:\Program Files\Godot\Godot.exe' --headless --path 'E:\Sonic Spinball Runners' --script res://tests/profile_regression.gd
& 'C:\Program Files\Godot\Godot.exe' --headless --path 'E:\Sonic Spinball Runners' --script res://tests/physics_regression.gd
```

The regression scripts use Godot directly, with no testing dependency. `tests/profile_regression.gd` protects resource resolution and reset behavior. `tests/physics_regression.gd` exercises real physics, both flippers, high-speed rail and bumper impacts, chunk crossings, scoring, collection, pause, live tuning, drain recovery, and 20 seconds of simulated play. See `docs/VERIFICATION.md` for results and practical limits.

Use **Physics** to show collision outlines, including the moving ball and flippers. Use **Chunks** to show section boundaries and connector regions. The outlines are raised slightly above the board for readability; their X/Z footprint derives from the same coordinates as gameplay.

Before Phase 2, manually evaluate controller feel, launch timing, readability, low-speed rail contact, and modifier extremes. The live panel does not persist edits across application restarts. Longer stress play and moving-flipper corner cases remain worthwhile. No procedural generation, character abilities, drafting, touch controls, network services, or exports are included.
