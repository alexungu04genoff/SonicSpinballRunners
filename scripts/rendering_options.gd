extends RefCounted
## Device-local rendering choices, shared by the Lab and gameplay viewports.
static var settings_path := "user://graphics_settings.cfg"
static var _loaded := false
static var _smooth_shadows := false
static var _views: Array[WeakRef] = []

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
 var settings := ConfigFile.new()
 var error := settings.load(settings_path)
 if error not in [OK, ERR_FILE_NOT_FOUND]: return error
 settings.set_value("rendering", "smooth_shadows", enabled)
 error = settings.save(settings_path)
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
 var settings := ConfigFile.new()
 var error := settings.load(settings_path)
 if error == OK:
  _smooth_shadows = settings.get_value("rendering", "smooth_shadows", false) == true
 elif error != ERR_FILE_NOT_FOUND:
  push_warning("Cannot load graphics settings: " + error_string(error))
 _apply_filter()

static func _apply_filter() -> void:
 var quality: int = RenderingServer.SHADOW_QUALITY_SOFT_ULTRA if _smooth_shadows else int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM))
 RenderingServer.directional_soft_shadow_filter_set_quality(quality)

static func _apply_view(view: Viewport) -> void:
 view.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if _smooth_shadows else int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/screen_space_aa", Viewport.SCREEN_SPACE_AA_DISABLED))
