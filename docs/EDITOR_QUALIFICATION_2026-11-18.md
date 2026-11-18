# Act Geometry Editor qualification — 18 November 2026

This qualifies the November 17 editor work and fixes four reproduced defects. It
does not change production Acts, gameplay tuning, graphics defaults, grounding
diagnostics, atmosphere, shadows, Retro settings or textures. Test Acts, user
profiles, bakes and package extraction are isolated from normal authoring data.

The final supported baseline passes all 32 suites. The refreshed portable ZIP was
extracted and its actual Windows executable passed the extended editor/Prototype
smoke. Native-input coverage and the remaining manual checks are separated below.

## 1. Starting source and environment

- Starting local and pushed `main`: `1e19af39a10ff90dd4eb817317fcf6781fafad6f`.
- While qualification was paused, remote main advanced through four commits to
  `c57c2bdb1b9a175ef5148ca029c3eee59b38be53`. Its moving bumper/score chute, anchored
  quick sizing, camera picker and seeded replay changes were preserved. The shared
  tree was fast-forwarded after backing up only this task's tracked edits; two
  overlapping test expectations were resolved without dropping either change.
  Final qualification and packaging use that integrated source plus the four fixes.
- Godot: `4.7.2.stable.official.ed1daf0bf`, Windows x64. Rendered checks use the
  existing Forward+/Vulkan configuration.
- The shared tree had no tracked edits at capture; 627 unrelated untracked
  import/UID/cache files were preserved.
- A fresh tracked-source archive was extracted to
  `E:\Sonic Spinball Runners\test-results\editor-qualification-20261118\source`.
  This is current main, not the older frozen grounding package. The initial 942
  source/data/scene/test files compared byte-for-byte with the archive.
- Real editor import passed. Explicit dependency loading passed for all 190
  production GDScript and scene dependencies. Each destructive/recovery suite
  uses a separate `APPDATA`/`LOCALAPPDATA` profile; only its restart phase reuses it.
- Local receipts are under
  `E:\Sonic Spinball Runners\test-results\editor-qualification-20261118`.
  `starting-state.json`, `starting-source-hashes.json` and the original logs retain
  the initial state and failure evidence.
- After integration, all 951 tracked/new script, scene, data and test files match
  the shared source. There are 119 archive-versus-checkout line-ending differences
  and no content differences; bake fingerprinting already normalizes carriage returns.

## 2. Failures reproduced before fixes

The supported 32-suite baseline ran before production code edits, after all 113
required private Act/theme bakes were rebuilt. It passed 29 suites and failed 3.
The lifecycle follow-up below was found later, after integrating the new replay
feature; it is separate from that initial baseline.

| Class | Reproduction | Diagnosis / closure |
| --- | --- | --- |
| A — production | `core-before-5`: 9 failures, three malformed source-history cases tested through validation, save and load | Invalid primitive footprint, out-of-range scale and non-normalized offset were accepted. Saved composite payload validation was also completed. |
| A — production | `exact-before`: typed size/target values acquired `.001` | SpinBox minimum `.001` and step `.01` were misaligned. The existing approximate no-op guard already kept untouched 100% from dirtying an Act. |
| A — production | Decor smoke: entered `1.1` became `1.105` | Minimum `.125` and step `.01` were misaligned. |
| A — production | `border-before-2`: 3 failures; actual toolbar mirror also rejected a valid border placement | Affine decomposition changed scale/rotation precision. Recomputing the center pivot on successive mirrors exposed the boundary drift. |
| B — stale expectation | `authored_gimmick`: 93 checks, 1 failure | Recipe comparison omitted now-explicit optional defaults such as triangle reflection and flipper length. Resolve both sides through the authoritative property schema. |
| B — stale expectation | `enemy`: 2 failed assertions followed by an index error | Patrol editing intentionally moved from Shift to Ctrl+Shift; proportional sizing replaced older fixed increments. Current code and documented gestures agree. |
| B — stale expectation | `prototype_run`: missing action, timeout, then null-game error | The current menu action is **Play**, not **Start run**. The integrated upstream changes already correct the selectors; this qualification retains the failed-start guard against a secondary null dereference. |
| B — stale expectation | Older editor fixtures | Explicit Absolute Grid, full-size brushes and active pivots are now requested where those old fixtures require them. Other corrections follow independent layer behavior, Markers tab naming, enabled group transforms and normalized ring IDs/defaults. |
| B — stale expectation | Final lifecycle follow-up: 33 checks, 6 failures | New Results replay intentionally retains one run configuration in Session. The previous probe expected every configuration to release at menu return. It now checks that this is the sole retained owner, that replacement releases it, and that closing Session releases every observed owner. |
| C — fixture/setup | Early new-test parse/type issues, stale SpinBox draft text, and an exact-transform fixture expanding a selected group beyond the border | Corrected fixture construction and input setup. Invalid-operation rejection remained asserted. Fixed-radius hardware expectations use its actual geometry. |
| C — integration fixture | Two new palette types changed fixture counts; a moving bumper uses a child visual under a rotated parent | Kept fixture ordering stable, retained exact copy-count deltas, and compared bumper world orientation to its authoritative body. No collision or presentation code changed. |
| E — environment/tooling | First import began before archive extraction completed; initial Computer Use access request expired | Stopped only the owned incomplete import, completed extraction and reran import. Native app access subsequently succeeded. |

No assertion failure was dismissed as unrelated (class D). Original failed logs remain in
the local receipts; later passing runs do not overwrite them.

## 3. Production corrections

Only four editor source files changed:

1. `terrain_history.gd` validates saved sources against supported transform ranges,
   allowed fields, primitive footprints and composite version/outline/frame rules.
   Invalid data is rejected before it can be saved or opened as recoverable history.
2. `editor_workspace_tools.gd` aligns the exact Size minimum to its `.01` step.
3. `act_geometry_editor.gd` uses `.001` Decor scale steps, aligned with `.125`.
4. `selection_transform.gd` reflects terrain frames analytically, retaining scale
   and quarter turns instead of decomposing a float32 affine basis. Existing source
   history continues to follow the final placement transform.

## 4. Stale tests and retained assertions

The baseline changes above follow current UI and schema behavior. Editor tests
retain save/reopen, dimensions, geometry and Undo assertions. Terrain rotation and
mirroring compare independently transformed world vertices instead of requiring a
particular equivalent field encoding. Composite group transforms now assert a
valid atomic edit and independent Undo, rather than expecting the retired refusal.
Ring preview comparisons check all preview fields plus fresh IDs and normalized
scoring defaults. No coverage threshold or validation rule was relaxed.

## 5. Disposable fixtures and reusable runners

`tests/editor_qualification_fixture.gd` builds:

- **A — dense:** ordinary, open and smoothed terrain; all 20 current hardware types plus
  three more linked mechanisms; two independent Switch Banks; three supported
  Decor slots; single/line/ellipse/filled ring patterns; lifecycle markers;
  groups, locks and hidden state.
- **B — linked assembly:** a persisted/reloaded mixed assembly with fresh IDs,
  one coherent 35-member group and two independent banks. Separate horizontal
  and vertical reflected variants are exported.
- **C — smoothed/mirrored:** transformed source history with unrelated terrain.

Fixtures are written only under the disposable snapshot's `test-results` folder.
Run these commands against an imported snapshot, using new result directories:

```powershell
& .\tools\verify_act_editor.ps1 -ProjectRoot <snapshot> -OutputDirectory <results>
& .\tools\verify_editor_authority.ps1 -ProjectRoot <snapshot> -OutputDirectory <authority-results>
```

The first runner includes real fresh-process restart phases. The second uses the
normal baker and rendered Prototype, serially. Its dense case covers all eight
themes, as requested for editor qualification; this does not expand grounding scope.

## 6. Format-19 persistence and compatibility

Initial `fixture-final/results.json`: **657 checks passed**. After integration,
`integrated-focused/results.json` core **395/395** and restart **3/3**, plus
`integrated-workspace-final/results.json` workspace **265/265** and restart
**22/22**, give **685 passing core/workspace checks**.
Coverage includes old Acts without metadata, copy/save/Save As/reopen, complete
editing fingerprints, metadata families and malformed files. Opening old content
does not rewrite it. Invalid documents cannot overwrite an existing good source.
Groups, locks and authoring visibility leave gameplay fingerprints unchanged;
geometric, hardware-dimension and patrol changes invalidate them normally.

## 7. Selection, transforms and mirrors

Viewport/editor regressions cover selection families, filters, marquee modes,
group expansion and protection, layer solo/restore, browser reveal/rename/frame,
all nine snap-mode/step pairs, Shift/Alt overrides, X/Y locks and cancellation,
three pivots, handles, brackets and keyboard rotation. Exact transforms verify
rotation → scale/target size → translation as one atomic edit. Invalid target
sizes and border crossings leave the full document and Undo stack unchanged.

Independent mirror oracles cover terrain silhouettes, asymmetric hardware,
flipper handedness, directional forces, teleporter exits, Buzz patrols, sampled
rings, Decor, bank links and supported lifecycle markers. Entry/Exit remain
structural and Activation stays horizontal. Repeated H/V mirrors and the actual
toolbar border regression pass.

## 8. Clipboard and assemblies

Core and workspace tests exercise every requested copy/paste/duplicate shortcut,
paste-in-place, cursor paste, row/grid creation, cross-cell-size placement, fresh
IDs, complete internal bank reconnection and omission of partial external links.
Copies start unlocked; intended groups/history persist. Undo/Redo restores the
previous duplicate offset. The 256-position and 20,000-object guards reject
oversized operations before committing any copies.

Assemblies are saved, loaded after a real process restart, placed repeatedly and
deleted in private profiles. Corrupt entries are rejected. Each placement has
fresh identities and an independent coherent group.

## 9. Source recovery, autosave and preferences

Merge, Smooth and Merge+Smooth recover their transformed sources after movement,
rotation, scale, mirrors, save/reopen, copy, duplicate and assembly placement.
Unsmooth and its Undo/Redo preserve unrelated placements. Sixteen-level nesting,
oversized/malformed histories and legacy composites without backups are covered;
the latter report that no saved sources exist.

The workspace run waits for the real 30-second timer. It verifies one automatic
copy per source/session, no rewrite of unchanged state, named/forced checkpoints,
dirty-document **Before recovery** protection, interrupted-save backups, invalid
files, moved sources, retention and Save As after recovery. Original source hashes
remain unchanged. Preferences and per-Act camera/zoom survive process restart and
do not dirty the Act or enter Undo. Uncommitted field drafts are not autosaved.

## 10. Native GUI and input-routing evidence

The source editor was controlled with real Windows keyboard/mouse input before
the work-PC pause. Verified F1/Escape, Workspace tabs and browser search, text-field
letter/number shortcut guards, Ctrl+M exact movement, native Ctrl+Z/Ctrl+Y, angle
commit on focus loss, hardware solo/restore, named Ctrl+K checkpoint, Recovery
restore as an unsaved copy, Save As, canvas drag/Undo and boundary-mode exit.
The recovered saved document matches the source content after normalizing only
the generated ExtResource ID. Closing and restarting the native process restored
the selected linked Act, view, Relative Grid and Guides Off preferences.
These native captures precede the later four upstream commits; their linked
fixture has 33 members. The integrated fixture adds both new hardware types.
The browser's real Tree text editor and checkboxes also pass a focused regression
for group rename, whitespace rejection, individual hide/lock, whole-group protection
and complete Undo/Redo.

Six native captures are retained, without a large screenshot suite:

| Evidence | Capture |
| --- | --- |
| Mixed selection and handles | [01](images/editor-qualification-20261118/01-mixed-handles.png) |
| Object/group browser | [02](images/editor-qualification-20261118/02-object-group-browser.png) |
| Exact transform | [03](images/editor-qualification-20261118/03-exact-transform.png) |
| Layers/filtering | [04](images/editor-qualification-20261118/04-layers-filtering.png) |
| Recovery list | [05](images/editor-qualification-20261118/05-recovery-list.png) |
| Mirrored linked assembly | [06](images/editor-qualification-20261118/06-mirrored-linked-fixture.png) |

The actual editor **Play** button opened the separate current Prototype process
with its Act HUD, score target and pause controls. Native input did not complete a
scoring/Goal playthrough. Those paths are asserted in the rendered authority tests.
Mid-drag cancellation is covered by viewport events; the native automation's drag
operation is atomic, so cancellation while physically holding the mouse remains
an explicit manual interaction check.

## 11. Bake and Prototype authority

Before upstream integration, `authority-final/results.json` passed 953 assertions.
The final `integrated-authority-final/results.json` has **11 normal bake processes
and 11 rendered Prototype runs passed, 1,023 assertions, zero failures**.
Dense A ran in all eight themes;
horizontal B, vertical B and C ran in Green Hill. Each Prototype loaded exactly
one disk Act recipe and one disk theme recipe, with **zero fallback rebuilds**.

Tests compare source and disk 2D collision polygons/segments, runtime identities,
bank membership, positions and properties. Rendered flippers, bumpers, mechanisms,
Buzz and all authored Decor slots follow the authoritative transforms. Authoring
hidden state does not remove Decor from gameplay. 3D presentation owns no collision.
The current Goal is visible, live controls accept flippers/steering, mechanic events
reach the score pipeline, sessions close, and fixture hashes remain unchanged.

Additional rendered integration checks in `integrated-play-final/results.json`
pass **Side to Side 16/16**, **Prototype Act playtest 15/15**, and the extended
portable source smoke. The Act playtest completes the scored Goal through Results
and replays the same saved course. The camera-picker regression passes **9/9**.
These are scripted rendered checks, distinct from the earlier native mouse/keyboard
source-editor session.

## 12. Undo/Redo and safety sanity

A deterministic sequence performs at least 16 independent edits covering placement,
group/lock/hide, movement, exact transform, mirror, duplicate, Smooth/Unsmooth,
boundary resize, assembly placement and deletion. Undo returns to the complete
starting editing fingerprint; Redo returns to the complete final fingerprint.
Saving/reopening retains the final state. Browser caching, inactive refreshes,
stable signal counts, autosave write suppression and released editor/session owners
pass. These are correctness/sanity checks, not performance benchmarks.

A separate disposable headless editor-ownership probe opens and frees the real
editor three times. Every cycle releases the editor, document, canvas and workspace
weak references, returns to one root Node and zero orphan Nodes, and preserves the
single initial window-close connection. Its complete output is retained under
`editor-ownership-final`. Source review also confirms browser refresh returns before
fingerprinting an invisible/inactive browser; refresh has no per-frame poll.

The final Prototype lifecycle follow-up first reproduced six stale assertions:
Results replay now keeps one plain run configuration in Session. The amended probe
does not drop that object from observation. It asserts that this is the only
retained runtime reference, checks its release when another run replaces it, and
checks all watched owners again after Session disposal. **39/39 checks pass across
six runs and three Session instances.** Each session ends with one root Node, zero
orphans, no live registered renderer targets and no retained watched owners.
Resources remain at 155 across the three settled sessions.

The engine warning remains a **D — pre-existing engine allocation issue**, not a
new editor cleanup defect. The quiet full-run baseline reports six ObjectDB
instances; its verbose 162/162 repeat reports 24 plain `RefCounted` instances with
reference count zero. Counts vary. A loader-only control, without a Session or
Game, reproduces 17 such instances while releasing the loaded resource on all six
cycles. Its ObjectDB count rises from 1,544 to 1,554 while resource count stays at
49. The matching six-load synchronous control releases every loaded resource,
stays at 1,535 objects / 47 resources and emits no ObjectDB warning. This reproduces
the [existing loader audit](LIFECYCLE_AUDIT.md). Original warnings
remain in `shutdown-final` and `shutdown-confirmed`; no engine leak fix, loader
workaround or suppression is shipped.

## 13. Remaining review for Alex

- Judge guide readability, preferred zoom, handle usability and flipper timing.
- Try Escape while physically holding a drag, including an axis-locked boundary
  gesture. Viewport-event cancellation is tested; native held-button cancellation
  was not automated.
- Play through a saved Act to its Goal for feel. Automated scoring/Goal/control
  assertions are not a substitute for a human playthrough.

No claim of every possible interaction being fully verified is made.

## 14. Supported baseline and final checks

Before fixes: **29/32 suites passed**. Final `baseline-final/baseline.json`:
**32/32 suites passed, zero assertion failures, script errors or timeouts**.
The final runner uses the same supported suites; only launch position is adjusted
to the left monitor while Alex uses the PC. The grounding runner itself remains
unchanged. All 113 required private Act/theme variants are fresh, and explicit
loading still passes all 190 production script/scene dependencies.

The baseline includes 3,461 Act-geometry checks plus six fresh-process reload
checks, 2,842 disk-geometry checks, 162 full Prototype-run checks and the
56-variant/566-check Prototype bake audit. Suite totals are the common denominator;
some older suites report failures without an assertion count.

Original logs retain expected malformed-resource and blocked-archive errors,
existing source-only raw-image warnings, and the previously documented Godot
threaded-loader shutdown warning. Passing assertion totals do not imply a
warning-free engine exit. Shutdown follow-up is recorded in section 12.

All 15 existing editor regression scripts pass on the integrated version:
14 in `integrated-editor-final/results.json`, plus the interaction suite
(214 checks) in `integrated-focused/results.json`. This includes fresh-process
gameplay/lifecycle/ring reloads and the 776-check composite geometry suite.

## 15. Portable Authoring Tools package

Delivered ZIP:

`E:\Sonic Spinball Runners\test-results\authoring-tools\Sonic Spinball Authoring Tools-20261118-qualified.zip`

- **268,509,993 bytes**, ten files: both authoring EXEs, README and seven launchers.
- SHA-256: `F033BD7DF65086162A920CB0965CAEC86DA7E557688CA50A8DAD87196425FB41`.
- Built with the unchanged full-suite exporter and the existing local Godot 4.7.2
  Windows release template; no external assets or software were downloaded.
- Both source pool audits and both embedded pool audits pass: each checks 56
  variants with 566 assertions and zero failures.
- Actual ZIP extraction is under `portable-extracted`; all ten extracted files
  match their pre-archive hashes. The delivered ZIP hash matches the tested ZIP.
- The extracted EXE resource audit sees 3,185 resources, no missing required
  resource and no shipped user preferences, assemblies or recovery copies. The
  four corrected scripts and extended smoke script match the qualified source
  byte-for-byte inside the executable.
  The later lifecycle-probe amendment changes test assertions only; it does not
  change the packaged editor or Prototype runtime.
- The extracted **Geometry Editor.exe**, with a fresh private application profile,
  passes opening an existing Act, grouping and exact movement of a disposable Act,
  complete Undo/Redo, external save/reopen, a recovery checkpoint, real Prototype
  traversal and clean close. This is scripted UI/session coverage, not a second
  native mouse/keyboard session. Both saved editor/game images were inspected.
- `portable-extracted-smoke/receipt.json` records exit zero, no errors or warnings,
  and `PORTABLE_EDITOR_SMOKE: PASS`. Local extraction/resource/delivery receipts
  retain the hashes and audit details.

## 16. Commit and handoff

Production source changes remain limited to the four editor files above. The
focused qualification commit includes regression tests, disposable fixture
builders, reusable runners, six native screenshots and documentation. Generated
bakes, private profiles and package binaries remain local. All 627 pre-existing
untracked files are preserved.

The exact final commit SHA and confirmed push are recorded in the chat handoff
and `E:\Sonic Spinball Runners\test-results\editor-qualification-20261118\release-receipt.json`.
That receipt also identifies the delivered ZIP and its hash.
