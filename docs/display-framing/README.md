# Display framing review evidence

[Full report and integration notes](../DISPLAY_FRAMING.md) · [Interactive local comparison](index.html)

Base: `5ceab0c5a3b86eac3dbc239763867e39976ef2c2`. Branch: `codex/display-framing-contract`. Main is not modified.

Matrix captures are **framing reconstructions**, uniformly scaled from the measured logical canvas. They are not native 4K font-quality or FPS evidence. Review copies have a maximum width of 1280 pixels; requested dimensions remain in filenames. [Image manifest](images.json) records original/review dimensions and SHA-256. Raw full-size images remain in the isolated worktree under `test-results/display-framing/{before-final,after-final-retry}`.

Both sides pin seed 18, the same real ball, Act, score and Default atmosphere. All 128 paired states match exactly. All 64 ordinary 16:9 rows retain identical camera/projection, normalized landmarks, HUD heading bounds and rendering settings. Every fixed row has zero landmark drift. Shader-time animation may vary between captures.

[Before receipt](before.json) · [After receipt](after.json) · [128-row CSV](matrix.csv) · [Native receipt](native.json) · [Crossfade receipt](transitions.json) · [Verification summary](verification.json)

## Prototype: Dramatic camera

| Client size | Before: Expand | After: fixed 16:9 |
| --- | --- | --- |
| 1280x720 | ![Before 1280x720](before/prototype-1280x720-camera2.jpg) | ![After 1280x720](after/prototype-1280x720-camera2.jpg) |
| 1920x1080 | ![Before 1920x1080](before/prototype-1920x1080-camera2.jpg) | ![After 1920x1080](after/prototype-1920x1080-camera2.jpg) |
| 2560x1440 | ![Before 2560x1440](before/prototype-2560x1440-camera2.jpg) | ![After 2560x1440](after/prototype-2560x1440-camera2.jpg) |
| 3840x2160 | ![Before 3840x2160](before/prototype-3840x2160-camera2.jpg) | ![After 3840x2160](after/prototype-3840x2160-camera2.jpg) |
| 2560x1080 | ![Before 2560x1080](before/prototype-2560x1080-camera2.jpg) | ![After 2560x1080](after/prototype-2560x1080-camera2.jpg) |
| 3440x1440 | ![Before 3440x1440](before/prototype-3440x1440-camera2.jpg) | ![After 3440x1440](after/prototype-3440x1440-camera2.jpg) |
| 1600x1200 | ![Before 1600x1200](before/prototype-1600x1200-camera2.jpg) | ![After 1600x1200](after/prototype-1600x1200-camera2.jpg) |
| 1280x900 | ![Before 1280x900](before/prototype-1280x900-camera2.jpg) | ![After 1280x900](after/prototype-1280x900-camera2.jpg) |

### Camera presets at 1280×720

| Camera | Before | After |
| --- | --- | --- |
| Dramatic | ![Before Dramatic](before/prototype-1280x720-camera2.jpg) | ![After Dramatic](after/prototype-1280x720-camera2.jpg) |
| Wide | ![Before Wide](before/prototype-1280x720-camera3.jpg) | ![After Wide](after/prototype-1280x720-camera3.jpg) |
| Real Pinball | ![Before Real Pinball](before/prototype-1280x720-camera1.jpg) | ![After Real Pinball](after/prototype-1280x720-camera1.jpg) |
| Top-down | ![Before Top-down](before/prototype-1280x720-camera0.jpg) | ![After Top-down](after/prototype-1280x720-camera0.jpg) |

## Endless: Dramatic camera

| Client size | Before: Expand | After: fixed 16:9 |
| --- | --- | --- |
| 1280x720 | ![Before 1280x720](before/endless-1280x720-camera2.jpg) | ![After 1280x720](after/endless-1280x720-camera2.jpg) |
| 1920x1080 | ![Before 1920x1080](before/endless-1920x1080-camera2.jpg) | ![After 1920x1080](after/endless-1920x1080-camera2.jpg) |
| 2560x1440 | ![Before 2560x1440](before/endless-2560x1440-camera2.jpg) | ![After 2560x1440](after/endless-2560x1440-camera2.jpg) |
| 3840x2160 | ![Before 3840x2160](before/endless-3840x2160-camera2.jpg) | ![After 3840x2160](after/endless-3840x2160-camera2.jpg) |
| 2560x1080 | ![Before 2560x1080](before/endless-2560x1080-camera2.jpg) | ![After 2560x1080](after/endless-2560x1080-camera2.jpg) |
| 3440x1440 | ![Before 3440x1440](before/endless-3440x1440-camera2.jpg) | ![After 3440x1440](after/endless-3440x1440-camera2.jpg) |
| 1600x1200 | ![Before 1600x1200](before/endless-1600x1200-camera2.jpg) | ![After 1600x1200](after/endless-1600x1200-camera2.jpg) |
| 1280x900 | ![Before 1280x900](before/endless-1280x900-camera2.jpg) | ![After 1280x900](after/endless-1280x900-camera2.jpg) |

### Camera presets at 1280×720

| Camera | Before | After |
| --- | --- | --- |
| Dramatic | ![Before Dramatic](before/endless-1280x720-camera2.jpg) | ![After Dramatic](after/endless-1280x720-camera2.jpg) |
| Wide | ![Before Wide](before/endless-1280x720-camera3.jpg) | ![After Wide](after/endless-1280x720-camera3.jpg) |
| Real Pinball | ![Before Real Pinball](before/endless-1280x720-camera1.jpg) | ![After Real Pinball](after/endless-1280x720-camera1.jpg) |
| Top-down | ![Before Top-down](before/endless-1280x720-camera0.jpg) | ![After Top-down](after/endless-1280x720-camera0.jpg) |

## Actual native windows on monitor 2

These capture the complete native client rectangle, including bars, with Canvas Items active. Fullscreen is the actual 1920×1200 secondary monitor. Native cases additionally cover 1280×720, 1600×900, 1280×900 and F11 restoration. Pointer events are injected inside Godot; the desktop cursor is never moved.

| Mode | 960×720 | 1440×600 | F11 1920×1200 |
| --- | --- | --- | --- |
| prototype | ![4:3](native/prototype-4x3.jpg) | ![Ultrawide](native/prototype-ultrawide.jpg) | ![Fullscreen](native/prototype-fullscreen.jpg) |
| endless | ![4:3](native/endless-4x3.jpg) | ![Ultrawide](native/endless-ultrawide.jpg) | ![Fullscreen](native/endless-fullscreen.jpg) |

## Zone seam at 50% blend

Actual foreground and two background layers, Green Hill / Casino Night. The test samples 0, 25, 50, 75, 100, 50 and 0% travel at 16:9, ultrawide and 4:3, including reversal. These two images use the matrix reconstruction method.

![Prototype seam](transitions/prototype-ultrawide-seam.jpg)

![Endless seam](transitions/endless-ultrawide-seam.jpg)

## Checks actually run

| Suite | Checks | Result |
| --- | ---: | --- |
| Legacy framing matrix | 605 | PASS |
| Fixed framing matrix | 861 | PASS |
| Native input / F11 | 250 | PASS |
| Prototype / Endless Zone seams | 556 | PASS |
| Contract lifecycle | 24 | PASS |
| Exact display physics traces | 3 | PASS |
| Existing camera picker | 9 | PASS |
| Existing Retro physics traces | 8 | PASS |
| Existing Endless planner | 845 | PASS |
| Existing Endless reuse | 131 | PASS |
| Existing Prototype run, seed 18 | 162 | See limitation |

Passing suites total: **3,292 assertions**, counting the before and after diagnostic matrices separately. The additional existing Prototype run passes **161/162**, with the OS clipboard check failing. This is a targeted display qualification, not a rerun of the full supported 32-suite baseline.

The unchanged Prototype run assertion at seed `4141928365` also fails on untouched parent: full-precision exported `-0.08499999999999996` versus default-precision expected `-0.085`. Configuration and fingerprint match; full-precision course comparison matches. Both seed-18 attempts report `Unable to open clipboard` at the OS clipboard check. Failed attempts and native ObjectDB exit warnings remain in local logs; no production behavior or assertion was weakened.

One repeated matrix capture crashed in native Godot/NVIDIA code with lost-device `UI_PASS` / `BLIT_PASS` breadcrumbs. The unchanged final retry passes all 861 checks. Cause is not proven; repeated readback stability and GPU performance are not qualified by this branch.

## Reproduction

Use Godot 4.7.2 with imported assets and fresh normal Prototype/Endless disk bakes. The same shared HUD source bytes must be used when baking and running; raw JSON line-ending changes can invalidate copied caches. These checks require no new test dependencies.

Use a disposable `APPDATA`/`LOCALAPPDATA` profile. Graphical tests must be positioned on monitor 2. On the qualification host, Godot screen 0 / virtual position `20,30` is that non-primary monitor. The native fixture explicitly chooses the first non-primary display and keeps its own window above others for client readback.

```powershell
$env:APPDATA = Join-Path $env:TEMP "ssr-display-review-profile"
$env:LOCALAPPDATA = $env:APPDATA
$godot = "C:/Program Files/Godot/Godot.exe"
$project = (Get-Location).Path
& $godot --path $project --position 20,30 --script res://tests/display_framing_matrix.gd -- --legacy-layout --output=res://test-results/display-review/before
& $godot --path $project --position 20,30 --script res://tests/display_framing_matrix.gd -- --expect-fixed --output=res://test-results/display-review/after
& $godot --path $project --position 20,30 --script res://tests/display_framing_native.gd
& $godot --path $project --position 20,30 --script res://tests/display_framing_transitions.gd
& $godot --headless --path $project --script res://tests/display_framing_regression.gd
& $godot --headless --path $project --script res://tests/display_framing_physics.gd
```

`--legacy-layout` exists only in the diagnostic fixture. It releases the prototype contract and reproduces parent scaling; it is not a shipping setting. An initial matrix also ran before any runtime source edit. All 128 of its camera/projection, landmark, logical/render-size and quality records match the final legacy fixture. The fixture retains the same camera code and real disk-backed authored data. Existing regression filenames and arguments are recorded in `verification.json`.

Review only: accept or reject the fixed reference composition and bars. No merge or production release is performed by this branch.
