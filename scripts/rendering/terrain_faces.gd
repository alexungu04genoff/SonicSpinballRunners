extends RefCounted
## Apply the terrain look while authoring the mesh, before its ordinary
## material and warm-up recipe are saved. Streamed Acts load those materials.
const ROLES := ["terrain_ground", "terrain_upper", "terrain_walls", "terrain_borders", "terrain_ledges", "ramps"]
const Surface = preload("res://scripts/atmosphere/surface_controls.gd")

static func mesh_of(node: Node) -> Mesh:
 if node is MeshInstance3D: return node.mesh
 if node is MultiMeshInstance3D and node.multimesh: return node.multimesh.mesh
 return null

static func supports_face_shader(code: String) -> bool:
 for token in ["ALPHA", "unshaded", "depth_test_disabled", "depth_draw_never", "blend_add", "blend_sub", "blend_mul", "hint_screen_texture", "hint_depth_texture", "void light", "skip_vertex_transform", "world_vertex_coords"]:
  if token in code: return false
 if "AO_LIGHT_AFFECT" in code:
  var zero := RegEx.create_from_string("\\bAO_LIGHT_AFFECT\\s*=\\s*0(?:\\.0+)?\\s*;")
  if "AO_LIGHT_AFFECT" in zero.sub(code,"",true): return false
 return true

static func prepare(presenter: Node3D, scenery: Node3D) -> void:
 var materials := {}
 for node: GeometryInstance3D in presenter.find_children("*","GeometryInstance3D",true,false):
  if scenery.is_ancestor_of(node) or node.transparency > 0.0 or node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
  var mesh := mesh_of(node)
  if not mesh or mesh.get_surface_count() != 1: continue
  var source := node.material_override
  if not source and node is MeshInstance3D: source = node.get_active_material(0)
  if not source: source = mesh.surface_get_material(0)
  if not source is ShaderMaterial or not source.shader or source.next_pass or source.get_meta("atmosphere_hue","") not in ROLES: continue
  if not supports_face_shader(source.shader.code): continue
  var bounds := mesh.get_aabb()
  var key := [source, bounds.position.y, bounds.size.y]
  if not materials.has(key):
   var material: ShaderMaterial = source.duplicate()
   Surface.prepare(material,true)
   material.set_shader_parameter("terrain_face_bounds",Vector2(bounds.position.y,bounds.size.y))
   materials[key] = material
  node.material_override = materials[key]
