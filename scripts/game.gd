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

func _ready() -> void:
 tuning = PhysicsTuning.new()
 tuning.name = "PhysicsTuning"
 add_child(tuning)
 controls = PlaygroundInput.new()
 controls.name = "InputRouter"
 add_child(controls)
 world = Node2D.new()
 world.name = "PhysicsWorld"
 add_child(world)
 layout = _generate_layout(generation_seed, generation_difficulty, -1, zone_enabled)
 generation_difficulty = int(layout.get("difficulty_preference", generation_difficulty))
 if not layout.valid:
  push_error("No safe table layout: " + str(layout.errors))
  set_physics_process(false)
  return
 for index in layout.chunks.size():
  chunks.append(_build_chunk(index))
 ball = PlaygroundBall.new()
 ball.name = "PlayerPhysics"
 ball.serve_position = chunks.back().get_node("serve").global_position
 ball.position = ball.serve_position
 ball.tuning = tuning
 ball.controls = controls
 world.add_child(ball)
 ball.teleport_to(ball.position, Vector2.ZERO, true)
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
 score_attack_enabled = score_attack_enabled and not zone_enabled
 score_attack.reset(score_attack_enabled, score_attack_target, ScoreAttack.find_goal(layout))
 previous_goal_position = ball.serve_position
 _build_view()
 debug_panel = PlaygroundDebugPanel.new()
 debug_panel.name = "DebugAndHUD"
 debug_panel.game = self
 debug_panel.tuning = tuning
 add_child(debug_panel)
 controls.launch_requested.connect(launch_ball)
 controls.reset_requested.connect(func(): reset_ball(true))
 controls.pause_requested.connect(toggle_pause)
 controls.debug_requested.connect(toggle_debug)
 controls.special_requested.connect(func(): status_message = "Special reserved for future experiments — no ability implemented yet")
 ball.bumper_hit.connect(_on_bumper_hit)
 ring_field.collected.connect(_on_ring_collected)
 tuning.changed.connect(_apply_tuning)
 _apply_tuning()
 print("PLAYGROUND_READY | Godot %s | 120 Hz | 2D collisions / 3D presentation | %s" % [Engine.get_version_info().string, layout.signature])

func _generate_layout(seed_value: int, preference: int, grid_mode: int = -1, for_zone: bool = false) -> Dictionary:
 if for_zone:
  if zone_config.difficulty != TableGenerator.Difficulty.EASY or zone_config.act_targets.size() != 3 or zone_config.act_targets.any(func(target: int): return target < 25):
   return {"valid": false, "errors": PackedStringArray(["This prototype requires one Easy Zone and three score targets of at least 25."])}
  return ZoneGenerator.generate(seed_value, generation_grid_mode if grid_mode < 0 else grid_mode)
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
 ring_field.rings.clear()
 ring_field.previous_ball_position = ball.serve_position
 for chunk: TableChunk in chunks:
  for descriptor: Dictionary in chunk.descriptors:
   if descriptor.kind == "ring":
    ring_field.add_ring(descriptor.position)

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
 presentation.build(chunks, layout.junctions, layout.bounds)
 var goal := ScoreAttackGoal.new()
 goal.challenge = score_attack
 presentation.add_child(goal)
 _add_zone_presentation()

func _add_zone_presentation() -> void:
 var markers := ZoneMarkers.new()
 markers.zone = zone
 presentation.add_child(markers)

func can_regenerate() -> bool:
 return not generation_pending and zone.state != ZoneRun.State.DRAFT and (get_tree().paused or ball.serve_pending)

func request_generation(seed_value: int, preference: int = -1, grid_mode: int = -1, challenge_settings: Dictionary = {}) -> bool:
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
 if not (get_tree().paused or ball.serve_pending):
  generation_pending = false
  status_message = "Generation cancelled because play resumed. Pause and try again."
  return
 var requested_zone: bool = challenge_settings.get("zone", zone_enabled)
 var candidate := _generate_layout(seed_value, preference, grid_mode, requested_zone)
 if not candidate.valid:
  status_message = "Generation failed; current table preserved."
  push_error(str(candidate.errors))
  generation_pending = false
  return
 var goal_position := ScoreAttack.find_goal(candidate)
 var challenge_enabled: bool = not requested_zone and challenge_settings.get("enabled", score_attack_enabled)
 if challenge_enabled and not goal_position.is_finite():
  status_message = "No clear upper goal anchor; current table preserved."
  generation_pending = false
  return
 var resume_after_victory := score_attack.state == ScoreAttack.State.COMPLETE or zone.state == ZoneRun.State.COMPLETE
 var overlays: Array[bool] = [presentation.physics_overlay.visible, presentation.chunk_overlay.visible, presentation.connector_overlay.visible, presentation.construction_grid_overlay.visible]
 var camera_preset: int = presentation.camera_preset
 var camera_follow: bool = presentation.camera_follow_enabled
 var camera_settings: Dictionary = presentation.camera_settings.duplicate()
 ball.freeze = true
 ball.linear_velocity = Vector2.ZERO
 presentation.free()
 for gate: ZoneGate in zone_gates:
  gate.free()
 zone_gates.clear()
 # Paddles stay put. A shaped lower junction can change the deck's top wall collar.
 var lower: TableChunk = chunks.back()
 var keep_lower_geometry: bool = lower.data.gameplay_descriptors() == candidate.chunks.back().gameplay_descriptors()
 for i in range(chunks.size() - 1):
  chunks[i].free()
 chunks.clear()
 for i in range(flippers.size() - 1, 1, -1):
  flippers[i].free()
  flippers.remove_at(i)
 if not keep_lower_geometry:
  for flipper: PlaygroundFlipper in flippers:
   flipper.free()
  flippers.clear()
 layout = candidate
 generation_seed = seed_value
 generation_difficulty = int(candidate.get("difficulty_preference", preference))
 generation_grid_mode = int(candidate.get("construction_mode", 0))
 for i in range(layout.chunks.size() - 1):
  chunks.append(_build_chunk(i))
 if keep_lower_geometry:
  lower.data = layout.chunks.back()
 else:
  lower.free()
  lower = _build_chunk(layout.chunks.size() - 1)
 chunks.append(lower)
 if not keep_lower_geometry:
  _add_chunk_flippers(lower)
 for i in range(chunks.size() - 2, -1, -1):
  _add_chunk_flippers(chunks[i])
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
 ball.serve_position = chunks.back().get_node("serve").global_position
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
 score_attack_enabled = challenge_enabled
 score_attack_target = clampi(int(challenge_settings.get("target", score_attack_target)), 25, 1000000)
 score_attack.reset(score_attack_enabled, score_attack_target, goal_position)
 previous_goal_position = ball.serve_position
 _goal_motion_ready = false
 _build_presentation()
 presentation.physics_overlay.visible = overlays[0]
 presentation.chunk_overlay.visible = overlays[1]
 presentation.connector_overlay.visible = overlays[2]
 presentation.construction_grid_overlay.visible = overlays[3]
 presentation.set_camera_preset(camera_preset)
 for key: String in camera_settings:
  presentation.set_camera_value(key, camera_settings[key])
 presentation.set_camera_follow(camera_follow)
 presentation.reset_camera(ball.serve_position)
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
 print("TABLE_GENERATED | " + layout.signature + " | fallback=" + str(layout.used_fallback))

func _apply_tuning() -> void:
 for chunk: TableChunk in chunks:
  chunk.wall_material.bounce = tuning.effective.wall_restitution

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
 if score_attack.state == ScoreAttack.State.COMPLETE or (zone_enabled and (zone.state != ZoneRun.State.PLAYING or not zone.acts[zone.active_act].bounds.has_point(body.global_position))):
  return
 score += 100
 special_meter = minf(100.0, special_meter + 2.0 * float(tuning.effective.special_meter_charge_multiplier))
 presentation.flash_bumper(body)
 _observe_challenge_score()

func _on_ring_collected(_where: Vector2) -> void:
 if score_attack.state == ScoreAttack.State.COMPLETE or (zone_enabled and zone.state != ZoneRun.State.PLAYING):
  return
 score += 25
 rings_collected += 1
 special_meter = minf(100.0, special_meter + 5.0 * float(tuning.effective.special_meter_charge_multiplier))
 var active: int = 0
 for ring: Dictionary in ring_field.rings:
  if ring.active and ring_field.ring_eligible(ring):
   active += 1
 if active == 0:
  score += 500
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
 if score_attack.state == ScoreAttack.State.COMPLETE or zone.state in [ZoneRun.State.DRAFT, ZoneRun.State.COMPLETE]:
  return
 if respawn_time >= 0.0:
  respawn_time -= delta
  if respawn_time <= 0:
   reset_ball(true)
 elif not ball.serve_pending and (_at_checkpoint_drain() or ball.position.y > layout.bounds.end.y + 50.0 or ball.position.x < layout.bounds.position.x - 250.0 or ball.position.x > layout.bounds.end.x + 250.0 or ball.position.y < layout.bounds.position.y - 200.0):
  ball_number += 1
  respawn_time = 0.65
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
  if score_attack.observe_motion(start, ball.position):
   status_message = "SCORE ATTACK CLEAR! Upper goal reached."
   get_tree().paused = true
  if zone_enabled and zone.observe_motion(start, ball.position):
   _sync_zone_gates()
   status_message = "ACT %d CLEAR — choose your Chao" % (zone.active_act + 1)
   get_tree().paused = true
  _goal_motion_ready = true
 else:
  _goal_motion_ready = false
 previous_goal_position = ball.position

func _setup_zone() -> void:
 zone.reset(zone_enabled, zone_config, layout)
 ring_field.collection_bounds = zone.acts[0].bounds if zone_enabled else Rect2()
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

func _at_checkpoint_drain() -> bool:
 if not zone_enabled or zone.active_act == 0:
  return false
 # The latched physical gate prevents fallback. Falling toward it counts as a
 # checkpoint drain, giving a fresh playable serve instead of a flat-floor trap.
 return ball.linear_velocity.y > 0 and ball.position.y > float(zone.acts[zone.active_act].bounds.end.y) - 48.0

func choose_zone_chao(id: String) -> bool:
 if zone.state != ZoneRun.State.DRAFT or not tuning.can_add_chao(id):
  return false
 if not tuning.add_chao(id):
  return false
 zone.accept_reward(id, score)
 _sync_zone_gates()
 if zone.state == ZoneRun.State.COMPLETE:
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
