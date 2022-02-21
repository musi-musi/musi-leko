pub const demos = struct {

    pub const triangle = @import("demos/triangle.zig");

};

const shader = @import("shader.zig");

pub usingnamespace shader;