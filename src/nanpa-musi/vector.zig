const std = @import("std");
const asserts = @import("asserts.zig");
const axis = @import("axis.zig");
const cardinal = @import("cardinal.zig");

pub const Vec2 = Vector(f32, 2);
pub const Vec3 = Vector(f32, 3);
pub const Vec4 = Vector(f32, 4);

pub fn vec2(v: Vec2.Value) Vec2 {
    return Vec2.init(v);
}
pub fn vec3(v: Vec3.Value) Vec3 {
    return Vec3.init(v);
}
pub fn vec4(v: Vec4.Value) Vec4 {
    return Vec4.init(v);
}

pub const Vec2d = Vector(f64, 2);
pub const Vec3d = Vector(f64, 3);
pub const Vec4d = Vector(f64, 4);

pub fn vec2d(v: Vec2d.Value) Vec2d {
    return Vec2d.init(v);
}
pub fn vec3d(v: Vec3d.Value) Vec3d {
    return Vec3d.init(v);
}
pub fn vec4d(v: Vec4d.Value) Vec4d {
    return Vec4d.init(v);
}

pub const Vec2i = Vector(i32, 2);
pub const Vec3i = Vector(i32, 3);
pub const Vec4i = Vector(i32, 4);

pub fn vec2i(v: Vec2i.Value) Vec2i {
    return Vec2i.init(v);
}
pub fn vec3i(v: Vec3i.Value) Vec3i {
    return Vec3i.init(v);
}
pub fn vec4i(v: Vec4i.Value) Vec4i {
    return Vec4i.init(v);
}

pub const Vec2u = Vector(u32, 2);
pub const Vec3u = Vector(u32, 3);
pub const Vec4u = Vector(u32, 4);

pub fn vec2u(v: Vec2u.Value) Vec2u {
    return Vec2u.init(v);
}
pub fn vec3u(v: Vec3u.Value) Vec3u {
    return Vec3u.init(v);
}
pub fn vec4u(v: Vec4u.Value) Vec4u {
    return Vec4u.init(v);
}

pub fn Vector(comptime Scalar_: type, comptime dimensions_: comptime_int) type {
    comptime asserts.assertFloatOrInt(Scalar_);
    comptime asserts.assertValidDimensionCount(dimensions_);
    return extern struct {
        
        v: Value,

        pub const Value = [dimensions]Scalar;
        pub const Scalar = Scalar_;
        pub const dimensions = dimensions_;

        pub const Axis = axis.Axis(dimensions);
        pub const Cardinal = cardinal.Cardinal(dimensions);

        pub const axes = Axis.values;
        pub const indices = ([4]u32{0, 1, 2, 3})[0..dimensions];

        const Self = @This();

        pub const zero = fill(0);
        pub const one = fill(1);

        pub fn init(v: Value) Self {
            return .{ .v = v};
        }

        pub fn get(self: Self, comptime a: Axis) Scalar {
            return self.v[@enumToInt(a)];
        }
        pub fn set(self: *Self, comptime a: Axis, v: Scalar) void {
            self.v[@enumToInt(a)] = v;
        }
        pub fn ptr(self: *const Self, comptime a: Axis) *const Scalar {
            return &(self.v[@enumToInt(a)]);
        }
        pub fn ptrMut(self: *Self, comptime a: Axis) *Scalar {
            return &(self.v[@enumToInt(a)]);
        }

        pub fn cast(self: Self, comptime S: type) Vector(S, dimensions) {
            var result: Vector(S, dimensions) = undefined;
            inline for(indices) |i| {
                switch (@typeInfo(Scalar)) {
                    .Float => switch (@typeInfo(S)) {
                        .Float => result.v[i] = @floatCast(S, self.v[i]),
                        .Int => result.v[i] = @floatToInt(S, self.v[i]),
                        else => unreachable,
                    },
                    .Int => switch (@typeInfo(S)) {
                        .Float => result.v[i] = @intToFloat(S, self.v[i]),
                        .Int => result.v[i] = @intCast(S, self.v[i]),
                        else => unreachable,
                    },
                    else => unreachable,
                }
            }
            return result;
        }

        /// lower this vector by one dimension, discarding last component
        pub fn removeDimension(self: Self) Vector(Scalar, dimensions - 1) {
            return Vector(Scalar, dimensions - 1).init(self.v[0..(dimensions - 1)].*);
        }
        
        /// raise this vector by one dimension, appending v as the value for the last component
        pub fn addDimension(self: Self, v: Scalar) Vector(Scalar, dimensions + 1) {
            const Target = Vector(Scalar, dimensions + 1);
            var res: Target = undefined;
            inline for(indices) |i| {
                res.v[i] = self.v[i];
            }
            res.v[dimensions] = v;
            return res;
        }

        pub fn toAffinePosition(self: Self) Vector(Scalar, dimensions + 1) {
            return self.addDimension(1);
        }
        pub fn toAffineDirection(self: Self) Vector(Scalar, dimensions + 1) {
            return self.addDimension(0);
        }

        pub fn fill(v: Scalar) Self {
            var res: Self = undefined;
            inline for(indices) |i| {
                res.v[i] = v;
            }
            return res;
        }

        pub fn unit(comptime a: Axis) Self {
            comptime {
                var res = fill(0);
                res.set(a, 1);
                return res;
            }
        }

        pub fn unitSigned(comptime c: Cardinal) Self {
            comptime {
                return switch (c.sign()) {
                    .positive => unit(c.axis()),
                    .negative => unit(c.axis()).neg(),
                };
            }
        }

        pub fn eql(a: Self, b: Self) bool {
            inline for (indices) |i| {
                if (a.v[i] != b.v[i]) {
                    return false;
                }
            }
            return true;
        }

        /// unary negation
        pub fn neg(self: Self) Self {
            var res: Self = undefined;
            inline for (indices) |i| {
                res.v[i] = -self.v[i];
            }
            return res;
        }

        /// component-wise floor
        pub fn floor(self: Self) Self {
            var res: Self = undefined;
            inline for (indices) |i| {
                res.v[i] = std.math.floor(self.v[i]);
            }
            return res;
        }

        /// component-wise addition
        pub fn add(a: Self, b: Self) Self {
            var res: Self = undefined;
            inline for (indices) |i| {
                res.v[i] = a.v[i] + b.v[i];
            }
            return res;
        }

        /// component-wise subtraction
        pub fn sub(a: Self, b: Self) Self {
            var res: Self = undefined;
            inline for (indices) |i| {
                res.v[i] = a.v[i] - b.v[i];
            }
            return res;
        }

        /// component-wise multiplication
        pub fn mul(a: Self, b: Self) Self {
            var res: Self = undefined;
            inline for (indices) |i| {
                res.v[i] = a.v[i] * b.v[i];
            }
            return res;
        }

        /// component-wise division
        pub fn div(a: Self, b: Self) Self {
            var res: Self = undefined;
            inline for (indices) |i| {
                res.v[i] = a.v[i] / b.v[i];
            }
            return res;
        }

        /// scalar multiplication
        pub fn mulScalar(a: Self, b: Scalar) Self {
            var res: Self = undefined;
            inline for (indices) |i| {
                res.v[i] = a.v[i] * b;
            }
            return res;
        }

        /// scalar division
        pub fn divScalar(a: Self, b: Scalar) Self {
            var res: Self = undefined;
            inline for (indices) |i| {
                res.v[i] = a.v[i] / b;
            }
            return res;
        }

        /// sum of components
        pub fn sum(self: Self) Scalar {
            var res: Scalar = 0;
            inline for (indices) |i| {
                res += self.v[i];
            }
            return res;
        }

        /// product of components
        pub fn product(self: Self) Scalar {
            var res: Scalar = 0;
            inline for (indices) |i| {
                res *= self.v[i];
            }
            return res;
        }

        /// dot product
        pub fn dot(a: Self, b: Self) Scalar {
            return a.mul(b).sum();
        }

        /// square magnitude
        pub fn mag2(self: Self) Scalar {
            return self.dot(self);
        }

        /// magnitude
        pub fn mag(self: Self) Scalar {
            return std.math.sqrt(self.mag2());
        }

        /// normalized
        pub fn norm(self: Self) Self {
            return self.divScalar(self.mag());
        }

        /// cross product
        /// using with non-3d vectors is a compile error
        pub fn cross(a: Self, b: Self) Self {
            if (dimensions != 3) @compileError("cannot compute cross product of non 3d vectors");
            var res: Self = undefined;
            res.v[0] = a.v[1] * b.v[2] - a.v[2] * b.v[1];
            res.v[1] = a.v[2] * b.v[0] - a.v[0] * b.v[2];
            res.v[2] = a.v[0] * b.v[1] - a.v[1] * b.v[0];
            return res;
        }


        pub fn format(self: Self, comptime fmt: []const u8, _: std.fmt.FormatOptions, w: anytype) !void {
            try w.writeAll("(");
            inline for (indices) |i| {
                if (i != 0) {
                    try w.writeAll(", ");
                }
                try w.print("{" ++ fmt ++ "}", .{ self.v[i] });
            }
            try w.writeAll(")");
        }


    };
}