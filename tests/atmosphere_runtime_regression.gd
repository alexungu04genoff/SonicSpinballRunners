extends "res://tests/atmosphere_profile.gd"
## Same-theme adjacent Zones deliberately use different appearances.
class FixtureGame extends "res://scripts/endless/endless_game.gd":
 func _next_planned_zone(documents: Array) -> Array[Dictionary]:
  var entries: Array[Dictionary] = super._next_planned_zone(documents)
  for entry: Dictionary in entries:
   entry.theme = "ice_cap"
   entry.atmosphere = {"id": "default" if entry.zone % 2 == 0 else "test_dusk", "values": {} if entry.zone % 2 == 0 else {"hue/terrain": 0.3, "hue/background": -0.2, "sun/light_color": Color("f4a8dc"), "env/ambient_light_color": Color("6c88af")}}
  return entries

var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(label)

func run() -> void:
 output = "res://test-results/atmosphere-variants/runtime"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 Engine.max_fps = 0
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 root.size = Vector2i(1280, 900)
 game = FixtureGame.new()
 root.add_child(game)
 var start := Time.get_ticks_msec()
 while (not game.started or not game._zone_ready(1) or game.resident.size() < 6) and Time.get_ticks_msec() - start < 240000: await process_frame
 check(game.started and game._zone_ready(1) and game.resident.size() == 6, "Two complete Zones prepared")
 if failures:
  game.free()
  quit(1)
  return
 check(game.library.fallback_builds == 0, "Runtime uses Act × Theme disk bakes")
 game.toggle_tour()
 game.set_process(false)
 Report.disable_native_input(game)
 _views(root)
 var before = game.backgrounds[0].layer.atmosphere
 var after = game.backgrounds[1].layer.atmosphere
 check(before.environment != after.environment and before.bindings != after.bindings, "Per-Zone ownership")
 check(before.bindings.materials.size() > 0 and after.bindings.materials.size() > 0, "Both Zones bind baked materials")
 var common := 0
 for source: Material in before.bindings.materials:
  if not after.bindings.materials.has(source): continue
  var a: Material = before.bindings.materials[source]
  var b: Material = after.bindings.materials[source]
  if a == source: continue
  common += 1
  check(a != b, "Shared recipe sources have distinct Zone copies")
  if source.has_meta("atmosphere_hue") and a is ShaderMaterial:
   check(is_zero_approx(float(a.get_shader_parameter("atmosphere_hue"))), "Default Zone remains authored")
   check(is_equal_approx(float(b.get_shader_parameter("atmosphere_hue")), 0.3), "Next Zone owns shifted terrain")
   check(source.get_shader_parameter("atmosphere_hue") == null or is_zero_approx(float(source.get_shader_parameter("atmosphere_hue"))), "Recipe material remains immutable")
 check(common > 0, "Ownership test exercises shared source materials")
 var source_count: int = before.bindings.materials.size()
 var base: Dictionary = before.values.duplicate(true)
 var strong := {"hue/terrain": 0.3, "saturation/terrain": 1.6, "hue/background": -0.2, "hue/neon": 0.35}
 samples = 360
 for index in 4:
  var values: Dictionary = strong if index in [1, 2] else base
  var timer := Time.get_ticks_usec()
  before.bindings.apply_palette(values, before.sun, false)
  preparation.append({"switch_cpu_ms": (Time.get_ticks_usec() - timer) / 1000.0})
  await frames(90)
  results.append(await sample("ice_cap", "strong" if index in [1, 2] else "default", index))
  if index < 2: await capture("runtime-" + str(index))
  check(before.bindings.materials.size() == source_count, "Switch reuses material copies")
 var identities := [game.ball.get_instance_id(), game.presentation.camera.get_instance_id()]
 game.presentation.tour_focus.y = game.backgrounds[1].entrance_y - 25.0
 game.presentation.camera_focus = game.presentation.tour_focus
 var timer := Time.get_ticks_usec()
 game._update_backgrounds()
 preparation.append({"transition_apply_cpu_ms": (Time.get_ticks_usec() - timer) / 1000.0})
 check(game.background_blend > 0.45 and game.background_blend < 0.55, "Distance-driven crossfade between variants")
 check(game.presentation._key_light.light_color.is_equal_approx(before.lighting.light_color.lerp(after.lighting.light_color, game.background_blend)), "Foreground light blends selected variants")
 await frames(90)
 results.append(await sample("ice_cap", "transition", 4))
 await capture("runtime-transition")
 check(identities == [game.ball.get_instance_id(), game.presentation.camera.get_instance_id()], "Transition preserves shared gameplay identities")
 var report := {"results": results, "preparation": preparation, "checks": checks, "failures": failures}
 report.merge(Report.metadata())
 FileAccess.open(output.path_join("report.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
 print("ATMOSPHERE_RUNTIME | checks=%d failures=%d" % [checks, failures])
 await game.prepare_to_close()
 game.free()
 quit(1 if failures else 0)
