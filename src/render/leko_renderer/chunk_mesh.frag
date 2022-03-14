in float frag_light;
in flat float frag_ao[4];
in vec2 frag_uv;
in float frag_fog;

out vec4 FragColor;

uniform float light_strength = 0.5;
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
    float color = mix(0.95, 1.0, float(checker1));
    color *= mix(0.85, 1.0, float(checker4));
    uv = (uv + vec2(0.5)) / resolution;
    float ao = mix(
        mix(frag_ao[2], frag_ao[3], frag_uv.x),
        mix(frag_ao[0], frag_ao[1], frag_uv.x),
        frag_uv.y
    );
    ao = mix(1, ao, ao_strength);
    float light = mix(1, frag_light, light_strength);
    FragColor.xyz = vec3(color * ao * light * (1 - frag_fog));
    // FragColor.xyz = vec3(color * light * (1 - frag_fog));
    FragColor.w = 1;
}