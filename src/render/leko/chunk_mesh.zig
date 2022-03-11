const std = @import("std");
const leko = @import("leko");
const nm = @import("nm");
const gl = @import("gl");
const window = @import("window");

const shader = @import("../shader.zig");

const Vec3 = nm.Vec3;

const Cardinal3 = nm.Cardinal3;
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
///  - n    0-5 face index; Cardinal3
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

        const light = Vec3.init(.{1, 3, 2}).norm();
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
            try self.data.generateBorder(allocator, self.chunk);
            self.quad_count = (
                self.data.base_middle.items.len +
                self.data.base_border.items.len
            );
        }

        pub fn uploadData(self: Self) void {
            if (self.quad_count > 0) {
                self.base_buffer.alloc(self.quad_count, .static_draw);
                if (self.data.base_middle.items.len > 0) {
                    self.base_buffer.subData(self.data.base_middle.items, 0);
                }
                if (self.data.base_border.items.len > 0) {
                    self.base_buffer.subData(self.data.base_border.items, self.data.base_middle.items.len);
                }
            }
        }

    };

};


pub const MeshData = struct {

    base_middle: std.ArrayListUnmanaged(QuadBase),
    base_border: std.ArrayListUnmanaged(QuadBase),

    const Self = @This();

    const Part = enum {
        middle, border,
    };

    pub fn init() Self {
        return Self {
            .base_middle = .{},
            .base_border = .{},
        };
    }
        
    pub fn deinit(self: *Self, allocator: Allocator) void {
        self.base_middle.deinit(allocator);
        self.base_border.deinit(allocator);
    }

    pub fn generateMiddle(self: *Self, allocator: Allocator, chunk: *const leko.Chunk) !void {
        self.base_middle.shrinkRetainingCapacity(0);
        const cardinals = comptime std.enums.values(Cardinal3);
        inline for (cardinals) |card_n| {
            var face_iter = FaceIterator(1, card_n){};
            while (face_iter.next()) |index|{
                var cursor = Cursor.init(chunk, index);
                var is_opaque = opacity(cursor) == .solid;
                var neighbor_is_opaque = is_opaque;
                cursor = cursor.decr(.middle, card_n).?;
                var n: u32 = 1;
                while (n < Chunk.width - 1) : (n += 1) {
                    is_opaque = opacity(cursor) == .solid;
                    if (is_opaque and !neighbor_is_opaque) {
                        try appendQuadBase(allocator, &self.base_middle, .middle, cursor, card_n);
                    }
                    neighbor_is_opaque = is_opaque;
                    cursor = cursor.decr(.middle, card_n).?;
                }
            }
        }
    }

    pub fn generateBorder(self: *Self, allocator: Allocator, chunk: *const leko.Chunk) !void {
        self.base_border.shrinkRetainingCapacity(0);
        const max = Chunk.width - 1;
        
        inline for (.{0, max}) |x| {
            for (range) |y| {
                for (range) |z| {
                    try self.appendBorderLekoBase(allocator, chunk, x, y, z);
                }
            }
        }

        for (range[1..max]) |x| {
            inline for (.{0, max}) |y| {
                for (range) |z| {
                    try self.appendBorderLekoBase(allocator, chunk, x, y, z);
                }
            }
            for (range[1..max]) |y| {
                inline for (.{0, max}) |z| {
                    try self.appendBorderLekoBase(allocator, chunk, x, y, z);
                }
            }
        }
        
    }

    const range = blk: {
        var result: [Chunk.width]u32 = undefined;
        for (result) |*x, i| {
            x.* = i;
        }
        break :blk result;
    };

    fn appendQuadBase(allocator: Allocator, list: *std.ArrayListUnmanaged(QuadBase), comptime part: Part, cursor: Cursor, comptime normal: Cardinal3) !void {
        return try list.append(allocator, QuadBase {
            .base = (@as(u32, cursor.position.v) << 3 | comptime @enumToInt(normal)) << 8 | computeAO(cursor, part, normal),
        });
    }

    fn appendBorderLekoBase(self: *Self, allocator: Allocator, chunk: *const Chunk, x: u32, y: u32, z: u32) !void{ 
        var cursor = Cursor.init(chunk, LekoIndex.init(u32, .{x, y, z}));
        if (opacity(cursor) == .solid) {
            inline for (comptime std.enums.values(Cardinal3)) |normal| {
                if (cursor.incr(.border, normal)) |neighbor| {
                    if (opacity(neighbor) == .transparent) {
                        try appendQuadBase(allocator, &self.base_border, .border, cursor, normal);
                    }
                }
            }
        }
    }

    const Opacity = enum(u8) {
        transparent = 0,
        solid = 1,
    };

    fn opacity(cursor: Cursor) Opacity {
        return switch (cursor.chunk.id_array.get(cursor.position)) {
            0 => .transparent,
            else => .solid,
        };
    }

    fn FaceIterator(comptime start: u32, comptime normal: Cardinal3) type {
        return struct {

            u: u32 = start,
            v: u32 = start,
            
            const end = Chunk.width - start;

            const card_u = cardU(normal);
            const card_v = cardV(normal);

            pub fn next(self: *@This()) ?LekoIndex {
                if (self.v >= end) {
                    return null;
                }
                else {
                    const result = self.index();
                    self.u += 1;
                    if (self.u >= end) {
                        self.u = start;
                        self.v += 1;
                    }
                    return result;
                }
            }

            fn index(self: @This()) LekoIndex {
                const u = LekoIndex.single(u32, self.u, comptime card_u.axis());
                const v = LekoIndex.single(u32, self.v, comptime card_v.axis());
                const n = LekoIndex.edge(u32, 0, normal);
                return .{
                    .v = u.v + v.v + n.v
                };
            }

        };

    }

    // fn EdgeIterator(
    //     comptime start: u32, comptime end: u32,
    //     comptime normal: Cardinal3,
    //     comptime edge_u: Cardinal3,
    //     comptime edge_v: Cardinal3,
    // ) type {

    //     return struct {

    //         x: u32 = start,

    //         pub fn next(self: *@This()) ?LekoIndex {
    //             return null;
    //         }

    //     };
    // }

    fn cardU(normal: Cardinal3) Cardinal3 {
        return switch (normal) {
            .x_pos => .z_neg,
            .x_neg => .z_pos,
            .y_pos => .z_pos,
            .y_neg => .z_neg,
            .z_pos => .x_pos,
            .z_neg => .x_neg,
        };
    }

    fn cardV(normal: Cardinal3) Cardinal3 {
        return switch (normal) {
            .x_pos => .y_pos,
            .x_neg => .y_pos,
            .y_pos => .x_pos,
            .y_neg => .x_pos,
            .z_pos => .y_pos,
            .z_neg => .y_pos,
        };
    }

    fn computeAO(cursor: Cursor, comptime part: Part, comptime normal: Cardinal3) u8 {
        const u = comptime cardU(normal);
        const v = comptime cardV(normal);

        var c = cursor;

        c = c.incr(part, normal) orelse return 0;
        

        const Move = struct {
            sign: enum { incr, decr },
            direction: Cardinal3,
        };

        const moves = [8]Move {
            .{ .sign = .decr, .direction = u },
            .{ .sign = .incr, .direction = v },
            .{ .sign = .incr, .direction = u },
            .{ .sign = .incr, .direction = u },
            .{ .sign = .decr, .direction = v },
            .{ .sign = .decr, .direction = v },
            .{ .sign = .decr, .direction = u },
            .{ .sign = .decr, .direction = u },
        };

        var neighbors: u8 = 0;
        inline for (moves) |move, i| {
            switch (part) {
                .middle => {},
                .border => {},
            }
            switch (move.sign) {
                .incr => c = c.incr(part, move.direction) orelse return 0,
                .decr => c = c.decr(part, move.direction) orelse return 0,
            }
            neighbors |= @enumToInt(opacity(c)) << i;
        }
        return ao_table[neighbors];
    }

    /// ```
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

    const Cursor = struct {
        
        chunk: *const Chunk,
        position: LekoIndex,

        pub fn init(chunk: *const Chunk, position: LekoIndex) Cursor {
            return .{
                .chunk = chunk,
                .position = position,
            };
        }

        pub fn incr(cursor: Cursor, comptime part: Part, comptime direction: Cardinal3) ?Cursor {
            var result = cursor;
            switch (part) {
                .middle => {
                    result.position = result.position.incr(direction);
                },
                .border => {
                    const pos = direction;
                    const neg = comptime direction.neg();
                    if (result.position.isEdge(pos)) {
                        if (result.chunk.neighbor(pos)) |neighbor| {
                            result.chunk = neighbor;
                            result.position = result.position.toEdge(neg);
                        }
                        else {
                            return null;
                        }
                    }
                    else {
                        result.position = result.position.incr(pos);
                    }
                }
            }
            return result;
        }

        pub fn decr(cursor: Cursor, comptime part: Part, comptime direction: Cardinal3) ?Cursor {
            var result = cursor;
            switch (part) {
                .middle => {
                    result.position = result.position.decr(direction);
                },
                .border => {
                    const pos = direction;
                    const neg = comptime direction.neg();
                    if (result.position.isEdge(neg)) {
                        if (result.chunk.neighbor(neg)) |neighbor| {
                            result.chunk = neighbor;
                            result.position = result.position.toEdge(pos);
                        }
                        else {
                            return null;
                        }
                    }
                    else {
                        result.position = result.position.decr(pos);
                    }
                }
            }
            return result;
        }




    };

    fn createShaderHeader() [:0]const u8 {
        const Context = struct {

            pub fn format(_: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, w: anytype) !void {
                try w.print("#define CHUNK_WIDTH {d}\n", .{Chunk.width});
                try w.print("#define CHUNK_WIDTH_BITS {d}\n", .{Chunk.width_bits});
                try w.writeAll("const vec3 cube_normals[6] = vec3[6](");
                for (std.enums.values(Cardinal3)) |card_n, i| {
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
                for (std.enums.values(Cardinal3)) |card_n, i| {
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

            fn vertPositionOffset(comptime cardinal: Cardinal3) Vec3 {
                switch (cardinal.sign()) {
                    .positive => return Vec3.unit(cardinal.axis()),
                    .negative => return Vec3.zero,
                }
            }

        };
        return std.fmt.comptimePrint("{}", .{ Context{}});
    }

};


