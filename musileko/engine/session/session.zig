const std = @import("std");

const engine = @import("../_.zig");

const nm = engine.nm;
const leko = engine.leko;

const client = @import("../../client/_.zig");
const window = client.window;
const input = client.input;
const gui = client.gui;

const session = @import("_.zig");

const Player = session.Player;
const config = session.config;

const Vec3 = nm.Vec3;
const Vec3i = nm.Vec3i;
const Mat4 = nm.Mat4;

var _volume: leko.Volume = undefined;
var _volume_manager: leko.VolumeManager = undefined;
var _player: Player = undefined;

var _time_since_last_tick: f32 = 0;

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
    const delta = @floatCast(f32, window.frameTime());
    _time_since_last_tick += delta;
    const tick_duration = config.tickDuration();
    while (_time_since_last_tick > tick_duration) : (_time_since_last_tick -= tick_duration) {
        try tick();
    }
    try _volume_manager.update(_player.bounds.center);
}

fn tick() !void {
    _player.tick();
}

pub fn tickLerp() f32 {
    return _time_since_last_tick / config.tickDuration();
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
