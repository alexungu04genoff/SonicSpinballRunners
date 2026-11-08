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
## Opt-in, process-local profiling only. Never saved as graphics preferences.
const PROFILE_MSAA := [0, 2, 4]
const PROFILE_SCALES := [75, 85, 100]
static var _profile_msaa := 4
static var _profile_scale := 100
static var _profile_fxaa := -1

static func pixel_profile() -> Dictionary:
 _load_settings()
 return {"msaa": _profile_msaa, "scale_percent": _profile_scale, "fxaa_override": _profile_fxaa}

static func set_pixel_profile(samples: int, scale_percent := 100, fxaa_override := -1) -> Error:
 _load_settings()
 if samples not in PROFILE_MSAA or scale_percent not in PROFILE_SCALES or fxaa_override not in [-1, 0, 1]: return ERR_INVALID_PARAMETER
 _profile_msaa = samples
 _profile_scale = scale_percent
 _profile_fxaa = fxaa_override
 for reference: WeakRef in _views:
  var view := reference.get_ref() as Viewport
  if is_instance_valid(view): _apply_view(view)
 return OK

static func install_profile_controls(owner: Node) -> void:
 if "--pixel-controls" in OS.get_cmdline_user_args():
  owner.add_child(load("res://scripts/pixel_profile_controls.gd").new())

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
 _profile_msaa = 4
 _profile_scale = 100
 _profile_fxaa = -1
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
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--world-msaa="):
   var value := argument.trim_prefix("--world-msaa=")
   if value.is_valid_int() and int(value) in PROFILE_MSAA: _profile_msaa = int(value)
   else: push_warning("Ignored unsupported --world-msaa value: " + value)
  elif argument.begins_with("--world-scale="):
   var value := argument.trim_prefix("--world-scale=")
   if value.is_valid_int() and int(value) in PROFILE_SCALES: _profile_scale = int(value)
   else: push_warning("Ignored unsupported --world-scale value: " + value)

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
 view.msaa_3d = {0: Viewport.MSAA_DISABLED, 2: Viewport.MSAA_2X, 4: Viewport.MSAA_4X}[_profile_msaa]
 # Scale only the native 3D buffer. Viewport layout, camera projection, Retro's
 # existing compositor sizing and parent HUD remain at their original sizes.
 view.scaling_3d_scale = _profile_scale / 100.0
 if not smooth_filter_supported():
  view.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
  return
 view.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if _smooth_shadows else int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/screen_space_aa", Viewport.SCREEN_SPACE_AA_DISABLED))
 if _profile_fxaa >= 0:
  view.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if _profile_fxaa == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
