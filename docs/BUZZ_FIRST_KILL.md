# Buzz Bomber first-kill diagnostic

2026-11-04: the reported approximately two-second first-kill freeze **was not reproduced locally**. Inspection and a small Forward+/Vulkan comparison support runtime transparency as a plausible contributor, not a proven laptop root cause.

The default death effect now uses the same prebuilt sphere and opaque material, with a short pop/shrink instead of alpha fading. It allocates no shader, material, mesh or particle system on death. Enemy collision, score, Buddy rewards, death duration and respawn rules are unchanged. `--buzz-death-effect=legacy` restores the original expanding transparent flash, and `--buzz-death-effect=off` hides only that flash. The switches also work in ordinary gameplay when supplied after Godot's `--` separator.

## Path inspected

- `enemy_runtime.gd`: the swept physical contact atomically consumes the enemy, sets its existing death/respawn clocks and emits one destruction signal. There is no death-time resource load or particle creation.
- `game.gd`, `zone_run.gd`, `scorecraft.gd`, `buddies.gd`: synchronous scoring, telemetry, percentage bonuses and virtual Ring rewards operate on existing state. The opt-in `death_profiled` signal measures lifecycle mutation and the complete synchronous callback dispatch separately. It performs no printing or file I/O inside the measured callbacks.
- `score_overlay.gd`: an accepted award appends/merges a bounded popup dictionary. Drawing uses the existing fallback font; renderer first-use work can still occur after the CPU callbacks return.
- `score_sounds.gd`: audio players and synthesized streams are built at startup. An enemy uses the ordinary bumper cue, not a newly loaded enemy sound.
- `buzz_bomber_model.gd`: the flash is constructed before play, then becomes visible on death. Previously it set `GeometryInstance3D.transparency` above zero during its first fade. Godot documents that this forces the transparent pipeline in Forward+. The existing bake warm manifest fingerprints the initial opaque state, not that later transparent state. [Godot GeometryInstance3D documentation](https://docs.godotengine.org/en/stable/classes/class_geometryinstance3d.html#class-geometryinstance3d-property-transparency)

## Local comparison

Godot 4.7.2, Forward+/Vulkan, NVIDIA RTX 4060. Each mode ran in a fresh process with the same authored Buzz fixture, Prototype score/HUD/telemetry, audio and Dark Chao callbacks. Two real downward Ball contacts produced exactly 250 then 500 points, including the Buddy bonus. Startup settled for two seconds without showing the death effect.

| Mode | First-kill maximum frame interval | Second-kill maximum frame interval | First-kill draw / specialization / surface compilation counts | First-kill synchronous callbacks |
|---|---:|---:|---:|---:|
| Legacy transparent | 30.49 ms | 17.58 ms | 2 / 2 / 1 | 0.263 ms |
| Opaque fallback | 17.46 ms | 17.41 ms | 1 / 1 / 1 | 0.287 ms |
| Effect off | 18.19 ms | 17.44 ms | 1 / 1 / 1 | 0.240 ms |

All second-kill compilation deltas were zero. Lifecycle mutation took 0.003–0.004 ms. The extra first-kill draw/specialization in legacy mode is consistent with the transparent transition. Common first-use work remains even with the flash off; these counters alone cannot attribute it to a particular draw. Frame intervals are wall-clock observations, not isolated GPU timings. Driver caches were retained and other machine activity was not controlled. These numbers do not establish the cause of a two-second stall on another GPU.

Headless enemy integration passed 50 checks (including opaque/legacy/off visual-state checks); streamed enemy integration passed 31. The actual Vulkan diagnostic completed both physical kills in all three modes without script/render errors. No production Acts or bakes were rewritten.

## Work-laptop comparison

1. Double-click **Buzz Death Diagnostic.cmd**. Choose **2** for the original transparent effect. A small Prototype Act runs two automatic physical kills and exits; no manual aim or charge collection is needed.
2. Launch it again with **1** (current opaque fallback), then **3** (effect off). Use the same laptop power/GPU settings. Repeat in a different order if the result changes after the first launch; retained driver caches matter. Do not clear global driver caches for this test.
3. Compare the two kills within each run and the three effect modes. If only legacy stalls, the flash is implicated. If all modes stall, preserve the reports for investigating the common first-use work.
4. The console prints each sample and the JSON path. Reports go to `%APPDATA%\Godot\app_userdata\Sonic Spinball Runners\diagnostics\buzz-death-<mode>-<timestamp>.json`; launcher stdout/stderr also remain under `test-results/buzz-diagnostic-<mode>*.log`.

PowerShell equivalent, from the repository: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\buzz_death_diagnostic.ps1 -Effect legacy`. Supported values are `legacy`, `opaque`, and `off`; `-GodotPath` selects another installed Godot executable. This is a local diagnostic, not an export or release.
