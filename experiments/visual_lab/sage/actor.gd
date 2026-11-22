extends Node3D
## The review actor is collisionless. Its parent supplies the table position.
const MODEL := "res://experiments/visual_lab/local/sage-flight-study/game/sage.glb"
const CYBER := preload("res://experiments/visual_lab/sage/cyber_ball.gdshader")
const CORE := preload("res://experiments/visual_lab/sage/cyber_core.gdshader")
const TRANSITION := preload("res://experiments/visual_lab/sage/data_transition.gdshader")
const MORPH_SECONDS := 0.45
const CORE_OPACITY := 0.90
const CLIPS := ["Hover", "Flight", "Boost Hover", "Ring Dash", "Victory Reach", "Victory Guard", "Victory Kick"]
const STEERED := ["Flight", "Boost Hover", "Ring Dash"]
const BALL := "Cyber Ball"
const HEIGHT := 0.736

var rig: Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var sphere: MeshInstance3D
var fragments: Array[MeshInstance3D] = []
var shell := ShaderMaterial.new()
var circuitry := ShaderMaterial.new()
var ball_root: Node3D
var action := "Hover"
var elapsed := 0.0
var heading := 0.0
var rig_clip := "Hover"
var digital_skin: Array[ShaderMaterial] = []
var body: MeshInstance3D
var morph := false
var assembly := 0.0
var morph_from := 0.0
var morph_duration := 0.0
var transform_seconds := MORPH_SECONDS
# The studio's character height is expressed in playfield ball radii.
var ball_radius := HEIGHT / 2.55

func prepare(model_path := MODEL) -> bool:
 var doc := GLTFDocument.new()
 var state := GLTFState.new()
 if doc.append_from_file(ProjectSettings.globalize_path(model_path), state) != OK: return false
 rig = doc.generate_scene(state, 60.0, false, false)
 if not is_instance_valid(rig): return false
 add_child(rig)
 player = rig.find_children("*", "AnimationPlayer", true, false).pop_front()
 skeleton = rig.find_children("*", "Skeleton3D", true, false).pop_front()
 body = rig.find_children("*", "MeshInstance3D", true, false).pop_front()
 if not player or not skeleton or not body or not body.mesh: return false
 for i in body.mesh.get_surface_count():
  var original := body.get_active_material(i) as BaseMaterial3D
  if not original: return false
  var effect := ShaderMaterial.new()
  effect.shader = TRANSITION
  effect.set_shader_parameter("skin_texture",original.albedo_texture)
  if original.emission_texture: effect.set_shader_parameter("glow_texture",original.emission_texture)
  digital_skin.append(effect)
 player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 for clip: String in CLIPS:
  if not player.has_animation(clip): return false
 prepare_ball()
 play("Hover")
 return true

func prepare_ball() -> void:
 ball_root = Node3D.new()
 add_child(ball_root)
 var ball := SphereMesh.new()
 ball.radius = 1.0
 ball.height = 2.0
 ball.radial_segments = 24
 ball.rings = 11
 sphere = MeshInstance3D.new()
 sphere.mesh = ball
 shell.shader = CORE
 shell.set_shader_parameter("opacity", CORE_OPACITY)
 circuitry.shader = CYBER
 circuitry.render_priority = 1
 shell.next_pass = circuitry
 sphere.material_override = shell
 sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 ball_root.add_child(sphere)
 var shard := BoxMesh.new()
 var ink := StandardMaterial3D.new()
 ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 ink.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
 ink.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
 ink.albedo_color = Color("ff355da8")
 ink.render_priority = 1
 for i in 8:
  var square := MeshInstance3D.new()
  square.mesh = shard
  square.material_override = ink
  square.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  fragments.append(square)
  ball_root.add_child(square)

func play(clip: String, transition := false) -> void:
 morph_from = assembly
 var target := 1.0 if clip == BALL else 0.0
 morph_duration = transform_seconds * absf(target - morph_from)
 morph = transition and morph_duration > 0.00001
 action = clip
 elapsed = 0.0
 if clip != BALL:
  rig_clip = clip
  player.play(clip)
  player.advance(0.0)
 sample(0.0)

func steer(side: float) -> void:
 heading = signf(side)

func sample(time: float, pose_time := -1.0) -> void:
 elapsed = time
 if time >= morph_duration: morph = false
 var target := 1.0 if action == BALL else 0.0
 assembly = lerpf(morph_from, target, smoothstep(0.0, morph_duration, time)) if morph else target
 if rig: rig.visible = assembly < 1.0
 ball_root.visible = assembly > 0.0
 for i in digital_skin.size():
  if morph: digital_skin[i].set_shader_parameter("dissolved", assembly)
  var desired: Material = digital_skin[i] if morph else null
  if body.get_surface_override_material(i) != desired: body.set_surface_override_material(i,desired)
 if ball_root.visible:
  ball_root.scale = Vector3.ONE * ball_radius * lerpf(.75,1.0,assembly)
  shell.set_shader_parameter("assembly", assembly)
  shell.set_shader_parameter("clock", time)
  circuitry.set_shader_parameter("assembly", assembly)
  circuitry.set_shader_parameter("clock", time)
  sphere.rotation.z = 0.14 * sin(time * 2.0)
  for i in fragments.size():
   var square := fragments[i]
   var phase := time * (1.1 + 0.14 * i) + TAU * i / fragments.size()
   var height := sin(i * 2.41 + time * 2.3) * 0.65
   var orbit := sqrt(1.0 - height*height) + 0.12 + 0.047*sin(phase*3.0)
   square.position = Vector3(cos(phase) * orbit, height, sin(phase) * orbit)
   square.scale = Vector3(0.15 + 0.08 * sin(phase), 0.042, 0.038) * smoothstep(0.0, 0.5, assembly)
   square.rotation.y = -phase
   square.visible = sin(phase*2.0 + i) > -0.22
 if action != BALL:
  var duration := player.current_animation_length
  if duration > 0.0:
   # Hold the last sample when the user scrubs a looping clip to its endpoint.
   var frame := fposmod(time, duration) if pose_time < 0.0 else clampf(pose_time, 0.0, duration - 0.000001)
   player.seek(frame, true)

func pose_on_table(table_basis: Basis, time: float) -> void:
 var lift := Vector3.ZERO
 if not rig_clip.begins_with("Victory"):
  lift = Vector3.UP * ball_radius * (0.65 + 0.10 * sin(time * TAU / 1.6))
 var yaw := deg_to_rad(30.0) * heading if rig_clip in STEERED else 0.0
 rig.transform = Transform3D(table_basis * Basis(Vector3.UP, yaw), lift - table_basis.y * HEIGHT * 0.5)
