layout (location = 0) in vec3 vertex;

uniform mat4 proj;
uniform mat4 view;

uniform ivec3 position;

void main() {
    gl_Position = proj * view * (vec4(position, 1) + vec4(vertex, 0));
}