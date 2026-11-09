# Theme identity: one imaginary SEGA game

**Confirmed direction — 2026-11-04.** Imagine all eight themes as Sonic 1 / early-classic 2D stage concepts, translated together by one late-Saturn / early-Dreamcast modeling team. Actual release chronology does not set a theme's detail budget. Original Zones provide motif vocabulary, not assets to reproduce.

The [geometry density hierarchy](GEOMETRIC_DENSITY.md) remains authoritative. This is a silhouette and motif pass, not another polygon reduction. Modern Hybrid materials, lighting, filtering, shaders and atmosphere remain useful. Shapes must still make sense without microtexture.

## Working rule

Prefer fewer, bigger, stronger objects. A prop should plausibly have a readable classic Sonic sprite/tile counterpart. Use broad color regions, bold patterns, exaggerated silhouettes and deliberately faceted volumes. Avoid realistic landscaping, refinery greebles, miniature architectural ornament and generic asset-pack realism. A later game's theme receives no exemption.

Readability priority: table pattern/material, terrain silhouette, medium-large edge scenery, one or two landmarks, background, then tiny decoration. Review from the gameplay camera before inspecting details. Keep foreground and background distinct. Do not change gameplay or atmosphere architecture to force an art result.

## Original audit before implementation

Starting HEAD: `0f4ccb5`. The current worktree includes separately owned selected/approved textures, materials, atmosphere values and other edits. They are part of the evidence, not part of this change. Fresh baseline: `test-results/theme-identity/before`, eight canonical Prototype frames and 135 passing authority/freshness checks. Builders supply context for motifs outside the spawn frame; their existence is not evidence that the spawn camera displays them. Sky clouds receive a separate matched gameplay-camera pan to `(570, 500)`.

| Theme | Strong current motifs | Weak/generic elements and redundant noise | Missing anchor | Keep | Proposed changes / assessment |
| --- | --- | --- | --- | --- | --- |
| Green Hill | Checker cliffs, broad turf, palms, sunflower, loop | Small rocks are generic but useful subordinate accents; no harmful clutter identified | None | Sunflower, segmented palms, loop, islands/ocean, broad grass | **No change.** Already the reference for this direction. |
| Chemical Plant | Magenta reactor, blue pipes, cyan collars, hazard bands, reservoir | Thin secondary service pipes and repeated small collars weaken the toy-machine hierarchy; no realistic refinery rebuild needed | More decisive fat-pipe silhouette, not another machine | Current surfaces, colors, glass vessel, reservoir and valve vocabulary | **Light polish.** Enlarge main feed pipes and arch; remove secondary service runs. |
| Rooftop Run | Terracotta roof bands, stucco tower, masonry, arches, balloons | Clock is subordinate to its building; thin repeated railing posts vanish at distance. Benches/urns are supporting props, not identity anchors | A clock face large enough to carry the tower | Roof shapes, shutters, bridges, awnings, cypress and balloon panels | **Light polish.** Broader clock face/hands and fewer, thicker railing posts. |
| Casino Night | Stars, reels, card suits, neon strips, toy towers | The palace's blank reverse face dominates this camera; more tiny ornaments would not fix it | A large emblem on the currently blank face | Selected housing, reel cabinet, palms, floor suits and existing star geometry | **Light polish.** One rear palace star. Initial pylon idea rejected after full-size review: the visible blank landmark matters more. |
| Sky Sanctuary | Columns, broken arches, stone platforms, suspended ruins | Vine leaves read as green pebbles; broad flattened cloud lobes resemble slabs. Column fluting is subordinate, not a reason to rebuild the ruins | Clear organic leaf and billowing-cloud silhouettes | Monumental masonry, broken silhouettes, open gaps, palette and cloud shader | **Moderate identity work.** Pointed folded leaves and taller overlapping cloud lobes, with the same cloud population/density family. |
| Ice Cap | Faceted crystals, snow caps, blue ice walls, angular mountains, aurora | Small shards remain useful accents; no modern or noisy offender warrants replacement | None | Crystal clusters, snow shapes, frozen structures and aurora | **No change.** Strong coherent identity already. |
| Lava Reef | Volcanic masses, large crystals, lava channels, industrial remnants | Small hazard signs are subordinate; repeated rock forms remain deliberately graphic, not geological noise | None | Rock/crystal silhouettes, molten colors, pipes and angular cavern | **No change.** No forced churn. |
| Aquarium Park | Faceted lanterns, curved roofs, tanks, water channels, coral | Palace reads mainly as architecture; small fish disappear inside tanks, and repeated window slits add little aquatic identity | Giant fish motif visible on either side of the palace | Whimsical roofs, lantern facets, glass/water, coral and existing aquatic colors | **Moderate identity work.** Fish relief replaces window repetition; fewer, larger fish in reef tanks. |

No theme needs substantial identity work. These are visual judgments about the inspected views, not exhaustive certification of every Act and atmosphere.

## Theme identity carriers

Keep most identity in these three-to-five motif groups. Supporting props should reinforce them, not compete with them.

| Theme | Primary carriers |
| --- | --- |
| Green Hill | Checker cliffs/turf; palms; sunflower; loop; ocean/islands |
| Chemical Plant | Fat pipes/valves; chemical vessels/reservoirs; hazard bands; stacked reactor blocks; cyan/yellow/magenta accents |
| Rooftop Run | Terracotta roofs; stucco clock towers; arches/bridges; striped awnings; broad masonry |
| Casino Night | Extruded stars/suits; reels; neon frames; chunky casino towers; circular arcade structures |
| Sky Sanctuary | Floating stone slabs; ancient columns; broken angular arches; trailing vegetation; billowing clouds |
| Ice Cap | Faceted crystals; blue ice walls; snow caps; angular mountains; aurora |
| Lava Reef | Volcanic rock masses; crystals; lava channels/glow; heavy industrial remnants; angular caverns |
| Aquarium Park | Glass tanks/tubes; giant fish; faceted lanterns; whimsical aquatic architecture; coral/water channels |

## Scope

All changes belong to collisionless presentation constructors. Preserve authored slot pools, indices, placement transforms and landmark footprint envelopes. Do not change authoritative collision, physics, terrain contours, Act layouts, Scorecraft, Buddies, characters, Type Actions, scoring or run structure. No baked-lighting work, new atmosphere system or external assets.

## Implemented changes

- **Chemical Plant:** two broad yellow feed pipes replace the reactor's thin service runs; the magenta vessel stays exposed and gains a simple valve wheel. The pipe arch has a heavier blue silhouette without its smaller parallel arch. Existing ten-sided pipe geometry, materials and placement remain.
- **Rooftop Run:** a dark octagonal bezel, larger clock face and thicker hands give the existing tower a readable emblem. Four broad railing posts replace seven thin ones. Roofs, stucco, windows, surface art and layout remain.
- **Casino Night:** one large gold-edged pink star fills the palace's reverse wall. The first audit suggested pylon simplification, but full-resolution evidence exposed the blank palace face as the higher-value change. Existing front reels and selected housing are preserved.
- **Sky Sanctuary:** an eight-triangle folded leaf replaces pebble-shaped vine leaves. Two sprigs lie across each tablet instead of disappearing inside its slab; hanging vines retain a visible stem. Cloud banks retain exactly 180 ordinary 8-by-3 lobes, with taller central billows and lower shoulders. No shader, light or atmosphere values change.
- **Aquarium Park:** a large shallow fish relief on both palace faces replaces seven little window slits. Reef tanks contain two larger fish instead of four tiny ones. The faceted lanterns, roof profile, glass, water, coral and palette remain.
- **Green Hill, Ice Cap and Lava Reef:** deliberately unchanged. Their existing anchor shapes already meet the shared direction.

The first rendered trial rejected square-looking Sky leaves and fish relief intersecting the palace backing. Final leaves use narrower pointed blades and explicit tablet orientation; fish relief uses shallow depth and clears the backing while retaining the tested landmark envelope. Rejected frames remain local under `test-results/theme-identity/after-trial1` and are not presented as final evidence.

## Review evidence

[Full-resolution comparisons](theme-identity/README.md) contain eight primary pairs and a supplemental Sky cloud/ruin pair. Each original is 1440 × 1000; pairs are 2880 × 1060 including a 60-pixel label strip. Gameplay pixels are copied at 1:1, without scaling or color adjustments. Open an original when a viewer automatically shrinks a wide pair.

All frames use the actual Prototype session, validated disk recipes, Forward+/Vulkan, First Try Smooth Decor, seed 18, served Sonic, zero score, locked Goal and published Default atmospheres. The exporter rejects mismatched state, camera, source Act, scenery, atmosphere or renderer receipts. The Sky supplement changes only the camera target to `(570, 500)` on both sides; it is not a close-up renderer. The primary gameplay framing remains the main criterion.

Screenshots include the pre-existing uncommitted art recorded in the provenance files. The source commit alone does not reproduce that artwork. Unchanged themes retain their source art; tiny framebuffer differences between independent runs are not claimed as edits. No new external artwork was downloaded.

Reproduce from the two source states using `tools/capture_prototype_appearance.ps1`. Capture Sky separately with `-SkipBake -Themes sky_sanctuary -CameraTarget '570,500'` into `before-sky-edge` and `after-sky-edge`. The completion section below names the current capture root and exporter invocation. Earlier `test-results/theme-identity/` outputs predate the explicit graphics receipts and remain historical evidence.

## Original implementation verification

Component checks executed successfully: cross-theme landmark footprints/indices/collision isolation **387**, Rooftop/Casino/Sanctuary/Aquarium decor **91/95/95/95**, geometry-density contracts **18**, and baked collision equivalence **2,842**. The headless Godot editor import completed with exit 0 and no script/engine errors.

A graphical Aquarium Challenge run used normal player inputs for **3,601 physics ticks** (approximately 30 seconds), scored **1,475**, kept three resident Acts and used **zero runtime rebuilds**, with no boundary wait. It exited successfully with the existing one-instance ObjectDB cleanup warning; no script/engine errors occurred. This is startup/motion evidence, not a controlled performance comparison: offline baking was running concurrently.

Concurrent work introduced shared device shadow controls during the first full bake. The freshness audit correctly rejected 29 stale Prototype receipts; a further update invalidated the remaining older receipts. That other work was preserved and landed separately as `48544d0`. All affected bakes were refreshed against the stable newer pipeline. Final disk audits passed **40 Prototype variants / 425 checks** and **56 Endless variants / 489 checks**, with zero failures. Device defaults remain the existing 8192 atlas, four cascades and `smooth_shadows=false`; the published atmosphere sources are not changed by this pass.

Known inherited diagnostic failure: `tests/decor_runtime_smoke.gd` reports **4 failures in 17 checks** and missing-metadata errors against the existing Green Hill source batching. It assumes every direct decor-root child is an authored slot; the separately owned `green_hill_static_scenery.gd` also appends `StaticSceneryBatch` children. This pass changes neither that Green Hill code nor the legacy test. Its collision-isolation/removal checks pass. Do not treat it as a successful test or weaken its assertions to hide the mismatch. Existing selected Casino source-image/export warnings also remain; production disk captures use the validated baked resources.

Human review remains necessary for art taste in motion, cloud silhouettes during panning and other Act/atmosphere combinations. Matched stills and a scripted play run cannot establish those judgments.

## Completion review — 2026-11-08

The existing uncommitted pass was reviewed against Alex's clarified fictional 1998–2000 brief on baseline `6a723e68db6b354b0eac070fd775c8b81ec38c3b`. It already supplied the right changes: bold Rooftop clock/rail shapes, monumental Sky ruins with restrained pointed vegetation and billowing clouds, giant Aquarium fish, broad Chemical feeds and a Casino star. Rooftop's existing roof masses, simple facades and warm blocks already avoid miniature modern-city detail. Aquarium's sparse lanterns and exaggerated aquatic architecture already support the shared pipeline. **No further production shape or material edits were justified.**

Completion work strengthened the evidence instead: explicit graphics receipts, an isolated pre-pass source reconstruction, fresh matched disk-baked Prototype captures, eight native detail pairs, a final eight-theme sheet and a navigable evidence index. Green Hill, Ice Cap and Lava Reef remain intentionally unchanged. Approved density work, selected artwork, Hybrid surfaces, authored layouts and all gameplay remain intact. Production cameras, shadow defaults, 4× MSAA and 100% render scale are unchanged. The pixel audit's 85% laptop candidate and visibly soft 75% experiment are not art-direction decisions.

### Current evidence and isolation

Use [the completion evidence index](theme-identity/README.md) and `theme-identity/review-20261108/` for the final comparison. Earlier captures remain preserved locally; they are historical evidence, not mixed with the new pairs.

Both sides use the current working-tree artwork and authored data. The before snapshot restores only the six identity constructor files from the preserved pre-pass sources. A SHA-256 comparison of 545 script, asset and data files found exactly those six differences; see [source scope](theme-identity/review-20261108/source-scope.json). Thus the comparisons retain selected artwork without claiming that this commit owns or reproduces the other uncommitted art changes. Each capture loads one validated Act recipe and one validated theme recipe, with zero source fallback. The source-scope and capture provenance receipts identify this distinction explicitly.

The frame is 1440 × 1000; its existing logical world viewport is 1296 × 900 at 100% 3D scale. Both sides record 4× MSAA, no FXAA, the same default shadow configuration, and Retro OFF for the established canonical inspection fixture. This does not change production Retro preferences. The exporter checks the complete graphics receipt alongside Act, scenery, camera, atmosphere, renderer and gameplay state. Full-frame pairs and detail crops preserve 1:1 framebuffer pixels. The separately labelled overview is downsampled for navigation; the final native sheet is 2880 × 4260.

Local reproduction uses `test-results/theme-identity-finish/before-source` for the before project and the working repository for after. Capture outputs are grouped under `test-results/theme-identity-finish/compare/{before,after,before-sky-edge,after-sky-edge}`. Run `tools/export_theme_identity_comparisons.ps1 -CaptureRoot test-results/theme-identity-finish/compare -OutputRoot <new-directory>` to reproduce the checked panels. A first before capture overlapped the isolated project's initial import; freshness validation rejected its stale receipt. That rejected attempt is preserved locally and excluded from the final evidence.

### Remaining visual questions

- The spawn frame clips portions of the right-side landmarks. Detail crops expose visible clock/fish geometry but cannot certify every angle, prop or Act. Only Sky has a supplemental matched pan.
- Chemical Plant's existing glowing floor bars compete with Rings. Lava Reef's warm hardware has less color separation from its floor than the cool themes. These are manual moving-readability questions; this pass preserves the selected art and atmosphere.
- Sky's fuller clouds still have broad visible facets. Check their silhouette during panning before judging further polish.
- The historical legacy `decor_runtime_smoke.gd` mismatch described above remains unresolved and is not included in the supported green baseline.

### Completion verification

Re-ran the supported **32 suites / 8,596 checks / zero assertion failures**, plus the Act geometry child process's six reload checks. [The run receipt](theme-identity/review-20261108/verification.json) lists each suite and local log hash; counts are not inflated by duplicate runs. The 40-variant Prototype disk audit passed 425 checks within that baseline. The separate 56-variant Endless disk audit passed 489 checks. Both full capture sets passed 135 authority/freshness checks each; both supplemental Sky sets passed 23 each, with zero failures. All final captures loaded validated disk resources without source fallback.

Focused presentation checks passed again: landmarks 387, Rooftop 91, Casino 95, Sanctuary 95 and Aquarium 95. Density 18 and geometry bake 2,842 also passed and are already counted in the baseline. No test assertion or supported count was weakened. Restricted headless runs retain the known Windows root-certificate diagnostic; dummy-renderer diagnostics, deliberate malformed-resource/archive-write failures and existing ObjectDB cleanup warnings remain distinguished from assertion failures. Final graphical captures completed without script/engine errors.

An exported copy of the exact staged source also completed a fresh editor import and the landmark/Rooftop/Casino/Sanctuary/Aquarium/density suites (387/91/95/95/95/18 checks, zero failures). This verifies that the scoped commit runs without separately owned uncommitted art code. Its shipped base artwork is not substituted for the selected working-tree artwork in the canonical review evidence. Pre-commit comparison confirmed all original tracked production diffs were preserved unchanged.

## Stronger signature pass — 2026-11

This second pass asks a different question: can the Zones be distinguished immediately at gameplay distance, within the already established fictional 1999 art language? It is not another density or realism-reduction pass. The starting main commit was the lifecycle audit, `21f97e358c1bce5bb2d947cf0025740629983b06`. Selected local artwork and published atmosphere edits remain part of the working-tree evidence, not newly owned assets.

### Audit and decisions

The initial audit used fresh validated Prototype disk bakes for all eight themes at spawn `(400, 500)` and the existing supplemental camera target `(570, 500)`. Both sets passed 135 authority/freshness checks. The camera's projection, zoom, angle and gameplay behavior were unchanged. The supplemental target reveals peripheral scenery but also exposes edge-on authored landmarks; the long landmark in the reference Act has a quarter-turn placement. A broad silhouette must work in that orientation, not only in a front-facing prop gallery.

| Theme | Gameplay-distance assessment | Decision and identity hierarchy |
| --- | --- | --- |
| Green Hill | Strong control: checker cliffs, turf, loop opening, palm silhouette and sunflower remain distinct at small size. | **Unchanged.** No evidence justified manufacturing a new hero. |
| Chemical Plant | The authored reactor and broad pipes were strong. The enormous external silo still read as a generic straight industrial cylinder with thin indicator slits. | **Strengthened.** A pinched magenta vessel, wide yellow hazard shoulder, cyan collars and two chunky pipe handles turn the existing large tank into an obvious chemical machine. Existing reactor/arch props, reservoir, selected textures and factory background remain. |
| Rooftop Run | Terracotta roof masses, pale architecture, clock and adjacent tower establish a strong skyline in the alternate view. The clock is partially clipped at spawn. | **Unchanged.** Composition across two ordinary camera positions supports the existing clock; another enlargement or more miniature architecture would not help. |
| Casino Night | The palace star, stepped building, reel tower and luminous palms provide recognizable shape groups, beyond the selected surface colors. | **Unchanged after reassessment.** The previous star solved the important blank face. No additional marquee animation or ornament. |
| Sky Sanctuary | Monumental stone, open arches/columns and floating masonry/cloud masses distinguish it from Rooftop's roof-and-clock architecture. | **Unchanged.** Preserve existing pointed vegetation and faceted clouds. Motion remains a human review question. |
| Ice Cap | Materials and atmosphere were coherent, but the hero was seven similar thin shards. Edge-on placement turned the row into a narrow picket shape. | **Strengthened.** Three broad crystal blades, led by one deep central prism, read as one glacier crown. The existing snow plinth, smaller crystals, mountains, arch, lake and aurora remain. |
| Lava Reef | The old crown repeated nine stacks of small boulders and five shards. It had no singular molten feature and shared Ice's spiky-row structure. | **Strengthened.** One dark six-sided caldera with a real crater and three broad orange clefts replaces the stacked wall. Two larger crystals and the existing purple pipe retain the mineral/mining vocabulary. |
| Aquarium Park | Giant fish, glass tanks, curved roofs and lanterns already form a distinct whimsical aquatic vocabulary. Some fish faces disappear when viewed edge-on. | **Unchanged.** The existing fish population is sufficient. No composition issue warranted more fish or a camera change. |

Macro identity comes from the new external Chemical vessel and the contrasting Ice/Lava hero masses. Mid-scale identity remains the existing pipes, smaller crystals, mineral formations and theme architecture. Color and emission support those shapes. No small-prop population was expanded to compensate for a weak anchor.

### Implementation boundaries and cost

Only three production constructor files change: Chemical's theme-local silo, Ice's `glacier_crown`, and Lava's `rift_crown`. Authored landmark pools, fixed indices, placement transforms and shared footprint envelopes remain intact. Chemical's vessel stays within the previous 1.08-radius clearance envelope; Ice/Lava keep the same three-by-one-cell bases. No Acts, terrain contours, collision shapes, mechanics, physics, scoring, Buddies, character actions, Goal logic, cameras, selected textures, shader programs or atmosphere values are changed by this task.

Chemical reuses unit cylinders, cap and box meshes so the existing static batcher can combine differently sized vessels. An initial trial created a separate sized mesh for each part; accounting exposed the avoidable submission cost, so that construction was replaced before final evidence. There is no new batching architecture. Ice replaces fourteen crystal mesh pieces with six. Lava replaces the stacked boulder assembly with two cached custom meshes: a 36-triangle shell and a 24-triangle static molten insert. Its winding regression checks visible outer walls, the upper rim and inner cavity, as well as finite geometry and shared resources.

**No animated signature was introduced.** Added animation bindings, animated nodes and lights: zero. Existing aurora, water, lava and other environmental effects remain. The new Lava clefts use the existing static heat material, with shadows disabled on the insert. No GPU-time or FPS improvement is inferred from mesh counts.

Final recipe accounting is recorded in [metrics.json](theme-identity/signature-20261108/metrics.json). Counts include off-camera instances and retained shadow geometry, not only visible-frame work. Shared backgrounds are counted once, separately from each Act, and remain unchanged.

| Reference Act | Baked triangles, before → after | Mesh instances, before → after | Mesh nodes, before → after | All recipe records, before → after |
| --- | ---: | ---: | ---: | ---: |
| Chemical Plant | 50,877 → 52,701 (+1,824) | 694 → 726 (+32) | 597 → 620 (+23) | 703 → 726 (+23) |
| Ice Cap | 47,505 → 46,977 (−528) | 509 → 493 (−16) | 368 → 356 (−12) | 526 → 509 (−17) |
| Lava Reef | 53,259 → 48,663 (−4,596) | 613 → 539 (−74) | 392 → 390 (−2) | 500 → 498 (−2) |

Mesh instances include every repeated MultiMesh transform. Mesh nodes count mesh-bearing recipe records after batching; they are not GPU draw calls. This distinction matters particularly for Lava: its old boulders already batched well, so removing 74 repeated pieces saves only two mesh nodes. Ice's individual crown falls from 16 source mesh pieces / 554 triangles to 8 / 290; Lava's falls from 47 / 2,646 to 10 / 348. Each appears twice in the reference Act. Every Act recipe retains 15 animation bindings.

### Evidence and review limits

The [signature evidence index](theme-identity/signature-20261108/README.md) links native before/after gameplay frames, alternate camera views, native detail crops, small before/after thumbnails, final eight-theme sheets and label-free color/grayscale sheets. Originals remain 1440 × 1000. Pair assembly does not rescale their gameplay pixels. Grayscale and HUD masking apply only to diagnostic copies; production appearance is not altered. This is human composition evidence, not automated recognition or art-quality certification.

The ordinary spawn frame remains the primary test and still clips parts of some heroes. No attempt was made to fit every landmark into every frame. Additional canonical camera targets expose the changed anchors without changing camera behavior. A source snapshot under `test-results/theme-signature/before-source` retains selected artwork and restores only the three pre-pass constructors for supplemental before captures. Failed sandbox attempts and the first Lava winding trial are retained locally and excluded from final evidence.

A concurrent renderer investigation corrected Godot's MSAA precompilation hint between the initial before captures and final verification. Actual captured quality remains 4× MSAA at 100% scale in both states. The supplemental before snapshot uses the current common rendering policy; only the three theme constructors are restored. The renderer fix belongs to its separate commit, and small framebuffer differences in unchanged controls are not attributed to this art pass.

Remaining human review questions:

- Chemical's unchanged distant factory blocks are still generic support architecture; the new vessel, pipes, hazard bands and reservoir carry recognition. Its glowing floor bars can still compete with Rings in motion.
- Ice still reads as general winter scenery where an Act exposes neither the crown nor the mountains/aurora. The new crown is a stronger hero tier, not a promise that every view contains an icon.
- Lava's crater is deliberately graphic and very simple. Judge whether its dark mass feels like the same playful stage vocabulary in motion. Warm hardware versus floor contrast remains unchanged.
- Rooftop clocks and Aquarium fish can be clipped or edge-on. Review camera travel across more Acts before adjusting scenery placement further.
- Sky cloud facets during panning remain unresolved by still images. No smoothing was applied.

### Signature verification

The supported baseline passed **32 suites / 8,596 checks / zero assertion failures**, plus the geometry suite's six fresh-process reload checks. The separate focused theme/decor suites passed 1,007 checks, and the existing scenery regression passed 7,647 checks covering deterministic placement, bounded local scenery and gameplay isolation. The final geometry-bake rerun passed 2,842 checks after the unit-mesh refinement; that result is already included in the baseline rather than counted twice. [Verification receipts](theme-identity/signature-20261108/verification.json) include suite names and local log hashes.

Rebuilt all 40 Prototype and 56 Endless variants against the current shared source. Their freshness audits passed 425 and 489 checks respectively; the Prototype audit is already inside the 32-suite baseline. All six canonical capture sets passed: two eight-theme before sets and two eight-theme after sets at 135 checks each, plus the three-theme before/after hero sets at 55 each. Every final capture uses validated disk resources, with zero fallback builds. The exporter also verified matching gameplay/camera state, atmosphere, graphics, selected texture pixels and renderer metadata. Native pairs, detail crops, thumbnail comparisons and final sheets were visually inspected.

A normal input-only Lava Challenge run completed 3,600 physics ticks at 120 Hz, scored 755 and retained at most three Acts, with zero fallback builds. Its timing values are not used as a performance comparison. An isolated export of committed base `afb75de` plus only this pass's scoped source/tests also passed a fresh import, 603 focused checks and one valid bake for each changed theme. This checks independence from separately owned local artwork; it is not substituted for the selected-art capture source.

One initial Traversal Prototype run failed because its separate test fixture bake predated the concurrent rendering-policy fingerprint change. Rebuilding that fixture restored all 20 checks; no assertion was weakened. The full Endless baker completed with exit code zero and emitted one `RendererDummy::DummyMesh` allocation diagnostic at shutdown, matching a pre-pass diagnostic preserved in earlier regression logs. Subsequent disk audits passed. Earlier restricted headless runs retain Windows certificate diagnostics; selected Casino raw-image warnings and intentional negative-fixture/archive errors remain distinguished from assertion failures. Final graphical capture logs contain no script or engine errors.

## Identity coverage across gameplay views — 2026-11-09

The current production roster, discovered through `PrototypePlan.source_paths()`, contains **five Acts**: First Try Smooth Decor, RampMania, Reverse C Spring, Secret Entry and SpringUp. The review covers every Act × eight themes at ordinary spawn, representative mid-Act and upper gameplay targets: **120 views**. Alternate targets affect evidence only. Native capture settings, gameplay state and selected art remain the canonical Prototype authority.

The [120-row coverage matrix](theme-identity/coverage-20261109/coverage-matrix.md) records primary anchors, mid motifs, far silhouettes, readability and weaknesses. [CSV](theme-identity/coverage-20261109/coverage.csv) and [annotated counts](theme-identity/coverage-20261109/coverage.json) support filtering. These are visual judgments, not an automated classifier or a numerical quality gate.

Most decorated Acts already carry identity through supporting props. Rooftop's roof masses, awnings and arches survive a clipped clock. Aquarium's tubes, curved roofs and lanterns survive an absent fish. Green Hill, Casino, Sky and Lava were retained as controls. RampMania has no authored decor slots; its course-filled interior frames expose weak shape coverage for Ice, Rooftop, Sky and Aquarium. Green Hill, Casino and Lava remain more pattern-led there. Secret Entry's upper Ice view also lacked a major frozen silhouette.

Chemical's old distant factory was not merely generic: its position in the shared Zone backdrop put it outside the reviewed gameplay views. Five low pipe-bridge/reservoir silhouettes now replace those blocks near the backdrop's downstream water. Their simplified open profiles, cyan collars and yellow feet form a distinct far tier using existing unit meshes and materials. They do not duplicate or enlarge the hero vessel. Ice adds two angular, snow-capped frozen gates using existing opaque library pieces and batching. The crown, local mountain/arch composition and aurora remain unchanged. A small local Ice-frame trial provided no visible benefit in the weak interiors and was removed.

All ten changed-theme upper views now expose the new far tier. The final annotation counts are **37 identifiable heroes, 99 views with at least two listed mid motif families, 18 with a far silhouette (previously 8), and 20 primarily color/texture-dependent views (previously 21)**. Identifiable clipped heroes count; ordinary small support props do not. These counts do not establish universal shape-only recognition. The remaining surface-dependent views are all in RampMania: three tiers each for Green Hill, Rooftop, Casino, Sky, Lava and Aquarium, plus Ice spawn/mid. Filling those opaque course interiors with external scenery would not solve their composition limit. No invisible extra geometry was retained to inflate coverage.

Evidence: [all-theme spawn](theme-identity/coverage-20261109/spawn-after.png), [mid-Act](theme-identity/coverage-20261109/mid-after.png), [upper](theme-identity/coverage-20261109/upper-after.png), and [label-free camera-travel sheet](theme-identity/coverage-20261109/label-free-after.png). The [evidence index](theme-identity/coverage-20261109/README.md) links the three before/after comparison sheets, native pairs for every changed Act/theme/target, detail strips and manifests. Six unchanged control themes explicitly reuse their baseline captures. All 30 changed-theme pairs match gameplay/camera state, atmosphere, graphics, renderer metadata and selected texture inputs; all accepted captures use disk bakes with zero fallback.

Shared-background deltas, counted once per theme: **Chemical +1,200 triangles / +10 mesh instances / +10 mesh-bearing nodes; Ice +240 triangles / +12 instances / +3 nodes**. All 40 Act/theme recipe geometry and animation counts remain unchanged. Mesh-bearing nodes are a submission proxy, not measured GPU draw calls. Added lights, animations, transparent materials and shaders: zero. New far meshes are shadowless. [Full accounting](theme-identity/coverage-20261109/metrics.json).

Rebuilt the affected two themes for five Prototype and seven Endless Acts, then audited all 40 Prototype and 56 Endless variants. [Verification receipts](theme-identity/coverage-20261109/verification.json) record the supported baseline, scenery determinism and collision/gameplay isolation, geometry contracts, appearance checks and clean-source verification. The historical `decor_runtime_smoke.gd` direct-child assumption was deliberately left alone; this pass does not alter authored decor-root ownership or the unrelated local Green Hill batching work.

The current supported baseline passes **32 suites / 8,596 checks / zero failures**, plus six fresh-process reload checks. Focused theme/decor checks pass 1,007 assertions, scenery determinism/isolation passes 7,347, and accepted capture regressions pass 2,610. A clean HEAD export plus only these scenery edits passes import, 500 focused assertions and both theme bakes. Scenery's count drops by 300 because 25 fewer direct far roots are checked across 12 settings; no test assertions changed. Existing engine/selected-art warnings and intentional negative-fixture errors remain documented in the receipts.

Human motion review remains necessary for the new far tiers during Zone travel, Chemical glow versus Rings, Sky cloud facets and Lava hardware/floor contrast. The latter issues, selected textures, Hybrid materials, gameplay cameras, mechanics, Act geometry and physics are outside these edits. Previous pass history above remains unchanged.
