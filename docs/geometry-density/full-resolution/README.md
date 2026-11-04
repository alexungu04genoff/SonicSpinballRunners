# Full-resolution geometry comparisons

Each original frame is **1440 × 1000**. Each side-by-side pair is **2880 × 1080**, including an 80-pixel label strip. The gameplay pixels are copied at **1:1**, without downscaling. Open the PNG at actual size or open an individual original if your viewer fits wide images to the window.

These are exports of the existing canonical Prototype captures, not new renders. The eight primary pairs have matching Act, served Ball, score, camera, seed, atmosphere and renderer receipts. The [overview sheet](../before-after.png) remains available.

| Theme | Full-resolution pair | Original before | Original after |
| --- | --- | --- | --- |
| Green Hill | [Pair](green_hill-pair.png) | [Before](green_hill-before.png) | [After](green_hill-after.png) |
| Chemical Plant | [Pair](chemical_plant-pair.png) | [Before](chemical_plant-before.png) | [After](chemical_plant-after.png) |
| Rooftop Run | [Pair](rooftop_run-pair.png) | [Before](rooftop_run-before.png) | [After](rooftop_run-after.png) |
| Casino Night | [Pair](casino_night-pair.png) | [Before](casino_night-before.png) | [After](casino_night-after.png) |
| Sky Sanctuary | [Pair](sky_sanctuary-pair.png) | [Before](sky_sanctuary-before.png) | [After](sky_sanctuary-after.png) |
| Ice Cap | [Pair](ice_cap-pair.png) | [Before](ice_cap-before.png) | [After](ice_cap-after.png) |
| Lava Reef | [Pair](lava_reef-pair.png) | [Before](lava_reef-before.png) | [After](lava_reef-after.png) |
| Aquarium Park | [Pair](aquarium_park-pair.png) | [Before](aquarium_park-before.png) | [After](aquarium_park-after.png) |

## Detail comparisons

Both sides use exactly the same crop rectangle. Small crops use labeled integer nearest-neighbor magnification: pixels are enlarged without smoothing, sharpening or invented detail. This cannot recover detail absent from the original gameplay-distance capture.

| Detail | Comparison | Source-pixel scale |
| --- | --- | --- |
| Green Hill sunflower | [Before / after](details/green-hill-flower.png) | 4× |
| Green Hill loop | [64 steps / final 16 steps](details/green-hill-loop.png) | 1× |
| Ordinary Rings and shadows | [Before / after](details/ring.png) | 4× |
| Round bumper | [Before / after](details/bumper.png) | 3× |
| Sky foliage | [Before / after](details/sky-foliage.png) | 2× |
| Aquarium roof, posts and lanterns | [Before / after](details/aquarium-architecture.png) | 1× |
| Aquarium repeated lantern | [Before / after](details/aquarium-lantern.png) | 3× |
| Sky cloud bank | [After only](details/sky-clouds-after-only.png) | 2× |

The loop comparison uses the already captured supplemental camera target `(570, 500)` on both sides. Its earlier frame isolates the original 64-step loop within the calibration worktree; it is not a complete historical before scene. The final frame also includes the documented face-normal/material-assignment correction. Full [64-step](supplemental/loop-64.png) and [16-step](supplemental/loop-16.png) originals are included.

**Cloud limitation:** the saved primary before/after camera does not expose the cloud bank. Only the later supplemental edge view does. Its [full after frame](supplemental/sky-edge-after.png) and crop are labeled after-only; no matched cloud comparison can be extracted from the existing data. The Aquarium comparison similarly covers the architecture visible in the primary frames, not every changed background landmark.

## Provenance and reproduction

- [Primary before receipt](../before-manifest.json) and [after receipt](../after-manifest.json)
- [Loop 64 receipt](../loop-64-manifest.json), [loop 16 receipt](../loop-16-manifest.json), and [supplemental edge receipt](../edge-manifest.json)
- [Export index](index.json): original SHA-256 hashes, source paths, crop coordinates, scale and labels
- Re-export from the retained local captures with `tools/export_geometry_comparisons.ps1`. This script only copies and arranges PNG pixels; it does not start Godot or change bakes.

The artwork and provenance limitations remain those described in the [geometry audit](../../GEOMETRIC_DENSITY.md).
