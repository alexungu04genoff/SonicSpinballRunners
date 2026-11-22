extends SceneTree
## Exercise the character screen in the real Atmosphere Lab, including rebuilds.
const Lab = preload("res://experiments/lighting_lab/lighting_lab.gd")
const Assets = preload("res://experiments/visual_lab/runners_sonic_assets.gd")
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)

func choose(picker: OptionButton, value: String) -> bool:
 for index in picker.item_count:
  if picker.get_item_metadata(index) == value:
   picker.select(index)
   picker.item_selected.emit(index)
   return true
 return false

func review_centers(lab: Node, id: String) -> void:
 var preview = lab.preview
 var camera_index: int = preview.cameras.get_item_index(TablePresentation.CameraPreset.TOP_DOWN)
 preview.cameras.select(camera_index)
 preview.cameras.item_selected.emit(camera_index)
 preview.sliders.zoom.value = 3.0
 preview.playing = false
 var folder := "res://test-results/roster-top-down"
 DirAccess.make_dir_recursive_absolute(folder)
 var reference: Vector3 = lab.character.marker.global_position
 var heading: Vector2 = lab.character.roll_heading
 var skinned: MeshInstance3D = preview.rig.find_children("*", "MeshInstance3D", true, false)[0]
 for index in preview.picker.item_count:
  preview.picker.select(index)
  preview.picker.item_selected.emit(index)
  var clip: String = preview.active_clip
  var rolling: bool = clip == preview.roll_clip
  var moving: bool = preview.rig.visible
  var is_boost: bool = clip == Assets.BOOST[id]
  var phases := 16 if is_boost else 8
  var worst := 0.0
  for phase in phases:
   var t := float(phase) / phases
   if is_boost: lab.character.roll_heading = Vector2.UP.rotated(TAU * t)
   if clip == Assets.FLIGHT_CLIPS.get(id): preview.flight_heading.x = -1.0 if phase % 2 == 0 else 1.0
   if rolling: preview.roll_angle = t * TAU
   if preview.held.visible: preview.trick_time = t * preview.Celebration.MILESTONE_TRICK_SECONDS
   if moving: preview.player.seek(t * preview.player.current_animation_length, true)
   preview._orient_model()
   await RenderingServer.frame_post_draw
   var model: MeshInstance3D = skinned if moving else (preview.curl if rolling else preview.held)
   if preview.held.visible:
    check(model.global_position.is_equal_approx(lab.character.spin_root.global_position), id + " turns around the roll center at every trick angle")
    # Measure the authored silhouette head-on. Shoes and quills turn with the pose.
    if t != 0.5: continue
   var mesh: Mesh = model.bake_mesh_from_current_skeleton_pose() if moving else model.mesh
   var footprint := Rect2()
   var first := true
   var transform := model.global_transform
   for surface in mesh.get_surface_count():
    var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
    for vertex in vertices:
     var point: Vector3 = transform * vertex - reference
     var flat := Vector2(point.x, point.z)
     footprint = Rect2(flat, Vector2.ZERO) if first else footprint.expand(flat)
     first = false
   worst = maxf(worst, footprint.get_center().length() / preview.pose.radius)
   if is_boost and phase == 4:
    var view: SubViewport = preview.orbit.get_viewport()
    var center: Vector2 = preview.orbit.unproject_position(reference)
    var pixels: float = center.distance_to(preview.orbit.unproject_position(reference + Vector3.RIGHT * preview.pose.radius))
    var half := ceili(pixels * 3.2)
    var rect := Rect2i(Vector2i(center) - Vector2i(half, half), Vector2i(half, half) * 2)
    view.get_texture().get_image().get_region(rect).save_png(folder.path_join(id + ".png"))
  print("TOP_DOWN_CENTER | ", id, " | ", clip, " | max offset in radii=", snappedf(worst, 0.001))
  check(worst < 0.12, id + " " + clip + " stays within 0.12 radii of the contact circle")
  lab.character.roll_heading = heading
 preview.playing = true

func run() -> void:
 preload("res://scripts/diagnostics/shadow_review.gd").position_review_window(root)
 var lab := Lab.new()
 root.add_child(lab)
 paused = true
 var panel := lab.lighting_controls
 var require_art := "--require-runners-set" in OS.get_cmdline_user_args()
 lab.view_button.pressed.emit()
 check(lab.preview != null and lab.preview.orbit.current, "The footer opens the character screen")
 for id: String in CharacterSpecials.CHARACTER_IDS:
  check(choose(lab.character_picker, id), "Character choice " + id)
  await process_frame
  await process_frame
  var preview := lab.preview
  check(preview.active_character == id and lab.character.character_id == id, "Table and inspector share " + id)
  check(lab.debug_panel.act_controls.character_selector.selected == CharacterSpecials.CHARACTER_IDS.find(id), "Replay Act reflects " + id)
  if id == "sage":
   check(preview.sage and preview.sage.ball_root.is_visible_in_tree() and not preview.shell.visible, "Sage previews her own procedural cyber ball")
   if preview.sage.animated:
    check(preview.picker.item_count == 8 and choose(preview.picker, "Flight") and preview.sage.action == "Flight", "Sage exposes her own rig and seven clips in the character screen")
   continue
  check(preview.picker.item_count > 0 and preview.picker.get_item_text(0) == "Spin ball", "Every character has a usable roll")
  if lab.character_pose.runners_roll:
   check(preview.curl and preview.curl.is_visible_in_tree(), id + " shows the Runners curl")
  elif require_art:
   check(false, id + " is missing its required local Runners model")
  else:
   check(preview.shell.visible and is_zero_approx(preview.shell.transparency), id + " shows the painted ball")
  if id == "shadow" and (require_art or preview.player):
   check(not preview.rig.visible and choose(preview.picker, Assets.BOOST.shadow) and preview.player.is_playing(), "Shadow switches from the ball to his animated Boost")
  if preview.player:
   var prefix: String = Assets.PREFIX[id]
   check(not choose(preview.picker, prefix + "_run_loop") and not choose(preview.picker, prefix + "_dash_loop"), id + " exposes only Boost for running")
   check(choose(preview.picker, Assets.BOOST[id]) and preview.player.current_animation == Assets.BOOST[id] and is_equal_approx(preview.player.get_playing_speed() / preview.player.current_animation_length, 2.7), id + " plays its own Boost at 2.7 strides per second")
   if "--review-centers" in OS.get_cmdline_user_args(): await review_centers(lab, id)
 check(choose(lab.character_picker, "tails"), "Return to Tails for Flight review")
 await process_frame
 await process_frame
 var flight := choose(lab.preview.picker, Assets.FLIGHT_CLIPS.tails)
 if require_art: check(flight and lab.preview.picker.item_count == 16, "Tails exposes the gameplay clips")
 var selected := lab.preview.active_clip
 if flight:
  var time := lab.preview.player.current_animation_position
  await process_frame
  await process_frame
  check(lab.preview.player.current_animation_position != time, "Flight plays on the paused table")
 lab.preview.pause_button.pressed.emit()
 var clip_time := lab.preview.player.current_animation_position if flight else 0.0
 lab.preview.sliders.zoom.value = 3.0
 var body := lab.ball
 check(lab.set_theme("ice_cap"), "Switch to Ice Cap while inspecting")
 await process_frame
 check(lab.preview.active_clip == selected and not lab.preview.playing and lab.preview.orbit.current and lab.ball == body, "Theme rebuild preserves the character, animation, camera and live ball")
 if flight: check(is_equal_approx(lab.preview.player.current_animation_position, clip_time), "Frozen pose survives the theme switch")
 await lab.reload_authored_act()
 check(lab.preview.active_clip == selected and lab.preview.orbit.current and is_equal_approx(lab.preview.sliders.zoom.value, 3.0), "Reloading the Act restores the close-up")
 panel.tabs.current_tab = panel.tabs.get_node("Light").get_index()
 panel.set_value("sun/light_energy", 0.35)
 check(lab.preview.orbit.current and is_equal_approx(lab.presentation._key_light.light_energy, 0.35), "Lighting edits reach the inspected character")
 panel.tabs.current_tab = lab.character_tab.get_index()
 if DisplayServer.get_name() != "headless":
  for frame in 4: await process_frame
  await RenderingServer.frame_post_draw
  DirAccess.make_dir_recursive_absolute("res://test-results/atmosphere-character")
  root.get_texture().get_image().save_png("res://test-results/atmosphere-character/ice-cap.png")
 lab.preview.resume_requested.emit()
 check(lab.preview == null and lab.presentation.camera.current and lab.character.rolling_mesh.visible and paused, "Back to table restores the camera and playing character")
 var request := lab.prototype_playtest_request()
 check(request.error.is_empty() and "--character=tails" in request.arguments, "Play Prototype carries the current character")
 if request.error.is_empty(): DirAccess.remove_absolute(request.path)
 var key := InputEventKey.new()
 key.keycode = KEY_F8
 key.pressed = true
 root.push_input(key, true)
 check(is_instance_valid(lab.preview) and lab.preview.active_clip == selected, "F8 reopens the last character and clip")
 root.push_input(key, true)
 check(lab.preview == null and lab.presentation.camera.current, "F8 returns to the table")
 lab.free()
 paused = false
 print("RESULT | Atmosphere character preview | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
