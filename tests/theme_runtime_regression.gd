extends SceneTree
## Exercises the production theme selector against unchanged authored and generated
## playfields. No alternate gameplay scene or replacement physics is used.
const Game = preload("res://experiments/visual_lab/visual_lab.gd")
const EXAMPLES := ["decor_terraces", "decor_curve_relay"]
const THEMES := ["green_hill", "chemical_plant"]
const MANIFEST := "res://test-results/theme-variants.json"
var game: Node
var checks := 0
var failures := 0

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 checks += 1
 if ok: print("PASS | ", message)
 else:
  failures += 1
  push_error("FAIL | " + message)

func frames(count := 3) -> void:
 for i in count:
  await process_frame
  await physics_frame

func load_act(name: String) -> void:
 check(game.request_authored_act("res://data/acts/%s.tres" % name), "Main game accepts authored example: " + name)
 for i in 120:
  await frames(1)
  if not game.generation_pending: break
 check(not game.generation_pending and game.last_source_error.is_empty(), "Authored source finishes loading: " + name)
 await frames(3)

func instance_ids(values: Array) -> Array:
 var ids: Array = []
 for value: Object in values:
  ids.append(value.get_instance_id())
 return ids

func physics_nodes(node: Node, result: Array) -> void:
 if node is CollisionObject2D or node is CollisionShape2D or node is CollisionPolygon2D:
  result.append([node.get_instance_id(), node.get_class(), node.transform])
 for child: Node in node.get_children(): physics_nodes(child, result)

func snapshot() -> Dictionary:
 var presentation = game.presentation
 var camera: Camera3D = presentation.camera
 var physics: Array = []
 physics_nodes(game.world, physics)
 var ring_meshes: Array = []
 for ring: MeshInstance3D in presentation.ring_visuals:
  ring_meshes.append([ring.transform, ring.visible])
 return {
  "engine identities": instance_ids([game.ball, game.tuning, game.controls, game.ring_field, game.scorecraft, game.specials, game.character, presentation, camera, game.playfield]),
  "physics bodies and shapes": physics,
  "terrain and gameplay bodies": instance_ids(game.playfield.terrain_bodies) + instance_ids(game.playfield.bumpers) + instance_ids(game.flippers),
  "ball state": [game.ball.global_transform, game.ball.linear_velocity, game.ball.angular_velocity, game.ball.serve_pending, game.ball.release_pending],
  "scoring and rings": [game.score, game.rings_collected, game.special_meter, game.ball_number, game.ring_field.rings.duplicate(true), game.scorecraft.chain, game.scorecraft.multiplier, game.scorecraft.remaining, game.scorecraft.last_award.duplicate(true)],
  "character and tuning": [game.character_id, game.specials.character_id, game.specials.definition.get_instance_id(), game.tuning.base.get_instance_id(), game.tuning.effective.duplicate(true), game.tuning.overrides.duplicate(true), game.tuning.build_ids],
  "camera": [camera.global_transform, camera.projection, camera.fov, camera.size, camera.near, camera.far, presentation.camera_focus, presentation.camera_target, presentation.camera_settings.duplicate(true), presentation.camera_preset, presentation.camera_follow_enabled],
  "lifecycle": [game.level_source, game.layout.signature, game.authored_activation_count, game.authored_exit_count, game.respawn_time, game.auto_launch_time, game.ring_reset_time],
  "authored document": game.authored_document.fingerprint() if game.authored_document != null else "",
  "authored silhouettes": [presentation.authored_terrain_polygons.duplicate(true), presentation.authored_composite_polygons.duplicate(true), presentation.authored_open_paths.duplicate(true), presentation.authored_floor_outline.duplicate()],
  "pickup and contact feedback": [presentation.ring_pickups.duplicate(true), presentation.flash_times.duplicate(), presentation.ball_visual.transform, ring_meshes],
 }

func compare(before: Dictionary, label: String) -> void:
 var after := snapshot()
 for key: String in before:
  check(before[key] == after[key], "%s preserves %s" % [label, key])

func variants() -> Array:
 var result: Array = []
 for prop: Node3D in game.presentation.decor_root.get_children():
  result.append([prop.get_meta("decor_slot_id"), prop.get_meta("decor_variant"), prop.get_meta("decor_skin_id"), str(prop.transform)])
 return result

func entirely_visual(node: Node) -> bool:
 if node is CollisionObject2D or node is CollisionShape2D or node is CollisionPolygon2D or node is CollisionObject3D or node is CollisionShape3D or node is CollisionPolygon3D:
  return false
 for child: Node in node.get_children():
  if not entirely_visual(child): return false
 return true

func check_visuals(theme_id: String, label: String) -> void:
 var p = game.presentation
 check(p.theme_definition.theme_id == theme_id, "Requested theme is active: " + label)
 check(entirely_visual(p), "Entire presentation, decor and scenery remain collisionless: " + label)
 check(is_instance_valid(p.scenery_root) and p.scenery_root.get_child_count() > 0, "Theme supplies surrounding scenery: " + label)
 if game.authored_document == null: return
 var slots: Array = game.authored_document.decor_slots
 check(p.decor_root.get_child_count() == slots.size() and p.skipped_decor_slots.is_empty(), "Every supported generic slot resolves: " + label)
 var exact := true
 for i in mini(slots.size(), p.decor_root.get_child_count()):
  var prop: Node3D = p.decor_root.get_child(i)
  var slot: Dictionary = slots[i]
  exact = exact and prop.get_meta("decor_slot_id") == slot.slot_id and prop.get_meta("decor_skin_id") == theme_id
  exact = exact and prop.position.is_equal_approx(TablePresentation.map_point(slot.position, TablePresentation.RAIL_HEIGHT + TablePresentation.RAIL_CAP_HEIGHT))
  exact = exact and is_equal_approx(prop.rotation.y, -deg_to_rad(slot.rotation_degrees))
  exact = exact and prop.scale.is_equal_approx(Vector3.ONE * game.authored_document.cell_size * TablePresentation.SCALE * slot.scale)
 check(exact, "Slot positions, rotations, scales and identities are retained: " + label)

func seed_live_state() -> void:
 game.specials.select_character("tails")
 game.tuning.set_value("steering_acceleration", 2317.0)
 game.tuning.equip_chao("ice")
 game.scorecraft.award_bumper(game.playfield.bumpers[0])
 game.presentation.flash_bumper(game.playfield.bumpers[0])
 if not game.ring_field.rings.is_empty(): game.ring_field.claim_ring(0)
 game.score = 777
 game.rings_collected = 7
 game.special_meter = 63.0
 game.ball.linear_velocity = Vector2(137, -219)
 game.presentation.set_camera_value("look_ahead", 137)
 game.presentation.set_camera_value("dead_zone_y", 67)
 game.presentation.set_camera_follow(false)

func verify_restart() -> void:
 var actual: Dictionary = {}
 for example: String in EXAMPLES:
  await load_act(example)
  for theme_id: String in THEMES:
   check(game.set_theme(theme_id), "Fresh process selects " + theme_id)
   actual[example + "/" + theme_id] = variants()
 var expected = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
 check(actual == expected, "Fresh process resolves identical variants and authored transforms for both themes and Acts")
 finish()

func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
 root.size = Vector2i(1440, 1000)
 game = Game.new()
 game.generation_enabled = false
 game.authored_act_path = "res://data/acts/decor_terraces.tres"
 root.add_child(game)
 await frames(8)
 game.retro_filter.set_preset(0)
 await frames(3)
 paused = true
 if OS.get_cmdline_user_args().has("--verify-restart"):
  await verify_restart()
  return
 var manifest: Dictionary = {}
 for example: String in EXAMPLES:
  var path := "res://data/acts/%s.tres" % example
  var source := FileAccess.get_file_as_bytes(path)
  await load_act(example)
  game.set_theme("green_hill")
  seed_live_state()
  var before := snapshot()
  var green := variants()
  for theme_id: String in ["chemical_plant", "green_hill", "chemical_plant"]:
   var label := example + "/" + theme_id
   check(game.set_theme(theme_id), "Main game switches theme while paused: " + label)
   compare(before, label)
   check_visuals(theme_id, label)
   var selected: OptionButton = game.theme_selector
   check(selected.get_item_metadata(selected.selected) == theme_id, "HUD theme selector follows the active skin: " + label)
   if theme_id == "green_hill": check(variants() == green, "Switching back restores deterministic Green Hill variants")
   manifest[label] = variants()
  check(source == FileAccess.get_file_as_bytes(path), "Theme switching never rewrites the example Act: " + example)
  var chemical := variants()
  await load_act(example)
  check(game.presentation.theme_definition.theme_id == "chemical_plant" and variants() == chemical, "Act reload retains the active theme and deterministic variants: " + example)
  # Drive the same signal as the user-facing dropdown without reloading the Act.
  var selector_before := snapshot()
  game.theme_selector.item_selected.emit(0)
  check(game.presentation.theme_definition.theme_id == "green_hill", "Actual HUD selector returns to Green Hill")
  compare(selector_before, example + "/HUD selection")
  game.presentation.set_camera_follow(true)
  var follow_before := snapshot()
  check(game.set_theme("chemical_plant"), "Theme changes with follow camera enabled")
  compare(follow_before, example + "/follow camera")
 var file := FileAccess.open(MANIFEST, FileAccess.WRITE)
 file.store_string(JSON.stringify(manifest, "  "))
 file.close()
 var process_output: Array = []
 var status := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--log-file", ProjectSettings.globalize_path("res://test-results/theme-restart.log"), "--script", "res://tests/theme_runtime_regression.gd", "--", "--verify-restart"], process_output, true)
 check(status == 0 and str(process_output).contains("0 failures"), "A separate Godot process verifies stable variant selection and transforms")
 if status != 0: print(str(process_output))
 check(game.request_generated_source(), "Main game accepts generated-source smoke check")
 for i in 120:
  await frames(1)
  if not game.generation_pending: break
 check(game.level_source == "generated" and not game.chunks.is_empty(), "Generated source builds in the same main engine")
 game.presentation.set_camera_follow(false)
 var generated_before := snapshot()
 for theme_id: String in THEMES:
  check(game.set_theme(theme_id), "Generated source accepts theme: " + theme_id)
  compare(generated_before, "generated/" + theme_id)
  check_visuals(theme_id, "generated/" + theme_id)
 var invalid_before := snapshot()
 check(not game.set_theme("unknown_theme"), "Unknown themes are rejected without resetting the run")
 compare(invalid_before, "unknown theme")
 finish()

func finish() -> void:
 game.free()
 print("RESULT | Theme runtime | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
