# Ice Cap — Phase 1 texture choices

Status: Phase 1 choices locked. Alex selected `1A 2B 3A 5A 6A 7B 8A 9A 10C 11A 12B`, with explicit repetition concerns for 1A, 5A and 12B. Phase 2 assets and repeated previews are in `../ice_texture_refined/`; those assets are now approved and provisionally integrated for Phase 3. These Phase 1 files remain historical concept studies, not production assets.

The shader-to-PNG pass produced 22 A/B studies. There were two successful visual generation passes; an earlier shader compile failure was corrected before visual review. No C texture was generated. No normal, height, roughness, AO, metallic or emission maps were created. Production source, geometry, lighting, atmosphere and imports are not edited by these scripts. Nothing is committed or pushed.

## Current-material authority

`scripts/themes/ice_cap_theme.gd` calls `theme_definition.gd::_apply_texture_set()`. `terrain_texture_sets.gd` binds the seven existing PNG sets in `assets/textures/ice_cap/` through `terrain_texture.gdshader`. No selected/approved override exists for Ice Cap. `current-assets.json` records the observed source hashes.

| Role | C source / geometry |
| --- | --- |
| 1 Bottom floor | `floor.png`; broad world-mapped ground, 8 × 8 world-unit repeat. |
| 2 Bottom floor border | `floor-border.png`; contour-following strip, width 6 physics pixels. |
| 3 Walls | `wall.png`; extruded vertical terrain sides, 4 × 1.6 world-unit projection. |
| 4 Wall ledges / transition caps | N/A as an independent surface. `_prism()` creates top and vertical side surfaces, without a separate bevel. Tops and horizontal perimeter strips are roles 5 and 6. |
| 5 Second-floor surfaces | `top.png`; elevated top faces, 8 × 8 world-unit repeat. |
| 6 Second-floor borders | `top-border.png`; separate horizontal contour strips, width 4 physics pixels. |
| 7 Ramp decks | `ramp.png`; route-mapped deck, 8 × 8 world-unit repeat. |
| 8 Ramp railguards | Existing `ice_cap_decor.gd` snow material, base `#cfdfeb`, roughness 0.93, specular 0.18. This is the ramp `edge` binding. |
| 9 Exterior facades | `facade.png`; outer under-floor cliff skin, not a building facade. The existing consolidated upper part uses the wall material. |
| 10 Crystal props | `ice_crystal.gdshader`; opaque glossy blue with a cyan view-dependent rim and emission, no PNG. |
| 11 Evergreen foliage | Existing `ice_cap_decor.gd` pine material, base `#254f57`, roughness 0.93; separate geometric snow caps. |
| 12 Frozen lake | `ice_lake.gdshader`; background lake with animated reflection bands and the published Ice Cap atmosphere palette. |

C panels show the unchanged source albedo or the exact source base-color chip. Shader-only C entries are documented rather than reconstructed. These are not gameplay screenshots; atmospheric tint, lighting, gloss and view-dependent effects are not represented by flat albedo swatches. The source materials were inspected; no claim of a new disk-bake freshness audit is made.

## Reference interpretation

- Supplied sheet 1: staggered blue-violet crystal clusters, packed diamond mosaics, white snow lips and vertical icicle curtains.
- Supplied sheet 2: thick snow over crystalline cliffs, ice slides, sparse warm industrial collars.
- Supplied sheet 3: chamfered cut-ice blocks, diagonal inclusions, pale vertical columns and jewel modules.
- Cool Edge: broad blue glacier faces, quiet snow routes, thick snow overhangs and sparse floating snow shelves. Reference screenshots were viewed in the browser, not downloaded or used as assets.
  - https://en.sonicscanf.org/gallery/den/cool-edge-4/
  - https://en.sonicscanf.org/gallery/den/cool-edge-6/
  - https://en.sonicscanf.org/gallery/noch/cool-edge-10/
  - https://sonicscanf.org/gallery/sony-playstation-3xbox-360/sonic-unleashed-holoska/
  - https://en.sonicscanf.org/gallery/noch/cool-edge/

The foliage proposals extrapolate snow coverage and frost placement onto the existing conifers; the supplied sheets do not provide conifer artwork. Existing C remains the stronger choice there. Crystal and lake C also retain useful material response that flat textures cannot replace.

## Review and limits

`board-1.png` covers roles 1–3; `board-2.png` covers 5–7; `board-3.png` covers 8–9; `board-4.png` covers 10–12. Each role also has a separate `choices-N.png`.

Rendered with Godot's graphical Compatibility renderer, then visually inspected. The isolated render reported shader-cache-directory and Windows root-certificate-store errors; it successfully wrote all 22 final PNGs without shader compilation errors. No regression suite, headless check, benchmark, production build or game capture was run.

Physical feature scale, exact UV placement, seam finishing and gameplay-camera evaluation remain later-phase work. Ramp sides require route/deck-width mapping when integrated. Printed faceting must not replace the existing crystal silhouettes. Foliage motifs still read too much like repeated sprigs; retain C unless that direction is explicitly reopened.

To reproduce A/B only, run `bake.gd` graphically with Godot, then `compose.ps1`. The composition reads C directly from production assets. Do not run historical production texture bakers. Stop here until a vote such as `1A 2C 3B 5A ...`; role 4 needs no vote.
