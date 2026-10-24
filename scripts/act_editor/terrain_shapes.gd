class_name TerrainShapes
extends RefCounted
## Authoring-only terrain library. All points are in canonical cell coordinates.
## Logical frames measure cells, not grid intersections or occupied-cell masks.
const VERSION := 1
const CURVE_STEPS := 24

static var _catalogue: Array[Dictionary] = []

static func definitions() -> Array[Dictionary]:
 if _catalogue.is_empty():
  _build_catalogue()
 return _catalogue.duplicate(true)

static func get_definition(id: String) -> Dictionary:
 if _catalogue.is_empty():
  _build_catalogue()
 for definition: Dictionary in _catalogue:
  if definition.id == id:
   return definition.duplicate(true)
 return {}

static func transformed_size(placement: Dictionary) -> Vector2i:
 var definition := _placement_definition(placement)
 if definition.is_empty() or typeof(placement.get("quarter_turns", 0)) != TYPE_INT:
  return Vector2i.ZERO
 var size: Vector2i = definition.size
 return Vector2i(size.y, size.x) if posmod(placement.get("quarter_turns", 0), 2) else size

static func transformed_points(placement: Dictionary) -> PackedVector2Array:
 var definition := _placement_definition(placement)
 var result := PackedVector2Array()
 if definition.is_empty() or typeof(placement.get("quarter_turns", 0)) != TYPE_INT:
  return result
 var turns: int = posmod(placement.get("quarter_turns", 0), 4)
 var original_size := Vector2(definition.size)
 for canonical: Vector2 in definition.points:
  var point := canonical
  var frame := original_size
  for turn in turns:
   # Screen coordinates increase downward, so this is a clockwise quarter-turn.
   point = Vector2(frame.y - point.y, point.x)
   frame = Vector2(frame.y, frame.x)
  # Mirrors refer to the final screen axes, after all quarter-turns.
  if placement.get("flip_h", false) == true:
   point.x = frame.x - point.x
  if placement.get("flip_v", false) == true:
   point.y = frame.y - point.y
  result.append(point)
 return result

static func _placement_definition(placement: Dictionary) -> Dictionary:
 if typeof(placement.get("shape_id")) != TYPE_STRING:
  return {}
 return get_definition(placement.shape_id)

static func _build_catalogue() -> void:
 var narrow: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)]
 var corners: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 3)]
 var squares: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3)]
 var rounded: Array[Vector2i] = [Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 2), Vector2i(2, 3)]
 _add_family("wall", "Straight walls", "Wall", narrow, false, Color("81d4fa"))
 _add_family("corner", "Open L corners", "L corner", corners, false, Color("80cbc4"))
 _add_family("triangle", "Triangles", "Triangle", narrow, true, Color("ffc778"))
 _add_family("slope", "Curved slopes", "Curved slope", corners, true, Color("8bd3a8"))
 _add_family("j_curve", "Open J curves", "J curve", corners, false, Color("87dce5"))
 _add_family("rectangle", "Squares / rectangles", "Rectangle", [Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3), Vector2i(1, 2), Vector2i(1, 3)], true, Color("a9bafa"))
 _add_family("circle", "Circles", "Circle", squares, true, Color("f1a3bb"))
 _add_family("oval", "Ovals", "Oval", rounded, true, Color("d3a5e8"))
 _add_family("bump", "Half-ellipse bumps", "Bump", [Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 3)], true, Color("e3d47e"))
 _add_family("diagonal", "Open diagonals", "Diagonal rail", narrow, false, Color("ffc49e"))
 _add_family("capsule", "Capsules", "Capsule", rounded, true, Color("b7cd92"))
 _add_family("outer_corner", "Rounded outer corners", "Outer corner", squares, true, Color("d7b18d"))
 _add_family("u_curve", "Open U curves", "U curve", [Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 3)], false, Color("8cbbe7"))

static func _add_family(prefix: String, family: String, label: String, sizes: Array[Vector2i], closed: bool, color: Color) -> void:
 for size: Vector2i in sizes:
  _catalogue.append({
   "id": "%s_%dx%d" % [prefix, size.x, size.y],
   "family": family,
   "label": "%s %d×%d" % [label, size.x, size.y],
   "size": size,
   "closed": closed,
   "points": _canonical_points(prefix, size),
   "color": color,
  })

static func _canonical_points(family: String, size: Vector2i) -> PackedVector2Array:
 var w := float(size.x)
 var h := float(size.y)
 var result := PackedVector2Array()
 match family:
  "wall":
   # A vertical line has zero geometric width, but a one-cell logical frame.
   return PackedVector2Array([Vector2.ZERO, Vector2(0, h)])
  "corner":
   return PackedVector2Array([Vector2.ZERO, Vector2(0, h), Vector2(w, h)])
  "triangle":
   return PackedVector2Array([Vector2.ZERO, Vector2(w, h), Vector2(0, h)])
  "diagonal":
   return PackedVector2Array([Vector2.ZERO, Vector2(w, h)])
  "rectangle":
   return PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)])
  "slope", "j_curve", "outer_corner":
   for step in range(CURVE_STEPS + 1):
    var angle := PI * 0.5 * float(step) / CURVE_STEPS
    if family == "outer_corner":
     # Convex quarter ellipse centered at (0,h): x=w sin(t), y=h(1-cos(t)).
     # The closing corner encloses pi/4 of the frame, unlike the concave ramp.
     result.append(Vector2(w * sin(angle), h * (1.0 - cos(angle))))
    else:
     # Concave ramp: x=w(1-cos(t)), y=h sin(t), centered at (w,0).
     # Closing through (0,h) leaves the wedge outside the quarter ellipse.
     result.append(Vector2(w * (1.0 - cos(angle)), h * sin(angle)))
   result[0] = Vector2.ZERO
   result[result.size() - 1] = Vector2(w, h)
   if family != "j_curve":
    result.append(Vector2(0, h))
  "circle", "oval":
   for step in range(CURVE_STEPS * 4):
    var angle := TAU * float(step) / (CURVE_STEPS * 4)
    result.append(Vector2(w * 0.5 * (1.0 + cos(angle)), h * 0.5 * (1.0 + sin(angle))))
   result[0] = Vector2(w, h * 0.5)
   result[CURVE_STEPS] = Vector2(w * 0.5, h)
   result[CURVE_STEPS * 2] = Vector2(0, h * 0.5)
   result[CURVE_STEPS * 3] = Vector2(w * 0.5, 0)
  "bump", "u_curve":
   for step in range(CURVE_STEPS * 2 + 1):
    var angle := PI * float(step) / (CURVE_STEPS * 2)
    var y := h * sin(angle)
    if family == "bump":
     y = h - y
    result.append(Vector2(w * 0.5 * (1.0 - cos(angle)), y))
   var base_y := h if family == "bump" else 0.0
   result[0] = Vector2(0, base_y)
   result[result.size() - 1] = Vector2(w, base_y)
   result[CURVE_STEPS] = Vector2(w * 0.5, 0.0 if family == "bump" else h)
  "capsule":
   # All canonical capsules are vertical. A square capsule is a circle.
   var radius := w * 0.5
   for step in range(CURVE_STEPS * 2 + 1):
    var angle := PI + PI * float(step) / (CURVE_STEPS * 2)
    result.append(Vector2(radius + radius * cos(angle), radius + radius * sin(angle)))
   result[0] = Vector2(0, radius)
   result[CURVE_STEPS] = Vector2(radius, 0)
   result[result.size() - 1] = Vector2(w, radius)
   for step in range(CURVE_STEPS * 2 + 1):
    # Avoid adjacent duplicate seam vertices when the capsule is a circle.
    if h == w and (step == 0 or step == CURVE_STEPS * 2):
     continue
    var angle := PI * float(step) / (CURVE_STEPS * 2)
    var point := Vector2(radius + radius * cos(angle), h - radius + radius * sin(angle))
    if step == 0:
     point = Vector2(w, h - radius)
    elif step == CURVE_STEPS:
     point = Vector2(radius, h)
    elif step == CURVE_STEPS * 2:
     point = Vector2(0, h - radius)
    result.append(point)
 return result
