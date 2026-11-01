extends RefCounted
## Optional table-direction haze. Each viewport owns one lazy, collisionless pass.
const DEFAULTS := {
 "directional_fog/enabled": false,
 "directional_fog/angle": 0.0,
 "directional_fog/start": 0.0,
 "directional_fog/length": 600.0,
 "directional_fog/density": 0.65,
 "directional_fog/curve": 1.5,
 "directional_fog/color": Color(0.7, 0.8, 0.9),
 "directional_fog/brightness": 1.0,
}
const FIELDS := [
 ["Directional fog enabled", "directional_fog/enabled", "bool"],
 ["Angle (0 = north)", "directional_fog/angle", "number", -180.0, 180.0, 1.0],
 ["Start (table px)", "directional_fog/start", "number", -3000.0, 3000.0, 10.0],
 ["Fade length (table px)", "directional_fog/length", "number", 10.0, 6000.0, 10.0],
 ["Maximum density", "directional_fog/density", "number", 0.0, 1.0, 0.01],
 ["Density curve", "directional_fog/curve", "number", 0.1, 8.0, 0.05],
 ["Fog color", "directional_fog/color", "color"],
 ["Fog brightness", "directional_fog/brightness", "number", 0.0, 3.0, 0.01],
]

static func apply(camera: Camera3D, values: Dictionary) -> void:
 if not is_instance_valid(camera): return
 var enabled: bool = values.get("directional_fog/enabled", false)
 var quad := camera.get_node_or_null("DirectionalFog") as MeshInstance3D
 if quad == null:
  if not enabled: return
  quad = MeshInstance3D.new()
  quad.name = "DirectionalFog"
  var mesh := QuadMesh.new()
  mesh.size = Vector2(2, 2)
  quad.mesh = mesh
  quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  quad.extra_cull_margin = 16384.0
  quad.ignore_occlusion_culling = true
  var material := ShaderMaterial.new()
  material.shader = preload("res://scripts/atmosphere/directional_fog.gdshader")
  material.render_priority = 120
  quad.material_override = material
  camera.add_child(quad)
 quad.visible = enabled
 if not enabled: return
 var material := quad.material_override as ShaderMaterial
 for key: String in DEFAULTS:
  if key.ends_with("/enabled"): continue
  material.set_shader_parameter("fog_" + key.get_slice("/", 1), values.get(key, DEFAULTS[key]))

static func blend(before: Dictionary, after: Dictionary, weight: float) -> Dictionary:
 var result := {}
 for key: String in DEFAULTS:
  var a: Variant = before.get(key, DEFAULTS[key])
  var b: Variant = after.get(key, DEFAULTS[key])
  if key.ends_with("/enabled"): result[key] = a or b
  elif key.ends_with("/angle"): result[key] = rad_to_deg(lerp_angle(deg_to_rad(a), deg_to_rad(b), weight))
  elif key.ends_with("/density"):
   result[key] = lerpf(float(a) if before.get("directional_fog/enabled", false) else 0.0, float(b) if after.get("directional_fog/enabled", false) else 0.0, weight)
  else: result[key] = lerp(a, b, weight)
 result["directional_fog/enabled"] = result["directional_fog/enabled"] and result["directional_fog/density"] > 0.0
 return result
