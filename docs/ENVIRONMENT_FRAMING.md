# Gameplay-camera environment framing — 2026-10-31

The accepted review views keep the Prototype camera's 50° elevation, 52° FOV and 1.3 zoom, then pan toward the left and right course edges. These are scenery inspection references, not changes to the live camera. Centered follow and overview images remain secondary checks. The pass preserves authored terrain, collision, physics, scoring and camera behavior.

## Local scenery follows the actual Act

The first composition draft exposed a real streaming limitation: shared Zone backgrounds are baked against a synthetic 600×1800 rectangle. A boundary query there still returns that rectangle, even when the visible Act curves inward. Reverse C Spring made the resulting empty strip particularly obvious in Casino Night.

`build_edges()` now runs during each Act's bake, while the presenter still has its actual authored floor outline. `scenery_side_edge()` samples that outline across a prop's longitudinal footprint, including bends and interval endpoints. It leaves a deliberate gap without using the Act's maximum width as the local edge. Broad props conservatively clear the portion of the outline they occupy; far scenery may still use broader bounds.

Local scenery records remain inside the existing Act recipe and carry a `background` flag. The static batcher separates foreground and background groups while retaining material sharing, instance buffers and spatial batching. Live attachment routes these records into the existing Zone background viewport at the Act's world offset. They inherit that Zone's visibility and processing, render behind the opaque course, and retire with their owning Act. There is no extra viewport, live geometry rebuild, per-frame boundary query or new lighting system.

`build_background()` continues to produce the shared ocean, cloud sea, lake, reservoir and distant skyline. Aquarium Park and Lava Reef composition remain unchanged. Bake version 7 invalidates old recipes; run both **Bake Prototype** and **Bake Endless** after pulling this change. Sidecars are derived, ignored files, not authored Act edits.

## Composition

| Theme | Result |
| --- | --- |
| Green Hill | Two low, staggered headlands per Act, with a palm, reused turf loop, flowers and one small rock/flower islet. Beaches and ocean channels separate them from the course. Far islands and cloud puffs are reduced. |
| Ice Cap | Nearby ridge pairs, shelves, crystals/pine and an arch. Two short aurora curtains per Act follow the sampled side contours, 0.30 world units outside the edge. The existing bounded shader is unchanged; the 48×4 mesh is shaped only during baking. The lake/reflection and sparse snow remain shared. |
| Sky Sanctuary | Two narrow broken floating ruins per Act, with columns, arches, vines and detached masonry. No broad base slabs or underside cones; visible cloud gaps preserve open air. Cloud sea and orbital silhouette remain distant. |
| Chemical Plant | One nearby tank and short connected pipe run per side. Short runs avoid recreating a bounding-box edge along curved Acts. Fewer distant factory blocks; purple reservoir remains open between structures. |
| Rooftop Run | Existing canals and skyline retained. Two facade/garden groups per Act now use its local outline rather than the shared rectangle. |
| Casino Night | Existing star/reel landmarks and neon palms moved beside the local contour. One group per side; palace and skyline remain distant. Existing two fill lights are retained; none added. |
| Aquarium Park / Lava Reef | Both approved edge views inspected. No composition changes. Lava's separate shader appearance issue remains outside this pass. |

All local scenery is shadowless. The foreground and its shadows are unchanged. Some stationary review ball positions intersect existing foreground decorative props; these images judge external scenery, not whether those diagnostic positions are playable lanes.

## Lightweight performance comparison

RTX 4060, Godot 4.7.2, Forward+/Vulkan, 1280×900 window and 673×473 world viewport. Seed 18, Reverse C Spring opening, three resident Acts, existing retro stack and four shadow cascades. Each row is one 120-frame sample after settling, with screenshot readback outside the sample. Before/after camera transforms match exactly.

These are **generated diagnostic scenes** (`--no-bakes`), so submission totals do not include the additional offline static-bake optimization. They compare the composition change within the same path; they are not final baked-game FPS claims. Short sequential timing samples vary with workstation load. Draw totals and measured GPU time show a small cost either way; the much larger frame/CPU timing differences should not be credited to moving scenery. Screenshot FPS labels can include preceding capture/preparation stalls.

Values below are **before → after**. Frame and GPU values are milliseconds.

| Theme / edge | Frame median | Frame p95 | Render GPU | Draws | Rendered objects |
| --- | ---: | ---: | ---: | ---: | ---: |
| Green Hill / left | 10.02 → 7.32 | 16.76 → 9.42 | 0.671 → 0.680 | 4352 → 4355 | 4728 → 4731 |
| Green Hill / right | 13.30 → 8.62 | 20.24 → 13.22 | 0.709 → 0.713 | 5567 → 5559 | 5993 → 5985 |
| Ice Cap / left | 7.79 → 4.33 | 10.97 → 5.86 | 0.690 → 0.692 | 1385 → 1400 | 3749 → 3767 |
| Ice Cap / right | 6.74 → 4.50 | 9.11 → 5.91 | 0.695 → 0.702 | 1585 → 1595 | 4610 → 4618 |
| Sky Sanctuary / left | 8.85 → 4.46 | 13.72 → 5.49 | 0.727 → 0.718 | 1447 → 1432 | 5635 → 5623 |
| Sky Sanctuary / right | 7.47 → 4.95 | 11.49 → 6.78 | 0.729 → 0.720 | 1622 → 1609 | 6974 → 6961 |
| Chemical Plant / left | 8.24 → 4.76 | 12.48 → 8.00 | 0.649 → 0.653 | 1378 → 1371 | 2749 → 2742 |
| Chemical Plant / right | 7.77 → 4.46 | 10.66 → 5.11 | 0.688 → 0.690 | 1671 → 1668 | 4107 → 4104 |
| Rooftop Run / left | 7.42 → 4.78 | 10.03 → 8.46 | 0.719 → 0.722 | 1417 → 1432 | 3327 → 3339 |
| Rooftop Run / right | 8.18 → 4.89 | 11.18 → 6.68 | 0.760 → 0.763 | 1762 → 1773 | 5152 → 5160 |
| Casino Night / left | 7.96 → 4.78 | 11.01 → 5.99 | 0.811 → 0.809 | 1510 → 1507 | 5545 → 5552 |
| Casino Night / right | 7.00 → 4.72 | 10.17 → 5.21 | 0.811 → 0.813 | 1720 → 1725 | 6569 → 6584 |

The largest increase here is 15 draws (about 1.1%); visible scenery is closer and stronger without a material GPU-time increase in these samples. This does not establish whole-run performance or first-use preparation cost. Raw reports, render CPU timings, logs, source snapshots and screenshots are under ignored `test-results/environment-framing/` (`before-edges`, `final-edges` for unchanged-theme baselines, and `local-edges`).

## Verification and remaining limits

- Inspected both accepted edge views in all eight Zones. Rechecked all six changed themes after switching local scenery to authored outlines.
- Rebuilt all 40 Prototype and 56 Endless Act/theme variants successfully. Local derived bake files are ready to use.
- Inspected baked Sky Sanctuary in Reverse C Spring, Secret Entry and RampMania, and baked Ice Cap in RampMania, SpringUp and First Try Smooth Decor. Together these cover all five Prototype Act sources. Also checked both baked Green Hill edge views. Each review loaded three Act recipes from disk, with zero runtime rebuilds and zero misplaced background records.
- Existing `endless_batch_regression.gd`: 111 checks, zero failures. Existing `endless_scene_smoke.gd`, requiring bakes and crossing six Act boundaries: 87 checks, zero failures, including two Zone changes. Repeated the latter headlessly after tightening retirement ownership; the same 87 checks passed. No dedicated regression suite was added.
- The rendered streaming smoke recorded one 139 ms frame; this short pass does not establish hitch-free streaming. Shutdown diagnostics still report four zero-reference `RefCounted` objects, and the final headless run reported one dummy-renderer mesh RID. No leaked scenery nodes were reported. These exit diagnostics remain unresolved; they are not evidence of clean resource teardown.

The baked images and reports are in ignored `test-results/environment-framing/baked-review/`. Human review of movement, scenery rhythm and final art direction remains the next useful check; the live camera and gameplay were not retuned.
