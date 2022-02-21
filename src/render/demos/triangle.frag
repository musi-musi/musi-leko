#version 450 core

in vec3 frag_color;

out vec4 FragColor;

void main() {
    FragColor.xyz = frag_color;
    FragColor.w = 1;
}