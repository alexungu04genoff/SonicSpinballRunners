extends SceneTree
## Graphical A/B captures and viewport timings in the normal Green Hill application.
## Headless mode checks wiring/restoration; it cannot validate pixels or GPU cost.
const Filter := preload("res://scripts/retro/retro_filter.gd")
var output := "res://test-results/retro"
var game: Node
var checks := 0
var failures := 0
var graphical := false
var baseline: Image

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, description: String) -> void:
 checks += 1
 if ok:
  print("PASS | ", description)
 else:
  failures += 1
  push_error("FAIL | " + description)

func frames(count: int) -> void:
 for _i in count:
  await process_frame

func freeze_processes(node: Node) -> void:
 node.set_process(false)
 node.set_physics_process(false)
 for child in node.get_children():
  freeze_processes(child)

func snapshot() -> Array:
 return [game.ball.position, game.ball.linear_velocity, game.score, game.rings_collected,
  game.layout.signature, game.tuning.effective.duplicate(true), game.presentation.camera.global_transform,
  game.presentation.camera.fov, game.presentation.camera_settings.duplicate(true), Engine.physics_ticks_per_second]

func key() -> void:
 var event := InputEventKey.new()
 event.physical_keycode = KEY_F4
 event.keycode = KEY_F4
 event.pressed = true
 root.push_input(event, true)
 event = event.duplicate()
 event.pressed = false
 root.push_input(event, true)
 await frames(3)

func image_now() -> Image:
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()

func stats(values: Array[float]) -> Dictionary:
 values.sort()
 var total := 0.0
 for value in values:
  total += value
 return {"mean_ms": total / values.size(), "median_ms": values[values.size() / 2], "p95_ms": values[int(values.size() * 0.95)]}

func measure(index: int) -> Dictionary:
 game.retro_filter.set_preset(index)
 # Warm shaders, screen-copy buffers and GPU timestamp queries before sampling.
 await frames(90)
 var wall: Array[float] = []
 var gpu: Array[float] = []
 var cpu: Array[float] = []
 var previous := Time.get_ticks_usec()
 for _sample in 240:
  await RenderingServer.frame_post_draw
  var now := Time.get_ticks_usec()
  wall.append((now - previous) / 1000.0)
  previous = now
  var gpu_ms := 0.0
  var cpu_ms := RenderingServer.get_frame_setup_time_cpu()
  for viewport: Viewport in [root, game.view]:
   gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid())
   cpu_ms += RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid())
  gpu.append(gpu_ms)
  cpu.append(cpu_ms)
 return {"preset": Filter.NAMES[index], "world_size": str(game.view.size), "frame": stats(wall), "gpu": stats(gpu), "render_cpu": stats(cpu)}

func run() -> void:
 graphical = DisplayServer.get_name() != "headless"
 if OS.get_cmdline_user_args().has("--native-report"):
  output += "-native"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 game = load("res://experiments/visual_lab/visual_lab.tscn").instantiate()
 game.generation_seed = 18
 root.add_child(game)
 await frames(45)
 check(game.retro_filter.preset == Filter.Preset.OFF and game.view_container.material == null and game.view_container.stretch_shrink == 1, "Normal application starts with original rendering")
 paused = true
 # Freeze the entire same scene, including cosmetic animations and HUD counters.
 # Only preset shaders change; camera, actors, rings, lights and geometry stay fixed.
 freeze_processes(game)
 game.retro_controls.visible = false
 await frames(4)
 var original := snapshot()
 var original_size: Vector2i = game.view.size
 var original_filter: int = game.view_container.texture_filter
 if graphical:
  baseline = await image_now()
  baseline.save_png(output + "/off.png")
 for index in range(1, 6):
  await key()
  var selected := index % 5
  check(game.retro_filter.preset == selected and game.retro_controls.selector.selected == selected, "F4 cycles and synchronizes selector: " + Filter.NAMES[selected])
  check(snapshot() == original, "Preset preserves camera and gameplay state: " + Filter.NAMES[selected])
  check(game.debug_panel.get_viewport() == root and game.lab_ui.get_viewport() == root and game.challenge_ui.get_viewport() == root, "HUD, debug, Scorecraft and menus stay in native root viewport")
  if graphical:
   var rendered := await image_now()
   rendered.save_png(output + "/" + ["off-restored", "pixel", "n64", "crt", "vhs"][selected] + ".png")
   # The opaque footer contains actual UI and is independent of the world behind it.
   var footer := Rect2i(0, 710, 1280, 190)
   check(baseline.get_region(footer).get_data() == rendered.get_region(footer).get_data(), "Native HUD pixels remain identical: " + Filter.NAMES[selected])
   if selected == 0:
    check(baseline.get_data() == rendered.get_data(), "OFF round-trip restores identical full-frame pixels")
   else:
    check(baseline.get_data() != rendered.get_data(), "Preset visibly changes world pixels: " + Filter.NAMES[selected])
 check(game.view.size == original_size and game.view_container.texture_filter == original_filter and game.view_container.material == null, "OFF restores resolution, sampler and original material")
 # Selector path works too, including while the normal F1 panel is visible.
 game.toggle_debug()
 game.retro_controls.selector.item_selected.emit(Filter.Preset.PIXEL)
 await frames(4)
 check(game.retro_filter.preset == Filter.Preset.PIXEL and game.view.size == Vector2i(game.view_container.size / 2.0), "Debug panel resizes filtered world without filtering its UI")
 game.toggle_debug()
 game.retro_filter.set_preset(Filter.Preset.OFF)
 await frames(4)
 if graphical and OS.get_cmdline_user_args().has("--benchmark"):
  DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
  Engine.max_fps = 0
  for viewport: Viewport in [root, game.view]:
   RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
  var report := {"godot": Engine.get_version_info().string, "adapter": RenderingServer.get_video_adapter_name(), "driver": RenderingServer.get_current_rendering_driver_name(), "root_size": str(root.size), "samples": 240, "warmup": 90, "runs": []}
  # Reverse pass reduces order/thermal bias. These are static-scene rendering costs.
  for index in [0, 1, 2, 3, 4, 4, 3, 2, 1, 0]:
   var result := await measure(index)
   report.runs.append(result)
   print("RETRO_PERF | ", JSON.stringify(result))
  var file := FileAccess.open(output + "/performance.json", FileAccess.WRITE)
  file.store_string(JSON.stringify(report, "  "))
 # Removing just the adapter returns to the exact legacy presentation path.
 game.retro_filter.set_preset(Filter.Preset.OFF)
 game.retro_filter.queue_free()
 await frames(4)
 check(game.view_container.material == null and game.view.size == original_size, "Adapter removal restores the original presentation path")
 check(not is_instance_valid(game.retro_controls), "Adapter removal also removes its controls and key handler")
 if graphical:
  var removed := await image_now()
  check(removed.get_data() == baseline.get_data(), "OFF matches the frame with the adapter removed entirely")
 game.queue_free()
 await frames(3)
 print("RESULT | Retro filters | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
