extends RefCounted
## Local-only Runners assets shared by the Prototype and the spin preview.
const LOCAL_SET := "res://experiments/visual_lab/local/runtime/sonic_runners_poses.glb"
const CURLS := {"sonic": "sn_ball_loop", "tails": "tl_jump_ball_loop", "knuckles": "kn_jump_ball_loop", "shadow": "sh_jump_ball_loop"}
const PREFIX := {"sonic": "sn", "tails": "tl", "knuckles": "kn", "shadow": "sh"}
const POWER_DIVE := {"knuckles": "kn_jump_bunk_loop"}
const FLIGHT := "tl_jump_bunk_loop"
const FLIGHT_CLIPS := {"tails": FLIGHT}
const DASH_RING := {"sonic": "sn_dashring_loop", "tails": "tl_dashring_loop", "knuckles": "kn_dashring_loop", "shadow": "sh_dashring_loop"}
const BOOST := {"sonic": "sn_boost_loop", "tails": "tl_boost_loop", "shadow": "sh_boost_loop", "knuckles": "kn_boost_loop"}
const BOOST_SPEED := 1.5
# Sonic's reference stride is 80 frames at 60 Hz, played at 3x on boost entry.
const BOOST_CYCLES_PER_SECOND := 2.25
const TAIL_WEAVE_DURATION := 8.0 / 60.0

static func set_playback_speed(player: AnimationPlayer, id: String, boost_scale: float) -> void:
 if player.current_animation == BOOST.get(id):
  player.speed_scale = player.current_animation_length * BOOST_CYCLES_PER_SECOND * boost_scale
 else: player.speed_scale = 1.0

static func trick_names(id: String) -> Array:
 var prefix: String = PREFIX.get(id, "")
 return [prefix + "_jump_trick", prefix + "_jump_trick_02", prefix + "_jump_trick_03"]

static func sample_roll_tails(tails: MeshInstance3D, seconds: float) -> void:
 # Frame zero is the base mesh. The last source frame returns to that shape.
 var count := tails.get_blend_shape_count()
 var frame := fposmod(seconds, TAIL_WEAVE_DURATION) * (count + 1) / TAIL_WEAVE_DURATION
 for i in count:
  tails.set_blend_shape_value(i, maxf(0.0, 1.0 - absf(frame - (i + 1))))

static func animated_scene(id: String) -> Node3D:
 var path := "res://experiments/visual_lab/local/runners-decomp/%s/%s Runners - original animations.glb" % [id, id.capitalize()]
 var document := GLTFDocument.new()
 var state := read_state(path, document)
 return document.generate_scene(state) if state != null else null

static func read_state(path: String, document := GLTFDocument.new()) -> GLTFState:
 if not FileAccess.file_exists(path): return null
 var state := GLTFState.new()
 if document.append_from_file(ProjectSettings.globalize_path(path), state) != OK: return null
 return state

static func static_meshes(path: String) -> Dictionary:
 var meshes := {}
 var state := read_state(path)
 if state == null or not state.get_skins().is_empty(): return meshes
 var definitions: Array = state.get_json().get("meshes", [])
 var imported := state.get_meshes()
 for i in imported.size():
  var part: ArrayMesh = imported[i].mesh.get_mesh()
  part.set_meta("bake", definitions[i].get("extras", {}))
  meshes[definitions[i].get("name", str(i))] = part
 return meshes

static func load_set(path: String, painted: ShaderMaterial, id: String) -> Dictionary:
 var poses := static_meshes(path)
 var color_map := path.get_basename() + ".png"
 var tricks_for_character := trick_names(id)
 if not poses.has_all([CURLS[id]] + tricks_for_character) or not FileAccess.file_exists(color_map): return {}
 if id == "tails" and not poses.has("tl_roll_tails"): return {}
 var image := Image.new()
 if image.load(ProjectSettings.globalize_path(color_map)) != OK: return {}
 image.generate_mipmaps()
 var shell := ImageTexture.create_from_image(image)
 var roll := MeshInstance3D.new()
 roll.name = "Runners%sRoll" % id.capitalize()
 roll.mesh = poses[CURLS[id]]
 for surface in roll.mesh.get_surface_count():
  var skin: BaseMaterial3D = roll.mesh.surface_get_material(surface)
  var blur: ShaderMaterial = painted.duplicate()
  blur.set_shader_parameter("runners_model", true)
  blur.set_shader_parameter("runners_skin", skin.albedo_texture)
  blur.set_shader_parameter("runners_shell", shell)
  roll.set_surface_override_material(surface, blur)
 var tricks: Array[Mesh] = []
 for clip: String in tricks_for_character: tricks.append(poses[clip])
 var result := {"roll": roll, "tricks": tricks}
 if id == "tails":
  var tails := MeshInstance3D.new()
  tails.name = "TrailingTails"
  tails.mesh = poses.tl_roll_tails
  result.trailing_tails = tails
 return result
