# Forward+/Vulkan first-use preparation — 2026-11-08

## Scope and measurement contract

This investigation starts from `21f97e358c1bce5bb2d947cf0025740629983b06` plus the existing local art. A frozen source copy under ignored `test-results/vulkan-first-use/source/` protects measurements from concurrent authoring work. All 40 Prototype variants were rebuilt there through the supported baker. The three-Act course uses seed 18, Reverse C Spring, Secret Entry and RampMania. No authored geometry, artwork, physics, shadow quality, render scale or residency policy is changed by the profiling tools.

The primary renderer is the installed Godot **4.7.2 stable `ed1daf0bf`**, Forward+/Vulkan, on the RTX 4060. Production world/warm-up/background viewports use 4× MSAA and 100% render scale. Each cold application-cache run gets new isolated APPDATA and LOCALAPPDATA directories, followed by a fresh process using the same directories. No global driver cache is cleared. These are **not sterile GPU-driver-cache measurements**.

`tools/profile_vulkan_first_use.ps1` rejects concurrent Godot processes, including headless bakes/tests. Early exploratory runs overlapped other chats' graphical captures or CPU-heavy bakes; their timings are excluded. Their deterministic counter observations helped locate the defect, but they are not accepted before/after performance evidence. The guard samples process inventory every two seconds; the user and both other authoring chats also reserved the machine's Godot work for the measurements.

**Primary timings omit `--verbose`.** Verbose shader-cache logging proved highly intrusive on this Windows setup: the Green Hill control reached readiness at 21.9/37.3 seconds cold/warm with logging, versus 10.1/7.2 seconds without it. The same pipeline totals were recorded. Verbose runs establish cache consumption and help source attribution; their elapsed times do not describe ordinary startup. The runner makes verbose logging opt-in through `-VerboseEngine`.

The profiler captures exact pipeline counters at pre/post draw, frame completion intervals, delayed viewport CPU/GPU work, library batch identities/events, ready/first-visible/settled milestones, resource inventories and loaded bake fingerprints. The runner adds process wall time, engine hash, cache file sizes/hashes and overlap receipts. Screenshot readback and inventory traversal happen after timing ends. Process lifetime therefore also includes reporting, readback and normal teardown; the readiness milestones are the preparation measurements. Fine-grained class inventories are taken after timing; frame/phase samples use Godot's total resource count to avoid repeatedly traversing the resource graph inside a measured frame.

Engine initialization before the script starts is separately visible in `script_initialize.at_us`. The first recorded completion interval includes synchronous script loading and game construction; it must not be presented as a pure rendering frame. Subsequent completion intervals, the first visible game frame, and frames after readiness are reported separately. CPU/GPU viewport measurements describe delayed work; they do not add up to wall time and do not account for all compilation waits.

## What the actual 4.7.2 counters mean

The installed runtime exposes these `Performance.Monitor` constants, discovered through `ClassDB`, rather than assumed from another release:

| Exact monitor | Value | Meaning |
| --- | ---: | --- |
| `PIPELINE_COMPILATIONS_CANVAS` | 34 | Canvas-renderer pipeline requests |
| `PIPELINE_COMPILATIONS_MESH` | 35 | Requests generated while loading mesh surfaces with associated materials |
| `PIPELINE_COMPILATIONS_SURFACE` | 36 | Requests generated while building/updating geometry surface caches |
| `PIPELINE_COMPILATIONS_DRAW` | 37 | Missing fallback/ubershader pipelines requested by the actual draw path |
| `PIPELINE_COMPILATIONS_SPECIALIZATION` | 38 | Optimized variants requested in the background |

These counters increment when a new pipeline task is submitted. They do **not** count driver cache misses, measure compiler duration, or prove that a background task has finished. They can therefore have identical totals in cold and warm processes. A draw can also wait for an unfinished pipeline already charged to `SURFACE`, without incrementing `DRAW`. Shader-language/SPIR-V work, sky and built-in post-processing work are not comprehensively described by the scene pipeline counters.

The pinned engine sources establish this behavior: [runtime monitor definitions](https://github.com/godotengine/godot/blob/ed1daf0bf/doc/classes/Performance.xml), [request deduplication and waits](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/pipeline_hash_map_rd.h), and [Forward+ draw/precompilation paths](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp).

## Confirmed MSAA preparation mismatch

Godot 4.7.2 derives its global precompilation sample count from `rendering/anti_aliasing/quality/msaa_3d`. SSR instead set 4× MSAA only on its runtime SubViewports through `RenderingOptions`; the project setting was absent, leaving the preparation hint at disabled/1 sample. The resource and surface preparation paths therefore generated a different framebuffer/sample-count pipeline from the one actually needed at first draw.

The controlled diagnostic changes only that project hint to `Viewport.MSAA_4X` (enum value 2). Actual viewport MSAA remains 4× in both conditions. Across Green Hill, Chemical Plant, Aquarium Park and Ice Cap, this eliminates all observed draw-triggered scene pipeline requests while preserving the mesh/surface/specialization counts. This is a renderer-state declaration issue, not a reason to lower MSAA or remove material features.

The retained implementation declares that default in `project.godot` before resource loading. `RenderingOptions._apply_view` also keeps the global preparation hint aligned with the existing, unsaved 0×/2×/4× diagnostic controls. This does not save device preferences or alter the production 4×/100%/8192-shadow/four-cascade policy. Because rendering policy is part of the bake fingerprint, normal Bake Prototype/Bake Endless refreshes are required after updating.

Source: [`_update_global_pipeline_data_requirements_from_project`](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp#L4144). The engine refreshes this state during renderer updates and uses it to build color/depth framebuffer formats during precompilation.

## Measured production result

The following paired values are **before / retained implementation**, with fresh application profiles followed by immediate repeats. They use the same frozen source, course, camera and quality, with normal rebakes after the policy fingerprint changed. This is one cold/warm pair per theme and condition, not a statistical speedup claim. The separate hint-only control used unchanged bake files and reproduced the same elimination of draw requests.

Ready time runs from the engine's startup clock to first Act readiness. “Worst subsequent” excludes only the first completion interval, whose synchronous script/tree setup is reported immediately below. `MESH`, `SURFACE` and `SPECIALIZATION` totals are identical before/after; `CANVAS` is 5 in every row. The labels refer to the exact `PIPELINE_COMPILATIONS_*` monitors defined above and stored in the JSON evidence.

| Theme | Cache | Ready seconds, before / after | Worst subsequent completion ms, before / after | MESH | SURFACE | DRAW, before / after | SPECIALIZATION |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Green Hill | Cold | 10.43 / 10.43 | 282.7 / 276.5 | 16 | 64 | 53 / 0 | 111 |
| Green Hill | Warm | 7.22 / 7.30 | 190.0 / 210.1 | 16 | 64 | 53 / 0 | 111 |
| Chemical Plant | Cold | 10.25 / 10.55 | 216.0 / 426.3 | 19 | 54 | 48 / 0 | 99 |
| Chemical Plant | Warm | 7.16 / 7.05 | 86.9 / 96.7 | 19 | 54 | 48 / 0 | 99 |
| Aquarium Park | Cold | 9.58 / 10.06 | 229.9 / 282.5 | 13 | 61 | 43 / 0 | 86 |
| Aquarium Park | Warm | 7.26 / 7.34 | 123.0 / 129.2 | 13 | 61 | 43 / 0 | 86 |
| Ice Cap | Cold | 9.61 / 9.63 | 305.0 / 267.1 | 13 | 57 | 47 / 0 | 87 |
| Ice Cap | Warm | 7.00 / 7.06 | 158.8 / 162.5 | 13 | 57 | 47 / 0 | 87 |

The overall largest recorded completion interval is the first one: cold Green Hill **2833 / 2892 ms**, Chemical Plant **2891 / 2856 ms**, Aquarium **2833 / 2943 ms**, Ice **2817 / 2979 ms**. Warm first intervals span **2588–2689 ms** across both conditions. These are not discarded costs: readiness includes them. The marks distinguish the preceding engine initialization, production-script load, tree attachment and first draw.

| Theme | Cold worst after readiness ms, before / after | Warm worst after readiness ms, before / after | Cold steady median ms, before / after | Warm steady median ms, before / after |
| --- | ---: | ---: | ---: | ---: |
| Green Hill | 149.4 / 83.7 | 75.3 / 86.6 | 6.668 / 6.160 | 5.971 / 6.417 |
| Chemical Plant | 216.0 / 77.7 | 54.7 / 60.5 | 4.754 / 4.778 | 4.651 / 4.686 |
| Aquarium Park | 83.1 / 72.8 | 62.9 / 63.2 | 5.374 / 5.308 | 5.184 / 5.503 |
| Ice Cap | 133.5 / 76.0 | 61.9 / 59.1 | 5.039 / 4.763 | 4.813 / 4.886 |

The steady windows contain 301 completed frames including the closing draw. Their delayed GPU medians remain approximately **0.83 / 0.91 / 0.98 / 0.93 ms** for Green Hill / Chemical / Aquarium / Ice. Render-CPU medians remain approximately **2.5 / 1.8 / 2.1 / 1.8 ms**. Whole-frame medians vary in both directions; this pass establishes pipeline coverage, not a steady-state speedup. No extra loading phase or scheduling delay was introduced.

Timeline examples show why counter categories matter:

- Before the fix, first visible gameplay adds one `DRAW`, one `SURFACE` and one `SPECIALIZATION` request in each Prototype theme. After the fix it still adds surface/specialization work, but no `DRAW` request.
- Retained Chemical Plant's 205.6 ms resource-wait completion includes a 205.0 ms render interval and six new `MESH` requests. This is loading-related work, not a missing fallback first discovered by a draw.
- Its larger 426.3 ms completion has **zero new pipeline requests**. The render interval is only 1.5 ms and the overlapping recorded handoff is 5.1 ms. The rest lies outside those instrumented spans; attributing it to draw compilation or purely to GDScript would be unsupported.
- Retained Green Hill's 276.5 ms completion adds six `SURFACE` requests around live visual setup; Aquarium's 282.5 ms completion adds three. A zero `DRAW` count does not remove all surface/native work.

### Endless stress path

The same seed-18 tour reaches sequence 6 through Sky Sanctuary, Green Hill and Aquarium Park with zero fallback rebuilds and a peak of **six resident Acts**. Before/after cold readiness is **8.97 / 8.89 s**. Totals are `MESH=19`, `SURFACE=128`, `SPECIALIZATION=181`, `CANVAS=5`, while `DRAW` falls **88 to 0**. Twenty of the old draw requests occurred during traversal; none do after the fix.

The worst completion after the initial setup falls **452.7 to 226.8 ms**, but the traversal-only worst is essentially unchanged at **214.3 / 218.6 ms**. Tour duration is **9.44 / 9.48 s**, and the settled opening-view median is **3.872 / 3.940 ms**. The retained warm repeat reaches readiness in **6.82 s**, with a **142.7 ms** traversal maximum. This supports the shared architectural principle without claiming that every transition hitch is fixed.

### Resources and residency

Every Prototype pair keeps **three resident Acts**, the same loaded course/camera/world size, and identical live material/mesh/shader/texture counts. Green Hill's live counts are **806 / 800 / 17 / 10**, Chemical's **302 / 460 / 13 / 37**, Aquarium's **272 / 427 / 13 / 21**, and Ice's **278 / 439 / 14 / 21**. Serialized unique material identities shift by one in Green Hill/Aquarium after the normal rebake; the corresponding live inventories remain equal. No new ownership graph or permanent resource cache was added.

Across the eight Prototype pairs, sampled static-memory peak changes range from **−1.47 to +1.94 MiB**, and reported video-memory peak changes from **−8 to +8 MiB**. The counters include renderer allocation/pool variation; they are not a retained-allocation audit. Endless cold peak static memory changes from approximately **255 to 252 MiB**. Its final live inventory is also identical, and its residency limit is unchanged. The known threaded-loader leak remains visible and separate.

## Resource construction audit

The supported disk path loads validated `GeometryBake` resources using the existing threaded loader. Their visual recipes contain small PackedScenes with real Mesh/Material/Shader references; background/environment resources and material probes are also serialized. Generated shader programs and eligible meshes/textures already share external, content-addressed bake resources through `bake_assets.gd`.

Many meshes use a node material override. Godot's mesh-load precompilation skips a mesh surface with no attached surface material; it cannot recover the node override from that mesh alone. The override becomes known when the geometry instance's surface cache is built. This explains the division between `MESH` and `SURFACE`; a low mesh count alone does not establish missing preparation.

`visual_recipe.instantiate_one` reconstructs a MultiMesh from its saved mesh, transforms and AABB. Ordinary node scenes retain their shared mesh/material references. Warmed foreground nodes are retained and incrementally attached to the live Act. They are not rebuilt into new geometry at handoff. Hardware bindings duplicate selected state-light materials so separate Acts can animate independently. Uniform/color changes retain shader features.

Live atmosphere bindings can create private material copies and adapt standard/custom scenery shaders. The character, Goal and combo presentations also have runtime resources outside the Act bake. These are real late combinations, so the broad claim that every production resource is already known at disk load is false. The matching-MSAA experiment demonstrates that the surface preparation path can cover the tested combinations without draw-triggered requests; it does not promise that all associated compilation has completed before every possible first draw.

| Production owner | When the renderer learns the combination |
| --- | --- |
| `geometry_bake.gd`, `bake_assets.gd`, threaded `_load_bake` | Serialized mesh surface materials can generate `MESH` requests. Shared shader code and eligible meshes/textures already have reusable disk identities. |
| `visual_recipe.gd` ordinary nodes and MultiMeshes | `instantiate_one` associates the effective material with geometry; detached construction already generates `SURFACE` work. MultiMesh transforms are reconstructed from the saved recipe. |
| `template_library.gd` warm root and retained Act nodes | Existing probes and actual upcoming recipes are prepared incrementally, then warmed Act nodes are handed to gameplay. The fix does not add another copy. |
| Hardware state bindings | Private material copies preserve independent Act animation. Ordinary uniform changes do not create a new shader source. |
| `atmosphere/material_bindings.gd`, `standard_surface.gd`, `surface_controls.gd` | Live foreground/background attachment can convert or extend shader sources after disk load. These operations also appear inside the measured `cpu.live.visuals`/`cpu.live.background` spans. Those spans include engine calls, not only GDScript arithmetic. |
| Sky, environment, compositor | Sky radiance, built-in compute/post-processing and shader-module preparation are not exhaustively represented by the five scene/canvas pipeline counters. |

## Controlled resource experiments

These causal fixtures load the existing validated recipes. Their 256×256 view, camera and light are diagnostic; actual Prototype supplies the production proof. Pipeline counts are task requests, so the intervals below establish **when work is queued**, not a portable compiler-time saving.

| Recipe / state | Loading: `MESH` | Detached: `SURFACE` | Hidden attachment: new requests | First reveal: `DRAW` | First reveal: `SPECIALIZATION` |
| --- | ---: | ---: | ---: | ---: | ---: |
| Chemical Plant's 36 existing probes, old hint | 0 | 34 | 0 | 24 | 68 |
| Same probes, matching 4× hint | 0 | 34 | 0 | 0 | 68 |
| Chemical Plant Reverse C Spring, 987 records, matching hint | 21 | 28 | 0 | 0 | 27 |
| Aquarium background, 48 records, matching hint | 0 | 11 | 0 | 0 | 12 |

The detached recipe nodes have no scene-tree parent. This rejects the assumption that `visible=false` necessarily prevents useful preparation in this engine version. Hidden attachment added nothing beyond the detached surface work; specialization still waited for actual drawing. Loading a theme resource alone queued no scene pipelines because the material associations live on its recipe nodes.

Chemical Plant feature isolation with the old hint also rejects a custom-shader-only explanation:

| Existing probe subset | Nodes | `SURFACE` | `DRAW` | `SPECIALIZATION` |
| --- | ---: | ---: | ---: | ---: |
| Ordinary MeshInstance3D | 18 | 34 | 24 | 34 |
| MultiMeshInstance3D | 18 | 34 | 24 | 34 |
| Standard/BaseMaterial3D | 16 | 12 | 9 | 24 |
| Custom ShaderMaterial | 20 | 24 | 16 | 48 |

Shared fallback pipelines are deduplicated, so subset counts are not additive. Both instance paths and both material families expose the mismatch. The pinned Forward+ source generates material-dependent color, depth/prepass and shadow variants; MSAA changes the relevant framebuffer key. The unchanged-feature, hint-only comparison isolates that key without removing transparency, custom code, depth passes or shadows. Counters alone cannot assign compiler duration to an individual variant.

Candidate A is partly already implemented: real references and shared external resources exist. Repacking every node override onto new per-mesh resources would duplicate data without evidence of a useful gain. Candidate B works for queuing surface preparation, and the existing recipe instantiation path already benefits; adding a second hidden graph would add ownership/memory without addressing late live atmosphere conversions. Candidate C is unchanged: no additional boxes, no skipped instanced probes and no larger resident set. Correcting the hint removes missing fallback requests without reopening previously rejected probe-removal/prefetch policies. Existing warm draws still prepare specializations and other uncounted renderer work.

## Cache ownership

Both `rendering/rendering_device/pipeline_cache/enable` and `rendering/shader_compiler/shader_cache/enabled` are true in the inspected runtime. Godot stores device/driver-specific PSO data under `user://vulkan/pipelines.forward_plus.<device>.cache`, and intermediate shader data under `user://shader_cache/`. The isolated source copy contains no `.godot/shader_cache` seed.

Receipts record files appearing after cold runs and unchanged inputs to immediate repeats. Verbose logs report the nonempty startup PSO cache and eliminate shader-cache misses on repeat. Shader resource instance IDs do not directly define the persistent cache key: [ShaderRD hashes generated source sections and defines](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/shader_rd.cpp). [RenderingDevice](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/rendering_device.cpp) loads/saves the application PSO file; [the Vulkan driver](https://github.com/godotengine/godot/blob/ed1daf0bf/drivers/vulkan/rendering_device_driver_vulkan.cpp) validates device/driver metadata before handing it to Vulkan.

Cache consumption is established independently of whether a repeat has lower total wall time. Shader-only and PSO-only seeded controls exposed the verbose-logging confound: shader-cache hits produce many verbose messages, while PSO-only seeding retained roughly cold-run timing. The quiet cold/warm control restored the expected warm advantage. This is a reason to fix measurement conditions, not disable the engine cache. No device cache is included in repository assets, and no player preferences, telemetry or global driver data are removed.

## Appearance and verification

Normal canonical Prototype captures completed successfully for all eight themes before the change, after the retained policy and normal rebakes, and in an unchanged after-repeat. All receipts match Act/gameplay state, camera, source textures and production graphics settings. The unchanged repeat is pixel-identical.

Comparing the separately rebuilt before/after images gives small deterministic differences: **0.01–0.128 mean RGB channel levels out of 255**, affecting approximately **0.22–0.70%** of pixels. These are not presented as byte-identical pictures. A further control isolates the preparation policy from rebaking: the same final validated bakes and canonical fixture are rendered with the old 1× precompilation hint, while all production SubViewports remain at 4×. That control creates 269 cumulative draw-triggered requests across eight themes, yet produces **exactly the same PNG bytes as the fixed captures in all eight themes**. The hint change itself therefore has no observed image difference. A Green Hill root-viewport MSAA control also matched, but its exploratory wrapper timed out during shutdown and is not counted as a clean regression pass.

The final same-bake control removes its diagnostic callbacks, restores the normal hint and completes normally. Its reproducible diagnostic-only [patch](vulkan-first-use/appearance-control.patch), [pixel/hash comparison](vulkan-first-use/appearance-same-bake-hint.json) and [capture receipts](vulkan-first-use/appearance-hint-clean-manifest.json) are retained. The zero-context patch is for an isolated copy (`git apply --unidiff-zero`); the ordinary capture fixture is not changed. Three earlier forced-state wrappers produced their images but timed out at teardown; those attempts are excluded from lifecycle/exit-success claims. No production loader change or engine-warning suppression was used to obtain the final result.

The supported regression baseline passes **32 suites / 8,596 checks / zero assertion failures**, plus its six child reload checks. The full supplemental pixel-quality suite passes **68 checks**, including ten new assertions for the saved 4× hint and all nine supported live MSAA/scale combinations. A separate **44-check** unit run passes on the live working tree. The 32-suite baseline uses the frozen source plus the retained fix, not a silently changing mixture of the concurrent editor/art work; exact test/source/log hashes and rendered/headless modes are in [verification.json](vulkan-first-use/verification.json).

All **40 Prototype** and **56 Endless** disk variants, plus the traversal fixture, were rebuilt through the normal baker in the isolated project. The final Prototype bake audit passes all **425 checks**. PowerShell parsing, Node syntax and the graphical profiling paths were checked. Expected malformed-resource/archive-write diagnostics, certificate warnings and the previously isolated threaded ResourceLoader warnings remain in the logs. Initial stale copied bakes and an invalid capture-output path were corrected through normal baking and an absolute output path before collecting accepted evidence.

Live Acts/art and other chats' changes were preserved. The GPU/CPU timing reservation was released to both chats after the controlled measurements; later correctness/capture controls make no timing claims. The current editor commit is independently preserved, and the live-tree MSAA contract was checked after it. Remaining manual checks are another-device cold startup and normal traversal feel; this pass does not substitute for those.

## Evidence and reproduction

Committed summaries retain phase/stage wall times, worst frames with overlapping events, delayed render CPU/GPU samples, pipeline deltas, resource/draw/object/residency peaks, bake fingerprints, shader-source hashes and cache receipts:

- [Before](vulkan-first-use/before.json), [hint-only causal control](vulkan-first-use/hint-only.json), [retained implementation](vulkan-first-use/retained.json).
- [Resource/visibility/material/instance experiments](vulkan-first-use/resource-experiments.json), [Endless transition evidence](vulkan-first-use/endless.json).
- [Machine and engine identity](vulkan-first-use/machine.json), [frozen source manifest](vulkan-first-use/source-manifest.json), [regression verification](vulkan-first-use/verification.json).

Full frame streams, process/cache manifests, logs, frozen source, screenshots and isolated profiles remain under ignored `test-results/vulkan-first-use/`. Driver-specific cache binaries are deliberately not committed.

Run graphical diagnostics sequentially after validating/rebuilding the selected disk bakes. Use a new evidence directory for each comparison; the runner refuses to overwrite one. The hint-only A/B below requires the saved **pre-fix** source copy: the retained `RenderingOptions` policy deliberately synchronizes the hint when views register, so current production source is always the fixed condition.

```powershell
./tools/profile_vulkan_first_use.ps1 -ProjectRoot '<frozen project>' -OutputDirectory '<new baseline output>'
./tools/profile_vulkan_first_use.ps1 -ProjectRoot '<same frozen project>' -OutputDirectory '<new hint output>' -DiagnosticArguments '--profile-precompile-msaa=4'
./tools/profile_vulkan_first_use.ps1 -ProjectRoot '<same frozen project>' -OutputDirectory '<new resource output>' -Themes chemical_plant -ProfileScript vulkan_resource_probe -DiagnosticArguments '--recipe-kind=act','--attachment=hidden','--profile-precompile-msaa=4'
./tools/profile_vulkan_first_use.ps1 -ProjectRoot '<fixed frozen project>' -OutputDirectory '<new tour output>' -Mode endless -Themes seed18-tour
node tools/summarize_vulkan_first_use.mjs '<evidence directory>'
```

`vulkan_resource_probe.gd` separates resource-only loading, detached construction, hidden or zero-layer attachment and first visible draw. Optional ordinary/instanced and standard/custom filters apply only to independent existing material-probe records. They never filter or rewrite a production hierarchy. Seeded-cache diagnostics copy only selected shader/PSO files into a new isolated profile, with the seed recorded in the process receipt. The filename retains the first-run `-cold` suffix for compatibility, but a seeded process receipt explicitly labels its condition `seeded-shader`, `seeded-pipeline` or `seeded-all`; it is not a cold-cache sample.

For Endless, `-Themes` supplies one filename label only: the production seed-18 plan selects the multi-theme course. The retained evidence used the legacy `green_hill` filename label; its first visible frame is Sky Sanctuary, followed by Green Hill and Aquarium Park. Do not interpret those filenames as a single-theme Endless workload.

The upstream threaded ResourceLoader retention issue remains separate. No loader behavior, cleanup warnings or ownership policy is changed by this investigation.

## Remaining limits

The safe project-side conclusion is narrower than “compilation is solved”: the renderer now receives the correct framebuffer/sample-count declaration, so it does not discover missing scene fallback pipelines at draw time in the tested workloads. Specialization remains the largest request category, followed by surface preparation. Those are counts, not a ranking of elapsed compiler cost.

The historical six-second individual Vulkan draw stall did not reproduce in these quiet runs with an uncontrolled, previously used driver cache. Several seconds still precede the first recorded draw completion: platform/renderer startup, loading the production script and constructing the game. The first completion interval includes that synchronous setup. It must not be relabeled as a several-second GPU frame. Later outliers include mesh-load render waits, detached surface construction and live atmosphere/background setup; the event timeline distinguishes these boundaries.

Godot can wait for an unfinished precompiled surface pipeline even when `PIPELINE_COMPILATIONS_DRAW` stays zero. Its public counters do not expose individual compiler duration, driver cache-hit status or all built-in shader work. Delayed GPU timers do not measure CPU shader compilation or driver waits. Proving the owner of a renewed multi-second stall would require native engine/driver call timing on the reproducing configuration. These measurements do not justify replacing the loader, duplicating production graphs, disabling the cache or promising stall-free first use on another GPU.

The investigation therefore retains the small, measured state-declaration fix and the explicit profiler. It does not claim that all remaining startup cost is irreducible engine work. Existing late material adaptation is a visible timing boundary, but its adapted programs are already shared by source/features; further optimization needs separate evidence rather than another permanent warm-up system.
