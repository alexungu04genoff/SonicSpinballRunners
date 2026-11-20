extends RefCounted
## Explicit diagnostic profiles. Each case specifies the complete device settings.
const Options = preload("res://scripts/rendering_options.gd")
const CASES := ["production", "quality", "performance", "neither", "ultra-only", "both"]

static func profile(id: String) -> Dictionary:
 assert(id in CASES)
 var settings := Options.defaults()
 if id != "production":
  settings.directional_shadow_resolution = 2048 if id == "performance" else 4096
  settings.directional_shadow_cascades = 1 if id == "performance" else 4
  settings.msaa = 2
  settings.scale_percent = 85
  settings.fxaa = id in ["quality", "performance", "both"]
  settings.ultra_filter = id in ["ultra-only", "both"]
 return settings

static func show_ring_shadows(rings: Array, enabled: bool) -> void:
 for ring: MeshInstance3D in rings:
  if enabled:
   if ring.has_meta("review_cast_shadow"):
    ring.cast_shadow = ring.get_meta("review_cast_shadow")
    ring.remove_meta("review_cast_shadow")
  elif not ring.has_meta("review_cast_shadow"):
   ring.set_meta("review_cast_shadow", ring.cast_shadow)
   ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func position_review_window(window: Window) -> void:
 if DisplayServer.get_name() == "headless": return
 var screen := DisplayServer.get_primary_screen()
 for index in DisplayServer.get_screen_count():
  if index != screen:
   screen = index
   break
 var rect := DisplayServer.screen_get_usable_rect(screen)
 window.current_screen = screen
 window.size = window.size.min(rect.size - Vector2i(32, 72))
 window.position = rect.position + Vector2i(16, 36)
