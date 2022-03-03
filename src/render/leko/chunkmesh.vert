layout (location = 0) in uint base;

uniform mat4 proj;
uniform mat4 view;
uniform vec3 light;

out float frag_light;

void main() {
    uint n = base & 0x7;
    vec3 position = vec3(
        float(base >> (3 + CHUNK_WIDTH_BITS * 2) & (CHUNK_WIDTH - 1)),
        float(base >> (3 + CHUNK_WIDTH_BITS * 1) & (CHUNK_WIDTH - 1)),
        float(base >> (3 + CHUNK_WIDTH_BITS * 0) & (CHUNK_WIDTH - 1))
    );
    position += cube_positions[n][gl_VertexID];
    vec3 normal = cube_normals[n];
    frag_light = abs(dot(normal, light));
    vec4 pos;
    pos.xyz = position;
    pos.w = 1;
    gl_Position = proj * view * pos;
}