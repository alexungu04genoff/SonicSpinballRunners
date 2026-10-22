extends Node3D
## Collisionless character adapter. Only observations flow from the 2D simulation.
const MODEL_PATH := "res://experiments/visual_lab/local/runtime/sonic.glb"
const POSE_NAMES := ["roll", "idle", "jump", "trick"]
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
var model_available := false
var model_status := "Local Sonic asset not prepared"
var pose := "idle"
var preview := ""
var preview_roll := false
var event_pose := ""
var event_time := 0.0
var close_view := false
var capture_hold := false
var _last_position := Vector2.INF
var _pose_time := 0.0
var _clips: Dictionary = {}

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 spin_root = Node3D.new()
 spin_root.name = "RollingVisualOnly"
 add_child(spin_root)
 var blue := table.material(Color("075dd2"), 0.05)
 blue.roughness = 0.38
 table.mesh_node(table.sphere(0.17), blue, Vector3.ZERO, spin_root)
 var stripe := TorusMesh.new()
 stripe.inner_radius = 0.167
 stripe.outer_radius = 0.175
 stripe.rings = 24
 stripe.ring_segments = 8
 var streak := table.mesh_node(stripe, table.material(Color("68caff"), 0.28), Vector3.ZERO, spin_root)
 streak.rotation.z = 0.5
 var second := table.mesh_node(stripe, table.material(Color("c9ecff"), 0.12), Vector3.ZERO, spin_root)
 second.rotation.x = 1.1
 upright = Node3D.new()
 upright.name = "UprightCharacterOnly"
 add_child(upright)
 # Keep this root separate from RollingVisualOnly. It never inherits ball spin.
 upright.rotation.y = -0.20
 _load_model()
 marker = Node3D.new()
 marker.name = "AuthoritativeBallContactMarker"
 add_child(marker)
 var disk := CylinderMesh.new()
 disk.top_radius = 0.22
 disk.bottom_radius = 0.22
 disk.height = 0.004
 disk.radial_segments = 32
 var shadow := table.material(Color(0.015, 0.055, 0.03, 0.42))
 shadow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 shadow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 var disk_visual := table.mesh_node(disk, shadow, Vector3.ZERO, marker)
 disk_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var ring := TorusMesh.new()
 ring.inner_radius = PlaygroundBall.RADIUS * TablePresentation.SCALE
 ring.outer_radius = ring.inner_radius + 0.018
 ring.rings = 32
 ring.ring_segments = 8
 var contact := table.mesh_node(ring, table.material(Color("fff2a7"), 0.2), Vector3(0, 0.009, 0), marker)
 contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 study_origin = Vector3(table.table_bounds.end.x * TablePresentation.SCALE + 4.0, 0.9, table.table_bounds.end.y * TablePresentation.SCALE - 3.0)
 study_root = Node3D.new()
 study_root.name = "PausedCharacterStudy"
 add_child(study_root)
 if table.has_method("build_study"):
  table.call("build_study", study_root, study_origin)
 else:
  study_root.position = study_origin
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
 _set_pose("idle", true)
 _process(0.0)

func _load_model() -> void:
 var absolute := ProjectSettings.globalize_path(MODEL_PATH)
 if not FileAccess.file_exists(absolute):
  push_warning(model_status + ": " + absolute)
  return
 var document := GLTFDocument.new()
 var state := GLTFState.new()
 var result := document.append_from_file(absolute, state)
 if result != OK:
  model_status = "Sonic GLB could not be loaded (%s)" % error_string(result)
  push_warning(model_status)
  return
 model = document.generate_scene(state)
 if model == null:
  model_status = "Sonic GLB contained no scene"
  return
 model.name = "ImportedSonic"
 upright.add_child(model)
 model_available = true
 _inspect_import(model)
 if animation_player != null:
  animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
  for clip: StringName in animation_player.get_animation_list():
   var lower := String(clip).to_lower()
   for desired: String in ["idle", "jump", "trick"]:
    if lower == desired or lower.ends_with("/" + desired) or lower.ends_with("_" + desired):
     _clips[desired] = clip
     animation_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
  print("VISUAL_LAB_ANIMATIONS | ", animation_player.get_animation_list())
 model_status = "Sonic Runners model · %d pose clips" % _clips.size()
 print("VISUAL_LAB_MODEL_READY | ", model_status)

func _inspect_import(node: Node) -> void:
 if node is AnimationPlayer and animation_player == null:
  animation_player = node
 # Imported decoration must never add a second collision authority.
 for child: Node in node.get_children():
  if child is CollisionObject3D or child is Camera3D or child is Light3D:
   child.queue_free()
  else:
   _inspect_import(child)

func select_preview(value: String) -> void:
 preview = "" if value == "roll" else value
 preview_roll = value == "roll"
 event_pose = ""
 event_time = 0.0
 _set_pose(value, true)

func show_event(value: String, duration: float) -> void:
 if not preview.is_empty() or close_view:
  return
 event_pose = value
 event_time = duration
 _set_pose(value, true)

func set_close_view(enabled: bool) -> void:
 close_view = enabled
 study_root.visible = enabled
 close_camera.current = enabled
 if enabled and preview.is_empty():
  select_preview("idle")
 if not enabled:
  table.camera.current = true

func _set_pose(value: String, restart: bool = false) -> void:
 if pose == value and not restart:
  return
 pose = value
 _pose_time = 0.0
 if animation_player != null and _clips.has(value):
  animation_player.play(_clips[value], 0.12)
  animation_player.advance(0.0)
 upright.visible = value != "roll" and model_available
 spin_root.visible = value == "roll" or not model_available

func seek_pose(seconds: float) -> void:
 capture_hold = true
 if animation_player != null and _clips.has(pose):
  animation_player.stop()
  animation_player.play(_clips[pose], 0.0)
  animation_player.advance(0.0)
  animation_player.seek(seconds, true)

func _process(delta: float) -> void:
 if not is_instance_valid(ball):
  return
 var physics_delta := 0.0 if get_tree().paused else delta
 if event_time > 0.0:
  event_time = maxf(0.0, event_time - physics_delta)
 if preview.is_empty():
  _set_pose(event_pose if event_time > 0.0 else ("idle" if ball.serve_pending and not preview_roll else "roll"))
 elif pose != preview:
  _set_pose(preview)
 var animation_delta := delta if not preview.is_empty() else physics_delta
 if capture_hold:
  animation_delta = 0.0
 _pose_time += animation_delta
 if animation_player != null and _clips.has(pose) and animation_delta > 0.0:
  animation_player.advance(animation_delta)
 var anchor := study_origin if close_view else TablePresentation.map_point(ball.position)
 upright.position = anchor + Vector3.UP * 0.025
 upright.rotation.y = 0.15 if close_view else -0.20
 spin_root.position = anchor + Vector3.UP * (TablePresentation.BALL_HEIGHT + 0.025)
 marker.position = TablePresentation.map_point(ball.position, 0.015)
 # A visual hop never moves the 2D body, contact marker, or ring pickup target.
 if pose == "jump" and not capture_hold:
  upright.position.y += 0.06 * sin(minf(_pose_time * 3.0, PI))
 var travel := ball.position - _last_position
 if _last_position != Vector2.INF and travel.length() > 0.001 and travel.length() < 100.0:
  spin_root.rotate(Vector3(travel.y, 0, -travel.x).normalized(), travel.length() / PlaygroundBall.RADIUS)
 if close_view and pose == "roll" and not capture_hold:
  spin_root.rotate(Vector3(1, 0, 0.5).normalized(), delta * 4.5)
 _last_position = ball.position
 var focus := upright.position + Vector3(0.0, 0.52, 0.0)
 close_camera.position = focus + Vector3(0.65, 0.65, 2.4)
 close_camera.look_at(focus)
