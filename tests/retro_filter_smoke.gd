extends SceneTree
## Graphical A/B captures and viewport timings in the normal Green Hill application.
## Headless mode checks wiring/restoration; it cannot validate pixels or GPU cost.
const Filter := preload("res://scripts/retro/retro_filter.gd")
var output := "res://test-results/retro-stack"
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

func key(shift := false) -> void:
 var event := InputEventKey.new()
 event.physical_keycode = KEY_F4
 event.keycode = KEY_F4
 event.pressed = true
 event.shift_pressed = shift
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
 if index < 5:
  game.retro_filter.set_preset(index)
 else:
  game.retro_filter.set_effects([Filter.Preset.PIXEL, Filter.Preset.CRT] if index == 5 else Filter.ORDER)
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
 return {"preset": game.retro_filter.display_name(), "world_size": str(game.view.size), "frame": stats(wall), "gpu": stats(gpu), "render_cpu": stats(cpu)}

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
  var menu: PopupMenu = game.retro_controls.selector.get_popup()
  check(game.retro_filter.preset == selected and (selected == 0 or menu.is_item_checked(menu.get_item_index(selected))), "F4 cycles and synchronizes selector: " + Filter.NAMES[selected])
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
 game.retro_controls.selector.get_popup().id_pressed.emit(Filter.Preset.PIXEL)
 await frames(4)
 check(game.retro_filter.preset == Filter.Preset.PIXEL and game.view.size == Vector2i(game.view_container.size / 2.0), "Debug panel resizes filtered world without filtering its UI")
 game.toggle_debug()
 game.retro_filter.set_preset(Filter.Preset.OFF)
 await frames(4)
 await check_stacking(original)
 await check_ranges(original)
 if graphical and OS.get_cmdline_user_args().has("--benchmark"):
  DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
  Engine.max_fps = 0
  for viewport: Viewport in [root, game.view]:
   RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
  var report := {"godot": Engine.get_version_info().string, "adapter": RenderingServer.get_video_adapter_name(), "driver": RenderingServer.get_current_rendering_driver_name(), "root_size": str(root.size), "samples": 240, "warmup": 90, "runs": []}
  # Reverse pass reduces order/thermal bias. These are static-scene rendering costs.
  for index in [0, 1, 2, 3, 4, 5, 6, 6, 5, 4, 3, 2, 1, 0]:
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
  # Removing the toolbar button intentionally changes footer layout; the world must match.
  var world := Rect2i(0, 0, 1280, 690)
  check(removed.get_region(world).get_data() == baseline.get_region(world).get_data(), "OFF world matches the adapter removed entirely")
 game.queue_free()
 await frames(3)
 print("RESULT | Retro filters | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)

func check_stacking(original: Array) -> void:
 var adapter = game.retro_filter
 var controls = game.retro_controls
 controls.selector.get_popup().id_pressed.emit(Filter.Preset.PIXEL)
 controls.selector.get_popup().id_pressed.emit(Filter.Preset.CRT)
 check(adapter.selected_effects == [Filter.Preset.PIXEL, Filter.Preset.CRT], "Multiselect adds CRT without replacing Pixel")
 controls.selector.get_popup().id_pressed.emit(Filter.Preset.PIXEL)
 check(adapter.selected_effects == [Filter.Preset.CRT], "Unchecking Pixel preserves CRT")
 for mask in 16:
  var selected: Array = []
  for effect in range(1, 5):
   if mask & (1 << (effect - 1)):
    selected.append(effect)
  adapter.set_effects(selected)
  await frames(3)
  check(snapshot() == original, "Stack %d preserves camera and gameplay state" % mask)
  var enabled_passes := 0
  var correct := true
  for effect: int in Filter.ORDER:
   var enabled: bool = adapter.passes[effect].rect.visible
   enabled_passes += int(enabled)
   correct = correct and enabled == selected.has(effect) and adapter.passes[effect].copy.visible == enabled and controls.checks[effect].button_pressed == enabled
  check(correct and enabled_passes == selected.size(), "Stack %d renders exactly its selected passes and synchronizes checkboxes" % mask)
  if graphical:
   var frame := await image_now()
   check(frame.get_region(Rect2i(0, 710, 1280, 190)).get_data() == baseline.get_region(Rect2i(0, 710, 1280, 190)).get_data(), "Stack %d keeps HUD pixels unchanged" % mask)
   if mask in [5, 12, 15]:
    frame.save_png(output + "/stack-%d.png" % mask)
   if mask == 5:
    check(frame.get_data() != Image.load_from_file(ProjectSettings.globalize_path(output + "/pixel.png")).get_data() and frame.get_data() != Image.load_from_file(ProjectSettings.globalize_path(output + "/crt.png")).get_data(), "Pixel plus CRT differs visibly from either individual effect")
 adapter.set_effects([Filter.Preset.PIXEL, Filter.Preset.CRT])
 var original_cell: float = adapter.settings.crt_cell_size
 var original_glow: float = adapter.settings.crt_glow
 controls.fields.crt_cell_size.value = 12
 controls.fields.crt_glow.value = 0.6
 controls.fields.crt_brightness.value = 0.08
 await frames(3)
 check(adapter.settings.crt_cell_size == 12 and is_equal_approx(adapter.settings.crt_brightness, 0.08) and adapter.passes[Filter.Preset.CRT].material.get_shader_parameter("scanline_count") == game.view_container.size.y / 12.0 and adapter.passes[Filter.Preset.CRT].material.get_shader_parameter("halation_intensity") == 0.6, "Live sliders update cell size, brightness and glow without changing selection")
 check(snapshot() == original, "Live tuning preserves gameplay and camera state")
 if graphical:
  var tuned := await image_now()
  tuned.save_png(output + "/pixel-crt-tuned.png")
 controls.visible = true
 controls.toast.hide()
 await key(true)
 check(controls.tuning_panel.visible and adapter.selected_effects == [Filter.Preset.PIXEL, Filter.Preset.CRT], "Shift+F4 opens live tuning without changing the stack")
 check(root.get_visible_rect().encloses(controls.tuning_panel.get_global_rect()) and controls.open_button.get_global_rect().end.x <= root.get_visible_rect().end.x, "Tuning panel and normal Retro button fit the window")
 if graphical:
  var ui := await image_now()
  ui.save_png(output + "/live-tuning.png")
 controls.toggle_panel()
 controls.visible = false
 controls.reset_tuning()
 check(adapter.settings.crt_cell_size == original_cell and adapter.settings.crt_glow == original_glow and adapter.selected_effects.size() == 2, "Reset tuning restores defaults while keeping the selected stack")
 await key()
 check(adapter.preset == Filter.Preset.OFF, "F4 returns a custom stack to OFF")
 await frames(3)
 if graphical:
  var off := await image_now()
  check(off.get_data() == baseline.get_data(), "OFF remains pixel-identical after stacking and live tuning")

func check_ranges(original: Array) -> void:
 var adapter = game.retro_filter
 var controls = game.retro_controls
 adapter.set_effects([Filter.Preset.PIXEL, Filter.Preset.CRT])
 controls.fields.pixel_resolution_divisor.value = 1.1
 controls.fields.crt_cell_size.value = 1.0
 await frames(4)
 check(is_equal_approx(adapter.settings.pixel_resolution_divisor, 1.1) and game.view.size == Vector2i(game.view_container.size / 1.1), "Resolution divisor 1.1 renders the actual fractional viewport size")
 check(adapter.passes[Filter.Preset.CRT].material.get_shader_parameter("mask_density") == game.view_container.size.x, "One-pixel phosphor cells have no hidden size clamp")
 game.toggle_debug()
 await frames(4)
 check(game.view.size == Vector2i(game.view_container.size / 1.1), "Fractional resolution follows F1 layout resizing")
 game.toggle_debug()
 adapter.toggle_effect(Filter.Preset.N64)
 controls.fields.n64_resolution_divisor.value = 1.7
 await frames(4)
 check(game.view.size == Vector2i(game.view_container.size / 1.7), "Stacked fractional divisors choose the larger value")
 adapter.set_effects(Filter.ORDER)
 for maximum in [false, true]:
  var matched := true
  for name: String in controls.fields:
   var slider: HSlider = controls.fields[name]
   var endpoint := slider.max_value if maximum else slider.min_value
   slider.value = endpoint
   matched = matched and is_equal_approx(float(adapter.settings.get(name)), endpoint)
  await frames(4)
  check(matched and snapshot() == original, "All sliders accept their %s endpoints without changing gameplay" % ("maximum" if maximum else "minimum"))
  if graphical:
   var frame := await image_now()
   check(frame.get_region(Rect2i(0, 710, 1280, 190)).get_data() == baseline.get_region(Rect2i(0, 710, 1280, 190)).get_data(), "Extreme slider values leave HUD pixels unchanged")
 controls.reset_tuning()
 adapter.set_preset(Filter.Preset.OFF)
 await frames(4)
 if graphical:
  var off := await image_now()
  check(off.get_data() == baseline.get_data(), "OFF restores identical pixels after fractional and extreme tuning")
