# Ice Cap — current selected materials

Status: Alex authorized the remaining phases after the final floor-repeat correction. Phase 4 adds restrained structural normals; Phase 5 makes the selected set current in the real theme and disk-bake path. Current assets are in `assets/textures/ice_cap/selected/`. Approved albedos and response maps remain unchanged by the depth pass. 10C stays unchanged, and role 8 uses plain matte snow. The sections below preserve the earlier phase history; old boards and captures are not the canonical result.

`detail_bake.gd` and `structure.gdshaderinc` generate nine aligned OpenGL normal maps and nine height references from the approved pattern shapes. Height is never used for runtime parallax or displacement. `live_controls.gd` supplies the Ice Cap F8 panel in Visual Lab: material detail and normal strength only. `review.gd` inspects actual Prototype disk materials, captures the requested wider Retro views, and can exercise those controls against bound materials with `--check-detail`.

Final focused review: `review/canonical-floor.png` and `canonical-ramp.png` show the actual disk-loaded Prototype with production Retro `[2,4,3]`, hidden HUD and requested wider framing. Both JSON receipts report complete, current sources and zero runtime rebuilds. The ramp receipt finds all nine albedos/normals and eight response maps, verifies matte snow guards, and exercises the detail toggle and 0.5/1.0 normal-strength multiplier on actual bound materials before restoring defaults. Toggling detail changes the rendered image. All five Prototype and seven Endless Ice Cap variants, plus the shared theme bake, match the current pipeline and retain `selected_relief`.

`revision/canonical-selection.json` records 37 PNG hashes, including historical unbound 8A files. All 19 previously approved albedo/response PNGs and the retained crystal shader match the prior receipt. Successful graphical generation, bakes and captures reported no script or shader errors; the restricted environment still reports shader-cache, log/settings access and Windows root-certificate warnings. No headless checks, full suites, benchmarks or production builds were run. No commit or push was made.

## Historical Phase 2 artwork

Locked selections: **1A 2B 3A 5A 6A 7B 8A 9A 10C 11A 12B**. Role 4 remains N/A. The selected 10C crystal shader is retained unchanged and is not regenerated.

## Assets and repetition

| ID | Selected material | Size | Repeat direction |
| --- | --- | --- | --- |
| 1A | Snow shelves with varied, rounded exposed-ice openings | 512 × 512 | Both axes |
| 2B | Blue-violet diamond ribbon | 512 × 128 | Along length |
| 3A | Staggered crystal clusters under snow | 512 × 256 | Horizontal; vertical strip clamps |
| 5A | Packed upper snow with smaller, paler ice openings | 512 × 512 | Both axes |
| 6A | Snow-covered cut-ice coping | 512 × 128 | Along length |
| 7B | Cut-ice ramp with complete snowy shoulders | 512 × 512 | Along travel; width stays complete |
| 8A | Crystal railguard with irregular snow cap | 512 × 128 | Along length |
| 9A | Crystal outer cliff with variable vertical ice curtains | 512 × 256 | Horizontal; vertical strip clamps |
| 11A | Overlapping conifer boughs with accumulated snow | 512 × 512 | Both axes |
| 12B | Varied sparse snow floes over blue lake | 1024 × 1024 | Both axes |

The selected concepts were rebuilt procedurally and supersampled, not enlarged from Phase 1 PNGs. Existing C artwork informed edge softness and surface-detail restraint. Albedo is the only exported map type.

For 1A and 5A, several varied smaller openings replace the original pair of isolated recognizable shapes. The upper surface uses less exposed ice and lower contrast. Snow remains the dominant material. For 12B, an 8 × 8 seeded placement cycle varies floe size, aspect, orientation, polygon shape and spacing. The 1024 resolution preserves individual floes within that longer pattern cycle; resolution alone does not change their physical scale.

All single images still repeat exactly. The plain 3 × 3 previews intentionally expose that repetition; they do not use rotations, stochastic blending or hidden variants. Larger natural motifs can still be recognized in those deliberately zoomed-out sheets. A gameplay-camera check of repeat distance remains Phase 3 work, especially for 12B and the snow on 11A. A lake cycle around 24–32 world units is a starting proposal, not an integrated or approved setting. The 8-world-unit production floor repeat is also only a starting point for the selected snow.

The periodic trim and crystal rhythms are intentional. 7B is a complete deck-width module, so its preview repeats along travel only; integration must preserve that distinction. Snow caps on walls and exterior cliffs are not vertically tileable. Existing geometric tree snow caps must remain intact when applying 11A.

## Previews

- `board-1.png`: 1A, 5A and 12B, including plain 3 × 3 repeats.
- `board-2.png`: 2B, 3A and 6A with horizontal repeats.
- `board-3.png`: 7B, 8A and 9A with their intended repeat axes.
- `board-4.png`: 11A with a plain 3 × 3 repeat.
- `preview-ID.png`: individual selected texture and repeated preview.
- `ID-repeat.png`: full-resolution repeated image without labels or scaling.

## Verification and limits

All ten final textures were rendered through Godot's graphical Compatibility renderer and visually inspected. Boundary-pixel differences were compared with adjacent interior differences on the intended repeat axes; `seam-review.json` records the measurements. This is a focused image seam check, not an engine regression test. No visible discontinuity was identified at the intended wrapping boundaries; motif repetition remains visible at the wide preview scale.

Godot reported shader-cache-directory and Windows root-certificate-store errors in this restricted render environment. There were no shader compilation errors in the completed exports. No headless checks, full regression suites, benchmarks, production builds, game captures or production integrations were run. The production Ice Cap PNG hashes still match the Phase 1 receipt. No normal, height, roughness, AO, metallic or emission maps were generated. No commit or push was made.

`bake.gd` exports only the selected new albedos. `compose.ps1` creates previews from those exports. Both stay local to this experiment. The verification paragraph above describes the completed Phase 2 state, before integration. Approved lighting, geometry, gameplay and the retained 10C material remain outside this change.

## Phase 3 bindings

The live source is `scripts/themes/ice_cap_theme.gd`, using `ice_selected_materials.gd` and `ice_selected.gdshader`. The initial review used albedo only. Alex's subsequent reflection request adds the structural response described below. Old terrain surface/emission masks are not reused. Existing crystal response and the lake's stylized aurora reflection remain, with the latter restricted to exposed lake ice.

- 1A / 5A: world-space snow, now 7.2 × 7.2 / 8 × 8 world-unit repeats respectively.
- 2B / 6A: existing closed-contour strips, fitting complete repeats at approximately 0.48 world units. Border widths remain 6 / 4 authored pixels.
- 3A: wall-contour UVs, 1.8 × 0.9 world-unit chart, fitted to complete horizontal modules. The chart changes UVs only.
- 7B: normalized full deck width and 1.8-world-unit repeat along route distance.
- Role 8: now plain matte snow on edge caps, inner guards and outer fascia, as subsequently requested. Historical 8A is no longer bound.
- 9A: the existing exterior projection, 1.8 × 1.6 world-unit chart with clamped snow-cap depth.
- 11A: conifer mesh UVs in `ice_cap_decor.gd`; existing geometric snow caps remain.
- 12B: 32-world-unit lake repeat in `ice_lake.gdshader`. The existing lake palette control remains active, normalized against its approved default color so that the new art is not double-tinted.

The one shared presenter change adds Ice Cap to the existing wall-UV hook; concurrent changes for other themes are preserved. No renderer, camera, lighting, atmosphere data, collision or authored geometry was edited.

`review.gd` uses the existing production appearance fixture, which instantiates `scenes/prototype_run.tscn` and its normal disk library. It hides HUD only in its isolated session, checks current source/bake authority, and matches the pixels in actual bound runtime textures to the selected PNGs. The normal launcher reaches the same production scene. Only focused graphical Ice Cap bakes and reviews are used; no headless checks or full builds.

## Requested revisions and reflections

`response.gdshader` and `response_bake.gd` retain the selected concepts and exact snow shapes. The diamond ribbon now contains 12 columns instead of 8 within the same closed-contour repeat, making diamonds one-third narrower without creating a seam or changing terrain. Lower contrast softens the trim. Ice faces use clearer blue/cyan variation. The ramp alone uses pale cyan faces, lighter bevels and softer joints; its full-width snowy shoulders remain intact.

Nine `ID-response.png` images pack linear roughness in R, specular in G and structural exposed-ice coverage in B. The same procedural boundaries create albedo and response. Snow uses roughness 0.93 / specular 0.18; exposed ice uses 0.16 / 0.62. The response has identical coordinates, clamping and derivatives to the albedo, including vertical guard orientation. Ice remains nonmetallic. 11A foliage remains unchanged and matte; 10C already has glossy response and remains unchanged.

Reflections reuse the existing static sky radiance. No new reflection probes, screen-space reflections, frame updates, transparency, normal maps, height, parallax or geometry were added. This adds a response-texture lookup to the selected surfaces, with no new per-frame CPU work. Local objects are not mirrored by a sky reflection. Performance was not benchmarked.

Only `First Try Smooth Decor` and `RampMania` Ice Cap sidecars were rebuilt for review; other Act sidecars are not refreshed by this phase. No commit or push was made.

Final visual review: `review/bright-ramp.png`, with matching `bright-ramp.json`, uses the actual Prototype disk path: one Act, one theme, zero fallback builds. All ten selected albedos and nine structural response maps were found on the loaded materials. Source and bake fingerprints were current throughout the final capture. Camera transform and FOV match the original ramp review; HUD is hidden and Retro is off. The screenshot was inspected after the ramp brightening. Earlier stale-bake attempts were rejected and rebuilt after concurrent shared-source changes; they are not final evidence.

The focused snow comparison in `revision/snow-preservation.json` found no change above one byte among 238,372 matte upper-snow pixels, and one such pixel among 210,273 lower-snow pixels. 10C and 11A remain byte-identical to their Phase 2 receipts. Graphical runs reported sandbox shader-cache/root-certificate warnings; no shader or script errors remain in the successful final run. No headless checks, full regression suites or benchmarks were performed.

## Denser lower-floor ice and snow guards

Alex subsequently requested more exposed ice on the floor and plain snow railings. The lower-floor placement cycle increases from 5 × 5 to 7 × 7, with more occupied cells and approximately the same individual feature size. Albedo and structural response are regenerated together. `revision/density-coverage.json` records the before/after exposed-ice area. Upper-floor snow, the bright ramp deck, other selected art and the retained crystal shader remain unchanged.

Ramp guard caps, inner faces and outer fascia now share a private copy of the existing snow material, with roughness 0.93 and specular 0.18. Geometry and supports are unchanged. 8A files remain archived in place, without a live binding. The review checks the snow material on actual loaded guard slots; it now expects nine textured roles and eight structural response maps in the ramp Act.

Requested Retro screenshots use the production default effect stack, with HUD hidden. `retro-floor-overview` uses the existing full-Act overview camera; `retro-ramp-overview` uses the existing follow camera at zoom 0.7, centered on the ramps. These controls are changed only in isolated capture sessions, without saving player preferences. Earlier screenshots and receipts above document earlier revisions.

The completed density revision measures 30.70% exposed lower-floor ice, up from 17.43%. Both requested Retro captures completed through the actual Prototype disk library, with current source fingerprints, one loaded Act/theme and zero source fallbacks each. The ramp receipt confirms the active plain-snow guard materials. Both images were visually inspected. The production Retro stack is `[2, 4, 3]`; HUD and menus are hidden. Only the two Ice Cap review Acts were rebaked. No commit or push was made.

The subsequent tiny density correction changes only the lower-floor repeat from 8 to 7.2 world units. Motifs are 10% smaller and repeat more frequently, while the existing snow artwork, ice coverage and reflection response remain intact. No PNGs are regenerated; the upper floor and snow railings are unchanged.
