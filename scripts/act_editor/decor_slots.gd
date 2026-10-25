extends RefCounted
## Theme-independent authoring records. No meshes, collision, or gameplay behavior.
const TYPES := ["small", "medium", "large", "landmark"]
const HINTS := ["surface", "edge", "either"]
const RADII := [0.10, 0.17, 0.25, 0.36]
const COLORS := [Color("f4db80"), Color("9cdeb0"), Color("d6a8ff"), Color("ffab8c")]
const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")

static func new_id() -> String:
 return Crypto.new().generate_random_bytes(16).hex_encode()

static func make_slot(slot_type: String) -> Dictionary:
 return {"slot_id": new_id(), "slot_type": slot_type, "placement_hint": "either",
  "position": Vector2.ZERO, "rotation_degrees": 0.0, "variant_mode": "auto", "scale": 1.0}

static func validation_error(slot: Variant) -> String:
 if not slot is Dictionary: return "slot must be a dictionary."
 if typeof(slot.get("slot_id")) != TYPE_STRING or slot.slot_id.is_empty(): return "slot_id must be a nonempty string."
 if slot.get("slot_type") not in TYPES: return "unknown slot_type."
 if slot.get("placement_hint") not in HINTS: return "unknown placement_hint."
 if typeof(slot.get("position")) != TYPE_VECTOR2 or not slot.position.is_finite(): return "position must be a finite local-pixel Vector2."
 if typeof(slot.get("rotation_degrees")) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(slot.rotation_degrees): return "rotation_degrees must be finite."
 if slot.get("variant_mode", "auto") != "auto": return "only auto variant_mode is supported."
 var size: Variant = slot.get("scale", 1.0)
 if typeof(size) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(size) or size < 0.85 or size > 1.15: return "scale must be between 0.85 and 1.15."
 for key: Variant in slot:
  if key not in ["slot_id", "slot_type", "placement_hint", "position", "rotation_degrees", "variant_mode", "scale"]:
   return "unrecognized decor field; store generic slots, not theme assets."
 return ""

static func fingerprint_records(slots: Variant) -> Array:
 if not slots is Array: return [slots]
 var records: Array = []
 for slot: Variant in slots:
  if not slot is Dictionary:
   records.append(slot)
   continue
  var angle: Variant = slot.get("rotation_degrees")
  var size: Variant = slot.get("scale", 1.0)
  if typeof(angle) in [TYPE_INT, TYPE_FLOAT]: angle = float(angle)
  if typeof(size) in [TYPE_INT, TYPE_FLOAT]: size = float(size)
  records.append([slot.get("slot_id"), slot.get("slot_type"), slot.get("placement_hint"), slot.get("position"), angle, slot.get("variant_mode", "auto"), size])
 return records

static func supported_by_terrain(point: Vector2, terrain: Array, cell_size: float) -> bool:
 # Test the exact raised silhouette, including narrow open-wall ribbons. A hint
 # selects a variant pool; it never snaps or relocates an authored anchor.
 for item: Dictionary in terrain:
  var points: PackedVector2Array = item.points
  if item.closed and Geometry2D.is_point_in_polygon(point, points): return true
  var count := points.size() if item.closed else points.size() - 1
  var tolerance := 0.001 if item.closed else cell_size * 0.02
  for i in count:
   if Geometry2D.get_closest_point_to_segment(point, points[i], points[(i + 1) % points.size()]).distance_to(point) <= tolerance:
    return true
 return false

static func supported_in_document(point: Vector2, document: Resource) -> bool:
 var terrain: Array = []
 for placement: Dictionary in document.placements:
  var points: PackedVector2Array = Shapes.transformed_points(placement)
  for i in points.size(): points[i] = (points[i] + Shapes.placement_position(placement)) * float(document.cell_size)
  terrain.append({"points": points, "closed": Shapes.definition_for_placement(placement).closed})
 return supported_by_terrain(point, terrain, float(document.cell_size))
