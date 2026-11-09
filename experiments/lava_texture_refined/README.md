# Lava Reef — canonical selected materials

Final decision (2026-11-09): Alex approved the exaggerated **normal-only** diagnostic. Both floor materials now use strength 6.0, with geometric relief and parallax off; other roles retain 0.85. The geometry trials below are historical. The production theme, source presenter and disk baker share the final response. Visual Lab F8 offers detail and normal-strength controls only. Alex explicitly authorized completing the phases and committing/pushing all current project changes.

## Current approved set

Alex approved the matched rock palette, muted reddish-brown timber, restored purple 3B wall and dark iron-and-brass 9B facade. The final color tweak darkens only the timber by 4%. Alex then approved the remaining material phases and collisionless visual rock relief, followed by recessed geometry rather than raised tops. Structural normal/roughness maps and low-poly rock facets now share the approved albedo structure. The rock tops stay at or below the original surface; the joints and beds are lower. Gameplay collision is unchanged. No commit or push is authorized.

Current sources: `balanced_revision/1C.png`, base `2A.png`, base purple `3B.png`, `final_revision/5B.png`, base `6B.png`, `7A.png`, `8B.png`, and `warm_revision/9B.png`. Copies live in `assets/textures/lava_reef/selected/`; `lava_reef_theme.gd` owns their production bindings. `phase3/` records the selected-source hashes and real Prototype review evidence.

`response/` owns deterministic companion-map and rock-mesh generation. `canonical/` owns the current real-game depth comparison and receipt. The normal Prototype/Endless theme and Visual Lab use the same materials. F8 in Visual Lab exposes Material detail, Normal strength and Rock recess depth; numeric defaults are 1.0. Historical captures below remain records of earlier phases.

The refinement notes below describe the original Phase 2 pass. Later revision folders supersede its 1C, 5B and 9B descriptions.

## Historical Phase 2 pass

Alex selected `1C 2A 3B 5B 6B 7A 8B 9B 10C 11C`, explicitly requesting a slightly calmer 1C. The follow-up clarified that **6B is the item to rework**, not 7A. These decisions supersede the historical Phase 1 waiting state.

The selected concepts were locked at this stage. The following review assets were initially isolated from production; the current status above records the subsequently approved integration.

## Refined selections

| ID | Refinement | Resolution | Intended repeat for later integration |
| --- | --- | --- | --- |
| 1C | Derives directly from the current production floor PNG. Stone-face RGB variation contracts by 12% toward a matching brown; purple joint pixels, rock count, and layout remain. No blur is applied. | 512 x 512 | Preserve current 8 / 2.1 world-unit period on both axes. |
| 2A | Single purple pipe profile, symmetric alloy bands, gold collars and restrained fittings. | 512 x 128 | One world unit along the contour; fit the existing lower-border width. |
| 3B | Violet basalt columns with individual column bends, staggered fractures and sparse gold mineral lenses. | 512 x 256 | 3.2 x 1.6 world units; approximately 0.4-unit column width. |
| 5B | Complete chamfered service panels with calm faces, shared gold transverse joints and correctly proportioned fasteners. | 512 x 512 | Proposed 1.6 x 1.6 world units; 0.8 x 0.4-unit panels. |
| 6B | Reworked as two purple conduits around a recessed spine, joined by a broad gold saddle. Distinct from the single lower pipe. | 512 x 128 | One world unit along the contour; fit the existing upper-border width. |
| 7A | Retains the selected basalt causeway concept. Broad fitted stones, shallow chamfers and very restrained face variation. | 512 x 512 | Proposed 1.6 x 1.6 world units; approximately 0.53 x 0.4-unit stones. |
| 8B | Gold girder bays with consistent brace thickness, joint plates and restrained fasteners. | 512 x 128 | Proposed one world unit along the guard; cross-axis fitted to existing guard geometry. |
| 9B | Two complete purple-and-gold retaining bays around the same basalt family as 3B. | 512 x 256 | Preserve 3.2 x 1.6 world units; each bay spans 1.6 units. |

These scale values are proposals for the next phase, not active runtime settings. Actual camera readability may require mapping adjustments after approval.

Role 4 remains N/A as an independent material. **10C lava and 11C crystals remain unchanged**; they were not regenerated or copied into this folder. Existing cavern scenery and minor props remain unchanged.

## Authoring and review

`selected.gdshader` reconstructs the selected procedural designs; it does not upscale the Phase 1 bitmaps. The only sampled source bitmap is the actual current floor, for Alex's explicit 1C adjustment. `bake.gd` uses the existing graphical SubViewport workflow and a 2x authoring render before downsampling to final resolution. Repeat previews are composed from the saved image pixels, not a second procedural interpretation.

Run the graphical Godot script `res://experiments/lava_texture_refined/bake.gd`, then `compose.ps1`. Use the local runtime profile and log paths to avoid writes outside this workspace. No headless suite or production bake is part of this authoring step.

`selected-1.png` through `selected-3.png` present the refined texture and a reduced repeat preview for every changed selection. Each original `ID-repeat.png` preserves native pixels. `1C-current-vs-refined.png` shows the subtle floor change directly.

Visual review found no obvious hard seams in the repeated previews. Ore accents and structural modules remain visibly periodic by design. In-game scale, curved mapping, and contrast under the approved lighting are not verified in this phase. No normal, height, roughness, AO, metallic, or emission maps were generated.

Graphical rendering completed for all eight albedos. Godot emitted the existing certificate-store startup error; rendering completed. The first local-source read also emitted an export warning, addressed by reading the PNG bytes directly in the authoring script. No full regression suite, headless verification, build, benchmark, or in-game integration was run.

The original refinement review is retained for comparison. Current status is recorded above. No commit or push.
