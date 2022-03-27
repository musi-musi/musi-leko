const std = @import("std");
const nm = @import("nm");

const window = @import("window");
const input = @import("input");
const gui = @import("gui");
const leko = @import("leko");

const Vec3 = nm.Vec3;
const Vec3i = nm.Vec3i;
const Mat4 = nm.Mat4;

pub const Player = struct {

    position: Vec3 = Vec3.zero,
    move_speed: f32 = 10,
    noclip_enabled: bool = true,
    noclip_speed: f32 = 50,

    input_handle: input.InputHandle = .{},
    mouse_look: input.MouseLook = undefined,

    const Self = @This();

    pub fn init(self: *Self) void {
        self.* = Self {};
        self.mouse_look.init(&self.input_handle);
    }

    pub fn update(self: *Self) void {
        const delta = @floatCast(f32, window.frameTime());
        if (self.noclip_enabled) {
            if (self.input_handle.is_active) {
                self.mouse_look.update();
                const view_matrix = self.mouse_look.viewMatrix();
                const forward = view_matrix.transformDirection(nm.Vec3.unit(.z)).mulScalar(delta * self.noclip_speed);
                const right = view_matrix.transformDirection(nm.Vec3.unit(.x)).mulScalar(delta * self.noclip_speed);
                const up = nm.Vec3.unit(.y).mulScalar(delta * self.noclip_speed);
                if (window.keyIsDown(.w)) self.position = self.position.add(forward);
                if (window.keyIsDown(.s)) self.position = self.position.sub(forward);
                if (window.keyIsDown(.a)) self.position = self.position.sub(right);
                if (window.keyIsDown(.d)) self.position = self.position.add(right);
                if (window.keyIsDown(.space)) self.position = self.position.add(up);
                if (window.keyIsDown(.left_shift)) self.position = self.position.sub(up);
            }
        }
    }

    pub fn viewMatrix(self: Self) Mat4 {
        return nm.transform.createTranslate(
            self.position.neg()
        ).mul(self.mouse_look.viewMatrix());
    }

};