const std = @import("std");
const nm = @import("nm");

const lk = @import("_.zig");

const Chunk = lk.Chunk;

const Axis3 = nm.Axis3;
const Cardinal3 = nm.Cardinal3;

const Vec3u = nm.Vec3u;
const Vec3i = nm.Vec3i;

/// local address into chunk data
/// used to locate a leko inside a chunk
/// wraps an integer that packs x, y, z indices
/// each component takes up `config.chunk_width_bits`
/// > MSB <-> LSB
/// >   x  y  z
pub const Address = struct {
    v: Value = 0,

    /// unsigned int with `chunk_width_bits * 3` bits
    pub const Value = std.meta.Int(.unsigned, Chunk.width_bits * 3);
    /// unsigned int with `chunk_width_bits` bits
    pub const UComponent = std.meta.Int(.unsigned, Chunk.width_bits);
    /// signed int with `chunk_width_bits` bits
    pub const IComponent = std.meta.Int(.signed, Chunk.width_bits);

    pub const component_min: UComponent = std.math.minInt(UComponent);
    pub const component_max: UComponent = std.math.maxInt(UComponent);

    const zero = Self{ .v = 0 };
    
    
    const Self = @This();

    /// init address from 3 integers
    /// out of range integers are protected UB
    pub fn init(comptime T: type, value: [3]T) Self {
        return Self {
            .v = (
                shl(@intCast(Value, @intCast(UComponent, value[0])), (Chunk.width_bits * 2)) |
                shl(@intCast(Value, @intCast(UComponent, value[1])), (Chunk.width_bits * 1)) |
                    @intCast(Value, @intCast(UComponent, value[2]))
            ),
        };
    }

    // init from usize (convenient casting)
    pub fn initI(i: usize) Self {
        return .{ .v = @intCast(Value, i), };
    }

    /// init address with only a single component, leaving the others zero
    /// out of range integers are protected UB
    pub fn initSingle(comptime T: type, value: T, comptime axis: Axis3) Self {
        return Self {
            .v = shl(@intCast(Value, @intCast(UComponent, value)), bitOffset(axis)),
        };
    }

    /// return a specific component
    pub fn get(self: Self, comptime axis: Axis3) UComponent {
        return @truncate(UComponent, std.math.shr(Value, self.v, bitOffset(axis)));
    }

    /// convert to a local location vector
    pub fn localLocation(self: Self) Vec3u {
        return Vec3u.init(.{
            get(self, .x),
            get(self, .y),
            get(self, .z),
        });
    }

    pub fn bitOffset(comptime axis: Axis3) u32 {
        return Chunk.width_bits * (2 - @enumToInt(axis));
    }

    fn shr(value: Value, shift: u32) Value {
        return std.math.shr(Value, value, shift);
    }

    fn shl(value: Value, shift: u32) Value {
        return std.math.shr(Value, value, shift);
    }

    /// increment this address in `direction`, checking bounds
    /// returns null if out of bounds
    pub fn incr(self: Self, comptime direction: Cardinal3) ?Self {
        if (self.get(comptime direction.axis()) == comptime edgeComponent(direction)) {
            return null;
        }
        else {
            return self.incrUnchecked(direction);
        }
    }

    /// decrement this address in `direction`, checking bounds
    /// returns null if out of bounds
    pub fn decr(self: Self, comptime direction: Cardinal3) ?Self {
        return self.incr(comptime direction.neg());
    }
    
    pub fn edgeComponent(comptime direction: Cardinal3) UComponent {
        return switch (direction.sign()) {
            .positive => ~ @as(UComponent, 0),
            .negative =>   @as(UComponent, 0),
        };
    }

    pub fn edge(comptime direction: Cardinal3) Self {
        return initSingle(UComponent, edgeComponent(direction), direction.axis());
    }

    /// increment this address in `direction`. no bounds checking
    /// out of bounds will give incorrect result
    pub fn incrUnchecked(self: Self, comptime direction: Cardinal3) Self {
        const n = component_max;
        const offset = comptime switch (direction) {
            .x_pos => init(UComponent, .{1, 0, 0}),
            .x_neg => init(UComponent, .{n, 0, 0}),
            .y_pos => init(UComponent, .{0, 1, 0}),
            .y_neg => init(UComponent, .{n, n, 0}),
            .z_pos => init(UComponent, .{0, 0, 1}),
            .z_neg => init(UComponent, .{n, n, n}),
        };
        return Self { .v = self.v +% offset.v };
    }

    /// decrement this address in `direction`. no bounds checking
    /// out of bounds will give incorrect result
    pub fn decrUnchecked(self: Self, comptime direction: Cardinal3) Self {
        return self.incrUnchecked(comptime direction.neg());
    }


};


/// a global reference to a leko in a chunk
/// used to locate a leko inside an entire volume
pub const Reference = struct {
  
    chunk: *Chunk,
    address: Address,

    const Self = @This();

    pub fn init(chunk: *Chunk, address: Address) Self {
        return Self {
            .chunk = chunk,
            .address = address,
        };
    }

    /// attempt to get a `Reference` given a global position in `volume`
    /// if the location is in a chunk that isnt created, return null
    pub fn initFromGlobalLocation(volume: *const lk.Volume, loc: Vec3i) ?Self {
        const chunk_position = loc.divFloorScalar(Chunk.width);
        if (volume.chunks.get(chunk_position)) |chunk| {
            return init(chunk, Address.init(i32, loc.sub(chunk_position.mulScalar(Chunk.width))).v);
        }
        else {
            return null;
        }
    }

    /// convert to a global location vector
    pub fn globalLocation(self: Self) Vec3i {
        return self.chunk.position.mulScalar(Chunk.width).add(self.address.localLocation().cast(i32));
    }

    /// increment this reference in `direction`
    /// no bounds checking, no crossing chunk borders
    /// out of bounds will return incorrect result
    pub fn incrUnchecked(self: Self, comptime direction: Cardinal3) Self {
        return init(self.chunk, self.address.incrUnchecked(direction));
    }

    /// decrement this reference in `direction`
    /// no bounds checking, no crossing chunk borders
    /// out of bounds will return incorrect result
    pub fn decrUnchecked(self: Self, comptime direction: Cardinal3) Self {
        return init(self.chunk, self.address.decrUnchecked(direction));
    }

    /// increment this reference in `direction`,
    /// checking bounds and crossing chunk borders
    /// returns null if neighbor chunk is not created
    pub fn incr(self: Self, comptime direction: Cardinal3) ?Self {
        if (self.address.incr(direction)) |address| {
            return init(self.chunk, address);
        }
        else {
            if (self.chunk.neighbor(direction)) |neighbor| {
                const mask = (
                    Address.zero.v | Address.initSingle(
                        Address.UComponent,
                        Address.component_max,
                        comptime direction.axis()
                    ).v
                );
                const address = switch (comptime direction.sign()) {
                    .positive => Address{.v = self.address.v & ~mask},
                    .negative => Address{.v = self.address.v |  mask},
                };
                return init(neighbor, address);
            }
            else {
                return null;
            }
        }
    }

    /// decrement this reference in `direction`,
    /// checking bounds and crossing chunk borders
    /// returns null if neighbor chunk is not created
    pub fn decr(self: Self, comptime direction: Cardinal3) ?Self {
        return self.incr(comptime direction.neg());
    }

};