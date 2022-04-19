layout (location = 0) in vec2 position;

out vec2 frag_uv;

void main() {
    gl_Position = vec4(position.xy, 0, 1);
    frag_uv = (position + vec2(1)) / 2;
}