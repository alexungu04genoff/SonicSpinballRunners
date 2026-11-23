extends RefCounted
## Collisionless Badnik presentation for authored and streamed Acts.
const Runners = preload("res://scripts/enemies/runners_badnik.gd")
const VISUAL_SCALE := 0.39
const HOVER_HEIGHT := 10.5
static var death_effect := _death_effect_option()

static func _death_effect_option() -> String:
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--buzz-death-effect="):
   var value := argument.trim_prefix("--buzz-death-effect=")
   if value in ["opaque", "legacy", "off"]: return value
   push_warning("Unknown Buzz death effect; using opaque.")
 return "opaque"

static func build(table: TablePresentation, parent: Node3D, item: Dictionary) -> Dictionary:
 var root := Node3D.new()
 root.name = "BuzzBomber_" + str(item.object_id)
 root.position = table.map_point(item.position)
 root.scale = Vector3.ONE * float(item.properties.scale) * VISUAL_SCALE
 parent.add_child(root)
 var pose := Node3D.new()
 root.add_child(pose)
 var body := Node3D.new()
 pose.add_child(body)
 var wings: Array[Node3D] = []
 var flash := _sphere(table, pose, Vector3.ZERO, Vector3(38, 38, 30), table.material(Color("fff1a0"), 0.0))
 flash.visible = false
 var entry := {"item": item, "root": root, "pose": pose, "body": body, "wings": wings, "flash": flash, "base": root.position}
 return entry

static func bind(entry: Dictionary, table: TablePresentation) -> void:
 # Older baked recipes can contain the original procedural wasp under this pivot.
 for child: Node3D in entry.body.get_children(): child.hide()
 entry.wings = []
 entry.base.y = HOVER_HEIGHT * table.SCALE if entry.item.skin == "beeton" else 0.0
 entry.erase("last_turn_time")
 if not Runners.bind(entry):
  match entry.item.skin:
   "ganigani": _crab(table, entry.body)
   "eggpawn": _pawn(table, entry.body)
   "beeton": _buzz(table, entry.body, entry.wings)
 update(entry, 0.0, table)

static func _pawn(table: TablePresentation, body: Node3D) -> void:
 var orange := table.material(Color("f7a028"), 0.25)
 var dark := table.material(Color("32343e"))
 var eye := table.material(Color("63e8ef"))
 _sphere(table, body, Vector3(0, 20, 0), Vector3(30, 32, 23), orange)
 for side: float in [-1.0, 1.0]:
  _sphere(table, body, Vector3(side * 6, 25, 10), Vector3(7, 6, 3), eye)
  _sphere(table, body, Vector3(side * 18, 15, 0), Vector3(9, 12, 9), orange)
  _sphere(table, body, Vector3(side * 8, 4, 1), Vector3(12, 8, 16), dark)

static func _crab(table: TablePresentation, body: Node3D) -> void:
 var red := table.material(Color("cf322f"), 0.25)
 var steel := table.material(Color("c7d9e0"), 0.4)
 _sphere(table, body, Vector3(0, 12, 0), Vector3(34, 21, 26), red)
 for side: float in [-1.0, 1.0]:
  _cone(table, body, Vector3(side * 10, 12, 0), Vector3(side * 21, 21, 3), 3, 3, steel)
  _sphere(table, body, Vector3(side * 22, 24, 4), Vector3(15, 18, 12), red)
  for z: float in [-6.0, 6.0]:
   _cone(table, body, Vector3(side * 10, 10, z), Vector3(side * 18, 1, z), 3, 1, steel)

static func _buzz(table: TablePresentation, body: Node3D, wings: Array) -> void:
 var blue := table.material(Color("178ed2"), 0.25)
 var cyan := table.material(Color("36b9e8"), 0.2)
 var dark := table.material(Color("142330"), 0.25)
 var stripe := table.material(Color("153f99"), 0.25)
 var gold := table.material(Color("ffc536"), 0.3)
 var silver := table.material(Color("b9cedb"), 0.4)
 var wing_material := table.material(Color("d7edf1"), 0.1)
 var white := table.material(Color("f6f5e8"), 0.05)
 var pupil := table.material(Color("062237"), 0.05)
 _sphere(table, body, Vector3(-3, 3, 0), Vector3(30, 28, 25), dark)
 _abdomen(table, body, blue, stripe)
 _cone(table, body, Vector3(12, -34, 0), Vector3(17, -45, 0), 4.5, 0, silver)
 _sphere(table, body, Vector3(15, 7, 0), Vector3(25, 25, 23), cyan)
 # Paired eyes, jaws and antennae remain visible when the enemy turns around.
 for side in [-1.0, 1.0]:
  _sphere(table, body, Vector3(24, 10, side * 7), Vector3(10, 14, 10), white)
  _sphere(table, body, Vector3(28, 10, side * 8.5), Vector3(3, 6, 4), pupil)
  _cone(table, body, Vector3(24, -1, side * 7), Vector3(21, -10, side * 4.5), 4, 0, silver)
  _cone(table, body, Vector3(13, 17, side * 7), Vector3(16, 27, side * 8), 1.3, 1.0, gold)
  _sphere(table, body, Vector3(20, 27, side * 8), Vector3(15, 4, 6), gold)
  # Stubby cylindrical silver arms, not the previous long rectangular legs.
  _sphere(table, body, Vector3(1, -3, side * 15), Vector3(9, 9, 9), silver)
  _cone(table, body, Vector3(1, -3, side * 16), Vector3(-16, -3, side * 16), 5, 5, silver)
  _cone(table, body, Vector3(-16, -3, side * 16), Vector3(-18, -3, side * 16), 5.5, 5.5, dark)
 for side in [-1.0, 1.0]:
  var hinge := Node3D.new()
  hinge.position = Vector3(-9, 13, side * 6) * table.SCALE
  body.add_child(hinge)
  _wing(table, hinge, Vector3.ZERO, Vector3(-25, 27, side * 5), 4.5, wing_material)
  _wing(table, hinge, Vector3.ZERO, Vector3(-32, 14, side * 6), 4.0, wing_material)
  wings.append(hinge)

static func _sphere(table: TablePresentation, parent: Node3D, at: Vector3, size_value: Vector3, material: Material) -> MeshInstance3D:
 var mesh := SphereMesh.new()
 mesh.radius = 0.5
 mesh.height = 1.0
 mesh.radial_segments = 10
 mesh.rings = 4
 var node := table.mesh_node(mesh, material, at * table.SCALE, parent)
 node.scale = size_value * table.SCALE
 return node

static func _cone(table: TablePresentation, parent: Node3D, start: Vector3, end: Vector3, start_radius: float, end_radius: float, material: Material) -> MeshInstance3D:
 var mesh := CylinderMesh.new()
 mesh.bottom_radius = start_radius * table.SCALE
 mesh.top_radius = end_radius * table.SCALE
 mesh.height = start.distance_to(end) * table.SCALE
 mesh.radial_segments = 10
 var node := table.mesh_node(mesh, material, (start + end) * 0.5 * table.SCALE, parent)
 node.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
 return node

static func _abdomen(table: TablePresentation, parent: Node3D, blue: Material, stripe: Material) -> void:
 # Tapered blue shell with narrow cobalt bands, swept forward below the thorax.
 var sections := [Vector3(0, -7, 7), Vector3(2, -12, 12), Vector3(3, -14, 12.8), Vector3(5, -20, 13.5), Vector3(6, -22, 12.6), Vector3(9, -28, 9), Vector3(10, -30, 7), Vector3(12, -34, 3.5)]
 for i in sections.size() - 1:
  var a: Vector3 = sections[i]
  var b: Vector3 = sections[i + 1]
  _cone(table, parent, Vector3(a.x, a.y, 0), Vector3(b.x, b.y, 0), a.z, b.z, stripe if i in [1, 3, 5] else blue)

static func _wing(table: TablePresentation, parent: Node3D, start: Vector3, end: Vector3, width: float, material: Material) -> void:
 # A tapered, six-sided blade has a clear sprite-like silhouette at table scale.
 var direction := (end - start).normalized()
 var across := Vector3(-direction.y, direction.x, 0).normalized() * width
 var points := [start, start.lerp(end, 0.25) + across, start.lerp(end, 0.85) + across * 0.65, end, start.lerp(end, 0.85) - across * 0.65, start.lerp(end, 0.25) - across]
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for side in [-1.0, 1.0]:
  for i in range(1, points.size() - 1):
   var triangle := [points[0], points[i], points[i + 1]] if side > 0 else [points[0], points[i + 1], points[i]]
   for point: Vector3 in triangle: surface.add_vertex((point + Vector3(0, 0, side * 0.6)) * table.SCALE)
 for i in points.size():
  var a: Vector3 = points[i]
  var b: Vector3 = points[(i + 1) % points.size()]
  for point: Vector3 in [a + Vector3(0, 0, 0.6), b + Vector3(0, 0, 0.6), a - Vector3(0, 0, 0.6), a - Vector3(0, 0, 0.6), b + Vector3(0, 0, 0.6), b - Vector3(0, 0, 0.6)]: surface.add_vertex(point * table.SCALE)
 surface.generate_normals()
 table.mesh_node(surface.commit(), material, Vector3.ZERO, parent)

static func update(entry: Dictionary, elapsed: float, table: TablePresentation) -> void:
 var item: Dictionary = entry.item
 var root: Node3D = entry.root
 var appearing: bool = item.get("respawn_ready", false) and item.get("respawn_fade", 0.0) > 0.0
 root.visible = item.alive or item.death_remaining > 0.0 or appearing
 var displacement: Vector2 = item.position - item.anchor
 var skin: String = item.get("skin", "beeton")
 var bee := skin == "beeton"
 var bob := sin(elapsed * 3.8) * 0.7 if bee else 0.0
 root.position = entry.base + Vector3(displacement.x, bob, displacement.y) * TablePresentation.SCALE
 var angle := deg_to_rad(float(item.get("rotation_degrees", 0.0)))
 var view := Basis(Vector3.RIGHT, -PI / 3.0)
 if is_instance_valid(table.camera): view = table.camera.global_basis.orthonormalized()
 var path := Vector3(cos(angle), 0.0, sin(angle)) * float(item.direction)
 var travel := Vector2(path.dot(view.x), path.dot(view.y)).normalized()
 var moving: bool = item.alive and item.get("pause_remaining", 0.0) <= 0.0 and not Vector2(item.position).is_equal_approx(item.get("previous_position", item.position))
 var delta := maxf(0.0, elapsed - float(entry.get("last_turn_time", elapsed)))
 # Show a three-quarter profile on lateral patrols. Uphill and downhill still turn
 # along the authored path. Keep each figure upright on reversed and diagonal paths.
 var facing := atan2(travel.x, 0.4 - travel.y) if moving else 0.0
 var pitch := 0.0
 match skin:
  "beeton":
   pitch = -8.0
   if not moving: facing = deg_to_rad(-32.0) if entry.has("player") else 0.0
   if not entry.has("player"): facing -= PI / 2.0 # The procedural nose points along +X.
  "ganigani":
   pitch = -15.0
   facing = deg_to_rad(12.0) * travel.x if moving else 0.0 # Crabs sidestep.
  "eggpawn":
   pitch = 12.0
   if not moving and entry.has("player"):
    # The two source idles already turn the chest in opposite directions.
    facing = deg_to_rad(42.0 if item.direction > 0.0 else -35.0)
 entry.pose.basis = view * Basis(Vector3.RIGHT, deg_to_rad(pitch))
 if entry.has("last_turn_time"):
  entry.body.rotation.y = lerp_angle(entry.body.rotation.y, facing, 1.0 - exp(-delta * 12.0))
 else: entry.body.rotation.y = facing
 entry.last_turn_time = elapsed
 entry.body.visible = item.alive or appearing
 entry.body.scale = Vector3.ONE * (float(item.respawn_fade) / 0.35 if appearing else 1.0)
 update_death_flash(entry, death_effect)
 if entry.has("player"):
  if item.alive or appearing: Runners.advance(entry, moving, delta)
 elif item.alive:
  for i in entry.wings.size():
   entry.wings[i].rotation.y = sin(elapsed * 45) * 0.16 * (-1 if i == 0 else 1)
   entry.wings[i].rotation.z = sin(elapsed * 45) * 0.06

static func update_death_flash(entry: Dictionary, mode: String) -> void:
 var showing: bool = not entry.item.alive and entry.item.death_remaining > 0.0
 entry.flash.visible = showing and mode != "off"
 if not showing: return
 var progress := clampf(1.0 - float(entry.item.death_remaining) / 0.28, 0.0, 1.0)
 if mode == "legacy":
  # Explicit diagnostic comparison with the original runtime transparent path.
  entry.flash.scale = Vector3(38, 38, 30) * TablePresentation.SCALE * (1.0 + progress * 1.5)
  entry.flash.transparency = progress
 else:
  # Keep the existing opaque material/pipeline. A quick pop and shrink replace
  # alpha fading; no runtime material, shader, particle or mesh is constructed.
  entry.flash.transparency = 0.0
  var size := lerpf(0.6, 1.3, progress / 0.2) if progress < 0.2 else 1.3 * (1.0 - smoothstep(0.2, 1.0, progress))
  entry.flash.scale = Vector3(38, 38, 30) * TablePresentation.SCALE * maxf(0.001, size)
