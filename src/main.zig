const std = @import("std");
const builtin = @import("builtin");
const gl = @import("gl.zig");
const glfw = @import("glfw.zig");

const nm = @import("nm");

pub fn main() anyerror!void {
    glfw.init();
    defer glfw.deinit();
    
    var window = glfw.Window.init(640, 360, "a toki ma!");
    defer window.deinit();

    gl.init();

    while (!window.shouldClose()) {
        window.update();
        window.swapBuffers();
    }
}