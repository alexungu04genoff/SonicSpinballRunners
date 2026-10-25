extends MeshInstance3D
## A time-faded ribbon in presentation space. Never participates in collisions.
const LIFETIME := 0.32
const MAX_POINTS := 64
var points: Array[Vector3] = []
var ages: Array[float] = []
var ribbon := ImmediateMesh.new()
var tint := Color("59c9ff")
var radius := 0.17

func _init() -> void:
 name = "CharacterMotionRibbon"
 mesh = ribbon
 cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var shader := Shader.new()
 shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
 float edge = pow(max(0.0, 1.0 - abs(UV.y * 2.0 - 1.0)), 1.4);
 float core = pow(edge, 8.0);
 ALBEDO = mix(COLOR.rgb, vec3(1.0), core * 0.55);
 float life = 1.0 - UV.x;
 ALPHA = life * edge * 0.9;
}
"""
 var material := ShaderMaterial.new()
 material.shader = shader
 material_override = material

func reset() -> void:
 points.clear()
 ages.clear()
 ribbon.clear_surfaces()
 visible = false

func advance(delta: float, head: Vector3, emitting: bool, camera: Camera3D) -> void:
 for i in ages.size():
  ages[i] += delta
 while not ages.is_empty() and ages[-1] >= LIFETIME:
  ages.pop_back()
  points.pop_back()
 if emitting and delta > 0.0:
  if points.is_empty() or points[0].distance_to(head) > radius * 0.06:
   points.push_front(head)
   ages.push_front(0.0)
   if points.size() > MAX_POINTS:
    points.pop_back()
    ages.pop_back()
 ribbon.clear_surfaces()
 visible = points.size() > 1
 if not visible:
  return
 ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
 var previous_side := Vector3.ZERO
 for i in points.size():
  var before: Vector3 = points[maxi(0, i - 1)]
  var after: Vector3 = points[mini(points.size() - 1, i + 1)]
  var tangent := (before - after).normalized()
  var facing := (camera.global_position - to_global(points[i])).normalized()
  var side := tangent.cross(facing).normalized()
  if side.length_squared() < 0.01:
   side = previous_side if previous_side != Vector3.ZERO else Vector3.RIGHT
  if previous_side.dot(side) < 0.0:
   side = -side
  previous_side = side
  var life := clampf(1.0 - ages[i] / LIFETIME, 0.0, 1.0)
  var width := radius * 1.05 * pow(life, 0.65)
  var color := Color(tint, 1.0)
  for edge in 2:
   ribbon.surface_set_color(color)
   ribbon.surface_set_uv(Vector2(1.0 - life, float(edge)))
   ribbon.surface_add_vertex(points[i] + side * width * (-1.0 if edge == 0 else 1.0))
 ribbon.surface_end()

