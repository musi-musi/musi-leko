in vec2 frag_uv;

uniform sampler2D buf_color;
uniform sampler2D buf_outline;

uniform vec2 screen_size;

uniform float outline_radius = 3;

out vec4 FragColor;

vec4 calcOutline() {
    vec4 self = texture(buf_outline, frag_uv);
    float dx = outline_radius / screen_size.x;
    float dy = outline_radius / screen_size.y;
    vec4 neighbors[8];
    neighbors[0] = texture(buf_outline, frag_uv + vec2( dx,   0));
    neighbors[1] = texture(buf_outline, frag_uv + vec2(-dx,   0));
    neighbors[2] = texture(buf_outline, frag_uv + vec2(  0,  dy));
    neighbors[3] = texture(buf_outline, frag_uv + vec2(  0, -dy));
    neighbors[4] = texture(buf_outline, frag_uv + vec2( dx,  dy));
    neighbors[5] = texture(buf_outline, frag_uv + vec2( dx, -dy));
    neighbors[6] = texture(buf_outline, frag_uv + vec2(-dx,  dy));
    neighbors[7] = texture(buf_outline, frag_uv + vec2(-dx, -dy));
    vec4 outline_color = vec4(0);
    int count = 0;
    for (int i = 0; i < 8; i ++) {
        outline_color += neighbors[i] * neighbors[i].w;
        count += int(neighbors[i].w);
    }
    if (count == 0) {
        return vec4(0);
    }
    else {
        return (outline_color / count) * (1 - self.w);
    }
}

void main() {
    vec4 color = texture(buf_color, frag_uv);
    // vec4 outline = texture(buf_outline, frag_uv);
    vec4 outline = calcOutline();

    vec2 pixel = frag_uv * screen_size;
    vec2 center = screen_size / 2;
    vec2 r = abs(pixel - center);

    if (max(r.x, r.y) < 2) {
        FragColor = vec4(1);
    }
    else {
        FragColor = mix(color, outline, outline.w);
    }
}