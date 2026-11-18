# Launch Tube verification

The feature starts from pushed closure commit `5d160094673982414615a572e8e33098066c9bd7`. That closure passed **32/32 supported suites, 8,702 checks**, refreshed stale caches through the normal baker, and published separate verified [frozen UHD benchmark](https://github.com/alexungu04genoff/SonicSpinballRunners/releases/tag/uhd620-test-2026-11-19) and [closure Authoring Tools](https://github.com/alexungu04genoff/SonicSpinballRunners/releases/tag/authoring-tools-2026-11-18) releases before feature work began.

## Scope and execution

The only new Act is `data/acts/Experiments/Launch Tube Workshop.tres`. Production Acts, both production rosters, theme artwork, atmosphere defaults and Theme Life choices are unchanged. The tube is optional; no ordinary Act receives one automatically. [Architecture, controls, editor workflow and tuning](LAUNCH_TUBE.md) describe the resulting behavior.

Checks use Godot `4.7.2.stable.official.ed1daf0bf`, including real 120 Hz RigidBody2D integration and rendered Prototype/Endless sessions on the local RTX 4060. These are functional checks, not UHD 620 performance results. Visible engine runs use monitor 2 (`--position 20,30` in Godot's virtual-desktop coordinates). Editor gestures and key events are injected within the test engine; no desktop cursor control is used. Test profiles are isolated from personal preferences.

## Feature evidence

| Check | Result | Coverage |
| --- | --- | --- |
| Launch Tube core | 58 checks, 0 failures | Finite settings, authoring, H/V mirrors, clipboard identities, assemblies, persistence, path drag, Undo/Redo, real physics, weak rollback, medium/full speed difference, blocked exit and fresh-input latch |
| Prototype/Endless integration | 44 checks, 0 failures | Native X hold/release, Enter pause parity, finite Ball drain, same real ball, preserved score/objectives/timers, held-through-death rejection, ordinary retry delays, neighboring ownership, nonzero streaming offsets and owner teardown |
| Both modes across eight themes | 208 checks, 0 failures | Canonical disk-backed Prototype authority, live animation binding, charge/compression/spin, pulse/burst, configurable quiet feedback, unchanged terrain, no dynamic lights or particles |
| Existing editor interaction suite | 224 checks, 0 failures | All hardware placement/size/drag paths, including the new path object and its charge guides |
| Existing workspace suite | 266 checks, 0 failures | Shared transforms, filters, groups, locks, clipboard, recovery and persistence |
| External authored Tunnel smoke | PASS | Actual editor save/reopen, reduced feedback setting, ordinary Play Act source builder, weak/full launch and death-to-dock |

The three focused Launch Tube suites total **310 checks**. The two editor suites total **490 checks**. All assertions remain enabled. The interaction fixture explicitly handles the new path object; independent editor checks use separate profiles so saved selection/filter preferences cannot contaminate later tests.

The normal baker regenerated 56 Prototype variants, 56 Endless variants, 16 Exposed/Tunnel test variants and three supporting fixtures after the final feedback control. No receipt was manually blessed and no runtime fallback replaced a required disk recipe.

The final supported baseline passed **32/32 suites, 8,700 checks**, with no failed suite, script error or timeout. The two-check count difference from closure comes from the bake audit's material-dependent checks (566 rather than 568); audit assertions were not removed or weakened. The receipt includes 325 existing source-image warnings, four intentional negative-fixture errors, one intentional archive-failure warning and four ObjectDB exit-warning records. Native package results and the exact build SHA are recorded in the downloadable development release.

## Retained limitations and review

The integration test emits two native `RefCounted` ObjectDB exit warnings even though both watched tube owners are released. This report does not claim an engine cleanup fix. Existing source-image warnings and intentional malformed-resource/archive-failure diagnostics remain visible in the broader test logs. Capturing a frame intentionally stalls rendering; capture-time slow-frame messages are not performance measurements.

Human review is limited to charge pace, the medium/full speed spread, and feedback/readability in motion. Charge duration, speed range, resistance, return speed, width, Exposed height and feedback strength are editable. Feedback strength zero quiets the machine without changing traversal. The defaults remain confined to Acts that explicitly contain the object.

## Frozen benchmark preservation

The original Thursday ZIP still hashes to `84C18A4D1BC193374AD3084E2804457D1727228C3D6FB7721A39D9A8C22FE707`. The separate no-shell ZIP remains based on frozen source base `a5722d5c1a4396b930069c92e3edd6665695323b` plus its qualified diagnostic overlay, with wrapper source in closure commit `5d160094673982414615a572e8e33098066c9bd7`. All 4,082 protected payload files match the original, and the direct matrix completed 8/8 cases with unchanged arguments and time budgets. It was not rebuilt from Launch Tube or current main.

The frozen Visual Grounding Lab starts directly and produces its diagnostic report. Its ordinary window-close route has the documented frozen asynchronous-cleanup error; the wrapper correctly preserves that run as failed. No frozen code or failure criterion was changed. Keep failed and partial benchmark results. See [the closure report](CURRENT_MAIN_CLOSURE_2026_11_18.md) and the UHD release's README for the exact limitation and provenance.

## Publication

Use the separate development release for the refreshed Authoring Tools package. Its release notes and README identify the exact pushed main commit used for the build, supported baseline, native smoke results, ZIP checksum and GitHub download verification. The earlier UHD and closure releases remain immutable. Large ZIPs, derived bakes, test profiles and raw logs are not committed to repository history.
