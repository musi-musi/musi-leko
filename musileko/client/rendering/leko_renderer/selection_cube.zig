const std = @import("std");
const rendering = @import("../.zig");
const client = @import("../../.zig");
const gl = client.gl;
const nm = client.nm;

const Camera = rendering.Camera;

const Vec3i = nm.Vec3i;

const Vertex = struct {
    position: [3]f32,
};

const VertexBuffer = gl.VertexBuffer(Vertex);

const Array = gl.Array(struct {
    vertex: gl.BufferBind(Vertex, .{}),
}, .uint);

const Shader = rendering.Shader(&.{
        gl.uniform("proj", .mat4),
        gl.uniform("view", .mat4),
        gl.uniform("position", .vec3i),
    }, 
    @embedFile("selection_cube.vert"), 
    @embedFile("selection_cube.frag"), 
    &.{},
);

var _array: Array = undefined;
var _index_buffer: Array.IndexBuffer = undefined;
var _vertex_buffer: VertexBuffer = undefined;
var _shader: Shader = undefined;

pub const selection_cube = struct {
    
    pub fn init() !void {
        _array = Array.init();
        _index_buffer = Array.IndexBuffer.init();
        _vertex_buffer = VertexBuffer.init();
        _shader = try Shader.init();

        const grow: f32 = 0.01;

        const a = -grow;
        const b = 1 + grow;

        _vertex_buffer.data(&.{
            .{ .position = .{ a, a, a} },
            .{ .position = .{ a, a, b} },
            .{ .position = .{ a, b, a} },
            .{ .position = .{ a, b, b} },
            .{ .position = .{ b, a, a} },
            .{ .position = .{ b, a, b} },
            .{ .position = .{ b, b, a} },
            .{ .position = .{ b, b, b} },
        }, .static_draw);

        _index_buffer.data(&.{
            0, 1,
            2, 3,
            4, 5,
            6, 7,

            0, 2,
            1, 3,
            4, 6,
            5, 7,

            0, 4,
            1, 5,
            2, 6,
            3, 7,
        },
        .static_draw);
        _array.bindIndexBuffer(_index_buffer);
        _array.buffer_binds.vertex.bindBuffer(_vertex_buffer);
    }

    pub fn deinit() void {
        _array.deinit();
        _index_buffer.deinit();
        _vertex_buffer.deinit();
        _shader.deinit();
    }

    pub fn setCamera(camera: Camera) void {
        _shader.uniforms.set("proj", camera.proj.v);
        _shader.uniforms.set("view", camera.view.v);
    }

    pub fn startDraw() void {
        _array.bind();
        _shader.use();
    }

    pub fn draw(position: Vec3i) void {
        _shader.uniforms.set("position", position.v);
        gl.drawElements(.lines, 24, .uint);
    }

};
