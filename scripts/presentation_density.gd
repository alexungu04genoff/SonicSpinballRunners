extends RefCounted
## Solid-form art direction, not collision tessellation or a VFX budget.
## See docs/PINBALL_VOCABULARY.md. Custom theme topology remains welcome.
const DETAIL_SEGMENTS := 6
const ORDINARY_SEGMENTS := 8
const ORDINARY_RINGS := 4
const IMPORTANT_SEGMENTS := 12
const IMPORTANT_SPHERE_SEGMENTS := 10
const IMPORTANT_RINGS := 5
const HERO_SEGMENTS := 16

static func faceted(source: PrimitiveMesh) -> ArrayMesh:
 # Split vertices at triangle boundaries so light reveals the constructed form.
 # Only opt-in organic/carved primitives use this; metal keeps its radial normals.
 var arrays := source.get_mesh_arrays()
 var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
 var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
 var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 surface.set_smooth_group(-1)
 surface.set_material(source.material)
 for triangle in range(0, indices.size(), 3):
  var a := vertices[indices[triangle]]
  var b := vertices[indices[triangle + 1]]
  var c := vertices[indices[triangle + 2]]
  # Sphere primitives include collapsed pole triangles; they have no face normal.
  if (b - a).cross(c - a).length_squared() < 1e-16: continue
  for corner in 3:
   var index := indices[triangle + corner]
   surface.set_uv(uv[index])
   surface.add_vertex(vertices[index])
 surface.generate_normals()
 surface.generate_tangents()
 return surface.commit()
