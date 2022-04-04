const std = @import("std");

const client = @import("../_.zig");

const nm = client.nm;
const window = client.window;

const input = @import("_.zig");

const InputHandle = input.InputHandle;

pub const MouseLook = struct {

    handle: *InputHandle,
    sensitivity: f32 = 0.1,
    invert_y: bool = false,
    look_angles: nm.Vec2 = nm.Vec2.zero,

    const Self = @This();

    pub fn init(self: *Self, input_handle: *InputHandle) void {
        self.* = .{
            .handle = input_handle,
        };
    }

    pub fn update(self: *Self) void {
        if (self.handle.is_active) {
            var angles_delta = window.mousePositionDelta().mulScalar(self.sensitivity);
            var look_x = self.look_angles.v[0] + angles_delta.v[0];
            var look_y = self.look_angles.v[1] + angles_delta.v[1];
            if (self.invert_y) {
                look_y *= -1;
            }
            if (look_y > 90) {
                look_y = 90;
            }
            if (look_y < -90) {
                look_y = -90;
            }
            look_x = @mod(look_x, 360);
            self.look_angles.v = .{look_x, look_y };
        }
    }

    pub fn viewMatrix(self: Self) nm.Mat4 {
        return nm.transform.createEulerZXY(
            nm.vec3(.{
                -self.look_angles.get(.y) * std.math.pi / 180.0,
                -self.look_angles.get(.x) * std.math.pi / 180.0,
                0,
            }
        ));
    }

};