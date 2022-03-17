const std = @import("std");
const nm = @import("nm");

const window = @import("window");
const render = @import("render");
const input = @import("input");
const leko = @import("leko");

const Vec3 = nm.Vec3;
const Vec3i = nm.Vec3i;
const Mat4 = nm.Mat4;

const speed: f32 = 25;

var _volume: leko.Volume = undefined;
var _volume_manager: leko.VolumeManager = undefined;
var _camera_pos: Vec3 = undefined;
var _mouselook = input.MouseLook{ .handle = &_player_input, };
var _view_matrix: Mat4 = undefined;

var _player_input: input.InputHandle = .{};

const Allocator = std.mem.Allocator;

pub fn init(allocator: Allocator) !void {

    try _volume.init(allocator, 32);
    try _volume_manager.init(allocator, &_volume);

    _camera_pos = Vec3.init(.{0, 0, 0});
    window.setMouseMode(.hidden_raw);
    _player_input.is_active = true;
}

pub fn deinit() void {
    _volume_manager.deinit();
    _volume.deinit();
}

pub fn update() !void {
    const delta = @floatCast(f32, window.frameTime());
    if (window.keyWasPressed(.grave)) {
        if (_player_input.is_active) {
            window.setMouseMode(.visible);
            // window.centerMouseCursor();
        }
        else {
            window.setMouseMode(.hidden_raw);
        }
        _player_input.is_active = !_player_input.is_active;
    }
    if (_player_input.is_active) {
        _mouselook.update();
        _view_matrix = _mouselook.viewMatrix();
        const forward = _view_matrix.transformDirection(nm.Vec3.unit(.z)).mulScalar(delta * speed);
        const right = _view_matrix.transformDirection(nm.Vec3.unit(.x)).mulScalar(delta * speed);
        const up = nm.Vec3.unit(.y).mulScalar(delta * speed);
        if (window.keyIsDown(.w)) _camera_pos = _camera_pos.add(forward);
        if (window.keyIsDown(.s)) _camera_pos = _camera_pos.sub(forward);
        if (window.keyIsDown(.a)) _camera_pos = _camera_pos.sub(right);
        if (window.keyIsDown(.d)) _camera_pos = _camera_pos.add(right);
        if (window.keyIsDown(.space)) _camera_pos = _camera_pos.add(up);
        if (window.keyIsDown(.left_shift)) _camera_pos = _camera_pos.sub(up);
    }
    try _volume_manager.update(_camera_pos);
}

pub fn viewMatrix() Mat4 {
    return nm.transform.createTranslate(_camera_pos.neg()).mul(_view_matrix);
}

pub fn volume() *const leko.Volume {
    return &_volume;
}

pub fn volumeManager() *leko.VolumeManager {
    return &_volume_manager;
}
