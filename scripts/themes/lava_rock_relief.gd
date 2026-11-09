extends RefCounted
## Collisionless recessed rock facets; gameplay contours and collisions stay flat.
var tiles: Dictionary={}
var materials: Dictionary={}

func prepare(id: String,source: ShaderMaterial) -> void:
 tiles[id]=load("res://assets/textures/lava_reef/selected/"+id+"_relief.res")
 # Sink the bed and the bevels; the highest rock face stays at the original level.
 source.set_shader_parameter("recess_depth",tiles[id].get_aabb().end.y)
 var material: ShaderMaterial=source.duplicate()
 material.resource_name=source.resource_name+" recessed rock facets"
 material.set_meta("lava_visual_relief",true)
 material.set_meta("normal_strength",0.0)
 material.set_shader_parameter("relief_strength",0.0)
 material.set_shader_parameter("visual_relief",true)
 materials[id]=material

func build(outline: PackedVector2Array,base_height: float,id: String) -> ArrayMesh:
 var points:=PackedVector2Array()
 for point: Vector2 in outline:points.append(point*0.01)
 var bounds:=Rect2(points[0],Vector2.ZERO)
 for point: Vector2 in points:bounds=bounds.expand(point)
 var tile: ArrayMesh=tiles[id]
 var repeat_size: float=tile.get_meta("repeat_size")
 var vertices: PackedVector3Array=tile.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 var low:=Vector2i((bounds.position/repeat_size).floor())-Vector2i.ONE
 var high:=Vector2i((bounds.end/repeat_size).ceil())+Vector2i.ONE
 var surface:=SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 surface.set_material(materials[id])
 var count:=0
 for y in range(low.y,high.y+1):
  for x in range(low.x,high.x+1):
   var offset:=Vector2(x,y)*repeat_size
   for index in range(0,vertices.size(),3):
    var triangle:=PackedVector2Array()
    for j in 3:triangle.append(Vector2(vertices[index+j].x,vertices[index+j].z)+offset)
    var rect:=Rect2(triangle[0],Vector2.ZERO).expand(triangle[1]).expand(triangle[2])
    if not bounds.intersects(rect):continue
    # Clip only the visual overlay, including concave edges and narrow rail caps.
    for clipped: PackedVector2Array in Geometry2D.intersect_polygons(triangle,points):
     for i in Geometry2D.triangulate_polygon(clipped):
      var at:=clipped[i]
      var height:=_height(at,triangle,vertices,index)
      var a:=vertices[index]
      var b:=vertices[index+1]
      var c:=vertices[index+2]
      surface.set_normal((c-a).cross(b-a).normalized())
      surface.set_uv2(Vector2(height,0.0))
      surface.add_vertex(Vector3(at.x,base_height+height,at.y))
      count+=1
 if count==0:return null
 return surface.commit()

static func _height(point: Vector2,triangle: PackedVector2Array,vertices: PackedVector3Array,index: int) -> float:
 var a:=triangle[0]
 var b:=triangle[1]
 var c:=triangle[2]
 var denominator:=(b-a).cross(c-a)
 var u:=(point-a).cross(c-a)/denominator
 var v:=(b-a).cross(point-a)/denominator
 return vertices[index].y*(1.0-u-v)+vertices[index+1].y*u+vertices[index+2].y*v
