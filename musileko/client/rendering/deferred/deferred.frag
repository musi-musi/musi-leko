in vec2 frag_uv;

uniform sampler2D g_color;
uniform sampler2D g_outline;
uniform sampler2D g_position;
uniform sampler2D g_normal;
uniform sampler2D g_uv;

uniform vec2 screen_size;

uniform float outline_radius = 1;

out vec4 out_color;

vec4 calcOutline() {
    vec4 self = texture(g_outline, frag_uv);
    float dx = outline_radius / screen_size.x;
    float dy = outline_radius / screen_size.y;
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
        vec4 neighbor = texture(g_outline, frag_uv + offset);
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

void main() {
    vec4 color = texture(g_color, frag_uv);
    // vec4 outline = texture(g_outline, frag_uv);
    vec4 outline = calcOutline();

    vec2 pixel = frag_uv * screen_size;
    vec2 center = screen_size / 2;
    vec2 r = abs(pixel - center);

    if (max(r.x, r.y) < 2) {
        out_color = vec4(1);
    }
    else {
        out_color = mix(color, outline, outline.w);
    }
}
