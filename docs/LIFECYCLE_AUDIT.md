# Prototype lifecycle and shutdown audit

Baseline: `0d5934a10772f59d5d327bb5bbed79dc4f2ad2e8`, Godot **4.7.2.stable.official.ed1daf0bf**, Windows, Forward+/Vulkan on RTX 4060. Existing local artwork and Acts were preserved. This is an ownership audit, not a graphics-quality or streaming-performance change.

## Finding

The recurring plain `RefCounted` shutdown warnings are consistent with Godot's **threaded ResourceLoader LoadToken leak**. They are not evidence that the Prototype retains its Game or resident Act trees. However, they are also **not harmless shutdown-only noise**: the loader-only control and repeated sessions show persistent increases in ObjectDB count while the executable is still running.

Production cleanup remains unchanged. No warning was suppressed, no Resource was manually freed, and no engine-internal cleanup was invoked. An alternative loader is a separate streaming decision: the synchronous and ordinary-Thread controls are diagnostic comparisons, not shipped workarounds.

## Classification

| Warning/reproducer | Classification | Owner/root cause | Resolution |
| --- | --- | --- | --- |
| Prototype budget, rendered verbose process | C — engine-owned runtime allocation leak, reported at shutdown | Plain `RefCounted`, reference count zero; matches the loader-only signature. Historical one-instance count is not invariant. | Preserve the diagnostic; no fixture or production cleanup change. |
| Prototype archive, rendered verbose process | C — engine-owned loader leak | Archive exercises multiple ordinary run replacements and the real `_quit()` path. Archive files and notes do not retain runtime objects. | Preserve archive/error behavior. An interrupted 600-second attempt is explicitly not counted as a pass. |
| Input-only Prototype play profile | C — engine loader signature | Supported graphical profile closes via `Session._close_run()` and frees Session; one zero-reference RefCounted remains. | No profile-helper or production cleanup change. |
| Repeated disk-loaded sessions | Project ownership clean in the measured course; C for residual ObjectDB growth | All observed Game/Act/cache/atmosphere owners release. Node/orphan counts and renderer signal connections return to baseline. | Add a focused ownership regression with weak references and process-lifetime measurements. |
| Loading one baked resource without Session/Game | C — Godot ResourceLoader | Threaded requests reproduce zero-reference `RefCounted` leaks; synchronous and ordinary-Thread controls isolate the engine worker-pool path. | Keep a small reproducible loader diagnostic. Do not claim the engine leak is fixed. |
| Dead device-registration entries and compiled-script caches | D — bounded process-lifetime bookkeeping/cache | RenderingOptions stores WeakRefs, prunes them on registration, and does not retain retired targets. Script/resource counts plateau after initial use. | Document; no global cache-clearing hack. |

No class-A project leak or class-B premature fixture exit was demonstrated by these reproductions. This conclusion is scoped to the observed supported paths, not every historical diagnostic script.

## Same-process results

The focused lifecycle regression completed **six runs across three Session instances**, with **33 checks / zero failures**. All tracked runtime references were already null immediately after `Session.return_to_menu()` closed the run. Eight additional frames changed neither that result nor the classification; extra waits in the budget/archive fixtures would not fix these objects.

| Observation | Before any Session | After runs 1–2 | After runs 3–4 | After runs 5–6 |
| --- | ---: | ---: | ---: | ---: |
| Nodes | 1 | 1 | 1 | 1 |
| Orphan Nodes | 0 | 0 | 0 | 0 |
| Resources | 141 | 144 | 144 | 144 |
| ObjectDB objects | 1,646 | 1,698 | 1,700 | 1,702 |
| Live registered views/lights | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 |
| Render pre/post-draw connections | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 |
| Window close connections | 1 | 1 | 1 | 1 |

Initial use includes engine/font/script bookkeeping and six bounded WeakRef slots; compare the warmed columns rather than treating every first-use object as a leak. The subsequent **+2 objects per two runs** matches the **six** zero-reference RefCounted instances printed at process exit. The per-run menu resource count also stays at 144; each live run retains the intended three Acts. This is a stable project-owned baseline, **not** a flat total engine-object baseline. Long-duration heap-byte growth was not measured.

The same final loader probe gives a direct control comparison:

| Loading mode, six loads of the same Green Hill/RampMania bake | Objects after load 1 → load 6 | Resources after warm-up | Shutdown leaked instances |
| --- | --- | ---: | ---: |
| `load_threaded_request(..., true)` | 1,540 → 1,550 | 45, stable | 17 |
| `load_threaded_request(..., false)` | 1,531 → 1,531 | 43, stable | 0 |
| Main-thread `ResourceLoader.load()` | 1,531 → 1,531 | 43, stable | 0 |
| Ordinary `Thread` calling `ResourceLoader.load()` | 1,531 → 1,531 | 43, stable | 0 |

The distributed-loader experiment reproduced 17 shutdown instances twice. Turning off subthreads is a clean control for this graph, not a universal fix: the upstream report also documents other failing graphs with that flag off. Neither it nor a custom worker replacement is shipped here; loading concurrency and streaming latency would need their own validation. The production warning therefore remains unresolved on this engine version.

## Warning counts and scope of the result

Budget completed twice with **57 checks / zero failures** each and **17 / 5** leaked instances. The count is not a stable project contract: this suite chooses courses, and engine dependency scheduling also matters. Every printed leak was plain RefCounted with reference count zero. Archive completed twice with **34 checks / zero failures** each and **seven / seven** such instances, including an isolated repeat without competing diagnostics, matching the historical report. The six-run ownership probe printed six. The existing `prototype_play_profile.gd` completed 120 normal input-driven physics ticks with zero runtime rebuilds and reproduced **one** such instance. Its shortened one-second observation is lifecycle/startup evidence, not a performance or gameplay-feel result.

There is **no production before/after fix claim**. Before and after this audit, production uses the same loader and can emit these warnings. The clean 17→0 contrast above belongs only to alternate loading-mode controls. Added files are diagnostic/regression probes and documentation; existing budget/archive fixtures and production code are unchanged.

Raw verbose logs retain every instance ID. For example, the repeated-session process reported `9223372589714376570` and five later IDs, all plain RefCounted at zero references. IDs are process-local observations, not stable identifiers or evidence of a particular gameplay object.

## Actual ownership

| System | Natural owner and retirement evidence |
| --- | --- |
| Session/Game | `Session._close_run()` flushes notes, awaits `Game.prepare_to_close()`, frees Game and clears its field. The game waits for in-flight library work. The archive test already invokes the real Session `_quit()` path. |
| Resident Acts and contribution | Resident `StreamedAct` owners belong to Game. Contribution objects retain computed bounds; temporary material/shader inspection dictionaries clear after capture. Actual retirement removes the Act and queues its trees. Visibility suppression is not retirement and was not changed. |
| Warm recipes/cache/physics | TemplateLibrary owns cached recipes and prepared detached nodes. Its `_exit_tree()` joins fingerprint jobs, collects primed loads, frees detached warm nodes and cached physics roots. StreamedAct releases only its still-detached prepared nodes on destruction. Warm reuse remains intact. |
| Backgrounds/Atmosphere | Each Zone backdrop owns its SubViewport, lighting and Atmosphere runtime. Atmosphere owns private Environment/material bindings. Weak observations verify those owners and private resources release on session close. |
| RingField/mechanics | RingField is a Game child; Act mechanics belong to Act roots. Mechanics exit resets transient state and clears the ball's matching mechanics reference. Neither registry survives its owner in the measured runs. |
| Rendering/device settings | Static `_views` and `_lights` arrays contain WeakRefs. In the repeated course, three view slots and three light slots remain bounded; live targets become zero. These shells are distinct from the plain zero-reference objects in the shutdown log. |
| Signals/callables | The Game's render-pre-draw connection disappears on close. Menu render-post-draw and Session window-close connections disappear with their Nodes. Recreated sessions do not accumulate these connections. |
| Telemetry/archive | Telemetry is run-owned; results are plain serialized data. Archive writes, flushes, closes, renames and removes its temporary reservation synchronously. The note debounce is a Session-child Timer. There is no asynchronous archive worker to drain. |

## Engine attribution

The [confirmed upstream issue #120661](https://github.com/godotengine/godot/issues/120661) reports the same zero-reference signature and variable counts, including reproduction on Godot 4.7.2 with correctly paired threaded requests/gets. In the [4.7.2 ResourceLoader source](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/core/io/resource_loader.cpp), worker completion paths call `load_task.load_token->unreference()` without deleting the token when it returns true (lines 468 and 623). The user-facing collection path handles that return correctly. [Upstream PR #121025](https://github.com/godotengine/godot/pull/121025) addresses this engine ownership defect.

The [native LoadToken declaration](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/core/io/resource_loader.h) derives directly from RefCounted without registering a separate class name. That explains the generic class in verbose output; instance IDs alone do not expose a native allocation stack. Attribution is strongly supported by the matching source defect, object-count drift and isolated loader controls, rather than by claiming a debugger stack was captured.

This attribution combines source inspection with local controls; it is not based solely on finding a similar issue title. The loader probe creates no Session, Game, live Act, archive, viewport or atmosphere owner. It loads and releases the same existing validated bake six times. The top-level Resource's WeakRef becomes null every time. Threaded loading still increases non-Resource ObjectDB count and emits the same shutdown signature. Main-thread and ordinary-Thread loading are controls for the ownership path, not performance measurements.

An initial synthetic graph of sixteen Gradient preloads did not reproduce the warning. That negative result is preserved in local logs; the final probe defaults to the actual baked dependency graph that does reproduce it.

## Reproduction

Use fresh isolated user-data directories and Godot's `--verbose` output. Record stdout and stderr separately; leaked class/instance IDs appear in verbose stdout while the ObjectDB warning appears in stderr.

```powershell
Godot.exe --path . --rendering-method forward_plus --rendering-driver vulkan --verbose --script res://tests/prototype_budget_regression.gd
Godot.exe --path . --rendering-method forward_plus --rendering-driver vulkan --verbose --script res://tests/prototype_archive_regression.gd
Godot.exe --path . --rendering-method forward_plus --rendering-driver vulkan --verbose --script res://tests/prototype_lifecycle_regression.gd
Godot.exe --path . --rendering-method forward_plus --rendering-driver vulkan --verbose --script res://tests/resource_loader_lifecycle_probe.gd -- --loader-mode=threaded
```

Loader controls accept `threaded_single`, `synchronous` and `plain_thread`. Use `--loader-output=res://test-results/lifecycle-audit/<unique-name>.json` to keep each report. An optional `--loader-resource=` chooses another existing resource without modifying it. The ownership regression accepts `--lifecycle-output=` and uses three Session instances, two supported runs each, three resident Acts and ordinary menu/Results transitions. It records references immediately after the real close and again after eight normal frames; the latter observe deferred work rather than perform cleanup. They are not extra sleeps added to production or existing fixtures.

Local raw evidence is under `test-results/lifecycle-audit/` and `test-results/regression-debt/lifecycle-*`. These probes do not change production settings: 4× MSAA, 100% render scale, current shadows, foreground rules, cameras, physics, score and all artwork remain unchanged.

## Executed checks and retained evidence

The supported baseline passed again: **32 suites / 8,596 checks / zero assertion failures**, plus six fresh-process geometry reload checks. [Verification receipt](lifecycle-audit/verification.json) lists each suite and raw log hash. Forward+/Vulkan covered budget/archive, foreground contribution (26), warmed visual reuse (127), Prototype setup (16), run (143), appearance (70), traversal Prototype and the other graphical baseline suites. The 40-variant Prototype bake audit passed 425 checks. Headless results were used only for the established nonvisual suites and bake validity, not as graphical cleanup evidence.

Additional evidence:

- [Shutdown counts, leaked classes/IDs and raw-log hashes](lifecycle-audit/shutdown-counts.json).
- [Six same-process runs and 33 ownership checks](lifecycle-audit/repeated-sessions.json).
- [Distributed loader](lifecycle-audit/loader-threaded.json), [single-worker pool control](lifecycle-audit/loader-threaded-single.json), [main-thread control](lifecycle-audit/loader-synchronous.json), [ordinary-Thread control](lifecycle-audit/loader-plain-thread.json).
- [Supported input-only play profile summary](lifecycle-audit/play-profile-summary.json), retained for lifecycle context; no performance conclusion is drawn from this run.

The first archive attempt exceeded a 600-second harness allowance while other diagnostics were running. It was interrupted and contributes neither a passing result nor a shutdown leak count. Completed repetitions and the baseline are recorded separately. Initial probe type-inference errors were corrected before counted executions. Expected blocked-archive/malformed-resource errors, Windows root-certificate diagnostics and verbose Vulkan loader messages about the installed Overwolf layer were retained, not hidden or treated as project ObjectDB ownership failures.

Before staging, all 23 pre-existing tracked diffs matched the initial snapshot, and no pre-existing untracked path disappeared. Production scripts, authored content, art, graphics preferences and existing fixtures were not edited.
