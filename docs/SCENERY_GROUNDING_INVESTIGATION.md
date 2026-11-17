# Scenery grounding and Thursday UHD 620 investigation

17 November 2026. **No production defaults changed. Recommend zero production scenery proxies.** Camera-right lighting is worth Alex's visual review in Rooftop Run and Sky Sanctuary. The other five themes retain their current direction recommendation. The portable package makes the remaining UHD 620 questions measurable on Thursday, 19 November; desktop timings do not establish that laptop's bottleneck.

[Seven-theme comparison](grounding-20261117/seven-theme-comparison.jpg) · [All comparison sheets and close crops](grounding-20261117/README.md) · [Thursday instructions](THURSDAY_LAPTOP_TEST.md)

## Scope and evidence authority

Starting SHA: `6f9f5c59db237002c37dcd482a964136f2bbe023`. Other chats continued changing the editor and Green Hill. The measured portable project freezes committed source/art at **`a5722d5c1a4396b930069c92e3edd6665695323b`**, then adds this investigation's diagnostics and two explicitly gated logging/Retro startup hooks. Its `grounding-build.json` identifies the base and exact source hashes. Later editor commits are preserved in the shared repository but are not silently substituted into these measurements.

The investigation covers Green Hill, Chemical Plant, Rooftop Run, Casino Night, Sky Sanctuary, Ice Cap and Aquarium Park. Only Rooftop, Sky, Ice and Chemical receive experimental proxy geometry. Lava Reef has no investigation, lighting sweep, proxy trial or artwork change. The existing supported regression baseline still exercises its unmodified historical fixtures.

Measured machine: Ryzen 5 1600X, RTX 4060, NVIDIA driver `32.0.16.1664`, Windows 11 build 22621, Godot `4.7.2.stable.official.ed1daf0bf`. Final matrix: `test-results/grounding-20261117/final/matrix-final/Work-Laptop-20261117-214133`. Native GPU execution was isolated from other Godot processes. Earlier sandbox/concurrent-preview timings are excluded. Every launch records actual renderer/device, source hashes, arguments, elapsed time and OS process CPU time. Private shader caches were warm in the final matrix; preferences were fresh for every run.

Visuals use the real canonical Prototype session, `First Try Smooth Decor`, seed 18, Default atmosphere, served Sonic, zero score/Rings, frozen physics and time. Window: 1440×1000. The opening camera is unchanged; the explicitly labeled edge inspection camera targets `(570, 500)` at zoom `0.8`. Direction sheets use the opening camera. All six proxy modes use the same edge camera. Production Retro and Retro OFF are separate capture sets. Source images are real engine captures, with no image-generated art or color enhancement.

## Live shadow ownership

FG means the gameplay SubViewport's 3D world. BG means a separate Zone backdrop SubViewport/world. “Receives” describes material eligibility **in its own world**, not proof that every pixel receives a cast shadow. The foreground directional light cannot illuminate or shadow a different world. Cast flags alone are insufficient: a BG mesh can retain `ON` while every light in its world has shadows disabled.

| Actual visual category | World | Foreground key light | Casts actual directional shadows? | Receives shadows? | Existing path |
| --- | --- | --- | --- | --- | --- |
| Gameplay terrain, floors and walls | FG | Yes, lit materials | Opaque terrain generally yes; individual excluded surfaces remain off | Lit opaque surfaces eligible | Baked recipe surfaces and static batches |
| Borders and ledges | FG | Lit parts yes; unshaded/transparent accents differ | Canonical Rooftop's 15 border/ledge mesh nodes are off | Lit surfaces eligible; transparent/unshaded accents differ | Existing terrain/border construction |
| Rings | FG | Yes | Yes | Lit Ring material eligible | Individual culled mesh instances, shared shader rotation and native instancing |
| Bumpers/flippers | FG | Yes on opaque bodies | Selected visible surfaces plus existing combined casters; not every visible part | Lit bodies eligible | Rigid actor batching, hidden retracted copies, combined shadow-only meshes |
| Mechanisms and enemies | FG | Yes on lit bodies | Mixed opaque source/caster path | Lit bodies eligible | Protected animated roots, rigid batches and existing hardware shadow groups |
| Rails and supports | FG | Yes | Rail surfaces plus bounded support casters; some visible sources deliberately off | Lit decks/supports eligible | Existing rail-support shadow groups, not this trial |
| Authored foreground Decor slots | FG | **Yes** | **Yes for opaque casters**; glass/glow exceptions remain off | Lit opaque decor eligible | Authored metadata roots, protected components, static spatial batches |
| Act-local theme scenery | BG | No; its own copied directional light | **No**: recursively disabled | Cannot receive FG shadows; its own key is shadowless | `LocalScenery` recipe root, static batches/MultiMeshes |
| Shared/far Zone scenery | BG | No; own light | **No actual shadows**, even where mesh flags retain `ON` | No shadow-casting light in this world | One prepared shared theme scene per resident Zone |
| Backdrop architecture | BG | No; own light | No | No FG shadows | Local or shared architecture follows the two rows above |
| Transparent scenery: glass/water/glow | FG or BG according to ownership | Material-dependent | Actual glass/glow samples are off; do not treat opaque eligibility as transparency proof | Material/world-dependent; BG cannot receive FG shadows | Existing transparent shaders and separate instances |
| Animated theme scenery | FG authored birds or BG themed scene | Own world only | Follows its mesh flags/world; BG animation adds no shadows | Same material/world rule | Existing animation bindings and shader time; no trial callbacks added |
| Combined hardware shadow-only meshes | FG | No visible color pass | **Yes** | No visible receiver surface | Existing rigid sibling/support groups; distinct from scenery trials |
| Duplicate FG/BG copies | Separate worlds where applicable | Own world only | No deliberate production cross-world scenery copy found | Own world only | No same mesh-resource identity + node transform + bounds match across worlds in any of the seven inventories; this is a node-level check, not an exhaustive per-instance pixel proof |

The canonical Rooftop inventory contains 175 authored Decor mesh nodes plus 28 decor batch nodes with casting enabled. It also contains 13 existing hardware shadow-only meshes. Its local BG scenery has eight cast-off mesh/batch nodes; 42 shared BG nodes retain `ON`, but the BG directional light is shadowless. The streamed inventory also observes 24 casting rail-surface nodes across the resident Acts. These are **inventory counts, not draw submissions**.

Seven-theme foreground Decor inventory, including static batches and currently hidden components:

| Theme | Decor mesh/batch nodes ON | Decor nodes OFF | Act-local BG nodes, all OFF | Shared BG nodes ON / OFF |
| --- | ---: | ---: | ---: | ---: |
| Green Hill | 147 | 0 | 148 | 141 / 1 |
| Chemical Plant | 190 | 165 | 58 | 0 / 115 |
| Rooftop Run | 203 | 0 | 8 | 42 / 0 |
| Casino Night | 251 | 0 | 17 | 27 / 0 |
| Sky Sanctuary | 161 | 0 | 9 | 0 / 14 |
| Ice Cap | 148 | 0 | 14 | 1 / 24 |
| Aquarium Park | 470 | 37 | 0 in this fixture | 8 / 38 |

Casino and Aquarium each have two **existing shadowless BG OmniLights**, in addition to their BG directional light. The trial adds no lights. Aquarium's large shared scene and transparent components are not a reason to add another proxy family.

F3 supplies separate bounds for casters, receivers, shadowless geometry, FG, BG and shadow-only geometry. Green means authored Decor, cyan other foreground, gold backdrop, pink shadow-only. Bounds use their own unshaded line meshes; production materials are untouched. `inventory.json` retains node paths, material eligibility, semantic metadata, transforms, bounds, mesh/surface/triangle counts, light ownership and animation scripts. Source corroboration: `themed_presentation.gd`, `zone_backdrop.gd`, `visual_recipe.gd`, `gimmick_shadows.gd`, `rendering_options.gd` and the actual theme/material constructors.

## Effective fresh-install settings and render architecture

Every run directs graphics preferences to a new, nonexistent `isolated-graphics.cfg`. It checks that no settings file was written. The normal player path is never used for diagnostics.

| Setting | Observed production value |
| --- | --- |
| Renderer / driver | Forward+ / Vulkan; RTX 4060 on this machine |
| Gameplay, BG and warm-up MSAA | 4×; project framebuffer-preparation hint also 4× |
| Native 3D scale | 100% |
| Screen-space AA | Disabled / `0`; profile FXAA override `-1` inherits this |
| Directional atlas | 8192 requested/applied through the existing settings path; Godot exposes no corresponding allocation getter here |
| Foreground directional splits | Four cascades |
| Smooth/Ultra toggle | False; this means **SOFT_MEDIUM (3)** from the project, not hard/unfiltered shadows |
| Retro stack | N64-ish + VHS + CRT, IDs `[2,4,3]` |
| Retro resolution divisor | 1.9 with N64-ish; independent of native 3D scale |

For the 1280×900 performance window, production foreground, each BG and the 2D composite SubViewport are 673×473; the output Window is 1280×900. Retro OFF restores 1280×900 foreground/BG/composite before applying native 3D scale: **3.62 times as many 3D pixels**. At the 1440×1000 canonical visual window, the logical world layout is 1296×900, while the actual Retro-scaled foreground/BG/composite viewports are 682×473. The output Window remains 1440×1000. The warm-up viewport is 256×256.

Balanced gives every registered 3D viewport 2× MSAA and 85% native scale. Production-Retro foreground/BG become approximately 572×402 native pixels; warm-up becomes 218×218. Balanced OFF becomes 1088×765. The final runtime receipts show matching MSAA/scale across gameplay, warm-up and streamed BG viewports; no new preparation mismatch was found. The compositor disables 3D. The output Window has no active 3D camera, so it is not counted as another 3D scene.

Settled opening: **two rendering 3D viewports**, FG plus current BG. A Zone crossfade has **three**, FG plus two BGs. Resource preparation can additionally activate the warm-up viewport. Warm-up and zero-weight BG viewports return to `UPDATE_DISABLED`; stale engine counters are explicitly zeroed for disabled viewports. The final lifecycle receipt shows old/current/future BGs disabled/enabled/disabled after transition.

Normal Endless opening retains six Acts, with two foreground-contributing roots; it does not render all six foreground roots indiscriminately. B still retains normal streaming, resources and scheduling but limits rendering to the active Act and current BG. Residency, foreground contribution and actual visible submissions are separate counters.

## Ranked explanation of visual flatness

1. **Direction relative to the camera and authored shapes.** Camera-right gives Rooftop's wall faces, ledges and architectural steps broad light/shadow separation; Sky's column/plinth faces also separate better. These changes occur without proxies or material edits. Camera-left is already close to several production directions. A brighter floor streak alone is not an improvement.
2. **Ambient/emissive presentation and large color patterns can dominate shape cues.** Ice's sun energy is 0.22 against ambient 0.56; Aquarium is 0.44 against 0.93. Chemical's emissive floor remains dominant through the sweep. These are observed settings and image evidence; an ambient-only causal experiment was deliberately not added, so its precise contribution remains unquantified.
3. **Retro reduces the visibility of fine material response.** The N64 resolution reduction and combined treatment make small normal/roughness changes harder to see. Retro OFF is a diagnostic, not the appearance approval target and not automatically a lower GPU workload.
4. **Scenery lacks cross-world contact shadows by architecture.** That fact is real, but it is not the main missing cue in the tested placements. Most selected local structures are below or beside the receiving playfield. Copying their exact silhouette into FG does not make a useful contact shadow appear. Moving them upward would falsify placement and was rejected.

No missing normal map, absent foreground light, blanket “Decor never casts,” or need for new GI was established. Existing foreground Decor already supplies substantial structural shadows.

## Direction sweep and recommendation

Seven directions were captured in both Retro states for every included theme: production, camera-left, camera-right, rays up-table, rays down-table, high 70° and low 20°. Color, energy, exposure, ambient, material values and quality remain unchanged. Side keys use the horizontal camera-right vector; up/down use the table Z axis. Side-key pitch retains production elevation clamped to 20–75°; this changes Casino's 80° to 75°. High/low keys use the camera-left azimuth. Exact rotations and ray vectors are recorded per capture for foreground and BG lights.

| Theme | Production pitch / yaw | Camera-right diagnostic pitch / yaw | Judgment |
| --- | --- | --- | --- |
| Green Hill | −55° / −35° | −55° / +90° | Keep production; darker loop shadows do not establish better gameplay readability |
| Chemical Plant | −67° / −9° | −67° / +90° | Keep production; emissive pattern dominates, proxy difference is peripheral |
| Rooftop Run | −48° / −58° | −48° / +90° | Review camera-right, yaw offset +148°; clear wall/ledge relief |
| Casino Night | −80° / +2° | −75° / +90° | Keep production; little broad structural gain |
| Sky Sanctuary | −64.5° / −26.5° | −64.5° / +90° | Review camera-right, yaw offset +116.5°; stronger column/plinth separation |
| Ice Cap | −52° / −35° | −52° / +90° | Keep production pending motion/readability review; modest wall change, no proxy benefit |
| Aquarium Park | −50° / −30° | −50° / +90° | Keep production; down-table adds an unwanted bright streak around gameplay objects |

Low-angle keys create longer, intrusive shadow bands. They are controls, not proposed Defaults. Rooftop/Sky camera-right remains an **unsaved candidate**. No atmosphere resource was edited. The seven-theme preferred sheet deliberately repeats production for the five themes with no recommended change.

## Proxy experiment and rejection

The trial copies only selected opaque Act-local source components into collisionless FG shadow-only geometry. It never moves the visible BG nodes. Background mapping is traced through `T(backdrop offset − 1200) × T(Act offset − backdrop position) × source`, yielding `T(Act offset) × source`. BG cameras copy the foreground camera/projection. Source global transforms therefore map directly to FG; receipts and magenta reveal captures verify alignment.

Source approach: append the selected source silhouettes into 3-unit spatial groups, at most six groups for the active Act. Hull approach: per-component boxes, preserving gaps between arch columns rather than filling the whole arch. Existing batched names are not semantic authority: selection uses the known opaque component families, material bindings and authored dimensions, then records every exact instance. The four-theme allowlist is explicit. The all-near ceiling copies all opaque local components into bounded cells and is intentionally not recommended.

| Theme / selection | Components / groups | Source triangles / hull triangles | Source / hull preparation, ms | Added shadow draws, current / right key | Result |
| --- | ---: | ---: | ---: | ---: | --- |
| Rooftop: two house bodies and two roofs | 4 / 2 | 24 / 48 | 4.117 / 5.205 | +4 / +2 | No visible gain; source is already simpler than boxes; bodies/roofs sit below the table |
| Sky: opaque ruin-stone arch/column pieces | 24 / 5 | 720 / 288 | 26.317 / 24.522 | +13 / +5 | No useful shadow change; preparation alone is poor value |
| Ice: opaque crystal shafts | 4 / 2 | 138 / 48 | 4.262 / 4.701 | +5 / +2 | No image difference across the seven-direction source trial |
| Chemical: opaque reservoir body/band pieces | 12 / 4 | 720 / 144 | 10.983 / 10.956 | +9 / +9 | Camera-right affects a narrow external wall strip, not broad playfield contact |

Preparation numbers are single diagnostic builds, not portable performance guarantees. They include selection and geometry construction. Reduced triangles do not reduce the number of bounded submissions. Source/hull selection does not add visible-pass draws.

Current-key source proxies produce identical Retro-OFF images in all four themes. Camera-right source proxies are also identical for Rooftop, Sky and Ice in the six-mode run. Chemical changes 2,658 of 1,440,000 pixels (0.1846%), bounded by x=673–686, y=480–792: a 14-pixel-wide exterior wall strip. Hull versus source changes another small peripheral strip. It fails the meaningful-grounding criterion. A separate paired seven-direction source sweep confirms the conclusion: Rooftop/Sky only have occasional one-channel-level rounding differences, Ice is exact throughout, Chemical's lower key creates a larger but still unhelpful external shadow. None improves Ring/character/Goal readability at gameplay distance.

Retro-OFF edge-camera shadow submissions, Modes 0–5 respectively:

| Theme | 0 production | 1 side | 2 current + proxy | 3 side + proxy | 4 all-near | 5 shadows off |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Rooftop | 288 | 241 | 292 | 243 | 298 | 0 |
| Sky | 359 | 324 | 372 | 329 | 373 | 0 |
| Ice | 230 | 208 | 235 | 210 | 243 | 0 |
| Chemical | 187 | 187 | 196 | 196 | 202 | 0 |

Median frame times for those same one-second samples, in ms:

| Theme | 0 | 1 | 2 | 3 | 4 | 5 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Rooftop | 2.457 | 2.528 | 2.476 | 2.297 | 2.309 | 2.109 |
| Sky | 2.430 | 2.345 | 2.443 | 3.056 | 2.508 | 1.912 |
| Ice | 2.462 | 2.081 | 2.076 | 2.086 | 2.068 | 1.750 |
| Chemical | 2.131 | 2.067 | 2.113 | 2.235 | 2.208 | 1.901 |

Small non-monotonic frame differences are noise/drift, not evidence that extra proxies accelerate rendering. Full median/p95/p99/max, visible/shadow objects and primitives remain in the receipts. The decision rests on absent visual value and certain extra work.

**Retained design:** reusable lab-only trial code, default off and unreachable from ordinary launch. Static transforms copy once. Owner changes rebuild bounded groups; no per-decoration process callbacks or per-frame tree scans occur. A small cached-root visibility check suppresses proxies for any positive Zone blend. Source root retirement queues its proxy root for deletion. Real transition checks confirm old proxies retire, the new Zone owns any new trial, restoration frees all proxies, and no light is added. Green Hill, Casino and Aquarium add no unique useful case beyond the four representatives, so no proxy geometry was added to them.

## Controlled Prototype versus Endless

A–E uses 1280×900, production quality/Retro, the same exact Act fingerprint, atmosphere, camera transform/projection, 21.247175 far plane and frozen gameplay/enemy state. Every recorded state field matches across all six A–E captures. Both runtimes resolve presentation at zero delta after the matched camera is set; this avoids comparing arbitrary enemy poses saved by the offline baker. The canonical production-parity captures remain untouched.

Normal Prototype and Endless retain their own HUDs and presentation helpers. Prototype includes additional contact/Goal helper nodes; its visible submission count is not identical to B. Thus A–B includes normal route differences and is not a pure scheduler microbenchmark. B–C–D–E within Endless is the cleaner residency/background comparison.

| Case | Median / p95 / p99 / max, ms | FG visible draws / objects / primitives | FG shadow draws / objects / primitives | Current / next BG draws |
| --- | --- | --- | --- | --- |
| A normal Prototype | 2.321 / 3.057 / 4.427 / 5.198 | 189 / 233 / 54,065 | 378 / 837 / 90,863 | 21 / — |
| B active Act + current BG | 3.407 / 4.029 / 4.486 / 5.487 | 163 / 207 / 51,373 | 380 / 835 / 85,466 | 21 / 0 |
| C normal Endless | 3.170 / 4.358 / 5.544 / 6.056 | 164 / 208 / 52,745 | 585 / 1,488 / 131,821 | 35 / 0 |
| D no next BG | 3.326 / 4.517 / 5.334 / 6.198 | 164 / 208 / 52,745 | 585 / 1,488 / 131,821 | 35 / 0 |
| E all BG disabled | 2.797 / 3.503 / 4.326 / 5.030 | 164 / 208 / 52,745 | 585 / 1,488 / 131,821 | 0 / 0 |
| C repeated | 3.125 / 3.865 / 5.005 / 6.630 | 164 / 208 / 52,745 | 585 / 1,488 / 131,821 | 35 / 0 |

Opening C–B adds just one visible draw but **205 shadow submissions** and 14 BG submissions. Shadow coverage and resident local scenery therefore matter even when foreground visible contribution is working. B's lower draws do not improve desktop wall time in this short sample. D has identical opening counts because the next BG is already disabled; its small timing change is not a causal saving. E saves approximately 0.37 ms versus C in this run, leaving substantial base foreground/architecture cost.

The native Endless far plane is 51.81314. Its separate production sample is 3.174 ms median / 3.845 p95, compared with 3.297 / 4.528 for the first matched-far stationary sample. It is restored for tours; no production camera behavior changes. The far-plane control avoids hiding a projection/cascade difference inside A–E.

At a fixed overlap camera, normal C renders current/next BG at 11/31 draws. D removes next BG; E removes both:

| Overlap case | Median / p95 / p99 / max, ms | FG visible draws / objects / primitives | Shadow draws | Current / next BG draws |
| --- | --- | --- | ---: | --- |
| C | 4.996 / 6.262 / 6.821 / 7.301 | 178 / 343 / 81,095 | 614 | 11 / 31 |
| D | 4.721 / 6.085 / 6.748 / 8.681 | 178 / 343 / 81,095 | 614 | 11 / 0 |
| E | 4.235 / 5.208 / 6.100 / 6.683 | 178 / 343 / 81,095 | 614 | 0 / 0 |
| B | 5.179 / 6.220 / 7.016 / 7.764 | 56 / 73 / 52,286 | 220 | 11 / 0 |

The backdrop cost grows at overlap, but it is not the sole remaining cost. The diagnostic does not remove streaming state, caches, scheduler, physics ownership or the compositing architecture.

## Quality, Retro and renderer matrix

Eight launcher jobs completed. Each stationary/tour sample lasts 2.5 seconds, with preparation and settling tracked separately. Production means the measured clean profile above. Shadow-light changes only atlas/cascades to 2048/1, keeping the non-Ultra project filter. Balanced additionally uses 2× MSAA and 85% native scale. There is no desktop evidence justifying a larger 4096 candidate before testing the lower-cost 2048 option.

| Job | First stationary median / p95 / p99 / max, ms | 100 px/s median / p95 | 400 px/s median / p95 | Post-transition median / p95 |
| --- | --- | --- | --- | --- |
| Prototype production | 2.211 / 2.809 / 3.405 / 4.361 | — | — | — |
| Endless production | 3.297 / 4.528 / 5.722 / 7.191 | 4.944 / 6.913 | 4.989 / 7.427 | 5.161 / 6.385 |
| Shadow-light | 2.783 / 3.912 / 7.226 / 57.589 | 3.936 / 4.761 | 4.120 / 6.203 | 4.691 / 6.418 |
| Balanced | 2.772 / 3.484 / 4.080 / 4.665 | 3.965 / 4.861 | 4.086 / 4.784 | 4.458 / 5.638 |
| Balanced, Retro OFF | 2.726 / 3.744 / 4.451 / 6.066 | 3.855 / 4.505 | 3.993 / 4.675 | 4.618 / 5.791 |
| Balanced, N64 only | 2.714 / 3.697 / 4.262 / 4.805 | 4.236 / 5.865 | 4.065 / 6.090 | 4.984 / 6.798 |
| Mobile/Vulkan production | 3.450 / 4.827 / 5.749 / 6.914 | 4.827 / 5.920 | 5.070 / 6.248 | 5.556 / 6.670 |
| Compatibility/ANGLE production | 8.884 / 10.448 / 12.336 / 14.455 | 10.327 / 12.822 | 10.362 / 11.970 | 11.152 / 12.900 |

Tour columns above contain only their `/settled` work group. Their complete distributions, including attachment/retirement/warm-up groups and maxima, are retained separately in `timings.csv`. Shadow-light had isolated 197–205 ms outliers during the native-far/100 px/s samples; the shorter median is not a promise of better tail latency. Balanced's post-transition median improves about 14% here, but the GPU and CPU balance is unlike an integrated UHD 620.

Retro pass isolation on normal Endless, same 673×473 internal pixel count:

| Pass | Whole-frame median / p95, ms | Compositor GPU median, ms |
| --- | --- | ---: |
| OFF | 3.041 / 3.849 | 0.017 |
| Pixel / Dither | 3.154 / 4.299 | 0.043 |
| N64-ish | 3.210 / 4.283 | 0.044 |
| CRT | 3.288 / 4.700 | 0.046 |
| VHS | 3.184 / 4.077 | 0.052 |
| Production combined | 3.171 / 4.409 | 0.094 |

VHS has the highest individual compositor GPU median, but the differences are tiny here. No pass is established as the unique low-end problem. The native-preset OFF foreground GPU time is 1.185 ms versus N64's 0.575 ms because OFF renders more pixels. N64 alone retains the familiar reduced-resolution/dither presentation and approximately halves combined compositor GPU time here; Pixel/Dither is similarly cheap but changes the intended aesthetic. **N64-only is a candidate, not a proven cheapest acceptable UHD profile.** The full quality matrix does not show a consistent whole-frame win over Balanced with the existing stack.

Verified launch flags:

```text
--rendering-method forward_plus --rendering-driver vulkan
--rendering-method mobile --rendering-driver vulkan
--rendering-method gl_compatibility --rendering-driver opengl3_angle
```

The bundled Compatibility console confirms OpenGL ES 3.0 through ANGLE, using Direct3D 11 on RTX 4060. Mobile renders the scene successfully but is not faster here. Compatibility renders successfully but produces a much brighter Rooftop image and different shadow/glow balance; it is not an appearance-equivalent migration. Godot documents lower color precision/HDR limitations in Compatibility and a different glow implementation with unavailable properties. This supports treating the image difference as renderer behavior, not tuning the production atmosphere to compensate. [Renderer feature comparison](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html), [Compatibility glow differences](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html).

An earlier cold-private-cache Compatibility attempt reached readiness after 163.7 seconds and hit the 240-second run budget before finishing. A cached repeat and the final complete matrix succeeded. The package gives Compatibility up to 420 seconds within a 20-minute overall budget; engine readiness and subsequent preparation settling each retain their separate 180-second guards. It keeps partial startup checkpoints and never labels warm-cache results as driver-cold. Thursday must retain failures and partial runs as evidence.

## Loading versus steady-state and UHD hypotheses

Final startup durations, Prototype then the seven Endless jobs: **4.58, 4.29, 3.93, 3.73, 3.83, 3.97, 4.42, 4.68 seconds**, with warm private caches. Process CPU totals include startup, all experiments and cleanup; they must not be divided by a stationary frame count or added to viewport GPU time.

The production real Zone crossing separates these frame distributions:

| Work during crossing | Frames | Median / p95 / p99 / max, ms |
| --- | ---: | --- |
| Settled outside overlap | 121 | 4.246 / 4.983 / 5.626 / 5.707 |
| Zone overlap | 694 | 5.152 / 6.105 / 7.065 / 9.960 |
| Live Act attachment | 93 | 7.064 / 10.423 / 15.233 / 15.233 |
| Resource retirement | 6 | 7.233 / 45.277 / 45.277 / 45.277 |

The whole-run native CPU stage maxima include foreground atmosphere attachment 79.449 ms, local scenery attachment 66.747 ms, background work 94.997 ms, visual attachment 79.484 ms and contribution capture 15.104 ms. Those maxima include startup/preparation and cannot be called steady-state spikes. Every final diagnostic reports zero fallback geometry builds. Loading disk recipes still requires instance/material attachment, device shader/pipeline preparation and retirement.

Ranked **provisional** UHD 620 causes and Thursday discriminators:

1. **Base foreground plus multi-cascade shadow work under the current high default.** Opening C submits 585 shadow draws for 164 visible draws; B removes 205 of those shadows. Compare production with shadow-light, then Balanced. If this dominates while E remains slow, extra backgrounds are not the main fix.
2. **Extra BG rendering/composition and resident scenery, especially overlap.** C–E and overlap C–D isolate current/next BG cost; counters distinguish actual rendering from mere residency. A uniform “all resident Acts render” failure is not observed on desktop.
3. **Device-specific preparation and attachment cost.** Compare startup/work-phase groups and the native stage events, not the stationary median. Successful baked loading does not eliminate graphics preparation. Cold ANGLE behavior demonstrates how large cache effects can be even on this desktop.
4. **Pixel bandwidth and Retro's resolution side effect.** Compare native presets with matched-pixel pass measurements. Turning Retro OFF raises 3D pixel count, which can offset savings from fewer post passes. This is a credible explanation for OFF not fixing the reported steady state, not proof about the unavailable laptop.
5. **Driver/renderer behavior and logging amplification.** Compare the actual Vulkan/Mobile/ANGLE paths and process CPU receipts. Per-slow-frame printing can amplify a slow machine; diagnostics sample rich counters at 4 Hz, keep frame distributions in memory and require `--grounding-verbose` for verbose sampling/old slow-frame logging. Ordinary launch logging is unchanged.

The original UHD 620 logs were not found in the available repository evidence. The catastrophic laptop slowdown and its exact multiplier therefore remain unverified here. This report does not fabricate a desktop reproduction or claim one selected cause is proven. Thursday returns enough controlled cases to distinguish the leading explanations without development on that machine.

## Instrumentation, package and verification

`tests/grounding_lab.gd` is an explicit script entry point. Normal launch does not load the control/proxy scripts. CLI modes include `--grounding-mode=0..5`, `--grounding-direction=0..6`, `--grounding-quality=...` and `--grounding-task=...`. Mode 0 restores the saved light transform exactly, rather than round-tripping Euler angles. F1–F10 route through the same code. Escape/window close runs normal teardown; theme switching saves the preceding theme's report before opening the next fixture.

Frame distributions retain median, p95, p99, maximum and counts over 50/100 ms for each explicit phase/work pair. Sampled JSON/CSV includes every viewport's visible/shadow/canvas draw/object/primitive counters, CPU/GPU times where supported, process/physics timing, active viewport count, resident/contributing Act identities, weights, build/warm/retirement state, caster inventory and applied quality. Scene inventories run explicitly, and caster ownership is cached when an Act appears; no per-frame tree traversal is introduced.

Viewport CPU/GPU timings are not additive wall time. Some counters are initially unavailable; Compatibility viewport timing is recorded as `null`, not zero-cost. GPU power states and short sample windows limit small-delta interpretation. [Godot RenderingServer counter/timing contract](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html).

The portable folder contains the engine, imported assets, validated disk recipes, diagnostic source, licenses, **Run Work Laptop Matrix.cmd**, **Visual Grounding Lab.cmd** and a seven-step README. Windows PowerShell 5.1 launch behavior was exercised, including exit-code capture. The matrix identifies hardware, runs eight cases, tours at 100/400 px/s, crosses a real Zone boundary, saves screenshots/JSON/CSV/logs and gathers one result folder. An existing Godot process causes a clear refused run rather than being stopped. A failed child preserves partial results; the runner only terminates its own timed-out/erroring child. No editor, Python, installation or laptop rebake is required.

The build-machine recipe is `tools/package_grounding_lab.ps1`, followed by the read-only `tests/grounding_bake_check.gd` and, only when needed, `tools/prepare_grounding_package.ps1`. `tools/finalize_grounding_package.ps1` validates the frozen source/freshness and creates the ZIP. `tools/run_grounding_matrix.ps1` is the portable runner; `tools/summarize_grounding.py` builds review sheets from real captures. Detailed reproduction and final verification receipts accompany the evidence directory.

Executed verification:

- Seven canonical untouched-reference versus Mode 0 comparisons are pixel-identical. All seven also restore exact gameplay state, material storage properties, light transforms/colors/energies and effective settings. After the full sweep, Green Hill restoration differs at 247 production-Retro pixels by at most two channel levels and 280 OFF pixels by one level; Aquarium OFF differs at one pixel by one level. Other final restored pairs are exact. These numerical differences remain disclosed; no image tolerance hides them.
- All four source/hull six-mode trials and all four paired seven-direction source trials complete without failures. All four final visual runs release watched project owners and return from one root node to one, with zero orphan nodes.
- The real crossfade/retirement test passes: no visible proxy at any positive blend, old Zone proxies retired, new ownership correct, restoration frees proxies, unchanged light count, warm-up/unused BG viewports disabled afterward.
- Actual F1–F10 input routing passes, including theme switching and capture. A signal-time free and a near-zero blend visibility edge case found during development were corrected before packaging. Escape/window close uses the same teardown handler.
- All eight final matrix jobs complete with zero diagnostic failures and zero fallback geometry builds. Every job's teardown reports zero retained watched project owners, zero orphan nodes and one remaining SceneTree root. The seven-theme freshness audit passes **98/98** source-path/theme combinations.
- A separate qualification runs the actual portable CMD with its default project/engine paths through Windows PowerShell 5.1: **8/8 complete in 541.7 seconds**. Source hashes match the final diagnostic scripts; every job restores settings without writing preferences and releases watched owners. Its new private cache gives ANGLE a 135.1-second engine startup, versus 4.68 seconds in the published warm-cache matrix. These qualification results are retained separately, not substituted into the comparison table. Final launcher checks corrected default-path initialization and inherited PowerShell module-path sensitivity; a zero-budget check also verifies all eight skipped cases remain in the status receipt.
- The supported baseline ran once against the measured frozen snapshot: **30 of 32 suites passed**. Enemy integration reports two editor wheel-sizing expectation failures. Prototype run integration looks for the old **“Start run”** button, while production now says **“Play”**; after its wait, the stale test dereferences a null game. Its failed child was stopped after that script error so the remaining suites could finish. The normal menu's Play button is enabled. These are not reported as a green baseline.
- A separate reproduction replaces both production hook files with their exact `a5722d5` Git blobs and runs without grounding flags. It reproduces the same two enemy assertions; a read-only menu probe records `labels=["Play"]` and `playable=true`. The diagnostic hooks are restored byte-for-byte afterward. No editor code or unrelated assertion was weakened to obtain a pass. The frozen baseline does not certify later editor commits.

The verbose lifecycle run still reports **one plain `RefCounted` with reference count zero** at engine exit. The first extracted-package smoke reports five ObjectDB instances; a verbose repeat reports one plain zero-reference `RefCounted`. The count is not stable. This matches the form of the previously documented native loader warning in [the lifecycle audit](LIFECYCLE_AUDIT.md). All watched project owners and nodes release; this is not a claim of a warning-free engine exit or proof of each native object's exact origin. Original logs retain the warnings.

Integration against the later shared editor source exposed three compile blockers unrelated to the visual experiment: the helper alias `EditorSelection` collided with Godot's native class, an unqualified helper `remap()` resolved to the global numeric function, and one dynamic equality expression needed an explicit boolean type. The focused integration fix renames the aliases/function and annotates that boolean, preserving editor behavior and other chats' work. Current shared gameplay/diagnostic and editor dependency checks now parse without errors, and a short isolated editor scene startup passes. This source-only fix is separate from the frozen benchmark package and does not retroactively certify the new editor's full behavior or bakes.

Portable delivery: `test-results/grounding-20261117/Sonic Spinball Grounding Thursday 2026-11-19 final.zip`, **207,485,508 bytes**, 4,098 entries. SHA-256: `84c18a4d1bc193374ad3084e2804457d1727228c3d6fb7721a39d9a8c22fe707`. ZIP CRC and required engine/launcher/import-cache files validate. The final launchers and scripts match the qualified extracted copy. Device/user/shader caches, test outputs and generated regression fixtures are excluded. The finalizer rejects changed frozen production source and checks the freshness receipt before creating the archive. The ZIP stays local; source, receipts and review sheets are committed to GitHub without publishing a release.

Thursday's only human judgments are the three README comparisons and gameplay readability in motion. Until those results return, production atmosphere/sun/ambient, Retro, renderer, MSAA, scale, shadow quality, Acts, collision, scoring and camera defaults remain unchanged. No scenery proxy is recommended for enablement.
