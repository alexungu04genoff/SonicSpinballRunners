extends SceneTree
## Whole-frame comparison in the real engine. Run graphically with VSync disabled.
const Game = preload("res://experiments/visual_lab/visual_lab.gd")
const Filter = preload("res://scripts/retro/retro_filter.gd")
const OUTPUT := "res://test-results/ice-review"
var game: Node
var results: Array[Dictionary] = []

func _initialize() -> void:
 call_deferred("run")

func frames(count: int) -> void:
 for i in count: await process_frame

func run() -> void:
 if DisplayServer.get_name() == "headless":
  quit(1)
  return
 root.size = Vector2i(1440, 1000)
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 Engine.max_fps = 0
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 game = Game.new()
 game.authored_act_path = "res://data/acts/decor_terraces.tres"
 root.add_child(game)
 await frames(30)
 paused = true
 game.set_theme("ice_cap")
 game.presentation.set_camera_follow(false)
 var center: Vector3 = game.presentation.map_point(game.presentation.table_bounds.get_center())
 var curtains: Node3D = game.presentation.scenery_root.find_child("AuroraCurtains", true, false)
 var reference := MeshInstance3D.new()
 reference.name = "BenchmarkOnlyCC0Volume"
 var cube := BoxMesh.new()
 cube.size = Vector3(2, 2, 2)
 reference.mesh = cube
 reference.position = curtains.get_child(0).position
 reference.scale = Vector3(55, 13.5, 5)
 reference.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var mat := ShaderMaterial.new()
 mat.shader = preload("res://third_party/aurora/miskatonic_reference.gdshader")
 var noise := FastNoiseLite.new()
 noise.seed = 1729
 noise.frequency = 0.035
 var texture := NoiseTexture2D.new()
 texture.width = 256
 texture.height = 256
 texture.noise = noise
 mat.set_shader_parameter("noise", texture)
 mat.set_shader_parameter("color", Color(0.15, 0.85, 0.55, 1))
 mat.set_shader_parameter("scale", 1.8)
 mat.set_shader_parameter("emission_strength", 2.0)
 reference.material_override = mat
 game.presentation.scenery_root.add_child(reference)
 reference.visible = false
 # Vista makes the aurora cover meaningful pixels; overview tests actual play.
 var overview: Transform3D = game.presentation.camera.transform
 for framing: String in ["overview", "vista"]:
  game.presentation.camera.transform = overview
  if framing == "vista":
   game.presentation.camera.position = center + Vector3(10, 6.5, 14)
   game.presentation.camera.look_at(center + Vector3(0, -0.8, -5))
  for filtered: bool in [false, true]:
   game.retro_filter.set_effects([Filter.Preset.N64, Filter.Preset.VHS, Filter.Preset.CRT] if filtered else [])
   # Resolution changes legitimately reconfigure the production camera. Set the
   # comparison view after that settles, so the vista benchmark is really a vista.
   await frames(12)
   game.presentation.camera.transform = overview
   if framing == "vista":
    game.presentation.camera.position = center + Vector3(10, 6.5, 14)
    game.presentation.camera.look_at(center + Vector3(0, -0.8, -5))
   var matched_camera: Transform3D = game.presentation.camera.transform
   for mode: String in ["off", "ribbons", "reference", "reference", "ribbons", "off"]:
    curtains.visible = mode == "ribbons"
    reference.visible = mode == "reference"
    await frames(45)
    var times: Array[float] = []
    var previous := Time.get_ticks_usec()
    for i in 120:
     await process_frame
     var current := Time.get_ticks_usec()
     times.append((current - previous) / 1000.0)
     previous = current
    times.sort()
    assert(game.presentation.camera.transform.is_equal_approx(matched_camera), "Benchmark camera must stay matched")
    var entry := {"mode": mode, "framing": framing, "camera": str(matched_camera), "filter": filtered, "median_ms": times[60], "p95_ms": times[114], "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
    results.append(entry)
    print("BENCHMARK | ", JSON.stringify(entry))
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(OUTPUT + "/aurora-%s-%s-%s.png" % [framing, mode, "retro" if filtered else "off"])
 var file := FileAccess.open(OUTPUT + "/aurora-benchmark.json", FileAccess.WRITE)
 file.store_string(JSON.stringify({"renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "window": str(root.size), "vsync": "disabled", "samples_per_pass": 120, "warmup_per_pass": 45, "results": results}, "  "))
 file.close()
 game.free()
 quit()
