const std = @import("std");

const asserts = @import("asserts.zig");
const vector = @import("vector.zig");

pub fn Bounds(comptime Scalar_: type, comptime dimensions_: comptime_int) type {
    comptime asserts.assertFloatOrInt(Scalar_);
    comptime asserts.assertValidDimensionCount(dimensions_);

    return struct {
        center: Vector,
        radius: Vector,


        pub const Scalar = Scalar_;
        pub const dimensions = dimensions_;
        pub const Vector = vector.Vector(Scalar, dimensions);

        const Self = @This();

        pub fn init(center: Vector.Value, radius: Vector.Value) Self {
            return Self {
                .center = Vector.init(center),
                .radius = Vector.init(radius),
            };
        }

        pub fn min(self: Self) Vector {
            return self.center.sub(self.radius);
        }

        pub fn max(self: Self) Vector {
            return self.center.add(self.radius);
        }

    };

}