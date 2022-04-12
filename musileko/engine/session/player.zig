const std = @import("std");

const engine = @import("../.zig");
const leko = engine.leko;

const session = @import(".zig");


const client = @import("../../client/.zig");
const window = client.window;
const input = client.input;

const nm = engine.nm;

const Vec3 = nm.Vec3;
const Vec3i = nm.Vec3i;
const Mat4 = nm.Mat4;
const Bounds3 = nm.Bounds3;
const Axis3 = nm.Axis3;

const sm = std.math;

const gravity: f32 = 40;


pub const Player = struct {

    bounds: Bounds3 = .{
        .center = undefined,
        .radius = Vec3.init(.{0.8, 1.8, 0.8}),
    },
    
    eye_height: f32 = 1.5,
    eye_height_step_offset: f32 = 0,
    move_speed: f32 = 15,
    jump_height: f32 = 2.2,
    velocity_y: f32 = 0,
    is_grounded: bool = false,

    noclip_enabled: bool = true,
    noclip_speed: f32 = 50,

    input_handle: input.InputHandle = .{},
    mouse_look: input.MouseLook = undefined,

    prev_position: Vec3 = undefined,
    next_position: Vec3 = undefined,
    position: Vec3 = Vec3.zero,

    select_range: f32 = 8,
    select_reference: ?leko.RaycastHit = null,

    const Self = @This();

    pub fn init(self: *Self) void {
        self.* = Self {};
        self.mouse_look.init(&self.input_handle);
        self.bounds.center = self.position;
        self.prev_position = self.position;
        self.next_position = self.position;
    }

    pub fn update(self: *Self) !void {
        // const delta = @floatCast(f32, window.frameTime());
        if (self.input_handle.keyWasPressed(.z)) {
            self.noclip_enabled = !self.noclip_enabled;
        }
        self.mouse_look.update();
        const look_matrix = self.mouse_look.viewMatrix();
        const look_direction = look_matrix.transformDirection(Vec3.unit(.z));
        self.select_reference = leko.raycast(
            session.volume(), 
            self.eyePosition(),
            look_direction,
            self.select_range,
        );

        self.position = self.prev_position.lerpTo(self.next_position, session.tickLerp());

        if (self.select_reference) |select_reference| {
            if (self.input_handle.keyWasPressed(.mouse_1)) {
                try session.volumeManager().requestSingleEdit(select_reference.reference, 0);
            }
            if (select_reference.normal) |normal| {
                if (self.input_handle.keyWasPressed(.mouse_2)) {
                    if (select_reference.reference.incr(normal)) |reference| {
                        try session.volumeManager().requestSingleEdit(reference, 1);
                    }
                }
            }
        }

    }

    pub fn tick(self: *Self) void {
        self.prev_position = self.next_position;
        if (self.noclip_enabled) {
            self.moveNoclip();
        }
        else {
            self.moveNormal();
        }
        self.next_position = self.bounds.center.add(Vec3.init(.{0, self.eye_height_step_offset, 0}));
    }

    fn moveNoclip(self: *Self) void {
        const delta = session.config.tickDuration();
        var move = Vec3.zero;
        const view_matrix = self.mouse_look.viewMatrix();
        const forward = view_matrix.transformDirection(nm.Vec3.unit(.z)).mulScalar(delta);
        const right = view_matrix.transformDirection(nm.Vec3.unit(.x)).mulScalar(delta);
        const up = nm.Vec3.unit(.y).mulScalar(delta);
        if (self.input_handle.keyIsDown(.w)) move = move.add(forward);
        if (self.input_handle.keyIsDown(.s)) move = move.sub(forward);
        if (self.input_handle.keyIsDown(.a)) move = move.sub(right);
        if (self.input_handle.keyIsDown(.d)) move = move.add(right);
        if (self.input_handle.keyIsDown(.space)) move = move.add(up);
        if (self.input_handle.keyIsDown(.left_shift)) move = move.sub(up);
        self.velocity_y = 0;
        self.is_grounded = false;
        self.bounds.center = self.bounds.center.add(move.mulScalar(self.noclip_speed));
    }

    fn moveNormal(self: *Self) void {
        const delta = session.config.tickDuration();
        const volume = session.volume();
        self.velocity_y -= gravity * delta;
        if (self.is_grounded and self.input_handle.keyIsDown(.space)) {
            self.velocity_y = self.jumpVelocity();
        }
        var move_y = self.velocity_y * delta;
        self.is_grounded = false;
        if (leko.moveBoundsAxis(volume, &self.bounds, move_y, .y)) |actual_move| {
            _ = actual_move;
            self.velocity_y = 0;
            if (move_y < 0) {
                self.is_grounded = true;
            }
        }
        var mouselook_horizontal = self.mouse_look;
        mouselook_horizontal.look_angles.v[1] = 0;
        const view_matrix_horizontal = mouselook_horizontal.viewMatrix();
        const forward = view_matrix_horizontal.transformDirection(nm.Vec3.unit(.z));
        const right = view_matrix_horizontal.transformDirection(nm.Vec3.unit(.x));
        var move_xz = Vec3.zero;
        if (self.input_handle.keyIsDown(.w)) move_xz = move_xz.add(forward);
        if (self.input_handle.keyIsDown(.s)) move_xz = move_xz.sub(forward);
        if (self.input_handle.keyIsDown(.a)) move_xz = move_xz.sub(right);
        if (self.input_handle.keyIsDown(.d)) move_xz = move_xz.add(right);
        if (!move_xz.eql(Vec3.zero)) {
            move_xz = move_xz.norm();
        }
        move_xz = move_xz.mulScalar(self.move_speed * delta);
        self.moveXZ(volume, move_xz);

        var offset = self.eye_height_step_offset;
        if (offset != 0) {
            const offset_move = self.move_speed * delta * sm.max(1, sm.absFloat(offset));
            if (offset > 0) {
                offset -= offset_move;
                if (offset < 0) {
                    offset = 0;
                }
            }
            else {
                offset += offset_move;
                if (offset > 0) {
                    offset = 0;
                }                
            }
            self.eye_height_step_offset = offset;
        }

    }

    fn jumpVelocity(self: Self) f32 {
        return sm.sqrt(2 * gravity * self.jump_height);
    }

    fn moveXZ(self: *Self, volume: *leko.Volume, move_xz: Vec3) void {
        var step_bounds = self.bounds;
        if (moveBoundsXZ(volume, &self.bounds, move_xz)) |move_ground| {
            if (self.is_grounded or leko.moveBoundsAxis(volume, &step_bounds, -1, .y) != null) {
                if (leko.moveBoundsAxis(volume, &step_bounds, 1, .y) == null) {
                    const move_step = moveBoundsXZ(volume, &step_bounds, move_xz);
                    if (
                        move_step == null 
                        or sm.absFloat(move_step.?.get(.x)) > sm.absFloat(move_ground.get(.x))
                        or sm.absFloat(move_step.?.get(.z)) > sm.absFloat(move_ground.get(.z))
                    ) {
                        self.eye_height_step_offset += self.bounds.center.get(.y) - step_bounds.center.get(.y);
                        self.bounds.center = step_bounds.center;
                    }
                }
            }
        }
        if (self.is_grounded) {
            step_bounds = self.bounds;
            if (leko.moveBoundsAxis(volume, &step_bounds, -1.1, .y) != null) {
                self.eye_height_step_offset += self.bounds.center.get(.y) - step_bounds.center.get(.y);
                self.bounds.center = step_bounds.center;
            }
        }
    }

    fn moveBoundsXZ(volume: *leko.Volume, bounds: *Bounds3, move: Vec3) ?Vec3 {
        const move_result = [2]?f32{
            leko.moveBoundsAxis(volume, bounds, move.get(.x), .x),
            leko.moveBoundsAxis(volume, bounds, move.get(.z), .z),
        };
        if (move_result[0] == null and move_result[1] == null) {
            return null;
        }
        else {
            return Vec3.init(.{
                move_result[0] orelse move.get(.x),
                0,
                move_result[1] orelse move.get(.z),
            });
        }
    }

    pub fn eyePosition(self: Self) Vec3 {
        return self.position.add(Vec3.init(.{0, self.eye_height, 0}));
    }

    pub fn viewMatrix(self: Self) Mat4 {
        return nm.transform.createTranslate(
            self.eyePosition().neg()
            // self.position.add(Vec3.init(.{0, self.eye_height + self.eye_height_step_offset, 0})).neg()
        ).mul(self.mouse_look.viewMatrix());
    }

};