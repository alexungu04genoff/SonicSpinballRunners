extends Node
## Shared scoring queries drive visual overlays without changing authored materials.
var game: Node
var targets: Array[Dictionary] = []
var glow := StandardMaterial3D.new()

func _ready() -> void:
 glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
 glow.albedo_color = Color(0.25, 0.85, 1.0, 0.225)
 rebuild()

func rebuild() -> void:
 for target: Dictionary in targets:
  if is_instance_valid(target.halo): target.halo.queue_free()
  for record: Dictionary in target.meshes:
   var mesh: MeshInstance3D = record.ref.get_ref()
   if is_instance_valid(mesh): mesh.material_overlay = record.original
 targets.clear()
 if game.active == null: return
 for item: Dictionary in game.active.runtime.objects:
  if not item.body.has_meta("bumper"): continue
  var visual: Node3D = game.presentation.bumper_visuals.get(item.body.get_instance_id())
  if visual == null: continue
  var meshes: Array[Dictionary] = []
  var nodes := visual.find_children("*", "MeshInstance3D", true, false)
  if visual is MeshInstance3D: nodes.append(visual)
  for mesh: MeshInstance3D in nodes:
   meshes.append({"ref": weakref(mesh), "original": mesh.material_overlay})
  targets.append({"body": weakref(item.body), "meshes": meshes, "lit": false, "halo": _halo(item.body.global_position, float(item.get("radius", game.active.document.cell_size * 0.4)))})
 for index in mini(game.presentation.ring_visuals.size(), game.ring_field.rings.size()):
  var ring: Dictionary = game.ring_field.rings[index]
  if ring.rack.owner_id != game.ring_field.active_owner_id: continue
  var mesh: MeshInstance3D = game.presentation.ring_visuals[index]
  targets.append({"ring": index, "meshes": [{"ref": weakref(mesh), "original": mesh.material_overlay}], "lit": false, "halo": _halo(ring.position, game.ring_field.ring_radius)})

func _process(_delta: float) -> void:
 var available: bool = game.started and not game.closing and not game.finished and not game.drafting and not is_instance_valid(game.transfer)
 for target: Dictionary in targets:
  var lit := false
  if available:
   if target.has("body"):
    lit = game.scorecraft.bumper_can_build_multiplier(target.body.get_ref())
   elif target.ring < game.ring_field.rings.size():
    lit = game.ring_field.rings[target.ring].active and game.scorecraft.rings_can_build_multiplier()
  if lit == target.lit: continue
  target.lit = lit
  target.halo.visible = lit
  for record: Dictionary in target.meshes:
   var mesh: MeshInstance3D = record.ref.get_ref()
   if is_instance_valid(mesh): mesh.material_overlay = glow if lit else record.original

func _halo(at: Vector2, radius: float) -> MeshInstance3D:
 var marker := MeshInstance3D.new()
 var plane := PlaneMesh.new()
 plane.size = Vector2.ONE * (radius + 6.0) * 2.0 * TablePresentation.SCALE
 marker.mesh = plane
 var material := ShaderMaterial.new()
 material.shader = preload("res://scripts/prototype/combo_halo.gdshader")
 marker.material_override = material
 marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 marker.position = TablePresentation.map_point(at, 0.012)
 marker.visible = false
 game.presentation.add_child(marker)
 return marker
