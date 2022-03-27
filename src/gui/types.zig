const std = @import("std");
const c = @import("c");
const nm = @import("nm");

const Vec2 = nm.Vec2;
const Vec4 = nm.Vec4;

pub const CVec2 = c.ImVec2;
pub const CVec4 = c.ImVec4;



pub fn cvec2(value: [2]f32) CVec2 {
    return @bitCast(CVec2, value);
}

pub fn cvec3(value: [3]f32) CVec4 {
    var v = [4]f32 {
        value[0],
        value[1],
        value[2],
        0,
    };
    return cvec4(v);
}

pub fn cvec4(value: [4]f32) CVec4 {
    return @bitCast(CVec4, value);
}

pub fn sumFlags(comptime Enum: type, flags: []const Enum) c_int {
    var flags_sum: c_int = 0;
    for (flags) |flag| {
        flags_sum |= @enumToInt(flag);
    }
    return flags_sum;
}