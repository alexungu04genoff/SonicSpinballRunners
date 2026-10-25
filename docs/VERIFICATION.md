# Physics Playground verification

Latest checks: 2026-10-25. Engine: Godot 4.7.2 stable, Windows. Physics: 120 Hz. Graphical renderer: Compatibility / ANGLE D3D11 on NVIDIA GeForce RTX 4060.

## Composite terrain authoring — 2026-10-25

**Smoothing follow-up:** Strength now reaches 200% in 25% steps. The optional Preserve 90° checkbox keeps perpendicular corners and concave notches within a 1° tolerance, while other joins round. At maximum strength, cuts stay within 0.4 cell and 45% of either neighboring edge; the existing 5% area-change and collision-validity checks remain. Existing stored outlines are unchanged. Direct primitive smoothing now inserts String metadata keys explicitly, fixing a schema rejection when converting a primitive into a composite.

Follow-up verification passed **491 composite geometry/persistence/runtime checks headlessly** and **74 editor checks graphically with ANGLE**. Extended coverage exercises every 25% step through 200%, stronger rounding than 75%, protected convex/concave vertices in either winding, reversible checkbox previews without history entries, primitive conversion, exact high-strength reload in a fresh process, and unchanged collision/render contracts. Inspected the refreshed 200% preview capture with the corner control visible; controls fit. `git diff --check` passed. Human review still owns the preferred smoothing amount.

Explicit Ctrl-click terrain selection now feeds Merge, Smooth and Merge + Smooth previews. Apply replaces sources with one format-6 CompositeTerrain; Cancel leaves source data and history unchanged. The final stored outline drives editor selection/drawing, solid 2D collision and Green Hill extrusion. Composite rendering bypasses runtime union and preserves one exterior contour.

- `composite_terrain_regression.gd`: **353 graphical ANGLE checks passed**. Cases include triangle/square, triangle/square/triangle, square/circle, curved slope/circle, nine overlaps, filled U/S, capsule/bump, progressive composite/primitive and composite/composite unions, transforms, all four smoothing strengths, rejected holes/islands/open paths, malformed stored payloads, exact fresh-process reload, and old format-5 rings. Real convex physics shapes and 400 point probes match the saved silhouette. Mesh cap-area and cliff-edge checks find no source seams or duplicate interior faces. Normal Green Hill loads the saved composite with zero generator calls and leaves the source file untouched.
- `composite_editor_smoke.gd`: **57 headless / 59 graphical ANGLE checks passed**. Actual pointer and keyboard events cover selection, hidden pieces, preview locks/pan/zoom, strength changes, all cancellation paths, one-step Apply/undo/redo, deletion, duplication, movement, rotation, mirroring, save/reload and existing gameplay selection. Applying an unchanged 0%-strength composite adds no empty undo step.
- Existing authoring regressions passed: geometry **3,461**, connectors **108**, gameplay **493**, lifecycle **170**, rings **46**, with their fresh-process checks also passing. Existing editor checks passed: terrain **92**, gameplay **67**, lifecycle **49**, rings **29**, plus fresh editor reload checks.
- Existing runtime/presentation regressions passed: authored runtime **151**, Green Hill **77**, main game **70**. Isolated editor import and `git diff --check` passed.

The added toolbar exposed a float32 boundary issue: rebuilding a transformed `Rect2` could admit the exact right edge. Canvas bounds now compare the exact drawn endpoints, with no coordinate tolerance or normalization. The shared gameplay UI test fixture initializes the configured viewport instead of headless Godot's artificial 64×64 window; strict fractional-position assertions remain unchanged. Initial lifecycle and palette-drop failures were resolved and their suites rerun successfully.

Inspected `test-results/composite-editor-preview.png`, `composite-editor-applied.png`, `composite-green-hill.png` and `composite-main-game.png`. Logs and captures remain ignored. Restricted runs can emit the existing Windows root-certificate/cache diagnostics; no final script, scene or assertion failure remains. V1 deliberately rejects holes, separate islands, point-only connections and open walls. Human checks remain: selection comfort on dense Acts, preferred smoothing strength, and rolling/flipper feel against newly sculpted terrain.

## Green Hill walls, inset deck and close follow — 2026-10-25

The plain wall caps/sides now use procedural grass tufts, a leafy turf edge and orange/brown checker soil, informed by [SEGA's Sonic Mania screenshots](https://www.sega.jp/game/detail/sonicmania/). Generated rails and authored solids/open walls share these materials. The darker playable floor remains at gameplay height; raised caps, side faces and shadows distinguish obstacles. On enclosed authored tables the deck follows connected outer side walls, with no rectangular exterior grass shelf. Incomplete side boundaries retain a rectangular fallback; this is presentation inference, not a new authored field or collider.

Authored follow now has a 2× baseline zoom relative to the preceding ball-relative window. F1's Camera follow tuning exposes an additional 0.6–2.5× Follow zoom multiplier; O's complete-table overview ignores it. Screen-margin tracking keeps fast balls visible while retaining the camera speed limit and fixed angle. Generated default framing and all physical dimensions remain unchanged.

- Main-game regression: **72 ANGLE checks passed**, including a substantially larger projected ball, unchanged perspective angle, corner/side-lane targets, 1200 px/s horizontal/vertical traversals at 60/120 Hz in all three camera presets, bounded camera speed, overview bounds, the actual F1 zoom control, source switching and retained engine ownership.
- Authored presentation: **77 headless / 82 ANGLE checks passed**. Added a connected inset-wall fixture with a curved outer edge, exterior/interior/gutter probes and actual floor mesh-area verification. The 50/100 px fallback floors, all 77 terrain silhouettes, nine filled U/S variants, exact physical/visual anchors, rings, open paths, source immutability and collisionless presentation still pass.
- Generated regressions: vertical camera **22**, presentation **18**, and Green Hill integration **14** checks passed. Real paddle/bumper events still feed presentation normally.
- Isolated editor import and `git diff --check` passed. Successful test and capture runs had empty stderr. No physics, authored resources or project settings were edited by this change.

Rendered and inspected the user's `First Try.tres` in close gameplay and full overview, plus generated play in the main app. Captures are `test-results/green-hill-first-try-close.png`, `test-results/green-hill-first-try-overview.png` and `test-results/generated-main-green-hill.png`; logs/captures remain ignored. The existing capture path also accepts `--capture=overview` (launcher: `-Capture overview`). Human review still owns camera comfort and visual polish, especially at extreme zoom settings or on layouts without enclosing walls.

## Authored floor, obstacle readability and closer camera — 2026-10-25

The authored renderer previously treated solid collision stamps as flat grass islands and removed the shared floor. Authored Acts now have a continuous grass/checker platform over the terrain rectangle, ending before the red gutter. Solid stamps render as raised brown-and-cream obstacles using the generated rail palette; open paths keep their unclosed topology and use the same styling. The visual floor adds no collision or perimeter. Existing canonical colliders, authored positions and object dimensions are unchanged.

Follow framing now uses the ball radius to choose a local play window, keeping compact authored Sonic comparable in screen size to generated Sonic while retaining the same perspective angle and tuning. The closer view can track both side lanes; O still switches to a full Act/gutter overview. Generated framing remains unchanged.

- Main-game regression: **67 headless / 69 ANGLE checks passed**, including comparable projected ball width, identical camera angle, visible corner/side-lane targets, 1200 px/s lateral/vertical traces, overview bounds, source switching and shared engine ownership.
- Authored presentation regression: **72 checks passed**. Exact floor bounds and empty-floor collision probes pass at 50/100 px cells. All 77 terrain silhouettes retain their actual cap area and filled/empty coverage; solid caps are raised and use the generated wall palette. Existing exact object transforms, shared dimensions, rings and open-path checks remain intact.
- Generated regressions: vertical camera **22**, Green Hill integration **14**, and presentation **18** checks passed. All reported zero failures and empty stderr.

Inspected actual ANGLE captures from the main app with both the simple comparison and the user's `First Try.tres`, alongside generated play. `test-results/authored-floor-camera.png` shows the user's level with continuous grass, visibly raised walls and closer follow framing. Isolated editor import and whitespace checks passed. Source Acts were only read; the existing `project.godot` edit remains preserved. Captures/logs are ignored. Human review still owns camera comfort and layout feel.

## One engine, multiple level sources — 2026-10-25

Saved Acts now load inside the normal Green Hill application. The footer supplies source selection and a paused file picker; Start/replay reloads the active source. `PlayfieldData` removes generated-chunk assumptions from shared character/terrain queries. Source changes retain the actual gameplay, HUD, presentation, camera, environment and character-presenter instances. Authored loading bypasses generation; generated modes retain their previous geometry path. See [architecture and normal launch instructions](PLAYFIELD_SOURCES.md).

- `authored_main_game_regression.gd`: **62 headless and 65 ANGLE checks passed**. Checks authored startup without a generator call, exact installed dimensions/positions, retained engine and UI identities across authored reload/generated round trips, normal profile/override persistence, failed-load preservation, complete run-state reset, shared ring score/meter/Scorecraft, all four real-body specials, gutter/reset/Activation/Exit behavior, camera tuning/follow persistence and collisionless presentation. Actual input exercises Load Act, picker cancel, input blocking, overview and Start/replay. A separate failed `--act` invocation passed **5 checks**, including readable failure and inert O/C/1 shortcuts without cascaded errors.
- `authored_source_physics_regression.gd`: **49 checks passed**. Equivalent existing `TableChunk` and authored-compiler fixtures contain matched rails, round bumper, rotated sling, compact paddles and rings. Across Sonic, Tails, Knuckles and Shadow profiles, real trajectories match for gravity, steering and counter-steering; actual wall/bumper/sling rebounds, paddle strikes, ring contact/Scorecraft awards and gravity-only serve match within explicit tolerances. Exact tuning/mass and paddle pivots/dimensions are checked independently. Special execution/ownership is checked by the main-game suite and existing character suites.
- Existing character/scoring regressions passed: Character Lab **70**, Four Characters **64**, Scorecraft **37**, Score Attack **26**. Score Attack includes 27 seeded difficulty/catalogue/grid rebuilds. Synthetic descriptor fixtures now refresh the common playfield contract; existing gameplay assertions remain intact.
- Existing generated recovery passed: Zone **34** and baseline physics **38**. Zone covers real gate collisions, checkpoint retries, drafts, completion, replay and leaving Zone. Its intentionally invalid configuration emits the expected rejection diagnostic while preserving the active run.
- Existing presentation checks passed: presentation **18**, vertical camera **22**, ring presentation **15**, Green Hill integration **14**, special visuals **17**, and full Green Hill playable smoke **25**. The latter runs four 90-second continuous layouts. Regeneration assertions now require the retained presenter/character while still verifying replacement geometry, exact listener counts, real strikes, rings and resets.
- The retained low-level authored Green Hill diagnostic passed **66 headless checks**, including the complete 77-shape silhouette catalogue, shared dimensions and ring rendering/collection. Its simplified reset behavior remains diagnostic only.

The final main-app ANGLE run measured **57.47–130.43 ms** for authored reloads, including normal installation/reset and retained Green Hill presentation. The final 50 px-cell comparison load measured **57.47 ms**. First authored startup measured **358.83 ms**, including creation of the full shared HUD and character-study presentation; its Green Hill construction phase was **145.92 ms**. These local samples exclude engine import/startup and first GPU frame. The expanded `AUTHORED_MAIN_READY` log reports load, terrain, objects, rings, presentation and total ready time. No procedural search is included or invoked.

Captured and inspected `test-results/authored-main-green-hill.png` and `test-results/generated-main-green-hill.png`: both show the normal HUD, character/Scorecraft controls and compact source row. Authored geometry uses normal follow framing and unchanged world-axis scale. Capture and test logs remain ignored. Isolated editor import and whitespace checks passed. Test stderr was empty except the two deliberate invalid-startup/configuration rejection cases; no unexpected script errors remain. The pre-existing `project.godot` edit remains byte-identical and excluded from this work.

Authored play is currently Free Play; score goals and multiple-Act transitions are deferred. Human flipper timing, smaller-world camera comfort and physical-controller feel remain manual checks. The older standalone results below are historical diagnostic evidence, not the normal human play path.

## Authored Green Hill presentation and shared scale — 2026-10-25

Saved Acts now use the existing Green Hill presentation by default, with direct compiler descriptors and no generated `TableChunk` instances. Authoritative 2D geometry remains independent. Shared cell dimensions drive editor previews, colliders and meshes, including a deliberately cell-relative ball. F2 retains the debug renderer; F3 exposes grid/lifecycle guides. Saved ring trails use the existing swept pickup and cosmetic flight systems.

- `authored_green_hill_smoke.gd`: **66 headless and 71 ANGLE checks passed**. Verifies 50/100 px-cell physical and visible dimensions, unchanged exact pivots/centers, Sonic's visible ball radius, complete Act/gutter camera framing, uniform axis scale, no 3D collisions or fake chunks, exact ring centers/contact thresholds, teleport suppression, real pickup and reset, F2 switching and source immutability. Actual grass-cap triangle area and filled/empty coverage pass for **all 77 terrain shapes**, including all nine filled U/S variants. Open paths preserve their exact unclosed vertices; representative merged overlap coverage matches independent colliders.
- `authored_act_runtime_regression.gd`: **151 checks passed**; `authored_act_physics_smoke.gd`: **42 checks passed**. Updated physical probes cover compact bumpers/slings, both flipper hands and rotated strikes at both cell sizes, thin-wall high-speed collision, and the showcase's falling serve. Existing lifecycle, exact persistence and no-generator dependency checks remain intact.
- `authored_act_scene_smoke.gd`: **23 ANGLE checks passed**, including actual toolbar/keyboard input, file selection/cancel, pause/resume/reset, ordinary flipper launch through Activation, invalid replacement and source-file preservation.
- Existing regressions: physics **38**, gameplay authoring **493 + 76 fresh-process**, ring gameplay **11**, ring presentation **15**, presentation **18**, vertical camera **22**, and Green Hill/Sonic integration **14** checks passed. The frozen-body ring-presentation fixture now explicitly settles its synthetic teleports; an added assertion verifies pending teleports cannot collect rings along an artificial path.
- Procedural Green Hill `playable_smoke.gd --screenshots --captures-only`: **27 ANGLE checks passed** across Normal seeds 18/23 and grid base/variant layouts. Regeneration, collision-matched scenery, live paddle listeners, real bottom/middle/upper strikes and ring flights passed. Overview/play captures were inspected. This bounded capture run does not claim the full long traversal/retry experiment.

`data/acts/scale_comparison.tres` provides a simple 50 px-cell reference with all four objects, 11 rings, straight terrain and lifecycle markers. `test-results/authored-scale-side-by-side.png` combines untouched editor and Green Hill frames; individual editor, Green Hill and underlying 2D captures are also available. Visual inspection confirmed compact objects, unchanged pivots, matching ring paths and perspective without world-axis stretching. The old curved showcase retains every terrain/object placement; its sample Spawn moved from X=530.5 to X=482.5 to feed the shorter left paddle. Runtime never performs that adjustment on loaded files.

The final ANGLE run measured **40.74–63.88 ms** total ready time for the 50 px-cell comparison, **101.38 ms** for its 100 px-cell variant, and **77.68 ms** for the curved showcase. The complete 77-shape stress catalogue measured **155.40 ms**, down from an observed 625.82 ms before batching static diagnostic lines into one mesh. These are file-request-to-attached-simulation/presentation measurements, not engine startup or first GPU frame. Each load logs resource, terrain, object, Green Hill and total times separately; no procedural search runs. Sample size and local load affect the numbers.

Isolated editor import and source whitespace checks passed. The user's pre-existing `project.godot` changes remain byte-identical and excluded from the commit. Human review still owns compact-flipper timing, layout quality and camera comfort. Multiple Acts, score gates, rewards and procedural generation changes remain outside this milestone. Earlier sections below record historical behavior before this scale/presentation change.

## Lightweight ring-trail authoring — 2026-10-25

The Gameplay Rings tool creates one-point or straight interpolated trails. Each trail stores exact endpoints and local-pixel spacing in format 5. Drawing, movement, endpoint edits and deletion use one history entry per gesture; preview size is centralized at a 0.18-cell diameter. Spacing defaults to 0.4 cells and equal intervals fit both endpoints. This change adds authoring/persistence only; terrain and gameplay physics remain unchanged.

- `act_ring_regression.gd`: **46 checks + 18 fresh-process checks passed**. Covers single, horizontal, vertical and free diagonal trails; equal/collinear internal spacing; fractional coordinates; cell-size independence; independent snapshots; malformed inputs; previous format-2/3/4 loading without source writes; exact endpoint/spacing bits and byte-identical generated positions after restart.
- `act_ring_editor_smoke.gd`: **30 ANGLE graphical checks + 3 fresh-editor checks passed**. Actual pointer/keyboard gestures cover click/drag, Alt placement and release before mouse-up, one-step undo/redo, whole-trail movement, both endpoint handles, duplication, deletion, spacing UI, terrain overlap/cycling, gesture cancellation and save/restart/load/edit. The rendered `test-results/act-ring-editor.png` was inspected: tiny gold rings, unobtrusive selection line/handles and compact spacing control fit the existing layout.
- Existing regressions passed: geometry **3,461 + 6**, connectors **108 + 5**, gameplay objects **493 + 76**, lifecycle **170 + 8**, and authored runtime **135**. Existing headless editor checks passed: terrain **92**, gameplay **67 + 5 fresh-editor**, lifecycle **49 + 5 fresh-editor**. Final error logs are empty. Isolated Godot import passed and generated the new script UIDs.

Two initial test-harness issues were corrected: dictionary serialization order is now excluded from bit-exact field comparisons, and the fresh-editor nudge probe selects through a real click to establish keyboard focus. No production assertion was weakened. Human review still owns preferred visual spacing and handle comfort. Ring collection and runtime integration remain deferred; the user's pre-existing `project.godot` edits are preserved.

## One authored file to one playable Act — 2026-10-25

The dedicated `authored_act_playtest.tscn` loads saved editor Resources into an isolated 2D world. Terrain uses the canonical editor points, with solid polygons for filled stamps and consecutive segments for open paths. The existing ball and flippers, shared bumper factory and physics profile drive gameplay. Exact authored transforms and source data remain unchanged. Runtime uses existing physical dimensions independently of compact editor previews. Entry, upward Activation, Spawn, the gutter-bottom drain and upward Exit remain separate concepts.

- `authored_act_runtime_regression.gd`: **135 checks passed**. Coverage includes all 77 shapes, 16 asymmetric transform combinations, open/solid topology, fractional object anchors and rotations, real collider dimensions, required Spawn, source Resource/file immutability and the instantiated dependency graph's exclusion of procedural generators. Actual physics ticks verify first-flight Activation/Exit detection, pause, drain/reset, delayed re-serve and suppression of false crossings during reset. A first-step crossing omission found during review was fixed and covered.
- `authored_act_physics_smoke.gd`: **28 checks passed**. The production ball collides with actual filled silhouettes, rotated/mirrored rails and filled U/S regions. Open L/U probes show no invented closing walls. Duplicate solids and circle/slope overlap probes preserve sensible rebound energy. Real round and rotated triangle bumpers each fire once; both flipper hands strike once at ordinary and 90°-offset authored orientations. The sample Spawn clears the real ball and feeds a successful ordinary flipper launch.
- `authored_act_scene_smoke.gd`: **23 ANGLE graphical checks passed**. Real pointer/keyboard input exercises Example, Load, Enter, Escape, Resume, R and Reload; file-picker selection/cancel signals verify their connected load/pause handlers. A normal falling serve and timed shared flipper controls physically reach Activation. Invalid replacement preserves the current table. The full Act/gutter framing and source immutability pass; `test-results/authored-act-ready.png` and `authored-act-playing.png` were rendered and visually inspected.
- Existing physics regression: **38 checks passed** after shared bumper construction and optional authored flipper orientation. The normal main scene reached `PLAYGROUND_READY`. Isolated editor import passed and generated script UIDs; final runs have empty error logs. Initial sandbox runs reported unavailable Godot cache/log/certificate access; reruns with normal local access passed. An import-induced indentation change in an unrelated gameplay script was restored before final import. The user's existing `project.godot` changes were preserved exactly.

Three fresh-process headless CLI loads of the 14-terrain/4-object showcase measured **6.22–8.63 ms total Act-ready time** (median **7.16 ms**): resource load 3.69–5.77 ms, terrain compilation 1.00–1.34 ms, object construction 0.11–0.18 ms, and presentation-node construction about 0.01 ms. Three graphical loads measured 7.34–8.34 ms. These measure the loader from file request to constructed/attached simulation, not engine startup, first GPU frame or cold disk performance. No procedural search or Zone assembly runs on this path.

The source `.tres` remains byte-identical after load, play, marker events, pause, reset and reload. Overlap tests are representative, not proof for every possible layout. Human review still owns flipper timing, rebound feel and authored-table quality; no complete human playthrough or final production presentation is claimed. Launch and controls: [Authored Act Playtest](AUTHORED_ACT_PLAYTEST.md).

## Shorter authored flippers — 2026-10-25

Both flippers now use a 0.65-cell centerline and 0.75-cell overall body, down from 0.8/0.9 cell. Thickness, pivots, positions and resting angles remain unchanged. Shared tuning automatically shortens the swing guides and selection silhouette. Gameplay regression passed **493 + 76 fresh-process checks**; ANGLE editor smoke passed **68 + 5 fresh-editor checks**, with empty error logs. The rendered result was inspected. This is editor sizing only; runtime physics is unchanged.

## Gameplay-object and marker scale pass — 2026-10-25

`scripts/act_editor/preview_dimensions.gd` centralizes editor sizing: round bumper diameter 0.5 cell, sling height 0.6 cell, flipper centerline 0.8 cell with 0.05-cell rounded caps (0.9×0.1-cell total body), and a 0.24-cell Spawn ring. Pivot marks, outlines, swing arrows, Activation arrows and connector handles are compact. Connector spans and full-width Activation retain their extents. Annotation scale clamps only at extreme zoom levels; object silhouettes always follow the construction-cell ratio. Terrain geometry and runtime physics are unchanged.

- Gameplay regression: **493 checks + 76 fresh-process checks passed**. Four cell sizes verify object dimensions, centered bumper/pivot geometry, uniform sling scaling about its existing origin, unchanged authored transforms after preview generation, and exact save/restart/load positions and angles.
- ANGLE gameplay editor: **68 checks + 5 fresh-editor checks passed**. Headless terrain editor: **92 checks passed**. Selection, dragging, Alt positioning, numeric angles, palette drops, undo/redo and existing terrain workflows remain green.
- Lifecycle editor: **49 headless and 50 ANGLE graphical checks passed**, each with **5 fresh-editor checks**. Spawn movement, marker history, independent metadata positions, gutter rejection and exact persistence remain intact.
- Isolated editor import passed. Both rendered captures were inspected against the grid: gameplay objects sit within cells, flipper pivots remain visible, and Spawn/guide markers are unobtrusive. Error logs are empty. Subjective sizing remains tunable in the shared dimensions file.

## Standard bumper scale — 2026-10-25

The editor round bumper now derives radius from `0.25 × cell_size`, giving a half-cell diameter while preserving the authored center. Canvas, placement ghost and hit testing use the same geometry. Palette thumbnails continue to fit their own icon boxes. Sling geometry remains 85×90 local pixels; flipper bodies remain 156×26 pixels before rotation, including rounded caps. Terrain dimensions and runtime physics are untouched.

- Gameplay model regression: **488 checks + 76 fresh-process checks passed**. Radius/diameter and centering are checked at cell sizes 25, 47.5, 50 and 100; both flipper hands and sling coordinates remain unchanged. Exact placement persistence remains green.
- Gameplay editor smoke: **67 headless and 68 ANGLE graphical checks passed**, each with **5 fresh-editor-process checks**. New checks place three neighboring bumpers, select each at its center and reject the former oversized hit region at both 50 and 100 px cell sizes. An initial graphical run reported a palette-drop coordinate mismatch; the rerun passed the unchanged assertion after adding failure diagnostics, and headless verification also passed. No coordinate tolerance was relaxed.
- Lifecycle editor smoke: **49 + 5 fresh-process checks passed**. The rendered gameplay capture was inspected against the grid: bumper bodies span half a cell, and sling/flipper proportions remain unchanged. Final error logs are empty.

## Filled U/S correction — 2026-10-25

Filled U and Filled S now use the matching open wall as their upper surface and fill down to the canonical frame bottom. Open wall geometry, frame sizes and saved placement IDs remain unchanged. This supersedes the ribbon interpretation in the earlier connector/shape-expansion milestone.

- Geometry regression: **3,461 checks + 6 fresh-process checks passed**. Checks cover exact shared curves, fill below/empty above, expected areas, U bottom tangency, all rotation/mirror triangulations and persistence.
- ANGLE editor smoke: **93 checks passed**, including placement and selection in the newly filled regions, empty-space selection and existing editor workflows. Error log empty.
- Rendered atlas inspected for all three U sizes and all six S sizes, beside their unchanged open wall counterparts. Fill reaches each frame's bottom; terrain scaling is unchanged.

## Act lifecycle metadata — 2026-10-25

Act Markers adds optional full-width Activation and exact-position Spawn markers alongside the existing Entry/Exit tools. A system-owned one-cell-height red gutter sits outside the unchanged 12×12 terrain grid. Format 4 loads previous format-2/3 Acts with lifecycle fields unset. This remains authoring-only: no activation state, death/respawn, ball, transitions, generator changes or playable Act loading.

- `act_lifecycle_regression.gd`: **170 checks passed + 8 fresh-process checks**. Coverage includes optional drafts, finite half-open terrain bounds, malformed data, rejection without clamping, exact fractional values, independent copies/fingerprints, shared gutter bounds, previous-format fixtures, repeated persistence and restart/edit/re-save. Activation uses the existing lossless scalar payload; Spawn remains a native Vector2.
- `act_lifecycle_editor_smoke.gd`: **49 headless and 50 ANGLE graphical checks passed**, each with **5 fresh-editor-process checks**, with empty error logs. Actual viewport input exercises all four marker tools, create/replace/move/delete, snapping and Alt fine movement, arrow nudges, one edit per drag, cancellation, undo/redo, mixed-layer selection, invalid moves, cell-size rejection, terrain click/drop exclusion in the gutter, unchanged grid dimensions and complete marker persistence.
- Existing model regressions remain green: geometry **3,302 + 6**, connectors **108 + 5**, gameplay **471 + 76**. Existing terrain UI passed **86 checks** and gameplay UI passed **57 headless checks + 5 fresh-process checks** with the gutter visible. A fractional-origin boundary regression was fixed by comparing pointer and bounds in the same global coordinate space; an additional eight actual-click probes confirmed left/top admission and right/bottom/gutter rejection without a tolerance or coordinate changes.
- Isolated editor import and unchanged playground startup passed with an empty error log and `PLAYGROUND_READY`.

The rendered lifecycle capture was inspected at 1280×900. Terrain rows stop at 0–11; the red gutter has no grid lines. Green Entry/Exit, cyan Activation, pink Spawn and the system-zone caption remain distinct and readable. The bundled example now includes Activation Y=450 and Spawn=(300.5,555.25), preserving all 18 terrain pieces, four gameplay objects and both connectors. Subjective marker placement comfort remains a short manual check.

## Gameplay-object authoring — 2026-10-25

The standalone Act editor authors round bumpers, triangle bumpers/slings and left/right flippers in a separate exact-local-coordinate collection. Format 3 loads previous format-2 terrain/connector documents with an empty object list. All previews remain collisionless; runtime assembly, generator behavior and gameplay are outside this change.

- `act_gameplay_regression.gd`: **471 checks passed**, plus **76 fresh-process checks**. Four pure-data silhouettes match current bottom-table proportions. Coverage includes finite numeric transforms, independent snapshots, overlap, out-of-grid local coordinates, version-2 compatibility, 70 fractional-coordinate/angle placements, repeated saves and restart/edit/re-save with byte-exact comparisons.
- Native Godot decimal text roundtrips changed some float64 angles by one binary unit. Saved `rotation_degrees` fields now use a single native numeric byte payload, decoded by `load_document()`; live objects retain numeric angles. Checks cover malformed payloads, unchanged live data and rejection without damaging an existing save. Fingerprints use ordered binary values, so even tiny authored changes remain visible to dirty/history tracking.
- Existing geometry regression passed **3,302 checks + 6 fresh-process checks**; connector regression passed **108 + 5**. Their terrain and connector contracts remain unchanged.
- `act_gameplay_editor_smoke.gd`: **57 headless and 58 ANGLE graphical checks passed**, each including **5 fresh-editor-process checks**, with empty error logs. Real viewport input covers all four palette types, snapped and Alt-free positions, modifier changes during a drag, exact numeric angles, handedness, duplication/deletion/history, mixed terrain/object overlaps, palette drag/drop, pending-angle focus changes and combined persistence. Graphical palette-drop probes target actual integer screen pixels and compare the corresponding fractional local position.
- Existing terrain/connector editor smoke passed **86 headless checks**. The isolated editor import completed without script errors, and the unchanged playground reached `PLAYGROUND_READY` in a separate headless startup check. The gameplay editor capture was inspected at 1280×900: cyan bumpers, yellow flippers, pivot markers, swing arrows, palette categories and angle controls remain readable.

The bundled example now combines 18 terrain pieces, two connectors and all four gameplay objects, including fractional positions and a 32° sling. Human review remains useful for drag comfort, pivot/swing readability and palette ergonomics. There is no playable Act loading in this milestone.

## Act connectors and expanded terrain — previous milestone

The follow-up authoring milestone retains the standalone scene and existing editing/file workflow. The user confirmed a fresh start: format/library version 2 only, with no migration layer or legacy shape lookup. Runtime generation and gameplay remain unchanged.

- `act_geometry_regression.gd`: **3,302 checks passed**, plus **6 fresh-process checks**. All 77 stamps retain exact cell frames through every quarter-turn/mirror combination. Additional checks cover matched solid/wall pairs, all nine bump aspect ratios, U-band open mouths, S inflection and endpoint tangents, valid non-self-intersecting ribbon polygons, and full terrain/connector restart persistence.
- `act_connector_regression.gd`: **108 checks passed**, plus **5 fresh-process checks**. Compatibility ignores local X and compares positive integer widths only. Optional drafts, in-bounds integer spans, independent snapshots, fingerprints and editing/re-saving after restart are covered.
- `act_editor_smoke.gd`: **86 headless checks and 87 graphical checks passed**, with empty error logs. Actual viewport input exercises all 77 stamps and existing terrain/file/history interactions, plus boundary restrictions, inclusive/reverse connector drags, replacement, movement, both resize handles, exact right-edge bounds, arrow nudges, cancellation, deletion, undo/redo, connector/terrain overlap selection, and saving/reloading both spans.
- Isolated headless editor import passed, and the unchanged playground reached `PLAYGROUND_READY` in a headless startup check. The rendered editor capture was inspected at 1280×900; connector metadata, green markers, endpoint handles, palette labels and new terrain remain readable. An additional rendered atlas covers all U/S pairs and all nine bump aspect ratios; U mouths remain empty and S ribbons follow their curves with tapered grid-corner tips.

The current `data/acts/curve_garden.tres` was authored through editor stamping/connector/save actions. It contains 18 terrain pieces and equal-width Entry/Exit spans at different local X positions. Captures and logs remain in ignored `test-results/`. Subjective drag comfort and preferred ribbon thickness still benefit from human review; gameplay playtesting and collision compilation are outside this milestone.

## Manual Act Geometry Editor — initial milestone

The standalone editor adds no runtime generator or gameplay changes. Godot 4.7.2 checks on 2026-10-24:

- Isolated headless editor import and standalone editor startup passed.
- Godot MCP launched the editor graphically; its final debug output contained no errors or warnings.
- `act_geometry_regression.gd`: **2,181 checks passed**, plus **5 checks in a fresh Godot process**. Coverage includes all 52 canonical shapes, every quarter-turn/mirror combination, exact frames and extents, open/closed topology, independent point-transform expectations, malformed/missing version metadata, invalid placements, deliberate overlap, save/reload equality and editing/re-saving after restart.
- `act_editor_smoke.gd`: **60 headless interaction checks passed**. Every palette stamp is placed through viewport input. The checks exercise repeated placement, real palette drag/drop, snapped moves and cancellation, selection by actual shape, overlap cycling, button/keyboard transforms, delete, history, title/cell-size drafts, file-state indicators, unsaved-change guards, failed-load preservation and exact editor re-save.
- The same scene smoke passed **61 graphical checks**, including a rendered capture. `test-results/act-editor.png` was visually inspected at 1280×900: palette previews, controls, grid, geometry and ghost fit and remain readable. Synthetic drag/drop input also synchronizes the native cursor so graphical mouse polling cannot overwrite its test position.
- Existing profile regression passed; existing generation regression passed **64 checks**. The unchanged playground scene reached `PLAYGROUND_READY` during a separate headless startup check.

The 22-piece `data/acts/curve_garden.tres` example was created using editor stamping/transform/save actions. Version fields are explicitly stored, and files reload with `CACHE_MODE_IGNORE`. No external testing dependencies were introduced.

The first raw editor import applied an existing indentation-conversion preference to one line of `scripts/game.gd`. That side effect was restored; subsequent checks used the existing isolated import helper, and no gameplay source change remains. Human review still owns palette comfort, drag precision and curve silhouettes. The editor deliberately has no runtime playtest mode.

## Four-character abilities — Knuckles and Shadow

`four_character_regression.gd`: **64 checks passed** using real 2D bodies, shared score callbacks and the public run-selection UI. Coverage includes paid and rejected activations, partial configured costs, blast radius limits, duplicate descriptors and ring claims, remote/contact award deduplication, fixed area values during an active ×3 combo, no remote meter refund, active-Act filtering, ordinary rack bonuses, real wall/bumper glide impacts, an immediate near-wall impact, missed glides, line-of-sight obstruction, unrelated-body exclusion, queued-wave cancellation, pause/draft timing, all reset reasons, real locked Act gates, actual checkpoint drains, Chao/profile compatibility, and both new characters in all three modes.

Native contact resolution can stop the ball before its callback. The new observational impact signal uses the preceding physical approach velocity and the solver's contact impulse; the existing fast-motion guard supplies its measured incoming speed. These observations do not change collision response. The first wave trial missed wall-mounted targets whose centers lie behind their rails. Testing the exposed bumper face preserves real line of sight and makes the existing mounted targets useful. Wave width increased from 260 to 360px after the first input survey found few scoring opportunities; range stays 500px. No geometry or generator changes were made.

Existing regressions passed: Sonic/Tails Character Lab **70**, physics **38**, rings **11**, Scorecraft **37**, Chao Lab **29**, Score Attack **26**, and Zone lifecycle **34**. The Zone negative configuration check emits its expected error; successful runs contain no unexpected script errors. Final safe editor import passed and generated the new UID files.

### Same-seed input comparison

All four used the existing seed-18 Easy Zone with the same movement/flipper policy and ability-specific activation conditions. Meter came only from real ring/bumper interactions. No score, charge, trajectory or position was injected. The cap was 120 simulated seconds; these are automated policies, not human completion times or proof of character balance.

| Character | Points | Rings | Balls | Acts completed | Special results |
| --- | ---: | ---: | ---: | ---: | --- |
| Sonic | 12,400 | 38 | 3 | 0 | 3 activations, 2 physical Homing hits |
| Tails | 10,725 | 35 | 1 | 1 | 3 flights |
| Knuckles | 11,850 | 59 | 2 | 3 | 3 glides/impacts; 2 remote targets and 4 wave rings; Zone complete at 110.55s |
| Shadow | 10,350 | 41 | 2 | 0 | 3 blasts; 7 remote targets and 3 blast rings |

First full charge arrived at 20.61–28.51 simulated seconds across the four characters. The survey shows different scoring/traversal outcomes, not a reason to retune Act targets. A separate 90-second same-seed Free Play comparison passed for all four specials, scoring 9,200 / 10,100 / 8,325 / 10,425 respectively. Its first boundary report was investigated: Knuckles had already drained and was 522px below the table with respawn pending, followed by the normal deferred reset. The survey now records that legitimate post-drain departure separately; non-finite motion and live side/top escapes still fail. The final Free Play and Zone surveys reported no live escapes.

### Graphical same-room comparison

`four_character_capture.gd` passed with ANGLE in the existing seed-18 Green Hill Orbit Cluster. All four start at the same authored room position, falling at 350px/s with an explicitly supplied full meter. After initialization, only ordinary controls act. Sonic physically hits a Homing target; Tails reduces the fall and guides the ball; Knuckles hits the side rail and waves an exposed wall bumper for 200 points; Shadow activates four bumpers and three rings for 475 remote points, with no remote recharge. Subsequent ordinary play can add points and meter.

Actual gameplay-camera images and JSON are in `test-results/four-character-review/`, including `knuckles-outcome.png` and `shadow-activation.png`. Shadow is black with red accents; neither new character borrows Sonic's model. All visuals are collisionless placeholders. Human playtesting should judge glide commitment and expiry, whether wave opportunities are readable, blast positioning, and the full-meter cost. No art polish or complete human playthrough is claimed.

## Target Garden — perimeter mounting and distinct shot routes

The approved compact mounting moves both pivots 50px toward the existing walls, to x125/675, with 18px bearings. Boundary polylines and paddle lengths stay unchanged. This pass changes only Target Garden; Bank Vault and Offset Climb retain their preceding layouts. The large bumper moves from (550,200) to (600,200), clearing a diagonal ring trail from the source-right paddle to the upper opening. A separate left-side trail leads into the small target cluster. Seed 28 mirrors the room, placing the progression paddle on screen left.

`target_garden_routes.gd`: **25 checks passed**. From the same clear upstream start at (688,200), zero initial velocity and one ordinary flipper press, five consecutive press ticks (116–120 at 120Hz) reach the actual upper opening with no post-strike bumper contacts and 2–6 post-strike rings. The same seven-sample timing sweep produced three clean climbs before the large bumper moved and five afterward. An earlier press hits the large bumper and falls below the isolated room. Both mirror orientations pass; no-input and premature presses miss without becoming stationary. The left paddle still reaches its small scoring target, and resting paddles leave the central upward passage open. `shot_kind="upper_passage"` requires physical passage; collecting an exit ring alone cannot pass the check.

Natural-feed checks passed **63**, Normal rooms **48**, compact mounts **98**, and unchanged contact-based aiming **21**. Mount coverage includes translated and mirrored fixtures, sixteen physical upper/underside/hinge/held-release probes, and rejection of missing or weak attachment, wall overlap, distant pivots, unrelated obstacles and invalid shot intent. The sealed root has no rear ball lane; actual capsule clearance remains mandatory, and full ball passage resumes beyond the first 60px of blade.

### Graphical full-Zone demonstrations

Three ANGLE recordings use the actual nine-chunk Normal 28 Green Hill game. Each initializes one upstream position and zero velocity, then uses ordinary flipper input or no input. No subsequent body, score, meter or force edits occur. The clips keep real walls, scoring, gates and drains active. They are controlled-shot demonstrations, not human or complete-run playtests.

| Clip in `test-results/target-garden-routes-review/` | Measured result |
| --- | --- |
| `garden-progression.mp4` | One strike; whole ball crosses the upper opening at 1.37s, with 150 points, 6 rings and no bumper contact before passage. |
| `garden-scoring.mp4` | Earlier strike; two real hits on the offset large bumper. Passage occurs later at 2.68s, then the ball returns into Garden. At 5s: 525 points, 9 rings and 2 bumper contacts. |
| `garden-miss.mp4` | No press; falls below Garden at 1.67s and reaches the ordinary Act 1 drain at 3.33s. Checkpoint retry is queued. |

The full-Zone scoring rebound eventually climbs, unlike the isolated-room scoring witness, then falls back into Garden rather than the lower recovery section. This shows a scoring detour with a different trajectory, not a guarantee that choosing points prevents progression. The clean climbing route reaches the passage sooner. Human playtesting must still judge whether the timing distinction is readable and comfortable across less controlled approaches.

`seed-28.png` and `seed-14.png` show the final room and its generated opposite mirror with the ordinary gameplay camera and HUD. All three graphical runs and both still captures passed; the H.264 clips also passed full decode. Separate earlier perimeter and rejected wedge captures remain archived; they are not current layouts. Captures and reports stay in ignored `test-results/`.

Compatibility reruns passed: Zone composition **103**, Zone lifecycle **34**, physics/profile resolution **38**, Character Lab **70**, Scorecraft **37**, and standalone Score Attack **26**. Composition includes Normal 28 / Hard 24 seams, both Act entries/drafts and all three checkpoint drains/recoveries. Zone lifecycle includes replay, Chao restoration and mode switching. The existing invalid-configuration negative test emits its expected diagnostic; no unexpected failures occurred. Final isolated editor import and whitespace checks passed. The flipper implementation and preexisting `project.godot` edit are unchanged. No subjective fun or full human Zone completion is claimed.

## Middle-flipper feeds and directional aiming — 2026-10-24

Zone generator v4 changes three existing recipes: Target Garden's shoulders now guide wall returns into its pair; Bank Vault loses its redundant right short paddle; Offset Climb lowers its 80px paddle by 50px to meet the opposing-bank return. Other Normal/Hard room shapes and selection remain intact. Existing grid clearance and connector validation are unchanged. The shared flipper now derives a bounded upward impulse direction from contact position and actual swing orientation, with unchanged resolved strength/leverage. Release cancels assistance, underside contacts receive no powered boost, and raised follow-through is limited to two physics ticks.

`flipper_aim_regression.gd`: **21 checks passed** using actual falling bodies and button presses. Twelve mirrored contact/timing samples each produce one useful upward strike. Representative heel and tip impulses differ by about 16 degrees (approximately 23 versus 6 degrees inward); changing press timing on the same middle contact changes direction by about 6 degrees. No-input, premature, expired-held, released-during-the-window and underside samples receive no powered recovery and can fall below the paddle. Spring scales the resolved impulse by exactly 1.35 once. These measure real emitted impulses and physical trajectories, not just the direction helper's output.

`normal_flipper_feeds.gd`: **61 checks passed** on final shaped Normal 28 rooms. All seven selected paddles have fixed, clear gravity-drop starts at least 300px upstream, repeated in both mirrors. Six recoveries reach their declared scoring target; Balcony passes through the safe upper opening. Fourteen matched unpressed drops fall to lower recovery, four early Garden taps miss, and ten mirrored upward passages clear resting paddles. Garden's new shoulders convert the previously missed wall-side drops into inward-moving catches and actual bumper hits. Crosscourt's existing bank-fed recovery remains; it did not need another shoulder. Existing Normal room checks also passed **48** assertions.

`hard_flipper_feeds.gd`: **25 checks passed** on Bank Vault, Offset Climb and Target Cove in both mirrors, from rest 300–400px upstream. Vault follows wall/bumper contacts into a scored catch. Climb follows its opposite bank into a tip catch and upper exit. Cove's three-bumper sequence feeds its opposite paddle and declared ring. Matched no-input and premature-input samples fall to lower recovery. Existing Hard room checks passed **32** assertions, including mirrored upward shots and target hits. The count changed because the removed Bank Vault paddle no longer requires its own shot fixtures; physical clearance requirements were not reduced.

### Recorded shots

Five graphical runs of `flipper_feel_capture.gd` passed in the actual nine-chunk Green Hill game. Each starts with one explicit upstream position and zero velocity, then uses one ordinary flipper-button press or no input. There are no subsequent body, score, meter or force edits. The review camera is fixed; gates, scoring, ball physics and presentation remain active. The clips label their controlled-drop setup and pause only after the visible outcome.

| Clip in `test-results/flipper-feel-review/` | Observed result at 120 Hz |
| --- | --- |
| `normal-garden-timed.mp4` | Right press at tick 112, strike 113, actual target contact 125. |
| `normal-garden-miss.mp4` | Same gravity drop, no press; falls into lower recovery. |
| `hard-vault-timed.mp4` | Left press/strike 209, actual target contact 225. |
| `hard-vault-miss.mp4` | Same gravity drop, no press; falls into lower recovery. |
| `hard-climb-timed.mp4` | Tip strike at tick 151, 545px upward recovery, then a physical rebound from the still-locked Act gate. |

Each clip is 5.617 seconds, H.264 at 1280×900/60fps, encoded from the 120fps Godot recording and decoded without errors. Matching drop/strike/outcome stills and JSON trajectories are in the same ignored local review folder. The Climb demonstration proves useful recovery and gate collision, not an unlocked Act completion. The previous layout-review screenshots remain separately preserved.

### Ordinary-input runs and compatibility

With the same existing timed-flipper/steering policy, earned specials and normal Chao draft choices, Normal 28 completed with Sonic in **105.775 seconds** (11,700 points, three specials, one Homing hit) and Tails in **156.358 seconds** (16,525 points, four flights). Both used one ball. Hard 24 remained incomplete after 240 seconds: Sonic completed one Act (32,150 points, six specials/five Homing hits); Tails completed two (30,825 points, seven flights). Neither escaped the course, and both used one ball. These are automated simulated times, not human completion estimates. The new response benefits the Normal samples but does not universally improve the same bot's Hard aiming.

Final shared checks passed: physics **38**, primary/middle flipper recovery **12**, side/upper recovery **10**, Chao Lab **29**, Character Lab **70**, Scorecraft **37**, Score Attack **26**, Act pinball **38**, Zone lifecycle **34**, Zone composition **103**, and the isolated Godot import. The Chao comparison retains approximately 11% greater observed upward speed and 19–22% greater height in the two tested profiles; the earlier, stronger inward bias failed that meaningful-power check and was retuned. Native moving-paddle response still contributes to total velocity, so 35% more added impulse does not promise 35% more final speed.

The broad physics test initially labelled an already-drained body falling below the table during its respawn delay as a rail escape. Its eligibility now matches active-shot state and is sampled before stepping, so a real escape cannot be hidden by a newly triggered respawn. No bounds or active-shot collision requirement was relaxed. Additional legacy upper catches passed all 18 mirrored physical fixtures unchanged. Human playtesting still needs to judge the timing window, whether the short Climb catch earns its visual placement, and Hard 24's demanding final routes. The controlled catches support deliberate shot design; they do not establish enjoyment or a universal success rate.

## Normal/Hard authored Act composition — 2026-10-24

Zone generator v3 replaces the repeated development corridors with six Normal and six Hard rooms. Each Act combines recovery, a distinct interaction chamber and an exit approach; the final Act retains a shaped capped objective room. Normal uses 160px Curve collars, Hard uses 240px Bank collars, and both retain the existing maximum bank grade of 0.75. The full compiler clearance checks run again after shaping. Official Easy selection and standalone Free Play/Score Attack resources remain intact.

`zone_normal_rooms.gd`: **48 checks passed**. Every Normal room accepts a real upward shot in both mirrors. All seven authored paddles catch a descending ball and then physically hit their named bumper or collect their named ring; the seven selected seed-28 paddles repeat that result after connector shaping. `zone_hard_rooms.gd`: **35 checks passed**, covering six compiled rooms, twelve mirrored upward shots, ten mirrored scoring recoveries, and four recoveries in the final shaped seed-24 rooms. These are controlled 120 Hz fixtures with one prescribed starting trajectory and timed flipper inputs, not claims of human skill or enjoyment.

`zone_composition_regression.gd`: **103 checks passed**. Six Normal/Hard examples and both alternative shuffles retain the requested roles and difficulty in every Act, five unique relay IDs, different interior silhouettes, measured Hard precision lanes and flowing joins. Repeated seeds reproduce transforms and composition. Counterexamples reject a single severe cap promoting otherwise Normal Acts, or broad empty rooms labelled Hard. Real physics checks cover twelve internal seam shots, four complete Act-boundary arrivals, six primary recovery shots, six central drains, frozen drafts and checkpoint state retention across Normal 28 and Hard 24.

Review identified a real progression defect exposed by offset mouths: completion at the next funnel's safe-entry line still checked the old gate's narrower X span. Completion now derives its own span from the incoming outline, inset by rail and ball radii; the physical gate keeps its original bounds. `zone_offset_entry_regression.gd`: **12 checks passed headlessly and graphically with ANGLE**. An actual Hard 24 shot enters the gate at x = 150.26, then fans left to cross the safe line at x = 95.72. The old span 110–705 rejected it; the actual chamber span 81–719 accepts it. Locked targets and crossings outside that safe span remain rejected. The draft freezes the arrival and reward selection preserves its body/momentum before activating the new funnel and sealing the old gate. Existing Zone lifecycle regression also passed **34 checks**.

### Ordinary-input character comparison

Final reruns include the offset-entry fix. The same timed-flipper/alternating-steering policy uses earned specials, ordinary gravity serves and public Spring/Ice/Magnet draft choices. No score, meter, position or velocity is injected. These are simulated seconds at 120 Hz, not human completion estimates.

| Layout | Character | Progress within 240 seconds | Score | Rings | Balls | Specials |
| --- | --- | --- | ---: | ---: | ---: | --- |
| Normal 28 | Sonic | Completed at 171.59 s | 20,500 | 59 | 1 | 5 activations, 5 actual Homing hits |
| Normal 28 | Tails | Two Acts; reached final cap | 24,300 | 50 | 1 | 5 flights |
| Hard 24 | Sonic | Two Acts; reached final cap | 32,350 | 57 | 1 | 6 activations, 5 actual Homing hits |
| Hard 24 | Tails | Two Acts; reached cap entrance | 25,175 | 62 | 2 | 6 flights |

All four runs physically crossed both Act boundaries without a side/top escape. First READY occurred at 20.35/34.62 seconds for Normal Sonic/Tails and 20.74/28.23 for Hard. The three incomplete runs remain incomplete evidence: high score did not replace the final aimed climb, and the same bot policy handles the characters differently. No difficulty or score target was reduced to force a successful survey.

`zone_cap_shots.gd`: **3 checks passed** proving Hard 24's final portal and recovery route are reachable. A prescribed entry from (355, 730) with velocity (-120, -900) reaches the actual portal detector after 86 ticks and one bumper contact. A second entry from (405, 730) with velocity (160, -700) reaches it after 327 ticks, three timed cap-paddle strikes and three bumper hits. Both include the shaped cap and neighboring room, normal Balanced physics and no subsequent position/force edits. These controlled witnesses explain a reachable aiming challenge; they do not erase the bot's failed final climbs.

### What differs visibly and mechanically

Normal 18 starts Bank Return into the paddle-free Winding Lane; Normal 28 starts Target Garden into Offset Crown; Normal 41 starts Crosscourt into Balcony. Hard 24 starts Bank Vault into Offset Climb. Hard 29 instead starts Target Cove into Needle Gate; Hard 41 starts the paddle-free Split Orbit into Needle Gate, later Bank Vault into Switchback. These change target routes, recovery coverage and room silhouettes. Hard 18 and Hard 24 have the same room order and mainly differ in Act 2 mirroring; their different signatures alone are not evidence of a new design.

Needle Gate's controlled upward route threads x = 475 (mirrored: 325) between large targets, while a center shot misses. Bank Vault's unequal pair reaches different scoring targets; Offset Climb's short optional paddle can hit its upper bumper. That short paddle still looks isolated from the wall: its role is a precise bonus shot, not side recovery. Human review should decide whether the shot earns the placement. Shared checkpoint decks remain repeated recognizable recovery spaces. Human timing fairness, sustained room interest and Tails' final climb remain open playtesting questions.

Graphical ANGLE verification produced **nine full overviews and six close-ups** with `zone_design_capture.gd`: Hard Free Play24/Zone24; Normal Free Play29/Zone28; additional Normal18/41 and Hard18/29/41. Baseline comparisons remain separately named. Final captures wait for the ordinary deferred serve reset before pausing; they do not place Sonic at an old table's coordinates. Files are `test-results/zone-design-*.png`, with JSON manifests; captures remain local and ignored. UI regression passed **19 graphical checks**, including Layout shuffle A/B/C naming, sandbox labels, development-tier persistence and route identities.

Compatibility checks passed: physics **38**, Score Attack **26**, Character Lab **70**, Scorecraft **37**, Act pinball **38**, Grid construction **23**, Grid Easy **22**, and Easy Zone generation **21**. The grid suites reproduce existing v11 geometry fingerprints and preserve regeneration behavior. The isolated Godot editor import also passed. Expected invalid-recipe/configuration diagnostics are exercised deliberately; no final failed assertions or unexpected script errors occurred. Source models, ArtBro's separate branch/worktree and the preexisting `project.godot` edit are preserved.

## Playfield design, gravity serves and Act funnels — 2026-10-24

The final serve follows the user's review: no cup, spring or preset launch velocity. Enter / X releases the waiting character into ordinary gravity at the generated side marker. The existing flippers supply the first upward shot. Checkpoint retries use the same release. New Act-bottom funnels stay retracted until a physical upward shot clears their generated safe-entry line; drafting preserves the same body and momentum before activating the next funnel.

`act_pinball_regression.gd`: **38 checks passed headlessly and graphically with ANGLE**. Controlled real-physics fixtures cover waiting and zero-impulse release, left and right recovery strikes in all three Acts, three missed shots through their central gaps into active 2D sensors, checkpoint retry, weak upward entries returning without advancement, both successful full-clear crossings, frozen drafts, unchanged arriving momentum, gate closure, score/Chao retention and clean same-seed replay. These fixtures prescribe starting trajectories and target scores; they are separate from the ordinary-input surveys below.

`playfield_catalogue_regression.gd`: **25 checks passed**, including real contacts with wall-mounted circles, bank-mounted circles and triangular slings. `zone_generation_regression.gd`: **21 checks passed**, spanning twelve seed/grid layouts, deterministic regeneration, five distinct relay archetypes per Easy Zone and eight actual upward seam crossings. The library contains eight authored Easy archetypes plus two Hard recipes; Normal reuses its existing flowing geometry. Collision validation remains separate from difficulty estimates.

`zone_difficulty_regression.gd`: **13 checks passed** for the F1 selector, complete Normal/Hard builds, replay persistence, explicit failed-generation preservation, official Easy restoration and UI fit. `launcher_visual_regression.gd`: **12 graphical ANGLE checks passed** for the final gravity serve, flat marker, low release speed, ordinary downward motion, pause and reset. The filename retains its original experimental name; there is no plunger in the final behavior.

Compatibility reruns passed: physics **38**, Score Attack **26**, Chao Lab **29**, rings **11**, Character Lab **70**, Scorecraft **37**, Zone **34**, and flipper recovery **12**. Act drain fixtures now use generated drain markers, and progression fixtures use the safe-entry line rather than the old flat checkpoint boundary.

Grid construction **23** and Grid Easy **22** checks passed, including their seed matrices, actual moving-paddle passage/recovery and regeneration. An independent audit reproduced all fourteen prior v10 geometry fingerprints after removing only the two new lower-funnel rail segments; reviewed v11 expectations include that intended change. The regeneration checks exposed and fixed replacement of unchanged bottom paddles when a generated wall collar changes. Paddle identity now follows its own placement descriptors independently of the lower collision section. Isolated editor import passed. Graphical ANGLE mode-transition smoke passed **14** checks across Free Play, Zone, replay and Score Attack. Deliberately invalid recipes/configuration emit expected diagnostics; final checks had no unexpected script errors or failed assertions.

### Input-only Zone play with the final gravity serve

These runs use ordinary launch, steering, timed flippers, earned special meter and public Spring / Ice / Magnet draft choices. No score, charge, position or velocity is injected. Times are simulated seconds at 120 Hz, not human completion estimates.

| Seed / policy | Completion | Score | Rings | Balls | Special use |
| --- | ---: | ---: | ---: | ---: | --- |
| 18, Sonic character survey | 159.60 s | 14,325 | 55 | 1 | 4 activations, 2 actual Homing hits |
| 18, Tails character survey | 175.44 s | 13,925 | 79 | 2 | 5 flights |
| 41, alternating route policy 2 | 149.16 s | 18,000 | 64 | 1 | No specials |

All three runs physically completed all three Acts and drafts without a side/top escape. Seed 18 first READY occurred at 28.69 s for Sonic and 30.51 s for Tails. Seed 41 unlocked Acts at run times 8.66 / 91.05 / 106.53 s and reached their physical exits at 76.24 / 97.93 / 149.16 s. Targets remain 750 / 1,250 / 1,750: these samples still require substantial travel after score unlock and do not justify arbitrary target inflation.

The gravity start supplies a readable first recovery shot, and both characters can traverse the new course through ordinary input. Controlled contact tests establish that misses and last-second recoveries work in each Act. They do not establish subjective fun or human timing fairness. Human review should compare seeds 18 / 23 / 41, judge the marked full-clear entrance on a weak shot, and try late flipper recovery on each funnel. Development Normal/Hard builds are geometry experiments, not evidence of balanced full-Zone completion.

`pinball_design_capture.gd` records three full-Zone layouts and all three active Act-bottom close-ups with the graphical Green Hill presentation. Still-image progression uses explicit fixtures and must not be mistaken for input-only play. Captures and logs remain under ignored `test-results/`; no third-party assets are added. ArtBro's separate worktree and the preexisting `project.godot` edit are preserved.

## Scorecraft v1 — 2026-10-24

The shared award calculator uses a 3-second window, three rings per ring link and a ×3 cap. The first trial allowed fresh bumpers alone to reach ×3. That produced 29–39 seconds at ×3 in two-minute Free Play trials, with little distinction between bumper-seeking and ring-seeking inputs. The final rule requires a completed ring link for ×3; fresh bumpers alone stop at ×2. This reduced top-tier uptime to 3–11 seconds while retaining the same physics and ordinary input policies.

`scorecraft_regression.gd`: **37 checks passed headlessly and graphically with ANGLE**. It covers capped awards, partial/extra rings, target history across A–B–A–B repeats, expiry, configurable thresholds, baseline awards, fixed rack clears, and Homing's additive bonus. A controlled real-physics fixture hits a bumper, collects three rings for 100 + 25 + 25 + 50 = 200, then earns exactly 700 from actual Homing contact. Meter remains ordinary +2/+5. Other checks cover paused timers, the live comparison toggle, Score Attack threshold observation, Zone subtotal accounting, frozen drafts, Act advancement, checkpoint drains, late contacts, Chao retention and regeneration cleanup. Controlled fixtures prescribe positions/meter and are separate from the input-only surveys below.

Existing suites passed: physics **38**, Score Attack **26** (including 27 seeded Easy/Normal/Hard catalogue/grid builds), Character Lab **70**, Chao Lab **29**, Zone **34**, rings **11**, profiles **8**, Chao builds **18**, plus **13 graphical special-presentation checks**. Isolated editor import passed. Expected invalid-layout/configuration diagnostics and the restricted-profile root-certificate warning remain; no unexpected script errors or failed assertions occurred in final checks.

### Same-seed scoring comparison

`scorecraft_play_survey.gd` uses ordinary launch, steering, timed flippers, earned special meter and public Chao choices. No score, meter or trajectory is injected. Seed 18, Easy catalogue, 120 simulated seconds per policy, combos enabled:

| Input policy | Total score | Same contacts at baseline values | Added combo points | Time at ×3 | Special use |
| --- | ---: | ---: | ---: | ---: | --- |
| Bumper seeking | 11,375 | 8,450 | 2,925 (+35%) | 3.95 s | None |
| Ring seeking on ascending shots | 11,075 | 8,100 | 2,975 (+37%) | 3.01 s | None |
| Ring seeking plus Sonic Homing | 14,675 | 10,750 | 3,925 (+37%) | 11.13 s | 2 activations, 2 hits |
| Tails with falling-flight activation | 11,800 | 8,150 | 3,650 (+45%) | 8.99 s | 2 flights |

The shadow baseline column sums original base awards plus the special bonus for the **same actual scoring events**, avoiding a false causal comparison between diverging physics trajectories. Separate baseline-mode runs produced 7,750 / 8,425 / 8,650 / 8,625 points respectively. Repeated bumper contacts stayed at 100 in all combo runs; 35 / 31 / 43 / 27 contacts received no combo uplift. ×3 was intermittent, not an automatic permanent buff. Ring-seeking input did not reliably collect more rings or beat bumper-seeking input; this simple bot is not evidence of skilled human routing. The controlled sequence demonstrates the reward, while human aiming and enjoyment remain open questions.

An initial survey escape flag incorrectly included balls already below the open drain during the 0.65-second respawn delay. Logged positions established this in baseline and combo runs. The final survey checks side escapes at playfield height and always checks top/non-finite escapes; it does not change gameplay collision or drain logic. All eight final Free Play trials and both Score Attack trials reported no playfield escape.

### Act targets and actual progression

Seed 18 Zone, the existing alternating-steering route policy, ordinary flippers, and Spring / Ice / Magnet draft choices:

| Act | Target retained | Baseline unlock, seconds since Act entry | Combo unlock, seconds since Act entry | Combo physical exit, run seconds |
| --- | ---: | ---: | ---: | ---: |
| 1 | 750 | 8.20 | 4.91 | 10.78 |
| 2 | 1,250 | 19.19 | 10.33 | 76.79 |
| 3 | 1,750 | 20.44 | 16.03 | 218.28 |

Baseline completed at 204.93 seconds with 12,575 points; combos completed at 218.28 with 17,800. Gate opening changes later trajectories, so earlier score unlock does not guarantee earlier completion. Targets remain 750 / 1,250 / 1,750: scoring is shorter, but the upper climb remains substantial. This sample does not justify simply multiplying all targets by the combo cap.

Tails completed the same Zone with four earned flights at 95.83 seconds, 7,350 points and seven balls; its baseline run reached Act 3 but did not finish within 180 seconds. Separate Score Attack / grid-variant play reached the goal with combos at 39.03 seconds and 3,750 points; the baseline policy did not finish within 90 seconds. These are sampled input policies, not character balance or success-rate claims. The Character Lab suite separately verifies flight near locked gates, modifier restoration and special-meter lifecycle.

Graphical Green Hill play reached ×3 naturally and produced `test-results/scorecraft-play.png`; the shared combo HUD was inspected for readable timer, action hint and award feedback. Human checks: attempt the same seed with combos on/off, deliberately bank into three rings then a fresh bumper, choose a Homing finisher, and judge whether three seconds is readable under controller play. Human feel, timing pressure and whether ring routes are enticing enough remain unproven.

## Character presentation merged into main — 2026-10-23

Integrated ArtBro's `1e363ac` on top of gameplay/lifecycle commit `e5bc124`. Green Hill now uses the generic Sonic/Tails presenter for homing, actual-contact impact, rotating-tail flight and return to spin. The original playground keeps its minimal placeholder; gameplay and the ANGLE launcher workaround remain shared.

Checks executed from the primary checkout: isolated Godot import passed; graphical ANGLE Character Lab **70/70**; special presentation **13/13** with prepared models and **13/13** without models; orientation **13/13**; physics **38/38**; Score Attack **26/26**; Zone **34/34**. Launcher PowerShell syntax passed. The Zone fixture deliberately rejects an invalid configuration. Restricted-profile runs retain the known root-certificate warning; no unexpected script errors or failed assertions occurred.

Inspected the merged rendered Tails flight capture at `test-results/character-lab-tails.png`: textured model, flight pose, shared HUD and Green Hill table are visible together. This capture uses a controlled meter fixture, not a new input-only playthrough. ArtBro's earlier input-only captures and results remain documented in the visual-lab README. Human animation feel and controller timing remain playtesting tasks.

Copied the two prepared runtime GLBs from the visual worktree into the primary checkout and verified matching SHA-256 hashes. Backed up the prior Sonic GLB before replacement. Models and backups remain Git-ignored; no third-party asset is added to the repository. The preexisting `project.godot` edit is preserved byte-for-byte, and ArtBro's branch/worktree remains intact.

## Character Lab v1

Presentation-contract follow-up: **70 headless Character Lab checks passed** after adding `homing_started(target, direction)` and `homing_ended(reason)`. The additional checks verify target-facing direction and active duration at start, no lifecycle events for rejected activation, cleared state at end, successful-hit event order, expiry without impact, and exactly one cancellation notification across repeated cleanup. No force, scoring, targeting or flight tuning changed in this follow-up. Signal ordering and adapter ownership are documented in the README's Character Lab section.

`character_lab_regression.gd` passed **45 checks headlessly and 45 graphically with ANGLE**. It exercises real 120 Hz homing contact from stationary, falling, opposing and fast-falling trajectories; full-shape obstruction rejection; insufficient/no-target charge preservation; a closing-wall miss; one 500-point award with ordinary +2 recharge; actual Tails fall recovery; fade restoration; pause; Chao/Practice compatibility and pending-character previews; character switching; all three UI mode entries; a locked Act gate; Act carryover; checkpoint drain and replay cleanup. Fixtures deliberately prescribe starting positions, velocities and meter. They are not input-only runs.

The initial 1,200 px/s homing impulse limit landed 2/5 specials in the 180-second Zone survey. Raising the impulse limit to 2,600 while keeping the aimed speed at 1,050 produced 7/8 actual hits. In the controlled fall probe, Tails fell 269.84 px over 0.375 seconds without flight; with flight he rose 16.42 px. Flight retained normal gate collision and restored the exact permanent profile/Chao result afterward.

`character_play_survey.gd` uses only ordinary launch, steering, flippers, Special requests, earned meter and public draft choices. Both characters use seed 18 and the same trigger/steering policy; Tails activates while falling, Sonic when a clear target is available. No score, charge or trajectory is injected. Final headless results:

| Mode / layout | Sonic | Tails |
| --- | --- | --- |
| Zone, catalogue, up to 180 s | First READY 24.61 s; 8 specials, 7 hits; 14,350 score; 1 Act completed; 15 balls | First READY 18.88 s; 5 flights; Zone complete at 91.87 s; 5,575 score; 7 balls |
| Free Play, Grid base, 60 s | 1 special/1 hit; 4,725 score; 2 balls; minimum Y 77 px | 1 flight; 4,350 score; 1 ball; minimum Y 574 px |
| Score Attack, Grid variant, up to 60 s | 1 special/no hit; 4,550 score; 2 balls; goal not reached | 1 flight; goal reached at 42.64 s; 3,450 score; 1 ball |

No side/top escape occurred. These divergent paths support the experiment, but do not establish character win rates or subjective fun. Automatically firing toward the nearest bumper can harm Sonic's climb; players should choose the moment. Tails' lower gravity and rescue window may need tightening after human playtesting. Full-meter cost gives roughly 19–33 seconds to the first charge in these samples; later charge timing varies with rings, drains and routing.

Godot ran graphical ANGLE physics/lifecycle checks and produced inspected Sonic target, Tails flight and READY HUD captures under `test-results/`. A longer graphical input survey was interrupted after its first Sonic activation capture; the full comparison above is headless. Existing regression reruns passed: profiles 8, physics 38, Score Attack 26, Chao Lab 29 and Zone 34. Restricted-profile runs emit the known root-certificate-store warning; no network function is used. Controller hardware, subjective timing and final visual polish remain human checks.

## Windows graphics crash workaround

The user's Zone-start/replay crash returned `-1073741819` (`0xC0000005`). Windows Application Error event 1000 and Godot's saved backtrace both identified `nvoglv64.dll` (NVIDIA 616.64) after the initial three-section scene reported ready. There was no GDScript parse error. The same native-driver transition did not crash in the diagnostic rerun, so the precise trigger is not established.

The launcher now requests `opengl3_angle` with the same Compatibility renderer, using Direct3D 11 on this machine. `-GraphicsBackend Native` retains the prior driver for comparison. Dedicated current/previous runtime logs preserve evidence without depending on the user-data folder. This is a targeted graphics-path workaround, not a claim to have repaired the NVIDIA driver.

`tests/render_transition_smoke.gd` exercises rendered Free Play launch, entering Zone from Free Play, Zone replay, return to Score Attack, and return to Free Play. It checks actual scene bounds and simulates after each rebuild, with a rendered Zone capture. Both native OpenGL and ANGLE runs passed **14 checks**; startup-only runs also exited normally. The existing Zone UI regression covers the final-reward/victory replay separately. Earlier verification below records the original native OpenGL runs.

ANGLE also passed **21 graphical Zone UI checks**, including victory replay. The actual PowerShell launcher completed its import and gameplay capture using the normal Windows user profile; the runtime log confirmed ANGLE / Direct3D 11 and exit code zero. Its rendered Zone capture was inspected for intact terrain, character, flippers and HUD.

## Green Hill Zone prototype

The optional Zone uses nine connected chunks and the same invisible 2D body. Existing Free Play and standalone Score Attack remain three-section modes. New deterministic checks:

- `zone_generation_regression.gd`: **21 checks**. Twelve seed/grid combinations, repeatability, unchanged source resources, Easy estimates, eight validated seams, one launch deck and one final cap, transformed checkpoint/portal clearance, complete flipper swings, and real 2D passage through all eight open seams at 1,200 px/s.
- `zone_regression.gd`: **34 checks**. A 12,000 px/s locked-gate rebound; exact score threshold through existing ring callback; physical boundary crossing; mandatory pause; unchanged body identity/position/velocity across drafts; checkpoint drain/automatic retry; isolated Act scoring and ring eligibility; final reward/victory; replay; both grid variants; invalid-config preservation; and restoration of the prior sandbox Chao. State fixtures intentionally set points/trajectories; they are separate from the play witness. Invalid configuration emits an expected rejection diagnostic.
- `chao_build_regression.gd`: **18 checks** for bounded copies/slots, resolver order and clamps, isolated previews, atomic invalid edits, repeated equip, profile changes, Practice replacement and reset.
- `zone_ui_smoke.gd`: **17 headless checks**, with additional screenshot checks when rendered. Both presentations were inspected for readable HUD/draft/completion, viewport fit, pointer blocking, keyboard focus containment, duplicate-pick controls and replay cleanup.

Existing regression passes during integration: physics **38**, rings **11**, profiles **8**, Score Attack **26**, Chao Lab **29**, generation UI **15**, and vertical camera **22**. The Score Attack regression also ran graphically. These retain Easy/Normal/Hard and grid coverage. No steering, flipper-strike or ball integration formula changed.

### Actual input-only completion

`tests/zone_play_survey.gd` launches normally and uses the ordinary input adapter, actual ring/bumper callbacks, automatic drains and public draft choices. It never assigns ball position/velocity or score. Reproduce with:

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --fixed-fps 120 --script res://tests/zone_play_survey.gd -- --seed=18 --grid=0 --trigger=58 --policy=2 --seconds=240
```

Balanced, seed **18**, mixed Easy relays, alternating half-strength steering and a 58 px flipper trigger completed in **204.93 simulated seconds**, with **12,750 points**, **182 rings**, **18 balls** and **Spring / Ice / Magnet**. All three scores came from existing gameplay events. No side/top escape occurred.

The same witness also ran graphically in Green Hill with identical event times, positions, velocities and result. The captured completion screen was inspected. For a rendered replay, remove `--headless` and add `--green-hill` after `--`. Fixed-fps diagnostic runs advance simulation per rendered frame; their wall-clock duration is not a normal-game performance measurement.

| Act | Score unlock (run seconds) | Physical exit / portal (run seconds) | Act score at completion | Reward |
| --- | ---: | ---: | ---: | --- |
| 1 | 8.21 | 38.57 | 2,975 | Spring |
| 2 | 57.77 | 131.60 | 5,000 | Ice |
| 3 | 152.05 | 204.93 | 4,775 | Magnet |

The first two boundary crossings retained upward velocities of approximately **488** and **1,825 px/s**. A different seed-18 steering policy completed only two Acts within 240 seconds despite enough points; seed 1 without ordinary steering completed only one. The score phase is achievable, while the climb remains meaningful. This is evidence of a playable loop, not a human enjoyment, win-rate or balance study.

Provisional targets stay **750 / 1,250 / 1,750** in `data/green_hill_zone.tres`. Deliberately modest thresholds avoid extended farming before the climb. Rewards use a fixed three-choice pool, with at most two copies per species and five slots; this Zone awards three picks. Completed gates latch physically, and falling toward a latch triggers the current checkpoint retry. This simple return mechanism avoids both completed-Act fallback and a flat-floor trap.

Graphical UI checks passed **21/21** in Green Hill after a replay fix. Unpausing directly inside deferred regeneration exposed Godot's [2D deferred-unpause issue](https://github.com/godotengine/godot/issues/122378). Replay now resumes on the next process frame, after the rebuild, with no native query-list warning. Draft choices preserve their immediate input-driven resume. Existing standalone Score Attack replay still passes.

Limitations: full nine-chunk validation measured approximately **3.9–4.3 seconds** alone, or **5.3–7.4 seconds** under concurrent test load. Overview fits all nine sections but is necessarily small. Human playtesting should judge recovery timing, gate returns, checkpoint serve comfort, the reward pause, and whether repeat copies overpower later climbs. The final reward is retained in the victory summary only; there is no second Zone or persistence across app restarts.

## Chao Lab v0

`tests/chao_lab_regression.gd` passed **29 checks**, headlessly and graphically. Coverage includes single-slot resolution, repeated equip, immutable profiles, clamped overrides, profile changes, Practice replacement and toggle synchronization, preview/cancel pause restoration, same-seed equip, real magnet pickup/score signals, rejection during active play, ball reset, drain/respawn/relaunch, typed Score Attack target/mode application, exact threshold, victory replay, grid/difficulty regeneration, invalid IDs and failed-build preservation. An intentionally invalid recipe emits its expected rejection diagnostic. Final lab and equipped HUD captures were inspected in Green Hill; all three cards and controls fit, and the equipped name remains visible with the debug HUD hidden.

Actual 120 Hz physics comparisons use fresh bodies and identical initial conditions, followed only by ordinary input:

| Probe | None | Chao | Observation |
| --- | ---: | ---: | --- |
| Half-second right input, Balanced | 26.14 px travel | Ice: 39.03 px | About 49% more lateral travel; sustained contribution remains capped at 150 px/s. |
| Counter-steer from −100 px/s for 15 ticks | −53.33 px/s | Ice: −18.33 px/s | Faster braking without instant reversal. |
| One controlled paddle strike, Balanced | 1,816.8 px rise | Spring: 2,220.6 px | About 22% more height; one impulse only. |
| Same strike, Floaty | 3,052.8 px rise | Spring: 3,646.2 px | About 19% more height; one impulse only. |
| Stationary ring 80 px from ball | Unclaimed | Magnet: claimed immediately | Existing score/pickup signals fire once; no ball force or ring-home displacement. |

Spring's initial ×1.25 effect was too subtle in the chosen moving-paddle contact. ×1.35 produced a clear gain in both profiles. Larger sampled values changed the native contact timing and did not monotonically increase height, so the implementation retains the shared mechanics and a moderate multiplier. These isolated heights are measurement fixtures, not reachable heights inside a capped table.

`tests/chao_play_survey.gd` passed **8 containment checks**: Normal seed 18, None and all three Chao, Balanced and Floaty, 40 simulated seconds each. The same feedback-input policy drives every sample from the normal serve; it never edits position or velocity after launch. All remained within side/top bounds, with distinct trajectories, ring counts and scores. None dominated all runs: Balanced scores were 3,975 / 3,875 / 3,100 / 2,825 (None / Ice / Spring / Magnet); Floaty scores were 2,250 / 3,150 / 2,525 / 4,475. These are short diagnostic observations, not player success rates or proof that an upgrade always raises score. The precise ring-radius comparison above isolates Magnet's benefit from chaotic trajectory changes.

Existing checks passed: physics **38**, profiles **8**, rings **11**, vertical traversal **25**, Score Attack **26**, and steering UI smoke. The safe launcher import and Green Hill startup also passed. Logs, survey JSON and captures are under ignored `test-results/`. Sandbox runs still report the unrelated Windows certificate-store diagnostic.

**Human check:** Replay Normal seed 18 with None, Ice, Spring and Magnet at the same profile and target. Judge whether Ice makes late saves manageable, whether Spring's extra power rewards retiming rather than feeling erratic, and whether Magnet's expanded collection is readable. Repeat once in Floaty and an Easy grid layout. Gamepad menu navigation and subjective fun remain human checks. No Chao artwork, campaign, drafting or permanent progression was added.

## Launcher indentation repair

Reproduced the reported `game.gd:163` parse failure using a fresh default editor profile: both editor startup and `--import` converted its four-space indentation to a tab during editor restoration. The earlier test profile's one-space preference masked this behavior. Restored the affected local line and changed the Windows launcher to use a private, version-matched import profile with `convert_indent_on_save = false`. The caller's environment is restored in `finally`, before gameplay; global editor settings are untouched.

Verified `-ImportOnly` with both the installed GUI executable and the automatically detected console executable. A repeated import preserved hashes of all **47 tracked GDScript files** and restored `APPDATA`. The full automatic launcher completed a graphical `-Capture gameplay -CaptureFrames 20` run, returned zero and produced an inspected Green Hill image. Import diagnostics remain strict; script failures are not suppressed. Existing local `project.godot` changes remain outside the commit.

## Side recovery and rounded Easy grid routes (generator v10, kit v2)

Middle paddles now sit nearer the walls, with full-ball passage behind their complete swing. Rebound Relay uses 120 px paddles: moving its former 110 px pair outward made direct shots into a Hard neck too scarce in the initial samples; 10 px more reach restored a tested route. Every upper resource and the fallback adds one 70–85 px paddle. Easy grid recipes use rounded 30 px banks and short curved seam collars, removing their horizontal inset steps without relaxing corridor, tier or collision checks. Green Hill's grid shortcuts previously forced Normal; they now preserve the active seed/difficulty and show the difficulty in the footer.

- `tests/side_recovery_regression.gd`: **10 checks passed**, graphically and headlessly. Covers 24 reproducible Easy grid configurations, both mirrors of all nine upper resources, complete swing clearance, side pivots, regenerated bodies/visuals, and the actual Green Hill grid buttons. All 18 upper recovery trials used a fresh descending ball and one real strike, rising at least 150 px. Graphical captures of both Easy grid variants show five paddles, rounded banks and matching collision outlines; the base overview and close view were inspected.
- `tests/grid_easy_regression.gd`: **22 passed**; `tests/grid_chunk_regression.gd`: **23 passed**. Easy remains in tier with at least 618 px checked junction corridors. Existing bidirectional seam, high-speed containment, recovery, drain and regeneration checks pass. Full geometry fingerprints now deliberately record v10 paddle placements; separate historical static-geometry fingerprints remain enforced.
- `tests/vertical_shot_survey.gd`: **18 passed** across seeds 1/2 and all three difficulties. All **432 controlled strikes** delivered exactly one impulse and remained finite. Bottom and middle shots reached the next chamber in every sampled layout; continuous input-only runs provide full ascent/descent witnesses for each of the three middle designs. The diagnostic adds 75%/80% paddle contact points and 52/50 px press distances while retaining previous samples and assertions. Earlier sparse samples missed the changed Hard aiming windows. Hard seed 1 still failed its sampled continuous policies despite a valid controlled shot; this is not a guarantee of easy completion.
- `tests/connector_transition_regression.gd`: **31 passed**; `tests/normal_flow_regression.gd`: **17 passed**; `tests/flipper_recovery_regression.gd`: **12 passed**. Normal 18/23 complete uninterrupted ascent/descent samples, and passive banks retain their collision behavior. Hard authored corners remain intact.
- `experiments/visual_lab/playable_smoke.gd`: **25 passed**, including actual short-upper-paddle pose events, retained settings and input-only launch/traversal/drain/relaunch runs. `tests/vertical_camera_smoke.gd`: **29 passed** graphically. `tests/score_attack_regression.gd`: **26 passed**, including exact unlock threshold, required goal contact, replay and regeneration.
- Additional shared regressions passed: physics **38**, profiles **8**, rings **11**, vertical traversal **25**, generation UI **15**. Final headless editor import and Green Hill startup passed with the local Sonic model loaded. Invalid-recipe rejection logs its expected diagnostic. Sandbox runs log the existing Windows certificate-store access error, unrelated to offline gameplay.

**Human check:** Launch Green Hill, build Easy / seed 8, then switch Grid base / Grid variant with the footer buttons. Judge side-lane clearance and whether the upper paddle makes a missed final climb worth recovering. Try Hard afterward: its precise neck shots remain substantially less forgiving. Visual review and automated routes support usability, not a claim of human-tested fun. Scenery and character animation assets were not changed. Captures and tuning probes remain in ignored `test-results/`.

## Optional Score Attack

Free Play stays the default. Score Attack uses the existing score callbacks and a swept 2D proximity check against a transformed upper-section anchor. It adds no colliders, physics tuning or generator changes. The default target is provisionally 1,500; the goal radius is 55 px plus the ball's 14 px contact radius.

- `tests/score_attack_regression.gd`: **26 checks passed**. Covers locked contact, exact threshold, score farming without completion, swept contact, one-shot victory, default Free Play, real scoring callbacks including the rack bonus, mode UI, automatic drain/respawn with retained progress, reset sampling, latched victory, replay, Next table, paused regeneration, ring/timer cleanup and return to Free Play. Checks include all 28 catalogue mirror/shift/translation combinations and 27 complete seeded builds (seeds 1, 2, 12 × three difficulties × three construction modes). Selected goal anchors pass the existing whole-course route validator with the actual generated geometry. This establishes coarse connectivity, not every physical trajectory.
- Graphical lifecycle fixture: the original **24 checks passed** before the two additional Next-table/pause checks. Free Play, locked-goal overview and victory screenshots were captured and inspected. Controls fit their margins, goal colors/text read correctly and the victory panel is clearly visible. A subsequent graphical input-only Normal run reproduced its headless victory and supplied `test-results/score-attack-play-clear.png` with the actual 1,500 target and 4,025 final score.
- Existing regressions rerun: physics **38**, rings **11**, profiles **8**, vertical traversal **25**, grid construction **23**, and generation UI **15** checks passed. Grid invalid-recipe rejection emits its expected diagnostic. Initial parsing exposed a mixed-indent line in the shared game file; it was repaired before these passing runs. Sandbox runs also log Windows certificate-store access failure, unrelated to offline gameplay. No remaining gameplay script error was observed.
- Final headless editor import and main-scene startup passed. The repeat indentation fault came from the temporary editor profile converting four spaces to a tab; that ignored profile now uses the repository's one-space indentation, and the source remains unchanged by import. Existing user `project.godot` changes were left out of this commit.

`tests/score_attack_play_survey.gd` uses normal serve, actual scoring and unlimited automatic drain recovery. After launch it changes only ordinary virtual flipper/steering inputs; there are no teleports, score injection, velocity edits or physics changes. Balanced profile, Quick / Tight steering, no modifier. Each attempted policy gets 90 simulated seconds, with three trigger distances tried only when needed. Steering aims toward the goal within the top chamber. These are diagnostics, not human completion rates.

| Layout | Successful policy completion | Final score |
| --- | ---: | ---: |
| Normal catalogue, seed 1 | 51.88 s | 4,025 |
| Hard catalogue, seed 1 | 19.62 s | 1,525 |
| Easy Grid base / variant, seed 2 | 74.93 / 66.08 s | 5,425 / 5,075 |
| Normal catalogue / Grid variant, seed 2 | 67.13 / 46.94 s | 4,850 / 3,275 |
| Hard catalogue / Grid base / Grid variant, seed 2 | 34.86 / 24.96 / 85.89 s | 2,525 / 2,525 / 6,550 |

The five initial seed-1 trials and sixteen seed-2 trials all reached the score threshold in roughly 13–32 seconds. Easy catalogue seeds 1/2 and Normal Grid base seed 2 did not complete under the sampled policies; some trajectories reached the top but missed the goal. Failed samples remain meaningful evidence: points alone cannot win, and the final climb/aim remains the challenge. No difficulty or safety geometry was changed to make the bot pass. Automated winners demonstrate that the complete objective works across all three preferences and both grid variants; they do not prove every seed equally accessible.

**Short human checklist:** Try Normal seed 1 at 1,500, then Easy Grid base seed 2. Judge whether unlocking feels too early, whether the final target is readable during follow-camera play, and whether retries make the climb satisfying rather than repetitive. Check gamepad menu navigation and flipper timing by hand. Art can replace `ScoreAttackGoal` using `game.score_attack.changed/state/goal_position` without controlling detection. Logs, diagnostic JSON and captures remain in ignored `test-results/`.

## Genuine Easy layouts for grid modes (generator v9)

Grid base and Grid variant now use dedicated 800 × 700 px recipes when Easy is requested. Their 700 px openings replace the original 600 px openings, the sharper right-wall slopes become gentle banks/curves, and recovery paddles sit farther apart. The authored rating remains 28; the unchanged estimator now finds genuinely Easy combinations instead of falling back to Normal. Original grid Normal/Hard recipes and Existing catalogue remain unchanged.

- `tests/grid_easy_regression.gd`: **22 checks passed**. Seeds 1–12 in both modes (24 configurations, each generated twice) all matched Easy at 28 points, preserved both broad upper designs and reproduced their geometry. Fourteen independent pre-change fingerprints protect Existing catalogue and sampled grid Normal/Hard geometry. Both new recipes passed compiler clearance, full paddle-swing checks, the unchanged whole-course validator and 618 px checked junction corridors.
- Actual 120 Hz physics checks cover upward passage past resting, raised and moving middle paddles, one-strike descending recovery into the upper chamber, missed-shot drain/respawn/relaunch, bidirectional 1200 px/s shots through both junctions, and ten bank-joint probes at approximately 8000 px/s without added energy or escape. Continuous movement remains off-grid. These reuse the existing grid regression helpers with the new Easy recipes.
- Regeneration retained tuning, overlays, camera, pause and bottom paddles. An intentionally invalid original recipe emitted its expected diagnostic and preserved the active table.
- A graphical fixture passed **16 checks**, including Easy-to-Normal-to-Easy switching in both modes. Returning to Easy reproduced the initial signature with a matched tier. Four images were saved; the Base lower-junction view and Variant overview were inspected. Collision outlines match the raised rails, flippers and ball; the full overview fits.

Total: **38 passing checks**. Logs and images are ignored `test-results/grid-easy-*`. Try **Easy seed 8** in both grid modes for an Open Meadow upper section, or **Easy seed 1** for Gentle Banks. Easy retains a 5 px grid/legacy inset difference, smaller than the 12 px rail radius; the generic generator still labels these tiny rounded closures `Step`. Large ceiling shoulders are gone, but endpoints are not mathematically identical. Representative physics samples pass; subjective recovery timing and exhaustive low-speed trajectories still need playtesting. The existing local `project.godot` edits and concurrent score-attack files are outside this change.

The final shared-game script check passed after restoring an accidentally changed indentation line from concurrent work. Godot MCP launched Easy / Grid base / seed 8 and returned `PLAYGROUND_READY`. Its only reported diagnostic was a variable-shadow warning in the concurrent, unstaged Score Attack panel; no grid runtime error was reported. The Easy playtest was left open without changing the project's default scene.

## Normal flow pass (generator v8)

Normal now constructs both joins before rating the course. It excludes raw stepped closures and generated facets with `abs(dx / dy) > 0.75`, tries the other style and other candidates, and explicitly reports a flowing alternative if its requested tier is unavailable. Authored interior corners remain. Easy/Hard selection and all chunk resources are unchanged; the separate visual experiment worktree was not modified.

- `tests/normal_flow_regression.gd`: **16 checks passed**. Twenty-two Normal configurations, including both grid recipes, reproduce valid in-tier geometry and estimates with no generated closure shoulders. Default seeds cover at least four top designs, all three middle designs and six pairings. Checks also cover source preservation, partial/shallow transition rejection and the explicitly easier aligned fallback.
- Native passive contact probes compare incoming and outgoing velocity in pixels per second. Normal 18's straight bank redirects `(0, -800)` to approximately `(391.7, -677.6)`; Normal 23's curve redirects it to `(-258.9, -749.4)`. Both retain upward movement, with no sampled speed above 800. Gravity and rolling acceleration are disabled only in these contact fixtures to isolate the existing wall response; gameplay physics are unchanged.
- Oblique misses remain possible: seed 18 redirects `(-700, -180)` to about `(485.0, 190.3)`, and seed 23 redirects `(700, -180)` to `(-518.0, 57.9)`. Neither adds speed. Low-speed contacts fall free under normal gravity. Separate uninterrupted Balanced trials recover from a downward bank rebound to above the join through timed ordinary flipper input, with one strike in each successful witness. Failed timings are retained in the diagnostic report; there are no post-launch position corrections or rescue forces.
- `tests/connector_transition_regression.gd`: **31 checks passed**, including eight preserved Easy/Hard static fingerprints, high-speed bank endpoint contacts, old shelf comparisons and full serve-to-top-to-return witnesses on Normal 18/23.
- `tests/flipper_recovery_regression.gd`: **12 checks passed**, preserving real drain/respawn/relaunch behavior, resting tip clearance, held-cradle release, 30 upward passage samples through resting/raised/moving paddles and timed recovery for all three middle designs.
- `tests/grid_chunk_regression.gd`: **23 checks passed** across 24 layouts generated twice. Eight complete Easy/Hard v6 fingerprints remain unchanged. Normal fingerprints intentionally change with v8. Grid compilation, mirrored/shifted geometry, invalid recipe rollback, seam shots up to 8000 px/s, recovery and drain checks pass. The rollback fixture deliberately logs one expected invalid-recipe error.
- A graphical capture fixture passed **24 checks** across default Normal 18/23, Grid base Normal 18 and Grid variant Normal 23. Twelve overview/junction screenshots were saved; four representative images were inspected. Final physics outlines follow both bank styles and match the raised rails; paddles and rings remain aligned, and full overviews fit.

Total: **106 passing checks**. Logs, capture fixtures and `normal-flow-report.json` are under ignored `test-results/`. Recommended playtests: default Normal **18** (Bank/Bank, 46), **23** (Curve/Aligned, 55), **1** (side recovery, 55), **5** (Curve/Curve, 55), and **8** in each grid mode (Curve/Curve, 38.6). Grid base Normal 18 built in approximately 0.335 seconds in one local sample; the former v7 result was 18.756 seconds with retained steps.

Final headless editor import completed successfully. A fresh Godot MCP run exposed a local-variable shadow warning; after renaming that fallback variable, the next launch returned `PLAYGROUND_READY` for v8 Normal seed 1 with an empty errors array. The game was left open for manual playtesting.

These are representative physical witnesses and geometric checks, not exhaustive trajectory guarantees. Unfavorable approaches can still fall back or drain. Difficulty, low-speed edge cases outside the samples, controller timing, Floaty/modifier extremes and long-session feel remain manual playtesting work. The historical results below describe their named generator versions, not current seed mappings.

## Optional construction grid (generator v7, kit v1)

The preceding drain/recovery correction is preserved in commit `a099f34`. This experiment adds two Resource-authored 50 px grid recipes that compile into the same collision and presentation descriptors as existing chunks. Default legacy generation is unchanged apart from its version number.

- `tests/grid_chunk_regression.gd`: **23 checks passed** across seeds 1/8/18/23, all three preferences and both recipes (24 layouts generated twice). Twelve independent v6 fingerprints protect complete legacy geometry, flipper placements and junctions. Checks cover deterministic compilation, exact anchor/mirror/shift mapping, reordered and split-collinear rail equivalence, valid intentional corners, duplicate/gapped rails, unsupported transforms and pieces, malformed spans, static and dynamic clearance, and source-resource preservation.
- Both grid modes on **Normal seed 8** passed real 120 Hz upward shots through resting, raised and moving middle paddles. A timed descending recovery produced exactly one existing flipper strike and reached approximately y446 in the upper chamber. A missed bottom shot physically drained, respawned and relaunched without a rescue correction. Fresh bodies establish each sample's initial conditions; ordinary physics/input own the shot afterward.
- Both grid junctions passed the diameter-28 ball upward and downward at 1200 px/s. Four base and five variant bank joints received 8000 px/s horizontal / −1000 px/s vertical impacts, remained contained and added no speed. Off-grid free-flight samples retained their original velocity. Runtime checks match one rail collider to each descriptor, synchronize paddle/ball visuals, and confirm no TileMap collision or 3D collision objects exist.
- Base → Variant → Existing → Base regeneration preserves Floaty, the modifier, live tuning, camera settings, overlays, pause and bottom paddles. Old middle nodes and pickup visuals are freed; no duplicate listener remains. An intentionally malformed in-memory recipe leaves the active table intact. That one expected `push_error` is labeled in the test log; it is not a startup failure.
- A supplemental audit reconstructed all 24 selected middle transforms and passed the compiler-standard full ball-passage margin throughout the paddle swing. The permanent helper now uses that stricter margin, including after generated connector shaping.
- Existing **38 physics**, **25 vertical traversal** and **19 graphical generation UI** checks passed. The grid-specific graphical fixture added **13 checks**, including actual Build/toggle callbacks, returning to the legacy catalogue, four image saves and panel bounds while local-cell telemetry is visible. Its panel ends at y828, within the y835 boundary.

Four captures were inspected: `test-results/grid-{base,variant}-{play,overlay}.png`. The same Normal seed 8 clearly shows the bank swap, the one-cell bumper move and matching collider footprints. Source-grid labels and full-swing footprint guides remain distinct from the green final-physics overlay. Existing physics, following camera and cosmetic ring flights are preserved.

The small optional catalogue currently lacks an Easy-rated combination and explicitly reports a Normal alternative, around 40 points. Normal seed 8 estimates 42 in both modes and is the recommended direct comparison. This does not change the ordinary Easy catalogue or its selection rules. The kit is limited to tested dual-opening middle chunks and Resource editing; it does not generate arbitrary random tiles. A measured Grid base Normal 18 build took **18.756 seconds**, retaining Step joins after its requested Bank transitions could not be selected. Some requests therefore pause the UI noticeably while the existing exhaustive validation runs. No selection rule or clearance check was weakened to hide this limitation.

Logs are ignored `test-results/grid-construction.log`, `grid-construction-report.json`, `grid-capture.log`, `grid-swing-audit.log`, `grid-compile-final.log`, `grid-timing.log`, `grid-physics-regression.log`, `grid-vertical-regression.log`, `grid-generation-ui.log` and `grid-final-import.log`. One early graphical capture process exited without a diagnostic; retries and the final 13-check graphical run succeeded. The final MCP launch returned `PLAYGROUND_READY` with an empty errors array after an integer-division warning was removed.

Manual playtesting still owns flow, low-speed pockets, paddle timing, gamepad feel and extreme profile/modifier combinations. These sampled shots and static checks are not exhaustive proof against every trap or trajectory. No new impulse, physics tuning, progression or collision-driven 3D object was introduced.

## Physical drain and varied recovery flippers (generator v6)

The reported bottom trap was reproduced with the original 150 px paddles: their radius-13 capsules left a **19.229 px** resting surface gap for a diameter-28 ball. A fresh zero-input drop remained at approximately `(399.98, 1992.49)` after 15 seconds, moving about 0.49 px/s, without draining. The new 130 px bottom paddles leave **57.20 px at rest** and at least **44 px through the swing**, at the original pivots. No ball-force, profile, steering, angular-speed or strike-window changes were needed.

- `tests/flipper_recovery_regression.gd`: **12 checks passed**. Ten zero-speed center/tip-near drops at x365/385/400/415/435 across Balanced and Floaty physically crossed the bottom drain in about 0.91–1.71 seconds, then automatically respawned and relaunched. An intentionally early missed press also drained without a strike. Fresh bodies establish independent initial conditions; no transform or velocity correction occurs during a shot except the normal respawn after an observed drain.
- The same suite checks **30 upward passage samples**: three lanes through each of the three middle arrangements with resting, held and moving paddles, plus Normal 8's specific lower-deck x400 route in all three states. Every sample passes. Each arrangement also has an actual timed descending recovery with one strike reaching the upper chamber (y below 450).
- **Remaining stable behavior:** holding either bottom paddle raised can cradle the ball against the inbound wall at its pivot. Eight-second holds confirmed this; releasing the paddle then permits a physical drain. None of the tested resting tip drops remains trapped. Normal 8's moving x400 sample passes but receives a strike from the existing 9 px assist margin; resting and held samples pass without strikes. These are ordinary existing flipper behaviors, not hidden rescue logic.
- `tests/vertical_shot_survey.gd`: **18 checks passed**. All **288 controlled samples** receive one actual strike and remain finite. Both bottom-to-middle and middle-to-top chamber witnesses exist in each of six sampled layouts. Full serve-to-top-to-bottom witnesses using both paddle pairs cover all three middle designs. Trials now record three input timings as needed, including real drains; they do not require an identical button timing to work on every arrangement. No controller or auto-flipper feature was added to the game. The new Rebound pair's final offset restored useful shots without increasing power: targeted 24-shot samples reached the next chamber 2 times for Normal 2, once for Hard 2 and twice for Normal 8. These counts are diagnostic samples, not player success probabilities.
- `tests/connector_transition_regression.gd`: **31 checks passed**, including unchanged passive-bank response, high-speed contacts, reproducibility, actual lower-collar reconstruction and complete Normal 18/23 traversal witnesses. Eight static-geometry fingerprints were captured before this change; Easy/Hard rails, bumpers, rings and junctions match them. Flipper placements intentionally differ and are covered by the physical recovery checks.
- Existing physics: **38 checks passed**. Vertical lifecycle/generation: **25 checks passed**. Graphical camera regression: **29 checks passed**. Final flipper rendering fixture: **28 checks passed**, with **11 screenshots reviewed**. Capsules, mesh lengths and tips match at rest, during the swing and raised; no 3D colliders exist. The final Normal 8 capture places a frozen render probe at x400 and shows the open route. Rendering probes are separate from the real trajectory tests.
- A separate full-swing clearance audit covered **72 generated layouts, 25 sampled middle variants and 81 angles**. Minimum paddle-to-static-obstacle surface gap was **55 px** overall (Open Relay), **95 px** for Bank Relay and **74.44 px** for Rebound Relay, all greater than the ball diameter. This supplements rather than replaces real collision tests.

Open Relay uses broad side recovery; Bank Relay uses a staggered pair; Rebound Relay uses a shorter offset traditional pair. Normal **1**, **23** and **8** respectively are useful comparisons. Normal 8 admits both x350 and x400; mirrored/shifted variants transform that route, so not every layout promises a straight shot at global x400. Static difficulty ratings do not yet estimate paddle coverage or recovery timing. Manual playtesting should judge launch feel, low-speed edge cases beyond these samples, held cradles, controller timing and Floaty/modifier recovery. Unlimited retries, automatic respawn and all existing sandbox controls remain unchanged.

Logs and reports are ignored `test-results/flipper-*` files, particularly `flipper-recovery-regression.log`, `flipper-recovery-report.json`, `flipper-shot-survey-final.log`, `flipper-connectors-final.log`, `flipper-layout-render.log`, `flipper-vertical-camera.log` and `flipper-sweep-clearance-final.log`. Screenshots use the `flipper-layout-` prefix. The original trap confirmation is `flipper-original-trap-confirmation.log`.

Final editor import and script checks completed without errors. Godot MCP launched generator v6, returned `PLAYGROUND_READY` with an empty errors array, and the game was left open for manual playtesting.

## Normal passive transitions (generator v5)

- `tests/connector_transition_regression.gd`: **31 checks passed**. Eight Easy/Hard geometry fingerprints captured independently from committed v4 match the new generator. Normal seeds 1–8 reproduce valid, in-tier geometry and retain steps alongside banks/curves. Original v3 Normal 18/23 reproduce the reported 150-pixel shelf before reshaping; source resources, markers, transforms and paddle positions remain unchanged.
- The same isolated shot from `(670, 820)` at `(0, -800)` px/s rebounds downward from the old shelf at approximately `(0, +576)`. A straight bank redirects it to approximately `(-392, -678)` and the faceted curve to `(-499, -586)`, both crossing upward through y700. Gravity/rolling assistance and steering are disabled for this comparison, with zero bumper contacts. Peak speed never exceeds the initial 800 px/s: the result comes from passive wall geometry, not an added boost.
- Both shaped styles pass bidirectional central seam checks and roughly 8000 px/s oblique containment probes near facets/endpoints. The seam test stops inside the connector band; a longer downward probe correctly encountered the unchanged lower bumper and was not evidence of a seam defect. Changed lower-deck collars rebuild their actual collision capsules on regeneration while preserving bottom paddles. No core ball or flipper behavior changed in v5.
- New Normal **18** (Bank/Bank, estimate 46) and **23** (Curve/Aligned, estimate 55) each completed **40 uninterrupted simulated seconds**, reaching the upper section, falling back below y1450, using both paddle pairs and avoiding a drain. These runs use the existing diagnostic's proximity-timed shared inputs after an ordinary serve, with no later teleport, velocity edit or rescue. Lowest Y positions were about 76 and 348 respectively. These are sample route witnesses, not guaranteed success rates.
- A separate Normal seeds **1–24** selection audit produced **six stepped, nine banked and nine curved preferences/results**, all valid and in the requested tier, with no style fallback. Seed **1** retains a deliberate Step/Aligned comparison; seed **5** has Curve/Curve.
- Rerun checks: **25 vertical traversal**, **64 legacy generation**, and **19 graphical generator UI**, all passing. UI checks include requested/actual transition labels and preserved camera selection. Final graphical bank capture added **10 passing checks** and six reviewed images: overviews plus both junctions for Normal 18/23. Raised rails follow the green collision footprints, including the changed lower collar; full overviews fit. Total for this refinement: **149 passing checks**, plus the 24-seed audit.

The first shaping attempt exposed a validator assumption: a rectangle inset from seam endpoints can cross a sloped wall away from the seam. The validator now intersects actual outline spans over the full ±45-pixel band before applying the existing inset and physical clearance checks. The estimator uses that same checked width. It does not loosen the safety margin or accept the initial rejected geometry.

Logs: ignored `test-results/connector-transition-final.log`, `normal-vertical-regression.log`, `normal-legacy-regression.log`, `normal-generation-ui.log`, and `normal-bank-render.log`. Captures: `normal-bank-{18,23}-{overview,junction-1,junction-2}.png`. Subjective flow, low-speed wall behavior, camera comfort and physical gamepad timing still need human playtesting, especially with Floaty and modifiers. Tests do not exhaust every seed/trajectory/profile combination.

Final headless editor import completed without errors. Godot MCP launched the graphical v5 game, returned `PLAYGROUND_READY`, and reported an empty errors array. The game was left open at the bottom serve for manual playtesting.

## Vertical Traversal Playground (generator v4)

- `tests/vertical_traversal_regression.gd`: **25 checks passed**. Four seeds per tier generated twice reproduce ordered chunks, flippers and both junctions. Checks cover three sections, matching difficulty, a three-section fallback, all four paddles responding simultaneously, aligned physics/presentation, both-direction 1200 px/s seam shots, 8000 px/s closure impacts, pause, bottom reset/drain/respawn and safe regeneration. Old generated bodies, middle paddles, pickup visuals and listeners are removed; the bottom deck/paddles, Floaty profile, modifier, live steering edits, overlays and camera settings persist correctly.
- An independent catalogue audit tested all **224** top/middle transform combinations: **220 valid**, with 16 Easy, 144 Normal and 60 Hard estimates. Four combinations correctly fail the unchanged 300 px raw-overlap requirement. This is static validation, not exhaustive trajectory testing.
- `tests/vertical_shot_survey.gd`: **18 checks passed** after the serve correction below. Six configurations (seeds 1/2 in each tier) each received 24 shots from the bottom pair and 24 from the middle pair: **288 actual single-strike samples**, all finite. Contact distances 55/75/95/135 px and incoming horizontal velocities −200/0/+200 px/s sample real paddle presses with unchanged Balanced defaults. Every configuration has a bottom-to-middle and middle-to-top chamber witness. Bottom chamber arrivals were 2–3/24 and middle-to-top arrivals 4–17/24; these are diagnostics, not player success probabilities.
- All six survey configurations also completed **40 uninterrupted simulated seconds** from the ordinary bottom serve, reaching y450 in the top section and returning below y1450. Both paddle pairs struck; no teleport, velocity edit or automatic rescue occurred after serve. The script uses proximity-timed shared left/right input, not a gameplay auto-flipper feature. All three middle designs appear. Recorded inputs and witnesses are in ignored `test-results/vertical-shot-survey.json`.
- Graphical `tests/vertical_camera_smoke.gd`: **29 checks passed**. Full-course framing works in all three presets. Controlled 1400 px/s ascent and 1480 px/s descent stay visible at 60/120 Hz with monotonic, speed-limited movement and under 3 px final-focus difference. Checks cover dead zone, gentle horizontal response, abrupt-rebound observations, fixed rotation, pause, bottom reset, regeneration, ring-flight cleanup and all four paddle/ring/ball mappings. Seven screenshots were reviewed: three overviews, bottom/middle/top follow views and an overlay. They show readable local geometry, matched footprints, shadows and unclipped course ends.
- Graphical generation UI: **18 checks passed**, including scrollable ordered chunk/junction diagnostics and preserved camera selection. Earlier two-section fixtures also pass: **64 generation**, **26 graphical presentation**, **38 physics**, **12 steering**, **eight profile**, **11 ring**, **14 headless ring-presentation**, and **four steering-UI** checks. Total executed: **267 passing checks**, including image saves. Headless import completed without script errors.

Testing found a real reset issue: after a long teleport, native contact recovery could nudge the waiting ball about 1.63 px from the serve point. The serve-only integrator state now holds the reset transform and zero velocity until launch; the same respawn check now observes exactly `(665, 1820)`. Active-flight steering, gravity, flipper power and rebound forces are unchanged. Controlled shot fixtures use a fresh body for independent samples to avoid carrying native CCD contact state between unrelated teleports. Adding a 75 px paddle contact sample found lower-to-middle witnesses through the open relays without changing their geometry or physics.

Logs are ignored `test-results/vertical-*.log` files. Final traversal/survey logs are `vertical-regression-final.log` and `vertical-shots-final.log`; camera captures are `vertical-overview-0/1/2.png`, `vertical-follow-bottom/middle/top.png` and `vertical-follow-overlay.png`. Godot MCP launched the graphical v4 course and returned `PLAYGROUND_READY` with an empty errors array.

Human playtesting remains necessary for flipper timing, mid-paddle undersides, recovery routes, camera feel after repeated extreme impacts and deliberately slow camera tuning. The shot survey uses Balanced only; Floaty persistence and existing profile/trajectory regression checks pass, but every generated course/profile/modifier combination is not dynamically proven. Static flood checks do not model moving paddles. No physical gamepad or Android device was tested. There are no middle checkpoints, powered banks, new abilities, progression or runtime streaming.

## Distinct geometry tiers (generator v3)

Four new upper sections expand the catalogue to eight shapes and 28 valid mirror/shift combinations. Easy uses full-width aligned openings with no closure ledges. Normal retains the original moderate shoulders and target routes. Hard adds tapered and sideways-bending necks, without increasing bumper counts or changing ball/flipper physics. The displayed estimate uses the hardest chunk, connector or approach component; selection requires the requested band when available and explicitly reports shortages.

- `tests/generation_regression.gd`: **64 checks passed, zero failures**. All 28 transformations passed static clearance/connectivity validation. Seeds 1–24 across all three tiers reproduced geometry and estimates when generated twice (144 builds), covered all eight upper sections and at least two shapes per tier, and always matched the requested band. Mean estimates were **25.9 / 52.5 / 93.3**, checked join widths **618 / 487 / 248 px**, and largest ledges **0 / 119 / 258 px** for Easy / Normal / Hard. Invalid geometry, explicit unavailable-tier fallback, resource immutability and safe regeneration remain covered.
- Real 2D checks crossed three seam lanes in both directions at 1200 px/s for every authored shape, checked closure rails at 8000 px/s, and verified transformed bumper positions. One layout per tier completed eight seconds of scripted play without a side/top escape or a stationary stall lasting two seconds. This is sampled coverage, not proof against all traps or trajectories.
- Graphical `tests/generation_ui_smoke.gd`: **18 checks passed, zero failures**. Build/Next/Repeat, flight/pause gating, camera preservation, matched-tier summaries and unavailable-tier notices work. Three seed-1 tier captures and a Hard collision/chunk/connector overlay were visually inspected: geometry differences are visible, ground footprints match the meshes, and the full table and diagnostics fit. Existing perspective cameras and raised primitives are retained.
- Existing `tests/physics_regression.gd`: **38 checks passed, zero failures**, including both flippers, high-speed collisions, scoring, pause, live tuning, respawn and 20 seconds of simulated play.
- `tests/flipper_access_survey.gd`: **four checks passed** across 162 controlled real-flipper shots on nine seeded layouts. The `--all-hard` mode added **12 passing checks** across 144 shots covering all eight Hard transformations. Every sample received exactly one actual flipper strike and remained finite. Every Hard transformation reached both y450 and its authored diagnostic target at least once.

Representative survey results below count arrivals out of 18 shots per layout. Physics is unchanged Balanced, with no steering, modifier or rescue flips. The target radius is 70 px; the script follows swept movement and records inputs/results in JSON. Seeds 1 and 2 select the same shape/transform in the Easy and Normal samples, which is valid seeded behavior.

| Preference + seed | Upper section | Cross y650 | Reach y450 | Target hits |
| --- | --- | ---: | ---: | ---: |
| Easy 1 / 2 | Gentle Banks | 11 | 9 | 4 |
| Easy 3 | Open Meadow | 11 | 10 | 6 |
| Normal 1 / 2 | Outer Return | 11 | 9 | Not authored |
| Normal 4 | Risk Route | 11 | 7 | Not authored |
| Hard 1 | Offset Neck, mirrored | 9 | 2 | 1 |
| Hard 2 | Offset Neck | 5 | 1 | 1 |
| Hard 3 | Tapered Throat | 8 | 3 | 3 |

Across all eight Hard transforms, y450 arrivals ranged from **1–4 of 18**, versus **7–10** in the representative Easy/Normal designs. This supports the narrow-neck challenge and provides successful sample routes. It is not a player success probability, exhaustive reachability proof, generator validity gate or scoring input. The fixed lower bumper influences these opening shots. Easy and Normal overlap on initial access; recovery room, subsequent shots and subjective challenge still need human playtesting. Floaty, modifier extremes, long sessions and physical gamepad timing were not assessed by this survey.

Total: **136 passing checks**, including image saves. Headless editor import completed without script errors. Godot MCP launched the graphical playground and returned `PLAYGROUND_READY` for generator v3 with an empty errors array. Logs are ignored `test-results/tier-*.log`; captures are `table-difficulty-0.png`, `table-difficulty-1.png`, `table-difficulty-2.png` and `table-connectors.png`. Diagnostic reports are `flipper-access-survey.json` and `flipper-access-all-hard.json`. Normal Windows cache access was required for clean Godot runs; earlier restricted-shell attempts emitted certificate/settings permission errors.

See [generation rules and sample configurations](GENERATION.md) for reproduction. Version 3 changes earlier seed mappings. Existing authored collision geometry, profiles, steering and flipper code are unchanged; Risk Route's authored estimate was recalibrated from 65 to 55 against the new restrictive designs. No camera following, taller tables, progression or external artwork is added. The separately developed ring animation is preserved.

## Cosmetic ring attraction follow-up

Ring claims still award score, ring total, and meter immediately. Presentation now runs a separate 0.20-second quadratic ease-in toward the moving visible ball, with a small final shrink. This supersedes the immediate-disappearance presentation described in the historical magnet section below. Magnet strength was already absent from profiles, modifiers, and the tuning schema; radius remains configurable.

- `tests/ring_regression.gd`: **11 checks passed, zero failures**, including the existing 24000 px/s pass with unchanged ball velocity and a new swept direct-contact boundary check with magnetism disabled.
- `tests/ring_presentation_smoke.gd`: **14 headless checks passed**, then **17 graphical checks passed**, including three image saves. Covers stationary unclaimed rings, three simultaneous swept claims with immediate rewards, accelerating flight, moving targets outside range, disabling magnetism after claim, pause, arrival without duplicate rewards, reset, drain/respawn, rack reuse within one frame, long frames, and regeneration during flight with no stale visual/listener or 3D collider.
- Existing **38 physics** and **eight profile** checks passed. The physics suite includes scoring, flippers, high-speed collisions, automatic drain recovery, and 20 seconds of simulated play. Headless editor import completed without script errors. Final logs contain no errors or warnings.
- Inspected graphical captures `test-results/pickup-claimed.png`, `pickup-chasing.png`, and `pickup-arrived.png`: multiple rings remain visible after claim, travel toward the relocated ball, and disappear on arrival. Godot MCP launched the normal graphical game with an empty errors array. A live launch through Computer Use confirmed ring totals and meter advancing during play. The user then stopped Computer Use with Escape; no further UI input was sent.

The graphical fixture pauses physics while awaiting screenshot rendering, so its manually positioned ball cannot be resynchronized by the physics server between assertions. An initial fixture check also used an oversized respawn timestep that advanced through both respawn and relaunch; it now steps at the game's 120 Hz. Neither correction changed gameplay. Logs are ignored local `test-results/pickup-*.log` files.

Run the new visual check with `Godot.exe --path . --script res://tests/ring_presentation_smoke.gd` (add `--headless` to skip captures). Human playtesting still decides whether the provisional 0.20-second pull and final shrink feel satisfying, especially during fast passes and dense pickups. No physical gamepad was tested.

## Raised primitives and stationary perspective cameras

- Graphical `tests/presentation_smoke.gd`: **26 checks passed, zero failures**. Covers the default/UI selection, absence of 3D collision objects, shadow configuration, outward triangle normals for both polygon windings, whole-board framing (including the slab and a 0.55-unit height envelope), and natural near/far perspective ratios of **1.00 / 1.41 / 1.74**. Camera changes preserve the seed signature, serve position, velocity and effective physics. Both flipper tips stay aligned during simultaneous press and release; a moving ball follows the existing mapping while the camera remains stationary.
- The same suite exercises camera changes and X-ray geometry while paused, reserves clear viewport space beside both panels, and checks that seed 10 + Easy and seed 6 + Normal rebuilds retain the selected camera. Eight images are captured, including seed 1 + Normal at all three presets, a paused collision/connector overlay, both additional seeds in Real Pinball, and a fixed ball two pixels outside an upper bumper's far contact edge in both perspective views.
- All eight captures were visually inspected. The table, flippers, closure rails, raised tops/sides, ball and cast shadows render in the reviewed views. The first render exposed floor shadow acne and inward-facing triangle side triangles; both were corrected. Flat grid markings avoid tiny cylindrical-line artifacts. The initial 42° Dramatic elevation hid too much of the far-side ball; it was raised to **50°**. Partial occlusion behind raised bumpers remains natural, and distant ball tracking is easier in **Real Pinball (60°)**.
- Existing checks executed: **38 physics**, **12 headless generation UI**, and **four headless steering UI** checks, all passing. Physics checks include high-speed walls/bumpers, chunk crossings, both flippers, pause, respawn, and a 20-second scripted play sequence. Total for this task: **80 passing checks**, including image saves. Headless editor import completed without script errors. Godot MCP launched the graphical playground and reported `PLAYGROUND_READY` with an empty errors array.

The moving-ball check originally sampled at `process_frame`, before node visual updates; it now samples after the idle update using a SceneTree timer. The static occlusion probe pauses physics explicitly and verifies its position, rather than relying on a long physics teleport to settle at the exact requested point. These are test-fixture corrections, not physics changes.

Captures are ignored local files: `test-results/depth-top-down.png`, `depth-real-pinball.png`, `depth-dramatic-pinball.png`, `depth-collision-overlay.png`, `depth-seed-10-real.png`, `depth-seed-6-real.png`, and `depth-bumper-clearance-1.png` / `depth-bumper-clearance-2.png`. Logs: `presentation-smoke.log`, `depth-import.log`, `depth-physics.log`, `depth-generation-ui.log`, and `depth-steering-ui.log` in the same directory. Reproduce captures with:

```powershell
& 'C:\Program Files\Godot\Godot.exe' --path 'E:\Sonic Spinball Runners' --script res://tests/presentation_smoke.gd
```

No physics, input routing, profile/modifier, ring collection, generator-selection or authored collider source changed. This task does not add camera following, taller tables, new connections, progression or external assets. Visual inspection uses actual Godot framebuffer images and scripted input; MCP cannot operate controls directly. No physical controller or human timing/feel test was performed. The captures are not proof against every possible occlusion. Before following, playtest distant ball visibility and height parallax, then establish viewport bounds, stable look-ahead, rebound smoothing and shadow coverage for a moving view. Performance was not profiled across other GPUs or Android.

## Difficulty preference follow-up (generator v2)

- `tests/generation_regression.gd`: **47 checks passed, zero failures**. Seeds 1–24 at Easy, Normal, and Hard reproduced both their geometry and difficulty metadata: 72 configurations, each generated twice. All 16 authored transformations remain valid, and the selected configurations still cover all four upper chunks.
- Every selected score stayed within eight points of the closest valid distance to the preference target. Mean scores across the same 24 seeds increased from **33.8 to 50.7 to 52.1**. The current catalogue spans **29.4–55.3**, so the Hard request truthfully reports a Normal estimate.
- Focused checks verify reflection invariance, greater estimated challenge from larger offsets/ledges without rejecting them, authored ratings changing score without changing colliders, nearby approach obstacles affecting the estimate, and invalid/trapped candidates never winning on difficulty. Existing fallback, safe regeneration, 1200 px/s bidirectional seam shots, 8000 px/s closure impacts, transformed-body alignment, and four eight-second simulations still pass.
- Graphical `tests/generation_ui_smoke.gd`: **16 checks passed, zero failures**. Build and Next apply the selected preference; Repeat restores both current seed and preference despite unbuilt edits. Flight/pause gating still works. The actual estimate, reasons, and mismatch notice fit beside the table. The Hard-preference capture was visually inspected at 1280 × 900.
- Existing suites rerun: **38 physics, 12 steering, eight profile, 10 ring, and four headless steering UI checks**, all passing. Total: **135 checks passed**. Headless editor import completed without script errors; Godot MCP launched the updated playground and reported a clean errors array.

Logs are in ignored `test-results/difficulty-*.log`; screenshots are `test-results/table-difficulty-0.png`, `table-difficulty-1.png`, and `table-difficulty-2.png`. The original random-penalty selection experiment excluded Central Targets in the sampled seeds; selection was changed to a deterministic near-target band, restoring all four layouts without loosening tests or collider validation.

No authored collider, ball physics, flipper, ring, or progression behavior changed. The ratings are static heuristics; upward-shot accessibility, effects of gravity/profile/modifier settings, and subjective challenge remain for manual playtesting. See [the scoring contract](GENERATION.md) for the provisional weights and limitations. Version 2 changes the earlier version 1 seed mappings.

## Immediate ring magnet follow-up

The playground remains an endless sandbox. The magnet now collects stationary rings immediately within a provisional 50-pixel radius measured from the ball's swept center path. Radius remains live-tunable and modifier-compatible. Direct contact retains its 26-pixel threshold with magnetism disabled. The unused attraction-speed field was removed; collected rings hide immediately with no pull animation.

- `tests/ring_regression.gd`: **10 checks passed, zero failures**. Checks cover both profile defaults, immediate stationary pickup, score/meter/event deduplication, exact radius boundary versus an outside ring, direct contact at radius zero, swept proximity in both directions with endpoints outside range, live/modifier radius resolution without base mutation, serve suppression, one rack bonus followed by automatic rack reset, and a real 24000 px/s pass preserving horizontal and vertical velocity.
- Existing checks rerun: **38 physics, 12 steering, eight profile, 39 generation, four headless steering UI, and 17 graphical generation UI checks**, all passing. Together with the new suite, **128 checks passed**.
- Headless editor import completed without errors. Godot MCP launched the updated graphical playground; its debug output was checked for script errors. Logs are in ignored `test-results/magnet-*.log` files.

Collection never applies forces or changes velocity. The sweep is the straight previous-to-current position segment for each physics tick, as in the original contact pickup. It is proximity-based, without wall occlusion. No new progression or artwork was added. Manual tuning remains necessary to judge the 50-pixel radius and immediate disappearance during ordinary play; no physical gamepad was tested for this change.

## Phase 2A verification

The modular generator was checked against the Phase 2A source. Its initial handoff remained local; the subsequent ring-magnet follow-up authorized committing and pushing the completed work.

- Final headless editor import and 240-frame debug startup completed without errors. Godot MCP recognized the project, launched the graphical build, and reported `PLAYGROUND_READY` with an empty errors array after the warning fix. The graphical session remains open for playtesting.

- `tests/generation_regression.gd`: **39 checks passed, zero failures**. All 16 catalogue/mirror/shift combinations passed static validation. Seeds 1–24 reproduced identical selections, closure rails, and gameplay descriptors and covered all four layouts without fallback. Negative fixtures rejected bad shifts, vertical misalignment, inadequate overlap, missing rail endpoints, a blocked join, and an enclosed route. An invalid catalogue correctly fell back to the original table without mutating resources.
- Real physics covered both directions through three join lanes in each of seeds **1, 2, 10, and 12**, at 1200 px/s (below the existing downward speed limiter). Closure rails blocked 8000 px/s upward shots. Transformed bumper descriptors matched actual body positions and mirrored triangle shapes. Each sample then completed eight seconds of scripted play without a side/top escape or stationary stall lasting two seconds.
- Regeneration checks covered refusal during flight, cancellation if pause ends before the deferred swap, immediate reset while paused, cleared counters/timers, preserved lower/flipper instances, retained tuning/modifier/overlays, repeatable layout, and synchronized ring visuals.
- `tests/physics_regression.gd`: **38 checks passed, zero failures**. The original geometry and Original steering calibration are now explicit test fixtures; all existing shot/physics checks remain. The Chao expectation reflects the requested Quick / Tight base acceleration.
- `tests/steering_regression.gd`: **12 checks passed, zero failures**. No steering integration, release, collision, or flipper code was changed in this phase.
- `tests/profile_regression.gd`: **eight checks passed, zero failures**. Both actual character resources also match Quick / Tight in the generation checks.
- Graphical `tests/generation_ui_smoke.gd`: **17 checks passed, zero failures**. Entered seed, Next, Repeat, flight/pause gating, reset, summary labels, panel bounds, and capture output were exercised. Rendered images for seeds 1/2/10/12 and the physics/chunk/connector overlays were visually inspected. Controls fit beside the table; closure rails and the transformed overlays are visible and aligned in the reviewed views.
- Headless `tests/steering_ui_smoke.gd`: **four checks passed, zero failures**. Profile reset now truthfully selects Quick / Tight. Existing preset editing and diagnostics still fit.

Logs: `test-results/phase2a-generation.log`, `phase2a-physics.log`, and `phase2a-ui.log`. Rendered views: `test-results/table-seed-1.png`, `table-seed-2.png`, `table-seed-10.png`, `table-seed-12.png`, and `table-connectors.png`. These generated files are ignored by Git.

During development, tests caught a typed-empty-array error in legacy fallback startup; this was fixed and the full legacy suite passed. The initial no-impulse seam test exceeded the existing terminal downward speed, so its fixture was corrected to 1200 px/s without changing physics. MCP also exposed a local-variable shadow warning in the generator, which was corrected.

Manual work remains: physical controller behavior, subjective shot quality, outer-return accessibility, low-speed join-shoulder behavior, long sessions, and extreme modifiers. MCP launches and reads output but does not operate game controls. Programmatic UI signals and rendered captures do not establish human timing or gameplay feel. Static connectivity and 32 seconds of generated-layout simulation do not prove every trajectory is safe. See [generation limits](GENERATION.md).

The sections below preserve the earlier Phase 1 and steering verification history.

## Executed checks

- Headless editor import completed with exit code 0 and no script errors.
- Headless main-scene startup completed for 240 frames and printed `PLAYGROUND_READY` with no script errors.
- Godot MCP `get_project_info` recognized the project. MCP `run_project` launched the graphical game, and the latest `get_debug_output` returned an empty errors array.
- `tests/physics_regression.gd`: **38 checks passed, zero failures**, exit code 0. Detailed output is in `test-results/physics-regression.log`.
- The existing `tests/profile_regression.gd` was rerun: **eight checks, zero failures**. Output is in `test-results/profile-regression.log`.

Covered behavior:

- Additive/multiplicative resolution, clamping, and preservation of shared character defaults.
- Steering calibration at 60/120 integration steps per second. At strength 0.065 and configured acceleration 1000, one second adds 65 px/s.
- Actual physics steering added to 1400 px/s lateral momentum, preserved vertical momentum, capped only assistance, removed assistance on release, and retained momentum under opposite steering.
- Comparable one-second launch: Balanced reached approximately `y = -147.1`, `vy = 200`; Floaty reached `y = -295.3`, `vy = -94`. Floaty's downward limit preserved lateral velocity.
- Both flipper actions raised both flippers within 100 ms; release restored their rest angles. Both sides launched approaching balls.
- Rail rebounds at 1800, 4000, and 8000 px/s. Closed side boundaries at `y = 685`, `700`, and `715`. Open middle passage in both directions.
- Circular and triangular bumper events, including 8000 px/s circle and 6000 px/s triangle sweeps.
- Ring scoring, special-meter charging, live changes across both chunks, example modifier values, pause, and automatic drain/respawn/relaunch.
- 2D/3D mapping round trip and absence of collision objects in the 3D tree.
- Twenty seconds of scripted play using the Balanced profile, timed flipper presses, and variable steering: no side/top escape or stationary trap longer than two seconds.

## Problems found and repaired

The original serve marker overlapped a lower rail. The marker was moved to an open area and a test now verifies it remains in place while waiting to serve.

Native shape CCD missed fast rail impacts in this engine build. A supplemental 2D shape sweep now applies a conservative normal impulse before a missed crossing. The failing high-speed and seam cases pass. This safeguard can rebound up to one physics tick early; it is documented in the README.

A gamepad enum warning was fixed. The latest graphical run's MCP errors array is empty.

## Visual and interactive limits

The first graphical build was inspected through Computer Use. The vertical table, tilted 3D presentation, primitive objects, flippers, score, and tuning panel rendered visibly. A keyboard launch action was sent. These observations do not establish subjective gameplay quality or final-build alignment.

The user stopped Computer Use with Escape during the later visual pass. UI control stopped at that point. The updated build was launched through MCP and its output checked, but final-build overlays, live field editing, and visual alignment still need manual inspection.

No physical gamepad was exercised. Automated simultaneous action tests validate input routing and flipper response, not controller hardware, OS mappings, stick feel, or latency. A 20-second scripted run and selected stress shots cannot prove the absence of every trap, moving-flipper tunneling case, or extreme modifier interaction.

## Short manual checklist

1. Launch with Enter/X. Tap Q/E or LB/RB separately and together; try holding both and releasing near the ball.
2. Compare Balanced and Floaty using reset/relaunch. Check that steering helps without replacing pinball timing.
3. Toggle Chao, edit a field, press Enter, and inspect effective values. Check pause/resume on Escape/Menu.
4. Toggle Physics and Chunks. Check footprints, moving flippers, the center seam, and side-rail continuity.
5. Play for several minutes, including modifier extremes. Note any trapped ball, unexpected escape, unreadable trajectory, or difficult drain recovery.

## Steering investigation follow-up

The subsequent focused steering change added an independent counter-steering rate, optional session presets, and steering telemetry. That pass retained original startup values; Phase 2A subsequently promotes Quick / Tight after user playtesting. See `STEERING_INVESTIGATION.md` for the findings and settings.

Executed against the updated source:

- Headless editor import: completed without script errors.
- `tests/steering_regression.gd`: 12 checks passed, zero failures, exit code 0. Includes actual ascent/descent, both counter-steering directions, release/reversal, real native and swept rebounds, preserved momentum, mapped input, and blocking telemetry. Output: `test-results/steering-regression.log`.
- Existing physics regression: 38 checks passed, zero failures, exit code 0, including high-speed collision and chunk checks.
- Existing profile regression: eight checks passed, zero failures, exit code 0.
- Graphical `tests/steering_ui_smoke.gd`: five checks passed, zero failures, exit code 0. Preset application, custom-edit labeling, profile reset, layout bounds, and screenshot capture were checked. The generated `test-results/steering-lab.png` was visually inspected; the added readout and preset selector fit and are readable.
- Godot MCP launched the updated game. `get_debug_output` reported `PLAYGROUND_READY` and an empty errors array.

The new input checks use synthetic keyboard/gamepad events. No physical controller or subjective playtesting was performed for this follow-up. The rendered UI smoke scene programmatically supplied steering for inspection; it does not validate human interaction timing. No collision geometry, flipper response, or world rendering changes were part of the steering work.

## Green Hill playable integration — 2026-10-23

The experiment branch merged main through `1e24223`. Godot 4.7.2 checks: Green Hill playable integration 25/25, original visual adapter 19/19 with Sonic and 14/14 with the fallback, shared physics 38/38, grid construction 23/23, Normal flow 17/17. No physics tuning or collision implementation changed in this integration. The Normal-flow test now creates `test-results/` and handles report-open failure in fresh worktrees.

Normal seeds 18 and 23, Grid base at 18 and Grid variant at 23 each completed a continuous normal-serve, ordinary-flipper-input run through all three sections and back, including bumper hits, ring attraction, drain and automatic relaunch. Real quick-build buttons, replacement scenery, surviving bottom-paddle listeners, new middle-paddle listeners, camera/tuning/pause preservation, collisionless models and aligned rendered contact/ring anchors were checked. A separate controlled miss verifies drain recovery. Earlier fixed timing failed some routes; varied input timing established witnesses without changing physics.

Headless import, PowerShell syntax and launcher execution passed. Actual graphical play/overview captures were produced for all four layouts and remain ignored. Footer clipping found in visual review was repaired. The short capture mode stops after a live frame; it does not claim a complete graphical traversal run. The grid regression intentionally reports an invalid recipe as part of its preservation check.

See [Green Hill instructions](../experiments/visual_lab/README.md) for commands and local capture filenames. Manual flipper feel, gamepad hardware and camera comfort remain user playtesting tasks.

## Green Hill table-relative character follow-up — 2026-10-23

The visual-lab presenter now defaults to spin and briefly uncurls along the table's gravity axis. Godot 4.7.2 orientation checks passed 13/13 with the local model, 13/13 without it, and 13/13 graphically. Coverage includes up-table head direction, visible front, smoothed bounded lean in both directions, descending motion without inversion, reaction repeat suppression, pause/study restoration and unchanged physics, rings and scoring during presenter updates.

Three labelled controlled-contact probes captured near-vertical and diagonal real flipper launches and a descending bumper approach/rebound. Only the initial placement/velocity is prescribed; subsequent physics is unmodified. Near-vertical and bumper probes complete the return to spin. The diagonal probe records an intervening genuine bumper instead of suppressing it. Five stills and a 113-frame local MP4 were visually reviewed or assembled under ignored `experiments/visual_lab/captures/orientation/`.

The complete playable integration rerun passed 25/25 across Normal 18/23 and both grid variants, including three-section traversal, rings, descent, drain and relaunch. Existing adapter checks passed 19/19 with the model and 14/14 with the fallback. The independent bumper fixture now resets after its preceding flipper scenario to respect the intentional visual cooldown. Final headless editor import passed without script errors.

The rig audit found consistent rest matrices and normalized weights. Removing temporary sideways finger curls improved open gloves; the local GLB and Blender study renders were regenerated successfully. Body poses remain provisional, including some hand/body overlap. No core physics, ring magnet, shared gameplay source or public asset payload changed. Manual reaction feel and gamepad hardware remain untested. See the visual-lab README for repeatable commands and local media paths.

## Combined main integration — 2026-10-23

Merged Green Hill with all PhysicsBro commits through `5dc758f`, including generator v9 Easy grid recipes and optional Score Attack. Green Hill now uses the shared mode/target/victory controls and collisionless upper goal; the rules and authoritative 2D physics remain shared with the original playground.

Checks executed on the combined source with Godot 4.7.2: headless editor import passed; shared physics 38/38; Easy grids 22/22; full Green Hill playable integration 25/25; original Score Attack 26/26; graphical Green Hill Score Attack 27/27. The Easy grid suite intentionally reports an invalid recipe while verifying preservation of the active table. The Score Attack check now accepts `--green-hill` and verifies mode controls remain available across debug/study changes. Its next-seed assertion was made relative to the starting seed after the initial Green Hill run exposed the playground-specific seed-1 assumption.

The graphical lifecycle fixture exercised score unlock, physical goal contact, latched victory, same-seed replay, next table, Free Play return and 27 difficulty/grid/seed regenerations. Free Play, locked-goal and victory captures were saved locally; the HUD and victory view were inspected. Goal-contact placement in this lifecycle fixture is controlled, not a claim of unaided human completion. The separate playable check completed ordinary-input traversal, descent and drain recovery on Normal 18/23 and both original grid variants.

Third-party assets and rendered media remain ignored. Existing uncommitted primary-checkout `project.godot` settings are preserved outside this merge. Human controller feel and difficulty remain playtesting tasks.
