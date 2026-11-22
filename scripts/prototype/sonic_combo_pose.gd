extends MeshInstance3D
## A rigid, camera-facing celebration at the live Ball. The rig is posed offline.
const LOCAL_MESH := "res://experiments/visual_lab/local/runtime/sonic_sa1_combo.glb"
var presenter: Node3D
var radius: float
var active := false

func prepare(actor: Node3D, fallback: Texture2D, path := LOCAL_MESH) -> void:
 mesh = _local_pose(path)
 if mesh == null:
  var material := StandardMaterial3D.new()
  material.albedo_texture = fallback
  material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
  material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
  var quad := QuadMesh.new()
  quad.material = material
  mesh = quad
 presenter = actor
 radius = presenter.ball.radius * TablePresentation.SCALE
 cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 hide()

func _local_pose(path: String) -> ArrayMesh:
 if not FileAccess.file_exists(path): return null
 var document := GLTFDocument.new()
 var state := GLTFState.new()
 var result := document.append_from_file(ProjectSettings.globalize_path(path), state)
 if result != OK or state.get_meshes().size() != 1 or not state.get_skins().is_empty():
  push_warning("Sonic's local combo pose could not be read as a single static mesh.")
  return null
 return state.get_meshes()[0].mesh.get_mesh()

func show_blend(amount: float) -> void:
 # The unfolding mesh emerges from the sphere. Keep both roll bases intact
 # because the track presenter composes them when crossing a Loop boundary.
 active = true
 presenter.rolling_mesh.visible = amount < 0.45
 visible = amount > 0.001
 if not visible: return
 var facing: Basis = presenter.table.camera.global_basis.orthonormalized()
 var height := radius * 4.4 * lerpf(0.22, 1.0, amount)
 var frame := Transform3D(facing.scaled(Vector3.ONE * height), Vector3.ZERO)
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
