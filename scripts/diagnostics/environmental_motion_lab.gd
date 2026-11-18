extends Node
## Process-local environmental review over a real disk-loaded Prototype session.
## Gameplay, authored Acts, player preferences and atmosphere files are never saved.
const Fixture = preload("res://tests/prototype_appearance_fixture.gd")
const Registry = preload("res://scripts/theme_motion/registry.gd")
const Audit = preload("res://scripts/diagnostics/render_audit.gd")
const Report = preload("res://tests/render_profile_support.gd")
const Retro = preload("res://scripts/retro/retro_filter.gd")
const GroundingDirection = preload("res://scripts/diagnostics/grounding_control.gd")
var fixture: RefCounted
var motion: RefCounted
var output := "res://test-results/theme-motion/lab"
var theme_id := "green_hill"
var candidate := "C"
var tier := "FULL"
var environmental_time := 0.0
var playing := false
var busy := false
var baseline_zoom := 2.0
var preparation_ms := 0.0
var camera_mode := "normal"
var focus := "spawn"
var spawn_target := Vector2.ZERO
var retro_mode := "production"
var variant_id := "default"
var side_light := false
var production_lights: Array[Dictionary] = []
var clock_usec := 0
var layer: CanvasLayer
var status: Label
var summary: Label
var timeline: HSlider
var theme_choice: OptionButton
var candidate_choice: OptionButton
var tier_choice: OptionButton
var camera_choice: OptionButton
var focus_choice: OptionButton
var retro_choice: OptionButton
var controls: Array[Control] = []
var failures: Array[String] = []
var batch_rows: Array[Dictionary] = []

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 Engine.time_scale = 0.0
 Engine.max_fps = 0
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var window := get_tree().root
 get_tree().auto_accept_quit = false
 window.close_requested.connect(_close_lab)
 window.mode = Window.MODE_WINDOWED
 window.size = Vector2i(1440, 1000)
 # The developer launcher also places the first native frame on monitor 2.
 # Keep the entire review window on the non-primary display when available.
 for screen in DisplayServer.get_screen_count():
  if screen != DisplayServer.get_primary_screen():
   window.current_screen = screen
   window.position = DisplayServer.screen_get_position(screen) + Vector2i(20, 30)
   break
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
  if argument.begins_with("--theme="): theme_id = argument.trim_prefix("--theme=")
  if argument.begins_with("--motion-variant="): variant_id = argument.trim_prefix("--motion-variant=")
  if argument.begins_with("--motion-camera="): camera_mode = argument.trim_prefix("--motion-camera=")
  if argument.begins_with("--motion-focus="): focus = argument.trim_prefix("--motion-focus=")
  if argument.begins_with("--motion-retro="): retro_mode = argument.trim_prefix("--motion-retro=")
  if argument.begins_with("--motion-tier="): tier = argument.trim_prefix("--motion-tier=")
  if argument == "--motion-side-light": side_light = true
 DirAccess.make_dir_recursive_absolute(output)
 preload("res://scripts/rendering_options.gd").settings_path = output.path_join("isolated-graphics.cfg")
 _build_ui()
 if "--motion-capture" in OS.get_cmdline_user_args():
  _batch_capture.call_deferred()
 else:
  _open_theme.call_deferred(theme_id)

func _build_ui() -> void:
 layer = CanvasLayer.new()
 layer.layer = 100
 add_child(layer)
 var panel := PanelContainer.new()
 panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
 layer.add_child(panel)
 var box := VBoxContainer.new()
 panel.add_child(box)
 var row := HBoxContainer.new()
 box.add_child(row)
 var title := Label.new()
 title.text = "ENVIRONMENTAL MOTION LAB"
 row.add_child(title)
 theme_choice = _choice(row, Registry.IDS)
 candidate_choice = _choice(row, ["C", "A", "B"])
 tier_choice = _choice(row, ["FULL", "SIGNATURE", "STATIC", "NATIVE"])
 camera_choice = _choice(row, ["normal", "wide", "close"])
 focus_choice = _choice(row, ["spawn", "mid", "right", "left"])
 retro_choice = _choice(row, ["production", "n64", "off"])
 theme_choice.item_selected.connect(func(index: int): _open_theme(str(Registry.IDS[index])))
 candidate_choice.item_selected.connect(func(index: int): candidate = ["C", "A", "B"][index]; _apply())
 tier_choice.item_selected.connect(func(index: int): tier = ["FULL", "SIGNATURE", "STATIC", "NATIVE"][index]; _apply())
 camera_choice.item_selected.connect(func(index: int): _camera(["normal", "wide", "close"][index]))
 focus_choice.item_selected.connect(func(index: int): focus = ["spawn", "mid", "right", "left"][index]; _camera(camera_mode); _status())
 retro_choice.item_selected.connect(func(index: int): _retro(["production", "n64", "off"][index]))
 row = HBoxContainer.new()
 box.add_child(row)
 _button(row, "Play / Pause", func(): playing = not playing; clock_usec = Time.get_ticks_usec())
 _button(row, "−1 s", func(): _seek(maxf(0.0, environmental_time - 1.0)))
 _button(row, "+1 s", func(): _seek(environmental_time + 1.0))
 _button(row, "Restart", func(): _seek(0.0))
 timeline = HSlider.new()
 timeline.min_value = 0.0
 timeline.max_value = 20.0
 timeline.step = 0.01
 timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 timeline.custom_minimum_size.x = 220
 timeline.value_changed.connect(func(value: float): _seek(value))
 row.add_child(timeline)
 controls.append(timeline)
 _button(row, "Screenshot", _screenshot)
 _button(row, "6 s loop", _loop)
 _button(row, "C / A / B sheet", _comparison)
 _button(row, "Side light", _side_light)
 summary = Label.new()
 summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 box.add_child(summary)
 status = Label.new()
 box.add_child(status)

func _choice(parent: Node, items: Array) -> OptionButton:
 var control := OptionButton.new()
 for item: String in items: control.add_item(item.replace("_", " "))
 parent.add_child(control)
 controls.append(control)
 return control

func _button(parent: Node, text: String, callback: Callable) -> void:
 var button := Button.new()
 button.text = text
 button.pressed.connect(callback)
 parent.add_child(button)
 controls.append(button)

func _set_busy(value: bool) -> void:
 busy = value
 for control: Control in controls:
  if control is BaseButton: control.disabled = value
  elif control is Slider: control.editable = not value

func _open_theme(id: String) -> bool:
 if id not in Registry.IDS:
  _failure("Theme is excluded or unknown: " + id)
  return false
 _set_busy(true)
 playing = false
 status.text = "Loading validated disk recipes: " + id
 if fixture != null: await fixture.close()
 get_tree().paused = false
 motion = null
 fixture = Fixture.new()
 var began := Time.get_ticks_usec()
 if not await fixture.open(get_tree(), Fixture.DEFAULT_ACT, id, output, variant_id):
  _failure(fixture.error)
  _set_busy(false)
  return false
 preparation_ms = (Time.get_ticks_usec() - began) / 1000.0
 fixture.session.archive_attempted = true
 theme_id = id
 theme_choice.select(Registry.IDS.find(id))
 motion = fixture.game.backgrounds[fixture.game.active.plan.zone].layer.motion
 baseline_zoom = fixture.game.presentation.camera_settings.zoom
 spawn_target = fixture.game.ball.position
 # Preserve the canonical fixture's explicit target instead of snapping back
 # to Sonic when a review camera or Retro selection changes.
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--camera-target="):
   var coordinates := argument.trim_prefix("--camera-target=").split(",")
   if coordinates.size() == 2: spawn_target = Vector2(float(coordinates[0]), float(coordinates[1]))
 production_lights.clear()
 var lights: Array[DirectionalLight3D] = [fixture.game.presentation._key_light]
 for background: Dictionary in fixture.game.backgrounds.values(): lights.append(background.layer.light)
 for light: DirectionalLight3D in lights:
  production_lights.append({"reference": weakref(light), "basis": light.basis, "pitch": light.rotation_degrees.x})
 _camera(camera_mode)
 _retro(retro_mode)
 if side_light: _apply_side_light(true)
 _apply()
 _set_busy(false)
 return true

func _apply() -> void:
 if motion == null: return
 if not motion.select(candidate, tier): _failure("Invalid motion selection: " + candidate + "/" + tier)
 candidate_choice.select(["C", "A", "B"].find(candidate))
 tier_choice.select(["FULL", "SIGNATURE", "STATIC", "NATIVE"].find(tier))
 _seek(environmental_time)

func _seek(seconds: float) -> void:
 environmental_time = maxf(0.0, seconds)
 if motion != null and not motion.seek(environmental_time): _failure("Invalid environmental time")
 if layer != null and layer.visible:
  if timeline != null: timeline.set_value_no_signal(fmod(environmental_time, 20.0))
  _status()

func _status() -> void:
 if motion == null: return
 var data: Dictionary = motion.stats()
 summary.text = Registry.description(theme_id, candidate)
 status.text = "%s · %s/%s · %.2f s · %s camera / %s focus · CPU callbacks %s · materials %s · moving meshes %s · update %s µs" % [theme_id.replace("_", " "), candidate, tier, environmental_time, camera_mode, focus, str(data.get("cpu_callbacks", 0)), str(data.get("animated_materials", 0)), str(data.get("moving_meshes", 0)), str(data.get("cpu_motion_usec", 0))]
 summary.text += " | Active: " + str(data.get("systems", []))

func _process(_delta: float) -> void:
 var now := Time.get_ticks_usec()
 if playing and not busy and motion != null and clock_usec > 0: _seek(environmental_time + (now - clock_usec) / 1000000.0)
 clock_usec = now

func _camera(mode: String) -> void:
 camera_mode = mode
 if camera_choice != null: camera_choice.select(["normal", "wide", "close"].find(mode))
 if focus_choice != null: focus_choice.select(["spawn", "mid", "right", "left"].find(focus))
 if fixture == null or fixture.game == null: return
 var settings: Dictionary = fixture.game.presentation.camera_settings
 settings.zoom = 0.6 if mode == "wide" else clampf(baseline_zoom * (1.25 if mode == "close" else 1.0), 0.6, 2.5)
 fixture.game.presentation.reset_camera(_focus_target())
 fixture.game._process(0.0)
 if side_light: _apply_side_light(true)

func _focus_target() -> Vector2:
 if focus == "spawn": return spawn_target
 var bounds: Rect2 = fixture.game.active.document.terrain_bounds()
 bounds.position += Vector2(fixture.game.active.plan.offset)
 if focus == "mid": return bounds.get_center()
 var inset: float = float(fixture.game.active.document.cell_size) * 0.6
 var y := clampf(spawn_target.y, bounds.position.y + inset, bounds.end.y - inset)
 return Vector2(bounds.end.x - inset if focus == "right" else bounds.position.x + inset, y)

func _retro(mode: String) -> void:
 retro_mode = mode
 if retro_choice != null: retro_choice.select(["production", "n64", "off"].find(mode))
 if fixture == null or fixture.game == null: return
 var filter: Node = fixture.game.retro_filter
 filter.set_effects(filter.settings.default_effects if mode == "production" else ([Retro.Preset.N64] if mode == "n64" else []))
 fixture.game._process(0.0)
 if side_light: _apply_side_light(true)

func _side_light() -> void:
 side_light = not side_light
 _apply_side_light(side_light)

func _apply_side_light(enabled: bool) -> void:
 if fixture == null or fixture.game == null or theme_id not in ["rooftop_run", "sky_sanctuary"]: return
 for state: Dictionary in production_lights:
  var light := state.reference.get_ref() as DirectionalLight3D
  if light == null: continue
  # Reuse only the established pure direction calculation. No grounding
  # controller or shadow proxy is constructed by the Motion Lab.
  light.basis = GroundingDirection.direction_basis(2, fixture.game.presentation.camera, float(state.pitch)) if enabled else state.basis
 status.text = "Unsaved lighting diagnostic: camera-right cross-key" if enabled else "Production light bases restored"

func _settled_image() -> Image:
 await get_tree().process_frame
 await RenderingServer.frame_post_draw
 return get_tree().root.get_texture().get_image()

func _screenshot() -> void:
 if busy or motion == null: return
 _set_busy(true)
 layer.hide()
 var image := await _settled_image()
 var path := output.path_join("%s_%s_%s_%.2f.png" % [theme_id, candidate, tier, environmental_time])
 image.save_png(path)
 layer.show()
 _set_busy(false)
 status.text = "Saved " + ProjectSettings.globalize_path(path)

func _comparison() -> void:
 if busy or motion == null: return
 _set_busy(true)
 playing = false
 layer.hide()
 var saved := candidate
 var images: Array[Image] = []
 for state: String in ["C", "A", "B"]:
  candidate = state
  _apply()
  images.append(await _settled_image())
 var sheet := Image.create(images[0].get_width() * 3, images[0].get_height(), false, Image.FORMAT_RGB8)
 for i in images.size():
  images[i].convert(Image.FORMAT_RGB8)
  sheet.blit_rect(images[i], Rect2i(Vector2i.ZERO, images[i].get_size()), Vector2i(i * images[i].get_width(), 0))
 var path := output.path_join(theme_id + "_C-A-B.png")
 sheet.save_png(path)
 candidate = saved
 _apply()
 layer.show()
 _set_busy(false)
 status.text = "Saved C / A / B at matched time: " + ProjectSettings.globalize_path(path)

func _loop() -> void:
 if busy or motion == null: return
 _set_busy(true)
 playing = false
 layer.hide()
 var directory := output.path_join(theme_id + "_" + candidate + "_loop")
 await _capture_frames(directory, 6.0, 15)
 var movie := ProjectSettings.globalize_path(directory + ".mp4")
 var log: Array = []
 var result := OS.execute("ffmpeg", PackedStringArray(["-y", "-hide_banner", "-loglevel", "error", "-framerate", "15", "-i", ProjectSettings.globalize_path(directory.path_join("%05d.jpg")), "-c:v", "libx264", "-preset", "fast", "-crf", "23", "-pix_fmt", "yuv420p", "-movflags", "+faststart", movie]), log, true, false)
 layer.show()
 _set_busy(false)
 status.text = "Saved " + movie if result == 0 else "Frames saved; ffmpeg failed. " + str(log)

func _capture_frames(directory: String, seconds: float, fps: int) -> void:
 DirAccess.make_dir_recursive_absolute(directory)
 var first: Image
 var frame_count := maxi(1, roundi(seconds * fps))
 for index in frame_count:
  _seek(float(index) / fps)
  var image := await _settled_image()
  if index == 0:
   first = image
   image.save_png(directory.get_base_dir().path_join(directory.get_file() + ".png"))
  if image.save_jpg(directory.path_join("%05d.jpg" % index), 0.95) != OK: _failure("Cannot write capture frame")
 _seek(0.0)
 var repeat := await _settled_image()
 # The world presentation, including Retro, must return to the same pixels.
 var reproducible := first.get_data() == repeat.get_data()
 _write_json(directory.path_join("capture.json"), {"theme": theme_id, "candidate": candidate, "tier": tier, "seconds": float(frame_count) / fps, "fps": fps, "frames": frame_count, "frame_format": "jpg", "frame_quality": 0.95, "camera": camera_mode, "focus": focus, "camera_target": str(_focus_target()), "retro": retro_mode, "deterministic_repeat_pixels": reproducible, "motion": motion.stats(), "receipt": fixture.receipt, "state": fixture.state()})
 if not reproducible: _failure("Environmental framebuffer did not repeat at time zero: " + theme_id + "/" + candidate)

func _benchmark(frames: int) -> Dictionary:
 var views := Audit.viewports(fixture.game)
 for view: Dictionary in views: RenderingServer.viewport_set_measure_render_time(view.node.get_viewport_rid(), true)
 var before := Report.pipelines()
 var resources_before := Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 var warm_start := Time.get_ticks_usec()
 for frame in 40:
  _seek(frame / 60.0)
  await get_tree().process_frame
 var warm_ms := (Time.get_ticks_usec() - warm_start) / 1000.0
 var times: Array = []
 var cpu: Array = []
 var gpu: Array = []
 var updates: Array = []
 var counters := {}
 var previous := Time.get_ticks_usec()
 for frame in frames:
  var motion_started := Time.get_ticks_usec()
  _seek(frame / 60.0)
  updates.append((Time.get_ticks_usec() - motion_started) / 1000.0)
  await get_tree().process_frame
  var now := Time.get_ticks_usec()
  times.append((now - previous) / 1000.0)
  previous = now
  if frame % 15 != 0: continue
  var cpu_sum := 0.0
  var gpu_sum := 0.0
  counters = {"draws": 0, "objects": 0, "primitives": 0, "shadow_draws": 0, "transparent_draws": null}
  for view: Dictionary in views:
   var state := Audit.viewport_state(view.node, view.role, true)
   if view.role == "output" or not state.active: continue
   if state.render_cpu_ms != null: cpu_sum += float(state.render_cpu_ms)
   if state.render_gpu_ms != null: gpu_sum += float(state.render_gpu_ms)
   counters.draws += state.visible.draws
   counters.objects += state.visible.objects
   counters.primitives += state.visible.primitives
   counters.shadow_draws += state.shadow.draws
  cpu.append(cpu_sum)
  gpu.append(gpu_sum)
 var delta := {}
 var after := Report.pipelines()
 for key: String in before: delta[key] = after[key] - before[key]
 return {"frame": Report.timing(times), "render_cpu": Report.timing(cpu), "render_gpu": Report.timing(gpu), "motion_update": Report.timing(updates), "counters": counters, "warmup_frames": 40, "warmup_ms": warm_ms, "pipeline_compilations": delta, "resource_delta": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT) - resources_before, "resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), "preparation_ms": preparation_ms, "motion": motion.stats(), "resident_inventory": _resource_inventory(), "note": "Uncapped presented-frame timing; frozen gameplay; capture/readback and hidden-UI formatting excluded. Motion update measures diagnostic seek/uniform upload, not native production cost. CPU/GPU viewport sums may overlap. Transparent draw count unavailable. Desktop evidence is not UHD certification."}

func _diagnostic_frames() -> Array[Dictionary]:
 var saved_camera := camera_mode
 var saved_retro := retro_mode
 var saved_focus := focus
 var saved_time := environmental_time
 var result: Array[Dictionary] = []
 for camera: String in ["normal", "wide", "close"]:
  for retro: String in ["production", "n64", "off"]:
   _camera(camera)
   _retro(retro)
   _seek(7.25)
   # Resolution changes need one compositor settlement before image readback.
   for frame in 3: await get_tree().process_frame
   var image := await _settled_image()
   var filename := "%s_%s_%s_%s_%s.png" % [theme_id, candidate, focus, camera, retro]
   image.save_png(output.path_join(filename))
   result.append({"image": filename, "camera": camera, "focus": focus, "retro": retro, "time": 7.25})
 for edge: String in ["spawn", "right", "left"]:
  focus = edge
  _camera("normal")
  _retro("production")
  _seek(7.25)
  for frame in 3: await get_tree().process_frame
  var image := await _settled_image()
  var filename := "%s_%s_%s_normal_production.png" % [theme_id, candidate, edge]
  image.save_png(output.path_join(filename))
  result.append({"image": filename, "camera": "normal", "focus": edge, "retro": "production", "time": 7.25})
 focus = saved_focus
 _camera(saved_camera)
 _retro(saved_retro)
 _seek(saved_time)
 for frame in 3: await get_tree().process_frame
 return result

func _resource_inventory() -> Dictionary:
 var materials := {}
 var shaders := {}
 var transparent_surfaces := 0
 for entry: Dictionary in Audit.viewports(fixture.game):
  if entry.role in ["output", "composite", "warmup"]: continue
  for node: Node in entry.node.find_children("*", "GeometryInstance3D", true, false):
   var mesh := Audit.mesh_of(node)
   if mesh == null: continue
   for surface in mesh.get_surface_count():
    var material: Material = node.get_active_material(surface) if node is MeshInstance3D else node.material_override
    if material == null: material = mesh.surface_get_material(surface)
    while material != null:
     materials[material.get_instance_id()] = true
     if material is ShaderMaterial and material.shader != null: shaders[material.shader.get_instance_id()] = true
     if Audit.material_state(material).transparent: transparent_surfaces += 1
     material = material.next_pass
 var signatures := {}
 var records := 0
 for recipe: Resource in [fixture.game.active.recipe, fixture.game.library.backgrounds[theme_id]]:
  records += recipe.records.size()
  for record: Dictionary in recipe.records:
   for signature: String in record.get("warm_signatures", PackedStringArray()): signatures[signature] = true
 var bake_bytes := 0
 for path: String in [fixture.receipt.act_bake, fixture.receipt.theme_bake]:
  var file := FileAccess.open(path, FileAccess.READ)
  if file != null: bake_bytes += file.get_length()
 return {"materials": materials.size(), "shader_resources": shaders.size(), "transparent_surface_slots": transparent_surfaces, "recipe_records": records, "recipe_bytes": bake_bytes, "warm_signatures": signatures.size(), "scope": "Resident canonical Act and shared background; recipe bytes exclude shared asset bank. Transparent slots are eligibility, not visible submissions."}

func _batch_capture() -> void:
 var themes: Array = Registry.IDS.duplicate()
 var states: Array = ["C", "A", "B"]
 var fps := 15
 var seconds := 6.0
 var sample_frames := 180
 var capture := true
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--themes="): themes = Array(argument.trim_prefix("--themes=").split(","))
  if argument.begins_with("--theme="): themes = [argument.trim_prefix("--theme=")]
  if argument.begins_with("--states="): states = Array(argument.trim_prefix("--states=").split(","))
  if argument.begins_with("--motion-fps="): fps = clampi(int(argument.trim_prefix("--motion-fps=")), 1, 60)
  if argument.begins_with("--motion-seconds="): seconds = clampf(float(argument.trim_prefix("--motion-seconds=")), 0.1, 12.0)
  if argument.begins_with("--sample-frames="): sample_frames = clampi(int(argument.trim_prefix("--sample-frames=")), 30, 1800)
  if argument.begins_with("--motion-tier="): tier = argument.trim_prefix("--motion-tier=")
  if argument.begins_with("--motion-camera="): camera_mode = argument.trim_prefix("--motion-camera=")
  if argument.begins_with("--motion-retro="): retro_mode = argument.trim_prefix("--motion-retro=")
  if argument == "--benchmark-only": capture = false
 for id: String in themes:
  if not await _open_theme(id): break
  _set_busy(true)
  layer.hide()
  var invariant: Dictionary = fixture.state()
  var inventory := Audit.inventory(fixture.game)
  _write_json(output.path_join(id + "_inventory.json"), inventory)
  for state: String in states:
   candidate = state
   _apply()
   var measurements := await _benchmark(sample_frames)
   if not measurements.has("frame"):
    _failure("Benchmark failed before returning frame measurements: " + id + "/" + state)
    get_tree().quit(1)
    return
   var directory := output.path_join(id + "_" + state)
   if capture: await _capture_frames(directory, seconds, fps)
   var diagnostics: Array[Dictionary] = []
   if "--motion-diagnostics" in OS.get_cmdline_user_args(): diagnostics = await _diagnostic_frames()
   if fixture.state() != invariant: _failure("Gameplay/camera mutated during motion review: " + id)
   if not fixture.still_current(): _failure("Source/bake changed during review: " + id)
   var row := {"theme": id, "candidate": state, "tier": tier, "camera": camera_mode, "focus": focus, "camera_target": str(_focus_target()), "retro": retro_mode, "variant": variant_id, "side_light": side_light, "directory": directory.get_file(), "description": Registry.description(id, state), "benchmark": measurements, "receipt": fixture.receipt, "diagnostics": diagnostics}
   batch_rows.append(row)
   _write_json(output.path_join("manifest.json"), {"complete": false, "rows": batch_rows, "failures": failures})
   print("THEME_MOTION_CAPTURE | %s | %s | %.3f ms | %s" % [id, state, measurements.frame.median_ms, JSON.stringify(measurements.motion)])
  await fixture.close()
  fixture = null
  motion = null
  get_tree().paused = false
 var complete := failures.is_empty() and batch_rows.size() == themes.size() * states.size()
 _write_json(output.path_join("manifest.json"), {"complete": complete, "rows": batch_rows, "failures": failures, "metadata": Report.metadata()})
 print("THEME_MOTION_COMPLETE | rows=%d | failures=%d" % [batch_rows.size(), failures.size()])
 get_tree().quit(0 if complete else 1)

func _failure(message: String) -> void:
 failures.append(message)
 if status != null: status.text = message
 push_error(message)

func _close_lab() -> void:
 playing = false
 if busy:
  # A capture/load coroutine may still be in flight. Engine tree teardown owns
  # its nodes; a second asynchronous session teardown would race that work.
  get_tree().quit()
  return
 _set_busy(true)
 if fixture != null:
  await fixture.close()
  fixture = null
 motion = null
 get_tree().paused = false
 get_tree().quit()

func _write_json(path: String, data: Dictionary) -> void:
 var file := FileAccess.open(path, FileAccess.WRITE)
 if file == null: _failure("Cannot write " + path)
 else: file.store_string(JSON.stringify(data, "  "))
