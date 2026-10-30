extends SceneTree
const Batch = preload("res://scripts/pinball_mesh_batch.gd")
const Detail = preload("res://scripts/endless/visual_detail.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL | " + label)

func triangle(indexed: bool, rich := true) -> ArrayMesh:
 var arrays: Array = []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.FORWARD])
 arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
 if rich:
  arrays[Mesh.ARRAY_TANGENT] = PackedFloat32Array([1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1])
  arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN])
  arrays[Mesh.ARRAY_TEX_UV2] = PackedVector2Array([Vector2(0.2, 0.2), Vector2(0.8, 0.2), Vector2(0.2, 0.8)])
  arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color.RED, Color.GREEN, Color.BLUE])
 if indexed: arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
 return mesh

func piece(actor: Node3D, mesh: Mesh, material: Material, at := Vector3.ZERO) -> MeshInstance3D:
 var visual := MeshInstance3D.new()
 visual.mesh = mesh
 visual.material_override = material
 visual.position = at
 actor.add_child(visual)
 return visual

func signature(actor: Node3D, baked := false, include_packed := true) -> Array[String]:
 var result: Array[String] = []
 for child: Node in actor.get_children():
  if not child is MeshInstance3D: continue
  var mesh: Mesh = child.mesh
  if baked and mesh is PrimitiveMesh:
   # Match BakeAssets' existing conversion, including its normal/tangent packing.
   var canonical := ArrayMesh.new()
   canonical.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, Detail.primitive(mesh).get_mesh_arrays())
   mesh = canonical
  for surface in mesh.get_surface_count():
   var arrays := mesh.surface_get_arrays(surface)
   var indices: Variant = arrays[Mesh.ARRAY_INDEX]
   if indices == null or indices.is_empty(): indices = range(arrays[Mesh.ARRAY_VERTEX].size())
   var material: Material = child.get_active_material(surface)
   for first in range(0, indices.size(), 3):
    var data: Array = [material.get_instance_id() if material != null else 0, child.cast_shadow, child.layers]
    for corner in 3:
     var index: int = indices[first + corner]
     data.append(arrays[Mesh.ARRAY_VERTEX][index] + child.position)
     for attribute: int in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
      if not include_packed and attribute in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT]: continue
      if arrays[attribute] == null or arrays[attribute].is_empty():
       data.append(null)
      elif attribute == Mesh.ARRAY_TANGENT:
       data.append(arrays[attribute].slice(index * 4, index * 4 + 4))
      else:
       data.append(arrays[attribute][index])
    result.append(var_to_bytes(data).hex_encode())
 result.sort()
 return result

func packed_error(before: Array, after: Array, copies: int) -> Dictionary:
 var result := {"count_matches": true, "normal": 0.0, "tangent": 0.0}
 for attribute: int in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT]:
  var count: int = before[attribute].size()
  if after[attribute].size() != count * copies:
   result.count_matches = false
   continue
  for copy in copies:
   for i in count:
    var error: float
    if attribute == Mesh.ARRAY_NORMAL:
     error = before[attribute][i].distance_to(after[attribute][copy * count + i])
    else:
     error = absf(before[attribute][i] - after[attribute][copy * count + i])
    var key := "normal" if attribute == Mesh.ARRAY_NORMAL else "tangent"
    result[key] = maxf(result[key], error)
 return result

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var actor := Node3D.new()
 actor.transform = Transform3D(Basis.from_euler(Vector3(0.1, 0.3, -0.2)).scaled(Vector3(1.2, 0.7, 1.4)), Vector3(7, 3, -9))
 var original_root := actor.transform
 var red := StandardMaterial3D.new()
 red.albedo_color = Color.RED
 var blue := StandardMaterial3D.new()
 blue.albedo_color = Color.BLUE
 var indexed := triangle(true)
 var unindexed := triangle(false)
 piece(actor, indexed, red, Vector3(0.25, 0.5, 0))
 piece(actor, unindexed, red, Vector3(-0.5, 0, 0.25))
 piece(actor, indexed, blue, Vector3(1, 0, 0))
 piece(actor, indexed, red, Vector3(2, 0, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 piece(actor, indexed, red, Vector3(3, 0, 0)).layers = 2
 piece(actor, triangle(false, false), red, Vector3(4, 0, 0))
 var layered := triangle(false)
 layered.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, indexed.surface_get_arrays(0))
 piece(actor, layered, red, Vector3(5, 0, 0))
 var before := signature(actor)
 var original_vertices: PackedVector3Array = indexed.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 var result := Batch.combine(actor)
 check(result.surfaces_before == 8 and result.surfaces_after == 5, "Only matching material, shadow, layer and attribute groups share draws")
 check(signature(actor) == before, "Every indexed and unindexed triangle retains winding, position, normal, tangent, color and both UV channels")
 check(actor.transform == original_root, "Animated actor root retains rotation, position and nonuniform scale")
 check(indexed.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == original_vertices, "Source mesh resources remain unchanged")
 var second := Batch.combine(actor)
 check(second.surfaces_before == second.surfaces_after and signature(actor) == before, "Repeated combining preserves the completed actor")
 actor.free()

 var guarded := Node3D.new()
 var transformed := piece(guarded, indexed, red)
 transformed.scale = Vector3(-1, 1, 1)
 var hidden := piece(guarded, indexed, red)
 hidden.visible = false
 var parent_mesh := piece(guarded, indexed, red)
 parent_mesh.add_child(Node3D.new())
 var transparent := red.duplicate() as StandardMaterial3D
 transparent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 var glass := piece(guarded, indexed, transparent)
 var custom_shader := ShaderMaterial.new()
 custom_shader.shader = Shader.new()
 custom_shader.shader.code = "shader_type spatial; void vertex() { VERTEX.x += NODE_POSITION_WORLD.x; }"
 var local_shader := piece(guarded, indexed, custom_shader)
 piece(guarded, indexed, red, Vector3.RIGHT)
 piece(guarded, unindexed, red, Vector3.LEFT)
 Batch.combine(guarded)
 check(is_instance_valid(transformed) and transformed.get_parent() == guarded and transformed.scale.x == -1, "Mirrored or rotated/scaled leaves are not flattened")
 check(is_instance_valid(hidden) and not hidden.visible and is_instance_valid(parent_mesh) and parent_mesh.get_child_count() == 1, "Hidden leaves and child hierarchies retain their identities")
 check(is_instance_valid(glass) and is_instance_valid(local_shader), "Transparent and unknown node-dependent shaders remain individual")
 guarded.free()

 for baked: bool in [false, true]:
  var hardware := Node3D.new()
  var cylinder := CylinderMesh.new()
  cylinder.radial_segments = 48
  cylinder.top_radius = 0.2
  cylinder.bottom_radius = 0.3
  cylinder.height = 0.1
  var pinball := ShaderMaterial.new()
  pinball.shader = Batch.Surface
  piece(hardware, cylinder, pinball, Vector3(0.2, 0.3, 0.4))
  piece(hardware, cylinder, pinball, Vector3(-0.2, 0.1, 0.2))
  var expected := signature(hardware, baked, false)
  var expected_mesh: Mesh = cylinder
  if baked:
   var canonical := ArrayMesh.new()
   canonical.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, Detail.primitive(cylinder).get_mesh_arrays())
   expected_mesh = canonical
  var before_arrays := expected_mesh.surface_get_arrays(0)
  var merged := Batch.combine(hardware, baked)
  check(merged.surfaces_after == 1 and signature(hardware, false, false) == expected, "Every primitive triangle, position, UV and material matches the existing %s path" % ("bake" if baked else "standalone"))
  var error := packed_error(before_arrays, hardware.get_child(0).mesh.surface_get_arrays(0), 2)
  # PrimitiveMesh to ArrayMesh re-encodes packed normal/tangent directions.
  # The baked path already performed this conversion and should remain exact.
  var tolerance := 0.0 if baked else 0.0001
  check(error.count_matches and error.normal <= tolerance and error.tangent <= tolerance, "All primitive normals and tangents stay within their measured packing tolerance")
  print("PINBALL_PACKED_FIDELITY | ", JSON.stringify({"baked": baked, "tolerance": tolerance, "error": error}))
  check(cylinder.radial_segments == 48, "Bake detail never mutates a shared primitive resource")
  hardware.free()
 print("PINBALL_MESH_BATCH_REGRESSION | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
