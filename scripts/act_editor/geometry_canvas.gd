extends Control
## Authoring drawing and pointer gestures only. The editor owns changes and undo.

signal placement_requested(placement: Dictionary)
signal selection_changed(index: int)
signal terrain_selection_changed(indices: Array[int])
signal composite_preview_cancel_requested
signal composite_corner_toggled(index: int)
signal move_requested(index: int, anchor: Vector2)
signal connector_requested(kind: String, start_x: int, width: int)
signal connector_selection_changed(kind: String)
signal gameplay_placement_requested(placement: Dictionary)
signal gameplay_selection_changed(index: int)
signal gameplay_move_requested(index: int, position: Vector2)
signal marker_requested(kind: String, value: Variant)
signal marker_selection_changed(kind: String)
signal ring_requested(index: int, trail: Dictionary)
signal ring_selection_changed(index: int)
signal decor_requested(index: int, slot: Dictionary)
signal decor_selection_changed(index: int)
signal status_changed(message: String)

const ActData = preload("res://scripts/act_editor/act_geometry.gd")
const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
signal rail_points_changed(points: PackedVector2Array)
var rail_edit := false
var _rail_draft: Dictionary = {}
var _rail_drag := -1
var _rail_preview := PackedVector2Array()
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const ObjectPreview = preload("res://scripts/act_editor/gameplay_preview.gd")
const PreviewDimensions = preload("res://scripts/act_editor/preview_dimensions.gd")
const Rings = preload("res://scripts/act_editor/ring_trails.gd")
const Decor = preload("res://scripts/act_editor/decor_slots.gd")
const GRID_MARGIN := 48.0
const MIN_CELL_PIXELS := 12.0
const MAX_CELL_PIXELS := 240.0
const SELECTION_COLOR := Color("b9f4ff")
const CONNECTOR_COLOR := Color("71efa4")
const CONNECTOR_BORDER_TOLERANCE := 12.0
const POINTER_JITTER_PIXELS := 0.01
const ACTIVATION_COLOR := Color("62eee3")
const SPAWN_COLOR := Color("ffd0ee")
const INVALID_MARKER_COLOR := Color("ff7a88")
const COMPOSITE_PREVIEW_COLOR := Color("ffd96c")

var document: Resource
var selected_index := -1
var selected_indices: Array[int] = []
var composite_preview: Dictionary = {}
var preview_active := false
var _smoothing_corners := PackedVector2Array()
var _smoothing_corner_indices := PackedInt32Array()
var _protected_corners := PackedInt32Array()
var terrain_snap_step := 1.0
var brush: Dictionary = {}
var connector_tool := ""
var selected_connector := ""
var gameplay_brush: Dictionary = {}
var selected_gameplay_indices: Array[int] = []
var selected_gameplay_index := -1:
 set(value):
  selected_gameplay_index = value
  selected_gameplay_indices.assign([value] if value >= 0 else [])
var marker_tool := ""
var selected_marker := ""
var ring_tool := false
var ring_kind := "line"
var ring_fill := false
var ring_rotation := 0.0
var ring_radii := Vector2(50, 50)
var trajectory_gravity_scale: float = preload("res://data/balanced.tres").gravity_scale
var selected_ring_index := -1
var decor_brush: Dictionary = {}
var selected_decor_index := -1
var show_decor := true
var decor_snap := false
var _decor_drag_index := -1
var _decor_drag_start := Vector2.ZERO
var _decor_drag_original := Vector2.ZERO
var _decor_drag_position := Vector2.ZERO
var _decor_drag_moved := false
var ring_spacing_cells := Rings.DEFAULT_SPACING_CELLS
var _ring_mode := ""
var _ring_index := -1
var _ring_original: Dictionary = {}
var _ring_preview: Dictionary = {}
var _ring_start_pointer := Vector2.ZERO
var _ring_last_pointer := Vector2.ZERO
var _ring_moved := false

var _view_origin := Vector2.ZERO
var _cell_pixels := 48.0
var _view_adjusted := false
var _last_size := Vector2.ZERO
var _hovering := false
var _cursor_position := Vector2.ZERO
var _panning := false
var _drag_index := -1
var _drag_start_pointer := Vector2.ZERO
var _drag_start_anchor := Vector2.ZERO
var _drag_anchor := Vector2.ZERO
var _drag_last_pointer := Vector2.ZERO
var _drag_moved := false
var _drop_brush: Dictionary = {}
var _last_status := ""
var _connector_drag_kind := ""
var _connector_drag_mode := ""
var _connector_first_cell := 0
var _connector_pointer_start_x := 0.0
var _connector_original_start := 0
var _connector_original_width := 0
var _connector_preview_start := 0
var _connector_preview_width := 0
var _connector_release_valid := true
var _gameplay_drag_index := -1
var _gameplay_drag_start_pointer := Vector2.ZERO
var _gameplay_drag_start_position := Vector2.ZERO
var _gameplay_drag_position := Vector2.ZERO
var _gameplay_drag_last_pointer := Vector2.ZERO
var _gameplay_drag_moved := false
var _drop_gameplay_brush: Dictionary = {}
var _pending_cycle_target: Dictionary = {}
var _alt_held := false
var _marker_drag_kind := ""
var _marker_drag_start_pointer := Vector2.ZERO
var _marker_drag_last_pointer := Vector2.ZERO
var _marker_drag_start_value: Variant = null
var _marker_drag_value: Variant = null
var _marker_drag_moved := false


func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_STOP
 focus_mode = Control.FOCUS_ALL
 clip_contents = true
 resized.connect(_on_resized)
 mouse_entered.connect(func():
  _hovering = true
  _cursor_position = get_local_mouse_position()
  queue_redraw()
 )
 mouse_exited.connect(func():
  _hovering = false
  _drop_brush = {}
  _drop_gameplay_brush = {}
  queue_redraw()
 )
 fit_view()


func set_document(value: Resource, reset_view: bool = true) -> void:
 _clear_decor_selection()
 ring_tool = false
 selected_ring_index = -1
 document = value
 selected_index = -1
 selected_indices.clear()
 composite_preview = {}
 preview_active = false
 set_smoothing_corners({}, PackedInt32Array())
 brush = {}
 connector_tool = ""
 selected_connector = ""
 gameplay_brush = {}
 selected_gameplay_index = -1
 marker_tool = ""
 selected_marker = ""
 cancel_gesture()
 if reset_view:
  fit_view()
 else:
  queue_redraw()


func set_brush(value: Dictionary) -> void:
 _clear_decor_selection()
 ring_tool = false
 selected_ring_index = -1
 cancel_gesture()
 brush = value.duplicate(true)
 selected_index = -1
 selected_indices.clear()
 connector_tool = ""
 selected_connector = ""
 gameplay_brush = {}
 selected_gameplay_index = -1
 marker_tool = ""
 selected_marker = ""
 queue_redraw()


func select_piece(index: int) -> void:
 var indices: Array[int] = []
 if index >= 0 and index < _placements().size():
  indices.append(index)
 set_terrain_selection(indices)


func set_terrain_selection(indices: Array[int]) -> void:
 _clear_decor_selection()
 ring_tool = false
 selected_ring_index = -1
 cancel_gesture()
 brush = {}
 selected_indices = []
 for index in indices:
  if index >= 0 and index < _placements().size() and not selected_indices.has(index):
   selected_indices.append(index)
 selected_index = selected_indices.back() if not selected_indices.is_empty() else -1
 connector_tool = ""
 selected_connector = ""
 gameplay_brush = {}
 selected_gameplay_index = -1
 marker_tool = ""
 selected_marker = ""
 queue_redraw()


func set_composite_preview(placement: Dictionary, active: bool) -> void:
 cancel_gesture()
 composite_preview = placement.duplicate(true)
 preview_active = active
 if not active: set_smoothing_corners({}, PackedInt32Array())
 queue_redraw()


func set_smoothing_corners(source: Dictionary, protected_indices: PackedInt32Array) -> void:
 _smoothing_corners.clear()
 _smoothing_corner_indices.clear()
 _protected_corners = protected_indices.duplicate()
 if not source.is_empty():
  var points := Shapes.transformed_points(source)
  var anchor := Shapes.placement_position(source)
  for index in points.size():
   var incoming := points[index] - points[posmod(index - 1, points.size())]
   var outgoing := points[(index + 1) % points.size()] - points[index]
   # Gentle curve samples already bypass smoothing; expose meaningful corners.
   if incoming.normalized().dot(outgoing.normalized()) > 0.99875: continue
   _smoothing_corners.append(points[index] + anchor)
   _smoothing_corner_indices.append(index)
 queue_redraw()


func smoothing_corner_at(pointer: Vector2) -> int:
 var nearest := -1
 var distance := 10.0
 for index in _smoothing_corners.size():
  var candidate := grid_to_screen(_smoothing_corners[index]).distance_to(pointer)
  if candidate < distance:
   nearest = _smoothing_corner_indices[index]
   distance = candidate
 return nearest


func set_connector_tool(kind: String) -> void:
 _clear_decor_selection()
 ring_tool = false
 selected_ring_index = -1
 cancel_gesture()
 brush = {}
 selected_index = -1
 selected_indices.clear()
 selected_connector = ""
 connector_tool = kind if kind in ["entry", "exit"] else ""
 gameplay_brush = {}
 selected_gameplay_index = -1
 marker_tool = ""
 selected_marker = ""
 queue_redraw()


func select_connector(kind: String) -> void:
 _clear_decor_selection()
 ring_tool = false
 selected_ring_index = -1
 cancel_gesture()
 brush = {}
 selected_index = -1
 selected_indices.clear()
 connector_tool = ""
 selected_connector = kind if kind in ["entry", "exit"] and connector_span(kind).y > 0 else ""
 gameplay_brush = {}
 selected_gameplay_index = -1
 marker_tool = ""
 selected_marker = ""
 queue_redraw()


func set_gameplay_brush(value: Dictionary) -> void:
 _clear_decor_selection()
 ring_tool = false
 selected_ring_index = -1
 cancel_gesture()
 brush = {}
 selected_index = -1
 selected_indices.clear()
 connector_tool = ""
 selected_connector = ""
 gameplay_brush = value.duplicate(true)
 selected_gameplay_index = -1
 marker_tool = ""
 selected_marker = ""
 queue_redraw()


func select_gameplay(index: int) -> void:
 _clear_decor_selection()
 ring_tool = false
 selected_ring_index = -1
 cancel_gesture()
 brush = {}
 selected_index = -1
 selected_indices.clear()
 connector_tool = ""
 selected_connector = ""
 gameplay_brush = {}
 selected_gameplay_index = index if index >= 0 and index < _gameplay_objects().size() else -1
 marker_tool = ""
 selected_marker = ""
 queue_redraw()

func set_gameplay_selection(indices: Array[int]) -> void:
 select_gameplay(-1)
 var valid: Array[int] = []
 for index: int in indices:
  if index >= 0 and index < _gameplay_objects().size() and not valid.has(index): valid.append(index)
 selected_gameplay_index = valid.back() if not valid.is_empty() else -1
 selected_gameplay_indices = valid
 queue_redraw()


func set_marker_tool(kind: String) -> void:
 select_piece(-1)
 marker_tool = kind if kind in ["activation", "spawn"] else ""
 queue_redraw()


func select_marker(kind: String) -> void:
 select_piece(-1)
 selected_marker = kind if marker_value(kind) != null else ""
 queue_redraw()


func set_ring_tool() -> void:
 select_piece(-1)
 ring_tool = true
 queue_redraw()

func select_ring(index: int) -> void:
 select_piece(-1)
 selected_ring_index = index if index >= 0 and index < document.ring_trails.size() else -1
 queue_redraw()

func marker_value(kind: String) -> Variant:
 if document == null:
  return null
 if kind == "activation":
  return document.get("activation_y")
 if kind == "spawn":
  return document.get("spawn_position")
 return null

func _clear_decor_selection() -> void:
 decor_brush = {}
 selected_decor_index = -1

func set_decor_brush(slot: Dictionary) -> void:
 select_piece(-1)
 decor_brush = slot.duplicate(true)
 show_decor = true
 queue_redraw()

func select_decor(index: int) -> void:
 select_piece(-1)
 selected_decor_index = index if index >= 0 and index < document.decor_slots.size() else -1
 queue_redraw()

func decor_position(point: Vector2, alt: bool) -> Vector2:
 return legal_gameplay_position(point, not decor_snap or alt)

func _decor_radius(slot: Dictionary) -> float:
 return maxf(5.0, Decor.RADII[Decor.TYPES.find(slot.slot_type)] * _cell_pixels * float(slot.get("scale", 1.0)))

func _draw_decor() -> void:
 if not show_decor: return
 for index in document.decor_slots.size():
  var slot: Dictionary = document.decor_slots[index].duplicate(true)
  if index == _decor_drag_index: slot.position = _decor_drag_position
  _draw_decor_slot(slot, index == selected_decor_index, false)
 if not decor_brush.is_empty() and _hovering and _inside_grid(_cursor_position):
  var slot := decor_brush.duplicate(true)
  slot.position = decor_position(screen_to_local_pixels(_cursor_position), _alt_held)
  _draw_decor_slot(slot, false, true)

func _draw_decor_slot(slot: Dictionary, selected: bool, ghost: bool) -> void:
 var center := local_pixels_to_screen(slot.position)
 var radius := _decor_radius(slot)
 var color: Color = Decor.COLORS[Decor.TYPES.find(slot.slot_type)]
 draw_circle(center, radius, Color(color, 0.20 if ghost else 0.65))
 draw_arc(center, radius, 0, TAU, 24, SELECTION_COLOR if selected else color, 2.0, true)
 var direction := Vector2.RIGHT.rotated(deg_to_rad(float(slot.rotation_degrees)))
 draw_line(center, center + direction * (radius + 7), color, 2.0, true)
 var label: String = "◆" if slot.slot_type == "landmark" else slot.slot_type.left(1).to_upper()
 draw_string(ThemeDB.fallback_font, center + Vector2(-3, 3), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("101a25"))

func _update_decor_drag(pointer: Vector2, alt: bool) -> void:
 var delta := screen_to_local_pixels(pointer) - _decor_drag_start
 if not _decor_drag_moved and delta.length() * _cell_pixels / _local_cell_size() < 3: return
 _decor_drag_moved = true
 _pending_cycle_target = {}
 _decor_drag_position = decor_position(_decor_drag_original + delta, alt)

func _end_decor_drag() -> void:
 var index := _decor_drag_index
 var moved := _decor_drag_moved and _decor_drag_position != _decor_drag_original
 _decor_drag_index = -1
 _decor_drag_moved = false
 if moved:
  var slot: Dictionary = document.decor_slots[index].duplicate(true)
  slot.position = _decor_drag_position
  decor_requested.emit(index, slot)
 _finish_cycle_click()
 queue_redraw()


func fit_view() -> void:
 var dimensions := Vector2(_grid_size())
 dimensions.y += ActData.RED_GUTTER_CELLS
 var available := (size - Vector2.ONE * GRID_MARGIN * 2.0).max(Vector2.ONE)
 _cell_pixels = clampf(minf(available.x / dimensions.x, available.y / dimensions.y), 4.0, MAX_CELL_PIXELS)
 _view_origin = (size - dimensions * _cell_pixels) * 0.5
 _view_adjusted = false
 _last_size = size
 queue_redraw()


func cancel_gesture() -> void:
 _rail_draft = {}
 _rail_drag = -1
 _decor_drag_index = -1
 _decor_drag_moved = false
 _ring_mode = ""
 _ring_index = -1
 _ring_preview = {}
 _ring_original = {}
 _ring_moved = false
 _drag_index = -1
 _drag_moved = false
 _panning = false
 _drop_brush = {}
 _connector_drag_kind = ""
 _connector_drag_mode = ""
 _connector_release_valid = true
 _gameplay_drag_index = -1
 _gameplay_drag_moved = false
 _drop_gameplay_brush = {}
 _pending_cycle_target = {}
 _marker_drag_kind = ""
 _marker_drag_moved = false
 _marker_drag_start_value = null
 _marker_drag_value = null
 queue_redraw()


func grid_to_screen(point: Vector2) -> Vector2:
 return _view_origin + point * _cell_pixels


func screen_to_grid(point: Vector2) -> Vector2:
 return (point - _view_origin) / _cell_pixels


func screen_to_local_pixels(point: Vector2) -> Vector2:
 return screen_to_grid(point) * _local_cell_size()


func local_pixels_to_screen(point: Vector2) -> Vector2:
 return grid_to_screen(point / _local_cell_size())


func legal_gameplay_position(position: Vector2, free_move: bool) -> Vector2:
 if free_move:
  return position
 return (position / _local_cell_size()).round() * _local_cell_size()


func gameplay_hit_indices_at(local_position: Vector2) -> Array[int]:
 var hits: Array[int] = []
 var pixel_position := screen_to_local_pixels(local_position)
 var tolerance := 7.0 * _local_cell_size() / _cell_pixels
 var objects := _gameplay_objects()
 for index in range(objects.size() - 1, -1, -1):
  var placement: Dictionary = objects[index]
  var points := ObjectPreview.rotated_points(placement, _local_cell_size())
  var point := pixel_position - Vector2(placement.position)
  if points.size() < 2:
   continue
  if placement.type != "elevated_rail" and Geometry2D.is_point_in_polygon(point, points):
   hits.append(index)
   continue
  for segment in (points.size() - 1 if placement.type == "elevated_rail" else points.size()):
   var nearest := Geometry2D.get_closest_point_to_segment(point, points[segment], points[(segment + 1) % points.size()])
   var hit_width := maxf(tolerance, float(Objects.properties(placement).width) * 0.5) if placement.type == "elevated_rail" else tolerance
   if nearest.distance_to(point) <= hit_width:
    hits.append(index)
    break
 return hits


func mixed_hit_indices_at(local_position: Vector2) -> Array[Dictionary]:
 var hits: Array[Dictionary] = []
 if show_decor:
  for index in range(document.decor_slots.size() - 1, -1, -1):
   var slot: Dictionary = document.decor_slots[index]
   if local_position.distance_to(local_pixels_to_screen(slot.position)) <= _decor_radius(slot) + 3:
    hits.append({"kind": "decor", "index": index})
 for kind: String in marker_hits_at(local_position):
  hits.append({"kind": "marker", "marker": kind})
 for index in range(document.ring_trails.size() - 1, -1, -1):
  var trail: Dictionary = document.ring_trails[index]
  var hit := false
  var radius := maxf(5.0, PreviewDimensions.RING_RADIUS_CELLS * _cell_pixels + 2.0)
  for point: Vector2 in Rings.positions(trail):
   if local_position.distance_to(local_pixels_to_screen(point)) <= radius:
    hit = true
    break
  if index == selected_ring_index:
   var nearest := Geometry2D.get_closest_point_to_segment(local_position, local_pixels_to_screen(trail.start), local_pixels_to_screen(trail.end))
   hit = hit or nearest.distance_to(local_position) <= 5.0
  if hit:
   hits.append({"kind": "ring", "index": index})
 for index: int in gameplay_hit_indices_at(local_position):
  hits.append({"kind": "gameplay", "index": index})
 for index: int in hit_indices_at(local_position):
  hits.append({"kind": "terrain", "index": index})
 return hits


func marker_hits_at(local_position: Vector2) -> Array[String]:
 var hits: Array[String] = []
 var spawn: Variant = marker_value("spawn")
 if spawn is Vector2 and local_position.distance_to(local_pixels_to_screen(spawn)) <= 15.0:
  hits.append("spawn")
 var activation: Variant = marker_value("activation")
 if activation != null:
  var start := local_pixels_to_screen(Vector2(0, float(activation)))
  var end := local_pixels_to_screen(Vector2(document.terrain_bounds().size.x, float(activation)))
  if local_position.x >= start.x and local_position.x <= end.x and absf(local_position.y - start.y) <= 8.0:
   hits.append("activation")
 return hits


func valid_marker_value(kind: String, value: Variant) -> bool:
 if document == null:
  return false
 var bounds: Rect2 = document.terrain_bounds()
 if kind == "spawn":
  return value is Vector2 and value.is_finite() and bounds.has_point(value)
 if kind == "activation" and typeof(value) in [TYPE_FLOAT, TYPE_INT]:
  return is_finite(value) and value >= bounds.position.y and value < bounds.end.y
 return false


func connector_span(kind: String) -> Vector2i:
 if document == null or kind not in ["entry", "exit"]:
  return Vector2i.ZERO
 return Vector2i(int(document.get(kind + "_start_x")), int(document.get(kind + "_width")))


func connector_border_at(local_position: Vector2) -> String:
 var left_x := grid_to_screen(Vector2.ZERO).x
 var right_x := grid_to_screen(Vector2(_grid_size().x, 0)).x
 if local_position.x < left_x or local_position.x > right_x:
  return ""
 var top_distance := absf(local_position.y - grid_to_screen(Vector2.ZERO).y)
 var bottom_distance := absf(local_position.y - grid_to_screen(Vector2(0, _grid_size().y)).y)
 if minf(top_distance, bottom_distance) > CONNECTOR_BORDER_TOLERANCE:
  return ""
 return "exit" if top_distance <= bottom_distance else "entry"


func connector_hit_at(local_position: Vector2) -> String:
 for kind: String in ["entry", "exit"]:
  var span := connector_span(kind)
  if span.y <= 0:
   continue
  var start := grid_to_screen(Vector2(span.x, _connector_row(kind)))
  var end := grid_to_screen(Vector2(span.x + span.y, _connector_row(kind)))
  if absf(local_position.y - start.y) <= CONNECTOR_BORDER_TOLERANCE and local_position.x >= start.x - 7.0 and local_position.x <= end.x + 7.0:
   return kind
 return ""


func connector_handle_at(kind: String, local_position: Vector2) -> String:
 var span := connector_span(kind)
 if span.y <= 0 or connector_hit_at(local_position) != kind:
  return ""
 var left := grid_to_screen(Vector2(span.x, _connector_row(kind))).x
 var right := grid_to_screen(Vector2(span.x + span.y, _connector_row(kind))).x
 # Leave a generous move target even when the connector is only one cell wide.
 var handle_radius := minf(8.0, _cell_pixels * 0.22)
 if absf(local_position.x - left) <= handle_radius:
  return "left"
 if absf(local_position.x - right) <= handle_radius:
  return "right"
 return "move"


func legal_anchor_for(placement: Dictionary, grid_position: Vector2, free_move: bool = false) -> Vector2:
 var limit := (Vector2(_grid_size()) - Shapes.scaled_size(placement)).max(Vector2.ZERO)
 var point := grid_position if free_move else grid_position.snapped(Vector2.ONE * terrain_snap_step)
 return point.clamp(Vector2.ZERO, limit)


func hit_indices_at(local_position: Vector2) -> Array[int]:
 var hits: Array[int] = []
 var grid_point := screen_to_grid(local_position)
 var tolerance := 7.0 / _cell_pixels
 var placements := _placements()
 for index in range(placements.size() - 1, -1, -1):
  var placement: Dictionary = placements[index]
  var definition: Dictionary = Shapes.definition_for_placement(placement)
  if definition.is_empty():
   continue
  var anchor := Shapes.placement_position(placement)
  var local_point := grid_point - Vector2(anchor)
  var points: PackedVector2Array = Shapes.transformed_points(placement)
  var closed: bool = definition.get("closed", false)
  if closed and points.size() >= 3 and Geometry2D.is_point_in_polygon(local_point, points):
   hits.append(index)
   continue
  var segment_count := points.size() if closed else points.size() - 1
  for segment in range(segment_count):
   var nearest := Geometry2D.get_closest_point_to_segment(local_point, points[segment], points[(segment + 1) % points.size()])
   if nearest.distance_to(local_point) <= tolerance:
    hits.append(index)
    break
 return hits


func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO, size), Color("0b1320"))
 if document == null:
  return
 _draw_gutter()
 _draw_grid()
 var placements := _placements()
 for index in placements.size():
  var placement: Dictionary = placements[index]
  if index == _drag_index and _drag_moved:
   placement = placement.duplicate(true)
   Shapes.set_placement_position(placement, _drag_anchor)
  _draw_piece(placement, false, false)
 for index in selected_indices:
  if index < 0 or index >= placements.size():
   continue
  var selected: Dictionary = placements[index].duplicate(true)
  if index == _drag_index and _drag_moved:
   Shapes.set_placement_position(selected, _drag_anchor)
  _draw_piece(selected, true, false)
  _draw_footprint(selected, Color(SELECTION_COLOR, 0.55))
 var active_brush := _drop_brush if not _drop_brush.is_empty() else brush
 if not preview_active and (_hovering or not _drop_brush.is_empty()) and _inside_grid(_cursor_position) and _valid_stamp(active_brush):
  var ghost := active_brush.duplicate(true)
  Shapes.set_placement_position(ghost, legal_anchor_for(ghost, screen_to_grid(_cursor_position), _alt_held))
  _draw_piece(ghost, false, true)
  _draw_footprint(ghost, Color(0.75, 0.91, 1.0, 0.5))
 _draw_gameplay_objects()
 _draw_rings()
 _draw_decor()
 _draw_markers()
 _draw_connectors()
 _draw_composite_preview()
 _draw_smoothing_corners()


func _draw_smoothing_corners() -> void:
 if not preview_active: return
 for index in _smoothing_corners.size():
  var point := grid_to_screen(_smoothing_corners[index])
  var pinned := _protected_corners.has(_smoothing_corner_indices[index])
  var color := Color("ff93c9") if pinned else Color("c5f5ff")
  draw_circle(point, 6.0, Color("131923"))
  draw_circle(point, 4.5, color, pinned, -1.0 if pinned else 1.5, true)
  if pinned:
   draw_line(point + Vector2(-2, 0), point + Vector2(2, 0), Color("131923"), 1.5, true)


func _draw_composite_preview() -> void:
 if not preview_active or composite_preview.is_empty():
  return
 var points: PackedVector2Array = Shapes.transformed_points(composite_preview)
 if points.size() < 3:
  return
 var anchor := Shapes.placement_position(composite_preview)
 for index in points.size():
  points[index] = grid_to_screen(points[index] + anchor)
 draw_colored_polygon(points, Color(COMPOSITE_PREVIEW_COLOR, 0.32))
 points.append(points[0])
 # The contrasting halo exposes the exact collision contour over every layer.
 draw_polyline(points, Color("131923"), 7.0, true)
 draw_polyline(points, COMPOSITE_PREVIEW_COLOR, 3.0, true)


func _draw_rings() -> void:
 for index in document.ring_trails.size():
  var trail: Dictionary = _ring_preview if _ring_index == index and not _ring_mode.is_empty() else document.ring_trails[index]
  _draw_ring_trail(trail, index == selected_ring_index, false)
 if _ring_mode == "create":
  _draw_ring_trail(_ring_preview, true, true)
 elif ring_tool and _hovering and _inside_grid(_cursor_position):
  var point := legal_gameplay_position(screen_to_local_pixels(_cursor_position), _alt_held)
  var pattern := {"start": point, "end": point, "spacing": ring_spacing_cells * _local_cell_size()}
  if ring_kind == "ellipse": pattern.merge({"kind": "ellipse", "end": point + ring_radii * 2.0, "fill": ring_fill, "rotation_degrees": ring_rotation}, true)
  _draw_ring_trail(pattern, false, true)

func _draw_ring_trail(trail: Dictionary, selected: bool, ghost: bool) -> void:
 var color := Color("ffd95e")
 if ghost: color.a = 0.6
 for point: Vector2 in Rings.positions(trail):
  draw_arc(local_pixels_to_screen(point), PreviewDimensions.RING_RADIUS_CELLS * _cell_pixels, 0, TAU, 24, color, 1.5, true)
 if selected:
  var start := local_pixels_to_screen(trail.start)
  var end := local_pixels_to_screen(trail.end)
  draw_line(start, end, Color(color, 0.3), 1.0, true)
  if trail.get("kind") == "ellipse":
   var outline := PackedVector2Array()
   var center: Vector2 = (trail.start + trail.end) * 0.5
   var radii: Vector2 = (trail.end - trail.start).abs() * 0.5
   for i in 65:
    outline.append(local_pixels_to_screen(center + (Vector2.from_angle(TAU * i / 64.0) * radii).rotated(deg_to_rad(float(trail.rotation_degrees)))))
   draw_polyline(outline, Color(color, 0.35), 1.0, true)
  var radius := clampf(PreviewDimensions.RING_HANDLE_RADIUS_CELLS * _cell_pixels, 2.0, 5.0)
  for point: Vector2 in [start, end]:
   draw_rect(Rect2(point - Vector2.ONE * radius, Vector2.ONE * radius * 2), Color("fff0b0"), false, 1.0)

func _begin_ring_drag(index: int, pointer: Vector2, mode: String) -> void:
 _ring_index = index
 _ring_mode = mode
 _ring_start_pointer = screen_to_local_pixels(pointer)
 _ring_last_pointer = pointer
 _ring_moved = false
 if mode == "create":
  var point := legal_gameplay_position(_ring_start_pointer, _alt_held)
  _ring_original = {"start": point, "end": point, "spacing": ring_spacing_cells * _local_cell_size()}
  if ring_kind == "ellipse":
   _ring_original.merge({"kind": "ellipse", "end": point + ring_radii * 2.0, "fill": ring_fill, "rotation_degrees": ring_rotation}, true)
 else:
  _ring_original = document.ring_trails[index].duplicate(true)
 _ring_preview = _ring_original.duplicate(true)
 queue_redraw()

func _update_ring_drag(pointer: Vector2, free_move: bool, force: bool = false) -> void:
 if not force and pointer.distance_squared_to(_ring_last_pointer) <= POINTER_JITTER_PIXELS * POINTER_JITTER_PIXELS:
  return
 _ring_last_pointer = pointer
 var delta := screen_to_local_pixels(pointer) - _ring_start_pointer
 if not _ring_moved and delta.length() * _cell_pixels / _local_cell_size() < 3.0:
  return
 _ring_moved = true
 _pending_cycle_target = {}
 _ring_preview = _ring_original.duplicate(true)
 if _ring_mode == "move":
  # Snap only the translated start; preserve the complete trail's relative shape.
  var offset := legal_gameplay_position(_ring_original.start + delta, free_move) - Vector2(_ring_original.start)
  _ring_preview.start += offset
  _ring_preview.end += offset
 elif _ring_mode == "create":
  _ring_preview.end = legal_gameplay_position(screen_to_local_pixels(pointer), free_move)
 else:
  _ring_preview[_ring_mode] = legal_gameplay_position(_ring_original[_ring_mode] + delta, free_move)
 _set_status("%d rings · Release for one edit · Alt frees endpoints · Esc cancels" % Rings.positions(_ring_preview).size())
 queue_redraw()

func _end_ring_drag() -> void:
 var index := _ring_index
 var trail := _ring_preview.duplicate(true)
 var changed := _ring_mode == "create" or (_ring_moved and trail != _ring_original)
 _ring_mode = ""
 _ring_index = -1
 if changed:
  ring_requested.emit(index, trail)
 _finish_cycle_click()
 queue_redraw()

func _draw_gutter() -> void:
 var local_bounds: Rect2 = document.red_gutter_bounds()
 var bounds := Rect2(local_pixels_to_screen(local_bounds.position), local_bounds.size * _cell_pixels / _local_cell_size())
 draw_rect(bounds, Color(0.67, 0.12, 0.20, 0.23))
 draw_rect(bounds, Color("ad4b60"), false, 1.5)
 var label := "SYSTEM DRAIN / TRANSITION ZONE · NOT TERRAIN"
 var font := get_theme_default_font()
 var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
 var label_x := clampf(bounds.get_center().x - width * 0.5, 8.0, maxf(8.0, size.x - width - 8.0))
 draw_string(font, Vector2(label_x, bounds.end.y + 19.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("ef94a7"))


func _draw_markers() -> void:
 for kind: String in ["activation", "spawn"]:
  var value: Variant = marker_value(kind)
  if value == null:
   continue
  if _marker_drag_kind == kind and _marker_drag_moved:
   if not valid_marker_value(kind, _marker_drag_value):
    _draw_marker(kind, value, false, true)
   _draw_marker(kind, _marker_drag_value, true, true, valid_marker_value(kind, _marker_drag_value))
  else:
   _draw_marker(kind, value, selected_marker == kind, false)
 if _hovering and not marker_tool.is_empty():
  var value: Variant = _marker_position_value(marker_tool, screen_to_local_pixels(_cursor_position), _alt_held)
  _draw_marker(marker_tool, value, false, true, _inside_grid(_cursor_position) and valid_marker_value(marker_tool, value))


func _draw_marker(kind: String, value: Variant, selected: bool, ghost: bool, valid: bool = true) -> void:
 var color := ACTIVATION_COLOR if kind == "activation" else SPAWN_COLOR
 if not valid:
  color = INVALID_MARKER_COLOR
 color.a = 0.65 if ghost else 1.0
 var font := get_theme_default_font()
 var unit := PreviewDimensions.marker_unit(_cell_pixels)
 if kind == "activation":
  var start := local_pixels_to_screen(Vector2(0, float(value)))
  var end := local_pixels_to_screen(Vector2(document.terrain_bounds().size.x, float(value)))
  start.x = maxf(start.x, 0.0)
  end.x = minf(end.x, size.x)
  if start.x >= end.x or start.y < -30.0 or start.y > size.y + 30.0:
   return
  if selected:
   draw_line(start, end, Color(color, 0.16), PreviewDimensions.SELECTED_OUTLINE_PIXELS * 2.0, true)
  _draw_dashes(start, end, color, PreviewDimensions.SELECTED_OUTLINE_PIXELS if selected else PreviewDimensions.OUTLINE_PIXELS)
  var arrow := Vector2(lerpf(start.x, end.x, 0.75), start.y)
  _draw_marker_arrow(arrow, unit, color)
  var label := "ACTIVATION · CROSS UP"
  var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
  draw_rect(Rect2(start + Vector2(8, -24), Vector2(label_width + 8, 17)), Color(0.04, 0.09, 0.13, 0.9))
  draw_string(font, start + Vector2(12, -11), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)
 else:
  var point := local_pixels_to_screen(value)
  var radius := PreviewDimensions.SPAWN_RADIUS_CELLS * unit
  var crosshair := PreviewDimensions.CROSSHAIR_RADIUS_CELLS * unit
  if selected:
   draw_circle(point, radius + PreviewDimensions.SELECTED_OUTLINE_PIXELS, Color(color, 0.22))
  draw_circle(point, radius, Color("192031"))
  draw_arc(point, radius, 0, TAU, 32, color, PreviewDimensions.OUTLINE_PIXELS, true)
  draw_line(point + Vector2(-crosshair, 0), point + Vector2(crosshair, 0), color, 1.0, true)
  draw_line(point + Vector2(0, -crosshair), point + Vector2(0, crosshair), color, 1.0, true)
  draw_circle(point, maxf(1.0, PreviewDimensions.PIVOT_RADIUS_CELLS * unit), Color.WHITE)
  var arrow_center := point - Vector2(0, radius + PreviewDimensions.ARROW_LENGTH_CELLS * unit * 0.5 + 2.0)
  _draw_marker_arrow(arrow_center, unit, color)
  draw_string(font, point + Vector2(radius + PreviewDimensions.LABEL_GAP_PIXELS, 4), "SPAWN", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)


func _draw_marker_arrow(center: Vector2, unit: float, color: Color) -> void:
 var half_length := PreviewDimensions.ARROW_LENGTH_CELLS * unit * 0.5
 var head := PreviewDimensions.ARROW_HEAD_CELLS * unit
 var tip := center - Vector2(0, half_length)
 draw_line(center + Vector2(0, half_length), tip, color, PreviewDimensions.OUTLINE_PIXELS, true)
 draw_line(tip, tip + Vector2(-head, head), color, PreviewDimensions.OUTLINE_PIXELS, true)
 draw_line(tip, tip + Vector2(head, head), color, PreviewDimensions.OUTLINE_PIXELS, true)


func _draw_gameplay_objects() -> void:
 var objects := _gameplay_objects()
 var scale_factor := _cell_pixels / _local_cell_size()
 for index in objects.size():
  var placement: Dictionary = objects[index]
  var point: Vector2 = placement.position
  if index == _gameplay_drag_index and _gameplay_drag_moved:
   point = _gameplay_drag_position
  ObjectPreview.draw_object(self, placement, local_pixels_to_screen(point), scale_factor, _local_cell_size(), selected_gameplay_indices.has(index))
  if placement.type == "spring" and selected_gameplay_indices.has(index): _draw_spring_trajectory(placement)
 if selected_gameplay_index >= 0 and selected_gameplay_index < objects.size():
  var placement: Dictionary = objects[selected_gameplay_index]
  var point: Vector2 = _gameplay_drag_position if selected_gameplay_index == _gameplay_drag_index and _gameplay_drag_moved else placement.position
  var shown := placement.duplicate(true)
  if _rail_drag >= 0: shown.properties.points = _rail_preview
  ObjectPreview.draw_object(self, shown, local_pixels_to_screen(point), scale_factor, _local_cell_size(), true)
 if not _rail_draft.is_empty():
  ObjectPreview.draw_object(self, _rail_draft, local_pixels_to_screen(_rail_draft.position), scale_factor, _local_cell_size(), true, true)
 var active_brush := _drop_gameplay_brush if not _drop_gameplay_brush.is_empty() else gameplay_brush
 if _rail_draft.is_empty() and (_hovering or not _drop_gameplay_brush.is_empty()) and _inside_grid(_cursor_position) and _valid_gameplay_stamp(active_brush):
  var point := legal_gameplay_position(screen_to_local_pixels(_cursor_position), _alt_held)
  ObjectPreview.draw_object(self, active_brush, local_pixels_to_screen(point), scale_factor, _local_cell_size(), false, true)
  if active_brush.type == "spring":
   var shown := active_brush.duplicate(true)
   shown.position = point
   _draw_spring_trajectory(shown)
 _draw_bank_links()

func _draw_spring_trajectory(item: Dictionary) -> void:
 var points := Objects.spring_trajectory(item, trajectory_gravity_scale, Objects.Dimensions.BALL_RADIUS_CELLS * _local_cell_size())
 for i in points.size(): points[i] = local_pixels_to_screen(points[i])
 draw_polyline(points, Color(1.0, 0.8, 0.3, 0.65), 1.5, true)
 for i in range(0, points.size(), 10): draw_circle(points[i], 2.5, Color("ffd24e"))

func _draw_bank_links() -> void:
 var positions := {}
 for i in document.gameplay_objects.size():
  positions[Objects.identity(document.gameplay_objects[i], i)] = local_pixels_to_screen(document.gameplay_objects[i].position)
 for bank: Dictionary in document.switch_banks:
  var center := Vector2.ZERO
  for id: String in bank.members: center += Vector2(positions.get(id, Vector2.ZERO))
  center /= maxf(1.0, bank.members.size())
  for id: String in bank.members:
   if positions.has(id): _draw_dashes(positions[id], center, Color(0.5, 0.8, 1.0, 0.5))
  for id: String in bank.gates:
   if positions.has(id):
    _draw_dashes(center, positions[id], Color(0.5, 0.8, 1.0, 0.5))
    ObjectPreview._arrow(self, center.lerp(positions[id], 0.8), positions[id], Color("81caff"))
  draw_string(ThemeDB.fallback_font, center + Vector2(7, -10), bank.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("81caff"))


func _draw_connectors() -> void:
 for kind: String in ["entry", "exit"]:
  var span := connector_span(kind)
  if span.y > 0 and _connector_drag_kind != kind:
   _draw_connector(kind, span.x, span.y, selected_connector == kind, false)
 if not _connector_drag_kind.is_empty():
  _draw_connector(_connector_drag_kind, _connector_preview_start, _connector_preview_width, true, true)
 elif _hovering and not connector_tool.is_empty() and connector_border_at(_cursor_position) == connector_tool:
  var cell := clampi(floori(screen_to_grid(_cursor_position).x), 0, _grid_size().x - 1)
  _draw_connector(connector_tool, cell, 1, false, true, false)


func _draw_connector(kind: String, start_x: int, width: int, selected: bool, ghost: bool, show_label: bool = true) -> void:
 if width <= 0:
  return
 var start := grid_to_screen(Vector2(start_x, _connector_row(kind)))
 var end := grid_to_screen(Vector2(start_x + width, _connector_row(kind)))
 var color := Color(CONNECTOR_COLOR, 0.48 if ghost else 1.0)
 var unit := PreviewDimensions.marker_unit(_cell_pixels)
 var handle := PreviewDimensions.CONNECTOR_HANDLE_CELLS * unit
 if selected:
  draw_line(start, end, Color("d1ffe2"), PreviewDimensions.SELECTED_OUTLINE_PIXELS * 2.0, true)
 draw_line(start, end, Color("123c30"), PreviewDimensions.SELECTED_OUTLINE_PIXELS + 1.0, true)
 draw_line(start, end, color, PreviewDimensions.OUTLINE_PIXELS + 1.0, true)
 for point: Vector2 in [start, end]:
  draw_line(point - Vector2(0, handle), point + Vector2(0, handle), color, PreviewDimensions.OUTLINE_PIXELS, true)
  if selected:
   draw_rect(Rect2(point - Vector2.ONE * handle, Vector2.ONE * handle * 2.0), Color("d1ffe2"))
   draw_rect(Rect2(point - Vector2.ONE * handle * 0.5, Vector2.ONE * handle), color)
 # Both annotations point upward: Entry into the Act; Exit out of the Act.
 var center := (start + end) * 0.5
 _draw_marker_arrow(center, unit, color)
 if not show_label:
  return
 var font := get_theme_default_font()
 var label := "%s · %d %s" % [kind.to_upper(), width, "cell" if width == 1 else "cells"]
 var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
 var label_x := clampf(center.x - text_width * 0.5, 8.0, maxf(8.0, size.x - text_width - 8.0))
 var label_y := start.y + (26.0 if kind == "entry" else -29.0)
 draw_string(font, Vector2(label_x, label_y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)


func _connector_row(kind: String) -> int:
 return _grid_size().y if kind == "entry" else 0


func _draw_grid() -> void:
 var dimensions := _grid_size()
 var bounds := Rect2(_view_origin, Vector2(dimensions) * _cell_pixels)
 var viewport_bounds := Rect2(Vector2.ZERO, size)
 if not bounds.intersects(viewport_bounds):
  return
 var visible_bounds := bounds.intersection(viewport_bounds)
 draw_rect(visible_bounds, Color("101f30"))
 var visible_start := screen_to_grid(visible_bounds.position)
 var visible_end := screen_to_grid(visible_bounds.end)
 # Bound work by visible pixels rather than the saved document's dimensions.
 # At low zoom, major lines remain readable without painting subpixel grids.
 var line_step := maxi(1, ceili(12.0 / _cell_pixels))
 var first_x := clampi(floori(visible_start.x / line_step) * line_step, 0, dimensions.x)
 var first_y := clampi(floori(visible_start.y / line_step) * line_step, 0, dimensions.y)
 var last_x := clampi(ceili(visible_end.x), 0, dimensions.x)
 var last_y := clampi(ceili(visible_end.y), 0, dimensions.y)
 if terrain_snap_step == 0.5 and _cell_pixels >= 24.0:
  for x in range(maxi(0, floori(visible_start.x)), last_x):
   var screen_x := grid_to_screen(Vector2(x + 0.5, 0)).x
   draw_line(Vector2(screen_x, visible_bounds.position.y), Vector2(screen_x, visible_bounds.end.y), Color("1d2c3e"), 1.0)
  for y in range(maxi(0, floori(visible_start.y)), last_y):
   var screen_y := grid_to_screen(Vector2(0, y + 0.5)).y
   draw_line(Vector2(visible_bounds.position.x, screen_y), Vector2(visible_bounds.end.x, screen_y), Color("1d2c3e"), 1.0)
 for x in range(first_x, last_x + 1, line_step):
  var screen_x := grid_to_screen(Vector2(x, 0)).x
  draw_line(Vector2(screen_x, visible_bounds.position.y), Vector2(screen_x, visible_bounds.end.y), Color("2b3d51"), 1.0, true)
 for y in range(first_y, last_y + 1, line_step):
  var screen_y := grid_to_screen(Vector2(0, y)).y
  draw_line(Vector2(visible_bounds.position.x, screen_y), Vector2(visible_bounds.end.x, screen_y), Color("2b3d51"), 1.0, true)
 draw_rect(bounds, Color("65869a"), false, 2.0)
 var font := get_theme_default_font()
 var label_color := Color("8fa9bc")
 var widest_label := font.get_string_size(str(maxi(dimensions.x, dimensions.y)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
 var label_step := maxi(1, ceili(maxf(22.0, widest_label + 8.0) / _cell_pixels))
 first_x = clampi(floori(visible_start.x / label_step) * label_step, 0, dimensions.x)
 first_y = clampi(floori(visible_start.y / label_step) * label_step, 0, dimensions.y)
 for x in range(first_x, mini(last_x + 1, dimensions.x), label_step):
  var label := str(x)
  var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
  var point := grid_to_screen(Vector2(x + 0.5, 0)) + Vector2(-width * 0.5, -10)
  draw_string(font, point, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, label_color)
 for y in range(first_y, mini(last_y + 1, dimensions.y), label_step):
  var label := str(y)
  var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
  var point := grid_to_screen(Vector2(0, y + 0.5)) + Vector2(-width - 11, 4)
  draw_string(font, point, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, label_color)
 draw_string(font, _view_origin + Vector2(-25, -11), "X/Y", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, label_color)


func _draw_piece(placement: Dictionary, selected: bool, ghost: bool) -> void:
 var definition: Dictionary = Shapes.definition_for_placement(placement)
 if definition.is_empty():
  return
 var points: PackedVector2Array = Shapes.transformed_points(placement)
 var anchor := Shapes.placement_position(placement)
 for point_index in points.size():
  points[point_index] = grid_to_screen(points[point_index] + Vector2(anchor))
 if points.size() < 2:
  return
 var color: Color = definition.get("color", Color("7bc8e8"))
 var closed: bool = definition.get("closed", false)
 if closed and points.size() >= 3:
  var fill_alpha := 0.18 if ghost else (0.2 if selected else 0.42)
  draw_colored_polygon(points, Color(color, fill_alpha))
  points.append(points[0])
 if selected:
  draw_polyline(points, SELECTION_COLOR, 6.0, true)
 var outline := Color(color, 0.8 if ghost else 1.0)
 draw_polyline(points, outline, 2.5 if closed else 3.5, true)
 if not closed:
  draw_circle(points[0], 2.5, outline)
  draw_circle(points[points.size() - 1], 2.5, outline)


func _draw_footprint(placement: Dictionary, color: Color) -> void:
 var anchor := Shapes.placement_position(placement)
 var footprint := Shapes.scaled_size(placement)
 var top_left := grid_to_screen(Vector2(anchor))
 var bottom_right := grid_to_screen(Vector2(anchor + footprint))
 var top_right := Vector2(bottom_right.x, top_left.y)
 var bottom_left := Vector2(top_left.x, bottom_right.y)
 _draw_dashes(top_left, top_right, color)
 _draw_dashes(top_right, bottom_right, color)
 _draw_dashes(bottom_right, bottom_left, color)
 _draw_dashes(bottom_left, top_left, color)
 draw_circle(top_left, 3.0, color)


func _draw_dashes(from: Vector2, to: Vector2, color: Color, width: float = 1.0) -> void:
 var length := from.distance_to(to)
 if length < 0.01:
  return
 var direction := (to - from) / length
 var distance := 0.0
 while distance < length:
  draw_line(from + direction * distance, from + direction * minf(distance + 5.0, length), color, width, true)
  distance += 10.0


func _input(event: InputEvent) -> void:
 # Drag-and-drop can bypass _gui_input, so retain the modifiers from the
 # actual event before Godot asks this control to accept or commit a drop.
 if event is InputEventKey and event.keycode == KEY_ALT:
  _alt_held = event.pressed
 elif event is InputEventMouse:
  _alt_held = event.alt_pressed
 else:
  return
 if not _drop_gameplay_brush.is_empty():
  queue_redraw()


func _gui_input(event: InputEvent) -> void:
 if _rail_input(event):
  accept_event()
  return
 if document == null:
  return
 if preview_active:
  _composite_preview_input(event)
  return
 if event is InputEventKey and event.keycode == KEY_ALT:
  _alt_held = event.pressed
  if not _ring_mode.is_empty():
   if _alt_held and _ring_moved: _update_ring_drag(_cursor_position, true, true)
  elif not _marker_drag_kind.is_empty():
   if _alt_held and _marker_drag_moved:
    _update_marker_drag(_cursor_position, true, true)
   else:
    _set_marker_status(_marker_drag_kind, _marker_drag_value)
  elif not marker_tool.is_empty():
   _set_marker_status(marker_tool, _marker_position_value(marker_tool, screen_to_local_pixels(_cursor_position), _alt_held))
  elif _alt_held and _gameplay_drag_index >= 0 and _gameplay_drag_moved:
   _update_gameplay_drag(_cursor_position, true, true)
  elif _gameplay_drag_index >= 0:
   _set_gameplay_status(_gameplay_drag_position)
  elif not gameplay_brush.is_empty():
   _set_gameplay_status(legal_gameplay_position(screen_to_local_pixels(_cursor_position), _alt_held))
  queue_redraw()
  accept_event()
 elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
  _leave_tool()
  accept_event()
 elif event is InputEventKey and event.pressed and not event.ctrl_pressed and not event.meta_pressed and event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
  # Consume arrows before Control's built-in focus navigation. The owner still
  # applies the edit through the same move signal as pointer dragging.
  if not event.echo and selected_decor_index >= 0:
   cancel_gesture()
   var direction: Vector2 = {KEY_LEFT: Vector2.LEFT, KEY_RIGHT: Vector2.RIGHT, KEY_UP: Vector2.UP, KEY_DOWN: Vector2.DOWN}[event.keycode]
   var slot: Dictionary = document.decor_slots[selected_decor_index].duplicate(true)
   slot.position += direction * (1.0 if event.alt_pressed or not decor_snap else _local_cell_size())
   decor_requested.emit(selected_decor_index, slot)
  elif not event.echo and selected_ring_index >= 0:
   cancel_gesture()
   var direction: Vector2 = {KEY_LEFT: Vector2.LEFT, KEY_RIGHT: Vector2.RIGHT, KEY_UP: Vector2.UP, KEY_DOWN: Vector2.DOWN}[event.keycode]
   var offset := direction * (1.0 if event.alt_pressed else _local_cell_size())
   var trail: Dictionary = document.ring_trails[selected_ring_index].duplicate(true)
   trail.start += offset
   trail.end += offset
   ring_requested.emit(selected_ring_index, trail)
  elif not event.echo and not selected_marker.is_empty():
   cancel_gesture()
   var direction: Vector2 = {KEY_LEFT: Vector2.LEFT, KEY_RIGHT: Vector2.RIGHT, KEY_UP: Vector2.UP, KEY_DOWN: Vector2.DOWN}[event.keycode]
   var distance := 1.0 if event.alt_pressed else _local_cell_size()
   var value: Variant = marker_value(selected_marker)
   if selected_marker == "spawn":
    _request_marker(selected_marker, value + direction * distance)
   elif direction.y != 0.0:
    _request_marker(selected_marker, float(value) + direction.y * distance)
  elif not event.echo and selected_gameplay_index >= 0 and selected_gameplay_index < _gameplay_objects().size():
   cancel_gesture()
   var direction: Vector2 = {KEY_LEFT: Vector2.LEFT, KEY_RIGHT: Vector2.RIGHT, KEY_UP: Vector2.UP, KEY_DOWN: Vector2.DOWN}[event.keycode]
   var point: Vector2 = _gameplay_objects()[selected_gameplay_index].position
   var distance := 1.0 if event.alt_pressed else _local_cell_size()
   gameplay_move_requested.emit(selected_gameplay_index, point + direction * distance)
  elif not event.echo and not selected_connector.is_empty():
   if event.keycode in [KEY_LEFT, KEY_RIGHT]:
    cancel_gesture()
    var span := connector_span(selected_connector)
    var offset := -1 if event.keycode == KEY_LEFT else 1
    var start_x := clampi(span.x + offset, 0, _grid_size().x - span.y)
    if start_x != span.x and span.y > 0:
     connector_requested.emit(selected_connector, start_x, span.y)
  elif not event.echo and selected_indices.size() == 1 and selected_index >= 0 and selected_index < _placements().size():
   var direction: Vector2i = {KEY_LEFT: Vector2i.LEFT, KEY_RIGHT: Vector2i.RIGHT, KEY_UP: Vector2i.UP, KEY_DOWN: Vector2i.DOWN}[event.keycode]
   var placement: Dictionary = _placements()[selected_index]
   var anchor := Shapes.placement_position(placement)
   var distance := 1.0 / _local_cell_size() if event.alt_pressed else terrain_snap_step
   move_requested.emit(selected_index, legal_anchor_for(placement, anchor + Vector2(direction) * distance, true))
  accept_event()
 elif event is InputEventMouseButton:
  _cursor_position = event.position
  _alt_held = event.alt_pressed
  if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
   _leave_tool()
   accept_event()
  elif event.button_index == MOUSE_BUTTON_MIDDLE:
   _panning = event.pressed
   if _panning:
    grab_focus()
   accept_event()
  elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
   _zoom_at(event.position, 1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12)
   accept_event()
  elif event.button_index == MOUSE_BUTTON_LEFT:
   if event.pressed:
    grab_focus()
    _begin_primary(event.position, event.alt_pressed, event.ctrl_pressed or event.meta_pressed)
   else:
    if not _ring_mode.is_empty():
     _update_ring_drag(event.position, event.alt_pressed)
    elif not _marker_drag_kind.is_empty():
     if event.position.distance_squared_to(_marker_drag_last_pointer) > POINTER_JITTER_PIXELS * POINTER_JITTER_PIXELS:
      _update_marker_drag(event.position, event.alt_pressed)
    elif _gameplay_drag_index >= 0:
     # A modifier release alone must not quantize the last free preview.
     if event.position.distance_squared_to(_gameplay_drag_last_pointer) > POINTER_JITTER_PIXELS * POINTER_JITTER_PIXELS:
      _update_gameplay_drag(event.position, event.alt_pressed)
    elif not _connector_drag_kind.is_empty():
     _update_connector_drag(event.position)
    elif _drag_index >= 0:
     _update_drag(event.position, event.alt_pressed)
    _end_primary()
   accept_event()
 elif event is InputEventMouseMotion:
  _cursor_position = event.position
  _alt_held = event.alt_pressed
  if _panning:
   _view_origin += event.relative
   _view_adjusted = true
  elif _decor_drag_index >= 0:
   _update_decor_drag(event.position, event.alt_pressed)
  elif not _ring_mode.is_empty():
   _update_ring_drag(event.position, event.alt_pressed)
  elif not _marker_drag_kind.is_empty():
   _update_marker_drag(event.position, event.alt_pressed)
  elif _gameplay_drag_index >= 0:
   _update_gameplay_drag(event.position, event.alt_pressed)
  elif not _connector_drag_kind.is_empty():
   _update_connector_drag(event.position)
  elif _drag_index >= 0:
   _update_drag(event.position, event.alt_pressed)
  elif not marker_tool.is_empty():
   _set_marker_status(marker_tool, _marker_position_value(marker_tool, screen_to_local_pixels(event.position), event.alt_pressed), _inside_grid(event.position))
  elif not gameplay_brush.is_empty() and _inside_grid(event.position):
   _set_gameplay_status(legal_gameplay_position(screen_to_local_pixels(event.position), event.alt_pressed))
  elif not connector_tool.is_empty():
   var border := "bottom" if connector_tool == "entry" else "top"
   if connector_border_at(event.position) == connector_tool:
    _set_status("%s: click or drag contiguous %s-border cells. Esc cancels." % [connector_tool.capitalize(), border])
   else:
    _set_status("%s belongs on the %s border. Click or drag there to define its span." % [connector_tool.capitalize(), border])
  elif not brush.is_empty() and _inside_grid(event.position):
   var anchor := legal_anchor_for(brush, screen_to_grid(event.position), event.alt_pressed)
   _set_status("Place at %s cells. Alt: free position; right-click or Esc to select." % anchor)
  queue_redraw()
  accept_event()


func _composite_preview_input(event: InputEvent) -> void:
 # Only preview corner protection changes here; the document remains untouched.
 # Handles stay usable even when smoothing validation rejects the current result.
 if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
  composite_preview_cancel_requested.emit()
 elif event is InputEventMouseButton:
  if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
   composite_preview_cancel_requested.emit()
  elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not _panning:
   var corner := smoothing_corner_at(event.position)
   if corner >= 0: composite_corner_toggled.emit(corner)
  elif event.button_index == MOUSE_BUTTON_MIDDLE:
   _panning = event.pressed
   if _panning:
    grab_focus()
  elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
   _zoom_at(event.position, 1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12)
 elif event is InputEventMouseMotion and _panning:
  _view_origin += event.relative
  _view_adjusted = true
  queue_redraw()
 accept_event()


func _begin_primary(pointer: Vector2, cycle_overlaps: bool, toggle_terrain: bool = false) -> void:
 if preview_active:
  return
 if not decor_brush.is_empty():
  if _inside_grid(pointer):
   var slot := decor_brush.duplicate(true)
   slot.position = decor_position(screen_to_local_pixels(pointer), cycle_overlaps)
   decor_requested.emit(-1, slot)
  return
 if ring_tool:
  if _inside_grid(pointer): _begin_ring_drag(-1, pointer, "create")
  return
 if not marker_tool.is_empty():
  var value: Variant = _marker_position_value(marker_tool, screen_to_local_pixels(pointer), cycle_overlaps)
  if _inside_grid(pointer):
   _request_marker(marker_tool, value)
  else:
   _set_marker_status(marker_tool, value, false)
  return
 if not connector_tool.is_empty():
  if connector_border_at(pointer) == connector_tool:
   _begin_connector_drag(connector_tool, pointer, "create")
  else:
   var border := "bottom" if connector_tool == "entry" else "top"
   _set_status("%s can only be created on the %s border." % [connector_tool.capitalize(), border])
  return
 if gameplay_brush.get("type") == "elevated_rail":
  if _inside_grid(pointer):
   var at := legal_gameplay_position(screen_to_local_pixels(pointer), cycle_overlaps)
   if _rail_draft.is_empty():
    _rail_draft = gameplay_brush.duplicate(true)
    _rail_draft.position = at
    _rail_draft.properties = Objects.properties(gameplay_brush)
    _rail_draft.properties.points = PackedVector2Array([Vector2.ZERO])
   else:
    var point := (at - Vector2(_rail_draft.position)).rotated(-deg_to_rad(float(_rail_draft.rotation_degrees)))
    if point.distance_to(_rail_draft.properties.points[-1]) >= 12.0 and _rail_draft.properties.points.size() < 64:
     _rail_draft.properties.points.append(point)
   queue_redraw()
  return
 if not gameplay_brush.is_empty():
  if _inside_grid(pointer) and _valid_gameplay_stamp(gameplay_brush):
   var placement := gameplay_brush.duplicate(true)
   placement["position"] = legal_gameplay_position(screen_to_local_pixels(pointer), cycle_overlaps)
   gameplay_placement_requested.emit(placement)
  return
 if not brush.is_empty():
  if _inside_grid(pointer) and _valid_stamp(brush):
   var placement := brush.duplicate(true)
   Shapes.set_placement_position(placement, legal_anchor_for(placement, screen_to_grid(pointer), cycle_overlaps))
   placement_requested.emit(placement)
  return
 # Alt-click preserves access to terrain that shares a connector's border.
 var connector := "" if cycle_overlaps else connector_hit_at(pointer)
 if not connector.is_empty():
  select_connector(connector)
  _emit_selection_changed()
  _begin_connector_drag(connector, pointer, connector_handle_at(connector, pointer))
  return
 var hits := mixed_hit_indices_at(pointer)
 var current_slot := -1
 for slot in hits.size():
  var hit: Dictionary = hits[slot]
  if (hit.kind == "decor" and hit.index == selected_decor_index) or (hit.kind == "ring" and hit.index == selected_ring_index) or (hit.kind == "marker" and hit.marker == selected_marker) or (hit.kind == "gameplay" and hit.index == selected_gameplay_index) or (hit.kind == "terrain" and hit.index == selected_index):
   current_slot = slot
   break
 var target: Dictionary = {}
 var click_target: Dictionary = {}
 if not hits.is_empty():
  target = hits[0]
  if cycle_overlaps:
   # Resolve Alt-click only on release. An Alt-drag keeps the already-selected
   # object, allowing fine movement even when terrain lies beneath it.
   if current_slot >= 0:
    target = hits[current_slot]
    click_target = hits[(current_slot + 1) % hits.size()]
   else:
    click_target = hits[0]
 if toggle_terrain:
  if cycle_overlaps and not click_target.is_empty():
   target = click_target
   click_target = {}
  if target.get("kind") == "gameplay":
   var indices: Array[int] = selected_gameplay_indices.duplicate()
   if indices.has(target.index): indices.erase(target.index)
   else: indices.append(target.index)
   set_gameplay_selection(indices)
   _emit_selection_changed()
   _set_status("%d gameplay objects selected. Select switches to create a bank." % indices.size())
   return
  if target.get("kind") == "terrain":
   var indices: Array[int] = selected_indices.duplicate()
   if indices.has(target.index):
    indices.erase(target.index)
   else:
    indices.append(target.index)
   set_terrain_selection(indices)
   _emit_selection_changed()
   _set_status("%d terrain pieces selected. Ctrl-click toggles; Ctrl+Alt-click reaches overlaps. Click empty space to clear." % selected_indices.size())
   return
 var ring_mode := "move"
 if target.get("kind") == "ring" and target.index == selected_ring_index:
  var trail: Dictionary = document.ring_trails[target.index]
  if trail.start != trail.end:
   if pointer.distance_to(local_pixels_to_screen(trail.start)) <= 6: ring_mode = "start"
   elif pointer.distance_to(local_pixels_to_screen(trail.end)) <= 6: ring_mode = "end"
 _select_hit_target(target)
 _pending_cycle_target = click_target
 if not target.is_empty():
  if target.kind == "decor":
   _decor_drag_index = target.index
   _decor_drag_start = screen_to_local_pixels(pointer)
   _decor_drag_original = document.decor_slots[target.index].position
   _decor_drag_position = _decor_drag_original
   _decor_drag_moved = false
  elif target.kind == "ring":
   _begin_ring_drag(target.index, pointer, ring_mode)
  elif target.kind == "marker":
   _begin_marker_drag(target.marker, pointer)
  elif target.kind == "gameplay":
   var placement: Dictionary = _gameplay_objects()[target.index]
   _gameplay_drag_index = target.index
   _gameplay_drag_start_pointer = screen_to_local_pixels(pointer)
   _gameplay_drag_start_position = placement.position
   _gameplay_drag_position = placement.position
   _gameplay_drag_last_pointer = pointer
   _gameplay_drag_moved = false
  else:
   var placement: Dictionary = _placements()[target.index]
   _drag_index = target.index
   _drag_start_pointer = screen_to_grid(pointer)
   _drag_start_anchor = Shapes.placement_position(placement)
   _drag_last_pointer = pointer
   _drag_anchor = _drag_start_anchor
   _drag_moved = false
  if hits.size() > 1:
   _set_status("%d overlapping items here. Alt-click cycles; Alt-drag freely moves gameplay objects and markers." % hits.size())
 queue_redraw()


func _select_hit_target(target: Dictionary) -> void:
 if target.is_empty():
  select_piece(-1)
 elif target.kind == "decor":
  select_decor(target.index)
 elif target.kind == "ring":
  select_ring(target.index)
 elif target.kind == "marker":
  select_marker(target.marker)
 elif target.kind == "gameplay":
  select_gameplay(target.index)
 else:
  select_piece(target.index)
 _emit_selection_changed()


func _emit_selection_changed() -> void:
 decor_selection_changed.emit(selected_decor_index)
 selection_changed.emit(selected_index)
 terrain_selection_changed.emit(selected_indices.duplicate())
 gameplay_selection_changed.emit(selected_gameplay_index)
 connector_selection_changed.emit(selected_connector)
 marker_selection_changed.emit(selected_marker)
 ring_selection_changed.emit(selected_ring_index)


func _finish_cycle_click() -> void:
 if _pending_cycle_target.is_empty():
  return
 var target := _pending_cycle_target
 _pending_cycle_target = {}
 _select_hit_target(target)


func _update_drag(pointer: Vector2, free_move: bool = false) -> void:
 var placements := _placements()
 if _drag_index >= placements.size():
  cancel_gesture()
  return
 if pointer.distance_squared_to(_drag_last_pointer) <= POINTER_JITTER_PIXELS * POINTER_JITTER_PIXELS:
  return
 _drag_last_pointer = pointer
 var delta := screen_to_grid(pointer) - _drag_start_pointer
 if not _drag_moved and delta.length() * _cell_pixels < 3.0:
  return
 _drag_moved = true
 _pending_cycle_target = {}
 _drag_anchor = legal_anchor_for(placements[_drag_index], _drag_start_anchor + delta, free_move)
 _set_status("Move to %s cells. Release to apply; Alt moves freely; Esc cancels." % _drag_anchor)


func _marker_position_value(kind: String, position: Vector2, free_move: bool) -> Variant:
 if kind == "activation":
  return float(position.y) if free_move else roundf(position.y / _local_cell_size()) * _local_cell_size()
 return legal_gameplay_position(position, free_move)


func _request_marker(kind: String, value: Variant) -> void:
 if not valid_marker_value(kind, value):
  _set_marker_status(kind, value)
  return
 marker_requested.emit(kind, value)


func _set_marker_status(kind: String, value: Variant, pointer_inside: bool = true) -> void:
 if not pointer_inside or not valid_marker_value(kind, value):
  _set_status("%s must stay inside the Act terrain bounds. The outer bottom/right edges and red gutter are outside; no edit applied." % kind.capitalize())
  return
 var mode := "FREE MOVE" if _alt_held else "SNAP ON"
 var coordinate := "Y %.2f px" % float(value) if kind == "activation" else "(%.2f, %.2f) px" % [value.x, value.y]
 _set_status("%s · %s %s · Alt frees position; Esc cancels. Activation moves vertically only." % [mode, kind.capitalize(), coordinate])


func _begin_marker_drag(kind: String, pointer: Vector2) -> void:
 _marker_drag_kind = kind
 _marker_drag_start_pointer = screen_to_local_pixels(pointer)
 _marker_drag_last_pointer = pointer
 _marker_drag_start_value = marker_value(kind)
 _marker_drag_value = _marker_drag_start_value
 _marker_drag_moved = false


func _update_marker_drag(pointer: Vector2, free_move: bool, force: bool = false) -> void:
 if _marker_drag_kind.is_empty() or marker_value(_marker_drag_kind) == null:
  cancel_gesture()
  return
 if not force and pointer.distance_squared_to(_marker_drag_last_pointer) <= POINTER_JITTER_PIXELS * POINTER_JITTER_PIXELS:
  return
 _marker_drag_last_pointer = pointer
 var delta := screen_to_local_pixels(pointer) - _marker_drag_start_pointer
 var movement := absf(delta.y) if _marker_drag_kind == "activation" else delta.length()
 if not _marker_drag_moved and movement * _cell_pixels / _local_cell_size() < 3.0:
  return
 _marker_drag_moved = true
 _pending_cycle_target = {}
 _alt_held = free_move
 if _marker_drag_kind == "activation":
  var y := float(_marker_drag_start_value) + delta.y
  _marker_drag_value = y if free_move else roundf(y / _local_cell_size()) * _local_cell_size()
 else:
  _marker_drag_value = legal_gameplay_position(_marker_drag_start_value + delta, free_move)
 _set_marker_status(_marker_drag_kind, _marker_drag_value)
 queue_redraw()


func _end_marker_drag() -> void:
 var kind := _marker_drag_kind
 var value: Variant = _marker_drag_value
 var changed: bool = _marker_drag_moved and value != _marker_drag_start_value
 _marker_drag_kind = ""
 _marker_drag_moved = false
 _marker_drag_start_value = null
 _marker_drag_value = null
 if changed:
  _request_marker(kind, value)
 _finish_cycle_click()
 queue_redraw()


func _update_gameplay_drag(pointer: Vector2, free_move: bool, force: bool = false) -> void:
 if _gameplay_drag_index < 0 or _gameplay_drag_index >= _gameplay_objects().size():
  cancel_gesture()
  return
 if not force and pointer.distance_squared_to(_gameplay_drag_last_pointer) <= POINTER_JITTER_PIXELS * POINTER_JITTER_PIXELS:
  return
 _gameplay_drag_last_pointer = pointer
 var delta := screen_to_local_pixels(pointer) - _gameplay_drag_start_pointer
 if not _gameplay_drag_moved and delta.length() * _cell_pixels / _local_cell_size() < 3.0:
  return
 _gameplay_drag_moved = true
 _pending_cycle_target = {}
 _alt_held = free_move
 _gameplay_drag_position = legal_gameplay_position(_gameplay_drag_start_position + delta, free_move)
 _set_gameplay_status(_gameplay_drag_position)
 queue_redraw()


func _end_gameplay_drag() -> void:
 var index := _gameplay_drag_index
 var point := _gameplay_drag_position
 var changed := _gameplay_drag_moved and point != _gameplay_drag_start_position
 _gameplay_drag_index = -1
 _gameplay_drag_moved = false
 if changed:
  gameplay_move_requested.emit(index, point)
 _finish_cycle_click()
 queue_redraw()


func _set_gameplay_status(point: Vector2) -> void:
 var mode := "FREE MOVE" if _alt_held else "SNAP ON"
 _set_status("%s · Anchor (%.2f, %.2f) px · Alt frees gameplay position; terrain always snaps." % [mode, point.x, point.y])


func _begin_connector_drag(kind: String, pointer: Vector2, mode: String) -> void:
 var span := connector_span(kind)
 _connector_drag_kind = kind
 _connector_drag_mode = mode
 _connector_pointer_start_x = screen_to_grid(pointer).x
 _connector_first_cell = clampi(floori(_connector_pointer_start_x), 0, _grid_size().x - 1)
 _connector_original_start = span.x
 _connector_original_width = span.y
 _connector_preview_start = _connector_first_cell if mode == "create" else span.x
 _connector_preview_width = 1 if mode == "create" else span.y
 _connector_release_valid = true
 queue_redraw()


func _update_connector_drag(pointer: Vector2) -> void:
 var grid_x := screen_to_grid(pointer).x
 var columns := _grid_size().x
 match _connector_drag_mode:
  "create":
   _connector_release_valid = connector_border_at(pointer) == _connector_drag_kind
   var cell := clampi(floori(grid_x), 0, columns - 1)
   _connector_preview_start = mini(_connector_first_cell, cell)
   _connector_preview_width = absi(_connector_first_cell - cell) + 1
  "move":
   _connector_preview_start = clampi(_connector_original_start + roundi(grid_x - _connector_pointer_start_x), 0, columns - _connector_original_width)
  "left":
   var fixed_end := _connector_original_start + _connector_original_width
   _connector_preview_start = clampi(roundi(grid_x), 0, fixed_end - 1)
   _connector_preview_width = fixed_end - _connector_preview_start
  "right":
   var end := clampi(roundi(grid_x), _connector_original_start + 1, columns)
   _connector_preview_width = end - _connector_original_start
 if _connector_release_valid:
  _set_status("%s: width %d · cells %d–%d. Release to apply; Esc cancels." % [_connector_drag_kind.capitalize(), _connector_preview_width, _connector_preview_start, _connector_preview_start + _connector_preview_width - 1])
 else:
  var border := "bottom" if _connector_drag_kind == "entry" else "top"
  _set_status("Return to the %s border before releasing to create this connector." % border)
 queue_redraw()


func _end_connector_drag() -> void:
 var kind := _connector_drag_kind
 var start_x := _connector_preview_start
 var width := _connector_preview_width
 var valid := _connector_release_valid
 var changed := _connector_drag_mode == "create" or start_x != _connector_original_start or width != _connector_original_width
 _connector_drag_kind = ""
 _connector_drag_mode = ""
 _connector_release_valid = true
 if not valid:
  _set_status("Connector placement canceled: release on its required border.")
 elif changed:
  selected_connector = kind
  connector_requested.emit(kind, start_x, width)
  connector_selection_changed.emit(selected_connector)
 queue_redraw()


func _end_primary() -> void:
 if _decor_drag_index >= 0:
  _end_decor_drag()
  return
 if not _ring_mode.is_empty():
  _end_ring_drag()
  return
 if not _marker_drag_kind.is_empty():
  _end_marker_drag()
  return
 if _gameplay_drag_index >= 0:
  _end_gameplay_drag()
  return
 if not _connector_drag_kind.is_empty():
  _end_connector_drag()
  return
 var moved_index := _drag_index
 var moved_anchor := _drag_anchor
 var should_move := _drag_moved and moved_anchor != _drag_start_anchor
 _drag_index = -1
 _drag_moved = false
 if moved_index >= 0 and should_move:
  move_requested.emit(moved_index, moved_anchor)
 _finish_cycle_click()
 queue_redraw()


func _leave_tool() -> void:
 _rail_draft = {}
 rail_edit = false
 _rail_drag = -1
 _clear_decor_selection()
 ring_tool = false
 selected_ring_index = -1
 cancel_gesture()
 brush = {}
 selected_index = -1
 selected_indices.clear()
 connector_tool = ""
 selected_connector = ""
 gameplay_brush = {}
 selected_gameplay_index = -1
 marker_tool = ""
 selected_marker = ""
 _emit_selection_changed()
 _set_status("Selection mode. Ctrl-click toggles terrain; Alt-click cycles overlaps. Click terrain, gameplay objects or Act markers.")
 queue_redraw()


func _zoom_at(pointer: Vector2, factor: float) -> void:
 var grid_point := screen_to_grid(pointer)
 _cell_pixels = clampf(_cell_pixels * factor, MIN_CELL_PIXELS, MAX_CELL_PIXELS)
 _view_origin = pointer - grid_point * _cell_pixels
 _view_adjusted = true
 queue_redraw()


func _on_resized() -> void:
 if _view_adjusted:
  _view_origin += (size - _last_size) * 0.5
  _last_size = size
  queue_redraw()
 else:
  fit_view()


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
 if preview_active:
  return false
 if not data is Dictionary:
  return false
 if data.get("gameplay_stamp") is Dictionary:
  var object: Dictionary = data["gameplay_stamp"]
  _drop_brush = {}
  if not _valid_gameplay_stamp(object) or not _inside_grid(at_position):
   _drop_gameplay_brush = {}
   queue_redraw()
   return false
  _drop_gameplay_brush = object.duplicate(true)
  _cursor_position = at_position
  queue_redraw()
  return true
 if not data.get("terrain_stamp") is Dictionary:
  return false
 _drop_gameplay_brush = {}
 var stamp: Dictionary = data["terrain_stamp"]
 if not _valid_stamp(stamp) or not _inside_grid(at_position):
  _drop_brush = {}
  queue_redraw()
  return false
 _drop_brush = stamp.duplicate(true)
 _cursor_position = at_position
 queue_redraw()
 return true


func _drop_data(at_position: Vector2, data: Variant) -> void:
 if not _can_drop_data(at_position, data):
  return
 # Commit a focused inspector field before changing the selection or brush.
 grab_focus()
 if data.get("gameplay_stamp") is Dictionary:
  var object: Dictionary = data["gameplay_stamp"].duplicate(true)
  object["position"] = legal_gameplay_position(screen_to_local_pixels(at_position), _alt_held)
  set_gameplay_brush(data["gameplay_stamp"])
  gameplay_placement_requested.emit(object)
  return
 var placement: Dictionary = data["terrain_stamp"].duplicate(true)
 Shapes.set_placement_position(placement, legal_anchor_for(placement, screen_to_grid(at_position), _alt_held))
 set_brush(data["terrain_stamp"])
 placement_requested.emit(placement)


func _notification(what: int) -> void:
 if what == NOTIFICATION_DRAG_END:
  _drop_brush = {}
  _drop_gameplay_brush = {}
  queue_redraw()
 elif what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
  _alt_held = false
  cancel_gesture()


func _valid_stamp(placement: Dictionary) -> bool:
 if document == null or placement.is_empty():
  return false
 if Shapes.definition_for_placement(placement).is_empty():
  return false
 var footprint := Shapes.scaled_size(placement)
 var dimensions := _grid_size()
 return footprint.x > 0 and footprint.y > 0 and footprint.x <= dimensions.x and footprint.y <= dimensions.y


func _valid_gameplay_stamp(placement: Dictionary) -> bool:
 return document != null and not Objects.get_definition(str(placement.get("type", ""))).is_empty()


func _inside_grid(point: Vector2) -> bool:
 # Compare in the same coordinate space as the incoming pointer. Converting an
 # exact left/top edge through a translated Control can lose one float32 ULP.
 # Use the exact drawn endpoints: transforming a Rect2 can round its reconstructed
 # end outward by an ULP and wrongly admit the right/bottom boundary. No tolerance
 # or snapping is applied to freely authored coordinates.
 var transform := get_global_transform()
 var start := transform * grid_to_screen(Vector2.ZERO)
 var end := transform * grid_to_screen(Vector2(_grid_size()))
 var global_point := transform * point
 return global_point.x >= start.x and global_point.y >= start.y and global_point.x < end.x and global_point.y < end.y


func _placements() -> Array:
 return document.get("placements") if document != null else []


func _gameplay_objects() -> Array:
 return document.get("gameplay_objects") if document != null else []


func _local_cell_size() -> float:
 return float(document.get("cell_size")) if document != null else 50.0


func _grid_size() -> Vector2i:
 return document.get("grid_size") if document != null else Vector2i(12, 12)


func _set_status(message: String) -> void:
 if message != _last_status:
  _last_status = message
  status_changed.emit(message)

func _rail_input(event: InputEvent) -> bool:
 if not _rail_draft.is_empty() and event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
  if _rail_draft.properties.points.size() >= 2:
   gameplay_placement_requested.emit(_rail_draft)
   _rail_draft = {}
   queue_redraw()
  return true
 if not rail_edit or selected_gameplay_index < 0 or selected_gameplay_index >= _gameplay_objects().size(): return false
 var item: Dictionary = _gameplay_objects()[selected_gameplay_index]
 if item.type != "elevated_rail":
  rail_edit = false
  return false
 var points: PackedVector2Array = Objects.properties(item).points
 if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
  grab_focus()
  var local := (legal_gameplay_position(screen_to_local_pixels(event.position), event.alt_pressed) - Vector2(item.position)).rotated(-deg_to_rad(float(item.rotation_degrees)))
  var nearest := -1
  for i in points.size():
   var screen := local_pixels_to_screen(item.position + points[i].rotated(deg_to_rad(float(item.rotation_degrees))))
   if screen.distance_to(event.position) <= 10.0: nearest = i
  if event.pressed:
   if event.button_index == MOUSE_BUTTON_RIGHT:
    if nearest >= 0 and points.size() > 2:
     points.remove_at(nearest)
     rail_points_changed.emit(points)
   elif nearest >= 0:
    _rail_drag = nearest
    _rail_preview = points.duplicate()
   elif points.size() < 64:
    var insert_at := points.size()
    if event.shift_pressed:
     var best := INF
     for i in points.size() - 1:
      var distance := Geometry2D.get_closest_point_to_segment(local, points[i], points[i + 1]).distance_to(local)
      if distance < best:
       best = distance
       insert_at = i + 1
    points.insert(insert_at, local)
    rail_points_changed.emit(points)
  elif _rail_drag >= 0:
   var edited := _rail_preview.duplicate()
   _rail_drag = -1
   rail_points_changed.emit(edited)
  queue_redraw()
  return true
 if event is InputEventMouseMotion and _rail_drag >= 0:
  _rail_preview[_rail_drag] = (legal_gameplay_position(screen_to_local_pixels(event.position), event.alt_pressed) - Vector2(item.position)).rotated(-deg_to_rad(float(item.rotation_degrees)))
  queue_redraw()
  return true
 return false
