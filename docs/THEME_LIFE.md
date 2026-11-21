# Theme Life — environmental motion

**Current production selection, November 21.** Casino Night uses B, the rotating large star signs. Rooftop Run keeps C pending Alex’s call on the clock hands. Sky Sanctuary keeps C after the follow-camera review. Green Hill, Chemical Plant, Ice Cap and Aquarium Park use C. Lava Reef is outside the system. [Six-second comparisons, measured costs and verdicts](THEME_LIFE_PRODUCTION_REVIEW.md)

The following sections preserve the original seven-theme study, starting at `ecbe1b812f0b0be11b7f3364c83e084fd0424c0a`. Its recommendations and measurements below refer to that earlier rendering baseline.

## Ownership and time

`scripts/theme_motion/registry.gd` is the single promotion table. Its `PRODUCTION` dictionary selects one state per theme. `controller.gd` is a small RefCounted owner attached to each included resident Zone's existing backdrop. Prototype and Endless use the same attachment paths.

Native C uses original shader `TIME` and the existing pause-aware Flicky clocks. No global shader time is introduced. A nonnegative `time_override` sets an explicit environmental time on the Zone's existing private atmosphere materials. `seek(7.25)` is absolute and repeatable; `seek(-1)` restores native time. The controller does not duplicate those materials. Cached recipe materials remain read-only. All selection, tier and time values are process-local.

New transform and signal animations use explicit `theme_motion` metadata with three accepted kinds: rotate, drift and signal. Bindings contain candidate, period, phase and, when applicable, finite axis/amplitude. Each binding caches its original local transform. Evaluation starts from that transform, so scrubbing cannot accumulate drift. Unknown kinds fail validation; arbitrary scripts are still rejected by the original recipe adapter. Existing mechanics and Flicky adapters remain explicit.

Metadata travels through PackedScene records. Static batching protects declared moving subtrees. Theme-specific background batching extracts and restores only those subtrees. One Zone update evaluates cached references; there is no per-prop `_process`, per-frame tree search, physics, navigation, gameplay RNG or event dependency. Weak references avoid retaining retired Act nodes. Zero-weight backgrounds disable rendering and background animation work. Scene close releases controller references.

Native water and atmospheric shader phase intentionally stays continuous and global, matching C. Candidate transform phases use pause-aware Zone age seeded by `zone_index × 1.731` seconds; absolute diagnostic time overrides that offset so isolated comparisons match. Hidden Zones advance only this cheap scalar while skipping background transforms and Flicky callbacks. Foreground candidates remain independent of background visibility. Two resident Zones own independent controls and private materials. Same-theme adjacency does not rebuild or reset an existing Zone's clock.

## Source inventory

This inventory excludes Rings, Sonic, Goals, enemies, flippers, bumpers, score chutes and other gameplay presentation. Rendered evidence and checks are recorded below, separately from source conclusions.

| Theme | Existing environmental motion | Implementation | Location | Cost owner | Native pause semantics | Disk path |
| --- | --- | --- | --- | --- | --- | --- |
| Green Hill | Ocean bands; hopping/looking/flapping Flickies | `green_hill_ocean.gdshader`; explicit `island_flicky.gd` adapter | Ocean BG; decorative birds | GPU fragment; existing callback per bird | Shader TIME continues through tree pause; birds pause | Shader resources and explicit node-reference binding |
| Chemical Plant | Reservoir ripple bands | `chemical_reservoir.gdshader` | BG reservoir | GPU fragment | Native TIME | Material in recipe |
| Rooftop Run | Canal reflections | `rooftop_canal.gdshader` | BG canals | GPU fragment | Native TIME | Material in recipe |
| Casino Night | None in environmental constructors | Stars, signs and reels were static | Decor/BG | None | Static | Static recipes |
| Sky Sanctuary | None; cloud shapes and cloud-sea noise were static | `sanctuary_clouds` and `sanctuary_cloud_volume` have no original TIME | BG | Static shaders | Static | Materials/MultiMesh |
| Ice Cap | Aurora folds and displacement; falling snow; lake reflection response | `ice_aurora`, `ice_snow`, `ice_lake` shaders | BG/local scenery | GPU vertex/fragment; snow MultiMesh | Native TIME | Materials and CPU-saved instance transforms |
| Aquarium Park | Broad waves, normals, caustics and lantern reflection ribbons | `aquarium_water.gdshader` | Water and decorative tank surfaces | GPU fragment | Native TIME; pre-existing override | Material in recipe |

No environmental AnimationPlayer, AnimationMixer, Tween, timer-driven animation, native particle emitter or additional scripted animation was found in the seven theme/decor constructors. Snow is a 48-instance shader-driven MultiMesh, not a particle simulation. Clouds that merely have volume-lighting shaders are not counted as existing motion.

The canonical Green Hill fixture contains **zero Flickies**. The inventory above describes available source systems, not a claim that every system is present in this Act. Bird time control and pause behavior have a separate 11-check runtime regression; the canonical Green Hill images demonstrate ocean motion only.

## C/A/B studies and noise budgets

| Theme | C | A | B | Stable elements / intended timing |
| --- | --- | --- | --- | --- |
| Green Hill | Ocean + Flickies | Bounded, very slow cloud travel | Broad coastal tide within existing ocean shader | Palms, islands and turf stay fixed; relaxed coast |
| Chemical Plant | Reservoir ripple | Directional broad feed lanes | Local circulating eddies in the reservoir | Pipes, lamps and playable deck stay stable; continuous industrial flow |
| Rooftop Run | Canal reflections | Actual clock hands on existing faces | Existing festival balloons drift within finite bounds | Buildings and awnings stay fixed; architectural/meandering alternatives |
| Casino Night | Static theatrical scenery | Restrained staggered illumination on large star signs | Slow mechanical rotation of large star signs | Small deck ornaments, playable neon and Rings remain untouched |
| Sky Sanctuary | Static cloud sea/banks | Broad bounded cloud-bank drift | Continuous cloud-sea advection | All monumental ruins remain stable |
| Ice Cap | Aurora + snow + lake | Explicit alias of C | Explicit alias of C | No additional motion justified; no extra particles |
| Aquarium Park | Existing water | Broad moving caustic cells confined to water | Two existing tank silhouettes move within their tanks | Architecture and giant palace fish reliefs remain fixed |

Ice A/B are deliberately not invented alternatives. The brief permits zero new candidates where C is sufficient. No candidate adds geometry, lights, textures or transparent effects. Transform bindings can increase retained recipe records and reduce batching even when C is selected; measurements must include that infrastructure cost.

## Developer tiers

No graphics-menu feature or saved setting is added. `NATIVE` is ordinary launch. `FULL` enables the selected state and existing supporting motion. `STATIC` freezes environmental systems at diagnostic time zero; gameplay remains unchanged. It is a measurement control, not a promise that static shader ALU disappears.

| Theme | SIGNATURE | FULL adds |
| --- | --- | --- |
| Green Hill | Ocean, including B tide if selected | Flickies; A cloud travel |
| Chemical Plant | Selected reservoir mode | Nothing |
| Rooftop Run | C canal, A hands or B balloons | Canal with A/B |
| Casino Night | A signals or B rotating signs; C remains static | Nothing |
| Sky Sanctuary | A cloud banks or B cloud sea; C remains static | Nothing |
| Ice Cap | Aurora | Snow and lake |
| Aquarium Park | C/A water or B tank fish | Water with B |

## Bounds, materials and transparency

Cloud vertex displacement has a finite native culling allowance, including instance scale in Sky's background MultiMesh. Foreground contribution capture recognizes only the known source vertex program and adds its finite envelope; unknown deformation still fails open. Transform bindings add bounded translation/rotation envelopes without changing collision. Existing Ice aurora retains its finite margin. Ice snow's maximum vertical wrap displacement is nine units; its inherited six-unit margin was insufficient and is corrected without changing snow trajectories.

The existing aurora and Aquarium tank glass retain their transparency. Candidate water, cloud and sign work adds no blended particles, passes or dynamic lights. Casino signals animate the existing private emission energy rather than a light. Source materials and their palette mappings remain current.

## Review tool

Launch `Environmental Motion Lab.cmd`, or use `tools/run_theme_motion.ps1`. The launcher requires a secondary display and puts the window there. The Lab opens the actual canonical disk-backed Prototype fixture using First Try Smooth Decor, frozen gameplay, Sonic and the normal production camera. It requires fresh recipes and never falls back to source geometry.

Controls cover seven themes, C/A/B, tiers, production/N64/off Retro, normal/wide/close cameras, play/pause, a 0–20 second scrubber, ±1 second, reset, summary/counters, screenshot, six-second MP4 capture, matched C/A/B sheet and an unsaved Rooftop/Sky side-light diagnostic. The normal production Retro view owns recommendations; wider/off views only explain them.

`tools/run_theme_motion.ps1 -Capture` records six-second, 15 fps clips and a separate uncapped benchmark for every C/A/B state. `tools/theme_motion_media.py` encodes with local FFmpeg, writes an HTML index, contact sheet, overview and CSV, then removes only successfully encoded enumerated frame files. Raw images and benchmark caches are ignored, not committed. Use fresh output directories below `test-results/theme-motion`; never use the Thursday matrix directories.

`--motion-variant=id` selects an existing atmosphere through the real fixture. Only Green Hill, Rooftop and Casino currently have non-Default variants. No synthetic atmosphere is saved for the other four themes. Measurements include frame percentiles, render CPU/GPU sums, draws/objects/primitives/shadow draws, controller counts, measured motion work, preparation, warm-up pipeline counts and resources. Transparent draw counts are unavailable and reported as null. Viewport CPU/GPU sums can overlap; they are not hardware-wide GPU timer certification.

## Evidence and decisions

The original review recommended **Green Hill C, Chemical Plant C, Rooftop Run A, Casino Night B, Sky Sanctuary A, Ice Cap C and Aquarium Park C**. The registry selected C for all seven at that handoff.

Open the [review index](theme-life/index.html), [current versus recommended contact sheet](theme-life/contact-sheet.png), or [seven-theme moving overview](theme-life/seven-theme-overview.mp4). The index includes individual C/A/B clips and capture receipts. The main capture uses the canonical Prototype Act with a right-side camera focus. Every one of the 21 theme/state combinations has matching normal, close and wide captures with production Retro, N64 and Retro off, plus normal spawn and left-side views. Normal production Retro and spawn readability govern the recommendation; close, wide and Retro-off images explain visibility and filtering tradeoffs.

Visual judgments below come from matched PNGs and inspected sampled clip frames. They do not claim continuous live playback review, gameplay feel certification or complete visibility from every authored Act. Six-second clips sample the motion at deterministic times; they are not seamless animation loops.

### Recommendation and visibility matrix

| Theme | Recommended state | Normal camera and spawn | Close and wide views | Rejected alternatives |
| --- | --- | --- | --- | --- |
| Green Hill | **C — existing ocean** | Broad ocean bands already supply readable coastal motion at the right edge. Spawn emphasizes the deck; the canonical Act has no Flickies. | Close crops peripheral scenery. Wide explains the cloud placement, but A does not establish a useful normal-camera signal in this fixture. | A cloud travel is too peripheral and slow to earn a new system here. B adds tide deformation to water that already reads as alive. Keep palms and islands stable. |
| Chemical Plant | **C — existing reservoir ripple** | Large machinery and the foreground wall obscure most reservoir area. Neither new flow pattern earns attention at ordinary zoom. | Wide reveals more reservoir; close increases machine occlusion. This is a visibility limit, not evidence that the shaders do not animate. | A directional lanes and B circulating eddies remain background details with insufficient normal-camera benefit. Extra lamp or deck animation would compete with existing strong neon cues. |
| Rooftop Run | **A — clock hands** | Large architectural faces give the hands a readable, place-specific role. Buildings, canal banks and playable surfaces remain stable. | Close makes the hand positions explicit; wide retains the large clock silhouette. Balloons become clearer only as peripheral scenery enters the frame. | B balloon drift contributes less at the ordinary camera. Keep the existing canal as supporting motion rather than replacing the clock's architectural identity. |
| Casino Night | **B — rotating large star signs** | Large side signs change silhouette clearly, including the prominent spawn-side sign. Ring trails, Sonic and bumper markings remain distinguishable. | Close confirms mechanical rotation; wide preserves the major sign silhouettes. Small deck stars and reel graphics stay fixed. | A's restrained emission changes are faint among already saturated neon. Increasing brightness would worsen bright flattening. B obtains a stronger result by moving the existing silhouette. |
| Sky Sanctuary | **A — cloud-bank drift** | At the normal right edge, cloud silhouettes move behind fixed arches and floating ruins. Spawn is mostly deck, so the background signal is limited there. | Wide makes cloud travel easiest to compare. Close may crop the cloud banks; that does not justify moving the monumental architecture. | B cloud-sea advection reads as a weaker, more water-like change. A gives a clearer sky identity while keeping ruins stable. |
| Ice Cap | **C — existing aurora, snow and lake** | Existing cold atmospheric motion is sufficient. The ordinary view retains strong ice silhouettes and stable gameplay surfaces. | Wider framing exposes more atmosphere; close emphasizes fixed ice forms. A/B are exactly the C study, not additional effects. | No new candidate is warranted. Additional particles or moving ice would add noise without a demonstrated need. |
| Aquarium Park | **C — existing water** | The broad caustic lattice and reflection ribbons already make the water legible. Tank fish are mostly above the normal left/right frame; the large spawn-side palace fish relief correctly stays static. | Wide exposes the tank silhouettes, making B a possible secondary detail there. Close crops their useful area further. | A replaces the crisp lattice with duller broad cells and weakens water structure. B is restrained but earns little at normal zoom. Preserve the stronger existing water and fixed architectural reliefs. |

The large clock, rotating star and moving cloud silhouettes survive the production filter well enough to support their recommendations. Production Retro softens small motion and can flatten bright regions; the N64 and off captures are comparison controls, not separate art directions. Retro-off exposes geometric and shading detail that may disappear in production, so an improvement visible only with the filter disabled is not sufficient. No new motion was observed crossing the gameplay objects in the inspected recommended views; this remains a camera-sample review, not exhaustive gameplay coverage.

### Temporal profile and finite envelopes

These values are verified from the shader coefficients and declarative metadata. A sinusoid with angular rate `w` has period `2π / w`; the table lists component periods rather than implying that a multi-rate scene repeats as one short loop. Distances are shader/local units before parent scale unless stated otherwise.

| Theme | Existing C timing | A timing / envelope | B timing / envelope |
| --- | --- | --- | --- |
| Green Hill | Ocean components: approximately 26.18 s and 20.27 s. Available Flickies use a 4.8 s cycle, absent from this canonical fixture. | Cloud X travel: approximately 114.24 s, ±0.45 local units. Native cloud bounds include the displacement. | Tide coordinate bend: approximately 33.07 s, ±1.1 water-coordinate units; fragment shading only, no surface displacement. Existing water components continue. |
| Chemical Plant | Ripple: approximately 9.67 s. | Directional lanes: approximately 14.96 s; fragment shading only. | Eddy component: approximately 12.08 s, mixed with the existing ripple and spatially faded within reservoir cells; fragment shading only. |
| Rooftop Run | Canal reflection ripple: approximately 13.96 s. | Clock hands: 48 s and 576 s per revolution, around the authored face pivots. | Balloon sinusoid: `19 + 2.7 × variant` seconds; the three source balloons use 19, 21.7 and 24.4 s. Maximum translation is `0.38 × radius` along the normalized authored drift axis. |
| Casino Night | Static environmental scenery. | Large-sign signal: 7.6 s, deterministic per-sign phase, 0.72–1.00 times the original private emission energy. It never raises the original maximum. | Large-sign rotation: `23 + 4 × size` seconds, currently 24.68–26.52 s per revolution, with deterministic position/size phase. Fivefold star symmetry makes similar silhouettes recur roughly every fifth revolution. |
| Sky Sanctuary | Static cloud banks and sea. | Cloud-bank X travel: approximately 78.54 s, ±1.2 local units. Background MultiMesh bounds include the largest instance scale; foreground bounds include the known shader envelope. | Cloud-sea coordinates advance by `(0.022, -0.009)` noise units per second. Continuous advection has no authored short loop; fragment shading only. |
| Ice Cap | Aurora components: approximately 83.78, 139.63, 114.24, 104.72 and 251.33 s. Snow falls at 0.16 units/s through a 10-unit wrap, repeating vertically every 62.5 s; its ±0.3 horizontal drift has a 34.91 s period. Lake components: approximately 83.78, 139.63 and 78.54 s. | Alias of C. | Alias of C. |
| Aquarium Park | Water components: approximately 17.95, 26.18 and 20.94 s, including coupled wave/reflection terms. | Caustic coordinates advance by `(0.055, -0.033)` units/s after the world-position scale of 0.35. No authored short loop; water geometry stays fixed. | Tank fish: `11 + 1.7 × length` seconds; maximum translation is `0.10 × length` along the normalized authored axis. Parent scale/rotation is carried into the flattened recipe's displacement envelope. Palace relief fish are excluded. |

New transform motion restores the exact authored pose when C is selected. Its translation and full-rotation envelopes are captured before animation is applied. No candidate adds a shadow caster; rotating signs and clock hands retain the existing meshes and shadow policy. The Ice snow culling-margin correction from six to nine units covers its pre-existing wrap travel; it does not change the snow's visible path or add snowfall.

### Atmosphere and lighting findings

Supplemental captures used existing **Sunset Hill** and **Ice Hill** atmospheres for Green Hill, **Apotos** and **Slatefall** for Rooftop, and **VIP** for Casino. These were real fixture selections, not saved edits. The remaining themes have no non-Default atmosphere variants to substitute.

- **Sunset Hill** darkens the deck and warms the checker walls; existing ocean motion remains the appropriate choice. **Ice Hill** is close to Default at the inspected right-side camera. Neither demonstrates a need for more motion.
- **Apotos** preserves the warm roof/teal clock relationship and reduces canal contrast. **Slatefall** keeps the clock hand readable while its cool palette and fog substantially soften distant facades. The clock recommendation survives both.
- **VIP** turns reel faces into nearly white blocks and makes yellow/orange areas flatter. Default Casino also has saturated neon cores. This is a visual brightness warning, not a measured HDR-clipping result. Signal A only dims its authored emission; no recommendation calls for brighter signs.

The unsaved lighting comparison uses the established camera-right `direction_basis(2, camera, pitch)` calculation, retaining each light's pitch. It adds no light and changes no saved Default.

| Theme | Lighting recommendation | Evidence and tradeoff |
| --- | --- | --- |
| Rooftop Run | **Retain current production lighting.** | Camera-right light separates wall and roof facets, but it also casts a large clock-tower shadow across the spawn lane beside/under Sonic. Current lighting keeps that lane clearer. Clock hands are readable in both. |
| Sky Sanctuary | **Favor camera-right lighting for a future lighting decision.** | It gives column ends, arch supports and stone facets stronger separation against pale clouds, while the inspected spawn lane remains readable. The Retro-off pair confirms the stone improvement. It does not resolve the bright cloud flattening visible with production Retro. |

These judgments compare the matching `review/<theme>_A_right_normal_production.png` and `spawn_normal_production.png` captures with `supplement/roof-side-light/` and `supplement/sky-side-light/`. Sky's matching `right_normal_off.png` pair supports the shading conclusion. Variant comparisons use the matching right-normal production images in `supplement/green-sunset/`, `green-ice/`, `roof-apotos/`, `roof-slatefall/` and `casino-vip/`. Raw capture paths are under `test-results/theme-motion/`; portable selected evidence is linked from the review index.

Desktop results do not certify Intel UHD 620. The frozen Thursday grounding package remains the primary laptop test; motion tiers provide a future lever after those results. Performance and validation measurements below report their actual scope separately from these visual recommendations.

## Performance evidence

The final 21-state measurement uses Godot 4.7.2, Forward+/Vulkan, RTX 4060, a 1440 × 1000 output window, normal right-focus camera and production Retro. Each state gets 40 warm-up frames and 180 uncapped sampled frames. Gameplay is frozen. Frame capture, image encoding and hidden UI formatting are excluded. These are instrumented desktop frame intervals, not a cold-start or laptop certification. This final run follows the transform-update optimization and supersedes timing recorded during media capture.

All state percentiles, render CPU/GPU timing, submissions, resources, preparation and warm-up counters are in [performance.csv](theme-life/performance.csv) and [performance.json](theme-life/performance.json). Viewport timing sums can overlap. Transparent draw counts are unavailable and remain null. The table retains the original final-run values, including noise; supplemental repeats are discussed separately. These are C/A/B comparisons within the final build. No matched starting-SHA frame benchmark was captured, so default-C infrastructure overhead against the previous binary is not quantified.

| Theme | C median ms | A median ms | B median ms | Recommended p95 / p99 / max ms | A / B cost assessment |
| --- | ---: | ---: | ---: | --- | --- |
| Green Hill | 2.614 | 2.549 | 2.670 | C: 2.993 / 3.312 / 4.244 | Effectively free / tiny within measurement noise |
| Chemical Plant | 2.052 | 2.214 | 2.198 | C: 2.574 / 2.867 / 3.483 | Tiny / tiny; insufficient visual benefit |
| Rooftop Run | 2.469 | 2.669 | 2.609 | A: 3.438 / 3.760 / 3.935 | Tiny / tiny shared CPU work |
| Casino Night | 3.261 | 2.938 | 3.101 | B: 3.856 / 4.797 / 5.152 | Tiny / tiny; frame differences need repeats |
| Sky Sanctuary | 2.394 | 3.172 | 2.381 | A: 5.845 / 6.583 / 6.811 | Tiny / tiny; A frame outlier did not reproduce |
| Ice Cap | 2.235 | 2.288 | 2.454 | C: 2.631 / 2.791 / 3.128 | Effectively free aliases; differences are noise |
| Aquarium Park | 2.588 | 2.663 | 3.132 | C: 3.051 / 3.653 / 3.899 | Tiny / measurable in this diagnostic run |

An earlier Casino B capture run looked substantially slower. Avoiding redundant rest-pose/rotated-pose submissions reduced the work without changing its pose. A separate B/C/B/C repeat then measured medians **2.972 / 3.017 / 3.012 / 3.033 ms**. The original apparent large penalty is not supported by that repeat. Aquarium B still carries extra shared transform work for a visual benefit largely outside ordinary framing, reinforcing KEEP C.

Sky received a longer A/C/A/C repeat with **600 sampled frames per state** after other rendering work finished. Medians were **2.536 / 2.689 / 2.481 / 2.416 ms**, with measured GPU sums approximately **0.660–0.662 ms** across all four cases. The earlier A slowdown did not reproduce; classify its measured cost as tiny, without claiming a desktop speedup. See [repeat measurements](theme-life/repeats.json) for all percentiles from both repeats.

### CPU work and resident resources

Ordinary C adds no environmental per-prop callback. Existing Flickies retain their original callbacks when present. The canonical Act contains no Flickies, so all seven C cases report zero native environmental callbacks. Rooftop A/B, Casino A/B and Aquarium B use one shared update site per visible Zone through its existing follow call. Shader-only candidates use none. The paused Lab adds one diagnostic seek driver; the recorded motion-update times below measure that seek and uniform upload, **not native production controller cost**.

| Theme | Diagnostic seek median ms C / A / B | Animated materials C / A / B | Moving meshes or GPU instances C / A / B | Resident materials / shader resources | Warm signatures | Transparent surface slots |
| --- | --- | --- | --- | --- | ---: | ---: |
| Green Hill | .041 / .039 / .043 | 1 / 2 / 1 | 0 / 9 / 0 | 343 / 17 | 37 | 8 |
| Chemical Plant | .030 / .033 / .033 | 1 / 1 / 1 | 0 / 0 / 0 | 76 / 10 | 19 | 10 |
| Rooftop Run | .174 / .237 / .192 | 2 / 2 / 2 | 0 / 24 / 33 | 102 / 16 | 27 | 18 |
| Casino Night | .428 / .407 / .475 | 0 / 30 / 0 | 0 / 0 / 60 | 116 / 9 | 28 | 8 |
| Sky Sanctuary | .038 / .054 / .039 | 0 / 1 / 1 | 0 / 180 / 0 | 79 / 8 | 20 | 8 |
| Ice Cap | .040 / .043 / .047 | 4 / 4 / 4 | 50 / 50 / 50 | 75 / 14 | 26 | 10 |
| Aquarium Park | .141 / .142 / .212 | 2 / 2 / 2 | 0 / 0 / 54 | 82 / 11 | 25 | 20 |

Counts cover the resident canonical Act plus its shared background, not only visible pixels. Transparent slots describe eligible surfaces, not submissions. Candidate selection adds **zero resident resources** in every measured state and changes no resident material/shader inventory. No candidate adds a shader file, geometry, transparent effect, dynamic light or shadow caster. Casino's full source Decor inventory has five additional material identities for independent signal phases (72 to 77); these are constructed once and private atmosphere copies are reused at runtime.

Draws/objects/primitives and shadow submissions remain identical across C/A/B except Casino B: at the sampled pose one existing sign enters the view, adding one draw/object and 36 primitives. Its shadow submissions remain 461. A/B produced zero new pipeline compilation counters in the measured switching runs. The first Green Hill C measurement recorded one surface and two specialization compilations; this is reported, not hidden as a candidate cost. Full fixture preparation was 3.295–4.974 seconds and the 40-frame warm-up took 112.6–200.1 ms. These runs use existing shader caches; completely cold driver compilation remains unmeasured.

Existing transparency remains a low-end concern, especially Ice aurora and Aquarium glass. A/B do not change transparent surface counts. Their separate state rows measure the existing effects with each candidate, but cannot isolate transparent-pass GPU time. STATIC freezes time; it retains geometry, transparency and shader work, so it is not a guaranteed GPU optimization.

### Bake impact

The [disk audit](theme-life/bakes.json) covers 105 fresh files: seven shared themes and seven authored Acts in each of Prototype and Endless for every included theme. All 623 checks passed. Byte changes include retained moving subtrees even when C is selected; resources in external shared asset banks are excluded.

| Theme | Total recipe bytes | Change from starting files | Current recipe records |
| --- | ---: | ---: | ---: |
| Green Hill | 6,824,554 | −343 | 10,315 |
| Chemical Plant | 6,353,190 | +82 | 11,070 |
| Rooftop Run | 5,697,088 | +44,191 | 8,720 |
| Casino Night | 5,876,607 | +157,108 | 9,461 |
| Sky Sanctuary | 5,596,327 | +308 | 7,428 |
| Ice Cap | 5,716,395 | −142 | 7,690 |
| Aquarium Park | 6,126,540 | +13,788 | 12,216 |

Total increase is 214,992 bytes, about 210 KiB. The initial snapshot captured file sizes only; before/after recipe-record, material and warm-signature deltas are unavailable. Current counts are retained in the audit rather than inventing baseline values. Source construction parity separately verified all 38 affected Decor variants: mesh transforms, triangle counts and shadow-caster counts remain unchanged in C.

## Optional current-code microbenchmark

`Optional Motion Microbenchmark.cmd` runs Rooftop C/NATIVE, A/SIGNATURE and C/STATIC against existing fresh disk recipes. It requires the current checkout, Godot and monitor 2; it needs no editor or rebake. It is not a portable replacement for Thursday's frozen package. It produces JSON/CSV in a fresh `test-results/theme-motion/optional-*` directory.

The executed smoke run completed all three cases: medians **2.464 / 2.668 / 2.525 ms**, p95 **2.827 / 3.657 / 3.501 ms**, with identical 174 draws and 54,305 primitives. See [optional-motion.csv](theme-life/optional-motion.csv). The STATIC result illustrates why freezing time alone does not establish an Intel GPU saving.

## Streaming and lifecycle evidence

The real Prototype transition test passed **435 checks** across Green Hill → Chemical Plant, Rooftop → Casino, Sky → Aquarium, Ice → Ice and Rooftop → Rooftop. Each run loaded six disk Acts and two Zones with zero geometry fallback. Camera distance drove the production crossfade through 0, 0.25, 0.49, 0.51, 0.75, 1, 0.5 and 0; seeks remained 7.25 and 11.75 seconds on the two owners. Materials stayed private and gameplay state stayed unchanged. Zero-weight viewports disabled, and both Zone owners disappeared on close.

The same-theme Rooftop case used actual **Slatefall → Default** atmosphere choices from the existing deterministic variant picker. Its two controllers and private materials remained distinct. Native shader phase continues globally; native transform age is independent per Zone. Entering or reversing a seam does not reset either clock. Absolute diagnostic seeks intentionally align the requested timestamp instead of adding the native Zone seed.

The actual Endless engine additionally passed **32 checks** with Rooftop and Casino, six disk Acts, A/B restoration, five real crossfade weights and zero fallback builds. Retirement exercised its production queue: processing stopped immediately, the retired layer and motion registrations released, the controller weak reference expired after the test released its inspection reference, and scene close released the remaining owner. Focused checks cover foreground candidates continuing while the background is hidden, hidden Flicky callback suppression, same-frame follow calls, paused seeks and unused MultiMesh source-material isolation.

No project-owned animated Node/controller retention was found by those checks. Godot still printed three ObjectDB exit instances in the Prototype transition process and one in the Endless process. These warnings are preserved separately; this pass does not claim to fix native ResourceLoader/ObjectDB cleanup.

## Validation and remaining review

Focused checks actually executed:

| Check | Result |
| --- | --- |
| Theme Motion contract: selection, pause, finite bounds, binding rejection, material isolation, repeated seeks and retirement | 35 passed |
| Custom background batching with scaled/rotated parent drift | 8 passed |
| Shader C parity against starting source at 0, 7.25 and 19 s | 30 passed; exact pixel equality, maximum channel delta 0 |
| Affected source Decor variants | 38 passed; geometry/transforms/triangles/shadow policy preserved |
| Existing Rooftop / Casino / Aquarium / Sky source regressions | 91 / 95 / 95 / 95 passed |
| Existing standalone Flicky runtime regression | 11 passed, including pause/resume and free |
| Included Prototype + Endless disk recipes | 105 files, 623 checks passed |
| Real Prototype transitions and same-theme variant seam | 435 passed |
| Real Endless attachment, crossfade and retirement | 32 passed |
| Main C/A/B capture | 21 clips; all framebuffer repeat checks true; zero capture failures |
| Supplemental atmosphere/lighting/repeat cases | 8 completed, zero manifest failures |
| Final C/A/B performance sweep and optional microbenchmark | 21 + 3 cases completed |
| Final canonical appearance check, explicitly scoped to the seven included themes | 62 passed |

### Supported baseline result

The unfiltered supported baseline ran once: **32 suites, initially 28 passed and 4 failed**. The traversal Prototype failure was a stale Green Hill bake for `tests/fixtures/traversal_diagnostic.tres`, outside the production Act pool. That single derived fixture was refreshed, the existing shared Green Hill bake was restored byte-for-byte, and the affected suite passed **20/20** on rerun. No fixture Act data or test assertion changed.

The resulting status at this pass's handoff was **29/32 passing**, with three unresolved all-eight-theme suites: `prototype_setup`, `prototype_appearance`, and `endless_bake_audit`. Their blocker was the excluded Lava Reef cache: the shared theme and seven published Act recipes had old pipeline fingerprints after shared recipe infrastructure changed. The bake audit reported exactly those eight stale entries. Lava source/assets/atmosphere/motion and its derived caches were intentionally not modified in this pass. No freshness check was relaxed or hidden. A separately scoped seven-theme appearance follow-up passed 62 checks; it did not replace the unfiltered failure. The [validation receipt](theme-life/validation.json) preserves both outcomes and the original baseline results. The subsequent [current-main closure](CURRENT_MAIN_CLOSURE_2026_11_18.md) refreshed the derived caches through the normal baker and passed **32/32 suites, 8,702 checks**, with production defaults unchanged.

This has a practical local consequence: **an all-eight-theme setup cannot start until Lava's derived caches are refreshed in a later, separately scoped bake**. Runs selecting the seven included themes have validated recipes. The frozen Thursday package remains untouched and independent. The full baseline failures are retained in the validation receipt, rather than relabeled as a green baseline.

Final scope verification found all 480 frozen authored/art/atmosphere/default inputs unchanged, and all 14 canonical Act/shared-theme bake hashes still match the captured media. Review videos and selected compressed stills are committed; raw frames, generated recipes and temporary benchmark caches remain ignored. All visible validation and review windows ran on monitor 2.

The follow-up evaluated Rooftop A, Casino B and Sky A beside C during the same served shot. Promotion used the central registry and the normal bake workflow. [Production review](THEME_LIFE_PRODUCTION_REVIEW.md)

The UHD 620 result still decides whether native CPU transform updates, existing transparency, shader work and warm-up meet the laptop budget, and whether a future SIGNATURE tier should ship. Desktop medians cannot settle those questions. STATIC is already available as a diagnostic control, but time freezing alone is not an optimized low-end renderer.
