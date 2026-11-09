extends RefCounted
## Authoring-only: a few planar faces per rock, traced from structural height.
static func build(height: Image, repeat_size: float, height_range: float) -> ArrayMesh:
 var size:=height.get_width()
 var mask:=BitMap.new()
 mask.create(Vector2i.ONE*size*3)
 for y in size:
  for x in size:
   if height.get_pixel(x,y).r*height_range-0.003<=0.006:continue
   for row in 3:
    for column in 3:mask.set_bit(x+column*size,y+row*size,true)
 var surface:=SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var count:=0
 for outline: PackedVector2Array in mask.opaque_to_polygons(Rect2i(Vector2i.ZERO,mask.get_size()),1.5):
  # Whole rocks crossing a repeat edge are kept once, by their center.
  var center:=Vector2.ZERO
  for point: Vector2 in outline:center+=point
  center/=outline.size()
  if not Rect2(Vector2.ONE*size,Vector2.ONE*size).has_point(center):continue
  var hull:=Geometry2D.convex_hull(outline)
  hull.remove_at(hull.size()-1)
  if hull.size()<3:continue
  count+=1
  var crown:=vertex(center,height,size,repeat_size,height_range)
  for i in hull.size():
   var next:=(i+1)%hull.size()
   var a:=vertex(hull[i],height,size,repeat_size,height_range)
   var b:=vertex(hull[next],height,size,repeat_size,height_range)
   a.y=0.001
   b.y=0.001
   var inner_a:=vertex(hull[i].lerp(center,0.36),height,size,repeat_size,height_range)
   var inner_b:=vertex(hull[next].lerp(center,0.36),height,size,repeat_size,height_range)
   triangle(surface,a,b,inner_a)
   triangle(surface,b,inner_b,inner_a)
   triangle(surface,inner_a,inner_b,crown)
 var mesh:=surface.commit()
 mesh.set_meta("rock_count",count)
 mesh.set_meta("repeat_size",repeat_size)
 return mesh

static func vertex(pixel: Vector2,height: Image,size: int,repeat_size: float,height_range: float) -> Vector3:
 var uv:=(pixel-Vector2.ONE*size)/size
 var value:=height.get_pixel(posmod(roundi(pixel.x),size),posmod(roundi(pixel.y),size)).r*height_range-0.003
 return Vector3(uv.x*repeat_size,maxf(0.001,value*0.75),uv.y*repeat_size)

static func triangle(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3) -> void:
 var normal:=(c-a).cross(b-a).normalized()
 if normal.y<0.0:
  var swap:=b
  b=c
  c=swap
  normal=-normal
 for point: Vector3 in [a,b,c]:
  surface.set_normal(normal)
  surface.add_vertex(point)
