const c = @import("../c.zig");

pub const config = @import("config.zig");

const buffer = @import("buffer.zig");
const array = @import("array.zig");
const program = @import("program.zig");
const texture = @import("texture.zig");
const draw = @import("draw.zig");
pub usingnamespace buffer;
pub usingnamespace array;
pub usingnamespace program;
pub usingnamespace texture;
pub usingnamespace draw;

pub fn init() void {
    if (c.gladLoadGLLoader(@ptrCast(c.GLADloadproc, c.glfwGetProcAddress)) == 0) {
        @panic("Failed to initialise GLAD");
    }
    c.glEnable(c.GL_DEPTH_TEST);
    c.glDisable(c.GL_MULTISAMPLE);
    c.glEnable(c.GL_CULL_FACE);
}

pub fn viewport(x: c_int, y: c_int, width: c_int, height: c_int) void{
    c.glViewport(x, y, width, height);
}