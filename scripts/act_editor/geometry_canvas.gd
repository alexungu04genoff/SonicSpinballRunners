extends Control
## Terrain drawing and pointer gestures only. The editor owns document changes and undo.

signal placement_requested(placement: Dictionary)
signal selection_changed(index: int)
signal move_requested(index: int, anchor: Vector2i)
signal status_changed(message: String)

const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
const GRID_MARGIN := 48.0
const MIN_CELL_PIXELS := 12.0
const MAX_CELL_PIXELS := 240.0
const SELECTION_COLOR := Color("b9f4ff")

var document: Resource
var selected_index := -1
var brush: Dictionary = {}

var _view_origin := Vector2.ZERO
var _cell_pixels := 48.0
var _view_adjusted := false
var _last_size := Vector2.ZERO
var _hovering := false
var _cursor_position := Vector2.ZERO
var _panning := false
var _drag_index := -1
var _drag_start_pointer := Vector2.ZERO
var _drag_start_anchor := Vector2i.ZERO
var _drag_anchor := Vector2i.ZERO
var _drag_moved := false
var _drop_brush: Dictionary = {}
var _last_status := ""


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
  queue_redraw()
 )
 fit_view()


func set_document(value: Resource, reset_view: bool = true) -> void:
 document = value
 selected_index = -1
 brush = {}
 cancel_gesture()
 if reset_view:
  fit_view()
 else:
  queue_redraw()


func set_brush(value: Dictionary) -> void:
 cancel_gesture()
 brush = value.duplicate(true)
 selected_index = -1
 queue_redraw()


func select_piece(index: int) -> void:
 cancel_gesture()
 brush = {}
 selected_index = index if index >= 0 and index < _placements().size() else -1
 queue_redraw()


func fit_view() -> void:
 var dimensions := Vector2(_grid_size())
 var available := (size - Vector2.ONE * GRID_MARGIN * 2.0).max(Vector2.ONE)
 _cell_pixels = clampf(minf(available.x / dimensions.x, available.y / dimensions.y), 4.0, MAX_CELL_PIXELS)
 _view_origin = (size - dimensions * _cell_pixels) * 0.5
 _view_adjusted = false
 _last_size = size
 queue_redraw()


func cancel_gesture() -> void:
 _drag_index = -1
 _drag_moved = false
 _panning = false
 _drop_brush = {}
 queue_redraw()


func grid_to_screen(point: Vector2) -> Vector2:
 return _view_origin + point * _cell_pixels


func screen_to_grid(point: Vector2) -> Vector2:
 return (point - _view_origin) / _cell_pixels


func legal_anchor_for(placement: Dictionary, grid_position: Vector2) -> Vector2i:
 var footprint: Vector2i = Shapes.transformed_size(placement)
 var limit := (_grid_size() - footprint).max(Vector2i.ZERO)
 return Vector2i(clampi(roundi(grid_position.x), 0, limit.x), clampi(roundi(grid_position.y), 0, limit.y))


func hit_indices_at(local_position: Vector2) -> Array[int]:
 var hits: Array[int] = []
 var grid_point := screen_to_grid(local_position)
 var tolerance := 7.0 / _cell_pixels
 var placements := _placements()
 for index in range(placements.size() - 1, -1, -1):
  var placement: Dictionary = placements[index]
  var definition: Dictionary = Shapes.get_definition(str(placement.get("shape_id", "")))
  if definition.is_empty():
   continue
  var anchor: Vector2i = placement.get("anchor", Vector2i.ZERO)
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
 _draw_grid()
 var placements := _placements()
 for index in placements.size():
  var placement: Dictionary = placements[index]
  if index == _drag_index and _drag_moved:
   placement = placement.duplicate(true)
   placement["anchor"] = _drag_anchor
  _draw_piece(placement, false, false)
 if selected_index >= 0 and selected_index < placements.size():
  var selected: Dictionary = placements[selected_index].duplicate(true)
  if selected_index == _drag_index and _drag_moved:
   selected["anchor"] = _drag_anchor
  _draw_piece(selected, true, false)
  _draw_footprint(selected, Color(SELECTION_COLOR, 0.55))
 var active_brush := _drop_brush if not _drop_brush.is_empty() else brush
 if (_hovering or not _drop_brush.is_empty()) and _inside_grid(_cursor_position) and _valid_stamp(active_brush):
  var ghost := active_brush.duplicate(true)
  ghost["anchor"] = legal_anchor_for(ghost, screen_to_grid(_cursor_position))
  _draw_piece(ghost, false, true)
  _draw_footprint(ghost, Color(0.75, 0.91, 1.0, 0.5))


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
 var definition: Dictionary = Shapes.get_definition(str(placement.get("shape_id", "")))
 if definition.is_empty():
  return
 var points: PackedVector2Array = Shapes.transformed_points(placement)
 var anchor: Vector2i = placement.get("anchor", Vector2i.ZERO)
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
 var anchor: Vector2i = placement.get("anchor", Vector2i.ZERO)
 var footprint: Vector2i = Shapes.transformed_size(placement)
 var top_left := grid_to_screen(Vector2(anchor))
 var bottom_right := grid_to_screen(Vector2(anchor + footprint))
 var top_right := Vector2(bottom_right.x, top_left.y)
 var bottom_left := Vector2(top_left.x, bottom_right.y)
 _draw_dashes(top_left, top_right, color)
 _draw_dashes(top_right, bottom_right, color)
 _draw_dashes(bottom_right, bottom_left, color)
 _draw_dashes(bottom_left, top_left, color)
 draw_circle(top_left, 3.0, color)


func _draw_dashes(from: Vector2, to: Vector2, color: Color) -> void:
 var length := from.distance_to(to)
 if length < 0.01:
  return
 var direction := (to - from) / length
 var distance := 0.0
 while distance < length:
  draw_line(from + direction * distance, from + direction * minf(distance + 5.0, length), color, 1.0, true)
  distance += 10.0


func _gui_input(event: InputEvent) -> void:
 if document == null:
  return
 if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
  _leave_tool()
  accept_event()
 elif event is InputEventKey and event.pressed and not event.ctrl_pressed and not event.meta_pressed and event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
  # Consume arrows before Control's built-in focus navigation. The owner still
  # applies the edit through the same move signal as pointer dragging.
  if not event.echo and selected_index >= 0 and selected_index < _placements().size():
   var direction: Vector2i = {KEY_LEFT: Vector2i.LEFT, KEY_RIGHT: Vector2i.RIGHT, KEY_UP: Vector2i.UP, KEY_DOWN: Vector2i.DOWN}[event.keycode]
   var placement: Dictionary = _placements()[selected_index]
   var anchor: Vector2i = placement.get("anchor", Vector2i.ZERO)
   move_requested.emit(selected_index, legal_anchor_for(placement, Vector2(anchor + direction)))
  accept_event()
 elif event is InputEventMouseButton:
  _cursor_position = event.position
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
    _begin_primary(event.position, event.alt_pressed)
   else:
    if _drag_index >= 0:
     _update_drag(event.position)
    _end_primary()
   accept_event()
 elif event is InputEventMouseMotion:
  _cursor_position = event.position
  if _panning:
   _view_origin += event.relative
   _view_adjusted = true
  elif _drag_index >= 0:
   _update_drag(event.position)
  elif not brush.is_empty() and _inside_grid(event.position):
   var anchor := legal_anchor_for(brush, screen_to_grid(event.position))
   _set_status("Place at (%d, %d). Click to stamp; right-click or Esc to select." % [anchor.x, anchor.y])
  queue_redraw()
  accept_event()


func _begin_primary(pointer: Vector2, cycle_overlaps: bool) -> void:
 if not brush.is_empty():
  if _inside_grid(pointer) and _valid_stamp(brush):
   var placement := brush.duplicate(true)
   placement["anchor"] = legal_anchor_for(placement, screen_to_grid(pointer))
   placement_requested.emit(placement)
  return
 var hits := hit_indices_at(pointer)
 var next_index := -1
 if not hits.is_empty():
  next_index = hits[0]
  if cycle_overlaps and selected_index in hits:
   next_index = hits[(hits.find(selected_index) + 1) % hits.size()]
 selected_index = next_index
 selection_changed.emit(selected_index)
 if next_index >= 0:
  var placement: Dictionary = _placements()[next_index]
  _drag_index = next_index
  _drag_start_pointer = screen_to_grid(pointer)
  _drag_start_anchor = placement.get("anchor", Vector2i.ZERO)
  _drag_anchor = _drag_start_anchor
  _drag_moved = false
  if hits.size() > 1:
   _set_status("%d overlapping shapes here. Alt-click cycles the selection." % hits.size())
 queue_redraw()


func _update_drag(pointer: Vector2) -> void:
 var placements := _placements()
 if _drag_index >= placements.size():
  cancel_gesture()
  return
 var delta := screen_to_grid(pointer) - _drag_start_pointer
 if not _drag_moved and delta.length() * _cell_pixels < 3.0:
  return
 _drag_moved = true
 _drag_anchor = legal_anchor_for(placements[_drag_index], Vector2(_drag_start_anchor) + delta)
 _set_status("Move to (%d, %d). Release to apply; Esc cancels." % [_drag_anchor.x, _drag_anchor.y])


func _end_primary() -> void:
 var moved_index := _drag_index
 var moved_anchor := _drag_anchor
 var should_move := _drag_moved and moved_anchor != _drag_start_anchor
 _drag_index = -1
 _drag_moved = false
 if moved_index >= 0 and should_move:
  move_requested.emit(moved_index, moved_anchor)
 queue_redraw()


func _leave_tool() -> void:
 cancel_gesture()
 brush = {}
 selected_index = -1
 selection_changed.emit(-1)
 _set_status("Selection mode. Click terrain; Alt-click cycles overlaps. Drag to move.")
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
 if not data is Dictionary or not data.get("terrain_stamp") is Dictionary:
  return false
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
 var placement: Dictionary = data["terrain_stamp"].duplicate(true)
 placement["anchor"] = legal_anchor_for(placement, screen_to_grid(at_position))
 set_brush(data["terrain_stamp"])
 placement_requested.emit(placement)
 grab_focus()


func _notification(what: int) -> void:
 if what == NOTIFICATION_DRAG_END:
  _drop_brush = {}
  queue_redraw()
 elif what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
  cancel_gesture()


func _valid_stamp(placement: Dictionary) -> bool:
 if document == null or placement.is_empty():
  return false
 if Shapes.get_definition(str(placement.get("shape_id", ""))).is_empty():
  return false
 var footprint: Vector2i = Shapes.transformed_size(placement)
 var dimensions := _grid_size()
 return footprint.x > 0 and footprint.y > 0 and footprint.x <= dimensions.x and footprint.y <= dimensions.y


func _inside_grid(point: Vector2) -> bool:
 return Rect2(_view_origin, Vector2(_grid_size()) * _cell_pixels).has_point(point)


func _placements() -> Array:
 return document.get("placements") if document != null else []


func _grid_size() -> Vector2i:
 return document.get("grid_size") if document != null else Vector2i(12, 12)


func _set_status(message: String) -> void:
 if message != _last_status:
  _last_status = message
  status_changed.emit(message)
