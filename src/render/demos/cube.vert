layout (location = 0) in vec3 position;
layout (location = 1) in vec3 normal;
layout (location = 2) in vec2 uv;

uniform mat4 proj;
uniform mat4 view;
uniform vec3 light;

// out vec3 frag_color;
out float frag_light;
out vec2 frag_uv;

void main() {
    vec4 pos;
    pos.xyz = position;
    pos.w = 1;
    frag_light = abs(dot(normal, light));
    // if (length(normal) < 0) {
    //     frag_color = vec3(1) + normal;
    // }
    // else {
    //     frag_color = normal;
    // }
    gl_Position = proj * view * pos;
    frag_uv = uv;

}
