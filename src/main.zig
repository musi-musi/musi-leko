const std = @import("std");
const builtin = @import("builtin");

const shell = @import("shell");
const render = @import("render");


const width = 1920;
const height = 1080;

pub fn main() !void {

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    var sh = try shell.init(gpa.allocator(), width, height, "toki ma o!");
    defer shell.deinit();

    var r = try render.init();
    defer r.deinit();

    while (sh.nextFrame()) {
        r.draw(sh.*);
    }
}