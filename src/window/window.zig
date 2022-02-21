const c = @import("c");
const gl = @import("gl");

pub const Handle = *c.GLFWwindow;

pub var handle: Handle = undefined;
pub var width: u32 = 0;
pub var height: u32 = 0;

pub const exports = struct {

    pub fn getWidth() u32 {
        return width;
    }

    pub fn getHeight() u32 {
        return height;
    }

    pub fn nextFrame() bool {
        c.glfwSwapBuffers(handle);
        c.glfwPollEvents();
        return c.glfwWindowShouldClose(handle) == 0;
    }

};

pub const Error = error {
    WindowCreationFailed,
};

pub const Config = struct {
    width: u32 = 1280,
    height: u32 = 720,
    title: [*c]const u8 = "musi",
};

pub fn init(config: Config) !void {
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, gl.config.version_major);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, gl.config.version_minor);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
    c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GL_TRUE);

    width = config.width;
    height = config.height;

    const handle_opt = c.glfwCreateWindow(@intCast(c_int, width), @intCast(c_int, height), config.title, null, null);
    if (handle_opt == null) {
        return Error.WindowCreationFailed;
    }
    handle = handle_opt.?;
    c.glfwMakeContextCurrent(handle);
    _ = c.glfwSetFramebufferSizeCallback(handle, frameBufferSizeCallback);

    gl.init();
    gl.viewport(0, 0, @intCast(c_int, width), @intCast(c_int, height));

}

fn frameBufferSizeCallback(window: ?Handle, width_: c_int, height_: c_int) callconv(.C) void {
    _ = window;
    width = @intCast(u32, width_);
    height = @intCast(u32, height_);
    gl.viewport(0, 0, width_, height_);
}

pub fn deinit() void {
    c.glfwDestroyWindow(handle);
}