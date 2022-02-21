#version 450 core

// in vec3 frag_color;
in float frag_light;

out vec4 FragColor;

void main() {
    FragColor.xyz = vec3(frag_light);
    FragColor.w = 1;
}