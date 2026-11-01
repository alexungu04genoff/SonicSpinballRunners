extends RefCounted
## Exterior wall triangles belong to the same facade as the floor below them.
## Transfer existing triangles into its existing surface: no new draw or geometry.
const POSITION_EPSILON := 0.000025
const EDGE_CELL := 0.5

static func material(source: Material, top_height: float, trim: Material = null) -> Material:
 if not source is ShaderMaterial: return source
 var result: ShaderMaterial = source.duplicate()
 var code: String = source.shader.code
 if code.contains("uniform float top_height"):
  result.set_shader_parameter("top_height", top_height)
 if code.contains("uniform int mapping") and code.contains("varying vec3 world_normal"):
  # Facades cannot use a private contour chart, even when an art variant does.
  result.set_shader_parameter("mapping", 1)
 elif code.contains("uniform bool world_mapping") or code.contains("uniform sampler2D soil_texture") or code.contains("uniform int mapping"):
  # Legacy Green Hill uses a contour UV image (or the local soil/fringe variant).
  # Keep its selected image and pitch; only exterior projection changes.
  result.shader = preload("res://scripts/themes/terrain_facade.gdshader")
  if code.contains("uniform sampler2D soil_texture"):
   result.set_shader_parameter("surface_texture", source.get_shader_parameter("soil_texture"))
   result.set_shader_parameter("repeat_size", Vector2(0.64, 0.64))
  elif code.contains("uniform bool world_mapping"):
   result.set_shader_parameter("surface_texture", source.get_shader_parameter("surface_texture"))
   result.set_shader_parameter("repeat_size", source.get_shader_parameter("repeat_size"))
  else:
   # Albedo-only contour facade variants use the same exterior chart too.
   result.set_shader_parameter("surface_texture", source.get_shader_parameter("albedo_texture"))
   result.set_shader_parameter("repeat_size", source.get_shader_parameter("repeat_size"))
   result.set_shader_parameter("clamp_depth", true)
   result.set_shader_parameter("top_height", top_height)
   result.set_shader_parameter("roughness_value", 0.65)
   result.set_shader_parameter("specular_value", 0.3)
  if trim is ShaderMaterial and trim.shader.code.contains("uniform sampler2D fringe_texture"):
   result.set_shader_parameter("fringe_texture", trim.get_shader_parameter("fringe_texture"))
   result.set_shader_parameter("show_fringe", true)
   result.set_shader_parameter("turf_height", trim.get_shader_parameter("turf_height"))
 return result

static func consolidate(floor_root: Node3D, terrain_root: Node3D, outline: PackedVector2Array, side_material: Material) -> Dictionary:
 var cliff: MeshInstance3D = floor_root.get_node("CheckerCliff")
 var facade := SurfaceTool.new()
 facade.begin(Mesh.PRIMITIVE_TRIANGLES)
 facade.set_material(cliff.mesh.surface_get_material(0))
 var original := cliff.mesh.surface_get_arrays(0)
 for i in original[Mesh.ARRAY_VERTEX].size():
  facade.set_normal(original[Mesh.ARRAY_NORMAL][i])
  facade.set_uv(original[Mesh.ARRAY_TEX_UV][i])
  facade.add_vertex(original[Mesh.ARRAY_VERTEX][i])
 var moved := 0
 var before := 0
 var after := 0
 var edges := {}
 for i in outline.size():
  var a := outline[i] * TablePresentation.SCALE
  var b := outline[(i + 1) % outline.size()] * TablePresentation.SCALE
  var low := Vector2i(((a.min(b) - Vector2.ONE * POSITION_EPSILON) / EDGE_CELL).floor())
  var high := Vector2i(((a.max(b) + Vector2.ONE * POSITION_EPSILON) / EDGE_CELL).floor())
  for x in range(low.x, high.x + 1):
   for y in range(low.y, high.y + 1):
    var cell := Vector2i(x, y)
    if not edges.has(cell): edges[cell] = []
    edges[cell].append(PackedVector2Array([a, b]))
 for node: Node in terrain_root.find_children("*", "MeshInstance3D", true, false):
  if node == cliff or node.get_parent() == floor_root: continue
  var mesh: ArrayMesh = node.mesh as ArrayMesh
  if mesh == null: continue
  var replacement := ArrayMesh.new()
  var changed := false
  for s in mesh.get_surface_count():
   before += 1
   var arrays := mesh.surface_get_arrays(s)
   var material: Material = mesh.surface_get_material(s)
   if material != side_material:
    replacement.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arrays)
    replacement.surface_set_material(replacement.get_surface_count() - 1, material)
    after += 1
    continue
   var inside := SurfaceTool.new()
   inside.begin(Mesh.PRIMITIVE_TRIANGLES)
   inside.set_material(material)
   var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
   var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
   var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
   var retained := 0
   for i in range(0, vertices.size(), 3):
    var exterior := true
    for j in 3:
     var point := Vector2(vertices[i + j].x, vertices[i + j].z)
     if absf(normals[i + j].y) > 0.01 or not _on_boundary(point, edges):
      exterior = false
      break
    # A chord can have endpoints on a curved boundary while crossing its interior.
    if exterior:
     var center := (vertices[i] + vertices[i + 1] + vertices[i + 2]) / 3.0
     exterior = _on_boundary(Vector2(center.x, center.z), edges)
    var target := facade if exterior else inside
    for j in 3:
     target.set_normal(normals[i + j])
     target.set_uv(uv[i + j] if not uv.is_empty() else Vector2.ZERO)
     target.add_vertex(vertices[i + j])
    if exterior: moved += 1
    else: retained += 1
   if retained > 0:
    inside.commit(replacement)
    after += 1
   changed = true
  if changed: node.mesh = replacement
 cliff.mesh = facade.commit()
 return {"triangles": moved, "surfaces_before": before + 1, "surfaces_after": after + 1}

static func _on_boundary(point: Vector2, edges: Dictionary) -> bool:
 for edge: PackedVector2Array in edges.get(Vector2i((point / EDGE_CELL).floor()), []):
  if point.x < minf(edge[0].x, edge[1].x) - POSITION_EPSILON or point.x > maxf(edge[0].x, edge[1].x) + POSITION_EPSILON: continue
  if point.y < minf(edge[0].y, edge[1].y) - POSITION_EPSILON or point.y > maxf(edge[0].y, edge[1].y) + POSITION_EPSILON: continue
  if point.distance_to(Geometry2D.get_closest_point_to_segment(point, edge[0], edge[1])) <= POSITION_EPSILON: return true
 return false
