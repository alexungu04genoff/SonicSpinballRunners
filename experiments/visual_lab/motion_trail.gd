extends MeshInstance3D
## A time-faded ribbon in presentation space. Never participates in collisions.
const LIFETIME := 0.38
const MAX_POINTS := 64
const JOIN_RADII := 1.8
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
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float join_radii;
void fragment() {
 float across = abs(UV.y * 2.0 - 1.0);
 float join_fade = smoothstep(0.15, join_radii, UV.x);
 float half_width = mix(0.28, 1.0, join_fade);
 float edge = 1.0 - smoothstep(0.83 * half_width, half_width, across);
 float streak = pow(max(0.0, cos(UV.y * 25.1327 + (1.0 - COLOR.a) * 3.0)), 18.0);
 ALBEDO = mix(COLOR.rgb, vec3(1.0), 0.24 + streak * 0.12);
 ALPHA = COLOR.a * edge * join_fade * 0.7;
}
"""
 var material := ShaderMaterial.new()
 material.shader = shader
 material.set_shader_parameter("join_radii", JOIN_RADII)
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
 var behind_head := 0.0
 var inverse_radius := 1.0 / maxf(radius, 0.0001)
 for i in points.size():
  var before: Vector3 = points[maxi(0, i - 1)]
  var after: Vector3 = points[mini(points.size() - 1, i + 1)]
  # True distance keeps the join the same size even when a frame spans several radii.
  if i > 0 and behind_head < JOIN_RADII:
   behind_head += before.distance_to(points[i]) * inverse_radius
  var tangent := (before - after).normalized()
  var facing := (camera.global_position - to_global(points[i])).normalized()
  var side := tangent.cross(facing).normalized()
  if side.length_squared() < 0.01:
   side = previous_side if previous_side != Vector3.ZERO else Vector3.RIGHT
  if previous_side.dot(side) < 0.0:
   side = -side
  previous_side = side
  var age := clampf(ages[i] / LIFETIME, 0.0, 1.0)
  var offset := side * radius * (1.05 + age * 0.4)
  # Fade the oldest end even while a new trail is still filling its lifetime.
  var tail_fade := pow(float(i) / float(points.size() - 1), 4.0)
  ribbon.surface_set_color(Color(tint, 1.0 - maxf(age, tail_fade)))
  ribbon.surface_set_uv(Vector2(behind_head, 0.0))
  ribbon.surface_add_vertex(points[i] - offset)
  ribbon.surface_set_uv(Vector2(behind_head, 1.0))
  ribbon.surface_add_vertex(points[i] + offset)
 ribbon.surface_end()

