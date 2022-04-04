const std = @import("std");
const engine = @import("../.zig");
const nm = engine.nm;

const leko = @import(".zig");

const config = leko.config;
const Address = leko.Address;

const Cardinal3 = nm.Cardinal3;

const Vec3i = nm.Vec3i;
const vec3i = nm.vec3i;

pub const LekoId = u16;

pub const Chunk = struct {
    
    position: Vec3i,
    id_array: IdArray,
    neighbors: Neighbors,
    state: State,

    pub const State = enum {
        /// chunk is in the pool, data is undefined
        inactive,
        /// chunk is in the volume, data is being generated or loaded
        loading,
        /// chunk is in the volume and ready for gameplay and rendering
        active,
    };

    pub const IdArray = LekoArray(LekoId);
    pub const Neighbors = [6]?*Self;

    pub const width_bits = config.chunk_width_bits;
    pub const width = config.chunk_width;

    const Self = @This();

    pub fn init(self: *Self, position: Vec3i) void {
        self.position = position;
        self.neighbors = std.mem.zeroes(Neighbors);
        self.state = .loading;
    }

    pub fn deinit(self: *Self) void {
        self.state = .inactive;
    }

    pub fn neighbor(self: Self, comptime direction: Cardinal3) ?*Self {
        return self.neighbors[@enumToInt(direction)];
    }

};

pub fn LekoArray(comptime Element_: type) type{
    return struct {
        items: Value,

        pub const Element = Element_;
        pub const Value = [width * width * width]Element;
        pub const width = Chunk.width;

        const Self = @This();

        pub fn get(self: Self, address: Address) Element {
            return self.items[address.v];
        }

    };
}
