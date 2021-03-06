const std = @import("std");
const engine = @import("../.zig");
const nm = engine.nm;

const leko = @import(".zig");

const Chunk = leko.Chunk;
const Volume = leko.Volume;

const Cardinal3 = nm.Cardinal3;

const Vec3u = nm.Vec3u;
const Vec3i = nm.Vec3i;

const shr = std.math.shr;
const shl = std.math.shl;

pub const Address = struct {
    /// MSB <-> LSB
    ///  x   y   z
    v: Value = 0,

    pub const Value = std.meta.Int(.unsigned, Chunk.width_bits * 3);
    pub const Width = std.meta.Int(.unsigned, Chunk.width_bits);

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

    pub fn get(self: Self, axis: nm.Axis3) Width {
        return @truncate(Width, shr(Value, self.v, (Chunk.width_bits * (2 - @enumToInt(axis)))));
    }


    pub fn isEdge(self: Self, direction: nm.Cardinal3) bool {
        const w: Width = @intCast(Width, Chunk.width - 1);
        return switch (direction.sign()) {
            .positive => self.get(direction.axis()) == w,
            .negative => self.get(direction.axis()) == 0,
        };
    }

    /// move this index to the edge of the chunk in `direction`
    pub fn toEdge(self: Self, direction: nm.Cardinal3) Self {
        const w: Width = @intCast(Width, Chunk.width - 1);
        return switch (direction.sign()) {
            .positive => .{ .v = self.v | single(Width, w, direction.axis()).v},
            .negative => .{ .v = self.v & ~single(Width, w, direction.axis()).v},
        };
    }

    pub fn edge(comptime T: type, offset: T, direction: nm.Cardinal3) Self {
        const w: Width = @intCast(Width, Chunk.width - 1);
        return switch (direction.sign()) {
            .positive => .{ .v = single(u32, w - offset, direction.axis()).v},
            .negative => .{ .v = single(u32, offset, direction.axis()).v},
        };
    }

    pub fn single(comptime T: type, value: T, axis: nm.Axis3) Self {
        return Self {
            .v = shl(Value, @intCast(Value, value), (Chunk.width_bits * (2 - @enumToInt(axis)))),
        };
    }

    pub fn localPosition(self: Self) Vec3i {
        return Vec3i.init(.{
            @truncate(Width, shr(Value, self.v, Chunk.width_bits * 2)),
            @truncate(Width, shr(Value, self.v, Chunk.width_bits * 1)),
            @truncate(Width, shr(Value, self.v, Chunk.width_bits * 0)),
        });
    }

    /// increment this index one cell in a cardinal direction
    /// trying to increment out of bounds is UB, only use when in bounds
    pub fn incrUnchecked(self: Self, card: nm.Cardinal3) Self {
        const w: Width = @intCast(Width, Chunk.width - 1);
        const offset = switch (card) {
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
    pub fn decrUnchecked(self: Self, card: nm.Cardinal3) Self {
        return self.incrUnchecked(card.neg());
    }

};

pub const Reference = ReferenceImpl(*Chunk);
pub const ConstReference = ReferenceImpl(*const Chunk);

fn ReferenceImpl(comptime ChunkPtr: type) type {
    return struct {
            
        chunk: ChunkPtr,
        address: Address,

        const Self = @This();

        pub fn init(chunk: ChunkPtr, address: Address) Self {
            return .{
                .chunk = chunk,
                .address = address,
            };
        }

        pub fn initGlobalPosition(volume: *Volume, position: Vec3i) ?Self {
            const chunk_position = position.divFloorScalar(Chunk.width);
            if (volume.chunks.get(chunk_position)) |chunk| {
                const local_position = position.sub(chunk_position.mulScalar(Chunk.width));
                return init(chunk, Address.init(i32, local_position.v));
            }
            else {
                return null;
            }
        }

        pub fn toConst(self: Self) ConstReference {
            return ConstReference.ini(self.chunk, self.address);
        }

        pub fn incrUnchecked(self: Self, comptime direction: Cardinal3) Self {
            return init(self.chunk, self.address.incrUnchecked(direction));
        }

        pub fn decrUnchecked(self: Self, comptime direction: Cardinal3) Self {
            return init(self.chunk, self.address.decrUnchecked(direction));
        }

        pub fn incr(self: Self, direction: Cardinal3) ?Self {
            var result = self;
            const pos = direction;
            const neg = direction.neg();
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

        pub fn decr(self: Self, direction: Cardinal3) ?Self {
            return self.incr(direction.neg());
        }

        pub fn globalPosition(self: Self) Vec3i {
            return self.chunk.position.mulScalar(Chunk.width).add(self.address.localPosition());
        }

    };

}
