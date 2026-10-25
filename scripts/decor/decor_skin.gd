extends RefCounted
## A skin owns variant pools and a visual factory. Acts never reference these IDs.
var skin_id: String
var pools: Dictionary
var factory: Callable

func _init(id: String = "", variants: Dictionary = {}, visual_factory: Callable = Callable()) -> void:
 skin_id = id
 pools = variants
 factory = visual_factory

func resolve(act_seed: String, slot: Dictionary) -> String:
 var choices: Array = pools.get(slot.slot_type, {}).get(slot.placement_hint, [])
 if choices.is_empty(): return ""
 # Explicit SHA-256 and a bounded prefix avoid process RNG and engine hash changes.
 # Length-delimited JSON avoids ambiguous concatenated keys. Stable IDs also keep
 # deletion/reordering of other slots from changing this slot's chosen variant.
 var digest := JSON.stringify([act_seed, slot.slot_id, skin_id]).sha256_text()
 return str(choices[digest.left(8).hex_to_int() % choices.size()])

func instantiate_slot(act_seed: String, slot: Dictionary) -> Node3D:
 var variant := resolve(act_seed, slot)
 if variant.is_empty() or not factory.is_valid(): return null
 var visual: Node3D = factory.call(variant)
 if visual != null:
  visual.set_meta("decor_variant", variant)
  visual.set_meta("decor_slot_id", slot.slot_id)
  visual.set_meta("decor_skin_id", skin_id)
 return visual
