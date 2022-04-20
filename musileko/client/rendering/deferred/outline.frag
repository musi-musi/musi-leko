layout (location = 0) out vec4 g_color;
layout (location = 1) out vec4 g_outline;
layout (location = 2) out vec4 g_position;
layout (location = 3) out vec4 g_normal;
layout (location = 4) out vec4 g_uv;

uniform vec4 color;

void main() {
    g_outline = color;
}