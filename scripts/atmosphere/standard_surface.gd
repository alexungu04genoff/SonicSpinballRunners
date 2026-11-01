extends RefCounted
## Preserve the texture/vertex-color surface features used by scenery while
## exposing its final color to the shared atmosphere operation in the same pass.
static var programs := {}
const SOURCE := """
shader_type spatial;
render_mode $MODES;
uniform vec4 surface_color : source_color = vec4(1.0);
uniform sampler2D surface_texture : source_color, hint_default_white, $FILTER, $REPEAT;
uniform float roughness = 1.0;
uniform float metallic = 0.0;
uniform float specular = 0.5;
uniform vec4 emission_color : source_color = vec4(0.0);
uniform float emission_energy = 1.0;
uniform sampler2D emission_texture : source_color, hint_default_black, $FILTER, $REPEAT;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform float triplanar_sharpness = 1.0;
varying vec3 texture_position;
varying vec3 texture_weights;
void vertex() {
 UV = UV * uv_scale.xy + uv_offset.xy;
 vec3 p = VERTEX;
 vec3 n = NORMAL;
 $WORLD
 texture_position = p * uv_scale + uv_offset;
 texture_position *= vec3(1.0, -1.0, 1.0);
 texture_weights = pow(abs(n), vec3(triplanar_sharpness));
 texture_weights /= max(dot(texture_weights, vec3(1.0)), 0.00001);
 $VERTEX_COLOR
}
vec4 sample_surface(sampler2D tex, vec2 coordinates) {
 $SAMPLE
}
void fragment() {
 vec4 texel = sample_surface(surface_texture, UV) * surface_color;
 $COLOR
 ALBEDO = texel.rgb;
 ROUGHNESS = roughness;
 METALLIC = metallic;
 SPECULAR = specular;
 EMISSION = $EMISSION;
 $ALPHA
}
"""

static func copy(source: BaseMaterial3D) -> Material:
 if source.albedo_texture == null and not source.vertex_color_use_as_albedo: return source
 var modes := ["blend_mix", "depth_draw_opaque", ["cull_back", "cull_front", "cull_disabled"][source.cull_mode], "diffuse_burley", "specular_schlick_ggx"]
 if source.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED: modes.append("unshaded")
 if source.no_depth_test: modes.append("depth_test_disabled")
 if source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS: modes.append("depth_prepass_alpha")
 var code := SOURCE.replace("$MODES", ", ".join(modes))
 code = code.replace("$FILTER", ["filter_nearest", "filter_linear", "filter_nearest_mipmap", "filter_linear_mipmap", "filter_nearest_mipmap_anisotropic", "filter_linear_mipmap_anisotropic"][source.texture_filter])
 code = code.replace("$REPEAT", "repeat_enable" if source.texture_repeat else "repeat_disable")
 code = code.replace("$WORLD", "p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; n = MODEL_NORMAL_MATRIX * NORMAL;" if source.uv1_world_triplanar else "")
 code = code.replace("$VERTEX_COLOR", "if (!OUTPUT_IS_SRGB) COLOR.rgb = mix(COLOR.rgb / 12.92, pow((COLOR.rgb + vec3(0.055)) / 1.055, vec3(2.4)), step(vec3(0.04045), COLOR.rgb));" if source.vertex_color_is_srgb else "")
 code = code.replace("$SAMPLE", "return texture(tex, texture_position.xy) * texture_weights.z + texture(tex, texture_position.xz) * texture_weights.y + texture(tex, texture_position.zy * vec2(-1.0, 1.0)) * texture_weights.x;" if source.uv1_triplanar else "return texture(tex, coordinates);")
 code = code.replace("$COLOR", "texel *= COLOR;" if source.vertex_color_use_as_albedo else "")
 var emission := "vec3(0.0)"
 if source.emission_enabled:
  emission = "(emission_color.rgb " + ("+" if source.emission_operator == BaseMaterial3D.EMISSION_OP_ADD else "*") + " sample_surface(emission_texture, UV).rgb) * emission_energy"
  if source.emission_texture == null: emission = "emission_color.rgb * emission_energy"
 code = code.replace("$EMISSION", emission)
 var alpha := "" if source.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED else "ALPHA = texel.a;"
 if source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR: alpha += " ALPHA_SCISSOR_THRESHOLD = " + str(source.alpha_scissor_threshold) + ";"
 code = code.replace("$ALPHA", alpha)
 if not programs.has(code):
  var shader := Shader.new()
  shader.code = code
  programs[code] = shader
 var result := ShaderMaterial.new()
 result.shader = programs[code]
 result.render_priority = source.render_priority
 result.next_pass = source.next_pass
 for key: StringName in source.get_meta_list(): result.set_meta(key, source.get_meta(key))
 var parameters := {"surface_color": source.albedo_color, "surface_texture": source.albedo_texture, "roughness": source.roughness, "metallic": source.metallic, "specular": source.metallic_specular, "emission_color": source.emission, "emission_energy": source.emission_energy_multiplier, "emission_texture": source.emission_texture, "uv_scale": source.uv1_scale, "uv_offset": source.uv1_offset, "triplanar_sharpness": source.uv1_triplanar_sharpness}
 for key: String in parameters: result.set_shader_parameter(key, parameters[key])
 var bindings: Dictionary = source.get_meta("atmosphere_bindings", {}).duplicate(true)
 for property: String in ["albedo_color", "emission"]:
  if not bindings.has(property): continue
  var binding: Dictionary = bindings[property]
  binding.shader = true
  bindings["surface_color" if property == "albedo_color" else "emission_color"] = binding
  bindings.erase(property)
 if not bindings.is_empty(): result.set_meta("atmosphere_bindings", bindings)
 return result
