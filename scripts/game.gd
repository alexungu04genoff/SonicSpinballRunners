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
@export var generation_seed: int = 1
@export_enum("Easy", "Normal", "Hard") var generation_difficulty: int = TableGenerator.Difficulty.NORMAL
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
 layout = _generate_layout(generation_seed, generation_difficulty)
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
 _build_view()
 debug_panel = PlaygroundDebugPanel.new()
 debug_panel.name = "DebugAndHUD"
 debug_panel.game = self
 debug_panel.tuning = tuning
 add_child(debug_panel)
 controls.launch_requested.connect(launch_ball)
 controls.reset_requested.connect(func(): reset_ball(true))
 controls.pause_requested.connect(toggle_pause)
 controls.debug_requested.connect(func():
  debug_panel.panel.visible = not debug_panel.panel.visible
  debug_panel.generation_panel.visible = debug_panel.panel.visible
  get_viewport().gui_release_focus()
 )
 controls.special_requested.connect(func(): status_message = "Special reserved for future experiments — no ability implemented yet")
 ball.bumper_hit.connect(_on_bumper_hit)
 ring_field.collected.connect(_on_ring_collected)
 tuning.changed.connect(_apply_tuning)
 _apply_tuning()
 print("PLAYGROUND_READY | Godot %s | 120 Hz | 2D collisions / 3D presentation | %s" % [Engine.get_version_info().string, layout.signature])

func _generate_layout(seed_value: int, preference: int) -> Dictionary:
 if not generation_enabled:
  return TableGenerator.generate_pair(seed_value, preference, [])
 if legacy_pair_fixture:
  return TableGenerator.generate_pair(seed_value, preference)
 return TableGenerator.generate(seed_value, preference)

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

func can_regenerate() -> bool:
 return not generation_pending and (get_tree().paused or ball.serve_pending)

func request_generation(seed_value: int, preference: int = -1) -> bool:
 if not can_regenerate():
  status_message = "Pause before generating a table, or wait at serve."
  return false
 generation_pending = true
 var requested := generation_difficulty if preference < 0 else clampi(preference, TableGenerator.Difficulty.EASY, TableGenerator.Difficulty.HARD)
 call_deferred("_regenerate", clampi(seed_value, 0, 2147483647), requested)
 return true

func _regenerate(seed_value: int, preference: int) -> void:
 # Validate before touching the active scene; swap outside physics callbacks.
 if not (get_tree().paused or ball.serve_pending):
  generation_pending = false
  status_message = "Generation cancelled because play resumed. Pause and try again."
  return
 var candidate := _generate_layout(seed_value, preference)
 if not candidate.valid:
  status_message = "Generation failed; current table preserved."
  push_error(str(candidate.errors))
  generation_pending = false
  return
 var overlays: Array[bool] = [presentation.physics_overlay.visible, presentation.chunk_overlay.visible, presentation.connector_overlay.visible]
 var camera_preset: int = presentation.camera_preset
 var camera_follow: bool = presentation.camera_follow_enabled
 var camera_settings: Dictionary = presentation.camera_settings.duplicate()
 ball.freeze = true
 ball.position = ball.serve_position
 ball.linear_velocity = Vector2.ZERO
 ball.teleport_to(ball.serve_position, Vector2.ZERO, true)
 presentation.free()
 # Paddles stay put. A shaped lower junction can change the deck's top wall collar.
 var lower: TableChunk = chunks.back()
 var keep_lower_geometry: bool = lower.data.gameplay_descriptors() == candidate.chunks.back().gameplay_descriptors()
 for i in range(chunks.size() - 1):
  chunks[i].free()
 chunks.clear()
 for i in range(flippers.size() - 1, 1, -1):
  flippers[i].free()
  flippers.remove_at(i)
 layout = candidate
 generation_seed = seed_value
 generation_difficulty = preference
 for i in range(layout.chunks.size() - 1):
  chunks.append(_build_chunk(i))
 if keep_lower_geometry:
  lower.data = layout.chunks.back()
 else:
  lower.free()
  lower = _build_chunk(layout.chunks.size() - 1)
 chunks.append(lower)
 for i in range(chunks.size() - 2, -1, -1):
  _add_chunk_flippers(chunks[i])
 _apply_tuning()
 _populate_rings()
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
 _build_presentation()
 presentation.physics_overlay.visible = overlays[0]
 presentation.chunk_overlay.visible = overlays[1]
 presentation.connector_overlay.visible = overlays[2]
 presentation.set_camera_preset(camera_preset)
 for key: String in camera_settings:
  presentation.set_camera_value(key, camera_settings[key])
 presentation.set_camera_follow(camera_follow)
 presentation.reset_camera(ball.serve_position)
 ball.freeze = false
 generation_pending = false
 debug_panel.refresh_generation()
 status_message = "Table ready. Resume if paused, then Enter / X to launch."
 print("TABLE_GENERATED | " + layout.signature + " | fallback=" + str(layout.used_fallback))

func _apply_tuning() -> void:
 for chunk: TableChunk in chunks:
  chunk.wall_material.bounce = tuning.effective.wall_restitution

func launch_ball() -> void:
 if respawn_time > 0 or generation_pending:
  return
 ball.launch()
 auto_launch_time = -1.0
 status_message = "Keep it alive. Time your flips; steer lightly."

func reset_ball(relaunch: bool = false) -> void:
 respawn_time = -1.0
 presentation.clear_ring_pickups()
 ball.teleport_to(ball.serve_position, Vector2.ZERO, true)
 presentation.reset_camera(ball.serve_position)
 ring_field.previous_ball_position = ball.serve_position
 auto_launch_time = 0.25 if relaunch else -1.0
 status_message = "Ready to launch"

func toggle_pause() -> void:
 get_tree().paused = not get_tree().paused

func _on_bumper_hit(body: Node) -> void:
 score += 100
 special_meter = minf(100.0, special_meter + 2.0 * float(tuning.effective.special_meter_charge_multiplier))
 presentation.flash_bumper(body)

func _on_ring_collected(_where: Vector2) -> void:
 score += 25
 rings_collected += 1
 special_meter = minf(100.0, special_meter + 5.0 * float(tuning.effective.special_meter_charge_multiplier))
 var active: int = 0
 for ring: Dictionary in ring_field.rings:
  if ring.active:
   active += 1
 if active == 0:
  score += 500
  ring_reset_time = 1.0
  status_message = "RING RACK CLEARED  +500"

func _physics_process(delta: float) -> void:
 if respawn_time >= 0.0:
  respawn_time -= delta
  if respawn_time <= 0:
   reset_ball(true)
 elif not ball.serve_pending and (ball.position.y > layout.bounds.end.y + 50.0 or ball.position.x < layout.bounds.position.x - 250.0 or ball.position.x > layout.bounds.end.x + 250.0 or ball.position.y < layout.bounds.position.y - 200.0):
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
