const std = @import("std");
const math = std.math;

const mat4 = @import("math/zalgebra/src/mat4.zig");
const quaternion = @import("math/zalgebra/src/quaternion.zig");
const vec2 = @import("math/zalgebra/src/vec2.zig");
const vec3 = @import("math/zalgebra/src/vec3.zig");
const vec4 = @import("math/zalgebra/src/vec4.zig");

pub const Quaternion = quaternion.Quaternion;

pub fn Matrix(comptime T: type, comptime dimensions: u32) type {
    return switch (dimensions) {
        4 => mat4.Mat4x4(T),
        else => @compileError("unsupported matrix size"),
    };
}

pub fn Vector(comptime T: type, comptime dimensions: u32) type {
    return switch(dimensions) {
        2 => vec2.Vector2(T),
        3 => vec3.Vector3(T),
        4 => vec4.Vector4(T),
        else => @compileError("unsupported vector size"),
    };
}

pub const Vec2 = Vector(f32, 2);
pub const Vec3 = Vector(f32, 3);
pub const Vec4 = Vector(f32, 4);

pub const Vec2i = Vector(i32, 2);
pub const Vec3i = Vector(i32, 3);
pub const Vec4i = Vector(i32, 4);

pub const Vec2u = Vector(u32, 2);
pub const Vec3u = Vector(u32, 3);
pub const Vec4u = Vector(u32, 4);

pub const Mat4 = Matrix(f32, 4);

pub const Quat = Quaternion(f32);

/// Convert degrees to radians.
pub fn toRadians(degrees: anytype) @TypeOf(degrees) {
    const T = @TypeOf(degrees);

    return switch (@typeInfo(T)) {
        .Float => degrees * (math.pi / 180.0),
        else => @compileError("Radians not implemented for " ++ @typeName(T)),
    };
}

/// Convert radians to degrees.
pub fn toDegrees(radians: anytype) @TypeOf(radians) {
    const T = @TypeOf(radians);

    return switch (@typeInfo(T)) {
        .Float => radians * (180.0 / math.pi),
        else => @compileError("Degrees not implemented for " ++ @typeName(T)),
    };
}

/// Linear interpolation between two floats.
/// `t` is used to interpolate between `from` and `to`.
pub fn lerp(comptime T: type, from: T, to: T, t: T) T {
    return switch (@typeInfo(T)) {
        .Float => (1 - t) * from + t * to,
        else => @compileError("Lerp not implemented for " ++ @typeName(T)),
    };
}