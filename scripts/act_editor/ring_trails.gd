extends RefCounted
## Pure authoring geometry. Endpoints and spacing are exact local pixels.
const DEFAULT_SPACING_CELLS := 0.4
const MAX_RINGS := 4096

static func validation_error(trail: Variant) -> String:
 if not trail is Dictionary:
  return "Ring trail must be a dictionary."
 if trail.size() != 3 or not trail.has_all(["start", "end", "spacing"]):
  return "Ring trail needs only start, end and spacing."
 if not trail.start is Vector2 or not trail.end is Vector2 or not trail.start.is_finite() or not trail.end.is_finite():
  return "Ring endpoints must be finite local Vector2 coordinates."
 if typeof(trail.spacing) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(trail.spacing) or trail.spacing <= 0:
  return "Ring spacing must be finite and greater than zero."
 var intervals: float = trail.start.distance_to(trail.end) / float(trail.spacing)
 if not is_finite(intervals) or intervals > MAX_RINGS - 1:
  return "A ring trail may contain at most %d rings; increase its spacing." % MAX_RINGS
 return ""

static func positions(trail: Dictionary) -> PackedVector2Array:
 var result := PackedVector2Array()
 if not validation_error(trail).is_empty():
  return result
 var start: Vector2 = trail.start
 var end: Vector2 = trail.end
 if start == end:
  return PackedVector2Array([start])
 # Include both endpoints; fit equal intervals no wider than the chosen spacing.
 var intervals := maxi(1, ceili(start.distance_to(end) / float(trail.spacing)))
 for index in range(intervals + 1):
  result.append(start.lerp(end, float(index) / intervals))
 result[0] = start
 result[intervals] = end
 return result
