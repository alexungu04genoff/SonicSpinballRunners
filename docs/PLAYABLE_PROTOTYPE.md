# Two-Zone playable prototype

The prototype camera uses zoom 1.3 and a vertical target 55% down the screen. The compact HUD uses 18/16-point headings/body text and a 35%-opaque backing; control instructions remain in the menu instead of covering gameplay. Window resizing and F11 fullscreen expand to the display aspect ratio, including ultrawide, instead of letterboxing the original canvas. Rendered checks covered 1600×900, 1920×810 and native 1920×1200 fullscreen on 2026-10-30.

Run **Sonic Spinball Runners.exe** from the Windows build. No Godot installation or repository is required for that build. In the source checkout, run **Play Prototype.cmd** with Godot 4.7.2 installed; it prepares missing bakes on first launch. Run **Bake Prototype.cmd** after changing the Acts or presentation sources.

Choose Sonic, Tails, Knuckles or Shadow, then start the run. **Green Hill** contains three Acts with provisional targets of **1,000, 1,500 and 2,000**. **Chemical Plant** follows with three more Acts targeting **2,500, 3,000 and 3,500**. Reaching a target opens that Act's exit; you still have to pass through it. Activating the next Act resets local score while preserving cumulative score and Buddies. The sixth exit ends the run and shows results for both Zones.

Every start, replay or restart draws a fresh random order from the `.tres` files directly in `data/acts/Authored/`, with no repeated Act within the six-Act run. The current pool contains First Try Smooth Decor, RampMania, Reverse C Spring, Second Simple, Secret Entry and SpringUp, so all six appear once. If more Acts are added, six are selected without replacement; fewer than six or incompatible connectors produce a startup error. The two themes retain their fixed order. The seed appears in pause and results; launch Godot with `-- --seed=18` to reproduce a particular order for debugging.

Challenge starts every Act with **three balls, including the ball in play**. Drains and manual retries spend one ball while preserving earned points, open score exits and the acquired build. Losing the third ball ends the run. Clearing an Act refreshes the next Act's budget to three. Retrying before launch or during an existing respawn cannot consume another ball. Practice mode keeps unlimited retries and separate records. Restarting clears all score, Buddy and budget progress.

After physically clearing each nonfinal Act, choose a Buddy, for five drafts in a complete run. Gameplay pauses for the choice and resumes the same ball position and velocity, including at the Zone boundary. The catalogue remains small so the prototype can test distinct scoring routes:

| Buddy | Level 1 bonus | Level 2 bonus |
| --- | --- | --- |
| Ring Scout | +10 per ring | +20 per ring |
| Bumper Coach | +75 per bumper award | +150 per bumper award |
| Feature Fox | +250 per completed rack, switch bank, spinner goal or lane set | +500 per completion |

Picking an owned Buddy upgrades it to level two; fully upgraded Buddies leave the available choices. At least one choice remains through all five drafts. Bonuses are flat additions after existing combo/special scoring and do not add combo links, timer refreshes or special charge. They never pay for zero-point sources or ordinary spinner ticks. The HUD shows the current build and included Buddy bonus; success and failure results show each Buddy's contribution, a scrollable Act breakdown and ordinary scoring. Amounts and the three-ball budget are provisional. Shops, bosses, more Buddy effects and permanent progression remain future work.

| Action | Keyboard | Controller |
| --- | --- | --- |
| Flippers | Q / E | LB / RB |
| Steer | Left / right arrows | Left stick |
| Launch | Enter | X |
| Character special | Space | A |
| Checkpoint retry (spends a ball in Challenge) | R | Back / View |
| Pause / resume | Escape | Menu / Start |
| Fullscreen | F11 | — |

The menu saves character choice, Practice preference, sound preference, best completed score and fastest completion time in Godot's user-data folder. Two-Zone Challenge and Practice records are separate from each other and from the earlier three-Act records, which remain preserved in the settings file. Failed runs do not replace completion records. Pause provides resume, restart, menu and quit. Short synthesized cues identify scoring, feature completion, exit unlocks, Act changes and drains.

The source Acts stay unchanged: run-local targets and score-exit hardware are applied to the streamed instances. Their source fingerprints and bake validation remain authoritative. Existing standalone Act play, editor workflows and the published Endless roster retain their own rules. The old three scoring demonstration layouts remain in `data/prototype/` but are not selected by this run.

**All six Acts are baked in both themes**, because any Act can occupy either Zone: 12 Act variants plus two shared theme bakes. `Bake Prototype.cmd` uses the same roster as the run. The launcher also prepares missing bakes or Acts saved after their last bake; run the explicit bake command after presentation changes. Normal play loads the baked collisions, visual recipes, optimized mesh batches and warm-up metadata. The existing loader rejects stale bakes instead of rebuilding geometry during gameplay. GPU uploads and driver shader compilation still happen at runtime; offline bakes do not eliminate every first-launch or streaming stall.

## Source verification and Windows export

`tests/prototype_plan_regression.gd` checks folder discovery, seeded shuffling, no repeats, connector alignment, source preservation and all five draft opportunities. The deterministic session check is `tests/prototype_run_regression.gd`. It tests the real menu and streaming lifecycle, injects awards to isolate scoring transitions, and verifies both Zones, physical score gates, drafts, pause, checkpoint persistence, final results and clean replay. Normal baked runs also assert zero runtime rebuilds and use of both theme bakes. `tests/prototype_budget_regression.gd` covers retry input, finite failure, duplicate drain protection, contribution accounting and Practice isolation. `tests/buddy_scoring_regression.gd` checks bonus ordering and upgrade/reset behavior. The input-only `tests/prototype_route_probe.gd` remains a limited steering heuristic, not proof that every authored route is beatable. Human testing is needed for the six-Act score curve, flipper timing, camera readability, character balance and sound comfort.

Export with `tools/export_prototype.ps1 -WindowsTemplate <path-to-matching-Windows-release-template>`. The script creates a separate source snapshot, imports it, bakes every authored Act in both themes, exports an embedded Windows executable and creates a zip under `test-results/prototype-build/`. It does not download a template or publish a release. Use a template matching the installed Godot version, since baked validation includes the engine version. Logs stay beside the snapshot.

The snapshot enables a small export plugin that retains source PNGs alongside imported textures. This preserves existing bake fingerprints instead of bypassing runtime validation. Before creating the zip, the exporter runs `tests/prototype_package_regression.gd` against the executable's embedded resources to check the menu entry point, authored-folder discovery, both themes and every Act/theme combination, including validated collisions and warm-up metadata.

Verified on 2026-10-30 with Godot 4.7.2: authored planning 37/37; rendered two-Zone session 80/80; ball budgets, Practice and preserved legacy records 25/25; Buddy scoring 13/13; existing Scorecraft 29/29; existing Endless scoring 30/30; warm manifests 30/30. A clean staged-source checkout passed planning 37/37 and the generated-fixture session 79/79. The Windows package passed all 40 source/bake checks and its rendered 80-check session suite. Both baked session runs loaded all six selected Act variants and both theme bakes with zero runtime geometry rebuilds. Menu, Zone transition, Buddy draft and scrollable results captures were visually checked. The earlier three-Act input-only playthrough does not establish difficulty or completion times for this new authored pool; human playtesting of its score curve remains necessary.

Startup batches up to four cold material features per loading-screen draw, while live streaming retains its one-feature limit. Earlier three-Act measurements reduced opening draw frames from 48 to 18 but still took about 69–74 seconds on fresh profiles, dominated by resource loading and cold shader compilation. The new two-Zone rendered check likewise showed cold shader stalls while preparing Chemical Plant; baked data is not a guarantee of stall-free play. Warm runs remain much faster. No shader variants, validation checks or artwork were omitted. Some environments can emit a Windows certificate-store warning; the headless baked renderer also has existing motion-trail dummy-renderer errors. Use rendered checks for presentation verification.
