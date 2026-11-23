# Optional Launch Tube

Confirmed direction: an authored launch object, absent from all existing production Acts. The experimental Act is `data/acts/Experiments/Launch Tube Workshop.tres`. No production roster or theme default is changed. This feature starts from closure commit `5d160094673982414615a572e8e33098066c9bd7`; Thursday's frozen benchmark is independent and remains unchanged.

## Authoring and play

Open the experimental Act in **Act Geometry Editor**, or choose **Gameplay → Launch Tube (optional)**. Click the dock and route points, then press Enter. Select the tube and enable **Edit path points** to drag points; Shift-click inserts and right-click removes. The first point is the dock and the final tangent is the exit direction. Place the dock at Spawn and leave the exit plus one ball diameter ahead clear. Invalid numeric values and degenerate paths are rejected through the usual Act validation.

Both modes cut a lane at table height through solid terrain and open walls. Leave room behind the dock for the spring housing, which extends 1.05 lane widths along the reverse entry tangent plus the rounded end of the cut. The compiler derives the visible banks and 2D collisions from the same cut. Moving or deleting the tube restores the underlying authored terrain on the next play or bake. **Exposed** leaves the textured ramp deck visible. **Tunnel** covers it with a faceted arch using the same stage material.

Undo/Redo, shared snapping, exact transforms, H/V mirrors, copy/paste, duplicate, assemblies and save/reopen use the existing editor paths and format 19. Scaling changes the path and presentation dimensions without silently changing launch speed. Copies receive independent identities. If several tubes exist, the dock nearest the active Act's Spawn owns serving and retry; ties use authored order. That same dock catches the ball if it rolls back down the shooter lane or settles in its plunger pocket. This supports reusable assemblies without inventing a new route-selection mechanic.

Use **Play Act** for source authoring, then **Bake Prototype → Play Prototype** for the supported gameplay run. **Bake Endless → Play Endless** remains the separate streaming stress workflow. The experiment can be selected explicitly in Prototype; it is not silently added to production pools.

Hold the existing Launch input, then release to fire: **X in Prototype**, **Enter in standalone/Endless**, or the existing gamepad Launch binding. The Workshop's design note gives three examples: roughly **0.18 s / 15%** rolls back, **0.6 s / 50%** exits moderately, and **1.2 s / 100%** exits strongly. Holding Launch draws the real ball and plunger head back against the coil. Release to shoot. After a successful shot, a ball that rolls back to the plunger can be launched again with the same control. This keeps the current Ball, score and objectives. The open bottom provides drain access. Activate the switch or progress the spinner before draining to inspect retained objective state.

## Runtime contract

`scripts/authored_act/launch_tube.gd` owns the dock/charge/outbound/return state machine. `PlaygroundBall` delegates its existing direct physics integration while contained. This is the same real RigidBody2D; there is no proxy ball or visual-driven collision. The controller samples the shared rail path, suspends gravity, collision layers/masks, steering and serve/scoring eligibility, and restores normal flight at a clear exit. Specials, ring pickups and mechanism scoring remain gated while contained.

Charge chooses initial traversal speed. Constant authored resistance gives weak launches a real stopping distance; they reverse on the same route and safely re-dock. A blocked exit also returns to dock. The exit checks the ball shape and its immediate forward sweep before restoring collisions, then clears motion history to prevent cross-route scoring or stale steering/contact impulses. Successful exit preserves the remaining traversal speed in the authored exit direction.

Prototype retains its existing death transfer, finite Balls, score, objective progress, partial spinner rotation, cooldowns and earned routing changes. On arrival, an eligible tube docks the real ball and cancels the old automatic launch timer. Endless uses its existing checkpoint reset with the same tube hook. Every docking arms a release latch: a Launch button held through death cannot charge or fire. Releasing only arms the next press. A fresh player-controlled hold and release are required. Weak rollback also requires a fresh charge.

Only the active Act's runtime supplies a retry dock. Streamed Acts instantiate their own controllers, world offsets and baked animation bindings. Neighboring resident tubes never claim a retry. An Act without a tube follows the existing paths and exact automatic-launch delays (0.35 s after Prototype transfer, 0.25 s on ordinary shared retry). No new input semantics apply to ordinary Acts.

## Presentation and tuning

The deck and edge trim use the active stage’s ramp materials. Dock and exit collars, eight charge indicators, a traversal pulse and a brief exit ring use the mechanism palette. The plunger has a fixed seat, a steel coil and a moving head. Its pullback follows the real ball during charging, and the coil extends again as the shot leaves the dock. Sonic and Tails spin up while charging and roll along the path in either direction. It adds no dynamic lights or particles, and does not change theme artwork, atmosphere defaults or Theme Life choices. Disk recipes use the existing mechanic binding/retirement infrastructure.

Starting values are deliberately configurable, not final feel decisions:

| Property | Default | Meaning |
| --- | ---: | --- |
| Charge seconds | 1.2 | Hold duration for full charge |
| Minimum / maximum speed | 80 / 410 px/s | Initial traversal speed range |
| Resistance | 55 px/s² | Outbound deceleration |
| Return speed | 300 px/s | Rollback speed limit |
| Width | 40 px | Deck width. The cut includes the ramp’s edge trim. |
| Feedback strength | 1.0 | 0–1; reduces motion/effect size, with 0 disabling charge indicators, pulse, burst and collar spin. Mechanical plunger travel follows charge at every setting |

Older saved tubes with the original 80 / 700 px/s and 100 px/s² factory tune adopt the new defaults on load. Custom speed and resistance settings persist. Playtest the medium/full speed spread and feedback in motion. Automated checks establish mechanics and persistence; they do not establish game feel.

## Verification entry points

- `tests/launch_tube_regression.gd`: authoring, transforms, persistence, real 120 Hz ball containment, strength, rollback, safe exit and input latch.
- `tests/launch_tube_integration.gd -- --prepare`: create disposable ordinary/Tunnel fixtures. Bake them normally before running the script without `--prepare`; it exercises real disk-backed Prototype and Endless deaths, state retention, streaming ownership and ordinary-Act parity.
- `tests/launch_tube_presentation.gd`: canonical Prototype disk authority in both modes across all eight themes, animation ownership, bounded effects and captures.
- Actual exported `Geometry Editor.exe -- --portable-smoke --launch-tube`: editor persistence, disk-backed Workshop, weak rollback, full launch and held-through-death behavior inside the native portable. Add `--tube-source` to exercise the externally saved Tunnel copy through the ordinary Play Act source builder.

The [verification report](LAUNCH_TUBE_VERIFICATION_2026_11_18.md) records source checks and limitations. The development release records the exact build SHA and native package receipt. Raw failed attempts remain in local task evidence; assertions and existing coverage requirements are retained.
