# Pixel-cost audit — 2026-11-08

Production defaults remain **4× MSAA, 100% native 3D scale**, with unchanged shadows,
Retro, foreground contribution, geometry, physics and artwork. The new controls
are development-only, unsaved process state. Measurements use the existing local
Acts/art on top of `c7cb7dce569f0bb88d9c16de33c2af63997d9d0a`; those unrelated edits
are not included in this change.

## Ownership and sizing

Previously the main game and Endless constructors selected 4× directly; Zone
backdrops and the streaming warm-up copied it. This was a fixed presentation choice,
not an atmosphere setting or a measured hardware policy. Prototype extends Endless;
source-built and disk-baked Acts use the same live viewport infrastructure. Bakes
contain presentation resources, not an independent live MSAA setting.

| Route / surface | Owner after this change | Sizing |
| --- | --- | --- |
| Prototype, single-Act source/disk, Endless foreground | `rendering_options.gd`, registered by `endless_game.gd` | Existing world SubViewport |
| Resident Zone scenery | Same owner, registered by `zone_backdrop.gd` | Follows world logical size |
| Source/disk streaming warm-up | Same owner, registered by `template_library.gd` | 256 × 256; disabled after preparation |
| Offline baker | Same owner, registered by `act_baker.gd` | No separate graphics policy |
| Generic game / authoring playtests / Lab | Existing registration now applies pixel profile as well as FXAA | Existing route-specific sizing |
| Portable Prototype | Same session and Endless implementation | Same world, backdrop and compositor structure |
| HUD / 2D composite | Excluded from pixel-profile registration | Original layout and text resolution |

At the measured 1280 × 900 window, the normal N64 + VHS + CRT stack already uses
Retro's **1.9 divisor**, producing a **673 × 473 logical world/composite**. Retro
then presents that result at the window size. Turning Retro off restores 1280 × 900.
`scaling_3d_scale` operates inside each registered 3D viewport; it does not change
Retro's divisor, viewport logical size, camera projection, 2D collision coordinates
or the parent HUD. The engine's existing bilinear mode is retained.

| Native scale | Normal Retro 3D buffer | Clean visual-only 3D buffer |
| --- | --- | --- |
| 100% | 673 × 473 | 1280 × 900 |
| 85% | 572 × 402 | 1088 × 765 |
| 75% | 504 × 354 | 960 × 675 |

These integer sizes are derived by truncating logical size × scale, matching the
engine's bilinear allocation calculation. They are not GPU readback measurements.
The logical 2D composite remains 673 × 473 throughout primary measurements, and
the HUD remains at 1280 × 900. Scaling also includes Godot's normal mip-bias
adjustment; no texture or material settings are edited. See the official
[resolution-scaling documentation](https://docs.godotengine.org/en/stable/tutorials/3d/resolution_scaling.html)
and [renderer allocation implementation](https://github.com/godotengine/godot/blob/master/servers/rendering/renderer_viewport.cpp).

## Reproduce and switch live

Run `tools/profile_pixel_cost.ps1` with Godot 4.7.2 after refreshing Prototype bakes.
It runs the four workloads serially, saves JSON/logs/native PNGs in a timestamped
`test-results/pixel-cost/` directory and refuses to measure alongside another Godot
process. Each process uses separate graphics/session settings. No device preference
file is written by pixel switching.

For ordinary development launches, add these user arguments after Godot's `--`:

```text
--pixel-controls --world-msaa=4 --world-scale=100
```

In Prototype/Endless, F6 cycles **4× → Off → 2× → 4×**; F7 cycles
**100% → 75% → 85% → 100%**. The overlay shows both. Explicit launch values accept
MSAA `0/2/4` and scale `75/85/100`; invalid values are ignored with a warning.
The API rejects invalid combinations atomically. Late-created scenery/warm-up
viewports inherit the current profile. The Lab keeps its existing F6 shortcut.
The optional FXAA-only override exists for the visual probe, independent of Smooth
Shadows, and does not change the Ultra shadow filter.

## Measurement method

Desktop **RTX 4060, Forward+/Vulkan, Godot 4.7.2**, uncapped/VSync off, 1280 × 900,
seed 18. Primary blocks retain normal Retro, Default atmosphere, conservative
foreground contribution, atlas 8192, four cascades, project Medium filtering,
Smooth Shadows/FXAA off. Gameplay, camera and animation time are frozen after
preparation. These are stationary rendering measurements, not play/streaming FPS.

Each workload compares 4×/100, 2×/100, Off/100, 4×/85 and 4×/75, then repeats in
reverse order: **600 measured frames per block, 120 warm-up frames**, plus a
30-frame settling period after switching. No pipeline compilation occurred inside
accepted measured blocks. Source fallback count is zero. Camera, ball identity and
position, score, logical sizes, atmosphere, Retro and resident count are checked
after every switch. Clean and FXAA-only images are captured after timing ends.

| Workload | Fixed scene / camera | Resident / contributing Acts |
| --- | --- | --- |
| Small | Reverse C Spring, Green Hill, served-ball follow view | 1 / 1 |
| Larger (`dense`) | RampMania, Green Hill, whole-Act overview, 12 × 16 grid | 1 / 1 |
| Multi | Reverse C Spring / Secret Entry / RampMania, Green Hill, join view | 3 / 3 |
| Busy | RampMania, Chemical Plant, served-ball follow view | 1 / 1 |

The larger overview is spatially larger, not the largest draw count: its camera
and shadows submit fewer primitives than the compact small view. The multi view
is the heavy submission workload. The report does not equate Act size with GPU cost.

Evidence from an initial fresh-cache run that lost the Vulkan device before
measurement is excluded (`20261108-164517/small.err`). A completed 120-frame smoke
probe and the subsequent full run are separate; smoke samples are not pooled.

## Results

The accepted run is `test-results/pixel-cost/20261108-164748/`: **40 blocks / 24,000
measured frames**, zero invariant or pipeline-compilation failures. The table shows
the arithmetic mean of the two block statistics, in milliseconds. Thus its p95/p99
columns are **means of block percentiles**, not pooled percentiles. Exact independent
block statistics, draw/primitive counts and allocation bytes are retained in
[pixel-cost-measurements.csv](pixel-cost-measurements.csv); full JSON also records
camera transforms, atmosphere, viewport properties and provenance.

| Workload | MSAA / scale | Frame median | p95 | p99 | Render CPU | GPU |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Small | 4× / 100 | 3.094 | 4.829 | 5.809 | 1.596 | 0.807 |
| Small | 2× / 100 | 3.007 | 4.354 | 5.146 | 1.545 | 0.783 |
| Small | Off / 100 | 3.040 | 4.035 | 4.537 | 1.571 | 0.717 |
| Small | 4× / 85 | 3.877 | 5.372 | 7.116 | 2.005 | 0.736 |
| Small | 4× / 75 | 3.500 | 5.519 | 7.039 | 1.779 | 0.696 |
| Larger | 4× / 100 | 2.093 | 2.854 | 3.353 | 1.018 | 0.619 |
| Larger | 2× / 100 | 2.114 | 3.154 | 3.944 | 1.026 | 0.591 |
| Larger | Off / 100 | 2.020 | 2.340 | 2.582 | 0.989 | 0.556 |
| Larger | 4× / 85 | 2.296 | 3.688 | 4.431 | 1.103 | 0.594 |
| Larger | 4× / 75 | 2.272 | 3.443 | 4.068 | 1.102 | 0.559 |
| Multi | 4× / 100 | 5.240 | 7.120 | 8.483 | 3.218 | 0.905 |
| Multi | 2× / 100 | 5.309 | 8.232 | 9.954 | 3.266 | 0.873 |
| Multi | Off / 100 | 4.897 | 6.355 | 7.817 | 3.024 | 0.808 |
| Multi | 4× / 85 | 5.535 | 8.374 | 10.003 | 3.387 | 0.823 |
| Multi | 4× / 75 | 5.740 | 9.582 | 12.424 | 3.523 | 0.778 |
| Busy | 4× / 100 | 2.167 | 2.970 | 3.967 | 1.068 | 0.807 |
| Busy | 2× / 100 | 2.314 | 3.723 | 4.746 | 1.094 | 0.777 |
| Busy | Off / 100 | 2.066 | 2.678 | 3.710 | 1.009 | 0.722 |
| Busy | 4× / 85 | 2.089 | 2.658 | 3.224 | 1.012 | 0.725 |
| Busy | 4× / 75 | 2.353 | 3.599 | 4.439 | 1.115 | 0.679 |

GPU and render CPU are sums of Godot's measured times for active viewports, excluding
disabled warm-up views. They are not end-to-end GPU latency or additive components
of the wall-frame time. Instrumentation also has CPU overhead. CPU/frame medians and
tails varied appreciably between passes; **these data do not establish an FPS gain**.
For example, the small 4× GPU median changed from 0.838 to 0.777 ms between passes,
while 2× stayed near 0.783 ms. Small differences should not be overinterpreted.

Across these block means, 4× costs **0.024–0.032 ms more GPU time than 2×**
(approximately 3–5% relative to 2×). Reducing native 3D scale to 85% saves
**0.025–0.082 ms** versus 4×/100; 75% saves **0.060–0.128 ms**. Those are desktop
stationary observations, not laptop predictions or significance estimates.

Draws/primitives stayed at **1129 / 124454** (small), **584 / 111200** (larger),
**601 / 142060** (busy), and **2743 / 326409** (multi). At 75% the multi renderer
reported one additional shadow draw / 384 primitives in both passes; camera and
scene invariants were unchanged. This tiny engine-reported submission difference
is retained in the evidence rather than hidden. Its cause was not independently
established, so multi scaling is not claimed to have perfectly identical submissions.

### Memory

Engine-reported texture allocation, including render targets, fell consistently
when MSAA or scale fell and returned when restored. Values below use the small
workload; larger is identical, multi adds 0.136 MiB, and busy adds 69.05 MiB.

| Mode | Texture allocation MiB | Difference from 4×/100 |
| --- | ---: | ---: |
| 4× / 100 | 288.95 | — |
| 2× / 100 | 265.83 | −23.13 |
| Off / 100 | 245.58 | −43.38 |
| 4× / 85 | 274.76 | −14.20 |
| 4× / 75 | 261.63 | −27.32 |

Scale also lowers buffer allocation by approximately 2.27 MiB at 85% and 3.34 MiB
at 75%. MSAA-only buffer changes are negligible. These are global engine allocation
counters, **not physical VRAM residency**, driver budget or a per-target memory
breakdown. Texture content and mesh assets are constant within each workload.
The 85%/75% buffers contain roughly 28%/44% fewer 3D pixels, but shadow atlas size,
geometry submission and the 2D compositor are unchanged. Pixel count reduction
therefore should not be read as an equivalent whole-frame speedup.

## Native visual evidence

All paths are under `test-results/pixel-cost/20261108-164748/`:

- Untouched **1280 × 900** normal-stack full frames:
  `<small|dense|multi|busy>-r1-msaa<0|2|4>-scale100.png`, plus `msaa4-scale85/75`.
- Untouched clean full frames: `<workload>-clean-msaa<0|2|4>-scale100-fxaa0.png`;
  `msaa2-scale100-fxaa1.png` is the FXAA-only comparison. Clean scale frames also
  include `msaa4-scale85/75-fxaa0.png`. No clean-frame timing is mixed above.
- `native-crops/small-normal-msaa-flipper-terrain.png` compares Off / 2× / 4×.
- `native-crops/small-normal-msaa-character-rings.png` and
  `small-normal-msaa-thin-scenery.png` cover the ball silhouette, rings and foliage.
- `native-crops/dense-clean-msaa-elevated-rails.png` covers the authored elevated
  rails, narrow edges and rings in the whole-Act view.
- `native-crops/busy-normal-msaa-diagonal-rail-scenery.png` and
  `busy-normal-msaa-contrast-edge.png` cover Chemical diagonals and thin supports.
- `native-crops/small-clean-msaa-contrast-silhouettes.png` covers high-contrast
  goal/star and enemy silhouettes. `small-clean-fxaa-thin-scenery.png` compares
  2× / 2×+FXAA / 4× without changing shadow filtering.
- `native-crops/small-normal-scale-character-rings.png` compares 100 / 85 / 75%.
  Matching HUD crops are included. Region coordinate text files make extraction
  reproducible with `tools/crop_pixel_cost.ps1`.

Individual crops are exact integer pixel extractions. Panels only add labels and
place those crops side-by-side at **1:1**; neither crops nor full frames are resized,
sharpened or recolored. View at 100%, rather than judging a browser's scaled preview.

Observed at native size: Off visibly stair-steps the diagonal flipper and thin
foliage, especially clean. 2× removes much of that; 4× slightly refines boundary
coverage, but the normal Retro stack makes the 2×/4× difference subtle. Clean rail
and goal edges show the extra coverage more clearly. MSAA does not remove the
normal Retro texture/scanline treatment. FXAA softens some remaining steps but also
softens fine foliage and hardware detail; it is not an unqualified quality upgrade.

85% introduces mild additional softness; 75% makes small rings and outlines more
diffuse. HUD glyph sizing/sharpness remains intact, although its translucent panel
still shows the changing world behind it. These stationary captures cannot establish
moving-edge shimmer, camera-motion stability or flipper/ball readability during play.

## Recommendation candidates, not defaults

**2× is the first laptop comparison candidate:** it preserves most observed static
edge quality under normal Retro and saves about 23 MiB of reported texture allocation.
The desktop GPU saving is small. This evidence does not establish that 4× has poor
value on every device, or justify silently replacing it; its visible benefit here
is modest and so is its measured GPU cost.

**85% native scale is a plausible optional low-end lever**, with 75% a more visible
compromise. The route is clean and preserves HUD/camera/physics; whether its GPU and
memory savings improve laptop frame times remains unproven. Keep it independent
of MSAA when comparing. Off is useful as a diagnostic lower bound, with visible
edge-quality cost. No combined MSAA/scale default or preset was selected.

On the work laptop, use the refreshed **Compare Prototype pixels.cmd**, leave
Smooth Shadows off, and hold shadow resolution/cascades, Retro, atmosphere, camera,
Act pool and window resolution fixed. Wait after each switch. Compare 4×/100 with
2×/100 first, then 4× at 100/85/75. Check moving diagonal rails, thin scenery, rings,
flippers and ball outlines, both served and in motion; include a join with multiple
resident Acts. Record device/power mode and frame tails, not only the FPS counter.
Laptop validation is follow-up evidence, not a blocker for this audit.

## Verification and delivery

- Re-ran the supported **32-suite / 8,596-check baseline**, with zero assertion
  failures, plus Act geometry's six fresh-process reload checks. The 12 graphical
  baseline suites use Forward+/Vulkan; remaining logic/geometry checks are headless.
  Logs: `test-results/regression-debt/pixel-*`; the correct 40-variant Prototype
  audit is `test-results/pixel-cost/prototype-audit.log` (**425/425**).
- New pixel-ownership test passed **58 checks** on Forward+/Vulkan, covering all
  nine MSAA/scale combinations, atomic rejection, existing/late views, unsaved state,
  FXAA independence, F6/F7 handlers and exact layout/gameplay preservation through
  source Prototype, disk Prototype and source Endless. A second successful 58-check
  run covers disk-loaded Endless after refreshing its separate pool; repeated
  checks are not counted as additional coverage. Logs: `quality.log` and
  `quality-disk-endless.log` under `test-results/pixel-cost/`.
- Existing device-shadow suite passed **135 checks**, including live atlas/cascade
  settings and atmosphere independence. No shadow defaults or controls changed.
- Isolated export snapshot imported without script errors; both Windows release
  executables exported successfully using the existing local template. PowerShell
  syntax checks passed. All 44 measurement/visual full frames were saved natively;
  representative full frames and 1:1 panels were visually inspected.
- The actual exported Geometry Editor executable passed the portable three-resident
  Prototype smoke test with `--pixel-controls`: F6 cycled Off/2×/4× across foreground
  and backdrops; F7 cycled 75/85/100 with unchanged layout/compositor. It restored
  4×/100 and exited successfully. These are automated control-handler checks, not
  a physical keyboard or laptop test. Logs: `test-results/pixel-cost/portable.*`.
- Original unrelated tracked diffs were compared with the pre-task binary diff and
  remained identical. No authored Act or artwork is staged with this change.

The first generic bake-audit invocation selected the old 56-variant Endless pool
instead of Prototype and correctly rejected its stale receipts. The explicit
`--prototype` audit passed all 40 refreshed variants. Cache refreshes are ignored
generated data; they do not rewrite source Acts. The separate Endless refresh then
rebuilt **56 variants**, and its audit passed **489/489** (`endless-audit.log`).
Root-certificate diagnostics,
intentional malformed-resource/archive-write tests, and existing ObjectDB cleanup
warnings are distinguished from assertion failures. The discarded Vulkan device
loss is recorded above; successful final profiling had no renderer/script errors.

Portable archive:
`test-results/authoring-tools/Sonic Spinball Authoring Tools-20261108-165243.zip`
(234,385,291 bytes). Extract to a writable folder and launch **Compare Prototype
pixels.cmd**. Both executables include current local artwork and source Acts;
the authoring archive deliberately excludes disk bakes. Existing external Acts and
Atmospheres are preserved. The ordinary executables retain their original defaults.
