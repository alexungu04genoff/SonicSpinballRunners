extends Node
## Shared scoring queries drive visual overlays without changing authored materials.
var game: Node
var targets: Array[Dictionary] = []
var glow := ShaderMaterial.new()

func _ready() -> void:
 glow.shader = preload("res://scripts/prototype/combo_halo.gdshader")
 rebuild()

func rebuild() -> void:
 for target: Dictionary in targets:
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
  targets.append({"body": weakref(item.body), "meshes": meshes, "lit": false})
 for index in mini(game.presentation.ring_visuals.size(), game.ring_field.rings.size()):
  var ring: Dictionary = game.ring_field.rings[index]
  if ring.rack.owner_id != game.ring_field.active_owner_id: continue
  var mesh: MeshInstance3D = game.presentation.ring_visuals[index]
  targets.append({"ring": index, "meshes": [{"ref": weakref(mesh), "original": mesh.material_overlay}], "lit": false})

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
  for record: Dictionary in target.meshes:
   var mesh: MeshInstance3D = record.ref.get_ref()
   if is_instance_valid(mesh): mesh.material_overlay = glow if lit else record.original
