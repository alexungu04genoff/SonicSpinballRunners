// Derivative frame supports authored meshes without tangents, curved routes,
// and nonuniformly scaled surfaces. UV V points down; OpenGL normal Y points up.
uniform sampler2D relief_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float relief_strength : hint_range(0.0, 2.0) = 1.0;
vec3 relief(vec3 position, vec3 geometric, vec2 coordinates, vec2 sample_uv) {
 vec3 n = normalize(geometric);
 vec3 dx = dFdx(position), dy = dFdy(position);
 vec2 sx = dFdx(coordinates), sy = dFdy(coordinates);
 float determinant = sx.x * sy.y - sx.y * sy.x;
 vec3 map = textureGrad(relief_normal, sample_uv, sx, sy).xyz * 2.0 - 1.0;
 // RG reconstruction also supports Godot's normal-map texture compression.
 map.z = sqrt(max(1.0 - dot(map.xy, map.xy), 0.001));
 if (abs(determinant) < 0.00000001 || relief_strength == 0.0) { return n; }
 vec3 t = (dx * sy.y - dy * sx.y) / determinant;
 vec3 b = (dy * sx.x - dx * sy.x) / determinant;
 t = normalize(t - n * dot(n, t));
 b = normalize(b - n * dot(n, b));
 return normalize(n * map.z + (t * map.x - b * map.y) * relief_strength);
}
