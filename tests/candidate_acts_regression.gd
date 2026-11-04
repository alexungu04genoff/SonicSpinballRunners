extends "res://tests/authored_gimmick_regression.gd"
## Focused content checks, not an automated verdict on shot difficulty or fun.
const CANDIDATES := ["Relay Garden", "Switchback Climb", "Side Door"]
const ALLOWED := ["left_flipper", "right_flipper", "round_bumper", "triangle_bumper", "switch_target", "one_way_gate", "spring", "spinner", "buzz_bomber"]

func run() -> void:
 root.size = Vector2i(1280, 900)
 for title: String in CANDIDATES:
  if "--capture" in OS.get_cmdline_user_args() and title != "Side Door": continue
  var path := "res://data/acts/Candidates/" + title + ".tres"
  var loaded := ActData.load_document(path)
  check(loaded.document != null, title + ": loads and validates", str(loaded.get("error", "")))
  if loaded.document == null: continue
  var doc: Resource = loaded.document
  var copy_path := "user://candidate-roundtrip.tres"
  var saved: bool = doc.save_document(copy_path) == OK
  var reloaded := ActData.load_document(copy_path)
  check(saved and reloaded.document != null and reloaded.document.fingerprint() == doc.fingerprint(), title + ": exact save/reload")
  var enemies_count := 0
  var supported := true
  var types := {}
  for item: Dictionary in doc.gameplay_objects:
   supported = supported and item.type in ALLOWED
   if item.type == "buzz_bomber": enemies_count += 1
   if item.type in ["spring", "spinner", "switch_target", "one_way_gate"]: types[item.type] = true
  check(supported and enemies_count == 2 and types.size() >= 2, title + ": two enemies and established mechanics only")
  game = ObservedGame.new()
  game.authored_act_path = path
  root.add_child(game)
  await frames(12)
  check(game.playfield.source == "authored", title + ": normal game startup", game.last_source_error)
  if game.playfield.source != "authored": game.free(); continue
  game.tuning.use_profile(PhysicsTuning.BALANCED)
  var runtime: Dictionary = game.authored_runtime
  var terrain_clear := true
  var paddle_clear := true
  var rings_count := 0
  for trail: Dictionary in doc.ring_trails:
   for point: Vector2 in Rings.positions(trail):
    rings_count += 1
    for terrain: Dictionary in runtime.terrain:
     if Compiler._near_outline(point, terrain.points, terrain.closed, game.ball.radius):
      terrain_clear = false
      print("Ring terrain clearance: ", title, " ", point)
    for object: Dictionary in doc.gameplay_objects:
     if object.type == "round_bumper" and point.distance_to(object.position) < 12.5 * float(Objects.properties(object).scale) + game.ball.radius: terrain_clear = false
  check(rings_count >= 35 and rings_count <= 45 and terrain_clear, title + ": %d rings with terrain/bumper clearance" % rings_count)
  for item: Dictionary in doc.gameplay_objects:
   if not str(item.type).ends_with("flipper"): continue
   for step in 9:
    var angle := deg_to_rad(float(item.rotation_degrees)) + (-1.0 if item.type == "left_flipper" else 1.0) * 0.8 * step / 8.0
    # Hinges deliberately mount at terrain boundaries; inspect the moving blade.
    for fraction: float in [0.35, 0.65, 1.0]:
     var point: Vector2 = item.position + Vector2.from_angle(angle) * 32.5 * fraction
     for terrain: Dictionary in runtime.terrain:
      if Compiler._near_outline(point, terrain.points, terrain.closed, 2.5): paddle_clear = false
  check(paddle_clear, title + ": full paddle sweep clears terrain beyond the hinge")
  game.controls.virtual_enabled = true
  game.launch_ball()
  await frames(120)
  check(game.ball.position.is_finite() and game.ball.linear_velocity.is_finite(), title + ": ordinary serve remains finite")
  manager = game.ball.mechanics
  for item: Dictionary in manager.items:
   if item.type != "spring": continue
   check(float(item.properties.launch_strength) >= 180 and float(item.properties.launch_strength) <= 300, title + ": restrained authored Spring speed")
   var count: int = item.launch_count
   await move_in_run(Vector2(item.position) + Objects.forward(item) * 30.0, -Objects.forward(item) * 70.0)
   var fastest := 0.0
   var highest_y: float = game.ball.position.y
   for step in 240:
    await physics_frame
    fastest = maxf(fastest, game.ball.linear_velocity.length())
    highest_y = minf(highest_y, game.ball.position.y)
   check(item.launch_count > count, title + ": physical Spring contact launches")
   print("SPRING OBSERVATION | ", title, " | speed=", item.properties.launch_strength, " | rise=", snappedf(float(item.position.y) - highest_y, 0.1), " px | peak free-flight speed=", snappedf(fastest, 0.1))
  for bank: Dictionary in manager.banks:
   for id: String in bank.members: manager._activate_switch(manager.by_id[id])
   var opened := bool(bank.complete)
   for id: String in bank.gates: opened = opened and bool(manager.by_id[id].open)
   check(opened, title + ": existing Bank completes and opens its linked gates")
  if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
   game._toggle_overview()
   await frames(12)
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://test-results/candidate-side-door.png")
  game.free()
  await process_frame
 print("CANDIDATE CHECKS | ", checks, " checks | ", failures, " failures")
 quit(1 if failures else 0)
