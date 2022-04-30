in vec2 frag_uv;

uniform sampler2D g_color;
uniform sampler2D g_outline;
uniform sampler2D g_position;
uniform sampler2D g_normal;
uniform sampler2D g_uv;
uniform sampler2D g_lighting;

uniform vec2 screen_size;

uniform float outline_radius = 1;

uniform float min_edge_dist = 0.99;

uniform mat4 proj;
uniform mat4 view;

uniform float fog_falloff = 5;
uniform float fog_start = 1.5;
uniform float fog_end = 3.75;

uniform vec3 light_direction;
uniform float light_strength = 0.5;
uniform float ao_strength = 0.5;

#define UV_SCALE (1.0/32.0)
#define WARP_SCALE 0.001

uniform sampler2D tex_noise;
uniform vec2 warp_uv_scale = vec2(1);
uniform vec2 warp_amount = vec2(0, 1);
uniform vec2 noise_uv_scale = vec2(0.5, 2);

uniform vec4 pallete_a = vec4(0.27, 0.20, 0.30, 1);
uniform vec4 pallete_b = vec4(0.35, 0.25, 0.32, 1);
uniform vec4 pallete_dark = vec4(0.07, 0.03, 0.1, 1);

out vec4 out_color;

#define BANDS(x, bands) (floor(x * bands) / bands)

vec4 calcMaterial(float light_level) {
    vec2 uv = texture2D(g_uv, frag_uv).xy * UV_SCALE;
    vec2 warp = texture2D(tex_noise, uv * warp_uv_scale).xy * warp_amount * WARP_SCALE;
    float noise = texture2D(tex_noise, uv * noise_uv_scale + warp).x;
    noise = (noise + 1) / 2;
    vec4 color = mix(pallete_a, pallete_b, BANDS(noise, 3));
    color = mix(pallete_dark, color, light_level);
    return color;
}

float calcLight() {
    
    vec2 lighting = texture2D(g_lighting, frag_uv).xy;
    vec3 normal = texture2D(g_normal, frag_uv).xyz;

    float dir_light = abs(dot(normal, light_direction));
    dir_light = mix(1, dir_light, light_strength);
    float ao = mix(1, lighting.y, ao_strength);
    return dir_light * ao;
}

vec4 calcEdge() {
    vec4 self_pos = texture2D(g_position, frag_uv);
    float dx = 1 / screen_size.x;
    float dy = 1 / screen_size.y;
    vec2 offsets[4];
    offsets[0] = vec2( 1,  0);
    offsets[1] = vec2(-1,  0);
    offsets[2] = vec2( 0,  1);
    offsets[3] = vec2( 0, -1);
    float max_depth_dist = 0;
    float max_pos_dist = 0;
    for (int i = 0; i < 4; i ++) {
        vec4 neighbor_pos = texture2D(g_position, frag_uv + (offsets[i] / screen_size));
        max_depth_dist = max(max_depth_dist, self_pos.w - neighbor_pos.w);
        max_pos_dist = max(max_pos_dist, length(self_pos.xyz - neighbor_pos.xyz));
    }
    float factor = 0;
    if (max_depth_dist > min_edge_dist && max_pos_dist > min_edge_dist) {
        factor = 1;
    }
    return vec4(1, 1, 1, 0) * 0.1 * factor;
}

vec4 calcOutline() {
    vec4 self = texture2D(g_outline, frag_uv);
    vec2 offsets[8];
    offsets[0] = vec2( 1,  0);
    offsets[1] = vec2(-1,  0);
    offsets[2] = vec2( 0,  1);
    offsets[3] = vec2( 0, -1);
    offsets[4] = vec2( 1,  1);
    offsets[5] = vec2( 1, -1);
    offsets[6] = vec2(-1,  1);
    offsets[7] = vec2(-1, -1);
    vec4 outline_color = vec4(0);
    int count = 0;
    vec2 delta = vec2(outline_radius) / screen_size;
    for (int i = 0; i < 8; i ++) {
        vec2 offset = normalize(offsets[i]) * delta;
        vec4 neighbor = texture2D(g_outline, frag_uv + offset);
        outline_color += neighbor * neighbor.w;
        count += int(neighbor.w);
    }
    if (count == 0) {
        return vec4(0);
    }
    else {
        return (outline_color / count) * (1 - self.w);
    }
}

float calcFog(vec3 position) {
    vec4 eye = inverse(view) * vec4(0, 0, 0, 1);
    vec3 eye_to_pos = abs(position - eye.xyz);

    float dist = length(eye_to_pos) / 32;
    dist = (dist - fog_start) / (fog_end - fog_start);
    return clamp(pow(fog_falloff, dist - 1), 0, 1);
}

void main() {
    vec2 pixel = frag_uv * screen_size;
    vec2 center = screen_size / 2;
    vec2 r = abs(pixel - center);

    if (max(r.x, r.y) < 2) {
        // crosshair
        out_color = vec4(1);
    }
    else {
        vec4 position = texture2D(g_position, frag_uv);
        if (position.w == 0) {
            discard;
        }
        vec4 outline = calcOutline();
        float light = calcLight();
        float fog = calcFog(position.xyz);
        vec3 color = calcMaterial(light).xyz;
        color = mix(color, vec3(0), fog);
        out_color.xyz = mix(color, outline.xyz, outline.w);
    }
}
