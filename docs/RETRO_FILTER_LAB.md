# Green Hill retro post-processing lab

The normal Green Hill application starts with **N64-ish + VHS + CRT**. Open **Retro…** or press **Shift+F4** to tune the picture for the current session.

## CRT at playing distance

**Dreamcast 480p · fit screen** is the default. Sega specified 640×480 progressive VGA output at 60 Hz. The game uses that 480-line picture height and extends the horizontal field for widescreen displays. It renders 640×480 at 4:3, 854×480 at 16:9 and 768×480 at 16:10. The CRT shader draws 480 corresponding beam rows on the final world image. Bright colors fill more of each row. The RGB grille starts at zero. HUD and editor controls retain their native display resolution. [Sega hardware outline](https://segaretro.org/images/8/8b/Dreamcast_Hardware_Specification_Outline.pdf) · [KallistiOS display modes](https://kos-docs.dreamcast.wiki/group__video__modes__display.html)

The full-screen Green Hill comparisons use a locked camera, native SSAO at 8× and blur 10. Each PNG contains the complete 1920×1200 display. Returning to the four-tone treatment reproduced the original tuned frame pixel-for-pixel. [All four frames](terrain-face-shading/green-hill-480p-comparison.jpg) · [Earlier grid](terrain-face-shading/green-hill-480p-grid.png) · [Soft CRT](terrain-face-shading/green-hill-480p-soft.png) · [Tuned CRT with smooth shadows](terrain-face-shading/green-hill-480p-smooth.png) · [Tuned CRT with four-tone shadows](terrain-face-shading/green-hill-480p-tuned.png)

For the stronger grid feel, keep **Dreamcast 480p · fit screen** on and set **Scanline strength** to **0.70**, **RGB mask strength** to **0.04** and **RGB grille pitch** to **3 px**. The old filter painted about 158 horizontal cycles into this 480-line source before scaling. The new setting draws 480 beam rows at display resolution, with an independent vertical RGB grille. The number of phosphor stripes on a physical tube depends on its grille pitch. [Full-screen side by side](terrain-face-shading/green-hill-480p-grid-comparison.jpg) · [Stronger 480-line frame at original size](terrain-face-shading/green-hill-480p-fine-grid.png)

The previous adaptive scale already rendered 757×473 in this fullscreen session. Widescreen 480p rendered 768×480. Across two reversed runs of 240 frames each per mode on an RTX 4060, median GPU times were 0.826–0.829 ms for adaptive and 0.828 ms for 480p. The 95th-percentile whole-frame times were 3.57–3.66 ms and 3.58–4.72 ms, respectively. All measured frames met the 16.7 ms budget. This comparison covers a steady Green Hill camera pan and excludes first-use shader preparation and Act transitions. [Recorded GPU and frame timings](terrain-face-shading/green-hill-480p-gpu.json)

Sony’s BA-4 training manual describes three beams scanning horizontal lines through an aperture grille onto vertical phosphor stripes. CRT-beans documents the wider bright spots common on consumer CRTs and the effect of diffusion in the glass. Our shader approximates these cues with a luminance-dependent beam, a small horizontal spread and local highlight diffusion. [Sony BA-4 training manual, pp. 7–10](https://www.epanorama.net/sff/Sony/Video/Sony%20CTV25%20BA-4%20Training%20Manual.PDF) · [CRT-beans spot size and glow](https://github.com/libretro/slang-shaders/blob/master/crt/shaders/crt-beans/docs/parameters.md)

For cleaner skies, keep **RGB mask strength** at 0. **Scanline strength** controls beam visibility. **Glow spread** controls how far a bright edge bleeds into its neighbor. Tape grain is 0.004. Turn off **Dreamcast 480p · fit screen** to experiment with custom raster lines and the Pixel/N64 resolution divisors. The earlier startup and stack galleries below document the previous filter.

Alex’s Dell Trinitron still and Sonic close-up guided the final Green Hill tune. The white gloves and road markings have a narrow bright fringe, while the shoe shadow has a dark center. The game responds separately to red, green and blue intensity so saturated colors can fill the raster. Chroma bleed is low enough to preserve the ring and terrain edges. [Video reference](https://www.youtube.com/watch?v=tWPhzjktu80)

## Controls and live tuning

- **F4** cycles **OFF → PIXEL / DITHER → N64-ish → CRT → VHS → OFF**. From a custom stack, F4 returns to OFF. A two-second native-resolution label announces the selection. Key repeat and Alt/Ctrl/Meta+F4 do not cycle presets.
- Click **Retro...** in the normal toolbar or press **Shift+F4** to open the live panel. Check any combination of effects and adjust sliders immediately, including while paused.
- **F1** also provides a multiselect menu that stays open while checking effects.
- **All OFF** clears the selection. **Reset tuning** restores parameter defaults while retaining selected effects. Closing the panel retains the current settings.
- **F11 / Play View** in the footer enters fullscreen gameplay with all development panels, selectors, diagnostics and overlays hidden. Score, specials, Scorecraft and gameplay modals remain. F11 restores the previous window mode, dimensions, position and development UI. Launch stays windowed. Retro effects remain active, but their development controls and F4 shortcut are hidden/disabled during Player View.

Green Hill starts with **Dramatic Pinball** and **follow zoom 2.0**, including authored Acts. F1 still exposes all camera choices; overview retains its complete-table framing. Shared Physics Playground camera defaults are unchanged.

Sliders appear for enabled effects in the scrollable panel. Pixel/N64 expose resolution divisor, color levels and dither. CRT exposes phosphor cell size, scanlines, RGB mask, glow intensity/spread, brightness and vignette. VHS exposes chroma offset/bleed, wobble, grain and tracking. The normal HUD has one launcher button.

The full experimental ranges are available without changing the restrained defaults. Hover a slider for its bounds and step. Resolution divisors accept **1.0–4.0 in 0.1 steps**, including 1.1; phosphor cells accept **1–64 px in 0.1 steps**. Color precision accepts 1–256 intervals; dither, scanlines, RGB mask, glow, vignette, VHS grain and tracking span 0–1. Brightness spans -1–1, glow spread 0–8 px, VHS offset/bleed 0–10 px and wobble 0–0.1. Positive minima for divisors, color intervals and cell size avoid undefined division. Extreme settings intentionally allow heavy distortion or an almost blank image; Reset tuning restores the original defaults.

Persistent developer defaults remain in `data/retro_settings.tres` and `scripts/retro/retro_settings.gd`. Inspector resource edits take effect on the next launch. Runtime code can edit the adapter's cloned `settings` resource and call `apply_settings()` without changing selection.

| Effect | World rendering when alone | Default treatment |
| --- | --- | --- |
| OFF | Original viewport size, material, filter and MSAA | No identity shader; original rendering path |
| PIXEL / DITHER | Half size, nearest upscale | 32 quantization intervals/channel, 4×4 dither at 0.65 strength |
| N64-ish | Divisor 1.9, linear upscale | 119 intervals/channel, 0.75 dither |
| CRT | 480-line source at the playfield aspect, display shader at output resolution | 0.34 scanline strength, 0 RGB mask, 0.42 glow, 2.6 px spread, neutral brightness, 0.14 vignette |
| VHS | Original size | 0.25 px chroma offset, 0.45 px bleed, 0.00015 wobble, 0.004 grain, 0.001 tracking |

## Stacking and world-only rendering

The fixed order is **Pixel → N64-ish → VHS → CRT**. Pixel and N64 can both be selected: their quantization passes run in order, the larger resolution divisor wins, and N64 selects linear upscale. CRT stays last so its display pattern covers the combined image.

RGB grille pitch, glow radius and VHS offsets use output-pixel units. The grille fades below three output pixels per triad.

The normal 1280×900 application reserves 210 pixels for its footer, so its **world is 1280×690**. Half resolution is **640×345**. Divisor 1.1 renders **1163×627**, rounding down to whole texture pixels. Fractional divisors follow F1/window resizing. MSAA and camera composition remain unchanged.

[Godot's SubViewportContainer shrink property](https://docs.godotengine.org/en/stable/classes/class_subviewportcontainer.html#class-subviewportcontainer-property-stretch-shrink) only accepts integers. The adapter therefore places the existing world viewport under a plain child node and displays its texture through a full-size TextureRect. It controls the viewport size directly; no extra viewport or render pass is added. Removing the adapter restores the original viewport parent/index and container presentation.

Pixel, N64 and VHS each take an explicit backbuffer copy in the world SubViewport. CRT runs on the existing world-output TextureRect, where it samples the composed image at display resolution. OFF restores the original sampler, resolution and material.

HUD, menus, character selector, Scorecraft, debug controls, live panel and toast stay in the root viewport. Existing 3D text painted on the table receives the filter. The display shader keeps the picture geometry flat.

## Same-scene comparison

[Earlier startup preview](retro-captures/startup-defaults.png) shows the previous N64/VHS/CRT stack, Dramatic Pinball at zoom 2, and the fullscreen button.

The historical images in [retro-captures/stacking](retro-captures/stacking/) predate the chosen startup stack and Dramatic zoom. They use generated seed 18, the same served Sonic ball, camera transform, geometry, rings, paddles, lighting and HUD. Scene and cosmetic animation processing are frozen; only VHS signal noise varies with shader time. No screenshot rescaling or reframing is applied.

- [OFF](retro-captures/stacking/off.png), [Pixel](retro-captures/stacking/pixel.png), [N64-ish](retro-captures/stacking/n64.png), [CRT](retro-captures/stacking/crt.png), [VHS](retro-captures/stacking/vhs.png)
- [Pixel + CRT](retro-captures/stacking/stack-5.png), [VHS + CRT](retro-captures/stacking/stack-12.png), [all four](retro-captures/stacking/stack-15.png)
- [Live panel with stronger custom settings](retro-captures/stacking/live-tuning.png)

The parent folder retains the initial single-preset experiment's historical captures and reports. Those predate the stronger CRT and stacking pipeline.

## Reproduce verification

Use Godot 4.7.2. On this workstation the executable is `C:\Program Files\Godot\Godot.exe`. The normal launcher selects `gl_compatibility` / `opengl3_angle`; native OpenGL is an optional diagnostic backend.

```powershell
godot --headless --path . --import
godot --headless --path . --script tests/retro_filter_smoke.gd
godot --headless --path . --fixed-fps 120 --script tests/retro_physics_regression.gd
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --script tests/retro_filter_smoke.gd -- --benchmark
```

The graphical smoke saves images under `test-results/retro-stack`. It checks all 16 combinations, synchronized multiselect/checkbox state, unchanged HUD footer bytes, live uniforms, reset, F4/Shift+F4, paused-state preservation and F1 resizing. OFF must match the initial full frame exactly. Removing the adapter must restore identical world pixels; removing its toolbar button intentionally changes the footer layout.

The physics regression compares all 600 ticks of identical launch, steering and flipper input across eight fresh application processes: five single presets, live cycling, all effects stacked, and live stacking with resolution/CRT tuning. Position, velocity, score, rings, drain count and flipper angles must match exactly. Reusing one process for successive games produced collision differences even in an OFF-versus-OFF control; fresh processes avoid that fixture issue without relaxing equality.

The optional `--benchmark` uses the static scene, VSync disabled, no FPS cap, 90 warmup frames and 240 samples per effect or stack, then reverses the order. It includes Pixel+CRT and all four effects. Shader startup and screenshot readback are excluded. Reports distinguish wall-frame duration, CPU rendering time and GPU query results. These are local static-scene measurements, not a hardware-independent FPS claim or moving-game benchmark. For native GPU timestamps, use `--rendering-driver opengl3` and append `--native-report` after `--`.

## Startup defaults and fullscreen verification — 2026-10-25

The later Player View pass replaces the simple fullscreen toggle with a clean gameplay view. Graphical `tests/player_view_smoke.gd`: **49 checks, zero failures**, including native fullscreen/window restoration, maximized windows, development panel/overlay restoration, character study, 8,000 px/s upward observation probes at 30/60/120 Hz, three camera presets, three zoom levels, a 200 ms hitch, authored scaling and a live 1,800 px/s upward launch. The live launch remained inside the 22–78% vertical safety band. The same graphical suite and editor import passed in an isolated copy containing only this pass over committed code. Fullscreen screenshots were visually inspected.

Related checks: vertical camera **22/22**, authored main-game integration **70/70**, headless Retro adapter **68/68**, and exact 600-tick Retro physics replays **8/8**. Camera comfort and flipper timing still need human playtesting. F1 camera controls expose the provisional strict-Y/soft-X settings; Player View retains gameplay follow zoom instead of selecting overview.

Headless retro smoke: **68 checks, zero failures**. ANGLE rendered smoke: **103 checks, zero failures**, including the actual fullscreen button and F11 round-trip with window-size restoration. Authored main-game regression: **70 checks, zero failures**, including startup perspective, zoom controls, overview and fast-ball camera tracking. Exact 120 Hz physics replay: **8 checks, zero failures**. The startup preview was visually inspected. Sandbox runs emit the same certificate-store read warning documented below; no script or shader errors occurred. Fullscreen remains opt-in and runtime slider edits remain session-only.

## Expanded-range verification — 2026-10-25

Headless retro smoke: **66 checks, zero failures**. ANGLE graphical smoke: **98 checks, zero failures**. Exact 120 Hz physics replay: **8 checks, zero failures**, including fractional resolution changes during the run. Coverage includes 1.1/1.7 rendering sizes, F1 resizing, one-pixel phosphor cells, every slider's minimum and maximum, unchanged HUD pixels and full OFF/removal restoration. The live panel capture was visually inspected. Godot emitted a sandbox certificate-store read error at startup; no script, shader or rendering errors occurred. Tiny-cell aliasing and extreme-effect comfort remain manual judgments.

## Stacking milestone measurements — 2026-10-25

These measurements predate fractional resolution support and the expanded slider ranges. They cover default settings, not the newly exposed extremes.

Godot 4.7.2, Windows, NVIDIA GeForce RTX 4060, 1280×900. Each value averages the medians of forward/reverse blocks (480 sampled frames per configuration/backend).

| Configuration | Normal ANGLE frame ms | Native OpenGL frame ms | Native OpenGL GPU ms |
| --- | ---: | ---: | ---: |
| OFF | 16.13 | 7.01 | 1.40 |
| Pixel | 14.38 | 6.88 | 1.40 |
| N64-ish | 14.53 | 6.34 | 1.29 |
| CRT | 15.34 | 6.26 | 1.29 |
| VHS | 17.55 | 6.00 | 1.25 |
| Pixel + CRT | 15.45 | 6.24 | 1.31 |
| All four | 19.52 | 7.14 | 1.54 |

All four effects were the heaviest tested stack: roughly 3.4 ms higher wall-frame duration than OFF on ANGLE, and 0.14 ms higher native GPU time. These are noisy local observations, not isolated causal deltas; background application/editor work and forward/reverse variation remain. Lower single-effect numbers do not imply a speedup. The four-pass stack is optional, and each extra selection incurs another screen copy/pass. No renderer-wide optimization was introduced.

ANGLE reports zero for all GPU queries, meaning unavailable telemetry. Native OpenGL supplies the separate GPU measurements; the normal launcher remains on ANGLE. Full device metadata, CPU timings, P95 values and blocks: [ANGLE report](retro-captures/stacking/performance-angle.json), [native report](retro-captures/stacking/performance-native.json).

Verification for this update:

- Headless editor import: successful, empty stderr.
- Headless retro smoke: **60 checks, zero failures**.
- Graphical retro smoke: **89 checks, zero failures** on both ANGLE and native OpenGL. Current single, combined and live-panel captures inspected.
- Isolated 120 Hz physics replay: **8 checks, zero failures**, exact equality through all 600 ticks, including live stacking/tuning.
- OFF full-frame restoration and unchanged HUD footer bytes pass for all combinations. Adapter removal restores identical world pixels and removes its controls.

The earlier single-preset milestone also passed the existing authored-main (70 checks) and playable Green Hill (25 checks) suites; those longer suites were not rerun for this presentation-only update. Concurrent editor/gameplay work is excluded from this commit.

## Removal and scope

Remove the two retro preloads, two fields and installation block from `experiments/visual_lab/visual_lab.gd`, plus its F4 help text. Then remove `scripts/retro/`, `data/retro_settings.tres`, `third_party/retro/` and dedicated tests/docs. No presentation mesh, physics, character, camera algorithm, scoring or Act-loading source needs rewriting. Freeing the adapter at runtime restores its owned container properties and removes its effect canvas and controls.

See [shader provenance and license notices](../third_party/retro/README.md). Concurrent gameplay/editor changes and authored Acts are outside this change.

Manual review: switch during a fast ball run; judge ball/ring/flipper tracking with larger cells and brighter glow; try F1, pause, overview and an authored Act. Automated results do not establish subjective motion comfort.
