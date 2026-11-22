extends MeshInstance3D
## A rigid, camera-facing celebration at the live Ball. The rig is posed offline.
const Assets = preload("res://experiments/visual_lab/runners_sonic_assets.gd")
const LEGACY_POSE := "res://experiments/visual_lab/local/runtime/sonic_sa1_combo.glb"
const SHELL_REST_OPACITY := 0.14
const SHELL_SPIN_OPACITY := 0.30
const DEFAULTS := {"model": 1.0, "ball": 1.0, "blur": 1.0, "speed": 1.0, "opacity": SHELL_SPIN_OPACITY}
var settings := DEFAULTS.duplicate()
var presenter: Node3D
var radius: float
var active := false
var tricks: Array[Mesh] = []
var trick_index := -1
var runners_roll: MeshInstance3D
var original_shadow: GeometryInstance3D.ShadowCastingSetting

func prepare(actor: Node3D, fallback: Texture2D, path := Assets.LOCAL_SET) -> void:
 presenter = actor
 radius = presenter.ball.radius * TablePresentation.SCALE
 set_process(false)
 var poses := Assets.load_set(path, presenter.spin_surface)
 if not poses.is_empty():
  runners_roll = poses.roll
  runners_roll.scale = Vector3.ONE * radius
  original_shadow = presenter.rolling_mesh.cast_shadow
  presenter.rolling_mesh.add_child(runners_roll)
  presenter.specials.character_changed.connect(_select_roll)
  _select_roll(presenter.character_id)
  tricks = poses.tricks
  mesh = tricks[0]
 if mesh == null and path == Assets.LOCAL_SET:
  var legacy := Assets.static_meshes(LEGACY_POSE)
  if legacy.size() == 1: mesh = legacy.values()[0]
 if mesh == null:
  var material := StandardMaterial3D.new()
  material.albedo_texture = fallback
  material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
  material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
  var quad := QuadMesh.new()
  quad.material = material
  mesh = quad
 cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 hide()

func _select_roll(id: String) -> void:
 runners_roll.visible = id == "sonic"
 var sphere: SphereMesh = presenter.rolling_mesh.mesh
 sphere.radius = radius * (float(settings.ball) if runners_roll.visible else 1.0)
 sphere.height = sphere.radius * 2.0
 presenter.roll_speed_scale = float(settings.speed) if runners_roll.visible else 1.0
 runners_roll.scale = Vector3.ONE * radius * float(settings.model)
 set_process(runners_roll.visible)
 if runners_roll.visible:
  presenter.rolling_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  _process(0.0)
 else:
  presenter.rolling_mesh.transparency = 0.0
  presenter.rolling_mesh.cast_shadow = original_shadow

func _process(_delta: float) -> void:
 var ball: PlaygroundBall = presenter.ball
 var speed := absf(ball.track_speed) if ball.has_track_frame else ball.linear_velocity.length()
 var exposure := 0.0 if ball.serve_pending else smoothstep(5.0, 32.0, speed / ball.radius)
 # The existing painted sphere and its opaque curled child share the roll pivot.
 presenter.rolling_mesh.transparency = 1.0 - float(settings.opacity) * lerpf(SHELL_REST_OPACITY / SHELL_SPIN_OPACITY, 1.0, exposure)
 runners_roll.set_instance_shader_parameter("roll_exposure", exposure * float(settings.blur))

func apply_settings(values: Dictionary) -> void:
 settings.merge(values, true)
 if is_instance_valid(runners_roll): _select_roll(presenter.character_id)

func next_trick() -> void:
 if tricks.is_empty(): return
 trick_index = (trick_index + 1) % tricks.size()
 mesh = tricks[trick_index]

func show_blend(amount: float) -> void:
 # The unfolding mesh emerges from the sphere. Keep both roll bases intact
 # because the track presenter composes them when crossing a Loop boundary.
 active = true
 presenter.rolling_mesh.visible = amount < 0.45
 visible = not presenter.rolling_mesh.visible if not tricks.is_empty() else amount > 0.001
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
  presenter.rolling_mesh.show()
