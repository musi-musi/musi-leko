const client = @import("../_.zig");
const c = client.c;
const gl = client.gl;
const window = @import("_.zig");

pub const Handle = *c.GLFWwindow;

var _handle: Handle = undefined;
var _width: u32 = 0;
var _height: u32 = 0;
var _shape: WindowShape = undefined;
var _display_mode: DisplayMode = .windowed;
var _vsync_mode: VsyncMode = .enabled;



pub fn handle() Handle {
    return _handle;
}

pub fn width() u32 {
    return _width;
}

pub fn height() u32 {
    return _height;
}

pub fn close() void {
    c.glfwSetWindowShouldClose(_handle, c.GLFW_TRUE);
}

pub const DisplayMode = enum {
    windowed,
    borderless,
};

pub const VsyncMode = enum(c_int) {
    disabled = 0,
    enabled = 1,
};

pub fn setDisplayMode(mode: DisplayMode) void {
    const monitor: *c.GLFWmonitor = c.glfwGetPrimaryMonitor().?;
    const video_mode: *const c.GLFWvidmode = c.glfwGetVideoMode(monitor);
    switch (mode) {
        .windowed => {
            c.glfwSetWindowMonitor(_handle, null, _shape.x, _shape.y, _shape.width, _shape.height, 0);
        },
        .borderless => {
            saveWindowShape();
            c.glfwSetWindowMonitor(_handle, monitor, 0, 0, video_mode.width, video_mode.height, video_mode.refreshRate);
        },
    }
    setVsyncMode(_vsync_mode);
    _display_mode = mode;
}

pub fn setVsyncMode(mode: VsyncMode) void {
    _vsync_mode = mode;
    c.glfwSwapInterval(@enumToInt(mode));
}

pub fn displayMode() DisplayMode {
    return _display_mode;
}
pub fn vsyncMode() VsyncMode {
    return _vsync_mode;
}



pub const Error = error {
    GlfwInitializationFailed,
    WindowCreationFailed,
};

pub const Config = struct {
    width: u32 = 1280,
    height: u32 = 720,
    title: [*c]const u8 = "musi",
};

pub fn init(config: Config) !void {

    if (c.glfwInit() == 0) {
        return Error.GlfwInitializationFailed;
    }
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, gl.config.version_major);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, gl.config.version_minor);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
    c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GL_TRUE);
    c.glfwWindowHint(c.GLFW_SAMPLES, 4);

    _width = config.width;
    _height = config.height;

    const handle_opt = c.glfwCreateWindow(@intCast(c_int, _width), @intCast(c_int, _height), config.title, null, null);
    if (handle_opt == null) {
        return Error.WindowCreationFailed;
    }
    _handle = handle_opt.?;
    c.glfwMakeContextCurrent(_handle);
    _ = c.glfwSetFramebufferSizeCallback(_handle, frameBufferSizeCallback);

    gl.init();
    gl.viewport(0, 0, @intCast(c_int, _width), @intCast(c_int, _height));

    saveWindowShape();

    window.initTime();
    window.initMouse();
}

fn frameBufferSizeCallback(_: ?Handle, width_: c_int, height_: c_int) callconv(.C) void {
    _width = @intCast(u32, width_);
    _height = @intCast(u32, height_);
    gl.viewport(0, 0, width_, height_);
}

pub fn deinit() void {
    c.glfwDestroyWindow(_handle);
    c.glfwTerminate();
}

pub const WindowShape = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
};

pub fn nextFrame() bool {
    c.glfwSwapBuffers(_handle);
    c.glfwPollEvents();
    return c.glfwWindowShouldClose(_handle) == 0;
}

fn saveWindowShape() void {
    c.glfwGetWindowPos(_handle, &_shape.x, &_shape.y);
    c.glfwGetFramebufferSize(_handle, &_shape.width, &_shape.height);
}

pub fn update() bool {
    if (nextFrame()) {
        window.updateTime();
        window.updateKeys();
        window.updateMouse();
        return true;
    }
    else {
        return false;
    }
}