const std = @import("std");
const leko = @import("leko");
const nm = @import("nm");
const gl = @import("gl");
const window = @import("window");

const shader = @import("../shader.zig");

const Vec3 = nm.Vec3;

const Cardinal = nm.Cardinal3;
const Allocator = std.mem.Allocator;
const Chunk = leko.Chunk;
const LekoIndex = leko.LekoIndex;

// 0 --- 1
// | \   |   ^
// |  \  |   |
// |   \ |   v
// 2 --- 3   + u ->

var _array: Array = undefined;
var _index_buffer: Array.IndexBuffer = undefined;
var _shader: Shader = undefined;

// pub const QuadVert = struct {
//     uv: [2]f32,
// };

pub const QuadBase = struct {
    base: u32,
};

pub const QuadBaseBuffer = gl.VertexBuffer(QuadBase);

const Array = gl.Array(struct {
    base: gl.BufferBind(QuadBase, .{.divisor = 1}),
}, .uint);

const Shader = shader.Shader(&.{
        gl.uniform("proj", .mat4),
        gl.uniform("view", .mat4),
        gl.uniform("light", .vec3),
    },
    @embedFile("chunkmesh.vert"),
    @embedFile("chunkmesh.frag"),
    &.{MeshData.createShaderHeader()},
);

pub const exports = struct {

    pub fn init() !void {
        _array = Array.init();
        _index_buffer = Array.IndexBuffer.init();
        _index_buffer.data(&.{0, 1, 3, 0, 3, 2}, .static_draw);
        _array.bindIndexBuffer(_index_buffer);
        _shader = try Shader.init();

        const light = Vec3.init(.{1, 2, 3}).norm();
        _shader.uniforms.set("light", light.v);
    }

    pub fn deinit() void {
        _array.deinit();
        _index_buffer.deinit();
        _shader.deinit();
    }

    pub fn setViewMatrix(view: nm.Mat4) void {
        _shader.uniforms.set("view", view.v);
    }

    pub fn startDraw() void {
        var proj = projectionMatrix();
        _shader.uniforms.set("proj", proj.v);
        gl.clearColor(.{0, 0, 0, 1});
        gl.clearDepth(.float, 1);
        gl.clear(.color_depth);
        _array.bind();
        _shader.use();
    }

    pub fn bindMesh(mesh: *const Mesh) void {
        _array.buffer_binds.base.bindBuffer(mesh.base_buffer);
    }

    pub fn drawMesh(mesh: *const Mesh) void {
        gl.drawElementsInstanced(.triangles, 6, .uint, mesh.quad_count);
    }

    fn projectionMatrix() nm.Mat4 {
        const width = window.width();
        const height = window.height();
        const fov_rad: f32 = std.math.pi / 180.0 * 90.0;
        const aspect = @intToFloat(f32, width) / @intToFloat(f32, height);
        return nm.transform.createPerspective(fov_rad, aspect, 0.001, 100);
    }

    pub const Mesh = struct {

        chunk: *const Chunk,
        base_buffer: QuadBaseBuffer,
        data: MeshData,
        quad_count: usize = 0,

        const Self = @This();

        pub fn init(chunk: *const Chunk) Self {
            return Self {
                .chunk = chunk,
                .base_buffer = QuadBaseBuffer.init(),
                .data = MeshData.init(),
            };
        }

        pub fn deinit(self: *Self, allocator: Allocator) void  {
            self.base_buffer.deinit();
            self.data.deinit(allocator);
        }

        pub fn generateData(self: *Self, allocator: Allocator) !void {
            try self.data.generate(allocator, self.chunk);
            self.quad_count = self.data.base.items.len;
        }

        pub fn uploadData(self: Self) void {
            self.base_buffer.data(self.data.base.items, .static_draw);
        }

    };

};


pub const MeshData = struct {

    base: std.ArrayListUnmanaged(QuadBase),

    const Self = @This();

    pub fn init() Self {
        return Self {
            .base = .{},
        };
    }
        
    pub fn deinit(self: *Self, allocator: Allocator) void {
        self.base.deinit(allocator);
    }

    pub fn generate(self: *Self, allocator: Allocator, chunk: *const leko.Chunk) !void {
        self.base.shrinkRetainingCapacity(0);
        const cardinals = comptime std.enums.values(Cardinal);
        inline for (cardinals) |card_n| {
            const card_u = comptime cardU(card_n);
            const card_v = comptime cardV(card_n);
            var u: u32 = 0;
            while (u < Chunk.width) : (u += 1) {
                var v: u32 = 0;
                while (v < Chunk.width) : (v += 1) {
                    const u_index = LekoIndex.single(u32, u, comptime card_u.axis());
                    const v_index = LekoIndex.single(u32, v, comptime card_v.axis());
                    const n_index = switch(comptime card_n.sign()) {
                        .positive => LekoIndex.single(u32, Chunk.width - 1, comptime card_n.axis()),
                        .negative => LekoIndex.single(u32, 0, comptime card_n.axis()),
                    };
                    var index = LekoIndex{ .v = u_index.v + v_index.v + n_index.v };
                    var is_opaque = isOpaque(chunk, index);
                    if (is_opaque) {
                        try self.appendQuadBase(allocator, index, card_n);
                    }
                    var neighbor_is_opaque = is_opaque;
                    index = index.decr(card_n);
                    var n: u32 = 1;
                    while (n < Chunk.width) : (n += 1) {
                        is_opaque = isOpaque(chunk, index);
                        if (is_opaque and !neighbor_is_opaque) {
                            try self.appendQuadBase(allocator, index, card_n);
                        }
                        neighbor_is_opaque = is_opaque;
                        index = index.decr(card_n);
                    }
                }
            }
        }
    }

    fn appendQuadBase(self: *Self, allocator: Allocator, index: LekoIndex, comptime normal: Cardinal) !void {
        return try self.base.append(allocator, QuadBase {
            .base = (@as(u32, index.v) << 3 | comptime @enumToInt(normal)),
        });
    }

    fn isOpaque(chunk: *const Chunk, index: LekoIndex) bool {
        return chunk.id_array.get(index) > 0;
    }

    fn cardU(normal: Cardinal) Cardinal {
        return switch (normal) {
            .x_pos => .z_neg,
            .x_neg => .z_pos,
            .y_pos => .z_pos,
            .y_neg => .z_neg,
            .z_pos => .x_pos,
            .z_neg => .x_neg,
        };
    }

    fn cardV(normal: Cardinal) Cardinal {
        return switch (normal) {
            .x_pos => .y_pos,
            .x_neg => .y_pos,
            .y_pos => .x_pos,
            .y_neg => .x_pos,
            .z_pos => .y_pos,
            .z_neg => .y_pos,
        };
    }

    // 0 --- 1
    // | \   |   ^
    // |  \  |   |
    // |   \ |   v
    // 2 --- 3   + u ->
    fn createShaderHeader() [:0]const u8 {
        const Context = struct {

            pub fn format(_: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, w: anytype) !void {
                try w.print("#define CHUNK_WIDTH {d}\n", .{Chunk.width});
                try w.print("#define CHUNK_WIDTH_BITS {d}\n", .{Chunk.width_bits});
                try w.writeAll("const vec3 cube_normals[6] = vec3[6](");
                for (std.enums.values(Cardinal)) |card_n, i| {
                    if (i != 0) {
                        try w.writeAll(", ");
                    }
                    const normal = Vec3.unitSigned(card_n).v;
                    try w.print("vec3({d}, {d}, {d})", .{
                        @floatToInt(i32, normal[0]), 
                        @floatToInt(i32, normal[1]), 
                        @floatToInt(i32, normal[2]),
                    });
                }
                try w.writeAll(");\n");
                try w.writeAll("const vec3 cube_positions[6][4] = vec3[6][4](");
                for (std.enums.values(Cardinal)) |card_n, i| {
                    if (i != 0) {
                        try w.writeAll(",");
                    }
                    try w.writeAll("\n    vec3[4](");
                    const card_u = cardU(card_n);
                    const card_v = cardV(card_n);
                    const n = vertPositionOffset(card_n);
                    const u = [2]Vec3{
                        vertPositionOffset(card_u.neg()),
                        vertPositionOffset(card_u),
                    };
                    const v = [2]Vec3{
                        vertPositionOffset(card_v.neg()),
                        vertPositionOffset(card_v),
                    };
                    const positions = [4][3]f32{
                        n.add(u[0]).add(v[1]).v,
                        n.add(u[1]).add(v[1]).v,
                        n.add(u[0]).add(v[0]).v,
                        n.add(u[1]).add(v[0]).v,
                    };
                    for (positions) |position, p| {
                        if (p != 0) {
                            try w.writeAll(", ");
                        }
                        try w.print("vec3({d}, {d}, {d})", .{
                            @floatToInt(i32, position[0]), 
                            @floatToInt(i32, position[1]), 
                            @floatToInt(i32, position[2]),
                        });
                    }

                    try w.writeAll(")");
                }
                try w.writeAll("\n);\n");
            }

            fn vertPositionOffset(comptime cardinal: Cardinal) Vec3 {
                switch (cardinal.sign()) {
                    .positive => return Vec3.unit(cardinal.axis()),
                    .negative => return Vec3.zero,
                }
            }

        };
        return std.fmt.comptimePrint("{}", .{ Context{}});
    }

};


