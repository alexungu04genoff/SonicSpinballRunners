# Act attachment stages — 2026-11-11

Prototype and Endless previously finalized each Act in one scheduler operation:
bind animations, collect/apply foreground atmosphere materials, collect/apply
local scenery materials, and capture foreground contribution bounds. That
combined job could block well beyond the scheduler's 1.5 ms budget.

These four existing operations now return to the scheduler separately. The
scheduler can continue cheap stages in the same frame, but checks its existing
deadline between them. Material ownership, shader programs, palette operations,
bounds calculation, lookahead, residency and warm-up policy are unchanged.
An individual stage can still overrun the budget; this does not make native
material duplication or bounds traversal incremental.

The Act remains hidden and disabled until all four stages finish. Restored
animations inherit the disabled staging parent, then recover their original
pausable behavior at activation. Explicit `PAUSABLE` animation roots otherwise
override a disabled ancestor and could animate during the longer preparation.
Physics authority and the 120 Hz update are unchanged. Current version-9 disk
bakes remain valid; this change does not alter their source pipeline.

## Measurements

Matching Godot 4.7.2, headless Linux, real disk-loaded three-Act Prototype,
seed 18, one Zone, Green Hill or Rooftop. Each theme ran in four separate
processes, ordered atomic / split / split / atomic. No other game tests ran
alongside them. The unsaved `--profile-atomic-attachment` control groups all four
stages into one operation, matching the previous scheduling. Both paths keep
the new animation hold and instrumentation.

| Theme | Original grouping: worst visual job per run | Separate stages: worst visual job per run |
| --- | --- | --- |
| Green Hill | 180.7, 122.6 ms | 100.3, 128.4 ms |
| Rooftop | 58.4, 48.9 ms | 55.5, 35.1 ms |

Every run prepared three resident Acts with zero runtime rebuilds. These are
elapsed method timings, including possible OS scheduling delays. The sample is
small and host variation is substantial: individual runs overlap, and total
preparation wall time is mixed. This is evidence for reducing accumulated work
in one job, not a claim of reduced total CPU work or Windows FPS gains.

A separate sequential seed-18 Green Hill tour, capped at 60 FPS and running at
400 px/s through sequence 3, measured maximum scheduler work of 105.1 ms with
atomic grouping and 64.9 ms with separate stages. Both recorded zero boundary
waiting and zero runtime rebuilds. An additional split-stage tour also recorded
zero boundary waiting. The [receipt](act-attachment-cpu/receipt.json) retains
all eight process aggregates, both controlled tour aggregates and source hashes.

A finer per-node material collection experiment was rejected. Although its
individual jobs were smaller, standalone fast tours introduced roughly
0.37–1.03 seconds of boundary waiting. The shipped implementation keeps the
existing complete-root material operation and only separates its surrounding
stages. Foreground material collection remains the main measured target for
future work; bounds, palette application and native creation can also spike.

## Reproduction

Use Godot 4.7.2 and current Prototype bakes for all three Acts listed in the
profiler, plus current Endless Green Hill bakes for the continuous tour. These
tools use the normal disk loader and fail on missing/stale recipes; do not use
`--no-bakes` for timing comparisons.

```sh
godot --headless --path . --script tools/profile_act_attachment.gd -- \
  --profile-stages --theme=green_hill \
  --output=res://test-results/attachment-split.json
godot --headless --path . --script tools/profile_act_attachment.gd -- \
  --profile-stages --theme=green_hill --profile-atomic-attachment \
  --output=res://test-results/attachment-atomic.json
godot --headless --path . --script tests/stream_material_tour.gd -- \
  --profile-stages --seed=18 \
  --output=res://test-results/attachment-tour.json
```

Repeat with `--theme=rooftop_run`, reverse process order, and keep other workloads
idle. The tour also accepts `--profile-atomic-attachment` for the same grouping
control. All diagnostic flags are process-local and write no player preferences.

## Validation and limits

The reuse regression checks stage boundaries, hidden/disabled preparation,
animation restoration and activation. The material regression compares complete
stored material properties, shader source, uniforms, slot coverage, palette
bases and restoration on real Green Hill, Rooftop and Chemical RampMania bakes,
including process frames between foreground and scenery attachment. This is
material-state evidence, not rendered pixel evidence.

Manifest, retirement, color ranges, foreground contribution, rail Rings, enemy
streaming, retry, HUD, scene smoke and Prototype appearance authority/freshness
checks pass headlessly: 606 assertions in total. The appearance check uses
RampMania across all eight themes (70 assertions); its default First Try Smooth
Decor fixture stopped at an existing missing/stale Chemical bake. Scene smoke
uses its explicit `--no-bakes --seed=2 --transitions=3` development path; it is
not part of the zero-rebuild timing comparisons. Actual Windows frame pacing and motion review remain
pending. Renderer-only surface/glow/foliage tests cannot validate pixels with the
headless dummy renderer and are not counted as passes. The existing upstream
threaded-loader exit leak remains separate; see [the lifecycle audit](LIFECYCLE_AUDIT.md).
