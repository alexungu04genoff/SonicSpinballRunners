extends SceneTree
## Validate production Defaults and the device-local shadow option; no benchmark.
const Registry := preload("res://scripts/atmosphere/variants.gd")
const Runtime := preload("res://scripts/atmosphere/runtime.gd")
const Options := preload("res://scripts/rendering_options.gd")
const OUTPUT := "res://test-results/zone-defaults"
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(label)
func equal(a: Variant, b: Variant) -> bool:
 if b is float: return is_equal_approx(a, b)
 if b is Color: return a.is_equal_approx(b)
 return a == b
func frames() -> void:
 for frame in 8: await process_frame
func capture(view: Viewport, name: String) -> void:
 await frames()
 await RenderingServer.frame_post_draw
 check(view.get_texture().get_image().save_png(OUTPUT.path_join(name + ".png")) == OK, "Capture " + name)

func run() -> void:
 DirAccess.make_dir_recursive_absolute(OUTPUT)
 Options.settings_path = "user://shadow-option-regression.cfg"
 if FileAccess.file_exists(Options.settings_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(Options.settings_path))
 check(not Options.smooth_shadows_enabled(), "Ultra + FXAA is opt-in")
 root.size = Vector2i(1280, 900)
 var game = load("res://experiments/lighting_lab/lighting_lab.tscn").instantiate()
 root.add_child(game)
 paused = true
 await frames()
 var panel = game.lighting_controls
 var baseline: Dictionary = panel.values.duplicate(true)
 var msaa: int = game.view.msaa_3d
 panel.smooth_shadows.button_pressed = true
 check(Options.smooth_shadows_enabled() and game.view.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA, "Shadow toggle updates the live world viewport")
 check(panel.values == baseline and game.view.msaa_3d == msaa, "Quality choice preserves atmosphere values and MSAA")
 var next_view := SubViewport.new()
 Options.register_view(next_view)
 check(next_view.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA, "New gameplay/backdrop viewports inherit the option")
 var settings := ConfigFile.new()
 check(settings.load(Options.settings_path) == OK and settings.get_value("rendering", "smooth_shadows") == true, "Device option persists separately")
 panel.smooth_shadows.button_pressed = false
 check(game.view.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED and next_view.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED, "Disabling restores every live viewport")
 next_view.free()
 game.view_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var registry := Registry.new()
 var retro: Array = game.retro_filter.settings.default_effects.duplicate()
 var physics: int = game.world.get_instance_id()
 for theme: String in Registry.THEMES:
  var records := registry.read(theme)
  check(registry.error.is_empty(), theme + " has valid production data")
  var record := records[0]
  check(record.id == "default" and record.enabled and record.weight > 0 and not record.values.is_empty(), theme + " has an enabled authored Default")
  game.set_theme(theme)
  panel.variants.context.selected = "default"
  panel.variants.load_selected()
  game.presentation.overview_zoom = 0.85
  game.presentation.reset_camera()
  var environment: Environment = game.presentation._world_environment.environment
  var light: DirectionalLight3D = game.presentation._key_light
  for key: String in record.values:
   check(equal(panel.values.get(key), record.values[key]), theme + " Lab loads " + key)
   if key.begins_with("env/"): check(equal(environment.get(key.trim_prefix("env/")), record.values[key]), theme + " live environment " + key)
   if key.begins_with("sun/"): check(equal(light.get(key.trim_prefix("sun/")), record.values[key]), theme + " live sun " + key)
  var runtime := Runtime.new()
  var runtime_light := DirectionalLight3D.new()
  runtime.configure(theme, record, environment, runtime_light)
  for key: String in record.values:
   if key.begins_with("env/"): check(equal(runtime.environment.get(key.trim_prefix("env/")), record.values[key]), theme + " production environment " + key)
   if key.begins_with("sun/"): check(equal(runtime_light.get(key.trim_prefix("sun/")), record.values[key]), theme + " production sun " + key)
  runtime_light.free()
  check(game.world.get_instance_id() == physics, "Defaults preserve gameplay world")
  if theme in preload("res://scripts/themes/scenery_settings.gd").THEMES:
   check(game.presentation.scenery_settings.density == 2.5, theme + " loads Showcase scenery")
  for use_retro in [false, true]:
   game.retro_filter.set_effects(retro if use_retro else [])
   await capture(game.view, theme + ("-retro" if use_retro else "-plain"))
  game.presentation.overview_zoom = 1.3
  game.presentation.reset_camera()
  for use_retro in [false, true]:
   game.retro_filter.set_effects(retro if use_retro else [])
   await capture(game.view, theme + ("-retro" if use_retro else "-plain") + "-play")
  print("ZONE_DEFAULT | ", theme, " | validated and captured")
 game.free()
 print("ATMOSPHERE_DEFAULTS | checks=%d failures=%d" % [checks, failures])
 quit(1 if failures else 0)
