const std = @import("std");
const gl = @import("gl.zig");

const glb = gl.buffer;
const gla = gl.array;
const glp = gl.program;

const VertexAttributes = struct {
    position: [2]f32,
    color: [3]f32,
};

const VertexBuffer = glb.VertexBuffer(VertexAttributes);

const Array = gla.Array(struct {
    vert: gla.BufferBind(VertexAttributes, .{})
}, .uint);


pub const HelloTriangle = struct {
    
    array: Array,
    vertex_buffer: VertexBuffer,
    index_buffer: Array.IndexBuffer,

    program: glp.Program,
    vert_stage: glp.Stage(.vertex),
    frag_stage: glp.Stage(.fragment),

    const Self = @This();

    pub fn init() !Self {
        const self = Self {
            .array = Array.init(),
            .vertex_buffer = VertexBuffer.init(),
            .index_buffer = Array.IndexBuffer.init(),
            .program = glp.Program.init(),
            .vert_stage = glp.Stage(.vertex).init(),
            .frag_stage = glp.Stage(.fragment).init(),
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


        self.array.bind();
        self.program.use();

        gl.draw.clearColor(.{0, 0, 0, 1});
        gl.draw.clearDepth(.float, 1);

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
        _ = self;
        gl.draw.clear(.color_depth);
        gl.draw.drawElements(.triangles, 3, .uint);
    }

};