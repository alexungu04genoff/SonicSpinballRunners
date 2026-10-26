extends SceneTree
## Acute starting wedges must retain perpendicular, outward wall normals.

func _initialize() -> void:
 var presentation := TablePresentation.new()
 var outline := PackedVector2Array([Vector2(0, 0), Vector2(800, -60), Vector2(800, 0)])
 var failures := 0
 for mirrored: bool in [false, true]:
  var points := outline.duplicate()
  if mirrored:
   for i in points.size(): points[i].x = -points[i].x
  var mesh := presentation._prism(points, 0.325, null, null)
  var arrays := mesh.surface_get_arrays(1)
  var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
  var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
  for face in points.size():
   var start := face * 6
   var edge := vertices[start + 1] - vertices[start]
   var outward := Vector3(edge.z, 0, -edge.x).normalized()
   for vertex in range(start, start + 6):
    # ArrayMesh packs normals, so allow quantization error on readback.
    if normals[vertex].distance_to(outward) > 0.001:
     push_error("Wall normal blends across an acute corner (mirrored=%s)" % mirrored)
     failures += 1
 presentation.free()
 print("RESULT | Wall normals | %d failures" % failures)
 quit(0 if failures == 0 else 1)
