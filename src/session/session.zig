const std = @import("std");
const nm = @import("nm");

const window = @import("window");
const input = @import("input");
const gui = @import("gui");
const leko = @import("leko");

const player = @import("player.zig");

const Vec3 = nm.Vec3;
const Vec3i = nm.Vec3i;
const Mat4 = nm.Mat4;

var _volume: leko.Volume = undefined;
var _volume_manager: leko.VolumeManager = undefined;
var _player: player.Player = undefined;



const Allocator = std.mem.Allocator;

pub fn init(allocator: Allocator) !void {

    try _volume.init(allocator, 32);
    try _volume_manager.init(allocator, &_volume);

    _player.init();

    window.setMouseMode(.hidden_raw);
    _player.input_handle.is_active = true;
}

pub fn deinit() void {
    _volume_manager.deinit();
    _volume.deinit();
}

pub fn update() !void {
    if (window.keyWasPressed(.grave)) {
        if (_player.input_handle.is_active) {
            window.setMouseMode(.visible);
            // window.centerMouseCursor();
        }
        else {
            window.setMouseMode(.hidden_raw);
        }
        _player.input_handle.is_active = !_player.input_handle.is_active;
        gui.input_handle.is_active = !_player.input_handle.is_active;
    }
    _player.update();
    try _volume_manager.update(_player.bounds.center);
}

pub fn viewMatrix() Mat4 {
    return _player.viewMatrix();
}

pub fn volume() *leko.Volume {
    return &_volume;
}

pub fn volumeManager() *leko.VolumeManager {
    return &_volume_manager;
}
