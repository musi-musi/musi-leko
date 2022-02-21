const std = @import("std");
const builtin = @import("builtin");

const window = @import("window");
const render = @import("render");


const width = 1920;
const height = 1080;

const demo = render.demos.cube;

pub fn main() !void {

    try window.init(.{});
    defer window.deinit();
    
    try demo.init();
    defer demo.deinit();

    while (window.nextFrame()) {
        demo.draw();
    }
}