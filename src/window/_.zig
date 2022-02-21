const c = @import("c");
const gl = @import("gl");

const window = @import("window.zig");
pub usingnamespace window.exports;

pub const WindowConfig = window.Config;


pub const Error = error {
    GlfwInitializationFailed,
};

pub fn init(config: WindowConfig) !void {
    if (c.glfwInit() == 0) {
        return Error.GlfwInitializationFailed;
    }
    try window.init(config);
}

pub fn deinit() void {
    window.deinit();
    c.glfwTerminate();
}