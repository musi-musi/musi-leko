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


const Uniforms = gl.ProgramUniforms(&.{
    gl.uniform("proj", .mat4),
});

pub const HelloTriangle = struct {
    
    array: Array,
    vertex_buffer: VertexBuffer,
    index_buffer: Array.IndexBuffer,

    program: gl.Program,
    vert_stage: gl.VertexStage,
    frag_stage: gl.FragmentStage,
    uniforms: Uniforms,

    const Self = @This();

    pub fn init() !Self {
        var self = Self {
            .array = Array.init(),
            .vertex_buffer = VertexBuffer.init(),
            .index_buffer = Array.IndexBuffer.init(),
            .program = gl.Program.init(),
            .vert_stage = gl.VertexStage.init(),
            .frag_stage = gl.FragmentStage.init(),
            .uniforms = undefined,
        };
        
        self.vertex_buffer.data(&[_]VertexAttributes{
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

        self.index_buffer.data(&[_]u32{0, 1, 2}, .static_draw);
        
        self.array.bindIndexBuffer(self.index_buffer);
        self.array.buffer_binds.vert.bindBuffer(self.vertex_buffer);
        
        
        
        self.vert_stage.source(@embedFile("triangle.vert"));
        try self.vert_stage.compile();
        
        self.frag_stage.source(@embedFile("triangle.frag"));
        try self.frag_stage.compile();

        self.program.attach(.vertex, self.vert_stage);
        self.program.attach(.fragment, self.frag_stage);
        try self.program.link();

        self.uniforms = Uniforms.init(self.program.handle);

        self.array.bind();
        self.program.use();

        gl.clearColor(.{0, 0, 0, 1});
        gl.clearDepth(.float, 1);

        return self;
    }
    
    pub fn deinit(self: Self) void {
        self.array.deinit();
        self.vertex_buffer.deinit();
        self.index_buffer.deinit();
        self.program.deinit();
        self.vert_stage.deinit();
        self.frag_stage.deinit();
    }

    pub fn draw(self: Self) void {
        var proj = projectionMatrix();
        self.uniforms.set("proj", proj.v);
        gl.clear(.color_depth);
        gl.drawElements(.triangles, 3, .uint);
    }

};

fn projectionMatrix() nm.Mat4 {
    const width = window.getWidth();
    const height = window.getHeight();
    const fov: f32 = std.math.pi / 2.0;
    const aspect = @intToFloat(f32, width) / @intToFloat(f32, height);
    return nm.transform.createPerspective(fov, aspect, 0.001, 100);
}