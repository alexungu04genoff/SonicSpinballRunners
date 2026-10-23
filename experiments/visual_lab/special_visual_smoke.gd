extends SceneTree
## Controlled adapter fixtures. These are not the input-only gameplay captures.
var game: Node
var actor: Node3D
var failures := 0
var checks := 0

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
 for tick in ceili(seconds * 120.0):
  actor._process(1.0 / 120.0)

func snapshot() -> Dictionary:
 return {"position": game.ball.position, "velocity": game.ball.linear_velocity, "score": game.score, "rings": game.rings_collected, "meter": game.special_meter, "homing": game.specials.homing_remaining, "flight": game.specials.flight_remaining, "target": game.specials.pending_target, "pickups": game.ring_field.rings.duplicate(true), "tuning": game.tuning.effective.duplicate(true)}

func axes() -> Basis:
 return Basis.from_euler(actor.upright.rotation) * Basis.from_euler(actor.model_alignment.rotation)

func skeleton() -> Skeleton3D:
 if not actor.model_available:
  return null
 var found: Array[Node] = actor.model.find_children("*", "Skeleton3D", true, false)
 return found[0] as Skeleton3D if found.size() == 1 else null

func listener_count(signal_name: String) -> int:
 var count := 0
 for connection: Dictionary in game.specials.get_signal_connection_list(signal_name):
  if connection.callable.get_object() == actor:
   count += 1
 return count

func run() -> void:
 game = load("res://experiments/visual_lab/visual_lab.tscn").instantiate()
 game.generation_seed = 18
 root.add_child(game)
 await frames(5)
 actor = game.character
 check(actor.character_id == "sonic" and actor.specials == game.specials and actor.state == actor.State.SPIN and actor.spin_material.albedo_color.b > actor.spin_material.albedo_color.r and game.presentation.find_children("*", "CollisionObject3D", true, false).is_empty(), "Sonic starts blue and curled; the adapter observes shared specials and has no 3D collisions")
 var sonic_model_expected := not OS.get_cmdline_user_args().has("--no-model") and FileAccess.file_exists("res://experiments/visual_lab/local/runtime/sonic.glb")
 check((actor.model_available and skeleton() != null and actor._clips.has("homing") and actor._clips.has("impact")) if sonic_model_expected else (not actor.model_available and actor.spin_root.visible), "Sonic loads the prepared skin and authored special clips, or keeps a visible asset-free fallback")
 # The isolated bumper and initial ball placement are deliberately controlled.
 # The authoritative 2D collision still supplies the special hit and score.
 game.set_physics_process(false)
 game.ring_field.set_physics_process(false)
 var target := StaticBody2D.new()
 target.position = Vector2(2200, 2000)
 target.set_meta("bumper", true)
 var shape := CircleShape2D.new()
 shape.radius = 30.0
 var collision := CollisionShape2D.new()
 collision.shape = shape
 target.add_child(collision)
 game.world.add_child(target)
 game.chunks[0].descriptors.append({"kind": "bumper", "body": target})
 var target_visual := Node3D.new()
 game.presentation.add_child(target_visual)
 game.presentation.bumper_visuals[target.get_instance_id()] = target_visual
 game.ball.teleport_to(Vector2(2000, 2000), Vector2.ZERO)
 await frames(3)
 game.specials.charge(100.0)
 var activated: bool = game.specials.activate()
 actor.set_process(false)
 var before := snapshot()
 advance_presenter(0.3)
 var heading: Vector2 = game.specials.homing_direction
 var heading_3d := Vector3(heading.x, 0, heading.y).normalized()
 check(activated and actor.state == actor.State.HOMING and axes().y.dot(heading_3d) > 0.98 and axes().z.dot(Vector3.UP) > 0.999 and snapshot() == before, "Homing faces the authoritative target direction in the board plane without changing gameplay")
 actor.set_process(true)
 var impact_seen := false
 var score_before: int = game.score
 for tick in 90:
  await frames(1)
  impact_seen = impact_seen or actor.state == actor.State.IMPACT
  if impact_seen:
   break
 check(impact_seen and game.score - score_before == 500 and game.specials.pending_target == null, "Actual 2D target contact awards the shared special hit and starts the impact reaction")
 actor.set_process(false)
 advance_presenter(1.0)
 check(actor.state == actor.State.SPIN and actor.pose == "roll" and actor.uncurl_amount < 0.001 and actor.spin_root.visible, "Homing impact finishes by blending fully back to spin")
 game.specials.select_character("tails")
 actor._process(0.0)
 var tails_model_expected := not OS.get_cmdline_user_args().has("--no-model") and FileAccess.file_exists("res://experiments/visual_lab/local/runtime/tails.glb")
 check(actor.character_id == "tails" and actor.spin_material.albedo_color.r > actor.spin_material.albedo_color.b and actor.state == actor.State.SPIN and ((actor.model_available and actor._clips.has("fly") and skeleton() != null) if tails_model_expected else (not actor.model_available and actor.spin_root.visible)), "Character selection swaps to orange Tails and its flight skin, with an independent fallback")
 var rig := skeleton()
 var tails_changed := not tails_model_expected
 var children_preserved := not tails_model_expected
 if rig != null:
  actor.select_preview("fly")
  actor.seek_pose(0.06)
  var first: Array[Quaternion] = []
  var children: Array[Quaternion] = []
  for side: String in ["L", "R"]:
   first.append(rig.get_bone_pose_rotation(rig.find_bone("Tail1_" + side)))
   for segment in range(2, 5):
    children.append(rig.get_bone_pose_rotation(rig.find_bone("Tail%d_%s" % [segment, side])))
  actor.seek_pose(0.19)
  tails_changed = true
  children_preserved = true
  var child_index := 0
  for side_index in 2:
   var side: String = ["L", "R"][side_index]
   tails_changed = tails_changed and first[side_index].angle_to(rig.get_bone_pose_rotation(rig.find_bone("Tail1_" + side))) > 0.5
   for segment in range(2, 5):
    children_preserved = children_preserved and children[child_index].angle_to(rig.get_bone_pose_rotation(rig.find_bone("Tail%d_%s" % [segment, side]))) < 0.001
    child_index += 1
 actor.resume_gameplay()
 check(tails_changed and children_preserved, "Both audited tail roots rotate in the flight clip while all six downstream tail joints retain their local pose" if tails_model_expected else "Asset-free Tails skips unavailable skeleton animation and retains its fallback")
 game.ball.teleport_to(Vector2(3000, 2000), Vector2(0, 600))
 await frames(3)
 game.specials.charge(100.0)
 activated = game.specials.activate()
 before = snapshot()
 advance_presenter(0.25)
 check(activated and actor.state == actor.State.FLIGHT and actor.pose == "fly" and snapshot() == before and axes().z.dot(Vector3.UP) > 0.999 and TablePresentation.unmap_point(actor.marker.position).distance_to(game.ball.position) < 0.001, "Flight is table-aligned and anchored; stepping presentation cannot change flight time, physics, score, rings or tuning")
 var clock_before: float = actor._pose_time
 var uncurl_before: float = actor.uncurl_amount
 before = snapshot()
 paused = true
 advance_presenter(0.25)
 check(snapshot() == before and actor._pose_time == clock_before and actor.uncurl_amount == uncurl_before, "Pause freezes flight presentation and the authoritative special state")
 paused = false
 actor.set_process(true)
 await frames(220)
 check(game.specials.flight_remaining == 0.0 and actor.state == actor.State.SPIN and actor.uncurl_amount < 0.001 and actor.spin_root.visible, "Authoritative flight expiration returns to orange spin with no lingering flight pose")
 game.specials.charge(100.0)
 game.specials.activate()
 await frames(20)
 game.reset_ball()
 await frames(25)
 check(game.specials.flight_remaining == 0.0 and actor.state == actor.State.SPIN and actor.event_time == 0.0 and actor.uncurl_amount < 0.001, "Reset clears special reactions and restores the serve spin presentation")
 # A controlled out-of-bounds fixture exercises the actual drain callback.
 game.ball.teleport_to(Vector2(3000, 2000), Vector2(0, 600))
 await frames(3)
 game.specials.charge(100.0)
 game.specials.activate()
 game.set_physics_process(true)
 await frames(20)
 check(game.respawn_time > 0.0 and game.specials.flight_remaining == 0.0 and actor.state == actor.State.SPIN and actor.uncurl_amount < 0.001, "The real drain path cancels flight and finishes its visual return to spin")
 game.set_physics_process(false)
 game.reset_ball()
 await frames(3)
 target.free()
 var previous_actor: WeakRef = weakref(actor)
 paused = true
 var regenerated: bool = game.request_generation(23, TableGenerator.Difficulty.NORMAL, 1, {"character": "sonic", "zone": false, "enabled": false})
 await frames(12)
 actor = game.character
 var listeners_ok := true
 for signal_name: String in ["character_changed", "homing_started", "homing_ended", "special_hit", "flight_started", "flight_ended"]:
  listeners_ok = listeners_ok and listener_count(signal_name) == 1
 check(regenerated and previous_actor.get_ref() == null and actor.character_id == "sonic" and actor.state == actor.State.SPIN and listeners_ok, "Regeneration frees the old character and binds exactly one listener per special event to the replacement")
 paused = false
 game.free()
 await frames(3)
 print("SPECIAL_VISUAL_SMOKE | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
