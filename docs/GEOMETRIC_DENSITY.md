# Geometric density and style — 2026-11-04

Collisionless presentation now follows a deliberately faceted, early-2000s Sonic-inspired vocabulary. Modern textures, materials, atmosphere, lighting and terrain contours remain unchanged. This is an art-direction pass, not an FPS claim.

## Authority and evidence

The starting HEAD was `c342462`. Existing selected/approved art, atmosphere edits and other uncommitted work were preserved. Overlapping edits are limited to geometry in Green Hill's theme and Casino/Rooftop decor. Those earlier art changes are not included in this commit.

All comparison frames use the existing [canonical Prototype workflow](PRODUCTION_APPEARANCE.md): the real session, validated disk recipes, Forward+/Vulkan, First Try Smooth Decor, served Sonic, seed 18, zero score, locked Goal, fixed time and a 1440×1000 window. The ordinary spawn view is primary. The supplemental loop view moves only the camera target to `(570, 500)`; its Ball and gameplay state remain fixed.

- [Eight-theme before/after sheet](geometry-density/before-after.png)
- [Full-resolution individual pairs, untouched originals and detail crops](geometry-density/full-resolution/README.md) — 1440×1000 per frame; no downscaling. Sky cloud-bank detail is explicitly after-only because the existing before camera does not expose it.
- [Green Hill calibration: loop, Ring, bumper and flower](geometry-density/calibration.png)
- [64 / 24 / 16-step loop comparison](geometry-density/loops.png)
- [Supplemental eight-theme edge review](geometry-density/edge-review.png)
- [Before receipt](geometry-density/before-manifest.json), [final receipt](geometry-density/after-manifest.json)
- [Before CPU audit](geometry-density/before-audit.json), [final CPU audit](geometry-density/after-audit.json), [bumper construction counts](geometry-density/hardware.json)

Full PNGs, intermediate/rejected trials, logs and source hashes are under ignored `test-results/geometry-density/`. The images depend on the explicitly recorded local art worktree, not just the committed geometry. `tests/geometry_density_audit.gd` is mesh accounting only; it does not render or introduce a second appearance harness.

## Density language

| Role | Working budget | Examples and exceptions |
| --- | --- | --- |
| Tiny | Planes/wedges; 4–8 sides; tiny sphere 6×2 (36 triangles) | Petals, leaves, coconuts, small flower heads, fish eyes, bolts |
| Ordinary scenery | Usually 6–10 sides; sphere 8×3 (64 triangles) | Clouds, lanterns, trunks, posts, pipework, shrubs |
| Gameplay hardware | Usually 12–16 sides | Round bumper 12, flipper capsule ends 16; preserve readable emblems and colors |
| Hero landmarks | Usually 16–24 samples; custom geometry where needed | Green Hill loop 16; preserve theme-specific roofs, arches and machinery |
| Effects / focal exceptions | Explicit, purpose-specific | Thin contact/ability outlines, aurora and water; prominent character/Goal silhouettes |

`scripts/presentation_density.gd` provides small explicit primitive families. Shared helpers default to ordinary scenery; the placeholder Ball and flipper ends explicitly request hardware density. Specialized theme constructors retain their own silhouette choices. These are construction budgets, not a LOD system. Existing bake caps still apply to PrimitiveMeshes, including any future HERO-family primitive; custom landmarks are not automatically decimated.

## Ranked audit: source versus production

Counts below are triangles unless specified. A source primitive passes through `visual_detail.gd`, canonical mesh sharing, static spatial batching and warm-manifest capture. Rigid pinball actors apply the same primitive cap **before** combining into ArrayMeshes. Custom ArrayMeshes bypass that primitive cap. MultiMesh instances still multiply vertex work; fewer submissions do not mean fewer instance triangles.

| Priority / object | Original source | Original baked | Final | Multiplication, rendering and importance |
| --- | ---: | ---: | ---: | --- |
| Green Hill sunflower | 3,168 / 1,934 vertices | 2,496 / 1,551 vertices | 96 | Seven standalone flowers plus a pedestal flower in the reference Act, with additional scenery possible. A patch contains three flowers. Shadow-casting; static pieces can batch. Usually tens of pixels. |
| Sky vine tablet | 2,532 | 2,532 | 552 | Six tablets in the reference Act, each with 15 tiny leaf ellipsoids; 90 leaves before counting other vine-bearing props. Shadow-casting decor; static batching applies. |
| Sky cloud banks | 180 × 168 | 30,240 | 180 × 64 = 11,520 | Large collective silhouette built from repeated lobes, already MultiMeshed and shadowless. The distant orbital relic retains 12×6 instead of inheriting cloud density. |
| Aquarium lantern/fish architecture | Palace 3,624; reef aquarium 2,596 | Palace 3,624; reef aquarium 2,500 | Palace 2,168; reef aquarium 1,276 | Two palaces, two reef aquariums and three pavilions in the Act, plus extensive shared background scenery. Lantern paper, fish, glass and water are already shadowless; opaque structure can cast. |
| Ordinary Ring | 256 / 153 vertices | 256 / 153 vertices | 144 / 91 vertices | 20 dynamic Ring bindings in the reference Act; 82 in the documented RampMania sample. No static batching. Shadows retained. |
| Round bumper, visible geometry | 5,212 | 1,276 | 676 | Five bumper bindings in the reference Act. Rigid materials batch inside each actor; whole actors remain dynamic/protected. Tiny bolts were a larger repeated cost than their screen size justified. |
| Round bumper, additional shadow-only geometry | 2,908 | 508 | 388 | Same animated root; existing combined shadow caster retained. Do not add these triangles to visible-pass counts. |
| Green Hill turf loop | 788 / 2,364 vertices | Identical | 212 / 636 vertices | Two authored loops in reference Act, plus local scenery. Custom unindexed SurfaceTool geometry; casts shadows in the foreground. A large silhouette deserves more than tiny decor, but not 64 samples. |

The flower's “baked” component budget is the measured primitive conversion; the disk audit separately counts the complete saved recipe, including spatially batched instances. After batching, some children no longer retain their original prop ancestry, so `groups.other` must not be treated as an unknown extra object or a complete per-prop attribution. Retained metadata roots provide authored-instance counts. Shared/far scenery and all off-camera instances are included in recipe totals.

Apparent source offenders already neutralized by baking:

- Bumper discs were 48 radial segments with inherited longitudinal rings. Production already reduced them to 16×1. Their source count was not their runtime count.
- Shared 24-sided cylinder helpers became 16×1 in ordinary primitive conversion. Explicit hardware construction now matches that cap in source previews too.
- Ordinary source spheres went from 16×8 to 16×7, which removed some triangles but did not make nine spheres per flower appropriate.
- Aquarium's 24×6 toruses became 20×6. Their custom roof and 32-step glass shell did not receive this reduction.
- Flipper ends already became 16-sided in the bake. They remain 16; their smaller pivot discs and tiny accents now follow the calibrated hardware/detail roles.

## Calibration decisions

**Flower:** six-sided open stem, simple two-sided leaf, eight shallow diamond/wedge petals and eight-sided center. Total 96 triangles, versus 2,496 after the old primitive cap (96.2% fewer). Mesh parts are cached and reused. The first flat-petal trial was rejected because it looked dark under the actual production light. Per-face normals on the shallow wedges restore readable yellow faces without changing the material. Both sides remain real geometry; no culling/material override was introduced.

**Loop:** 64 / 24 / 16 samples produce 788 / 308 / 212 triangles. Sixteen retains the loop and spiral approach silhouette at gameplay distance. The supplemental camera exposed a defect hidden by the denser mesh: radial-angle classification could send nearly horizontal outer faces to the vertical cliff projection, producing black patches. Classification now uses the actual exterior face normal. Twisted side quads also receive per-triangle geometric normals, while retaining their established UV chart. No terrain contour, collision or shader was altered.

**Ring:** compared the baked 16×8 baseline, 12×6 and 16×6. Choose 12×6: readable gold opening, intentional facets, 43.75% fewer triangles. The mesh remains shared across individually animated Ring nodes. Attraction, flight, reset, score and shadow policies are untouched.

**Bumper:** compared the production 16-side baseline against 16 and 12 with six-sided bolts. Choose 12 for circular bodies/pivots and six for bolts. Five visible material groups plus the existing nonshadowing accents/shadow grouping remain; the whole constructed actor has seven mesh nodes before and after. Visible triangles fall 1,276→676, and shadow-only triangles 508→388. The 48-side source request was never assumed to survive the bake.

## All eight themes

| Theme | Change or deliberate retention |
| --- | --- |
| Green Hill | Sunflower rebuilt; loop 64→16; coconuts 16×7 baked spheres→6×2; ordinary cloud helper 8×3. Preserve seven-sided segmented palm trunks, custom fronds, rocks, shrubs and turf textures. |
| Chemical Plant | Keep 10-sided tanks/pipes, 8-sided supports and 12×5 valve rings. These already match the vocabulary; dense-looking pipe clusters are assemblies of useful distinct pieces. No numeric churn. |
| Rooftop Run | Tiny urn flower heads use 6×2 instead of 8×4. Preserve eight-sided architecture, ordinary foliage, custom balloon panels, railings and arches. |
| Casino Night | Ordinary cylinders 12→10. Preserve custom stars, neon frames, marquees, reels, palms and the selected housing art. |
| Sky Sanctuary | Tiny vines/blossoms 6×2; ordinary orbs, palm leaves and cloud lobes 8×3. Preserve eight-sided columns, architectural pieces and the larger 12×6 orbital relic. |
| Ice Cap | Keep existing 6/8-sided crystals, low-poly snow and tiny 4×2 distant peaks. Aurora segmentation remains an effect exception. No forced simplification. |
| Lava Reef | Keep six-sided gems/columns, eight-sided pipes and custom 64-triangle beveled boulders. The large total comes from repeated themed rock formations, not smooth inherited spheres. |
| Aquarium Park | Ordinary orbs 12×6→8×3; fish eyes 6×2; cylinders 12→8; tank/gate rings 20×6 baked→16×6; glass shell 32→16 steps. Roof curvature uses nine bands instead of 24, preserving the exact original narrow gold lip interval. Coral, fish tails, roof colors, architecture and water/glass materials stay distinct. |

Shared Spring coils and button power-symbol toruses use 12×4 (96 triangles), down from 20×6 baked (240). Spring/button face discs still receive the existing 16-side bake cap. Slingshot outlines, Drop Target bodies, rail paths/support placement and enemy construction remain intact; Buzz's 10-sided body vocabulary is already appropriate.

Explicit unchanged exceptions: magnetic-field source outline remains 48×6 (generic bake cap still produces 20×6); thin character contact/ability rings remain 32×8; the live, unbaked Goal remains 32×8; the single animated character sphere remains 32×16 for its focal silhouette and shader. Legacy diagnostic-only CharacterFeedback primitives and the hidden base-presenter Ball stripe are not counted as visible Prototype offenders. No CapsuleMesh producer was found in current production geometry; the existing capsule bake cap remains defensive support.

## Runtime accounting and verification

Recipe totals count every instance, including off-camera scenery and separately retained shadow-only meshes. They are workload budgets, not rendered-frame triangle counters. Shared backgrounds are counted once. Compressed `.res` sizes exclude the shared external asset bank and are not download-size estimates. No FPS improvement is inferred from these counts.

| Theme | Act vertices, before→after | Act triangles, before→after | Shared-background triangles, before→after | Act shadow-eligible triangles, before→after |
| --- | ---: | ---: | ---: | ---: |
| Green Hill | 89,932→61,215 | 86,807→45,387 | 2,594→866 | 53,532→27,244 |
| Chemical Plant | 70,174→65,574 | 58,097→51,825 | 542→542 | 28,308→25,012 |
| Rooftop Run | 143,082→137,468 | 80,449→72,461 | 2,356→2,356 | 34,320→29,308 |
| Casino Night | 84,150→78,392 | 60,449→52,785 | 3,312→3,104 | 36,324→32,128 |
| Sky Sanctuary | 95,268→74,964 | 97,423→63,839 | 30,482→11,762 | 67,856→39,888 |
| Ice Cap | 64,074→59,474 | 53,777→47,505 | 1,164→1,164 | 32,594→29,298 |
| Lava Reef | 97,242→92,642 | 59,531→53,259 | 29,070→29,070 | 41,328→38,032 |
| Aquarium Park | 88,443→71,211 | 79,473→56,201 | 52,958→31,534 | 49,272→35,936 |

Shared hardware explains the Act reduction even in the three themes whose own decor was retained. Shadow-eligible counts preserve existing casting policies and include shadow-only actor meshes; they do not multiply by lights/cascades or establish actual shadow-pass visibility.

Static Act batch counts are unchanged in seven themes: Green Hill 37, Chemical 27, Rooftop 26, Casino 51, Ice 21, Lava 24 and Aquarium 29. Sky changes 53→54 batches and 345→337 batched instances because tiny leaves and ordinary spheres now use different meshes. All eight retain 20 Ring, five bumper, eight flipper and 15 animation bindings in the reference Act. This is no batching collapse. Compressed Act recipe sizes fall in all themes; Green Hill 495,647→441,212 bytes, Sky 406,480→385,642, Aquarium 434,207→409,807. Shared mesh-bank deduplication means these are only recipe-file comparisons.

Executed component checks: geometry density/normal/UV contracts (18), contour/primitive bake safety (939), rigid hardware batching (14), shadow batching (16), Green Hill landmarks (16), cross-theme landmarks (387), Rooftop/Casino/Sky/Ice/Lava/Aquarium decor (91/95/95/95/96/95), static batches (111), exact baked collision equivalence/freshness (2,842), and mechanism lifecycle (103). All passed. The real Prototype run regression passed 142 checks. Captures also byte-check Act/scenery/atmosphere sources and verify current imported/selected pixels in loaded recipes.

Full offline rebuild completed for **40 Prototype variants** and **56 separate Endless variants**, including all shared backgrounds. Post-build disk audits passed **425** and **489** checks respectively with zero failures. Bakes remain ignored derived local data; they are not committed. Source hashing continues to invalidate old geometry, and the canonical regression explicitly rejects an isolated stale receipt before session construction. Final spawn and supplemental edge views each passed all eight themes and **135** authority/freshness/manifest checks. The final spawn receipt matched **146** textures and preserved hashes for **47** Act/scenery/atmosphere source files. Both eight-theme sheets were visually inspected; the [edge receipt](geometry-density/edge-manifest.json) records its alternate camera. Godot's headless editor scan completed without script/engine errors.

A 30-second Forward+/Vulkan input-driven Challenge run completed 3,600 physics-input ticks, scored 755, retained three resident Acts, and used **zero runtime rebuilds** with no boundary wait. Its final gameplay screenshot was inspected. This is motion/startup evidence, not a matched performance comparison: another headless bake was running, and the run seed/path and driver caches were not controlled against a before sample. The process emitted one ObjectDB-instance leak warning on exit; no script/engine errors occurred. Raw timing and the warning remain in `test-results/geometry-density/play.*`.

Known inherited test debt: `theme_texture_regression.gd` assumes the older albedo/emission/surface import interface and reports 31 failures against existing selected Chemical/Casino art. `ring_presentation_smoke.gd` reports four failures because it still expects 75 points for three ordinary Rings; current Scorecraft defines 15 points per Ring. These source files and scoring rules were not changed or weakened. Canonical texture receipts and the current Prototype runtime checks are the relevant production evidence.

Human follow-up: judge flipper timing and moving Ring readability during play; review all atmosphere variants and distant scenery from more camera positions. Existing terrain tessellation, shadow architecture and character density are separate decisions.
