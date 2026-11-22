extends RefCounted
## Local-only Runners assets shared by the Prototype and the spin preview.
const LOCAL_SET := "res://experiments/visual_lab/local/runtime/sonic_runners_poses.glb"
const ANIMATED := "res://experiments/visual_lab/local/runners-decomp/sonic/Sonic Runners - original animations.glb"
const TRICKS := ["sn_jump_trick", "sn_jump_trick_02", "sn_jump_trick_03"]

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

static func load_set(path: String, painted: ShaderMaterial) -> Dictionary:
 var poses := static_meshes(path)
 var color_map := path.get_basename() + ".png"
 if not poses.has_all(["sn_ball_loop"] + TRICKS) or not FileAccess.file_exists(color_map): return {}
 var image := Image.new()
 if image.load(ProjectSettings.globalize_path(color_map)) != OK: return {}
 image.generate_mipmaps()
 var shell := ImageTexture.create_from_image(image)
 var roll := MeshInstance3D.new()
 roll.name = "RunnersSonicRoll"
 roll.mesh = poses.sn_ball_loop
 for surface in roll.mesh.get_surface_count():
  var skin: BaseMaterial3D = roll.mesh.surface_get_material(surface)
  var blur: ShaderMaterial = painted.duplicate()
  blur.set_shader_parameter("runners_model", true)
  blur.set_shader_parameter("runners_skin", skin.albedo_texture)
  blur.set_shader_parameter("runners_shell", shell)
  roll.set_surface_override_material(surface, blur)
 var tricks: Array[Mesh] = []
 for clip: String in TRICKS: tricks.append(poses[clip])
 return {"roll": roll, "tricks": tricks}
