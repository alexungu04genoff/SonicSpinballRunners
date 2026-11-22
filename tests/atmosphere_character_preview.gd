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

func run() -> void:
 preload("res://scripts/diagnostics/shadow_review.gd").position_review_window(root)
 var lab := Lab.new()
 root.add_child(lab)
 paused = true
 var panel := lab.lighting_controls
 var require_art := "--require-runners-set" in OS.get_cmdline_user_args()
 lab.view_button.pressed.emit()
 check(lab.preview != null and lab.preview.orbit.current, "The footer opens the character screen")
 for id: String in ["knuckles", "shadow", "sonic", "tails"]:
  check(choose(lab.character_picker, id), "Character choice " + id)
  await process_frame
  await process_frame
  var preview := lab.preview
  check(preview.active_character == id and lab.character.character_id == id, "Table and inspector share " + id)
  check(lab.debug_panel.act_controls.character_selector.selected == CharacterSpecials.CHARACTER_IDS.find(id), "Replay Act reflects " + id)
  check(preview.picker.item_count > 0 and preview.picker.get_item_text(0) == "Spin ball", "Every character has a usable roll")
  if lab.character_pose.runners_roll or (require_art and id in ["sonic", "tails"]):
   check(preview.curl and preview.curl.is_visible_in_tree(), id + " shows the Runners curl")
  else: check(preview.shell.visible and is_zero_approx(preview.shell.transparency), id + " shows the painted ball")
  if id == "shadow" and (require_art or preview.player):
   check(not preview.rig.visible and choose(preview.picker, Assets.BOOST.shadow) and preview.player.is_playing(), "Shadow switches from the ball to his animated Boost")
 var flight := choose(lab.preview.picker, Assets.FLIGHT)
 if require_art: check(flight and lab.preview.picker.item_count == 17, "Tails exposes the full local clip set")
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
