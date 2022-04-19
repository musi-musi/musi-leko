const std = @import("std");
const rendering = @import("../.zig");
const client = @import("../../.zig");
const gl = client.gl;
const nm = client.nm;

const Cardinal3 = nm.Cardinal3;

const Vec3 = nm.Vec3;

const Vertex = struct {
    position: [3]f32,
};

const VertexBuffer = gl.VertexBuffer(Vertex);

const Array = gl.Array(struct {
    vertex: gl.BufferBind(Vertex, .{}),
}, .uint);

var _array: Array = undefined;
var _index_buffer: Array.IndexBuffer = undefined;
var _vertex_buffer: VertexBuffer = undefined;

pub const selection_cube = struct {
    
    pub fn init() void {
        _array = Array.init();
        _index_buffer = Array.IndexBuffer.init();
        _vertex_buffer = VertexBuffer.init();

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
        _array.bindIndexBuffer(_index_buffer);
        _array.buffer_binds.vertex.bindBuffer(_vertex_buffer);
    }

    pub fn deinit() void {
        _array.deinit();
        _index_buffer.deinit();
        _vertex_buffer.deinit();
    }

    pub fn bindMesh() void {
        _array.bind();
    }

    pub fn draw() void {
        gl.drawElements(.triangles, 36, .uint);
    }

};

fn generateFace(comptime n: Cardinal3) [4]Vertex {
    const vec = Vec3.unitSigned;
    const up = cardU(n);
    const vp = cardV(n);
    const un = up.neg();
    const vn = vp.neg();
    return .{
        .{
            .position = vec(n).add(vec(un)).add(vec(vp)).addScalar(1).divScalar(2).v,
        },
        .{
            .position = vec(n).add(vec(up)).add(vec(vp)).addScalar(1).divScalar(2).v,
        },
        .{
            .position = vec(n).add(vec(un)).add(vec(vn)).addScalar(1).divScalar(2).v,
        },
        .{
            .position = vec(n).add(vec(up)).add(vec(vn)).addScalar(1).divScalar(2).v,
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
