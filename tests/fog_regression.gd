extends SceneTree
## Rendered directional mask, live authoring and persistence regression checks.
const Fog := preload("res://scripts/atmosphere/directional_fog.gd")
const Fields := preload("res://scripts/atmosphere/fields.gd")
const FogView := preload("res://experiments/lighting_lab/fog_view.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(label)
func sample(view: SubViewport) -> Image:
 for frame in 4: await process_frame
 await RenderingServer.frame_post_draw
 return view.get_texture().get_image()

func run() -> void:
 var view := SubViewport.new()
 view.size = Vector2i(256, 256)
 view.own_world_3d = true
 view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(view)
 var world := WorldEnvironment.new()
 world.environment = Environment.new()
 world.environment.background_mode = Environment.BG_COLOR
 world.environment.background_color = Color.BLACK
 view.add_child(world)
 var camera := Camera3D.new()
 view.add_child(camera)
 camera.position = Vector3(0, 10, 0)
 camera.rotation_degrees.x = -90
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 20
 camera.current = true
 var top_span := FogView.table_distances(camera)
 check(is_equal_approx(top_span.x, 10.0) and top_span.y > top_span.x, "Top-down view uses radial table distances")
 var plane := MeshInstance3D.new()
 var mesh := PlaneMesh.new()
 mesh.size = Vector2(20, 20)
 plane.mesh = mesh
 var black := StandardMaterial3D.new()
 black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 black.albedo_color = Color.BLACK
 plane.material_override = black
 view.add_child(plane)
 Fog.apply(camera, {})
 check(camera.get_child_count() == 0, "Disabled defaults allocate no pass")
 var values := Fog.DEFAULTS.duplicate()
 values.merge({"directional_fog/enabled": true, "directional_fog/color": Color.WHITE, "directional_fog/density": 1.0, "directional_fog/length": 800.0, "directional_fog/curve": 1.0}, true)
 check(Fields.valid_values("green_hill", values), "Directional fog validates for variants")
 check(not Fields.valid_values("green_hill", {"directional_fog/curve": 0.0}), "Reject degenerate curve")
 check(not Fields.valid_values("green_hill", {"env/fog_mode": 2}), "Reject invalid native fog mode")
 Fog.apply(camera, values)
 var linear := await sample(view)
 check(linear.get_pixel(128, 32).r > linear.get_pixel(128, 96).r + 0.1, "North gets progressively denser")
 check(linear.get_pixel(128, 200).r < 0.02, "South remains clear")
 values["directional_fog/curve"] = 3.0
 Fog.apply(camera, values)
 var curved := await sample(view)
 check(curved.get_pixel(128, 96).r < linear.get_pixel(128, 96).r - 0.05, "Higher curve delays buildup")
 values["directional_fog/angle"] = 90.0
 values["directional_fog/color"] = Color.RED
 Fog.apply(camera, values)
 var east := await sample(view)
 check(east.get_pixel(224, 128).r > 0.5 and east.get_pixel(224, 128).g < 0.02 and east.get_pixel(32, 128).r < 0.02, "Angle rotates east and color applies")
 values["directional_fog/brightness"] = 0.1
 Fog.apply(camera, values)
 var dimmed := await sample(view)
 check(dimmed.get_pixel(224, 128).r < east.get_pixel(224, 128).r - 0.2, "Brightness dims fog independently")
 camera.position.x += 5.0
 plane.position.x += 5.0
 var moved := await sample(view)
 check(absf(moved.get_pixel(224, 128).r - dimmed.get_pixel(224, 128).r) < 0.02, "Fog follows view center")
 Fog.apply(camera, {})
 var disabled := await sample(view)
 check(disabled.get_pixel(224, 128).r < 0.02, "Disable restores clear rendering")
 check(camera.get_child_count() == 1, "Edits reuse one pass")
 check(is_equal_approx(Fog.blend({}, values, 0.5)["directional_fog/density"], 0.5), "Zone transition blends density")
 check(not Fog.blend(values, {}, 1.0)["directional_fog/enabled"], "Transition to Default disables pass")
 # Exercise the production foreground transition without loading disk bakes.
 var stream = load("res://scripts/endless/endless_game.gd").new()
 var presentation := TablePresentation.new()
 stream.presentation = presentation
 presentation.camera = camera
 presentation._world_environment = world
 var light := DirectionalLight3D.new()
 view.add_child(light)
 presentation._key_light = light
 var before := preload("res://scripts/atmosphere/runtime.gd").new()
 var after := preload("res://scripts/atmosphere/runtime.gd").new()
 before.configure("green_hill", {"values": {"env/fog_enabled": true, "env/fog_density": 0.01}}, Environment.new(), light)
 var depth_values := values.duplicate()
 depth_values.merge({"env/fog_enabled": true, "env/fog_mode": Environment.FOG_MODE_DEPTH, "env/fog_density": 0.8, "env/fog_depth_begin": 5.0, "env/fog_depth_end": 30.0, "env/fog_depth_curve": 3.0})
 after.configure("green_hill", {"values": depth_values}, Environment.new(), light)
 stream.backgrounds = {0: {"layer": {"atmosphere": before}}, 1: {"layer": {"atmosphere": after}}}
 stream._blend_lighting(0, 1, 0.25)
 check(is_equal_approx(world.environment.fog_density, 0.005), "Mixed native modes fade old density safely")
 stream._blend_lighting(0, 1, 0.5)
 check(world.environment.fog_mode == Environment.FOG_MODE_DEPTH and is_zero_approx(world.environment.fog_density), "Native mode switches at zero density")
 check(is_equal_approx(camera.get_node("DirectionalFog").material_override.get_shader_parameter("fog_density"), 0.5), "Production transition applies directional density")
 stream._blend_lighting(0, 1, 1.0)
 check(is_equal_approx(world.environment.fog_density, 0.8) and world.environment.fog_depth_begin == 5.0 and world.environment.fog_depth_end == 30.0 and world.environment.fog_depth_curve == 3.0, "Production native fog reaches next Zone values")
 stream.free()
 presentation.free()
 view.free()
 var game = load("res://experiments/lighting_lab/lighting_lab.tscn").instantiate()
 root.add_child(game)
 paused = true
 for frame in 12: await process_frame
 var panel = game.lighting_controls
 panel.settings_path = "user://fog_regression.cfg"
 panel.saved = ConfigFile.new()
 panel.drafts.clear()
 panel.reset_values()
 var environment: Environment = game.presentation._world_environment.environment
 panel.set_value("directional_fog/enabled", true)
 panel.set_value("directional_fog/angle", 25.0)
 panel.set_value("env/fog_enabled", true)
 panel.set_value("env/fog_mode", Environment.FOG_MODE_DEPTH)
 panel.set_value("env/fog_density", 0.55)
 panel.set_value("env/fog_depth_begin", 4.0)
 panel.set_value("env/fog_depth_end", 24.0)
 panel.set_value("env/fog_depth_curve", 2.0)
 check(environment.fog_mode == Environment.FOG_MODE_DEPTH and environment.fog_depth_curve == 2.0 and environment.fog_depth_begin == 4.0 and environment.fog_depth_end == 24.0, "Native distance and curve controls apply")
 var span := FogView.table_distances(game.presentation.camera)
 panel._fit_fog_to_view()
 check(environment.fog_depth_begin >= span.x and absf(environment.fog_depth_end - span.y) < 0.01, "Fit spans the visible perspective table")
 var fitted := Vector2(environment.fog_depth_begin, environment.fog_depth_end)
 var before_view: Transform3D = game.presentation.camera.transform
 game.presentation.camera.position += game.presentation.camera.basis.z * 4.0
 panel.sync_fog_controls()
 check(Vector2(environment.fog_depth_begin, environment.fog_depth_end) == fitted, "Moving camera does not rewrite saved fog distances")
 var distance_slider: HSlider = panel.widgets["env/fog_depth_begin"].get_meta("slider")
 var zoom_span := FogView.table_distances(game.presentation.camera)
 check(distance_slider.min_value < zoom_span.x and distance_slider.max_value > zoom_span.y and distance_slider.max_value < 1000.0, "Distance sliders cover current viewport scale")
 game.presentation.camera.transform = before_view
 panel.sync_fog_controls()
 var quad: MeshInstance3D = game.presentation.camera.get_node("DirectionalFog")
 check(quad.visible and environment.fog_enabled, "Both fog types coexist")
 panel.set_value("directional_fog/enabled", false)
 DirAccess.make_dir_recursive_absolute("res://test-results/directional-fog")
 var fitted_capture := await sample(game.view)
 fitted_capture.save_png("res://test-results/directional-fog/viewport-depth.png")
 panel.set_value("directional_fog/enabled", true)
 panel.save_preset()
 panel.compare.button_pressed = true
 check(not quad.visible and not environment.fog_enabled, "Original comparison restores both fog types")
 panel.compare.button_pressed = false
 check(quad.visible and environment.fog_enabled, "Tuned comparison restores both fog types")
 panel.reset_values()
 panel.reload_preset()
 environment = game.presentation._world_environment.environment
 check(panel.values["directional_fog/angle"] == 25.0 and environment.fog_depth_curve == 2.0, "Fog preset round trip")
 check(game.set_theme("ice_cap"), "Theme switch succeeds")
 check(not quad.visible, "Fog does not leak across themes")
 game.set_theme("green_hill")
 check(quad.visible, "Theme draft restores fog")
 panel.set_value("env/fog_mode", Environment.FOG_MODE_EXPONENTIAL)
 check(not panel.widgets["env/fog_depth_curve"].editable, "Distance controls disable in Exponential mode")
 panel.set_value("env/fog_enabled", false)
 panel.set_value("directional_fog/angle", 0.0)
 DirAccess.make_dir_recursive_absolute("res://test-results/directional-fog")
 var capture := await sample(game.view)
 capture.save_png("res://test-results/directional-fog/lab.png")
 game.free()
 print("FOG_REGRESSION | checks=%d failures=%d" % [checks, failures])
 quit(1 if failures else 0)
