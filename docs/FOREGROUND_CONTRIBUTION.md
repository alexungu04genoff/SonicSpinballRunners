# Resident foreground contribution

Implemented against `e0691e70a1e22499866ddb5262aafbc88ed0eeab`, with the existing local artwork and authored Acts preserved. This is a presentation policy, not a streaming or physics change.

## Ownership audit

`endless_game.gd` owns the resident list, incremental builder, active sequence, retirement queue, shared presenter and Zone backdrops. Prototype's `zone_run.gd` extends it. The opening prepares two Acts, then the normal lookahead prepares additional Acts; neither the count nor retirement distance changes here.

Each `streamed_act.gd` instance owns separate roots:

| Owner | Contents | Policy |
| --- | --- | --- |
| `root`, a Node2D under the physics world | Terrain bodies, authored object bodies, flippers, mechanic manager and runtime dictionaries | Unchanged, including processing, collision masks, scoring eligibility and readiness |
| `visual`, a Node3D under the foreground presenter | Recipe terrain, hardware, Rings, foreground authored Decor and bound mechanic animations | Only this parent's `visible` flag changes |
| `background_visual`, under its Zone backdrop | Recipe records marked as local scenery/background | Unchanged |
| Shared presenter | Production camera, directional light, ball visual and global visual bindings | Unchanged |
| Prototype/shared presentation siblings | Character, transfer proxy, Goal Rings, exit warnings, score effects and overlays | Remain outside the gated root |

Previously, attachment phase 3 set `visual.visible = true`. Nothing subsequently tested camera or light contribution. `_sync_resident()` registered every resident's Rings, flippers, bumpers and mechanic bindings; only `_queue_retirement()` hid the root. Godot still performed its normal per-instance camera culling, but off-camera residents remained eligible for directional shadow passes. Residency therefore implied render eligibility until retirement.

Source construction and disk recipes converge on the same `StreamedAct` attachment path. The cache does not modify recipes, resources, authored dimensions or bake fingerprints. Capturing hidden descendants is intentional: destroyed/respawning enemies, collected Rings, retracted flippers and stateful hardware can change their own visibility later.

`zone_backdrop.gd.follow()` already disables rendering and processing when a layer has zero weight and is not warming. The existing crossfade keeps the underlying layer at weight 1 while the next layer blends in; completion disables the previous layer. Backdrop lights remain shadowless. This policy does not write any background property.

## Contribution rule

An Act contributes if any of the following applies:

1. The diagnostic selects legacy rendering.
2. It is the active Act.
3. Startup, boundary loading, Ring pickup flight, Prototype draft/pending activation or spawn transfer requires a safety hold. Newly ready Acts also receive two process frames of grace.
4. Any resident has unsupported/unbounded presentation: all residents remain visible because unknown geometry could also be a shadow receiver.
5. Its expanded cached presentation AABB intersects the current camera frustum.
6. Its possible directional-shadow volume intersects that frustum.

Otherwise, hide only `act.visual`. Child visibility, processing and runtime bindings are retained. Returning to a relevant view restores the parent, revealing the current child states. Retirement uses the existing hide/disable/free path; a reused recipe receives a fresh visible root and a fresh cache.

The policy executes from `RenderingServer.frame_pre_draw`, after camera movement, viewport resize, animation and atmosphere/light updates. It also runs during paused overview navigation. It reads `Camera3D.get_frustum()` rather than inferring a fixed screen rectangle. Perspective/orthographic projection, zoom, horizontal following, vertical framing/look-ahead, overview pan and actual viewport aspect therefore use the production camera's final pose.

## Cached bounds and shadows

One attachment-time traversal unions transformed mesh/MultiMesh/Label bounds, custom AABBs and culling margins. Separate animation envelopes cover full flipper and Ring rotation, bumper scaling, spinner rotation, Spring/switch movement, Slingshot expansion, Flicky motion and Buzz rotation/death scaling plus its complete **horizontal** patrol. Elevated rails and distant Teleporter endpoints are measured from their actual meshes. No old flipper length, terrain rectangle or rail height is assumed.

An extra 0.25 world units (25 table pixels) provides presentation/filtering tolerance. Unknown geometry, native animation, top-level transforms, lights/probes/decals, billboard/grow materials and detected vertex-deforming shaders fail open. Shader includes are inspected and identical shader checks are cached during attachment. In particular, deforming Rooftop grass shells can retain an Act; this pass does not rewrite that artwork to earn a culling win.

For directional shadows:

- Read the final sunlight direction from `-light.global_basis.z`.
- Use the lowest cached resident bound, with a shared-presentation floor of at most -1 world unit, as a conservative receiver floor.
- Project each of the eight bound corners along the light ray to that floor. Test the convex volume formed by the original corners and projected corners against the camera's planes. This avoids inventing shadow receivers below the floor or high floating receivers at the far end of a ray.
- Expand for the light's full angular distance and a conservative shadow-texel/bias guard based on camera depth/size/aspect, device atlas resolution and light bias. Horizon/upward or near-horizontal cone directions fail open.
- **Do not truncate caster rays by `directional_shadow_max_distance`.** That setting limits camera-depth shadow coverage, not caster-to-receiver distance. The test deliberately keeps the complete camera frustum and uses shadow distance only to enlarge the bias guard. It does not depend on the selected cascade count.

This is conservative geometric rejection, not occlusion culling. A hidden-by-terrain neighbor can remain enabled because its aggregate bounds or shadow volume intersects view. Low sun, wide overview, joins and transfers deliberately reduce or eliminate savings. There are no per-object runtime contribution decisions.

Per update: obtain six camera planes, determine the resident receiver floor, then perform a few box/plane and corner/plane tests per resident. Only changed root visibility is assigned. No per-frame scene walk, mesh inspection, recipe rebuild, collision edit or animation suspension is introduced.

## Reproduction

Use `--foreground-contribution=legacy` or `--foreground-contribution=conservative` after Godot's `--` separator. Conservative is the default. This is a development argument, not a player graphics setting.

The existing `tests/render_cost_profile.gd` now supports:

```text
--profile-contribution
--profile-views=opening,boundary,forward,backward,overview,transition,long-shadow
--profile-samples=600
--profile-output=res://test-results/foreground-contribution/example.json
--profile-act=res://data/endless/third_complex.tres
--profile-capture-only
--profile-cascades=1
```

Omit `--profile-act` for the three-Act Prototype workload. Use `--seed=18` or `--seed=1` for repeatable orders. `--no-bakes` explicitly selects source construction; otherwise the probe requires current disk bakes. The Second Simple/Third Complex fixtures are loaded through single-Act Prototype for scaling diagnostics; they are not promoted into the production Act pool.

Each view measures legacy, conservative and a legacy return. Timing uses a stationary served Ball and a held production camera, with runtime mechanics running. The shared presenter process is held for the fixed camera; this is a render-cost probe, not a full gameplay frame benchmark. Screenshots separately pause simulation and set `Engine.time_scale = 0`, then compare complete image buffers. Godot's shader `TIME` follows time scale but not SceneTree pause ([engine documentation](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html#global-built-ins)). Timing excludes screenshots, image comparison and startup/warmup.

## Evidence and limits

Measured on 2026-11-05: Godot 4.7.2, Forward+/Vulkan, RTX 4060, 1280×900 window, existing 673×473 world viewport, 120 Hz physics, VSync disabled, 4× MSAA, 8192 atlas, four cascades, angular distance 0 and Ultra/FXAA off. Quality remains identical within every A/B/A sequence. Separate unsaved one-/two-cascade captures check correctness, not performance attribution. Each timed block contains 600 frames after 120 settling frames; startup and screenshot processing are excluded.

Raw final evidence: `measured-small.json`, `measured-large.json`, `measured-multi.json`, `measured-seed1.json`, `cascade1.json` and `cascade2.json`, under `test-results/foreground-contribution/`. Counts below are rendering-server totals across active viewports, including shadow submissions. Cells show **legacy → conservative**.

| Workload/view | Draws | Objects | Primitives | Resident Acts | Foreground roots |
| --- | ---: | ---: | ---: | ---: | ---: |
| Small: Second Simple | 205 → 205 | 330 → 330 | 52,138 → 52,138 | 1 | 1 → 1 |
| Large: Third Complex | 887 → 887 | 1,201 → 1,201 | 106,873 → 106,873 | 1 | 1 → 1 |
| Prototype opening, seed 18 | 1,960 → 1,830 | 2,823 → 2,537 | 229,098 → 200,350 | 3 | 3 → 2 |
| Prototype opening, seed 1 | 1,838 → 1,462 | 2,701 → 2,170 | 226,697 → 187,098 | 3 | 3 → 2 |
| Boundary | 2,723 → 2,723 | 4,086 → 4,086 | 326,043 → 326,043 | 3 | 3 → 3 |
| Forward | 2,739 → 2,739 | 4,091 → 4,091 | 319,857 → 319,857 | 3 | 3 → 3 |
| Backward | 2,711 → 2,711 | 4,015 → 4,015 | 321,832 → 321,824 | 3 | 3 → 3 |
| Overview | 2,484 → 2,484 | 3,593 → 3,593 | 280,630 → 280,630 | 3 | 3 → 3 |
| Actual transfer, held at midpoint | 2,490 → 2,490 | 3,670 → 3,671 | 296,926 → 296,938 | 3 | 3 → 3 |
| Low sun, pitch -12° | 1,485 → 1,486 | 2,139 → 2,140 | 188,324 → 188,336 | 3 | 3 → 3 |

Minor count changes while all three roots remain enabled come from ordinary animated/stateful presentation; their frozen image comparisons are identical. Root counts exclude shared Goal/character/effect siblings and independent scenery viewports, which stay enabled by their existing policies.

All timing values are milliseconds. GPU values are sums of active viewport render timers, not end-to-end GPU frame latency; Vulkan reports consistent nonzero values here, but they do not explain desktop scheduling or presentation delays.

| Workload/view | Render CPU | Render GPU | Frame median | p95 | p99 | Legacy-return median |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Small | 0.689 → 0.728 | 0.635 → 0.634 | 2.407 → 2.642 | 3.513 → 4.881 | 3.860 → 6.633 | 2.730 |
| Large | 1.370 → 1.441 | 0.830 → 0.830 | 3.807 → 3.964 | 5.213 → 6.404 | 5.976 → 7.768 | 3.677 |
| Opening, seed 18 | 2.710 → 2.390 | 0.845 → 0.835 | 6.974 → 6.185 | 11.106 → 10.003 | 13.863 → 11.089 | 6.974 |
| Opening, seed 1 | 2.335 → 1.967 | 0.832 → 0.825 | 5.813 → 5.230 | 7.820 → 6.457 | 10.496 → 8.759 | 5.861 |
| Boundary | 2.906 → 2.902 | 0.895 → 0.895 | 6.565 → 6.543 | 7.888 → 7.903 | 9.917 → 10.104 | 6.512 |
| Forward | 2.954 → 2.864 | 0.892 → 0.891 | 6.683 → 6.424 | 10.461 → 7.246 | 13.287 → 9.527 | 6.446 |
| Backward | 2.856 → 2.854 | 0.900 → 0.900 | 6.458 → 6.500 | 7.224 → 7.972 | 9.816 → 11.332 | 6.424 |
| Overview | 3.569 → 3.712 | 0.688 → 0.688 | 7.683 → 8.040 | 8.893 → 14.225 | 12.126 → 16.553 | 8.227 |
| Transfer | 2.695 → 2.725 | 0.902 → 0.902 | 5.998 → 6.073 | 6.707 → 7.304 | 8.326 → 8.830 | 6.060 |
| Low sun | 1.993 → 1.991 | 0.874 → 0.875 | 5.197 → 5.232 | 6.152 → 6.973 | 7.640 → 8.571 | 5.192 |

The opening courses reduce submissions by **6.6%** and **20.5%**, with roughly **10–11% lower frame medians in the final run**. Earlier short samples showed a smaller seed-18 timing benefit, so the submission reduction is firmer evidence than a universal frame-rate promise. Single-Act and fully contributing controls show no submission benefit, and their timing variation must not be attributed to successful culling. This does not solve within-Act scaling or shader warmup.

For the final three-Act probe, cache construction took **4.9–8.0 ms once per attachment**. The complete conservative update measured approximately **0.039–0.069 ms median**, compared with **0.025–0.032 ms** for legacy restoration/bookkeeping. No geometry walk runs per frame. The one-time cache is extra attachment work; this pass does not claim to eliminate loading hitches.

### Visual verification

All **16 final image pairs are byte-identical**: seven seed-18 views, the seed-1 opening, both single-Act controls, and opening/transfer/low-sun views under both one and two cascades. Each pair compares all 3,456,000 RGB channels of the 1280×900 capture. The ordinary run uses four cascades. Representative full-size opening, boundary, overview, transfer and long-shadow images were also inspected. No geometry or shadow discrepancy was accepted.

The transfer fixture calls the real `_start_transfer()` and holds the real proxy at its midpoint; it is not a timer placeholder. This is a still-frame correctness check, not a completed human traversal session. The low-sun capture contains tall foreground posts/scenery; a separate deterministic test proves that an off-camera tall caster remains enabled when its shadow reaches view.

### Checks actually run

- Contribution regression: **26/26** on source construction and **26/26** on disk bakes. Covers visible/irrelevant bounds, off-camera shadows, horizon fallback, zoom, long flipper sweep, elevated/distant meshes, unknown deformation, active/adjacent/overview/transfer safety, unchanged runtime identities/collision masks/score, background state, reactivation, recipe reuse and retirement.
- Profile/modifier regression: **0 failures**. Prototype planning: **41/41**. Buddy scoring: **70/70**. Real Prototype Act Play/restart/Goal/archive: **12/12**. Resource retirement: **72/72**.
- Traversal authoring: **33/34**; the sole failure is `Diagnostic round trip is exact`, because the existing local `Traversal Diagnostic.tres` differs from the test's generated fixed fixture. Reproduced that comparison using the pre-pass source snapshot against the preserved local Act. Physical rail/Teleporter/contact checks passed. The source Act was not rewritten to satisfy the fixture.
- Existing reuse suite: **125/127**, identically before and after. Its `StreamingHost` stub lacks `backgrounds`; completed-attachment/activation assertions consequently fail. The pre-pass `source-20261105-185543` snapshot reproduces the same errors. New real-Prototype reuse/retirement checks pass; the old suite was not weakened.
- Disk profile/regression probes emit one `RefCounted` shutdown leak warning. An isolated copy using `e0691e7`'s original runtime and profiler, with the same current art and bakes, reproduces that warning without script/engine errors. Source contribution and exported smoke runs are clean. This remains pre-existing shutdown cleanup debt, not a passing assertion or a new culling result.
- Headless editor import and both portable exports complete without script/engine errors. The actual portable release executable passes legacy/conservative three-Act checks; the conservative release also runs under Forward+/Vulkan.

The portable artifact is `test-results/authoring-tools/Sonic Spinball Authoring Tools-20261105-223004.zip`. It includes the existing local artwork and Acts without committing them. The runtime contribution source in its build snapshot matches the repository source byte-for-byte.

World MSAA remains 4×. Renderer choice, resolution policy, shadow defaults, cascade defaults, softness, Ultra/FXAA and atmosphere remain unchanged. MSAA is a separate future quality knob. These RTX 4060 results are not work-laptop FPS predictions, and a single dense active Act cannot benefit from whole-Act suppression.

## Portable comparison

The refreshed authoring-tools ZIP includes `Compare Prototype legacy.cmd` and `Compare Prototype conservative.cmd`. Both launch the actual Prototype menu with seed 18 and Green Hill Default; choose identical Act pools and settings. They use source construction because the portable authoring package excludes disk recipes. Repository Prototype still uses validated disk bakes. See [portable instructions](PORTABLE_AUTHORING_TOOLS.md#foreground-performance-comparison).

Human follow-up remains: laptop timings at identical device settings, normal traversal and flipper feel, rapid camera movement across joins, and custom low-sun/soft-shadow atmospheres. Correctness takes precedence over keeping only one foreground Act enabled.
