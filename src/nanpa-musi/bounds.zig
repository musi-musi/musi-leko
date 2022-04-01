const std = @import("std");

const asserts = @import("asserts.zig");
const vector = @import("vector.zig");

pub const Bounds2 = Bounds(f32, 2);
pub const Bounds3 = Bounds(f32, 3);
pub const Bounds4 = Bounds(f32, 4);

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

pub const Range2 = Range(f32, 2);
pub const Range3 = Range(f32, 3);
pub const Range4 = Range(f32, 4);

pub const Range2i = Range(i32, 2);
pub const Range3i = Range(i32, 3);
pub const Range4i = Range(i32, 4);

pub const Range2u = Range(u32, 2);
pub const Range3u = Range(u32, 3);
pub const Range4u = Range(u32, 4);

pub fn Range(comptime Scalar_: type, comptime dimensions_: comptime_int) type {
    comptime asserts.assertFloatOrInt(Scalar_);
    comptime asserts.assertValidDimensionCount(dimensions_);

    return struct {

        min: Vector,
        max: Vector,

        pub const Scalar = Scalar_;
        pub const dimensions = dimensions_;
        pub const Vector = vector.Vector(Scalar, dimensions);

        const Self = @This();

        pub fn init(min: Vector.Value, max: Vector.Value) Self {
            return .{
                .min = Vector.init(min),
                .max = Vector.init(max),
            };
        }

    };  
}