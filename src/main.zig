const std = @import("std");
const builtin = @import("builtin");

const window = @import("window");
const render = @import("render");


const width = 1920;
const height = 1080;

pub fn main() !void {

    try window.init(.{});
    defer window.deinit();
    
    var r = try render.init();
    defer r.deinit();

    while (window.nextFrame()) {
        r.draw();
    }
}