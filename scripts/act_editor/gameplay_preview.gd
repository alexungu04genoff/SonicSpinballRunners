extends RefCounted
## Shared authoring preview for the canvas and palette. This creates no physics.
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Dimensions = preload("res://scripts/act_editor/preview_dimensions.gd")
const SELECTION_COLOR := Color("b9f4ff")


static func rotated_points(placement: Dictionary, cell_size: float) -> PackedVector2Array:
 var result: PackedVector2Array = Objects.local_points(placement, cell_size)
 var angle := deg_to_rad(float(placement.get("rotation_degrees", 0.0)))
 for index in result.size():
  result[index] = result[index].rotated(angle)
 return result


static func draw_object(target: CanvasItem, placement: Dictionary, anchor: Vector2, scale_factor: float, cell_size: float, selected: bool = false, ghost: bool = false, annotations: bool = true) -> void:
 var definition: Dictionary = Objects.get_definition(str(placement.get("type", "")))
 if definition.is_empty():
  return
 if placement.type == "buzz_bomber":
  _draw_enemy(target, placement, anchor, scale_factor, selected, ghost, annotations)
  return
 var points := rotated_points(placement, cell_size)
 for index in points.size():
  points[index] = anchor + points[index] * scale_factor
 if placement.type in ["lane_barrier", "diverter", "dash_panel", "wall_switch"]:
  _draw_new_gimmick(target, placement, anchor, scale_factor, points, selected, ghost)
  return
 if placement.type in ["one_way_gate", "switch_target", "spring"]:
  _draw_gimmick(target, placement, anchor, scale_factor, points, selected, ghost)
  return
 if placement.type in ["spinner", "magnetic_field", "elevated_rail"]:
  _draw_mechanic(target, placement, anchor, scale_factor, points, selected, ghost)
  return
 if points.size() < 3:
  return
 var color: Color = definition.color
 var opacity := 0.55 if ghost else 1.0
 target.draw_colored_polygon(points, Color(color, 0.3 if ghost else 0.72))
 points.append(points[0])
 if selected:
  target.draw_polyline(points, SELECTION_COLOR, Dimensions.SELECTED_OUTLINE_PIXELS, true)
 target.draw_polyline(points, Color(color, opacity), Dimensions.OUTLINE_PIXELS, true)
 var flipper: bool = placement.type in ["left_flipper", "right_flipper"]
 if flipper and annotations:
  _draw_swing(target, placement, anchor, scale_factor * cell_size, Color(color, opacity))
 # The same marker identifies each object's saved center, local origin or pivot.
 var unit := Dimensions.marker_unit(scale_factor * cell_size)
 var marker_radius := Dimensions.PIVOT_RADIUS_CELLS * unit
 var crosshair := Dimensions.CROSSHAIR_RADIUS_CELLS * unit
 target.draw_circle(anchor, marker_radius + 1.0, Color("102434"))
 target.draw_circle(anchor, marker_radius, Color("f5fcff"))
 target.draw_line(anchor - Vector2(crosshair, 0), anchor + Vector2(crosshair, 0), Color(color, opacity), 1.0, true)
 target.draw_line(anchor - Vector2(0, crosshair), anchor + Vector2(0, crosshair), Color(color, opacity), 1.0, true)
 if flipper and annotations:
  var hand := "L" if placement.type == "left_flipper" else "R"
  var font := ThemeDB.fallback_font
  target.draw_string(font, anchor + Vector2(-4, -12), hand, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(color, opacity))


static func _draw_enemy(target: CanvasItem, placement: Dictionary, anchor: Vector2, scale_factor: float, selected: bool, ghost: bool, annotations: bool) -> void:
 var props := Objects.properties(placement)
 var size_value := float(props.scale) * scale_factor
 var color := Color("ffe074") if selected else Color("5bafff")
 if ghost: color.a = 0.55
 if annotations:
  var left := anchor + Vector2(float(props.patrol_left), 0) * scale_factor
  var right := anchor + Vector2(float(props.patrol_right), 0) * scale_factor
  target.draw_line(left, right, Color("ffe074"), 2.0, true)
  for endpoint: Vector2 in [left, right]:
   target.draw_rect(Rect2(endpoint - Vector2.ONE * 5, Vector2.ONE * 10), Color("ffe074"), selected)
 var outline := PackedVector2Array()
 for i in 33: outline.append(anchor + Vector2(cos(TAU * i / 32) * 26, sin(TAU * i / 32) * 12) * size_value)
 target.draw_colored_polygon(outline, Color("e7b52f"))
 target.draw_polyline(outline, color, 2.0, true)
 for x in [-8, 2, 12]: target.draw_line(anchor + Vector2(x, -10) * size_value, anchor + Vector2(x, 10) * size_value, Color("172c48"), maxf(1.0, size_value * 4), true)
 var facing := -1.0 if props.starting_direction == "left" else 1.0
 target.draw_circle(anchor + Vector2(facing * 21, -2) * size_value, maxf(2, 8 * size_value), color)
 for side in [-1, 1]:
  target.draw_line(anchor, anchor + Vector2(-5, side * 25) * size_value, Color("beeaff"), maxf(2, 6 * size_value), true)

static func _draw_swing(target: CanvasItem, placement: Dictionary, anchor: Vector2, cell_pixels: float, color: Color) -> void:
 var rest := deg_to_rad(float(placement.rotation_degrees))
 var direction := -1.0 if placement.type == "left_flipper" else 1.0
 var swing := deg_to_rad(Objects.FLIPPER_SWING_DEGREES) * direction
 var radius: float = Dimensions.FLIPPER_LENGTH_CELLS * cell_pixels
 var arc := PackedVector2Array()
 for step in range(25):
  arc.append(anchor + Vector2.RIGHT.rotated(rest + swing * float(step) / 24.0) * radius)
 target.draw_polyline(arc, Color(color, color.a * 0.65), 1.5, true)
 var tip := arc[arc.size() - 1]
 var tangent := (tip - arc[arc.size() - 2]).normalized()
 var back := -tangent * Dimensions.ARROW_HEAD_CELLS * Dimensions.marker_unit(cell_pixels)
 target.draw_line(tip, tip + back.rotated(0.5), color, 1.5, true)
 target.draw_line(tip, tip + back.rotated(-0.5), color, 1.5, true)
 var end := anchor + Vector2.RIGHT.rotated(rest + swing) * radius
 target.draw_line(anchor, end, Color(color, color.a * 0.18), 1.0, true)

static func _draw_mechanic(target: CanvasItem, placement: Dictionary, anchor: Vector2, scale_factor: float, points: PackedVector2Array, selected: bool, ghost: bool) -> void:
 var props := Objects.properties(placement)
 var color: Color = Objects.get_definition(placement.type).color
 if ghost: color.a = 0.55
 var angle := deg_to_rad(float(placement.rotation_degrees))
 if placement.type == "elevated_rail":
  if points.size() >= 2:
   target.draw_polyline(points, Color(color, 0.18), maxf(3.0, float(props.width) * scale_factor), true)
   target.draw_polyline(points, color, 2.0, true)
   _arrow(target, points[-1] - (points[-1] - points[-2]).normalized() * 18, points[-1], color)
  for point: Vector2 in props.points:
   target.draw_circle(anchor + point.rotated(angle) * scale_factor, 5.0 if selected else 3.0, color)
 elif placement.type == "magnetic_field":
  var radius := float(props.radius) * scale_factor
  var repel: bool = props.mode == "repel"
  color = Color("ff9378") if repel else color
  target.draw_arc(anchor, radius, 0, TAU, 64, color, 2.0, true)
  for i in 4:
   var direction := Vector2.from_angle(i * TAU / 4)
   var a := anchor + direction * radius * (0.4 if repel else 0.8)
   var b := anchor + direction * radius * (0.8 if repel else 0.4)
   _arrow(target, a, b, color)
 else:
  if points.size() >= 3:
   target.draw_colored_polygon(points, color)
   target.draw_circle(anchor + Vector2(-float(props.width) / 2, 0).rotated(angle) * scale_factor, 3, Color.WHITE)
   target.draw_circle(anchor + Vector2(float(props.width) / 2, 0).rotated(angle) * scale_factor, 3, Color.WHITE)
  _arrow(target, anchor + Vector2.DOWN.rotated(angle) * 18, anchor + Vector2.UP.rotated(angle) * 18, color)
 target.draw_circle(anchor, 3.0, Color.WHITE)
 if selected: target.draw_arc(anchor, 7.0, 0, TAU, 24, SELECTION_COLOR, 1.5, true)

static func _arrow(target: CanvasItem, a: Vector2, b: Vector2, color: Color) -> void:
 target.draw_line(a, b, color, 1.5, true)
 var back := (a - b).normalized() * 7.0
 target.draw_line(b, b + back.rotated(0.5), color, 1.5, true)
 target.draw_line(b, b + back.rotated(-0.5), color, 1.5, true)

static func _draw_gimmick(target: CanvasItem, item: Dictionary, anchor: Vector2, scale_factor: float, points: PackedVector2Array, selected: bool, ghost: bool) -> void:
 var props := Objects.properties(item)
 var color: Color = Objects.COLORS.get(props.get("color", ""), Color("66e0b2"))
 if ghost: color.a = 0.55
 var state: Dictionary = item.get("mechanic", {})
 var open: bool = state.get("open", props.get("initial_state") == "open")
 if item.type == "one_way_gate" and open:
  for i in points.size(): target.draw_line(points[i], points[(i + 1) % points.size()], Color(color, 0.25), 1.0, true)
 else:
  target.draw_colored_polygon(points, Color(color, 0.6))
  var outline := points.duplicate()
  outline.append(points[0])
  target.draw_polyline(outline, SELECTION_COLOR if selected else color, 3.0 if selected else 1.5, true)
 if item.type == "switch_target":
  target.draw_circle(anchor, Objects.switch_radius(item) * scale_factor * 0.65, color.lightened(0.3) if state.get("active", false) else color.darkened(0.35))
  var text: String = "ON" if state.get("active", false) else props.label
  if not text.is_empty(): target.draw_string(ThemeDB.fallback_font, anchor + Vector2(0, -22), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
 elif item.type == "spring":
  target.draw_circle(anchor, 6.0 * scale_factor, Color("2362c9"))
  target.draw_circle(anchor, 3.0 * scale_factor, Color("ffe05a"))
 if item.type != "switch_target":
  var forward := Objects.forward(item)
  _arrow(target, anchor - forward * 14, anchor + forward * 28, color)
 if selected: target.draw_arc(anchor, 6, 0, TAU, 24, Color.WHITE, 1.5, true)

static func _draw_new_gimmick(target: CanvasItem, item: Dictionary, anchor: Vector2, scale_factor: float, points: PackedVector2Array, selected: bool, ghost: bool) -> void:
 var props := Objects.properties(item)
 var color: Color = Objects.get_definition(item.type).color
 if ghost: color.a = 0.5
 if item.type == "lane_barrier":
  for i in points.size() - 1:
   target.draw_line(points[i], points[i + 1], Color(color, 0.3), maxf(2.0, 12.0 * scale_factor), true)
   var center := (points[i] + points[i + 1]) * 0.5
   var normal := (points[i + 1] - points[i]).normalized().orthogonal()
   _arrow(target, center - normal * 12, center + normal * 12, color)
  for point: Vector2 in points:
   target.draw_circle(point, maxf(2.0, float(props.post_radius) * scale_factor), Color("18243a"))
   target.draw_arc(point, maxf(2.0, float(props.post_radius) * scale_factor), 0, TAU, 12, SELECTION_COLOR if selected else color, 2, true)
 elif item.type == "diverter":
  for state: String in ["a", "b"]:
   var side := Objects.diverter_forward(item, state).orthogonal() * float(props.length) * scale_factor * 0.5
   target.draw_line(anchor - side, anchor + side, Color(color, 0.25), 8.0 * scale_factor, true)
   if selected: target.draw_string(ThemeDB.fallback_font, anchor + side + Vector2(4, -4), state.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
  target.draw_colored_polygon(points, color)
 elif item.type == "dash_panel":
  target.draw_colored_polygon(points, Color("30224e", color.a))
  var outline := points.duplicate()
  outline.append(points[0])
  target.draw_polyline(outline, color, 2, true)
  var forward := Objects.forward(item)
  for offset: float in [-9.0, 1.0, 11.0]:
   var tip := anchor + forward * offset * scale_factor
   var side := forward.orthogonal() * minf(12.0, float(props.width) * 0.28) * scale_factor
   target.draw_polyline(PackedVector2Array([tip - forward * 7.0 * scale_factor - side, tip, tip - forward * 7.0 * scale_factor + side]), color, 2.0, true)
  if selected: _arrow(target, anchor + forward * 24.0 * scale_factor, anchor + forward * 120.0 * scale_factor, Color(color, 0.6))
 else:
  color = Objects.COLORS[props.color]
  target.draw_colored_polygon(points, color)
  var forward := Objects.forward(item)
  _arrow(target, anchor, anchor + forward * 30.0 * scale_factor, color)
  target.draw_line(points[2], points[3], Color.WHITE, 2, true)
 if selected: target.draw_arc(anchor, 6, 0, TAU, 24, Color.WHITE, 1.5, true)
