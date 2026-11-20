extends Node
## Starting in Native allocates no overlays. After Clean 8 has been used,
## keep the prepared programs and restore the opaque receivers on switch-back.
const Options = preload("res://scripts/rendering_options.gd")
const Bands = preload("res://scripts/rendering/shadow_bands.gd")
const Native := preload("res://scripts/atmosphere/native_ssao.gd")
const BandedContact := preload("res://scripts/rendering/terrain_contact.gd")
var bands: RefCounted
var cast_levels := 0
var contact: BandedContact
var contact_levels := 0
var contact_curve := Vector3.ZERO
var contact_environment: Environment

func _ready() -> void:
 RenderingServer.frame_pre_draw.connect(apply)

func apply() -> void:
 if contact_levels > 0: _sync_contact(false)
 var mode := Bands.CLEAN_EIGHT if Options.clean_eight_enabled else -1
 if cast_levels > 0 and RenderingServer.get_current_rendering_method() == "forward_plus":
  mode = Bands.LEVEL_COUNTS.find(cast_levels) # The clean four-tone mode precedes ordered four.
 if not bands and mode < 0: return
 var game := get_parent()
 if not game.presentation or not game.presentation._key_light: return
 if not bands:
  bands = Bands.new()
 if bands.mode != mode:
  bands.mode = mode
  bands.last_lighting.clear()
 bands.sync(game)

func configure_contact(environment: Environment, count: int, curve: Vector3) -> void:
 contact_environment = environment
 contact_levels = count
 contact_curve = curve
 _sync_contact(true)

func _sync_contact(changed: bool) -> void:
 var game := get_parent()
 var supported: bool = contact_levels > 0 and contact_curve.x > 0.0 and RenderingServer.get_current_rendering_method() == "forward_plus" and game.view.msaa_3d != Viewport.MSAA_DISABLED
 if supported:
  if not contact: contact = BandedContact.new()
  if contact_environment.ssao_enabled: contact_environment.ssao_enabled = false
  contact.sync(game, contact_levels, contact_curve)
 else:
  if contact:
   contact.release()
   contact = null
   changed = true
  if changed: Native.apply(contact_environment, contact_curve.x, contact_curve.y, contact_curve.z)

func refresh_preview_materials() -> void:
 if contact: contact.receivers.refresh_source_parameters()
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
 if contact: contact.release()
 if bands: bands.clear(true)

func _exit_tree() -> void:
 RenderingServer.frame_pre_draw.disconnect(apply)
 if contact: contact.release()
 if bands: bands.clear()
