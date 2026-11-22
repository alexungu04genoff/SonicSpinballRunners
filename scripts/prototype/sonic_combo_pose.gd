extends MeshInstance3D
## Collisionless character animations at the live Ball.
const Assets = preload("res://experiments/visual_lab/runners_sonic_assets.gd")
const LEGACY_POSE := "res://experiments/visual_lab/local/runtime/sonic_sa1_combo.glb"
const Presenter = preload("res://experiments/visual_lab/sonic_presenter.gd")
const FLIGHT_TURN := PI / 6.0
const DEFAULTS := {"model": 1.0, "ball": 1.0, "blur": 1.0, "speed": Presenter.RUNNERS_ROLL_SPEED, "opacity": 0.30}
var settings := DEFAULTS.duplicate()
var boost_speed := Assets.BOOST_SPEED
var presenter: Node3D
var radius: float
var tricks: Array[Mesh] = []
var trick_index := -1
var runners_roll: MeshInstance3D
var trailing_tails: MeshInstance3D
var tail_time := 0.0
var original_shadow: GeometryInstance3D.ShadowCastingSetting
var character := ""
var sets := {}
var sonic_fallback: Mesh
var motion_rig: Node3D
var motion_player: AnimationPlayer
var motion_fit := {}
var motion_center := Vector3.ZERO
var source_radius := 1.0
var motion: StringName = &""
var motion_direction := Vector2.UP
var boost_remaining := 0.0
var launch_serial := 0
var flight_heading := Vector2.RIGHT
var flying: bool:
 get: return motion == &"flight"
var inspecting := false

func prepare(actor: Node3D, fallback: Texture2D, path := Assets.LOCAL_SET) -> void:
 presenter = actor
 radius = presenter.ball.radius * TablePresentation.SCALE
 set_process(false)
 set_physics_process(false)
 if path == Assets.LOCAL_SET:
  var legacy := Assets.static_meshes(LEGACY_POSE)
  if legacy.size() == 1: sonic_fallback = legacy.values()[0]
 if sonic_fallback == null:
  var material := StandardMaterial3D.new()
  material.albedo_texture = fallback
  material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
  material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
  var quad := QuadMesh.new()
  quad.material = material
  sonic_fallback = quad
 mesh = sonic_fallback
 cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 hide()
 if path != Assets.LOCAL_SET and not FileAccess.file_exists(path): return
 original_shadow = presenter.rolling_mesh.cast_shadow
 presenter.specials.character_changed.connect(_select_roll)
 presenter.specials.flight_started.connect(_start_flight)
 presenter.specials.flight_ended.connect(_end_flight)
 presenter.specials.homing_started.connect(_start_target_boost)
 presenter.specials.homing_ended.connect(_end_target_boost)
 presenter.ball.traversal_launched.connect(_on_traversal_launch)
 presenter.ball.loop_changed.connect(_on_loop_changed)
 presenter.ball.reposition_requested.connect(_stop_motion)
 _select_roll(presenter.character_id, path)

func _select_roll(id: String, sonic_path := Assets.LOCAL_SET) -> void:
 restore_ball()
 if is_instance_valid(runners_roll): runners_roll.hide()
 _stop_motion()
 if trailing_tails: trailing_tails.hide()
 if Assets.BOOST.has(id) and not sets.has(id):
  sets[id] = _load_character(id, sonic_path)
 character = id
 var selected: Dictionary = sets.get(id, {})
 runners_roll = selected.get("roll")
 trailing_tails = selected.get("trailing_tails")
 motion_rig = selected.get("motion_rig")
 motion_player = selected.get("motion_player")
 motion_fit = selected.get("motion_fit", {})
 tricks.assign(selected.get("tricks", []))
 settings = selected.get("settings", DEFAULTS.duplicate())
 trick_index = selected.get("trick_index", -1)
 mesh = tricks[maxi(trick_index, 0)] if not tricks.is_empty() else sonic_fallback
 if runners_roll: runners_roll.show()
 set_process(runners_roll != null)
 _apply_roll_settings()
 _sync_visibility()

func _load_character(id: String, sonic_path: String) -> Dictionary:
 var poses := {}
 if Assets.CURLS.has(id):
  var path := sonic_path if id == "sonic" else "res://experiments/visual_lab/local/runtime/tails_runners_poses.glb"
  poses = Assets.load_set(path, presenter.spin_surface, id)
  if poses.is_empty(): return poses
  presenter.rolling_mesh.add_child(poses.roll)
  poses.trick_index = -1
  poses.motion_fit = poses.roll.mesh.get_meta("bake", {})
  if id == "tails": presenter.spin_root.add_child(poses.trailing_tails)
 elif id == "shadow" and FileAccess.file_exists(Assets.SHADOW_FIT):
  var fit = JSON.parse_string(FileAccess.get_file_as_string(Assets.SHADOW_FIT))
  if fit is Dictionary: poses.motion_fit = fit
 if not poses.has("motion_fit"): return poses
 poses.settings = DEFAULTS.duplicate()
 var rig := Assets.animated_scene(id)
 if not rig: return poses
 var player: AnimationPlayer = rig.find_child("AnimationPlayer", true, false)
 if not player:
  rig.free()
  return poses
 var pivot := Node3D.new()
 pivot.name = "%sMotion" % id.capitalize()
 pivot.hide()
 presenter.add_child(pivot)
 pivot.add_child(rig)
 player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 poses.motion_rig = pivot
 poses.motion_player = player
 return poses

func _apply_roll_settings() -> void:
 var sphere: SphereMesh = presenter.rolling_mesh.mesh
 sphere.radius = radius * float(settings.ball)
 sphere.height = sphere.radius * 2.0
 presenter.roll_speed_scale = float(settings.speed) if Assets.CURLS.has(character) else 1.0
 if runners_roll:
  runners_roll.scale = Vector3.ONE * radius * float(settings.model)
  if trailing_tails: trailing_tails.scale = runners_roll.scale
  presenter.rolling_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  presenter.rolling_mesh.transparency = 1.0 - float(settings.opacity)
  _process(0.0)
 else:
  presenter.rolling_mesh.transparency = 0.0
  presenter.rolling_mesh.cast_shadow = original_shadow

func _process(delta: float) -> void:
 var ball: PlaygroundBall = presenter.ball
 var speed: float = absf(ball.track_speed) if ball.has_track_frame and not ball.serve_pending else presenter.roll_velocity().length()
 var exposure := smoothstep(5.0, 32.0, speed / ball.radius)
 if runners_roll: runners_roll.set_instance_shader_parameter("roll_exposure", exposure * float(settings.blur))
 var elapsed := delta if is_inside_tree() and not get_tree().paused else 0.0
 if trailing_tails and trailing_tails.visible:
  tail_time = fposmod(tail_time + elapsed, Assets.TAIL_WEAVE_DURATION)
  Assets.sample_roll_tails(trailing_tails, tail_time)
 if motion != &"":
  _place_motion()
  motion_player.advance(elapsed)

func _play_motion(kind: StringName, clip: String) -> void:
 if motion_player == null or not motion_player.has_animation(clip):
  _stop_motion()
  return
 var center: Array = motion_fit.get("preview_centers", {}).get(clip, [])
 source_radius = motion_fit.get("runners_source_radius", 0.0)
 if center.size() != 3 or source_radius <= 0.0:
  _stop_motion()
  return
 motion = kind
 if kind in [&"loop", &"target_boost"]: restore_ball()
 motion_center = Vector3(center[0], center[1], center[2])
 motion_rig.get_child(0).position = -motion_center
 if motion_player.current_animation != clip:
  motion_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
  motion_player.play(clip)
  motion_player.advance(0.0)
 Assets.set_playback_speed(motion_player, character, boost_speed)
 _place_motion()
 set_process(true)
 set_physics_process(kind in [&"spring", &"dash_panel"])
 _sync_visibility()

func _on_traversal_launch(kind: StringName, velocity: Vector2) -> void:
 if not motion_rig or presenter.ball.in_loop or motion == &"target_boost": return
 launch_serial = presenter.ball.transfer_serial
 motion_direction = velocity.normalized()
 if kind == &"spring":
  if velocity.y < -0.0001 and Assets.DASH_RING.has(character): _play_motion(kind, Assets.DASH_RING[character])
  else: _stop_motion()
 elif kind == &"dash_panel":
  boost_remaining = 1.0
  _play_motion(kind, Assets.BOOST[character])

func _on_loop_changed(riding: bool) -> void:
 if riding and motion_rig:
  _play_motion(&"loop", Assets.BOOST[character])
 elif motion == &"loop": _stop_motion()

func _physics_process(delta: float) -> void:
 if get_tree().paused: return
 var ball: PlaygroundBall = presenter.ball
 if ball.serve_pending or ball._teleport_pending or ball.transfer_serial != launch_serial:
  _stop_motion()
  return
 if motion == &"dash_panel":
  boost_remaining -= delta
  if boost_remaining <= 0.000001:
   _stop_motion()
   return
 elif motion == &"spring" and (ball.on_ramp or ball.linear_velocity.y >= 0.0):
  _stop_motion()
  return
 if not ball.linear_velocity.is_zero_approx(): motion_direction = ball.linear_velocity.normalized()

func _start_flight() -> void:
 if character != "tails" or flying or presenter.ball.in_loop: return
 flight_heading = initial_flight_heading()
 _play_motion(&"flight", Assets.FLIGHT)

func _start_target_boost(_target: Node2D, direction: Vector2) -> void:
 if motion_rig and presenter.specials.action.kind == TypeAction.Kind.SPEED:
  motion_direction = direction
  _play_motion(&"target_boost", Assets.BOOST[character])

func _end_target_boost(_reason: String) -> void:
 if motion == &"target_boost": _stop_motion()

func initial_flight_heading() -> Vector2:
 var horizontal: float = presenter.roll_heading.x
 return flight_heading if is_zero_approx(horizontal) else Vector2(signf(horizontal), 0)

static func player_facing_basis(camera: Camera3D, steering_side := 0.0) -> Basis:
 return camera.global_basis.orthonormalized() * Basis(Vector3.UP, steering_side * FLIGHT_TURN)

static func flight_lift(half_height: float, ball_radius: float) -> float:
 return maxf(0.0, half_height - ball_radius) + ball_radius * 0.3

static func trick_lift(frame: Basis, bounds: AABB, ball_radius: float) -> float:
 var oriented := Transform3D(frame, Vector3.ZERO) * bounds
 return maxf(0.0, -oriented.position.y - ball_radius * 0.82)

static func spring_basis(camera: Camera3D, at: Vector3, direction: Vector2) -> Basis:
 var view := player_facing_basis(camera)
 var screen := camera.unproject_position(at + TablePresentation.map_point(direction)) - camera.unproject_position(at)
 var elevation := asin(clampf(view.z.y, -1.0, 1.0))
 var facing := view * Basis(Vector3.RIGHT, 0.1 * elevation)
 return facing * Basis(Vector3.BACK, -Vector2.UP.angle_to(screen)) if not screen.is_zero_approx() else facing

func _place_motion() -> void:
 var camera: Camera3D = presenter.table.camera
 var anchor: Vector3 = presenter.spin_root.global_position
 var frame: Basis
 var fit := radius * float(settings.model) / source_radius
 var lift := Vector3.UP * flight_lift(motion_center.y * fit, radius)
 match motion:
  &"spring": frame = spring_basis(camera, anchor, motion_direction)
  &"target_boost", &"dash_panel":
   if motion == &"target_boost" and not presenter.specials.homing_direction.is_zero_approx():
    motion_direction = presenter.specials.homing_direction
   frame = Presenter.flat_roll_frame(motion_direction)
   # The original stride is authored around a floor at local Y = 0.
   lift = Vector3.UP * (motion_center.y * fit - radius)
  &"loop":
   var ball: PlaygroundBall = presenter.ball
   var forwards := -ball.track_frame.z if ball.track_speed >= 0.0 else ball.track_frame.z
   frame = Basis.looking_at(forwards, ball.track_frame.y, true)
   lift = ball.track_frame.y * maxf(0.0, motion_center.y * fit - radius)
  &"flight":
   var steer: float = presenter.ball.controls.steering
   if not is_zero_approx(steer): flight_heading = Vector2(signf(steer), 0)
   frame = player_facing_basis(camera, flight_heading.x)
 motion_rig.global_transform = Transform3D(frame.scaled(Vector3.ONE * fit), anchor + lift)

func _end_flight(_reason: String) -> void:
 if flying: _stop_motion()

func _stop_motion() -> void:
 if motion == &"": return
 motion = &""
 boost_remaining = 0.0
 motion_player.stop()
 set_process(runners_roll != null)
 set_physics_process(false)
 _sync_visibility()

func inspect(enabled: bool) -> void:
 inspecting = enabled
 _sync_visibility()

func _sync_visibility() -> void:
 var regular := not inspecting and not visible
 presenter.rolling_mesh.visible = regular and motion == &""
 if trailing_tails: trailing_tails.visible = presenter.rolling_mesh.visible
 if motion_rig: motion_rig.visible = regular and motion != &""

func apply_settings(values: Dictionary, boost_scale: float) -> void:
 settings.merge(values, true)
 boost_speed = boost_scale
 if motion_player and motion != &"":
  Assets.set_playback_speed(motion_player, character, boost_speed)
 _apply_roll_settings()

func start_trick() -> void:
 if not tricks.is_empty():
  trick_index = (trick_index + 1) % tricks.size()
  sets[character].trick_index = trick_index
  mesh = tricks[trick_index]
 if motion in [&"loop", &"target_boost"]: return
 show()
 _sync_visibility()
 place_trick()

func place_trick() -> void:
 if not visible: return
 var facing := player_facing_basis(presenter.table.camera)
 var model_scale := radius * float(settings.model) if not tricks.is_empty() else radius * 4.4
 var frame := Transform3D(facing.scaled(Vector3.ONE * model_scale), Vector3.ZERO)
 var center: Vector3 = presenter.spin_root.global_position
 # Lift the lowest corner just clear of the surface under the moving Ball.
 frame.origin = center + Vector3.UP * trick_lift(frame.basis, mesh.get_aabb(), radius)
 global_transform = frame

func restore_ball() -> void:
 if not visible: return
 hide()
 _sync_visibility()
