#version 450 core

uniform sampler2D maintex;

// in vec3 frag_color;
in float frag_light;
in vec2 frag_uv;

out vec4 FragColor;

void main() {
    vec4 color = texture2D(maintex, frag_uv);
    FragColor.xyz = color.xyz * frag_light;
    FragColor.w = 1;
}