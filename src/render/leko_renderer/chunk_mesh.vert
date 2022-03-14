layout (location = 0) in uint base;

uniform mat4 proj;
uniform mat4 view;

uniform ivec3 chunk_position;

uniform vec3 light;

uniform float fog_start = 32;
uniform float fog_end = 64;


out float frag_light;
out vec4 frag_ao;
out vec2 frag_uv;
out float frag_fog;

void main() {
    uint b = base;
    uint ao = b & 0xFF;
    b >>= 8;
    uint n = b & 0x7;
    b >>=3;
    vec3 position = vec3(
        float(b >> (CHUNK_WIDTH_BITS * 2) & (CHUNK_WIDTH - 1)),
        float(b >> (CHUNK_WIDTH_BITS * 1) & (CHUNK_WIDTH - 1)),
        float(b >> (CHUNK_WIDTH_BITS * 0) & (CHUNK_WIDTH - 1))
    );
    position += cube_positions[n][gl_VertexID];
    vec3 normal = cube_normals[n];
    frag_light = abs(dot(normal, light));
    frag_ao.x = (3 - float(ao >> 0 & 0x3)) / 3.0;
    frag_ao.y = (3 - float(ao >> 2 & 0x3)) / 3.0;
    frag_ao.z = (3 - float(ao >> 4 & 0x3)) / 3.0;
    frag_ao.w = (3 - float(ao >> 6 & 0x3)) / 3.0;
    frag_uv = cube_uvs[gl_VertexID];
    vec4 pos;
    pos.xyz = position + vec3(chunk_position) * CHUNK_WIDTH;
    pos.w = 1;
    gl_Position = proj * view * pos;

    vec4 eye = inverse(view) * vec4(0, 0, 0, 1);
    vec3 eye_to_pos = abs(pos.xyz - eye.xyz);

    // float dist = max(max(eye_to_pos.x, eye_to_pos.y), eye_to_pos.z);
    float dist = length(eye_to_pos);
    frag_fog = clamp((dist - fog_start) / (fog_end - fog_start), 0, 1);
}