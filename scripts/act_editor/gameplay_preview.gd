extends RefCounted
## Shared authoring preview for the canvas and palette. This creates no physics.
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
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
 var points := rotated_points(placement, cell_size)
 for index in points.size():
  points[index] = anchor + points[index] * scale_factor
 if points.size() < 3:
  return
 var color: Color = definition.color
 var opacity := 0.55 if ghost else 1.0
 target.draw_colored_polygon(points, Color(color, 0.3 if ghost else 0.72))
 points.append(points[0])
 if selected:
  target.draw_polyline(points, SELECTION_COLOR, 6.0, true)
 target.draw_polyline(points, Color(color, opacity), 2.5, true)
 var flipper: bool = placement.type in ["left_flipper", "right_flipper"]
 if flipper and annotations:
  _draw_swing(target, placement, anchor, scale_factor, Color(color, opacity))
 # The same marker identifies each object's saved center, local origin or pivot.
 var marker_radius := 4.0 if annotations else 2.5
 target.draw_circle(anchor, marker_radius + 1.5, Color("102434"))
 target.draw_circle(anchor, marker_radius, Color("f5fcff"))
 target.draw_line(anchor - Vector2(7, 0), anchor + Vector2(7, 0), Color(color, opacity), 1.0, true)
 target.draw_line(anchor - Vector2(0, 7), anchor + Vector2(0, 7), Color(color, opacity), 1.0, true)
 if flipper and annotations:
  var hand := "L" if placement.type == "left_flipper" else "R"
  var font := ThemeDB.fallback_font
  target.draw_string(font, anchor + Vector2(-4, -12), hand, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(color, opacity))


static func _draw_swing(target: CanvasItem, placement: Dictionary, anchor: Vector2, scale_factor: float, color: Color) -> void:
 var rest := deg_to_rad(float(placement.rotation_degrees))
 var direction := -1.0 if placement.type == "left_flipper" else 1.0
 var swing := deg_to_rad(Objects.FLIPPER_SWING_DEGREES) * direction
 var radius: float = Objects.FLIPPER_LENGTH * scale_factor
 var arc := PackedVector2Array()
 for step in range(25):
  arc.append(anchor + Vector2.RIGHT.rotated(rest + swing * float(step) / 24.0) * radius)
 target.draw_polyline(arc, Color(color, color.a * 0.65), 1.5, true)
 var tip := arc[arc.size() - 1]
 var tangent := (tip - arc[arc.size() - 2]).normalized()
 var back := -tangent * 7.0
 target.draw_line(tip, tip + back.rotated(0.5), color, 1.5, true)
 target.draw_line(tip, tip + back.rotated(-0.5), color, 1.5, true)
 var end := anchor + Vector2.RIGHT.rotated(rest + swing) * radius
 target.draw_line(anchor, end, Color(color, color.a * 0.18), 1.0, true)
