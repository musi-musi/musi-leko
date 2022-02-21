pub const demos = struct {

    pub const triangle = @import("demos/triangle.zig");
    pub const cube = @import("demos/cube.zig");

};

const shader = @import("shader.zig");

pub usingnamespace shader;