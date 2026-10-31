# Rendering and streaming performance — 2026-10-30

This pass starts at `77ecd3ff536fd5b8f868bc7994ef2eeb3debac71`. The working tree includes pre-existing local art changes; those are preserved separately from the optimization changes. Local measurements, logs and screenshots are under ignored `test-results/performance-20261030/`.

The first measured improvement combines rigid mesh pieces within individual Bumpers and flippers. In alternating RampMania runs, it reduces the typical frame time by **11.1%** and draw calls by **17.2%**, while preserving source triangles, materials and actor animation roots. The larger remaining steady cost is repeated rendering of many small shadow-casting objects. Streaming and severe first-use preparation stalls are measured separately below.

## Measurement method and limits

- Godot 4.7.2 Compatibility renderer, ANGLE / Direct3D 11, NVIDIA RTX 4060; driver `32.0.16.1664`.
- Window: 1280×900. Existing internal world sizes: 673×363 for standalone Play Act, 673×473 for Prototype and Endless. The existing retro presentation remains enabled.
- VSync and the frame cap are disabled for stationary measurements. Authoritative physics remains at **120 Hz**.
- Seed 18, served Ball, no player input. Each process waits for preparation to settle, then records three blocks of 600 frames. Each block has another 120-frame settling interval.
- Standalone workload: RampMania / Green Hill. Prototype: one Green Hill Zone, with Reverse C Spring, Secret Entry and RampMania in the seeded order. Endless: its seed-18 opening view in Sky Sanctuary.
- Stationary streams settle with three resident Acts in Prototype and six in Endless. These samples deliberately include the existing lookahead population; they are not measurements of one isolated mesh or a complete played run.
- GPU timer values are zero on this backend. Do not interpret those zeros as free GPU work. The reported per-viewport shadow-draw counter also remains zero even when disabling shadows removes thousands of total draws; total counters and controlled toggles are more useful here.
- Rendered object/primitive counters include render passes and views. They are different from scene node counts and unique source triangles. Inventory counts also include stored, hidden and offscreen geometry.
- Each table's median, p95 and p99 is the **median of the relevant block statistics**, not a percentile recomputed from pooled frames. Worst frame is the largest reported block maximum.
- Driver caches, operating-system scheduling and thermal state are not fully controlled. Repeated alternating runs support the retained change; short diagnostic ablations identify suspects rather than proving independent additive savings.

The cleanup figures in `PROJECT_BRAIN.md` used a different settling/frame-pacing procedure. They remain historical clues and must not be compared directly with this pass's uncapped steady-state numbers.

## Initial steady-state measurements

These are the first three baseline blocks in `act-before.json`, `prototype-before.json` and `endless-before.json`.

| Workload | Median ms | p95 ms | p99 ms | Worst ms | Draws | Rendered objects | Rendered primitives |
|---|---:|---:|---:|---:|---:|---:|---:|
| RampMania / Green Hill | 12.297 | 18.276 | 21.551 | 29.705 | 1,850 | 2,482 | 430,256 |
| Prototype opening view | 16.541 | 25.086 | 30.513 | 34.553 | 3,756 | 3,852 | 593,186 |
| Endless opening view | 12.514 | 18.605 | 21.746 | 90.230 | 2,855 | 3,121 | 398,093 |

Typical recorded physics time is approximately 0.29 ms, 0.52 ms and 0.69 ms respectively. These samples do not identify physics as the main cost. Render CPU time is approximately 10.19 ms, 13.26 ms and 9.64 ms; its measurement scope differs from whole-frame time, so the counters should not be added together.

### Draw-call ablations

Each ablation hides one visual category and disables its shadow casting, then restores it. Physics and gameplay state are unchanged. Draw reductions below are relative to the first baseline block; category and shadow effects overlap.

| Visual category disabled | RampMania draws removed | Prototype draws removed | Endless draws removed |
|---|---:|---:|---:|
| Rings | 302 | 253 | 127 |
| Mechanics, including Bumpers and flippers | 1,277 | 2,031 | 1,348 |
| Background/scenery | 134 | 24 | 34 |
| Other geometry | 9 | 1,437 | 1,325 |
| Post-processing passes | 3 | 4 | 3 |
| Directional shadows | 1,622 | 3,366 | 2,493 |

Mechanics are a substantial submission cost. Disabling shadows reduces RampMania from 1,850 to 228 draws, Prototype from 3,756 to 390, and Endless from 2,855 to 362. Their corresponding diagnostic medians are 6.483, 9.019 and 8.301 ms. Removing shadows visibly changes presentation, so this is evidence about cost, not a quality-preserving optimization.

The category classifier is more precise for freshly built standalone scenes than for baked streamed records. In the latter, terrain/border/decor meshes can fall into `other` after capture; a zero result for those named categories does not establish that they are free. In standalone RampMania, removing visible terrain saves 66 draws and removing borders saves four. No authored decor from that category contributes in the sampled view.

## Retained change: combine pieces within each hardware actor

`scripts/pinball_mesh_batch.gd` combines compatible rigid pieces after each round Bumper, triangle Bumper or flipper is built. It keeps the existing actor root, so animation, hit reactions, orientation, visual bindings and physics ownership remain unchanged. It does not combine separate actors into a large level-wide mesh.

Groups require the same material instance, vertex attributes and relevant render state, including shadow casting and layers. Rotated/scaled leaves, hidden leaves, child hierarchies, transparent materials, unknown shaders and other unsupported cases remain separate. Indices, winding, vertices, normals, tangents, colors and both UV channels are retained. The bake path applies the existing primitive-detail policy before conversion; standalone detail stays unchanged.

| Representative actor | Draw surfaces before | Draw surfaces after | Source triangle change |
|---|---:|---:|---:|
| Round Bumper | 15 | 6 | 0 |
| Triangle Bumper | 10 | 5 | 0 |
| Flipper | 21 | 6 | 0 |

The actual-actor probe found no missing or extra triangles in either standalone or bake geometry. PrimitiveMesh-to-ArrayMesh direction packing introduces differences below `0.0001`; positions, triangle membership, UVs and materials remain unchanged. The focused regression also checks source-resource immutability, actor transforms, unsupported-case preservation and repeated combining.

### Alternating RampMania comparison

Evidence: `act-unbatched-1.json`, `act-batched-1.json`, `act-unbatched-2.json`, `act-batched-2.json`. Both conditions use the same current source, scene, camera, art, shadows and resolution; the diagnostic switch changes only hardware combining. Each condition contains six 600-frame blocks across two processes.

| Metric | Unbatched | Batched | Change |
|---|---:|---:|---:|
| Typical frame time | 11.983 ms | 10.657 ms | −11.1% |
| Block p95 | 17.824 ms | 15.142 ms | −15.0% |
| Block p99 | 20.907 ms | 18.738 ms | −10.4% |
| Worst recorded frame | 26.021 ms | 22.716 ms | −12.7% |
| Render CPU time | 9.905 ms | 8.587 ms | −13.3% |
| Draw calls | 1,850 | 1,532 | −318 / −17.2% |
| Rendered objects | 2,482 | 2,164 | −318 / −12.8% |
| Scene nodes | 1,526 | 1,418 | −108 |
| Rendered primitives | 430,256 | 436,320 | +1.4% |

The slightly higher rendered primitive count is consistent with coarser culling of combined bounds. It does not represent additional source triangles. The lower submission cost outweighs that increase in this workload.

Matched local captures are `act-unbatched-1-baseline-1.png` / `act-batched-1-baseline-1.png`, and `gallery-before.png` / `gallery-after.png`. The eight-theme hardware gallery retains silhouettes, palette slots, markings and geometry. An RGB comparison of the 1493×1050 gallery found only four changed pixels, each with a maximum channel difference of 1/255 (`gallery-difference.json`). Animated scenery and frame-dependent effects can differ between gameplay captures; screenshots support visual fidelity rather than proving gameplay equivalence.

### Prototype and Endless after rebaking

Evidence: `prototype-before.json` / `prototype-after.json` and `endless-before.json` / `endless-after.json`, using the first three baseline blocks in each file. Both modes were rebaked before measuring the changed hardware. Resident counts remain three for Prototype and six for Endless.

| Workload and version | Median ms | p95 ms | p99 ms | Worst ms | Draws | Rendered objects | Rendered primitives | Scene nodes |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Prototype before | 16.541 | 25.086 | 30.513 | 34.553 | 3,756 | 3,852 | 593,186 | 4,433 |
| Prototype after | 15.430 | 21.138 | 25.459 | 32.344 | 3,070 | 3,166 | 594,530 | 4,125 |
| Endless before | 12.514 | 18.605 | 21.746 | 90.230 | 2,855 | 3,121 | 398,093 | 7,567 |
| Endless after | 11.664 | 18.788 | 20.870 | 32.054 | 1,991 | 2,257 | 398,477 | 6,907 |

Prototype removes 686 draws (18.3%) and 308 scene nodes. Endless removes 864 draws (30.3%) and 660 scene nodes. Recorded typical frame times fall by 6.7% and 6.8%, respectively. These are sequential before/after measurements, not alternating runs like the standalone comparison, so the timing attribution is less certain. In particular, Endless p95 is essentially unchanged; the lower maximum does not prove first-use stalls are solved.

Visual inspection of `prototype-before-baseline-1.png` / `prototype-after-baseline-1.png` and the corresponding Endless captures found matching framing, silhouettes and materials. Differences are limited to Ring/enemy animation and CRT phase. The original before reports did not serialize camera transforms; the after reports do. Matching screenshots and resident counts support the comparison, but do not replace that missing numerical camera record.

## Investigated alternatives

### Rings

RampMania stores 82 Ring meshes / 20,992 source triangles. Removing their rendering saves 302 draws in the sampled view, with a diagnostic median of 10.930 ms versus the initial 12.297 ms typical baseline. Rings are therefore a real contributor, but mechanics provide a larger total submission opportunity.

Resting-Ring MultiMesh batching would also need to preserve per-Ring collection, attraction, reset and streamed bindings. This pass takes the simpler hardware improvement first. Rings retain their existing behavior and presentation.

### Border tessellation and static batching

RampMania's standalone inventory contains nine border mesh nodes / 25,240 source triangles, but hiding visible borders removes only four draws and 17,324 rendered primitives. Its diagnostic median, 11.868 ms, is within the variation of the initial baseline blocks. The earlier 4,782-triangle border is a valid geometry observation, not sufficient evidence that border tessellation dominates frame time.

The earlier RampMania recipe's 492 source mesh records and zero static batches do not indicate a broken batcher. `static_batches.gd` deliberately protects flippers, retracted flippers, Rings, Bumpers and animation roots, including their descendants. Eligible static meshes must have a single surface and share the same mesh resource identity; at least three compatible instances must occur in a two-metre cell. Unique terrain and independently generated pieces often fail those criteria.

Hardware roots still need individual animation. Combining rigid children inside those roots addresses an opportunity that the level-wide static batcher correctly excluded. The border builder also handles concave contours and holes; its simpler baked fast path requires validated compatible contours. This change retains both border detail and authored collision geometry.

### Shadow resolution

The default 8192 atlas was compared with 4096 and 2048 using matched captures. All three retain the same draw counts. The exploratory medians do not show a consistent resolution benefit across workloads:

| Workload | Initial 8192 typical ms | 4096 trial ms | 2048 trial ms |
|---|---:|---:|---:|
| RampMania | 12.297 | 14.472 | 11.975 |
| Prototype | 16.541 | 16.024 | 15.772 |
| Endless | 12.514 | 12.309 | 15.414 |

These single trial phases are insufficient evidence for lowering the default. The much larger no-shadow difference points toward caster/pass submission cost as well as potential raster work. Matched `*-shadow-4096.png`, `*-shadow-2048.png` and `*-without-shadows.png` captures remain local for quality review. No default shadow quality reduction is part of the hardware change.

### Shaders, transparency and post-processing

Disabling post-processing removes only three or four draws; timing varies by workload and does not explain the thousands of submissions. Scenery is not uniformly expensive: its contribution depends on the active theme and view. These measurements do not isolate water, glass, clouds or lava sufficiently to declare any specific shader cheap or expensive. Dedicated theme/material comparisons remain useful follow-up work.

Source inspection narrows the next experiments:

- Aquarium water is opaque procedural shading; `aquarium_water.gdshader` does not write `ALPHA` or sample the screen. The separate `aquarium_glass.gdshader` does write alpha. Background water and glass instances have shadow casting disabled. Transparent glass overlap is a possible overdraw target, not evidence that the entire lagoon pays that cost.
- Sky Sanctuary's cloud deck uses three value-noise layers, and its cloud-bank spheres use analytic normal-based shading. Both cloud shaders are unshaded and opaque; neither ray marches a volume or samples the screen. Cloud instances are shadowless and the banks are batched.
- Lava's molten surface uses procedural noise and emission without alpha. Screen-sampling transparent heat distortion is a separate shader, enabled only by the existing `--lava-heat-haze` option. It is not part of the default path. Lava's local fill lights are also shadowless.
- The default N64/VHS/CRT stack creates three full-world passes and three explicit back-buffer copies before upscaling; HUD rendering stays separate. The source shaders contain 2, 16 and 8 texture calls respectively, although the compiler may merge reads. The ablation hides only those passes and retains the world resolution, avoiding the resolution change caused by switching the whole preset off.

These are implementation facts from the theme generators and shaders, not shader timing results. Pixel coverage, overlap and first-use shader preparation still require measured comparisons before changing them.

### Render scale

A 75% world-resolution trial leaves RampMania draw counts unchanged and gives no compelling isolated win. The initial streamed scale trials are **not valid matched comparisons**: resizing changed the camera/culling workload, and the later baseline-return phase retained increased draw counts (Prototype 3,756 to 4,258; Endless 2,855 to 4,280).

The corrected Prototype trial in `prototype-after.json` freezes camera pose and far plane. At 505×355 it records 15.150 ms / 3,069 draws; the following 673×473 baseline records 15.161 ms / 3,070 draws. That is no meaningful demonstrated improvement. The old streamed scale timings remain invalid, and neither trial justifies changing the default or adding a Performance preset in this pass.

## Loading and transitions

The continuous Endless tour uses seed 18, speed 400 and target sequence 6. It measures movement through multiple Acts/themes, including preparation and boundary waits, separately from the stationary probe.

| Pre-change tour | Median ms | p95 ms | p99 ms | Worst ms | Boundary wait ms | Runtime rebuilds |
|---|---:|---:|---:|---:|---:|---:|
| First recorded run | 16.976 | 274.199 | 429.351 | 6,233.200 | 3,868.761 | 0 |
| Repeat 2 | 17.385 | 77.827 | 175.768 | 314.194 | 3,223.244 | 0 |
| Repeat 3 | 16.799 | 71.983 | 143.505 | 226.754 | 3,249.615 | 0 |

The first run's extreme tail is retained as evidence of first-use/environment variability; it is not silently averaged into a steady-state improvement claim. Warm repeats still show substantial stalls. Zero runtime geometry rebuilds does not mean zero resource, instantiation, upload, shader-preparation or warm-up work.

### One-Act resource prefetch experiment

**Rejected and reverted.** The experiment overlapped one upcoming Act's threaded disk request with the current graphics preparation worker. It kept validation and cache reservations intact, but three alternating pairs did not establish a useful rendering or boundary-wait benefit.

Evidence: `prefetch-off-1.json` through `prefetch-on-3.json`. Each pair uses the same baked hardware, tour and renderer. Active-frame p99 excludes frames spent waiting at an Act boundary; it does not exclude ongoing background preparation.

| Pair | Wait off ms | Wait on ms | Median off ms | Median on ms | Active p99 off ms | Active p99 on ms |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 0.000 | 42.147 | 16.656 | 16.888 | 94.959 | 117.703 |
| 2 | 218.218 | 55.194 | 16.634 | 16.992 | 96.337 | 101.340 |
| 3 | 288.226 | 635.951 | 16.995 | 17.866 | 111.857 | 95.272 |

Prefetch reduced the measured time awaiting already-requested resources from approximately 516 ms to 0.15 ms. It moved that loading earlier rather than eliminating the work. Boundary waits varied, typical frame times did not improve, and active-frame tails did not consistently improve. The added scheduling and reservation state therefore did not earn its complexity. Final code has no Act-prefetch option or diagnostic switch.

The `off` runs measure the retained hardware-batching candidate with normal streaming. Their median boundary wait is 218.218 ms, versus 3,249.615 ms across the original three pre-change tours; all six runs reached sequence 6 without runtime geometry rebuilds. This is a limited sequential before/after observation: source/node counts changed, caches are uncontrolled, and the earlier first-use outlier remains relevant. It does not prove a 93% universal loading improvement or the elimination of transition stalls.

After reverting prefetch and rebuilding all 96 variants, `final-tour.json` again completed sequence 6 with zero rebuilds. It recorded median 16.159 ms, p95 63.931 ms, p99 183.130 ms, worst 332.369 ms and **1,395.991 ms boundary wait**. Active-frame p99 was also 183.130 ms. This final confirmation is materially worse than the earlier candidate's boundary-wait median, demonstrating why the warm-tour result must not be generalized. The retained optimization is supported most strongly by its reduced submissions and alternating stationary measurement.

The tour's existing success criterion requires zero boundary waits. Among the alternating pairs, only `prefetch-off-1` meets it; completed tours with nonzero waits, including the final confirmation, still return a failing profiler status. The zero-wait performance target remains unmet.

### Cold theme preparation remains a major bottleneck

The first full-session integration run exposed Chemical Plant's 30-node material-probe warm-up taking **41,822 ms**, within 42,743 ms total theme preparation. Individual frames reached roughly 5–7 seconds. The later 27-transition integration tour also recorded a 5,787 ms maximum frame while first-use themes warmed. These are separate cold-preparation observations, not the settled view or six-transition benchmark. The logs identify graphics warm-up as the slow stage; the precise shader/driver contribution is an inference because this backend supplies no usable GPU timings. No evidence isolates these stalls as a new regression from batching.

This is the highest-priority loading investigation left by the pass: probe/material variant count, first-use compilation, upload work and warm-up granularity. A faster settled view does not make these stalls acceptable or solved.

## Verification status

Headless checks passed for physics profiles, Scorecraft, SRA Buddy scoring, enemies (45 checks), geometry bake equivalence (2,842), presentation (18), all eight themes (675), warm manifests, warmed-node reuse, retirement, mesh batching (14), and authored Green Hill playback (80). After reverting prefetch, the retained cache suite passed **28/28 checks** in both the live tree and a clean checkout containing only HEAD plus this pass's changes. The clean checkout also imported successfully, passed batching and authored-playback checks, and parsed `render_cost_profile.gd` with `--check-only`. These changes do not require the unrelated local art edits.

The authored playback test contained obsolete implementation assumptions: it expected the first Bumper child to be a `CylinderMesh`, and expected an old `raised_turf` shader parameter. The test now checks the complete rendered Bumper footprint/radius/center and the current terrain texture/material contract. These checks retain the intended geometry and presentation guarantees without requiring a particular mesh class or retired shader flag.

Final-code bakes completed for all 40 production and 56 Endless variants. The rendered full Prototype session passed **143 checks**, including Buddy drafts, results, replay, restart and interrupted-startup cleanup. Rendered 1- and 7-Zone runs passed **74 checks**. The rendered 27-transition Endless smoke test passed **260 checks**, visited all published Acts, verified valid bakes and cache/theme/retirement bounds, and reached at most six resident Acts. The final continuous tour completed with zero rebuilds but failed the zero-wait target described above.

The initial full-session test used a ten-second wall deadline for a 1.25-second process-driven transfer, then continued after timeout and crashed on an absent score award. [Godot clamps process delta during long frames](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-private-method-process), so first-use graphics stalls can exhaust wall time before the animation receives enough simulation time. The test now allows 2.25 seconds of unpaused process time, retains a 180-second loading watchdog, preserves exact spawn/control-release assertions, and exits cleanly with diagnostics on failure. No transfer runtime or scoring behavior was changed. The corrected full-session rerun passed all 143 checks.

All pre-existing tracked files outside this pass's owned edits were checked against their starting SHA256 values. Existing art changes remain unstaged and separate. Manual playtesting still owns flipper feel, camera readability and polish; these automated checks do not replace that judgment.

## Reproduction and remaining work

Use the existing bake launchers after source changes affecting recipe fingerprints. Set `$godot` to the local Godot 4.7.2 executable and run graphical probes sequentially:

```powershell
& $godot --path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --script res://tests/render_cost_profile.gd -- --profile-mode=act --profile-output=res://test-results/act-batched.json
& $godot --path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --script res://tests/render_cost_profile.gd -- --profile-mode=act --profile-unbatched --profile-output=res://test-results/act-unbatched.json
& $godot --path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --script res://tests/render_cost_profile.gd -- --seed=18 --profile-mode=prototype --profile-ablations --profile-output=res://test-results/prototype-cost.json
& $godot --path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --script res://tests/endless_stream_profile.gd -- --seed=18 --profile-stages --profile-speed=400 --profile-target=6 --profile-unlimited --profile-output=res://test-results/endless-tour.json
```

Next investigations should prioritize shadow-caster submissions, remaining mechanic pieces, streamed background overlap and first-use preparation stalls. Consider Ring batching only with equivalent lifecycle tests and measured benefit. Preserve 120 Hz physics, existing scoring/Buddies, all Acts/themes and current default visual quality while comparing changes.

## Performance Pass 2 — cold preparation and shadow submissions

Starting source: `75e1df0071a219727b03c5ce6ee56b57535fb5af`, with the existing local ArtBro changes preserved. Measurements below include those local visuals. They are comparisons within this pass, not interchangeable with Pass 1's different window/camera samples. Raw JSON, logs and captures are under ignored `test-results/performance-pass2/`.

The retained changes are deliberately narrow:

- Bumpers and flippers retain their visible colored surfaces and gain one combined shadow-only mesh per compatible render-state group. Original triangles, winding and normals are preserved, including the normals used by shadow normal bias. Only the known opaque, non-displacing pinball shader is eligible. Animated roots and authoritative 2D bodies are unchanged.
- Generated bake shaders share an external, content-addressed resource across Act and theme files. This preserves source and uniforms while avoiding independently instantiated renderer programs for identical generated source. Existing external shaders already shared paths and are untouched.
- Opt-in profiling records each warm draw batch, feature signatures, material/shader paths and source hashes, process-frame waits and post-draw waits. The theme startup probe counts actual resources and follows the normal Prototype startup/lookahead path. Shadow-only category ablations and resident counts remain available for later investigation.

### Cold Chemical Plant: what the 42-second bucket contained

Method: fresh Godot process, fresh isolated APPDATA shader cache for each cold trial, seed 18, one Chemical Plant Prototype Zone containing the same three Acts, ANGLE/D3D11 on RTX 4060, Godot 4.7.2. GPU runs were sequential. Driver/OS caches were not reset, so these are application-cache-cold observations, not controlled driver compiler benchmarks. The cache-cold startup includes an approximately 24-second initial frame before theme preparation; Pass 1's 42-second observation was later in a full session and excluded that work.

The baseline has **347 material resources, 37 textures, 18 Shader resources but only six distinct custom shader sources**. Its 30 material probes have 28 warm feature signatures. Many material colors do not create new programs. Four generated sources are nevertheless embedded separately in multiple bake files. Sharing reduces the 18 Shader instances to six without removing shader source or material coverage.

Matched shader-sharing experiment (original shadow casters in both; `chemical-full5.json` and `chemical-shared-full5.json`):

| Stage | Embedded shaders ms | Shared shaders ms |
|---|---:|---:|
| Theme resource wait | 73.534 | 54.900 |
| Probe scene instantiation | 38.307 | 21.570 |
| Probe graphics warm-up | 59,227.019 | 57,483.129 |
| Background graphics warm-up | 1,163.770 | 1,008.327 |
| Total theme preparation, including load/retirement | 60,571.022 | 58,611.800 |
| First Act graphics warm-up | 580.174 | 100.849 |
| Second Act graphics warm-up | 608.600 | 204.171 |
| Third Act graphics warm-up | 613.131 | 238.478 |
| Ready for play, from game creation | 89,506.622 | 85,278.786 |
| Settled after lookahead plus 180 frames | 94,408.124 | 89,324.479 |
| Worst startup frame | 24,131.092 | 23,852.523 |

The useful retained result is resource sharing and cheaper repeated Act preparation. The modest first-use difference is insufficient to claim that the minute-long theme stall is solved. Three resident Acts and zero runtime rebuilds were retained.

Final-code confirmation after the workstation interruption was slower when application-cache-cold: **113,626 ms ready**, 118,218 ms settled, **75,268 ms total theme preparation**, 73,646 ms probe graphics, and a **32,542 ms worst startup frame**. The immediate repeat using that same cache recorded **7,407 ms ready**, 11,675 ms settled, 2,626 ms theme preparation, 2,197 ms probe graphics and a 965 ms worst frame. Both retain 30 probes, six Shader resources, three resident Acts and zero rebuilds (`chemical-final-cold.json`, `chemical-final-warm.json`). This confirms strong cache sensitivity and the unresolved first-use stall. It is not a matched replacement for the earlier shader-sharing pair or evidence of a 15-fold code optimization.

The expensive probe batches take about 6.3–13.2 seconds each. They draw only a handful of boxes, including ordinary and instanced paths; several stalls have over 99% of their elapsed time between the process-frame signal and the post-draw signal. Instantiation takes tens of milliseconds, not tens of seconds. A batch using standard materials also stalls for 12.8 seconds: Chemical Plant's custom fragment code alone cannot explain the problem. The initial pinball-material batch also stalls before the process-frame signal, so the two wait columns are scheduling observations rather than a clean CPU/GPU partition.

**Measured:** first-use render work dominates the probe bucket; resource/scene creation is much smaller; new generated Shader identities cause repeat preparation; cache/backend choice has a large effect. **Inference:** shader compilation/translation and driver synchronization are the main cause. This backend reports zero in the GPU-time counter and does not expose compiler timings, texture-upload timings or mesh-upload timings separately. Zero means unavailable here. Likewise, the per-viewport shadow-draw counter returns zero despite clearly measured shadow ablation savings; use total submissions and matched ablations, not that counter.

[Godot's pipeline compilation guidance](https://docs.godotengine.org/en/4.6/tutorials/performance/pipeline_compilations.html) distinguishes renderer capabilities. The [GLES3 shader implementation](https://github.com/godotengine/godot/blob/master/drivers/gles3/shader_gles3.cpp) creates shader versions and default variants at first use. A legacy Compatibility visible warm-up cannot interrupt a single synchronous driver operation merely by reducing its node budget. The existing live warm-up already admits only one cold feature-bearing node at a time; changing that budget would not eliminate a multi-second individual operation.

### Cold experiments rejected

- **Skip all probes:** the theme bucket falls to 6.6 seconds, but first and second Act graphics warm-up become **33.38 seconds and 10.46 seconds**. Ready time remains 79.43 seconds. That moves stalls into actual Act preparation rather than removing them. Keep the normal coverage.
- **Skip instanced probes:** 89.51 to 86.03 seconds ready with embedded shaders; first Act warm-up increases from 580 to 1,243 ms. With shared shaders it records 80.05 seconds instead of 85.28. This limited cold saving does not justify knowingly transferring first-use work into instanced scenery/Acts. The diagnostic switch remains opt-in only.
- **Probe only observed render paths:** an offline union of actual ordinary/instanced/shadow paths reduced 30 probes to 23. Ready time was 84.52 seconds versus 85.28 with shared shaders and the original probe plan. Complexity did not earn its place; implementation and tests were reverted.
- **Native OpenGL diagnostic:** the same 23-probe experiment recorded 29.04 seconds ready, 17.30 seconds theme preparation and a 6.44-second worst frame. This is strong backend sensitivity, not proof of a particular compiler function. Native OpenGL already has a documented NVIDIA `nvoglv64.dll` access violation in Zone replay (see VERIFICATION.md); ANGLE remains the default. A fast startup does not establish backend stability.
- Early runs with overlapping GPU processes, a hidden rendering window or a missing console-wrapper target were discarded. They are not included in the reported comparisons. Windows's GUI executable can return control before the game ends; the correctly paired console wrapper was used for the valid sequential runs.

### Shadow audit and retained batching

RampMania's baseline uses **1,532 draws**. Disabling only each category's shadow casting gives these diagnostic totals; the visible objects remain present:

| Category | Stored casters | Draws with its shadows disabled | Saved draws |
|---|---:|---:|---:|
| Rings | 82 | 1,251 | 281 |
| Flippers | 45 | 1,430 | 102 |
| Bumpers | 30 | 1,439 | 93 |
| Rails/supports | 46 | 1,369 | 163 |
| Springs | 27 | 1,433 | 99 |
| Switches | 45 | 1,396 | 136 |
| Enemies | 31 | 1,412 | 120 |
| Other mechanics | 53 | 1,387 | 145 |
| Terrain | 9 | 1,476 | 56 |
| Scenery/decor | 76 | 1,401 | 131 |

Inventory counts include stored, hidden and offscreen meshes. The initial standalone audit's Ball category captured the hidden generic sphere rather than the separate character adapter; its zero saving did not establish character cost. The harness now includes both presentation paths for the streamed audit. Background scenery in a separate streamed viewport has no shadow-enabled key light; standalone scenery is a different case. Do not add these ablations together or treat their exploratory timings as a controlled benchmark.

Four cascades multiply small opaque surfaces. A Bumper's several palette materials need separate visible surfaces, but its depth silhouette does not need separate material submissions. Combining those caster triangles across colors reduces RampMania's eligible mechanic casters by 49 while retaining every shadow triangle. This adds 11 shadow-only nodes and duplicated mesh storage; it trades modest memory for fewer submissions. The combined bounds can admit some triangles that previously culled independently, so primitive counts need not decrease.

All-eight-theme hardware gallery captures with a receiving floor are **byte-identical before and after** (`shadow-gallery-before.png`, `shadow-gallery-after.png`). Deterministic checks also compare visible and shadow triangles, winding and normals before/after, verify idempotence, and repeat the comparison after recipe capture/reload.

Two alternating standalone pairs each contain three settled 600-frame blocks, 120 settling frames per block, VSync disabled and 120 Hz physics. Window is 1280×900, world viewport 673×363, same camera/seed/theme. Six-block medians and tail summaries are reported below; no claim of guaranteed whole-run FPS follows from a stationary view.

| RampMania | Original casters | Combined casters |
|---|---:|---:|
| Median of block median frame ms | 12.049 | 11.265 |
| Median of block p95 frame ms | 16.855 | 15.906 |
| Median of block p99 frame ms | 20.359 | 19.025 |
| Median draw calls | 1,532 | 1,373 |
| Median rendered objects | 2,168 | 2,007 |
| Median render CPU ms | 9.794 | 8.985 |
| Median physics ms | 0.306 | 0.295 |

This is a 10.4% submission reduction, 6.5% lower typical frame time and 8.3% lower render CPU in these alternating samples. Tail values are medians of block percentiles, not percentiles of a concatenated frame trace. The few fluctuating UI objects account for small object-count differences between repeats.

Fixed shadow-distance and cascade experiments remain diagnostic. Distance 40 to 12 lowers the sampled RampMania view from 1,532 to 931 draws and looks similar at that camera. However, a fixed short distance has not established coverage for overview cameras, tall scenery and all authored shapes; do not ship that constant. Two cascades lower draws to 797 but visibly blur the ramp shadow, so that change is rejected. Ring-shadow removal visibly weakens the ground anchor; keep those casters. No atlas, physics or gameplay tuning changed.

### Resident overlap

Ready adjacent Acts are visible and shadow-capable while resident. Residency is needed for traversal safety, but rendering is a separate potential optimization. The current background implementation already disables a zero-weight, non-warming viewport and pauses its scenery processing; it does not keep all resident theme backgrounds rendering forever. During the intended crossfade, two backgrounds render. Theme backdrop key lights do not enable shadows.

An active-Act-only diagnostic measures the cost of adjacent foreground Acts. It is not a safe lifecycle rule: neighboring geometry can be visible near a join, and offscreen objects can cast into the visible region. Keep streaming safety and current visibility behavior until camera- and light-aware bounds can conservatively establish when an Act contributes neither pixels nor shadows.

| Settled view, original casters | All resident Acts drawn | Only active Act drawn | Resident Acts in both |
|---|---:|---:|---:|
| Prototype | 3,070 | 1,681 | 3 |
| Endless | 1,991 | 1,316 | 6 |

That is 45.2% and 33.9% fewer submissions in these opening views without unloading anything. The screenshots show no obvious lost foreground geometry there, but this does not establish correctness at joins or under moving light/camera coverage. No visibility gating ships in this pass. Disabling only background-scene casters saves **zero draws** in both modes, confirming the source inspection. Disabling character/Ball casters saves four and two draws respectively in these served-ball views; character shadows are not the large submission problem here. The streamed category inventory is coarser than the standalone inventory because it relies on surviving node ancestry and runtime bindings; its `other` bucket must not be attributed to one specific mechanic or terrain feature.

### Streamed steady views and boundary waits

The first sequential streamed pair crossed the workstation interruption. Prototype block medians were 20.431 → 22.504 ms, while Endless was 13.336 → 11.806 ms. Those mixed timings did not justify a speed claim. A fresh control comparison therefore rebuilt only the relevant variants with **shader sharing enabled in both cases**, changing only original versus combined shadow casters. The retained recipes were backed up, then restored byte-for-byte after the control; all 29 restored file hashes matched. No source changed between these runs.

Fresh control/confirmation results (`*-control.json`, `*-confirm.json`), medians across three 600-frame blocks at 1280×900 / 673×473 world resolution:

| View / casters | Frame median ms | Block p95 ms | Block p99 ms | Render CPU ms | Draws | Rendered objects | Resident Acts |
|---|---:|---:|---:|---:|---:|---:|---:|
| Prototype / original | 23.285 | 32.915 | 36.518 | 18.389 | 3,069 | 3,165 | 3 |
| Prototype / combined | 20.059 | 28.718 | 31.986 | 15.851 | 2,777 | 2,873 | 3 |
| Endless / original | 15.737 | 22.555 | 25.189 | 12.295 | 1,991 | 2,257 | 6 |
| Endless / combined | 16.252 | 22.956 | 25.977 | 12.313 | 1,668 | 1,934 | 6 |

Prototype's fresh pair shows approximately 13.9% lower median frame time and 13.8% lower render CPU. Endless consistently saves **323 draws (16.2%)**, but its fresh pair does **not** establish a timing gain: median frame time is 3.3% higher and measured render CPU is essentially unchanged. One-draw variations between Prototype blocks are UI/capture-time variation. Keep the distinction between fewer submissions and demonstrated faster frames. The uninterrupted alternating standalone pairs and the fresh Prototype comparison support retaining the conservative batching; do not promise an Endless FPS increase.

All continuous tours below use seed 18, speed 400, target sequence 6, normal lookahead, VSync disabled and 120 Hz physics. Every run reaches sequence 6 with **zero runtime rebuilds and three resident Acts at peak**. The original and retained initial pairs straddle the interruption; the later control pair isolates shadow casters with shader sharing on both sides.

| Continuous tour | Median ms | p95 ms | p99 ms | Worst ms | Boundary wait ms |
|---|---:|---:|---:|---:|---:|
| Initial original 1 | 16.815 | 35.448 | 97.760 | 108.350 | 1,478.869 |
| Initial original 2 | 17.394 | 45.306 | 95.546 | 107.308 | 1,152.978 |
| Initial retained 1 | 15.863 | 42.363 | 108.119 | 164.986 | 2,334.556 |
| Initial retained 2 | 18.173 | 43.931 | 107.625 | 151.779 | 3,038.562 |
| Fresh original-caster control 1 | 18.263 | 40.262 | 105.065 | 135.354 | 3,082.079 |
| Fresh original-caster control 2 | 17.518 | 38.708 | 94.107 | 103.484 | 1,100.320 |
| Fresh combined-caster confirmation 1 | 18.141 | 38.264 | 113.339 | 163.791 | 3,221.060 |
| Fresh combined-caster confirmation 2 | 17.074 | 38.964 | 111.558 | 134.978 | 2,323.126 |

**No streaming latency improvement is demonstrated.** Both retained pairs have worse boundary waits/tails than their corresponding original samples, and the original control itself varies from 1.10 to 3.08 seconds. This remains a material limitation, not a result to average away. All eight tours fail the profiler's existing zero-boundary-wait success criterion despite completing without rebuilds. There is no new prefetch, smaller resident buffer or relaxed readiness check hiding the waits. Extra shadow meshes add storage and warm-up work; the measured steady-view benefit must not be presented as a transition-loading win.

Next optimization targets are a minimal first-use ANGLE/compiler/cache reproducer and conservative foreground Act/caster visibility bounds. The latter must account for offscreen casters projecting into the camera and for overview/transition cameras. Remaining rigid rails/supports, springs and switches are candidates only with equivalent geometry/animation tests. Static lighting remains exploratory; this pass does not justify a LightmapGI rewrite.

### Reproducing Pass 2

Use one correctly paired Godot console wrapper/executable and wait for each process to exit. Do not run GPU probes or CPU-heavy bakes beside timed probes. The examples assume `$godot` points to that console executable. Fresh APPDATA/LOCALAPPDATA directories isolate application caches and test telemetry from normal player data; do not delete the player's existing cache or telemetry.

```powershell
# Original-caster/embedded-shader diagnostic recipes; both pools must match.
& $godot --headless --path . --script res://tests/performance_bake.gd -- --prototype --profile-original-shadows --profile-embedded-shaders
& $godot --headless --path . --script res://tests/performance_bake.gd -- --pool --profile-original-shadows --profile-embedded-shaders

# Restore the supported recipes after comparison.
& $godot --headless --path . --script res://tests/performance_bake.gd -- --prototype
& $godot --headless --path . --script res://tests/performance_bake.gd -- --pool

# Cold startup in a fresh isolated application-cache directory; repeat unchanged for a cache-warm run.
& $godot --path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --script res://tests/theme_prepare_profile.gd -- --seed=18 --profile-stages --profile-theme=chemical_plant --profile-output=res://test-results/chemical-prepare.json

# Same steady probe as Pass 1, with optional shadow-only diagnostics.
& $godot --path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --script res://tests/render_cost_profile.gd -- --seed=18 --profile-mode=prototype --profile-shadow-audit --profile-output=res://test-results/prototype-shadows.json
```

For standalone comparisons, `--profile-original-shadows` on `render_cost_profile.gd` disables only the new shadow combining; Pass 1's colored-surface batching stays enabled. Baked Prototype/Endless variants require the diagnostic rebake above. Shadow audits keep the three normal 600-frame steady blocks, use 120-frame ablation blocks for stable draw counts, then restore a full baseline block. The normal live scheduler, lookahead and safety rules remain active throughout the tour.

### Pass 2 verification

Headless checks passed for rigid mesh batching (14), shadow geometry and recipe equivalence (16), shared flat-shader resources (17 with local art; 16 without the optional art), warm manifests (30), bake cache behavior (28), warmed-node reuse (127), retirement (72), physics profiles, Scorecraft (29), SRA Buddy scoring (70), collision bake equivalence (2,842), all eight theme runtimes (675), and authored Green Hill playback (80). The empty-mesh guard leaves unsupported input untouched instead of creating an invalid shadow surface.

A separate clean source tree containing HEAD plus only this pass's changes imported successfully and passed batching, shadow geometry, flat-shader, manifest, cache and authored-playback checks. All profiling scripts parsed there. These changes do not depend on uncommitted ArtBro files. The restricted-profile certificate-store warning is environmental; the first clean import also lacked an editor cache path, resolved by isolating LOCALAPPDATA as well as APPDATA.

Final-code bakes completed for all **40 Prototype and 56 Endless variants**. The workstation interruption occurred during an offline bake, before the final timed GPU runs; bake duration is not used as performance evidence. Steady before/after streamed timings are sequential observations across that interruption, so the deterministic draw savings and uninterrupted alternating standalone pairs provide stronger evidence than a claimed universal timing percentage.

Rendered full Prototype session checks passed **143/143**; rendered 1- and 7-Zone runs passed **74/74**. The `--require-bakes` Endless smoke passed **256/256** checks across 27 transitions, all published Acts and all eight themes, with zero runtime rebuilds. Its jump-driven sampling reached two resident Acts; the continuous tour and settled view use different sampling and are reported separately. Endless diagnostics still report ObjectDB shutdown warnings (10–11 instances in the final tour/smoke); shutdown ownership is not established as fixed by this pass. Their existing teardown waits for the active load before freeing the scene, while the player/session and startup profiler use the fuller `prepare_to_close` path.

Matched standalone, Prototype and Endless screenshots show no meaningful lost shadows or changed geometry. Animated Rings/enemies and FPS labels differ with capture time. The hardware gallery's exact byte equality is the stronger fixed-pose image comparison. Human playtesting still owns flipper feel, camera readability and polish.

## Renderer bakeoff — 2026-10-31

Starting pushed HEAD: `741ef00edba6df595fc4609aef2bfd1dbf450785`. This investigation uses the live working tree, including Alex's separately owned local art, on Godot 4.7.2 stable `ed1daf0bf`, RTX 4060 and NVIDIA 616.64. The default renderer, production shaders, gameplay, physics and bake source remain unchanged. Renderer selection is a process-local command-line override: Compatibility/ANGLE (D3D11), Forward+/Vulkan or Mobile/Vulkan. Runtime metadata and engine logs verify the actual backend; the saved project setting alone cannot establish it.

### Method and limits

Runs are sequential, using the same retained Prototype/Endless bakes and seed 18. Window size is 1280×900, world size 673×363 for standalone RampMania and 673×473 for streamed modes. Four directional shadow cascades, the 8192 atlas, current light/camera settings, N64/VHS/CRT stack and 120 Hz physics stay enabled. VSync and the frame cap are disabled. The stationary Prototype course uses Reverse C Spring, Secret Entry and RampMania in that seeded order, with three resident Acts. The settled Endless opening has six resident Acts. Rendering inventory is not the same as rendered-object counters.

Each steady comparison has two fresh processes, each with three 600-frame blocks, 120 frames between blocks, and preparation settled before sampling. Tables use the median of six block medians/percentiles; these are not pooled percentiles. Worst frame is the maximum sampled frame across those blocks. Capturing a screenshot can itself stall the next frame by approximately a second; screenshots occur outside samples, with the next settling interval excluding that readback. Startup and lookahead are reported separately. One early ANGLE standalone repeat received native input and moved its camera; it is excluded. Stationary probes now disable native input without stopping simulation, and camera/resolution metadata is checked across accepted samples.

One isolated application profile is reused throughout. It is seeded with the existing Pass 2 shader cache, without copying player settings or telemetry. ANGLE therefore starts with prior cache coverage; Vulkan's initial runs encounter their own first-use preparation. No driver cache is cleared, and no sterile cache experiment is performed. These debug-script startup times are not a replacement for Alex's approximately three-second normal player startup observation. They include this selected three-Act course and preparation path; engine/process initialization precedes the reported scene startup. Raw reports, screenshots, logs and process wall times are retained under ignored `test-results/renderer-bakeoff/`.

Godot's counters do not describe identical passes across renderers. Compatibility reports no useful separate shadow or GPU timing here; zero means unavailable, not free. Forward+ can automatically instance matching opaque meshes and has a depth prepass; Mobile uses a different render path. A lower object/draw counter does not establish that geometry vanished. Compare matched views, resident/inventory counts, frame time and CPU cost together. Summed viewport CPU/GPU timings are diagnostic work measurements, not additive wall-clock frame components. See the official [renderer comparison](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html), [automatic instancing](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html#use-automatic-instancing) and [pipeline compilation monitors](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html).

### Results and desktop recommendation

**Forward+/Vulkan is the recommended desktop migration candidate.** Both Vulkan renderers roughly halve the steady frame time of the current Compatibility/ANGLE path on this RTX 4060. Forward+ and Mobile are effectively tied in the ordinary Green Hill session and settled Endless opening; Forward+ has the stronger RampMania and Aquarium results, while Mobile is faster in Chemical Plant and often cheaper during first-use preparation. This is not a universal Forward+ victory on every workload or GPU. Keep Compatibility/ANGLE as the production default until the visual differences below are approved; the new Lighting Lab launches Forward+ independently.

Steady samples, milliseconds unless specified. Each row represents six 600-frame blocks from two processes. `CPU` is measured render CPU; `Objects` is the renderer's counter, not scene inventory. Aquarium's longer confirmation compares the two Vulkan candidates; its shorter ANGLE visual sample is not promoted into this table.

| View / renderer | Median | p95 | p99 | Worst | Draws | Objects | CPU | GPU | Resident Acts |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| RampMania / ANGLE | 15.553 | 23.774 | 27.228 | 38.129 | 1,373 | 2,005 | 12.672 | n/a | 1 |
| RampMania / Forward+ | 5.324 | 8.205 | 9.350 | 37.191 | 1,367 | 2,007 | 1.874 | 0.686 | 1 |
| RampMania / Mobile | 5.877 | 8.508 | 10.190 | 22.212 | 567 | 1,201 | 2.055 | 0.573 | 1 |
| Prototype GH / ANGLE | 22.807 | 32.319 | 35.522 | 45.927 | 2,776 | 2,872 | 17.998 | n/a | 3 |
| Prototype GH / Forward+ | 10.955 | 14.995 | 16.771 | 35.207 | 2,113 | 2,873 | 4.544 | 0.715 | 3 |
| Prototype GH / Mobile | 10.904 | 15.539 | 17.265 | 88.122 | 1,561 | 1,658 | 4.541 | 0.539 | 3 |
| Endless opening / ANGLE | 17.626 | 24.172 | 26.306 | 43.974 | 1,668 | 1,934 | 13.099 | n/a | 6 |
| Endless opening / Forward+ | 7.974 | 10.954 | 13.994 | 105.593 | 670 | 1,934 | 2.817 | 0.646 | 6 |
| Endless opening / Mobile | 7.934 | 11.275 | 13.379 | 184.847 | 1,048 | 1,314 | 2.963 | 0.482 | 6 |
| Chemical Plant / ANGLE | 19.088 | 26.822 | 29.225 | 41.677 | 2,782 | 2,882 | 14.697 | n/a | 3 |
| Chemical Plant / Forward+ | 9.568 | 13.617 | 15.498 | 48.221 | 1,138 | 2,884 | 3.359 | 0.721 | 3 |
| Chemical Plant / Mobile | 8.414 | 11.981 | 13.456 | 32.437 | 1,551 | 1,654 | 3.348 | 0.553 | 3 |
| Aquarium / Forward+ | 8.237 | 12.105 | 13.705 | 16.964 | 1,333 | 4,662 | 3.240 | 0.972 | 3 |
| Aquarium / Mobile | 9.512 | 14.162 | 15.815 | 20.844 | 2,422 | 2,523 | 4.258 | 0.652 | 3 |

The nearly unchanged RampMania draw count between ANGLE and Forward+ is particularly informative: render CPU falls from 12.672 to 1.874 ms without a corresponding reduction in submitted geometry. Backend submission/pass handling matters substantially, alongside batching. Forward+'s automatic instancing is also relevant to the much lower Endless/Chemical draw counts. This comparison does not isolate the ANGLE translator from the rest of Compatibility; native OpenGL is not a supported candidate because of the previously reproduced NVIDIA crash. Vulkan's sub-millisecond GPU work and much larger total frame times still point toward CPU/preparation work, rather than simply needing lower resolution.

### Normal Prototype play and continuous streaming

The ordinary Challenge check launches the real Session, menu/bake validation, HUD, sounds and isolated telemetry. It uses finite Balls, Sonic, one Green Hill Zone, and 3,600 physics ticks of scripted launch/steering/flipper inputs. It does not teleport, grant score or force an Act clear. Dynamic camera/ball paths are not identical across renderers, so this complements the stationary comparison rather than replacing it. Mean FPS is observed frames divided by elapsed time, not the reciprocal of median frame time.

| Challenge / process | Mean FPS | Median ms | p95 ms | p99 ms | Worst ms | Frames >100 ms | Ready after Start ms |
|---|---:|---:|---:|---:|---:|---:|---:|
| ANGLE 1 | 31.4 | 31.028 | 43.143 | 50.534 | 474.850 | 2 | 9,753.796 |
| ANGLE 2 | 39.4 | 24.416 | 36.457 | 43.258 | 87.160 | 0 | 7,611.614 |
| Forward+ 1 | 82.3 | 10.922 | 17.022 | 21.598 | 612.131 | 4 | 7,420.802 |
| Forward+ 2 | 82.3 | 11.458 | 18.370 | 21.986 | 81.740 | 0 | 4,084.561 |
| Mobile 1 | 82.1 | 11.522 | 18.413 | 22.172 | 176.611 | 1 | 3,806.769 |
| Mobile 2 | 81.1 | 11.768 | 18.663 | 22.427 | 48.805 | 0 | 3,748.010 |

Menu validation is separate from Start: approximately 4.9–8.6 seconds in these diagnostic processes. All six sessions remain playable, finish sampling with two Balls left, have three resident Acts, zero boundary waiting and zero runtime rebuilds. Scores are 755 except ANGLE process 2 at 955. This is an opening play sample, not a completed Challenge run or a human feel evaluation.

Continuous Endless tours use speed 400, seed 18, unchanged lookahead and target sequence 6. Every process reaches that target with zero runtime rebuilds.

| Tour / process | Median ms | p95 ms | p99 ms | Worst ms | Boundary wait ms | Frames >100 ms | Peak residents |
|---|---:|---:|---:|---:|---:|---:|---:|
| ANGLE 1 | 18.975 | 36.129 | 123.503 | 189.289 | 5,723.603 | 18 | 3 |
| ANGLE 2 | 18.728 | 33.674 | 105.404 | 152.765 | 3,702.026 | 13 | 3 |
| Forward+ 1 | 10.711 | 17.394 | 55.832 | 5,988.987 | 672.915 | 4 | 4 |
| Forward+ 2 | 10.709 | 18.514 | 45.806 | 158.388 | 0 | 1 | 4 |
| Mobile 1 | 10.301 | 17.630 | 79.740 | 3,421.307 | 314.159 | 6 | 4 |
| Mobile 2 | 11.122 | 21.273 | 63.198 | 148.260 | 0 | 2 | 4 |

The faster backend allows the same scheduler to reach four resident Acts; no buffer was reduced. First-process Aquarium graphics warm probes correlate with the largest Vulkan stalls: approximately 6.77 seconds of Forward+ probe rendering and 3.95 seconds on Mobile, while CPU node creation is tiny. The worst Forward+ frame reports roughly 5,981 ms render wall time versus 6 ms render CPU and 0.87 ms GPU. First-use pipeline/driver setup is the leading inference, not a measured compiler breakdown. Pipeline counters record created variants but do not measure compiler duration or establish an empty driver cache. Immediate repeats remove the multi-second outliers and boundary waits, but still contain 148–158 ms spikes. **Vulkan improves streaming headroom; first-use hitching is not solved.** Nonzero-wait tours return the profiler's existing failure exit code despite completing their route.

### Preparation and visual migration cost

The initial short Vulkan pilots become ready at 46.012 → 9.746 seconds for Forward+, and 28.120 → 8.721 seconds for Mobile on immediate repeat. Later full Chemical Plant probes record 38.592 → 7.707 seconds and 23.723 → 7.126 seconds respectively; ANGLE records 12.109 → 10.280 seconds with prior cache coverage. These are different preparation buckets from an ordinary menu-validated Start, and they are not sterile-cold or cache-equivalent benchmarks. Full reports retain startup frame tails, lookahead timing, process wall times and pipeline counts separately. Inventory walks and screenshot readbacks are outside steady timed blocks.

Matched gameplay/overview captures were rendered and inspected across all eight themes. No missing-geometry, magenta-material or shader compilation failure was observed. Forward+ and Mobile are visually close to each other; neither is an as-is image match for Compatibility:

- **Aquarium:** glass remains transparent with visible fish, but glass/water become milkier and much brighter cyan. The dark lagoon atmosphere changes substantially.
- **Sky Sanctuary:** clouds remain present, but bright cloud regions lose contrast/detail. Stone becomes darker relative to the background.
- **Lava Reef:** molten surfaces, crystals and cavern remain present; orange glow/haze becomes much stronger. The optional, default-off heat-haze experiment was not enabled.
- **Chemical Plant:** yellow/cyan light halos broaden and the purple background brightens; foreground color balance also changes.
- **Ice Cap:** ice, crystals and aurora remain present, with a brighter blue background and relatively darker foreground.
- **Green Hill, Rooftop and Casino:** recognizable materials and shadows remain; warmth, saturation, emission and foreground/background contrast differ. Ball presentation and the N64/VHS/CRT stack remain readable.

Animated shader time, enemy/Ring poses and HUD counters prevent pixel-equality claims. The differences are substantial enough to require lighting/material calibration and human approval, not merely a backend flag. The user-requested [Lighting Lab](LIGHTING_LAB.md) is the next review tool; it does not silently apply its presets to Prototype, Endless, bakes or production renderer settings.

Next priorities are **reviewing the Vulkan presentation and addressing first-use preparation**, then profiling conservative foreground/caster visibility on the selected backend. Presentation bounds must include offscreen shadow casters and joining Acts. Badnik's culling and shadow discipline remain useful references, but the backend result reduces the case for a large visibility rewrite before choosing the render path. No physics culling, reduced resident buffer, lower shadow quality, new engine or language migration is justified by this investigation.

### BadnikFramework architecture reference

Alex reports that Badnik's example game feels smooth on the same RTX 4060. The source review is pinned to [`9f1c38a99b4b042fc1999c338cc0d8a57d3e3bd2`](https://github.com/Gnidel/BadnikFramework/tree/9f1c38a99b4b042fc1999c338cc0d8a57d3e3bd2). This is an architecture comparison, not an instrumented benchmark of that executable or proof of its exact stage, preset, export configuration or renderer.

- **Distance-limited activity is real.** `StageData` defaults to 200 units for enemies and 100 for items. Distant actors have processing, physics callbacks and visibility disabled, with opt-outs for dead/launched enemies and attracted items. Item checks are amortized over 50 items per update after the initial pass. This reduces several kinds of work simultaneously. Our resident foreground Acts remain rendered and shadow-capable; their safe residency does not require every presentation node to contribute every frame. Preserve our authoritative collision/streaming rules when considering presentation culling. [StageData.cs](https://github.com/Gnidel/BadnikFramework/blob/9f1c38a99b4b042fc1999c338cc0d8a57d3e3bd2/Scripts/System/StageData.cs#L57)
- **Shadow workload differs substantially.** DiscoHill enables one orthogonal directional shadow map, while the inspected HubStage and DigitalSeaActB1 lights specify orthogonal mode but do not enable shadows at all. They are not four-cascade comparisons. A single map avoids repeated caster submissions but can lose nearby shadow detail; our Pass 2 two-cascade test already demonstrated an unacceptable ramp-shadow blur. Do not copy a cascade count without checking the intended image. [DiscoHill](https://github.com/Gnidel/BadnikFramework/blob/9f1c38a99b4b042fc1999c338cc0d8a57d3e3bd2/Games/Example%20game/Levels/DiscoHill/DiscoHill.tscn#L176), [HubStage](https://github.com/Gnidel/BadnikFramework/blob/9f1c38a99b4b042fc1999c338cc0d8a57d3e3bd2/Games/Example%20game/Levels/Hub/HubStage.tscn#L206), [DigitalSeaActB1](https://github.com/Gnidel/BadnikFramework/blob/9f1c38a99b4b042fc1999c338cc0d8a57d3e3bd2/Games/Example%20game/Levels/Digital%20Sea/DigitalSeaActB1.tscn#L295), [shadow modes](https://docs.godotengine.org/en/stable/classes/class_directionallight3d.html#enum-directionallight3d-shadowmode)
- **Selective casting matters more than apparent scene size.** The sun quad, explosion smoke and blue-sphere mesh explicitly disable casting; the sphere also has a visibility-range limit. Large scenery with a few material submissions can cost less CPU than many small multipart mechanics repeated through shadow passes. That explains a plausible architectural advantage, not a measured percentage of Badnik's frame time. [Smoke](https://github.com/Gnidel/BadnikFramework/blob/9f1c38a99b4b042fc1999c338cc0d8a57d3e3bd2/SonicAssets/Prefabs/Particles/Explosion/%5Bparticles%5D_explosion_smoke.tscn), [blue sphere](https://github.com/Gnidel/BadnikFramework/blob/9f1c38a99b4b042fc1999c338cc0d8a57d3e3bd2/SonicAssets/Prefabs/Items/%5Bitem%5D_blue_sphere.tscn)
- **Occlusion is enabled, but its benefit is not established by the checkbox.** Godot still requires occluder geometry and useful occlusion opportunities. The three inspected stage files contain no explicit `OccluderInstance3D` node. This review does not establish what imported/nested assets supply. Our elevated, largely open board also presents different occlusion opportunities from a corridor or enclosed level. [Project settings](https://github.com/Gnidel/BadnikFramework/blob/9f1c38a99b4b042fc1999c338cc0d8a57d3e3bd2/project.godot), [Godot occlusion setup and costs](https://docs.godotengine.org/en/stable/tutorials/3d/occlusion_culling.html)
- **Quality controls exist.** Render distance is applied to each player camera's far plane. The options code exposes resolution, AA and effect choices; environment settings enable/disable several effects. Different user presets can therefore change the actual workload considerably. A shorter camera far plane alone does not suspend actor logic or prove that all shadow work disappears. [ApplyPlayerSettings.cs](https://github.com/Gnidel/BadnikFramework/blob/9f1c38a99b4b042fc1999c338cc0d8a57d3e3bd2/Scripts/System/ApplyPlayerSettings.cs), [OptionsMenu.cs](https://github.com/Gnidel/BadnikFramework/blob/9f1c38a99b4b042fc1999c338cc0d8a57d3e3bd2/Scripts/Ui/OptionsMenu.cs), [environment settings](https://github.com/Gnidel/BadnikFramework/blob/9f1c38a99b4b042fc1999c338cc0d8a57d3e3bd2/Scripts/System/ApplyWorldEnvironmentSettings.cs)
- **The Mobile label is not runtime proof.** The checked-in project advertises `"Mobile"` in `config/features`, but has no explicit desktop `renderer/rendering_method`; its `.mobile` platform override is `gl_compatibility`. Godot documents the desktop setting's default as Forward+. The exported game may differ; its runtime renderer log is needed before attributing Alex's experience specifically to Mobile. This does not weaken the distance/shadow findings or our direct Mobile bakeoff. [project.godot](https://github.com/Gnidel/BadnikFramework/blob/9f1c38a99b4b042fc1999c338cc0d8a57d3e3bd2/project.godot), [renderer setting and runtime override](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-rendering-renderer-rendering-method)

The useful lesson is to budget active objects, material submissions and shadow passes rather than judging cost by how large a scene looks. Nothing in this reference establishes that changing GDScript to C#, copying the framework, or toggling occlusion alone would solve our measured render CPU bottleneck.

### Bakeoff reproduction and verification

Use the existing renderer-independent bakes, one sequential rendering process at a time, and one reused application profile. Run each command twice without clearing caches. Select `gl_compatibility/opengl3_angle`, `forward_plus/vulkan`, or `mobile/vulkan`; the examples use Forward+. `$godot` must name a correctly paired Godot 4.7.2 console wrapper/executable.

```powershell
$env:APPDATA = Join-Path $PWD 'test-results\renderer-profile'
$env:LOCALAPPDATA = $env:APPDATA
& $godot --path . --rendering-method forward_plus --rendering-driver vulkan --script res://tests/render_cost_profile.gd -- --seed=18 --profile-mode=prototype --profile-samples=600 --profile-output=res://test-results/prototype-forward.json
& $godot --path . --rendering-method forward_plus --rendering-driver vulkan --script res://tests/render_cost_profile.gd -- --seed=18 --profile-mode=prototype --profile-theme=chemical_plant --profile-overview --profile-output=res://test-results/chemical-forward.json
& $godot --path . --rendering-method forward_plus --rendering-driver vulkan --script res://tests/endless_stream_profile.gd -- --seed=18 --profile-speed=400 --profile-target=6 --profile-unlimited --profile-stages --profile-output=res://test-results/tour-forward.json
& $godot --path . --rendering-method forward_plus --rendering-driver vulkan --script res://tests/prototype_play_profile.gd -- --seed=18 --profile-seconds=30 --profile-output=res://test-results/play-forward.json
```

Use `--profile-mode=act` for the standalone RampMania comparison and `--profile-mode=endless` for the settled Endless view. The standalone player uses its existing `--theme=<id>` argument; `--profile-theme=<id>` selects the Prototype course theme. Visual-only probes used 120 frames per block; reported steady measurements use 600. Raw local evidence includes `summary.json`, `validation.json`, `runs.jsonl`, `gallery.html` and per-process JSON/log/PNG files in ignored `test-results/renderer-bakeoff/`.

Accepted evidence contains **28 full steady reports, six continuous tours, six ordinary Challenge sessions and 18 additional theme visual reports**, plus the explicitly identified startup pilots. Cross-backend steady cameras, world sizes and complete geometry inventories match within each workload. Runtime metadata confirms the intended renderer/driver and 120 Hz physics. All accepted streamed/play reports have zero runtime rebuilds. The early native-input-contaminated ANGLE standalone repeat is excluded and replaced by two clean confirmations. An initial ordinary-play harness attempt did not wait for the menu validation gate; it produced no accepted report, was fixed, and all six reported sessions use the corrected path.

The profiling additions only extend reporting and isolate native input. The Lighting Lab is a separate opt-in scene/launcher, added after all timing runs. No production renderer switch or gameplay optimization is included. Existing certificate-store messages are environmental; the continuous-stream harness still has previously documented ObjectDB shutdown warnings. No shader parse/compile failure appeared in the accepted renderer capture matrix. User-owned art remains separate; all 1,284 initially modified/untracked files were hash-checked unchanged after measurement and lab verification.
