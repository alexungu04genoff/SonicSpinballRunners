# Material attachment slices — 2026-11-11

Prototype and Endless now spread live Act material collection across scheduler
steps, while allowing the existing library worker to prepare the next queued
variant. The Act stays hidden and disabled until its materials, animations and
bounds are ready. Startup retains synchronous material attachment.

## Implementation

Material collection targets 800 microseconds per step, checking time after each
complete node. Traversal order, material-slot ownership, private copies and the
attachment-scoped shader inspection cache are retained. Emission and palette
application run in a separate final step using the latest atmosphere values.
The original synchronous API still serves authoring, shared sky and startup.
No shader program, material value, light, shadow setting or physics rule changes.

The 1.5 ms live scheduler budget remains in place. These are cooperative budgets:
a native material operation, palette application or bounds capture can overrun
them. Library preparation also consumes CPU time, so a small live scheduler slice
does not imply an equally small total frame.

While an Act collects materials, the idle library worker can request the first
pending variant within the existing five-Act lookahead. It reserves cache space
first and protects the requested, resident and currently attaching Acts from
eviction. The worker remains serial; cache limits stay at eight variants and
three themes. Normal activation still consumes the pending queue. Optional
theme preparation also protects the attaching Act.

Splitting collection without overlapping the next load introduced 0.27–0.43 s
of boundary waiting in two trials. Those trials were rejected. Keeping the
inspection cache across slices avoids repeated shader queries; starting the
queued load before attachment finishes prevents that serial delay in the
verified tours below.

## Measurements

Pinned Godot 4.7.2, headless Linux, real current disk bakes, seed 18. Runs were
sequential with other game tests idle. Each theme used four fresh-process pairs
of three-Act Prototype preparation and a 400 px/s Endless tour, ordered
whole / sliced / sliced / whole. Four additional Rooftop tours checked its
variable frame results. The unsaved whole-material control also disables the
new request overlap. All runs retain the previous separation of animation,
foreground, scenery and bounds stages.

| Theme | Whole-material maximum live scheduler work per tour | Sliced maximum per tour |
| --- | --- | --- |
| Green Hill | 78.9, 88.4 ms | 15.5, 24.4 ms |
| Rooftop | 27.7, 44.2, 44.7, 29.4 ms | 20.6, 36.3, 24.6, 16.3 ms |

All **12 fixed-theme tours** reach sequence 3 with zero boundary waiting and zero
runtime rebuilds. Peak cached variants remain four or five, with one theme.
Two additional Green Hill-to-Rooftop tours also finish without waits or rebuilds;
maximum live scheduler work is 58.9 ms whole versus 18.1 ms sliced, and maximum
frame intervals are 66.5 versus 36.5 ms. These are one paired transition sample.
All eight Prototype profiles prepare three resident Acts with zero rebuilds.
Prototype preparation wall times are 2.93–3.24 s whole versus 1.95–1.99 s sliced
in Green Hill, and 1.88–2.24 s versus 2.22–2.28 s in Rooftop. Total preparation
time is therefore mixed, rather than a general loading-speed improvement.

The tour also samples complete frame intervals at a 60 FPS cap. Green Hill's
maximum intervals are 80.4/91.5 ms whole versus 50.2/36.6 ms sliced. Rooftop's
whole intervals are 45.1/47.4/72.3/35.2 ms, versus 35.2/96.9/92.5/30.2 ms sliced:
**Rooftop whole-frame improvement is not established.** One sliced run also
records a 71.3 ms physics-template compilation call. Physics compilation,
native material operations, bounds and graphics preparation can still spike;
overlap can put library and live work in the same frame.

These are elapsed CPU measurements with host scheduling variation. They do not
measure Windows GPU performance or guarantee hitch-free gameplay. Retain the
full result ranges when evaluating this change; lower material-job maxima alone
do not establish better whole-game frame pacing.

[The receipt](material-attachment-slices/receipt.json) retains the per-process
aggregates, source hashes, initial rejected trials and validation results.

## Correctness and reproduction

The material regression compares all stored material properties, program source,
uniforms, slot coverage, palette bases and restoration across all eight themes.
It forces one-node collection slices and crosses process frames. It also edits
values during collection and checks that completion applies those latest values
while preserving shared private copies.

Reuse checks cover hidden/disabled preparation, separate collection/application,
startup throughput and activation. Prefetch checks cover busy workers, cache
reservation failure, already-cached variants, startup, stage eligibility,
lookahead, queue ownership and protection of attaching resources. The targeted
suite passes **750 assertions** across 15 cases, including cache/manifest/
retirement, palette ranges, HUD, retry, rail Rings, enemies, foreground
contribution and all-eight-theme disk-backed Prototype authority. Enemy and
scene smoke checks use their explicit development `--no-bakes` path; timing
comparisons use normal disk bakes. No engine or script errors occur in the final
suite. The existing threaded-loader ObjectDB shutdown warning remains separate.

Use Godot 4.7.2 with current bakes and run each command separately:

```sh
godot --headless --path . --script tools/profile_act_attachment.gd -- \
  --profile-stages --theme=green_hill --output=res://test-results/sliced.json
godot --headless --path . --script tools/profile_act_attachment.gd -- \
  --profile-stages --theme=green_hill --profile-whole-material-attachment \
  --output=res://test-results/whole.json
godot --headless --path . --script tests/stream_material_tour.gd -- \
  --profile-stages --theme=green_hill --seed=18 \
  --output=res://test-results/sliced-tour.json
```

Add `--profile-whole-material-attachment` to the tour for the previous behavior,
or `--next-theme=rooftop_run` for an alternating two-theme course. Repeat in
reverse order. `play.*` timings are the in-play subset of `live.*`; do not add
those overlapping counters together. All controls are process-local.

**Current version-9 bakes remain valid; no new rebake is needed for this change.**
Windows motion review and driver/frame-time profiling remain outstanding.
