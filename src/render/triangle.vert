#version 450 core

layout (location = 0) in vec2 position;
layout (location = 1) in vec3 color;

out vec3 frag_color;

void main() {
    gl_Position.xy = position;
    gl_Position.z = 0.5;
    gl_Position.w = 1;
    frag_color = color;
}
