extends CanvasLayer
## Opt-in lab controls; no production hook, settings save, or material mutation.
signal capture_requested
signal camera_requested(index: int)
signal theme_requested
signal close_requested
const Audit = preload("res://scripts/diagnostics/render_audit.gd")
const Proxy = preload("res://scripts/diagnostics/scenery_shadow_trial.gd")
const Options = preload("res://scripts/rendering_options.gd")
const MODE_NAMES := ["0 Production current", "1 Side-key only", "2 Current key + proxies", "3 Side-key + proxies", "4 ALL NEAR SHADOWS / NON-SHIPPING CEILING", "5 Directional shadows OFF"]
const DIRECTIONS := ["production", "camera-left cross-key", "camera-right cross-key", "travelling up-table", "travelling down-table", "higher 70-degree key", "lower 20-degree key"]
const OVERLAYS := ["off", "casters", "receivers", "shadowless", "foreground world", "backdrop world", "shadow-only geometry"]
var game: Node
var mode := 0
var direction := 2
var overlay := 0
var reveal := false
var camera_index := 0
var proxy_method := "source"
var quality := "production"
var proxy := Proxy.new()
var label: Label
var production_light := {}
var production_retro: Array = []
var saved_pixel := {}
var saved_shadow := {}
var overlays: Array[MeshInstance3D] = []
var _known_owners := ""
var _last_zone := -99

func configure(owner_game: Node, defaults: Dictionary = {}) -> void:
 game = owner_game
 process_mode = Node.PROCESS_MODE_ALWAYS
 layer = 120
 production_retro = game.retro_filter.settings.default_effects.duplicate()
 snapshot_light()
 saved_pixel = defaults.get("pixel", Options.pixel_profile().duplicate())
 saved_shadow = defaults.get("shadow", {"size": Options.shadow_resolution(), "cascades": Options.shadow_cascades(), "smooth": Options.smooth_shadows_enabled()})
 label = Label.new()
 label.position = Vector2(12, 105)
 label.add_theme_font_size_override("font_size", 15)
 label.add_theme_color_override("font_outline_color", Color.BLACK)
 label.add_theme_constant_override("outline_size", 5)
 add_child(label)
 refresh_label()

func snapshot_light() -> void:
 production_light.clear()
 for light: DirectionalLight3D in _lights():
  production_light[light.get_instance_id()] = {"reference": weakref(light), "transform": light.transform, "shadows": light.shadow_enabled}

func _lights() -> Array[DirectionalLight3D]:
 var result: Array[DirectionalLight3D] = [game.presentation._key_light]
 for background: Dictionary in game.backgrounds.values(): result.append(background.layer.light)
 return result

func restore_light() -> void:
 for state: Dictionary in production_light.values():
  var light := state.reference.get_ref() as DirectionalLight3D
  if is_instance_valid(light):
   light.transform = state.transform
   light.shadow_enabled = state.shadows

func set_direction(index: int) -> void:
 direction = posmod(index, DIRECTIONS.size())
 apply_mode(mode)

func apply_mode(index: int) -> void:
 mode = clampi(index, 0, 5)
 restore_light()
 if mode in [1, 3]:
  for light: DirectionalLight3D in _lights():
   if direction != 0: light.basis = direction_basis(direction, game.presentation.camera, light.rotation_degrees.x)
 if mode == 5: game.presentation._key_light.shadow_enabled = false
 if mode in [2, 3, 4]:
  proxy.build(game, proxy_method, mode == 4)
 else: proxy.clear()
 proxy.set_visible(game, mode in [2, 3, 4], reveal)
 _known_owners = owner_signature()
 _last_zone = game._background_zone
 set_overlay(overlay)
 refresh_label()
 print("GROUNDING_MODE | ", MODE_NAMES[mode], " | direction=", DIRECTIONS[direction], " | proxy=", proxy_method)

static func direction_basis(index: int, camera: Camera3D, production_pitch: float) -> Basis:
 var pitch := clampf(absf(production_pitch), 20.0, 75.0)
 if index == 5: pitch = 70.0
 if index == 6: pitch = 20.0
 var right := Vector3(camera.global_basis.x.x, 0, camera.global_basis.x.z).normalized()
 var source := -right
 if index == 2: source = right
 if index == 3: source = Vector3.BACK
 if index == 4: source = Vector3.FORWARD
 source = source * cos(deg_to_rad(pitch)) + Vector3.UP * sin(deg_to_rad(pitch))
 return Basis.looking_at(-source, Vector3.UP)

func set_quality(profile: String) -> void:
 quality = profile
 apply_quality(profile, {"pixel": saved_pixel, "shadow": saved_shadow})
 for light: DirectionalLight3D in _lights(): Options._apply_light(light)
 game.retro_filter.set_effects([] if profile == "balanced-no-retro" else ([2] if profile == "reduced-retro" else production_retro))
 refresh_label()

static func apply_quality(profile: String, defaults: Dictionary) -> void:
 var saved_shadow: Dictionary = defaults.shadow
 var saved_pixel: Dictionary = defaults.pixel
 var production := profile == "production"
 Options._shadow_resolution = saved_shadow.size if production else 2048
 Options._shadow_cascades = saved_shadow.cascades if production else 1
 Options._smooth_shadows = saved_shadow.smooth if production else false
 Options._apply_resolution()
 Options._apply_filter()
 for reference: WeakRef in Options._lights:
  var light := reference.get_ref() as DirectionalLight3D
  if is_instance_valid(light): Options._apply_light(light)
 var low := profile.begins_with("balanced") or profile == "reduced-retro"
 Options.set_pixel_profile(2 if low else saved_pixel.msaa, 85 if low else saved_pixel.scale_percent, saved_pixel.fxaa_override)
 ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", {0: 0, 2: 1, 4: 2}[Options.pixel_profile().msaa])

func owner_signature() -> String:
 var ids: Array = [game.active_sequence]
 for act: RefCounted in game.resident: ids.append(act.visual.get_instance_id())
 return str(ids)

func update_lifecycle() -> void:
 # Called by the lab's 4 Hz sampler, never by individual decoration callbacks.
 var current := owner_signature()
 if _known_owners != current or _last_zone != game._background_zone:
  restore_light()
  game._last_atmosphere_blend = Vector3(-1, -1, -1)
  game._update_backgrounds()
  snapshot_light()
  apply_mode(mode)
 proxy.set_visible(game, mode in [2, 3, 4], reveal)

func set_overlay(index: int) -> void:
 for node: MeshInstance3D in overlays:
  if is_instance_valid(node): node.free()
 overlays.clear()
 overlay = posmod(index, OVERLAYS.size())
 if overlay == 0: return
 for entry: Dictionary in Audit.viewports(game):
  if entry.role in ["output", "composite", "warmup"]: continue
  var nodes: Array[Node] = [entry.node]
  while not nodes.is_empty():
   var node: Node = nodes.pop_back()
   nodes.append_array(node.get_children())
   var mesh := Audit.mesh_of(node)
   if mesh == null or not node.is_visible_in_tree(): continue
   var is_proxy: bool = node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
   var casts: bool = node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   var receiver := false
   for surface in mesh.get_surface_count():
    var material: Material = node.get_active_material(surface) if node is MeshInstance3D else (node.material_override if node.material_override != null else mesh.surface_get_material(surface))
    receiver = receiver or Audit.material_state(material).receives_shadows
   var selected: bool = [false, casts, receiver, not casts, entry.role == "foreground", entry.role.begins_with("backdrop"), is_proxy][overlay]
   if not selected: continue
   # Bounds are separate line geometry, so no production material is replaced.
   var box: AABB = node.get_aabb()
   var lines := ImmediateMesh.new()
   lines.surface_begin(Mesh.PRIMITIVE_LINES)
   for corner in 8:
    for axis in 3:
     var other := corner ^ (1 << axis)
     if other > corner:
      lines.surface_add_vertex(box.get_endpoint(corner))
      lines.surface_add_vertex(box.get_endpoint(other))
   lines.surface_end()
   var visual := MeshInstance3D.new()
   visual.mesh = lines
   visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   var color := StandardMaterial3D.new()
   color.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
   color.no_depth_test = true
   var decor := Audit.category(node, entry.role, game).begins_with("authored_decor")
   color.albedo_color = Color("ff37d4") if is_proxy else (Color("70ff58") if decor else (Color("38dfef") if entry.role == "foreground" else Color("ffbd50")))
   visual.material_override = color
   entry.node.add_child(visual)
   visual.global_transform = node.global_transform
   overlays.append(visual)
 refresh_label()

func refresh_label() -> void:
 if label == null: return
 label.text = "GROUNDING LAB / UNSAVED DIAGNOSTICS\n%s · %s · proxies %s\nF1 mode · F2 sun · F3 bounds · F4 Retro · F5 reveal · F6 source/hull\nF7 camera · F8 theme · F9 capture · F10 quality · Esc exit\n%s · %dx · %d%% · atlas %d · %d cascades · %s\nBounds: %s (green Decor / cyan foreground / gold backdrop / pink shadow-only)\nCaster/receiver bounds show eligibility; backdrop lights are shadowless." % [MODE_NAMES[mode], DIRECTIONS[direction], proxy_method,
  quality, Options.pixel_profile().msaa, Options.pixel_profile().scale_percent, Options.shadow_resolution(), Options.shadow_cascades(), game.retro_filter.display_name(), OVERLAYS[overlay]]

func _unhandled_key_input(event: InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo: return
 match event.keycode:
  KEY_F1: apply_mode((mode + 1) % MODE_NAMES.size())
  KEY_F2: set_direction(direction + 1)
  KEY_F3: set_overlay(overlay + 1)
  KEY_F4:
   game.retro_filter.set_effects(production_retro if game.retro_filter.selected_effects.is_empty() else [])
   game._update_backgrounds()
  KEY_F5:
   reveal = not reveal
   proxy.set_visible(game, mode in [2, 3, 4], reveal)
  KEY_F6:
   proxy_method = "hull" if proxy_method == "source" else "source"
   apply_mode(mode)
  KEY_F7:
   camera_index = (camera_index + 1) % 3
   camera_requested.emit(camera_index)
  KEY_F8: theme_requested.emit()
  KEY_F9: capture_requested.emit()
  KEY_F10:
   var profiles := ["production", "shadow-light", "balanced", "balanced-no-retro", "reduced-retro"]
   set_quality(profiles[(profiles.find(quality) + 1) % profiles.size()])
  KEY_ESCAPE: close_requested.emit()
  _: return
 refresh_label()
 get_viewport().set_input_as_handled()

func restore() -> void:
 set_overlay(0)
 proxy.clear()
 restore_light()
 set_quality("production")
