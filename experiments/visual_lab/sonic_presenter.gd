extends Node3D
## Collisionless character adapter. Only observations flow from the 2D simulation.
# Keep state/pose hooks and the local model pipeline for future art refinement.
const BALL_FORM_ONLY := true
const MODEL_PATH := "res://experiments/visual_lab/local/runtime/sonic.glb"
const MODEL_PATHS := {
 "sonic": MODEL_PATH,
 "tails": "res://experiments/visual_lab/local/runtime/tails.glb",
}
const POSE_NAMES := ["roll", "idle", "jump", "trick", "homing", "impact", "fly"]
enum State { SPIN, JUMP, TRICK, SHOWCASE, HOMING, IMPACT, FLIGHT }
var specials: CharacterSpecials
var character_id := "sonic"
var spin_material: StandardMaterial3D
var spin_surface: ShaderMaterial
var target_marker: Node3D
var flight_wind: MeshInstance3D
var homing_direction := Vector2.UP
var _aim_angle := 0.0
var _special_heading_active := false
const MAX_LEAN_DEGREES := 23.0
const LEAN_DEAD_ZONE := 45.0
const LEAN_FULL_SPEED := 650.0
const LEAN_RESPONSE := 10.0
const UNCURL_BLEND_TIME := 0.12
const POSE_HEIGHT := 0.40
const MODEL_CENTER_HEIGHT := 0.50
const EVENT_COOLDOWN := 0.18
var state: int = State.SPIN
var lean_angle := 0.0
var uncurl_amount := 0.0
var model_alignment: Node3D
var _event_duration := 0.0
var _event_cooldown := 0.0
var ball: PlaygroundBall
var table: TablePresentation
var upright: Node3D
var spin_root: Node3D
var marker: Node3D
var model: Node3D
var animation_player: AnimationPlayer
var close_camera: Camera3D
var study_root: Node3D
var study_origin: Vector3
## Diagnostics can omit this optional island; the main game keeps the same study UI.
var study_enabled := true
var model_available := false
var model_status := "Local Sonic asset not prepared"
var pose := "roll"
var preview := ""
var preview_roll := false
var event_pose := ""
var event_time := 0.0
var close_view := false
var capture_hold := false
var _last_position := Vector2.INF
var _pose_time := 0.0
var _clips: Dictionary = {}
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
 model = null
 animation_player = null
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
 upright = Node3D.new()
 upright.name = "UncurledVisualAnchor"
 add_child(upright)
 # Body placement and board-plane lean never inherit the procedural ball spin.
 model_alignment = Node3D.new()
 model_alignment.name = "ImportedModelAxisAlignment"
 upright.add_child(model_alignment)
 _load_model()
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
 var contact := table.mesh_node(ring, table.material(Color("fff2a7"), 0.2), Vector3(0, 0.009, 0), marker)
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

func _load_model() -> void:
 if is_instance_valid(model):
  model.get_parent().remove_child(model)
  model.queue_free()
 model = null
 animation_player = null
 model_available = false
 _clips.clear()
 if BALL_FORM_ONLY:
  model_status = character_id.capitalize() + " · ball form · animation states retained"
  return
 model_status = "Local %s asset not prepared" % character_id.capitalize()
 if not MODEL_PATHS.has(character_id):
  model_status = character_id.capitalize() + " · colored prototype ball"
  return
 if OS.get_cmdline_user_args().has("--no-model"):
  model_status = "Spin-ball fallback (local model disabled)"
  return
 var absolute := ProjectSettings.globalize_path(MODEL_PATHS.get(character_id, MODEL_PATH))
 if not FileAccess.file_exists(absolute):
  push_warning(model_status + ": " + absolute)
  return
 var document := GLTFDocument.new()
 var state := GLTFState.new()
 var result := document.append_from_file(absolute, state)
 if result != OK:
  model_status = "%s GLB could not be loaded (%s)" % [character_id.capitalize(), error_string(result)]
  push_warning(model_status)
  return
 model = document.generate_scene(state)
 if model == null:
  model_status = character_id.capitalize() + " GLB contained no scene"
  return
 model.name = "Imported" + character_id.capitalize()
 model_alignment.add_child(model)
 model_available = true
 _inspect_import(model)
 if animation_player != null:
  animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
  for clip: StringName in animation_player.get_animation_list():
   var lower := String(clip).to_lower()
   for desired: String in ["idle", "jump", "trick", "homing", "impact", "fly"]:
    if lower == desired or lower.ends_with("/" + desired) or lower.ends_with("_" + desired):
     _clips[desired] = clip
     animation_player.get_animation(clip).loop_mode = Animation.LOOP_NONE if desired == "impact" else Animation.LOOP_LINEAR
  print("VISUAL_LAB_ANIMATIONS | ", animation_player.get_animation_list())
 model_status = "%s · Sonic Runners model · %d pose clips" % [character_id.capitalize(), _clips.size()]
 print("VISUAL_LAB_MODEL_READY | ", model_status)

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
 _load_model()
 _apply_character_color()
 if close_view:
  select_preview("idle")

func _on_homing_started(_target: Node2D, direction: Vector2) -> void:
 homing_direction = direction.normalized()
 _special_heading_active = true
 # The imported head points along table -Z. Only yaw changes the aim;
 # imported front remains aligned with the board normal at every angle.
 _aim_angle = atan2(-homing_direction.x, -homing_direction.y)
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
 _event_duration = event_time
 _set_pose("impact", true)
 _pulse(Color("e1faff"))

func _on_flight_started() -> void:
 if close_view:
  return
 _special_heading_active = false
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

func _inspect_import(node: Node) -> void:
 if node is AnimationPlayer and animation_player == null:
  animation_player = node
 # Imported decoration must never add a second collision authority.
 for child: Node in node.get_children():
  if child is CollisionObject3D or child is Camera3D or child is Light3D:
   child.queue_free()
  else:
   _inspect_import(child)

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
 _special_heading_active = false
 state = State.SPIN
 lean_angle = 0.0
 uncurl_amount = 0.0
 _event_cooldown = 0.0
 _event_duration = 0.0
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
 _special_heading_active = false
 event_pose = value
 event_time = maxf(duration, UNCURL_BLEND_TIME * 2.0)
 _event_duration = event_time
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
 if animation_player != null and _clips.has(value):
  animation_player.play(_clips[value], 0.045 if value in ["homing", "impact"] else UNCURL_BLEND_TIME)
  animation_player.advance(0.0)

func seek_pose(seconds: float) -> void:
 capture_hold = true
 if animation_player != null and _clips.has(pose):
  animation_player.stop()
  animation_player.play(_clips[pose], 0.0)
  animation_player.advance(0.0)
  animation_player.seek(seconds, true)

func _update_pose_transform(delta: float) -> void:
 var anchor := study_origin if close_view else TablePresentation.map_point(ball.position)
 if close_view:
  uncurl_amount = 0.0 if pose == "roll" or (model_available and not _clips.has(pose)) else 1.0
  lean_angle = 0.0
  upright.rotation = Vector3(0, 0.15, 0)
  model_alignment.rotation = Vector3.ZERO
  if model_available:
   model.position = Vector3.ZERO
  upright.position = anchor + Vector3.UP * 0.025
  upright.scale = Vector3.ONE
 else:
  var target_uncurl := 1.0 if (not model_available or _clips.has(pose)) and state in [State.JUMP, State.TRICK, State.HOMING, State.IMPACT, State.FLIGHT] else 0.0
  var blend_time := 0.055 if state == State.HOMING else UNCURL_BLEND_TIME
  uncurl_amount = move_toward(uncurl_amount, target_uncurl, delta / blend_time)
  var horizontal_speed := absf(ball.linear_velocity.x)
  var lean_strength := clampf((horizontal_speed - LEAN_DEAD_ZONE) / (LEAN_FULL_SPEED - LEAN_DEAD_ZONE), 0.0, 1.0)
  var target_lean := -signf(ball.linear_velocity.x) * deg_to_rad(MAX_LEAN_DEGREES) * lean_strength
  lean_angle = lerpf(lean_angle, target_lean, 1.0 - exp(-LEAN_RESPONSE * delta))
  # Only yaw around the board normal is trajectory-dependent. Descending never
  # reverses the head/feet axis, and yaw cannot tilt the model through the board.
  upright.rotation = Vector3(0, _aim_angle if _special_heading_active and uncurl_amount > 0.001 else lean_angle, 0)
  # Imported +Y (head) -> table -Z; imported +Z (face) -> board +Y.
  model_alignment.rotation = Vector3(-PI * 0.5, 0, 0)
  if model_available:
   model.position = Vector3(0, -MODEL_CENTER_HEIGHT, 0)
  var progress := clampf(1.0 - event_time / maxf(_event_duration, 0.001), 0.0, 1.0)
  var hop := sin(progress * PI) * (0.12 if state == State.JUMP else (0.06 if state in [State.TRICK, State.IMPACT] else 0.0))
  upright.position = anchor + Vector3.UP * lerpf(TablePresentation.BALL_HEIGHT + 0.025, POSE_HEIGHT + hop, uncurl_amount)
  upright.scale = Vector3.ONE * 0.85 * lerpf(0.25, 1.0, uncurl_amount)
 var ball_scale := 1.0 if close_view or table.authored_mode else 1.12
 # A short scale overlap suggests uncurl/re-curl without tumbling the upright rig.
 spin_root.scale = Vector3.ONE * ball_scale * (1.0 if BALL_FORM_ONLY or not model_available else maxf(0.001, 1.0 - uncurl_amount))
 spin_root.position = anchor + Vector3.UP * (table.ball_height() if table.authored_mode else TablePresentation.BALL_HEIGHT + 0.025)
 upright.visible = not BALL_FORM_ONLY and model_available and uncurl_amount > 0.001
 spin_root.visible = BALL_FORM_ONLY or not model_available or uncurl_amount < 0.999
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
 if animation_player != null and _clips.has(pose) and animation_delta > 0.0:
  animation_player.advance(animation_delta)
 _update_pose_transform(physics_delta)
 # Keep the curled animation spinning at the apex as well as during travel.
 # The smoothed board-plane axis avoids sudden tumbles when velocity reverses.
 if not close_view and not ball.serve_pending and not capture_hold:
  _advance_spin(physics_delta, ball.linear_velocity)
 if close_view and (BALL_FORM_ONLY or pose == "roll") and not capture_hold:
  spin_root.rotate(Vector3(1, 0, 0.5).normalized(), delta * 22.0)
 _update_effects(physics_delta)
 _last_position = ball.position
 var focus := spin_root.position if BALL_FORM_ONLY else upright.position + Vector3(0.0, 0.52, 0.0)
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
