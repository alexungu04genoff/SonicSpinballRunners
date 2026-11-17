# Grounding evidence — 17 November 2026

[Investigation, decisions and measurements](../SCENERY_GROUNDING_INVESTIGATION.md) · [Thursday laptop instructions](../THURSDAY_LAPTOP_TEST.md)

**No production defaults changed. Zero production scenery proxies recommended.** Camera-right is an unsaved review candidate for Rooftop and Sky. “Keep production” in the overview deliberately repeats the original image for the other five themes.

These are labeled JPEG review copies of real Godot captures. Raw 1440×1000 visual PNGs, exact pixel comparisons, full instance inventories and original logs remain under `test-results/grounding-20261117/final/`. Performance images use 1280×900. JPEGs are not used to calculate pixel parity. Source artwork, colors, materials and atmosphere values are unchanged.

- [Seven-theme preferred comparison](seven-theme-comparison.jpg)
- [Live shadow ownership overlay](shadow-ownership.jpg)
- [Proxy alignment reveal](proxy-alignment.jpg)
- [Matched Prototype / Endless A–E](architecture-opening.jpg)
- [Zone overlap C / D / E / B](architecture-overlap.jpg)
- [Quality and renderer matrix](quality-renderers.jpg)
- [Individual Retro passes](retro-passes.jpg)

## Direction-only sweeps

Each sheet shows all seven directions, first with production Retro and then OFF. Camera, quality, color, energy, ambient and exposure remain fixed. Casino side-key elevation clamps from its production 80° to 75°; the other side-key elevations are retained. The 70°/20° controls use the camera-left azimuth.

| Theme | Seven-direction sheet |
| --- | --- |
| Green Hill | [Sweep](green_hill-sun-sweep.jpg) |
| Chemical Plant | [Sweep](chemical_plant-sun-sweep.jpg) |
| Rooftop Run | [Sweep](rooftop_run-sun-sweep.jpg) |
| Casino Night | [Sweep](casino_night-sun-sweep.jpg) |
| Sky Sanctuary | [Sweep](sky_sanctuary-sun-sweep.jpg) |
| Ice Cap | [Sweep](ice_cap-sun-sweep.jpg) |
| Aquarium Park | [Sweep](aquarium_park-sun-sweep.jpg) |

## Four representative proxy trials

All six modes use identical frozen edge-camera framing. Modes 1/3 use camera-right. Mode 4 is an expensive diagnostic ceiling. Each mode sheet includes production Retro and OFF; close crops use OFF to expose small changes. Source/hull sheets compare the selected source silhouette with per-component boxes. No proxy geometry was added to Green Hill, Casino or Aquarium; Lava is excluded.

| Theme | Six modes | Source versus hull | Edge/contact crop | Wall/floor crop | Normal-response crop | Gameplay-object crop |
| --- | --- | --- | --- | --- | --- | --- |
| Rooftop | [Modes](rooftop_run-six-modes.jpg) | [Methods](rooftop_run-source-vs-hull.jpg) | [Contact](rooftop_run-crop-edge-contact.jpg) | [Wall](rooftop_run-crop-wall-and-floor.jpg) | [Floor](rooftop_run-crop-floor-normals.jpg) | [Ball](rooftop_run-crop-ball-and-hardware.jpg) |
| Sky | [Modes](sky_sanctuary-six-modes.jpg) | [Methods](sky_sanctuary-source-vs-hull.jpg) | [Contact](sky_sanctuary-crop-edge-contact.jpg) | [Wall](sky_sanctuary-crop-wall-and-floor.jpg) | [Floor](sky_sanctuary-crop-floor-normals.jpg) | [Ball](sky_sanctuary-crop-ball-and-hardware.jpg) |
| Ice | [Modes](ice_cap-six-modes.jpg) | [Methods](ice_cap-source-vs-hull.jpg) | [Contact](ice_cap-crop-edge-contact.jpg) | [Wall](ice_cap-crop-wall-and-floor.jpg) | [Floor](ice_cap-crop-floor-normals.jpg) | [Ball](ice_cap-crop-ball-and-hardware.jpg) |
| Chemical | [Modes](chemical_plant-six-modes.jpg) | [Methods](chemical_plant-source-vs-hull.jpg) | [Contact](chemical_plant-crop-edge-contact.jpg) | [Wall](chemical_plant-crop-wall-and-floor.jpg) | [Floor](chemical_plant-crop-floor-normals.jpg) | [Ball](chemical_plant-crop-ball-and-hardware.jpg) |

The full-frame Chemical proxy difference is a narrow exterior-wall strip; it does not improve playfield contact. Exact bounds and all paired seven-direction pixel deltas are recorded in [measurements.json](measurements.json). The generic crop boxes intentionally stay identical across modes; a crop is an inspection location, not a claim that a new contact shadow exists there.

## Data and reproduction

[Compact measurements and counters](measurements.json) · [Verification receipts and limitations](verification.json) · [Per-phase frame distributions](timings.csv) · [Live ownership counts](ownership.csv)

The final desktop matrix is `final/matrix-final/Work-Laptop-20261117-214133` under the ignored evidence root. Its eight jobs completed. Full `report.json`, `samples.csv`, `captures.json`, `inventory.json`, `process.json`, `teardown.json`, startup checkpoints and console/error logs remain together. `final/lifecycle-final` contains the real crossfade/retirement check; `final/controls-package` and its generated Casino sibling contain actual F-key routing checks. `final/supported-baseline` records the supported 32-suite run, including its pre-existing failures. The pristine-base reproduction is separate from measurement data.

Rebuild the contact sheets on a build machine with Pillow and NumPy:

```powershell
python tools/summarize_grounding.py test-results/grounding-20261117/final test-results/grounding-20261117/evidence-final --preferred green_hill:0,chemical_plant:0,rooftop_run:2,casino_night:0,sky_sanctuary:2,ice_cap:0,aquarium_park:0 --matrix test-results/grounding-20261117/final/matrix-final/Work-Laptop-20261117-214133 --review-directory docs/grounding-20261117
```

The `--matrix` selection excludes exploratory/failed development runs from published timings. No image-error tolerance or benchmark timing is promoted into a permanent regression threshold.

Build-machine packaging uses PowerShell 7 (`pwsh`) and the installed Godot engine. Use `tools/package_grounding_lab.ps1 -BaseRevision a5722d5c1a4396b930069c92e3edd6665695323b -OutputDirectory <new-folder>` to reproduce the frozen source selection, validate/rebuild the private bakes with the grounding preparation tools, then run `tools/finalize_grounding_package.ps1 -ProjectRoot <folder> -ZipPath <new-zip>`. Never package the live shared working tree as an unrecorded replacement for the measured base. The portable CMD launchers themselves use Windows PowerShell 5.1 and need no build tools.
