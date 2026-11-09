# Lava Reef — matched floor values and mineral treatment

Phase 2 revision requested by Alex: keep the approved orange timber with rock insets, darken the top floor, lighten the lower floor, and bring their rock styles toward a shared middle ground. This explicitly reopens the value and mineral treatment of retained selection 1C. Stable IDs remain 1C and 5B.

## Result

- **1C:** Brighter ochre boulder faces with broad copper facets and muted plum joints. The periodic construction of the current production floor supplies the existing boulder layout.
- **5B:** Darker orange timber with the approved plank pattern and inset cluster positions. Its rocks use the same palette, facet coloring and broad bevel treatment as 1C. The previous pale-yellow faces and thin dark outlines are replaced.
- **3B and 9B:** The approved warm charcoal wall and dark iron-and-brass facade PNGs are reused unchanged. All other selections remain unchanged.

`balanced.gdshaderinc` shares one mineral shading function between the two materials. `render.gd` combines it with the existing timber construction, renders at 1024 x 1024, and downsamples to 512 x 512. Repeated previews copy the final PNG pixels into a 2 x 2 layout. No additional material maps are generated.

The mean Rec.709-weighted sRGB signal was approximately 0.331 for the previous lower floor and 0.479 for the previous timber floor. Both revisions are approximately 0.405, the midpoint. This is an albedo comparison metric, not a photometric luminance or in-game lighting measurement. `render-receipt.json` records the values and the solved gains. The rock gain is shared; only the timber contribution is adjusted independently.

## Review

- `balanced-comparison.png`: Previous and revised generic unlit studies, with identical geometry, camera, and mapping. This is not a gameplay screenshot.
- `floor-review.png`: Both source albedos and their reduced 2 x 2 repeats.
- `1C.png`, `5B.png`: Revised source images; corresponding `-repeat.png` files preserve the repeated native pixels.

The graphical Godot export completed and both review images were inspected. The repeat previews show no obvious hard boundary seam; the two timber inset clusters remain visibly periodic. The study retains the previous mapping, so the top-floor inset rocks remain smaller than the ground boulders. In-game appearance and mapping remain for a later phase.

All 12 production-source hashes match the Phase 1 baseline. Godot emitted its existing certificate-store startup error, but image generation completed. No production integration, headless checks, regression suite, build, benchmark, commit, or push was performed.

Await texture approval before integration. The earlier timber revision remains available for comparison.
