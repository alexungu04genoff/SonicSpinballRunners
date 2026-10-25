extends Node2D
## Collisionless 2D debug drawing from compiled terrain and actual runtime bodies.
var document: Resource
var runtime: Dictionary = {}
var ball: PlaygroundBall
var ring_field: RingField
var units_per_pixel := 1.0

func _process(_delta: float) -> void:
 queue_redraw()

func _draw() -> void:
 if document == null:
  return
 var bounds: Rect2 = document.terrain_bounds()
 var gutter: Rect2 = document.red_gutter_bounds()
 draw_rect(bounds, Color("121e2a"))
 for x in range(document.grid_size.x + 1):
  draw_line(Vector2(x * document.cell_size, 0), Vector2(x * document.cell_size, bounds.end.y), Color("233443"), units_per_pixel)
 for y in range(document.grid_size.y + 1):
  draw_line(Vector2(0, y * document.cell_size), Vector2(bounds.end.x, y * document.cell_size), Color("233443"), units_per_pixel)
 draw_rect(gutter, Color(0.7, 0.13, 0.2, 0.20))
 draw_line(Vector2(0, gutter.end.y), gutter.end, Color("ff647e"), 2.0 * units_per_pixel)
 _label(Vector2(8, gutter.end.y - 8 * units_per_pixel), "DRAIN / RESPAWN THRESHOLD", Color("ff9aaf"))
 for item: Dictionary in runtime.get("terrain", []):
  var points: PackedVector2Array = item.points.duplicate()
  if item.closed:
   draw_colored_polygon(points, Color("708395"))
   points.append(points[0])
  draw_polyline(points, Color("d6e5ee"), 2.0 * units_per_pixel, true)
 for item: Dictionary in runtime.get("objects", []):
  if item.has("mechanic"):
   preload("res://scripts/act_editor/gameplay_preview.gd").draw_object(self, item, item.position, 1.0, float(document.cell_size))
   continue
  var body: Node2D = item.body
  var points := PackedVector2Array()
  var color := Color("5cd9ed")
  if item.type == "round_bumper":
   draw_circle(body.position, item.radius, Color("24788e"))
   draw_arc(body.position, item.radius, 0, TAU, 64, color, 2.0 * units_per_pixel, true)
  elif item.type == "triangle_bumper":
   for point: Vector2 in item.points:
    points.append(body.transform * point)
  else:
   color = Color("ffda70")
   for step in range(25):
    points.append(body.transform * (Vector2.RIGHT.rotated(PI * 0.5 + PI * step / 24.0) * item.radius))
   for step in range(25):
    points.append(body.transform * (Vector2(item.length, 0) + Vector2.RIGHT.rotated(-PI * 0.5 + PI * step / 24.0) * item.radius))
  if not points.is_empty():
   draw_colored_polygon(points, Color(color, 0.8))
   points.append(points[0])
   draw_polyline(points, color, 1.5 * units_per_pixel, true)
  draw_circle(body.position, 2.5 * units_per_pixel, Color.WHITE)
 if is_instance_valid(ring_field):
  for ring: Dictionary in ring_field.rings:
   if ring.active:
    draw_arc(ring.position, ring_field.ring_radius, 0, TAU, 24, Color("ffda70"), 1.5 * units_per_pixel, true)
 if document.activation_y != null:
  var y := float(document.activation_y)
  draw_dashed_line(Vector2(0, y), Vector2(bounds.end.x, y), Color("62eee3"), 1.5 * units_per_pixel, 8 * units_per_pixel)
  _label(Vector2(8, y - 6 * units_per_pixel), "ACTIVATION ↑", Color("62eee3"))
 _connector("entry", bounds.end.y)
 _connector("exit", 0.0)
 var spawn: Vector2 = document.spawn_position
 draw_arc(spawn, 7 * units_per_pixel, 0, TAU, 32, Color("f4aedd"), 1.5 * units_per_pixel, true)
 _label(spawn + Vector2(10, -6) * units_per_pixel, "SPAWN", Color("f4aedd"))
 if is_instance_valid(ball):
  draw_circle(ball.position, ball.radius, Color("f7fbff"))
  draw_arc(ball.position, ball.radius, 0, TAU, 32, Color("76cafa"), 1.5 * units_per_pixel, true)

func _connector(kind: String, y: float) -> void:
 var span: Dictionary = document.get_connector(kind)
 if span.width == 0:
  return
 var a := Vector2(span.start_x * document.cell_size, y)
 var b := Vector2((span.start_x + span.width) * document.cell_size, y)
 draw_line(a, b, Color("71efa4"), 4.0 * units_per_pixel, true)
 for point: Vector2 in [a, b]:
  draw_line(point - Vector2(0, 5) * units_per_pixel, point + Vector2(0, 5) * units_per_pixel, Color("71efa4"), 1.5 * units_per_pixel)
 _label((a + b) * 0.5 + Vector2(0, -10 if kind == "exit" else 18) * units_per_pixel, kind.to_upper() + " · " + str(span.width) + " cells", Color("71efa4"))

func _label(at: Vector2, text: String, color: Color) -> void:
 draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(1, roundi(12 * units_per_pixel)), color)
