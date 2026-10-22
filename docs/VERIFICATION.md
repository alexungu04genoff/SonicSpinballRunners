# Physics Playground verification

Date: 2026-10-22. Engine: Godot 4.7.2 stable, Windows. Physics: 120 Hz. Graphical renderer: OpenGL Compatibility on NVIDIA GeForce RTX 4060.

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
