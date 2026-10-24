# Act Geometry Editor

This standalone scene edits **one Act**, initially **12 columns × 12 rows**, with terrain, gameplay objects and optional Act markers. A system-owned red gutter appears below the terrain; it adds no terrain row. Authoring Resources remain independent of the existing generator, playable layouts and physics.

## Launch

Double-click **Act Geometry Editor.cmd**, or open `scenes/act_geometry_editor.tscn` in Godot and press **F6**. F5 still launches the playground.

```powershell
& 'C:\Program Files\Godot\Godot.exe' --path 'E:\Sonic Spinball Runners' res://scenes/act_geometry_editor.tscn
```

The Windows launcher uses the project's working ANGLE backend. For another Godot installation, run `scripts/act_editor/launch.ps1 -GodotPath 'D:\Tools\Godot.exe'`.

## Build an Act

1. Choose **Terrain**, **Gameplay** or **Act Markers**. Click a tool; terrain and the four gameplay-object palette items can also be dragged onto the canvas. **Gameplay → Rings** draws trails directly on the canvas. Terrain supports search by name/size and family filtering.
2. Terrain and gameplay stamps show a cursor preview; click to place and keep clicking to repeat. Act markers select themselves after placement; choose the tool again to replace a marker.
3. Press **Esc**, right-click, or choose **Select / Move**. Click terrain, gameplay or a marker, then drag to move it. Hold **Alt** for free gameplay-object or lifecycle-marker movement.
4. Rotate terrain/gameplay, flip terrain, or delete any selection. With a terrain/gameplay stamp active, transforms change the next stamp instead. Markers have no rotation or flip controls.
5. Save, close, return later and Load the saved file to continue editing.

| Action | Shortcut |
| --- | --- |
| Select / cancel current gesture | Esc or right-click |
| Rotate terrain 90° / gameplay object 15° clockwise | R |
| Rotate gameplay object 15° counterclockwise | Shift+R |
| Set exact gameplay resting angle | Angle field, then Enter |
| Flip terrain along screen horizontal / vertical axis | H / V |
| Delete selected terrain, object or Act marker | Delete or Backspace |
| Move selection one cell | Arrow keys |
| Move gameplay object or lifecycle marker one local pixel | Alt+Arrow keys |
| Free gameplay / lifecycle-marker position while placing / dragging | Hold Alt |
| Cycle terrain, gameplay objects and lifecycle markers under the cursor | Alt-click without dragging |
| Duplicate selected gameplay object | Ctrl+D or Duplicate |
| Undo / redo | Ctrl+Z / Ctrl+Y or Ctrl+Shift+Z |
| Zoom / pan / restore overview | Mouse wheel / middle-drag / Fit Grid |
| New / Load / Save / Save As | Ctrl+N / Ctrl+O / Ctrl+S / Ctrl+Shift+S |

Text fields retain normal text-editing shortcuts. Undo/redo covers terrain, connectors, lifecycle markers, gameplay objects, ring trails, names and cell size, retaining up to 100 edits per session. Each completed pointer drag adds at most one edit. Activation moves vertically only; Entry/Exit move horizontally only.

The default grid has 144 **cells**, with 13 boundary intersections along each axis. A 1×3 stamp becomes 3×1 after one quarter-turn. The integer anchor is the transformed frame's top-left corner. Movement rounds to the nearest anchor and clamps the entire frame inside the Act. Rotation near a border may move the anchor inward to keep the frame inside.

**Overlaps are allowed.** Frames reserve no cells. Selection tests actual polygons or proximity to open wall segments. Gameplay objects appear above terrain; the last-placed item in each of those layers wins. Lifecycle markers appear above both. Alt-click cycles overlapping terrain, gameplay objects and lifecycle markers, including covered pieces. Dashed frames are guides, not terrain. Alt never disables terrain snapping or its quarter-turn restriction.

Cell size specifies saved local authoring pixels per cell. It does not change terrain grid anchors or footprints, or rescale existing object positions. Gameplay-object preview dimensions follow cell size around their unchanged authored origins. The fitted view scales the Act to the window; zoom controls on-screen size. Grid dimensions are stored in the Resource; this MVP creates 12×12 Acts without a grid-resize tool.

## Gameplay objects

The **Gameplay** tab contains **Round Bumper**, **Triangle Bumper / Sling**, **Left Flipper**, **Right Flipper** and the **Rings** drawing tool. Cyan bumpers, yellow flippers and tiny gold rings are distinct from terrain geometry. These are collisionless authoring previews: they do not fire, swing, collect, collide or create physics bodies.

- **Anchors:** a round bumper uses its center; a flipper uses its pivot. A triangle bumper retains the same origin relative to its uniformly scaled silhouette. The small crosshair marks this point. Preview sizing never shifts the authored position.
- **Position:** normal placement and dragging snap the anchor to the nearest grid intersection. Hold **Alt** to use continuous local-pixel coordinates, including while a drag is already in progress. The canvas reports **SNAP ON** or **FREE MOVE**. Releasing Alt without moving the pointer does not round a freely placed position; later pointer movement resumes snapping. Arrow nudges preserve the existing fractional offset.
- **Rotation:** **R / Shift+R** changes gameplay orientation by **+15° / −15°**. Enter any finite angle in the numeric field for finer control. Angles are actual resting orientations, clockwise in the canvas's down-positive Y coordinates; they are not wrapped or rounded. Alt affects position only. Terrain still rotates in 90° steps.
- **Flippers:** the paddle, pivot, handedness label and curved swing arrow show future motion direction. Left and right defaults match the runtime resting orientations, about 18.33° and 161.67°. Changing the handedness selector changes swing direction while retaining the exact authored pivot and angle.
- **Duplication:** Ctrl+D copies the selected gameplay object and offsets it by one cell in both axes. Its fractional position and angle remain intact; the copy is selected. Undo treats duplication as one edit.

The standard round bumper has **diameter `0.5 × cell_size`** and **radius `0.25 × cell_size`**, centered on its authored position. At the default 50 px cell size, that is a 25 px diameter and 12.5 px radius. Drawing, placement previews and selection resolve the same size from the Act's cell size; changing cell size preserves its center and updates its diameter. No per-placement radius or file conversion is needed.

The sling's dominant dimension is **0.6 cell** (about 0.567 cell wide). Each flipper has a **0.65-cell pivot-to-tip centerline**, a 0.05-cell cap radius and a thin 0.1-cell body: **0.75 cell overall length**. At the default 50 px cell size, the sling is about 28.33×30 px and the flipper body is 37.5×5 px before rotation. Both hands retain their resting angles and swing direction; swing guides use the same reduced centerline length.

Tune these editor dimensions in `scripts/act_editor/preview_dimensions.gd`. It also centralizes the compact Spawn ring (0.24-cell diameter), pivot crosshairs, guide arrows, connector handles and outline widths. Small annotation units clamp at extreme zoom levels for readability; object silhouettes retain their exact cell-relative proportions. Connector span lengths and the full-width Activation line remain unchanged. Palette icons fit their thumbnail boxes independently of canvas scale. No runtime physics dimensions are changed.

Saved object records still contain only type, exact local position and angle. Preview size is derived separately and is never baked into position, stored as a new transform or used to rescale saved coordinates. Spawn position is likewise independent of its indicator size. Terrain definitions keep their exact cell footprints.

The Act's top-left is local `(0, 0)`, with X right and Y down. Gameplay placements store exact `Vector2` local pixels independently of cells. Existing objects can move beyond the grid boundary; their values are preserved, with no collision, occupancy or reachability restriction. Palette placement starts inside the visible Act. For example, `(438.5, 271.25)` remains fractional after save/restart/load.

## Ring trails

Choose **Gameplay → Rings**, then click once for one ring, or drag in any direction for an evenly spaced trail. Release to commit the whole trail as **one undo step**. The tool stays active for repeated trails. Esc or right-click cancels an unfinished gesture and returns to selection mode.

Endpoints snap to grid intersections normally; hold **Alt** for exact local-pixel endpoints. Intermediate rings are linearly interpolated and never individually grid-snapped, so diagonal trails stay smooth. Releasing Alt without moving does not re-snap the current preview. Ring placement can overlap filled terrain and other objects; no occupancy, collision or reachability correction occurs.

The compact **Spacing** field defaults to **0.4 cells between centers**. Both endpoints are included: the tool fits equal intervals no wider than the chosen spacing, so actual spacing may be slightly smaller. Coincident endpoints produce one ring. Spacing edits affect the selected trail or the next trail when none is selected. Each record stores its endpoints and spacing in local pixels, so later cell-size or preview changes do not reposition existing rings.

In **Select / Move**, click any ring to select the whole trail. Drag its body to move both endpoints together; once selected, drag either small endpoint handle to reshape the trail. A single ring moves as one point. Normal group movement snaps the start while preserving the trail's relative shape. Alt enables free movement; arrows move one cell and Alt+arrows move one pixel. Delete removes the whole trail, and Ctrl+D duplicates it one cell diagonally. Creation, movement, endpoint edits, spacing changes, duplication and deletion use the shared undo/redo history. Alt-click includes ring trails when cycling overlapping items.

Rings have a **0.18-cell diameter**, centralized as `RING_RADIUS_CELLS` in `preview_dimensions.gd`. Selection adds only a faint endpoint line and small handles. `ring_trails.gd` owns deterministic generation and default spacing; it has no runtime dependencies. A trail is limited to 4,096 rings to reject unbounded resource input without freezing the editor.

This feature is **authoring and persistence only**. The existing authored-Act playtest does not instantiate these trails yet; no ring collection, scoring, magnetism, collision, character interaction or procedural ring routes are added.

## Entry and Exit

Each Act can have one **Entry on the bottom border** and one **Exit on the top border**. Both are green spans covering contiguous cells. Drafts may leave either unset.

The **Act Markers** category includes these tools alongside **Activation Trigger** and **Spawn Point**. Entry/Exit also retain their quick-access buttons above the canvas.

- Choose **Entry (bottom)** or **Exit (top)**, then click or drag along the corresponding border. A click makes a one-cell span. Dragging in either direction includes the first and last cells; it replaces that connector if one already exists. Starting or releasing on the wrong border/interior does not create a connector.
- After placement, the connector is selected. Drag its middle to move while keeping its width; drag either endpoint handle to resize. Left/right arrows nudge it by one cell. Spans stay inside their boundary and at least one cell wide.
- **Delete** removes the selected connector. **Undo / Redo** handles each completed gesture as one edit. **Esc** or right-click cancels an unfinished gesture.
- In Select mode, clicking green spans selects connectors. **Alt-click** reaches terrain or gameplay objects beneath them. Connectors do not occupy cells, cut terrain or compile collision geometry.

The metadata row reports, for example, `Entry: width 2 · cells 7–8`. Cell indices start at zero. A span starting at X=7 with width=2 runs from grid boundary X=7 to X=9.

**Compatibility uses width only.** An Exit at X=1, width=3 is compatible with an Entry at X=8, width=3. `ActGeometry.compatible(previous_exit, next_entry)` compares positive integer widths and ignores horizontal positions; unset connectors are not compatible. Actual horizontal alignment of whole Acts belongs to a future runtime assembler.

## Activation, Spawn and the red gutter

Choose **Act Markers → Activation Trigger**, then click inside the terrain grid. The cyan dashed horizontal guide spans the full Act width. Drag it vertically or use Up/Down arrows. Position snaps to the grid by default; Alt allows a fine local Y. The upward arrow records its intended future meaning: crossing upward activates this Act as the checkpoint. Entering through the green Entry connector alone will not activate it.

Choose **Spawn Point**, then click inside the grid. Drag its marked anchor to move it. Default movement snaps to grid intersections; hold Alt for continuous exact local X/Y. A freely placed point stays fractional after releasing Alt, saving and reloading. For Act 1 this point will be the initial launch position; for an active Act it will be the future respawn location. No launch direction is authored in this milestone.

Each marker is optional and unique. Choosing its tool again replaces it. Click a marker to select it; Delete removes it. Alt-click cycles markers, gameplay objects and terrain at shared positions; Alt-drag retains the selected target. Each completed drag, replacement or deletion is one undo step. Esc cancels an unfinished edit.

Activation Y must be finite and satisfy `0 <= Y < Act height`. Spawn coordinates must be finite with `0 <= X < Act width` and `0 <= Y < Act height`. These are local-pixel bounds: the bottom and right boundaries are excluded. Invalid moves or placements report the problem and preserve the previous marker; they never clamp it to another location. A cell-size edit that would place a marker outside these bounds is rejected with a message. Unset markers remain valid, saveable drafts.

The translucent **red gutter** begins at the true bottom terrain boundary and spans one cell-height below it, using shared `ActGeometry.RED_GUTTER_CELLS`. It has no grid lines, terrain row index, editable marker or placement tool. Terrain clicks and palette drops cannot place anything there. Its height is derived from cell size and is not copied into each Act file; `terrain_bounds()` and `red_gutter_bounds()` expose the two distinct local rectangles.

The concepts remain separate: Entry is the physical connection, Activation is the upward checkpoint crossing, the red gutter provides recovery space below the active Act, and Spawn is its restart location. **No gameplay physics run in this editor.** The separate [Authored Act Playtest](AUTHORED_ACT_PLAYTEST.md) now detects upward Activation/Exit crossings and drains at the gutter's bottom, resetting to Spawn. Checkpoint transfers between multiple Acts remain future work.

## File workflow

**Save** creates or updates a `.tres` file; **Save As** chooses another destination. The dialog starts in persistent `user://acts`, outside the checkout, and allows other locations. The header shows the open file path and unsaved marker.

After restarting, choose **Load** and select your file. Geometry, order, title, grid/cell sizes, transforms, connector starts/widths, gameplay-object types, exact local positions and angles, Activation Y and Spawn position return exactly. History, palette selection and view position are session-only.

New, Load, Example, Close and the operating-system close button offer **Save / Discard / Cancel** when edits exist. Canceling Save As or a failed save keeps edits open. Saving validates a temporary sibling Resource by reloading and comparing its content, then replaces the destination with recovery handling for the old file. Forced termination before saving can still lose unsaved edits.

**Example** opens `data/acts/curve_garden.tres` as a new editable copy. Its 18 terrain placements include solid/open U and S curves, broad bumps, large triangles/diagonals, mirrors and deliberate overlaps. Four gameplay objects add a round bumper at `(438.5, 271.25)`, a triangle bumper rotated 32°, and both flipper hands with fractional pivot Y positions. Entry covers cells 7–9; Exit covers cells 1–3. Both have width 3 despite different positions. Activation is at local Y `450`; Spawn is at `(300.5, 555.25)`. The grid remains 12×12 with the red gutter derived beneath it. The example was authored through the editor's placement/connector/marker/save workflow. Save chooses a separate destination for the copy.

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
| Filled U | Same three U sizes | Solid area below the U curve, closed along the frame bottom |
| S-curves | 1×2, 1×3, 2×2, 2×3, 3×2, 3×3 | Smooth open wall with one inflection |
| Filled S | Same six S sizes | Solid area below the S curve, closed along the frame bottom |

`scripts/act_editor/terrain_shapes.gd` defines deterministic sampled curves with exact endpoints/extents. Open walls never close implicitly. A straight wall has zero geometric width but a one-cell logical frame. Redundant square ovals/capsules are absent; circles cover those cases. Filled U/S stamps fill all space beneath their matching open curve down to the canonical frame's bottom edge. Rotation and mirroring transform this entire solid.

Filled U uses the exact half-ellipse wall as its upper surface and closes through both bottom corners. Its two solid sides meet where the curve touches the frame bottom; the bowl above stays empty. The S wall runs from `(0,0)` to `(width,height)` using `x = width*(3t²−2t³), y = height*t`, with vertical endpoint tangents and one inflection. Filled S closes from its bottom-right endpoint through the bottom-left corner, leaving only the area above the curve empty. The existing `u_band_*` and `s_band_*` placement IDs now resolve to these corrected filled shapes; no file conversion is needed. The standalone runtime compiler consumes these same authoritative silhouettes.

`scripts/act_editor/act_geometry.gd` stores:

- Explicit `format_version` and `library_version`, plus `title`, `grid_size` and `cell_size`.
- Ordered independent placements containing `shape_id`, `base_size`, `anchor`, `quarter_turns`, `flip_h` and `flip_v`.
- `entry_start_x`, `entry_width`, `exit_start_x` and `exit_width`. Width 0 with start 0 means unset; otherwise the integer span must fit the Act's boundary.
- A separate ordered `gameplay_objects` array. Each dictionary contains `type`, `position: Vector2` in local pixels and `rotation_degrees`. The four type IDs are `round_bumper`, `triangle_bumper`, `left_flipper` and `right_flipper`; the two flipper IDs encode handedness.
- Separate lifecycle fields: `activation_y` (a local-pixel number or `null`) and `spawn_position` (a local-pixel `Vector2` or `null`). `null` means unset. Neither field changes terrain grid dimensions or connector metadata.
- A separate ordered `ring_trails` array. Each dictionary contains `start: Vector2`, `end: Vector2` and `spacing` in local pixels. Individual centers are reproduced deterministically from this record without snapping.

The current schema uses **format version 5 / terrain library version 2**. Existing format-2/3/4 Acts retain their authored data and load with an empty ring-trail collection. Format-2/3 Acts also gain unset lifecycle markers; format-2 files gain an empty gameplay-object array. Loading does not rewrite the source file; the next explicit save writes version 5. The earlier fresh-start terrain library still has no legacy shape aliases or version-1 migration path.

Use `ActGeometry.load_document()` and `save_document()` for persistence. In memory, `rotation_degrees`, a set `activation_y` and ring `spacing` are numbers. In the saved `.tres`, each uses one native `PackedByteArray` numeric payload, decoded on load. Godot 4.7.2's decimal text parser can change some float64 numbers by one binary unit; this narrow encoding preserves every bit without a second competing value. Local object/Spawn positions and ring endpoints remain native `Vector2` values. Plain numeric scalar fields are also accepted on input. No transform is rounded or snapped while saving or loading.

Transforms apply clockwise quarter-turns, then mirrors along the final screen axes. Rotate composes another clockwise turn with existing mirrors. Saves reference shape IDs instead of duplicating points. Normal field/shape validation and the existing unsaved-change workflow remain in place.

The canvas emits edit requests; the editor owns mutations and history. No grid-occupancy masks, boolean union, collision compilation or procedural-chunk assumptions enter the authoring model. Save a file with Spawn, then load it in the standalone [Authored Act Playtest](AUTHORED_ACT_PLAYTEST.md) to play its exact geometry with existing gameplay physics. Runtime compilation remains separate from authoring. Rings, boost pads, hazards, difficulty/reachability checks, horizontal Act alignment and Zone assembly remain deferred.

## Verification

Use the existing isolated import helper to prevent editor indentation conversion:

```powershell
& '.\experiments\visual_lab\launch.ps1' -GodotPath 'C:\Program Files\Godot\Godot.exe' -ImportOnly
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --script res://tests/act_geometry_regression.gd
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --script res://tests/act_connector_regression.gd
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --script res://tests/act_gameplay_regression.gd
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --script res://tests/act_lifecycle_regression.gd
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --script res://tests/act_ring_regression.gd
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --script res://tests/act_ring_editor_smoke.gd
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --script res://tests/act_editor_smoke.gd
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --script res://tests/act_gameplay_editor_smoke.gd
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --script res://tests/act_lifecycle_editor_smoke.gd
```

The geometry regression checks all shapes against independent transform calculations, curved fill coverage and triangulation, overlap persistence and a fresh-process reload/edit/re-save. Connector regression checks width-only compatibility, spans, drafts and restart persistence. Gameplay and lifecycle regressions check independent records, validation, exact fractional persistence and previous-format loading. Scene smoke scripts exercise actual pointer/keyboard gestures, both snapping modes, numeric angles, overlap selection, history, marker bounds, gutter rejection and file workflow. Run them graphically with the launcher's ANGLE backend for rendered captures.

Human review remains useful for palette comfort, drag precision, curve silhouettes and editing feel. Gameplay is tested in the separate authored-Act scene; the editor remains focused on authoring.
