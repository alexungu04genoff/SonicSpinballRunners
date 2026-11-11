# Rigid gimmick shadows — 2026-11-11

The shadow-only pass starts at `29093fe`. Gates, switches, springs, drop-target
sockets, lane hardware, diverters and dash panels now combine eligible rigid
siblings into one shadow-only mesh per parent/render-state group. Their visible
meshes, material slots and emitter references stay intact. No GI, baked lighting,
shadow-quality reduction, camera change or physics change is involved.

## Why this target

An eight-theme RampMania inventory found identical overall and caster AABBs.
Separating shadowless decoration from those bounds therefore offered no tighter
coverage in this fixture. Existing Act visibility and bumper/flipper shadow
combining remain in place. Gimmicks still submitted numerous small shadow pieces,
so this pass extends the same principle to that concrete remaining workload.

`gimmick_models.gd` alone opts into `gimmick_shadows.gd`. It recurses between rigid
parents but never merges across them: an opening gate panel, rotating diverter,
pressed switch, shrinking target or compressed spring retains its own transform
and visibility. The independently scaled Slingshot rubber is explicitly excluded;
its rotated arrows also remain separate, so Slingshots currently get no reduction.

Eligibility reuses the existing conservative mesh/state checks. Only opaque
StandardMaterial3D surfaces with ordinary back-face culling qualify. Alpha,
billboards, grow/height effects, next passes, custom shaders, rotated/scaled leaves,
overlays and unsupported geometry retain their original casters. The combined
mesh preserves every eligible triangle, its winding and normal; normals matter
for shadow bias. Color/emission animation continues on the original visible nodes.
The bake path uses the existing primitive-detail policy for matching silhouettes.

## Measurements

Godot 4.7.2 `ed1daf0bf`, Forward+/Vulkan, Linux llvmpipe, 800×600, 4× MSAA,
8192 directional shadow atlas and four cascades. Each hardware fixture contains
the nine supported gimmick kinds. The same process captures original and combined
casters in normal, activated/open, and low-sun/completed states.

| Theme | Normal-pose total draws, original → combined | Whole RampMania caster surfaces, original → combined |
| --- | ---: | ---: |
| Green Hill | 258 → 161 | 302 → 248 |
| Chemical Plant | 264 → 149 | 320 → 262 |
| Rooftop Run | 288 → 153 | 312 → 244 |
| Casino Night | 261 → 154 | 303 → 249 |
| Sky Sanctuary | 261 → 154 | 303 → 249 |
| Ice Cap | 261 → 154 | 303 → 249 |
| Lava Reef | 282 → 175 | 310 → 256 |
| Aquarium Park | 294 → 155 | 314 → 244 |

All **24 rendered comparisons are pixel-identical**. Total fixture draws fall
30.4–47.3% across the tested states. The RampMania column is an inventory of
caster surfaces, not per-frame shadow draws. Full-game improvement depends on
which mechanisms and cascades are visible. This is no Windows FPS measurement.
Additional shadow meshes trade some memory and preparation for fewer submissions.

[Machine-readable evidence](gimmick-shadows/receipt.json) includes all poses,
renderer metadata and the eight-theme inventory. Green Hill review images:
[normal original](gimmick-shadows/green_hill-original-0.png),
[normal combined](gimmick-shadows/green_hill-combined-0.png),
[low sun original](gimmick-shadows/green_hill-original-2.png), and
[low sun combined](gimmick-shadows/green_hill-combined-2.png).
These isolated hardware captures are not canonical Prototype captures.

## Verification and reproduction

`gimmick_shadow_regression.gd` passes 1,450 assertions across eight themes, nine
mechanisms, source/bake detail and three live states. It compares visible and
shadow geometry/normals, source resource identities, recipe reconstruction,
repeat application and unsupported-material fallbacks. The full targeted pass
totals **2,283 assertions**, including original pinball shadows, authored/routing
gameplay, device shadow settings, manifests, retirement, material attachment,
reuse, Green Hill/Rooftop contribution, and all-eight-theme disk-backed Prototype
authority. The authored reload test deliberately produces three malformed-file
errors; all other checks report no engine/script errors.

All eight RampMania variants and both Green Hill/Rooftop Prototype and Endless
pools bake successfully. The seed-18, 400 px/s Green Hill tour reaches sequence 3
with zero boundary waits and zero fallback builds. It overlaps a software GPU
capture, so its timings are not a controlled CPU comparison. The existing
threaded-loader ObjectDB shutdown warning remains outside this change.

The full canonical Green Hill Prototype capture timed out after 180 seconds on
software Vulkan; it is not counted as a pass. Windows gameplay appearance and
GPU/frame-time verification remain outstanding. The 24 successful images above
cover the isolated changed hardware with unchanged rendering settings.

Use the pinned Godot executable, with the project as the working directory:

```text
godot --headless --path . --script res://tests/gimmick_shadow_regression.gd
godot --path . --rendering-method forward_plus --rendering-driver vulkan --script res://tests/gimmick_shadow_capture.gd
```

**Re-bake Prototype and Endless after pulling.** The normal source fingerprint
invalidates old geometry recipes; their format remains version 9. The diagnostic
`--profile-original-gimmick-shadows` after `--` disables combining during source
construction/baking. It does not undo casters in an already-combined disk bake.
For a full-scene A/B, build both diagnostic and normal recipes with the same
source, then restore normal recipes. The isolated capture performs its own A/B.
