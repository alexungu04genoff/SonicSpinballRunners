extends RefCounted
## Arc-length samples shared by authoring, runtime pickup data and baked visuals.
const Path = preload("res://scripts/authored_act/rail_path.gd")
const MAX_RINGS := 4096

static func samples(placement: Dictionary, properties: Dictionary) -> Array[Dictionary]:
 var result: Array[Dictionary] = []
 if not properties.get("rings_enabled", true): return result
 var control: PackedVector2Array = properties.points.duplicate()
 var angle := deg_to_rad(float(placement.rotation_degrees))
 for i in control.size(): control[i] = placement.position + control[i].rotated(angle)
 var path := Path.build(control)
 if path.length <= 0.0: return result
 var spacing := clampf(float(properties.get("ring_spacing", 25.0)), 12.0, 200.0)
 # A centered sequence with at least half a spacing clear of each mouth.
 var count := mini(MAX_RINGS, floori(path.length / spacing))
 var first: float = (path.length - (count - 1) * spacing) * 0.5
 for i in count:
  var distance := first + i * spacing
  result.append({"position": Path.sample(path, distance), "distance": distance,
   "height": Path.height(path, distance, float(properties.height))})
 return result
