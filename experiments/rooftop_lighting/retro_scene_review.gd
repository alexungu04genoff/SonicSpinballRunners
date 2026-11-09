extends "res://experiments/rooftop_lighting/scene_review.gd"
## Same material experiment through the existing saved retro stack.
## Capture time is replayable; original production shaders and settings stay intact.
const RETRO_OUTPUT := "res://experiments/rooftop_lighting/captures/retro-scene-study/"
const FPS := 30
const HOLD_FRAMES := 30
const MOVE_FRAMES := 120
const TOTAL_FRAMES := HOLD_FRAMES * 2 + MOVE_FRAMES
var retro_enabled := false
var retro_button: CheckButton
var movement_button: Button
var synchronized_vhs: ShaderMaterial
var output_view: SubViewport
var output_rect: TextureRect
var retro_report := {}
var recording := false
var preview_movement := false
var preview_time := 0.0
var live_shader_time := 0.0

func run() -> void:
 await super.run()
 output_path = RETRO_OUTPUT
 DirAccess.make_dir_recursive_absolute(output_path)
 install_replayable_time()
 make_output_view()
 set_scene_view("close")
 if "--capture-retro-close" in OS.get_cmdline_user_args():
  recording = true
  output_path = OUTPUT + "retro-close-study/"
  DirAccess.make_dir_recursive_absolute(output_path)
  root.get_node("SceneControls").hide()
  set_scene_view("close")
  for filtered in [false, true]:
   set_retro(filtered)
   for mode in 4:
    apply_mode(mode)
    set_review_time(2.0)
    await frames(10)
    var still := await output_image()
    var name: String = ("retro" if filtered else "normal") + "-" + SCENE_NAMES[mode].to_lower()
    still.save_png(output_path + name + ".png")
    print("SCREENSHOT | ", name)
  quit()
  return
 if "--capture-retro-scene" in OS.get_cmdline_user_args():
  recording = true
  root.get_node("SceneControls").hide()
  var source := FileAccess.get_file_as_bytes("res://experiments/rooftop_lighting/existing_act.tres")
  var document: String = game.authored_document.fingerprint()
  var ball_id: int = game.ball.get_instance_id()
  retro_report["settings"] = settings_snapshot()
  retro_report["sequences"] = {}
  retro_report["stills"] = {}
  for filtered in [false, true]:
   set_retro(filtered)
   var filter_name := "retro" if filtered else "normal"
   for mode in 4:
    apply_mode(mode)
    set_scene_view("gameplay")
    set_review_time(2.0)
    await frames(12)
    var name: String = filter_name + "-" + SCENE_NAMES[mode].to_lower()
    var still := await output_image()
    if still.save_png(output_path + name + ".png") != OK: failures += 1
    retro_report.stills[name] = state_snapshot()
    var sequence_path := output_path + name + "/"
    DirAccess.make_dir_recursive_absolute(sequence_path)
    var trajectory: Array[String] = []
    var timestamps: Array[float] = []
    for index in TOTAL_FRAMES:
     var seconds := float(index) / FPS
     set_motion_frame(index)
     set_review_time(2.0 + seconds)
     # Allow the world screen-copy passes and final upscaler to consume the
     # same requested pose/time before reading the GPU result.
     await frames(2)
     var image := await output_image()
     if image.save_png(sequence_path + "%04d.png" % index) != OK: failures += 1
     trajectory.append(str(game.presentation.camera.transform))
     timestamps.append(2.0 + seconds)
    var invariant: bool = geometry_fingerprint() == baseline_geometry and document == game.authored_document.fingerprint() and ball_id == game.ball.get_instance_id()
    if not invariant: failures += 1
    retro_report.sequences[name] = {"trajectory": trajectory, "shader_times": timestamps, "geometry_gameplay_unchanged": invariant, "state": state_snapshot()}
    print("SEQUENCE | ", name, " | ", TOTAL_FRAMES, " frames | geometry/gameplay ", invariant)
  # Hold BOTH camera and VHS time: isolate animated filter noise from temporal
  # instability in materials/rendering. Full stack remains enabled.
  set_retro(true)
  apply_mode(3)
  set_scene_view("gameplay")
  set_review_time(2.0)
  await frames(10)
  var locked := await output_image()
  var repeatable := true
  for index in 8:
   await frames(2)
   var next := await output_image()
   if next.get_data() != locked.get_data(): repeatable = false
  retro_report["fixed_camera_fixed_filter_time_pixel_identical"] = repeatable
  if not repeatable: failures += 1
  if source != FileAccess.get_file_as_bytes("res://experiments/rooftop_lighting/existing_act.tres"): failures += 1
  retro_report["failures"] = failures
  retro_report["fps"] = FPS
  retro_report["frames_per_sequence"] = TOTAL_FRAMES
  retro_report["stationary_frames_at_start_and_end"] = HOLD_FRAMES
  FileAccess.open(output_path + "validation.json", FileAccess.WRITE).store_string(JSON.stringify(retro_report, "  "))
  print("RESULT | Retro material comparison | ", failures, " failures")
  quit(1 if failures else 0)
 elif "--retro-scene-controls-smoke" in OS.get_cmdline_user_args():
  recording = true
  for enabled in [true, false, true]:
   retro_button.button_pressed = enabled
   for mode in 4:
    apply_mode(mode)
    await frames(2)
    if retro_enabled != enabled or game.retro_filter.selected_effects != (game.retro_filter.settings.default_effects if enabled else []): failures += 1
  movement_button.pressed.emit()
  await frames(10)
  if not preview_movement: failures += 1
  movement_button.pressed.emit()
  await frames(3)
  if game.presentation.camera.transform != gameplay_camera_state.transform: failures += 1
  if geometry_fingerprint() != baseline_geometry: failures += 1
  print("RESULT | Retro controls | ", failures, " failures")
  quit(1 if failures else 0)

func install_replayable_time() -> void:
 # Freeze unrelated ambient shader animation (the canal), which otherwise
 # continues even while the scene tree is paused. Preserve it across swaps.
 var frozen := {}
 for slot in slots:
  var original: Material = slot.material
  if not original is ShaderMaterial or not "TIME" in original.shader.code: continue
  var key := original.get_instance_id()
  if not frozen.has(key):
   var material: ShaderMaterial = original.duplicate()
   var frozen_shader := Shader.new()
   frozen_shader.code = original.shader.code.replace("TIME", "2.0")
   material.shader = frozen_shader
   frozen[key] = material
  slot.material = frozen[key]
 var pass_data: Dictionary = game.retro_filter.passes[4]
 synchronized_vhs = pass_data.material.duplicate()
 var shader := Shader.new()
 shader.code = synchronized_vhs.shader.code.replace("TIME", "review_time").replace("shader_type canvas_item;", "shader_type canvas_item;\nuniform float review_time = 0.0;")
 synchronized_vhs.shader = shader
 pass_data.material = synchronized_vhs
 pass_data.rect.material = synchronized_vhs
 game.retro_filter.apply_settings()

func make_output_view() -> void:
 output_view = SubViewport.new()
 output_view.name = "RetroComparisonOutput"
 output_view.size = Vector2i(1280, 690)
 output_view.disable_3d = true
 output_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(output_view)
 output_rect = TextureRect.new()
 output_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 output_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 output_rect.texture = game.retro_filter.world_view.get_texture()
 output_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
 output_view.add_child(output_rect)
 output_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func output_image() -> Image:
 await RenderingServer.frame_post_draw
 return output_view.get_texture().get_image()

func set_review_time(seconds: float) -> void:
 if synchronized_vhs: synchronized_vhs.set_shader_parameter("review_time", seconds)

func set_retro(enabled: bool) -> void:
 retro_enabled = enabled
 if not is_instance_valid(game): return
 game.retro_filter.set_effects(game.retro_filter.settings.default_effects if enabled else [])
 if is_instance_valid(retro_button): retro_button.set_pressed_no_signal(enabled)
 apply_mode(scene_mode)

func apply_mode(mode: int) -> void:
 super.apply_mode(mode)
 if is_instance_valid(label): label.text += " | " + ("Saved N64 + VHS + CRT" if retro_enabled else "Retro OFF")

func set_motion_frame(index: int) -> void:
 var t := clampf(float(index - HOLD_FRAMES) / float(MOVE_FRAMES - 1), 0.0, 1.0)
 var pose: Transform3D = gameplay_camera_state.transform
 # A closed, gentle pan and dolly. No camera rotation, zoom/FOV or exposure changes.
 pose.origin += Vector3(0.30 * sin(TAU * t), -0.40 * sin(PI * t), -0.70 * sin(PI * t))
 game.presentation.camera.transform = pose

func settings_snapshot() -> Dictionary:
 var result := {}
 for property in game.retro_filter.settings.get_property_list():
  if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
   result[property.name] = game.retro_filter.settings.get(property.name)
 return result

func state_snapshot() -> Dictionary:
 var camera: Camera3D = game.presentation.camera
 return {"camera": str(camera.transform), "fov": camera.fov, "projection": camera.projection, "size": camera.size,
  "lighting": [str(game.presentation._key_light.rotation_degrees), settings.key_energy, settings.ambient_energy, settings.ssao_intensity, settings.exposure],
  "strengths": strengths.duplicate(), "filter_settings": settings_snapshot(), "effects": game.retro_filter.selected_effects.duplicate(),
  "world_resolution": str(game.retro_filter.world_view.size), "output_resolution": str(output_view.size), "geometry_unchanged": geometry_fingerprint() == baseline_geometry}

func build_controls() -> void:
 super.build_controls()
 var column: VBoxContainer = label.get_parent()
 retro_button = CheckButton.new()
 retro_button.text = "Existing retro stack: N64 + VHS + CRT"
 retro_button.toggled.connect(set_retro)
 column.add_child(retro_button)
 movement_button = Button.new()
 movement_button.text = "Play / stop repeated camera movement"
 movement_button.pressed.connect(func() -> void:
  preview_movement = not preview_movement
  preview_time = 0.0
  set_scene_view("gameplay")
 )
 column.add_child(movement_button)

func _process(delta: float) -> bool:
 if not recording:
  live_shader_time += delta
  set_review_time(live_shader_time)
 if preview_movement and is_instance_valid(game):
  preview_time = fmod(preview_time + delta, float(TOTAL_FRAMES) / FPS)
  set_motion_frame(int(preview_time * FPS))
 return false
