layout (location = 0) in uint base;

uniform mat4 proj;
uniform mat4 view;

uniform ivec3 chunk_position;

uniform vec3 light;

uniform float fog_start = 2.5 * CHUNK_WIDTH;
uniform float fog_end = 3.75 * CHUNK_WIDTH;


out float frag_light;
out flat float frag_ao[4];
out vec2 frag_uv_face;
out vec2 frag_uv_texture;
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
    frag_ao[0] = (3 - float(ao >> 0 & 0x3)) / 3.0;
    frag_ao[1] = (3 - float(ao >> 2 & 0x3)) / 3.0;
    frag_ao[2] = (3 - float(ao >> 4 & 0x3)) / 3.0;
    frag_ao[3] = (3 - float(ao >> 6 & 0x3)) / 3.0;
    frag_uv_face = cube_uvs_face[gl_VertexID];
    vec4 pos;
    pos.xyz = position + vec3(chunk_position) * CHUNK_WIDTH;
    pos.w = 1;
    gl_Position = proj * view * pos;

    frag_uv_texture.x = dot(pos.xyz, cube_umat_texture[n]);
    frag_uv_texture.y = dot(pos.xyz, cube_vmat_texture[n]);

    frag_uv_texture /= 32;

    vec4 eye = inverse(view) * vec4(0, 0, 0, 1);
    vec3 eye_to_pos = abs(pos.xyz - eye.xyz);

    // float dist = max(max(eye_to_pos.x, eye_to_pos.y), eye_to_pos.z);
    float dist = length(eye_to_pos);
    frag_fog = clamp((dist - fog_start) / (fog_end - fog_start), 0, 1);
}