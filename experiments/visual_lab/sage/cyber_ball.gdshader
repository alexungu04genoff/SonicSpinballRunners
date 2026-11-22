shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;
#include "res://experiments/visual_lab/sage/cyber_surface.gdshaderinc"

uniform vec4 signal : source_color = vec4(1.0, 0.073, 0.18, 1.0);
uniform vec4 edge : source_color = vec4(1.0, 0.43, 0.59, 1.0);

void fragment() {
    vec4 marks = circuit_sample(normalize(local_normal));
    if (assembly < marks.x) { discard; }
    float rim = pow(1.0 - clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),2.3);
    ALBEDO = mix(signal.rgb, edge.rgb, 0.26 * marks.z + 0.12 * rim);
    ALPHA = (0.22 * marks.y + 0.57 * marks.z + rim * (0.035 + 0.12 * marks.y)) * smoothstep(0.0, 0.32, assembly);
}
