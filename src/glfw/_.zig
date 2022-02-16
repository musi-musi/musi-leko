const panic = @import("std").debug.panic;

const c = @import("c");
const window = @import("window.zig");
pub const Window = window.Window;
// pub usingnamespace @import("window.zig");
// pub usingnamespace @import("mouse.zig");
// pub usingnamespace @import("keyboard.zig");
// pub usingnamespace @import("time.zig");

pub fn init() void {
    if (c.glfwInit() == 0) {
        panic("Failed to initialise GLFW\n", .{});
    }
}

pub fn deinit() void {
    c.glfwTerminate();
}