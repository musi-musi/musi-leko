layout (location = 0) in uint base;

uniform mat4 proj;
uniform mat4 view;

uniform ivec3 chunk_position;

uniform float near_plane;
uniform float float_plane;

uniform float fog_falloff = 5;
uniform float fog_start = 1.5;
uniform float fog_end = 3.75;

uniform ivec3 player_selection_position;
uniform int player_selection_face;

out vec4 frag_position;
out vec3 frag_normal;
flat out float frag_ao[4];
out vec2 frag_uv_face;
out vec2 frag_uv_texture;
flat out int frag_outline;

void main() {
    uint b = base;
    int ao = int(b & uint(0xFF));
    b >>= 8;
    uint n = b & uint(0x7);
    b >>=3;
    vec3 leko_position = vec3(
        float(b >> uint(CHUNK_WIDTH_BITS * 2) & uint(CHUNK_WIDTH - 1)),
        float(b >> uint(CHUNK_WIDTH_BITS * 1) & uint(CHUNK_WIDTH - 1)),
        float(b >> uint(CHUNK_WIDTH_BITS * 0) & uint(CHUNK_WIDTH - 1))
    ) + vec3(chunk_position) * CHUNK_WIDTH;
    vec3 position = leko_position + cube_positions[n * uint(4) + uint(gl_VertexID)];
    frag_ao[0] = (3 - float(ao >> 0 & 0x3)) / 3.0;
    frag_ao[1] = (3 - float(ao >> 2 & 0x3)) / 3.0;
    frag_ao[2] = (3 - float(ao >> 4 & 0x3)) / 3.0;
    frag_ao[3] = (3 - float(ao >> 6 & 0x3)) / 3.0;
    frag_uv_face = cube_uvs_face[gl_VertexID];
    vec4 view_position = view * vec4(position, 1);
    gl_Position = proj * view_position;
    frag_position = vec4(position, view_position.z);


    frag_uv_texture.x = dot(position, cube_umat_texture[n]);
    frag_uv_texture.y = dot(position, cube_vmat_texture[n]);


    if (player_selection_position == ivec3(leko_position) && uint(player_selection_face) == n) {
        frag_outline = 1;
    }
    else {
        frag_outline = 0;
    }
    vec3 normal = cube_normals[n];
    frag_normal = normal;

}
