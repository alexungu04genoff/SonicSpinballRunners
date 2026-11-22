extends SceneTree
## Fullscreen, deterministic chapter capture with the normal Prototype and local Runners rig.
const Session = preload("res://scripts/prototype/session.gd")
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Rail = preload("res://scripts/authored_act/rail_path.gd")
const STAGES := {
 "Plunger Lane": ["tube", "weak_tube", "retry"],
 "Spin Alley": ["roll", "flipper"],
 "Spring Meadow": ["spring"],
 "Dash Causeway": ["panel"],
 "Rail Terrace": ["rail", "ramp"],
 "Loop Clearing": ["loop", "rollback"],
 "Special Arena": ["special", "special_replay"],
 "Trick Garden": ["combos", "poses"],
 "Animation Green": ["library"],
}
const SHOTS := {
 "tube": ["Launch tube / full charge", 85], "weak_tube": ["Weak launch / rollback and dock", 110],
 "retry": ["Checkpoint return", 60], "roll": ["Fast roll / speed trail", 46],
 "flipper": ["Flipper strike", 40], "spring": ["Spring / rise to apex", 76],
 "panel": ["Dash panel / boost to curl", 56], "rail": ["Elevated rail", 45],
 "ramp": ["Terrain ramp", 44], "loop": ["Loop / inversion and exit", 84],
 "rollback": ["Loop / reversal and exit", 92], "special": ["Special", 80], "special_replay": ["Special replay", 115],
 "combos": ["Bounce combo", 230], "poses": ["Victory tricks / extended turns", 150],
}
const DEST := "res://test-results/character-reels/"
var session: Node
var game: Node
var pose: Node
var tag: Label
var actor: String
var stage: String
var shot: String
var folder: String
var seen := {}
var frame := 0
var pose_camera: Node
var records := []
var special_score := 0

class ShotCamera extends Node:
 var director: SceneTree
 func _process(_delta: float) -> void:
  director.frame_action_camera()

func _initialize() -> void:
 run.call_deferred()

func run() -> void:
 var args := OS.get_cmdline_user_args()
 if args.size() < 2 or not STAGES.has(args[1]) or args[0] not in CharacterSpecials.CHARACTER_IDS:
  push_error("Pass a character ID and Act title after --")
  quit(2)
  return
 actor = args[0]
 stage = args[1]
 if root.current_screen == DisplayServer.get_primary_screen() or root.mode not in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]:
  push_error("Capture requires fullscreen on the secondary monitor")
  quit(2)
  return
 folder = DEST + actor + "/" + stage + "/"
 if "--verify-roster" in args: folder = DEST + "roster-check/"
 DirAccess.make_dir_recursive_absolute(folder)
 root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
 session = Session.new()
 session.settings_path = folder + "session.cfg"
 session.archive_directory = folder + "telemetry"
 session.sound_enabled = false
 root.add_child(session)
 session.configure_act_test("res://data/acts/Experiments/" + stage + ".tres")
 await session._start_configured_run(session.run_configuration, actor, true, 18)
 game = session.game
 while not game.started and game.last_source_error.is_empty(): await process_frame
 if not game.started:
  push_error(game.last_source_error)
  quit(2)
  return
 session.set_process(false)
 session.overlay_root.hide()
 game.set_physics_process(false)
 game.ball.can_sleep = false
 game.controls.virtual_enabled = true
 game.select_play_camera(TablePresentation.CameraPreset.DRAMATIC_PINBALL)
 game.presentation.set_camera_value("zoom", 2.3)
 game.retro_filter.set_effects(game.retro_filter.settings.default_effects)
 game.fps_label.hide()
 pose = game.combo_celebration.character_pose
 if not (pose.sage and pose.sage.animated) and (not pose.motion_player or not pose.runners_roll):
  push_error("Local Runners animation assets required")
  quit(2)
  return
 var layer := CanvasLayer.new()
 layer.layer = 125
 root.add_child(layer)
 tag = Label.new()
 layer.add_child(tag)
 tag.position = Vector2(32, 110)
 tag.add_theme_font_size_override("font_size", 25)
 var background := StyleBoxFlat.new()
 background.bg_color = Color("#101827eb")
 tag.add_theme_stylebox_override("normal", background)
 pose_camera = ShotCamera.new()
 pose_camera.director = self
 pose_camera.process_priority = 900
 root.add_child(pose_camera)
 game.ball.traversal_launched.connect(func(kind, _velocity): seen[str(kind)] = true)
 for tube in game.active.runtime.launch_tubes:
  tube.exited.connect(func(_position, _velocity): seen["exit"] = true)
 for paddle: PlaygroundFlipper in game.active.runtime.flippers:
  paddle.shot_fired.connect(func(_p, _v, _f): seen["strike"] = true)
 game.specials.special_hit.connect(func(_target, _factor): seen["contact"] = true)
 game.specials.homing_ended.connect(func(reason): seen["boost_end"] = reason)
 game.specials.area_completed.connect(func(_source, count, _rings): seen["area_targets"] = count)
 game.specials.flight_started.connect(func(): seen["flight"] = true)
 game.scorecraft.builder_hit_resolved.connect(func(hits, _points): seen["hits"] = hits)
 print("CAPTURE ", actor, " / ", stage, " / ", game.retro_filter.display_name())
 var complete := true
 if "--verify-roster" in args:
  complete = await verify_roster()
 else:
  for key: String in STAGES[stage]:
   if key == "library": complete = await capture_library()
   else: complete = await capture_gameplay(key)
   if not complete: break
 if complete and "--verify-roster" not in args:
  FileAccess.open(folder + "index.json", FileAccess.WRITE).store_string(JSON.stringify(records))
  print("STAGE_COMPLETE ", stage)
 pose_camera.free()
 shot = ""
 session.archive_attempted = true
 await session._close_run("capture")
 session.free()
 quit(0 if complete else 3)

func caption(detail: String) -> void:
 tag.text = "  " + actor.capitalize() + "   /   " + stage + "   /   " + detail + "  "

func set_ball(local: Vector2, velocity := Vector2.ZERO) -> void:
 var at := Vector2(game.active.plan.offset) + local
 game.ball.freeze = false
 game.ball.teleport_to(at, velocity)
 game.presentation.reset_camera(at)

func prepare(key: String) -> void:
 game.controls.virtual_launch = false
 game.controls.virtual_left = false
 game.controls.virtual_steering = 0.0
 game.controls.input_blocked = false
 game.auto_launch_time = -1.0
 game.specials.reset(false, "Review")
 game.scorecraft.reset("Review")
 game.combo_celebration.reset_combo()
 if is_instance_valid(game.ball.launch_tube): game.ball.launch_tube.detach()
 var pos: Vector2 = game.active.document.spawn_position
 var velocity := Vector2.ZERO
 var items: Dictionary = game.active.runtime.mechanics.by_id
 match key:
  "roll": velocity = Vector2(465, -190)
  "retry":
   pos = Vector2(235, 735)
   velocity = Vector2(50, 190)
  "spring":
   var spring: Dictionary = items.showcase_spring
   var forward := Objects.forward(spring)
   pos = Vector2(spring.position) - Vector2(game.active.plan.offset) + forward * 48.0
   velocity = -forward * 205.0
  "panel": velocity = Vector2.UP * 640.0
  "loop", "rollback":
   var loop: Dictionary = items.showcase_loop
   var forward := Objects.forward(loop)
   pos = Vector2(loop.position) - Vector2(game.active.plan.offset) - forward * 26.0
   velocity = forward * 490.0
  "rail", "ramp":
   var rail: Dictionary = items["showcase_" + key]
   var forward := Rail.tangent(rail.path, 0.0)
   pos = Vector2(rail.position) - Vector2(game.active.plan.offset) - forward * 26.0
   velocity = forward * 570.0
  "flipper":
   var paddle: PlaygroundFlipper = game.active.runtime.flippers[0]
   pos = paddle.global_position.lerp(paddle.tip(), 0.83) + paddle.strike_direction(0.83) * (game.ball.radius + paddle.radius + 12.0) - Vector2(game.active.plan.offset)
   velocity = Vector2.DOWN * 80.0
  "poses": pos = Vector2(450, 425)
  "special", "special_replay":
   if game.specials.action.kind == TypeAction.Kind.POWER: pos = Vector2(590, 505)
   if key == "special_replay" and game.specials.action.kind == TypeAction.Kind.SPEED: pos = Vector2(805, 530)
   velocity = Vector2(20, -15)
 set_ball(pos, velocity)
 for i in 3: await physics_frame
 if key in ["tube", "weak_tube"]:
  game.active.runtime.launch_tubes[0].dock(game.ball)
  game.presentation.reset_camera(game.ball.position)
 if key == "poses":
  game.ball.freeze = true
  if pose.sage: pose.sage.victory_index = -1
  else: pose.trick_index = -1
 if key.begins_with("special"):
  game.special_meter = game.specials.definition.meter_capacity
  special_score = game.score

func subject_center() -> Vector3:
 if is_instance_valid(game.transfer) and is_instance_valid(game.transfer.proxy): return game.transfer.proxy.global_position
 if pose.sage:
  if pose.sage.rig.visible and pose.sage.assembly < 0.5:
   return pose.sage.rig.to_global(Vector3.UP * pose.sage.HEIGHT * 0.5)
  return pose.sage.global_position
 if pose.visible: return pose.global_position
 if pose.motion != &"" and pose.motion_rig.visible: return pose.motion_rig.global_position
 return game.character.spin_root.global_position

func rolling() -> bool:
 if pose.sage: return pose.sage.action == pose.sage.BALL and pose.sage.assembly > 0.99
 return game.character.rolling_mesh.visible

func verify_roster() -> bool:
 if stage != "Special Arena": return false
 shot = "special"
 for id: String in CharacterSpecials.CHARACTER_IDS:
  actor = id
  game.specials.select_character(id)
  await prepare(shot)
  var active_seen := false
  var centered_frames := 0
  for i in 150:
   frame = i
   if i == 5 and not game.specials.activate(): return false
   if game.specials.action.kind == TypeAction.Kind.FLY: game.controls.virtual_steering = sin(i / 12.0)
   await process_frame
   await RenderingServer.frame_post_draw
   if not centered(game.presentation.camera, subject_center()):
    push_error("Off-center special: %s frame %d" % [id, i])
    return false
   centered_frames += 1
   if pose.motion != &"": active_seen = true
   if active_seen and pose.motion == &"" and rolling(): break
  if not active_seen or not rolling(): return false
  print("CENTERED_SPECIAL ", id, " frames=", centered_frames)
 return true

func centered(camera: Camera3D, subject: Vector3) -> bool:
 var midpoint := camera.get_viewport().get_visible_rect().get_center()
 return not camera.is_position_behind(subject) and camera.unproject_position(subject).distance_to(midpoint) < 1.0

func frame_action_camera() -> void:
 if shot == "" or shot == "library": return
 var table: TablePresentation = game.presentation
 var center := subject_center()
 if shot not in ["combos", "poses", "special", "special_replay"]:
  # Translate in the image plane. The real camera still owns pitch, zoom and
  # the Loop transition, while the recorded subject stays at screen center.
  var normal := table.camera.global_basis.z.normalized()
  table.camera.global_position += (center - table.camera.global_position).slide(normal)
  return
 var phase := frame / 30.0
 var yaw := deg_to_rad(32.0 * sin(phase * 0.9 - 0.8))
 var pitch := deg_to_rad(7.0 * cos(phase * 0.8))
 var basis := table._follow_basis.rotated(table._follow_basis.x, pitch).rotated(Vector3.UP, yaw)
 var distance: float = pose.radius * (14.0 + 1.5 * cos(phase * 1.15))
 if shot == "special": distance *= 1.55
 if shot == "special_replay":
  basis = basis.rotated(Vector3.UP, deg_to_rad(-38.0))
  distance *= 1.12
 table.camera.global_transform = Transform3D(basis, center + basis.z * distance)
 if pose.visible:
  if shot == "poses": pose.place_trick(clampf((frame % 50 - 2) / 39.0, 0.0, 1.0))
  elif game.combo_celebration.trick_remaining > 0.0:
   pose.place_trick(1.0 - game.combo_celebration.trick_remaining / game.combo_celebration.trick_duration)

func capture_gameplay(key: String) -> bool:
 shot = key
 seen = {}
 await prepare(key)
 var count: int = SHOTS[key][1]
 var title: String = SHOTS[key][0]
 if key.begins_with("special"):
  title = game.specials.action.action_name
  if game.specials.action.kind == TypeAction.Kind.FLY: count = ceili(game.specials.action.flight_duration * 30) + 65
 if key == "special_replay":
  Engine.time_scale = 0.55
  title += " / slow-motion reverse angle"
  if game.specials.action.kind != TypeAction.Kind.SPEED: count = ceili(count / Engine.time_scale)
 caption(title)
 var recovered_at := -1
 var path := folder + key + "/"
 DirAccess.make_dir_recursive_absolute(path)
 for i in count:
  frame = i
  if key in ["tube", "weak_tube"]:
   game.controls.virtual_launch = i >= 4 and i < (9 if key == "weak_tube" else 48)
  if key == "flipper" and i >= 1:
   var paddle: PlaygroundFlipper = game.active.runtime.flippers[0]
   var nearest := Geometry2D.get_closest_point_to_segment(game.ball.position, paddle.global_position, paddle.tip())
   if game.ball.position.distance_to(nearest) < game.ball.radius + paddle.radius + 6: game.controls.virtual_left = true
  if key.begins_with("special"):
   if i == 10:
    if not game.specials.activate(): break
    seen["activated"] = true
   if game.specials.action.kind == TypeAction.Kind.FLY: game.controls.virtual_steering = sin(i / 15.0)
  if key == "retry" and i == 7: game._start_transfer(true)
  if key == "combos" and i % 23 == 1:
   var index := floori(i / 23.0)
   var bumper := Vector2(280 + 125 * (index % 5) + (42 if index >= 5 else 0), 350 if index < 5 else 530)
   var approach := Vector2(0.4 if index % 2 == 0 else -0.4, 1).normalized()
   set_ball(bumper + approach * 62.0, -approach * 290.0)
  if key == "poses":
   if i % 50 == 2: pose.start_trick(1.30)
   if i % 50 == 42: pose.restore_ball()
   caption("Victory trick %d / extended turn" % (1 + floori(i / 50.0)))
  if key == "rollback" and game.ball.in_loop and not seen.has("reversed") and game.active.runtime.mechanics.progress > game.ball.loop_item.properties.scale * 245.0:
   game.active.runtime.mechanics.speed = -absf(game.active.runtime.mechanics.speed)
   seen["reversed"] = true
  await process_frame
  await RenderingServer.frame_post_draw
  if not centered(game.presentation.camera, subject_center()):
   push_error("Subject left frame center in %s at frame %d" % [key, i])
   return false
  if game.ball.in_loop: seen["loop"] = true
  if game.ball.on_ramp: seen["track"] = true
  if pose.motion != &"": seen[str(pose.motion)] = true
  if game.character.trail.visible: seen["trail"] = true
  if is_instance_valid(game.ball.launch_tube):
   var tube = game.ball.launch_tube
   if tube.phase == tube.Phase.RETURNING: seen["returning"] = true
   if tube.phase == tube.Phase.OUTBOUND: seen["outbound"] = true
   if tube.phase == tube.Phase.DOCKED and (seen.has("returning") or seen.has("transfer")): seen["redocked"] = true
  if is_instance_valid(game.transfer): seen["transfer"] = true
  if key == "spring" and seen.has("spring") and game.ball.linear_velocity.y > 2 and pose.motion == &"" and rolling():
   seen["falling_ball"] = true
   caption("Falling / back in ball form")
  if key.begins_with("special") and seen.has("activated") and rolling() and pose.motion == &"" and game.specials.homing_remaining <= 0 and game.specials.flight_remaining <= 0 and game.specials.smash_remaining <= 0:
   if recovered_at < 0: recovered_at = i
   seen["recovery"] = true
   caption(title + " / recovery")
  if not save_frame(path, i): return false
  if recovered_at >= 0 and i - recovered_at >= 19:
   count = i + 1
   break
 Engine.time_scale = 1.0
 var required: Array = {"tube":["exit"], "weak_tube":["returning","redocked"], "retry":["transfer","redocked"], "roll":["trail"], "flipper":["strike"], "spring":["spring","falling_ball"], "panel":["dash_panel"], "loop":["loop"], "rollback":["reversed"], "rail":["track"], "ramp":["track"], "special":["activated","recovery"]}.get(key, [])
 if key == "special_replay": required = ["activated", "recovery"]
 var valid := seen.has_all(required)
 if key == "combos": valid = seen.get("hits", 0) >= 10
 if key.begins_with("special") and game.specials.action.kind == TypeAction.Kind.SPEED: valid = valid and seen.has("target_boost") and game.score - special_score >= 500
 if key.begins_with("special") and game.specials.action.kind == TypeAction.Kind.POWER: valid = valid and seen.get("area_targets", 0) > 0
 print("SHOT ", key, " ", seen, " valid=", valid)
 if not valid:
  push_error("Missing action in " + key)
  return false
 add_record(key, title, count, path)
 return true

func save_frame(path: String, index: int) -> bool:
 return root.get_texture().get_image().save_jpg(path + ("%03d.jpg" % index), 0.90) == OK

func add_record(key: String, title: String, count: int, path: String) -> void:
 records.append({"key": key, "title": title, "frames": count, "folder": path, "stage": stage})

func capture_library() -> bool:
 shot = "library"
 await prepare(shot)
 session._open_spin_lab()
 var lab = session.spin_lab
 if not is_instance_valid(lab): return false
 lab.hide()
 lab.sliders.zoom.value = 1.85
 if lab.sage:
  for index in lab.picker.item_count:
   lab._select_clip(index)
   var clip: String = lab.active_clip
   var count := 45 if clip == lab.sage.BALL else maxi(30, ceili(lab.sage.player.get_animation(clip).length * 30))
   var path := folder + clip + "/"
   DirAccess.make_dir_recursive_absolute(path)
   caption("Original clip / " + clip)
   for i in count:
    lab.yaw = deg_to_rad(17.0 * sin(i / float(count) * PI - 0.4))
    lab._aim_camera()
    await process_frame
    await RenderingServer.frame_post_draw
    if not centered(lab.orbit, lab.pivot.global_position) or not save_frame(path, i): return false
   add_record(clip, "Original / " + clip, count, path)
  session._resume_spin_lab()
  return true
 var clips: PackedStringArray = lab.player.get_animation_list()
 for clip: String in clips:
  var name_parts := clip.split("_", false, 1)
  var title := str(name_parts[-1]).replace("_", " ").capitalize()
  var index := -1
  for j in lab.picker.item_count:
   if lab.picker.get_item_metadata(j) == clip:
    index = j
    title = lab.picker.get_item_text(j)
    break
  if index == -1:
   index = lab.picker.item_count
   lab.picker.add_item(title)
   lab.picker.set_item_metadata(index, clip)
  lab._select_clip(index)
  # Sample the original skeletal performance, including the moving jump tricks.
  lab.curl.hide()
  if lab.trailing_tails: lab.trailing_tails.hide()
  lab.held.hide()
  lab.rig.show()
  lab.rig.scale = Vector3.ONE / lab.source_radius
  lab.Assets.start_clip(lab.rig, lab.player, clip)
  lab.player.speed_scale = 1.0
  var count := maxi(30, ceili(lab.player.current_animation_length * 30.0) + 1)
  var path := folder + clip + "/"
  DirAccess.make_dir_recursive_absolute(path)
  caption("Original clip / " + title)
  for i in count:
   lab.yaw = deg_to_rad(17.0 * sin(i / float(count) * PI - 0.4))
   lab.pitch = deg_to_rad(-4.0)
   lab._aim_camera()
   await process_frame
   await RenderingServer.frame_post_draw
   if not centered(lab.orbit, lab.pivot.global_position): return false
   if not save_frame(path, i): return false
  add_record(clip, "Original / " + title, count, path)
 print("ORIGINAL_CLIPS ", clips.size())
 session._resume_spin_lab()
 return true
