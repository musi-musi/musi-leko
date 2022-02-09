const c = @import("../c.zig");

const std = @import("std");
const builtin = std.builtin;
const meta = std.meta;

pub fn VertexArray(comptime IndexT: type) type {

    return struct {

        handle: c_int,

        const Self = @This();

        pub fn init() Self {

        }
    };

}