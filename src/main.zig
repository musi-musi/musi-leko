const std = @import("std");
const nm = @import("nm");

const window = @import("window");
const session = @import("session");
const render = @import("render");


pub fn main() !void {

    try window.init(.{});
    defer window.deinit();
    
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    
    try session.init(allocator);
    defer session.deinit();

    
    try render.init(allocator);
    defer render.deinit();

    window.setMouseMode(.hidden_raw);
    while (window.update()) {
        if (window.keyWasPressed(.escape)) {
            window.close();
        }
        else {
            if (window.keyWasPressed(.f_4)) {
                window.setDisplayMode(switch (window.displayMode()) {
                    .windowed => .borderless,
                    .borderless => .windowed,
                });
            }
        }
        try session.update();
        // render.render();
    }
}