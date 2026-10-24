# Act Geometry Editor

This standalone scene edits **one Act**, initially **12 columns × 12 rows**, with terrain stamps, optional boundary connectors and gameplay-object placements. Its authoring Resources are independent of the existing generator, playable layouts and physics.

## Launch

Double-click **Act Geometry Editor.cmd**, or open `scenes/act_geometry_editor.tscn` in Godot and press **F6**. F5 still launches the playground.

```powershell
& 'C:\Program Files\Godot\Godot.exe' --path 'E:\Sonic Spinball Runners' res://scenes/act_geometry_editor.tscn
```

The Windows launcher uses the project's working ANGLE backend. For another Godot installation, run `scripts/act_editor/launch.ps1 -GodotPath 'D:\Tools\Godot.exe'`.

## Build an Act

1. Choose **Terrain** or **Gameplay**, then click a palette item or drag it onto the canvas. Terrain supports search by name/size and family filtering.
2. The cursor ghost shows the geometry and dashed transform frame. Click to place; keep clicking to repeat.
3. Press **Esc**, right-click, or choose **Select / Move**. Click terrain or a gameplay object, then drag its anchor. Hold **Alt** for free gameplay-object movement.
4. Rotate, flip or delete the selection. With a palette stamp active, transforms change the next stamp instead.
5. Save, close, return later and Load the saved file to continue editing.

| Action | Shortcut |
| --- | --- |
| Select / cancel current gesture | Esc or right-click |
| Rotate terrain 90° / gameplay object 15° clockwise | R |
| Rotate gameplay object 15° counterclockwise | Shift+R |
| Set exact gameplay resting angle | Angle field, then Enter |
| Flip terrain along screen horizontal / vertical axis | H / V |
| Delete selected terrain, object or connector | Delete or Backspace |
| Move selection one cell | Arrow keys |
| Move gameplay object one local pixel | Alt+Arrow keys |
| Free gameplay position while placing / dragging | Hold Alt |
| Cycle terrain and gameplay objects under the cursor | Alt-click without dragging |
| Duplicate selected gameplay object | Ctrl+D or Duplicate |
| Undo / redo | Ctrl+Z / Ctrl+Y or Ctrl+Shift+Z |
| Zoom / pan / restore overview | Mouse wheel / middle-drag / Fit Grid |
| New / Load / Save / Save As | Ctrl+N / Ctrl+O / Ctrl+S / Ctrl+Shift+S |

Text fields retain normal text-editing shortcuts. Undo/redo covers terrain, connector and gameplay-object changes, names and cell size, retaining up to 100 edits per session. Each completed pointer drag adds at most one edit.

The default grid has 144 **cells**, with 13 boundary intersections along each axis. A 1×3 stamp becomes 3×1 after one quarter-turn. The integer anchor is the transformed frame's top-left corner. Movement rounds to the nearest anchor and clamps the entire frame inside the Act. Rotation near a border may move the anchor inward to keep the frame inside.

**Overlaps are allowed.** Frames reserve no cells. Selection tests actual polygons or proximity to open wall segments. Gameplay objects appear above terrain; the last-placed item in each layer wins. Alt-click cycles overlapping hits across both layers, including covered pieces. Dashed frames are guides, not terrain. Alt never disables terrain snapping or its quarter-turn restriction.

Cell size specifies saved local authoring pixels per cell. It does not change terrain grid anchors or footprints, or rescale existing gameplay-object positions/dimensions. The fitted view scales the Act to the window; zoom controls on-screen size. Grid dimensions are stored in the Resource; this MVP creates 12×12 Acts without a grid-resize tool.

## Gameplay objects

The **Gameplay** tab contains only **Round Bumper**, **Triangle Bumper / Sling**, **Left Flipper** and **Right Flipper**. Cyan bumpers and yellow flippers are distinct from terrain geometry. These are collisionless authoring previews: they do not fire, swing, collide or create physics bodies.

- **Anchors:** a round bumper uses its center; a flipper uses its physical pivot. A triangle bumper uses the marked local origin inside its silhouette, matching the existing bottom-table triangle's origin. The small crosshair marks this point.
- **Position:** normal placement and dragging snap the anchor to the nearest grid intersection. Hold **Alt** to use continuous local-pixel coordinates, including while a drag is already in progress. The canvas reports **SNAP ON** or **FREE MOVE**. Releasing Alt without moving the pointer does not round a freely placed position; later pointer movement resumes snapping. Arrow nudges preserve the existing fractional offset.
- **Rotation:** **R / Shift+R** changes gameplay orientation by **+15° / −15°**. Enter any finite angle in the numeric field for finer control. Angles are actual resting orientations, clockwise in the canvas's down-positive Y coordinates; they are not wrapped or rounded. Alt affects position only. Terrain still rotates in 90° steps.
- **Flippers:** the paddle, pivot, handedness label and curved swing arrow show future motion direction. Left and right defaults match the runtime resting orientations, about 18.33° and 161.67°. Changing the handedness selector changes swing direction while retaining the exact authored pivot and angle.
- **Duplication:** Ctrl+D copies the selected gameplay object and offsets it by one cell in both axes. Its fractional position and angle remain intact; the copy is selected. Undo treats duplication as one edit.

The silhouettes use the current bottom-table proportions: round bumper radius 38 px, the existing triangle's three local vertices, and a 130 px flipper centerline with 13 px end-cap radius. Definitions are pure editor data and do not load runtime physics scripts. These dimensions stay constant when changing grid cell size.

The Act's top-left is local `(0, 0)`, with X right and Y down. Gameplay placements store exact `Vector2` local pixels independently of cells. Existing objects can move beyond the grid boundary; their values are preserved, with no collision, occupancy or reachability restriction. Palette placement starts inside the visible Act. For example, `(438.5, 271.25)` remains fractional after save/restart/load.

## Entry and Exit

Each Act can have one **Entry on the bottom border** and one **Exit on the top border**. Both are green spans covering contiguous cells. Drafts may leave either unset.

- Choose **Entry (bottom)** or **Exit (top)**, then click or drag along the corresponding border. A click makes a one-cell span. Dragging in either direction includes the first and last cells; it replaces that connector if one already exists. Starting or releasing on the wrong border/interior does not create a connector.
- After placement, the connector is selected. Drag its middle to move while keeping its width; drag either endpoint handle to resize. Left/right arrows nudge it by one cell. Spans stay inside their boundary and at least one cell wide.
- **Delete** removes the selected connector. **Undo / Redo** handles each completed gesture as one edit. **Esc** or right-click cancels an unfinished gesture.
- In Select mode, clicking green spans selects connectors. **Alt-click** reaches terrain or gameplay objects beneath them. Connectors do not occupy cells, cut terrain or compile collision geometry.

The metadata row reports, for example, `Entry: width 2 · cells 7–8`. Cell indices start at zero. A span starting at X=7 with width=2 runs from grid boundary X=7 to X=9.

**Compatibility uses width only.** An Exit at X=1, width=3 is compatible with an Entry at X=8, width=3. `ActGeometry.compatible(previous_exit, next_entry)` compares positive integer widths and ignores horizontal positions; unset connectors are not compatible. Actual horizontal alignment of whole Acts belongs to a future runtime assembler.

## File workflow

**Save** creates or updates a `.tres` file; **Save As** chooses another destination. The dialog starts in persistent `user://acts`, outside the checkout, and allows other locations. The header shows the open file path and unsaved marker.

After restarting, choose **Load** and select your file. Geometry, order, title, grid/cell sizes, transforms, connector starts/widths, gameplay-object types, exact local positions and angles return exactly. History, palette selection and view position are session-only.

New, Load, Example, Close and the operating-system close button offer **Save / Discard / Cancel** when edits exist. Canceling Save As or a failed save keeps edits open. Saving validates a temporary sibling Resource by reloading and comparing its content, then replaces the destination with recovery handling for the old file. Forced termination before saving can still lose unsaved edits.

**Example** opens `data/acts/curve_garden.tres` as a new editable copy. Its 18 terrain placements include solid/open U and S curves, broad bumps, large triangles/diagonals, mirrors and deliberate overlaps. Four gameplay objects add a round bumper at `(438.5, 271.25)`, a triangle bumper rotated 32°, and both flipper hands with fractional pivot Y positions. Entry covers cells 7–9; Exit covers cells 1–3. Both have width 3 despite different positions. The example was authored through the editor's placement/connector/save workflow. Save chooses a separate destination for the copy.

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
- A separate ordered `gameplay_objects` array. Each dictionary contains `type`, `position: Vector2` in local pixels and `rotation_degrees`. The four type IDs are `round_bumper`, `triangle_bumper`, `left_flipper` and `right_flipper`; the two flipper IDs encode handedness.

The current schema uses **format version 3 / terrain library version 2**. Existing **format-2 terrain/connector Acts** load with an empty gameplay-object array and keep their terrain/connector values. Loading does not rewrite the source file; the next explicit save writes version 3. The earlier fresh-start terrain library still has no legacy shape aliases or version-1 migration path.

Use `ActGeometry.load_document()` and `save_document()` for persistence. In memory, `rotation_degrees` is a number. In the saved `.tres`, that field uses one native `PackedByteArray` numeric payload, decoded on load. Godot 4.7.2's decimal text parser can change some float64 angles by one binary unit; this narrow encoding preserves every angle bit without a second competing value. Local positions remain native `Vector2` values. Plain numeric angle fields are also accepted on input. No transform is rounded or snapped while saving or loading.

Transforms apply clockwise quarter-turns, then mirrors along the final screen axes. Rotate composes another clockwise turn with existing mirrors. Saves reference shape IDs instead of duplicating points. Normal field/shape validation and the existing unsaved-change workflow remain in place.

The canvas emits edit requests; the editor owns mutations and history. No grid-occupancy masks, boolean union, collision compilation or procedural-chunk assumptions enter the model. Rings, boost pads, hazards, difficulty/reachability checks, runtime Act loading, horizontal Act alignment, playtesting and Zone assembly are deferred. The authored Act is not yet playable.

## Verification

Use the existing isolated import helper to prevent editor indentation conversion:

```powershell
& '.\experiments\visual_lab\launch.ps1' -GodotPath 'C:\Program Files\Godot\Godot.exe' -ImportOnly
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --script res://tests/act_geometry_regression.gd
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --script res://tests/act_connector_regression.gd
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --script res://tests/act_gameplay_regression.gd
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --script res://tests/act_editor_smoke.gd
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --script res://tests/act_gameplay_editor_smoke.gd
```

The geometry regression checks all shapes against independent transform calculations, valid band polygons/voids, overlap persistence and a fresh-process reload/edit/re-save. The connector regression checks width-only compatibility, spans, drafts and restart persistence. Gameplay regression checks independent object records, validation, exact fractional persistence and version-2 loading. Scene smoke scripts exercise actual pointer/keyboard gestures, both snapping modes, numeric angles, overlap selection, history and file workflow. Run them graphically with the launcher's ANGLE backend for rendered captures.

Human review remains useful for palette comfort, drag precision, curve silhouettes and editing feel. This milestone has no gameplay playtest mode.
