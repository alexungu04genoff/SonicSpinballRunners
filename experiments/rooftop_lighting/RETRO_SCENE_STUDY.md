# Rooftop Run: material comparison with the existing retro stack

This extends the uncommitted whole-scene experiment. The original scene, material strengths, lighting, exposure, geometry, collision state, and gameplay camera are retained. All four material variants are captured with retro disabled and with the project's saved retro stack enabled.

## Review

Run `RetroSceneReview.cmd` for live review. Keys 1–4 select None, Beveled, Faceted, and Hybrid. The retro checkbox enables the exact saved stack. The movement button repeats the same six-second camera sequence. Normal strengths and the earlier fixed cameras remain available. No restart is required.

Outputs are in `captures/retro-scene-study/`:

- `normal-comparison.png` and `retro-comparison.png`: four-way gameplay-camera stills.
- `normal-vs-retro-all.png`: four rows, one per material variant; normal rendering on the left, retro on the right.
- `normal-four-way-motion.mp4` and `retro-four-way-motion.mp4`: synchronized four-way motion comparisons.
- `<variant>-normal-vs-retro.mp4`: full-resolution side-by-side filter comparison for each material variant.
- `moving-frame-detail-sheet.png`: native-size crops from four points along the camera move.
- `validation.json` and `comparison-validation.json`: settings, exact trajectories, invariant checks, and image measurements.

## Exact filter settings

The worktree and main workspace have identical `data/retro_settings.tres` values. The enabled stack is **N64 → VHS → CRT**, matching `default_effects = [2, 4, 3]`.

| Setting | Value |
| --- | ---: |
| N64 resolution divisor | 1.9 |
| N64 color levels | 119 |
| N64 dither strength | 0.75 |
| VHS chroma offset / bleed | 0.9 / 1.1 |
| VHS wobble | 0.00015 |
| VHS grain | 0.055 |
| VHS tracking | 0.0045 |
| CRT cell size | 3.7 |
| CRT scanlines / RGB mask | 0.03 / 0 |
| CRT glow / radius | 0.19 / 2.1 |
| CRT brightness | -0.085 |
| CRT vignette | 0.28 |

Normal rendering uses the native 1280 × 690 world viewport. The retro stack renders at 673 × 363, then uses the existing linear, aspect-preserving upscaling behavior to produce the same 1280 × 690 output. The tiny source-aspect rounding is the existing filter's behavior. Camera transforms, projection, FOV, and exposure remain identical. The filter's own brightness/vignette is intentionally preserved, with no compensating exposure change.

## Motion and synchronization

Each clip contains 180 frames at 30 fps: one stationary second, four seconds of gentle lateral pan/dolly, then one stationary second. The move returns to the initial camera transform. Orientation and FOV stay fixed. The maximum offsets are 0.30 world units sideways, 0.40 downward, and 0.70 forward. The exact frame-by-frame path is shared across all eight sequences.

VHS contains deliberate time-dependent grain, wobble, and tracking. For fair comparisons, the experiment duplicates the VHS material in memory and supplies a replayable time uniform in place of `TIME`. Its math and all effect parameters remain unchanged. Stills use time 2.0; videos advance from time 2.0 in exact 1/30-second increments for every variant. Live review advances that uniform normally.

Unrelated canal shader animation is frozen at time 2.0 across all captures. No production shader file is edited. All gameplay and other presentation animation remain frozen as in the preceding material experiment.

The final output is captured through a separate 2D viewport using the existing filtered world texture and linear upscaling. This includes the actual shader stack rather than applying a simulated filter to a PNG. Review UI is excluded.

## Measurement limits

Clips are assembled from deterministic rendered frames. They are not real-time performance recordings; their 30 fps playback does not claim that rate on Android or any other device. H.264 review videos use CRF 16; lossless PNG source frames are retained for checking compression-sensitive grain.

Stationary-camera frame differences isolate temporal effects. A second check holds both the camera and the filter time fixed, so changing VHS noise cannot be confused with material instability. Broad material response is compared after a two-pixel low-pass filter within the central playfield. These measurements support comparison; they are not perceptual quality scores.

The recorded moving-material residual includes legitimate moving edges and is explicitly not a motion-compensated shimmer metric. Thin railguards, distant mortar, and diagonal edges still warrant an on-device gameplay review before choosing final settings.

## Results

- Broad bevel/facet shading remains visible through the stack. The central-playfield low-pass material differences retain approximately 84% (Beveled), 88% (Faceted), and 87% (Hybrid) of their unfiltered mean absolute RGB contrast. Spatial correlations are 0.85–0.89. These are regional image measurements, not percentages of perceived depth.
- Narrow bevels and fine joints become less distinct. The full Faceted treatment still shows its large triangular planes on architectural blocks; the filter does not erase that style choice. Hybrid keeps the more restrained architecture while retaining planar path response.
- The softened edges, color bleed, and grain make the presentation less pristine and can unify the low-poly look. The saved VHS grain is also conspicuous and can obscure the quieter material detail. This is a subjective tradeoff for review, not a selected default.
- All four unfiltered stationary holds were pixel-stable in the measured playfield region. Filtered consecutive-frame differences were 3.76 RGB levels for None and 3.77 for the three normal variants, on a 0–255 scale. The similar values show that the existing animated filter dominates stationary temporal noise.
- With camera and VHS time both held fixed, eight repeated full-output captures were byte-identical. The normal treatment does not introduce autonomous flicker in this controlled test.
- Moving-frame crops preserve the broad stone planes and ramp response throughout the path. Reduced-resolution edges and animated VHS noise remain visible concerns; this check does not establish that moving-camera shimmer is absent. Review the matching videos at native size, especially the railguards and distant floor.

Eight stills and eight six-second sequences were captured: 1,440 motion frames. Camera trajectories, VHS phases, lighting, exposure, normal strengths, filter settings, geometry, authored document, and ball identity checks passed. Live filter/mode/movement controls also passed. Runtime logs contain no script or shader errors. No production files were changed.

## Reproduction

Run `retro_scene_review.gd` with `-- --capture-retro-scene`, then run `compare_retro_scene.py` with Python, NumPy, Pillow, and the installed FFmpeg. Use `-- --retro-scene-controls-smoke` to check the live filter/mode/movement controls.

All changes remain in the experimental worktree. No commit or push.
