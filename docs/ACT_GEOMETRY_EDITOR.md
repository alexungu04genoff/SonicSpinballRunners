# Act Geometry Editor

This standalone scene edits **one Act**, initially **12 columns × 12 rows**, with terrain stamps and optional boundary connectors. Its authoring Resources are independent of the existing generator, playable layouts and physics.

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

Text fields retain normal text-editing shortcuts. Undo/redo covers terrain, connector changes, names and cell size, retaining up to 100 edits per session.

The default grid has 144 **cells**, with 13 boundary intersections along each axis. A 1×3 stamp becomes 3×1 after one quarter-turn. The integer anchor is the transformed frame's top-left corner. Movement rounds to the nearest anchor and clamps the entire frame inside the Act. Rotation near a border may move the anchor inward to keep the frame inside.

**Overlaps are allowed.** Frames reserve no cells. Selection tests actual polygons or proximity to open wall segments, starting with the last-placed piece. Alt-click cycles overlapping hits, including covered pieces. Dashed frames are guides, not terrain.

Cell size specifies saved local authoring pixels per cell. It does not change grid anchors or footprints. The fitted view scales the Act to the window; zoom controls on-screen size. Grid dimensions are stored in the Resource; this MVP creates 12×12 Acts without a grid-resize tool.

## Entry and Exit

Each Act can have one **Entry on the bottom border** and one **Exit on the top border**. Both are green spans covering contiguous cells. Drafts may leave either unset.

- Choose **Entry (bottom)** or **Exit (top)**, then click or drag along the corresponding border. A click makes a one-cell span. Dragging in either direction includes the first and last cells; it replaces that connector if one already exists. Starting or releasing on the wrong border/interior does not create a connector.
- After placement, the connector is selected. Drag its middle to move while keeping its width; drag either endpoint handle to resize. Left/right arrows nudge it by one cell. Spans stay inside their boundary and at least one cell wide.
- **Delete** removes the selected connector. **Undo / Redo** handles each completed gesture as one edit. **Esc** or right-click cancels an unfinished gesture.
- In Select mode, clicking green spans selects connectors. **Alt-click** reaches terrain beneath them. Connectors do not occupy cells, cut terrain or compile collision geometry.

The metadata row reports, for example, `Entry: width 2 · cells 7–8`. Cell indices start at zero. A span starting at X=7 with width=2 runs from grid boundary X=7 to X=9.

**Compatibility uses width only.** An Exit at X=1, width=3 is compatible with an Entry at X=8, width=3. `ActGeometry.compatible(previous_exit, next_entry)` compares positive integer widths and ignores horizontal positions; unset connectors are not compatible. Actual horizontal alignment of whole Acts belongs to a future runtime assembler.

## File workflow

**Save** creates or updates a `.tres` file; **Save As** chooses another destination. The dialog starts in persistent `user://acts`, outside the checkout, and allows other locations. The header shows the open file path and unsaved marker.

After restarting, choose **Load** and select your file. Geometry, order, title, grid/cell sizes, transforms and connector starts/widths return exactly. History, palette selection and view position are session-only.

New, Load, Example, Close and the operating-system close button offer **Save / Discard / Cancel** when edits exist. Canceling Save As or a failed save keeps edits open. Saving validates a temporary sibling Resource by reloading and comparing its content, then replaces the destination with recovery handling for the old file. Forced termination before saving can still lose unsaved edits.

**Example** opens `data/acts/curve_garden.tres` as a new editable copy. Its 18 terrain placements include solid/open U and S curves, broad bumps, large triangles/diagonals, mirrors and deliberate overlaps. Entry covers cells 7–9; Exit covers cells 1–3. Both have width 3 despite different positions. The example was authored through the editor's stamp/connector/save workflow. Save chooses a separate destination for the copy.

## Shapes and format

The palette contains **77 stamps**. Useful solid/wall pairs appear together, with **SOLID TERRAIN** or **WALL ONLY** labels and previews. Search and family filtering remain available.

| Family | Canonical footprints | Geometry |
| --- | --- | --- |
| Straight walls | 1×1, 1×2, 1×3 | Open straight segment |
| L corners | 1×1, 1×2, 1×3, 2×2, 2×3, 3×3 | Two open perpendicular segments |
| Triangles | 1×1, 1×2, 1×3, 2×2, 3×2, 3×3 | Closed right triangle |
| Curved slopes | 1×1, 1×2, 1×3, 2×2, 2×3, 3×3 | Concave quarter-ellipse with closing edges |
| J curves | Same six slope sizes | Curved edge only |
| Squares / rectangles | 1×1, 2×2, 3×3, 1×2, 1×3 | Closed solid |
| Circles | 1×1, 2×2, 3×3 | Closed solid |
| Ovals | 1×2, 1×3, 2×3 | Closed ellipse |
| Bumps | All nine width × height combinations from 1×1 through 3×3 | Half-ellipse with flat base, including broad/flat 2×1 and 3×1 |
| Diagonal rails | Same six triangle sizes | Diagonal edge only |
| Capsules | 1×2, 1×3, 2×3 | Rounded ends and straight sides |
| Outer corners | 1×1, 2×2, 3×3 | Convex quarter-disk with closing edges |
| U-curves | 2×2, 2×3, 3×3 | Half-ellipse wall, no closing segment |
| U bands | Same three U sizes | Solid ribbon around the curve; mouth remains open |
| S-curves | 1×2, 1×3, 2×2, 2×3, 3×2, 3×3 | Smooth open wall with one inflection |
| S bands | Same six S sizes | Solid ribbon following the S curve, tapering to grid-corner endpoints |

`scripts/act_editor/terrain_shapes.gd` defines deterministic sampled curves with exact endpoints/extents. Open walls never close implicitly. A straight wall has zero geometric width but a one-cell logical frame. Redundant square ovals/capsules are absent; circles cover those cases. Solid U/S bands follow the curve instead of filling the frame.

The U band connects an outer half-ellipse to an inset inner curve at the two mouth ends. Its inset is 18% of the smaller frame dimension. The S wall runs from `(0,0)` to `(width,height)` using `x = width*(3t²−2t³), y = height*t`, with vertical endpoint tangents and one inflection. Its solid version uses horizontal offsets `±0.15*min(width,height)*sin²(πt)`; both sides meet at the exact grid endpoints. These are authoring silhouettes, not runtime collision rules.

`scripts/act_editor/act_geometry.gd` stores:

- Explicit `format_version` and `library_version`, plus `title`, `grid_size` and `cell_size`.
- Ordered independent placements containing `shape_id`, `base_size`, `anchor`, `quarter_turns`, `flip_h` and `flip_v`.
- `entry_start_x`, `entry_width`, `exit_start_x` and `exit_width`. Width 0 with start 0 means unset; otherwise the integer span must fit the Act's boundary.

The current schema uses **format version 2 / library version 2**. Per the fresh-start decision, there is no migration layer or legacy shape lookup. The bundled example uses the current schema.

Transforms apply clockwise quarter-turns, then mirrors along the final screen axes. Rotate composes another clockwise turn with existing mirrors. Saves reference shape IDs instead of duplicating points. Normal field/shape validation and the existing unsaved-change workflow remain in place.

The canvas emits edit requests; the editor owns mutations and history. No grid-occupancy masks, boolean union, collision compilation or procedural-chunk assumptions enter the model. Future gameplay objects can use separate exact local-coordinate records. Gameplay objects, difficulty/reachability checks, runtime Act loading, horizontal Act alignment, playtesting and Zone assembly are deferred.

## Verification

Use the existing isolated import helper to prevent editor indentation conversion:

```powershell
& '.\experiments\visual_lab\launch.ps1' -GodotPath 'C:\Program Files\Godot\Godot.exe' -ImportOnly
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --script res://tests/act_geometry_regression.gd
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --script res://tests/act_connector_regression.gd
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --script res://tests/act_editor_smoke.gd
```

The geometry regression checks all shapes against independent transform calculations, valid band polygons/voids, overlap persistence and a fresh-process reload/edit/re-save. The connector regression checks width-only compatibility, spans, drafts and restart persistence. The scene smoke exercises actual pointer/keyboard gestures, connector endpoints, history and the existing file workflow. Run it without `--headless` to capture `test-results/act-editor.png`.

Human review remains useful for palette comfort, drag precision, curve silhouettes and editing feel. This milestone has no gameplay playtest mode.
