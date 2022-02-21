const std = @import("std");
const c = @import("c");
const nm = @import("nm");

const window = @import("window.zig");

const Vec2 = nm.Vec2;

var _raw_supported: bool = false;
var _last_position: Vec2 = Vec2.zero;
var _position_delta: Vec2 = Vec2.zero;
