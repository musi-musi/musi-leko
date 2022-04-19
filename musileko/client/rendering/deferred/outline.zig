const std = @import("std");

const client = @import("../../.zig");
const gl = client.gl;
const nm = client.nm;

const rendering = @import("../.zig");

pub const OutlinePass = struct {

    shader: Shader,

    pub const Shader = rendering.Shader(&.{
            gl.uniform("model", .mat4),
            gl.uniform("view", .mat4),
            gl.uniform("proj", .mat4),
            
            gl.uniform("color", .vec4),
        },
        @embedFile("outline.vert"),
        @embedFile("outline.frag"),
        &.{},
    );

    const Self = @This();

    pub fn init(self: *Self) !void {
        self.shader = try Shader.init();
    }

    pub fn deinit(self: *Self) void {
        self.shader.deinit();
    }

    pub fn begin(self: Self) void {
        self.shader.use();
    }

    pub fn setCamera(self: Self, camera: rendering.Camera) void {
        self.shader.uniforms.set("view", camera.view.v);
        self.shader.uniforms.set("proj", camera.proj.v);
    }

    pub fn setModelMatrix(self: Self, model: nm.Mat4) void {
        self.shader.uniforms.set("model", model.v);
    }

    pub fn setColor(self: Self, color: nm.Vec4) void {
        self.shader.uniforms.set("color", color.v);
    }

};


