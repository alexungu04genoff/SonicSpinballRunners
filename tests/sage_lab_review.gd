extends SceneTree
## Checks the visible inspector using the same pointer and key events as the player.
const Scene = preload("res://experiments/visual_lab/sage/lab.tscn")
const Lab = preload("res://experiments/visual_lab/sage/lab.gd")
var failures := 0

func _initialize() -> void:
 run.call_deferred()

func check(condition: bool, message: String) -> void:
 if not condition:
  failures += 1
  push_error(message)

func mouse_button(point: Vector2, index: MouseButton, pressed: bool) -> void:
 var event := InputEventMouseButton.new()
 event.position = point
 event.global_position = point
 event.button_index = index
 event.pressed = pressed
 root.push_input(event, true)

func click(point: Vector2) -> void:
 mouse_button(point, MOUSE_BUTTON_LEFT, true)
 mouse_button(point, MOUSE_BUTTON_LEFT, false)

func key(code: Key) -> void:
 for pressed in [true, false]:
  var event := InputEventKey.new()
  event.keycode = code
  event.pressed = pressed
  root.push_input(event, true)

func capture(name: String) -> void:
 if "--capture-sage-lab" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
 await process_frame
 await RenderingServer.frame_post_draw
 var path := "res://test-results/sage-flight-review"
 DirAccess.make_dir_recursive_absolute(path)
 check(root.get_texture().get_image().save_png(path.path_join(name + ".png")) == OK, "Could not save full-window screenshot")

func record_crt(lab: Lab) -> void:
 if "--capture-sage-crt" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
 var folder := "res://test-results/sage-flight-review/crt-frames"
 DirAccess.make_dir_recursive_absolute(folder)
 key(KEY_TAB)
 lab.zoom = 0.65
 lab._aim_camera()
 lab.set_process(false)
 lab._set_playing(true)
 key(KEY_2)
 for frame in 90:
  if frame == 12: key(KEY_1)
  if frame == 55: key(KEY_3)
  lab._process(1.0 / 30.0)
  await process_frame
  await RenderingServer.frame_post_draw
  var image := root.get_texture().get_image()
  check(image.save_jpg(folder.path_join("%03d.jpg" % frame), 0.94) == OK, "Could not capture CRT frame")
  if frame == 40:
   check(image.save_png(folder.get_base_dir().path_join("sage-cyber-ball-crt.png")) == OK, "Could not save CRT screenshot")
   print("SAGE_CRT_CAPTURE | ", image.get_size(), " | ", lab.game.retro_filter.display_name(), " | opacity=", lab.actor.shell.get_shader_parameter("opacity"), " | morph=", lab.actor.transform_seconds)
 key(KEY_TAB)
 lab.set_process(true)

func check_sage_poses(actor: Lab.Actor) -> void:
 var skeleton := actor.skeleton
 var hand := skeleton.find_bone("Hand_L")
 var foot := skeleton.find_bone("Foot_L")
 var poses: Array[PackedVector3Array] = []
 for clip in ["Victory Reach", "Victory Guard", "Victory Kick"]:
  actor.play(clip)
  actor.sample(0.06)
  var wrist := skeleton.get_bone_global_pose(hand).origin
  var boot := skeleton.get_bone_global_pose(foot).origin
  actor.sample(0.34)
  check(wrist.distance_to(skeleton.get_bone_global_pose(hand).origin) < 0.001 and boot.distance_to(skeleton.get_bone_global_pose(foot).origin) < 0.001, clip + " holds its silhouette through the shared turn")
  for prior in poses:
   check(wrist.distance_to(prior[0]) + boot.distance_to(prior[1]) > 0.08, clip + " has a distinct wrist and boot silhouette")
  poses.append(PackedVector3Array([wrist, boot]))
 actor.play("Flight")
 actor.sample(0.3)
 var wrist := skeleton.get_bone_global_pose(hand).origin
 var boot := skeleton.get_bone_global_pose(foot).origin
 actor.sample(0.9)
 check(wrist.distance_to(skeleton.get_bone_global_pose(hand).origin) > 0.03 and boot.distance_to(skeleton.get_bone_global_pose(foot).origin) > 0.03, "Flight articulates both the reaching arm and trailing leg")

func run() -> void:
 var fallback := preload("res://experiments/visual_lab/sage/gameplay_actor.gd").new()
 root.add_child(fallback)
 fallback.prepare_gameplay("res://test-results/missing-sage-rig.glb")
 check(not fallback.animated and fallback.ball_root.visible and fallback.sphere.mesh != null and is_equal_approx(fallback.assembly, 1.0), "Sage's procedural ball works without any character assets")
 fallback.free()
 var missing: Lab = Scene.instantiate()
 missing.model_path = "res://test-results/missing-sage-rig.glb"
 root.add_child(missing)
 check(missing.get_node("%Status").text.contains(missing.model_path.get_file()) and not missing.game, "Missing local model must show its path")
 missing.free()
 var lab: Lab = Scene.instantiate()
 if not FileAccess.file_exists(lab.model_path):
  lab.free()
  print("SAGE_LAB_REVIEW | missing-rig screen checked; local model unavailable")
  quit(failures)
  return
 root.add_child(lab)
 var deadline := Time.get_ticks_msec() + 90000
 while not lab.inspecting and Time.get_ticks_msec() < deadline: await process_frame
 if not lab.inspecting:
  push_error("Inspector failed to start: " + lab.get_node("%Status").text)
  quit(1)
  return
 await process_frame
 check(not lab.game and lab.get_node("%Studio").is_visible_in_tree() and lab.get_node("%Sidebar").is_visible_in_tree(), "Open directly into the full-resolution studio")
 check(lab.clips.item_count == 9 and lab.actor.action == "Hover", "Open on Hover with nine choices")
 check_sage_poses(lab.actor)
 for i in lab.clips.item_count:
  click(lab.clips.global_position + lab.clips.get_item_rect(i).get_center())
  check(lab.actor.action == Lab.STATES[i], "Pointer could not select " + Lab.STATES[i])
 key(KEY_1)
 lab._replay_morph()
 lab._process(0.225)
 check(lab.actor.morph and is_equal_approx(lab.actor.assembly, 0.5), "Ball must be halfway assembled at 0.225 seconds")
 key(KEY_2)
 check(is_equal_approx(lab.actor.assembly, 0.5), "Reversing a partial transformation must preserve its visible coverage")
 lab._process(0.225)
 check(not lab.actor.ball_root.visible and lab.actor.rig.visible, "Reverse transition must finish cleanly")
 key(KEY_1)
 lab.get_node("%CoreOpacity").value = 35
 lab.get_node("%MorphTime").value = 0.8
 check(is_equal_approx(lab.actor.shell.get_shader_parameter("opacity"), 0.35) and is_equal_approx(lab.actor.transform_seconds, 0.8), "Cyber ball tuning must reach its materials and clock")
 lab.get_node("%CoreOpacity").value = Lab.Actor.CORE_OPACITY * 100.0
 lab.get_node("%MorphTime").value = Lab.Actor.MORPH_SECONDS
 lab._process(0.5)
 key(KEY_3)
 click(lab.get_node("%Steering/Right").get_global_rect().get_center())
 check(lab.actor.heading == 1 and lab.actor.action == "Flight", "Flight steering and animation shortcut")
 click(lab.get_node("%PlayPause").get_global_rect().get_center())
 var held := lab.seconds
 await process_frame
 check(not lab.playing and is_equal_approx(held, lab.seconds), "Pause must hold the frame")
 lab.timeline.value = lab.timeline.max_value
 check(not lab.playing and is_equal_approx(lab.playhead, lab.timeline.max_value) and lab.actor.player.current_animation_position > lab.timeline.max_value - 0.002, "Scrub must hold the last pose")
 click(lab.get_node("%Restart").get_global_rect().get_center())
 check(is_zero_approx(lab.playhead) and not lab.playing, "Restart while paused must hold the first frame")
 key(KEY_SPACE)
 lab.speed.select(Lab.RATES.find(0.5))
 lab._process(0.2)
 check(lab.playing and is_equal_approx(lab.seconds, 0.1), "Playback rate must drive the animation clock")
 var stage_point := root.get_visible_rect().size * Vector2(0.75, 0.5)
 mouse_button(stage_point, MOUSE_BUTTON_WHEEL_UP, true)
 mouse_button(stage_point, MOUSE_BUTTON_WHEEL_UP, false)
 check(lab.zoom > 1.0, "Stage wheel must zoom")
 var move := InputEventMouseMotion.new()
 move.position = stage_point + Vector2(30, 15)
 move.relative = Vector2(30, 15)
 move.button_mask = MOUSE_BUTTON_MASK_LEFT
 mouse_button(stage_point, MOUSE_BUTTON_LEFT, true)
 root.push_input(move, true)
 mouse_button(move.position, MOUSE_BUTTON_LEFT, false)
 check(not is_zero_approx(lab.orbit_yaw), "Dragging the table must orbit")
 click(lab.get_node("%ResetView").get_global_rect().get_center())
 check(is_equal_approx(lab.zoom, 1.0) and is_zero_approx(lab.orbit_yaw), "Reset must restore the opening view")
 lab.speed.select(Lab.RATES.find(1.0))
 lab.timeline.value = lab.timeline.max_value * 0.43
 var held_frame := lab.playhead
 root.gui_release_focus()
 await capture("sage-lab")
 var table_index := lab.cameras.get_item_index(Lab.DEFAULT_CAMERA)
 lab.cameras.item_selected.emit(table_index)
 deadline = Time.get_ticks_msec() + 90000
 while not lab.table_camera and Time.get_ticks_msec() < deadline: await process_frame
 if not lab.table_camera:
  push_error("Clover Scoop failed to load")
  quit(1)
  return
 await process_frame
 var pose = lab.game.character_pose
 var specials = lab.game.specials
 var sage = pose.sage
 check(lab.game.character_id == "sage" and specials.character_id == "sage" and specials.definition.display_name == "Sage" and lab.game.tuning.base == CharacterSpecials.CHARACTERS.sage.profile, "Sage owns her selectable identity and physics profile")
 check(sage.animated and not sage.is_visible_in_tree() and not pose.runners_roll, "The dedicated lab displays one Sage rig")
 specials.select_character("cream")
 check(specials.character_id == "cream" and pose.sage == null and not sage.visible and specials.definition.profile != CharacterSpecials.CHARACTERS.sage.profile, "Selecting Cream removes Sage and selects Cream's profile")
 if pose.runners_roll: check(pose.runners_roll.name == "RunnersCreamRoll", "Cream uses her original Runners curl")
 specials.select_character("sage")
 check(pose.sage == sage and pose.runners_roll == null and specials.action == CharacterSpecials.CHARACTERS.cream.type_action and lab.game.run_summary().character == "sage", "Selecting Sage restores her own art and records Sage in the run summary")
 check(paused and not lab.game.hud.visible and not lab.game.character.rolling_mesh.is_visible_in_tree() and not lab.game.presentation.ball_visual.is_visible_in_tree(), "The host character and its ball must stay hidden on the table")
 check(lab.game.retro_filter.selected_effects.is_empty() and lab.actor.rig.is_visible_in_tree(), "Table should show Sage without scanlines")
 check(not lab.playing and is_equal_approx(lab.actor.player.current_animation_position, held_frame) and lab.actor.action == "Flight", "Table must preserve %s at %.4f s (got %.4f s; playing=%s)" % [lab.actor.action, held_frame, lab.actor.player.current_animation_position, lab.playing])
 await capture("sage-lab-table")
 click(lab.get_node("%GameFilters").get_global_rect().get_center())
 check(lab.game.retro_filter.selected_effects == lab.table_effects, "Game filters opt back into the original stack")
 check(lab.game.retro_filter.is_enabled(lab.game.retro_filter.Preset.CRT), "Capture must use the production CRT")
 await record_crt(lab)
 for preset: int in Lab.Run.PLAY_CAMERAS:
  lab.cameras.item_selected.emit(lab.cameras.get_item_index(preset))
  check(lab.game.presentation.camera_preset == preset, "Table camera mismatch")
 lab.cameras.item_selected.emit(lab.cameras.get_item_index(Lab.STUDIO))
 check(lab.actor.get_parent() == lab.get_node("%Studio") and not lab.game.camera_input_container.visible, "Return the rig to the studio")
 key(KEY_2)
 lab.timeline.value = lab.timeline.max_value * 0.35
 await capture("sage-lab-hover")
 print("SAGE_LAB_REVIEW | nine states, playhead, steering, camera and playback | failures=", failures)
 if failures: quit(1)
 else: lab._close()
