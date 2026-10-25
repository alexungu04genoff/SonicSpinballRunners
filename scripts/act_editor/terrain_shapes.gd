class_name TerrainShapes
extends RefCounted
## Authoring-only terrain library. All points are in canonical cell coordinates.
## Logical frames measure cells, not grid intersections or occupied-cell masks.
const VERSION := 2
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
 var definition := definition_for_placement(placement)
 if definition.is_empty() or typeof(placement.get("quarter_turns", 0)) != TYPE_INT:
  return Vector2i.ZERO
 var size: Vector2i = definition.size
 return Vector2i(size.y, size.x) if posmod(placement.get("quarter_turns", 0), 2) else size

static func transformed_points(placement: Dictionary) -> PackedVector2Array:
 var definition := definition_for_placement(placement)
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

static func definition_for_placement(placement: Dictionary) -> Dictionary:
 # Composite outlines are final authored geometry, not catalogue primitives.
 # Validation belongs to ActGeometry; this lookup never repairs stored points.
 if typeof(placement.get("shape_id")) != TYPE_STRING:
  return {}
 if placement.shape_id == "composite":
  if typeof(placement.get("base_size")) != TYPE_VECTOR2I or typeof(placement.get("outline")) != TYPE_PACKED_VECTOR2_ARRAY:
   return {}
  return {"id": "composite", "family": "Composite terrain", "label": "Composite terrain",
   "size": placement.base_size, "closed": true, "points": placement.outline.duplicate(), "color": Color("99dfbd")}
 return get_definition(placement.shape_id)

static func _build_catalogue() -> void:
 var narrow: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)]
 var corners: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 3)]
 var squares: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3)]
 var rounded: Array[Vector2i] = [Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 3)]
 var wedges: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 2), Vector2i(3, 2), Vector2i(3, 3)]
 var u_sizes: Array[Vector2i] = [Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 3)]
 var s_sizes: Array[Vector2i] = [Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 2), Vector2i(3, 3)]
 var bumps: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3)]
 _add_family("wall", "Straight walls", "Wall", narrow, false, Color("81d4fa"))
 _add_family("corner", "Open L corners", "L corner", corners, false, Color("80cbc4"))
 _add_pair("triangle", "Triangle", "diagonal", "Diagonal rail", "Triangles / diagonals", wedges, Color("ffc778"), Color("ffc49e"))
 _add_pair("slope", "Curved slope", "j_curve", "J curve", "Slopes / J curves", corners, Color("8bd3a8"), Color("87dce5"))
 _add_pair("u_band", "Filled U", "u_curve", "U curve", "U curves", u_sizes, Color("8cbbe7"), Color("aad7fa"))
 _add_pair("s_band", "Filled S", "s_curve", "S curve", "S curves", s_sizes, Color("d99dda"), Color("edbfee"))
 _add_family("rectangle", "Squares / rectangles", "Rectangle", [Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3), Vector2i(1, 2), Vector2i(1, 3)], true, Color("a9bafa"))
 _add_family("circle", "Circles", "Circle", squares, true, Color("f1a3bb"))
 _add_family("oval", "Ovals", "Oval", rounded, true, Color("d3a5e8"))
 _add_family("bump", "Half-ellipse bumps", "Bump", bumps, true, Color("e3d47e"))
 _add_family("capsule", "Capsules", "Capsule", rounded, true, Color("b7cd92"))
 _add_family("outer_corner", "Rounded outer corners", "Outer corner", squares, true, Color("d7b18d"))

static func _add_pair(solid_id: String, solid_label: String, wall_id: String, wall_label: String, family: String, sizes: Array[Vector2i], solid_color: Color, wall_color: Color) -> void:
 for size: Vector2i in sizes:
  _add_family(solid_id, family, solid_label, [size], true, solid_color)
  _add_family(wall_id, family, wall_label, [size], false, wall_color)

static func _add_family(prefix: String, family: String, label: String, sizes: Array[Vector2i], closed: bool, color: Color) -> void:
 for size: Vector2i in sizes:
  var definition := {
   "id": "%s_%dx%d" % [prefix, size.x, size.y],
   "family": family,
   "label": "%s %d×%d" % [label, size.x, size.y],
   "size": size,
   "closed": closed,
   "points": _canonical_points(prefix, size),
   "color": color,
  }
  _catalogue.append(definition)

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
  "u_band":
   result = _canonical_points("u_curve", size)
   # Fill below the exact wall curve to the frame bottom. The two solid sides
   # meet where the U touches that bottom edge; the bowl above stays empty.
   result.append(Vector2(w, h))
   result.append(Vector2(0, h))
  "s_curve", "s_band":
   # Smoothstep has vertical end tangents and exactly one inflection at t=1/2.
   var steps := CURVE_STEPS * 2
   for step in range(steps + 1):
    var t := float(step) / steps
    var x := w * t * t * (3.0 - 2.0 * t)
    result.append(Vector2(x, h * t))
   result[0] = Vector2.ZERO
   result[steps] = Vector2(w, h)
   if family == "s_band":
    # The curve already ends at the bottom-right corner. Close along the bottom
    # and left edges to fill the entire area below it, rather than a ribbon.
    result.append(Vector2(0, h))
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
