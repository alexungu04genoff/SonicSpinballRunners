# Retro AO Lab

**Production follow-up, November 20.** Authored terrain faces are now baked into regular Prototype and Endless play. The isolated Lab still starts with AO off for its comparisons. [Production captures and settings](TERRAIN_FACE_SHADING.md)

This review compares ambient depth cues under the complete N64-ish, VHS and CRT presentation. The primary control is ordinary Godot shading with native directional shadows. The Lab opens with ambient occlusion off. It lives in its own scene and has no production entry point. The starting revision was `536b112269ff708a78d6b17ec07c2a1fbdd64587` on `main`.

## Run the review

1. Extract the entire Windows package to a writable folder and double-click **Retro AO Lab.cmd**. The same launcher works in a source checkout with Godot 4.7.2 installed. The portable carries its runtime, imported assets and disk-baked review Acts.
2. Start with **Profile B**, **Native shadows**, **Stair study** and **Hold pose**. Compare the joint beneath the back wall, the horizontal treads, the vertical risers and the underside of the shelf. The amber strip is an unlit reference. Compare Off, Native subtle, Clean 8, Clean 4 and Authored faces before trying Ordered 4.
3. Switch to **Rooftop Run â†’ Launch Tube**, then **Green Hill â†’ First Try**. Choose **Pan + spin** or **Play Act / tour**. **F1** hides the controls. Use Dramatic, Wide, Real or Top-down to change elevation. Zoom, AO strength and radius are independent controls. For Ordered 4, adjust screen/object/world anchoring, matrix, cell size and transition width.
4. For the shadow interaction, hold AO on **Authored faces** and switch between **Native shadows**, **Clean 8 shadows** and **Clean 4 shadows**. Native remains the production shadow presentation. The separate Shadow Lab also compares clean 8/4/3/2 attenuation and pattern-dithered shadows under full Retro. [Shadow comparison](RETRO_SHADOW_LAB.md)
5. From CMD, run `"Retro AO Lab.cmd" stairs` to open the stair fixture, `"Retro AO Lab.cmd" smoke` for a quick rendered qualification, or `"Retro AO Lab.cmd" evidence` for the full matrix. Use `first-native` or `first-authored` for two Rooftop activations in a new process. Keep the game window restored during rendered tests so Godot continues presenting frames. Each portable launch gets a new adjacent `Results/Review-*` directory containing its private user data and engine log. Evidence runs also write screenshots and `report.json`. No editor, PowerShell, admin access or installation is required to run the portable.

## Matched evidence

| Open | Inspect |
| --- | --- |
| [Six stair candidates](retro-ao-lab/stairs.jpg) Â· [lossless, original-size detail](retro-ao-lab/contact-detail.png) | Compare the horizontal wall joint with the vertical face of the second tread. The authored mode deepens the face across its width. Native adds a softer contact at its edges. |
| [Continuous, 8, 4, 3, 2, ordered](retro-ao-lab/bands.jpg) Â· [Bayer matrix and cell sizes](retro-ao-lab/ordered.jpg) | Compare the thin line at the back of a tread. Clean 8 and 4 follow the same contour. At 2, most of a shallow contact drops below the single threshold. |
| [Six Launch Tube views](retro-ao-lab/tube.jpg) Â· [flipper, moving bumper, score chute and launch](retro-ao-lab/fixtures.jpg) | Inspect the floor next to the moving hardware and the recess below the dock. The barrel's existing texture is present in the Off reference. |
| [Theme comparison 1](retro-ao-lab/themes-1.jpg) Â· [theme comparison 2](retro-ao-lab/themes-2.jpg) | Eight disk-baked Acts, each at the same gameplay pose in Off, Native, Clean 4 and Authored. |
| [Pan, zoom and moving block](retro-ao-lab/motion.mp4) Â· [screen, object and world anchoring](retro-ao-lab/anchors.mp4) | Matched 24-position sweeps. The block uncovers the floor on the stair card. The Rooftop sweep includes spinning Rings. Clips replay the forward samples in reverse for inspection. |
| [85% and 100% scale](retro-ao-lab/scale.jpg) Â· [native and quantized shadows](retro-ao-lab/shadow-pairs.jpg) | The native-scale comparison holds the other device settings fixed. Each shadow row uses one pose and exposure. |
| [RTX 4060 frame timings](retro-ao-lab/rtx4060.csv) Â· [scale, lifecycle and image measurements](retro-ao-lab/measurements.json) Â· [baseline suites](retro-ao-lab/baseline.csv) | Frame times use wall-clock intervals. Pixel metrics compare matched, full-resolution end-of-stack screenshots before review-sheet resizing or compression. |

## Art direction

**Classification E. Authored face shading wins for the remembered console look.** On the stairs, each riser reads as a single plane and the top stays bright. The shelf support gains weight all the way down to its base. The cue belongs to the shape and remains legible as the camera moves. At ordinary play distance it is often easier to notice the geometry than the treatment. I would keep this available for selected architecture. Existing lighting already does most of the work across broad outdoor floors.

Native subtle is the strongest alternative when an object actually needs to feel attached to the ground. Look immediately under the movable block and around the rim of a bumper. The reaction to a passing object is something authored faces cannot supply. A soft continuous join along an entire long wall reads more like contemporary SSAO. Coarse keeps much of that look after Retro. Its main distinguishing feature is the reduced definition of small contacts. It does little to strengthen the intended style.

Clean 8 is the quietest dynamic treatment. Clean 4 makes the tread/wall contact easier to pick out, particularly while inspecting the pale stair card. Clean 3 and 2 lose progressively more of the low-contrast end of the field. Ordered 4 fills in those threshold transitions with texture. It gives the stair edges a grain that can be attractive in a close-up, but competes with CRT and surface texture during travel. Screen anchoring holds that grain against the viewport as the floor moves underneath. World anchoring is the more coherent reference for static architecture. Object anchoring follows individual pieces and can restart the pattern at a mesh boundary. This interpretation is an art-direction judgment about the captures.

| Theme | Observation at the matched gameplay distance |
| --- | --- |
| Green Hill | Open turf stays bright. Native grounds the round bumpers and cliff foot. Authored concentrates the change on the raised faces. |
| Rooftop Run | Paving and existing relief already carry a great deal of detail. Authored gives a consistent value to a step or ledge. Native is easier to see near isolated hardware. |
| Chemical Plant | The yellow machinery and blue/pink panels keep their separation. Deepening every recess has little value where the floors already include cavity maps. |
| Casino Night | The emissive stars and illuminated trim remain the focal points. Subtlety is preferable on the dark blue floor. |
| Sky Sanctuary | The pale paving makes excess edge shading easy to see. Authored leaves the broad upper faces bright. Native contacts are visible beneath hardware. |
| Ice Cap | The broad blue shadows are already conspicuous in Off. Adding a little contact changes less about the scene than their silhouettes. The snow keeps its pale blue cast. |
| Aquarium Park | The treatment is easiest to read on red/pale architectural edges. The original glass and water keep their own materials. |
| Lava Reef | The dark joints in the rock are already strong in Off. Clean 4 changes 47.5% of the image by at least 3/255 in one channel. The darkening covers too much of the patterned floor. Authored affects 4.1% by the same measure. |

The Launch Tube close-up separates geometry from contact. Native SSAO changes 11.0% of that frame at the 3/255 threshold, Clean 4 changes 3.9%, and Authored matches Off on every pixel. The dock view contains large upward-facing surfaces and untreated hardware. Only the dynamic treatments add grounding there. In the shadow matrix, Clean 8 preserves more of the soft shoulder around the hardware. Clean 4 makes the directional shadow contour easier to see. On the stairs the authored riser tone and the directional ramp are legible separately. Neither matrix supports a universal combined preset.

In the 18 pan/zoom sweeps, the first rendered image after the last move matched the same pose held for four more frames. This includes the moving block uncovering the floor and all three ordered anchors. The evidence establishes a clean stop for those paths. During travel, discrete contact boundaries still move between pixels and small patterned patches still change apparent contrast against CRT. The clips sample one rendered frame per pose with synchronous readback. Their 15 fps playback is for visual comparison. Frame timing uses separate capture-free loops. [Motion comparison](retro-ao-lab/motion.mp4) Â· [Anchor motion](retro-ao-lab/anchors.mp4)

At 85% the foreground depth copy was **572 Ã— 402**. At 100% it was **673 Ã— 473**, an increase of about 38% in source pixels at the same 1280 Ã— 900 window size. The N64 resolution divisor is 1.9. The extra samples improve definition at narrow edges, and also alter the base image in Off. Large risers retain the same character at both scales. Coarse's half-size working field loses small contacts earliest. Motion was captured at the main 85% setting. The 100% test includes pan timings and matched stills. [Scale comparison](retro-ao-lab/scale.jpg)

The 120-frame stair pan at 85% / 100% measured 1.54 / 1.49 ms with AO Off, 1.75 / 2.09 ms with native subtle, 2.78 / 2.03 ms with coarse, and 1.59 / 2.03 ms with Clean 4. The mixed ordering illustrates the limits of ranking these low-millisecond cases from one pan. The change in source resolution is independently confirmed by the reported GPU texture dimensions.

For Chemical Plant, Casino Night and Aquarium Park, temporarily removing ambient light and reflections left direct and emissive output byte-identical across Off, Native subtle, Clean 4 and Authored. Full Retro and the scene's glow remained active during this control. Aquarium contained 20 transparent slots, zero treated. Each theme also passed an exact return-to-Off screenshot check, and duplicate materials reproduced the original at zero strength in Clean 4 and Authored. These tests preserve the themes' existing material cavity maps.

## What each mode changes

| Mode | Input and treatment |
| --- | --- |
| A Â· AO off | Original foreground environment and materials. Includes any cavity detail already authored into a theme material. |
| B Â· Native subtle | Godot SSAO at Medium, full internal resolution and two blur passes. Radius 0.42 m, intensity 0.961, power 1.08, detail 0.08, horizon 0.09, sharpness 0.88. Direct-light and material-AO-channel affect both zero. |
| C Â· Coarse SSAO | Same environment values as B, with Low quality, half-size sampling and one blur pass. |
| D Â· Clean 8, 4, 3 or 2 | A separate deterministic contact field from current-frame foreground depth. Round to the nearest of N evenly spaced values including both endpoints, then apply strength. The thresholds follow the field and use no spatial pattern. **Continuous contact** runs the very same field with rounding disabled. |
| E Â· Ordered 4 | Choose between adjacent levels of that field with a 2Ã—2 or 4Ã—4 Bayer threshold. The default is a world-anchored 4Ã—4 pattern with 0.045 m cells and 0.55 transition width. A modern Saturn/Dreamcast-inspired art study. |
| F Â· Authored faces | Use the geometric face normal and relative height within its mesh. Tops receive zero extra shading. Side faces darken progressively toward their base and undersides more strongly. Strength 0.62. World orientation follows moving geometry. There is no screen-space pass in this mode. |

The tone count describes the AO signal. Lighting, texture detail and the game's own N64/VHS/CRT texture are visible even in clean modes. The custom treatments replace the eligible material's ambient occlusion input with the darker of its authored value and the experimental value. The existing opaque shader still supplies albedo, normal, roughness, metalness and emission. The resolver accepts opaque single-material ground, upper terrain, walls, borders, ledges and ramps. Water, glass, alpha, shadow-only surfaces, unsupported lighting code and backdrop worlds keep their original materials. A moving prop can occlude an eligible floor in mode D without receiving the treatment itself. F provides a static depth cue on the receiver and has no contact response to a passing ball.

Each resident Act owns private material instances. When the Act leaves, the Lab releases those instances and restores the exact prior override, including a null override. Native and coarse SSAO use the foreground viewport's own environment. Their quality configuration is process-wide and restored from project settings on exit. The foreground lighting crossfade uses the same environment object. Device profiles and atmosphere resources on disk are shared with ordinary gameplay.

## Engine boundary

Godot **4.7.2-stable**, Forward+ on Vulkan, computes native SSAO from the scaled foreground depth and normal/roughness prepass. Sampling, depth-aware blur and reconstruction run before opaque lighting, before upscaling and before the Retro canvas passes. Lower native scale changes the input and sampling footprint. Godot blends the native field with material AO in opaque shading. Ambient diffuse and indirect specular can respond. The direct-light AO weight is zero in this study. Lighting, fog and glow then run through their regular paths. Native SSAO uses a fixed sampling pattern without previous-frame reprojection. [4.7.2 SSAO implementation](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/rendering/renderer_rd/effects/ss_effects.cpp) Â· [Forward+ material and lighting shader](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl#L2028-L2036)

The public pre-opaque compositor callback precedes the native SSAO dispatch. The next public callback sees already-shaded opaque color. The Lab therefore generates its own field for D/E. A single compute pass copies the resolved opaque depth into a private R32F texture before opaque draws. A material samples eight directions at three metric radii, applies a surface bias and distance falloff, and combines the highest nearby horizon in each direction. The receiver reads the depth copy from the current frame. New render sizes publish their private texture between frames. All three device profiles use MSAA. This Lab qualifies that Forward+ path only. Compatibility has a different post-process SSAO implementation with its own parameter mapping. Mobile lacks native SSAO in this engine version. [Callback ordering](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp#L2135-L2182) Â· [Compatibility implementation](https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/gles3/rasterizer_scene_gles3.cpp#L2706-L2716) Â· [Environment reference for this version](https://github.com/godotengine/godot/blob/4.7.2-stable/doc/classes/Environment.xml)

| Installed Environment property | Inspector range | Engine default |
| --- | --- | ---: |
| `ssao_enabled` | Boolean | false |
| `ssao_radius` | 0.01â€“16 m, higher allowed | 1 |
| `ssao_intensity` | 0â€“16, higher allowed | 2 |
| `ssao_power` | Positive | 1.5 |
| `ssao_detail` | 0â€“5 | 0.5 |
| `ssao_horizon` | 0â€“1 | 0.06 |
| `ssao_sharpness` | 0â€“1 | 0.98 |
| `ssao_light_affect` | 0â€“1 | 0 |
| `ssao_ao_channel_affect` | 0â€“1 | 0 |

`RenderingServer.environment_set_ssao_quality` sets Very Low, Low, Medium, High or Ultra, half-size mode, adaptive target (Ultra), blur passes and fade distances. This project's defaults are Medium, half-size on, target 0.5, two passes, fade from 50 to 300 m. The B and C letters for **device profiles** are independent of the AO mode letters. Device B uses a 4096 atlas, four cascades, Medium directional filter, FXAA, 2Ã— MSAA and 85% native scale. Device A uses 8192/four, Medium, 4Ã— MSAA, 100% and FXAA off. Device C uses 2048/one with B's other settings. The 85/100 comparison changes only native scale within B. [Device definitions](SHADOW_REVIEW.md) Â· [4.7.2 project setting descriptions](https://github.com/godotengine/godot/blob/4.7.2-stable/doc/classes/ProjectSettings.xml)

## First activation on the RTX 4060

First-use cost changes the integration decision. Two independent launches of the extracted package each opened the ordinary Rooftop Act with AO Off, measured first activation, returned exactly to Off, and repeated the same treatment. Each launch received a new Godot user cache. Windows and NVIDIA driver caches were available. The longest time among the following 24 frame intervals includes pipeline preparation. Steady timings use the next 120 frames. These intervals exclude screenshot readback.

| First treatment in fresh process | Act open | Enable call, first / repeat | Slowest of next 24 frames, first / repeat | Steady median, first / repeat |
| --- | ---: | ---: | ---: | ---: |
| Native subtle | 6.83 s | 0.22 / 0.14 ms | 213 / 6.0 ms | 4.06 / 3.48 ms |
| Authored faces | 9.25 s | 64.45 / 0.24 ms | **6,584 / 5.2 ms** | 3.61 / 3.58 ms |

An authored-first run pays for private material/shader specialization even though its face rule requires no screen-space pass. The stable visual result is worth carrying into a future terrain material or bake. The live replacement used to audition it here has an unacceptable first-use hitch for an in-game toggle. Native subtle also needs a warm-up plan for seamless play. [Fresh and repeat measurements](retro-ao-lab/measurements.json)

## RTX 4060 performance and streaming

Measurements use uncapped Forward+/Vulkan in a 1280 × 900 window on one RTX 4060. Each static cell is the median across the eight gameplay themes of their own 120-frame median or P95. The pan column uses a separate 90-frame Rooftop sweep. The continuous contact row carries the same depth capture and sampling as clean/ordered. Comparing these rows isolates the cost of the tonal choice as far as this end-to-end test allows.

| AO mode | Static median (ms) | Static P95 (ms) | Rooftop pan median / P95 (ms) |
| --- | ---: | ---: | ---: |
| Off | 2.41 | 3.18 | 2.41 / 2.84 |
| Native subtle | 2.66 | 4.40 | 2.42 / 4.04 |
| Coarse native | 2.74 | 4.07 | 2.38 / 2.81 |
| Continuous contact | 2.65 | 4.04 | 2.72 / 3.93 |
| Clean 8 | 2.84 | 4.23 | 2.74 / 4.72 |
| Clean 4 | 2.48 | 3.93 | 2.62 / 3.60 |
| Clean 3 | 2.56 | 3.99 | 2.44 / 2.89 |
| Clean 2 | 2.52 | 3.73 | 2.67 / 4.33 |
| Ordered 4 | 2.62 | 3.95 | 3.16 / 5.17 |
| Authored faces | 2.47 | 3.72 | 2.80 / 4.83 |

Opening the eight ordinary disk-backed cases took 4.35–6.84 s. Native first introduced 10–19 renderer compilation events per theme. The first custom activation (Clean 8 in this matrix) took 28–173 ms on the calling thread, with a longest interval of 0.12–6.72 s among the next 24 frames. Subsequent tone and ordered switches reused the same material programs. Their warm frame-time differences overlap normal run variation. These are whole-frame measurements. The renderer counters do not provide isolated GPU pass time or per-pixel overdraw.

Rooftop submitted 190 visible draws, 237 objects and 54017 visible primitives with AO Off. Clean 4 submitted 190 draws and 54017 visible primitives. Both recorded 388 shadow draws. The ordinary theme fixtures used seven eligible receiver slots, four private materials and two to four programs. Rooftop's process-wide video counter read 240.2 MiB Off, 245.8 MiB native and 246.1 MiB at Clean 4. The counters include other viewports and cached resources. The Lab retains one private depth target per visited size until case teardown. [Per-theme timings, draws, resource counts and memory](retro-ao-lab/rtx4060.csv)

The tube's same-pose native shadow + Off / native + authored / Clean 8 + authored / Clean 4 + authored medians were 1.75 / 1.59 / 1.67 / 1.53 ms. Their visible draw counts were 27 / 27 / 32 / 32. The additional submissions belong to the existing shadow overlay. Rooftop's authored AO itself substitutes the opaque material in its existing geometry draw.

| Endless, Rooftop → Chemical | Startup (s) | Next Zone ready (s) | Crossing median / P95 (ms) | Worst frame (ms) | Boundary wait frames / fallback builds |
| --- | ---: | ---: | ---: | ---: | ---: |
| Off | 3.61 | 2.35 | 5.77 / 10.02 | 82.0 | 0 / 0 |
| Native | 2.46 | 1.84 | 5.75 / 9.28 | 64.8 | 0 / 0 |
| Clean 4 | 2.52 | 1.87 | 5.92 / 9.16 | 317.4 | 0 / 0 |
| Authored | 2.49 | 2.19 | 5.98 / 9.45 | 303.1 | 0 / 0 |

Each run exercised the real background overlap and travel-controlled crossfade. The native game continued preparing disk recipes ahead of the camera. The custom cases also exercised Act retirement and released their private receiver owners. A zero boundary wait still permits individual long frames during preparation and crossing. These results cover this RTX 4060 only. The portable is ready for a separate UHD 620 test. [Crossing and retirement measurements](retro-ao-lab/measurements.json)

## Portable and source

The review ZIP on the build machine is `test-results/retro-ao-lab/Retro AO Lab.zip` (185,838,486 bytes). Its SHA-256 is `3b82a4875dd14091c377af614bc48d2bbfe6fb5d9b81f0859c1a096c6c011951`. It uses the previous qualified portable's runtime, assets and baked Acts. The full archive passed a CRC check before extraction. Raw PNG sequences and machine-local results stay in the results directory. The compact review media, performance data and Lab source live in Git.

The implementation is under `experiments/retro_ao_lab/`. The shared Shadow Lab gained scene-title, capture-runner, fixture and evidence hooks to reuse its established rig. The launcher is `Retro AO Lab.cmd` and the media builder is `tools/summarize_retro_ao_lab.py`. To regenerate the compact evidence, pass the full capture directory and an output directory to the media builder, followed by `--first-use` and the two isolated first-use capture directories. The builder uses Pillow, NumPy and FFmpeg on the evidence machine. The portable review itself uses its bundled Godot runtime.

## Verification

The shipping ZIP's extracted CMD passed the full study (890 checks, 145 timing and diagnostic rows, 585 PNGs), the short control/UI run (55 checks), and both independent first-use runs (five checks each). Each reported zero orphan nodes. The inherited Shadow Lab passed its separate 40-check smoke. The GPU ramp verified exactly 8, 4, 3 and 2 monotonic values including both endpoints. All four clean modes were pixel-independent of the dither controls. The full run checked replay, four camera presets, the moving Sonic ball, spinning Rings, flipper and bumper motion, score chute loading, Launch Tube charging/release, paused position and native Theme Life. The final Lab logs contained zero shader errors, engine errors or warnings. In a preliminary smoke attempt Windows minimized the render window during native preload and the fixture timed out. Restoring the window allowed the same fixture to finish. The final launcher qualifications ran with the game window restored on the second monitor.

All **32 supported baseline suites passed on their single run**. The canonical Prototype appearance regression passed 70 checks, and the disk-bake audit passed 566 checks over 56 variants. The traversal Prototype suite used the previously verified private project view with its isolated rebuilt test fixture. Its test script and source Act matched the checkout by SHA-256, and it passed all 20 checks. The other 31 suites ran against the checkout. The runner selected the second monitor for rendered cases. Established source-image warnings and intentional failure-path diagnostics still appear in the underlying suite logs. [Per-suite exits, timing and test project](retro-ao-lab/baseline.csv)
