const std = @import("std");
const asserts = @import("asserts.zig");
const Axis_ = @import("axis.zig").Axis;

pub const Cardinal2 = Cardinal(2);
pub const Cardinal3 = Cardinal(3);
pub const Cardinal4 = Cardinal(4);

pub fn Cardinal(comptime dimensions_: comptime_int) type {
    comptime asserts.assertValidDimensionCount(dimensions_);
    return switch (dimensions_) {
        1 => enum {
            x_pos,
            x_neg,

            const Self = @This();
            const mixin = Mixin(Self, dimensions_);
            pub usingnamespace mixin;
        },
        2 => enum {
            x_pos,
            x_neg,
            y_pos,
            y_neg,

            const Self = @This();
            const mixin = Mixin(Self, dimensions_);
            pub usingnamespace mixin;
        },
        3 => enum {
            x_pos,
            x_neg,
            y_pos,
            y_neg,
            z_pos,
            z_neg,

            const Self = @This();
            const mixin = Mixin(Self, dimensions_);
            pub usingnamespace mixin;
        },
        4 => enum {
            x_pos,
            x_neg,
            y_pos,
            y_neg,
            z_pos,
            z_neg,
            w_pos,
            w_neg,

            const Self = @This();
            const mixin = Mixin(Self, dimensions_);
            pub usingnamespace mixin;
        },
        else => unreachable,
    };
}

fn Mixin(comptime Self: type, comptime dimensions_: comptime_int) type {
    return struct {

        pub const dimensions = dimensions_;
        pub const Axis = Axis_(dimensions);
        const AxisTag = std.meta.Tag(Axis);

        pub fn axis(self: Self) Axis {
            return @intToEnum(Axis, @truncate(AxisTag, @enumToInt(self) >> 1));
        }

        pub fn sign(self: Self) Sign {
            return @intToEnum(Sign, @truncate(u1, @enumToInt(self) % 2));
        }

        pub fn neg(self: Self) Self {
            return @intToEnum(Self, @enumToInt(self) ^ 1);
        }

    };
}

pub const Sign = enum(u1) {
    positive, negative
};