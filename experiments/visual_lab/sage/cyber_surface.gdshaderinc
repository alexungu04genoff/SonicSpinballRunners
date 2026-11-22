uniform float clock = 0.0;
uniform float assembly : hint_range(0.0, 1.0) = 1.0;
varying vec3 local_normal;

float noise_cell(vec2 index) {
    return fract(sin(dot(index, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
    local_normal = NORMAL;
    float band = floor((NORMAL.y + 1.0) * 5.0);
    float tick = floor(clock * 8.0);
    float burst = step(0.81, noise_cell(vec2(tick, band)));
    VERTEX.x += burst * (noise_cell(vec2(tick + 7.0, band)) - 0.5) * 0.095;
}

// Panel ID, printed circuit, lit packet, and clear-panel coverage.
vec4 circuit_sample(vec3 normal) {
    vec2 coord = vec2(atan(normal.x, normal.z) / 6.2831853 + 0.5, acos(clamp(normal.y, -1.0, 1.0)) / 3.141593);
    coord.x += clock * 0.21;
    vec2 panel = coord * vec2(18.0, 13.0);
    vec2 cell = floor(panel);
    vec2 uv = fract(panel);
    vec2 wrapped = vec2(mod(cell.x, 18.0), cell.y);
    float id = noise_cell(wrapped);
    float circuit = step(uv.y, 0.20) * step(0.17, id);
    float hinge = step(uv.x, 0.13) * step(0.64, id) * step(uv.y, 0.64);
    float strip = fract(coord.y * 3.0 + 0.08 * sin(coord.x * 6.2831853 + floor(cell.y * 0.4) * 0.28));
    float belt = (1.0 - smoothstep(0.04, 0.16, strip)) * step(0.24, id);
    float trace = clamp(max(circuit * 0.62 + hinge * 0.45, belt), 0.0, 1.0);
    float packet = step(0.77, noise_cell(wrapped + vec2(floor(clock * 6.0), 0.0)))
                 * step(0.28, uv.x) * step(uv.x, 0.93) * step(0.42, uv.y) * step(uv.y, 0.67);
    vec2 window = smoothstep(vec2(0.03), vec2(0.16), uv) * (1.0 - smoothstep(vec2(0.84), vec2(0.97), uv));
    return vec4(id, trace, packet, step(0.76, id) * window.x * window.y);
}
