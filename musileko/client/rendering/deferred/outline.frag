layout (location = 1) out vec4 outline_color;

uniform vec4 color;

void main() {
    outline_color = color;
}