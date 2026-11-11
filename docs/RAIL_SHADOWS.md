# Spatial rail support shadows — 2026-11-11

Elevated rails now combine eligible support-post shadow geometry in small local
groups. This follows the [rigid gimmick pass](GIMMICK_SHADOWS.md), with no GI,
lighting, shadow-resolution, cascade, material or gameplay changes.

## Scope and culling

The shared helper accepts an optional cell width. Rails use 2-unit cells in their
parent's X/Z plane, equivalent to 200 authored pixels. Only compatible rigid
siblings in the same cell share a caster. A source wider than one cell stays
independent, bounding a combined footprint to at most twice the cell width.
This avoids joining distant supports along an entire winding route. Groups can
still submit some neighboring posts together; per-post culling is coarser within
each small group.

Visible source meshes and materials remain intact. The existing opaque standard
material and render-state eligibility checks still apply. The long deck, guards,
fascia, underside and Chemical Plant pipes retain their original shadow paths.
The entry marker is explicitly excluded: re-encoding its sloped normal introduced
a small quantization difference in the initial trial. Post triangles, winding
and normals are retained, including under transformed or mirrored parents.
Extra shadow-only meshes trade memory and construction work for fewer draws;
grouping runs during source construction/baking, with no per-frame grouping.
Existing gimmick callers retain their original behavior without a cell limit.

## Measurements

Godot 4.7.2 `ed1daf0bf`, Forward+/Vulkan on Linux llvmpipe, 800×600, 4× MSAA,
8192 directional shadow atlas and four cascades. The controlled U-shaped rail
fixture compares original and combined casters in the same process, using an
overview, close view and close view with low sun.

| Theme | Overview total draws, original → combined | Whole RampMania caster surfaces, before → after |
| --- | ---: | ---: |
| Green Hill | 107 → 75 | 248 → 227 |
| Chemical Plant | 139 → 107 | 262 → 241 |
| Rooftop Run | 107 → 75 | 244 → 223 |
| Casino Night | 107 → 75 | 249 → 228 |
| Sky Sanctuary | 107 → 75 | 249 → 228 |
| Ice Cap | 107 → 75 | 249 → 228 |
| Lava Reef | 107 → 75 | 256 → 235 |
| Aquarium Park | 107 → 75 | 244 → 223 |

All **24 rendered comparisons are pixel-identical**. Total fixture draws decrease
23.0–29.9% in overview and 8.2–14.7% in the close views. The unchanged custom
surfaces make Chemical Plant's relative saving smaller. Shadow triangle counts
are unchanged. RampMania's 21-surface saving per theme is a disk-bake inventory,
not a per-frame draw count. These results do not measure whole-game Windows FPS.

[Machine-readable evidence](rail-shadows/receipt.json) records every rendered
comparison and the before/after inventory. Green Hill images:
[overview original](rail-shadows/green_hill-original-0.png),
[overview combined](rail-shadows/green_hill-combined-0.png),
[low sun original](rail-shadows/green_hill-original-2.png), and
[low sun combined](rail-shadows/green_hill-combined-2.png).
These are isolated rail captures. The previous full Prototype software-Vulkan
capture timed out at 180 seconds; that limitation remains. Canonical Windows
appearance review and GPU/frame-time measurements are still needed.

## Verification and reproduction

The rail regression checks all eight themes on straight, curved and negative
coordinate routes, including translated, rotated and mirrored owners. It checks
source resource identity, visible geometry, shadow geometry/normals, bounded
groups, unchanged authoritative paths, repeat application and recipe rebuilding.
Float geometry comparisons use a distance tolerance of 0.00001 to account for
translation being baked into vertices before a parent transform; snapped-string
equality can disagree at a rounding boundary even for sub-micro-unit differences.

All **2,365 targeted assertions pass**: rail geometry (171), existing gimmick
shadows (1,450), ramp height/themes (100), ordinary/streamed rail Rings (13/10),
device shadows (135), manifests (30), retirement (72), material attachment (112),
reuse (130), all-eight-theme Prototype authority (70), and Green Hill/Rooftop
foreground contribution (36 each). All eight RampMania variants and both themes'
Prototype and Endless pools bake successfully. These checks report no engine or
script errors. Existing source-image loading warnings and the threaded-loader
ObjectDB shutdown warning remain outside this change.

The seed-18 Green Hill streaming tour reaches sequence 3 at 400 px/s with zero
boundary waiting and zero fallback builds. Its maximum scheduler work is
75.167 ms; this is a lifecycle check, not an A/B frame-time improvement claim.

Use the pinned Godot executable with the repository as the working directory:

```text
godot --headless --path . --script res://tests/rail_shadow_regression.gd
godot --path . --rendering-method forward_plus --rendering-driver vulkan --script res://tests/rail_shadow_capture.gd
```

**Re-bake Prototype and Endless after pulling.** Source fingerprints invalidate
old recipes; their format stays version 9. `--profile-original-rail-shadows`
after `--` disables this pass during construction/baking. It cannot undo an
already-combined disk recipe. The older `--profile-original-gimmick-shadows`
switch disables the shared helper, including rails. The isolated capture builds
its own original/combined pair; run it without these diagnostic switches.
