const vector = @import("vector.zig");
pub usingnamespace vector;
const axis = @import("axis.zig");
pub usingnamespace axis;
const cardinal = @import("cardinal.zig");
pub usingnamespace cardinal;
const matrix = @import("matrix.zig");
pub usingnamespace matrix;
const bounds = @import("bounds.zig");
pub usingnamespace bounds;


pub usingnamespace @import("transform.zig");

pub const noise = @import("noise/_.zig");

const asserts = @import("asserts.zig");

pub fn lerp(comptime T: type, a: T, b: T, t: T) T {
    comptime asserts.assertFloat(T);
    return a + ((b - a) * t);
}