const std = @import("std");
const nm = @import("nm");

const leko = @import("_.zig");

const Chunk = leko.Chunk;

const Cardinal3 = nm.Cardinal3;

pub const Address = struct {
    /// MSB <-> LSB
    ///  x   y   z
    v: Value = 0,

    pub const Value = std.meta.Int(.unsigned, Chunk.width_bits * 3);
    pub const Width = std.meta.Int(.unsigned, Chunk.width_bits);
    const IWidth = std.meta.Int(.signed, Chunk.width_bits);
    pub const Vector = nm.Vec3u;

    const Self = @This();

    pub const zero = Self { .v = 0 };

    pub fn init(comptime T: type, value: [3]T) Self {
        var self: Self = .{};
        comptime var i = 0;
        inline while (i < 3) : (i += 1) {
            self.v = (self.v << Chunk.width_bits) | @intCast(Width, value[i]);
        }
        return self;
    }

    pub fn initI(value: usize) Self {
        return .{
            .v = @intCast(Value, value),
        };
    }

    pub fn get(self: Self, comptime axis: nm.Axis3) Width {
        return @truncate(Width, self.v >> (Chunk.width_bits * (2 - @enumToInt(axis))));
    }


    pub fn isEdge(self: Self, comptime direction: nm.Cardinal3) bool {
        const w: Width = @intCast(Width, Chunk.width - 1);
        return switch (comptime direction.sign()) {
            .positive => self.get(comptime direction.axis()) == w,
            .negative => self.get(comptime direction.axis()) == 0,
        };
    }

    /// move this index to the edge of the chunk in `direction`
    pub fn toEdge(self: Self, comptime direction: nm.Cardinal3) Self {
        const w: Width = @intCast(Width, Chunk.width - 1);
        return switch (comptime direction.sign()) {
            .positive => .{ .v = self.v | single(Width, w, comptime direction.axis()).v},
            .negative => .{ .v = self.v & ~single(Width, w, comptime direction.axis()).v},
        };
    }

    pub fn edge(comptime T: type, offset: T, comptime direction: nm.Cardinal3) Self {
        const w: Width = @intCast(Width, Chunk.width - 1);
        return switch (comptime direction.sign()) {
            .positive => .{ .v = single(u32, w - offset, comptime direction.axis()).v},
            .negative => .{ .v = single(u32, offset, comptime direction.axis()).v},
        };
    }

    pub fn single(comptime T: type, value: T, comptime axis: nm.Axis3) Self {
        return Self {
            .v = @intCast(Value, value) << (Chunk.width_bits * (2 - @enumToInt(axis))),
        };
    }


    pub fn vector(self: Self) Vector {
        return Vector.init(.{
            @truncate(Width, self.v >> Chunk.width_bits * 2),
            @truncate(Width, self.v >> Chunk.width_bits * 1),
            @truncate(Width, self.v >> Chunk.width_bits * 0),
        });
    }

    /// increment this index one cell in a cardinal direction
    /// trying to increment out of bounds is UB, only use when in bounds
    pub fn incrUnchecked(self: Self, comptime card: nm.Cardinal3) Self {
        const w: Width = @intCast(Width, Chunk.width - 1);
        const offset = comptime switch (card) {
            .x_pos => init(Width, .{1, 0, 0}),
            .x_neg => init(Width, .{w, 0, 0}),
            .y_pos => init(Width, .{0, 1, 0}),
            .y_neg => init(Width, .{w, w, 0}),
            .z_pos => init(Width, .{0, 0, 1}),
            .z_neg => init(Width, .{w, w, w}),
        };
        return .{ .v = self.v +% offset.v};
    }

    /// decrement this index one cell in a cardinal direction
    /// trying to increment out of bounds is UB, only use when in bounds
    pub fn decrUnchecked(self: Self, comptime card: nm.Cardinal3) Self {
        return self.incrUnchecked(comptime card.neg());
    }

};

pub const Reference = struct {
        
    chunk: *Chunk,
    address: Address,

    const Self = @This();

    pub fn init(chunk: *Chunk, address: Address) Self {
        return .{
            .chunk = chunk,
            .address = address,
        };
    }

    pub fn incrUnchecked(self: Self, comptime direction: Cardinal3) Self {
        return init(self.chunk, self.address.incrUnchecked(direction));
    }

    pub fn decrUnchecked(self: Self, comptime direction: Cardinal3) Self {
        return init(self.chunk, self.address.decrUnchecked(direction));
    }

    pub fn incr(self: Self, comptime direction: Cardinal3) ?Self {
        var result = self;
        const pos = direction;
        const neg = comptime direction.neg();
        if (result.address.isEdge(pos)) {
            if (result.chunk.neighbor(pos)) |neighbor| {
                result.chunk = neighbor;
                result.address = result.address.toEdge(neg);
            }
            else {
                return null;
            }
        }
        else {
            result.address = result.address.incrUnchecked(pos);
        }
        return result;
    }

    pub fn decr(self: Self, comptime direction: Cardinal3) ?Self {
        return self.incr(comptime direction.neg());
    }

};