const std = @import("std");

const nm = @import(".zig");

pub const Bounds2 = Bounds(f32, 2);
pub const Bounds3 = Bounds(f32, 3);
pub const Bounds4 = Bounds(f32, 4);

pub fn Bounds(comptime Scalar_: type, comptime dimensions_: comptime_int) type {
    comptime nm.assertFloatOrInt(Scalar_);
    comptime nm.assertValidDimensionCount(dimensions_);

    return struct {
        center: Vector,
        radius: Vector,


        pub const Scalar = Scalar_;
        pub const dimensions = dimensions_;
        pub const Vector = nm.Vector(Scalar, dimensions);

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
    comptime nm.assertFloatOrInt(Scalar_);
    comptime nm.assertValidDimensionCount(dimensions_);

    return struct {

        min: Vector,
        max: Vector,

        pub const Scalar = Scalar_;
        pub const dimensions = dimensions_;
        pub const Vector = nm.Vector(Scalar, dimensions);
        pub const Axis = nm.Axis(dimensions);

        const Self = @This();

        pub fn init(min: Vector.Value, max: Vector.Value) Self {
            return .{
                .min = Vector.init(min),
                .max = Vector.init(max),
            };
        }

        pub fn contains(self: Self, v: Vector) bool {
            inline for (comptime std.enums.values(Axis)) |a| {
                switch (@typeInfo(Scalar)) {
                    .Int => {
                        if (v.get(a) < self.min.get(a) or v.get(a) >= self.max.get(a)) {
                            return false;
                        }
                    },
                    .Float => {
                        if (v.get(a) < self.min.get(a) or v.get(a) > self.max.get(a)) {
                            return false;
                        }
                    },
                    else => unreachable,
                }
            }
            return true;
        }

    };  
}