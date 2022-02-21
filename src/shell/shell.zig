const std = @import("std");

const c = @import("c");
const gl = @import("gl");
const window = @import("window.zig");

const Window = window.Window;

const Allocator = std.mem.Allocator;

pub const Error  = error {
    InitializationFailed,
    AlreadyRunning,
};

var running_shell: ?*Shell = null;

pub fn init(allocator: Allocator, width: u32, height: u32, title: [:0]const u8) !*Shell {
    if (running_shell != null) {
        return Error.AlreadyRunning;
    }
    if (c.glfwInit() == 0) {
        return Error.InitializationFailed;
    }
    running_shell = try Shell.create(allocator, width, height, title);
    return running_shell.?;
}

pub fn deinit() void {
    if (running_shell) |rs| {
        rs.destroy();
    }
    c.glfwTerminate();
}

pub const Shell = struct {
    
    allocator: Allocator,
    window: Window,
    
    const Self = @This();

    fn create(allocator: Allocator, width: u32, height: u32, title: [:0]const u8) !*Self{
        var self = try allocator.create(Self);
        self.* = Self{
            .allocator = allocator,
            .window = undefined,
        };
        try self.window.init(width, height, title);
        return self;
    }

    fn destroy(self: *Self) void {
        self.allocator.destroy(self);
    }

    pub fn nextFrame(self: Self) bool {
        return self.window.nextFrame();
    }

};



