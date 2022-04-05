const rendering = @import(".zig");
const client = @import("../.zig");
const nm = client.nm;

const Mat4 = nm.Mat4;

pub const Camera = struct {

    proj: Mat4,
    view: Mat4,

};