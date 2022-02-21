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

var array: Array = undefined;
var vertex_buffer: VertexBuffer = undefined;
var index_buffer: Array.IndexBuffer = undefined;

var program: gl.Program = undefined;
var vert_stage: gl.VertexStage = undefined;
var frag_stage: gl.FragmentStage = undefined;
var uniforms: Uniforms = undefined;

const Self = @This();

pub fn init() !void {
    array = Array.init();
    vertex_buffer = VertexBuffer.init();
    index_buffer = Array.IndexBuffer.init();
    program = gl.Program.init();
    vert_stage = gl.VertexStage.init();
    frag_stage = gl.FragmentStage.init();
    
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
    
    
    
    vert_stage.source(@embedFile("triangle.vert"));
    try vert_stage.compile();
    
    frag_stage.source(@embedFile("triangle.frag"));
    try frag_stage.compile();

    program.attach(.vertex, vert_stage);
    program.attach(.fragment, frag_stage);
    try program.link();

    uniforms = Uniforms.init(program.handle);

    array.bind();
    program.use();

    gl.clearColor(.{0, 0, 0, 1});
    gl.clearDepth(.float, 1);
}

pub fn deinit() void {
    array.deinit();
    vertex_buffer.deinit();
    index_buffer.deinit();
    program.deinit();
    vert_stage.deinit();
    frag_stage.deinit();
}

pub fn draw() void {
    var proj = projectionMatrix();
    uniforms.set("proj", proj.v);
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