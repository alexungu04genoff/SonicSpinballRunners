extends Node
## Optional world-only adapter. No gameplay references, timers, input actions or physics writes.
const Settings := preload("res://scripts/retro/retro_settings.gd")
const DITHER := preload("res://third_party/retro/psx/dither.gdshader")
const DITHER_TEXTURE := preload("res://third_party/retro/psx/psxdither.png")
const CRT := preload("res://third_party/retro/crt_vhs/crt.gdshader")
const VHS := preload("res://third_party/retro/crt_vhs/vhs.gdshader")
enum Preset { OFF, PIXEL, N64, CRT, VHS }
const NAMES := ["OFF", "PIXEL / DITHER", "N64-ish", "CRT", "VHS"]
signal preset_changed(index: int)

var settings: Settings = preload("res://data/retro_settings.tres").duplicate()
var preset := Preset.OFF
var container: SubViewportContainer
var world_view: SubViewport
var dither_rect: ColorRect
var dither_layer: CanvasLayer
var dither_material: ShaderMaterial
var crt_material: ShaderMaterial
var vhs_material: ShaderMaterial
var _original_material: Material
var _original_filter: int
var _original_shrink: int

func attach(target: SubViewportContainer, viewport: SubViewport) -> void:
 container = target
 world_view = viewport
 _original_material = container.material
 _original_filter = container.texture_filter
 _original_shrink = container.stretch_shrink
 dither_material = ShaderMaterial.new()
 dither_material.shader = DITHER
 dither_material.set_shader_parameter("dither_tex", DITHER_TEXTURE)
 crt_material = ShaderMaterial.new()
 crt_material.shader = CRT
 vhs_material = ShaderMaterial.new()
 vhs_material.shader = VHS
 # Dither BEFORE upscale so its pattern is locked to source texels. This canvas
 # belongs only to the 3D SubViewport; parent HUD/debug/menu canvases never enter it.
 dither_layer = CanvasLayer.new()
 dither_layer.name = "RetroWorldDither"
 dither_layer.layer = 100
 world_view.add_child(dither_layer)
 dither_rect = ColorRect.new()
 dither_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
 dither_rect.material = dither_material
 dither_layer.add_child(dither_rect)
 dither_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 set_preset(Preset.OFF)

func cycle() -> void:
 set_preset((preset + 1) % NAMES.size())

func set_preset(index: int) -> void:
 if not is_instance_valid(container):
  return
 preset = clampi(index, Preset.OFF, Preset.VHS)
 # OFF restores every property owned by this adapter; there is no identity shader.
 container.material = _original_material
 container.texture_filter = _original_filter
 container.stretch_shrink = _original_shrink
 dither_layer.visible = preset in [Preset.PIXEL, Preset.N64]
 match preset:
  Preset.PIXEL, Preset.N64:
   var pixel := preset == Preset.PIXEL
   container.stretch_shrink = clampi(settings.pixel_resolution_divisor if pixel else settings.n64_resolution_divisor, 1, 4)
   container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if pixel else CanvasItem.TEXTURE_FILTER_LINEAR
   dither_material.set_shader_parameter("col_depth", clampf(settings.pixel_color_levels if pixel else settings.n64_color_levels, 4.0, 64.0))
   dither_material.set_shader_parameter("dith_range", clampf(settings.pixel_dither_strength if pixel else settings.n64_dither_strength, 0.0, 1.0))
  Preset.CRT:
   container.material = crt_material
   _parameters(crt_material, {
    "scanline_intensity": settings.crt_scanlines, "scanline_count": 345.0,
    "mask_intensity": settings.crt_mask, "mask_density": 426.0,
    "vignette_intensity": settings.crt_vignette, "halation_intensity": settings.crt_glow,
    "convergence_intensity": 0.0, "tv_brightness": 0.0, "tv_contrast": 1.0,
    "tv_saturation": 1.0, "corner_radius": 0.0,
    "border_thickness_horizontal": 0.0, "border_thickness_vertical": 0.0,
   })
  Preset.VHS:
   container.material = vhs_material
   container.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
   _parameters(vhs_material, {
    "scanline_intensity": 0.025, "luminance_blur": 0.2,
    "chroma_bleed": settings.vhs_chroma_bleed, "chroma_shift": settings.vhs_chroma_offset,
    "wobble_intensity": settings.vhs_wobble, "tape_noise_intensity": settings.vhs_grain,
    "tracking_height": 0.06, "tracking_distortion": settings.vhs_tracking,
    "tracking_noise": 0.015, "chroma_streak_frequency": 0.0, "dropout_frequency": 0.0,
   })
 preset_changed.emit(preset)

func _parameters(material: ShaderMaterial, values: Dictionary) -> void:
 for parameter: String in values:
  material.set_shader_parameter(parameter, values[parameter])

func _exit_tree() -> void:
 if is_instance_valid(container):
  container.material = _original_material
  container.texture_filter = _original_filter
  container.stretch_shrink = _original_shrink
 if is_instance_valid(dither_layer):
  dither_layer.queue_free()
