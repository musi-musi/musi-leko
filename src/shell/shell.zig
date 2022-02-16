const std = @import("std");

const c = @import("c");
const gl = @import("gl");
const window = @import("window.zig");

const Window = window.Window;

pub const Shell = struct {
    
    window: Window,
    
    const Self = @This();

    pub const Error  = error {
        InitializationFailed,
    };

    pub fn init() !Self{
        if (c.glfwInit() == 0) {
            return Error.InitializationFailed;
        }
        return Self{
            .window = undefined,
        };
    }

    pub fn start(self: *Self, width: u32, height: u32, title: [:0]const u8) !void {
        var w = try Window.init(width, height, title);
        self.window = w;
        gl.init();
        gl.viewport(0, 0, @intCast(c_int, width), @intCast(c_int, height));

    }

    pub fn deinit(self: Self) void {
        _ = self;
        c.glfwTerminate();
    }

    pub fn nextFrame(self: Self) bool {
        return self.window.nextFrame();
    }

};