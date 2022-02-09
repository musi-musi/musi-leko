const panic = @import("std").debug.panic;

const c =@import("../c.zig");
// usingnamespace @import("mouse.zig");
// usingnamespace @import("keyboard.zig");
// usingnamespace @import("time.zig");

const nm = @import("nm");

pub const Vec2i = nm.Vec2i;

pub const Window = struct {

    handle: Handle,
    // mouse: Mouse,
    // keyboard: Keyboard,
    // time: FrameTimer,
    display_mode: DisplayMode,
    windowed_pos: Vec2i,
    windowed_size: Vec2i,

    pub const Handle = *c.GLFWwindow;

    const Self = @This();

    pub fn init(width: c_int, height: c_int, title: [:0]const u8) Self {
        // yeah its hardcoded eat my ass
        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 4);
        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 5);
        c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
        c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GL_TRUE);
        // c.glfwWindowHint(c.GLFW_SAMPLES, 4);

        const window_opt: ?Handle = c.glfwCreateWindow(width, height, title, null, null);
        if (window_opt == null) {
            panic("Failed to create GLFW window\n", .{});
        }
        const window = window_opt.?;
        c.glfwMakeContextCurrent(window);

        _ = c.glfwSetFramebufferSizeCallback(window, frameBufferSizeCallback);
        c.glfwPollEvents();

        var self = Self{
            .handle = window,
            // .mouse = Mouse.init(window),
            // .keyboard = Keyboard.init(window),
            // .time = FrameTimer.init(),
            .display_mode = .windowed,
            .windowed_pos = Vec2i.zero,
            .windowed_size = Vec2i.zero,
        };
        self.saveWindowedShape();
        return self;

    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }
    
    fn saveWindowedShape(self: *Self) void {
        var pos: Vec2i = undefined;
        c.glfwGetWindowPos(self.handle, &pos.v[0], &pos.v[1]);
        const size: Vec2i = self.getFrameBufferSize();
        self.windowed_pos = pos;
        self.windowed_size = size;
    }

    pub fn update(self: *Self) void {
        _ = self;
        c.glfwPollEvents();
        // self.mouse.update();
        // self.keyboard.update();
        // self.time.update();
    }

    pub fn shouldClose(self: Self) bool {
        return c.glfwWindowShouldClose(self.handle) != 0;
    }

    pub fn setShouldClose(self: Self, should_close: bool) void {
        c.glfwSetWindowShouldClose(self.handle, @boolToInt(should_close));
    }

    pub fn swapBuffers(self: Self) void {
        c.glfwSwapBuffers(self.handle);
    }

    pub fn setVsyncMode(self: Self, mode: VsyncMode) void {
        _ = self;
        c.glfwSwapInterval(@enumToInt(mode));
    }
    
    pub const VsyncMode = enum(c_int) {
        disabled = 0,
        enabled = 1,
    };

    pub fn setDisplayMode(self: *Self, mode: DisplayMode, vsync_mode: VsyncMode) void {
        var monitor: *c.GLFWmonitor = c.glfwGetPrimaryMonitor().?;
        var vidmode: *const c.GLFWvidmode = c.glfwGetVideoMode(monitor);
        switch(mode) {
            // .windowed => {
            //     c.glfwRestoreWindow(self.handle);
            //     c.glfwSetWindowAttrib(self.handle, c.GLFW_FLOATING, c.GLFW_FALSE);
            //     c.glfwSetWindowAttrib(self.handle, c.GLFW_DECORATED, c.GLFW_TRUE);
            // },
            // .borderless => {
            //     c.glfwSetWindowAttrib(self.handle, c.GLFW_DECORATED, c.GLFW_FALSE);
            //     c.glfwMaximizeWindow(self.handle);
            //     c.glfwSetWindowAttrib(self.handle, c.GLFW_FLOATING, c.GLFW_TRUE);
            // },
            .windowed => {
                const pos = self.windowed_pos;
                const size = self.windowed_size;
                c.glfwSetWindowMonitor(self.handle, null, pos.x, pos.y, size.x, size.y, 0);
            },
            .borderless => {
                self.saveWindowedShape();
                c.glfwSetWindowMonitor(self.handle, monitor, 0, 0, vidmode.width, vidmode.height, vidmode.refreshRate);
            },
        }
        self.display_mode = mode;
        self.setVsyncMode(vsync_mode);
    }

    pub const DisplayMode = enum {
        windowed,
        borderless,
    };

    pub fn getFrameBufferSize(self: Self) Vec2i {
        var frame_buffer_size: Vec2i = undefined;
        c.glfwGetFramebufferSize(self.handle, &frame_buffer_size.v[0], &frame_buffer_size.v[1]);
        return frame_buffer_size;
    }

    fn frameBufferSizeCallback(window: ?Handle, width: c_int, height: c_int) callconv(.C) void {
        _ = window;
        // make sure the viewport matches the new window dimensions; note that width and
        // height will be significantly larger than specified on retina displays.
        c.glViewport(0, 0, width, height);
    }


};