extends RefCounted
## Optional clean contact bands, using the Retro AO Lab's current-frame depth field.
const Receivers := preload("res://experiments/retro_ao_lab/receivers.gd")
const Depth := preload("res://experiments/retro_ao_lab/depth_source.gd")
const Native := preload("res://scripts/atmosphere/native_ssao.gd")
var receivers := Receivers.new()
var depth: Depth
var camera: Camera3D
var compositor: Compositor
var original: Compositor
var levels := -1
var curve := Vector3.ZERO

func sync(game: Node, count: int, controls: Vector3) -> void:
 if camera != game.presentation.camera or not compositor:
  release()
  camera = game.presentation.camera
  original = camera.compositor
  compositor = Compositor.new()
  var effects: Array[CompositorEffect] = []
  if original: effects.assign(original.compositor_effects)
  depth = Depth.new()
  depth.depth_ready.connect(_depth_ready)
  effects.append(depth)
  compositor.compositor_effects = effects
  camera.compositor = compositor
 if levels != count or curve != controls:
  levels = count
  curve = controls
  receivers.apply({"contact_levels": levels, "contact_radius": curve.y, "contact_depth": depth.depth,
   "contact_gain": curve.x / Native.DEFAULT_GAIN, "contact_contrast": curve.z / Native.REFERENCE_POWER,
   "contact_strength": Native.REFERENCE_STRENGTH})
 receivers.sync(game, true)

func _depth_ready() -> void:
 receivers.settings.contact_depth = depth.depth
 receivers.apply(receivers.settings)

func release() -> void:
 receivers.clear()
 if is_instance_valid(camera) and camera.compositor == compositor: camera.compositor = original
 if depth:
  depth.depth_ready.disconnect(_depth_ready)
  depth.release()
 depth = null
 compositor = null
 original = null
 camera = null
 levels = -1
