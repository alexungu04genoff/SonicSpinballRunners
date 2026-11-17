extends SceneTree
## Small geometry contracts: reusable sunflower, family budgets, valid winding.
const Flower = preload("res://scripts/decor/sunflower_meshes.gd")
const Density = preload("res://scripts/presentation_density.gd")
const Detail = preload("res://scripts/endless/visual_detail.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(message)

func triangles(mesh: Mesh) -> int:
 return mesh.get_faces().size() / 3

func valid_flat_faces(mesh: Mesh) -> bool:
 var arrays := mesh.surface_get_arrays(0)
 var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
 var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
 var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
 if normals.size() != vertices.size(): return false
 if indices.is_empty():
  for i in vertices.size(): indices.append(i)
 for i in range(0, indices.size(), 3):
  var a := indices[i]
  var b := indices[i + 1]
  var c := indices[i + 2]
  var face := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a])
  if not face.is_finite() or face.length_squared() < 0.000000000001: return false
  for vertex: int in [a, b, c]:
   if not normals[vertex].is_finite() or face.normalized().dot(normals[vertex]) < 0.99: return false
 return true

func _initialize() -> void:
 var total := 0
 for part: String in ["stem", "leaf", "petal", "center"]:
  var mesh: Mesh = Flower.get_part(part)
  check(mesh == Flower.get_part(part), "Flower patches share " + part)
  total += triangles(mesh) * (8 if part == "petal" else 1)
  var arrays := mesh.surface_get_arrays(0)
  var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
  var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
  var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
  check(normals.size() == vertices.size(), "Every flower vertex has a normal")
  var valid := true
  for index in range(0, indices.size(), 3):
   var a: int = indices[index]
   var b: int = indices[index + 1]
   var c: int = indices[index + 2]
   var face := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a])
   valid = valid and face.is_finite() and face.length_squared() > 0.000000000001
   valid = valid and face.dot(normals[a] + normals[b] + normals[c]) > 0.0
  check(valid, "Flower has finite nondegenerate clockwise faces: " + part)
 check(total <= 100, "Complete eight-petal sunflower stays below 100 triangles")
 check(triangles(Density.sphere(1.0, Density.Family.TINY)) <= 48, "Tiny spheres cannot inherit scenery/hardware density")
 check(triangles(Detail.primitive(Flower.get_part("stem"))) == triangles(Flower.get_part("stem")), "Bake retains deliberate tiny stem geometry")
 var torus := TorusMesh.new()
 torus.rings = Density.RING_SIDES
 torus.ring_segments = Density.RING_TUBE_SIDES
 check(triangles(torus) <= 160, "Ordinary Rings stay within calibrated silhouette budget")
 var presentation = preload("res://scripts/themes/themed_presentation.gd").new()
 presentation.set_theme_definition(preload("res://scripts/themes/theme_registry.gd").create("green_hill"))
 var loop: Node3D = presentation.decor_skin.factory.call("turf_loop")
 var soil: Mesh = loop.get_node("CheckerCliff").mesh
 var valid_cliff := true
 for normal: Vector3 in soil.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]:
  valid_cliff = valid_cliff and normal.y <= 0.721
 check(valid_cliff, "Horizontal loop faces use turf, never the vertical facade projection")
 var valid_uv := true
 for node: MeshInstance3D in loop.get_children():
  for uv: Vector2 in node.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]: valid_uv = valid_uv and uv.is_finite()
 check(valid_uv, "Loop retains finite texture coordinates")
 loop.free()
 var rock: Node3D = presentation.decor_skin.factory.call("small_rock")
 var rock_mesh: Mesh = rock.get_child(0).mesh
 check(triangles(rock_mesh) <= 64 and valid_flat_faces(rock_mesh), "Chipped rocks retain a small, finite, outward flat-shaded mesh")
 rock.free()
 var ice := preload("res://scripts/decor/ice_cap_decor.gd").new(null)
 var bough: Mesh = ice.primitive("bough")
 check(triangles(bough) <= 32 and valid_flat_faces(bough), "Snow boughs retain a small, finite, outward flat-shaded mesh")
 check(bough == ice.primitive("bough"), "Snow and foliage reuse the same branch geometry")
 presentation.free()
 print("GEOMETRY_DENSITY | flower_triangles=%d checks=%d failures=%d" % [total, checks, failures])
 quit(1 if failures else 0)
