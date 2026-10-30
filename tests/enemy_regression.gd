extends "res://tests/pinball_editor_regression.gd"
const Enemies = preload("res://scripts/enemies/enemy_runtime.gd")
const Buddies = preload("res://scripts/prototype/buddies.gd")
const FIXTURE := "res://data/acts/buzz_bomber_test.tres"
var game: Node

func capture(label: String) -> void:
 if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/buzz-" + label + ".png")

func drag_to(point: Vector2, shift := false) -> void:
 var event := InputEventMouseMotion.new()
 event.position = editor.canvas.local_pixels_to_screen(point)
 event.alt_pressed = true
 event.shift_pressed = shift
 editor.canvas._gui_input(event)

func shoot(at: Vector2, velocity: Vector2, id: String) -> void:
 game.ball.teleport_to(at, velocity, false)
 for frame in 60:
  await physics_frame
  await process_frame
  if not game.authored_runtime.mechanics.enemies.by_id[id].alive: return

func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
 root.size = Vector2i(1440, 1000)
 editor = EditorScene.instantiate()
 root.add_child(editor)
 await process_frame
 editor.choose_gameplay("buzz_bomber")
 pointer(Vector2(200, 300), true, MOUSE_BUTTON_LEFT, true)
 drag_to(Vector2(335.25, 480))
 pointer(Vector2(335.25, 480), false)
 check(editor.document.gameplay_objects.size() == 1, "Shift-drag creates one enemy through the real editor")
 var item: Dictionary = editor.document.gameplay_objects[0]
 var id: String = item.object_id
 var original_endpoint: float = item.properties.patrol_right
 check(item.position.distance_to(Vector2(200, 300)) < 0.001 and item.properties.patrol_left == 0.0 and absf(original_endpoint - 135.25) < 0.001, "Patrol line stays horizontal with unsnapped local endpoints")
 editor.canvas.set_gameplay_brush({})
 editor.canvas.select_gameplay(0)
 pointer(Vector2(335.25, 300), true)
 drag_to(Vector2(390.5, 260))
 pointer(Vector2(390.5, 260), false)
 check(editor.document.gameplay_objects[0].properties.patrol_right == 190.5, "Selected endpoint handle resizes the line without Shift")
 editor.undo()
 check(editor.document.gameplay_objects[0].properties.patrol_right == original_endpoint, "One patrol drag is one Undo step, restoring exact sampled coordinates")
 editor.redo()
 check(editor.document.gameplay_objects[0].properties.patrol_right == 190.5, "Redo restores patrol geometry")
 editor.choose_gameplay("buzz_bomber")
 pointer(Vector2(200, 300), true, MOUSE_BUTTON_LEFT, true)
 drag_to(Vector2(450, 300), true)
 pointer(Vector2(450, 300), false)
 check(editor.document.gameplay_objects.size() == 1 and editor.document.gameplay_objects[0].properties.patrol_right == 250.0, "Shift edits an existing Buzz while its placement brush is active, without stamping another")
 editor.undo()
 editor.canvas.select_gameplay(0)
 pointer(Vector2(200, 300), true)
 drag_to(Vector2(100, 300), true)
 pointer(Vector2(100, 300), false)
 check(editor.document.gameplay_objects[0].position.distance_to(Vector2(200, 300)) < 0.001 and editor.document.gameplay_objects[0].properties.patrol_left == -100.0, "Pressing Shift after mouse-down extends the left patrol without moving the anchor")
 editor.undo()
 editor.canvas.select_gameplay(0)
 pointer(Vector2(300, 300), true, MOUSE_BUTTON_LEFT, true)
 drag_to(Vector2(500, 300), true)
 pointer(Vector2(500, 300), false)
 check(editor.document.gameplay_objects[0].properties.patrol_right == 300.0, "Shift-drag anywhere on the selected patrol line extends its endpoint")
 editor.undo()
 editor.canvas.select_gameplay(0)
 await capture("editor")
 editor.duplicate_selected()
 check(editor.document.gameplay_objects.size() == 2 and editor.document.gameplay_objects[1].object_id != id and editor.document.gameplay_objects[1].properties.patrol_right == 190.5, "Duplication preserves patrol but assigns a fresh object ID")
 var path := "res://test-results/buzz-authoring.tres"
 check(editor.save_to(path), "Enemy and exact patrol data save through Act Editor")
 var fingerprint: String = editor.document.fingerprint()
 check(editor.load_from(path) and editor.document.fingerprint() == fingerprint, "Enemy Save/Load preserves identity, properties and geometry")
 editor.set_enemy_patrol(0, Vector2.ZERO)
 check(editor.document.gameplay_objects[0].properties.patrol_right == 0, "Zero-length patrol authors a stationary enemy")
 editor.canvas.select_gameplay(0)
 var zoom_before: float = editor.canvas._cell_pixels
 pointer(Vector2(200, 300), true, MOUSE_BUTTON_WHEEL_UP, true)
 var wheel_props: Dictionary = editor.document.gameplay_objects[0].properties
 check(wheel_props.patrol_left == -10 and wheel_props.patrol_right == 10 and wheel_props.scale == 1 and editor.canvas._cell_pixels == zoom_before, "Shift-wheel widens a selected patrol without changing model scale or zoom")
 editor.undo()
 check(editor.document.gameplay_objects[0].properties.patrol_left == 0 and editor.document.gameplay_objects[0].properties.patrol_right == 0, "One wheel notch is one Undo step")
 editor.redo()
 check(editor.document.gameplay_objects[0].properties.patrol_right == 10, "Redo restores the wheel patrol edit")
 for i in 2: pointer(Vector2(200, 300), true, MOUSE_BUTTON_WHEEL_DOWN, true)
 check(editor.document.gameplay_objects[0].properties.patrol_left == 0 and editor.document.gameplay_objects[0].properties.patrol_right == 0, "Wheel shortening stops at a stationary zero-length patrol")
 editor.choose_gameplay("buzz_bomber")
 var object_count: int = editor.document.gameplay_objects.size()
 pointer(Vector2(400, 300), true, MOUSE_BUTTON_WHEEL_UP, true)
 check(editor.canvas.gameplay_brush.properties.patrol_left == -70 and editor.canvas.gameplay_brush.properties.patrol_right == 70 and editor.document.gameplay_objects.size() == object_count, "Shift-wheel also adjusts the placement brush without placing an enemy")
 editor.free()

 game = load("res://scenes/playground.tscn").instantiate()
 game.authored_act_path = FIXTURE
 root.add_child(game)
 for i in 5: await process_frame
 game.set_physics_process(false)
 game.ring_field.set_physics_process(false)
 game.scorecraft.set_physics_process(false)
 var runtime: Node = game.authored_runtime.mechanics
 var enemies: RefCounted = runtime.enemies
 check(enemies.items.size() == 4 and game.enemy_targets().is_empty(), "Authored fixture compiles four sensors and cannot target them at serve")
 check(game.presentation.find_children("BuzzBomber_*", "Node3D", true, false).size() == 4, "Each enemy has its own collisionless presentation")
 var model: Node = game.presentation.find_children("BuzzBomber_*", "Node3D", true, false)[0]
 check(model.find_children("*", "CollisionObject3D", true, false).is_empty(), "Enemy meshes have no 3D collision authority")
 var build := Buddies.new()
 build.choose("dark_chao")
 build.choose("rc_ufo")
 game.scorecraft.award_bonuses = build.modifiers()
 build.virtual_rings_awarded.connect(func(amount, _buddy): game.award_virtual_rings(amount))
 runtime.enemy_destroyed.connect(func(type, object_id, _points, source): build.enemy_destroyed(type, object_id, source))
 game.ball.freeze = true
 game.ball.serve_pending = false
 game.ball._teleport_pending = false
 var top: Dictionary = enemies.by_id.easy_top
 var hit := Enemies.swept_contact(top, Vector2(180, 100), Vector2(180, 800), game.ball.radius)
 check(not hit.is_empty() and hit.normal.y < -0.9, "High-speed sweep crosses the complete enemy without tunneling")
 check(Enemies.contact_velocity(Vector2(37, 600), Vector2(180, 100), Vector2(180, 800), top.position, hit) == Vector2(37, -510), "Descending top response preserves X and rebounds upward")
 hit = Enemies.swept_contact(top, Vector2(180, 700), Vector2(180, 100), game.ball.radius)
 check(Enemies.contact_velocity(Vector2(37, -600), Vector2(180, 700), Vector2(180, 100), top.position, hit) == Vector2(37, -480), "Bottom response keeps upward motion with modest damping")
 hit = Enemies.swept_contact(top, Vector2(0, 400), Vector2(600, 400), game.ball.radius)
 check(Enemies.contact_velocity(Vector2(6000, 0), Vector2(0, 400), Vector2(600, 400), top.position, hit) == Vector2(6000, 0), "Side response preserves trajectory")
 hit = Enemies.swept_contact(top, Vector2(0, 395), Vector2(600, 405), game.ball.radius)
 check(Enemies.contact_velocity(Vector2(6000, 100), Vector2(0, 395), Vector2(600, 405), top.position, hit).y == 100, "A grazing side hit ending above/below the center cannot become a false top bounce")
 var patrol: Dictionary = enemies.by_id.patrol_target
 var anchor: Vector2 = patrol.position
 enemies.tick(maxf(0.0, float(patrol.pause_remaining) - 0.05))
 check(patrol.position == anchor, "Buzz Bomber begins with a brief hover")
 enemies.tick(0.25)
 check(patrol.position.x > anchor.x, "Patrol departs after the initial hover")
 enemies.tick(3)
 check(patrol.position.x == anchor.x + 90 and patrol.direction == -1 and patrol.pause_remaining > 0, "Patrol pauses and reverses at its authored endpoint")
 runtime.scoring_active = false
 var before_position: Vector2 = patrol.position
 runtime.tick(2)
 check(not enemies.destroy("patrol_target") and patrol.alive and patrol.position == before_position and game.score == 0, "Inactive Act cannot destroy, score or advance enemy state")
 runtime.scoring_active = true
 await capture("playing")
 game.ball.freeze = false
 await shoot(Vector2(180, 330), Vector2(40, 700), "easy_top")
 check(not top.alive and game.ball.linear_velocity.y < -400 and absf(game.ball.linear_velocity.x - 40) < 1, "Real authoritative Ball top contact destroys and bounces")
 check(game.score == 125 and game.rings_collected == 1 and game.special_meter == 0 and game.scorecraft.chain == 0, "Generic enemy event pays 100 + 25 Dark Chao and one virtual Ring, without Special or combo")
 check(not enemies.destroy("easy_top") and game.score == 125, "Destruction is atomic and cannot award twice")
 game.reset_ball(false)
 for i in 3: await physics_frame
 check(not top.alive and game.score == 125, "Checkpoint reset retains defeated enemies and legitimate score")
 await shoot(Vector2(300, 780), Vector2(0, -650), "bottom_target")
 check(not enemies.by_id.bottom_target.alive and game.ball.linear_velocity.y < -450, "Real rising underside hit remains upward")
 # Remove terrain from this extreme-speed isolation shot so the nearby wall
 # cannot legitimately reverse it on the same frame as the sensor contact.
 game.ball.collision_mask = 0
 await shoot(Vector2(100, 550), Vector2(12000, 0), "side_target")
 check(not enemies.by_id.side_target.alive and game.ball.linear_velocity.x > 11990, "Real 12000 px/s side shot cannot tunnel or ricochet")
 check(game.score == 375 and game.rings_collected == 3 and not build.cadence.has("rc_ufo"), "Enemy virtual Rings never enter the RC UFO physical counter")
 game.ball.freeze = true
 game.ball.serve_pending = false
 game.ball._teleport_pending = false
 game.specials.select_character("shadow")
 game.specials._release_area("chaos_blast", patrol.position)
 check(not patrol.alive and game.score >= 500, "Chaos Blast uses the same enemy destruction path")
 var fresh := ActData.load_document(FIXTURE)
 var compiled := preload("res://scripts/authored_act/act_runtime_compiler.gd").compile(fresh.document, game.tuning, game.controls, game.ball)
 check(compiled.mechanics.enemies.items.all(func(enemy): return enemy.alive), "A fresh Act instance restores all enemy targets")
 compiled.root.free()
 game.free()
 # A fresh instance exercises real Sonic acquisition/contact and Knuckles' area
 # adapter without resurrecting or mutating the defeated fixture targets.
 game = load("res://scenes/playground.tscn").instantiate()
 game.authored_act_path = FIXTURE
 root.add_child(game)
 for i in 5: await process_frame
 game.set_physics_process(false)
 game.ring_field.set_physics_process(false)
 game.scorecraft.set_physics_process(false)
 game.ball.teleport_to(Vector2(180, 330), Vector2.ZERO, false)
 for i in 3: await physics_frame
 game.special_meter = 100
 var target: Node2D = game.specials.find_target()
 check(target != null and target.get_meta("enemy_id", "") == "easy_top", "Sonic acquires the nearest unobstructed active enemy sensor")
 check(game.specials.activate(), "Sonic launches Homing Attack at an enemy through existing targeting")
 for i in 60:
  await physics_frame
  await process_frame
  if not game.authored_runtime.mechanics.enemies.by_id.easy_top.alive: break
 check(not game.authored_runtime.mechanics.enemies.by_id.easy_top.alive and game.score == 100 and game.specials.homing_remaining == 0, "Real Homing contact destroys once for fixed 100 and clears its target")
 game.ball.freeze = true
 game.ball.serve_pending = false
 game.ball._teleport_pending = false
 game.specials.select_character("knuckles")
 var ability_enemies: RefCounted = game.authored_runtime.mechanics.enemies
 var alive_before: int = ability_enemies.items.filter(func(enemy): return enemy.alive).size()
 var enemy_points_before: int = game.act_score_breakdown.get("enemy", 0)
 game.specials._release_area("shockwave", Vector2(300, 780))
 var destroyed: int = alive_before - ability_enemies.items.filter(func(enemy): return enemy.alive).size()
 check(not ability_enemies.by_id.bottom_target.alive and game.act_score_breakdown.get("enemy", 0) - enemy_points_before == destroyed * 100, "Knuckles Shockwave uses generic destruction without its bumper multiplier")
 game.free()
 await process_frame
 print("RESULT | Enemy integration | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
