# Physics Playground verification

Date: 2026-10-22. Engine: Godot 4.7.2 stable, Windows. Physics: 120 Hz. Graphical renderer: OpenGL Compatibility on NVIDIA GeForce RTX 4060.

## Vertical Traversal Playground (generator v4)

- `tests/vertical_traversal_regression.gd`: **25 checks passed**. Four seeds per tier generated twice reproduce ordered chunks, flippers and both junctions. Checks cover three sections, matching difficulty, a three-section fallback, all four paddles responding simultaneously, aligned physics/presentation, both-direction 1200 px/s seam shots, 8000 px/s closure impacts, pause, bottom reset/drain/respawn and safe regeneration. Old generated bodies, middle paddles, pickup visuals and listeners are removed; the bottom deck/paddles, Floaty profile, modifier, live steering edits, overlays and camera settings persist correctly.
- An independent catalogue audit tested all **224** top/middle transform combinations: **220 valid**, with 16 Easy, 144 Normal and 60 Hard estimates. Four combinations correctly fail the unchanged 300 px raw-overlap requirement. This is static validation, not exhaustive trajectory testing.
- `tests/vertical_shot_survey.gd`: **18 checks passed** after the serve correction below. Six configurations (seeds 1/2 in each tier) each received 24 shots from the bottom pair and 24 from the middle pair: **288 actual single-strike samples**, all finite. Contact distances 55/75/95/135 px and incoming horizontal velocities −200/0/+200 px/s sample real paddle presses with unchanged Balanced defaults. Every configuration has a bottom-to-middle and middle-to-top chamber witness. Bottom chamber arrivals were 2–3/24 and middle-to-top arrivals 4–17/24; these are diagnostics, not player success probabilities.
- All six survey configurations also completed **40 uninterrupted simulated seconds** from the ordinary bottom serve, reaching y450 in the top section and returning below y1450. Both paddle pairs struck; no teleport, velocity edit or automatic rescue occurred after serve. The script uses proximity-timed shared left/right input, not a gameplay auto-flipper feature. All three middle designs appear. Recorded inputs and witnesses are in ignored `test-results/vertical-shot-survey.json`.
- Graphical `tests/vertical_camera_smoke.gd`: **29 checks passed**. Full-course framing works in all three presets. Controlled 1400 px/s ascent and 1480 px/s descent stay visible at 60/120 Hz with monotonic, speed-limited movement and under 3 px final-focus difference. Checks cover dead zone, gentle horizontal response, abrupt-rebound observations, fixed rotation, pause, bottom reset, regeneration, ring-flight cleanup and all four paddle/ring/ball mappings. Seven screenshots were reviewed: three overviews, bottom/middle/top follow views and an overlay. They show readable local geometry, matched footprints, shadows and unclipped course ends.
- Graphical generation UI: **18 checks passed**, including scrollable ordered chunk/junction diagnostics and preserved camera selection. Earlier two-section fixtures also pass: **64 generation**, **26 graphical presentation**, **38 physics**, **12 steering**, **eight profile**, **11 ring**, **14 headless ring-presentation**, and **four steering-UI** checks. Total executed: **267 passing checks**, including image saves. Headless import completed without script errors.

Testing found a real reset issue: after a long teleport, native contact recovery could nudge the waiting ball about 1.63 px from the serve point. The serve-only integrator state now holds the reset transform and zero velocity until launch; the same respawn check now observes exactly `(665, 1820)`. Active-flight steering, gravity, flipper power and rebound forces are unchanged. Controlled shot fixtures use a fresh body for independent samples to avoid carrying native CCD contact state between unrelated teleports. Adding a 75 px paddle contact sample found lower-to-middle witnesses through the open relays without changing their geometry or physics.

Logs are ignored `test-results/vertical-*.log` files. Final traversal/survey logs are `vertical-regression-final.log` and `vertical-shots-final.log`; camera captures are `vertical-overview-0/1/2.png`, `vertical-follow-bottom/middle/top.png` and `vertical-follow-overlay.png`. Godot MCP launched the graphical v4 course and returned `PLAYGROUND_READY` with an empty errors array.

Human playtesting remains necessary for flipper timing, mid-paddle undersides, recovery routes, camera feel after repeated extreme impacts and deliberately slow camera tuning. The shot survey uses Balanced only; Floaty persistence and existing profile/trajectory regression checks pass, but every generated course/profile/modifier combination is not dynamically proven. Static flood checks do not model moving paddles. No physical gamepad or Android device was tested. There are no middle checkpoints, powered banks, new abilities, progression or runtime streaming.

## Distinct geometry tiers (generator v3)

Four new upper sections expand the catalogue to eight shapes and 28 valid mirror/shift combinations. Easy uses full-width aligned openings with no closure ledges. Normal retains the original moderate shoulders and target routes. Hard adds tapered and sideways-bending necks, without increasing bumper counts or changing ball/flipper physics. The displayed estimate uses the hardest chunk, connector or approach component; selection requires the requested band when available and explicitly reports shortages.

- `tests/generation_regression.gd`: **64 checks passed, zero failures**. All 28 transformations passed static clearance/connectivity validation. Seeds 1–24 across all three tiers reproduced geometry and estimates when generated twice (144 builds), covered all eight upper sections and at least two shapes per tier, and always matched the requested band. Mean estimates were **25.9 / 52.5 / 93.3**, checked join widths **618 / 487 / 248 px**, and largest ledges **0 / 119 / 258 px** for Easy / Normal / Hard. Invalid geometry, explicit unavailable-tier fallback, resource immutability and safe regeneration remain covered.
- Real 2D checks crossed three seam lanes in both directions at 1200 px/s for every authored shape, checked closure rails at 8000 px/s, and verified transformed bumper positions. One layout per tier completed eight seconds of scripted play without a side/top escape or a stationary stall lasting two seconds. This is sampled coverage, not proof against all traps or trajectories.
- Graphical `tests/generation_ui_smoke.gd`: **18 checks passed, zero failures**. Build/Next/Repeat, flight/pause gating, camera preservation, matched-tier summaries and unavailable-tier notices work. Three seed-1 tier captures and a Hard collision/chunk/connector overlay were visually inspected: geometry differences are visible, ground footprints match the meshes, and the full table and diagnostics fit. Existing perspective cameras and raised primitives are retained.
- Existing `tests/physics_regression.gd`: **38 checks passed, zero failures**, including both flippers, high-speed collisions, scoring, pause, live tuning, respawn and 20 seconds of simulated play.
- `tests/flipper_access_survey.gd`: **four checks passed** across 162 controlled real-flipper shots on nine seeded layouts. The `--all-hard` mode added **12 passing checks** across 144 shots covering all eight Hard transformations. Every sample received exactly one actual flipper strike and remained finite. Every Hard transformation reached both y450 and its authored diagnostic target at least once.

Representative survey results below count arrivals out of 18 shots per layout. Physics is unchanged Balanced, with no steering, modifier or rescue flips. The target radius is 70 px; the script follows swept movement and records inputs/results in JSON. Seeds 1 and 2 select the same shape/transform in the Easy and Normal samples, which is valid seeded behavior.

| Preference + seed | Upper section | Cross y650 | Reach y450 | Target hits |
| --- | --- | ---: | ---: | ---: |
| Easy 1 / 2 | Gentle Banks | 11 | 9 | 4 |
| Easy 3 | Open Meadow | 11 | 10 | 6 |
| Normal 1 / 2 | Outer Return | 11 | 9 | Not authored |
| Normal 4 | Risk Route | 11 | 7 | Not authored |
| Hard 1 | Offset Neck, mirrored | 9 | 2 | 1 |
| Hard 2 | Offset Neck | 5 | 1 | 1 |
| Hard 3 | Tapered Throat | 8 | 3 | 3 |

Across all eight Hard transforms, y450 arrivals ranged from **1–4 of 18**, versus **7–10** in the representative Easy/Normal designs. This supports the narrow-neck challenge and provides successful sample routes. It is not a player success probability, exhaustive reachability proof, generator validity gate or scoring input. The fixed lower bumper influences these opening shots. Easy and Normal overlap on initial access; recovery room, subsequent shots and subjective challenge still need human playtesting. Floaty, modifier extremes, long sessions and physical gamepad timing were not assessed by this survey.

Total: **136 passing checks**, including image saves. Headless editor import completed without script errors. Godot MCP launched the graphical playground and returned `PLAYGROUND_READY` for generator v3 with an empty errors array. Logs are ignored `test-results/tier-*.log`; captures are `table-difficulty-0.png`, `table-difficulty-1.png`, `table-difficulty-2.png` and `table-connectors.png`. Diagnostic reports are `flipper-access-survey.json` and `flipper-access-all-hard.json`. Normal Windows cache access was required for clean Godot runs; earlier restricted-shell attempts emitted certificate/settings permission errors.

See [generation rules and sample configurations](GENERATION.md) for reproduction. Version 3 changes earlier seed mappings. Existing authored collision geometry, profiles, steering and flipper code are unchanged; Risk Route's authored estimate was recalibrated from 65 to 55 against the new restrictive designs. No camera following, taller tables, progression or external artwork is added. The separately developed ring animation is preserved.

## Cosmetic ring attraction follow-up

Ring claims still award score, ring total, and meter immediately. Presentation now runs a separate 0.20-second quadratic ease-in toward the moving visible ball, with a small final shrink. This supersedes the immediate-disappearance presentation described in the historical magnet section below. Magnet strength was already absent from profiles, modifiers, and the tuning schema; radius remains configurable.

- `tests/ring_regression.gd`: **11 checks passed, zero failures**, including the existing 24000 px/s pass with unchanged ball velocity and a new swept direct-contact boundary check with magnetism disabled.
- `tests/ring_presentation_smoke.gd`: **14 headless checks passed**, then **17 graphical checks passed**, including three image saves. Covers stationary unclaimed rings, three simultaneous swept claims with immediate rewards, accelerating flight, moving targets outside range, disabling magnetism after claim, pause, arrival without duplicate rewards, reset, drain/respawn, rack reuse within one frame, long frames, and regeneration during flight with no stale visual/listener or 3D collider.
- Existing **38 physics** and **eight profile** checks passed. The physics suite includes scoring, flippers, high-speed collisions, automatic drain recovery, and 20 seconds of simulated play. Headless editor import completed without script errors. Final logs contain no errors or warnings.
- Inspected graphical captures `test-results/pickup-claimed.png`, `pickup-chasing.png`, and `pickup-arrived.png`: multiple rings remain visible after claim, travel toward the relocated ball, and disappear on arrival. Godot MCP launched the normal graphical game with an empty errors array. A live launch through Computer Use confirmed ring totals and meter advancing during play. The user then stopped Computer Use with Escape; no further UI input was sent.

The graphical fixture pauses physics while awaiting screenshot rendering, so its manually positioned ball cannot be resynchronized by the physics server between assertions. An initial fixture check also used an oversized respawn timestep that advanced through both respawn and relaunch; it now steps at the game's 120 Hz. Neither correction changed gameplay. Logs are ignored local `test-results/pickup-*.log` files.

Run the new visual check with `Godot.exe --path . --script res://tests/ring_presentation_smoke.gd` (add `--headless` to skip captures). Human playtesting still decides whether the provisional 0.20-second pull and final shrink feel satisfying, especially during fast passes and dense pickups. No physical gamepad was tested.

## Raised primitives and stationary perspective cameras

- Graphical `tests/presentation_smoke.gd`: **26 checks passed, zero failures**. Covers the default/UI selection, absence of 3D collision objects, shadow configuration, outward triangle normals for both polygon windings, whole-board framing (including the slab and a 0.55-unit height envelope), and natural near/far perspective ratios of **1.00 / 1.41 / 1.74**. Camera changes preserve the seed signature, serve position, velocity and effective physics. Both flipper tips stay aligned during simultaneous press and release; a moving ball follows the existing mapping while the camera remains stationary.
- The same suite exercises camera changes and X-ray geometry while paused, reserves clear viewport space beside both panels, and checks that seed 10 + Easy and seed 6 + Normal rebuilds retain the selected camera. Eight images are captured, including seed 1 + Normal at all three presets, a paused collision/connector overlay, both additional seeds in Real Pinball, and a fixed ball two pixels outside an upper bumper's far contact edge in both perspective views.
- All eight captures were visually inspected. The table, flippers, closure rails, raised tops/sides, ball and cast shadows render in the reviewed views. The first render exposed floor shadow acne and inward-facing triangle side triangles; both were corrected. Flat grid markings avoid tiny cylindrical-line artifacts. The initial 42° Dramatic elevation hid too much of the far-side ball; it was raised to **50°**. Partial occlusion behind raised bumpers remains natural, and distant ball tracking is easier in **Real Pinball (60°)**.
- Existing checks executed: **38 physics**, **12 headless generation UI**, and **four headless steering UI** checks, all passing. Physics checks include high-speed walls/bumpers, chunk crossings, both flippers, pause, respawn, and a 20-second scripted play sequence. Total for this task: **80 passing checks**, including image saves. Headless editor import completed without script errors. Godot MCP launched the graphical playground and reported `PLAYGROUND_READY` with an empty errors array.

The moving-ball check originally sampled at `process_frame`, before node visual updates; it now samples after the idle update using a SceneTree timer. The static occlusion probe pauses physics explicitly and verifies its position, rather than relying on a long physics teleport to settle at the exact requested point. These are test-fixture corrections, not physics changes.

Captures are ignored local files: `test-results/depth-top-down.png`, `depth-real-pinball.png`, `depth-dramatic-pinball.png`, `depth-collision-overlay.png`, `depth-seed-10-real.png`, `depth-seed-6-real.png`, and `depth-bumper-clearance-1.png` / `depth-bumper-clearance-2.png`. Logs: `presentation-smoke.log`, `depth-import.log`, `depth-physics.log`, `depth-generation-ui.log`, and `depth-steering-ui.log` in the same directory. Reproduce captures with:

```powershell
& 'C:\Program Files\Godot\Godot.exe' --path 'E:\Sonic Spinball Runners' --script res://tests/presentation_smoke.gd
```

No physics, input routing, profile/modifier, ring collection, generator-selection or authored collider source changed. This task does not add camera following, taller tables, new connections, progression or external assets. Visual inspection uses actual Godot framebuffer images and scripted input; MCP cannot operate controls directly. No physical controller or human timing/feel test was performed. The captures are not proof against every possible occlusion. Before following, playtest distant ball visibility and height parallax, then establish viewport bounds, stable look-ahead, rebound smoothing and shadow coverage for a moving view. Performance was not profiled across other GPUs or Android.

## Difficulty preference follow-up (generator v2)

- `tests/generation_regression.gd`: **47 checks passed, zero failures**. Seeds 1–24 at Easy, Normal, and Hard reproduced both their geometry and difficulty metadata: 72 configurations, each generated twice. All 16 authored transformations remain valid, and the selected configurations still cover all four upper chunks.
- Every selected score stayed within eight points of the closest valid distance to the preference target. Mean scores across the same 24 seeds increased from **33.8 to 50.7 to 52.1**. The current catalogue spans **29.4–55.3**, so the Hard request truthfully reports a Normal estimate.
- Focused checks verify reflection invariance, greater estimated challenge from larger offsets/ledges without rejecting them, authored ratings changing score without changing colliders, nearby approach obstacles affecting the estimate, and invalid/trapped candidates never winning on difficulty. Existing fallback, safe regeneration, 1200 px/s bidirectional seam shots, 8000 px/s closure impacts, transformed-body alignment, and four eight-second simulations still pass.
- Graphical `tests/generation_ui_smoke.gd`: **16 checks passed, zero failures**. Build and Next apply the selected preference; Repeat restores both current seed and preference despite unbuilt edits. Flight/pause gating still works. The actual estimate, reasons, and mismatch notice fit beside the table. The Hard-preference capture was visually inspected at 1280 × 900.
- Existing suites rerun: **38 physics, 12 steering, eight profile, 10 ring, and four headless steering UI checks**, all passing. Total: **135 checks passed**. Headless editor import completed without script errors; Godot MCP launched the updated playground and reported a clean errors array.

Logs are in ignored `test-results/difficulty-*.log`; screenshots are `test-results/table-difficulty-0.png`, `table-difficulty-1.png`, and `table-difficulty-2.png`. The original random-penalty selection experiment excluded Central Targets in the sampled seeds; selection was changed to a deterministic near-target band, restoring all four layouts without loosening tests or collider validation.

No authored collider, ball physics, flipper, ring, or progression behavior changed. The ratings are static heuristics; upward-shot accessibility, effects of gravity/profile/modifier settings, and subjective challenge remain for manual playtesting. See [the scoring contract](GENERATION.md) for the provisional weights and limitations. Version 2 changes the earlier version 1 seed mappings.

## Immediate ring magnet follow-up

The playground remains an endless sandbox. The magnet now collects stationary rings immediately within a provisional 50-pixel radius measured from the ball's swept center path. Radius remains live-tunable and modifier-compatible. Direct contact retains its 26-pixel threshold with magnetism disabled. The unused attraction-speed field was removed; collected rings hide immediately with no pull animation.

- `tests/ring_regression.gd`: **10 checks passed, zero failures**. Checks cover both profile defaults, immediate stationary pickup, score/meter/event deduplication, exact radius boundary versus an outside ring, direct contact at radius zero, swept proximity in both directions with endpoints outside range, live/modifier radius resolution without base mutation, serve suppression, one rack bonus followed by automatic rack reset, and a real 24000 px/s pass preserving horizontal and vertical velocity.
- Existing checks rerun: **38 physics, 12 steering, eight profile, 39 generation, four headless steering UI, and 17 graphical generation UI checks**, all passing. Together with the new suite, **128 checks passed**.
- Headless editor import completed without errors. Godot MCP launched the updated graphical playground; its debug output was checked for script errors. Logs are in ignored `test-results/magnet-*.log` files.

Collection never applies forces or changes velocity. The sweep is the straight previous-to-current position segment for each physics tick, as in the original contact pickup. It is proximity-based, without wall occlusion. No new progression or artwork was added. Manual tuning remains necessary to judge the 50-pixel radius and immediate disappearance during ordinary play; no physical gamepad was tested for this change.

## Phase 2A verification

The modular generator was checked against the Phase 2A source. Its initial handoff remained local; the subsequent ring-magnet follow-up authorized committing and pushing the completed work.

- Final headless editor import and 240-frame debug startup completed without errors. Godot MCP recognized the project, launched the graphical build, and reported `PLAYGROUND_READY` with an empty errors array after the warning fix. The graphical session remains open for playtesting.

- `tests/generation_regression.gd`: **39 checks passed, zero failures**. All 16 catalogue/mirror/shift combinations passed static validation. Seeds 1–24 reproduced identical selections, closure rails, and gameplay descriptors and covered all four layouts without fallback. Negative fixtures rejected bad shifts, vertical misalignment, inadequate overlap, missing rail endpoints, a blocked join, and an enclosed route. An invalid catalogue correctly fell back to the original table without mutating resources.
- Real physics covered both directions through three join lanes in each of seeds **1, 2, 10, and 12**, at 1200 px/s (below the existing downward speed limiter). Closure rails blocked 8000 px/s upward shots. Transformed bumper descriptors matched actual body positions and mirrored triangle shapes. Each sample then completed eight seconds of scripted play without a side/top escape or stationary stall lasting two seconds.
- Regeneration checks covered refusal during flight, cancellation if pause ends before the deferred swap, immediate reset while paused, cleared counters/timers, preserved lower/flipper instances, retained tuning/modifier/overlays, repeatable layout, and synchronized ring visuals.
- `tests/physics_regression.gd`: **38 checks passed, zero failures**. The original geometry and Original steering calibration are now explicit test fixtures; all existing shot/physics checks remain. The Chao expectation reflects the requested Quick / Tight base acceleration.
- `tests/steering_regression.gd`: **12 checks passed, zero failures**. No steering integration, release, collision, or flipper code was changed in this phase.
- `tests/profile_regression.gd`: **eight checks passed, zero failures**. Both actual character resources also match Quick / Tight in the generation checks.
- Graphical `tests/generation_ui_smoke.gd`: **17 checks passed, zero failures**. Entered seed, Next, Repeat, flight/pause gating, reset, summary labels, panel bounds, and capture output were exercised. Rendered images for seeds 1/2/10/12 and the physics/chunk/connector overlays were visually inspected. Controls fit beside the table; closure rails and the transformed overlays are visible and aligned in the reviewed views.
- Headless `tests/steering_ui_smoke.gd`: **four checks passed, zero failures**. Profile reset now truthfully selects Quick / Tight. Existing preset editing and diagnostics still fit.

Logs: `test-results/phase2a-generation.log`, `phase2a-physics.log`, and `phase2a-ui.log`. Rendered views: `test-results/table-seed-1.png`, `table-seed-2.png`, `table-seed-10.png`, `table-seed-12.png`, and `table-connectors.png`. These generated files are ignored by Git.

During development, tests caught a typed-empty-array error in legacy fallback startup; this was fixed and the full legacy suite passed. The initial no-impulse seam test exceeded the existing terminal downward speed, so its fixture was corrected to 1200 px/s without changing physics. MCP also exposed a local-variable shadow warning in the generator, which was corrected.

Manual work remains: physical controller behavior, subjective shot quality, outer-return accessibility, low-speed join-shoulder behavior, long sessions, and extreme modifiers. MCP launches and reads output but does not operate game controls. Programmatic UI signals and rendered captures do not establish human timing or gameplay feel. Static connectivity and 32 seconds of generated-layout simulation do not prove every trajectory is safe. See [generation limits](GENERATION.md).

The sections below preserve the earlier Phase 1 and steering verification history.

## Executed checks

- Headless editor import completed with exit code 0 and no script errors.
- Headless main-scene startup completed for 240 frames and printed `PLAYGROUND_READY` with no script errors.
- Godot MCP `get_project_info` recognized the project. MCP `run_project` launched the graphical game, and the latest `get_debug_output` returned an empty errors array.
- `tests/physics_regression.gd`: **38 checks passed, zero failures**, exit code 0. Detailed output is in `test-results/physics-regression.log`.
- The existing `tests/profile_regression.gd` was rerun: **eight checks, zero failures**. Output is in `test-results/profile-regression.log`.

Covered behavior:

- Additive/multiplicative resolution, clamping, and preservation of shared character defaults.
- Steering calibration at 60/120 integration steps per second. At strength 0.065 and configured acceleration 1000, one second adds 65 px/s.
- Actual physics steering added to 1400 px/s lateral momentum, preserved vertical momentum, capped only assistance, removed assistance on release, and retained momentum under opposite steering.
- Comparable one-second launch: Balanced reached approximately `y = -147.1`, `vy = 200`; Floaty reached `y = -295.3`, `vy = -94`. Floaty's downward limit preserved lateral velocity.
- Both flipper actions raised both flippers within 100 ms; release restored their rest angles. Both sides launched approaching balls.
- Rail rebounds at 1800, 4000, and 8000 px/s. Closed side boundaries at `y = 685`, `700`, and `715`. Open middle passage in both directions.
- Circular and triangular bumper events, including 8000 px/s circle and 6000 px/s triangle sweeps.
- Ring scoring, special-meter charging, live changes across both chunks, example modifier values, pause, and automatic drain/respawn/relaunch.
- 2D/3D mapping round trip and absence of collision objects in the 3D tree.
- Twenty seconds of scripted play using the Balanced profile, timed flipper presses, and variable steering: no side/top escape or stationary trap longer than two seconds.

## Problems found and repaired

The original serve marker overlapped a lower rail. The marker was moved to an open area and a test now verifies it remains in place while waiting to serve.

Native shape CCD missed fast rail impacts in this engine build. A supplemental 2D shape sweep now applies a conservative normal impulse before a missed crossing. The failing high-speed and seam cases pass. This safeguard can rebound up to one physics tick early; it is documented in the README.

A gamepad enum warning was fixed. The latest graphical run's MCP errors array is empty.

## Visual and interactive limits

The first graphical build was inspected through Computer Use. The vertical table, tilted 3D presentation, primitive objects, flippers, score, and tuning panel rendered visibly. A keyboard launch action was sent. These observations do not establish subjective gameplay quality or final-build alignment.

The user stopped Computer Use with Escape during the later visual pass. UI control stopped at that point. The updated build was launched through MCP and its output checked, but final-build overlays, live field editing, and visual alignment still need manual inspection.

No physical gamepad was exercised. Automated simultaneous action tests validate input routing and flipper response, not controller hardware, OS mappings, stick feel, or latency. A 20-second scripted run and selected stress shots cannot prove the absence of every trap, moving-flipper tunneling case, or extreme modifier interaction.

## Short manual checklist

1. Launch with Enter/X. Tap Q/E or LB/RB separately and together; try holding both and releasing near the ball.
2. Compare Balanced and Floaty using reset/relaunch. Check that steering helps without replacing pinball timing.
3. Toggle Chao, edit a field, press Enter, and inspect effective values. Check pause/resume on Escape/Menu.
4. Toggle Physics and Chunks. Check footprints, moving flippers, the center seam, and side-rail continuity.
5. Play for several minutes, including modifier extremes. Note any trapped ball, unexpected escape, unreadable trajectory, or difficult drain recovery.

## Steering investigation follow-up

The subsequent focused steering change added an independent counter-steering rate, optional session presets, and steering telemetry. That pass retained original startup values; Phase 2A subsequently promotes Quick / Tight after user playtesting. See `STEERING_INVESTIGATION.md` for the findings and settings.

Executed against the updated source:

- Headless editor import: completed without script errors.
- `tests/steering_regression.gd`: 12 checks passed, zero failures, exit code 0. Includes actual ascent/descent, both counter-steering directions, release/reversal, real native and swept rebounds, preserved momentum, mapped input, and blocking telemetry. Output: `test-results/steering-regression.log`.
- Existing physics regression: 38 checks passed, zero failures, exit code 0, including high-speed collision and chunk checks.
- Existing profile regression: eight checks passed, zero failures, exit code 0.
- Graphical `tests/steering_ui_smoke.gd`: five checks passed, zero failures, exit code 0. Preset application, custom-edit labeling, profile reset, layout bounds, and screenshot capture were checked. The generated `test-results/steering-lab.png` was visually inspected; the added readout and preset selector fit and are readable.
- Godot MCP launched the updated game. `get_debug_output` reported `PLAYGROUND_READY` and an empty errors array.

The new input checks use synthetic keyboard/gamepad events. No physical controller or subjective playtesting was performed for this follow-up. The rendered UI smoke scene programmatically supplied steering for inspection; it does not validate human interaction timing. No collision geometry, flipper response, or world rendering changes were part of the steering work.
