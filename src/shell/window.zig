const std = @import("std");
const c = @import("c");
const gl = @import("gl");

pub const Window = struct {
    
    handle: Handle,

    pub const Handle = *c.GLFWwindow;

    const Self = @This();

    pub const Error = error {
        WindowCreationFailed,
    };

    pub fn init(width: u32, height: u32, title: [:0]const u8) Error!Self {
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

        var self = Self {
            .handle = handle,
        };
        return self;
    }

    pub fn nextFrame(self: Self) bool {
        c.glfwSwapBuffers(self.handle);
        c.glfwPollEvents();
        return c.glfwWindowShouldClose(self.handle) == 0;
    }

    fn frameBufferSizeCallback(window: ?Handle, width: c_int, height: c_int) callconv(.C) void {
        _ = window;
        gl.viewport(0, 0, width, height);
    }

};