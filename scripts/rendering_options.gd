extends RefCounted
## Machine-local quality. Diagnostic overrides live only in this process.
const SHADOW_RESOLUTIONS := [2048, 4096, 8192]
const SHADOW_CASCADES := [1, 2, 4]
const PROFILE_MSAA := [0, 2, 4]
const PROFILE_SCALES := [75, 85, 100]
const CHOICES := {
 "directional_shadow_resolution": SHADOW_RESOLUTIONS, "directional_shadow_cascades": SHADOW_CASCADES,
 "ultra_filter": [false, true], "fxaa": [false, true], "msaa": PROFILE_MSAA, "scale_percent": PROFILE_SCALES,
 "authored_faces": [false, true], "clean_eight_shadows": [false, true],
}
static var settings_path := "user://graphics_settings.cfg"
static var _loaded := false
static var _quality := {}
static var _profile_fxaa := -1
static var _views: Array[WeakRef] = []
static var _lights: Array[WeakRef] = []
static var clean_eight_enabled := false

static func defaults() -> Dictionary:
 return {"directional_shadow_resolution": int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size", 4096)),
  "directional_shadow_cascades": 4, "ultra_filter": false,
  "fxaa": ProjectSettings.get_setting("rendering/anti_aliasing/quality/screen_space_aa") == Viewport.SCREEN_SPACE_AA_FXAA,
  "msaa": 2, "scale_percent": 100, "authored_faces": true, "clean_eight_shadows": false}

static func quality() -> Dictionary:
 _load_settings()
 return _quality.duplicate()

static func shadow_resolution() -> int:
 _load_settings()
 return _quality.directional_shadow_resolution

static func shadow_cascades() -> int:
 _load_settings()
 return _quality.directional_shadow_cascades

static func ultra_filter_enabled() -> bool:
 _load_settings()
 return _quality.ultra_filter

static func filter_quality() -> int:
 if ultra_filter_enabled(): return RenderingServer.SHADOW_QUALITY_SOFT_ULTRA
 return int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM))

static func smooth_filter_supported() -> bool:
 return RenderingServer.get_current_rendering_method() in ["forward_plus", "mobile"]

static func set_shadow_resolution(size: int) -> Error:
 return update_quality({"directional_shadow_resolution": size})

static func set_shadow_cascades(count: int) -> Error:
 return update_quality({"directional_shadow_cascades": count})

static func _valid(key: String, value: Variant) -> bool:
 return CHOICES.has(key) and typeof(value) == typeof(CHOICES[key][0]) and value in CHOICES[key]

static func update_quality(changes: Dictionary, persist := true) -> Error:
 _load_settings()
 for key: String in changes:
  if not _valid(key, changes[key]): return ERR_INVALID_PARAMETER
 if persist:
  var settings := ConfigFile.new()
  var error := settings.load(settings_path)
  if error not in [OK, ERR_FILE_NOT_FOUND]: return error
  # Migrate both old meanings together on the first explicit device save.
  if settings.has_section_key("rendering", "smooth_shadows"):
   var legacy: Variant = settings.get_value("rendering", "smooth_shadows")
   for key: String in ["ultra_filter", "fxaa"]:
    if not settings.has_section_key("rendering", key):
     settings.set_value("rendering", key, true if legacy is bool and legacy else defaults()[key])
   settings.erase_section_key("rendering", "smooth_shadows")
  for key: String in changes: settings.set_value("rendering", key, changes[key])
  error = settings.save(settings_path)
  if error != OK: return error
 var previous := _quality.duplicate()
 _quality.merge(changes, true)
 if changes.has("authored_faces") or changes.has("clean_eight_shadows"): _apply_terrain()
 if _quality.directional_shadow_resolution != previous.directional_shadow_resolution: _apply_resolution()
 if _quality.ultra_filter != previous.ultra_filter: _apply_filter()
 if _quality.directional_shadow_cascades != previous.directional_shadow_cascades:
  for reference: WeakRef in _lights:
   var light := reference.get_ref() as DirectionalLight3D
   if is_instance_valid(light): _apply_light(light)
 if changes.has("fxaa"): _profile_fxaa = -1
 if changes.has("msaa") or changes.has("scale_percent") or changes.has("fxaa"): _apply_views()
 return OK

static func pixel_profile() -> Dictionary:
 _load_settings()
 return {"msaa": _quality.msaa, "scale_percent": _quality.scale_percent, "fxaa_override": _profile_fxaa}

static func set_pixel_profile(samples: int, scale_percent := 100, fxaa_override := -1) -> Error:
 _load_settings()
 if samples not in PROFILE_MSAA or scale_percent not in PROFILE_SCALES or fxaa_override not in [-1, 0, 1]: return ERR_INVALID_PARAMETER
 _profile_fxaa = fxaa_override
 return update_quality({"msaa": samples, "scale_percent": scale_percent}, false)

static func install_profile_controls(owner: Node) -> void:
 if "--pixel-controls" in OS.get_cmdline_user_args():
  owner.add_child(load("res://scripts/pixel_profile_controls.gd").new())

static func register_light(light: DirectionalLight3D) -> void:
 _load_settings()
 _lights = _lights.filter(func(reference: WeakRef): return is_instance_valid(reference.get_ref()))
 var registered := false
 for reference: WeakRef in _lights:
  if reference.get_ref() == light: registered = true; break
 if not registered: _lights.append(weakref(light))
 _apply_light(light)

static func register_view(view: Viewport) -> void:
 _load_settings()
 _views = _views.filter(func(reference: WeakRef): return is_instance_valid(reference.get_ref()))
 for reference: WeakRef in _views:
  if reference.get_ref() == view: return
 _views.append(weakref(view))
 _apply_view(view)

static func _load_settings() -> void:
 if _loaded: return
 _loaded = true
 _quality = defaults()
 _profile_fxaa = -1
 var settings := ConfigFile.new()
 var error := settings.load(settings_path)
 if error == OK:
  var legacy: Variant = settings.get_value("rendering", "smooth_shadows", false)
  if legacy is bool and legacy:
   _quality.ultra_filter = true
   _quality.fxaa = true
  for key: String in CHOICES:
   var value: Variant = settings.get_value("rendering", key, _quality[key])
   if _valid(key, value): _quality[key] = value
 elif error != ERR_FILE_NOT_FOUND:
  push_warning("Cannot load graphics settings: " + error_string(error))
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--world-msaa="):
   var value := argument.trim_prefix("--world-msaa=")
   if value.is_valid_int() and int(value) in PROFILE_MSAA: _quality.msaa = int(value)
  elif argument.begins_with("--world-scale="):
   var value := argument.trim_prefix("--world-scale=")
   if value.is_valid_int() and int(value) in PROFILE_SCALES: _quality.scale_percent = int(value)
 _apply_resolution()
 _apply_filter()
 _apply_terrain()

static func _apply_terrain() -> void:
 clean_eight_enabled = _quality.clean_eight_shadows and RenderingServer.get_current_rendering_method() == "forward_plus"
 RenderingServer.global_shader_parameter_set("authored_terrain_faces", _quality.authored_faces)

static func _apply_views() -> void:
 for reference: WeakRef in _views:
  var view := reference.get_ref() as Viewport
  if is_instance_valid(view): _apply_view(view)

static func _apply_resolution() -> void:
 # Global runtime API, not a project-file change. Godot exposes no atlas-size getter.
 RenderingServer.directional_shadow_atlas_set_size(_quality.directional_shadow_resolution, bool(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/16_bits", true)))

static func _apply_light(light: DirectionalLight3D) -> void:
 # Never change shadow_enabled: streamed scenery deliberately stays shadowless.
 light.directional_shadow_mode = {1: DirectionalLight3D.SHADOW_ORTHOGONAL, 2: DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, 4: DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS}[_quality.directional_shadow_cascades]

static func _apply_filter() -> void:
 if not smooth_filter_supported(): return
 RenderingServer.directional_soft_shadow_filter_set_quality(filter_quality())

static func _apply_view(view: Viewport) -> void:
 view.msaa_3d = {0: Viewport.MSAA_DISABLED, 2: Viewport.MSAA_2X, 4: Viewport.MSAA_4X}[_quality.msaa]
 # Godot 4.7.2 precompiles framebuffer variants from the project hint, not each
 # SubViewport's MSAA. Keep unsaved diagnostic switches consistent with it too.
 if ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d") != view.msaa_3d:
  ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", view.msaa_3d)
 # Scale only the native 3D buffer. Viewport layout, camera projection, Retro's
 # existing compositor sizing and parent HUD remain at their original sizes.
 view.scaling_3d_scale = _quality.scale_percent / 100.0
 if not smooth_filter_supported():
  view.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
  return
 var enabled: bool = _quality.fxaa if _profile_fxaa < 0 else _profile_fxaa == 1
 view.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if enabled else Viewport.SCREEN_SPACE_AA_DISABLED
