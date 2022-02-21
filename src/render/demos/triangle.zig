const std = @import("std");
const gl = @import("gl");
const window = @import("window");
const nm = @import("nm");

const VertexAttributes = struct {
    position: [2]f32,
    color: [3]f32,
};

const VertexBuffer = gl.VertexBuffer(VertexAttributes);

const Array = gl.Array(struct {
    vert: gl.BufferBind(VertexAttributes, .{})
}, .uint);


pub const Shader = @import("../shader.zig").Shader(&.{
    gl.uniform("proj", .mat4),
    },
    @embedFile("triangle.vert"),
    @embedFile("triangle.frag"),
);

var array: Array = undefined;
var vertex_buffer: VertexBuffer = undefined;
var index_buffer: Array.IndexBuffer = undefined;
var shader: Shader = undefined;

pub fn init() !void {
    array = Array.init();
    vertex_buffer = VertexBuffer.init();
    index_buffer = Array.IndexBuffer.init();
    
    vertex_buffer.data(&[_]VertexAttributes{
        .{
            .position = .{ 0, 0.5 },
            .color = .{ 1, 1, 1 },
        },
        .{
            .position = .{ -0.5, -0.5 },
            .color = .{ 1, 0, 1 },
        },
        .{
            .position = .{ 0.5, -0.5 },
            .color = .{ 0, 1, 1 },
        },
    }, .static_draw);

    index_buffer.data(&[_]u32{0, 1, 2}, .static_draw);
    
    array.bindIndexBuffer(index_buffer);
    array.buffer_binds.vert.bindBuffer(vertex_buffer);
    
    shader = try Shader.init();
    
    array.bind();
    shader.use();

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
    gl.drawElements(.triangles, 3, .uint);
}


fn projectionMatrix() nm.Mat4 {
    const width = window.getWidth();
    const height = window.getHeight();
    const fov: f32 = std.math.pi / 2.0;
    const aspect = @intToFloat(f32, width) / @intToFloat(f32, height);
    return nm.transform.createPerspective(fov, aspect, 0.001, 100);
}