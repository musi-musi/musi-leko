#version 450 core

layout (location = 0) in vec2 position;
layout (location = 1) in vec3 color;

out vec3 frag_color;

uniform mat4 proj;

void main() {
    vec4 pos;
    pos.xy = position;
    pos.z = 0.5;
    pos.w = 1;
    gl_Position = proj * pos;
    frag_color = color;
}
