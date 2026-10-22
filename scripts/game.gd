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
 for resource: ChunkData in [preload("res://data/upper_chunk.tres"), preload("res://data/lower_chunk.tres")]:
  var chunk := TableChunk.new()
  chunk.data = resource
  chunk.name = "UpperChunk" if chunks.is_empty() else "LowerChunk"
  world.add_child(chunk)
  chunk.build()
  chunks.append(chunk)
 ball = PlaygroundBall.new()
 ball.name = "PlayerPhysics"
 ball.serve_position = chunks[1].get_node("serve").global_position
 ball.position = ball.serve_position
 ball.tuning = tuning
 ball.controls = controls
 world.add_child(ball)
 ball.teleport_to(ball.position, Vector2.ZERO, true)
 for side: int in [1, -1]:
  var flipper := PlaygroundFlipper.new()
  flipper.name = "LeftFlipper" if side > 0 else "RightFlipper"
  flipper.side = float(side)
  flipper.position = chunks[1].get_node("left_flipper" if side > 0 else "right_flipper").global_position
  flipper.ball = ball
  flipper.controls = controls
  flipper.tuning = tuning
  world.add_child(flipper)
  flippers.append(flipper)
 ring_field = RingField.new()
 ring_field.name = "Rings"
 ring_field.ball = ball
 ring_field.tuning = tuning
 ring_field.previous_ball_position = ball.position
 add_child(ring_field)
 for chunk: TableChunk in chunks:
  for descriptor: Dictionary in chunk.descriptors:
   if descriptor.kind == "ring":
    ring_field.add_ring(descriptor.position)
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
  get_viewport().gui_release_focus()
 )
 controls.special_requested.connect(func(): status_message = "Special reserved for Phase 2 — meter is ready for abilities")
 ball.bumper_hit.connect(_on_bumper_hit)
 ring_field.collected.connect(_on_ring_collected)
 tuning.changed.connect(_apply_tuning)
 _apply_tuning()
 print("PLAYGROUND_READY | Godot %s | 120 Hz | 2D collisions / 3D presentation | 2 connected chunks" % Engine.get_version_info().string)

func _build_view() -> void:
 var container := SubViewportContainer.new()
 container.name = "TableView"
 container.position = Vector2(0, 85)
 container.size = Vector2(870, 750)
 container.stretch = true
 container.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(container)
 var viewport := SubViewport.new()
 viewport.name = "Collisionless3DViewport"
 viewport.size = Vector2i(870, 750)
 viewport.own_world_3d = true
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 container.add_child(viewport)
 presentation = TablePresentation.new()
 presentation.name = "Presentation"
 presentation.ball = ball
 presentation.flippers = flippers
 presentation.ring_field = ring_field
 viewport.add_child(presentation)
 presentation.build(chunks)

func _apply_tuning() -> void:
 for chunk: TableChunk in chunks:
  chunk.wall_material.bounce = tuning.effective.wall_restitution

func launch_ball() -> void:
 if respawn_time > 0:
  return
 ball.launch()
 auto_launch_time = -1.0
 status_message = "Keep it alive. Time your flips; steer lightly."

func reset_ball(relaunch: bool = false) -> void:
 respawn_time = -1.0
 ball.teleport_to(ball.serve_position, Vector2.ZERO, true)
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
 elif not ball.serve_pending and (ball.position.y > 1450.0 or absf(ball.position.x - 400.0) > 650.0 or ball.position.y < -200.0):
  ball_number += 1
  respawn_time = 0.65
  status_message = "DRAIN — automatic respawn"
 if auto_launch_time >= 0:
  auto_launch_time -= delta
  if auto_launch_time <= 0:
   launch_ball()
 if ring_reset_time >= 0:
  ring_reset_time -= delta
  if ring_reset_time <= 0:
   ring_field.reset_rings()
