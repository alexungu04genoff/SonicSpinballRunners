extends RefCounted
## Pure authoring geometry. Endpoints and spacing are exact local pixels.
const DEFAULT_SPACING_CELLS := 0.4
const MAX_RINGS := 4096
const SCORING_KEYS := ["pattern_id", "bonus_rack", "completion_bonus", "timeout", "respawn_delay"]

static func scoring_settings(trail: Dictionary) -> Dictionary:
 var bonus := bool(trail.get("bonus_rack", false))
 return {"bonus_rack": bonus, "completion_bonus": int(trail.get("completion_bonus", 500)) if bonus else 0, "timeout": float(trail.get("timeout", 12.0 if bonus else 25.0)), "respawn_delay": float(trail.get("respawn_delay", 11.0 if bonus else 18.0))}

static func migrate_legacy_timing(trail: Dictionary) -> void:
 # Formats 15/16 generated this exact default signature. A changed timeout or
 # reward is evidence of author tuning: preserve the entire explicit recipe.
 if trail.get("respawn_delay") != 1.0 or trail.get("timeout", 12.0) != 12.0 or trail.get("completion_bonus", 500) != 500: return
 var bonus := bool(trail.get("bonus_rack", false))
 trail.respawn_delay = 11.0 if bonus else 18.0
 trail.timeout = 12.0 if bonus else 25.0

static func pattern_id(trail: Dictionary, index: int) -> String:
 return str(trail.get("pattern_id", "ring_pattern_%d" % index))

static func _scoring_error(trail: Dictionary) -> String:
 if trail.has("pattern_id") and (not trail.pattern_id is String or trail.pattern_id.is_empty() or trail.pattern_id.length() > 128):
  return "Ring pattern ID must be a nonempty string of at most 128 characters."
 if trail.has("bonus_rack") and typeof(trail.bonus_rack) != TYPE_BOOL:
  return "Bonus Rack must be boolean."
 if trail.has("completion_bonus") and (typeof(trail.completion_bonus) != TYPE_INT or trail.completion_bonus < 0 or trail.completion_bonus > 100000):
  return "Ring completion bonus must be an integer from 0 to 100000."
 for key: String in ["timeout", "respawn_delay"]:
  if not trail.has(key): continue
  var value: Variant = trail[key]
  var maximum := 300.0 if key == "timeout" else 60.0
  if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(value) or value < 0.1 or value > maximum:
   return "Ring %s must be from 0.1 to %.0f seconds." % [key, maximum]
 return ""

static func _allowed_keys(trail: Dictionary, geometry_keys: Array) -> bool:
 if not trail.has_all(geometry_keys): return false
 for key: Variant in trail:
  if key not in geometry_keys and key not in SCORING_KEYS: return false
 return true

static func validation_error(trail: Variant) -> String:
 if not trail is Dictionary:
  return "Ring trail must be a dictionary."
 var scoring_error := _scoring_error(trail)
 if not scoring_error.is_empty(): return scoring_error
 if trail.get("kind") == "ellipse":
  return _ellipse_error(trail)
 if not _allowed_keys(trail, ["start", "end", "spacing"]):
  return "Ring trail needs start, end and spacing, plus optional rack settings."
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
 if trail.get("kind") == "ellipse": return _ellipse_positions(trail)
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

static func _ellipse_error(trail: Dictionary) -> String:
 if not _allowed_keys(trail, ["kind", "start", "end", "spacing", "fill", "rotation_degrees"]):
  return "Ellipse needs kind, start/end bounds, spacing, fill and rotation_degrees."
 if not trail.start is Vector2 or not trail.end is Vector2 or not trail.start.is_finite() or not trail.end.is_finite():
  return "Ellipse bounds must be finite Vector2 coordinates."
 if typeof(trail.spacing) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(trail.spacing) or trail.spacing <= 0:
  return "Ellipse spacing must be finite and greater than zero."
 if typeof(trail.fill) != TYPE_BOOL or typeof(trail.rotation_degrees) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(trail.rotation_degrees):
  return "Ellipse fill must be boolean and rotation must be finite."
 var radii: Vector2 = (trail.end - trail.start).abs() * 0.5
 if not radii.is_finite() or minf(radii.x, radii.y) < 1.0: return "Ellipse radii must be at least 1 pixel."
 # Bound the candidate grid as well as output size, including extreme aspect ratios.
 var estimate := (ceilf(radii.x * 2.0 / trail.spacing) + 3) * (ceilf(radii.y * 2.0 / (trail.spacing * sqrt(0.75))) + 3) if trail.fill else ceilf(TAU * maxf(radii.x, radii.y) / trail.spacing)
 if not is_finite(estimate) or estimate > MAX_RINGS: return "Ellipse exceeds 4096 candidates; increase spacing."
 return ""

static func _ellipse_positions(trail: Dictionary) -> PackedVector2Array:
 var result := PackedVector2Array()
 var center: Vector2 = (trail.start + trail.end) * 0.5
 var radii: Vector2 = (trail.end - trail.start).abs() * 0.5
 var spacing := float(trail.spacing)
 var angle := deg_to_rad(float(trail.rotation_degrees))
 if trail.fill:
  # Centered hex rows keep uniform nearest-neighbor distance and include the center.
  var row_height := spacing * sqrt(0.75)
  var rows := floori(radii.y / row_height)
  var columns := ceili(radii.x / spacing)
  for row in range(-rows, rows + 1):
   for column in range(-columns, columns + 1):
    var point := Vector2((column + 0.5 * posmod(row, 2)) * spacing, row * row_height)
    if (point / radii).length_squared() <= 1.000001:
     result.append(center + point.rotated(angle))
 else:
  # Arc-length resampling avoids crowding the narrow ends of an ellipse.
  var outline := PackedVector2Array()
  var lengths := PackedFloat64Array([0.0])
  for i in 513:
   outline.append(Vector2.from_angle(TAU * i / 512.0) * radii)
   if i > 0: lengths.append(lengths[-1] + outline[i].distance_to(outline[i - 1]))
  var count := maxi(4, ceili(lengths[-1] / spacing))
  for i in count:
   var distance := lengths[-1] * i / count
   var segment := clampi(lengths.bsearch(distance), 1, 512)
   var point := outline[segment - 1].lerp(outline[segment], (distance - lengths[segment - 1]) / (lengths[segment] - lengths[segment - 1]))
   result.append(center + point.rotated(angle))
 return result
