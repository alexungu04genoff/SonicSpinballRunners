# Act Geometry Editor

This standalone scene edits **one Act**, initially **12 columns × 12 rows**. Its terrain library and authoring Resources are independent of the existing generator, playable layouts and physics.

## Launch

Double-click **Act Geometry Editor.cmd**, or open `scenes/act_geometry_editor.tscn` in Godot and press **F6**. F5 still launches the playground.

```powershell
& 'C:\Program Files\Godot\Godot.exe' --path 'E:\Sonic Spinball Runners' res://scenes/act_geometry_editor.tscn
```

The Windows launcher uses the project's working ANGLE backend. For another Godot installation, run `scripts/act_editor/launch.ps1 -GodotPath 'D:\Tools\Godot.exe'`.

## Build an Act

1. Choose a stamp from the palette, or drag one onto the canvas. Search by name/size or filter by family.
2. The cursor ghost shows the geometry and dashed transform frame. Click to place; keep clicking to repeat.
3. Press **Esc**, right-click, or choose **Select / Move**. Click terrain, then drag to another snapped anchor.
4. Rotate, flip or delete the selection. With a palette stamp active, transforms change the next stamp instead.
5. Save, close, return later and Load the saved file to continue editing.

| Action | Shortcut |
| --- | --- |
| Select / cancel current gesture | Esc or right-click |
| Rotate clockwise 90° | R |
| Flip along screen horizontal / vertical axis | H / V |
| Delete selected terrain | Delete or Backspace |
| Move selected terrain one cell | Arrow keys |
| Cycle terrain under the cursor | Alt-click |
| Undo / redo | Ctrl+Z / Ctrl+Y or Ctrl+Shift+Z |
| Zoom / pan / restore overview | Mouse wheel / middle-drag / Fit Grid |
| New / Load / Save / Save As | Ctrl+N / Ctrl+O / Ctrl+S / Ctrl+Shift+S |

Text fields retain normal text-editing shortcuts. Undo/redo covers placement, movement, transforms, deletion, names and cell size, retaining up to 100 edits per session.

The default grid has 144 **cells**, with 13 boundary intersections along each axis. A 1×3 stamp becomes 3×1 after one quarter-turn. The integer anchor is the transformed frame's top-left corner. Movement rounds to the nearest anchor and clamps the entire frame inside the Act. Rotation near a border may move the anchor inward to keep the frame inside.

**Overlaps are allowed.** Frames reserve no cells. Selection tests actual polygons or proximity to open wall segments, starting with the last-placed piece. Alt-click cycles overlapping hits, including covered pieces. Dashed frames are guides, not terrain.

Cell size specifies saved local authoring pixels per cell. It does not change grid anchors or footprints. The fitted view scales the Act to the window; zoom controls on-screen size. Grid dimensions are stored in the Resource; this MVP creates 12×12 Acts without a grid-resize tool.

## File workflow

**Save** creates or updates a `.tres` file; **Save As** chooses another destination. The dialog starts in persistent `user://acts`, outside the checkout, and allows other locations. The header shows the open file path and unsaved marker.

After restarting, choose **Load** and select your file. Geometry, order, title, grid/cell sizes and transforms return exactly. History, palette selection and view position are session-only.

New, Load, Example, Close and the operating-system close button offer **Save / Discard / Cancel** when edits exist. Canceling Save As or a failed save keeps edits open. Saving validates a temporary sibling Resource by reloading and comparing its content, then replaces the destination with recovery handling for the old file. Forced termination before saving can still lose unsaved edits.

**Example** opens `data/acts/curve_garden.tres` as a new editable copy. Its 22 placements were created through the editor's stamp/transform/save workflow. They include open rails, filled curves, rotations, mirrors and deliberate circle/slope overlaps. Save chooses a separate destination for the copy.

## Shapes and format

All **52 stamps in 13 families** are included:

| Family | Canonical footprints | Geometry |
| --- | --- | --- |
| Straight walls | 1×1, 1×2, 1×3 | Open straight segment |
| L corners | 1×1, 1×2, 1×3, 2×2, 2×3, 3×3 | Two open perpendicular segments |
| Triangles | 1×1, 1×2, 1×3 | Closed right triangle |
| Curved slopes | 1×1, 1×2, 1×3, 2×2, 2×3, 3×3 | Concave quarter-ellipse with closing edges |
| J curves | Same six slope sizes | Curved edge only |
| Squares / rectangles | 1×1, 2×2, 3×3, 1×2, 1×3 | Closed solid |
| Circles | 1×1, 2×2, 3×3 | Closed solid |
| Ovals | 1×2, 1×3, 2×2, 2×3 | Closed ellipse |
| Bumps | 1×2, 1×3, 2×3 | Half-ellipse with flat base |
| Diagonal rails | 1×1, 1×2, 1×3 | Diagonal edge only |
| Capsules | 1×2, 1×3, 2×2, 2×3 | Rounded ends and straight sides |
| Outer corners | 1×1, 2×2, 3×3 | Convex quarter-disk with closing edges |
| U-curves | 2×2, 2×3, 3×3 | Half-ellipse wall, no closing segment |

`scripts/act_editor/terrain_shapes.gd` defines deterministic sampled curves with exact endpoints/extents. Open walls never close implicitly. A straight wall has zero geometric width but a one-cell logical frame. A 2×2 oval or capsule is circular by design.

`scripts/act_editor/act_geometry.gd` stores:

- Explicit `format_version` and `library_version`, plus `title`, `grid_size` and `cell_size`.
- Ordered independent placements containing `shape_id`, `base_size`, `anchor`, `quarter_turns`, `flip_h` and `flip_v`.

Transforms apply clockwise quarter-turns, then mirrors along the final screen axes. Rotate composes another clockwise turn with existing mirrors. Saves reference shape IDs instead of duplicating points. Unknown/missing versions, invalid types, unknown shapes, incorrect frames and out-of-Act placements are rejected. Failed loads preserve the open document.

The canvas emits edit requests; the editor owns mutations and history. No grid-occupancy masks, boolean union, collision compilation or procedural-chunk assumptions enter the model. Future gameplay objects can use separate exact local-coordinate records. Connectors, gameplay objects, difficulty/reachability checks, runtime Act loading, playtesting and Zone assembly are deferred.

## Verification

Use the existing isolated import helper to prevent editor indentation conversion:

```powershell
& '.\experiments\visual_lab\launch.ps1' -GodotPath 'C:\Program Files\Godot\Godot.exe' -ImportOnly
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --script res://tests/act_geometry_regression.gd
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --script res://tests/act_editor_smoke.gd
```

The model regression checks all shapes against independent transform calculations, malformed data, overlap persistence and a fresh-process reload/edit/re-save. The scene smoke exercises pointer/keyboard gestures, history and file guards. Run it without `--headless` to capture `test-results/act-editor.png`.

Human review remains useful for palette comfort, drag precision, curve silhouettes and editing feel. This milestone has no gameplay playtest mode.
