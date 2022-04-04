const std = @import("std");


const engine = @import("../../../engine/.zig");
const leko = engine.leko;


const client = @import("../../.zig");
const gl = client.gl;
const nm = client.nm;
const window = client.window;

const leko_renderer = @import(".zig");
const rendering = @import("../.zig");

const Vec3 = nm.Vec3;

const Cardinal3 = nm.Cardinal3;
const Allocator = std.mem.Allocator;
const Chunk = leko.Chunk;
const Address = leko.Address;
const Reference = leko.Reference;

pub const chunk_mesh = struct {

    var _array: Array = undefined;
    var _index_buffer: Array.IndexBuffer = undefined;
    var _shader: Shader = undefined;
    var _perlin_texture: Texture = undefined;

    const Texture = gl.Texture(.texture_2d, .{
        .channels = .rg,
        .component = .float,
    });

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

    const Shader = rendering.Shader(&.{
            gl.uniform("proj", .mat4),
            gl.uniform("view", .mat4),

            gl.uniform("chunk_position", .vec3i),
            
            gl.uniform("light", .vec3),
            gl.uniformTextureUnit("perlin"),

            gl.uniform("time", .float),
        },
        @embedFile("chunk_mesh.vert"),
        @embedFile("chunk_mesh.frag"),
        &.{MeshData.createShaderHeader()},
    );

    pub fn init() !void {
        _array = Array.init();
        _index_buffer = Array.IndexBuffer.init();
        _index_buffer.data(&.{0, 1, 3, 0, 3, 2}, .static_draw);
        _array.bindIndexBuffer(_index_buffer);
        _shader = try Shader.init();

        const light = Vec3.init(.{1, 3, 2}).norm();
        _shader.uniforms.set("light", light.v);

        _perlin_texture = Texture.init();

        const size: u32 = 256;
        // const perlin_wrap: f32 = 64;
        const Data = [size][size][2]f32;
        // const perlin = nm.noise.Perlin2(null){};
        var data: Data = undefined;
        var rng = std.rand.DefaultPrng.init(0);
        const r = rng.random();
        var x: u32 = 0;
        while (x < size) : (x += 1) {
            // const u = @intToFloat(f32, x) / @intToFloat(f32, size - 1) * (perlin_wrap - 1);
            var y: u32 = 0;
            while (y < size) : (y += 1) {
                // const v = @intToFloat(f32, y) / @intToFloat(f32, size - 1) * (perlin_wrap - 1);
                data[x][y][0] = (r.float(f32) * 2) - 1;
                data[x][y][1] = (r.float(f32) * 2) - 1;
                // data[x][y][0] = perlin.sample(.{u, v});
            }
        }
        
        _perlin_texture.alloc(size, size);
        _perlin_texture.upload(size, size, @ptrCast(*[size * size][2]f32, &data));
        _shader.uniforms.set("perlin", 1);
        _perlin_texture.setFilter(.linear, .linear);
        // _perlin_texture.setFilter(.nearest, .nearest);
    }

    pub fn deinit() void {
        _array.deinit();
        _index_buffer.deinit();
        _shader.deinit();
        _perlin_texture.deinit();
    }

    pub fn setViewMatrix(view: nm.Mat4) void {
        _shader.uniforms.set("view", view.v);
    }

    pub fn startDraw() void {
        var proj = projectionMatrix();
        _shader.uniforms.set("proj", proj.v);
        _shader.uniforms.set("time", @floatCast(f32, window.currentTime()));
        _array.bind();
        _shader.use();
        _perlin_texture.bind(1);
    }

    pub fn bindMesh(mesh: *ChunkMesh) void {
        _array.buffer_binds.base.bindBuffer(mesh.base_buffer);
        _shader.uniforms.set("chunk_position", mesh.chunk.position.v);
    }

    pub fn drawMesh(mesh: *ChunkMesh) void {
        _ = mesh;
        if (mesh.quad_count > 0 and mesh.has_uploaded) {
            gl.drawElementsInstanced(.triangles, 6, .uint, mesh.quad_count);
        }
    }

    fn projectionMatrix() nm.Mat4 {
        const width = window.width();
        const height = window.height();
        const fov_rad: f32 = std.math.pi / 180.0 * 90.0;
        const aspect = @intToFloat(f32, width) / @intToFloat(f32, height);
        return nm.transform.createPerspective(fov_rad, aspect, 0.01, 1000);
    }
};

pub const ChunkMesh = struct {

    chunk: *Chunk,
    base_buffer: QuadBaseBuffer,
    data: MeshData,
    quad_count: usize = 0,
    state: State = .inactive,
    mutex: std.Thread.Mutex = .{},
    has_uploaded: bool = false,

    const QuadBaseBuffer = chunk_mesh.QuadBaseBuffer;

    const Self = @This();

    pub const State = enum {
        inactive,
        generating,
        active,
    };

    pub const Parts = enum {
        middle,
        border,
        middle_border,
    };

    pub fn init(self: *Self, chunk: *Chunk) void {
        self.* = .{
            .chunk = chunk,
            .base_buffer = QuadBaseBuffer.init(),
            .data = MeshData.init(),
        };
    }

    pub fn deinit(self: *Self, allocator: Allocator) void  {
        defer self.base_buffer.deinit();
        defer self.data.deinit(allocator);
    }

    pub fn clear(self: *Self) void {
        self.quad_count = 0;
        self.has_uploaded = false;
        self.data.clear();
    }

    pub fn generateData(self: *Self, allocator: Allocator, parts: Parts) !void {
        switch (parts) {
            .middle => {
                try self.data.generateMiddle(allocator, self.chunk);
            },
            .border => {
                try self.data.generateBorder(allocator, self.chunk);
            },
            .middle_border => {
                try self.data.generateMiddle(allocator, self.chunk);
                try self.data.generateBorder(allocator, self.chunk);
            },
        }
    }

    pub fn uploadData(self: *Self) void {
        self.quad_count = (
            self.data.base_middle.items.len +
            self.data.base_border.items.len
        );
        if (self.quad_count > 0) {
            self.base_buffer.alloc(self.quad_count, .static_draw);
            if (self.data.base_middle.items.len > 0) {
                self.base_buffer.subData(self.data.base_middle.items, 0);
            }
            if (self.data.base_border.items.len > 0) {
                self.base_buffer.subData(self.data.base_border.items, self.data.base_middle.items.len);
            }
            self.has_uploaded = true;
        }
    }

};


pub const MeshData = struct {

    base_middle: std.ArrayListUnmanaged(QuadBase),
    base_border: std.ArrayListUnmanaged(QuadBase),

    const QuadBase = chunk_mesh.QuadBase;

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

    pub fn clear(self: *Self) void {
        self.base_middle.shrinkRetainingCapacity(0);
        self.base_border.shrinkRetainingCapacity(0);
    }

    pub fn generateMiddle(self: *Self, allocator: Allocator, chunk: *Chunk) !void {
        self.base_middle.shrinkRetainingCapacity(0);
        const cardinals = comptime std.enums.values(Cardinal3);
        inline for (cardinals) |card_n| {
            var face_iter = FaceIterator(1, card_n){};
            while (face_iter.next()) |index|{
                var reference = Reference.init(chunk, index);
                var is_opaque = opacity(reference) == .solid;
                var neighbor_is_opaque = is_opaque;
                reference = reference.decrUnchecked(card_n);
                var n: u32 = 1;
                while (n < Chunk.width - 1) : (n += 1) {
                    is_opaque = opacity(reference) == .solid;
                    if (is_opaque and !neighbor_is_opaque) {
                        try appendQuadBase(allocator, &self.base_middle, .middle, reference, card_n);
                    }
                    neighbor_is_opaque = is_opaque;
                    reference = reference.decrUnchecked(card_n);
                }
            }
        }
    }

    pub fn generateBorder(self: *Self, allocator: Allocator, chunk: *Chunk) !void {
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

    fn appendQuadBase(allocator: Allocator, list: *std.ArrayListUnmanaged(QuadBase), comptime part: Part, reference: Reference, comptime normal: Cardinal3) !void {
        return try list.append(allocator, QuadBase {
            .base = (@as(u32, reference.address.v) << 3 | comptime @enumToInt(normal)) << 8 | computeAO(reference, part, normal),
        });
    }

    fn appendBorderLekoBase(self: *Self, allocator: Allocator, chunk: *Chunk, x: u32, y: u32, z: u32) !void{ 
        var reference = Reference.init(chunk, Address.init(u32, .{x, y, z}));
        if (opacity(reference) == .solid) {
            inline for (comptime std.enums.values(Cardinal3)) |normal| {
                if (reference.incr(normal)) |neighbor| {
                    if (opacity(neighbor) == .transparent) {
                        try appendQuadBase(allocator, &self.base_border, .border, reference, normal);
                    }
                }
            }
        }
    }

    const Opacity = enum(u8) {
        transparent = 0,
        solid = 1,
    };

    fn opacity(reference: Reference) Opacity {
        return switch (reference.chunk.id_array.get(reference.address)) {
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

            pub fn next(self: *@This()) ?Address {
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

            fn index(self: @This()) Address {
                const u = Address.single(u32, self.u, comptime card_u.axis());
                const v = Address.single(u32, self.v, comptime card_v.axis());
                const n = Address.edge(u32, 0, normal);
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

    //         pub fn next(self: *@This()) ?Address {
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

    fn computeAO(reference: Reference, comptime part: Part, comptime normal: Cardinal3) u8 {
        const u = comptime cardU(normal);
        const v = comptime cardV(normal);

        var r = switch (part) {
            .middle => reference.incrUnchecked(normal),
            .border => reference.incr(normal) orelse return 0,
        };

        

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
                .middle => {
                    switch (move.sign) {
                        .incr => r = r.incrUnchecked(move.direction),
                        .decr => r = r.decrUnchecked(move.direction),
                    }
                },
                .border => {
                    switch (move.sign) {
                        .incr => r = r.incr(move.direction) orelse return 0,
                        .decr => r = r.decr(move.direction) orelse return 0,
                    }
                },
            }
            neighbors |= @enumToInt(opacity(r)) << i;
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

    

    fn createShaderHeader() [:0]const u8 {
        const Header = struct {

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
                try w.writeAll("const vec2 cube_uvs_face[4] = vec2[4](");
                try w.writeAll("vec2(0, 1), vec2(1, 1), vec2(0, 0), vec2(1, 0)");
                try w.writeAll(");\n");
                try w.writeAll("const vec3 cube_umat_texture[6] = vec3[6](");
                for (std.enums.values(Cardinal3)) |card_n, i| {
                    if (i != 0) {
                        try w.writeAll(",");
                    }
                    const umat = Vec3.unitSigned(cardU(card_n));
                    try w.print("vec3{}", .{ umat });
                }
                try w.writeAll(");\n");
                try w.writeAll("const vec3 cube_vmat_texture[6] = vec3[6](");
                for (std.enums.values(Cardinal3)) |card_n, i| {
                    if (i != 0) {
                        try w.writeAll(",");
                    }
                    const vmat = Vec3.unitSigned(cardV(card_n));
                    try w.print("vec3{}", .{ vmat });
                }
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
        return std.fmt.comptimePrint("{}", .{ Header{}});
    }

};


