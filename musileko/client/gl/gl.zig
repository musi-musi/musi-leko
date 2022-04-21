const gl = @import(".zig");
const client = @import("../.zig");
const c = client.c;

pub fn init() void {
    if (c.gladLoadGLLoader(@ptrCast(c.GLADloadproc, c.glfwGetProcAddress)) == 0) {
        @panic("Failed to initialise GLAD");
    }
    c.glEnable(c.GL_DEPTH_TEST);
    c.glDepthFunc(c.GL_LESS);
    c.glDisable(c.GL_MULTISAMPLE);
    // c.glEnable(c.GL_MULTISAMPLE);
    c.glEnable(c.GL_CULL_FACE);
    c.glEnable(c.GL_FRAMEBUFFER_SRGB);

    // setup gl debug
    c.glEnable(c.GL_DEBUG_OUTPUT);
    c.glEnable(c.GL_DEBUG_OUTPUT_SYNCHRONOUS);
    c.glDebugMessageCallback(gl_debug_callback, null);
}

pub fn viewport(x: c_int, y: c_int, width: c_int, height: c_int) void{
    c.glViewport(x, y, width, height);
}

pub fn enableDepthTest() void {
    c.glEnable(c.GL_DEPTH_TEST);
}

pub fn disableDepthTest() void {
    c.glDisable(c.GL_DEPTH_TEST);
}

const std = @import("std");
const panic = std.debug.panic;

const gl_debug_log = std.log.scoped(.gl_debug);

pub fn gl_debug_callback(
    source: c_uint,
    debugtype: c_uint,
    id: c_uint,
    severity: c_uint,
    length: c_int,
    message: [*c]const u8,
    user_param: ?*const anyopaque,
) callconv(.C) void {
    _ = length;
    _ = user_param;

    const source_str = switch (source) {
        c.GL_DEBUG_SOURCE_API => "API",
        c.GL_DEBUG_SOURCE_APPLICATION => "Application",
        c.GL_DEBUG_SOURCE_OTHER => "Other",
        c.GL_DEBUG_SOURCE_SHADER_COMPILER => "Compiler",
        c.GL_DEBUG_SOURCE_THIRD_PARTY => "Third Party",
        c.GL_DEBUG_SOURCE_WINDOW_SYSTEM => "Window System",
        else => panic("Invalid GL debug source {}", .{ source }),
    };

    const debugtype_str = switch (debugtype) {
        c.GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR => "Deprecated Behavior",
        c.GL_DEBUG_TYPE_ERROR => "Error",
        c.GL_DEBUG_TYPE_MARKER => "Marker",
        c.GL_DEBUG_TYPE_OTHER => "Other",
        c.GL_DEBUG_TYPE_PERFORMANCE => {
            // NOTE: ignoring all PERFORMANCE messages because they appear quite often, they might be worth paying attention to once the app is actually in "need to optimize" mode
            return;
            //"Performance"
        },
        c.GL_DEBUG_TYPE_POP_GROUP => "Pop Group",
        c.GL_DEBUG_TYPE_PORTABILITY => "Portability",
        c.GL_DEBUG_TYPE_PUSH_GROUP => "Push Group",
        c.GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR => "Undefined Behavior",
        else => panic("Invalid GL debug type {}", .{ debugtype }),
    };

    switch (severity) {
        c.GL_DEBUG_SEVERITY_NOTIFICATION => {
            // NOTE: ignoring all NOTIFICATION messages because the sheer volume of nvidia / windows notification messages is causing problems of an unknown type that eventually crash the app
            // if (source != c.GL_DEBUG_SOURCE_SHADER_COMPILER) {
            //     // ignore shader compiler notifications by default as it produces a good number of them and they're not super useful
            //     gl_debug_log.info("ID: {X}, Source: {s}, Type: {s}, Message: {s}", .{id, source_str, debugtype_str, message});
            // }
        },
        c.GL_DEBUG_SEVERITY_LOW => {
            gl_debug_log.debug("ID: {X}, Source: {s}, Type: {s}, Message: {s}", .{id, source_str, debugtype_str, message});
        },
        c.GL_DEBUG_SEVERITY_MEDIUM => {
            gl_debug_log.warn("ID: {X}, Source: {s}, Type: {s}, Message: {s}", .{id, source_str, debugtype_str, message});
        },
        c.GL_DEBUG_SEVERITY_HIGH => {
            gl_debug_log.err("ID: {X}, Source: {s}, Type: {s}, Message: {s}", .{id, source_str, debugtype_str, message});
            // panic("ID: {X}, Source: {s}, Type: {s}, Message: {s}", .{id, source_str, debugtype_str, message});
        },
        else => panic("Invalid GL debug severity {}", .{ severity }),
    }
}
