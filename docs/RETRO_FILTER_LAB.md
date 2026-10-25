# Green Hill retro post-processing lab

This is an optional presentation experiment in the **normal Green Hill application**, not a separate game or level. Start `Play Green Hill.cmd`. **F4** cycles **OFF → PIXEL / DITHER → N64-ish → CRT → VHS → OFF**. A two-second native-resolution label announces the selection. F1's tuning panel has the same preset selector. Key repeat and Alt/Ctrl/Meta+F4 do not cycle presets.

Every launch starts OFF. Selection and tuning are session-only; nothing saves a preferred aesthetic. The experiment does not select a winner.

## Presets and tuning

Edit `data/retro_settings.tres` in Godot's Inspector. Defaults and descriptions are in `scripts/retro/retro_settings.gd`. Restart the game after editing the resource; runtime code can edit `retro_filter.settings` and call `set_preset` again. No sliders were added to the normal HUD.

| Preset | World rendering | Treatment |
| --- | --- | --- |
| OFF | Original viewport size, material, filter and MSAA | No identity shader; original rendering path |
| PIXEL / DITHER | Half size, nearest upscale | 32 quantization intervals/channel, restrained 4×4 dither at 0.65 strength |
| N64-ish | Half size, linear upscale | 24 intervals/channel, 0.9 dither, gentle output softness |
| CRT | Original size | 10% scanlines, 3.5% RGB mask, 8% vignette, 3.5% glow, zero convergence |
| VHS | Original size | 0.45 px chroma shift, 1.1 px bleed, tiny wobble, 1.2% grain, restrained bottom tracking |

The normal 1280×900 application reserves 210 pixels for its footer, so its **world is 1280×690**. Half resolution is **640×345**, preserving that existing composition rather than forcing a 16:9 world or stretching its camera. Resolution divisors 1–4 are exposed; divisor 3 is roughly 426×230 at this window size and deliberately not the default. F1 and window resizing change the world area's size; the divisor follows it. The viewport's normal integer rounding applies. MSAA remains at its existing setting in every preset.

Pixel dither runs inside the existing world SubViewport, before upscale. N64-ish uses that same pass with linear output filtering. CRT/VHS are materials on the existing SubViewportContainer, sampling only its world texture. There are no history buffers, extra SubViewports, temporal accumulation, deliberate presentation delay, global screen overlay or physics-timestep changes.

HUD, menus, character selector, Scorecraft, debug controls and the toast stay in the root viewport. Existing 3D text painted on the table is part of the world and receives the filter. Curvature is absent in the imported CRT implementation. The optional normal-based outline shader was omitted to retain Compatibility rendering. VHS has no large tears, dropouts or chroma-loss streaks; the upstream continuous bottom tracking is dialed down rather than turned into a new tape simulator.

## Same-scene comparison

The five full-window images in [retro-captures](retro-captures/) use the same generated seed 18, served Sonic ball, exact camera transform, geometry, rings, paddles, lighting and HUD. Scene and cosmetic animation processing are frozen before switching; only the VHS shader's time-dependent signal noise varies. No camera reframing or screenshot rescaling is applied.

- [OFF](retro-captures/off.png)
- [PIXEL / DITHER](retro-captures/pixel.png)
- [N64-ish](retro-captures/n64.png)
- [CRT](retro-captures/crt.png)
- [VHS](retro-captures/vhs.png)

## Reproduce verification

Use Godot 4.7.2 on this project. On this workstation the executable is `C:\Program Files\Godot\Godot.exe`. The normal launcher selects `gl_compatibility` / `opengl3_angle`; native OpenGL is an optional diagnostic backend.

```powershell
godot --headless --path . --import
godot --headless --path . --script tests/retro_filter_smoke.gd
godot --headless --path . --fixed-fps 120 --script tests/retro_physics_regression.gd
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --script tests/retro_filter_smoke.gd -- --benchmark
```

The graphical smoke saves five A/B images, checks the opaque HUD footer byte-for-byte, checks OFF against both its initial frame and a frame with the adapter removed, and measures root-plus-world render costs. It also checks input cycling, synchronized debug selection, paused-state preservation, F1 resizing and adapter removal. The physics regression compares all 600 ticks of the same scripted launch, steering and flipper input across five fresh application processes plus a sixth that switches every 60 ticks. Position, velocity, score, rings, drain count and flipper angles must match exactly. Reusing one engine process for successive games produced small collision differences even in an OFF-versus-OFF control; fresh processes avoid that fixture issue without changing physics or relaxing equality.

The optional `--benchmark` flag adds performance measurements to the otherwise short graphical smoke. It uses the static comparison scene, VSync disabled, no FPS cap, 90 warmup frames and 240 samples per preset, then reverses the order. Shader startup and screenshot readback are excluded from measured blocks. The report distinguishes wall-frame duration, CPU rendering time and GPU query results. They are local measurements, not a hardware-independent FPS claim or a moving-game benchmark. To repeat the native diagnostic, use `--rendering-driver opengl3` and append `--native-report` after `--`.

### Measured results — 2026-10-25

Godot 4.7.2, Windows, NVIDIA GeForce RTX 4060, 1280×900 window. Values below average the median of each forward/reverse block (480 measured frames per preset per backend).

| Preset | Normal ANGLE frame ms | Native OpenGL frame ms | Native OpenGL GPU ms |
| --- | ---: | ---: | ---: |
| OFF | 17.40 | 6.70 | 1.26 |
| PIXEL / DITHER | 14.21 | 7.15 | 1.44 |
| N64-ish | 15.98 | 7.27 | 1.45 |
| CRT | 13.31 | 6.23 | 1.22 |
| VHS | 12.69 | 5.98 | 1.18 |

**Do not read the lower CRT/VHS numbers as a speedup.** Background load and block-to-block variation exceed these small effect differences. ANGLE OFF alone moved from a 20.56 ms to 14.25 ms block median; a pre-existing Act editor process remained open and was not stopped. Native GPU measurements put all five paths in roughly the same 1.2–1.5 ms range. Pixel/N64 add a world screen-copy/dither pass, so lower resolution does not guarantee a faster result in this geometry-heavy scene. No disproportionately expensive multipass effect was introduced.

ANGLE returned **0 for every GPU query** despite measurement being enabled; this means unavailable telemetry, not zero GPU work. Native OpenGL was measured separately to obtain GPU timestamps. The normal launcher remains on ANGLE because of its existing driver-stability rationale; this experiment does not change the graphics backend. Per-block statistics, CPU timings, P95 values and device metadata are preserved in [ANGLE report](retro-captures/performance-angle.json) and [native report](retro-captures/performance-native.json).

### Checks executed

- Headless editor import: no script/import errors.
- Final retro smoke headless: **20 checks, zero failures**.
- Retro smoke rendered on ANGLE: **31 checks, zero failures**. Native OpenGL: **30 checks, zero failures** (before the additional controls-removal assertion). Both had empty stderr. Five images visually inspected; shader effects preserve silhouettes and readable ball/rings/paddles.
- Isolated 120 Hz physics replay: **6 checks, zero failures**, exact equality through all 600 ticks, including live preset switching.
- Existing authored-main-game regression: **70 checks, zero failures** (headless), including generated/authored transitions, geometry, character presentation and camera behavior.
- Existing playable Green Hill smoke: **25 checks, zero failures** (headless), including four generated layouts, scripted real-input traversal, rings, bumpers, drain/relaunch and pause.

Captures, performance and the longer existing traversal survey used physics from `8270f5a`. Concurrent gameplay work subsequently landed as `04e2a20`; final render/removal checks and the exact replay/authored-main regressions were checked against that newer working tree. This change neither stages nor reverts the concurrent gameplay work.

Automated results do not establish subjective fast-motion comfort; that remains the manual comparison described below.

## Removal and scope

Remove the two retro preloads, two fields and the installation block from `experiments/visual_lab/visual_lab.gd`, plus the F4 help text. Then delete `scripts/retro/`, `data/retro_settings.tres`, `third_party/retro/` and the dedicated tests/docs if no longer wanted. No presentation mesh, physics, character, camera algorithm, scoring or Act-loading source needs rewriting. Freeing the adapter at runtime also restores its owned container properties and removes its dither canvas.

See [shader provenance and license notices](../third_party/retro/README.md). Existing unrelated physics, project-settings and authored-Act work is outside this change.

Manual review remains short: switch during a fast ball run; judge ring/ball/flipper tracking; try F1, pause, overview and an authored Act; decide whether any preset earns further art tuning.
