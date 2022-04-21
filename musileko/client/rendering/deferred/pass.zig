const std = @import("std");

const client = @import("../../.zig");
const gl = client.gl;
const nm = client.nm;

const rendering = @import("../.zig");

const deferred = @import(".zig");

const GBuffer = deferred.GBuffer;

pub const Pass = struct {

    buffer: GBuffer,
    screen_mesh: ScreenMesh,
    shader: Shader,

    const Shader = rendering.Shader(&.{
            gl.uniformTextureUnit("g_color"),
            gl.uniformTextureUnit("g_outline"),
            gl.uniformTextureUnit("g_position"),
            gl.uniformTextureUnit("g_normal"),
            gl.uniformTextureUnit("g_uv"),
            gl.uniform("screen_size", .vec2),
        },
        @embedFile("deferred.vert"),
        @embedFile("deferred.frag"),
        &.{},
    );

    const Self = @This();

    pub fn init(self: *Self) !void {
        const width = client.window.width();
        const height = client.window.height();
        self.buffer.init(width, height);
        self.screen_mesh.init();
        self.shader = try Shader.init();
        self.setScreenSize(width, height);
    }

    pub fn deinit(self: *Self) void {
        self.buffer.deinit();
        self.screen_mesh.deinit();
        self.shader.deinit();
    }

    pub fn setScreenSize(self: Self, width: usize, height: usize) void {
        const w = @intToFloat(f32, width);
        const h = @intToFloat(f32, height);
        self.shader.uniforms.set("screen_size", .{w, h});
    }

    pub fn begin(self: *Self) bool {
        const width = client.window.width();
        const height = client.window.height();
        if (width != self.buffer.width or height != self.buffer.height) {
            self.buffer.resize(width, height);
            self.setScreenSize(width, height);
        }
        if (self.buffer.is_complete) {
            self.buffer.setAsTarget();
            self.buffer.clear();
        }
        return self.buffer.is_complete;
    }

    pub fn finish(self: Self) void {
        gl.bindDefaultFramebuffer();
        gl.disableDepthTest();
        self.buffer.textures.color.bind(2);
        self.shader.uniforms.set("g_color", 2);
        self.buffer.textures.outline.bind(3);
        self.shader.uniforms.set("g_outline", 3);
        self.buffer.textures.position.bind(4);
        self.shader.uniforms.set("g_position", 4);
        self.buffer.textures.normal.bind(5);
        self.shader.uniforms.set("g_normal", 5);
        self.buffer.textures.uv.bind(6);
        self.shader.uniforms.set("g_uv", 6);
        self.shader.use();
        self.screen_mesh.startDraw();
        self.screen_mesh.draw();
        gl.enableDepthTest();
        // self.buffer.blitDepth(0); // produces GL_INVALID_OPERATION because the default depth buffer is not f32
    }

};

pub const ScreenMesh = struct {

    array: Array,
    vertex_buffer: VertexBuffer,
    index_buffer: Array.IndexBuffer,

    pub const Vertex = struct {
        position: [2]f32,
    };

    pub const VertexBuffer = gl.VertexBuffer(Vertex);

    pub const Array = gl.Array(struct {
        verts: gl.BufferBind(Vertex, .{}),
    }, .uint);

    const Self = @This();

    pub fn init(self: *Self) void {
        self.array = Array.init();
        self.vertex_buffer = VertexBuffer.init();
        self.index_buffer = Array.IndexBuffer.init();

        self.vertex_buffer.data(&.{
            .{ .position = .{-1, -1} },
            .{ .position = .{ 1, -1} },
            .{ .position = .{-1,  1} },
            .{ .position = .{ 1,  1} },
        }, .static_draw);
        self.index_buffer.data(&.{
            0, 1, 3, 0, 3, 2,
        }, .static_draw);

        self.array.buffer_binds.verts.bindBuffer(self.vertex_buffer);
        self.array.bindIndexBuffer(self.index_buffer);
    }

    pub fn deinit(self: Self) void {
        self.array.deinit();
        self.vertex_buffer.deinit();
        self.index_buffer.deinit();
    }

    pub fn startDraw(self: Self) void {
        self.array.bind();
    }

    pub fn draw(_: Self) void  {
        gl.drawElements(.triangles, 6, .uint);
    }

};
