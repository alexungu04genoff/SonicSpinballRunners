extends RefCounted
## A skin owns variant pools and a visual factory. Acts never reference these IDs.
const LANDMARK_ROLES := ["Upright", "Span / Gateway"]
var skin_id: String
var pools: Dictionary
var factory: Callable
var atmosphere_materials := {}

func _init(id: String = "", variants: Dictionary = {}, visual_factory: Callable = Callable()) -> void:
 skin_id = id
 pools = variants
 factory = visual_factory

func variants_for(slot: Dictionary) -> Array:
 return pools.get(slot.get("slot_type", ""), {}).get(slot.get("placement_hint", ""), []).duplicate()

func variant_warning(slot: Dictionary) -> String:
 var choices := variants_for(slot)
 if choices.is_empty(): return "This theme has no variants for this slot; no prop will be shown."
 if slot.get("variant_mode", "auto") == "fixed" and int(slot.get("variant_index", -1)) not in range(choices.size()):
  return "Variant %d is unavailable in this theme's %s / %s pool; using Auto. The saved index is unchanged." % [int(slot.get("variant_index", -1)) + 1, slot.slot_type, slot.placement_hint]
 return ""

func resolve(act_seed: String, slot: Dictionary) -> String:
 var choices := variants_for(slot)
 if choices.is_empty(): return ""
 if slot.get("variant_mode", "auto") == "fixed":
  var index: int = slot.get("variant_index", -1)
  if index >= 0 and index < choices.size(): return str(choices[index])
 # Explicit SHA-256 and a bounded prefix avoid process RNG and engine hash changes.
 # Length-delimited JSON avoids ambiguous concatenated keys. Stable IDs also keep
 # deletion/reordering of other slots from changing this slot's chosen variant.
 var namespace_id := skin_id
 var auto_count := choices.size()
 if slot.get("slot_type") == "landmark":
  # Shared upright/span roles keep the same long-axis composition in every
  # theme. Retain the original Green Hill hash so existing layouts stay stable.
  # Circular landmarks remain explicit fixed choices so long layouts stay long.
  namespace_id = "green_hill"
  auto_count = mini(LANDMARK_ROLES.size(), choices.size())
 var digest := JSON.stringify([act_seed, slot.slot_id, namespace_id]).sha256_text()
 return str(choices[digest.left(8).hex_to_int() % auto_count])

func instantiate_slot(act_seed: String, slot: Dictionary) -> Node3D:
 var variant := resolve(act_seed, slot)
 if variant.is_empty() or not factory.is_valid(): return null
 var visual: Node3D = factory.call(variant)
 if visual != null:
  visual.set_meta("decor_variant", variant)
  visual.set_meta("decor_slot_id", slot.slot_id)
  visual.set_meta("decor_skin_id", skin_id)
  _bind_atmosphere(visual)
 return visual

func _bind_atmosphere(root: Node3D) -> void:
 # Only this explicit collisionless prop subtree opts into Decor. Copies stay
 # shared across instances; terrain and gameplay keep their original materials.
 var nodes: Array[Node] = [root]
 nodes.append_array(root.find_children("*", "GeometryInstance3D", true, false))
 for node: Node in nodes:
  if not node is GeometryInstance3D: continue
  if node.material_override != null:
   node.material_override = _decor_material(node.material_override)
  elif node is MeshInstance3D and node.mesh != null:
   for surface in node.mesh.get_surface_count():
    node.set_surface_override_material(surface, _decor_material(node.get_active_material(surface)))
  elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null and node.multimesh.mesh.get_surface_count() == 1:
   node.material_override = _decor_material(node.multimesh.mesh.surface_get_material(0))

func _decor_material(source: Material) -> Material:
 if source == null: return null
 if not atmosphere_materials.has(source):
  atmosphere_materials[source] = preload("res://scripts/atmosphere/surface_controls.gd").decor_copy(source)
 return atmosphere_materials[source]
