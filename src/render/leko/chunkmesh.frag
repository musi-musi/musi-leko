in float frag_light;
in vec4 frag_ao;
in vec2 frag_uv;

out vec4 FragColor;

uniform float light_strength = 1;
uniform float ao_strength = 0.7;
uniform float resolution = 8.0;

// 0 --- 1
// | \   |   ^
// |  \  |   |
// |   \ |   v
// 2 --- 3   + u ->
void main() {
    vec2 uv = floor(frag_uv * resolution);
    bool checker1 = (uint(uv.x) % 2 == 0) != (uint(uv.y) % 2 == 0);
    bool checker4 = ((uint(uv.x) >> 2) % 2 == 0) != ((uint(uv.y) >> 2) % 2 == 0);
    float color = mix(0.9, 1.0, float(checker1));
    color *= mix(0.85, 1.0, float(checker4));
    uv = (uv + vec2(0.5)) / resolution;
    float ao = mix(
        mix(frag_ao.z, frag_ao.w, uv.x),
        mix(frag_ao.x, frag_ao.y, uv.x),
        uv.y
    );
    ao = 1 - ao * ao_strength;
    float light = 1 - frag_light * light_strength;
    FragColor.xyz = vec3(color * ao * light);
    FragColor.w = 1;
}