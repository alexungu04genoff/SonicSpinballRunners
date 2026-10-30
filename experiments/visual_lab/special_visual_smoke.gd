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

func listener_count(signal_name: String) -> int:
 var count := 0
 for connection: Dictionary in game.specials.get_signal_connection_list(signal_name):
  if connection.callable.get_object() == actor:
   count += 1
 return count

func run() -> void:
 game = load("res://experiments/visual_lab/visual_lab.tscn").instantiate()

 root.add_child(game)
 await frames(5)
 actor = game.character
 check(actor.character_id == "sonic" and actor.specials == game.specials and actor.state == actor.State.SPIN and actor.spin_material.albedo_color.b > actor.spin_material.albedo_color.r and game.presentation.find_children("*", "CollisionObject3D", true, false).is_empty(), "Sonic starts blue and curled; the adapter observes shared specials and has no 3D collisions")
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
 game.playfield._add_bumper(target, 30.0)
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
 check(activated and actor.state == actor.State.HOMING and actor.homing_direction.is_equal_approx(heading) and actor.target_marker.visible and snapshot() == before, "Homing observes the target direction and displays its marker without changing gameplay")
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
 check(actor.state == actor.State.SPIN and actor.pose == "roll" and actor.spin_root.visible, "Homing impact finishes by returning to spin")
 game.specials.select_character("tails")
 actor._process(0.0)
 check(actor.character_id == "tails" and actor.spin_material.albedo_color.r > actor.spin_material.albedo_color.b and actor.spin_root.visible, "Character selection presents the orange Tails ball")
 game.ball.teleport_to(Vector2(3000, 2000), Vector2(0, 600))
 await frames(3)
 game.specials.charge(100.0)
 activated = game.specials.activate()
 before = snapshot()
 advance_presenter(0.25)
 check(activated and actor.state == actor.State.FLIGHT and actor.pose == "fly" and snapshot() == before and actor.flight_wind.visible and TablePresentation.unmap_point(actor.marker.position).distance_to(game.ball.position) < 0.001, "Flight is table-aligned and anchored; stepping presentation cannot change flight time, physics, score, rings or tuning")
 var clock_before: float = actor._pose_time
 var spin_before: Transform3D = actor.spin_root.transform
 before = snapshot()
 paused = true
 advance_presenter(0.25)
 check(snapshot() == before and actor._pose_time == clock_before and actor.spin_root.transform.is_equal_approx(spin_before), "Pause freezes flight presentation and the authoritative special state")
 paused = false
 actor.set_process(true)
 await frames(220)
 check(game.specials.flight_remaining == 0.0 and actor.state == actor.State.SPIN and actor.spin_root.visible, "Authoritative flight expiration returns to orange spin with no lingering flight pose")
 game.specials.charge(100.0)
 game.specials.activate()
 await frames(20)
 game.reset_ball()
 await frames(25)
 check(game.specials.flight_remaining == 0.0 and actor.state == actor.State.SPIN and actor.event_time == 0.0, "Reset clears special reactions and restores the serve spin presentation")
 # A controlled out-of-bounds fixture exercises the actual drain callback.
 game.ball.teleport_to(Vector2(3000, 2000), Vector2(0, 600))
 await frames(3)
 game.specials.charge(100.0)
 game.specials.activate()
 game.set_physics_process(true)
 await frames(20)
 check(game.respawn_time > 0.0 and game.specials.flight_remaining == 0.0 and actor.state == actor.State.SPIN, "The real drain path cancels flight and finishes its visual return to spin")
 game.set_physics_process(false)
 game.reset_ball()
 await frames(3)
 target.free()
 var previous_actor: WeakRef = weakref(actor)
 paused = true
 var regenerated: bool = game.request_replay({"character": "sonic"})
 await frames(12)
 actor = game.character
 var listeners_ok := true
 for signal_name: String in ["character_changed", "homing_started", "homing_ended", "special_hit", "flight_started", "flight_ended"]:
  listeners_ok = listeners_ok and listener_count(signal_name) == 1
 check(regenerated and previous_actor.get_ref() == actor and actor.character_id == "sonic" and actor.state == actor.State.SPIN and listeners_ok, "Regeneration retains the character presenter with reset visual state and exactly one listener per special event")
 # Ball form is a presentation policy, independent of the current state or assets.
 for id: String in CharacterSpecials.CHARACTERS:
  game.specials.select_character(id)
  var stable_ball: bool = actor.find_children("*", "Skeleton3D", true, false).is_empty()
  var gameplay_before := snapshot()
  for visual_state: int in actor.State.values():
   for study: bool in [false, true]:
    actor.state = visual_state
    actor.close_view = study
    actor._update_pose_transform(0.2)
    stable_ball = stable_ball and actor.spin_root.visible and actor.state == visual_state
    stable_ball = stable_ball and actor.spin_root.scale.is_equal_approx(Vector3.ONE * (1.0 if study or game.presentation.authored_mode else 1.12))
  check(stable_ball and snapshot() == gameplay_before, "%s retains full ball form in every presentation state and study, without loading a model or altering gameplay" % id.capitalize())
 actor.close_view = false
 paused = false
 game.free()
 await frames(3)
 print("SPECIAL_VISUAL_SMOKE | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
