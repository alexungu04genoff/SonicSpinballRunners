extends "res://tests/atmosphere_profile.gd"
## Optional ABBA measurement of reviewed Default values on the canonical disk fixture.
const Fixture = preload("res://tests/prototype_appearance_fixture.gd")
const Variants = preload("res://scripts/atmosphere/variants.gd")

func run() -> void:
 if DisplayServer.get_name() == "headless":
  quit(1)
  return
 if not "--retro=production" in OS.get_cmdline_user_args():
  push_error("This production comparison requires --retro=production.")
  quit(1)
  return
 output = "res://test-results/atmosphere-signatures/performance"
 var baseline := "res://test-results/atmosphere-signatures/source-before/data/atmospheres"
 var themes: Array = ["chemical_plant", "casino_night"]
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--baseline-atmospheres="): baseline = argument.trim_prefix("--baseline-atmospheres=")
  if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
  if argument.begins_with("--themes="): themes = Array(argument.trim_prefix("--themes=").split(","))
 for theme: String in themes:
  if theme not in Fixture.Registry.IDS:
   push_error("Unknown profile theme: " + theme)
   quit(1)
   return
 DirAccess.make_dir_recursive_absolute(output)
 preload("res://scripts/rendering_options.gd").settings_path = output.path_join("isolated-graphics.cfg")
 root.size = Vector2i(1440, 1000)
 root.gui_disable_input = true
 Engine.time_scale = 0.0
 Engine.max_fps = 0
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 samples = 360
 for theme: String in themes:
  var config := ConfigFile.new()
  if config.load(baseline.path_join(theme + ".cfg")) != OK:
   push_error("Missing explicit baseline atmosphere: " + theme)
   quit(1)
   return
  var previous_values: Dictionary = config.get_value("default", "values")
  var current_values: Dictionary = Variants.new().read(theme)[0].values
  var fixture := Fixture.new()
  if not await fixture.open(self, Fixture.DEFAULT_ACT, theme, output):
   push_error(fixture.error)
   quit(1)
   return
  game = fixture.game
  views.clear()
  _views(root)
  var state: Dictionary = fixture.state()
  for pass_index in 4:
   var label := "before" if pass_index in [0, 3] else "after"
   var values: Dictionary = previous_values if label == "before" else current_values
   var atmosphere = game.backgrounds[0].layer.atmosphere
   var start := Time.get_ticks_usec()
   atmosphere.values = values.duplicate(true)
   atmosphere.apply_properties(values, atmosphere.environment, atmosphere.sun)
   atmosphere.bindings.apply(float(values.get("emission", 1.0)))
   atmosphere.bindings.apply_palette(values, atmosphere.sun, true)
   preload("res://scripts/atmosphere/directional_fog.gd").apply(game.backgrounds[0].layer.camera, values)
   for property: String in atmosphere.LIGHT_FIELDS: atmosphere.lighting[property] = atmosphere.sun.get(property)
   atmosphere.lighting.quaternion = atmosphere.sun.quaternion
   atmosphere.sun.shadow_enabled = false
   game._last_atmosphere_blend = Vector3(-1, -1, -1)
   game._blend_lighting(0, 0, 0.0)
   preparation.append({"theme": theme, "variant": label, "apply_cpu_ms": (Time.get_ticks_usec() - start) / 1000.0})
   await frames(120)
   results.append(await sample(theme, label, pass_index))
   assert(fixture.state() == state, "Profiling cannot change gameplay or camera state")
   assert(fixture.still_current() and game.library.fallback_builds == 0, "Profiling requires unchanged valid disk recipes")
  await fixture.close()
 var report := {"results": results, "preparation": preparation, "samples_per_block": samples,
  "fixture": Fixture.DEFAULT_ACT, "retro": "Unmodified production N64/VHS/CRT stack via --retro=production",
  "note": "ABBA settled viewport timers; shader caches were not cleared. No screenshot readback in timed blocks. Values alone change; no new optional fog/glow path."}
 report.merge(Report.metadata())
 FileAccess.open(output.path_join("report.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
 quit()
