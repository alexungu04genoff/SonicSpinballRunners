extends MeshInstance3D
## Collisionless character animations at the live Ball.
const Assets = preload("res://experiments/visual_lab/runners_sonic_assets.gd")
const LEGACY_POSE := "res://experiments/visual_lab/local/runtime/sonic_sa1_combo.glb"
const Presenter = preload("res://experiments/visual_lab/sonic_presenter.gd")
const ShellFade = preload("res://experiments/visual_lab/round_shell_fade.gd")
const FLIGHT_TURN := PI / 6.0
const TRICK_TURN := PI / 6.0
const DEFAULTS := {"model": 1.0, "ball": 1.0, "blur": 1.0, "speed": Presenter.RUNNERS_ROLL_SPEED, "opacity": 0.45}
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
var shell_fade := ShellFade.new()
var action_shell: MeshInstance3D

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
 action_shell = MeshInstance3D.new()
 action_shell.name = "ActionTransitionShell"
 action_shell.mesh = presenter.rolling_mesh.mesh
 action_shell.material_override = presenter.spin_surface
 action_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 action_shell.hide()
 presenter.add_child(action_shell)
 original_shadow = presenter.rolling_mesh.cast_shadow
 presenter.specials.character_changed.connect(_select_roll)
 presenter.specials.flight_started.connect(_start_flight)
 presenter.specials.flight_ended.connect(_end_flight)
 presenter.specials.homing_started.connect(_start_target_boost)
 presenter.specials.homing_ended.connect(_end_target_boost)
 presenter.specials.smash_started.connect(_start_smash)
 presenter.specials.smash_diving.connect(_dive_smash)
 presenter.specials.smash_ended.connect(_stop_motion)
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
 var markings: Texture2D = selected.get("shell_markings")
 presenter.spin_surface.set_shader_parameter("use_shell_markings", markings != null)
 presenter.spin_surface.set_shader_parameter("runners_shell", markings)
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
 _sync_visibility(false)

func _load_character(id: String, sonic_path: String) -> Dictionary:
 var poses := {}
 if Assets.CURLS.has(id):
  var path := sonic_path if id == "sonic" else "res://experiments/visual_lab/local/runtime/%s_runners_poses.glb" % id
  poses = Assets.load_set(path, presenter.spin_surface, id)
  if poses.is_empty(): return poses
  presenter.rolling_mesh.add_child(poses.roll)
  poses.trick_index = -1
  poses.motion_fit = poses.roll.mesh.get_meta("bake", {})
  if id == "tails": presenter.spin_root.add_child(poses.trailing_tails)
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
 if shell_fade.elapsed < ShellFade.DURATION:
  shell_fade.advance(elapsed)
  _draw_shell()
 if trailing_tails and trailing_tails.visible:
  tail_time = fposmod(tail_time + elapsed, Assets.TAIL_WEAVE_DURATION)
  Assets.sample_roll_tails(trailing_tails, tail_time)
 if motion != &"":
  motion_player.advance(elapsed)
  _place_motion()

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
 if motion_player.current_animation != clip:
  motion_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
  Assets.start_clip(motion_rig, motion_player, clip)
 Assets.set_playback_speed(motion_player, character, boost_speed)
 _place_motion()
 set_process(true)
 set_physics_process(kind in [&"spring", &"dash_panel"])
 _sync_visibility()

func _on_traversal_launch(kind: StringName, velocity: Vector2) -> void:
 if not motion_rig or presenter.ball.in_loop or motion == &"target_boost" or presenter.specials.smash_remaining > 0.0: return
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
 if not Assets.FLIGHT_CLIPS.has(character) or flying or presenter.ball.in_loop: return
 flight_heading = initial_flight_heading()
 _play_motion(&"flight", Assets.FLIGHT_CLIPS[character])

func _start_target_boost(_target: Node2D, direction: Vector2) -> void:
 if motion_rig and presenter.specials.action.kind == TypeAction.Kind.SPEED:
  motion_direction = direction
  _play_motion(&"target_boost", Assets.BOOST[character])

func _end_target_boost(_reason: String) -> void:
 if motion == &"target_boost": _stop_motion()

func _start_smash() -> void:
 restore_ball()
 _stop_motion()

func _dive_smash() -> void:
 if motion_rig and Assets.POWER_DIVE.has(character):
  _play_motion(&"smash", Assets.POWER_DIVE[character])

static func smash_basis(heading: Vector2) -> Basis:
 return Presenter.flat_roll_frame(heading) * Basis(Vector3.RIGHT, PI / 2.0)

func smash_lift(scale_factor: float) -> float:
 # At zero jump height the leading glove meets the surface below the Ball.
 var curl_radius: float = motion_fit.runners_source_radius
 return float(motion_fit.get("slam_front", curl_radius)) * radius * scale_factor / curl_radius - radius

func initial_flight_heading() -> Vector2:
 var horizontal: float = presenter.roll_heading.x
 return flight_heading if is_zero_approx(horizontal) else Vector2(signf(horizontal), 0)

static func player_facing_basis(camera: Camera3D, steering_side := 0.0) -> Basis:
 return camera.global_basis.orthonormalized() * Basis(Vector3.UP, steering_side * FLIGHT_TURN)

static func flight_lift(half_height: float, ball_radius: float) -> float:
 return maxf(0.0, half_height - ball_radius) + ball_radius * 0.3

static func spring_basis(camera: Camera3D, at: Vector3, direction: Vector2) -> Basis:
 var view := player_facing_basis(camera)
 var screen := camera.unproject_position(at + TablePresentation.map_point(direction)) - camera.unproject_position(at)
 var elevation := asin(clampf(view.z.y, -1.0, 1.0))
 var facing := view * Basis(Vector3.RIGHT, 0.1 * elevation)
 return facing * Basis(Vector3.BACK, -Vector2.UP.angle_to(screen)) if not screen.is_zero_approx() else facing

func _place_motion() -> void:
 motion_center = Assets.pose_center(motion_fit, motion_player)
 var camera: Camera3D = presenter.table.camera
 var anchor: Vector3 = presenter.spin_root.global_position
 var frame: Basis
 var fit := radius * float(settings.model) / source_radius
 var lift := Vector3.UP * flight_lift(motion_center.y * fit, radius)
 match motion:
  &"smash":
   frame = smash_basis(presenter.roll_heading)
   lift = Vector3.UP * smash_lift(float(settings.model))
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
 var yaw := flight_heading.x * FLIGHT_TURN if flying else atan2(frame.z.x, frame.z.z)
 motion_rig.get_child(0).position = -Assets.pose_center(motion_fit, motion_player, yaw)
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
 _sync_visibility(false)

func _sync_visibility(animate := true) -> void:
 var regular := not inspecting and not visible
 var rolling := regular and motion == &""
 if not animate or inspecting or (is_inside_tree() and get_tree().paused): shell_fade.elapsed = ShellFade.DURATION
 elif runners_roll and presenter.rolling_mesh.visible != rolling:
  var base := float(settings.opacity)
  shell_fade.start(shell_fade.opacity(base if presenter.rolling_mesh.visible else 0.0, base))
 presenter.rolling_mesh.visible = rolling
 if trailing_tails: trailing_tails.visible = presenter.rolling_mesh.visible
 if motion_rig: motion_rig.visible = regular and motion != &""
 _draw_shell()

func _draw_shell() -> void:
 if not action_shell: return
 if not runners_roll:
  action_shell.hide()
  return
 var rolling: bool = presenter.rolling_mesh.visible
 var base := float(settings.opacity)
 var opacity := shell_fade.opacity(base if rolling else 0.0, base)
 presenter.rolling_mesh.transparency = 1.0 - (opacity if rolling else base)
 action_shell.visible = not inspecting and not rolling and opacity > 0.0
 if action_shell.visible:
  action_shell.global_transform = presenter.rolling_mesh.global_transform
  action_shell.transparency = 1.0 - opacity

func finish_shell_fade() -> void:
 shell_fade.elapsed = ShellFade.DURATION
 _draw_shell()

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
 if motion in [&"loop", &"target_boost"] or presenter.specials.smash_remaining > 0.0: return
 show()
 _sync_visibility()
 place_trick(0.0)

static func trick_basis(camera: Camera3D, progress: float) -> Basis:
 # Give each endpoint a visible beat even on the shortest combo.
 var angle := lerpf(-TRICK_TURN, TRICK_TURN, smoothstep(1.0 / 6.0, 5.0 / 6.0, progress))
 return player_facing_basis(camera) * Basis(Vector3.UP, angle)

func place_trick(progress: float) -> void:
 if not visible: return
 var model_scale := radius * float(settings.model) if not tricks.is_empty() else radius * 4.4
 var facing := trick_basis(presenter.table.camera, progress)
 global_transform = Transform3D(facing.scaled(Vector3.ONE * model_scale), presenter.spin_root.global_position)

func restore_ball() -> void:
 if not visible: return
 hide()
 _sync_visibility()
