shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform mat3 ring_rotation;
uniform vec4 paint : source_color;
uniform float surface_roughness;
uniform float surface_metallic;
uniform float surface_specular;
uniform vec4 emission_color : source_color;
uniform float emission_scale;

void vertex() {
 VERTEX = ring_rotation * VERTEX;
 NORMAL = ring_rotation * NORMAL;
 TANGENT = ring_rotation * TANGENT;
 BINORMAL = ring_rotation * BINORMAL;
}

void fragment() {
 ALBEDO = paint.rgb;
 ROUGHNESS = surface_roughness;
 METALLIC = surface_metallic;
 SPECULAR = surface_specular;
 EMISSION = emission_color.rgb * emission_scale;
}
