in vec4 frag_position;
in vec3 frag_normal;
flat in float frag_ao[4];
in vec2 frag_uv_face;
in vec2 frag_uv_texture;
flat in int frag_outline;

layout (location = 0) out vec4 g_color;
layout (location = 1) out vec4 g_outline;
layout (location = 2) out vec4 g_position;
layout (location = 3) out vec3 g_normal;
layout (location = 4) out vec2 g_uv;
layout (location = 5) out vec2 g_lighting;

uniform vec4 selection_outline_color = vec4(1, 0, 1, 1);

// 0 --- 1
// | \   |   ^
// |  \  |   |
// |   \ |   v
// 2 --- 3   + u ->
void main() {
    float ao = mix(
        mix(frag_ao[2], frag_ao[3], frag_uv_face.x),
        mix(frag_ao[0], frag_ao[1], frag_uv_face.x),
        frag_uv_face.y
    );
    g_outline = selection_outline_color * float(frag_outline);
    g_uv = frag_uv_texture;
    g_position = frag_position;
    g_normal = frag_normal;
    g_lighting = vec2(1, ao);
}
