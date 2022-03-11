layout (location = 0) in vec3 vertex_position;
layout (location = 1) in vec3 normal;

uniform mat4 proj;
uniform mat4 view;

uniform vec3 light;

uniform vec3 position;
uniform float radius;

out float frag_light;

void main() {
    vec4 pos;
    pos.xyz = (vertex_position * radius) + position;
    pos.w = 1;
    gl_Position = proj * view * pos;
    frag_light = abs(dot(normal, light));
}