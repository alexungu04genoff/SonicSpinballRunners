# Sonic Spinball Runners — Vertical Traversal Playground

**Current presentation (2026-10-24):** Sonic, Tails, Knuckles and Shadow always remain in their character-colored ball form, including jumps, impacts, specials and character study. State transitions, special effects and authoritative 2D gameplay remain intact. Local character models are not loaded; the existing Blender pipeline and pose hooks are retained for later work with a 3D modeler. Older model previews and verification records below describe the previous presentation.

A local Godot 4/GDScript pinball prototype. Gameplay uses an invisible 2D rigid body and 2D collision geometry. Three connected sections form a tall course; a separate, collisionless 3D scene renders raised primitives with a smooth following perspective camera or fixed overview. No external artwork or dependencies are required.

Free Play remains the default endless experimental physics playground. Optional Score Attack adds a single-table objective: earn points, unlock an upper goal, then physically reach it. Optional **Green Hill Zone** adds the first three-Act loop: nine connected chunks, separate score challenges, checkpoints and Chao rewards. There are no lives limits, bosses, permanent unlocks or second Zone. The ball number counts attempts.

## Manual Act geometry editor

Double-click **Act Geometry Editor.cmd**, or run `scenes/act_geometry_editor.tscn` with **F6**. This isolated editor provides a 12×12 Act canvas, 77 terrain stamps, green bottom Entry/top Exit spans and a separate Gameplay palette for round/triangle bumpers and left/right flippers. Terrain keeps grid anchors, quarter-turns and mirrors. Gameplay anchors snap by default; hold **Alt** for exact free position, use **R / Shift+R** for 15° turns or enter an exact angle. Object placement, moves, rotation, handedness, deletion and duplication join undo/redo and persistent `.tres` saves. Format-2 terrain/connector files still load; new saves use format 3. Choose **Example** for an editable sample. See [Act Geometry Editor](docs/ACT_GEOMETRY_EDITOR.md) for controls and format details. The authored Acts are not yet playable; the generator and default scene are unchanged.

## Play Green Hill

Double-click **Play Green Hill.cmd** to play the themed version. **Physics Playground.cmd** opens the original debug presentation. Green Hill is integrated on `main` and includes the shared generator v10, 50 px kit with rounded Easy recipes, Normal-flow connections, five flippers, ring collection, unlimited drain recovery and optional Score Attack. Its mode/target strip remains available with the tuning panel hidden, and the shared upper goal and victory/replay controls use the same rules as the physics playground. Third-party Sonic assets remain local and ignored; a procedural spin-ball works without them.

Use **Enter** to launch, **Q/E** to flip, **Escape** to pause, **O** for overview and **F1** for tuning/seeds. The footer supplies Normal seeds 18/23 and both grid variants. Grid shortcuts preserve the active seed and difficulty, which the footer displays. Build while paused or at serve. See [Green Hill launch, assets and verification](experiments/visual_lab/README.md).

## Run the physics playground

Open `project.godot` in Godot 4 and press **F6** from `scenes/playground.tscn`, or **F5** to run the project. The prototype was tested with **Godot 4.7.2** on Windows, using the Compatibility renderer.

For this machine, PowerShell can launch it with:

```powershell
& 'C:\Program Files\Godot\Godot.exe' --path 'E:\Sonic Spinball Runners'
```

The ball starts on the bottom launch deck. Press **Enter** or gamepad **X** to launch. Time the middle flippers to gain height into the top section; its short paddle offers another recovery shot. All left paddles share Q/LB; all right paddles share E/RB. Falling between sections is normal. Draining automatically respawns and relaunches at the bottom, without checkpoints or a lives limit.

| Action | Keyboard | Windows gamepad |
| --- | --- | --- |
| Left flipper | Q | LB |
| Right flipper | E | RB |
| Horizontal steering | Left/right arrows | Left analog stick |
| Launch | Enter | X |
| Reset and relaunch | R | Back/View |
| Pause/resume | Escape | Menu/Start |
| Character special when READY | Space | A |
| Toggle tuning panel | F1 | — |

Both flippers can be held simultaneously. Special input currently displays a status message; it does not consume the meter or execute an ability.

## What is playable

- **Green Hill Zone:** choose **Green Hill Zone** in the shared mode selector, then **Start / replay** at serve or while paused. This works in **Play Green Hill.cmd** and **Physics Playground.cmd**. Start with seed **18** for a verified route. All three Acts use Easy geometry, regardless of the sandbox difficulty setting. Existing catalogue mixes broad relays and rounded grid recipes; Grid base/variant use their corresponding Easy relays. Generation validates all nine chunks before replacing the table; allow several seconds for this larger build.

  Earn **750 / 1,250 / 1,750 new points** in Acts 1 / 2 / 3. Each threshold opens that Act's exit; earlier points remain in Total Run Score but cannot unlock the next Act. Cross each open boundary, choose a Chao, and continue from the same position and velocity. The final portal requires Act 3's own target, then awards a final Chao before **GREEN HILL ZONE COMPLETE!**. Its replay starts the same geometry with empty scores and build.

  Completed boundaries latch behind the ball. Falling back toward one triggers a checkpoint drain and automatic serve inside the current Act. Retries retain total score, Act score and rewards; active-Act rings refresh on a drain/reset or rack clear. Only active-Act rings and bumpers score. No completed Act must be replayed. The follow camera spans all nine sections; **O** in Green Hill or the debug follow toggle gives an overview.

  Each reward offers Ice, Spring and Magnet, with effective-stat comparisons. Picks combine through the same resolver: **maximum two copies per species, five slots**, with existing stat clamps. This prototype awards three picks from a fixed pool. Zone mode starts without a Chao, disables the single-slot Lab/Practice toggle, and restores your earlier sandbox Chao when leaving. No random drafting, rarity, shops or permanent persistence.

- **Chao Lab v0:** open **Chao: … · Lab** beside Start / replay, at serve or while paused. Compare Ice, Spring and Magnet, then **Equip + replay same seed**. This uses the mode/target selected above and resets score, rings and ball; **None** provides a baseline. The equipped name stays visible during play. See [Chao tuning and lifecycle](#chao-lab-v0).

- **Score Attack:** select it in the strip below the score, set a target, and press **Start / replay** while at serve or paused. Launch normally. The provisional default is **1,500 points** (for example, ten bumpers and twenty rings). At the threshold, the amber upper goal turns green. Touch its ring with the ball to win; points alone never complete the run. The victory panel offers **Replay same seed**, **Next table**, and **Free Play**. Starting/replaying clears score, rings and timers, while preserving physics tuning, difficulty and construction mode. Drains and R/ball reset preserve earned progress; use Start / replay for a fresh challenge. Paused builds stay paused; replaying a victory resumes at serve. Mode controls remain visible with F1.

- A fixed bottom deck, three reusable middle layouts with two openings, and eight upper layouts, selected by a reproducible seed and difficulty preference with optional mirroring and horizontal shifting.
- An optional 50 px construction-grid experiment: choose **Grid base** or **Grid variant** in Table Generator, then build while paused or at serve. **Easy** uses wider recipes with gentle banks; Normal/Hard retain the original recipes. Enable **Construction grid** for local coordinates and piece footprints. **Existing catalogue** keeps the original levels available. See [grid authoring and variants](docs/GRID_AUTHORING.md).
- Wide aligned Easy sections, flowing Normal gardens/return lanes/target routes, and Hard tapered or offset necks. Joins meet at physics `y = 700` and `y = 1400`. Normal requires aligned joins, passive banks or faceted curves at both junctions; authored interior corners remain.
- Open, gently banked and asymmetric rebound middle sections, each with two bumpers and recovery paddles. Segmented rails, circular/triangular bumpers and collectible rings retain the primitive presentation.
- Five physical flippers with authored lengths and a short, edge-triggered launch window. Bottom paddles leave a genuine drain gap. Middle paddles sit near the side walls with space for the ball to pass behind them; layouts retain different heights and lengths. Each upper section adds one short 70–85 px recovery paddle, mirrored with its chunk. Holding a flipper keeps it raised; it does not repeatedly award launch impulses.
- Rings have a 25-point base; bumpers have a 100-point base. Scorecraft applies the active combo to eligible awards. Clearing all rings awards a fixed 500 and restores the ring rack after one second.
- Rings contribute five special-meter points and bumpers two, scaled by the profile. Meter caps at 100; Character Lab specials spend 100 on a valid activation.
- Rings stay at their authored positions until the configurable magnetic radius claims them. Score and meter update immediately; their visuals accelerate toward the moving ball over 0.20 seconds. Collection checks the ball's swept path and never alters ball momentum.
- Automatic drain recovery, a fixed serve, two test profiles, one equipped Chao and live tuning.

## Scorecraft v1

Combos are enabled in Free Play, Score Attack and Green Hill Zone. Hit a bumper to start a **3-second** chain at ×1. Each different bumper advances a link and refreshes the window. After each fresh bumper, collecting **three rings** earns one additional link and refreshes the window. Partial ring sequences do not refresh it; a new bumper starts a new three-ring count.

The second link earns **×2**. **×3 requires at least three links including a completed ring sequence**: bumper-only chains stop at ×2. Further links remain capped at ×3. A bumper can advance only once in the entire active chain; repeat hits pay 100, cannot refresh the timer and cannot rearm the ring sequence. Extra rings earn the current multiplier but cannot sustain it after that bumper's ring link is used. Rack clears remain a fixed 500.

Sonic's successful Homing hit pays **100 × eligible combo multiplier + 400**, then ends the chain. Thus a fresh-target ×3 finisher pays **700**, never 1,500. An unchained or repeated-target Homing hit still pays 500. Tails earns the same combo awards through ordinary physical interactions during flight; neither flight nor Chao gives a separate scoring multiplier. Meter charge remains unchanged.

The character HUD shows links, multiplier, time remaining, the next useful action and the latest award. To compare baseline scoring, pause or wait at serve and switch **Scorecraft combos**. This starts a fresh run of the same seed with the currently equipped character and existing replay rules. Baseline scoring restores 100/25/500 and Homing's 500. Ordinary replay retains the comparison setting. Pause and Chao drafts freeze combo timers; inactivity, drain, ball reset, character changes, Act advancement and new runs clear the chain. Earned run/Act scores still follow their existing retention rules.

Provisional window, ring count and cap live in `data/scorecraft.tres`. `Scorecraft` calculates awards from existing callbacks; `game.gd` still owns the total. Art hooks on `game.scorecraft`: `combo_changed(chain, multiplier)`, `combo_ended(reason, chain, multiplier)` and `score_awarded(details)`. The award payload includes `kind`, `base`, `multiplier`, `special_bonus`, `total`, `chain`, `fresh_bumper` and `target_id`. Signals fire during calculation, **before the root adds the award to its total**; use the payload for popups. A Homing award emits before its combo-end signal. No presentation callback may award points.

Run `tests/scorecraft_regression.gd` for formula/contact/lifecycle checks. `tests/scorecraft_play_survey.gd -- --seconds=120` compares four input policies on seed 18; `--mode=2 --case=1 --route --seconds=240` measures all three Act unlocks. See [measured results and limits](docs/VERIFICATION.md).

## Playfield design: roll-in serves and Act funnels

Sonic and Tails wait at a marked side serve. **Enter / gamepad X releases the ball into normal gravity**, feeding it down the sloping wall toward the recovery flippers. The flippers provide the first upward shot. There is no launch cup, spring obstruction or preset launch velocity. This follows the playtest preference for a simple roll-in. Automatic retries use the same serve in the current Act; manual reset can leave the ball waiting there.

Every Act has a sloped funnel, two recovery flippers and a real central 2D drain sensor. A fast downward pass uses a swept sensor check. Score, current Act progress and Chao survive; the existing combo and temporary-special resets still happen on a drain. The global out-of-bounds recovery remains a safety net.

Future checkpoint funnels and their flippers are retracted, shown as thin floor guides, so an unlocked entrance does not become a ceiling. Cross the score gate and climb above the generated safe-entry line to finish the Act. A weak attempt can fall back before that line. After the draft, the next funnel activates and the previous gate seals behind it. Entered Acts remain checkpoints; there is no return to completed Acts or transition teleport.

Zone generator v2 draws five distinct relay rooms from **eight authored Easy archetypes**: Wall Garden, Sling Alley, Orbit Cluster, Bank Return, Staggered Steps, Winding Lane, Twin Banks and Crosscourt. Two checkpoint decks, the bottom funnel and one final cap complete the nine-chunk layout. The shared 50px kit adds mounted circles, three circle sizes, triangular wall slings and rounded banks. Ring patterns, paddle positions, mirroring and safe horizontal shifts follow each authored room's purpose. Grid base and variant now shuffle the full Zone library instead of repeating one room. Free Play and Score Attack keep their existing three-section catalogues, with the shared roll-in serve and lower drain refinement.

Green Hill's official difficulty remains **Easy**. For development, open **F1**, select **Zone difficulty: DEV Normal / DEV Hard**, then build or start a Zone. The override changes the complete generated course, is labelled in the HUD, and persists on replay. Invalid candidates report failure and preserve the current run; Zone generation never substitutes Easy for a requested development tier. Select **Official Easy** to return to the official rules. Sandbox difficulty remains separate.

**Zone generator v5: composed Normal and Hard Acts.** Each development tier has six dedicated rooms: three interaction chambers and three exit approaches. Every Act combines its recovery funnel, one distinct interaction chamber and a compatible approach (the final Act uses the capped objective room). Wide target gardens, banked returns, narrow bonus routes and asymmetric pockets replace repeated corridor recipes. Mirroring stays consistent within each Act. Rooms deliberately use zero, one or two paddles; 80px precision paddles complement the unchanged primary recovery pair. Authored paddle roles, scoring targets and optional `wall_mount` metadata are available in `world_flippers()` for debug/presentation adapters.

The focused recovery pass adds passive feed shoulders to Normal Target Garden, removes Hard Bank Vault's redundant right paddle, and lowers Offset Climb's short catch by 50px onto its opposing-bank return. Other reviewed paddles remain because upstream gravity drops demonstrated useful scoring or climbing shots. The shared aiming rules below make contact position and press timing matter in every mode; this does not add new room types or change the primary drain geometry.

Target Garden's perimeter flippers now separate upward progress from optional scoring. Both pivots move 50px outward toward the existing walls, with compact 18px bearings. The source-right paddle follows diagonal rings through the upper opening; an earlier strike can attack the large bumper, moved 50px outward from that climbing route. The left paddle retains a short ring trail into the small target cluster. Seed 28 mirrors the room, so its progression paddle appears on screen left. Press timing and contact-based aiming determine the actual shot; authored `shot_kind` metadata only describes intent and selects the regression criterion. No target applies steering or forces.

Kit v5 adds `mounted_` flipper pieces whose `flipper_mount` descriptor drives passive 2D collision, route validation and 3D rendering. The sealed hinge has no rear ball lane; the whole capsule still clears its wall, and full ball passage is checked beyond the first 60px. The assembly cannot score or become a Homing target. This layout pass changes only Target Garden. Current gameplay-camera screenshots and controlled-drop input demonstrations are in `test-results/target-garden-routes-review/`; earlier perimeter and wedge captures remain in their separate review folders. See [verification](docs/VERIFICATION.md) for measured outcomes and human playtest limits.

Normal uses flowing Curve joins. Hard uses longer Bank joins, with the same maximum slope and collision-clearance checks; difficulty comes from authored room targets and useful shot widths instead of universal Step seams. The existing worst-case difficulty estimate remains visible. Additional composition checks require matching room difficulty in every Act, five distinct relay IDs, varied silhouettes, and measured interior precision lanes in every Hard Act. Complete object/paddle clearance is checked again after connector shaping. These are selection heuristics, not proof of human difficulty or fun.

In Zone, the construction selector now reads **Layout shuffle A / B / C**: each uses the full room library with a different deterministic shuffle. Free Play and Score Attack retain their catalogue / Grid base / Grid variant meanings and existing geometry. The Zone HUD shows each Act's interaction-room identity. For review, compare Normal seeds **18 / 28 / 41** and Hard **24 / 29 / 41**; Hard 18 is a useful near-repeat of 24, mainly changing an Act's mirror. See [verification](docs/VERIFICATION.md) for actual trajectories, completion limits and screenshots.

All rails, bumpers, slings and flippers come from shared 2D descriptors. `checkpoint_only` marks retractable geometry; its collision state and each flipper's `enabled` state also drive placeholder visuals. `PlayfieldDrain` owns the bounded sensor; `ZoneRun` owns progress. `PlaygroundBall.launch_started` and `launched(impulse)` report serve release; the latter currently carries `Vector2.ZERO`, because gravity supplies the motion. Presentation cannot change ball motion.

## Character Lab — four playable characters

Select **Sonic · Homing**, **Tails · Flight**, **Knuckles · Glide** or **Shadow · Blast** beside the mode selector, then **Start / replay** at serve or while paused. This starts the same seed with the selected character's starting profile. Ordinary replay retains live tuning; changing characters restores their starting profile. Sandbox Chao remain equipped. A fresh Zone starts its existing empty draft build. All four profiles are also available in F1 for comparison.

- **Sonic — Homing Attack:** Balanced starting physics. At READY, Space / gamepad A aims a bounded impulse toward the nearest bumper within 400 px whose path is clear for the entire ball. Actual contact with the marked bumper within 0.65 seconds earns its **400-point special bonus** once, giving 500 baseline points or up to 700 with Scorecraft. No clear target or insufficient charge spends nothing. A wall can still stop a shot after activation. Gates, portals and exits are never targets. Choosing the moment matters: homing toward a lower bumper can sacrifice upward progress.
- **Tails — Tail Flight:** slightly lower gravity and more steering, with an orange spin-ball and a locally prepared flight model in Green Hill. Full meter buys **1.6 seconds** of reduced gravity and additional bounded steering. One upward impulse can rescue a fall; it does not continuously power ascent. Gravity/control fade back over the final 0.35 seconds. All ordinary collisions remain active.
- **Knuckles — Glide + Shockwave:** heavier gravity and stronger rebounds. Hold left/right and press Special; existing horizontal momentum can also choose the direction. A single bounded lateral impulse starts a **0.85-second** glide with extra steering trim and unchanged gravity. A real side-rail or bumper impact releases an upward **360px-wide, 500px-long** wave. Exposed eligible targets and rings pay **2× base value**. Walls block the wave; gates, paddles and housings cannot trigger it. A missed glide expires without a wave. Red prototype ball.
- **Shadow — Chaos Blast:** stronger counter-steering and softer wall rebounds favor positioning. Full meter instantly activates eligible bumpers and rings within **300px** of the physical ball, paying **1× base value**. Ordinary walls do not block the radial blast, but only the active Act is eligible. Gates, portals and other collision bodies never qualify. Black prototype ball with red accents.
- The character HUD shows the equipped character, ability description, charge, **READY**, and activation/hit feedback. A pending character choice is explicitly labelled for the next run. F1 exposes the effective shared physics stats.
- Unused charge persists through Acts, drains and ball resets; checkpoints never refill it. New runs/replay clear meter. Pause and Act drafts freeze flight time. Drain/reset, character changes and completed challenges clear temporary ability effects. Chao modifiers combine through the existing resolver, without duplicate temporary modifiers.

Area awards use Scorecraft's shared calculator at fixed base values; they neither advance nor refresh a combo and do not recharge their own meter. Existing combos continue to expire normally. A real Knuckles bumper impact receives its 2× award once and its ordinary physical +2 charge; the wave cannot award it again. Atomic ring claims retain immediate collection and cosmetic ring flight. Remote/contact bumper awards share a short deduplication window. The ordinary 500-point ring-rack bonus still applies. Earning enough points can unlock an exit, but every mode still requires its physical progression step.

The new mechanics are configurable in `CharacterDefinition` and `data/characters/`: full-meter costs by default, glide duration/speed/impulse cap, minimum impact speed, wave size/multiplier and blast radius. Safety ceilings are 400px wave width, 800px wave range and 600px blast radius. `PhysicsProfile` owns starting physics; keyed temporary glide modifiers combine with Chao. Pauses/drafts freeze glide time; advancing an Act clears glide and pending waves while retaining meter. Tails' existing paused-flight behavior across drafts is preserved.

Additional ArtBro hooks on `game.specials`: `glide_started(direction, duration)`, `glide_impact(body, position, normal)`, `glide_ended(reason)`, `area_started(source, origin, size)`, `area_target_activated(source, target, multiplier)`, `area_completed(source, targets, rings)` and `effects_cleared(reason)`. Coordinates use gameplay XY; wave size is width/range and blast size contains radius in both components. Impact ends the glide before emitting `glide_impact`; the wave then resolves outside the physics callback. Reset invalidates queued waves. Counts include remote awards only; the real impact contact is reported separately. No area event impersonates `ball.bumper_hit`. The existing meter events remain shared. Minimal collisionless outlines are replaceable in `AreaSpecialFeedback`.

Definitions and provisional tuning live in `data/characters/` and `data/tails.tres`. `CharacterSpecials` exposes `character_changed`, `special_activated`, `target_acquired`, `homing_started`, `homing_ended`, `special_hit`, `flight_started`, `flight_ended`, `meter_changed`, `meter_spent` and `meter_replenished`. Green Hill now consumes these hooks for Sonic's homing/impact poses and Tails' rotating-tail flight, with separate blue/orange spin-balls. Prepared models stay local and Git-ignored; visible fallbacks work without them. The original physics playground retains its lightweight `CharacterFeedback` placeholder. Tails bonus scoring and campaign expansion remain future work.

Presentation contract: bind to `game.specials` and initialize from its current `character_id`/`definition`; initial selection happens before presentation creation. The specials node persists while presentation is rebuilt. `homing_started(target, direction)` supplies a live bumper and a target-facing unit vector in gameplay XY, with `pending_target`, `homing_direction` and `homing_remaining` already set. `flight_started()` likewise exposes active `flight_remaining`; both ability-specific start signals precede meter spending, while `special_activated(id)` follows it. `homing_ended(reason)` fires once after clearing state, with `Hit`, `Expired`, `Act complete` or the reset reason (`Drain`, `Reset`, `New run`, `Character changed`, `Challenge complete`, `Zone complete`; direct cancellation defaults to `Cancelled`). A successful hit emits target loss, then `homing_ended("Hit")`, then `special_hit(target, multiplier)` before the root awards points. Preview `target_acquired(null)` alone is not a miss. `flight_ended(reason)` fires after clearing its temporary modifier; duration/fade come from `definition`. Pause/drafts freeze timers. Visuals must observe the authoritative ball and never apply gameplay movement. Replace/remove the fallback `CharacterFeedback` node when installing a combined Sonic/Tails presenter: it otherwise owns the orange placeholder and toggles `SonicVisualAdapter` visibility each frame.

Run `tests/character_lab_regression.gd` at `--fixed-fps 120` for controlled physics/lifecycle checks. `tests/character_play_survey.gd -- --seconds=180 --mode=2` compares the same seed using only ordinary inputs and earned meter. Mode 0 is Free Play; mode 1 is Score Attack. Add `--grid=1` or `--grid=2` for variants. See [verification and playtest limits](docs/VERIFICATION.md).

## Runtime structure

`scenes/playground.tscn` is the entry scene. Its controller builds this small runtime tree from resources:

```text
PhysicsPlayground                         scripts/game.gd
├── PhysicsTuning                         base profile + overrides + modifiers
├── InputRouter                           named input actions / virtual-input seam
├── PhysicsWorld (Node2D)
│   ├── Section_0 / Section_1 / Section_2  ordered top, middle, bottom collision sections
│   ├── PlayerPhysics (RigidBody2D)        invisible circle, radius 14 px
│   └── FiveFlippers (AnimatableBody2D)    resource placements, shared left/right actions
├── Rings                                 stationary pickups and swept collection
├── TableView / Collisionless3DViewport
│   └── Presentation                      camera, lights, meshes, debug geometry
└── DebugAndHUD (CanvasLayer)              live tuning, telemetry, score, pause
```

Authoritative legacy layouts are in `data/chunks/*.tres`, `data/middle_chunks/*.tres` and `data/lower_chunk.tres`. Optional grid layouts live only in `data/grid_chunks/*.tres`; `GridChunkCompiler` creates their runtime geometry from `GridPieceKit`. `scripts/table_generator.gd` returns ordered chunks, junctions and their combined bounds after validation. `scripts/connector_transitions.gd` shapes Normal's adjoining wall collars and Easy grid's small inset mismatch on private resource copies; the resulting descriptors drive both 2D collisions and 3D meshes. `data/upper_chunk.tres` remains the fallback top and original physics-test fixture. Character defaults are in `data/balanced.tres` and `data/floaty.tres`. The example modifier is `data/practice_chao.tres`.

Physics lives in `scripts/ball.gd`, `scripts/flipper.gd`, and `scripts/table_chunk.gd`. `scripts/ring_field.gd` owns collectibles. `scripts/game.gd` handles score, meter, drain/serve, and signal wiring. Rendering is isolated in `scripts/presentation.gd`. Future models can replace `ball_visual` and listen to existing bumper/flipper signals without changing collisions.

`scripts/score_attack.gd` observes that existing score and swept 2D ball contact; it does not award points or change collisions. Goal placement uses a clear authored target, navigation probe or ring anchor in the upper 45% of the transformed top chunk. The circle has a 55 px radius; contact includes the ball's 14 px radius. `scripts/score_attack_goal.gd` supplies the replaceable collisionless skin under Presentation, and `scripts/score_attack_panel.gd` supplies mode/victory UI. For themed art, use `game.score_attack.changed`, `.state`, `.target`, and `.goal_position`; keep detection and score in gameplay. No changes to the existing presentation script are required.

### Coordinate mapping

The sandbox course is 800 × 2100 physics pixels; the Zone is 800 × 6300. Both derive their bounds from generated footprints. Positive 2D Y points down the table. One physics pixel is 0.01 3D world units:

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

For generator **v10**, compare **18 + Normal** (two straight banks, estimate 46), **23 + Normal** (upper faceted curve and staggered recovery, 55), and **1 + Normal** (upper bank and side recovery, 55). **8 + Easy** in both grid modes demonstrates rounded banks, step-free seams and side-mounted paddles. **1 + Hard** retains its narrow offset neck. Record the generator version when sharing seeds because authored layout changes can alter trajectories and selection. The panel and log record ordered chunks, transforms, requested transition and actual junction styles. Scroll the left panel for checked widths, largest ledges and estimates; hover the summary for bank grades. **Chunks** and **Connectors** have independent overlays. F1 hides both development panels. Settings are not saved across restarts.

Difficulty is a rough geometry preference, not a physics mode or safety override. Easy opens recovery space; Normal favors momentum and banks while preserving authored interior corners; Hard uses large shoulders and narrow, sometimes sideways-bending necks that reject imprecise upward shots. Normal prefers Bank for seed remainders 0–3 and Curve for 4–7, trying the other style and other compatible candidates when needed. It never falls back to a stepped ceiling. Ordinary banks redirect momentum through existing wall collisions without a powered impulse. The hardest component across every chunk and junction, including actual generated bank inclination, sets the finished course estimate. An unavailable band explicitly reports the closest valid flowing alternative. See [difficulty scoring and limits](docs/GENERATION.md).

## Physics and live tuning

The simulation runs at 120 Hz with world gravity 700 px/s². Ball mass is one kilogram. All profile fields, labels, units, and allowed limits are centralized in `PhysicsProfile.FIELDS`.

The panel edits session values before modifiers. Its **Active values** section shows final effective values. Click a numeric field, enter a value, then press Enter to return keyboard control to the game. Gameplay keys are suppressed while editing a numeric field. Profile switching and **Restore profile defaults** clear session edits while preserving the equipped Chao. Ball reset preserves tuning, score, rings, and meter.

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

Flippers rotate at 12 rad/s upward and 7 rad/s on release. A press opens a maximum 0.11-second strike window, with at most two physics ticks of follow-through after the paddle reaches its raised angle. Releasing cancels the powered window. One above-face catch per press receives an impulse scaled by contact leverage and the shared resolved launch-strength stat. Passive moving-body collisions remain active, so the stat controls the extra boost rather than total post-collision speed.

The impulse direction combines the paddle's current surface orientation with contact position. Heel contacts aim farther across the table; tip contacts and later swing contacts aim more vertically. The provisional angle is bounded between 10.3 degrees outward and 31.5 degrees inward from vertical, with exact left/right mirroring. In controlled falling shots, heel versus tip changed the added impulse direction by about 16 degrees; changing press timing on the same fall changed it by about 6 degrees. No target snapping or velocity replacement is used. `shot_fired(contact_position, impulse, contact_fraction)` exposes the actual strike for presentation/debugging; existing `struck` listeners remain compatible.

### Drain and recovery geometry

Flipper placements carry an optional pivot-to-tip `length`; omitted values retain the original 150 px default. Collision capsules, mesh bodies, visual tips, launch leverage and connector swing checks use the same instance length. Radius remains 13 px. Input and angular speeds remain shared; the aiming and powered-window rules are described above.

| Section | Local pivots | Lengths | Arrangement |
| --- | --- | --- | --- |
| Launch Deck | (235,560), (565,560) | 130 / 130 px | Familiar bottom pair with an open drain |
| Open Relay | (125,550), (675,550) | 115 / 115 px | Side recovery and broad central passage |
| Bank Relay | (140,500), (675,590) | 125 / 115 px | Staggered side recovery at different heights |
| Rebound Relay | (125,560), (575,560) | 120 / 120 px | Side recovery with enough reach for the narrow upper necks |

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

Practice Chao applies ×1.25 steering acceleration and ×1.15 flipper launch strength. It occupies the same single slot as Chao Lab: enabling it replaces the current Chao; disabling it equips None. The debug toggle now starts a fresh run and is available only at serve or pause. Bounds include steering strength 0–0.3, acceleration 0–4000, flipper strength 200–2200, gravity 0.1–2.0, bumper multiplier 0.25–2.5, and restitution 0–0.95. All other limits are in the same schema and enforced by both resolver and panel.

### Chao Lab v0

These are provisional tuning values, implemented as `PhysicsModifier` resources in `data/chao/`. All resolve through the existing `PhysicsTuning` pipeline. The slot defaults to None; no inventory, rarity, drafting, persistence or campaign rules are introduced.

| Chao | Effect | Balanced / Quick-tight effective values |
| --- | --- | --- |
| Ice — Control | ×1.5 steering acceleration, ×1.75 counter-steering, ×1.25 steering contribution cap | Steering 220 → 330 px/s² after strength; counter-steering 400 → 700 px/s²; cap 120 → 150 px/s |
| Spring — Power | ×1.35 flipper launch strength | 1,050 → 1,417.5 px/s impulse per mass before leverage/contact response |
| Magnet — Collection | ×2 ring magnet radius | 50 → 100 px, immediate score and unchanged cosmetic flight |

The lab compares all three against your current unmodified profile/session settings and displays clamped effective values. Previewing a choice does not equip it; closing restores the prior pause state. Equipping rebuilds the same seed with the selected Free Play/Score Attack mode and target, clearing the run's counters and pending timers. A rejected build leaves the old loadout intact. Paused changes stay paused; victory replays resume at serve.

Ordinary replay, Next table, regeneration, ball reset and drains retain the equipped Chao. Profile changes/default restoration retain it too. Only one modifier enters the resolver, including the legacy Practice choice; repeated equip/rebuild never duplicates it. Gameplay physics never branches on a Chao name. `PhysicsTuning.equip_chao(id)` is the simple future selection hook; current UI changes go through validated fresh-run generation.

For comparison, build Normal seed 18, keep the same profile/tuning, and replay with None, Ice, Spring and Magnet. Actual 120 Hz probes show about 49% more half-second lateral travel with Ice and about 20–22% greater controlled launch height with Spring. Table collisions and timing make full-run results nonlinear; extra power does not guarantee a higher score or easier shot. See [verification and the short human checklist](docs/VERIFICATION.md).

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

`tests/vertical_traversal_regression.gd` checks seeded three-section courses, both junctions, five paddles, pause/reset/drain and regeneration cleanup. `tests/vertical_shot_survey.gd` exercises actual flipper shots and continuous upward/downward play. `tests/side_recovery_regression.gd` checks wall clearance, rounded Easy grid routes, mirrored upper recovery shots and Green Hill's difficulty-preserving shortcuts. `tests/vertical_camera_smoke.gd` checks tracking and captures follow/overview views. `tests/generation_regression.gd` retains the v3 two-section geometry fixtures through `generate_pair()`; `tests/generation_ui_smoke.gd` exercises current three-section controls. Capture scripts create the ignored `test-results/` directory when needed.

`tests/flipper_access_survey.gd` remains the earlier two-section diagnostic with the original 150 px paddles; use the vertical and flipper-recovery diagnostics for current resource-authored geometry. Its optional diagnostic targets and recorded shot results are sandbox evidence, not win conditions or player success rates. Static connectivity and sampled trajectories cannot prove every shot, profile or modifier combination is playable.

Use **Physics** for collision outlines, **Chunks** for transformed section bounds, and **Connectors** for opening rectangles (purple) plus the checked clear passage (green). Outlines are raised slightly above the board for readability; their X/Z footprint derives from gameplay coordinates.

Before expanding the generator, manually evaluate controller feel, launch timing, rail shoulders, lane accessibility, and modifier extremes across the sample seeds. Static connectivity and short simulations cannot prove every trajectory is playable. Character abilities, drafting, touch controls, endless tables, network services, and exports remain outside this milestone.
