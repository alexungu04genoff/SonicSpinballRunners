# Eight-theme production identity review

Final review: **2026-11-08**, against baseline `6a723e68`. See [the audit, changes and verification](../THEME_IDENTITY.md). These are actual Prototype captures with validated disk bakes, current selected artwork and matching Act/camera/atmosphere/settings. The commit preserves separately owned uncommitted artwork; the capture provenance records that dependency.

## Four calibration themes

Each pair contains native 1440 × 1000 before/after frames, with a label strip. Open the adjacent `-before.png` or `-after.png` file if a viewer shrinks the pair.

| Theme | Full comparison | Native detail comparisons |
| --- | --- | --- |
| Green Hill | [Before / after](review-20261108/green_hill-pair.png) | [Sunflower](review-20261108/details/green_hill-sunflower-pair.png), [loop](review-20261108/details/green_hill-loop-pair.png) |
| Rooftop Run | [Before / after](review-20261108/rooftop_run-pair.png) | [Clock](review-20261108/details/rooftop_run-clock-pair.png), [roof and chimney](review-20261108/details/rooftop_run-roof-chimney-pair.png) |
| Sky Sanctuary | [Before / after](review-20261108/sky_sanctuary-pair.png), [matched cloud pan](review-20261108/sky_sanctuary-sky-edge-pair.png) | [Leaves](review-20261108/details/sky_sanctuary-leaves-pair.png), [clouds](review-20261108/details/sky_sanctuary-sky-edge-clouds-pair.png) |
| Aquarium Park | [Before / after](review-20261108/aquarium_park-pair.png) | [Fish](review-20261108/details/aquarium_park-fish-pair.png), [lantern](review-20261108/details/aquarium_park-lantern-pair.png) |

## Final production comparison

- [All eight themes at native pixel scale](review-20261108/eight-themes-native.png): 2880 × 4260, four rows of two unscaled frames. Rows: Green Hill/Rooftop, Sky/Aquarium, Chemical/Casino, Ice/Lava.
- [Compact overview](review-20261108/eight-themes-overview.png): downsampled navigation sheet, not the detail-review authority.
- Other full pairs: [Chemical Plant](review-20261108/chemical_plant-pair.png), [Casino Night](review-20261108/casino_night-pair.png), [Ice Cap](review-20261108/ice_cap-pair.png), [Lava Reef](review-20261108/lava_reef-pair.png).

Green Hill, Ice Cap and Lava Reef received no identity edits. Small framebuffer differences across independent runs are not claimed as art changes.

## Receipts and limits

[Source scope](review-20261108/source-scope.json) records the six restored constructor files and hashes. [Pair index](review-20261108/index.json) records original image hashes. [Crop coordinates](review-20261108/details/coordinates.json) specify integer rectangles at scale 1. Four `*-manifest.json` files record runtime state, validated bake loads and graphics settings; four `*-provenance.json` files record source state. The exporter refuses mismatched captures or changes to the recorded 4× MSAA, 100% scale and default shadow settings.

The current pass already matched the requested fictional late-90s pipeline; completion added verification and review tools, not further shape changes. Still review Chemical floor/Ring competition, Lava hardware separation and Sky clouds in motion. The spawn camera clips some landmarks; these frames do not certify every authored Act or atmosphere. Earlier local captures are preserved outside `review-20261108` and are not the final comparison set.

The supported baseline passed again: [32 suites / 8,596 checks / zero assertion failures](review-20261108/verification.json). See the main identity document for focused decor tests, capture validation, bake audits and known diagnostic limitations.
