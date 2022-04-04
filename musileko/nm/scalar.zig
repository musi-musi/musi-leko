const nm = @import("_.zig");

pub fn lerp(comptime T: type, a: T, b: T, t: T) T {
    comptime nm.assertFloat(T);
    return a + ((b - a) * t);
}