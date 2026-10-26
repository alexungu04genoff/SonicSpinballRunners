# Endless authored-Act experiment

Open **Play Endless.cmd**. The supported modes are standalone authored Act play and seamless Endless streaming. F5 and **Play Act.cmd** start the authored player; the procedural alpha modes are retired.

The trial uses checked-in snapshots of **Second Simple**, **Third Complex**, and **First Try Smooth Decor** in `data/endless/`. Each Zone contains three shuffled Acts under one theme. Themes use a shuffled bag without adjacent repeats. There are no score gates or limited lives. Shared ball physics, controls, profiles, mechanics and characters remain authoritative.

## Continuous travel

Normal play never changes scenes or teleports between Acts. Upcoming collision and visual roots attach above the existing course. The same camera follows the same ball across aligned connectors; crossing the next Act's activation line transfers the checkpoint. Draining retries the active Act's Spawn.

The background blend starts 200 pixels before a Zone entrance and finishes 250 pixels beyond it. These distances are provisional. Two scenery/sky layers follow the gameplay camera during the overlap. Scenery fades by travel distance while foreground light direction, color, intensity, ambient color and exposure blend. Old scenery stops rendering after the fade and retires later. Foreground lighting uses ambient color without live sky reflections to avoid repeatedly rebuilding sky radiance. Reflective-material polish still needs visual review.

**T** starts a spectator camera tour with physics parked; it never pushes the ball into geometry. **N** jumps to the next ready Act only during this diagnostic tour. Leaving the tour serves safely at the current checkpoint. The HUD provides tour speed, pause and reset; **F3** shows streaming timings and disk-load/rebuild counters. N64-ish + VHS + CRT remain enabled by default, with F4 / Shift+F4 controls. Both backgrounds and foreground pass through the gameplay effects; the HUD stays at native resolution. Theme surface shaders and live animations remain enabled.

## Bake from the editor, then load from disk

1. Finish verification and playtesting, then save the Act in Act Builder.
2. Click **Bake** in the editor header. The same offline baker used by **Bake Endless.cmd** prepares the saved Act for every theme.
3. Keep `<Act name>.bake/` beside its `.tres` source, together with `data/endless/themes.bake/`, `data/endless/assets.bake/` and referenced imported assets.

**Version 5** stores reusable Endless preparation data on disk:

- Act sidecars contain pre-decomposed terrain collision shapes, complete visual recipes, material assignments, explicit animation bindings and CPU instance buffers. Primitive geometry is converted to vertex buffers offline.
- Shared theme sidecars contain scenery, sky, lighting and the foreground material preload list. Ordinary and instanced probe recipes are now built offline and saved alongside them.
- Warm-up manifests store stable material/render-feature signatures, original visibility and cull margins. Dependency manifests record resource ownership for gradual cache retirement. Normal baked play consumes these lists without repeating material reflection or discovering resource dependencies.
- Identical meshes and procedural image textures share content-addressed files in `assets.bake`; imported assets retain their external references. Full Act bakes omit the unused material-free geometry dictionary, which duplicated meshes already in their recipes. A small geometry-job count remains for diagnostics.

Sidecars record their source and presentation-pipeline fingerprints, including engine version and referenced generators, shaders and assets. Validation hashes run off the main thread and are reused within a session. Missing, old or stale full bakes stop with an offline-rebake message; normal play never silently regenerates them. Re-bake after changing the Act or its presentation dependencies. Source Acts remain unchanged. The explicit developer `--no-bakes` flag still exercises the construction fallback.

**Bake Endless.cmd** bakes the three trial snapshots; it is an authoring operation, not a session loading screen. Editor **Bake** saves beside the selected document and does not publish it into the fixed pool. Updating `data/acts/` does not update its snapshot in `data/endless/`. A larger catalogue needs an explicit pool/publish workflow and connector verification.

This guarantee applies to the source-project editor's Endless bake pipeline. Standalone Act play and editor previews retain their dynamic construction path. The portable Act Editor exporter currently excludes bake folders, and its shared `res://` output paths need separate writable-location and packaging work. A production Endless package must include fresh sidecars and shared assets; that packaging workflow is not implemented here. Derived bake folders remain ignored by Git.

## Runtime preparation and bounds

Startup prepares only the first **two** Act/theme variants and opening background. During play, the library prioritizes the rest of the current Zone and then the next Zone. Only one graphics preparation request runs at a time. Next-theme disk reads and validation can overlap current-Act preparation without loading another Act. The library retains at most eight visual recipes and three themes, with active entries pinned; resident Acts use bounded lookahead.

Theme-only preparation loads saved scenery, lighting and probes without opening an Act sidecar or compiling its physics. Tiny probes upload textures and exercise ordinary and instanced material paths. Actual Act meshes still need later preparation. Known graphics features can submit up to 32 geometry instances per frame during play, or 64 during startup; a new feature ends the batch early. Foreground and background feature knowledge stay separate.

The nodes warmed for an Act are retained and attached incrementally to its live visual root. Their identities, local transforms, resources and animation indices survive the handoff. Original visibility, rendering-layer masks and cull margins are restored before attachment; the root stays inactive until ready. Warm-up isolates batches with rendering-layer masks instead of hiding mesh parents, so nested geometry and geometry under authored hidden groups are actually submitted. This removes the previous second construction of the Act's visuals. Backgrounds and probe scenes retain their existing warm-up/lifetime path. Old live trees are freed incrementally.

Evicted baked resource graphs enter a retirement queue with at most four pending graphs. Saved dependency lists allow owners and dependencies to be released separately without mutating shared resources. Each process slice requests at most 64 steps and a **500 microsecond cooperative budget**. This is not a hard deadline: one resource destruction or driver call can exceed it. A full queue defers eviction rather than dropping resources synchronously.

Disk decoding, live Node/physics instances and bindings, GPU uploads and machine-specific shader preparation remain runtime work. Warm live nodes and graphics handles are session state, not portable disk assets. Terrain collision decomposition is baked, but physics compilation still reconstructs descriptors and rail paths and validates clearance. Physics-template eviction also frees its root synchronously above eight unique cached Acts; the three-Act trial does not exercise that future large-catalogue cost. Invalid-bake teardown can still release resources synchronously.

If the camera or ball outruns preparation, physics pauses safely before the unavailable entrance while the course remains visible. Compatibility/ANGLE can also stall during first-use uploads and shader/driver work. Driver caches are machine-specific, and Godot's export shader baker does not support Compatibility ([official documentation](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html)). These changes do not guarantee hitch-free cold loading.

## Low-poly geometry and static batches

Visual baking simplifies terrain, floor and rail contours within a **0.35 local-pixel error**. It preserves endpoints and turns of at least 25 degrees, rejects crossings and retains unsafe/self-touching input unchanged. Wall caps and trim share the reduced outline. Round primitive limits are 16 radial segments, sphere 7 rings, cylinder 1 ring, capsule 4 rings and torus 20 by 8; lower-detail props remain unchanged. Authored collision contours retain their exact samples.

Eligible repeated meshes share spatial batches by exact material/render state and a 2-world-unit cell: at least three instances, at most 64 instances and 8,192 triangles per batch. Animated/referenced descendants, gameplay visuals, transparent/billboarded or skinned meshes, custom instance parameters and unsupported per-node shaders remain separate. Empty unbound transform nodes are removed and bindings remapped. The version-4 trial bake grouped 4,094 repeated meshes into 609 batches and reduced scene records about 21%; these are pool-specific measurements.

Simple border rings use two triangles per edge; holes, split/collapsed insets, intersections, non-convex strips and reversed texture-travel contours use the existing builder. The J-rail wall/cap fixture fell from 969 to 310 triangles after contour reduction, then to **98 triangles** with simpler trim. This is a fixture result, not a whole-Act reduction claim. The 0.35-pixel tolerance and physics remain unchanged.

Both new batches and native theme instances save explicit CPU transform buffers. This avoids losing renderer-side MultiMesh transforms during headless baking and preserves native instance order for animated snow/ember shaders. Unsupported color/custom-data formats fail the bake. See the [RenderingServer buffer layout](https://docs.godotengine.org/en/4.4/classes/class_renderingserver.html#class-renderingserver-method-multimesh-set-buffer).

## Fast-tour diagnostics

The workload is seed 18, continuous **400 px/s** camera travel through sequence 24 and all eight themes, using Godot 4.7.2 Compatibility/ANGLE with N64-ish + VHS + CRT. Readiness pauses and individual long frames are different measurements. The earlier detailed baseline recorded 4.829 seconds of readiness pauses, a 169.42 ms maximum frame and 55.23 ms p99.

The baseline's completed gameplay preparation stages accumulated **18.625 s** in graphics warm-up, **7.035 s** creating temporary warm-up scenes, **2.397 s** retiring them and **1.917 s** waiting for resource readiness. These are elapsed asynchronous durations, including frame/scheduling waits, not pure GPU time or disk I/O; they are not percentages of frame time. Baseline draw calls were **2,450 median**, **4,193 p95** and **5,274 maximum**, so steady rendering workload remains relevant alongside loading overhead.

The final version-5 profile includes the nested-geometry warm-up visibility correction. Driver/resource caches and run-to-run variation prevent treating the comparison as a controlled cold-driver benchmark.

| Gameplay CPU work | Earlier detailed baseline | Final version 5 |
| --- | ---: | ---: |
| Graphics submission, total | 4,190.61 ms | 80.135 ms |
| Material-signature inspection, included above | 4,078.96 ms | No runtime inspection entry |
| Live visual attachment/construction, total | 317.21 ms | 129.040 ms |
| Cache eviction, largest call | 78.23 ms | 0.158 ms |
| Resource retirement, largest slice | Not separately staged | 5.991 ms |

The run reused **15,027 warmed visual nodes**, completed **24** retirement jobs and reached the bounded peak of **four** pending graphs. Material reflection moved offline. Graphics submission's largest call was 4.111 ms; live visual attachment's largest step was 0.632 ms. Cache eviction totaled 2.247 ms, while gradual retirement totaled 378.175 ms. Retirement can still exceed its requested slice budget, as the 5.991 ms maximum demonstrates. Nested counters must not be added together; elapsed warm-up includes frame/graphics waits rather than pure CPU or GPU execution.

| Continuous fast tour | Gameplay duration | Entrance waits | Maximum frame | p99 frame |
| --- | ---: | ---: | ---: | ---: |
| Earlier detailed baseline | 41.10 s | 4,829 ms | 169.42 ms | 55.23 ms |
| Final version 5 | 37.013 s | 199.493 ms | 304.530 ms | 47.855 ms |

Final startup used 1.206 s of synchronous initialization followed by 5.478 s of opening preparation. All requested variants loaded from disk, with **zero runtime rebakes**. The strict profiler exited with code 1 because of the measured entrance wait; this was a performance-criterion failure, not a script error.

Preparation CPU costs fell, but large frames remain and the worst frame exceeded the earlier detailed baseline. The 304.530 ms frame contained a 302.059 ms measured render interval and only 0.536 ms of streaming build work; the next-largest frame was 294.413 ms, with 289.997 ms in the render interval and 0.033 ms of build work. Graphics-side stalls remain unresolved. Compatibility GPU timestamps were unavailable, so those intervals do not separate GPU execution, uploads, driver compilation and synchronization. Next priorities are a controlled graphics/backend capture and moving invariant physics preparation offline before expanding toward 50 Acts. Do not increase startup loading to hide preparation costs.

## Verification and reproduction

Version-5 verification passed: warm manifests **30**, resource retirement **49**, visual reuse and nested-geometry warm-up **127** in both headless and rendered runs, cache/warm-up **28**, geometry/collision serialization **1,001**, and authored physics equivalence **56** assertions. All 24 local Act/theme bakes passed their fingerprint audit. An isolated intended checkout passed manifests, retirement, reuse and cache checks plus **35** explicit-fallback smoke checks. A rendered 27-transition smoke passed **253** checks. A small ObjectDB exit warning remains in long runs (two to three instances observed). The earlier composed spinner/magnet/rail mechanics fixture failure is not claimed fixed.

Useful focused checks:

- `tests/endless_manifest_regression.gd`: persisted render signatures and probe metadata.
- `tests/endless_retirement_regression.gd`: bounded gradual release and shared-resource ownership.
- `tests/endless_reuse_regression.gd`: retained identities, transforms, visibility/culling, animation bindings and interrupted-build cleanup.
- `tests/endless_cache_regression.gd`, `tests/geometry_bake_regression.gd`: serialized assets and collision equality.
- `tests/endless_scene_smoke.gd`: startup scope, readiness protection, bounded caches, theme-only preloading, blending and checkpoints. `--captures` saves images; `--require-bakes` rejects fallback; `--transitions=3` shortens the run.
- `tests/endless_regression.gd`, `tests/endless_detail_regression.gd`, `tests/endless_batch_regression.gd`, `tests/endless_border_regression.gd`: ordering/seams and offline geometry safeguards.

For an interactive timing run, use `Play Endless.cmd -Seed 18 -Tour -FrameTiming`. For the automated trace, run the local Godot console executable with:

```text
--path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --script res://tests/endless_stream_profile.gd -- --profile-stages --profile-speed=400 --profile-target=24 --profile-output=res://test-results/endless-fast-diagnostics.json
```

The JSON contains frame samples, timestamped stage events, synchronous CPU count/total/max counters, and separate startup/gameplay measurements. Resource waits measure elapsed readiness, not pure disk I/O. Stage labels identify concurrent work, not proven causation. The profiler exits nonzero if any entrance wait occurs; that is a performance-criterion failure, not necessarily a script error.

Manual review remains necessary for pinball traversal/flipper timing, connector readability, scenery/lighting through the blend and first-use performance. Unlimited-duration coordinate rebasing and production packaging remain future work.
