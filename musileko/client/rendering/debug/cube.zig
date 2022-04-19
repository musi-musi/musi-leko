const std = @import("std");

const debug = @import(".zig");
const rendering = @import("../.zig");

const client = @import("../../.zig");
const gl = client.gl;
const nm = client.nm;

const Vec3 = nm.Vec3;
const Cardinal3 = nm.Cardinal3;

const Shader = rendering.Shader(&.{
        gl.uniform("proj", .mat4),
        gl.uniform("view", .mat4),
        gl.uniform("light", .vec3),

        gl.uniform("position", .vec3),
        gl.uniform("radius", .float),

        gl.uniform("color", .vec3),
    },
    @embedFile("cube.vert"),
    @embedFile("cube.frag"),
    &.{},
);

const Vertex = struct {
    position: [3]f32,
    normal: [3]f32,
};

const VertexBuffer = gl.VertexBuffer(Vertex);

const Array = gl.Array(struct {
    verts: gl.BufferBind(Vertex, .{}),
}, .uint);

var _shader: Shader = undefined;
var _array: Array = undefined;
var _vertex_buffer: VertexBuffer = undefined;
var _index_buffer: Array.IndexBuffer = undefined;

//     0 --- 1
//     | \   |   ^
//     |  \  |   |
//     |   \ |   v
//     2 --- 3   + u -- >

pub fn init() !void {
    _shader = try Shader.init();
    _array = Array.init();
    _vertex_buffer = VertexBuffer.init();
    _index_buffer = Array.IndexBuffer.init();

    @setEvalBranchQuota(1_000_000);
    const verts = comptime
        generateFace(.x_pos) ++
        generateFace(.x_neg) ++
        generateFace(.y_pos) ++
        generateFace(.y_neg) ++
        generateFace(.z_pos) ++
        generateFace(.z_neg);

    _vertex_buffer.data(&verts, .static_draw);

    var indices: [36]u32 = undefined;
    var i: u32 = 0;
    var f: u32 = 0;
    while (i < 36) : (i += 6) {
        indices[i + 0] = f + 0;
        indices[i + 1] = f + 1;
        indices[i + 2] = f + 3;
        indices[i + 3] = f + 0;
        indices[i + 4] = f + 3;
        indices[i + 5] = f + 2;
        f += 4;
    }

    _index_buffer.data(&indices, .static_draw);

    _array.buffer_binds.verts.bindBuffer(_vertex_buffer);
    _array.bindIndexBuffer(_index_buffer);
}

pub fn deinit() void {
    _shader.deinit();
    _array.deinit();
    _vertex_buffer.deinit();
    _index_buffer.deinit();
}

pub fn startDraw() void {
    _shader.use();
    _array.bind();
}

pub fn setProjection(proj: nm.Mat4) void {
    _shader.uniforms.set("proj", proj.v);
}

pub fn setView(view: nm.Mat4) void {
    _shader.uniforms.set("view", view.v);
}

pub fn setLight(light: Vec3) void {
    _shader.uniforms.set("light", light.v);
}

pub fn draw(position: Vec3, radius: f32, color: Vec3) void {
    _shader.uniforms.set("position", position.v);
    _shader.uniforms.set("radius", radius);
    _shader.uniforms.set("color", color.v);
    gl.drawElements(.triangles, 36, .uint);
}


fn generateFace(comptime n: Cardinal3) [4]Vertex {
    const vec = Vec3.unitSigned;
    const up = cardU(n);
    const vp = cardV(n);
    const un = up.neg();
    const vn = vp.neg();
    return .{
        .{
            .position = vec(n).add(vec(un)).add(vec(vp)).v,
            .normal = vec(n).v,
        },
        .{
            .position = vec(n).add(vec(up)).add(vec(vp)).v,
            .normal = vec(n).v,
        },
        .{
            .position = vec(n).add(vec(un)).add(vec(vn)).v,
            .normal = vec(n).v,
        },
        .{
            .position = vec(n).add(vec(up)).add(vec(vn)).v,
            .normal = vec(n).v,
        },
    };
}

fn cardU(normal: Cardinal3) Cardinal3 {
    return switch (normal) {
        .x_pos => .z_neg,
        .x_neg => .z_pos,
        .y_pos => .z_pos,
        .y_neg => .z_neg,
        .z_pos => .x_pos,
        .z_neg => .x_neg,
    };
}

fn cardV(normal: Cardinal3) Cardinal3 {
    return switch (normal) {
        .x_pos => .y_pos,
        .x_neg => .y_pos,
        .y_pos => .x_pos,
        .y_neg => .x_pos,
        .z_pos => .y_pos,
        .z_neg => .y_pos,
    };
}