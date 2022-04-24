const std = @import("std");
const rendering = @import(".zig");
const client = @import("../.zig");
const nm = client.nm;

const Mat4 = nm.Mat4;

pub const Camera = struct {

    proj: Mat4,
    view: Mat4,

    near_plane: f32 = 0.01,
    far_plane: f32 = 1000,
    fov: f32 = 90.0,

    const Self = @This();

    pub fn calculatePerspective(self: *Self, width: usize, height: usize) void {
        const aspect = @intToFloat(f32, width) / @intToFloat(f32, height);
        self.proj = nm.transform.createPerspective(self.fov * std.math.pi / 180.0, aspect, self.near_plane, self.far_plane);
    }

};