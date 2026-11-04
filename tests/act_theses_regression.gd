extends "res://tests/authored_gimmick_regression.gd"
## Small content smoke pass. This does not judge fun or prove human reachability.
const THESES := {
 "Orbit Garden": ["drop_target_bank", "one_way_gate"],
 "Rail Exchange": ["elevated_rail", "diverter", "switch_target"],
 "Spinner Falls": ["spinner", "one_way_gate", "switch_target"],
 "Split Decision": ["diverter", "dash_panel", "switch_target"],
 "Lockbox": ["drop_target_bank", "switch_target", "one_way_gate"],
}
func run() -> void:
 root.size = Vector2i(1280, 900)
 for title: String in THESES:
  if "--capture" in OS.get_cmdline_user_args() and title != "Rail Exchange": continue
  var path := "res://data/acts/Experiments/" + title + ".tres"
  var loaded := ActData.load_document(path)
  check(loaded.document != null, title + ": valid authored resource", str(loaded.get("error", "")))
  if loaded.document == null: continue
  var doc: Resource = loaded.document
  var saved: bool = doc.save_document("user://act-thesis-roundtrip.tres") == OK
  var again := ActData.load_document("user://act-thesis-roundtrip.tres")
  check(saved and again.document != null and again.document.fingerprint() == doc.fingerprint(), title + ": exact save/reload")
  game = ObservedGame.new()
  game.authored_act_path = path
  root.add_child(game)
  await frames(12)
  check(game.playfield.source == "authored", title + ": shared-engine startup", game.last_source_error)
  if game.playfield.source != "authored": game.free(); continue
  game.tuning.use_profile(PhysicsTuning.BALANCED)
  game.controls.virtual_enabled = true
  manager = game.ball.mechanics
  var counts := {}
  for object: Dictionary in game.authored_runtime.objects: counts[object.type] = int(counts.get(object.type, 0)) + 1
  var featured := true
  for type: String in THESES[title]: featured = featured and counts.get(type, 0) > 0
  var rings := 0
  for trail: Dictionary in doc.ring_trails: rings += Rings.positions(trail).size()
  for object: Dictionary in doc.gameplay_objects:
   if object.type == "elevated_rail": rings += preload("res://scripts/authored_act/rail_rings.gd").samples(object, Objects.properties(object)).size()
  check(featured and counts.get("buzz_bomber", 0) >= 1 and counts.get("slingshot", 0) == 2 and rings > 0, title + ": featured objects and baseline instantiate (%d Rings)" % rings)
  var clear := true
  for terrain: Dictionary in game.authored_runtime.terrain:
   for point: Vector2 in [doc.spawn_position, doc.goal_center()]:
    clear = clear and not Compiler._near_outline(point, terrain.points, terrain.closed, game.ball.radius)
  check(clear and doc.goal_position is Vector2, title + ": spawn and Goal clear solid terrain")
  for side: int in [0, 1]:
   game.controls.virtual_left = false
   game.controls.virtual_right = false
   await frames(12)
   var paddle: Node2D = game.authored_runtime.flippers[side]
   var rest := paddle.rotation
   var contact: Vector2 = paddle.position + Vector2.from_angle(rest) * 22.0 + Vector2.UP * 10.0
   await move_in_run(contact, Vector2(0, 60))
   game.controls.virtual_left = side == 0
   game.controls.virtual_right = side == 1
   await frames(12)
   check(absf(paddle.rotation - rest) > 0.3 and game.ball.linear_velocity.y < -50.0, title + ": main %s paddle physically strikes" % ("left" if side == 0 else "right"))
  game.controls.virtual_left = false
  game.controls.virtual_right = false
  if title == "Rail Exchange": await check_rail()
  for bank: Dictionary in manager.banks:
   for id: String in bank.members: manager._activate_switch(manager.by_id[id])
  manager._advance_diverters(Vector2(10, 10), Vector2.ZERO)
  var objectives := true
  for bank: Dictionary in manager.banks:
   objectives = objectives and bool(bank.complete)
   for id: String in bank.gates: objectives = objectives and bool(manager.by_id[id].open)
  for item: Dictionary in manager.items:
   if item.type == "drop_target_bank":
    for target: Dictionary in item.targets: manager.drop_target(item, target)
    objectives = objectives and bool(item.complete)
  check(objectives, title + ": authored Bank actions / target completion work")
  if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
   game._toggle_overview()
   await frames(12)
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://test-results/rail-exchange-runtime.png")
  game.free()
  await process_frame
 print("ACT THESES | ", checks, " checks | ", failures, " failures")
 quit(1 if failures else 0)

func check_rail() -> void:
 var events: Array = []
 manager.traversal_event.connect(func(kind, id, phase):
  if kind == &"elevated_rail": events.append([id, phase]))
 await move_in_run(Vector2(180, 365), Vector2(0, 70))
 await frames(600)
 var entered := false
 var completed := false
 for event: Array in events:
  entered = entered or event[1] == &"entered"
  completed = completed or event[1] == &"completed"
 check(entered and completed, "Rail Exchange: authored Spring feeds and completes crossover", str(events))
 var diverter: Dictionary = manager.by_id.rail_exchange_7
 for state: String in ["a", "b"]:
  manager.reset_for_retry()
  manager.request_diverter(diverter, "set_" + state)
  manager._advance_diverters(Vector2(10, 10), Vector2.ZERO)
  await move_in_run(Vector2(630, 350), Vector2(0, 170))
  await frames(30)
  var correct: bool = game.ball.linear_velocity.x > 30 if state == "a" else game.ball.linear_velocity.x < -30
  check(correct, "Rail Exchange: Diverter %s gives a distinct physical return" % state, str(game.ball.linear_velocity))
