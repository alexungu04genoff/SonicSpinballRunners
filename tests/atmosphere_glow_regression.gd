extends SceneTree
## Run with Forward+ in an isolated user profile; captures require a rendered viewport.
const Bindings := preload("res://scripts/atmosphere/material_bindings.gd")
const Runtime := preload("res://scripts/atmosphere/runtime.gd")
const Registry := preload("res://scripts/atmosphere/variants.gd")
const OUTPUT := "res://test-results/atmosphere-glow"
const WIDE := {"env/glow_enabled": true, "env/glow_strength": 1.3, "env/glow_levels/3": 0.1, "env/glow_levels/5": 0.8, "env/glow_levels/7": 0.7, "env/glow_normalized": true, "env/glow_intensity": 0.65, "env/glow_hdr_threshold": 0.7, "surface_halo_spread": 1.8}
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(label)
func equal(actual: Variant, expected: Variant) -> bool:
 return actual is float and is_equal_approx(actual, expected) if expected is float else actual == expected
func frames(count := 5) -> void:
 for index in count: await process_frame
func capture(view: Viewport, name: String) -> Image:
 await frames()
 await RenderingServer.frame_post_draw
 var picture := view.get_texture().get_image()
 picture.save_png(OUTPUT.path_join(name + ".png"))
 return picture

func run() -> void:
 DirAccess.make_dir_recursive_absolute(OUTPUT)
 check_surface_width()
 await check_glow_shape()
 if "--fixture-only" in OS.get_cmdline_user_args():
  quit(1 if failures else 0)
  return
 root.size = Vector2i(1280, 900)
 var game = load("res://experiments/lighting_lab/lighting_lab.tscn").instantiate()
 root.add_child(game)
 paused = true
 await frames()
 var panel = game.lighting_controls
 panel.saved = ConfigFile.new()
 panel.drafts.clear()
 var retro: Array = game.retro_filter.selected_effects.duplicate()
 var registry := Registry.new()
 registry.directory = "user://glow-regression"
 for theme: String in game.ThemeRegistry.IDS:
  game.set_theme(theme)
  panel.variants.context.selected = "draft"
  panel.reset_values()
  var original: Dictionary = panel.originals.duplicate(true)
  var environment: Environment = game.presentation._world_environment.environment
  var ball: int = game.ball.get_instance_id()
  var count: int = game.presentation.find_children("*", "", true, false).size()
  check(panel.widgets["surface_halo_spread"].get_parent().visible == not panel.emission.halo_parameters.is_empty(), theme + " shows surface width only where supported")
  for use_retro in [false, true]:
   game.retro_filter.set_effects(retro if use_retro else [])
   panel.reset_values()
   await capture(game.view, theme + ("-retro" if use_retro else "-plain") + "-original")
   for key: String in WIDE: panel.set_value(key, WIDE[key])
   for key: String in WIDE:
    if key.begins_with("env/"): check(equal(environment.get(key.trim_prefix("env/")), WIDE[key]), theme + " applies " + key)
   for entry: Dictionary in panel.emission.halo_parameters:
    check(is_equal_approx(entry.material.get_shader_parameter(entry.property), entry.base * 1.8), "Surface width follows the shared control")
   await capture(game.view, theme + ("-retro" if use_retro else "-plain") + "-wide-soft")
  if theme == "chemical_plant":
   panel.tabs.current_tab = panel.tabs.get_node("Glow & Fog").get_index()
   await capture(root, "chemical-controls")
  check(count == game.presentation.find_children("*", "", true, false).size() and ball == game.ball.get_instance_id(), theme + " preserves nodes and gameplay")
  var records: Array[Dictionary] = [Registry.baseline()]
  records[0].values = WIDE.duplicate()
  check(registry.save(theme, records, registry.revision(theme)) and registry.read(theme) == records, theme + " glow settings save and reload")
  var light := DirectionalLight3D.new()
  var runtime := Runtime.new()
  runtime.configure(theme, records[0], Environment.new(), light)
  for key: String in WIDE:
   if key.begins_with("env/"): check(equal(runtime.environment.get(key.trim_prefix("env/")), WIDE[key]), theme + " runtime applies " + key)
  light.free()
  panel.reset_values()
  for key: String in WIDE:
   if key.begins_with("env/"): check(environment.get(key.trim_prefix("env/")) == original[key], theme + " exact glow reset")
  print("GLOW_THEME | ", theme, " | surface_halo_bindings=", panel.emission.halo_parameters.size())
 check_transition(game)
 game.free()
 print("ATMOSPHERE_GLOW | checks=%d failures=%d" % [checks, failures])
 quit(1 if failures else 0)

func check_surface_width() -> void:
 var shader := Shader.new()
 shader.code = "shader_type spatial; uniform float floor_neon_spread = 2.7; void fragment(){ ALBEDO=vec3(0.0); EMISSION=vec3(floor_neon_spread); }"
 var source := ShaderMaterial.new()
 source.shader = shader
 source.set_shader_parameter("floor_neon_spread", 2.7)
 var owner_node := Node3D.new()
 var scenery := Node3D.new()
 owner_node.add_child(scenery)
 scenery.set_meta("atmosphere_scenery", "local")
 for parent: Node in [scenery, owner_node]:
  var visual := MeshInstance3D.new()
  visual.mesh = BoxMesh.new()
  visual.material_override = source
  parent.add_child(visual)
 var bindings := Bindings.new()
 bindings.collect(owner_node)
 var light := DirectionalLight3D.new()
 bindings.apply_palette(WIDE, light, false)
 check(bindings.halo_parameters.size() == 1, "Only opted-in scenery exposes a surface halo")
 check(is_equal_approx(scenery.get_child(0).material_override.get_shader_parameter("floor_neon_spread"), 4.86), "Width scales the authored radius")
 check(is_equal_approx(owner_node.get_child(1).material_override.get_shader_parameter("floor_neon_spread"), 2.7), "Shared gameplay source stays unchanged")
 bindings.apply_palette({}, light, false)
 check(is_equal_approx(scenery.get_child(0).material_override.get_shader_parameter("floor_neon_spread"), 2.7), "Neutral width restores the authored value")
 bindings.restore()
 owner_node.free()
 light.free()

func check_glow_shape() -> void:
 var view := SubViewport.new()
 view.size = Vector2i(256, 256)
 view.own_world_3d = true
 view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(view)
 var world := WorldEnvironment.new()
 var environment := Environment.new()
 world.environment = environment
 environment.background_mode = Environment.BG_COLOR
 environment.background_color = Color.BLACK
 environment.glow_enabled = true
 environment.glow_normalized = true
 view.add_child(world)
 var camera := Camera3D.new()
 camera.position.z = 3.0
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 4.0
 view.add_child(camera)
 camera.make_current()
 var emitter := MeshInstance3D.new()
 var quad := QuadMesh.new()
 quad.size = Vector2(0.12, 0.12)
 emitter.mesh = quad
 var material := StandardMaterial3D.new()
 material.albedo_color = Color.BLACK
 material.emission_enabled = true
 material.emission = Color.WHITE
 material.emission_energy_multiplier = 8.0
 emitter.material_override = material
 view.add_child(emitter)
 environment.set_glow_level(2, 1.0)
 environment.set_glow_level(4, 0.0)
 environment.glow_strength = 0.5
 var narrow := await capture(view, "fixture-low-spread")
 environment.glow_strength = 1.0
 var tight := await capture(view, "fixture-tight")
 check(halo_radius(tight) > halo_radius(narrow) * 1.1, "Glow spread increases the rendered halo radius")
 environment.set_glow_level(2, 0.0)
 environment.set_glow_level(4, 0.5)
 environment.set_glow_level(6, 0.5)
 var wide := await capture(view, "fixture-wide")
 print("GLOW_RADIUS | tight=", halo_radius(tight), " wide=", halo_radius(wide))
 check(halo_radius(wide) > halo_radius(tight) * 1.2, "Wide/diffuse controls spread light farther from the emitter")
 view.free()

func halo_radius(picture: Image) -> float:
 var weighted := 0.0
 var total := 0.0
 for y in picture.get_height():
  for x in picture.get_width():
   var distance := Vector2(x - 128, y - 128).length_squared()
   if distance < 64.0: continue
   var brightness := picture.get_pixel(x, y).r
   weighted += distance * brightness
   total += brightness
 return sqrt(weighted / maxf(total, 0.00001))

func check_transition(game: Node) -> void:
 var stream = load("res://scripts/endless/endless_game.gd").new()
 stream.presentation = game.presentation
 var before := Runtime.new()
 var after := Runtime.new()
 before.configure("green_hill", {"values": {}}, Environment.new(), game.presentation._key_light)
 after.configure("green_hill", {"values": WIDE}, Environment.new(), game.presentation._key_light)
 stream.backgrounds = {0: {"layer": {"atmosphere": before}}, 1: {"layer": {"atmosphere": after}}}
 stream._blend_lighting(0, 1, 0.5)
 var target: Environment = game.presentation._world_environment.environment
 for property: String in ["glow_strength", "glow_levels/3", "glow_levels/5", "glow_levels/7"]:
  check(is_equal_approx(target.get(property), lerpf(before.environment.get(property), after.environment.get(property), 0.5)), "Streamed glow blends " + property)
 check(target.glow_normalized, "Streamed normalization switches with the appearance")
 stream.free()
