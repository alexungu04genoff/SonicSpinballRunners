# Three-Act playable prototype

Run **Sonic Spinball Runners.exe** from the Windows build. No Godot installation or repository is required for that build. In the source checkout, run **Play Prototype.cmd** with Godot 4.7.2 installed; it prepares missing bakes on first launch. Run **Bake Prototype.cmd** after changing the Acts or presentation sources.

Choose Sonic, Tails, Knuckles or Shadow, then start the run. Each Act has its own earned score and physical exit. The provisional targets are **1,000, 1,500 and 2,000**. Reaching a target opens that Act's exit; you still have to pass through it. Activating the next Act resets local score to zero while preserving cumulative score. The third exit ends the run and shows the three Act results.

Drains and manual checkpoint retries preserve earned points and open score exits. Retries are unlimited. Restarting the run clears both score totals. This is a short score-gated progression prototype using authored Acts and the shared streaming engine. Finite attempts, Buddy drafts, shops and a failure economy are future design work.

| Action | Keyboard | Controller |
| --- | --- | --- |
| Flippers | Q / E | LB / RB |
| Steer | Left / right arrows | Left stick |
| Launch | Enter | X |
| Character special | Space | A |
| Checkpoint retry | R | Back / View |
| Pause / resume | Escape | Menu / Start |
| Fullscreen | F11 | — |

The menu saves character choice, sound preference, best completed score and fastest completion time in Godot's user-data folder. Pause provides resume, restart, menu and quit. Short synthesized cues identify scoring, feature completion, exit unlocks, Act changes and drains.

The three source Acts live in `data/prototype/`. A central ring rack provides a repeatable scoring route. The second Act adds a switch bank, gate and spinner; the third adds lane scoring, a raised rail and a dash panel. These are compact proof-of-flow layouts, with provisional score balance and shot placement. Existing standalone Act play, editor workflows and the published Endless roster remain available separately.

## Source verification and Windows export

The deterministic session check is `tests/prototype_run_regression.gd`. It tests the real menu and streaming lifecycle, injects feature awards to isolate scoring transitions, and verifies pause, checkpoint persistence, final results and clean replay. `tests/prototype_route_probe.gd` separately surveys the physical route using production steering, flipper and checkpoint inputs; it does not inject points or move the ball directly. Human testing is still needed for flipper timing, camera readability, character balance and sound comfort.

Export with `tools/export_prototype.ps1 -WindowsTemplate <path-to-matching-Windows-release-template>`. The script creates a separate source snapshot, imports it, bakes its three Acts, exports an embedded Windows executable and creates a zip under `test-results/prototype-build/`. It does not download a template or publish a release. Use a template matching the installed Godot version, since baked validation includes the engine version. Logs stay beside the snapshot.

The snapshot enables a small export plugin that retains source PNGs alongside imported textures. This preserves the existing bake fingerprints instead of bypassing runtime validation. Before creating the zip, the exporter runs `tests/prototype_package_regression.gd` against the executable's embedded resources to check the menu entry point, theme and all three Act bakes.

Verified on 2026-10-28: 28 session checks passed in the isolated staged source, rendered source and rendered embedded package; the existing Endless scoring regression passed 30 checks. The input-only route cleared all three Acts in 53.6 simulated seconds with two drains, both from source and from the rendered package. That is automation evidence, not an expected human completion time. First graphics preparation took about 72 seconds in the simultaneous package tests; subsequent opening preparations took about two seconds. Startup time, frame hitches, layout balance, sound comfort and human playability still need review. The environment emitted a Windows certificate-store warning; the headless baked renderer also emitted existing motion-trail dummy-renderer errors, while rendered package checks passed without script or rendering errors.
