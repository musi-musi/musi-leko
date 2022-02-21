const c = @import("c");
const gl = @import("gl");

const window = @import("window.zig");
pub usingnamespace window.exports;
const time = @import("time.zig");
pub usingnamespace time.exports;

pub const keys = @import("keys.zig");
pub usingnamespace keys.exports;

pub const KeyState = keys.KeyState;
pub const KeyCode = keys.KeyCode;

pub const WindowConfig = window.Config;


pub const Error = error {
    GlfwInitializationFailed,
};

pub fn init(config: WindowConfig) !void {
    if (c.glfwInit() == 0) {
        return Error.GlfwInitializationFailed;
    }
    try window.init(config);
    time.init();
}

pub fn deinit() void {
    window.deinit();
    c.glfwTerminate();
}

pub fn update() bool {
    if (window.nextFrame()) {
        time.update();
        keys.update();
        return true;
    }
    else {
        return false;
    }
}