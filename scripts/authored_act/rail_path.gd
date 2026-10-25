extends RefCounted
## One deterministic Catmull-Rom route shared by the editor, physics and renderer.
const SAMPLES_PER_SPAN := 20

static func validation_error(value: Variant) -> String:
 if typeof(value) != TYPE_PACKED_VECTOR2_ARRAY or value.size() < 2 or value.size() > 64:
  return "A rail needs 2–64 control points."
 for i in value.size():
  if not value[i].is_finite() or value[i].length() > 10000.0:
   return "Rail control points must be finite and within 10000 pixels of the origin."
  if i > 0 and value[i].distance_to(value[i - 1]) < 12.0:
   return "Adjacent rail points must be at least 12 pixels apart."
 return ""

static func build(control: PackedVector2Array) -> Dictionary:
 var points := PackedVector2Array()
 var lengths := PackedFloat32Array([0.0])
 if control.size() < 2: return {"points": control, "lengths": lengths, "length": 0.0}
 for i in control.size() - 1:
  var a := control[maxi(0, i - 1)]
  var b := control[i]
  var c := control[i + 1]
  var d := control[mini(control.size() - 1, i + 2)]
  for step in SAMPLES_PER_SPAN:
   var t := float(step) / SAMPLES_PER_SPAN
   points.append(0.5 * ((2.0 * b) + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t + (-a + 3.0 * b - 3.0 * c + d) * t * t * t))
 points.append(control[-1])
 for i in range(1, points.size()): lengths.append(lengths[-1] + points[i].distance_to(points[i - 1]))
 return {"points": points, "lengths": lengths, "length": float(lengths[-1])}

static func sample(path: Dictionary, distance: float) -> Vector2:
 var d := clampf(distance, 0.0, path.length)
 for i in range(1, path.points.size()):
  if d <= path.lengths[i]:
   var span: float = path.lengths[i] - path.lengths[i - 1]
   return path.points[i - 1].lerp(path.points[i], (d - path.lengths[i - 1]) / maxf(0.0001, span))
 return path.points[-1]

static func tangent(path: Dictionary, distance: float) -> Vector2:
 return (sample(path, distance + 0.5) - sample(path, distance - 0.5)).normalized()

static func height(path: Dictionary, distance: float, peak: float) -> float:
 var f := clampf(distance / maxf(1.0, path.length), 0.0, 1.0)
 return peak * smoothstep(0.0, 0.22, f) * smoothstep(0.0, 0.22, 1.0 - f)
