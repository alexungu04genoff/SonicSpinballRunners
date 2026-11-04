extends RefCounted
## Device-local rendering choices, shared by the Lab and gameplay viewports.
static var settings_path := "user://graphics_settings.cfg"
static var _loaded := false
static var _smooth_shadows := false
static var _views: Array[WeakRef] = []
const SHADOW_RESOLUTIONS := [2048, 4096, 8192]
const SHADOW_CASCADES := [1, 2, 4]
static var _shadow_resolution := 8192
static var _shadow_cascades := 4
static var _lights: Array[WeakRef] = []

static func shadow_resolution() -> int:
 _load_settings()
 return _shadow_resolution

static func shadow_cascades() -> int:
 _load_settings()
 return _shadow_cascades

static func smooth_filter_supported() -> bool:
 return RenderingServer.get_current_rendering_method() in ["forward_plus", "mobile"]

static func register_light(light: DirectionalLight3D) -> void:
 _load_settings()
 _lights = _lights.filter(func(reference: WeakRef): return is_instance_valid(reference.get_ref()))
 var registered := false
 for reference: WeakRef in _lights:
  if reference.get_ref() == light: registered = true; break
 if not registered: _lights.append(weakref(light))
 _apply_light(light)

static func set_shadow_resolution(size: int) -> Error:
 _load_settings()
 if size not in SHADOW_RESOLUTIONS: return ERR_INVALID_PARAMETER
 var error := _save_value("directional_shadow_resolution", size)
 if error != OK: return error
 _shadow_resolution = size
 _apply_resolution()
 return OK

static func set_shadow_cascades(count: int) -> Error:
 _load_settings()
 if count not in SHADOW_CASCADES: return ERR_INVALID_PARAMETER
 var error := _save_value("directional_shadow_cascades", count)
 if error != OK: return error
 _shadow_cascades = count
 for reference: WeakRef in _lights:
  var light := reference.get_ref() as DirectionalLight3D
  if is_instance_valid(light): _apply_light(light)
 return OK

static func _save_value(key: String, value: Variant) -> Error:
 var settings := ConfigFile.new()
 var error := settings.load(settings_path)
 if error not in [OK, ERR_FILE_NOT_FOUND]: return error
 settings.set_value("rendering", key, value)
 return settings.save(settings_path)

static func smooth_shadows_enabled() -> bool:
 _load_settings()
 return _smooth_shadows

static func register_view(view: Viewport) -> void:
 _load_settings()
 _views = _views.filter(func(reference: WeakRef): return is_instance_valid(reference.get_ref()))
 for reference: WeakRef in _views:
  if reference.get_ref() == view: return
 _views.append(weakref(view))
 _apply_view(view)

static func set_smooth_shadows(enabled: bool) -> Error:
 _load_settings()
 var error := _save_value("smooth_shadows", enabled)
 if error != OK: return error
 _smooth_shadows = enabled
 _apply_filter()
 for reference: WeakRef in _views:
  var view := reference.get_ref() as Viewport
  if is_instance_valid(view): _apply_view(view)
 return OK

static func _load_settings() -> void:
 if _loaded: return
 _loaded = true
 _smooth_shadows = false
 _shadow_resolution = int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size", 8192))
 _shadow_cascades = 4
 var settings := ConfigFile.new()
 var error := settings.load(settings_path)
 if error == OK:
  var smooth: Variant = settings.get_value("rendering", "smooth_shadows", false)
  _smooth_shadows = smooth is bool and smooth
  var size: Variant = settings.get_value("rendering", "directional_shadow_resolution", _shadow_resolution)
  if size is int and size in SHADOW_RESOLUTIONS: _shadow_resolution = size
  var count: Variant = settings.get_value("rendering", "directional_shadow_cascades", 4)
  if count is int and count in SHADOW_CASCADES: _shadow_cascades = count
 elif error != ERR_FILE_NOT_FOUND:
  push_warning("Cannot load graphics settings: " + error_string(error))
 _apply_resolution()
 _apply_filter()

static func _apply_resolution() -> void:
 # Global runtime API, not a project-file change. Godot exposes no atlas-size getter.
 RenderingServer.directional_shadow_atlas_set_size(_shadow_resolution, bool(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/16_bits", true)))

static func _apply_light(light: DirectionalLight3D) -> void:
 # Never change shadow_enabled: streamed scenery deliberately stays shadowless.
 light.directional_shadow_mode = {1: DirectionalLight3D.SHADOW_ORTHOGONAL, 2: DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, 4: DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS}[_shadow_cascades]

static func _apply_filter() -> void:
 if not smooth_filter_supported(): return
 var quality: int = RenderingServer.SHADOW_QUALITY_SOFT_ULTRA if _smooth_shadows else int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM))
 RenderingServer.directional_soft_shadow_filter_set_quality(quality)

static func _apply_view(view: Viewport) -> void:
 if not smooth_filter_supported():
  view.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
  return
 view.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if _smooth_shadows else int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/screen_space_aa", Viewport.SCREEN_SPACE_AA_DISABLED))
