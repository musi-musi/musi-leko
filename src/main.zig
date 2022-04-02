const std = @import("std");
const nm = @import("nm");

const window = @import("window");
const session = @import("session");
const rendering = @import("rendering");
const gui = @import("gui");

const session_renderer = rendering.session_renderer;

pub fn main() !void {

    try window.init(.{});
    defer window.deinit();
    
    window.setVsyncMode(.enabled);

    try gui.init();
    defer gui.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    
    try session.init(allocator);
    defer session.deinit();

    try session_renderer.init(allocator);
    defer session_renderer.deinit();

    

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
            try session.update();
        
            session_renderer.render();
            gui.newFrame();
            gui.showStats();
            // gui.showDemo();
            gui.render();
        }
    }
}