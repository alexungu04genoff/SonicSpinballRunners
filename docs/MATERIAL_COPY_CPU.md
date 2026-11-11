# Direct private-material conversion — 2026-11-11

Atmosphere binding used to duplicate an editable StandardMaterial3D and then
convert that temporary duplicate into a new ShaderMaterial when its surface
used a texture or vertex colors. Conversion now creates the private shader
material directly from the source. Flat materials still receive their required
private duplicate; protected/shared materials and emission-only copies retain
their existing rules.

The converter reads surface properties, copies metadata and remaps palette
bindings. Atmosphere-only foliage, trim and scenery tags are applied afterward.
Shader code, textures, next-pass ownership, metadata sharing, emission values,
slot restoration and appearance remain equivalent to the old path. No shader
generator or bake dependency changes, so current version-9 bakes remain valid.

## Measured scope

This is a small allocation cleanup. The eight RampMania fixtures eliminate five
temporary native materials in Green Hill and one each in Casino and Ice. The
other five fixtures have no eligible standard-material conversions.

Headless Godot 4.7.2 comparisons alternate legacy / direct / direct / legacy:

| Measurement | Legacy mean | Direct mean | Interpretation |
| --- | --- | --- | --- |
| One actual Green Hill converted material, 1,000 samples per trial | 0.448 ms | 0.314 ms | About 30% less conversion work |
| Whole Green Hill foreground + scenery attachment, 150 samples per trial | 23.94 ms | 23.18 ms | About 3%; individual trial distributions overlap |

The first measurement includes `_copy` and palette registration, with warmed
programs; the second includes both `Runtime.attach` calls. Restore, loading and
node construction are outside the samples. Results average the two trial means
per path. They do not establish an FPS gain or a broad startup improvement.

Four fresh-process three-Act Green Hill profiles prepared all three Acts with
zero fallback. Their foreground maxima varied substantially: 107.6/51.4 ms
legacy and 62.8/83.2 ms direct. Both 60 FPS, 400 px/s seed-18 tours reached
sequence 3 without boundary waiting or rebuilds. Whole scheduler maxima were
73.2 ms legacy and 53.1 ms direct in those individual tours; this small sample
is not a reliable frame-time speedup claim.

The cold shader audit found the existing adapter cache already reuses prepared
programs. In one sequential Green Hill / Rooftop / Chemical probe, only 4/4/1
of 23/32/18 prepare calls created a program. Those new-program calls totaled
9.7/10.2/6.6 ms, while reuse/already-prepared calls totaled 0.7/1.1/0.6 ms.
The probe times `surface_controls.prepare`, including its first native Shader
creation, in the headless renderer. It does not measure Windows driver
compilation. No additional warm-up stages or shader cache policy were added.

The [receipt](material-copy-cpu/receipt.json) retains the timings, source/bake
hashes, complete cold-probe source, conversion counts and validation results.

## Reproduction and checks

```sh
godot --headless --path . --script tools/profile_material_collection.gd -- \
  --compare-material-copies --themes=green_hill --iterations=150 \
  --output=res://test-results/copy-whole.json
godot --headless --path . --script tools/profile_material_collection.gd -- \
  --conversion-only --themes=green_hill --iterations=1000 \
  --output=res://test-results/copy-single.json
godot --headless --path . --script tools/profile_act_attachment.gd -- \
  --profile-stages --theme=green_hill --profile-redundant-material-copies \
  --output=res://test-results/copy-live-legacy.json
```

Omit `--profile-redundant-material-copies` for the direct-conversion control;
the same flag works with `tests/stream_material_tour.gd`. The paired profiler
sets both modes explicitly and keeps uniform inspection caching enabled for
copy comparisons. Current disk bakes are required; stale recipes are rejected.

The material regression compares full stored material/program state and live
edits across all eight themes. Dedicated cases cover flat, textured,
vertex-colored, scenery, protected, shared and emission-only materials, plus
source properties, metadata identity and next-pass ownership. Existing streaming,
retirement, retry, rail, contribution and appearance-authority checks cover
integration. Windows rendering/frame-time validation remains the next useful
evidence for larger graphics changes.

The final 14-case suite passes 697 assertions with no script or engine errors,
including 112 material checks and all eight RampMania appearance-authority
fixtures. The matching Godot editor import also completes cleanly.
