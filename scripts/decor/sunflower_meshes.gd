extends RefCounted
## Reused, closed/two-sided low-poly parts. Materials remain owned by the theme.
static var parts: Dictionary = {}

static func get_part(part: String) -> Mesh:
 if parts.has(part): return parts[part]
 var mesh: Mesh
 if part in ["stem", "center"]:
  var cylinder := CylinderMesh.new()
  cylinder.top_radius = 0.018 if part == "stem" else 0.082
  cylinder.bottom_radius = cylinder.top_radius
  cylinder.height = 0.37 if part == "stem" else 0.05
  cylinder.radial_segments = 6 if part == "stem" else 8
  cylinder.rings = 0
  cylinder.cap_top = part == "center"
  cylinder.cap_bottom = part == "center"
  mesh = cylinder
 else:
  var surface := SurfaceTool.new()
  surface.begin(Mesh.PRIMITIVE_TRIANGLES)
  var points := [Vector3(0, 0.075, 0), Vector3(0.0525, 0, 0), Vector3(0, -0.075, 0), Vector3(-0.0525, 0, 0)]
  if part == "leaf":
   points = [Vector3(-0.08, -0.03, 0), Vector3(0.02, 0.035, 0.03), Vector3(0.12, 0.07, 0), Vector3(0.02, 0.035, -0.03)]
  # A shallow petal ridge catches the overhead light without changing materials.
  # The leaf and petal backs use real faces, preserving the culling policy.
  var indices := [0, 1, 2, 0, 2, 3, 2, 1, 0, 3, 2, 0]
  if part == "petal":
   points.append(Vector3(0, 0, 0.026))
   indices = [0, 1, 4, 1, 2, 4, 2, 3, 4, 3, 0, 4, 2, 1, 0, 3, 2, 0]
  for triangle in range(0, indices.size(), 3):
   var a: Vector3 = points[indices[triangle]]
   var b: Vector3 = points[indices[triangle + 1]]
   var c: Vector3 = points[indices[triangle + 2]]
   var normal := (c - a).cross(b - a).normalized()
   for vertex: Vector3 in [a, b, c]:
    surface.set_normal(normal)
    surface.add_vertex(vertex)
  surface.index()
  mesh = surface.commit()
 parts[part] = mesh
 return mesh
