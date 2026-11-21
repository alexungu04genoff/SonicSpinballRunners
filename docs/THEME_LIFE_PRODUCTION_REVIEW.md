# Theme Life at the gameplay camera

**November 21, 2026. Casino Night B is the one production promotion.** All three comparisons use the same served shot on First Try Smooth Decor. Watch Sonic take the lower Ring, then use the final two seconds to see what the normal camera can resolve along the right boundary.

| Theme | Production verdict | What survives full Retro |
| --- | --- | --- |
| [Rooftop Run · C and A](theme-life/production-review/rooftop_run.mp4) | **NEEDS HUMAN DECISION · C ships** | At spawn the red-roofed tower is easy to recognize, but the clock sits almost entirely beyond the right crop. The moving camera gives little time to read the hands. At the boundary, the long hand is legible against the tan face and moves at a believable 48 seconds per turn. The building and canal banks stay steady. Alex’s call is whether that peripheral moment earns the work on every visible Zone frame. |
| [Casino Night · C and B](theme-life/production-review/casino_night.mp4) | **PROMOTE B** | The large magenta cabinet star is visible from the serve. As Sonic takes the Ring, a star point turns past vertical against the dark cabinet. The bright center holds steady and the changing outline reads as a mechanical sign. The gold Ring trail, blue Ball, small deck ornaments and target faces remain distinct. The large signs take about 25–27 seconds per revolution. |
| [Sky Sanctuary · C and A](theme-life/production-review/sky_sanctuary.mp4) | **KEEP C** | The served court hides almost all the cloud banks. The shot reveals sky below the plinth, but the drift is hard to pick out while following Sonic. At the parked right edge the cloud contour slides behind the fixed columns, which gives a pleasing sense of depth. The ruins stay anchored and the clouds stay clear of the Ring route. The effect earns its clearest read in the supplemental view. |

## Reading the clips

The left and right panes retain the full 1280 × 900 game output, including the HUD. Each six-second clip holds the served Ball for 1.5 seconds, follows 2.5 seconds of ordinary launch physics, and ends with two seconds at the original Motion Lab’s right-edge focus. Both views use the normal 1.3 zoom and 52° field of view. The last cut parks the camera for inspection. The 20 fps edit samples the shot at fixed 60 fps and advances environmental time at real speed.

The initial review ran against `1de8eb0`. The published pairs replayed C and its candidate on the final registry. Each pair used byte-identical disk Act and backdrop recipes, seed 18, Default atmosphere and current desktop defaults. The 682 × 480 foreground, three Retro passes, 0.010 grain, authored faces, smooth cast, native contacts, lights and exposure come from the shipping setup. The capture compares all 80 sampled Ball, velocity, camera, score, Ring and serve states, plus both held camera transforms. Each session loaded one Act and one backdrop with zero runtime builds. [Capture and validation source](../experiments/theme_life_review/)

In the first Casino comparison, the pink star on the small pedestal also turned. Its authored size is exactly 0.42, which qualified it for the original sign-size cutoff. Production B now opts in the signs on the lantern, reel-tower crown and jackpot palace. The reel faces, pedestal star and other small ornaments stay fixed. The published clip uses that correction on the same shot. The sign geometry, phases and rotation periods come from the original candidate.

## Desktop cost

Godot 4.7.2, Forward+/Vulkan, RTX 4060. Each theme started in C on fresh device defaults. The timed section measured 120 native Zone updates at the served pose after 48 warm-up frames per selection. The CPU column measures the controller call with an advancing time step. The GPU columns measure each world viewport independently. Frame capture and JPEG encoding ran in separate processes.

| C → candidate, matched final recipes | Visible Δ draws / objects / primitives | Controller CPU median, ms | Foreground GPU median, ms | Backdrop GPU median, ms | Bound materials / shader programs in both |
| --- | --- | --- | --- | --- | --- |
| Rooftop C → A | 0 / 0 / 0 | 0.008 → 0.247 | 0.534 → 0.536 | 0.219 → 0.220 | 103 / 18 |
| Casino C → B | 0 / +1 / +36 | 0.007 → 0.394 | 0.501 → 0.488 | 0.206 → 0.199 | 117 / 11 |
| Sky C → A | 0 / 0 / 0 | 0.007 → 0.013 | 0.507 → 0.506 | 0.159 → 0.159 | 80 / 10 |

Rooftop updates 24 clock-hand meshes through one Zone owner. Casino updates 42 meshes through one owner, down from 60 with the pedestal stars included. Sky displaces 180 instances through one existing cloud-volume material and keeps its MultiMesh batches. All visible-count differences in the table occurred in the foreground. Each switch added zero resident resources and zero canvas, mesh, surface, draw or specialization pipeline compilations on this warmed driver. The small differences between GPU medians fall within the variation seen across frames. [Per-viewport counts, sample percentiles, pipeline counters and recipe hashes](theme-life/production-review/receipts.json)

Casino’s binding correction also changes the baseline batch layout. The **original C → shipping B** comparison at spawn was 183 → 184 foreground draws, 238 → 238 objects and 27,933 → 28,293 primitives. The backdrop stayed at 24 draws, 24 objects and 7,572 primitives. Original C measured 0.006 ms for the controller and 0.494 / 0.199 ms for the two GPU viewports. The final B controller median was 0.394 ms, with p95 at 0.529 ms. These are desktop observations. The UHD 620 result remains open. Tuesday’s self-contained depth matrix retains SHA-256 `87e3f99d3a13f0e1b0bfc193543feb35cf1400346cb871c1e4ac4befa75b3623`.

## Reproduction and checks

Use fresh Prototype and Endless bakes in the checkout being reviewed. Run `res://experiments/theme_life_review/capture.gd` with Forward+/Vulkan, `--fixed-fps 60` and user arguments `--seed=18 --theme=casino_night --state=C`, then B in a fresh process. Use A for Rooftop and Sky. For each theme, measure in a separate uncapped process with `--seed=18 --theme=<id> --measure --motion-candidate=C`. The Windows capture uses the secondary screen. Run `python experiments/theme_life_review/compare.py` to validate the paired receipts and encode the three clips with local FFmpeg.

The first cross-worktree Endless audit caught a raw-byte hash mismatch in the HUD source catalog. The two checkouts had identical catalog text with different line endings. The normal baker refreshed the recipes in the gameplay checkout. Both eight-theme pools subsequently passed all 646 checks apiece across 56 variants each. The Theme Life disk audit passed 623 checks over 105 recipes. The existing Tuesday executable and its bundled recipes are independent.

The motion contract passed 35 checks, including repeat seeks, pause and reference release. Custom batching passed 8 and native shader parity passed 30. The real Prototype transition suite passed 435 checks, and Endless passed 33 including the production selections, zero-weight backgrounds and controller retirement. Those processes reported 9 and 2 ObjectDB instances respectively at engine shutdown. The tests confirmed their motion-owner weak references expired. The shutdown warnings remain unresolved.

Casino decor passed 108 checks across all 13 variants, including the rotation count on each. Prototype setup passed 16 and canonical appearance passed 70 across eight themes. Retro smoke passed 75 headless and 110 graphical checks. Eight fresh-process replays matched all 600 physics ticks, and the graphical terrain-shadow streaming regression reported zero failures.
