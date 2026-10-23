# Sonic Spinball Runners — Vertical Traversal Playground

A local Godot 4/GDScript pinball prototype. Gameplay uses an invisible 2D rigid body and 2D collision geometry. Three connected sections form a tall course; a separate, collisionless 3D scene renders raised primitives with a smooth following perspective camera or fixed overview. No external artwork or dependencies are required.

This remains an endless experimental physics playground, including the modular generator. There are no acts, zones, win conditions, lives, bosses, or roguelite progression. The ball number is a serve counter, not a lives limit. Primitive, blocky N64-style visuals are sufficient while we tune physics, flippers, bumpers, steering, profiles, modifiers, and layouts.

## Play Green Hill

On `experiment/green-hill-visual-lab`, double-click **Play Green Hill.cmd** to play the themed version. **Physics Playground.cmd** opens the original debug presentation. Green Hill includes the same current generator, 50 px kit, Normal-flow connections, flippers, ring collection and unlimited drain recovery. Third-party Sonic assets remain local and ignored; a procedural spin-ball works without them.

Use **Enter** to launch, **Q/E** to flip, **Escape** to pause, **O** for overview and **F1** for tuning/seeds. The footer supplies Normal seeds 18/23 and both grid variants. Build while paused or at serve. See [Green Hill launch, assets and verification](experiments/visual_lab/README.md).

## Run the physics playground

Open `project.godot` in Godot 4 and press **F6** from `scenes/playground.tscn`, or **F5** to run the project. The prototype was tested with **Godot 4.7.2** on Windows, using the Compatibility renderer.

For this machine, PowerShell can launch it with:

```powershell
& 'C:\Program Files\Godot\Godot.exe' --path 'E:\Sonic Spinball Runners'
```

The ball starts on the bottom launch deck. Press **Enter** or gamepad **X** to launch. Time the middle flippers to gain height into the top section, then recover as the ball falls. Both left paddles share Q/LB; both right paddles share E/RB. Falling between sections is normal. Draining automatically respawns and relaunches at the bottom, without checkpoints or a lives limit.

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

- A fixed bottom deck, three reusable middle layouts with two openings, and eight upper layouts, selected by a reproducible seed and difficulty preference with optional mirroring and horizontal shifting.
- An optional 50 px construction-grid experiment: choose **Grid base** or **Grid variant** in Table Generator, then build while paused or at serve. Enable **Construction grid** for local coordinates and piece footprints. **Existing catalogue** keeps the original levels available. See [grid authoring and the two-edit variant](docs/GRID_AUTHORING.md).
- Wide aligned Easy sections, flowing Normal gardens/return lanes/target routes, and Hard tapered or offset necks. Joins meet at physics `y = 700` and `y = 1400`. Normal requires aligned joins, passive banks or faceted curves at both junctions; authored interior corners remain.
- Open, gently banked and asymmetric rebound middle sections, each with two bumpers and recovery paddles. Segmented rails, circular/triangular bumpers and collectible rings retain the primitive presentation.
- Four physical flippers with authored lengths and a short, edge-triggered launch window. Bottom paddles leave a genuine drain gap. Middle layouts offer side-mounted, staggered and shorter traditional recovery arrangements. Holding a flipper keeps it raised; it does not repeatedly award launch impulses.
- Rings award 25 points; bumpers award 100. Clearing all rings awards 500 and restores the ring rack after one second.
- Rings contribute five special-meter points and bumpers two, scaled by the profile. Meter caps at 100; specials remain future work.
- Rings stay at their authored positions until the configurable magnetic radius claims them. Score and meter update immediately; their visuals accelerate toward the moving ball over 0.20 seconds. Collection checks the ball's swept path and never alters ball momentum.
- Automatic drain recovery, a fixed serve, two test profiles, an example Chao modifier, and live tuning.

## Runtime structure

`scenes/playground.tscn` is the entry scene. Its controller builds this small runtime tree from resources:

```text
PhysicsPlayground                         scripts/game.gd
├── PhysicsTuning                         base profile + overrides + modifiers
├── InputRouter                           named input actions / virtual-input seam
├── PhysicsWorld (Node2D)
│   ├── Section_0 / Section_1 / Section_2  ordered top, middle, bottom collision sections
│   ├── PlayerPhysics (RigidBody2D)        invisible circle, radius 14 px
│   └── FourFlippers (AnimatableBody2D)    resource placements, shared left/right actions
├── Rings                                 stationary pickups and swept collection
├── TableView / Collisionless3DViewport
│   └── Presentation                      camera, lights, meshes, debug geometry
└── DebugAndHUD (CanvasLayer)              live tuning, telemetry, score, pause
```

Authoritative legacy layouts are in `data/chunks/*.tres`, `data/middle_chunks/*.tres` and `data/lower_chunk.tres`. Optional grid layouts live only in `data/grid_chunks/*.tres`; `GridChunkCompiler` creates their runtime geometry from `GridPieceKit`. `scripts/table_generator.gd` returns ordered chunks, junctions and their combined bounds after validation. `scripts/connector_transitions.gd` shapes Normal's adjoining wall collars on private resource copies; the resulting descriptors drive both 2D collisions and 3D meshes. `data/upper_chunk.tres` remains the fallback top and original physics-test fixture. Character defaults are in `data/balanced.tres` and `data/floaty.tres`. The example modifier is `data/practice_chao.tres`.

Physics lives in `scripts/ball.gd`, `scripts/flipper.gd`, and `scripts/table_chunk.gd`. `scripts/ring_field.gd` owns collectibles. `scripts/game.gd` handles score, meter, drain/serve, and signal wiring. Rendering is isolated in `scripts/presentation.gd`. Future models can replace `ball_visual` and listen to existing bumper/flipper signals without changing collisions.

### Coordinate mapping

The current course is 800 × 2100 physics pixels, derived from its three footprints. Positive 2D Y points down the table. One physics pixel is 0.01 3D world units:

```text
3D position = (physics_x × 0.01, visual_height, physics_y × 0.01)
```

All geometry and gameplay visuals use `TablePresentation.map_point()`. Height is cosmetic. No `CollisionObject3D` exists in the presentation tree. Flipper visual rotation is the negative of the physical angle around the 3D Y axis. Camera projection never changes gameplay geometry or its scale.

### Follow camera and overview

Use **Follow ball** in the Live Physics Lab to compare tracking with a fixed full-course overview. **Camera** retains three projection presets, including while paused:

| Preset | Projection | Elevation above the board | Vertical FOV |
| --- | --- | --- | --- |
| Top-down reference | Orthographic | 90° | Not applicable |
| Real Pinball (default) | Perspective | 60° | 40° |
| Dramatic Pinball | Perspective | 50° | 52° |

Perspective views look along the table from its positive-Z/front end. Overview distance or orthographic size fits the full generated bounds and raised-object envelope. Follow mode fits a 1100-pixel local window, keeps rotation/projection fixed, and translates smoothly. Vertical tracking has a dead zone and constant upward look-ahead. Horizontal tracking responds to 18% of the ball's offset from the course center, capped at ±55 px. Exponential damping and a movement-speed limit soften rebounds; a 50 ms update cap prevents a long frame from producing a large camera jump. Only explicit reset/mode/preset changes snap to the new view.

Expand **Camera follow tuning** in the lab's scroll area to edit vertical dead zone (100 px), upward look-ahead (100 px), vertical response (5/s), horizontal response (2/s) and movement cap (1800 px/s). Higher response follows sooner; a larger dead zone tolerates more movement before tracking. Bounds keep the bottom paddles and upper cap available. Pause freezes following. Reset returns the view to the bottom; regeneration preserves the preset, follow toggle and tuning, then resets its tracking state. Settings last for this session. The left panel shows the current chunk and camera target; scroll its layout details for each junction.

Real Pinball is the recommended starting point. Dramatic increases height parallax and occlusion; overview makes the ball smaller but helps inspect the whole course. No camera parameter writes to the physics ball, scales gameplay geometry or changes its velocity.

Circular bumpers have beveled cylinder tops, triangular bumpers are solid prisms, and rails/flippers extrude their exact capsule footprints with smaller inset top trim. Sides and tops use distinct simple materials. The floor surface is at visual Y = 0, above a 0.32-unit slab. Rails are 0.325 units tall, circular bumpers 0.42, triangular bumpers 0.34, and paddles 0.265 (0.285 at the pivot cap). The ball keeps its 0.14-unit radius and 0.16-unit center height; rings sit at 0.23. Bumper hit pulses change only visual height.

One directional light casts real shadows from the ball, bumpers, rings and rails onto the board. Ambient light preserves readability, and 4× MSAA smooths small primitive edges. No textures, custom shaders, post-processing or 3D collision shapes are used. The floor and flat grid markings receive shadows without casting their own.

**Physics** shows green X-ray collider footprints on the board plane, including moving flippers and the ball. **Chunks** and **Connectors** retain their independent overlays. Raised tops naturally project away from these ground footprints in perspective; this is height parallax, not a collision offset. Debug lines do not cast shadows. The pause notice stays above the table so it cannot hide the connection being inspected.

For follow/overview screenshots, run `tests/vertical_camera_smoke.gd` graphically. `tests/presentation_smoke.gd` retains the earlier two-section depth fixture. Captures go to ignored `test-results/`; see [verification and visual limits](docs/VERIFICATION.md).

### Chunk contract

`ChunkData` stores an ID, grid position and dimensions (100 pixels per cell), top/bottom connection rectangles, rail polylines, bumpers, rings, markers, flipper placements, visual attachment metadata, a navigable footprint, and route probes. Top/middle sections are 7 × 7 or 8 × 7 cells; the fixed bottom deck is 8 × 7. Full-width sections stay aligned; narrower sections retain both horizontal shifts. Sections occupy rows 0, 7 and 14. The original capped upper resources are never used as middle sections.

Horizontal mirroring and cell shifts apply consistently to collision descriptors, connectors, objects, markers, and debug bounds through `ChunkData.world_point()` / `world_rect()`. There is no rotation field. Compatibility uses overlapping opening spans at the same world boundary, never connector IDs. Unused opening spans receive capsule rails; the shared passage remains open. A coarse static reachability check rejects obvious disconnected routes. See [Generation contract and limits](docs/GENERATION.md).

Visual attachment metadata is a future theme hook. The current renderer uses primitive materials; it does not load themed assets.

### Generate a table

Use the **Table Generator** panel on the left. At serve, or after pausing with **Escape / Menu**, enter a seed, choose an **Easy / Normal / Hard** preference, and click **Build seed + preference**. **Next seed** increments the current seed using the selected preference. **Repeat current layout** restores the current seed and preference even if controls contain unbuilt edits. Different configurations can select the same layout. Generation resets the ball to serve, score, rings, meter, timers, and ball count, while preserving physics tuning, the Chao toggle, overlays, camera preset, and pause state. Resume if paused, then press **Enter / X** to launch.

For generator **v8**, compare **18 + Normal** (two straight banks, estimate 46), **23 + Normal** (upper faceted curve and staggered recovery, 55), **1 + Normal** (upper bank and side recovery, 55), and **5 + Normal** (two curves, 55). **8 + Normal** retains the shorter traditional recovery pair; both grid modes on seed 8 demonstrate curved joins around the editable construction recipes. **1 + Easy** and **1 + Hard** retain their contrasting geometry. Version 8 intentionally changes Normal mappings and estimates; Easy/Hard retain their prior selection. The panel and log record ordered chunks, transforms, requested transition and actual junction styles. Scroll the left panel for checked widths, largest ledges and estimates; hover the summary for bank grades. **Chunks** and **Connectors** have independent overlays. F1 hides both development panels. Settings are not saved across restarts.

Difficulty is a rough geometry preference, not a physics mode or safety override. Easy opens recovery space; Normal favors momentum and banks while preserving authored interior corners; Hard uses large shoulders and narrow, sometimes sideways-bending necks that reject imprecise upward shots. Normal prefers Bank for seed remainders 0–3 and Curve for 4–7, trying the other style and other compatible candidates when needed. It never falls back to a stepped ceiling. Ordinary banks redirect momentum through existing wall collisions without a powered impulse. The hardest component across every chunk and junction, including actual generated bank inclination, sets the finished course estimate. An unavailable band explicitly reports the closest valid flowing alternative. See [difficulty scoring and limits](docs/GENERATION.md).

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

The magnetic radius is an immediate collection distance, similar to an electric shield. Rings remain fixed until claimed, then their collisionless 3D visuals fly toward the moving ball. Every physics tick checks the closest point on the ball's previous-to-current position segment, so a fast pass can collect a nearby ring even when both tick endpoints are outside its radius.

Direct contact retains its existing 26-pixel center-distance threshold (14-pixel ball radius plus 12-pixel ring allowance), including swept contact at high speeds. The effective pickup radius is the larger of that contact threshold and the configured magnet radius. `RingField` deactivates each ring before notifying presentation and scoring, preventing duplicate awards until a new rack resets it. Score, ring total, meter, and rack bonuses never wait for the animation. Waiting at serve does not collect rings. The unused attraction-speed stat is already removed; radius remains in the centralized profile/modifier schema and Live Physics Lab for future Chao upgrades.

`TablePresentation` owns the cosmetic flight: a provisional **0.20-second quadratic ease-in** from the authored ring position toward the ball's current visible position, with a small scale-down during the final 30%. Multiple rings animate independently and remain claimed even if the ball leaves range or the radius changes. `RING_PICKUP_DURATION` is presentation tuning, separate from character physics. Pause freezes flights. Drain/reset cancels unfinished visuals while retaining earned rewards; a new rack restores position and scale, and table regeneration frees the old presentation and its signal listeners. Neither collection nor animation changes ball movement or creates 3D collision objects.

### Steering strength and the provisional default

Both test profiles now start with **Quick / Tight**, selected after playtesting. At full stick, `2200 × 0.10 = 220 px/s²` of normal assistance accumulates toward a separate ±120 px/s contribution limit. Counter-steering uses `4000 × 0.10 = 400 px/s²`; release removes assistance at `3000 × 0.10 = 300 px/s²`. Original remains selectable with strength 0.065, acceleration/counter 1000, and release 1400. Analog magnitude scales the target contribution; the action deadzone is 0.18. Strength is a multiplier on configured acceleration, **not** a percentage of the ball's velocity or trajectory.

Each tick applies only the change in steering contribution as an impulse. Existing horizontal and vertical momentum remains intact. Collision contact clears the bookkeeping contribution without applying a cancelling impulse: the rebound becomes physical momentum. Therefore the contribution budget is per free-flight interval; sustained rail contact can continue receiving bounded steering acceleration. This is intentional and should be judged in playtesting.

Counter-steering has an independent rate, used when the commanded correction opposes total horizontal velocity. The **Steering** dropdown retains Original, Quick/tight, Air control, and Stronger brake presets. The readout exposes raw/routed input, horizontal velocity, actual steering acceleration/impulse, contribution/target, saturation, blockers, and collision resets. Phase 2A changes only the profile defaults; steering and release behavior are unchanged. See [Steering investigation](docs/STEERING_INVESTIGATION.md) for the trace and limitations, including why release unwinds temporary braking.

There is no global speed clamp. The downward limiter removes only excess downward velocity using an impulse. Rolling assistance applies along supporting contact tangents; its speed cutoff never clamps overall velocity. Air drag is zero. Full velocity replacement occurs only for deliberate reset/serve operations inside `_integrate_forces()`.

### Collision reliability and flippers

The ball uses shape CCD, thick capsule rails, 120 Hz physics, and contact reporting. Testing this Godot build found native CCD missed some fast rail impacts. A supplemental [`PhysicsServer2D.body_test_motion()`](https://docs.godotengine.org/en/stable/classes/class_physicsserver2d.html#class-physicsserver2d-method-body-test-motion) sweep checks actual 2D shapes when travel exceeds half the ball radius per tick. It applies a normal rebound impulse conservatively, at most one physics tick before contact. This avoids tunneling in the tested cases without introducing 3D collisions or a global velocity cap. Extreme speeds may show an early rebound; test new layouts and engine versions.

Flippers rotate at 12 rad/s upward and 7 rad/s on release. A press opens a 0.11-second strike window, applies at most one boost to a nearby ball, and scales it by contact leverage. The normal moving-body response remains active. The launch-strength stat controls the extra boost, not total post-collision speed. This makes tuning explicit while keeping passive physical contact.

### Drain and recovery geometry

Flipper placements carry an optional pivot-to-tip `length`; omitted values retain the original 150 px default. Collision capsules, mesh bodies, visual tips, launch leverage and connector swing checks use the same instance length. Radius remains 13 px; input, angular speed, strike window and launch-strength formulas are unchanged.

| Section | Local pivots | Lengths | Arrangement |
| --- | --- | --- | --- |
| Launch Deck | (235,560), (565,560) | 130 / 130 px | Familiar bottom pair with an open drain |
| Open Relay | (135,550), (665,550) | 115 / 115 px | Side recovery and broad central passage |
| Bank Relay | (175,500), (615,590) | 125 / 115 px | Staggered recovery at different heights |
| Rebound Relay | (185,560), (545,560) | 110 / 110 px | Shorter, slightly offset traditional pair with a narrower central route |

The old bottom paddles left only 19.23 px between their resting capsule tips, blocking the 28 px ball. The revised pair leaves 57.20 px at rest and at least 44 px throughout the swing. Failed shots can now fall through; unlimited automatic respawn/relaunch is unchanged. The minimum horizontal surface corridors for Open, Bank and Rebound are respectively 274, 174 and 114 px. Mirroring transforms placements and left/right input sides without changing length. Normal 8's Rebound passage admits both its x350 chunk center and the x400 lower-deck centerline.

Holding a bottom paddle raised can still cradle a ball against the incoming wall near its pivot. Releasing clears that cradle. The existing 9 px assisted-strike margin can catch a near-tip shot during a press even when the capsule itself would clear it; this behavior is unchanged. No nudges, position corrections, automatic rescue flips or new ball forces are used to open a route. See [actual failure/recovery checks](docs/VERIFICATION.md).

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
& 'C:\Program Files\Godot\Godot.exe' --headless --path 'E:\Sonic Spinball Runners' --fixed-fps 120 --script res://tests/vertical_traversal_regression.gd
& 'C:\Program Files\Godot\Godot.exe' --headless --path 'E:\Sonic Spinball Runners' --fixed-fps 120 --script res://tests/vertical_shot_survey.gd
& 'C:\Program Files\Godot\Godot.exe' --headless --path 'E:\Sonic Spinball Runners' --fixed-fps 120 --script res://tests/connector_transition_regression.gd
& 'C:\Program Files\Godot\Godot.exe' --headless --path 'E:\Sonic Spinball Runners' --fixed-fps 120 --script res://tests/flipper_recovery_regression.gd
& 'C:\Program Files\Godot\Godot.exe' --path 'E:\Sonic Spinball Runners' --script res://tests/vertical_camera_smoke.gd
& 'C:\Program Files\Godot\Godot.exe' --path 'E:\Sonic Spinball Runners' --script res://tests/generation_ui_smoke.gd
```

The regression scripts use Godot directly, with no testing dependency. `tests/profile_regression.gd` protects resource resolution and reset behavior. `tests/physics_regression.gd` exercises real physics, both flippers, high-speed rail and bumper impacts, chunk crossings, scoring, collection, pause, live tuning, drain recovery, and 20 seconds of simulated play. See `docs/VERIFICATION.md` for results and practical limits.

`tests/vertical_traversal_regression.gd` checks seeded three-section courses, both junctions, four paddles, pause/reset/drain and regeneration cleanup. `tests/vertical_shot_survey.gd` exercises actual flipper shots and continuous upward/downward play. `tests/vertical_camera_smoke.gd` checks tracking and captures follow/overview views. `tests/generation_regression.gd` retains the v3 two-section geometry fixtures through `generate_pair()`; `tests/generation_ui_smoke.gd` exercises current three-section controls. Capture scripts create the ignored `test-results/` directory when needed.

`tests/flipper_access_survey.gd` remains the earlier two-section diagnostic with the original 150 px paddles; use the vertical and flipper-recovery diagnostics for current resource-authored geometry. Its optional diagnostic targets and recorded shot results are sandbox evidence, not win conditions or player success rates. Static connectivity and sampled trajectories cannot prove every shot, profile or modifier combination is playable.

Use **Physics** for collision outlines, **Chunks** for transformed section bounds, and **Connectors** for opening rectangles (purple) plus the checked clear passage (green). Outlines are raised slightly above the board for readability; their X/Z footprint derives from gameplay coordinates.

Before expanding the generator, manually evaluate controller feel, launch timing, rail shoulders, lane accessibility, and modifier extremes across the sample seeds. Static connectivity and short simulations cannot prove every trajectory is playable. Character abilities, drafting, touch controls, endless tables, network services, and exports remain outside this milestone.
