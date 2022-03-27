const std = @import("std");
const asserts = @import("asserts.zig");

fn Mixin(comptime Self: type, comptime dimensions_: comptime_int) type {
    return struct {

        pub const dimensions = dimensions_;
        pub const values = std.enums.values(Self);

    };
}

pub fn Axis(comptime dimensions: comptime_int) type {
    comptime asserts.assertValidDimensionCount(dimensions);
    return switch (dimensions) {
        1 => enum {
            x, y,
            const Self = @This();
            const mixin = Mixin(Self, dimensions);
            pub usingnamespace mixin;
        },
        2 => enum {
            x, y,
            const Self = @This();
            const mixin = Mixin(Self, dimensions);
            pub usingnamespace mixin;
        },
        3 => enum {
            x, y, z,
            const Self = @This();
            const mixin = Mixin(Self, dimensions);
            pub usingnamespace mixin;
        },
        4 => enum {
            x, y, z, w,
            const Self = @This();
            const mixin = Mixin(Self, dimensions);
            pub usingnamespace mixin;
        },
        else => unreachable,
    };
}

pub const Axis2 = Axis(2);
pub const Axis3 = Axis(3);
pub const Axis4 = Axis(4);