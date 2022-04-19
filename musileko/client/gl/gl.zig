const gl = @import(".zig");
const client = @import("../.zig");
const c = client.c;

pub fn init() void {
    if (c.gladLoadGLLoader(@ptrCast(c.GLADloadproc, c.glfwGetProcAddress)) == 0) {
        @panic("Failed to initialise GLAD");
    }
    c.glEnable(c.GL_DEPTH_TEST);
    c.glDepthFunc(c.GL_LESS);
    c.glDisable(c.GL_MULTISAMPLE);
    // c.glEnable(c.GL_MULTISAMPLE);
    c.glEnable(c.GL_CULL_FACE);
}

pub fn viewport(x: c_int, y: c_int, width: c_int, height: c_int) void{
    c.glViewport(x, y, width, height);
}

pub fn enableDepthTest() void {
    c.glEnable(c.GL_DEPTH_TEST);
}

pub fn disableDepthTest() void {
    c.glDisable(c.GL_DEPTH_TEST);
}