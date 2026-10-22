# Sonic Spinball Runners — Modular Physics Playground

A local Godot 4/GDScript pinball prototype. Gameplay uses an invisible 2D rigid body and 2D collision geometry. A separate, collisionless 3D scene renders raised primitives through a stationary perspective camera, with an orthographic reference preset. No external artwork or dependencies are required.

This remains an endless experimental physics playground, including the modular generator. There are no acts, zones, win conditions, lives, bosses, or roguelite progression. The ball number is a serve counter, not a lives limit. Primitive, blocky N64-style visuals are sufficient while we tune physics, flippers, bumpers, steering, profiles, modifiers, and layouts.

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

- A fixed lower deck and four hand-authored upper layouts, selected by a reproducible seed with optional mirroring and horizontal shifting.
- Spacious bumper gardens, a curved return lane, central targets, and an asymmetric risk route. All joins meet at physics `y = 700` with visible closure rails where openings differ.
- Segmented curved rails, circular and triangular bumpers, and 16 rings per generated table. The original 17-ring layout remains a validated fallback.
- Two physical flippers with a short, edge-triggered launch window. Holding a flipper keeps it raised; it does not repeatedly award launch impulses.
- Rings award 25 points; bumpers award 100. Clearing all rings awards 500 and restores the ring rack after one second.
- Rings contribute five special-meter points and bumpers two, scaled by the profile. Meter caps at 100; specials remain future work.
- Rings stay at their authored positions and collect immediately inside the configurable magnetic radius. Collection checks the ball's swept path and never alters ball momentum.
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
├── Rings                                 stationary pickups and swept collection
├── TableView / Collisionless3DViewport
│   └── Presentation                      camera, lights, meshes, debug geometry
└── DebugAndHUD (CanvasLayer)              live tuning, telemetry, score, pause
```

Authoritative layout is in `data/chunks/*.tres` and the fixed `data/lower_chunk.tres`. `scripts/table_generator.gd` selects and validates a layout before the controller builds it. `data/upper_chunk.tres` preserves the original fallback and physics-test fixture. Character defaults are in `data/balanced.tres` and `data/floaty.tres`. The example modifier is `data/practice_chao.tres`.

Physics lives in `scripts/ball.gd`, `scripts/flipper.gd`, and `scripts/table_chunk.gd`. `scripts/ring_field.gd` owns collectibles. `scripts/game.gd` handles score, meter, drain/serve, and signal wiring. Rendering is isolated in `scripts/presentation.gd`. Future models can replace `ball_visual` and listen to existing bumper/flipper signals without changing collisions.

### Coordinate mapping

The table is 800 × 1400 physics pixels. Positive 2D Y points down the table. One physics pixel is 0.01 3D world units:

```text
3D position = ((physics_x - 400) × 0.01, visual_height, (physics_y - 700) × 0.01)
```

All geometry and gameplay visuals use `TablePresentation.map_point()`. Height is cosmetic. No `CollisionObject3D` exists in the presentation tree. Flipper visual rotation is the negative of the physical angle around the 3D Y axis. Camera projection never changes gameplay geometry or its scale.

### Depth and camera experiment

Use **Camera** in the Live Physics Lab, including while paused:

| Preset | Projection | Elevation above the board | Framing |
| --- | --- | --- | --- |
| Top-down reference | Orthographic | 90° | Size 15.6; equal scale throughout |
| Real Pinball (default) | Perspective | 60° | Vertical FOV 40°; distance 20; near edge about 1.41× the far edge |
| Dramatic Pinball | Perspective | 50° | Vertical FOV 52°; distance 16; near edge about 1.74× the far edge |

Perspective views look at `(0, 0, 1)` from the positive-Z/front end. All three cameras remain stationary and show the entire current board. The viewport reserves space beside both debug panels; there is no follow, scrolling, dynamic zoom, or gameplay scaling. The selected preset survives table regeneration but is not saved across restarts. Real Pinball is the recommended starting point: Dramatic compresses distant lanes and increases occlusion at bumper edges.

Circular bumpers have beveled cylinder tops, triangular bumpers are solid prisms, and rails/flippers extrude their exact capsule footprints with smaller inset top trim. Sides and tops use distinct simple materials. The floor surface is at visual Y = 0, above a 0.32-unit slab. Rails are 0.325 units tall, circular bumpers 0.42, triangular bumpers 0.34, and paddles 0.265 (0.285 at the pivot cap). The ball keeps its 0.14-unit radius and 0.16-unit center height; rings sit at 0.23. Bumper hit pulses change only visual height.

One directional light casts real shadows from the ball, bumpers, rings and rails onto the board. Ambient light preserves readability, and 4× MSAA smooths small primitive edges. No textures, custom shaders, post-processing or 3D collision shapes are used. The floor and flat grid markings receive shadows without casting their own.

**Physics** shows green X-ray collider footprints on the board plane, including moving flippers and the ball. **Chunks** and **Connectors** retain their independent overlays. Raised tops naturally project away from these ground footprints in perspective; this is height parallax, not a collision offset. Debug lines do not cast shadows. The pause notice stays above the table so it cannot hide the connection being inspected.

For reproducible screenshots, run `tests/presentation_smoke.gd` graphically. Captures are written to ignored `test-results/depth-*.png`; see [verification and visual limits](docs/VERIFICATION.md).

### Chunk contract

`ChunkData` stores an ID, grid position and dimensions (100 pixels per cell), top/bottom connection rectangles, rail polylines, bumpers, ring positions, spawn markers, visual attachment metadata, a navigable footprint, and route probes. Upper sections are 7 × 7 cells; the fixed lower deck is 8 × 7. They fit the existing 800 × 1400 table and camera.

Horizontal mirroring and cell shifts apply consistently to collision descriptors, connectors, objects, markers, and debug bounds through `ChunkData.world_point()` / `world_rect()`. There is no rotation field. Compatibility uses overlapping opening spans at the same world boundary, never connector IDs. Unused opening spans receive capsule rails; the shared passage remains open. A coarse static reachability check rejects obvious disconnected routes. See [Generation contract and limits](docs/GENERATION.md).

Visual attachment metadata is a future theme hook. The current renderer uses primitive materials; it does not load themed assets.

### Generate a table

Use the **Table Generator** panel on the left. At serve, or after pausing with **Escape / Menu**, enter a seed, choose an **Easy / Normal / Hard** preference, and click **Build seed + preference**. **Next seed** increments the current seed using the selected preference. **Repeat current layout** restores the current seed and preference even if controls contain unbuilt edits. Different configurations can select the same layout. Generation resets the ball to serve, score, rings, meter, timers, and ball count, while preserving physics tuning, the Chao toggle, overlays, camera preset, and pause state. Resume if paused, then press **Enter / X** to launch.

For generator **v2**, try **1 + Easy** (Central Targets), **10 + Easy** (Bumper Garden), **6 + Normal** (Outer Return), and **1 + Hard** (Risk Route). Version 1 seed mappings have changed. The panel and log record the seed, preference, IDs, transformations, and actual estimated difficulty. Reasons include clear opening width, offset, largest ledge, sampled approach clutter, and authored chunk ratings. **Chunks** and **Connectors** have independent overlays. F1 hides both development panels. Settings are not saved across restarts.

Difficulty is a rough selection preference, not a physics mode or safety override. Valid ledges and sharp corners remain. The current library estimates range from about **29–55 / 100**, so Hard selects a nearby valid candidate and still reports its actual **Normal** estimate. Normal and Hard may select the same layout. A small eight-point selection band retains seed variety around the closest valid score. See [difficulty scoring and limits](docs/GENERATION.md).

## Physics and live tuning

The simulation runs at 120 Hz with world gravity 700 px/s². Ball mass is one kilogram. All profile fields, labels, units, and allowed limits are centralized in `PhysicsProfile.FIELDS`.

The panel edits session values before modifiers. Its **Active values** section shows final effective values. Click a numeric field, enter a value, then press Enter to return keyboard control to the game. Gameplay keys are suppressed while editing a numeric field. Profile switching clears session edits but preserves the Chao toggle. **Restore profile defaults** clears edits for the selected profile and also preserves that toggle. Ball reset preserves tuning, score, rings, and meter.

| Field | Balanced | Floaty | Meaning |
| --- | ---: | ---: | --- |
| Steering acceleration | 2200 | 2200 | px/s² at strength 1.0 |
| Counter-steering deceleration | 4000 | 4000 | px/s² at strength 1.0, opposing total horizontal motion |
| Steering contribution limit | 120 | 120 | px/s of accumulated steering assistance |
| Steering release deceleration | 3000 | 3000 | px/s² at strength 1.0 |
| Steering strength | 0.10 | 0.10 | Acceleration/deceleration multiplier |
| Gravity scale | 1.0 | 0.58 | Multiplier on 700 px/s² gravity |
| Maximum downward speed | 1500 | 1000 | px/s; downward component only |
| Rolling acceleration | 80 | 80 | Additional downhill contact acceleration |
| Rolling drag | 0.10 | 0.10 | Contact tangential damping in 1/s |
| Rolling assistance cutoff | 900 | 900 | Stops adding rolling acceleration above this tangent speed |
| Flipper launch strength | 1050 | 1050 | Impulse divided by mass, before leverage factor |
| Bumper rebound multiplier | 1.0 | 1.0 | Scales the target outward normal speed |
| Wall restitution | 0.72 | 0.72 | Rail normal-speed retention |
| Ring magnet radius | 50 | 50 | px from ball center to ring center; 0 disables magnetism |
| Special meter charge | 1.0 | 1.0 | Multiplier on earned charge |

These values are provisional, not approved character balance.

### Ring collection

The magnetic radius is an immediate collection distance, similar to an electric shield. Rings remain fixed until collected and disappear immediately; there is no pull animation in this lightweight version. Every physics tick checks the closest point on the ball's previous-to-current position segment, so a fast pass can collect a nearby ring even when both tick endpoints are outside its radius.

Direct contact retains its existing 26-pixel center-distance threshold (14-pixel ball radius plus 12-pixel ring allowance). The effective pickup radius is the larger of that contact threshold and the configured magnet radius. A ring becomes inactive before its score/meter event is emitted, preventing duplicate awards until a new rack resets it. Waiting at serve does not collect rings. The unused attraction-speed stat was removed; radius remains in the centralized profile/modifier schema and Live Physics Lab for future Chao upgrades. Neither collection nor a future cosmetic effect may alter ball movement.

### Steering strength and the provisional default

Both test profiles now start with **Quick / Tight**, selected after playtesting. At full stick, `2200 × 0.10 = 220 px/s²` of normal assistance accumulates toward a separate ±120 px/s contribution limit. Counter-steering uses `4000 × 0.10 = 400 px/s²`; release removes assistance at `3000 × 0.10 = 300 px/s²`. Original remains selectable with strength 0.065, acceleration/counter 1000, and release 1400. Analog magnitude scales the target contribution; the action deadzone is 0.18. Strength is a multiplier on configured acceleration, **not** a percentage of the ball's velocity or trajectory.

Each tick applies only the change in steering contribution as an impulse. Existing horizontal and vertical momentum remains intact. Collision contact clears the bookkeeping contribution without applying a cancelling impulse: the rebound becomes physical momentum. Therefore the contribution budget is per free-flight interval; sustained rail contact can continue receiving bounded steering acceleration. This is intentional and should be judged in playtesting.

Counter-steering has an independent rate, used when the commanded correction opposes total horizontal velocity. The **Steering** dropdown retains Original, Quick/tight, Air control, and Stronger brake presets. The readout exposes raw/routed input, horizontal velocity, actual steering acceleration/impulse, contribution/target, saturation, blockers, and collision resets. Phase 2A changes only the profile defaults; steering and release behavior are unchanged. See [Steering investigation](docs/STEERING_INVESTIGATION.md) for the trace and limitations, including why release unwinds temporary braking.

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
& 'C:\Program Files\Godot\Godot.exe' --headless --path 'E:\Sonic Spinball Runners' --script res://tests/steering_regression.gd
& 'C:\Program Files\Godot\Godot.exe' --headless --path 'E:\Sonic Spinball Runners' --script res://tests/generation_regression.gd
& 'C:\Program Files\Godot\Godot.exe' --headless --path 'E:\Sonic Spinball Runners' --script res://tests/ring_regression.gd
& 'C:\Program Files\Godot\Godot.exe' --path 'E:\Sonic Spinball Runners' --script res://tests/generation_ui_smoke.gd
```

The regression scripts use Godot directly, with no testing dependency. `tests/profile_regression.gd` protects resource resolution and reset behavior. `tests/physics_regression.gd` exercises real physics, both flippers, high-speed rail and bumper impacts, chunk crossings, scoring, collection, pause, live tuning, drain recovery, and 20 seconds of simulated play. See `docs/VERIFICATION.md` for results and practical limits.

`tests/generation_regression.gd` checks all 16 authored transformations, seed reproduction, rejected layouts/fallback, safe reset, real seam crossings, closure collisions, and short play simulations. `tests/generation_ui_smoke.gd` exercises generation controls and captures all four sample tables when run graphically. Capture scripts create the ignored `test-results/` directory when needed.

Use **Physics** for collision outlines, **Chunks** for transformed section bounds, and **Connectors** for opening rectangles (purple) plus the checked clear passage (green). Outlines are raised slightly above the board for readability; their X/Z footprint derives from gameplay coordinates.

Before expanding the generator, manually evaluate controller feel, launch timing, rail shoulders, lane accessibility, and modifier extremes across the sample seeds. Static connectivity and short simulations cannot prove every trajectory is playable. Character abilities, drafting, touch controls, endless tables, network services, and exports remain outside this milestone.
