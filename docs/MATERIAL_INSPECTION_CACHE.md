# Shared shader inspection — 2026-11-11

Foreground atmosphere attachment was repeatedly asking Godot for the complete
uniform list of the same shader, then walking that list for each private
material. Emission/halo collection and fake-light registration only need six
possible control names.

Material bindings now inspect each Shader once per synchronous `append_root`,
retain those control descriptors in their original order, and reuse them for
that attachment. Per-material values and defaults are still read from each
original material. Private copies, palette application, shader source, material
slot restoration and operation ordering stay current.

The cache clears at attachment entry and exit, and on restoration. A later root
therefore sees live shader/include edits; it does not retain extra Shader
resources or need change-signal subscriptions. It adds no scheduler stages or
lookahead. Current version-9 bakes remain valid.

## Evidence

The eight-theme RampMania comparison reduces explicit uniform-list queries from
367 to 90 (75.5%). All stored material properties, shader code, uniforms, palette
bases and binding coverage match the uncached path. Live hue, emission, halo and
sun edits also match; a shared Shader edited between attachments exposes its
new emission uniform correctly.

Warm headless Godot 4.7.2 comparisons use real disk-loaded RampMania materials,
five warm-up iterations, then 150 attachments in each of four trials ordered
uncached / cached / cached / uncached. Each timed sample includes foreground
and local scenery `Runtime.attach`; loading, node creation and restoration are
outside the measurement. The following values average the two trial means:

| Theme | Uncached | Cached | Change |
| --- | --- | --- | --- |
| Green Hill | 27.25 ms | 24.30 ms | −10.8% |
| Rooftop | 19.53 ms | 15.14 ms | −22.5% |
| Chemical | 17.48 ms | 16.66 ms | −4.7% |

Individual trial ranges overlap, especially Green Hill and Chemical. These are
elapsed method measurements in a warm fixture, not a Windows FPS or cold-start
promise. The [receipt](material-inspection-cache/receipt.json) keeps all trial
aggregates, source/bake hashes, native-query counts and integration results.

Eight fresh-process three-Act Prototype profiles (four per theme for Green Hill
and Rooftop) all prepared three Acts with zero rebuilds. Foreground maxima still
overlap between paths: 46.9–52.3 vs 46.6–50.1 ms in Green Hill, and 24.6–36.8 vs
23.1–30.2 ms in Rooftop. Large native creation/duplication and bounds operations
remain. The 60 FPS, 400 px/s seed-18 Green Hill tours both reached sequence 3
with zero boundary waiting and zero rebuilds; maximum whole scheduler work was
73.8 ms uncached and 78.1 ms cached. This does not establish an improvement in
worst-frame timing.

Two earlier cached integration attempts logged dummy-renderer mesh/RID cleanup
errors; the same mesh signature is present in a pre-change rail-stream log.
Those attempts are retained as excluded runs, and the repeated eight profiles
and both tours completed without engine errors. The dummy-renderer issue and
the existing threaded-loader ObjectDB leak are not fixed by this optimization.
See [the lifecycle audit](LIFECYCLE_AUDIT.md). Windows motion/frame review remains
pending; no new GPU program or rendered appearance change is claimed.

## Reproduction

Use matching Godot 4.7.2 and current normal disk bakes. Run comparisons
sequentially with other heavy work idle:

```sh
godot --headless --path . --script tools/profile_material_collection.gd -- \
  --iterations=150 --themes=green_hill,rooftop_run,chemical_plant \
  --output=res://test-results/material-collection-cpu.json
godot --headless --path . --script tools/profile_act_attachment.gd -- \
  --profile-stages --theme=rooftop_run \
  --output=res://test-results/material-live-cached.json
godot --headless --path . --script tools/profile_act_attachment.gd -- \
  --profile-stages --theme=rooftop_run --profile-uncached-materials \
  --output=res://test-results/material-live-uncached.json
godot --headless --path . --script tests/stream_material_tour.gd -- \
  --profile-stages --seed=18
```

`--profile-uncached-materials` is an unsaved control that restores the full native
queries and scans. The paired warm profiler sets each mode explicitly. Shader
code and bakes are shared between both paths. The profiler validates Act/scenery
freshness instead of generating fallback geometry.

`tests/stream_material_regression.gd` owns the eight-theme material-state,
control-coverage, edit, cache-release and restoration checks. Existing reuse,
manifest, retirement, color ranges, foreground contribution, rail Rings, enemy,
retry, HUD, scene smoke and eight-theme RampMania appearance authority checks
cover integration. Renderer-only pixel tests remain outside this headless pass.
The final 14-case suite passes 676 assertions without script or engine errors,
including 91 material-state/cache checks and 70 appearance-authority checks.
