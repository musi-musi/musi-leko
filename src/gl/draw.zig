const std = @import("std");
const c = @import("c");
const buffer = @import("buffer.zig");

pub fn clearColor(color: [4]f32) void {
    c.glClearColor(color[0], color[1], color[2], color[3]);
}

pub const DepthBits = enum {
    float,
    double,

    pub fn Type(comptime self: DepthBits) type {
        return switch(self) {
            .float => f32,
            .double => f64,
        };
    }

};

pub fn clearDepth(comptime bits: DepthBits, depth: bits.Type()) void {
    c.glClearDepth(@floatCast(f64, depth));
}

pub fn clearStencil(stencil: i32) void {
    c.glClearStencil(stencil);
}

pub const ClearFlags = enum(u32) {
    color = c.GL_COLOR_BUFFER_BIT,
    depth = c.GL_DEPTH_BUFFER_BIT,
    stencil = c.GL_STENCIL_BUFFER_BIT,
    color_depth = c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT,
    depth_stencil = c.GL_DEPTH_BUFFER_BIT | c.GL_STENCIL_BUFFER_BIT,
    color_stencil = c.GL_COLOR_BUFFER_BIT | c.GL_STENCIL_BUFFER_BIT,
    color_depth_stencil = c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT | c.GL_STENCIL_BUFFER_BIT,
};

pub fn clear(flags: ClearFlags) void {
    c.glClear(@enumToInt(flags));
}

pub const PrimitiveType = enum(c_uint) {
    points = c.GL_POINTS,
    line_strip = c.GL_LINE_STRIP,
    line_loop = c.GL_LINE_LOOP,
    lines = c.GL_LINES,
    triangle_strip = c.GL_TRIANGLE_STRIP,
    triangle_fan = c.GL_TRIANGLE_FAN,
    triangles = c.GL_TRIANGLES,
};

pub fn drawElementsOffset(primitive_type: PrimitiveType, index_count: usize, comptime index_element: buffer.IndexElement, offset: usize) void {
    c.glDrawElements(@enumToInt(primitive_type), @intCast(c_int, index_count), @enumToInt(index_element), @intToPtr(?*anyopaque, offset));
}

pub fn drawElements(primitive_type: PrimitiveType, index_count: usize, comptime index_element: buffer.IndexElement) void {
    drawElementsOffset(primitive_type, index_count, index_element, 0);
}

pub fn drawElementsInstanced(primitive_type: PrimitiveType, index_count: usize, comptime index_element: buffer.IndexElement, instance_count: usize) void {
    c.glDrawElementsInstanced(
        @enumToInt(primitive_type),
        @intCast(c_int, index_count),
        @enumToInt(index_element),
        null,
        @intCast(c_int, instance_count),
    );
}