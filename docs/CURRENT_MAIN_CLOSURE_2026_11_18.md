# Current-main closure — 18 November 2026

## Scope and starting state

Started from pushed `main` at `06bbfec20e2e0b9e564136d5ba17a79c20c6bffb`, with no tracked changes. Godot is `4.7.2.stable.official.ed1daf0bf` (engine hex `263938`), using Forward+/Vulkan on the development RTX 4060 for rendered checks. This is not the UHD 620 result.

Evidence is retained locally under `test-results/current-main-closure-20261118/`. That ignored directory contains the original logs, raw fingerprints, protected-file hashes, isolated tracked-source snapshot, isolated profiles, generated bakes, extracted packages and screenshots. The 647 pre-existing unrelated untracked files were inventoried, backed up and checked byte-for-byte after the live import. None changed.

Production themes remain Green Hill, Chemical Plant, Rooftop Run, Casino Night, Sky Sanctuary, Ice Cap, Lava Reef and Aquarium Park. The seven Theme Life registry entries remain C. Lava has no candidate registry entry or controller. Rooftop A, Casino B and Sky A remain recommendations only. Production Acts, atmosphere files, graphics defaults, theme source and artwork are unchanged.

Visible checks target the second, non-primary monitor. An initial native editor launch exposed a coordinate mismatch: WinForms uses negative primary-relative coordinates here, while Godot uses the virtual desktop's top-left. The incorrect launch was closed and repeated with Godot's verified `(20, 30)` position on screen 0. The direct launcher translates those coordinate systems, and editor Play/Bake children inherit their parent editor's Godot position. Later checks use background commands without cursor control, as requested.

## Reproduced failures before refresh

The complete supported baseline reproduced **29/32**, before refreshing any production recipe. All three failures independently classify as **D — stale derived cache**. The rejected files existed, deserialized, retained matching Act/scenery fingerprints and valid collision/warm receipts, but their common pipeline fingerprint was old. No test assertion was changed.

| Suite | Original result | Rejected cache |
| --- | --- | --- |
| `prototype_setup` | 16 checks, 1 failure | All-eight setup rejects Lava; its first selected Act is `data/acts/Authored/DropTarget-SW-SP-DT.bake/lava_reef.res`, and the shared Lava recipe is also stale. |
| `prototype_appearance` | 55 checks, 1 failure | Representative `data/acts/Authored/First Try Smooth Decor.bake/lava_reef.res` and `data/endless/themes.bake/lava_reef.res`. |
| `endless_bake_audit --prototype` | 56 variants, 566 checks, 8 failures | Shared Lava recipe plus the seven Prototype Lava recipes listed below. |

Expected Lava pipeline SHA-256:

`89447e6232331ea6d7210ae9c4cf29d935f1fad21897f0ae5fa2dc7043f041fc`

Actual Prototype/shared Lava pipeline:

`1b7c987d7ba922eb0ddfe982b384a13d9efd083b54d2fa18461a9d497c3ebe45`

Actual Endless Lava pipeline:

`c28e86ce4725305e040f7c6c76ade24c878a411b224fec738e1af31b27a0d305`

The live pre-refresh inventory found **15 stale of 121 inspected recipes**: seven Prototype Lava, seven Endless Lava and one shared Lava. The other 106 were fresh. Exact paths are:

```text
data/endless/themes.bake/lava_reef.res
data/acts/Authored/DropTarget-SW-SP-DT.bake/lava_reef.res
data/acts/Authored/First Try Smooth Decor.bake/lava_reef.res
data/acts/Authored/GateDash.bake/lava_reef.res
data/acts/Authored/RampMania.bake/lava_reef.res
data/acts/Authored/Reverse C Spring.bake/lava_reef.res
data/acts/Authored/Secret Entry.bake/lava_reef.res
data/acts/Authored/SpringUp.bake/lava_reef.res
data/endless/second_simple.bake/lava_reef.res
data/endless/third_complex.bake/lava_reef.res
data/endless/first_try_smooth_decor.bake/lava_reef.res
data/endless/ramp_mania.bake/lava_reef.res
data/endless/reverse_c_spring.bake/lava_reef.res
data/endless/secret_entry.bake/lava_reef.res
data/endless/spring_up.bake/lava_reef.res
```

The isolated snapshot reproduced the three failures after a completed fresh import and preservation of the starting raw bytes of `assets/ui/hud/sources.json`. Git archive normalizes that JSON's CRLF to LF, while the cache hashes non-code files as raw bytes. An initial incomplete import and an aborted archive-encoding attempt are retained separately as setup/tooling evidence, not counted as the reproduced baseline. Correcting the snapshot's byte fidelity made its fingerprints match the live checkout exactly.

## Why Lava became stale

`GeometryBake.pipeline_hash()` hashes the bake version, engine version and recursively referenced shared presentation/compiler/recipe sources and assets. Theme Life exclusion controls candidate bindings; it does not exempt Lava from shared serialization and pipeline changes.

The exact Theme Life dependency change from pre-pass `ecbe1b8` is:

```text
warm_manifest.gd (unchanged source, traversed dependency)
  -> visual_recipe.gd (changed serialization)
     -> static_batches.gd (changed batching)
     -> theme_motion/registry.gd (new referenced dependency)
```

With the starting raw asset metadata preserved, pre-pass pipeline `6a23767cadbcae917c5ca8c8b1d558b6ee0929866bac06b7486f343f6473868f` changes to current `89447e...`. Shared warm-manifest source itself did not change. Contribution/culling code is not a visited Lava dependency in this trace. Godot `.import` metadata is excluded. Lava-specific source did not change.

The actual Lava caches were already older than that pass. The Prototype/shared `1b7c...` fingerprint exactly matches the historical source at `5dd8d4ae3435355631c319579f7d9dceb3fa0e19`, the latest matching commit found; this identifies compatible source, not a claimed original bake commit. Eighteen dependencies differ from current source: the shared Act geometry, selection, history, terrain and gameplay-object helpers; runtime compiler, gimmick models, mechanics presentation, pinball mechanics and teleporter; enemy runtime/model; presentation/themed presentation; visual recipes/static batching; and the newly referenced motion registry.

The Endless `c28e...` fingerprint exactly matches the preserved `test-results/authoring-tools/source-20261109-231840` source. Later common geometry, gimmick-shadow, template presenter, ring-spin/shader, HUD and shared asset changes also invalidate that older pipeline. Broad referenced asset-directory hashing includes some shared assets outside Lava's own art. This is cumulative shared pipeline drift, not a Lava artwork defect and not solely the Theme Life commit.

## Refresh and disk authority

Used the existing authoritative baker, in sequence:

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path <isolated-source> res://scenes/act_baker.tscn -- --prototype
& 'C:\Program Files\Godot\Godot.exe' --headless --path <isolated-source> res://scenes/act_baker.tscn -- --pool
```

The runner waits for each actual process to exit before advancing. Prototype refreshed **7 Acts × 8 themes = 56** combinations; Endless refreshed **7 × 8 = 56**. The traversal and Side to Side smoke fixtures each refreshed Green Hill once: **114 total requested/refreshed**, **0 reused Act/theme combinations**, **0 failures**. Offline generation is intentional; there are no disk-hit substitutions or runtime fallback builds in this refresh. Shared theme recipes, content-addressed assets, warm manifests, collision receipts and pipeline fingerprints come from the normal baker.

Both audits pass **56 variants / 568 checks / 0 failures**. The post-refresh isolated and live-checkout inventories each report **121 fresh / 0 stale**. Verified derived directories were installed back into the live checkout without deleting unrelated cache files. All remain ignored; no generated bake is committed.

One representative current Act, `First Try Smooth Decor`, passes **324 rendered checks across all eight themes**: source/scenery/pipeline freshness, offline collision receipts, actual 2D collisions, authored hardware and Goal, Default atmosphere, private Zone environment/material ownership and close-time owner release. Exactly **8 Act + 8 shared-theme disk hits**, **0 fallback builds**. Lava has no Theme Life binding. Canonical captures are in `source/test-results/closure-authority/` within the evidence directory.

Existing startup diagnostics already identify stale Act/theme data and direct developers to **Bake Prototype.cmd** or **Bake Endless.cmd**. No automatic rebake, permissive stale acceptance, duplicate bake implementation or assertion relaxation was added.

## Integration and C parity

- Theme Motion contract: **35 checks**, custom batching: **8 checks**, both zero failures.
- Exact pre-pass constructor parity: **38 geometry variants**, zero failures.
- C shader parity: **30 fixed-time samples**, zero failures; actual maximum channel delta and mean delta are both **0**. One initial run crashed in native Vulkan/NVIDIA readback at `BLIT_PASS`; an unchanged rerun completed. Both attempts remain available.
- All seven included themes launch C/NATIVE with diagnostic time `-1`; diagnostic A/B followed by C restores exact transforms and native shader parameters without changing gameplay/camera state or writing player preferences. Lava follows its original path.
- Disk-loaded Side to Side: **17 checks**, zero failures, covering camera selection, moving bumper, chute direction/scoring and zero fallback.
- Editor Act playtest: **15 checks**, zero failures, covering Goal, Results, seeded Replay and return to the Act-test menu with the chosen camera. This intentionally uses the editor's source-preview path.
- Source editor smoke: PASS for bundled Act open, disposable external save/reopen, exact `(12.5, -3.25)` transform, group, Undo/Redo, recovery checkpoint and actual Prototype play/teleporter behavior.
- Prototype lifecycle: **39 checks**, zero failures. Run/session owners, live device registrations, Node counts and orphan counts return to the checked baseline. The process still emits six native ObjectDB exit instances; that warning is not hidden or claimed fixed.
- Normal Endless seed 18: **15 checks**, zero failures. Tour speed **100**, simulation scale **1**; natural sequences 0–3 cross Sky Sanctuary into Green Hill. Default atmospheres, four crossfade buckets, opening-Act retirement, bounded caches and close ownership pass. **6 Act / 3 theme disk hits**, **0 fallback builds**, **0 boundary-wait frames**. This is a functional smoke, not a performance claim.

## Final baseline, native portable and handoff

The final supported baseline completed **32/32 suites, 8,702 checks, zero assertion failures, zero timed-out suites and zero script errors**. This total includes the six fresh-process Act reload checks, individually printed pinball-vocabulary checks and the twelve unconditional profile checks. The formerly failing setup, appearance and Prototype bake-audit suites now pass 16, 70 and 568 checks respectively.

All final normal disk-authority probes have zero runtime fallback builds. Source-preview and deliberately malformed/stale test fixtures remain intentional tests, not a fallback workaround.

Warnings remain separate from assertion status:

- 325 existing raw-image resource warnings from source material loaders. The portable exporter deliberately retains raw PNGs as well as imported textures; native packaged behavior is checked below.
- Four ObjectDB exit-warning lines: Prototype archive **7 instances**, foreground contribution **1**, Prototype budget **1**, Prototype run **6**. Project-owned lifecycle checks pass; native cleanup is not declared fixed.
- Four expected negative-fixture error lines: three malformed-Act load errors and one deliberately unwritable archive path. The archive test also emits its expected fallback-to-copy warning.
- No additional native ResourceLoader shutdown warning appeared in this final baseline. The previously documented warning remains unresolved; this closure does not claim a loader fix.
- The separate shader parity attempt had the native readback crash described above; its unchanged successful retry is preserved alongside it.

The full portable ZIP is **271,024,517 bytes**, SHA-256 `82B513ABE01C768989F0A98D2EBF03CE366745E7FC4B85CA3F2B11E0406298AA`. Its source and embedded-PCK bake audits each pass 568 checks. The fresh extraction contains the direct Geometry Editor and Atmosphere Lab executables, all eight full-suite launchers including Environmental Motion Lab, and no personal preferences, recovery files, Acts or results.

The actual extracted Geometry Editor EXE passes its complete portable workspace smoke, including save/reopen, group/exact transforms, Undo/Redo, recovery and Prototype play. Native Motion Lab opens, switches C to A, advances diagnostic time and saves its capture under the portable profile. A subsequent native ordinary Prototype starts the seeded disk-loaded course, opens Results and replays the same course. The actual editor Play button starts its native child on the corrected second-monitor position. The native Prototype UI run emits 64 ObjectDB exit instances; those remain recorded separately from functional success. No script errors appeared. Manual charging/feel is not claimed from that UI run.

Using the matching Godot engine with the extracted EXE as `--main-pack`, the same profile after the Lab passes **324 packaged checks across all eight themes**: ordinary C/NATIVE/time `-1`, exact restoration after A/B, Lava exclusion, private materials, collision authority, eight Act/eight shared-theme disk hits, no fallback, no preference writes and observed owner release. This explicitly tests packaged code; it is not mislabeled as an arbitrary-script invocation supported by the release EXE. An earlier unsupported release-CLI script attempt is retained as setup evidence.

## Frozen Thursday package and separate no-shell edition

Original archive: `test-results/grounding-20261117/Sonic Spinball Grounding Thursday 2026-11-19 final.zip`, **207,485,508 bytes**.

Original SHA-256 before this task:

`84C18A4D1BC193374AD3084E2804457D1727228C3D6FB7721A39D9A8C22FE707`

The separate direct-EXE edition is built only from that frozen archive. **4,082 retained payload files** independently match the original ZIP, the new ZIP and its fresh extraction, including binaries, tests, source, assets, bakes and build manifests. Sixteen shell/build-tool files are omitted; there are **zero `.cmd`, `.bat` or `.ps1` files** in the new ZIP. Independent comparison confirms all **eight matrix command plans** match the frozen cases, with only paths and second-monitor placement adjusted.

The two small .NET Framework launchers use `ProcessStartInfo.UseShellExecute=false`, an `asInvoker` manifest, explicit redirected output and isolated profiles. They never invoke CMD/PowerShell, request elevation, modify the registry, install dependencies or change security policy. Every generated application file goes under adjacent `Results`; the verified frozen payload stays immutable. Case durations, total budget and failure handling are retained. See [Thursday laptop instructions](THURSDAY_LAPTOP_TEST.md) for usage.

The verified no-shell archive is **185,076,039 bytes**, SHA-256 `10D223B6FF6A671FF2089822CC1653AEA39427A1F876DDED01FF4416D0E459D6`. The original ZIP and all 17 protected original archives/launchers/manifests retain their starting hashes, including the original ZIP hash above. The frozen manifest records source base `a5722d5c1a4396b930069c92e3edd6665695323b` plus a separately qualified diagnostic overlay with file hashes; it is not described as a clean checkout of that base alone.

The actual extracted **Run Work Laptop Matrix.exe** completed **8/8 original cases**, exit 0, zero diagnostic failures, zero runtime fallback builds and zero retained project owners on the development RTX 4060. Observed children were the frozen engine directly, with no shell process between wrapper and engine. Forward+/Vulkan, Mobile/Vulkan and Compatibility/ANGLE all ran. ANGLE's first startup was slower; its case completed in 233.92 seconds, within the unchanged 420-second limit. These are functional delivery checks, not UHD 620 performance results. Existing native exit warnings remain in Results.

The actual extracted **Visual Grounding Lab.exe** also starts the frozen interactive Prototype directly. It reaches `GROUNDING_READY`, writes its report with zero diagnostic failures/fallbacks/preference writes and releases its observed owners. An ordinary window-close request exposes a **frozen cleanup error**: `Resumed function 'prepare_to_close()' after await, but class instance is gone`, at frozen `endless_game.gd:770`. Both the Lab and embedded Prototype session subscribe to the root window-close signal; their asynchronous cleanup paths overlap. The engine exits 0, but the wrapper correctly marks this run failed and exits 1 because stderr contains `ERROR:`. The entire failed receipt is retained. The frozen code and failure rule are not modified. Direct startup is verified; clean window-close behavior for this frozen Lab is not claimed. Its existing Escape control follows the Lab's own close route rather than the shared root signal; that route was not automated during this check because the user requested no cursor control.

An initial fresh extraction on E: failed while copying the runtime because that drive filled. Its partial receipt is retained. Automatic approval review rejected deleting redundant task copies without supplying a detailed reason; no copies were removed. Verification continued in a fresh C: task folder with sufficient space. Nothing in the frozen benchmark was weakened or modified to work around this setup failure.

The reproducible build-machine verifier, `tools/verify_grounding_no_shell.py`, independently checks original/new/extracted payload bytes and the exact eight command plans. It is not shipped and adds no work-laptop dependency. Native execution uses a medium-integrity user token and `asInvoker` launchers.

## Package paths and publication

Closure Authoring Tools ZIP:

`E:\Sonic Spinball Runners\test-results\current-main-closure-20261118\source\test-results\authoring-tools\Sonic Spinball Authoring Tools-20261118-214440.zip`

Separate no-shell ZIP:

`E:\Sonic Spinball Runners\test-results\current-main-closure-20261118\Thursday No Shell 2026-11-19 release.zip`

The portable's 3,421 tracked runtime input files match the closure source: 3,137 byte-identical and 284 differing only in existing CRLF/LF normalization. No source-content mismatch was found. Bakes and export configuration remain generated artifacts.

The closure commit contains the portable Motion Lab route/output/export integration, editor child-position inheritance, direct-EXE wrapper/manifest/build verifier, monitor guidance and closure documentation. It contains no ZIP, generated bake, benchmark output or personal data. The 647 pre-existing untracked files remain byte-identical. Five new import-generated Theme Life UID files remain untracked rather than absorbing unrelated importer output into this commit.

GitHub release records identify the exact pushed closure SHA and carry checksums and short instructions. The frozen benchmark and normal development portable use separate releases: `uhd620-test-2026-11-19` and `authoring-tools-2026-11-18`. The final handoff supplies their verified links and upload/download receipts. Optional Launch Tube work starts only after this closure is pushed and the releases are verified.
