const std = @import("std");
const builtin = @import("builtin");

const shell = @import("shell");
const render = @import("render");


const width = 1920;
const height = 1080;

pub fn main() !void {

    var sh = try shell.init();
    defer sh.deinit();
    try sh.start(width, height, "toki ma o!");
    
    var r = try render.init();
    defer r.deinit();

    while (sh.nextFrame()) {
        r.draw();
    }
}