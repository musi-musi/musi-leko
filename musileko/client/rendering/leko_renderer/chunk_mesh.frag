in vec4 frag_position;
in vec3 frag_normal;
in float frag_light;
in flat float frag_ao[4];
in vec2 frag_uv_face;
in vec2 frag_uv_texture;
in float frag_fog;
in flat int frag_outline;

layout (location = 0) out vec4 g_color;
layout (location = 1) out vec4 g_outline;
layout (location = 2) out vec4 g_position;
layout (location = 3) out vec3 g_normal;
layout (location = 4) out vec2 g_uv;

uniform vec4 selection_outline_color = vec4(1, 0, 1, 1);

uniform float light_strength = 0.5;
uniform float ao_strength = 0.25;
uniform float resolution = 8.0;
uniform sampler2D perlin;
uniform float noise_warp_strength = 0.001;
uniform float time;
uniform float animation_speed = 0;
uniform int color_bands = 3;

float band(float x, int bands) {
    return floor(x * bands) / bands;
}

// 0 --- 1
// | \   |   ^
// |  \  |   |
// |   \ |   v
// 2 --- 3   + u ->
void main() {
    // vec2 uv = floor(frag_uv_face * resolution);
    // bool checker1 = (uint(uv.x) % 2 == 0) != (uint(uv.y) % 2 == 0);
    // bool checker4 = ((uint(uv.x) >> 2) % 2 == 0) != ((uint(uv.y) >> 2) % 2 == 0);
    // float color = mix(0.95, 1.0, float(checker1));
    // color *= mix(0.85, 1.0, float(checker4));
    // uv = (uv + vec2(0.5)) / resolution;
    float ao = mix(
        mix(frag_ao[2], frag_ao[3], frag_uv_face.x),
        mix(frag_ao[0], frag_ao[1], frag_uv_face.x),
        frag_uv_face.y
    );
    ao = mix(1, band(ao - 0.1, 4), ao_strength);
    float light = mix(1, frag_light, light_strength);
    vec2 anim = vec2(time * animation_speed);
    float v_warp = texture(perlin, frag_uv_texture + vec2(24.354, 56.5463)).x;
    vec2 warp = vec2(0, v_warp) * noise_warp_strength;
    float noise = texture(perlin, frag_uv_texture * vec2(0.5, 2) + warp).x;
    // float noise = texture(perlin, frag_uv_texture + anim + uv_warp * noise_warp_strength).x;
    noise = (noise + 1) / 2;

    // noise = clamp((noise + 0.35) * 100, -1, 1);
    float color = mix(0.3, 0.35, band(noise, color_bands));
    // float color = (noise + 1) / 2;
    g_color.xyz = mix(vec3(color * ao * light), vec3(0), frag_fog);
    g_color.w = 1;
    g_outline = selection_outline_color * float(frag_outline);

    g_position = frag_position;
    g_normal = frag_normal;
}