extends Node
## Optional world-only adapter. No gameplay references, timers, input actions or physics writes.
const Settings := preload("res://scripts/retro/retro_settings.gd")
const DITHER := preload("res://third_party/retro/psx/dither.gdshader")
const DITHER_TEXTURE := preload("res://third_party/retro/psx/psxdither.png")
const CRT := preload("res://third_party/retro/crt_vhs/crt.gdshader")
const VHS := preload("res://third_party/retro/crt_vhs/vhs.gdshader")
enum Preset { OFF, PIXEL, N64, CRT, VHS }
const NAMES := ["OFF", "PIXEL / DITHER", "N64-ish", "CRT", "VHS"]
const ORDER := [Preset.PIXEL, Preset.N64, Preset.VHS, Preset.CRT]
signal preset_changed(index: int)

var settings: Settings = preload("res://data/retro_settings.tres").duplicate()
## -1 denotes a custom stack; F4 returns a custom stack to OFF.
var preset := Preset.OFF
var selected_effects: Array[int] = []
var container: SubViewportContainer
var world_view: SubViewport
var effect_layer: CanvasLayer
var passes: Dictionary = {}
var _original_material: Material
var _original_filter: int
var _original_shrink: int
var _original_view_index: int
var _viewport_host: Node
var _output: TextureRect
var _resolution_divisor := 1.0

func attach(target: SubViewportContainer, viewport: SubViewport) -> void:
 container = target
 world_view = viewport
 _original_material = container.material
 _original_filter = container.texture_filter
 _original_shrink = container.stretch_shrink
 _original_view_index = world_view.get_index()
 # SubViewportContainer only supports integer divisors. A plain parent and
 # TextureRect let the same viewport render at fractional resolution scales.
 _viewport_host = Node.new()
 _viewport_host.name = "RetroViewportHost"
 container.add_child(_viewport_host)
 world_view.reparent(_viewport_host)
 _output = TextureRect.new()
 _output.name = "RetroWorldOutput"
 _output.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 _output.mouse_filter = Control.MOUSE_FILTER_IGNORE
 _output.texture = world_view.get_texture()
 container.add_child(_output)
 _output.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 # Dither BEFORE upscale so its pattern is locked to source texels. This canvas
 # belongs only to the 3D SubViewport; parent HUD/debug/menu canvases never enter it.
 effect_layer = CanvasLayer.new()
 effect_layer.name = "RetroWorldEffects"
 effect_layer.layer = 100
 world_view.add_child(effect_layer)
 for effect: int in ORDER:
  # Each selected pass reads the result of the previous one in this same frame.
  # Explicit copies prevent Godot's first screen snapshot being reused by every pass.
  var copy := BackBufferCopy.new()
  copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
  effect_layer.add_child(copy)
  var material := ShaderMaterial.new()
  material.shader = CRT if effect == Preset.CRT else (VHS if effect == Preset.VHS else DITHER)
  if effect in [Preset.PIXEL, Preset.N64]:
   material.set_shader_parameter("dither_tex", DITHER_TEXTURE)
  var rect := ColorRect.new()
  rect.name = "RetroPass%d" % effect
  rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
  rect.material = material
  effect_layer.add_child(rect)
  rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  passes[effect] = {"copy": copy, "rect": rect, "material": material}
 container.resized.connect(_refresh_output)
 set_effects(settings.default_effects)

func cycle() -> void:
 set_preset((preset + 1) % NAMES.size())

func set_preset(index: int) -> void:
 index = clampi(index, Preset.OFF, Preset.VHS)
 set_effects([] if index == Preset.OFF else [index])

func is_enabled(effect: int) -> bool:
 return selected_effects.has(effect)

func toggle_effect(effect: int) -> void:
 var next := selected_effects.duplicate()
 if next.has(effect):
  next.erase(effect)
 else:
  next.append(effect)
 set_effects(next)

func set_effects(effects: Array) -> void:
 selected_effects = []
 for effect: int in ORDER:
  if effects.has(effect):
   selected_effects.append(effect)
 preset = Preset.OFF if selected_effects.is_empty() else (selected_effects[0] if selected_effects.size() == 1 else -1)
 apply_settings()
 preset_changed.emit(preset)

func display_name() -> String:
 var labels := PackedStringArray()
 for effect: int in selected_effects:
  labels.append("PIXEL" if effect == Preset.PIXEL else NAMES[effect])
 return "OFF" if labels.is_empty() else " + ".join(labels)

func apply_settings() -> void:
 if not is_instance_valid(container):
  return
 # OFF restores every property owned by this adapter; there is no identity shader.
 var shrink := float(_original_shrink)
 var sampling := _original_filter
 if is_enabled(Preset.PIXEL):
  shrink = clampf(settings.pixel_resolution_divisor, 1, 4)
  sampling = CanvasItem.TEXTURE_FILTER_NEAREST
 if is_enabled(Preset.N64):
  shrink = maxf(shrink, clampf(settings.n64_resolution_divisor, 1, 4))
  sampling = CanvasItem.TEXTURE_FILTER_LINEAR
 container.material = _original_material
 container.texture_filter = sampling
 _resolution_divisor = shrink
 _output.material = _original_material
 effect_layer.visible = not selected_effects.is_empty()
 for effect: int in ORDER:
  passes[effect].copy.visible = is_enabled(effect)
  passes[effect].rect.visible = is_enabled(effect)
 for effect: int in [Preset.PIXEL, Preset.N64]:
  var pixel := effect == Preset.PIXEL
  _parameters(passes[effect].material, {
   "col_depth": clampf(settings.pixel_color_levels if pixel else settings.n64_color_levels, 1, 256),
   "dith_range": clampf(settings.pixel_dither_strength if pixel else settings.n64_dither_strength, 0, 1),
  })
 _parameters(passes[Preset.CRT].material, {
  "scanline_intensity": settings.crt_scanlines, "mask_intensity": settings.crt_mask,
  "vignette_intensity": settings.crt_vignette, "halation_intensity": settings.crt_glow,
  "halation_radius": settings.crt_glow_radius / shrink,
  "convergence_intensity": 0.0, "tv_brightness": settings.crt_brightness, "tv_contrast": 1.0,
  "tv_saturation": 1.0, "corner_radius": 0.0,
  "border_thickness_horizontal": 0.0, "border_thickness_vertical": 0.0,
 })
 _parameters(passes[Preset.VHS].material, {
  "scanline_intensity": 0.025, "luminance_blur": 0.2 / shrink,
  "chroma_bleed": settings.vhs_chroma_bleed / shrink, "chroma_shift": settings.vhs_chroma_offset / shrink,
  "wobble_intensity": settings.vhs_wobble, "tape_noise_intensity": settings.vhs_grain,
  "tracking_height": 0.06, "tracking_distortion": settings.vhs_tracking,
  "tracking_noise": 0.015, "chroma_streak_frequency": 0.0, "dropout_frequency": 0.0,
 })
 _refresh_output()

func _refresh_output() -> void:
 if not is_instance_valid(world_view):
  return
 world_view.size = Vector2i(container.size / _resolution_divisor).max(Vector2i(2, 2))
 _refresh_pattern()

func _refresh_pattern() -> void:
 if not passes.has(Preset.CRT):
  return
 # Honor the chosen size without a hidden resolution-dependent floor.
 # Subpixel RGB channels may alias at small cells; this is an experimental control.
 var cell_size := maxf(settings.crt_cell_size, 1.0)
 _parameters(passes[Preset.CRT].material, {
  "scanline_count": maxf(1, container.size.y / cell_size),
  "mask_density": maxf(1, container.size.x / cell_size),
 })

func _parameters(material: ShaderMaterial, values: Dictionary) -> void:
 for parameter: String in values:
  material.set_shader_parameter(parameter, values[parameter])

func _exit_tree() -> void:
 if is_instance_valid(container):
  container.material = _original_material
  container.texture_filter = _original_filter
  container.stretch_shrink = _original_shrink
  if is_instance_valid(world_view) and not container.is_queued_for_deletion():
   world_view.reparent(container)
   container.move_child(world_view, _original_view_index)
 if is_instance_valid(_output):
  _output.queue_free()
 if is_instance_valid(_viewport_host):
  _viewport_host.queue_free()
 if is_instance_valid(effect_layer):
  effect_layer.queue_free()
