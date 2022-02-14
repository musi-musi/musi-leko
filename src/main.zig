const std = @import("std");
const builtin = @import("builtin");
const gl = @import("gl.zig");
const glfw = @import("glfw.zig");

const nm = @import("nm");

const render = @import("render");

pub fn main() !void {
    glfw.init();
    defer glfw.deinit();
    
    const width = 1920;
    const height = 1080;

    var window = glfw.Window.init(width, height, "a toki ma!");
    defer window.deinit();

    gl.init();
    window.setVsyncMode(.enabled);

    gl.viewport(0, 0, width, height);

    var ht = try render.init();
    defer ht.deinit();

    while (!window.shouldClose()) {
        ht.draw();
        window.update();
        window.swapBuffers();
    }
}