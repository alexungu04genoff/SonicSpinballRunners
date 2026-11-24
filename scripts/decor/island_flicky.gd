extends Node3D
## Runners wildlife uses its own animation clock. The ball never drives the pose.
const SPECIES := ["flicky", "picky", "pecky", "pocky", "ricky", "rocky", "cookie"]
const CLIP := &"ani_cmn_idle_loop"
const ASSET_PATH := "res://experiments/visual_lab/local/runners-decomp/%s/Runners animal.glb"
var species := "flicky"
var phase := 0.0
var animation_time := 0.0
var pose: Node3D
var rig: Node3D
var player: AnimationPlayer

static func available_species() -> Array:
 return SPECIES.filter(func(id: String): return FileAccess.file_exists(ASSET_PATH % id))

func _init(presentation: Node3D = null, index: int = 0) -> void:
 if presentation == null: return # Baked perches bind after their nodes are attached.
 name = "Flicky%d" % (index + 1)
 phase = float(index) / 3.0
 process_mode = Node.PROCESS_MODE_PAUSABLE
 pose = Node3D.new()
 pose.name = "Animal"
 add_child(pose)
 scale = Vector3.ONE * 0.55
 # Bake just the perch. Original art is installed locally on the machine playing.
 if not presentation.has_method("stream_checkpoint"): bind_model()

func bind_model() -> void:
 if rig and rig.name == species:
  set_animation_time(0.0)
  return
 if rig:
  rig.free()
  rig = null
  player = null
 set_process(false)
 if species not in SPECIES or not FileAccess.file_exists(ASSET_PATH % species): return
 var gltf := GLTFDocument.new()
 var state := GLTFState.new()
 if gltf.append_from_file(ProjectSettings.globalize_path(ASSET_PATH % species), state) != OK: return
 var gold: ShaderMaterial
 if species == "flicky":
  var env_index: int = state.get_json().materials[0].get("extras", {}).get("runnersEnvironmentImage", -1)
  var images := state.get_images()
  if env_index < 0 or env_index >= images.size() or not images[env_index]: return
  gold = ShaderMaterial.new()
  gold.shader = preload("res://scripts/decor/runners_flicky_gold.gdshader")
  gold.set_shader_parameter("body_texture", state.get_materials()[0].albedo_texture)
  gold.set_shader_parameter("gold_texture", images[env_index])
 rig = gltf.generate_scene(state, 60.0, false, false)
 if not rig: return
 player = rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
 if not player or not player.has_animation(CLIP):
  rig.free()
  rig = null
  player = null
  return
 if not pose:
  pose = Node3D.new()
  pose.name = "Animal"
  add_child(pose)
 rig.name = species
 pose.add_child(rig)
 player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 player.play(CLIP)
 # Measure actual vertices in the authored rest pose, including the feet of
 # ground animals and Rocky's low body. All seven use different rigid parts.
 var bottom := INF
 for part: MeshInstance3D in rig.find_children("*", "MeshInstance3D", true, false):
  if gold: part.set_surface_override_material(0, gold)
  var local := part.transform
  var parent := part.get_parent() as Node3D
  while parent != rig:
   local = parent.transform * local
   parent = parent.get_parent() as Node3D
  for vertex: Vector3 in part.mesh.get_faces(): bottom = minf(bottom, (local * vertex).y)
 if is_finite(bottom): rig.position.y = -bottom
 set_animation_time(0.0)
 set_process(true)

func set_animation_time(seconds: float) -> void:
 animation_time = seconds
 if player:
  var length := player.current_animation_length
  if length > 0.0: player.seek(fposmod(seconds + phase * length, length), true)

func _process(delta: float) -> void:
 set_animation_time(animation_time + delta)
