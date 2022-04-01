const std = @import("std");
const nm = @import("nm");
const session = @import("_.zig");

const window = @import("window");
const input = @import("input");
const gui = @import("gui");
const leko = @import("leko");

const Vec3 = nm.Vec3;
const Vec3i = nm.Vec3i;
const Mat4 = nm.Mat4;
const Bounds3 = nm.Bounds3;

pub const Player = struct {

    bounds: Bounds3 = .{
        .center = Vec3.zero,
        .radius = Vec3.init(.{0.8, 1.8, 0.8}),
    },
    eye_height: f32 = 0.9,
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
        var move = Vec3.zero;
        if (self.input_handle.is_active) {
            if (window.keyWasPressed(.z)) {
                self.noclip_enabled = !self.noclip_enabled;
            }
            self.mouse_look.update();
            const view_matrix = self.mouse_look.viewMatrix();
            const forward = view_matrix.transformDirection(nm.Vec3.unit(.z)).mulScalar(delta);
            const right = view_matrix.transformDirection(nm.Vec3.unit(.x)).mulScalar(delta);
            const up = nm.Vec3.unit(.y).mulScalar(delta);
            if (window.keyIsDown(.w)) move = move.add(forward);
            if (window.keyIsDown(.s)) move = move.sub(forward);
            if (window.keyIsDown(.a)) move = move.sub(right);
            if (window.keyIsDown(.d)) move = move.add(right);
            if (window.keyIsDown(.space)) move = move.add(up);
            if (window.keyIsDown(.left_shift)) move = move.sub(up);
        }
        if (self.noclip_enabled) {
            self.bounds.center = self.bounds.center.add(move.mulScalar(self.noclip_speed));
        }
        else {
            move = move.mulScalar(self.move_speed);
            const volume = session.volume();
            _ = leko.moveBoundsAxis(volume, &self.bounds, move.get(.x), .x);
            _ = leko.moveBoundsAxis(volume, &self.bounds, move.get(.y), .y);
            _ = leko.moveBoundsAxis(volume, &self.bounds, move.get(.z), .z);
        }
    }

    pub fn viewMatrix(self: Self) Mat4 {
        return nm.transform.createTranslate(
            self.bounds.center.add(Vec3.init(.{0, self.eye_height, 0})).neg()
        ).mul(self.mouse_look.viewMatrix());
    }

};