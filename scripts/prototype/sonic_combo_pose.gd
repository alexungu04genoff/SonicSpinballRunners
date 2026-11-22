extends MeshInstance3D
## Collisionless roll, trick and flight visuals at the live Ball.
const Assets = preload("res://experiments/visual_lab/runners_sonic_assets.gd")
const LEGACY_POSE := "res://experiments/visual_lab/local/runtime/sonic_sa1_combo.glb"
const Presenter = preload("res://experiments/visual_lab/sonic_presenter.gd")
const DEFAULTS := {"model": 1.0, "ball": 1.0, "blur": 1.0, "speed": Presenter.RUNNERS_ROLL_SPEED, "opacity": 0.30}
var settings := DEFAULTS.duplicate()
var presenter: Node3D
var radius: float
var active := false
var tricks: Array[Mesh] = []
var trick_index := -1
var runners_roll: MeshInstance3D
var trailing_tails: MeshInstance3D
var original_shadow: GeometryInstance3D.ShadowCastingSetting
var character := ""
var sets := {}
var sonic_fallback: Mesh
var flight: Node3D
var flight_player: AnimationPlayer
var flight_center := Vector3.ZERO
var flight_source_radius := 1.0
var flight_heading := Vector2.RIGHT
var flying := false
var inspecting := false
var replacing_roll := false

func prepare(actor: Node3D, fallback: Texture2D, path := Assets.LOCAL_SET) -> void:
 presenter = actor
 radius = presenter.ball.radius * TablePresentation.SCALE
 set_process(false)
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
 _select_roll(presenter.character_id, path)

func _select_roll(id: String, sonic_path := Assets.LOCAL_SET) -> void:
 if is_instance_valid(runners_roll): runners_roll.hide()
 if flying: _end_flight("Character changed")
 if trailing_tails: trailing_tails.hide()
 if Assets.CURLS.has(id) and not sets.has(id):
  var path := sonic_path if id == "sonic" else "res://experiments/visual_lab/local/runtime/tails_runners_poses.glb"
  var poses := Assets.load_set(path, presenter.spin_surface, id)
  sets[id] = poses
  if not poses.is_empty():
   presenter.rolling_mesh.add_child(poses.roll)
   poses.settings = DEFAULTS.duplicate()
   poses.trick_index = -1
   if id == "tails":
    presenter.spin_root.add_child(poses.trailing_tails)
    _load_flight(poses.roll.mesh)
 character = id
 var selected: Dictionary = sets.get(id, {})
 runners_roll = selected.get("roll")
 trailing_tails = selected.get("trailing_tails")
 tricks.assign(selected.get("tricks", []))
 settings = selected.get("settings", DEFAULTS.duplicate())
 trick_index = selected.get("trick_index", -1)
 mesh = tricks[maxi(trick_index, 0)] if not tricks.is_empty() else sonic_fallback
 if runners_roll: runners_roll.show()
 set_process(runners_roll != null)
 _apply_roll_settings()
 _sync_visibility()

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
 var speed := absf(ball.track_speed) if ball.has_track_frame else ball.linear_velocity.length()
 var exposure := 0.0 if ball.serve_pending else smoothstep(5.0, 32.0, speed / ball.radius)
 runners_roll.set_instance_shader_parameter("roll_exposure", exposure * float(settings.blur))
 if trailing_tails and trailing_tails.visible: Assets.sample_roll_tails(trailing_tails, presenter.roll_angle)
 if flying:
  _place_flight()
  if is_inside_tree() and not get_tree().paused: flight_player.advance(delta)

func _load_flight(curl: Mesh) -> void:
 var bake: Dictionary = curl.get_meta("bake", {})
 var center: Array = bake.get("preview_centers", {}).get(Assets.FLIGHT, [])
 flight_source_radius = bake.get("runners_source_radius", 0.0)
 if center.size() != 3 or flight_source_radius <= 0.0: return
 var rig := Assets.animated_scene("tails")
 if rig == null: return
 flight_player = rig.find_child("AnimationPlayer", true, false)
 if flight_player == null or not flight_player.has_animation(Assets.FLIGHT):
  rig.free()
  flight_player = null
  return
 flight_center = Vector3(center[0], center[1], center[2])
 flight = Node3D.new()
 flight.name = "TailsFlight"
 flight.hide()
 presenter.add_child(flight)
 flight.add_child(rig)
 rig.position = -flight_center
 flight_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 flight_player.get_animation(Assets.FLIGHT).loop_mode = Animation.LOOP_LINEAR

func _start_flight() -> void:
 if character != "tails" or flight == null or flying: return
 flying = true
 flight_heading = initial_flight_heading()
 flight_player.play(Assets.FLIGHT)
 flight_player.advance(0.0)
 _place_flight()
 _sync_visibility()

func initial_flight_heading() -> Vector2:
 var horizontal: float = presenter.roll_heading.x
 return flight_heading if is_zero_approx(horizontal) else Vector2(signf(horizontal), 0)

func _place_flight() -> void:
 var steer: float = presenter.ball.controls.steering
 if not is_zero_approx(steer): flight_heading = Vector2(signf(steer), 0)
 var fit := radius * float(settings.model) / flight_source_radius
 var frame: Basis = presenter.flat_roll_frame(flight_heading)
 var lift := maxf(0.0, flight_center.y * fit - radius) + radius * 0.3
 flight.transform = Transform3D(frame.scaled(Vector3.ONE * fit), presenter.spin_root.position + Vector3.UP * lift)

func _end_flight(_reason: String) -> void:
 if not flying: return
 flying = false
 flight_player.stop()
 _sync_visibility()

func inspect(enabled: bool) -> void:
 inspecting = enabled
 _sync_visibility()

func _sync_visibility() -> void:
 var regular := not inspecting and not replacing_roll
 presenter.rolling_mesh.visible = regular and not flying
 if trailing_tails: trailing_tails.visible = regular and not flying
 if flight: flight.visible = regular and flying

func apply_settings(values: Dictionary) -> void:
 settings.merge(values, true)
 _apply_roll_settings()

func next_trick() -> void:
 if tricks.is_empty(): return
 trick_index = (trick_index + 1) % tricks.size()
 sets[character].trick_index = trick_index
 mesh = tricks[trick_index]

func show_blend(amount: float) -> void:
 # The unfolding mesh emerges from the sphere. Keep both roll bases intact
 # because the track presenter composes them when crossing a Loop boundary.
 active = true
 replacing_roll = amount >= 0.45
 _sync_visibility()
 visible = replacing_roll if not tricks.is_empty() else amount > 0.001
 if not visible: return
 var facing: Basis = presenter.table.camera.global_basis.orthonormalized()
 # Original Runners meshes all use the curl's source units. Opening the
 # pose changes its silhouette, never its character scale, even on entry.
 var model_scale := radius * float(settings.model) if not tricks.is_empty() else radius * 4.4 * lerpf(0.22, 1.0, amount)
 var frame := Transform3D(facing.scaled(Vector3.ONE * model_scale), Vector3.ZERO)
 var bounds := frame * mesh.get_aabb()
 var center: Vector3 = presenter.spin_root.global_position
 # Lift the lowest corner just clear of the surface under the moving Ball.
 frame.origin = center + Vector3.UP * maxf(0.0, -bounds.position.y - radius * 0.82)
 global_transform = frame

func restore_ball() -> void:
 if not active: return
 active = false
 hide()
 if is_instance_valid(presenter) and is_instance_valid(presenter.rolling_mesh):
  replacing_roll = false
  _sync_visibility()
