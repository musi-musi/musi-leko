const std = @import("std");

pub fn assertValidDimensionCount(comptime dim: comptime_int) void {
    switch (dim) {
        1, 2, 3, 4 => {},
        else => @compileError("only 1, 2, 3, or 4 dimensions allowed"),
    }
}

pub fn assertFloatOrInt(comptime T: type) void {
    switch (@typeInfo(T)) {
        .Float, .Int => {},
        else => @compileError("only float or int types allowed"),
    }
}

pub fn assertFloat(comptime T: type) void {
    switch (@typeInfo(T)) {
        .Float => {},
        else => @compileError("only float types allowed"),
    }
}

pub fn assertInt(comptime T: type) void {
    switch (@typeInfo(T)) {
        .Int => {},
        else => @compileError("only float types allowed"),
    }
}