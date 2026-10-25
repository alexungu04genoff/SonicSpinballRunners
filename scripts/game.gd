extends Node
## Owns run state and wiring. Physics, input, resources, and rendering remain independent.
var tuning: PhysicsTuning
var controls: PlaygroundInput
var world: Node2D
var chunks: Array[TableChunk] = []
var ball: PlaygroundBall
var flippers: Array[PlaygroundFlipper] = []
var ring_field: RingField
var presentation: TablePresentation
var debug_panel: PlaygroundDebugPanel
var score: int = 0
var rings_collected: int = 0
var ball_number: int = 1
var special_meter: float = 0.0
@export var scorecraft_enabled := true
@export var scorecraft_config: ScorecraftConfig = preload("res://data/scorecraft.tres")
var scorecraft: Scorecraft
@export_enum("sonic", "tails", "knuckles", "shadow") var character_id := "sonic"
var _target_awards: Dictionary = {}
var specials: CharacterSpecials
var status_message: String = "Press Enter / gamepad X to launch"
var respawn_time: float = -1.0
var auto_launch_time: float = -1.0
var ring_reset_time: float = -1.0
@export var score_attack_enabled: bool = false
@export_range(25, 1000000, 25) var score_attack_target: int = ScoreAttack.DEFAULT_TARGET
var score_attack := ScoreAttack.new()
@export var zone_enabled := false
@export var zone_config: ZoneConfig = preload("res://data/green_hill_zone.tres")
var zone := ZoneRun.new()
var zone_gates: Array[ZoneGate] = []
@export var zone_difficulty_override := -1
var drains: Array[PlayfieldDrain] = []
var _sandbox_chao := "none"
var previous_goal_position := Vector2.ZERO
var _goal_motion_ready := false
@export var generation_seed: int = 1
@export_enum("Easy", "Normal", "Hard") var generation_difficulty: int = TableGenerator.Difficulty.NORMAL
@export_enum("Existing catalogue", "Grid base", "Grid variant") var generation_grid_mode: int = 0
const GRID_MODE_NAMES := ["Existing catalogue", "Grid base", "Grid variant"]
const GRID_RECIPES: Array[GridChunkRecipe] = [
 preload("res://data/grid_chunks/flow_relay.tres"),
 preload("res://data/grid_chunks/flow_relay_variant.tres"),
]
const GRID_EASY_RECIPES: Array[GridChunkRecipe] = [
 preload("res://data/grid_chunks/flow_relay_easy.tres"),
 preload("res://data/grid_chunks/flow_relay_easy_variant.tres"),
]
## Legacy layout remains available for the original physics regression fixture.
@export var generation_enabled: bool = true
## Keep earlier two-section regression fixtures reproducible, outside the debug UI.
@export var legacy_pair_fixture: bool = false
var layout: Dictionary = {}
var generation_pending: bool = false
var view: SubViewport
const Playfield = preload("res://scripts/playfield_data.gd")
const ActDocument = preload("res://scripts/act_editor/act_geometry.gd")
const ActCompiler = preload("res://scripts/authored_act/act_runtime_compiler.gd")
const ActLifecycle = preload("res://scripts/authored_act/act_lifecycle.gd")
var playfield: PlayfieldData
var level_source := "generated"
var authored_act_path := ""
var authored_document: Resource
var authored_runtime: Dictionary = {}
var authored_timings: Dictionary = {}
var authored_activation_count := 0
var authored_exit_count := 0
var last_source_error := ""
var _authored_root: Node2D
var _ring_population_ms := 0.0

func _ready() -> void:
 tuning = PhysicsTuning.new()
 tuning.name = "PhysicsTuning"
 add_child(tuning)
 scorecraft = Scorecraft.new()
 scorecraft.name = "Scorecraft"
 scorecraft.config = scorecraft_config
 scorecraft.enabled = scorecraft_enabled
 add_child(scorecraft)
 controls = PlaygroundInput.new()
 controls.name = "InputRouter"
 add_child(controls)
 world = Node2D.new()
 world.name = "PhysicsWorld"
 add_child(world)
 ball = PlaygroundBall.new()
 ball.name = "PlayerPhysics"
 ball.tuning = tuning
 ball.controls = controls
 var args := OS.get_cmdline_user_args()
 var act_argument := args.find("--act")
 if act_argument >= 0 and act_argument + 1 < args.size():
  authored_act_path = args[act_argument + 1]
 var initial_authored: Dictionary = {}
 if not authored_act_path.is_empty():
  initial_authored = _prepare_authored(authored_act_path)
  if not initial_authored.error.is_empty():
   _fail_startup(initial_authored.error)
   return
  zone_enabled = false
  score_attack_enabled = false
  level_source = "authored"
  authored_document = initial_authored.document
  authored_runtime = initial_authored.runtime
  layout = _authored_layout(authored_document)
  playfield = Playfield.from_authored(authored_document, authored_runtime)
 else:
  layout = _generate_layout(generation_seed, generation_difficulty, -1, zone_enabled)
  generation_difficulty = int(layout.get("difficulty_preference", generation_difficulty))
  if not layout.valid:
   _fail_startup("No safe table layout: " + str(layout.errors))
   return
  for index in layout.chunks.size():
   chunks.append(_build_chunk(index))
  playfield = Playfield.from_generated(chunks, layout)
 ball.serve_position = playfield.spawn
 ball.position = ball.serve_position
 world.add_child(ball)
 ball.teleport_to(ball.position, Vector2.ZERO, true)
 if level_source == "authored":
  _authored_root = authored_runtime.root
  world.add_child(_authored_root)
  flippers.assign(authored_runtime.flippers)
 else:
  for index in range(chunks.size() - 1, -1, -1):
   _add_chunk_flippers(chunks[index])
 ring_field = RingField.new()
 ring_field.name = "Rings"
 ring_field.ball = ball
 ring_field.tuning = tuning
 ring_field.previous_ball_position = ball.position
 add_child(ring_field)
 _populate_rings()
 _setup_zone()
 specials = CharacterSpecials.new()
 specials.game = self
 add_child(specials)
 specials.character_changed.connect(func(_id: String): scorecraft.reset("Character changed", true))
 specials.select_character(character_id)
 score_attack_enabled = score_attack_enabled and not zone_enabled
 score_attack.reset(score_attack_enabled, score_attack_target, ScoreAttack.find_goal(layout))
 previous_goal_position = ball.serve_position
 var presentation_started := Time.get_ticks_usec()
 _build_view()
 var presentation_ms := (Time.get_ticks_usec() - presentation_started) / 1000.0
 debug_panel = PlaygroundDebugPanel.new()
 debug_panel.name = "DebugAndHUD"
 debug_panel.game = self
 debug_panel.tuning = tuning
 add_child(debug_panel)
 controls.launch_requested.connect(launch_ball)
 controls.reset_requested.connect(func(): reset_ball(true))
 controls.pause_requested.connect(toggle_pause)
 controls.debug_requested.connect(toggle_debug)
 controls.special_requested.connect(func():
  specials.activate()
  status_message = specials.feedback
 )
 ball.bumper_hit.connect(_on_bumper_hit)
 ring_field.scoring_pickup.connect(_on_ring_collected)
 tuning.changed.connect(_apply_tuning)
 _apply_tuning()
 if level_source == "authored":
  # Include the derived app's HUD setup in ready time, without charging it to
  # presentation geometry construction or waiting for the first rendered frame.
  call_deferred("_record_authored_timing", initial_authored, presentation_ms)
 print("PLAYGROUND_READY | Godot %s | 120 Hz | 2D collisions / 3D presentation | %s" % [Engine.get_version_info().string, layout.signature])

func _fail_startup(message: String) -> void:
 last_source_error = message
 push_error(message)
 ball.free()
 ball = null
 set_physics_process(false)
 set_process(false)
 set_process_unhandled_input(false)
 set_process_unhandled_key_input(false)
 var error_label := Label.new()
 error_label.position = Vector2(32, 32)
 error_label.size = Vector2(900, 200)
 error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 error_label.text = "Unable to load the playfield.\n\n%s\n\nClose this window and check the launch path and Act Spawn, then try again." % message
 add_child(error_label)

func _generate_layout(seed_value: int, preference: int, grid_mode: int = -1, for_zone: bool = false, difficulty_override: int = -2) -> Dictionary:
 if for_zone:
  if zone_config.difficulty != TableGenerator.Difficulty.EASY or zone_config.act_targets.size() != 3 or zone_config.act_targets.any(func(target: int): return target < 25):
   return {"valid": false, "errors": PackedStringArray(["This prototype requires one Easy Zone and three score targets of at least 25."])}
  var override := zone_difficulty_override if difficulty_override == -2 else difficulty_override
  if override < -1 or override > TableGenerator.Difficulty.HARD:
   return {"valid": false, "errors": PackedStringArray(["Invalid development Zone difficulty."])}
  return ZoneGenerator.generate(seed_value, generation_grid_mode if grid_mode < 0 else grid_mode, TableGenerator.Difficulty.EASY if override < 0 else override)
 if not generation_enabled:
  return TableGenerator.generate_pair(seed_value, preference, [])
 if legacy_pair_fixture:
  return TableGenerator.generate_pair(seed_value, preference)
 var mode := clampi(generation_grid_mode if grid_mode < 0 else grid_mode, 0, GRID_RECIPES.size())
 var result: Dictionary
 if mode == 0:
  result = TableGenerator.generate(seed_value, preference)
 else:
  # Easy has its own broad recipe; preserve the original Normal/Hard catalogue.
  var recipes := GRID_EASY_RECIPES if preference == TableGenerator.Difficulty.EASY else GRID_RECIPES
  var compiled := GridChunkCompiler.compile(recipes[mode - 1])
  if not compiled.valid:
   return compiled
  var middle: Array[ChunkData] = [compiled.chunk]
  result = TableGenerator.generate(seed_value, preference, TableGenerator.CATALOGUE, middle)
  # A broken experiment must not silently substitute an unrelated fallback section.
  if result.valid and not result.chunks[1].construction_grid.has("recipe_id"):
   return {"valid": false, "errors": PackedStringArray(["No valid grid layout; existing table preserved."])}
 result["construction_mode"] = mode
 result["construction_version"] = GridPieceKit.VERSION if mode > 0 else 0
 if result.valid and mode > 0:
  result.signature += " construction=%s kit=%d" % [GRID_MODE_NAMES[mode], result.construction_version]
 return result

func _build_chunk(index: int) -> TableChunk:
 var chunk := TableChunk.new()
 chunk.data = layout.chunks[index]
 chunk.name = "Section_%d_%s" % [index, chunk.data.chunk_id]
 for junction: Dictionary in layout.junctions:
  if junction.upper_index == index:
   chunk.junction_rails.append_array(junction.junction_rails)
 world.add_child(chunk)
 chunk.build()
 return chunk

func _add_chunk_flippers(chunk: TableChunk) -> void:
 for placement: Dictionary in chunk.data.world_flippers():
  var flipper := PlaygroundFlipper.new()
  flipper.name = "%s_%sFlipper" % [chunk.data.chunk_id, "Left" if placement.side > 0 else "Right"]
  flipper.side = placement.side
  flipper.length = placement.length
  flipper.position = placement.position
  flipper.ball = ball
  flipper.controls = controls
  flipper.tuning = tuning
  if placement.get("checkpoint_only", false):
   flipper.set_meta("checkpoint_chunk", chunk)
  world.add_child(flipper)
  flippers.append(flipper)

func current_chunk_index() -> int:
 for i in chunks.size():
  var data := chunks[i].data
  var bounds := data.world_rect(Rect2(Vector2.ZERO, Vector2(data.grid_dimensions) * ChunkData.GRID_SIZE))
  if bounds.has_point(ball.position):
   return i
 return -1

func _populate_rings() -> void:
 var started := Time.get_ticks_usec()
 ring_field.rings.clear()
 ring_field.previous_ball_position = ball.serve_position
 ring_field.ring_radius = float(authored_document.cell_size) * preload("res://scripts/act_dimensions.gd").RING_RADIUS_CELLS if level_source == "authored" else 12.0
 for point: Vector2 in playfield.ring_positions:
  ring_field.add_ring(point)
 _ring_population_ms = (Time.get_ticks_usec() - started) / 1000.0

func _build_view() -> void:
 var container := SubViewportContainer.new()
 container.name = "TableView"
 # Reserve the generator's left margin so a perspective near edge cannot hide behind it.
 container.position = Vector2(225, 85)
 container.size = Vector2(645, 750)
 container.stretch = true
 container.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(container)
 view = SubViewport.new()
 view.name = "Collisionless3DViewport"
 view.size = Vector2i(645, 750)
 view.own_world_3d = true
 view.msaa_3d = Viewport.MSAA_4X
 view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 container.add_child(view)
 _build_presentation()

func _build_presentation() -> void:
 presentation = TablePresentation.new()
 presentation.name = "Presentation"
 presentation.ball = ball
 presentation.flippers = flippers
 presentation.ring_field = ring_field
 view.add_child(presentation)
 if level_source == "authored":
  presentation.build_authored(authored_runtime, playfield.bounds, float(authored_document.cell_size))
  presentation.set_camera_follow(true)
 else:
  presentation.build(chunks, layout.junctions, layout.bounds)
 var goal := ScoreAttackGoal.new()
 goal.challenge = score_attack
 presentation.add_child(goal)
 _add_zone_presentation()

func _rebuild_presentation() -> void:
 presentation.flippers = flippers
 presentation.rebuild_playfield(playfield, chunks, layout)
 var goal := ScoreAttackGoal.new()
 goal.challenge = score_attack
 presentation.add_child(goal)
 _add_zone_presentation()

func _add_zone_presentation() -> void:
 _add_area_feedback()
 var markers := ZoneMarkers.new()
 markers.zone = zone
 presentation.add_child(markers)
 var feedback := CharacterFeedback.new()
 feedback.game = self
 presentation.add_child(feedback)

func _add_area_feedback() -> void:
 var area := AreaSpecialFeedback.new()
 area.game = self
 presentation.add_child(area)

func can_regenerate() -> bool:
 return not generation_pending and zone.state != ZoneRun.State.DRAFT and (get_tree().paused or (ball.serve_pending and not ball.release_pending))

func _source_settings_valid(settings: Dictionary) -> bool:
 if not CharacterSpecials.CHARACTERS.has(settings.get("character", character_id)):
  status_message = "Unknown character; current run preserved."
  return false
 if settings.has("chao") and not PhysicsTuning.CHAO.has(settings.chao):
  status_message = "Unknown Chao; current run preserved."
  return false
 return true

func request_authored_act(path: String, challenge_settings: Dictionary = {}) -> bool:
 if not _source_settings_valid(challenge_settings):
  return false
 if challenge_settings.get("zone", false) or challenge_settings.get("enabled", false):
  status_message = "Single authored Acts use Free Play. Score goals and multi-Act Zones remain separate."
  return false
 if not can_regenerate():
  status_message = "Pause before changing the level source, or wait at serve."
  return false
 generation_pending = true
 call_deferred("_load_authored_act", path, challenge_settings.duplicate())
 return true

func request_generated_source() -> bool:
 if not can_regenerate():
  status_message = "Pause before changing the level source, or wait at serve."
  return false
 generation_pending = true
 call_deferred("_regenerate", generation_seed, generation_difficulty, generation_grid_mode, {"zone": false, "enabled": false})
 return true

func _prepare_authored(path: String) -> Dictionary:
 var started := Time.get_ticks_usec()
 var loaded: Dictionary = ActDocument.load_document(path)
 var result := {"document": loaded.document, "runtime": {}, "error": loaded.error,
  "started": started, "load_ms": (Time.get_ticks_usec() - started) / 1000.0}
 if loaded.document == null:
  return result
 result.runtime = ActCompiler.compile(loaded.document, tuning, controls, ball)
 result.error = result.runtime.error
 return result

func _authored_layout(document: Resource) -> Dictionary:
 # Keep the legacy generated-layout metadata at the source boundary. Downstream
 # gameplay reads PlayfieldData and never requires fabricated TableChunks.
 return {"valid": true, "chunks": [], "junctions": [], "bounds": Rect2(Vector2.ZERO, document.red_gutter_bounds().end),
  "signature": "Authored Act / " + str(document.title), "used_fallback": false}

func _load_authored_act(path: String, challenge_settings: Dictionary) -> void:
 if not (get_tree().paused or (ball.serve_pending and not ball.release_pending)):
  generation_pending = false
  status_message = "Level load cancelled because play resumed."
  return
 var prepared := _prepare_authored(path)
 if not prepared.error.is_empty():
  last_source_error = prepared.error
  status_message = "Cannot load Act: " + last_source_error
  generation_pending = false
  return
 authored_act_path = path
 last_source_error = ""
 var settings := challenge_settings.duplicate()
 settings.zone = false
 settings.enabled = false
 await _replace_playfield(_authored_layout(prepared.document), generation_seed, generation_difficulty, generation_grid_mode, settings, prepared)

func _record_authored_timing(prepared: Dictionary, presentation_ms: float) -> void:
 authored_timings = {"load_ms": prepared.load_ms, "terrain_ms": prepared.runtime.timings.terrain_ms,
  "objects_ms": prepared.runtime.timings.objects_ms, "rings_ms": _ring_population_ms, "presentation_ms": presentation_ms,
  "total_ms": (Time.get_ticks_usec() - int(prepared.started)) / 1000.0}
 print("AUTHORED_MAIN_READY | Load %.2f ms | Terrain %.2f ms | Objects %.2f ms | Rings %.2f ms | Green Hill %.2f ms | Ready %.2f ms" % [authored_timings.load_ms, authored_timings.terrain_ms, authored_timings.objects_ms, authored_timings.rings_ms, authored_timings.presentation_ms, authored_timings.total_ms])

func request_generation(seed_value: int, preference: int = -1, grid_mode: int = -1, challenge_settings: Dictionary = {}) -> bool:
 # Existing Start/replay, character and Chao controls replay the active source.
 if level_source == "authored":
  return request_authored_act(authored_act_path, challenge_settings)
 if not CharacterSpecials.CHARACTERS.has(challenge_settings.get("character", character_id)):
  status_message = "Unknown character; current run preserved."
  return false
 if (bool(challenge_settings.get("zone", zone_enabled))) and challenge_settings.has("chao"):
  status_message = "Zone upgrades are chosen after completing an Act."
  return false
 if challenge_settings.has("chao") and not PhysicsTuning.CHAO.has(challenge_settings.chao):
  status_message = "Unknown Chao; current run preserved."
  return false
 if not can_regenerate():
  status_message = "Pause before generating a table, or wait at serve."
  return false
 generation_pending = true
 var requested := generation_difficulty if preference < 0 else clampi(preference, TableGenerator.Difficulty.EASY, TableGenerator.Difficulty.HARD)
 var requested_grid := generation_grid_mode if grid_mode < 0 else clampi(grid_mode, 0, GRID_RECIPES.size())
 call_deferred("_regenerate", clampi(seed_value, 0, 2147483647), requested, requested_grid, challenge_settings.duplicate())
 return true

func _regenerate(seed_value: int, preference: int, grid_mode: int = -1, challenge_settings: Dictionary = {}) -> void:
 # Validate before touching the active scene; swap outside physics callbacks.
 if not (get_tree().paused or (ball.serve_pending and not ball.release_pending)):
  generation_pending = false
  status_message = "Generation cancelled because play resumed. Pause and try again."
  return
 var requested_zone: bool = challenge_settings.get("zone", zone_enabled)
 var requested_override: int = challenge_settings.get("zone_difficulty", zone_difficulty_override)
 var candidate := _generate_layout(seed_value, preference, grid_mode, requested_zone, requested_override)
 if not candidate.valid:
  status_message = "Generation failed; current table preserved. " + "; ".join(candidate.errors)
  push_error(str(candidate.errors))
  generation_pending = false
  return
 var goal_position := ScoreAttack.find_goal(candidate)
 var challenge_enabled: bool = not requested_zone and challenge_settings.get("enabled", score_attack_enabled)
 if challenge_enabled and not goal_position.is_finite():
  status_message = "No clear upper goal anchor; current table preserved."
  generation_pending = false
  return
 await _replace_playfield(candidate, seed_value, preference, grid_mode, challenge_settings)

func _replace_playfield(candidate: Dictionary, seed_value: int, preference: int, _grid_mode: int, challenge_settings: Dictionary, prepared: Dictionary = {}) -> void:
 last_source_error = ""
 var requested_zone: bool = challenge_settings.get("zone", zone_enabled)
 var requested_override: int = challenge_settings.get("zone_difficulty", zone_difficulty_override)
 var challenge_enabled: bool = not requested_zone and challenge_settings.get("enabled", score_attack_enabled)
 var goal_position := ScoreAttack.find_goal(candidate)
 var resume_after_victory := score_attack.state == ScoreAttack.State.COMPLETE or zone.state == ZoneRun.State.COMPLETE
 scorecraft.reset("New run", true)
 scorecraft_enabled = bool(challenge_settings.get("combos", scorecraft_enabled))
 scorecraft.enabled = scorecraft_enabled
 var requested_character: String = challenge_settings.get("character", character_id)
 if requested_character != character_id:
  specials.select_character(requested_character)
 else:
  specials.reset(true, "New run")
 ball.freeze = true
 ball.linear_velocity = Vector2.ZERO
 for gate: ZoneGate in zone_gates:
  gate.free()
 zone_gates.clear()
 if not prepared.is_empty():
  _clear_playfield_geometry()
  level_source = "authored"
  authored_document = prepared.document
  authored_runtime = prepared.runtime
  _authored_root = authored_runtime.root
  world.add_child(_authored_root)
  flippers.assign(authored_runtime.flippers)
  layout = candidate
  playfield = Playfield.from_authored(authored_document, authored_runtime)
 else:
  _install_generated_geometry(candidate)
  generation_seed = seed_value
  generation_difficulty = int(candidate.get("difficulty_preference", preference))
  generation_grid_mode = int(candidate.get("construction_mode", 0))
 # Commit the loadout only after the replacement layout has passed validation.
 # Ordinary replay/regeneration retains the slot; no modifier list accumulates.
 if requested_zone:
  if not zone_enabled:
   _sandbox_chao = tuning.chao_id
  tuning.clear_build()
 elif zone_enabled:
  tuning.equip_chao(_sandbox_chao)
 if challenge_settings.has("chao"):
  tuning.equip_chao(challenge_settings.chao)
 zone_enabled = requested_zone
 zone_difficulty_override = requested_override
 ball.serve_position = playfield.spawn
 ball.teleport_to(ball.serve_position, Vector2.ZERO, true)
 _apply_tuning()
 _populate_rings()
 _setup_zone()
 for flipper: PlaygroundFlipper in flippers:
  flipper.rotation = flipper.rest_angle()
  flipper.held = false
  flipper.swing_remaining = 0.0
  flipper.struck_this_swing = false
  flipper.strikes = 0
 score = 0
 rings_collected = 0
 ball_number = 1
 special_meter = 0.0
 respawn_time = -1.0
 auto_launch_time = -1.0
 ring_reset_time = -1.0
 ball.bumper_hit_count = 0
 ball.sweep_rebounds = 0
 _target_awards.clear()
 authored_activation_count = 0
 authored_exit_count = 0
 score_attack_enabled = challenge_enabled
 score_attack_target = clampi(int(challenge_settings.get("target", score_attack_target)), 25, 1000000)
 score_attack.reset(score_attack_enabled, score_attack_target, goal_position)
 previous_goal_position = ball.serve_position
 _goal_motion_ready = false
 var presentation_started := Time.get_ticks_usec()
 _rebuild_presentation()
 presentation.reset_camera(ball.serve_position)
 var presentation_ms := (Time.get_ticks_usec() - presentation_started) / 1000.0
 ball.freeze = false
 if resume_after_victory:
  # Resume outside this deferred callback: Godot 2D can otherwise step twice
  # without flushing body queries when unpaused in the middle of a physics tick.
  await get_tree().process_frame
  get_tree().paused = false
 generation_pending = false
 debug_panel.refresh_generation()
 status_message = "Table ready. Resume if paused, then Enter / X to launch."
 if resume_after_victory:
  status_message = "Fresh challenge. Enter / X to launch."
 if not prepared.is_empty():
  _record_authored_timing(prepared, presentation_ms)
 else:
  print("TABLE_GENERATED | " + layout.signature + " | fallback=" + str(layout.used_fallback))

func _clear_playfield_geometry() -> void:
 for flipper: PlaygroundFlipper in flippers:
  flipper.free()
 flippers.clear()
 for chunk: TableChunk in chunks:
  chunk.free()
 chunks.clear()
 if is_instance_valid(_authored_root):
  _authored_root.free()
 _authored_root = null

func _install_generated_geometry(candidate: Dictionary) -> void:
 if chunks.is_empty():
  _clear_playfield_geometry()
  layout = candidate
  for index in layout.chunks.size():
   chunks.append(_build_chunk(index))
  for index in range(chunks.size() - 1, -1, -1):
   _add_chunk_flippers(chunks[index])
 else:
  _replace_generated_chunks(candidate)
 level_source = "generated"
 authored_document = null
 authored_runtime = {}
 ball.radius = PlaygroundBall.RADIUS
 playfield = Playfield.from_generated(chunks, layout)

func _replace_generated_chunks(candidate: Dictionary) -> void:
 # Preserve the existing generated lower deck and paddles when identical.
 var lower: TableChunk = chunks.back()
 var keep_lower_geometry: bool = lower.data.gameplay_descriptors() == candidate.chunks.back().gameplay_descriptors()
 var keep_lower_paddles: bool = lower.data.world_flippers() == candidate.chunks.back().world_flippers()
 for i in range(chunks.size() - 1):
  chunks[i].free()
 chunks.clear()
 for i in range(flippers.size() - 1, 1, -1):
  flippers[i].free()
  flippers.remove_at(i)
 if not keep_lower_paddles:
  for flipper: PlaygroundFlipper in flippers:
   flipper.free()
  flippers.clear()
 layout = candidate
 for i in range(layout.chunks.size() - 1):
  chunks.append(_build_chunk(i))
 if keep_lower_geometry:
  lower.data = layout.chunks.back()
 else:
  lower.free()
  lower = _build_chunk(layout.chunks.size() - 1)
 chunks.append(lower)
 if not keep_lower_paddles:
  _add_chunk_flippers(lower)
 for i in range(chunks.size() - 2, -1, -1):
  _add_chunk_flippers(chunks[i])

func _apply_tuning() -> void:
 for body: StaticBody2D in playfield.terrain_bodies:
  if is_instance_valid(body) and body.physics_material_override != null:
   body.physics_material_override.bounce = tuning.effective.wall_restitution

func launch_ball() -> void:
 if respawn_time > 0 or generation_pending or score_attack.state == ScoreAttack.State.COMPLETE or zone.state in [ZoneRun.State.DRAFT, ZoneRun.State.COMPLETE]:
  return
 ball.launch()
 auto_launch_time = -1.0
 status_message = "Keep it alive. Time your flips; steer lightly."

func reset_ball(relaunch: bool = false) -> void:
 if zone.state == ZoneRun.State.DRAFT:
  return
 if score_attack.state == ScoreAttack.State.COMPLETE or zone.state == ZoneRun.State.COMPLETE:
  request_generation(generation_seed)
  return
 specials.reset(false, "Reset")
 scorecraft.reset("Reset", true)
 respawn_time = -1.0
 previous_goal_position = ball.serve_position
 _goal_motion_ready = false
 presentation.clear_ring_pickups()
 ball.teleport_to(ball.serve_position, Vector2.ZERO, true)
 presentation.reset_camera(ball.serve_position)
 ring_field.previous_ball_position = ball.serve_position
 if zone_enabled:
  ring_field.reset_rings()
  ring_reset_time = -1.0
 auto_launch_time = 0.25 if relaunch else -1.0
 status_message = "Act %d checkpoint — score and Chao retained" % (zone.active_act + 1) if zone_enabled else "Ready to launch"

func toggle_debug() -> void:
 if zone.state == ZoneRun.State.DRAFT:
  return
 debug_panel.panel.visible = not debug_panel.panel.visible
 debug_panel.generation_panel.visible = debug_panel.panel.visible
 get_viewport().gui_release_focus()

func toggle_pause() -> void:
 if score_attack.state == ScoreAttack.State.COMPLETE or zone.state in [ZoneRun.State.DRAFT, ZoneRun.State.COMPLETE]:
  return
 get_tree().paused = not get_tree().paused

func _on_bumper_hit(body: Node) -> void:
 var impact: bool = specials.impact_target == body
 _award_bumper(body, "shockwave" if impact else "", specials.definition.shockwave_multiplier if impact else 1, true)

func scoring_target_eligible(body: Node2D) -> bool:
 if not is_instance_valid(body) or not body.has_meta("bumper") or respawn_time >= 0.0 or generation_pending:
  return false
 if score_attack.state == ScoreAttack.State.COMPLETE:
  return false
 return not zone_enabled or (zone.state == ZoneRun.State.PLAYING and zone.acts[zone.active_act].bounds.has_point(body.global_position))

func activate_area_target(body: Node2D, source: String, multiplier: int) -> bool:
 if source not in ["shockwave", "chaos_blast"]:
  return false
 return _award_bumper(body, source, multiplier, false)

func _award_bumper(body: Node2D, source: String, multiplier: int, physical: bool) -> bool:
 if not scoring_target_eligible(body):
  return false
 var key := body.get_instance_id()
 var frame := Engine.get_physics_frames()
 var previous: Dictionary = _target_awards.get(key, {})
 # Share the existing contact cooldown across remote/contact award paths.
 # Ordinary repeated contacts retain Scorecraft's existing repeated-target rule.
 if not previous.is_empty() and frame - previous.frame < ceili(0.16 * Engine.physics_ticks_per_second) and (not physical or previous.remote):
  return false
 _target_awards[key] = {"frame": frame, "remote": not physical}
 score += scorecraft.award_bumper(body, specials.hit_multiplier(body)) if source.is_empty() else scorecraft.award_area("bumper", source, multiplier, body)
 if physical:
  specials.charge(specials.definition.bumper_charge)
 presentation.flash_bumper(body)
 _observe_challenge_score()
 return true

func _on_ring_collected(_where: Vector2, source: String = "", multiplier: int = 1) -> void:
 if respawn_time >= 0.0 or generation_pending:
  return
 if score_attack.state == ScoreAttack.State.COMPLETE or (zone_enabled and zone.state != ZoneRun.State.PLAYING):
  return
 score += scorecraft.award_ring() if source.is_empty() else scorecraft.award_area("ring", source, multiplier)
 rings_collected += 1
 if source.is_empty():
  specials.charge(specials.definition.ring_charge)
 var active: int = 0
 for ring: Dictionary in ring_field.rings:
  if ring.active and ring_field.ring_eligible(ring):
   active += 1
 if active == 0:
  score += scorecraft.award_rack()
  ring_reset_time = 1.0
  status_message = "RING RACK CLEARED  +500"
 _observe_challenge_score()

func _observe_challenge_score() -> void:
 if zone_enabled:
  var locked := not zone.exit_unlocked
  zone.observe_score(score)
  if locked and zone.exit_unlocked:
   previous_goal_position = ball.position
   _sync_zone_gates()
   status_message = "ACT %d EXIT OPEN — climb and cross to claim a Chao!" % (zone.active_act + 1)
  return
 var was_locked := score_attack.state == ScoreAttack.State.LOCKED
 score_attack.observe_score(score)
 if was_locked and score_attack.state == ScoreAttack.State.UNLOCKED:
  # Crossing the goal while locked cannot be credited retroactively.
  previous_goal_position = ball.position
  status_message = "GOAL OPEN — climb to the green ring in the upper section!"

func _physics_process(delta: float) -> void:
 if not is_instance_valid(ball) or generation_pending:
  return
 if score_attack.state == ScoreAttack.State.COMPLETE or zone.state in [ZoneRun.State.DRAFT, ZoneRun.State.COMPLETE]:
  return
 if respawn_time >= 0.0:
  respawn_time -= delta
  if respawn_time <= 0:
   reset_ball(true)
 elif not ball.serve_pending and not ball._teleport_pending and _at_playfield_drain():
  ball_number += 1
  respawn_time = 0.65
  specials.reset(false, "Drain")
  scorecraft.reset("Drain", true)
  presentation.clear_ring_pickups()
  status_message = "DRAIN — automatic respawn"
 if auto_launch_time >= 0:
  auto_launch_time -= delta
  if auto_launch_time <= 0:
   launch_ball()
 if ring_reset_time >= 0:
  ring_reset_time -= delta
  if ring_reset_time <= 0:
   ring_field.reset_rings()
 if not ball.serve_pending and not ball._teleport_pending and respawn_time < 0.0:
  var start := previous_goal_position if _goal_motion_ready else ball.position
  if level_source == "authored":
   var events: Dictionary = ActLifecycle.crossings(authored_document, start, ball.position)
   if events.activation:
    authored_activation_count += 1
    print("ACT ACTIVATED | upward crossing ", authored_activation_count)
   if events.exit:
    authored_exit_count += 1
    print("ACT EXIT REACHED | upward crossing ", authored_exit_count)
  if score_attack.observe_motion(start, ball.position):
   specials.reset(false, "Challenge complete")
   scorecraft.reset("Challenge complete")
   status_message = "SCORE ATTACK CLEAR! Upper goal reached."
   get_tree().paused = true
  if zone_enabled and zone.observe_motion(start, ball.position):
   specials.clear_homing("Act complete")
   _sync_zone_gates()
   status_message = "ACT %d CLEAR — choose your Chao" % (zone.active_act + 1)
   get_tree().paused = true
  _goal_motion_ready = true
 else:
  _goal_motion_ready = false
 previous_goal_position = ball.position
 if level_source == "authored" and (ball.serve_pending or ball._teleport_pending):
  previous_goal_position = ball.serve_position
  _goal_motion_ready = true

func _at_playfield_drain() -> bool:
 if level_source == "authored":
  return ball.position.y >= authored_document.red_gutter_bounds().end.y
 return _at_checkpoint_drain() or ball.position.y > layout.bounds.end.y + 50.0 or ball.position.x < layout.bounds.position.x - 250.0 or ball.position.x > layout.bounds.end.x + 250.0 or ball.position.y < layout.bounds.position.y - 200.0

func _setup_zone() -> void:
 for drain: PlayfieldDrain in drains:
  drain.free()
 drains.clear()
 zone.reset(zone_enabled, zone_config, layout)
 ring_field.collection_bounds = zone.acts[0].bounds if zone_enabled else Rect2()
 for chunk: TableChunk in chunks:
  if chunk.data.markers.has("drain"):
   var drain := PlayfieldDrain.new()
   drain.ball = ball
   var center: Vector2 = chunk.data.world_point(chunk.data.markers.drain)
   drain.bounds = Rect2(center - Vector2(35, 5), Vector2(70, 20))
   world.add_child(drain)
   drains.append(drain)
 _sync_act_bottoms()
 if not zone_enabled:
  return
 for index in 2:
  var act: Dictionary = zone.acts[index]
  var gate := ZoneGate.new()
  gate.name = "Act%dGate" % (index + 1)
  gate.opening = Rect2(act.exit_left, act.exit_y, act.exit_right - act.exit_left, 0)
  world.add_child(gate)
  zone_gates.append(gate)
 _sync_zone_gates()

func _sync_zone_gates() -> void:
 for index in zone_gates.size():
  zone_gates[index].set_closed(index != zone.active_act or not zone.exit_unlocked or zone.state != ZoneRun.State.PLAYING)
 _sync_act_bottoms()

func _sync_act_bottoms() -> void:
 var current_bounds: Rect2 = zone.acts[zone.active_act].bounds if zone_enabled else layout.bounds
 for chunk: TableChunk in chunks:
  chunk.set_checkpoint_active(not zone_enabled or current_bounds.has_point(chunk.data.world_point(Vector2(400, 400))))
 for flipper: PlaygroundFlipper in flippers:
  if flipper.has_meta("checkpoint_chunk"):
   flipper.set_enabled(not zone_enabled or current_bounds.has_point(flipper.position))
 for drain: PlayfieldDrain in drains:
  drain.active = not zone_enabled or (drain.bounds.get_center().y >= current_bounds.position.y and drain.bounds.get_center().y < current_bounds.end.y)

func _at_checkpoint_drain() -> bool:
 for drain: PlayfieldDrain in drains:
  if drain.crossed(previous_goal_position, ball.position):
   return true
 return false

func choose_zone_chao(id: String) -> bool:
 if zone.state != ZoneRun.State.DRAFT or not tuning.can_add_chao(id):
  return false
 if not tuning.add_chao(id):
  return false
 zone.accept_reward(id, score)
 specials.act_advanced()
 scorecraft.reset("Act advanced", true)
 _sync_zone_gates()
 if zone.state == ZoneRun.State.COMPLETE:
  specials.reset(false, "Zone complete")
  status_message = "GREEN HILL ZONE COMPLETE!"
  return true
 ball.serve_position = zone.acts[zone.active_act].entry
 ring_field.collection_bounds = zone.acts[zone.active_act].bounds
 ring_field.previous_ball_position = ball.position
 ring_field.reset_rings()
 ring_reset_time = -1.0
 previous_goal_position = ball.position
 _goal_motion_ready = false
 status_message = "ACT %d — checkpoint set; earn %d new points" % [zone.active_act + 1, zone.targets[zone.active_act]]
 get_tree().paused = false
 return true
