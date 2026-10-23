extends SceneTree
## Focused observation-only adapter checks and labelled, real-contact capture probes.
var game: Node
var actor: Node3D
var failures := 0
var checks := 0
var capture_enabled := false
var capture_label: Label
var sequence_index := 0
const CAPTURE_DIR := "res://experiments/visual_lab/captures/orientation"

func _initialize() -> void:
 call_deferred("run")

func frames(count: int) -> void:
 for tick in count:
  await physics_frame
  await process_frame

func check(condition: bool, description: String) -> void:
 checks += 1
 if condition:
  print("PASS | ", description)
 else:
  failures += 1
  push_error("FAIL | " + description)

func advance_presenter(seconds: float) -> void:
 # No SceneTree tick occurs here: only the visual observer receives elapsed time.
 for tick in ceili(seconds * 120.0):
  actor._process(1.0 / 120.0)

func rotation_basis() -> Basis:
 # Ignore the uncurl scale so the axes can also be measured during a blend.
 return Basis.from_euler(actor.upright.rotation) * Basis.from_euler(actor.model_alignment.rotation)

func axes_are_table_aligned() -> bool:
 var basis := rotation_basis()
 return basis.y.dot(Vector3.FORWARD) >= cos(deg_to_rad(actor.MAX_LEAN_DEGREES)) - 0.001 and basis.z.dot(Vector3.UP) > 0.999

func observer_snapshot() -> Dictionary:
 return {"position": game.ball.position, "velocity": game.ball.linear_velocity, "serve": game.ball.serve_pending, "score": game.score, "rings": game.rings_collected, "meter": game.special_meter, "try": game.ball_number, "bumper_hits": game.ball.bumper_hit_count, "pickups": game.ring_field.rings.duplicate(true)}

func fixture(velocity: Vector2) -> void:
 # Controlled observations, not a gameplay trajectory: no physics frames run
 # between assigning this input and the synchronous presenter-only assertions.
 actor.resume_gameplay()
 game.ball.linear_velocity = velocity
 actor.show_event("jump", 2.0)
 advance_presenter(0.25)

func make_capture_label() -> void:
 var overlay := CanvasLayer.new()
 overlay.layer = 30
 root.add_child(overlay)
 capture_label = Label.new()
 capture_label.position = Vector2(24, 140)
 capture_label.add_theme_font_size_override("font_size", 17)
 capture_label.add_theme_color_override("font_color", Color.WHITE)
 capture_label.add_theme_color_override("font_shadow_color", Color("071e26"))
 capture_label.add_theme_constant_override("shadow_offset_x", 2)
 capture_label.add_theme_constant_override("shadow_offset_y", 2)
 overlay.add_child(capture_label)

func capture(file_name: String, description: String) -> void:
 if not capture_enabled:
  return
 capture_label.text = "CONTROLLED CONTACT PROBE · %s\nVelocity: (%d, %d) px/s · %s" % [description, game.ball.linear_velocity.x, game.ball.linear_velocity.y, actor.pose.to_upper()]
 await RenderingServer.frame_post_draw
 var directory := ProjectSettings.globalize_path(CAPTURE_DIR)
 DirAccess.make_dir_recursive_absolute(directory)
 var ignore := FileAccess.open(directory.path_join(".gdignore"), FileAccess.WRITE)
 if ignore != null:
  ignore.close()
 var result := root.get_texture().get_image().save_png(directory.path_join(file_name + ".png"))
 if result != OK:
  failures += 1
  push_error("Capture failed: " + file_name + " / " + error_string(result))

func prepare_contact() -> void:
 game.controls.virtual_left = false
 game.controls.virtual_right = false
 game.reset_ball()
 await frames(24)

func flipper_probe(label: String, incoming_x: float, nearly_vertical: bool) -> void:
 await prepare_contact()
 var flipper: PlaygroundFlipper = game.flippers[0]
 var before := flipper.strikes
 var bumper_hits_before: int = game.ball.bumper_hit_count
 var incoming := Vector2(incoming_x, 100.0)
 var point := flipper.position + Vector2.RIGHT.rotated(flipper.rest_angle()) * flipper.length * 0.6 + Vector2(0, -32)
 # The initial fixture is the only trajectory edit. The live 2D paddle supplies
 # the launch impulse; gravity, rails, bumpers and steering remain unchanged.
 game.ball.teleport_to(point - incoming * (3.0 / 120.0), incoming)
 await frames(3)
 if capture_enabled:
  await capture("sequence_%03d" % sequence_index, label.replace("_", " ") + " / before contact")
  sequence_index += 1
 game.controls.virtual_left = flipper.side > 0.0
 game.controls.virtual_right = flipper.side < 0.0
 var contact_tick := -1
 var launch_velocity := Vector2.ZERO
 var aligned := true
 var jump_seen := false
 var returned_to_spin := false
 var captured_return := false
 var intervening_contact := false
 for tick in 160:
  await frames(1)
  if contact_tick < 0 and flipper.strikes > before:
   contact_tick = tick
  if contact_tick < 0:
   continue
  var elapsed := tick - contact_tick
  jump_seen = jump_seen or (actor.event_pose == "jump" and actor.event_time > 0.0)
  intervening_contact = intervening_contact or game.ball.bumper_hit_count > bumper_hits_before or flipper.strikes > before + 1
  returned_to_spin = returned_to_spin or (jump_seen and elapsed > 6 and actor.state == actor.State.SPIN and actor.uncurl_amount < 0.001)
  if capture_enabled and returned_to_spin and not captured_return:
   await capture(label + "_return_to_spin", label.replace("_", " ") + " / returned to spin")
   captured_return = true
  if elapsed == 3:
   launch_velocity = game.ball.linear_velocity
  if actor.event_pose == "jump" and actor.event_time > 0.0:
   aligned = aligned and axes_are_table_aligned()
  if elapsed == 16:
   await capture(label, label.replace("_", " ") + " / live flight")
  if capture_enabled and elapsed % 3 == 0 and elapsed <= 105:
   await capture("sequence_%03d" % sequence_index, label.replace("_", " "))
   sequence_index += 1
  if elapsed >= 110:
   break
 game.controls.virtual_left = false
 game.controls.virtual_right = false
 var slope := absf(launch_velocity.x) / maxf(absf(launch_velocity.y), 1.0)
 var requested_heading := slope < 0.35 if nearly_vertical else slope >= 0.35
 check(contact_tick >= 0 and jump_seen and launch_velocity.y < -100.0 and requested_heading and aligned and (returned_to_spin or intervening_contact), "Real %s keeps the character head toward table-up and face toward the camera" % label.replace("_", " "))
 print("ORIENTATION_CONTACT | ", JSON.stringify({"probe": label, "initial_velocity": [incoming.x, incoming.y], "launch_velocity": [launch_velocity.x, launch_velocity.y], "horizontal_vertical_ratio": slope, "contact_tick": contact_tick, "jump_seen": jump_seen, "table_aligned": aligned, "returned_to_spin": returned_to_spin, "intervening_contact": intervening_contact}))

func bumper_probe() -> void:
 await prepare_contact()
 var bumper: Dictionary = {}
 for descriptor: Dictionary in game.chunks.back().descriptors:
  if descriptor.kind == "circle":
   bumper = descriptor
   break
 if bumper.is_empty():
  check(false, "Descending bumper probe has a generated circular bumper")
  return
 var hits_before: int = game.ball.bumper_hit_count
 game.ball.teleport_to(bumper.position - Vector2(0, bumper.radius + PlaygroundBall.RADIUS + 35), Vector2(0, 700))
 var contact_tick := -1
 var descending_seen := false
 var trick_seen := false
 var aligned := true
 var returned_to_spin := false
 var captured_return := false
 var intervening_contact := false
 for tick in 160:
  await frames(1)
  if game.ball.bumper_hit_count == hits_before:
   descending_seen = descending_seen or game.ball.linear_velocity.y > 100.0
  elif contact_tick < 0:
   contact_tick = tick
  if contact_tick < 0:
   if capture_enabled and tick % 3 == 0:
    await capture("sequence_%03d" % sequence_index, "descending bumper approach / before contact")
    sequence_index += 1
   continue
  var elapsed := tick - contact_tick
  trick_seen = trick_seen or (actor.event_pose == "trick" and actor.event_time > 0.0)
  intervening_contact = intervening_contact or game.ball.bumper_hit_count > hits_before + 1
  returned_to_spin = returned_to_spin or (trick_seen and elapsed > 6 and actor.state == actor.State.SPIN and actor.uncurl_amount < 0.001)
  if capture_enabled and returned_to_spin and not captured_return:
   await capture("descending_bumper_return_to_spin", "descending bumper contact / returned to spin")
   captured_return = true
  if actor.event_pose == "trick" and actor.event_time > 0.0:
   aligned = aligned and axes_are_table_aligned()
  if elapsed == 16:
   await capture("descending_bumper_trick", "descending bumper approach / live rebound trick")
  if capture_enabled and elapsed % 3 == 0 and elapsed <= 105:
   await capture("sequence_%03d" % sequence_index, "descending bumper approach / live rebound trick")
   sequence_index += 1
  if elapsed >= 110:
   break
 check(descending_seen and contact_tick >= 0 and trick_seen and aligned and (returned_to_spin or intervening_contact), "A genuine descending bumper contact triggers a table-aligned trick without a 180-degree turn")
 print("ORIENTATION_CONTACT | ", JSON.stringify({"probe": "descending_bumper", "initial_velocity": [0, 700], "contact_tick": contact_tick, "descending_seen": descending_seen, "trick_seen": trick_seen, "table_aligned": aligned, "returned_to_spin": returned_to_spin, "intervening_contact": intervening_contact}))

func run() -> void:
 capture_enabled = OS.get_cmdline_user_args().has("--screenshots")
 game = load("res://experiments/visual_lab/visual_lab.tscn").instantiate()
 game.generation_seed = 18
 root.add_child(game)
 await frames(5)
 actor = game.character
 game.controls.virtual_enabled = true
 if capture_enabled:
  make_capture_label()
 check(actor.state == actor.State.SPIN and actor.pose == "roll" and actor.spin_root.visible and not actor.upright.visible and actor.spin_root.get_parent() != actor.model_alignment and game.presentation.find_children("*", "CollisionObject3D", true, false).is_empty(), "Serve starts curled; rolling and upright roots are separate and collisionless")
 actor.set_process(false)
 fixture(Vector2(0, -600))
 var upright_axes := rotation_basis()
 check(upright_axes.y.dot(Vector3.FORWARD) > 0.999 and upright_axes.z.dot(Vector3.UP) > 0.999, "Zero horizontal velocity maps model head toward table-up and face out of the table")
 fixture(Vector2(600, -600))
 var positive_lean: float = actor.lean_angle
 var right_head := rotation_basis().y
 fixture(Vector2(-600, -600))
 var negative_lean: float = actor.lean_angle
 check(positive_lean < 0.0 and negative_lean > 0.0 and right_head.x > 0.0 and rotation_basis().y.x < 0.0 and absf(positive_lean) <= deg_to_rad(actor.MAX_LEAN_DEGREES) + 0.001 and absf(negative_lean) <= deg_to_rad(actor.MAX_LEAN_DEGREES) + 0.001 and axes_are_table_aligned(), "Opposite horizontal velocities produce opposite, bounded lean instead of full heading rotation")
 fixture(Vector2(0, 600))
 var descending_axes := rotation_basis()
 fixture(Vector2(5, 600))
 var deadzone_stable := absf(actor.lean_angle) < 0.001
 game.ball.linear_velocity = Vector2(600, 600)
 actor._process(1.0 / 120.0)
 var first_lean: float = actor.lean_angle
 advance_presenter(0.25)
 var settled_lean: float = actor.lean_angle
 game.ball.linear_velocity = Vector2(-600, 600)
 actor._process(1.0 / 120.0)
 check(descending_axes.y.dot(Vector3.FORWARD) > 0.999 and deadzone_stable and absf(first_lean) < absf(settled_lean) and absf(actor.lean_angle - settled_lean) < deg_to_rad(10.0) and axes_are_table_aligned(), "Descending motion stays head-up; deadzone removes jitter and direction changes blend smoothly")
 actor.resume_gameplay()
 actor.show_event("jump", 0.46)
 advance_presenter(0.12)
 var event_before: float = actor.event_time
 var clock_before: float = actor._pose_time
 actor.show_event("jump", 0.46)
 check(is_equal_approx(actor.event_time, event_before) and is_equal_approx(actor._pose_time, clock_before), "Repeated active jump events do not restart the event timer or animation")
 advance_presenter(0.60)
 check(actor.state == actor.State.SPIN and actor.pose == "roll" and actor.uncurl_amount < 0.001 and actor.spin_root.visible and not actor.upright.visible, "Completed event blends fully back to the default spin-ball")
 fixture(Vector2(600, -600))
 var before := observer_snapshot()
 actor.spin_root.rotate_z(1.2)
 advance_presenter(0.12)
 check(observer_snapshot() == before and absf(actor.upright.rotation.x) < 0.001 and absf(actor.upright.rotation.z) < 0.001 and TablePresentation.unmap_point(actor.marker.position).distance_to(game.ball.position) < 0.001, "Presenter leaves physics, pickups and score unchanged; spin cannot contaminate the contact anchor or upright axes")
 paused = true
 before = observer_snapshot()
 var paused_lean: float = actor.lean_angle
 event_before = actor.event_time
 clock_before = actor._pose_time
 advance_presenter(0.25)
 check(observer_snapshot() == before and actor.lean_angle == paused_lean and actor.event_time == event_before and actor._pose_time == clock_before, "Pause freezes gameplay lean, events, animation and the authoritative body")
 paused = false
 game._set_close_view(true)
 actor.select_preview("jump")
 actor._process(0.0)
 var showcase_ok: bool = paused and actor.state == actor.State.SHOWCASE and actor.model_alignment.rotation.is_zero_approx() and absf(actor.upright.rotation.x) < 0.001 and absf(actor.upright.rotation.z) < 0.001
 if actor.model_available:
  showcase_ok = showcase_ok and actor.model.position.is_zero_approx()
 game._set_close_view(false)
 actor._process(0.0)
 check(showcase_ok and not paused and actor.state == actor.State.SPIN and axes_are_table_aligned(), "Paused showcase restores normal standing model axes and returns cleanly to gameplay alignment")
 if OS.get_cmdline_user_args().has("--no-model") or not FileAccess.file_exists(ProjectSettings.globalize_path(actor.MODEL_PATH)):
  actor.show_event("trick", 0.52)
  advance_presenter(0.2)
  check(not actor.model_available and actor.spin_root.visible and not actor.upright.visible, "Unavailable model retains a visible spin-ball throughout uncurl events")
 else:
  check(actor.model_available and actor.model.get_parent() == actor.model_alignment and is_equal_approx(actor.model.position.y, -0.5), "Imported skinned model uses its own alignment root and centered gameplay origin")
 actor.set_process(true)
 game.ball.linear_velocity = Vector2.ZERO
 await flipper_probe("near_vertical_launch", -220.0, true)
 await flipper_probe("diagonal_launch", -650.0, false)
 await bumper_probe()
 print("ORIENTATION_SMOKE | %d checks | %d failures | %d sequence frames" % [checks, failures, sequence_index])
 game.free()
 quit(0 if failures == 0 else 1)
