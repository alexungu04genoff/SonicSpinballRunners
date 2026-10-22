# Physics Playground verification

Date: 2026-10-22. Engine: Godot 4.7.2 stable, Windows. Physics: 120 Hz. Graphical renderer: OpenGL Compatibility on NVIDIA GeForce RTX 4060.

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

The subsequent focused steering change adds an independent counter-steering rate, optional session presets, and steering telemetry. Startup profile values retain the original behavior. See `STEERING_INVESTIGATION.md` for the findings and settings.

Executed against the updated source:

- Headless editor import: completed without script errors.
- `tests/steering_regression.gd`: 12 checks passed, zero failures, exit code 0. Includes actual ascent/descent, both counter-steering directions, release/reversal, real native and swept rebounds, preserved momentum, mapped input, and blocking telemetry. Output: `test-results/steering-regression.log`.
- Existing physics regression: 38 checks passed, zero failures, exit code 0, including high-speed collision and chunk checks.
- Existing profile regression: eight checks passed, zero failures, exit code 0.
- Graphical `tests/steering_ui_smoke.gd`: five checks passed, zero failures, exit code 0. Preset application, custom-edit labeling, profile reset, layout bounds, and screenshot capture were checked. The generated `test-results/steering-lab.png` was visually inspected; the added readout and preset selector fit and are readable.
- Godot MCP launched the updated game. `get_debug_output` reported `PLAYGROUND_READY` and an empty errors array.

The new input checks use synthetic keyboard/gamepad events. No physical controller or subjective playtesting was performed for this follow-up. The rendered UI smoke scene programmatically supplied steering for inspection; it does not validate human interaction timing. No collision geometry, flipper response, or world rendering changes were part of the steering work.
