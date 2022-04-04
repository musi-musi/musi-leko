in float frag_light;

uniform vec3 color;

out vec4 FragColor;

void main() {
    FragColor.xyz = frag_light * color;
    FragColor.w = 1;
}