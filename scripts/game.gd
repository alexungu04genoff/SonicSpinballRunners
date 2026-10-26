extends Node
## Owns run state and wiring. Physics, input, resources, and rendering remain independent.
var tuning: PhysicsTuning
var controls: PlaygroundInput
var world: Node2D
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
var previous_goal_position := Vector2.ZERO
var _goal_motion_ready := false
var loading_act: bool = false
var view: SubViewport
var camera_input_container: SubViewportContainer
const Playfield = preload("res://scripts/playfield_data.gd")
const ActDocument = preload("res://scripts/act_editor/act_geometry.gd")
const ActCompiler = preload("res://scripts/authored_act/act_runtime_compiler.gd")
const ActLifecycle = preload("res://scripts/authored_act/act_lifecycle.gd")
var playfield: PlayfieldData
var authored_act_path := "res://data/endless/second_simple.tres"
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
 var initial_authored := _prepare_initial_act()
 if not initial_authored.error.is_empty():
  _fail_startup(initial_authored.error)
  return
 authored_document = initial_authored.document
 authored_runtime = initial_authored.runtime
 playfield = Playfield.from_authored(authored_document, authored_runtime)
 ball.serve_position = playfield.spawn
 ball.position = ball.serve_position
 world.add_child(ball)
 ball.teleport_to(ball.position, Vector2.ZERO, true)
 _authored_root = authored_runtime.get("root")
 if _authored_root != null:
  world.add_child(_authored_root)
  authored_runtime.mechanics.scoring_tick.connect(_on_mechanic_score)
  flippers.assign(authored_runtime.flippers)
 ring_field = RingField.new()
 ring_field.name = "Rings"
 ring_field.ball = ball
 ring_field.tuning = tuning
 ring_field.previous_ball_position = ball.position
 add_child(ring_field)
 _populate_rings()
 specials = CharacterSpecials.new()
 specials.game = self
 add_child(specials)
 specials.character_changed.connect(func(_id: String): scorecraft.reset("Character changed", true))
 specials.select_character(character_id)
 previous_goal_position = ball.serve_position
 var presentation_started := Time.get_ticks_usec()
 _build_view()
 var presentation_ms := (Time.get_ticks_usec() - presentation_started) / 1000.0
 _build_debug_panel()
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
 if _authored_root != null:
  call_deferred("_record_authored_timing", initial_authored, presentation_ms)
 print("ACT_ENGINE_READY | Godot %s | 120 Hz | 2D collisions / 3D presentation" % Engine.get_version_info().string)

func _prepare_initial_act() -> Dictionary:
 return _prepare_authored(authored_act_path)

func _build_debug_panel() -> void:
 debug_panel = PlaygroundDebugPanel.new()
 debug_panel.name = "DebugAndHUD"
 debug_panel.game = self
 debug_panel.tuning = tuning
 add_child(debug_panel)

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

func _populate_rings() -> void:
 var started := Time.get_ticks_usec()
 ring_field.rings.clear()
 ring_field.previous_ball_position = ball.serve_position
 ring_field.ring_radius = float(authored_document.cell_size) * preload("res://scripts/act_dimensions.gd").RING_RADIUS_CELLS
 for point: Vector2 in playfield.ring_positions:
  ring_field.add_ring(point)
 _ring_population_ms = (Time.get_ticks_usec() - started) / 1000.0

func _unhandled_input(event: InputEvent) -> void:
 if not event is InputEventMouse or not is_instance_valid(presentation) or controls.input_blocked or loading_act:
  return
 var container := camera_input_container
 var local: Vector2 = container.get_global_transform_with_canvas().affine_inverse() * event.position
 if not Rect2(Vector2.ZERO, container.size).has_point(local):
  return
 var mapped := event.duplicate() as InputEventMouse
 var scale := Vector2(view.size) / container.size
 mapped.position = local * scale
 if mapped is InputEventMouseMotion:
  mapped.relative = (container.get_global_transform_with_canvas().basis_xform_inv(event.relative)) * scale
 if presentation.handle_overview_input(mapped):
  get_viewport().set_input_as_handled()

func _build_view() -> void:
 var container := SubViewportContainer.new()
 camera_input_container = container
 container.name = "TableView"
 # Reserve space for the Act summary and physics controls.
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
 presentation.build_authored(authored_runtime, playfield.bounds, float(authored_document.cell_size))
 presentation.set_camera_follow(true)
 _add_playfield_feedback()

func _rebuild_presentation() -> void:
 presentation.flippers = flippers
 presentation.rebuild_playfield(playfield)
 _add_playfield_feedback()

func _add_playfield_feedback() -> void:
 _add_area_feedback()
 var feedback := CharacterFeedback.new()
 feedback.game = self
 presentation.add_child(feedback)

func _add_area_feedback() -> void:
 var area := AreaSpecialFeedback.new()
 area.game = self
 presentation.add_child(area)

func can_reload_act() -> bool:
 return not loading_act and (get_tree().paused or (ball.serve_pending and not ball.release_pending))

func _source_settings_valid(settings: Dictionary) -> bool:
 if not CharacterSpecials.CHARACTERS.has(settings.get("character", character_id)):
  status_message = "Unknown character; current run preserved."
  return false
 if settings.has("chao") and not PhysicsTuning.CHAO.has(settings.chao):
  status_message = "Unknown Chao; current run preserved."
  return false
 return true

func request_authored_act(path: String, settings: Dictionary = {}) -> bool:
 if not _source_settings_valid(settings):
  return false
 if not can_reload_act():
  status_message = "Pause before loading an Act, or wait at serve."
  return false
 loading_act = true
 call_deferred("_load_authored_act", path, settings.duplicate())
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

func _load_authored_act(path: String, settings: Dictionary) -> void:
 if not (get_tree().paused or (ball.serve_pending and not ball.release_pending)):
  loading_act = false
  status_message = "Level load cancelled because play resumed."
  return
 var prepared := _prepare_authored(path)
 if not prepared.error.is_empty():
  last_source_error = prepared.error
  status_message = "Cannot load Act: " + last_source_error
  loading_act = false
  return
 authored_act_path = path
 last_source_error = ""
 _replace_playfield(prepared, settings)

func _record_authored_timing(prepared: Dictionary, presentation_ms: float) -> void:
 authored_timings = {"load_ms": prepared.load_ms, "terrain_ms": prepared.runtime.timings.terrain_ms,
  "objects_ms": prepared.runtime.timings.objects_ms, "rings_ms": _ring_population_ms, "presentation_ms": presentation_ms,
  "total_ms": (Time.get_ticks_usec() - int(prepared.started)) / 1000.0}
 print("AUTHORED_MAIN_READY | Load %.2f ms | Terrain %.2f ms | Objects %.2f ms | Rings %.2f ms | Presentation %.2f ms | Ready %.2f ms" % [authored_timings.load_ms, authored_timings.terrain_ms, authored_timings.objects_ms, authored_timings.rings_ms, authored_timings.presentation_ms, authored_timings.total_ms])

func request_replay(settings: Dictionary = {}) -> bool:
 return request_authored_act(authored_act_path, settings)

func _replace_playfield(prepared: Dictionary, settings: Dictionary) -> void:
 last_source_error = ""
 scorecraft.reset("New run", true)
 scorecraft_enabled = bool(settings.get("combos", scorecraft_enabled))
 scorecraft.enabled = scorecraft_enabled
 var requested_character: String = settings.get("character", character_id)
 if requested_character != character_id:
  specials.select_character(requested_character)
 else:
  specials.reset(true, "New run")
 ball.freeze = true
 ball.linear_velocity = Vector2.ZERO
 _clear_playfield_geometry()
 authored_document = prepared.document
 authored_runtime = prepared.runtime
 _authored_root = authored_runtime.root
 world.add_child(_authored_root)
 authored_runtime.mechanics.scoring_tick.connect(_on_mechanic_score)
 flippers.assign(authored_runtime.flippers)
 playfield = Playfield.from_authored(authored_document, authored_runtime)
 if settings.has("chao"):
  tuning.equip_chao(settings.chao)
 ball.serve_position = playfield.spawn
 ball.teleport_to(ball.serve_position, Vector2.ZERO, true)
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
 _target_awards.clear()
 authored_activation_count = 0
 authored_exit_count = 0
 previous_goal_position = ball.serve_position
 _goal_motion_ready = false
 var presentation_started := Time.get_ticks_usec()
 _rebuild_presentation()
 presentation.reset_camera(ball.serve_position)
 var presentation_ms := (Time.get_ticks_usec() - presentation_started) / 1000.0
 ball.freeze = false
 loading_act = false
 if is_instance_valid(debug_panel): debug_panel.refresh_act()
 status_message = "Act ready. Resume if paused, then Enter / X to launch."
 _record_authored_timing(prepared, presentation_ms)

func _clear_playfield_geometry() -> void:
 flippers.clear()
 if is_instance_valid(_authored_root):
  _authored_root.free()
 _authored_root = null

func _apply_tuning() -> void:
 for body: StaticBody2D in playfield.terrain_bodies:
  if is_instance_valid(body) and body.physics_material_override != null and not is_equal_approx(body.physics_material_override.bounce, tuning.effective.wall_restitution):
   body.physics_material_override.bounce = tuning.effective.wall_restitution

func launch_ball() -> void:
 if respawn_time > 0 or loading_act:
  return
 ball.launch()
 auto_launch_time = -1.0
 status_message = "Keep it alive. Time your flips; steer lightly."

func reset_ball(relaunch: bool = false) -> void:
 specials.reset(false, "Reset")
 scorecraft.reset("Reset", true)
 respawn_time = -1.0
 previous_goal_position = ball.serve_position
 _goal_motion_ready = false
 presentation.clear_ring_pickups()
 ball.teleport_to(ball.serve_position, Vector2.ZERO, true)
 presentation.reset_camera(ball.serve_position)
 ring_field.previous_ball_position = ball.serve_position
 auto_launch_time = 0.25 if relaunch else -1.0
 status_message = "Ready to launch"

func toggle_debug() -> void:
 if not is_instance_valid(debug_panel): return
 debug_panel.panel.visible = not debug_panel.panel.visible
 debug_panel.act_panel.visible = debug_panel.panel.visible
 get_viewport().gui_release_focus()

func toggle_pause() -> void:
 get_tree().paused = not get_tree().paused

func _on_mechanic_score(_object_id: String, points: int) -> void:
 if respawn_time >= 0.0 or loading_act or ball.serve_pending: return
 score += scorecraft.award_spinner(points)

func _on_bumper_hit(body: Node) -> void:
 var impact: bool = specials.impact_target == body
 _award_bumper(body, "shockwave" if impact else "", specials.definition.shockwave_multiplier if impact else 1, true)

func scoring_target_eligible(body: Node2D) -> bool:
 if not is_instance_valid(body) or not body.has_meta("bumper") or respawn_time >= 0.0 or loading_act:
  return false
 return true

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
 return true

func _on_ring_collected(_where: Vector2, source: String = "", multiplier: int = 1) -> void:
 if respawn_time >= 0.0 or loading_act:
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

func _physics_process(delta: float) -> void:
 if not is_instance_valid(ball) or loading_act:
  return
 if respawn_time >= 0.0:
  respawn_time -= delta
  if respawn_time <= 0:
   reset_ball(true)
 elif not ball.serve_pending and not ball._teleport_pending and _at_playfield_drain():
  ball_number += 1
  respawn_time = 0.65
  if is_instance_valid(ball.mechanics): ball.mechanics.reset()
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
 if ball.on_ramp: _goal_motion_ready = false
 if not ball.on_ramp and not ball.serve_pending and not ball._teleport_pending and respawn_time < 0.0:
  var start := previous_goal_position if _goal_motion_ready else ball.position
  _observe_authored_motion(start, ball.position)
  _goal_motion_ready = true
 else:
  _goal_motion_ready = false
 previous_goal_position = ball.position
 if ball.serve_pending or ball._teleport_pending:
  previous_goal_position = ball.serve_position
  _goal_motion_ready = true

func _observe_authored_motion(start: Vector2, finish: Vector2) -> void:
 var events: Dictionary = ActLifecycle.crossings(authored_document, start, finish)
 if events.activation:
  authored_activation_count += 1
  print("ACT ACTIVATED | upward crossing ", authored_activation_count)
 if events.exit:
  authored_exit_count += 1
  print("ACT EXIT REACHED | upward crossing ", authored_exit_count)

func _at_playfield_drain() -> bool:
 return ball.position.y >= authored_document.red_gutter_bounds().end.y
