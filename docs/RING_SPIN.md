# Shared Ring spin — 2026-11-11

Prototype and Endless now rotate ordinary Rings in a shared vertex shader. Each
resident material receives one rotation basis per frame. Resting Ring nodes keep
their CPU transforms; collection updates only the individual pickup flights.
Reset and rack signals restore visibility and positions when their state changes.
The standalone editor/Visual Lab presentation keeps its existing CPU path.

Fresh Green Hill Prototype recipes contain 20–82 Rings per Act, with one shared
spin material each (205 Rings across five sources). Each Act replaces that many
resting CPU rotation writes and visibility checks with one basis update. This
inventory describes the removed work, not a measured frame-time percentage.

This preserves Forward+'s automatic instancing and individual frustum/shadow
culling. An initial small-MultiMesh experiment was rejected: in the 35-Ring
Forward+ fixture, the original automatically instanced draw used two submissions
while two manual batches used four. Shared shader rotation retains two. The
optimization therefore targets CPU animation work, without adding manual batches
or promising fewer Forward+ draw calls.

The conversion copies the current opaque Standard surface's color, roughness,
metallic, specular and emission. It preserves atmosphere emission adjustment.
Textures, alpha, extra passes, material metadata and other unsupported features
retain the original material and CPU rotation. All eight current theme gold
materials qualify. Pickup movement, spin phase, final shrink, pause behavior,
rail height, scoring, 120 Hz physics and streamed ownership remain unchanged.

The exact vertex program has a finite CPU envelope: a sphere around the actual
mesh's eight AABB corners covers every rotation angle. The same envelope reaches
Godot's native mesh culler and the cached foreground-contribution bounds. Unknown
vertex programs and unsupported geometry still fail open. The shader material
and original Standard material are saved through the ordinary recipe/asset path;
the existing warm probes cover their rendering features.

## Verification

Matching Godot 4.7.2 headless checks cover disk serialization, warm signatures,
material sharing, unchanged resting transforms, rail-height bounds, atomic claims,
pickup movement and completion, reset, re-registration, legacy fallback and
unknown-geometry handling. Existing Ring, rack, rail, static batching, manifest
and warmed-node reuse suites also pass. The manifest fixture now compares against
`GeometryBake.VERSION` instead of its stale literal version 6. The streamed rail
fixture uses distinct published Acts with a fixed seed, matching current planner
validation; it verifies real rail pickup completion and reset signals.

Final-code offline bakes completed for all five Prototype and seven Endless
variants in Green Hill and Rooftop, plus RampMania in the other six themes
(30 variants). The canonical disk authority/freshness check passes 70 checks
across all eight RampMania themes, with no runtime rebuilds. Green Hill and
Rooftop contribution checks pass 36 each; the real streamed rail check passes 10.

Rendered checks use Linux software Vulkan/llvmpipe, Forward+, 4× MSAA and 35 Rings
at three phases for each of eight theme gold materials. All 24 pairs retain two
draw submissions and pass the pixel comparison; normalized mean differences are
below 0.00003, including subpixel edge differences. This confirms shader behavior
and instancing on that renderer. It is not Windows GPU timing or a universal FPS
claim. Captures stay in ignored `test-results/`.

A full canonical Prototype capture on software Vulkan exceeded the fixture's
180-second startup deadline and did not pass. Headless canonical disk authority
checks pass; full Windows motion/Retro review and hardware timing remain pending.

```sh
godot --headless --path . --script tests/ring_spin_regression.gd
godot --path . --rendering-method forward_plus --rendering-driver vulkan \
  --script tests/ring_spin_regression.gd -- --capture
```

Bake version 9 rejects earlier recipes. After pulling, use **Bake Prototype** and
**Bake Endless** for the desired themes before normal play. Their shared pipeline
fingerprints include the new shader and conversion code; normal play keeps the
existing stale-bake rejection.

For a Windows comparison, use the existing profiler with normal fresh bakes and
repeat the same command with `--ring-spin=legacy` appended after `--`. This unsaved
diagnostic restores original Standard materials and per-Ring CPU spin from the
same recipes. Compare CPU/frame tails and pickup motion as well as draw counts;
the retained automatic instancing means lower draw counts are not expected.
