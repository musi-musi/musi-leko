const std = @import("std");
const client = @import("../_.zig");
const c = client.c;
const nm = client.nm;

const window = @import("_.zig");

const Vec2 = nm.Vec2;

var _raw_supported: bool = false;
var _curr_position: Vec2 = Vec2.zero;
var _prev_position: Vec2 = Vec2.zero;
var _position_delta: Vec2 = Vec2.zero;


pub fn rawMouseSupported() bool {
    return _raw_supported;
}

pub fn mousePosition() Vec2 {
    return _curr_position;
}

pub fn prevMousePosition() Vec2 {
    return _prev_position;
}

pub fn mousePositionDelta() Vec2 {
    return _position_delta;
}

pub fn setMousePosition(position: Vec2) void {
    c.glfwSetCursorPos(window.handle(), @floatCast(f64, position.v[0]), @floatCast(f64, position.v[1]));
    resetMousePositionDelta();
}

pub fn centerMouseCursor() void {
    const width = @intToFloat(f64, window.width());
    const height = @intToFloat(f64, window.height());
    c.glfwSetCursorPos(window.handle(), width / 2.0, height / 2.0);
    resetMousePositionDelta();
}

pub fn resetMousePositionDelta() void {
    _prev_position = getPosition();
    _curr_position = getPosition();
    _position_delta = Vec2.zero;
}

pub fn setMouseMode(mode: MouseMode) void {
    c.glfwSetInputMode(window.handle(), c.GLFW_CURSOR, @enumToInt(mode));
    if (_raw_supported) {
        const raw_mode = (
            if (mode == .hidden_raw) c.GLFW_TRUE else c.GLFW_FALSE
        );
        c.glfwSetInputMode(window.handle(), c.GLFW_RAW_MOUSE_MOTION, raw_mode);
        c.glfwPollEvents();
    }
    resetMousePositionDelta();
}

pub const MouseMode = enum(c_int) {
    visible = c.GLFW_CURSOR_NORMAL,
    hidden = c.GLFW_CURSOR_HIDDEN,
    hidden_raw = c.GLFW_CURSOR_DISABLED,
};

pub fn initMouse() void {
    _raw_supported = c.glfwRawMouseMotionSupported() != c.GLFW_FALSE;
}

pub fn updateMouse() void {
    _prev_position = _curr_position;
    _curr_position = getPosition();
    _position_delta = _curr_position.sub(_prev_position);
}

fn getPosition() Vec2 {
    var x: f64 = undefined;
    var y: f64 = undefined;
    c.glfwGetCursorPos(window.handle(), &x, &y);
    return Vec2.init(.{
        @floatCast(f32, x),
        @floatCast(f32, y),
    });
}