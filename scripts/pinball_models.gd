extends RefCounted
## Collisionless Sonic-inspired hardware. All colours are replaceable palette slots.
const SURFACE = preload("res://scripts/pinball_surface.gdshader")
const PALETTES := {
 "default": ["dc3546", "164ea1", "ffd45b", "f5f4df", "42ce89", "182b42"],
 "green_hill": ["e54a42", "246fc5", "ffcf50", "fff4dd", "48d293", "243e49"],
 "chemical_plant": ["eb426f", "473492", "ffd354", "e0faff", "39dfcc", "242943"],
 "rooftop_run": ["c64b3d", "247d86", "eab85d", "fff0d2", "46b7bb", "36414a"],
 "casino_night": ["ed377e", "382b9e", "ffe05e", "f5ecff", "88ee47", "25203f"],
 "sky_sanctuary": ["48a9b2", "487bb6", "e5c27b", "fff9e5", "7ce5d0", "35475b"],
 "ice_cap": ["6c9ee8", "35568c", "9ef5ff", "f2fbff", "8bdded", "233a59"],
 "lava_reef": ["a34d42", "226f76", "c1a36a", "fff1cf", "59b7ad", "332a3b"],
}
const SLOTS := ["rubber", "face", "trim", "mark", "paddle", "base"]

static func materials(theme_id: String, overrides: Dictionary = {}) -> Dictionary:
 var colors: Array = PALETTES.get(theme_id, PALETTES.default)
 var result := {}
 for i in SLOTS.size():
  var mat := ShaderMaterial.new()
  mat.shader = SURFACE
  mat.set_shader_parameter("paint", overrides.get(SLOTS[i], Color(colors[i])))
  mat.set_shader_parameter("metal", 0.65 if SLOTS[i] == "trim" else 0.0)
  result[SLOTS[i]] = mat
 return result

static func disc(p, parent: Node3D, radius: float, height: float, y: float, mat: Material, taper := 1.0) -> void:
 var mesh: CylinderMesh = p.cylinder(radius, height)
 mesh.radial_segments = 48
 mesh.top_radius *= taper
 p.mesh_node(mesh, mat, Vector3(0, y + height * 0.5, 0), parent)

static func round_bumper(p, parent: Node3D, radius: float, height_scale: float, m: Dictionary) -> void:
 parent.name = "StarBumper"
 disc(p, parent, radius * 0.82, 0.08 * height_scale, 0.0, m.base)
 disc(p, parent, radius, 0.20 * height_scale, 0.08 * height_scale, m.rubber)
 disc(p, parent, radius, 0.07 * height_scale, 0.28 * height_scale, m.rubber, 0.91)
 disc(p, parent, radius * 0.88, 0.035 * height_scale, 0.35 * height_scale, m.trim)
 disc(p, parent, radius * 0.73, 0.025 * height_scale, 0.385 * height_scale, m.face)
 var star := PackedVector2Array()
 for i in 10:
  star.append(Vector2.from_angle(-PI / 2.0 + i * TAU / 10.0) * radius / p.SCALE * (0.57 if i % 2 == 0 else 0.25))
 p.mesh_node(p._prism(star, 0.009 * height_scale, m.mark, m.mark), null, Vector3(0, 0.413 * height_scale, 0), parent)
 for i in 8:
  var angle := i * TAU / 8.0
  var bolt: MeshInstance3D = p.mesh_node(p.cylinder(radius * 0.035, 0.008 * height_scale), m.mark, Vector3(cos(angle) * radius * 0.81, 0.39 * height_scale, sin(angle) * radius * 0.81), parent)
  bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func triangle_bumper(p, parent: Node3D, points: PackedVector2Array, height: float, m: Dictionary) -> void:
 p.mesh_node(p._prism(points, height * 0.65, m.base, m.rubber), null, Vector3.ZERO, parent)
 var center := Vector2.ZERO
 for point in points: center += point
 center /= points.size()
 for layer in [{"scale": 1.0, "y": 0.65, "mat": m.rubber}, {"scale": 0.86, "y": 0.80, "mat": m.trim}, {"scale": 0.73, "y": 0.90, "mat": m.face}]:
  var inset := PackedVector2Array()
  for point in points: inset.append(center + (point - center) * float(layer.scale))
  p.mesh_node(p._prism(inset, height * 0.12, layer.mat, layer.mat), null, Vector3(0, height * float(layer.y), 0), parent)
 var mark := PackedVector2Array()
 for point in points: mark.append(center + (point - center) * 0.35)
 p.mesh_node(p._prism(mark, height * 0.025, m.mark, m.mark), null, Vector3(0, height * 1.025, 0), parent)

static func flipper(p, parent: Node3D, length: float, radius: float, h: float, m: Dictionary) -> void:
 parent.name = "StripedFlipper"
 p._paddle(length, radius * 0.90, 0.06 * h, 0.0, m.base, parent)
 p._paddle(length, radius, 0.13 * h, 0.06 * h, m.rubber, parent)
 p._paddle(length, radius * 0.88, 0.045 * h, 0.19 * h, m.trim, parent)
 p._paddle(length, radius * 0.70, 0.025 * h, 0.235 * h, m.paddle, parent)
 disc(p, parent, radius * 0.62, 0.016 * h, 0.262 * h, m.base)
 disc(p, parent, radius * 0.43, 0.02 * h, 0.278 * h, m.trim)
 disc(p, parent, radius * 0.16, 0.006 * h, 0.298 * h, m.mark)
 for fraction in [0.37, 0.55, 0.73]:
  var x: float = length * fraction / p.SCALE
  var r: float = radius * 0.55 / p.SCALE
  var chevron := PackedVector2Array([Vector2(x - r * 0.6, -r), Vector2(x, -r), Vector2(x + r * 0.8, 0), Vector2(x, r), Vector2(x - r * 0.6, r), Vector2(x + r * 0.2, 0)])
  p.mesh_node(p._prism(chevron, 0.004 * h, m.mark, m.mark), null, Vector3(0, 0.263 * h, 0), parent)
