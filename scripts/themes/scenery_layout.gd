extends RefCounted
## Authoring/bake-only deterministic plans. Never uses Godot's global RNG.
var seed_value := 0
var density := 1.0
var theme := ""
var occupied: Array[Dictionary] = []

func _init(values: Dictionary = {}, theme_id := "") -> void:
 seed_value = int(values.get("seed", 0))
 density = clampf(float(values.get("density", 1.0)), 0.5, 1.5)
 theme = theme_id

func rng(stream: String) -> RandomNumberGenerator:
 var result := RandomNumberGenerator.new()
 result.seed = ("%d/%s/%s" % [seed_value, theme, stream]).sha256_text().substr(0, 15).hex_to_int()
 return result

func varied(stream: String, authored: float, amount: float) -> float:
 return authored if seed_value == 0 else authored + rng(stream).randf_range(-amount, amount)

func choice(stream: String, authored: int, count: int) -> int:
 return authored if seed_value == 0 else rng(stream).randi_range(0, count - 1)

func plans(authored: Array) -> Array[Dictionary]:
 var result: Array[Dictionary] = []
 var count := clampi(roundi(authored.size() * density), 1, 3)
 var flip := -1 if seed_value != 0 and rng("sides").randi_range(0, 1) == 1 else 1
 for index in count:
  var plan: Dictionary = authored[index % authored.size()].duplicate(true)
  plan.id = index
  if index >= authored.size(): plan.at = authored[(index + 1) % authored.size()].at
  plan.side = int(plan.side) * flip
  plan.at = clampf(varied("position/" + str(index), float(plan.at), 0.075), 0.12, 0.88)
  result.append(plan)
 return result

func fit(bounds: Rect2, side: int, requested_y: float, half_span: float) -> float:
 # Conservative longitudinal footprints keep groups apart, including the
 # optional third group. A short Act can legitimately reject a dense candidate.
 var margin := minf(16.0, bounds.size.y * 0.02)
 if half_span * 2.0 + margin * 2.0 > bounds.size.y: return NAN
 var y := clampf(requested_y, bounds.position.y + half_span + margin, bounds.end.y - half_span - margin)
 for previous: Dictionary in occupied:
  if previous.side == side and absf(y - previous.y) < half_span + previous.half_span + 30.0: return NAN
 occupied.append({"side": side, "y": y, "half_span": half_span})
 return y

func place_group(p: Node3D, group: Node3D, side: int, fraction: float, gap: float, height: float) -> bool:
 # Inspect the existing prop vocabulary after its safe scale/yaw variation.
 # The entire rotated footprint clears the real contour, not only its origin.
 var box := group_bounds(group)
 var center_z := box.get_center().z
 var requested_y: float = lerpf(p.table_bounds.position.y, p.table_bounds.end.y, fraction) + center_z / p.SCALE
 var y := fit(p.table_bounds, side, requested_y, box.size.z * 0.5 / p.SCALE)
 if not is_finite(y): return false
 var edge: float = p.theme_definition.scenery_side_edge(p, side, y, box.size.z * 0.5 / p.SCALE)
 group.position = Vector3((edge + side * gap) * p.SCALE - (box.end.x if side < 0 else box.position.x), height, y * p.SCALE - center_z)
 return true

static func group_bounds(root: Node3D) -> AABB:
 var result := AABB()
 var found := false
 var pending: Array = [[root, Transform3D.IDENTITY]]
 while not pending.is_empty():
  var item: Array = pending.pop_back()
  var node: Node3D = item[0]
  var transform: Transform3D = item[1] * node.transform
  if node is MeshInstance3D and node.mesh != null:
   var box: AABB = transform * node.mesh.get_aabb()
   result = result.merge(box) if found else box
   found = true
  for child: Node in node.get_children():
   if child is Node3D: pending.append([child, transform])
 return result
