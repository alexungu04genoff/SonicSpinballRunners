# Theme-aware decoration slots

The Act Editor stores manually placed, theme-independent decor slots. The active presentation skin selects collisionless props. This first version provides Green Hill; future skins can reuse the same authored geometry and slot records.

## Try the examples

Open **Act Geometry Editor.cmd → Load** to edit a file below. Open **Play Green Hill.cmd → Load Act…** to play it. Press **O** for an overview of the composition; normal follow mode remains available.

| File | Composition | Slots |
| --- | --- | --- |
| [`decor_terraces.tres`](../data/acts/decor_terraces.tres) | Broad side terraces, edge palms, checker details and a loop island | 16 |
| [`decor_garden_steps.tres`](../data/acts/decor_garden_steps.tres) | Stepped small islands, a rounded rock island and an upper landmark | 17 |
| [`decor_loop_court.tres`](../data/acts/decor_loop_court.tres) | Central raised loop court and two decorated side shelves | 17 |

All examples include small, medium, large and landmark slots, Spawn, connectors, rings, bumpers and flippers. They are workflow/look demonstrations, not final balanced Acts. Every slot anchor is on raised terrain. Their geometry and slot compositions are explicit authored records; nothing scatters across the map on load.

![Terraced Islands in the main Green Hill application](decor-captures/terraces.png)
![Garden Steps in the main Green Hill application](decor-captures/garden-steps.png)
![Loop Court in the main Green Hill application](decor-captures/loop-court.png)

## Editor workflow

1. Choose **Decor**, then **Small / Medium / Large / Landmark slot**. Click inside the Act to place repeated slots. Colored markers grow with slot size; S/M/L/◆ labels and an orientation tick remain visible without loading a 3D skin.
2. Press **Esc** or **Select / Move**, then click and drag a marker. Decor uses free placement by default. **Snap decor to grid** is optional; **Alt** temporarily frees an enabled snap. **Alt-click** cycles overlapping items, including terrain.
3. Edit **type**, **Placement: surface / edge / either**, exact **X/Y** local pixels, **Angle °**, or **Scale**. Any finite angle is accepted; **R / Shift+R** adds/subtracts 15°. Scale is limited to 0.85–1.15. Position and angle are never normalized on save.
4. **Ctrl+D / Duplicate** copies the transform half a cell diagonally and gives the new slot its own ID. **Delete** removes it. Placement, movement, property changes, duplication and deletion share the existing undo/redo history. Arrow keys move one pixel in free mode, or one cell with snap; Alt+arrows always move one pixel.
5. **Show decor slots** hides markers and their selection targets without deleting records. Snap and visibility are session view preferences, not Act data.

The Decor inspector scrolls when the window is short. Exact angle editing uses the existing field below the canvas. Variant mode is currently **auto**; named/indexed overrides, copy/paste and themed 3D editor ghosts are deferred.

![Decor authoring palette and selected slot](decor-captures/editor.png)

### Placement rules

Place the anchor on a filled terrain stamp/composite or a narrow raised wall ribbon. The inspector reports when a selected slot has no supporting raised terrain. Such slots remain valid, saveable drafts but do not spawn in Green Hill. The runtime records their IDs in `skipped_decor_slots`. It never relocates a slot onto nearby geometry or puts a floating prop over the playable floor.

`placement_hint` chooses a theme pool; it does not detect a cliff, change height or move the anchor. `edge` is an artistic hint: choose it when placing at an island edge. The anchor determines support, not the full prop footprint. Leaves or the loop silhouette may extend beyond that anchor, so inspect the result in the normal gameplay camera.

## Data and deterministic resolution

Act format **7**, terrain library **2**, adds:

- `decor_seed`: a persistent Act decoration identity, generated on its first decor edit. It survives saves, Save As, renaming and copies. An unseeded hand-authored file falls back to its Resource path.
- `decor_slots`: an ordered array of dictionaries containing `slot_id`, `slot_type`, `placement_hint`, `position: Vector2`, `rotation_degrees`, optional `variant_mode = "auto"`, and optional `scale = 1.0`.

Act records contain no mesh paths, Green Hill prop names or skin IDs. Slot IDs are generated only during authoring and stay fixed through movement, rotation and undo. A duplicate gets a fresh ID. IDs must be nonempty and unique within the Act.

`DecorSkin.resolve()` hashes the JSON array `[act_identity, slot_id, skin_id]` with SHA-256, converts its first eight hexadecimal digits to an integer, then takes modulo the selected pool length. It does not consume gameplay RNG. Reloading, reordering slots, deleting other slots, or editing unrelated geometry cannot reshuffle an existing slot. Changing the slot type/hint or active skin selects a different pool. Changing a skin's pool membership/order can change its choices; preserve published pool order when visual continuity matters.

The document fingerprint, deep-copy history, validation, and atomic save/reload comparison include the new fields. Angles and scale use the existing exact numeric byte storage convention. Formats 2–6 load in memory with no decor and no file rewrite. Format 7 introduced decor; current saves use format 8, which also supports fractional and half-size terrain. Existing format-7 decor remains unchanged on load. Formats below 7 cannot carry decor data. Format-6 composites retain their existing exact outlines.

## Skin and runtime ownership

- `scripts/act_editor/decor_slots.gd`: generic schema, IDs, markers' dimensions/colors, and raised-surface support queries.
- `scripts/decor/decor_skin.gd`: skin ID, per-type/per-hint variant pools, deterministic resolution, and a visual factory callable.
- `scripts/decor/green_hill_decor.gd`: first skin's lightweight procedural meshes, built in cell units. It reuses the existing Green Hill palm and sunflower builders/material palette.
- `act_runtime_compiler.gd`: copies generic decor metadata into the runtime descriptor. Its physics compilation does not inspect or instantiate decor.
- `green_hill_presentation.gd`: resolves and spawns supported slots below `GreenHillTerrain/AuthoredDecor`, at the same `RAIL_HEIGHT + RAIL_CAP_HEIGHT` used by raised terrain. Cell size and safe per-slot scale control prop size. Canvas clockwise degrees map to negative world Y rotation.

Every spawned child is a visual `Node3D`/`MeshInstance3D`. There are no collision objects, physics shapes, hit targets, ring records, scores or ball callbacks. The normal presentation rebuild disposes all old props before a source/replay reload. Existing distant scenery and exterior edge-island dressing remain unchanged.

To add a skin, provide its stable ID, pools for all four sizes and three hints, and a factory returning a collisionless `Node3D` in cell units. Assign it to the presentation's `decor_skin` before rebuilding the playfield. No Act schema or physics change is required. There is no production Chemical Plant skin or theme-picker UI yet; runtime regression uses a minimal test-only industrial factory to verify this boundary with the same saved Act.

### Green Hill library

| Size | Available props |
| --- | --- |
| Small | Single sunflower, small faceted rock |
| Medium | Medium rock cluster, low shrub, sunflower patch |
| Large | Left/right leaning palm family (`edge`), tall rock formation or checker pedestal (`surface`); `either` combines these families |
| Landmark | Faceted checker loop with grass rim and plinth; visual ornament only |

The composition borrows the broad checker silhouettes, palms and sunflower accents visible in [Sonic Generations' Green Hill screenshots](https://www.digitallydownloaded.net/2011/10/sonic-generations-demo-now-available.html) and [Sonic Mania's Green Hill screenshots](https://www.trueachievements.com/n25476/taegx-2016-sonic-mania-showcases-green-hill-and-studiopolis). These were visual references only. No external models, textures or screenshot assets were downloaded into the project. New props are local primitive geometry matching the project's existing low-poly presentation. Sizes and density remain provisional art tuning.

## Verification and manual review

Run from the repository with Godot 4:

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --script tests/decor_regression.gd
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --script tests/decor_editor_smoke.gd
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --script tests/decor_runtime_smoke.gd
```

Omit `--headless` and add `--rendering-method gl_compatibility --rendering-driver opengl3_angle` for graphical captures. Tests save captures under ignored `test-results/`; this document includes selected captures from the actual editor/game.

Manual checklist: place/move a slot at an island edge, rotate it to a non-round angle, duplicate it, save/reload, then compare follow/overview in Green Hill. Check ball readability, overhanging palm leaves, loop placement and the amount of decoration. These are human art/feel judgments; deterministic tests do not establish final gameplay balance.
