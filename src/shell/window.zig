const std = @import("std");
const c = @import("c");
const gl = @import("gl");

const Shell = @import("shell.zig").Shell;
const Allocator = std.mem.Allocator;

pub const Window = struct {
    
    handle: Handle,
    width: u32,
    height: u32,

    pub const Handle = *c.GLFWwindow;

    const Self = @This();

    pub const Error = error {
        WindowCreationFailed,
    };

    pub fn init(self: *Self, width: u32, height: u32, title: [:0]const u8) Error!void {
        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, gl.config.version_major);
        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, gl.config.version_minor);
        c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
        c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GL_TRUE);

        const handle_opt = c.glfwCreateWindow(@intCast(c_int, width), @intCast(c_int, height), title, null, null);
        if (handle_opt == null) {
            return Error.WindowCreationFailed;
        }
        const handle = handle_opt.?;
        c.glfwMakeContextCurrent(handle);
        _ = c.glfwSetFramebufferSizeCallback(handle, frameBufferSizeCallback);

        gl.init();
        gl.viewport(0, 0, @intCast(c_int, width), @intCast(c_int, height));

        c.glfwSetWindowUserPointer(handle, self.shell());

        self.* = Self {
            .handle = handle,
            .width = width,
            .height = height,
        };
    }

    pub fn deinit(self: Self) void {
        c.glfwDestroyWindow(self.handle);
    }

    fn shell(self: *Self) *Shell {
        return @fieldParentPtr(Shell, "window", self);
    }

    pub fn nextFrame(self: Self) bool {
        c.glfwSwapBuffers(self.handle);
        c.glfwPollEvents();
        return c.glfwWindowShouldClose(self.handle) == 0;
    }

    fn frameBufferSizeCallback(window: ?Handle, width: c_int, height: c_int) callconv(.C) void {
        _ = window;
        var sh = @ptrCast(*align(1)Shell, c.glfwGetWindowUserPointer(window.?));
        sh.window.width = @intCast(u32, width);
        sh.window.height = @intCast(u32, height);
        gl.viewport(0, 0, width, height);
    }

};