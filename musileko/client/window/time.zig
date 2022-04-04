const std = @import("std");
const client = @import("../.zig");
const c = client.c;

var _previous_time: f64 = 0;
var _current_time: f64 = 0;
var _frame_time: f64 = 0;

pub fn previousTime() f64 {
    return _previous_time;
}

pub fn currentTime() f64 {
    return _current_time;
}

pub fn frameTime() f64 {
    return _frame_time;
}


pub fn initTime() void {
    const time = getTime();
    _previous_time = time;
    _current_time = time;
}

pub fn updateTime() void {
    _previous_time = _current_time;
    _current_time = getTime();
    _frame_time = _current_time - _previous_time;
}

fn getTime() f64 {
    return c.glfwGetTime();
}