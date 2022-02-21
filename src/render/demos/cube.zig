const std = @import("std");
const gl = @import("gl");
const window = @import("window");
const nm = @import("nm");

const Vertex = struct {
    position: [3]f32,
    normal: [3]f32,
};

const VertexBuffer = gl.VertexBuffer(Vertex);

const Array = gl.Array(struct {
    vert: gl.BufferBind(Vertex, .{})
}, .uint);


pub const Shader = @import("../shader.zig").Shader(&.{
        gl.uniform("view", .mat4),
        gl.uniform("proj", .mat4),
        gl.uniform("light", .vec3),
    },
    @embedFile("cube.vert"),
    @embedFile("cube.frag"),
);

var array: Array = undefined;
var vertex_buffer: VertexBuffer = undefined;
var index_buffer: Array.IndexBuffer = undefined;
var shader: Shader = undefined;

pub fn init() !void {
    array = Array.init();
    vertex_buffer = VertexBuffer.init();
    index_buffer = Array.IndexBuffer.init();

    const vertices =
        faceVertices(.x_pos) ++
        faceVertices(.x_neg) ++
        faceVertices(.y_pos) ++
        faceVertices(.y_neg) ++
        faceVertices(.z_pos) ++
        faceVertices(.z_neg);
    const indices =
        faceIndices(0) ++
        faceIndices(1) ++
        faceIndices(2) ++
        faceIndices(3) ++
        faceIndices(4) ++
        faceIndices(5);

    vertex_buffer.data(&vertices, .static_draw);
    index_buffer.data(&indices, .static_draw);

    array.bindIndexBuffer(index_buffer);
    array.buffer_binds.vert.bindBuffer(vertex_buffer);
    
    shader = try Shader.init();
    
    array.bind();
    shader.use();
    
    const light = Vec3.init(.{1, 2, 3}).norm();
    shader.uniforms.set("light", light.v);

    gl.clearColor(.{0, 0, 0, 1});
    gl.clearDepth(.float, 1);
}

pub fn deinit() void {
    array.deinit();
    vertex_buffer.deinit();
    index_buffer.deinit();
    shader.deinit();
}

pub fn draw() void {
    var proj = projectionMatrix();
    shader.uniforms.set("proj", proj.v);
    gl.clear(.color_depth);
    gl.drawElements(.triangles, 6 * 6, .uint);
}

const fov: f32 = 45;

pub fn setViewMatrix(view: nm.Mat4) void {
    shader.uniforms.set("view", view.v);
}

fn projectionMatrix() nm.Mat4 {
    const width = window.width();
    const height = window.height();
    const fov_rad: f32 = std.math.pi / 180.0 * fov;
    const aspect = @intToFloat(f32, width) / @intToFloat(f32, height);
    return nm.transform.createPerspective(fov_rad, aspect, 0.001, 100);
}

const Cardinal = nm.Cardinal3;
const Vec3 = nm.Vec3;

fn faceVertices(comptime normal_cardinal: Cardinal) [4]Vertex {
    const u_cardinal = getU(normal_cardinal);
    const v_cardinal = getV(normal_cardinal);
    const n = vertPositionOffset(normal_cardinal);
    const u = [2]Vec3{
        vertPositionOffset(u_cardinal.neg()),
        vertPositionOffset(u_cardinal),
    };
    const v = [2]Vec3{
        vertPositionOffset(v_cardinal.neg()),
        vertPositionOffset(v_cardinal),
    };
    // 0 --- 1
    // | \   |   ^
    // |  \  |   |
    // |   \ |   v
    // 2 --- 3   + u ->
    return [4]Vertex {
        .{
            .position = n.add(u[0]).add(v[1]).v,
            .normal = Vec3.unitSigned(normal_cardinal).v,
        },
        .{
            .position = n.add(u[1]).add(v[1]).v,
            .normal = Vec3.unitSigned(normal_cardinal).v,
        },
        .{
            .position = n.add(u[0]).add(v[0]).v,
            .normal = Vec3.unitSigned(normal_cardinal).v,
        },
        .{
            .position = n.add(u[1]).add(v[0]).v,
            .normal = Vec3.unitSigned(normal_cardinal).v,
        },
    };
}

fn faceIndices(face_i: u32) [6]u32 {
    const s = face_i * 4;
    return [6]u32 {
        s + 0, s + 1, s + 3,
        s + 0, s + 3, s + 2,
    };
}

fn getU(normal: Cardinal) Cardinal {
    return switch (normal) {
        .x_pos => .z_neg,
        .x_neg => .z_pos,
        .y_pos => .z_pos,
        .y_neg => .z_neg,
        .z_pos => .x_pos,
        .z_neg => .x_neg,
    };
}

fn getV(normal: Cardinal) Cardinal {
    return switch (normal) {
        .x_pos => .y_pos,
        .x_neg => .y_pos,
        .y_pos => .x_pos,
        .y_neg => .x_pos,
        .z_pos => .y_pos,
        .z_neg => .y_pos,
    };
}

fn vertPositionOffset(comptime cardinal: Cardinal) Vec3 {
    switch (cardinal.sign()) {
        .positive => return Vec3.unit(cardinal.axis()),
        .negative => return Vec3.zero,
    }
}