# Lava Reef — Phase 1 texture choices

Historical Phase 1 choices. Alex has selected `1C 2A 3B 5B 6B 7A 8B 9B 10C 11C`, with a slight 1C simplification and a confirmed 6B rework. Phase 2 review assets now live in `../lava_texture_refined/`. No integration, new response maps, commit, or push is authorized yet.

The four `board-*.png` images contain A/B albedo studies and current C evidence. Individual `choices-N.png` panels and the original A/B PNGs are available alongside them. `patterns.gdshader` and `bake.gd` implement the existing ColorRect/SubViewport shader-to-PNG workflow. They never write to production texture folders. `compose.ps1` reads current artwork directly rather than creating replacement C textures.

## Current material ownership

The current `LavaReefTheme` calls `ThemeDefinition._apply_texture_set()`. `TerrainTextureSets.material()` binds `assets/textures/lava_reef/{role}.png` through `scripts/themes/terrain_texture.gdshader`.

| Role | Current owner / evidence |
| --- | --- |
| 1. Bottom floor | `floor.png`, world-XZ projection, 8 / 2.1 world-unit repeat |
| 2. Bottom floor border | `floor-border.png`, contour-strip mapping, 7-pixel width |
| 3. Walls | `wall.png`, vertical wall projection |
| 4. Wall ledges / transition caps | No independent material or beveled band. Existing prism sides use role 3; horizontal tops use role 5. Role 6 is a separate horizontal border. |
| 5. Second-floor surfaces | `top.png`, world-XZ projection |
| 6. Second-floor borders | `top-border.png`, contour-strip mapping, 5-pixel width |
| 7. Ramp decks | `ramp.png`, ramp-distance mapping |
| 8. Ramp railguards | `LavaReefDecor.materials.iron`: #8277bb, metallic 0.45, roughness 0.38. C is an explicitly labeled base-color key, not a texture. |
| 9. Exterior facades | `facade.png`; exposed outside terrain cliffs, not city-building facades. The existing TerrainFacade owner also binds exterior raised-wall triangles. |
| 10. Lava | Existing `lava_molten.gdshader`, photographed using the live decor-pool material and published Default atmosphere. |
| 11. Crystals | Existing `lava_crystal.gdshader` on the live six-sided gem mesh, photographed with the published Default atmosphere. |

`current_materials.gd` photographs unchanged production shader materials. These are material portraits, not exported replacement albedos or gameplay screenshots. C10 includes current emission; C11 includes current lighting and material response. A/B are only color/structure studies. This distinction is labeled in the boards.

`current-capture/manifest.json` records one fresh graphical Prototype capture with matching production texture evidence and zero capture assertion failures. The diagnostic image still includes its existing HUD, so it is inspection evidence only and is not presented as the requested clean comparison. Initial capture startup reported sandbox log/cache access and certificate-store errors. The study renderer used a local runtime profile; its only remaining startup diagnostic was the certificate-store error. No headless suite, build, benchmark, or production rebake was run.

## Reference interpretation

Primary reference: Alex's supplied Sonic & Knuckles Lava Reef Act 1 chunk sheet. Its cream/ochre faceted stones, turquoise mineral edges, purple infill, lilac pipes, gold joints/supports, stone steps, and small yellow/red lava swatch inform the option captions. The pink sheet background is not a level color. No source sprite was cropped into a texture.

Supplemental visual references: [Marble Zone underground screenshot](https://www.superjumpmagazine.com/what-happened-to-sonics-roll/) for deliberate stone courses near lava; [Red Mountain bridge screenshot](https://en.sonicscanf.org/gallery/red-mountain/red-mountain-3/) for a distinct industrial route surface. These are references only; no external asset was downloaded or integrated. Lava Reef's sheet remains the palette and motif authority.

## Study limits and handoff

- Twenty new A/B albedo studies across ten meaningful roles. Role 4 is N/A independently.
- At most two successful generation passes per option. Compile-error corrections did not count as visual iterations.
- `2A`, `6B`, and `8A` deliberately share the same purple-pipe material language. They can become one shared material if selected.
- Current cavern scenery and minor props remain as supplied by production. Their rock/metal families are not multiplied into extra voting numbers.
- Seams, physical scale, normal response, and final in-game contrast remain for later approved phases. No new normal, height, roughness, AO, metallic, or emission maps exist.
- The source sampler shows one source repeat per panel, not a claim of final on-mesh density.
- Await a vote such as `1B 2A 3C 4N/A 5A 6C 7B 8A 9C 10C 11C`.
