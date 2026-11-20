extends Node
## Starting in Native allocates no overlays. After Clean 8 has been used,
## keep the prepared programs and restore the opaque receivers on switch-back.
const Options = preload("res://scripts/rendering_options.gd")
const Bands = preload("res://scripts/rendering/shadow_bands.gd")
var bands: RefCounted

func _ready() -> void:
 RenderingServer.frame_pre_draw.connect(apply)

func apply() -> void:
 if not bands and not Options.clean_eight_enabled: return
 var game := get_parent()
 if not game.presentation or not game.presentation._key_light: return
 if not bands:
  bands = Bands.new()
 bands.mode = Bands.CLEAN_EIGHT if Options.clean_eight_enabled else -1
 bands.sync(game)

func refresh_preview_materials() -> void:
 if not bands: return
 # Atmosphere edits mutate the opaque material in place. The optional
 # correction needs the same texture, color and roughness inputs.
 for owner: Dictionary in bands.owners.values():
  for source: ShaderMaterial in owner.materials:
   var overlay: ShaderMaterial = owner.materials[source]
   for property: Dictionary in source.get_property_list():
    if String(property.name).begins_with("shader_parameter/"):
     overlay.set(property.name,source.get(property.name))

func release_preview_materials() -> void:
 if bands: bands.clear(true)

func _exit_tree() -> void:
 RenderingServer.frame_pre_draw.disconnect(apply)
 if bands: bands.clear()
