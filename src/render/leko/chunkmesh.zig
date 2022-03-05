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


var _array: Array = undefined;
var _index_buffer: Array.IndexBuffer = undefined;
var _shader: Shader = undefined;

/// ```
///     0 --- 1
///     | \   |   ^
///     |  \  |   |
///     |   \ |   v
///     2 --- 3   + u -- >
/// ```
///  base = 0b 000000 xxxxx yyyyy zzzzz nnn aaaaaaaa
///  - xyz  position of cube
///  - n    0-5 face index; Cardinal
///  - a    ao strength per vertex, packed 0b33221100
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

        gl.uniform("chunk_position", .vec3i),
        
        gl.uniform("light", .vec3),
    },
    @embedFile("chunkmesh.vert"),
    @embedFile("chunkmesh.frag"),
    &.{MeshData.createShaderHeader()},
);

pub usingnamespace exports;
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
        _shader.uniforms.set("chunk_position", mesh.chunk.position.v);
    }

    pub fn drawMesh(mesh: *const Mesh) void {
        gl.drawElementsInstanced(.triangles, 6, .uint, mesh.quad_count);
    }

    fn projectionMatrix() nm.Mat4 {
        const width = window.width();
        const height = window.height();
        const fov_rad: f32 = std.math.pi / 180.0 * 90.0;
        const aspect = @intToFloat(f32, width) / @intToFloat(f32, height);
        return nm.transform.createPerspective(fov_rad, aspect, 0.001, 10000);
    }

    pub const Mesh = struct {

        chunk: *const Chunk,
        base_buffer: QuadBaseBuffer,
        data: MeshData,
        quad_count: usize = 0,

        const Self = @This();

        pub fn init(self: *Self, chunk: *const Chunk) void {
            self.chunk = chunk;
            self.base_buffer = QuadBaseBuffer.init();
            self.data = MeshData.init();
        }

        pub fn deinit(self: *Self, allocator: Allocator) void  {
            defer self.base_buffer.deinit();
            defer self.data.deinit(allocator);
        }

        pub fn generateData(self: *Self, allocator: Allocator) !void {
            try self.data.generateMiddle(allocator, self.chunk);
            self.quad_count = self.data.base_middle.items.len;
        }

        pub fn uploadData(self: Self) void {
            self.base_buffer.alloc(self.quad_count, .static_draw);
            self.base_buffer.subData(self.data.base_middle.items, 0);
        }

    };

};


pub const MeshData = struct {

    base_middle: std.ArrayListUnmanaged(QuadBase),

    const Self = @This();

    pub fn init() Self {
        return Self {
            .base_middle = .{},
        };
    }
        
    pub fn deinit(self: *Self, allocator: Allocator) void {
        self.base_middle.deinit(allocator);
    }

    pub fn generateMiddle(self: *Self, allocator: Allocator, chunk: *const leko.Chunk) !void {
        self.base_middle.shrinkRetainingCapacity(0);
        const cardinals = comptime std.enums.values(Cardinal);
        inline for (cardinals) |card_n| {
            const card_u = comptime cardU(card_n);
            const card_v = comptime cardV(card_n);
            var u: u32 = 1;
            while (u < Chunk.width - 1) : (u += 1) {
                var v: u32 = 1;
                while (v < Chunk.width - 1) : (v += 1) {
                    const u_index = LekoIndex.single(u32, u, comptime card_u.axis());
                    const v_index = LekoIndex.single(u32, v, comptime card_v.axis());
                    const n_index = switch(comptime card_n.sign()) {
                        .positive => LekoIndex.single(u32, Chunk.width - 1, comptime card_n.axis()),
                        .negative => LekoIndex.single(u32, 0, comptime card_n.axis()),
                    };
                    var index = LekoIndex{ .v = u_index.v + v_index.v + n_index.v };
                    var is_opaque = opacity(chunk, index) == .solid;
                    var neighbor_is_opaque = is_opaque;
                    index = index.decr(card_n);
                    var n: u32 = 1;
                    while (n < Chunk.width) : (n += 1) {
                        is_opaque = opacity(chunk, index) == .solid;
                        if (is_opaque and !neighbor_is_opaque) {
                            try appendQuadBase(allocator, &self.base_middle, index, card_n, computeAO(index, card_n, chunk));
                        }
                        neighbor_is_opaque = is_opaque;
                        index = index.decr(card_n);
                    }
                }
            }
        }
    }

    fn appendQuadBase(allocator: Allocator, list: *std.ArrayListUnmanaged(QuadBase), position: LekoIndex, comptime normal: Cardinal, ao: u8) !void {
        return try list.append(allocator, QuadBase {
            .base = (@as(u32, position.v) << 3 | comptime @enumToInt(normal)) << 8 | ao,
        });
    }

    const Opacity = enum(u8) {
        transparent = 0,
        solid = 1,
    };

    fn opacity(chunk: *const Chunk, index: LekoIndex) Opacity {
        return switch (chunk.id_array.get(index)) {
            0 => .transparent,
            else => .solid,
        };
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

    fn computeAO(position: LekoIndex, comptime n: Cardinal, chunk: *const Chunk) u8 {
        const u = comptime cardU(n);
        const v = comptime cardV(n);
        var p = position.incr(n);
        var neighbors: u8 = 0;
        p = p.decr(u);
        neighbors |= @enumToInt(opacity(chunk, p)) << 0;
        p = p.incr(v);
        neighbors |= @enumToInt(opacity(chunk, p)) << 1;
        p = p.incr(u);
        neighbors |= @enumToInt(opacity(chunk, p)) << 2;
        p = p.incr(u);
        neighbors |= @enumToInt(opacity(chunk, p)) << 3;
        p = p.decr(v);
        neighbors |= @enumToInt(opacity(chunk, p)) << 4;
        p = p.decr(v);
        neighbors |= @enumToInt(opacity(chunk, p)) << 5;
        p = p.decr(u);
        neighbors |= @enumToInt(opacity(chunk, p)) << 6;
        p = p.decr(u);
        neighbors |= @enumToInt(opacity(chunk, p)) << 7;
        return ao_table[neighbors];
    }

    ///```
    ///  | 1 |  2  | 3 |
    ///  | - 0 --- 1 - |
    ///  |   | \   |   |    ^
    ///  | 0 |  \  | 4 |    |
    ///  |   |   \ |   |    v
    ///  | - 2 --- 3 - |    + u ->
    ///  | 7 |  6  | 5 |
    /// ```
    const ao_table: [256]u8 = blk: {
        @setEvalBranchQuota(1_000_000);
        var table = std.mem.zeroes([256]u8);
        var i: u32 = 0;
        while (i < 256) : (i += 1) {
            var neighbors = @intCast(u8, i);
            for ([4]u3{0, 1, 3, 2}) |vert| {
                var vert_neighbors = neighbors & 0b111;
                neighbors = std.math.rotr(u8, neighbors, 2);
                const ao: u8 = switch(vert_neighbors) {
                    0b000 => 0,
                    0b010 => 1,
                    0b001 => 1,
                    0b100 => 1,
                    0b011 => 2,
                    0b110 => 2,
                    0b101 => 3,
                    0b111 => 3,
                    else => unreachable,
                };
                table[i] |= ao << 2 * vert;
            }
        }
        break :blk table;
    };


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
                try w.writeAll("const vec2 cube_uvs[4] = vec2[4](");
                try w.writeAll("vec2(0, 1), vec2(1, 1), vec2(0, 0), vec2(1, 0)");
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


