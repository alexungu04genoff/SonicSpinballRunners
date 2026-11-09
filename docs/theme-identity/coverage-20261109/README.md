# Identity coverage across gameplay views

The production Prototype roster discovered through `run_plan.gd` contains **five Acts**: First Try Smooth Decor, RampMania, Reverse C Spring, Secret Entry and SpringUp. Eight themes × five Acts × three camera targets gives **120 reviewed views**. [Roster, targets and source fingerprints](roster.json).

These are canonical 1440×1000 Prototype captures: served Ball, seed 18, fixed time, Forward+/Vulkan, 4× MSAA, 100% render scale and validated disk recipes. Spawn uses ordinary framing. Mid/upper move only the evidence camera target to an authored gameplay position; they are representative views, not a recorded playthrough. No camera behavior or gameplay source changed.

Evidence reflects the current working tree's selected artwork. Unrelated local Acts/art are preserved and excluded from this source commit. [Source scope](source-scope.json) records the working and scoped hashes. Clean-source checks establish independence from those local edits; they do not substitute different artwork into the appearance evidence.

## Review

- [Complete 120-row visual matrix](coverage-matrix.md), [filterable CSV](coverage.csv), [annotations and factual counts](coverage.json).
- [All-theme spawn before](spawn-before.png) / [after](spawn-after.png).
- [All-theme mid-Act before](mid-before.png) / [after](mid-after.png).
- [All-theme upper before](upper-before.png) / [after](upper-after.png).
- Changed-theme comparisons: [spawn](spawn-comparison.png), [mid](mid-comparison.png), [upper](upper-comparison.png). Each shows Chemical then Ice; five Act rows per theme, before on the left and after on the right.
- [Label-free before](label-free-before.png) / [after](label-free-after.png). Theme rows follow registry order: Green Hill, Chemical, Rooftop, Casino, Sky, Ice, Lava, Aquarium. Columns group the five Acts in roster order, with spawn/mid/upper within each Act. Only these diagnostic copies mask the HUD.
- Native-pixel detail strips: [Chemical](chemical_plant-detail.png), [Ice](ice_cap-detail.png), before above after. Both use RampMania upper, source rectangle `(480, 0, 940, 230)`.

The [capture index](index.json) links **60 untouched native images** under `native/`: before/after for both changed themes at every Act/target. All 150 accepted capture records have copied manifests and provenance under `receipts/`. The complete original 120-view baseline and 30-view final batch remain locally under `test-results/theme-coverage/`.

Copied text receipts use LF line endings to match repository policy; their recorded hashes therefore survive checkout. Original local logs retain their original bytes. Native images are copied without modification.

The six unchanged control themes reuse their baseline images in final sheets, explicitly. Their source hashes and all-Act recipe accounting remained unchanged; these are not represented as 90 new captures. [Pair verification](pair-verification.json) checks all 30 new pairs for identical gameplay/camera state, atmosphere, graphics, renderer/device/version, selected texture matches and authored source hashes. Output directories and selected theme CLI lists differ deliberately. Every accepted capture has zero source fallback builds.

## What the images establish

Most authored supporting props already work. Rooftop retains roofs, awnings, arches and stucco when its clock disappears. Aquarium retains tubes, curved architecture and lanterns without the fish. Green Hill, Casino, Sky and Lava retain their established vocabulary on the decorated Acts.

RampMania has **zero authored decor slots**. Its close course-filled views expose a real limit: no amount of rearranging scenery beyond the contour can put that scenery inside an opaque course-filled frame. Ice, Rooftop, Sky and Aquarium are weakest there. Green Hill checker/grass, Casino card faces and Lava rock/lava patterns remain recognizable but primarily surface-led. Chemical's existing fat ramp pipes and collars already provide a shape cue.

The final changes address visible backdrop opportunities rather than adding invisible geometry:

- Chemical replaces five generic far factory blocks with five simple paired pipe bridges, cyan collars, low magenta reservoirs and yellow feet. They use the existing shared unit meshes/materials and static batcher. The district now sits near the downstream part of the shared Zone backdrop, rather than beyond the far upstream skyline.
- Ice adds two opaque angular frozen gates with broad snow caps, using the existing library and batcher. The crown, local mountains, local arches, aurora and authored props are unchanged.
- All ten changed-theme upper views expose the new far tier. No visible gain is claimed for spawn or mid-Act. A trial replacing secondary local Ice mountains with small frames did not help the weak interior views and was removed.
- The other six themes remain unchanged. No selected textures, Hybrid materials, camera settings, Act geometry, physics, mechanics or hero dimensions changed.

| Review aid, out of 120 views | Before | After |
| --- | ---: | ---: |
| Identifiable primary anchor, including recognizable clipped anchors | 37 | 37 |
| At least two listed mid motif families | 99 | 99 |
| Identifiable far silhouette | 8 | 18 |
| Primarily color/texture-dependent | 21 | 20 |

These are counts of manual annotations, not a quality score or recognition benchmark. Motif families can include broad surface patterns. Surface-dependent does not automatically mean unreadable: Casino's card deck is a good example. The remaining 20 surface-dependent views are all RampMania: all three targets for Green Hill, Rooftop, Casino, Sky, Lava and Aquarium, plus Ice spawn/mid. Their limits remain visible in the matrix and thumbnails.

## Cost and verification

[Full all-Act recipe accounting](metrics.json) includes off-camera geometry. Act triangle, mesh-instance, mesh-node and animation counts are unchanged for all 40 Act/theme combinations. Shared backgrounds are counted once per theme, not multiplied by the number of Acts.

| Shared background | Triangles | Mesh instances | Mesh-bearing nodes after batching |
| --- | ---: | ---: | ---: |
| Chemical | 542 → 1,742 (+1,200) | 31 → 41 (+10) | 21 → 31 (+10) |
| Ice | 1,164 → 1,404 (+240) | 49 → 61 (+12) | 2 → 5 (+3) |

Mesh-bearing nodes are only a submission proxy, **not measured GPU draw calls**. Added lights, animation bindings, transparent materials and shaders: zero. New scenery is shadowless; Chemical's background meshes now also explicitly disable shadow casting, matching the existing shadowless backdrop light. Ice's unchanged lake retains its previous mesh flag. No FPS claim follows from these counts.

[Verification receipts](verification.json) record the current run, including supported baseline suites, scenery determinism/gameplay isolation, bake audits, geometry contracts and clean-source checks. Rebuilt the two affected themes for all five Prototype and seven Endless Acts: 24 variants. Audited all 40 Prototype and 56 Endless variants, including unchanged controls. No assertion was weakened.

Current results: **32 supported suites / 8,596 checks / zero failures**, plus six fresh-process reload checks. Focused theme/decor checks pass 1,007 assertions; scenery determinism/isolation passes 7,347; accepted capture regressions pass 2,610. Prototype and Endless bake audits pass 425 and 489 checks respectively (Prototype is already included in the baseline). The clean-source export passes a fresh import, 500 focused assertions and both changed-theme bakes. The separate traversal fixture was refreshed before its passing 20-check run.

Scenery's total is 300 lower than the previous pass because Chemical now has five district parent groups instead of 30 separate far mesh roots. Its unchanged test checks each far root across 12 settings: 25 fewer roots × 12. No assertion or test source was removed; all existing ownership, RNG, placement, camera, Ball and collision checks remain. Existing Casino raw-image warnings, intentional negative-fixture errors and the documented Godot ObjectDB shutdown diagnostic are retained in logs and distinguished from assertion failures.

`decor_runtime_smoke.gd` was deliberately left alone. Its old direct-child ownership assumption is separate from these shared-background edits and the unrelated local Green Hill batching work. No production structure was changed to satisfy it.

Human motion review remains useful for the two new far tiers during Zone travel, Chemical glow versus Rings, Sky cloud facets and Lava hardware/floor contrast. Sparse full-course compositions need a later authored composition decision if stronger shape-only coverage is desired; this pass does not claim to solve them.

## Reproduction and exclusions

1. Run `tests/theme_coverage_roster.gd` in Godot headless and review its proposed camera targets.
2. Bake the relevant themes through the supported Act baker.
3. Run `tools/capture_theme_coverage.ps1` with a new output root. It delegates to the existing canonical capture tool, validates source hashes and rejects fallback captures. `-Themes chemical_plant,ice_cap` selects the changed subset.
4. `tools/export_theme_coverage.ps1` assembles this evidence layout from the accepted before/after batches. The manual matrix is reviewed separately; the exporter does not classify images.

The first baseline target proposal duplicated First Try's mid target for upper. Its replacement `(350, 125)` was captured for all eight themes **before production edits**, under `before-first-upper-corrected`; the duplicate eight-view trial is excluded. The accepted baseline contains 120 distinct Act/theme/tier records. Oversized/hidden skyline trials under `trial*` are also excluded. Historical evidence and prior pass documentation are preserved.
