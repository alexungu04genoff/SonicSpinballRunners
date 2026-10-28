# Three-Act playable prototype

Run **Sonic Spinball Runners.exe** from the Windows build. No Godot installation or repository is required for that build. In the source checkout, run **Play Prototype.cmd** with Godot 4.7.2 installed; it prepares missing bakes on first launch. Run **Bake Prototype.cmd** after changing the Acts or presentation sources.

Choose Sonic, Tails, Knuckles or Shadow, then start the run. Each Act has its own earned score and physical exit. The provisional targets are **1,000, 1,500 and 2,000**. Reaching a target opens that Act's exit; you still have to pass through it. Activating the next Act resets local score to zero while preserving cumulative score. The third exit ends the run and shows the three Act results.

Challenge starts every Act with **three balls, including the ball in play**. Drains and manual retries spend one ball while preserving earned points, open score exits and the acquired build. Losing the third ball ends the run. Clearing an Act refreshes the next Act's budget to three. Retrying before launch or during an existing respawn cannot consume another ball. Practice mode keeps unlimited retries and separate records. Restarting clears all score, Buddy and budget progress.

After physically clearing Acts 1 and 2, choose one of three Buddies. Gameplay pauses for the choice and resumes the same ball position and velocity. The choices are currently fixed so the small prototype can test distinct scoring routes:

| Buddy | Level 1 bonus | Level 2 bonus |
| --- | --- | --- |
| Ring Scout | +10 per ring | +20 per ring |
| Bumper Coach | +75 per bumper award | +150 per bumper award |
| Feature Fox | +250 per completed rack, switch bank, spinner goal or lane set | +500 per completion |

Picking an owned Buddy upgrades it to level two. Bonuses are flat additions after existing combo/special scoring and do not add combo links, timer refreshes or special charge. They never pay for zero-point sources or ordinary spinner ticks. The HUD shows the current build and included Buddy bonus; success and failure results show each Buddy's contribution, Act totals and ordinary scoring. Amounts and the three-ball budget are provisional. Shops, bosses, more Buddy effects and permanent progression remain future work.

| Action | Keyboard | Controller |
| --- | --- | --- |
| Flippers | Q / E | LB / RB |
| Steer | Left / right arrows | Left stick |
| Launch | Enter | X |
| Character special | Space | A |
| Checkpoint retry (spends a ball in Challenge) | R | Back / View |
| Pause / resume | Escape | Menu / Start |
| Fullscreen | F11 | — |

The menu saves character choice, Practice preference, sound preference, best completed score and fastest completion time in Godot's user-data folder. Challenge and Practice records are separate; records from the earlier unlimited prototype migrate to Practice. Failed runs do not replace completion records. Pause provides resume, restart, menu and quit. Short synthesized cues identify scoring, feature completion, exit unlocks, Act changes and drains.

The three source Acts live in `data/prototype/`. A central ring rack provides a repeatable scoring route. The second Act adds a switch bank, gate and spinner; the third adds lane scoring, a raised rail and a dash panel. These are compact proof-of-flow layouts, with provisional score balance and shot placement. Existing standalone Act play, editor workflows and the published Endless roster remain available separately.

## Source verification and Windows export

The deterministic session check is `tests/prototype_run_regression.gd`. It tests the real menu and streaming lifecycle, injects feature awards to isolate scoring transitions, and verifies drafts, pause, checkpoint persistence, final results and clean replay. `tests/prototype_budget_regression.gd` covers the retry input, finite failure, duplicate drain protection, contribution accounting and Practice isolation. `tests/buddy_scoring_regression.gd` checks bonus ordering and upgrade/reset behavior. `tests/prototype_route_probe.gd` separately surveys the physical route using production steering, flipper and checkpoint inputs and valid draft choices; it does not inject points or move the ball directly. Human testing is still needed for flipper timing, camera readability, character balance and sound comfort.

Export with `tools/export_prototype.ps1 -WindowsTemplate <path-to-matching-Windows-release-template>`. The script creates a separate source snapshot, imports it, bakes its three Acts, exports an embedded Windows executable and creates a zip under `test-results/prototype-build/`. It does not download a template or publish a release. Use a template matching the installed Godot version, since baked validation includes the engine version. Logs stay beside the snapshot.

The snapshot enables a small export plugin that retains source PNGs alongside imported textures. This preserves the existing bake fingerprints instead of bypassing runtime validation. Before creating the zip, the exporter runs `tests/prototype_package_regression.gd` against the executable's embedded resources to check the menu entry point, theme and all three Act bakes.

Verified on 2026-10-28 with Godot 4.7.2: Buddy scoring 13/13, session flow 39/39, ball budgets and Practice 23/23, existing Scorecraft 29/29, Endless scoring 30/30 and warm manifests 30/30. The exported Windows resources passed all 11 package checks plus the rendered 39-check session and 23-check budget suites. The three new/updated gameplay suites also passed from a clean staged-source copy without local artwork changes. All 56 existing Endless bake variants were refreshed and passed 447 audit checks. An input-only Challenge route cleared all three Acts with both drafts in 63.4 simulated seconds, losing three balls across the run; this confirms a viable route, not balanced difficulty for human players.

Startup now batches up to four cold material features per loading-screen draw, while live streaming retains its one-feature limit. The opening preparation used 18 draw frames instead of 48 in the recorded comparison. Separate fresh-profile runs still took about 69–74 seconds overall, dominated by resource loading and cold shader compilation; this is not a demonstrated reduction in cold wall-clock startup time. Warm runs remain much faster. No shader variants, validation checks or artwork were omitted. The environment can emit a Windows certificate-store warning; the headless baked renderer also has existing motion-trail dummy-renderer errors. Use rendered checks for presentation verification.
