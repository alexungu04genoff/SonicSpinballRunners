extends Node3D
## Collisionless character adapter. Only observations flow from the 2D simulation.
enum State { SPIN, JUMP, TRICK, SHOWCASE, HOMING, IMPACT, FLIGHT }
var specials: CharacterSpecials
var character_id := "sonic"
var spin_material: StandardMaterial3D
var spin_surface: ShaderMaterial
var target_marker: Node3D
var flight_wind: MeshInstance3D
var homing_direction := Vector2.UP
const MIN_EVENT_DURATION := 0.24
const EVENT_COOLDOWN := 0.18
var state: int = State.SPIN
var _event_cooldown := 0.0
var ball: PlaygroundBall
var table: TablePresentation
var spin_root: Node3D
var marker: Node3D
var close_camera: Camera3D
var study_root: Node3D
var study_origin: Vector3
## Diagnostics can omit this optional island; the main game keeps the same study UI.
var study_enabled := true
var pose := "roll"
var preview := ""
var preview_roll := false
var event_pose := ""
var event_time := 0.0
var close_view := false
var capture_hold := false
var _last_position := Vector2.INF
var _pose_time := 0.0
const MotionTrail = preload("res://experiments/visual_lab/motion_trail.gd")
var trail: MeshInstance3D
var _spin_axis := Vector3.RIGHT
var pulse: MeshInstance3D
var pulse_material: StandardMaterial3D
var pulse_time := 0.0
var _bound_flippers: Array[PlaygroundFlipper] = []

func _ready() -> void:
 _build_visuals()

func refresh_playfield() -> void:
 # Keep this presenter and its shared gameplay observers; only the cosmetic
 # children and listeners on replaceable paddle bodies depend on the playfield.
 resume_gameplay()
 for flipper: PlaygroundFlipper in _bound_flippers:
  if is_instance_valid(flipper) and flipper.struck.is_connected(_on_flipper_struck):
   flipper.struck.disconnect(_on_flipper_struck)
 _bound_flippers.clear()
 for child: Node in get_children():
  remove_child(child)
  child.free()
 _last_position = Vector2.INF
 close_view = false
 _build_visuals()

func _connect_once(signal_value: Signal, callback: Callable) -> void:
 if not signal_value.is_connected(callback):
  signal_value.connect(callback)

func _build_visuals() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 if is_instance_valid(specials):
  character_id = specials.character_id
 spin_root = Node3D.new()
 spin_root.name = "RollingVisualOnly"
 add_child(spin_root)
 spin_material = table.material(Color("075dd2"), 0.05)
 spin_material.roughness = 0.38
 var spin_radius := ball.radius * TablePresentation.SCALE if table.authored_mode else 0.17
 spin_surface = ShaderMaterial.new()
 spin_surface.shader = preload("res://experiments/visual_lab/spin_ball.gdshader")
 var sphere := table.sphere(spin_radius)
 sphere.radial_segments = 32
 sphere.rings = 16
 table.mesh_node(sphere, spin_surface, Vector3.ZERO, spin_root)
 marker = Node3D.new()
 marker.name = "AuthoritativeBallContactMarker"
 add_child(marker)
 var disk := CylinderMesh.new()
 disk.top_radius = spin_radius * 1.3 if table.authored_mode else 0.22
 disk.bottom_radius = disk.top_radius
 disk.height = 0.004
 disk.radial_segments = 32
 var shadow := table.material(Color(0.015, 0.055, 0.03, 0.42))
 shadow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 shadow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 var disk_visual := table.mesh_node(disk, shadow, Vector3.ZERO, marker)
 disk_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var ring := TorusMesh.new()
 ring.inner_radius = ball.radius * TablePresentation.SCALE
 ring.outer_radius = ring.inner_radius + (spin_radius * 0.12 if table.authored_mode else 0.018)
 ring.rings = 32
 ring.ring_segments = 8
 var contact := table.mesh_node(ring, table.material(Color.WHITE, 0.2), Vector3(0, 0.009, 0), marker)
 contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 study_origin = Vector3(table.table_bounds.end.x * TablePresentation.SCALE + 4.0, 0.9, table.table_bounds.end.y * TablePresentation.SCALE - 3.0)
 study_root = Node3D.new()
 study_root.name = "PausedCharacterStudy"
 add_child(study_root)
 if not study_enabled:
  # Low-level diagnostics have no character study UI.
  study_root.position = study_origin
 elif table.has_method("build_study"):
  table.call("build_study", study_root, study_origin)
 else:
  study_root.position = study_origin
 if study_enabled:
  var study_shadow := table.mesh_node(disk, shadow, Vector3(0, 0.014, 0), study_root)
  study_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 study_root.visible = false
 close_camera = Camera3D.new()
 close_camera.name = "CharacterInspectionCamera"
 close_camera.fov = 34.0
 close_camera.near = 0.02
 close_camera.far = 100.0
 add_child(close_camera)
 table.ball_visual.visible = false
 _build_effects()
 _apply_character_color()
 if is_instance_valid(specials):
  _connect_once(specials.character_changed, _on_character_changed)
  _connect_once(specials.homing_started, _on_homing_started)
  _connect_once(specials.homing_ended, _on_homing_ended)
  _connect_once(specials.special_hit, _on_special_hit)
  _connect_once(specials.flight_started, _on_flight_started)
  _connect_once(specials.flight_ended, _on_flight_ended)
 # Persistent gameplay signals connect once. Refresh disconnects old paddle
 # listeners before binding the current set, including retained bottom paddles.
 _connect_once(ball.bumper_hit, _on_bumper_hit)
 for flipper: PlaygroundFlipper in table.flippers:
  _connect_once(flipper.struck, _on_flipper_struck)
  _bound_flippers.append(flipper)
 _connect_once(table.ring_field.pickup_claimed, _on_ring_claimed)
 _set_pose("roll", true)
 _process(0.0)

func _apply_character_color() -> void:
 var tails := character_id == "tails"
 spin_material.albedo_color = Color("f28b17") if tails else Color("075dd2")
 if character_id not in ["sonic", "tails"]:
  spin_material.albedo_color = CharacterSpecials.CHARACTERS[character_id].ball_color
 spin_surface.set_shader_parameter("fur_color", spin_material.albedo_color)
 spin_surface.set_shader_parameter("character_style", ["sonic", "tails", "knuckles", "shadow"].find(character_id))
 var character_color: Color = CharacterSpecials.CHARACTERS[character_id].color
 trail.tint = Color.from_hsv(character_color.h, 0.92, 0.95)
 if character_id == "sonic":
  trail.tint = Color("2635f5")
 trail.reset()

func _on_character_changed(id: String) -> void:
 if character_id == id:
  return
 character_id = id
 resume_gameplay()
 _apply_character_color()
 if close_view:
  select_preview("idle")

func _on_homing_started(_target: Node2D, direction: Vector2) -> void:
 homing_direction = direction.normalized()
 if close_view:
  return
 state = State.HOMING
 event_time = 0.0
 _set_pose("homing", true)
 _pulse(Color("80dbff"))

func _on_homing_ended(_reason: String) -> void:
 if state == State.HOMING:
  state = State.SPIN

func _on_special_hit(_target: Node2D, _multiplier: int) -> void:
 if close_view:
  return
 state = State.IMPACT
 event_pose = "impact"
 event_time = 0.28
 _set_pose("impact", true)
 _pulse(Color("e1faff"))

func _on_flight_started() -> void:
 if close_view:
  return
 state = State.FLIGHT
 event_time = 0.0
 _set_pose("fly", true)
 _pulse(Color("ffd38a"))

func _on_flight_ended(_reason: String) -> void:
 if state == State.FLIGHT:
  state = State.SPIN

func _sync_special_state() -> void:
 if not is_instance_valid(specials):
  return
 # Read-only recovery after a presentation rebuild or leaving character study.
 if specials.homing_remaining > 0.0 and specials.homing_direction != Vector2.ZERO:
  if state != State.HOMING:
   _on_homing_started(specials.pending_target, specials.homing_direction)
 elif specials.flight_remaining > 0.0:
  if state != State.FLIGHT:
   _on_flight_started()
 elif state in [State.HOMING, State.FLIGHT]:
  state = State.SPIN

func _build_effects() -> void:
 var effect_scale := ball.radius / PlaygroundBall.RADIUS if table.authored_mode else 1.0
 trail = MotionTrail.new()
 trail.radius = ball.radius * TablePresentation.SCALE if table.authored_mode else 0.17 * 1.12
 add_child(trail)
 var hoop := TorusMesh.new()
 hoop.inner_radius = 0.23 * effect_scale
 hoop.outer_radius = 0.255 * effect_scale
 hoop.rings = 32
 hoop.ring_segments = 8
 pulse_material = table.material(Color("fff4b0"))
 pulse_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 pulse_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 pulse = table.mesh_node(hoop, pulse_material, Vector3.ZERO, self)
 pulse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 pulse.visible = false
 target_marker = Node3D.new()
 target_marker.name = "AuthoritativeHomingTarget"
 add_child(target_marker)
 var target_mat := table.material(Color("b7f1ff"), 0.6)
 target_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 var target_ring := table.mesh_node(hoop, target_mat, Vector3.ZERO, target_marker)
 target_ring.scale = Vector3.ONE * 1.65
 for i in 4:
  var tick := BoxMesh.new()
  tick.size = Vector3(0.12, 0.02, 0.025) * effect_scale
  var angle := i * PI * 0.5
  var tick_node := table.mesh_node(tick, target_mat, Vector3(cos(angle), 0, sin(angle)) * 0.48 * effect_scale, target_marker)
  tick_node.rotation.y = -angle
 var wind_mat := table.material(Color(1.0, 0.76, 0.35, 0.45), 0.2)
 wind_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 wind_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 flight_wind = table.mesh_node(hoop, wind_mat, Vector3.ZERO, self)
 flight_wind.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 flight_wind.visible = false
 target_marker.visible = false

func _pulse(color: Color) -> void:
 pulse_time = 0.32
 pulse_material.albedo_color = color

func _on_flipper_struck() -> void:
 show_event("jump", 0.62)
 _pulse(Color("92eaff"))

func _on_bumper_hit(_body: Node) -> void:
 show_event("trick", 0.56)
 _pulse(Color("fff2ae"))

func _on_ring_claimed(_index: int) -> void:
 _pulse(Color("ffd52f"))

func resume_gameplay() -> void:
 state = State.SPIN
 _event_cooldown = 0.0
 preview = ""
 preview_roll = false
 event_pose = ""
 event_time = 0.0
 capture_hold = false
 trail.reset()
 pulse_time = 0.0
 _set_pose("roll", true)

func _update_effects(delta: float) -> void:
 if close_view or ball.serve_pending or ball.position.distance_to(_last_position) > 100.0:
  trail.reset()
 else:
  trail.advance(delta, spin_root.position, ball.linear_velocity.length() > 260.0, table.camera)
 pulse_time = maxf(0.0, pulse_time - delta)
 pulse.visible = pulse_time > 0.0 and not close_view
 pulse.position = marker.position + Vector3.UP * 0.025
 pulse.scale = Vector3.ONE * (1.0 + (1.0 - pulse_time / 0.32) * 1.8)
 pulse_material.albedo_color.a = clampf(pulse_time / 0.20, 0.0, 1.0)
 var chosen: Node2D = null
 if is_instance_valid(specials) and not close_view and not ball.serve_pending:
  chosen = specials.pending_target if state == State.HOMING else specials.target
 target_marker.visible = is_instance_valid(chosen) and not chosen.is_queued_for_deletion()
 if target_marker.visible:
  target_marker.position = TablePresentation.map_point(chosen.global_position, 0.07)
 flight_wind.visible = state == State.FLIGHT and not close_view
 flight_wind.position = marker.position + Vector3.UP * 0.04
 flight_wind.scale = Vector3.ONE * (1.55 + sin(_pose_time * TAU * 2.0) * 0.12)

func select_preview(value: String) -> void:
 preview = "" if value == "roll" else value
 preview_roll = value == "roll"
 event_pose = ""
 event_time = 0.0
 _set_pose(value, true)
 _update_pose_transform(0.0)

func show_event(value: String, duration: float) -> void:
 if close_view or state in [State.HOMING, State.IMPACT, State.FLIGHT] or value not in ["jump", "trick"]:
  return
 # Repeated contact callbacks never rewind or prolong an active reaction.
 # Different reactions may take over after a short, presentation-only cooldown.
 if _event_cooldown > 0.0 or (event_time > 0.0 and event_pose == value):
  return
 event_pose = value
 event_time = maxf(duration, MIN_EVENT_DURATION)
 _event_cooldown = EVENT_COOLDOWN
 state = State.JUMP if value == "jump" else State.TRICK
 _set_pose(value, true)

func set_close_view(enabled: bool) -> void:
 close_view = enabled
 study_root.visible = enabled
 close_camera.current = enabled
 if enabled:
  state = State.SHOWCASE
  if preview.is_empty():
   select_preview("idle")
 else:
  resume_gameplay()
  table.camera.current = true
 _process(0.0)

func _set_pose(value: String, restart: bool = false) -> void:
 if pose == value and not restart:
  return
 pose = value
 _pose_time = 0.0

func seek_pose(_seconds: float) -> void:
 capture_hold = true

func _update_pose_transform(_delta: float) -> void:
 var anchor := study_origin if close_view else TablePresentation.map_point(ball.position)
 var ball_scale := 1.0 if close_view or table.authored_mode else 1.12
 spin_root.scale = Vector3.ONE * ball_scale
 spin_root.position = anchor + Vector3.UP * (table.ball_height() if table.authored_mode else TablePresentation.BALL_HEIGHT + 0.025)
 spin_root.visible = true
 marker.position = TablePresentation.map_point(ball.position, 0.015)

func _process(delta: float) -> void:
 if not is_instance_valid(ball):
  return
 var physics_delta := 0.0 if get_tree().paused else delta
 _event_cooldown = maxf(0.0, _event_cooldown - physics_delta)
 if close_view:
  state = State.SHOWCASE
  _set_pose("roll" if preview_roll else (preview if not preview.is_empty() else "idle"))
 else:
  event_time = maxf(0.0, event_time - physics_delta)
  if state in [State.JUMP, State.TRICK, State.IMPACT] and event_time <= 0.0:
   state = State.SPIN
  _sync_special_state()
  if ball.serve_pending:
   state = State.SPIN
  match state:
   State.HOMING: _set_pose("homing")
   State.FLIGHT: _set_pose("fly")
   State.JUMP, State.TRICK, State.IMPACT: _set_pose(event_pose)
   _: _set_pose("roll")
 var animation_delta := delta if close_view else physics_delta
 if capture_hold:
  animation_delta = 0.0
 _pose_time += animation_delta
 _update_pose_transform(physics_delta)
 # Keep the curled animation spinning at the apex as well as during travel.
 # The smoothed board-plane axis avoids sudden tumbles when velocity reverses.
 if not close_view and not ball.serve_pending and not capture_hold:
  _advance_spin(physics_delta, ball.linear_velocity)
 if close_view and not capture_hold:
  spin_root.rotate(Vector3(1, 0, 0.5).normalized(), delta * 22.0)
 _update_effects(physics_delta)
 _last_position = ball.position
 var focus := spin_root.position
 close_camera.position = focus + Vector3(0.65, 0.65, 2.4)
 close_camera.look_at(focus)

func _advance_spin(delta: float, velocity: Vector2) -> void:
 if delta <= 0.0:
  return
 if velocity.length() > 45.0:
  var axis := Vector3(velocity.y, 0, -velocity.x).normalized()
  # A roll axis is unsigned; preserve its hemisphere across the jump apex.
  if axis.dot(_spin_axis) < 0.0:
   axis = -axis
  var weight := 1.0 - exp(-8.0 * delta)
  # Nearly parallel axes have an ill-conditioned cross product in Vector3.slerp.
  # Use normalized linear interpolation there to avoid invalid-axis log spam.
  _spin_axis = (_spin_axis.lerp(axis, weight) if _spin_axis.dot(axis) > 0.9999 else _spin_axis.slerp(axis, weight)).normalized()
 var angular_speed := clampf(velocity.length() / ball.radius, 22.0, 36.0)
 spin_root.rotate(_spin_axis, angular_speed * delta)
